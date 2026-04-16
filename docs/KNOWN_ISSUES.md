# Known Issues

这里只保留当前仍然会影响使用或开发判断的问题。

## OCR 仍是 bridge-backed 可选能力

- 位置：`src/capabilities/ocr/`、`scripts/ocr/bridge.py`
- 影响：OCR 依赖 Python 和可用 backend，不是纯 MoonBit 内建能力。

当前 OCR 只适合作为恢复路径：

- 图片 OCR 依赖 bridge 和 backend 可用性。
- PDF OCR 只做页级文本恢复，不提供成熟的版面理解、bbox 或表格结构恢复。
- backend 缺失、超时或 bridge 失败时，预期行为是产生 diagnostics / warnings，而不是保证成功。

## Windows native release 构建依赖 MSVC

- 位置：`scripts/build.bat`
- 影响：Windows 上的原生 release 构建不能脱离 MSVC 环境。

这不是 bug，但它是一个明确的运行边界。如果构建环境没有 `cl.exe` 或没有正确加载 MSVC 环境，`moon build --target native --release` 不会按预期工作。
