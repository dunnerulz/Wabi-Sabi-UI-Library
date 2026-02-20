-- Wabi Sabi UI Library
-- For Matcha LuaVM

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- Default style
local DefaultStyle = {
    Window = {
        StartPos = Vector2.new(100, 300),
        Size = Vector2.new(460, 295),
        Title = "wabi sabi ui"
    },
    Colors = {
        Background = Color3.fromRGB(12, 12, 12),
        Header     = Color3.fromRGB(20, 20, 20),
        Border     = Color3.fromRGB(45, 45, 45),
        TextMain   = Color3.fromRGB(235, 235, 235),
        TextDim    = Color3.fromRGB(160, 160, 160),
        TextHeader = Color3.fromRGB(100, 100, 100),
        Accent     = Color3.fromRGB(255, 50, 50),

        Status = {
            Idle     = Color3.fromRGB(200, 200, 200),
            Active   = Color3.fromRGB(160, 225, 60),
            Locked   = Color3.fromRGB(50, 255, 50),
            Targeted = Color3.fromRGB(255, 100, 100),
            Panic    = Color3.fromRGB(255, 150, 0),
            Clash    = Color3.fromRGB(180, 0, 255),
            Predict  = Color3.fromRGB(0, 255, 255),
            Disabled = Color3.fromRGB(100, 100, 100)
        }
    }
}

-- Math helpers
local Math = {}

function Math.Clamp(x, minv, maxv)
    if x < minv then return minv end
    if x > maxv then return maxv end
    return x
end

function Math.RoundStep(x, step)
    if step <= 0 then return x end
    return math.floor((x / step) + 0.5) * step
end

-- Converts a keycode to a readable string
local function GetKeyName(code)
    if code == nil then return "NONE" end
    if code == 0x01 then return "M1" end
    if code == 0x02 then return "M2" end
    if code >= 0x30 and code <= 0x39 then return string.char(code) end -- 0-9
    if code >= 0x41 and code <= 0x5A then return string.char(code) end -- A-Z
    if code >= 0x70 and code <= 0x7B then return "F" .. tostring(code - 0x6F) end -- F1-F12

    local map = {
        [0x1B] = "ESC", [0x20] = "SPACE", [0x09] = "TAB", [0x0D] = "ENTER",
        [0x10] = "SHIFT", [0x11] = "CTRL", [0x12] = "ALT",
        [0x25] = "LEFT", [0x26] = "UP", [0x27] = "RIGHT", [0x28] = "DOWN",
        [0x21] = "PGUP", [0x22] = "PGDN", [0x23] = "END", [0x24] = "HOME",
        [0x2D] = "INS", [0x2E] = "DEL"
    }
    return map[code] or ("0x" .. string.format("%02X", code))
end

-- Drawing helpers
local function createDrawing(drawType, properties)
    local obj = Drawing.new(drawType)
    for k, v in pairs(properties) do
        obj[k] = v
    end
    return obj
end

local function safeRemove(d)
    if not d then return end
    pcall(function()
        if type(d) == "table" then
            for _, v in pairs(d) do safeRemove(v) end
            return
        end
        if d.Remove then d:Remove() end
    end)
end

local function getSafeMousePosition()
    local lp = Players.LocalPlayer
    if not lp then return Vector2.new(0, 0) end
    local mouse = lp:GetMouse()
    if not mouse then return Vector2.new(0, 0) end
    return Vector2.new(mouse.X, mouse.Y)
end

local function isInRect(mousePos, x, y, w, h)
    return mousePos.X >= x and mousePos.X <= x + w and mousePos.Y >= y and mousePos.Y <= y + h
end

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            out[k] = deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end


-- Recursively set Visible on drawing objects or nested tables.
local function setVisibleDeep(obj, visible)
    if obj == nil then return end

    local t = type(obj)
    if t ~= "table" then
        pcall(function() obj.Visible = visible end)
        return
    end

    local ok, curVis = pcall(function() return obj.Visible end)
    if ok and type(curVis) == "boolean" then
        pcall(function() obj.Visible = visible end)
        return
    end

    for _, v in pairs(obj) do
        setVisibleDeep(v, visible)
    end
end


local Library = {}
Library.__index = Library

local function returnSelf(self) return self end


local Window = {}
Window.__index = Window

-- Layout constants
local LAYOUT = {
    SegHeight = 2,
    HeaderHeight = 20,
    TopDividerY = 22,
    ContentTopY = 30,
    FooterHeight = 20,
    PaddingX = 10,
    ColumnGap = 20,
    RowHeight = 20,
    SliderHeight = 40,
    SectionHeight = 18,
    ItemHeight = 16,
}

-- Control registration
function Window:_markLayoutDirty()
    self._layoutDirty = true
end

function Window:_registerControl(ctrl)
    table.insert(self.Controls, ctrl)

    if ctrl.Type == "Toggle" then
        self.Defaults.Toggles[ctrl.Id] = ctrl.Default
        self.Defaults.Binds[ctrl.Id] = ctrl.BindDefault
    elseif ctrl.Type == "Slider" then
        self.Defaults.Sliders[ctrl.Id] = ctrl.Default
    elseif ctrl.Type == "Dropdown" then
        self.Defaults.Dropdowns[ctrl.Id] = ctrl.Default
    end

    self:_markLayoutDirty()

    if self._initialized then
        self._needsRebuild = true
    end
end

