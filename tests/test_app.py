# Third-party
import mock
import pytest
from moto import mock_s3  # type: ignore

# First-party
import src.app


@mock_s3
def test_get_imdb_data(s3_event: src.app.S3Event) -> None:
    """Assert retrieve body data correctly."""
    result = src.app.get_imdb_data(s3_event)
    assert result is not None


def test_get_imdb_data__error(s3_event: src.app.S3Event) -> None:
    """Assert error raised on no object exists."""
    with mock.patch.object(src.app.s3, "get_object") as mocked_get_object:
        mocked_get_object.side_effect = Exception()
        with pytest.raises(Exception):
            src.app.get_imdb_data(s3_event)


@mock_s3
def test_lambda_imdb(s3_event: src.app.S3Event):
    with mock.patch("pymysql.connect"):
        resp = src.app.lambda_imdb(event=s3_event, context={})
        assert resp == {"result": "Records inserted"}
