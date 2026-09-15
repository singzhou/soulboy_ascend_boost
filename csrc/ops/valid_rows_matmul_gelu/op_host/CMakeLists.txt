set(_op_dir "${CMAKE_CURRENT_LIST_DIR}/..")
set(_tiling_source "${CMAKE_CURRENT_LIST_DIR}/valid_rows_matmul_gelu_tiling.cpp")

add_library(soulboy_op_host SHARED
    valid_rows_matmul_gelu_def.cpp
    valid_rows_matmul_gelu_tiling.cpp
)
target_include_directories(soulboy_op_host PRIVATE "${_op_dir}/op_kernel")

# CANN 9.x custom-op projects provide this macro. Keeping the target separate
# is essential: this copy of the tiling code is compiled for Device AI CPU.
if(COMMAND npu_op_device_tiling_library)
    npu_op_device_tiling_library(cust_opmaster SHARED "${_tiling_source}")
    target_include_directories(cust_opmaster PRIVATE "${_op_dir}/op_kernel")
    install(TARGETS cust_opmaster LIBRARY DESTINATION lib)
else()
    message(WARNING
        "npu_op_device_tiling_library is unavailable; host tiling will build, "
        "but device tiling requires a CANN 9.x custom-op toolchain.")
endif()

install(TARGETS soulboy_op_host LIBRARY DESTINATION lib)
