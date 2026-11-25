# =============================================================================
# 03b_exploratorio_entrega1.R
# Qué hace : reproduce el análisis exploratorio de la PRIMERA ENTREGA (gráficos y
#            números de las diapositivas 7 a 11) a partir de los datos crudos.
# Lee      : input/listings_con_nulos.rds  (29.471 publicaciones, tras sacar precios > $1.000.000)
#            input/listings_limpio.rds     (27.679 publicaciones con precio)
#            raw/listings.csv.gz           (solo para property_type y host_listings_count)
# Genera   : output/tablas/eda1_hallazgos.csv, eda1_precio_rangos.csv,
#            eda1_tipo_alquiler.csv, eda1_precio_capacidad.csv, eda1_top10_barrios.csv,
#            eda1_correlaciones.csv
#            output/graficos/eda1_precio_rangos.png, eda1_tipo_alquiler.png,
#            eda1_precio_capacidad.png, eda1_top10_barrios.png
#
# Nota: los porcentajes de oferta (tipo de alquiler, barrios, anfitriones, reseñas) se
# calculan sobre las 29.471 publicaciones; las estadísticas de precio, sobre las que
# tienen precio (27.679), igual que en la primera entrega.
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(here)

source(here("utils", "tema_graficos.R"))
source(here("utils", "guardar_grafico.R"))

base      <- readRDS(here("input", "listings_con_nulos.rds"))   # 29.471
con_precio <- readRDS(here("input", "listings_limpio.rds"))     # 27.679

# Dos variables de la base original que no guardamos en 01: tipo de propiedad y
# cantidad de propiedades del anfitrión según su perfil de Airbnb.
extra <- read_csv(here("raw", "listings.csv.gz"), show_col_types = FALSE) |>
  select(id, tipo_propiedad = property_type, props_perfil_host = host_listings_count)
base <- base |> left_join(extra, by = "id")

etiqueta_pesos <- function(x) scales::dollar(x, big.mark = ".", decimal.mark = ",")

# --- 1. Distribución del precio por rangos (diapositiva 7) --------------------
cortes_rango <- c(0, 5e4, 1e5, 1.5e5, 2e5, 3e5, 5e5, 1e6)
nombres_rango <- c("0–50k", "50–100k", "100–150k", "150–200k", "200–300k", "300–500k", "500k–1M")

precio_rangos <- con_precio |>
  mutate(rango = cut(precio, cortes_rango, labels = nombres_rango)) |>
  count(rango) |>
  mutate(pct = round(n / sum(n) * 100, 1))
print(precio_rangos)

g1 <- ggplot(precio_rangos, aes(x = rango, y = n)) +
  geom_col(fill = colores["azul"], width = 0.75) +
  scale_y_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ",")) +
  labs(title = "Cantidad de publicaciones por rango de precio por noche",
       subtitle = paste0("Mediana ", etiqueta_pesos(median(con_precio$precio)),
                         " · media ", etiqueta_pesos(round(mean(con_precio$precio)))),
       x = "Precio por noche (ARS)", y = "Publicaciones") +
  tema_graficos()
guardar_grafico(g1, "eda1_precio_rangos", 9, 5)

# --- 2. Precio y oferta según tipo de alquiler (diapositiva 8) ----------------
tipo_alquiler <- base |>
  count(tipo_alquiler, name = "publicaciones") |>
  mutate(pct_oferta = round(publicaciones / sum(publicaciones) * 100, 1)) |>
  left_join(con_precio |> group_by(tipo_alquiler) |>
              summarise(precio_mediano = median(precio)), by = "tipo_alquiler") |>
  arrange(desc(publicaciones))
print(tipo_alquiler)

g2 <- ggplot(tipo_alquiler, aes(x = precio_mediano,
                                y = reorder(tipo_alquiler, precio_mediano))) +
  geom_col(fill = colores["verde"], width = 0.65) +
  geom_text(aes(label = paste0(format(pct_oferta, decimal.mark = ","), "% de la oferta")),
            hjust = -0.1, colour = colores["gris"], size = 4) +
  scale_x_continuous(labels = etiqueta_pesos, expand = expansion(mult = c(0, 0.35))) +
  labs(title = "Precio mediano por noche según tipo de alquiler",
       subtitle = "La etiqueta indica qué parte de la oferta representa cada tipo",
       x = "Precio mediano (ARS)", y = NULL) +
  tema_graficos()
guardar_grafico(g2, "eda1_tipo_alquiler", 9, 4.5)

# --- 3. Precio promedio según capacidad (diapositiva 9) -----------------------
precio_capacidad <- con_precio |>
  mutate(capacidad_g = if_else(capacidad > 8, "8+", as.character(capacidad)),
         capacidad_g = factor(capacidad_g, levels = c(1:8, "8+"))) |>
  group_by(capacidad_g) |>
  summarise(n = n(), precio_promedio = round(mean(precio)))
