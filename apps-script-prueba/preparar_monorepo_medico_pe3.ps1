# PE3/012 - unificacion inicial de programacion medica.
# No elimina ni altera repositorios originales, ni despliegues Apps Script.
$ErrorActionPreference = 'Stop'
$Destino = 'C:\PE3\medicina-pe3'
$Repo = 'joansamo20/medicina-pe3'
$ReporteArchivo = Join-Path $env:USERPROFILE 'Documents\PE3\Medicina\reporte_union_012.json'
$BaseAgenda = 'https://raw.githubusercontent.com/joansamo20/proyecto_prueba_cli/deefe3a4c675a97fa1e012a3dfb42b1c2dc12f2c/apps-script-prueba'
$Reporte = [ordered]@{
  Version = 'PE3-MEDICO-V1'
  Fecha = (Get-Date).ToString('o')
  EstadoEjecucion012 = 1
  EstadoFuncional = 'NoIniciado'
  Repositorio = 'https://github.com/joansamo20/medicina-pe3'
  RutaPC = $Destino
  Etapas = @()
  Modulos = [ordered]@{
    Agenda = @{EstadoEjecucion012=1;EstadoFuncional='Pendiente'}
    Boletas = @{EstadoEjecucion012=1;EstadoFuncional='Pendiente'}
    Recetas = @{EstadoEjecucion012=1;EstadoFuncional='Pendiente'}
  }
  ProximaAccion = ''
  Diagnostico = ''
}

