#include <torch/extension.h>
#include <torch/library.h>

TORCH_LIBRARY_FRAGMENT(custom, m)
{
    m.def("npu_valid_rows_matmul_gelu(Tensor x, Tensor weight, Tensor bias, Tensor valid_rows) -> Tensor");
}

PYBIND11_MODULE(TORCH_EXTENSION_NAME, m)
{}
