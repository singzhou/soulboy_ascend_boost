from __future__ import annotations

import os
from pathlib import Path

import torch
import torch.nn.functional as F

_LOADED = False


def load_library(path: str | os.PathLike[str] | None = None) -> None:
    """Load the compiled PTA registration library exactly once."""
    global _LOADED
    if _LOADED:
        return
    if path is None:
        path = os.getenv("SOULBOY_PTA_LIBRARY")
    if path is None:
        root = Path(__file__).resolve().parents[2]
        path = root / "output" / "lib" / "libsoulboy_pta.so"
    path = Path(path)
    if not path.is_file():
        raise FileNotFoundError(
            f"PTA library not found: {path}. Build it with ./build.sh --pta."
        )
    torch.ops.load_library(str(path))
    _LOADED = True


def _check_inputs(
    x: torch.Tensor,
    weight: torch.Tensor,
    bias: torch.Tensor,
    valid_rows: torch.Tensor,
) -> None:
    if x.ndim != 2 or weight.ndim != 2 or bias.ndim != 1:
        raise ValueError("x/weight/bias must have ranks 2/2/1")
    if x.shape[1] != weight.shape[0] or weight.shape[1] != bias.shape[0]:
        raise ValueError("incompatible x, weight and bias shapes")
    if valid_rows.dtype != torch.int64 or valid_rows.numel() != 1:
        raise TypeError("valid_rows must be a one-element torch.int64 tensor")
    if not (x.device == weight.device == bias.device == valid_rows.device):
        raise ValueError("all inputs must be on the same device")


def valid_rows_matmul_gelu(
    x: torch.Tensor,
    weight: torch.Tensor,
    bias: torch.Tensor,
    valid_rows: torch.Tensor,
    *,
    fallback: bool = False,
) -> torch.Tensor:
    """Compute GELU(x @ weight + bias), zeroing rows >= valid_rows.

    ``valid_rows`` remains a tensor so graph/eager callers do not need a
    device-to-host scalar read. ``fallback=True`` is intended for CPU-side
    development and contract tests.
    """
    _check_inputs(x, weight, bias, valid_rows)
    if not fallback:
        load_library()
        return torch.ops.soulboy.valid_rows_matmul_gelu(x, weight, bias, valid_rows)
    value = F.gelu(x.float() @ weight.float() + bias.float(), approximate="none")
    rows = torch.arange(x.shape[0], device=x.device)
    return (value * (rows < valid_rows.reshape(())).unsqueeze(1)).to(x.dtype)
