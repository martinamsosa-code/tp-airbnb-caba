# Guion del oral — TP integrador Airbnb en CABA

Ciencia de Datos para Economía y Negocios · FCE-UBA · Exposición del 27/11/2026  
Martina Sosa · Ciro López Pavía

## Antes de empezar

- Duración objetivo: unos 13 minutos y medio de exposición, con margen hasta 15, más preguntas. Los tiempos de cada diapositiva son orientativos.
- Reparto: Martina abre, presenta la hipótesis, los datos, el ANOVA, el ingreso y la conclusión. Ciro hace el tratamiento de datos, la metodología, el k-means, el territorio, el riesgo y los próximos pasos.
- No leer las diapositivas: decir la idea con nuestras palabras y señalar el número clave.
- Lenguaje: siempre “se asocia”, “difiere”, “es mayor en”. Nunca “causa”, “hace que”, “mueve”, “explica por qué”. Es un trabajo descriptivo.
- Los textos entre comillas son una forma posible de decirlo, no hay que memorizarlos palabra por palabra.

## Reparto y tiempos

| N.º | Diapositiva | Quién | Tiempo |
|---|---|---|---|
| 1 | Carátula | Martina | 0:20 |
| 2 | Hipótesis de trabajo | Martina | 0:50 |
| 3 | Base de datos | Martina | 0:40 |
| 4 | Variables utilizadas | Martina | 0:30 |
| 5 | Estadísticas descriptivas | Martina | 0:40 |
| 6 | Datos faltantes | Ciro | 0:50 |
| 7 | Outliers | Ciro | 0:40 |
| 8 | Antes y después de la limpieza | Ciro | 0:35 |
| 9 | Metodología | Ciro | 0:35 |
| 10 | ANOVA — diseño, supuestos y resultado | Martina | 1:00 |
| 11 | Por qué Palermo como referencia | Martina | 0:35 |
| 12 | Resultados de Tukey | Martina | 0:50 |
| 13 | k-means | Ciro | 0:55 |
| 14 | Perfiles y territorio | Ciro | 1:00 |
| 15 | Riesgo-retorno: el ingreso | Martina | 0:55 |
| 16 | Riesgo-retorno: el riesgo | Ciro | 0:55 |
| 17 | Conclusión | Martina | 0:55 |
| 18 | Limitaciones y próximos pasos | Ciro | 0:35 |
| 19 | Cierre | Martina | 0:10 |
|  | **Total aproximado** | Martina ≈ 7:25 · Ciro ≈ 6:05 | **≈ 13:30** |

## Guion diapositiva por diapositiva

### 1 · Carátula

**Martina** · 0:20 min

“Buenas, somos Martina Sosa y Ciro López Pavía. Estudiamos cómo se organiza la oferta de Airbnb en la Ciudad y si las diferencias de precio entre barrios se sostienen cuando miramos cuánto ingresa una vivienda en el año.”

### 2 · Hipótesis de trabajo

**Martina** · 0:50 min

“Nuestra hipótesis tiene tres partes. Primero, que el precio difiere entre barrios aun entre viviendas del mismo tamaño. Segundo, que los perfiles más profesionalizados se concentran en el corredor premium. Y tercero, que la brecha entre barrios es todavía mayor en el ingreso anual, y que los segmentos con menor ingreso no lo compensan con menos riesgo.”

“Esto último viene de la lógica financiera: normalmente, quien gana menos asume menos riesgo; es la compensación. Nosotros queremos ver si eso pasa acá o no.”

“Cada parte tiene su pregunta y su método, que son las tres tarjetas de abajo.”

“Respecto de la instancia 1: ahí teníamos dos preguntas abiertas. Después las reformulamos como esta hipótesis en tres partes, que se puede contrastar con los datos. Y el riesgo-retorno, que el profesor nos preguntó cómo haríamos sin el precio de compra de la vivienda, lo resolvimos usando el ingreso bruto estimado como retorno.”

“Aclaramos desde el principio que es un trabajo descriptivo: hablamos de asociaciones, no de causas.”

**Si preguntan**

- **¿Por qué cambiaron la hipótesis?** Las dos preguntas de la instancia 1 eran abiertas. Al avanzar vimos que podíamos ordenarlas en una hipótesis con tres afirmaciones que los datos pueden sostener o no, y así cada método responde a una parte.

### 3 · Base de datos

**Martina** · 0:40 min

“Usamos Inside Airbnb, que releva las publicaciones de airbnb.com y publica una base por trimestre. Es una foto del mercado tomada entre fines de junio y principios de julio de 2026: 29.685 publicaciones de 48 barrios. Cada fila es una publicación.”

