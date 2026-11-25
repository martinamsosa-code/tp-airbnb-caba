# indice_rand_ajustado(): compara dos clasificaciones de los mismos casos.
# 1 = idénticas (aunque los números de cluster cambien), 0 = coincidencia esperable por azar.
indice_rand_ajustado <- function(a, b) {
  tab <- table(a, b)
  comb2 <- function(x) x * (x - 1) / 2
  suma_celdas <- sum(comb2(tab))
  suma_filas  <- sum(comb2(rowSums(tab)))
  suma_cols   <- sum(comb2(colSums(tab)))
  esperado    <- suma_filas * suma_cols / comb2(sum(tab))
  maximo      <- (suma_filas + suma_cols) / 2
  (suma_celdas - esperado) / (maximo - esperado)
}
