# Hermes Mac Chat

一个面向 macOS 的 Hermes Agent 桌面消息客户端。Mac 端只负责发送消息、接收 Hermes 后端事件和展示结果；LLM、工具调用、记忆、终端能力都由已经部署好的 Hermes Agent 后端处理。

## 启动

```bash
cd hermes-mac-chat
npm install
npm start
```

也可以通过环境变量预设部署地址：

```bash
HERMES_BASE_URL="http://YOUR_HERMES_HOST:8642" \
HERMES_API_KEY="your-api-server-key" \
npm start
```

## 连接配置

窗口左下角填写：

- 云端地址：默认 `http://YOUR_HERMES_HOST:8642`
- API Key：Hermes 后端的 `API_SERVER_KEY`
- Hermes 模型：默认 `hermes-agent`
- 系统提示：可选，会作为 `system` message 或 `instructions` 传给 Hermes
- 输出上限：可选，对应 `max_tokens`
- Responses 使用流式输出：打开后 `/v1/responses` 也会使用 SSE

## 模式

- 实时消息：使用 `/v1/chat/completions` 的流式接口，像聊天软件一样边生成边接收。
- 会话保持：使用 `/v1/responses`，自动带上上一条 `previous_response_id` 续聊。
- Runs：使用 `/v1/runs` 提交异步任务，并监听 `/v1/runs/{run_id}/events`。
- 定时任务：使用 `/api/jobs` 管理 Cron Job，可创建、刷新、暂停、恢复、立即运行和删除。

## 云端要求

Hermes API Server 需要开放：

- `GET /v1/health`
- `GET /health`
- `GET /health/detailed`
- `GET /v1/models`
- `POST /v1/chat/completions`
- `POST /v1/responses`
- `GET /v1/responses/{response_id}`
- `DELETE /v1/responses/{response_id}`
- `POST /v1/runs`
- `GET /v1/runs/{run_id}/events`
- `GET /api/jobs`
- `POST /api/jobs`
- `POST /api/jobs/{job_id}/pause`
- `POST /api/jobs/{job_id}/resume`
- `POST /api/jobs/{job_id}/run`
- `DELETE /api/jobs/{job_id}`

认证方式：

```http
Authorization: Bearer <API_SERVER_KEY>
```
