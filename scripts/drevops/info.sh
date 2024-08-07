#!/usr/bin/env bash
##
# Print project information.
#
# shellcheck disable=SC1090,SC1091

t=$(mktemp) && export -p >"${t}" && set -a && . ./.env && if [ -f ./.env.local ]; then . ./.env.local; fi && set +a && . "${t}" && rm "${t}" && unset t

set -eu
[ "${DREVOPS_DEBUG-}" = "1" ] && set -x

# Name of the webroot directory with Drupal codebase.
DREVOPS_WEBROOT="${DREVOPS_WEBROOT:-web}"

# Show one-time login link.
DREVOPS_SHOW_LOGIN="${DREVOPS_SHOW_LOGIN:-}"

# ------------------------------------------------------------------------------

# @formatter:off
note() { printf "       %s\n" "${1}"; }
info() { [ "${TERM:-}" != "dumb" ] && tput colors >/dev/null 2>&1 && printf "\033[34m[INFO] %s\033[0m\n" "${1}" || printf "[INFO] %s\n" "${1}"; }
pass() { [ "${TERM:-}" != "dumb" ] && tput colors >/dev/null 2>&1 && printf "\033[32m[ OK ] %s\033[0m\n" "${1}" || printf "[ OK ] %s\n" "${1}"; }
fail() { [ "${TERM:-}" != "dumb" ] && tput colors >/dev/null 2>&1 && printf "\033[31m[FAIL] %s\033[0m\n" "${1}" || printf "[FAIL] %s\n" "${1}"; }
# @formatter:on

[ -n "${DREVOPS_HOST_HAS_SEQUELACE:-}" ] && sequelace="('ahoy db' to start SequelAce)" || sequelace=""

info "Project information"

echo
note "Project name                : ${DREVOPS_PROJECT}"
note "Docker Compose project name : ${COMPOSE_PROJECT_NAME:-}"
note "Site local URL              : http://${DREVOPS_LOCALDEV_URL}"
note "Path to web root            : $(pwd)/${DREVOPS_WEBROOT}"
note "DB host                     : ${MARIADB_HOST}"
note "DB username                 : ${MARIADB_USERNAME}"
note "DB password                 : ${MARIADB_PASSWORD}"
note "DB port                     : ${MARIADB_PORT}"
note "DB port on host             : ${DREVOPS_HOST_DB_PORT} ${sequelace}"
if [ -n "${DREVOPS_DB_IMAGE:-}" ]; then
  note "DB-in-image                 : ${DREVOPS_DB_IMAGE}"
fi
if [ -n "${DREVOPS_HOST_SOLR_PORT:-}" ]; then
  note "Solr URL on host            : http://127.0.0.1:${DREVOPS_HOST_SOLR_PORT}"
fi
if [ -n "${DREVOPS_HOST_SELENIUM_VNC_PORT:-}" ]; then
  note "Selenium VNC URL on host    : http://localhost:${DREVOPS_HOST_SELENIUM_VNC_PORT}/?autoconnect=1&password=secret"
fi
note "Mailhog URL                 : http://mailhog.docker.amazee.io/"
note "Xdebug                      : $(php -v | grep -q Xdebug && echo "Enabled ('ahoy up cli' to disable)" || echo "Disabled ('ahoy debug' to enable)")"
if [ "${DREVOPS_SHOW_LOGIN}" = "1" ] || [ -n "${1:-}" ]; then
  echo -n "       Site login link             : "
  ./scripts/drevops/login.sh
else
  echo
  note "Use 'ahoy login' to generate Drupal login link."
fi
echo
