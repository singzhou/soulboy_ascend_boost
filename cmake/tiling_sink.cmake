# Copyright (c) 2025 Huawei Technologies Co., Ltd. All rights reserved.
# Licensed under the CANN Open Software License Agreement Version 2.0.

set(VALID_ROWS_MATMUL_GELU_TILING_SRC
    ${CMAKE_SOURCE_DIR}/src/ops-transformer/matmul/valid_rows_matmul_gelu/op_host/valid_rows_matmul_gelu_tiling.cpp
)

ascendc_device_library(
    TARGET cust_opmaster
    OPTION SHARED
    SRC ${VALID_ROWS_MATMUL_GELU_TILING_SRC}
    INCLUDE_DIR ${CMAKE_SOURCE_DIR}/src/ops-transformer/matmul
)
