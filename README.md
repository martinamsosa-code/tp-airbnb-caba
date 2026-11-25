# Airbnb en CABA: precio, perfiles, territorio e ingreso

Trabajo práctico integrador · **Ciencia de Datos para Economía y Negocios** (FCE-UBA, 2.º cuatrimestre 2026) · Docente: Nicolás Sidicaro · **Grupo 2**

## 1. Integrantes

- Martina Sosa
- Ciro López Pavía

## 2. Objetivo e hipótesis

**Objetivo:** describir cómo se organiza la oferta de Airbnb en la Ciudad de Buenos Aires y si las diferencias entre barrios que se ven en el precio se mantienen cuando se mira el ingreso que generan las publicaciones.

**Hipótesis de trabajo**

> El mercado de Airbnb en CABA no es homogéneo: el precio difiere entre barrios aun entre viviendas del mismo tamaño, los perfiles más profesionalizados se concentran en el corredor premium, y la brecha entre barrios es aún mayor en el ingreso anual estimado. Además, los segmentos con menor ingreso no lo compensan con menos riesgo: tienen más viviendas sin ingreso.

| Pregunta | Método |
|---|---|
| ¿El precio medio difiere entre barrios, más allá del tamaño? | ANOVA de un factor + Welch, Kruskal-Wallis y Tukey (inferencia) |
| ¿Hay perfiles de publicación diferenciados y se reparten igual en la ciudad? | k-means + chi-cuadrado, V de Cramér, HHI y cociente de localización (cuantitativo) |
| ¿La diferencia de precio se mantiene en el ingreso? ¿Un menor ingreso se compensa con menos riesgo? | Indicadores por segmento indexados a Palermo = 100, Kruskal-Wallis, chi-cuadrado y Spearman (síntesis riesgo-retorno) |

El trabajo es **descriptivo y de asociación, no causal**.

**Cambios respecto de la instancia 1:** se mantuvo la hipótesis de diferencias entre barrios y se precisó en tres partes. El análisis de riesgo-retorno que planteamos desde el inicio (y que el docente aprobó) se resolvió sin precio de compra: el retorno es el ingreso bruto anual estimado y el riesgo, la proporción de publicaciones sin ingreso y la dispersión del ingreso dentro de cada segmento.

## 3. Base de datos

