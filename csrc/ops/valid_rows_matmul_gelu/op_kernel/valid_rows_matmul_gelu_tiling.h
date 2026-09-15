#ifndef SOULBOY_VALID_ROWS_MATMUL_GELU_TILING_H
#define SOULBOY_VALID_ROWS_MATMUL_GELU_TILING_H

#include "register/tilingdata_base.h"

namespace optiling {
BEGIN_TILING_DATA_DEF(ValidRowsMatmulGeluTilingData)
    TILING_DATA_FIELD_DEF(uint32_t, maxM);
    TILING_DATA_FIELD_DEF(uint32_t, validM);
    TILING_DATA_FIELD_DEF(uint32_t, n);
    TILING_DATA_FIELD_DEF(uint32_t, k);
    TILING_DATA_FIELD_DEF(uint32_t, rowsPerBlock);
    TILING_DATA_FIELD_DEF(uint32_t, zeroOnly);
END_TILING_DATA_DEF;

REGISTER_TILING_DATA_CLASS(ValidRowsMatmulGelu, ValidRowsMatmulGeluTilingData)
}  // namespace optiling

#endif
