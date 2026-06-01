@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\switch_vendor.ps1"
pause
