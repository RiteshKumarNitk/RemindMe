# Local-only helper: regenerate the Prisma client WITHOUT touching the
# query_engine DLL that is locked by a running `next dev` (Windows EPERM on
# rename). Generates into .prisma-gen/out, then copies everything except the
# engine binary into the real .prisma/client folder.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

$pnpmDir = Get-ChildItem -LiteralPath "node_modules\.pnpm" -Directory |
  Where-Object { $_.Name -like "@prisma+client@*" } |
  Select-Object -First 1
if (-not $pnpmDir) { throw "could not locate @prisma/client in node_modules/.pnpm" }
$real = Join-Path $pnpmDir.FullName "node_modules\.prisma\client"
if (-not (Test-Path -LiteralPath $real)) { throw "could not locate .prisma/client" }

(Get-Content prisma\schema.prisma -Raw) -replace 'generator client \{\s*\r?\n\s*provider = "prisma-client-js"\s*\r?\n\}', "generator client {`n  provider = `"prisma-client-js`"`n  output   = `"../.prisma-gen/out`"`n}" |
  Set-Content .prisma-gen\schema.prisma -NoNewline

node node_modules/prisma/build/index.js generate --schema .prisma-gen\schema.prisma | Out-Null

Get-ChildItem -LiteralPath ".prisma-gen\out" | Where-Object {
  $_.Name -notlike "query_engine-windows.dll.node*"
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $real -Recurse -Force }

# stale engine temp copies left behind by earlier locked generations
Get-ChildItem -LiteralPath $real -Filter "query_engine-windows.dll.node.tmp*" -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue

Write-Output "prisma client synced to $real"
