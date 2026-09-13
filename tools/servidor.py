#!/usr/bin/env python3
"""Servidor estático para el build web, sin caché.

`python3 -m http.server` manda `Last-Modified` y el navegador cachea el
`.pck` y el `.wasm` por su cuenta. El resultado es que exportas, recargas y
sigues jugando al build anterior sin ningún aviso: el juego carga, funciona y
le faltan las últimas features. Costó un buen rato de diagnóstico con las
frutas de T-047.

Aquí cada respuesta lleva `Cache-Control: no-store`, así que el navegador no
puede quedarse nada. Lo usa tools/servir_web.sh.
"""

import functools
import http.server
import os
import sys


class SinCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, formato, *args):
        # Una línea por petición, sin la marca de tiempo que no aporta nada.
        sys.stderr.write("  %s\n" % (formato % args))


def main():
    puerto = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    raiz = sys.argv[2] if len(sys.argv) > 2 else os.getcwd()
    handler = functools.partial(SinCache, directory=raiz)
    with http.server.ThreadingHTTPServer(("", puerto), handler) as httpd:
        print("Sirviendo %s en http://localhost:%d (sin caché)" % (raiz, puerto))
        httpd.serve_forever()


if __name__ == "__main__":
    main()
