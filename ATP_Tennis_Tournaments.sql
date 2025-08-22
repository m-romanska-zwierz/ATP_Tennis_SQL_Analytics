USE atp_tennis;

-- 1. Number of Players by Tournaments

wITH players_list AS
		((SELECT
			t.tournament_name,
            YEAR(m.date) AS season,
            m.player1_id AS player_id
		FROM
			tournaments t
				JOIN
			matches m ON t.tournament_id = m.tournament_id)
				UNION
		(SELECT
			t.tournament_name,
			YEAR(m.date) AS season,
            m.player2_id
		FROM
			tournaments t
				JOIN
			matches m ON t.tournament_id = m.tournament_id))
SELECT
    tournament_name,
    season,
    COUNT(DISTINCT player_id) players_count
FROM
	players_list
GROUP BY tournament_name, season
ORDER BY tournament_name, season;

-- 2. Upset vs. Favourite Wins by Tournament

WITH tournament_totals AS
		(SELECT
			t.tournament_name AS tournament_name,
			COUNT(m.match_id) AS total_matches
		FROM tournaments t
				JOIN
			matches m ON m.tournament_id = t.tournament_id
		GROUP BY t.tournament_name)
SELECT
	t.tournament_name,
    CASE
		WHEN (m.rank_1 > m.rank_2 AND m.player1_id = m.winner_id)
			OR (m.rank_2 > m.rank_1 AND m.player2_id = m.winner_id)
		THEN 'underdog_win'
        ELSE 'favorite_win'
	END AS winner_type,
    COUNT(m.match_id) AS matches_count,
    ROUND(COUNT(m.match_id)/tt.total_matches, 2) AS winner_type_rate
FROM
	tournaments t
		JOIN
	matches m ON m.tournament_id = t.tournament_id
		JOIN
	tournament_totals tt ON tt.tournament_name = t.tournament_name
GROUP BY tournament_name, winner_type
ORDER BY tournament_name, winner_type;

-- 3. Tournaments with The Highest Rate of Upsets

WITH tournament_totals AS
		(SELECT
			t.tournament_name AS tournament_name,
            COUNT(m.match_id) AS total_matches
		FROM
			tournaments t
				JOIN
			matches m ON m.tournament_id = t.tournament_id
		GROUP BY tournament_name)
SELECT
	t.tournament_name,
    CASE
		WHEN (m.rank_1 > m.rank_2 AND m.player1_id = m.winner_id)
			OR (m.rank_2 > m.rank_1 AND m.player2_id = m.winner_id)
		THEN 'underdog_won'
        ELSE 'favorite_won'
	END AS winner_type,
    COUNT(m.match_id) AS upset_count,
    ROUND(COUNT(m.match_id) / tt.total_matches, 2) AS upset_rate,
    RANK() OVER (ORDER BY COUNT(m.match_id) / tt.total_matches DESC) AS upset_rank
FROM
	tournaments t
		JOIN
	matches m ON m.tournament_id = t.tournament_id
		JOIN
	tournament_totals tt ON tt.tournament_name = t.tournament_name
GROUP BY tournament_name, winner_type
HAVING winner_type = 'underdog_won'
ORDER BY upset_rate DESC
LIMIT 20;

-- 4. Number of Tournaments by Surface

SELECT
	COUNT(tournament_name) AS tournaments_count,
    surface
FROM
	tournaments
GROUP BY surface;

-- 5. Number of Tournaments by Court Type

SELECT
	COUNT(tournament_name) AS tournaments_count,
    court_type
FROM
	tournaments
GROUP BY court_type;

-- 6. Number of Tournaments by Court Type and Surface

SELECT
	COUNT(tournament_name) AS tournaments_count,
	court_type,
    surface
FROM
	tournaments
GROUP BY court_type, surface
ORDER BY court_type;

-- 7. Number of Tournaments by Series

SELECT
	COUNT(tournament_id) AS tournaments_count,
    series
FROM
	tournaments
GROUP BY series
ORDER BY tournaments_count DESC;

-- 8. Grand Slam Tournaments

SELECT tournament_name
FROM tournaments
WHERE series = 'Grand Slam';

-- 9. Tournaments with Best-of-Five Matches

SELECT DISTINCT t.tournament_name
FROM
	tournaments t
		JOIN
	matches m ON m.tournament_id = t.tournament_id
WHERE m.best_of = 5;
