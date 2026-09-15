# Ascend C 算子开发准则

本准则以 `omni-ops/inference/ascendc` 的工程形式和本仓首个算子的落地经验为基线。

## 1. 固定目录

每个 Ascend C 算子放在：

```text
src/ops-transformer/<category>/<op_name>/
├── CMakeLists.txt
├── docs/<op_name>.md
├── example/test_<op_name>.py
├── op_host/
│   ├── CMakeLists.txt
│   ├── <op_name>_def.cpp
│   ├── <op_name>_tiling.cpp
│   └── <op_name>_tiling.h
└── op_kernel/<op_name>.cpp
```

PTA 适配放在：

```text
torch_ops_extension/soulboy_custom_ops/ops_transformer/<category>/<op_name>/csrc/
```

不得再为单个算子创建根目录级 `pta/`、`python/` 或第二套 CMake 工程。

## 2. 命名映射

| 层 | 规则 | 示例 |
|---|---|---|
| GE Op 类型 | UpperCamelCase | `ValidRowsMatmulGelu` |
| 目录、文件、kernel | snake_case | `valid_rows_matmul_gelu` |
| ACLNN API | `aclnn` + GE 类型 | `aclnnValidRowsMatmulGelu` |
| PyTorch schema | `custom::npu_<op_name>` | `custom::npu_valid_rows_matmul_gelu` |
| Python/torch_npu | `npu_<op_name>` | `torch_npu.npu_valid_rows_matmul_gelu` |

输入输出必须使用语义名称，不使用 `input1`、`output1`。同一参数在 OpDef、Tiling、PTA、文档和
示例中的顺序与含义必须完全一致。

## 3. CMake 接线

- 算子根 `CMakeLists.txt` 只遍历有 CMakeLists 的子目录，保持与 omni-ops 一致。
- OpDef 加入 `op_host_aclnn`，Tiling 加入 `optiling`；需要设备侧 Tiling 时，由
  `cmake/tiling_sink.cmake` 汇总到 `cust_opmaster`。
- `OpAICoreConfig` 显式填写 `opFile.value`，值必须等于 kernel 文件名。
- 新增头文件依赖时在目标的 `target_include_directories` 增加准确目录，禁止依赖宿主机偶然存在的
  全局 include path。
- 构建入口固定为 `bash build.sh -n '<op_name>' -c <soc>`，产物必须进入 `output/*.run`。

## 4. 接口与 Tiling 规范

接口文档必须写清数学定义、输入输出 shape/dtype/format/device、合法值域、值依赖、动态 shape、
workspace、精度、支持 SoC/CANN 版本和已知限制。

- 只影响执行规模的 Device Tensor 使用 `ValueDepend(..., DependScope::TILING)`，不得在 Python/PTA
  中 `.item()` 造成 D2H 同步。
- Host TilingData 使用 `register/tilingdata_base.h`；custom OPP 构建会自动生成并注入 kernel 侧
  `*_tiling_data.h`，kernel 必须通过 `GET_TILING_DATA`/`GET_TILING_DATA_WITH_STRUCT` 使用它。禁止再定义
  同名 POD，也禁止把 Host 注册头带入 AI Core 编译。
- Host 与 Device Tiling 复用同一策略函数；注册宏分别使用 `IMPL_OP_OPTILING` 和
  `DEVICE_IMPL_OP_OPTILING`。
- Tiling 必须检查空指针、rank、shape、值域和溢出；失败时不得写半初始化数据。
- 明确定义 `0`、空张量、对齐边界和最大 shape 的行为；GM 访问必须能证明无越界和无写冲突。

## 5. PTA 接口规范

- schema 集中注册在 `csrc_base/ops_def_registration.cpp`。
- 每个算子注册 `PrivateUse1` 和 `Meta`；Meta 只推导输出，不访问 Tensor 数据。
- PTA 只做参数检查、输出分配和 `EXEC_NPU_CMD_V1(aclnn..., ...)`，不得重复 kernel 算法。
- Python 包导入后同时支持 `torch.ops.custom.npu_<op>()` 和 `torch_npu.npu_<op>()`。
- wheel 构建入口固定为 `cd torch_ops_extension && bash build_and_install.sh`；脚本必须同时执行
  `build_ext --inplace` 并从源码目录做 import 冒烟检查，避免源码包遮蔽已安装 wheel。

## 6. Python 示例模板

示例必须导入 `soulboy_custom_ops`，使用确定随机种子、显式 NPU/dtype、Device 上的值依赖 Tensor、
参考实现和 `torch.testing.assert_close`。至少覆盖一个正常值和一个边界值；错误必须令进程非零退出。

```python
import soulboy_custom_ops

torch.manual_seed(7)
runtime_value = torch.tensor([17], dtype=torch.int64, device="npu")
actual = torch_npu.npu_example(x, runtime_value)
expected = reference(x, runtime_value)
torch.testing.assert_close(actual, expected, rtol=2e-3, atol=2e-3)
```

## 7. 合入门槛

- `git diff --check`、`bash -n build.sh`、`bash -n torch_ops_extension/build_and_install.sh`、Python 语法检查通过。
- 在目标 Ascend 环境完成 `bash build.sh -n '<op>' -c <soc>`，安装 `.run` 后成功 source vendor 环境。
- 完成 PTA wheel 构建安装并运行 Python 示例；覆盖 `0/1/对齐前后/最大值/非法值`。
- 提交说明记录 CANN、驱动、固件、torch、torch_npu、SoC、完整构建和复现命令。
- `build/`、`output/`、wheel、so、缓存等产物不得提交。
