# =============================================================================
# 04_anova.R
# Pregunta : ¿el precio medio por noche (en log) es igual en todos los barrios?
#            ¿Las diferencias se mantienen al comparar viviendas del mismo tamaño?
# Método   : ANOVA de un factor + verificación de supuestos + Welch + Kruskal-Wallis
#            + post-hoc de Tukey + tamaño del efecto (eta²). Sensibilidad sin outliers.
# Lee      : input/listings_analisis.rds
# Genera   : output/tablas/anova_resultados.csv, anova_supuestos.csv,
#            anova_tukey_vs_palermo.csv, anova_por_capacidad.csv
#            output/graficos/anova_qqplot.png, anova_diferencias_palermo.png
# =============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(car)        # leveneTest()
library(here)

source(here("utils", "tema_graficos.R"))
source(here("utils", "guardar_grafico.R"))

datos <- readRDS(here("input", "listings_analisis.rds"))

# --- 1. Población y grupos ----------------------------------------------------
# Solo viviendas completas (90% de la oferta): así no comparamos departamentos
# con habitaciones, que tienen otra lógica de precio.
# Barrios con menos de 100 viviendas completas se agrupan en "Resto de CABA"
# para no tener grupos muy chicos e inestables.
viv <- datos |> filter(tipo_alquiler == "Vivienda completa")

barrios_100 <- viv |> count(barrio) |> filter(n >= 100) |> pull(barrio)
viv <- viv |>
  mutate(barrio_g = if_else(barrio %in% barrios_100, barrio, "Resto de CABA"),
         barrio_g = relevel(factor(barrio_g), ref = "Palermo"),
         tramo_cap = cut(capacidad, c(0, 2, 4, 6, Inf),
                         labels = c("1-2", "3-4", "5-6", "7+")))
cat("Grupos:", nlevels(viv$barrio_g), "| N =", nrow(viv), "\n")
print(sort(table(viv$barrio_g)))

# --- 2. ANOVA de un factor sobre log(precio) ---------------------------------
modelo <- aov(log_precio ~ barrio_g, data = viv)
tabla  <- summary(modelo)[[1]]
print(tabla)

sc   <- tabla[["Sum Sq"]]
eta2 <- sc[1] / sum(sc)          # proporción de la variabilidad asociada a la agrupación
cat("eta² =", round(eta2, 3), "\n")

# --- 3. Supuestos -------------------------------------------------------------
# 3a. Normalidad de residuos: con n = 25.000 cualquier test rechaza; miramos el QQ-plot.
res <- tibble(r = residuals(modelo))
g_qq <- ggplot(res, aes(sample = r)) +
  stat_qq(colour = colores["gris"], size = 0.4, alpha = 0.4) +
  stat_qq_line(colour = colores["azul"]) +
  labs(title = "QQ-plot de los residuos del ANOVA (log del precio)",
       x = "Cuantiles teóricos (normal)", y = "Cuantiles de los residuos") +
  tema_graficos()
guardar_grafico(g_qq, "anova_qqplot", 6, 5, 6, 5)
asimetria <- mean(res$r^3) / sd(res$r)^3
curtosis  <- mean(res$r^4) / sd(res$r)^4

# 3b. Homogeneidad de varianzas: Levene + cociente entre el mayor y el menor desvío
levene <- leveneTest(log_precio ~ barrio_g, data = viv)
desvios <- viv |> group_by(barrio_g) |> summarise(sd = sd(log_precio))
cociente_sd <- max(desvios$sd) / min(desvios$sd)

supuestos <- tibble(
  chequeo = c("Asimetría de residuos", "Curtosis de residuos",
              "Levene: F", "Levene: p-valor", "Cociente desvío máx/mín"),
  valor = c(asimetria, curtosis, levene$`F value`[1], levene$`Pr(>F)`[1], cociente_sd))
print(supuestos)

