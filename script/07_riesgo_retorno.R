# =============================================================================
# 07_riesgo_retorno.R
# Pregunta : la diferencia de precio entre barrios que mostró el ANOVA, ¿se
#            mantiene, se achica o se agranda cuando miramos el ingreso anual
#            estimado? ¿Los segmentos con menor ingreso tienen, a cambio,
#            menos riesgo?
# Método   : indicadores por segmento (barrio y barrio × tamaño) indexados a
#            Palermo = 100; riesgo = % de publicaciones sin ingreso en el año y
#            coeficiente de variación; Kruskal-Wallis y chi-cuadrado como
#            respaldo inferencial; correlación de Spearman entre retorno y riesgo.
#            Chequeos de robustez (otro umbral de n, otra medida de riesgo,
#            sin outliers de precio).
# Lee      : input/listings_analisis.rds
# Genera   : output/tablas/rr_barrio.csv, rr_segmentos.csv, rr_pruebas.csv,
#            rr_robustez.csv, rr_chequeo_ocupacion.csv
#            output/graficos/rr_indice_precio_ingreso.png, rr_mapa_segmentos.png
# Nota     : es una descripción de una foto del mercado (12 meses previos a
#            julio de 2026). No mide rentabilidad ni identifica causas.
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(scales)
library(here)

source(here("utils", "tema_graficos.R"))
source(here("utils", "guardar_grafico.R"))
source(here("utils", "resumir_ingreso.R"))

datos <- readRDS(here("input", "listings_analisis.rds"))

# --- 1. Universo y variable de retorno ---------------------------------------
# Mismo universo que el ANOVA: solo viviendas completas, mismos grupos de barrio.
# Ingreso anual estimado = precio por noche × noches ocupadas estimadas.
# Es la misma cuenta que hace Inside Airbnb en estimated_revenue_l365d
# (lo verificamos: coincide en el 99,98% de los casos). Es ingreso BRUTO:
# no descuenta costos ni considera el valor de la vivienda.
viv <- datos |>
  filter(tipo_alquiler == "Vivienda completa") |>
  mutate(ingreso = precio * ocupacion)

barrios_100 <- viv |> count(barrio) |> filter(n >= 100) |> pull(barrio)
viv <- viv |>
  mutate(barrio_g  = if_else(barrio %in% barrios_100, barrio, "Resto de CABA"),
         # Tramos de tamaño: los del ANOVA, pero 5-6 y 7+ se juntan en "5+"
         # porque si no casi ningún barrio llega a 30 viviendas en esos tramos.
         tramo_cap = cut(capacidad, c(0, 2, 4, Inf), labels = c("1-2", "3-4", "5+")))
cat("Viviendas completas:", nrow(viv), "| sin ingreso en el año:",
    round(mean(viv$ingreso == 0) * 100, 1), "%\n")

# --- 2. Indicadores por barrio, indexados a Palermo = 100 --------------------
# Palermo es la referencia de todo el trabajo: es el barrio con más oferta
# (1 de cada 3 viviendas completas) y por eso su mediana es la más estable.
por_barrio <- viv |> group_by(barrio = barrio_g) |> resumir_ingreso()
ref <- por_barrio |> filter(barrio == "Palermo")
por_barrio <- por_barrio |>
  mutate(indice_precio    = precio_mediano / ref$precio_mediano * 100,
         indice_ocupacion = ocupacion_mediana / ref$ocupacion_mediana * 100,
         indice_ingreso   = ingreso_mediano / ref$ingreso_mediano * 100,
         # ¿la brecha de ingreso es más grande que la de precio? (en puntos del índice)
         brecha_extra     = indice_ingreso - indice_precio) |>
  arrange(desc(indice_ingreso))
print(por_barrio, n = Inf, width = Inf)

# --- 3. Respaldo inferencial ------------------------------------------------
# 3a. ¿El ingreso difiere entre barrios? Kruskal-Wallis y no ANOVA: el ingreso
#     tiene muchos ceros y una cola larga, así que no se acerca a una normal ni
#     con log (log(0) no existe). Kruskal-Wallis compara rangos, no medias.
kw <- kruskal.test(ingreso ~ factor(barrio_g), data = viv)
k <- n_distinct(viv$barrio_g); n <- nrow(viv)
eps2 <- unname((kw$statistic - k + 1) / (n - k))   # épsilon²: tamaño del efecto

