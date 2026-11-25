# =============================================================================
# 05_clustering.R
# Pregunta : ¿hay perfiles de publicaciones con características cuantitativas
#            parecidas? ¿Esos perfiles se agrupan en ciertos barrios/zonas?
# Método   : k-means sobre variables cuantitativas estandarizadas; elección de k
#            con codo y silueta; perfiles; relación con barrios (chi-cuadrado,
#            V de Cramér, cociente de localización, HHI territorial) y mapas.
# Lee      : input/listings_analisis.rds, auxiliar/neighbourhoods.geojson
# Genera   : input/listings_clusters.rds
#            output/tablas/cluster_eleccion_k.csv, cluster_perfiles.csv,
#            cluster_barrio_pct.csv, cluster_territorio.csv, cluster_sensibilidad.csv
#            output/graficos/cluster_codo_silueta.png, cluster_mapa_puntos.png,
#            cluster_mapa_cociente.png
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(cluster)   # silhouette()
library(sf)        # mapas
library(here)

source(here("utils", "tema_graficos.R"))
source(here("utils", "guardar_grafico.R"))

datos <- readRDS(here("input", "listings_analisis.rds"))

# --- 1. Variables del clustering ---------------------------------------------
# Solo cuantitativas y sin ubicación (lat/long quedan afuera a propósito:
# queremos ver DESPUÉS si los grupos coinciden con el territorio).
# Las muy asimétricas van en log para que pocos valores extremos no dominen.
base_cl <- datos |>
  filter(!is.na(estadia_minima)) |>                    # 3 casos sin dato
  mutate(log_estadia = log(estadia_minima),
         log_props   = log(props_anfitrion))

vars_cl <- c("log_precio", "capacidad", "ocupacion", "disponibilidad",
             "log_estadia", "log_props")

# Estandarizar: media 0 y desvío 1. Sin esto, la variable con números más grandes
# (disponibilidad, hasta 365) pesaría mucho más en la distancia que la capacidad.
X <- scale(base_cl[, vars_cl])

# --- 2. Elección de k: codo (WSS) y silueta ----------------------------------
set.seed(123)
idx <- sample(nrow(X), 5000)          # la silueta necesita todas las distancias: usamos una muestra
D   <- dist(X[idx, ])

eleccion <- lapply(2:8, function(k) {
  set.seed(123)
  km <- kmeans(X, centers = k, nstart = 25, iter.max = 100, algorithm = "MacQueen")
  tibble(k = k,
         wss_relativa = km$tot.withinss / sum(scale(X, scale = FALSE)^2),
         silueta = mean(silhouette(km$cluster[idx], D)[, 3]))
}) |> bind_rows()
print(eleccion)

g_k <- eleccion |>
  pivot_longer(-k, names_to = "criterio", values_to = "valor") |>
  mutate(criterio = dplyr::recode(criterio,
                           wss_relativa = "Variación interna (proporción del total)",
                           silueta = "Silueta promedio")) |>
  ggplot(aes(k, valor)) +
  geom_line(colour = colores["tinta"]) + geom_point(colour = colores["tinta"]) +
  facet_wrap(~ criterio, scales = "free_y") +
  scale_x_continuous(breaks = 2:8) +
  labs(title = "Elección de la cantidad de clusters", x = "k", y = NULL) +
  tema_graficos()
guardar_grafico(g_k, "cluster_codo_silueta", 9, 4, 9, 4.2)

# --- 3. Modelo final -----------------------------------------------------------
K <- 6                                 # máxima silueta y perfiles interpretables (ver informe)
set.seed(123)
km <- kmeans(X, centers = K, nstart = 25, iter.max = 100, algorithm = "MacQueen")
base_cl$cluster <- km$cluster

