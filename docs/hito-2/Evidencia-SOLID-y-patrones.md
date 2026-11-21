# Evidencia de diseño limpio, SOLID y patrones

| Principio/patrón | Evidencia en código | Explicación | Estado |
|---|---|---|---|
| Single Responsibility | `PedidoController`, `PedidoServiceImpl`, repositorios, `GlobalExceptionHandler` | HTTP, reglas, persistencia y traducción de errores están en responsabilidades diferentes | Aplicado en pedido |
| Dependency Inversion | `PedidoService` y repositorios inyectados por constructor (`@RequiredArgsConstructor`) | Servicio depende de contratos Spring Data/interfaces, no crea dependencias concretas manualmente | Aplicado |
| DTO | `CrearPedidoRequest` como record con validaciones anidadas | Contrato de entrada desacoplado de validación de dominio | Aplicado en entrada; respuesta sigue exponiendo entidad |
| Repository | `PedidoRepository`, `ProductoRepository`, `ReservaRepository` | Abstracción de persistencia y consultas derivadas/JPQL | Aplicado |
| Observer / Event | `ApplicationEventPublisher` + `PedidoCreadoEvent`; `ReservaCreadaEvent` + `NotificacionListener` | Notifica publicación sin que el service invoque directamente un transporte externo | Parcial: no hay listener para eventos PedidoCreadoEvent; listener de reserva solo escribe log |
| Strategy | No se encontró una implementación Strategy en el estado actual | No afirmar que está aplicada; sería útil si aparecen políticas variables de precio/stock | No aplicado |
| Factory | No hay factory de dominio explícita | La creación se realiza con Lombok Builder en service | No aplicado como patrón Factory |

## Mejora concreta priorizada

Crear `ProductoService` para mover la consulta `findAll()` fuera de `ProductoController`, y crear `PedidoResponse`/`DetallePedidoResponse` para que la API no serialice entidades JPA directamente. Esta evolución mejora SRP, límites de contrato y control de carga lazy sin cambiar las reglas de negocio.
