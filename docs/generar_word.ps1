# Genera docs\TP-BDA-Tickets-Entrega1.docx armando el archivo Word a mano (un .docx es un ZIP con XML).
# No necesita tener Word instalado.  Uso: powershell -ExecutionPolicy Bypass -File docs\generar_word.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$carpeta = $PSScriptRoot
$carpetaImg = Join-Path $carpeta "img"
$salida = Join-Path $carpeta "TP-BDA-Tickets-Entrega1.docx"

$cuerpo = New-Object System.Text.StringBuilder
$imagenes = New-Object System.Collections.ArrayList
$ANCHO_UTIL = 9026   # ancho de texto en A4 con márgenes de 2,54 cm (en twips)

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }
function Agregar([string]$xml) { [void]$cuerpo.Append($xml) }

# Un "run" de texto. Opciones: b = negrita, i = cursiva, hl = resaltado amarillo, sz = tamaño en medios puntos, color
function Run([string]$texto, [switch]$b, [switch]$i, [switch]$hl, [int]$sz = 0, [string]$color = "") {
  $pr = ""
  if ($b) { $pr += "<w:b/>" }
  if ($i) { $pr += "<w:i/>" }
  if ($color) { $pr += "<w:color w:val=`"$color`"/>" }
  if ($sz) { $pr += "<w:sz w:val=`"$sz`"/><w:szCs w:val=`"$sz`"/>" }
  if ($hl) { $pr += "<w:highlight w:val=`"yellow`"/>" }
  "<w:r><w:rPr>$pr</w:rPr><w:t xml:space=`"preserve`">$(Esc $texto)</w:t></w:r>"
}

function P([string]$runs, [string]$estilo = "", [string]$alinear = "", [switch]$saltoAntes, [switch]$conSiguiente) {
  $pr = ""
  if ($estilo) { $pr += "<w:pStyle w:val=`"$estilo`"/>" }
  if ($conSiguiente) { $pr += "<w:keepNext/>" }
  if ($saltoAntes) { $pr += "<w:pageBreakBefore/>" }
  if ($alinear) { $pr += "<w:jc w:val=`"$alinear`"/>" }
  Agregar "<w:p><w:pPr>$pr</w:pPr>$runs</w:p>"
}

function Parrafo([string]$texto) { P (Run $texto) }
function Titulo1([string]$texto, [switch]$nuevaPagina) { P (Run $texto) "Heading1" -saltoAntes:$nuevaPagina }
function Titulo2([string]$texto) { P (Run $texto) "Heading2" }
function Vinetas([string[]]$items) { foreach ($x in $items) { P (Run $x) "ListBullet" } }
function Vacio { Agregar "<w:p/>" }

# Párrafo con partes en negrita marcadas con *asteriscos*
function Mixto([string[]]$partes) {
  $runs = ""
  foreach ($p in $partes) {
    if ($p.Length -gt 1 -and $p.StartsWith("*") -and $p.EndsWith("*")) { $runs += Run $p.Trim("*") -b } else { $runs += Run $p }
  }
  P $runs
}

# Tabla: primera fila = encabezado. $anchos en twips (deben sumar $ANCHO_UTIL). $colores: hashtable "fila,col" -> color de fondo
function Tabla([object[]]$filas, [int[]]$anchos, [hashtable]$colores = @{}, [hashtable]$textoBlanco = @{}) {
  $x = "<w:tbl><w:tblPr><w:tblW w:w=`"$ANCHO_UTIL`" w:type=`"dxa`"/><w:tblLayout w:type=`"fixed`"/>"
  $x += "<w:tblBorders>"
  foreach ($lado in "top","left","bottom","right","insideH","insideV") { $x += "<w:$lado w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"BFC6D1`"/>" }
  $x += "</w:tblBorders><w:tblCellMar><w:top w:w=`"60`" w:type=`"dxa`"/><w:left w:w=`"100`" w:type=`"dxa`"/><w:bottom w:w=`"60`" w:type=`"dxa`"/><w:right w:w=`"100`" w:type=`"dxa`"/></w:tblCellMar></w:tblPr><w:tblGrid>"
  foreach ($a in $anchos) { $x += "<w:gridCol w:w=`"$a`"/>" }
  $x += "</w:tblGrid>"
  for ($f = 0; $f -lt $filas.Count; $f++) {
    $x += "<w:tr>"
    if ($f -eq 0) { $x += "<w:trPr><w:tblHeader/></w:trPr>" }
    for ($c = 0; $c -lt $filas[$f].Count; $c++) {
      $fondo = if ($f -eq 0) { "E9F0F9" } elseif ($colores.ContainsKey("$f,$c")) { $colores["$f,$c"] } else { "" }
      $x += "<w:tc><w:tcPr><w:tcW w:w=`"$($anchos[$c])`" w:type=`"dxa`"/>"
      if ($fondo) { $x += "<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$fondo`"/>" }
      $x += "</w:tcPr>"
      $blanco = $textoBlanco.ContainsKey("$f,$c")
      $negrita = ($f -eq 0) -or $colores.ContainsKey("$f,$c")
      $color = if ($blanco) { "FFFFFF" } else { "" }
      $x += "<w:p><w:pPr><w:spacing w:after=`"0`"/></w:pPr>" + (Run $filas[$f][$c] -b:$negrita -sz 20 -color $color) + "</w:p></w:tc>"
    }
    $x += "</w:tr>"
  }
  $x += "</w:tbl>"
  Agregar $x
  Agregar "<w:p><w:pPr><w:spacing w:after=`"0`"/></w:pPr></w:p>"
}

# Imagen centrada con epígrafe. $anchoCm = ancho en el documento
function Imagen([string]$archivo, [string]$epigrafe, [double]$anchoCm = 15.9) {
  $ruta = Join-Path $carpetaImg $archivo
  $bmp = [System.Drawing.Image]::FromFile($ruta)
  $proporcion = $bmp.Height / $bmp.Width
  $bmp.Dispose()
  $n = $imagenes.Count + 1
  [void]$imagenes.Add($ruta)
  $cx = [int64]($anchoCm * 360000)
  $cy = [int64]($cx * $proporcion)
  $dibujo = @"
<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$n" name="Imagen $n"/><wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$n" name="imagen$n.png"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdImg$n"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:ln w="6350"><a:solidFill><a:srgbClr val="BFC6D1"/></a:solidFill></a:ln></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>
"@
  P $dibujo "" "center" -conSiguiente
  P (Run $epigrafe) "Caption" "center"
}

# =====================================================================
# CONTENIDO
# =====================================================================

# ---------- Carátula ----------
for ($k = 0; $k -lt 7; $k++) { Vacio }
P (Run "Ingeniería en Sistemas Informáticos" -sz 26) "" "center"
P (Run "Bases de Datos Aplicada" -sz 26) "" "center"
Vacio; Vacio
P (Run "Tablero de Control de Tickets de Soporte" -b -sz 52 -color "1F3F86") "" "center"
P (Run "Trabajo Cuatrimestral · Primera entrega" -sz 30 -color "5E6778") "" "center"
for ($k = 0; $k -lt 9; $k++) { Vacio }
P ((Run "Integrante: " -b) + (Run "Tobías Caprile")) "" "center"
P (Run "Grupo N°: " -b) "" "center"

# ---------- 1 ----------
Titulo1 "1. Descripción del proyecto" -nuevaPagina
Mixto @("El proyecto es un tablero de control (dashboard) para la ", "*mesa de ayuda*", " de una empresa. Cada vez que un empleado tiene un problema informático (una PC que no enciende, un usuario bloqueado, falta de internet, etc.) se registra un ", "*ticket*", ". El tablero muestra esos tickets agrupados y resumidos para que el responsable de soporte pueda ver rápidamente ", "*dónde se concentran los problemas, cuánto se tarda en resolverlos y si se cumplen los plazos acordados*", ".")
Titulo2 "Temática"
Parrafo "Gestión de incidencias (tickets de problemas) del área de soporte técnico de una empresa."
Titulo2 "Objetivo del tablero"
Parrafo "Ayudar al jefe de soporte a tomar decisiones: qué departamento genera más problemas, qué tipo de problemas son más frecuentes, qué técnicos están sobrecargados y qué tickets están por vencer o ya vencieron su plazo de resolución (SLA, Service Level Agreement: tiempo máximo de resolución según la prioridad)."
Titulo2 "Usuario del tablero"
Parrafo "El responsable o coordinador del área de soporte técnico, y la gerencia que quiera controlar la calidad del servicio."

# ---------- 2 ----------
Titulo1 "2. Tecnologías"
Tabla @(
  ,@("Parte", "Tecnología", "Por qué")
  ,@("Motor de base de datos", "PostgreSQL, alojado en Supabase", "Base relacional con SQL estándar, gratuita y accesible desde la web sin instalar un servidor propio.")
  ,@("Interfaz (frontend)", "HTML, CSS y JavaScript", "No requiere instalar nada: se abre en el navegador. Es fácil de explicar y de mantener.")
  ,@("Conexión a la base", "Librería supabase-js", "Permite ejecutar consultas y funciones SQL de la base desde JavaScript.")
  ,@("Seguridad de contraseñas", "Extensión pgcrypto (bcrypt)", "Las contraseñas se guardan encriptadas (hash), nunca en texto plano.")
  ,@("Repositorio", "GitHub", "Para alojar el código, como pide la cátedra.")
) @(2200, 2600, 4226)

# ---------- 3 ----------
Titulo1 "3. Entidades representadas" -nuevaPagina
Tabla @(
  ,@("Entidad", "Qué representa", "Por qué es relevante para el usuario")
  ,@("Tickets", "Cada problema reportado: título, estado, prioridad, fechas de creación y resolución.", "Es la entidad central: de ella salen todos los indicadores (cantidad, tiempos, cumplimiento del SLA).")
  ,@("Departamentos", "Áreas de la empresa que reportan problemas (Ventas, Logística, etc.).", "Permite ver qué áreas generan más incidencias y cuáles reciben peor servicio.")
  ,@("Categorías", "Tipo de problema (Hardware, Software, Redes, Accesos, Correo).", "Muestra qué tipo de problema es más frecuente y dónde conviene invertir (equipos nuevos, capacitación).")
  ,@("Técnicos", "Personal de soporte que resuelve los tickets.", "Permite controlar la carga de trabajo y el desempeño de cada técnico.")
) @(1800, 3400, 3826)
Mixto @("Tablas de apoyo: ", "*Prioridades*", " (define el SLA en horas de cada prioridad) y ", "*Usuarios*", " (personas que pueden entrar al tablero).")

# ---------- 4 ----------
Titulo1 "4. Modelo canónico de la base de datos" -nuevaPagina
Imagen "00_modelo_canonico.png" "Figura 1. Modelo canónico: tablas, claves primarias (PK), claves foráneas (FK), claves únicas (UK) y relaciones." 14
Titulo2 "Relaciones"
Vinetas @(
  "Un departamento reporta muchos tickets; cada ticket pertenece a un solo departamento (1 a N).",
  "Una categoría clasifica muchos tickets; cada ticket tiene una sola categoría (1 a N).",
  "Una prioridad se aplica a muchos tickets y define su plazo máximo de resolución (SLA) (1 a N).",
  "Un técnico resuelve muchos tickets; un ticket puede no tener técnico asignado todavía (0..1 a N).",
  "Cada técnico tiene una categoría como especialidad (1 a N).",
  "Usuarios es independiente: solo se usa para el inicio de sesión."
)

# ---------- 5 ----------
Titulo1 "5. Navegación entre niveles (Drill Down / Drill Up)"
Tabla @(
  ,@("Nivel", "Qué muestra", "Cómo se navega")
  ,@("1. Departamentos", "Cantidad de tickets, abiertos y % de cumplimiento del SLA de cada departamento.", "Clic en un departamento: baja al nivel 2.")
  ,@("2. Categorías", "Dentro del departamento elegido: tickets por tipo de problema y tiempo promedio de resolución.", "Clic en una categoría: baja al nivel 3. Botón Volver o ruta de navegación: sube al nivel 1.")
  ,@("3. Detalle de tickets", "Listado de tickets de esa categoría y departamento: prioridad, técnico, estado, horas usadas y semáforo.", "Botón Volver: sube al nivel 2.")
) @(1900, 4000, 3126)

# ---------- 6 ----------
Titulo1 "6. Semaforización"
Mixto @("Indicador: ", "*porcentaje de tickets resueltos dentro del SLA*", " (por departamento, categoría y técnico).")
Tabla @(
  ,@("Color", "Condición", "Significado")
  ,@("Verde", "90% o más", "Servicio normal o favorable.")
  ,@("Amarillo", "Entre 75% y 89%", "Advertencia: se están demorando tickets.")
  ,@("Rojo", "Menos de 75%", "Situación crítica: hay que reforzar o reorganizar el soporte.")
) @(1800, 2600, 4626) @{ "1,0" = "1F9D55"; "2,0" = "E0A100"; "3,0" = "D63C3C" } @{ "1,0" = 1; "3,0" = 1 }
Parrafo "En el nivel de detalle, cada ticket también tiene su propio semáforo: verde si usó menos del 75% del plazo, amarillo si usó entre el 75% y el 100%, y rojo si el plazo ya venció."
Parrafo "Plazos (SLA) por prioridad: Crítica 4 h · Alta 8 h · Media 24 h · Baja 72 h."

# ---------- 7 ----------
Titulo1 "7. Inicio de sesión"
Vinetas @(
  "Las credenciales se verifican contra la tabla usuarios de la base de datos.",
  "La contraseña se guarda como hash bcrypt (función crypt() de la extensión pgcrypto), nunca en texto plano.",
  "La página llama a la función SQL login(usuario, contraseña), que devuelve el usuario solo si la contraseña coincide con el hash guardado.",
  "La tabla usuarios está protegida con Row Level Security: no se puede leer directamente desde la web, solo a través de la función login().",
  "Si las credenciales son correctas, se redirige automáticamente al tablero. Si son incorrectas, se muestra un mensaje de error y no se permite el acceso.",
  "Si alguien intenta abrir el tablero sin haber iniciado sesión, es enviado de vuelta a la pantalla de login."
)

# ---------- 8 ----------
Titulo1 "8. Prototipo de interfaces" -nuevaPagina
Parrafo "A continuación se muestran las pantallas del sistema. El login ya funciona contra la base de datos. El tablero es un prototipo navegable: muestra la organización visual definitiva con números de ejemplo, que en la segunda entrega serán reemplazados por los resultados de consultas SQL."

Titulo2 "8.1 Inicio de sesión"
Parrafo "Pantalla de acceso al sistema. El usuario ingresa su nombre de usuario y contraseña, que se validan contra la tabla usuarios."
Imagen "01_login.png" "Figura 2. Pantalla de inicio de sesión." 6.3
Parrafo "Si el usuario o la contraseña no corresponden a un usuario registrado, se muestra un mensaje de error y no se permite el acceso al tablero."
Imagen "02_login_error.png" "Figura 3. Intento de acceso con credenciales incorrectas." 6.3

Titulo2 "8.2 Nivel 1: Resumen general por departamento"
Parrafo "Pantalla principal del tablero. Arriba se muestran los indicadores generales (total de tickets, tickets abiertos, porcentaje resuelto dentro del SLA con su semáforo y tiempo promedio de resolución). Abajo, un gráfico de barras con la cantidad de tickets por departamento y una tabla con el cumplimiento del SLA de cada uno. Al hacer clic en un departamento se baja al nivel 2."
Imagen "03_nivel1_resumen.png" "Figura 4. Nivel 1: resumen general con semáforo por departamento."

Titulo2 "8.3 Nivel 2: Categorías dentro de un departamento"
Parrafo "Muestra los indicadores del departamento elegido y cómo se distribuyen sus tickets por tipo de problema, con el tiempo promedio de resolución y el semáforo de cada categoría. La ruta de navegación y el botón Volver permiten regresar al nivel 1 (Drill Up). Al hacer clic en una categoría se baja al nivel 3."
Imagen "04_nivel2_departamento.png" "Figura 5. Nivel 2: categorías del departamento Logística."

Titulo2 "8.4 Nivel 3: Detalle de tickets"
Parrafo "Listado de los tickets de la categoría y departamento elegidos: prioridad, técnico asignado, estado, horas transcurridas frente al plazo (SLA) y semáforo individual de cada ticket. El botón Volver regresa al nivel 2."
Imagen "05_nivel3_tickets.png" "Figura 6. Nivel 3: tickets de la categoría Redes en Logística."

Titulo2 "8.5 Técnicos"
Parrafo "Vista complementaria con la carga de trabajo de cada técnico (tickets asignados y abiertos) y su porcentaje de cumplimiento del SLA, para detectar sobrecargas."
Imagen "06_tecnicos.png" "Figura 7. Carga de trabajo y cumplimiento por técnico."

# ---------- 9 ----------
Titulo1 "9. Repositorio" -nuevaPagina
P ((Run "Link al repositorio en GitHub: " -b) + (Run "https://github.com/Tcapri-05/TP-BDA-Tickets" -color "2457C5"))
Parrafo "El repositorio contiene todo el código del proyecto y los scripts SQL para recrear la base de datos desde cero. Su estructura es la siguiente:"
Tabla @(
  ,@("Archivo o carpeta", "Contenido")
  ,@("index.html", "Pantalla de inicio de sesión.")
  ,@("dashboard.html", "Tablero (prototipo navegable con los tres niveles y la vista de técnicos).")
  ,@("css/estilos.css", "Estilos visuales de todas las pantallas.")
  ,@("js/config.js", "Conexión a Supabase (URL y clave pública).")
  ,@("js/login.js", "Validación del login llamando a la función SQL login().")
  ,@("js/sesion.js", "Manejo de la sesión y protección del tablero.")
  ,@("js/prototipo.js", "Lógica de navegación (Drill Down / Drill Up) y semaforización.")
  ,@("sql/01_esquema.sql", "Creación de tablas, relaciones, restricciones, índices y seguridad (RLS).")
  ,@("sql/02_login.sql", "Función login() con contraseñas encriptadas con bcrypt.")
  ,@("sql/03_datos.sql", "Carga de datos iniciales con INSERT: departamentos, categorías, prioridades, técnicos, usuario de prueba y 200 tickets.")
  ,@("docs/", "Documentación de la entrega e imágenes.")
  ,@("README.md", "Instrucciones para abrir y ejecutar el proyecto.")
) @(2600, 6426)
Titulo2 "Cómo ejecutar el proyecto"
Vinetas @(
  "Base de datos: ejecutar en el SQL Editor de Supabase los scripts sql/01_esquema.sql, sql/02_login.sql y sql/03_datos.sql, en ese orden.",
  "Conexión: completar la URL y la clave pública del proyecto de Supabase en js/config.js.",
  "Aplicación: abrir index.html en el navegador (no requiere instalar nada)."
)

# =====================================================================
# ARMADO DEL ARCHIVO .docx
# =====================================================================
$ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"'

$documento = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document $ns><w:body>$($cuerpo.ToString())<w:sectPr><w:footerReference w:type="default" r:id="rIdFooter"/><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/><w:titlePg/></w:sectPr></w:body></w:document>
"@

$estilos = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="es-AR"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="360" w:after="160"/><w:pBdr><w:bottom w:val="single" w:sz="8" w:space="2" w:color="2457C5"/></w:pBdr><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:color w:val="1F3F86"/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="80"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:color w:val="2457C5"/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Caption"><w:name w:val="caption"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="60" w:after="240"/></w:pPr><w:rPr><w:i/><w:color w:val="5E6778"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="ListBullet"><w:name w:val="List Bullet"/><w:basedOn w:val="Normal"/><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr><w:spacing w:after="60"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Footer"><w:name w:val="footer"/><w:basedOn w:val="Normal"/></w:style>
<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>
</w:styles>
"@

$numeracion = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr></w:lvl></w:abstractNum>
<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>
"@

$pie = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:pStyle w:val="Footer"/><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:color w:val="5E6778"/><w:sz w:val="18"/></w:rPr><w:t xml:space="preserve">Tablero de Tickets de Soporte · Página </w:t></w:r><w:r><w:rPr><w:color w:val="5E6778"/><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:rPr><w:color w:val="5E6778"/><w:sz w:val="18"/></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r><w:r><w:rPr><w:color w:val="5E6778"/><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:rPr><w:color w:val="5E6778"/><w:sz w:val="18"/></w:rPr><w:t>2</w:t></w:r><w:r><w:rPr><w:color w:val="5E6778"/><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>
"@

$relsImagenes = ""
for ($k = 1; $k -le $imagenes.Count; $k++) {
  $relsImagenes += "<Relationship Id=`"rIdImg$k`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image`" Target=`"media/imagen$k.png`"/>"
}
$relsDocumento = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rIdNumbering" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/><Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>$relsImagenes</Relationships>
"@

$relsRaiz = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>
"@

$tipos = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>
"@

$propiedades = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>Tablero de Control de Tickets de Soporte - Primera entrega</dc:title><dc:creator>Tobías Caprile</dc:creator></cp:coreProperties>
"@

if (Test-Path $salida) { Remove-Item $salida }
$utf8 = New-Object System.Text.UTF8Encoding $false
$zip = [System.IO.Compression.ZipFile]::Open($salida, "Create")
function Parte([string]$nombre, [string]$contenido) {
  $e = $zip.CreateEntry($nombre)
  $w = New-Object System.IO.StreamWriter($e.Open(), $utf8)
  $w.Write($contenido.Trim())
  $w.Close()
}
Parte "[Content_Types].xml" $tipos
Parte "_rels/.rels" $relsRaiz
Parte "docProps/core.xml" $propiedades
Parte "word/document.xml" $documento
Parte "word/styles.xml" $estilos
Parte "word/numbering.xml" $numeracion
Parte "word/footer1.xml" $pie
Parte "word/_rels/document.xml.rels" $relsDocumento
for ($k = 1; $k -le $imagenes.Count; $k++) {
  [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $imagenes[$k - 1], "word/media/imagen$k.png")
}
$zip.Dispose()

# Validación rápida: cada parte XML tiene que poder leerse
$zip = [System.IO.Compression.ZipFile]::OpenRead($salida)
foreach ($e in $zip.Entries | Where-Object { $_.FullName -match '\.(xml|rels)$' }) {
  $r = New-Object System.IO.StreamReader($e.Open()); $x = New-Object System.Xml.XmlDocument; $x.LoadXml($r.ReadToEnd()); $r.Close()
}
$zip.Dispose()
Write-Host "Listo: $salida ($($imagenes.Count) imágenes)"
