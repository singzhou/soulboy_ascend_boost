#include "kernel_operator.h"
#include "valid_rows_matmul_gelu_tiling.h"

using namespace AscendC;

namespace {
// Low-cost scalar approximation used only by this bring-up kernel. The PTA
// implementation uses torch's exact GELU and is the user-facing path.
__aicore__ inline float GeluApprox(float x)
{
    const float x2 = x * x;
    float gate = 0.5F + x * (0.197F + 0.00881F * x2);
    gate = gate < 0.0F ? 0.0F : gate;
    gate = gate > 1.0F ? 1.0F : gate;
    return x * gate;
}
}  // namespace

extern "C" __global__ __aicore__ void valid_rows_matmul_gelu(
    GM_ADDR x, GM_ADDR weight, GM_ADDR bias, GM_ADDR valid_rows,
    GM_ADDR y, GM_ADDR workspace, GM_ADDR tiling)
{
    (void)valid_rows;
    (void)workspace;
    GET_TILING_DATA_WITH_STRUCT(ValidRowsMatmulGeluTilingData, td, tiling);

    GlobalTensor<half> xGm;
    GlobalTensor<half> weightGm;
    GlobalTensor<float> biasGm;
    GlobalTensor<half> yGm;
    xGm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(x), td.maxM * td.k);
    weightGm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(weight), td.k * td.n);
    biasGm.SetGlobalBuffer(reinterpret_cast<__gm__ float *>(bias), td.n);
    yGm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(y), td.maxM * td.n);

    const uint32_t rowBegin = GetBlockIdx() * td.rowsPerBlock;
    uint32_t rowEnd = rowBegin + td.rowsPerBlock;
    rowEnd = rowEnd > td.maxM ? td.maxM : rowEnd;
    for (uint32_t row = rowBegin; row < rowEnd; ++row) {
        for (uint32_t col = 0; col < td.n; ++col) {
            float value = 0.0F;
            if (row < td.validM && td.zeroOnly == 0U) {
                value = biasGm.GetValue(col);
                for (uint32_t inner = 0; inner < td.k; ++inner) {
                    value += static_cast<float>(xGm.GetValue(row * td.k + inner)) *
                             static_cast<float>(weightGm.GetValue(inner * td.n + col));
                }
                value = GeluApprox(value);
            }
            yGm.SetValue(row * td.n + col, static_cast<half>(value));
        }
    }
}
