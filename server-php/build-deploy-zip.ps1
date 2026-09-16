<#
.SYNOPSIS
    Construit un zip de deploiement Laravel pour DirectAdmin (PHP classique,
    sans Application Manager, sans acces terminal/Composer serveur).

.DESCRIPTION
    Comme DirectAdmin ne permet pas ici de choisir un document root distinct
    du dossier uploade, le contenu de public/ est remonte a la racine du zip
    (motif standard d'hebergement mutualise pour Laravel), et index.php est
    reecrit en consequence. Les dossiers sensibles (app/, config/, vendor/...)
    recoivent un .htaccess "Require all denied" pour ne pas etre accessibles
    directement en HTTP.
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("laravel_deploy_" + [System.Guid]::NewGuid().ToString('N'))
$out = Join-Path $root 'laravel-deploy.zip'

New-Item -ItemType Directory -Path $staging | Out-Null

try {
    $includeTop = @('app', 'bootstrap', 'config', 'database', 'resources', 'routes', 'storage', 'vendor', 'artisan', 'composer.json', 'composer.lock')
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

    # Contenu de public/ remonte a la racine (index.php, .htaccess, favicon...).
    Get-ChildItem (Join-Path $root 'public') | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $staging $_.Name) -Recurse
    }

    # index.php n'a plus a remonter d'un cran : vendor/ et bootstrap/ sont
    # desormais a cote de lui, pas dans un dossier parent.
    $indexPath = Join-Path $staging 'index.php'
    (Get-Content $indexPath -Raw) `
        -replace "__DIR__\.'/\.\./storage/framework/maintenance\.php'", "__DIR__.'/storage/framework/maintenance.php'" `
        -replace "__DIR__\.'/\.\./vendor/autoload\.php'", "__DIR__.'/vendor/autoload.php'" `
        -replace "__DIR__\.'/\.\./bootstrap/app\.php'", "__DIR__.'/bootstrap/app.php'" `
        | Set-Content $indexPath -NoNewline

    # Dossiers qui ne doivent jamais etre servis directement.
    $denied = @('app', 'bootstrap', 'config', 'database', 'routes', 'storage', 'vendor')
    foreach ($dir in $denied) {
        $dirPath = Join-Path $staging $dir
        if (Test-Path $dirPath) {
            "Require all denied`n" | Set-Content (Join-Path $dirPath '.htaccess') -NoNewline
        }
    }

    # Cache Laravel vide au depart : bootstrap/cache doit rester ecrivable,
    # mais son contenu genere localement n'a pas a etre uploade.
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
