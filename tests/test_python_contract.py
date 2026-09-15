import pytest

torch = pytest.importorskip("torch")

from soulboy_ascend_boost import valid_rows_matmul_gelu


@pytest.mark.parametrize("valid", [0, 1, 15, 16, 17, 32])
def test_fallback_contract(valid: int) -> None:
    torch.manual_seed(1)
    x = torch.randn(32, 16, dtype=torch.float16)
    weight = torch.randn(16, 24, dtype=torch.float16)
    bias = torch.randn(24, dtype=torch.float32)
    valid_rows = torch.tensor([valid], dtype=torch.int64)
    result = valid_rows_matmul_gelu(x, weight, bias, valid_rows, fallback=True)
    assert result.shape == (32, 24)
    assert torch.count_nonzero(result[valid:]) == 0


def test_rejects_incompatible_shape() -> None:
    with pytest.raises(ValueError, match="incompatible"):
        valid_rows_matmul_gelu(
            torch.randn(4, 3), torch.randn(2, 5), torch.randn(5),
            torch.tensor([2]), fallback=True,
        )
