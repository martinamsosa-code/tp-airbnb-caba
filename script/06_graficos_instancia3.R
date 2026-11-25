# =============================================================================
# 06_graficos_instancia3.R
# Objetivo : los dos gráficos de la tercera entrega (visualización).
#   1. Exploratorio : mapa de calor del cociente de localización (CL) de cada
#                     perfil del k-means en cada barrio.
#   2. Comunicativo : superposición de las distribuciones de precio entre
#                     barrios, tomando la mediana de Palermo como referencia.
# Lee      : input/listings_clusters.rds, input/listings_analisis.rds
# Genera   : output/graficos/grupo_02_exploratorio.jpg
#            output/graficos/grupo_02_comunicativo.jpg
# Requiere : correr antes 04_anova.R y 05_clustering.R
# =============================================================================

library(dplyr)
library(tidyr)     # complete()
library(stringr)   # str_wrap()
library(ggplot2)
library(scales)
library(here)

# Paleta del TP (la misma de la presentación)
tinta  <- "#0b2545"; gris <- "#5f6b7a"; gris_claro <- "#c9d3df"
azul   <- "#174a7e"; verde <- "#17805c"; fondo <- "#ffffff"

# La base trae algunos barrios sin tilde: los corregimos solo para mostrar
con_tildes <- function(x) dplyr::recode(x, "Nuñez" = "Núñez", "San Nicolas" = "San Nicolás",
                                        "Constitucion" = "Constitución", "San Cristobal" = "San Cristóbal",
                                        "Villa Del Parque" = "Villa del Parque")

fuente <- "Fuente: elaboración propia en base a Inside Airbnb, Buenos Aires (relevamiento 29/06/2026 a 02/07/2026)."

# -----------------------------------------------------------------------------
# 1. GRÁFICO EXPLORATORIO: cociente de localización perfil × barrio
# -----------------------------------------------------------------------------
# CL = (% del perfil dentro del barrio) / (% del perfil en toda la ciudad).
# CL > 1: el perfil pesa más en ese barrio que en CABA (sobrerrepresentado).
# Devolución de la instancia 3: usamos el CL NORMALIZADO, (CL - 1) / (CL + 1),
# que va de -1 (el perfil no aparece en el barrio) a 1, con 0 = igual que CABA.
# Es simétrico igual que el log (CL = 2 da 0,33 y CL = 0,5 da -0,33), pero se
# lee en una escala común, sin logaritmos.

base_cl <- readRDS(here("input", "listings_clusters.rds")) |> mutate(barrio = con_tildes(barrio))

# Barrios con al menos 100 publicaciones (con menos, el CL es inestable)
barrios_ok <- base_cl |> count(barrio) |> filter(n >= 100)

# Orden de los barrios: por precio mediano por noche (de más caro a más barato)
orden <- base_cl |>
  filter(barrio %in% barrios_ok$barrio) |>
  group_by(barrio) |>
  summarise(n = n(), precio_med = median(precio)) |>
  arrange(precio_med) |>
  mutate(etiqueta = paste0(barrio, "  (n = ", label_number(big.mark = ".", decimal.mark = ",")(n),
                           " · $", label_number(big.mark = ".", decimal.mark = ",", accuracy = 1)(precio_med), ")"))

pct_ciudad <- base_cl |> count(perfil) |> mutate(pct = n / sum(n))

cl <- base_cl |>
  filter(barrio %in% barrios_ok$barrio) |>
  count(barrio, perfil) |>
  complete(barrio, perfil, fill = list(n = 0)) |>
  group_by(barrio) |> mutate(pct_barrio = n / sum(n)) |> ungroup() |>
  left_join(pct_ciudad |> select(perfil, pct), by = "perfil") |>
  mutate(cl = pct_barrio / pct,
         cl_norm = (cl - 1) / (cl + 1),                  # de -1 a 1
         etiqueta = factor(orden$etiqueta[match(barrio, orden$barrio)],
                           levels = orden$etiqueta),
         perfil_lbl = paste0(str_wrap(perfil, 12), "\n(", label_percent(accuracy = 0.1, decimal.mark = ",")(pct), ")"))