function Window:AddSection(text, opts)
    opts = opts or {}
    local ctrl = {
        Type = "Section",
        Id = "__section_" .. tostring(#self.Controls + 1),
        Text = text or "",
        Column = opts.Column,
    }
    self:_registerControl(ctrl)
    return self
end

function Window:AddToggle(id, def)
    def = def or {}
    local ctrl = {
        Type = "Toggle",
        Id = id,
        Text = def.Text or id,
        Description = def.Description or "",
        Column = def.Column,

        Default = (def.Default == true),
        Value = (def.Default == true),

        Bindable = (def.Keybind == true),
        Bind = def.BindDefault,
        BindDefault = def.BindDefault,
        Callback = def.Callback,

        -- Whether this toggle is listed in the indicator panel
        ShowInIndicator = (def.ShowInIndicator ~= false)
    }
    self:_registerControl(ctrl)
    return self
end

function Window:AddSlider(id, def)
    def = def or {}
    local ctrl = {
        Type = "Slider",
        Id = id,
        Text = def.Text or id,
        Description = def.Description or "",
        Column = def.Column,

        Min = def.Min or 0,
        Max = def.Max or 100,
        Step = def.Step or 1,
        Integer = (def.Integer == true),

        Default = (def.Default ~= nil and def.Default or (def.Min or 0)),
        Value = (def.Default ~= nil and def.Default or (def.Min or 0)),

        Callback = def.Callback
    }
    self:_registerControl(ctrl)
    return self
end

function Window:AddButton(id, def)
    def = def or {}
    local ctrl = {
        Type = "Button",
        Id = id,
        Text = def.Text or id,
        Description = def.Description or "",
        Column = def.Column,

        Callback = def.Callback
    }
    self:_registerControl(ctrl)
    return self
end

function Window:AddDropdown(id, def)
    def = def or {}
    local options = def.Options or {}
    local default = def.Default
    if default == nil and #options > 0 then default = options[1] end

    local ctrl = {
        Type = "Dropdown",
        Id = id,
        Text = def.Text or id,
        Description = def.Description or "",
        Column = def.Column,

        Options = options,
        MaxVisible = def.MaxVisible or 6,
        Default = default,
        Value = default,

        Open = false,
        ScrollIndex = 1,

        Callback = def.Callback
    }
    self:_registerControl(ctrl)
    return self
end

-- Defaults / reset
function Window:_applyDefaults()
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Type == "Toggle" then
            ctrl.Value = (self.Defaults.Toggles[ctrl.Id] == true)
            ctrl.Bind = self.Defaults.Binds[ctrl.Id]
        elseif ctrl.Type == "Slider" then
            ctrl.Value = self.Defaults.Sliders[ctrl.Id]
        elseif ctrl.Type == "Dropdown" then
            ctrl.Value = self.Defaults.Dropdowns[ctrl.Id]
            ctrl.Open = false
            ctrl.ScrollIndex = 1
        end
    end

    self.Config.UIKey = self.Defaults.UIKey
    self.Config.UIEnabled = self.Defaults.UIEnabled
    self.Config.IndicatorEnabled = self.Defaults.IndicatorEnabled

    self:_markLayoutDirty()
end

-- Config system
function Window:_setConfigStatus(text, color, duration)
    self.ConfigSystem.StatusText = text or ""
    self.ConfigSystem.StatusColor = color or self.Style.Colors.TextDim
    self.ConfigSystem.StatusUntil = os.clock() + (duration or 1.25)
end

function Window:SaveConfig()
    if not writefile or not HttpService or not HttpService.JSONEncode then
        self:_setConfigStatus("Save unsupported", self.Style.Colors.TextDim, 1.5)
        return false
    end

    local data = {
        UIKey = self.Config.UIKey,
        UIEnabled = self.Config.UIEnabled,
        IndicatorEnabled = self.Config.IndicatorEnabled,

        Controls = {}
    }

    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Type == "Toggle" then
            data.Controls[ctrl.Id] = { Type="Toggle", Value = (ctrl.Value == true), Bind = ctrl.Bind or 0 }
        elseif ctrl.Type == "Slider" then
            data.Controls[ctrl.Id] = { Type="Slider", Value = ctrl.Value }
        elseif ctrl.Type == "Dropdown" then
            data.Controls[ctrl.Id] = { Type="Dropdown", Value = ctrl.Value }
        end
    end

    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then
        self:_setConfigStatus("JSON encode failed", self.Style.Colors.TextDim, 1.5)
        return false
    end

    pcall(function() writefile(self.ConfigSystem.Filename, encoded) end)
    self:_setConfigStatus("Saved", self.Style.Colors.Status.Active, 1.25)
    return true
end

function Window:LoadConfig()
    if not readfile or not HttpService or not HttpService.JSONDecode then
        self:_setConfigStatus("Load unsupported", self.Style.Colors.TextDim, 1.5)
        return false
    end

    local raw = nil
    local okRead = pcall(function() raw = readfile(self.ConfigSystem.Filename) end)
    if not okRead then
        self:_setConfigStatus("No config file", self.Style.Colors.TextDim, 1.5)
        return false
    end
    if not okRead or not raw or raw == "" then
        self:_setConfigStatus("Read failed", self.Style.Colors.TextDim, 1.5)
        return false
    end

    local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(decoded) ~= "table" then
        self:_setConfigStatus("JSON decode failed", self.Style.Colors.TextDim, 1.5)
        return false
    end

    if type(decoded.UIKey) == "number" then self.Config.UIKey = decoded.UIKey end
    if type(decoded.UIEnabled) == "boolean" then self.Config.UIEnabled = decoded.UIEnabled end
    if type(decoded.IndicatorEnabled) == "boolean" then self.Config.IndicatorEnabled = decoded.IndicatorEnabled end

    if type(decoded.Controls) == "table" then
        for _, ctrl in ipairs(self.Controls) do
            local saved = decoded.Controls[ctrl.Id]
            if type(saved) == "table" then
                if ctrl.Type == "Toggle" and saved.Type == "Toggle" then
                    if type(saved.Value) == "boolean" then ctrl.Value = saved.Value end
                    if type(saved.Bind) == "number" then ctrl.Bind = (saved.Bind ~= 0) and saved.Bind or nil end
                elseif ctrl.Type == "Slider" and saved.Type == "Slider" then
                    if type(saved.Value) == "number" then
                        ctrl.Value = Math.Clamp(saved.Value, ctrl.Min, ctrl.Max)
                        ctrl.Value = Math.RoundStep(ctrl.Value, ctrl.Step)
                    end
                elseif ctrl.Type == "Dropdown" and saved.Type == "Dropdown" then
                    if type(saved.Value) == "string" then ctrl.Value = saved.Value end
                end
            end
        end
    end

    self.UI:SetVisible(self.Config.UIEnabled)
    self.ConfigMenu:SetVisible(self.Config.UIEnabled)
    self.Indicator:SetVisible(self.Config.IndicatorEnabled)

    self:_markLayoutDirty()
    self:_setConfigStatus("Loaded", self.Style.Colors.Status.Active, 1.25)
    return true
end

function Window:ResetConfig()
    self:_applyDefaults()
    self.UI:SetVisible(self.Config.UIEnabled)
    self.ConfigMenu:SetVisible(self.Config.UIEnabled)
    self.Indicator:SetVisible(self.Config.IndicatorEnabled)
    self:_setConfigStatus("Reset", self.Style.Colors.Status.Active, 1.25)
    return true
end

-- Panel construction
function Window:_buildPanels()
    local selfWindow = self


    local UI = {
        Position = self.Style.Window.StartPos,
        Size = Vector2.new(self.Style.Window.Size.X, self.Style.Window.Size.Y),
        LastPos = nil,
        Visible = true,

        Drag = { IsDragging = false, StartMouse = nil, StartWindow = nil },

        Input = {
            LastM1 = false,
            LastUIKey = false,
            BindStates = {}
        },

        SliderState = { Active = nil, Hovered = nil },
        ScrollbarState = { Active = nil, StartMouseY = nil, StartIndex = nil },
        BindingMode = false,
        BindingTarget = nil,
        BindingDebounce = false,

        Elements = {},
        ControlsDraw = {},
    }

    function UI:SetVisible(visible)
        UI.Visible = visible
        for _, obj in pairs(UI.Elements) do
            setVisibleDeep(obj, visible)
        end
        for _, pack in pairs(UI.ControlsDraw) do
            setVisibleDeep(pack, visible)
        end

        if not visible then
            UI.BindingMode = false
            UI.BindingTarget = nil
            UI.BindingDebounce = false
            UI.Drag.IsDragging = false
            UI.SliderState.Active = nil
            UI.SliderState.Hovered = nil
            UI.ScrollbarState.Active = nil
            UI.ScrollbarState.StartMouseY = nil
            UI.ScrollbarState.StartIndex = nil
            UI.LastPos = nil
        end
    end


    function UI:_destroy()
        safeRemove(UI.Elements)
        safeRemove(UI.ControlsDraw)
        UI.Elements = {}
        UI.ControlsDraw = {}
    end

    function UI:InitFrame()
        local E = UI.Elements
        local C = selfWindow.Style.Colors

        E.MainBg = createDrawing("Square", { Filled = true, Color = C.Background, ZIndex = 1 })
        E.HeaderBg = createDrawing("Square", { Filled = true, Color = C.Header, ZIndex = 2 })
        E.Border = createDrawing("Square", { Filled = false, Thickness = 1, Color = C.Border, ZIndex = 3 })
        E.Divider = createDrawing("Square", { Filled = true, Color = C.Border, ZIndex = 3 })

        E.VerticalLine = createDrawing("Line", { Thickness = 1, Color = C.Border, ZIndex = 3 })

        E.Title = createDrawing("Text", { Text = selfWindow.Style.Window.Title, Color = C.TextMain, Size = 13, Outline = true, ZIndex = 4 })
        E.StatusValue = createDrawing("Text", { Text = "IDLE", Color = selfWindow.Style.Colors.Status.Idle, Size = 13, Outline = true, ZIndex = 4, Center = true })
        E.Description = createDrawing("Text", { Text = selfWindow.Style.Window.Title, Color = C.TextDim, Size = 13, Outline = true, ZIndex = 4, Center = true })

        E.Segments = {}
        for i = 1, 100 do
            table.insert(E.Segments, createDrawing("Square", { Filled = true, ZIndex = 3, Size = Vector2.new(2, 2) }))
        end
    end

    function UI:BuildControls()
        UI.ControlsDraw = {}
        local C = selfWindow.Style.Colors

        for _, ctrl in ipairs(selfWindow.Controls) do
            local pack = {}

            if ctrl.Type == "Section" then
                pack.Text = createDrawing("Text", {
                    Text = ctrl.Text,
                    Color = C.TextHeader,
                    Size = 13,
                    Outline = true,
                    ZIndex = 4
                })

            elseif ctrl.Type == "Slider" then
                pack.Label = createDrawing("Text", { Text = ctrl.Text, Color = C.TextDim, Size = 13, Outline = true, ZIndex = 4 })
                -- No Center=true here: Center anchors both X and Y to the position point,
                -- which would shift the text upward relative to the label on the same row.
                -- We position it manually to align with the label baseline instead.
                pack.Value = createDrawing("Text", { Text = tostring(ctrl.Value), Color = C.TextMain, Size = 13, Outline = true, ZIndex = 4 })
                pack.BarBg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(30, 30, 30), ZIndex = 4 })
                pack.BarFill = createDrawing("Square", { Filled = true, Color = C.Accent, ZIndex = 5 })

            elseif ctrl.Type == "Toggle" then
                pack.Label = createDrawing("Text", { Text = ctrl.Text, Color = C.TextDim, Size = 13, Outline = true, ZIndex = 4 })
                pack.BoxOut = createDrawing("Square", { Filled = false, Thickness = 1, Color = C.Border, ZIndex = 4, Size = Vector2.new(13, 13) })
                pack.BoxFill = createDrawing("Square", { Filled = true, Color = C.Accent, ZIndex = 5, Size = Vector2.new(9, 9) })

                if ctrl.Bindable then
                    pack.BindBg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(25, 25, 25), ZIndex = 4, Size = Vector2.new(40, 16) })
                    pack.BindText = createDrawing("Text", { Text = "[NONE]", Color = C.TextDim, Size = 13, Outline = true, ZIndex = 5, Center = true })
                end

            elseif ctrl.Type == "Button" then
                pack.Bg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(25, 25, 25), ZIndex = 4 })
                pack.Text = createDrawing("Text", { Text = ctrl.Text, Color = C.TextMain, Size = 13, Outline = true, ZIndex = 5, Center = true })

            elseif ctrl.Type == "Dropdown" then
                pack.Label = createDrawing("Text", { Text = ctrl.Text, Color = C.TextDim, Size = 13, Outline = true, ZIndex = 4 })
                pack.ValueBg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(25, 25, 25), ZIndex = 4 })
                pack.ValueText = createDrawing("Text", { Text = tostring(ctrl.Value or ""), Color = C.TextMain, Size = 13, Outline = true, ZIndex = 5, Center = true })

                pack.ListBg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(18, 18, 18), ZIndex = 6 })
                pack.ListBorder = createDrawing("Square", { Filled = false, Thickness = 1, Color = C.Border, ZIndex = 7 })
                pack.Items = {}
                pack.ItemBgs = {}
                for i = 1, ctrl.MaxVisible do
                    pack.ItemBgs[i] = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(25, 25, 25), ZIndex = 6 })
                    pack.Items[i] = createDrawing("Text", { Text = "", Color = C.TextMain, Size = 13, Outline = true, ZIndex = 7, Center = false })
                end

                pack.ScrollTrack = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(30, 30, 30), ZIndex = 7 })
                pack.ScrollThumb = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(80, 80, 80), ZIndex = 8 })

            end

            UI.ControlsDraw[ctrl.Id] = pack
        end
    end


    local Indicator = {
        WIDTH = 170,
        HEADER_HEIGHT = 22,
        FEATURE_HEIGHT = 16,
        PADDING = 5,
        SEGMENT_COUNT = 50,

        Position = Vector2.new(20, 200),
        LastPos = nil,
        LastHeight = 0,

        Drag = { IsDragging = false, StartMouse = nil, StartWindow = nil },

        Visible = true,
        Elements = {},
    }

    function Indicator:SetVisible(visible)
        Indicator.Visible = visible
        for _, v in pairs(Indicator.Elements) do
            setVisibleDeep(v, visible)
        end
        if not visible then
            Indicator.Drag.IsDragging = false
            Indicator.LastPos = nil
        end
    end

    function Indicator:_destroy()
        safeRemove(Indicator.Elements)
        Indicator.Elements = {}
    end

    function Indicator:Init()
        local C = selfWindow.Style.Colors
        local screenCenterY = 300
        pcall(function()
            local cam = Workspace.CurrentCamera
            if cam and cam.ViewportSize then
                screenCenterY = cam.ViewportSize.Y / 2
            end
        end)

        Indicator.Position = Vector2.new(UI.Position.X - Indicator.WIDTH - 10, UI.Position.Y)

        local E = Indicator.Elements
        E.MainBg = createDrawing("Square", { Filled = true, Color = C.Background, ZIndex = 10 })
        E.HeaderBg = createDrawing("Square", { Filled = true, Color = C.Header, ZIndex = 11 })
        E.Border = createDrawing("Square", { Filled = false, Thickness = 1, Color = C.Border, ZIndex = 12 })
        E.Divider = createDrawing("Square", { Filled = true, Color = C.Border, ZIndex = 13 })
        E.Title = createDrawing("Text", { Text = "indicator", Color = C.TextMain, Size = 13, Outline = true, ZIndex = 13, Center = false })

        E.Segments = {}
        for i = 1, Indicator.SEGMENT_COUNT do
            table.insert(E.Segments, createDrawing("Square", { Filled = true, ZIndex = 12, Size = Vector2.new(2, 2) }))
        end

        E.FeatureLabels = {}
        for i = 1, 32 do
            E.FeatureLabels[i] = createDrawing("Text", { Text = "", Color = C.TextDim, Size = 13, Outline = true, ZIndex = 13, Center = false })
        end
    end


    local ConfigMenu = {
        WIDTH = 200,
        HEADER_HEIGHT = 22,
        CONTENT_HEIGHT = 60,
        SEGMENT_COUNT = 50,

        Position = Vector2.new(0, 0),
        LastPos = nil,
        Drag = { IsDragging = false, StartMouse = nil, StartWindow = nil },

        BindingMode = false,
        BindingDebounce = false,

        Visible = true,
        Elements = {},
    }

    function ConfigMenu:SetVisible(visible)
    ConfigMenu.Visible = visible
    for _, v in pairs(ConfigMenu.Elements) do
        setVisibleDeep(v, visible)
    end
    if not visible then
        ConfigMenu.BindingMode = false
        ConfigMenu.BindingDebounce = false
        ConfigMenu.Drag.IsDragging = false
        ConfigMenu.LastPos = nil
    end
