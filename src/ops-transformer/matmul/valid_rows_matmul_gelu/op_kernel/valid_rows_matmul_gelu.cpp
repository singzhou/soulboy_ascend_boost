#include "kernel_operator.h"

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
    GET_TILING_DATA(tilingData, tiling);

    GlobalTensor<half> xGm;
    GlobalTensor<half> weightGm;
    GlobalTensor<float> biasGm;
    GlobalTensor<half> yGm;
    xGm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(x), tilingData.maxM * tilingData.k);
    weightGm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(weight), tilingData.k * tilingData.n);
    biasGm.SetGlobalBuffer(reinterpret_cast<__gm__ float *>(bias), tilingData.n);
    yGm.SetGlobalBuffer(reinterpret_cast<__gm__ half *>(y), tilingData.maxM * tilingData.n);

    const uint32_t rowBegin = GetBlockIdx() * tilingData.rowsPerBlock;
    uint32_t rowEnd = rowBegin + tilingData.rowsPerBlock;
    rowEnd = rowEnd > tilingData.maxM ? tilingData.maxM : rowEnd;
    for (uint32_t row = rowBegin; row < rowEnd; ++row) {
        for (uint32_t col = 0; col < tilingData.n; ++col) {
            float value = 0.0F;
            if (row < tilingData.validM && tilingData.zeroOnly == 0U) {
                value = biasGm.GetValue(col);
                for (uint32_t inner = 0; inner < tilingData.k; ++inner) {
                    value += static_cast<float>(xGm.GetValue(row * tilingData.k + inner)) *
                             static_cast<float>(weightGm.GetValue(inner * tilingData.n + col));
                }
                value = GeluApprox(value);
            }
            yGm.SetValue(row * tilingData.n + col, static_cast<half>(value));
        }
    }
}