g_expl <- ggplot(cl, aes(x = perfil_lbl, y = etiqueta, fill = cl_norm)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = label_number(accuracy = 0.01, decimal.mark = ",", style_negative = "minus")(cl_norm),
                colour = abs(cl_norm) > 0.35), size = 2.7) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = tinta), guide = "none") +
  # Divergente azul-naranja: accesible para daltonismo y distinguible en grises
  scale_fill_gradient2(low = "#2b6ca3", mid = "#f7f7f7", high = "#c4570e",
                       midpoint = 0, limits = c(-1, 1),
                       breaks = c(-1, -0.5, 0, 0.5, 1),
                       labels = c("−1 (no aparece)", "−0,5", "0 (igual que CABA)", "0,5", "1"),
                       name = "Cociente de\nlocalización\nnormalizado") +
  labs(title = "¿En qué barrios pesa más cada perfil de publicación?",
       subtitle = paste0("Naranja: el perfil pesa más en el barrio que en toda CABA; azul: pesa menos; 0 = igual que en CABA.\n",
                         "Columnas: perfiles de publicación del k-means (entre paréntesis, su peso en toda la oferta). ",
                         "Solo barrios con 100 o más publicaciones."),
       x = NULL, y = NULL,
       caption = paste0(fuente,
                        "\nJunto a cada barrio: cantidad de publicaciones y precio mediano por noche (ARS). ",
                        "Cociente de localización normalizado = (CL − 1) / (CL + 1), donde\nCL = % del perfil dentro del barrio ÷ % del perfil en toda CABA.")) +
  theme_minimal(base_size = 10) +
  theme(plot.background = element_rect(fill = fondo, colour = NA),
        panel.grid = element_blank(),
        plot.title = element_text(face = "bold", colour = tinta, size = 15),
        plot.subtitle = element_text(colour = gris, size = 8.6, lineheight = 1.15,
                                     margin = margin(b = 10)),
        plot.caption = element_text(colour = gris, size = 7.5, hjust = 0),
        plot.title.position = "plot", plot.caption.position = "plot",
        axis.text.x = element_text(colour = tinta, size = 8.3, lineheight = 1),
        axis.text.y = element_text(colour = tinta, size = 8.3),
        axis.title = element_text(colour = gris, size = 8.6),
        legend.position = "right",
        legend.title = element_text(size = 8.3, colour = tinta),
        legend.text = element_text(size = 7.8, colour = tinta),
        legend.key.height = unit(1.4, "cm"))

ggsave(here("output", "graficos", "grupo_02_exploratorio.jpg"), g_expl,
       width = 25, height = 19, units = "cm", dpi = 300, bg = "white")

# Versión para la presentación: el mismo mapa de calor TRASPUESTO (perfiles en
# filas, barrios en columnas) para aprovechar el ancho de la diapositiva y que
# los números se lean. Sin título (lo pone la diapositiva).
cl_ppt <- cl |>
  mutate(barrio_lbl = factor(barrio, levels = rev(orden$barrio)),   # de más caro a más barato
         perfil_fila = paste0(str_wrap(perfil, 16), " (",
                              label_percent(accuracy = 0.1, decimal.mark = ",")(pct), ")"),
         perfil_fila = factor(perfil_fila, levels = rev(sort(unique(perfil_fila)))))

g_expl_ppt <- ggplot(cl_ppt, aes(x = barrio_lbl, y = perfil_fila, fill = cl_norm)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = label_number(accuracy = 0.01, decimal.mark = ",", style_negative = "minus")(cl_norm),
                colour = abs(cl_norm) > 0.35), size = 2.1) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = tinta), guide = "none") +
  scale_fill_gradient2(low = "#2b6ca3", mid = "#f7f7f7", high = "#c4570e",
                       midpoint = 0, limits = c(-1, 1),
                       breaks = c(-1, -0.5, 0, 0.5, 1),
                       labels = c("−1 (no aparece)", "−0,5", "0 (igual que CABA)", "0,5", "1"),
                       name = "Cociente de localización normalizado") +
  scale_x_discrete(position = "top") +
  labs(x = NULL, y = NULL,
       caption = paste0("Fuente: elaboración propia con datos de Inside Airbnb (CABA, jun-jul 2026). ",
                        "\nBarrios con 100 o más publicaciones, ordenados por precio mediano: de más caro (izquierda) a más barato. ",
                        "Entre paréntesis, el peso del perfil en toda la oferta.")) +
  theme_minimal(base_size = 7) +
  theme(plot.background = element_rect(fill = "#f4f7f9", colour = NA),
        panel.grid = element_blank(),
        axis.text.x.top = element_text(colour = tinta, size = 7, angle = 40, hjust = 0, vjust = 0),
        axis.text.y = element_text(colour = tinta, size = 7.2),
        plot.caption = element_text(colour = gris, size = 5.6, hjust = 0),
        plot.caption.position = "plot",
        legend.position = "bottom",
        legend.title = element_text(size = 6.2, colour = tinta),
        legend.text = element_text(size = 5.8, colour = tinta),
        legend.key.height = unit(0.22, "cm"), legend.key.width = unit(1.6, "cm"),
        legend.margin = margin(0, 0, 0, 0), legend.box.spacing = unit(0.1, "cm"),
        plot.margin = margin(4, 30, 4, 4)) +
  guides(fill = guide_colourbar(title.position = "left", title.vjust = 0.9))

