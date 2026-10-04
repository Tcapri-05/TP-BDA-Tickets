# Servidor web local mínimo para probar el proyecto (no hace falta instalar nada).
# Uso: powershell -ExecutionPolicy Bypass -File servidor.ps1   → abrir http://localhost:5500
$puerto = 5500
$raiz = $PSScriptRoot
$tipos = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"; ".js" = "application/javascript; charset=utf-8"; ".png" = "image/png"; ".svg" = "image/svg+xml" }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$puerto/")
$listener.Start()
Write-Host "Servidor en http://localhost:$puerto  (Ctrl+C para cortar)"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $ruta = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart("/"))
  if ($ruta -eq "") { $ruta = "index.html" }
  $archivo = Join-Path $raiz $ruta
  if ((Test-Path $archivo -PathType Leaf) -and ([IO.Path]::GetFullPath($archivo).StartsWith($raiz))) {
    $bytes = [IO.File]::ReadAllBytes($archivo)
    $ext = [IO.Path]::GetExtension($archivo).ToLower()
    $ctx.Response.ContentType = if ($tipos.ContainsKey($ext)) { $tipos[$ext] } else { "application/octet-stream" }
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else {
    $ctx.Response.StatusCode = 404
  }
  $ctx.Response.Close()
}
