# 使用本地 Terraria 服务器文件

## 功能说明

通过 `USE_LOCAL_FILES` 环境变量，你可以控制 Docker 构建时是否使用本地 Terraria 服务器文件而不是从网络下载。

## 使用方法

### 1. 设置环境变量

在 `.env` 文件中设置：
```bash
# 使用本地文件 (设置为 1)
USE_LOCAL_FILES=1

# Terraria 版本 (当使用网络下载时需要)
TERRARIA_VERSION=1449
```

### 2. 准备本地文件

如果 `USE_LOCAL_FILES=1`，你需要将 Terraria 服务器文件放置在 `docker/terraria-server/` 目录中：

```bash
# 创建目录
mkdir -p docker/terraria-server

# 方法1: 手动下载和解压
curl -L -o terraria-server.zip https://terraria.org/api/download/pc-dedicated-server/terraria-server-1449.zip
unzip terraria-server.zip
cp -r 1449/Linux/* docker/terraria-server/
rm terraria-server.zip

# 方法2: 从现有安装复制
# 如果你已经安装了 Terraria 服务器，将文件复制到 docker/terraria-server/
cp -r /path/to/your/terraria/server/* docker/terraria-server/
```

### 3. 构建镜像

```bash
# 使用本地文件构建
docker compose build

# 或者强制重新构建
docker compose build --no-cache
```

## 文件结构

`docker/terraria-server/` 目录应包含以下文件：
```
docker/terraria-server/
├── TerrariaServer.bin.x86_64
├── TerrariaServer.exe
├── Terraria.png
├── FNA.dll
├── FNA.dll.config
├── Mono.Posix.dll
├── Mono.Security.dll
├── System.Configuration.dll
├── System.Core.dll
├── System.Data.dll
├── System.dll
├── System.Drawing.dll
├── System.Runtime.Serialization.dll
├── System.Security.dll
├── System.Windows.Forms.dll
├── System.Windows.Forms.dll.config
├── System.Xml.dll
├── System.Xml.Linq.dll
├── mscorlib.dll
├── monoconfig
├── monomachineconfig
├── changelog.txt
├── open-folder
└── lib64/
    ├── libFAudio.so.0
    ├── libFNA3D.so.0
    ├── libSDL2-2.0.so.0
    ├── libSDL2_image-2.0.so.0
    ├── libSDL2.so
    ├── libfreetype.so.6
    ├── libjpeg.so.62
    ├── libmojoshader.so
    ├── libogg.so.0
    ├── libopenal.so.1
    ├── libpng15.so.15
    ├── libtheoradec.so.1
    ├── libtheorafile.so
    ├── libvorbis.so.0
    └── libvorbisfile.so.3
```

## 故障排除

### 构建日志显示正在下载而不是使用本地文件

检查：
1. `USE_LOCAL_FILES` 是否设置为 `1`
2. `docker/terraria-server/` 目录是否存在且包含文件
3. 文件权限是否正确

### 本地文件不存在的错误

如果设置了 `USE_LOCAL_FILES=1` 但目录不存在，构建会自动回退到网络下载。

## 优势

- **更快的构建**：避免网络下载
- **离线构建**：在无网络环境中构建
- **版本控制**：将服务器文件纳入版本控制
- **一致性**：确保所有环境使用相同版本的服务器文件