“La base trae 90 variables; nosotros usamos 17. También usamos una base auxiliar, el mapa de los barrios, que solo trae el nombre y el contorno de cada barrio: es el molde para dibujar los mapas, no agrega datos y no se pierde ninguna observación.”

“Hay limitaciones que vuelven al final: el precio es el publicado, no el cobrado, y la ocupación y el ingreso son estimaciones.”

**Si preguntan**

- **¿Cómo estima Inside Airbnb la ocupación?** Cuenta las reseñas del último año y supone cuántos huéspedes dejan reseña y cuánto dura una estadía típica. Nosotros no leemos el texto de las reseñas: usamos la columna estimated_occupancy_l365d. El ingreso lo calculamos nosotros: precio por esas noches. Por eso una publicación sin reseñas en el año queda con ingreso 0.
- **¿Qué tiene la base auxiliar?** Solo el nombre y el contorno de cada barrio (49 contornos; el extra es “Escollera Exterior”, sin publicaciones). La usamos en el script 05 para los mapas de la instancia 2.

### 4 · Variables utilizadas

**Martina** · 0:30 min

“Las centrales son el precio, el barrio y la ocupación. Además construimos variables: el logaritmo del precio, el ingreso anual, que es precio por noches ocupadas, los tramos de capacidad y el perfil que asigna el k-means.”

“En total usamos 17 variables; acá están las 10 del análisis. Las otras 7, que son coordenadas, baños, superhost y reseñas, son de apoyo: sirven para los mapas, las descriptivas y para resolver faltantes, pero no entran en los métodos. El diccionario completo está en el anexo I.”

**Si preguntan**

- **¿Y el id?** Además de las 17 está el id, que solo identifica cada publicación.

### 5 · Estadísticas descriptivas

**Martina** · 0:40 min

“El precio es muy asimétrico: la media, unos 124 mil pesos por noche, supera a la mediana, de 100 mil. Hay una cola de precios altos que tira la media hacia arriba. Por eso trabajamos con mediana y con logaritmo.”

“La ocupación también es muy dispersa: la mitad de las publicaciones se ocupa menos de 42 noches al año.”

“Y el 90% son viviendas completas, que es el universo del ANOVA y del ingreso. El boxplot ya anticipa la primera pregunta: Puerto Madero se separa y el resto se superpone bastante.”

**Si preguntan**

- **¿Qué es el desvío?** Cuánto se alejan en promedio los valores de la media. Un desvío grande, como el del precio (casi 95 mil), indica mucha dispersión.

### 6 · Datos faltantes

**Ciro** · 0:50 min

“Antes de decidir qué hacer con los faltantes, miramos dónde faltan. Y no faltan al azar: siguen la lógica de la plataforma.”

“El precio falta en 1.792 publicaciones, y en el 99,6% de los calendarios cerrados: son anuncios sin oferta activa. Como es la variable central, no la imputamos: esas publicaciones se eliminan, y eso no sesga la oferta activa que describimos.”

“La calificación falta exactamente en las publicaciones sin reseñas: no se puede calificar lo que nadie reseñó. Y dormitorios falta sobre todo en capacidad 1, probables monoambientes; por eso medimos el tamaño con la capacidad.”

“Los baños tenían 3.420 vacíos, pero en 3.400 el dato estaba escrito en otra columna de texto y lo recuperamos. Y la estadía mínima tiene solo 3 casos faltantes: quedan afuera únicamente del k-means, que necesita las 6 variables completas.”

### 7 · Outliers

**Ciro** · 0:40 min

“Hay dos tipos de valores raros. Los precios de más de un millón por noche, que llegan hasta 171 millones, son errores de carga: se eliminan antes de todo, 214 casos.”

“Los outliers son otra cosa. Usamos la regla de Tukey, 1,5 veces el rango intercuartílico, sobre el logaritmo del precio. Marca 632 precios bajos, que son sobre todo habitaciones, y 853 altos, que son casas grandes. Son parte real del mercado, así que no los borramos: los marcamos y repetimos cada método sin ellos.”

**Si preguntan**

- **¿Por qué en logaritmo?** Porque el precio es asimétrico. En pesos, la regla marcaría como atípica toda la cola de precios altos (2.108 casos). En log la distribución es simétrica y la regla tiene sentido.
- **¿Qué es el RIC?** El rango intercuartílico: la distancia entre el primer y el tercer cuartil, donde está la mitad central de los datos. Es atípico lo que queda a más de 1,5 RIC de esa caja.
- **¿Diferencia entre outlier y error de carga?** El error de carga es un dato imposible o mal cargado (171 millones por noche): se elimina. El outlier es un valor extremo pero real (una casa para 12 personas): se conserva y se analiza aparte.