ggsave(here("output", "graficos", "ppt", "grupo_02_exploratorio.png"), g_expl_ppt,
       width = 19, height = 6.9, units = "cm", dpi = 300)

# -----------------------------------------------------------------------------
# 2. GRÁFICO COMUNICATIVO: superposición de precios entre barrios
# -----------------------------------------------------------------------------
# Mensaje único: los precios típicos difieren entre barrios, pero la dispersión
# dentro de cada barrio es mayor que la distancia entre barrios (eta² = 0,06).
# Devolución de la instancia 3: es un gráfico para el público general, así que
# no lleva lenguaje técnico (ANOVA, p-valor, eta²) ni repite la nota.

viv2 <- readRDS(here("input", "listings_analisis.rds")) |>
  mutate(barrio = con_tildes(barrio)) |>
  filter(tipo_alquiler == "Vivienda completa", !is.na(log_precio))
g100 <- viv2 |> count(barrio) |> filter(n >= 100)
viv2 <- viv2 |> mutate(bg = if_else(barrio %in% g100$barrio, barrio, "Resto de CABA"))

med_pal <- median(viv2$precio[viv2$bg == "Palermo"])

res <- viv2 |>
  group_by(bg) |>
  summarise(n = n(), med = median(precio), p_sobre = mean(precio > med_pal) * 100) |>
  arrange(med) |>
  mutate(bg = factor(bg, levels = bg),
         destaca = case_when(bg == "Palermo" ~ "pal",
                             bg == "Puerto Madero" ~ "pm",
                             TRUE ~ "resto"))

viv2 <- viv2 |> mutate(bg = factor(bg, levels = levels(res$bg))) |>
  left_join(res |> select(bg, destaca), by = "bg")

paleta <- c(pal = "#0b2545", pm = verde, resto = "#aebccd")
tope <- 1150000   # tope del eje para que las cajas se lean; se aclara en la nota

