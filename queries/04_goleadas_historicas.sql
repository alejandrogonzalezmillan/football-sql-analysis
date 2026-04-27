-- ============================================================
-- Query 04 — Goleadas históricas (diferencia ≥ 5 goles)
-- ============================================================
-- Propósito
--   Identificar los partidos más desiguales del dataset: las
--   "vendettas" con diferencia ≥ 5 goles. Combina análisis
--   cuantitativo con narrativa (qué equipos aparecen más
--   veces como verdugos y cuáles como víctimas).
--
-- Dos entregables en una sola query
--   Resultado 1: Top 15 mayores goleadas de la historia del
--                dataset con contexto (fecha, liga, temporada,
--                jornada).
--   Resultado 2: se deja como query de consulta alternativa al
--                final, comentada — útil para entrenar a quien
--                lea el código.
--
-- Técnicas SQL demostradas
--   * Expresión derivada en SELECT y ORDER BY (ABS)
--   * CASE WHEN complejo para construir narrativa textual
--   * Concatenación con || para montar frases descriptivas
--   * Auto-join triple sobre team (local + visitante + mismo
--     match) con alias distintos
-- ============================================================

SELECT
    m.date::date                                                       AS fecha,
    l.name                                                             AS liga,
    m.season                                                           AS temporada,
    m.stage                                                            AS jornada,
    CASE
        WHEN m.home_team_goal > m.away_team_goal
            THEN home.team_long_name || ' ' || m.home_team_goal || '-' || m.away_team_goal || ' ' || away.team_long_name
        ELSE home.team_long_name || ' ' || m.home_team_goal || '-' || m.away_team_goal || ' ' || away.team_long_name
    END                                                                AS marcador,
    CASE
        WHEN m.home_team_goal > m.away_team_goal THEN home.team_long_name
        ELSE away.team_long_name
    END                                                                AS ganador,
    CASE
        WHEN m.home_team_goal > m.away_team_goal THEN away.team_long_name
        ELSE home.team_long_name
    END                                                                AS perdedor,
    ABS(m.home_team_goal - m.away_team_goal)                           AS diferencia,
    m.home_team_goal + m.away_team_goal                                AS goles_totales
FROM match m
JOIN team   home ON home.team_api_id = m.home_team_api_id
JOIN team   away ON away.team_api_id = m.away_team_api_id
JOIN league l    ON l.id             = m.league_id
WHERE ABS(m.home_team_goal - m.away_team_goal) >= 5
ORDER BY diferencia DESC, goles_totales DESC
LIMIT 15;


-- ============================================================
-- QUERY ALTERNATIVA (descomentar para ejecutar)
-- ============================================================
-- Ranking de equipos que MÁS goleadas RECIBIERON (≥ 4 goles
-- de diferencia). Las humillaciones más repetidas de Europa.
-- ============================================================
/*
WITH goleadas AS (
    SELECT
        CASE
            WHEN home_team_goal > away_team_goal THEN away_team_api_id
            ELSE home_team_api_id
        END AS victima_api_id
    FROM match
    WHERE ABS(home_team_goal - away_team_goal) >= 4
)
SELECT
    t.team_long_name                         AS victima,
    l.name                                   AS liga,
    COUNT(*)                                 AS veces_humillado
FROM goleadas g
JOIN team   t ON t.team_api_id = g.victima_api_id
JOIN match  m ON m.home_team_api_id = g.victima_api_id OR m.away_team_api_id = g.victima_api_id
JOIN league l ON l.id = m.league_id
GROUP BY t.team_long_name, l.name
ORDER BY veces_humillado DESC
LIMIT 10;
*/