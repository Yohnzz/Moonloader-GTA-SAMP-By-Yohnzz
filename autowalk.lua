-- ============================================================
--  AUTOWALK.LUA - MoonLoader SA-MP
--  Berjalan otomatis mengikuti koordinat dari file JSON
--  + GUI Manager file, toggle sprint/walk
-- ============================================================

script_name("autowalk.lua")
script_author("Yohanez")

require "lib.moonloader"
local json    = require "dkjson"
local sampev  = require "lib.samp.events"
local mimgui  = require "mimgui"
local theme   = require "lib.mimgui_theme"
local ffi     = require "ffi"

-- ============================================================
-- STATE
-- ============================================================
local enabled       = false
local selectedFile  = nil
local coordinates   = {}
local waitTime      = 8000      -- ms antar titik
local clickKeyName  = nil
local clickKey      = nil
local clickDelay    = 0
local woodCount     = 0
local isSprint      = false     -- mode sprint global (bisa toggle via /sprint)

local basePath = getWorkingDirectory() .. "\\config\\autowalk"

-- ============================================================
-- GUI STATE
-- ============================================================
local showMenu      = mimgui.new.bool(false)
local bufNewFile    = mimgui.new.char[128]("")   -- input nama file baru
local fileList      = {}                          -- daftar file JSON di folder
local selectedIdx   = 0                           -- indeks file yang di-highlight di GUI
local guiMsg        = ""                          -- pesan status di bawah GUI
local guiMsgTimer   = 0

-- ============================================================
-- HELPERS
-- ============================================================

local function ensureDirectoryExists(path)
    if not doesDirectoryExist(path) then
        local ok = createDirectory(path)
        if not ok then
            sampAddChatMessage("{FF0000}[AUTOWALK] Gagal buat direktori: " .. path, -1)
            return false
        end
    end
    return true
end

local function getKeyFromName(name)
    name = string.lower(name)
    if #name == 1 then return string.byte(string.upper(name))
    elseif name == "enter" or name == "return" then return 0x0D
    elseif name == "space"  then return 0x20
    elseif name == "shift"  then return 0x10
    elseif name == "ctrl" or name == "control" then return 0x11
    elseif name == "alt"    then return 0x12
    end
    return nil
end

local function pressKey(vkCode)
    if not vkCode then return end
    setVirtualKeyDown(vkCode, true)
    wait(50)
    setVirtualKeyDown(vkCode, false)
end

-- Simpan data ke file yang sedang aktif
local function saveCurrentFile()
    if not selectedFile then return false end
    local f = io.open(selectedFile, "w")
    if f then
        f:write(json.encode({
            points       = coordinates,
            waitTime     = waitTime,
            clickKeyName = clickKeyName,
            clickDelay   = clickDelay,
            isSprint     = isSprint,
        }))
        f:close()
        return true
    end
    return false
end

-- Ambil nama file dari path lengkap
local function basename(path)
    return path:match("([^\\]+)$") or path
end

-- ============================================================
-- FILE LIST SCANNER
-- ============================================================
local function scanFileList()
    fileList = {}
    ensureDirectoryExists(basePath)
    -- Menggunakan API native Moonloader untuk menghindari window minimization akibat io.popen/cmd.exe
    local searchPath = basePath .. "\\*.json"
    local handle, file = findFirstFile(searchPath)
    if handle and handle ~= -1 then
        while file do
            table.insert(fileList, {
                name = file,
                path = basePath .. "\\" .. file,
            })
            file = findNextFile(handle)
        end
        findClose(handle)
    end
end