end

    function ConfigMenu:_destroy()
        safeRemove(ConfigMenu.Elements)
        ConfigMenu.Elements = {}
    end

    function ConfigMenu:Init()
        local C = selfWindow.Style.Colors

        local mainMenuRight = UI.Position.X + UI.Size.X
        ConfigMenu.Position = Vector2.new(mainMenuRight + 10, UI.Position.Y)

        local E = ConfigMenu.Elements
        local totalHeight = ConfigMenu.HEADER_HEIGHT + 1 + ConfigMenu.CONTENT_HEIGHT

        E.MainBg = createDrawing("Square", { Filled = true, Color = C.Background, ZIndex = 20 })
        E.HeaderBg = createDrawing("Square", { Filled = true, Color = C.Header, ZIndex = 21 })
        E.Border = createDrawing("Square", { Filled = false, Thickness = 1, Color = C.Border, ZIndex = 22 })
        E.Divider = createDrawing("Square", { Filled = true, Color = C.Border, ZIndex = 23 })
        E.Title = createDrawing("Text", { Text = "config", Color = C.TextMain, Size = 13, Outline = true, ZIndex = 23, Center = false })

        E.Segments = {}
        for i = 1, ConfigMenu.SEGMENT_COUNT do
            table.insert(E.Segments, createDrawing("Square", { Filled = true, ZIndex = 22, Size = Vector2.new(2, 2) }))
        end

        E.MenuKey_Label = createDrawing("Text", { Text = "Menu Key", Color = C.TextDim, Size = 13, Outline = true, ZIndex = 23, Center = false })
        E.MenuKey_Bg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(25, 25, 25), ZIndex = 22, Size = Vector2.new(60, 16) })
        E.MenuKey_Text = createDrawing("Text", { Text = "[END]", Color = C.TextMain, Size = 13, Outline = true, ZIndex = 23, Center = true })

        local function mkBtn(text)
            return {
                Bg = createDrawing("Square", { Filled = true, Color = Color3.fromRGB(25, 25, 25), ZIndex = 22 }),
                Text = createDrawing("Text", { Text = text, Color = C.TextMain, Size = 13, Outline = true, ZIndex = 23, Center = true })
            }
        end
        E.SaveBtn = mkBtn("Save")
        E.LoadBtn = mkBtn("Load")
        E.ResetBtn = mkBtn("Reset")

        E.StatusText = createDrawing("Text", { Text = "", Color = C.TextDim, Size = 13, Outline = true, ZIndex = 23, Center = true })

        ConfigMenu.TotalHeight = totalHeight
    end

    selfWindow.UI = UI
    selfWindow.Indicator = Indicator
    selfWindow.ConfigMenu = ConfigMenu
