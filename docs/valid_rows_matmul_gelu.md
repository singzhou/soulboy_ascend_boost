# ValidRowsMatmulGelu 使用说明

## 功能

对静态上限输入执行：

```text
y[:m] = gelu(x[:m] @ weight + bias)
y[m:] = 0
m = valid_rows
```

接口为 `valid_rows_matmul_gelu(x, weight, bias, valid_rows)`。`x`/`weight`/输出为
FP16，`bias` 为 FP32，`valid_rows` 为与输入同设备上的单元素 INT64 Tensor。首版只支持
二维 ND 布局，且 `0 <= valid_rows <= M_max`。

## 构建

在安装 CANN 9.x、PyTorch 与 torch_npu 的 Ascend 910B Linux 环境执行：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
./build.sh --clean --soc ascend910b --pta
python -m pip install -e .
python examples/valid_rows_matmul_gelu.py
```

若 CMake 找不到 Torch，可追加：

```bash
export CMAKE_PREFIX_PATH="$(python -c 'import torch; print(torch.utils.cmake_prefix_path)')"
```

`./build.sh --kernel-only` 只验证 Ascend C kernel；完整的 Device Tiling 需要 CANN 9.x
custom-op CMake 中提供 `npu_op_device_tiling_library`。

## Python 示例

```python
import torch
import torch_npu
from soulboy_ascend_boost import valid_rows_matmul_gelu

x = torch.randn(128, 256, dtype=torch.float16, device="npu")
w = torch.randn(256, 512, dtype=torch.float16, device="npu")
b = torch.randn(512, dtype=torch.float32, device="npu")
m = torch.tensor([17], dtype=torch.int64, device="npu")
y = valid_rows_matmul_gelu(x, w, b, m)
```

## 当前实现边界

- PTA 注册实现用原生 NPU `matmul + gelu + mask` 完成语义，是当前可直接调用和验收的路径。
- `op_host` 已声明 `valid_rows` 的 `DependScope::TILING`，并同时注册 Host/Device tiling。
- Ascend C bring-up kernel 使用标量矩阵乘和低成本 GELU 近似，仅用于打通编译与调度，不是性能实现，
  也不应拿来作为 PTA 精度基线。下一阶段应替换为 `TCubeTiling` + Matmul 高阶 API 的 AIC/AIV 混合核。
- 仅在 macOS 上无法执行 CANN、bisheng、torch_npu 或 910B 真机验证；必须在目标 Linux 环境复验。
