-- Death and Decay: a ground zone that hurts enemies standing in it and gives
-- its caster a small defence bonus while they stay inside.
--
-- Placeholder look: the stock "firefighter_placement" ground ring, tinted
-- dark red. Replace it by drawing anim/bk_decayzone.zip (see ART_GUIDE.md):
-- draw the circle exactly ART_SIZE pixels wide (like the stock ring) and the
-- code below scales it to the zone's radius, so the size never has to be
-- guessed.

local ART = rawget(_G, "BK_ART") or {}
local BK = TUNING.BK
local FX = BK.FX

local BANK, BUILD = "firefighter_placement", "firefighter_placement"
local assets = {}
if ART.decayzone then
    BANK, BUILD = "bk_decayzone", "bk_decayzone"
    table.insert(assets, Asset("ANIM", "anim/bk_decayzone.zip"))
else
    table.insert(assets, Asset("ANIM", "anim/firefighter_placement.zip"))
end

local prefabs = { FX.WISP, FX.PORTAL_OUT }

-- Width in pixels of the ring picture (the stock one is 1888 px wide; custom
-- art has to be exactly as wide). Source art size / anim_scale / 2 is the
-- same constant the stock game uses to size the firefighter_placement ring:
-- the ring is this many world units in radius at scale 1.
local ART_SIZE = 1888
local CIRCLE_RADIUS_SCALE = ART_SIZE / 150 / 2

local BUFF_CHECK_PERIOD = 0.25

local function OnTick(inst)
    local owner = inst.owner
    if owner == nil or not owner:IsValid() then
        inst:Remove()
        return
    end

    local bk = owner.components.bk_bloodknight
    if bk == nil then
        inst:Remove()
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = inst.radius

    for _, ent in ipairs(bk:FindEnemies(x, y, z, radius)) do
        local health = ent.components.health
        if health ~= nil and not health:IsDead() then
            health:DoDelta(-inst.dps * inst.tick_period, true, "bk_decay", nil, owner)
            bk:Taunt(ent) -- threat: enemies in your Death and Decay turn to you
        end
    end

    -- a few drifting wisps so the zone reads as "something is rotting here"
    for i = 1, 3 do
        local angle = math.random() * 2 * PI
        local dist = math.sqrt(math.random()) * radius * 0.9
        local fx = SpawnPrefab(FX.WISP)
        if fx ~= nil then
            fx.Transform:SetPosition(x + math.cos(angle) * dist, 0, z + math.sin(angle) * dist)
        end
    end
end

local function OnBuffCheck(inst)
    local owner = inst.owner
    if owner == nil or not owner:IsValid() or owner.components.bk_bloodknight == nil then
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local inside = not owner:HasTag("playerghost")
        and owner:GetDistanceSqToPoint(x, y, z) <= inst.radius * inst.radius
    owner.components.bk_bloodknight:SetInDecay(inside)
end

-- Called by the component right after spawning.
local function Setup(inst, owner, radius, duration, dps, tick_period)
    inst.owner = owner
    inst.radius = radius
    inst.dps = dps
    inst.tick_period = tick_period or 1

    inst:DoPeriodicTask(inst.tick_period, OnTick, inst.tick_period)
    inst:DoPeriodicTask(BUFF_CHECK_PERIOD, OnBuffCheck)
    inst:DoTaskInTime(duration, inst.Remove)

    local x, y, z = inst.Transform:GetWorldPosition()
    local start = SpawnPrefab(FX.PORTAL_OUT)
    if start ~= nil then
        start.Transform:SetPosition(x, 0, z)
    end
    OnBuffCheck(inst)
end

local function OnRemoved(inst)
    local owner = inst.owner
    if owner ~= nil and owner:IsValid() then
        local bk = owner.components.bk_bloodknight
        if bk ~= nil then
            if bk.zone == inst then
                bk.zone = nil
                bk:SetInDecay(false)
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")
    inst:AddTag("FX")

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetLightOverride(0.6)

    -- size the ring to the zone radius (stock ring and custom art alike)
    local scale = BK.DD_RADIUS / CIRCLE_RADIUS_SCALE
    inst.AnimState:SetScale(scale, scale)
    if not ART.decayzone then
        -- placeholder ring: tint it dark red
        inst.AnimState:SetMultColour(0.75, 0.08, 0.16, 0.85)
        inst.AnimState:SetAddColour(0.35, 0, 0.08, 0)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.Setup = Setup
    inst:ListenForEvent("onremove", OnRemoved)

    return inst
end

return Prefab("bk_decayzone", fn, assets, prefabs)
