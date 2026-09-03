# 切问学术内部接口观察记录

观察日期：2026-09-02。内容来自当前检索页前端 bundle 的静态分析；没有保存用户 token、Cookie、授权码或实际检索内容。

## 基础配置

- 前端页面：`https://qiewenpaper.com/app/search`
- API 网关：`https://gateway.qiewenpaper.com`
- 路径前缀：`/api/v1`
- 常规请求最终形态：`https://gateway.qiewenpaper.com/api/v1/<path>`
- 登录请求使用当前会话的 `Authorization: Bearer <session-token>`。前端还存在访客 `api_key` 回退路径；不要提取、复制或展示任何实际凭据。

前端的 HTTP client 默认发送 JSON，并期望 JSON 响应包含 `success` 和 `data` 字段；成功时通常返回 `data`。

## 主要文献相关端点

| 用途 | 方法 | 路径 | 传输 |
|---|---:|---|---|
| 主检索/深度检索 | POST | `/search/completions` | SSE |
| 知识库学术问答 | POST | `/kb/chat/completions` | SSE |
| 新手引导检索 | POST | `/search/onboarding/stream` | SSE |
| 聊天/检索历史 | POST | `/search/history` | JSON |
| 共享检索历史 | GET | `/search/completion/shared/{uuid}` | JSON |
| 引用生成 | POST | `/search/paper/cite` | JSON |
| 中断检索 | POST | `/search/completion/break` | JSON |
| 消息反馈 | POST | `/search/message/vote` | JSON |
| 快速检索反馈 | POST | `/search/quick-search/vote` | JSON |

## 检索请求形态

主检索 SSE 请求的结构大致为：

```http
POST https://gateway.qiewenpaper.com/api/v1/search/completions
Accept: text/event-stream
Content-Type: application/json
Authorization: Bearer <current-session-token>
```

```json
{
  "message": "用户的研究问题",
  "session_id": "会话 ID",
  "language": "zh",
  "public_collection_id": null,
  "public_collection_short_name": null,
  "stream": false,
  "search_scholar": true,
  "slow_search": true,
  "offset": 0,
  "limit": 20
}
```

实际调用会根据页面状态附加 metadata，例如检索类别、续跑标记、公共集合字段和分析字段。代码还会设置 `x-billing` 请求头；其具体值由页面当前动作决定，不应硬编码。

学术问答使用同一网关下的 `/kb/chat/completions`，请求通常还会带 `team_id`、`item_id`、`search_modes` 等上下文字段。

## SSE 解析

- 响应为 `text/event-stream`，前端读取响应流并解析 `data: ...` 行。
- `[PENDING]` 表示任务状态更新；普通 data 内容作为增量消息。
- `[DONE]` 表示完成。完成后前端会调用 `/search/history` 获取最终消息和分页信息。
- 需要取消时，前端会中止请求；页面级中断接口为 `/search/completion/break`，请求体含 `chat_id`。

## 维护边界

- 这些是网页内部接口，不是稳定的公开 API；前端 bundle、字段和路径可能变化。
- 当前观测 bundle：`/base-search/assets/index-DbDHqzUa.js`。
- 若实际页面行为与本记录不符，应重新检查当前前端资源或页面可见调用；不要猜测接口变体，也不要为了验证而消耗额度。
