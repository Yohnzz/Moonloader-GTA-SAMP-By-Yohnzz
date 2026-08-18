script_name("Notepad SAMP")
script_author("Yohanez")

require 'lib.sampfuncs'
require 'lib.moonloader'
local mimgui = require 'lib.mimgui'
local theme = require 'lib.mimgui_theme'
local ffi = require 'ffi'
local lfs = require 'lfs'

-- UI State
local showWindow = mimgui.new.bool(false)
local textBuffer = mimgui.new.char[16384]("")
local newFileNameBuffer = mimgui.new.char[64]("")
local selectedFile = ""
local notepadFiles = {}

-- Folders
local dirPath = getWorkingDirectory() .. "/config/notepad"

-- Check OS for clipboard safety on mobile
local isWindows = (ffi.os == "Windows")

if isWindows then
    pcall(function()
        ffi.cdef[[
            int OpenClipboard(void* hwnd);
            int EmptyClipboard();
            void* SetClipboardData(unsigned int uFormat, void* hMem);
            int CloseClipboard();
            void* GlobalAlloc(unsigned int uFlags, size_t dwBytes);
            void* GlobalLock(void* hMem);
            int GlobalUnlock(void* hMem);
        ]]
    end)
end

-- ========================
-- CLIPBOARD FUNCTION (Safe)
-- ========================
function copyToClipboard(text)
    if not isWindows then
        sampAddChatMessage("{FFFF00}[Notepad] Fitur salin ke clipboard tidak didukung di HP.", -1)
        return
    end

    local success = pcall(function()
        local len = #text + 1
        local hMem = ffi.C.GlobalAlloc(0x0002, len) -- GMEM_MOVEABLE = 0x0002
        local ptr = ffi.C.GlobalLock(hMem)

        ffi.copy(ptr, text)
        ffi.C.GlobalUnlock(hMem)

        ffi.C.OpenClipboard(nil)
        ffi.C.EmptyClipboard()
        ffi.C.SetClipboardData(1, hMem) -- CF_TEXT = 1
        ffi.C.CloseClipboard()
        sampAddChatMessage("{00FF00}[Notepad] Berhasil disalin ke clipboard!", -1)
    end)
    
    if not success then
        sampAddChatMessage("{FF0000}[Notepad] Gagal menyalin ke clipboard.", -1)
    end
end

-- ========================
-- FILE MANAGER FUNCTIONS
-- ========================
function refreshFileList()
    notepadFiles = {}
    if doesDirectoryExist(dirPath) then
        for file in lfs.dir(dirPath) do
            if file ~= "." and file ~= ".." and file:match("%.txt$") then
                table.insert(notepadFiles, file)
            end
        end
        table.sort(notepadFiles)
    end
end

function loadFile(fileName)
    local path = dirPath .. "/" .. fileName
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        -- Batasi panjang content agar pas dengan buffer
        if #content >= 16384 then
            content = content:sub(1, 16383)
        end
        
        ffi.copy(textBuffer, content)
        selectedFile = fileName
        sampAddChatMessage(string.format("{00FF00}[Notepad] Dibuka: %s", fileName), -1)
    else
        sampAddChatMessage(string.format("{FF0000}[Notepad] Gagal membuka file: %s", fileName), -1)
    end
end

function saveFile(fileName)
    if not fileName or fileName == "" then return end
    
    -- Pastikan folder config/notepad ada
    if not doesDirectoryExist(dirPath) then
        createDirectory(getWorkingDirectory() .. "/config")
        createDirectory(dirPath)
    end

    local path = dirPath .. "/" .. fileName
    local file = io.open(path, "w")
    if file then
        file:write(ffi.string(textBuffer))
        file:close()
        sampAddChatMessage(string.format("{00FF00}[Notepad] Disimpan: %s", fileName), -1)
        refreshFileList()
    else
        sampAddChatMessage(string.format("{FF0000}[Notepad] Gagal menyimpan file: %s", fileName), -1)
    end
end

