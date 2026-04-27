-- ============================================================
-- Query 11 — Rachas invictas más largas (sin perder)
-- ============================================================
-- Propósito
--   Calcular la racha más larga de partidos sin derrota de
--   cada equipo. A diferencia de la query 10 (solo victorias),
--   aquí una racha se rompe ÚNICAMENTE con derrota: los
--   empates continúan la racha invicta.
--
-- Importancia analítica
--   En fútbol, un equipo invicto es estadísticamente más
--   relevante que uno con muchas victorias consecutivas,
--   porque refleja consistencia defensiva: no pierden,
--   aunque a veces empaten. Es la métrica que más valoran
--   analistas y casas de apuestas al evaluar la solidez
--   de un equipo.
--
-- Reutilización del patrón
--   Misma técnica de gaps and islands que en la query 10,
--   pero cambiando la lógica del "evento que rompe la racha":
--
--     Query 10: racha rota por (D o E)  → agrupar solo V
--     Query 11: racha rota solo por D   → agrupar V y E juntos
--
--   El cambio se hace introduciendo una columna derivada
--   `no_perdido` (V o E = 1, D = 0) y aplicando el mismo
--   algoritmo de dual ROW_NUMBER + diferencia.
--
-- Técnicas SQL demostradas
--   * Reutilización del patrón gaps and islands
--   * Transformación booleana sobre CASE previo
--   * Comparativa entre dos métricas derivadas del mismo patrón
-- ============================================================

WITH partidos_equipo AS (
    SELECT
        home_team_api_id AS team_api_id,
        league_id,
        date,
        CASE
            WHEN home_team_goal >= away_team_goal THEN 'NP'  -- No perdió (V o E)
            ELSE 'P'                                         -- Perdió
        END AS resultado
    FROM match

    UNION ALL

    SELECT
        away_team_api_id,
        league_id,
        date,
        CASE
            WHEN away_team_goal >= home_team_goal THEN 'NP'
            ELSE 'P'
        END
    FROM match
),
con_row_numbers AS (
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
    SELECT
        team_api_id,
        league_id,
        (rn_global - rn_por_resultado) AS grupo_isla,
        COUNT(*)                        AS longitud_racha,
        MIN(date)::date                 AS inicio,
        MAX(date)::date                 AS fin
    FROM con_row_numbers
    WHERE resultado = 'NP'
    GROUP BY team_api_id, league_id, grupo_isla
)
SELECT
    t.team_long_name                                AS equipo,
    l.name                                          AS liga,
    i.longitud_racha                                AS partidos_sin_perder,
    i.inicio,
    i.fin,
    (i.fin - i.inicio)                              AS dias_racha
FROM islas i
JOIN team   t ON t.team_api_id = i.team_api_id
JOIN league l ON l.id          = i.league_id
WHERE l.name != 'Belgium Jupiler League'   -- datos incompletos (query 07)
ORDER BY i.longitud_racha DESC, i.inicio
LIMIT 10;