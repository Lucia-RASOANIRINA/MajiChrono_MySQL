<#
.SYNOPSIS
    Reconstruit server/api_mobile.zip a partir des sources uniquement.

.DESCRIPTION
    L'archive precedente embarquait .venv/ (un virtualenv Windows compile,
    inutilisable sur l'hebergement Linux DirectAdmin), .env (secrets en clair)
    et les fichiers .db locaux -- exactement ce que DEPLOY_DIRECTADMIN.md
    interdit de publier. Ce script part d'une liste blanche de fichiers
    sources pour ne jamais reproduire ce probleme, quel que soit l'etat du
    dossier de travail au moment de l'execution.

    A relancer a chaque fois que le contenu de server/ change et qu'un
    nouvel api_mobile.zip doit etre uploade sur DirectAdmin.
#>

[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$serverRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $serverRoot 'api_mobile.zip'
}

# Dossiers et fichiers a inclure. Ni .venv/, ni .env, ni *.db, ni les caches
# de test/bytecode : voir DEPLOY_DIRECTADMIN.md "Ne publiez jamais".
$includeDirs = @('app', 'tools')
$includeFiles = @(
    'passenger_wsgi.py',
    'requirements.txt',
    'install.sh',
    '.env.example',
    '.env.mysql.example',
    'DEPLOY_DIRECTADMIN.md',
    'README.md'
)

$excludeDirNames = @('__pycache__', '.pytest_cache', '.venv', '.pip-cache')
$excludeFileExtensions = @('.pyc', '.db')

$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("api_mobile_build_" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingDir | Out-Null

try {
    foreach ($file in $includeFiles) {
        $source = Join-Path $serverRoot $file
        if (-not (Test-Path $source)) {
            Write-Warning "Fichier attendu introuvable, ignore : $file"
            continue
        }
        Copy-Item -Path $source -Destination (Join-Path $stagingDir $file)
    }

    foreach ($dir in $includeDirs) {
        $source = Join-Path $serverRoot $dir
        if (-not (Test-Path $source)) {
            Write-Warning "Dossier attendu introuvable, ignore : $dir"
            continue
        }
        $dest = Join-Path $stagingDir $dir
        Copy-Item -Path $source -Destination $dest -Recurse

        Get-ChildItem -Path $dest -Recurse -Directory |
            Where-Object { $excludeDirNames -contains $_.Name } |
            Sort-Object { $_.FullName.Length } -Descending |
            Remove-Item -Recurse -Force

        Get-ChildItem -Path $dest -Recurse -File |
            Where-Object { $excludeFileExtensions -contains $_.Extension } |
            Remove-Item -Force
    }

    if (Test-Path $OutputPath) {
        Remove-Item $OutputPath -Force
    }

    # Compress-Archive stocke parfois les chemins avec le separateur Windows
    # ("app\core\deps.py") au lieu du "/" impose par le format ZIP. Une fois
    # sur le serveur Linux, unzip cree alors un unique fichier plat nomme
    # littéralement "app\core\deps.py" au lieu du dossier app/core/, et
    # `from app.main import app` echoue. On construit donc l'archive a la
    # main avec ZipArchive pour forcer un "/" dans chaque nom d'entree.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -Path $stagingDir -Recurse -File
        foreach ($f in $files) {
            $relative = $f.FullName.Substring($stagingDir.Length + 1) -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $f.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }

    $fileCount = (Get-ChildItem -Path $stagingDir -Recurse -File).Count
    Write-Host "OK : $OutputPath ($fileCount fichiers)"
}
finally {
    Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
}
