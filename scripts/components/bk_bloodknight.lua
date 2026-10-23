--------------------------------------------------------------------------
-- bk_bloodknight  (server only)
--
-- All Blood Knight rules live here: Runes, Runic Power, Bone Shield,
-- Blood Debt, the six abilities, Blood Plague and the Dancing Rune Weapon.
-- The client never calculates anything; it only reads the net variables
-- (inst._bk_*) that this component publishes, see Publish().
--
-- Ability ids (also used by the keybinds, the RPC and the HUD):
--   1 Heart Strike   2 Death Strike   3 Marrowrend
--   4 Blood Boil     5 Death and Decay 6 Dancing Rune Weapon
--   7 Death Grip     8 Dark Command   9 Vampiric Blood
--   10 Raise Dead    (Purgatory is passive)
--------------------------------------------------------------------------

local BK = TUNING.BK
local FX = BK.FX
local wortox_soul_common = require("prefabs/wortox_soul_common")

local HEART, DEATH, MARROW, BOIL, DECAY, DANCE = 1, 2, 3, 4, 5, 6
local GRIP, COMMAND, VAMPIRIC, RAISEDEAD = 7, 8, 9, 10
local NUM_ABILITIES = 10

-- bit flags published in inst._bk_flags
local FLAG_DRW, FLAG_FREEHS, FLAG_DEBT, FLAG_DECAY, FLAG_OSSUARY, FLAG_VB, FLAG_PURG, FLAG_CRIMSON = 1, 2, 4, 8, 16, 32, 64, 128

local ENEMY_MUST_TAGS = { "_combat" }
local ENEMY_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "invisible", "playerghost", "player", "wall", "companion", "FX" }
local HOSTILE_TAGS = { "monster", "hostile", "epic", "shadowcreature", "nightmarecreature" }
-- things on the players' side that area abilities must never hit
local FRIENDLY_TAGS = { "companion", "domesticated", "abigail", "critter", "structure", "shadowminion" }
local INCAPACITATED_TAGS = { "dead", "sleeping", "knockout", "frozen", "pinned", "drowning" }

-- health changes that must not count as "damage taken" for Death Strike
local IGNORED_DAMAGE_CAUSES = { hunger = true, cold = true, hot = true }

local FAIL_LINES =
{
    runes = "ANNOUNCE_BK_NORUNES",
    rp = "ANNOUNCE_BK_NORP",
    target = "ANNOUNCE_BK_NOTARGET",
    noblade = "ANNOUNCE_BK_NOBLADE",   -- no Rune Blade in hand
    locked = "ANNOUNCE_BK_LOCKED",     -- the held Rune Blade's tier is too low
    charges = "ANNOUNCE_BK_NOCHARGES", -- out of Blood Boil / Death and Decay charges
    cooldown = nil, -- silent: key mashing is normal
}

--------------------------------------------------------------------------

local function SpawnFx(name, x, y, z, scale)
    local fx = SpawnPrefab(name)
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
        if scale ~= nil then
            fx.Transform:SetScale(scale, scale, scale)
        end
    end
    return fx
end

-- A flat ring on the ground whose outer edge matches `radius`.
-- (slingshot_aoe_fx is about FX_RING_RADIUS big at scale 1.)
local function SpawnRing(x, z, radius, colour)
    local fx = SpawnPrefab(FX.RING)
    if fx ~= nil then
        fx.Transform:SetPosition(x, 0, z)
        local s = radius / BK.FX_RING_RADIUS
        fx.Transform:SetScale(s, s, s)
        if fx.SetColorType ~= nil then
            fx:SetColorType(colour or "horror")
        end
    end
    return fx
end

local function Clamp(v, lo, hi)
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

-- Runic Power is kept as a float (it drains smoothly); everything else sees
-- the whole number. The tiny extra keeps 34.99999 from showing as 34.
local function RPValue(rp)
    return math.floor(rp + 0.0001)
end

--------------------------------------------------------------------------

