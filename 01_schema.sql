-- ============================================================
-- European Soccer Database — Schema constraints & indexes
-- ============================================================
-- Este script añade claves primarias, claves foráneas e índices
-- sobre las 7 tablas migradas desde SQLite, asegurando integridad
-- referencial y rendimiento en joins/filtros habituales.
--
-- Orden de ejecución:
--   1. Limpieza de filas huérfanas (previo a FKs)
--   2. Primary Keys
--   3. Unique constraints sobre claves naturales
--   4. Foreign Keys
--   5. Índices de rendimiento
-- ============================================================


-- ------------------------------------------------------------
-- 1. LIMPIEZA PREVIA
-- ------------------------------------------------------------
-- Las FKs fallarán si hay valores huérfanos. Eliminamos filas
-- de match que referencian equipos inexistentes (si las hubiera).

DELETE FROM match
WHERE home_team_api_id NOT IN (SELECT team_api_id FROM team)
   OR away_team_api_id NOT IN (SELECT team_api_id FROM team);

DELETE FROM player_attributes
WHERE player_api_id NOT IN (SELECT player_api_id FROM player);

DELETE FROM team_attributes
WHERE team_api_id NOT IN (SELECT team_api_id FROM team);


-- ------------------------------------------------------------
-- 2. PRIMARY KEYS
-- ------------------------------------------------------------

ALTER TABLE country            ADD PRIMARY KEY (id);
ALTER TABLE league             ADD PRIMARY KEY (id);
ALTER TABLE team               ADD PRIMARY KEY (id);
ALTER TABLE player             ADD PRIMARY KEY (id);
ALTER TABLE match              ADD PRIMARY KEY (id);
ALTER TABLE player_attributes  ADD PRIMARY KEY (id);
ALTER TABLE team_attributes    ADD PRIMARY KEY (id);


-- ------------------------------------------------------------
-- 3. UNIQUE CONSTRAINTS sobre claves naturales
-- ------------------------------------------------------------
-- team_api_id y player_api_id son los identificadores externos
-- (API de fútbol original). Los usamos para los JOINs porque
-- así viene diseñado el dataset.

ALTER TABLE team    ADD CONSTRAINT uq_team_api_id    UNIQUE (team_api_id);
ALTER TABLE player  ADD CONSTRAINT uq_player_api_id  UNIQUE (player_api_id);


-- ------------------------------------------------------------
-- 4. FOREIGN KEYS
-- ------------------------------------------------------------

-- league → country
ALTER TABLE league
    ADD CONSTRAINT fk_league_country
    FOREIGN KEY (country_id) REFERENCES country(id);

-- match → country, league, team (local y visitante)
ALTER TABLE match
    ADD CONSTRAINT fk_match_country
    FOREIGN KEY (country_id) REFERENCES country(id);

ALTER TABLE match
    ADD CONSTRAINT fk_match_league
    FOREIGN KEY (league_id) REFERENCES league(id);

ALTER TABLE match
    ADD CONSTRAINT fk_match_home_team
    FOREIGN KEY (home_team_api_id) REFERENCES team(team_api_id);

ALTER TABLE match
    ADD CONSTRAINT fk_match_away_team
    FOREIGN KEY (away_team_api_id) REFERENCES team(team_api_id);

-- player_attributes → player
ALTER TABLE player_attributes
    ADD CONSTRAINT fk_player_attr_player
    FOREIGN KEY (player_api_id) REFERENCES player(player_api_id);

-- team_attributes → team
ALTER TABLE team_attributes
    ADD CONSTRAINT fk_team_attr_team
    FOREIGN KEY (team_api_id) REFERENCES team(team_api_id);


-- ------------------------------------------------------------
-- 5. ÍNDICES DE RENDIMIENTO
-- ------------------------------------------------------------
-- Postgres crea índices automáticamente para PKs y UNIQUEs,
-- pero NO para columnas con FK. Los creamos manualmente sobre
-- las columnas que usaremos con más frecuencia en WHERE/JOIN.

-- Match: la tabla más consultada
CREATE INDEX idx_match_season        ON match (season);
CREATE INDEX idx_match_date          ON match (date);
CREATE INDEX idx_match_league_id     ON match (league_id);
CREATE INDEX idx_match_country_id    ON match (country_id);
CREATE INDEX idx_match_home_team     ON match (home_team_api_id);
CREATE INDEX idx_match_away_team     ON match (away_team_api_id);

-- Índice compuesto para queries típicas "liga + temporada"
CREATE INDEX idx_match_league_season ON match (league_id, season);

-- Player attributes: consultas por jugador y por fecha
CREATE INDEX idx_player_attr_player  ON player_attributes (player_api_id);
CREATE INDEX idx_player_attr_date    ON player_attributes (date);

-- Team attributes: idem
CREATE INDEX idx_team_attr_team      ON team_attributes (team_api_id);
CREATE INDEX idx_team_attr_date      ON team_attributes (date);

-- League: filtro por país
CREATE INDEX idx_league_country      ON league (country_id);


-- ============================================================
-- FIN
-- ============================================================