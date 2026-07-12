script_name("Auto Fish It")
script_author("Antigravity")
script_description("Auto Fishing for SAMP with Server /fauto integration")

local ev = require 'lib.samp.events'
local vkeys = require 'vkeys'

local isActive = false
local serverAutoEnabled = false
local isSyncing = false

function main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("autofishit", function(arg)
        if arg == "off" then
            isActive = false
            serverAutoEnabled = false
            isSyncing = false
            sampAddChatMessage("{FF0000}[AutoFish] {FFFFFF}Script Dimatikan!", -1)
        else
            isActive = true
            serverAutoEnabled = false
            isSyncing = true
            sampAddChatMessage("{00FF00}[AutoFish] {FFFFFF}Script Dinyalakan! Menunggu sinkronisasi /fauto...", -1)
            sampSendChat("/fauto")
        end
    end)

    while true do
        wait(0)
    end
end

function ev.onServerMessage(color, text)
    if not isActive then return end

    -- Sync Logic for /fauto
    if text:find("Auto Fishing enabled") then
        serverAutoEnabled = true
        isSyncing = false
        sampAddChatMessage("{00FF00}[AutoFish] {FFFFFF}Server Auto Fishing AKTIF. Memulai pancing...", -1)
    elseif text:find("Auto Fishing disabled") then
        serverAutoEnabled = false
        if isSyncing then
            lua_thread.create(function()
                wait(2000) -- Wait 2 seconds before retrying
                if isActive and not serverAutoEnabled then
                    sampSendChat("/fauto")
                end
            end)
        end
    end

    -- Fishing Logic
    if serverAutoEnabled then
        -- 1. Trigger to cast: [Info]: {FFFFFF}Tekan 'ALT' untuk melemparkan kail pancing anda!
        if text:find("Tekan 'ALT' untuk melemparkan kail") then
            pressAlt()
        end

        -- 2. Trigger after getting fish: [Info]: {FFFFFF}Anda mendapatkan 1x ...
        if text:find("Anda mendapatkan") then
            lua_thread.create(function()
                local delay = math.random(2000, 4000)
                sampAddChatMessage("{00FF00}[AutoFish] {FFFFFF}Ikan didapat! Menunggu " .. delay .. "ms sebelum melempar kembali...", -1)
                wait(delay)
                if isActive then
                    pressAlt()
                end
            end)
        end

        -- 3. Trigger tas penuh
        if text:find("Tas pancing Anda sudah penuh untuk jenis ikan ini") then
            lua_thread.create(function()
                local delay = math.random(2000, 4000)
                sampAddChatMessage("{00FF00}[AutoFish] {FFFFFF}Tas penuh untuk ikan ini! Menunggu " .. delay .. "ms sebelum melempar kembali...", -1)
                wait(delay)
                if isActive then
                    pressAlt()
                end
            end)
        end

        -- 4. Trigger no bobber
        if text:find("Anda tidak memiliki bobber di inventory") then
            isActive = false
            serverAutoEnabled = false
            isSyncing = false
            sampAddChatMessage("{FF0000}[AutoFish] {FFFFFF}AutoFishIt dimatikan dikarenakan Boober Sudah Habis", -1)
        end

        -- 5. Trigger out of area
        if text:find("Auto Fishing dimatikan otomatis karena Anda meninggalkan area pemancingan") then
            isActive = false
            serverAutoEnabled = false
            isSyncing = false
            sampAddChatMessage("{FF0000}[AutoFish] {FFFFFF}AutoFishIt dimatikan dikarenakan Anda meninggalkan area pemancingan", -1)
        end
    end
end

function pressAlt()
    lua_thread.create(function()
        -- Simulate Alt key (VK_MENU = 18, LALT = 19 in game keys)
        setVirtualKeyDown(vkeys.VK_MENU, true)
        setGameKeyState(19, 255)
        wait(250)
        setVirtualKeyDown(vkeys.VK_MENU, false)
        setGameKeyState(19, 0)
    end)
end
