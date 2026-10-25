@echo off
title Lu7ech - Anti-Infostealer
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Pidiendo permisos de administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -Raw -LiteralPath '%~f0') -split '(?m)^::PSSTART::\s*$')[1]"
echo.
pause
exit /b
::PSSTART::
$ErrorActionPreference = 'SilentlyContinue'
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$report = Join-Path ([Environment]::GetFolderPath('Desktop')) "Reporte_Infostealer_$ts.txt"
$quar = 'C:\Cuarentena_Lu7ech'
New-Item -ItemType Directory -Force -Path $quar | Out-Null
$findings = New-Object System.Collections.ArrayList
$quarantined = New-Object System.Collections.ArrayList

function Log($t) { Write-Host $t; Add-Content -Path $report -Value $t }
# Nivel: ALTO = malware claro (se cuarentena). BAJO = dudoso (solo se reporta, no se toca)
function Add-Finding($level, $type, $desc, $path, $extra, $why) {
    foreach ($f in $findings) { if ($f.Type -eq $type -and $f.Path -eq $path -and $f.Desc -eq $desc) { return } }
    [void]$findings.Add([pscustomobject]@{ Level = $level; Type = $type; Desc = $desc; Path = $path; Extra = $extra; Why = $why })
}
$susDirs = '\\AppData\\', '\\Temp\\', '\\ProgramData\\', '\\Users\\Public\\', '\\Downloads\\'
function IsSusPath($p) { if (-not $p) { return $false }; foreach ($d in $susDirs) { if ($p -match $d) { return $true } }; return $false }
function Get-ExePath($cmd) {
    $cmd = [Environment]::ExpandEnvironmentVariables([string]$cmd)
    if ($cmd -match '^\s*"([^"]+)"') { return $Matches[1] }
    elseif ($cmd -match '^\s*(\S+\.(exe|bat|cmd|ps1|vbs|js|scr|com))') { return $Matches[1] }
    else { return $null }
}
function IsSigned($f) { if (-not $f -or -not (Test-Path -LiteralPath $f)) { return $false }; return ((Get-AuthenticodeSignature -LiteralPath $f).Status -eq 'Valid') }
function IsRandomName($n) { return ($n -match '^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]{8,20}\.(exe|scr|dll)$') }
function IsKnownName($n) { return ($n -match '(?i)HR4kwl763VPZ') }
$evilCmd = '(?i)-enc\b|-encodedcommand|downloadstring|frombase64string|invoke-expression|iex\s|-w(indowstyle)?\s+hidden|bitsadmin.*transfer|certutil.*-urlcache'

function Quarantine-File($path, $why) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    Get-Process | Where-Object { $_.Path -eq $path } | Stop-Process -Force
    Start-Sleep -Milliseconds 400
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $dest = Join-Path $quar ("$ts" + '_' + (Split-Path $path -Leaf) + '.quar')
    Move-Item -LiteralPath $path -Destination $dest -Force
    if (Test-Path -LiteralPath $path) {
        Log "   !! NO se pudo mover (en uso). Reinicia la PC y volve a correr el script: $path"
    } else {
        [void]$quarantined.Add($dest)
        Log "   -> EN CUARENTENA: $path"
        Log "      guardado como: $dest  (SHA256: $hash)"
        Log "      motivo: $why"
    }
}

Log "=== ANTI-INFOSTEALER Lu7ech - $(Get-Date) ==="
Log "Equipo: $env:COMPUTERNAME  Usuario: $env:USERNAME"
Log ''

