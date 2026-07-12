-- Auto RP Medis GUI untuk SAMP Lua (MoonLoader)
require 'lib.sampfuncs'
require 'lib.moonloader'
local mimgui = require 'lib.mimgui'
local encoding = require 'lib.encoding'
encoding.default = 'CP1252'
local ffi = require "ffi"
local sampev = require 'lib.samp.events'

ffi.cdef[[
bool SetCursorPos(int X, int Y);
void mouse_event(unsigned int dwFlags, unsigned int dx, unsigned int dy, unsigned int dwData, unsigned long dwExtraInfo);
void keybd_event(unsigned char bVk, unsigned char bScan, unsigned long dwFlags, unsigned long dwExtraInfo);
]]
local events = require 'lib.events'

-- ===== PROXIMITY DETECTION SYSTEM =====
local proximitySystem = {
    nearbyPlayers = {},
    maxDistance = 15.0,
    updateInterval = 500,
    lastUpdate = 0
}

-- Get nearby players with proximity detection
function proximitySystem:update()
    local currentTime = getGameTimer()
    if currentTime - self.lastUpdate < self.updateInterval then return end
    
    self.lastUpdate = currentTime
    self.nearbyPlayers = {}
    
    if not doesCharExist(PLAYER_PED) then return end
    
    local myPlayer = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not myPlayer or myPlayer == -1 then return end
    
    local myPos = getCharCoordinates(PLAYER_PED)
    if not myPos then return end
    
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) and i ~= myPlayer then
            local ped = sampGetCharHandleBySampPlayerId(i)
            if ped and doesCharExist(ped) then
                local playerPos = getCharCoordinates(ped)
                if playerPos then
                    local distance = math.sqrt(
                        (myPos.x - playerPos.x)^2 + 
                        (myPos.y - playerPos.y)^2 + 
                        (myPos.z - playerPos.z)^2
                    )
                    if distance <= self.maxDistance then
                        table.insert(self.nearbyPlayers, {
                            id = i,
                            name = sampGetPlayerNickname(i),
                            distance = distance,
                            x = playerPos.x,
                            y = playerPos.y,
                            z = playerPos.z
                        })
                    end
                end
            end
        end
    end
    
    table.sort(self.nearbyPlayers, function(a, b) return a.distance < b.distance end)
end

function proximitySystem:getNearest()
    self:update()
    if #self.nearbyPlayers > 0 then
        return self.nearbyPlayers[1]
    end
    return nil
end

function proximitySystem:getAll()
    self:update()
    return self.nearbyPlayers
end

