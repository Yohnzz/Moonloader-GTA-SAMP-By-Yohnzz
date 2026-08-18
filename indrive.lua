-- Auto RP TRANS GUI untuk SAMP Lua (MoonLoader)
-- Modifikasi: Penghapusan Sistem Invoice
require 'lib.sampfuncs'
require 'lib.moonloader'
local mimgui = require 'lib.mimgui'
local theme = require 'lib.mimgui_theme'
local encoding = require 'lib.encoding'
encoding.default = 'CP1252'
local ffi = require "ffi"
local dlstatus = require('moonloader').download_status
local os = require 'os'

-- URL Firebase Anda (Ganti dengan URL Realtime Database Project Anda)
-- Contoh: "https://project-id-default-rtdb.firebaseio.com/events.json"
local FIREBASE_URL = "https://moonloader-event-default-rtdb.asia-southeast1.firebasedatabase.app/events.json"
local firebaseEvents = {}
local isLoadingEvents = false

ffi.cdef[[
bool SetCursorPos(int X, int Y);
void mouse_event(unsigned int dwFlags, unsigned int dx, unsigned int dy, unsigned int dwData, unsigned long dwExtraInfo);
void keybd_event(unsigned char bVk, unsigned char bScan, unsigned long dwFlags, unsigned long dwExtraInfo);
]]
local events = require 'lib.events'

local rpCategories = {
    {
        name = 'Pengumuman',
        description = 'Kategori untuk pengumuman terkait status layanan TRANS.',
        rps = {
            {
                name = 'Buka Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di TRANS telah dibuka.',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS TELAH DIBUKA || SILAKAN ORDER MELALUI HP',
                    '/fa MELAYANI ANTAR JEMPUT - ANTAR MAKANAN - ANTAR TOOLKIT',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Tutup Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di TRANS telah ditutup.',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS TELAH DITUTUP || KITA BERTEMU DI LAIN WAKTU',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Darurat',
                desc = 'Memberikan informasi jika orderan banyak',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa DIINFORMASIKAN KEPADA PEMESAN LAYANAN TRANS',
                    '/fa MOHON BERSABAR JIKA ORDERAN BELUM DITERIMA',
                    '/fa DIKARENAKAN PETUGAS YANG JUMLAHNYA TERBATAS',
                    '/fa SILAHKAN MENUNGGU DI LOKASI PENJEMPUTAN HINGGA MAKS 15 MENIT',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Tips',
                desc = 'Memberikan informasi Tips kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa SILAHKAN BAGI PARA WARGA MENUNGGU MAKS 15 MENIT',
                    '/fa JIKA DALAM WAKTU TERSEBUT BELUM TIDAK DI LOKASI PENJEMPUTAN',
                    '/fa MAKA PIHAK TRANS BERHAK BLACKLIST PELANGGAN',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'Paket',
                desc = 'Memberikan informasi Paket kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa SELAIN ANTAR ANTAR TRANS JUGA MENYEDIAKAN LAYANAN PAKET MENARIK',
                    '/fa SILAHKAN CEK DI WEBSITE KAMI UNTUK INFO LEBIH LANJUT',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'Buka Pelayanan (Alternatif)',
                desc = 'Memberikan informasi Buka Pelayanan (Alternatif) kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS TELAH DIBUKA || SILAKAN ORDER MELALUI HP MASING MASING',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'Layanan Telah Terbuka',
                desc = 'Memberikan informasi Buka Pelayanan (Alternatif) kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS MASIH DIBUKA || SILAKAN ORDER MELALUI HP MASING MASING',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
            {
                name = 'RECRUITMENT',
                desc = 'Memberikan informasi Buka Pelayanan (Alternatif) kepada pelanggan',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa LAYANAN TRANS MASIH DIBUKA || SILAKAN ORDER MELALUI HP MASING MASING',
                    '/fa RECRUITMENT TRANS JUGA MASIH TERBUKA',
                    '/fa BAGI WARGA YANG INGIN MENJADI ANGGOTA TRANS DAPAT DAFTAR DI WEB #recruitment-trans',
                    '/fa YANG PERLU DIPERSIAPKAN HANYALAH UMUR 15+, KTP DAN MEMILIKI KEAHLIAN BERKENDARA MOBIL',
                    '/fa SEKIAN DAN TERIMAKASIH'
                }
            },
        }
    },
    {
        name = 'Warning Customer',
        description = 'Kategori untuk memberikan peringatan/warning kepada customer TRANS.',
        isWarningCategory = true,
        rps = {}
    },
    {
        name = 'Event',
        description = 'Kategori untuk memuat event dari Panel Website secara realtime.',
        isEventCategory = true,
        rps = {}
    }
}