### 8 · Antes y después de la limpieza

**Ciro** · 0:35 min

“A la izquierda está el flujo: de 29.685 publicaciones quedan 27.679 en la base de análisis, el 93%.”

“El gráfico compara cada versión contra esa base, que es la línea del 0%. Sacar los faltantes casi no cambia nada. Sacar los outliers sí baja la media del precio, un 9%, y la ocupación mediana pasa de 42 a 48 noches. Por eso mostramos cada método con y sin outliers.”

**Si preguntan**

- **¿Por qué sube la ocupación sin outliers?** Porque los atípicos bajos son habitaciones que se ocupan poco; al sacarlas, la mediana sube.

### 9 · Metodología

**Ciro** · 0:35 min

“Este es el mapa del resto de la exposición: cuatro pasos y el orden no es arbitrario.”

“Primero, el ANOVA para ver si el precio difiere entre barrios. Segundo, el k-means arma perfiles de publicación sin usar la ubicación. Tercero, contrastamos esos perfiles con el territorio. Y cuarto, la síntesis de riesgo-retorno: junta precio y ocupación en el ingreso, con la misma referencia, Palermo, y los mismos grupos que el ANOVA. No es un método aislado: es el cierre del argumento.”

**Si preguntan**

- **¿El riesgo-retorno no es un método nuevo?** Es la síntesis: usa los mismos grupos y la misma referencia que el ANOVA, y responde la pregunta que nos hicieron en la instancia 1.

### 10 · ANOVA — diseño, supuestos y resultado

**Martina** · 1:00 min

“Comparamos el logaritmo del precio entre 22 grupos: los 21 barrios con 100 o más viviendas y un grupo “Resto de CABA”. Solo viviendas completas, para no mezclar el barrio con el tipo de alquiler.”

“Los supuestos no se cumplen perfecto y lo decimos: hay colas pesadas y Levene rechaza varianzas iguales. Pero el desvío mayor es apenas 1,26 veces el menor, y las dos alternativas robustas, Welch y Kruskal-Wallis, dan lo mismo.”

“El resultado: F de 78,9 con p menor a 0,001, así que el precio medio no es igual en todos los barrios. Pero el número que importa es el eta cuadrado: 0,06. El barrio se asocia con el 6% de la variabilidad del precio; la mayor parte de las diferencias está dentro de cada barrio. A igual capacidad sube a 0,09. Significativo no es lo mismo que grande.”

**Si preguntan**

- **¿Qué son los números entre paréntesis del F?** Los grados de libertad: 22 grupos menos 1 = 21; 24.948 viviendas menos 22 grupos = 24.926.
- **¿Por qué no Kruskal-Wallis directamente?** Lo hicimos como chequeo y coincide. El ANOVA sobre log permite el post-hoc de Tukey y leer las diferencias en porcentaje.
- **¿El 6% es poco?** Es moderado. Para comparar, la capacidad sola se asocia con el 22,5%.

### 11 · Por qué Palermo como referencia

**Martina** · 0:35 min

“Esto responde la devolución de la instancia 2: ¿por qué Palermo? Por tres razones. Uno de cada tres departamentos está ahí. Es el promedio estimado con menos error, porque es el barrio con más datos. Y el resultado no depende de la referencia: Tukey compara los 231 pares de barrios. No usamos Dunnett, que compararía solo contra Palermo.”

“No lo elegimos por ser el más caro: el más caro es Puerto Madero.”

**Si preguntan**

- **¿Qué hubiera dado Dunnett?** Compararía cada barrio solo contra Palermo: menos comparaciones e intervalos un poco más angostos, pero no diría nada de los barrios entre sí. Con Tukey vemos todo.

### 12 · Resultados de Tukey

**Martina** · 0:50 min

“Cada caja es la mitad central de las viviendas de un barrio, y la línea punteada es el precio típico de Palermo, 112 mil pesos por noche.”

“Solo Puerto Madero se despega: cobra en promedio 64% más que Palermo. 17 de los 21 grupos cobran significativamente menos, y los más baratos, Flores y San Cristóbal, un 32% menos. Colegiales, Núñez y Barracas no difieren significativamente, lo que no quiere decir que sean iguales.”

“Pero las distribuciones se superponen: en todos los barrios hay viviendas más caras que lo típico de Palermo, incluso en San Cristóbal, una de cada cinco. Esa superposición es el eta cuadrado chico.”

“Es el gráfico comunicativo de la instancia 3 con la devolución aplicada: sacamos el ANOVA y el p-valor del gráfico porque es para un público general, sacamos el texto repetido y cambiamos el título viejo, que sugería causalidad.”

