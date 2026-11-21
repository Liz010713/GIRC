# Hito 2 — Arquitectura y diseño GIRC

## Entrega

- [Documento Maestro del Parcial 2](Documento-Maestro-Parcial-2.md): justificación, C4/UML, diccionario, SOLID/patrones, ADRs, pruebas y guía de exposición.
- [Documento consolidado Word](Documento-Maestro-Parcial-2.docx)
- [Documento consolidado PDF](Documento-Maestro-Parcial-2.pdf)
- [Diagramas renderizados](diagramas.md): vista Mermaid en GitHub.
- [`diagrams/`](diagrams/): fuentes Mermaid independientes y editables.
- [`persistencia/diccionario-datos.md`](persistencia/diccionario-datos.md): columnas SQL, restricciones, relaciones e índices.
- [`adr/`](adr/): cuatro decisiones arquitectónicas con estado explícito.

## Fuentes Mermaid

1. `diagrams/c4-contexto.mmd`
2. `diagrams/c4-contenedores.mmd`
3. `diagrams/c4-componentes-backend.mmd`
4. `diagrams/uml-clases-dominio.mmd`
5. `diagrams/uml-secuencia-crear-pedido.mmd`
6. `diagrams/uml-despliegue.mmd`

## Nota de rigor

Los diagramas documentan el código existente y marcan qué es propuesta. No se debe presentar autenticación, envío SMTP, pagos, TLS productivo ni listener de pedidos como funcionalidades implementadas. El paquete `com.courtsync.pro` se conserva porque forma parte de la plantilla del curso; la identidad de producto y el código de arranque visible ya usan GIRC.