local BloodKnight = Class(function(self, inst)
    self.inst = inst

    -- resources
    self.runes = BK.RUNES_MAX
    self.rune_prog = {}     -- seconds of recharge done, one entry per missing rune (oldest first)
    self.rp = 0
    self.shield = 0
    self.debt = 0
    self.blood_shield = 0           -- Blood Shield: damage it can still absorb
    self.blood_shield_end = nil
    self.hemo = 0                   -- Hemostasis stacks (from Blood Boil, used by Death Strike)
    self.coag = 0                   -- Coagulopathy stacks (from Death Strike, boost Blood Plague)
    self.taunted = {}               -- [enemy] = time until it is forced to stay on us
    self.vb_end = nil               -- Vampiric Blood is up until this time
    self.vb_base_max = nil          -- max health before Vampiric Blood
    self.ghoul = nil                -- Raise Dead's ghoul
    self.ghoul_task = nil
    self.purg_end = nil             -- Purgatory shroud is up until this time
    self.purg_debt = 0              -- healing still needed to survive Purgatory
    self.purg_ready = 0             -- Purgatory can trigger again from this time
    self.tier = 0                   -- tier of the Rune Blade in hand (0 = none), see UpdateTier
    self.rune = nil                 -- rune engraved in that blade (runeforging)
    self.at_forge = false           -- standing at a Rune Forge (see UpdateStations)
    self.at_table = false           -- standing at a Runic Armor Table
    self.station_acc = 0
    self.craft_bits = -1            -- last crafting tags published to the client
    self.crusader_end = nil         -- Fallen Crusader buff
    self.sang_ready = 0             -- Sanguination heal can trigger again from this time
    self.sang_end = nil             -- Sanguination heal-over-time running until this time
    self.thirst_end = nil           -- Unending Thirst kill buff
    self.razorice = {}              -- [enemy] = { n = stacks, expire = time }
    self.coag_end = nil
    self.bb_charges = BK.BB_CHARGES -- Blood Boil uses stored up
    self.bb_timer = 0               -- seconds towards the next Blood Boil charge
    self.dd_charges = BK.DD_CHARGES -- Death and Decay uses stored up
    self.dd_timer = 0
    self.crimson_end = nil          -- Crimson Scourge: next Death and Decay is free until this time

    -- timers (absolute GetTime() values)
    self.ready = {}
    for i = 1, NUM_ABILITIES do
        self.ready[i] = 0
    end
    self.shield_next_loss = 0
    self.shield_end = nil   -- Bone Shield fades at this time (SHIELD_TIME after the last build-up)
    self.shard_ready = 0
    self.last_combat = -1000
    self.talk_next = 0

    -- buffs
    self.drw_end = nil
    self.drw_blade = nil
    self.drw_haste_on_end = false -- the real DRW (not a Dance of Midnight proc) is running
    self.rune_haste_end = nil     -- runes recharge faster until this time
    self.freehs = false
    self.freehs_expire = 0
    self.debt_buff_end = nil
    self.in_decay = false
    self.zone = nil

    -- bookkeeping
    self.plague = {}        -- [enemy] = expire time
    self.plague_acc = 0
    self.plague_fx_tick = 0
    self.recent = {}        -- { {t = time, amt = damage}, ... }
    self.dirty = true

    -- event hooks ---------------------------------------------------------
    self._onattacked = function(_, data) self:OnAttacked(data) end
    self._onhealthdelta = function(_, data) self:OnHealthDelta(data) end
    self._onattackother = function(_, data) self:OnAttackOther(data) end
    self._onhitother = function(_, data) self:OnHitOther(data) end
    self._ondeath = function() self:ClearTransient() end
    self._onbecameghost = function() self:Reset() end
    self._onrespawned = function() self:Reset() end
    self._onentitydeath = function(_, data) self:OnEntityDeath(data) end
    self._onkilled = function(_, data) self:OnKilled(data) end

    inst:ListenForEvent("attacked", self._onattacked)
    inst:ListenForEvent("healthdelta", self._onhealthdelta)
    inst:ListenForEvent("onattackother", self._onattackother)
    inst:ListenForEvent("onhitother", self._onhitother)
    inst:ListenForEvent("death", self._ondeath)
    inst:ListenForEvent("ms_becameghost", self._onbecameghost)
    inst:ListenForEvent("ms_respawnedfromghost", self._onrespawned)
    -- progression: what is in our hand decides which abilities work
    self._onequipchange = function() self:UpdateTier() end
    inst:ListenForEvent("equip", self._onequipchange)
    inst:ListenForEvent("unequip", self._onequipchange)
    inst:DoTaskInTime(0, self._onequipchange) -- after the starting inventory is equipped/loaded
    inst:ListenForEvent("entity_death", self._onentitydeath, TheWorld)
    inst:ListenForEvent("killed", self._onkilled)

    -- Dancing Rune Weapon: +dodge through the stock attackdodger component.
    if inst.components.attackdodger == nil then
        inst:AddComponent("attackdodger")
    end
    inst.components.attackdodger:SetCanDodgeFn(function(_, attacker)
        return self:IsDRWActive() and math.random() < BK.DRW_DODGE
    end)
    inst.components.attackdodger:SetOnDodgeFn(function(_, attacker)
        self:OnDodge(attacker)
    end)

    -- Blood Shield soaks up incoming hits before they reach health.
    -- (Chained, so any other effect using the same hook keeps working.)
    local health = inst.components.health
    self._prev_deltamodifier = health.deltamodifierfn
    health.deltamodifierfn = function(inst2, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        if self._prev_deltamodifier ~= nil then
            amount = self._prev_deltamodifier(inst2, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        end
        if amount > 0 and self.vb_end ~= nil then
            amount = amount * (1 + BK.VB_HEAL) -- Vampiric Blood: +30% healing received
        end
        amount = self:AbsorbWithBloodShield(amount, afflicter)
        return self:ApplyPurgatory(amount)
    end

    -- Coagulopathy: enemies with Blood Plague take more damage from us.
    -- customdamagemultfn is the game's per-target damage hook (chained too).
    local combat = inst.components.combat
    self._prev_damagemult = combat.customdamagemultfn
    combat.customdamagemultfn = function(inst2, target, weapon, multiplier, mount)
        local m = 1
        if self._prev_damagemult ~= nil then
            m = self._prev_damagemult(inst2, target, weapon, multiplier, mount) or 1
        end
        if target ~= nil and self.plague[target] ~= nil and self:HasTalent("coagulopathy") then
            m = m * (1 + BK.COAG_TARGET_DAMAGE)
        end
        if self.rune == "razorice" then
            -- Rune of Razorice: extra frost damage, more for every stack on the target
            local stack = target ~= nil and self.razorice[target] or nil
            m = m * (1 + BK.RAZORICE_DAMAGE) * (1 + (stack ~= nil and stack.n or 0) * BK.RAZORICE_PER_STACK)
        end
        return m
    end

    inst:StartUpdatingComponent(self)
    self:UpdateDefense()
    self:Publish()
end)

--------------------------------------------------------------------------
-- Net variables (read by the client HUD)
--------------------------------------------------------------------------

function BloodKnight:MarkDirty()
    self.dirty = true
end

function BloodKnight:Publish()
    local inst = self.inst
    if inst._bk_runes == nil then
        return
    end

    inst._bk_runes:set(self.runes)
    -- progress of the (up to 3) recharging runes, 0..95 in steps of 5
    for i = 1, BK.RUNES_RECHARGING do
        local netvar = inst["_bk_runeprog" .. (i == 1 and "" or i)]
        if netvar ~= nil then
            netvar:set(self:RuneStep(i))
        end
    end
    inst._bk_rp:set(RPValue(self.rp))
    if inst._bk_tier ~= nil then
        inst._bk_tier:set(self.tier)
    end
    if inst._bk_bloodshield ~= nil then
        inst._bk_bloodshield:set(math.ceil(self.blood_shield))
        inst._bk_hemo:set(self.hemo)
    end
    if inst._bk_bbcharges ~= nil then
        inst._bk_bbcharges:set(self.bb_charges)
        local bbstep = 0
        if self.bb_charges < BK.BB_CHARGES then
            bbstep = math.floor(Clamp(self.bb_timer / BK.BB_RECHARGE, 0, 0.99) * 20) * 5
        end
        inst._bk_bbprog:set(bbstep)
    end
    if inst._bk_ddcharges ~= nil then
        inst._bk_ddcharges:set(self.dd_charges)
        local ddstep = 0
        if self.dd_charges < BK.DD_CHARGES then
            ddstep = math.floor(Clamp(self.dd_timer / BK.DD_RECHARGE, 0, 0.99) * 20) * 5
        end
        inst._bk_ddprog:set(ddstep)
    end
    inst._bk_shield:set(self.shield)
    inst._bk_debt:set(self.debt)

    local now = GetTime()
    local flags = 0
    if self:IsDRWActive() then
        flags = flags + FLAG_DRW
    end
    if self.freehs and now <= self.freehs_expire then
        flags = flags + FLAG_FREEHS
    end
    if self.debt_buff_end ~= nil then
        flags = flags + FLAG_DEBT
    end
    if self.in_decay then
        flags = flags + FLAG_DECAY
    end
    if self:HasOssuary() then
        flags = flags + FLAG_OSSUARY
    end
    if self.vb_end ~= nil then
        flags = flags + FLAG_VB
    end
    if self.purg_end ~= nil then
        flags = flags + FLAG_PURG
    end
    if self.crimson_end ~= nil then
        flags = flags + FLAG_CRIMSON
    end
    if inst._bk_purg ~= nil then
        inst._bk_purg:set(math.ceil(self.purg_debt))
    end
    inst._bk_flags:set(flags)

    self.dirty = false
end

--------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------

function BloodKnight:NoteCombat()
    self.last_combat = GetTime()
end

function BloodKnight:IsInCombat()
    return GetTime() - self.last_combat <= BK.RP_DECAY_DELAY
end

function BloodKnight:IsDRWActive()
    return self.drw_end ~= nil
end

function BloodKnight:IsIncapacitated()
    local inst = self.inst
    if not inst:IsValid() or inst:HasTag("playerghost") then
        return true
    end
    if inst.components.health ~= nil and inst.components.health:IsDead() then
        return true
    end
    if inst.sg ~= nil and inst.sg:HasAnyStateTag(unpack(INCAPACITATED_TAGS)) then
        return true
    end
    return false
end

-- Short, rate limited "I can't do that" lines.
function BloodKnight:Fail(reason)
    local now = GetTime()
    local key = FAIL_LINES[reason]
    if key ~= nil and now >= self.talk_next and self.inst.components.talker ~= nil then
        self.talk_next = now + 1.5
        local line = GetString(self.inst, key, nil, true)
        if line ~= nil and line ~= "" then
            self.inst.components.talker:Say(line)
        end
    end
    return false
end

-- Is `ent` something our area abilities may hurt?
-- Anything you could attack counts (monsters, but also pigs, beefalo, a
-- spider that has not noticed you yet...), except what is on the players'
-- side: other players, their followers, pets, companions and buildings.
-- `relaxed` skips that friendly check too (a target the player chose on purpose).
function BloodKnight:IsEnemy(ent, relaxed)
    local inst = self.inst
    if ent == nil or ent == inst or not ent:IsValid() then
        return false
    end
    if ent.components.health == nil or ent.components.health:IsDead() or ent.components.combat == nil then
        return false
    end
    if not inst.components.combat:CanTarget(ent) then
        return false
    end
    if relaxed then
        return true
    end
    if ent:HasAnyTag(FRIENDLY_TAGS) then
        return false
    end
    local follower = ent.components.follower
    local leader = follower ~= nil and follower:GetLeader() or nil
    if leader ~= nil and (leader:HasTag("player") or leader:HasTag("companion")) then
        return false -- somebody's pig, spider, ghoul...
    end
    return true
end

-- Enemies whose BODY touches the circle (centre distance minus their size),
-- so a big creature standing at the edge of a ring is still hit.
local MAX_BODY_RADIUS = 4 -- search a bit wider, then check each body size
function BloodKnight:FindEnemies(x, y, z, radius)
    local found = {}
    local ents = TheSim:FindEntities(x, y, z, radius + MAX_BODY_RADIUS, ENEMY_MUST_TAGS, ENEMY_CANT_TAGS)
    for _, ent in ipairs(ents) do
        local reach = radius + ent:GetPhysicsRadius(0)
        if ent:GetDistanceSqToPoint(x, y, z) <= reach * reach and self:IsEnemy(ent) then
            table.insert(found, ent)
        end
    end
    return found
end

function BloodKnight:FindPrimaryTarget()
    local inst = self.inst
    local reach = BK.HS_RANGE

    local current = inst.components.combat.target
    if current ~= nil and current:IsValid() and self:IsEnemy(current, true)
        and inst:GetDistanceSqToInst(current) <= (reach + 2) * (reach + 2) then
        return current
    end

    -- closest one, but something that is fighting (or a monster) comes
    -- before a neutral creature standing nearby
    local x, y, z = inst.Transform:GetWorldPosition()
    local best, bestdsq, bestrank
    for _, ent in ipairs(self:FindEnemies(x, y, z, reach)) do
        local rank = (ent.components.combat.target ~= nil or ent:HasAnyTag(HOSTILE_TAGS)) and 1 or 0
        local dsq = inst:GetDistanceSqToInst(ent)
        if best == nil or rank > bestrank or (rank == bestrank and dsq < bestdsq) then
            best, bestdsq, bestrank = ent, dsq, rank
        end
    end
    return best
end

-- Damage an enemy with a share of the player's normal hit damage.
function BloodKnight:HitTarget(ent, mult, weapon)
    local inst = self.inst
    if ent == nil or not ent:IsValid() or ent.components.combat == nil then
        return
    end
    local combat = inst.components.combat
    if weapon == nil then
        weapon = combat:GetWeapon()
    end
    self._ability_hit = true -- the Rune Blade counts its ability damage (see IsAbilityHit)
    local dmg, spdmg = combat:CalcDamage(ent, weapon, mult)
    ent.components.combat:GetAttacked(inst, dmg, weapon, nil, spdmg) -- (OnHitOther ignores it)
    self._ability_hit = false
    -- threat: anything an ability hits turns to us (see Taunt)
    self:Taunt(ent)
end

--------------------------------------------------------------------------
-- Threat / taunt
--
-- DST has no threat table, so this is the tank rule from WoW made simple:
--   * every enemy your abilities hit switches its target to you, even if it
--     was attacking a friend;
--   * a taunt (Death Grip, Dark Command) also keeps it on you for
--     TAUNT_TIME seconds, re-targeting you if it tries to turn away.
--------------------------------------------------------------------------

function BloodKnight:Taunt(ent, hold_time)
    local inst = self.inst
    if ent == nil or not ent:IsValid() or ent:HasTag("player") then
        return false
    end
    local combat = ent.components.combat
    if combat == nil or ent.components.health == nil or ent.components.health:IsDead()
        or not combat:CanTarget(inst) then
        return false
    end
    if combat.target ~= inst then
        combat:SetTarget(inst)
    end
    if hold_time ~= nil then
        self.taunted[ent] = math.max(self.taunted[ent] or 0, GetTime() + hold_time)
    end
    return true
end

-- Keep taunted enemies on us (called from OnUpdate).
function BloodKnight:UpdateTaunts(now)
    for ent, untiltime in pairs(self.taunted) do
        if now >= untiltime or not ent:IsValid() or ent.components.combat == nil
            or ent.components.health == nil or ent.components.health:IsDead() then
            self.taunted[ent] = nil
        elseif ent.components.combat.target ~= self.inst then
            ent.components.combat:SetTarget(self.inst)
        end
    end
end

-- Target for Death Grip / Dark Command:
--   1. what the player pointed at with the mouse (sent with the key press);
--   2. otherwise the closest enemy that is attacking somebody else (peel it
--      off a friend);
--   3. otherwise the closest enemy.
function BloodKnight:PickTauntTarget(hint, range)
    local inst = self.inst
    local rangesq = range * range
    if hint ~= nil and self:IsEnemy(hint, true) and inst:GetDistanceSqToInst(hint) <= rangesq then
        return hint
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    -- rank: 2 = attacking somebody else, 1 = fighting you or a monster,
    -- 0 = a neutral creature minding its own business
    local best, bestdsq, bestrank
    for _, ent in ipairs(self:FindEnemies(x, y, z, range)) do
        local tgt = ent.components.combat.target
        local rank = (tgt ~= nil and tgt ~= inst and 2) or ((tgt == inst or ent:HasAnyTag(HOSTILE_TAGS)) and 1) or 0
        local dsq = inst:GetDistanceSqToInst(ent)
        if best == nil or rank > bestrank or (rank == bestrank and dsq < bestdsq) then
            best, bestdsq, bestrank = ent, dsq, rank
        end
    end
    return best
end

--------------------------------------------------------------------------
-- Resource mutators
--------------------------------------------------------------------------

function BloodKnight:AddRP(delta)
    local old = RPValue(self.rp)
    self.rp = Clamp(self.rp + delta, 0, self:GetRPMax())
    if self.rp < 0.0001 then
        self.rp = 0
    end
    if RPValue(self.rp) ~= old then
        self:MarkDirty()
    end
end

function BloodKnight:SetShield(n)
    n = Clamp(math.floor(n), 0, BK.SHIELD_MAX)
    if n ~= self.shield then
        self.shield = n
        self:UpdateDefense()
        self:AddRP(0) -- Ossuary may have ended: Runic Power above the smaller max is lost
        self:MarkDirty()
    end
end

-- Ossuary (WoW talent): at 5+ Bone Shield stacks, cheaper Death Strike and a bigger RP bar.
function BloodKnight:HasOssuary()
    return self.shield >= BK.OSSUARY_STACKS and self:HasTalent("ossuary")
end

function BloodKnight:GetRPMax()
    return BK.RP_MAX + (self:HasOssuary() and BK.OSSUARY_RP_BONUS or 0)
end

function BloodKnight:GetDeathStrikeCost()
    return BK.RP_COST[DEATH] - (self:HasOssuary() and BK.OSSUARY_COST_CUT or 0)
end

-- Is this hit an ability (and not a plain swing)? The Rune Blade asks this to
-- pick its damage: plain swings are weak, abilities hit as hard as before.
function BloodKnight:IsAbilityHit(target)
    if self._ability_hit then
        return true
    end
    local swing = self._ability_swing
    return swing ~= nil and swing.target == target and swing.time == GetTime()
end

function BloodKnight:AddShield(n)
    self:SetShield(self.shield + n)
    if n > 0 then
        self.shield_end = GetTime() + BK.SHIELD_TIME -- building it up restarts the 30 s
    end
end

-- Heart Strike's slow (like WoW): 20% slower for 8 s, refreshed by every hit.
local function ApplySlow(ent)
    local locomotor = ent:IsValid() and ent.components.locomotor or nil
    if locomotor == nil then
        return
    end
    locomotor:SetExternalSpeedMultiplier(ent, "bk_heartstrike", 1 - BK.HS_SLOW)
    if ent._bk_slowtask ~= nil then
        ent._bk_slowtask:Cancel()
    end
    ent._bk_slowtask = ent:DoTaskInTime(BK.HS_SLOW_TIME, function()
        ent._bk_slowtask = nil
        if ent.components.locomotor ~= nil then
            ent.components.locomotor:RemoveExternalSpeedMultiplier(ent, "bk_heartstrike")
        end
    end)
end

function BloodKnight:SetDebt(n)
    n = Clamp(math.floor(n), 0, BK.DEBT_MAX)
    if n ~= self.debt then
        self.debt = n
        -- like WoW: each stack already gives +0.5% damage while you build them
        local mods = self.inst.components.combat.externaldamagemultipliers
        if n > 0 then
            mods:SetModifier(self.inst, 1 + n * BK.DEBT_PER_STACK, "bk_debtstacks")
        else
            mods:RemoveModifier(self.inst, "bk_debtstacks")
        end
        self:MarkDirty()
    end
end

function BloodKnight:AddDebt(n)
    self:SetDebt(self.debt + n)
end

-- Spend runes. Returns false (and spends nothing) if there are too few.
-- Also rolls the Dance of Midnight proc.
function BloodKnight:SpendRunes(n)
    if n <= 0 then
        return true
    end
    if self.runes < n then
        return false
    end
    self.runes = self.runes - n
    -- the spent runes join the end of the recharge queue
    for i = 1, n do
        table.insert(self.rune_prog, 0)
    end
    -- like WoW: every rune spent generates Runic Power
    self:AddRP(BK.RP_PER_RUNE * n)
    self:MarkDirty()

    if not self:IsDRWActive() and self:HasTalent("dance") and math.random() < BK.DOM_CHANCE then
        self:StartDRW(BK.DOM_TIME)
    end
    return true
end

-- Recharge progress of the i-th recharging rune, as 0..95 in steps of 5
-- (0 when that rune is not recharging).
function BloodKnight:RuneStep(i)
    local t = self.rune_prog[i]
    if t == nil or i > BK.RUNES_RECHARGING then
        return 0
    end
    return math.floor(Clamp(t / BK.RUNE_RECHARGE, 0, 0.99) * 20) * 5
end

-- Called for every health change (see the hook in the constructor).
-- Only real hits (something hurt us) are absorbed, not hunger, cold or fire ticks.
function BloodKnight:AbsorbWithBloodShield(amount, afflicter)
    if amount >= 0 or self.blood_shield <= 0 or afflicter == nil then
        return amount
    end
    local absorbed = math.min(-amount, self.blood_shield)
    self.blood_shield = self.blood_shield - absorbed
    if self.blood_shield <= 0.01 then
        self.blood_shield = 0
        self.blood_shield_end = nil
    end
    self:MarkDirty()
    if self.inst._bk_bloodshield ~= nil then
        self:Publish()
    end
    return amount + absorbed
end

--------------------------------------------------------------------------
-- Purgatory (passive)
--------------------------------------------------------------------------

local function SayLine(self, key)
    local talker = self.inst.components.talker
    if talker ~= nil then
        local line = GetString(self.inst, key, nil, true)
        if line ~= nil and line ~= "" then
            talker:Say(line)
        end
    end
end

-- Called for every health change after Blood Shield (see the constructor).
function BloodKnight:ApplyPurgatory(amount)
    local health = self.inst.components.health
    if amount == 0 or health == nil or health:IsDead() then
        return amount
    end
    local now = GetTime()

    if amount > 0 then
        -- healing first pays off the Purgatory debt
        if self.purg_debt > 0 then
            local used = math.min(amount, self.purg_debt)
            self.purg_debt = self.purg_debt - used
            amount = amount - used
            self:MarkDirty()
            self:Publish()
        end
        return amount
    end

    local after = health.currenthealth + amount
    if self.purg_end ~= nil then
        -- shroud is up: we cannot die, the extra damage becomes more debt
        if after < 1 then
            self.purg_debt = self.purg_debt + (1 - after)
            amount = 1 - health.currenthealth
            self:MarkDirty()
            self:Publish()
        end
    elseif after <= 0 and now >= self.purg_ready and not health:IsInvincible() and self:HasTalent("purgatory") then
        -- fatal hit: Purgatory saves us at 1 health
        self.purg_debt = 1 - after
        self.purg_end = now + BK.PURGATORY_TIME
        self.purg_ready = now + BK.PURGATORY_COOLDOWN
        amount = 1 - health.currenthealth
        if self.inst._bk_purgcd ~= nil then
            self.inst._bk_purgcd:set(BK.PURGATORY_COOLDOWN)
        end
        local x, y, z = self.inst.Transform:GetWorldPosition()
        SpawnFx(FX.PORTAL_IN, x, 0, z)
        SpawnFx(FX.SMOKE, x, 0, z, 1.0)
        if self.inst.components.colouradder == nil then
            self.inst:AddComponent("colouradder")
        end
        self.inst.components.colouradder:PushColour("bk_purgatory", 0.25, 0, 0.3, 0)
        SayLine(self, "ANNOUNCE_BK_PURGATORY")
        self:MarkDirty()
        self:Publish()
    end
    return amount
end

-- The 3 s are over: survive if the debt was healed, die otherwise.
function BloodKnight:EndPurgatory(survived_anyway)
    if self.purg_end == nil then
        return
    end
    self.purg_end = nil
    local debt = self.purg_debt
    self.purg_debt = 0
    if self.inst.components.colouradder ~= nil then
        self.inst.components.colouradder:PopColour("bk_purgatory")
    end
    self:MarkDirty()
    local health = self.inst.components.health
    if not survived_anyway and debt > 0 and health ~= nil and not health:IsDead() then
        SayLine(self, "ANNOUNCE_BK_PURGATORY_FAIL")
        health:Kill()
    end
end

--------------------------------------------------------------------------
-- Progression: the Rune Blade in hand
--------------------------------------------------------------------------

-- Tier of the Rune Blade we are holding (0 = none). Called on equip/unequip.
-- force: re-read even if the tier did not change (a new rune was engraved)
function BloodKnight:UpdateTier(force)
    local inst = self.inst
    local inv = inst.components.inventory
    local item = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    local tier = item ~= nil and item.bk_tier or 0
    local rune = tier > 0 and item.bk_rune or nil
    if tier == self.tier and rune == self.rune and not force then
        return
    end
    self.tier = tier
    self.rune = rune
    self:UpdateCraftTags()
    self:ApplyRunePassives()
    self:AddRP(0) -- Ossuary may no longer apply: clamp Runic Power to the max
    self:MarkDirty()
    self:Publish()
end

--------------------------------------------------------------------------
-- Crafting stations (bk_stations.lua)
--
-- The station recipes in modmain.lua ask for these builder tags:
--   bk_at_runeforge   at a Rune Forge               blade tier upgrades
--   bk_runeforge      at a Rune Forge, blade in hand  runes
--   bk_armor_t1..t3   at a Runic Armor Table with a blade of tier
--                     ARMOR_BLADE_TIER[n] in hand    armor tier n
--------------------------------------------------------------------------

local function SetTag(inst, tag, on)
    if on then
        inst:AddTag(tag)
    else
        inst:RemoveTag(tag)
    end
end

function BloodKnight:UpdateCraftTags()
    local inst = self.inst
    local bits = 0
    local function Flag(tag, on, bit)
        SetTag(inst, tag, on)
        if on then
            bits = bits + bit
        end
    end
    Flag("bk_at_runeforge", self.at_forge, 1)
    Flag("bk_runeforge", self.at_forge and self.tier >= 1, 2)
    for n, need in ipairs(BK.ARMOR_BLADE_TIER) do
        Flag("bk_armor_t" .. n, self.at_table and self.tier >= need, 2 ^ (1 + n))
    end
    if bits ~= self.craft_bits then
        self.craft_bits = bits
        -- the crafting menu does not notice tag changes by itself: tell it
        if inst._bk_craft ~= nil then
            inst._bk_craft:set(bits) -- clients refresh on this (bloodknight.lua)
        end
        inst:PushEvent("refreshcrafting") -- a host player refreshes here
    end
end

local STATION_TAGS = { "bk_runeforge_station", "bk_armortable_station" }
function BloodKnight:UpdateStations()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local forge, table_ = false, false
    for _, ent in ipairs(TheSim:FindEntities(x, y, z, BK.STATION_RANGE, nil, { "INLIMBO", "burnt" }, STATION_TAGS)) do
        if ent:HasTag("bk_runeforge_station") then
            forge = true
        else
            table_ = true
        end
    end
    if forge ~= self.at_forge or table_ ~= self.at_table then
        self.at_forge = forge
        self.at_table = table_
        self:UpdateCraftTags()
    end
end

-- Is this passive talent unlocked by the blade in hand?
function BloodKnight:HasTalent(name)
    return self.tier >= (BK.TALENT_TIER[name] or 1)
end

--------------------------------------------------------------------------
-- Runeforging: the rune in the held blade
--------------------------------------------------------------------------

-- Always-on rune effects (re-applied whenever the blade or its rune changes).
function BloodKnight:ApplyRunePassives()
    local inst = self.inst
    local combat = inst.components.combat
    -- Stoneskin Gargoyle: a little tougher and stronger
    if self.rune == "gargoyle" then
        combat.externaldamagemultipliers:SetModifier(inst, 1 + BK.GARGOYLE_DAMAGE, "bk_gargoyle")
        combat.externaldamagetakenmultipliers:SetModifier(inst, 1 - BK.GARGOYLE_DEFENSE, "bk_gargoyle")
    else
        combat.externaldamagemultipliers:RemoveModifier(inst, "bk_gargoyle")
        combat.externaldamagetakenmultipliers:RemoveModifier(inst, "bk_gargoyle")
    end
    -- Unending Thirst: faster, even more after a kill
    local locomotor = inst.components.locomotor
    if locomotor ~= nil then
        if self.rune == "thirst" then
            local bonus = BK.THIRST_SPEED + (self.thirst_end ~= nil and BK.THIRST_KILL_SPEED or 0)
            locomotor:SetExternalSpeedMultiplier(inst, "bk_thirst", 1 + bonus)
        else
            locomotor:RemoveExternalSpeedMultiplier(inst, "bk_thirst")
        end
    end
end

-- Unending Thirst: something we killed heals us and speeds us up.
function BloodKnight:OnKilled(data)
    if self.rune ~= "thirst" or data == nil or data.victim == nil then
        return
    end
    local health = self.inst.components.health
    if health ~= nil and not health:IsDead() then
        health:DoDelta(health.maxhealth * BK.THIRST_KILL_HEAL, false, "bk_thirst")
    end
    self.thirst_end = GetTime() + BK.THIRST_KILL_TIME
    self:ApplyRunePassives()
end

-- Fallen Crusader proc and Razorice stacks: on every hit we land.
function BloodKnight:RuneOnHit(target)
    local now = GetTime()
    if self.rune == "crusader" and math.random() < BK.CRUSADER_CHANCE then
        local inst = self.inst
        local health = inst.components.health
        if health ~= nil and not health:IsDead() then
            health:DoDelta(health.maxhealth * BK.CRUSADER_HEAL, false, "bk_crusader")
        end
        inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1 + BK.CRUSADER_DAMAGE, "bk_crusader")
        self.crusader_end = now + BK.CRUSADER_TIME
        local x, y, z = inst.Transform:GetWorldPosition()
        SpawnFx(FX.HEAL, x, 0, z)
    elseif self.rune == "razorice" and target ~= nil and target:IsValid() then
        local stack = self.razorice[target]
        if stack == nil then
            stack = { n = 0 }
            self.razorice[target] = stack
        end
        stack.n = math.min(BK.RAZORICE_MAX, stack.n + 1)
        stack.expire = now + BK.RAZORICE_TIME
    end
end

function BloodKnight:UpdateDefense()
    local mods = self.inst.components.combat ~= nil and self.inst.components.combat.externaldamagetakenmultipliers or nil
    if mods == nil then
        return
    end
    if self.shield > 0 then
        mods:SetModifier(self.inst, 1 - BK.SHIELD_REDUCTION, "bk_boneshield")
    else
        mods:RemoveModifier(self.inst, "bk_boneshield")
    end
    if self.in_decay then
        mods:SetModifier(self.inst, 1 - BK.DD_DEFENSE, "bk_decay")
    else
        mods:RemoveModifier(self.inst, "bk_decay")
    end
end

function BloodKnight:SetInDecay(inside)
    inside = inside and true or false
    if inside ~= self.in_decay then
        self.in_decay = inside
        self:UpdateDefense()
        self:MarkDirty()
    end
end

--------------------------------------------------------------------------
-- Casting
--------------------------------------------------------------------------

function BloodKnight:StartCooldown(id, now)
    self.ready[id] = now + BK.COOLDOWN[id]
    local nv = self.inst["_bk_cd" .. id]
    if nv ~= nil then
        nv:set((nv:value() + 1) % 256)
    end
    if id == DANCE then
        self:PublishDRWCooldown(now)
    end
end

-- Dancing Rune Weapon's cooldown can shrink (Bone Shield), so the HUD gets
-- the seconds left instead of only "it was cast".
function BloodKnight:PublishDRWCooldown(now)
    if self.inst._bk_drwcd ~= nil then
        self.inst._bk_drwcd:set(math.max(0, math.ceil(self.ready[DANCE] - now)))
    end
end

function BloodKnight:ReduceDRWCooldown(seconds)
    local now = GetTime()
    if self.ready[DANCE] > now then
        self.ready[DANCE] = math.max(now, self.ready[DANCE] - seconds)
        self:PublishDRWCooldown(now)
    end
end

-- While Dancing Rune Weapon is up, the rune weapon copies what you do.
-- kind: "melee", "hs", "ds", "bb" or "mr" (see bk_drw_blade.lua)
function BloodKnight:MirrorBlade(kind)
    local blade = self.drw_blade
    if self:IsDRWActive() and blade ~= nil and blade:IsValid() and blade.Mirror ~= nil then
        blade:Mirror(kind)
    end
end

function BloodKnight:Cast(id, hint)
    if type(id) ~= "number" or id < 1 or id > NUM_ABILITIES or id ~= math.floor(id) then
        return false
    end
    if self:IsIncapacitated() then
        return false
    end
    -- progression: the held Rune Blade's tier must be high enough
    if self.tier < BK.ABILITY_TIER[id] then
        return self:Fail(self.tier == 0 and "noblade" or "locked")
    end
    local now = GetTime()
    if now < self.ready[id] then
        return self:Fail("cooldown")
    end
    local fn = self.casters[id]
    if fn == nil then
        return false
    end
    local ok = fn(self, now, hint)
    if self.dirty then
        self:Publish()
    end
    return ok
end

-- Show an ability's swing. The ability has already dealt its damage.
function BloodKnight:PlaySwing(target)
    local inst = self.inst
    if target ~= nil and target:IsValid() then
        inst:ForceFacePoint(target.Transform:GetWorldPosition())
    end
    -- the player's own attack state with NO queued action: it plays the swing
    -- (animation + sound) but has nothing to hit, so no extra damage lands
    if inst.sg ~= nil and not inst.sg:HasAnyStateTag("busy", "attack")
        and not (inst.components.rider ~= nil and inst.components.rider:IsRiding()) then
        inst:ClearBufferedAction()
        inst.sg:GoToState("attack")
    end
    inst.components.combat:SetTarget(target) -- keep fighting it with normal attacks
end

-- Heart Strike lands the moment the key is pressed (like in WoW). It used
-- to wait for a real swing to connect, and any miss, step or busy moment
-- silently cancelled it; now the swing is only the animation.
local function CastHeartStrike(self, now)
    local free = self.freehs and now <= self.freehs_expire
    if not free and self.runes < BK.RUNE_COST[HEART] then
        return self:Fail("runes")
    end
    local target = self:FindPrimaryTarget()
    if target == nil then
        return self:Fail("target")
    end
    self:StartCooldown(HEART, now)
    self:ResolveHeartStrike(target, free, nil, true)
    self:PlaySwing(target)
    return true
end

local function CastDeathStrike(self, now)
    local health = self.inst.components.health
    if health == nil then
        return false
    end
    local cost = self:GetDeathStrikeCost()
    if RPValue(self.rp) < cost then
        return self:Fail("rp")
    end
    -- Death Strike needs an enemy in reach (no healing by swinging at air)
    local target = self:FindPrimaryTarget()
    if target == nil then
        return self:Fail("target")
    end
    self:AddRP(-cost)

    -- Coagulopathy: every Death Strike makes Blood Plague stronger for a while
    if self:HasTalent("coagulopathy") then
        self.coag = math.min(BK.COAG_MAX, self.coag + 1)
        self.coag_end = now + BK.COAG_TIME
    end

    -- Hemostasis: Blood Boil stacks make this Death Strike stronger, then are used up
    local power = 1 + self.hemo * BK.HEMO_PER_STACK
    self.hemo = 0

    local taken = self:GetRecentDamage(now)
    local heal = math.max(taken * BK.DS_HEAL_PCT, health.maxhealth * BK.DS_MIN_HEAL_PCT) * power
    health:DoDelta(heal, nil, "bk_deathstrike")
    if self:HasTalent("blooddebt") then
        self:AddDebt(1)
    end

    -- Blood Shield: part of the heal becomes an absorb shield (max = your max health)
    if self:HasTalent("bloodshield") then
        local absorb = heal * BK.DS_BLOOD_SHIELD
        if self.vb_end ~= nil then
            absorb = absorb * (1 + BK.VB_HEAL) -- Vampiric Blood: +30% absorbs too
        end
        self.blood_shield = math.min(self.blood_shield + absorb, health.maxhealth)
        self.blood_shield_end = now + BK.DS_BLOOD_SHIELD_TIME
    end
    self:MarkDirty()

    local x, y, z = self.inst.Transform:GetWorldPosition()
    SpawnFx(FX.HEAL, x, 0, z)

    -- the hit on the target lands right away (a normal hit plus the bonus, so
    -- Death Strike always hurts more than Heart Strike); the swing is only the animation
    local main_mult = (1 + BK.DS_TARGET_BONUS) * power
    if self.rune == "sanguination" and target.components.health ~= nil then
        -- Rune of Sanguination: the more health the target is missing, the harder it hits
        main_mult = main_mult * (1 + BK.SANGUINATION_DS_BONUS * (1 - target.components.health:GetPercent()))
    end
    self:HitTarget(target, main_mult)
    self:PlaySwing(target)

    -- Deadly Reach (like WoW): the 2 closest other enemies take 60% of the hit
    local others = {}
    for _, ent in ipairs(self:FindEnemies(x, y, z, BK.DS_REACH_RADIUS)) do
        if ent ~= target then
            table.insert(others, { ent = ent, dsq = self.inst:GetDistanceSqToInst(ent) })
        end
    end
    table.sort(others, function(a, b) return a.dsq < b.dsq end)
    for i = 1, math.min(#others, BK.DS_REACH_TARGETS) do
        local ent = others[i].ent
        self:HitTarget(ent, main_mult * BK.DS_REACH_MULT)
        local ex, ey, ez = ent.Transform:GetWorldPosition()
        SpawnFx(FX.WISP, ex, 0, ez)
    end
    self:MirrorBlade("ds")

    self:StartCooldown(DEATH, now)
    return true
end

function BloodKnight:ShadowBurst()
    local inst = self.inst
    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnFx(FX.PUFF_BIG, x, 0, z, 1.4)
    SpawnRing(x, z, BK.DEBT_BURST_RADIUS, "shadow")
    for _, ent in ipairs(self:FindEnemies(x, y, z, BK.DEBT_BURST_RADIUS)) do
        self:HitTarget(ent, BK.DEBT_BURST_MULT)
    end
end

function BloodKnight:StartDebtBuff(now)
    self.debt_buff_end = now + BK.DEBT_TIME
    self.inst.components.combat.externaldamagemultipliers:SetModifier(self.inst, BK.DEBT_DAMAGE, "bk_blooddebt")
    self:MarkDirty()
end

function BloodKnight:StopDebtBuff()
    if self.debt_buff_end ~= nil then
        self.debt_buff_end = nil
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "bk_blooddebt")
        self:MarkDirty()
    end
end

local function CastMarrowrend(self, now)
    if self.runes < BK.RUNE_COST[MARROW] then
        return self:Fail("runes")
    end
    self:SpendRunes(BK.RUNE_COST[MARROW])

    -- the strike itself (like WoW). Still castable with nobody in reach, so
    -- you can build Bone Shield before a fight.
    local target = self:FindPrimaryTarget()
    if target ~= nil then
        self:HitTarget(target, BK.MR_MULT)
        local tx, ty, tz = target.Transform:GetWorldPosition()
        SpawnFx(FX.WISP, tx, 0, tz)
        self:PlaySwing(target)
    end

    local gain = BK.SHIELD_PER_MARROWREND
    if self.debt >= BK.DEBT_MAX and self:HasTalent("blooddebt") then
        -- Blood Debt payoff
        self:SetDebt(0)
        self:StartDebtBuff(now)
        gain = gain + BK.DEBT_EXTRA_SHIELD
        self:ShadowBurst()
    end
    self:AddShield(gain)

    local x, y, z = self.inst.Transform:GetWorldPosition()
    SpawnFx(FX.SHIELD, x, 0, z)
    self:MirrorBlade("mr")

    self:StartCooldown(MARROW, now)
    return true
end

-- Red glow on an enemy while it has Blood Plague, so the debuff is visible.
-- colouradder is the stock component that lets several effects (freezing,
-- this glow, ...) tint the same creature without overwriting each other.
local function SetPlagueTint(ent, on)
    if not ent:IsValid() or ent.AnimState == nil then
        return
    end
    if on then
        if ent.components.colouradder == nil then
            ent:AddComponent("colouradder")
        end
        local c = BK.PLAGUE_TINT
        ent.components.colouradder:PushColour("bk_plague", c[1], c[2], c[3], 0)
    elseif ent.components.colouradder ~= nil then
        ent.components.colouradder:PopColour("bk_plague")
    end
end

function BloodKnight:ApplyPlague(ent)
    if ent == nil or not ent:IsValid() then
        return
    end
    local fresh = self.plague[ent] == nil
    self.plague[ent] = GetTime() + BK.PLAGUE_TIME
    if fresh then
        SetPlagueTint(ent, true)
        local x, y, z = ent.Transform:GetWorldPosition()
        SpawnFx(FX.PUFF, x, 0, z, 0.6)
    end
end

-- Remove Blood Plague from every enemy (and their red glow).
function BloodKnight:ClearPlague()
    for ent in pairs(self.plague) do
        SetPlagueTint(ent, false)
    end
    self.plague = {}
end

-- Blood Boil uses charges instead of runes: it stores up to BB_CHARGES uses,
-- and gets one back every BB_RECHARGE seconds (see OnUpdate).
local function CastBloodBoil(self, now)
    if self.bb_charges <= 0 then
        return self:Fail("charges")
    end
    -- like in WoW it can be cast with nobody around (it just hits nothing)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local enemies = self:FindEnemies(x, y, z, BK.BB_RADIUS)
    self.bb_charges = self.bb_charges - 1
    self:MarkDirty()

    SpawnRing(x, z, BK.BB_RADIUS, "horror")
    SpawnFx(FX.PUFF_BIG, x, 0, z, 1.0)
    for _, ent in ipairs(enemies) do
        self:HitTarget(ent, BK.BB_MULT * BK.DAMAGE_SCALE)
        self:ApplyPlague(ent)
    end
    -- Hemostasis: one stack per enemy hit, for the next Death Strike
    if self:HasTalent("hemostasis") then
        self.hemo = math.min(BK.HEMO_MAX, self.hemo + #enemies)
    end
    self:MirrorBlade("bb")

    self:StartCooldown(BOIL, now)
    return true
end

function BloodKnight:RemoveZone()
    local zone = self.zone
    self.zone = nil
    if zone ~= nil and zone:IsValid() then
        zone:Remove()
    end
    self:SetInDecay(false)
end

-- 2 charges, one back every DD_RECHARGE seconds (see OnUpdate). Crimson
-- Scourge makes it free.
local function CastDeathAndDecay(self, now)
    if self.dd_charges <= 0 then
        return self:Fail("charges")
    end
    local free = self.crimson_end ~= nil
    if not free and self.runes < BK.RUNE_COST[DECAY] then
        return self:Fail("runes")
    end
    if free then
        self.crimson_end = nil
    else
        self:SpendRunes(BK.RUNE_COST[DECAY])
    end
    self.dd_charges = self.dd_charges - 1
    self:MarkDirty()

    self:RemoveZone()
    local zone = SpawnPrefab("bk_decayzone")
    if zone ~= nil then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        zone.Transform:SetPosition(x, 0, z)
        zone:Setup(self.inst, BK.DD_RADIUS, BK.DD_TIME, BK.DD_DPS * BK.DAMAGE_SCALE, BK.DD_TICK)
        self.zone = zone
    end

    self:StartCooldown(DECAY, now)
    return true
end

function BloodKnight:StartDRW(duration)
    local now = GetTime()
    local new_end = now + duration
    if self.drw_end ~= nil and self.drw_end >= new_end then
        return false
    end
    self.drw_end = new_end

    local inst = self.inst
    -- Dance of Midnight ranks 2-3: stronger and tougher while a rune weapon is out
    inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1 + BK.DOM_DAMAGE, "bk_dom")
    inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1 - BK.DOM_DEFENSE, "bk_dom")
    local x, y, z = inst.Transform:GetWorldPosition()
    if self.drw_blade == nil or not self.drw_blade:IsValid() then
        local blade = SpawnPrefab("bk_drw_blade")
        if blade ~= nil then
            blade.Transform:SetPosition(x, 0, z)
            blade:Setup(inst, BK.DRW_BLADE_MULT * BK.DAMAGE_SCALE)
            self.drw_blade = blade
        end
    end
    SpawnFx(FX.PORTAL_IN, x, 0, z)
    SpawnFx(FX.SMOKE, x, 0, z, 1.0)

    if inst._bk_drwlen ~= nil then
        inst._bk_drwlen:set(math.min(255, math.floor(duration * 10)))
    end
    self:MarkDirty()
    return true
