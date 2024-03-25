--==============================================================================
--[[
	Author: Ragnarok.Lorand
	HealBot action handling functions
--]]
--==============================================================================

local actions = {queue=L()}
local lor_res = _libs.lor.resources
local ffxi = _libs.lor.ffxi


local function local_queue_reset()
    actions.queue = L()
end

local function local_queue_insert(action, target)
	if (tostring(action) ~= nil) and (tostring(target) ~= nil) then
		actions.queue:append(tostring(action)..' → '..tostring(target))
	end
end

local function local_queue_disp()
    hb.txts.actionQueue:text(getPrintable(actions.queue))
    hb.txts.actionQueue:visible(settings.textBoxes.actionQueue.visible)
end

--[[
	Builds an action queue for defensive actions.  Returns the action deemed most important at the time.
--]]
function actions.get_defensive_action()
	local action = {}
	local player = player or windower.ffxi.get_player()
	
	if (not settings.disable.cure) then
		local cureq = CureUtils.get_cure_queue()
		while (not cureq:empty()) do
			local cact = cureq:pop()
            local_queue_insert(cact.action.en, cact.name)
			
			--ST20 debuff, prevent curing.
			local ST20 = false
			if buffs.debuffList[cact.name] and buffs.debuffList[cact.name][20] then
				ST20 = true
			end
			
			if (action.cure == nil) and healer:in_casting_range(cact.name) and ST20 == false then
				action.cure = cact
			end
		end
	end
	if (not settings.disable.na) then
		local dbuffq = buffs.getDebuffQueue()
		while (not dbuffq:empty()) do
			local dbact = dbuffq:pop()
			atcd(123, 'Debuff popped to remove: ' .. dbact.debuff.en)
			local ign = buffs.ignored_debuffs[dbact.debuff.en]	
			
			if not ((ign ~= nil) and ((ign.all == true) or ((ign[dbact.name] ~= nil) and (ign[dbact.name] == true)))) then
				-- Erase disable toggle
				if (dbact.action.en == 'Erase') then
					if (not settings.disable.erase) then
						dbact_target = windower.ffxi.get_mob_by_name(dbact.name)
						local_queue_insert(dbact.action.en, dbact.name)
						if (action.debuff == nil) and healer:in_casting_range(dbact.name) and healer:ready_to_use(dbact.action) and not(dbact_target.hpp == 0) then
							action.debuff = dbact
						end
					end
				else
					dbact_target = windower.ffxi.get_mob_by_name(dbact.name)
					local is_trust = dbact_target and dbact_target.spawn_type == 14 or false
					if not(is_trust and dbact.debuff.en:lower() == 'sleep') then
						local_queue_insert(dbact.action.en, dbact.name)
						if (action.debuff == nil) and healer:in_casting_range(dbact.name) and healer:ready_to_use(dbact.action) and not(dbact_target.hpp == 0) then
							action.debuff = dbact
						end
					end
				end
			else
				atcd(123, '***[Failsafe ignore_debuff caught]*** ->  Name: ' .. dbact.name .. ' Debuff: ' .. dbact.debuff.en .. ' ID: ' .. dbact.debuff.id)
			end
			
		end
	end
	if (not settings.disable.buff) then
		
		local buffq = buffs.getBuffQueue()
		while (not buffq:empty()) do
			local bact = buffq:pop()
			
			if (bact and bact.action and bact.action.en) then
				bact_target = windower.ffxi.get_mob_by_name(bact.name)
				if not (buffs.debuffList[bact.name] and buffs.debuffList[bact.name][13] and S{'Haste','Haste II','Flurry','Flurry II'}:contains(bact.action.en)) then
					local_queue_insert(bact.action.en, bact.name)
				end
			end
            
			if (action.buff == nil) and healer:in_casting_range(bact.name) and healer:ready_to_use(bact.action) and not(bact_target.hpp == 0) then
				if not (buffs.debuffList[bact.name] and buffs.debuffList[bact.name][13] and S{'Haste','Haste II','Flurry','Flurry II'}:contains(bact.action.en)) then
					action.buff = bact
				end
			end
		end
	end
	
	local_queue_disp()
	
	if (action.cure ~= nil) then
		if (action.debuff ~= nil) and (action.debuff.action.en == 'Paralyna') and (action.debuff.name == healer.name) then
			return action.debuff
		elseif (action.debuff ~= nil) and ((action.debuff.prio + 2) < action.cure.prio) then
			return action.debuff
		elseif (action.buff ~= nil) and ((action.buff.prio + 2) < action.cure.prio) then
			return action.buff
		end
		return action.cure
	elseif (action.debuff ~= nil) then
		if (action.buff ~= nil) and (action.buff.prio < action.debuff.prio) then
			return action.buff
		end
		return action.debuff
	elseif (action.buff ~= nil) then
		return action.buff
	end
	utils.check_recovery_item()
	return nil
