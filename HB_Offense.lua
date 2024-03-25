--==============================================================================
--[[
    Author: Ragnarok.Lorand
    HealBot offense handling functions
--]]
--==============================================================================

local offense = {
    immunities=lor_settings.load('data/mob_immunities.lua'),
    alwaysfacetarget = true,
    mobdistance = 2.2, -- Default Mob Distance without forcing distances.
    mobdistancemin = 2.2,-- 2.2, -- Forcing distance min
    mobdistancemax = 20.2, -- 24,  -- Forcing distance max
    forcemobdist = false,
    assist={active = false, engage = false, nolock = false, noapproach = false, sametarget = true,},
	moblist={active = false, mobs=S{}, debuffs={},},
    debuffs={}, ignored={}, mobs={}, 
	dispel={active = true, mobs={}, ignored=S{},},
    debuffing_active = true,
	debuffing_battle_target = false,
	stymie={active = false, spell = '', last_used = 0, flag = false, attempt = 0},
}


function offense.register_assistee(assistee_name, job_name_flag)
	if job_name_flag then
		if utils.getPlayerNameFromJob(assistee_name) then
			offense.register_assistee(utils.getPlayerNameFromJob(assistee_name), false)
		else
			atc('Unable to find JOB target: '..assistee_name:upper())
		end
		return
	end

    local pname = utils.getPlayerName(assistee_name)
    if (pname ~= nil) then
        offense.assist.name = pname
        offense.assist.active = true
        atcf('Now assisting %s.', pname)
    else
        atcf(123,'Error: Invalid name provided as an assist target: %s', assistee_name)
    end
end


function offense.assistee_and_target()
    if offense.assist.active and (offense.assist.name ~= nil) then
        local partner = windower.ffxi.get_mob_by_name(offense.assist.name)
        if partner then
            local targ = windower.ffxi.get_mob_by_index(partner.target_index)
            if (targ ~= nil) and targ.is_npc then
                return partner, targ
            end
        end
    end
    return nil
end


function offense.cleanup()
    local mob_ids = table.keys(offense.mobs)
    if mob_ids then
        for _,id in pairs(mob_ids) do
            local mob = windower.ffxi.get_mob_by_id(id)
            if mob == nil or mob.hpp == 0 then
                offense.mobs[id] = nil
            end
        end
    end
	if offense.dispel.mobs then
		offense.dispel.mobs = {}
	end
end


function offense.maintain_debuff(spell, cancel, mob_debuff_list_flag)
    local nspell = utils.normalize_action(spell, 'spells')
    if not nspell then
        atcfs(123, '[offense.maintain_debuff] Invalid spell: %s', spell)
        return
    end
    local debuff_id = spell_debuff_idmap[nspell.id]
    if debuff_id == nil then
        atcfs(123, 'Unable to find debuff for spell: %s', spell)
        return
    end
    local debuff = res.buffs[debuff_id]
    if cancel then
		if mob_debuff_list_flag then
			offense.moblist.debuffs[debuff.id] = nil
		else
			offense.debuffs[debuff.id] = nil
		end
    else
		if mob_debuff_list_flag then
			offense.moblist.debuffs[debuff.id] = {spell = nspell, res = debuff}
		else
			offense.debuffs[debuff.id] = {spell = nspell, res = debuff}
		end
    end
    local msg = cancel and 'no longer ' or ''
	if mob_debuff_list_flag then
		atcf('Will %smaintain debuff on moblist: %s', msg, nspell.en)
	else
		atcf('Will %smaintain debuff on mobs: %s', msg, nspell.en)
	end
end


function offense.normalized_mob(mob)
    if istable(mob) then
        return mob
    elseif isnum(mob) then
        return windower.ffxi.get_mob_by_id(mob)
    end
    return mob
end


function offense.register_immunity(mob, debuff)
    offense.immunities[mob.name] = S(offense.immunities[mob.name]) or S{}
    offense.immunities[mob.name]:add(debuff.id)
    offense.immunities:save()
end


function offense.registerMob(mob, forget)
    mob = offense.normalized_mob(mob)
    if not mob then return end

    if forget then
        offense.mobs[mob.id] = nil
        atcd(('Forgetting mob: %s [%s]'):format(mob.name, mob.id))
    else
        if offense.mobs[mob.id] ~= nil then
            atcd(('Attempted to register already known mob: %s[%s]'):format(mob.name, mob.id))
        else
            atcd(('Registering new mob: %s[%s]'):format(mob.name, mob.id))
        end
        offense.mobs[mob.id] = offense.mobs[mob.id] or {}
    end
end


function offense.getDebuffQueue(player, target, mob_debuff_list_flag)
    local dbq = ActionQueue.new()
    if offense.debuffing_active then
		offense.mobs[target.id] = offense.mobs[target.id] or {}
		if mob_debuff_list_flag and next(offense.moblist.debuffs) then -- Use alternative debuff list for moblist
			for id,debuff in pairs(offense.moblist.debuffs) do
				if offense.mobs[target.id][id] == nil then
					if not (offense.immunities[target.name] and offense.immunities[target.name][id]) then
						dbq:enqueue('debuff_mob', debuff.spell, target.name, debuff.res, (' (%s)'):format(debuff.spell.en))
					end
				end
			end
		else
			for id,debuff in pairs(offense.debuffs) do
				if offense.mobs[target.id][id] == nil then
					if not (offense.immunities[target.name] and offense.immunities[target.name][id]) then
						dbq:enqueue('debuff_mob', debuff.spell, target.name, debuff.res, (' (%s)'):format(debuff.spell.en))
					end
				end
			end
		end
    end
    return dbq:getQueue()
end


function offense.getDispelQueue(player, target)
    local dbq = ActionQueue.new()
    if offense.dispel.active and (S{'RDM','BRD'}:contains(player.main_job) or S{'RDM'}:contains(player.sub_job)) then
		if offense.dispel.mobs[target.id] then
			for debuff,_ in pairs(offense.dispel.mobs[target.id]) do
				if debuff ~= nil then
					if not offense.dispel.ignored:contains(target.name) then
						if player.main_job == 'BRD' and healer:can_use(res.spells[462]) then
							dbq:enqueue('spells', res.spells[462], target.name, res.spells[462], ' Magic Finale')
						elseif (player.main_job == 'RDM' or player.sub_job == 'RDM') and not (player.main_job == 'BRD') and healer:can_use(res.spells[260]) then
							dbq:enqueue('spells', res.spells[260], target.name, res.spells[260], ' Dispel')
						end
					end
				end
			end
		end
    end
    return dbq:getQueue()
end


return offense

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
