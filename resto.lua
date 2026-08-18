script_name("AutoRP BERATAP CAFE")
script_author("Yohanez")

require 'lib.sampfuncs'
require 'lib.moonloader'
local mimgui  = require 'lib.mimgui'
local theme   = require 'lib.mimgui_theme'
local encoding = require 'lib.encoding'
local ev      = require 'lib.samp.events'
local ffi     = require 'ffi'

encoding.default = 'CP1252'

ffi.cdef[[
    int OpenClipboard(void* hwnd);
    int EmptyClipboard();
    void* SetClipboardData(unsigned int uFormat, void* hMem);
    int CloseClipboard();
    void* GlobalAlloc(unsigned int uFlags, size_t dwBytes);
    void* GlobalLock(void* hMem);
    int GlobalUnlock(void* hMem);
    void keybd_event(uint8_t bVk, uint8_t bScan, uint32_t dwFlags, uintptr_t dwExtraInfo);
]]

local CF_TEXT = 1
local GMEM_MOVEABLE = 0x0002

local restoText1 = "{ffb703} LAPAR & HAUS? {ffd166}KE BERATAP CAFE AJA | {f4a261}HARGA MURAH | LOC: PEREMPATAN TOL LV"
local restoText2 = "{ffcc00} BERATAP CAFE!!! || {ffff66} MELAYANI DELIVERY PAKET MAKANAN || {ff9933} JOIN RADIO 121"

local showWindow = mimgui.new.bool(false)

-- Restock automation variables
local restock_active  = false
local restock_running = false

-- Helper: simulasi tekan Enter fisik via keybd_event
local function pressEnter()
    ffi.C.keybd_event(0x0D, 0, 0, 0)   -- VK_RETURN press
    wait(80)
    ffi.C.keybd_event(0x0D, 0, 2, 0)   -- VK_RETURN release
end

-- Helper: jalankan loop restock
local function startRestockLoop()
    if restock_running then return end
    lua_thread.create(function()
        restock_running = true
        while restock_active do
            sampSendChat('/cook')
            wait(300)
            pressEnter()
            wait(7000)
        end
        restock_running = false
    end)
end

-- Helper: matikan restock + notifikasi bahan habis
local function stopRestockHabis(alasan)
    restock_active = false
    lua_thread.create(function()
        wait(100)
        sampAddChatMessage('{FF4444}[AutoRP Resto] AUTO RESTOCK DIHENTIKAN!', -1)
        sampAddChatMessage('{FF4444}[AutoRP Resto] Bahan-bahan telah habis!', -1)
        sampAddChatMessage('{FF4444}[AutoRP Resto] Alasan: {FFFF00}' .. (alasan or 'Stok tidak mencukupi'), -1)
        sampAddChatMessage('{FF4444}[AutoRP Resto] Silakan isi ulang bahan terlebih dahulu, lalu ketik {00FF00}/restock', -1)
    end)
end

-- ✅ Definisikan SEBELUM main()
local function isSampAvailable()
    return isSampLoaded() and isSampfuncsLoaded()
end

local function copyToClipboard(text)
    local len = #text + 1
    local hMem = ffi.C.GlobalAlloc(GMEM_MOVEABLE, len)
    local ptr = ffi.C.GlobalLock(hMem)
    ffi.copy(ptr, text)
    ffi.C.GlobalUnlock(hMem)
    ffi.C.OpenClipboard(nil)
    ffi.C.EmptyClipboard()
    ffi.C.SetClipboardData(CF_TEXT, hMem)
    ffi.C.CloseClipboard()
end

local function applyStyle()
    local style = mimgui.GetStyle()
    style.WindowRounding = 10.0
    style.FrameRounding = 6.0

    local colors = style.Colors
    colors[mimgui.Col.WindowBg]      = mimgui.ImVec4(0.10, 0.07, 0.04, 1.00)
    colors[mimgui.Col.TitleBgActive] = mimgui.ImVec4(0.60, 0.30, 0.10, 1.00)
    colors[mimgui.Col.Button]        = mimgui.ImVec4(0.60, 0.30, 0.10, 1.00)
    colors[mimgui.Col.ButtonHovered] = mimgui.ImVec4(0.80, 0.40, 0.10, 1.00)
    colors[mimgui.Col.ButtonActive]  = mimgui.ImVec4(1.00, 0.50, 0.10, 1.00)
end

