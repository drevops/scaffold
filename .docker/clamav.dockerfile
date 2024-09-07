# ClamAV container.
#
# @see https://hub.docker.com/r/clamav/clamav/tags
#
# Allow running ClamAV in rootless mode.
# @see https://github.com/Cisco-Talos/clamav/issues/478
#
# hadolint global ignore=DL3018
#
# @see https://hub.docker.com/r/uselagoon/commons/tags
# @see https://github.com/uselagoon/lagoon-images/tree/main/images/commons
FROM uselagoon/commons:24.8.0 as commons

FROM clamav/clamav:1.4.1

COPY --from=commons /lagoon /lagoon
COPY --from=commons /bin/fix-permissions /bin/ep /bin/docker-sleep /bin/wait-for /bin/

RUN apk add --no-cache tzdata

COPY .docker/config/clamav/clamav.conf /tmp/clamav.conf

RUN cat /tmp/clamav.conf >> /etc/clamav/clamd.conf && rm /tmp/clamav.conf && \
    sed -i "s/^LogFile /# LogFile /g" /etc/clamav/clamd.conf && \
    sed -i "s/^#LogSyslog /LogSyslog /g" /etc/clamav/clamd.conf && \
    sed -i "s/^UpdateLogFile /# UpdateLogFile /g" /etc/clamav/freshclam.conf && \
    sed -i "s/^#LogSyslog /LogSyslog /g" /etc/clamav/freshclam.conf

USER root

RUN fix-permissions /var/lib/clamav

USER clamav

ENTRYPOINT [ "/init-unprivileged" ]
