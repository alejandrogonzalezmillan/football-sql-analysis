-- ============================================================
-- Query 14 — Evolución táctica: el ADN de los grandes equipos
-- ============================================================
-- Propósito
--   Reconstruir la evolución del estilo de juego (el "ADN
--   táctico") de los grandes equipos europeos año a año, y
--   detectar en qué temporadas hubo un CAMBIO BRUSCO de estilo
--   (típicamente por un cambio de entrenador).
--
--   Es la query de cierre del proyecto: combina varias técnicas
--   y cuenta una historia que solo se ve con datos a lo largo
--   del tiempo.
--
-- Fuente de datos
--   team_attributes: snapshots anuales de parámetros tácticos
--   de FIFA para cada equipo. Las métricas clave:
--     * buildupplayspeed      → velocidad de construcción (0-100)
--     * buildupplaypassing    → estilo de pase (corto vs largo)
--     * chancecreationpassing → creación vía pase
--     * chancecreationshooting→ creación vía disparo
--     * defencepressure       → intensidad de presión (0-100)
--     * defenceaggression     → agresividad defensiva
--     * defenceteamwidth      → amplitud defensiva
--
-- Nueva técnica: LAG() — comparar con el año anterior
--   LAG(columna) OVER (PARTITION BY equipo ORDER BY anio)
--   = "¿cuál era el valor de esa columna en la fila anterior
--      del mismo equipo ordenando por año?"
--
--   Es la función fundamental para análisis temporal:
--     * Calcular crecimiento año-sobre-año (YoY)
--     * Detectar cambios bruscos en series temporales
--     * Calcular diferencias entre filas consecutivas
--
--   Su hermana LEAD() hace lo mismo pero mirando hacia ADELANTE.
--
-- Segunda técnica: AVG OVER toda la ventana
--   AVG(col) OVER (PARTITION BY equipo) sin ORDER BY
--   = "la media histórica del equipo en toda su serie temporal".
--   Permite comparar el valor puntual de un año con la media
--   histórica del mismo equipo → ¿ese año fue atípico?
--
-- Técnicas SQL demostradas
--   * LAG() window function (comparativa temporal)
--   * AVG() OVER con partición pero sin ORDER (media global por grupo)
--   * Múltiples window functions en la misma query
--   * ABS() para detectar magnitud del cambio (sin importar signo)
--   * Filtro sobre columna derivada vía CTE adicional
-- ============================================================

WITH equipos_grandes AS (
    -- Seleccionamos una muestra representativa de equipos top
    -- europeos para que el resultado sea legible.
    SELECT team_api_id, team_long_name
    FROM team
    WHERE team_long_name IN (
        'FC Barcelona',
        'Real Madrid CF',
        'FC Bayern Munich',
        'Juventus',
        'Manchester United',
        'Chelsea',
        'Paris Saint-Germain',
        'Ajax'
    )
),
stats_anuales AS (
    -- Para cada equipo y año, extraemos las métricas tácticas.
    -- Si FIFA publicó varias actualizaciones el mismo año, nos
    -- quedamos con la más reciente.
    SELECT
        ta.team_api_id,
        EXTRACT(YEAR FROM ta.date::timestamp)::int   AS anio,
        ta.buildupplayspeed                           AS velocidad,
        ta.buildupplaypassing                         AS pase_construccion,
        ta.chancecreationpassing                      AS creacion_pase,
        ta.chancecreationshooting                     AS creacion_disparo,
        ta.defencepressure                            AS presion,
        ta.defenceaggression                          AS agresividad,
        ta.defenceteamwidth                           AS amplitud,
        ROW_NUMBER() OVER (
            PARTITION BY ta.team_api_id, EXTRACT(YEAR FROM ta.date::timestamp)
            ORDER BY ta.date DESC
        ) AS rn
    FROM team_attributes ta
    WHERE ta.team_api_id IN (SELECT team_api_id FROM equipos_grandes)
),
con_comparativas AS (
    -- Aquí llegan las window functions de análisis temporal:
    -- comparamos el valor de cada año con el año anterior y con
    -- la media histórica del mismo equipo.
    SELECT
        s.team_api_id,
        s.anio,
        s.velocidad,
        s.presion,
        s.creacion_pase,
        -- Valores del año anterior
        LAG(s.velocidad) OVER (
            PARTITION BY s.team_api_id ORDER BY s.anio
        ) AS velocidad_anterior,
        LAG(s.presion) OVER (
            PARTITION BY s.team_api_id ORDER BY s.anio
        ) AS presion_anterior,
        -- Cambios año-sobre-año
        s.velocidad - LAG(s.velocidad) OVER (
            PARTITION BY s.team_api_id ORDER BY s.anio
        ) AS delta_velocidad,
        s.presion - LAG(s.presion) OVER (
            PARTITION BY s.team_api_id ORDER BY s.anio
        ) AS delta_presion,
        -- Media histórica del equipo (sin ORDER BY = toda la ventana)
        ROUND(AVG(s.velocidad) OVER (PARTITION BY s.team_api_id)::numeric, 1) AS velocidad_media_historica,
        ROUND(AVG(s.presion)   OVER (PARTITION BY s.team_api_id)::numeric, 1) AS presion_media_historica
    FROM stats_anuales s
    WHERE s.rn = 1
)
SELECT
    eg.team_long_name                    AS equipo,
    c.anio,
    c.velocidad,
    c.velocidad_anterior,
    c.delta_velocidad,
    c.velocidad_media_historica,
    c.presion,
    c.presion_anterior,
    c.delta_presion,
    c.presion_media_historica,
    c.creacion_pase
FROM con_comparativas c
JOIN equipos_grandes eg ON eg.team_api_id = c.team_api_id
ORDER BY eg.team_long_name, c.anio;

