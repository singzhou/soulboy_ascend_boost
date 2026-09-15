# Copyright (c) 2025 Huawei Technologies Co., Ltd. All rights reserved.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.

function(add_target_source)
    cmake_parse_arguments(ADD "" "BASE_TARGET;SRC_DIR" "TARGET_NAME" ${ARGN})

    get_target_property(all_srcs ${ADD_BASE_TARGET} SOURCES)
    set(add_srcs)
    foreach(_src ${all_srcs})
        string(REGEX MATCH "^${ADD_SRC_DIR}" is_match "${_src}")
        if (is_match)
            list(APPEND add_srcs ${_src})
        endif ()
    endforeach()

    get_target_property(all_includes ${ADD_BASE_TARGET} INCLUDE_DIRECTORIES)
    set(add_includes)
    foreach(_include ${all_includes})
        string(REGEX MATCH "^${ADD_SRC_DIR}" is_match "${_include}")
        if (is_match)
            list(APPEND add_includes ${_include})
        endif ()
    endforeach()

    foreach(_target_name ${ADD_TARGET_NAME})
        target_sources(${_target_name} PRIVATE
                ${add_srcs}
        )

        target_include_directories(${_target_name} PRIVATE
                ${add_includes}
        )
    endforeach()
endfunction()

function(op_add_subdirectory OP_LIST OP_DIR_LIST)
    set(_OP_LIST)
    set(_OP_DIR_LIST)

    file(GLOB OP_HOST_CMAKE_FILES  "${CMAKE_CURRENT_SOURCE_DIR}/src/ops-transformer/**/**/CMakeLists.txt" "${CMAKE_CURRENT_SOURCE_DIR}/src/ops-transformer/**/**/ophost/CMakeLists.txt" "${CMAKE_CURRENT_SOURCE_DIR}/src/ops-nn/**/**/CMakeLists.txt" "${CMAKE_CURRENT_SOURCE_DIR}/src/ops-nn/**/**/ophost/CMakeLists.txt")

    foreach(OP_CMAKE_FILE ${OP_HOST_CMAKE_FILES})
        if ("${OP_CMAKE_FILE}" MATCHES "ophost")
            get_filename_component(OP_HOST_DIR "${OP_CMAKE_FILE}" DIRECTORY)
            get_filename_component(OP_DIR "${OP_HOST_DIR}" DIRECTORY)
        else()
            get_filename_component(OP_DIR "${OP_CMAKE_FILE}" DIRECTORY)
        endif()
        get_filename_component(OP_NAME "${OP_DIR}" NAME)

        if (NOT BUILD_OPEN_PROJECT)
            if (EXISTS ${TOP_DIR}/asl/ops/cann/ops/built-in/tbe/impl/ascendc/${OP_NAME})
                continue()
            endif ()
        endif ()

        if (DEFINED ASCEND_OP_NAME AND NOT "${ASCEND_OP_NAME}" STREQUAL "")
            if (NOT "${ASCEND_OP_NAME}" STREQUAL "all" AND NOT "${ASCEND_OP_NAME}" STREQUAL "ALL")
                if (NOT ${OP_NAME} IN_LIST ASCEND_OP_NAME)
                    continue()
                endif ()
            endif ()
        endif ()

        list(APPEND _OP_LIST ${OP_NAME})
        list(APPEND _OP_DIR_LIST ${OP_DIR})
    endforeach()

    list(REMOVE_DUPLICATES _OP_LIST)
    list(REMOVE_DUPLICATES _OP_DIR_LIST)
    list(SORT _OP_LIST)
    list(SORT _OP_DIR_LIST)
    set(${OP_LIST} ${_OP_LIST} PARENT_SCOPE)
    set(${OP_DIR_LIST} ${_OP_DIR_LIST} PARENT_SCOPE)
endfunction()

function(op_add_depend_directory)
    cmake_parse_arguments(DEP "" "OP_DIR_LIST" "OP_LIST" ${ARGN})
    set(_OP_DEPEND_DIR_LIST)
    foreach(op_name ${DEP_OP_LIST})
        if (DEFINED ${op_name}_depends)
            foreach(depend_info ${${op_name}_depends})
                if (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/${depend_info}/ophost/CMakeLists.txt AND NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/${depend_info}/CMakeLists.txt)
                    continue()
                endif ()

                get_filename_component(_depend_op_name "${depend_info}" NAME)
                if (NOT BUILD_OPEN_PROJECT)
                    if (EXISTS ${TOP_DIR}/asl/ops/cann/ops/built-in/tbe/impl/ascendc/${_depend_op_name})
                        continue()
                    endif ()
                endif ()

                if (NOT ${_depend_op_name} IN_LIST DEP_OP_LIST)
                    list(APPEND _OP_DEPEND_DIR_LIST ${CMAKE_CURRENT_SOURCE_DIR}/src/${depend_info})
                endif ()
            endforeach()
        endif()
    endforeach()

    list(SORT _OP_DEPEND_DIR_LIST)
    list(REMOVE_DUPLICATES _OP_DEPEND_DIR_LIST)
    set(${DEP_OP_DIR_LIST} ${_OP_DEPEND_DIR_LIST} PARENT_SCOPE)
endfunction()

function(add_compile_cmd_target)
    cmake_parse_arguments(CMD "" "COMPUTE_UNIT" "" ${ARGN})

    if(ADD_OPS_COMPILE_OPTION_V2)
        set(OP_DEBUG_CONFIG_OPTION --opc-config-file ${ASCEND_CUSTOM_OPC_OPTIONS})
    else()
        if(OP_DEBUG_CONFIG)
            set(OP_DEBUG_CONFIG_OPTION --op-debug-config ${OP_DEBUG_CONFIG})
        endif()
        set(OP_TILING_KEY_OPTION --tiling-keys ${ASCEND_CUSTOM_TILING_KEYS})
    endif()

    set(_OUT_DIR           ${ASCEND_BINARY_OUT_DIR}/${CMD_COMPUTE_UNIT})
    set(GEN_OUT_DIR        ${_OUT_DIR}/gen)
    set(COMPILE_CMD_TARGET generate_compile_cmd_${CMD_COMPUTE_UNIT})

    add_custom_target(${COMPILE_CMD_TARGET} ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${GEN_OUT_DIR}
        COMMAND ${HI_PYTHON} ${ASCENDC_CMAKE_UTIL_DIR}/ascendc_bin_param_build.py
            ${base_aclnn_binary_dir}/aic-${CMD_COMPUTE_UNIT}-ops-info.ini
            ${GEN_OUT_DIR}
            ${CMD_COMPUTE_UNIT}
            ${OP_TILING_KEY_OPTION}
            ${OP_DEBUG_CONFIG_OPTION}
        COMMAND ${HI_PYTHON} ${ASCENDC_CMAKE_UTIL_DIR}/ascendc_bin_param_build.py
            ${base_aclnn_binary_dir}/inner/aic-${CMD_COMPUTE_UNIT}-ops-info.ini
            ${GEN_OUT_DIR}
            ${CMD_COMPUTE_UNIT}
            ${OP_TILING_KEY_OPTION}
            ${OP_DEBUG_CONFIG_OPTION}
        COMMAND ${HI_PYTHON} ${ASCENDC_CMAKE_UTIL_DIR}/ascendc_bin_param_build.py
            ${base_aclnn_binary_dir}/exc/aic-${CMD_COMPUTE_UNIT}-ops-info.ini
            ${GEN_OUT_DIR}
            ${CMD_COMPUTE_UNIT}
            ${OP_TILING_KEY_OPTION}
            ${OP_DEBUG_CONFIG_OPTION}
    )

    add_dependencies(${COMPILE_CMD_TARGET} opbuild_gen_default opbuild_gen_inner opbuild_gen_exc)
    add_dependencies(generate_compile_cmd ${COMPILE_CMD_TARGET})