end

function BloodKnight:StopDRW()
    if self.drw_end == nil then
        return
    end
    self.drw_end = nil
    self.drw_haste_on_end = false
    self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "bk_dom")
    self.inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(self.inst, "bk_dom")
    local blade = self.drw_blade
    self.drw_blade = nil
    if blade ~= nil and blade:IsValid() then
        blade:Retire()
    end
    if self.inst._bk_drwlen ~= nil then
        self.inst._bk_drwlen:set(0)
    end
    self:MarkDirty()
end

local function CastDancingRuneWeapon(self, now)
    self:StopDRW() -- a Dance of Midnight proc is replaced by the real thing
    self:StartDRW(BK.DRW_TIME)
    self.drw_haste_on_end = true
    self:StartCooldown(DANCE, now)
    return true
end

-- Death Grip: pull the enemy in front of you and taunt it.
-- Bosses ("epic") are too big to pull: they are only taunted.
local function CastDeathGrip(self, now, hint)
    local inst = self.inst
    local target = self:PickTauntTarget(hint, BK.GRIP_RANGE)
    if target == nil then
        return self:Fail("target")
    end
    local tx, ty, tz = target.Transform:GetWorldPosition()
    SpawnFx(FX.PORTAL_OUT, tx, 0, tz)
    if not target:HasTag("epic") then
        local x, y, z = inst.Transform:GetWorldPosition()
        local dx, dz = tx - x, tz - z
        local dist = math.sqrt(dx * dx + dz * dz)
        local land = BK.GRIP_DISTANCE + target:GetPhysicsRadius(0) + inst:GetPhysicsRadius(0)
        if dist > land then
            local nx, nz = x + dx / dist * land, z + dz / dist * land
            if target.components.locomotor ~= nil then
                target.components.locomotor:Stop()
            end
            if target.Physics ~= nil then
                target.Physics:Teleport(nx, 0, nz)
            else
                target.Transform:SetPosition(nx, 0, nz)
            end
            SpawnFx(FX.PORTAL_IN, nx, 0, nz)
        end
    end
    self:Taunt(target, BK.TAUNT_TIME)
    inst:ForceFacePoint(target.Transform:GetWorldPosition())
    self:NoteCombat()
    self:StartCooldown(GRIP, now)
    return true
