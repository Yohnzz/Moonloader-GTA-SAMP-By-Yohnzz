script_name("Universal & Click Detector")
script_author("Yohnzz")
script_version("1.1.0")

local sampev = require 'lib.samp.events'

-- ============================================================================
-- KONFIGURASI / STATE STATUS (ON/OFF)
-- ============================================================================
local det_textdraw = false
local det_dialog   = true
local det_rpc      = false -- Sengaja di-default FALSE agar chatlog tidak terlalu spam saat baru login

local PREFIX       = "{00FFFF}[Detector] "
local COLOR_GREEN  = "{00FF00}"
local COLOR_RED    = "{FF0000}"
local COLOR_WHITE  = "{FFFFFF}"



-- ============================================================================
-- MAIN FUNCTION & COMMAND REGISTRATION
-- ============================================================================
function main()
    while not isSampAvailable() do wait(100) end

    sampAddChatMessage(PREFIX .. COLOR_GREEN .. "Universal & Click Detector Loaded!", -1)

    -- Registrasi perintah chat
    sampRegisterChatCommand("detector", cmd_status)
    sampRegisterChatCommand("dettd", cmd_toggle_td)
    sampRegisterChatCommand("detdialog", cmd_toggle_dialog)
    sampRegisterChatCommand("detrpc", cmd_toggle_rpc)

    -- Fallback Polling Dialog Aktif (Supaya 100% terdeteksi meskipun di-override script lain)
    lua_thread.create(function()
        local lastDialogId = -1
        while true do
            wait(200)
            if det_dialog then
                if sampIsDialogActive() then
                    local id = sampGetCurrentDialogId()
                    if id ~= lastDialogId then
                        lastDialogId = id
                        sampAddChatMessage(string.format("{00FFFF}[DIALOG-ACTIVE] {FFFFFF}ID: {00FF00}%d", id), -1)
                        print(string.format("[Detector Polling] Active Dialog - ID: %d", id))
                    end
                else
                    lastDialogId = -1
                end
            else
                lastDialogId = -1
            end
        end
    end)

    wait(-1)
end

-- ============================================================================
-- FUNCTIONS FOR COMMAND HANDLERS
-- ============================================================================
function cmd_status()
    local status_td     = det_textdraw and (COLOR_GREEN .. "ON") or (COLOR_RED .. "OFF")
    local status_dialog = det_dialog   and (COLOR_GREEN .. "ON") or (COLOR_RED .. "OFF")
    local status_rpc    = det_rpc      and (COLOR_GREEN .. "ON") or (COLOR_RED .. "OFF")

    sampAddChatMessage(PREFIX .. "{FFFF00}--- STATUS DETECTOR ---", -1)
    sampAddChatMessage(COLOR_WHITE .. "Deteksi TextDraw (Show & Click): " .. status_td, -1)
    sampAddChatMessage(COLOR_WHITE .. "Deteksi Dialog: " .. status_dialog, -1)
    sampAddChatMessage(COLOR_WHITE .. "Deteksi RPC (In & Out): " .. status_rpc, -1)
    sampAddChatMessage(PREFIX .. "{FFFF00}Gunakan: /dettd , /detdialog , atau /detrpc untuk toggle.", -1)
end

function cmd_toggle_td()
    det_textdraw = not det_textdraw
    local str = det_textdraw and (COLOR_GREEN .. "DIAKTIFKAN") or (COLOR_RED .. "DINONAKTIFKAN")
    sampAddChatMessage(PREFIX .. "Deteksi TextDraw/PlayerTextDraw " .. str, -1)
end

function cmd_toggle_dialog()
    det_dialog = not det_dialog
    local str = det_dialog and (COLOR_GREEN .. "DIAKTIFKAN") or (COLOR_RED .. "DINONAKTIFKAN")
    sampAddChatMessage(PREFIX .. "Deteksi Dialog " .. str, -1)