end

-- Auto layout
function Window:_computeWindowSizeAndLayout()
    local width = self.Style.Window.Size.X
    local columns = self.Options.Columns
    local divider = (columns == 2 and self.Options.Divider == true)

    local halfW = math.floor(width / 2)
    local colW = (columns == 2) and (halfW - 20) or (width - 20)
    local colX1 = self.UI.Position.X + LAYOUT.PaddingX
    local colX2 = self.UI.Position.X + halfW + LAYOUT.PaddingX

    local yStart = self.UI.Position.Y + LAYOUT.ContentTopY
    local colY = { yStart, yStart }
    local colMaxY = yStart

    -- Compute per-control rects
    for _, ctrl in ipairs(self.Controls) do
        local col = 1
        if columns == 2 and type(ctrl.Column) == "number" and (ctrl.Column == 1 or ctrl.Column == 2) then
            col = ctrl.Column
        end

        local x = (col == 1) and colX1 or colX2
        local y = colY[col]
        local h = 0

        if ctrl.Type == "Section" then
            h = LAYOUT.SectionHeight
            ctrl._rect = { x = x, y = y, w = colW, h = h }
            colY[col] = colY[col] + h + 6

        elseif ctrl.Type == "Slider" then
            h = LAYOUT.SliderHeight
            ctrl._rect = { x = x, y = y, w = colW, h = h }
            colY[col] = colY[col] + h

        elseif ctrl.Type == "Toggle" or ctrl.Type == "Button" or ctrl.Type == "Dropdown" then
            h = LAYOUT.RowHeight
            ctrl._rect = { x = x, y = y, w = colW, h = h }
            colY[col] = colY[col] + h

            if ctrl.Type == "Dropdown" and ctrl.Open then
                local visibleCount = math.min(ctrl.MaxVisible, #ctrl.Options)
                local extra = (visibleCount * LAYOUT.ItemHeight) + 6
                colY[col] = colY[col] + extra
                ctrl._extra = extra
            else
                ctrl._extra = 0
            end
        end

        if colY[col] > colMaxY then colMaxY = colY[col] end
    end

    local contentHeight = colMaxY - (self.UI.Position.Y + LAYOUT.ContentTopY)
    local height = LAYOUT.ContentTopY + contentHeight + LAYOUT.FooterHeight
    self.UI.Size = Vector2.new(width, height)

    self._layout = {
        width = width,
        height = height,
        columns = columns,
        divider = divider,
        colW = colW,
        colX1 = colX1,
        colX2 = colX2
    }

    return width, height
end

-- Initialization
function Window:_initIfNeeded()
    if self._initialized and not self._needsRebuild then return end

    if self._initialized and self._needsRebuild then
        self.UI:_destroy()
        self.Indicator:_destroy()
        self.ConfigMenu:_destroy()
        self._initialized = false
        self._needsRebuild = false
    end

    self:_buildPanels()

    self.UI.Position = self.Style.Window.StartPos
    self:_computeWindowSizeAndLayout()

    if not self._positionLocked then
        pcall(function()
            local cam = Workspace.CurrentCamera
            if cam and cam.ViewportSize then
                local screenW = cam.ViewportSize.X
                local screenH = cam.ViewportSize.Y
                local menuW = self.UI.Size.X
                local menuH = self.UI.Size.Y
                self.UI.Position = Vector2.new((screenW - menuW) / 2, (screenH - menuH) / 2)
            end
        end)
    end

    self:_computeWindowSizeAndLayout()

    self.UI:InitFrame()
    self.UI:BuildControls()
    self.Indicator:Init()
    self.ConfigMenu:Init()


    self.UI:SetVisible(self.Config.UIEnabled)
    self.ConfigMenu:SetVisible(self.Config.UIEnabled)
    self.Indicator:SetVisible(self.Config.IndicatorEnabled)

    self._initialized = true
    self._layoutDirty = true
end

-- Input / interaction
function Window:_handleBindingCaptureForControl(ctrl)
    -- Binding capture mode for toggle keybinds.
    if self.UI.BindingDebounce then
        if not ismouse1pressed() then self.UI.BindingDebounce = false end
        return
    end

    local pressedKey = nil
    for i = 1, 255 do
        if iskeypressed(i) then pressedKey = i; break end
    end
    if ismouse1pressed() then pressedKey = 0x01 end

    if pressedKey then
        -- ESC or M1 cancels/clears bind
        if pressedKey == 0x1B or pressedKey == 0x01 then
            ctrl.Bind = nil
        else
            ctrl.Bind = pressedKey
        end

        self.UI.BindingMode = false
        self.UI.BindingTarget = nil
        self.UI.BindingDebounce = true

        self:_markLayoutDirty()
        if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value, ctrl.Bind) end
    end
end

