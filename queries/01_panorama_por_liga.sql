-- ============================================================
-- Query 01 — Panorama por liga
-- ============================================================
-- Propósito
--   "Radiografía" de cada liga del dataset para contextualizar
--   el resto de análisis: tamaño, estilo de juego (ofensivo vs
--   defensivo) y equilibrio entre equipos locales y visitantes.
--
-- Qué devuelve (una fila por liga)
--   * País y nombre de la liga
--   * Número de partidos y equipos distintos
--   * Goles totales y goles por partido
--   * % victorias locales, visitantes y empates
--   * Rango temporal cubierto
--
-- Técnicas SQL demostradas
--   * JOIN multi-tabla (match + league + country)
--   * Agregaciones condicionales: SUM(CASE WHEN ...)
--   * COUNT DISTINCT para cardinalidad
--   * CAST a numeric + ROUND para presentación limpia
--   * GROUP BY con ORDER BY sobre métrica derivada
-- ============================================================

SELECT
    c.name                                                           AS pais,
    l.name                                                           AS liga,
    COUNT(*)                                                         AS partidos,
    COUNT(DISTINCT m.home_team_api_id)                               AS equipos,
    SUM(m.home_team_goal + m.away_team_goal)                         AS goles_totales,
    ROUND(AVG(m.home_team_goal + m.away_team_goal)::numeric, 2)      AS goles_por_partido,
    ROUND(
        100.0 * SUM(CASE WHEN m.home_team_goal > m.away_team_goal THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                AS pct_victoria_local,
    ROUND(
        100.0 * SUM(CASE WHEN m.home_team_goal < m.away_team_goal THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                AS pct_victoria_visitante,
    ROUND(
        100.0 * SUM(CASE WHEN m.home_team_goal = m.away_team_goal THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                                AS pct_empates,
    MIN(m.date)::date                                                AS primera_fecha,
    MAX(m.date)::date                                                AS ultima_fecha
FROM match m
JOIN league  l ON l.id = m.league_id
JOIN country c ON c.id = l.country_id
GROUP BY c.name, l.name
ORDER BY goles_por_partido DESC;