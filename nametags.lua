script_name("nametags")
script_author("Arkananta Studio")
script_version("2.5.1")

local bit = require 'bit'

imgui, ec, ffi, ev, mem, ped, h = require 'imgui', require 'encoding', require "ffi", require 'lib.samp.events', require 'memory', playerPed, playerHandle
flag, getBonePosition = require ('moonloader').font_flag, ffi.cast("int (__thiscall*)(void*, float*, int, bool)", 0x5E4280)
path = getWorkingDirectory() .. '\\config\\' cfg = path .. 'nametags.ini' ec.default = 'CP1251' u8 = ec.UTF8
menu, nt, server, fontid, mid, name = {imgui.ImBool(false)}, {}, {distance = 0}, {}, 0, {[0]='Main','Health','Armor','Names','Chatbubbles'}

function main()
	if not doesDirectoryExist(path) then createDirectory(path) end
	if doesFileExist(cfg) then loadIni() else blankIni() end
	for i = 1, 4 do createfont(i) end
  	repeat wait(0) until isSampAvailable()
    sampRegisterChatCommand("nametags", function() menu[1].v = not menu[1].v end)
    lua_thread.create(function()
        while true do
            wait(0)
            if sampIsLocalPlayerSpawned() then
                sampAddChatMessage("{00FF00}[Nametags] Script berhasil dimuat!", -1)
                sampAddChatMessage("{FFFFFF}Gunakan {00FF00}/nametags{FFFFFF} untuk membuka menu", -1)
                break
            end
        end
    end)
	sampfuncsLog("(Nametags: /nametags) Authors: " .. table.concat(thisScript().authors, ", "))
    while sampGetGamestate() ~= 3 do wait(100) end
    serverPtr = sampGetServerSettingsPtr()
	server.distance = nameTags_getDistance()
    while true do wait(1) 
		if nt.toggle[1] then if nameTags_getState() == 1 then nameTags_setState(0) end else if nameTags_getState() == 0 then nameTags_setState(1) end end
		if not menu[1].v and mid ~= 0 then mid = 0 end 
		drawNametags()
		imgui.Process = menu[1].v 
	end
end

