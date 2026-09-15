cmake_minimum_required(VERSION 3.16)

project(soulboy_ascend_boost LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(SOC_VERSION "ascend910b" CACHE STRING "Ascend SoC version")
set(ASCEND_CANN_PACKAGE_PATH "" CACHE PATH "CANN toolkit root")
set(ASCENDC_CMAKE_DIR "" CACHE PATH "Directory containing ascendc.cmake")
set(SOULBOY_KERNEL_TARGET "soulboy_ascend_kernels" CACHE STRING "Kernel library target name")

option(SOULBOY_ENABLE_EXAMPLE "Build the example identity kernel" ON)
option(SOULBOY_BUILD_OP_HOST "Build the GE host/device-tiling registration libraries" ON)
option(SOULBOY_BUILD_PTA "Build the PyTorch/torch_npu extension" OFF)

include(cmake/AscendC.cmake)
soulboy_configure_ascendc()

add_subdirectory(csrc)

if(SOULBOY_BUILD_PTA)
    add_subdirectory(pta)
endif()