end

function cmd_toggle_rpc()
    det_rpc = not det_rpc
    local str = det_rpc and (COLOR_GREEN .. "DIAKTIFKAN") or (COLOR_RED .. "DINONAKTIFKAN")
    sampAddChatMessage(PREFIX .. "Deteksi RPC " .. str, -1)
end

-- ============================================================================
-- HOOKS: TEXTDRAW DETECTION
-- ============================================================================
function sampev.onShowTextDraw(id, data)
    if not det_textdraw then return end
    local text = (data and data.text) or "N/A"
    sampAddChatMessage(string.format("{00FFFF}[TD] {FFFFFF}ID: {00FF00}%d {FFFFFF}| Text: %s", id, text), -1)
end

function sampev.onShowPlayerTextDraw(id, data)
    if not det_textdraw then return end
    local text = (data and data.text) or "N/A"
    sampAddChatMessage(string.format("{00FFFF}[PTD] {FFFFFF}ID: {00FF00}%d {FFFFFF}| Text: %s", id, text), -1)
end

function sampev.onSendClickTextDraw(id)
    if not det_textdraw then return end
    sampAddChatMessage("{00FFFF}[SEND CLICK TD] {FFFF00}" .. id, -1)
end

function sampev.onSendClickPlayerTextDraw(id)
    if not det_textdraw then return end
    sampAddChatMessage("{00FFFF}[SEND CLICK PTD] {FFFF00}" .. id, -1)
end

-- ============================================================================
-- HOOKS: DIALOG DETECTION
-- ============================================================================
function sampev.onShowDialog(id, style, title, button1, button2, text)
    if not det_dialog then return end
    
    local ok, err = pcall(function()
        local cleanTitle = tostring(title or "No Title")
        local cleanBtn1  = tostring(button1 or "N/A")
        local cleanBtn2  = tostring(button2 or "N/A")
        
        -- Kirim info dialog ke chat game dengan warna cyan/putih agar jelas terbaca
        sampAddChatMessage(string.format("{00FFFF}[DIALOG] {FFFFFF}ID: {00FF00}%d {FFFFFF}| Style: {00FF00}%d {FFFFFF}| Title: %s", id, style, cleanTitle), -1)
        
        -- Hitung baris isi dialog
        local lineCount = 0
        if text and text ~= "" then
            for line in string.gmatch(text, "[^\r\n]+") do
                lineCount = lineCount + 1
            end
        end
        sampAddChatMessage(string.format("{00FFFF}[DIALOG] {FFFFFF}Lines: {FFFF00}%d {FFFFFF}| Buttons: {00FF00}%s {FFFFFF}/ {00FF00}%s", lineCount, cleanBtn1, cleanBtn2), -1)

        -- Catat detail lengkap ke file moonloader.log untuk analisis mendalam
        print("========== DETECTED DIALOG ==========")
        print("ID:", id)
        print("STYLE:", style)
        print("TITLE:", cleanTitle)
        print("BUTTON 1:", cleanBtn1)
        print("BUTTON 2:", cleanBtn2)
        print("TEXT:")
        print(text or "[Empty]")
        print("=====================================")
    end)

    if not ok then
        sampAddChatMessage("{FF0000}[Detector Error] Gagal memproses dialog: " .. tostring(err), -1)
    end
end

-- ============================================================================
-- HOOKS: RPC DETECTION (NATIVE MOONLOADER GLOBAL EVENTS)
-- ============================================================================
function onReceiveRpc(id, bs)
    if det_rpc then
        sampAddChatMessage(string.format("{00FFFF}[RPC INCOMING] {FFFFFF}ID: {FFFF00}%d", id), -1)
    end
end

function onSendRpc(id, bs)
    if det_rpc then
        sampAddChatMessage(string.format("{00FFFF}[RPC OUTGOING] {FFFFFF}ID: {FFFF00}%d", id), -1)
    end
end