@echo off
setlocal
set CGO_ENABLED=0
set GOOS=windows
set GOARCH=amd64
if not exist dist mkdir dist
go build -trimpath -buildvcs=false -ldflags "-H=windowsgui -s -w -X main.version=source-review-v1" -o "dist\MW4_Thai_Campaign_Setup_by_akiemod_SourceReview.exe" .
if errorlevel 1 exit /b 1
certutil -hashfile "dist\MW4_Thai_Campaign_Setup_by_akiemod_SourceReview.exe" SHA256
