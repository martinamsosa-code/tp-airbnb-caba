# guardar_grafico(): guarda cada gráfico dos veces.
#  - output/graficos/<nombre>.png      : con título (para el informe y el anexo)
#  - output/graficos/ppt/<nombre>.png  : sin título y con letra más grande (el título
#                                        lo pone la diapositiva)
# Si el gráfico no trae fuente, le agrega la de Inside Airbnb al pie: la consigna
# pide la fuente del dato en todos los gráficos.
guardar_grafico <- function(g, nombre, ancho, alto, ancho_ppt = ancho, alto_ppt = alto) {
  if (is.null(g$labels$caption)) {
    g <- g + ggplot2::labs(caption = "Fuente: elaboración propia con datos de Inside Airbnb (CABA, jun-jul 2026).") +
      ggplot2::theme(plot.caption = ggplot2::element_text(colour = "#5f6b7a", size = 9, hjust = 0))
  }
  ggplot2::ggsave(here::here("output", "graficos", paste0(nombre, ".png")),
                  g, width = ancho, height = alto, dpi = 200)
  g_ppt <- g + ggplot2::labs(title = NULL, subtitle = NULL) +
    ggplot2::theme(text = ggplot2::element_text(size = 15),
                   plot.caption = ggplot2::element_text(size = 12, colour = "#5f6b7a", hjust = 0),
                   strip.text = ggplot2::element_text(size = 15, colour = "#0b2545"),
                   # mismo fondo que las diapositivas
                   plot.background = ggplot2::element_rect(fill = "#f4f7f9", colour = NA))
  ggplot2::ggsave(here::here("output", "graficos", "ppt", paste0(nombre, ".png")),
                  g_ppt, width = ancho_ppt, height = alto_ppt, dpi = 200)
}