end

-- Dark Command: taunt from range.
local function CastDarkCommand(self, now, hint)
    local target = self:PickTauntTarget(hint, BK.DC_RANGE)
    if target == nil then
        return self:Fail("target")
    end
    self:Taunt(target, BK.TAUNT_TIME)
    local x, y, z = target.Transform:GetWorldPosition()
    SpawnFx(FX.PUFF, x, 0, z, 1.0)
    SpawnFx(FX.WISP, x, 0, z)
    self.inst:ForceFacePoint(x, y, z)
    self:NoteCombat()
    self:StartCooldown(COMMAND, now)
    return true
end

-- Vampiric Blood: +30% max health (and you get that health), +30% healing
-- and absorbs received, for a few seconds.
local function CastVampiricBlood(self, now)
    local health = self.inst.components.health
    if health == nil or self.vb_end ~= nil then
        return false
    end
    self.vb_base_max = health.maxhealth
    local extra = health.maxhealth * BK.VB_HEALTH
    health.maxhealth = health.maxhealth + extra
    health:DoDelta(extra, true, "bk_vampiricblood", true) -- before vb_end is set: no heal bonus on this
    self.vb_end = now + BK.VB_TIME

    local x, y, z = self.inst.Transform:GetWorldPosition()
    SpawnFx(FX.HEAL, x, 0, z)
    SpawnRing(x, z, 2, "horror")
    self:MarkDirty()
    self:StartCooldown(VAMPIRIC, now)
    return true
