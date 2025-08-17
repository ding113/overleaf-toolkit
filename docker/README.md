# Overleaf All-in-One Docker Container

这是一个完全自包含的 Overleaf 部署方案，包含所有必要的服务（Overleaf、MongoDB、Redis），专为 Dokploy 等容器编排平台设计。

## 🚀 特性

- ✅ **All-in-One**: 单个容器包含 Overleaf、MongoDB 6.0、Redis 6.2
- ✅ **自动初始化**: MongoDB replica set 自动配置
- ✅ **数据持久化**: 完整的数据持久化支持
- ✅ **健康检查**: 内置健康检查端点支持 Dokploy
- ✅ **生产就绪**: 包含进程管理、日志记录、优雅关闭
- ✅ **零配置**: 开箱即用，无需手动配置

## 📁 项目结构

```
docker/
├── Dockerfile                    # 主容器镜像
├── scripts/
│   ├── entrypoint.sh            # 容器入口点
│   ├── init-mongo.sh            # MongoDB 初始化
│   ├── start-overleaf.sh        # Overleaf 启动脚本
│   ├── health-server.js         # 健康检查服务
│   └── supervisord.conf         # 进程管理配置
├── config/
│   └── variables.env            # 环境变量配置
└── README.md                    # 本文档
```

## 🔧 Dokploy 部署配置

### 1. 创建应用

在 Dokploy 中创建新应用：

1. **Application Type**: Git 
2. **Source Type**: Git Provider
3. **Repository**: 你的 Git 仓库地址
4. **Branch**: `main` (或你的主分支)
5. **Build Path**: `/docker`
6. **Dockerfile Path**: `./Dockerfile`

### 2. 端口配置

- **Application Port**: `80` (Overleaf 主服务)
- **Health Check Port**: `3000` (健康检查服务)

### 3. 健康检查配置

在 Dokploy 的 "Advanced" → "Swarm Settings" → "Health Check" 中配置：

```json
{
  "Test": [
    "CMD",
    "curl",
    "-f", 
    "http://localhost:3000/health"
  ],
  "Interval": 30000000000,
  "Timeout": 10000000000,
  "StartPeriod": 60000000000,
  "Retries": 3
}
```

### 4. 更新配置 (可选)

在 "Update Config" 中配置自动回滚：

```json
{
  "Parallelism": 1,
  "Delay": 10000000000,
  "FailureAction": "rollback",
  "Order": "start-first"
}
```

## 💾 数据持久化

### 重要的数据目录

容器内的以下目录需要持久化：

| 目录 | 用途 | 重要性 |
|------|------|--------|
| `/data/mongo` | MongoDB 数据库文件 | **关键** |
| `/data/redis` | Redis 持久化数据 | **重要** |
| `/var/lib/overleaf` | Overleaf 用户数据、项目文件 | **关键** |

### Dokploy 中配置持久化

1. 在应用的 "Advanced" 标签中
2. 添加 "Mounts" (挂载点)：

```yaml
# MongoDB 数据持久化
Source: overleaf-mongo-data
Target: /data/mongo
Type: volume

# Redis 数据持久化  
Source: overleaf-redis-data
Target: /data/redis
Type: volume

# Overleaf 用户数据持久化
Source: overleaf-app-data
Target: /var/lib/overleaf
Type: volume
```

## 🌐 环境变量配置

### 基本配置

```bash
# 应用名称
OVERLEAF_APP_NAME="My Overleaf"

# 网站配置
SHARELATEX_SITE_URL="https://overleaf.yourdomain.com"
SHARELATEX_NAV_TITLE="My Overleaf"
```

### 邮件配置 (可选)

```bash
SHARELATEX_EMAIL_FROM_ADDRESS="noreply@yourdomain.com"
SHARELATEX_EMAIL_SMTP_HOST="smtp.gmail.com"
SHARELATEX_EMAIL_SMTP_PORT="587"
SHARELATEX_EMAIL_SMTP_SECURE="false"
SHARELATEX_EMAIL_SMTP_USER="your-email@gmail.com"
SHARELATEX_EMAIL_SMTP_PASS="your-app-password"
```

## 🚀 部署步骤

### 1. 推送代码到 Git 仓库

确保 `docker/` 目录及其所有文件都已提交到你的 Git 仓库。

### 2. 在 Dokploy 中配置应用

按照上述配置创建应用。

### 3. 配置数据持久化

**关键**: 必须配置数据持久化，否则重启后数据会丢失。

### 4. 部署

点击 "Deploy" 按钮，Dokploy 将：
1. 从 Git 拉取代码
2. 构建 Docker 镜像
3. 启动容器
4. 自动初始化所有服务

### 5. 验证部署

- **应用访问**: `http://your-domain/` 
- **健康检查**: `http://your-domain:3000/health`
- **状态页面**: `http://your-domain:3000/status`

## 🔍 故障排除

### 查看日志

在 Dokploy 中查看容器日志：
- MongoDB 日志: `/var/log/mongodb.log`
- Redis 日志: `/var/log/redis.log`
- Overleaf 日志: 通过 supervisor 管理
- 健康检查日志: `/var/log/supervisor/health-check.log`

### 常见问题

1. **容器启动失败**
   - 检查数据目录挂载是否正确
   - 确认端口 80 和 3000 未被占用

2. **MongoDB 连接失败** 
   - 等待 60 秒让 MongoDB 完全初始化
   - 检查数据持久化挂载

3. **健康检查失败**
   - 确认端口 3000 可访问
   - 检查所有服务是否正常启动

## 🔧 高级配置

### 自定义 TeXLive 镜像

```bash
SHARELATEX_TEX_LIVE_IMAGE_NAME="custom/texlive:latest"
```

### 性能调优

```bash
# 增加编译超时时间
SHARELATEX_COMPILE_TIMEOUT="120000"

# 增加上传文件大小限制
SHARELATEX_MAX_UPLOAD_SIZE="100mb"
```

## 📊 监控

健康检查端点提供详细的服务状态：

- `GET /health` - 简单健康状态 (Dokploy 使用)
- `GET /status` - 详细状态信息
- `GET /ping` - 简单 ping 测试

## 🔄 更新和备份

### 更新应用

1. 推送新代码到 Git 仓库
2. 在 Dokploy 中点击 "Deploy"
3. 自动滚动更新，零停机

### 数据备份

定期备份以下 Docker volumes：
- `overleaf-mongo-data`
- `overleaf-redis-data` 
- `overleaf-app-data`

## 📝 注意事项

1. **首次启动**: 首次启动可能需要 2-3 分钟完成初始化
2. **数据持久化**: 务必配置数据持久化，否则数据会丢失
3. **资源要求**: 建议至少 2GB RAM 和 10GB 存储空间
4. **安全性**: 生产环境中请修改默认的 session secret

## 🆘 获取帮助

如果遇到问题：
1. 检查 Dokploy 中的容器日志
2. 访问 `/status` 端点查看服务状态
3. 确认数据持久化配置正确