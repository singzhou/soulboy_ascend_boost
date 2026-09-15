"""PyTorch NPU bindings for soulboy custom operators."""

import torch
import torch_npu

from . import custom_ops_lib  # noqa: F401


def npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows):
    return torch.ops.custom.npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows)


setattr(torch_npu, "npu_valid_rows_matmul_gelu", npu_valid_rows_matmul_gelu)

__all__ = ["npu_valid_rows_matmul_gelu"]
