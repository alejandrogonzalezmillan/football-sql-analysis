-- ============================================================
-- Query 08 — "Qué cerca estuvieron": diferencia con el campeón
-- ============================================================
-- Propósito
--   Calcular la distancia (en puntos) con la que cada equipo
--   terminó respecto al campeón de su liga cada temporada, y
--   devolver los SUBCAMPEONATOS MÁS DOLOROSOS de Europa: los
--   segundos clasificados que estuvieron más cerca de ganar.
--
--   Bonus: identificar las temporadas con ligas más ajustadas
--   (menor diferencia entre 1º y 2º) y las más desequilibradas
--   (mayor diferencia).
--
-- Nueva window function: FIRST_VALUE
--   FIRST_VALUE(columna) OVER (PARTITION BY ... ORDER BY ...)
--
--   Devuelve el valor de esa columna para la PRIMERA fila de
--   cada partición, según el orden especificado. Aquí la
--   usamos así:
--
--     FIRST_VALUE(puntos) OVER (
--         PARTITION BY league_id, season
--         ORDER BY puntos DESC
--     )
--
--   = "para cada liga+temporada, ordenados por puntos
--      descendente, dame los puntos del equipo #1 (campeón)".
--
--   Resultado: a cada fila se le añade una columna con los
--   puntos del campeón de SU liga en SU temporada. Con eso ya
--   podemos restar: puntos_campeon - puntos_equipo = distancia.
--
-- Técnicas SQL demostradas
--   * FIRST_VALUE como window function (nueva)
--   * Combinación de MÚLTIPLES window functions en la misma
--     subquery (RANK + FIRST_VALUE)
--   * Expresión derivada usando valores de window functions
--   * ORDER BY sobre la métrica calculada (distancia)
-- ============================================================

WITH puntos_por_partido AS (
    SELECT
        home_team_api_id AS team_api_id,
        league_id,
        season,
        CASE
            WHEN home_team_goal > away_team_goal THEN 3
            WHEN home_team_goal = away_team_goal THEN 1
            ELSE 0
        END AS puntos
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
        END
    FROM match
),
tabla_temporada AS (
    SELECT
        team_api_id,
        league_id,
        season,
        SUM(puntos) AS puntos
    FROM puntos_por_partido
    GROUP BY team_api_id, league_id, season
),
ranking_con_distancia AS (
    SELECT
        team_api_id,
        league_id,
        season,
        puntos,
        RANK() OVER (
            PARTITION BY league_id, season
            ORDER BY puntos DESC
        ) AS posicion,
        FIRST_VALUE(puntos) OVER (
            PARTITION BY league_id, season
            ORDER BY puntos DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS puntos_campeon
    FROM tabla_temporada
)
-- Resultado 1: los SUBCAMPEONATOS MÁS DOLOROSOS de Europa
-- (segundos clasificados que más cerca estuvieron)
SELECT
    l.name                        AS liga,
    r.season                      AS temporada,
    t.team_long_name              AS subcampeon,
    r.puntos                      AS puntos_subcampeon,
    r.puntos_campeon              AS puntos_campeon,
    r.puntos_campeon - r.puntos   AS diferencia
FROM ranking_con_distancia r
JOIN team   t ON t.team_api_id = r.team_api_id
JOIN league l ON l.id          = r.league_id
WHERE r.posicion = 2
  AND r.season != '2013/2014'           -- excluimos Bélgica 2013/14 (datos corruptos)
  AND l.name NOT IN ('Belgium Jupiler League')  -- o mejor: excluir toda Bélgica para fiabilidad
ORDER BY diferencia ASC, l.name
LIMIT 15;



*/
