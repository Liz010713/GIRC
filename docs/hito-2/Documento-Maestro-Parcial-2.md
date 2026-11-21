# Documento Maestro — Parcial 2

## GIRC
### Sistema de Gestión Integral de Recursos y Comercialización

**Asignatura:** [Completar]<br>
**Docente:** [Completar]<br>
**Integrantes:** [Completar nombres del equipo]<br>
**Institución:** [Completar]<br>
**Fecha:** 21 de noviembre de 2026<br>
**Repositorio:** [Liz010713/GIRC](https://github.com/Liz010713/GIRC)

> Este documento describe la implementación y la arquitectura verificadas en el repositorio. Los elementos marcados como *propuestos*, *brecha* o *no implementados* no deben presentarse como funcionalidad existente.

## 1. Resumen ejecutivo

GIRC es una aplicación web para consultar inventario y registrar pedidos. La SPA React consulta productos desde Spring Boot, permite seleccionar artículos y enviar un pedido. El backend valida idempotencia, bloquea filas de productos, comprueba existencias, calcula subtotales y total, actualiza el estado del stock, persiste pedido/detalles y publica un evento de aplicación.

El estilo adoptado es **monolito modular con arquitectura en capas**. El repositorio conserva clases de reservas del proyecto formativo original como módulo heredado; la interfaz principal y la identidad visible ahora corresponden a GIRC.

## 2. Alcance actual y evidencia

| Capacidad | Evidencia actual |
|---|---|
| Consultar inventario | `GET /api/v1/productos`, `ProductoController`, `ProductoRepository.findAll()` |
| Crear pedido | `POST /api/v1/pedidos`, `PedidoController`, `PedidoServiceImpl` |
| Validación de entrada | `CrearPedidoRequest` con `@NotNull`, `@NotBlank`, `@NotEmpty`, `@Valid`, `@Min(1)` |
| Idempotencia | `PedidoRepository.existsByClaveIdempotencia()` y UNIQUE en columna |
| Concurrencia de stock | `@Transactional` y `findByIdWithLock()` con `PESSIMISTIC_WRITE` |
| Errores HTTP | `GlobalExceptionHandler`: 400, 404, 409 y 422 |
| Eventos | Se publica `PedidoCreadoEvent`; aún no existe listener de pedido |
| Notificaciones | El listener heredado de reservas solo escribe log; no hay SMTP real |
| Seguridad | No hay autenticación/autorización implementada; no desplegar API abierta |
| Integraciones de pago | No forman parte del flujo actual de GIRC |

## 3. Justificación del estilo arquitectónico

### Estilo seleccionado: monolito modular en capas

El backend es una aplicación Spring Boot única, separada en `controller`, `service`, `repository`, `domain.entity`, `dto` y `exception`. React se despliega como SPA y se comunica con la API mediante HTTP/JSON. PostgreSQL es un contenedor separado.

Se elige este estilo para el alcance formativo porque mantiene una transacción atómica para consultar y actualizar stock, simplifica pruebas con JUnit/Mockito/MockMvc/H2 y hace explícitas las responsabilidades. Microservicios añadirían coordinación de transacciones y despliegue sin una necesidad demostrada. Hexagonal/Clean sería viable si aumentan integraciones, pero hoy no hay puertos/adaptadores definidos.

### Relación con atributos de calidad

| Atributo | Mecanismo actual | Evidencia / riesgo |
|---|---|---|
| Integridad/concurrencia (RNF-02) | `@Transactional`, bloqueo `PESSIMISTIC_WRITE`, UNIQUE de clave idempotente | No hay benchmark ni prueba de concurrencia real en PostgreSQL; riesgo de contención/deadlock con pedidos multítem |
| Rendimiento | Índices compuestos de reservas; React filtra catálogo en cliente | Catálogo usa `findAll()` sin paginación; P95 no medido |
| Seguridad | Validación de entrada, manejo central de errores, parámetros JPA | No existe SecurityFilterChain, JWT ni control por rol; CORS permite `*` |
| Mantenibilidad (RNF-05) | Interfaces de servicio/repository y DTO de entrada | `ProductoController` accede directo al repository; controllers de pedido devuelven entidades JPA |
| Resiliencia/eventos | `ApplicationEventPublisher`; listener de reserva async AFTER_COMMIT | `PedidoCreadoEvent` no tiene consumidor y Spring event en memoria no es durable |
| Despliegue | Docker Compose para DB, API y Nginx | Compose describe entorno local; proxy TLS, backups y monitoreo de producción no están configurados |

## 4. Modelo C4

Los seis diagramas editables están en [`diagrams/`](diagrams/). La versión para lectura/render en GitHub está en [Diagramas del Parcial 2](diagramas.md).

### Nivel 1 — Contexto

Sistema central GIRC, operador comercial/inventario y administrador como actores conceptuales. PostgreSQL es dependencia real. SMTP se muestra como sistema propuesto/no conectado para GIRC; una pasarela de pago se declara fuera del flujo actual. La autenticación de roles no está implementada.

Fuente: [`c4-contexto.mmd`](diagrams/c4-contexto.mmd).

### Nivel 2 — Contenedores

Navegador con React/TypeScript, Nginx como servidor SPA/proxy, API Java 21/Spring Boot y PostgreSQL 16. Comunicación local HTTP, API JSON y JDBC. La sección de producción del dibujo se etiqueta expresamente como recomendación, no como despliegue existente.

Fuente: [`c4-contenedores.mmd`](diagrams/c4-contenedores.mmd).

### Nivel 3 — Componentes del backend

Se muestran controllers, DTO, service, repositories, entidades, manejo global de errores y evento de aplicación. No se dibuja un filtro JWT como existente: se marca como brecha. También se hace visible que `ProductoController` consulta el repository directamente.

Fuente: [`c4-componentes-backend.mmd`](diagrams/c4-componentes-backend.mmd).

## 5. UML esencial

### Clases de dominio

El diagrama cubre entidades GIRC y las entidades de reservas que permanecen en la plantilla. Cardinalidades reales: `Pedido 1 — 0..N DetallePedido`, `DetallePedido N — 1 Producto`, `Reserva N — 1 Cancha`. `idUsuario`/`usuarioId` son escalares sin FK a `Jugador`. `Pedido.estado` y `Producto.estado` son strings, no enums. La lista de items del request exige 1..n en API, pero la BD no impone la existencia de hijos.

Las entidades son anémicas en el código actual: `crearPedido()` y `calcularEstadoProducto()` residen en `PedidoServiceImpl`; `crearReserva()` reside en `ReservaServiceImpl`. El diagrama muestra estas operaciones donde son implementadas, sin atribuirlas a las entidades.

Fuente: [`uml-clases-dominio.mmd`](diagrams/uml-clases-dominio.mmd).

### Secuencia Full Stack de crear pedido

El flujo incluye validación 400, idempotencia 409, producto ausente 404, stock insuficiente 422, camino válido, bloqueo de producto, persistencia y respuesta 201. En el camino 422 la transacción revierte y no se guarda ni publica evento. La publicación del evento no tiene subscriber GIRC hoy.

Fuente: [`uml-secuencia-crear-pedido.mmd`](diagrams/uml-secuencia-crear-pedido.mmd).

### Despliegue

El entorno reproducible actual es Docker Compose: Nginx, API y PostgreSQL con volumen local. El diagrama distingue una propuesta de producción con TLS, secretos externos y PostgreSQL protegido; no se afirma que exista un VPS/cloud desplegado.

Fuente: [`uml-despliegue.mmd`](diagrams/uml-despliegue.mmd).

## 6. Persistencia y ORM

El diccionario detallado con tipo SQL, restricciones, claves, índices, significado y mapeo se encuentra en [`persistencia/diccionario-datos.md`](persistencia/diccionario-datos.md).

Buenas prácticas presentes: PK identity; SKU/código/idempotencia únicos; FK para detalles y cancha de reserva; `BigDecimal` en importes GIRC; `@Enumerated(EnumType.STRING)` en estados/tipos del módulo de reserva; `FetchType.LAZY` en relaciones Reserva-Cancha, Pedido-Detalles y Detalle-Pedido. Excepción detectada: `DetallePedido.producto` omite `fetch`, por lo que JPA lo deja EAGER.

`ddl-auto=update` es cómodo en desarrollo, pero para producción se recomienda Flyway/Liquibase. Validar FKs, CHECKs e índices en PostgreSQL real; H2 es evidencia de tests, no sustituto de todas las pruebas de dialecto.

## 7. Diseño limpio y patrones

### Responsabilidades/SOLID observables

- **SRP:** `PedidoController` recibe HTTP; `PedidoServiceImpl` aplica reglas; repositories aíslan acceso a datos; `GlobalExceptionHandler` traduce excepciones.
- **DIP:** servicios reciben interfaces repository y `ApplicationEventPublisher` por constructor (`@RequiredArgsConstructor`).
- **DTO:** `CrearPedidoRequest` y su tipo `Item` aíslan y validan el contrato de entrada.
- **Repository:** `PedidoRepository`/`ProductoRepository` abstraen persistencia; Spring Data genera operaciones CRUD.
- **Observer/Event:** `PedidoServiceImpl` publica `PedidoCreadoEvent`. El patrón de publicación existe, pero falta un listener específico de pedidos.
- **Transacción:** `@Transactional` mantiene actualización de stock y creación de pedido en una unidad atómica.

### Brechas recomendadas antes de llamarlo listo para producción

1. Crear `ProductoService` para que `ProductoController` no dependa directamente del repository.
2. Definir DTO de respuesta de pedido/producto y evitar serializar entidades JPA directamente.
3. Declarar `DetallePedido.producto` como `FetchType.LAZY` y probar serialización con OSIV apagado.
4. Implementar seguridad (OIDC/JWT/roles), restringir CORS y no confiar en `idUsuario` del body.
5. Añadir listener de `PedidoCreadoEvent` o retirar el evento si no se consume; usar Outbox si se exige durabilidad.
6. Añadir migraciones de esquema, paginación de productos, índices medidos y pruebas de concurrencia PostgreSQL.

## 8. Registros de decisiones (ADRs)

1. [ADR-001 — Monolito modular en capas](adr/ADR-001-monolito-modular-en-capas.md)
2. [ADR-002 — Transacciones y bloqueo pesimista](adr/ADR-002-transacciones-y-bloqueo-pesimista.md)
3. [ADR-003 — PostgreSQL y JPA](adr/ADR-003-postgresql-y-jpa.md)
4. [ADR-004 — Seguridad y autenticación](adr/ADR-004-seguridad-y-autenticacion.md) (propuesta / brecha)

## 9. Pruebas y evidencia

En la última validación registrada del repositorio se ejecutaron **21 pruebas backend, 0 fallidas, `BUILD SUCCESS`**. El frontend pasó `npm ci` y `npm run build`. Las pruebas cubren servicio de pedidos, MockMvc, reglas de reservas heredadas y `@DataJpaTest` con H2 para solapamiento parcial, contigüidad y cancelación.

La cobertura no representa una prueba de carga, seguridad, concurrencia real de PostgreSQL, integración SMTP ni despliegue TLS. Añadir evidencia si se ejecutan esas pruebas en el entorno del equipo.

## 10. Cómo presentar el trabajo, paso a paso

1. Presentar GIRC y delimitar actores: operador comercial/inventario y administrador conceptual; explicar que los roles aún no se autentican.
2. Explicar por qué se eligió un monolito modular por capas y cómo una transacción protege el flujo de pedido.
3. Recorrer C4 Contexto: quién usa el sistema y qué dependencia real existe; aclarar que SMTP y pagos no forman una integración GIRC actual.
4. Recorrer C4 Contenedores: SPA, Nginx, API y PostgreSQL; separar desarrollo local de propuesta productiva.
5. Recorrer Componentes: request validado, controller, service, repositories, entidades y handler; mencionar el acceso directo del controller de producto como mejora pendiente.
6. Leer el UML de clases y explicar las cardinalidades, las FKs reales y los IDs de usuario escalares.
7. Narrar la secuencia de pedido y detenerse en los `alt`: 400, 409, 404, 422 y 201.
8. Explicar el diccionario de datos, unicidad de idempotencia, FKs, precisión monetaria e índices heredados de reservas.
9. Presentar ADRs como decisiones con alternativas y trade-offs, no como descripción genérica.
10. Cerrar con evidencia: `mvn test`, build frontend y brechas de producción declaradas.

## 11. Lista de entrega del equipo

- [ ] Completar integrantes, curso, docente e institución en esta portada.
- [ ] Revisar términos y alcance contra las historias de usuario y OpenAPI aprobados por el profesor.
- [ ] Revisar la sección de brechas con el equipo; no presentar pagos, autenticación, SMTP real o TLS como existentes.
- [ ] Exportar este documento y la página de diagramas a PDF/Word desde un editor compatible si la plataforma exige ese formato. Los fuentes editables Mermaid permanecen bajo `docs/hito-2/diagrams/`.
- [ ] Adjuntar capturas de las pruebas/CI si las solicitan.
