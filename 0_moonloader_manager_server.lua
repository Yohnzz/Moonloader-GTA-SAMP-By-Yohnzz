-- ============================================================
--  0_MOONLOADER_MANAGER - Server Script Access Control
--  Mengatur hak akses script per server menggunakan config JSON
--  Manager & cmdlist selalu aktif di semua server (tidak bisa diblokir)
-- ============================================================

script_name("Moonloader Manager")
script_author("Yohanez")
script_description("Mengatur hak akses command/script per server via config JSON")

require "lib.moonloader"
local mimgui  = require "mimgui"
local theme   = require "lib.mimgui_theme"
local ffi     = require "ffi"
local json    = require "dkjson"
local sampev  = require "lib.samp.events"

-- ============================================================
-- PATHS
-- ============================================================
local workDir  = getWorkingDirectory()
local cfgDir   = workDir .. "\\config\\manager"
local cfgFile  = cfgDir  .. "\\config.json"

-- ============================================================
-- STATE & GLOBAL ACCESS CONTROL LIST
-- ============================================================
local blockedScripts = {}    -- set nama script yang diblokir untuk server aktif
local activeProfile  = nil   -- nama profil yang sedang aktif
local lastServerKey  = ""
local statusMsg      = "Belum terhubung ke server"

-- ============================================================
-- PEMETAAN COMMAND → NAMA SCRIPT
-- ============================================================
local CMD_OWNERS = {
    -- autowalk
    ["awmenu"]       = "autowalk",
    ["autowalk"]     = "autowalk",
    ["sprint"]       = "autowalk",
    ["createfile"]   = "autowalk",
    ["selectfile"]   = "autowalk",
    ["setcord"]      = "autowalk",
    ["remcord"]      = "autowalk",
    ["setwait"]      = "autowalk",
    ["setclick"]     = "autowalk",
    ["setcdclick"]   = "autowalk",
    ["woodcount"]    = "autowalk",
    ["resetcount"]   = "autowalk",
    ["helpcommand"]  = "autowalk",
    -- autopay
    ["autopay"]      = "autopay",
    -- autoreconnect
    ["rc"]           = "autoreconnect",
    -- detect_id / autoinvoice
    ["autoinvoice"]  = "detect_id",
    -- id_textdraw_check
    ["detector"]     = "id_textdraw_check",
    ["dettd"]        = "id_textdraw_check",
    ["detdialog"]    = "id_textdraw_check",
    ["detrpc"]       = "id_textdraw_check",
    -- kalkulator
    ["kalkulator"]   = "kalkulator",
    -- nametags
    ["nametags"]     = "nametags",
    -- note
    ["note"]         = "note_xixi",
    -- resto
    ["rmenu"]        = "resto",
    ["ropen1"]       = "resto",
    ["ropen2"]       = "resto",
    ["restock"]      = "resto",
    -- teleport
    ["tp"]           = "teleport",
    ["tpgo"]         = "teleport",
    ["tpreload"]     = "teleport",
    ["tplist"]       = "teleport",
    -- ttchat
    ["ttchat"]       = "ttchat",
    ["ttchatpanel"]  = "ttchat",
    ["ttoverlay"]    = "ttchat",
    ["ttlogfolder"]  = "ttchat",
    ["ttclearcfg"]   = "ttchat",
    -- ytchat
    ["ytchat"]       = "ytchat",
    ["ytchatpanel"]  = "ytchat",
    ["ytoverlay"]    = "ytchat",
    ["ytlogfolder"]  = "ytchat",
    ["ytclearcfg"]   = "ytchat",
    -- voice_clear
    ["rvoice"]       = "voice_clear",
    -- workshop
    ["wmenu"]        = "workshop",
    ["wsbuka"]       = "workshop",
    ["wstutup"]      = "workshop",
    ["wsbukaTT"]     = "workshop",
    ["repair"]       = "workshop",
    ["hello"]        = "workshop",
    ["tq"]           = "workshop",
    ["wscmdhelp"]    = "workshop",
    -- kayuafk / medis / disabled scripts
    ["startjob"]     = "kayuafk",
    ["stopjob"]      = "kayuafk",
    ["cpstatus"]     = "kayuafk",
    ["md"]           = "medis",
    ["pbuka"]        = "medis",
    ["ptutup"]       = "medis",
    ["pdarurat"]     = "medis",
    ["ptreatment"]   = "medis",
    ["pcek"]         = "medis",
    ["prk"]          = "medis",
    ["psks"]         = "medis",
    ["pbpjs"]        = "medis",
    ["popersi"]      = "medis",
    ["ppatah"]       = "medis",
    ["psunat"]       = "medis",
    ["pinvoice"]     = "medis",
    ["pcucitangan"]  = "medis",
    ["pdokoperasi"]  = "medis",
    ["pcnormal"]     = "medis",
    ["pcoprasi"]     = "medis",
    ["pck"]          = "medis",
    ["pskstes"]      = "medis",
    ["pskscetak"]    = "medis",
    ["cmdhelp"]      = "medis",
    -- GameFixer
    ["q"]            = "GameFixer",
    ["quit"]         = "GameFixer",
    ["gmenu"]        = "GameFixer",
    -- dmginf
    ["dmginf"]       = "dmginf",
}