-- =========================================
-- Warning Customer State
-- =========================================
local warningState = {
    namaCustomer    = '',
    jumlahWarning   = '',
    alasan          = '',
    showConfirm     = false,
    errorMsg        = ''
}

-- =========================================
-- UTILITY FUNCTIONS
-- =========================================
function fetchFirebaseEvents()
    if isLoadingEvents then return end
    isLoadingEvents = true
    local tmpfile = getWorkingDirectory() .. "\\tmp_events.json"
    downloadUrlToFile(FIREBASE_URL, tmpfile, function(id, status, p1, p2)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            isLoadingEvents = false
            local f = io.open(tmpfile, "r")
            if f then
                local content = f:read("*a")
                f:close()
                os.remove(tmpfile)
                
                if content and content ~= "null" then
                    local success, data = pcall(decodeJson, content)
                    if success and type(data) == "table" then
                        firebaseEvents = {}
                        for k, v in pairs(data) do
                            if v.enabled then
                                table.insert(firebaseEvents, {
                                    id = k,
                                    name = v.name or "Unnamed Event",
                                    desc = v.desc or "",
                                    category = v.category or "Uncategorized",
                                    delay = v.delay or 2000,
                                    cmds = v.cmds or {}
                                })
                            end
                        end
                    end
                else
                    firebaseEvents = {}
                end
            end
        elseif status == dlstatus.STATUSEX_ERROR then
            isLoadingEvents = false
            os.remove(tmpfile)
        end
    end)
end

function executeCommands(commands, delay)
    if not commands then return end
    local sleepTime = delay or math.random(2000, 3000)
    lua_thread.create(function()
        for _, cmd in ipairs(commands) do
            sampSendChat(cmd)
            wait(sleepTime)
        end
    end)
end

function executeWarningCommands(nama, jumlah, alasan)
    local commands = {
        '/fa PENGUMUMAN',
        '/fa CUSTOMER ATAS NAMA ' .. string.upper(nama),
        '/fa TELAH MENDAPATKAN WARNING ' .. jumlah .. ' DIKARENAKAN ' .. string.upper(alasan),
        '/fa TERIMAKASIH'
    }
    executeCommands(commands)
end

function findRpCommands(rpNameToFind)
    for _, category in ipairs(rpCategories) do
        for _, rp in ipairs(category.rps) do
            if rp.name == rpNameToFind then
                return rp.cmds
            end
        end
    end
    return nil
end

function applyStyle()
    local style = mimgui.GetStyle()
    style.WindowRounding = 5.0
    style.FrameRounding = 4.0
    local colors = style.Colors
    colors[mimgui.Col.Text]                   = mimgui.ImVec4(1.00, 0.95, 0.70, 1.00)
    colors[mimgui.Col.WindowBg]               = mimgui.ImVec4(0.06, 0.05, 0.07, 1.00)
    colors[mimgui.Col.Border]                 = mimgui.ImVec4(1.00, 0.84, 0.00, 0.80)
    colors[mimgui.Col.Button]                 = mimgui.ImVec4(0.12, 0.10, 0.05, 1.00)
    colors[mimgui.Col.ButtonHovered]          = mimgui.ImVec4(1.00, 0.84, 0.00, 0.45)
    colors[mimgui.Col.Header]                 = mimgui.ImVec4(0.12, 0.10, 0.05, 1.00)
    colors[mimgui.Col.HeaderHovered]          = mimgui.ImVec4(1.00, 0.84, 0.00, 0.45)
end

