# AquíEstuve v0.15 · Radar mejorado y Movimiento inteligente

App nativa y gratuita para iPhone (iOS 17+) que une dos experiencias sin mezclarlas: registrar las estancias reales y descubrir establecimientos cercanos o en otra ciudad. Se mantiene el mismo bundle identifier `com.aquiestuve.ios` para instalar encima de v0.14 sin desinstalar ni perder los datos locales.

## Radar inteligente

- Portada visual con indicadores circulares, pila animada de hasta tres tarjetas y candidatos ordenados según proximidad, visitas reales y preferencias. No se atribuyen probabilidades estadísticas inexistentes.
- **Deslizar derecha:** favorito, prioriza visitas futuras en la zona, pero NO registra presencia.
- **Deslizar izquierda:** «Ahora no», oculta durante 4 horas. Descartes anteriores reducen ligeramente la prioridad posterior cuando caducan.
- **Deslizar más a la izquierda:** oculta solo en un radio de 450 metros alrededor de la zona actual.
- **Deslizar arriba:** archivar globalmente de las sugerencias, con confirmación explícita.
- **Confirmar visita:** botón independiente en la tarjeta. Solo esta acción explícita modifica el historial.
- **Ver detalles y mapa:** abre la ficha sin confirmar presencia.
- **Deshacer y recuperar:** botón de deshacer y apartado «Descartados» con buscador. Ninguna ocultación elimina establecimientos del mapa ni borra visitas.
- Las preferencias persisten localmente en `Application Support/AquiEstuve/radar-preferences.json`, independientemente de `visits.json`.
- Si se abre la portada en una zona sin suficientes lugares conocidos, se permite una consulta inicial pequeña y limitada en tiempo y distancia. No hay rastreo continuo en modo normal ni consultas de mapas en segundo plano.

## Guía de lugares

- Pestaña «Guía» en la portada, con búsqueda de ciudad/barrio/destino mediante MapKit.
- Filtros rápidos de categorías, búsqueda de lugares por nombre y selector de **323 categorías detalladas**.
- Vista de lista predeterminada para cargar con fluidez; mapa solo al solicitarlo. Los lugares ocultos están excluidos por defecto y reaparecen mediante un check de la Guía para poder recuperarlos.
- Favoritos también editables desde la guía. Buscar o marcar favoritos **nunca crea una visita**.

## Visitas y autonomía

- El modo normal sigue usando visitas y cambios significativos de posición de iOS y puede recibir eventos sin que abras la app ese día, siempre que esté autorizada con ubicación «Siempre» y no la fuerces a cerrar.
- Modo Paseo opcional, hasta 3 horas, para intentar captar pausas cortas con mayor precisión y gasto de batería.
- Se mantienen reconciliación de intervalos, categorías, fusión manual de duplicados, historial, estadísticas y configuración anterior.
- Las Actividades en directo de la pantalla bloqueada permanecen experimentales: su visibilidad con Sideloadly **no está resuelta ni garantizada**.

## Validación

- `python -X utf8 Tests/check_source.py`
- `swiftc -frontend -parse Source/*.swift LiveWidget/*.swift` (solo sintaxis)
- `swiftc Source/RadarRules.swift Tests/check_radar.swift -o radar-tests && ./radar-tests`
- `swiftc Source/StayReconciliation.swift Tests/check_episodes.swift -o episode-tests && ./episode-tests`

La compilación completa con el SDK de iOS corresponde al workflow manual de GitHub Actions; **no puede validarse íntegramente en este entorno Linux**. Ejecutar una sola vez el actualizador Windows, revisar el estado de GitHub y no instalar una IPA si la compilación falla. Antes de actualizar, exportar «Copia completa JSON» y conservarla fuera del iPhone. No desinstalar la aplicación actual.


## 0.15 · Ajustes y movimiento inteligente

- La Guía excluye descartados por defecto; activa «Mostrar descartados del Radar» para encontrarlos y recuperarlos (lista y mapa).
- Tarjetas opacas; el gesto vertical se prioriza desde la tarjeta, con alternativa «Archivar» en el menú de tres puntos.
- Interruptor **Movimiento inteligente** (optativo). Usa Core Motion con permiso de actividad física y ráfagas limitadas de GPS cuando el proceso recibe indicios de movimiento o parada. No garantiza detectar paradas breves si iOS suspende la app. El modo pasivo sigue funcionando sin abrir la app cada día, con permiso «Siempre».
- El paseo manual sigue en Ajustes → Detección de estancias → Paseo detallado manual.
- La prueba de Actividad en directo queda aislada de las actualizaciones de ubicación; el diagnóstico permite comprobar el identificador y ejecutable de la extensión, **no** su firma efectiva o su representación en WidgetKit. Si sigue sin dibujarse, investigar Sideloadly/la firma de la extensión, no darla por corregida.
