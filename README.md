# ai-news

个人资讯管理系统的 MVP，基于 `RSSHub + Huginn`。

当前版本已经补齐：

- 主题配置文件
- RSSHub + Huginn + Postgres 的本地编排
- 基于官方 Huginn 镜像的本地修复构建
- 从 `topics.yaml` 生成 Huginn 场景的脚本
- 一个可导入的 Huginn 抓取场景样板

## 目录

- `config/topics.yaml` 主题配置
- `huginn/scenarios/ai-news-mvp.json` Huginn 场景样板
- `huginn/scenarios/ai-news-generated.json` 自动生成的 Huginn 场景
- `scripts/generate_huginn_scenario.rb` 场景生成器
- `docker-compose.yml` 本地启动编排
- `docker/huginn/Dockerfile` Huginn 本地修复镜像
- `.env.example` 环境变量模板

## MVP 做什么

1. 你在 `config/topics.yaml` 里定义关注主题和 RSSHub 路由。
2. 运行生成脚本，把主题配置转成 Huginn 场景 JSON。
3. RSSHub 统一把这些来源转成 RSS。
4. Huginn 定时抓取这些 RSS，并保留事件。

这个版本先不做飞书推送和历史总结，只先把“采集链路”跑通。

这里保留 `Postgres`，不再加 `Redis`。原因很直接：当前 `Huginn` 官方镜像依赖 `MySQL` 或 `PostgreSQL`，并不能直接用 `SQLite` 运行。

## 当前验证状态

2026-04-19 本地实际验证结果：

- `RSSHub` 容器可以正常启动
- `Huginn + SQLite` 不可行：官方镜像未包含 `sqlite3` adapter
- `Huginn + Postgres` 的当前 `ghcr.io/huginn/huginn:latest` 原始镜像缺少 `pg` gem
- 当前仓库通过本地 `Dockerfile` 在官方镜像上补跑 `bundle install`，已经成功跑通
- Huginn 已完成数据库迁移并成功监听 `0.0.0.0:3000`
- Huginn 数据库已完成初始化，可使用 `admin / password` 登录

## 启动方式

1. 复制环境变量模板：

```bash
cp .env.example .env
```

2. 填好 `HUGINN_APP_SECRET_TOKEN`。
3. 启动服务：

```bash
docker compose up -d
```

4. 根据主题配置生成 Huginn 场景：

```bash
ruby scripts/generate_huginn_scenario.rb
```

5. 初始化 Huginn 数据库和示例账号：

```bash
docker compose exec huginn bundle exec rake db:seed RAILS_ENV=production SEED_USERNAME=admin SEED_PASSWORD=password
```

6. 打开 Huginn：

- 默认模板：`http://localhost:3000`
- 当前本地 `.env`：`http://localhost:17000`
- 默认登录：`admin / password`

7. 在 Huginn UI 里导入：

- `huginn/scenarios/ai-news-generated.json`

## RSSHub 路由

当前示例主题使用的是 RSSHub 官方文档里可用的路由：

- `/github/topics/ai`
- `/github/search/agent%20workflow/bestmatch/desc`
- `/anthropic/news`
- `/anthropic/research`
- `/huggingface/daily-papers/week/50`
- `/hackernews/index/sources`
- `/github/trending/daily/javascript/en`
- `/web/blog`

## Huginn 场景

`huginn/scenarios/ai-news-mvp.json` 是一个可作为起点的场景样板。

`huginn/scenarios/ai-news-generated.json` 是根据 `config/topics.yaml` 自动生成的导入文件。

自动生成的场景包含：

- 每个主题 1 个 `TriggerAgent`
- 每条 RSSHub 路由 1 个 `RssAgent`
- RSS 源到主题过滤器的自动连线

改关注主题时的流程：

- 修改 `config/topics.yaml`
- 运行 `ruby scripts/generate_huginn_scenario.rb`
- 在 Huginn 里重新导入 `huginn/scenarios/ai-news-generated.json`

导入后，你可以继续在 Huginn UI 里：

- 修改关键词
- 增加主题分流
- 加上后续通知动作

## 下一步

如果你要，我下一步可以继续把这套 MVP 往前推进两步：

1. 补一个本地资讯归档服务，把 Huginn 抓到的事件写入 SQLite
2. 接上飞书机器人，做每天的 Top 资讯推送
