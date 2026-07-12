

-- Invoice System for SAMP
-- Created by Arkananta Studio
-- Author: Arkananta Studio - Invoice Roleplay System

local sampev = require 'lib.samp.events'
local ffi = require 'ffi'
local encoding = require 'encoding'

encoding.default = 'CP1251'
u8 = encoding.UTF8

-- Configuration
local INVOICE_CONFIG = {
    invoiceDialogId = 443,     -- ID dialog untuk invoice (nama)
    amountDialogId = 444,      -- ID dialog untuk invoice (nominal)
    successDialogId = 88,    -- ID dialog untuk invoice (success)
    messageDelay = 4000,       -- Delay antar pesan (4 detik)
    enabled = true,           -- Status sistem
    debugMode = false         -- Debug mode (nonaktif untuk clean output)
}

-- Queue untuk menyimpan aksi roleplay
local actionQueue = {}
local isProcessingQueue = false

-- Fungsi logging sederhana
local function log(message, logType)
    if INVOICE_CONFIG.debugMode then
        print(string.format("[Invoice] %s", message))
    end
end

-- Fungsi untuk mengirim pesan roleplay dengan delay
function sendRoleplayMessage(message, delay)
    local currentTime = os.clock() * 1000
    local lastMessageTime = 0
    
    if #actionQueue > 0 then
        local lastAction = actionQueue[#actionQueue]
        lastMessageTime = lastAction.sendTime or currentTime
    end
    
    local sendTime = lastMessageTime + (delay or INVOICE_CONFIG.messageDelay)
    
    table.insert(actionQueue, {
        message = message,
        delay = delay or INVOICE_CONFIG.messageDelay,
        sendTime = sendTime,
        timestamp = currentTime
    })
    log(string.format("Queue: %s", message), "debug")
end

-- Fungsi untuk mengirim multiple pesan
function sendMultipleRoleplayMessages(messageList)
    for i, item in ipairs(messageList) do
        sendRoleplayMessage(item[1], item[2])
    end
end

-- Fungsi untuk memproses queue
local function processActionQueue()
    if isProcessingQueue or #actionQueue == 0 then
        return
    end
    
    isProcessingQueue = true
    local currentTime = os.clock() * 1000
    
    local action = actionQueue[1]
    if currentTime >= action.sendTime then
        sampProcessChatInput(action.message)
        log(string.format("Sent: %s", action.message), "debug")
        table.remove(actionQueue, 1)
    end
    
    isProcessingQueue = false
end

-- Dialog triggers untuk invoice
local dialogTriggers = {
    {
        id = INVOICE_CONFIG.invoiceDialogId,  -- 443: Input nama
        name = "Invoice Nama Dialog",
        actions = function()
            lua_thread.create(function()
                wait(1000)
                sampProcessChatInput('/eprop tablet')
                wait(4000)
                sampProcessChatInput('/me mengambil tablet dari tas')
                wait(4000)
                sampProcessChatInput('/me Membuka aplikasi invoice di tablet')
                wait(4000)
                sampProcessChatInput('/me menyiapkan formulir invoices')
                wait(4000)
                sampProcessChatInput('/e x')
            end)
        end
    },
    {
        id = INVOICE_CONFIG.amountDialogId,  -- 444: Input nominal
        name = "Invoice Nominal Dialog", 
        actions = function()
            lua_thread.create(function()
                wait(1500)
                sampProcessChatInput('/me membuka kalkulator di tablet')
                wait(4000)
                sampProcessChatInput('/me Menghitung nominal tagihan')
                wait(4000)
                sampProcessChatInput('/me mengetik nominal invoices')
            end)
        end
    },
    {
        id = INVOICE_CONFIG.successDialogId,
        name = "Invoice Success",
        actions = function()
            lua_thread.create(function()
                wait(1000)
                sampProcessChatInput('/me Invoices Berhasil Diberikan')
            end)
        end
    },
}

-- Event handler untuk dialog SAMP
function sampev.onShowDialog(id, style, title, button1, button2, text)
    -- Cek trigger berdasarkan ID
    for _, trigger in ipairs(dialogTriggers) do
        if trigger.id == id then
            trigger.actions()
            return
        end
    end
    
    -- Auto-detect berdasarkan title jika mengandung "invoice"
    if title:lower():find("invoice") then
        addInvoiceTrigger(id, "Auto-detect", function()
            lua_thread.create(function()
                wait(1000)
                sampProcessChatInput('/eprop tablet')
                wait(4000)
                sampProcessChatInput('/me mengambil tablet dari tas')
                wait(4000)
                sampProcessChatInput('/me Membuka aplikasi invoice di tablet')
                wait(4000)
                sampProcessChatInput('/me memberikan invoices kepada pasien')
                wait(2000)
                sampProcessChatInput('/e x')
            end)
        end)
        dialogTriggers[#dialogTriggers].actions()
    end
end

-- Fungsi untuk menambah trigger baru
function addInvoiceTrigger(dialogId, name, actions)
    table.insert(dialogTriggers, {
        id = dialogId,
        name = name,
        actions = actions
    })
    log(string.format("Added trigger: %s (ID: %d)", name, dialogId))
end

-- Fungsi untuk menghapus trigger
function removeInvoiceTrigger(dialogId)
    for i, trigger in ipairs(dialogTriggers) do
        if trigger.id == dialogId then
            table.remove(dialogTriggers, i)
            log(string.format("Removed trigger: ID %d", dialogId))
            break
        end
    end
end

-- Fungsi untuk enable/disable system (tidak aktif)
function setInvoiceSystemEnabled(enabled)
    sampAddChatMessage("{FFFF00}[Invoice] System always active", -1)
end

-- Fungsi untuk toggle system (tidak aktif)
function toggleInvoiceSystem()
    sampAddChatMessage("{FFFF00}[Invoice] System always active", -1)
end

-- Fungsi untuk trigger manual
local function manualInvoice()
    lua_thread.create(function()
        wait(1000)
        sampProcessChatInput('/eprop tablet')
        wait(4000)
        sampProcessChatInput('/me mengambil tablet dari tas')
        wait(4000)
        sampProcessChatInput('/me Membuka aplikasi invoice di tablet')
        wait(4000)
        sampProcessChatInput('/me memberikan invoices kepada pasien')
        wait(2000)
        sampProcessChatInput('/e x')
    end)
    sampAddChatMessage("{00FF00}[Invoice] Manual trigger executed", -1)
end

-- Fungsi untuk toggle debug mode
function toggleDebugMode()
    INVOICE_CONFIG.debugMode = not INVOICE_CONFIG.debugMode
    local status = INVOICE_CONFIG.debugMode and "enabled" or "disabled"
    sampAddChatMessage(string.format("{FFFF00}[Invoice] Debug mode %s", status), -1)
end

-- Fungsi untuk menampilkan semua trigger
function showAllTriggers()
    if #dialogTriggers == 0 then
        sampAddChatMessage("{FF0000}[Invoice] No triggers registered", -1)
        return
    end
    
    sampAddChatMessage("{FFFF00}[Invoice] Registered triggers:", -1)
    for i, trigger in ipairs(dialogTriggers) do
        sampAddChatMessage(string.format("{FFFFFF}%d. ID: {00FF00}%d{FFFFFF}, Name: {00FF00}%s", i, trigger.id, trigger.name), -1)
    end
end

-- Fungsi untuk cek status
function checkInvoiceStatus()
    local queueSize = #actionQueue
    local triggerCount = #dialogTriggers
    sampAddChatMessage(string.format("{00FF00}[Invoice] Active{FFFF00} | Queue: {FFFFFF}%d{FFFF00} | Triggers: {FFFFFF}%d", queueSize, triggerCount), -1)
end

-- Main loop
function main()
    repeat wait(0) until isSampAvailable()
    while true do
        wait(0)
        if sampIsLocalPlayerSpawned() then
            sampAddChatMessage("{00FF00}[Invoice] Script berhasil dimuat!", -1)
            sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/invoice help{FFFFFF} untuk melihat command", -1)
            break
        end
    end

    while true do
        if #actionQueue > 0 then
            local action = actionQueue[1]
            local currentTime = os.clock() * 1000
            local waitTime = action.sendTime - currentTime
            
            if waitTime <= 0 then
                processActionQueue()
                wait(50)
            else
                wait(math.min(waitTime, 500))
            end
        else
            wait(500)
        end
    end
end

-- Script initialization
function onScriptInit()
    print("[Invoice] System initialized")
    sampAddChatMessage("{00FF00}[Invoice] System ready", -1)
end

-- Script termination
function onScriptTerminate(script, quitGame)
    if script == thisScript() then
        print("[Invoice] Script terminated")
    end
end

-- Command handler
function sampev.onServerMessage(color, text)
    local message = u8:decode(text)
    
    if message:find("^/invoice") then
        if message:find("^/invoice manual") then
            manualInvoice()
            return false
        elseif message:find("^/invoice status") then
            checkInvoiceStatus()
            return false
        elseif message:find("^/invoice help") then
            sampAddChatMessage("{00FF00}[Invoice] Commands:", -1)
            sampAddChatMessage("{FFFFFF}/invoice manual - Manual trigger", -1)
            sampAddChatMessage("{FFFFFF}/invoice status - System status", -1)
            sampAddChatMessage("{FFFFFF}/invoice help - Show help", -1)
            return false
        else
            checkInvoiceStatus()
            return false
        end
    end
end