function main()
    repeat wait(0) until isSampAvailable()

    mimgui.OnInitialize(applyStyle)

    sampRegisterChatCommand('rmenu', function()
        showWindow[0] = not showWindow[0]
    end)

    sampRegisterChatCommand('ropen1', function()
        sampSendChat("/ado " .. restoText1)
    end)

    sampRegisterChatCommand('ropen2', function()
        sampSendChat("/ado " .. restoText2)
    end)

    -- Command /restock: toggle langsung tanpa buka /rmenu
    sampRegisterChatCommand('restock', function()
        restock_active = not restock_active
        if restock_active then
            sampAddChatMessage('{00FF00}[AutoRP Resto] AUTO RESTOCK DIMULAI!', -1)
            sampAddChatMessage('{00FF00}[AutoRP Resto] Loop: /cook -> Enter -> 7 detik jeda', -1)
            sampAddChatMessage('{00FF00}[AutoRP Resto] Ketik {FF4444}/restock {00FF00}untuk berhenti.', -1)
            startRestockLoop()
        else
            sampAddChatMessage('{FF4444}[RESTO] {FFFFFF}Restock otomatis dihentikan oleh pengguna.', -1)
        end
    end)

    mimgui.OnFrame(function() return showWindow[0] end, function()
        theme.applyDarkModern()
        mimgui.SetNextWindowSize(mimgui.ImVec2(520, 320), mimgui.Cond.FirstUseEver)
        mimgui.Begin("BERATAP CAFE MENU", showWindow)

        mimgui.Text("Auto RP BERATAP CAFE")
        mimgui.TextDisabled("Author: Yohanez")
        mimgui.Separator()

        mimgui.TextWrapped(restoText1)
        if mimgui.Button("Kirim (Lokasi)", mimgui.ImVec2(-1, 30)) then
            sampSendChat("/ado " .. restoText1)
        end
        if mimgui.Button("Salin (Lokasi)", mimgui.ImVec2(-1, 30)) then
            copyToClipboard(restoText1)
            sampAddChatMessage("{00FF00}[RESTO] Teks lokasi disalin!", -1)
        end

        mimgui.Separator()

        mimgui.TextWrapped(restoText2)
        if mimgui.Button("Kirim (Delivery)", mimgui.ImVec2(-1, 30)) then
            sampSendChat("/ado " .. restoText2)
        end
        if mimgui.Button("Salin (Delivery)", mimgui.ImVec2(-1, 30)) then
            copyToClipboard(restoText2)
            sampAddChatMessage("{00FF00}[RESTO] Teks delivery disalin!", -1)
        end

        -- Restock Paket Makanan section
        mimgui.Separator()
        mimgui.Text('Restock Paket Makanan')
        local status_text = restock_active and '{00FF00}Aktif' or '{FF0000}Mati'
        mimgui.Text('Status: ' .. status_text)
        mimgui.TextWrapped('Loop: /cook -> Enter -> tunggu 7 detik -> ulangi')
        if restock_active then
            if mimgui.Button('Stop Restock', mimgui.ImVec2(-1, 30)) then
                restock_active = false
                sampAddChatMessage('{FF0000}[RESTO] Restock otomatis dihentikan.', -1)
            end
        else
            if mimgui.Button('Start Restock', mimgui.ImVec2(-1, 30)) then
                restock_active = true
                sampAddChatMessage('{00FF00}[RESTO] Restock otomatis dimulai.', -1)
                startRestockLoop()
            end
        end

        mimgui.End()
    end)

    while true do
        wait(0)
        if sampGetGamestate() == 3 and sampIsLocalPlayerSpawned() then
            sampAddChatMessage('{00FF00}[AutoRP Resto] {FFFFFF}Script berhasil dimuat!', -1)
            sampAddChatMessage('{FFFFFF}[AutoRP Resto] {00FF00}/rmenu {FFFFFF}buka menu  |  {00FF00}/restock {FFFFFF}mulai/stop restock', -1)
            break
        end
    end

    -- Main loop: keep script alive
    while true do
        wait(0)
    end
end

-- Deteksi pesan server: bahan tidak cukup → matikan restock otomatis
function ev.onServerMessage(color, text)
    if not restock_active then return end

    -- Cek berbagai kemungkinan pesan "tidak cukup" dari server
    if text:find("tidak cukup") or text:find("Tidak Cukup") or
       text:find("tidak memiliki") or text:find("Tidak Memiliki") or
       text:find("stok habis") or text:find("Stok Habis") then

        -- Ambil nama bahan dari pesan server (teks antara ":" dan ",")
        local alasan = text:match("{%x+}(.-)$") or text
        -- Bersihkan color codes dari pesan
        alasan = alasan:gsub("{%x%x%x%x%x%x}", ""):gsub("^%s+", "")

        stopRestockHabis(alasan)
    end
end