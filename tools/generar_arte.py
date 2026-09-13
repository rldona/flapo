#!/usr/bin/env python3
"""Genera el arte placeholder de Flapo en la paleta del proyecto.

Se ejecuta con el venv del repo:

    ./.venv/bin/python tools/generar_arte.py

Todo el arte que no es Flapo se dibuja aquí en vez de a mano, por dos motivos:
es reproducible (si cambia la paleta, se regenera) y queda documentado qué
forma tiene cada pieza y por qué. Ver docs/art-guide.md y ADR-0016.
"""

from PIL import Image

# --- Paleta (docs/art-guide.md) -----------------------------------------
OUTLINE = (0x26, 0x3B, 0x46, 255)
CUERPO = (0x3F, 0x71, 0x88, 255)
CUERPO_S = (0x31, 0x59, 0x6C, 255)
TRIPA = (0xF2, 0xD9, 0xA7, 255)
TRIPA_S = (0xD5, 0xB8, 0x7D, 255)
PICO = (0xE6, 0xB8, 0x4A, 255)
PICO_S = (0xB8, 0x86, 0x32, 255)
OJO = (0x18, 0x26, 0x2D, 255)
BRILLO = (0xFF, 0xF4, 0xD6, 255)
CORAL = (0xD9, 0x89, 0x72, 255)
CIELO = (0x7C, 0xB3, 0xD7, 255)
NUBE = (0xBF, 0xD9, 0xEC, 255)
EDIFICIO = (0x50, 0x69, 0x82, 255)
EDIFICIO_LEJOS = (0x7C, 0x9A, 0xB5, 255)
SUELO = (0xD0, 0xAE, 0x62, 255)
SUELO_S = (0xB8, 0x86, 0x32, 255)
NADA = (0, 0, 0, 0)

DESTINO = "assets/sprites"


def lienzo(w, h, fondo=NADA):
    return Image.new("RGBA", (w, h), fondo)


def rect(img, x0, y0, x1, y1, color):
    """Rectángulo relleno, coordenadas inclusivas."""
    p = img.load()
    for y in range(max(0, y0), min(img.height, y1 + 1)):
        for x in range(max(0, x0), min(img.width, x1 + 1)):
            p[x, y] = color


def guardar(img, nombre):
    ruta = "%s/%s.png" % (DESTINO, nombre)
    img.save(ruta)
    colores = len({c for c in img.getdata() if c[3] > 0})
    print("  %-18s %2dx%-3d  %d colores" % (nombre, img.width, img.height, colores))


# --- Tubería (T-051) -----------------------------------------------------
# Cuerpo repetible verticalmente y cabeza aparte, para que la tubería se
# estire a cualquier altura sin deformar la cabeza (criterio del ticket).
ANCHO_TUBO = 26


def tuberia_cuerpo():
    """Franja de 26x16 que se repite en vertical."""
    img = lienzo(ANCHO_TUBO, 16)
    rect(img, 0, 0, ANCHO_TUBO - 1, 15, EDIFICIO)
    # Brillo a la izquierda y sombra a la derecha: da volumen cilíndrico con
    # dos columnas, que es todo lo que cabe en 26 px.
    rect(img, 2, 0, 4, 15, EDIFICIO_LEJOS)
    rect(img, ANCHO_TUBO - 6, 0, ANCHO_TUBO - 3, 15, CUERPO_S)
    rect(img, 0, 0, 0, 15, OUTLINE)
    rect(img, ANCHO_TUBO - 1, 0, ANCHO_TUBO - 1, 15, OUTLINE)
    return img


def tuberia_cabeza():
    """Boca de la tubería: 2 px más ancha por cada lado."""
    ancho = ANCHO_TUBO + 4
    img = lienzo(ancho, 14)
    rect(img, 0, 0, ancho - 1, 13, EDIFICIO)
    rect(img, 2, 1, 5, 12, EDIFICIO_LEJOS)
    rect(img, ancho - 7, 1, ancho - 3, 12, CUERPO_S)
    rect(img, 0, 0, ancho - 1, 0, OUTLINE)
    rect(img, 0, 13, ancho - 1, 13, OUTLINE)
    rect(img, 0, 0, 0, 13, OUTLINE)
    rect(img, ancho - 1, 0, ancho - 1, 13, OUTLINE)
    return img


