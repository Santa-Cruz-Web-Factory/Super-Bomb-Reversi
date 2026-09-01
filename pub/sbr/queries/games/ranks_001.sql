WITH PlayerOldestMove AS (
    SELECT 
        CASE WHEN turn = 'challenger' THEN challenger_id ELSE accepter_id END AS player_id,
        MIN(time_last_moved) AS oldest_game_move
    FROM games
    WHERE status = 'everythings_normal'
      AND (
          (turn = '_challenger_' AND challenger_id IS NOT NULL) OR 
          (turn = '_accepter_' AND accepter_id IS NOT NULL)
      )
    GROUP BY player_id
),
PreparedPlayers AS (
    SELECT 
        p.player_id,
        p.score,
        COALESCE(pom.oldest_game_move, p.moved_last) AS effective_move_time
    FROM players p
    LEFT JOIN PlayerOldestMove pom ON p.player_id = pom.player_id
),
RankedLeaderboard AS (
    SELECT 
        player_id,
        score,
        effective_move_time,
        DENSE_RANK() OVER (
            ORDER BY 
                CASE 
                    WHEN effective_move_time >= NOW() - INTERVAL 10 MINUTE THEN 0
                    WHEN effective_move_time >= NOW() - INTERVAL 60 MINUTE THEN 1
                    WHEN effective_move_time >= NOW() - INTERVAL 6 HOUR   THEN 2
                    WHEN effective_move_time >= NOW() - INTERVAL 24 HOUR  THEN 3
                    WHEN effective_move_time >= NOW() - INTERVAL 72 HOUR  THEN 4
                    WHEN effective_move_time >= NOW() - INTERVAL 10 DAY   THEN 5
                    WHEN effective_move_time >= NOW() - INTERVAL 30 DAY   THEN 6
                    WHEN effective_move_time >= NOW() - INTERVAL 365 DAY  THEN 7
                    ELSE 8 
                END ASC,
                score DESC
        ) AS leaderboard_rank
    FROM PreparedPlayers
)
SELECT * 
FROM RankedLeaderboard
LIMIT :numPlayers      -- How many records to return (e.g., :numPlayers players)
OFFSET :skipPast    -- How many records to skip from the top (e.g., starts at row :skipPast + 1)
