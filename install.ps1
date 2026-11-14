# =============================================================================
#  DYGO Loader — pemasang CLIENT EDITION (hanya-baca) untuk Windows
#  Pakai:  irm https://raw.githubusercontent.com/yugoit211/dygo-loader/main/install.ps1 | iex
# =============================================================================
$ErrorActionPreference = 'Stop'
$Repo   = $env:DYGO_REPO   ; if (-not $Repo)   { $Repo   = 'yugoit211/dygo-loader' }
$Branch = $env:DYGO_BRANCH ; if (-not $Branch) { $Branch = 'main' }
$DygoDir = Join-Path $env:USERPROFILE '.dygo-client'
$BinDir  = Join-Path $env:USERPROFILE 'bin-cmd'

function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Inf($m){ Write-Host "[i]  $m" -ForegroundColor Cyan }
function Wrn($m){ Write-Host "[!]  $m" -ForegroundColor Yellow }
function Die($m){ Write-Host "[X]  $m" -ForegroundColor Red; exit 1 }

Write-Host "DYGO Loader - pemasang client (hanya-baca)`n" -ForegroundColor Cyan

# 1) PHP
$php = if ($env:PHP) { $env:PHP } else { 'php' }
try { $null = & $php -v } catch { Die "PHP tidak ditemukan. Pasang PHP 8.1+ dan taruh di PATH." }
$ver = & $php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'
$abi = & $php -r 'echo preg_replace("/\D/","",(string)ini_get("extension_dir"));'
$extDir = if ($env:DYGO_EXTDIR) { $env:DYGO_EXTDIR } else { & $php -r 'echo (string)ini_get("extension_dir");' }
$arch = if ([Environment]::Is64BitOperatingSystem) { 'x86_64' } else { 'x86' }
$plat = "windows-$arch"
Ok "PHP $ver (windows/$arch), ABI $abi, extension_dir: $extDir"

New-Item -ItemType Directory -Force -Path $DygoDir,$BinDir | Out-Null

# 2) sumber
$tmp = Join-Path $env:TEMP ("dygo-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
if ($env:DYGO_LOCAL_SRC) {
  $src = $env:DYGO_LOCAL_SRC
  Inf "Memakai sumber lokal: $src"
} else {
  Inf "Mengunduh dygo-loader ($Repo@$Branch) ..."
  $zip = Join-Path $tmp 'src.zip'
  Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/$Repo/zip/refs/heads/$Branch" -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $src = (Get-ChildItem -Path $tmp -Directory | Where-Object { $_.Name -like 'dygo-loader*' } | Select-Object -First 1).FullName
  if (-not $src) { Die "gagal mengekstrak sumber." }
}

# 3) biner loader (prebuilt DLL)
$dllName = 'php_dygo_loader.dll'
$target  = Join-Path $extDir $dllName
$prebuilt = Join-Path $src "prebuilt\$plat\$abi\$dllName"
$installed = $false
if (Test-Path $prebuilt) {
  try { Copy-Item $prebuilt $target -Force; $installed = $true; Ok "loader prebuilt terpasang: $target" }
  catch { Wrn "Gagal menyalin DLL (butuh hak admin?). Salin manual: $prebuilt -> $target" }
} else {
  Wrn "Prebuilt DLL untuk $plat/$abi tidak tersedia di paket."
  Inf "Minta vendor mengirim php_dygo_loader.dll untuk PHP $ver ($arch, ABI $abi),"
  Inf "atau pakai fallback PHP-murni (runtime\dygo-runtime.php)."
}

# 4) aktifkan di php.ini
if ($installed) {
  $ini = if ($env:DYGO_INIFILE) { $env:DYGO_INIFILE } else { & $php -r 'echo (string)php_ini_loaded_file();' }
  if ($ini -and (Test-Path $ini)) {
    $cur = Get-Content $ini -Raw
    if ($cur -notmatch '(?im)^\s*extension\s*=\s*(php_)?dygo_loader') {
      Add-Content -Path $ini -Value "`r`n; DYGO Loader`r`nextension=php_dygo_loader"
    }
    Ok "loader diaktifkan di php.ini: $ini"
  } else { Wrn "php.ini tak terdeteksi. Tambah manual: extension=php_dygo_loader" }
}

# 5) perintah dygo
Copy-Item -Recurse -Force (Join-Path $src 'bin')     (Join-Path $DygoDir 'app\bin')     -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force (Join-Path $src 'shared')  (Join-Path $DygoDir 'app\shared')  -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force (Join-Path $src 'runtime') (Join-Path $DygoDir 'app\runtime') -ErrorAction SilentlyContinue
$cmd = Join-Path $BinDir 'dygo.cmd'
"@echo off`r`n`"$php`" `"$DygoDir\app\bin\dygo`" %*" | Set-Content -Encoding ASCII $cmd
Ok "perintah 'dygo' terpasang: $cmd"
if ($env:Path -notlike "*$BinDir*") { Wrn "Tambahkan ke PATH: $BinDir" }

# 6) master key
$keyFile = Join-Path $DygoDir 'dygo.key'
Write-Host ""
if ($env:DYGO_KEY) {
  Set-Content -Path $keyFile -Value $env:DYGO_KEY -Encoding ASCII
  Ok "master key tersimpan dari env DYGO_KEY -> $keyFile"
} elseif (Test-Path $keyFile) {
  Ok "master key sudah ada: $keyFile"
} else {
  Wrn "Master key BELUM dipasang."
  Write-Host "  Minta master key (64 hex) ke vendor, lalu:"
  Write-Host "    Set-Content '$keyFile' 'KEY_HEX_DARI_VENDOR'"
}

Write-Host ""
if ((& $php -m) -match 'dygo_loader') { Ok "Terverifikasi: dygo_loader AKTIF." }
else { Inf "Jalankan: dygo doctor   (restart layanan web bila perlu)." }
Inf "Selesai. File ter-encode dari vendor kini jalan otomatis setelah key terpasang."