function createNewFile(fileName)
    -- Bersihkan spasi
    fileName = fileName:gsub("^%s*(.-)%s*$", "%1")
    if fileName == "" then return false end
    
    -- Tambahkan ekstensi .txt jika belum ada
    if not fileName:match("%.txt$") then
        fileName = fileName .. ".txt"
    end
    
    local path = dirPath .. "/" .. fileName
    
    -- Cek jika file sudah ada
    local checkFile = io.open(path, "r")
    if checkFile then
        checkFile:close()
        sampAddChatMessage("{FFFF00}[Notepad] File dengan nama tersebut sudah ada!", -1)
        return false
    end
    
    local file = io.open(path, "w")
    if file then
        file:write("")
        file:close()
        refreshFileList()
        loadFile(fileName)
        sampAddChatMessage(string.format("{00FF00}[Notepad] Berhasil membuat file baru: %s", fileName), -1)
        return true
    else
        sampAddChatMessage("{FF0000}[Notepad] Gagal membuat file baru!", -1)
        return false
    end
end

-- ========================
-- GUI (mimgui)
-- ========================
mimgui.OnFrame(function() return showWindow[0] end, function()
    theme.applyDarkModern()
    mimgui.SetNextWindowSize(mimgui.ImVec2(650, 450), mimgui.Cond.FirstUseEver)
    mimgui.Begin("📝 Notepad SAMP - Multi-File Edition", showWindow)
    mimgui.TextDisabled("Author: Yohanez")

    -- Panel Kiri (Daftar File & Buat Baru)
    mimgui.BeginChild("LeftPanel", mimgui.ImVec2(200, 0), true)
        mimgui.Text("Buat File Baru:")
        mimgui.PushItemWidth(-1)
        mimgui.InputText("##NewFileName", newFileNameBuffer, 64)
        mimgui.PopItemWidth()
        
        if mimgui.Button("➕ Buat Baru", mimgui.ImVec2(-1, 25)) then
            local newName = ffi.string(newFileNameBuffer)
            if createNewFile(newName) then
                ffi.copy(newFileNameBuffer, "")
            end
        end
        
        mimgui.Separator()
        mimgui.Text("Daftar File (.txt):")
        
        mimgui.BeginChild("FileListScroll", mimgui.ImVec2(-1, -1), false)
        for _, file in ipairs(notepadFiles) do
            local isSelected = (selectedFile == file)
            if mimgui.Selectable(file, isSelected) then
                loadFile(file)
            end
        end
        mimgui.EndChild()
    mimgui.EndChild()

    mimgui.SameLine()

    -- Panel Kanan (Editor)
    mimgui.BeginChild("RightPanel", mimgui.ImVec2(0, 0), false)
        if selectedFile ~= "" then
            mimgui.Text("Mengedit: " .. selectedFile)
            mimgui.Separator()
            
            -- Text Area
            mimgui.InputTextMultiline("##editor", textBuffer, 16384, mimgui.ImVec2(-1, -40))
            
            -- Tombol Aksi
            if mimgui.Button("💾 Simpan", mimgui.ImVec2(100, 30)) then
                saveFile(selectedFile)
            end
            
            mimgui.SameLine()
            if mimgui.Button("📋 Salin", mimgui.ImVec2(100, 30)) then
                copyToClipboard(ffi.string(textBuffer))
            end
            
            mimgui.SameLine()
            if mimgui.Button("🗑️ Bersihkan", mimgui.ImVec2(100, 30)) then
                ffi.copy(textBuffer, "")
            end
        else
            mimgui.Text("Silakan buat file baru atau pilih file di sebelah kiri.")
        end
    mimgui.EndChild()

    mimgui.End()
end)

-- ========================
-- MAIN LOOP
-- ========================
function main()
    repeat wait(0) until isSampAvailable()

    -- Buat folder jika belum ada
    local configDir = getWorkingDirectory() .. "/config"
    local notepadDir = getWorkingDirectory() .. "/config/notepad"

    if not doesDirectoryExist(configDir) then
        createDirectory(configDir)
    end
    if not doesDirectoryExist(notepadDir) then
        createDirectory(notepadDir)
    end

    -- Refresh daftar file saat startup
    refreshFileList()
    
    -- Auto load file pertama jika ada
    if #notepadFiles > 0 then
        loadFile(notepadFiles[1])
    else
        -- Jika tidak ada file sama sekali, buatkan satu file default
        createNewFile("catatan.txt")
    end

    sampRegisterChatCommand("note", function()
        showWindow[0] = not showWindow[0]
        if showWindow[0] then
            refreshFileList()
        end
    end)

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[Notepad] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/note{FFFFFF} untuk membuka Notepad", -1)
            break
        end
    end

    while true do
        wait(0)
    end
end