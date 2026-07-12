-- MonetLoader manager for MoonLoader
-- Auto-apply allowed scripts per server and provide ImGui UI to manage server rules

local inicfg = require('inicfg')
local imgui = require('imgui')
local lfs_ok, lfs = pcall(require, 'lfs')

-- Determine script directory (assumes this script is in moonloader folder)
local this_file = debug.getinfo(1).source:sub(2)
local base_folder = this_file:match("(.+[\\/])") or './'
if base_folder:sub(-1) ~= '/' and base_folder:sub(-1) ~= '\\' then base_folder = base_folder .. '/' end

local config_name = 'monetloader_config'
local disabled_folder = base_folder .. 'disabled_scripts/'
local manager_filename = this_file:match('[^\\/]+$')

-- Config template
local template = {
    servers = {
        -- { id = 'mayday', match = 'mayday', allowed = { 'autofish.lua', 'indrive.lua' } }
    }
}

local cfg = inicfg.load(template, config_name)

-- Utility: ensure disabled folder exists
local function ensure_dir(path)
    if lfs_ok then
        if not lfs.attributes(path) then
            lfs.mkdir(path)
        end
    else
        -- Native Moonloader fallback (anti-minimize)
        if not doesDirectoryExist(path) then
            createDirectory(path)
        end
    end
end

ensure_dir(disabled_folder)

-- Scan for lua scripts in moonloader folder
local function scan_lua_scripts()
    local t = {}
    if lfs_ok then
        for file in lfs.dir(base_folder) do
            if file:match('%.lua$') and file ~= manager_filename then
                table.insert(t, file)
            end
        end
    else
        -- Native Moonloader fallback (anti-minimize)
        local searchPath = base_folder .. "*.lua"
        local handle, file = findFirstFile(searchPath)
        if handle and handle ~= -1 then
            while file do
                if file ~= manager_filename then
                    table.insert(t, file)
                end
                file = findNextFile(handle)
            end
            findClose(handle)
        end
    end
    table.sort(t)
    return t
end

-- Move file safely
local function move_file(src, dst)
    -- try os.rename first
    local ok, err = os.rename(src, dst)
    if not ok then
        -- fallback: try copy via io and remove
        local sfile = io.open(src, 'rb')
        if not sfile then return false, err end
        local data = sfile:read('*a')
        sfile:close()
        local dfile = io.open(dst, 'wb')
        if not dfile then return false, 'open dst failed' end
        dfile:write(data)
        dfile:close()
        os.remove(src)
        return true
    end
    return true
end

-- Apply rules for a server (move disallowed scripts to disabled folder, enable allowed ones)
local function apply_rules_for(server)
    ensure_dir(disabled_folder)
    local all = scan_lua_scripts()
    local allowed_map = {}
    for _, v in ipairs(server.allowed or {}) do allowed_map[v] = true end

    for _, fname in ipairs(all) do
        local full = base_folder .. fname
        local disabled_full = disabled_folder .. fname
        if allowed_map[fname] then
            -- ensure it's in base folder (enabled)
            if lfs_ok and lfs.attributes(disabled_full) then
                move_file(disabled_full, full)
            elseif not lfs_ok then
                -- still attempt to move if file exists
                local f = io.open(disabled_full, 'r')
                if f then f:close() move_file(disabled_full, full) end
            end
        else
            -- move to disabled if exists in base folder
            if lfs_ok and lfs.attributes(full) then
                move_file(full, disabled_full)
            else
                local f = io.open(full, 'r')
                if f then f:close() move_file(full, disabled_full) end
            end
        end
    end
end

-- Try to reload MoonLoader in several ways
local function try_reload_moonloader()
    -- Try thisScript():reload()
    local ok, err = pcall(function() thisScript():reload() end)
    if ok then return true end
    -- Try require('moonloader').reload()
    ok, err = pcall(function() require('moonloader').reload() end)
    if ok then return true end
    -- Last resort: restart script (not ideal)
    return false, err
end

-- Find server config by match string (case-insensitive, match substring in server name or address)
local function find_server_for(current_name, current_addr)
    if not cfg.servers then return nil end
    local name = (current_name or ''):lower()
    local addr = (current_addr or ''):lower()
    for _, s in ipairs(cfg.servers) do
        local m = (s.match or ''):lower()
        if m ~= '' then
            if name:find(m, 1, true) or addr:find(m, 1, true) then
                return s
            end
        end
    end
    return nil
end

