# Trazabilidad de requisitos no funcionales

| RNF / requisito | Diseño actual | Evidencia verificable | Brecha / seguimiento |
|---|---|---|---|
| Concurrencia de inventario RNF-02 | `@Transactional` + `@Lock(PESSIMISTIC_WRITE)` en ProductoRepository | `PedidoServiceImpl`, tests de stock en `PedidoServiceTest` | Agregar prueba concurrente con PostgreSQL, bloqueo ordenado por ID, timeout y métrica |
| Rendimiento | Índices compuestos `reservas` y consulta agregada de disponibilidad | `ReservaRepository`, `ReservaRepositoryDataJpaTest` | `GET /productos` sin paginación; P95 no medido; planificar carga/EXPLAIN |
| Seguridad | Validación de request y `GlobalExceptionHandler` | `PedidoControllerTest` | No hay autenticación/autorización; CORS `*`; no publicar expuesto |
| Mantenibilidad | Paquetes controller/service/repository/domain/dto/exception | Interfaces `PedidoService`, `PedidoRepository`, DTO de entrada | `ProductoController` salta service; controller devuelve entidad Pedido |
| Resiliencia de evento | `ApplicationEventPublisher` para `PedidoCreadoEvent` | `PedidoServiceTest` verifica publish/never | Evento solo memoria y sin listener GIRC; Outbox/listener si requiere entrega durable |
| Persistencia | PostgreSQL + JPA, H2 en `@DataJpaTest` | `ReservaRepositoryDataJpaTest` | Integración de consultas de pedidos contra Postgres no creada; sin Flyway/Liquibase |
| Disponibilidad/despliegue | Docker Compose separa frontend, backend y DB | `docker-compose.yml` | No hay TLS, backup, healthchecks para API/frontend ni observabilidad productiva |
