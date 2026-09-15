# Ascend C 算子开发准则

本文是本仓库新增算子的最低交付标准，来自 `ValidRowsMatmulGelu` 首次落地以及
`ops-transformer`、`omni-ops` 的工程约定。

## 1. 命名

同一概念在不同层使用确定的机械映射，禁止随意缩写：

| 层级 | 规则 | 示例 |
|---|---|---|
| GE 算子类型 | UpperCamelCase | `ValidRowsMatmulGelu` |
| kernel/文件/目录 | snake_case | `valid_rows_matmul_gelu.cpp` |
| C++ 函数 | UpperCamelCase 或项目既有风格 | `ValidRowsMatmulGeluTiling` |
| Python 公共接口 | snake_case | `valid_rows_matmul_gelu` |
| torch namespace | 固定为 `soulboy` | `torch.ops.soulboy.valid_rows_matmul_gelu` |
| ACLNN（若提供） | `aclnn` + UpperCamelCase | `aclnnValidRowsMatmulGelu` |

输入名必须表达语义（`valid_rows`），不用 `input1`。数量、字节和偏移字段加后缀
`Count`、`Bytes`、`Offset`；shape 维度沿用领域字母 `m/n/k`，在文档首次出现时解释。

## 2. 目录与层次

每个算子至少包含：

```text
csrc/ops/<op>/
├── op_host/       # 原型、InferShape、Tiling、注册
└── op_kernel/     # Ascend C kernel 与共享 TilingData
docs/<op>.md       # 用户接口与限制
examples/<op>.py   # 最小可运行 Python 示例
tests/             # contract、tiling 边界和 NPU 正确性测试
```

PTA 注册只负责参数校验、输出分配与调用 ACLNN/算子，不复制 tiling 和 kernel 算法。
Host 和 Device tiling 应调用同一个纯策略函数，避免两份逻辑漂移。

## 3. 接口规范

接口文档必须给出：数学定义、每个输入输出的 shape/dtype/format/device、合法值域、连续性、
动态 shape/值依赖、错误行为、精度阈值、workspace、副作用和支持的 SoC/CANN 版本。

设计时遵守：

1. 输出 shape 能静态推导时，不读取 Device 值；只影响 tiling 的输入使用
   `ValueDepend(OPTIONAL, DependScope::TILING)`。
2. 非法值返回失败，不静默 clamp；`0`、空张量、对齐边界和最大值都有明确语义。
3. TilingData 只含定宽 POD 字段和官方可序列化结构，不放指针、STL 容器或 ABI 敏感对象。
   Host 定义使用 `register/tilingdata_base.h`；kernel 定义使用
   `kernel_tiling/kernel_tiling.h` 和等价 POD，禁止让 AI Core 编译依赖 Host 注册头文件。
4. workspace 用 `uint64_t/size_t` 检查溢出并按编译期最大 shape 预留。
5. PTA 同时注册 `PrivateUse1` 与 `Meta`；Meta 路径不得访问 Tensor 数据。
6. Python 封装保留 Device Tensor 参数，禁止为方便调用 `.item()` 引入隐式 D2H 同步。

## 4. Tiling 与 kernel

- Tiling 函数先判空、校验 rank/dtype/shape/value，再写 TilingData；失败后不得使用半初始化数据。
- Device 值在编译期可能无 data 指针，使用静态最大值生成可编译、可分配的计划。
- `valid_rows=0` 等零工作量必须有独立快速路径。
- 混合 AIC/AIV kernel 的生产者/消费者必须显式使用跨核 flag；文档写明 flag 所有权。
- 每个 block 的 GM 范围必须可由 tiling 字段独立证明无重叠、无越界。
- 首版先正确再优化，但临时标量实现必须在文档中标成 bring-up，不可伪装成性能版本。

## 5. Python 调用例子模板

示例必须包含确定随机种子、显式 dtype/device、最小与边界 shape、Device 上构造的值依赖、
参考实现和 `torch.testing.assert_close`。模板：

```python
torch.manual_seed(7)
x = torch.randn(..., dtype=torch.float16, device="npu")
runtime_value = torch.tensor([...], dtype=torch.int64, device="npu")
actual = public_api(x, ..., runtime_value)
expected = reference(x, ..., runtime_value)
torch.testing.assert_close(actual, expected, rtol=..., atol=...)
```

不要只打印结果；示例必须在错误时以非零状态退出。不要用超大 shape 作为唯一示例。

## 6. 文档模板

每份 `docs/<op>.md` 按以下顺序：功能与公式、接口表、约束、构建/安装、Python 示例、
精度与性能、错误处理、兼容矩阵、已知限制。代码和文档中的 dtype、参数顺序必须一致。

## 7. 合入门槛

- `git diff --check`、shell 语法、Python compile/contract tests 全部通过。
- 在目标 910B 环境完成 kernel、Host tiling、Device tiling 和 PTA 编译。
- 覆盖 `0/1/15/16/17/max` 等边界与非法值；输出无效区严格为零。
- profiler 证明值依赖 tiling 在 AI CPU 执行；与关闭 tiling sink 的结果一致。
- 示例能从干净环境按文档命令运行；构建产物和缓存不提交。
- PR 说明记录 CANN、驱动、固件、torch、torch_npu、SoC 与复现命令。
