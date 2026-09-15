#include <ATen/ATen.h>
#include <torch/library.h>

namespace soulboy {
at::Tensor ValidRowsMatmulGelu(
    const at::Tensor &x, const at::Tensor &weight, const at::Tensor &bias,
    const at::Tensor &validRows)
{
    TORCH_CHECK(x.dim() == 2 && weight.dim() == 2 && bias.dim() == 1,
                "x/weight/bias must have ranks 2/2/1");
    TORCH_CHECK(x.size(1) == weight.size(0) && weight.size(1) == bias.size(0),
                "incompatible x, weight and bias shapes");
    TORCH_CHECK(validRows.numel() == 1 && validRows.scalar_type() == at::kLong,
                "valid_rows must be a one-element int64 tensor");

    auto value = at::gelu(at::matmul(x, weight) + bias, "none");
    auto rowIds = at::arange(x.size(0), validRows.options());
    auto mask = rowIds.lt(validRows.reshape({})).unsqueeze(1);
    return value * mask.to(value.scalar_type());
}

at::Tensor ValidRowsMatmulGeluMeta(
    const at::Tensor &x, const at::Tensor &weight, const at::Tensor &bias,
    const at::Tensor &validRows)
{
    (void)bias;
    (void)validRows;
    return at::empty({x.size(0), weight.size(1)}, x.options());
}
}  // namespace soulboy

TORCH_LIBRARY(soulboy, m)
{
    m.def("valid_rows_matmul_gelu(Tensor x, Tensor weight, Tensor bias, Tensor valid_rows) -> Tensor");
}

TORCH_LIBRARY_IMPL(soulboy, PrivateUse1, m)
{
    m.impl("valid_rows_matmul_gelu", &soulboy::ValidRowsMatmulGelu);
}

TORCH_LIBRARY_IMPL(soulboy, Meta, m)
{
    m.impl("valid_rows_matmul_gelu", &soulboy::ValidRowsMatmulGeluMeta);
}
