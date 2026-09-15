# Copyright (c) 2025 Huawei Technologies Co., Ltd. All rights reserved.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.

message(STATUS "TILING SINK TASK BEGIN")
message(STATUS "TARGET: ${TARGET}")
message(STATUS "OPTION: ${OPTION}")
message(STATUS "SRC: ${SRC}")
message(STATUS "VENDOR: ${VENDOR_NAME}")
message(STATUS "INCLUDE_DIR: ${INCLUDE_DIR}")

set(CMAKE_CXX_COMPILER ${ASCEND_CANN_PACKAGE_PATH}/toolkit/toolchain/hcc/bin/aarch64-target-linux-gnu-g++)
set(CMAKE_C_COMPILER ${ASCEND_CANN_PACKAGE_PATH}/toolkit/toolchain/hcc/bin/aarch64-target-linux-gnu-gcc)

string(REPLACE " " ";" SRC "${SRC}")
add_library(${TARGET} ${OPTION}
    ${SRC}
)
target_compile_definitions(${TARGET} PRIVATE
    DEVICE_OP_TILING_LIB
    DEVICE_OP_LOG_BY_DUMP
    _FORTIFY_SOURCE=2
    google=ascend_private
    OPS_UTILS_LOG_SUB_MOD_NAME="${TARGET}"
    OPS_UTILS_LOG_PACKAGE_TYPE=$<IF:$<BOOL:${BUILD_OPEN_PROJECT}>,"[Custom]","">
)
target_include_directories(${TARGET} PRIVATE
    ${ASCEND_CANN_PACKAGE_PATH}/include
    ${ASCEND_CANN_PACKAGE_PATH}/include/external
    ${ASCEND_CANN_PACKAGE_PATH}/include/experiment/platform
    ${ASCEND_CANN_PACKAGE_PATH}/include/experiment/runtime
    ${ASCEND_CANN_PACKAGE_PATH}/include/experiment/msprof
    ${ASCEND_CANN_PACKAGE_PATH}/pkg_inc
    ${INCLUDE_DIR}/common/op_host
    ${INCLUDE_DIR}/../../utils/inc
    ${INCLUDE_DIR}/../../utils/inc/error
    ${INCLUDE_DIR}/../../utils/inc/log
    ${INCLUDE_DIR}/../../utils/inc/log/inner
    ${ASCEND_CANN_PACKAGE_PATH}/include
    ${ASCEND_CANN_PACKAGE_PATH}/include/base
)
target_compile_options(${TARGET} PRIVATE
    -fPIC
    -fstack-protector-strong
    -fstack-protector-all
    -O2
    -std=c++11
    -fvisibility-inlines-hidden
    -fvisibility=hidden
)
target_link_libraries(${TARGET} PRIVATE
    -Wl,--whole-archive
    device_register
    c_sec
    mmpa
    tiling_api
    platform_static
    ascend_protobuf
    exe_meta_device
    aicpu_cust_log
    -Wl,--no-whole-archive
)
target_link_directories(${TARGET} PRIVATE
    ${ASCEND_CANN_PACKAGE_PATH}/lib64/device/lib64
    ${ASCEND_CANN_PACKAGE_PATH}/compiler/lib64
)
set_target_properties(${TARGET} PROPERTIES
    OUTPUT_NAME cust_opmaster
)