end


function actions.take_action(player, partner, targ)
    if hb.aoe_action then
        healer:take_action(hb.aoe_action)
        return
    end
	if settings.autoshadows == true then
        buffs.check_shadows()
    end
    buffs.checkOwnBuffs()
    local_queue_reset()
    local action = actions.get_defensive_action()
    if (action ~= nil) then         --If there's a defensive action to perform
        --Record attempt time for buffs/debuffs
        buffs.buffList[action.name] = buffs.buffList[action.name] or {}
        if (action.type == 'buff') and (buffs.buffList[action.name][action.buff]) then
            buffs.buffList[action.name][action.buff].attempted = os.clock()
        elseif (action.type == 'debuff') then
            buffs.debuffList[action.name][action.debuff.id].attempted = os.clock()
        end
		if action.action.divine_seal then
            local divine_seal = lor_res.action_for("Divine Seal")
            if healer:can_use(divine_seal) and utils.ready_to_use(divine_seal) then
                healer:take_action({action=divine_seal}, healer.name)
                hb.aoe_action = action
                return true
            end
        end
        if action.action.accession then
            local accession = lor_res.action_for("Accession")
            if healer:can_use(accession) and utils.ready_to_use(accession) then
                healer:take_action({action=accession}, healer.name)
                hb.aoe_action = action
                return true
            end
        end
        healer:take_action(action)
		--Debuffs with moblist specified, has same priority as healing or buffing - will alternate.
		if offense.moblist.active and offense.moblist.mobs then
			actions.build_mob_debuff_list(player, offense.moblist.mobs)
		end
		--Dispel, has same priority as healing or buffing - will alternate.
		if offense.dispel.active and offense.dispel.mobs then
			actions.build_dispel_list(player, offense.dispel.mobs)
		end
		return true
    --Otherwise, there may be an offensive action(Debuffing or engage to attack)
    else             
		--Targetting or Independant mode.
        if (targ ~= nil) or hb.modes.independent then
            local self_engaged = (player.status == 1)
            if (targ ~= nil) then
				local partner_engaged = (partner.status == 1)
				if (player.target_index == partner.target_index) then
					if offense.assist.engage then
                        if (not partner_engaged) and (self_engaged) then
                            healer:send_cmd('input /attack off')
                            return true
                        elseif partner_engaged and (not self_engaged) then
                            healer:send_cmd('input /attack on')
                            healer:take_action(actions.face_target())
                            -- if offense.assist.noapproach == true then 
                                -- if player.target_locked then
                                --     healer:send_cmd('input /lockon')
                                -- end
							-- end
							return true
						else
							-- if offense.assist.noapproach == true then 
                            --     if player.target_locked then
                            --         healer:send_cmd('input /lockon')
                            --     end
							-- end
							if offense.alwaysfacetarget and self_engaged then 
								healer:take_action(actions.face_target())
							end
							if not actions.check_moblist_mob(player.target_index) then
								healer:take_action(actions.get_offensive_action(player, partner), '<t>')
							end
							if offense.moblist.active and offense.moblist.mobs then 
								actions.build_mob_debuff_list(player, offense.moblist.mobs)
							end
							if offense.dispel.active and offense.dispel.mobs then
								actions.build_dispel_list(player, offense.dispel.mobs)
							end
							return true
						end
					--Debuff actions with lock on target
					else
						if not actions.check_moblist_mob(player.target_index) then
							healer:take_action(actions.get_offensive_action(player, partner), '<t>')
						end
						if offense.moblist.active and offense.moblist.mobs then 
							actions.build_mob_debuff_list(player, offense.moblist.mobs)
						end
						if offense.dispel.active and offense.dispel.mobs then
							actions.build_dispel_list(player, offense.dispel.mobs)
						end
						return true
					end
				else   --Different targets
					--Assist but not engage
					if partner_engaged and (not self_engaged) and not (offense.assist.nolock) then
						healer:send_cmd('input /as '..offense.assist.name)
						return true
					--Assist + Debuffs with mob id, requires gearswap
					elseif (partner_engaged and partner.target_index and offense.assist.nolock) then
						if not actions.check_moblist_mob(partner.target_index) then
							healer:take_action(actions.get_offensive_action(player, partner), windower.ffxi.get_mob_by_index(partner.target_index).id)
						end
						if (hb.modes.independent and (self_engaged or (player.target_locked and utils.isMonster(player.target_index)))) then
							if not actions.check_moblist_mob(player.target_index) then
								healer:take_action(actions.get_offensive_action(player, nil), '<t>')
							end
						end
						if offense.moblist.active and offense.moblist.mobs then 
							actions.build_mob_debuff_list(player, offense.moblist.mobs)
						end
						if offense.dispel.active and offense.dispel.mobs then
							actions.build_dispel_list(player, offense.dispel.mobs)
						end
						return true
					--Switches target to same as partner
					elseif partner_engaged and partner.target_index and self_engaged and not (offense.assist.nolock) and offense.assist.sametarget then
						healer:switch_target(windower.ffxi.get_mob_by_index(partner.target_index).id)
						return true
					end
				end
			-- Debuff without having assist, either engaged or target locked.
            elseif (hb.modes.independent and (self_engaged or (player.target_locked and utils.isMonster(player.target_index)))) then
				if offense.alwaysfacetarget and self_engaged then 
                    healer:take_action(actions.face_target())
                end
                if offense.assist.noapproach == true then 
                    if player.target_locked then
                        healer:send_cmd('input /lockon')
                    end
                end
				if not actions.check_moblist_mob(player.target_index) then
					healer:take_action(actions.get_offensive_action(player, nil), '<t>')
				end
				if offense.moblist.active and offense.moblist.mobs then 
					actions.build_mob_debuff_list(player, offense.moblist.mobs)
				end
				if offense.dispel.active and offense.dispel.mobs then
					actions.build_dispel_list(player, offense.dispel.mobs)
				end
				return true
            end
		end
		--Debuffs with mobslist specified within debuffing block
		if offense.moblist.active and offense.moblist.mobs then
			actions.build_mob_debuff_list(player, offense.moblist.mobs)
        end
		if offense.dispel.active and offense.dispel.mobs then
			actions.build_dispel_list(player, offense.dispel.mobs)
		end
		if offense.debuffing_battle_target and (windower.ffxi.get_mob_by_target('bt') or false) and next(offense.debuffs) then
			healer:take_action(actions.get_offensive_action(player, nil, true), '<bt>')
		end
		return true
    end
	return false