# --- 4. Alternativas robustas -------------------------------------------------
welch   <- oneway.test(log_precio ~ barrio_g, data = viv, var.equal = FALSE)
kruskal <- kruskal.test(precio ~ barrio_g, data = viv)
k <- nlevels(viv$barrio_g); n <- nrow(viv)
eps2 <- (kruskal$statistic - k + 1) / (n - k)   # épsilon² (tamaño de efecto del Kruskal-Wallis)

# --- 5. ¿Las diferencias se mantienen comparando viviendas del mismo tamaño? --
# Repetimos el ANOVA dentro de cada tramo de capacidad.
por_cap <- viv |>
  group_by(tramo_cap) |>
  group_modify(~ {
    m  <- aov(log_precio ~ barrio_g, data = .x)
    t  <- summary(m)[[1]]
    tibble(n = nrow(.x), F = t$`F value`[1], gl1 = t$Df[1], gl2 = t$Df[2],
           p = t$`Pr(>F)`[1], eta2 = t$`Sum Sq`[1] / sum(t$`Sum Sq`))
  }) |> ungroup()
print(por_cap)

# eta² del tamaño solo, para comparar magnitudes
t_cap <- summary(aov(log_precio ~ tramo_cap, data = viv))[[1]]
eta2_cap <- t_cap$`Sum Sq`[1] / sum(t_cap$`Sum Sq`)

# --- 6. Sensibilidad: sin outliers de precio ----------------------------------
viv_sin <- viv |> filter(outlier_precio == "normal")
t_sin <- summary(aov(log_precio ~ barrio_g, data = viv_sin))[[1]]
eta2_sin <- t_sin$`Sum Sq`[1] / sum(t_sin$`Sum Sq`)

resultados <- tibble(
  prueba = c("ANOVA clásico", "ANOVA de Welch", "Kruskal-Wallis",
             "ANOVA sin outliers", "ANOVA solo con tramo de capacidad"),
  estadistico = c(tabla$`F value`[1], welch$statistic, kruskal$statistic,
                  t_sin$`F value`[1], t_cap$`F value`[1]),
  gl1 = c(tabla$Df[1], welch$parameter[1], kruskal$parameter, t_sin$Df[1], t_cap$Df[1]),
  gl2 = c(tabla$Df[2], welch$parameter[2], NA, t_sin$Df[2], t_cap$Df[2]),
  p_valor = c(tabla$`Pr(>F)`[1], welch$p.value, kruskal$p.value,
              t_sin$`Pr(>F)`[1], t_cap$`Pr(>F)`[1]),
  efecto = c(eta2, NA, eps2, eta2_sin, eta2_cap),
  medida_efecto = c("eta²", NA, "épsilon²", "eta²", "eta²"),
  n = c(n, n, n, nrow(viv_sin), n))
print(resultados, width = Inf)

# --- 7. Post-hoc de Tukey: ¿qué barrios difieren? ----------------------------
tukey <- TukeyHSD(modelo, "barrio_g")$barrio_g
tukey_df <- as_tibble(tukey, rownames = "par")
cat("Pares comparados:", nrow(tukey_df),
    "| significativos (p ajustado < 0,05):", sum(tukey_df$`p adj` < 0.05), "\n")

# Para comunicar: cada barrio contra Palermo (el de mayor oferta).
# La diferencia de log se pasa a % con (exp(dif) - 1) * 100.
vs_palermo <- tukey_df |>
  filter(grepl("-Palermo$", par)) |>
  transmute(barrio = sub("-Palermo$", "", par),
            dif_pct = (exp(diff) - 1) * 100,
            li_pct  = (exp(lwr) - 1) * 100,
            ls_pct  = (exp(upr) - 1) * 100,
            p_ajustado = `p adj`,
            significativo = p_ajustado < 0.05) |>
  arrange(dif_pct)
print(vs_palermo, n = Inf)

# Etiqueta con el n de cada barrio: el ancho del intervalo depende de cuántos casos hay.
n_barrio <- viv |> count(barrio_g, name = "n_casos") |> mutate(barrio = as.character(barrio_g))
vs_palermo_g <- vs_palermo |>
  left_join(n_barrio |> select(barrio, n_casos), by = "barrio") |>
  mutate(etiqueta = paste0(barrio, " (n = ", format(n_casos, big.mark = ".", decimal.mark = ",", trim = TRUE), ")"),
         resultado = if_else(significativo, "Diferencia significativa (Tukey, 5%)",
                             "Diferencia no significativa: el intervalo cruza el 0"))

