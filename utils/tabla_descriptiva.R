# tabla_descriptiva(): estadísticas de posición, dispersión y faltantes
# para un conjunto de variables cuantitativas de un data frame.
tabla_descriptiva <- function(datos, variables) {
  datos |>
    dplyr::select(dplyr::all_of(variables)) |>
    tidyr::pivot_longer(dplyr::everything(), names_to = "variable", values_to = "valor") |>
    dplyr::group_by(variable) |>
    dplyr::summarise(
      n         = sum(!is.na(valor)),
      pct_nulos = round(mean(is.na(valor)) * 100, 1),
      media     = mean(valor, na.rm = TRUE),
      desvio    = sd(valor, na.rm = TRUE),
      cv        = desvio / media,                       # coeficiente de variación
      min       = min(valor, na.rm = TRUE),
      q1        = quantile(valor, 0.25, na.rm = TRUE),
      mediana   = median(valor, na.rm = TRUE),
      q3        = quantile(valor, 0.75, na.rm = TRUE),
      max       = max(valor, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(variable = factor(variable, levels = variables)) |>
    dplyr::arrange(variable)
}
