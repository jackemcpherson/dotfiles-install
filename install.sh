#!/bin/bash
#
# Install the dotfiles CLI from the latest GitHub release of a private
# repository, using a fine-grained token passed in DOTFILES_TOKEN.
#
# Usage:
#   DOTFILES_TOKEN=github_pat_... bash install.sh
#
# Environment:
#   DOTFILES_TOKEN  Required. Token with Contents read on the repository.
#   DOTFILES_REPO   Optional. owner/name, default jackemcpherson/dotfiles.
#   DOTFILES_BIN    Optional. Install directory, default ~/.local/bin.
#   DOTFILES_TAG    Optional. Release tag to install, default latest.

set -euo pipefail

readonly REPO="${DOTFILES_REPO:-jackemcpherson/dotfiles}"
readonly BIN_DIR="${DOTFILES_BIN:-${HOME}/.local/bin}"
readonly ASSET='dotfiles-darwin-arm64'
readonly API='https://api.github.com'

#######################################
# Call the GitHub API with the token.
# Globals:
#   API
#   DOTFILES_TOKEN
# Arguments:
#   Accept header, then the path below /repos/<repo>.
# Outputs:
#   Writes the response body to stdout.
#######################################
api() {
  local accept="$1"
  local path="$2"
  curl -fsSL \
    -H "Accept: ${accept}" \
    -H "Authorization: Bearer ${DOTFILES_TOKEN}" \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "${API}/repos/${REPO}${path}"
}

#######################################
# Print the id of one asset in a release JSON document.
# Arguments:
#   Release JSON on stdin, asset name as $1.
#######################################
asset_id() {
  local name="$1"
  python3 -c '
import json, sys
name = sys.argv[1]
for asset in json.load(sys.stdin)["assets"]:
    if asset["name"] == name:
        print(asset["id"])
        break
' "${name}"
}

#######################################
# Download the release binary, verify it, and install it.
# Globals:
#   ASSET
#   BIN_DIR
#   DOTFILES_TAG
#   DOTFILES_TOKEN
# Arguments:
#   None
# Outputs:
#   Writes progress to stdout and errors to stderr.
#######################################
main() {
  local release
  local release_path
  local binary_id
  local checksum_id
  local tag
  local workdir

  if [[ -z "${DOTFILES_TOKEN:-}" ]]; then
    printf 'DOTFILES_TOKEN is not set.\n' >&2
    return 1
  fi
  if [[ "$(uname -s)-$(uname -m)" != 'Darwin-arm64' ]]; then
    printf 'Only Apple Silicon macOS is supported.\n' >&2
    return 1
  fi

  release_path='/releases/latest'
  if [[ -n "${DOTFILES_TAG:-}" ]]; then
    release_path="/releases/tags/${DOTFILES_TAG}"
  fi
  release="$(api 'application/vnd.github+json' "${release_path}")"
  tag="$(printf '%s' "${release}" \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')"
  binary_id="$(printf '%s' "${release}" | asset_id "${ASSET}")"
  checksum_id="$(printf '%s' "${release}" | asset_id "${ASSET}.sha256")"
  if [[ -z "${binary_id}" || -z "${checksum_id}" ]]; then
    printf 'Release %s has no %s asset.\n' "${tag}" "${ASSET}" >&2
    return 1
  fi

  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' EXIT
  printf 'Downloading dotfiles %s...\n' "${tag}"
  api 'application/octet-stream' "/releases/assets/${binary_id}" \
    >"${workdir}/${ASSET}"
  api 'application/octet-stream' "/releases/assets/${checksum_id}" \
    >"${workdir}/${ASSET}.sha256"
  (cd "${workdir}" && shasum -a 256 -c "${ASSET}.sha256" >/dev/null)

  mkdir -p "${BIN_DIR}"
  install -m 0755 "${workdir}/${ASSET}" "${BIN_DIR}/dotfiles"
  printf 'Installed %s/dotfiles (%s).\n' "${BIN_DIR}" "${tag}"
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) printf 'Add %s to PATH.\n' "${BIN_DIR}" ;;
  esac
  printf 'Next: pbpaste | dotfiles init --profile <profile> --token-stdin\n'
  printf '      dotfiles pull && dotfiles apply\n'
}

main "$@"
