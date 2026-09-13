# ADR-0001 — Motor y lenguaje: Godot 4 + GDScript

Fecha: 2026-09-07 · Estado: aceptada

## Contexto
Primer proyecto de videojuego. Objetivo: aprender el pipeline completo y publicar en Web y Android con herramientas gratuitas. El siguiente proyecto previsto es un metroidvania 2D.

## Opciones
- **Godot 4 + GDScript**: libre, sin royalties, 2D de primera, escenas en texto (`.tscn`) que van bien con Git y con asistentes de código. Comunidad creciente, menos ofertas de empleo.
- **Unity + C#**: el más demandado en empleo, gran asset store. Licencia gratuita con umbral de ingresos, cambios de licencia recientes, proyecto más pesado.
- **Unreal 5**: 3D AAA, C++/Blueprints. Sobredimensionado para 2D y para empezar.
- **Phaser + TypeScript**: reutiliza el stack web, pero limita a navegador y no enseña un motor de la industria.

## Decisión
Godot 4 con GDScript. C# queda como opción si algún proyecto lo necesita.

## Consecuencias
- Exportación nativa a Web, Android, escritorio sin coste.
- Aprender GDScript (curva baja).
- Menos transferible a empleo en estudios Unity/Unreal; asumido: el objetivo es producto propio.
