#include <torch/library.h>
#include "../../../../csrc_base/ops_common.h"

namespace custom {

at::Tensor npu_valid_rows_matmul_gelu(
    const at::Tensor &x,
    const at::Tensor &weight,
    const at::Tensor &bias,
    const at::Tensor &validRows)
{
    TORCH_CHECK(x.dim() == 2, "x must be rank 2");
    TORCH_CHECK(weight.dim() == 2, "weight must be rank 2");
    TORCH_CHECK(bias.dim() == 1, "bias must be rank 1");
    TORCH_CHECK(validRows.numel() == 1 && validRows.scalar_type() == at::kLong,
                "valid_rows must be a one-element int64 tensor");
    TORCH_CHECK(x.size(1) == weight.size(0) && weight.size(1) == bias.size(0),
                "incompatible x, weight and bias shapes");

    auto out = at::empty({x.size(0), weight.size(1)}, x.options());
    EXEC_NPU_CMD_V1(aclnnValidRowsMatmulGelu, x, weight, bias, validRows, out);
    return out;
}

at::Tensor npu_valid_rows_matmul_gelu_meta(
    const at::Tensor &x,
    const at::Tensor &weight,
    const at::Tensor &bias,
    const at::Tensor &validRows)
{
    (void)bias;
    (void)validRows;
    c10::SmallVector<c10::SymInt, 2> outSize = {x.sym_size(0), weight.sym_size(1)};
    return at::empty_symint(outSize, x.options());
}

}  // namespace custom

TORCH_LIBRARY_IMPL(custom, PrivateUse1, m)
{
    m.impl("npu_valid_rows_matmul_gelu", &custom::npu_valid_rows_matmul_gelu);
}

TORCH_LIBRARY_IMPL(custom, Meta, m)
{
    m.impl("npu_valid_rows_matmul_gelu", &custom::npu_valid_rows_matmul_gelu_meta);
}
