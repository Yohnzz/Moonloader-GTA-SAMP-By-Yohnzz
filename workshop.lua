-- Auto RP ENGINE + MOTORSPORT GUI untuk SAMP Lua (MoonLoader)
require 'lib.sampfuncs'
require 'lib.moonloader'
local mimgui = require 'lib.mimgui'
local encoding = require 'lib.encoding'
encoding.default = 'CP1252'
local ffi = require "ffi"

ffi.cdef[[
bool SetCursorPos(int X, int Y);
void mouse_event(unsigned int dwFlags, unsigned int dx, unsigned int dy, unsigned int dwData, unsigned long dwExtraInfo);
void keybd_event(unsigned char bVk, unsigned char bScan, unsigned long dwFlags, unsigned long dwExtraInfo);
]]
local events = require 'lib.events'

local rpCategories = {
    {
        name = 'Pengumuman',
        description = 'Kategori untuk pengumuman terkait status layanan ENGINE + MOTORSPORT.',
        rps = {
            {
                name = 'Buka Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di ENGINE + MOTORSPORT telah dibuka.',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa BENGKEL ENGINE + MOTORSPORT TELAH DIBUKA',
                    '/fa MELAYANI REPAIR - MODIF - TOOLKIT - UP ENGINE & BODY - REPAINT',
                    '/fa LOKASI : PEREMPATAN TOLL LV, DEPAN RESTO BARANOV',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Tutup Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di ENGINE + MOTORSPORT telah ditutup.',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa BENGKEL ENGINE + MOTORSPORT TELAH DITUTUP',
                    '/fa KITA BERTEMU DI LAIN WAKTU',
                    '/fa TERIMAKASIH'
                }
            },
            {
                name = 'Pengumuman Tanpa Toolkit',
                desc = 'Memberikan informasi jika tidak menerima penjualan toolkit',
                cmds = {
                    '/fa PENGUMUMAN',
                    '/fa BENGKEL ENGINE + MOTORSPORT TELAH DIBUKA',
                    '/fa MELAYANI REPAIR - MODIF - UP ENGINE & BODY - REPAINT',
                    '/fa TIDAK MELAYANI PENJUALAN TOOLKIT',
                    '/fa LOKASI : PEREMPATAN TOLL LV, DEPAN RESTO BARANOV',
                    '/fa TERIMAKASIH'
                }
            }
        }
    },
    {
        name = 'Kerja Lapangan',
        description = 'Kategori untuk Kerja Lapangan terkait status layanan ENGINE + MOTORSPORT.',
        rps = {
            {
                name = 'repair Kendaraan',
                desc = 'Memberikan repair kepada customer',
                cmds = {
                    '/e cek3',
                    '/me Membuka Kap Mesin Kendaraan yang ada di depan',
                    '/do Kap Terbuka',
                    '/e x',
                    '/e geledah',
                    '/me Memeriksa Kondisi Mesin Kendaraan',
                    '/e geledah3',
                    '/do Mesin Kendaraan Terlihat Baik-Baik Saja',
                    '/e x',
                    '/me Mengeluarkan Peralatan repair dari Toolbox',
                    '/eprop toolbox',
                    '/e cek',
                    '/me Melakukan repair pada Kendaraan',
                    '/e x',
                    '/modif'
                }
            },
            {
                name = 'menyambut Customer',
                desc = 'Menyambut customer yang datang ke bengkel',
                cmds = {
                    '/e bicara3',
                    '/me Selamat Datang di Bengkel ENGINE + MOTORSPORT, Ada yang Bisa Saya Bantu?'
                }
            },
            {
                name = 'Cek Kendaraan',
                desc = 'Melakukan pengecekan kendaraan customer sebelum dilayani',
                cmds = {
                    '/me Mengecek kondisi kendaraan customer yang ada di depan',
                    '/do 2/3',
                    '/do 3/3',
                    '/do Selesai melakukan pengecekan kendaraan'
                }
            },
            {
                name = 'Terimakasih Customer',
                desc = 'Mengucapkan terimakasih dan mengantar customer pulang',
                cmds = {
                    '/e lambai3',
                    '/me Terimakasih telah datang ke Bengkel ENGINE + MOTORSPORT',
                    '/me Hati-hati di jalan, sampai jumpa lagi!',
                    -- '/e x'

                }
            }
        }
    }
}

