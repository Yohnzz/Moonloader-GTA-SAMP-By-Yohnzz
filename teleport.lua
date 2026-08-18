-- teleport.lua
-- Enhanced script: CRUD for teleport checkpoints with custom names
-- Created for GTA SA-MP with MoonLoader

script_name("AutoTeleport")
script_author("Custom")
script_description("Teleport ke checkpoint dengan CRUD dan nama kustom")

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

-- Colors
local colorTitle  = mimgui.ImVec4(1.0, 0.8, 0.2, 1.0)  -- Gold
local colorGreen  = mimgui.ImVec4(0.3, 1.0, 0.5, 1.0)  -- Green
local colorWhite  = mimgui.ImVec4(1.0, 1.0, 1.0, 1.0)  -- White

-- ============================================================
-- HELPERS
-- ============================================================
local function saveRoute()
    local file, err = io.open(routeFile, "w")
    if not file then
        sampAddChatMessage("{FF0000}[Teleport] Gagal menulis route.json: " .. tostring(err), -1)
        return false
    end
    local content = json.encode(checkpoints, { indent = true })
    file:write(content)
    file:close()
    sampAddChatMessage("{00FF00}[Teleport] route.json tersimpan.", -1)
    return true
end

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
    -- Migrate legacy format (array of {x,y,z}) to include name
    checkpoints = {}
    for i, cp in ipairs(data) do
        if cp.name == nil then
            cp.name = "Checkpoint #" .. i
        end
        checkpoints[i] = { name = cp.name, x = cp.x, y = cp.y, z = cp.z }
    end
    sampAddChatMessage("{00FF00}[Teleport] Berhasil memuat " .. #checkpoints .. " checkpoint dari route.json", -1)
    return true
end

local function findIndexByName(name)
    for i, cp in ipairs(checkpoints) do
        if cp.name == name then return i end
    end
    return nil
end

-- ============================================================
-- CRUD OPERATIONS
-- ============================================================
local function addCheckpoint(name, x, y, z)
    table.insert(checkpoints, { name = name, x = x, y = y, z = z })
    saveRoute()
    sampAddChatMessage(string.format("{00FF00}[Teleport] Tambah checkpoint '%s' (X:%.2f Y:%.2f Z:%.2f)", name, x, y, z), -1)
end

local function editCheckpoint(index, newName, x, y, z)
    if not checkpoints[index] then
        sampAddChatMessage("{FF0000}[Teleport] Checkpoint #"..index.." tidak ditemukan.", -1)
        return
    end
    local cp = checkpoints[index]
    cp.name = newName or cp.name
    cp.x = x or cp.x
    cp.y = y or cp.y
    cp.z = z or cp.z
    saveRoute()
    sampAddChatMessage(string.format("{00FF00}[Teleport] Edit checkpoint #%d menjadi '%s' (X:%.2f Y:%.2f Z:%.2f)", index, cp.name, cp.x, cp.y, cp.z), -1)
end

local function deleteCheckpoint(index)
    if not checkpoints[index] then
        sampAddChatMessage("{FF0000}[Teleport] Checkpoint #"..index.." tidak ditemukan.", -1)
        return
    end
    local name = checkpoints[index].name
    table.remove(checkpoints, index)
    saveRoute()
    sampAddChatMessage(string.format("{00FF00}[Teleport] Hapus checkpoint #%d ('%s')", index, name), -1)
end

-- ============================================================
-- TELEPORT FUNCTION
-- ============================================================
local function teleportTo(index)
    local cp = checkpoints[index]
    if not cp then
        sampAddChatMessage("{FF0000}[Teleport] Checkpoint #"..index.." tidak ditemukan.", -1)
        return
    end
    local ped = PLAYER_PED
    setCharCoordinates(ped, cp.x, cp.y, cp.z + 1.0)
    sampAddChatMessage(string.format("{00FF00}[Teleport] Teleport ke '%s' (X:%.2f Y:%.2f Z:%.2f)", cp.name, cp.x, cp.y, cp.z), -1)
end

-- ============================================================
-- UI (ImGui)
-- ============================================================
mimgui.OnFrame(function() return showMenu[0] end, function()
    local screenW, screenH = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(screenW / 2, screenH / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(420, 520), mimgui.Cond.FirstUseEver)
    mimgui.Begin("🗺 Teleport Manager", showMenu, mimgui.WindowFlags.NoCollapse)

    mimgui.TextColored(colorTitle, "Daftar Checkpoint (CRUD)")
    mimgui.Separator()
    mimgui.Spacing()

    -- List existing checkpoints with edit fields
    mimgui.BeginChild("CheckpointList", mimgui.ImVec2(0, -120), true)
    for i, cp in ipairs(checkpoints) do
        -- use unique IDs via label suffix
        local nameBuf = mimgui.new.char[64]()
        ffi.copy(nameBuf, cp.name)
        local xBuf = mimgui.new.float(cp.x)
        local yBuf = mimgui.new.float(cp.y)
        local zBuf = mimgui.new.float(cp.z)
        mimgui.InputText("Name##"..i, nameBuf, 63)
        mimgui.SameLine()
        mimgui.InputFloat("X##"..i, xBuf, 0.0, 0.0, "%.3f")
        mimgui.SameLine()
        mimgui.InputFloat("Y##"..i, yBuf, 0.0, 0.0, "%.3f")
        mimgui.SameLine()
        mimgui.InputFloat("Z##"..i, zBuf, 0.0, 0.0, "%.3f")
        mimgui.SameLine()
        if mimgui.Button("Save##"..i) then
            editCheckpoint(i, ffi.string(nameBuf), xBuf[0], yBuf[0], zBuf[0])
        end
        mimgui.SameLine()
        if mimgui.Button("Delete##"..i) then
            deleteCheckpoint(i)
        end
        mimgui.Spacing()
    end
    mimgui.EndChild()

    mimgui.Spacing()
    -- Add new checkpoint section
    mimgui.TextColored(colorGreen, "Tambah Checkpoint Baru")
    local newName = mimgui.new.char[64]()
    local newX = mimgui.new.float(0.0)
    local newY = mimgui.new.float(0.0)
    local newZ = mimgui.new.float(0.0)
    mimgui.InputText("Name##new", newName, 63)
    mimgui.SameLine()
    mimgui.InputFloat("X##new", newX, 0.0, 0.0, "%.3f")
    mimgui.SameLine()
    mimgui.InputFloat("Y##new", newY, 0.0, 0.0, "%.3f")
    mimgui.SameLine()
    mimgui.InputFloat("Z##new", newZ, 0.0, 0.0, "%.3f")
    mimgui.SameLine()
    if mimgui.Button("Add##new") then
        local nameStr = ffi.string(newName)
        if nameStr == "" then nameStr = "Checkpoint #"..(#checkpoints+1) end
        addCheckpoint(nameStr, newX[0], newY[0], newZ[0])
    end
    mimgui.SameLine()
    if mimgui.Button("Current##new") then
        local nameStr = ffi.string(newName)
        if nameStr == "" then nameStr = "Checkpoint #"..(#checkpoints+1) end
        local ped = PLAYER_PED
        local cx, cy, cz = getCharCoordinates(ped)
        addCheckpoint(nameStr, cx, cy, cz)
    end

    mimgui.Spacing()
    if mimgui.Button("Reload route.json", mimgui.ImVec2(150, 30)) then
        loadRoute()
    end
    mimgui.SameLine()
    if mimgui.Button("Close", mimgui.ImVec2(-1, 30)) then
        showMenu[0] = false
    end

    mimgui.End()
end)

-- ============================================================
-- CHAT COMMANDS
-- ============================================================
function main()
    while not isSampAvailable() do wait(100) end
    loadRoute()

    -- Toggle UI
    sampRegisterChatCommand("tp", function()
        showMenu[0] = not showMenu[0]
    end)

    -- Direct teleport by index
    sampRegisterChatCommand("tpgo", function(param)
        local idx = tonumber(param)
        if idx then teleportTo(idx) else sampAddChatMessage("{FF0000}[Teleport] Gunakan: /tpgo <index>", -1) end
    end)

    -- Add checkpoint via chat
    sampRegisterChatCommand("tpadd", function(param)
        local name, x, y, z = param:match("^(%S+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)$")
        if name and x and y and z then
            addCheckpoint(name, tonumber(x), tonumber(y), tonumber(z))
        else
            sampAddChatMessage("{FF0000}[Teleport] Gunakan: /tpadd <name> <x> <y> <z>", -1)
        end
    end)
    
    -- Add checkpoint via current position (name only)
    sampRegisterChatCommand("tpcord", function(param)
        local name = param:match("^(%S+)$")
        if not name or name == "" then
            sampAddChatMessage("{FF0000}[Teleport] Gunakan: /tpcord <nama>", -1)
            return
        end
        local ped = PLAYER_PED
        local cx, cy, cz = getCharCoordinates(ped)
        addCheckpoint(name, cx, cy, cz)
    end)

    -- Edit checkpoint via chat
    sampRegisterChatCommand("tpedit", function(param)
        local idx, name, x, y, z = param:match("^(%d+)%s+(%S+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)$")
        if idx and name and x and y and z then
            editCheckpoint(tonumber(idx), name, tonumber(x), tonumber(y), tonumber(z))
        else
            sampAddChatMessage("{FF0000}[Teleport] Gunakan: /tpedit <index> <name> <x> <y> <z>", -1)
        end
    end)

    -- Delete checkpoint via chat
    sampRegisterChatCommand("tpdel", function(param)
        local idx = tonumber(param)
        if idx then deleteCheckpoint(idx) else sampAddChatMessage("{FF0000}[Teleport] Gunakan: /tpdel <index>", -1) end
    end)

    -- List checkpoints in chat
    sampRegisterChatCommand("tplist", function()
        if #checkpoints == 0 then
            sampAddChatMessage("{FF0000}[Teleport] Tidak ada checkpoint.", -1)
            return
        end
        sampAddChatMessage("{00FFFF}[Teleport] Daftar Checkpoint:", -1)
        for i, cp in ipairs(checkpoints) do
            sampAddChatMessage(string.format("{FFFFFF}  #%d '%s' → X:%.2f Y:%.2f Z:%.2f", i, cp.name, cp.x, cp.y, cp.z), -1)
        end
    end)

    -- Reload command
    sampRegisterChatCommand("tpreload", function()
        loadRoute()
    end)

    -- Welcome messages
    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[Teleport] Script dimuat! Commands:", -1)
            sampAddChatMessage("{FFFFFF}  /tp         → Buka menu teleport GUI", -1)
            sampAddChatMessage("{FFFFFF}  /tpgo <n>   → Teleport langsung ke checkpoint #n", -1)
            sampAddChatMessage("{FFFFFF}  /tpadd <name> <x> <y> <z> → Tambah checkpoint", -1)
            sampAddChatMessage("{FFFFFF}  /tpedit <n> <name> <x> <y> <z> → Edit checkpoint", -1)
            sampAddChatMessage("{FFFFFF}  /tpdel <n>  → Hapus checkpoint", -1)
            sampAddChatMessage("{FFFFFF}  /tplist     → List checkpoint di chat", -1)
            sampAddChatMessage("{FFFFFF}  /tpreload   → Reload route.json", -1)
            break
        end
    end

    while true do wait(1000) end
end