print(precio_capacidad)

g3 <- ggplot(precio_capacidad, aes(x = capacidad_g, y = precio_promedio, group = 1)) +
  geom_line(colour = colores["tinta"], linewidth = 0.8) +
  geom_point(colour = colores["tinta"], size = 2.5) +
  scale_y_continuous(labels = etiqueta_pesos, limits = c(0, NA)) +
  labs(title = "Precio promedio por noche según capacidad",
       x = "Capacidad (huéspedes)", y = "Precio promedio (ARS)") +
  tema_graficos()
guardar_grafico(g3, "eda1_precio_capacidad", 9, 5)

# Correlaciones de Pearson con el precio. Como en la primera entrega, se calculan
# sobre las publicaciones con calificación (casos completos: 24.390), porque la
# calificación tiene nulos. Con todas las publicaciones, precio-capacidad da 0,52.
completos <- con_precio |> filter(!is.na(calificacion))
correlaciones <- tibble(
  variable = c("Capacidad", "Calificación", "Cantidad de reseñas"),
  r = c(cor(completos$precio, completos$capacidad),
        cor(completos$precio, completos$calificacion),
        cor(completos$precio, completos$resenias)),
  n = nrow(completos)) |>
  mutate(r = round(r, 2))
print(correlaciones)

# --- 4. Top 10 de barrios por cantidad de publicaciones (diapositiva 10) ------
top10 <- base |>
  count(barrio, name = "publicaciones") |>
  mutate(pct = round(publicaciones / sum(publicaciones) * 100, 1)) |>
  arrange(desc(publicaciones)) |>
  slice_head(n = 10)
print(top10)

g4 <- ggplot(top10, aes(x = publicaciones, y = reorder(barrio, publicaciones))) +
  geom_col(fill = colores["azul"], width = 0.7) +
  scale_x_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ",")) +
  labs(title = "Los 10 barrios con más publicaciones",
       subtitle = paste0("Palermo concentra el ", format(top10$pct[1], decimal.mark = ","), "% de la oferta"),
       x = "Publicaciones", y = NULL) +
  tema_graficos()
guardar_grafico(g4, "eda1_top10_barrios", 9, 5.5)

# --- 5. Los cinco hallazgos en números (diapositiva 11) -----------------------
# Anfitriones: host_listings_count es la cantidad de propiedades que figura en el
# perfil del anfitrión (puede incluir otras ciudades). Es la variable que usamos en
# la primera entrega; los porcentajes son sobre publicaciones, no sobre anfitriones.
hallazgos <- tibble(
  hallazgo = c(
    "% vivienda completa",
    "% departamentos o condos enteros",
    "% de la oferta en Palermo",
    "% en Palermo + Recoleta + San Nicolás",
    "% de publicaciones de anfitriones con 1 propiedad",
    "% de publicaciones de anfitriones con 10 o más",
    "Correlación precio-capacidad",
    "Correlación precio-calificación",
    "Correlación precio-reseñas",
    "% de publicaciones sin reseñas",
    "% de nulos en calificación",
    "Calificación mediana",
    "Precio mediano",
    "Precio promedio",
    "% con precio entre $50.000 y $100.000"),
  valor = c(
    mean(base$tipo_alquiler == "Vivienda completa") * 100,
    mean(grepl("^Entire (rental unit|condo)", base$tipo_propiedad)) * 100,
    top10$pct[1],
    sum(top10$publicaciones[1:3]) / nrow(base) * 100,
    mean(base$props_perfil_host == 1, na.rm = TRUE) * 100,
    mean(base$props_perfil_host >= 10, na.rm = TRUE) * 100,
    correlaciones$r[1], correlaciones$r[2], correlaciones$r[3],
    mean(base$resenias == 0) * 100,
    mean(is.na(base$calificacion)) * 100,
    median(base$calificacion, na.rm = TRUE),
    median(con_precio$precio),
    mean(con_precio$precio),
    mean(con_precio$precio > 5e4 & con_precio$precio <= 1e5) * 100)) |>
  mutate(valor = round(valor, 2))
print(hallazgos, n = Inf)

write_csv(precio_rangos,    here("output", "tablas", "eda1_precio_rangos.csv"))
write_csv(tipo_alquiler,    here("output", "tablas", "eda1_tipo_alquiler.csv"))
write_csv(precio_capacidad, here("output", "tablas", "eda1_precio_capacidad.csv"))
write_csv(correlaciones,    here("output", "tablas", "eda1_correlaciones.csv"))
write_csv(top10,            here("output", "tablas", "eda1_top10_barrios.csv"))
write_csv(hallazgos,        here("output", "tablas", "eda1_hallazgos.csv"))
