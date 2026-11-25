# resumir_ingreso(): resume precio, ocupación e ingreso de un grupo de publicaciones
# (un barrio o un segmento barrio × tamaño). Se usa con group_by() |> summarise().
# Devuelve los indicadores de "retorno" (ingreso mediano) y de "riesgo"
# (% sin ingreso en el año y coeficiente de variación del ingreso).
resumir_ingreso <- function(datos) {
  dplyr::summarise(
    datos,
    n                 = dplyr::n(),
    precio_mediano    = stats::median(precio),
    ocupacion_mediana = stats::median(ocupacion),          # noches por año
    ingreso_mediano   = stats::median(ingreso),            # retorno
    ingreso_promedio  = mean(ingreso),
    pct_sin_ingreso   = mean(ingreso == 0) * 100,          # riesgo 1: publicaciones paradas
    cv_ingreso        = stats::sd(ingreso) / mean(ingreso), # riesgo 2: dispersión relativa
    .groups = "drop"
  )
}