# Perfil de cada cluster en la escala original (medianas)
perfiles <- base_cl |>
  group_by(cluster) |>
  summarise(n = n(),
            pct = round(n / nrow(base_cl) * 100, 1),
            precio = median(precio),
            capacidad = median(capacidad),
            ocupacion = median(ocupacion),
            disponibilidad = median(disponibilidad),
            estadia_minima = median(estadia_minima),
            props_anfitrion = median(props_anfitrion),
            pct_habitaciones = round(mean(tipo_alquiler != "Vivienda completa") * 100, 1),
            pct_superhost = round(mean(superhost) * 100, 1),
            calificacion = median(calificacion, na.rm = TRUE))
print(perfiles, width = Inf)

# Nombres descriptivos según el perfil (revisar si cambia la semilla o las variables)
nombres <- c(`1` = "Gestión profesional", `2` = "Grandes y caras",
             `3` = "Calendario restringido", `4` = "Particular, baja ocupación",
             `5` = "Estadías largas", `6` = "Alta ocupación")
base_cl <- base_cl |> mutate(perfil = factor(nombres[as.character(cluster)], levels = nombres))
perfiles <- perfiles |> mutate(perfil = nombres[as.character(cluster)], .after = cluster)

write_csv(eleccion, here("output", "tablas", "cluster_eleccion_k.csv"))
write_csv(perfiles, here("output", "tablas", "cluster_perfiles.csv"))

# --- 4. ¿Los perfiles se relacionan con el barrio? ----------------------------
# 4a. Tabla de contingencia barrio (agrupado como en el ANOVA) × perfil
barrios_100 <- base_cl |> count(barrio) |> filter(n >= 100) |> pull(barrio)
base_cl <- base_cl |>
  mutate(barrio_g = if_else(barrio %in% barrios_100, barrio, "Resto de CABA"))

tabla_bp <- table(base_cl$barrio_g, base_cl$perfil)
chi <- chisq.test(tabla_bp)
v_cramer <- sqrt(unname(chi$statistic) / (sum(tabla_bp) * (min(dim(tabla_bp)) - 1)))
cat("Chi² =", round(chi$statistic, 1), "| gl =", chi$parameter, "| p =", chi$p.value,
    "| V de Cramér =", round(v_cramer, 3),
    "| celdas con esperado < 5:", sum(chi$expected < 5), "\n")

pct_barrio <- as_tibble(prop.table(tabla_bp, 1) * 100, .name_repair = "minimal") |>
  setNames(c("barrio", "perfil", "pct")) |>
  pivot_wider(names_from = perfil, values_from = pct)
write_csv(pct_barrio, here("output", "tablas", "cluster_barrio_pct.csv"))

# 4b. ¿Cada perfil está concentrado en pocos barrios? Índice de Herfindahl-Hirschman
#     (HHI = suma de participaciones² de cada barrio en el perfil) y comparación con
#     la concentración de la oferta total. Más alto = más concentrado territorialmente.
hhi <- function(x) sum((x / sum(x))^2)
territorio <- base_cl |>
  count(perfil, barrio, name = "cant") |>
  group_by(perfil) |>
  summarise(n = sum(cant),
            hhi = hhi(cant),
            pct_palermo_recoleta = round(sum(cant[barrio %in% c("Palermo", "Recoleta")]) / sum(cant) * 100, 1),
            barrio_principal = barrio[which.max(cant)]) |>
  mutate(perfil = as.character(perfil)) |>
  bind_rows(base_cl |> count(barrio, name = "cant") |>
              summarise(perfil = "Oferta total", n = sum(cant), hhi = hhi(cant),
                        pct_palermo_recoleta = round(sum(cant[barrio %in% c("Palermo", "Recoleta")]) / sum(cant) * 100, 1),
                        barrio_principal = barrio[which.max(cant)]))
print(territorio)
write_csv(territorio, here("output", "tablas", "cluster_territorio.csv"))

# 4c. Cociente de localización (misma lógica que la ventaja comparativa revelada):
#     CL = (% del perfil dentro del barrio) / (% del perfil en toda la ciudad).
#     CL > 1: el perfil está sobrerrepresentado en ese barrio.
cociente <- base_cl |>
  count(barrio, perfil) |>
  group_by(barrio) |> mutate(n_barrio = sum(n), pct_en_barrio = n / n_barrio) |>
  group_by(perfil) |> mutate(pct_ciudad = sum(n) / nrow(base_cl)) |>
  ungroup() |>
  mutate(cl = pct_en_barrio / pct_ciudad) |>
  complete(barrio, perfil, fill = list(cl = 0)) |>
  group_by(barrio) |> mutate(n_barrio = max(n_barrio, na.rm = TRUE)) |> ungroup()
