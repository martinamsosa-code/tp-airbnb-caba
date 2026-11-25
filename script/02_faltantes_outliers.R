# =============================================================================
# 02_faltantes_outliers.R
# Qué hace : (a) diagnostica los valores faltantes: cuántos hay y dónde se concentran;
#            (b) detecta outliers de precio con la regla de Tukey sobre log(precio)
#                y describe quiénes son.
# Lee      : input/listings_con_nulos.rds, input/listings_limpio.rds
# Genera   : output/tablas/nulos_por_variable.csv, nulos_precio_concentracion.csv,
#            nulos_dormitorios_capacidad.csv, outliers_precio_resumen.csv,
#            outliers_precio_perfil.csv
#            output/graficos/histograma_precio_log.png
#            input/listings_analisis.rds  (base final con la marca de outlier)
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(here)

source(here("utils", "marcar_outliers_iqr.R"))
source(here("utils", "tema_graficos.R"))
source(here("utils", "guardar_grafico.R"))

con_nulos <- readRDS(here("input", "listings_con_nulos.rds"))   # 29.471 casos
datos     <- readRDS(here("input", "listings_limpio.rds"))      # 27.679 casos

# --- A. FALTANTES -------------------------------------------------------------

# A1. Cuántos nulos tiene cada variable (antes de filtrar)
nulos <- con_nulos |>
  summarise(across(everything(), ~ sum(is.na(.x)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "nulos") |>
  mutate(pct = round(nulos / nrow(con_nulos) * 100, 1)) |>
  arrange(desc(nulos))
print(nulos)

# A2. ¿Dónde se concentran los nulos de precio? Comparamos la tasa de nulos
#     según el calendario esté cerrado (0 días disponibles) o no.
nulos_precio <- con_nulos |>
  mutate(calendario = if_else(disponibilidad == 0, "Cerrado (0 días disponibles)",
                                                   "Abierto (1+ días disponibles)"),
         sin_actividad = if_else(resenias_12m == 0, "Sin reseñas en 12 meses",
                                                     "Con reseñas en 12 meses")) |>
  group_by(calendario) |>
  summarise(publicaciones = n(),
            sin_precio = sum(is.na(precio)),
            pct_sin_precio = round(mean(is.na(precio)) * 100, 1))
print(nulos_precio)

# A3. ¿Dónde se concentran los nulos de dormitorios? Por capacidad.
#     Hipótesis de trabajo: son monoambientes (Airbnb no carga "0 dormitorios").
nulos_dorm <- datos |>
  mutate(cap = if_else(capacidad >= 5, "5+", as.character(capacidad))) |>
  group_by(cap) |>
  summarise(publicaciones = n(),
            pct_sin_dormitorios = round(mean(is.na(dormitorios)) * 100, 1))
print(nulos_dorm)

# Calificación: ¿todos los nulos son publicaciones sin reseñas? (nulo estructural)
cat("Nulos de calificación:", sum(is.na(datos$calificacion)),
    "| de ellos, sin ninguna reseña:", sum(is.na(datos$calificacion) & datos$resenias == 0), "\n")

# A4. Gráfico: % de faltantes por variable y qué decisión se tomó con cada una
nombres_vars <- c(dormitorios = "Dormitorios", calificacion = "Calificación",
                  resenias_mes = "Reseñas por mes", precio = "Precio por noche",
                  banios = "Baños", superhost = "Superhost", estadia_minima = "Estadía mínima")
decision <- c(dormitorios = "No se usa (el tamaño se mide con la capacidad)",
              calificacion = "Faltante estructural: sin reseñas",
              resenias_mes = "Faltante estructural: sin reseñas",
              precio = "Se eliminan (variable central)",
              # baños: 3.420 vacíos en la columna original; 3.400 se recuperan del texto en 01
              banios = "Recuperados del texto (3.400 de 3.420); quedan 20",
              superhost = "Se mantiene", estadia_minima = "Se excluyen solo del k-means (3 casos)")
g_nulos <- nulos |>
  filter(nulos > 0) |>
  mutate(etiqueta = coalesce(nombres_vars[variable], variable),
         decision = coalesce(decision[variable], "Se mantiene")) |>
  ggplot(aes(x = pct, y = reorder(etiqueta, pct), fill = decision)) +
  geom_col(width = 0.65) +
  # Etiqueta con % y cantidad de casos: el % redondeado puede dar 0,0% con casos reales
  geom_text(aes(label = paste0(scales::label_number(accuracy = 0.1, decimal.mark = ",")(pct), "% · ",
                               scales::label_number(big.mark = ".", decimal.mark = ",")(nulos), " casos")),
            hjust = -0.08, size = 3.8,
            colour = colores[["tinta"]]) +
  scale_fill_manual(values = c("Se eliminan (variable central)" = colores[["bordo"]],
                               "Faltante estructural: sin reseñas" = colores[["azul"]],
                               "No se usa (el tamaño se mide con la capacidad)" = colores[["gris"]],
                               "Recuperados del texto (3.400 de 3.420); quedan 20" = colores[["verde"]],
                               "Se excluyen solo del k-means (3 casos)" = colores[["gris_claro"]],
                               "Se mantiene" = colores[["gris_claro"]]), name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.45))) +
  guides(fill = guide_legend(ncol = 2)) +
  labs(title = "Faltantes por variable y decisión tomada",
       subtitle = "Base de 29.471 publicaciones (después de quitar precios mayores a $1.000.000)",
       x = "Publicaciones sin dato (%)", y = NULL,
       caption = "Fuente: elaboración propia con datos de Inside Airbnb (Buenos Aires, jun-jul 2026).") +
  tema_graficos() +
  theme(plot.caption = element_text(colour = colores[["gris"]], size = 9, hjust = 0))
