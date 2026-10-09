> **Recuperación v0.2 (10/10/2026):** si has descargado el paquete «Windows-Recuperacion-v0.2», usa `Instalar-AquiEstuve.cmd` desde la raíz del ZIP extraído. No crees manualmente otro repositorio: el instalador recupera `fabricelop/aquiestuve-ios` aunque haya quedado vacío. Las instrucciones de creación manual indicadas más abajo son solamente una alternativa.

## Instalación automatizada en Windows

En el ZIP de autoinstalación, extrae todo y ejecuta `Instalar-AquiEstuve.cmd`.
Automatiza la instalación de dependencias con WinGet, la creación del repositorio independiente (solo si GH CLI está autorizado), una compilación manual y la descarga de la IPA. No puede acceder remotamente a tu ordenador ni saltar la firma del iPhone. Ver `LEEME-ANTES-DE-EJECUTAR.txt` en la raíz del ZIP.

---

# AquíEstuve — MVP nativo iPhone, sin cuotas de pago

Aplicación personal SwiftUI para **detectar visitas** usando `CLVisit`, elegir lugares cercanos de Apple Maps y opcionalmente OpenStreetMap, crear lugares privados, corregir horarios, exportar los datos y conocer estadísticas.

**Estado: código fuente preparado y sintaxis comprobada; NO compilado todavía con Xcode ni probado en un iPhone real.** La automatización solo se ejecuta manualmente para no consumir recursos inesperadamente.

## Contenido v0.1

- **Ahora:** mapa con posición, hora estimada de llegada, contador de permanencia; sugeridos / todos los resultados obtenidos; radio 100, 250, 500 o 1.000 metros; confirmar o cambiar de sitio con un toque.
- **En segundo plano:** `CLVisit` y eventos de cambio significativo de posición cuando iOS concede permiso **Siempre**; no GPS constante ni temporizador de red. Las detecciones dependen de iOS y pueden tardar. Forzar el cierre desde el selector de aplicaciones puede impedir nuevos eventos hasta abrirla de nuevo. Las visitas inciertas quedan sin clasificar.
- **Fuentes:** MapKit del iPhone, lugares personales y complemento OSM bajo demanda (`Overpass`; hasta 700 m, máximo una consulta nueva cada 10 minutos, caché en memoria 24 horas). Dedupe aproximado por nombre y distancia. **Ningún catálogo garantiza recoger todos los sitios reales.**
- **Lugares:** alta privada, ajuste del pin mediante pulsación prolongada, nombre y categoría, edición, ficha y acceso a visitas manuales.
- **Historial:** visita activa/finalizada, lugares pendientes, edición de fechas, asignación retroactiva de lugar y eliminación.
- **Estadísticas:** visitas, tiempo, lugares únicos, media y sitios con más permanencia en 7, 30 y 365 días. Se omite el tiempo sin identificar. Todos los tiempos son estimaciones.
- **Privacidad:** JSON local con protección tras primer desbloqueo, exportación CSV/JSON, sin cuenta, sin backend, sin analítica. Consultas a Apple Maps y OSM sí requieren red y comunican las coordenadas del área consultada a estos proveedores.

## Costes y límites

- **App, backend y servicios propios: 0 €**. No se usan Vercel, Foursquare de pago, servicios de geocodificación comerciales ni API keys.
- GitHub Actions usa `macos-15` estándar en un **repositorio público** y compila **solo** al pulsar `Run workflow`. No hay triggers `push`, `pull_request` o cron ni despliegue. El artefacto caduca al día siguiente para ahorrar almacenamiento.
- Las consultas Apple Maps se hacen al abrir la sección, mover significativamente la posición, cambiar radio o pulsar actualizar (caché de 3 minutos y mínimo de 15 segundos incluso al forzar). Las peticiones a Overpass solo al pulsar y respetan su infraestructura comunitaria. No es una API con disponibilidad garantizada.
- El repo público contiene **solo código**. **No** subas exportaciones, datos personales, localizaciones o credenciales al repositorio.
- Las apps instaladas con un Apple ID gratuito suelen tener perfil de **7 días**; requiere renovación. Si la firma caduca, la app deja de funcionar y no se registran nuevas estancias mientras esté inactiva.

