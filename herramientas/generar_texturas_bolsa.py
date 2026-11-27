#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera las texturas de la piel "bolsa grande" del banco de CaprimedinaUI.

Uso:
    python herramientas/generar_texturas_bolsa.py
    python herramientas/generar_texturas_bolsa.py --vista-previa C:\\temp\\banco.png

Todas las texturas se guardan como TGA sin comprimir de 32 bits (BGRA) con
dimensiones potencia de dos, que es lo que acepta el cliente 3.3.5a.

Las texturas de borde son "9-slice": el dibujo de las esquinas vive en los 32
(o 16) pixeles de las esquinas y el centro de cada lado es uniforme, de modo que
World of Warcraft puede estirarlas sin deformarlas. Asi el banco puede crecer en
columnas/filas o cambiar de escala sin romper el diseno.
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------------------
# Paleta (cuero oscuro + herrajes dorados, a juego con el resto de la interfaz)
# ---------------------------------------------------------------------------
NEGRO = (16, 11, 7)
CUERO = (72, 53, 35)
CUERO_CLARO = (92, 69, 46)
CUERO_OSCURO = (46, 33, 22)
ORO = (192, 154, 82)
ORO_CLARO = (220, 184, 112)
ORO_OSCURO = (98, 72, 32)

DESTINO_POR_DEFECTO = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "CaprimedinaUI", "texturas",
)


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _value_noise(alto, ancho, celdas, rng):
    """Ruido de valor con interpolacion suave y envolvente (tileable)."""
    rejilla = rng.random((celdas, celdas)).astype(np.float32)

    ys = np.arange(alto, dtype=np.float32) * celdas / alto
    xs = np.arange(ancho, dtype=np.float32) * celdas / ancho

    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3.0 - 2.0 * fy)
    fx = fx * fx * (3.0 - 2.0 * fx)

    y1 = (y0 + 1) % celdas
    x1 = (x0 + 1) % celdas
    y0 %= celdas
    x0 %= celdas

    v00 = rejilla[np.ix_(y0, x0)]
    v10 = rejilla[np.ix_(y0, x1)]
    v01 = rejilla[np.ix_(y1, x0)]
    v11 = rejilla[np.ix_(y1, x1)]

    v0 = v00 * (1.0 - fx) + v10 * fx
    v1 = v01 * (1.0 - fx) + v11 * fx
    return v0 * (1.0 - fy[:, None]) + v1 * fy[:, None]


def _guardar_tga(imagen, ruta):
    """Escribe un TGA sin comprimir de 32 bits con origen abajo-izquierda.

    El bit 5 del descriptor se deja en 0 (origen inferior) y las filas se
    guardan de abajo hacia arriba: asi el cliente lo lee bien tanto si respeta
    el descriptor como si asume el origen clasico de TGA.
    """
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    img = imagen.convert("RGBA")
    ancho, alto = img.size
    pixeles = np.asarray(img, dtype=np.uint8)[::-1]  # fila inferior primero
    bgra = pixeles[:, :, [2, 1, 0, 3]]

    cabecera = bytearray(18)
    cabecera[2] = 2                       # TGA sin comprimir (true color)
    cabecera[12] = ancho & 0xFF
    cabecera[13] = (ancho >> 8) & 0xFF
    cabecera[14] = alto & 0xFF
    cabecera[15] = (alto >> 8) & 0xFF
    cabecera[16] = 32                     # 32 bits por pixel
    cabecera[17] = 0x08                   # 8 bits de alfa, origen abajo-izquierda

    with open(ruta, "wb") as fh:
        fh.write(bytes(cabecera))
        fh.write(bgra.tobytes())

    print("  %-26s %s" % (os.path.basename(ruta), img.size))


