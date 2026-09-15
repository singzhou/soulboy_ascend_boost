import torch

from soulboy_ascend_boost import valid_rows_matmul_gelu


def main() -> None:
    import torch_npu  # noqa: F401  # registers the NPU device with PyTorch

    torch.manual_seed(7)
    device = torch.device("npu:0")
    m_max, k, n = 128, 256, 512
    x = torch.randn(m_max, k, dtype=torch.float16, device=device)
    weight = torch.randn(k, n, dtype=torch.float16, device=device)
    bias = torch.randn(n, dtype=torch.float32, device=device)
    valid_rows = torch.tensor([17], dtype=torch.int64, device=device)

    actual = valid_rows_matmul_gelu(x, weight, bias, valid_rows)
    expected = valid_rows_matmul_gelu(x, weight, bias, valid_rows, fallback=True)
    torch.testing.assert_close(actual, expected, rtol=2e-3, atol=2e-3)
    print(f"ok: shape={tuple(actual.shape)}, valid_rows=17, tail_nonzero={actual[17:].count_nonzero().item()}")


if __name__ == "__main__":
    main()
