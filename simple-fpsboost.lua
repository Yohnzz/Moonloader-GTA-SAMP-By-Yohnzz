function main()
    repeat wait(0) until isSampAvailable()
    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[FPSBoost] Script berhasil dimuat!", -1)
            break
        end
    end
    while true do wait(-1) end
end