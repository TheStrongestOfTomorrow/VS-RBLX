# VS-RBLX `ui-lib`

`ui-lib/init.lua` extracts VS-RBLX's standalone Luau window shell (draggable title bar, viewport auto-clamp, and player resize corner) for lightweight custom Roblox scripts that do not need the full 69-module IDE workbench.

## Quick Start

```lua
local uiLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheStrongestOfTomorrow/VS-RBLX/main/ui-lib/init.lua"))()

local win = uiLib.mountWindow({
	title = "My Custom Luau Window",
	width = 720,
	height = 460,
})
```
