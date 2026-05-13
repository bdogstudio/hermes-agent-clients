# Hermes iOS

SwiftUI 版 Hermes Agent 客户端，用来在 iPhone 上连接已经部署好的 Hermes API Server。

## 当前功能

- 实时消息：`/v1/chat/completions` SSE 流式输出
- 会话保持：`/v1/responses`，自动续接 `previous_response_id`
- Runs：`/v1/runs` + `/v1/runs/{run_id}/events`
- 定时任务：`/api/jobs` 列表、创建、暂停、恢复、立即运行、删除
- 设置：Base URL、API Key、模型、系统提示、max_tokens
- API Key 使用 iOS Keychain 保存

## 运行

1. 安装并打开 Xcode。
2. 执行：
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. 打开：
   ```text
   hermes-ios/HermesIOS.xcodeproj
   ```
4. 在 Xcode 的 Signing & Capabilities 中选择你的 Team。
5. 连接 iPhone，选择真机，点击 Run。

## HTTP 说明

当前默认 Base URL 是：

```text
http://YOUR_HERMES_HOST:8642/v1
```

项目已在生成的 Info.plist 里放开 HTTP。长期使用建议给 Hermes API Server 加 HTTPS。