function imgui.OnDrawFrame()
	width, height = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(width / 2, height / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowSize(imgui.ImVec2(440, 320), imgui.Cond.FirstUseEver)
	imgui.Begin(u8('Nametag Settings - '.. name[mid]..'	id:('..mid..')'), menu[1], imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove +  imgui.WindowFlags.NoCollapse + imgui.WindowFlags.MenuBar)
	if imgui.BeginMenuBar() then for i = 0, 4 do if imgui.MenuItem(u8(name[i])) then mid = i end end imgui.EndMenuBar() end
	if mid == 0 then
		if imgui.Checkbox(u8'Toggle', imgui.ImBool(nt.toggle[1])) then nt.toggle[1] = not nt.toggle[1] end
		imgui.SameLine(100) 
		if imgui.Checkbox('Autosave', imgui.ImBool(nt.toggle[2])) then nt.toggle[2] = not nt.toggle[2] saveIni() end 
		imgui.SameLine(255)
		if imgui.Button(u8'Reset', imgui.ImVec2(80, 25)) then blankIni() for i = 1, 4 do createfont(i) end end
		imgui.SameLine(345)
		if imgui.Button(u8'Save', imgui.ImVec2(80, 25)) then saveIni() end
	else
		if mid == 1 or mid == 2 then
			if imgui.Checkbox(u8'Bar', imgui.ImBool(nt.tog[mid][1])) then nt.tog[mid][1] = not nt.tog[mid][1] end 
			imgui.SameLine(80) 
			if imgui.Checkbox(u8'Text', imgui.ImBool(nt.tog[mid][2])) then nt.tog[mid][2] = not nt.tog[mid][2] end 
			imgui.NewLine() 
			imgui.SameLine(40) 
			imgui.Text(u8'Color') 
			imgui.SameLine(135) 
			imgui.Text(u8'Border') 
			imgui.SameLine(255) 
			imgui.Text(u8'Fade') 
			imgui.SameLine(375) 
			imgui.Text(u8'Alpha')
			imgui.PushItemWidth(110)
			color = imgui.ImFloat3(explode_rgba(1, nt.color[mid][1]))
			if imgui.ColorEdit3('##color', color, imgui.ColorEditFlags.HEX) then nt.color[mid][1] = join_argb(255, color.v[1], color.v[2], color.v[3]) end
			imgui.SameLine(135)
			color3 = imgui.ImFloat3(explode_rgba(1, nt.color[mid][3]))
			if imgui.ColorEdit3('##bordercolor', color3, imgui.ColorEditFlags.HEX) then nt.color[mid][3] = join_argb(255, color3.v[1], color3.v[2], color3.v[3]) end
			imgui.SameLine(255)
			color2 = imgui.ImFloat3(explode_rgba(1, nt.color[mid][2][1]))
			if imgui.ColorEdit3('##fade', color2, imgui.ColorEditFlags.HEX) then nt.color[mid][2][1] = join_argb(255, color2.v[1], color2.v[2], color2.v[3]) end
			imgui.PopItemWidth()
			imgui.SameLine(375)
			imgui.PushItemWidth(50)
			alpha  = imgui.ImInt(nt.color[mid][2][2])
			if imgui.DragInt('##alpha', alpha, 0.1, 0, 255) then nt.color[mid][2][2] = alpha.v end
			imgui.PopItemWidth()
			imgui.NewLine() 
			imgui.SameLine(35) 
			imgui.Text(u8'Left/Right') 
			imgui.SameLine(110) 
			imgui.Text(u8'Up/Down') 
			imgui.SameLine(210) 
			imgui.Text(u8'Width') 
			imgui.SameLine(310) 
			imgui.Text(u8'Height') 
			imgui.SameLine(375) 
			imgui.Text(u8'Border')
			imgui.PushItemWidth(350)
			move = imgui.ImFloat4(nt.offset[mid][1], nt.offset[mid][2], nt.size[mid][1], nt.size[mid][2])
			if imgui.DragFloat4('##movement', move, 0.1, -200, 200, "%.1f") then nt.offset[mid][1] = move.v[1] nt.offset[mid][2] = move.v[2] nt.size[mid][1] = move.v[3] nt.size[mid][2] = move.v[4] end 
			imgui.PopItemWidth()
			imgui.SameLine(375)
			imgui.PushItemWidth(50)
			border = imgui.ImInt(nt.border[mid])
			if imgui.DragInt('##border', border, 0.1, 0, 5) then nt.border[mid] = border.v end
			imgui.PopItemWidth()
		elseif mid == 3 then
			if imgui.Checkbox(u8'Names', imgui.ImBool(nt.tog[mid][1])) then nt.tog[mid][1] = not nt.tog[mid][1] end
		elseif mid == 4 then
			if imgui.Checkbox(u8'Chatbubbles', imgui.ImBool(nt.tog[mid][1])) then nt.tog[mid][1] = not nt.tog[mid][1] end
		end
		imgui.NewLine() imgui.SameLine(40) imgui.Text(u8'Font') imgui.SameLine(114) imgui.Text(u8'Size')
		if nt.alignfont[mid] == 1 then imgui.SameLine(191) imgui.Text(u8'Left')
		elseif nt.alignfont[mid] == 2 then imgui.SameLine(185) imgui.Text(u8'Center')
		elseif nt.alignfont[mid] == 3 then imgui.SameLine(188) imgui.Text(u8'Right') end
		imgui.SameLine(260) imgui.Text(u8'Bold') imgui.SameLine(294) imgui.Text(u8'Italics') imgui.SameLine(335) imgui.Text(u8'Border') imgui.SameLine(380) imgui.Text(u8'Shadow')
		imgui.PushItemWidth(75)
		font = imgui.ImBuffer(30) font.v = nt.font[mid]
		if imgui.InputText('##Font1', font, imgui.InputTextFlags.EnterReturnsTrue) then nt.font[mid] = font.v createfont(mid) end
		imgui.PopItemWidth()
		imgui.SameLine(100)
		imgui.PushItemWidth(50)
		fsize = imgui.ImInt(nt.fontsize[mid])
		if imgui.DragInt(u8'##Size1', fsize, 0.01, 4, 48) then nt.fontsize[mid] = fsize.v createfont(mid) end
		imgui.PopItemWidth()
		imgui.SameLine(160)
		if imgui.Button('##Left1', imgui.ImVec2(25, 25)) then nt.alignfont[mid] = 1 end
		imgui.SameLine(190)
		if imgui.Button('##Center1', imgui.ImVec2(25, 25)) then nt.alignfont[mid] = 2 end
		imgui.SameLine(220)
		if imgui.Button('##Right1', imgui.ImVec2(25, 25)) then nt.alignfont[mid] = 3 end
		imgui.SameLine(260)
		if imgui.Checkbox('##Bold1', imgui.ImBool(nt.fontflag[mid][1])) then nt.fontflag[mid][1] = not nt.fontflag[mid][1] createfont(mid) end
		imgui.SameLine(297)
		if imgui.Checkbox('##Italics1', imgui.ImBool(nt.fontflag[mid][2])) then nt.fontflag[mid][2] = not nt.fontflag[mid][2] createfont(mid) end
		imgui.SameLine(340)
		if imgui.Checkbox('##Border1', imgui.ImBool(nt.fontflag[mid][3])) then nt.fontflag[mid][3] = not nt.fontflag[mid][3] createfont(mid) end
		imgui.SameLine(388)
		if imgui.Checkbox('##Shadow1', imgui.ImBool(nt.fontflag[mid][4])) then nt.fontflag[mid][4] = not nt.fontflag[mid][4] createfont(mid) end
		imgui.NewLine() imgui.SameLine(35) imgui.Text(u8'Left/Right') imgui.SameLine(140) imgui.Text(u8'Up/Down')
		if mid == 1 or mid == 2 then
			imgui.SameLine(220) 
			imgui.Text(u8'Text')
		elseif mid == 3 then
			imgui.SameLine(230) 
			imgui.Text(u8'Alpha')
		elseif mid == 4 then 
			imgui.SameLine(220) 
			imgui.Text(nt.tog[mid][2] and 'Color' or 'Disabled') 
			imgui.SameLine(365) 
			imgui.Text(u8'Alpha')
		end
		imgui.PushItemWidth(197)
		move2 = imgui.ImFloat2(nt.text[mid][1], nt.text[mid][2])
		if imgui.DragFloat2('##movement2', move2, 0.1, -200, 200, "%.1f") then nt.text[mid][1] = move2.v[1] nt.text[mid][2] = move2.v[2] end
		imgui.PopItemWidth()
		if mid == 1 or mid == 2 then
			imgui.SameLine(220)
			imgui.PushItemWidth(110)
			color4 = imgui.ImFloat3(explode_rgba(1, nt.color[mid][4]))
			if imgui.ColorEdit3('##textcolor', color4, imgui.ColorEditFlags.HEX) then nt.color[mid][4] = join_argb(255, color4.v[1], color4.v[2], color4.v[3]) end
			imgui.PopItemWidth()
		elseif mid == 3 then
			imgui.SameLine(230)
			imgui.PushItemWidth(50)
			alpha  = imgui.ImInt(nt.color[3][1])
			if imgui.DragInt('##alpha', alpha, 0.1, 0, 255) then nt.color[3][1] = alpha.v end
			imgui.PopItemWidth()
		elseif mid == 4 then
			imgui.SameLine(220)
			imgui.PushItemWidth(110)
			if imgui.Checkbox('##customcolor', imgui.ImBool(nt.tog[mid][2])) then nt.tog[mid][2] = not nt.tog[mid][2] end
			imgui.SameLine(245)
			color = imgui.ImFloat3(explode_rgba(1, nt.tog[mid][2] and nt.color[mid][1] or -16777216))
			if imgui.ColorEdit3('##colorchat',color, imgui.ColorEditFlags.HEX) and nt.tog[mid][2] then nt.color[mid][1] = join_argb(255, color.v[1], color.v[2], color.v[3]) end
			imgui.PopItemWidth()
			imgui.SameLine(365)
			imgui.PushItemWidth(50)
			alpha  = imgui.ImInt(nt.color[mid][2])
			if imgui.DragInt('##alpha', alpha, 0.1, 0, 255) then nt.color[mid][2] = alpha.v end
			imgui.PopItemWidth()
		end
	end
	imgui.End()
end

function drawNametags()
	if sampIsLocalPlayerSpawned() and not isPauseMenuActive() and not sampIsScoreboardOpen() and not isSampfuncsConsoleActive() and sampGetChatDisplayMode() > 0 and nt.toggle[1] then
		for i = 0, sampGetMaxPlayerId(false) do
			local getted, remotePlayer = sampGetCharHandleBySampPlayerId(i)
			if getted then
				local remotePlayerX, remotePlayerY, remotePlayerZ = getBodyPartCoordinates(8, remotePlayer);
				local myPosX, myPosY, myPosZ = getCharCoordinates(playerPed)
				local dist = getDistanceBetweenCoords3d(remotePlayerX, remotePlayerY, remotePlayerZ, myPosX, myPosY, myPosZ)
				if dist <= server.distance then
					if isCharOnScreen(remotePlayer) then
						local camX, camY, camZ = getActiveCameraCoordinates()
						local wposX, wposY = convert3DCoordsToScreen(remotePlayerX, remotePlayerY, remotePlayerZ + 0.4 + (dist * 0.05))
						local result, colPoint = processLineOfSight(camX, camY, camZ, remotePlayerX, remotePlayerY, remotePlayerZ, true, false, false, true, false, false, false, true)
						if not result then
							local health, armor, color, text, afkState = sampGetPlayerHealth(i), sampGetPlayerArmor(i), sampGetPlayerColor(i), string.format("%s (%d)", sampGetPlayerNickname(i), i), sampIsPlayerPaused(i)
							local r, g, b = explode_rgba(1, color) color = join_argb(255, r, g, b)
							if afkState then text = "[AFK] " .. text; end
							if armor > 1 then offx = nt.offset[1][1] offy = nt.offset[1][2] txtx = nt.text[1][1] txty = nt.text[1][2] else offx = nt.offset[2][1] offy = nt.offset[2][2] txtx = nt.text[2][1] txty = nt.text[2][2] end
							if nt.tog[1][1] then renderbar(wposX + offx, wposY + offy, nt.size[1][1], nt.size[1][2], nt.border[1], 100, health, nt.color[1][1], nt.color[1][2][1], nt.color[1][3], nt.color[1][2][2]) end
							if nt.tog[1][2] then renderFontDrawText(fontid[1], health, wposX + txtx - aligntext(fontid[1], health, nt.alignfont[1]), wposY  + txty, nt.color[1][4]) end
							if armor > 1 then
								if nt.tog[2][1] then renderbar(wposX + nt.offset[2][1], wposY + nt.offset[2][2], nt.size[2][1], nt.size[2][2], nt.border[2], 100, armor, nt.color[2][1], nt.color[2][2][1], nt.color[2][3], nt.color[2][2][2]) end
								if nt.tog[2][2] then renderFontDrawText(fontid[2], armor, wposX - aligntext(fontid[2], armor, nt.alignfont[2]) + nt.text[2][1], wposY  + nt.text[2][2], nt.color[2][4]) end
							end
							if nt.tog[3][1] then renderFontDrawText(fontid[3], text, wposX - aligntext(fontid[3], text, nt.alignfont[3]) + nt.text[3][1], wposY  + nt.text[3][2], change_alpha(color, nt.color[3][1])) end
						end
					end
				end
			end
		end
		for k, v in pairs(chatBubbles) do
			if os.time() > v["time"] then 
				table.remove(chatBubbles, i);
			else
				local getted, remotePlayer = sampGetCharHandleBySampPlayerId(v["playerid"])
				if getted then
					local remotePlayerX, remotePlayerY, remotePlayerZ = getBodyPartCoordinates(8, remotePlayer);
					local myPosX, myPosY, myPosZ = getCharCoordinates(playerPed)
					local dist = getDistanceBetweenCoords3d(remotePlayerX, remotePlayerY, remotePlayerZ, myPosX, myPosY, myPosZ)
					if dist <= v["dist"] then
						if isCharOnScreen(remotePlayer) then
							local camX, camY, camZ = getActiveCameraCoordinates()
							local wposX, wposY = convert3DCoordsToScreen(remotePlayerX, remotePlayerY, remotePlayerZ + 0.4 + (dist * 0.05))
							local result, colPoint = processLineOfSight(camX, camY, camZ, remotePlayerX, remotePlayerY, remotePlayerZ, true, false, false, true, false, false, false, true)
							if not result then
								--local r, g, b, a = explode_rgba(2, v["color"]) 
								--v["color"] = join_argb(a, r, g, b)
								--change_alpha(nt.tog[4][2] and nt.color[4][1] or v["color"], nt.color[4][2])
								
								color = bgra_to_argb(v["color"])
								text = string.format("{%06X}%s", color, v["text"])
								--print(text)
								if nt.tog[4][1] then renderFontDrawText(fontid[4], v["text"], wposX - aligntext(fontid[4], v["text"], nt.alignfont[4]) + nt.text[4][1], wposY + nt.text[4][2], color) end
							end
						end
					end
				end
			end
		end
	end
end

chatBubbles = chatBubbles or {};
function ev.onPlayerChatBubble(playerId, color, dist, time, text)
    for k, v in pairs(chatBubbles) do
        if v["playerid"] == playerId then
            table.remove(chatBubbles, k);
            break;
        end
    end

    local tbl = {
        ["playerid"] = playerId,
        ["color"] = color,
        ["dist"] = dist,
        ["time"] = os.time() + time / 1000,
        ["text"] = text
    }
    table.insert(chatBubbles, tbl);
    return false
end

function onScriptTerminate(scr, quitGame) 
	if scr == script.this then 
		if nt.toggle[2] then 
			saveIni() 
		end 
	end
end

function nameTags_getDistance() 
	return mem.getfloat(serverPtr + 39, 1) 
end

function nameTags_getState() 
	return mem.getint8(serverPtr + 56, 1) 
end

function nameTags_setState(state) 
	mem.setint8(serverPtr + 56, state) 
end

function createfont(id)
	flags, flagids = {}, {flag.BOLD,flag.ITALICS,flag.BORDER,flag.SHADOW}
	for i = 1, 4 do flags[i] = nt.fontflag[id][i] and flagids[i] or 0 end
	fontid[id] = renderCreateFont(nt.font[id], nt.fontsize[id], flags[1] + flags[2] + flags[3] + flags[4])
end

function aligntext(fid, value, id)
	l = renderGetFontDrawTextLength(fid, value) 
	if id == 1 then 
		return 0
	elseif id == 2 then 
		return l / 2 
	elseif id == 3 then 
		return l 
	end
end

function renderbar(x, y, sizex, sizey, border, maxvalue, value, color, color2, color3, alpha)
	renderDrawBoxWithBorder(x, y, sizex, sizey, change_alpha(color2, alpha), border, color3)
	renderDrawBox(x + border, y + border, sizex / maxvalue * value - (2 * border), sizey - (2 * border), color)
end

function getBodyPartCoordinates(id, handle)
	local pedptr = getCharPointer(handle)
	local vec = ffi.new("float[3]")
	getBonePosition(ffi.cast("void*", pedptr), vec, id, true)
	return vec[0], vec[1], vec[2]
end

function explode_rgba(type, rgba)
	local a = bit.band(bit.rshift(rgba, 24), 0xFF)
	local r = bit.band(bit.rshift(rgba, 16), 0xFF)
	local g = bit.band(bit.rshift(rgba, 8),	 0xFF)
	local b = bit.band(rgba, 0xFF)
	if type == 1 then
		return r / 255, g / 255, b / 255
	elseif type == 2 then
		return r / 255, g / 255, b / 255, a / 255
	end
end

function join_argb(a, r, g, b)
	local argb = b * 255
    argb = bit.bor(argb, bit.lshift(g * 255, 8))
    argb = bit.bor(argb, bit.lshift(r * 255, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

function change_alpha(c, a)
	local r, g, b = explode_rgba(1, c)
	return join_argb(a, r, g, b)
end

function argb_to_rgb(argb)
	return bit.band(argb, 0xFFFFFF)
end

function bgra_to_argb(bgra)
  local b, g, r, a = explode_argb(bgra)
  return join_argb2(a, r, g, b)
end

function explode_argb(argb)
  local a = bit.band(bit.rshift(argb, 24), 0xFF)
  local r = bit.band(bit.rshift(argb, 16), 0xFF)
  local g = bit.band(bit.rshift(argb, 8), 0xFF)
  local b = bit.band(argb, 0xFF)
  return a, r, g, b
end

function join_argb2(a, r, g, b)
  local argb = b  -- b
  argb = bit.bor(argb, bit.lshift(g, 8))  -- g
  argb = bit.bor(argb, bit.lshift(r, 16)) -- r
  argb = bit.bor(argb, bit.lshift(a, 24)) -- a
  return argb
end

function blankIni()
	nt = {
		toggle = {true,false},
		tog = {{true,true},{true,true},{true},{true,false}},
		offset = {{-24,28},{-24,18}},
		size = {{50,6},{50,6}},
		border = {1,1},
		text = {{-27.5,25.5},{-27.5,15.5},{0,-3},{0,-17.5}},
		font = {'Aerial','Aerial','Aerial','Aerial'},
		fontsize = {6,6,10,9},
		alignfont = {3,3,2,2},
		fontflag = {{true,false,true,true},{true,false,true,true},{true,false,false,true},{true,false,false,true}},
		color = {{-65536,{-16777216,127},-16777216,-1},{-1,{-16777216,127},-16777216,-1},{255},{-1,200}},
	}
	saveIni()
end

function loadIni()
	local f = io.open(cfg, "r") if f then nt = decodeJson(f:read("*all")) f:close() end
end

function saveIni()
	if type(nt) == "table" then local f = io.open(cfg, "w") f:close() if f then local f = io.open(cfg, "r+") f:write(encodeJson(nt)) f:close() end end
end

function apply_style()
	local s = imgui.GetStyle()
	local clrs = s.Colors
	local clr = imgui.Col
	local im4 = imgui.ImVec4
	local im2 = imgui.ImVec2
	s.WindowPadding = im2(15, 15)
	s.WindowRounding = 6.0
	s.FramePadding = im2(5, 5)
	s.FrameRounding = 4.0
	s.ItemSpacing = im2(12, 8)
	s.ItemInnerSpacing = im2(8, 6)
	s.IndentSpacing = 25.0
	s.ScrollbarSize = 15.0
	s.ScrollbarRounding = 9.0
	s.GrabMinSize = 5.0
	s.GrabRounding = 3.0
	clrs[clr.Text] = im4(0.80, 0.80, 0.83, 1.00)
	clrs[clr.TextDisabled] = im4(0.24, 0.23, 0.29, 1.00)
	clrs[clr.WindowBg] = im4(0.06, 0.05, 0.07, 1.00)
	clrs[clr.ChildWindowBg] = im4(0.07, 0.07, 0.09, 1.00)
	clrs[clr.PopupBg] = im4(0.07, 0.07, 0.09, 1.00)
	clrs[clr.Border] = im4(0.80, 0.80, 0.83, 0.88)
	clrs[clr.BorderShadow] = im4(0.92, 0.91, 0.88, 0.00)
	clrs[clr.FrameBg] = im4(0.10, 0.09, 0.12, 1.00)
	clrs[clr.FrameBgHovered] = im4(0.24, 0.23, 0.29, 1.00)
	clrs[clr.FrameBgActive] = im4(0.56, 0.56, 0.58, 1.00)
	clrs[clr.TitleBg] = im4(0.76, 0.31, 0.00, 1.00)
	clrs[clr.TitleBgCollapsed] = im4(1.00, 0.98, 0.95, 0.75)
	clrs[clr.TitleBgActive] = im4(0.80, 0.33, 0.00, 1.00)
	clrs[clr.MenuBarBg] = im4(0.10, 0.09, 0.12, 1.00)
	clrs[clr.ScrollbarBg] = im4(0.10, 0.09, 0.12, 1.00)
	clrs[clr.ScrollbarGrab] = im4(0.80, 0.80, 0.83, 0.31)
	clrs[clr.ScrollbarGrabHovered] = im4(0.56, 0.56, 0.58, 1.00)
	clrs[clr.ScrollbarGrabActive] = im4(0.06, 0.05, 0.07, 1.00)
	clrs[clr.ComboBg] = im4(0.19, 0.18, 0.21, 1.00)
	clrs[clr.CheckMark] = im4(1.00, 0.42, 0.00, 0.53)
	clrs[clr.SliderGrab] = im4(1.00, 0.42, 0.00, 0.53)
	clrs[clr.SliderGrabActive] = im4(1.00, 0.42, 0.00, 1.00)
	clrs[clr.Button] = im4(0.10, 0.09, 0.12, 1.00)
	clrs[clr.ButtonHovered] = im4(0.24, 0.23, 0.29, 1.00)
	clrs[clr.ButtonActive] = im4(0.56, 0.56, 0.58, 1.00)
	clrs[clr.Header] = im4(0.10, 0.09, 0.12, 1.00)
	clrs[clr.HeaderHovered] = im4(0.56, 0.56, 0.58, 1.00)
	clrs[clr.HeaderActive] = im4(0.06, 0.05, 0.07, 1.00)
	clrs[clr.ResizeGrip] = im4(0.00, 0.00, 0.00, 0.00)
	clrs[clr.ResizeGripHovered] = im4(0.56, 0.56, 0.58, 1.00)
	clrs[clr.ResizeGripActive] = im4(0.06, 0.05, 0.07, 1.00)
	clrs[clr.CloseButton] = im4(0.40, 0.39, 0.38, 0.16)
	clrs[clr.CloseButtonHovered] = im4(0.40, 0.39, 0.38, 0.39)
	clrs[clr.CloseButtonActive] = im4(0.40, 0.39, 0.38, 1.00)
	clrs[clr.PlotLines] = im4(0.40, 0.39, 0.38, 0.63)
	clrs[clr.PlotLinesHovered] = im4(0.25, 1.00, 0.00, 1.00)
	clrs[clr.PlotHistogram] = im4(0.40, 0.39, 0.38, 0.63)
	clrs[clr.PlotHistogramHovered] = im4(0.25, 1.00, 0.00, 1.00)
	clrs[clr.TextSelectedBg] = im4(0.25, 1.00, 0.00, 0.43)
	clrs[clr.ModalWindowDarkening] = im4(1.00, 0.98, 0.95, 0.73)
end
apply_style()
