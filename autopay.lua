script_name("Auto Pay")
script_author("Antigravity")
script_description("Auto Pay via command with auto-ENTER support")

require "lib.moonloader"
local sampev = require "samp.events"

local running = false

-- Mendeteksi jika dialog konfirmasi pembayaran muncul dari server
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if running then
        -- Kirim respon positif (tombol 1 / enter) untuk mengonfirmasi pembayaran
        sampSendDialogResponse(dialogId, 1, 0, "")
        return false -- Sembunyikan dialog agar tidak berkedip di layar
    end
end

-- Mendeteksi pesan dari server untuk menghentikan autopay jika ada kendala
function sampev.onServerMessage(color, text)
    if running then
        -- Hilangkan kode warna hex {FFFFFF} dll agar pencarian teks akurat
        local cleanText = text:gsub("{%x%x%x%x%x%x}", "")
        
        if cleanText:find("Pemain tersebut tidak terkoneksi ke server") or
           cleanText:find("Uang anda tidak cukup") or
           cleanText:find("Uang Anda tidak cukup") then
            
            running = false
            sampAddChatMessage("{FF0000}[AutoPay] Sistem dihentikan! Alasan: " .. cleanText, -1)
        end
    end
end

function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("autopay", function(param)
        if running then
            sampAddChatMessage("{FF0000}[AutoPay] Proses pengiriman uang masih berjalan!", -1)
            return
        end

        local id, amount = param:match("^(%d+)%s+(%d+)$")
        if not id or not amount then
            sampAddChatMessage("{FFFF00}[AutoPay] Penggunaan: /autopay [ID] [Jumlah]", -1)
            return
        end

        id = tonumber(id)
        local total = tonumber(amount)

        if not id or not total or total <= 0 then
            sampAddChatMessage("{FF0000}[AutoPay] ID atau Jumlah tidak valid!", -1)
            return
        end

        lua_thread.create(function()
            running = true
            local sisa = total
            sampAddChatMessage(string.format("{FFFF00}[AutoPay] Mengirim $%d ke ID %d...", total, id), -1)

            while sisa > 0 and running do
                local bayar = math.min(50000, sisa)
                sampSendChat(string.format("/pay %d %d", id, bayar))
                
                -- Tunggu sebentar agar server memproses perintah /pay
                wait(400)
                
                -- Fallback simulasi tombol ENTER (untuk PC jika server tidak menggunakan dialog standar)
                setVirtualKeyDown(13, true) -- ENTER down
                wait(50)
                setVirtualKeyDown(13, false) -- ENTER up
                
                sisa = sisa - bayar
                wait(1000) -- Jeda aman antar loop /pay (bisa disesuaikan jika terkena spam limit)
            end

            if running then
                sampAddChatMessage(string.format("{00FF00}[AutoPay] Selesai! $%d berhasil dikirim ke ID %d.", total, id), -1)
                running = false
            end
        end)
    end)

    sampAddChatMessage("{00FF00}AutoPay loaded | Gunakan /autopay [ID] [Jumlah]", -1)

    while true do
        wait(0)
    end
end