-- ===== HELPER: GENERATE RANDOM BPJS ID =====
math.randomseed(os.time())
local function generateBPJSID()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = 'BPJS-'
    for i = 1, 10 do
        local idx = math.random(1, #chars)
        result = result .. chars:sub(idx, idx)
    end
    return result
end

-- ===== HELPER: GET CURRENT TIME STRING (WIB / UTC+7) =====
local function getCurrentTimeString()
    -- os.time() returns UTC, add 7 hours for WIB (25200 seconds)
    local t = os.date("*t", os.time() + 25200)
    return string.format("%02d:%02d WIB", t.hour, t.min)
end

-- ===== FORM INPUT BUFFERS =====
local sksPatientID      = mimgui.new.char[64]('')
local bpjsPatientID     = mimgui.new.char[64]('')
local bpjsCustomID      = mimgui.new.char[32]('')
local blacklistID       = mimgui.new.char[64]('')
local blacklistReason   = mimgui.new.char[128]('')
local ckPatientName     = mimgui.new.char[128]('')   -- NEW: nama pasien meninggal

-- ===== QUICK TARGET SYSTEM =====
local targetSystem = {
    nearestPlayer = nil,
    autoSetTarget = true
}

function targetSystem:update()
    self.nearestPlayer = proximitySystem:getNearest()
    if self.autoSetTarget and self.nearestPlayer then
        ffi.copy(sksPatientID, tostring(self.nearestPlayer.id), 64)
        ffi.copy(bpjsPatientID, tostring(self.nearestPlayer.id), 64)
        ffi.copy(blacklistID, tostring(self.nearestPlayer.id), 64)
    end
end

function targetSystem:getTargetInfo()
    if self.nearestPlayer then
        return string.format("%s (ID: %d) - %.2f meter", 
            self.nearestPlayer.name, 
            self.nearestPlayer.id, 
            self.nearestPlayer.distance)
    end
    return "Tidak ada pemain terdekat"
end

-- ===== INVOICE SYSTEM =====
local INVOICE_TYPES = {
    {name = "Revive", code = "REVIVE", price = 6000},
    {name = "Treatment", code = "TREATMENT", price = 5000},
    {name = "Operasi", code = "OP", price = 20000},
    {name = "SKS", code = "SKS", price = 10000},
    {name = "BPJS", code = "BPJS", price = 40000},
    {name = "Farmasi - Paket A", code = "FARMASI_A", price = 6000},
    {name = "Farmasi - Paket B", code = "FARMASI_B", price = 15000},
    {name = "Farmasi - Paket C", code = "FARMASI_C", price = 45000},
}

local invoiceState = {
    selectedTargetId = nil,
    selectedTargetName = nil,
    selectedInvoiceType = nil,
    queue = {}
}

local function sendInvoiceCommand(command, delay)
    table.insert(invoiceState.queue, {
        cmd = command,
        time = getGameTimer() + (delay or 1000)
    })
end

local function processInvoiceQueue()
    if #invoiceState.queue == 0 then return end
    
    local currentTime = getGameTimer()
    for i = #invoiceState.queue, 1, -1 do
        if currentTime >= invoiceState.queue[i].time then
            sampSendChat(invoiceState.queue[i].cmd)
            table.remove(invoiceState.queue, i)
        end
    end
end

local function executeInvoiceWithType(targetId, targetName, invoiceType)
    if not invoiceType then
        sampAddChatMessage("{FF0000}[AutoRP] Pilih tipe invoice terlebih dahulu!", -1)
        return
    end
    
    local RP_TIMING = {
        PROP_TABLET = 1000,
        TAKE_TABLET = 2500,
        POWER_ON = 4000,
        TYPING = 5500,
        SHOW_FORM = 7000,
        APPROACH_PATIENT = 8500,
        EXPLAIN_INVOICE = 10000,
        INVOICE_DETAILS = 11500,
        POWER_OFF = 13000,
        CLOSE_PROP = 14500
    }
    
    local invoiceName = string.format("%s %s", invoiceType.code, targetName:upper())
    
    sampAddChatMessage(string.format("{00FF00}[AutoRP] Mulai invoice: %s | Harga: Rp %d", invoiceName, invoiceType.price), -1)
    
    -- Tablet prop sequence
    sendInvoiceCommand("/eprop tablet", RP_TIMING.PROP_TABLET)
    sendInvoiceCommand("/me mengambil tablet dari tas tactical", RP_TIMING.TAKE_TABLET)
    sendInvoiceCommand("/me menyalakan layar tablet", RP_TIMING.POWER_ON)
    sendInvoiceCommand("/me mengetik data invoice di layar tablet", RP_TIMING.TYPING)
    
    -- Show invoice details
    sendInvoiceCommand("/do Layar tablet menampilkan: " .. invoiceName, RP_TIMING.SHOW_FORM)
    sendInvoiceCommand("/me menghampiri pasien sambil menunjukkan tablet", RP_TIMING.APPROACH_PATIENT)
    sendInvoiceCommand("/me Berikut invoice untuk " .. invoiceType.name:lower() .. " sebesar Rp " .. invoiceType.price, RP_TIMING.EXPLAIN_INVOICE)
    sendInvoiceCommand("/do Invoice atas nama: " .. invoiceName, RP_TIMING.INVOICE_DETAILS)
    
    -- Cleanup
    sendInvoiceCommand("/me mematikan layar tablet dan menyimpannya", RP_TIMING.POWER_OFF)
    sendInvoiceCommand("/e x", RP_TIMING.CLOSE_PROP)
    
    sampAddChatMessage("{00FF00}[AutoRP] Invoice sequence selesai!", -1)
end
local rpCategories = {
    {
        name = 'Pengumuman',
        description = 'Kategori untuk pengumuman terkait status layanan rumah sakit.',
        rps = {
            {
                name = 'Buka Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di rumah sakit telah dibuka.',
                cmds = {
                    '/fa [MIC: ON]',
                    '/fa PELAYANAN RUMAH SAKIT TELAH DIBUKA',
                    '/fa BAGI YANG INGIN BEROBAT/MENGURUS ADMINISTRASI PELAYANAN SILAHKAN DATANG KE RUMAH SAKIT',
                    '/fa TERIMAKASIH',
                    '/fa [MIC: OFF]'
                }
            },
            {
                name = 'Tutup Pelayanan',
                desc = 'Memberikan pengumuman bahwa pelayanan di rumah sakit telah ditutup.',
                cmds = {
                    '/fa [MIC: ON]',
                    '/fa PELAYANAN RUMAH SAKIT TELAH DITUTUP DIKARENAKAN JAM OPERASIONAL',
                    '/fa DIHIMBAU KEPADA SELURUHNYA UNTUK MENJAGA KESEHATAN. TERIMAKASIH',
                    '/fa [MIC: OFF]'
                }
            },
            {
                name = 'Darurat',
                desc = 'Memberikan informasi adanya panggilan darurat.',
                cmds = {
                    '/fa [MIC: ON]',
                    '/fa BAGI YANG MENEMUKAN WARGA PINGSAN DIMOHON UNTUK MEMBAWANYA KE RS',
                    '/fa DIKARENAKAN MEDIS SEDANG KEKURANGAN ANGGOTA',
                    '/fa TERIMAKASIH',
                    '/fa [MIC: OFF]'
                }
            }
        }
    },
    {
        name = 'Pelayanan',
        description = 'Kategori untuk pelayanan medis dasar.',
        rps = {
            {
                name = 'Treatment (Suntik Vit)',
                desc = 'RP singkat untuk memberikan suntikan vitamin.',
                cmds = {
                    '/e geledah',
                    '/me mengambil suntikan vitamin dari kotak P3K',
                    '/do suntikan terambil',
                    '/me menyuntikkan vitamin ke pasien di depannya',
                    '/do proses penyuntikan',
                    '/do pasien berhasil tersuntik vitamin',
                    '/e x'
                }
            }
        }
    },
    {
        name = 'Kerja Lapangan',
        description = 'Kategori untuk kerja lapangan medis.',
        rps = {
            {
                name = 'RP Cek Kesehatan',
                desc = 'Cek Kesehatan Korban',
                cmds = {
                    '/e geledah',
                    '/me mengambil alat alat medis dari kotak P3K',
                    '/do terambil',
                    '/me mengecek kesehatan pasien di depannya menggunakan alat medis',
                    '/do proses pengecekan',
                    '/do 3/3',
                    '/me menyimpulkan kondisi pasien',
                    '/e x',
                }
            },
            {
                name = 'RP Revive Pasien',
                desc = 'Memberikan pertolongan pertama pada korban.',
                cmds = {
                    '/me menaruh medkit di sebelah korban',
                    '/do tertaruh',
                    '/me memberikan pertolongan pertama pada korban di depannya secara perlahan',
                    '/do proses',
                    '/do pasien tersadarkan?',
                    '/e x'
                }
            },
            {
                name = 'Hasil Cek Normal',
                desc = 'Kondisi pasien normal.',
                cmds = {
                    '/me Pengecekan Lancar, Kondisi Pasien Normal',
                    '/do selesai'
                }
            },
            {
                name = 'Hasil Cek Oprasi',
                desc = 'Kondisi pasien butuh operasi segera.',
                cmds = {
                    '/me Pengecekan Lancar, Kondisi Pasien Harus Oprasi Segera',
                    '/do selesai'
                }
            }
        }
    },
    {
        name = 'Administrasi',
        description = 'Kategori untuk layanan administrasi medis.',
        rps = {
            {
                name = 'RP SKS',
                desc = 'RP lengkap untuk pemeriksaan Surat Keterangan Sehat (SKS).',
                actions = {
                    {
                        name = 'Tes',
                        desc = 'Pemeriksaan fisik untuk SKS.',
                        cmds = {
                            '/e geledah',
                            '/me mengambil stetoskop dan alat tensi dari kotak P3K',
                            '/do terambil',
                            '/me memasangakan alat tensi ke lengan pasien',
                            '/do proses',
                            '/do terpasang',
                            '/me menyelipkan stetoskop ke alat tensi',
                            '/do terselipkan',
                            '/me nemompa alat tensi',
                            '/do proses',
                            '/do TENSI 120/80',
                            '/me memeriksa kondisi pasien',
                            '/do NORMAL',
                            '/e x',
                        }
                    },
                    {
                        name = 'Cetak',
                        desc = 'Mencetak dokumen SKS.',
                        cmds = {
                            '/e geledah',
                            '/me menyalakan komputer dan printer',
                            '/do menyala',
                            '/me memasukkan data pasien',
                            '/me data berhasil di masukan',
                            '/me mencetak data SKS',
                            '/do SKS BERHASIL TERCETAK',
                            '/e x'
                        }
                    },
                    {
                        name = 'Mencatat',
                        desc = 'Proses awal sebelum Cetak dan periksa.',
                        cmds = {
                            '/eprop buku',
                            '/me menuliskan data pasien ke dalam buku administrasi',
                            '/do tertulis',
                            '/me menuliskan tujuan pasien membuat SKS',
                            '/me tertulis',
                            '/me menandatangani buku administrasi',
                            '/do tertanda tangan',
                            '/e x'
                        }
                    }
                }
            },
            {
                name = 'RP BPJS',
                desc = 'RP pengurusan data dan pencetakan BPJS.',
                cmds = {
                    '/me menyalakan komputer dan printer',
                    '/do menyala',
                    '/me Memasukkan data orang di depannya',
                    '/me data berhasil di masukan',
                    '/me mencetak data BPJS',
                    '/do BPJS BERHASIL TERCETAK'
                }
            }
        }
    },
    {
        name = 'Operasi',
        description = 'Kategori untuk tindakan operasi medis.',
        rps = {
            {
                name = 'RP Operasi Luka Tembak',
                desc = 'Penanganan medis untuk pasien dengan luka tembak.',
                cmds = {
                    '/e geledah',
                    '/me membuka pakaian pasien di area luka tembak',
                    '/me menaruh barang pribadi pasien di meja medis',
                    '/do barang pasien tersimpan dengan aman',
                    '/me menyiapkan peralatan operasi dan obat luka tembak',
                    '/do peralatan medis siap digunakan',
                    '/me mengambil suntikan anestesi',
                    '/do anestesi terambil',
                    '/me menyuntikkan anestesi ke area sekitar luka',
                    '/do anestesi mulai bekerja',
                    '/do pasien dalam kondisi terbius',
                    '/me mengambil cairan pembersih luka tembak',
                    '/do cairan terambil',
                    '/me membersihkan luka tembak secara perlahan',
                    '/do proses pembersihan luka',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do luka tembak terlihat lebih bersih',
                    '/me memeriksa posisi peluru di dalam tubuh pasien',
                    '/do proses identifikasi proyektil',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do posisi peluru berhasil ditemukan',
                    '/me mengeluarkan peluru dari tubuh pasien dengan alat medis',
                    '/do proses pengangkatan peluru',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do peluru berhasil dikeluarkan',
                    '/me membersihkan kembali area bekas peluru',
                    '/do area luka kembali steril',
                    '/me memasang infus di tangan pasien',
                    '/do infus terpasang dengan baik',
                    '/do cairan infus mengalir',
                    '/me memantau tekanan darah dan denyut nadi pasien',
                    '/do tanda vital pasien masih lemah',
                    '/me memberikan obat penstabil kondisi pasien',
                    '/do obat bekerja di dalam tubuh pasien',
                    '/me membersihkan dan menutup area tindakan',
                    '/do area tindakan bersih dan aman',
                    '/me melepas sarung tangan medis',
                    '/do sarung tangan medis dibuang',
                    '/me memindahkan pasien ke ruang pemulihan',
                    '/do pasien dalam kondisi stabil dan dalam observasi',
                    '/e x'
                }
            },
            {
                name = 'RP Patah Tulang',
                desc = 'RP lengkap untuk operasi patah tulang.',
                cmds = {
                    '/e geledah',
                    '/me mengambil dan memakai sarung tangan medis',
                    '/do sarung tangan terpakai',
                    '/me menyiapkan peralatan operasi di meja',
                    '/do peralatan siap',
                    '/me memeriksa seluruh tubuh pasien',
                    '/me membersihkan area patah tulang pasien',
                    '/do proses pembersihan',
                    '/do area patah tulang pasien berhasil dibersihkan',
                    '/me mengambil dan mengoleskan alkohol ke luka pasien',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do alkohol berhasil dioleskan',
                    '/me mengambil suntikan anestesi dan menyuntikkan ke pasien',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do pasien terbius',
                    '/me mengambil pisau bedah dan menyayat area luka patah tulang',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do luka patah tulang berhasil tersayat',
                    '/me mengreduksi area patah tulang',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do berhasil tereduksi',
                    '/me mengambil dan memasang pen menggunakan kedua tangan',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do pen terpasang di tubuh pasien',
                    '/me mengambil suture dan jarum medis di meja',
                    '/do terambil',
                    '/me menjahit luka sayatan di tubuh pasien',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do berhasil menjahit luka sayatan',
                    '/me mengambil perban dan membalutkan ke luka pasien menggunakan kedua tangan',
                    '/do proses 1/3', '/do proses 2/3', '/do proses 3/3',
                    '/do luka patah tulang berhasil terbalutkan',
                    '/me melepas sarung tangan medis dan membuangnya',
                    '/do terbuang',
                    '/e x'
                }
            },
            {
                name = 'RP Sunat',
                desc = 'RP prosedur sunat lengkap.',
                cmds = {
                    '/e geledah',
                    '/me mengambil dan memakai sarung tangan medis',
                    '/do sarung tangan terpakai',
                    '/me mempersiapkan peralatan sunat',
                    '/Do tersiapkan',
                    '/Me memulai proses sunat',
                    '/Me mengambil cairan alkohol', '/Do terambil',
                    '/Me mulai membersihkan area venis pasien menggunakan cairan alkohol',
                    '/Do proses', '/Do 1/2', '/Do 2/2', '/Do selesai',
                    '/Me mengambil suntikan pereda nyeri', '/Do terambil',
                    '/Me mulai menyuntikkan suntikan di area venis pasien',
                    '/Do proses', '/Do 1/3', '/Do 2/3', '/Do 3/3', '/Do selesai',
                    '/Me mengambil gunting', '/Do terambil',
                    '/Me mulai menggunting kulit atas venis pasien',
                    '/Do proses', '/Do 1/2', '/Do 2/2', '/Do selesai',
                    '/Me mengambil benang dan jarum', '/Do terambil',
                    '/Me mulai menjahit area venis pasien yang telah di gunting',
                    '/Do proses', '/Do 1/2', '/Do 2/2', '/Do selesai',
                    '/Me mengambil alkohol dan membersihkan area venis pasien',
                    '/Do proses', '/Do 1/2', '/Do 2/2', '/Do selesai',
                    '/Me memberikan cairan revanol di bagian atas venis pasien', '/Do selesai',
                    '/Me mengambil perban dan kain kasa', '/Do terambil',
                    '/Me mulai membalut dan menutup area venis pasien',
                    '/Do proses', '/Do 1/2', '/Do 2/2', '/Do proses sunat selesai',
                    '/me melepas sarung tangan medis dan membuangnya', '/do terbuang',
                    '/e x'
                }
            },
            {
                name = 'Cuci Tangan',
                desc = 'Mencuci tangan sebelum melakukan tindakan medis.',
                cmds = {
                    '/e geledah',
                    '/me mencuci kedua tangan menggunakan sabun dan air mengalir',
                    '/do tangan bersih higienis',
                    '/me mengeringkan kedua tangan menggunakan handuk bersih',
                    '/do tangan kering',
                    '/do memakai sarung tangan medis',
                    '/do sarung tangan terpakai',
                    '/e x'
                }
            },
            {
                name = 'RP Cepat',
                desc = 'Operasi cepat ringkas.',
                cmds = {
                    '/e geledah',
                    '/me Melakukan Operasi Pada Pasien',
                    '/me Memberikan Obat Anestesi pada Tubuh pasien',
                    '/me Proses Operasi',
                    '/do 1/10', '/do 2/10', '/do 3/10', '/do 4/10', '/do 5/10',
                    '/do 6/10', '/do 7/10', '/do 8/10', '/do 9/10', '/do 10/10',
                    '/do Operasi Selesai',
                    '/me Operasi Telah berhasil dan berjalan Lancar',
                    '/e x'
                }
            },
            {
                name = 'RP Operasi Lambung Kompleks',
                desc = 'Melakukan prosedur operasi lambung secara lengkap dan profesional.',
                cmds = {
                    '/e geledah',
                    '/me Memeriksa kondisi vital pasien sebelum operasi',
                    '/me Memberikan anestesi umum kepada pasien',
                    '/do Pasien mulai kehilangan kesadaran',
                    '/me Mensterilkan area perut pasien dengan cairan antiseptik',
                    '/me Menyiapkan alat bedah operasi lambung',
                    '/me Membuat sayatan awal pada area perut pasien',
                    '/do 1/15', '/do 2/15', '/do 3/15',
                    '/me Membuka lapisan jaringan menuju organ lambung',
                    '/do 4/15', '/do 5/15',
                    '/me Mengidentifikasi bagian lambung yang bermasalah',
                    '/do Ditemukan gangguan pada lambung pasien',
                    '/do 6/15', '/do 7/15',
                    '/me Melakukan tindakan medis pada lambung pasien',
                    '/do 8/15', '/do 9/15', '/do 10/15',
                    '/me Menghentikan perdarahan dan memastikan kondisi lambung aman',
                    '/do 11/15',
                    '/me Menjahit kembali jaringan lambung yang telah ditangani',
                    '/do 12/15',
                    '/me Menutup lapisan perut pasien secara bertahap',
                    '/do 13/15', '/do 14/15',
                    '/me Menjahit kulit luar dan membersihkan area operasi',
                    '/do 15/15',
                    '/do Operasi lambung telah selesai',
                    '/me Operasi berjalan dengan lancar tanpa komplikasi',
                    '/e x'
                }
            },
            {
                name = 'RP Koma',
                desc = 'RP operasi darurat, pasien mengalami komplikasi dan harus masuk kondisi koma.',
                cmds = {
                    '/e geledah',
                    '/me mempersiapkan peralatan operasi', '/do peralatan tersiapkan',
                    '/me memindahkan pasien ke meja operasi', '/do pasien terbaring di meja operasi',
                    '/me memulai prosedur operasi dengan hati-hati', '/do operasi berlangsung',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/me melihat kondisi pasien tiba-tiba melemah',
                    '/do monitor jantung berbunyi tidak stabil',
                    '/me menyadari adanya komplikasi serius', '/do terjadi pendarahan hebat',
                    '/me berusaha menghentikan pendarahan dan menstabilkan pasien',
                    '/do tim medis membantu dengan cepat', '/do kondisi pasien semakin kritis',
                    '/me meminta alat bantu pernapasan', '/do alat terpasang',
                    '/me melakukan tindakan penyelamatan darurat',
                    '/do proses penanganan berlangsung', '/do 1/2', '/do 2/2',
                    '/me melihat tekanan darah pasien menurun drastis', '/do kondisi sangat kritis',
                    '/me memutuskan untuk membawa pasien ke ruang ICU',
                    '/do pasien dipindahkan dengan cepat',
                    '/me memasang alat bantu pernapasan lanjutan',
                    '/do pasien dalam kondisi tidak sadar',
                    '/me menyatakan pasien dalam kondisi koma untuk pemulihan lebih lanjut',
                    '/do pasien dinyatakan koma dan dalam pengawasan ketat',
                    '/me melepas sarung tangan dan membuangnya ke tempat medis',
                    '/do terbuang', '/e x'
                }
            },
            {
                name = 'Dokumentasi Operasi',
                desc = 'Melaporkan operasi korban ke website.',
                cmds = {
                    '/me menyiapkan perangkat dokumentasi medis',
                    '/do proses pengumpulan data kesehatan korban',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do data identitas dan kondisi korban terkumpul',
                    '/me mencatat hasil pemeriksaan dan tindakan operasi',
                    '/do proses pendokumentasian medis',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do catatan medis tersimpan dengan baik',
                    '/me memasukkan laporan operasi ke website rumah sakit',
                    '/do proses input data laporan operasi',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do laporan operasi berhasil diunggah',
                    '/me memverifikasi kondisi korban pasca operasi',
                    '/do proses validasi data kesehatan',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do data kesehatan telah tervalidasi',
                    '/me menyelesaikan laporan medis korban',
                    '/do dokumentasi operasi resmi tersimpan di sistem'
                }
            },
            {
                name = 'Operasi Luka Tusuk',
                desc = 'Melakukan operasi dan dokumentasi medis korban luka tusuk.',
                cmds = {
                    '/e geledah',
                    '/me membawa pasien ke ruang pemeriksaan dan menyiapkan area tindakan',
                    '/do area pemeriksaan siap digunakan',
                    '/me memakai sarung tangan medis dan mengambil peralatan bedah',
                    '/do terpakai dan terambil',
                    '/me membersihkan area luka tusuk menggunakan antiseptik',
                    '/do proses pembersihan luka', '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do area luka bersih dari darah',
                    '/me memeriksa kedalaman dan arah luka tusuk',
                    '/do luka tusuk sedalam kurang lebih 3 cm',
                    '/me mengambil suntikan anestesi lokal', '/do terambil',
                    '/me menyuntikkan anestesi di sekitar area luka',
                    '/do proses penyuntikan anestesi', '/do 1/2', '/do 2/2',
                    '/do area sekitar mati rasa',
                    '/me mengambil pinset dan kasa steril', '/do terambil',
                    '/me membersihkan sisa darah dan jaringan kotor dari dalam luka',
                    '/do proses pembersihan luka', '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do luka terlihat lebih jelas',
                    '/me mengambil needle dan benang jahit', '/do terambil',
                    '/me mulai menjahit luka tusuk secara perlahan',
                    '/do proses menjahit luka', '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do luka berhasil terjahit',
                    '/me mengoleskan salep antibiotik pada area jahitan', '/do teroles merata',
                    '/me menutup luka dengan kasa steril dan perban', '/do luka tertutup rapi',
                    '/me memeriksa kembali kondisi pasien setelah operasi', '/do kondisi pasien stabil',
                    '/me mencatat hasil tindakan medis pada laporan rumah sakit',
                    '/do proses dokumentasi medis', '/do 1/3', '/do 2/3', '/do 3/3',
                    '/do laporan operasi tersimpan di sistem',
                    '/e x'
                }
            },
        }
    },
    {
        name = 'Lainnya',
        description = 'Kategori untuk RP medis lainnya.',
        rps = {
            {
                name = 'RP CUCI TANGAN',
                desc = 'RP Langkah pertama untuk penanganan (semua operasi).',
                cmds = {
                    '/e geledah',
                    '/me mencuci kedua tangan menggunakan air bersih',
                    '/do tangan bersih higienis',
                    '/e x'
                }
            },
            {
                name = 'RP Invoice',
                desc = 'RP pengeluaran invoice.',
                cmds = {
                    '/eprop tablet',
                    '/me memasukkan jumlah nominal invoice',
                    '/me memberikan invoice ke orang di depannya',
                    '/do sudah diterima?',
                    '/e x'
                }
            },
            -- ===== NEW: RP CK / MENINGGAL =====
            {
                name = 'RP CK (Meninggal)',
                desc = 'RP prosedur pemeriksaan korban meninggal (Cek Kematian).',
                cmds = {
                    '/e geledah',
                    '/me mendekati korban dan memeriksa kondisi tubuhnya secara perlahan',
                    '/do proses pemeriksaan',
                    '/do 1/3', '/do 2/3', '/do 3/3',
                    '/me memeriksa denyut nadi dan pernapasan korban',
                    '/do tidak terdeteksi denyut nadi',
                    '/me memeriksa kondisi pupil mata korban',
                    '/do pupil melebar tidak responsif',
                    '/me memeriksa suhu tubuh korban',
                    '/do suhu tubuh menurun drastis',
                    '/me menyatakan korban telah meninggal dunia',
                    '/do korban dinyatakan meninggal',
                    '/me menutup tubuh korban dengan kain steril',
                    '/do korban tertutupi',
                    '/me melepas sarung tangan medis dan membuangnya',
                    '/do terbuang',
                    '/e x'
                }
            }
        }
    },
    -- ===== KATEGORI TOOLS ADMIN =====
    {
        name = 'Tools Admin',
        description = 'Form langsung untuk /makesks, /makebpjs, /blacklist, dan Berita Kematian.',
        isToolsAdmin = true,
        rps = {}
    },
    -- ===== KATEGORI INVOICE =====
    {
        name = 'Invoice',
        description = 'Sistem invoice otomatis dengan berbagai tipe layanan.',
        isInvoiceMenu = true,
        rps = {}
    }
}

-- ===== FIND HELPERS =====
function findRpCommands(rpNameToFind)
    for _, category in ipairs(rpCategories) do
        for _, rp in ipairs(category.rps) do
            if rp.name == rpNameToFind then
                if rp.actions then
                    local allCmds = {}
                    for _, action in ipairs(rp.actions) do
                        for _, cmd in ipairs(action.cmds) do
                            table.insert(allCmds, cmd)
                        end
                    end
                    return allCmds
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

-- ===== EXECUTE COMMANDS =====
function executeCommands(commands)
    if not commands then return end
    lua_thread.create(function()
        for _, cmd in ipairs(commands) do
            sampSendChat(cmd)
            wait(math.random(2000, 2500))
        end
    end)
end

-- ===== NEW: EXECUTE DEATH ANNOUNCEMENT =====
-- Builds /fa commands dynamically with the patient name and current time
function executeDeathAnnouncement(patientName)
    if not patientName or patientName == '' then
        sampAddChatMessage("{FF0000}[AutoRP] Nama pasien tidak boleh kosong!", -1)
        return
    end
    local timeStr = getCurrentTimeString()
    local cmds = {
        '/fa MIC : ON',
        '/fa BERITA KEMATIAN : TELAH MENINGGAL ATAS NAMA ' .. patientName:upper() .. ' SUDAH DINYATAKAN MENINGGAL PADA JAM ' .. timeStr,
        '/fa DIHARAPKAN UNTUK PIHAK KELUARGA UNTUK DATANG KE RS UNTUK MENGURUS SURAT KEMATIAN KORBAN',
        '/fa TERIMA KASIH',
        '/fa MIC : OFF'
    }
    executeCommands(cmds)
    sampAddChatMessage(("{FF4444}[AutoRP] Berita Kematian dikirim untuk: %s | Waktu: %s"):format(patientName, timeStr), -1)
end

-- ===== SERVER MESSAGE EVENTS =====
events.onServerMessage = function(color, text)
    if text:lower():find("revive") or text:lower():find("treatment") then
        print(string.format("Server message detected: %s", text))
        sampAddChatMessage(("{55FF55}[SERVER DEBUG] Pesan terkait EMS: %s"):format(text), -1)
    end
    local cleanText = text:gsub("{%x%x%x%x%x%x}", "")
    if cleanText:lower():find("action: memberikan pelayanan treatment") then
        executeCommands(findRpCommands('Treatment (Suntik Vit)'))
    elseif cleanText:lower():find("action: menyadarkan korban dengan medkit") then
        executeCommands(findRpCommands('RP Revive Pasien'))
    end
end

-- ===== STYLE =====
function applyStyle()
    local style = mimgui.GetStyle()
    style.WindowPadding     = mimgui.ImVec2(15, 15)
    style.WindowRounding    = 5.0
    style.FramePadding      = mimgui.ImVec2(5, 5)
    style.FrameRounding     = 4.0
    style.ItemSpacing       = mimgui.ImVec2(12, 8)
    style.ItemInnerSpacing  = mimgui.ImVec2(8, 6)
    style.IndentSpacing     = 25.0
    style.ScrollbarSize     = 15.0
    style.ScrollbarRounding = 9.0
    style.GrabMinSize       = 5.0
    style.GrabRounding      = 3.0

    local c = style.Colors
    c[mimgui.Col.Text]                 = mimgui.ImVec4(0.95, 0.95, 0.97, 1.00)
    c[mimgui.Col.TextDisabled]         = mimgui.ImVec4(0.55, 0.55, 0.60, 1.00)
    c[mimgui.Col.WindowBg]             = mimgui.ImVec4(0.07, 0.08, 0.10, 1.00)
    c[mimgui.Col.ChildBg]              = mimgui.ImVec4(0.09, 0.10, 0.13, 1.00)
    c[mimgui.Col.PopupBg]              = mimgui.ImVec4(0.09, 0.10, 0.13, 1.00)
    c[mimgui.Col.Border]               = mimgui.ImVec4(0.85, 0.20, 0.20, 0.85)
    c[mimgui.Col.BorderShadow]         = mimgui.ImVec4(0, 0, 0, 0)
    c[mimgui.Col.FrameBg]              = mimgui.ImVec4(0.12, 0.14, 0.18, 1.00)
    c[mimgui.Col.FrameBgHovered]       = mimgui.ImVec4(0.85, 0.20, 0.20, 0.35)
    c[mimgui.Col.FrameBgActive]        = mimgui.ImVec4(0.85, 0.20, 0.20, 0.60)
    c[mimgui.Col.TitleBg]              = mimgui.ImVec4(0.10, 0.12, 0.16, 1.00)
    c[mimgui.Col.TitleBgActive]        = mimgui.ImVec4(0.85, 0.20, 0.20, 0.40)
    c[mimgui.Col.TitleBgCollapsed]     = mimgui.ImVec4(0.85, 0.20, 0.20, 0.25)
    c[mimgui.Col.MenuBarBg]            = mimgui.ImVec4(0.10, 0.12, 0.16, 1.00)
    c[mimgui.Col.ScrollbarBg]          = mimgui.ImVec4(0.10, 0.12, 0.16, 1.00)
    c[mimgui.Col.ScrollbarGrab]        = mimgui.ImVec4(0.80, 0.25, 0.25, 0.45)
    c[mimgui.Col.ScrollbarGrabHovered] = mimgui.ImVec4(0.90, 0.30, 0.30, 0.75)
    c[mimgui.Col.ScrollbarGrabActive]  = mimgui.ImVec4(0.95, 0.35, 0.35, 1.00)
    c[mimgui.Col.CheckMark]            = mimgui.ImVec4(0.90, 0.25, 0.25, 1.00)
    c[mimgui.Col.SliderGrab]           = mimgui.ImVec4(0.90, 0.25, 0.25, 0.70)
    c[mimgui.Col.SliderGrabActive]     = mimgui.ImVec4(0.95, 0.35, 0.35, 1.00)
    c[mimgui.Col.Button]               = mimgui.ImVec4(0.12, 0.14, 0.18, 1.00)
    c[mimgui.Col.ButtonHovered]        = mimgui.ImVec4(0.85, 0.20, 0.20, 0.45)
    c[mimgui.Col.ButtonActive]         = mimgui.ImVec4(0.95, 0.30, 0.30, 0.80)
    c[mimgui.Col.Header]               = mimgui.ImVec4(0.12, 0.14, 0.18, 1.00)
    c[mimgui.Col.HeaderHovered]        = mimgui.ImVec4(0.30, 0.60, 0.85, 0.45)
    c[mimgui.Col.HeaderActive]         = mimgui.ImVec4(0.85, 0.20, 0.20, 0.75)
    c[mimgui.Col.Separator]            = mimgui.ImVec4(0.30, 0.60, 0.85, 0.60)
    c[mimgui.Col.SeparatorHovered]     = mimgui.ImVec4(0.90, 0.25, 0.25, 0.80)
    c[mimgui.Col.SeparatorActive]      = mimgui.ImVec4(0.95, 0.30, 0.30, 1.00)
    c[mimgui.Col.ResizeGrip]           = mimgui.ImVec4(0, 0, 0, 0)
    c[mimgui.Col.ResizeGripHovered]    = mimgui.ImVec4(0.30, 0.60, 0.85, 0.80)
    c[mimgui.Col.ResizeGripActive]     = mimgui.ImVec4(0.90, 0.25, 0.25, 1.00)
    c[mimgui.Col.PlotLines]            = mimgui.ImVec4(0.30, 0.60, 0.85, 0.80)
    c[mimgui.Col.PlotLinesHovered]     = mimgui.ImVec4(0.95, 0.30, 0.30, 1.00)
    c[mimgui.Col.PlotHistogram]        = mimgui.ImVec4(0.30, 0.60, 0.85, 0.80)
    c[mimgui.Col.PlotHistogramHovered] = mimgui.ImVec4(0.95, 0.30, 0.30, 1.00)
    c[mimgui.Col.TextSelectedBg]       = mimgui.ImVec4(0.85, 0.20, 0.20, 0.35)
end

-- ===== MAIN =====
function main()
    local showWindow = mimgui.new.bool(false)
    local selectedCategoryIndex = mimgui.new.int(1)

    while not isSampAvailable() do wait(100) end

    mimgui.OnInitialize(function()
        applyStyle()
        local initID = generateBPJSID()
        ffi.copy(bpjsCustomID, initID, #initID + 1)
    end)

    events.onInitGame = function()
        sampAddChatMessage("{00FF00}[AutoRP Medis] Script berhasil dimuat!", -1)
        sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/md{FFFFFF} untuk membuka menu GUI atau {00FF00}/cmdhelp{FFFFFF} untuk melihat command cepat", -1)
    end

    sampRegisterChatCommand('md', function() showWindow[0] = not showWindow[0] end)

    sampRegisterChatCommand('pbuka',       function() local c = findRpCommands('Buka Pelayanan')         if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Buka Pelayanan", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('ptutup',      function() local c = findRpCommands('Tutup Pelayanan')        if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Tutup Pelayanan", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pdarurat',    function() local c = findRpCommands('Darurat')                if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Darurat", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('ptreatment',  function() local c = findRpCommands('Treatment (Suntik Vit)') if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Treatment", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pcek',        function() local c = findRpCommands('RP Cek Kesehatan')       if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Cek Kesehatan", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('prk',         function() local c = findRpCommands('RP Revive Pasien')       if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Revive", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('psks',        function() local c = findRpCommands('RP SKS')                 if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP SKS", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pcnormal',    function() local c = findRpCommands('Hasil Cek Normal')       if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Hasil Cek Normal", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pcoprasi',    function() local c = findRpCommands('Hasil Cek Oprasi')       if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Hasil Cek Oprasi", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pskstes',     function() local c = findRpCommandsByAction('RP SKS', 'Tes')  if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: SKS Tes", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pskscetak',   function() local c = findRpCommandsByAction('RP SKS', 'Cetak') if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: SKS Cetak", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pbpjs',       function() local c = findRpCommands('RP BPJS')                if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP BPJS", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('popersi',     function() local c = findRpCommands('RP Operasi Luka Tembak') if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP Operasi Luka Tembak", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('ppatah',      function() local c = findRpCommands('RP Patah Tulang')        if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP Patah Tulang", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('psunat',      function() local c = findRpCommands('RP Sunat')               if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP Sunat", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pinvoice',    function() local c = findRpCommands('RP Invoice')             if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP Invoice", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pcucitangan', function() local c = findRpCommands('Cuci Tangan')            if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Cuci Tangan", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pdokoperasi', function() local c = findRpCommands('Dokumentasi Operasi')    if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: Dokumentasi Operasi", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)
    sampRegisterChatCommand('pck',         function() local c = findRpCommands('RP CK (Meninggal)')      if c then sampAddChatMessage("{00FF00}[AutoRP] Menjalankan: RP CK (Meninggal)", -1) executeCommands(c) else sampAddChatMessage("{FF0000}[AutoRP] Tidak ditemukan!", -1) end end)

    sampRegisterChatCommand('cmdhelp', function()
        sampAddChatMessage("{FFFF00}=== [AutoRP Medis] Daftar Command ===", -1)
        sampAddChatMessage("{00FF00}/md{FFFFFF} - Buka/tutup menu GUI", -1)
        sampAddChatMessage("{00FF00}/pbuka /ptutup /pdarurat{FFFFFF} - Pengumuman", -1)
        sampAddChatMessage("{00FF00}/ptreatment /prk /pcek{FFFFFF} - Pelayanan / Lapangan", -1)
        sampAddChatMessage("{00FF00}/pcnormal /pcoprasi{FFFFFF} - Hasil Cek", -1)
        sampAddChatMessage("{00FF00}/psks /pskstes /pskscetak{FFFFFF} - RP SKS", -1)
        sampAddChatMessage("{00FF00}/pbpjs{FFFFFF} - RP BPJS", -1)
        sampAddChatMessage("{00FF00}/popersi /ppatah /psunat{FFFFFF} - Operasi", -1)
        sampAddChatMessage("{00FF00}/pdokoperasi /pinvoice /pcucitangan{FFFFFF} - Lainnya", -1)
        sampAddChatMessage("{00FF00}/pck{FFFFFF} - RP CK (Meninggal)", -1)
        sampAddChatMessage("{00FFFF}/md >> Tools Admin{FFFFFF} - Form SKS, BPJS, Blacklist, Berita Kematian (GUI)", -1)
        sampAddChatMessage("{00FFFF}/md >> Invoice{FFFFFF} - Sistem Invoice otomatis dengan GUI", -1)
        sampAddChatMessage("{00FF00}/cmdhelp{FFFFFF} - Bantuan ini", -1)
    end)

    -- ===== GUI FRAME =====
    mimgui.OnFrame(function() return showWindow[0] end, function()
        targetSystem:update()  -- Update proximity detection
        processInvoiceQueue()  -- Process invoice commands
        
        mimgui.SetNextWindowSize(mimgui.ImVec2(700, 540), mimgui.Cond.FirstUseEver)
        mimgui.Begin('Auto RP Medis', showWindow)

        mimgui.Text('Author: Arkananta Studio')
        
        -- Display nearest player info in red box
        mimgui.PushStyleColor(mimgui.Col.FrameBg, mimgui.ImVec4(0.85, 0.20, 0.20, 0.60))
        mimgui.TextWrapped('Orang Terdekat: ' .. targetSystem:getTargetInfo())
        mimgui.PopStyleColor()
        
        mimgui.Separator()

        -- Left panel
        mimgui.BeginChild('CategoryList', mimgui.ImVec2(200, 0), true)
        mimgui.Text('Kategori:')
        mimgui.Separator()
        for i, category in ipairs(rpCategories) do
            if mimgui.Selectable(category.name, selectedCategoryIndex[0] == i) then
                selectedCategoryIndex[0] = i
            end
        end
        mimgui.EndChild()

        mimgui.SameLine()

        -- Right panel
        mimgui.BeginChild('RightPanel', mimgui.ImVec2(0, 0), false)
        local cat_idx = selectedCategoryIndex[0]
        local selected_category = rpCategories[cat_idx]

        if selected_category then
            mimgui.Text(selected_category.name)
            mimgui.Separator()
            mimgui.TextWrapped('Deskripsi: ' .. selected_category.description)
            mimgui.Separator()

            -- ===================================================
            -- TOOLS ADMIN: form inline, satu window, tanpa popup
            -- ===================================================
            if selected_category.isToolsAdmin then

                -- ---- SKS ----
                mimgui.TextDisabled('-- Buat Surat Keterangan Sehat --')
                mimgui.Text('ID Pasien')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-1)
                mimgui.InputText('##sksid', sksPatientID, 64)
                if mimgui.Button('Kirim /makesks [ID] SEHAT', mimgui.ImVec2(-1, 28)) then
                    local id = ffi.string(sksPatientID)
                    if id ~= '' then
                        sampSendChat('/makesks ' .. id .. ' SEHAT')
                        sampAddChatMessage(("{00FF00}[AutoRP] /makesks %s SEHAT"):format(id), -1)
                    else
                        sampAddChatMessage("{FF0000}[AutoRP] ID Pasien tidak boleh kosong!", -1)
                    end
                end

                mimgui.Spacing()
                mimgui.Separator()
                mimgui.Spacing()

                -- ---- BPJS ----
                mimgui.TextDisabled('-- Buat Kartu BPJS --')
                mimgui.Text('ID Pasien')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-1)
                mimgui.InputText('##bpjspatid', bpjsPatientID, 64)

                mimgui.Text('BPJS ID ')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-70)
                mimgui.InputText('##bpjscid', bpjsCustomID, 32)
                mimgui.SameLine()
                if mimgui.Button('Acak', mimgui.ImVec2(-1, 22)) then
                    local newID = generateBPJSID()
                    ffi.copy(bpjsCustomID, newID, #newID + 1)
                end
                if mimgui.Button('Kirim /makebpjs [ID] [BPJSID] APPROVE', mimgui.ImVec2(-1, 28)) then
                    local id    = ffi.string(bpjsPatientID)
                    local bpjsid = ffi.string(bpjsCustomID)
                    if id ~= '' and bpjsid ~= '' then
                        sampSendChat('/makebpjs ' .. id .. ' ' .. bpjsid .. ' APPROVE')
                        sampAddChatMessage(("{00FF00}[AutoRP] /makebpjs %s %s APPROVE"):format(id, bpjsid), -1)
                        local newID = generateBPJSID()
                        ffi.copy(bpjsCustomID, newID, #newID + 1)
                    else
                        sampAddChatMessage("{FF0000}[AutoRP] ID Pasien dan BPJS ID tidak boleh kosong!", -1)
                    end
                end

                mimgui.Spacing()
                mimgui.Separator()
                mimgui.Spacing()

                -- ---- BLACKLIST ----
                mimgui.TextDisabled('-- Blacklist Pasien --')
                mimgui.Text('ID Target')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-1)
                mimgui.InputText('##blid', blacklistID, 64)

                mimgui.Text('Alasan  ')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-1)
                mimgui.InputText('##blreason', blacklistReason, 128)

                if mimgui.Button('Kirim /blacklist [ID] [Alasan]', mimgui.ImVec2(-1, 28)) then
                    local id     = ffi.string(blacklistID)
                    local reason = ffi.string(blacklistReason)
                    if id ~= '' and reason ~= '' then
                        sampSendChat('/blacklist ' .. id .. ' ' .. reason)
                        sampAddChatMessage(("{FF4444}[AutoRP] /blacklist %s %s"):format(id, reason), -1)
                    else
                        sampAddChatMessage("{FF0000}[AutoRP] ID dan Alasan tidak boleh kosong!", -1)
                    end
                end

                mimgui.Spacing()
                mimgui.Separator()
                mimgui.Spacing()

                -- ===== NEW: BERITA KEMATIAN =====
                mimgui.TextDisabled('-- Berita Kematian (/fa Pengumuman) --')

                -- Tampilkan waktu realtime sebagai preview
                local previewTime = getCurrentTimeString()
                mimgui.TextWrapped('Waktu Sekarang: ' .. previewTime .. '  (otomatis saat dikirim)')

                mimgui.Text('Nama Pasien')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-1)
                mimgui.InputText('##ckname', ckPatientName, 128)

                -- Preview baris /fa
                local previewName = ffi.string(ckPatientName)
                if previewName ~= '' then
                    mimgui.Spacing()
                    mimgui.TextDisabled('Preview:')
                    mimgui.TextWrapped('/fa MIC : ON')
                    mimgui.TextWrapped('/fa BERITA KEMATIAN : TELAH MENINGGAL ATAS NAMA ' .. previewName:upper() .. ' SUDAH DINYATAKAN MENINGGAL PADA JAM ' .. previewTime)
                    mimgui.TextWrapped('/fa DIHARAPKAN UNTUK PIHAK KELUARGA UNTUK DATANG KE RS UNTUK MENGURUS SURAT KEMATIAN KORBAN')
                    mimgui.TextWrapped('/fa TERIMA KASIH')
                    mimgui.TextWrapped('/fa MIC : OFF')
                    mimgui.Spacing()
                end

                if mimgui.Button('Kirim Berita Kematian via /fa', mimgui.ImVec2(-1, 32)) then
                    local nama = ffi.string(ckPatientName)
                    executeDeathAnnouncement(nama)
                    if nama ~= '' then showWindow[0] = false end
                end

            -- ===================================================
            -- INVOICE MENU
            -- ===================================================
            elseif selected_category.isInvoiceMenu then
                mimgui.TextDisabled('-- Pilih Target Pasien --')
                
                -- Show nearby players
                mimgui.PushStyleColor(mimgui.Col.FrameBg, mimgui.ImVec4(0.12, 0.14, 0.18, 1.00))
                mimgui.TextWrapped('Orang Terdekat: ' .. targetSystem:getTargetInfo())
                mimgui.PopStyleColor()
                
                if targetSystem.nearestPlayer then
                    if mimgui.Button('Gunakan Target Terdekat', mimgui.ImVec2(-1, 28)) then
                        invoiceState.selectedTargetId = targetSystem.nearestPlayer.id
                        invoiceState.selectedTargetName = targetSystem.nearestPlayer.name
                    end
                end
                
                mimgui.Separator()
                mimgui.TextDisabled('-- Atau Input ID Manual --')
                
                local manualIdBuffer = mimgui.new.char[64]('')
                mimgui.Text('ID Pasien')
                mimgui.SameLine()
                mimgui.SetNextItemWidth(-1)
                mimgui.InputText('##invoiceid', manualIdBuffer, 64)
                
                if mimgui.Button('Gunakan ID Manual', mimgui.ImVec2(-1, 28)) then
                    local manualId = tonumber(ffi.string(manualIdBuffer))
                    if manualId and sampIsPlayerConnected(manualId) then
                        invoiceState.selectedTargetId = manualId
                        invoiceState.selectedTargetName = sampGetPlayerNickname(manualId)
                    else
                        sampAddChatMessage("{FF0000}[AutoRP] ID tidak valid!", -1)
                    end
                end
                
                if invoiceState.selectedTargetId then
                    mimgui.Spacing()
                    mimgui.Separator()
                    mimgui.Spacing()
                    
                    mimgui.PushStyleColor(mimgui.Col.Text, mimgui.ImVec4(0.00, 1.00, 0.00, 1.00))
                    mimgui.TextWrapped('Target: ' .. invoiceState.selectedTargetName .. ' (ID: ' .. invoiceState.selectedTargetId .. ')')
                    mimgui.PopStyleColor()
                    
                    mimgui.TextDisabled('-- Pilih Tipe Invoice --')
                    mimgui.Separator()
                    
                    for idx, invoiceType in ipairs(INVOICE_TYPES) do
                        local btnText = string.format('%d. %s - Rp %d', idx, invoiceType.name, invoiceType.price)
                        if mimgui.Button(btnText, mimgui.ImVec2(-1, 25)) then
                            executeInvoiceWithType(invoiceState.selectedTargetId, invoiceState.selectedTargetName, invoiceType)
                            showWindow[0] = false
                        end
                    end
                else
                    mimgui.Spacing()
                    mimgui.TextWrapped('Silakan pilih target pasien terlebih dahulu')
                end

            else
                -- ===================================================
                -- RP BIASA
                -- ===================================================
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
            end
        else
            mimgui.Text('Pilih kategori dari panel kiri.')
        end

        mimgui.EndChild()
        mimgui.End()
    end)
end

function isSampAvailable()
    return isSampLoaded() and isSampfuncsLoaded()
end

main()