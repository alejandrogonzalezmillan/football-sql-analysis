# Football SQL Analysis — European Soccer Database (2008–2016)

Análisis exhaustivo en **PostgreSQL** de más de 25.000 partidos de las 11 grandes ligas europeas entre 2008 y 2016. El proyecto cubre 14 queries analíticas con progresión pedagógica clara: desde joins básicos y agregación condicional hasta patrones avanzados como *gaps and islands*, pivotes manuales y window functions temporales (`LAG`, `FIRST_VALUE`, `SUM OVER`).

**Stack:** PostgreSQL 16 · DBeaver · pgloader · Git

---

## TL;DR

Reconstrucción completa del fútbol europeo 2008–2016 a partir de datos brutos, demostrando el repertorio técnico de SQL que se espera en una entrevista de Data Analyst senior. Tres historias clave que los datos cuentan por sí solos:

1. **El ADN del tiki-taka del Barça queda confirmado numéricamente.** Velocidad de construcción media 35.8 — la más baja entre los grandes europeos. Ajax, su hermano holandés bajo la filosofía Cruyff, tiene velocidad casi idéntica (35.2).
2. **La llegada de Guardiola al Bayern (verano 2013) es detectable en los datos tácticos.** Entre 2013 y 2014: velocidad de construcción -19 puntos, presión +9. Dos años después la presión llega a 72, de las más altas de todo el dataset.
3. **Messi supera a Cristiano en 2009 y nunca más vuelve a estar por debajo.** La diferencia de rating FIFA año a año dibuja una montaña invertida perfecta: -5 → -1 → +1 → +1 → +2 → +2 → +2 → +1 → +1.

---

## Dataset

**European Soccer Database** publicado por Hugo Mathien en Kaggle.

| Característica | Valor |
|---|---|
| Cobertura temporal | 2008/09 – 2015/16 (8 temporadas) |
| Ligas incluidas | 11 |
| Partidos | ~25.000 |
| Jugadores | ~11.000 |
| Equipos | ~300 |
| Snapshots FIFA (ratings jugadores) | ~180.000 |
| Snapshots tácticos (equipos) | ~1.500 |

Las 11 ligas son Premier League, La Liga, Serie A, Bundesliga, Ligue 1, Eredivisie, Primeira Liga, Scottish Premier, Jupiler League belga, Ekstraklasa polaca y Super League suiza.

El dataset original viene en **SQLite**. El proyecto incluye la migración a PostgreSQL con tipos corregidos, 7 primary keys, 2 UNIQUE constraints, 7 foreign keys y 13 índices.

---

## Estructura del repositorio

```
football-sql-analysis/
├── README.md                              Este documento
├── 01_schema.sql                          PKs, FKs, UNIQUE e índices
└── queries/
    ├── 01_panorama_por_liga.sql           Nivel 1: fundamentos
    ├── 02_top_equipos_ganadores.sql
    ├── 03_fortalezas_en_casa.sql
    ├── 04_goleadas_historicas.sql
    ├── 05_goleadores_vs_defensivos.sql
    ├── 06_factor_espectaculo.sql
    ├── 07_clasificacion_por_temporada.sql Nivel 2: window functions
    ├── 08_diferencia_con_campeon.sql
    ├── 09_clasificacion_jornada_a_jornada.sql
    ├── 10_rachas_ganadoras.sql            Nivel 3: gaps and islands
    ├── 11_rachas_invictas.sql
    ├── 12_el_clasico.sql                  Nivel 4: narrativa y pivotes
    ├── 13_messi_vs_cristiano.sql
    └── 14_evolucion_tactica.sql           Nivel 5: análisis temporal avanzado
```

---

## Las 14 queries

Cada fichero contiene documentación extensa en los comentarios con la intuición del algoritmo, las técnicas SQL empleadas y la narrativa deportiva detrás.

### Nivel 1 — Fundamentos: JOIN + agregación condicional

**Q01 · Panorama por liga**
Partidos totales, goles, porcentaje de victorias locales vs visitantes en cada una de las 11 ligas. Multi-join `match + league + country`, `SUM(CASE WHEN ...)` para agregación condicional, `COUNT(DISTINCT ...)`.