-- Load file berdasarkan path
local function loadFile(path)
    local f = io.open(path, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    local data = json.decode(content)
    if not data then return false end
    coordinates  = data.points or {}
    waitTime     = data.waitTime or 8000
    clickKeyName = data.clickKeyName or nil
    clickDelay   = data.clickDelay or 0
    isSprint     = data.isSprint or false
    if clickKeyName then
        clickKey = getKeyFromName(clickKeyName)
    else
        clickKey = nil
    end
    selectedFile = path
    return true
end

-- Hapus file
local function deleteFile(path)
    os.remove(path)
end

-- ============================================================
-- GUI STYLE
-- ============================================================
local function applyStyle()
    local style = mimgui.GetStyle()
    style.WindowRounding  = 8.0
    style.FrameRounding   = 5.0
    style.GrabRounding    = 4.0
    style.WindowBorderSize = 1.0

    local col = style.Colors
    col[mimgui.Col.WindowBg]        = mimgui.ImVec4(0.05, 0.05, 0.10, 0.94)
    col[mimgui.Col.Border]          = mimgui.ImVec4(0.3, 0.8, 0.4, 0.5)
    col[mimgui.Col.TitleBg]         = mimgui.ImVec4(0.05, 0.18, 0.05, 1.0)
    col[mimgui.Col.TitleBgActive]   = mimgui.ImVec4(0.05, 0.35, 0.08, 1.0)
    col[mimgui.Col.Button]          = mimgui.ImVec4(0.10, 0.40, 0.12, 0.85)
    col[mimgui.Col.ButtonHovered]   = mimgui.ImVec4(0.15, 0.60, 0.18, 0.90)
    col[mimgui.Col.ButtonActive]    = mimgui.ImVec4(0.08, 0.28, 0.10, 1.00)
    col[mimgui.Col.FrameBg]         = mimgui.ImVec4(0.08, 0.10, 0.08, 0.90)
    col[mimgui.Col.FrameBgHovered]  = mimgui.ImVec4(0.12, 0.20, 0.12, 1.0)
    col[mimgui.Col.Header]          = mimgui.ImVec4(0.10, 0.40, 0.12, 0.70)
    col[mimgui.Col.HeaderHovered]   = mimgui.ImVec4(0.15, 0.55, 0.18, 0.85)
    col[mimgui.Col.HeaderActive]    = mimgui.ImVec4(0.12, 0.48, 0.14, 1.00)
    col[mimgui.Col.Separator]       = mimgui.ImVec4(0.3, 0.8, 0.4, 0.3)
    col[mimgui.Col.CheckMark]       = mimgui.ImVec4(0.3, 1.0, 0.4, 1.0)
    col[mimgui.Col.SliderGrab]      = mimgui.ImVec4(0.3, 1.0, 0.4, 1.0)
    col[mimgui.Col.ScrollbarGrab]   = mimgui.ImVec4(0.2, 0.7, 0.3, 0.7)
    col[mimgui.Col.Text]            = mimgui.ImVec4(0.92, 0.95, 0.92, 1.0)
end

mimgui.OnInitialize(function()
    theme.applyDarkModern()
end)

-- ============================================================
-- GUI FRAME
-- ============================================================
mimgui.OnFrame(function() return showMenu[0] end, function()
    theme.applyDarkModern()
    local screenW, screenH = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(screenW / 2, screenH / 2),
        mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(520, 500), mimgui.Cond.FirstUseEver)

    mimgui.Begin("AutoWalk Manager", showMenu, mimgui.WindowFlags.NoCollapse)
    mimgui.TextDisabled("Author: Yohanez")

    -- ── Header Status ──────────────────────────────────────
    local statusColor = enabled
        and mimgui.ImVec4(0.2, 1.0, 0.3, 1.0)
        or  mimgui.ImVec4(1.0, 0.35, 0.35, 1.0)
    mimgui.PushStyleColor(mimgui.Col.Text, statusColor)
    mimgui.Text(enabled and "AUTOWALK AKTIF" or "AUTOWALK NON-AKTIF")
    mimgui.PopStyleColor()

    mimgui.SameLine()

    -- Mode Sprint Badge
    local sprintColor = isSprint
        and mimgui.ImVec4(1.0, 0.85, 0.1, 1.0)
        or  mimgui.ImVec4(0.5, 0.5, 0.5, 0.8)
    mimgui.PushStyleColor(mimgui.Col.Text, sprintColor)
    mimgui.Text(isSprint and "  [SPRINT]" or "  [JALAN]")
    mimgui.PopStyleColor()

    mimgui.SameLine()
    mimgui.SetCursorPosX(mimgui.GetContentRegionAvail().x - 30)
    if mimgui.SmallButton("X") then showMenu[0] = false end

    -- File aktif
    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.8, 1.0, 0.9))
    local activeLabel = selectedFile
        and ("File: " .. basename(selectedFile) .. "  |  Titik: " .. #coordinates)
        or  "Belum ada file dipilih"
    mimgui.Text(activeLabel)
    mimgui.PopStyleColor()

    mimgui.Separator()
    mimgui.Spacing()

    -- ── Tombol Kontrol Utama ────────────────────────────────
    -- Autowalk ON/OFF
    if enabled then
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.55, 0.08, 0.08, 0.9))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.75, 0.12, 0.12, 0.9))
        if mimgui.Button("Stop AutoWalk", mimgui.ImVec2(160, 32)) then
            enabled = false
            sampAddChatMessage("{FF4444}[AUTOWALK] Dihentikan.", -1)
        end
        mimgui.PopStyleColor(2)
    else
        if mimgui.Button("Mulai AutoWalk", mimgui.ImVec2(160, 32)) then
            if not selectedFile then
                guiMsg = "Pilih file dulu!"
            elseif #coordinates == 0 then
                guiMsg = "File kosong, tidak ada koordinat!"
            else
                enabled = true
                sampAddChatMessage("{00FF00}[AUTOWALK] Dimulai! File: " .. basename(selectedFile), -1)
            end
        end
    end

    mimgui.SameLine()

    -- Toggle Sprint/Jalan
    if isSprint then
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.55, 0.45, 0.05, 0.9))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.75, 0.62, 0.08, 0.9))
        if mimgui.Button("Ganti ke Jalan", mimgui.ImVec2(155, 32)) then
            isSprint = false
            saveCurrentFile()
            sampAddChatMessage("{00FFFF}[AUTOWALK] Mode: Jalan (Walk)", -1)
        end
        mimgui.PopStyleColor(2)
    else
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.08, 0.35, 0.42, 0.9))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.10, 0.50, 0.60, 0.9))
        if mimgui.Button("Ganti ke Sprint", mimgui.ImVec2(155, 32)) then
            isSprint = true
            saveCurrentFile()
            sampAddChatMessage("{FFFF00}[AUTOWALK] Mode: Sprint (Lari)", -1)
        end
        mimgui.PopStyleColor(2)
    end

    mimgui.SameLine()

    -- Simpan koordinat sekarang
    if mimgui.Button("Simpan Posisi", mimgui.ImVec2(140, 32)) then
        if not selectedFile then
            guiMsg = "Pilih file dulu sebelum simpan posisi!"
        else
            local px, py, pz = getCharCoordinates(PLAYER_PED)
            table.insert(coordinates, {px, py, pz, 11, -255, isSprint})
            saveCurrentFile()
            guiMsg = "Posisi #" .. #coordinates .. " disimpan!"
            sampAddChatMessage("{00FF00}[AUTOWALK] Koordinat #" .. #coordinates .. " ditambahkan.", -1)
        end
    end

    mimgui.Spacing()
    mimgui.Separator()

    -- ── Panel kiri: Daftar File ─────────────────────────────
    mimgui.Text("Daftar File Route:")
    mimgui.SameLine()
    if mimgui.SmallButton("Refresh") then
        scanFileList()
        guiMsg = "Daftar diperbarui. " .. #fileList .. " file ditemukan."
    end

    -- Buat file baru
    mimgui.Spacing()
    mimgui.Text("Nama file baru:")
    mimgui.SameLine()
    mimgui.PushItemWidth(180)
    mimgui.InputText("##newfile", bufNewFile, 128)
    mimgui.PopItemWidth()
    mimgui.SameLine()
    if mimgui.Button("Buat", mimgui.ImVec2(70, 0)) then
        local fname = ffi.string(bufNewFile):gsub("^%s*(.-)%s*$", "%1")
        if fname == "" then
            guiMsg = "Nama file tidak boleh kosong!"
        else
            if not fname:match("%.json$") then fname = fname .. ".json" end
            ensureDirectoryExists(basePath)
            local fpath = basePath .. "\\" .. fname
            if doesFileExist(fpath) then
                guiMsg = "File sudah ada: " .. fname
            else
                local nf = io.open(fpath, "w")
                if nf then
                    nf:write(json.encode({points={}, waitTime=8000, clickKeyName=nil, clickDelay=0, isSprint=false}))
                    nf:close()
                    scanFileList()
                    guiMsg = "File dibuat: " .. fname
                    sampAddChatMessage("{00FF00}[AUTOWALK] File baru: " .. fname, -1)
                else
                    guiMsg = "Gagal membuat file!"
                end
            end
        end
    end

    mimgui.Spacing()

    -- Tabel file
    mimgui.BeginChild("##filelist", mimgui.ImVec2(-1, 160), true)

    if #fileList == 0 then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.5, 0.5, 0.7))
        mimgui.Text("  Belum ada file. Klik Refresh atau buat file baru.")
        mimgui.PopStyleColor()
    else
        for i, finfo in ipairs(fileList) do
            local isActive = selectedFile == finfo.path
            local isSelected = selectedIdx == i

            -- Highlight baris aktif
            if isActive then
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.2, 1.0, 0.4, 1.0))
            elseif isSelected then
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.9, 0.9, 0.2, 1.0))
            else
                mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.85, 0.85, 0.85, 1.0))
            end

            local icon = isActive and ">> " or "   "
            if mimgui.Selectable(icon .. finfo.name .. "##" .. i, isSelected or isActive) then
                selectedIdx = i
            end
            mimgui.PopStyleColor()
        end
    end

    mimgui.EndChild()

    -- Tombol aksi file
    mimgui.Spacing()
    local canAct = selectedIdx >= 1 and selectedIdx <= #fileList

    -- Tombol GUNAKAN
    if not canAct then
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
    end
    if mimgui.Button("Gunakan", mimgui.ImVec2(100, 28)) and canAct then
        local fi = fileList[selectedIdx]
        if loadFile(fi.path) then
            guiMsg = "File dimuat: " .. fi.name .. " | " .. #coordinates .. " titik"
            sampAddChatMessage("{00FF00}[AUTOWALK] File dipilih: " .. fi.name, -1)
        else
            guiMsg = "Gagal membuka file: " .. fi.name
        end
    end
    if not canAct then mimgui.PopStyleColor(2) end

    mimgui.SameLine()

    -- Tombol HAPUS
    if not canAct then
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
    else
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.50, 0.06, 0.06, 0.9))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.72, 0.10, 0.10, 0.9))
    end
    if mimgui.Button("Hapus", mimgui.ImVec2(90, 28)) and canAct then
        local fi = fileList[selectedIdx]
        if selectedFile == fi.path then
            selectedFile = nil
            coordinates = {}
            enabled = false
        end
        deleteFile(fi.path)
        scanFileList()
        selectedIdx = 0
        guiMsg = "File dihapus: " .. fi.name
        sampAddChatMessage("{FF4444}[AUTOWALK] File dihapus: " .. fi.name, -1)
    end
    mimgui.PopStyleColor(2)

    mimgui.SameLine()

    -- Tombol PREVIEW KOORDINAT
    if not canAct then
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
    end
    if mimgui.Button("Preview", mimgui.ImVec2(85, 28)) and canAct then
        local fi = fileList[selectedIdx]
        local pf = io.open(fi.path, "r")
        if pf then
            local c = pf:read("*a")
            pf:close()
            local d = json.decode(c)
            local pts = d and d.points and #d.points or 0
            local wt  = d and d.waitTime and (d.waitTime/1000) or 0
            local sp  = d and d.isSprint and "Sprint" or "Jalan"
            guiMsg = fi.name .. " | " .. pts .. " titik | Wait: " .. wt .. "s | Mode: " .. sp
        else
            guiMsg = "Gagal baca file untuk preview"
        end
    end
    if not canAct then mimgui.PopStyleColor(2) end

    mimgui.SameLine()

    -- Tombol BERSIHKAN TITIK (dari file aktif)
    if not selectedFile then
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.2, 0.2, 0.2, 0.5))
    else
        mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.35, 0.20, 0.05, 0.9))
        mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.55, 0.32, 0.08, 0.9))
    end
    if mimgui.Button("Kosongkan", mimgui.ImVec2(105, 28)) and selectedFile then
        coordinates = {}
        saveCurrentFile()
        guiMsg = "Semua titik dihapus dari " .. basename(selectedFile)
        sampAddChatMessage("{FFAA00}[AUTOWALK] Semua koordinat dihapus dari file aktif.", -1)
    end
    mimgui.PopStyleColor(2)

    -- ── Koordinat aktif ─────────────────────────────────────
    mimgui.Spacing()
    mimgui.Separator()
    mimgui.Text("Koordinat aktif (" .. #coordinates .. " titik):")

    mimgui.BeginChild("##coords", mimgui.ImVec2(-1, -40), true)
    if #coordinates == 0 then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.5, 0.5, 0.5, 0.7))
        mimgui.Text("  Belum ada titik. Gunakan /setcord atau tombol Simpan Posisi.")
        mimgui.PopStyleColor()
    else
        for i, pt in ipairs(coordinates) do
            local spMode = pt[6] and "[SPRINT]" or "[JALAN]"
            local label = string.format(
                "[%02d] %s  X:%.1f  Y:%.1f  Z:%.1f",
                i, spMode, pt[1], pt[2], pt[3]
            )
            mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.7, 0.95, 0.75, 1.0))
            mimgui.Text(label)
            mimgui.PopStyleColor()
            mimgui.SameLine()
            mimgui.PushStyleColor(mimgui.Col.Button,        mimgui.ImVec4(0.50, 0.06, 0.06, 0.8))
            mimgui.PushStyleColor(mimgui.Col.ButtonHovered, mimgui.ImVec4(0.72, 0.10, 0.10, 0.9))
            if mimgui.SmallButton("X##rm" .. i) then
                table.remove(coordinates, i)
                saveCurrentFile()
                guiMsg = "Titik #" .. i .. " dihapus."
            end
            mimgui.PopStyleColor(2)
        end
    end
    mimgui.EndChild()

    -- ── Status Message ──────────────────────────────────────
    if guiMsg ~= "" then
        mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.4, 0.9, 0.5, 1.0))
        mimgui.Text(guiMsg)
        mimgui.PopStyleColor()
    end

    mimgui.End()
