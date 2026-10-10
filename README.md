# AquíEstuve v0.11 — Probables, mapa y panel de bloqueo

Aplicación nativa SwiftUI + MapKit + Core Location. Código fuente abierto; **los datos de ubicación permanecen en el iPhone** y no se incluyen en el repositorio.

## Cambios incluidos

- **Probables / Todos:** los lugares privados, visitados y los negocios reconocibles tienen prioridad. El listado completo conserva oficinas y otras ubicaciones, sin eliminarlas de la búsqueda.
- **Tipos de lugares:** comercios y locales, espacios públicos, oficinas y otros, y lugares personales. La categoría sigue siendo editable y se guarda.
- **Mapa compacto o pantalla completa:** agrupación real de pines mediante `MKMapView`, controles `+`/`−`, botón de centrar y lista con todos los miembros de cada grupo. Cambiar la escala no hace nuevas consultas. «Buscar en esta zona» sí consulta bajo demanda.
- **Actividad en directo (experimental):** extensión WidgetKit/ActivityKit con hasta tres sitios que enlazan a la ficha de confirmación dentro de AquíEstuve. También puede aparecer en Dynamic Island. Se inicia y cierra desde Ajustes. Requiere que iOS la permita y que Sideloadly firme la extensión. **Tocar la actividad no registra una visita directamente**: abre la ficha para confirmar y evitar errores.
- **Consumo:** no hay polling de mapas en segundo plano. Se reutiliza una caché local y se limitan las actualizaciones de la Actividad en directo. El modo Paseo v0.10 sigue siendo optativo.
- Se conservan la estructura local de historial, las categorías corregidas, los lugares privados y las funciones de v0.10.

## Límites reales de iOS

Las Actividades en directo **no pueden hacer búsquedas GPS ni consultar mapas directamente**. Su contenido se actualiza cuando la app ejecuta código (por ejemplo, al abrirla, buscar lugares o al recibir ciertos eventos de ubicación). Puede mostrar lugares desactualizados mientras iOS no despierta la app. Una Actividad en directo estándar puede terminar después de unas horas; no es un banner permanente sin restricciones. El widget real independiente de bloqueo **no se ha añadido**: esta entrega contiene una Actividad en directo en el bloqueo y Dynamic Island.

## Instalación desde Windows

1. **Copia de seguridad antes de actualizar:** AquíEstuve → Ajustes → Copia completa JSON.
2. Descomprime `AquiEstuve-Windows-Actualizacion-v0.11.zip`.
3. Ejecuta `Actualizar-AquiEstuve.cmd` con Windows. Requiere Git, GitHub CLI y una sesión ya autorizada; NO los reinstala.
4. Si GitHub completa la única compilación, `Salida/AquiEstuve-unsigned.ipa` estará listo para Sideloadly.
5. Conecta tu iPhone, usa la **misma cuenta de Apple y el mismo bundle ID** que en la instalación previa y pulsa Start. No elimines la app anterior: así debería conservar sus datos.
6. Para probar la Actividad en directo: iOS → Ajustes → AquíEstuve → Actividades en directo (si aparece), activarlas; AquíEstuve → Ajustes → «Mostrar lugares en pantalla de bloqueo». Bloquea el iPhone. Si la extensión no aparece o Sideloadly la rechaza, conserva tu instalación anterior y reporta el error exacto.

## Para compilar sin widget (solo si la firma de la extensión falla)

El generador `python tools/generate_project.py --no-live` genera un proyecto **sin** el target de la extensión. No lo uses sobre el repositorio durante la prueba principal: requeriría otra compilación. La app principal mantiene las funciones de mapa, clasificación y recorrido; el botón de Actividad en directo informa si falta la extensión.

## Seguridad, costes y pruebas

- Sin Vercel, sin servidores propios y sin proveedores de pago.
- `python3 Tests/check_source.py` comprueba los 14 casos locales.
- `swiftc -frontend -parse Source/*.swift LiveWidget/*.swift` verifica la sintaxis (en un host con Swift).
- `plutil -lint AquiEstuve.xcodeproj/project.pbxproj` valida la estructura OpenStep.
- Estas comprobaciones **no sustituyen compilar con Xcode ni probar la extensión y su firma en el iPhone**.
- GitHub Actions solo se lanza manualmente y los artefactos se conservan un día.
