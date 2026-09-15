find_package(Torch REQUIRED)

add_library(soulboy_pta SHARED valid_rows_matmul_gelu.cpp)
target_link_libraries(soulboy_pta PRIVATE "${TORCH_LIBRARIES}")
target_compile_features(soulboy_pta PRIVATE cxx_std_17)
set_target_properties(soulboy_pta PROPERTIES PREFIX "lib")
install(TARGETS soulboy_pta LIBRARY DESTINATION lib)
