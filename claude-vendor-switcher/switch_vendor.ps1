$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$backupPath = "$env:USERPROFILE\.claude\settings.json.bak"
$customVendorsPath = "$env:USERPROFILE\.claude\custom_vendors.json"

$builtInVendors = @(
    [ordered]@{
        Name = "GLM (ZhipuAI)"
        BaseUrl = "https://open.bigmodel.cn/api/anthropic"
        AuthToken = "YOUR_GLM_API_KEY"
        HaikuModel = "glm-4.5-air"
        SonnetModel = "glm-5-turbo"
        OpusModel = "glm-5.1"
        Source = "Built-in"
    },
    [ordered]@{
        Name = "Kimi (Moonshot)"
        BaseUrl = "https://api.kimi.com/coding/"
        AuthToken = "YOUR_KIMI_API_KEY"
        HaikuModel = "kimi-k2-thinking-turbo"
        SonnetModel = "kimi-k2.5"
        OpusModel = "kimi-k2.6"
        Source = "Built-in"
    },
    [ordered]@{
        Name = "Mimo"
        BaseUrl = "https://token-plan-sgp.xiaomimimo.com/anthropic"
        AuthToken = "YOUR_MIMO_API_KEY"
        HaikuModel = "mimo-v2.5-pro"
        SonnetModel = "mimo-v2.5-pro"
        OpusModel = "mimo-v2.5-pro"
        Source = "Built-in"
    }
)

function Read-RequiredValue($Prompt) {
    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
        Write-Host "Value cannot be empty." -ForegroundColor Red
    }
}

function Read-OptionalValue($Prompt, $DefaultValue) {
    $value = Read-Host "$Prompt [$DefaultValue]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }
    return $value.Trim()
}

function Load-CustomVendors {
    if (-not (Test-Path $customVendorsPath)) {
        return @()
    }

    try {
        $raw = Get-Content $customVendorsPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return @()
        }
        $data = $raw | ConvertFrom-Json
        if ($null -eq $data) {
            return @()
        }
        if ($data -is [array]) {
            return @($data)
        }
        return @($data)
    }
    catch {
        Write-Host "Failed to read custom_vendors.json: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Save-CustomVendors($Vendors) {
    $Vendors | ConvertTo-Json -Depth 10 | Set-Content $customVendorsPath -Encoding UTF8
}

function Get-AllVendors {
    $all = @()
    foreach ($v in $builtInVendors) {
        $all += [pscustomobject]$v
    }
    foreach ($v in (Load-CustomVendors)) {
        $customVendor = $v | Select-Object *
        if ($null -eq $customVendor.PSObject.Properties["Source"]) {
            $customVendor | Add-Member -MemberType NoteProperty -Name Source -Value "Custom"
        }
        else {
            $customVendor.Source = "Custom"
        }
        $all += $customVendor
    }
    return $all
}

