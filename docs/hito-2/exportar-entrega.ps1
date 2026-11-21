$ErrorActionPreference = 'Stop'

$docs = $PSScriptRoot
$diagramSource = Join-Path $docs 'diagrams'
$rendered = Join-Path $docs 'rendered'
New-Item -ItemType Directory -Force -Path $rendered | Out-Null

$chromeCandidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
)
$chrome = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) {
    throw 'Instala Google Chrome o Microsoft Edge antes de renderizar Mermaid.'
}

$puppeteerConfig = Join-Path $env:TEMP "girc-mermaid-$PID.json"
$configJson = @{
    executablePath = $chrome
    args = @('--no-sandbox', '--disable-setuid-sandbox')
} | ConvertTo-Json
[System.IO.File]::WriteAllText(
    $puppeteerConfig,
    $configJson,
    [System.Text.UTF8Encoding]::new($false)
)

try {
    Get-ChildItem -LiteralPath $diagramSource -Filter '*.mmd' | ForEach-Object {
        $png = Join-Path $rendered ($_.BaseName + '.png')
        npx --yes @mermaid-js/mermaid-cli@11.4.2 `
            -p $puppeteerConfig `
            -i $_.FullName `
            -o $png `
            -w 1800 -H 1400 -s 2
        if ($LASTEXITCODE -ne 0) {
            throw "Mermaid no pudo renderizar $($_.Name)."
        }
    }
}
finally {
    Remove-Item -LiteralPath $puppeteerConfig -Force -ErrorAction SilentlyContinue
}

$pandoc = (python -c 'import pypandoc; print(pypandoc.get_pandoc_path())').Trim()
if (-not (Test-Path -LiteralPath $pandoc) -and (Test-Path -LiteralPath ($pandoc + '.exe'))) {
    $pandoc += '.exe'
}
if (-not (Test-Path -LiteralPath $pandoc)) {
    throw 'No se encontró Pandoc. Instálalo con: python -m pip install --user pypandoc-binary'
}

$sections = [System.Collections.Generic.List[string]]::new()
$utf8 = [System.Text.Encoding]::UTF8
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$sections.Add([System.IO.File]::ReadAllText((Join-Path $docs 'Documento-Maestro-Parcial-2.md'), $utf8))
$sections.Add("`n# Anexo A - Diagramas renderizados`n")
$figures = @(
    @('C4 Level 1 - Context', 'c4-contexto'),
    @('C4 Level 2 - Containers', 'c4-contenedores'),
    @('C4 Level 3 - Backend components', 'c4-componentes-backend'),
    @('UML - Domain classes', 'uml-clases-dominio'),
    @('UML - Full Stack order sequence', 'uml-secuencia-crear-pedido'),
    @('UML - Deployment', 'uml-despliegue')
)
foreach ($figure in $figures) {
    $sections.Add("`n## $($figure[0])`n")
    $sections.Add("![ $($figure[0]) ](rendered/$($figure[1]).png){width=6.3in}`n")
}
$sections.Add("`n# Anexo B - Diccionario de datos`n")
$sections.Add([System.IO.File]::ReadAllText((Join-Path $docs 'persistencia\diccionario-datos.md'), $utf8))
$sections.Add("`n# Anexo C - Trazabilidad RNF`n")
$sections.Add([System.IO.File]::ReadAllText((Join-Path $docs 'Trazabilidad-RNF.md'), $utf8))
$sections.Add("`n# Anexo D - Evidencia SOLID y patrones`n")
$sections.Add([System.IO.File]::ReadAllText((Join-Path $docs 'Evidencia-SOLID-y-patrones.md'), $utf8))
$sections.Add("`n# Anexo E - ADRs`n")
Get-ChildItem -LiteralPath (Join-Path $docs 'adr') -Filter 'ADR-*.md' | Sort-Object Name | ForEach-Object {
    $sections.Add([System.IO.File]::ReadAllText($_.FullName, $utf8))
}

$combined = Join-Path $docs 'Documento-Maestro-Consolidado.md'
[System.IO.File]::WriteAllText($combined, ($sections -join "`n`n"), $utf8NoBom)
$docx = Join-Path $docs 'Documento-Maestro-Parcial-2.docx'
$pdf = Join-Path $docs 'Documento-Maestro-Parcial-2.pdf'
$html = Join-Path $docs 'Documento-Maestro-Consolidado.html'
$css = Join-Path $docs 'exportacion.css'

& $pandoc $combined --from=markdown --to=docx --standalone --toc `
    '--metadata=title=GIRC - Documento Maestro Parcial 2' `
    "--resource-path=$docs" `
    "--output=$docx"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $docx)) {
    throw 'Pandoc no pudo generar el documento Word.'
}

$chromeCandidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
)
$chrome = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) {
    throw 'Google Chrome is required to print the PDF.'
}

& $pandoc $combined --from=markdown --to=html5 --standalone --toc `
    '--metadata=title=GIRC - Documento Maestro Parcial 2' `
    "--resource-path=$docs" `
    "--css=$css" `
    "--output=$html"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $html)) {
    throw 'Pandoc no pudo generar el HTML intermedio para PDF.'
}

$htmlUri = ([System.Uri]$html).AbsoluteUri
& $chrome --headless --disable-gpu --no-first-run --no-default-browser-check --no-pdf-header-footer `
    "--print-to-pdf=$pdf" $htmlUri
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pdf)) {
    throw 'Chrome could not print the PDF.'
}

Get-Item -LiteralPath $docx, $pdf | Select-Object Name, Length, FullName