end

--Builder for multiple dispel targets
function actions.build_dispel_list(player, moblist)
	for mob_id,mob_debuffs in pairs(moblist) do
		local dispel_target = windower.ffxi.get_mob_by_id(mob_id) and windower.ffxi.get_mob_by_id(mob_id).claim_id or nil
		if utils.check_claim_id(dispel_target) then
			healer:take_action(actions.get_dispel_action(player, mob_id), mob_id)
		end
	end
end

--Builder for list of mobs to debuff, accounting for same name mobs.
function actions.build_mob_debuff_list(player, moblist)
	mob_names = T(windower.ffxi.get_mob_list()):filter(set.contains+{moblist})
	for mob_index,mob_name in pairs(mob_names) do
		if utils.isMonster(mob_index) then
			healer:take_action(actions.get_offensive_action_list(player, mob_index), windower.ffxi.get_mob_by_index(mob_index).id)
		end
	end
end

function actions.check_moblist_mob(target_index)
	if not offense.moblist.mobs then return false end
	local target_name = windower.ffxi.get_mob_by_index(target_index).name
	
	for mob_name,_ in pairs(offense.moblist.mobs) do
		if target_name == mob_name then
			return true
		end
	end
	return false
end

--[[
	Builds an action queue for offensive actions.
    Returns the action deemed most important at the time.
--]]
function actions.get_offensive_action(player, partner, battle_target)
	player = player or windower.ffxi.get_player()
	local target
	if battle_target then
		target = windower.ffxi.get_mob_by_target('bt')
	else
		target = (partner and partner.target_index and windower.ffxi.get_mob_by_index(partner.target_index)) or windower.ffxi.get_mob_by_target()
	end
    if target == nil or target.hpp == 0 then return nil end
    local action = {}

    --Prioritize debuffs over nukes/ws
    local dbuffq = offense.getDebuffQueue(player, target)
    while not dbuffq:empty() do
        local dbact = dbuffq:pop()
        local_queue_insert(dbact.action.en, target.name)
        if (action.db == nil) and healer:in_casting_range(target) and healer:ready_to_use(dbact.action) then
			--Stymie
			local stymie = lor_res.action_for("Stymie")
			if offense.stymie.active and player.main_job == "RDM" and healer:can_use(stymie) and (healer:ready_to_use(stymie) or haveBuff(stymie.name)) and os.time() > (offense.stymie.last_used + 600) then
				offense.stymie.flag = false
				if dbact.action.en == offense.stymie.spell then
					healer:take_action({action=stymie}, healer.name)
					action.db = dbact
					offense.stymie.attempt = os.time() -- Sets the attempt to cast the spell with Stymie
				end
			else
				action.db = dbact
			end
			--Sets 10mins before Stymie can be used again, waits 30sec after Stymie attempts to set this timer.
			if offense.stymie.active and player.main_job == "RDM" and not healer:ready_to_use(stymie) and not haveBuff(stymie.name) and not offense.stymie.flag and os.time() > (offense.stymie.attempt + 30) then
				log('timer')
				offense.stymie.last_used = os.time()
				offense.stymie.flag = true
			end
        end
    end
    
    local_queue_disp()
    if action.db ~= nil then
        return action.db
    end
    
    if (not settings.disable.ws) and (settings.ws ~= nil) and (settings.ws.name ~= nil) and healer:ready_to_use(lor_res.action_for(settings.ws.name)) and actions.in_ws_range('<t>', settings.ws.name) then
        local sign = settings.ws.sign or '>'
        local hp = settings.ws.hp or 0
        local hp_ok = ((sign == '<') and (target.hpp <= hp)) or ((sign == '>') and (target.hpp >= hp))

        local player = windower.ffxi.get_player()
        local setting_self_tp = 1000

        if (settings.ws.self_tp ~= nil) then
            setting_self_tp = settings.ws.self_tp
        end

        local partner_ok = true
        if (settings.ws.partner ~= nil) then
            local pname = settings.ws.partner.name
            local partner = ffxi.get_party_member(pname)
            if partner ~= nil then
                partner_ok = partner.tp >= settings.ws.partner.tp
                --partner_ok = partner.tp <= 500
            else
                partner_ok = false
                atc(123,'Unable to locate weaponskill partner '..pname)
            end
        end

        if (hp_ok and partner_ok) then
            if settings.ws.name ~= nil then
                if settings.ws.keep_AM3 == true and buffs.buff_active(272) == false then
                    if player.vitals.tp == 3000 then
                        if settings.ws.AM3_name ~= nil then
                            if actions.is_self_weaponskill(settings.ws.AM3_name) == true  then
                                --atc(123,'Attempting a self targetting WS '..settings.ws.name)
                                return {action=lor_res.action_for(settings.ws.AM3_name),name='<me>'}
                            else
                                return {action=lor_res.action_for(settings.ws.AM3_name),name='<t>'}
                            end
                        end
                    end
                elseif player.vitals.tp > setting_self_tp then
                    if actions.is_self_weaponskill(settings.ws.name) == true  then
                        --atc(123,'Attempting a self targetting WS '..settings.ws.name)
                        return {action=lor_res.action_for(settings.ws.name),name='<me>'}
                    else
                        if actions.in_ws_range('<t>', settings.ws.name) == true then
                            return {action=lor_res.action_for(settings.ws.name),name='<t>'}
                        end
                    end
                end
            end
        end
    elseif (not settings.disable.spam) and settings.spam.active and (settings.spam.name ~= nil) then
        local spam_action = lor_res.action_for(settings.spam.name)
        if (target.hpp > 0) and healer:ready_to_use(spam_action) and healer:in_casting_range('<t>') then
			return {action=spam_action,name='<t>'}
        else
			atcd('MP/TP not ok for '..settings.spam.name)
        end
    end
    
    atcd('get_offensive_action: no offensive actions to perform')
	return nil