# ---------------------------------------------------------------------------
# Cuero
# ---------------------------------------------------------------------------
def textura_cuero(tam=128, base=CUERO, amplitud=9.0, semilla=7, vetas=1.0):
    rng = np.random.default_rng(semilla)

    n = (
        _value_noise(tam, tam, 4, rng) * 0.42
        + _value_noise(tam, tam, 8, rng) * 0.27
        + _value_noise(tam, tam, 16, rng) * 0.19
        + _value_noise(tam, tam, 32, rng) * 0.12
    )
    n = (n - 0.5) * 2.0

    grano = rng.normal(0.0, 1.0, (tam, tam)).astype(np.float32)
    valor = amplitud * n + 2.2 * grano

    # Vetas horizontales tipicas del cuero curtido.
    for _ in range(int(round(14 * vetas))):
        y = int(rng.integers(0, tam))
        largo = int(rng.integers(tam // 3, tam))
        x0 = int(rng.integers(0, tam))
        fuerza = float(rng.normal(0.0, 1.8))
        for i in range(largo):
            x = (x0 + i) % tam
            valor[y, x] += fuerza * math.sin(math.pi * i / largo) ** 2

    # Poros.
    for _ in range(150):
        x, y = (int(v) for v in rng.integers(0, tam, 2))
        tono = float(rng.integers(5, 14))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if rng.random() < 0.55:
                    valor[(y + dy) % tam, (x + dx) % tam] -= tono

    rgb = np.clip(np.array(base, dtype=np.float32)[None, None, :] + valor[..., None], 0, 255)
    alfa = np.full((tam, tam, 1), 255.0, dtype=np.float32)
    return Image.fromarray(np.concatenate([rgb, alfa], axis=2).astype(np.uint8), "RGBA")


def textura_cuero_solapa(tam=128):
    """Cuero un poco mas claro: la solapa tiene que leerse sobre el cuerpo."""
    return textura_cuero(tam, base=CUERO_CLARO, amplitud=7.0, semilla=23, vetas=0.8)


# ---------------------------------------------------------------------------
# Bordes 9-slice
# ---------------------------------------------------------------------------
def _perfil_borde(t, grosor, brillo=1.0, tono_oro=ORO):
    """Devuelve (r, g, b, a) para una profundidad t dentro del borde.

    Las proporciones se mantienen para grosores de 12 a 26 px: el filete dorado
    queda fino sobre un canto de cuero grueso, como una bolsa de verdad.
    """
    if t < 0:
        return (0, 0, 0, 0)

    g = float(grosor)
    borde = 0.088 * g            # canto exterior casi negro
    rampa = (0.088, 0.160)       # el dorado sube
    nucleo = (0.160, 0.190)      # linea brillante
    caida = (0.190, 0.330)       # el dorado baja
    ranura = (0.330, 0.440)      # surco oscuro
    cuero_fin = 0.730 * g        # desde aca, sombra interior

    if t < borde:
        return NEGRO + (255,)

    # Filete dorado.
    if t < caida[1] * g:
        if t < rampa[1] * g:
            f = (t - rampa[0] * g) / max(0.001, (rampa[1] - rampa[0]) * g)
            f = max(0.0, min(1.0, f)) * 0.75
        elif t < nucleo[1] * g:
            f = 1.0
        else:
            f = 1.0 - (t - caida[0] * g) / max(0.001, (caida[1] - caida[0]) * g)
            f = max(0.0, min(1.0, f)) * 0.8

        col = tuple(int(ORO_OSCURO[i] * (1.0 - f) + tono_oro[i] * f) for i in range(3))
        if nucleo[0] * g <= t <= (nucleo[1] + 0.015) * g:
            col = tuple(int(min(255, col[i] * 0.55 + ORO_CLARO[i] * 0.5 * brillo)) for i in range(3))
        return col + (255,)

    # Surco oscuro entre el filete y el cuero.
    if t < ranura[1] * g:
        return (30, 20, 12, 255)

    # Cuero del canto.
    if t < cuero_fin:
        f = (t - ranura[1] * g) / max(1.0, cuero_fin - ranura[1] * g)
        col = tuple(int(CUERO_OSCURO[i] * (1.0 - f) + CUERO[i] * f) for i in range(3))
        return col + (255,)

    # Sombra que cae hacia el centro de la ventana.
    f = (t - cuero_fin) / max(1.0, g - cuero_fin)
    a = int(round(150 * (1.0 - f) ** 1.5))
    return (0, 0, 0, a)


def textura_borde(tam=128, radio=22.0, grosor=22.0, semilla=31, brillo=1.0, tono_oro=ORO):
    yy, xx = np.mgrid[0:tam, 0:tam].astype(np.float32)
    c = (tam - 1) / 2.0
    mitad = tam / 2.0
    qx = np.abs(xx - c) - (mitad - radio)
    qy = np.abs(yy - c) - (mitad - radio)
    d = (
        np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qy, 0.0) ** 2)
        + np.minimum(np.maximum(qx, qy), 0.0)
        - radio
    )
    t = -d

    rng = np.random.default_rng(semilla)
    ruido = (_value_noise(tam, tam, 16, rng) - 0.5) * 7.0

    # Mascara con antialias en el borde exterior y en el interior.
    alfa = _smoothstep(0.0, 0.9, t) * (1.0 - _smoothstep(grosor - 0.9, grosor, t))

    salida = np.zeros((tam, tam, 4), dtype=np.float32)
    ys, xs = np.nonzero(alfa > 0.002)
    cache = {}
    for y, x in zip(ys, xs):
        tt = float(t[y, x])
        clave = round(tt * 4.0)
        if clave not in cache:
            cache[clave] = _perfil_borde(clave / 4.0, grosor, brillo, tono_oro)
        r, g, b, a = cache[clave]
        if 0.44 * grosor <= tt < 0.73 * grosor:
            r = max(0, min(255, int(r + ruido[y, x])))
            g = max(0, min(255, int(g + ruido[y, x] * 0.9)))
            b = max(0, min(255, int(b + ruido[y, x] * 0.8)))
        salida[y, x] = (r, g, b, a * float(alfa[y, x]))

    return Image.fromarray(np.clip(salida, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------
# Asa de cuerda
# ---------------------------------------------------------------------------
def textura_asa(ancho=256, alto=128, ss=3, semilla=5):
    W, H = ancho * ss, alto * ss
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dibujo = ImageDraw.Draw(img)

    cx, cy = W / 2.0, H * 0.96
    rx, ry = W * 0.42, H * 0.66

    pasos = 220
    puntos = []
    for i in range(pasos + 1):
        ang = math.pi + math.pi * i / pasos
        puntos.append((cx + rx * math.cos(ang), cy + ry * math.sin(ang)))

    def trazo(desplazamiento, grosor, color):
        pts = [(x + desplazamiento[0], y + desplazamiento[1]) for x, y in puntos]
        dibujo.line(pts, fill=color, width=grosor, joint="curve")

    # Contorno oscuro y cuerpo de la cuerda.
    trazo((0, 0), 27 * ss, (20, 13, 8, 255))
    trazo((0, 0), 20 * ss, (92, 63, 34, 255))
    trazo((-1.0 * ss, -1.6 * ss), 13 * ss, (112, 78, 42, 255))
    trazo((-2.0 * ss, -3.2 * ss), 5 * ss, (152, 110, 60, 230))

    # Vueltas de la cuerda (lineas perpendiculares al recorrido).
    rng = random.Random(semilla)
    for i in range(0, len(puntos) - 1, 7):
        x0, y0 = puntos[i]
        x1, y1 = puntos[i + 1]
        dx, dy = x1 - x0, y1 - y0
        largo = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / largo, dx / largo
        jitter = rng.uniform(-1.5, 1.5) * ss
        a = (x0 + nx * 11 * ss + jitter, y0 + ny * 11 * ss)
        b = (x0 - nx * 11 * ss + jitter, y0 - ny * 11 * ss)
        dibujo.line([a, b], fill=(58, 38, 19, 190), width=max(1, int(2.2 * ss)))

    # Cordones sueltos en las puntas.
    for signo in (-1, 1):
        x = cx + signo * rx
        dibujo.line([(x - 3 * ss, cy + 1 * ss), (x - 5 * ss, H - 1)],
                    fill=(30, 19, 10, 220), width=int(3 * ss))

    return img.resize((ancho, alto), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Remache, hebilla y puntada
# ---------------------------------------------------------------------------
def textura_remache(tam=32, ss=6):
    W = tam * ss
    yy, xx = np.mgrid[0:W, 0:W].astype(np.float32)
    cx = cy = (W - 1) / 2.0
    r = np.hypot(xx - cx, yy - cy) / (W * 0.40)

    alfa = 1.0 - _smoothstep(0.94, 1.02, r)
    altura = np.sqrt(np.clip(1.0 - r ** 2, 0.0, 1.0))
    brillo = 0.30 + 0.70 * altura

    base = np.array(ORO, dtype=np.float32)
    oscuro = np.array((74, 52, 20), dtype=np.float32)
    rgb = oscuro[None, None, :] + (base - oscuro)[None, None, :] * brillo[..., None]

    # Punto especular.
    spec = np.clip(1.0 - np.hypot(xx - cx + W * 0.10, yy - cy + W * 0.12) / (W * 0.16), 0, 1)
    rgb += (spec ** 2)[..., None] * np.array(ORO_CLARO, dtype=np.float32)[None, None, :] * 0.85

    aro = _smoothstep(0.86, 0.90, r) * (1.0 - _smoothstep(0.96, 1.0, r))
    rgb = rgb * (1.0 - aro[..., None] * 0.65)

    out = np.concatenate([np.clip(rgb, 0, 255), (alfa * 255)[..., None]], axis=2)
    return Image.fromarray(out.astype(np.uint8), "RGBA").resize((tam, tam), Image.LANCZOS)


def textura_hebilla(ancho=64, alto=32, ss=5):
    W, H = ancho * ss, alto * ss
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Correa de cuero.
    d.rounded_rectangle([0, H * 0.26, W, H * 0.74], radius=5 * ss, fill=(54, 38, 24, 255))
    d.rounded_rectangle([0, H * 0.26, W, H * 0.30], radius=3 * ss, fill=(84, 60, 38, 255))
    d.rounded_rectangle([0, H * 0.70, W, H * 0.74], radius=3 * ss, fill=(28, 19, 12, 255))

    # Marco dorado.
    mx0, my0 = W * 0.30, H * 0.12
    mx1, my1 = W * 0.70, H * 0.88
    d.rounded_rectangle([mx0, my0, mx1, my1], radius=4 * ss, fill=(238, 208, 128, 255))
    d.rounded_rectangle([mx0 + 3 * ss, my0 + 3 * ss, mx1 - 3 * ss, my1 - 3 * ss], radius=3 * ss,
                        fill=(86, 62, 26, 255))
    d.ellipse([W * 0.47, H * 0.42, W * 0.53, H * 0.58], fill=(250, 232, 172, 255))

    return img.resize((ancho, alto), Image.LANCZOS)


def textura_luz(tam=128):
    yy, xx = np.mgrid[0:tam, 0:tam].astype(np.float32)
    cx = cy = (tam - 1) / 2.0
    r = np.hypot(xx - cx, yy - cy) / (tam * 0.52)
    a = np.clip(1.0 - r, 0.0, 1.0) ** 2 * 30.0
    rgb = np.full((tam, tam, 3), (255, 236, 200), dtype=np.float32)
    return Image.fromarray(np.concatenate([rgb, a[..., None]], axis=2).astype(np.uint8), "RGBA")


def textura_puntada(ancho=16, alto=8):
    arr = np.zeros((alto, ancho, 4), dtype=np.uint8)
    arr[3:5, :, :] = (26, 18, 11, 120)
    arr[3, 2:12] = (226, 198, 142, 235)
    arr[4, 2:12] = (196, 166, 112, 215)
    return Image.fromarray(arr, "RGBA")


# ---------------------------------------------------------------------------
# Composicion 9-slice (solo para la vista previa)
# ---------------------------------------------------------------------------
def _pegar(destino, pieza, x, y):
    destino.alpha_composite(pieza, (int(round(x)), int(round(y))))


def _nueve_trozos(destino, tex, x, y, w, h, esquina):
    w = int(round(w))
    h = int(round(h))
    if w <= 0 or h <= 0:
        return
    e = esquina
    esquinas = (
        (0, 0, x, y),
        (tex.width - e, 0, x + w - e, y),
        (0, tex.height - e, x, y + h - e),
        (tex.width - e, tex.height - e, x + w - e, y + h - e),
    )
    for sx, sy, dx, dy in esquinas:
        _pegar(destino, tex.crop((sx, sy, sx + e, sy + e)), dx, dy)

    if w > 2 * e:
        for sy, dy in ((0, y), (tex.height - e, y + h - e)):
            franja = tex.crop((tex.width // 2, sy, tex.width // 2 + 1, sy + e))
            _pegar(destino, franja.resize((w - 2 * e, e), Image.BILINEAR), x + e, dy)
    if h > 2 * e:
        for sx, dx in ((0, x), (tex.width - e, x + w - e)):
            franja = tex.crop((sx, tex.height // 2, sx + e, tex.height // 2 + 1))
            _pegar(destino, franja.resize((e, h - 2 * e), Image.BILINEAR), dx, y + e)


def _degradado(w, h, color, a0, a1):
    arr = np.zeros((int(h), int(w), 4), dtype=np.float32)
    f = np.linspace(a0, a1, int(h), dtype=np.float32)[:, None]
    arr[..., 0] = color[0]
    arr[..., 1] = color[1]
    arr[..., 2] = color[2]
    arr[..., 3] = f * 255.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _degradado_h(w, h, color, a0, a1):
    arr = np.zeros((int(h), int(w), 4), dtype=np.float32)
    f = np.linspace(a0, a1, int(w), dtype=np.float32)[None, :]
    arr[..., 0] = color[0]
    arr[..., 1] = color[1]
    arr[..., 2] = color[2]
    arr[..., 3] = f * 255.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _tile(destino, tex, x, y, w, h):
    for yy in range(0, int(h), tex.height):
        for xx in range(0, int(w), tex.width):
            _pegar(destino, tex, x + xx, y + yy)


# ---------------------------------------------------------------------------
# Generacion
# ---------------------------------------------------------------------------
def textura_degradado(tam=128, horizontal=False):
    """Rampa blanca con alfa 255 arriba/izquierda y 0 abajo/derecha."""
    img = Image.new("RGBA", (tam, tam), (255, 255, 255, 255))
    px = img.load()
    for y in range(tam):
        for x in range(tam):
            t = (x if horizontal else y) / float(tam - 1)
            px[x, y] = (255, 255, 255, int(round(255 * (1.0 - t))))
    return img


def generar(destino):
    print("Generando texturas de la bolsa del banco en:\n  %s" % destino)

    _guardar_tga(textura_cuero(128, base=(56, 41, 28), amplitud=10.0, semilla=7),
                 os.path.join(destino, "bolsa_cuerpo.tga"))
    _guardar_tga(textura_cuero_solapa(128),
                 os.path.join(destino, "bolsa_solapa_cuerpo.tga"))
    _guardar_tga(textura_borde(128, radio=24, grosor=26, semilla=31),
                 os.path.join(destino, "bolsa_borde.tga"))
    _guardar_tga(textura_borde(64, radio=10, grosor=12, semilla=41, brillo=0.95),
                 os.path.join(destino, "bolsa_borde_peq.tga"))
    _guardar_tga(textura_borde(64, radio=12, grosor=15, semilla=47, brillo=1.0),
                 os.path.join(destino, "bolsa_solapa_borde.tga"))
    _guardar_tga(textura_asa(256, 128), os.path.join(destino, "bolsa_asa.tga"))
    _guardar_tga(textura_remache(32), os.path.join(destino, "remache.tga"))
    _guardar_tga(textura_hebilla(64, 32), os.path.join(destino, "bolsa_hebilla.tga"))
    _guardar_tga(textura_puntada(16, 8), os.path.join(destino, "puntada.tga"))
    _guardar_tga(textura_luz(128), os.path.join(destino, "bolsa_luz.tga"))
    _guardar_tga(textura_puntada(16, 8).rotate(90, expand=True), os.path.join(destino, "puntada_v.tga"))
    _guardar_tga(textura_degradado(128, horizontal=False), os.path.join(destino, "degradado_v.tga"))
    _guardar_tga(textura_degradado(128, horizontal=True), os.path.join(destino, "degradado_h.tga"))


# ---------------------------------------------------------------------------
# Vista previa (aproximacion del layout de bag.lua)
# ---------------------------------------------------------------------------
def _fuente(tam):
    for ruta in (
        r"C:\Windows\Fonts\frizqt__.TTF",
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\arial.ttf",
    ):
        if os.path.exists(ruta):
            try:
                return ImageFont.truetype(ruta, tam)
            except OSError:
                pass
    return ImageFont.load_default()


def vista_previa(texturas, salida, cols=10, filas_banco=28, bolsas=(20, 20)):
    cap = 30
    alto_solapa = 62
    top_solapa = 0
    pad_sup = top_solapa + alto_solapa + 12
    pad_inf = 56
    boton = 41

    ancho = cap * 2 + cols * boton  # cap = BANK_SIDE_PAD
    alto = pad_sup + 20 + math.ceil(filas_banco / cols) * boton + 15
    for n in bolsas:
        alto += 20 + math.ceil(n / cols) * boton + 15
    alto += pad_inf

    margen_x, margen_y = 140, 130
    lienzo = Image.new("RGBA", (ancho + margen_x * 2, alto + margen_y + 40), (33, 27, 21, 255))

    cuerpo = Image.open(os.path.join(texturas, "bolsa_cuerpo.tga")).convert("RGBA")
    solapa_cuerpo = Image.open(os.path.join(texturas, "bolsa_solapa_cuerpo.tga")).convert("RGBA")
    borde = Image.open(os.path.join(texturas, "bolsa_borde.tga")).convert("RGBA")
    borde_peq = Image.open(os.path.join(texturas, "bolsa_borde_peq.tga")).convert("RGBA")
    borde_solapa = Image.open(os.path.join(texturas, "bolsa_solapa_borde.tga")).convert("RGBA")
    asa = Image.open(os.path.join(texturas, "bolsa_asa.tga")).convert("RGBA")
    puntada = Image.open(os.path.join(texturas, "puntada.tga")).convert("RGBA")
    puntada_v = Image.open(os.path.join(texturas, "puntada_v.tga")).convert("RGBA")
    remache = Image.open(os.path.join(texturas, "remache.tga")).convert("RGBA")
    hebilla = Image.open(os.path.join(texturas, "bolsa_hebilla.tga")).convert("RGBA")

    ox, oy = margen_x, margen_y

    # Cuerpo de cuero.
    marco = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    _tile(marco, cuerpo, 0, 0, ancho, alto)
    _pegar(lienzo, marco, ox, oy)

    # Luz suave del centro de la bolsa.
    luz = Image.open(os.path.join(texturas, "bolsa_luz.tga")).convert("RGBA")
    _pegar(lienzo, luz.resize((ancho - 52, alto - pad_sup - 30), Image.BILINEAR),
           ox + 26, oy + pad_sup - 8)

    # Volumen: luz arriba, sombra abajo y en los costados.
    _pegar(lienzo, _degradado(ancho - 52, 80, (255, 236, 192), 0.08, 0.0), ox + 26, oy + 68)
    _pegar(lienzo, _degradado(ancho - 52, 110, (0, 0, 0), 0.0, 0.34), ox + 26, oy + alto - 34 - 110)
    _pegar(lienzo, _degradado_h(30, alto - 100, (0, 0, 0), 0.30, 0.0), ox + 26, oy + 66)
    _pegar(lienzo, _degradado_h(30, alto - 100, (0, 0, 0), 0.0, 0.30), ox + ancho - 56, oy + 66)

    # Grilla de items.
    d = ImageDraw.Draw(lienzo)
    y = oy + pad_sup
    for n in (filas_banco,) + tuple(bolsas):
        etiqueta = "BANCO PRINCIPAL" if n == filas_banco else "CONTENIDO DE BOLSA"
        d.text((ox + cap + 10, y + 3), etiqueta, font=_fuente(11), fill=(255, 204, 102, 255))
        y += 20
        for i in range(n):
            cx = ox + cap + (i % cols) * boton
            cy = y + (i // cols) * boton
            d.rectangle([cx + 2, cy + 2, cx + boton - 3, cy + boton - 3], fill=(8, 6, 5, 210),
                        outline=(58, 47, 34, 255))
        y += math.ceil(n / cols) * boton + 15

    # Costuras del cuerpo (siguen el borde interior).
    for x in range(cap + 2, ancho - cap - 2, 14):
        _pegar(lienzo, puntada, ox + x, oy + alto - 18)
    puntada_v_dim = puntada_v.copy()
    puntada_v_dim.putalpha(puntada_v.getchannel("A").point(lambda v: int(v * 0.55)))
    for yy in range(pad_sup + 8, alto - 34, 14):
        _pegar(lienzo, puntada_v_dim, ox + 17, oy + yy)
        _pegar(lienzo, puntada_v_dim, ox + ancho - 25, oy + yy)

    # Borde del cuerpo.
    _nueve_trozos(lienzo, borde, ox, oy, ancho, alto, 32)

    # Asa detras de la solapa.
    ancho_asa = max(150, min(int((ancho - 4) * 0.60), 320))
    alto_asa = int(ancho_asa * 0.46)
    _pegar(lienzo, asa.resize((ancho_asa, alto_asa), Image.LANCZOS),
           ox + ancho / 2 - ancho_asa / 2, oy + 22 - alto_asa)

    # Sombra bajo la solapa.
    _pegar(lienzo, _degradado(ancho - 48, 18, (0, 0, 0), 0.62, 0.0),
           ox + 24, oy + top_solapa + alto_solapa + 1)

    # Solapa.
    solapa = Image.new("RGBA", (ancho - 4, alto_solapa), (0, 0, 0, 0))
    _tile(solapa, solapa_cuerpo, 0, 0, ancho - 4, alto_solapa)
    _pegar(lienzo, solapa, ox + 2, oy + top_solapa)
    _nueve_trozos(lienzo, borde_solapa, ox + 2, oy + top_solapa, ancho - 4, alto_solapa, 16)

    d.text((ox + ancho / 2, oy + top_solapa + 19), "BANCO CAPRIMEDINA", font=_fuente(15),
           fill=(255, 226, 140, 255), anchor="mm")

    for x in range(24, ancho - 24, 14):
        _pegar(lienzo, puntada, ox + x, oy + top_solapa + alto_solapa - 19)

    # Hebilla.
    _pegar(lienzo, hebilla.resize((40, 20), Image.LANCZOS),
           ox + ancho / 2 - 20, oy + top_solapa + alto_solapa - 13)

    # Remaches inferiores.
    for rx in (28, ancho - 44):
        _pegar(lienzo, remache, ox + rx, oy + alto - 30)

    # Placa de compra.
    ancho_placa = int(max(230, min(ancho * 0.60, 360)))
    px = ox + (ancho - ancho_placa) / 2
    py = oy + alto - 54
    _pegar(lienzo, cuerpo.crop((0, 0, 1, 1)).resize((ancho_placa, 42)), px, py)
    _nueve_trozos(lienzo, borde_peq, px, py, ancho_placa, 42, 16)
    d.rectangle([px + 14, py + 11, px + 114, py + 31], fill=(64, 52, 28, 255),
                outline=(240, 212, 130, 255))
    d.text((px + 64, py + 21), "Comprar", font=_fuente(11), fill=(255, 226, 150, 255), anchor="mm")

    # Bolsillo lateral (bolsas del banco).
    p_ancho, p_alto = 72, 320
    p_x, p_y = ox - p_ancho + 10, oy + 16
    _pegar(lienzo, cuerpo.crop((0, 0, 1, 1)).resize((p_ancho, p_alto)), p_x, p_y)
    _nueve_trozos(lienzo, borde_peq, p_x, p_y, p_ancho, p_alto, 16)
    d.text((p_x + p_ancho / 2, p_y + 13), "BOLSAS", font=_fuente(10),
           fill=(255, 214, 120, 255), anchor="mm")
    for i in range(7):
        bx, by = p_x + 17, p_y + 32 + i * 40
        d.rectangle([bx, by, bx + 38, by + 38], fill=(8, 6, 5, 210), outline=(58, 47, 34, 255))

    lienzo.convert("RGB").save(salida)
    print("Vista previa: %s" % salida)


def vista_previa_mochila(texturas, salida, cols=10, side_bags=True):
    cap = 30
    alto_solapa = 62
    top_solapa = 0
    pad_sup = top_solapa + alto_solapa + 12
    pdw, pdh = 220, 310
    alto_bolsas = 52
    alto_prof1, alto_prof2 = 100, 130
    boton = 41
    pad_inf = 56

    start_x = cap + pdw + 24
    ancho = start_x + cols * boton + cap

    # Alturas como en OrganizeItems
    alto_izq = pad_sup + pdh + 8 + alto_bolsas + 8 + alto_prof1 + 8 + alto_prof2 + 8
    filas = math.ceil(16 / cols)
    alto_der = pad_sup + 20 + filas * boton + 10 + 4 * (20 + filas * boton + 10) + 15
    alto = max(alto_izq, alto_der) + pad_inf

    margen_x, margen_y = 150, 140
    lienzo = Image.new("RGBA", (ancho + margen_x * 2, alto + margen_y + 30), (33, 27, 21, 255))

    cuerpo = Image.open(os.path.join(texturas, "bolsa_cuerpo.tga")).convert("RGBA")
    solapa_cuerpo = Image.open(os.path.join(texturas, "bolsa_solapa_cuerpo.tga")).convert("RGBA")
    borde = Image.open(os.path.join(texturas, "bolsa_borde.tga")).convert("RGBA")
    borde_peq = Image.open(os.path.join(texturas, "bolsa_borde_peq.tga")).convert("RGBA")
    borde_solapa = Image.open(os.path.join(texturas, "bolsa_solapa_borde.tga")).convert("RGBA")
    asa = Image.open(os.path.join(texturas, "bolsa_asa.tga")).convert("RGBA")
    puntada = Image.open(os.path.join(texturas, "puntada.tga")).convert("RGBA")
    puntada_v = Image.open(os.path.join(texturas, "puntada_v.tga")).convert("RGBA")
    remache = Image.open(os.path.join(texturas, "remache.tga")).convert("RGBA")
    hebilla = Image.open(os.path.join(texturas, "bolsa_hebilla.tga")).convert("RGBA")

    ox, oy = margen_x, margen_y
    d = ImageDraw.Draw(lienzo)
    fuente = _fuente(11)
    fuente_t = _fuente(15)

    def slot(x, y, s=36):
        d.rectangle([x + 1, y + 1, x + s - 2, y + s - 2], fill=(8, 6, 5, 230),
                    outline=(58, 47, 34, 255))

    # Cuerpo
    marco = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    _tile(marco, cuerpo, 0, 0, ancho, alto)
    _pegar(lienzo, marco, ox, oy)
    _pegar(lienzo, _degradado(ancho - 52, 80, (255, 236, 192), 0.08, 0.0), ox + 26, oy + 66)
    _pegar(lienzo, _degradado(ancho - 52, 110, (0, 0, 0), 0.0, 0.34), ox + 26, oy + alto - 30 - 110)
    _pegar(lienzo, _degradado_h(30, alto - 100, (0, 0, 0), 0.30, 0.0), ox + 26, oy + 66)
    _pegar(lienzo, _degradado_h(30, alto - 100, (0, 0, 0), 0.0, 0.30), ox + ancho - 56, oy + 66)

    # Ventana de vestuario
    if side_bags:
        px, py = ox + cap, oy + pad_sup
        d.rectangle([px, py, px + pdw, py + pdh], fill=(14, 11, 8, 255))
        d.rectangle([px + 12, py + 12, px + pdw - 12, py + pdh - 12], fill=(30, 24, 18, 255))
        _pegar(lienzo, _degradado(pdw - 40, pdh - 60, (120, 100, 78), 0.35, 0.0),
               px + 20, py + 30)
        _nueve_trozos(lienzo, borde_peq, px, py, pdw, pdh, 16)
        for i in range(8):
            slot(px + 16, py + 16 + i * 36, 32)
            slot(px + pdw - 48, py + 16 + i * 36, 32)
        for i in range(3):
            slot(px + 60 + i * 36, py + pdh - 48, 32)
        for rx, ry in ((6, 6), (pdw - 16, 6), (6, pdh - 16), (pdw - 16, pdh - 16)):
            _pegar(lienzo, remache.resize((10, 10), Image.LANCZOS), px + rx, py + ry)

        # Tira de bolsas
        by = py + pdh + 8
        _pegar(lienzo, cuerpo.crop((0, 0, 1, 1)).resize((pdw, alto_bolsas)), px, by)
        _nueve_trozos(lienzo, borde_peq, px, by, pdw, alto_bolsas, 16)
        for i in range(5):
            slot(px + 16 + i * 38, by + (alto_bolsas - 36) // 2, 36)

        # Profesiones
        py2 = by + alto_bolsas + 8
        for alto_p, titulo, filas in ((alto_prof1, "Principales", 2), (alto_prof2, "Secundarias", 3)):
            _pegar(lienzo, solapa_cuerpo.crop((0, 0, 1, 1)).resize((pdw, alto_p)), px, py2)
            _nueve_trozos(lienzo, borde_peq, px, py2, pdw, alto_p, 16)
            d.text((px + 16, py2 + 9), titulo, font=fuente, fill=(255, 214, 112, 255))
            d.line([(px + 16, py2 + 28), (px + pdw - 16, py2 + 28)], fill=(20, 14, 9, 255), width=1)
            d.line([(px + 16, py2 + 29), (px + pdw - 16, py2 + 29)], fill=(200, 165, 95, 55), width=1)
            for f in range(filas):
                ry = py2 + 32 + f * 28
                d.rectangle([px + 20, ry + 2, px + 40, ry + 22], fill=(12, 9, 7, 255),
                            outline=(60, 48, 34, 255))
                d.rectangle([px + 48, ry + 8, px + 150, ry + 15], fill=(150, 130, 95, 255))
            py2 += alto_p + 8

        # Costura vertical
        sx = ox + cap + pdw + 12
        d.line([(sx, oy + 80), (sx, oy + alto - 30)], fill=(15, 10, 6, 255), width=1)
        for yy in range(84, alto - 30, 16):
            _pegar(lienzo, puntada_v, sx - 4, oy + yy)

    # Rejilla de bolsas
    x0 = ox + (start_x if side_bags else cap)
    y = oy + pad_sup
    for n, etiqueta in ((16, "MOCHILA PRINCIPAL"), (16, "BOLSA 1"), (16, "BOLSA 2"), (16, "BOLSA 3"), (16, "BOLSA 4")):
        d.text((x0 + 20, y + 3), etiqueta, font=fuente, fill=(255, 204, 102, 255))
        y += 20
        for i in range(n):
            slot(x0 + (i % cols) * boton, y + (i // cols) * boton, boton - 2)
        y += math.ceil(n / cols) * boton + 10

    # Borde y solapa
    _nueve_trozos(lienzo, borde, ox, oy, ancho, alto, 32)
    ancho_asa = max(140, min(int((ancho - 4) * 0.55), 300))
    alto_asa = int(ancho_asa * 0.42)
    _pegar(lienzo, asa.resize((ancho_asa, alto_asa), Image.LANCZOS),
           ox + ancho / 2 - ancho_asa / 2, oy + 22 - alto_asa)
    _pegar(lienzo, _degradado(ancho - 48, 18, (0, 0, 0), 0.62, 0.0), ox + 24, oy + top_solapa + alto_solapa + 1)
    solapa = Image.new("RGBA", (ancho - 4, alto_solapa), (0, 0, 0, 0))
    _tile(solapa, solapa_cuerpo, 0, 0, ancho - 4, alto_solapa)
    _pegar(lienzo, solapa, ox + 2, oy + top_solapa)
    _nueve_trozos(lienzo, borde_solapa, ox + 2, oy + top_solapa, ancho - 4, alto_solapa, 16)
    d.text((ox + ancho / 2, oy + top_solapa + 19), "MOCHILA CAPRIMEDINA", font=fuente_t,
           fill=(255, 226, 140, 255), anchor="mm")
    _pegar(lienzo, hebilla.resize((40, 20), Image.LANCZOS),
           ox + ancho / 2 - 20, oy + top_solapa + alto_solapa - 13)
    for x in range(24, ancho - 24, 14):
        _pegar(lienzo, puntada, ox + x, oy + top_solapa + alto_solapa - 11)

    # Remaches y placa de dinero
    for rx in (28, ancho - 44):
        _pegar(lienzo, remache, ox + rx, oy + alto - 30)
    plw, plh = 190, 34
    ppx, ppy = ox + ancho - 30 - plw, oy + alto - 14 - plh
    _pegar(lienzo, solapa_cuerpo.crop((0, 0, 1, 1)).resize((plw, plh)), ppx, ppy)
    _nueve_trozos(lienzo, borde_peq, ppx, ppy, plw, plh, 16)
    d.text((ppx + plw / 2, ppy + plh / 2), "1.480", font=fuente, fill=(255, 226, 150, 255), anchor="mm")

    lienzo.convert("RGB").save(salida)
    print("Vista previa mochila: %s" % salida)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Genera las texturas de la bolsa del banco.")
    parser.add_argument("--destino", default=DESTINO_POR_DEFECTO,
                        help="Carpeta donde se escriben los .tga (por defecto CaprimedinaUI/texturas)")
    parser.add_argument("--vista-previa", default=None,
                        help="Ruta del PNG de vista previa (opcional)")
    parser.add_argument("--cols", type=int, default=10)
    parser.add_argument("--mochila", action="store_true",
                        help="Genera la vista previa de la mochila en vez de la del banco")
    parser.add_argument("--bolsas", default="20,20",
                        help="Slots de cada bolsa del banco, separados por coma")
    args = parser.parse_args(argv)

    generar(args.destino)

    if args.vista_previa:
        if args.mochila:
            vista_previa_mochila(args.destino, args.vista_previa, cols=args.cols)
        else:
            bolsas = tuple(int(v) for v in args.bolsas.split(",") if v.strip())
            vista_previa(args.destino, args.vista_previa, cols=args.cols, bolsas=bolsas)
    return 0


if __name__ == "__main__":
    sys.exit(main())
