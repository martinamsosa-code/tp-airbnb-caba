# =============================================================================
# 03_descriptivas.R
# Qué hace : tablas de estadísticas descriptivas (pedido de la devolución docente)
#            y gráficos de precio por barrio.
#            Compara las descriptivas antes y después de la limpieza.
# Lee      : input/listings_analisis.rds, input/listings_con_nulos.rds
# Genera   : output/tablas/descriptivas_cuantitativas.csv, descriptivas_categoricas.csv,
#            descriptivas_tipo_alquiler.csv, descriptivas_barrio.csv,
#            descriptivas_antes_despues.csv
#            output/graficos/boxplot_precio_barrio.png, descriptivas_antes_despues.png
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(here)

source(here("utils", "tabla_descriptiva.R"))
source(here("utils", "tema_graficos.R"))
source(here("utils", "guardar_grafico.R"))

datos <- readRDS(here("input", "listings_analisis.rds"))   # 27.679 publicaciones

# --- 1. Variables cuantitativas: posición, dispersión y faltantes ------------
vars_cuanti <- c("precio", "capacidad", "dormitorios", "banios", "estadia_minima",
                 "resenias", "resenias_12m", "calificacion", "disponibilidad",
                 "ocupacion", "props_anfitrion")
desc_cuanti <- tabla_descriptiva(datos, vars_cuanti)
print(desc_cuanti, width = Inf)

# --- 2. Variables categóricas: frecuencias ----------------------------------
desc_categ <- bind_rows(
  datos |> count(variable = "tipo_alquiler", categoria = tipo_alquiler),
  datos |> count(variable = "superhost", categoria = as.character(superhost))
) |>
  group_by(variable) |>
  mutate(pct = round(n / sum(n) * 100, 1)) |>
  arrange(variable, desc(n))
print(desc_categ)

# --- 3. Por tipo de alquiler --------------------------------------------------
desc_tipo <- datos |>
  group_by(tipo_alquiler) |>
  summarise(n = n(),
            precio_mediano = median(precio),
            precio_q1 = quantile(precio, .25),
            precio_q3 = quantile(precio, .75),
            capacidad_mediana = median(capacidad),
            ocupacion_mediana = median(ocupacion)) |>
  arrange(desc(n))
print(desc_tipo)

# --- 4. Por barrio ------------------------------------------------------------
desc_barrio <- datos |>
  group_by(barrio) |>
  summarise(n = n(),
            pct_oferta = round(n / nrow(datos) * 100, 1),
            precio_mediano = median(precio),
            precio_ric = IQR(precio),
            capacidad_mediana = median(capacidad),
            ocupacion_mediana = median(ocupacion)) |>
  arrange(desc(n))
print(desc_barrio, n = 15)

write_csv(desc_cuanti, here("output", "tablas", "descriptivas_cuantitativas.csv"))
write_csv(desc_categ,  here("output", "tablas", "descriptivas_categoricas.csv"))
write_csv(desc_tipo,   here("output", "tablas", "descriptivas_tipo_alquiler.csv"))
write_csv(desc_barrio, here("output", "tablas", "descriptivas_barrio.csv"))

# --- 5. Boxplot de precio por barrio (barrios con 100+ publicaciones) --------
barrios_grandes <- desc_barrio |> filter(n >= 100) |> pull(barrio)
cortes <- c(3e4, 5e4, 1e5, 2e5, 4e5)
g <- datos |>
  filter(barrio %in% barrios_grandes, tipo_alquiler == "Vivienda completa") |>
  ggplot(aes(x = log_precio, y = reorder(barrio, log_precio, median))) +
  geom_boxplot(fill = colores["gris_claro"], colour = colores["tinta"],
               outlier.shape = NA, width = 0.6) +
  scale_x_continuous(breaks = log(cortes),
                     labels = scales::dollar(cortes, big.mark = ".", decimal.mark = ",")) +
  coord_cartesian(xlim = log(c(2.5e4, 5e5))) +
  labs(title = "Precio por noche de viviendas completas por barrio",
       subtitle = "Barrios con 100 o más publicaciones, ordenados por mediana",
       x = "Precio por noche (ARS, escala log)", y = NULL) +
  tema_graficos()
guardar_grafico(g, "boxplot_precio_barrio", 8, 7, 8, 7.5)

