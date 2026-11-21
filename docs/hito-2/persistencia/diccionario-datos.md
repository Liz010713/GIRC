# Diccionario de datos y mapeo JPA

**Motor objetivo:** PostgreSQL 16. Los tipos SQL corresponden al mapeo PostgreSQL habitual de Hibernate 6. El DDL definitivo debe verificarse con migraciones antes de producción. La aplicación usa actualmente `spring.jpa.hibernate.ddl-auto=update`; no hay Flyway/Liquibase ni scripts versionados de migración.

## Tablas GIRC: inventario y pedidos

### `productos`
Entidad `com.courtsync.pro.domain.entity.Producto`.

| Columna | Tipo SQL | Restricciones observadas | ORM / descripción |
|---|---|---|---|
| `id` | `BIGINT` | PK, identity | `@Id`, `@GeneratedValue(IDENTITY)` |
| `sku` | `VARCHAR(50)` | NOT NULL, UNIQUE | Código comercial, `@Column(unique=true)` |
| `nombre_producto` | `VARCHAR(150)` | NOT NULL | Nombre visible |
| `precio_unitario` | `NUMERIC(12,2)` | NOT NULL; `@DecimalMin("0.0")` | `BigDecimal`, precio unitario |
| `stock_actual` | `INTEGER` | NOT NULL; `@Min(0)` | Existencias disponibles |
| `stock_minimo` | `INTEGER` | NOT NULL; `@Min(1)` | Umbral de alerta |
| `estado` | `VARCHAR(20)` | NOT NULL | `String`: Disponible, Crítico o Agotado; recalculado por service |

Índice único en `sku`. La consulta del catálogo hoy usa `findAll()` sin paginación.

### `pedidos`
Entidad `Pedido`.

| Columna | Tipo SQL | Restricciones observadas | ORM / descripción |
|---|---|---|---|
| `id` | `BIGINT` | PK, identity | Identificador |
| `codigo_orden` | `VARCHAR(40)` | NOT NULL, UNIQUE | Código `ORD-...` |
| `id_usuario` | `BIGINT` | NOT NULL, sin FK JPA | ID escalar aportado por request; no autentica identidad |
| `clave_idempotencia` | `VARCHAR(100)` | NOT NULL, UNIQUE | Evita reutilización de clave |
| `total_neto` | `NUMERIC(12,2)` | NOT NULL | Suma de subtotales |
| `estado` | `VARCHAR(30)` | NOT NULL | `String`, estado inicial Pendiente; no enum |
| `fecha_creacion` | `TIMESTAMP WITH TIME ZONE` | NOT NULL | `OffsetDateTime` UTC |

Relación `Pedido 1 -> 0..N DetallePedido`, `@OneToMany(cascade=ALL, orphanRemoval=true)`. El request valida lista no vacía, pero el esquema no fuerza que toda orden tenga detalle.

### `detalles_pedido`
Entidad `DetallePedido`.

| Columna | Tipo SQL | Restricciones observadas | ORM / descripción |
|---|---|---|---|
| `id` | `BIGINT` | PK, identity | Identificador |
| `pedido_id` | `BIGINT` | NOT NULL, FK -> `pedidos.id` | `@ManyToOne(fetch=LAZY)` |
| `producto_id` | `BIGINT` | NOT NULL, FK -> `productos.id` | `@ManyToOne`; actualmente hereda EAGER por omitir `fetch` |
| `cantidad_solicitada` | `INTEGER` | NOT NULL | Unidades pedidas |
| `precio_unitario` | `NUMERIC(12,2)` | NOT NULL | Precio histórico al momento de compra |
| `subtotal` | `NUMERIC(12,2)` | NOT NULL | Precio por cantidad |

PostgreSQL no crea índices automáticamente sobre FKs. Evaluar índices en `pedido_id` y `producto_id` según consultas/volumen.

## Entidades heredadas de reservas

Se conservan para respetar la plantilla del curso; no son el flujo de inventario GIRC.

### `jugadores`

| Columna | Tipo SQL | Restricciones | Mapeo / significado |
|---|---|---|---|
| `id` | `BIGINT` | PK, identity | ID |
| `nombre` | `VARCHAR(120)` | NOT NULL | Nombre |
| `email` | `VARCHAR(160)` | NOT NULL, UNIQUE | Correo |

### `canchas`

| Columna | Tipo SQL | Restricciones | Mapeo / significado |
|---|---|---|---|
| `id` | `BIGINT` | PK, identity | ID |
| `nombre` | `VARCHAR(150)` | NOT NULL | Nombre |
| `tipo_cancha` | `VARCHAR(30)` | NOT NULL | `@Enumerated(STRING)`, `TipoCancha` |
| `tarifa_hora` | `DOUBLE PRECISION` | NOT NULL | Tarifa |
| `activa` | `BOOLEAN` | NOT NULL | Indicador activo |

### `reservas`

| Columna | Tipo SQL | Restricciones | Mapeo / significado |
|---|---|---|---|
| `id` | `BIGINT` | PK, identity | ID |
| `codigo_confirmacion` | `VARCHAR(30)` | NOT NULL, UNIQUE | Código de reserva |
| `cancha_id` | `BIGINT` | NOT NULL, FK -> `canchas.id` | `ManyToOne(fetch=LAZY)` |
| `usuario_id` | `BIGINT` | NOT NULL, sin FK JPA a jugadores | ID escalar |
| `fecha_hora_inicio` | `TIMESTAMP WITH TIME ZONE` | NOT NULL | Inicio |
| `fecha_hora_fin` | `TIMESTAMP WITH TIME ZONE` | NOT NULL | Fin |
| `duracion_horas` | `INTEGER` | NOT NULL | Duración |
| `valor_total` | `DOUBLE PRECISION` | NOT NULL | Importe heredado |
| `valor_anticipo` | `DOUBLE PRECISION` | NOT NULL | Importe heredado |
| `estado` | `VARCHAR(30)` | NOT NULL | `@Enumerated(STRING)`, `EstadoReserva` |
| `fecha_creacion` | `TIMESTAMP WITH TIME ZONE` | NOT NULL | Fecha creación |
| `fecha_expiracion_pago` | `TIMESTAMP WITH TIME ZONE` | NOT NULL | Expiración |

Índices compuestos declarados: `idx_reservas_cancha_inicio_estado (cancha_id, fecha_hora_inicio, estado)` para disponibilidad y `idx_reservas_usuario_inicio (usuario_id, fecha_hora_inicio)` para límite diario.

## Integridad y notas para producción

- Las anotaciones Jakarta Validation validan request/entidades, pero no se debe asumir que `ddl-auto=update` ha creado todos los CHECK constraints en bases existentes. Inspeccionar DDL real.
- FKs actuales: `detalles_pedido.pedido_id`, `detalles_pedido.producto_id`, `reservas.cancha_id`. Los IDs de usuario no tienen FK.
- Cambiar `ddl-auto=update` por migraciones versionadas para producción.
- DTOs de respuesta recomendados: `PedidoController` actualmente responde una entidad y `Pedido.detalles` es LAZY; comprobar serialización con `open-in-view=false`.
- GIRC usa `BigDecimal`; reservas heredadas aún usa `Double` para dinero.