function Window:_updateMainUIInteraction(mousePos, m1, m1Click)
    if not self.Config.UIEnabled then return end

    local UI = self.UI
    local size = UI.Size
    local pos = UI.Position

    -- Dragging main window (header area)
    local headerRect = { x = pos.X, y = pos.Y, w = size.X, h = LAYOUT.TopDividerY }
    if m1Click and isInRect(mousePos, headerRect.x, headerRect.y, headerRect.w, headerRect.h) then
        -- Prevent drag conflicts with other panels
        if not self.ConfigMenu.Drag.IsDragging and not self.Indicator.Drag.IsDragging then
            UI.Drag.IsDragging = true
            UI.Drag.StartMouse = mousePos
            UI.Drag.StartWindow = pos
        end
    end
    if UI.Drag.IsDragging then
        if m1 then
            local delta = mousePos - UI.Drag.StartMouse
            UI.Position = UI.Drag.StartWindow + delta
            self:_markLayoutDirty()
        else
            UI.Drag.IsDragging = false
        end
    end

    -- If we're in keybind capture mode, we only capture and skip other clicks.
    if UI.BindingMode and UI.BindingTarget then
        local targetCtrl = nil
        for _, c in ipairs(self.Controls) do
            if c.Type == "Toggle" and c.Id == UI.BindingTarget then targetCtrl = c break end
        end
        if targetCtrl then
            self:_handleBindingCaptureForControl(targetCtrl)
        else
            UI.BindingMode = false
            UI.BindingTarget = nil
            UI.BindingDebounce = false
        end
        return
    end

    UI.SliderState.Hovered = nil

    if UI.SliderState.Active then
        local ctrl = UI.SliderState.Active
        if not m1 then
            UI.SliderState.Active = nil
        else
            local r = ctrl._barRect
            if r then
                local pct = Math.Clamp((mousePos.X - r.x) / r.w, 0, 1)
                local raw = ctrl.Min + (ctrl.Max - ctrl.Min) * pct
                local snapped = Math.RoundStep(raw, ctrl.Step)
                snapped = Math.Clamp(snapped, ctrl.Min, ctrl.Max)

                if snapped ~= ctrl.Value then
                    ctrl.Value = snapped
                    if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value) end
                end
            end
        end
    end

    if UI.ScrollbarState.Active then
        local ctrl = UI.ScrollbarState.Active
        if not m1 then
            UI.ScrollbarState.Active = nil
            UI.ScrollbarState.StartMouseY = nil
            UI.ScrollbarState.StartIndex = nil
        else
            local trackR = ctrl._trackRect
            if trackR and trackR.h > 0 then
                local maxStart = math.max(1, #ctrl.Options - ctrl.MaxVisible + 1)
                local deltaY = mousePos.Y - UI.ScrollbarState.StartMouseY
                local pixelsPerStep = trackR.h / math.max(1, maxStart - 1)
                local indexDelta = math.floor((deltaY / pixelsPerStep) + 0.5)
                local newIndex = Math.Clamp(UI.ScrollbarState.StartIndex + indexDelta, 1, maxStart)
                if newIndex ~= ctrl.ScrollIndex then
                    ctrl.ScrollIndex = newIndex
                    self:_markLayoutDirty()
                end
            end
        end
    end

    
local anyDropdownOpen = false
for _, ctrl in ipairs(self.Controls) do
    if ctrl.Type == "Dropdown" and ctrl.Open then
        anyDropdownOpen = true
        break
    end
end

-- When a dropdown is open its list captures clicks first to prevent pass-through.
if m1Click and anyDropdownOpen then
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Type == "Dropdown" and ctrl.Open then
            local listR = ctrl._listRect
            if listR and isInRect(mousePos, listR.x, listR.y, listR.w, listR.h) then
                if ctrl._thumbRect and isInRect(mousePos, ctrl._thumbRect.x, ctrl._thumbRect.y, ctrl._thumbRect.w, ctrl._thumbRect.h) then
                    UI.ScrollbarState.Active = ctrl
                    UI.ScrollbarState.StartMouseY = mousePos.Y
                    UI.ScrollbarState.StartIndex = ctrl.ScrollIndex
                    return
                end

                local inTrack = ctrl._trackRect and isInRect(mousePos, ctrl._trackRect.x, ctrl._trackRect.y, ctrl._trackRect.w, ctrl._trackRect.h)
                if not inTrack then
                    local visibleCount = math.min(ctrl.MaxVisible, #ctrl.Options)
                    for i = 1, visibleCount do
                        local optIndex = ctrl.ScrollIndex + (i - 1)
                        local itemRect = ctrl._itemRects and ctrl._itemRects[i]
                        if itemRect and optIndex <= #ctrl.Options and isInRect(mousePos, itemRect.x, itemRect.y, itemRect.w, itemRect.h) then
                            local newVal = ctrl.Options[optIndex]
                            if newVal ~= ctrl.Value then
                                ctrl.Value = newVal
                                if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value) end
                            end
                            ctrl.Open = false
                            self:_markLayoutDirty()
                            return
                        end
                    end
                end

                return
            end
        end
    end

    local clickedOnOpenDropdown = false
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Type == "Dropdown" and ctrl.Open then
            local rowR = ctrl._rect
            local listR = ctrl._listRect
            if (rowR and isInRect(mousePos, rowR.x, rowR.y, rowR.w, rowR.h)) or (listR and isInRect(mousePos, listR.x, listR.y, listR.w, listR.h)) then
                clickedOnOpenDropdown = true
                break
            end
        end
    end

    if not clickedOnOpenDropdown then
        for _, ctrl in ipairs(self.Controls) do
            if ctrl.Type == "Dropdown" and ctrl.Open then
                ctrl.Open = false
            end
        end
        self:_markLayoutDirty()
        return
    end
end

for _, ctrl in ipairs(self.Controls) do
    local r = ctrl._rect
    if r then
        if isInRect(mousePos, r.x, r.y, r.w, r.h + (ctrl._extra or 0)) then
            UI.SliderState.Hovered = ctrl.Id
        end

        if m1Click then
            if ctrl.Type == "Slider" then
                -- Slider: clicking on the bar activates drag
                if ctrl._barRect and isInRect(mousePos, ctrl._barRect.x, ctrl._barRect.y, ctrl._barRect.w, ctrl._barRect.h) then
                    UI.SliderState.Active = ctrl
                end

            elseif ctrl.Type == "Toggle" then
                local bindRect = ctrl._bindRect

                    if ctrl.Bindable and bindRect and isInRect(mousePos, bindRect.x, bindRect.y, bindRect.w, bindRect.h) then
                    UI.BindingMode = true
                    UI.BindingTarget = ctrl.Id
                    UI.BindingDebounce = true
                    self:_markLayoutDirty()
                else
                    if isInRect(mousePos, r.x, r.y, r.w, r.h) then
                        ctrl.Value = not ctrl.Value
                        if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value, ctrl.Bind) end
                        self:_markLayoutDirty()
                    end
                end

            elseif ctrl.Type == "Button" then
                if isInRect(mousePos, r.x, r.y, r.w, r.h) then
                    if ctrl.Callback then pcall(ctrl.Callback) end
                    self:_markLayoutDirty()
                end

            elseif ctrl.Type == "Dropdown" then
                if isInRect(mousePos, r.x, r.y, r.w, r.h) then
                    if not ctrl.Open then
                        for _, other in ipairs(self.Controls) do
                            if other.Type == "Dropdown" and other.Open then
                                other.Open = false
                            end
                        end
                    end
                    ctrl.Open = not ctrl.Open
                    self:_markLayoutDirty()
                end
            end
        end
    end
end
end -- close Window:_updateMainUIInteraction

-- Indicator interaction
function Window:_updateIndicatorInteraction(mousePos, m1, m1Click)
    if not self.Config.IndicatorEnabled or not self.Indicator.Visible then return end

    local Ind = self.Indicator
    local pos = Ind.Position

    local height = Ind.LastHeight
    if height <= 0 then height = Ind.HEADER_HEIGHT + 1 + Ind.PADDING + (1 * Ind.FEATURE_HEIGHT) + Ind.PADDING end

    if m1Click and isInRect(mousePos, pos.X, pos.Y, Ind.WIDTH, Ind.HEADER_HEIGHT) then
        if not self.UI.Drag.IsDragging and not self.ConfigMenu.Drag.IsDragging then
            Ind.Drag.IsDragging = true
            Ind.Drag.StartMouse = mousePos
            Ind.Drag.StartWindow = pos
        end
    end

    if Ind.Drag.IsDragging then
        if m1 then
            local delta = mousePos - Ind.Drag.StartMouse
            Ind.Position = Ind.Drag.StartWindow + delta
        else
            Ind.Drag.IsDragging = false
        end
    end
end

-- Config menu interaction
function Window:_updateConfigMenuInteraction(mousePos, m1, m1Click)
    if not self.Config.UIEnabled or not self.ConfigMenu.Visible then return end

    local CM = self.ConfigMenu
    local pos = CM.Position
    local totalH = CM.TotalHeight or (CM.HEADER_HEIGHT + 1 + CM.CONTENT_HEIGHT)

    if m1Click and isInRect(mousePos, pos.X, pos.Y, CM.WIDTH, CM.HEADER_HEIGHT) then
        if not self.UI.Drag.IsDragging and not self.Indicator.Drag.IsDragging then
            CM.Drag.IsDragging = true
            CM.Drag.StartMouse = mousePos
            CM.Drag.StartWindow = pos
        end
    end

    if CM.Drag.IsDragging then
        if m1 then
            local delta = mousePos - CM.Drag.StartMouse
            CM.Position = CM.Drag.StartWindow + delta
        else
            CM.Drag.IsDragging = false
        end
    end

    if CM.BindingMode then
        if CM.BindingDebounce then
            if not m1 then CM.BindingDebounce = false end
            return
        end

        local pressedKey = nil
        for i = 1, 255 do
            if iskeypressed(i) then pressedKey = i; break end
        end
        if ismouse1pressed() then pressedKey = 0x01 end

        if pressedKey then
            -- ESC or M1 cancels bind (does NOT clear UIKey, to avoid locking the user out)
            if pressedKey ~= 0x1B and pressedKey ~= 0x01 then
                self.Config.UIKey = pressedKey
            end
            CM.BindingMode = false
            CM.BindingDebounce = true
            self:_markLayoutDirty()
        end
        return
    end

    -- Click targets
    local E = CM.Elements
    if not E or not E.MenuKey_Bg then return end

    -- Menu key bind box rect
    local bindX = pos.X + CM.WIDTH - 70
    local bindY = pos.Y + CM.HEADER_HEIGHT + 1 + 10
    local bindW, bindH = 60, 16

    if m1Click and isInRect(mousePos, bindX, bindY, bindW, bindH) then
        CM.BindingMode = true
        CM.BindingDebounce = true
        return
    end

    -- Buttons rects
    local btnY = bindY + 24
    local btnW, btnH = 56, 16
    local btnX1 = pos.X + 10
    local btnX2 = btnX1 + btnW + 6
    local btnX3 = btnX2 + btnW + 6

    if m1Click and isInRect(mousePos, btnX1, btnY, btnW, btnH) then
        self:SaveConfig(); return
    end
    if m1Click and isInRect(mousePos, btnX2, btnY, btnW, btnH) then
        self:LoadConfig(); return
    end
    if m1Click and isInRect(mousePos, btnX3, btnY, btnW, btnH) then
        self:ResetConfig(); return
    end
end

