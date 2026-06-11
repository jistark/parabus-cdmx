# Parabús

App iOS no oficial para saber cómo va el Metrobús de la CDMX — antes de salir, en la estación, y durante el viaje.

La información existe: el operador publica el estado del servicio, hay GTFS, hay posiciones de vehículos en tiempo real. El problema es que vive dispersa y nadie te la entrega cuando la necesitas. Parabús parte de una idea simple: **la app te dice lo que está pasando en *tu* trayecto en el momento en que te sirve saberlo** — tus líneas, tu estación más cercana, tu ruta de todos los días.

## Qué hace

- **Estado de las líneas en vivo**, con el vocabulario real del operador (carril obstruido, servicio limitado, manifestaciones…), no un semáforo genérico.
- **Llegadas en tu estación**: la más cercana a ti o la de tu ruta programada, con countdown por dirección.
- **Mapa en tiempo real** con los buses moviéndose, por línea.
- **Rutas programadas (ida/regreso)** con alertas antes de tu hora de salida si algo afecta tu trayecto.
- **Widgets y Live Activities** para no tener que abrir la app.

## Cómo está hecho

Dos piezas:

- **App iOS** (SwiftUI, iOS 26): la interfaz, los widgets, las Live Activities. Swift Package + proyecto Xcode en la raíz.
- **Worker de Cloudflare** ([`workers/`](workers/)): el backend. Normaliza el estado que publica el operador, sirve el GTFS estático (horarios, rutas, paradas) y decodifica el feed GTFS-Realtime de posiciones de vehículos. Todo con caching agresivo — la meta es ser un buen ciudadano con las fuentes y con el free tier.

## Datos

Los datos vienen de fuentes oficiales del [Metrobús CDMX](https://www.metrobus.cdmx.gob.mx) (estado del servicio, GTFS estático y GTFS-RT). Parabús no inventa información: la normaliza, la clasifica y la entrega a tiempo.

## Licencias

- **El código** de este repositorio está bajo licencia [MIT](LICENSE).
- **La identidad del Metrobús y de la CDMX no es mía ni está cubierta por esa licencia**: las marcas, los colores de línea, los pictogramas de estación y la tipografía Tipo Movin CDMX pertenecen al Metrobús / Gobierno de la Ciudad de México. Están aquí para que la app se sienta parte del sistema que describe; si reutilizas este código para otra cosa, esos assets no van incluidos en el trato.

## Aviso

Parabús es un proyecto independiente. No está afiliado a, ni respaldado por, el Metrobús ni el Gobierno de la Ciudad de México. La información de servicio puede tener retraso o errores; ante cualquier duda, la fuente oficial manda.