# ---------- 1. DEFENDER ----------
Log '[1/5] Windows Defender'
Update-MpSignature
$r = Read-Host 'Escaneo COMPLETO de Defender (tarda de 20 min a horas). S = completo, otra tecla = rapido'
if ($r -match '^[sS]') { Log ' Escaneo completo...'; Start-MpScan -ScanType FullScan } else { Log ' Escaneo rapido...'; Start-MpScan -ScanType QuickScan }
$defDetect = @()
foreach ($d in (Get-MpThreatDetection)) {
    $nm = (Get-MpThreat -ThreatID $d.ThreatID).ThreatName
    foreach ($res in $d.Resources) {
        $defDetect += $res
        Log " DEFENDER DETECTO: $nm -> $res"
        $ex = ($res -replace '^(file|containerfile|folder):_?', '')
        Add-Finding 'ALTO' 'Defender' $nm $ex $null "Detectado por Windows Defender como $nm"
    }
}
if (-not $defDetect) { Log ' Defender: sin detecciones' }
Log ''

# ---------- 2. PERSISTENCIA ----------
Log '[2/5] Persistencia (arranque automatico)'
$runKeys = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
           'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
           'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
foreach ($k in $runKeys) {
    $p = Get-ItemProperty -Path $k
    if (-not $p) { continue }
    foreach ($prop in ($p.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' })) {
        $val = [string]$prop.Value
        $exe = Get-ExePath $val
        $leaf = if ($exe) { Split-Path $exe -Leaf } else { '' }
        $signed = IsSigned $exe
        Log " Run: $($prop.Name) = $val  (firmado: $signed)"
        if ((IsKnownName $leaf) -or ($val -match $evilCmd) -or ((IsRandomName $leaf) -and (IsSusPath $exe) -and -not $signed)) {
            Add-Finding 'ALTO' 'RunKey' $prop.Name $val $k 'Arranque automatico con nombre aleatorio/conocido o comando ofuscado'
        } elseif ((IsSusPath $exe) -and -not $signed) {
            Add-Finding 'BAJO' 'RunKey' $prop.Name $val $k 'Arranque automatico sin firma en carpeta de usuario'
        }
    }
}
foreach ($d in ("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp")) {
    Get-ChildItem -LiteralPath $d -Force -File | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
        Log " Startup: $($_.FullName)"
        if ((IsKnownName $_.Name) -or ((IsRandomName $_.Name) -and -not (IsSigned $_.FullName))) {
            Add-Finding 'ALTO' 'File' $_.Name $_.FullName 'Startup' 'Archivo en carpeta de inicio con nombre aleatorio/conocido'
        } elseif ($_.Extension -match '^\.(exe|bat|cmd|ps1|vbs|js|scr)$') {
            Add-Finding 'BAJO' 'File' $_.Name $_.FullName 'Startup' 'Ejecutable/script en carpeta de inicio'
        }
    }
}
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | ForEach-Object {
    $t = $_
    foreach ($a in $t.Actions) {
        $exe = [Environment]::ExpandEnvironmentVariables([string]$a.Execute)
        $ar = [string]$a.Arguments
        $leaf = Split-Path $exe -Leaf
        Log " Tarea: $($t.TaskPath)$($t.TaskName) -> $exe $ar"
        if ((IsKnownName $leaf) -or ("$exe $ar" -match $evilCmd) -or ((IsRandomName $leaf) -and (IsSusPath $exe) -and -not (IsSigned $exe))) {
            Add-Finding 'ALTO' 'Task' $t.TaskName "$exe $ar" $t.TaskPath 'Tarea programada con nombre aleatorio/conocido o comando ofuscado'
        } elseif ((IsSusPath $exe) -and -not (IsSigned $exe)) {
            Add-Finding 'BAJO' 'Task' $t.TaskName "$exe $ar" $t.TaskPath 'Tarea programada que ejecuta algo sin firma desde carpeta de usuario'
        }
    }
}
Get-CimInstance Win32_Service | ForEach-Object {
    $e = Get-ExePath $_.PathName
    if ($e -and (IsSusPath $e) -and -not (IsSigned $e)) {
        $leaf = Split-Path $e -Leaf
        if ((IsKnownName $leaf) -or (IsRandomName $leaf)) { Add-Finding 'ALTO' 'Service' $_.Name $e $_.Name 'Servicio con nombre aleatorio/conocido' }
        else { Add-Finding 'BAJO' 'Service' $_.Name $e $_.Name 'Servicio sin firma en carpeta de usuario' }
    }
}
foreach ($w in (Get-WmiObject -Namespace root\subscription -Class __EventConsumer)) {
    Add-Finding 'BAJO' 'Info' "WMI: $($w.Name)" $w.__CLASS $null 'Suscripcion WMI (revisar a mano)'
}
Log ''

