set(_op_dir "${CMAKE_CURRENT_LIST_DIR}/..")
set(_tiling_source "${CMAKE_CURRENT_LIST_DIR}/valid_rows_matmul_gelu_tiling.cpp")

add_library(soulboy_op_host SHARED
    valid_rows_matmul_gelu_def.cpp
    valid_rows_matmul_gelu_tiling.cpp
)

# CANN host headers are split across public, external and experimental trees.
# This mirrors the public interface target used by omni-ops/ops-transformer.
set(_cann_host_include_dirs
    "${ASCEND_CANN_PACKAGE_PATH}/include"
    "${ASCEND_CANN_PACKAGE_PATH}/include/external"
    "${ASCEND_CANN_PACKAGE_PATH}/include/experiment/platform"
    "${ASCEND_CANN_PACKAGE_PATH}/include/experiment/runtime"
    "${ASCEND_CANN_PACKAGE_PATH}/include/experiment/msprof"
    "${ASCEND_CANN_PACKAGE_PATH}/pkg_inc"
)

find_path(_opdef_include_root
    NAMES register/op_def_registry.h
    PATHS ${_cann_host_include_dirs}
    NO_DEFAULT_PATH
)
find_path(_platform_include_root
    NAMES tiling/platform/platform_ascendc.h
    PATHS ${_cann_host_include_dirs}
    NO_DEFAULT_PATH
)
if(NOT _opdef_include_root OR NOT _platform_include_root)
    message(FATAL_ERROR
        "Required CANN op-host headers were not found under "
        "${ASCEND_CANN_PACKAGE_PATH}. Expected register/op_def_registry.h "
        "and tiling/platform/platform_ascendc.h; check ASCEND_HOME_PATH.")
endif()

target_include_directories(soulboy_op_host PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
    ${_cann_host_include_dirs}
)
target_link_directories(soulboy_op_host PRIVATE
    "${ASCEND_CANN_PACKAGE_PATH}/lib64"
)

# CANN 9.x custom-op projects provide this macro. Keeping the target separate
# is essential: this copy of the tiling code is compiled for Device AI CPU.
if(COMMAND npu_op_device_tiling_library)
    npu_op_device_tiling_library(cust_opmaster SHARED "${_tiling_source}")
    target_include_directories(cust_opmaster PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}"
        ${_cann_host_include_dirs}
    )
    target_compile_definitions(cust_opmaster PRIVATE SOULBOY_DEVICE_TILING=1)
    install(TARGETS cust_opmaster LIBRARY DESTINATION lib)
else()
    message(WARNING
        "npu_op_device_tiling_library is unavailable; host tiling will build, "
        "but device tiling requires a CANN 9.x custom-op toolchain.")
endif()

install(TARGETS soulboy_op_host LIBRARY DESTINATION lib)
