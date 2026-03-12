# MoonBitMark MCP 服务设计文档

**版本:** 1.0
**日期:** 2026-03-12
**作者:** WorkBuddy
**状态:** 设计阶段

---

## 一、项目概述

### 1.1 项目目标

为 MoonBitMark 项目添加 Model Context Protocol (MCP) 服务能力,使其能够作为 MCP 服务器运行,供 AI 助手(如 Claude Desktop)直接调用进行文档转换。

### 1.2 设计原则

1. **简洁优先** - 优先实现核心功能,避免过度设计
2. **类型安全** - 充分利用 MoonBit 的静态类型系统
3. **无依赖** - 尽量使用 MoonBit 标准库,减少外部依赖
4. **渐进式开发** - 先实现 STDIO 传输,HTTP/SSE 作为后续增强功能
5. **兼容性** - 遵循 MCP 0.5.0 规范,与现有 MCP 客户端兼容

---

## 二、MCP 协议调研分析

### 2.1 MCP 协议核心概念

**MCP (Model Context Protocol)** 是由 Anthropic 提出的开放协议,用于标准化 AI 模型与外部数据源、工具之间的交互。

#### 核心特性:

1. **基于 JSON-RPC 2.0** - 所有消息都遵循 JSON-RPC 2.0 规范
2. **客户端-服务器架构** - MCP Host/MCP Client 与 MCP Server 通信
3. **多种传输方式** - 支持 STDIO、HTTP、SSE 等传输层
4. **三大核心能力**:
   - **Tools (工具)**: 服务器暴露的可调用函数
   - **Resources (资源)**: 服务器暴露的数据文件
   - **Prompts (提示)**: 服务器提供的可重用消息模板

### 2.2 JSON-RPC 2.0 消息格式

#### 请求消息 (Request)

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "convert_to_markdown",
    "arguments": {
      "uri": "file:///path/to/document.pdf"
    }
  },
  "id": 1
}
```

#### 响应消息 (Response)

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "# Converted Markdown\n\n..."
      }
    ]
  },
  "id": 1
}
```

#### 错误响应

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": null
  },
  "id": 1
}
```

### 2.3 MarkitDown MCP 实现分析

#### 技术栈:

- **Python** - 实现语言
- **FastMCP** - 简化的 MCP 服务器框架
- **uvicorn + Starlette** - HTTP/SSE 支持
- **MarkItDown** - 核心文档转换库

#### 核心工具:

```python
@mcp.tool()
async def convert_to_markdown(uri: str) -> str:
    """Convert a resource described by an http:, https:, file: or data: URI to markdown"""
    return MarkItDown(enable_plugins=check_plugins_enabled()).convert_uri(uri).markdown