# ---------- 3. PROCESOS ----------
Log '[3/5] Procesos desde carpetas de usuario sin firma'
Get-Process | ForEach-Object {
    $pp = $_.Path
    if ($pp -and (IsSusPath $pp) -and -not (IsSigned $pp)) {
        $leaf = Split-Path $pp -Leaf
        $con = @(Get-NetTCPConnection -OwningProcess $_.Id -State Established)
        Log " Proceso: $($_.ProcessName) PID $($_.Id) -> $pp  (conexiones: $($con.Count))"
        foreach ($c in $con) { Log "    conectado a $($c.RemoteAddress):$($c.RemotePort)" }
        if ((IsKnownName $leaf) -or (IsRandomName $leaf)) {
            Add-Finding 'ALTO' 'Process' "$($_.ProcessName) PID $($_.Id)" $pp $_.Id 'Proceso sin firma con nombre aleatorio/conocido en carpeta de usuario'
        } else {
            Add-Finding 'BAJO' 'Process' "$($_.ProcessName) PID $($_.Id)" $pp $_.Id 'Proceso sin firma en carpeta de usuario'
        }
    }
}
Log ''

# ---------- 4. ARCHIVOS ----------
Log '[4/5] Buscando archivos (ultimos 90 dias)'
$roots = $env:APPDATA, $env:LOCALAPPDATA, $env:TEMP, $env:ProgramData, 'C:\Users\Public', "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents"
$since = (Get-Date).AddDays(-90)
$skip = 'node_modules|\\pip\\|\\npm|\\Microsoft\\WindowsApps|\\Google\\Chrome|\\Microsoft\\Edge|\\Cuarentena_Lu7ech|\\Windows Defender|\\Packages\\'
$seen = @{}
foreach ($root in ($roots | Select-Object -Unique)) {
    if (-not (Test-Path $root)) { continue }
    Log " Revisando $root ..."
    Get-ChildItem -LiteralPath $root -Recurse -Force -File -Include *.exe, *.scr, *.dll, *.bat, *.cmd, *.ps1, *.vbs, *.js -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $since -and $_.FullName -notmatch $skip } | ForEach-Object {
        if ($seen.ContainsKey($_.FullName)) { return }
        $seen[$_.FullName] = $true
        $bin = $_.Extension -match '^\.(exe|scr|dll)$'
        if (IsKnownName $_.Name) {
            Add-Finding 'ALTO' 'File' $_.Name $_.FullName 'Archivo' 'Nombre conocido del hackeo anterior'
        } elseif ($bin -and (IsRandomName $_.Name) -and -not (IsSigned $_.FullName)) {
            Add-Finding 'ALTO' 'File' $_.Name $_.FullName 'Archivo' 'Ejecutable sin firma con nombre aleatorio'
        } elseif ($_.FullName -match '\\Temp\\|\\Users\\Public\\') {
            if ($bin -and -not (IsSigned $_.FullName)) { Add-Finding 'BAJO' 'File' $_.Name $_.FullName 'Archivo' 'Ejecutable sin firma en Temp/Public' }
            elseif (-not $bin) { Add-Finding 'BAJO' 'File' $_.Name $_.FullName 'Archivo' 'Script en Temp/Public' }
        }
    }
}
Log ''

