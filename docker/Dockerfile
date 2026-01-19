FROM debian:bookworm-slim

# 基础信息
LABEL maintainer="your-name"
LABEL description="Terraria Dedicated Server (Vanilla) - Docker"

# 安装运行依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    bash \
    libicu72 \
    && rm -rf /var/lib/apt/lists/*

# Terraria Server 目录
WORKDIR /opt/terraria

# 拷贝 Terraria Server（第一版：手动放入仓库）
# 目录示例：docker/terraria-server/
COPY docker/terraria-server/ /opt/terraria/

# 确保可执行
RUN chmod +x /opt/terraria/TerrariaServer.bin.x86_64

# 拷贝 entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 运行时目录（由 volume 覆盖）
RUN mkdir -p /worlds /config

# Terraria 默认端口
EXPOSE 7777

ENTRYPOINT ["/entrypoint.sh"]
