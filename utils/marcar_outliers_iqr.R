# marcar_outliers_iqr(): regla de Tukey (boxplot). Marca como atípico todo valor
# que quede por debajo de Q1 - k*IQR o por encima de Q3 + k*IQR.
# Devuelve un vector de texto: "bajo", "alto" o "normal".
marcar_outliers_iqr <- function(x, k = 1.5) {
  q1  <- quantile(x, 0.25, na.rm = TRUE)
  q3  <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  dplyr::case_when(
    x < q1 - k * iqr ~ "bajo",
    x > q3 + k * iqr ~ "alto",
    TRUE             ~ "normal"
  )
}
