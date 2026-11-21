# ADR-002: Transacciones y bloqueo pesimista de existencias

- **Estado:** Aceptada
- **Fecha:** 2026-11-21

## Contexto y problema

Pedidos concurrentes podrían leer el mismo `stockActual` y vender unidades por encima de las disponibles. RNF-02 exige integridad; RN-02.1 exige HTTP 422 sin guardar ni publicar evento si el stock es insuficiente.

## Alternativas evaluadas

1. `@Transactional` + `PESSIMISTIC_WRITE` por producto.
2. Control optimista con `@Version`, conflictos y reintentos.
3. Actualización SQL condicional (`stock_actual >= cantidad`) y comprobar filas afectadas.

## Decisión tomada

`PedidoServiceImpl.crearPedido()` es `@Transactional`; consulta cada producto con `ProductoRepository.findByIdWithLock()` (`@Lock(PESSIMISTIC_WRITE)`), valida todas las líneas y después muta las entidades administradas, guarda pedido/detalles y publica `PedidoCreadoEvent`. Las excepciones runtime provocan rollback.

## Consecuencias y trade-offs

- **Positivas:** serializa escrituras sobre la fila de producto; el pedido y los detalles se escriben en la transacción; tests verifican no guardar/evento en stock insuficiente.
- **Negativas:** locks largos reducen concurrencia; pedidos multítem que toman filas en distinto orden pueden aumentar riesgo de deadlock; el publisher en memoria no es durable.
- **Mitigaciones recomendadas:** bloquear IDs en orden ascendente, definir timeout, medir contención y considerar Outbox si el evento debe sobrevivir a fallos.
- **Brecha:** no hay prueba concurrente de dos transacciones contra PostgreSQL; la cobertura de bloqueo se infiere de la anotación/repositorio y pruebas funcionales.
