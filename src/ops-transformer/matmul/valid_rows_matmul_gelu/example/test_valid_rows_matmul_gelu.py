import torch
import torch_npu

import soulboy_custom_ops  # noqa: F401


def gelu_bringup_reference(value: torch.Tensor) -> torch.Tensor:
    value = value.float()
    gate = (0.5 + value * (0.197 + 0.00881 * value.square())).clamp(0.0, 1.0)
    return value * gate


def main() -> None:
    torch.manual_seed(7)
    device = torch.device("npu:0")
    m, k, n = 32, 16, 24
    x = torch.randn(m, k, dtype=torch.float16, device=device) * 0.1
    weight = torch.randn(k, n, dtype=torch.float16, device=device) * 0.1
    bias = torch.randn(n, dtype=torch.float32, device=device) * 0.1

    for row_count in (0, 1, 17, m):
        valid_rows = torch.tensor([row_count], dtype=torch.int64, device=device)
        actual = torch_npu.npu_valid_rows_matmul_gelu(x, weight, bias, valid_rows)
        expected = gelu_bringup_reference(x.float() @ weight.float() + bias)
        expected[row_count:] = 0
        torch.testing.assert_close(actual.float(), expected, rtol=5e-3, atol=5e-3)

    print("ValidRowsMatmulGelu passed")


if __name__ == "__main__":
    main()
