import pytest

from app.metrics import parse_cpu_quantity, parse_memory_quantity


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("1", 1.0),
        ("250m", 0.25),
        ("500u", 0.0005),
        ("100000000n", 0.1),
        ("1.5", 1.5),
    ],
)
def test_parse_cpu_quantity(value, expected):
    assert parse_cpu_quantity(value) == pytest.approx(expected)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("1024", 1024),
        ("1Ki", 1024),
        ("2Mi", 2 * 1024 * 1024),
        ("1Gi", 1024**3),
        ("1Ti", 1024**4),
        ("1K", 1000),
        ("2M", 2_000_000),
        ("1.5G", 1_500_000_000),
    ],
)
def test_parse_memory_quantity(value, expected):
    assert parse_memory_quantity(value) == pytest.approx(expected)


def test_parse_invalid_cpu_quantity():
    with pytest.raises(ValueError):
        parse_cpu_quantity("10Mi")


def test_parse_invalid_memory_quantity():
    with pytest.raises(ValueError):
        parse_memory_quantity("abc")