write_csv(cociente, here("output", "tablas", "cluster_cociente_localizacion.csv"))

# --- 5. Mapas ----------------------------------------------------------------
barrios_sf <- st_read(here("auxiliar", "neighbourhoods.geojson"), quiet = TRUE)

# 5a. Puntos: cada publicación ubicada y coloreada por perfil, un panel por perfil
g_pts <- ggplot() +
  geom_sf(data = barrios_sf, fill = "#ffffff", colour = "#c9d3df", linewidth = 0.2) +
  geom_point(data = base_cl, aes(longitud, latitud), size = 0.15, alpha = 0.35,
             colour = colores["azul"]) +
  facet_wrap(~ perfil, ncol = 3) +
  coord_sf(xlim = c(-58.535, -58.34), ylim = c(-34.71, -34.53)) +
  labs(title = "Ubicación de las publicaciones de cada perfil", x = NULL, y = NULL) +
  tema_graficos(11) +
  theme(axis.text = element_blank(), panel.grid = element_blank(), panel.grid.major = element_blank())
guardar_grafico(g_pts, "cluster_mapa_puntos", 10, 7.5, 9, 7.6)

# 5b. Coropleta del cociente de localización (barrios con 30+ publicaciones)
mapa_cl <- barrios_sf |>
  left_join(cociente, by = c("neighbourhood" = "barrio"), relationship = "many-to-many") |>
  filter(!is.na(perfil)) |>
  mutate(cl_plot = if_else(n_barrio >= 30, pmin(cl, 3), NA_real_))
g_cl <- ggplot(mapa_cl) +
  geom_sf(aes(fill = cl_plot), colour = "white", linewidth = 0.2) +
  scale_fill_gradient2(low = "#c9d3df", mid = "#ffffff", high = colores[["verde"]],
                       midpoint = 1, limits = c(0, 3), na.value = "#ffffff",
                       name = "Cociente de\nlocalización") +
  facet_wrap(~ perfil, ncol = 3) +
  labs(title = "¿Dónde está sobrerrepresentado cada perfil?",
       subtitle = "Verde: el perfil pesa más en el barrio que en toda la ciudad (CL > 1). Blanco: menos de 30 publicaciones.") +
  tema_graficos(11) +
  theme(axis.text = element_blank(), panel.grid = element_blank(), panel.grid.major = element_blank(), legend.position = "right")
guardar_grafico(g_cl, "cluster_mapa_cociente", 10, 7.5, 10.5, 7.6)

# --- 6. Sensibilidad: mismo k-means sin los outliers de precio -----------------
source(here("utils", "indice_rand_ajustado.R"))
sin_out <- base_cl$outlier_precio == "normal"
X_sin <- scale(base_cl[sin_out, vars_cl])
set.seed(123)
km_sin <- kmeans(X_sin, centers = K, nstart = 25, iter.max = 100, algorithm = "MacQueen")
tabla_sin <- table(base_cl$barrio_g[sin_out], km_sin$cluster)
chi_sin <- suppressWarnings(chisq.test(tabla_sin))
sensib <- tibble(
  version = c("Con outliers", "Sin outliers de precio"),
  n = c(nrow(base_cl), sum(sin_out)),
  v_cramer = c(v_cramer, sqrt(unname(chi_sin$statistic) / (sum(tabla_sin) * (min(dim(tabla_sin)) - 1)))),
  rand_ajustado_vs_original = c(1, indice_rand_ajustado(base_cl$cluster[sin_out], km_sin$cluster)))
print(sensib)
write_csv(sensib, here("output", "tablas", "cluster_sensibilidad.csv"))

saveRDS(base_cl, here("input", "listings_clusters.rds"))
