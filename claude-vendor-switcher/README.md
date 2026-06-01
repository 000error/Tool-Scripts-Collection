# Claude Vendor Switcher

Windows helper scripts for switching Claude Code between Anthropic-compatible API vendors.

## Files

- `switch_vendor.ps1`: Main PowerShell switcher.
- `switch-vendor.bat`: Double-click launcher for Windows.
- `custom_vendors.example.json`: Example custom vendor file format.

## Install

Copy the scripts to your Claude config directory:

```powershell
Copy-Item .\switch_vendor.ps1 "$env:USERPROFILE\.claude\switch_vendor.ps1" -Force
Copy-Item .\switch-vendor.bat "$env:USERPROFILE\.claude\切换模型厂商.bat" -Force
```

Edit the built-in vendor API keys in `switch_vendor.ps1`, or choose `a` in the menu to add a custom vendor through Claude Code.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\switch_vendor.ps1"
```

Or double-click `切换模型厂商.bat`.

After switching vendors, close old terminals and open a new terminal before running `claude`.

## Notes

- Real API keys are intentionally not included.
- `settings.json`, `settings.json.bak`, and `custom_vendors.json` are local runtime files and should not be committed.
- The script writes both `settings.json` and Windows user-level environment variables so Claude Code sees a consistent provider.
