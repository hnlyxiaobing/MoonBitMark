# MCP Server 测试脚本 (PowerShell)

Write-Host "========================================="
Write-Host "MoonBitMark MCP Server 测试"
Write-Host "========================================="
Write-Host ""

# 检查构建产物是否存在
$BINARY = "_build\native\release\build\cmd\mcp-server\main.exe"

if (-not (Test-Path $BINARY)) {
    Write-Host "❌ 错误: MCP 服务器二进制文件不存在"
    Write-Host "请先运行: moon build --release"
    exit 1
}

Write-Host "✅ 找到 MCP 服务器: $BINARY"
Write-Host ""

# 测试 JSON-RPC 请求
Write-Host "========================================="
Write-Host "测试 1: Initialize 请求"
Write-Host "========================================="

$INIT_REQUEST = '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}},"id":1}'

Write-Host "发送请求:"
Write-Host $INIT_REQUEST
Write-Host ""

Write-Host "预期响应:"
Write-Host '{"jsonrpc":"2.0","result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"moonbitmark","version":"0.7.0","protocolVersion":"2024-11-05"}},"id":1}'
Write-Host ""

# 测试 tools/list 请求
Write-Host "========================================="
Write-Host "测试 2: Tools/List 请求"
Write-Host "========================================="

$TOOLS_LIST_REQUEST = '{"jsonrpc":"2.0","method":"tools/list","id":2}'

Write-Host "发送请求:"
Write-Host $TOOLS_LIST_REQUEST
Write-Host ""

Write-Host "预期响应:"
Write-Host '{"jsonrpc":"2.0","result":{"tools":[{"name":"convert_to_markdown","description":"Convert a document (PDF, DOCX, HTML, etc.) to Markdown format","inputSchema":{"type":"object","properties":{"uri":{"type":"string","description":"URI of the document to convert (file://, http://, https://)"},"required":["uri"]}}]}]},"id":2}'
Write-Host ""

# 测试 tools/call 请求
Write-Host "========================================="
Write-Host "测试 3: Tools/Call 请求"
Write-Host "========================================="

$TOOLS_CALL_REQUEST = '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"convert_to_markdown","arguments":{"uri":"file:///path/to/test.pdf"}},"id":3}'

Write-Host "发送请求:"
Write-Host $TOOLS_CALL_REQUEST
Write-Host ""

Write-Host "预期响应:"
Write-Host '{"jsonrpc":"2.0","result":{"content":[{"type":"text","text":"转换结果..."}],"isError":false},"id":3}'
Write-Host ""

# 测试无效 JSON
Write-Host "========================================="
Write-Host "测试 4: 无效 JSON 请求"
Write-Host "========================================="

$INVALID_JSON_REQUEST = '{invalid json}'

Write-Host "发送请求:"
Write-Host $INVALID_JSON_REQUEST
Write-Host ""

Write-Host "预期响应 (解析错误):"
Write-Host '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error: ..."},"id":null}'
Write-Host ""

# 测试未知方法
Write-Host "========================================="
Write-Host "测试 5: 未知方法请求"
Write-Host "========================================="

$UNKNOWN_METHOD_REQUEST = '{"jsonrpc":"2.0","method":"unknown_method","id":5}'

Write-Host "发送请求:"
Write-Host $UNKNOWN_METHOD_REQUEST
Write-Host ""

Write-Host "预期响应 (方法未找到):"
Write-Host '{"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found: unknown_method"},"id":5}'
Write-Host ""

Write-Host "========================================="
Write-Host "执行测试"
Write-Host "========================================="
Write-Host ""

Write-Host "测试 1: Initialize 请求"
Write-Host "---"
echo $INIT_REQUEST | & $BINARY
Write-Host ""

Write-Host "测试 2: Tools/List 请求"
Write-Host "---"
echo $TOOLS_LIST_REQUEST | & $BINARY
Write-Host ""

Write-Host "测试 3: Tools/Call 请求"
Write-Host "---"
echo $TOOLS_CALL_REQUEST | & $BINARY
Write-Host ""

Write-Host "测试 4: 无效 JSON 请求"
Write-Host "---"
echo $INVALID_JSON_REQUEST | & $BINARY
Write-Host ""

Write-Host "测试 5: 未知方法请求"
Write-Host "---"
echo $UNKNOWN_METHOD_REQUEST | & $BINARY
Write-Host ""

Write-Host "========================================="
Write-Host "✅ 测试完成"
Write-Host "========================================="
