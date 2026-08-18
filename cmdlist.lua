-- ============================================================
--  SAMP COMMAND & SCRIPT LIST - Moonloader
--  Ketik /cmdlist atau /scriptlist untuk membuka menu
-- ============================================================

script_name("CMD List")
script_author("Yohanez")
script_description("Daftar lengkap command & script Moonloader yang aktif")

require "lib.moonloader"
local mimgui = require "mimgui"
local theme  = require "lib.mimgui_theme"
local ffi    = require "ffi"

-- ── UI STATE ─────────────────────────────────────────────────
local showMenu    = mimgui.new.bool(false)
local searchBuffer = mimgui.new.char[256]("")

-- ── WARNA ────────────────────────────────────────────────────
local colorTitle   = mimgui.ImVec4(1.0,  0.85, 0.2,  1.0) -- Kuning emas
local colorCommand = mimgui.ImVec4(0.35, 0.9,  1.0,  1.0) -- Cyan
local colorDesc    = mimgui.ImVec4(0.78, 0.78, 0.78, 1.0) -- Abu-abu terang

-- ============================================================
-- DATA SCRIPT & COMMAND (UPDATE TERAKHIR: Juli 2026)
-- ============================================================
local scriptData = {

    -- ── SISTEM UMUM ───────────────────────────────────────────
    {
        category = "CMD List (Script Ini)",
        color = mimgui.ImVec4(1.0, 0.85, 0.2, 1.0), -- Gold
        commands = {
            { cmd = "/cmdlist", desc = "Membuka daftar lengkap semua command & script yang aktif" },
            { cmd = "/scriptlist", desc = "Alias dari /cmdlist (sama fungsinya)" },
        }
    },
    {
        category = "GameFixer",
        color = mimgui.ImVec4(0.5, 1.0, 0.7, 1.0), -- Teal
        commands = {
            { cmd = "Otomatis", desc = "Memperbaiki berbagai bug visual & gameplay GTA SA secara otomatis saat join" },
            { cmd = "/q", desc = "Keluar game dengan cepat (fast quit)" },
            { cmd = "/quit", desc = "Alias dari /q untuk keluar game" },
            { cmd = "/gmenu", desc = "Membuka menu utama GameFixer" },
        }
    },
    {
        category = "System Reload",
        color = mimgui.ImVec4(0.7, 0.7, 0.7, 1.0), -- Gray
        commands = {
            { cmd = "Tombol F3", desc = "Memuat ulang (reload) semua script Moonloader secara instan" },
        }
    },
    {
        category = "MonetLoader Manager",
        color = mimgui.ImVec4(0.7, 0.8, 1.0, 1.0), -- Ice Blue
        commands = {
            { cmd = "/ml", desc = "Membuka panel UI untuk mengatur hak akses & profil script per server" },
        }
    },

    -- ── PERGERAKAN & UTILITAS ─────────────────────────────────
    {
        category = "Auto Walk / Auto Job",
        color = mimgui.ImVec4(0.3, 0.85, 0.45, 1.0), -- Hijau
        commands = {
            { cmd = "/awmenu", desc = "Membuka GUI Manager file rute JSON (list, buat, hapus, preview rute)" },
            { cmd = "/autowalk", desc = "Memulai/menghentikan pergerakan otomatis sesuai rute yang dipilih" },
            { cmd = "/sprint true/false", desc = "Mengatur mode gerak: true = lari (sprint), false = jalan kaki" },
            { cmd = "/createfile <nama>", desc = "Membuat file rute JSON baru dengan nama yang ditentukan" },
            { cmd = "/selectfile <nama>", desc = "Memilih dan mengaktifkan file rute JSON yang sudah ada" },
            { cmd = "/setcord", desc = "Menambahkan titik koordinat posisi karakter saat ini ke rute aktif" },
            { cmd = "/remcord <index>", desc = "Menghapus titik koordinat ke-[index] dari rute aktif" },
            { cmd = "/setwait <ms>", desc = "Mengatur jeda waktu (ms) antar titik rute saat berjalan" },
            { cmd = "/setclick <key>", desc = "Mengatur tombol yang diklik otomatis di setiap titik rute" },
            { cmd = "/setcdclick <ms>", desc = "Mengatur cooldown (ms) antar klik otomatis" },
            { cmd = "/woodcount", desc = "Menampilkan hitungan kayu/item yang berhasil dikumpulkan" },
            { cmd = "/resetcount", desc = "Mereset counter item yang dikumpulkan ke nol" },
            { cmd = "/helpcommand", desc = "Menampilkan ringkasan semua command autowalk di chat" },
        }
    },
    {
        category = "Teleport",
        color = mimgui.ImVec4(0.5, 0.5, 1.0, 1.0), -- Biru-Ungu
        commands = {
            { cmd = "/tp", desc = "Membuka menu daftar lokasi teleport tersimpan" },
            { cmd = "/tpgo <nama>", desc = "Teleport langsung ke lokasi berdasarkan nama" },
            { cmd = "/tpreload", desc = "Memuat ulang daftar lokasi dari file route.json" },
            { cmd = "/tplist", desc = "Menampilkan semua nama lokasi yang tersimpan di chat" },
        }
    },

    -- ── PEMBAYARAN & EKONOMI ──────────────────────────────────
    {
        category = "Auto Pay",
        color = mimgui.ImVec4(0.3, 0.9, 0.5, 1.0), -- Hijau
        commands = {
            { cmd = "/autopay <ID> <Jumlah>", desc = "Mengirim sejumlah uang ke pemain secara otomatis (berhenti otomatis jika pemain offline atau uang tidak cukup)" },
        }
    },
    {
        category = "Invoice",
        color = mimgui.ImVec4(0.95, 0.75, 0.2, 1.0), -- Kuning
        commands = {
            { cmd = "/autoinvoice <ID>", desc = "Mengirim invoice otomatis ke ID pemain terdekat" },
        }
    },

    -- ── RESTORAN ─────────────────────────────────────────────
    {
        category = "Restoran (Resto)",
        color = mimgui.ImVec4(1.0, 0.55, 0.15, 1.0), -- Oranye
        commands = {
            { cmd = "/rmenu", desc = "Membuka menu utama restoran (menu iklan & pengaturan)" },
            { cmd = "/ropen1", desc = "Menjalankan iklan buka restoran versi 1 (chat otomatis)" },
            { cmd = "/ropen2", desc = "Menjalankan iklan buka restoran versi 2" },
            { cmd = "/restock", desc = "Menjalankan loop restock bahan makanan otomatis (/cook → Enter)" },
        }
    },

    -- ── WORKSHOP ─────────────────────────────────────────────
    {
        category = "Workshop (Bengkel)",
        color = mimgui.ImVec4(0.6, 0.45, 0.9, 1.0), -- Ungu
        commands = {
            { cmd = "/wmenu", desc = "Membuka/menutup GUI panel workshop" },
            { cmd = "/wsbuka", desc = "Menjalankan urutan RP buka workshop secara otomatis" },
            { cmd = "/wstutup", desc = "Menjalankan urutan RP tutup workshop secara otomatis" },
            { cmd = "/wsbukaTT", desc = "Buka workshop versi khusus (TT = tidak terima tamu)" },
            { cmd = "/repair", desc = "Mengirim pesan RP perbaikan kendaraan di workshop" },
            { cmd = "/hello", desc = "Mengirim pesan sambutan workshop kepada pemain" },
            { cmd = "/tq", desc = "Mengirim pesan terima kasih workshop kepada pemain" },
            { cmd = "/wscmdhelp", desc = "Menampilkan daftar command workshop di chat" },
        }
    },

    -- ── MEDIS (DISABLED - TERSEDIA SAAT AKTIF) ────────────────
    {
        category = "Medis / Rumah Sakit (disabled_scripts)",
        color = mimgui.ImVec4(0.9, 0.2, 0.35, 1.0), -- Merah
        commands = {
            { cmd = "/md", desc = "Membuka/menutup GUI panel medis (Auto RP medis)" },
            { cmd = "/cmdhelp", desc = "Menampilkan daftar command medis di chat" },
            { cmd = "/pbuka", desc = "Auto RP: Buka Pelayanan rumah sakit" },
            { cmd = "/ptutup", desc = "Auto RP: Tutup Pelayanan rumah sakit" },
            { cmd = "/pdarurat", desc = "Auto RP: Kondisi Darurat" },
            { cmd = "/ptreatment", desc = "Auto RP: Treatment (Suntik Vitamin)" },
            { cmd = "/pcek", desc = "Auto RP: Cek Kesehatan pasien" },
            { cmd = "/prk", desc = "Auto RP: Revive Pasien" },
            { cmd = "/psks", desc = "Auto RP: Surat Keterangan Sehat (SKS)" },
            { cmd = "/pskstes", desc = "Auto RP: SKS → Tes" },
            { cmd = "/pskscetak", desc = "Auto RP: SKS → Cetak" },
            { cmd = "/pbpjs", desc = "Auto RP: BPJS" },
            { cmd = "/popersi", desc = "Auto RP: Operasi Luka Tembak" },
            { cmd = "/ppatah", desc = "Auto RP: Patah Tulang" },
            { cmd = "/psunat", desc = "Auto RP: Sunat" },
            { cmd = "/pinvoice", desc = "Auto RP: Invoice pasien" },
            { cmd = "/pcucitangan", desc = "Auto RP: Cuci Tangan" },
            { cmd = "/pdokoperasi", desc = "Auto RP: Dokumentasi Operasi" },
            { cmd = "/pcnormal", desc = "Auto RP: Hasil Cek Normal" },
            { cmd = "/pcoprasi", desc = "Auto RP: Hasil Cek Operasi" },
            { cmd = "/pck", desc = "Auto RP: CK / Meninggal" },
        }
    },

    -- ── AUTO JOB / KAYU AFK (DISABLED) ───────────────────────
    {
        category = "Auto Job / Kayu AFK (disabled_scripts)",
        color = mimgui.ImVec4(0.5, 0.8, 0.35, 1.0), -- Hijau muda
        commands = {
            { cmd = "/startjob", desc = "Memulai auto job (mode rekaman rute aktif)" },
            { cmd = "/stopjob", desc = "Menghentikan auto job yang sedang berjalan" },
            { cmd = "/cpstatus", desc = "Menampilkan status checkpoint auto job saat ini" },
        }
    },

    -- ── DETEKSI & DEBUG ───────────────────────────────────────
    {
        category = "Detector (TextDraw & Dialog)",
        color = mimgui.ImVec4(0.0, 0.85, 0.85, 1.0), -- Cyan
        commands = {
            { cmd = "/detector", desc = "Menampilkan status deteksi: TextDraw, Dialog, RPC aktif/nonaktif" },
            { cmd = "/dettd", desc = "Toggle: nyalakan/matikan pendeteksi ID TextDraw" },
            { cmd = "/detdialog", desc = "Toggle: nyalakan/matikan pendeteksi konten Dialog server" },
            { cmd = "/detrpc", desc = "Toggle: nyalakan/matikan pendeteksi paket RPC server" },
        }
    },
    {
        category = "Detect ID Player",
        color = mimgui.ImVec4(0.6, 0.8, 1.0, 1.0), -- Biru langit
        commands = {
            { cmd = "/autoinvoice <ID>", desc = "Mendeteksi dan otomatis mengirim invoice ke ID pemain target" },
        }
    },

    -- ── CATATAN & KALKULATOR ──────────────────────────────────
    {
        category = "Notepad (Catatan)",
        color = mimgui.ImVec4(1.0, 0.95, 0.5, 1.0), -- Kuning muda
        commands = {
            { cmd = "/note", desc = "Membuka/menutup GUI notepad untuk menulis catatan in-game" },
        }
    },
    {
        category = "Kalkulator",
        color = mimgui.ImVec4(0.55, 0.9, 0.75, 1.0), -- Mint
        commands = {
            { cmd = "/kalkulator", desc = "Membuka kalkulator in-game untuk kalkulasi cepat" },
        }
    },

    -- ── STREAMING & OVERLAY ───────────────────────────────────
    {
        category = "YouTube Live Chat",
        color = mimgui.ImVec4(1.0, 0.15, 0.15, 1.0), -- Merah YouTube
        commands = {
            { cmd = "/ytchat", desc = "Membuka/menutup overlay YouTube Live Chat di layar game" },
            { cmd = "/ytchatpanel", desc = "Membuka panel setup: isi API Key & link video, simpan config, mulai/stop" },
            { cmd = "/ytoverlay", desc = "Alias untuk toggle overlay chat (sama dengan /ytchat)" },
            { cmd = "/ytlogfolder", desc = "Membuka folder log chat harian di Windows Explorer (config/ytchat/logs/)" },
            { cmd = "/ytclearcfg", desc = "Menghapus file config dan mereset API Key yang tersimpan" },
        }
    },
    {
        category = "TikTok Live Chat",
        color = mimgui.ImVec4(0.2, 0.9, 1.0, 1.0), -- Cyan TikTok
        commands = {
            { cmd = "/ttchat", desc = "Membuka/menutup overlay TikTok Live Chat di layar game" },
            { cmd = "/ttchatpanel", desc = "Membuka panel setup: isi Username TikTok, hubungkan/putuskan bridge Python" },
            { cmd = "/ttoverlay", desc = "Alias untuk toggle overlay (sama dengan /ttchat)" },
            { cmd = "/ttlogfolder", desc = "Membuka folder konfigurasi TikTok Chat (config/ttchat/) di Explorer" },
            { cmd = "/ttclearcfg", desc = "Menghapus config TikTok dan mereset username yang tersimpan" },
        }
    },
    {
        category = "Stream Chat Overlay",
        color = mimgui.ImVec4(0.8, 0.2, 1.0, 1.0), -- Ungu
        commands = {
            { cmd = "/streamchat", desc = "Membuka/menutup overlay chat stream (tampilan custom di layar)" },
        }
    },

    -- ── AUDIO & VOICE ─────────────────────────────────────────
    {
        category = "Voice Smart Fix",
        color = mimgui.ImVec4(0.8, 0.4, 1.0, 1.0), -- Ungu muda
        commands = {
            { cmd = "/rvoice", desc = "Refresh koneksi voice chat SAMP jika suara terputus atau bug" },
        }
    },

    -- ── KONEKSI & STABILITAS ──────────────────────────────────
    {
        category = "Auto Reconnect",
        color = mimgui.ImVec4(1.0, 0.55, 0.2, 1.0), -- Oranye
        commands = {
            { cmd = "/rc [nama]", desc = "Reconnect ke server dengan nickname baru (default: Yohnzz)" },
            { cmd = "Otomatis", desc = "Secara otomatis mencoba terhubung kembali jika kick/disconnect dengan nama akun aktif" },
        }
    },
    {
        category = "Auto Reboot",
        color = mimgui.ImVec4(1.0, 0.4, 0.2, 1.0), -- Merah-Oranye
        commands = {
            { cmd = "Otomatis", desc = "Auto reconnect / reboot jika koneksi ke server terputus tidak terduga" },
        }
    },

    -- ── GAMEPLAY TAMBAHAN ─────────────────────────────────────
    {
        category = "Nametags",
        color = mimgui.ImVec4(0.4, 1.0, 0.4, 1.0), -- Hijau terang
        commands = {
            { cmd = "/nametags", desc = "Membuka menu konfigurasi nametag player (warna, jarak, dsb)" },
        }
    },
    {
        category = "Auto Otot (Gym AFK)",
        color = mimgui.ImVec4(0.9, 0.3, 0.5, 1.0), -- Pink-Merah
        commands = {
            { cmd = "Otomatis", desc = "Melakukan gym / latihan otot secara otomatis di area gym sambil AFK" },
        }
    },
    {
        category = "Kill Streak Blade",
        color = mimgui.ImVec4(1.0, 0.3, 0.6, 1.0), -- Hot Pink
        commands = {
            { cmd = "Otomatis", desc = "Menampilkan notifikasi kill streak saat berhasil membunuh pemain lain" },
        }
    },
    {
        category = "DMG Infinity (disabled_scripts)",
        color = mimgui.ImVec4(1.0, 0.2, 0.2, 1.0), -- Merah terang
        commands = {
            { cmd = "/dmginf", desc = "Membuka panel pengaturan DMG Infinity (cheat damage modifikasi)" },
        }
    },
}

