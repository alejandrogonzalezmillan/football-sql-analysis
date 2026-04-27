-- ============================================================
-- Query 03 — Fortalezas en casa vs. equipos viajeros
-- ============================================================
-- Propósito
--   Medir la dependencia de cada equipo del factor "jugar en
--   casa". Dos equipos con el mismo % global de victorias
--   pueden ser muy distintos: uno puede ser fortísimo en casa
--   y mediocre fuera, y otro equilibrado. Esta query identifica
--   esas dos tipologías.
--
-- Métrica clave
--   GAP = % victorias en casa − % victorias fuera
--     * GAP alto  → "fortaleza casera" (dependencia del campo)
--     * GAP bajo  → equipo equilibrado o buen viajero
--
-- Reto técnico
--   Necesitamos calcular métricas separadas para dos "roles"
--   del mismo equipo (local/visitante) en la misma fila de
--   resultado. Aquí NO usamos UNION ALL (como en la query 02)
--   porque queremos AMBAS perspectivas en la misma fila, no
--   apiladas. Lo resolvemos con `FILTER` dentro de agregados,
--   pivotando en vertical → horizontal.
--
-- Técnicas SQL demostradas
--   * Agregados con FILTER condicional (pivote dinámico)
--   * CTE para separar cálculo por rol (local vs visitante)
--   * JOIN sobre CTE con el propio match por team_api_id
--   * Ordenación por métrica derivada (GAP)
-- ============================================================

WITH local AS (
    SELECT
        home_team_api_id                           AS team_api_id,
        league_id,
        COUNT(*)                                   AS partidos_local,
        COUNT(*) FILTER (WHERE home_team_goal > away_team_goal)  AS victorias_local
    FROM match
    GROUP BY home_team_api_id, league_id
),
visitante AS (
    SELECT
        away_team_api_id                           AS team_api_id,
        league_id,
        COUNT(*)                                   AS partidos_visitante,
        COUNT(*) FILTER (WHERE away_team_goal > home_team_goal)  AS victorias_visitante
    FROM match
    GROUP BY away_team_api_id, league_id
)
SELECT
    t.team_long_name                                                   AS equipo,
    l.name                                                             AS liga,
    lo.partidos_local,
    lo.victorias_local,
    ROUND(100.0 * lo.victorias_local / lo.partidos_local, 1)           AS pct_victorias_local,
    vi.partidos_visitante,
    vi.victorias_visitante,
    ROUND(100.0 * vi.victorias_visitante / vi.partidos_visitante, 1)   AS pct_victorias_visitante,
    ROUND(
        100.0 * lo.victorias_local / lo.partidos_local
      - 100.0 * vi.victorias_visitante / vi.partidos_visitante,
        1
    )                                                                  AS gap_casa_vs_fuera
FROM local lo
JOIN visitante vi ON vi.team_api_id = lo.team_api_id
JOIN team      t  ON t.team_api_id  = lo.team_api_id
JOIN league    l  ON l.id           = lo.league_id
WHERE lo.partidos_local >= 100     -- mínimo ~3 temporadas para validez estadística
ORDER BY gap_casa_vs_fuera DESC
LIMIT 15;

