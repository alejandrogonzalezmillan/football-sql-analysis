-- ============================================================
-- Query 06 — Factor espectáculo: equipos con partidos más abiertos
-- ============================================================
-- Propósito
--   Medir el "factor espectáculo" de cada equipo desde una
--   perspectiva distinta a la ofensiva pura: no cuántos goles
--   meten, sino cuántos goles se ven en sus partidos en TOTAL
--   (ellos + rivales).
--
-- Diferencia clave con la query 05
--   * Query 05 → goles a favor (pura capacidad ofensiva)
--   * Query 06 → goles totales del partido (entretenimiento)
--
--   Un equipo que gana siempre 1-0 está alto en query 05 (hace
--   goles y los conserva) pero BAJO en esta (sus partidos son
--   aburridos de ver). Un equipo que pierde 3-4 también produce
--   espectáculo aunque no gane.
--
-- Métrica adicional: % over 2.5 goals
--   Sintaxis estándar en casas de apuestas: partido con 3+
--   goles totales. Es la métrica que más predice el retorno
--   de apuestas "over/under" en mercados deportivos.
--   Añadirla conecta el análisis con su uso real en industria.
--
-- Técnicas SQL demostradas
--   * CTE con expresión derivada (goles_partido)
--   * FILTER con agregado para calcular %
--   * Ratio entre agregados para derivar la métrica over
--   * ORDER BY sobre expresión computada en SELECT
-- ============================================================

WITH partidos_por_equipo AS (
    SELECT
        home_team_api_id                     AS team_api_id,
        league_id,
        home_team_goal + away_team_goal      AS goles_partido
    FROM match

    UNION ALL

    SELECT
        away_team_api_id                     AS team_api_id,
        league_id,
        home_team_goal + away_team_goal      AS goles_partido
    FROM match
)
SELECT
    t.team_long_name                                                        AS equipo,
    l.name                                                                  AS liga,
    COUNT(*)                                                                AS partidos,
    ROUND(AVG(p.goles_partido)::numeric, 2)                                 AS goles_por_partido,
    COUNT(*) FILTER (WHERE p.goles_partido >= 3)                            AS partidos_over_2_5,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE p.goles_partido >= 3) / COUNT(*),
        1
    )                                                                       AS pct_over_2_5,
    COUNT(*) FILTER (WHERE p.goles_partido = 0)                             AS partidos_0_0,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE p.goles_partido = 0) / COUNT(*),
        1
    )                                                                       AS pct_0_0
FROM partidos_por_equipo p
JOIN team   t ON t.team_api_id = p.team_api_id
JOIN league l ON l.id          = p.league_id
GROUP BY t.team_long_name, l.name
HAVING COUNT(*) >= 150
ORDER BY goles_por_partido DESC
LIMIT 10;


-- ============================================================
-- CONTRAPARTIDA (descomentar para ejecutar)
-- ============================================================
-- Top 10 equipos más ABURRIDOS (menos goles por partido)
-- ============================================================
/*
WITH partidos_por_equipo AS (
    SELECT home_team_api_id AS team_api_id, league_id,
           home_team_goal + away_team_goal AS goles_partido
    FROM match
    UNION ALL
    SELECT away_team_api_id AS team_api_id, league_id,
           home_team_goal + away_team_goal AS goles_partido
    FROM match
)
SELECT
    t.team_long_name AS equipo,
    l.name           AS liga,
    COUNT(*)         AS partidos,
    ROUND(AVG(p.goles_partido)::numeric, 2) AS goles_por_partido,
    ROUND(100.0 * COUNT(*) FILTER (WHERE p.goles_partido = 0) / COUNT(*), 1) AS pct_0_0,
    ROUND(100.0 * COUNT(*) FILTER (WHERE p.goles_partido <= 2) / COUNT(*), 1) AS pct_under_2_5
FROM partidos_por_equipo p
JOIN team   t ON t.team_api_id = p.team_api_id
JOIN league l ON l.id          = p.league_id
GROUP BY t.team_long_name, l.name
HAVING COUNT(*) >= 150
ORDER BY goles_por_partido ASC
LIMIT 10;
*/