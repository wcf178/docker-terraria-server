# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

LABEL maintainer="wcf178"
LABEL description="Terraria Dedicated Server (Vanilla)"

# 避免 tzdata 交互
ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list \
    && sed -i 's|security.debian.org|mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list

# 仅安装“真正需要”的依赖（使用 BuildKit 缓存加速重复构建）
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
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
