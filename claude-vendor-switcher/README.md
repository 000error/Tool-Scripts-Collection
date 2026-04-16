# Claude Code 模型厂商切换工具

一个用于在 Windows 环境下快速切换 Claude Code 第三方模型厂商配置的小工具。

## 功能

- 交互式选择模型厂商（智谱 ZhipuAI / 月之暗面 Kimi / 自定义厂商）
- 自动备份当前的 `settings.json` 到 `settings.json.bak`
- 自动修改 Claude Code 的 `settings.json` 中的以下环境变量：
  - `ANTHROPIC_BASE_URL`
  - `ANTHROPIC_AUTH_TOKEN`
  - `ANTHROPIC_DEFAULT_HAIKU_MODEL`
  - `ANTHROPIC_DEFAULT_SONNET_MODEL`
  - `ANTHROPIC_DEFAULT_OPUS_MODEL`
- 切换后提示重启 Claude Code 以生效

## 文件说明

| 文件 | 说明 |
|------|------|
| `switch_vendor.ps1` | PowerShell 核心脚本，负责读取和修改配置 |
| `切换模型厂商.bat` | Windows 批处理入口，双击即可运行 |

## 使用前提

1. 已安装 [Claude Code](https://claude.ai/code) 并在本机生成过 `settings.json`。
2. 脚本默认读取/修改路径：`%USERPROFILE%\.claude\settings.json`
3. 你需要将脚本中的 `AuthToken` 占位符替换为你自己的真实 API Key：
   - `YOUR_ZHIPU_API_KEY` → 你的智谱 AI API Key
   - `YOUR_KIMI_API_KEY` → 你的 Kimi (Moonshot) API Key
   - `YOUR_CUSTOM_API_KEY` → 自定义厂商的 API Key

## 快速开始

1. 将 `switch_vendor.ps1` 和 `切换模型厂商.bat` 复制到 `%USERPROFILE%\.claude\` 目录下（或者任意目录，但需保持 bat 中的路径一致）。
2. 用文本编辑器打开 `switch_vendor.ps1`，填入你自己的 API Key。
3. 双击运行 `切换模型厂商.bat`，按提示选择厂商即可。

## 注意事项

- 运行前请确保 Claude Code 已经至少启动过一次，确保 `settings.json` 文件已存在。
- 每次切换都会覆盖上一次的配置，但会自动生成 `.bak` 备份文件。
- 切换完成后需要**重启 Claude Code** 才能使新配置生效。
