-- AutoFish MoonLoader SA-MP
-- Command: /autofish
-- Off: /autofish off

script_name("AutoFish")
script_author("Arkananta Studio")

require "lib.moonloader"

local sampev = require 'lib.samp.events'

local autofish = false
local fastRetry = false

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("autofish", function(arg)
        arg = tostring(arg)

        if arg == "off" then
            autofish = false
            sampAddChatMessage("{FF0000}[AutoFish] OFF", -1)
            return
        end

        if not autofish then
            autofish = true
            sampAddChatMessage("{00FF00}[AutoFish] ON", -1)
            lua_thread.create(autoFishLoop)
        else
            sampAddChatMessage("{FFFF00}[AutoFish] Sudah aktif!", -1)
        end
    end)

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[AutoFish] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/autofish{FFFFFF} untuk ON | {00FF00}/autofish off{FFFFFF} untuk OFF", -1)
            break
        end
    end

    while true do
        wait(0)
    end
end

function autoFishLoop()
    while autofish do

        -- Tekan tombol Y
        setVirtualKeyDown(0x59, true) -- Y
        wait(100)
        setVirtualKeyDown(0x59, false)

        -- Kalau ada response ikan besar
        if fastRetry then
            fastRetry = false
            wait(900) -- jeda 1 detik
        else
            wait(8200) -- loading normal 10 detik
        end
    end
end

-- Detect chat server
function sampev.onServerMessage(color, text)

    if autofish then
        if text:find("Pancingan mu terbawa ikan besar dan jatuh ke dasar laut") then
            fastRetry = true
        end
    end
end