# --- 6. Antes y después de la limpieza ---------------------------------------
# Tres versiones de la base: (a) antes de quitar faltantes de precio, (b) la base
# de análisis y (c) la base de análisis sin outliers de precio (sensibilidad).
# Si las medianas casi no se mueven, las decisiones no cambian la foto general.
con_nulos <- readRDS(here("input", "listings_con_nulos.rds"))
# Versión 0: la base original, antes de sacar los precios > $1.000.000 (solo el precio)
source(here("utils", "limpiar_precio.R"))
original <- read_csv(here("raw", "listings.csv.gz"), show_col_types = FALSE,
                     col_select = "price") |>
  mutate(precio = limpiar_precio(price))
vars_comp <- c("precio", "capacidad", "ocupacion", "disponibilidad", "resenias_12m")
versiones <- list(
  "1. Antes (29.471, con faltantes)"    = con_nulos,
  "2. Después: base de análisis"        = datos,
  "3. Después: sin outliers de precio"  = filter(datos, outlier_precio == "normal"))
antes_despues <- bind_rows(
  tabla_descriptiva(original, "precio") |> mutate(version = "0. Original (29.685)", .before = 1),
  bind_rows(lapply(names(versiones), function(v)
    tabla_descriptiva(versiones[[v]], vars_comp) |> mutate(version = v, .before = 1))))
print(antes_despues |> select(version, variable, n, media, mediana, desvio), n = Inf)
write_csv(antes_despues, here("output", "tablas", "descriptivas_antes_despues.csv"))

nombres_comp <- c(precio = "Precio por noche (ARS)", capacidad = "Capacidad (personas)",
                  ocupacion = "Noches ocupadas estimadas (año)",
                  disponibilidad = "Días disponibles (año)", resenias_12m = "Reseñas (últimos 12 meses)")
# Gráfico: cuánto cambia cada medida respecto de la base de análisis (en %).
# Mostrar la diferencia relativa evita que un eje "con zoom" exagere cambios chicos.
# Deja afuera la versión 0: con precios de hasta $171 millones la media del precio
# se más que duplica (el valor está en la tabla).
base_ref <- antes_despues |> filter(version == "2. Después: base de análisis") |>
  select(variable, media_ref = media, mediana_ref = mediana)
g_ad <- antes_despues |>
  filter(version %in% c("1. Antes (29.471, con faltantes)", "3. Después: sin outliers de precio")) |>
  left_join(base_ref, by = "variable") |>
  transmute(version, variable,
            Media   = (media / media_ref - 1) * 100,
            Mediana = (mediana / mediana_ref - 1) * 100) |>
  tidyr::pivot_longer(c(Media, Mediana), names_to = "medida", values_to = "dif") |>
  mutate(variable = factor(nombres_comp[as.character(variable)], levels = rev(nombres_comp)),
         version = sub("^[0-9]\\. ", "", version)) |>
  ggplot(aes(x = dif, y = variable, colour = medida, shape = medida)) +
  annotate("rect", xmin = -5, xmax = 5, ymin = -Inf, ymax = Inf, fill = colores[["linea"]], alpha = 0.5) +
  geom_vline(xintercept = 0, colour = colores[["tinta"]]) +
  geom_point(size = 3.2, position = position_dodge(width = 0.5)) +
  facet_wrap(~ version) +
  scale_x_continuous(labels = function(x) paste0(format(x, decimal.mark = ","), "%"),
                     limits = c(-10, 16), breaks = seq(-10, 15, 5)) +
  scale_colour_manual(values = c(Media = colores[["gris"]], Mediana = colores[["azul"]]), name = NULL) +
  scale_shape_manual(values = c(Media = 1, Mediana = 16), name = NULL) +
  labs(title = "Sacar faltantes no cambia la foto; sacar outliers baja la media del precio",
       subtitle = "Diferencia respecto de la base de análisis (27.679 publicaciones) · franja gris: ±5%",
       x = "Diferencia respecto de la base de análisis (%)", y = NULL,
       caption = "Fuente: elaboración propia con datos de Inside Airbnb (Buenos Aires, jun-jul 2026).") +
  tema_graficos() +
  theme(plot.caption = element_text(colour = colores[["gris"]], size = 9, hjust = 0))
guardar_grafico(g_ad, "descriptivas_antes_despues", 10, 4.8, 10, 4.8)