# 3b. ¿El % de publicaciones sin ingreso difiere entre barrios? Chi-cuadrado de
#     independencia sobre la tabla barrio × (con ingreso / sin ingreso).
tabla_cero <- table(viv$barrio_g, viv$ingreso == 0)
chi <- chisq.test(tabla_cero)
v_cramer <- sqrt(unname(chi$statistic) / sum(tabla_cero))  # tabla de 2 columnas: min(dim) - 1 = 1
cat("Frecuencias esperadas < 5:", sum(chi$expected < 5), "\n")

# --- 4. Segmentos barrio × tamaño y relación riesgo-retorno ------------------
# Comparar dentro de un mismo tamaño evita que "Palermo ingresa más" sea solo
# "en Palermo hay departamentos más grandes". Solo segmentos con 30+ viviendas.
segmentos_todos <- viv |> group_by(barrio, tramo_cap) |> resumir_ingreso()
segmentos <- segmentos_todos |> filter(n >= 30)
cobertura <- sum(segmentos$n) / nrow(viv) * 100
cat("Segmentos:", nrow(segmentos), "| barrios:", n_distinct(segmentos$barrio),
    "| cobertura:", round(cobertura, 1), "% de las viviendas\n")

# Si el mercado "compensara", los segmentos con más retorno tendrían más riesgo
# (correlación positiva). Spearman porque solo nos interesa el orden y hay pocos
# segmentos con valores extremos (Puerto Madero).
sp_cero <- cor.test(segmentos$ingreso_mediano, segmentos$pct_sin_ingreso,
                    method = "spearman", exact = FALSE)
sp_cv   <- cor.test(segmentos$ingreso_mediano, segmentos$cv_ingreso,
                    method = "spearman", exact = FALSE)
# Lo mismo dentro de cada tramo de tamaño
sp_tramo <- segmentos |>
  group_by(tramo_cap) |>
  summarise(n_segmentos = n(),
            rho = cor(ingreso_mediano, pct_sin_ingreso, method = "spearman"),
            .groups = "drop")
print(sp_tramo)

pruebas <- tibble(
  prueba = c("Kruskal-Wallis: ingreso según barrio",
             "Chi-cuadrado: sin ingreso según barrio",
             "Spearman: ingreso mediano vs % sin ingreso (segmentos)",
             "Spearman: ingreso mediano vs CV del ingreso (segmentos)"),
  estadistico = c(kw$statistic, chi$statistic, sp_cero$estimate, sp_cv$estimate),
  gl = c(kw$parameter, chi$parameter, NA, NA),
  p_valor = c(kw$p.value, chi$p.value, sp_cero$p.value, sp_cv$p.value),
  efecto = c(eps2, v_cramer, NA, NA),
  medida_efecto = c("épsilon²", "V de Cramér", "rho", "rho"),
  n = c(n, n, nrow(segmentos), nrow(segmentos)))
print(pruebas, width = Inf)

# --- 5. Robustez: ¿la conclusión depende de las decisiones? -----------------
rho_cero <- function(seg) cor(seg$ingreso_mediano, seg$pct_sin_ingreso, method = "spearman")
seg_sin_out <- viv |> filter(outlier_precio == "normal") |>
  group_by(barrio, tramo_cap) |> resumir_ingreso() |> filter(n >= 30)
robustez <- tibble(
  version = c("Base: segmentos con 30+ viviendas",
              "Umbral más exigente: 50+ viviendas",
              "Riesgo medido con el CV del ingreso",
              "Sin outliers de precio"),
  n_segmentos = c(nrow(segmentos), sum(segmentos$n >= 50), nrow(segmentos), nrow(seg_sin_out)),
  rho = c(rho_cero(segmentos),
          rho_cero(filter(segmentos, n >= 50)),
          unname(sp_cv$estimate),
          rho_cero(seg_sin_out)))
