script_name("Auto Reconnect")
script_author("Antigravity")
script_description("Otomatis reconnect saat koneksi terputus")

require "lib.moonloader"
local sampev = require "samp.events"

local reconnecting = false
local reconnectDelay = 3000 -- Jeda sebelum reconnect (3 detik)

function sampev.onConnectionClosed()
    triggerReconnect("Koneksi ditutup oleh server")
end

function sampev.onConnectionLost()
    triggerReconnect("Koneksi terputus (lost connection)")
end

function triggerReconnect(reason)
    if reconnecting then return end
    reconnecting = true
    
    lua_thread.create(function()
        sampAddChatMessage(string.format("{FF0000}[AutoReconnect] %s!", reason), -1)
        
        -- Hitung mundur sebelum reconnect
        for i = math.ceil(reconnectDelay / 1000), 1, -1 do
            sampAddChatMessage(string.format("{FFFF00}[AutoReconnect] Menghubungkan ulang dalam %d detik...", i), -1)
            wait(1000)
        end
        
        sampAddChatMessage("{00FF00}[AutoReconnect] Mencoba menghubungkan ulang...", -1)
        
        -- Lakukan proses pemutusan & penyetelan ulang state
        sampDisconnectWithReason(0)
        wait(1000)
        sampSetGamestate(1) -- Reset state ke GAMESTATE_WAIT_CONNECT agar otomatis re-connect
        
        reconnecting = false
    end)
end

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("autorec", function()
        sampAddChatMessage("{FFFF00}[AutoReconnect] Memaksa reconnect...", -1)
        triggerReconnect("Manual reconnect")
    end)

    sampAddChatMessage("{00FF00}Auto Reconnect loaded | Gunakan /autorec untuk paksa reconnect", -1)

    while true do
        wait(0)
    end
end