function Add-CustomVendor {
    Write-Host ""
    Write-Host "Add custom vendor" -ForegroundColor Cyan
    Write-Host "-----------------" -ForegroundColor Cyan

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($null -eq $claudeCmd) {
        Write-Host "Claude Code command not found. Please install or fix claude first." -ForegroundColor Red
        return
    }

    $claudeDir = Split-Path $settingsPath -Parent
    $prompt = @"
你正在帮助用户给 Claude Code 的“模型厂商切换脚本”添加一个自定义厂商。

请只和用户确认这个自定义厂商在 Claude Code 里真正必要的参数，然后只修改这个文件：
$customVendorsPath

不要修改 settings.json，不要切换当前厂商，不要写入 Windows 环境变量。

custom_vendors.json 是 JSON 数组。请追加或更新一个对象，字段仅在必要时写入：
- Name: 显示名称，必填。
- BaseUrl: Anthropic Messages 兼容入口，例如 https://example.com 或 https://example.com/anthropic。仅当厂商要求时填写。
- AuthToken: API key 或 token。仅当厂商要求时填写。
- AuthVariable: 认证变量名。默认是 ANTHROPIC_AUTH_TOKEN；如果厂商官方要求 ANTHROPIC_API_KEY，就写 ANTHROPIC_API_KEY。
- HaikuModel: Claude Code 使用 --model haiku 时映射的模型名。仅当用户提供或厂商明确支持时填写。
- SonnetModel: Claude Code 使用 --model sonnet 时映射的模型名。仅当用户提供或厂商明确支持时填写。
- OpusModel: Claude Code 使用 --model opus 时映射的模型名。仅当用户提供或厂商明确支持时填写。
- ExtraEnv: 对象。只放厂商官方要求的额外 Claude Code 环境变量，例如 {"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"1"}。
- CreatedAt: 当前时间，ISO 风格字符串。

规则：
1. 不要让用户瞎填 Haiku/Sonnet/Opus。如果厂商没有这三档，就询问默认/推荐模型，并只写对应可用的模型字段。
2. 如果官方文档只说通过 --model 指定完整模型名，可以不写 HaikuModel/SonnetModel/OpusModel。
3. 如果 Base URL 是 OpenAI compatible 的 /v1 地址，请提醒用户 Claude Code 通常需要 Anthropic Messages 兼容入口；除非厂商明确支持 Claude Code，否则不要硬写。
4. 最后保存 JSON 后，告诉用户回到切换脚本选择新出现的自定义厂商。
"@

    Write-Host "Starting Claude Code custom vendor assistant..." -ForegroundColor Cyan
    Push-Location $claudeDir
    try {
        & claude --add-dir $claudeDir $prompt
    }
    finally {
        Pop-Location
    }
}

function Ensure-SettingsShape($Settings) {
    if ($null -eq $Settings) {
        $Settings = [pscustomobject]@{}
    }
    if ($null -eq $Settings.PSObject.Properties["env"]) {
        $Settings | Add-Member -MemberType NoteProperty -Name env -Value ([pscustomobject]@{})
    }
    return $Settings
}

function Set-EnvValue($EnvObject, $Name, $Value) {
    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        Remove-EnvValue $EnvObject $Name
        return
    }
    if ($null -eq $EnvObject.PSObject.Properties[$Name]) {
        $EnvObject | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
    else {
        $EnvObject.$Name = $Value
    }
}

function Remove-EnvValue($EnvObject, $Name) {
    if ($null -ne $EnvObject.PSObject.Properties[$Name]) {
        $EnvObject.PSObject.Properties.Remove($Name)
    }
}

function Get-ObjectMap($Object) {
    $map = @{}
    if ($null -eq $Object) {
        return $map
    }
    foreach ($property in $Object.PSObject.Properties) {
        $map[$property.Name] = [string]$property.Value
    }
    return $map
}

function Warn-MachineAnthropicEnvironment {
    $machineVars = @(
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL"
    )
    $found = @()
    foreach ($name in $machineVars) {
        $value = [Environment]::GetEnvironmentVariable($name, "Machine")
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $found += $name
        }
    }
    if ($found.Count -gt 0) {
        Write-Host "Warning: Machine-level Claude environment variables exist and may override this switcher:" -ForegroundColor Yellow
        Write-Host "  $($found -join ', ')" -ForegroundColor Yellow
        Write-Host "Remove them from System Environment Variables if Claude Code reports auth conflict." -ForegroundColor Yellow
        Write-Host ""
    }
}

