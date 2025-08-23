CREATE DATABASE atp_tennis;
USE atp_tennis;

DROP TABLE IF EXISTS matches;
DROP TABLE IF EXISTS tournaments;
DROP TABLE IF EXISTS players;

-- Creating table players

CREATE TABLE players (
	player_id INT PRIMARY KEY AUTO_INCREMENT,
    player_name VARCHAR(100) NOT NULL
    )
AUTO_INCREMENT = 10001;

-- Creating table tournaments

CREATE TABLE tournaments (
    tournament_id INT PRIMARY KEY AUTO_INCREMENT,
    tournament_name VARCHAR(255) NOT NULL,
    series VARCHAR(50),
    court_type VARCHAR(50),
    surface VARCHAR(50)
	)
AUTO_INCREMENT = 1001;

-- Creating table matches

CREATE TABLE matches (
    match_id INT PRIMARY KEY AUTO_INCREMENT,
    tournament_id INT,
    date DATE,
    round VARCHAR(50),
    best_of INT,
    player1_id INT,
    player2_id INT,
    winner_id INT,
    rank_1 INT,
    rank_2 INT,
    pts_1 INT,
    pts_2 INT,
    odd_1 FLOAT,
    odd_2 FLOAT,
    score VARCHAR(50),
    FOREIGN KEY (tournament_id) REFERENCES tournaments(tournament_id),
    FOREIGN KEY (player1_id) REFERENCES players(player_id),
    FOREIGN KEY (player2_id) REFERENCES players(player_id),
    FOREIGN KEY (winner_id) REFERENCES players(player_id)
	)
AUTO_INCREMENT = 10001;

-- Creating a temporary table to add files

DROP TABLE IF EXISTS raw_tennis;

CREATE TABLE raw_tennis (
    Tournament VARCHAR(255),
    Date DATE,
    Series VARCHAR(50),
    Court VARCHAR(50),
    Surface VARCHAR(50),
    Round VARCHAR(50),
    Best_of INT,
    Player_1 VARCHAR(100),
    Player_2 VARCHAR(100),
    Winner VARCHAR(100),
    Rank_1 INT,
    Rank_2 INT,
    Pts_1 INT,
    Pts_2 INT,
    Odd_1 FLOAT,
    Odd_2 FLOAT,
    Score VARCHAR(50)
	);

-- Importing data into temporary table

LOAD DATA LOCAL INFILE '/Users/malgorzataromanska/Documents/Projekty/ATP_Tennis/atp_tennis.csv'
INTO TABLE raw_tennis
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Tournament, Date, Series, Court, Surface, Round, Best_of, Player_1, Player_2, Winner, Rank_1, Rank_2, Pts_1, Pts_2, Odd_1, Odd_2, Score);

-- Changing -1 to NULL

SET SQL_SAFE_UPDATES = 0;

UPDATE raw_tennis
SET Rank_1 = NULL WHERE Rank_1 = -1;

UPDATE raw_tennis
SET Rank_2 = NULL WHERE Rank_2 = -1;

UPDATE raw_tennis
SET Pts_1 = NULL WHERE Pts_1 = -1;

UPDATE raw_tennis
SET Pts_2 = NULL WHERE Pts_2 = -1;

UPDATE raw_tennis
SET Odd_1 = NULL WHERE Odd_1 = -1;

UPDATE raw_tennis
SET Odd_2 = NULL WHERE Odd_2 = -1;

SET SQL_SAFE_UPDATES = 1;

-- Filling table players

INSERT INTO players (player_name)
SELECT DISTINCT Player_1 FROM raw_tennis
			UNION
SELECT DISTINCT Player_2 FROM raw_tennis;

-- Filling table tournaments

INSERT INTO tournaments (tournament_name, series, court_type, surface)
SELECT DISTINCT Tournament, Series, Court, Surface
FROM raw_tennis;

-- Filling table matches

INSERT INTO matches (tournament_id, date, round, best_of, player1_id, player2_id, winner_id, rank_1, rank_2, pts_1, pts_2, odd_1, odd_2, score)
SELECT 
    t.tournament_id,
    r.Date,
    r.Round,
    r.Best_of,
    p1.player_id,
    p2.player_id,
    pw.player_id,
    r.Rank_1,
    r.Rank_2,
    r.Pts_1,
    r.Pts_2,
    r.Odd_1,
    r.Odd_2,
    r.Score
FROM raw_tennis r
		JOIN tournaments t ON r.Tournament = t.tournament_name
								AND r.Series = t.series
								AND r.Court = t.court_type
								AND r.Surface = t.surface
		JOIN players p1 ON r.Player_1 = p1.player_name
		JOIN players p2 ON r.Player_2 = p2.player_name
		JOIN players pw ON r.Winner = pw.player_name;