end

function BloodKnight:StopVampiricBlood()
    if self.vb_end == nil then
        return
    end
    self.vb_end = nil
    local health = self.inst.components.health
    if health ~= nil and self.vb_base_max ~= nil then
        health.maxhealth = self.vb_base_max
        health:ForceUpdateHUD(true) -- caps current health at the normal max
    end
    self.vb_base_max = nil
    self:MarkDirty()
end

-- Raise Dead (Blood version): a ghoul fights for you for a minute.
-- Placeholder ghoul: Maxwell's Shadow Protector, renamed and tinted, because
-- it already follows a leader and fights whatever attacks or is attacked by him.
function BloodKnight:DespawnGhoul()
    if self.ghoul_task ~= nil then
        self.ghoul_task:Cancel()
        self.ghoul_task = nil
    end
    local ghoul = self.ghoul
    self.ghoul = nil
    if ghoul ~= nil and ghoul:IsValid() then
        local x, y, z = ghoul.Transform:GetWorldPosition()
        local fx = SpawnPrefab("shadow_despawn")
        if fx ~= nil then
            fx.Transform:SetPosition(x, y, z)
        end
        ghoul:Remove()
    end
end

local function CastRaiseDead(self, now)
    local inst = self.inst
    self:DespawnGhoul() -- one ghoul at a time
    local ghoul = SpawnPrefab("shadowprotector")
    if ghoul == nil then
        return false
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local angle = math.random() * 2 * PI
    local px, pz = x + math.cos(angle) * 2, z - math.sin(angle) * 2
    if ghoul.Physics ~= nil then
        ghoul.Physics:Teleport(px, 0, pz)
    else
        ghoul.Transform:SetPosition(px, 0, pz)
    end
    ghoul.persists = false -- the ghoul does not survive a save
    ghoul.components.follower:SetLeader(inst)
    if ghoul.components.named == nil then
        ghoul:AddComponent("named")
    end
    ghoul.components.named:SetName(STRINGS.NAMES.BK_GHOUL)
    ghoul.AnimState:SetAddColour(0.25, 0.05, 0.05, 0) -- dark red: one of the Blood Knight's own

    SpawnFx(FX.SMOKE, px, 0, pz, 1.0)
    SpawnFx(FX.PUFF_BIG, px, 0, pz, 1.0)

    self.ghoul = ghoul
    self.ghoul_task = inst:DoTaskInTime(BK.GHOUL_TIME, function() self:DespawnGhoul() end)
    ghoul:ListenForEvent("onremove", function()
        if self.ghoul == ghoul then
            self.ghoul = nil
        end
    end)
    self:StartCooldown(RAISEDEAD, now)
    return true
