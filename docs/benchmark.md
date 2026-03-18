# Benchmark

`scripts/benchmark.ps1` 用于在本地对已构建的 native CLI 做最小重复基准。

## 前提

- 已完成 native release 构建
- `main.exe` 位于 `_build/native/release/build/cmd/main/main.exe`

## 示例

```powershell
$env:VCPKG_ROOT = 'C:\vcpkg'
scripts\build.bat
pwsh -File scripts/benchmark.ps1 -InputPath <your-input-file> -Iterations 10
```

## 参数

- `-InputPath`：待转换输入文件
- `-Iterations`：重复次数，默认 `5`
- `-BinaryPath`：CLI 二进制路径，默认 release 主程序
- `-OutputPath`：临时输出文件路径，默认系统临时目录

## 输出

脚本会输出：

- 每轮耗时（毫秒）
- 平均耗时
- 最小 / 最大耗时

该脚本目标是提供可复现的最小性能证据，而不是做严格统计学 benchmark。若需要更稳定的结果，建议：

- 固定输入文件集
- 预热一次 release 二进制
- 在空闲机器上运行更高迭代次数
