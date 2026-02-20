-- Load the library
local Library
local ok, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/dunnerulz/Wabi-Sabi-UI-Library/refs/heads/main/library.lua"))()
    Library = WabiSabiUILibrary
end)

if not ok or not Library then
    warn("Failed to load WabiSabi UI: " .. tostring(err))
    return
end

-- Create the window
local Window = Library:CreateWindow({
    Title = "My Script",
    Columns = 2,
    Divider = true,
    ConfigFile = "my_script_config.json",
    BuiltInIndicatorToggle = true,
    Theme = {
        Colors = {
            Accent = Color3.fromRGB(0, 150, 255)
        }
    }
})

-- Column 1
Window:AddSection("General", { Column = 1 })

Window:AddToggle("my_toggle", {
    Text = "Enable Feature",
    Description = "Turns the feature on or off",
    Default = false,
    Keybind = true,
    Column = 1,
    Callback = function(value)
        print("Toggle:", value)
    end
})

Window:AddSlider("my_slider", {
    Text = "Speed",
    Description = "Adjusts speed value",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 50,
    Integer = true,
    Column = 1,
    Callback = function(value)
        print("Slider:", value)
    end
})

-- Column 2
Window:AddSection("Options", { Column = 2 })

Window:AddDropdown("my_dropdown", {
    Text = "Mode",
    Options = {"Option A", "Option B", "Option C", "Option D", "Option E"},
    Default = "Option A",
    MaxVisible = 3,
    Column = 2,
    Callback = function(value)
        print("Dropdown:", value)
    end
})

Window:AddButton("my_button", {
    Text = "Do Something",
    Column = 2,
    Callback = function()
        Window:SetStatus("Active", Color3.fromRGB(160, 225, 60))
        print("Button clicked")
    end
})

-- Main loop (required for Matcha)
while true do
    local ok, err = pcall(function()
        Window:Step()
    end)
    if not ok then
        warn("Step error: " .. tostring(err))
        task.wait(1)
    end
    task.wait()
end
