#include <algorithm>
#include <cstdint>

#ifdef SOULBOY_DEVICE_TILING
#include "register/device_op_impl_registry.h"
#else
#include "register/op_impl_registry.h"
#endif
#include "tiling/platform/platform_ascendc.h"
#include "valid_rows_matmul_gelu_tiling.h"

namespace optiling {
namespace {
constexpr uint32_t kFallbackCoreCount = 1;

ge::graphStatus FillTiling(gert::TilingContext *context)
{
    if (context == nullptr || context->GetInputShape(0) == nullptr ||
        context->GetInputShape(1) == nullptr) {
        return ge::GRAPH_FAILED;
    }
    const auto &xShape = context->GetInputShape(0)->GetStorageShape();
    const auto &wShape = context->GetInputShape(1)->GetStorageShape();
    if (xShape.GetDimNum() != 2 || wShape.GetDimNum() != 2) {
        return ge::GRAPH_FAILED;
    }
    const uint32_t maxM = static_cast<uint32_t>(xShape.GetDim(0));
    const uint32_t k = static_cast<uint32_t>(xShape.GetDim(1));
    const uint32_t n = static_cast<uint32_t>(wShape.GetDim(1));
    if (maxM == 0 || k == 0 || n == 0 || wShape.GetDim(0) != xShape.GetDim(1)) {
        return ge::GRAPH_FAILED;
    }

    uint32_t validM = maxM;  // compile phase: reserve/compile for the static maximum
    const auto *rowsTensor = context->GetInputTensor(3);
    if (rowsTensor != nullptr) {
        const int64_t *rows = rowsTensor->GetData<int64_t>();
        if (rows != nullptr) {
            if (*rows < 0 || *rows > static_cast<int64_t>(maxM)) {
                return ge::GRAPH_FAILED;
            }
            validM = static_cast<uint32_t>(*rows);
        }
    }

    uint32_t coreCount = kFallbackCoreCount;
    if (context->GetPlatformInfo() != nullptr) {
        platform_ascendc::PlatformAscendC platform(context->GetPlatformInfo());
        coreCount = std::max(kFallbackCoreCount, platform.GetCoreNumAiv());
    }
    coreCount = std::min(coreCount, maxM);

    ValidRowsMatmulGeluTilingData td;
    td.set_maxM(maxM);
    td.set_validM(validM);
    td.set_n(n);
    td.set_k(k);
    td.set_rowsPerBlock((maxM + coreCount - 1U) / coreCount);
    td.set_zeroOnly(validM == 0U ? 1U : 0U);
    td.SaveToBuffer(context->GetRawTilingData()->GetData(), context->GetRawTilingData()->GetCapacity());
    context->GetRawTilingData()->SetDataSize(td.GetDataSize());
    context->SetBlockDim(coreCount);
    context->SetTilingKey(1);
    if (context->GetWorkspaceSizes(1) != nullptr) {
        context->GetWorkspaceSizes(1)[0] = 0;
    }
    return ge::GRAPH_SUCCESS;
}
}  // namespace

ge::graphStatus ValidRowsMatmulGeluTiling(gert::TilingContext *context)
{
    return FillTiling(context);
}

#ifdef SOULBOY_DEVICE_TILING
DEVICE_IMPL_OP_OPTILING(ValidRowsMatmulGelu).Tiling(ValidRowsMatmulGeluTiling);
#else
IMPL_OP_OPTILING(ValidRowsMatmulGelu).Tiling(ValidRowsMatmulGeluTiling);
#endif
}  // namespace optiling