function Set-ClaudeUserEnvironment($Vendor) {
    $authVariable = "ANTHROPIC_AUTH_TOKEN"
    if ($null -ne $Vendor.PSObject.Properties["AuthVariable"] -and -not [string]::IsNullOrWhiteSpace($Vendor.AuthVariable)) {
        $authVariable = $Vendor.AuthVariable
    }

    $vars = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace([string]$Vendor.BaseUrl)) { $vars.ANTHROPIC_BASE_URL = $Vendor.BaseUrl }
    if (-not [string]::IsNullOrWhiteSpace([string]$Vendor.HaikuModel)) { $vars.ANTHROPIC_DEFAULT_HAIKU_MODEL = $Vendor.HaikuModel }
    if (-not [string]::IsNullOrWhiteSpace([string]$Vendor.SonnetModel)) { $vars.ANTHROPIC_DEFAULT_SONNET_MODEL = $Vendor.SonnetModel }
    if (-not [string]::IsNullOrWhiteSpace([string]$Vendor.OpusModel)) { $vars.ANTHROPIC_DEFAULT_OPUS_MODEL = $Vendor.OpusModel }
    if (-not [string]::IsNullOrWhiteSpace([string]$Vendor.AuthToken)) { $vars[$authVariable] = $Vendor.AuthToken }

    if ($null -ne $Vendor.PSObject.Properties["DisableNonEssentialTraffic"]) {
        $vars.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = $Vendor.DisableNonEssentialTraffic
    }
    if ($null -ne $Vendor.PSObject.Properties["AttributionHeader"]) {
        $vars.CLAUDE_CODE_ATTRIBUTION_HEADER = $Vendor.AttributionHeader
    }
    $extraEnv = Get-ObjectMap $Vendor.ExtraEnv
    foreach ($key in $extraEnv.Keys) {
        if (-not [string]::IsNullOrWhiteSpace($key) -and -not [string]::IsNullOrWhiteSpace($extraEnv[$key])) {
            $vars[$key] = $extraEnv[$key]
        }
    }

    foreach ($item in $vars.GetEnumerator()) {
        $null = & setx.exe $item.Key $item.Value
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set user environment variable: $($item.Key)"
        }
    }

    if ($null -eq $Vendor.PSObject.Properties["DisableNonEssentialTraffic"]) {
        $null = & reg.exe delete HKCU\Environment /v CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC /f 2>$null
        Remove-Item Env:\CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -ErrorAction SilentlyContinue
    }
    if ($null -eq $Vendor.PSObject.Properties["AttributionHeader"]) {
        $null = & reg.exe delete HKCU\Environment /v CLAUDE_CODE_ATTRIBUTION_HEADER /f 2>$null
        Remove-Item Env:\CLAUDE_CODE_ATTRIBUTION_HEADER -ErrorAction SilentlyContinue
    }
    if ($authVariable -eq "ANTHROPIC_API_KEY") {
        $null = & reg.exe delete HKCU\Environment /v ANTHROPIC_AUTH_TOKEN /f 2>$null
        Remove-Item Env:\ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
    }
    else {
        $null = & reg.exe delete HKCU\Environment /v ANTHROPIC_API_KEY /f 2>$null
        Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    }

    if ($vars.Contains("ANTHROPIC_BASE_URL")) { $env:ANTHROPIC_BASE_URL = $Vendor.BaseUrl }
    if ($vars.Contains("ANTHROPIC_DEFAULT_HAIKU_MODEL")) { $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Vendor.HaikuModel }
    if ($vars.Contains("ANTHROPIC_DEFAULT_SONNET_MODEL")) { $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Vendor.SonnetModel }
    if ($vars.Contains("ANTHROPIC_DEFAULT_OPUS_MODEL")) { $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Vendor.OpusModel }
    if ($authVariable -eq "ANTHROPIC_API_KEY") {
        $env:ANTHROPIC_API_KEY = $Vendor.AuthToken
    }
    else {
        $env:ANTHROPIC_AUTH_TOKEN = $Vendor.AuthToken
    }
    if ($null -ne $Vendor.PSObject.Properties["DisableNonEssentialTraffic"]) {
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = $Vendor.DisableNonEssentialTraffic
    }
    if ($null -ne $Vendor.PSObject.Properties["AttributionHeader"]) {
        $env:CLAUDE_CODE_ATTRIBUTION_HEADER = $Vendor.AttributionHeader
    }
    foreach ($key in $extraEnv.Keys) {
        Set-Item -Path "Env:\$key" -Value $extraEnv[$key]
    }
}

