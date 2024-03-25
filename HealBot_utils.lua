--==============================================================================
--[[
    Author: Ragnarok.Lorand
    HealBot utility functions that don't belong anywhere else
--]]
--==============================================================================
--          Input Handling Functions
--==============================================================================

utils = {normalize={}}
local lor_res = _libs.lor.resources
local lc_res = lor_res.lc_res
local ffxi = _libs.lor.ffxi
local debuffs_lists = L()

function utils.normalize_str(str)
    return str:lower():gsub(' ', '_'):gsub('%.', '')
end


function utils.normalize_action(action, action_type)
    if istable(action) then return action end
    if action_type == nil then return nil end
    if isstr(action) then
        if tonumber(action) == nil then
            local naction = res[action_type]:with('en', action)
            if naction ~= nil then
                return naction
            end
            return res[action_type]:with('enn', utils.normalize_str(action))
        end
        action = tonumber(action) 
    end
    if isnum(action) then
        return res[action_type][action]
    end
    --atcf("Unable to normalize: '%s'[%s] (%s)", tostring(action), type(action), tostring(action_type))
    return nil
end


function utils.strip_roman_numerals(str)
    --return str:sub(1, str:find('I*V?X?I*V?I*$')):trim()
    return str:match('^%s*(.-)%s*I*V?X?I*V?I*$')
end


--[[
    Add an 'enn' (english, normalized) entry to each relevant resource
--]]
local function normalize_action_names()
    local categories = {'spells', 'job_abilities', 'weapon_skills', 'buffs'}
    for _,cat in pairs(categories) do
        for id,entry in pairs(res[cat]) do
            res[cat][id].enn = utils.normalize_str(entry.en)
            res[cat][id].ja = nil
            res[cat][id].jal = nil
        end
    end
end
normalize_action_names()


local txtbox_cmd_map = {
    moveinfo = 'moveInfo',          actioninfo = 'actionInfo',
    showq = 'actionQueue',          showqueue = 'actionQueue',
    queue = 'actionQueue',          monitored = 'montoredBox',
    showmonitored = 'montoredBox',
}


function utils.is_npc(mob_id)
    local is_pc = mob_id < 0x01000000
    local is_pet = mob_id > 0x01000000 and mob_id % 0x1000 > 0x700

    -- filter out pcs and known pet IDs
    return not is_pc and not is_pet
end

