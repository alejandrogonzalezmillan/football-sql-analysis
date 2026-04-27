-- ============================================================
-- Query 07 — Clasificación final por liga y temporada
-- ============================================================
-- Propósito
--   Reconstruir la clasificación oficial de cada liga al final
--   de cada temporada, aplicando el sistema puntuación estándar:
--     * 3 puntos por victoria
--     * 1 punto por empate
--     * 0 puntos por derrota
--
--   Devuelve el TOP 3 de cada combinación (liga × temporada):
--   campeón, subcampeón y tercer clasificado.
--
-- Salto conceptual
--   Hasta la query 06 todo eran agregaciones y joins clásicos.
--   Aquí usamos por primera vez WINDOW FUNCTIONS: funciones
--   que calculan un valor por fila basándose en un "marco" de
--   filas relacionadas, SIN colapsar los resultados como haría
--   un GROUP BY.
--
-- Window function utilizada
--   RANK() OVER (PARTITION BY liga, temporada ORDER BY puntos DESC)
--
--   Esto significa: "para cada combinación de liga+temporada,
--   ordena los equipos por puntos descendente y asígnales una
--   posición (1, 2, 3, ...)". El PARTITION BY es el equivalente
--   de GROUP BY pero dentro de una window function.
--
--   Diferencia entre RANK, DENSE_RANK y ROW_NUMBER:
--     * ROW_NUMBER: cada fila recibe un número único (1, 2, 3, 4)
--     * RANK:       empates comparten posición, salta números (1, 2, 2, 4)
--     * DENSE_RANK: empates comparten posición, sin saltos (1, 2, 2, 3)
--
--   Usamos RANK porque refleja cómo funciona el fútbol: si hay
--   empate a puntos, desempate por goal difference (que no
--   calculamos aquí), pero mantenemos la lógica de "posición"
--   oficial.
--
-- Técnicas SQL demostradas
--   * WINDOW FUNCTION: RANK() OVER (PARTITION BY ... ORDER BY ...)
--   * Subconsulta en FROM para poder filtrar sobre la window
--     (no se puede filtrar una window function en el WHERE
--     directamente — se necesita envolver en subquery o CTE)
--   * Triple CTE encadenada (puntos, clasificación, resultado)
-- ============================================================

WITH puntos_por_partido AS (
    -- Calculamos los puntos de cada equipo en cada partido,
    -- para ambas perspectivas (local y visitante)
    SELECT
        home_team_api_id AS team_api_id,
        league_id,
        season,
        CASE
            WHEN home_team_goal > away_team_goal THEN 3
            WHEN home_team_goal = away_team_goal THEN 1
            ELSE 0
        END              AS puntos,
        CASE WHEN home_team_goal > away_team_goal THEN 1 ELSE 0 END  AS victoria,
        CASE WHEN home_team_goal = away_team_goal THEN 1 ELSE 0 END  AS empate,
        CASE WHEN home_team_goal < away_team_goal THEN 1 ELSE 0 END  AS derrota,
        home_team_goal   AS gf,
        away_team_goal   AS gc
    FROM match

    UNION ALL

    SELECT
        away_team_api_id,
        league_id,
        season,
        CASE
            WHEN away_team_goal > home_team_goal THEN 3
            WHEN away_team_goal = home_team_goal THEN 1
            ELSE 0
        END,
        CASE WHEN away_team_goal > home_team_goal THEN 1 ELSE 0 END,
        CASE WHEN away_team_goal = home_team_goal THEN 1 ELSE 0 END,
        CASE WHEN away_team_goal < home_team_goal THEN 1 ELSE 0 END,
        away_team_goal,
        home_team_goal
    FROM match
),
tabla_temporada AS (
    SELECT
        team_api_id,
        league_id,
        season,
        SUM(puntos)         AS puntos,
        SUM(victoria)       AS ganados,
        SUM(empate)         AS empatados,
        SUM(derrota)        AS perdidos,
        SUM(gf)             AS goles_favor,
        SUM(gc)             AS goles_contra,
        SUM(gf - gc)        AS diferencia_goles
    FROM puntos_por_partido
    GROUP BY team_api_id, league_id, season
),
ranking_temporada AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY league_id, season
            ORDER BY puntos DESC, diferencia_goles DESC, goles_favor DESC
        ) AS posicion
    FROM tabla_temporada
)
SELECT
    l.name                    AS liga,
    r.season                  AS temporada,
    r.posicion,
    t.team_long_name          AS equipo,
    r.puntos,
    r.ganados,
    r.empatados,
    r.perdidos,
    r.goles_favor             AS gf,
    r.goles_contra            AS gc,
    r.diferencia_goles        AS dg
FROM ranking_temporada r
JOIN team   t ON t.team_api_id = r.team_api_id
JOIN league l ON l.id          = r.league_id
WHERE r.posicion <= 3
ORDER BY l.name, r.season, r.posicion;