function ComprobarEntorno {
  try {
    if(-not (Get-Command 'gh.exe' -ErrorAction SilentlyContinue)){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='FaltaGH';Diagnostico='Se requiere GitHub CLI gh.exe'}}
    }
    if(-not (Get-Command 'git.exe' -ErrorAction SilentlyContinue)){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='FaltaGit';Diagnostico='Se requiere Git'}}
    }
    $usuario = (& gh api user --jq '.login' 2>&1 | Out-String).Trim()
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='GHNoAutenticado';Diagnostico='Completar gh auth login'}}
    }
    if($usuario -cne 'joansamo20'){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='UsuarioGHIncorrecto';Diagnostico="Cuenta activa: $usuario. Se requiere joansamo20; no se cambia la cuenta."}}
    }
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='GitHubVerificado';Usuario=$usuario}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ErrorComprobacion';Diagnostico=$_.Exception.Message}}
  }
}
function CrearRepositorio {
  try {
    $salida = (& gh repo view $Repo --json isPrivate --jq '.isPrivate' 2>$null | Out-String).Trim()
    if($LASTEXITCODE -eq 0){
      if($salida -ne 'true'){
        return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='RepoNoPrivado';Diagnostico='El destino ya existe, pero no es privado'}}
      }
      return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='RepositorioPrivadoExistente'}}
    }
    $salida = (& gh repo create $Repo --private --description 'Sistema medico modular personal PE3' 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='CreacionFallida';Diagnostico=$salida.Trim()}}
    }
    $privado = (& gh repo view $Repo --json isPrivate --jq '.isPrivate' 2>&1 | Out-String).Trim()
    if($LASTEXITCODE -ne 0 -or $privado -ne 'true'){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='PrivacidadNoVerificada';Diagnostico='Se intento crear el destino, pero no se verifico privacidad'}}
    }
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='RepositorioPrivadoCreado'}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ErrorRepositorio';Diagnostico=$_.Exception.Message}}
  }
}
function PrepararLocal {
  try {
    New-Item -ItemType Directory -Path (Split-Path $Destino -Parent) -Force | Out-Null
    if(Test-Path $Destino){
      if(Test-Path (Join-Path $Destino '.git')){
        $url = (& git -C $Destino remote get-url origin 2>&1 | Out-String).Trim()
        if($LASTEXITCODE -ne 0 -or $url -notmatch 'joansamo20/medicina-pe3'){
          return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='DestinoGitDistinto';Diagnostico='La carpeta local apunta a otro repositorio'}}
        }
        $status = (& git -C $Destino status --porcelain 2>&1 | Out-String).Trim()
        if($status){
          return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='DestinoConCambios';Diagnostico='Hay cambios locales en el repositorio destino'}}
        }
        return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='ClonExistente'}}
      }
      if((Get-ChildItem -LiteralPath $Destino -Force | Measure-Object).Count -gt 0){
        return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='DirectorioOcupado';Diagnostico='C:\PE3\medicina-pe3 existe sin ser un repo Git'}}
      }
      Remove-Item -LiteralPath $Destino -Force
    }
    $salida=(& gh repo clone $Repo $Destino 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ClonFallido';Diagnostico=$salida.Trim()}}
    }
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='ClonListo'}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ErrorLocal';Diagnostico=$_.Exception.Message}}
  }
}
function ImportarAgenda {
  try {
    $carpeta=Join-Path $Destino 'agenda\apps-script'
    New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
    foreach($archivo in @('Code.gs','Index.html','appsscript.json')){
      $destino=Join-Path $carpeta $archivo
      Invoke-WebRequest -UseBasicParsing -Uri "$BaseAgenda/$archivo" -OutFile $destino -ErrorAction Stop
      if((Get-Item -LiteralPath $destino).Length -eq 0){
        return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ArchivoVacio';Diagnostico=$archivo}}
      }
    }
    $origen = @'
# Agenda - origen comprobable
Repositorio: joansamo20/proyecto_prueba_cli
Rama: experimento/apps-script-pe3
Fuentes: Code.gs, Index.html, appsscript.json
Version origen: deefe3a4c675a97fa1e012a3dfb42b1c2dc12f2c
El despliegue existente permanece intacto. No se importaron credenciales.
'@
    Set-Content -LiteralPath (Join-Path $carpeta 'ORIGEN.md') -Value $origen -Encoding UTF8
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='AgendaImportada';Archivos=3}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='FalloImportacionAgenda';Diagnostico=$_.Exception.Message}}
  }
}
function InventariarBoletas {
  try {
    $ruta='C:\proyecto-boletas\sii'
    if(Test-Path (Join-Path $ruta '.git')){
      $estado=(& git -C $ruta status --porcelain 2>&1 | Out-String).Trim()
      if($LASTEXITCODE -ne 0){
        return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='EstadoLocalDesconocido'}}
      }
      if($estado){
        return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='TrabajoLocalPendiente';Diagnostico='Hay modificaciones locales no registradas; no se importan a ciegas'}}
      }
    }
    $info=(& gh repo view 'joansamo20/sii-custom' --json isPrivate --jq '.isPrivate' 2>&1 | Out-String).Trim()
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='RepoBoletasInaccesible'}}
    }
    if($info -ne 'true'){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='PrivacidadBoletasNoConfirmada'}}
    }
    return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='FuenteBoletasIdentificadaSinImportar';Diagnostico='Origen privado desarrollo/asodial identificado; falta inspeccionar datos, tokens e historial antes de copiar'}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ErrorInventarioBoletas';Diagnostico=$_.Exception.Message}}
  }
}
function PrepararEstructura {
  try {
    foreach($m in @('boletas','recetas','compartido')){
      New-Item -ItemType Directory -Path (Join-Path $Destino $m) -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $Destino 'boletas\README.md') -Value 'Origen identificado: joansamo20/sii-custom (desarrollo/asodial). Importacion pendiente de auditoria de archivos y cambios locales.' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $Destino 'recetas\README.md') -Value 'Tampermonkey MINSAL/SNRE. Aun no hay un repositorio origen identificado. No copiar datos clinicos reales ni logs con RUT.' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $Destino 'compartido\README.md') -Value 'Componentes PE3/012 compartidos. Sin implementaciones comunes hasta verificarlas.' -Encoding UTF8
    $texto = @'
