$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter create --empty --platforms=android,ios,web --project-name=nextrole --org=com.saadi .
if ($LASTEXITCODE -ne 0) { throw 'Platform generation failed.' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
dart run scripts/configure_platforms.dart
if ($LASTEXITCODE -ne 0) { throw 'Platform configuration failed.' }
dart format lib test scripts
if ($LASTEXITCODE -ne 0) { throw 'Formatting failed.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
