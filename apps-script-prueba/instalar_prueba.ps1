# Apps Script PE3 - comprobacion y despliegue local.
# Codigo fuente: joansamo20/proyecto_prueba_cli, rama experimento/apps-script-pe3.
# No pide contrasenas en la consola. OAuth se hace con Google.
# No sube reportes ni credenciales a GitHub.

$ErrorActionPreference = 'Continue'
$Script:Root = Join-Path $env:USERPROFILE 'Documents\PE3\AppsScriptPrueba'
$Script:Base = 'https://raw.githubusercontent.com/joansamo20/proyecto_prueba_cli/deefe3a4c675a97fa1e012a3dfb42b1c2dc12f2c/apps-script-prueba'
$Script:Clasp = $null
$Script:Reporte = @{
  Fecha = (Get-Date).ToString('o')
  EstadoEjecucion012 = 1
  EstadoFuncional = 'SinEjecutar'
  Etapas = @()
  EnlaceWeb = $null
  AccionSiguiente = ''
  CarpetaRelativa = 'Documents\PE3\AppsScriptPrueba'
  Diagnostico = ''
}

function Comprobar-Node {
  try {
    $n = Get-Command node.exe -ErrorAction SilentlyContinue
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if ($null -eq $n -or $null -eq $npm) {
      return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='FaltaNode';Diagnostico='Necesita Node.js LTS (20 o posterior). https://nodejs.org/en/download'}}
    }
    $version = (& $n.Source --version 2>&1 | Out-String).Trim()
    $match = [regex]::Match($version,'v(\d+)\.')
    if (-not $match.Success) {
      return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='VersionNoDeterminado';Diagnostico='No se pudo identificar la version de Node: '+$version}}
    }
    if ([int]$match.Groups[1].Value -lt 20) {
      return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='NodeAntiguo';Diagnostico='Instala Node.js 20 o posterior. Detectado: '+$version}}
    }
    return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='NodeDisponible';Version=$version}}
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorComprobacion';Diagnostico=$_.Exception.Message}}
  }
}

function Preparar-Clasp {
  try {
    $clasp = Get-Command clasp.cmd -ErrorAction SilentlyContinue
    if ($null -eq $clasp) {
      Write-Host 'Instalando clasp (herramienta de Google)...' -ForegroundColor Cyan
      $salida = (& npm.cmd install --global '@google/clasp' 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='InstalacionFallida';Diagnostico=($salida | Select-Object -Last 1)}}
      }
      $env:PATH += ';' + (Join-Path $env:APPDATA 'npm')
      $clasp = Get-Command clasp.cmd -ErrorAction SilentlyContinue
    }
    if ($null -eq $clasp) {
      return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='ClaspNoDetectado';Diagnostico='npm completo la instalacion, pero clasp no aparece en PATH.'}}
    }
    $Script:Clasp = $clasp.Source
    return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='ClaspDisponible'}}
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorClasp';Diagnostico=$_.Exception.Message}}
  }
}

function Autorizar-Google {
  try {
    $salida = (& $Script:Clasp show-authorized-user 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0) {
      return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='SesionYaAutorizada'}}
    }
    Write-Host 'Se abrira Google para autorizar clasp. Autoriza solo si reconoces la cuenta.' -ForegroundColor Yellow
    & $Script:Clasp login
    if ($LASTEXITCODE -eq 0) {
      return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='SesionAutorizada'}}
    }
    return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='AutorizacionPendiente';Diagnostico='Completa el inicio de sesion de Google y ejecuta el mismo comando de nuevo.'}}
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorAutorizacion';Diagnostico=$_.Exception.Message}}
  }
}

function Crear-Proyecto {
  try {
    New-Item -ItemType Directory -Path $Script:Root -Force -ErrorAction Stop | Out-Null
    Push-Location $Script:Root
    try {
      $claspFile = Join-Path $Script:Root '.clasp.json'
      if (Test-Path $claspFile) {
        $datos = Get-Content $claspFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($datos.scriptId)) {
          return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='ProyectoNoIdentificable';Diagnostico='El archivo .clasp.json no contiene scriptId.'}}
        }
        return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='ProyectoExistente';IdScript=$datos.scriptId}}
      }
      Write-Host 'Creando proyecto real de Google Apps Script...' -ForegroundColor Cyan
      $salida = (& $Script:Clasp create-script --title 'PE3 Agenda - interfaz prueba' --type webapp 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        if ($salida -match 'API|api|disabled|enabled') {
          try { Start-Process 'https://script.google.com/home/usersettings' } catch {}
          return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='ApiPorHabilitar';Diagnostico='Revisa la configuracion de Apps Script y activa Google Apps Script API. Luego repite el mismo comando.'}}
        }
        return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='CreacionFallida';Diagnostico=$salida.Trim()}}
      }
      if (-not (Test-Path $claspFile)) {
        return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='CreacionSinId';Diagnostico='clasp dijo que creo el proyecto, pero no genero .clasp.json.'}}
      }
      $datos = Get-Content $claspFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='ProyectoCreado';IdScript=$datos.scriptId}}
    } finally {
      Pop-Location
    }
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorCrearProyecto';Diagnostico=$_.Exception.Message}}
  }
}

