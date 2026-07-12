script_name("Command List Menu")
script_author("Arkananta Studio")
script_description("Menampilkan daftar lengkap command dari berbagai monet/script MoonLoader")

require "lib.moonloader"
local mimgui = require "lib.mimgui"
local ffi = require "ffi"
local encoding = require "encoding"
encoding.default = "CP1252"
local u8 = encoding.UTF8

-- Variables
local showMenu = mimgui.new.bool(false)
local searchBuffer = mimgui.new.char[256]("")

-- Customizing Colors
local colorTitle = mimgui.ImVec4(1.0, 0.8, 0.2, 1.0)
local colorCommand = mimgui.ImVec4(1.0, 1.0, 0.0, 1.0)
local colorDesc = mimgui.ImVec4(0.8, 0.8, 0.8, 1.0)

-- Database Manual Script & Command (Mudah diedit)
local scriptData = {
    {
        category = "Auto Fish It (Pancing Baru)",
        color = mimgui.ImVec4(0.3, 0.8, 1.0, 1.0), -- Light Blue
        commands = {
            { cmd = "/autofishit", desc = "Mengaktifkan auto fishing (sinkronisasi otomatis dengan server /fauto)" },
            { cmd = "/autofishit off", desc = "Menonaktifkan auto fishing secara penuh" }
        }
    },
    {
        category = "Auto Fish (Pancing Lama)",
        color = mimgui.ImVec4(0.3, 0.7, 0.9, 1.0), -- Blue-gray
        commands = {
            { cmd = "/autofish", desc = "Mengaktifkan atau menonaktifkan auto memancing konvensional" }
        }
    },
    {
        category = "Anti AFK",
        color = mimgui.ImVec4(1.0, 0.5, 0.5, 1.0), -- Light Red
        commands = {
            { cmd = "Otomatis", desc = "Mencegah kick server dengan otomatis mendeteksi pesan AFK" }
        }
    },
    {
        category = "Auto Job Kayu AFK",
        color = mimgui.ImVec4(0.8, 0.5, 0.3, 1.0), -- Brownish
        commands = {
            { cmd = "/startrekam", desc = "Mulai merekam koordinat kayu baru" },
            { cmd = "/stoprekam", desc = "Berhenti merekam dan menyimpan koordinat ke file" },
            { cmd = "/cp", desc = "Menambahkan checkpoint koordinat saat mode rekam aktif" },
            { cmd = "/startjob", desc = "Memulai bot otomatisasi pekerjaan kayu (bisa tekan F9)" },
            { cmd = "/stopjob", desc = "Menghentikan bot pekerjaan kayu (bisa tekan F9)" },
            { cmd = "/cpstatus", desc = "Melihat semua daftar checkpoint kayu yang terekam" }
        }
    },
    {
        category = "AutoWalk",
        color = mimgui.ImVec4(0.4, 0.8, 1.0, 1.0), -- Cyan
        commands = {
            { cmd = "/awmenu", desc = "Membuka GUI Manager AutoWalk: daftar file, buat, hapus, pilih, preview koordinat" },
            { cmd = "/autowalk", desc = "Mengaktifkan atau mematikan fitur berjalan otomatis" },
            { cmd = "/sprint true/false", desc = "Toggle mode sprint (lari) atau jalan saat autowalk berjalan" },
            { cmd = "/createfile <nama>", desc = "Membuat file konfigurasi route autowalk baru" },
            { cmd = "/selectfile <nama>", desc = "Memilih file konfigurasi route berjalan" },
            { cmd = "/setcord", desc = "Menyimpan koordinat posisi saat ini sebagai titik route" },
            { cmd = "/remcord <index>", desc = "Menghapus koordinat berdasarkan nomor indeks" },
            { cmd = "/setwait <detik>", desc = "Mengatur jeda waktu diam di setiap titik koordinat" },
            { cmd = "/setclick <tombol>", desc = "Mengatur tombol yang ditekan otomatis di setiap checkpoint (Y, SPACE, ENTER, dll). Gunakan /setclick off untuk menonaktifkan" },
            { cmd = "/setcdclick <ms>", desc = "Mengatur jeda/cooldown sebelum tombol ditekan di checkpoint (default 0 ms)" },
            { cmd = "/woodcount", desc = "Menampilkan total kayu yang telah berhasil diambil" },
            { cmd = "/resetcount", desc = "Merestart/mengatur ulang counter kayu ke 0" },
            { cmd = "/helpcommand", desc = "Menampilkan bantuan lengkap autowalk di chat log" }
        }
    },
    {
        category = "Medis & Kalkulator",
        color = mimgui.ImVec4(1.0, 0.4, 0.4, 1.0), -- Red
        commands = {
            { cmd = "/md", desc = "Membuka menu UI utama pelayanan medis" },
            { cmd = "/kalkulator", desc = "Membuka kalkulator cerdas khusus medis" },
            { cmd = "/cmdhelp", desc = "Melihat bantuan command medis lengkap di chat" },
            { cmd = "/pbuka", desc = "RP Membuka pelayanan medis rumah sakit" },
            { cmd = "/ptutup", desc = "RP Menutup pelayanan medis rumah sakit" },
            { cmd = "/pdarurat", desc = "RP Mengumumkan status darurat medis" },
            { cmd = "/ptreatment", desc = "RP Memberikan suntik vitamin / treatment medis" },
            { cmd = "/pcek", desc = "RP Memeriksa kondisi kesehatan pasien" },
            { cmd = "/prk", desc = "RP Melakukan pertolongan pertama / resusitasi (revive)" },
            { cmd = "/psks", desc = "RP Membuat Surat Keterangan Sehat (SKS)" },
            { cmd = "/pcnormal", desc = "RP Memberikan hasil cek kesehatan normal" },
            { cmd = "/pcoprasi", desc = "RP Memberikan hasil tindakan operasi medis" },
            { cmd = "/pskstes", desc = "RP Melakukan tes kesehatan untuk pembuatan SKS" },
            { cmd = "/pskscetak", desc = "RP Mencetak dan memberikan berkas SKS" },
            { cmd = "/pbpjs", desc = "RP Mendaftarkan kartu kesehatan BPJS pasien" },
            { cmd = "/popersi", desc = "RP Melakukan tindakan bedah operasi luka tembak" },
            { cmd = "/ppatah", desc = "RP Memberikan penanganan cedera patah tulang" },
            { cmd = "/psunat", desc = "RP Melakukan tindakan sirkumsisi / sunat" },
            { cmd = "/pinvoice", desc = "RP Mencetak tagihan (invoice) pelayanan medis" },
            { cmd = "/pcucitangan", desc = "RP Mencuci tangan sesuai protokol medis" },
            { cmd = "/pdokoperasi", desc = "RP Mengambil dokumentasi pasca-tindakan operasi" },
            { cmd = "/pck", desc = "RP Menyatakan pasien meninggal dunia (Character Kill)" }
        }
    },
    {
        category = "AutoRP Resto",
        color = mimgui.ImVec4(1.0, 0.6, 0.2, 1.0), -- Orange
        commands = {
            { cmd = "/rmenu", desc = "Membuka menu utama RP Restoran" },
            { cmd = "/ropen1", desc = "RP Mengumumkan resto dibuka untuk umum" },
            { cmd = "/ropen2", desc = "RP Mengumumkan layanan delivery order resto" }
        }
    },
    {
        category = "Workshop Helper",
        color = mimgui.ImVec4(0.9, 0.8, 0.3, 1.0), -- Light Gold
        commands = {
            { cmd = "/wmenu", desc = "Membuka menu UI utama Workshop" },
            { cmd = "/wsbuka", desc = "RP Membuka pelayanan servis kendaraan di workshop" },
            { cmd = "/wstutup", desc = "RP Menutup aktivitas pelayanan workshop" },
            { cmd = "/wsbukaTT", desc = "RP Membuka pelayanan modifikasi khusus ban/velg/komponen" },
            { cmd = "/repair", desc = "RP Memperbaiki bodi dan mesin kendaraan pelanggan" },
            { cmd = "/hello", desc = "RP Menyapa ramah pelanggan yang datang" },
            { cmd = "/tq", desc = "RP Mengucapkan terima kasih setelah pelayanan selesai" },
            { cmd = "/wscmdhelp", desc = "Menampilkan bantuan command workshop lengkap di chat" }
        }
    },
    {
        category = "InDrive Helper",
        color = mimgui.ImVec4(0.2, 0.9, 0.6, 1.0), -- Emerald
        commands = {
            { cmd = "/td", desc = "Membuka/menutup UI panel InDrive" },
            { cmd = "/tbuka", desc = "RP Membuka penerimaan orderan taksi / indrive" },
            { cmd = "/ttutup", desc = "RP Menutup penerimaan orderan taksi / indrive" },
            { cmd = "/tcmdhelp", desc = "Menampilkan daftar bantuan command indrive lengkap di chat" }
        }
    },
    {
        category = "Invoice Bot (AutoInvoice)",
        color = mimgui.ImVec4(0.4, 1.0, 0.8, 1.0), -- Mint
        commands = {
            { cmd = "/autoinvoice [id] [nama_invoice] [harga]", desc = "Mengisi form invoice secara otomatis untuk player ID target" }
        }
    },
    {
        category = "Universal Detector",
        color = mimgui.ImVec4(0.5, 0.9, 0.9, 1.0), -- Light Cyan
        commands = {
            { cmd = "/detector", desc = "Menampilkan status aktif deteksi Textdraw, Dialog, dan RPC" },
            { cmd = "/dettd", desc = "Mengaktifkan/menonaktifkan deteksi Textdraw di layar" },
            { cmd = "/detdialog", desc = "Mengaktifkan/menonaktifkan deteksi Dialog box server" },
            { cmd = "/detrpc", desc = "Mengaktifkan/menonaktifkan deteksi paket RPC server" }
        }
    },
    {
        category = "Notepad SAMP",
        color = mimgui.ImVec4(1.0, 0.9, 0.4, 1.0), -- Yellow
        commands = {
            { cmd = "/note", desc = "Membuka UI Notepad modern dalam game untuk mencatat teks RP" }
        }
    },
    {
        category = "Nametags",
        color = mimgui.ImVec4(0.4, 1.0, 0.4, 1.0), -- Light Green
        commands = {
            { cmd = "/nametags", desc = "Membuka menu konfigurasi nametags player" }
        }
    },
    {
        category = "MonetLoader Manager",
        color = mimgui.ImVec4(0.7, 0.8, 1.0, 1.0), -- Ice Blue
        commands = {
            { cmd = "/ml", desc = "Membuka ImGui Manager untuk mengatur hak akses script per server" }
        }
    },
    {
        category = "Voice Smart Fix",
        color = mimgui.ImVec4(0.8, 0.4, 1.0, 1.0), -- Purple
        commands = {
            { cmd = "/rvoice", desc = "Refresh koneksi voice chat SAMP jika suara terputus / bug" }
        }
    },
    {
        category = "System Reload & Boost",
        color = mimgui.ImVec4(0.7, 0.7, 0.7, 1.0), -- Gray
        commands = {
            { cmd = "Tombol F3", desc = "Memuat ulang (reload) semua script Moonloader secara instan" },
            { cmd = "Otomatis", desc = "Menstabilkan FPS, optimasi RAM, dan membersihkan sun glare game" }
        }
    },
    {
        category = "Auto Reboot",
        color = mimgui.ImVec4(1.0, 0.4, 0.2, 1.0), -- Red-Orange
        commands = {
            { cmd = "Otomatis", desc = "Auto reconnect / reboot jika koneksi ke server terputus secara tidak terduga" }
        }
    },
    {
        category = "Auto Reconnect",
        color = mimgui.ImVec4(1.0, 0.55, 0.2, 1.0), -- Orange
        commands = {
            { cmd = "Otomatis", desc = "Secara otomatis mencoba kembali terhubung ke server jika kena kick atau disconnect" }
        }
    },
    {
        category = "Auto Otot (Gym AFK)",
        color = mimgui.ImVec4(0.9, 0.3, 0.5, 1.0), -- Pink-Red
        commands = {
            { cmd = "Otomatis", desc = "Melakukan gym / latihan otot secara otomatis di gym sambil AFK" }
        }
    },
    {
        category = "Auto Pay",
        color = mimgui.ImVec4(0.3, 0.9, 0.5, 1.0), -- Green
        commands = {
            { cmd = "Otomatis", desc = "Otomatis membayar dialog pembayaran yang muncul dari server" }
        }
    },
    {
        category = "Detect ID",
        color = mimgui.ImVec4(0.6, 0.8, 1.0, 1.0), -- Sky Blue
        commands = {
            { cmd = "/detectid", desc = "Menampilkan ID dari player terdekat di sekitar karakter" }
        }
    },
    {
        category = "DMG Infinity",
        color = mimgui.ImVec4(1.0, 0.2, 0.2, 1.0), -- Bright Red
        commands = {
            { cmd = "/dmginf", desc = "Membuka panel pengaturan DMG Infinity (cheat damage)" }
        }
    },
    {
        category = "GameFixer",
        color = mimgui.ImVec4(0.5, 1.0, 0.7, 1.0), -- Light Teal
        commands = {
            { cmd = "Otomatis", desc = "Memperbaiki berbagai bug visual & gameplay GTA SA secara otomatis saat join" }
        }
    },
    {
        category = "Kill Streak Blade",
        color = mimgui.ImVec4(1.0, 0.3, 0.6, 1.0), -- Hot Pink
        commands = {
            { cmd = "Otomatis", desc = "Menampilkan notifikasi kill streak saat berhasil membunuh pemain lain" }
        }
    },
    {
        category = "Teleport",
        color = mimgui.ImVec4(0.5, 0.5, 1.0, 1.0), -- Soft Blue-Purple
        commands = {
            { cmd = "/teleport", desc = "Membuka menu teleport ke berbagai lokasi yang tersimpan" },
            { cmd = "/tp <nama>", desc = "Teleport cepat ke lokasi berdasarkan nama yang tersimpan" }
        }
    },
    {
        category = "Stream Chat Overlay",
        color = mimgui.ImVec4(0.8, 0.2, 1.0, 1.0), -- Purple
        commands = {
            { cmd = "/streamchat", desc = "Membuka/menutup overlay chat stream di layar game" }
        }
    },
    {
        category = "YouTube Live Chat",
        color = mimgui.ImVec4(1.0, 0.15, 0.15, 1.0), -- YouTube Red
        commands = {
            { cmd = "/ytchat", desc = "Membuka/menutup overlay YouTube Live Chat di layar game" },
            { cmd = "/ytchatpanel", desc = "Membuka panel setup: isi API Key & link video, simpan config, mulai/stop" },
            { cmd = "/ytoverlay", desc = "Alias untuk toggle overlay chat (sama dengan /ytchat)" },
            { cmd = "/ytlogfolder", desc = "Membuka folder log chat di Windows Explorer (config/ytchat/logs/)" },
            { cmd = "/ytclearcfg", desc = "Menghapus file config tersimpan dan mereset API Key (jika ingin ganti key)" }
        }
    }
}

