# Nginx container.
#
# All web requests are sent to this container.
ARG CLI_IMAGE
# hadolint ignore=DL3006
FROM ${CLI_IMAGE:-cli} as cli

# @see https://hub.docker.com/r/uselagoon/nginx-drupal/tags?page=1
# @see https://github.com/uselagoon/lagoon-images/tree/main/images/nginx-drupal
FROM uselagoon/nginx-drupal:23.5.0

# Webroot is used for Nginx docroot configuration.
ARG WEBROOT=web
ENV WEBROOT=${WEBROOT}

COPY --from=cli /app /app