**Si preguntan**

- **¿Cómo puede San Cristóbal superar a Palermo si su caja está a la izquierda?** La caja es solo la mitad central. El bigote derecho, las viviendas más caras, pasa la línea punteada: ese tramo es el 19%.

### 13 · k-means

**Ciro** · 0:55 min

“Para el clustering usamos seis variables: precio, capacidad, ocupación, disponibilidad, estadía mínima y cantidad de publicaciones del anfitrión. Las estandarizamos, porque si no la disponibilidad, que llega a 365, dominaría frente a la capacidad. Y a propósito no usamos latitud ni longitud: queremos ver después si los perfiles coinciden con el territorio; si la ubicación entrara, la respuesta estaría armada de antemano.”

“Elegimos 6 grupos porque fue la mejor silueta entre 2 y 8, y el codo coincide: hasta 6, cada grupo extra baja bastante la variación interna; después, casi nada. La silueta mide qué tan bien queda cada publicación en su grupo y qué tan separada está de los demás. Dio 0,198, que es baja: los perfiles son tendencias, no grupos nítidos.”

“En la tabla, lo verde es lo que define a cada perfil: gestión profesional, anfitriones con 35 publicaciones; grandes y caras, 6 personas y 265 mil pesos; calendario restringido, 94 días disponibles; particular, una sola publicación y 24 noches; estadías largas, 15 noches mínimas; y alta ocupación, 234 noches.”

**Si preguntan**

- **¿Por qué logaritmo en la estadía mínima y en las publicaciones?** Porque están muy sesgadas (muchas en 1 o 2, pocas en 30 o más). El log evita que esos extremos dominen las distancias. No tiene nada que ver con los faltantes: los 3 casos sin estadía mínima simplemente se excluyen.
- **¿Qué es el codo?** En el gráfico de la variación interna, el punto donde la curva deja de bajar fuerte. Hasta k = 6 cada grupo extra la reduce entre 7 y 10 puntos; de 6 a 7, solo 3. Ahí está el codo, y coincide con la silueta.
- **¿Por qué nstart = 25 y semilla?** El k-means depende del punto de partida: con 25 arranques se queda con la mejor solución, y la semilla hace que el resultado sea reproducible.

### 14 · Perfiles y territorio

**Ciro** · 1:00 min

“Tres medidas para tres preguntas. ¿El perfil depende del barrio? El chi cuadrado dice que sí, pero la V de Cramér es 0,10: la asociación es débil.”

“¿Algún perfil está más concentrado que la oferta? El HHI dice que sí: gestión profesional y alta ocupación tienen 0,19, contra 0,147 del total.”

“¿Dónde? Eso lo muestra el cociente de localización normalizado: 0 es igual que en toda la ciudad, positivo es que el perfil está sobrerrepresentado y −1 que no aparece. Lo normalizamos por la devolución, porque es simétrico como un logaritmo pero se lee directo. Los barrios van de más caro a la izquierda a más barato a la derecha. Grandes y caras pesa más en Puerto Madero, y gestión profesional pesa mucho menos en los barrios baratos, como Flores o Caballito.”

“Sin outliers da prácticamente lo mismo: V de 0,104 y los grupos casi no cambian.”

**Si preguntan**

- **¿Qué es el cociente de localización?** El porcentaje del perfil en el barrio dividido el porcentaje en toda la ciudad. Es la misma lógica que la ventaja comparativa revelada.

### 15 · Riesgo-retorno: el ingreso

**Martina** · 0:55 min

“Acá cerramos la pregunta de la instancia 1. El retorno es el ingreso anual estimado: precio por noche por noches ocupadas. Es bruto, sin costos ni valor de la vivienda.”

“Armamos índices con Palermo igual a 100, tanto para el precio como para el ingreso. El círculo vacío es el precio y el lleno el ingreso. Fuera del corredor premium, el precio es entre 15 y 25% menor, pero el ingreso, entre 30 y 70% menor: además de cobrar menos, se ocupan menos noches.”

“Dos ejemplos: Colegiales cobra casi lo mismo que Palermo, 6% más, pero ingresa 35% menos. Constitución cobra 24% menos e ingresa 71% menos.”

“Como el ingreso tiene muchos ceros, usamos Kruskal-Wallis: el ingreso difiere entre barrios, pero el barrio se asocia con solo un 3% de su variación.”

**Si preguntan**

- **¿Qué significa mismo universo y grupos que el ANOVA?** Las mismas 24.948 viviendas completas y los mismos 22 grupos de barrios. Así la brecha de ingreso se compara directo con la de precio.

