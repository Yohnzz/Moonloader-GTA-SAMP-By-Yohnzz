-- ============================================================
--  YOUTUBE LIVE CHAT OVERLAY - MoonLoader SA-MP
--  Menampilkan chat YouTube Live di dalam game GTA SAMP
--
--  CARA PAKAI:
--  1. Buka /ytchatpanel di dalam game
--  2. Masukkan YouTube API Key (gratis dari console.cloud.google.com)
--  3. Masukkan link/URL video YouTube Live yang sedang berjalan
--  4. Klik "💾 Simpan Config" untuk menyimpan API key secara aman
--  5. Klik "▶ Mulai" untuk mulai mengambil chat
--
--  FILE YANG DIHASILKAN:
--  - config/ytchat/config.json        → API Key & URL terakhir (terenkripsi sederhana)
--  - config/ytchat/logs/DD-MM-YYYY_logslivechat.txt → Log chat harian
-- ============================================================

script_name("YT Live Chat Overlay")
script_author("Yohanez")
script_description("Menampilkan YouTube Live Chat di overlay GTA SAMP")

require "lib.moonloader"
local mimgui   = require "mimgui"
local theme    = require "lib.mimgui_theme"
local ffi      = require "ffi"
local dlstatus = require("moonloader").download_status
local json     = require "dkjson"
local os       = require "os"

-- ============================================================
-- PATHS
-- ============================================================
local workDir  = getWorkingDirectory()
local cfgDir   = workDir .. "\\config\\ytchat"
local cfgFile  = cfgDir  .. "\\config.json"

-- Helper: ambil hanya nama file/folder terakhir dari path panjang
local function shortPath(path)
    if not path then return "" end
    return path:match("([^\\]+)$") or path
end

-- Label pendek untuk display di GUI / chat (relatif dari config/)
local function relPath(path)
    if not path then return "" end
    local rel = path:match("config\\(.+)$")
    return rel and ("config\\" .. rel) or shortPath(path)
end
local logsDir  = cfgDir  .. "\\logs"
local tmpDir   = cfgDir  .. "\\tmp\\"

-- ============================================================
-- STATE & KONFIGURASI
-- ============================================================
local mainWindow     = mimgui.new.bool(false)
local overlayWindow  = mimgui.new.bool(false)

local bufApiKey   = mimgui.new.char[256]("")
local bufVideoUrl = mimgui.new.char[512]("")

local apiKey        = ""
local lastVideoUrl  = ""
local liveChatId    = ""
local nextPageToken = ""
local isRunning     = false
local isFetching    = false
local statusMsg     = "Belum dimulai"
local lastFetchTime = 0
local POLL_INTERVAL = 8

local messages    = {}
local MAX_MESSAGES = 20

-- Log
local currentLogFile  = nil   -- path file log hari ini
local logSessionStart = nil   -- timestamp sesi dimulai
local totalLoggedMsgs = 0     -- total pesan yang sudah di-log sesi ini