end

BloodKnight.casters =
{
    [HEART] = CastHeartStrike,
    [DEATH] = CastDeathStrike,
    [MARROW] = CastMarrowrend,
    [BOIL] = CastBloodBoil,
    [DECAY] = CastDeathAndDecay,
    [DANCE] = CastDancingRuneWeapon,
    [GRIP] = CastDeathGrip,
    [COMMAND] = CastDarkCommand,
    [VAMPIRIC] = CastVampiricBlood,
    [RAISEDEAD] = CastRaiseDead,
}

--------------------------------------------------------------------------
-- Combat events
--------------------------------------------------------------------------

-- hit_main: also deal the main hit (pressed key). In "auto" mode the
-- player's real swing is the main hit, so it is left out there.
function BloodKnight:ResolveHeartStrike(target, free, weapon, hit_main)
    if not free then
        if not self:SpendRunes(BK.RUNE_COST[HEART]) then
            return
        end
    else
        self.freehs = false
    end

    -- Dance of Midnight: a free Heart Strike deals +150% damage
    local power = free and (1 + BK.DOM_HS_BONUS) or 1
    if hit_main then
        self:HitTarget(target, power, weapon)
    elseif free then
        self:HitTarget(target, BK.DOM_HS_BONUS, weapon) -- auto mode: the swing was the normal part
    end
    ApplySlow(target)

    local gain = BK.RP_PER_HEART_STRIKE
    if self:IsDRWActive() then
        gain = gain + BK.RP_DRW_BONUS -- the rune weapon's copy of the strike
        self:MirrorBlade("hs")
    end
    self:AddRP(gain)

    self:Taunt(target) -- threat: the main target turns to us

    -- cleave: the main target already took the normal hit, now more enemies
    -- around the Blood Knight get hit too. Standing in Death and Decay lets
    -- Heart Strike reach more of them.
    local max_targets = self.in_decay and BK.HS_TARGETS_DECAY or BK.HS_TARGETS
    local px, py, pz = self.inst.Transform:GetWorldPosition()
    local hit = 0
    for _, ent in ipairs(self:FindEnemies(px, py, pz, BK.HS_CLEAVE_RADIUS)) do
        if ent ~= target and hit < max_targets - 1 then
            hit = hit + 1
            self:HitTarget(ent, BK.HS_CLEAVE_MULT * power, weapon)
            ApplySlow(ent)
            local ex, ey, ez = ent.Transform:GetWorldPosition()
            SpawnFx(FX.WISP, ex, 0, ez)
        end
    end
    local x, y, z = target.Transform:GetWorldPosition()
    SpawnFx(FX.WISP, x, 0, z)
    SpawnRing(px, pz, BK.HS_CLEAVE_RADIUS, "horror")

    -- heal for every enemy hit (main target + the sweep)
    local health = self.inst.components.health
    if health ~= nil and not health:IsDead() then
        local heal = math.min((hit + 1) * BK.HS_HEAL_PER_ENEMY, BK.HS_HEAL_MAX)
        health:DoDelta(heal, nil, "bk_heartstrike")
    end
    self:MarkDirty()
end

