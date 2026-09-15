"""PyTorch NPU bindings for soulboy custom operators."""

import torch
import torch_npu

try:
    from . import custom_ops_lib  # noqa: F401
except ImportError as error:
    raise ImportError(
        "failed to load soulboy_custom_ops.custom_ops_lib; run "
        "'cd torch_ops_extension && bash build_and_install.sh' to build "
        "both the wheel and the in-place native extension"
    ) from error


def npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows):
    return torch.ops.custom.npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows)


setattr(torch_npu, "npu_valid_rows_matmul_gelu", npu_valid_rows_matmul_gelu)

__all__ = ["npu_valid_rows_matmul_gelu"]
