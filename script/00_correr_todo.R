# =============================================================================
# 00_correr_todo.R — corre todo el análisis en orden, de raw/ a output/.
# Paquetes necesarios (instalarlos una sola vez desde la consola, no desde acá):
# dplyr, tidyr, readr, stringr, ggplot2, ggrepel, scales, car, cluster, sf, here
# =============================================================================
library(here)
source(here("script", "01_carga_limpieza.R"))
source(here("script", "02_faltantes_outliers.R"))
source(here("script", "03_descriptivas.R"))
source(here("script", "03b_exploratorio_entrega1.R"))
source(here("script", "04_anova.R"))
source(here("script", "05_clustering.R"))
source(here("script", "06_graficos_instancia3.R"))
source(here("script", "07_riesgo_retorno.R"))
