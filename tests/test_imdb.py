import pytest

import src.main
from moto import mock_s3
import mock


@mock_s3
def test_get_imdb_data(s3_event: dict[str, object]) -> None:
    """Assert retrieve body data correctly."""
    result = src.main.get_imdb_data(s3_event)
    assert result is not None


def test_get_imdb_data__error(s3_event: dict[str]) -> None:
    """Assert error raised on no object exists."""
    with mock.patch.object(src.main.s3, "get_object") as mocked_get_object:
        mocked_get_object.side_effect = Exception()
        with pytest.raises(Exception):
            src.main.get_imdb_data(s3_event)


@mock_s3
def test_lambda_handler(s3_event: dict[str, object]):
    with mock.patch("pymysql.connect"):
        resp = src.main.lambda_handler(event=s3_event, context={})
        assert resp == {"result": "Records inserted"}
