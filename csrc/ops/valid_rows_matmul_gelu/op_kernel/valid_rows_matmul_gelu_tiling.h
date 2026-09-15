#ifndef SOULBOY_VALID_ROWS_MATMUL_GELU_TILING_H
#define SOULBOY_VALID_ROWS_MATMUL_GELU_TILING_H

#include <cstdint>
#include "kernel_tiling/kernel_tiling.h"

// Kernel-side wire representation. Keep this POD layout byte-for-byte in sync
// with the fields in op_host/valid_rows_matmul_gelu_tiling.h. Host registration
// headers are deliberately not included in AI Core compilation.
#pragma pack(push, 8)
struct alignas(8) ValidRowsMatmulGeluTilingData {
    uint32_t maxM;
    uint32_t validM;
    uint32_t n;
    uint32_t k;
    uint32_t rowsPerBlock;
    uint32_t zeroOnly;
};
#pragma pack(pop)

#endif