```

#### 支持的传输方式:

1. **STDIO** - 默认,通过标准输入输出通信
2. **HTTP + SSE** - 可选,支持流式 HTTP 传输

---

## 三、MoonBitMark MCP 服务架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    MCP Client (AI 助手)                      │
│                    (Claude Desktop 等)                        │
└────────────────────────────┬────────────────────────────────┘
                             │ MCP 协议
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                  MoonBitMark MCP Server                       │
├─────────────────────────────────────────────────────────────┤
│  传输层 (Transport Layer)                                    │
│  ┌─────────────┐  ┌─────────────┐                           │
│  │ STDIO       │  │ HTTP/SSE    │  (未来)                    │
│  │ Transport   │  │ Transport   │                           │
│  └──────┬──────┘  └──────┬──────┘                           │
├─────────┴────────────────┴─────────────────────────────────┤
│  协议层 (Protocol Layer)                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  JSON-RPC 2.0 处理器                                 │   │
│  │  - 请求解析                                         │   │
│  │  - 方法路由                                         │   │
│  │  - 响应生成                                         │   │
│  │  - 错误处理                                         │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  MCP 核心层 (MCP Core Layer)                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Server      │  │ Handler     │  │ Tool        │          │
│  │            │  │            │  │ Registry    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  业务逻辑层 (Business Logic Layer)                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  MoonBitMark 文档转换器                              │   │
│  │  - URI 解析                                         │   │
│  │  - 格式检测                                         │   │
│  │  - 转换执行                                         │   │
│  │  - 结果封装                                         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 模块划分

| 模块 | 路径 | 职责 |
|------|------|------|
| **mcp/core** | src/mcp/core/ | MCP 核心类型和接口定义 |
| **mcp/protocol** | src/mcp/protocol/ | JSON-RPC 2.0 协议处理 |
| **mcp/transport** | src/mcp/transport/ | 传输层抽象 (STDIO/HTTP) |
| **mcp/handler** | src/mcp/handler/ | MCP 请求处理器 |
| **mcp/types** | src/mcp/types/ | MCP 协议类型定义 |
| **cmd/mcp-server** | cmd/mcp-server/ | MCP 服务器 CLI 入口 |

### 3.3 目录结构设计

```
MoonBitMark/
├── src/
│   ├── core/              # 现有核心模块
│   ├── formats/           # 现有转换器
│   └── mcp/               # 新增 MCP 模块
│       ├── moon.pkg       # MCP 包配置
│       ├── types/
│       │   ├── moon.pkg
│       │   ├── jsonrpc.mbt    # JSON-RPC 2.0 类型
│       │   ├── mcp.mbt        # MCP 协议类型
│       │   └── tool.mbt       # 工具定义
│       ├── protocol/
│       │   ├── moon.pkg
│       │   ├── jsonrpc.mbt    # JSON-RPC 处理器
│       │   └── mcp.mbt        # MCP 协议处理器
│       ├── transport/
│       │   ├── moon.pkg
│       │   ├── stdio.mbt      # STDIO 传输
│       │   └── http.mbt       # HTTP 传输 (未来)
│       └── handler/
│           ├── moon.pkg
│           ├── tools.mbt      # 工具调用处理
│           └── server.mbt     # 服务器主逻辑
├── cmd/
│   ├── main/              # 现有 CLI 入口
│   └── mcp-server/        # 新增 MCP 服务器入口
│       ├── moon.pkg
│       └── main.mbt
└── tests/
    └── mcp/               # MCP 模块测试
```

---

## 四、核心技术设计

### 4.1 JSON-RPC 2.0 类型定义

#### 请求类型 (src/mcp/types/jsonrpc.mbt)

```moonbit
/// JSON-RPC 2.0 请求
pub struct JsonRequest {
  jsonrpc : String     // 必须为 "2.0"
  method : String      // 方法名
  params : JsonValue?  // 参数 (可选)
  id : JsonId?         // 请求 ID (可选,通知则省略)
} derive(ToJson, FromJson)

/// JSON-RPC 2.0 响应
pub struct JsonResponse {
  jsonrpc : String
  result : JsonValue?  // 成功结果
  error : JsonError?   // 错误信息
  id : JsonId?         // 对应的请求 ID
} derive(ToJson, FromJson)

/// JSON-RPC 2.0 错误
pub struct JsonError {
  code : Int
  message : String
  data : JsonValue?
} derive(ToJson, FromJson)

/// JSON-RPC ID (可以是字符串、数字或 null)
pub type JsonId =
  | StringId(String)
  | NumberId(Int)
  | NullId

pub fn JsonId::to_json(self : JsonId) -> JsonValue {
  match self {
    StringId(s) => JsonValue::String(s)
    NumberId(n) => JsonValue::Number(n)
    NullId => JsonValue::Null
  }
}

pub fn JsonId::from_json(v : JsonValue) -> JsonId? {
  match v {
    JsonValue::String(s) => Some(StringId(s))
    JsonValue::Number(n) => Some(NumberId(n))
    JsonValue::Null => Some(NullId)
    _ => None
  }
}
```

### 4.2 MCP 协议类型定义

#### MCP 类型 (src/mcp/types/mcp.mbt)

```moonbit
/// MCP 工具定义
pub struct McpTool {
  name : String
  description : String
  input_schema : JsonValue  // JSON Schema
} derive(ToJson, FromJson)

