# limpiar_precio(): convierte el precio de texto ("$45,000.00") a número.
# Recibe un vector de texto y devuelve un vector numérico (NA si venía vacío).
limpiar_precio <- function(x) {
  readr::parse_number(x)
}
