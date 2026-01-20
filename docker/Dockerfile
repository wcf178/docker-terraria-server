# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV MONO_CONFIG=/etc/mono/config

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
       libicu72 \
       cron \
       mono-complete \
       libgdiplus \
    && rm -rf /var/lib/apt/lists/*

#######################################
# 创建 monoconfig 文件
#######################################
RUN mkdir -p /etc/mono \
    && echo '<configuration>\n\
  <dllmap dll="i:dl">\n\
    <dllentry dll="__Internal" name="dlopen" target="dlopen"/>\n\
  </dllmap>\n\
</configuration>' > /etc/mono/config

#######################################
# 工作目录
#######################################
WORKDIR /opt/terraria

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