endfunction()

function(add_ops_info_target)
    cmake_parse_arguments(OPINFO "" "COMPUTE_UNIT" "" ${ARGN})

    set(OPS_INFO_TARGET generate_ops_info_${OPINFO_COMPUTE_UNIT})
    set(OPS_INFO_JSON ${ASCEND_AUTOGEN_DIR}/aic-${OPINFO_COMPUTE_UNIT}-ops-info.json)
    set(CUSTOM_OPS_INFO_DIR ${CUSTOM_DIR}/op_impl/ai_core/tbe/config/${OPINFO_COMPUTE_UNIT})

    set(OPS_INFO_INI          ${base_aclnn_binary_dir}/aic-${OPINFO_COMPUTE_UNIT}-ops-info.ini)
    set(OPS_INFO_INNER_INI    ${base_aclnn_binary_dir}/inner/aic-${OPINFO_COMPUTE_UNIT}-ops-info.ini)
    set(OPS_INFO_EXCLUDE_INI  ${base_aclnn_binary_dir}/exc/aic-${OPINFO_COMPUTE_UNIT}-ops-info.ini)

    add_custom_command(OUTPUT ${OPS_INFO_JSON}
            COMMAND ${HI_PYTHON} ${ASCENDC_CMAKE_UTIL_DIR}/parse_ini_to_json.py
            ${OPS_INFO_INI}
            ${OPS_INFO_INNER_INI}
            ${OPS_INFO_EXCLUDE_INI}
            ${OPS_INFO_JSON}
            COMMAND mkdir -p ${CUSTOM_OPS_INFO_DIR}
            COMMAND cp -f ${OPS_INFO_JSON} ${CUSTOM_OPS_INFO_DIR}
    )

    add_custom_target(${OPS_INFO_TARGET} ALL
            DEPENDS ${OPS_INFO_JSON}
    )

    add_dependencies(${OPS_INFO_TARGET} opbuild_gen_default opbuild_gen_inner opbuild_gen_exc)
    add_dependencies(generate_ops_info ${OPS_INFO_TARGET})

    install(FILES ${OPS_INFO_JSON}
            DESTINATION packages/vendors/${VENDOR_NAME}/op_impl/ai_core/tbe/config/${OPINFO_COMPUTE_UNIT} OPTIONAL
    )
endfunction()

function(add_ops_compile_options)
    cmake_parse_arguments(OP_COMPILE "" "OP_NAME" "COMPUTE_UNIT;OPTIONS" ${ARGN})

    if(NOT OP_COMPILE_OPTIONS)
        return()
    endif()

    if(ADD_OPS_COMPILE_OPTION_V2)
        execute_process(COMMAND ${HI_PYTHON} ${ASCENDC_CMAKE_UTIL_DIR}/ascendc_gen_options.py
                ${ASCEND_CUSTOM_OPTIONS} ${OP_COMPILE_OP_NAME}
                ${OP_COMPILE_COMPUTE_UNIT} ${OP_COMPILE_OPTIONS}
                RESULT_VARIABLE EXEC_RESULT
                OUTPUT_VARIABLE EXEC_INFO
                ERROR_VARIABLE EXEC_ERROR)
        if (EXEC_RESULT)
            message("add ops compile options info: ${EXEC_INFO}")
            message("add ops compile options error: ${EXEC_ERROR}")
            message(FATAL_ERROR "Error: add ops compile options failed!")
        endif ()
    else()
        file(APPEND ${ASCEND_CUSTOM_OPTIONS}
                "${OP_COMPILE_OP_NAME},${OP_COMPILE_COMPUTE_UNIT},${OP_COMPILE_OPTIONS}\n"
        )
    endif()
endfunction()

function(add_ops_tiling_keys)
    cmake_parse_arguments(OP_COMPILE "" "OP_NAME" "COMPUTE_UNIT;TILING_KEYS" ${ARGN})

    if(NOT OP_COMPILE_TILING_KEYS)
        return()
    endif()

    if(ADD_OPS_COMPILE_OPTION_V2)
        list(JOIN OP_COMPILE_TILING_KEYS "," STRING_TILING_KEYS)
        add_ops_compile_options(
                OP_NAME ${OP_COMPILE_OP_NAME}
                OPTIONS --tiling_key=${STRING_TILING_KEYS}
        )
    else()
        file(APPEND ${ASCEND_CUSTOM_TILING_KEYS}
                "${OP_COMPILE_OP_NAME},${OP_COMPILE_COMPUTE_UNIT},${OP_COMPILE_TILING_KEYS}\n"
        )
    endif()
endfunction()

function(add_opc_config)
    cmake_parse_arguments(OP_COMPILE "" "OP_NAME" "COMPUTE_UNIT;CONFIG" ${ARGN})

    if(NOT ADD_OPS_COMPILE_OPTION_V2)
        return()
    endif()

    if(NOT OP_COMPILE_CONFIG)
        return()
    endif()

    string(REPLACE "," ";" OP_COMPILE_CONFIG_LIST "${OP_COMPILE_CONFIG}")

    set(_OPC_CONFIG)

    foreach(_option ${OP_COMPILE_CONFIG_LIST})
        if("${_option}" STREQUAL "ccec_g")
            list(APPEND _OPC_CONFIG "-g")
        elseif("${_option}" STREQUAL "ccec_O0")
            list(APPEND _OPC_CONFIG "-O0")
        elseif("${_option}" STREQUAL "oom")
            list(APPEND _OPC_CONFIG "--oom")
        elseif("${_option}" STREQUAL "sanitizer")
            list(APPEND _OPC_CONFIG "-sanitizer")
        elseif("${_option}" STREQUAL "dump_cce")
            list(APPEND _OPC_CONFIG "--save-temp-files")
        endif()
    endforeach()

    if(_OPC_CONFIG)
        add_ops_compile_options(
                OP_NAME ${OP_COMPILE_OP_NAME}
                OPTIONS ${_OPC_CONFIG}
        )
    endif()
endfunction()