-- Script yang SELALU aktif di semua server (tidak bisa diblokir)
local ALWAYS_ALLOWED = {
    ["0_moonloader_manager_server"] = true,
    ["cmdlist"]                     = true,
    ["GameFixer"]                   = true,
    ["autoreconnect"]               = true,
}

-- Daftar semua script yang dikenali (untuk UI checkbox)
local ALL_SCRIPTS = {
    "autowalk", "autopay", "detect_id", "id_textdraw_check",
    "kalkulator", "nametags", "note_xixi", "resto", "teleport",
    "ttchat", "ytchat", "voice_clear", "workshop", "kayuafk",
    "medis", "dmginf", "streamchat",
}

-- ============================================================
-- OVERRIDE sampRegisterChatCommand (INTERSEPTOR LOKAL)
-- ============================================================
local originalRegister = sampRegisterChatCommand
_G.sampRegisterChatCommand = function(cmd, callback)
    if type(callback) ~= "function" then
        return originalRegister(cmd, callback)
    end

    local wrappedCallback = function(params)
        local owner = CMD_OWNERS[cmd:lower()]
        print("[Manager Debug] Command /" .. cmd .. " executed. Owner: " .. tostring(owner))
        if owner and blockedScripts[owner] then
            print("[Manager Debug] Command /" .. cmd .. " is BLOCKED (owner '" .. owner .. "' is in blockedScripts)")
            sampAddChatMessage(
                string.format("{FF4444}[Manager] {FFFFFF}Script '%s' tidak bisa diakses dikarenakan telah dibatasi oleh profil server '%s'.",
                    owner, activeProfile or "Unknown"),
                -1
            )
            return
        end
        return callback(params)
    end
    return originalRegister(cmd, wrappedCallback)
end

-- ============================================================
-- CONFIG JSON
-- ============================================================
local function ensureDir()
    local base = workDir .. "\\config"
    if not doesDirectoryExist(base)   then createDirectory(base) end
    if not doesDirectoryExist(cfgDir) then createDirectory(cfgDir) end
end

local config = { servers = {} }

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
    local f = io.open(cfgFile, "r")
    if not f then return false end
    local raw = f:read("*all")
    f:close()
    if not raw or raw == "" then return false end
    local ok, data = pcall(json.decode, raw)
    if ok and data then
        config = data
        config.servers = config.servers or {}
        return true
    end
    return false
end

