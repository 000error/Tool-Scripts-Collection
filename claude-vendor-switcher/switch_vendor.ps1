$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$backupPath = "$env:USERPROFILE\.claude\settings.json.bak"

$vendors = @{
    "1" = @{
        Name = "ZhipuAI (GLM)"
        BaseUrl = "https://open.bigmodel.cn/api/anthropic"
        AuthToken = "YOUR_ZHIPU_API_KEY"
        HaikuModel = "glm-4.5-air"
        SonnetModel = "glm-5-turbo"
        OpusModel = "glm-5.1"
    }
    "2" = @{
        Name = "Kimi (Moonshot)"
        BaseUrl = "https://api.kimi.com/coding/"
        AuthToken = "YOUR_KIMI_API_KEY"
        HaikuModel = "kimi-k2-thinking-turbo"
        SonnetModel = "kimi-k2.5"
        OpusModel = "kimi-k2.6"
    }
    "3" = @{
        Name = "Custom Vendor"
        BaseUrl = "https://your-vendor-url/api/anthropic"
        AuthToken = "YOUR_CUSTOM_API_KEY"
        HaikuModel = "custom-haiku"
        SonnetModel = "custom-sonnet"
        OpusModel = "custom-opus"
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Claude Code Model Vendor Switcher" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $settingsPath) {
    $current = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $currentUrl = $current.env.ANTHROPIC_BASE_URL
    $currentHaiku = $current.env.ANTHROPIC_DEFAULT_HAIKU_MODEL
    $currentSonnet = $current.env.ANTHROPIC_DEFAULT_SONNET_MODEL
    $currentOpus = $current.env.ANTHROPIC_DEFAULT_OPUS_MODEL
    Write-Host "Current config:" -ForegroundColor Yellow
    Write-Host "  Base URL : $currentUrl"
    Write-Host "  Haiku    : $currentHaiku"
    Write-Host "  Sonnet   : $currentSonnet"
    Write-Host "  Opus     : $currentOpus"
    Write-Host ""
}

Write-Host "Select vendor:" -ForegroundColor Green
foreach ($key in ($vendors.Keys | Sort-Object)) {
    $v = $vendors[$key]
    Write-Host "  [$key] $($v.Name)" -ForegroundColor White
}
Write-Host "  [q] Quit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter option"

if ($choice -eq "q") {
    Write-Host "Bye" -ForegroundColor Gray
    exit 0
}

if (-not $vendors.ContainsKey($choice)) {
    Write-Host "Invalid option!" -ForegroundColor Red
    exit 1
}

$vendor = $vendors[$choice]

Copy-Item $settingsPath $backupPath -Force
Write-Host ""
Write-Host "Backup saved to settings.json.bak" -ForegroundColor Gray

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

$settings.env.ANTHROPIC_BASE_URL = $vendor.BaseUrl
$settings.env.ANTHROPIC_AUTH_TOKEN = $vendor.AuthToken
$settings.env.ANTHROPIC_DEFAULT_HAIKU_MODEL = $vendor.HaikuModel
$settings.env.ANTHROPIC_DEFAULT_SONNET_MODEL = $vendor.SonnetModel
$settings.env.ANTHROPIC_DEFAULT_OPUS_MODEL = $vendor.OpusModel

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8

Write-Host ""
Write-Host "Switched to: $($vendor.Name)" -ForegroundColor Green
Write-Host "  Base URL : $($vendor.BaseUrl)" -ForegroundColor White
Write-Host "  Haiku    : $($vendor.HaikuModel)" -ForegroundColor White
Write-Host "  Sonnet   : $($vendor.SonnetModel)" -ForegroundColor White
Write-Host "  Opus     : $($vendor.OpusModel)" -ForegroundColor White
Write-Host ""
Write-Host "Please restart Claude Code to apply changes!" -ForegroundColor Yellow
Write-Host ""
