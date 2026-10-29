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
- `dump_normalized_ast`
- `extract_structure`
- `compare_with_baseline`
- `upload_document`
- `convert_uploaded_document`
- `list_documents`
- `delete_document`

静态资源：

- `moonbitmark://capabilities`
- `moonbitmark://supported-formats`
- `moonbitmark://known-issues`
- `moonbitmark://ocr-boundaries`
- `moonbitmark://mcp-usage`
- `moonbitmark://server-info`

资源模板：

- `moonbitmark://document/{id}`（`upload_document` 写入、`list_documents` /
  `delete_document` 管理的上传文档）

静态 prompts：

- `convert-document`
- `diagnose-conversion-failure`
- `batch-convert`

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
- `MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP`：控制是否允许抓取私网 / 回环地址（默认关闭）
- `MOONBITMARK_MCP_ENABLE_OCR`：控制是否允许 OCR
- `MOONBITMARK_MCP_MAX_OUTPUT_CHARS`：限制输出长度
- `MOONBITMARK_MCP_MAX_UPLOAD_BYTES`：限制上传体积
- `MOONBITMARK_MCP_HTTP_ALLOW_NONLOCAL`：控制非 loopback 绑定

这些限制只作用于 MCP 路径，不改变 CLI 默认行为。

### 文件输入的路径校验分两层

1. **词法层**（同步）：把路径归一化、消解 `.` / `..`，并按段剥掉 Windows 内核在打开文件时会剥掉的**尾随点和空格**（`.. `、`.. .`、`a...` 这类写法与内核语义对齐），再与 `MOONBITMARK_MCP_ALLOWED_ROOTS` 做前缀比较。
2. **真实路径层**（异步）：对通过词法检查的路径调用 `realpath`，解析符号链接、NTFS junction 与 8.3 短名后再比较一次。目标文件尚不存在时（例如后续才会写出的输出路径），退化为「父目录 realpath + 末段」。越界的错误文案带 `after symlink resolution` 前缀，便于与词法层失败区分。

词法层看不到符号链接，真实路径层看不到不存在的目标，所以两层缺一不可。

### 私网 URL 默认拒绝

`MOONBITMARK_MCP_ALLOW_HTTP=1` 只表示「允许 URL 输入」，**不等于**可以抓任意地址。默认还会拒绝私网 / 回环目标，命中即报错并在文案里提示设置 `MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP=1`：

- `localhost`、`*.localhost`、`*.local`、`*.internal`、`*.lan`、`*.home.arpa`
- IPv4：`127/8`、`10/8`、`192.168/16`、`172.16/12`、`169.254/16`（云元数据）、`0/8`、`100.64/10`（CGNAT）、`224/4` 及以上
- IPv6：`::`、`::1`、`fc00::/7`、`fe80::/10`、`::ffff:` 映射地址
- 无法静态判定的写法（纯十进制整数如 `2130706433`、`0x` 十六进制、点分不足四段如 `127.1`）：按私有处理（失败即关闭）
- `http://example.com@127.0.0.1/` 这类 userinfo 伪装：取最后一个 `@` 之后的主机名再判定
- 主机名先归一化再判定：剥掉**全部尾随 `.`**（FQDN 根点，`127.0.0.1.` 与 `127.0.0.1` 等义）与尾随空格；剥完为空（`http://./x`）按私有处理
- 主机名字符集白名单：只接受 `a-z`、`0-9`、`.`、`-`、`_`、`:`、`[`、`]`。含 `%`（百分号编码，如 `127%2e0%2e0%2e1`）、空白、控制字符或非 ASCII 字符（IDN、全角点 `。`、同形字符）的主机名一律拒绝，**无需解码**即挡在分类逻辑之前

**残余风险**：本层只看 URL 里的字面主机名，**公网域名解析到私网 IP**（DNS rebinding、内网域名解析劫持）拦不住，需要在真正抓取的那一层对解析结果再做一次校验。抓取私网资源的显式开关 `MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP=1` 会同时放开上述全部规则。另外，字符集白名单带来的取舍是：**主机名含 `%` 编码或非 ASCII 字符的 URL 会被拒绝**（`http://例子.测试/x` 这类 IDN 目标也在此列），这类目标需要设置 `MOONBITMARK_MCP_ALLOW_PRIVATE_HTTP=1` 才能抓取。


## 推荐调用顺序

1. 先调用 `inspect_document`
2. 再调用 `convert_to_markdown`
3. 默认使用 preview 行为，只有确实需要全文时再请求 full 输出
4. 需要结构化结果时传 `response_mode=json`
5. 如果客户端只有字节流，先用 `upload_document` 取得 `resource_uri`

## format_hint 参数

`format_hint` 是**建议性**参数，用于在内容嗅探不可靠时覆盖探测结果。它只接受已注册的转换器名，匹配前会先去掉首尾空白并转小写：

`text`、`csv`、`json`、`pdf`、`html`、`docx`、`doc`、`pptx`、`xlsx`、`epub`、`image`

- 传入上表之外的值（例如 `pdfx`、`text/plain`、`xhtml`、`wps`）**不会报错**，而是被忽略，转换按探测到的格式继续。
- schema 没有为 `format_hint` 声明 `enum`，所以无法识别的值不会在协议层被拒绝；调用方应读取回显的 `effective_format`，而不是假定自己的字符串一定生效。
- `format_hint_applied` 表示 hint **既已提供、又被采纳**（即落在上表内）。无法识别的 hint 回显 `false`，此时 `effective_format` 与 `detected_format` 相同。

## 结构化输出

当 `response_mode=json` 时，工具会在 `structuredContent` 中返回稳定字段，而不仅是文本 summary。

当前公共字段包括：

- `content`
- `metadata`
- `diagnostics`
- `stats`

调试型工具会额外返回：

- `explanations.normalizer`
- `explanations.headings`
- `explanations.tables`
- `explanations.ocr`
- `explanations.uncertainties`
- `explanations.comparison_debug`（仅 `compare_with_baseline`）
- `normalized_document` 或 `semantic_document`

解释性输出当前主要回答：

- normalizer 对每个 block 做了哪些步骤、哪些步骤生效、改前改后是什么
- 为什么 heading 被判成当前层级
- 为什么 table 被保留或降级
- 为什么触发或未触发 OCR
- 当前有哪些不确定点
- baseline compare 这次为什么能跑/没跑、agreement metric 哪些强、哪些弱

`inspect_document` 仍是 preflight 工具，因此它的解释更偏“可能发生什么”；真正的结构解释要以 `convert_to_markdown`、`dump_normalized_ast` 或 `extract_structure` 的结果为准。

## 不在当前范围内

- SSE
- 流式响应
- 长任务进度通道
- 鉴权
- 远程生产级部署语义

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_ocr_mcp_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_stdio_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_resources_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_prompts_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_security_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/integration/mcp_http_security_smoke.ps1
```
