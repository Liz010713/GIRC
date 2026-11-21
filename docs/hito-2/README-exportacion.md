# Exportar la entrega a PDF y Word

El Documento Maestro tiene fuentes Markdown/Mermaid. El script `exportar-entrega.ps1` renderiza las seis fuentes Mermaid a PNG y SVG, integra el Documento Maestro, el diccionario, trazabilidad RNF, evidencia SOLID y ADRs, y genera DOCX y PDF.

## Requisitos en Windows

- Python 3
- Node.js/npm y acceso a npm para Mermaid CLI
- Google Chrome
- Pandoc (se instala como binario Python)

## Instalar Pandoc

```powershell
python -m pip install --user pypandoc-binary
```

## Generar los entregables

Desde PowerShell:

```powershell
Set-Location "<ruta-del-proyecto>\docs\hito-2"
.\exportar-entrega.ps1
```

El script escribe:

- `Documento-Maestro-Parcial-2.docx`
- `Documento-Maestro-Parcial-2.pdf`
- `Documento-Maestro-Consolidado.md`
- `Documento-Maestro-Consolidado.html` (vista intermedia para impresión)
- Figuras `.png` y `.svg` en `rendered/`

La portada contiene campos `[Completar]`; revisa integrantes, curso, docente e institución antes de entregar. Regenera los documentos después de editar Markdown o diagramas.
