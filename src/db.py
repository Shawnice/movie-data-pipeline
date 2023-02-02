"""DB-related configuration."""


CREATE_TABLE = """
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

INSERT_ROW = """
INSERT INTO imdb (rank_, name, year, genre, director, rating, actors)
VALUES (%s, %s, %s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  id = id ;
"""