function main()
    local showWindow = mimgui.new.bool(false)
    local selectedCategoryIndex = mimgui.new.int(1)

    local bufNama   = mimgui.new.char[128]('')
    local bufJumlah = mimgui.new.char[32]('')
    local bufAlasan = mimgui.new.char[256]('')

    while not isSampAvailable() do wait(100) end

    mimgui.OnInitialize(applyStyle)

    sampRegisterChatCommand('td', function() showWindow[0] = not showWindow[0] end)

    -- Command Cepat (Tanpa Invoice)
    sampRegisterChatCommand('tbuka', function()
        local cmds = findRpCommands('Buka Pelayanan')
        if cmds then executeCommands(cmds) end
    end)

    sampRegisterChatCommand('ttutup', function()
        local cmds = findRpCommands('Tutup Pelayanan')
        if cmds then executeCommands(cmds) end
    end)

    sampRegisterChatCommand('tcmdhelp', function()
        sampAddChatMessage("{FFFF00}=== [AutoRP TRANS] Daftar Command ===", -1)
        sampAddChatMessage("{FFFF00}/td{FFFFFF} - Buka/tutup menu GUI", -1)
        sampAddChatMessage("{FFFF00}/tbuka{FFFFFF} - Buka pelayanan", -1)
        sampAddChatMessage("{FFFF00}/ttutup{FFFFFF} - Tutup pelayanan", -1)
        sampAddChatMessage("{FFFF00}===================================", -1)
    end)

    mimgui.OnFrame(function() return showWindow[0] end, function()
        theme.applyDarkModern()
        mimgui.SetNextWindowSize(mimgui.ImVec2(600, 400), mimgui.Cond.FirstUseEver)
        mimgui.Begin('Auto RP TRANS - Hummatech Edition', showWindow)
        mimgui.TextDisabled("Author: Yohanez")

        -- Panel Kiri
        mimgui.BeginChild('CategoryList', mimgui.ImVec2(200, 0), true)
        for i, category in ipairs(rpCategories) do
            if mimgui.Selectable(category.name, selectedCategoryIndex[0] == i) then
                selectedCategoryIndex[0] = i
                warningState.showConfirm = false
                if category.isEventCategory then
                    fetchFirebaseEvents()
                end
            end
        end
        mimgui.EndChild()

        mimgui.SameLine()

        -- Panel Kanan
        mimgui.BeginChild('RightPanel', mimgui.ImVec2(0, 0), false)
        local cat_idx = selectedCategoryIndex[0]
        local selected_category = rpCategories[cat_idx]

        if selected_category then
            mimgui.Text(selected_category.name)
            mimgui.Separator()

            if selected_category.isWarningCategory then
                -- Form Warning Tetap Ada
                mimgui.Text('Nama Customer:')
                mimgui.InputText('##NamaCustomer', bufNama, 128)
                mimgui.Text('Jumlah Warning:')
                mimgui.InputText('##JumlahWarning', bufJumlah, 32)
                mimgui.Text('Alasan:')
                mimgui.InputTextMultiline('##Alasan', bufAlasan, 256, mimgui.ImVec2(-1, 80))

                if mimgui.Button('Kirim Warning', mimgui.ImVec2(-1, 32)) then
                    executeWarningCommands(ffi.string(bufNama), ffi.string(bufJumlah), ffi.string(bufAlasan))
                    showWindow[0] = false
                end
            elseif selected_category.isEventCategory then
                if mimgui.Button('Refresh Data', mimgui.ImVec2(-1, 30)) then
                    fetchFirebaseEvents()
                end
                
                mimgui.Separator()
                
                if isLoadingEvents then
                    mimgui.Text("Loading events dari Firebase...")
                else
                    if #firebaseEvents == 0 then
                        mimgui.TextColored(mimgui.ImVec4(1, 0.4, 0.4, 1), "Tidak ada event yang dijalankan")
                    else
                        for _, ev in ipairs(firebaseEvents) do
                            local buttonLabel = ev.name .. " (" .. ev.category .. ")##" .. tostring(ev.id)
                            if mimgui.Button(buttonLabel, mimgui.ImVec2(-1, 30)) then
                                showWindow[0] = false
                                executeCommands(ev.cmds, ev.delay)
                            end
                            if mimgui.IsItemHovered() then
                                mimgui.SetTooltip(ev.desc)
                            end
                        end
                    end
                end
            else
                -- Daftar RP Biasa
                for _, rp in ipairs(selected_category.rps) do
                    if mimgui.Button(rp.name, mimgui.ImVec2(-1, 30)) then
                        showWindow[0] = false
                        executeCommands(rp.cmds)
                    end
                end
            end
        end
        mimgui.EndChild()
        mimgui.End()
    end)
end