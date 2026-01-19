# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# 替换 APT 源（适配 Debian 12 slim）
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

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       bash \
       libicu72 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/terraria

# 拷贝 server 文件
COPY docker/terraria-server/ /opt/terraria/

RUN chmod +x /opt/terraria/TerrariaServer.bin.x86_64

# entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /worlds /config

EXPOSE 7777

ENTRYPOINT ["/entrypoint.sh"]
