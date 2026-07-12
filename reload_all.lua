script_name('ML-ReloadAll')
script_author("Arkananta Studio")
script_description('Press F3 to reload all lua scripts. Also can be used to load new added scripts')
if script_properties then
	script_properties('work-in-pause', 'forced-reloading-only')
end


--- Main
function main()
  while true do
	wait(40)
	if isKeyDown(114) then -- F3
		while isKeyDown(114) do wait(80) end
		reloadScripts()
	end
  end
end