- **Fuente:** [Inside Airbnb](https://insideairbnb.com/get-the-data/), Buenos Aires, archivo `listings.csv.gz` (detallado). Relevamiento del 29/06/2026 al 02/07/2026. Inside Airbnb publica un relevamiento por trimestre.
- **Unidad de observación:** una publicación (anuncio) de Airbnb.
- **Dimensiones:** 29.685 publicaciones × 90 variables en la base original. Usamos 17 variables.
- **Período:** foto del mercado a julio de 2026; reseñas, ocupación e ingreso se refieren a los 12 meses previos.
- **Auxiliar:** `auxiliar/neighbourhoods.geojson` (límites de los 48 barrios, de la misma fuente), solo para los mapas. No se hacen joins que pierdan observaciones.
- **Limitaciones:** es *web scraping* de lo publicado; la ocupación y el ingreso son estimaciones de Inside Airbnb a partir de las reseñas; no hay costos ni valor de la vivienda.

## 4. Análisis realizado

1. **Limpieza:** 29.685 → 29.471 (se quitan 214 precios mayores a $1.000.000, error de carga) → 27.679 (se quitan 1.792 sin precio publicado).
2. **Faltantes y outliers:** la calificación falta en las publicaciones sin reseñas (faltante estructural); la falta de precio se concentra en calendarios cerrados. Outliers de precio con la regla de Tukey (1,5 × RIC) sobre log(precio): se marcan, se mantienen y se repiten los métodos sin ellos.
3. **ANOVA** del log(precio) por barrio (viviendas completas, 22 grupos).
4. **k-means** (k = 6) y relación de los perfiles con el territorio.
5. **Riesgo-retorno** por barrio y por segmento barrio × capacidad (64 segmentos con 30 o más viviendas).

## 5. Estructura del repositorio

```
proyecto_tp/
├── raw/              listings.csv.gz original (no se modifica)
├── auxiliar/         neighbourhoods.geojson
├── input/            bases procesadas (.rds) que generan los scripts
├── output/
│   ├── tablas/       tablas de resultados (.csv)
│   └── graficos/     gráficos (.png y los .jpg de la instancia 3);
│                     en graficos/ppt/ la versión sin título para las diapositivas
├── script/           00 a 07, en orden de ejecución
├── utils/            funciones propias, una por archivo
├── proyecto.Rproj
└── README.md
```

## 6. Cómo reproducirlo

1. Clonar el repositorio y abrir `proyecto.Rproj` en RStudio (así `here()` encuentra la raíz).
2. Instalar los paquetes una sola vez, desde la consola:
   ```r
   install.packages(c("dplyr", "tidyr", "readr", "stringr", "ggplot2", "ggrepel", "scales", "car", "cluster", "sf", "here"))
   ```
3. Correr `script/00_correr_todo.R`. Recrea todo `input/` y `output/` a partir de `raw/` (tarda unos minutos, sobre todo el clustering).

Cada script guarda sus resultados y el siguiente los lee del archivo, así que también se pueden correr de a uno, en orden.

| Script | Qué hace | Lee | Genera |
|---|---|---|---|
| `01_carga_limpieza.R` | Lee la base, convierte tipos (precio de texto a número, baños desde el texto), filtra y registra el flujo de casos | `raw/listings.csv.gz` | `input/listings_con_nulos.rds`, `input/listings_limpio.rds`, `flujo_casos.csv` |
| `02_faltantes_outliers.R` | Diagnóstico de faltantes (cuántos y dónde) y outliers de precio (Tukey sobre log) | `listings_con_nulos.rds`, `listings_limpio.rds` | `nulos_*.csv`, `outliers_*.csv`, `nulos_por_variable.png`, `histograma_precio_log.png`, `input/listings_analisis.rds` |
| `03_descriptivas.R` | Tablas descriptivas numéricas, categóricas, por tipo y por barrio; comparación antes y después de la limpieza | `listings_analisis.rds`, `listings_con_nulos.rds`, `raw/listings.csv.gz` | `descriptivas_*.csv`, `boxplot_precio_barrio.png`, `descriptivas_antes_despues.png` |
| `03b_exploratorio_entrega1.R` | Reproduce los números y gráficos de la instancia 1 | `listings_con_nulos.rds`, `listings_limpio.rds` | `eda1_*.csv`, `eda1_*.png` |
| `04_anova.R` | ANOVA, supuestos, Welch, Kruskal-Wallis, Tukey, η², estratos de capacidad, sensibilidad | `listings_analisis.rds` | `anova_*.csv`, `anova_*.png` |
| `05_clustering.R` | k-means, perfiles, chi-cuadrado, V de Cramér, HHI, cociente de localización, mapas, sensibilidad | `listings_analisis.rds`, `neighbourhoods.geojson` | `cluster_*.csv`, `cluster_*.png`, `input/listings_clusters.rds` |
| `06_graficos_instancia3.R` | Gráfico exploratorio (heatmap del cociente de localización normalizado) y comunicativo (precio por barrio con Palermo como referencia), con la devolución de la instancia 3 | `listings_clusters.rds`, `listings_analisis.rds`, `anova_tukey_vs_palermo.csv` | `grupo_02_exploratorio.jpg`, `grupo_02_comunicativo.jpg` |
| `07_riesgo_retorno.R` | Ingreso anual estimado, índices con Palermo = 100, riesgo por segmento, pruebas y robustez | `listings_analisis.rds` | `rr_*.csv`, `rr_indice_precio_ingreso.png`, `rr_mapa_segmentos.png` |

**Funciones propias (`utils/`):** `limpiar_precio`, `marcar_outliers_iqr`, `tabla_descriptiva`, `indice_rand_ajustado`, `tema_graficos`, `guardar_grafico`, `resumir_ingreso`.

**Nota técnica:** en Windows, si los acentos de los gráficos salen mal, correr antes `Sys.setlocale("LC_ALL", "Spanish_Argentina.utf8")`. Se usa `dplyr::recode()` explícito porque el paquete `car` también tiene una función `recode()`.

## 7. Conclusiones principales

- **Precio:** el precio medio por noche difiere entre barrios (ANOVA: F(21; 24.926) = 78,9, p < 0,001), con un efecto moderado (η² = 0,06) que se mantiene dentro de cada tramo de capacidad. Solo Puerto Madero cobra claramente más que Palermo (+64%); 17 de 21 barrios cobran significativamente menos.
- **Perfiles y territorio:** hay seis perfiles de publicación (silueta 0,198: grupos superpuestos, segmentación descriptiva). Su asociación con el barrio es débil (V de Cramér = 0,10), pero los perfiles más profesionalizados están más concentrados (HHI ≈ 0,19 vs 0,147 de la oferta total) y sobrerrepresentados en el corredor premium.
- **Ingreso:** la brecha con Palermo se agranda al pasar del precio al ingreso. Fuera del corredor premium el precio mediano es 15–25% menor y el ingreso, 30–70% menor, porque además se ocupan menos noches. Colegiales cobra igual que Palermo e ingresa 35% menos.
- **Riesgo-retorno:** entre segmentos de igual tamaño, más ingreso viene con menos publicaciones sin ingreso, no con más (Spearman ρ = −0,47, p < 0,001; se mantiene con otro umbral, otra medida de riesgo y sin outliers). La única excepción visible es Puerto Madero en departamentos de 1–2 personas: tiene el mayor ingreso del tramo, pero el 27% de sus viviendas no registró ingreso (mediana del tramo: 24%).
- Son asociaciones observadas en una foto del mercado: no identifican causas ni miden rentabilidad.