end

--Moblist debuff - with separate list if defined.  Otherwise use default debuffs
function actions.get_offensive_action_list(player, mob_index)
	player = player or windower.ffxi.get_player()
	local target = (windower.ffxi.get_mob_by_index(mob_index))
    if target == nil or target.hpp == 0 then return nil end
    local action = {}
    
    --Prioritize debuffs over nukes/ws
    local dbuffq = offense.getDebuffQueue(player, target, true)
    while not dbuffq:empty() do
        local dbact = dbuffq:pop()
        local_queue_insert(dbact.action.en, target.name)
        if (action.db == nil) and healer:in_casting_range(target) and healer:ready_to_use(dbact.action) then
            action.db = dbact
        end
    end
    
    local_queue_disp()
    if action.db ~= nil then
        return action.db
    end
   
    atcd('get_offensive_action: no offensive actions to perform')
	return nil
end

function actions.get_dispel_action(player, mob_id)
	player = player or windower.ffxi.get_player()
	local target = (windower.ffxi.get_mob_by_id(mob_id))
    if target == nil or target.hpp == 0 then return nil end
    local action = {}
    
    --Prioritize debuffs over nukes/ws
    local dbuffq = offense.getDispelQueue(player, target)
    while not dbuffq:empty() do
        local dbact = dbuffq:pop()
        local_queue_insert(dbact.action.en, target.name)
        if (action.db == nil) and healer:in_casting_range(target) and healer:ready_to_use(dbact.action) then
            action.db = dbact
        end
    end
    
    local_queue_disp()
    if action.db ~= nil then
        return action.db
    end
	return nil
