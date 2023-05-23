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
    else

    end
    --actions.queue:append(tostring(action)..' → '..tostring(target))
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

    if hb.manual_action then
        action.manual = hb.manual_action
    elseif not utils.manual_actions:empty() then
        for _,a in ipairs(utils.manual_actions) do
            local_queue_insert(a.action.en, a.target)
        end
        local ma = utils.manual_actions[1]
        hb.manual_action = ma
        utils.manual_actions:remove(1)
        action.manual = ma
    end

    if (not settings.disable.cure) then
        local cureq = CureUtils.get_cure_queue()
        while (not cureq:empty()) do
            local cact = cureq:pop()
            local_queue_insert(cact.action.en, cact.name)
            if (action.cure == nil) and healer:in_casting_range(cact.name) then
                action.cure = cact
            end
        end
    end
    if (not settings.disable.na) then
        local dbuffq = buffs.getDebuffQueue()
        while (not dbuffq:empty()) do
            local dbact = dbuffq:pop()
            local_queue_insert(dbact.action.en, dbact.name)
            if (action.debuff == nil) and healer:in_casting_range(dbact.name) and healer:ready_to_use(dbact.action) then
                action.debuff = dbact
            end
        end
    end
    if (not settings.disable.buff) then
        local buffq = buffs.getBuffQueue()
        while (not buffq:empty()) do
            local bact = buffq:pop()
            if (bact and bact.action and bact.action.en) then
                bact_target = windower.ffxi.get_mob_by_name(bact.name)
                local_queue_insert(bact.action.en, bact.name)
            end
            if (action.buff == nil) and healer:in_casting_range(bact.name) and healer:ready_to_use(bact.action) then
                action.buff = bact
            end
        end
    end

    local_queue_disp()

    if action.manual ~= nil then
        return action.manual
    elseif (action.cure ~= nil) then
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
        return true
    else                        --Otherwise, there may be an offensive action
        if (targ ~= nil) or hb.modes.independent then
            local self_engaged = (player.status == 1)
            if (targ ~= nil) then
                local partner_engaged = (partner.status == 1)
                if (player.target_index == partner.target_index) then
                    if offense.assist.engage and partner_engaged and (not self_engaged) then
                        healer:send_cmd('input /attack on')
                        healer:take_action(actions.face_target())
                        return true
                    else
                        if offense.alwaysfacetarget and self_engaged then 
                            healer:take_action(actions.face_target())
                        end
                        local offensive_action = actions.get_offensive_action(player)
                        if offensive_action ~= nil then
                            atcd(123, 'Offensive Action Current action: '..tostring(offensive_action.action.en))
                            atcd(123, 'Offensive Action Current action target: '..tostring(offensive_action.name))
                            if offensive_action.name == '<me>' then
                                healer:take_action(offensive_action, '<me>')
                            else
                                healer:take_action(offensive_action, '<t>')
                            end
                        end

                        -- Old Hardcoded method
                        --healer:take_action(actions.get_offensive_action(player), '<t>')

                        return true
                    end
                else                            --Different targets
                    if partner_engaged and (not self_engaged) then
                        healer:send_cmd('input /as '..offense.assist.name)
                        return true
                    end
                end
            elseif self_engaged and hb.modes.independent then
                if offense.alwaysfacetarget and self_engaged then 
                    healer:take_action(actions.face_target())
                end
                local independent_offensive_action = actions.get_offensive_action(player)
                if independent_offensive_action ~= nil then
                    atcd(123, 'Independent Offensive Current action: '..tostring(independent_offensive_action.action.en))
                    atcd(123, 'Independent Offensive Current action target: '..tostring(independent_offensive_action.name))
                    if independent_offensive_action.name == '<me>' then
                        healer:take_action(independent_offensive_action, '<me>')
                    else
                        healer:take_action(independent_offensive_action, '<t>')
                    end
                end

                -- Old Hardcoded method
                --healer:take_action(actions.get_offensive_action(player), '<t>')
                return true
            end
            offense.cleanup()
        end
    end
    return false
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

--[[
    Builds an action queue for offensive actions.
    Returns the action deemed most important at the time.
--]]
function actions.get_offensive_action(player)
    player = player or windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target()
    if target == nil then return nil end
    local action = {}

    --Prioritize debuffs over nukes/ws
    local dbuffq = offense.getDebuffQueue(player, target)
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

    if (not settings.disable.ws) and (settings.ws ~= nil) and (settings.ws.name ~= nil) and healer:ready_to_use(lor_res.action_for(settings.ws.name)) then
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
                        return {action=lor_res.action_for(settings.ws.name),name='<t>'}
                    end
                end
            end
        end
    elseif (not settings.disable.spam) and settings.spam.active and (settings.spam.name ~= nil) then
        local spam_action = lor_res.action_for(settings.spam.name)
        if (target.hpp > 0) and healer:ready_to_use(spam_action) and healer:in_casting_range('<t>') then
            local _p_ok = (player.vitals.mp >= spam_action.mp_cost)
            if spam_action.tp_cost ~= nil then
                _p_ok = (_p_ok and (player.vitals.tp >= spam_action.tp_cost))
            end
            if _p_ok then
                return {action=spam_action,name='<t>'}
            else
                atcd('MP/TP not ok for '..settings.spam.name)
            end
        end
    end

    atcd('get_offensive_action: no offensive actions to perform')
    return nil
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