print(robustez)

# --- 6. Chequeo de la primera entrega ----------------------------------------
# En la entrega 1 medimos la ocupación como (365 - disponibilidad) / 365. Pero
# un calendario cerrado puede estar bloqueado por el anfitrión, no alquilado.
# Comparamos cómo se ordenan los barrios con cada medida.
chequeo <- viv |>
  group_by(barrio_g) |>
  summarise(precio_mediano = median(precio),
            ocup_por_calendario = median((365 - disponibilidad) / 365 * 100),
            ocup_estimada = median(ocupacion / 365 * 100), .groups = "drop")
chequeo_cor <- tibble(
  medida = c("Ocupación por calendario cerrado (entrega 1)",
             "Ocupación estimada por reseñas (entrega final)"),
  spearman_con_precio = c(cor(chequeo$precio_mediano, chequeo$ocup_por_calendario, method = "spearman"),
                          cor(chequeo$precio_mediano, chequeo$ocup_estimada, method = "spearman")))
print(chequeo_cor)

# --- 7. Gráfico 1: índice de precio vs índice de ingreso por barrio ----------
# La base trae los nombres sin tilde; los corregimos solo para los gráficos.
con_tildes <- function(x) dplyr::recode(x, "Nuñez" = "Núñez", "San Nicolas" = "San Nicolás",
                                        "Constitucion" = "Constitución", "San Cristobal" = "San Cristóbal",
                                        "Villa Del Parque" = "Villa del Parque")
graf_b <- por_barrio |>
  mutate(barrio = con_tildes(barrio)) |>
  filter(barrio != "Palermo") |>
  select(barrio, n, indice_precio, indice_ingreso) |>
  mutate(etiqueta = paste0(barrio, " (n = ", number(n, big.mark = ".", decimal.mark = ","), ")"),
         etiqueta = reorder(etiqueta, indice_ingreso)) |>
  pivot_longer(c(indice_precio, indice_ingreso), names_to = "medida", values_to = "indice") |>
  mutate(medida = if_else(medida == "indice_precio", "Precio por noche", "Ingreso anual estimado"),
         medida = factor(medida, levels = c("Precio por noche", "Ingreso anual estimado")))

pal <- por_barrio |> filter(barrio == "Palermo")   # valores de referencia

g_ind <- ggplot(graf_b, aes(x = indice, y = etiqueta)) +
  geom_vline(xintercept = 100, colour = colores[["tinta"]]) +
  geom_line(aes(group = etiqueta), colour = colores[["gris_claro"]], linewidth = 1.2) +
  geom_point(aes(colour = medida, shape = medida), size = 2.8) +
  # Aclaración de la referencia: Palermo vale 100 en las dos medidas, cada una con su valor
  annotate("text", x = 103, y = 3, hjust = 0, vjust = 0.5, size = 3.6, lineheight = 1.1,
           colour = colores[["tinta"]],
           label = paste0("Palermo = 100 en las dos medidas:\n",
                          "precio por noche: $", number(pal$precio_mediano, big.mark = ".", decimal.mark = ","), "\n",
                          "ingreso anual: $", number(pal$ingreso_mediano, big.mark = ".", decimal.mark = ","))) +
  scale_colour_manual(values = c("Precio por noche" = colores[["gris"]],
                                 "Ingreso anual estimado" = colores[["azul"]]), name = NULL) +
  scale_shape_manual(values = c("Precio por noche" = 1, "Ingreso anual estimado" = 16), name = NULL) +
  scale_x_continuous(breaks = seq(0, 200, 25)) +
  labs(title = "Fuera de Palermo, la brecha de ingreso es mayor que la de precio",
       subtitle = "Viviendas completas · medianas por barrio indexadas a Palermo = 100\nIngreso = precio × noches ocupadas estimadas, últimos 12 meses",
       x = "Índice (Palermo = 100)", y = NULL,
       caption = "Fuente: elaboración propia con datos de Inside Airbnb (CABA, jun-jul 2026).") +
  tema_graficos() +
  theme(plot.caption = element_text(colour = colores[["gris"]], size = 9, hjust = 0))