-- Warna author bergantian
local authorColors = {
    { 0.4, 0.8, 1.0 },   -- biru muda
    { 0.5, 1.0, 0.5 },   -- hijau muda
    { 1.0, 0.8, 0.4 },   -- kuning
    { 1.0, 0.5, 0.8 },   -- pink
    { 0.8, 0.6, 1.0 },   -- ungu muda
    { 0.4, 1.0, 0.9 },   -- cyan
    { 1.0, 0.7, 0.4 },   -- oranye
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
    if not doesDirectoryExist(logsDir) then createDirectory(logsDir) end
    if not doesDirectoryExist(tmpDir)  then createDirectory(tmpDir) end
end

-- ============================================================
-- CONFIG: SAVE & LOAD
-- ============================================================

-- Obfuscate sederhana: XOR setiap byte dengan key
-- Ini bukan enkripsi kuat, tapi mencegah API key terbaca langsung di file teks
local XOR_KEY = 0x5F

local function xorString(s)
    local result = {}
    for i = 1, #s do
        result[i] = string.char(bit.bxor(string.byte(s, i), XOR_KEY))
    end
    return table.concat(result)
end

local function toHex(s)
    return (s:gsub(".", function(c)
        return string.format("%02X", string.byte(c))
    end))
end

local function fromHex(h)
    return (h:gsub("%x%x", function(hh)
        return string.char(tonumber(hh, 16))
    end))
end

local function encodeKey(plaintext)
    return toHex(xorString(plaintext))
end

local function decodeKey(encoded)
    local ok, result = pcall(function()
        return xorString(fromHex(encoded))
    end)
    return ok and result or ""
end

-- Simpan config ke file
local function saveConfig()
    ensureDirs()
    local data = {
        apiKey_enc   = encodeKey(apiKey),
        lastVideoUrl = lastVideoUrl,
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

-- Load config dari file
local function loadConfig()
    local f = io.open(cfgFile, "r")
    if not f then return false end
    local content = f:read("*all")
    f:close()
    if not content or content == "" then return false end

    local ok, data = pcall(json.decode, content)
    if not ok or not data then return false end

    if data.apiKey_enc and data.apiKey_enc ~= "" then
        apiKey = decodeKey(data.apiKey_enc)
        -- Isi buffer GUI dengan API key yang sudah didekode
        ffi.copy(bufApiKey, apiKey)
    end
    if data.lastVideoUrl and data.lastVideoUrl ~= "" then
        lastVideoUrl = data.lastVideoUrl
        ffi.copy(bufVideoUrl, lastVideoUrl)
    end
    return true
end

-- ============================================================
-- LOG CHAT
-- ============================================================

-- Dapatkan path log hari ini: logs/DD-MM-YYYY_logslivechat.txt
local function getTodayLogPath()
    local d = os.date("*t")
    local fname = string.format("%02d-%02d-%04d_logslivechat.txt", d.day, d.month, d.year)
    return logsDir .. "\\" .. fname
end

-- Tulis baris ke file log
local function writeLog(author, text, badge)
    ensureDirs()
    currentLogFile = getTodayLogPath()
    local timeStr = os.date("[%H:%M:%S]")
    local badgeStr = (badge and badge ~= "") and (badge .. " ") or ""
    local line = timeStr .. " " .. badgeStr .. author .. ": " .. text .. "\n"

    local f = io.open(currentLogFile, "a")   -- append mode
    if f then
        f:write(line)
        f:close()
        totalLoggedMsgs = totalLoggedMsgs + 1
    end
end

-- Tulis header sesi ke log
local function writeLogSessionHeader(videoUrl)
    ensureDirs()
    currentLogFile = getTodayLogPath()
    local timeStr = os.date("[%Y-%m-%d %H:%M:%S]")
    local header = string.format(
        "\n══════════════════════════════════════════\n" ..
        "  SESI DIMULAI: %s\n" ..
        "  Video: %s\n" ..
        "══════════════════════════════════════════\n",
        timeStr, videoUrl
    )
    local f = io.open(currentLogFile, "a")
    if f then
        f:write(header)
        f:close()
    end
    logSessionStart  = os.time()
    totalLoggedMsgs  = 0
end

-- Tulis footer sesi ke log saat stop
local function writeLogSessionFooter()
    if not currentLogFile then return end
    local elapsed = logSessionStart and (os.time() - logSessionStart) or 0
    local mins  = math.floor(elapsed / 60)
    local secs  = elapsed % 60
    local footer = string.format(
        "── Sesi berakhir | Durasi: %dm %ds | Total pesan: %d ──\n\n",
        mins, secs, totalLoggedMsgs
    )
    local f = io.open(currentLogFile, "a")
    if f then
        f:write(footer)
        f:close()
    end
end

-- ============================================================
-- UTILS
-- ============================================================

local function extractVideoId(url)
    local id = url:match("youtu%.be/([%w%-_]+)")
    if id then return id end
    id = url:match("[?&]v=([%w%-_]+)")
    if id then return id end
    id = url:match("/live/([%w%-_]+)")
    if id then return id end
    if url:match("^[%w%-_]+$") and #url == 11 then return url end
    return nil
end

local function nextColor()
    colorIndex = (colorIndex % #authorColors) + 1
    return authorColors[colorIndex]
end

local function addMessage(author, text, isModerator, isMember)
    local color  = nextColor()
    local badge  = ""
    if isModerator then badge = "🔧" end
    if isMember    then badge = badge .. "★" end

    table.insert(messages, {
        author    = (badge ~= "" and badge .. " " or "") .. (author or "?"),
        text      = text or "",
        color     = color,
        timeLabel = os.date("%H:%M"),
    })

    while #messages > MAX_MESSAGES do
        table.remove(messages, 1)
    end

    -- Tulis ke log (kecuali pesan SYSTEM)
    if author ~= "SYSTEM" then
        writeLog(author or "?", text or "", badge)
    end
end

-- ============================================================
-- YOUTUBE API - Ambil liveChatId dari videoId
-- ============================================================
local function fetchLiveChatId(videoId, rawUrl)
    if isFetching then return end
    isFetching = true
    statusMsg = "Mencari Live Chat ID..."

    ensureDirs()
    local url = string.format(
        "https://www.googleapis.com/youtube/v3/videos?id=%s&part=liveStreamingDetails&key=%s",
        videoId, apiKey
    )
    local tmpFile = tmpDir .. "video_info.json"

    downloadUrlToFile(url, tmpFile, function(id, status, p1, p2)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            local f = io.open(tmpFile, "r")
            if f then
                local content = f:read("*all")
                f:close()
                os.remove(tmpFile)

                local ok, data = pcall(decodeJson, content)
                if ok and data and data.items and #data.items > 0 then
                    local lsd = data.items[1].liveStreamingDetails
                    if lsd and lsd.activeLiveChatId then
                        liveChatId = lsd.activeLiveChatId
                        statusMsg  = "✅ Live Chat ditemukan! Polling dimulai..."
                        isRunning  = true
                        nextPageToken = ""

                        -- Tulis header log sesi
                        writeLogSessionHeader(rawUrl or videoId)

                        addMessage("SYSTEM", "Terhubung! Log disimpan ke: logs\\" .. shortPath(getTodayLogPath()), false, false)
                    else
                        statusMsg = "❌ Video tidak sedang live atau tidak punya live chat."
                        isRunning = false
                    end
                else
                    -- Cek apakah error dari API (misal quota habis / key salah)
                    if ok and data and data.error then
                        local errMsg = data.error.message or "Unknown API error"
                        local errCode = data.error.code or 0
                        statusMsg = string.format("❌ API Error %d: %s", errCode, errMsg)
                    else
                        statusMsg = "❌ Gagal parse respons API. Cek API key & Video ID."
                    end
                    isRunning = false
                end
            else
                statusMsg = "❌ Gagal membuka file temp."
                isRunning = false
            end
            isFetching = false
        elseif status == dlstatus.STATUSEX_ERROR then
            statusMsg  = "❌ Gagal terhubung ke YouTube API. Cek koneksi internet."
            isRunning  = false
            isFetching = false
            if doesFileExist(tmpFile) then os.remove(tmpFile) end
        end
    end)
end

-- ============================================================
-- YOUTUBE API - Ambil pesan chat
-- ============================================================
local function fetchChatMessages()
    if isFetching or not isRunning or liveChatId == "" then return end
    isFetching = true

    ensureDirs()
    local url = string.format(
        "https://www.googleapis.com/youtube/v3/liveChat/messages?liveChatId=%s&part=snippet,authorDetails&maxResults=200&key=%s",
        liveChatId, apiKey
    )
    if nextPageToken ~= "" then
        url = url .. "&pageToken=" .. nextPageToken
    end

    local tmpFile = tmpDir .. "chat_messages.json"

    downloadUrlToFile(url, tmpFile, function(id, status, p1, p2)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            local f = io.open(tmpFile, "r")
            if f then
                local content = f:read("*all")
                f:close()
                os.remove(tmpFile)

                local ok, data = pcall(decodeJson, content)
                if ok and data then
                    if data.nextPageToken then
                        nextPageToken = data.nextPageToken
                    end

                    if data.items then
                        for _, item in ipairs(data.items) do
                            local snippet = item.snippet
                            local author  = item.authorDetails

                            if snippet and snippet.type == "textMessageEvent" then
                                local authorName = author and author.displayName or "Unknown"
                                local msgText    = snippet.textMessageDetails
                                                   and snippet.textMessageDetails.messageText or ""
                                local isMod      = author and author.isChatModerator or false
                                local isMember   = author and author.isChatSponsor or false

                                if msgText ~= "" then
                                    addMessage(authorName, msgText, isMod, isMember)
                                end
                            end
                        end
                    end

                    if data.pollingIntervalMillis then
                        POLL_INTERVAL = math.max(5, math.floor(data.pollingIntervalMillis / 1000))
                    end

                    statusMsg = string.format(
                        "✅ LIVE | Polling %ds | Chat: %d | Log: %d pesan",
                        POLL_INTERVAL, #messages, totalLoggedMsgs
                    )
                else
                    statusMsg = "⚠ Gagal parse chat response."
                end
            end
            isFetching = false
        elseif status == dlstatus.STATUSEX_ERROR then
            statusMsg  = "⚠ Gagal ambil chat - akan coba lagi..."
            isFetching = false
            if doesFileExist(tmpFile) then os.remove(tmpFile) end
        end
    end)
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
    col[mimgui.Col.WindowBg]        = mimgui.ImVec4(0.04, 0.04, 0.08, 0.95)
    col[mimgui.Col.Border]          = mimgui.ImVec4(1.0, 0.2, 0.2, 0.55)
    col[mimgui.Col.TitleBg]         = mimgui.ImVec4(0.12, 0.02, 0.02, 1.0)
    col[mimgui.Col.TitleBgActive]   = mimgui.ImVec4(0.65, 0.04, 0.04, 1.0)
    col[mimgui.Col.Button]          = mimgui.ImVec4(0.55, 0.04, 0.04, 0.85)
    col[mimgui.Col.ButtonHovered]   = mimgui.ImVec4(0.80, 0.10, 0.10, 0.90)
    col[mimgui.Col.ButtonActive]    = mimgui.ImVec4(0.40, 0.02, 0.02, 1.00)
    col[mimgui.Col.FrameBg]         = mimgui.ImVec4(0.08, 0.06, 0.14, 0.90)
    col[mimgui.Col.FrameBgHovered]  = mimgui.ImVec4(0.15, 0.12, 0.25, 1.0)
    col[mimgui.Col.CheckMark]       = mimgui.ImVec4(1.0, 0.3, 0.3, 1.0)
    col[mimgui.Col.SliderGrab]      = mimgui.ImVec4(1.0, 0.3, 0.3, 1.0)
    col[mimgui.Col.Header]          = mimgui.ImVec4(0.5, 0.05, 0.05, 0.7)
    col[mimgui.Col.Separator]       = mimgui.ImVec4(1.0, 0.2, 0.2, 0.35)
    col[mimgui.Col.Text]            = mimgui.ImVec4(0.95, 0.92, 0.92, 1.0)
    col[mimgui.Col.ScrollbarBg]     = mimgui.ImVec4(0, 0, 0, 0)
    col[mimgui.Col.ScrollbarGrab]   = mimgui.ImVec4(0.7, 0.1, 0.1, 0.55)
    col[mimgui.Col.ScrollbarGrabHovered] = mimgui.ImVec4(0.9, 0.15, 0.15, 0.8)
end

mimgui.OnInitialize(function()
    theme.applyDarkModern()
end)

-- ============================================================
-- GUI - PANEL PENGATURAN (Main Window)
-- ============================================================
mimgui.OnFrame(function() return mainWindow[0] end, function()
    theme.applyDarkModern()
    mimgui.SetNextWindowSize(mimgui.ImVec2(520, 390), mimgui.Cond.FirstUseEver)
    mimgui.SetNextWindowPos(mimgui.ImVec2(100, 120), mimgui.Cond.FirstUseEver)
    mimgui.Begin("▶ YouTube Live Chat - Setup Panel", mainWindow, mimgui.WindowFlags.NoCollapse)

    -- Header
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.18, 0.18, 1.0))
    mimgui.Text("▶ YouTube Live Chat Overlay")
    mimgui.PopStyleColor()
    mimgui.TextDisabled("Author: Yohanez")
    mimgui.SameLine()
    -- Badge status config
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

    -- ── Input API Key ────────────────────────────────────────
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.85, 0.3, 1.0))
    mimgui.Text("🔑 YouTube Data API v3 Key:  (disimpan terenkripsi di config.json)")
    mimgui.PopStyleColor()
    mimgui.PushItemWidth(-1)
    -- Password field agar API key tidak terlihat saat mengetik
    mimgui.InputText("##apikey", bufApiKey, 256, mimgui.InputTextFlags.Password)
    mimgui.PopItemWidth()
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.45, 0.65, 1.0, 0.75))
    mimgui.Text("   Dapatkan gratis di: console.cloud.google.com  →  YouTube Data API v3")
    mimgui.PopStyleColor()

    mimgui.Spacing()

    -- ── Input Video URL ──────────────────────────────────────
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.85, 0.3, 1.0))
    mimgui.Text("🔗 Link / URL YouTube Live:")
    mimgui.PopStyleColor()
    mimgui.PushItemWidth(-1)
    mimgui.InputText("##videourl", bufVideoUrl, 512)
    mimgui.PopItemWidth()
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.45, 0.65, 1.0, 0.75))
    mimgui.Text("   Contoh: https://www.youtube.com/watch?v=XXXXXXXXXXX  |  atau youtu.be/XXXXXXX")
    mimgui.PopStyleColor()

    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    -- ── Baris Tombol ────────────────────────────────────────

    -- Tombol SIMPAN CONFIG
    mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.10, 0.35, 0.55, 0.90))
    mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.15, 0.50, 0.78, 0.95))
    if mimgui.Button("💾 Simpan Config", mimgui.ImVec2(140, 34)) then
        local rawKey = ffi.string(bufApiKey):gsub("^%s*(.-)%s*$", "%1")
        local rawUrl = ffi.string(bufVideoUrl):gsub("^%s*(.-)%s*$", "%1")
        if rawKey == "" then
            cfgMsg      = "❌ API Key tidak boleh kosong!"
            cfgMsgColor = { 1.0, 0.3, 0.3 }
        else
            apiKey       = rawKey
            lastVideoUrl = rawUrl
            if saveConfig() then
                cfgMsg      = "✅ Config berhasil disimpan ke config/ytchat/config.json"
                cfgMsgColor = { 0.3, 1.0, 0.45 }
            else
                cfgMsg      = "❌ Gagal menyimpan config!"
                cfgMsgColor = { 1.0, 0.3, 0.3 }
            end
        end
    end
    mimgui.PopStyleColor(2)

    mimgui.SameLine()

    -- Tombol MULAI / STOP
    if not isRunning then
        if mimgui.Button("▶ Mulai", mimgui.ImVec2(110, 34)) and not isFetching then
            local rawKey = ffi.string(bufApiKey):gsub("^%s*(.-)%s*$", "%1")
            local rawUrl = ffi.string(bufVideoUrl):gsub("^%s*(.-)%s*$", "%1")
            local videoId = extractVideoId(rawUrl)

            if rawKey == "" then
                statusMsg = "❌ Masukkan API Key terlebih dahulu!"
            elseif not videoId then
                statusMsg = "❌ URL tidak valid! Pastikan itu link video YouTube Live."
            else
                apiKey       = rawKey
                lastVideoUrl = rawUrl
                -- Auto-save config setiap kali mulai
                saveConfig()
                cfgMsg      = "✅ Config di-auto-save saat mulai."
                cfgMsgColor = { 0.3, 1.0, 0.45 }
                statusMsg   = "Menghubungkan ke YouTube API..."
                fetchLiveChatId(videoId, rawUrl)
            end
        end
    else
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.08, 0.38, 0.08, 0.88))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.12, 0.55, 0.12, 0.95))
        if mimgui.Button("⏹ Stop", mimgui.ImVec2(110, 34)) then
            writeLogSessionFooter()
            isRunning     = false
            liveChatId    = ""
            nextPageToken = ""
            statusMsg     = "Dihentikan."
            addMessage("SYSTEM", "Live Chat dihentikan. Log: logs\\" .. shortPath(currentLogFile), false, false)
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

    mimgui.SameLine()
    if mimgui.Button("🗑 Bersihkan", mimgui.ImVec2(95, 34)) then
        messages = {}
    end

    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    -- ── Info Log & Status ───────────────────────────────────
    -- Status running
    mimgui.PushStyleColor(mimgui.Col.Text,
        isRunning
            and mimgui.ImVec4(0.25, 1.0, 0.35, 1.0)
            or  mimgui.ImVec4(1.0, 0.65, 0.2, 1.0)
    )
    mimgui.Text("Status: " .. statusMsg)
    mimgui.PopStyleColor()

    -- Config feedback message
    if cfgMsg ~= "" then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(cfgMsgColor[1], cfgMsgColor[2], cfgMsgColor[3], 1.0))
        mimgui.Text(cfgMsg)
        mimgui.PopStyleColor()
    end

    mimgui.Spacing()

    -- Info file log
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.55, 0.55, 0.65, 0.85))
    if currentLogFile then
        mimgui.Text("📝 Log: " .. shortPath(currentLogFile) .. "  (" .. totalLoggedMsgs .. " pesan)")
    else
        mimgui.Text("📝 Log: belum ada sesi aktif")
    end

    -- Info config file
    if doesFileExist(cfgFile) then
        mimgui.Text("💾 Config: config.json  (🔒 API Key terenkripsi)")
    end
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

    mimgui.Begin("##YTChatOverlay", overlayWindow, flags)

    -- Header bar
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.22, 0.22, 1.0))
    mimgui.Text("▶ YOUTUBE LIVE CHAT")
    mimgui.PopStyleColor()

    if isRunning then
        mimgui.SameLine()
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.18, 1.0, 0.28, 0.95))
        mimgui.Text(" ● LIVE")
        mimgui.PopStyleColor()
        mimgui.SameLine()
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.5, 0.6, 0.7))
        mimgui.Text("  📝 " .. totalLoggedMsgs .. " logged")
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
    mimgui.BeginChild("##YTMessages", mimgui.ImVec2(-1, -1), false)

    if #messages == 0 then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.45, 0.45, 0.5, 0.65))
        mimgui.Text("Belum ada chat.")
        mimgui.Text("Buka /ytchatpanel → isi API Key & URL → ▶ Mulai")
        mimgui.PopStyleColor()
    else
        for _, msg in ipairs(messages) do
            local c = msg.color

            -- Timestamp kecil
            mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.4, 0.4, 0.5, 0.6))
            mimgui.Text(msg.timeLabel)
            mimgui.PopStyleColor()
            mimgui.SameLine()

            -- Nama Author berwarna
            mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(c[1], c[2], c[3], 1.0))
            mimgui.Text(msg.author .. ":")
            mimgui.PopStyleColor()

            -- Teks pesan
            mimgui.SameLine()
            mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.93, 0.93, 0.93, 1.0))
            mimgui.TextWrapped(msg.text)
            mimgui.PopStyleColor()
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
    repeat wait(0) until isSampAvailable()

    ensureDirs()

    -- Load config tersimpan (API key + last URL)
    if loadConfig() then
        sampAddChatMessage("{FF4444}[YT Chat] {FFFFFF}Config ditemukan & dimuat! API Key sudah terisi.", -1)
    end

    -- /ytchat → toggle overlay chat
    sampRegisterChatCommand("ytchat", function()
        overlayWindow[0] = not overlayWindow[0]
    end)

    -- /ytchatpanel → buka panel setup
    sampRegisterChatCommand("ytchatpanel", function()
        mainWindow[0] = not mainWindow[0]
    end)

    -- /ytoverlay → alias overlay (backward compat)
    sampRegisterChatCommand("ytoverlay", function()
        overlayWindow[0] = not overlayWindow[0]
    end)

    -- /ytlogfolder → buka folder log di Windows Explorer
    sampRegisterChatCommand("ytlogfolder", function()
        ensureDirs()
        os.execute('explorer "' .. logsDir .. '"')
        sampAddChatMessage("{FF4444}[YT Chat] {FFFFFF}Membuka folder log: config/ytchat/logs/", -1)
    end)

    -- /ytclearcfg → hapus config (reset API key)
    sampRegisterChatCommand("ytclearcfg", function()
        if doesFileExist(cfgFile) then
            os.remove(cfgFile)
            apiKey       = ""
            lastVideoUrl = ""
            ffi.copy(bufApiKey,   "")
            ffi.copy(bufVideoUrl, "")
            sampAddChatMessage("{FF4444}[YT Chat] {FFFFFF}Config dihapus! API Key direset.", -1)
        else
            sampAddChatMessage("{FF4444}[YT Chat] {FFFFFF}Tidak ada config yang perlu dihapus.", -1)
        end
    end)

    sampAddChatMessage(
        "{FF4444}[YT Live Chat] {FFFFFF}Loaded! | " ..
        "{FF4444}/ytchat{FFFFFF} = Overlay | " ..
        "{FF4444}/ytchatpanel{FFFFFF} = Setup | " ..
        "{FF4444}/ytlogfolder{FFFFFF} = Buka Folder Log",
        -1
    )

    while true do
        wait(1000)

        if isRunning and not isFetching and liveChatId ~= "" then
            local now = os.time()
            if (now - lastFetchTime) >= POLL_INTERVAL then
                lastFetchTime = now
                fetchChatMessages()
            end
        end
    end
end