-- ============================================================
-- LOGIKA PROFIL SERVER
-- ============================================================
local function applyProfile(serverProfile)
    -- Kosongkan table tanpa membuat objek table baru agar referensi upvalue tetap konsisten
    for k in pairs(blockedScripts) do
        blockedScripts[k] = nil
    end
    
    if not serverProfile then
        activeProfile = nil
        statusMsg = "Tidak ada profil untuk server ini - semua script aktif"
        print("[Manager Debug] applyProfile: serverProfile is nil. All scripts allowed.")
        return
    end
    activeProfile = serverProfile.id or serverProfile.match or "Tanpa Nama"
    print("[Manager Debug] applyProfile: Applying profile '" .. activeProfile .. "'")
    for _, scriptName in ipairs(serverProfile.blocked or {}) do
        if not ALWAYS_ALLOWED[scriptName] then
            blockedScripts[scriptName] = true
            print("[Manager Debug] applyProfile: Blocked script: '" .. scriptName .. "'")
        else
            print("[Manager Debug] applyProfile: Script '" .. scriptName .. "' is ALWAYS_ALLOWED, block ignored.")
        end
    end
    local n = 0
    for _ in pairs(blockedScripts) do n = n + 1 end
    statusMsg = string.format("Profil aktif: %s | %d script dibatasi", activeProfile, n)
    sampAddChatMessage(string.format("{00FFFF}[Manager] {FFFFFF}Profil server '%s' dimuat. %d script dibatasi.", activeProfile, n), -1)
end

local function findProfileForServer(name, addr)
    name = (name or ""):lower()
    addr = (addr or ""):lower()
    print("[Manager Debug] findProfileForServer: name='" .. name .. "', addr='" .. addr .. "'")
    for i, srv in ipairs(config.servers or {}) do
        local m = (srv.match or ""):lower()
        print("[Manager Debug] srv " .. i .. " match pattern: '" .. m .. "'")
        if m ~= "" and (name:find(m, 1, true) or addr:find(m, 1, true)) then
            print("[Manager Debug] MATCH found on srv " .. i .. " (pattern: '" .. m .. "')")
            return srv
        end
    end
    return nil
end

-- ============================================================
-- INTERCEPT SERVER COMMANDS
-- ============================================================
function sampev.onSendCommand(cmdStr)
    if not cmdStr then return end
    -- Cek jika ada tanda slash di depan command (bisa ada atau tidak)
    local cmdName = cmdStr:match("^/?(%S+)")
    if not cmdName then return end
    local owner = CMD_OWNERS[cmdName:lower()]
    print("[Manager Debug] onSendCommand: '" .. cmdStr .. "' -> owner: " .. tostring(owner))
    if owner and blockedScripts[owner] then
        print("[Manager Debug] onSendCommand: '" .. cmdStr .. "' BLOCKED")
        sampAddChatMessage(
            string.format("{FF4444}[Manager] {FFFFFF}Script '%s' tidak bisa diakses dikarenakan telah dibatasi oleh profil server '%s'.",
                owner, activeProfile or "Unknown"),
            -1
        )
        return false
    end
end

-- ============================================================
-- GUI - PANEL UTAMA
-- ============================================================
local showWindow = mimgui.new.bool(false)
local bufMatch = mimgui.new.char[256]("")
local selectedIdx = 1
local cfgMsg = ""
local cfgMsgColor = { 0.3, 1.0, 0.5 }

