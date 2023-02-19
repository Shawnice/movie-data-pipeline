"""Test suite for `src.app`."""

# Standard library
import unittest.mock

# Third-party
import pytest
from botocore.exceptions import ClientError

# First-party
import src.app


def test_get_imdb_data(s3_event: src.app.S3Event) -> None:
    """Assert retrieve body data correctly."""
    result = src.app.get_imdb_data(s3_event)
    assert result is not None


def test_get_imdb_data__error(s3_event: src.app.S3Event) -> None:
    """Assert error raised on no object exists."""
    with unittest.mock.patch.object(
        src.app.s3, "get_object"
    ) as mocked_get_object:
        mocked_get_object.side_effect = Exception()
        with pytest.raises(ClientError):
            src.app.get_imdb_data(s3_event)


def test_lambda_imdb(s3_event: src.app.S3Event) -> None:
    """Assert lambda function return correct response."""
    with unittest.mock.patch("pymysql.connect"):
        resp = src.app.lambda_imdb(event=s3_event, context={})
        assert resp == {"result": "Records inserted"}
