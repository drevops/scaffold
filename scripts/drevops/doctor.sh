#!/usr/bin/env bash
#
# Check DrevOps project requirements or print info.
#
# IMPORTANT! This script runs outside the container on the host system.
#
# doctor.sh - check project requirements.
# doctor.sh info - show system information.
#

t=$(mktemp) && export -p >"$t" && set -a && . ./.env && if [ -f ./.env.local ]; then . ./.env.local; fi && set +a && . "$t" && rm "$t" && unset t

set -e
[ -n "${DREVOPS_DEBUG}" ] && set -x

# Check minimal Doctor requirements.
DREVOPS_DOCTOR_CHECK_MINIMAL="${DREVOPS_DOCTOR_CHECK_MINIMAL:-0}"

# Check pre-flight Doctor requirements.
DREVOPS_DOCTOR_CHECK_PREFLIGHT="${DREVOPS_DOCTOR_CHECK_PREFLIGHT:-0}"

if [ "${DREVOPS_DOCTOR_CHECK_MINIMAL}" = "1" ]; then
  DREVOPS_DOCTOR_CHECK_PORT=0
  DREVOPS_DOCTOR_CHECK_PYGMY=0
  DREVOPS_DOCTOR_CHECK_SSH=0
  DREVOPS_DOCTOR_CHECK_WEBSERVER=0
  DREVOPS_DOCTOR_CHECK_BOOTSTRAP=0
fi

if [ "${DREVOPS_DOCTOR_CHECK_PREFLIGHT}" = "1" ]; then
  DREVOPS_DOCTOR_CHECK_TOOLS="${DREVOPS_DOCTOR_CHECK_TOOLS:-1}"
  DREVOPS_DOCTOR_CHECK_PORT="${DREVOPS_DOCTOR_CHECK_PORT:-1}"
  DREVOPS_DOCTOR_CHECK_PYGMY="${DREVOPS_DOCTOR_CHECK_PYGMY:-1}"
  DREVOPS_DOCTOR_CHECK_CONTAINERS="${DREVOPS_DOCTOR_CHECK_CONTAINERS:-0}"
  DREVOPS_DOCTOR_CHECK_SSH="${DREVOPS_DOCTOR_CHECK_SSH:-0}"
  DREVOPS_DOCTOR_CHECK_WEBSERVER="${DREVOPS_DOCTOR_CHECK_WEBSERVER:-0}"
  DREVOPS_DOCTOR_CHECK_BOOTSTRAP="${DREVOPS_DOCTOR_CHECK_BOOTSTRAP:-0}"
fi

# Check Doctor requirements for presence of tools.
DREVOPS_DOCTOR_CHECK_TOOLS="${DREVOPS_DOCTOR_CHECK_TOOLS:-1}"

# Check Doctor requirements for port of availability.
DREVOPS_DOCTOR_CHECK_PORT="${DREVOPS_DOCTOR_CHECK_PORT:-1}"

# Check Doctor requirements for Pygmy of availability.
DREVOPS_DOCTOR_CHECK_PYGMY="${DREVOPS_DOCTOR_CHECK_PYGMY:-1}"

# Check Doctor requirements for container status.
DREVOPS_DOCTOR_CHECK_CONTAINERS="${DREVOPS_DOCTOR_CHECK_CONTAINERS:-1}"

# Check Doctor requirements for SSH key.
DREVOPS_DOCTOR_CHECK_SSH="${DREVOPS_DOCTOR_CHECK_SSH:-1}"

# Check Doctor requirements for webserver status.
DREVOPS_DOCTOR_CHECK_WEBSERVER="${DREVOPS_DOCTOR_CHECK_WEBSERVER:-1}"

# Check Doctor requirements for application bootstrap status.
DREVOPS_DOCTOR_CHECK_BOOTSTRAP="${DREVOPS_DOCTOR_CHECK_BOOTSTRAP:-1}"

# Local development URL.
DREVOPS_DOCTOR_LOCALDEV_URL="${DREVOPS_DOCTOR_LOCALDEV_URL:-${DREVOPS_LOCALDEV_URL}}"

# Default SSH key file.
DREVOPS_DOCTOR_SSH_KEY_FILE="${DREVOPS_DOCTOR_SSH_KEY_FILE:-${HOME}/.ssh/id_rsa}"

