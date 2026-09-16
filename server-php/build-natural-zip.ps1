<#
.SYNOPSIS
    Construit le zip de deploiement Laravel "propre" : structure de projet
    naturelle (public/ reste un sous-dossier), pour un sous-domaine dont le
    document root pointe directement vers public/. Pas de reecriture
    d'index.php, pas de .htaccess "deny" necessaires : app/, vendor/,
    bootstrap/, etc. ne sont simplement jamais dans le webroot.
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("laravel_natural_" + [System.Guid]::NewGuid().ToString('N'))
$out = Join-Path $root 'laravel-natural.zip'

New-Item -ItemType Directory -Path $staging | Out-Null

try {
    $includeTop = @('app', 'bootstrap', 'config', 'database', 'public', 'resources', 'routes', 'storage', 'vendor', 'artisan', 'composer.json', 'composer.lock')
    foreach ($item in $includeTop) {
        $src = Join-Path $root $item
        if (-not (Test-Path $src)) { continue }
        $dest = Join-Path $staging $item
        if ((Get-Item $src).PSIsContainer) {
            Copy-Item $src $dest -Recurse
        } else {
            Copy-Item $src $dest
        }
    }

    # .env.production (DB_HOST=localhost, APP_DEBUG=false) et non le .env de
    # dev local : voir la note dans .env pour pourquoi le nom d'hote externe
    # echoue depuis le serveur lui-meme.
    Copy-Item (Join-Path $root '.env.production') (Join-Path $staging '.env')

    Get-ChildItem (Join-Path $staging 'bootstrap/cache') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '.gitignore' } | Remove-Item -Force
    Get-ChildItem (Join-Path $staging 'storage/logs') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '.gitignore' } | Remove-Item -Force

    if (Test-Path $out) { Remove-Item $out -Force }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($out, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -Path $staging -Recurse -File
        foreach ($f in $files) {
            $relative = $f.FullName.Substring($staging.Length + 1) -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $f.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $zip.Dispose()
    }

    $count = (Get-ChildItem -Path $staging -Recurse -File).Count
    Write-Host "OK : $out ($count fichiers)"
}
finally {
    Remove-Item -Path $staging -Recurse -Force -ErrorAction SilentlyContinue
}
