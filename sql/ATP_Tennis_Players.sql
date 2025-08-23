USE atp_tennis;

-- 1. Number of Matches Played by Player

WITH players_by_matches AS
	((SELECT player1_id AS player_id FROM matches)
				UNION ALL
	(SELECT player2_id FROM matches))
SELECT
	pm.player_id,
    p.player_name,
    COUNT(pm.player_id) AS matches_played
FROM
	players_by_matches pm
		JOIN
	players p ON p.player_id = pm.player_id
GROUP BY pm.player_id
ORDER BY p.player_name;

-- 2. Number of Matches Won by Player

SELECT
    m.winner_id,
    p.player_name,
    COUNT(m.match_id) AS matches_won
FROM
	matches m
		JOIN	
	players p ON m.winner_id = p.player_id
GROUP BY m.winner_id, p.player_name
ORDER BY matches_won DESC;

-- 3. Top 10 Players per Year by Finals Won

WITH players_stats AS
	(SELECT winner_id,
			COUNT(match_id) AS finals_won,
            YEAR(date) AS season,
            RANK() OVER window_players AS season_rank
	FROM
		matches
	WHERE round = 'The Final'
	GROUP BY winner_id, season
	WINDOW window_players AS (PARTITION BY YEAR(date) ORDER BY COUNT(match_id) DESC))
SELECT
	*
FROM
	players_stats
WHERE season_rank <= 10
ORDER BY season, season_rank;

-- 4. Players with Most First-Round Losses

WITH players_list AS
	((SELECT match_id, player1_id AS player_id FROM matches)
				UNION ALL
	(SELECT match_id, player2_id FROM matches))
SELECT
	pl.player_id,
    p.player_name,
	COUNT(m.match_id) AS first_round_losses
FROM
	matches m
		JOIN
	players_list pl ON m.match_id = pl.match_id
		JOIN
	players p ON p.player_id = pl.player_id
WHERE m.round = '1st Round'
		AND pl.player_id != m.winner_id
GROUP BY pl.player_id, p.player_name
ORDER BY first_round_losses DESC;

-- 5. Unique Players Achieving Rank 1 by Season

SELECT
	DISTINCT p.player_id,
    p.player_name,
    YEAR(m.date) AS season
FROM
	players p
		JOIN
	matches m ON p.player_id = m.player1_id OR p.player_id = m.player2_id
WHERE
	rank_1 = 1 OR rank_2 = 1
ORDER BY season;

-- 6. Count of Players with Rank 1 by Season

SELECT
	COUNT(DISTINCT p.player_id) top_players_count,
    YEAR(m.date) AS season
FROM
	players p
		JOIN
	matches m ON p.player_id = m.player1_id OR p.player_id = m.player2_id
WHERE
	rank_1 = 1 OR rank_2 = 1
GROUP BY season
ORDER BY season;

-- 7. Upsets with the Largest Ranking Gaps (Loser Ranked Higher by 1000+ Points)

SELECT 
    a.match_id,
	a.player1_id,
	a.player2_id,
	a.winner_id,
	a.rank_1,
	a.rank_2,
    a.is_upset,
    ABS(rank_1 - rank_2) AS ranking_difference,
    p1.player_name AS p1_name,
    p2.player_name AS p2_name,
    w.player_name AS winner_name
FROM
    (SELECT 
        match_id,
		player1_id,
		player2_id,
		winner_id,
		rank_1,
		rank_2,
		CASE
			WHEN
				(player1_id = winner_id AND rank_1 > rank_2) OR (player2_id = winner_id AND rank_2 > rank_1)
                THEN 1
                ELSE 0
            END AS is_upset
    FROM
        matches) a
        JOIN
	players p1 ON p1.player_id = a.player1_id
		JOIN
	players p2 ON p2.player_id = a.player2_id
		JOIN
	players w ON w.player_id = a.winner_id
WHERE
    a.is_upset = 1
        AND ABS(rank_1 - rank_2) > 1000
ORDER BY ranking_difference DESC;

-- 8. Matches Won by Underdog (Based on Betting Odds)

SELECT
	m.match_id,
    p1.player_name AS player1_name,
    p2.player_name AS player2_name,
    p3.player_name AS winner_name,
    ROUND(m.odd_1, 2) AS odd_1,
    ROUND(m.odd_2, 2) AS odd_2,
    ROUND(ABS(m.odd_1 - m.odd_2), 2) AS odds_difference,
    CASE
		WHEN (m.odd_1 > m.odd_2 AND m.winner_id = m.player1_id)
			OR (m.odd_2 > m.odd_1 AND m.winner_id = m.player2_id)
			THEN 'underdog_win'
        WHEN (m.odd_1 > m.odd_2 AND m.winner_id = m.player2_id)
			OR (m.odd_2 > m.odd_1 AND m.winner_id = m.player1_id)
			THEN 'favourite_win'
        ELSE NULL
	END AS betting_outcome
