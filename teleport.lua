-- teleport.lua
-- Script teleport ke checkpoint dari file route.json
-- Dibuat untuk GTA SA-MP dengan MoonLoader

script_name("AutoTeleport")
script_author("Custom")
script_description("Teleport ke checkpoint dari file route.json")

require "lib.moonloader"
local json = require "dkjson"
local mimgui = require "lib.mimgui"
local ffi = require "ffi"

-- ============================================================
-- CONFIG
-- ============================================================
local routeFile = getWorkingDirectory() .. "\\config\\route.json"
local checkpoints = {}
local showMenu = mimgui.new.bool(false)

-- Warna
local colorTitle  = mimgui.ImVec4(1.0, 0.8, 0.2, 1.0)  -- Gold
local colorGreen  = mimgui.ImVec4(0.3, 1.0, 0.5, 1.0)  -- Green
local colorWhite  = mimgui.ImVec4(1.0, 1.0, 1.0, 1.0)  -- White

-- ============================================================
-- LOAD CHECKPOINTS DARI FILE
-- ============================================================
local function loadRoute()
    local file = io.open(routeFile, "r")
    if not file then
        sampAddChatMessage("{FF0000}[Teleport] Gagal membuka file route.json: " .. routeFile, -1)
        return false
    end
    local content = file:read("*a")
    file:close()
    local data, _, err = json.decode(content)
    if not data then
        sampAddChatMessage("{FF0000}[Teleport] Error parsing route.json: " .. tostring(err), -1)
        return false
    end
    checkpoints = data
    sampAddChatMessage("{00FF00}[Teleport] Berhasil memuat " .. #checkpoints .. " checkpoint dari route.json", -1)
    return true
end

-- ============================================================
-- FUNGSI TELEPORT
-- ============================================================
local function teleportTo(index)
    if not checkpoints[index] then
        sampAddChatMessage("{FF0000}[Teleport] Checkpoint #" .. index .. " tidak ditemukan.", -1)
        return
    end
    local cp = checkpoints[index]
    local ped = PLAYER_PED
    setCharCoordinates(ped, cp.x, cp.y, cp.z + 1.0)
    sampAddChatMessage(string.format("{00FF00}[Teleport] Teleport ke Checkpoint #%d (X:%.2f Y:%.2f Z:%.2f)", index, cp.x, cp.y, cp.z), -1)
end

-- ============================================================
-- UI MIMGUI
-- ============================================================
mimgui.OnFrame(function() return showMenu[0] end, function()
    local screenW, screenH = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(screenW / 2, screenH / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(380, 460), mimgui.Cond.FirstUseEver)

    mimgui.Begin("🗺 Teleport Checkpoint", showMenu, mimgui.WindowFlags.NoCollapse)

    mimgui.TextColored(colorTitle, "Daftar Checkpoint dari route.json")
    mimgui.Text("Total: " .. #checkpoints .. " titik")
    mimgui.Separator()
    mimgui.Spacing()

    mimgui.BeginChild("CheckpointList", mimgui.ImVec2(0, -50), true)
    for i, cp in ipairs(checkpoints) do
        local label = string.format("#%d  X:%.2f  Y:%.2f  Z:%.2f", i, cp.x, cp.y, cp.z)
        if mimgui.Button(label, mimgui.ImVec2(-1, 28)) then
            teleportTo(i)
            showMenu[0] = false
        end
        mimgui.Spacing()
    end
    mimgui.EndChild()

    mimgui.Spacing()
    if mimgui.Button("Reload route.json", mimgui.ImVec2(175, 30)) then
        loadRoute()
    end
    mimgui.SameLine()
    if mimgui.Button("Tutup", mimgui.ImVec2(-1, 30)) then
        showMenu[0] = false
    end

    mimgui.End()
end)

-- ============================================================
-- MAIN
-- ============================================================
function main()
    while not isSampAvailable() do wait(100) end

    -- Load file route
    loadRoute()

    -- Command: /tp → buka menu
    sampRegisterChatCommand("tp", function()
        showMenu[0] = not showMenu[0]
    end)

    -- Command: /tp <nomor> → teleport langsung ke checkpoint
    sampRegisterChatCommand("tpgo", function(param)
        local index = tonumber(param)
        if not index then
            sampAddChatMessage("{FF0000}[Teleport] Gunakan: /tpgo <nomor checkpoint>", -1)
            return
        end
        teleportTo(index)
    end)

    -- Command: /tpreload → reload file route.json
    sampRegisterChatCommand("tpreload", function()
        loadRoute()
    end)

    -- Command: /tplist → tampilkan daftar di chat
    sampRegisterChatCommand("tplist", function()
        if #checkpoints == 0 then
            sampAddChatMessage("{FF0000}[Teleport] Belum ada checkpoint yang dimuat.", -1)
            return
        end
        sampAddChatMessage("{00FFFF}[Teleport] Daftar Checkpoint:", -1)
        for i, cp in ipairs(checkpoints) do
            sampAddChatMessage(string.format("{FFFFFF}  #%d → X:%.2f  Y:%.2f  Z:%.2f", i, cp.x, cp.y, cp.z), -1)
        end
    end)

    -- Tunggu spawn sebelum tampilkan pesan selamat datang
    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[Teleport] Script dimuat! Commands:", -1)
            sampAddChatMessage("{FFFFFF}  /tp         → Buka menu teleport GUI", -1)
            sampAddChatMessage("{FFFFFF}  /tpgo <no>  → Teleport langsung ke checkpoint", -1)
            sampAddChatMessage("{FFFFFF}  /tplist     → Lihat semua checkpoint di chat", -1)
            sampAddChatMessage("{FFFFFF}  /tpreload   → Reload ulang file route.json", -1)
            break
        end
    end

    while true do wait(1000) end
end