guardar_grafico(g_ind, "rr_indice_precio_ingreso", 9, 7.5, 9.5, 7.2)

# --- 8. Gráfico 2: mapa riesgo-retorno de los segmentos ----------------------
medianas <- segmentos |> group_by(tramo_cap) |>
  summarise(x = median(pct_sin_ingreso), y = median(ingreso_mediano), .groups = "drop")
destacados <- c("Palermo", "Puerto Madero", "Recoleta", "Balvanera", "Constitucion", "San Nicolas")
segmentos_g <- segmentos |>
  mutate(grupo = case_when(barrio == "Palermo" ~ "Palermo",
                           barrio == "Puerto Madero" ~ "Puerto Madero",
                           TRUE ~ "Resto de los barrios"),
         rotulo = if_else(barrio %in% destacados, con_tildes(barrio), NA_character_),
         tramo_cap = paste("Capacidad", tramo_cap, "personas"))
medianas <- medianas |> mutate(tramo_cap = paste("Capacidad", tramo_cap, "personas"))

g_rr <- ggplot(segmentos_g, aes(pct_sin_ingreso, ingreso_mediano)) +
  geom_vline(data = medianas, aes(xintercept = x), colour = colores[["gris_claro"]], linetype = "dashed") +
  geom_hline(data = medianas, aes(yintercept = y), colour = colores[["gris_claro"]], linetype = "dashed") +
  geom_point(aes(colour = grupo, size = n), alpha = 0.85) +
  # ggrepel separa los nombres para que no se pisen entre sí ni con los puntos
  ggrepel::geom_text_repel(aes(label = rotulo), size = 3.6, colour = colores[["tinta"]], na.rm = TRUE,
                           seed = 123, box.padding = 0.5, point.padding = 0.3, min.segment.length = 0,
                           segment.colour = colores[["gris"]], segment.size = 0.3, max.overlaps = Inf) +
  facet_wrap(~ tramo_cap, scales = "free_y") +
  scale_colour_manual(values = c("Palermo" = colores[["tinta"]], "Puerto Madero" = "#c4570e",   # naranja: se distingue del azul
                                 "Resto de los barrios" = "#6f93bd"), name = NULL) +
  scale_size_area(max_size = 7, guide = "none") +
  scale_x_continuous(labels = label_percent(scale = 1, decimal.mark = ",")) +
  scale_y_continuous(labels = label_number(scale = 1e-6, suffix = " M", big.mark = ".", decimal.mark = ","),
                     expand = expansion(mult = c(0.05, 0.15))) +
  coord_cartesian(clip = "off") +
  labs(title = "Los segmentos con menor ingreso también tienen más viviendas sin ingreso",
       subtitle = "Segmentos barrio × capacidad con 30 o más viviendas completas (64 segmentos, 97,6% de la oferta)\nLíneas: medianas del panel · tamaño = cantidad de viviendas · escala vertical distinta por panel",
       x = "Viviendas sin ingreso en los últimos 12 meses (%)",
       y = "Ingreso anual mediano (millones)",
       caption = "Fuente: elaboración propia con datos de Inside Airbnb (CABA, jun-jul 2026). Asociación descriptiva, no causal.") +
  tema_graficos() +
  theme(plot.caption = element_text(colour = colores[["gris"]], size = 9, hjust = 0))
guardar_grafico(g_rr, "rr_mapa_segmentos", 11, 5.5, 13, 4.3)

# --- 9. Guardado --------------------------------------------------------------
write_csv(por_barrio,  here("output", "tablas", "rr_barrio.csv"))
write_csv(segmentos,   here("output", "tablas", "rr_segmentos.csv"))
write_csv(pruebas,     here("output", "tablas", "rr_pruebas.csv"))
write_csv(robustez,    here("output", "tablas", "rr_robustez.csv"))
write_csv(chequeo,     here("output", "tablas", "rr_chequeo_ocupacion.csv"))
write_csv(chequeo_cor, here("output", "tablas", "rr_chequeo_ocupacion_correlacion.csv"))
