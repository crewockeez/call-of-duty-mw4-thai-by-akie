$ErrorActionPreference = 'Stop'
$env:CGO_ENABLED = '0'
$env:GOOS = 'windows'
$env:GOARCH = 'amd64'
New-Item -ItemType Directory -Force -Path dist | Out-Null
go build -trimpath -buildvcs=false -ldflags "-H=windowsgui -s -w -X main.version=source-review-v1" -o "dist/MW4_Thai_Campaign_Setup_by_akiemod_SourceReview.exe" .
Get-FileHash "dist/MW4_Thai_Campaign_Setup_by_akiemod_SourceReview.exe" -Algorithm SHA256
