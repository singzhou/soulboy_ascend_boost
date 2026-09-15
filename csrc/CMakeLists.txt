set(_kernel_globs
    "${CMAKE_CURRENT_SOURCE_DIR}/ops/*/op_kernel/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/ops/*/op_kernel/**/*.cpp"
)

file(GLOB_RECURSE SOULBOY_KERNEL_SOURCES CONFIGURE_DEPENDS ${_kernel_globs})

if(NOT SOULBOY_ENABLE_EXAMPLE)
    list(FILTER SOULBOY_KERNEL_SOURCES EXCLUDE REGEX "/soulboy_identity/")
endif()

if(NOT SOULBOY_KERNEL_SOURCES)
    message(FATAL_ERROR
        "No Ascend C kernels were found. Add .cpp files under "
        "csrc/ops/<operator>/op_kernel/ or enable SOULBOY_ENABLE_EXAMPLE."
    )
endif()

ascendc_library(${SOULBOY_KERNEL_TARGET} SHARED ${SOULBOY_KERNEL_SOURCES})
ascendc_include_directories(${SOULBOY_KERNEL_TARGET} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${ASCEND_CANN_PACKAGE_PATH}/include"
    "${ASCEND_CANN_PACKAGE_PATH}/include/ascendc"
    "${ASCEND_CANN_PACKAGE_PATH}/include/external"
    "${ASCEND_CANN_PACKAGE_PATH}/include/experiment/platform"
)

if(SOULBOY_BUILD_OP_HOST)
    add_subdirectory(ops/valid_rows_matmul_gelu/op_host)
endif()

install(
    TARGETS ${SOULBOY_KERNEL_TARGET}
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)
