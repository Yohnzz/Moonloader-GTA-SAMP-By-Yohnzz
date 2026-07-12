script_name("Voice Smart Fix")
script_author("Arkananta Studio")

require 'lib.moonloader'
local sampev = require 'lib.samp.events'

local lastActivity = os.clock()
local warningShown = false

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("rvoice", manualRefresh)

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[Voice Smart Fix] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/rvoice{FFFFFF} untuk refresh manual", -1)
            break
        end
    end

    while true do
        wait(1000)

        -- cek kalau gak ada "aktivitas" selama 15 detik
        if os.clock() - lastActivity > 15 then
            if not warningShown then
                sampAddChatMessage("{FF0000}[VoiceFix] Mic kemungkinan mati! Ketik /rvoice", -1)
                warningShown = true
            end
        else
            warningShown = false
        end
    end
end

-- simulasi "aktivitas" (bisa kamu trigger manual juga nanti)
function sampev.onSendPlayerSync()
    lastActivity = os.clock()
end

function manualRefresh()
    sampAddChatMessage("{FFFF00}[VoiceFix] Refreshing audio...", -1)

    -- Game pause feature removed due to compatibility
    lua_thread.create(function()
        wait(1000)
        lastActivity = os.clock()
        warningShown = false

        sampAddChatMessage("{00FF00}[VoiceFix] Done! Coba ngomong lagi.", -1)
    end)
end