function processCommand(command,...)
    command = command and command:lower() or 'help'
    local args = map(windower.convert_auto_trans, {...})
	local player = windower.ffxi.get_player()
    
    if S{'reload','unload'}:contains(command) then
		windower.send_command(('lua %s %s'):format(command, 'healbot'))
    elseif command == 'refresh' then
	    utils.load_configs()
	elseif S{'show','sh'}:contains(command) then
		if (args[1] and args[1]:lower() == 'party') or not args[1] then
			atc('Party Debuff Table:')
			table.vprint(buffs.debuffList)
		end
		if (args[1] and args[1]:lower() == 'aura') or not args[1] then
			atc('Aura Table:')
			table.vprint(buffs.auras)
		end
		if (args[1] and args[1]:lower() == 'ignore') or not args[1] then
			atc('Ignored Debuff Table:')
			table.vprint(buffs.ignored_debuffs)
		end
		if (args[1] and args[1]:lower() == 'offense') or not args[1] then
			atc('Offense Table:')
			table.vprint(offense.mobs)
		end
		if (args[1] and args[1]:lower() == 'debuff') or not args[1] then
			atc('Offense debuffs table:')
			table.vprint(offense.debuffs)
		end
		if (args[1] and args[1]:lower() == 'dispel') or not args[1] then
			atc('Dispel table:')
			table.vprint(offense.dispel.mobs)
		end
		if (args[1] and args[1]:lower() == 'follow') or not args[1] then
			local targ_value = settings.follow.target or 'NIL'
			atc('Follow target: '..targ_value)
		end
		if (args[1] and args[1]:lower() == 'buffs') or not args[1] then
			atc('Buffs table: ')
			table.vprint(buffs.buffList)
		end
    elseif S{'start','on'}:contains(command) then
        hb.activate()
    elseif S{'stop','end','off'}:contains(command) then
        hb.active = false
        printStatus()
    elseif S{'aoe'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (settings.aoe_na and 'off' or 'resume')
        if S{'off','end','false','pause'}:contains(cmd) then
            settings.aoe_na = false
            atc('AOE is now off.')
        else
            settings.aoe_na = true
			atc('AOE is active.')
        end
	elseif S{'dispel'}:contains(command) then
		local cmd = args[1] and args[1]:lower() or (offense.dispel.active and 'off' or 'resume')
		if S{'off','end','false','pause'}:contains(cmd) then
			offense.dispel.active = false
			atc('Auto Dispel is now off.')
		elseif S{'resume','on'}:contains(cmd) then
			offense.dispel.active = true
			atc('Auto Dispel is now active.')
		elseif cmd == 'ignore' then
			local mob_string = args[2]:lower():capitalize()
			offense.dispel.ignored:add(mob_string)
			atc('Added mob to dispel ignore list: '..mob_string)
		elseif cmd == 'unignore' then
			local mob_string = args[2]:lower():capitalize()
			if offense.dispel.ignored:contains(mob_string) then
				offense.dispel.ignored:remove(mob_string)
				atc('Removed mob from dispel ignore list: '..mob_string)
				local show_dispel_ignore_names = ''
				for k,v in pairs(offense.dispel.ignored) do
					show_dispel_ignore_names = show_dispel_ignore_names..'['..k..']'
				end
				atc('Dispel Ignore List: '..show_dispel_ignore_names)
			else
				atc('Error: Mob not in current list')
			end
		end
    elseif S{'disable'}:contains(command) then
        if not validate(args, 1, 'Error: No argument specified for Disable') then return end
        disableCommand(args[1]:lower(), true)
    elseif S{'enable'}:contains(command) then
        if not validate(args, 1, 'Error: No argument specified for Enable') then return end 
        disableCommand(args[1]:lower(), false)
	 elseif S{'moblist'}:contains(command) then
		local cmd = args[1] and args[1]:lower() or (offense.moblist.active and 'off' or 'resume')
		if S{'off','end','false','pause'}:contains(cmd) then
			offense.moblist.active = false
			atc('Moblist debuffing is now off.')
		elseif S{'resume','on'}:contains(cmd) then
			offense.moblist.active = true
			atc('Moblist debuffing is now active.')
		elseif cmd == 'add' and args[2] then
			local mob_string = args[2]:lower():capitalize()
			offense.moblist.mobs:add(mob_string)
			atc('Added mob to debuff list: '..mob_string)
		elseif cmd == 'remove' and args[2] then
			local mob_string = args[2]:lower():capitalize()
			if offense.moblist.mobs:contains(mob_string) then
				offense.moblist.mobs:remove(mob_string)
				atc('Removed mob from debuff list: '..mob_string)
				local show_moblist_names = ''
				for k,v in pairs(offense.moblist.mobs) do
					show_moblist_names = show_moblist_names..'['..k..']'
				end
				atc('Debuff Mob List: '..show_moblist_names)
			else
				atc('Error: Mob not in current list')
			end
		elseif (cmd == 'show' or cmd == 'list') and offense.moblist.mobs then
			local show_moblist_names = ''
			for k,v in pairs(offense.moblist.mobs) do
				show_moblist_names = show_moblist_names..'['..k..']'
			end
			atc('Debuff Mob List: '..show_moblist_names)
		elseif cmd == 'clear' or cmd == 'reset' then
			offense.moblist.mobs:clear()
			atc('Debuff Mob List cleared')
		else
			atc(123,'Error: No parameter - [add / remove / on / off / clear] specified.')
		end
    elseif S{'assist','as'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (offense.assist.active and 'off' or 'resume')
        if S{'off','end','false','pause'}:contains(cmd) then
            offense.assist.active = false
            atc('Assist is now off.')
        elseif S{'resume'}:contains(cmd) then
            if (offense.assist.name ~= nil) then
                offense.assist.active = true
                atc('Now assisting '..offense.assist.name..'.')
            else
                atc(123,'Error: Unable to resume assist - no target set')
            end
        elseif S{'attack','engage'}:contains(cmd) then
            local cmd2 = args[2] and args[2]:lower() or (offense.assist.engage and 'off' or 'resume')
            if S{'off','end','false','pause'}:contains(cmd2) then
                offense.assist.engage = false
                atc('Will no longer enagage when assisting.')
            else
                if not (offense.assist.nolock) then
                    offense.assist.engage = true
                    atc('Will now enagage when assisting.')
                else
                    offense.assist.engage = false
					atc('ERROR: Cannot engage/attack to assist if using nolock.')
                end
            end
		elseif S{'nolock'}:contains(cmd) then
            local cmd2 = args[2] and args[2]:lower() or (offense.assist.nolock and 'off' or 'resume')
            if S{'off','end','false','pause'}:contains(cmd2) then
                offense.assist.nolock = false
                atc('Will now use target/lock on when assisting.')
            else
				if not (offense.assist.engage) then
					offense.assist.nolock = true
					atc('Will now use mob id to cast spells when assisting.')
				else
					offense.assist.nolock = false
					atc('ERROR: Cannot use nolock/mob id to assist if engaging to attack.')
				end
            end
        elseif S{'sametarget'}:contains(cmd) then
            local cmd2 = args[2] and args[2]:lower() or (offense.assist.sametarget and 'off' or 'resume')
            if S{'off','end','false','pause'}:contains(cmd2) then
                offense.assist.sametarget = false
                atc('Will now NOT switch to the SAME mob when engaged.')
            else
				if not (offense.assist.nolock) and offense.assist.engage then
					offense.assist.sametarget = true
					atc('Will now switch to the same mob when attack/engage to assist.')
				else
					offense.assist.sametarget = false
					atc('ERROR: Cannot use sametarget to attack/engage if using [nolock] or not [attack/engage].')
				end
            end
		elseif S{'job','j'}:contains(cmd) then
			if args[2] then
				offense.register_assistee(args[2],true)
			else
				atc('ERROR: No JOB specified.')
			end
        elseif S{'noapproach'}:contains(cmd) then
            local cmd2 = args[2] and args[2]:lower() or (offense.assist.noapproach and 'off' or 'resume')
            if S{'off','end','false','pause'}:contains(cmd2) then
                offense.assist.noapproach = false
                atc('Will approach mobs when assisting.')
            else
                offense.assist.noapproach = true
                atc('Will no longer approach mobs when assisting. Set the follow dist to .5 to make sure you can reach mobs.')
            end
        elseif S{'mobdistancemin'}:contains(cmd) then -- This isn't working fully yet
            local cmd = tonumber(args[2]) or 2.2
            offense.mobdistancemin = cmd
            atc("Will force mob distance minimum to "..cmd..".")
        elseif S{'mobdistancemax'}:contains(cmd) then -- This isn't working fully yet
            local cmd = tonumber(args[2]) or 24.0
            offense.mobdistancemax = cmd
            atc("Will force mob distance maximum to "..cmd..".")
        elseif S{'forcemobdist'}:contains(cmd) then -- This isn't working fully yet
            local cmd = args[2] and args[2]:lower() or (offense.forcemobdist and 'off' or 'resume')
            if S{'off','end','false','pause'}:contains(cmd) then
                offense.forcemobdist = false
                atc('Will no longer force a mob distance when attacking.')
            else
                offense.forcemobdist = true
                atc('Will force a mob distance when attacking.')
            end
        else    --args[1] is guaranteed to have a value if this is reached
            offense.register_assistee(args[1])
        end

    elseif S{'facetarget'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (offense.alwaysfacetarget and 'off' or 'resume')
        if S{'off','end','false','pause'}:contains(cmd) then
            offense.alwaysfacetarget = false
            atc('Will not forcefully face the target when attacking.')
        else
            offense.alwaysfacetarget = true
            atc('Will forcefully face the target when attacking.')
        end
    elseif S{'ws','weaponskill'}:contains(command) then
        local lte,gte = string.char(0x81, 0x85),string.char(0x81, 0x86)
        local cmd = args[1] and args[1] or ''
        settings.ws = settings.ws or {}
        if (cmd == 'waitfor') then      --another player's TP
            local partner = utils.getPlayerName(args[2])
            if (partner ~= nil) then
                local partnertp = tonumber(args[3]) or 1000
                settings.ws.partner = {name=partner,tp=partnertp}
                atc("Will weaponskill when "..partner.."'s TP is "..gte.." "..partnertp)
            else
                atc(123,'Error: Invalid argument for ws waitfor: '..tostring(args[2]))
            end
        elseif (cmd == 'nopartner') then
            settings.ws.partner = nil
            atc('Weaponskill partner removed.')
        elseif (cmd == 'hp') then       --Target's HP
            local sign = S{'<','>'}:contains(args[2]) and args[2] or nil
            local hp = tonumber(args[3])
            if (sign ~= nil) and (hp ~= nil) then
                settings.ws.sign = sign
                settings.ws.hp = hp
                atc("Will weaponskill when the target's HP is "..sign.." "..hp.."%")
            else
                atc(123,'Error: Invalid arguments for ws hp: '..tostring(args[2])..', '..tostring(args[3]))
            end
        elseif (cmd == 'tp') then      --another player's TP
            local self_tp = tonumber(args[2]) or 1000
            if self_tp < 1000 then
                self_tp = 1000
            end
            if self_tp >  2999 then
                self_tp = 2999
            end

            settings.ws.self_tp = self_tp
            atc("Will weaponskill when TP is "..gte.." "..self_tp)
        elseif (cmd == 'setAM3') then    -- AM3 ws name
            table.remove(args, 1)
            utils.register_AM3_ws(args)
        elseif (cmd == 'keepAM3') then
            local keepAM3 = toboolean(args[2])
            settings.ws.keep_AM3 = keepAM3
            atc("Setting to upkeep AM3 to "..tostring(keepAM3))
        else
            if S{'use','set'}:contains(cmd) then    -- ws name
                table.remove(args, 1)
            end
            utils.register_ws(args)
        end
    elseif S{'spam','nuke'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (settings.spam.active and 'off' or 'on')
        if S{'on','true'}:contains(cmd) then
            settings.spam.active = true
            if (settings.spam.name ~= nil) then
                atc('Action spamming is now on. Action: '..settings.spam.name)
            else
                atc('Action spamming is now on. To set a spell to use: //hb spam use <action>')
            end
        elseif S{'off','false'}:contains(cmd) then
            settings.spam.active = false
            atc('Action spamming is now off.')
        else
            if S{'use','set'}:contains(cmd) then
                table.remove(args, 1)
            end
            utils.register_spam_action(args)
        end
	elseif S{'stymie'}:contains(command) then
		if player.main_job == 'RDM' then
			local cmd = args[1] and args[1]:lower() or (settings.spam.active and 'off' or 'on')
			if S{'on','true'}:contains(cmd) then
				offense.stymie.active = true
				if (offense.stymie.spell ~= '') then
					atc('Stymie is now on. Action: '..offense.stymie.spell)
				else
					atc('Stymie is now on. To set a spell to use: //hb stymie use <action>')
				end
			elseif S{'off','false'}:contains(cmd) then
				offense.stymie.active = false
				atc('Stymie is now off.')
			else
				if S{'use','set'}:contains(cmd) then
					table.remove(args, 1)
				end
				utils.register_stymie(args)
			end
		else
			atc('Error: Not RDM main job')
		end
    elseif S{'debuff', 'db'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (offense.debuffing_active and 'off' or 'on')
        if S{'on','true'}:contains(cmd) then
            offense.debuffing_active = true
            atc('Debuffing is now on.')
        elseif S{'off','false'}:contains(cmd) then
            offense.debuffing_active = false
            atc('Debuffing is now off.')
		elseif S{'bt'}:contains(cmd) then
			local battle_cmd = args[2] and args[2]:lower() or (offense.debuffing_battle_target and 'off' or 'on')
			if S{'on','true'}:contains(battle_cmd) then
				offense.debuffing_active = true
				offense.debuffing_battle_target = true
				atc('WARNING! Debuffing is now set to battle targets.')
			elseif S{'off','false'}:contains(battle_cmd) then
				offense.debuffing_battle_target = false
				atc('DISABLED debuffing on battle targets.')
			end
        elseif S{'rm','remove'}:contains(cmd) then
            utils.register_offensive_debuff(table.slice(args, 2), true)
        elseif S{'ls','list'}:contains(cmd) then
			local debuff_print = ''
			for k,v in pairs(offense.debuffs) do
				debuff_print = debuff_print..offense.debuffs[k].spell.en..','
			end
			atc('Debuffs: '..debuff_print)
        else
            if S{'use','set'}:contains(cmd) then
                table.remove(args, 1)
            end
            utils.register_offensive_debuff(args, false)
        end
	elseif S{'mldebuff', 'mldb'}:contains(command) then
		local cmd = args[1] and args[1]:lower() 
        if S{'rm','remove'}:contains(cmd) then
            utils.register_offensive_debuff(table.slice(args, 2), true, true)
        elseif S{'ls','list'}:contains(cmd) then
            local debuff_print = ''
			for k,v in pairs(offense.moblist.debuffs) do
				debuff_print = debuff_print..offense.moblist.debuffs[k].spell.en..','
			end
			atc('Debuffs for Moblist: '..debuff_print)
        else
            if S{'use','set'}:contains(cmd) then
                table.remove(args, 1)
            end
            utils.register_offensive_debuff(args, false, true)
        end
    elseif command == 'mincure' then
        if not validate(args, 1, 'Error: No argument specified for minCure') then return end
        local val = tonumber(args[1])
        if (val ~= nil) and (1 <= val) and (val <= 6) then
            settings.healing.min.cure = val
            atc('Minimum cure tier set to '..val)
        else
            atc('Error: Invalid argument specified for minCure')
        end
    elseif command == 'mincuraga' then
        if not validate(args, 1, 'Error: No argument specified for minCuraga') then return end
        local val = tonumber(args[1])
        if (val ~= nil) and (1 <= val) and (val <= 6) then
            settings.healing.min.curaga = val
            atc('Minimum curaga tier set to '..val)
        else
            atc('Error: Invalid argument specified for minCuraga')
        end
    elseif command == 'minwaltz' then
        if not validate(args, 1, 'Error: No argument specified for minWaltz') then return end
        local val = tonumber(args[1])
        if (val ~= nil) and (1 <= val) and (val <= 5) then
            settings.healing.min.waltz = val
            atc('Minimum waltz tier set to '..val)
        else
            atc('Error: Invalid argument specified for minWaltz')
        end
    elseif command == 'minwaltzga' then
        if not validate(args, 1, 'Error: No argument specified for minWaltzga') then return end
        local val = tonumber(args[1])
        if (val ~= nil) and (1 <= val) and (val <= 2) then
            settings.healing.min.waltzga = val
            atc('Minimum waltzga tier set to '..val)
        else
            atc('Error: Invalid argument specified for minWaltzga')
        end
    elseif command == 'minblue' then
        if not validate(args, 1, 'Error: No argument specified for minBlue') then return end
        local val = tonumber(args[1])
        if (val ~= nil) and (1 <= val) and (val <= 4) then
            settings.healing.min.blue = val
            atc('Minimum blue tier set to '..val)
        else
            atc('Error: Invalid argument specified for minBlue')
        end
    elseif command == 'minbluega' then
        if not validate(args, 1, 'Error: No argument specified for minBluega') then return end
        local val = tonumber(args[1])
        if (val ~= nil) and (1 <= val) and (val <= 2) then
            settings.healing.min.bluega = val
            atc('Minimum bluega tier set to '..val)
        else
            atc('Error: Invalid argument specified for minBluega')
        end
    elseif command == 'reset' then
        if not validate(args, 1, 'Error: No argument specified for reset') then return end
        local rcmd = args[1]:lower()
        local b,d = false,false
        if S{'all','both'}:contains(rcmd) then
            b,d = true,true
        elseif (rcmd == 'buffs') then
            b = true
        elseif (rcmd == 'debuffs') then
            d = true
        else
            atc('Error: Invalid argument specified for reset: '..arg[1])
            return
        end
        
        local resetTarget
        if (args[2] ~= nil) and (args[3] ~= nil) and (args[2]:lower() == 'on') then
            local pname = utils.getPlayerName(args[3])
            if (pname ~= nil) then
                resetTarget = pname
            else
                atc(123,'Error: Invalid name provided as a reset target: '..tostring(args[3]))
                return
            end
        end
        resetTarget = resetTarget or 'ALL' 
        local rtmsg = resetTarget or 'all monitored players'
        if b then
            buffs.resetBuffTimers(resetTarget)
            atc(('Buff timers for %s were reset.'):format(rtmsg))
        end
        if d then
            buffs.resetDebuffTimers(resetTarget)
            atc(('Debuffs detected for %s were reset.'):format(rtmsg))
        end
    elseif command == 'buff' then
        buffs.registerNewBuff(args, true)
	elseif command == 'buffjob' then
	    buffs.registerNewBuff(args, true, true)
    elseif S{'cancelbuff','nobuff'}:contains(command) then
        buffs.registerNewBuff(args, false)
	elseif S{'cancelbuffjob','nobuffjob'}:contains(command) then
        buffs.registerNewBuff(args, false, true)
    elseif S{'bufflist','bl'}:contains(command) then
        if not validate(args, 1, 'Error: No argument specified for BuffList') then return end
        utils.apply_bufflist(args)
    elseif command == 'bufflists' then
        pprint(hb.config.buff_lists)
    elseif command == 'ignore_debuff' then
        buffs.registerIgnoreDebuff(args, true)
    elseif command == 'unignore_debuff' then
        buffs.registerIgnoreDebuff(args, false)
    elseif S{'debufflist','debl'}:contains(command) then
        if not validate(args, 1, 'Error: No argument specified for DebuffList') then return end
        utils.apply_debufflist(args)
    elseif S{'follow','f'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (settings.follow.active and 'off' or 'resume')
        if S{'off','end','false','pause','stop','exit'}:contains(cmd) then
			atc('Follow is now off.')
            settings.follow.active = false
			settings.follow.target = nil
        elseif S{'distance', 'dist', 'd'}:contains(cmd) then
            local dist = tonumber(args[2])
            if (dist ~= nil) and (0 < dist) and (dist < 45) then
                settings.follow.distance = dist
                atc('Follow distance set to '..settings.follow.distance)
            else
                atc('Error: Invalid argument specified for follow distance')
            end
        elseif S{'resume'}:contains(cmd) then
            if (settings.follow.target ~= nil) then
                settings.follow.active = true
                atc('Now following '..settings.follow.target..'.')
            else
                atc(123,'Error: Unable to resume follow - no target set')
            end
		elseif S{'job', 'j'}:contains(cmd) then
		    local pname = utils.getPlayerNameFromJob(args[2])
			if (pname ~= nil) then
                settings.follow.target = pname
                settings.follow.active = true
                atc('Now following '..settings.follow.target..'.')
            else
                atc(123,'Error: Invalid JOB provided as a follow target: '..tostring(args[2]))
            end
        else    --args[1] is guaranteed to have a value if this is reached
            local pname = utils.getPlayerName(args[1])
            if (pname ~= nil) then
                settings.follow.target = pname
                settings.follow.active = true
                atc('Now following '..settings.follow.target..'.')
            else
                atc(123,'Error: Invalid name provided as a follow target: '..tostring(args[1]))
            end
        end
    elseif S{'ignore', 'unignore', 'watch', 'unwatch'}:contains(command) then
        monitorCommand(command, args[1])
	elseif command == 'watchall' then
        if watchall == false then
            watchall = true
            atc(123,'Watch all parties set to true.')
        elseif watchall == true then
            watchall = false
            atc(123,'Watch all parties set to false.')
        end
	elseif S{'showdebuff'}:contains(command) then
		local cmd = args[1] and args[1]:lower() or (hb.showdebuff and 'off' or 'on')
        if S{'on','true'}:contains(cmd) then
            hb.showdebuff = true
            atc('Debuff List is displayed.')
			hb.txts.debuffList:visible(true)
        elseif S{'off','false'}:contains(cmd) then
            hb.showdebuff = false
			hb.txts.debuffList:visible(false)
            atc('Debuff List is hidden.')
		end
	elseif S{'automp'}:contains(command) then
		local cmd = args[1] and args[1]:lower() or (hb.autoRecoverMPMode and 'off' or 'on')
        if S{'on','true'}:contains(cmd) then
            hb.autoRecoverMPMode = true
            atc('Auto Recover MP [Coalition Ether] is ON.')
        elseif S{'off','false'}:contains(cmd) then
			hb.autoRecoverMPMode = false
            atc('Auto Recover MP [Coalition Ether] is OFF.')
		end
	elseif S{'autohp'}:contains(command) then
		local cmd = args[1] and args[1]:lower() or (hb.autoRecoverHPMode and 'off' or 'on')
        if S{'on','true'}:contains(cmd) then
            hb.autoRecoverHPMode = true
            atc('Auto Recover HP [Vile Elixir] is ON.')
        elseif S{'off','false'}:contains(cmd) then
			hb.autoRecoverHPMode = false
            atc('Auto Recover HP [Vile Elixir] is OFF.')
		end
    elseif command == 'ignoretrusts' then
        utils.toggleX(settings, 'ignoreTrusts', args[1], 'Ignoring of Trust NPCs', 'IgnoreTrusts')
    elseif command == 'packetinfo' then
        toggleMode('showPacketInfo', args[1], 'Packet info display', 'PacketInfo')
    elseif command == 'debug' then
        toggleMode('debug', args[1], 'Debug mode', 'debug mode')
    elseif S{'ind','inde','independent'}:contains(command) then
        toggleMode('independent', args[1], 'Independent mode', 'independent mode')
    elseif S{'autoshadows','shadows'}:contains(command) then
        local cmd = args[1] and args[1]:lower() or (offense.assist.active and 'off' or 'resume')
        if S{'off','end','false','pause'}:contains(cmd) then
            settings.autoshadows = false
            atc('Autoshadows is now off.')
        elseif S{'resume','on'}:contains(cmd) then
            settings.autoshadows = true
            atc('Autoshadows is now on.')
        end
    elseif S{'deactivateindoors','deactivate_indoors'}:contains(command) then
        utils.toggleX(settings, 'deactivateIndoors', args[1], 'Deactivation in indoor zones', 'DeactivateIndoors')
    elseif S{'activateoutdoors','activate_outdoors'}:contains(command) then
        utils.toggleX(settings, 'activateOutdoors', args[1], 'Activation in outdoor zones', 'ActivateOutdoors')
    elseif txtbox_cmd_map[command] ~= nil then
        local boxName = txtbox_cmd_map[command]
        if utils.posCommand(boxName, args) then
            utils.refresh_textBoxes()
        else
            utils.toggleVisible(boxName, args[1])
        end
    elseif S{'customsettings','custom'}:contains(command) then
        if not validate(args, 1, 'Error: No argument specified for Custom Settings') then return end
        utils.apply_custom_settings(args)
    elseif S{'help','--help'}:contains(command) then
        help_text()
    elseif command == 'settings' then
        for k,v in pairs(settings) do
            local kstr = tostring(k)
            local vstr = (type(v) == 'table') and tostring(T(v)) or tostring(v)
            atc(kstr:rpad(' ',15)..': '..vstr)
        end
    elseif command == 'status' then
        printStatus()
    elseif command == 'info' then
        if not _libs.lor.exec then
            atc(3,'Unable to parse info.  Windower/addons/libs/lor/lor_exec.lua was unable to be loaded.')
            atc(3,'If you would like to use this function, please visit https://github.com/zpaav/lor_libs/ to download it.')
            return
        end
        local cmd = args[1]     --Take the first element as the command
        table.remove(args, 1)   --Remove the first from the list of args
        _libs.lor.exec.process_input(cmd, args)
    else
        atc('Error: Unknown command')
    end
end


local function _get_player_id(player_name)
    local player_mob = windower.ffxi.get_mob_by_name(player_name)
    if player_mob then
        return player_mob.id
    end
    return nil
end
utils.get_player_id = _libs.lor.advutils.scached(_get_player_id)


function utils.register_offensive_debuff(args, cancel, mob_debuff_list_flag)
    local argstr = table.concat(args,' ')
    local snames = argstr:split(',')
    for index,sname in pairs(snames) do
        if (tostring(index) ~= 'n') then
            if sname:lower() == 'all' and cancel then
				if mob_debuff_list_flag then
				atcf(123,'Removing all debuffs from moblist debuff list.')
					for k,v in pairs(offense.moblist.debuffs) do
						atcf('Removing debuff: ' ..offense.moblist.debuffs[k].spell.enn)
						offense.moblist.debuffs[k] = nil
					end
				else
					atcf(123,'Removing all debuffs on mobs.')
					for k,v in pairs(offense.debuffs) do
						atcf('Removing debuff: ' ..offense.debuffs[k].spell.enn)
						offense.debuffs[k] = nil
					end
				end
            else
                local spell_name = utils.formatActionName(sname:trim())
                local spell = lor_res.action_for(spell_name)
                if (spell ~= nil) then
                    if healer:can_use(spell) then
						if mob_debuff_list_flag then
							offense.maintain_debuff(spell, cancel, true)
						else
							offense.maintain_debuff(spell, cancel)
						end
                    else
                        atcfs(123,'Error: Unable to cast %s', spell.en)
                    end
                else
                    atcfs(123,'Error: Invalid spell name: %s', spell_name)
                end
            end
        end
    end
end

function utils.register_stymie(args)
    local argstr = table.concat(args,' ')
    local action_name = utils.formatActionName(argstr)
    local action = lor_res.action_for(action_name)
    if (action ~= nil) then
        if healer:can_use(action) then
            offense.stymie.spell = action.en
			offense.maintain_debuff(action, false)
            atc('Will now use Stymie with spell: ', offense.stymie.spell)
        else
            atc(123,'Error: Unable to cast: ', action.en)
        end
    else
        atc(123,'Error: Invalid action name: ', action_name)
    end
end

function utils.register_spam_action(args)
    local argstr = table.concat(args,' ')
    local action_name = utils.formatActionName(argstr)
    local action = lor_res.action_for(action_name)
    if (action ~= nil) then
        if healer:can_use(action) then
            settings.spam.name = action.en
            atcfs('Will now spam %s', settings.spam.name)
        else
            atcfs(123,'Error: Unable to cast %s', action.en)
        end
    else
        atcfs(123,'Error: Invalid action name: %s', action_name)
    end
end


function utils.register_ws(args)
    local argstr = table.concat(args,' ')
    local wsname = utils.formatActionName(argstr)
    local ws = lor_res.action_for(wsname)
    if (ws ~= nil) then
        settings.ws.name = ws.en
        atcfs('Will now use %s', ws.en)
    else
        atcfs(123,'Error: Invalid weaponskill name: %s', wsname)
    end
end

function utils.register_AM3_ws(args)
    local argstr = table.concat(args,' ')
    local wsname = utils.formatActionName(argstr)
    local ws = lor_res.action_for(wsname)
    if (ws ~= nil) then
        settings.ws.AM3_name = ws.en
        atcfs('Will now use %s for AM3', ws.en)
    else
        atcfs(123,'Error: Invalid weaponskill name: %s', wsname)
    end
end

function utils.apply_bufflist(args)
    local mj = windower.ffxi.get_player().main_job
    local sj = windower.ffxi.get_player().sub_job
    local job = ('%s/%s'):format(mj, sj)
    local bl_name = args[1]
    local bl_target = args[2]
    if bl_target == nil and bl_name == 'self' then
        bl_target = 'me'
    end
    local buff_list = table.get_nested_value(hb.config.buff_lists, {job, job:lower(), mj, mj:lower()}, bl_name)
    
    buff_list = buff_list or hb.config.buff_lists[bl_name]
    if buff_list ~= nil then
        for _,buff in pairs(buff_list) do
            buffs.registerNewBuff({bl_target, buff}, true)
        end
    else
        atc('Error: Invalid argument specified for BuffList: '..bl_name)
    end
end

function utils.apply_custom_settings(args)
    local self = windower.ffxi.get_player().name
    local mj = windower.ffxi.get_player().main_job
    local sj = windower.ffxi.get_player().sub_job
    local job = ('%s/%s'):format(mj, sj)
    local custom_settings_name = args[1]
    local party = windower.ffxi.get_party()
    local custom_settings= table.get_nested_value(hb.config.custom_settings, {job, job:lower(), mj, mj:lower()}, custom_settings_name)

    custom_settings = custom_settings or hb.config.custom_settings[custom_settings_name]
    if custom_settings ~= nil then
        for key, value in pairs(custom_settings) do
            if key == 'independent' then
                hb.modes.independent = custom_settings['independent']
            elseif key == 'autoshadows' then
                settings.autoshadows = custom_settings['autoshadows']
            elseif key == 'assist' then
                offense.assist.active =  custom_settings['assist']
            elseif key == 'assistName' then
                offense.assist.name =  custom_settings['assistName']
            elseif key == 'assistEngage' then
                offense.assist.engage  = custom_settings['assistEngage']
            elseif key == 'noapproach' then
                offense.assist.noapproach = custom_settings['noapproach']
            elseif key == 'sametarget' then
                offense.assist.sametarget = custom_settings['sametarget']
            elseif key == 'follow' then
                settings.follow.active = custom_settings['follow']
            elseif key == 'followTarget' then
                settings.follow.target = custom_settings['followTarget']
            elseif key == 'followDist' then
                settings.follow.distance = custom_settings['followDist']
            elseif key == 'keep_AM3' then
                settings.ws.keep_AM3  = custom_settings['keep_AM3']
            elseif key == 'AM3_name' then
                settings.ws.AM3_name  = custom_settings['AM3_name']
            elseif key == 'useWeaponSkill' then
                settings.ws.name = custom_settings['useWeaponSkill']
            elseif key == 'useWeaponSkillTP' then
                settings.ws.self_tp = custom_settings['useWeaponSkillTP']
            elseif key == 'applySelfBuffList' then
                utils.apply_bufflist({custom_settings['applySelfBuffList'], self})
            elseif key == 'applyP1BuffList' then
                if party.p1 ~= nil then
                    utils.apply_bufflist({custom_settings['applyP1BuffList'], party.p1.name})
                end
            elseif key == 'applyP2BuffList' then
                if party.p2 ~= nil then
                    utils.apply_bufflist({custom_settings['applyP2BuffList'], party.p2.name})
                end
            elseif key == 'applyP3BuffList' then
                if party.p3 ~= nil then
                    utils.apply_bufflist({custom_settings['applyP3BuffList'], party.p3.name})
                end
            elseif key == 'applyP4BuffList' then
                if party.p4 ~= nil then
                    utils.apply_bufflist({custom_settings['applyP4BuffList'], party.p4.name})
                end
            elseif key == 'applyP5BuffList' then
                if party.p5 ~= nil then
                    utils.apply_bufflist({custom_settings['applyP5BuffList'], party.p5.name})
                end
            elseif key == 'useDebuffs' then
                offense.debuffing_active = custom_settings['useDebuffs']
            elseif key == 'applyDebuffList' then
                utils.apply_debufflist({custom_settings['applyDebuffList']})
            elseif key == 'ignoreTrusts' then
                settings.ignoreTrusts  = custom_settings['ignoreTrusts']
            end
        end
    else
        atc('Error: Invalid argument specified for Custom Settings: '..custom_settings_name)
    end
end

function utils.posCommand(boxName, args)
    if (args[1] == nil) or (args[2] == nil) then return false end
    local cmd = args[1]:lower()
    if not S{'pos','posx','posy'}:contains(cmd) then
        return false
    end
    local x,y = tonumber(args[2]),tonumber(args[3])
    if (cmd == 'pos') then
        if (x == nil) or (y == nil) then return false end
        settings.textBoxes[boxName].x = x
        settings.textBoxes[boxName].y = y
    elseif (cmd == 'posx') then
        if (x == nil) then return false end
        settings.textBoxes[boxName].x = x
    elseif (cmd == 'posy') then
        if (y == nil) then return false end
        settings.textBoxes[boxName].y = y
    end
    return true
end

function utils.toggleVisible(boxName, cmd)
    cmd = cmd and cmd:lower() or (settings.textBoxes[boxName].visible and 'off' or 'on')
    if (cmd == 'on') then
        settings.textBoxes[boxName].visible = true
    elseif (cmd == 'off') then
        settings.textBoxes[boxName].visible = false
    else
        atc(123,'Invalid argument for changing text box settings: '..cmd)
    end
end

function utils.toggleX(tbl, field, cmd, msg, msgErr)
    if (tbl[field] == nil) then
        atcf(123, 'Error: Invalid mode to toggle: %s', field)
        return
    end
    cmd = cmd and cmd:lower() or (tbl[field] and 'off' or 'on')
    if (cmd == 'on') then
        tbl[field] = true
        atc(msg..' is now on.')
    elseif (cmd == 'off') then
        tbl[field] = false
        atc(msg..' is now off.')
    else
        atc(123,'Invalid argument for '..msgErr..': '..cmd)
    end
end

function toggleMode(mode, cmd, msg, msgErr)
    utils.toggleX(hb.modes, mode, cmd, msg, msgErr)
    _libs.lor.debug = hb.modes.debug
end

function disableCommand(cmd, disable)
    local msg = ' is now '..(disable and 'disabled.' or 're-enabled.')
    if S{'cure','cures','curing'}:contains(cmd) then
        if (not disable) then
            if (settings.maxCureTier == 0) then
                settings.disable.cure = true
                atc(123,'Error: Unable to enable curing because you have no Cure spells available.')
                return
            end
        end
        settings.disable.cure = disable
        atc('Curing'..msg)
    elseif S{'curaga'}:contains(cmd) then
        settings.disable.curaga = disable
        atc('Curaga use'..msg)
    elseif S{'na','heal_debuff','cure_debuff'}:contains(cmd) then
        settings.disable.na = disable
        atc('Removal of status effects'..msg)
	elseif S{'erase'}:contains(cmd) then
		settings.disable.erase = disable
		atc('Erase status effects'..msg)
    elseif S{'buff','buffs','buffing'}:contains(cmd) then
        settings.disable.buff = disable
        atc('Buffing'..msg)
    elseif S{'debuff','debuffs','debuffing'}:contains(cmd) then
        settings.disable.debuff = disable
        atc('Debuffing'..msg)
    elseif S{'spam','nuke','nukes','nuking'}:contains(cmd) then
        settings.disable.spam = disable
        atc('Spamming'..msg)
    elseif S{'ws','weaponskill','weaponskills','weaponskilling'}:contains(cmd) then
        settings.disable.ws = disable
        atc('Weaponskilling'..msg)
    else
        atc(123,'Error: Invalid argument for disable/enable: '..cmd)
    end
end

function monitorCommand(cmd, pname)
    if (pname == nil) then
        atc('Error: No argument specified for '..cmd)
        return
    end
    local name = utils.getPlayerName(pname)
    if cmd == 'ignore' then
        if (not hb.ignoreList:contains(name)) then
            hb.ignoreList:add(name)
            atc('Will now ignore '..name)
            if hb.extraWatchList:contains(name) then
                hb.extraWatchList:remove(name)
            end
        else
            atc('Error: Already ignoring '..name)
        end
    elseif cmd == 'unignore' then
        if (hb.ignoreList:contains(name)) then
            hb.ignoreList:remove(name)
            atc('Will no longer ignore '..name)
        else
            atc('Error: Was not ignoring '..name)
        end
    elseif cmd == 'watch' then
        if (not hb.extraWatchList:contains(name)) then
            hb.extraWatchList:add(name)
            atc('Will now watch '..name)
            if hb.ignoreList:contains(name) then
                hb.ignoreList:remove(name)
            end
        else
            atc('Error: Already watching '..name)
        end
    elseif cmd == 'unwatch' then
        if (hb.extraWatchList:contains(name)) then
            hb.extraWatchList:remove(name)
            atc('Will no longer watch '..name)
        else
            atc('Error: Was not watching '..name)
        end
    end
end

function validate(args, numArgs, message)
    for i = 1, numArgs do
        if (args[i] == nil) then
            atc(message..' ('..i..')')
            return false
        end
    end
    return true
end

function utils.getPlayerName(name)
    local target = ffxi.get_target(name)
    if target ~= nil then
        return target.name
    end
    return nil
end

function utils.getPlayerNameFromJob(job)
	local target
	for k, v in pairs(windower.ffxi.get_party()) do
		if type(v) == 'table' and v.mob ~= nil and v.mob.in_party then
			if ((job:lower() == 'tank' and S{'PLD','RUN'}:contains(get_registry(v.mob.id))) or (job:lower() ~= 'tank' and get_registry(v.mob.id):lower() == job:lower())) then
				target = v.name
			end
		end
	end
    if target ~= nil then
        return target
    end
    return nil
end

function num_strats()
    local p = windower.ffxi.get_player()
    local sch_level = 0
    if p.main_job == "SCH" then
        sch_level = p.main_job_level
    elseif healer.sub_job == "SCH" then
        sch_level = p.sub_job_level
    end
    if sch_level == 0 then return 0 end

    if sch_level < 30 then return 1
    elseif sch_level < 50 then return 2
    elseif sch_level < 70 then return 3
    elseif sch_level < 90 then return 4
    elseif p.job_points.sch.jp_spent < 550 then return 5
    else return 6 end
end

function healer_has_buffs(buffs)
    local buff_list = windower.ffxi.get_player().buffs
    for _,bid in pairs(buff_list) do
        if buffs:contains(bid) then
            return true
        end
    end
    return false
end

function utils.isMonster(mob_index)
	local mob_in_question = windower.ffxi.get_mob_by_index(mob_index)
	if mob_in_question and mob_in_question.is_npc and mob_in_question.spawn_type == 16 and mob_in_question.valid_target then
		return true
	end
end

function utils.check_claim_id(id)
	for k, v in pairs(windower.ffxi.get_party()) do
		if type(v) == 'table' then
			if id and v.mob and v.mob.id == id then
				return true
			end
		end
	end
	return false
end

function utils.ready_to_use(action)
    if light_strategems:contains(action.en) then
        if not healer_has_buffs(light_arts) then return false end

        local strats = num_strats()
        if strats < 1 then return false end 

        local rc = windower.ffxi.get_ability_recasts()[action.recast_id]
        return rc <= (4 * 60) / strats * (strats - 1)
    elseif dark_strategems:contains(action.en) then
        if not healer_has_buffs(dark_arts) then return false end

        local strats = num_strats()
        if strats < 1 then return false end 

        local rc = windower.ffxi.get_ability_recasts()[action.recast_id]
        return rc <= (4 * 60) / strats * (strats - 1)
    else
        return healer:ready_to_use(action)
    end
end

function utils.debuffs_disp()
	debuffs_lists = L()
	if next(offense.mobs) ~= nil or next(offense.dispel.mobs) ~= nil then
		if next(offense.mobs) ~= nil then
			local t_target = windower.ffxi.get_mob_by_target('t') or nil
			local tindex = 0
			for mob_id,debuff_table in pairs(offense.mobs) do
				tindex = utils.get_mob_index(debuff_table)
				local claim_target = tindex and windower.ffxi.get_mob_by_index(tindex) and windower.ffxi.get_mob_by_index(tindex).claim_id or nil
				if (utils.check_claim_id(claim_target)) or (t_target and t_target.valid_target and t_target.is_npc and t_target.spawn_type == 16 and t_target.id == mob_id) then
					utils.debuff_display_builder(debuff_table,true,false,mob_id,tindex)
					if next(offense.dispel.mobs) ~= nil then
						if offense.dispel.mobs[mob_id] then
							utils.debuff_display_builder(offense.dispel.mobs[mob_id],false,true,mob_id)
						end
					end
				end
			end
		end
		-- If just dispel buffs
		if next(offense.dispel.mobs) ~= nil then
			local t_target = windower.ffxi.get_mob_by_target('t') or nil
			local tindex = 0
			for mob_id,dispel_table in pairs(offense.dispel.mobs) do
				tindex = utils.get_mob_index(dispel_table)
				local claim_target = tindex and windower.ffxi.get_mob_by_index(tindex) and windower.ffxi.get_mob_by_index(tindex).claim_id or nil
				if not offense.mobs[mob_id] and ((utils.check_claim_id(claim_target)) or (t_target and t_target.valid_target and t_target.is_npc and t_target.spawn_type == 16 and t_target.id == mob_id)) then
					utils.debuff_display_builder(dispel_table,true,true,mob_id,tindex)
				end
			end
		end
	end
    hb.txts.debuffList:text(getPrintable(debuffs_lists))
    hb.txts.debuffList:visible(settings.textBoxes.debuffList.visible)
end

function utils.debuff_display_builder(d_table, name, dispel, mob_id, mob_index)
	local count = 0
	local colorOrange = "\\cs(255,165,0)"
	local colorRed = "\\cs(255,50,0)"
	local formattedMessage = ""
	local mob_claim_name = ""

	for _,v in pairs(d_table) do
		if count == 0 and name then
			local claim_target = windower.ffxi.get_mob_by_index(mob_index) and windower.ffxi.get_mob_by_index(mob_index).claim_id or nil
			if utils.check_claim_id(claim_target) then
				mob_claim_name = string.format("%s%s\\cr", colorRed, v.mob_name)
				if d_table[0] then
					debuffs_lists:append('['..mob_claim_name..'] - '..mob_id..' - '..string.format(os.date('%M:%S',os.time()-d_table[0].landed)))
				else
					debuffs_lists:append('['..mob_claim_name..'] - '..mob_id)
				end
			else
				if d_table[0] then
					debuffs_lists:append('['..v.mob_name..'] - '..mob_id..' - '..string.format(os.date('%M:%S',os.time()-d_table[0].landed)))
				else
					debuffs_lists:append('['..v.mob_name..'] - '..mob_id)
				end
			end
		end
		if dispel then
			formattedMessage = string.format("%s%s\\cr", colorOrange, v.debuff_name)
			debuffs_lists:append(formattedMessage.." : "..string.format(os.date('%M:%S',os.time()-v.landed)))
		else
			if v.spell_name ~= "KO" then
				debuffs_lists:append(v.spell_name.." : "..string.format(os.date('%M:%S',os.time()-v.landed)))
			end
		end
		count = count +1
	end
end

function utils.get_mob_index(s_table)
	for _,v in pairs(s_table) do
		if v.mob_index then
			return v.mob_index
		end
	end
	return nil
end

function utils.check_debuffs_timer()
	if next(offense.mobs) == nil then return end
	for mob_id,debuff_table in pairs(offense.mobs) do
		for k,v in pairs(debuff_table) do
			if maximum_debuff_timers[v.spell_id] then
				local now = os.time()
				if now-debuff_table[k].landed >= maximum_debuff_timers[v.spell_id] then
					offense.mobs[mob_id][k] = nil
				end
			end
		end
	end
end

function utils.toggle_disp()
	local toggle_list = L()
	
    local header_toggle = '\\cs(0,255,0)Healbot\\cr'
	toggle_list:append(('<<%s>>'):format(header_toggle))

    if hb.modes.independent then
        local independent_toggle = hb.modes.independent and '\\cs(0,255,0)[ON]\\cr' or '\\cs(255,0,0)[OFF]\\cr'
	    toggle_list:append(('[Independent Mode]: %s'):format(independent_toggle))
    end

    if hb.autoRecoverHPMode then 
        local hp_toggle = hb.autoRecoverHPMode and '\\cs(0,0,255)[ON]\\cr' or '\\cs(255,0,0)[OFF]\\cr'
	    toggle_list:append(('[Auto HP]: %s'):format(hp_toggle))
    end
    if hb.autoRecoverMPMode then 
	    local mp_toggle = hb.autoRecoverMPMode and '\\cs(0,0,255)[ON]\\cr' or '\\cs(255,0,0)[OFF]\\cr'
	    toggle_list:append(('[Auto MP]: %s'):format(mp_toggle))
    end

    if settings.follow.target then 
        local follow_toggle = settings.follow.target and '\\cs(0,255,0)['..settings.follow.target..']\\cr' or '\\cs(255,0,0)[None]\\cr'
	    toggle_list:append(('[Following]: %s'):format(follow_toggle))

        local followDist_toggle = settings.follow.distance and '\\cs(0,255,0)['..settings.follow.distance..']\\cr' or '\\cs(255,0,0)[None]\\cr'
	    toggle_list:append(('[Follow Dist]: %s'):format(followDist_toggle))
    end

    if offense.assist.name then 
        local assist_toggle = offense.assist.name and '\\cs(0,255,0)['..offense.assist.name..']\\cr' or '\\cs(255,0,0)[None]\\cr'
	    toggle_list:append(('[Assisting]: %s'):format(assist_toggle))

        local assistEngage_toggle = offense.assist.engage and '\\cs(0,255,0)[ON]\\cr' or '\\cs(255,0,0)[OFF]\\cr'
	    toggle_list:append(('[Engaging Mob]: %s'):format(assistEngage_toggle))

        local sametarget_toggle = offense.assist.sametarget and '\\cs(0,255,0)[ON]\\cr' or '\\cs(255,0,0)[OFF]\\cr'
	    toggle_list:append(('[Same Target]: %s'):format(sametarget_toggle))

        local approach_toggle = offense.assist.noapproach and '\\cs(255,0,0)[False]\\cr' or '\\cs(0,255,0)[True]\\cr'
	    toggle_list:append(('[Approaching Mob]: %s'):format(approach_toggle))
    end

    if settings.ws.name then 
        local weaponSkill_toggle = settings.ws.name and '\\cs(0,255,0)['..settings.ws.name..']\\cr' or '\\cs(255,0,0)[None]\\cr'
        toggle_list:append(('[Using Weaponskill]: %s'):format(weaponSkill_toggle))

        local weaponSkillTP_toggle = settings.ws.self_tp and '\\cs(0,255,0)['..settings.ws.self_tp..']\\cr' or '\\cs(255,0,0)[1000]\\cr'
        toggle_list:append(('[Weaponskill TP]: %s'):format(weaponSkillTP_toggle))
        
        local weaponSkillHP_toggle = (settings.ws.sign and settings.ws.hp) and '\\cs(0,255,0)['..settings.ws.sign..' '..settings.ws.hp..']\\cr' or '\\cs(255,0,0)[> 0]\\cr'
        toggle_list:append(('[Weaponskill HP]: %s'):format(weaponSkillHP_toggle))
    end

    if settings.ws.keep_AM3 then 
        local weaponSkillAM3_toggle = settings.ws.AM3_name and '\\cs(0,255,0)['..settings.ws.AM3_name..']\\cr' or '\\cs(255,0,0)[None]\\cr'
        toggle_list:append(('[Using AM3 Weaponskill]: %s'):format(weaponSkillAM3_toggle))
    end

    if settings.autoshadows then 
        local autoshadows_toggle = settings.autoshadows and '\\cs(0,255,0)[ON]\\cr' or '\\cs(255,0,0)[Off]\\cr'
	    toggle_list:append(('[Autoshadows]: %s'):format(autoshadows_toggle))
    end

    hb.txts.toggleList:text(getPrintable(toggle_list))
    hb.txts.toggleList:visible(settings.textBoxes.toggleList.visible)
end

function utils.haveItem(item_id)
	for bag in T(__bags.usable):it() do
		for item, index in T(windower.ffxi.get_items(bag.id)):it() do
			if type(item) == 'table' and item.id == item_id then
				return true
			end
		end
	end
	return false
end

function utils.check_recovery_item()
	if (not hb.autoRecoverMPMode) and (not hb.autoRecoverHPMode) then return false end

	if hb.autoRecoverHPMode and not moving and windower.ffxi.get_player().vitals.hpp < 30 then
		if utils.haveItem(4175) then
			atc(123,'HP LOW: Vile Elixir +1')
			windower.chat.input('/item "Vile Elixir +1" <me>')
			return true
		elseif utils.haveItem(4174) then
			atc(123,'HP LOW: Vile Elixir')
			windower.chat.input('/item "Vile Elixir" <me>')
			return true
		end
	end
	
	if hb.autoRecoverMPMode and not moving and windower.ffxi.get_player().vitals.mpp < 25 then
		if utils.haveItem(5987) then
			atc(123,'MP LOW: Coalition Ether')
			windower.chat.input('/item "Coalition Ether" <me>')
			return true
		end
	end
	return false
end

--==============================================================================
--          String Formatting Functions
--==============================================================================

function utils.formatActionName(text)
    if (type(text) ~= 'string') or (#text < 1) then return nil end
    
    local fromAlias = hb.config.aliases[text]
    if (fromAlias ~= nil) then
        return fromAlias
    end
    
    local spell_from_lc = lc_res.spells[text:lower()]
    if spell_from_lc ~= nil then
        return spell_from_lc.en
    end
    
    local parts = text:split(' ')
    if #parts >= 2 then
        local name = formatName(parts[1])
        for p = 2, #parts do
            local part = parts[p]
            local tier = toRomanNumeral(part) or part:upper()
            if (roman2dec[tier] == nil) then
                name = name..' '..formatName(part)
            else
                name = name..' '..tier
            end
        end
        return name
    else
        local name = formatName(text)
        local tier = text:sub(-1)
        local rnTier = toRomanNumeral(tier)
        if (rnTier ~= nil) then
            return name:sub(1, #name-1)..' '..rnTier
        else
            return name
        end
    end
end

function formatName(text)
    if (text ~= nil) and (type(text) == 'string') then
        return text:lower():ucfirst()
    end
    return text
end

function toRomanNumeral(val)
    if type(val) ~= 'number' then
        if type(val) == 'string' then
            val = tonumber(val)
        else
            return nil
        end
    end
    return dec2roman[val]
end


function toboolean(str)
    local bool = false
    if str == "true" then
        bool = true
    end
    return bool
end

--==============================================================================
--          Output Handling Functions
--==============================================================================

function printStatus()
    windower.add_to_chat(1, 'HB is now '..(hb.active and 'active' or 'off')..'.')
end

--==============================================================================
--          Initialization Functions
--==============================================================================

function utils.load_configs()
    local defaults = {
        textBoxes = {
            actionQueue={x=-125,y=300,font='Arial',size=10,visible=true},
            moveInfo={x=0,y=18,visible=false},
            actionInfo={x=0,y=0,visible=true},
            montoredBox={x=-150,y=600,font='Arial',size=10,visible=true}
        },
        spam = {name='Stone'},
        healing = {
            min={
                cure=3,
                curaga=1,
                waltz=2,
                waltzga=1,
                blue=1,
                bluega=1
            },
            curaga_min_targets=2
        },
        disable = {curaga=false},
        ignoreTrusts=true, 
        deactivateIndoors=true, 
        activateOutdoors=false
    }
    local loaded = lor_settings.load('data/settings.lua', defaults)
    utils.update_settings(loaded)
    utils.refresh_textBoxes()
    
    local cure_potency_defaults = {
        cure = {94,207,469,880,1110,1395},  curaga = {150,313,636,1125,1510},
        waltz = {157,325,581,887,1156},     waltzga = {160,521},
		blue = {288,762,1072},				bluega = {300,885},
    }
    local buff_lists_defaults = {       self = {'Haste II','Refresh II'},
        whm = {self={'Haste','Refresh'}}, rdm = {self={'Haste II','Refresh II'}}
    }
    
    local debuff_lists_defaults = {  rdm = {self={'Dia II','Paralyze'}}}
    local custom_settings_defaults = {}

    hb.config = {
        aliases = config.load('../shortcuts/data/aliases.xml'),
        mabil_debuffs = lor_settings.load('data/mabil_debuffs.lua'),
        buff_lists = lor_settings.load('data/buffLists.lua', buff_lists_defaults),
        priorities = lor_settings.load('data/priorities.lua'),
        cure_potency = lor_settings.load('data/cure_potency.lua', cure_potency_defaults),
        debuff_lists = lor_settings.load('data/debuffLists.lua', debuff_lists_defaults),
        custom_settings = lor_settings.load('data/custom_settings.lua', custom_settings_defaults),
    }

    hb.config.priorities.players =        hb.config.priorities.players or {}
    hb.config.priorities.jobs =           hb.config.priorities.jobs or {}
    hb.config.priorities.status_removal = hb.config.priorities.status_removal or {}
    hb.config.priorities.buffs =          hb.config.priorities.buffs or {}
    hb.config.priorities.debuffs =        hb.config.priorities.debuffs or {}
    hb.config.priorities.dispel =         hb.config.priorities.dispel or {}     --not implemented yet
    hb.config.priorities.default =        hb.config.priorities.default or 5
    
    --process_mabil_debuffs()
    local msg = hb.configs_loaded and 'Rel' or 'L'
    hb.configs_loaded = true
    atcc(262, msg..'oaded config files.')
end


function process_mabil_debuffs()
    local debuff_names = table.keys(hb.config.mabil_debuffs)
    for _,abil_raw in pairs(debuff_names) do
        local abil_fixed = abil_raw:gsub('_',' '):capitalize()
        hb.config.mabil_debuffs[abil_fixed] = S{}
        local debuffs = hb.config.mabil_debuffs[abil_raw]
        for _,debuff in pairs(debuffs) do
            hb.config.mabil_debuffs[abil_fixed]:add(debuff)
        end
        hb.config.mabil_debuffs[abil_raw] = nil
    end
    hb.config.mabil_debuffs:save()
end


function utils.update_settings(loaded)
    for key,val in pairs(loaded) do
        if istable(val) then
            settings[key] = settings[key] or {}
            for skey,sval in pairs(val) do
                settings[key][skey] = sval
            end
        else
            settings[key] = settings[key] or val
        end
    end
    table.update_if_not_set(settings, {
        disable = {},
        follow = {delay = 0.08, distance = 3},
        healing = {
            minCure = 3, 
            minCuraga = 2, 
            minWaltz = 2, 
            minWaltzga = 2, 
            minBlue = 2, 
            minBluega = 2
        },
        spam = {}
    })
end


function utils.refresh_textBoxes()
	local OurReso = windower.get_windower_settings()
	local X_action_queue = OurReso.x_res - 765
	local X_mon_box = OurReso.x_res - 305

    local boxes = {'actionQueue','moveInfo','actionInfo','montoredBox','debuffList','toggleList'}
    for _,box in pairs(boxes) do
        local bs = settings.textBoxes[box]
		local bst
		if (box == 'actionInfo' or box == 'moveInfo') then
			bst = {pos={x=bs.x, y=bs.y}, bg={alpha=125, blue=0, green=0,red=0,visible=true}, stroke={alpha=255, blue=0, green=0, red=0, width=0}}
		elseif box == 'montoredBox' then
			bst = {pos={x=X_mon_box, y=bs.y}, bg=settings.textBoxes.bg, stroke={alpha=255, blue=0, green=0, red=0, width=0}}
		elseif box == 'actionQueue' then
			bst = {pos={x=X_action_queue, y=bs.y}, bg=settings.textBoxes.bg, stroke={alpha=255, blue=0, green=0, red=0, width=0}}
		elseif box == 'debuffList' then
			bst = {pos={x=bs.x, y=bs.y}, bg=settings.textBoxes.bg_other, stroke={alpha=255, blue=0, green=0, red=0, width=0}}
		elseif box == 'toggleList' then
			bst = {pos={x=X_mon_box, y=bs.y}, bg=settings.textBoxes.bg, stroke={alpha=255, blue=0, green=0, red=0, width=0}}
		end
	
        if (bs.font ~= nil) then
            bst.text = {font=bs.font}
        end
        if (bs.size ~= nil) then
            bst.text = bst.text or {}
            bst.text.size = bs.size
        end
		
        if (hb.txts[box] ~= nil) then
            hb.txts[box]:destroy()
        end
        hb.txts[box] = texts.new(bst)
    end
end


--==============================================================================
--          Table Functions
--==============================================================================

function getPrintable(list, inverse)
    local qstring = ''
    for index,line in pairs(list) do
        local check = index
        local add = line
        if (inverse) then
            check = line
            add = index
        end
        if (tostring(check) ~= 'n') then
            if (#qstring > 1) then
                qstring = qstring..'\n'
            end
            qstring = qstring..add
        end
    end
    return qstring
end

--======================================================================================================================
--                      Misc.
--======================================================================================================================

function help_text()
    local t = '    '
    local ac,cc,dc = 262,263,1
    atcc(262,'HealBot Commands:')
    local cmds = {
        {'on | off','Activate / deactivate HealBot (does not affect follow)'},
        {'reload','Reload HealBot, resetting everything'},
        {'refresh','Reloads settings XMLs in addons/HealBot/data/'},
        {'custom','Loads custom settings from a list stored in the custom_settings.lua'},
        {'fcmd','Sets a player to follow, the distance to maintain, or toggles being active with no argument'},
        {'buff <player> <spell>[, <spell>[, ...]]','Sets spell(s) to be maintained on the given player'},
        {'cancelbuff <player> <spell>[, <spell>[, ...]]','Un-sets spell(s) to be maintained on the given player'},
        {'blcmd','Sets the given list of spells to be maintained on the given player'},
        {'bufflists','Lists the currently configured spells/abilities in each bufflist'},
        {'spam [use <spell> | <bool>]','Sets the spell to be spammed on assist target\'s enemy, or toggles being active (default: Stone, off)'},
        {'dbcmd','Add/remove debuff spell to maintain on assist target\'s enemy, toggle on/off, or list current debuffs to maintain'},
        {'dbcmd2','Add/remove debuff spells from a selected list stored in debuffLists.lua'},
        {'mincure <number>','Sets the minimum cure spell tier to cast (default: 3)'},
        {'disable <action type>','Disables actions of a given type (cure, buff, na)'},
        {'enable <action type>','Re-enables actions of a given type (cure, buff, na) if they were disabled'},
        {'reset [buffs | debuffs | both [on <player>]]','Resets the list of buffs/debuffs that have been detected, optionally for a single player'},
        {'ignore_debuff <player/always> <debuff>','Ignores when the given debuff is cast on the given player or everyone'},
        {'unignore_debuff <player/always> <debuff>','Stops ignoring the given debuff for the given player or everyone'},
        {'ignore <player>','Ignores the given player/npc so they will not be healed'},
        {'unignore <player>','Stops ignoring the given player/npc (=/= watch)'},
        {'watch <player>','Monitors the given player/npc so they will be healed'},
        {'unwatch <player>','Stops monitoring the given player/npc (=/= ignore)'},
        {'ignoretrusts <on/off>','Toggles whether or not Trust NPCs should be ignored (default: on)'},
        {'ascmd','Sets a player to assist, toggles whether or not to engage, to approach target, switch to the same target as assist, or toggles being active with no argument'},
        {'wscmd1','Sets the weaponskill to use'},
        {'wscmd2','Sets when weaponskills should be used according to whether the mob HP is < or > the given amount'},
        {'wscmd3','Sets a weaponskill partner to open skillchains for, and the TP that they should have'},
        {'wscmd4','Removes a weaponskill partner so weaponskills will be performed independently'},
        {'wscmd5','Sets the mininum TP for weaponskill use'},
        {'queue [pos <x> <y> | on | off]','Moves action queue, or toggles display with no argument (default: on)'},
        {'actioninfo [pos <x> <y> | on | off]','Moves character status info, or toggles display with no argument (default: on)'},
        {'moveinfo [pos <x> <y> | on | off]','Moves movement status info, or toggles display with no argument (default: off)'},
        {'monitored [pos <x> <y> | on | off]','Moves monitored player list, or toggles display with no argument (default: on)'},
        {'help','Displays this help text'}
    }
    local acmds = {
        ['custom']=('custom'):colorize(ac,cc)..'settings <list name>',
        ['fcmd']=('f'):colorize(ac,cc)..'ollow [<player> | dist <#> | off | resume]',
        ['ascmd']=('as'):colorize(ac,cc)..'sist [<player> | attack | off | resume | noapproach | sametarget]',
        ['wscmd1']=('w'):colorize(ac,cc)..'eapon'..('s'):colorize(ac,cc)..'kill use <ws name>',
        ['wscmd2']=('w'):colorize(ac,cc)..'eapon'..('s'):colorize(ac,cc)..'kill hp <sign> <mob hp%>',
        ['wscmd3']=('w'):colorize(ac,cc)..'eapon'..('s'):colorize(ac,cc)..'kill waitfor <player> <tp>',
        ['wscmd4']=('w'):colorize(ac,cc)..'eapon'..('s'):colorize(ac,cc)..'kill nopartner',
        ['wscmd5']=('w'):colorize(ac,cc)..'eapon'..('s'):colorize(ac,cc)..'kill tp <tp>',
        ['dbcmd']=('d'):colorize(ac,cc)..'e'..('b'):colorize(ac,cc)..'uff [(use | rm) <spell> | on | off | ls]',
        ['dbcmd2']=('de'):colorize(ac,cc)..('b'):colorize(ac,cc)..'uff'..('l'):colorize(ac,cc)..'ist <list name>',
        ['blcmd']=('b'):colorize(ac,cc)..'uff'..('l'):colorize(ac,cc)..'ist <list name> (<player>)',
    }
    
    for _,tbl in pairs(cmds) do
        local cmd,desc = tbl[1],tbl[2]
        local txta = cmd
        if (acmds[cmd] ~= nil) then
            txta = acmds[cmd]
        else
            txta = txta:colorize(cc)
        end
        local txtb = desc:colorize(dc)
        atc(txta)
        atc(t..txtb)
    end
end

--======================================================================================================================
--[[
Copyright © 2016, Lorand
All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:
    * Redistributions of source code must retain the above copyright notice, this list of conditions and the
      following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
      following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of ffxiHealer nor the names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Lorand BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
--]]
--======================================================================================================================
