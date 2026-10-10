# AquíEstuve 0.10 — Versión de pruebas nativa para iPhone

App personal para reconocer y revisar estancias. **Sin pagos, cuentas, servidor propio, Vercel ni APIs de pago.** Historial privado en el teléfono; Apple Maps/OSM reciben búsquedas de zona solicitadas.

## Qué incorpora

- **Ahora:** mapa ocultable (recuerda la preferencia), vista a pantalla completa con zoom/arrastre, pines pulsables y botón explícito «Buscar en esta zona». Radio 100/250/500/1.000 m con zoom y contador. Tocar una fila o pin **no registra visita**: solo «Confirmar que estoy aquí» lo hace.
- **Búsqueda:** filtra inmediatamente sitios cargados, pero al pulsar «Buscar en zona» consulta Apple Maps por nombre a 1/3/5/10 km; búsqueda de categoría ampliada por petición; búsqueda por sectores (hasta cuatro) bajo demanda, para zonas densas. La disponibilidad y exhaustividad dependen de Apple Maps; no hay cobertura garantizada. Sin consultas al teclear, sin búsqueda repetitiva en segundo plano.
- **OpenStreetMap:** ampliación manual hasta 700 m; intervalo mínimo de 10 minutos entre peticiones nuevas, caché local en memoria. Se intenta evitar duplicados y aprovechar categorías más específicas, sin sobrescribir correcciones del usuario.
- **Categorías:** traducción de etiquetas conocidas, colores y filtros; edición persistente de la categoría incluso si nunca se visitó un lugar.
- **Lugares:** privados separados de sitios visitados; borrar cualquier lugar y conservar las visitas como pendientes o borrar también las visitas accidentales.
- **Historial:** vistas Todas/Pendientes/Identificadas, agrupación por día y corrección de llegada/salida; búsqueda de establecimientos en la **posición histórica** de una parada. Las pendientes no se contabilizan como visitas identificadas.
- **Modo Paseo (opcional):** GPS de mayor consumo temporalmente para intentar detectar paradas de ~80 segundos o más y registrarlas como pendientes. Termina manualmente o a las 3 horas como máximo; al no existir garantía de eventos y precisión de iOS, algunas paradas breves no se detectarán. El modo normal sigue utilizando CLVisit y cambios significativos de posición.
- **Estadísticas:** por 7/30/365 días, categorías, evolución de la última semana, comparativa temporal, sitios, media y pendientes por revisar.
- **Pantalla de bloqueo:** notificaciones de visitas detectadas con candidatos de datos recientes; en Ajustes, prueba de notificación a los 5 segundos **sin crear una visita**. Esto NO es un widget de pantalla de bloqueo, ni asegura que iOS detecte paradas de 1 minuto.

## Instalación desde Windows

La compilación iOS requiere un runner macOS. El ZIP `AquiEstuve-Windows-v0.10.zip` contiene `Actualizar-AquiEstuve.cmd` y el parche de código para el **único** repositorio `fabricelop/aquiestuve-ios`. Descomprime todo el ZIP en una carpeta nueva y ejecuta el CMD cuando quieras compilar. Necesita Git y GitHub CLI ya instalados y autenticados en el PC (como en v0.9); no reinstala nada.

El instalador valida la sintaxis de PowerShell ANTES de modificar GitHub, exige que el repositorio sea público y que siga en la versión v0.9 conocida, actualiza solamente AquíEstuve, lanza a lo sumo una compilación manual para el commit nuevo, y recupera `Salida/AquiEstuve-unsigned.ipa`. Si la compilación falla, se detiene y no la repite automáticamente.

**Antes de instalar con Sideloadly:** AquíEstuve → Ajustes → «Copia completa JSON», guárdala fuera del iPhone. Selecciona la IPA nueva, el **mismo Apple ID** y las mismas opciones de firma; instala encima de la versión existente **sin desinstalarla**. Así deberían conservarse los datos; nunca prometemos conservación sin respaldo. No subas historial ni credenciales a GitHub.

## Comprobaciones y límites

Las fuentes Swift pasan el parser local (`swiftc -frontend -parse`) y `python Tests/check_source.py`. **Estos controles no sustituyen una compilación Xcode ni una prueba real en iPhone.** El artefacto unsigned IPA solo existirá cuando la compilación manual termine correctamente. El script de Windows incluye una verificación de sintaxis real con el PowerShell de tu ordenador.

Sin cron, sin despliegues, sin ejecución por `push`, sin repetición automática de builds. Repo público = sin minutos facturables en el entorno público estándar de GitHub Actions, sujeto a las condiciones vigentes de GitHub. Las búsquedas Apple/OSM pueden tener límites y la precisión GPS depende de iOS.

El widget real/Live Activity queda **pendiente de validar su instalación y firma gratuitas**. Esta versión aporta notificación interactiva y prueba de notificaciones como primera fase de la experiencia de pantalla bloqueada.
