function(soulboy_configure_ascendc)
    if(NOT ASCEND_CANN_PACKAGE_PATH)
        if(DEFINED ENV{ASCEND_HOME_PATH} AND NOT "$ENV{ASCEND_HOME_PATH}" STREQUAL "")
            set(ASCEND_CANN_PACKAGE_PATH "$ENV{ASCEND_HOME_PATH}" CACHE PATH "CANN toolkit root" FORCE)
        elseif(DEFINED ENV{ASCEND_TOOLKIT_HOME} AND NOT "$ENV{ASCEND_TOOLKIT_HOME}" STREQUAL "")
            set(ASCEND_CANN_PACKAGE_PATH "$ENV{ASCEND_TOOLKIT_HOME}" CACHE PATH "CANN toolkit root" FORCE)
        else()
            set(ASCEND_CANN_PACKAGE_PATH "/usr/local/Ascend/latest" CACHE PATH "CANN toolkit root" FORCE)
        endif()
    endif()

    if(NOT ASCENDC_CMAKE_DIR)
        set(_ascendc_candidates
            "${ASCEND_CANN_PACKAGE_PATH}/tools/tikcpp/ascendc_kernel_cmake"
            "${ASCEND_CANN_PACKAGE_PATH}/compiler/tikcpp/ascendc_kernel_cmake"
            "${ASCEND_CANN_PACKAGE_PATH}/${CMAKE_SYSTEM_PROCESSOR}-linux/tikcpp/ascendc_kernel_cmake"
            "${ASCEND_CANN_PACKAGE_PATH}/ascendc_devkit/tikcpp/samples/cmake"
        )

        foreach(_candidate IN LISTS _ascendc_candidates)
            if(EXISTS "${_candidate}/ascendc.cmake")
                set(ASCENDC_CMAKE_DIR "${_candidate}" CACHE PATH "Directory containing ascendc.cmake" FORCE)
                break()
            endif()
        endforeach()
    endif()

    if(NOT EXISTS "${ASCENDC_CMAKE_DIR}/ascendc.cmake")
        message(FATAL_ERROR
            "ascendc.cmake was not found. Source the CANN set_env.sh script, set "
            "ASCEND_HOME_PATH, or pass -DASCENDC_CMAKE_DIR=/path/to/ascendc_kernel_cmake."
        )
    endif()

    message(STATUS "CANN toolkit: ${ASCEND_CANN_PACKAGE_PATH}")
    message(STATUS "Ascend C CMake: ${ASCENDC_CMAKE_DIR}")
    message(STATUS "Target SoC: ${SOC_VERSION}")

endfunction()