function findRpCommands(rpNameToFind)
    for _, category in ipairs(rpCategories) do
        for _, rp in ipairs(category.rps) do
            if rp.name == rpNameToFind then
                -- Handle RP with actions (like RP SKS)
                if rp.actions then
                    local allCmds = {}
                    for _, action in ipairs(rp.actions) do
                        for _, cmd in ipairs(action.cmds) do
                            table.insert(allCmds, cmd)
                        end
                    end
                    return allCmds
                -- Handle RP with direct cmds
                elseif rp.cmds then
                    return rp.cmds
                end
            end
        end
    end
    return nil
end


function findRpCommandsByAction(rpNameToFind, actionName)
    for _, category in ipairs(rpCategories) do
        for _, rp in ipairs(category.rps) do
            if rp.name == rpNameToFind and rp.actions then
                for _, action in ipairs(rp.actions) do
                    if action.name == actionName then
                        return action.cmds
                    end
                end
            end
        end
    end
    return nil
end

function executeCommands(commands)
    if not commands then return end
    lua_thread.create(function()
        for _, cmd in ipairs(commands) do
            sampSendChat(cmd)
            wait(math.random(2000, 3000)) -- Using the same delay as in the GUI
        end
    end)
end

function applyStyle()
    local style = mimgui.GetStyle()
    style.WindowPadding = mimgui.ImVec2(15, 15)
    style.WindowRounding = 6.0
    style.FramePadding = mimgui.ImVec2(6, 5)
    style.FrameRounding = 4.0
    style.ItemSpacing = mimgui.ImVec2(12, 8)
    style.ItemInnerSpacing = mimgui.ImVec2(8, 6)
    style.ScrollbarSize = 14.0
    style.ScrollbarRounding = 8.0
    style.GrabMinSize = 6.0
    style.GrabRounding = 4.0

local colors = style.Colors
    -- TEXT
    colors[mimgui.Col.Text] = mimgui.ImVec4(0.95, 0.95, 0.95, 1.00)
    colors[mimgui.Col.TextDisabled] = mimgui.ImVec4(0.50, 0.50, 0.50, 1.00)

    -- BACKGROUND
    colors[mimgui.Col.WindowBg] = mimgui.ImVec4(0.05, 0.05, 0.05, 1.00)
    colors[mimgui.Col.ChildBg]  = mimgui.ImVec4(0.08, 0.08, 0.08, 1.00)
    colors[mimgui.Col.PopupBg] = mimgui.ImVec4(0.08, 0.08, 0.08, 1.00)

    -- BORDER
    colors[mimgui.Col.Border] = mimgui.ImVec4(0.60, 0.10, 0.12, 0.80)
    colors[mimgui.Col.BorderShadow] = mimgui.ImVec4(0, 0, 0, 0)

    -- FRAME
    colors[mimgui.Col.FrameBg] = mimgui.ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[mimgui.Col.FrameBgHovered] = mimgui.ImVec4(0.75, 0.15, 0.18, 0.50)
    colors[mimgui.Col.FrameBgActive]  = mimgui.ImVec4(0.75, 0.15, 0.18, 0.80)

    -- TITLE BAR
    colors[mimgui.Col.TitleBg] = mimgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[mimgui.Col.TitleBgActive] = mimgui.ImVec4(0.60, 0.10, 0.12, 0.90)
    colors[mimgui.Col.TitleBgCollapsed] = mimgui.ImVec4(0.60, 0.10, 0.12, 0.60)

    -- SCROLLBAR
    colors[mimgui.Col.ScrollbarBg] = mimgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[mimgui.Col.ScrollbarGrab] = mimgui.ImVec4(0.60, 0.10, 0.12, 0.60)
    colors[mimgui.Col.ScrollbarGrabHovered] = mimgui.ImVec4(0.80, 0.15, 0.18, 0.80)
    colors[mimgui.Col.ScrollbarGrabActive] = mimgui.ImVec4(0.90, 0.18, 0.22, 1.00)

    -- CHECKBOX & SLIDER
    colors[mimgui.Col.CheckMark] = mimgui.ImVec4(0.90, 0.18, 0.22, 1.00)
    colors[mimgui.Col.SliderGrab] = mimgui.ImVec4(0.75, 0.15, 0.18, 0.80)
    colors[mimgui.Col.SliderGrabActive] = mimgui.ImVec4(0.90, 0.18, 0.22, 1.00)

    -- BUTTON
    colors[mimgui.Col.Button] = mimgui.ImVec4(0.16, 0.16, 0.16, 1.00)
    colors[mimgui.Col.ButtonHovered] = mimgui.ImVec4(0.75, 0.15, 0.18, 0.70)
    colors[mimgui.Col.ButtonActive] = mimgui.ImVec4(0.90, 0.18, 0.22, 1.00)

    -- HEADER
    colors[mimgui.Col.Header] = mimgui.ImVec4(0.16, 0.16, 0.16, 1.00)
    colors[mimgui.Col.HeaderHovered] = mimgui.ImVec4(0.75, 0.15, 0.18, 0.70)
    colors[mimgui.Col.HeaderActive] = mimgui.ImVec4(0.90, 0.18, 0.22, 1.00)

    -- SEPARATOR
    colors[mimgui.Col.Separator] = mimgui.ImVec4(0.60, 0.10, 0.12, 0.50)
    colors[mimgui.Col.SeparatorHovered] = mimgui.ImVec4(0.80, 0.15, 0.18, 0.80)
    colors[mimgui.Col.SeparatorActive] = mimgui.ImVec4(0.90, 0.18, 0.22, 1.00)

    -- TEXT SELECT
    colors[mimgui.Col.TextSelectedBg] = mimgui.ImVec4(0.75, 0.15, 0.18, 0.35)

    -- PLOT
    colors[mimgui.Col.PlotLines] = mimgui.ImVec4(0.90, 0.18, 0.22, 0.80)
    colors[mimgui.Col.PlotLinesHovered] = mimgui.ImVec4(1.00, 0.25, 0.28, 1.00)
    colors[mimgui.Col.PlotHistogram] = mimgui.ImVec4(0.90, 0.18, 0.22, 0.80)
    colors[mimgui.Col.PlotHistogramHovered] = mimgui.ImVec4(1.00, 0.25, 0.28, 1.00)


