-- AutoJobKayu.lua
-- Script untuk otomatisasi job kayu di GTA SAMP
-- Fitur: rekam checkpoint, auto berjalan ke checkpoint, auto tekan Y, cooldown 15 detik

script_name("AutoJobKayu")
script_author("YourName")
script_description("Auto walk & interact for wood job")

require "lib.moonloader"
local memory = require "memory"
local json = require "dkjson"

-- Variabel global
local checkpoints = {}           -- tabel posisi {x, y, z}
local checkpointFile = "AutoJobKayu_cp.json"
local recording = false          -- mode rekam aktif?
local autoJobActive = false       -- auto job aktif?
local currentCpIndex = 1          -- checkpoint target saat ini
local cooldownUntil = 0            -- waktu (tick) hingga cooldown selesai
local walking = false             -- sedang berjalan menuju checkpoint?
local walkTarget = nil            -- {x,y,z} tujuan berjalan
local playerPed = nil
local tolerance = 2.0             -- jarak toleransi untuk dianggap sampai (meter)

-- Tombol kontrol (bisa diubah)
local TOGGLE_KEY = 0x78 -- F9 (0x78 = F9) untuk start/stop auto job
local RECORD_KEY = 0x70 -- F1 (0x70 = F1) untuk rekam checkpoint saat mode rekam

