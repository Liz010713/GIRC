# Diagramas C4 y UML — GIRC

Estos bloques Mermaid se renderizan en GitHub. Las fuentes canónicas editables están en [`diagrams/`](diagrams/).

## C4 Nivel 1 — Contexto

```mermaid
flowchart LR
  operador["Persona: Operador comercial / inventario<br/>Consulta existencias y prepara pedidos"]
  admin["Persona: Administrador del sistema<br/>Mantiene configuración y catálogo<br/>(rol/autorización no implementados)"]
  girc["Sistema: GIRC<br/>Gestión Integral de Recursos y Comercialización<br/>Consulta inventario y registra pedidos"]
  postgres[("Sistema externo: PostgreSQL 16<br/>Persistencia relacional")]
  correo["SMTP propuesto<br/>No conectado a pedidos; listener de reserva solo registra log"]
  pago["Pasarela de pago<br/>Fuera del flujo GIRC actual"]
  operador -->|HTTPS prod / HTTP local| girc
  admin -->|HTTPS prod / HTTP local| girc
  girc -->|JDBC / SQL| postgres
  girc -.->|Integración futura, no implementada| correo
  girc -.->|No aplica al flujo actual| pago
```

## C4 Nivel 2 — Contenedores

```mermaid
flowchart LR
  user["Operador comercial / inventario"]
  subgraph system["GIRC — Docker Compose actual"]
    browser["Navegador<br/>React 18 + TypeScript + Vite"]
    proxy["Frontend container<br/>Nginx: SPA + proxy /api/v1"]
    api["Backend container<br/>Java 21 + Spring Boot 3.4<br/>REST / JSON, Spring Data JPA"]
    db[("PostgreSQL 16<br/>girc_db")]
  end
  event["Spring ApplicationEventPublisher<br/>Evento en memoria"]
  user --> browser
  browser -->|HTTP :80 o dev :5173| proxy
  proxy -->|HTTP /api/v1| api
  api -->|JDBC| db
  api -->|PedidoCreadoEvent; sin listener GIRC| event
  prod["Producción recomendada, no configurada:<br/>TLS, secretos externos, backups, DB privada"]
  prod -.-> proxy
```

## C4 Nivel 3 — Componentes backend

```mermaid
flowchart TB
  subgraph backend["API — componentes observados"]
    pedidoController["PedidoController<br/>POST /api/v1/pedidos"]
    productoController["ProductoController<br/>GET /api/v1/productos"]
    service["PedidoServiceImpl<br/>idempotencia, stock, total, transacción"]
    pedidoRepo["PedidoRepository<br/>JpaRepository + idempotencia"]
    productoRepo["ProductoRepository<br/>JpaRepository + PESSIMISTIC_WRITE"]
    publisher["ApplicationEventPublisher<br/>PedidoCreadoEvent"]
    advice["GlobalExceptionHandler<br/>400 / 404 / 409 / 422"]
    entities["domain.entity<br/>Producto, Pedido, DetallePedido<br/>+ entidades heredadas"]
    dto["CrearPedidoRequest<br/>record + Jakarta Validation"]
    db[("PostgreSQL")]
    security["Filtros JWT / SecurityFilterChain<br/>No implementados"]
    listener["NotificacionListener<br/>solo evento de reserva y log"]
  end
  pedidoController --> dto
  pedidoController --> service
  service --> pedidoRepo
  service --> productoRepo
  pedidoRepo --> entities
  productoRepo --> entities
  pedidoRepo --> db
  productoRepo --> db
  service --> publisher
  publisher -.->|No existe consumidor GIRC actual| listener
  productoController -->|Acceso directo actual; ProductoService recomendado| productoRepo
  pedidoController -.-> advice
  productoController -.-> advice
  security -.-> pedidoController
```

## UML — Clases de dominio

