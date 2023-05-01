#!/usr/bin/env bash
##
# Notification dispatch to New Relic.
#

t=$(mktemp) && export -p >"$t" && set -a && . ./.env && if [ -f ./.env.local ]; then . ./.env.local; fi && set +a && . "$t" && rm "$t" && unset t

set -eu
[ -n "${DREVOPS_DEBUG:-}" ] && set -x

# The project name to notify.
DREVOPS_NOTIFY_PROJECT="${DREVOPS_NOTIFY_PROJECT:-}"

# The API key. Usually of type 'USER'.
DREVOPS_NOTIFY_NEWRELIC_APIKEY="${DREVOPS_NOTIFY_NEWRELIC_APIKEY:-}"

# Deployment reference, such as a git SHA.
DREVOPS_NOTIFY_SHA="${DREVOPS_NOTIFY_SHA:-}"

# Application name as it appears in the dashboard.
DREVOPS_NOTIFY_NEWRELIC_APP_NAME="${DREVOPS_NOTIFY_NEWRELIC_APP_NAME:-"${DREVOPS_NOTIFY_PROJECT}-${DREVOPS_NOTIFY_SHA}"}"

# Optional Application ID. Will be discovered automatically from application name if not provided.
DREVOPS_NOTIFY_NEWRELIC_APPID="${DREVOPS_NOTIFY_NEWRELIC_APPID:-}"

# Optional description.
DREVOPS_NOTIFY_NEWRELIC_DESCRIPTION="${DREVOPS_NOTIFY_NEWRELIC_DESCRIPTION:-"${DREVOPS_NOTIFY_SHA} deployed"}"

# Optional changelog. Defaults to description.
DREVOPS_NOTIFY_NEWRELIC_CHANGELOG="${DREVOPS_NOTIFY_NEWRELIC_CHANGELOG:-${DREVOPS_NOTIFY_NEWRELIC_DESCRIPTION}}"

# Optional name of the user performing the deployment.
DREVOPS_NOTIFY_NEWRELIC_USER="${DREVOPS_NOTIFY_NEWRELIC_USER:-"Deployment robot"}"

# Optional endpoint.
DREVOPS_NOTIFY_NEWRELIC_ENDPOINT="${DREVOPS_NOTIFY_NEWRELIC_ENDPOINT:-https://api.newrelic.com/v2}"

# ------------------------------------------------------------------------------

# @formatter:off
note() { printf "       %s\n" "$1"; }
info() { [ -z "${TERM_NO_COLOR:-}" ] && tput colors >/dev/null 2>&1 && printf "\033[34m[INFO] %s\033[0m\n" "$1" || printf "[INFO] %s\n" "$1"; }
pass() { [ -z "${TERM_NO_COLOR:-}" ] && tput colors >/dev/null 2>&1 && printf "\033[32m[ OK ] %s\033[0m\n" "$1" || printf "[ OK ] %s\n" "$1"; }
fail() { [ -z "${TERM_NO_COLOR:-}" ] && tput colors >/dev/null 2>&1 && printf "\033[31m[FAIL] %s\033[0m\n" "$1" || printf "[FAIL] %s\n" "$1"; }
# @formatter:on

command -v curl >/dev/null || (fail "curl command is not available." && exit 1)
[ -z "${DREVOPS_NOTIFY_PROJECT}" ] && fail "Missing required value for DREVOPS_NOTIFY_PROJECT" && exit 1
[ -z "${DREVOPS_NOTIFY_NEWRELIC_APIKEY}" ] && fail "Missing required value for DREVOPS_NOTIFY_NEWRELIC_APIKEY" && exit 1
[ -z "${DREVOPS_NOTIFY_SHA}" ] && fail "Missing required value for DREVOPS_NOTIFY_REF" && exit 1
[ -z "${DREVOPS_NOTIFY_NEWRELIC_APP_NAME}" ] && fail "Missing required value for DREVOPS_NOTIFY_NEWRELIC_APP_NAME" && exit 1
[ -z "${DREVOPS_NOTIFY_NEWRELIC_DESCRIPTION}" ] && fail "Missing required value for DREVOPS_NOTIFY_NEWRELIC_DESCRIPTION" && exit 1
[ -z "${DREVOPS_NOTIFY_NEWRELIC_CHANGELOG}" ] && fail "Missing required value for DREVOPS_NOTIFY_NEWRELIC_CHANGELOG" && exit 1
[ -z "${DREVOPS_NOTIFY_NEWRELIC_USER}" ] && fail "Missing required value for DREVOPS_NOTIFY_NEWRELIC_USER" && exit 1

info "Started New Relic notification."

# Discover APP id by name if it was not provided.
if [ -z "${DREVOPS_NOTIFY_NEWRELIC_APPID}" ] && [ -n "${DREVOPS_NOTIFY_NEWRELIC_APP_NAME}" ]; then
  DREVOPS_NOTIFY_NEWRELIC_APPID="$(curl -s -X GET "${DREVOPS_NOTIFY_NEWRELIC_ENDPOINT}/applications.json" \
    -H "Api-Key:${DREVOPS_NOTIFY_NEWRELIC_APIKEY}" \
    -s -G -d "filter[name]=${DREVOPS_NOTIFY_NEWRELIC_APP_NAME}&exclude_links=true" |
    cut -c 24- |
    cut -c -10)"
fi

{ [ "${#DREVOPS_NOTIFY_NEWRELIC_APPID}" != "10" ] || [ "$(expr "x$DREVOPS_NOTIFY_NEWRELIC_APPID" : "x[0-9]*$")" -eq 0 ]; } && fail "Failed to get an application ID from the application name ${DREVOPS_NOTIFY_NEWRELIC_APP_NAME}." && exit 1

if ! curl -X POST "${DREVOPS_NOTIFY_NEWRELIC_ENDPOINT}/applications/${DREVOPS_NOTIFY_NEWRELIC_APPID}/deployments.json" \
  -L -s -o /dev/null -w "%{http_code}" \
  -H "Api-Key:${DREVOPS_NOTIFY_NEWRELIC_APIKEY}" \
  -H 'Content-Type: application/json' \
  -d \
  "{
  \"deployment\": {
    \"revision\": \"${DREVOPS_NOTIFY_SHA}\",
    \"changelog\": \"${DREVOPS_NOTIFY_NEWRELIC_CHANGELOG}\",
    \"description\": \"${DREVOPS_NOTIFY_NEWRELIC_DESCRIPTION}\",
    \"user\": \"${DREVOPS_NOTIFY_NEWRELIC_USER}\"
  }
}" | grep -q '201'; then
  fail "[ERROR] Failed to crate a deployment notification for application ${DREVOPS_NOTIFY_NEWRELIC_APP_NAME} with ID ${DREVOPS_NOTIFY_NEWRELIC_APPID}"
  exit 1
fi

pass "Finished New Relic notification."
