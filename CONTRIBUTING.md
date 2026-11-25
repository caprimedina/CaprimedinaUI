# Contribuir a CaprimedinaUI

Gracias por querer mejorar el addon. Esta guía es breve: lo importante es no
romper la experiencia en Android/Winlator.

## Antes de empezar

- El addon está pensado para **WoW 3.3.5a (build 12340)**, interfaz `30300`.
- No se usan librerías externas ni frameworks: solo Lua y la API del cliente.
- Prueba cualquier cambio dentro del juego antes de enviarlo.

## Cómo probar

1. Copia la carpeta `CaprimedinaUI` en `Interface/AddOns/`.
2. Entra al juego con `/console scriptErrors 1` activado.
3. Usa `/reload` tras cada cambio de código.
4. Comprueba al menos: botones de acción, joystick, bolsas, barras y ventanas.

## Estilo de código

- Lua 5.1 (el que usa 3.3.5a): evita sintaxis moderna.
- Indentación de **4 espacios**, sin tabulaciones.
- Nombres de funciones y variables en español cuando sea posible, siguiendo el
  estilo del archivo que estés tocando.
- No añadas dependencias ni archivos que no se usen.
- Mantén los comentarios útiles y en español.

## Enviar cambios

1. Haz un fork del repositorio.
2. Crea una rama descriptiva: `fix/brillo-objetivo`, `feat/dpad-nativo`.
3. Haz commits pequeños y claros.
4. Abre un Pull Request explicando qué cambia y cómo lo probaste.

## Reportar errores

Usa la plantilla de **Reporte de error** e incluye:

- Versión del addon.
- Dispositivo, versión de Android y de Winlator.
- Pasos para reproducirlo.
- Capturas o vídeo si es visual.
- Errores de Lua, si aparecen.
