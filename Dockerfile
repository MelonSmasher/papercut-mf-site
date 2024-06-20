FROM --platform=linux/amd64 debian:stable-slim

LABEL org.opencontainers.image.title="PaperCut MF Site Server"
LABEL org.opencontainers.image.description="Docker image that runs a PaperCut MF Site Server"
LABEL org.opencontainers.image.authors="Alex Markessinis <markea125@gmail.com>"

ARG PAPERCUT_MF_VERSION
ARG PAPERCUT_DL_BASE_URL=https://cdn.papercut.com/web/products/ng-mf/installers/mf/
ARG PAPERCUT_MF_SCRIPT=pcmf-setup.sh
ARG PAPERCUT_MF_INSTALL_DIR=/papercut
ARG PAPERCUT_USER=papercut
ARG ENVSUBST_VERSION=1.4.2
ARG ENVSUBST_DOWNLOAD_URL=https://github.com/a8m/envsubst/releases/download/v${ENVSUBST_VERSION}/envsubst-Linux-x86_64

ENV PAPERCUT_UUID_BACKUP_INTERVAL_SECONDS 3600
ENV SMB_NETBIOS_NAME papercut-site
ENV SMB_WORKGROUP WORKGROUP

COPY src/server.properties.template /
COPY src/site-server.properties.template /
COPY src/entrypoint.sh /
COPY src/smb.conf.template /

WORKDIR ${PAPERCUT_MF_INSTALL_DIR}

RUN $(useradd -m -d ${PAPERCUT_MF_INSTALL_DIR} -s /bin/bash ${PAPERCUT_USER} || adduser -D -h ${PAPERCUT_MF_INSTALL_DIR} -s /bin/bash ${PAPERCUT_USER}) && \
    chown -R ${PAPERCUT_USER}:${PAPERCUT_USER} ${PAPERCUT_MF_INSTALL_DIR} && \
    command apt-get update && apt-get install -y \
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
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    chmod +x /entrypoint.sh && \
    curl -o /usr/local/bin/envsubst -L ${ENVSUBST_DOWNLOAD_URL} && chmod +x /usr/local/bin/envsubst

RUN curl -o ${PAPERCUT_MF_SCRIPT} -L ${PAPERCUT_DL_BASE_URL}$(echo ${PAPERCUT_MF_VERSION} | cut -d "." -f 1).x/pcmf-setup-${PAPERCUT_MF_VERSION}.sh && \
    chmod a+rx ${PAPERCUT_MF_SCRIPT} && \
    chown ${PAPERCUT_USER}:${PAPERCUT_USER} ${PAPERCUT_MF_SCRIPT} && \
    sudo -u ${PAPERCUT_USER} -H ./${PAPERCUT_MF_SCRIPT} -v --site-server --non-interactive && \
    rm ${PAPERCUT_MF_SCRIPT} && \
    ${PAPERCUT_MF_INSTALL_DIR}/MUST-RUN-AS-ROOT && \
    rm -rf ${PAPERCUT_MF_INSTALL_DIR}/MUST-RUN-AS-ROOT && \
    chown -R ${PAPERCUT_USER}:${PAPERCUT_USER} ${PAPERCUT_MF_INSTALL_DIR} && \
    /etc/init.d/papercut stop && \
    chmod +x ${PAPERCUT_MF_INSTALL_DIR}/server/bin/linux-x64/setperms && \
    ${PAPERCUT_MF_INSTALL_DIR}/server/bin/linux-x64/setperms && \
    rm -rf /etc/supervisor

COPY src/supervisor /etc/supervisor

RUN chmod 644 /etc/supervisor/supervisord.conf /etc/supervisor/conf.d/*.conf && \
    chmod 755 /etc/supervisor /etc/supervisor/conf.d && \
    chown -R root:root /etc/supervisor

VOLUME /papercut/server/data/conf /papercut/server/custom /papercut/server/logs /papercut/server/data/backups /papercut/server/data/archive
EXPOSE 9163 9164 9165 9191 9192 9193 9194 9195 10389 10636 137/UDP 445 139

ENTRYPOINT ["/entrypoint.sh"]
