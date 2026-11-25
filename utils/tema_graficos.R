# tema_graficos(): estilo común de todos los gráficos, con la paleta de la
# presentación (azul marino, azul, verde y bordó sobre fondo gris azulado claro).
# Así todas las figuras se ven iguales y combinan con las diapositivas.
colores <- c(tinta = "#0b2545", gris = "#5f6b7a", gris_claro = "#c9d3df",
             linea = "#d9e0e8", azul = "#174a7e", verde = "#17805c",
             bordo = "#8c2f39", fondo = "#f4f7f9")

tema_graficos <- function(base = 13) {
  ggplot2::theme_minimal(base_size = base) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = "white", colour = NA),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#e3e8ee", linewidth = 0.3),
      axis.text        = ggplot2::element_text(colour = "#5f6b7a"),
      axis.title       = ggplot2::element_text(colour = "#5f6b7a"),
      plot.title       = ggplot2::element_text(colour = "#0b2545", face = "bold"),
      plot.subtitle    = ggplot2::element_text(colour = "#5f6b7a"),
      strip.text       = ggplot2::element_text(colour = "#0b2545"),
      legend.position  = "top"
    )
}