function BloodKnight:OnAttackOther(data)
    if data == nil or data.target == nil then
        return
    end
    self:NoteCombat()

    local now = GetTime()
    if BK.AUTO_HS and self.tier >= BK.ABILITY_TIER[HEART] and now >= self.ready[HEART]
        and (self.runes >= 2 or (self.freehs and now <= self.freehs_expire))
        and self:IsEnemy(data.target, true) then
        -- "auto" mode: ordinary swings become Heart Strikes
        local free = self.freehs and now <= self.freehs_expire
        -- damage is worked out right after this event: tell the Rune Blade it is an ability
        self._ability_swing = { target = data.target, time = now }
        self:StartCooldown(HEART, now)
        self:ResolveHeartStrike(data.target, free, data.weapon)
    else
        -- an ordinary attack: the rune weapon copies it
        self:MirrorBlade("melee")
    end
    if self.dirty then
        self:Publish()
    end
end

-- A hit landed. Only real swings count here, not ability hits (HitTarget).
function BloodKnight:OnHitOther(data)
    self:NoteCombat()
    if data == nil or data.target == nil then
        return
    end
    self:RuneOnHit(data.target) -- runes work on every hit, abilities included
    if self._ability_hit then
        return
    end
    -- Crimson Scourge: a swing on a plagued enemy may refund Death and Decay
    if self.plague[data.target] ~= nil and self:HasTalent("crimson") and math.random() < BK.CRIMSON_CHANCE then
        if self.dd_charges < BK.DD_CHARGES then
            self.dd_charges = self.dd_charges + 1
        end
        self.crimson_end = GetTime() + BK.CRIMSON_TIME
        local x, y, z = self.inst.Transform:GetWorldPosition()
        SpawnFx(FX.PUFF, x, 0, z, 0.8)
        self:MarkDirty()
        self:Publish()
    end
end

function BloodKnight:OnAttacked(data)
    self:NoteCombat()
    if data == nil or data.attacker == nil then
        return
    end
    local now = GetTime()
    if self.shield > 0 and now >= self.shield_next_loss then
        self.shield_next_loss = now + BK.SHIELD_HIT_ICD
        self:SetShield(self.shield - 1)
        self:ReduceDRWCooldown(BK.DRW_CDR_PER_SHIELD)
        if self.shield == 0 then
            self:TryBoneShard(now)
        end
    end
    if self.dirty then
        self:Publish()
    end
end

-- Bone Shards in the inventory rebuild a broken Bone Shield.
function BloodKnight:TryBoneShard(now)
    if now < self.shard_ready then
        return false
    end
    local inv = self.inst.components.inventory
    if inv == nil or not inv:Has("boneshard", 1) then
        return false
    end
    inv:ConsumeByName("boneshard", 1)
    self.shard_ready = now + BK.SHARD_ICD
    self:AddShield(BK.SHARD_STACKS)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    SpawnFx(FX.SHIELD, x, 0, z)
    return true
end

function BloodKnight:OnHealthDelta(data)
    if data == nil or data.amount == nil or data.amount >= 0 then
        return
    end
    -- Rune of Sanguination: dropping low starts a heal over time (once per 2 min)
    local health = self.inst.components.health
    if self.rune == "sanguination" and health ~= nil and not health:IsDead()
        and health:GetPercent() < BK.SANGUINATION_THRESHOLD and GetTime() >= self.sang_ready then
        self.sang_ready = GetTime() + BK.SANGUINATION_COOLDOWN
        self.sang_end = GetTime() + BK.SANGUINATION_TIME
        local x, y, z = self.inst.Transform:GetWorldPosition()
        SpawnFx(FX.HEAL, x, 0, z)
    end
    if data.cause ~= nil and IGNORED_DAMAGE_CAUSES[data.cause] then
        return
    end
    local now = GetTime()
    table.insert(self.recent, { t = now, amt = -data.amount })
    -- forget anything outside the window (and keep the list short)
    while #self.recent > 0 and (now - self.recent[1].t > BK.DS_WINDOW or #self.recent > 60) do
        table.remove(self.recent, 1)
    end
end

function BloodKnight:GetRecentDamage(now)
    local total = 0
    for _, e in ipairs(self.recent) do
        if now - e.t <= BK.DS_WINDOW then
            total = total + e.amt
        end
    end
    return total
end

function BloodKnight:OnDodge(attacker)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    SpawnFx(FX.PUFF, x, 0, z, 0.8)
    if self:IsDRWActive() and self:HasTalent("dance") and math.random() < BK.DOM_DODGE_CHANCE then
        -- Dance of Midnight: the next Heart Strike is free and deals +150% damage
        self.freehs = true
        self.freehs_expire = GetTime() + BK.DRW_FREE_HS_TIME
        self:MarkDirty()
    end
    self.inst:PushEvent("bk_dodged", { attacker = attacker })
    if self.dirty then
        self:Publish()
    end
end

--------------------------------------------------------------------------
-- Blood Plague
--------------------------------------------------------------------------

function BloodKnight:TickPlague(now)
    local inst = self.inst
    local dps = BK.PLAGUE_DPS * BK.DAMAGE_SCALE * (1 + self.coag * BK.COAG_PER_STACK) -- Coagulopathy
    local show_fx = false
    self.plague_fx_tick = self.plague_fx_tick + 1
    if self.plague_fx_tick >= 3 then
        self.plague_fx_tick = 0
        show_fx = true
    end

    local shown = 0
    local sick = 0 -- enemies hurt this tick, each one heals the Blood Knight
    for ent, expire in pairs(self.plague) do
        local health = ent:IsValid() and ent.components.health or nil
        if health == nil or health:IsDead() or now >= expire then
            self.plague[ent] = nil
            SetPlagueTint(ent, false)
        else
            sick = sick + 1
            health:DoDelta(-dps, true, "bk_plague", nil, inst)
            if ent.components.combat ~= nil then
                ent.components.combat:SuggestTarget(inst)
            end
            if show_fx and shown < 6 then
                shown = shown + 1
                local x, y, z = ent.Transform:GetWorldPosition()
                SpawnFx(FX.WISP, x, 0, z, 0.7)
            end
        end
    end

    -- the plague feeds the Blood Knight: slow healing while enemies are sick
    local myhealth = inst.components.health
    if sick > 0 and myhealth ~= nil and not myhealth:IsDead() then
        local heal = math.min(sick * BK.PLAGUE_HEAL_PER_TARGET, BK.PLAGUE_HEAL_MAX)
        myhealth:DoDelta(heal, true, "bk_plague")
    end
end

