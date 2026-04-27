-- ============================================================
-- Query 05 — Equipos más goleadores vs más defensivos
-- ============================================================
-- Propósito
--   Clasificar equipos según su perfil ofensivo/defensivo:
--     * GOLES A FAVOR por partido  (ataque)
--     * GOLES EN CONTRA por partido (defensa)
--     * DIFERENCIA (balance ofensivo neto)
--
--   Permite identificar:
--     * Equipos "ofensivos espectáculo" (muchos goles a favor
--       y en contra → partidos abiertos).
--     * Equipos "fortaleza defensiva" (pocos goles a favor y
--       en contra → partidos cerrados, 1-0).
--     * Equipos "top" (muchos goles a favor, pocos en contra).
--
-- Reto técnico
--   Reutilizamos el patrón wide → long (UNION ALL) de la
--   query 02 pero añadiendo la dimensión GOLES anotados y
--   recibidos desde cada perspectiva. Las columnas del match
--   cambian de rol según el equipo esté como local o visitante.
--
-- Técnicas SQL demostradas
--   * CTE + UNION ALL para desnormalización con dos métricas
--   * AVG de expresiones compuestas (no columnas directas)
--   * Subquery en FROM del ranking final
--   * ROUND + CAST para presentación
--   * UNION entre dos SELECT finales etiquetados (dos rankings
--     en una sola query: top ataque / top defensa)
-- ============================================================

WITH partidos_por_equipo AS (
    SELECT
        home_team_api_id AS team_api_id,
        league_id,
        home_team_goal   AS goles_favor,
        away_team_goal   AS goles_contra
    FROM match

    UNION ALL

    SELECT
        away_team_api_id AS team_api_id,
        league_id,
        away_team_goal   AS goles_favor,
        home_team_goal   AS goles_contra
    FROM match
),
estadisticas_equipo AS (
    SELECT
        p.team_api_id,
        p.league_id,
        COUNT(*)                                                    AS partidos,
        ROUND(AVG(p.goles_favor)::numeric, 2)                       AS gpp_favor,
        ROUND(AVG(p.goles_contra)::numeric, 2)                      AS gpp_contra,
        ROUND(AVG(p.goles_favor - p.goles_contra)::numeric, 2)      AS diferencia
    FROM partidos_por_equipo p
    GROUP BY p.team_api_id, p.league_id
    HAVING COUNT(*) >= 150
)
-- Ranking 1: TOP 10 equipos más goleadores (mayor gpp_favor)
SELECT
    'Más goleadores' AS categoria,
    t.team_long_name AS equipo,
    l.name           AS liga,
    e.partidos,
    e.gpp_favor,
    e.gpp_contra,
    e.diferencia
FROM estadisticas_equipo e
JOIN team   t ON t.team_api_id = e.team_api_id
JOIN league l ON l.id          = e.league_id
ORDER BY e.gpp_favor DESC
LIMIT 10;


-- ============================================================
-- RANKING ALTERNATIVO (descomentar para ejecutar)
-- ============================================================
-- Top 10 equipos MÁS DEFENSIVOS (menor gpp_contra)
-- ============================================================
/*
WITH partidos_por_equipo AS (
    SELECT home_team_api_id AS team_api_id, league_id,
           home_team_goal AS goles_favor, away_team_goal AS goles_contra
    FROM match
    UNION ALL
    SELECT away_team_api_id AS team_api_id, league_id,
           away_team_goal AS goles_favor, home_team_goal AS goles_contra
    FROM match
),
estadisticas_equipo AS (
    SELECT p.team_api_id, p.league_id,
           COUNT(*) AS partidos,
           ROUND(AVG(p.goles_favor)::numeric, 2)   AS gpp_favor,
           ROUND(AVG(p.goles_contra)::numeric, 2)  AS gpp_contra,
           ROUND(AVG(p.goles_favor - p.goles_contra)::numeric, 2) AS diferencia
    FROM partidos_por_equipo p
    GROUP BY p.team_api_id, p.league_id
    HAVING COUNT(*) >= 150
)
SELECT 'Más defensivos' AS categoria,
       t.team_long_name AS equipo,
       l.name AS liga,
       e.partidos, e.gpp_favor, e.gpp_contra, e.diferencia
FROM estadisticas_equipo e
JOIN team   t ON t.team_api_id = e.team_api_id
JOIN league l ON l.id          = e.league_id
ORDER BY e.gpp_contra ASC
LIMIT 10;
*/