FROM
	matches m
		JOIN
	players p1 ON p1.player_id = m.player1_id
		JOIN
	players p2 ON p2.player_id = m.player2_id
		JOIN
	players p3 on p3.player_id = m.winner_id
HAVING betting_outcome = 'underdog_win'
ORDER BY odds_difference DESC;

-- 9. Players With Most Underdog Wins (Based on Betting Odds)

SELECT COUNT(a.match_id) AS total_underdog_wins, a.winner_name
FROM
	(SELECT
		m.match_id,
		p1.player_name AS player1_name,
		p2.player_name AS player2_name,
		p3.player_name AS winner_name,
		ROUND(m.odd_1, 2) AS odd_1,
		ROUND(m.odd_2, 2) AS odd_2,
		ROUND(ABS(m.odd_1 - m.odd_2), 2) AS odds_difference,
		CASE
			WHEN (m.odd_1 > m.odd_2 AND m.winner_id = m.player1_id)
				OR (m.odd_2 > m.odd_1 AND m.winner_id = m.player2_id)
				THEN 'underdog_win'
			WHEN (m.odd_1 > m.odd_2 AND m.winner_id = m.player2_id)
				OR (m.odd_2 > m.odd_1 AND m.winner_id = m.player1_id)
				THEN 'favourite_win'
			ELSE NULL
		END AS betting_outcome
	FROM
		matches m
		JOIN
	players p1 ON p1.player_id = m.player1_id
		JOIN
	players p2 ON p2.player_id = m.player2_id
		JOIN
	players p3 on p3.player_id = m.winner_id
HAVING betting_outcome = 'underdog_win') a
GROUP BY a.winner_name
ORDER BY total_underdog_wins DESC;

-- 10. Favourite vs Underdog Win Rate

WITH

	winner_type_summary AS
		(SELECT
			COUNT(match_id) AS outcome_match_count,
			CASE
				WHEN (rank_1 > rank_2 AND player1_id = winner_id)
					OR (rank_2 > rank_1 AND player2_id = winner_id)
				THEN 'underdog_won'
				WHEN (rank_1 < rank_2 AND player1_id = winner_id)
					OR (rank_2 < rank_1 AND player2_id = winner_id)
				THEN 'favorite_won'
				ELSE NULL
			END AS winner_type
		FROM
			matches
		GROUP BY winner_type
		HAVING winner_type IS NOT NULL),
        
	total_ranked_matches AS
		(SELECT
			COUNT(match_id) AS total_ranked_matches
		FROM
			matches
		WHERE rank_1 AND rank_2 IS NOT NULL
				AND rank_1 != rank_2)
                
SELECT
    w.winner_type,
    w.outcome_match_count,
    w.outcome_match_count/t.total_ranked_matches AS outcome_ratio
FROM
	winner_type_summary w
		JOIN
	total_ranked_matches t;

-- 11. Top Player Matchups

SELECT
    CONCAT(LEAST(p1.player_name, p2.player_name),' vs ',GREATEST(p1.player_name, p2.player_name)) AS players_pair,
    COUNT(m.match_id) AS matches_count
FROM
	matches m
		JOIN
	players p1 ON p1.player_id = m.player1_id
		JOIN
	players p2 ON p2.player_id = m.player2_id
GROUP BY players_pair
ORDER BY matches_count DESC;

-- 12. Top Player Matchups in Finals

SELECT
	CONCAT(LEAST(p1.player_name, p2.player_name),' vs ',GREATEST(p1.player_name, p2.player_name)) AS players_pair,
	COUNT(*) AS matches_count
FROM
	matches m
		JOIN
	players p1 ON m.player1_id = p1.player_id
		JOIN
	players p2 ON m.player2_id = p2.player_id
WHERE m.round = 'The Final'
GROUP BY players_pair
ORDER BY matches_count DESC;

-- 13. Number of Tournaments Won by Player

SELECT
    m.winner_id,
    p.player_name,
	COUNT(m.round) tournaments_won
FROM
	matches m
		JOIN
	players p ON m.winner_id = p.player_id
WHERE m.round = 'The Final'
GROUP BY m.winner_id, p.player_name
ORDER BY tournaments_won DESC;

-- 14. Number of Grand Slam Won by Player

SELECT
    m.winner_id,
    p.player_name,
	COUNT(m.round) grand_slam_titles