function(add_ops_src_copy)
    cmake_parse_arguments(SRC_COPY "" "TARGET_NAME;SRC;DST;BE_RELIED;COMPUTE_UNIT" "" ${ARGN})

    set(OPS_UTILS_INC_KERNEL_TARGET ops_utils_inc_kernel_${SRC_COPY_COMPUTE_UNIT})
    if (EXISTS ${OPS_ADV_UTILS_KERNEL_INC})
        if (NOT TARGET ${OPS_UTILS_INC_KERNEL_TARGET})
            get_filename_component(_ROOT_OPS_SRC_DIR    "${SRC_COPY_DST}" DIRECTORY)
            set(OPS_UTILS_INC_KERNEL_DIR ${_ROOT_OPS_SRC_DIR}/ascendc/common)
            add_custom_command(OUTPUT ${OPS_UTILS_INC_KERNEL_DIR}
                    COMMAND mkdir -p ${OPS_UTILS_INC_KERNEL_DIR}/regbase
                    COMMAND cp -rf ${OPS_ADV_UTILS_KERNEL_INC}/*.* ${OPS_UTILS_INC_KERNEL_DIR}
            )

            add_custom_target(${OPS_UTILS_INC_KERNEL_TARGET}
                    DEPENDS ${OPS_UTILS_INC_KERNEL_DIR}
            )
        endif ()
    endif ()

    if ("${SRC_COPY_SRC}" MATCHES "common")
        file(GLOB SRC_FILES ${SRC_COPY_SRC}/*)
    else()
        file(GLOB SRC_FILES ${SRC_COPY_SRC}/* ${SRC_COPY_SRC}/op_kernel/*)
    endif()
    list(FILTER SRC_FILES EXCLUDE REGEX "ophost")
    if (NOT TARGET ${SRC_COPY_TARGET_NAME})
        set(_BUILD_FLAG ${SRC_COPY_DST}/${SRC_COPY_TARGET_NAME}.done)

        if (NOT "${SRC_COPY_DST}" MATCHES "common")
            add_custom_command(OUTPUT ${_BUILD_FLAG}
                    COMMAND mkdir -p ${SRC_COPY_DST}
                    COMMAND cp -rf ${SRC_FILES} ${SRC_COPY_DST}
                    COMMAND rm -rf ${SRC_COPY_DST}/op_kernel/
                    COMMAND touch ${_BUILD_FLAG}
            )
        else()
            add_custom_command(OUTPUT ${_BUILD_FLAG}
                    COMMAND mkdir -p ${SRC_COPY_DST}
                    COMMAND cp -rf ${SRC_FILES} ${SRC_COPY_DST}
                    COMMAND touch ${_BUILD_FLAG}
            )
        endif()

        add_custom_target(${SRC_COPY_TARGET_NAME}
                DEPENDS ${_BUILD_FLAG}
        )
    endif ()

    if (TARGET ${OPS_UTILS_INC_KERNEL_TARGET})
        add_dependencies(${SRC_COPY_TARGET_NAME} ${OPS_UTILS_INC_KERNEL_TARGET})
    endif ()

    if (DEFINED SRC_COPY_BE_RELIED)
        add_dependencies(${SRC_COPY_BE_RELIED} ${SRC_COPY_TARGET_NAME})
    endif ()

endfunction()

function(add_bin_compile_target)
    cmake_parse_arguments(BINARY "" "COMPUTE_UNIT" "OP_INFO" ${ARGN})

    set(_INSTALL_DIR packages/vendors/${VENDOR_NAME}/op_impl/ai_core/tbe/kernel)
    set(_OUT_DIR ${ASCEND_BINARY_OUT_DIR}/${BINARY_COMPUTE_UNIT})

    set(BIN_OUT_DIR      ${_OUT_DIR}/bin)
    set(GEN_OUT_DIR      ${_OUT_DIR}/gen)
    set(SRC_OUT_DIR      ${_OUT_DIR}/src)
    file(MAKE_DIRECTORY  ${BIN_OUT_DIR})

    foreach(_op_info ${BINARY_OP_INFO})
        get_filename_component(_op_name "${_op_info}" NAME)
        set(${_op_name}_dir ${_op_info})
    endforeach()

    set(_ops_target_list)
    set(compile_scripts)
    file(GLOB scripts_list ${GEN_OUT_DIR}/*.sh)
    list(APPEND compile_scripts ${scripts_list})

    foreach(bin_script ${compile_scripts})
        get_filename_component(bin_file ${bin_script} NAME_WE)
        string(REPLACE "-" ";" bin_sep ${bin_file})
        list(GET bin_sep 0 op_type)
        list(GET bin_sep 1 op_file)
        list(GET bin_sep 2 op_index)

        if (NOT DEFINED ${op_file}_dir)
            continue()
        endif ()

        if (NOT TARGET ${op_file})
            add_custom_target(${op_file})
            add_dependencies(ops_kernel ${op_file})
        endif ()

        set(OP_TARGET_NAME ${op_file}_${BINARY_COMPUTE_UNIT})

        if (NOT TARGET ${OP_TARGET_NAME})
            add_custom_target(${OP_TARGET_NAME})
            add_dependencies(${op_file} ${OP_TARGET_NAME})
            list(APPEND _ops_target_list ${OP_TARGET_NAME})

            set(OP_SRC_OUT_DIR  ${SRC_OUT_DIR}/${op_file})
            set(OP_BIN_OUT_DIR  ${BIN_OUT_DIR}/${op_file})
            file(MAKE_DIRECTORY ${OP_SRC_OUT_DIR})

            add_ops_src_copy(
                    TARGET_NAME
                    ${OP_TARGET_NAME}_src_copy
                    SRC
                    ${${op_file}_dir}
                    DST
                    ${OP_SRC_OUT_DIR}
                    COMPUTE_UNIT
                    ${BINARY_COMPUTE_UNIT}
            )

            if (DEFINED ${op_file}_depends)
                foreach(depend_info ${${op_file}_depends})
                    get_filename_component(_depend_op_name "${depend_info}" NAME)
                    set(_depend_op_target ${_depend_op_name}_${BINARY_COMPUTE_UNIT}_src_copy)
                    add_ops_src_copy(
                            TARGET_NAME
                            ${_depend_op_target}
                            SRC
                            ${CMAKE_SOURCE_DIR}/src/${depend_info}
                            DST
                            ${SRC_OUT_DIR}/${_depend_op_name}
                            COMPUTE_UNIT
                            ${BINARY_COMPUTE_UNIT}
                            BE_RELIED
                            ${OP_TARGET_NAME}_src_copy
                    )
                endforeach()
            endif ()

            set(DYNAMIC_PY_FILE ${OP_SRC_OUT_DIR}/${op_type}.py)
            add_custom_command(OUTPUT ${DYNAMIC_PY_FILE}
                    COMMAND cp -rf ${ASCEND_IMPL_OUT_DIR}/dynamic/${op_file}.py ${DYNAMIC_PY_FILE}
            )

            add_custom_target(${OP_TARGET_NAME}_py_copy
                    DEPENDS ${DYNAMIC_PY_FILE}
            )

            add_custom_command(OUTPUT ${OP_BIN_OUT_DIR}
                    COMMAND mkdir -p ${OP_BIN_OUT_DIR}
            )

            add_custom_target(${OP_TARGET_NAME}_mkdir
                    DEPENDS ${OP_BIN_OUT_DIR}
            )

            install(DIRECTORY ${OP_BIN_OUT_DIR}
                    DESTINATION ${_INSTALL_DIR}/${BINARY_COMPUTE_UNIT} OPTIONAL
            )

            install(FILES ${BIN_OUT_DIR}/${op_file}.json
                    DESTINATION ${_INSTALL_DIR}/config/${BINARY_COMPUTE_UNIT} OPTIONAL
            )
        endif ()

        set(_group "1-0")
        if (DEFINED ASCEND_OP_NAME AND NOT "${ASCEND_OP_NAME}" STREQUAL "")
            if (NOT "${ASCEND_OP_NAME}" STREQUAL "all" AND NOT "${ASCEND_OP_NAME}" STREQUAL "ALL")
                if (${op_file} IN_LIST ASCEND_OP_NAME)
                    list(LENGTH ASCEND_OP_NAME _len)
                    list(FIND ASCEND_OP_NAME ${op_file} _index)
                    math(EXPR _next_index "${_index} + 1")
                    if (${_next_index} LESS ${_len})
                        list(GET ASCEND_OP_NAME ${_next_index} _group_str)
                        set(_regex "^[0-9]+-[0-9]+$")
                        string(REGEX MATCH "${_regex}" match "${_group_str}")
                        if (match)
                            set(_group   ${_group_str})
                        endif ()
                    endif ()
                endif ()
            endif ()
        endif ()

        string(REPLACE "-" ";" _group_sep ${_group})

        list(GET _group_sep 1 start_index)
        set(end_index         ${op_index})
        list(GET _group_sep 0 step)

        set(_compile_flag false)
        if (${start_index} LESS ${end_index})
            foreach(i RANGE ${start_index} ${end_index} ${step})
                if (${i} EQUAL ${end_index})
                    set(_compile_flag true)
                    break()
                endif ()
            endforeach()
        elseif (${start_index} EQUAL ${end_index})
            set(_compile_flag true)
        else()
            set(_compile_flag false)
        endif ()

        if (_compile_flag)
            set(_BUILD_COMMAND)
            set(_BUILD_FLAG ${GEN_OUT_DIR}/${OP_TARGET_NAME}_${op_index}.done)
            if (ENABLE_OPS_HOST OR ENABLE_HOST_TILING)
                list(APPEND _BUILD_COMMAND export ASCEND_CUSTOM_OPP_PATH=${CUSTOM_DIR} &&)
            endif ()
            list(APPEND _BUILD_COMMAND export HI_PYTHON="python3" &&)
            list(APPEND _BUILD_COMMAND export TILINGKEY_PAR_COMPILE=1 &&)
            list(APPEND _BUILD_COMMAND export BIN_FILENAME_HASHED=1 &&)
            list(APPEND _BUILD_COMMAND bash ${bin_script} ${OP_SRC_OUT_DIR}/${op_type}.py ${OP_BIN_OUT_DIR})
            if(CMAKE_GENERATOR MATCHES "Unix Makefiles")
                list(APPEND _BUILD_COMMAND && echo $(MAKE))
            endif()

            add_custom_command(OUTPUT ${_BUILD_FLAG}
                    COMMAND ${_BUILD_COMMAND}
                    COMMAND touch ${_BUILD_FLAG}
                    WORKING_DIRECTORY ${GEN_OUT_DIR}
            )

            add_custom_target(${OP_TARGET_NAME}_${op_index}
                DEPENDS ${_BUILD_FLAG}
            )

            if (ENABLE_OPS_HOST OR ENABLE_HOST_TILING)
                add_dependencies(${OP_TARGET_NAME}_${op_index} optiling generate_ops_info)
            endif ()
            add_dependencies(${OP_TARGET_NAME}_${op_index} ${OP_TARGET_NAME}_src_copy ${OP_TARGET_NAME}_py_copy ${OP_TARGET_NAME}_mkdir)
            add_dependencies(${OP_TARGET_NAME} ${OP_TARGET_NAME}_${op_index})
        endif ()
    endforeach()

    if (_ops_target_list)
        set(OPS_CONFIG_TARGET ops_config_${BINARY_COMPUTE_UNIT})
        set(BINARY_INFO_CONFIG_FILE ${BIN_OUT_DIR}/binary_info_config.json)

        add_custom_command(OUTPUT ${BINARY_INFO_CONFIG_FILE}
                COMMAND ${HI_PYTHON} ${ASCENDC_CMAKE_UTIL_DIR}/ascendc_ops_config.py -p ${BIN_OUT_DIR} -s ${BINARY_COMPUTE_UNIT}
        )

        add_custom_target(${OPS_CONFIG_TARGET}
                DEPENDS ${BINARY_INFO_CONFIG_FILE}
        )

        add_dependencies(ops_config ${OPS_CONFIG_TARGET})

        foreach(_op_target ${_ops_target_list})
            add_dependencies(${OPS_CONFIG_TARGET} ${_op_target})
        endforeach()

        install(FILES ${BINARY_INFO_CONFIG_FILE}
                DESTINATION ${_INSTALL_DIR}/config/${BINARY_COMPUTE_UNIT} OPTIONAL
        )
    endif ()
endfunction()

function(redefine_file_macro)
    cmake_parse_arguments(_FILE "" "" "TARGET_NAME" ${ARGN})

    foreach(_target_name ${_FILE_TARGET_NAME})
        target_compile_options(${_target_name} PRIVATE
                -Wno-builtin-macro-redefined
        )

        get_target_property(_srcs ${_target_name} SOURCES)

        foreach(_src ${_srcs})
            get_filename_component(_src_name "${_src}" NAME)
            set_source_files_properties(${_src}
                    PROPERTIES COMPILE_DEFINITIONS __FILE__="${_src_name}"
            )
        endforeach()
    endforeach()
endfunction()

function(add_static_ops)
    cmake_parse_arguments(STATIC "" "SRC_DIR" "ACLNN_SRC;ACLNN_INNER_SRC" ${ARGN})
    set(prepare_ops_adv_static_target prepare_ops_adv_static)
    set(static_src_temp_dir ${CMAKE_CURRENT_BINARY_DIR}/static_src_temp_dir)
    set(modified_files)
    foreach(ops_type ${OPS_STATIC_TYPES})
        get_target_property(all_srcs aclnn_ops_${ops_type} SOURCES)
        set(add_srcs)
        set(generate_aclnn_srcs)
        foreach(_src ${all_srcs})
            string(REGEX MATCH "^${STATIC_SRC_DIR}" is_match "${_src}")
            if (is_match)
                list(APPEND add_srcs ${_src})
            endif ()
        endforeach()

        foreach(_src ${add_srcs})
            get_filename_component(name_without_ext ${_src} NAME_WE)
            string(REGEX REPLACE "^aclnn_" "" _op_name ${name_without_ext})

            foreach(_aclnn_src ${STATIC_ACLNN_SRC})
                get_filename_component(aclnn_name ${_aclnn_src} NAME_WE)
                if("aclnn_${_op_name}" STREQUAL "${aclnn_name}")
                    list(APPEND generate_aclnn_srcs ${_aclnn_src})
                    break()
                endif()
            endforeach()

            foreach(_aclnn_inner_src ${STATIC_ACLNN_INNER_SRC})
                get_filename_component(aclnn_inner_name ${_aclnn_inner_src} NAME_WE)
                if("aclnnInner_${_op_name}" STREQUAL "${aclnn_inner_name}")
                    list(APPEND generate_aclnn_srcs ${_aclnn_inner_src})
                    break()
                endif()
            endforeach()
        endforeach()

        if(add_srcs)
            list(TRANSFORM add_srcs REPLACE "${STATIC_SRC_DIR}" "${static_src_temp_dir}" OUTPUT_VARIABLE add_static_srcs)
            list(APPEND modified_files ${add_static_srcs})
            set(aclnn_ops_static_target aclnn_ops_${ops_type}_static)
            set_source_files_properties(${add_static_srcs}
                    TARGET_DIRECTORY ${aclnn_ops_static_target}
                    PROPERTIES GENERATED TRUE
            )

            target_sources(${aclnn_ops_static_target} PRIVATE
                    ${add_static_srcs}
            )
            add_dependencies(${aclnn_ops_static_target} ${prepare_ops_adv_static_target})
        endif()

        if(generate_aclnn_srcs)
            list(REMOVE_DUPLICATES generate_aclnn_srcs)
            set(aclnn_op_target acl_op_${ops_type}_builtin)
            set_source_files_properties(${generate_aclnn_srcs}
                    TARGET_DIRECTORY ${aclnn_op_target}
                    PROPERTIES GENERATED TRUE
            )

            target_sources(${aclnn_op_target} PRIVATE
                    ${generate_aclnn_srcs}
            )
        endif()
    endforeach()

    if(NOT TARGET ${prepare_ops_adv_static_target})
        list(REMOVE_DUPLICATES modified_files)
        add_custom_command(OUTPUT ${static_src_temp_dir}
                COMMAND mkdir -p ${static_src_temp_dir}
                COMMAND cp -rf ${STATIC_SRC_DIR}/src ${static_src_temp_dir}
                COMMAND ${HI_PYTHON} -B ${OPS_STATIC_SCRIPT} InsertIni -p ${static_src_temp_dir} -f ${modified_files}
        )

        add_custom_target(${prepare_ops_adv_static_target}
                DEPENDS ${static_src_temp_dir}
        )
    endif()
endfunction()

include(ExternalProject)
function(ascendc_device_library)
    message(STATUS "Ascendc device library generating")
    cmake_parse_arguments(DEVICE "" "TARGET;OPTION" "SRC;INCLUDE_DIR" ${ARGN})
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/tiling_sink
        COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_CURRENT_BINARY_DIR}/tiling_sink/CMakeLists.txt
    )
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E echo "cmake_minimum_required(VERSION 3.16.0)\nproject(cust_tiling_sink)\ninclude(${CMAKE_SOURCE_DIR}/cmake/device_task.cmake)\n"
        OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/tiling_sink/CMakeLists.txt
        RESULT_VARIABLE result
    )
    string(REPLACE ";" " " DEVICE_SRC "${DEVICE_SRC}")
    ExternalProject_Add(tiling_sink_task
        SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/tiling_sink
        CONFIGURE_COMMAND ${CMAKE_COMMAND}
        -DASCEND_CANN_PACKAGE_PATH=${ASCEND_CANN_PACKAGE_PATH}
        -DTARGET=${DEVICE_TARGET}
        -DOPTION=${DEVICE_OPTION}
        -DSRC=${DEVICE_SRC}
        -DINCLUDE_DIR=${DEVICE_INCLUDE_DIR} # 新增：传递INCLUDE_DIR变量
        -DVENDOR_NAME=${VENDOR_NAME}
        <SOURCE_DIR>
        CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
        INSTALL_COMMAND ""
        BUILD_ALWAYS TRUE
    )
    ExternalProject_Get_Property(tiling_sink_task BINARY_DIR)
    set(TILINGSINK_LIB_PATH "")
    message(STATUS "CMAKE_CURRENT_BINARY_DIR = ${CMAKE_CURRENT_BINARY_DIR}")
    message(STATUS "BINARY_DIR = ${BINARY_DIR}")
    message(STATUS "CMAKE_CURRENT_BINARY_DIR = ${CMAKE_CURRENT_BINARY_DIR}")
    if ("${DEVICE_OPTION}" STREQUAL "SHARED")
        set(TILINGSINK_LIB_PATH "${BINARY_DIR}/libcust_opmaster.so")
    else()
        set(TILINGSINK_LIB_PATH "${BINARY_DIR}/libcust_opmaster.a")
    endif()
    install(FILES ${TILINGSINK_LIB_PATH}
        DESTINATION packages/vendors/${VENDOR_NAME}/op_impl/ai_core/tbe/op_master_device/lib
    )
endfunction()

# 添加infer object
function(add_infer_modules)
  if (NOT TARGET ${OPHOST_NAME}_infer_obj)
    add_library(${OPHOST_NAME}_infer_obj OBJECT)
    target_include_directories(${OPHOST_NAME}_infer_obj
      PRIVATE ${INFER_OBJ_INCLUDE}
    )
    target_compile_definitions(${OPHOST_NAME}_infer_obj
      PRIVATE
      LOG_CPP
      OPS_UTILS_LOG_SUB_MOD_NAME="OP_PROTO"
      $<$<BOOL:${ENABLE_TEST}>:ASCEND_OPSPROTO_UT>
    )
    target_compile_options(${OPHOST_NAME}_infer_obj
      PRIVATE
      $<$<NOT:$<BOOL:${ENABLE_TEST}>>:-DDISABLE_COMPILE_V1>
      -Dgoogle=ascend_private
      -fvisibility=hidden
    )
    target_link_libraries(${OPHOST_NAME}_infer_obj
      PRIVATE
      $<BUILD_INTERFACE:$<IF:$<BOOL:${ENABLE_TEST}>,intf_llt_pub_asan_cxx17,intf_pub_cxx17>>
      $<BUILD_INTERFACE:intf_pub>
      $<BUILD_INTERFACE:ops_transformer_utils_proto_headers>
      $<$<BOOL:${alog_FOUND}>:$<BUILD_INTERFACE:alog_headers>>
      $<$<BOOL:${dlog_FOUND}>:$<BUILD_INTERFACE:dlog_headers>>
      -Wl,--whole-archive
      rt2_registry_static
      -Wl,--no-whole-archive
      -Wl,--no-as-needed
      exe_graph
      graph
      graph_base
      register
      ascendalog
      error_manager
      platform
      -Wl,--as-needed
      c_sec
    )
  endif()
endfunction()

# 添加tiling object
function(add_tiling_modules)
  if (NOT TARGET ${OPHOST_NAME}_tiling_obj)
    add_library(${OPHOST_NAME}_tiling_obj OBJECT)
    target_include_directories(${OPHOST_NAME}_tiling_obj
      PRIVATE ${OP_TILING_INCLUDE}
      $<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include>
      $<BUILD_INTERFACE:${OPS_TRANSFORMER_DIR}/common/include>

      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include/experiment>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/include/op_common/op_host>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include/experiment/metadef/common/util>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include/experiment>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/pkg_inc/profiling>>
    )
    target_compile_definitions(${OPHOST_NAME}_tiling_obj
      PRIVATE
      LOG_CPP
      OPS_UTILS_LOG_SUB_MOD_NAME="OP_TILING"
      $<$<BOOL:${ENABLE_TEST}>:ASCEND_OPTILING_UT>
    )
    target_compile_options(${OPHOST_NAME}_tiling_obj
      PRIVATE
      $<$<NOT:$<BOOL:${ENABLE_TEST}>>:-DDISABLE_COMPILE_V1>
      -Dgoogle=ascend_private
      -fvisibility=hidden
      -fno-strict-aliasing
    )
    target_link_libraries(${OPHOST_NAME}_tiling_obj
      PRIVATE
      $<BUILD_INTERFACE:$<IF:$<BOOL:${ENABLE_TEST}>,intf_llt_pub_asan_cxx17,intf_pub_cxx17>>
      $<BUILD_INTERFACE:intf_pub>
      $<BUILD_INTERFACE:ops_transformer_utils_tiling_headers>
      $<$<BOOL:${alog_FOUND}>:$<BUILD_INTERFACE:alog_headers>>
      $<$<BOOL:${dlog_FOUND}>:$<BUILD_INTERFACE:dlog_headers>>
      -Wl,--whole-archive
      rt2_registry_static
      -Wl,--no-whole-archive
      -Wl,--no-as-needed
      graph
      graph_base
      exe_graph
      platform
      register
      # ascendalog
      error_manager
      -Wl,--as-needed
      -Wl,--whole-archive
      tiling_api
      -Wl,--no-whole-archive
      # mmpa
      c_sec
    )
  endif()
endfunction()

# useage: add_aicpu_cust_kernel_modules(target_name)
# 添加aicpu cust kernel object target
function(add_aicpu_cust_kernel_modules target_name)
  message(STATUS "add_aicpu_cust_kernel_modules for ${target_name}")
  if(NOT TARGET ${target_name})
    add_library(${target_name} OBJECT)
    target_include_directories(${target_name} PRIVATE ${AICPU_INCLUDE})
    target_compile_definitions(
            ${target_name} PRIVATE
            _FORTIFY_SOURCE=2 _GLIBCXX_USE_CXX11_ABI=1
            google=ascend_private
            $<$<BOOL:${ENABLE_TEST}>:ASCEND_AICPU_UT>
    )
    target_compile_options(
            ${target_name} PRIVATE
            $<$<NOT:$<BOOL:${ENABLE_TEST}>>:-DDISABLE_COMPILE_V1> -Dgoogle=ascend_private
            -fvisibility=hidden ${AICPU_DEFINITIONS}
    )
    target_link_libraries(
            ${target_name}
            PRIVATE $<BUILD_INTERFACE:$<IF:$<BOOL:${ENABLE_TEST}>,intf_llt_pub_asan_cxx17,intf_pub_cxx17>>
            $<BUILD_INTERFACE:dlog_headers>
            -Wl,--no-whole-archive
            Eigen3::EigenTransformer
    )
    if (NOT ${target_name} IN_LIST AICPU_CUST_OBJ_TARGETS)
      set(AICPU_CUST_OBJ_TARGETS ${AICPU_CUST_OBJ_TARGETS} ${target_name} CACHE INTERNAL "All aicpu cust obj targets")
    endif()
  endif()
endfunction()

set(OPS_CATEGORY_LIST
  "src/ops-transformer/attention"
)

# 添加待编译算子
function(add_need_compile_ops op_name)
  if(NOT ASCEND_OP_NAME)
    # 为空则不需要更新
    return()
  endif()

  set(NEW_OP_NAMES ${ASCEND_OP_NAME} ${op_name})
  list(REMOVE_DUPLICATES NEW_OP_NAMES)
  set(ASCEND_OP_NAME
      ${NEW_OP_NAMES}
      CACHE STRING "Ascend op names to compile" FORCE
    )
endfunction()

function(add_dependent_ops dependent_ops)
  # 当 ASCEND_OP_NAME 为 ALL 时，所有算子均已参与编译，无需重复添加依赖目录
  if (ASCEND_OP_NAME STREQUAL "ALL")
    return()
  endif()

  foreach(dep_op ${dependent_ops})
    # 查询依赖算子所在目录
    set(dep_op_path_list "")
    if(ENABLE_EXPERIMENTAL)
      foreach(ops_category ${OPS_CATEGORY_LIST})
        file(GLOB dep_op_path "${PROJECT_SOURCE_DIR}/experimental/${ops_category}/${dep_op}")
        list(APPEND dep_op_path_list ${dep_op_path})
      endforeach()
    endif()
    set(outside_experimental FALSE)
    # 如果非 experimental，或 experimental 下没找到，则去常规目录查找
    if(NOT dep_op_path_list)
      foreach(ops_category ${OPS_CATEGORY_LIST})
        file(GLOB dep_op_path "${PROJECT_SOURCE_DIR}/${ops_category}/${dep_op}")
        list(APPEND dep_op_path_list ${dep_op_path})
      endforeach()
      set(outside_experimental ${ENABLE_EXPERIMENTAL})
    endif()
    # 检查依赖存在
    if(NOT dep_op_path_list)
      message(FATAL_ERROR "dependent operator(${dep_op}) not exists")
    endif()
    list(LENGTH ${dep_op_path_list} find_dep_ops_count)
    if(find_dep_ops_count GREATER 1)
      message(FATAL_ERROR "dependent operator(${dep_op}) is not unique, the found operators:${dep_op_path_list}")
    endif()

    # ASCEND_OP_NAME 为空表示全部编译，则不需要特意添加目录；但指定experimental时未扫描常规算子，如果依赖常规算子，需要添加目录
    # 已在待编译列表，则不需要加入
    # 已在编译列表，则不需要重复加入

    if((ASCEND_OP_NAME OR outside_experimental)
        AND (NOT (dep_op IN_LIST ASCEND_OP_NAME))
        AND (NOT (dep_op IN_LIST COMPILED_OPS))
    )
      # 加入依赖并去重
      if (NOT ASCEND_OP_NAME STREQUAL "ALL")
          add_need_compile_ops("${dep_op}")
      endif()
      # 添加目录
      get_filename_component(dep_op_path "${dep_op_path_list}" ABSOLUTE)
      get_filename_component(dep_op_parent "${dep_op_path}" DIRECTORY)
      get_filename_component(parent_path "${dep_op_parent}" NAME)
      message(STATUS "add dependent operator: ${parent_path}/${dep_op}, path: ${dep_op_path}")
      add_subdirectory("${dep_op_path}" "${CMAKE_BINARY_DIR}/dependent-ops/${parent_path}/${dep_op}")
    endif()
  endforeach()
endfunction()

function(add_aicpu_kernel_modules)
  if(NOT TARGET ${OPHOST_NAME}_aicpu_obj)
    add_library(${OPHOST_NAME}_aicpu_obj OBJECT)
    target_include_directories(${OPHOST_NAME}_aicpu_obj PRIVATE ${AICPU_INCLUDE})
    target_compile_definitions(
      ${OPHOST_NAME}_aicpu_obj PRIVATE _FORTIFY_SOURCE=2 google=ascend_private
                                       $<$<BOOL:${ENABLE_TEST}>:ASCEND_AICPU_UT>
      )
    target_compile_options(
      ${OPHOST_NAME}_aicpu_obj PRIVATE $<$<NOT:$<BOOL:${ENABLE_TEST}>>:-DDISABLE_COMPILE_V1> -Dgoogle=ascend_private
                                       -fvisibility=hidden ${AICPU_DEFINITIONS}
      )
    target_link_libraries(
      ${OPHOST_NAME}_aicpu_obj
      PRIVATE $<BUILD_INTERFACE:$<IF:$<BOOL:${ENABLE_TEST}>,intf_llt_pub_asan_cxx17,intf_pub_cxx17>>
              $<BUILD_INTERFACE:dlog_headers>
      )
  endif()
endfunction()

function(add_aicpu_cust_kernel_modules op_name aicpu_sources aicpu_jsons)
  set(target_name ${op_name}_obj)
  message(STATUS "target_name ==> ${op_name}_obj")
  message(STATUS "AICPU_INCLUDE ==> ${AICPU_INCLUDE}")
  if(NOT TARGET ${target_name})
    add_library(${target_name} OBJECT)
    target_include_directories(${target_name} PRIVATE ${AICPU_INCLUDE})
    target_compile_definitions(
      ${target_name} PRIVATE
                    _FORTIFY_SOURCE=2 _GLIBCXX_USE_CXX11_ABI=1
                    google=ascend_private
                    $<$<BOOL:${ENABLE_TEST}>:ASCEND_AICPU_UT>
      )
    target_compile_options(
      ${target_name} PRIVATE
                    $<$<NOT:$<BOOL:${ENABLE_TEST}>>:-DDISABLE_COMPILE_V1> -Dgoogle=ascend_private
                    -fvisibility=hidden ${AICPU_DEFINITIONS}
      )
    target_link_libraries(
      ${target_name}
      PRIVATE $<BUILD_INTERFACE:$<IF:$<BOOL:${ENABLE_TEST}>,intf_llt_pub_asan_cxx17,intf_pub_cxx17>>
              $<BUILD_INTERFACE:dlog_headers>
              -Wl,--no-whole-archive
      )
    if (NOT (UT_TEST_ALL OR OP_KERNEL_AICPU_UT))
      set_property(TARGET ${target_name} PROPERTY
        CXX_COMPILER_LAUNCHER ${ASCEND_DIR}/toolkit/toolchain/hcc/bin/aarch64-target-linux-gnu-g++)
    endif()
    target_sources(${target_name} PRIVATE ${aicpu_sources})
    set_property(GLOBAL APPEND PROPERTY AICPU_JSON_FILES ${aicpu_jsons})
    if (NOT ${target_name} IN_LIST AICPU_CUST_OBJ_TARGETS)
      set(AICPU_CUST_OBJ_TARGETS ${AICPU_CUST_OBJ_TARGETS} ${target_name} CACHE INTERNAL "All aicpu cust obj targets")
    endif()
  endif()
endfunction()

# usage: add_modules_sources_aicpu(OPTYPE ACLNNTYPE DEPENDENCIES COMPUTE_UNIT TILING_DIR DISABLE_IN_OPP)
# ACLNNTYPE 支持类型aclnn/aclnn_inner/aclnn_exclude
# OPTYPE 和 ACLNNTYPE 需一一对应
# DEPENDENCIES 指定依赖的算子名称列表，如果开启 experimental，则会优先加载 experimental 下的算子
# COMPUTE_UNIT 设置支持芯片版本号，必须与TILING_DIR一一对应，示例：ascend910b ascend910_95
# TILING_DIR 设置所支持芯片类型对应的tiling文件目录，必须与COMPUTE_UNIT一一对应，示例：arch32 arch35
# DISABLE_IN_OPP 设置是否在opp包中编译tiling文件，布尔类型：TRUE，FALSE
macro(add_modules_sources_aicpu)
  set(oneValueArgs DISABLE_IN_OPP)
  set(multiValueArgs OPTYPE ACLNNTYPE DEPENDENCIES COMPUTE_UNIT TILING_DIR)

  cmake_parse_arguments(MODULE "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  set(SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  get_filename_component(OP_NAME ${SOURCE_DIR} NAME)

  add_dependent_ops("${MODULE_DEPENDENCIES}")

  # opapi l0 默认全部编译
  file(GLOB OPAPI_L0_SRCS ${SOURCE_DIR}/op_api/*.cpp)
  list(FILTER OPAPI_L0_SRCS EXCLUDE REGEX "aclnn_")
  if(OPAPI_L0_SRCS)
    add_opapi_modules()
    target_sources(${OPHOST_NAME}_opapi_obj PRIVATE ${OPAPI_L0_SRCS})
  endif()

  file(GLOB OPAPI_HEADERS ${SOURCE_DIR}/op_api/aclnn_*.h)
  if(OPAPI_HEADERS)
    target_sources(${OPHOST_NAME}_aclnn_exclude_headers INTERFACE ${OPAPI_HEADERS})
  endif()

  file(GLOB OPAPI_L2_SRCS ${SOURCE_DIR}/op_api/aclnn_*.cpp)
  if(OPAPI_L2_SRCS)
    add_opapi_modules()
    message(STATUS "959: ${OPAPI_L2_SRCS}")
    target_sources(${OPHOST_NAME}_opapi_obj PRIVATE ${OPAPI_L2_SRCS})
  endif()

  file(GLOB OPINFER_SRCS ${SOURCE_DIR}/op_host/*_infershape*.cpp)
  if(OPINFER_SRCS)
    add_infer_modules()
    target_sources(${OPHOST_NAME}_infer_obj PRIVATE ${OPINFER_SRCS})
  endif()

  file(GLOB OPTILING_SRCS ${SOURCE_DIR}/*_tiling*.cpp)
  if(OPTILING_SRCS)
    add_tiling_modules()
    target_sources(${OPHOST_NAME}_tiling_obj PRIVATE ${OPTILING_SRCS})
  else()
    if (NOT TARGET ${OPHOST_NAME}_tiling_obj)
      add_tiling_modules()
      add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/optiling_stub.cpp
          COMMAND touch ${CMAKE_CURRENT_BINARY_DIR}/optiling_stub.cpp
      )
      target_sources(${OPHOST_NAME}_tiling_obj PRIVATE
          ${CMAKE_CURRENT_BINARY_DIR}/optiling_stub.cpp
      )
    endif()
  endif()


  file(GLOB AICPU_SRCS ${SOURCE_DIR}/op_kernel_aicpu/*_aicpu*.cpp)

  if(AICPU_SRCS)
    if(NOT BUILD_WITH_INSTALLED_DEPENDENCY_CANN_PKG)
      add_aicpu_kernel_modules()
      target_sources(${OPHOST_NAME}_aicpu_obj PRIVATE ${AICPU_SRCS})
    else()
      file(GLOB AICPU_JSON_FILE ${SOURCE_DIR}/op_kernel_aicpu/*.json)
      add_aicpu_cust_kernel_modules(${OP_NAME} ${AICPU_SRCS} ${AICPU_JSON_FILE})
    endif()
  endif()

  if(MODULE_OPTYPE)
    list(LENGTH MODULE_OPTYPE OpTypeLen)
    list(LENGTH MODULE_ACLNNTYPE AclnnTypeLen)
    if(NOT ${OpTypeLen} EQUAL ${AclnnTypeLen})
      message(FATAL_ERROR "OPTYPE AND ACLNNTYPE Should be One-to-One")
    endif()
    math(EXPR index "${OpTypeLen} - 1")
    foreach(i RANGE ${index})
      list(GET MODULE_OPTYPE ${i} OpType)
      list(GET MODULE_ACLNNTYPE ${i} AclnnType)
      if(${AclnnType} STREQUAL "aclnn"
         OR ${AclnnType} STREQUAL "aclnn_inner"
         OR ${AclnnType} STREQUAL "aclnn_exclude"
        )
        file(GLOB OPDEF_SRCS ${SOURCE_DIR}/op_host/${OpType}_def*.cpp)
        if(OPDEF_SRCS)
          target_sources(${OPHOST_NAME}_opdef_${AclnnType}_obj INTERFACE ${OPDEF_SRCS})
        endif()
      else()
        message(FATAL_ERROR "ACLNN TYPE UNSPPORTED, ONLY SUPPORT aclnn/aclnn_inner/aclnn_exclude")
      endif()
    endforeach()
  else()
    file(GLOB OPDEF_SRCS ${SOURCE_DIR}/op_host/*_def*.cpp)
    if(OPDEF_SRCS)
      message(
        FATAL_ERROR
          "Should Manually specify aclnn/aclnn_inner/aclnn_exclude\n"
          "usage: add_modules_sources_aicpu(OPTYPE optypes ACLNNTYPE aclnntypes)\n"
          "example: add_modules_sources_aicpu(OPTYPE add ACLNNTYPE aclnn_exclude)"
        )
    endif()
  endif()

  file(GLOB OP_GRAPH_PROTO_HEADERS ${SOURCE_DIR}/op_graph/*_proto*.h)
  if(OP_GRAPH_PROTO_HEADERS)
    target_sources(${GRAPH_PLUGIN_NAME}_proto_headers INTERFACE ${OP_GRAPH_PROTO_HEADERS})
  endif()

  set(ENABLE_AICPU ON CACHE BOOL "enable aicpu kernel" FORCE)

endmacro()

function(gen_cust_aicpu_json_symbol)
  get_property(ALL_AICPU_JSON_FILES GLOBAL PROPERTY AICPU_JSON_FILES)
  if(NOT ALL_AICPU_JSON_FILES)
    message(STATUS "No aicpu json files to merge, skipping.")
    return()
  endif()

  set(MERGED_JSON ${CMAKE_BINARY_DIR}/cust_aicpu_kernel.json)
  add_custom_command(
    OUTPUT ${MERGED_JSON}
    COMMAND bash ${CMAKE_SOURCE_DIR}/scripts/util/merge_aicpu_info_json.sh ${CMAKE_SOURCE_DIR} ${MERGED_JSON} ${ALL_AICPU_JSON_FILES}
    DEPENDS ${ALL_AICPU_JSON_FILES}
    COMMENT "Merging Json files into ${MERGED_JSON}"
    VERBATIM
  )
  add_custom_target(merge_aicpu_json ALL DEPENDS ${MERGED_JSON})
  install(
    FILES ${MERGED_JSON}
    DESTINATION packages/vendors/${VENDOR_NAME}/op_impl/cpu/config
    OPTIONAL
  )
endfunction()

function(gen_cust_aicpu_kernel_symbol)
  if(NOT AICPU_CUST_OBJ_TARGETS)
    message(STATUS "No aicpu cust obj targets found, skipping.")
    return()
  endif()

  set(ARM_CXX_COMPILER ${ASCEND_DIR}/toolkit/toolchain/hcc/bin/aarch64-target-linux-gnu-g++)
  set(ARM_SO_OUTPUT ${CMAKE_BINARY_DIR}/libtransformer_aicpu_kernels.so)

  set(ALL_OBJECTS "")
  foreach(tgt IN LISTS AICPU_CUST_OBJ_TARGETS)
    list(APPEND ALL_OBJECTS $<TARGET_OBJECTS:${tgt}>)
  endforeach()

  message(STATUS "Linking cust_aicpu_kernels with ARM toolchain: ${ARM_CXX_COMPILER}")
  message(STATUS "Objects: ${ALL_OBJECTS}")
  message(STATUS "Output: ${ARM_SO_OUTPUT}")

  if(EXISTS ${ASCEND_DIR}/ops_base/lib64/libaicpu_context.a)
    set(LIBAICPU_CONTEXT_PATH ${ASCEND_DIR}/ops_base/lib64/libaicpu_context.a)
  else()
    set(LIBAICPU_CONTEXT_PATH ${ASCEND_DIR}/lib64/libaicpu_context.a)
  endif()

  if(EXISTS ${ASCEND_DIR}/ops_base/lib64/libbase_ascend_protobuf.a)
    set(LIBBASE_ASCEND_PROTOBUF_PATH ${ASCEND_DIR}/ops_base/lib64/libbase_ascend_protobuf.a)
  else()
    set(LIBBASE_ASCEND_PROTOBUF_PATH ${ASCEND_DIR}/lib64/libbase_ascend_protobuf.a)
  endif()

  add_custom_command(
    OUTPUT ${ARM_SO_OUTPUT}
    COMMAND ${ARM_CXX_COMPILER} -shared ${ALL_OBJECTS}
      -Wl,--whole-archive
      ${LIBAICPU_CONTEXT_PATH}
      ${LIBBASE_ASCEND_PROTOBUF_PATH}
      -Wl,--no-whole-archive
      -Wl,-Bsymbolic
      -Wl,--exclude-libs=libbase_ascend_protobuf.a
      -s
      -o ${ARM_SO_OUTPUT}
    DEPENDS ${AICPU_CUST_OBJ_TARGETS}
    COMMENT "Linking cust_aicpu_kernels.so using ARM toolchain"
  )
  add_custom_target(cust_aicpu_kernels ALL DEPENDS ${ARM_SO_OUTPUT})

  install(
    FILES ${ARM_SO_OUTPUT}
    DESTINATION packages/vendors/${VENDOR_NAME}/op_impl/cpu/aicpu_kernel/impl
    OPTIONAL
  )
endfunction()

# 添加opapi object
function(add_opapi_modules)
  if (NOT TARGET ${OPHOST_NAME}_opapi_obj)
    add_library(${OPHOST_NAME}_opapi_obj OBJECT)
    unset(OPAPI_UT_DEPEND_INC)
    if(UT_TEST_ALL OR OP_API_UT)
      set(OPAPI_UT_DEPEND_INC ${UT_PATH}/op_api/stub)
    endif()
    target_include_directories(${OPHOST_NAME}_opapi_obj
      PRIVATE
      ${OPAPI_INCLUDE}
      ${OPAPI_UT_DEPEND_INC}
      $<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include>
      $<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include/aclnn>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include/experiment/metadef/common/util>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/pkg_inc>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/pkg_inc/op_common>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/pkg_inc/op_common/op_host>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/include/op_common>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/include/op_common/op_host>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/include/experiment/hccl/external>>
      $<$<BOOL:${BUILD_OPEN_PROJECT}>:$<BUILD_INTERFACE:${ASCEND_CANN_PACKAGE_PATH}/${SYSTEM_PREFIX}/pkg_inc/profiling>>
    )
    target_compile_definitions(${OPHOST_NAME}_opapi_obj PRIVATE
      _GLIBCXX_USE_CXX11_ABI=0
      BUILD_OPEN_PROJECT_API=1
    )
    target_compile_options(${OPHOST_NAME}_opapi_obj
      PRIVATE
      -Dgoogle=ascend_private
      -DACLNN_LOG_FMT_CHECK
    )
    target_link_libraries(${OPHOST_NAME}_opapi_obj
      PUBLIC
      $<BUILD_INTERFACE:intf_pub>
      $<BUILD_INTERFACE:$<IF:$<BOOL:${ENABLE_TEST}>,intf_llt_pub_asan_cxx17,intf_pub_cxx17>>
      -Wl,--whole-archive
      ops_aclnn
      -Wl,--no-whole-archive
      $<$<BOOL:${dlog_FOUND}>:$<BUILD_INTERFACE:dlog_headers>>
      nnopbase
      profapi
      ge_common_base
      ascend_dump
      ascendalog
      dl
      )
  endif()
endfunction()