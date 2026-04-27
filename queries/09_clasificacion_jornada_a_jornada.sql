-- ============================================================
-- Query 09 — Clasificación jornada a jornada: La Liga 2013/14
-- ============================================================
-- Propósito
--   Reconstruir la clasificación de La Liga 2013/14 jornada a
--   jornada. Esta temporada es legendaria: el Atlético de
--   Madrid de Simeone rompió el duopolio Barça–Real Madrid,
--   consiguiendo un título que se decidió en la última jornada
--   con un histórico 1-1 en el Camp Nou.
--
--   Devolvemos solo los top 3 contendientes al título (Barça,
--   Real Madrid, Atlético) para poder visualizar el duelo.
--
-- Nueva técnica: running totals con SUM() OVER
--   SUM(puntos) OVER (
--       PARTITION BY team
--       ORDER BY stage
--       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--   )
--
--   = "suma acumulada de puntos de cada equipo, ordenando por
--      jornada, desde la primera hasta la actual".
--
--   Este patrón es idéntico al que usarías en:
--     * Saldo acumulado de una cuenta bancaria
--     * Revenue acumulado año a año
--     * Kilómetros totales recorridos mes a mes
--
--   La clave es el frame: ROWS BETWEEN UNBOUNDED PRECEDING AND
--   CURRENT ROW (desde el inicio hasta la fila actual).
--   Si no lo especificas, Postgres usa RANGE por defecto y con
--   ORDER BY el comportamiento puede ser sorprendente — otra
--   razón más para declarar frames explícitamente.
--
-- Técnicas SQL demostradas
--   * SUM() OVER con ROWS BETWEEN ... frame explícito (running total)
--   * Combinación con RANK() OVER (posición en cada jornada)
--   * Filtro WHERE sobre datos de referencia (liga + temporada)
--   * JOIN con subquery para filtrar solo los 3 candidatos
-- ============================================================

WITH partidos_temporada AS (
    SELECT
        m.league_id,
        m.season,
        m.stage,
        m.date,
        home_team_api_id AS team_api_id,
        CASE
            WHEN home_team_goal > away_team_goal THEN 3
            WHEN home_team_goal = away_team_goal THEN 1
            ELSE 0
        END AS puntos
    FROM match m
    JOIN league l ON l.id = m.league_id
    WHERE l.name = 'Spain LIGA BBVA' AND m.season = '2013/2014'

    UNION ALL

    SELECT
        m.league_id,
        m.season,
        m.stage,
        m.date,
        away_team_api_id,
        CASE
            WHEN away_team_goal > home_team_goal THEN 3
            WHEN away_team_goal = home_team_goal THEN 1
            ELSE 0
        END
    FROM match m
    JOIN league l ON l.id = m.league_id
    WHERE l.name = 'Spain LIGA BBVA' AND m.season = '2013/2014'
),
evolucion AS (
    SELECT
        team_api_id,
        stage,
        date,
        puntos                                                              AS puntos_jornada,
        SUM(puntos) OVER (
            PARTITION BY team_api_id
            ORDER BY stage
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                                   AS puntos_acumulados
    FROM partidos_temporada
),
posiciones_por_jornada AS (
    SELECT
        team_api_id,
        stage,
        date,
        puntos_jornada,
        puntos_acumulados,
        RANK() OVER (
            PARTITION BY stage
            ORDER BY puntos_acumulados DESC
        ) AS posicion
    FROM evolucion
)
SELECT
    p.stage                          AS jornada,
    p.date::date                     AS fecha,
    t.team_long_name                 AS equipo,
    p.puntos_jornada                 AS pts_jornada,
    p.puntos_acumulados              AS pts_total,
    p.posicion
FROM posiciones_por_jornada p
JOIN team t ON t.team_api_id = p.team_api_id
WHERE t.team_long_name IN (
    'FC Barcelona',
    'Real Madrid CF',
    'Atlético Madrid'
)
ORDER BY p.stage, p.posicion;