# ---------- 5. CUARENTENA ----------
$alto = @($findings | Where-Object { $_.Level -eq 'ALTO' })
$bajo = @($findings | Where-Object { $_.Level -eq 'BAJO' })
Log "[5/5] Malware claro: $($alto.Count)   |   Dudosos (solo reporte): $($bajo.Count)"
if ($alto.Count -gt 0) {
    Log ''
    Log '--- MALWARE ENCONTRADO: cuarentena automatica ---'
    foreach ($f in ($alto | Sort-Object { switch ($_.Type) { 'Process' {0} 'RunKey' {1} 'Task' {1} 'Service' {1} default {2} } })) {
        Log ''
        Log "[ALTO] $($f.Type): $($f.Desc)"
        Log "   Ubicacion: $($f.Path)"
        Log "   Por que: $($f.Why)"
        switch ($f.Type) {
            'Process' { Stop-Process -Id $f.Extra -Force; Log "   -> Proceso terminado (PID $($f.Extra))"; Quarantine-File $f.Path $f.Why }
            'RunKey' {
                Remove-ItemProperty -Path $f.Extra -Name $f.Desc
                Log "   -> Entrada de arranque eliminada de $($f.Extra)  (valor original: $($f.Path))"
                $ex = Get-ExePath $f.Path
                if ($ex) { Quarantine-File $ex $f.Why }
            }
            'Task' {
                Unregister-ScheduledTask -TaskName $f.Desc -TaskPath $f.Extra -Confirm:$false
                Log "   -> Tarea programada eliminada: $($f.Desc)"
                $ex = Get-ExePath $f.Path
                if ($ex) { Quarantine-File $ex $f.Why }
            }
            'Service' {
                Stop-Service -Name $f.Extra -Force; Set-Service -Name $f.Extra -StartupType Disabled
                Log "   -> Servicio detenido y deshabilitado: $($f.Extra)"
                Quarantine-File $f.Path $f.Why
            }
            default { Quarantine-File $f.Path $f.Why }
        }
    }
}
if ($bajo.Count -gt 0) {
    Log ''
    Log '--- DUDOSOS (NO se toco nada, revisalos vos) ---'
    foreach ($f in $bajo) { Log "[BAJO] $($f.Type): $($f.Desc) | $($f.Path) | $($f.Why)" }
}

# ---------- VEREDICTO ----------
Log ''
Log '=============================================='
if ($alto.Count -gt 0) {
    Log " VEREDICTO: INFECTADO - $($alto.Count) elemento(s) de malware encontrados"
    Log ' Donde estaba alojado:'
    foreach ($f in $alto) { Log "   - [$($f.Type)] $($f.Path)" }
    Log " Todo lo detectado quedo en cuarentena: $quar"
} elseif ($bajo.Count -gt 0) {
    Log ' VEREDICTO: SIN MALWARE CLARO, pero hay elementos dudosos para revisar (ver lista arriba)'
} else {
    Log ' VEREDICTO: LIMPIO - no se encontro ningun infostealer ni persistencia sospechosa'
}
Log '=============================================='

# ---------- BORRADO DEFINITIVO (solo lo que quedo en cuarentena) ----------
if ($quarantined.Count -gt 0) {
    Log ''
    Log "Archivos en cuarentena en esta corrida: $($quarantined.Count)"
    $q = Read-Host 'Borrar DEFINITIVAMENTE estos archivos de cuarentena? (S/N)'
    if ($q -match '^[sS]') {
        foreach ($qf in $quarantined) { Remove-Item -LiteralPath $qf -Force; Log " Borrado definitivo: $qf" }
    } else { Log ' Quedan en cuarentena (inofensivos, renombrados .quar). Borralos vos cuando quieras.' }
}

Log ''
Log "Reporte completo en el Escritorio: $report"
Log ''
Log 'IMPORTANTE: aunque la PC quede limpia, desde OTRO dispositivo limpio:'
Log ' - cerra sesiones activas (Google, Discord, Instagram, Facebook, Telegram, WhatsApp Web)'
Log ' - cambia contrasenas y activa 2FA'
Log ' - pasa Malwarebytes como segunda opinion'