end

function main()
    local showWindow = mimgui.new.bool(false)
    local selectedCategoryIndex = mimgui.new.int(1) -- Default to the first category

    while not isSampAvailable() do wait(100) end

    mimgui.OnInitialize(applyStyle)

    events.onInitGame = function()
        sampAddChatMessage("{C1121F}[AutoRP ENGINE + MOTORSPORT] Script berhasil dimuat!", -1)
        sampAddChatMessage("{FFFFFF}Gunakan {C1121F}/wmenu{FFFFFF} untuk membuka menu GUI atau {C1121F}/wscmdhelp{FFFFFF} untuk melihat command cepat", -1)
    end

    sampRegisterChatCommand('wmenu', function() showWindow[0] = not showWindow[0] end)
    
    -- Command trigger RP untuk akses cepat
    sampRegisterChatCommand('wsbuka', function()
        local cmds = findRpCommands('Buka Pelayanan')
        if cmds then
            sampAddChatMessage("{C1121F}[AutoRP] Menjalankan: Buka Pelayanan", -1)
            executeCommands(cmds)
        else
            sampAddChatMessage("{FF0000}[AutoRP] Command 'Buka Pelayanan' tidak ditemukan!", -1)
        end
    end)
    
    sampRegisterChatCommand('wstutup', function()
        local cmds = findRpCommands('Tutup Pelayanan')
        if cmds then
            sampAddChatMessage("{C1121F}[AutoRP] Menjalankan: Tutup Pelayanan", -1)
            executeCommands(cmds)
        else
            sampAddChatMessage("{FF0000}[AutoRP] Command 'Tutup Pelayanan' tidak ditemukan!", -1)
        end
    end)

    sampRegisterChatCommand('wsbukaTT', function()
        local cmds = findRpCommands('Pengumuman Tanpa Toolkit')
        if cmds then
            sampAddChatMessage("{C1121F}[AutoRP] Menjalankan: Pengumuman Buka WS Tanpa Toolkit", -1)
            executeCommands(cmds)
        else
            sampAddChatMessage("{FF0000}[AutoRP] Command 'Pengumuman Tanpa Toolkit' tidak ditemukan!", -1)
        end
    end)

    sampRegisterChatCommand('repair', function()
        local cmds = findRpCommands('repair Kendaraan')
        if cmds then
            sampAddChatMessage("{C1121F}[AutoRP] Menjalankan: repair Kendaraan", -1)
            executeCommands(cmds)
        else
            sampAddChatMessage("{FF0000}[AutoRP] Command 'repair Kendaraan' tidak ditemukan!", -1)
        end
    end)

    sampRegisterChatCommand('hello', function()
        local cmds = findRpCommands('menyambut Customer')
        if cmds then
            sampAddChatMessage("{C1121F}[AutoRP] Menjalankan: Menyambut Customer", -1)
            executeCommands(cmds)
        else
            sampAddChatMessage("{FF0000}[AutoRP] Command 'Menyambut Customer' tidak ditemukan!", -1)
        end
    end)

    sampRegisterChatCommand('tq', function()
        local cmds = findRpCommands('Terimakasih Customer')
        if cmds then
            sampAddChatMessage("{C1121F}[AutoRP] Menjalankan: Menyambut Customer", -1)
            executeCommands(cmds)
        else
            sampAddChatMessage("{FF0000}[AutoRP] Command 'Menyambut Customer' tidak ditemukan!", -1)
        end
    end)
    
    
    -- Command bantuan untuk melihat daftar command yang tersedia
        sampRegisterChatCommand('wscmdhelp', function()
        sampAddChatMessage("{C1121F}=== [AutoRP ENGINE + MOTORSPORT] Daftar Command ===", -1)
        sampAddChatMessage("{C1121F}/wmenu{FFFFFF} - Buka/tutup menu GUI", -1)
        sampAddChatMessage("{C1121F}/wsbuka{FFFFFF} - Buka pelayanan", -1)
        sampAddChatMessage("{C1121F}/wstutup{FFFFFF} - Tutup pelayanan", -1)
        sampAddChatMessage("{C1121F}/wsbukaTT{FFFFFF} - Pengumuman darurat", -1)
        sampAddChatMessage("{C1121F}/repair{FFFFFF} - repair kendaraan", -1)
        sampAddChatMessage("{C1121F}/hello{FFFFFF} - menyambut customer", -1)
        sampAddChatMessage("{C1121F}/tq{FFFFFF} - mengantar customer pulang", -1)
        sampAddChatMessage("{C1121F}/wscmdhelp{FFFFFF} - Menampilkan bantuan ini", -1)
        sampAddChatMessage("{C1121F}===================================", -1)
    end)

    mimgui.OnFrame(function() return showWindow[0] end, function()
        mimgui.SetNextWindowSize(mimgui.ImVec2(650, 450), mimgui.Cond.FirstUseEver)
        mimgui.Begin('Auto RP ENGINE + MOTORSPORT', showWindow)

        mimgui.Text('Author: Arkananta Studio')
        mimgui.Separator()

        -- Left Panel: Category List
        mimgui.BeginChild('CategoryList', mimgui.ImVec2(220, 0), true)
        mimgui.Text('Kategori:')
        mimgui.Separator()
        for i, category in ipairs(rpCategories) do
            if mimgui.Selectable(category.name, selectedCategoryIndex[0] == i) then
                selectedCategoryIndex[0] = i
            end
        end
        mimgui.EndChild()

        mimgui.SameLine()

        -- Right Panel: Category Details and RP Buttons
        mimgui.BeginChild('RightPanel', mimgui.ImVec2(0, 0), false)
        local cat_idx = selectedCategoryIndex[0]
        if rpCategories[cat_idx] then
            local selected_category = rpCategories[cat_idx]
            mimgui.Text(selected_category.name)
            mimgui.Separator()
            mimgui.TextWrapped('Deskripsi: ' .. selected_category.description)
            mimgui.Separator()

            for _, rp in ipairs(selected_category.rps) do
                if rp.actions then
                    if mimgui.CollapsingHeader(rp.name) then
                        mimgui.TextWrapped(rp.desc)
                        for _, action in ipairs(rp.actions) do
                            mimgui.TextWrapped(action.name .. ': ' .. action.desc)
                            if mimgui.Button('Jalankan ' .. action.name, mimgui.ImVec2(-1, 0)) then
                                executeCommands(action.cmds)
                                showWindow[0] = false
                            end
                        end
                    end
                else
                    if mimgui.Button(rp.name, mimgui.ImVec2(-1, 0)) then
                        executeCommands(rp.cmds)
                        showWindow[0] = false
                    end
                    if mimgui.IsItemHovered() then
                        mimgui.BeginTooltip()
                        mimgui.Text(rp.desc)
                        mimgui.EndTooltip()
                    end
                end
            end
        else
            mimgui.Text('Choose a category from the left panel.')
        end
        mimgui.EndChild()

        mimgui.End()
    end)
end


function isSampAvailable()
    return isSampLoaded() and isSampfuncsLoaded()
end

main()