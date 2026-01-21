# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

#######################################
# Terraria 版本（构建时下载）
#######################################
ARG TERRARIA_VERSION=1449
ENV TERRARIA_VERSION=${TERRARIA_VERSION}

#######################################
# APT 源（Debian 12 slim 适配）
#######################################
RUN printf "Types: deb\n\
URIs: http://mirrors.aliyun.com/debian\n\
Suites: bookworm bookworm-updates\n\
Components: main\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\n\
Types: deb\n\
URIs: http://mirrors.aliyun.com/debian-security\n\
Suites: bookworm-security\n\
Components: main\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg\n" \
> /etc/apt/sources.list.d/debian.sources

#######################################
# 基础依赖
#######################################
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       bash \
       curl \
       unzip \
       procps \
       libicu72 \
       cron \
       screen \
    && rm -rf /var/lib/apt/lists/*

#######################################
# 工作目录
#######################################
WORKDIR /opt/terraria

#######################################
# 预下载 Terraria Server 可执行文件
#######################################
RUN set -eux; \
  DOWNLOAD_URL="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip"; \
  TMP_DIR=/tmp/terraria-server; \
  mkdir -p "${TMP_DIR}" /opt/terraria; \
  echo "[BUILD] Downloading Terraria Server v${TERRARIA_VERSION} from ${DOWNLOAD_URL}"; \
  curl -fL "${DOWNLOAD_URL}" -o "${TMP_DIR}/server.zip"; \
  unzip -q "${TMP_DIR}/server.zip" -d "${TMP_DIR}"; \
  cp -r "${TMP_DIR}/${TERRARIA_VERSION}/Linux/." /opt/terraria/; \
  chmod +x /opt/terraria/TerrariaServer.bin.x86_64; \
  rm -rf "${TMP_DIR}"

#######################################
# Entrypoint
#######################################
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

#######################################
# backup script
#######################################
COPY docker/backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

#######################################
# restore script
#######################################
COPY docker/restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/restore.sh

#######################################
# 数据目录
#######################################
RUN mkdir -p /worlds /config

#######################################
# 端口
#######################################
EXPOSE 7777

ENTRYPOINT ["/entrypoint.sh"]