/// MCP 工具调用参数
pub struct McpToolCallParams {
  name : String
  arguments : JsonValue
} derive(FromJson)

/// MCP 工具调用结果
pub struct McpToolResult {
  content : Vec[McpContent]
  isError : Bool  // 默认 false
} derive(ToJson, FromJson)

/// MCP 内容类型
pub type McpContent =
  | TextContent {
      type : String  // "text"
      text : String
    }
  | ImageContent {
      type : String   // "image"
      data : String   // base64
      media_type : String
    }
  | ResourceContent {
      type : String   // "resource"
      uri : String
      text : String?
    }

/// MCP 服务器信息
pub struct McpServerInfo {
  name : String
  version : String
  protocol_version : String
} derive(ToJson)

/// MCP 初始化请求参数
pub struct McpInitializeParams {
  protocol_version : String
  capabilities : McpClientCapabilities
  client_info : McpClientInfo
} derive(FromJson)

/// MCP 初始化响应
pub struct McpInitializeResult {
  protocol_version : String
  capabilities : McpServerCapabilities
  server_info : McpServerInfo
} derive(ToJson)
```

### 4.3 工具注册表设计

```moonbit
// src/mcp/handler/tools.mbt

/// 工具函数类型
pub type ToolHandler = (JsonValue) -> McpToolResult raise

/// 工具注册表
pub struct ToolRegistry {
  tools : Map[String, ToolDefinition]
}

pub struct ToolDefinition {
  name : String
  description : String
  handler : ToolHandler
  input_schema : JsonValue
}

impl ToolRegistry {
  /// 创建空注册表
  pub fn new() -> ToolRegistry {
    { tools: Map::empty() }
  }

  /// 注册工具
  pub fn register(self : ToolRegistry, tool : ToolDefinition) -> ToolRegistry raise {
    if self.tools.contains(tool.name) {
      fail("Tool already registered: " + tool.name)
    }
    { tools: self.tools.insert(tool.name, tool) }
  }

  /// 调用工具
  pub fn call(self : ToolRegistry, name : String, args : JsonValue) -> McpToolResult raise {
    match self.tools.get(name) {
      Some(tool) => tool.handler(args)
      None => {
        // 返回错误结果
        {
          content: [
            TextContent {
              type: "text",
              text: "Tool not found: " + name
            }
          ],
          isError: true
        }
      }
    }
  }

  /// 列出所有工具
  pub fn list(self : ToolRegistry) -> Vec[McpTool] {
    self.tools.values().map(fn(t) {
      {
        name: t.name,
        description: t.description,
        input_schema: t.input_schema
      }
    }).to_vec()
  }
}
```

### 4.4 STDIO 传输层设计

```moonbit
// src/mcp/transport/stdio.mbt

/// STDIO 传输实现
pub struct StdioTransport {
  // 无需状态,直接使用标准输入输出
}

impl StdioTransport {
  pub fn new() -> StdioTransport {
    StdioTransport()
  }

  /// 读取 JSON-RPC 请求
  pub fn read_request(self : StdioTransport) -> JsonRequest raise {
    // 从标准输入读取 JSON 行
    let line = @io.stdin().read_line()?
    match JsonValue::from_string(line) {
      Ok(json) => JsonRequest::from_json(json)?
      Err(e) => fail("Invalid JSON: " + e.to_string())
    }
  }

  /// 写入 JSON-RPC 响应
  pub fn write_response(self : StdioTransport, response : JsonResponse) -> Unit raise {
    let json = response.to_json()
    let json_str = JsonValue::to_string_pretty(json)
    println(json_str)
  }
}
```

### 4.5 MCP 服务器主逻辑

```moonbit
// src/mcp/handler/server.mbt

/// MCP 服务器
pub struct McpServer {
  tools : ToolRegistry
  transport : StdioTransport
}

