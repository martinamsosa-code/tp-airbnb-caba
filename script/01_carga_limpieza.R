# =============================================================================
# 01_carga_limpieza.R
# Qué hace : lee la base original de Inside Airbnb (CABA), convierte tipos,
#            aplica los filtros de limpieza y registra el flujo de casos.
# Lee      : raw/listings.csv.gz
# Genera   : input/listings_con_nulos.rds (intermedia, para diagnosticar nulos)
#            input/listings_limpio.rds
#            output/tablas/flujo_casos.csv
# =============================================================================

library(dplyr)
library(readr)
library(here)

source(here("utils", "limpiar_precio.R"))

# --- 1. Lectura de la base original (raw/ no se modifica nunca) --------------
crudo <- read_csv(here("raw", "listings.csv.gz"), show_col_types = FALSE)

# --- 2. Selección de variables y conversión de tipos ------------------------
datos <- crudo |>
  transmute(
    id,
    barrio          = neighbourhood_cleansed,
    latitud         = latitude,
    longitud        = longitude,
    tipo_alquiler   = dplyr::recode(room_type,
                             "Entire home/apt" = "Vivienda completa",
                             "Private room"    = "Habitación privada",
                             "Shared room"     = "Habitación compartida",
                             "Hotel room"      = "Hotel"),
    capacidad       = accommodates,
    dormitorios     = bedrooms,
    # bathrooms viene vacío en 3.420 casos, pero en 3.400 el dato está en el texto ("1.5 baths")
    banios          = coalesce(bathrooms,
                               if_else(grepl("half", bathrooms_text, ignore.case = TRUE), 0.5,
                                       suppressWarnings(parse_number(bathrooms_text)))),
    precio          = limpiar_precio(price),
    estadia_minima  = minimum_nights,
    resenias        = number_of_reviews,
    resenias_12m    = number_of_reviews_ltm,
    resenias_mes    = reviews_per_month,
    calificacion    = review_scores_rating,
    disponibilidad  = availability_365,
    ocupacion       = estimated_occupancy_l365d,   # noches ocupadas estimadas (últ. 365 días)
    superhost       = host_is_superhost,
    props_anfitrion = calculated_host_listings_count
  )

# --- 3. Filtros, guardando cuántos casos quedan en cada paso -----------------
flujo <- tibble(paso = "Base original", n = nrow(datos))

# 3a. Precios imposibles: más de $1.000.000 por noche (≈10 veces la mediana).
#     Llegan a $171 millones por noche: lo tratamos como error de carga
#     (probablemente precios de estadía total o mensual). Mismo criterio que en la 1ª entrega.
datos <- datos |> filter(is.na(precio) | precio <= 1e6)
flujo <- add_row(flujo, paso = "Sin precios > $1.000.000 (error de carga)", n = nrow(datos))

# Guardamos esta versión intermedia (todavía con nulos) para diagnosticar faltantes en 02
saveRDS(datos, here("input", "listings_con_nulos.rds"))

# 3b. Publicaciones sin precio: no tienen oferta activa (ver 02_faltantes_outliers.R).
#     El precio es la variable central del análisis, no se imputa.
datos <- datos |> filter(!is.na(precio))
flujo <- add_row(flujo, paso = "Sin publicaciones sin precio publicado", n = nrow(datos))

# 3c. Nulos estructurales: sin reseñas => reseñas por mes = 0 (no es un dato perdido)
datos <- datos |> mutate(resenias_mes = if_else(resenias == 0, 0, resenias_mes))

flujo <- flujo |> mutate(excluidos = lag(n) - n, pct_del_original = round(n / first(n) * 100, 1))
print(flujo)

# --- 4. Guardado --------------------------------------------------------------
saveRDS(datos, here("input", "listings_limpio.rds"))
write_csv(flujo, here("output", "tablas", "flujo_casos.csv"))
