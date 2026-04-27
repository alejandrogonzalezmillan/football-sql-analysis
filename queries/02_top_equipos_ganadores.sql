-- ============================================================
-- Query 02 — Top 10 equipos más ganadores del dataset
-- ============================================================
-- Propósito
--   Identificar los equipos dominantes en Europa entre 2008 y
--   2016 por número de victorias acumuladas, con desglose de
--   partidos jugados, empates, derrotas y % de victorias.
--
-- Reto técnico
--   Un partido genera DOS perspectivas (equipo local y equipo
--   visitante), pero la tabla `match` las guarda en UNA sola
--   fila con columnas distintas. Para calcular resultados por
--   equipo hay que "desnormalizar" la tabla: reshape de
--   formato ancho (wide) a formato largo (long).
--
-- Solución
--   UNION ALL de dos SELECT sobre la misma tabla, uno para la
--   perspectiva local y otro para la visitante. El resultado
--   es una tabla virtual con una fila por "participación" de
--   un equipo en un partido (≈ 2 × nº partidos).
--
-- Técnicas SQL demostradas
--   * CTE (Common Table Expression) con WITH
--   * UNION ALL para desnormalización wide → long
--   * CASE WHEN anidado para clasificar resultados
--   * Conditional aggregation con SUM(CASE ...) y FILTER
--   * HAVING para filtrar grupos con trayectoria mínima
-- ============================================================

WITH resultados_equipo AS (
    -- Perspectiva del equipo LOCAL
    SELECT
        home_team_api_id AS team_api_id,
        CASE
            WHEN home_team_goal > away_team_goal THEN 'victoria'
            WHEN home_team_goal < away_team_goal THEN 'derrota'
            ELSE 'empate'
        END              AS resultado,
        league_id,
        season
    FROM match

    UNION ALL

    -- Perspectiva del equipo VISITANTE
    SELECT
        away_team_api_id AS team_api_id,
        CASE
            WHEN away_team_goal > home_team_goal THEN 'victoria'
            WHEN away_team_goal < home_team_goal THEN 'derrota'
            ELSE 'empate'
        END              AS resultado,
        league_id,
        season
    FROM match
)
SELECT
    t.team_long_name                                                  AS equipo,
    l.name                                                            AS liga,
    COUNT(*)                                                          AS partidos,
    COUNT(*) FILTER (WHERE r.resultado = 'victoria')                  AS victorias,
    COUNT(*) FILTER (WHERE r.resultado = 'empate')                    AS empates,
    COUNT(*) FILTER (WHERE r.resultado = 'derrota')                   AS derrotas,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE r.resultado = 'victoria') / COUNT(*),
        1
    )                                                                 AS pct_victorias
FROM resultados_equipo r
JOIN team   t ON t.team_api_id = r.team_api_id
JOIN league l ON l.id = r.league_id
GROUP BY t.team_long_name, l.name
HAVING COUNT(*) >= 150   -- mínimo ~2 temporadas completas para ser relevante
ORDER BY victorias DESC
LIMIT 10;