"""Module for processing `IMDB` data."""

# Standard library
import logging
import pymysql

# Third-party
import pandas as pd
import json
import boto3
from botocore.exceptions import ClientError
import urllib
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

create_table = """
CREATE TABLE IF NOT EXISTS imdb (
    id                  int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name                varchar(255),
    rank_               int,
    year                int,
    genre               JSON,
    director            varchar(120),
    rating              float(4,2),
    actors              JSON,
    CONSTRAINT Unique_Movie UNIQUE(name, year, director)
);"""

insert_row = """
INSERT INTO imdb (rank_, name, year, genre, director, rating, actors)
VALUES (%s, %s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  id = id ;
"""


def get_secret(
    secret_name: str, region_name: str = "us-east-1"
) -> dict[str, str]:
    session = boto3.session.Session()
    client = session.client(
        service_name="secretsmanager", region_name=region_name
    )
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e
    return json.loads(get_secret_value_response["SecretString"])


IS_PRODUCTION = os.environ.get("IsProduction") == "true"
DB_HOST = os.environ["DBHost"] if IS_PRODUCTION else "docker.for.mac.localhost"
DB_NAME = os.environ["DBName"] if IS_PRODUCTION else "mysql"
DB_USER = os.environ["DBUser"] if IS_PRODUCTION else "root"
DB_PASSWORD = get_secret() if IS_PRODUCTION else ""

s3 = boto3.client("s3")


def get_imdb_data(event: dict[str, object]) -> object:
    """Get `IMDB` data from S3 bucket."""
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(
        event["Records"][0]["s3"]["object"]["key"], encoding="utf-8"
    )
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        return response["Body"].read().decode("utf-8")
    except Exception as err:
        logger.error(
            "Can not fetch object {} from bucket {}. Error: {}".format(
                key, bucket, err
            )
        )
        raise err


def get_mysql_conn():
    """."""
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        database=DB_NAME,
        passwd=DB_PASSWORD,
        port=3306,
    )


def lambda_handler(
    event: dict[str, object], context: dict[str, object]
) -> dict[str, object]:
    """Lambda function for loading `IMDB` data into database."""
    imdb_data = get_imdb_data(event)
    df = pd.read_json(imdb_data, lines=True)
    df.rename(columns={"rank": "rank_"}, inplace=True)

    conn = get_mysql_conn()
    cursor = conn.cursor()
    cursor.execute(create_table)

    for _, row in df.iterrows():
        insert_data = row.tolist()
        insert_data[3] = json.dumps(insert_data[3])
        insert_data[6] = json.dumps(insert_data[6])
        logger.info(insert_data)
        try:
            cursor.execute(insert_row, insert_data)
        except Exception as err:
            logger.exception(err)

    conn.commit()
    conn.close()
    return {"result": "Records inserted"}
