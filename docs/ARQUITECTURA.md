# Arquitectura de CaprimedinaUI

Este documento describe la organización interna del addon para quien quiera
leerlo, modificarlo o añadir módulos.

## Orden de carga (TOC)

`core.lua` se carga primero y define el espacio de nombres compartido `C`.
Después se cargan `config/config.lua` y `ui.lua`, que crean el menú y el HUD.
Los módulos de `modulos/` y `botones/` se cargan a continuación.

```
core.lua
config\config.lua
ui.lua
modulos\barra.lua
modulos\bag.lua
modulos\SmartClick.lua
modulos\vida.lua
modulos\teclado.lua
modulos\chat.lua
modulos\ventanas.lua
modulos\escala.lua
botones\botones.lua
botones\dpad.lua
```

## Módulos

| Archivo | Responsabilidad |
| --- | --- |
| `core.lua` | Utilidades (`C.Print`, fuentes, botones estilizados), base de datos inicial (`C.InitDB`) y skin compartido (anillos, discos, brillos). |
| `ui.lua` | HUD principal, anclajes arrastrables, modo edición (`/capri`), minimapa, bolitas de jugador/objetivo, menú contextual de escalas y barra de experiencia. |
| `config/config.lua` | Menú de configuración y botón del minimapa (mover, click para abrir). |
| `modulos/barra.lua` | Barras de acción curvas, bindings (`/capribind`), brillo de pulsación. |
| `modulos/bag.lua` | Bolsas y banco personalizados (incluye `BankFrame` propio y la piel de bolsa de la mochila y del banco). |
| `modulos/SmartClick.lua` | Clic inteligente y cámara automática para pantallas táctiles. |
| `modulos/vida.lua` | Texto de vida/maná con porcentaje en combate. |
| `modulos/teclado.lua` | Teclado virtual en pantalla (`/vkb`). |
| `modulos/chat.lua` | Comportamiento y protección del chat. |
| `modulos/ventanas.lua` | Ventanas Grandes: escalado automático y coherente de ventanas de Blizzard. |
| `modulos/escala.lua` | Ajuste de escala de interfaz (`/escala`). |
| `botones/botones.lua` | Botones Atacar, Objetivo y Saltar. |
| `botones/dpad.lua` | Joystick virtual indicador de movimiento. |

## Datos guardados

- `CaprimedinaUIDB`: ajustes por cuenta (interfaz, ventanas, minimapa, botones, dpad, etc.).
- `SmartClickDB`: ajustes por personaje (SmartClick).

Ambos se almacenan en `WTF/Account/<CUENTA>/SavedVariables/`.

## Convenciones

- Cada módulo se registra mediante `SlashCmdList` cuando tiene comandos.
- Los anclajes se guardan con `point/relPoint/x/y` en la base de datos y se
  aplican en `VARIABLES_LOADED`.
- La mayoría de los módulos comprueban `CapriUIEnabled()` o una función
  `*Enabled()` propia para respetar la activación/desactivación.
- El módulo de ventanas no toca chat, bolitas, barras ni botones: solo frames
  de su lista blanca.
- `BankFrame` lo gestiona `bag.lua` y no debe tocarse desde `ventanas.lua`.

## Notas específicas de Android

- El escalado de ventanas usa el alto de pantalla (768 unidades) para que
  todas las ventanas quepan sin salirse.
- El joystick es solo un indicador visual de las teclas de movimiento.
- El teclado virtual aparece automáticamente al escribir.
