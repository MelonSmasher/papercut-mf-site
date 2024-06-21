FROM --platform=linux/amd64 debian:stable-slim

LABEL org.opencontainers.image.title="PaperCut MF Site Server"
LABEL org.opencontainers.image.description="Docker image that runs a PaperCut MF Site Server"
LABEL org.opencontainers.image.authors="Alex Markessinis <markea125@gmail.com>"

ARG PAPERCUT_MF_VERSION
ARG ENVSUBST_VERSION=1.4.2

ENV PAPERCUT_UUID_BACKUP_INTERVAL_SECONDS 3600
ENV SMB_NETBIOS_NAME papercut-site
ENV SMB_WORKGROUP WORKGROUP

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=debconf,target=/var/cache/debconf,sharing=locked \
    set -exu && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install -y -qq --no-install-recommends \
    ca-certificates \
    curl \
    cups \
    cpio \
    tar \
    unzip \
    bash \
    supervisor \
    samba \
    samba-common \
    samba-common-bin \
    smbclient \
    sudo && \
    truncate -s 0 /var/log/apt/* && \
    truncate -s 0 /var/log/dpkg.log && \
    rm -rf /etc/supervisor

RUN curl -o /usr/local/bin/envsubst -L https://github.com/a8m/envsubst/releases/download/v${ENVSUBST_VERSION}/envsubst-Linux-x86_64 && \
    chmod +x /usr/local/bin/envsubst

RUN useradd -m -d /papercut -s /bin/bash papercut

WORKDIR /papercut

COPY src/server.properties.template /
COPY src/site-server.properties.template /
COPY src/entrypoint.sh /
COPY src/smb.conf.template /
COPY src/supervisor /etc/supervisor

RUN chmod 644 /etc/supervisor/supervisord.conf /etc/supervisor/conf.d/*.conf && \
    chmod 755 /etc/supervisor /etc/supervisor/conf.d && \
    chown -R root:root /etc/supervisor && \
    chmod +x /entrypoint.sh

RUN curl -o pcmf-setup.sh -L https://cdn.papercut.com/web/products/ng-mf/installers/mf/$(echo ${PAPERCUT_MF_VERSION} | cut -d "." -f 1).x/pcmf-setup-${PAPERCUT_MF_VERSION}.sh && \
    chmod a+rx pcmf-setup.sh && \
    chown papercut:papercut pcmf-setup.sh && \
    sudo -u papercut -H ./pcmf-setup.sh -v --site-server --non-interactive && \
    rm pcmf-setup.sh && \
    /papercut/MUST-RUN-AS-ROOT && \
    rm -rf /papercut/MUST-RUN-AS-ROOT && \
    /etc/init.d/papercut stop

VOLUME /papercut/server/data/conf /papercut/server/custom /papercut/server/logs /papercut/server/data/backups /papercut/server/data/archive
EXPOSE 9163 9164 9165 9191 9192 9193 9194 9195 10389 10636 137/UDP 445 139

ENTRYPOINT ["/entrypoint.sh"]
