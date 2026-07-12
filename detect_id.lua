local sampev = require 'lib.samp.events'

-- Variabel penampung parameter input user
local botAktif = false
local inputPlayerId = ""
local inputNamaInvoice = ""
local inputHargaInvoice = ""

function main()
    while not isSampAvailable() do wait(100) end

    -- Command: /autoinvoice [id] [nama_invoice] [harga]
    sampRegisterChatCommand("autoinvoice", function(param)
        if param == "" or not param then
            sampAddChatMessage("{FF0000}[Invoice Bot] {FFFFFF}Format salah! Gunakan: /autoinvoice [id] [nama_invoice] [harga]", -1)
            sampAddChatMessage("{FF0000}[Invoice Bot] {FFFFFF}Contoh: /autoinvoice 167 testing 1", -1)
            return
        end

        local id, nama, harga = param:match("^(%d+)%s+(%S+)%s+(%d+)$")
        
        if id and nama and harga then
            inputNamaInvoice = nama:gsub("_", " ")
            inputPlayerId = id
            inputHargaInvoice = harga
            botAktif = true
            
            sampAddChatMessage("{00FF00}[Invoice Bot] {FFFFFF}Target Terkunci (Backup: GameText Aktif)!", -1)
            sampAddChatMessage(string.format("{FFFF00}[Target] {FFFFFF}ID: %s | Nama: %s | Harga: %s", inputPlayerId, inputNamaInvoice, inputHargaInvoice), -1)
            sampAddChatMessage("{00FF00}[Invoice Bot] {FFFFFF}Silakan tekan tombol N sekarang.", -1)
        else
            sampAddChatMessage("{FF0000}[Invoice Bot] {FFFFFF}Gagal membaca parameter. Pastikan formatnya benar!", -1)
        end
    end)

    wait(-1)
end

-- ========================================================
-- CARA 1: DETEKSI VIA GAMETEXT (GXT INTERCEPTION)
-- ========================================================
function sampev.onDisplayGameText(style, time, text)
    if not botAktif then return true end

    local cleanText = text:gsub("~%a~", "") -- Bersihkan format warna server (~r~, ~y~, dll)

    -- Jika teks menu terdeteksi lewat paket GameText GTA SA
    if cleanText:find("Faction Panel") or cleanText:find("Invoice") or cleanText:find("Action") or cleanText:find("Invoice manual") then
        lua_thread.create(function()
            sampAddChatMessage("{00FF00}[Bot-GameText] {FFFFFF}Menu terdeteksi di GameText! Memulai bypass...", -1)
            
            -- Kita tembak id click textdraw statis 109 sebagai trigger paket awal ke server
            sampSendClickTextdraw(109)
            
            -- Rantai otomatisasi dialog pengisian langsung dipicu setelahnya
            wait(500) 
            sampSetCurrentDialogEditboxText(inputNamaInvoice)
            sampCloseCurrentDialogWithButton(1) -- Kirim/Enter data nama
            sampAddChatMessage("{00FF00}[Bot-GameText] {FFFFFF}Sukses input Nama Invoice: " .. inputNamaInvoice, -1)
            
            wait(500) 
            sampSetCurrentDialogEditboxText(inputHargaInvoice)
            sampCloseCurrentDialogWithButton(1) -- Kirim/Enter data harga
            sampAddChatMessage("{00FF00}[Bot-GameText] {FFFFFF}Sukses input Harga Invoice: " .. inputHargaInvoice .. ". PROSES SELESAI!", -1)
            
            botAktif = false -- Matikan bot karena siklus selesai
        end)
    end
    return true
end

-- ========================================================
-- IMPLEMENTASI METODE 1: ON TEXTDRAW SET STRING (UPDATE TEKS)
-- ========================================================
function sampev.onTextDrawSetString(id, text)
    if not botAktif then return true end

    local cleanText = text:gsub("~%a~", "") 

    if cleanText:find("Faction Panel") or cleanText:find("Invoice") or cleanText:find("Action") then
        lua_thread.create(function()
            wait(400) 
            sampSendClickTextdraw(id)
            sampAddChatMessage("{00FF00}[Bot-String] {FFFFFF}Terdeteksi Update Teks! Sukses klik Menu Utama (ID " .. id .. ")", -1)
        end)
    end
    return true
end

-- ========================================================
-- OTOMATISASI FULL TEXTDRAW (AMANKAN STEP ID PLAYER)
-- ========================================================
function sampev.onShowTextDraw(id, data)
    if not botAktif then return true end

    local textData = data.text or ""
    local cleanText = textData:gsub("~%a~", "") 

    -- STEP 1: Deteksi Menu Utama (ID 109 / 117 / 110) pas pencet N
    if id == 109 or id == 117 or id == 110 or id == 132 then
        lua_thread.create(function()
            wait(400) 
            sampSendClickTextdraw(id)
            sampAddChatMessage("{00FF00}[Bot] {FFFFFF}Sukses klik Menu Utama (ID " .. id .. ")", -1)
        end)
        return true 
    end

    -- STEP 2: Cari & Klik opsi menu "Invoice manual"
    if cleanText:find("Invoice manual") then
        lua_thread.create(function()
            wait(300) 
            sampSendClickTextdraw(id)
            sampAddChatMessage("{00FF00}[Bot] {FFFFFF}Sukses klik 'Invoice manual'!", -1)
        end)
        return false 
    end

    -- STEP 3A: PENGUNCI ID TARGET
    if cleanText:find("%(" .. inputPlayerId .. "%)") or cleanText:find("^" .. inputPlayerId .. "$") then
        lua_thread.create(function()
            wait(250)
            sampSendClickTextdraw(id) 
            sampAddChatMessage("{00FF00}[Bot] {FFFFFF}Sukses klik & mengunci Baris Player ID: " .. inputPlayerId, -1)
        end)
        return false
    end

    -- STEP 3B: Klik Tombol "Pilih" Konfirmasi
    if cleanText:find("Pilih") or cleanText:find("PILIH") then
        lua_thread.create(function()
            wait(600) 
            sampSendClickTextdraw(id) 
            sampAddChatMessage("{00FF00}[Bot] {FFFFFF}Sukses klik tombol 'Pilih' konfirmasi!", -1)
            
            lua_thread.create(function()
                wait(500) 
                sampSetCurrentDialogEditboxText(inputNamaInvoice)
                sampCloseCurrentDialogWithButton(1) 
                sampAddChatMessage("{00FF00}[Bot] {FFFFFF}Sukses input Nama Invoice: " .. inputNamaInvoice, -1)
                
                wait(500) 
                sampSetCurrentDialogEditboxText(inputHargaInvoice)
                sampCloseCurrentDialogWithButton(1) 
                sampAddChatMessage("{00FF00}[Bot] {FFFFFF}Sukses input Harga Invoice: " .. inputHargaInvoice .. ". PROSES TUNTAS!", -1)
                
                botAktif = false 
            end)
        end)
        return false
    end

    -- Blokir visual sisa box hitam panel agar proses otomatisasi gaib total di monitor kamu
    if cleanText:find("Faction Panel") or cleanText:find("Invoice") or cleanText:find("Player ID") or cleanText:find("Mohon masukkan") or textData:find("LD_BEAT") then
        return false
    end

    return true
end