**Q02 · Top 10 equipos más ganadores de Europa**
Reshape de ancho a largo con `UNION ALL` (una fila por partido-equipo desde ambas perspectivas, local y visitante). `COUNT(*) FILTER (WHERE ...)` — sintaxis limpia de Postgres para contar condicionalmente. Filtro mínimo de trayectoria con `HAVING`.

**Q03 · Fortalezas en casa**
Qué equipos sacan más ventaja de jugar como locales. Dos CTEs encadenadas (una para estadísticas locales, otra para visitante), join por `team_api_id`. Métrica derivada: `gap = % victorias casa - % victorias fuera`.

**Q04 · Las 15 goleadas más brutales**
Partidos con diferencia de 6+ goles. Auto-join triple sobre `match` con alias `home/away`, concatenación con `||` para construir marcador legible.

**Q05 · Goleadores vs equipos defensivos**
Ranking por goles marcados por partido. Dos CTEs encadenadas, `AVG` sobre expresiones derivadas (`goles_favor - goles_contra`).

**Q06 · Factor espectáculo**
Equipos cuyos partidos son más entretenidos (más goles totales por encuentro). KPI `over 2.5` de la industria de las apuestas. Métrica `pct_0_0` (porcentaje de partidos sin goles).

### Nivel 2 — Window functions

**Q07 · Clasificación completa por temporada**
Reconstruye las clasificaciones de las 11 ligas en las 8 temporadas. Primer uso de `RANK() OVER (PARTITION BY league_id, season ORDER BY puntos DESC, diferencia_goles DESC, goles_favor DESC)` con reglas de desempate oficiales de FIFA/UEFA. Resultado: 88 filas (11 ligas × 8 temporadas × top 3).

**Q08 · Diferencia con el campeón**
Las 15 temporadas más ajustadas de Europa. `FIRST_VALUE() OVER` con frame explícito `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` para identificar al campeón de cada partición y calcular la diferencia de puntos del resto.

**Q09 · Clasificación jornada a jornada: La Liga 2013/14**
Running total con `SUM() OVER (PARTITION BY team ORDER BY stage ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`. Combinado con `RANK() OVER (PARTITION BY stage)` para obtener la posición en cada jornada. Temporada legendaria del Atlético de Simeone rompiendo el duopolio Barça–Madrid.

### Nivel 3 — Patrones avanzados: gaps and islands

**Q10 · Rachas ganadoras consecutivas más largas**
Implementación del patrón **gaps and islands** (Itzik Ben-Gan, 2009), la pregunta SQL más recurrente en entrevistas técnicas de Data Analyst senior en FAANG. Dual `ROW_NUMBER` con dos particiones distintas sobre la misma tabla; la diferencia entre ambos identifica cada isla de victorias consecutivas. Algoritmo O(n log n), portable a cualquier motor con window functions.

**Q11 · Rachas invictas (partidos sin perder)**
Reutiliza el patrón de gaps and islands modificando la condición que rompe la racha: ahora solo las derrotas la interrumpen (los empates la continúan). Demuestra cómo un mismo patrón SQL resuelve preguntas de negocio distintas con cambios mínimos.

### Nivel 4 — Narrativa y pivotes

**Q12 · El Clásico histórico (Barça vs Real Madrid)**
Todos los enfrentamientos de liga entre los dos clubes, con marcador formateado, ganador y estadio. Multi-join con dos alias de `team`, `CASE` con condiciones desde ambas perspectivas (local y visitante).

**Q13 · Messi vs Cristiano Ronaldo: evolución del rating FIFA**
Pivote manual de formato largo a ancho con `MAX(CASE WHEN player_name ILIKE '%messi%' THEN rating END)`. Patrón portable que funciona en cualquier motor SQL (Postgres no tiene `PIVOT` nativo). `EXTRACT(YEAR FROM date::timestamp)` + `ROW_NUMBER` para quedarse con el último rating de cada año.

### Nivel 5 — Análisis temporal avanzado

**Q14 · Evolución táctica: el ADN de los grandes equipos**
Combina `LAG()` para comparar cada año con el anterior, y `AVG() OVER (PARTITION BY team)` sin `ORDER BY` para obtener la media histórica del equipo en la misma fila. Detecta cambios tácticos bruscos (≥15 puntos en velocidad o presión) que suelen coincidir con cambios de entrenador. Técnica transferible a cualquier dominio temporal: finanzas (crecimiento YoY), producto (cohortes), IoT (deltas entre lecturas).

---