end)

-- ============================================================
-- MOVEMENT CORE
-- ============================================================

function MovePlayer(move_code, sprintMode)
    setGameKeyState(1, move_code)
    if sprintMode then
        setGameKeyState(16, 255)
    else
        setGameKeyState(16, 0)
    end
end

function BeginToPoint(x, y, z, radius, move_code, sprintMode)
    repeat
        local posX, posY, posZ = getCharCoordinates(PLAYER_PED)
        SetAngle(x, y, z)
        MovePlayer(move_code, sprintMode)
        local dist = getDistanceBetweenCoords3d(x, y, z, posX, posY, z)
        wait(0)
    until not enabled or dist < radius
end

function moveToPoints()
    local index = 1

    while enabled do
        local point = coordinates[index]
        if not point then break end

        -- isSprint global bisa override, atau ambil dari data titik
        local useSprintMode = isSprint or point[6]
        BeginToPoint(point[1], point[2], point[3], 1.0, point[5], useSprintMode)
        wait(point[4] or 11)

        if clickKey then
            if clickDelay > 0 then wait(clickDelay) end
            pressKey(clickKey)
        end

        wait(waitTime)

        if index == #coordinates then
            index = 1
        else
            index = index + 1
        end
    end

    setGameKeyState(14, 1)
    wait(20)
    setGameKeyState(14, 0)