end

function actions.face_target()
    if (player == nil) then
        player = windower.ffxi.get_player()
    end
    mob = windower.ffxi.get_mob_by_target("t")
    if (not mob) then
        return
    end

    local player_body = windower.ffxi.get_mob_by_id(player.id)
    local angle = (math.atan2((mob.y - player_body.y), (mob.x - player_body.x))*180/math.pi)*-1
    local rads = angle:radian()
    windower.ffxi.turn(rads)
end

function actions.is_self_weaponskill(weaponskill_name)
    local is_self_weaponskill = false
    local self_target_ws = {'dagan', 'starlight', 'moonlight', 'myrkr'}
    for _, v in ipairs(self_target_ws) do
        if v == string.lower(weaponskill_name)then
            is_self_weaponskill = true
            break
        end
    end
    return is_self_weaponskill
end


function actions.in_ws_range(targ, weaponskill_name)
    -- Returns true if the given target is within spell casting range
    local target = ffxi.get_target(targ)
    local mob = windower.ffxi.get_mob_by_target('t')
    local dist = healer:dist_from(mob.id)
    --local dist = self:dist_from(targ)

    local long_range_ws = {"Flaming Arrow", "Piercing Arrow", "Dulling Arrow", "Sidewinder", "Blast Arrow", "Arching Arrow",
    "Empyreal Arrow","Namas Arrow","Refulgent Arrow","Jishnu's Radience","Apex Arrow", "Sarv", "Hot Shot","Split Shot","Sniper Shot", 
    "Slug Shot", "Blast Shot", "Heavy Shot", "Detonator", 
    "Coronach", "Trueflight", "Leaden Salute", "Numbing Shot", "Wildfire", "Last Stand", "Terminus"}
    local mid_range_ws = {'mistral axe', 'bora axe'}
    local ws_dist = 5
    if target == nil then 
        return false
    end   
    if dist == -1 then
        return false
    else
        for _, x in ipairs(long_range_ws) do
            if x == string.lower(weaponskill_name)then
                ws_dist = 17
                break
            end
        end
        for _, v in ipairs(mid_range_ws) do
            if v == string.lower(weaponskill_name)then
                ws_dist = 9
                break
            end
        end   
        --return dist < 20.9
        return dist < (ws_dist + target.model_size)
    end
end


return actions

--==============================================================================
--[[
Copyright © 2016, Lorand
All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of ffxiHealer nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Lorand BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]
--==============================================================================
