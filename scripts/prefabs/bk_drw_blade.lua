-- The spectral blade of Dancing Rune Weapon. Like in World of Warcraft it
-- does not attack on its own: it floats next to the enemy the Blood Knight
-- is fighting and COPIES every attack and ability the Blood Knight uses
-- (the component calls inst:Mirror(kind), see MirrorBlade).
--
-- Placeholder look: the Dark Sword, translucent and red. Replace it by
-- drawing anim/bk_drw_blade.zip (see ART_GUIDE.md).

local ART = rawget(_G, "BK_ART") or {}
local BK = TUNING.BK
local FX = BK.FX

local BANK, BUILD = "nightmaresword", "nightmaresword"
local assets = {}
if ART.drwblade then
    BANK, BUILD = "bk_drw_blade", "bk_drw_blade"
    table.insert(assets, Asset("ANIM", "anim/bk_drw_blade.zip"))
else
    table.insert(assets, Asset("ANIM", "anim/nightmaresword.zip"))
end

local prefabs = { FX.WISP, FX.SMOKE }

local HOVER_HEIGHT = 1.2
local FOLLOW_DISTANCE = 1.8     -- how far beside the owner it idles
local SEARCH_RADIUS = 8         -- where it looks for something to cut
local STRIKE_RANGE = 2.4
local MIRROR_RANGE = 6          -- the copy only lands if the blade is this close to its target
local SPEED = 11                -- world units per second
local RETARGET_PERIOD = 0.3

local function ChooseTarget(inst)
    local owner = inst.owner
    local bk = owner.components.bk_bloodknight
    if bk == nil then
        return nil
    end

    -- the owner's current fight comes first
    local current = owner.components.combat ~= nil and owner.components.combat.target or nil
    if current ~= nil and current:IsValid() and bk:IsEnemy(current, true)
        and owner:GetDistanceSqToInst(current) <= SEARCH_RADIUS * SEARCH_RADIUS then
        return current
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local best, bestdsq
    for _, ent in ipairs(bk:FindEnemies(x, y, z, SEARCH_RADIUS)) do
        local dsq = owner:GetDistanceSqToInst(ent)
        if bestdsq == nil or dsq < bestdsq then
            best, bestdsq = ent, dsq
        end
    end
    return best
end

local function OnUpdate(inst, dt)
    local owner = inst.owner
    if owner == nil or not owner:IsValid() or inst.retiring then
        return
    end

    local now = GetTime()
    if now >= inst.next_retarget then
        inst.next_retarget = now + RETARGET_PERIOD
        inst.target = ChooseTarget(inst)
    end

    local target = inst.target
    if target ~= nil and (not target:IsValid() or (target.components.health ~= nil and target.components.health:IsDead())) then
        target = nil
        inst.target = nil
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local gx, gy, gz
    if target ~= nil then
        gx, gy, gz = target.Transform:GetWorldPosition()
    else
        local ox, _, oz = owner.Transform:GetWorldPosition()
        local rot = owner.Transform:GetRotation() * DEGREES
        -- idle off the owner's shoulder
        gx = ox + math.cos(rot + PI * 0.5) * FOLLOW_DISTANCE
        gz = oz - math.sin(rot + PI * 0.5) * FOLLOW_DISTANCE
    end

    local dx, dz = gx - x, gz - z
    local dist = math.sqrt(dx * dx + dz * dz)
    local stop = target ~= nil and STRIKE_RANGE * 0.6 or 0.2
    if dist > stop then
        local step = math.min(SPEED * dt, dist - stop)
        inst.Transform:SetPosition(x + dx / dist * step, HOVER_HEIGHT, z + dz / dist * step)
    end
end

local function WispAt(ent)
    local x, _, z = ent.Transform:GetWorldPosition()
    local fx = SpawnPrefab(FX.WISP)
    if fx ~= nil then
        fx.Transform:SetPosition(x, 0, z)
    end
end

-- Copy one of the owner's attacks or abilities.
--   "melee" normal attack       "hs" Heart Strike    "ds" Death Strike (harder hit)
--   "mr"    Marrowrend          "bb" Blood Boil (burst + Blood Plague around the blade)
local function Mirror(inst, kind)
    local owner = inst.owner
    local bk = owner ~= nil and owner:IsValid() and owner.components.bk_bloodknight or nil
    if bk == nil or inst.retiring then
        return
    end

    if kind == "bb" then
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab(FX.PUFF_BIG)
        if fx ~= nil then
            fx.Transform:SetPosition(x, 0, z)
        end
        for _, ent in ipairs(bk:FindEnemies(x, 0, z, BK.BB_RADIUS)) do
            bk:HitTarget(ent, BK.BB_MULT * inst.mult)
            bk:ApplyPlague(ent)
        end
        return
    end

    local target = inst.target
    if target == nil or not target:IsValid() then
        target = ChooseTarget(inst)
        inst.target = target
    end
    if target == nil or inst:GetDistanceSqToInst(target) > MIRROR_RANGE * MIRROR_RANGE then
        return
    end

    local mult = inst.mult
    if kind == "ds" then
        mult = mult * (1 + BK.DS_TARGET_BONUS) -- Death Strike hits harder, the copy too
    end
    bk:HitTarget(target, mult)
    WispAt(target)

    if kind == "melee" then
        bk:NoteCombat()
        bk:AddRP(BK.RP_PER_DRW_BLADE_HIT)
        if bk.dirty then
            bk:Publish() -- show the new Runic Power on the HUD right away
        end
    end
end

-- Called by the component right after spawning.
local function Setup(inst, owner, mult)
    inst.owner = owner
    inst.mult = mult
    inst.next_retarget = 0
    inst:ListenForEvent("onremove", function() inst:Remove() end, owner)
end

-- Ends the dance: a puff of smoke, then the blade is gone.
local function Retire(inst)
    if inst.retiring then
        return
    end
    inst.retiring = true
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab(FX.SMOKE)
    if fx ~= nil then
        fx.Transform:SetPosition(x, 0, z)
    end
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")
    inst:AddTag("FX")
    inst:AddTag("bk_drw_blade")

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetLightOverride(0.5)
    if not ART.drwblade then
        inst.AnimState:SetMultColour(1, 0.25, 0.3, 0.75)
    end

    inst.Light:SetRadius(1.6)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.55)
    inst.Light:SetColour(1, 0.15, 0.2)
    inst.Light:Enable(true)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.Setup = Setup
    inst.Retire = Retire
    inst.Mirror = Mirror

    inst:AddComponent("updatelooper")
    inst.components.updatelooper:AddOnUpdateFn(OnUpdate)

    return inst
end

return Prefab("bk_drw_blade", fn, assets, prefabs)
