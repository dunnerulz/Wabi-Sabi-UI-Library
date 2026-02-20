# Wabi Sabi UI Library

A UI library for [Matcha](https://matcha.gg) (external Roblox executor). Built around Matcha's constraints — no events, all input polled via a step loop.

---

## Setup

Load the library via HttpGet, then call `Window:Step()` in a loop. Without the loop nothing renders or responds to input.

```lua
loadstring(game:HttpGet("YOUR_RAW_URL_HERE"))()
local Library = WabiSabiUILibrary

local Window = Library:CreateWindow({ Title = "My Script" })

-- add controls here

while true do
    Window:Step()
    task.wait()
end
```

---

## CreateWindow

```lua
Library:CreateWindow({
    Title = "My Script",       -- window title
    Columns = 2,               -- 1 or 2 column layout (default: 1)
    Divider = true,            -- show vertical divider between columns (only with Columns=2)
    ConfigFile = "my_cfg.json",-- save/load filename (default: "wabi_ui_config.json")
    BuiltInIndicatorToggle = true, -- adds a toggle to control the indicator panel
    UIKey = 0x23,              -- key to show/hide the UI (default: END key)
    Theme = {
        Colors = {
            Accent = Color3.fromRGB(255, 50, 50) -- override any color from the defaults
        }
    }
})
```

---

## Controls

All controls take an `id` (string) and a table of options. `Column` is optional — only relevant when using 2 columns.

### Toggle
```lua
Window:AddToggle("my_toggle", {
    Text = "Enable Thing",
    Description = "Shows on hover",  -- optional
    Default = false,
    Keybind = true,                  -- shows a bind button
    ShowInIndicator = true,          -- show in indicator panel when active (default: true)
    Column = 1,
    Callback = function(value) end
})
```

### Slider
```lua
Window:AddSlider("my_slider", {
    Text = "Speed",
    Description = "...",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 50,
    Integer = true,   -- display as integer (default: false, shows 2 decimal places)
    Column = 1,
    Callback = function(value) end
})
```

### Dropdown
```lua
Window:AddDropdown("my_dropdown", {
    Text = "Mode",
    Options = {"A", "B", "C", "D"},
    Default = "A",
    MaxVisible = 3,   -- max rows shown before scrollbar appears (default: 6)
    Column = 2,
    Callback = function(value) end
})
```

### Button
```lua
Window:AddButton("my_button", {
    Text = "Click Me",
    Description = "...",
    Column = 2,
    Callback = function() end
})
```

### Section
```lua
Window:AddSection("Section Label", { Column = 1 })
```

---

## API

```lua
-- Get a control's current value (and bind for toggles)
local value, bind = Window:Get("my_toggle")

-- Set a control's value programmatically
Window:Set("my_toggle", true)
Window:Set("my_slider", 75)
Window:Set("my_dropdown", "B")

-- Set a keybind on a toggle
Window:SetBind("my_toggle", 0x41) -- A key

-- Set the status text in the header
Window:SetStatus("Active", Color3.fromRGB(160, 225, 60))

-- Save / Load / Reset config
Window:SaveConfig()
Window:LoadConfig()
Window:ResetConfig()
```

---

## Indicator Panel

The indicator panel shows toggles that are currently **enabled and have a keybind set**. It spawns to the left of the main window.

To exclude a toggle from the indicator, set `ShowInIndicator = false`.

---

## Config

Save/Load/Reset is built into the config panel (spawns to the right of the main window). Config saves toggle values, slider values, dropdown selections, keybinds, and the UI key. Panel positions are not saved.

---

## Notes

- The `while true do Window:Step() task.wait() end` loop is **required**. Nothing will work without it.
- Keybinds use Windows virtual keycodes (e.g. `0x41` = A, `0x23` = END).
- The UI toggle key is END by default. Press it to show/hide the UI.
