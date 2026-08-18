-- ============================================================
--  TIKTOK LIVE CHAT OVERLAY - MoonLoader SA-MP
--  Menampilkan chat TikTok Live di dalam game GTA SAMP
--
--  CARA PAKAI:
--  1. Buka /ttchatpanel di dalam game
--  2. Masukkan Username TikTok (contoh: @username_kamu)
--  3. Klik "💾 Simpan Config"
--  4. Klik "▶ Hubungkan" (jendela cmd bridge akan terbuka)
--  5. Chat TikTok akan otomatis mengalir di overlay game!
-- ============================================================

script_name("TikTok Live Chat Overlay")
script_author("Antigravity")
script_description("Menampilkan TikTok Live Chat di overlay GTA SAMP")

require "lib.moonloader"
local mimgui   = require "mimgui"
local ffi      = require "ffi"
local json     = require "dkjson"
local os       = require "os"

-- ============================================================
-- PATHS
-- ============================================================
local workDir  = getWorkingDirectory()
local cfgDir   = workDir .. "\\config\\ttchat"
local cfgFile  = cfgDir  .. "\\config.json"
local jsonFile = cfgDir  .. "\\live_chat.json"
local pyScript = cfgDir  .. "\\tiktok_bridge.py"

-- ============================================================
-- STATE
-- ============================================================
local mainWindow     = mimgui.new.bool(false)
local overlayWindow  = mimgui.new.bool(false)

local bufUsername = mimgui.new.char[128]("")

local username     = ""
local isConnected  = false
local statusMsg    = "Belum terhubung"
local lastSyncTime = 0
local SYNC_INTERVAL = 0.5  -- Detik jeda membaca file JSON (500ms)

local messages = {} -- Array berisi { author, text, time, is_moderator, is_subscriber, is_system }

-- Warna author bergantian
local authorColors = {
    { 1.0, 0.4, 0.4 },   -- merah muda
    { 0.4, 0.8, 1.0 },   -- biru muda
    { 0.5, 1.0, 0.5 },   -- hijau muda
    { 1.0, 0.8, 0.4 },   -- kuning
    { 1.0, 0.5, 0.8 },   -- pink
    { 0.8, 0.6, 1.0 },   -- ungu muda
    { 0.4, 1.0, 0.9 },   -- cyan
}
local colorIndex = 0

-- GUI feedback
local cfgMsg      = ""
local cfgMsgColor = { 0.4, 1.0, 0.5 }

-- ============================================================
-- DIRECTORY SETUP
-- ============================================================
local function ensureDirs()
    local base = workDir .. "\\config"
    if not doesDirectoryExist(base)    then createDirectory(base) end
    if not doesDirectoryExist(cfgDir)  then createDirectory(cfgDir) end
end

-- Helper: ambil hanya nama file dari path panjang
local function shortPath(path)
    if not path then return "" end
    return path:match("([^\\]+)$") or path
end

-- ============================================================
-- CONFIG: SAVE & LOAD
-- ============================================================
local function saveConfig()
    ensureDirs()
    local data = {
        username     = username,
        savedAt      = os.date("%Y-%m-%d %H:%M:%S"),
        version      = 1,
    }
    local f = io.open(cfgFile, "w")
    if f then
        f:write(json.encode(data, { indent = true }))
        f:close()
        return true
    end
    return false
end

local function loadConfig()
    local f = io.open(cfgFile, "r")
    if not f then return false end
    local content = f:read("*all")
    f:close()
    if not content or content == "" then return false end

    local ok, data = pcall(json.decode, content)
    if not ok or not data then return false end

    if data.username and data.username ~= "" then
        username = data.username
        ffi.copy(bufUsername, username)
    end
    return true
end

