#!/usr/bin/env python3
"""Genera los efectos de sonido placeholder de Flapo.

    ./.venv/bin/python tools/generar_audio.py

Mismo criterio que tools/generar_arte.py: sonidos sintetizados por código en
vez de ficheros opacos, para que ajustar uno sea cambiar un número y volver a
generar. Son ondas simples estilo jsfxr, adecuadas para un juego de píxeles.
Ver ADR-0017.
"""

import math
import random
import struct
import wave

TASA = 22050  # Hz. De sobra para efectos cortos y pesa la mitad que 44100.
DESTINO = "assets/audio"


def envolvente(n, ataque=0.01, caida=0.9):
    """Sube rápido y baja despacio. Sin esto, cada sonido empieza y acaba con
    un chasquido: el salto brusco de amplitud es audible como un 'click'."""
    a = max(1, int(n * ataque))
    d = max(1, int(n * caida))
    env = []
    for i in range(n):
        if i < a:
            env.append(i / a)
        elif i > n - d:
            env.append(max(0.0, (n - i) / d))
        else:
            env.append(1.0)
    return env


def tono(f0, f1, dur, forma="cuadrada", volumen=0.5, ruido=0.0):
    """Barrido de f0 a f1 en `dur` segundos."""
    n = int(TASA * dur)
    env = envolvente(n)
    fase = 0.0
    muestras = []
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        fase += 2.0 * math.pi * f / TASA
        if forma == "cuadrada":
            v = 1.0 if math.sin(fase) >= 0 else -1.0
        elif forma == "sierra":
            v = 2.0 * ((fase / (2 * math.pi)) % 1.0) - 1.0
        else:
            v = math.sin(fase)
        if ruido > 0.0:
            v = v * (1.0 - ruido) + random.uniform(-1.0, 1.0) * ruido
        muestras.append(v * env[i] * volumen)
    return muestras


def mezcla(*pistas):
    n = max(len(p) for p in pistas)
    out = [0.0] * n
    for p in pistas:
        for i, v in enumerate(p):
            out[i] += v
    pico = max(1.0, max(abs(v) for v in out))
    return [v / pico for v in out]


def guardar(muestras, nombre):
    ruta = "%s/%s.wav" % (DESTINO, nombre)
    with wave.open(ruta, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TASA)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in muestras))
    print("  %-10s %5.2f s  %d Hz" % (nombre, len(muestras) / TASA, TASA))


def main():
    random.seed(7)  # Reproducible: la misma ejecución da los mismos ficheros.
    print("Generando audio en %s/" % DESTINO)

    # Aleteo: golpe de aire corto y grave. Flapo pesa, así que no es un
    # 'pip' agudo sino algo con cuerpo.
    guardar(mezcla(tono(420, 180, 0.10, "sierra", 0.35),
                   tono(90, 60, 0.10, "seno", 0.25, ruido=0.5)), "flap")

    # Punto: dos notas ascendentes. Es el único sonido que premia, así que
    # sube en vez de bajar.
    guardar(mezcla(tono(660, 660, 0.06, "cuadrada", 0.4),
                   [0.0] * int(TASA * 0.05) + tono(990, 990, 0.09, "cuadrada", 0.4)), "point")

    # Golpe: ruido con caída de tono. El batacazo del GDD.
    guardar(mezcla(tono(300, 60, 0.18, "cuadrada", 0.45, ruido=0.7)), "hit")

    # Caída: barrido largo hacia abajo, para el rato entre el golpe y el suelo.
    guardar(mezcla(tono(500, 90, 0.45, "sierra", 0.3)), "fall")

    # Fruta buena: arpegio corto hacia arriba. Se distingue del punto por ser
    # tres notas en vez de dos y por acabar más agudo.
    guardar(mezcla(tono(520, 520, 0.05, "cuadrada", 0.35),
                   [0.0] * int(TASA * 0.04) + tono(780, 780, 0.05, "cuadrada", 0.35),
                   [0.0] * int(TASA * 0.08) + tono(1040, 1040, 0.08, "cuadrada", 0.35)),
            "fruit_good")

    # Fruta mala: la misma idea al revés y con la onda más sucia. Tiene que
    # reconocerse como "algo ha ido mal" sin sonar a muerte.
    guardar(mezcla(tono(560, 220, 0.22, "sierra", 0.35, ruido=0.25)), "fruit_bad")

    # Bocanada (T-202): inhalación. Barrido de ruido hacia ARRIBA, al revés
    # que la caída, y sin tono definido: tiene que sonar a aire entrando, no
    # a una nota. Se distingue del punto porque no es musical.
    guardar(mezcla(tono(180, 520, 0.28, "sierra", 0.16, ruido=0.85)), "breath")

    # Botón: click seco y neutro.
    guardar(mezcla(tono(880, 700, 0.05, "cuadrada", 0.3)), "button")


if __name__ == "__main__":
    main()
