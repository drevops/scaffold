#!/usr/bin/env bash
##
# Deploy via pushing Docker images to Docker registry.
#
# This will push multiple docker images by tagging provided services in the
# DOCKER_MAP variable.
#

set -e
[ -n "${DREVOPS_DEBUG}" ] && set -x

# Comma-separated map of docker services and images to use for deployment in
# format "service1=org/image1,service2=org/image2".
DOCKER_MAP="${DOCKER_MAP:-}"

# Docker registry credentials to read and write Docker images.
# Note that for CI, these variables should be set through UI.
DOCKER_REGISTRY_USERNAME="${DOCKER_REGISTRY_USERNAME:-}"
DOCKER_REGISTRY_TOKEN="${DOCKER_REGISTRY_TOKEN:-}"

# Docker registry name. Provide port, if required as <server_name>:<port>.
# Defaults to DockerHub.
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"

# ------------------------------------------------------------------------------

echo "==> Started DOCKER deployment"

# Only deploy if the map was provided, but do not fail if it has not as this
# may be called as a part of another task.
# @todo: Handle this better - empty DOCKER_MAP should use defaults.
[ -z "${DOCKER_MAP}" ] && echo "Services map is not specified in DOCKER_MAP variable. Docker deployment will not continue." && exit 0

services=()
images=()
# Parse and validate map.
IFS=',' read -r -a values <<< "${DOCKER_MAP}"
for value in "${values[@]}"; do
  IFS='=' read -r -a parts <<< "${value}"
  [ "${#parts[@]}" -ne 2 ] && echo "ERROR: invalid key/value pair \"${value}\" provided." && exit 1
  services+=("${parts[0]}")
  images+=("${parts[1]}")
done

# Login to Docker registry.
if [ -f "$HOME/.docker/config.json" ] && grep -q "${DOCKER_REGISTRY}" "$HOME/.docker/config.json"; then
  echo "==> Already logged in to registry \"${DOCKER_REGISTRY}\"."
elif [ -n "${DOCKER_REGISTRY_USERNAME}" ] &&  [ -n "${DOCKER_REGISTRY_TOKEN}" ]; then
  echo "==> Logging in to registry \"${DOCKER_REGISTRY}\"."
  docker login --username "${DOCKER_REGISTRY_USERNAME}" --password "${DOCKER_REGISTRY_TOKEN}" "${DOCKER_REGISTRY}"
fi

for key in "${!services[@]}"; do
  service="${services[$key]}"
  image="${images[$key]}"

  echo "==> Processing service ${service}."
  # Check if the service is running.)
  cid=$(docker-compose ps -q "${service}")

  [ -z "${cid}" ] && echo "ERROR: Service \"${service}\" is not running." && exit 1
  echo "==> Found \"${service}\" service container with id \"${cid}\"."

  [ -n "${image##*:*}" ] && image="${image}:latest"
  new_image="${DOCKER_REGISTRY}/${image}"

  echo "==> Committing image with name \"${new_image}\"."
  iid=$(docker commit "${cid}" "${new_image}")
  iid="${iid#sha256:}"
  echo "==> Committed image with id \"${iid}\"."

  echo "==> Pushing image to the registry."
  docker push "${new_image}"
done

echo "==> Finished DOCKER deployment"
