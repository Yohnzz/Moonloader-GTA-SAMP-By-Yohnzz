-- ============================================================
--  AUTO RECONNECT & AUTO LOGIN
--  Menyediakan auto-reconnect cerdas dengan pergantian nama instan
--  dan auto-login menggunakan password dari config.json
--  Command: /reconnect [nama] (default: Yohnzz)
-- ============================================================

script_name("Auto Reconnect")
script_author("Antigravity")
script_description("Otomatis reconnect dengan pergantian nama instan & auto login")

require "lib.moonloader"
local sampev = require "samp.events"
local json   = require "dkjson"

local reconnecting = false
local reconnectDelay = 3000 -- Jeda sebelum reconnect (3 detik)
local currentAccountName = "Yohnzz" -- Default akun utama

-- ============================================================
-- CONFIGURATION SYSTEM
-- ============================================================
local workDir = getWorkingDirectory()
local cfgDir  = workDir .. "\\config\\autoreconnect"
local cfgFile = cfgDir  .. "\\config.json"

local config = {
    accounts = {
        ["Yohnzz"] = "isi_password_yohnzz_disini",
        ["ContohNama"] = "isi_password_disini"
    }
}

local function ensureDir()
    local base = workDir .. "\\config"
    if not doesDirectoryExist(base) then createDirectory(base) end
    if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end
end

local function saveConfig()
    ensureDir()
    local f = io.open(cfgFile, "w")
    if f then
        f:write(json.encode(config, { indent = true }))
        f:close()
        return true
    end
    return false
end

local function loadConfig()
    ensureDir()
    local f = io.open(cfgFile, "r")
    if not f then
        saveConfig() -- Buat config default jika belum ada
        return false
    end
    local raw = f:read("*all")
    f:close()
    if not raw or raw == "" then return false end
    local ok, data = pcall(json.decode, raw)
    if ok and data then
        config = data
        config.accounts = config.accounts or {}
        -- Pastikan minimal akun default tertulis di config jika kosong
        if not config.accounts["Yohnzz"] then
            config.accounts["Yohnzz"] = "isi_password_yohnzz_disini"
            saveConfig()
        end
        return true
    end
    return false
end

-- ============================================================
-- CORE RECONNECT PROCESS
-- ============================================================
function triggerReconnect(reason, targetName)
    if reconnecting then return end
    reconnecting = true

    -- Gunakan nama yang di-snapshot saat trigger dipanggil,
    -- atau currentAccountName jika tidak ada argumen (dipanggil dari /rc)
    local nameForReconnect = targetName or currentAccountName

    lua_thread.create(function()
        sampAddChatMessage(string.format("{FF0000}[AutoReconnect] %s!", reason), -1)

        -- Hitung mundur sebelum reconnect
        for i = math.ceil(reconnectDelay / 1000), 1, -1 do
            sampAddChatMessage(string.format("{FFFF00}[AutoReconnect] Menghubungkan ulang dalam %d detik...", i), -1)
            wait(1000)
        end

        -- Putuskan koneksi lama terlebih dahulu (agar client melakukan cleanup secara bersih)
        sampDisconnectWithReason(0)
        wait(1000)

        -- Set nama lokal tepat sebelum mengirim handshake koneksi baru ke server
        sampSetLocalPlayerName(nameForReconnect)
        currentAccountName = nameForReconnect
        sampAddChatMessage(string.format("{00FF00}[AutoReconnect] Menghubungkan ulang sebagai: {FFFF00}%s", nameForReconnect), -1)

        -- Reset state ke WAIT_CONNECT untuk memulai koneksi
        sampSetGamestate(1) -- GAMESTATE_WAIT_CONNECT

        reconnecting = false
    end)
end

-- ============================================================
-- AUTO LOGIN DIALOG INTERCEPTOR
-- ============================================================
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 13 then
        local pass = config.accounts[currentAccountName]
        if pass and pass ~= "" and pass ~= "isi_password_yohnzz_disini" and pass ~= "isi_password_disini" then
            lua_thread.create(function()
                wait(200) -- Delay 200ms agar server siap memproses input
                sampSendDialogResponse(13, 1, -1, pass)
            end)
            sampAddChatMessage(string.format("{00FF00}[AutoReconnect] Menemukan dialog login. Memasukkan password untuk {FFFF00}%s{00FF00} secara otomatis.", currentAccountName), -1)
            return false -- Sembunyikan dialog login agar tidak mengganggu player
        else
            sampAddChatMessage(string.format("{FFFF00}[AutoReconnect] Dialog login muncul, tetapi password untuk '{FFFFFF}%s{FFFF00}' belum diatur di config.json.", currentAccountName), -1)
        end
    end
end

-- ============================================================
-- DISCONNECT DETECTION HOOKS (Auto Reconnect)
-- ============================================================
function sampev.onConnectionClosed()
    -- Snapshot nama akun aktif sebelum disconnect
    local nameToUse = currentAccountName
    triggerReconnect("Koneksi ditutup oleh server", nameToUse)
end

function sampev.onConnectionLost()
    -- Snapshot nama akun aktif sebelum disconnect
    local nameToUse = currentAccountName
    triggerReconnect("Koneksi terputus (lost connection)", nameToUse)
end

-- ============================================================
-- MAIN LOOP & COMMANDS
-- ============================================================
function main()
    repeat wait(0) until isSampAvailable()

    -- Muat konfigurasi akun dan password
    loadConfig()

    -- Perintah /rc [nama] (reconnect manual, default: Yohnzz)
    sampRegisterChatCommand("rc", function(param)
        local targetName = param:match("^%s*(%S+)%s*$")
        if not targetName or targetName == "" then
            targetName = "Yohnzz"
        end
        currentAccountName = targetName
        triggerReconnect(string.format("Manual reconnect ke akun %s", targetName), targetName)
    end)

    sampAddChatMessage("{00FF00}Auto Reconnect & Auto Login loaded | Gunakan /rc [nama] (default: Yohnzz)", -1)

    -- Loop sinkronisasi nickname & failsafe auto-login dialog 13
    while true do
        wait(200) -- Cek setiap 200ms agar lebih responsif
        if isSampAvailable() then
            -- 1. Sinkronisasi nickname (hanya jika tidak sedang reconnecting)
            if not reconnecting then
                local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if myId and myId ~= -1 then
                    local myName = sampGetPlayerNickname(myId)
                    if myName and myName ~= "" then
                        currentAccountName = myName
                    end
                end
            end

            -- 2. Failsafe Auto Login Dialog ID 13 (jika hook onShowDialog terlewat karena reconnect)
            if sampIsDialogActive() and sampGetCurrentDialogId() == 13 then
                local pass = config.accounts[currentAccountName]
                if pass and pass ~= "" and pass ~= "isi_password_yohnzz_disini" and pass ~= "isi_password_disini" then
                    sampSetCurrentDialogEditboxText(pass)
                    sampCloseCurrentDialogWithButton(1)
                    sampAddChatMessage(string.format("{00FF00}[AutoReconnect] Failsafe: Mengisi password login secara otomatis untuk {FFFF00}%s{00FF00}.", currentAccountName), -1)
                    wait(2000) -- Jeda 2 detik agar tidak mendeteksi dialog yang sama berulang kali
                end
            end
        end
    end
end
