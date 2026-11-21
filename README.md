# MediGest (versión web)

Sistema de Gestión Clínica (módulos **Inventario** y **Farmacia**) que al ejecutarse **enciende su propio servidor web**:
tú eres el host y abres la página en el navegador. Sin Tomcat ni Spring: usa el servidor HTTP incluido en el JDK.

## Cómo ejecutarlo
Requisitos: JDK 17 o superior y Maven.

    mvn compile exec:java        (o doble clic en iniciar.bat / ./iniciar.sh)

Se abre solo `http://localhost:8080`. Si no se abre, escríbela en el navegador.
- Otro puerto: `mvn compile exec:java -Dexec.args="9090"`
- Que otros equipos de tu red entren: `-Dexec.args="8080 --red"` (por defecto solo entra tu computador)
- Apagar: Ctrl+C. Reiniciar los datos de prueba: apaga y borra el archivo `medigest.db`.

Usuarios de prueba (clave = usuario): `admin` (todo + bitácora), `farmacia` (dispensa y anula), `inventario` (gestiona inventario).

## Cómo está armado
    navegador (HTML/CSS/JS en src/main/resources/web)
        |  fetch  /api/*   (JSON, cookie de sesión HttpOnly)
    pe.medigest.web      -> ServidorWeb, RutasApi, Sesiones, Json   (solo traduce HTTP <-> controladores)
        |
    InventarioController / DispensacionController   (permisos, bitácora, reglas)  <- los mismos de antes
        |
    ServicioInventario + DAO JDBC -> SQLite (medigest.db)

La página solo muestra datos y manda acciones; **todas las reglas siguen en Java** (FEFO, rollback, vigencia de receta, permisos por rol).

| Ruta | Qué hace |
|------|----------|
| POST /api/login, /api/logout, GET /api/sesion | Sesión |
| GET /api/productos, /api/lotes, /api/movimientos, /api/alertas | Consultas de inventario |
| POST /api/productos, /api/productos/eliminar, /api/entradas, /api/ajustes | Operaciones de inventario |
| GET /api/receta?codigo=, POST /api/dispensar, GET /api/tickets, POST /api/tickets/anular | Farmacia |
| GET /api/bitacora | Solo administrador |

Las acciones (POST) exigen la cabecera `X-MediGest` (solo la manda nuestra página) como protección básica contra peticiones de otros sitios.
Prototipo académico: sin HTTPS; no exponerlo a internet.

## Clases por módulo (Inventario y Farmacia)
Total: **148 clases, interfaces y enums** (Inventario 87 + Farmacia 61), sin contar vistas, `comun` ni pruebas.

| Paquete                     | Qué tiene                                                                                           |
|-----------------------------|-----------------------------------------------------------------------------------------------------|
| `inventario`                | Núcleo (Producto, LoteAlmacen, ServicioInventario, DAO, movimientos) + `GeneradorAlertas`, `AlertaFactory`, `PlanDescuento`, `ProductoBuilder`, `BuscadorProductos` |
| `inventario.modelo`         | Enums y objetos de valor: `CodigoProducto`, `NumeroLote`, `Cantidad`, `RangoFechas`, `EstadoLote`, `NivelStock`... |
| `inventario.excepcion`      | Excepciones propias (`ProductoNoEncontrado`, `LoteDuplicado`, `AjusteInvalido`...)                  |
| `inventario.regla`          | Specification (`LoteVigente`, `LotePorVencer`... combinables con y/o/no), clasificadores, validadores, políticas de reposición, estrategia `SeleccionMenorCantidad`, `FabricaEstrategias` |
| `inventario.evento`         | Bus de eventos (Observer): `BusEventosInventario`, `EventoLoteIngresado`, `EventoStockAjustado`     |
| `inventario.reporte`        | `ReporteStock`, `ReporteVencimientos`, `ReporteMovimientos` + formateadores texto y CSV             |
| `inventario.memoria`        | DAO en memoria (para pruebas sin base de datos)                                                     |
| `farmacia`                  | Núcleo (Receta, TicketFarmacia, DispensacionController, DAO) + `RecetaBuilder`                      |
| `farmacia.modelo`           | `CodigoReceta`, `DocumentoPaciente`, `DatosPaciente`, `EstadoReceta`, `EstadoTicket`, `MotivoRechazo` |
| `farmacia.excepcion`        | `RecetaNoEncontrada`, `RecetaYaDispensada`, `RecetaVencida`, `TicketYaAnulado`...                   |
| `farmacia.regla`            | Cadena de validación de recetas (`CadenaValidacionReceta` + 6 reglas) y políticas de vigencia       |
| `farmacia.tiempo`           | `Reloj`, `RelojSistema`, `RelojFijo` (para probar vigencias)                                        |
| `farmacia.servicio`         | Constancias (texto/CSV), `ConsultaMedicamentos`, `ResultadoDispensacion`, observadores de dispensación |
| `farmacia.reporte`          | Filtros, estadísticas, historial, exportación CSV                                                   |
| `farmacia.memoria`          | DAO en memoria                                                                                      |

### Patrones nuevos (además de los 5 del documento)
Specification (`EspecificacionLote`), Chain of Responsibility (`CadenaValidacionReceta`), Builder (`ProductoBuilder`, `RecetaBuilder`), Strategy extra (`PoliticaReposicion`, `PoliticaVigencia`, `FormateadorReporte`, `ConstanciaFormateador`), Observer extra (`BusEventosInventario`, `NotificadorDispensacion`).

### Qué cambió en el código que ya existía
- `ValidadorReceta` ahora aplica la cadena de reglas (mismos mensajes y mismo tipo de excepción).
- `TicketFarmacia.generarConstancia()` delega en `ConstanciaTexto` (mismo texto).
- `ServicioInventario.calcularAlertas()` delega en `GeneradorAlertas` (mismas alertas) y publica eventos de ingreso/ajuste.
- `DispensacionController` acepta observadores (`registrarObservador`) y les avisa después del commit.

Pruebas nuevas: `InventarioNuevasClasesTest` y `FarmaciaNuevasClasesTest`.


### Capa web (paquete `pe.medigest.web`)
`ServidorWeb`, `RutasApi`, `Sesiones`, `Sesion`, `Parametros`, `Json`, `ErrorApi`. Las ventanas Swing se reemplazaron por la carpeta `resources/web`. Pruebas: `WebJsonTest`.
