# CANN 9.0.1's makeself scripts use /tmp/mkself<pid> directly instead of
# honoring TMPDIR. Keep direct `cpack`/`cmake --build --target package` calls
# working in minimal containers where /tmp is absent.
if(NOT EXISTS "/tmp")
    file(MAKE_DIRECTORY "/tmp")
    execute_process(COMMAND chmod 1777 /tmp RESULT_VARIABLE _chmod_result)
    if(NOT _chmod_result EQUAL 0)
        message(FATAL_ERROR "Created /tmp, but failed to set permissions required by CANN makeself.")
    endif()
endif()

if(NOT IS_DIRECTORY "/tmp")
    message(FATAL_ERROR "/tmp must be a directory for CANN makeself packaging.")
endif()

execute_process(COMMAND test -w /tmp RESULT_VARIABLE _tmp_not_writable)
if(NOT _tmp_not_writable EQUAL 0)
    message(FATAL_ERROR "/tmp is not writable; CANN cannot create the custom-op run package.")
endif()