-- Fungsi bantuan: load checkpoint dari file
function loadCheckpoints()
    if doesFileExist(checkpointFile) then
        local file = io.open(checkpointFile, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local success, data = pcall(json.decode, content)
            if success and type(data) == "table" then
                checkpoints = data
                sampAddChatMessage("{00FF00}[AutoJob] Loaded " .. #checkpoints .. " checkpoints.", -1)
                return true
            end
        end
    end
    checkpoints = {}
    return false
end

-- Fungsi bantuan: simpan checkpoint ke file
function saveCheckpoints()
    local file = io.open(checkpointFile, "w")
    if file then
-- menggunakan json global (dkjson)
        file:write(json.encode(checkpoints))
        file:close()
        sampAddChatMessage("{00FF00}[AutoJob] Saved " .. #checkpoints .. " checkpoints.", -1)
    else
        sampAddChatMessage("{FF0000}[AutoJob] Failed to save checkpoints!", -1)
    end
end

-- Fungsi: tambah checkpoint dari posisi pemain saat ini
function addCurrentCheckpoint()
    local x, y, z = getCharCoordinates(playerPed)
    table.insert(checkpoints, {x = x, y = y, z = z})
    sampAddChatMessage("{00FF00}[AutoJob] Checkpoint " .. #checkpoints .. " added at (" .. string.format("%.2f", x) .. ", " .. string.format("%.2f", y) .. ")", -1)
end

-- Fungsi: mulai auto job
function startAutoJob()
    if #checkpoints == 0 then
        sampAddChatMessage("{FF0000}[AutoJob] No checkpoints recorded! Use /startrekam then /cp at each location, then /stoprekam.", -1)
        return
    end
    if autoJobActive then
        sampAddChatMessage("{FFFF00}[AutoJob] Already running.", -1)
        return
    end
    autoJobActive = true
    currentCpIndex = 1
    cooldownUntil = 0
    walking = false
    walkTarget = nil
    sampAddChatMessage("{00FF00}[AutoJob] Started. Walking to checkpoint 1...", -1)
    -- Pengecekan posisi terhadap checkpoint 1 akan dilakukan di loop utama
end

-- Fungsi: stop auto job
function stopAutoJob()
    autoJobActive = false
    walking = false
    if walkTarget then
        -- lepas tombol W jika sedang berjalan
        setVirtualKeyDown(0x57, false)
    end
    walkTarget = nil
    sampAddChatMessage("{FFFF00}[AutoJob] Stopped.", -1)
end

-- Fungsi: tekan tombol Y (interaksi)
function pressY()
    lua_thread.create(function()
        setVirtualKeyDown(0x59, true)  -- Y down
        wait(50)
        setVirtualKeyDown(0x59, false) -- Y up
    end)
end

-- Fungsi: mulai berjalan menuju titik tertentu
function startWalkingTo(target)
    if walking then return end
    walking = true
    walkTarget = target
    -- Lepaskan tombol W jika sebelumnya ditekan (buat jaga-jaga)
    setVirtualKeyDown(0x57, false)
    sampAddChatMessage("{FFFFFF}[AutoJob] Walking to checkpoint " .. currentCpIndex .. "...", -1)
end

-- Fungsi: update walking setiap frame
function updateWalking()
    if not walking or not walkTarget then return end
    local px, py, pz = getCharCoordinates(playerPed)
    local tx, ty, tz = walkTarget.x, walkTarget.y, walkTarget.z
    local dx = tx - px
    local dy = ty - py
    local dz = tz - pz
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    
    if dist < tolerance then
        -- Sampai tujuan
        walking = false
        setVirtualKeyDown(0x57, false)  -- lepas W
        walkTarget = nil
        sampAddChatMessage("{00FF00}[AutoJob] Arrived at checkpoint " .. currentCpIndex .. ".", -1)
        -- Setelah sampai, script akan otomatis klik Y dan cooldown di loop utama
        return
    end
    
    -- Hitung sudut arah (heading) dalam derajat
    local angle = math.atan2(dy, dx) * 180 / math.pi
    -- Atur rotasi karakter menghadap target
    setCharHeading(playerPed, angle)
    -- Tekan tombol maju (W)
    setVirtualKeyDown(0x57, true)
end

-- Fungsi untuk memproses logika auto job saat tidak sedang berjalan
function processAutoJob()
    if not autoJobActive then return end
    if walking then return end  -- sedang berjalan, nanti diupdate sendiri
    
    -- Cek cooldown
    if cooldownUntil > getTickCount() then
        return  -- masih cooldown
    end
    
    -- Cek apakah masih ada checkpoint
    if currentCpIndex > #checkpoints then
        sampAddChatMessage("{00FF00}[AutoJob] All checkpoints completed! Job finished.", -1)
        stopAutoJob()
        return
    end
    
    local cp = checkpoints[currentCpIndex]
    local px, py, pz = getCharCoordinates(playerPed)
    local dx = cp.x - px
    local dy = cp.y - py
    local dz = cp.z - pz
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    
    if dist > tolerance then
        -- Belum sampai di checkpoint target, mulai berjalan
        startWalkingTo(cp)
    else
        -- Sudah sampai di checkpoint
        -- Tekan Y untuk interaksi
        pressY()
        sampAddChatMessage("{FFFF00}[AutoJob] Pressed Y at checkpoint " .. currentCpIndex .. ". Cooldown 15s...", -1)
        -- Set cooldown 15 detik
        cooldownUntil = getTickCount() + 15000
        -- Pindah ke checkpoint berikutnya setelah cooldown (akan diproses di iterasi berikutnya)
        currentCpIndex = currentCpIndex + 1
    end
end

-- Catatan: Pengecekan command server dipindahkan ke sampRegisterChatCommand di dalam main()

-- Event: saat tombol ditekan (untuk toggle global)
function onKeyPress(vkey)
    if not isSampAvailable() then return end
    if vkey == TOGGLE_KEY then
        if autoJobActive then
            stopAutoJob()
        else
            startAutoJob()
        end
    elseif vkey == RECORD_KEY then
        if recording then
            addCurrentCheckpoint()
        else
            sampAddChatMessage("{FF0000}[AutoJob] Recording mode not active. Use /startrekam first.", -1)
        end
    end
end

-- Main loop
function main()
    while not isSampAvailable() do wait(100) end
    playerPed = PLAYER_PED
    
    -- Load checkpoint dari file jika ada
    loadCheckpoints()
    
    -- Daftarkan perintah chat (command)
    sampRegisterChatCommand("startrekam", function()
        recording = true
        checkpoints = {}
        sampAddChatMessage("{00FF00}[AutoJob] Recording mode ON. Go to each checkpoint and type /cp (or press F1). Type /stoprekam to finish.", -1)
    end)
    sampRegisterChatCommand("stoprekam", function()
        recording = false
        saveCheckpoints()
    end)
    sampRegisterChatCommand("cp", function()
        if recording then
            addCurrentCheckpoint()
        else
            sampAddChatMessage("{FF0000}[AutoJob] Not in recording mode. Use /startrekam first.", -1)
        end
    end)
    sampRegisterChatCommand("startjob", startAutoJob)
    sampRegisterChatCommand("stopjob", stopAutoJob)
    sampRegisterChatCommand("cpstatus", function()
        if #checkpoints == 0 then
            sampAddChatMessage("{FFFF00}[AutoJob] No checkpoints recorded.", -1)
        else
            sampAddChatMessage("{00FF00}[AutoJob] Total checkpoints: " .. #checkpoints, -1)
            for i, cp in ipairs(checkpoints) do
                sampAddChatMessage(string.format("  %d: (%.2f, %.2f, %.2f)", i, cp.x, cp.y, cp.z), -1)
            end
        end
    end)
    
    sampAddChatMessage("{00FF00}[AutoJob] Script loaded. Commands: /startrekam, /cp, /stoprekam, /startjob, /stopjob, /cpstatus | F9 toggle job, F1 add checkpoint (rekam mode)", -1)
    
    while true do
        wait(0)
        if not isSampAvailable() then
            -- Jika SAMP tidak aktif, nonaktifkan semua aksi
            if autoJobActive then stopAutoJob() end
            walking = false
            setVirtualKeyDown(0x57, false)
            wait(1000)
        else
            playerPed = PLAYER_PED
            
            -- Cek input tombol menggunakan wasKeyPressed bawaan MoonLoader
            if wasKeyPressed(TOGGLE_KEY) then
                onKeyPress(TOGGLE_KEY)
            elseif wasKeyPressed(RECORD_KEY) then
                onKeyPress(RECORD_KEY)
            end

            if walking then
                updateWalking()
            end
            if autoJobActive then
                processAutoJob()
            end
        end
    end
end