-- ============================================================
-- CHAT SYNC (MEMBACA JSON DARI PYTHON BRIDGE)
-- ============================================================
local function syncChatJson()
    if not doesFileExist(jsonFile) then return end
    
    local f = io.open(jsonFile, "r")
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then
            local ok, data = pcall(json.decode, content)
            if ok and data then
                messages = data
                
                -- Cek apakah ada pesan system untuk menentukan status koneksi
                if #messages > 0 then
                    local lastMsg = messages[#messages]
                    if lastMsg.is_system then
                        statusMsg = lastMsg.text
                    else
                        statusMsg = string.format("✅ Aktif | Terhubung ke %s (%d chat)", username, #messages)
                    end
                end
            end
        end
    end
end

-- ============================================================
-- PROCESS CONTROL (START & STOP BRIDGE)
-- ============================================================
local function startTikTokBridge()
    ensureDirs()
    if username == "" then return false end
    
    -- Pastikan file Python ada
    if not doesFileExist(pyScript) then
        sampAddChatMessage("{FF4444}[TikTok Chat] {FFFFFF}Error: File tiktok_bridge.py hilang!", -1)
        return false
    end
    
    -- Mulai jembatan Python menggunakan perintah shell start cmd
    local cmd = string.format('start cmd /k "python \"%s\" %s"', pyScript, username)
    os.execute(cmd)
    
    isConnected = true
    statusMsg = "Menghubungkan ke TikTok..."
    return true
end

local function stopTikTokBridge()
    if username == "" then return end
    
    -- Hentikan jembatan cmd Python dengan taskkill berdasarkan Console Title yang diset oleh Python
    local cmd = string.format('taskkill /F /FI "WINDOWTITLE eq TikTok Live: %s" >nul 2>&1', username)
    os.execute(cmd)
    
    isConnected = false
    statusMsg = "Koneksi terputus."
    
    -- Kosongkan file JSON
    local f = io.open(jsonFile, "w")
    if f then
        f:write("[]")
        f:close()
    end
    messages = {}
end

-- ============================================================
-- GUI STYLE
-- ============================================================
local function applyStyle()
    local style = mimgui.GetStyle()
    style.WindowRounding   = 8.0
    style.FrameRounding    = 5.0
    style.GrabRounding     = 4.0
    style.WindowBorderSize = 1.0
    style.ItemSpacing      = mimgui.ImVec2(8, 6)

    local col = style.Colors
    col[mimgui.Col.WindowBg]        = mimgui.ImVec4(0.04, 0.08, 0.08, 0.95)
    col[mimgui.Col.Border]          = mimgui.ImVec4(0.2, 0.9, 1.0, 0.55)
    col[mimgui.Col.TitleBg]         = mimgui.ImVec4(0.02, 0.12, 0.12, 1.0)
    col[mimgui.Col.TitleBgActive]   = mimgui.ImVec4(0.04, 0.65, 0.65, 1.0)
    col[mimgui.Col.Button]          = mimgui.ImVec4(0.04, 0.55, 0.55, 0.85)
    col[mimgui.Col.ButtonHovered]   = mimgui.ImVec4(0.10, 0.80, 0.80, 0.90)
    col[mimgui.Col.ButtonActive]    = mimgui.ImVec4(0.02, 0.40, 0.40, 1.00)
    col[mimgui.Col.FrameBg]         = mimgui.ImVec4(0.06, 0.14, 0.14, 0.90)
    col[mimgui.Col.FrameBgHovered]  = mimgui.ImVec4(0.12, 0.25, 0.25, 1.0)
    col[mimgui.Col.CheckMark]       = mimgui.ImVec4(0.3, 1.0, 1.0, 1.0)
    col[mimgui.Col.SliderGrab]      = mimgui.ImVec4(0.3, 1.0, 1.0, 1.0)
    col[mimgui.Col.Header]          = mimgui.ImVec4(0.05, 0.5, 0.5, 0.7)
    col[mimgui.Col.Separator]       = mimgui.ImVec4(0.2, 1.0, 1.0, 0.35)
    col[mimgui.Col.Text]            = mimgui.ImVec4(0.92, 0.95, 0.95, 1.0)
    col[mimgui.Col.ScrollbarBg]     = mimgui.ImVec4(0, 0, 0, 0)
    col[mimgui.Col.ScrollbarGrab]   = mimgui.ImVec4(0.1, 0.7, 0.7, 0.55)
    col[mimgui.Col.ScrollbarGrabHovered] = mimgui.ImVec4(0.15, 0.9, 0.9, 0.8)
end

mimgui.OnInitialize(applyStyle)

-- ============================================================
-- GUI - PANEL PENGATURAN (Main Window)
-- ============================================================
mimgui.OnFrame(function() return mainWindow[0] end, function()
    mimgui.SetNextWindowSize(mimgui.ImVec2(520, 340), mimgui.Cond.FirstUseEver)
    mimgui.SetNextWindowPos(mimgui.ImVec2(100, 120), mimgui.Cond.FirstUseEver)
    mimgui.Begin("📱 TikTok Live Chat - Setup Panel", mainWindow, mimgui.WindowFlags.NoCollapse)

    -- Header
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.2, 0.9, 1.0, 1.0))
    mimgui.Text("📱 TikTok Live Chat Overlay")
    mimgui.PopStyleColor()
    mimgui.SameLine()
    
    local cfgExists = doesFileExist(cfgFile)
    if cfgExists then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.3, 1.0, 0.4, 0.85))
        mimgui.Text(" 🔒 Config Tersimpan")
        mimgui.PopStyleColor()
    else
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.6, 0.2, 0.85))
        mimgui.Text(" ⚠ Belum ada config")
        mimgui.PopStyleColor()
    end
    mimgui.Separator()
    mimgui.Spacing()

    -- ── Input Username ───────────────────────────────────────
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.3, 1.0, 0.9, 1.0))
    mimgui.Text("👤 TikTok Username: (contoh: @username_kamu)")
    mimgui.PopStyleColor()
    mimgui.PushItemWidth(-1)
    mimgui.InputText("##username", bufUsername, 128)
    mimgui.PopItemWidth()
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.45, 0.65, 1.0, 0.75))
    mimgui.Text("   Pastikan live stream kamu sudah berjalan di TikTok sebelum menghubungkan!")
    mimgui.PopStyleColor()

    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    -- ── Baris Tombol ────────────────────────────────────────

    -- Tombol SIMPAN CONFIG
    mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.10, 0.35, 0.55, 0.90))
    mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.15, 0.50, 0.78, 0.95))
    if mimgui.Button("💾 Simpan Config", mimgui.ImVec2(140, 34)) then
        local rawUser = ffi.string(bufUsername):gsub("^%s*(.-)%s*$", "%1")
        if rawUser == "" then
            cfgMsg      = "❌ Username tidak boleh kosong!"
            cfgMsgColor = { 1.0, 0.3, 0.3 }
        else
            username = rawUser
            if saveConfig() then
                cfgMsg      = "✅ Username berhasil disimpan ke config.json"
                cfgMsgColor = { 0.3, 1.0, 0.45 }
            else
                cfgMsg      = "❌ Gagal menyimpan config!"
                cfgMsgColor = { 1.0, 0.3, 0.3 }
            end
        end
    end
    mimgui.PopStyleColor(2)

    mimgui.SameLine()

    -- Tombol HUBUNGKAN / PUTUSKAN
    if not isConnected then
        if mimgui.Button("▶ Hubungkan", mimgui.ImVec2(120, 34)) then
            local rawUser = ffi.string(bufUsername):gsub("^%s*(.-)%s*$", "%1")
            if rawUser == "" then
                statusMsg = "❌ Masukkan username terlebih dahulu!"
            else
                username = rawUser
                saveConfig() -- Auto-save
                cfgMsg = "✅ Config di-auto-save."
                cfgMsgColor = { 0.3, 1.0, 0.45 }
                
                if startTikTokBridge() then
                    sampAddChatMessage("{00FFFF}[TikTok Chat] {FFFFFF}Menghubungkan ke bridge. Jendela CMD akan terbuka di background.", -1)
                end
            end
        end
    else
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.55, 0.04, 0.04, 0.88))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.80, 0.10, 0.10, 0.95))
        if mimgui.Button("⏹ Putuskan", mimgui.ImVec2(120, 34)) then
            stopTikTokBridge()
            sampAddChatMessage("{00FFFF}[TikTok Chat] {FFFFFF}Bridge dihentikan.", -1)
        end
        mimgui.PopStyleColor(2)
    end

    mimgui.SameLine()

    -- Tombol Toggle Overlay
    if overlayWindow[0] then
        if mimgui.Button("👁 Sembunyikan Overlay", mimgui.ImVec2(170, 34)) then
            overlayWindow[0] = false
        end
    else
        if mimgui.Button("👁 Tampilkan Overlay", mimgui.ImVec2(170, 34)) then
            overlayWindow[0] = true
        end
    end

    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    -- ── Info Status & File ──────────────────────────────────
    mimgui.PushStyleColor(mimgui.Col.Text,
        isConnected
            and mimgui.ImVec4(0.25, 1.0, 0.35, 1.0)
            or  mimgui.ImVec4(1.0, 0.65, 0.2, 1.0)
    )
    mimgui.Text("Status: " .. statusMsg)
    mimgui.PopStyleColor()

    if cfgMsg ~= "" then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(cfgMsgColor[1], cfgMsgColor[2], cfgMsgColor[3], 1.0))
        mimgui.Text(cfgMsg)
        mimgui.PopStyleColor()
    end

    mimgui.Spacing()

    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.55, 0.55, 0.65, 0.85))
    mimgui.Text("💾 Config: config\\ttchat\\config.json")
    mimgui.Text("📄 Live Data: config\\ttchat\\live_chat.json")
    mimgui.PopStyleColor()

    mimgui.End()
