# ValidRowsMatmulGelu

## 功能

对于 `x[M, K]`、`weight[K, N]`：

```text
y[:valid_rows] = gelu(x[:valid_rows] @ weight + bias)
y[valid_rows:] = 0
```

## 接口

```text
torch_npu.npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows) -> y
```

| 参数 | dtype | shape | format | 说明 |
|---|---|---|---|---|
| `x` | FP16 | `[M, K]` | ND | 输入矩阵 |
| `weight` | FP16 | `[K, N]` | ND | 权重矩阵 |
| `bias` | FP32 | `[N]` | ND | Bias |
| `valid_rows` | INT64 | `[1]` | ND | NPU 上的值依赖 Tensor，范围 `[0, M]` |
| `y` | FP16 | `[M, N]` | ND | 结果，无效行严格清零 |

输入必须位于同一 NPU。当前支持 `ascend910b` 和 `ascend910_93`，workspace 为 0。

## 构建与安装

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
bash build.sh -n 'valid_rows_matmul_gelu' -c ascend910b

cd output
chmod +x CANN-soulboy_custom_ops-*.run
./CANN-soulboy_custom_ops-*.run --quiet \
  --install-path=/usr/local/Ascend/ascend-toolkit/latest/opp
source /usr/local/Ascend/ascend-toolkit/latest/opp/vendors/soulboy_custom_ops/bin/set_env.bash

cd ../torch_ops_extension
bash build_and_install.sh

python ../src/ops-transformer/matmul/valid_rows_matmul_gelu/example/test_valid_rows_matmul_gelu.py
```

PTA 构建脚本同时生成 wheel 和源码树内的 `custom_ops_lib`，因此上述示例可直接从
`torch_ops_extension` 目录运行。

## Python 调用

```python
import torch
import torch_npu
import soulboy_custom_ops

x = torch.randn(128, 256, dtype=torch.float16, device="npu")
w = torch.randn(256, 512, dtype=torch.float16, device="npu")
b = torch.randn(512, dtype=torch.float32, device="npu")
rows = torch.tensor([17], dtype=torch.int64, device="npu")
y = torch_npu.npu_valid_rows_matmul_gelu(x, w, b, rows)
```

## 当前限制

Ascend C kernel 是首版 bring-up 实现，使用标量矩阵乘和低成本 GELU 近似，目标是验证 OPP、
AICPU Tiling、AI Core kernel、ACLNN 和 PTA 全链路；它不是性能版本。后续应使用 Matmul 高阶 API
和向量化 GELU 替换，并在 910B 上建立精度/性能基线。