-- Mimgui Frame
mimgui.OnFrame(function() return showMenu[0] end, function()
    local screenResX, screenResY = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(screenResX / 2, screenResY / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(600, 550), mimgui.Cond.FirstUseEver)
    
    mimgui.Begin("📜 SAMP Command & Script List", showMenu, mimgui.WindowFlags.NoCollapse)
    
    mimgui.TextColored(colorTitle, "Gunakan kotak pencarian di bawah untuk memfilter kategori atau command.")
    mimgui.Spacing()
    
    -- Pencarian
    mimgui.Text("Cari Command:")
    mimgui.SameLine()
    mimgui.PushItemWidth(-1)
    mimgui.InputText("##search", searchBuffer, 256)
    mimgui.PopItemWidth()
    
    mimgui.Separator()
    mimgui.Spacing()
    
    local searchText = string.lower(ffi.string(searchBuffer))
    
    -- List container with scrollbar
    mimgui.BeginChild("ListChild", mimgui.ImVec2(0, -40), true)
    
    for _, script in ipairs(scriptData) do
        local matchesSearch = false
        
        -- Cek pencarian di kategori atau command
        if string.find(string.lower(script.category), searchText, 1, true) then
            matchesSearch = true
        else
            for _, cmdInfo in ipairs(script.commands) do
                if string.find(string.lower(cmdInfo.cmd), searchText, 1, true) or 
                   string.find(string.lower(cmdInfo.desc), searchText, 1, true) then
                    matchesSearch = true
                    break
                end
            end
        end
        
        -- Render jika match pencarian atau search kosong
        if matchesSearch or searchText == "" then
            mimgui.PushStyleColor(mimgui.Col.Text, script.color)
            mimgui.Text("=== " .. string.upper(script.category) .. " ===")
            mimgui.PopStyleColor()
            
            for _, cmdInfo in ipairs(script.commands) do
                mimgui.TextColored(colorCommand, cmdInfo.cmd)
                mimgui.TextColored(colorDesc, cmdInfo.desc)
                mimgui.Spacing()
            end
            mimgui.Separator()
            mimgui.Spacing()
        end
    end
    
    mimgui.EndChild()
    
    -- Close button
    if mimgui.Button("Tutup UI", mimgui.ImVec2(-1, 30)) then
        showMenu[0] = false
    end
    
    mimgui.End()
end)

function main()
    repeat wait(0) until isSampAvailable()
    
    sampRegisterChatCommand("scriptlist", function() showMenu[0] = not showMenu[0] end)
    sampRegisterChatCommand("cmdlist", function() showMenu[0] = not showMenu[0] end)
    
    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[ScriptList] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/cmdlist{FFFFFF} atau {00FF00}/scriptlist{FFFFFF} untuk melihat daftar command.", -1)
            break
        end
    end
    
    while true do
        wait(0)
    end
end
