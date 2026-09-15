# soulboy_ascend_boost

面向昇腾推理场景的 Ascend C 自定义算子工程。工程布局、Ascend C run 包构建、安装方式和
PyTorch NPU 扩展构建方式与 `omni-ops/inference/ascendc` 保持一致。

首个算子是 `ValidRowsMatmulGelu`：只计算前 `valid_rows` 行的矩阵乘、Bias 和 GELU，输出其余行清零。

## 目录结构

```text
.
├── CMakeLists.txt
├── build.sh
├── cmake/                         # custom OPP/CPack 构建框架
├── scripts/                       # 打包辅助脚本
├── src/
│   ├── ops-transformer/
│   │   └── matmul/
│   │       └── valid_rows_matmul_gelu/
│   │           ├── docs/
│   │           ├── example/
│   │           ├── op_host/       # OpDef、Host/Device Tiling
│   │           └── op_kernel/     # Ascend C Kernel
│   └── utils/
└── torch_ops_extension/
    ├── soulboy_custom_ops/
    ├── setup.py
    └── build_and_install.sh
```

## 环境准备

在安装了配套 CANN、PyTorch 和 torch_npu 的 Linux/Ascend 环境执行：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
```

非默认 CANN 路径可通过 `-p` 指定，例如：

```bash
bash build.sh -p /usr/local/Ascend/ascend-toolkit/latest -c ascend910b
```

## Ascend C 算子编译

命令与 `omni-ops/inference/ascendc` 相同：

```bash
# 编译全部算子
bash build.sh -c ascend910b

# 编译指定算子；多个算子以分号分隔
bash build.sh -n 'valid_rows_matmul_gelu' -c ascend910b
```

如 CANN 版本兼容校验失败，可增加 `--disable-check-compatible`。成功后在 `output/` 生成：

```text
CANN-soulboy_custom_ops-<cann-version>-linux.<arch>.run
```

## 安装 run 包

```bash
cd output
chmod +x CANN-soulboy_custom_ops-*.run
./CANN-soulboy_custom_ops-*.run \
  --quiet \
  --install-path=/usr/local/Ascend/ascend-toolkit/latest/opp
source /usr/local/Ascend/ascend-toolkit/latest/opp/vendors/soulboy_custom_ops/bin/set_env.bash
```

run 包必须与 CANN 和机器架构匹配。安装到其他 OPP 根目录时，相应调整 `--install-path` 和
`source` 路径。

若使用精简容器，工程会在打包前检查 `/tmp`。CANN 9.0.1 的 makeself 脚本固定在该目录创建
`mkself*.tar`；当前用户无权创建或写入 `/tmp` 时，需要由容器管理员执行：

```bash
mkdir -p /tmp
chmod 1777 /tmp
```

## PTA wheel 编译与安装

命令与 omni-ops 相同：

```bash
cd torch_ops_extension
bash build_and_install.sh
```

脚本执行 `setup.py build bdist_wheel`，在 `dist/` 生成 wheel 并通过 `pip3 --force-reinstall`
安装。PTA 扩展通过自动生成的 `aclnnValidRowsMatmulGelu` 接口调用已安装的 custom OPP。

## Python 使用

```python
import torch
import torch_npu
import soulboy_custom_ops  # 加载 so，并把接口挂载到 torch_npu

x = torch.randn(128, 256, dtype=torch.float16, device="npu")
weight = torch.randn(256, 512, dtype=torch.float16, device="npu")
bias = torch.randn(512, dtype=torch.float32, device="npu")
valid_rows = torch.tensor([17], dtype=torch.int64, device="npu")

y = torch_npu.npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows)
# 等价：torch.ops.custom.npu_valid_rows_matmul_gelu(...)
```

完整可运行示例见
`src/ops-transformer/matmul/valid_rows_matmul_gelu/example/test_valid_rows_matmul_gelu.py`；接口约束见同目录
`docs/valid_rows_matmul_gelu.md`。新增算子前阅读根目录 `DEVELOPMENT_GUIDE.md`。
