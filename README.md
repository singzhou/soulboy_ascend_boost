# soulboy_ascend_boost

面向 Ascend C 自定义算子的轻量编译工程。工程结构参考 `ops-transformer` 和
`omni-ops`：CMake 负责接入 CANN Ascend C 工具链，算子按独立目录组织，构建脚本统一管理
SoC、构建类型和安装目录。

## 目录结构

```text
.
├── CMakeLists.txt
├── build.sh
├── cmake/
│   └── AscendC.cmake
└── csrc/
    ├── CMakeLists.txt
    └── ops/
        └── <operator>/
            └── op_kernel/
                └── *.cpp
```

首个完整算子是 `ValidRowsMatmulGelu`，包含值依赖 Host/Device Tiling、Ascend C bring-up
kernel、PTA 注册、Python 包装、示例和 contract tests。接口与当前实现边界见
[`docs/valid_rows_matmul_gelu.md`](docs/valid_rows_matmul_gelu.md)，新增算子的统一规范见
[`DEVELOPMENT_GUIDE.md`](DEVELOPMENT_GUIDE.md)。`soulboy_identity` 只保留为最小编译样例。

## 环境要求

- Linux（x86_64 或 aarch64）
- CMake 3.16+
- 配套的 CANN Toolkit 与 Ascend C 编译工具链

先加载 CANN 环境：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
```

如果安装路径不是默认路径，可设置 `ASCEND_HOME_PATH` 或 `ASCEND_TOOLKIT_HOME`；也可以直接用
`ASCENDC_CMAKE_DIR` 指向包含 `ascendc.cmake` 的目录。

## 编译

```bash
./build.sh --soc ascend910b
./build.sh --soc ascend910b --pta
```

常用选项：

```bash
./build.sh --help
./build.sh --soc ascend910_93 --jobs 32
./build.sh --clean --build-type Debug
```

默认构建产物安装到 `output/lib/`。也可以直接调用 CMake：

```bash
cmake -S . -B build \
  -DSOC_VERSION=ascend910b \
  -DASCEND_CANN_PACKAGE_PATH=/usr/local/Ascend/latest \
  -DCMAKE_INSTALL_PREFIX="$PWD/output"
cmake --build build --target install --parallel
```

## Python 使用

```bash
python -m pip install -e .
python examples/valid_rows_matmul_gelu.py
```

PTA 共享库默认从 `output/lib/libsoulboy_pta.so` 加载，也可通过
`SOULBOY_PTA_LIBRARY` 指定。CPU 侧 contract tests 可用：

```bash
PYTHONPATH=python python -m pytest tests/test_python_contract.py
```

## 新增算子

1. 新建 `csrc/ops/<operator>/op_kernel/`。
2. 将 Ascend C Kernel 源文件放入该目录。
3. 如需公共头文件，可在算子目录下增加 `include/`，并在 `csrc/CMakeLists.txt` 中给目标添加 include path。
4. 执行 `./build.sh --soc <soc_version>`。

新增前先阅读 `DEVELOPMENT_GUIDE.md`。本仓库当前的 `ValidRowsMatmulGelu` Ascend C kernel
仍是 bring-up 版本；用户侧可验收语义由 PTA 组合实现提供，生产性能 kernel 尚需在 910B
机器上用 Matmul 高阶 API 和 AIC/AIV 混合核替换。