function Obtener-Fuentes {
  try {
    foreach ($nombre in @('Code.gs','Index.html','appsscript.json')) {
      $url = "$Script:Base/$nombre"
      $destino = Join-Path $Script:Root $nombre
      Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $destino -ErrorAction Stop
      if (-not (Test-Path $destino) -or (Get-Item $destino).Length -eq 0) {
        return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='FuenteNoDisponible';Diagnostico='Archivo faltante: '+$nombre}}
      }
    }
    return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='FuentesDescargadas';Archivos=@('Code.gs','Index.html','appsscript.json')}}
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorDescarga';Diagnostico=$_.Exception.Message}}
  }
}

function Subir-Codigo {
  try {
    Push-Location $Script:Root
    try {
      Write-Host 'Subiendo interfaz a Google Apps Script...' -ForegroundColor Cyan
      $salida = (& $Script:Clasp push --force 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) {
        if ($salida -match 'API|api|disabled|enabled|Unauthorized') {
          try { Start-Process 'https://script.google.com/home/usersettings' } catch {}
          return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='PermisoPendiente';Diagnostico='Revisa Apps Script API o la autorizacion OAuth; repite el comando.'}}
        }
        return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='SubidaFallida';Diagnostico=$salida.Trim()}}
      }
      return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='CodigoSubido'}}
    } finally {
      Pop-Location
    }
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorSubida';Diagnostico=$_.Exception.Message}}
  }
}

function Desplegar-Web {
  try {
    Push-Location $Script:Root
    try {
      $archivo = Join-Path $Script:Root 'despliegue_pe3.json'
      $idAnterior = $null
      if (Test-Path $archivo) {
        $registrado = Get-Content $archivo -Raw | ConvertFrom-Json
        $idAnterior = [string]$registrado.DeploymentId
      }
      Write-Host 'Creando o actualizando implementacion web...' -ForegroundColor Cyan
      if ([string]::IsNullOrWhiteSpace($idAnterior)) {
        $salida = (& $Script:Clasp create-deployment --description 'PE3 prueba tecnica, sin pacientes' 2>&1 | Out-String)
      } else {
        $salida = (& $Script:Clasp create-deployment --deploymentId $idAnterior --description 'PE3 prueba tecnica, sin pacientes' 2>&1 | Out-String)
      }
      if ($LASTEXITCODE -ne 0) {
        return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='DespliegueFallido';Diagnostico=$salida.Trim()}}
      }
      $id = [regex]::Match($salida,'AKfy[A-Za-z0-9_\-]+').Value
      if (-not $id -and $idAnterior) { $id = $idAnterior }
      if (-not $id) {
        $detalle = (& $Script:Clasp list-deployments 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0) {
          $id = [regex]::Match($detalle,'AKfy[A-Za-z0-9_\-]+').Value
        }
      }
      if (-not $id) {
        return @{EstadoEjecucion012=1; Dato=@{EstadoFuncional='IdDespliegueIndeterminado';Diagnostico='clasp desplego, pero no se pudo extraer la URL. Revisa list-deployments en la carpeta del proyecto.'}}
      }
      $url = "https://script.google.com/macros/s/$id/exec"
      @{DeploymentId=$id;EnlaceWeb=$url} | ConvertTo-Json | Set-Content $archivo -Encoding UTF8
      $Script:Reporte.EnlaceWeb = $url
      try {
        $firefox = Get-Command firefox.exe -ErrorAction SilentlyContinue
        if ($null -ne $firefox) {
          Start-Process -FilePath $firefox.Source -ArgumentList $url -ErrorAction Stop
        } elseif (Test-Path 'C:\Program Files\Mozilla Firefox\firefox.exe') {
          Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe' -ArgumentList $url -ErrorAction Stop
        } else {
          Start-Process $url -ErrorAction Stop
        }
      } catch { }
      return @{EstadoEjecucion012=0; Dato=@{EstadoFuncional='DesplegadoSinPruebaDeNavegador';EnlaceWeb=$url;Diagnostico='Abre la URL en Firefox y presiona Comprobar conexion para verificar el backend.'}}
    } finally {
      Pop-Location
    }
  } catch {
    return @{EstadoEjecucion012=2; Dato=@{EstadoFuncional='ErrorDespliegue';Diagnostico=$_.Exception.Message}}
  }
}

