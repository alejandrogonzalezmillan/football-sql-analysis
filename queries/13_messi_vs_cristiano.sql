-- ============================================================
-- Query 13 — Messi vs Cristiano: evolución del rating FIFA
-- ============================================================
-- Propósito
--   Reconstruir la evolución año a año del rating FIFA de los
--   dos mejores jugadores de la era 2008-2016, generando una
--   tabla pivotada que permite compararlos directamente.
--
-- Fuente de datos
--   La tabla `player_attributes` contiene snapshots de ratings
--   FIFA de cada jugador con fechas. FIFA actualiza ratings
--   varias veces por temporada, así que puede haber múltiples
--   filas por jugador y año. Nos quedamos con el ÚLTIMO
--   rating de cada año (más reciente = más definitivo).
--
-- Reto técnico: pivotar filas a columnas
--   La tabla original tiene una fila por (jugador, fecha).
--   Queremos una fila por año con DOS columnas (Messi y CR7
--   lado a lado). Esto es un pivote vertical → horizontal.
--
--   PostgreSQL no tiene un operador PIVOT directo como SQL
--   Server. Se resuelve con el patrón estándar de CASE WHEN
--   dentro de agregados. Otros motores que sí tienen PIVOT
--   nativo (SQL Server, Oracle, Snowflake) traducirían esto
--   a una sintaxis más corta, pero el patrón de CASE WHEN
--   funciona en TODOS los motores SQL modernos.
--
-- Técnicas SQL demostradas
--   * ILIKE (case-insensitive LIKE) para match fuzzy de nombres
--   * EXTRACT(YEAR FROM ...) para truncar fechas a año
--   * ROW_NUMBER para "tomar la última fila por grupo"
--   * Pivote manual con CASE WHEN + MAX (o COALESCE)
--   * Self-comparison: el rating de Messi menos el de CR7
-- ============================================================

WITH jugadores_estrella AS (
    -- Localizamos los dos jugadores. Usamos ILIKE porque los
    -- nombres en el dataset pueden tener variantes (acentos,
    -- espacios, segundos apellidos).
    SELECT
        player_api_id,
        player_name
    FROM player
    WHERE player_name ILIKE '%Lionel Messi%'
       OR player_name ILIKE '%Cristiano Ronaldo%'
),
ratings_por_anio AS (
    -- Para cada jugador y año, nos quedamos con el rating MÁS
    -- RECIENTE (la última actualización de FIFA en ese año).
    SELECT
        pa.player_api_id,
        EXTRACT(YEAR FROM pa.date::timestamp)::int AS anio,
        pa.overall_rating,
        pa.potential,
        pa.finishing,
        pa.dribbling,
        pa.ball_control,
        pa.sprint_speed,
        pa.strength,
        pa.heading_accuracy,
        ROW_NUMBER() OVER (
            PARTITION BY pa.player_api_id, EXTRACT(YEAR FROM pa.date::timestamp)
            ORDER BY pa.date DESC
        ) AS rn
    FROM player_attributes pa
    WHERE pa.player_api_id IN (SELECT player_api_id FROM jugadores_estrella)
),
ratings_limpios AS (
    -- Filtramos solo la última fila de cada año-jugador y
    -- asociamos nombres para el pivote.
    SELECT
        je.player_name,
        r.anio,
        r.overall_rating
    FROM ratings_por_anio r
    JOIN jugadores_estrella je ON je.player_api_id = r.player_api_id
    WHERE r.rn = 1
)
SELECT
    anio                                                                   AS año,
    MAX(CASE WHEN player_name ILIKE '%messi%'             THEN overall_rating END) AS messi,
    MAX(CASE WHEN player_name ILIKE '%cristiano ronaldo%' THEN overall_rating END) AS cristiano,
    MAX(CASE WHEN player_name ILIKE '%messi%'             THEN overall_rating END)
      - MAX(CASE WHEN player_name ILIKE '%cristiano ronaldo%' THEN overall_rating END)
                                                                           AS diferencia
FROM ratings_limpios
GROUP BY anio
ORDER BY anio;


-- ============================================================
-- COMPARATIVA POR ATRIBUTOS (descomentar para ejecutar)
-- ============================================================
-- Compara el PICO histórico (mejor valor alcanzado) de cada
-- atributo de juego: dónde Messi supera a CR7 y viceversa.
-- ============================================================
/*
SELECT
    'Finishing'           AS atributo,
    MAX(CASE WHEN p.player_name ILIKE '%messi%'             THEN pa.finishing END) AS messi,
    MAX(CASE WHEN p.player_name ILIKE '%cristiano ronaldo%' THEN pa.finishing END) AS cristiano
FROM player_attributes pa
JOIN player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name ILIKE '%Lionel Messi%' OR p.player_name ILIKE '%Cristiano Ronaldo%'

UNION ALL

SELECT 'Dribbling',
    MAX(CASE WHEN p.player_name ILIKE '%messi%'             THEN pa.dribbling END),
    MAX(CASE WHEN p.player_name ILIKE '%cristiano ronaldo%' THEN pa.dribbling END)
FROM player_attributes pa
JOIN player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name ILIKE '%Lionel Messi%' OR p.player_name ILIKE '%Cristiano Ronaldo%'

UNION ALL

SELECT 'Ball control',
    MAX(CASE WHEN p.player_name ILIKE '%messi%'             THEN pa.ball_control END),
    MAX(CASE WHEN p.player_name ILIKE '%cristiano ronaldo%' THEN pa.ball_control END)
FROM player_attributes pa
JOIN player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name ILIKE '%Lionel Messi%' OR p.player_name ILIKE '%Cristiano Ronaldo%'

UNION ALL

SELECT 'Sprint speed',
    MAX(CASE WHEN p.player_name ILIKE '%messi%'             THEN pa.sprint_speed END),
    MAX(CASE WHEN p.player_name ILIKE '%cristiano ronaldo%' THEN pa.sprint_speed END)
FROM player_attributes pa
JOIN player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name ILIKE '%Lionel Messi%' OR p.player_name ILIKE '%Cristiano Ronaldo%'

UNION ALL

SELECT 'Strength',
    MAX(CASE WHEN p.player_name ILIKE '%messi%'             THEN pa.strength END),
    MAX(CASE WHEN p.player_name ILIKE '%cristiano ronaldo%' THEN pa.strength END)
FROM player_attributes pa
JOIN player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name ILIKE '%Lionel Messi%' OR p.player_name ILIKE '%Cristiano Ronaldo%'

UNION ALL

SELECT 'Heading accuracy',
    MAX(CASE WHEN p.player_name ILIKE '%messi%'             THEN pa.heading_accuracy END),
    MAX(CASE WHEN p.player_name ILIKE '%cristiano ronaldo%' THEN pa.heading_accuracy END)
FROM player_attributes pa
JOIN player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name ILIKE '%Lionel Messi%' OR p.player_name ILIKE '%Cristiano Ronaldo%';
*/