impl McpServer {
  pub fn new(transport : StdioTransport) -> McpServer {
    {
      tools: ToolRegistry::new(),
      transport: transport
    }
  }

  /// 注册工具
  pub fn register_tool(self : McpServer, tool : ToolDefinition) -> McpServer raise {
    {
      tools: self.tools.register(tool)?,
      transport: self.transport
    }
  }

  /// 处理请求
  pub fn handle_request(self : McpServer, request : JsonRequest) -> JsonResponse {
    match request.method {
      "initialize" => self.handle_initialize(request.params?, request.id)
      "tools/list" => self.handle_tools_list(request.id)
      "tools/call" => self.handle_tools_call(request.params?, request.id)
      _ => self.handle_method_not_found(request.method, request.id)
    }
  }

  /// 初始化处理
  fn handle_initialize(self : McpServer, params : JsonValue, id : JsonId) -> JsonResponse {
    let result = McpInitializeResult {
      protocol_version: "2024-11-05",
      capabilities: McpServerCapabilities { /* ... */ },
      server_info: McpServerInfo {
        name: "moonbitmark",
        version: "0.6.0",
        protocol_version: "2024-11-05"
      }
    }
    JsonResponse {
      jsonrpc: "2.0",
      result: Some(result.to_json()),
      error: None,
      id: Some(id)
    }
  }

  /// 工具列表处理
  fn handle_tools_list(self : McpServer, id : JsonId) -> JsonResponse {
    let tools = self.tools.list()
    JsonResponse {
      jsonrpc: "2.0",
      result: Some(tools.to_json()),
      error: None,
      id: Some(id)
    }
  }

  /// 工具调用处理
  fn handle_tools_call(self : McpServer, params : JsonValue, id : JsonId) -> JsonResponse {
    // 解析参数
    let call_params = McpToolCallParams::from_json(params)?
    // 调用工具
    match self.tools.call(call_params.name, call_params.arguments) {
      Ok(result) => {
        JsonResponse {
          jsonrpc: "2.0",
          result: Some(result.to_json()),
          error: None,
          id: Some(id)
        }
      }
      Err(e) => {
        JsonResponse {
          jsonrpc: "2.0",
          result: None,
          error: Some(JsonError {
            code: -32603,
            message: "Internal error: " + e.to_string(),
            data: None
          }),
          id: Some(id)
        }
      }
    }
  }

  /// 方法不存在处理
  fn handle_method_not_found(self : McpServer, method : String, id : JsonId) -> JsonResponse {
    JsonResponse {
      jsonrpc: "2.0",
      result: None,
      error: Some(JsonError {
        code: -32601,
        message: "Method not found: " + method,
        data: None
      }),
      id: Some(id)
    }
  }

  /// 运行服务器主循环
  pub fn run(self : McpServer) -> Unit {
    loop {
      match self.transport.read_request() {
        Ok(request) => {
          let response = self.handle_request(request)
          self.transport.write(response)
        }
        Err(e) => {
          // 发送错误响应并继续
          let error_response = JsonResponse {
            jsonrpc: "2.0",
            result: None,
            error: Some(JsonError {
              code: -32700,
              message: "Parse error: " + e.to_string(),
              data: None
            }),
            id: None
          }
          self.transport.write(error_response)
        }
      }
    }
  }
}
```

### 4.6 文档转换工具实现

```moonbit
// src/mcp/handler/tools.mbt (续)

/// 文档转换工具注册
pub fn register_convert_tools(registry : ToolRegistry) -> ToolRegistry raise {
  let convert_tool = ToolDefinition {
    name: "convert_to_markdown",
    description: "Convert a document (PDF, DOCX, HTML, etc.) to Markdown format",
    input_schema: JsonValue::Object(Map::from([
      ("type", JsonValue::String("object")),
      ("properties", JsonValue::Object(Map::from([
        ("uri", JsonValue::Object(Map::from([
          ("type", JsonValue::String("string")),
          ("description", JsonValue::String("URI of the document to convert (file://, http://, https://)"))
        ])))
      ]))),
      ("required", JsonValue::Array(vec![
        JsonValue::String("uri")
      ]))
    ])),
    handler: fn(args : JsonValue) -> McpToolResult {
      convert_to_markdown_handler(args)
    }
  }

  registry.register(convert_tool)?
}