g_dif <- ggplot(vs_palermo_g, aes(x = dif_pct, y = reorder(etiqueta, dif_pct))) +
  geom_vline(xintercept = 0, colour = colores["tinta"]) +
  geom_errorbarh(aes(xmin = li_pct, xmax = ls_pct, colour = resultado), height = 0, linewidth = 1.1) +
  geom_point(aes(colour = resultado), size = 2.6) +
  scale_colour_manual(values = c("Diferencia significativa (Tukey, 5%)" = colores[["azul"]],
                                 "Diferencia no significativa: el intervalo cruza el 0" = colores[["bordo"]]),
                      name = NULL) +
  labs(title = "Diferencia de precio medio respecto de Palermo",
       subtitle = "Viviendas completas · media geométrica · IC 95% simultáneo de Tukey",
       x = "Diferencia respecto de Palermo (%)", y = NULL) +
  tema_graficos() +
  theme(legend.position = "top", legend.direction = "vertical")
guardar_grafico(g_dif, "anova_diferencias_palermo", 8, 7, 9, 7.5)

# --- 8. Gráfico simple: precio promedio por barrio, coloreado según Tukey ----
# Promedio geométrico = exp(media del log): es el "promedio" que compara el ANOVA
# (menos influido por los precios muy altos que el promedio común).
promedios <- viv |>
  group_by(barrio = as.character(barrio_g)) |>
  summarise(n = n(), precio_promedio = exp(mean(log_precio))) |>
  left_join(vs_palermo |> select(barrio, dif_pct, significativo), by = "barrio") |>
  mutate(grupo = case_when(
    barrio == "Palermo" ~ "Palermo (referencia)",
    !significativo      ~ "Diferencia no significativa",
    dif_pct > 0         ~ "Más caro que Palermo",
    TRUE                ~ "Más barato que Palermo"),
    grupo = factor(grupo, levels = c("Más caro que Palermo", "Palermo (referencia)",
                                     "Diferencia no significativa", "Más barato que Palermo")))
print(promedios |> arrange(desc(precio_promedio)), n = Inf)

g_prom <- ggplot(promedios, aes(x = precio_promedio, y = reorder(barrio, precio_promedio), fill = grupo)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = scales::dollar(round(precio_promedio, -2), big.mark = ".", decimal.mark = ",")),
            hjust = -0.08, size = 3.6, colour = colores[["tinta"]]) +
  scale_fill_manual(values = c("Más caro que Palermo" = colores[["verde"]],
                               "Palermo (referencia)" = colores[["tinta"]],
                               "Diferencia no significativa" = colores[["gris_claro"]],
                               "Más barato que Palermo" = "#6f93bd"), name = NULL) +
  scale_x_continuous(labels = scales::dollar_format(big.mark = ".", decimal.mark = ","),
                     expand = expansion(mult = c(0, 0.16))) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(title = "Precio promedio por noche de viviendas completas, por barrio",
       subtitle = "Promedio geométrico · color según la comparación de Tukey con Palermo (5%)",
       x = "Precio promedio por noche (ARS)", y = NULL) +
  tema_graficos()
guardar_grafico(g_prom, "anova_precio_promedio_barrio", 8, 7.5, 8.6, 7.6)
write_csv(promedios, here("output", "tablas", "anova_precio_promedio_barrio.csv"))

write_csv(resultados, here("output", "tablas", "anova_resultados.csv"))
write_csv(supuestos,  here("output", "tablas", "anova_supuestos.csv"))
write_csv(vs_palermo, here("output", "tablas", "anova_tukey_vs_palermo.csv"))
write_csv(tukey_df,   here("output", "tablas", "anova_tukey_todos.csv"))
write_csv(por_cap,    here("output", "tablas", "anova_por_capacidad.csv"))