function Switch-Vendor($Vendor) {
    if (-not (Test-Path $settingsPath)) {
        [pscustomobject]@{ env = [pscustomobject]@{} } | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    }

    Copy-Item $settingsPath $backupPath -Force
    Write-Host ""
    Write-Host "Backup saved to settings.json.bak" -ForegroundColor Gray

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings = Ensure-SettingsShape $settings
    $authVariable = "ANTHROPIC_AUTH_TOKEN"
    if ($null -ne $Vendor.PSObject.Properties["AuthVariable"] -and -not [string]::IsNullOrWhiteSpace($Vendor.AuthVariable)) {
        $authVariable = $Vendor.AuthVariable
    }

    Set-EnvValue $settings.env "ANTHROPIC_BASE_URL" $Vendor.BaseUrl
    Set-EnvValue $settings.env $authVariable $Vendor.AuthToken
    if ($authVariable -eq "ANTHROPIC_API_KEY") {
        Remove-EnvValue $settings.env "ANTHROPIC_AUTH_TOKEN"
    }
    else {
        Remove-EnvValue $settings.env "ANTHROPIC_API_KEY"
    }
    Set-EnvValue $settings.env "ANTHROPIC_DEFAULT_HAIKU_MODEL" $Vendor.HaikuModel
    Set-EnvValue $settings.env "ANTHROPIC_DEFAULT_SONNET_MODEL" $Vendor.SonnetModel
    Set-EnvValue $settings.env "ANTHROPIC_DEFAULT_OPUS_MODEL" $Vendor.OpusModel
    if ($null -ne $Vendor.PSObject.Properties["DisableNonEssentialTraffic"]) {
        Set-EnvValue $settings.env "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" $Vendor.DisableNonEssentialTraffic
    }
    if ($null -ne $Vendor.PSObject.Properties["AttributionHeader"]) {
        Set-EnvValue $settings.env "CLAUDE_CODE_ATTRIBUTION_HEADER" $Vendor.AttributionHeader
    }
    else {
        Remove-EnvValue $settings.env "CLAUDE_CODE_ATTRIBUTION_HEADER"
    }
    if ($null -eq $Vendor.PSObject.Properties["DisableNonEssentialTraffic"]) {
        Remove-EnvValue $settings.env "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
    }
    $extraEnv = Get-ObjectMap $Vendor.ExtraEnv
    foreach ($key in $extraEnv.Keys) {
        Set-EnvValue $settings.env $key $extraEnv[$key]
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Set-ClaudeUserEnvironment $Vendor

    Write-Host ""
    Write-Host "Switched to: $($Vendor.Name)" -ForegroundColor Green
    Write-Host "  Base URL : $($Vendor.BaseUrl)" -ForegroundColor White
    Write-Host "  Haiku    : $($Vendor.HaikuModel)" -ForegroundColor White
    Write-Host "  Sonnet   : $($Vendor.SonnetModel)" -ForegroundColor White
    Write-Host "  Opus     : $($Vendor.OpusModel)" -ForegroundColor White
    Write-Host "  Scope    : settings.json and Windows user environment" -ForegroundColor White
    Write-Host ""
    Write-Host "Please restart Claude Code to apply changes." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Claude Code Model Vendor Switcher" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Warn-MachineAnthropicEnvironment

if (Test-Path $settingsPath) {
    try {
        $current = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $current = Ensure-SettingsShape $current

        $baseUrl = $current.env.ANTHROPIC_BASE_URL
        $haiku = $current.env.ANTHROPIC_DEFAULT_HAIKU_MODEL
        $sonnet = $current.env.ANTHROPIC_DEFAULT_SONNET_MODEL
        $opus = $current.env.ANTHROPIC_DEFAULT_OPUS_MODEL
        $source = "settings.json"

        if ([string]::IsNullOrWhiteSpace($baseUrl)) {
            $baseUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "Process")
            if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User") }
            if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "Machine") }
            if (-not [string]::IsNullOrWhiteSpace($baseUrl)) { $source = "environment variable" }
        }
        if ([string]::IsNullOrWhiteSpace($haiku)) {
            $haiku = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_HAIKU_MODEL", "Process")
            if ([string]::IsNullOrWhiteSpace($haiku)) { $haiku = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_HAIKU_MODEL", "User") }
            if ([string]::IsNullOrWhiteSpace($haiku)) { $haiku = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_HAIKU_MODEL", "Machine") }
        }
        if ([string]::IsNullOrWhiteSpace($sonnet)) {
            $sonnet = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_SONNET_MODEL", "Process")
            if ([string]::IsNullOrWhiteSpace($sonnet)) { $sonnet = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_SONNET_MODEL", "User") }
            if ([string]::IsNullOrWhiteSpace($sonnet)) { $sonnet = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_SONNET_MODEL", "Machine") }
        }
        if ([string]::IsNullOrWhiteSpace($opus)) {
            $opus = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_OPUS_MODEL", "Process")
            if ([string]::IsNullOrWhiteSpace($opus)) { $opus = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_OPUS_MODEL", "User") }
            if ([string]::IsNullOrWhiteSpace($opus)) { $opus = [Environment]::GetEnvironmentVariable("ANTHROPIC_DEFAULT_OPUS_MODEL", "Machine") }
        }

        if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = "(not set)" }
        if ([string]::IsNullOrWhiteSpace($haiku)) { $haiku = "(not set)" }
        if ([string]::IsNullOrWhiteSpace($sonnet)) { $sonnet = "(not set)" }
        if ([string]::IsNullOrWhiteSpace($opus)) { $opus = "(not set)" }

        Write-Host "Current config ($source):" -ForegroundColor Yellow
        Write-Host "  Base URL : $baseUrl"
        Write-Host "  Haiku    : $haiku"
        Write-Host "  Sonnet   : $sonnet"
        Write-Host "  Opus     : $opus"
        if ($source -eq "environment variable") {
            Write-Host "  Note     : settings.json env is empty; showing environment variables." -ForegroundColor DarkYellow
        }
        Write-Host ""
    }
    catch {
        Write-Host "Current settings.json cannot be parsed." -ForegroundColor Red
        Write-Host ""
    }
}

$vendors = @(Get-AllVendors)

Write-Host "Select vendor:" -ForegroundColor Green
for ($i = 0; $i -lt $vendors.Count; $i++) {
    $num = $i + 1
    $v = $vendors[$i]
    $tag = if ($v.Source -eq "Custom") { "custom" } else { "built-in" }
    Write-Host "  [$num] $($v.Name) ($tag)" -ForegroundColor White
}
Write-Host "  [a] Add custom vendor" -ForegroundColor Cyan
Write-Host "  [q] Quit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter option"

if ($choice -eq "q") {
    Write-Host "Bye" -ForegroundColor Gray
    exit 0
}

if ($choice -eq "a") {
    Add-CustomVendor
    exit 0
}

[int]$index = 0
if (-not [int]::TryParse($choice, [ref]$index)) {
    Write-Host "Invalid option!" -ForegroundColor Red
    exit 1
}

if ($index -lt 1 -or $index -gt $vendors.Count) {
    Write-Host "Invalid option!" -ForegroundColor Red
    exit 1
}

Switch-Vendor $vendors[$index - 1]


