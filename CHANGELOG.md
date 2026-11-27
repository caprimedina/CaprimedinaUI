# Historial de cambios

Todos los cambios importantes de CaprimedinaUI. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
[Versionado Semántico](https://semver.org/lang/es/).

## [5.1.0] - 2026-11-27

**Mochila y banco mejorados:** las dos ventanas pasan a tener diseño de bolsa
grande de cuero, con solapa, asa, costuras y remaches.

### Cambiado

- El banco se ve ahora como una bolsa grande de cuero: cuerpo con canto de cuero y filete dorado, solapa con el título, asa de cuerda, hebilla, costuras, remaches y bolsillo lateral para las bolsas del banco. El arte se recompone al cambiar columnas, filas, títulos o escala (`LayoutBankSkin`).
- La mochila del personaje usa la misma piel de bolsa grande: cuerpo de cuero, solapa con título, asa, hebilla, costuras, remaches y placa de dinero. La **ventana de vestuario** queda enmarcada en cuero con remaches en las esquinas, y la tira de bolsas y los paneles de profesión (Principales/Secundarias) pasan a cuero con costura bajo el título. El arte se recompone con `LayoutBagSkin` al cambiar columnas, títulos o escala.
- El **llavero** ya no se mezcla con las bolsas: hay un botón de llave en la solapa que abre una página propia con sus **32 ranuras**; el título cambia a `LLAVERO` y, al pulsar cualquier bolsa de la tira, se vuelve a las bolsas.
- El **precio de las ranuras del banco** se muestra con las mismas monedas que la mochila (`SmallMoneyFrame`), junto al botón *Comprar*, en lugar de `Costo: Xg Xs Xc`. Si el banco está lleno se sigue mostrando `Ranuras al maximo`.

### Corregido

- El banco y la mochila respetan el ajuste **Tamaño** (faltaba aplicar la escala al marco al reorganizarlo).
- Los bordes de la bolsa, la solapa y el bolsillo se dibujan con esquinas fijas y lados estirados (`CrearBorde9`). El cliente 3.3.5 no acepta una textura cuadrada como `edgeFile` de `SetBackdrop`: la parte en 8 tiras y el borde salía con "dientes".
- El bolsillo de las bolsas del banco es más ancho y sus botones ya no quedan pegados al canto.
- La sombra derecha de la mochila salía **azul** porque la llamada al degradado tenía un argumento de menos (el azul 0.30 se colaba como color). Las sombras usan ahora texturas de degradado pregrabadas (`degradado_v.tga`/`degradado_h.tga`) y ya no dependen de `SetGradientAlpha`.
- El **costo de las ranuras del banco** se dibujaba detrás de la placa y no se veía; ahora es hijo de la placa y aparece junto al botón *Comprar* (o "Ranuras al maximo" centrado).
- Si cierras la mochila estando en la página del **llavero**, la página se reinicia: el llavero se cierra y al volver a abrir aparece la mochila normal (antes se reabría el llavero).

### Añadido

- `herramientas/generar_texturas_bolsa.py`: genera de forma reproducible las texturas TGA de la bolsa (cuero, bordes, asa, hebilla, remaches, puntadas y degradados) y las vistas previas del banco (`--vista-previa`) y de la mochila (`--mochila`).
- `herramientas/probar_piel_banco.py`: prueba de humo que carga `bag.lua` con un stub del API y comprueba el banco y la mochila en varios tamaños, escalas y estados (23 escenarios, incluida la página del llavero y las monedas del costo del banco).

## [5.0.0] - 2026-11-25

Primera versión publicada en GitHub.

### Añadido

- Interfaz táctil completa para WoW 3.3.5a en Android/Winlator.
- Botones de acción grandes: Atacar, Objetivo y Saltar, con brillo al pulsar.
- Joystick virtual con anillo dorado y círculo interior que se agranda al moverse.
- Teclado virtual en pantalla.
- SmartClick y cámara automática.
- Bolsas y banco personalizados con escala, columnas, títulos y bloqueo.
- Barras de acción curvas con asignación de teclas.
- Bolitas de Jugador y Objetivo rediseñadas, arrastrables y escalables.
- Minimapa escalable con buffs y debuffs que lo siguen y crecen con él.
- Ventanas Grandes: escalado automático y coherente de las ventanas de Blizzard.
- Modo edición con anclajes visibles y menús por elemento.
- Escala de interfaz integrada.
- Modo rendimiento mediante `/perf`.
- Ajustes guardados en `CaprimedinaUIDB` y `SmartClickDB`.

### Notas

- El mapa del mundo queda fuera del escalado automático para no salirse de la pantalla.
- Compatible con el cliente 3.3.5a (build 12340), interfaz `30300`.
- Créditos y licencia: todo el código y las texturas son creación original de Caprimedina.
