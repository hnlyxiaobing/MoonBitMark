# Benchmark

`scripts/benchmark.ps1` 用于对 native CLI 做最小重复基准，适合快速比较改动前后的本地耗时。

## 前提

- 已完成 native release 构建
- 可执行文件位于 `_build/native/release/build/cmd/main/main.exe`

推荐先执行：

```bat
scripts\build.bat
```

## 示例

```powershell
pwsh -File scripts/benchmark.ps1 -InputPath <your-input-file> -Iterations 10
```

## 参数

- `-InputPath`: 待转换输入文件
- `-Iterations`: 重复次数，默认 `5`
- `-BinaryPath`: CLI 路径，默认 release 主程序
- `-OutputPath`: 临时输出文件路径，默认系统临时目录

## 输出

脚本会输出每轮耗时和平均耗时。这个脚本是最小基准入口，不负责长期结果归档或固定样本管理。
