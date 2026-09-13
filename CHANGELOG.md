# Changelog

## 0.2.0 — 2026-09-09

### Novedades

- Los efectos de fruta se acumulan, uno por eje

## 0.1.3 — 2026-09-09

### Arreglos

- Quita el brillo de la franja de aliento (T-202)

## 0.1.2 — 2026-09-09

### Arreglos

- El suelo llega al borde de la pantalla

## 0.1.1 — 2026-09-09

### Arreglos

- El changelog generado no pasaba los hooks del propio repo
- El juego llena la pantalla, sin barras
- El sobrante del letterbox lleva el cielo, no negro

## 0.1.0 — 2026-09-09

### Novedades

- El escudo se acumula
- Build jugable por PR y versionado automático (T-270, T-271)
- El bot dice también de qué muere (T-260)
- El paisaje cuenta hasta dónde has llegado (T-222)
- Fin del viaje, Flapo llega al nido (T-209)
- El hermano pasa y deja rebufo (T-204)
- Térmicas, columnas de aire que se suben planeando (T-203)
- Captura del mejor salto al batir el récord (T-077)
- Modo espejo desbloqueable con récord 25 (T-076)
- Un compañero que vuela contigo y no hace nada (T-058)
- Tramo especial al superar el récord (T-067)
- Cuatro cielos para el mismo sitio (T-057)
- Replay determinista para reproducir bugs (T-261)
- Bot que juega y mide si la curva es justa (T-260)
- Submenú de opciones y ocultar el fantasma (T-087)
- El fantasma del récord vuelve a volar (T-243)
- Código corto para compartir la partida (T-242)
- Reto del día con semilla por fecha (T-241)
- Un solo generador con semilla para toda la partida (T-240)
- Enseñar a planear en la primera partida (T-200)
- Bocanada visible y audible al coger aire (T-202)
- Jadeo visible en el cuerpo de Flapo (T-201)
- Tubería giratoria, solo visual (T-065)
- Ráfagas de viento anunciadas (T-064)
- Layout adaptativo por tamaño de ventana (T-085)
- Tubería blandita que no mata (T-066)
- Tuberías con movimiento vertical (T-063)
- Nombre de jugador opcional en el menú (T-079)
- Pantalla de estadísticas desde el menú (T-084)
- Pantalla de inicio con modos de dificultad (T-078)
- La frase del Game Over cuenta de qué murió Flapo (T-075)
- Progresión de confianza con la práctica (T-074)
- Frases variables al morir (T-056)
- Fatiga por aleteo sin pausa (T-049)
- Aliento como recurso de vuelo (T-048)
- Frutas con efectos temporales (T-047)
- Hueco de salida más ancho, 118 px (T-046)
- Curva de dificultad con la puntuación (T-045)
- Efectos de sonido, buses y silencio persistente (T-060, T-061)
- Márgenes seguros y letterbox con color de cielo (T-073)
- Pausa y pérdida de foco (T-072)
- Panel de Game Over con medalla y récord (T-071)
- Récord y partidas jugadas persistentes (T-070)
- Transiciones entre estados (T-044)
- Parallax de fondo en dos capas (T-043)
- Flash, sacudida, hit-stop y rebote al morir (T-042)
- Animación de aleteo con 3 frames placeholder (T-041)
- HUD de puntuación (T-029)
- Panel de Game Over y reinicio (T-028)
- Suelo con scroll infinito y colisión (T-027)
- Zona de puntuación entre tuberías (T-026)
- PipeSpawner y GameConfig sin autoload (T-025)
- Par de tuberías con hueco aleatorio (T-024)
- Arnés de verificación headless (T-006)
- Flapo con gravedad, aleteo y rotación (T-023)
- Escena Main y máquina de estados con señales (T-022)
- Acciones flap, restart y pause en el InputMap (T-021)
- Configuración del proyecto y autoload GameConfig (T-020)

### Arreglos

- La imagen de Godot no trae bash, así que nada de pipefail
- El job de release no podía crear releases (T-091)
- El fantasma se va cuando lo superas (T-243)
- Todas las frutas salían azules
- Las frutas no se veían en el navegador
- Las frutas nacían desfasadas de las tuberías (T-047)
- Colocar las export templates donde Godot las busca en CI (T-091)
- Restaurar Main como escena principal
- Resolver la referencia a Bird en Main.tscn (T-023)