end)

-- ============================================================
-- GUI - OVERLAY CHAT (Bersih untuk Stream)
-- ============================================================
mimgui.OnFrame(function() return overlayWindow[0] end, function()
    mimgui.SetNextWindowPos(mimgui.ImVec2(15, 310), mimgui.Cond.FirstUseEver)
    mimgui.SetNextWindowSize(mimgui.ImVec2(500, 340), mimgui.Cond.FirstUseEver)
    mimgui.SetNextWindowBgAlpha(0.78)

    local flags = mimgui.WindowFlags.NoTitleBar + mimgui.WindowFlags.NoScrollbar

    mimgui.Begin("##TTChatOverlay", overlayWindow, flags)

    -- Header bar
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.2, 0.9, 1.0, 1.0))
    mimgui.Text("📱 TIKTOK LIVE CHAT")
    mimgui.PopStyleColor()

    if isConnected then
        mimgui.SameLine()
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.18, 1.0, 0.28, 0.95))
        mimgui.Text(" ● LIVE")
        mimgui.PopStyleColor()
    end

    -- Tombol tutup overlay
    mimgui.SameLine()
    mimgui.SetCursorPosX(mimgui.GetContentRegionAvail().x - 18)
    if mimgui.SmallButton("X") then
        overlayWindow[0] = false
    end

    mimgui.Separator()

    -- Area Chat
    mimgui.BeginChild("##TTMessages", mimgui.ImVec2(-1, -1), false)

    if #messages == 0 then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.45, 0.45, 0.5, 0.65))
        mimgui.Text("Belum ada chat.")
        mimgui.Text("Buka /ttchatpanel → isi Username → ▶ Hubungkan")
        mimgui.PopStyleColor()
    else
        for _, msg in ipairs(messages) do
            if msg.is_system then
                -- Pesan system berwarna oranye
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.6, 0.2, 0.9))
                mimgui.TextWrapped("[SYSTEM] " .. msg.text)
                mimgui.PopStyleColor()
            else
                -- Tentukan warna berdasarkan author
                colorIndex = 1
                for i = 1, #msg.author do
                    colorIndex = colorIndex + string.byte(msg.author, i)
                end
                colorIndex = (colorIndex % #authorColors) + 1
                local c = authorColors[colorIndex]

                -- Timestamp kecil
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.4, 0.4, 0.5, 0.6))
                mimgui.Text(msg.time or "N/A")
                mimgui.PopStyleColor()
                mimgui.SameLine()

                -- Badge Mod/Sub
                local badge = ""
                if msg.is_moderator then badge = "🔧 " end
                if msg.is_subscriber then badge = badge .. "★ " end

                -- Nama Author
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(c[1], c[2], c[3], 1.0))
                mimgui.Text(badge .. msg.author .. ":")
                mimgui.PopStyleColor()

                -- Teks pesan
                mimgui.SameLine()
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.93, 0.93, 0.93, 1.0))
                mimgui.TextWrapped(msg.text)
                mimgui.PopStyleColor()
            end
        end

        -- Auto scroll ke bawah
        mimgui.SetScrollHereY(1.0)
    end

    mimgui.EndChild()
    mimgui.End()