function Ejecutar-Flujo {
  foreach ($etapa in @('Preparar-Clasp','Autorizar-Google','Crear-Proyecto','Obtener-Fuentes','Subir-Codigo','Desplegar-Web')) {
    $resultado = & $etapa
    $Script:Reporte.Etapas += @{
      Nombre = $etapa
      EstadoEjecucion012 = $resultado.EstadoEjecucion012
      EstadoFuncional = $resultado.Dato.EstadoFuncional
      Diagnostico = $resultado.Dato.Diagnostico
    }
    switch ([int]$resultado.EstadoEjecucion012) {
      0 {
        Write-Host "[0] $etapa" -ForegroundColor Green
      }
      1 {
        Write-Host "[1] $etapa - pendiente o incierto" -ForegroundColor Yellow
        return @{EstadoEjecucion012=1;Dato=$resultado.Dato}
      }
      2 {
        Write-Host "[2] $etapa - fallo" -ForegroundColor Red
        return @{EstadoEjecucion012=2;Dato=$resultado.Dato}
      }
      default {
        return @{EstadoEjecucion012=2;Dato=@{EstadoFuncional='EstadoNoReconocido';Diagnostico=$etapa}}
      }
    }
  }
  return @{EstadoEjecucion012=0;Dato=@{EstadoFuncional='DespliegueReportado';EnlaceWeb=$Script:Reporte.EnlaceWeb}}
}

# ENTRADA AUTOMATICA PE3: primera decision 0/1/2 ocurre aqui.
$inicio = Comprobar-Node
$Script:Reporte.Etapas += @{
  Nombre='Comprobar-Node'
  EstadoEjecucion012=$inicio.EstadoEjecucion012
  EstadoFuncional=$inicio.Dato.EstadoFuncional
  Diagnostico=$inicio.Dato.Diagnostico
}
switch ([int]$inicio.EstadoEjecucion012) {
  0 {
    Write-Host '[0] Node disponible' -ForegroundColor Green
    $flujo = Ejecutar-Flujo
    switch ([int]$flujo.EstadoEjecucion012) {
      0 {
        $Script:Reporte.EstadoEjecucion012 = 0
        $Script:Reporte.EstadoFuncional = $flujo.Dato.EstadoFuncional
        $Script:Reporte.AccionSiguiente = 'Probar boton en Firefox y pegar el reporte aqui.'
      }
      1 {
        $Script:Reporte.EstadoEjecucion012 = 1
        $Script:Reporte.EstadoFuncional = $flujo.Dato.EstadoFuncional
        $Script:Reporte.Diagnostico = $flujo.Dato.Diagnostico
        $Script:Reporte.AccionSiguiente = 'Resolver permiso o requisito indicado y repetir exactamente el mismo comando.'
      }
      2 {
        $Script:Reporte.EstadoEjecucion012 = 2
        $Script:Reporte.EstadoFuncional = $flujo.Dato.EstadoFuncional
        $Script:Reporte.Diagnostico = $flujo.Dato.Diagnostico
        $Script:Reporte.AccionSiguiente = 'Pegar el reporte aqui para corregir el fallo.'
      }
      default {
        $Script:Reporte.EstadoEjecucion012 = 2
        $Script:Reporte.EstadoFuncional = 'EstadoNoReconocido'
      }
    }
  }
  1 {
    $Script:Reporte.EstadoEjecucion012 = 1
    $Script:Reporte.EstadoFuncional = $inicio.Dato.EstadoFuncional
    $Script:Reporte.Diagnostico = $inicio.Dato.Diagnostico
    $Script:Reporte.AccionSiguiente = 'Instalar Node.js LTS y repetir el mismo comando.'
    Write-Host '[1] Node ausente o incompatible' -ForegroundColor Yellow
  }
  2 {
    $Script:Reporte.EstadoEjecucion012 = 2
    $Script:Reporte.EstadoFuncional = $inicio.Dato.EstadoFuncional
    $Script:Reporte.Diagnostico = $inicio.Dato.Diagnostico
    $Script:Reporte.AccionSiguiente = 'Pegar reporte para diagnostico.'
    Write-Host '[2] Fallo al comprobar Node' -ForegroundColor Red
  }
  default {
    $Script:Reporte.EstadoEjecucion012 = 2
    $Script:Reporte.EstadoFuncional = 'EstadoNoReconocido'
  }
}

try {
  New-Item -ItemType Directory -Path $Script:Root -Force -ErrorAction Stop | Out-Null
  $reportePath = Join-Path $Script:Root 'reporte_prueba_012.json'
  $texto = $Script:Reporte | ConvertTo-Json -Depth 10
  Set-Content -Path $reportePath -Value $texto -Encoding UTF8 -ErrorAction Stop
  try { Set-Clipboard -Value $texto -ErrorAction Stop; Write-Host 'Reporte copiado al portapapeles.' -ForegroundColor Cyan } catch {}
  Write-Host ""
  Write-Host "ESTADO 012: $($Script:Reporte.EstadoEjecucion012) | $($Script:Reporte.EstadoFuncional)"
  if ($Script:Reporte.EnlaceWeb) { Write-Host "ENLACE WEB: $($Script:Reporte.EnlaceWeb)" -ForegroundColor Green }
  Write-Host "REPORTE: $reportePath"
  if ($Script:Reporte.Diagnostico) { Write-Host "DIAGNOSTICO: $($Script:Reporte.Diagnostico)" }
  Write-Host $Script:Reporte.AccionSiguiente
} catch {
  Write-Host "[2] No se pudo guardar el reporte: $($_.Exception.Message)" -ForegroundColor Red
  $Script:Reporte | ConvertTo-Json -Depth 10 | Write-Output
}