g_com2 <- ggplot(viv2, aes(x = precio, y = bg, fill = destaca, colour = destaca)) +
  geom_boxplot(outlier.shape = NA, linewidth = 0.4, width = 0.62, alpha = 0.9) +
  annotate("segment", x = med_pal, xend = med_pal, y = 0.4, yend = 22.7,
           colour = "#0b2545", linetype = "22", linewidth = 0.6) +
  scale_fill_manual(values = paleta, guide = "none") +
  scale_colour_manual(values = c(pal = "#0b2545", pm = "#0f5c42", resto = "#6f8299"), guide = "none") +
  # porcentaje por encima de la mediana de Palermo, como columna a la derecha
  geom_text(data = res, aes(x = tope, y = bg,
                            label = paste0(label_number(accuracy = 1)(p_sobre), "%")),
            inherit.aes = FALSE, hjust = 1, size = 3,
            colour = ifelse(res$destaca == "resto", gris, tinta),
            fontface = ifelse(res$destaca == "resto", "plain", "bold")) +
  annotate("text", x = tope, y = 25.8, hjust = 1, vjust = 1, size = 2.9,
           colour = tinta, fontface = "bold", lineheight = 1,
           label = "% del barrio más caro\nque el típico de Palermo") +
  annotate("text", x = 19500, y = 25.8, hjust = 0, vjust = 1, size = 3.1, colour = azul,
           fontface = "bold", lineheight = 1.05,
           label = "Hasta en San Cristóbal, el barrio más barato,\n1 de cada 5 departamentos supera al típico\nde Palermo") +
  scale_y_discrete(expand = expansion(add = c(0.8, 4.2))) +
  scale_x_log10(limits = c(19000, tope),
                breaks = c(25000, 50000, 100000, 200000, 400000, 800000),
                labels = label_number(big.mark = ".", decimal.mark = ",", prefix = "$", accuracy = 1)) +
  labs(title = "El precio difiere entre barrios, pero las distribuciones se superponen:\nen todos hay departamentos más caros que el típico de Palermo",
       subtitle = paste0("Precio por noche de los departamentos y casas completos publicados en cada barrio. ",
                         "Cada caja abarca la mitad central de los\ndepartamentos del barrio y la línea interior marca el precio del medio. ",
                         "La línea punteada es el precio típico de Palermo: $",
                         label_number(big.mark = ".", decimal.mark = ",", accuracy = 100)(med_pal), " por noche."),
       x = "Precio por noche en pesos (escala logarítmica)",
       y = NULL,
       caption = paste0(fuente,
                        "\nBarrios con 100 o más publicaciones, ordenados por precio mediano; el resto se agrupa en \"Resto de CABA\". ",
                        "Se omiten los valores atípicos del gráfico para\nque las cajas sean legibles, pero están incluidos en todos los cálculos. ",
                        "Palermo es la referencia porque concentra un tercio de la oferta (8.484 de 24.948),\nno por ser el más caro.")) +
  theme_minimal(base_size = 10) +
  theme(plot.background = element_rect(fill = fondo, colour = NA),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        panel.grid.major.x = element_line(colour = "#e6eaef", linewidth = 0.4),
        plot.title = element_text(face = "bold", colour = tinta, size = 14.5, lineheight = 1.08),
        plot.subtitle = element_text(colour = gris, size = 8.4, lineheight = 1.2, margin = margin(b = 10)),
        plot.caption = element_text(colour = gris, size = 7.3, hjust = 0, lineheight = 1.15),
        plot.title.position = "plot", plot.caption.position = "plot",
        axis.text.y = element_text(colour = tinta, size = 8.8),
        axis.text.x = element_text(colour = gris, size = 8.3),
        axis.title.x = element_text(colour = gris, size = 8.6),
        plot.margin = margin(12, 14, 8, 10))

ggsave(here("output", "graficos", "grupo_02_comunicativo.jpg"), g_com2,
       width = 24, height = 17, units = "cm", dpi = 300, bg = "white")

# Versión para la presentación: sin título ni subtítulo (los pone la diapositiva),
# nota al pie corta y tamaño menor para que la letra se lea en pantalla.
# La anotación de San Cristóbal se pasa al texto de la diapositiva (no entra a este tamaño).
g_com_ppt <- g_com2
g_com_ppt$layers <- Filter(function(l) !grepl("San Cristóbal", paste(l$aes_params$label, collapse = "")),
                           g_com_ppt$layers)
g_com_ppt <- g_com_ppt +
  labs(title = NULL, subtitle = NULL,
       caption = paste0("Fuente: elaboración propia con datos de Inside Airbnb (CABA, jun-jul 2026).\n",
                        "Se omiten los valores atípicos del gráfico, pero están incluidos en los cálculos.")) +
  scale_y_discrete(expand = expansion(add = c(0.6, 2.6))) +
  scale_x_log10(limits = c(19000, tope),
                breaks = c(25000, 50000, 100000, 200000, 400000, 800000),
                labels = c("$25 mil", "$50 mil", "$100 mil", "$200 mil", "$400 mil", "$800 mil")) +
  theme(plot.background = element_rect(fill = "#f4f7f9", colour = NA),
        axis.text.y = element_text(colour = tinta, size = 10),
        axis.text.x = element_text(colour = gris, size = 8.5),
        plot.caption = element_text(colour = gris, size = 7.5, hjust = 0, lineheight = 1.15))

ggsave(here("output", "graficos", "ppt", "grupo_02_comunicativo.png"), g_com_ppt,
       width = 12.5, height = 10.5, units = "cm", dpi = 300)