end)

-- ============================================================
-- MAIN LOOP + POLLING
-- ============================================================
function main()
    while not isSampAvailable() do wait(100) end

    ensureDirs()

    -- Load config tersimpan (username terakhir)
    if loadConfig() then
        sampAddChatMessage("{00FFFF}[TikTok Chat] {FFFFFF}Config ditemukan! Username loaded: " .. username, -1)
    end

    -- /ttchat → toggle overlay chat
    sampRegisterChatCommand("ttchat", function()
        overlayWindow[0] = not overlayWindow[0]
    end)

    -- /ttchatpanel → buka panel setup
    sampRegisterChatCommand("ttchatpanel", function()
        mainWindow[0] = not mainWindow[0]
    end)

    -- /ttoverlay → alias overlay
    sampRegisterChatCommand("ttoverlay", function()
        overlayWindow[0] = not overlayWindow[0]
    end)

    -- /ttlogfolder → buka folder log di Windows Explorer
    sampRegisterChatCommand("ttlogfolder", function()
        ensureDirs()
        os.execute('explorer "' .. cfgDir .. '"')
        sampAddChatMessage("{00FFFF}[TikTok Chat] {FFFFFF}Membuka folder konfigurasi.", -1)
    end)

    -- /ttclearcfg → hapus config (reset username)
    sampRegisterChatCommand("ttclearcfg", function()
        if doesFileExist(cfgFile) then
            os.remove(cfgFile)
            username = ""
            ffi.copy(bufUsername, "")
            sampAddChatMessage("{00FFFF}[TikTok Chat] {FFFFFF}Config dihapus! Username direset.", -1)
        else
            sampAddChatMessage("{00FFFF}[TikTok Chat] {FFFFFF}Tidak ada config yang perlu dihapus.", -1)
        end
    end)

    sampAddChatMessage(
        "{00FFFF}[TikTok Live Chat] {FFFFFF}Loaded! | " ..
        "{00FFFF}/ttchat{FFFFFF} = Overlay | " ..
        "{00FFFF}/ttchatpanel{FFFFFF} = Setup | " ..
        "{00FFFF}/ttlogfolder{FFFFFF} = Buka Folder Config",
        -1
    )

    -- Loop sinkronisasi file JSON
    while true do
        wait(SYNC_INTERVAL * 1000)

        if isConnected then
            syncChatJson()
        end
    end
end

-- ============================================================
-- LUA TERMINATION HOOK
-- ============================================================
function onScriptTerminate(script)
    if script == thisScript() and isConnected then
        -- Bersihkan jembatan python saat script dimuat ulang/mati
        stopTikTokBridge()
    end
end
