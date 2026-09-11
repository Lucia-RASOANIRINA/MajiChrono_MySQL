$ErrorActionPreference = "Stop"

$mysql = "C:\xampp\mysql\bin\mysql.exe"
if (-not (Test-Path $mysql)) {
    throw "XAMPP MySQL est introuvable: $mysql"
}

& "C:\xampp\mysql_start.bat"
Start-Sleep -Seconds 3

& $mysql "--protocol=tcp" "-h127.0.0.1" "-P3306" "-uroot" "-e" `
    "CREATE DATABASE IF NOT EXISTS majichrono_mysql CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
if ($LASTEXITCODE -ne 0) {
    throw "Impossible de creer la base majichrono_mysql."
}

Write-Output "Base MySQL majichrono_mysql prete."