-- UI state
local ui = {
    visible = true,
    add_name = '',
    add_match = '',
    selected = 1,
    scripts = scan_lua_scripts()
}

-- Ensure servers is array
cfg.servers = cfg.servers or {}

-- Auto-apply on server change
local last_server = nil

function apply_if_needed()
    if not isSampAvailable() then return end
    local curr_name = sampGetCurrentServerName() or sampGetCurrentServerAddress() or ''
    local curr_addr = sampGetCurrentServerAddress() or ''
    local key = (curr_name or '') .. '|' .. (curr_addr or '')
    if key ~= last_server then
        last_server = key
        local s = find_server_for(curr_name, curr_addr)
        if s then
            sampAddChatMessage('[MonetLoader] Applying rules for server: ' .. (s.id or s.match or 'unknown'), 0xFFFFFFFF)
            apply_rules_for(s)
            -- try reload
            try_reload_moonloader()
        end
    end
end

-- Simple ImGui layout
local function draw_ui()
    if not ui.visible then return end
    imgui.SetNextWindowSize(520, 420, imgui.Cond.FirstUseEver)
    imgui.Begin('MonetLoader - Server Script Manager', true)

    -- Left: server list
    imgui.BeginChild('left_col', 200, 300, true)
    if imgui.Button('Add New') then
        table.insert(cfg.servers, { id = 'server_' .. tostring(#cfg.servers+1), match = ui.add_match, allowed = {} })
        ui.selected = #cfg.servers
    end
    imgui.SameLine()
    if imgui.Button('Remove') then
        if cfg.servers[ui.selected] then
            table.remove(cfg.servers, ui.selected)
            if ui.selected > #cfg.servers then ui.selected = #cfg.servers end
        end
    end

    imgui.Separator()
    imgui.PushItemWidth(180)
    for i, s in ipairs(cfg.servers) do
        local label = ('%d. %s'):format(i, s.match or s.id or '')
        if imgui.Selectable(label, ui.selected == i) then ui.selected = i end
    end
    imgui.PopItemWidth()
    imgui.EndChild()

    imgui.SameLine()

    -- Right: details for selected
    imgui.BeginChild('right_col', 300, 300, false)
    if cfg.servers[ui.selected] then
        local s = cfg.servers[ui.selected]
        imgui.Text('Server ID: ' .. (s.id or ''))
        local buf = { s.match or '' }
        imgui.InputText('Match (name or addr)', buf)
        s.match = buf[1]

        imgui.Separator()
        imgui.Text('Allowed scripts:')
        ui.scripts = scan_lua_scripts()
        for _, script in ipairs(ui.scripts) do
            local checked = false
            for _, a in ipairs(s.allowed or {}) do if a == script then checked = true break end end
            local changed
            changed, checked = imgui.Checkbox(script, checked)
            if changed then
                if checked then
                    s.allowed = s.allowed or {}
                    table.insert(s.allowed, script)
                else
                    for idx, nm in ipairs(s.allowed or {}) do if nm == script then table.remove(s.allowed, idx) break end end
                end
            end
        end

        imgui.Separator()
        if imgui.Button('Save') then
            inicfg.save(cfg, config_name)
            sampAddChatMessage('[MonetLoader] Config saved.', 0xFFFFFFFF)
        end
        imgui.SameLine()
        if imgui.Button('Save & Apply') then
            inicfg.save(cfg, config_name)
            apply_rules_for(s)
            sampAddChatMessage('[MonetLoader] Applied rules.', 0xFFFFFFFF)
        end
        imgui.SameLine()
        if imgui.Button('Save, Apply & Reload') then
            inicfg.save(cfg, config_name)
            apply_rules_for(s)
            local ok, err = try_reload_moonloader()
            if ok then sampAddChatMessage('[MonetLoader] Reloaded.', 0xFFFFFFFF) else sampAddChatMessage('[MonetLoader] Reload failed.', 0xFFFF0000) end
        end

    else
        imgui.Text('No server selected')
    end
    imgui.EndChild()

    imgui.End()
end

function main()
    while not isSampfuncsLoaded() do wait(100) end
    sampRegisterChatCommand('ml', function() ui.visible = not ui.visible end)
    while true do
        apply_if_needed()
        wait(1000)
    end
end

function onScriptTerminate(script)
    if script == thisScript() then
        inicfg.save(cfg, config_name)
    end
end

function onShowUI(flag)
    ui.visible = flag
end

-- Draw UI via imgui callback
function imgui_onFrame()
    draw_ui()
end