-- ============================================================
-- STYLE MIMGUI
-- ============================================================
mimgui.OnInitialize(function()
    theme.applyDarkModern()
end)

-- ============================================================
-- GUI FRAME
-- ============================================================
mimgui.OnFrame(function() return showMenu[0] end, function()
    local screenResX, screenResY = getScreenResolution()
    mimgui.SetNextWindowPos(mimgui.ImVec2(screenResX / 2, screenResY / 2), mimgui.Cond.FirstUseEver, mimgui.ImVec2(0.5, 0.5))
    mimgui.SetNextWindowSize(mimgui.ImVec2(640, 580), mimgui.Cond.FirstUseEver)

    mimgui.Begin("SAMP Command & Script List", showMenu, mimgui.WindowFlags.NoCollapse)
    mimgui.TextDisabled("Author: Yohanez")

    mimgui.TextColored(colorTitle, "Daftar lengkap command & script yang aktif di Moonloader kamu.")
    mimgui.Spacing()

    -- Search bar
    mimgui.Text("Cari Command:")
    mimgui.SameLine()
    mimgui.PushItemWidth(-1)
    mimgui.InputText("##search", searchBuffer, 256)
    mimgui.PopItemWidth()

    mimgui.Separator()
    mimgui.Spacing()

    local searchText = string.lower(ffi.string(searchBuffer))

    -- Scrollable list
    mimgui.BeginChild("ListChild", mimgui.ImVec2(0, -44), true)

    for _, script in ipairs(scriptData) do
        local matchesSearch = false

        if searchText == "" then
            matchesSearch = true
        elseif string.find(string.lower(script.category), searchText, 1, true) then
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

        if matchesSearch then
            mimgui.PushStyleColor(mimgui.Col.Text, script.color)
            mimgui.Text("[ " .. string.upper(script.category) .. " ]")
            mimgui.PopStyleColor()

            for _, cmdInfo in ipairs(script.commands) do
                mimgui.TextColored(colorCommand, "   " .. cmdInfo.cmd)
                mimgui.SameLine()
                mimgui.TextColored(mimgui.ImVec4(0.4, 0.4, 0.5, 0.8), "  -  ")
                mimgui.SameLine()
                mimgui.TextColored(colorDesc, cmdInfo.desc)
            end

            mimgui.Separator()
            mimgui.Spacing()
        end
    end

    mimgui.EndChild()

    -- Tombol tutup
    if mimgui.Button("Tutup", mimgui.ImVec2(-1, 32)) then
        showMenu[0] = false
    end

    mimgui.End()
end)

-- ============================================================
-- MAIN
-- ============================================================
function main()
    repeat wait(0) until isSampAvailable()

    sampRegisterChatCommand("scriptlist", function() showMenu[0] = not showMenu[0] end)
    sampRegisterChatCommand("cmdlist",    function() showMenu[0] = not showMenu[0] end)

    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FFFF}[CMD List] {FFFFFF}Loaded! Ketik {00FFFF}/cmdlist{FFFFFF} untuk melihat daftar command.", -1)
            break
        end
    end

    while true do wait(0) end
end
