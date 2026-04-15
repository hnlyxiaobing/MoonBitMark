# MCP

MoonBitMark 的 MCP 接口仍是实验性的，本地可用入口有两个：

- STDIO：`scripts/mcp/moonbitmark-mcp.cmd`
- HTTP：`cmd/mcp-http-server`

## 当前能力

已验证的方法：

- `initialize`
- `tools/list`
- `tools/call`
- `resources/list`
- `resources/read`
- `prompts/list`
- `prompts/get`

已注册工具：

- `inspect_document`
- `convert_to_markdown`
- `upload_document`
- `convert_uploaded_document`

静态资源：

- `moonbitmark://capabilities`
- `moonbitmark://supported-formats`
- `moonbitmark://known-issues`
- `moonbitmark://ocr-boundaries`
- `moonbitmark://mcp-usage`

静态 prompts：

- `convert-document`
- `diagnose-conversion-failure`

## 启动方式

STDIO：

```bat
scripts\mcp\moonbitmark-mcp.cmd
```

PowerShell 版本：

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\mcp\moonbitmark-mcp.ps1
```

HTTP：

```bash
moon run --target native --release -q cmd/mcp-http-server -- --host 127.0.0.1 --port 8765
```

健康检查：

```bash
curl http://127.0.0.1:8765/healthz
```

## HTTP 约定

- `POST /mcp`
- `GET /healthz`

状态码约定：

- 带 `id` 的 JSON-RPC 请求返回 `200`
- 不带 `id` 的 notification 返回 `204`
- 非法 JSON 或非法 JSON-RPC 请求返回 `400`

默认只允许 loopback 绑定；如果要绑定到非本机地址，需要设置 `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL=1`。

## 运行时限制

- `MOONBITMARK_MCP_ALLOWED_ROOTS`：限制可访问文件根目录
- `MOONBITMARK_MCP_ALLOW_HTTP`：控制是否允许 URL 输入
- `MOONBITMARK_MCP_ENABLE_OCR`：控制是否允许 OCR
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`：限制输出长度
- `MOONBITMARK_MCP_MAX_UPLOAD_BYTES`：限制上传体积
- `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL`：控制非 loopback 绑定

这些限制只作用于 MCP 路径，不改变 CLI 默认行为。

## 推荐调用顺序

1. 先调用 `inspect_document`
2. 再调用 `convert_to_markdown`
3. 默认使用 preview 行为，只有确实需要全文时再请求 full 输出
4. 需要结构化结果时传 `response_mode=json`
5. 如果客户端只有字节流，先用 `upload_document` 取得 `resource_uri`

## 不在当前范围内

- SSE
- 流式响应
- 长任务进度通道
- 鉴权
- 远程生产级部署语义

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_security_smoke.ps1
```