## Compilar en GitHub desde Windows, una única vez

1. Crea desde la web de GitHub un **repositorio nuevo y público** llamado, por ejemplo, `aquiestuve-ios`. **No uses `europapress-rss`**, cuyo `main` pertenece a otros proyectos.
2. Descarga y extrae este ZIP en Windows, p. ej. `C:\\Users\\TU_USUARIO\\Downloads\\AquiEstuve`.
3. Desde PowerShell, situándote en el directorio que contiene `AquiEstuve.xcodeproj`, ejecuta (sustituye `TU_USUARIO_GITHUB`):

   ```powershell
   git init -b main
   git add .
   git commit -m "AquiEstuve iOS MVP 0.1"
   git remote add origin https://github.com/TU_USUARIO_GITHUB/aquiestuve-ios.git
   git push -u origin main
   ```

4. Abre la pestaña **Actions** → **Construir AquíEstuve iPhone (manual)** → **Run workflow**. No hay compilación al subir el código: es manual para proteger cupos.
5. Si la compilación termina en verde, descarga el artefacto `AquiEstuve-unsigned-IPA`, descomprímelo y extrae `AquiEstuve-unsigned.ipa`.
6. En Windows instala [Sideloadly](https://sideloadly.io/). Conecta el iPhone y, dentro de Sideloadly, selecciona el archivo IPA y firma/instala usando **tu propia Apple Account gratuita**. No pegues contraseñas aquí. Sigue las indicaciones de confianza y modo desarrollador del iPhone si aparecen.
7. En la app, permite ubicación **Mientras se usa** y después solicita **Siempre** en Ajustes. Para mejores resultados habilita ubicación precisa. Las notificaciones son opcionales.
8. Crea un lugar privado, confirma una estancia y comprueba Historial. Luego realiza pruebas de campo para verificar la latencia real de `CLVisit`, precisión y batería. **No supongas fiabilidad del segundo plano sin estas pruebas**.

### Instalación y conservación de datos

- Se distribuye una **IPA sin firmar** porque el servidor GitHub no dispone de tu certificado. Sideloadly realiza la firma local; la instalación no está garantizada para todas las versiones de iOS/Apple ID.
- Para renovar la firma, usa el mismo identificador de app y Apple ID. Normalmente se puede instalar **encima** sin borrar datos; **exporta JSON/CSV antes de cualquier reinstalación**. Si borras la app, iOS puede borrar todo el historial.
- Cuenta gratuita: Apple limita los perfiles a 7 días y el número de apps/dispositivos. Consultar [Apple Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account) y [Sideloadly FAQ](https://sideloadly.io/faq.html).

## Desarrollo

- iOS mínimo **17.0**; Swift 5 y SwiftUI; sin paquetes externos.
- `AquiEstuve.xcodeproj` y esquema compartido incluidos. El proyecto se puede regenerar sin red: `python tools/generate_project.py`.
- Fuentes en `Source/`; flujo de compilación `.github/workflows/build-iphone.yml`.
- Validación local posible en Windows/Linux: `python Tests/check_source.py`. En este entorno se ha ejecutado además `swiftc -frontend -parse Source/*.swift` (no equivale a compilar para iOS).
- Evitar ediciones simultáneas del JSON desde múltiples procesos: el MVP serializa los cambios en el hilo principal. Más adelante podría migrarse a SQLite para muchos años de datos.

## Limitaciones conocidas de la primera entrega

- Aún no incluye sincronización entre dispositivos, restauración JSON, división de estancias, calendario, mapa de calor, búsqueda por nombre remota ni fotografías. Tampoco ofrece seguimiento GPS de alta frecuencia, deliberadamente por batería y privacidad.
- Las visitas de iOS indican periodos **aproximados** y pueden llegar tarde o faltar; sitios contiguos necesitan confirmación. El recuento puede depender de correcciones manuales.
- Una IPA sin firma generada por CI **no es una app instalada**: hace falta completar la firma en Windows y verificar funcionamiento real.
- No se ha consumido ningún minuto de GitHub Actions, desplegado nada ni modificado otro repositorio para crear esta entrega.