# Medicina PE3
Repositorio PRIVADO: boletas SII, recetas SNRE/MINSAL y agenda Apps Script.
Los repositorios de origen permanecen intactos.
La agenda se importo como instantanea; boletas y recetas estan pendientes de importacion.
Toda funcion propia devuelve (EstadoEjecucion012, Dato) y cada punto de recepcion maneja 0, 1 y 2 explicitamente.
No almacenar tokens OAuth, .clasp.json, RUT, historias clinicas ni reportes administrativos en Git.
'@
    Set-Content -LiteralPath (Join-Path $Destino 'README.md') -Value $texto -Encoding UTF8
    $ignore = @'
.env
.env.*
.clasp.json
.clasprc.json
**/node_modules/
**/outputs/
**/reportes_privados/
**/credentials.json
**/token.json
*.pem
*.p12
*.pfx
*.key
*.sqlite
*.db
'@
    Set-Content -LiteralPath (Join-Path $Destino '.gitignore') -Value $ignore -Encoding UTF8
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='MonorepoEstructurado'}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='FalloEstructura';Diagnostico=$_.Exception.Message}}
  }
}
function Publicar {
  try {
    $id=(& git -C $Destino config user.name 2>&1 | Out-String).Trim()
    $correo=(& git -C $Destino config user.email 2>&1 | Out-String).Trim()
    if(-not $id -or -not $correo){
      return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='IdentidadGitPendiente';Diagnostico='Configurar user.name y user.email en Git; no se inventaron datos'}}
    }
    $rama=(& git -C $Destino branch --show-current 2>&1 | Out-String).Trim()
    if($rama -ne 'main'){
      & git -C $Destino symbolic-ref HEAD refs/heads/main 2>&1 | Out-Null
      if($LASTEXITCODE -ne 0){
        return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='RamaGitFallida'}}
      }
    }
    $salida=(& git -C $Destino add README.md .gitignore agenda boletas recetas compartido 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='GitAddFallido';Diagnostico=$salida.Trim()}}
    }
    $pendientes=(& git -C $Destino diff --cached --name-only 2>&1 | Out-String).Trim()
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='GitDiffFallido'}}
    }
    if($pendientes){
      $salida=(& git -C $Destino commit -m 'PE3: inicializar sistema medico modular' 2>&1 | Out-String)
      if($LASTEXITCODE -ne 0){
        return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='GitCommitFallido';Diagnostico=$salida.Trim()}}
      }
    }
    $salida=(& git -C $Destino push -u origin main 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){
      return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='GitPushFallido';Diagnostico=$salida.Trim()}}
    }
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='PublicacionGitVerificada'}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='ErrorPublicacion';Diagnostico=$_.Exception.Message}}
  }
}
function Secuencia {
  $hayPendiente=$false
  foreach($etapa in @('CrearRepositorio','PrepararLocal','ImportarAgenda','InventariarBoletas','PrepararEstructura','Publicar')){
    $r=& $etapa
    $Reporte.Etapas += @{Nombre=$etapa;EstadoEjecucion012=$r.EstadoEjecucion012;EstadoFuncional=$r.Dato.EstadoFuncional}
    if($etapa -eq 'ImportarAgenda'){
      $Reporte.Modulos.Agenda=@{EstadoEjecucion012=$r.EstadoEjecucion012;EstadoFuncional=$r.Dato.EstadoFuncional}
    }
    if($etapa -eq 'InventariarBoletas'){
      $Reporte.Modulos.Boletas=@{EstadoEjecucion012=$r.EstadoEjecucion012;EstadoFuncional=$r.Dato.EstadoFuncional}
    }
    switch([int]$r.EstadoEjecucion012){
      0 { Write-Host "[0] $etapa $($r.Dato.EstadoFuncional)" -ForegroundColor Green }
      1 {
        Write-Host "[1] $etapa $($r.Dato.EstadoFuncional)" -ForegroundColor Yellow
        if($etapa -eq 'InventariarBoletas'){
          $hayPendiente=$true
        } else {
          return @{EstadoEjecucion012=1;Dato=$r.Dato}
        }
      }
      2 {
        Write-Host "[2] $etapa $($r.Dato.EstadoFuncional)" -ForegroundColor Red
        if($etapa -eq 'InventariarBoletas'){
          $hayPendiente=$true
        } else {
          return @{EstadoEjecucion012=2;Dato=$r.Dato}
        }
      }
      default {
        return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='EstadoNoReconocido';Diagnostico=$etapa}}
      }
    }
  }
  $Reporte.Modulos.Recetas=@{EstadoEjecucion012=1;EstadoFuncional='OrigenNoIdentificado'}
  if($hayPendiente){
    return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='RepositorioCreadoConFuentesPendientes'}}
  }
  return @{EstadoEjecucion012=1;Dato=@{EstadoFuncional='FaltaFuenteRecetas'}}
}
function GuardarReporte {
  try {
    New-Item -ItemType Directory -Path (Split-Path $ReporteArchivo -Parent) -Force | Out-Null
    $json=$Reporte | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $ReporteArchivo -Value $json -Encoding UTF8
    try { Set-Clipboard -Value $json -ErrorAction Stop } catch {}
    return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='ReporteGuardado'}}
  } catch {
    return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='FalloReporte';Diagnostico=$_.Exception.Message}}
  }
}
# ENTRADA AUTOMATICA: primer juicio ternario obligatorio 0,1,2.
$inicio=ComprobarEntorno
$Reporte.Etapas+=@{Nombre='ComprobarEntorno';EstadoEjecucion012=$inicio.EstadoEjecucion012;EstadoFuncional=$inicio.Dato.EstadoFuncional}
switch([int]$inicio.EstadoEjecucion012){
  0 {
    $trabajo=Secuencia
    switch([int]$trabajo.EstadoEjecucion012){
      0 {
        $Reporte.EstadoEjecucion012=0
        $Reporte.EstadoFuncional=$trabajo.Dato.EstadoFuncional
      }
      1 {
        $Reporte.EstadoEjecucion012=1
        $Reporte.EstadoFuncional=$trabajo.Dato.EstadoFuncional
        $Reporte.Diagnostico=$trabajo.Dato.Diagnostico
      }
      2 {
        $Reporte.EstadoEjecucion012=2
        $Reporte.EstadoFuncional=$trabajo.Dato.EstadoFuncional
        $Reporte.Diagnostico=$trabajo.Dato.Diagnostico
      }
      default {
        $Reporte.EstadoEjecucion012=2
        $Reporte.EstadoFuncional='EstadoNoReconocido'
      }
    }
  }
  1 {
    $Reporte.EstadoEjecucion012=1
    $Reporte.EstadoFuncional=$inicio.Dato.EstadoFuncional
    $Reporte.Diagnostico=$inicio.Dato.Diagnostico
  }
  2 {
    $Reporte.EstadoEjecucion012=2
    $Reporte.EstadoFuncional=$inicio.Dato.EstadoFuncional
    $Reporte.Diagnostico=$inicio.Dato.Diagnostico
  }
  default {
    $Reporte.EstadoEjecucion012=2
    $Reporte.EstadoFuncional='EstadoNoReconocido'
  }
}
$Reporte.ProximaAccion='Pegar reporte en ChatGPT para terminar la importacion de boletas y recetas.'
$guardado=GuardarReporte
switch([int]$guardado.EstadoEjecucion012){
  0 { Write-Host '[0] Reporte guardado y copiado al portapapeles.' -ForegroundColor Cyan }
  1 { Write-Host '[1] Guardado incierto.' -ForegroundColor Yellow }
  2 { Write-Host '[2] No se pudo guardar el reporte.' -ForegroundColor Red; Write-Output ($Reporte | ConvertTo-Json -Depth 10) }
  default { Write-Host '[2] Estado de guardado invalido.' -ForegroundColor Red }
}
Write-Host "ESTADO 012: $($Reporte.EstadoEjecucion012) $($Reporte.EstadoFuncional)"
Write-Host 'REPO: https://github.com/joansamo20/medicina-pe3'
Write-Host "REPORTE: $ReporteArchivo"