function Window:_renderMainUI(statusData)
    local UI = self.UI
    local E = UI.Elements
    local C = self.Style.Colors

    if not self.Config.UIEnabled then
        UI:SetVisible(false)
        return
    end

    -- Recompute size + layout when dirty or if position changed.
    local moved = false
    if not UI.LastPos or UI.LastPos.X ~= UI.Position.X or UI.LastPos.Y ~= UI.Position.Y then
        moved = true
        UI.LastPos = UI.Position
        self:_markLayoutDirty()
    end

    if self._layoutDirty then
        self:_computeWindowSizeAndLayout()
    end

    local pos = UI.Position
    local size = UI.Size

    E.MainBg.Position = pos; E.MainBg.Size = size; E.MainBg.Visible = true
    E.HeaderBg.Position = Vector2.new(pos.X, pos.Y + 2); E.HeaderBg.Size = Vector2.new(size.X, LAYOUT.HeaderHeight); E.HeaderBg.Visible = true
    E.Border.Position = pos; E.Border.Size = size; E.Border.Visible = true
    E.Divider.Position = Vector2.new(pos.X, pos.Y + LAYOUT.TopDividerY); E.Divider.Size = Vector2.new(size.X, 1); E.Divider.Visible = true

    E.Title.Text = self.Style.Window.Title
    E.Title.Position = Vector2.new(pos.X + 6, pos.Y + 4); E.Title.Visible = true

    local sText = "IDLE"
    local sColor = self.Style.Colors.Status.Idle
    if type(statusData) == "table" then
        if type(statusData.Text) == "string" then sText = statusData.Text end
        if typeof(statusData.Color) == "Color3" then sColor = statusData.Color end
    end
    E.StatusValue.Text = sText
    E.StatusValue.Color = sColor
    E.StatusValue.Position = Vector2.new(pos.X + size.X - 40, pos.Y + 10)
    E.StatusValue.Visible = true

    if self._layout.columns == 2 and self._layout.divider then
        local x = pos.X + math.floor(size.X / 2)
        E.VerticalLine.From = Vector2.new(x, pos.Y + LAYOUT.ContentTopY)
        E.VerticalLine.To = Vector2.new(x, pos.Y + size.Y - LAYOUT.FooterHeight)
        E.VerticalLine.Visible = true
    else
        E.VerticalLine.Visible = false
    end

    local time = os.clock() * 2.0
    for i, seg in ipairs(E.Segments) do
        local offset = ((i - 1) / 100) * 6.0
        local t = time + offset
        local r, g, b = (math.sin(t)*0.5)+0.5, (math.sin(t+2.094)*0.5)+0.5, (math.sin(t+4.188)*0.5)+0.5
        seg.Color = Color3.new(r, g, b)
        seg.Position = Vector2.new(pos.X + (i-1)*(size.X/100), pos.Y)
        seg.Size = Vector2.new(math.ceil(size.X/100), LAYOUT.SegHeight)
        seg.Visible = true
    end

    for _, ctrl in ipairs(self.Controls) do
        local pack = UI.ControlsDraw[ctrl.Id]
        local r = ctrl._rect
        if pack and r then
            if ctrl.Type == "Section" then
                pack.Text.Position = Vector2.new(r.x, r.y)
                pack.Text.Visible = true

            elseif ctrl.Type == "Slider" then
                local yPos = r.y
                local xPos = r.x
                local width = r.w

                pack.Label.Position = Vector2.new(xPos, yPos)
                pack.Label.Visible = true

                if ctrl.Integer then
                    pack.Value.Text = string.format("%d", ctrl.Value)
                else
                    pack.Value.Text = string.format("%.2f", ctrl.Value)
                end
                pack.Value.Position = Vector2.new(xPos + width - 30, yPos)
                pack.Value.Visible = true

                pack.BarBg.Position = Vector2.new(xPos, yPos + 18)
                pack.BarBg.Size = Vector2.new(width, 6)
                pack.BarBg.Visible = true

                local percent = (ctrl.Value - ctrl.Min) / (ctrl.Max - ctrl.Min)
                pack.BarFill.Position = Vector2.new(xPos, yPos + 18)
                pack.BarFill.Size = Vector2.new(width * percent, 6)
                pack.BarFill.Visible = true

                ctrl._barRect = { x = xPos, y = yPos + 18, w = width, h = 6 }

            elseif ctrl.Type == "Toggle" then
                local yPos = r.y + 2
                local xPos = r.x
                local width = r.w

                pack.Label.Position = Vector2.new(xPos, r.y)
                pack.Label.Visible = true

                local boxX = xPos + width - 15
                pack.BoxOut.Position = Vector2.new(boxX, yPos)
                pack.BoxOut.Visible = true
                pack.BoxFill.Position = Vector2.new(boxX + 2, yPos + 2)
                pack.BoxFill.Visible = (ctrl.Value == true)

                if ctrl.Bindable then
                    local btnX = xPos + width - 15 - 40 - 8
                    pack.BindBg.Position = Vector2.new(btnX, yPos)
                    pack.BindBg.Size = Vector2.new(40, 16)
                    pack.BindBg.Visible = true

                    pack.BindText.Position = Vector2.new(btnX + 20, yPos + 6)
                    pack.BindText.Visible = true

                    if UI.BindingMode and UI.BindingTarget == ctrl.Id then
                        pack.BindText.Text = "[...]"
                        pack.BindText.Color = C.Accent
                    else
                        pack.BindText.Text = "[" .. GetKeyName(ctrl.Bind) .. "]"
                        pack.BindText.Color = C.TextDim
                    end

                    ctrl._bindRect = { x = btnX, y = yPos, w = 40, h = 16 }
                else
                    ctrl._bindRect = nil
                end

            elseif ctrl.Type == "Button" then
                pack.Bg.Position = Vector2.new(r.x, r.y + 2)
                pack.Bg.Size = Vector2.new(r.w, 16)
                pack.Bg.Visible = true

                pack.Text.Position = Vector2.new(r.x + (r.w/2), r.y + 8)
                pack.Text.Visible = true

            elseif ctrl.Type == "Dropdown" then
                local yPos = r.y
                local xPos = r.x
                local width = r.w

                pack.Label.Position = Vector2.new(xPos, yPos)
                pack.Label.Visible = true

                -- Selection box on the right
                local boxW = 80
                local boxX = xPos + width - boxW
                local boxY = yPos + 2

                pack.ValueBg.Position = Vector2.new(boxX, boxY)
                pack.ValueBg.Size = Vector2.new(boxW, 16)
                pack.ValueBg.Visible = true

                pack.ValueText.Text = tostring(ctrl.Value or "")
                pack.ValueText.Position = Vector2.new(boxX + (boxW/2), boxY + 6)
                pack.ValueText.Visible = true

                -- Open list (expands layout instead of overlay)
                if ctrl.Open and #ctrl.Options > 0 then
                    local visibleCount = math.min(ctrl.MaxVisible, #ctrl.Options)
                    local listH = visibleCount * LAYOUT.ItemHeight + 4
                    local listX = xPos
                    local listY = yPos + LAYOUT.RowHeight
                    local listW = width

                    pack.ListBg.Position = Vector2.new(listX, listY)
                    pack.ListBg.Size = Vector2.new(listW, listH)
                    pack.ListBg.Visible = true

                    pack.ListBorder.Position = Vector2.new(listX, listY)
                    pack.ListBorder.Size = Vector2.new(listW, listH)
                    pack.ListBorder.Visible = true

                    ctrl._listRect = { x = listX, y = listY, w = listW, h = listH }
                    ctrl._itemRects = {}

                    -- Items
                    local startIdx = Math.Clamp(ctrl.ScrollIndex, 1, math.max(1, #ctrl.Options - visibleCount + 1))
                    ctrl.ScrollIndex = startIdx

                    for i = 1, ctrl.MaxVisible do
                        if i <= visibleCount then
                            local optIndex = startIdx + (i - 1)
                            local opt = ctrl.Options[optIndex]

                            local itemY = listY + 2 + (i - 1) * LAYOUT.ItemHeight
                            pack.ItemBgs[i].Position = Vector2.new(listX + 2, itemY)
                            pack.ItemBgs[i].Size = Vector2.new(listW - 4, LAYOUT.ItemHeight)
                            pack.ItemBgs[i].Visible = true

                            pack.Items[i].Text = tostring(opt or "")
                            pack.Items[i].Position = Vector2.new(listX + 6, itemY + 1)
                            pack.Items[i].Visible = true

                            ctrl._itemRects[i] = { x = listX + 2, y = itemY, w = listW - 4, h = LAYOUT.ItemHeight }
                        else
                            pack.ItemBgs[i].Visible = false
                            pack.Items[i].Visible = false
                        end
                    end

                    -- Scrollbar
                    local needsScroll = (#ctrl.Options > ctrl.MaxVisible)
                    if needsScroll then
                        local SCROLLBAR_W = 6
                        local trackX = listX + listW - SCROLLBAR_W - 2
                        local trackY = listY + 2
                        local trackH = listH - 4

                        pack.ScrollTrack.Position = Vector2.new(trackX, trackY)
                        pack.ScrollTrack.Size = Vector2.new(SCROLLBAR_W, trackH)
                        pack.ScrollTrack.Visible = true

                        local maxStart = math.max(1, #ctrl.Options - ctrl.MaxVisible + 1)
                        local thumbH = math.max(16, math.floor(trackH * (ctrl.MaxVisible / #ctrl.Options)))
                        local thumbTravel = trackH - thumbH
                        local thumbT = (ctrl.ScrollIndex - 1) / math.max(1, maxStart - 1)
                        local thumbY = trackY + math.floor(thumbT * thumbTravel)

                        pack.ScrollThumb.Position = Vector2.new(trackX, thumbY)
                        pack.ScrollThumb.Size = Vector2.new(SCROLLBAR_W, thumbH)
                        if UI.ScrollbarState.Active == ctrl then
                            pack.ScrollThumb.Color = Color3.fromRGB(140, 140, 140)
                        else
                            pack.ScrollThumb.Color = Color3.fromRGB(80, 80, 80)
                        end
                        pack.ScrollThumb.Visible = true

                        ctrl._trackRect = { x = trackX, y = trackY, w = SCROLLBAR_W, h = trackH }
                        ctrl._thumbRect = { x = trackX, y = thumbY, w = SCROLLBAR_W, h = thumbH }

                        for i = 1, ctrl.MaxVisible do
                            if pack.ItemBgs[i] and pack.ItemBgs[i].Visible then
                                pack.ItemBgs[i].Size = Vector2.new(listW - SCROLLBAR_W - 6, LAYOUT.ItemHeight)
                            end
                        end
                    else
                        pack.ScrollTrack.Visible = false
                        pack.ScrollThumb.Visible = false
                        ctrl._trackRect = nil
                        ctrl._thumbRect = nil
                    end
                else
                    pack.ListBg.Visible = false
                    pack.ListBorder.Visible = false
                    for i = 1, ctrl.MaxVisible do
                        if pack.ItemBgs[i] then pack.ItemBgs[i].Visible = false end
                        if pack.Items[i] then pack.Items[i].Visible = false end
                    end
                    pack.ScrollTrack.Visible = false
                    pack.ScrollThumb.Visible = false
                    ctrl._listRect = nil
                    ctrl._itemRects = nil
                    ctrl._trackRect = nil
                    ctrl._thumbRect = nil
                end
            end
        end
    end

    local descText = self.Style.Window.Title
    if UI.BindingMode then
        descText = "Press key to bind (M1/ESC to clear)"
    elseif UI.SliderState.Hovered then
        for _, ctrl in ipairs(self.Controls) do
            if ctrl.Id == UI.SliderState.Hovered then
                if ctrl.Description and ctrl.Description ~= "" then descText = ctrl.Description
                else descText = ctrl.Text or self.Style.Window.Title end
                break
            end
        end
    elseif UI.SliderState.Active then
        local ctrl = UI.SliderState.Active
        if ctrl and ctrl.Description and ctrl.Description ~= "" then descText = ctrl.Description end
    end

    E.Description.Text = descText
    E.Description.Position = Vector2.new(pos.X + (size.X / 2), pos.Y + size.Y - 12)
    E.Description.Visible = true

    self._layoutDirty = false
end

function Window:_renderIndicator()
    local Ind = self.Indicator
    local E = Ind.Elements
    local C = self.Style.Colors

    if not self.Config.IndicatorEnabled or not Ind.Visible then
        Ind:SetVisible(false)
        return
    end
    Ind:SetVisible(true)

    local pos = Ind.Position

    local features = {}
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Type == "Toggle" and ctrl.ShowInIndicator and ctrl.Value == true and ctrl.Bind ~= nil then
            table.insert(features, { Label = ctrl.Text or ctrl.Id })
        end
    end
    if #features == 0 then
        table.insert(features, { Label = "No binds active" })
    end

    local height = Ind.HEADER_HEIGHT + 1 + Ind.PADDING + (#features * Ind.FEATURE_HEIGHT) + Ind.PADDING
    Ind.LastHeight = height

    local moved = false
    if not Ind.LastPos or Ind.LastPos.X ~= pos.X or Ind.LastPos.Y ~= pos.Y or Ind.LastHeight ~= height then
        moved = true
        Ind.LastPos = pos
    end

    E.MainBg.Position = pos; E.MainBg.Size = Vector2.new(Ind.WIDTH, height); E.MainBg.Visible = true
    E.HeaderBg.Position = Vector2.new(pos.X, pos.Y + 2); E.HeaderBg.Size = Vector2.new(Ind.WIDTH, Ind.HEADER_HEIGHT - 2); E.HeaderBg.Visible = true
    E.Border.Position = pos; E.Border.Size = Vector2.new(Ind.WIDTH, height); E.Border.Visible = true
    E.Divider.Position = Vector2.new(pos.X, pos.Y + Ind.HEADER_HEIGHT); E.Divider.Size = Vector2.new(Ind.WIDTH, 1); E.Divider.Visible = true
    E.Title.Position = Vector2.new(pos.X + 6, pos.Y + 4); E.Title.Visible = true

    -- Rainbow segments
    local time = os.clock() * 2.0
    for i, seg in ipairs(E.Segments) do
        local offset = ((i - 1) / Ind.SEGMENT_COUNT) * 6.0
        local t = time + offset
        local r, g, b = (math.sin(t)*0.5)+0.5, (math.sin(t+2.094)*0.5)+0.5, (math.sin(t+4.188)*0.5)+0.5
        seg.Color = Color3.new(r, g, b)
        seg.Position = Vector2.new(pos.X + (i-1)*(Ind.WIDTH/Ind.SEGMENT_COUNT), pos.Y)
        seg.Size = Vector2.new(math.ceil(Ind.WIDTH/Ind.SEGMENT_COUNT), 2)
        seg.Visible = true
    end

    -- Feature rows
    local startY = pos.Y + Ind.HEADER_HEIGHT + 1 + Ind.PADDING
    for i = 1, 32 do
        local label = E.FeatureLabels[i]
        if features[i] then
            label.Text = features[i].Label
            label.Position = Vector2.new(pos.X + 6, startY + (i - 1) * Ind.FEATURE_HEIGHT)
            label.Visible = true
        else
            label.Visible = false
        end
    end
end

function Window:_renderConfigMenu()
    local CM = self.ConfigMenu
    local E = CM.Elements
    local C = self.Style.Colors

    if not self.Config.UIEnabled or not CM.Visible then
        CM:SetVisible(false)
        return
    end
    CM:SetVisible(true)

    local pos = CM.Position
    local height = CM.TotalHeight or (CM.HEADER_HEIGHT + 1 + CM.CONTENT_HEIGHT)

    E.MainBg.Position = pos; E.MainBg.Size = Vector2.new(CM.WIDTH, height); E.MainBg.Visible = true
    E.HeaderBg.Position = Vector2.new(pos.X, pos.Y + 2); E.HeaderBg.Size = Vector2.new(CM.WIDTH, CM.HEADER_HEIGHT - 2); E.HeaderBg.Visible = true
    E.Border.Position = pos; E.Border.Size = Vector2.new(CM.WIDTH, height); E.Border.Visible = true
    E.Divider.Position = Vector2.new(pos.X, pos.Y + CM.HEADER_HEIGHT); E.Divider.Size = Vector2.new(CM.WIDTH, 1); E.Divider.Visible = true
    E.Title.Position = Vector2.new(pos.X + 6, pos.Y + 4); E.Title.Visible = true

    -- Rainbow segments
    local time = os.clock() * 2.0
    for i, seg in ipairs(E.Segments) do
        local offset = ((i - 1) / CM.SEGMENT_COUNT) * 6.0
        local t = time + offset
        local r, g, b = (math.sin(t)*0.5)+0.5, (math.sin(t+2.094)*0.5)+0.5, (math.sin(t+4.188)*0.5)+0.5
        seg.Color = Color3.new(r, g, b)
        seg.Position = Vector2.new(pos.X + (i-1)*(CM.WIDTH/CM.SEGMENT_COUNT), pos.Y)
        seg.Size = Vector2.new(math.ceil(CM.WIDTH/CM.SEGMENT_COUNT), 2)
        seg.Visible = true
    end

    local rowY = pos.Y + CM.HEADER_HEIGHT + 1 + 10
    E.MenuKey_Label.Position = Vector2.new(pos.X + 10, rowY - 2); E.MenuKey_Label.Visible = true

    local bindX = pos.X + CM.WIDTH - 70
    local bindY = rowY
    E.MenuKey_Bg.Position = Vector2.new(bindX, bindY)
    E.MenuKey_Bg.Size = Vector2.new(60, 16)
    E.MenuKey_Bg.Visible = true

    if CM.BindingMode then
        E.MenuKey_Text.Text = "[...]"
        E.MenuKey_Text.Color = C.Accent
    else
        E.MenuKey_Text.Text = "[" .. GetKeyName(self.Config.UIKey) .. "]"
        E.MenuKey_Text.Color = C.TextMain
    end
    E.MenuKey_Text.Position = Vector2.new(bindX + 30, bindY + 6)
    E.MenuKey_Text.Visible = true

    local btnY = bindY + 24
    local btnW, btnH = 56, 16
    local btnX1 = pos.X + 10
    local btnX2 = btnX1 + btnW + 6
    local btnX3 = btnX2 + btnW + 6

    local function placeBtn(btn, x, y)
        btn.Bg.Position = Vector2.new(x, y)
        btn.Bg.Size = Vector2.new(btnW, btnH)
        btn.Bg.Visible = true
        btn.Text.Position = Vector2.new(x + (btnW/2), y + 6)
        btn.Text.Visible = true
    end
    placeBtn(E.SaveBtn, btnX1, btnY)
    placeBtn(E.LoadBtn, btnX2, btnY)
    placeBtn(E.ResetBtn, btnX3, btnY)

    if self.ConfigSystem.StatusUntil and os.clock() > self.ConfigSystem.StatusUntil then
        self.ConfigSystem.StatusText = ""
        self.ConfigSystem.StatusUntil = nil
    end

    local statusText = self.ConfigSystem.StatusText or ""
    E.StatusText.Text = statusText
    E.StatusText.Color = self.ConfigSystem.StatusColor or C.TextDim
    E.StatusText.Position = Vector2.new(pos.X + CM.WIDTH - 40, pos.Y + 10)
    E.StatusText.Visible = (statusText ~= "")
end

-- Public API
function Window:SetStatus(text, color)
    self.Status.Text = text or "IDLE"
    self.Status.Color = color or self.Style.Colors.Status.Idle
end


function Window:Get(id)
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Id == id then
            if ctrl.Type == "Toggle" or ctrl.Type == "Slider" or ctrl.Type == "Dropdown" then
                return ctrl.Value, ctrl.Bind
            end
            return nil
        end
    end
    return nil
end

function Window:Set(id, value)
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Id == id then
            if ctrl.Type == "Toggle" then
                ctrl.Value = (value == true)
                if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value, ctrl.Bind) end
                self:_markLayoutDirty()
                return true
            elseif ctrl.Type == "Slider" then
                if type(value) == "number" then
                    ctrl.Value = Math.Clamp(Math.RoundStep(value, ctrl.Step), ctrl.Min, ctrl.Max)
                    if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value) end
                    self:_markLayoutDirty()
                    return true
                end
            elseif ctrl.Type == "Dropdown" then
                if type(value) == "string" then
                    ctrl.Value = value
                    if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value) end
                    self:_markLayoutDirty()
                    return true
                end
            end
            return false
        end
    end
    return false
end

function Window:SetBind(id, keycode)
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Id == id and ctrl.Type == "Toggle" and ctrl.Bindable then
            ctrl.Bind = keycode
            self:_markLayoutDirty()
            return true
        end
    end
    return false
end

function Window:Step(statusData)
    self:_initIfNeeded()

    local mousePos = getSafeMousePosition()
    local m1 = ismouse1pressed()
    local m1Click = (m1 and not self.UI.Input.LastM1)

    local uiKeyPressed = iskeypressed(self.Config.UIKey)
    if uiKeyPressed and not self.UI.Input.LastUIKey and not self.ConfigMenu.BindingMode then
        self.Config.UIEnabled = not self.Config.UIEnabled
        self.UI:SetVisible(self.Config.UIEnabled)
        self.ConfigMenu:SetVisible(self.Config.UIEnabled)
        -- Indicator stays independent (like original)
    end
    self.UI.Input.LastUIKey = uiKeyPressed

    -- Toggle binds
    for _, ctrl in ipairs(self.Controls) do
        if ctrl.Type == "Toggle" and ctrl.Bindable and ctrl.Bind ~= nil then
            local pressed = iskeypressed(ctrl.Bind)
            if pressed and not self.UI.Input.BindStates[ctrl.Id] then
                ctrl.Value = not ctrl.Value
                if ctrl.Callback then pcall(ctrl.Callback, ctrl.Value, ctrl.Bind) end
                self:_markLayoutDirty()
            end
            self.UI.Input.BindStates[ctrl.Id] = pressed
        end
    end

    self:_updateMainUIInteraction(mousePos, m1, m1Click)
    self:_updateIndicatorInteraction(mousePos, m1, m1Click)
    self:_updateConfigMenuInteraction(mousePos, m1, m1Click)

    self:_renderMainUI(statusData or self.Status)
    self:_renderIndicator()
    self:_renderConfigMenu()

    self.UI.Input.LastM1 = m1
end

function Window:Destroy()
    if not self._initialized then return end
    self.UI:_destroy()
    self.Indicator:_destroy()
    self.ConfigMenu:_destroy()
    self._initialized = false
end


function Library:CreateWindow(opts)
    opts = opts or {}

    local w = setmetatable({}, Window)
    w.Style = deepCopy(DefaultStyle)

    w.Options = {
        Columns = (opts.Columns == 2) and 2 or 1,
        Divider = (opts.Columns == 2) and (opts.Divider ~= false) or false
    }

    if type(opts.Title) == "string" then w.Style.Window.Title = opts.Title end
    if type(opts.Width) == "number" then w.Style.Window.Size = Vector2.new(opts.Width, w.Style.Window.Size.Y) end
    if type(opts.Theme) == "table" then
        -- Shallow merge user theme into the default theme (safe: only overwrite provided fields)
        for k, v in pairs(opts.Theme) do
            if type(v) == "table" and type(w.Style[k]) == "table" then
                for kk, vv in pairs(v) do w.Style[k][kk] = vv end
            else
                w.Style[k] = v
            end
        end
    end

    w.Controls = {}
    w.Status = { Text = "IDLE", Color = w.Style.Colors.Status.Idle }

    w.Config = {
        UIKey = (type(opts.UIKey) == "number") and opts.UIKey or 0x23,   -- END
        UIEnabled = true,
        IndicatorEnabled = true
    }

    w.ConfigSystem = {
        Filename = (type(opts.ConfigFile) == "string") and opts.ConfigFile or "wabi_ui_config.json",
        StatusText = "",
        StatusColor = w.Style.Colors.TextDim,
        StatusUntil = nil
    }

    w.Defaults = {
        UIKey = w.Config.UIKey,
        UIEnabled = w.Config.UIEnabled,
        IndicatorEnabled = w.Config.IndicatorEnabled,
        Toggles = {},
        Sliders = {},
        Dropdowns = {},
        Binds = {}
    }

    if typeof(opts.StartPos) == "Vector2" then
        w.Style.Window.StartPos = opts.StartPos
        w._positionLocked = true
    end

    w._initialized = false
    w._layoutDirty = true
    w._needsRebuild = false

    if opts.BuiltInIndicatorToggle == true then
        w:AddToggle("__indicator", {
            Text = "Indicator",
            Description = "Toggle the indicator panel",
            Default = true,
            Keybind = true,
            ShowInIndicator = false, -- prevent the indicator listing itself
            Callback = function(on)
                w.Config.IndicatorEnabled = (on == true)
                if w.Indicator then w.Indicator:SetVisible(w.Config.IndicatorEnabled) end
            end
        })
    end

    return w
end

local ExportedLibrary = setmetatable(Library, Library)

-- Export as return value and as globals (WabiSabiUILibrary / Library)
local __env = (type(getgenv) == "function" and getgenv()) or _G
__env.Library = ExportedLibrary
__env.WabiSabiUILibrary = ExportedLibrary

return ExportedLibrary
