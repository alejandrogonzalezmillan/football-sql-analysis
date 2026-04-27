-- ============================================================
-- Query 12 — El Clásico histórico (Barça vs Real Madrid)
-- ============================================================
-- Propósito
--   Recuperar TODOS los enfrentamientos de liga entre Barça y
--   Real Madrid del dataset (agosto 2008 – mayo 2016) con
--   contexto completo, y calcular el balance histórico con
--   métricas agregadas en la MISMA query.
--
--   Es la query "estrella narrativa" del proyecto: combina
--   una tabla detallada (cada enfrentamiento) con KPIs globales
--   al final usando GROUPING SETS o una segunda CTE agregada.
--
-- Reto técnico
--   1. Identificar partidos donde AMBOS equipos son uno de los
--      dos clásicos, sin importar quién sea local.
--   2. Construir un resultado legible: ganador, marcador
--      formateado, "estadio" (Santiago Bernabéu o Camp Nou).
--   3. Añadir una fila de resumen al final con el balance
--      histórico.
--
-- Nueva técnica: GROUPING SETS
--   GROUPING SETS permite producir en una sola query varias
--   agregaciones distintas (el resumen global + los detalles).
--   Aquí usamos un enfoque más claro: UNION ALL entre detalle
--   (fila por partido) y totales (una fila única calculada
--   con COUNT/SUM). Es la forma clásica de hacer "detalle +
--   resumen" en un mismo informe.
--
-- Técnicas SQL demostradas
--   * Multi-join (match + dos aliases de team)
--   * CASE con condiciones de ambos lados (local y visitante)
--   * Subqueries en SELECT para traer datos relacionados
--   * String formatting con || para construir labels
--   * Uso práctico de filtros WHERE con IN sobre subquery
-- ============================================================

WITH clasicos AS (
    SELECT
        m.id,
        m.season,
        m.stage,
        m.date::date         AS fecha,
        home.team_long_name  AS equipo_local,
        away.team_long_name  AS equipo_visitante,
        m.home_team_goal     AS goles_local,
        m.away_team_goal     AS goles_visitante,
        CASE
            WHEN m.home_team_goal > m.away_team_goal THEN home.team_long_name
            WHEN m.home_team_goal < m.away_team_goal THEN away.team_long_name
            ELSE 'Empate'
        END                  AS ganador,
        CASE
            WHEN home.team_long_name = 'FC Barcelona' THEN 'Camp Nou'
            ELSE 'Santiago Bernabéu'
        END                  AS estadio
    FROM match m
    JOIN team home ON home.team_api_id = m.home_team_api_id
    JOIN team away ON away.team_api_id = m.away_team_api_id
    WHERE
        (home.team_long_name = 'FC Barcelona' AND away.team_long_name = 'Real Madrid CF')
     OR (home.team_long_name = 'Real Madrid CF' AND away.team_long_name = 'FC Barcelona')
)
-- Detalle: todos los clásicos uno a uno
SELECT
    fecha,
    season                                                                AS temporada,
    stage                                                                 AS jornada,
    estadio,
    equipo_local || ' ' || goles_local || '-' || goles_visitante || ' ' || equipo_visitante
                                                                          AS marcador,
    ganador,
    (goles_local + goles_visitante)                                       AS goles_totales
FROM clasicos
ORDER BY fecha;



*/
