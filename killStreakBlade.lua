script_author("Arkananta Studio")
local ev = require 'lib.samp.events'
local s_X, s_Y = getScreenResolution()
local td_Id = 421;
local global_thread;
local current_kills = 0;
local dead_players = {}

local killStreak_str = { 'Down 1 Jack', 'Down 2 Jack', 'Down 3 Jack', 'Down Lagi Jack', 'Noob Jack', 'Monster Kill', 'Unstoppable', 'Wicked Sick', 'Godlike','Hitman','God', 'Most Respected', 'Unreal Shit', 'Bruh Moment', 'You madz?', 'Stop Please', 'Are you God?', 'Extreme Kill', 'Omfg'}
function main()
	repeat wait(0) until isSampAvailable()
	while true do
		wait(0)
		if sampIsLocalPlayerSpawned() then
			sampAddChatMessage("{00FF00}[KillStreak] Script berhasil dimuat!", -1)
			break
		end
	end
	sampTextdrawDelete(td_Id)
	while true do wait(-1) end
end

function ev.onSendSpawn()
	current_kills = 0;
end

function ev.onSendGiveDamage(playerid, damage, amount, weaponid, bodypart)
	if playerid ~= nil and playerid ~= 65535 then
		if not isPlayerDead(PLAYER_HANDLE) and not damage ~= nil then
			hp = sampGetPlayerHealth(playerid)
			newhp = hp - damage
			if newhp == 0 or newhp < 0 then
				
				if not isPlayerAlreadyDead(playerid) then
				
					table.insert(dead_players, playerid)
		
					if global_thread ~= nil then
						thread_status = global_thread:status()
						if thread_status == 'yielded' or thread_status == 'running' then
							global_thread:terminate()
						end
					end
				
					if current_kills >= 19 then current_kills = 14 end
					current_kills = current_kills + 1
				
					createTextdraw(killStreak_str[current_kills])
					
					lua_thread.create(function()
						wait(5000)
						if isPlayerAlreadyDead(playerid) then
							for k,v in pairs(dead_players) do		
								if dead_players[k] == playerid then
									table.remove(dead_players, k)
								end
							end
						end
					end)
				end
			end
		end
	end
end

function isPlayerAlreadyDead(playerid)
    for k,v in pairs(dead_players) do
		if dead_players[k] == playerid then return true end
	end
	return false
end

function createTextdraw(text)
	sampTextdrawCreate(td_Id, text, 322, 110)
	sampTextdrawSetShadow(td_Id,1,0x90000000)
	sampTextdrawSetLetterSizeAndColor(td_Id, 0.4, 1.5, -1)
	sampTextdrawSetAlign(td_Id, 2)
	sampTextdrawSetBoxColorAndSize(td_Id, 0,0, 1000, 500)
	
	global_thread = lua_thread.create(function()
			wait(3000)
			
			for i = 95, 0, -5 do
			color = '0x';
			color = color..i..'FFFFFF';
			
			sampTextdrawSetLetterSizeAndColor(td_Id, 0.4, 1.5, color)
			wait(25)
			
			end
			sampTextdrawDelete(td_Id)
	end)
end