end

function SetAngle(x, y, z)
    local posX, posY, posZ = getCharCoordinates(PLAYER_PED)
    local pX = x - posX
    local pY = y - posY
    local zAngle = getHeadingFromVector2d(pX, pY)
    setCharHeading(PLAYER_PED, zAngle)
    restoreCameraJumpcut()
end

-- ============================================================
-- MAIN & COMMANDS
-- ============================================================
function main()
    while not isSampAvailable() do wait(100) end

    ensureDirectoryExists(basePath)
    scanFileList()

    -- /awmenu - buka GUI manager
    sampRegisterChatCommand("awmenu", function()
        scanFileList()
        showMenu[0] = not showMenu[0]
    end)

    -- /autowalk - toggle on/off
    sampRegisterChatCommand("autowalk", function()
        if not selectedFile then
            sampAddChatMessage("{FF0000}[AUTOWALK] Pilih file dulu! /selectfile <nama> atau /awmenu", -1)
            return
        end
        if #coordinates == 0 then
            sampAddChatMessage("{FF0000}[AUTOWALK] File kosong, tidak ada koordinat.", -1)
            return
        end
        enabled = not enabled
        sampAddChatMessage(
            enabled
                and ("{00FF00}[AUTOWALK] AKTIF | File: " .. basename(selectedFile) .. " | Mode: " .. (isSprint and "Sprint" or "Jalan"))
                or  "{FF4444}[AUTOWALK] NONAKTIF",
            -1
        )
    end)

    -- /sprint true/false - toggle mode sprint saat autowalk
    sampRegisterChatCommand("sprint", function(arg)
        arg = string.lower(arg or "")
        if arg == "true" or arg == "1" or arg == "on" then
            isSprint = true
            saveCurrentFile()
            sampAddChatMessage("{FFFF00}[AUTOWALK] Mode Sprint AKTIF - karakter akan berlari!", -1)
        elseif arg == "false" or arg == "0" or arg == "off" then
            isSprint = false
            saveCurrentFile()
            sampAddChatMessage("{00FFFF}[AUTOWALK] Mode Jalan AKTIF - karakter akan berjalan.", -1)
        else
            local cur = isSprint and "{FFFF00}Sprint (Lari)" or "{00FFFF}Jalan (Walk)"
            sampAddChatMessage("{00FFFF}[AUTOWALK] Mode sekarang: " .. cur, -1)
            sampAddChatMessage("{FFFFFF}Gunakan: /sprint true  ATAU  /sprint false", -1)
        end
    end)

    -- /createfile <nama>
    sampRegisterChatCommand("createfile", function(filename)
        ensureDirectoryExists(basePath)
        if not filename or filename == "" then
            sampAddChatMessage("{FF0000}[AUTOWALK] Penggunaan: /createfile <nama>", -1)
            return
        end
        if not filename:match("%.json$") then filename = filename .. ".json" end
        local fullPath = basePath .. "\\" .. filename
        if doesFileExist(fullPath) then
            sampAddChatMessage("{FFAA00}[AUTOWALK] File sudah ada: " .. filename, -1)
            return
        end
        local nf = io.open(fullPath, "w")
        if nf then
            nf:write(json.encode({points={}, waitTime=8000, clickKeyName=nil, clickDelay=0, isSprint=false}))
            nf:close()
            selectedFile = fullPath
            coordinates  = {}
            scanFileList()
            sampAddChatMessage("{00FF00}[AUTOWALK] File dibuat & dipilih: " .. filename, -1)
        else
            sampAddChatMessage("{FF0000}[AUTOWALK] Gagal membuat file!", -1)
        end
    end)

    -- /selectfile <nama>
    sampRegisterChatCommand("selectfile", function(filename)
        if not filename or filename == "" then
            sampAddChatMessage("{FF0000}[AUTOWALK] Penggunaan: /selectfile <nama>", -1)
            return
        end
        if not filename:match("%.json$") then filename = filename .. ".json" end
        local fullPath = basePath .. "\\" .. filename
        if loadFile(fullPath) then
            sampAddChatMessage("{00FF00}[AUTOWALK] File dipilih: " .. filename .. " | " .. #coordinates .. " titik | Mode: " .. (isSprint and "Sprint" or "Jalan"), -1)
        else
            sampAddChatMessage("{FF0000}[AUTOWALK] Gagal membuka: " .. filename, -1)
        end
    end)

    -- /setcord
    sampRegisterChatCommand("setcord", function()
        if not selectedFile then
            sampAddChatMessage("{FF0000}[AUTOWALK] Pilih file dulu! Gunakan /selectfile atau /awmenu", -1)
            return
        end
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        table.insert(coordinates, {px, py, pz, 11, -255, isSprint})
        saveCurrentFile()
        sampAddChatMessage("{00FF00}[AUTOWALK] Koordinat #" .. #coordinates .. " ditambahkan (Mode: " .. (isSprint and "Sprint" or "Jalan") .. ")", -1)
    end)

    -- /remcord <index>
    sampRegisterChatCommand("remcord", function(index)
        if not selectedFile then
            sampAddChatMessage("{FF0000}[AUTOWALK] Pilih file dulu!", -1)
            return
        end
        index = tonumber(index)
        if index and coordinates[index] then
            table.remove(coordinates, index)
            saveCurrentFile()
            sampAddChatMessage("{00FF00}[AUTOWALK] Koordinat #" .. index .. " dihapus.", -1)
        else
            sampAddChatMessage("{FF0000}[AUTOWALK] Indeks tidak valid.", -1)
        end
    end)

    -- /setwait <detik>
    sampRegisterChatCommand("setwait", function(time)
        if not selectedFile then
            sampAddChatMessage("{FF0000}[AUTOWALK] Pilih file dulu!", -1)
            return
        end
        local t = tonumber(time)
        if not t or t < 0 then
            sampAddChatMessage("{FF0000}[AUTOWALK] Penggunaan: /setwait <detik>", -1)
            return
        end
        waitTime = t * 1000
        saveCurrentFile()
        sampAddChatMessage("{00FF00}[AUTOWALK] Waktu tunggu: " .. t .. " detik.", -1)
    end)

    -- /setclick <tombol|off>
    sampRegisterChatCommand("setclick", function(keyName)
        if not selectedFile then
            sampAddChatMessage("{FF0000}[AUTOWALK] Pilih file dulu!", -1)
            return
        end
        if not keyName or keyName == "" then
            local cur = clickKeyName and ("{00FF00}" .. clickKeyName) or "{FF0000}NONAKTIF"
            sampAddChatMessage("{00FFFF}[AUTOWALK] Tombol klik saat ini: " .. cur, -1)
            return
        end
        if keyName:lower() == "off" or keyName:lower() == "none" then
            clickKeyName = nil
            clickKey = nil
            saveCurrentFile()
            sampAddChatMessage("{00FF00}[AUTOWALK] Auto-klik dinonaktifkan.", -1)
            return
        end
        local vk = getKeyFromName(keyName)
        if not vk then
            sampAddChatMessage("{FF0000}[AUTOWALK] Tombol tidak dikenal! Contoh: Y, SPACE, ENTER, SHIFT", -1)
            return
        end
        clickKeyName = keyName:upper()
        clickKey = vk
        saveCurrentFile()
        sampAddChatMessage("{00FF00}[AUTOWALK] Auto-klik diatur ke: " .. clickKeyName, -1)
    end)

    -- /setcdclick <ms>
    sampRegisterChatCommand("setcdclick", function(ms)
        if not selectedFile then
            sampAddChatMessage("{FF0000}[AUTOWALK] Pilih file dulu!", -1)
            return
        end
        local d = tonumber(ms)
        if not d or d < 0 then
            sampAddChatMessage("{FF0000}[AUTOWALK] Penggunaan: /setcdclick <milidetik>", -1)
            return
        end
        clickDelay = d
        saveCurrentFile()
        sampAddChatMessage("{00FF00}[AUTOWALK] Cooldown klik: " .. d .. " ms.", -1)
    end)

    -- /woodcount
    sampRegisterChatCommand("woodcount", function()
        sampAddChatMessage("{00FFFF}[AUTOWALK] Total kayu: {00FF00}" .. woodCount, -1)
    end)

    -- /resetcount
    sampRegisterChatCommand("resetcount", function()
        woodCount = 0
        sampAddChatMessage("{00FF00}[AUTOWALK] Counter kayu direset ke 0.", -1)
    end)

    -- /helpcommand
    sampRegisterChatCommand("helpcommand", function()
        sampAddChatMessage("{00FFFF}=== AUTOWALK COMMANDS ===", -1)
        sampAddChatMessage("{00FF00}/awmenu{FFFFFF} - Buka GUI Manager file route (file list, hapus, gunakan, dll)", -1)
        sampAddChatMessage("{00FF00}/autowalk{FFFFFF} - Toggle autowalk ON/OFF", -1)
        sampAddChatMessage("{00FF00}/sprint true/false{FFFFFF} - Mode sprint (lari) atau jalan", -1)
        sampAddChatMessage("{00FF00}/createfile <nama>{FFFFFF} - Buat file route baru", -1)
        sampAddChatMessage("{00FF00}/selectfile <nama>{FFFFFF} - Pilih file route", -1)
        sampAddChatMessage("{00FF00}/setcord{FFFFFF} - Simpan posisi sekarang ke file route", -1)
        sampAddChatMessage("{00FF00}/remcord <index>{FFFFFF} - Hapus titik berdasarkan nomor", -1)
        sampAddChatMessage("{00FF00}/setwait <detik>{FFFFFF} - Atur jeda diam di setiap titik", -1)
        sampAddChatMessage("{00FF00}/setclick <tombol|off>{FFFFFF} - Auto tekan tombol di setiap titik", -1)
        sampAddChatMessage("{00FF00}/setcdclick <ms>{FFFFFF} - Delay sebelum tekan tombol", -1)
        sampAddChatMessage("{00FF00}/woodcount{FFFFFF} - Lihat total kayu | {00FF00}/resetcount{FFFFFF} - Reset counter", -1)
    end)

    -- Tombol F9 toggle autowalk
    local f9Pressed = false

    -- Notif saat spawn
    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[AutoWalk] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/awmenu{FFFFFF} untuk GUI Manager atau {00FF00}/helpcommand{FFFFFF} untuk daftar command.", -1)
            break
        end
    end

    while true do
        wait(0)

        -- Tombol F9 toggle
        if isKeyDown(0x78) then  -- F9
            if not f9Pressed then
                f9Pressed = true
                if selectedFile and #coordinates > 0 then
                    enabled = not enabled
                    sampAddChatMessage(
                        enabled and "{00FF00}[AUTOWALK] F9: AKTIF" or "{FF4444}[AUTOWALK] F9: NONAKTIF",
                        -1
                    )
                end
            end
        else
            f9Pressed = false
        end

        if enabled then
            moveToPoints()
        end
    end
end

-- ============================================================
-- HOOKS: CHAT DETECTOR & INVENTORY
-- ============================================================

function sampev.onServerMessage(color, text)
    local t = string.lower(text)
    local hasWood    = string.find(t, "kayu", 1, true) or string.find(t, "wood", 1, true)
                    or string.find(t, "pohon", 1, true) or string.find(t, "log", 1, true)
    local hasSuccess = string.find(t, "berhasil", 1, true) or string.find(t, "dapat", 1, true)
                    or string.find(t, "ambil", 1, true) or string.find(t, "cut", 1, true)
                    or string.find(t, "gather", 1, true) or string.find(t, "harvest", 1, true)

    if hasWood and hasSuccess then
        woodCount = woodCount + 1
        printStringNow("Kayu: ~g~" .. woodCount, 3000)
        sampAddChatMessage("{00FF00}[AUTOWALK] Panen kayu! Total: " .. woodCount, -1)
    end
end

function sampev.onShowDialog(id, style, title, button1, button2, text)
    local lowerTitle = string.lower(title)
    local lowerText  = string.lower(text)

    if string.find(lowerTitle, "inventory", 1, true) or
       string.find(lowerTitle, "tas",       1, true) or
       string.find(lowerTitle, "perlengkapan", 1, true) or
       string.find(lowerTitle, "kantong",   1, true) or
       string.find(lowerText,  "inventory", 1, true) or
       string.find(lowerText,  "tas",       1, true) then

        local matchPatterns = {
            "kayu%s*:%s*(%d+)", "wood%s*:%s*(%d+)", "log%s*:%s*(%d+)",
            "kayu%s*%-%s*(%d+)", "wood%s*%-%s*(%d+)",
            "kayu%s*%((%d+)%)", "wood%s*%((%d+)%)",
            "kayu%s*x%s*(%d+)", "wood%s*x%s*(%d+)",
            "kayu%s*x(%d+)", "wood%s*x(%d+)",
            "pohon%s*:%s*(%d+)", "pohon%s*%-%s*(%d+)"
        }

        for _, pattern in ipairs(matchPatterns) do
            local match = string.match(lowerText, pattern)
            if match then
                local amount = tonumber(match)
                if amount and amount ~= woodCount then
                    woodCount = amount
                    printStringNow("Kayu (Inv): ~g~" .. woodCount, 3000)
                    sampAddChatMessage("{00FF00}[AUTOWALK] Counter sync inventory: " .. woodCount .. " kayu", -1)
                    break
                end
            end
        end
    end
end