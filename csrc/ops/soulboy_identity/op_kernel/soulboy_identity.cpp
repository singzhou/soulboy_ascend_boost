#include "kernel_operator.h"

using namespace AscendC;

namespace {
constexpr uint32_t kElementsPerBlock = 16;
}

extern "C" __global__ __aicore__ void soulboy_identity(
    GM_ADDR input, GM_ADDR output, uint32_t element_count)
{
    GlobalTensor<half> input_gm;
    GlobalTensor<half> output_gm;

    const uint32_t block_count = GetBlockNum();
    const uint32_t block_index = GetBlockIdx();
    const uint32_t aligned_count = element_count / kElementsPerBlock * kElementsPerBlock;
    const uint32_t elements_per_core =
        (aligned_count / block_count / kElementsPerBlock) * kElementsPerBlock;
    const uint32_t offset = block_index * elements_per_core;

    input_gm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(input) + offset, elements_per_core);
    output_gm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(output) + offset, elements_per_core);

    for (uint32_t i = 0; i < elements_per_core; i += kElementsPerBlock) {
        for (uint32_t j = 0; j < kElementsPerBlock; ++j) {
            output_gm.SetValue(i + j, input_gm.GetValue(i + j));
        }
    }
}