FROM
	matches m
		JOIN
	players p ON m.winner_id = p.player_id
		JOIN
	tournaments t ON t.tournament_id = m.tournament_id
WHERE m.round = 'The Final' AND t.series = 'Grand Slam'
GROUP BY m.winner_id, p.player_name
ORDER BY grand_slam_titles DESC;

-- 15. Number of Matches Won by a Player by Tournament Surface

SELECT
	m.winner_id,
    p.player_name,
    COUNT(m.winner_id) AS matches_won,
    t.surface
FROM
	matches m
		JOIN
	players p ON p.player_id = m.winner_id
		JOIN
	tournaments t ON t.tournament_id = m.tournament_id
GROUP BY m.winner_id, t.surface
ORDER BY surface, matches_won DESC;

-- 16. Number od Matches Won by a Player by Season

SELECT
	m.winner_id,
    p.player_name,
    YEAR(m.date) AS season,
    COUNT(m.match_id) AS matches_count
FROM
	matches m
		JOIN
	players p ON p.player_id = m.winner_id
GROUP BY m.winner_id, season
ORDER BY m.winner_id, season;

-- 17. Win Rate by All Players

WITH players_by_matches AS
	((SELECT player1_id AS player_id FROM matches)
				UNION ALL
	(SELECT player2_id FROM matches)),
player_wins AS
	(SELECT winner_id, COUNT(winner_id) AS matches_won
	FROM matches
	GROUP BY winner_id)
SELECT
	pm.player_id,
    COUNT(pm.player_id) AS matches_played,
    COALESCE(w.matches_won, 0) AS matches_won,
    ROUND(COALESCE(w.matches_won, 0) / COUNT(pm.player_id), 2) AS win_rate
FROM
	players_by_matches pm
		LEFT JOIN
	player_wins w ON pm.player_id = w.winner_id
GROUP BY pm.player_id, matches_won
ORDER BY pm.player_id;

-- 18. Win Rate by All Players vs Surface

WITH players_by_matches AS
		((SELECT m.player1_id AS player_id, t.surface AS surface
		FROM matches m
				JOIN
			tournaments t ON t.tournament_id = m.tournament_id)
				UNION ALL
		(SELECT m.player2_id, t.surface
		FROM matches m
				JOIN
			tournaments t ON t.tournament_id = m.tournament_id)),
player_wins AS
		(SELECT
			winner_id,
            COUNT(winner_id) AS matches_won,
            t.surface AS surface
		FROM
			matches m
				JOIN
			tournaments t ON t.tournament_id = m.tournament_id
		GROUP BY winner_id, t.surface)
SELECT
	pm.player_id,
    COUNT(pm.player_id) AS matches_played,
    COALESCE(w.matches_won, 0) AS matches_won,
    w.surface,
    ROUND(COALESCE(w.matches_won) / COUNT(pm.player_id), 2) AS win_rate
FROM
	players_by_matches pm
		LEFT JOIN
	player_wins w ON pm.player_id = w.winner_id AND pm.surface = w.surface
GROUP BY pm.player_id, matches_won, w.surface
ORDER BY pm.player_id;

-- 19. Win Rate by Only Winning Players

WITH players_by_matches AS
		((SELECT player1_id AS player FROM matches)
						UNION ALL
		(SELECT player2_id FROM matches))
SELECT
	a.player,
    a.matches_played,
    b.matches_won,
    ROUND((b.matches_won / a.matches_played), 2) AS win_rate
FROM
	(SELECT
		player,
        COUNT(player) AS matches_played
	FROM
		players_by_matches
	GROUP BY player) a
			JOIN
	(SELECT
		winner_id,
        COUNT(winner_id) AS matches_won
	FROM
		matches
	GROUP BY winner_id) b ON a.player = b.winner_id;

-- 20. Players Performance by Tournament

WITH players_by_matches AS
			((SELECT
				m.player1_id AS player_id,
                t.tournament_name AS tournament_name
			FROM
				matches m
					JOIN
				tournaments t ON m.tournament_id = t.tournament_id)
					UNION ALL
			(SELECT
				m.player2_id,
                t.tournament_name
			FROM
				matches m
					JOIN
				tournaments t ON m.tournament_id = t.tournament_id)),
	player_wins AS
			(SELECT
				m.winner_id,
                COUNT(m.winner_id) AS matches_won,
                t.tournament_name AS tournament_name
			FROM matches m
					JOIN
				tournaments t ON m.tournament_id = t.tournament_id
			GROUP BY winner_id, tournament_name)
SELECT
	pm.player_id,
    p.player_name,
    pm.tournament_name,
    COUNT(pm.player_id) AS matches_played,
    COALESCE(w.matches_won, 0) AS matches_won
