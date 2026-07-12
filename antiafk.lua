-- Auto Anti AFK MoonLoader
-- Otomatis detect kode AFK dari server
-- lalu auto mengetik /afk KODE

script_name("AutoAntiAFK")
script_author("Arkananta Studio")

require "lib.moonloader"

local sampev = require "lib.samp.events"

function main()
    repeat wait(0) until isSampAvailable()

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[AutoAntiAFK] Script berhasil dimuat!", -1)
            break
        end
    end

    while true do
        wait(0)
    end
end

-- Detect pesan server
function sampev.onServerMessage(color, text)

    -- Cari pola:
    -- /afk 952
    local code = text:match("/afk%s+(%d+)")

    if code then

        sampAddChatMessage(
            string.format("{00FF00}[AntiAFK] Auto kembali RP dengan kode: %s", code),
            -1
        )

        -- Jeda kecil biar aman
        lua_thread.create(function()
            wait(1000)

            -- Kirim command otomatis
            sampSendChat(string.format("/afk %s", code))
        end)
    end
end