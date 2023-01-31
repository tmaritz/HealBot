return {
    ['rdmLead'] = {
        ['assist'] = false,
        ['assistEngage'] = false,
        ['follow'] = false,
        ['useWeaponSkill'] = 'Savage Blade',
        ['useWeaponSkillTP'] = 1000,
        ['applySelfBuffList'] = 'rdmExemplar',
        ['applyP1BuffList'] = 'ddExemplar',
        ['applyP2BuffList'] = 'ddExemplar',
        ['applyP3BuffList'] = 'ddExemplar',
        ['applyP4BuffList'] = 'ddExemplar',
        ['applyP5BuffList'] = 'ddExemplar',
        ['useDebuffs'] = false,
        --['applyDebuffList'] = 'rdmExemplar',
        ['independent'] = true,
        ['autoshadows'] = true,
        ['noapproach'] = false,
        ['ignoreTrusts'] = true,
    },
    ['rdmAssistFendo'] = {
        ['assist'] = true,
        ['assistName'] = 'Fendo',
        ['assistEngage'] = true,
        ['follow'] = true,
        ['followTarget'] = 'Fendo',
        ['followDist'] = 0.3,
        ['useWeaponSkill'] = 'Savage Blade',
        ['useWeaponSkillTP'] = 1000,
        ['applySelfBuffList'] = 'rdmExemplar',
        ['applyP1BuffList'] = 'ddExemplar',
        ['applyP2BuffList'] = 'ddExemplar',
        ['applyP3BuffList'] = 'ddExemplar',
        ['applyP4BuffList'] = 'ddExemplar',
        ['applyP5BuffList'] = 'ddExemplar',
        ['independent'] = false,
        ['autoshadows'] = false,
        ['noapproach'] = false,
        ['ignoreTrusts'] = true,
    },
    ['ddAssistFendo'] = {
        ['assist'] = true,
        ['assistName'] = 'Fendo',
        ['assistEngage'] = true,
        ['follow'] = true,
        ['followTarget'] = 'Fendo',
        ['followDist'] = 0.3,
        ['useWeaponSkill'] = 'Savage Blade',
        ['useWeaponSkillTP'] = 1000,
        ['independent'] = false,
        ['autoshadows'] = false,
        ['noapproach'] = false,
        ['ignoreTrusts'] = true,
    },
    ['ddAssistDenorea'] = {
        ['assist'] = true,
        ['assistName'] = 'Denorea',
        ['assistEngage'] = true,
        ['follow'] = true,
        ['followTarget'] = 'Denorea',
        ['followDist'] = 0.3,
        ['useWeaponSkill'] = 'Savage Blade',
        ['useWeaponSkillTP'] = 1000,
        ['independent'] = false,
        ['autoshadows'] = true,
        ['noapproach'] = false,
        ['ignoreTrusts'] = true,
    },
    ['rdmAssistDenorea'] = {
        ['assist'] = true,
        ['assistName'] = 'Denorea',
        ['assistEngage'] = true,
        ['follow'] = true,
        ['followTarget'] = 'Denorea',
        ['followDist'] = 0.3,
        ['useWeaponSkill'] = 'Savage Blade',
        ['useWeaponSkillTP'] = 1000,
        ['applySelfBuffList'] = 'rdmExemplar',
        ['applyP1BuffList'] = 'ddExemplar',
        ['applyP2BuffList'] = 'ddExemplar',
        ['applyP3BuffList'] = 'ddExemplar',
        ['applyP4BuffList'] = 'ddExemplar',
        ['applyP5BuffList'] = 'ddExemplar',
        ['independent'] = false,
        ['autoshadows'] = false,
        ['noapproach'] = false,
        ['useDebuffs'] = false,
        --['applyDebuffList'] = 'rdmExemplar',
        ['ignoreTrusts'] = true,
    },
}


-- Things we want to set - IF you think of more let me know!

-- Independent Mode --
-- hb.modes.independent

-- Assist --
-- offense.assist.name = 'Name'
-- offense.assist.active = true
-- offense.assist.engage = true
-- offense.assist.noapproach

-- Follow --
-- settings.follow.active = true
-- settings.follow.target = 'Name'
-- settings.follow.distance = 0.3

-- Weaponskills --
-- settings.ws.self_tp = 1000
-- settings.ws.name = 'Savage Blade'

-- Shadows --
-- settings.autoshadows

-- Buff List --
-- bufflist use
-- rdmExemplar
-- utils.apply_bufflist({listName, target})

-- Debuff List --
-- Use a specific Debuff List if not blank
-- offense.debuffing_active
-- utils.apply_debufflist({args})

-- Ignore Trusts
-- settings.ignoreTrusts