mimgui.OnFrame(function() return showWindow[0] end, function()
    theme.applyDarkModern()
    local sw, sh = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(sw / 2, sh / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(600, 480), mimgui.Cond.FirstUseEver)

    mimgui.Begin("Moonloader Manager - Server Access Control", showWindow, mimgui.WindowFlags.NoCollapse)
    mimgui.TextDisabled("Author: Yohanez")

    -- Status bar
    local statColor = activeProfile
        and mimgui.ImVec4(0.25, 1.0, 0.35, 1.0)
        or  mimgui.ImVec4(1.0, 0.75, 0.2, 0.9)
    mimgui.PushStyleColor(mimgui.Col.Text, statColor)
    mimgui.Text("Status: " .. statusMsg)
    mimgui.PopStyleColor()
    mimgui.Separator()
    mimgui.Spacing()

    -- ── Kolom Kiri: Daftar Profil Server ─────────────────────
    mimgui.BeginChild("left_col", mimgui.ImVec2(195, 360), true)
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.55, 0.85, 1.0, 1.0))
    mimgui.Text("Profil Server")
    mimgui.PopStyleColor()
    mimgui.Separator()

    if mimgui.Button("+ Tambah Profil", mimgui.ImVec2(-1, 28)) then
        local newId = "server_" .. tostring(#config.servers + 1)
        table.insert(config.servers, { id = newId, match = "", blocked = {} })
        selectedIdx = #config.servers
        ffi.copy(bufMatch, "")
    end
    mimgui.Spacing()
    if mimgui.Button("- Hapus Dipilih", mimgui.ImVec2(-1, 28)) then
        if config.servers[selectedIdx] then
            table.remove(config.servers, selectedIdx)
            if selectedIdx > #config.servers then selectedIdx = math.max(1, #config.servers) end
            if config.servers[selectedIdx] then
                ffi.copy(bufMatch, config.servers[selectedIdx].match or "")
            else
                ffi.copy(bufMatch, "")
            end
        end
    end
    mimgui.Separator()
    mimgui.Spacing()

    if #config.servers == 0 then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.5, 0.5, 0.7))
        mimgui.TextWrapped("Belum ada profil. Klik + Tambah Profil.")
        mimgui.PopStyleColor()
    else
        for i, srv in ipairs(config.servers) do
            local lbl = string.format("%d. %s", i, srv.match ~= "" and srv.match or srv.id or "Kosong")
            if activeProfile and (srv.id == activeProfile or srv.match == activeProfile) then
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.3, 1.0, 0.4, 1.0))
                if mimgui.Selectable("[AKTIF] " .. lbl, selectedIdx == i) then
                    selectedIdx = i
                    ffi.copy(bufMatch, srv.match or "")
                end
                mimgui.PopStyleColor()
            else
                if mimgui.Selectable(lbl, selectedIdx == i) then
                    selectedIdx = i
                    ffi.copy(bufMatch, srv.match or "")
                end
            end
        end
    end
    mimgui.EndChild()

    mimgui.SameLine()

    -- ── Kolom Kanan: Detail Profil ────────────────────────────
    mimgui.BeginChild("right_col", mimgui.ImVec2(0, 360), false)

    if config.servers[selectedIdx] then
        local srv = config.servers[selectedIdx]

        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.55, 0.85, 1.0, 1.0))
        mimgui.Text("Pengaturan Profil: " .. (srv.id or ""))
        mimgui.PopStyleColor()
        mimgui.Separator()
        mimgui.Spacing()

        -- Match keyword
        mimgui.Text("Kata kunci server (nama / IP):")
        mimgui.PushItemWidth(-1)
        if mimgui.InputText("##match", bufMatch, 256) then
            srv.match = ffi.string(bufMatch):gsub("^%s*(.-)%s*$", "%1")
        end
        mimgui.PopItemWidth()

        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.5, 0.6, 0.8))
        mimgui.Text("Contoh: 'mayday', '15.235.128', 'BeratapRP'")
        mimgui.PopStyleColor()

        mimgui.Spacing()
        mimgui.Separator()
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.55, 0.85, 1.0, 1.0))
        mimgui.Text("Script yang DIBLOKIR di server ini:")
        mimgui.PopStyleColor()
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.5, 0.6, 0.8))
        mimgui.Text("(Centang = diblokir. Script default tidak bisa diblokir)")
        mimgui.PopStyleColor()
        mimgui.Spacing()

        srv.blocked = srv.blocked or {}

        mimgui.BeginChild("script_list", mimgui.ImVec2(-1, 175), true)
        for _, scriptName in ipairs(ALL_SCRIPTS) do
            local isAlwaysAllowed = ALWAYS_ALLOWED[scriptName]
            if isAlwaysAllowed then
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.4, 0.7, 0.4, 0.7))
                mimgui.Text("  [Selalu Aktif] " .. scriptName)
                mimgui.PopStyleColor()
            else
                local isBlocked = false
                local blockedIdx = nil
                for bi, bn in ipairs(srv.blocked) do
                    if bn == scriptName then
                        isBlocked = true
                        blockedIdx = bi
                        break
                    end
                end

                local chk = mimgui.new.bool(isBlocked)
                if mimgui.Checkbox(scriptName, chk) then
                    if chk[0] then
                        table.insert(srv.blocked, scriptName)
                    else
                        if blockedIdx then
                            table.remove(srv.blocked, blockedIdx)
                        end
                    end
                end
                if isBlocked then
                    mimgui.SameLine()
                    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(1.0, 0.35, 0.35, 0.85))
                    mimgui.Text("  [Diblokir]")
                    mimgui.PopStyleColor()
                end
            end
        end
        mimgui.EndChild()

        mimgui.Spacing()

        -- Tombol Aksi
        if mimgui.Button("Simpan Config", mimgui.ImVec2(120, 30)) then
            srv.match = ffi.string(bufMatch):gsub("^%s*(.-)%s*$", "%1")
            if saveConfig() then
                cfgMsg = "Config berhasil disimpan!"
                cfgMsgColor = { 0.3, 1.0, 0.5 }
            else
                cfgMsg = "Gagal menyimpan config!"
                cfgMsgColor = { 1.0, 0.3, 0.3 }
            end
        end

        mimgui.SameLine()

        if mimgui.Button("Simpan & Terapkan", mimgui.ImVec2(150, 30)) then
            srv.match = ffi.string(bufMatch):gsub("^%s*(.-)%s*$", "%1")
            saveConfig()
            applyProfile(srv)
            cfgMsg = "Diterapkan untuk profil: " .. (srv.match or srv.id or "")
            cfgMsgColor = { 0.3, 1.0, 0.5 }
        end

        mimgui.SameLine()

        if mimgui.Button("Reset (Semua Aktif)", mimgui.ImVec2(155, 30)) then
            srv.blocked = {}
            saveConfig()
            applyProfile(srv)
            cfgMsg = "Semua script diizinkan untuk profil ini."
            cfgMsgColor = { 0.3, 1.0, 0.5 }
        end

        if cfgMsg ~= "" then
            mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(cfgMsgColor[1], cfgMsgColor[2], cfgMsgColor[3], 1.0))
            mimgui.Text(cfgMsg)
            mimgui.PopStyleColor()
        end
    else
        mimgui.Text("Tidak ada profil yang dipilih.")
        mimgui.Text("Klik '+ Tambah Profil' di sebelah kiri.")
    end

    mimgui.EndChild()
    mimgui.End()
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
function main()
    while not isSampAvailable() do wait(100) end

    ensureDir()
    loadConfig()

    -- Sync buffer match untuk profil pertama
    if config.servers[selectedIdx] then
        ffi.copy(bufMatch, config.servers[selectedIdx].match or "")
    end

    sampRegisterChatCommand("ml", function()
        showWindow[0] = not showWindow[0]
    end)

    sampAddChatMessage("{00FFFF}[Manager] {FFFFFF}Loaded! Ketik {00FFFF}/ml{FFFFFF} untuk mengatur akses script per server.", -1)

    while true do
        wait(1500)
        if isSampAvailable() then
            local name = sampGetCurrentServerName() or ""
            local addr = sampGetCurrentServerAddress() or ""
            local key  = name .. "|" .. addr
            if key ~= lastServerKey then
                lastServerKey = key
                local profile = findProfileForServer(name, addr)
                applyProfile(profile)
            end
        end
    end
end

function onScriptTerminate(script)
    if script == thisScript() then
        -- Tidak menyimpan secara otomatis pada terminate untuk mencegah penimpaan file config manual
    end
end