FROM
	players_by_matches pm
		LEFT JOIN
	player_wins w ON pm.player_id = w.winner_id AND pm.tournament_name = w.tournament_name
		JOIN
	players p ON p.player_id = pm.player_id
GROUP BY pm.player_id, pm.tournament_name
ORDER BY pm.player_id;

-- 21. Top Players by Tournament Titles

SELECT *
FROM 
	(SELECT 
			m.winner_id,
            p.player_name,
			t.tournament_name AS tournament_name,
			COUNT(m.winner_id) matches_won,
            ROW_NUMBER() OVER window_tournaments AS ranking
	FROM
		matches m
			JOIN
		tournaments t ON m.tournament_id = t.tournament_id
			JOIN
		players p ON p.player_id = m.winner_id
	WHERE m.round = 'The Final'
	GROUP BY p.player_name, m.winner_id, t.tournament_name
	WINDOW window_tournaments AS (PARTITION BY t.tournament_name ORDER BY COUNT(m.winner_id) DESC)) r
WHERE r.ranking <= 3
ORDER BY r.tournament_name, ranking;

-- 22. Top Players by Grand Slam Tournament

SELECT *
FROM 
	(SELECT 
			m.winner_id,
			p.player_name,
			t.tournament_name AS tournament_name,
			COUNT(m.winner_id) tournaments_won,
            ROW_NUMBER() OVER window_tournaments AS tournament_rank
	FROM
		matches m
			JOIN
		tournaments t ON m.tournament_id = t.tournament_id
			JOIN
		players p ON p.player_id = m.winner_id
	WHERE m.round = 'The Final' AND t.series = 'Grand Slam'
	GROUP BY p.player_name, m.winner_id, t.tournament_name
	WINDOW window_tournaments AS (PARTITION BY t.tournament_name ORDER BY COUNT(m.winner_id) DESC)) r
WHERE r.tournament_rank <= 3
ORDER BY r.tournament_name, tournament_rank;

-- 23. Most Frequent Matchups (by Player ID)

SELECT
	CONCAT(LEAST(player1_id, player2_id),' vs ',GREATEST(player1_id, player2_id)) AS opponents,
    COUNT(match_id) AS matches_count
FROM matches
GROUP BY opponents
ORDER BY matches_count DESC;

-- 24. Most Frequent Matchups (by Player Name)

WITH opponents_names AS
		(SELECT
			a.match_id AS match_id,
            a.player1_id AS player1_id,
            a.player1_name AS player1_name,
            b.player2_id AS player2_id,
			b.player2_name AS player2_name
        FROM
			(SELECT
				m.match_id AS match_id,
                m.player1_id AS player1_id,
                p.player_name AS player1_name
            FROM
				matches m
					JOIN
				players p ON m.player1_id = p.player_id) a
					JOIN
			(SELECT
				m.match_id AS match_id,
                m.player2_id AS player2_id,
                p.player_name AS player2_name
			FROM
				matches m
					JOIN
				players p ON m.player2_id = p.player_id) b ON a.match_id = b.match_id)
SELECT
	CONCAT(LEAST(player1_id, player2_id),' vs ',GREATEST(player1_id, player2_id)) AS opponents_id,
	CONCAT(LEAST(player1_name, player2_name),' vs ',GREATEST(player1_name, player2_name)) AS opponents_names,
    COUNT(match_id) AS matches_count
FROM opponents_names
GROUP BY opponents_names, opponents_id
ORDER BY matches_count DESC;

-- 25. Matches with 6-0 6-0 Score

WITH match_opponents AS
	(SELECT
		a.match_id,
        a.player1_id,
        a.player1_name AS player1_name,
        b.player2_id,
        b.player2_name AS player2_name
    FROM 
		(SELECT
			m.match_id AS match_id, m.player1_id AS player1_id, p.player_name AS player1_name
        FROM
			matches m
				JOIN
			players p ON m.player1_id = p.player_id) a
				JOIN
		(SELECT
			m.match_id AS match_id, m.player2_id AS player2_id, p.player_name AS player2_name
		FROM
			matches m
				JOIN
			players p ON m.player2_id = p.player_id) b ON a.match_id = b.match_id)
SELECT
	o.match_id,
    CASE
		WHEN m.score = '6-0 6-0' THEN CONCAT(player1_name,' vs ',player2_name)
		ELSE CONCAT(player2_name,' vs ',player1_name) END AS opponents,
    CASE
		WHEN m.score = '0-6 0-6' THEN '6-0 6-0'
        ELSE m.score END AS score
FROM
	match_opponents o
		JOIN
	matches m ON o.match_id = m.match_id
WHERE score = '6-0 6-0' OR score = '0-6 0-6';