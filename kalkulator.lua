script_name("Kalkulator Medis")
script_author("Yohanez")

require 'lib.sampfuncs'
require 'lib.moonloader'
local ffi = require 'ffi'
local mimgui = require 'lib.mimgui'
local theme = require 'lib.mimgui_theme'

-- ======================
-- VARIABEL
-- ======================
local showCalculatorWindow = mimgui.new.bool(false)
local calcDisplay = mimgui.new.char[256]("0")
local calcPrevious = mimgui.new.int(0)
local calcOperation = ""
local calcNewNumber = mimgui.new.bool(true)

-- ======================
-- FUNCTION
-- ======================
function openCalculator()
    showCalculatorWindow[0] = true
end

function clearAll()
    ffi.copy(calcDisplay, "0")
    calcPrevious[0] = 0
    calcOperation = ""
    calcNewNumber[0] = true
end

function inputNumber(num)
    local current = ffi.string(calcDisplay)

    if calcNewNumber[0] then
        ffi.copy(calcDisplay, num)
        calcNewNumber[0] = false
    else
        if current == "0" then
            ffi.copy(calcDisplay, num)
        else
            ffi.copy(calcDisplay, current .. num)
        end
    end
end

function setOperation(op)
    calcPrevious[0] = tonumber(ffi.string(calcDisplay))
    calcOperation = op
    calcNewNumber[0] = true
end

function calculate()
    local current = tonumber(ffi.string(calcDisplay))
    local result = 0

    if calcOperation == "+" then
        result = calcPrevious[0] + current
    elseif calcOperation == "-" then
        result = calcPrevious[0] - current
    elseif calcOperation == "*" then
        result = calcPrevious[0] * current
    elseif calcOperation == "/" then
        if current ~= 0 then
            result = calcPrevious[0] / current
        end
    end

    ffi.copy(calcDisplay, tostring(result))
    calcOperation = ""
    calcNewNumber[0] = true
end

-- ======================
-- GUI
-- ======================
mimgui.OnFrame(function() return showCalculatorWindow[0] end, function()
    theme.applyDarkModern()
    mimgui.SetNextWindowSize(mimgui.ImVec2(300, 400), mimgui.Cond.FirstUseEver)
    mimgui.Begin("Kalkulator Medis", showCalculatorWindow)
    mimgui.TextDisabled("Author: Yohanez")

    mimgui.InputText("##display", calcDisplay, mimgui.InputTextFlags.ReadOnly)

    -- ROW 1
    if mimgui.Button("7", mimgui.ImVec2(60,40)) then inputNumber("7") end
    mimgui.SameLine()
    if mimgui.Button("8", mimgui.ImVec2(60,40)) then inputNumber("8") end
    mimgui.SameLine()
    if mimgui.Button("9", mimgui.ImVec2(60,40)) then inputNumber("9") end
    mimgui.SameLine()
    if mimgui.Button("/", mimgui.ImVec2(60,40)) then setOperation("/") end

    -- ROW 2
    if mimgui.Button("4", mimgui.ImVec2(60,40)) then inputNumber("4") end
    mimgui.SameLine()
    if mimgui.Button("5", mimgui.ImVec2(60,40)) then inputNumber("5") end
    mimgui.SameLine()
    if mimgui.Button("6", mimgui.ImVec2(60,40)) then inputNumber("6") end
    mimgui.SameLine()
    if mimgui.Button("*", mimgui.ImVec2(60,40)) then setOperation("*") end

    -- ROW 3
    if mimgui.Button("1", mimgui.ImVec2(60,40)) then inputNumber("1") end
    mimgui.SameLine()
    if mimgui.Button("2", mimgui.ImVec2(60,40)) then inputNumber("2") end
    mimgui.SameLine()
    if mimgui.Button("3", mimgui.ImVec2(60,40)) then inputNumber("3") end
    mimgui.SameLine()
    if mimgui.Button("-", mimgui.ImVec2(60,40)) then setOperation("-") end

    -- ROW 4
    if mimgui.Button("0", mimgui.ImVec2(125,40)) then inputNumber("0") end
    mimgui.SameLine()
    if mimgui.Button("=", mimgui.ImVec2(60,40)) then calculate() end
    mimgui.SameLine()
    if mimgui.Button("+", mimgui.ImVec2(60,40)) then setOperation("+") end

    if mimgui.Button("Clear", mimgui.ImVec2(-1,40)) then clearAll() end

    mimgui.End()
end)

-- ======================
-- MAIN (WAJIB!)
-- ======================
function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand('kalkulator', function()
        openCalculator()
    end)

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[Kalkulator] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/kalkulator{FFFFFF} untuk membuka kalkulator", -1)
            break
        end
    end

    while true do
        wait(0)
    end
end