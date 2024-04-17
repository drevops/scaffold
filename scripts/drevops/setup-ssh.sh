#!/usr/bin/env bash
##
# Setup SSH in the environment.
#
# - If key fingerprint provided in MD5 or SHA256 format, search for the existing
#   key file. Export the key file path.
# - Start SSH agent if not running. Export SSH_AGENT_PID and SSH_AUTH_SOCK.
# - Load SSH key to the SSH agent.
# - Disable strict host key checking in CI.
#
# IMPORTANT! This script runs outside the container on the host system.
#
# shellcheck disable=SC1090,SC1091,SC2009

t=$(mktemp) && export -p >"${t}" && set -a && . ./.env && if [ -f ./.env.local ]; then . ./.env.local; fi && set +a && . "${t}" && rm "${t}" && unset t

set -eu
[ "${DREVOPS_DEBUG-}" = "1" ] && set -x

# Prefix used to load SSH key from prefixes environment variables:
# - DREVOPS_${DREVOPS_SSH_PREFIX}_SSH_FINGERPRINT - the variable name with the
#   SSH key fingerprint value.
# - DREVOPS_${DREVOPS_SSH_PREFIX}_SSH_FILE - the variable name with the SSH
#   key file path.
DREVOPS_SSH_PREFIX="${DREVOPS_SSH_PREFIX?Missing the required DREVOPS_SSH_PREFIX environment variable.}"

# ------------------------------------------------------------------------------

# @formatter:off
note() { printf "       %s\n" "${1}"; }
info() { [ "${TERM:-}" != "dumb" ] && tput colors >/dev/null 2>&1 && printf "\033[34m[INFO] %s\033[0m\n" "${1}" || printf "[INFO] %s\n" "${1}"; }
pass() { [ "${TERM:-}" != "dumb" ] && tput colors >/dev/null 2>&1 && printf "\033[32m[ OK ] %s\033[0m\n" "${1}" || printf "[ OK ] %s\n" "${1}"; }
fail() { [ "${TERM:-}" != "dumb" ] && tput colors >/dev/null 2>&1 && printf "\033[31m[FAIL] %s\033[0m\n" "${1}" || printf "[FAIL] %s\n" "${1}"; }
# @formatter:on

for cmd in ssh-keygen ssh-add; do command -v ${cmd} >/dev/null || { fail "Command ${cmd} is not available"; exit 1; }; done

info "Started SSH setup."

fingerprint_var="DREVOPS_${DREVOPS_SSH_PREFIX}_SSH_FINGERPRINT"
if [ -n "${!fingerprint_var-}" ]; then
  fingerprint="${!fingerprint_var}"
  note "Found variable ${fingerprint_var} with value ${fingerprint}."
fi

file_var="DREVOPS_${DREVOPS_SSH_PREFIX}_SSH_FILE"
if [ -n "${!file_var-}" ]; then
  file="${!file_var}"
  note "Found variable ${file_var} with value ${file}."
else
  file="${HOME}/.ssh/id_rsa"
  note "Using default SSH file ${file}."
fi

if [ -n "${fingerprint-}" ]; then
  note "Using fingerprint-based deploy key because fingerprint was provided."

  if [ "${fingerprint#SHA256:}" != "${fingerprint}" ]; then
    note "Searching for MD5 hash as fingerprint starts with SHA256."
    for existing_file in "${HOME}"/.ssh/id_rsa*; do
      fingerprint_sha256=$(ssh-keygen -l -E sha256 -f "${existing_file}" | awk '{print $2}')
      if [ "${fingerprint_sha256}" = "${fingerprint}" ]; then
        pass "Found matching existing key file ${existing_file}."
        fingerprint=$(ssh-keygen -l -E md5 -f "${existing_file}" | awk '{print $2}')
        fingerprint="${fingerprint#MD5:}"
        break
      fi
    done
  fi

  # Cleanup the fingerprint and create a file name.
  file="${fingerprint//:/}"
  file="${HOME}/.ssh/id_rsa_${file//\"/}"
fi

if [ ! -f "${file}" ]; then
  fail "SSH key file ${file} does not exist."
  exit 1
fi

note "Using SSH key file ${file}."
export "${file_var}=${file}"

if [ -z "${SSH_AGENT_PID:-}" ]; then
  if ! ps aux | grep "[s]sh-agent" | awk '{print $2}' >/dev/null; then
    note "Starting SSH agent."
    eval "$(ssh-agent)"
  fi
fi

if ssh-add -l | grep -q "${file}"; then
  note "SSH agent has ${file} key loaded."
else
  note "SSH agent does not have a required key loaded. Trying to load."
  ssh-add -D >/dev/null
  ssh-add "${file}"
  ssh-add -l
fi

if [ -n "${CI-}" ]; then
  note "Disabling strict host key checking in CI."
  mkdir -p "${HOME}/.ssh/"
  echo -e "\nHost *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null\n" >>"${HOME}/.ssh/config"
  chmod 600 "${HOME}/.ssh/config"
fi

pass "Finished SSH setup."