# --- Suelo (T-052) -------------------------------------------------------
def suelo():
    """Tile de 32 px de ancho por el alto del suelo, repetible en horizontal.

    Los bordes izquierdo y derecho son idénticos a propósito: si el dibujo no
    encaja consigo mismo, se ve una costura cada 32 px (criterio de T-052).
    """
    alto = 64
    img = lienzo(32, alto)
    rect(img, 0, 0, 31, alto - 1, SUELO)
    rect(img, 0, 0, 31, 1, OUTLINE)
    rect(img, 0, 2, 31, 4, TRIPA)
    # Guijarros, colocados para que ninguno toque los bordes laterales.
    for gx, gy in [(6, 12), (20, 18), (12, 30), (25, 38), (4, 46), (17, 52)]:
        rect(img, gx, gy, gx + 2, gy + 1, SUELO_S)
    return img


# --- Fondo (T-052) -------------------------------------------------------
def nube(ancho, alto):
    img = lienzo(ancho, alto)
    rect(img, 2, alto // 2, ancho - 3, alto - 2, NUBE)
    rect(img, ancho // 4, 2, 3 * ancho // 4, alto - 2, NUBE)
    rect(img, 1, alto - 2, ancho - 2, alto - 1, NUBE)
    return img


def ciudad():
    """Silueta repetible de 96 px. Alturas variadas, bordes que encajan."""
    ancho, alto = 96, 120
    img = lienzo(ancho, alto)
    edificios = [(0, 34, 52), (14, 18, 78), (34, 26, 40), (52, 30, 96),
                 (74, 22, 60), (88, 8, 44)]
    for x, w, h in edificios:
        rect(img, x, alto - h, x + w - 1, alto - 1, EDIFICIO_LEJOS)
        # Ventanas: dos columnas, suficiente para que se lea como ciudad.
        for vy in range(alto - h + 6, alto - 6, 10):
            rect(img, x + 3, vy, x + 4, vy + 2, NUBE)
            if w > 16:
                rect(img, x + w - 6, vy, x + w - 5, vy + 2, NUBE)
    return img


# --- Medallas (T-053) ----------------------------------------------------
# Croqueta, tortilla y jamón. Nombres de comida, como pide el GDD.
def medalla(relleno, sombra, forma):
    img = lienzo(24, 24)
    # Cinta
    rect(img, 6, 0, 8, 7, CORAL)
    rect(img, 15, 0, 17, 7, CORAL)
    # Disco
    for y in range(24):
        for x in range(24):
            dx, dy = x - 11.5, y - 14.5
            d = (dx * dx + dy * dy) ** 0.5
            if d <= 8.5:
                img.putpixel((x, y), relleno if d <= 7.0 else OUTLINE)
    if forma == "croqueta":
        rect(img, 8, 12, 15, 17, sombra)
    elif forma == "tortilla":
        for y in range(10, 20):
            for x in range(6, 18):
                if ((x - 11.5) ** 2 + (y - 14.5) ** 2) ** 0.5 <= 5.0:
                    img.putpixel((x, y), sombra)
    else:  # jamón
        rect(img, 9, 10, 14, 18, sombra)
        rect(img, 11, 8, 12, 10, OUTLINE)
    return img


# --- Logo (T-053) --------------------------------------------------------
def logo():
    """FLAPO con la O gorda: la tripa como letra, según el GDD."""
    img = lienzo(120, 32)
    letras = {
        "F": ["11111", "10000", "11110", "10000", "10000"],
        "L": ["10000", "10000", "10000", "10000", "11111"],
        "A": ["01110", "10001", "11111", "10001", "10001"],
        "P": ["11110", "10001", "11110", "10000", "10000"],
    }
    x = 6
    for letra in "FLAP":
        for fy, fila in enumerate(letras[letra]):
            for fx, c in enumerate(fila):
                if c == "1":
                    rect(img, x + fx * 4, 6 + fy * 4, x + fx * 4 + 3, 6 + fy * 4 + 3, CUERPO)
        x += 24
    # La O es Flapo: círculo con tripa y pico.
    cx, cy, r = 100, 16, 13
    for y in range(32):
        for x2 in range(120):
            d = ((x2 - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                img.putpixel((x2, y), CUERPO if d <= r - 2 else OUTLINE)
    for y in range(cy, cy + 10):
        for x2 in range(cx - 6, cx + 10):
            if ((x2 - cx) ** 2 + (y - cy - 2) ** 2) ** 0.5 <= 8:
                img.putpixel((x2, y), TRIPA)
    rect(img, cx + 10, cy - 2, cx + 14, cy + 1, PICO)
    rect(img, cx + 3, cy - 6, cx + 5, cy - 4, OJO)
    return img


# --- Icono y splash (T-054) ---------------------------------------------
def icono(lado=512):
    """Icono de la app: Flapo grande sobre el cielo, escalado sin filtro."""
    base = lienzo(64, 64, CIELO)
    cx, cy, r = 32, 34, 22
    for y in range(64):
        for x in range(64):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                base.putpixel((x, y), CUERPO if d <= r - 3 else OUTLINE)
    for y in range(cy - 2, cy + 20):
        for x in range(cx - 12, cx + 18):
            if ((x - cx) ** 2 + (y - cy - 6) ** 2) ** 0.5 <= 14:
                base.putpixel((x, y), TRIPA)
    rect(base, cx + 18, cy - 4, cx + 26, cy + 2, PICO)
    rect(base, cx + 20, cy + 3, cx + 24, cy + 4, PICO_S)
    rect(base, cx + 6, cy - 12, cx + 10, cy - 8, OJO)
    rect(base, cx + 7, cy - 11, cx + 8, cy - 10, BRILLO)
    rect(base, cx - 4, cy - 12, cx + 1, cy - 9, CORAL)
    return base.resize((lado, lado), Image.NEAREST)


def splash():
    img = lienzo(288, 512, CIELO)
    img.alpha_composite(logo(), (84, 200))
    rect(img, 0, 448, 287, 511, SUELO)
    rect(img, 0, 448, 287, 449, OUTLINE)
    return img


# --- Dígitos del marcador (T-053) ---------------------------------------
DIGITOS = {
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"],
    "7": ["111", "001", "001", "001", "001"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
}
CELDA = 3  # px por celda del dígito: cada cifra sale de 9x15 más contorno


def digitos():
    """Atlas de cifras 0-9, con contorno oscuro para leerse sobre cualquier
    fondo. Cada glifo ocupa 12x18 en el atlas."""
    gw, gh = 12, 18
    img = lienzo(gw * 10, gh)
    for i, d in enumerate("0123456789"):
        ox = i * gw
        patron = DIGITOS[d]
        # Contorno: se pinta el dígito desplazado en las ocho direcciones.
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]:
            for fy, fila in enumerate(patron):
                for fx, c in enumerate(fila):
                    if c == "1":
                        x0 = ox + 1 + fx * CELDA + dx
                        y0 = 1 + fy * CELDA + dy
                        rect(img, x0, y0, x0 + CELDA - 1, y0 + CELDA - 1, OUTLINE)
        for fy, fila in enumerate(patron):
            for fx, c in enumerate(fila):
                if c == "1":
                    x0 = ox + 1 + fx * CELDA
                    y0 = 1 + fy * CELDA
                    rect(img, x0, y0, x0 + CELDA - 1, y0 + CELDA - 1, TRIPA)
    return img, gw, gh


def fuente_fnt(gw, gh):
    """Descriptor BMFont del atlas de cifras. Godot importa .fnt directamente,
    así que no hace falta ninguna herramienta externa."""
    lineas = [
        'info face="FlapoDigits" size=%d bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0" % gh,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (gh, gh - 2, gw * 10, gh),
        'page id=0 file="score_digits.png"',
        "chars count=10",
    ]
    for i, d in enumerate("0123456789"):
        lineas.append(
            "char id=%d x=%d y=0 width=%d height=%d xoffset=0 yoffset=0 "
            "xadvance=%d page=0 chnl=15" % (ord(d), i * gw, gw, gh, gw)
        )
    return "\n".join(lineas) + "\n"


def main():
    print("Generando arte en %s/" % DESTINO)
    guardar(tuberia_cuerpo(), "pipe_body")
    guardar(tuberia_cabeza(), "pipe_cap")
    guardar(suelo(), "ground_tile")
    guardar(nube(40, 16), "cloud_a")
    guardar(nube(52, 14), "cloud_b")
    guardar(ciudad(), "city")
    guardar(medalla(PICO_S, SUELO_S, "croqueta"), "medal_croqueta")
    guardar(medalla(NUBE, EDIFICIO_LEJOS, "tortilla"), "medal_tortilla")
    guardar(medalla(PICO, TRIPA, "jamon"), "medal_jamon")
    guardar(logo(), "logo")
    guardar(icono(), "icon_app")
    guardar(splash(), "splash")
    atlas, gw, gh = digitos()
    guardar(atlas, "score_digits")
    with open("%s/score_digits.fnt" % DESTINO, "w") as f:
        f.write(fuente_fnt(gw, gh))
    print("  score_digits.fnt   descriptor BMFont de 10 glifos")


if __name__ == "__main__":
    main()