## Hallazgos destacados

**Rachas invictas: el Porto de Villas-Boas es infernal**
Porto lidera con una racha de 55 partidos sin perder (687 días). Le siguen Porto otra vez (53), Bayern (53) y la Juventus de Conte (46 — la famosa temporada invicta 2011/12).

**16 Clásicos, dominio azulgrana**
De los 16 Barça–Madrid del dataset: 10 victorias para Barça, 4 para Real Madrid, 2 empates. 58 goles totales, media de 3.6 goles por Clásico.

**Compra qatarí del PSG detectable en datos tácticos**
Entre 2010 y 2011 (año de la compra por QSI), la presión del PSG baja 25 puntos. El cambio de dueño cambia el estilo de juego antes incluso que la plantilla.

**Cambio de estilo más extremo del dataset: Arsenal 2012**
La velocidad de construcción cae 50 puntos en un año (de 75 a 25). Wenger experimentando con un giro radical al tiki-taka, que abandonaría dos años después (+29 puntos de velocidad en 2014).

**Pep Guardiola en su versión más extrema**
Última temporada de Pep en el Barça (2012): la velocidad de construcción toca fondo con 24 puntos — el tiki-taka llevado al límite físico. Después se va, y el Barça nunca volvió a ese nivel de extremismo estilístico.

---

## Cómo reproducir el proyecto

### Requisitos previos

- PostgreSQL 14 o superior
- DBeaver Community (o cualquier cliente SQL)
- El fichero `database.sqlite` del European Soccer Database (descargable desde Kaggle)
- pgloader para la migración

### Pasos

1. **Crear la base de datos en PostgreSQL**

   ```sql
   CREATE DATABASE football;
   ```

2. **Migrar desde SQLite con pgloader**

   ```bash
   pgloader database.sqlite postgresql:///football
   ```

3. **Aplicar el esquema (PKs, FKs, índices)**

   Abrir `01_schema.sql` en DBeaver, seleccionar todo el contenido (`Ctrl+A`) y ejecutar con `Alt+X`. Añade 7 primary keys, 2 UNIQUE constraints, 7 foreign keys y 13 índices, dejando el esquema listo para análisis.

4. **Ejecutar las queries en orden**

   Las queries están numeradas del 01 al 14 y cada una es independiente. Cada fichero contiene la documentación técnica en los comentarios.

---

## Limitaciones conocidas

**Liga belga 2013/14 con datos incompletos**
La Jupiler League de esa temporada solo tiene 6 jornadas en el dataset en lugar de las 30 habituales. KV Oostende aparece como campeón con solo 14 puntos. Detectado en la Query 07 y filtrado en las queries 08, 10 y 11 con `WHERE l.name != 'Belgium Jupiler League'`.

**Tipos de datos en `player_attributes` y `team_attributes`**
La columna `date` se migró como `text` en lugar de `timestamp`. Las queries 13 y 14 aplican el cast explícito `date::timestamp` para poder usar `EXTRACT(YEAR FROM ...)`.

**Nombres de jugadores con variantes**
El dataset contiene variantes y grafías distintas de nombres. La Query 13 usa `ILIKE '%Lionel Messi%'` y `ILIKE '%Cristiano Ronaldo%'` para cubrir posibles variaciones.

**Cobertura limitada a 2008–2016**
El dataset termina en mayo de 2016, por lo que no incluye el Barça de Luis Enrique post-2016, la era Zidane en el Real Madrid, ni la era post-Guardiola del Bayern.

---

## Licencia y atribuciones

### Datos

Los datos analizados en este proyecto proceden del **European Soccer Database** publicado por [Hugo Mathien](https://www.kaggle.com/hugomathien) en Kaggle, bajo licencia **Open Data Commons Open Database License (ODbL) v1.0**.

Este repositorio **no redistribuye el dataset original** — los usuarios deben descargarlo directamente desde Kaggle bajo los términos de la licencia ODbL.

### Código

El código SQL y la documentación de este repositorio están publicados bajo licencia **MIT**, salvo donde se indique lo contrario.

---

## Autor

**Alejandro González Millán**
Graduado en Economía (UGR) · Máster en Modelización y Análisis de Datos Económicos (UCLM)
[LinkedIn](https://linkedin.com/in/alejandrogonzalezmillan) · [GitHub](https://github.com/alejandrogonzalezmillan)