#-------------------------------------------------------------------------------

# @formatter:off
note() { printf "       %s\n" "$1"; }
info() { [ -z "${TERM_NO_COLOR}" ] && tput colors >/dev/null 2>&1 && printf "\033[34m[INFO] %s\033[0m\n" "$1" || printf "[INFO] %s\n" "$1"; }
pass() { [ -z "${TERM_NO_COLOR}" ] && tput colors >/dev/null 2>&1 && printf "\033[32m[ OK ] %s\033[0m\n" "$1" || printf "[ OK ] %s\n" "$1"; }
fail() { [ -z "${TERM_NO_COLOR}" ] && tput colors >/dev/null 2>&1 && printf "\033[31m[FAIL] %s\033[0m\n" "$1" || printf "[FAIL] %s\n" "$1"; }
# @formatter:on

#
# Main entry point.
#
main() {
  [ "$1" = "info" ] && system_info && exit

  info "Checking project requirements"

  if [ "${DREVOPS_DOCTOR_CHECK_TOOLS}" = "1" ]; then
    [ "$(command_exists docker)" = "1" ] && fail "Please install Docker (https://www.docker.com/get-started)." && exit 1
    [ "$(command_exists docker-compose)" = "1" ] && fail "Please install docker-compose (https://docs.docker.com/compose/install/)." && exit 1
    [ "$(command_exists pygmy)" = "1" ] && fail "Please install Pygmy (https://pygmy.readthedocs.io/)." && exit 1
    [ "$(command_exists ahoy)" = "1" ] && fail "Please install Ahoy (https://ahoy-cli.readthedocs.io/)." && exit 1
    pass "All required tools are present."
  fi

  if [ "${DREVOPS_DOCTOR_CHECK_PORT}" = "1" ] && [ "${OSTYPE}" != "linux-gnu" ]; then
    if lsof -i :80 | grep -v 'CLOSED' | grep 'LISTEN' | grep -vq 'om.docke'; then
      fail "Port 80 is occupied by a service other than Docker. Stop this service and run 'pygmy up'."
      exit 1
    fi
    pass "Port 80 is available."
  fi

  if [ "${DREVOPS_DOCTOR_CHECK_PYGMY}" = "1" ]; then
    pygmy_status="$(pygmy status | tr -d '\000')"

    pygmy_services=()
    pygmy_services+=("amazeeio-ssh-agent")
    pygmy_services+=("amazeeio-mailhog")
    pygmy_services+=("amazeeio-haproxy")
    pygmy_services+=("amazeeio-dnsmasq")

    for pygmy_service in "${pygmy_services[@]}"; do
      if ! echo "$pygmy_status" | grep -q "${pygmy_service}: Running"; then
        fail "Pygmy service ${pygmy_service} is not running. Run 'pygmy up' or 'pygmy restart' to fix."
        exit 1
      fi
    done
    pass "Pygmy is running."
  fi

  # Check that the stack is running.
  if [ "${DREVOPS_DOCTOR_CHECK_CONTAINERS}" = "1" ]; then
    docker_services=(cli php nginx mariadb)
    for docker_service in "${docker_services[@]}"; do
      # shellcheck disable=SC2143
      if [ -z "$(docker-compose ps -q "${docker_service}")" ] || [ -z "$(docker ps -q --no-trunc | grep "$(docker-compose ps -q "${docker_service}")")" ]; then
        fail "${docker_service} container is not running."
        echo "      Run 'ahoy up'."
        echo "      Run 'ahoy logs ${docker_service}' to see error logs."
        exit 1
      fi
    done
    pass "All containers are running"
  fi

  if [ "${DREVOPS_DOCTOR_CHECK_SSH}" = "1" ]; then
    # SSH key injection is required to access Lagoon services from within
    # containers. For example, to connect to production environment to run
    # drush script.
    # Pygmy makes this possible in the following way:
    # 1. Pygmy starts `amazeeio/ssh-agent` container with a volume `/tmp/amazeeio_ssh-agent`
    # 2. Pygmy adds a default SSH key from the host into this volume.
    # 3. `docker-compose.yml` should have volume inclusion specified for CLI container:
    #    ```
    #    volumes_from:
    #      - container:amazeeio-ssh-agent
    #    ```
    # 4. When CLI container starts, the volume is mounted and an entrypoint script
    #    adds SHH key into agent.
    #    @see https://github.com/uselagoon/lagoon-images/blob/main/images/php-cli/10-ssh-agent.sh
    #
    #  Running `ssh-add -L` within CLI container should show that the SSH key
    #  is correctly loaded.
    #
    # As rule of a thumb, one must restart the CLI container after restarting
    # Pygmy ONLY if SSH key was not loaded in pygmy before the stack starts.
    # No need to restart CLI container if key was added, but pygmy was
    # restarted - the volume mount will retain and the key will still be
    # available in CLI container.

    ssh_key_added=1
    # Check that the key is injected into pygmy ssh-agent container.
    if ! pygmy status 2>&1 | grep -q "${DREVOPS_DOCTOR_SSH_KEY_FILE}"; then
      note "SSH key is not added to pygmy. Run 'pygmy restart' and then 'ahoy up -- --build'."
      ssh_key_added=0
    fi

    # Check that the volume is mounted into CLI container.
    if ! docker exec -i "$(docker-compose ps -q cli)" bash -c "grep \"^/dev\" /etc/mtab | grep -q /tmp/amazeeio_ssh-agent"; then
      note "SSH key is added to Pygmy, but the volume is not mounted into container. Make sure that your your \"docker-compose.yml\" has the following lines:"
      note "volumes_from:"
      note "- container:amazeeio-ssh-agent"
      note "After adding these lines, run 'ahoy up -- --build'."
      ssh_key_added=0
    fi

    # Check that ssh key is available in the container.
    if [ "${ssh_key_added}" = "1" ] && ! docker exec -i "$(docker-compose ps -q cli)" bash -c "ssh-add -L | grep -q 'ssh-rsa'"; then
      note "SSH key was not added into container. Run 'pygmy restart'."
      ssh_key_added=0
    fi

    [ "${ssh_key_added}" = "1" ] && pass "SSH key is available within CLI container."
  fi

  if [ -n "${DREVOPS_DOCTOR_LOCALDEV_URL}" ]; then
    if [ "${DREVOPS_DOCTOR_CHECK_WEBSERVER}" = "1" ]; then
      # Depending on the type of installation, the homepage may return 200 or 403.
      if ! curl -L -s -o /dev/null -w "%{http_code}" "${DREVOPS_DOCTOR_LOCALDEV_URL}" | grep -q '200\|403'; then
        fail "Web server is not accessible at http://${DREVOPS_DOCTOR_LOCALDEV_URL}."
        exit 1
      fi
      pass "Web server is running and accessible at http://${DREVOPS_DOCTOR_LOCALDEV_URL}."
    fi

    if [ "${DREVOPS_DOCTOR_CHECK_BOOTSTRAP}" = "1" ]; then
      if ! curl -L -s -N "${DREVOPS_DOCTOR_LOCALDEV_URL}" | grep -q -i "charset="; then
        fail "Website is running, but cannot be bootstrapped. Try pulling latest container images with 'ahoy pull'."
        exit 1
      fi
      pass "Successfully bootstrapped website at http://${DREVOPS_DOCTOR_LOCALDEV_URL}."
    fi
  fi

  pass "All required checks have passed."
  echo
}

system_info() {
  echo "System information report"
  echo

  echo "OPERATING SYSTEM"
  if [ "$(uname)" = "Darwin" ]; then
    sw_vers
  else
    lsb_release -a
  fi
  echo

  echo "DOCKER"
  echo "Path to binary: $(which docker)"
  docker -v
  docker info
  echo

  echo "DOCKER COMPOSE"
  echo "Path to binary: $(which docker-compose)"
  docker-compose version
  echo

  echo "PYGMY"
  echo "Path to binary: $(which pygmy)"
  pygmy version
  echo

  echo "AHOY"
  echo "Path to binary: $(which ahoy)"
  ahoy --version
  echo
}

#
# Check that command exists.
#
command_exists() {
  local cmd=$1
  command -v "${cmd}" | grep -ohq "${cmd}"
  local res=$?

  # Try homebrew lookup, if brew is available.
  if command -v "brew" | grep -ohq "brew" && [ "$res" = "1" ]; then
    brew --prefix "${cmd}" >/dev/null
    res=$?
  fi

  echo ${res}
}

main "$@"
