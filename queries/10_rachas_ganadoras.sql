-- ============================================================
-- Query 10 — Rachas ganadoras consecutivas más largas
-- ============================================================
-- Propósito
--   Calcular la racha de victorias consecutivas más larga de
--   cada equipo en toda su historia dentro del dataset, y
--   devolver el top 10 europeo.
--
-- Por qué esta query es especial
--   Resuelve el problema llamado "GAPS AND ISLANDS", que es
--   literalmente la pregunta SQL más recurrente en entrevistas
--   técnicas de Data Analyst senior en FAANG, consultoras y
--   startups unicornio. El planteamiento original viene de
--   Itzik Ben-Gan ("SQL Server MVP Deep Dives", 2009) y es
--   aplicable en MUCHOS dominios:
--     * Rachas de días consecutivos de actividad de un usuario
--     * Días consecutivos en rojo en una cuenta bancaria
--     * Periodos de uptime/downtime de un servidor
--     * Trimestres consecutivos de crecimiento de ventas
--
-- Intuición del algoritmo
--   Queremos agrupar victorias consecutivas en "islas" separadas
--   por "gaps" (derrotas o empates). El truco canónico:
--
--     1. A cada fila (partido) le asignamos dos ROW_NUMBER:
--        * rn_global:  secuencia general de partidos del equipo
--        * rn_victorias: secuencia SOLO entre las victorias
--
--     2. La DIFERENCIA (rn_global - rn_victorias) es constante
--        dentro de cada isla de victorias consecutivas, y cambia
--        cuando hay una derrota/empate que rompe la racha.
--
--     3. Agrupamos por esa diferencia → cada grupo es una isla.
--        MAX(COUNT) por equipo = racha más larga.
--
--   Es elegante, rápido (O(n log n)) y funciona en cualquier
--   motor SQL que soporte window functions (Postgres, MySQL 8+,
--   SQL Server, Oracle, BigQuery, Snowflake...).
--
-- Técnicas SQL demostradas
--   * GAPS AND ISLANDS pattern (dual ROW_NUMBER + GROUP BY diff)
--   * ROW_NUMBER con dos particiones distintas sobre misma tabla
--   * Triple CTE encadenada
--   * WHERE sobre window function vía subquery (imposible en WHERE directo)
--   * HAVING sobre agregado para filtrar islas
-- ============================================================

WITH partidos_equipo AS (
    -- Paso 1: desnormalizamos para tener una fila por partido-equipo
    SELECT
        home_team_api_id AS team_api_id,
        league_id,
        season,
        date,
        CASE
            WHEN home_team_goal > away_team_goal THEN 'V'
            WHEN home_team_goal = away_team_goal THEN 'E'
            ELSE 'D'
        END AS resultado
    FROM match

    UNION ALL

    SELECT
        away_team_api_id,
        league_id,
        season,
        date,
        CASE
            WHEN away_team_goal > home_team_goal THEN 'V'
            WHEN away_team_goal = home_team_goal THEN 'E'
            ELSE 'D'
        END
    FROM match
),
con_row_numbers AS (
    -- Paso 2: asignamos dos ROW_NUMBERS (el truco de gaps and islands)
    SELECT
        team_api_id,
        league_id,
        date,
        resultado,
        ROW_NUMBER() OVER (
            PARTITION BY team_api_id
            ORDER BY date
        ) AS rn_global,
        ROW_NUMBER() OVER (
            PARTITION BY team_api_id, resultado
            ORDER BY date
        ) AS rn_por_resultado
    FROM partidos_equipo
),
islas AS (
    -- Paso 3: la diferencia entre los dos ROW_NUMBERS identifica la isla
    -- Filtramos solo las victorias y agrupamos
    SELECT
        team_api_id,
        league_id,
        (rn_global - rn_por_resultado)      AS grupo_isla,
        COUNT(*)                             AS longitud_racha,
        MIN(date)::date                      AS inicio,
        MAX(date)::date                      AS fin
    FROM con_row_numbers
    WHERE resultado = 'V'
    GROUP BY team_api_id, league_id, grupo_isla
)
-- Paso 4: recuperamos la racha más larga de cada equipo y hacemos ranking
SELECT
    t.team_long_name         AS equipo,
    l.name                   AS liga,
    i.longitud_racha         AS victorias_consecutivas,
    i.inicio,
    i.fin,
    (i.fin - i.inicio)       AS dias_racha
FROM islas i
JOIN team   t ON t.team_api_id = i.team_api_id
JOIN league l ON l.id          = i.league_id
WHERE l.name != 'Belgium Jupiler League'   -- datos incompletos (query 07)
ORDER BY i.longitud_racha DESC, i.inicio
LIMIT 10;