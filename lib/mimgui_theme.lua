-- lib/mimgui_theme.lua
-- Centralized Dark Modern Theme for all mimgui scripts

local mimgui = require "mimgui"
local theme = {}

local applied = false

function theme.applyDarkModern()
    if applied then return end
    applied = true

    local style = mimgui.GetStyle()
    local colors = style.Colors

    -- Modern Rounded Corners
    style.WindowRounding    = 8.0
    style.ChildRounding     = 6.0
    style.FrameRounding     = 5.0
    style.PopupRounding     = 6.0
    style.ScrollbarRounding = 6.0
    style.GrabRounding      = 4.0
    style.TabRounding       = 5.0
    style.WindowBorderSize  = 1.0
    style.FrameBorderSize   = 0.0
    style.ItemSpacing       = mimgui.ImVec2(8, 6)
    style.ItemInnerSpacing  = mimgui.ImVec2(6, 4)

    -- Dark Modern Color Palette
    colors[mimgui.Col.WindowBg]             = mimgui.ImVec4(0.11, 0.11, 0.13, 0.98)
    colors[mimgui.Col.ChildBg]              = mimgui.ImVec4(0.08, 0.08, 0.10, 0.95)
    colors[mimgui.Col.PopupBg]              = mimgui.ImVec4(0.13, 0.13, 0.16, 0.98)
    colors[mimgui.Col.Border]               = mimgui.ImVec4(0.22, 0.22, 0.25, 0.60)
    colors[mimgui.Col.FrameBg]              = mimgui.ImVec4(0.16, 0.16, 0.19, 1.00)
    colors[mimgui.Col.FrameBgHovered]       = mimgui.ImVec4(0.22, 0.22, 0.26, 1.00)
    colors[mimgui.Col.FrameBgActive]        = mimgui.ImVec4(0.28, 0.28, 0.34, 1.00)
    colors[mimgui.Col.TitleBg]              = mimgui.ImVec4(0.09, 0.09, 0.11, 1.00)
    colors[mimgui.Col.TitleBgActive]        = mimgui.ImVec4(0.12, 0.12, 0.15, 1.00)
    colors[mimgui.Col.TitleBgCollapsed]     = mimgui.ImVec4(0.08, 0.08, 0.10, 0.80)
    colors[mimgui.Col.MenuBarBg]            = mimgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    colors[mimgui.Col.ScrollbarBg]          = mimgui.ImVec4(0.08, 0.08, 0.10, 0.50)
    colors[mimgui.Col.ScrollbarGrab]        = mimgui.ImVec4(0.22, 0.24, 0.28, 1.00)
    colors[mimgui.Col.ScrollbarGrabHovered] = mimgui.ImVec4(0.28, 0.32, 0.38, 1.00)
    colors[mimgui.Col.ScrollbarGrabActive]  = mimgui.ImVec4(0.35, 0.40, 0.48, 1.00)
    colors[mimgui.Col.CheckMark]            = mimgui.ImVec4(0.30, 0.60, 0.95, 1.00)
    colors[mimgui.Col.SliderGrab]           = mimgui.ImVec4(0.30, 0.60, 0.95, 1.00)
    colors[mimgui.Col.SliderGrabActive]     = mimgui.ImVec4(0.40, 0.70, 1.00, 1.00)
    colors[mimgui.Col.Button]               = mimgui.ImVec4(0.20, 0.22, 0.26, 1.00)
    colors[mimgui.Col.ButtonHovered]        = mimgui.ImVec4(0.28, 0.32, 0.40, 1.00)
    colors[mimgui.Col.ButtonActive]         = mimgui.ImVec4(0.35, 0.40, 0.50, 1.00)
    colors[mimgui.Col.Header]               = mimgui.ImVec4(0.16, 0.18, 0.22, 1.00)
    colors[mimgui.Col.HeaderHovered]        = mimgui.ImVec4(0.24, 0.28, 0.35, 1.00)
    colors[mimgui.Col.HeaderActive]         = mimgui.ImVec4(0.30, 0.36, 0.45, 1.00)
    colors[mimgui.Col.Separator]            = mimgui.ImVec4(0.22, 0.22, 0.26, 0.80)
    colors[mimgui.Col.Text]                 = mimgui.ImVec4(0.92, 0.92, 0.95, 1.00)
    colors[mimgui.Col.TextDisabled]         = mimgui.ImVec4(0.55, 0.55, 0.60, 1.00)
end

-- Terapkan OnInitialize jika mimgui mendukung OnInitialize
if mimgui.OnInitialize then
    mimgui.OnInitialize(function()
        theme.applyDarkModern()
    end)
end

return theme
