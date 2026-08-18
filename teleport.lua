-- teleport.lua
-- Enhanced script: CRUD for teleport checkpoints with custom names and Dark Modern mimgui UI
-- Created for GTA SA-MP with MoonLoader

script_name("AutoTeleport")
script_author("Yohanez")
script_description("Teleport ke checkpoint dengan CRUD, Search Bar, dan Dark Modern UI")

require "lib.moonloader"
local json   = require "dkjson"
local mimgui = require "lib.mimgui"
local ffi    = require "ffi"

-- ============================================================
-- CONFIG & PATHS
-- ============================================================
local configDir       = getWorkingDirectory() .. "\\config\\teleport"
local routeFile       = configDir .. "\\route.json"
local legacyRouteFile = getWorkingDirectory() .. "\\config\\route.json"

local checkpoints = {}
local showMenu    = mimgui.new.bool(false)

-- Buffers UI
local searchBuf  = mimgui.new.char[128]()
local newNameBuf = mimgui.new.char[128]()
local newLocBuf  = mimgui.new.char[128]()
local editingIdx = -1

-- ============================================================
-- HELPERS
-- ============================================================
local function ensureConfigDir()
    if not doesDirectoryExist(configDir) then
        createDirectory(configDir)
    end
end

local function saveRoute()
    ensureConfigDir()
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
    ensureConfigDir()
    local targetFile = routeFile
    local file = io.open(targetFile, "r")
    if not file then
        file = io.open(legacyRouteFile, "r")
        if file then
            targetFile = legacyRouteFile
        else
            sampAddChatMessage("{FF0000}[Teleport] Gagal membuka file route.json", -1)
            return false
        end
    end
    local content = file:read("*a")
    file:close()
    local data, _, err = json.decode(content)
    if not data then
        sampAddChatMessage("{FF0000}[Teleport] Error parsing route.json: " .. tostring(err), -1)
        return false
    end

    checkpoints = {}
    for i, cp in ipairs(data) do
        if cp.name == nil then
            cp.name = "Checkpoint #" .. i
        end
        checkpoints[i] = { name = cp.name, x = cp.x, y = cp.y, z = cp.z }
    end
    sampAddChatMessage("{00FF00}[Teleport] Berhasil memuat " .. #checkpoints .. " checkpoint", -1)

    if targetFile == legacyRouteFile then
        saveRoute()
    end
    return true
end

local function parseLocation(str)
    if not str or str == "" then return nil end
    local x, y, z = str:match("([%d%.%-]+)%s*[,%s]%s*([%d%.%-]+)%s*[,%s]%s*([%d%.%-]+)")
    if x and y and z then
        return tonumber(x), tonumber(y), tonumber(z)
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
-- DARK MODERN STYLING
-- ============================================================
local darkThemeInitialized = false
local function applyDarkTheme()
    if darkThemeInitialized then return end
    darkThemeInitialized = true

    local style = mimgui.GetStyle()
    local colors = style.Colors

    style.WindowRounding    = 8.0
    style.ChildRounding     = 6.0
    style.FrameRounding     = 5.0
    style.PopupRounding     = 6.0
    style.ScrollbarRounding = 6.0
    style.GrabRounding      = 4.0
    style.TabRounding       = 5.0
    style.WindowBorderSize  = 1.0
    style.FrameBorderSize   = 0.0
    style.ItemSpacing       = mimgui.ImVec2(8, 6)
    style.ItemInnerSpacing  = mimgui.ImVec2(6, 4)

    colors[mimgui.Col.WindowBg]           = mimgui.ImVec4(0.11, 0.11, 0.13, 0.98)
    colors[mimgui.Col.ChildBg]            = mimgui.ImVec4(0.08, 0.08, 0.10, 0.95)
    colors[mimgui.Col.PopupBg]            = mimgui.ImVec4(0.13, 0.13, 0.16, 0.98)
    colors[mimgui.Col.Border]             = mimgui.ImVec4(0.22, 0.22, 0.25, 0.60)
    colors[mimgui.Col.FrameBg]            = mimgui.ImVec4(0.16, 0.16, 0.19, 1.00)
    colors[mimgui.Col.FrameBgHovered]     = mimgui.ImVec4(0.22, 0.22, 0.26, 1.00)
    colors[mimgui.Col.FrameBgActive]      = mimgui.ImVec4(0.28, 0.28, 0.34, 1.00)
    colors[mimgui.Col.TitleBg]            = mimgui.ImVec4(0.09, 0.09, 0.11, 1.00)
    colors[mimgui.Col.TitleBgActive]      = mimgui.ImVec4(0.12, 0.12, 0.15, 1.00)
    colors[mimgui.Col.Button]             = mimgui.ImVec4(0.20, 0.22, 0.26, 1.00)
    colors[mimgui.Col.ButtonHovered]      = mimgui.ImVec4(0.28, 0.32, 0.40, 1.00)
    colors[mimgui.Col.ButtonActive]       = mimgui.ImVec4(0.35, 0.40, 0.50, 1.00)
    colors[mimgui.Col.Header]             = mimgui.ImVec4(0.16, 0.18, 0.22, 1.00)
    colors[mimgui.Col.HeaderHovered]      = mimgui.ImVec4(0.24, 0.28, 0.35, 1.00)
    colors[mimgui.Col.HeaderActive]       = mimgui.ImVec4(0.30, 0.36, 0.45, 1.00)
    colors[mimgui.Col.Separator]          = mimgui.ImVec4(0.22, 0.22, 0.26, 0.80)
end

-- ============================================================
-- UI (ImGui OnFrame)
-- ============================================================
mimgui.OnFrame(function() return showMenu[0] end, function()
    applyDarkTheme()

    local screenW, screenH = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(screenW / 2, screenH / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(520, 480), mimgui.Cond.FirstUseEver)
    
    mimgui.Begin("Teleport Manager (CRUD)", showMenu, mimgui.WindowFlags.NoCollapse)
    mimgui.TextDisabled("Author: Yohanez")
    mimgui.Spacing()
    mimgui.SetNextItemWidth(-1)
    mimgui.InputTextWithHint("##search", "Search...", searchBuf, 127)
    mimgui.Spacing()

    -- 2. TABEL INTERAKTIF CHECKPOINT
    local searchStr = ffi.string(searchBuf):lower()
    
    mimgui.BeginChild("TableChild", mimgui.ImVec2(0, 240), true)
    
    -- Table Header
    mimgui.Columns(4, "CPTable", true)
    mimgui.SetColumnWidth(0, 35)   -- ID
    mimgui.SetColumnWidth(1, 140)  -- Name
    mimgui.SetColumnWidth(2, 190)  -- Location
    mimgui.SetColumnWidth(3, 115)  -- Actions

    mimgui.TextColored(mimgui.ImVec4(0.7, 0.7, 0.75, 1.0), "ID")
    mimgui.NextColumn()
    mimgui.TextColored(mimgui.ImVec4(0.7, 0.7, 0.75, 1.0), "Name")
    mimgui.NextColumn()
    mimgui.TextColored(mimgui.ImVec4(0.7, 0.7, 0.75, 1.0), "Location")
    mimgui.NextColumn()
    mimgui.TextColored(mimgui.ImVec4(0.7, 0.7, 0.75, 1.0), "Actions")
    mimgui.NextColumn()
    mimgui.Separator()

    for i, cp in ipairs(checkpoints) do
        if searchStr == "" or cp.name:lower():find(searchStr, 1, true) then
            -- Column 0: ID
            mimgui.Text(tostring(i))
            mimgui.NextColumn()

            -- Column 1: Name
            mimgui.Text(cp.name)
            mimgui.NextColumn()

            -- Column 2: Location (e.g. name: -484.485...)
            mimgui.TextDisabled(string.format("name: %.3f", cp.x))
            if mimgui.IsItemHovered() then
                mimgui.SetTooltip(string.format("X: %.3f\nY: %.3f\nZ: %.3f", cp.x, cp.y, cp.z))
            end
            mimgui.NextColumn()

            -- Column 3: Actions (Go, Edit ✏, Delete 🗑)
            -- Go Button (Blue)
            mimgui.PushStyleColor(mimgui.Col.Button, mimgui.ImVec4(0.18, 0.38, 0.68, 1.0))
            mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.25, 0.48, 0.82, 1.0))
            if mimgui.Button("Go##"..i, mimgui.ImVec2(30, 22)) then
                teleportTo(i)
            end
            mimgui.PopStyleColor(2)

            -- Edit Button (Pencil Icon)
            mimgui.SameLine()
            if mimgui.Button("✏##"..i, mimgui.ImVec2(24, 22)) then
                editingIdx = i
                ffi.copy(newNameBuf, cp.name)
                ffi.copy(newLocBuf, string.format("%.3f, %.3f, %.3f", cp.x, cp.y, cp.z))
            end
            if mimgui.IsItemHovered() then
                mimgui.SetTooltip("Edit checkpoint ini")
            end

            -- Delete Button (Red)
            mimgui.SameLine()
            mimgui.PushStyleColor(mimgui.Col.Button, mimgui.ImVec4(0.58, 0.18, 0.18, 1.0))
            mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.78, 0.22, 0.22, 1.0))
            if mimgui.Button("🗑##"..i, mimgui.ImVec2(24, 22)) then
                deleteCheckpoint(i)
                if editingIdx == i then
                    editingIdx = -1
                    ffi.copy(newNameBuf, "")
                    ffi.copy(newLocBuf, "")
                end
            end
            mimgui.PopStyleColor(2)
            if mimgui.IsItemHovered() then
                mimgui.SetTooltip("Hapus checkpoint ini")
            end

            mimgui.NextColumn()
        end
    end

    mimgui.Columns(1)
    mimgui.EndChild()

    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Spacing()

    -- 3. FORM TAMBAH / EDIT CHECKPOINT BARU
    mimgui.TextColored(mimgui.ImVec4(0.9, 0.9, 0.9, 1.0), editingIdx > 0 and ("Edit Checkpoint #" .. editingIdx) or "Tambah Checkpoint Baru")
    mimgui.Spacing()

    -- Input Fields: Nama & Location
    mimgui.Text("Nama:")
    mimgui.SameLine()
    mimgui.SetNextItemWidth(170)
    mimgui.InputText("##newName", newNameBuf, 127)

    mimgui.SameLine()
    mimgui.Text("Location")
    mimgui.SameLine()
    mimgui.SetNextItemWidth(160)
    mimgui.InputTextWithHint("##newLoc", "-484.485, 120.100, 15.200", newLocBuf, 127)

    -- Tombol "+" Ambil Posisi Player
    mimgui.SameLine()
    mimgui.PushStyleColor(mimgui.Col.Button, mimgui.ImVec4(0.20, 0.32, 0.50, 1.0))
    mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.28, 0.42, 0.65, 1.0))
    if mimgui.Button("+##getpos", mimgui.ImVec2(26, 24)) then
        local ped = PLAYER_PED
        local cx, cy, cz = getCharCoordinates(ped)
        local locStr = string.format("%.3f, %.3f, %.3f", cx, cy, cz)
        ffi.copy(newLocBuf, locStr)
    end
    mimgui.PopStyleColor(2)

    -- Tooltip saat tombol + di-hover
    if mimgui.IsItemHovered() then
        mimgui.SetTooltip("ambil data coordinat posisi player sekarang")
    end

    mimgui.Spacing()
    mimgui.Spacing()

    -- 4. TOMBOL EKSEKUSI & MENYIMPAN (BOTTOM ACTIONS)
    -- Left Button: Reload route.json
    if mimgui.Button("🔄 Reload route json", mimgui.ImVec2(150, 28)) then
        loadRoute()
    end

    -- Right Buttons: + Add New / Simpan & Close
    mimgui.SameLine()
    mimgui.SetCursorPosX(mimgui.GetWindowWidth() - 200)

    -- Add New / Simpan Button (Blue Accent)
    mimgui.PushStyleColor(mimgui.Col.Button, mimgui.ImVec4(0.18, 0.38, 0.68, 1.0))
    mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.25, 0.48, 0.82, 1.0))
    local btnLabel = editingIdx > 0 and "💾 Simpan" or "+ Add New"
    if mimgui.Button(btnLabel, mimgui.ImVec2(95, 28)) then
        local nameStr = ffi.string(newNameBuf)
        local locStr  = ffi.string(newLocBuf)
        
        -- Fallback koordinat dari posisi player jika location kosong
        local x, y, z = parseLocation(locStr)
        if not x or not y or not z then
            local ped = PLAYER_PED
            x, y, z = getCharCoordinates(ped)
        end

        if nameStr == "" then
            nameStr = editingIdx > 0 and checkpoints[editingIdx].name or ("Checkpoint #" .. (#checkpoints + 1))
        end

        if editingIdx > 0 then
            editCheckpoint(editingIdx, nameStr, x, y, z)
            editingIdx = -1
        else
            addCheckpoint(nameStr, x, y, z)
        end

        ffi.copy(newNameBuf, "")
        ffi.copy(newLocBuf, "")
    end
    mimgui.PopStyleColor(2)

    -- Close Button
    mimgui.SameLine()
    if mimgui.Button("✕ Close", mimgui.ImVec2(85, 28)) then
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

    -- Add checkpoint via chat (manual coordinates)
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
            sampAddChatMessage("{FFFFFF}  /tpcord <nama> → Tambah checkpoint dari posisi saat ini", -1)
            sampAddChatMessage("{FFFFFF}  /tpadd <name> <x> <y> <z> → Tambah checkpoint manual", -1)
            sampAddChatMessage("{FFFFFF}  /tpedit <n> <name> <x> <y> <z> → Edit checkpoint", -1)
            sampAddChatMessage("{FFFFFF}  /tpdel <n>  → Hapus checkpoint", -1)
            sampAddChatMessage("{FFFFFF}  /tplist     → List checkpoint di chat", -1)
            sampAddChatMessage("{FFFFFF}  /tpreload   → Reload route.json", -1)
            break
        end
    end

    while true do wait(1000) end
end
