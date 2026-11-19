# syntax=docker/dockerfile:1
FROM golang:1.27.4-bookworm AS tools
RUN apt-get update && apt-get install -y --no-install-recommends python3 unzip ca-certificates && rm -rf /var/lib/apt/lists/*
COPY manifests/sources.lock.json /build/sources.lock.json
COPY scripts/build-tools.sh /build/build-tools.sh
ARG TOOLS_COMPONENTS
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build TOOLS_COMPONENTS="$TOOLS_COMPONENTS" bash /build/build-tools.sh

FROM alpine:3.24.4 AS alpine
RUN apk upgrade --no-cache && apk add --no-cache bash ca-certificates curl wget git openssh-client nano sudo \
    python3 py3-yaml py3-coverage openssl openjdk17-jre-headless docker docker-cli fuse-overlayfs \
    iputils bind-tools iproute2 tcpdump netcat-openbsd traceroute busybox-extras postfix mailx msmtp \
    libstdc++ xz gettext tzdata gnupg unzip jq nodejs npm && update-ca-certificates
COPY --from=tools /out/ /usr/local/bin/
COPY --from=tools /opt/sonar-scanner/ /opt/sonar-scanner/
COPY --from=tools /licenses/ /usr/share/licenses/tools/
COPY scripts/runtime/ /usr/local/bin/
RUN sh /usr/local/bin/setup-image.sh && sh /usr/local/bin/smoke-tools.sh
ARG VERSION=1.6.0
ARG REVISION=unknown
ARG IMAGE_VENDOR="Tools CI/CD"
LABEL org.opencontainers.image.title="Tools Alpine" org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$REVISION" org.opencontainers.image.vendor="$IMAGE_VENDOR" \
      org.opencontainers.image.description="DevOps toolbox with OpenBao, Kubernetes, Docker-in-Docker and Postfix" \
      org.opencontainers.image.licenses="NOASSERTION" org.opencontainers.image.base.name="alpine:3.24.4"
ENV TZ=America/Fortaleza
ENTRYPOINT ["/usr/local/bin/start-postfix-dind.sh"]
CMD ["dockerd"]

FROM ubuntu:22.04 AS ubuntu
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash ca-certificates curl wget git openssh-client nano sudo python3 python3-yaml python3-coverage \
    openssl openjdk-17-jre-headless docker.io fuse-overlayfs iputils-ping dnsutils iproute2 tcpdump \
    netcat-openbsd traceroute telnet postfix bsd-mailx msmtp xz-utils gettext tzdata gnupg unzip jq \
    && rm -rf /var/lib/apt/lists/* && update-ca-certificates \
+    && rm -f /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem \
+    && postconf -e 'smtpd_tls_cert_file =' 'smtpd_tls_key_file ='
# Node oficial, versão e checksum fixados a partir do servidor do projeto.
ARG NODE_VERSION=22.23.5
RUN curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    && echo 'cdeb8670a0c81f51b4dc4ac61919f9b1ad917b304bf8221eb939570663d240f8  /tmp/node.tar.xz' | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && rm /tmp/node.tar.xz
RUN npm install --global npm@11.12.1 && npm cache clean --force
COPY --from=tools /out/ /usr/local/bin/
COPY --from=tools /opt/sonar-scanner/ /opt/sonar-scanner/
COPY --from=tools /licenses/ /usr/share/licenses/tools/
COPY scripts/runtime/ /usr/local/bin/
RUN sh /usr/local/bin/setup-image.sh && sh /usr/local/bin/smoke-tools.sh
ARG VERSION=1.6.0
ARG REVISION=unknown
ARG IMAGE_VENDOR="Tools CI/CD"
LABEL org.opencontainers.image.title="Tools Ubuntu" org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$REVISION" org.opencontainers.image.vendor="$IMAGE_VENDOR" \
      org.opencontainers.image.description="DevOps toolbox with OpenBao, Kubernetes, Docker-in-Docker and Postfix" \
      org.opencontainers.image.licenses="NOASSERTION" org.opencontainers.image.base.name="ubuntu:22.04"
ENV TZ=America/Fortaleza
ENTRYPOINT ["/usr/local/bin/start-postfix-dind.sh"]
CMD ["dockerd"]