```mermaid
classDiagram
  class Producto {
    +Long id
    +String sku
    +String nombreProducto
    +BigDecimal precioUnitario
    +Integer stockActual
    +Integer stockMinimo
    +String estado
  }
  class Pedido {
    +Long id
    +String codigoOrden
    +Long idUsuario
    +String claveIdempotencia
    +BigDecimal totalNeto
    +String estado
    +OffsetDateTime fechaCreacion
  }
  class DetallePedido {
    +Long id
    +Integer cantidadSolicitada
    +BigDecimal precioUnitario
    +BigDecimal subtotal
  }
  class Jugador {
    +Long id
    +String nombre
    +String email
  }
  class Cancha {
    +Long id
    +String nombre
    +TipoCancha tipoCancha
    +Double tarifaHora
    +Boolean activa
  }
  class Reserva {
    +Long id
    +String codigoConfirmacion
    +Long usuarioId
    +OffsetDateTime fechaHoraInicio
    +OffsetDateTime fechaHoraFin
    +Integer duracionHoras
    +Double valorTotal
    +Double valorAnticipo
    +EstadoReserva estado
    +OffsetDateTime fechaCreacion
    +OffsetDateTime fechaExpiracionPago
  }
  class TipoCancha {
    <<enumeration>>
    PADEL
    FUTBOL_5
    TENIS
  }
  class EstadoReserva {
    <<enumeration>>
    PENDIENTE_PAGO
    CONFIRMADA
    CANCELADA
    CANCELADA_CON_PENALIDAD
    EXPIRADA
    FINALIZADA
  }
  class PedidoServiceImpl {
    +crearPedido(request) Pedido
    -calcularEstadoProducto(producto) String
  }
  class ReservaServiceImpl {
    +crearReserva(request, usuarioId) ReservaResponse
  }
  Pedido "1" *-- "0..*" DetallePedido : cascade ALL
  DetallePedido "0..*" --> "1" Producto
  Reserva "0..*" --> "1" Cancha
  Cancha --> TipoCancha
  Reserva --> EstadoReserva
  Pedido ..> Jugador : idUsuario escalar, sin FK JPA
  Reserva ..> Jugador : usuarioId escalar, sin FK JPA
  PedidoServiceImpl ..> Pedido : construye y guarda
  PedidoServiceImpl ..> Producto : valida y actualiza stock
  ReservaServiceImpl ..> Reserva : construye y guarda
```

## UML — Secuencia Full Stack: crear pedido

```mermaid
sequenceDiagram
  autonumber
  actor Operador
  participant UI as React SPA
  participant Proxy as Nginx
  participant C as PedidoController
  participant V as Jakarta Validation
  participant S as PedidoServiceImpl
  participant PR as PedidoRepository
  participant R as ProductoRepository
  participant DB as PostgreSQL
  participant E as ApplicationEventPublisher
  participant H as GlobalExceptionHandler
  Operador->>UI: Elige productos y confirma
  UI->>Proxy: POST /api/v1/pedidos + JSON
  Proxy->>C: Reenvía HTTP
  C->>V: @Valid CrearPedidoRequest
  alt Request inválido
    V-->>H: MethodArgumentNotValidException
    H-->>UI: 400 ErrorResponse
  else Request válido
    V-->>C: DTO validado
    C->>S: crearPedido(request)
    S->>PR: existsByClaveIdempotencia
    PR->>DB: SELECT EXISTS
    DB-->>PR: existe / no existe
    alt Clave repetida
      PR-->>S: true
      S-->>H: ConflictoNegocioException
      H-->>UI: 409 ErrorResponse
    else Clave nueva
      loop Cada ítem
        S->>R: findByIdWithLock (PESSIMISTIC_WRITE)
        R->>DB: SELECT ... FOR UPDATE
        DB-->>R: Producto bloqueado
        R-->>S: Producto
      end
      alt Producto inexistente
        S-->>H: RecursoNoEncontradoException
        H-->>UI: 404 ErrorResponse
      else Stock insuficiente
        S-->>H: StockInsuficienteException
        H-->>UI: 422 ErrorResponse
        Note over S,DB: Rollback: no guardar pedido ni publicar evento.
      else Stock suficiente
        S->>S: Calcula subtotales, total y stock resultante
        S->>PR: save(Pedido + detalles)
        PR->>DB: INSERT y commit de transacción
        DB-->>PR: Pedido persistido
        PR-->>S: Pedido guardado
        S->>E: publishEvent(PedidoCreadoEvent)
        Note over E: No hay listener GIRC actualmente.
        S-->>C: Pedido
        C-->>UI: 201 Created + JSON
      end
    end
  end
```

## UML — Despliegue

```mermaid
flowchart TB
  subgraph client["<<device>> Equipo usuario"]
    browser["<<executionEnvironment>> Navegador<br/>React SPA"]
  end
  subgraph compose["<<node>> Host Docker Compose — desarrollo actual"]
    subgraph f["<<container>> girc-frontend"]
      nginx["Nginx :80<br/>SPA + reverse proxy /api/v1"]
    end
    subgraph b["<<container>> girc-backend"]
      spring["JRE 21<br/>Spring Boot API :8080"]
    end
    subgraph d["<<container>> girc-db"]
      pg["PostgreSQL 16 :5432"]
      vol[("postgres_data")]
      pg --- vol
    end
  end
  browser -->|HTTP| nginx
  nginx -->|HTTP privado| spring
  spring -->|JDBC| pg
  subgraph future["Producción recomendada — aún no desplegada"]
    tls["Proxy / Load Balancer TLS"]
    app["Frontend y Backend containers"]
    manageddb["PostgreSQL privado/administrado + backups"]
    sm["Secret Manager"]
  end
  tls -.-> app
  app -.-> manageddb
  sm -.-> app
```