guardar_grafico(g_nulos, "nulos_por_variable", 9, 5, 10, 5.2)

write_csv(nulos,        here("output", "tablas", "nulos_por_variable.csv"))
write_csv(nulos_precio, here("output", "tablas", "nulos_precio_concentracion.csv"))
write_csv(nulos_dorm,   here("output", "tablas", "nulos_dormitorios_capacidad.csv"))

# --- B. OUTLIERS DE PRECIO ----------------------------------------------------

# B1. Comparamos la regla de Tukey sobre el precio en pesos y sobre su logaritmo.
#     El precio es muy asimétrico: en pesos, la regla marca toda la cola derecha.
datos <- datos |>
  mutate(log_precio      = log(precio),
         outlier_pesos   = marcar_outliers_iqr(precio),
         outlier_precio  = marcar_outliers_iqr(log_precio))

resumen_out <- bind_rows(
  datos |> count(criterio = "Tukey sobre precio en pesos", tipo = outlier_pesos),
  datos |> count(criterio = "Tukey sobre log(precio)",     tipo = outlier_precio)
) |> mutate(pct = round(n / nrow(datos) * 100, 1))
print(resumen_out)

# Límites en pesos de la regla aplicada al log (para comunicarlos)
q <- quantile(datos$log_precio, c(.25, .75)); iqr <- diff(q)
limites <- exp(c(inferior = q[[1]] - 1.5 * iqr, superior = q[[2]] + 1.5 * iqr))
print(round(limites))

# B2. ¿Quiénes son los outliers? Si son errores o valores genuinos.
perfil_out <- datos |>
  group_by(outlier_precio) |>
  summarise(n = n(),
            precio_mediano     = median(precio),
            capacidad_mediana  = median(capacidad),
            pct_vivienda_compl = round(mean(tipo_alquiler == "Vivienda completa") * 100, 1),
            pct_hab_priv_comp  = round(mean(tipo_alquiler %in% c("Habitación privada",
                                                                 "Habitación compartida")) * 100, 1),
            pct_puerto_madero  = round(mean(barrio == "Puerto Madero") * 100, 1),
            pct_capacidad_6mas = round(mean(capacidad >= 6) * 100, 1))
print(perfil_out)

write_csv(resumen_out, here("output", "tablas", "outliers_precio_resumen.csv"))
write_csv(perfil_out,  here("output", "tablas", "outliers_precio_perfil.csv"))

# B3. Histograma del log(precio) con los límites de la regla de Tukey
cortes <- c(5e3, 1e4, 3e4, 1e5, 3e5, 1e6)
g <- ggplot(datos, aes(x = log_precio, fill = outlier_precio != "normal")) +
  geom_histogram(bins = 70, colour = "white", linewidth = 0.1) +
  geom_vline(xintercept = log(limites), colour = colores["tinta"], linetype = "dashed") +
  scale_fill_manual(values = c(`FALSE` = colores[["gris_claro"]], `TRUE` = colores[["bordo"]]),
                    labels = c("Dentro del rango", "Atípico (fuera de 1,5 × RIC)"), name = NULL) +
  scale_x_continuous(breaks = log(cortes),
                     labels = scales::dollar(cortes, big.mark = ".", decimal.mark = ",")) +
  labs(title = "Distribución del precio por noche (escala logarítmica)",
       subtitle = "Líneas: límites de la regla de Tukey sobre log(precio)",
       x = "Precio por noche (ARS, escala log)", y = "Publicaciones") +
  tema_graficos()
guardar_grafico(g, "histograma_precio_log", 9, 4.5, 10, 5)

# Decisión: los outliers del log se MANTIENEN (son genuinos) y se marcan para
# poder repetir el ANOVA y el clustering sin ellos (análisis de sensibilidad).
saveRDS(datos, here("input", "listings_analisis.rds"))