--------------------------------------------------------------------------
-- Souls (Wortox's soul system) for the Death Knight Plate / Helm
--------------------------------------------------------------------------

-- Is a living Wortox (or any other "soulstealer") close to this spot?
-- Then the souls are left to him, so the mod never steals Wortox's souls.
local function IsSoulStealerNear(x, y, z)
    local rangesq = TUNING.WORTOX_SOULEXTRACT_RANGE * TUNING.WORTOX_SOULEXTRACT_RANGE
    for _, p in ipairs(AllPlayers) do
        if p:HasTag("soulstealer") and not p:HasTag("playerghost")
            and p:GetDistanceSqToPoint(x, y, z) < rangesq then
            return true
        end
    end
    return false
end

-- Throw one of Wortox's flying souls from the corpse at the Blood Knight.
-- When it arrives, Wortox's own code puts a "wortox_soul" item into our
-- inventory, and the gear (bk_soulgear.lua) eats it from there.
local function ThrowSoul(soul, owner)
    if soul:IsValid() and owner:IsValid() and not owner:HasTag("playerghost")
        and soul.components.projectile ~= nil then
        soul.components.projectile:SetSpeed(TUNING.WORTOX_SOUL_PROJECTILE_SPEED)
        soul.components.projectile:Throw(soul, owner, owner)
    end
    -- otherwise the soul just times out and pops like an unclaimed Wortox soul
end

function BloodKnight:OnEntityDeath(data)
    local inst = self.inst
    local victim = data ~= nil and data.inst or nil
    if victim == nil or victim == inst or not victim:IsValid() or victim.nosoultask ~= nil
        or inst:HasTag("playerghost") or inst.components.health:IsDead()
        or not wortox_soul_common.HasSoul(victim)
        or not inst:IsNear(victim, TUNING.WORTOX_SOULEXTRACT_RANGE) then
        return
    end
    local x, y, z = victim.Transform:GetWorldPosition()
    if IsSoulStealerNear(x, y, z) then
        return
    end

    -- same guard Wortox uses: only one soul drop per corpse
    victim.nosoultask = victim:DoTaskInTime(5, function() victim.nosoultask = nil end)

    local count = wortox_soul_common.GetNumSouls(victim)
    for i = 1, count do
        local soul = SpawnPrefab("wortox_soul_spawn")
        if soul ~= nil then
            local angle = math.random() * 2 * PI
            local radius = count > 1 and (0.4 + math.random() * 1.2) or 0
            soul.Transform:SetPosition(x + math.cos(angle) * radius, 0, z - math.sin(angle) * radius)
            soul:Setup(victim)
            -- stop it looking for a Wortox; it comes to us instead
            if soul._seektask ~= nil then
                soul._seektask:Cancel()
                soul._seektask = nil
            end
            soul:DoTaskInTime(BK.SOUL_FLY_DELAY + i * 0.1, ThrowSoul, inst)
        end
    end
end

--------------------------------------------------------------------------
-- Update loop
--------------------------------------------------------------------------

function BloodKnight:OnUpdate(dt)
    local inst = self.inst
    if inst:HasTag("playerghost") then
        return
    end
    local now = GetTime()

    -- crafting stations nearby? (twice a second is plenty)
    self.station_acc = self.station_acc + dt
    if self.station_acc >= 0.5 then
        self.station_acc = 0
        self:UpdateStations()
    end

    -- rune recharge: the first RUNES_RECHARGING missing runes fill up at the
    -- same time; when one is done, the next one in the queue starts
    local recharging = math.min(#self.rune_prog, BK.RUNES_RECHARGING)
    local rate = 1
    if self.thirst_end ~= nil then
        rate = rate + BK.THIRST_KILL_SPEED -- Unending Thirst kill buff
    end
    if self.rune_haste_end ~= nil then
        if now < self.rune_haste_end then
            rate = rate + BK.DRW_END_HASTE -- just after Dancing Rune Weapon
        else
            self.rune_haste_end = nil
        end
    end
    for i = 1, recharging do
        self.rune_prog[i] = self.rune_prog[i] + dt * rate
    end
    while self.rune_prog[1] ~= nil and self.rune_prog[1] >= BK.RUNE_RECHARGE do
        table.remove(self.rune_prog, 1)
        self.runes = math.min(self.runes + 1, BK.RUNES_MAX)
        self:MarkDirty()
    end
    -- progress changes in 5% steps, publish when a step is crossed
    if not self.dirty then
        for i = 1, BK.RUNES_RECHARGING do
            local netvar = inst["_bk_runeprog" .. (i == 1 and "" or i)]
            if netvar ~= nil and netvar:value() ~= self:RuneStep(i) then
                self:MarkDirty()
                break
            end
        end
    end

    -- Blood Boil charges come back one at a time, like runes
    if self.bb_charges < BK.BB_CHARGES then
        self.bb_timer = self.bb_timer + dt
        if self.bb_timer >= BK.BB_RECHARGE then
            self.bb_timer = self.bb_timer - BK.BB_RECHARGE
            self.bb_charges = self.bb_charges + 1
            if self.bb_charges >= BK.BB_CHARGES then
                self.bb_timer = 0
            end
            self:MarkDirty()
        else
            local step = math.floor(Clamp(self.bb_timer / BK.BB_RECHARGE, 0, 0.99) * 20) * 5
            if inst._bk_bbprog ~= nil and inst._bk_bbprog:value() ~= step then
                self:MarkDirty()
            end
        end
    end

    -- Death and Decay charges, like Blood Boil's
    if self.dd_charges < BK.DD_CHARGES then
        self.dd_timer = self.dd_timer + dt
        if self.dd_timer >= BK.DD_RECHARGE then
            self.dd_timer = self.dd_timer - BK.DD_RECHARGE
            self.dd_charges = self.dd_charges + 1
            if self.dd_charges >= BK.DD_CHARGES then
                self.dd_timer = 0
            end
            self:MarkDirty()
        else
            local step = math.floor(Clamp(self.dd_timer / BK.DD_RECHARGE, 0, 0.99) * 20) * 5
            if inst._bk_ddprog ~= nil and inst._bk_ddprog:value() ~= step then
                self:MarkDirty()
            end
        end
    end
    if self.crimson_end ~= nil and now >= self.crimson_end then
        self.crimson_end = nil
        self:MarkDirty()
    end

    -- Runic Power drains when you stop fighting
    if self.rp > 0 and now - self.last_combat > BK.RP_DECAY_DELAY then
        self:AddRP(-BK.RP_DECAY_RATE * dt)
    end

    -- Blood Plague
    if next(self.plague) ~= nil then
        self.plague_acc = self.plague_acc + dt
        if self.plague_acc >= 1 then
            self.plague_acc = self.plague_acc - 1
            self:TickPlague(now)
        end
    end

    -- timed buffs
    if self.drw_end ~= nil and now >= self.drw_end then
        if self.drw_haste_on_end then
            -- the weapon fades: runes recharge faster for a while
            self.rune_haste_end = now + BK.DRW_END_HASTE_TIME
        end
        self:StopDRW()
    end
    if next(self.taunted) ~= nil then
        self:UpdateTaunts(now)
    end
    if self.vb_end ~= nil and now >= self.vb_end then
        self:StopVampiricBlood()
    end
    if self.purg_end ~= nil and now >= self.purg_end then
        self:EndPurgatory()
    end
    -- Purgatory cooldown for the HUD, in whole seconds
    if inst._bk_purgcd ~= nil then
        local left = math.max(0, math.ceil(self.purg_ready - now))
        if inst._bk_purgcd:value() ~= left then
            inst._bk_purgcd:set(left)
        end
    end
    if self.shield_end ~= nil and now >= self.shield_end then
        self.shield_end = nil
        self:SetShield(0) -- Bone Shield faded
    end
    -- runes: timers
    if self.crusader_end ~= nil and now >= self.crusader_end then
        self.crusader_end = nil
        inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "bk_crusader")
    end
    if self.thirst_end ~= nil and now >= self.thirst_end then
        self.thirst_end = nil
        self:ApplyRunePassives()
    end
    if self.sang_end ~= nil then
        if now >= self.sang_end then
            self.sang_end = nil
        elseif inst.components.health ~= nil and not inst.components.health:IsDead() then
            local per_second = inst.components.health.maxhealth * BK.SANGUINATION_HEAL / BK.SANGUINATION_TIME
            inst.components.health:DoDelta(per_second * dt, true, "bk_sanguination")
        end
    end
    for ent, stack in pairs(self.razorice) do
        if now >= stack.expire or not ent:IsValid() then
            self.razorice[ent] = nil
        end
    end
    if self.coag_end ~= nil and now >= self.coag_end then
        self.coag_end = nil
        self.coag = 0
    end
    if self.blood_shield_end ~= nil and now >= self.blood_shield_end then
        self.blood_shield_end = nil
        self.blood_shield = 0
        self:MarkDirty()
    end
    if self.debt_buff_end ~= nil and now >= self.debt_buff_end then
        self:StopDebtBuff()
    end
    if self.freehs and now > self.freehs_expire then
        self.freehs = false
        self:MarkDirty()
    end

    if self.zone ~= nil and not self.zone:IsValid() then
        self.zone = nil
        self:SetInDecay(false)
    end

    if self.dirty then
        self:Publish()
    end
end

--------------------------------------------------------------------------
-- Reset / save / cleanup
--------------------------------------------------------------------------

-- Remove everything that is "alive in the world" (zone, blade, DoTs, buffs).
function BloodKnight:ClearTransient()
    self:StopDRW()
    self:StopVampiricBlood()
    self:EndPurgatory(true) -- dead or reset: nothing more to settle
    if self.crusader_end ~= nil then
        self.crusader_end = nil
        self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "bk_crusader")
    end
    self.sang_end = nil
    self.thirst_end = nil
    self.razorice = {}
    self:ApplyRunePassives()
    self:DespawnGhoul()
    self.taunted = {}
    self:StopDebtBuff()
    self:RemoveZone()
    self:ClearPlague()
    self.blood_shield = 0
    self.blood_shield_end = nil
    self.hemo = 0
    self.coag = 0
    self.coag_end = nil
    self.freehs = false
    self:SetInDecay(false)
    self:MarkDirty()
end

function BloodKnight:Reset()
    self:ClearTransient()
    self.runes = BK.RUNES_MAX
    self.rune_prog = {}
    self.rune_haste_end = nil
    self.bb_charges = BK.BB_CHARGES
    self.bb_timer = 0
    self.dd_charges = BK.DD_CHARGES
    self.dd_timer = 0
    self.crimson_end = nil
    self.rp = 0
    self.debt = 0
    self.recent = {}
    self:SetShield(0)
    for i = 1, NUM_ABILITIES do
        self.ready[i] = 0
    end
    self:UpdateDefense()
    self:MarkDirty()
    self:Publish()
end

function BloodKnight:OnSave()
    return { runes = self.runes, rp = RPValue(self.rp), shield = self.shield, debt = self.debt }
end

function BloodKnight:OnLoad(data)
    if data == nil then
        return
    end
    self.runes = Clamp(data.runes or self.runes, 0, BK.RUNES_MAX)
    self.rune_prog = {}
    for i = 1, BK.RUNES_MAX - self.runes do
        table.insert(self.rune_prog, 0) -- missing runes start recharging from zero
    end
    self.rp = Clamp(data.rp or 0, 0, BK.RP_MAX + BK.OSSUARY_RP_BONUS) -- clamped again by SetShield
    self:SetDebt(data.debt or 0) -- (also restores the per-stack damage bonus)
    self:SetShield(data.shield or 0)
    if self.shield > 0 then
        self.shield_end = GetTime() + BK.SHIELD_TIME -- a saved shield gets a fresh 30 s
    end
    self:AddRP(0) -- keep Runic Power within the max (depends on Ossuary)
    self.last_combat = GetTime() -- start the Runic Power decay delay fresh
    self:UpdateDefense()
    self:MarkDirty()
    self:Publish()
end

function BloodKnight:OnRemoveFromEntity()
    local inst = self.inst
    if inst.components.health ~= nil then
        inst.components.health.deltamodifierfn = self._prev_deltamodifier
    end
    if inst.components.combat ~= nil then
        inst.components.combat.customdamagemultfn = self._prev_damagemult
    end
    inst:RemoveEventCallback("attacked", self._onattacked)
    inst:RemoveEventCallback("healthdelta", self._onhealthdelta)
    inst:RemoveEventCallback("onattackother", self._onattackother)
    inst:RemoveEventCallback("onhitother", self._onhitother)
    inst:RemoveEventCallback("death", self._ondeath)
    inst:RemoveEventCallback("ms_becameghost", self._onbecameghost)
    inst:RemoveEventCallback("ms_respawnedfromghost", self._onrespawned)
    inst:RemoveEventCallback("equip", self._onequipchange)
    inst:RemoveEventCallback("unequip", self._onequipchange)
    inst:RemoveEventCallback("entity_death", self._onentitydeath, TheWorld)
    inst:RemoveEventCallback("killed", self._onkilled)
    self:ClearTransient()
    if inst.components.combat ~= nil then
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "bk_boneshield")
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "bk_decay")
    end
end

function BloodKnight:GetDebugString()
    return string.format("runes %d (%.1f/%d) rp %.0f shield %d debt %d drw %s",
        self.runes, self.rune_prog[1] or 0, BK.RUNE_RECHARGE, self.rp, self.shield, self.debt,
        tostring(self:IsDRWActive()))
end

return BloodKnight