### 16 · Riesgo-retorno: el riesgo

**Ciro** · 0:55 min

“Medimos el riesgo de dos formas en cada segmento barrio por capacidad: el porcentaje de viviendas sin ingreso en el año y la dispersión del ingreso. Son 64 segmentos que cubren casi toda la oferta.”

“Si el mercado compensara, los segmentos con mayor ingreso deberían ser más riesgosos y los puntos subirían hacia la derecha. Pasa lo contrario: bajan. La correlación de Spearman es −0,47. Más ingreso, menos viviendas paradas.”

“Usamos Spearman porque compara rankings y así Puerto Madero no domina. Y es robusto: cambiando el umbral, la medida de riesgo o sacando outliers, el signo se mantiene. La excepción es Puerto Madero en departamentos chicos: el mayor ingreso de su tramo y un 27% sin ingreso.”

**Si preguntan**

- **Una publicación sin ingreso, ¿no puede ser nueva?** Sí, es una limitación: una publicación nueva sin reseñas cuenta como sin ingreso. Está en la diapositiva de limitaciones y un próximo paso es filtrar por antigüedad.

### 17 · Conclusión

**Martina** · 0:55 min

“La hipótesis se sostiene, con matices. Uno: el precio difiere entre barrios aun a igual tamaño, pero con un efecto moderado. Dos: se sostiene en parte; la asociación entre los perfiles del k-means y los barrios es débil, pero los profesionales y los de alta ocupación están más concentrados y más presentes en el corredor premium. Tres: la brecha se agranda del precio al ingreso, y los segmentos con menor ingreso tienen más viviendas sin ingreso.”

“En criollo: los barrios son distintos en precio, pero todavía más distintos en lo que ingresan, porque los barrios baratos además se alquilan menos y tienen más departamentos parados. Y eso no se compensa con menos riesgo.”

“Lo que no podemos afirmar es que el barrio cause el precio o el ingreso, ni que el ingreso sea rentabilidad: son asociaciones en una foto del mercado.”

### 18 · Limitaciones y próximos pasos

**Ciro** · 0:35 min

“Cada próximo paso responde a una limitación. Es una sola foto: sumaríamos varios relevamientos para medir la volatilidad en el tiempo. La ocupación es estimada: usaríamos el calendario diario. Las publicaciones nuevas cuentan como sin ingreso: filtraríamos por antigüedad. Y no tenemos costos ni valor de la vivienda: cruzaríamos con precios de venta para pasar del ingreso a la rentabilidad.”

### 19 · Cierre

**Martina** · 0:10 min

“Muchas gracias. Todo el código y los datos están en el repositorio. ¿Preguntas?”

## Otras preguntas probables

- **¿Por qué el trabajo no es causal?** Porque los datos son observacionales y de una sola foto: no hay asignación al azar ni comparación antes/después. Solo podemos describir asociaciones.
- **¿Cómo se reproduce el trabajo?** Se abre proyecto.Rproj y se corre script/00_correr_todo.R, que ejecuta los scripts 01 a 07 en orden. Los datos originales están en raw/ y nunca se modifican; todo lo procesado va a input/ y los resultados a output/.
- **¿Por qué usaron here::here()?** Para que las rutas funcionen en cualquier computadora sin cambiar nada, partiendo de la carpeta del proyecto.
- **¿Por qué viviendas completas en el ANOVA y en el ingreso?** Para comparar productos parecidos: una habitación privada y un departamento entero no son el mismo bien. Son el 90% de la oferta.
- **¿Qué otros tipos de alquiler hay?** Habitación privada, habitación compartida y habitación de hotel.
- **¿Por qué η² y no solo el p-valor?** Con casi 25 mil casos cualquier diferencia chica es significativa. El η² dice cuán grande es la diferencia.
- **¿Qué es ε²?** La versión del η² para Kruskal-Wallis: la parte de la variación del ingreso asociada al barrio (3%).
- **¿Por qué el gráfico de la diapositiva 14 está dado vuelta respecto de la instancia 3?** Es la misma información; lo trasponemos para que en la pantalla se lean los números. El original sigue en el repositorio.

## Checklist antes del oral

- Pegar el link del repositorio en la diapositiva de cierre antes de exportar.
- Exportar la presentación a PDF y probarla en la computadora del aula.
- Tener abierto RStudio con el proyecto por si piden ver código (scripts 04, 06 y 07 son los más probables).
- Si alguien instaló los paquetes antes: correr una vez install.packages("ggrepel").
- Ensayar con cronómetro: la exposición tiene que quedar en unos 15 minutos.
