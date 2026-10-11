param([Parameter(Mandatory=$true)][string]$SourceProject)
$ErrorActionPreference = 'Stop'
$target = Split-Path $PSScriptRoot -Parent
$source = (Resolve-Path -LiteralPath $SourceProject).Path
if ($source -eq $target) { throw 'Choose the old project folder as SourceProject, not this new folder.' }
$options = Join-Path $source 'lib\firebase_options.dart'
$androidConfig = Join-Path $source 'android\app\google-services.json'
if (!(Test-Path -LiteralPath $options) -or !(Test-Path -LiteralPath $androidConfig)) { throw 'The old folder must contain configured firebase_options.dart and google-services.json.' }
if (!(Test-Path -LiteralPath (Join-Path $target 'android\app'))) { throw 'Run scripts/bootstrap.ps1 in this new folder first.' }
$config = Get-Content -LiteralPath $androidConfig -Raw | ConvertFrom-Json
$optionsText = Get-Content -LiteralPath $options -Raw
if ($optionsText -notmatch [regex]::Escape($config.project_info.project_id)) { throw 'Old Android config and Dart options refer to different projects. Use flutterfire configure instead.' }
$clients = @($config.client | Where-Object { $_.client_info.android_client_info.package_name -eq 'com.saadi.nextrole' })
if ($clients.Count -eq 0) { throw 'Firebase Android package must be com.saadi.nextrole.' }
Copy-Item -LiteralPath $options -Destination (Join-Path $target 'lib\firebase_options.dart') -Force
Copy-Item -LiteralPath $androidConfig -Destination (Join-Path $target 'android\app\google-services.json') -Force
Write-Host "Copied client configuration for $($config.project_info.project_id)."
Write-Host 'Run flutterfire configure for this same project to finish native Gradle integration in the newly generated Android folder.'
