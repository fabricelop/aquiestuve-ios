# AquíEstuve v0.13 · Pulse

Versión experimental para iPhone. App sin backend personal, sin Vercel y sin consultas periódicas de lugares. Conserva el `CFBundleIdentifier` original para actualización sobre la instalación actual.

## Novedades

- Pantalla principal **Pulse**: tarjeta contextual de estancia, tiempo actual, acceso a selección probable, dos tarjetas estadísticas y cronología de hoy. Reutiliza la caché local de Apple Maps/OSM, sin búsquedas en segundo plano.
- Modo normal (predeterminado): CoreLocation Visits + significant changes. Modo Paseo: opcional, tres horas como máximo, GPS más preciso. Ahora exige desplazamiento sostenido antes de cerrar una parada; el GPS que oscila no crea estancias periódicas.
- Reconciliación de registros físicamente solapados: combina duplicados no identificados y visitas a un mismo establecimiento. Nunca fusiona automáticamente dos establecimientos distintos o visitas consecutivas sin solapamiento. Conserva el estado confirmado y el intervalo completo. Copia local automática `visits-pre-pulse-013.json` antes de la primera migración.
- Catálogo sin conexión con **323 categorías** buscables en 14 familias. Categorías editables también manualmente. Ejemplos: Escuela de Arquitectura, Colegio de Arquitectos, Sede de telecomunicaciones y oficinas.
- El historial ya no muestra «Posible parada de paseo» después de que la estancia esté confirmada.
- Se mantiene la prueba visual y diagnóstico de la Actividad en directo v0.12. El nuevo Pulse es la alternativa accesible dentro de la app mientras no se confirme que iOS representa esa extensión con firma Sideloadly.

## Pruebas

`python -X utf8 Tests/check_source.py`; `swiftc -frontend -parse Source/*.swift LiveWidget/LivePlacesWidget.swift`; `swiftc Source/StayReconciliation.swift Tests/check_episodes.swift -o episodes && ./episodes` (macOS/Linux). Este código **no se ha compilado con el SDK de iOS**, pendiente de Xcode en GitHub Actions, bajo una sola ejecución manual.

Antes de instalar, exporta `Copia completa JSON`, guarda el archivo fuera del móvil y conserva v0.12 hasta comprobar que la instalación de v0.13 funciona. La presencia de la extensión de ActivityKit en la IPA no demuestra que Sideloadly/iOS pueda mostrar su vista ampliada.