/// 文档转换处理函数
fn convert_to_markdown_handler(args : JsonValue) -> McpToolResult raise {
  // 解析 URI 参数
  let uri = match args.get("uri") {
    Some(JsonValue::String(u)) => u,
    _ => return McpToolResult {
      content: vec![TextContent {
        type: "text",
        text: "Error: 'uri' parameter is required"
      }],
      isError: true
    }
  }

  // 调用现有转换逻辑
  let markdown = convert_file(uri)?

  // 返回结果
  McpToolResult {
    content: vec![TextContent {
      type: "text",
      text: markdown
    }],
    isError: false
  }
}
```

---

## 五、实现计划

### 5.1 第一阶段: 核心功能 (优先级 P0)

| 任务 | 说明 | 预估时间 |
|------|------|----------|
| 1.1 实现 JSON 类型支持 | 需要调研 MoonBit JSON 序列化库或手动实现 | 2-3 天 |
| 1.2 实现 JSON-RPC 2.0 类型 | 定义请求/响应/错误类型 | 1 天 |
| 1.3 实现 MCP 协议类型 | 定义工具、资源、提示类型 | 1 天 |
| 1.4 实现 STDIO 传输 | 标准输入输出读写 | 1 天 |
| 1.5 实现工具注册表 | 工具注册、调用、列表 | 1 天 |
| 1.6 实现 MCP 服务器 | 请求处理、方法路由 | 2 天 |
| 1.7 集成文档转换 | 注册 convert_to_markdown 工具 | 1 天 |
| 1.8 编写单元测试 | 测试协议处理和工具调用 | 2 天 |

**第一阶段总计:** 约 12 天

### 5.2 第二阶段: 优化与增强 (优先级 P1)

| 任务 | 说明 | 预计时间 |
|------|------|----------|
| 2.1 错误处理增强 | 统一错误码和错误消息 | 1 天 |
| 2.2 日志支持 | 添加调试日志 | 1 天 |
| 2.3 配置文件支持 | 支持配置文件读取 | 1 天 |
| 2.4 性能优化 | 异步处理、流式传输 | 2 天 |
| 2.5 文档完善 | 使用文档和 API 文档 | 2 天 |

**第二阶段总计:** 约 7 天

### 5.3 第三阶段: 扩展功能 (优先级 P2)

| 任务 | 说明 | 预计时间 |
|------|------|----------|
| 3.1 HTTP/SSE 传输 | 实现基于 HTTP 的传输 | 5 天 |
| 3.2 资源支持 | 暴露文档文件作为资源 | 2 天 |
| 3.3 提示支持 | 提供转换提示模板 | 2 天 |
| 3.4 批量转换 | 支持批量文档转换 | 2 天 |

**第三阶段总计:** 约 11 天

---

## 六、关键技术挑战与解决方案

### 6.1 JSON 序列化/反序列化

**挑战:** MoonBit 目前没有成熟的 JSON 序列化库

**解决方案:**
1. **短期方案:** 手动实现简化的 JSON 解析器
   - 仅支持需要的类型 (String, Number, Boolean, Null, Object, Array)
   - 不支持注释、宽松模式
2. **长期方案:** 等待 MoonBit 官方或社区完善 JSON 库

### 6.2 异步 I/O

**挑战:** JSON-RPC 通信需要异步 I/O 支持

**解决方案:**
1. 使用现有的 `moonbitlang/async` 库
2. STDIO 传输可以直接使用同步 I/O (因为不需要等待网络)
3. HTTP 传输需要使用异步 HTTP 客户端

### 6.3 类型系统限制

**挑战:** MoonBit 的类型系统与 JSON 的动态类型不匹配

**解决方案:**
1. 定义 `JsonValue` 枚举类型表示任意 JSON 值
2. 使用 `Option` 表示可选字段
3. 提供类型转换辅助函数

### 6.4 MCP 协议兼容性

**挑战:** 确保 MoonBitMark MCP 与现有 MCP 客户端兼容

**解决方案:**
1. 严格遵循 MCP 规范
2. 参考官方 SDK 实现
3. 使用 MCP Inspector 工具测试

---

## 七、测试策略

### 7.1 单元测试

| 模块 | 测试内容 |
|------|----------|
| JSON-RPC | 请求解析、响应生成、错误处理 |
| MCP 协议 | 初始化、工具列表、工具调用 |
| 工具注册表 | 注册、调用、列表功能 |
| 文档转换 | 各格式转换正确性 |

### 7.2 集成测试

1. **手动测试:** 使用 MCP Inspector 连接 MoonBitMark MCP 服务器
2. **自动测试:** 编写测试客户端脚本
3. **兼容性测试:** 测试与 Claude Desktop 等客户端的兼容性

### 7.3 测试工具

- **MCP Inspector:** 官方提供的 MCP 调试工具
- **测试文档:** 准备各种格式的测试文档
- **日志分析:** 分析通信日志排查问题

---

## 八、文档计划

### 8.1 用户文档

1. **安装指南:** 如何编译和运行 MoonBitMark MCP 服务器
2. **配置指南:** 如何配置 MCP 客户端连接到 MoonBitMark
3. **使用示例:** Claude Desktop 配置示例
4. **API 文档:** 可用工具列表和参数说明

### 8.2 开发文档

1. **架构设计:** 整体架构和模块划分
2. **协议实现:** MCP 协议和 JSON-RPC 2.0 实现
3. **扩展指南:** 如何添加新的工具和资源
4. **调试指南:** 常见问题和调试方法

---

## 九、风险评估

### 9.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| JSON 序列化库缺失 | 高 | 高 | 手动实现简化版本 |
| MoonBit 生态不成熟 | 中 | 中 | 使用现有标准库,减少依赖 |
| MCP 规范变更 | 中 | 低 | 锁定到特定版本,关注更新 |
| 性能问题 | 低 | 低 | 优化关键路径,使用原生代码 |

### 9.2 进度风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| 实现复杂度超预期 | 中 | 中 | 分阶段实现,优先核心功能 |
| 测试覆盖不足 | 中 | 中 | 边开发边测试,及早发现问题 |
| 文档编写延迟 | 低 | 中 | 并行开发文档 |

---

## 十、总结

本设计文档详细说明了为 MoonBitMark 添加 MCP 服务能力的技术方案。核心要点如下:

1. **架构清晰:** 采用分层架构,各层职责明确
2. **模块化设计:** 核心功能独立模块,便于维护和扩展
3. **类型安全:** 充分利用 MoonBit 静态类型系统
4. **渐进式实现:** 优先实现核心功能,逐步增强
5. **规范遵循:** 严格遵循 MCP 和 JSON-RPC 2.0 规范

下一步将按照实现计划,优先完成第一阶段的核心功能,确保 MoonBitMark MCP 服务器能够正常工作并兼容现有 MCP 客户端。

---

**附录 A: 参考资料**

1. [MCP 官方文档](https://modelcontextprotocol.io)
2. [MCP 规范](https://modelcontextprotocol.io/specification)
3. [MCP Servers 仓库](https://github.com/modelcontextprotocol/servers)
4. [MarkitDown MCP 实现](https://github.com/microsoft/markitdown/tree/main/packages/markitdown-mcp)
5. [JSON-RPC 2.0 规范](https://www.jsonrpc.org/specification)

**附录 B: 相关技术文档**

- MoonBitMark 项目 README
- MoonBitMark 项目申报书
- MoonBit 官方文档
- moonbitlang/async 库文档

---

**文档版本历史:**

| 版本 | 日期 | 作者 | 说明 |
|------|------|------|------|
| 1.0 | 2026-03-12 | WorkBuddy | 初始版本 |
