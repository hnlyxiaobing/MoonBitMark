#!/bin/bash
# MCP Server 测试脚本

set -e

echo "========================================="
echo "MoonBitMark MCP Server 测试"
echo "========================================="
echo ""

# 检查构建产物是否存在
BINARY="_build/native/release/build/cmd/mcp-server/main.exe"

if [ ! -f "$BINARY" ]; then
    echo "❌ 错误: MCP 服务器二进制文件不存在"
    echo "请先运行: moon build --release"
    exit 1
fi

echo "✅ 找到 MCP 服务器: $BINARY"
echo ""

# 测试 JSON-RPC 请求
echo "========================================="
echo "测试 1: Initialize 请求"
echo "========================================="

INIT_REQUEST='{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}},"id":1}'

echo "发送请求:"
echo "$INIT_REQUEST"
echo ""

echo "预期响应:"
echo '{"jsonrpc":"2.0","result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"moonbitmark","version":"0.7.0","protocolVersion":"2024-11-05"}},"id":1}'
echo ""

# 测试 tools/list 请求
echo "========================================="
echo "测试 2: Tools/List 请求"
echo "========================================="

TOOLS_LIST_REQUEST='{"jsonrpc":"2.0","method":"tools/list","id":2}'

echo "发送请求:"
echo "$TOOLS_LIST_REQUEST"
echo ""

echo "预期响应:"
echo '{"jsonrpc":"2.0","result":{"tools":[{"name":"convert_to_markdown","description":"Convert a document (PDF, DOCX, HTML, etc.) to Markdown format","inputSchema":{"type":"object","properties":{"uri":{"type":"string","description":"URI of the document to convert (file://, http://, https://)"},"required":["uri"]}}]}]},"id":2}'
echo ""

# 测试 tools/call 请求
echo "========================================="
echo "测试 3: Tools/Call 请求 (无效参数)"
echo "========================================="

TOOLS_CALL_REQUEST='{"jsonrpc":"2.0","method":"tools/call","params":{"name":"convert_to_markdown","arguments":{"uri":"file:///path/to/test.pdf"}},"id":3}'

echo "发送请求:"
echo "$TOOLS_CALL_REQUEST"
echo ""

echo "预期响应:"
echo '{"jsonrpc":"2.0","result":{"content":[{"type":"text","text":"转换结果..."}],"isError":false},"id":3}'
echo ""

# 测试无效 JSON
echo "========================================="
echo "测试 4: 无效 JSON 请求"
echo "========================================="

INVALID_JSON_REQUEST='{invalid json}'

echo "发送请求:"
echo "$INVALID_JSON_REQUEST"
echo ""

echo "预期响应 (解析错误):"
echo '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error: ..."},"id":null}'
echo ""

# 测试未知方法
echo "========================================="
echo "测试 5: 未知方法请求"
echo "========================================="

UNKNOWN_METHOD_REQUEST='{"jsonrpc":"2.0","method":"unknown_method","id":5}'

echo "发送请求:"
echo "$UNKNOWN_METHOD_REQUEST"
echo ""

echo "预期响应 (方法未找到):"
echo '{"jsonrpc":"2.0","error":{"code":-32601,"message":"Method not found: unknown_method"},"id":5}'
echo ""

echo "========================================="
echo "测试场景说明"
echo "========================================="
echo ""
echo "要执行这些测试,请运行以下命令:"
echo ""
echo "  echo '$INIT_REQUEST' | $BINARY"
echo "  echo '$TOOLS_LIST_REQUEST' | $BINARY"
echo "  echo '$TOOLS_CALL_REQUEST' | $BINARY"
echo "  echo '$INVALID_JSON_REQUEST' | $BINARY"
echo "  echo '$UNKNOWN_METHOD_REQUEST' | $BINARY"
echo ""
echo "或者使用交互式测试:"
echo ""
echo "  echo '启动交互式测试...' | $BINARY"
echo "  (在标准输入中输入 JSON-RPC 请求)"
echo ""
echo "========================================="
echo "✅ 测试脚本准备完成"
echo "========================================="
