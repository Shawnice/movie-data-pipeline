"""Fixtures for `src`."""

# Third-party
import pytest


@pytest.fixture()
def s3_event() -> dict[str, object]:
    """Return a sample S3 event."""
    return {
        "Records": [
            {
                "eventVersion": "2.0",
                "eventSource": "aws:s3",
                "awsRegion": "us-east-1",
                "eventTime": "1970-01-01T00:00:00.123Z",
                "eventName": "ObjectCreated:Put",
                "s3": {
                    "s3SchemaVersion": "1.0",
                    "bucket": {
                        "name": "movie-source-data-bucket",
                        "arn": "arn:aws:s3:::movie-source-data-bucket",
                    },
                    "object": {
                        "key": "imdb_data.json",
                    },
                },
            }
        ]
    }
