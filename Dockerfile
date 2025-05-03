ARG BUILD_FROM=alpine:latest
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set workdir
WORKDIR /opt

# Copy Python requirements file
COPY requirements.txt /opt/

RUN apk update && apk add curl bash

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base
ARG UPTIME_KUMA_VERSION="1.23.16"
ARG UPTIME_KUMA_COMMIT="9cbbed4bbedead66bda2f883f68cca30e9dd9580"
ARG CLOUDFLARED_VERSION="2025.4.0"
ARG BUILD_ARCH=amd64
# hadolint ignore=DL3003,DL3042
RUN \
    apk add --no-cache --virtual .build-dependencies \
        build-base=0.5-r3 \
        py3-pip=24.3.1-r0 \
    \
    && apk add --no-cache \
        iputils=20240905-r0 \
        nodejs=22.13.1-r0 \
        npm=10.9.1-r0 \
        python3=3.12.10-r0 \
        setpriv=2.40.4-r1 \
    \
    && mkdir -p /opt/uptime-kuma \
    && curl -L -s "https://github.com/therickys93/uptime-kuma/archive/${UPTIME_KUMA_COMMIT}.tar.gz" \
        | tar zxvf - --strip-components 1 -C /opt/uptime-kuma \
    \
    && cd /opt/uptime-kuma \
    \
    && pip install --break-system-packages -r /opt/requirements.txt \
    \
    && npm ci \
        --no-audit \
        --no-fund \
        --no-update-notifier \
        --omit=dev \
    && npm run download-dist \
    \
    && if [ "${BUILD_ARCH}" = "aarch64" ]; then CLOUDFLARED_ARCH="arm64"; \
    elif [ "${BUILD_ARCH}" = "amd64" ]; then CLOUDFLARED_ARCH="amd64"; \
    elif [ "${BUILD_ARCH}" = "armv7" ]; then CLOUDFLARED_ARCH="arm"; fi \
    && curl -L --fail -o /usr/bin/cloudflared \
        "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${CLOUDFLARED_ARCH}" \
    && chmod +x /usr/bin/cloudflared \
    \
    && npm cache clear --force \
    \
    && apk del --no-cache --purge .build-dependencies \
    && rm -fr \
        /tmp/* \
        /root/.cache \ 
        /root/.npm \
        /root/.npmrc

WORKDIR /opt/uptime-kuma

CMD ["npm", "run", "start-server"]
