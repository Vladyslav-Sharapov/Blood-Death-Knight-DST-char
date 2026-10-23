--------------------------------------------------------------------------
-- bk_soulgear  (server only)
--
-- Shared "Soul charge" for the Death Knight Plate and Death Knight Helm.
--
--   * The gear never breaks (armor:InitIndestructible).
--   * It only blocks damage while it has charge. At 0% it blocks nothing.
--   * The charge is a percentage (shown on the inventory slot). How much
--     damage 100% is worth scales with the fight: HALF the total max health
--     of every enemy attacking the wearer, at least MIN_CHARGE and at most
--     the piece's cap (two 100-health spiders: 150, Deerclops: the cap). With
--     no enemy attacking, it is the piece's default (both per tier: ARMOR_TIERS).
--     Every point of damage blocked uses CHARGE_DRAIN points of that.
--   * While worn, it eats Wortox souls (prefab "wortox_soul") from the
--     owner's inventory to refill: one soul = SOUL_CHARGE_PCT of the charge.
--
-- Usage in a prefab's master section:
--     local SoulGear = require("bk_soulgear")
--     SoulGear.Setup(inst, absorb, default_max_charge)
-- and call SoulGear.OnEquip / SoulGear.OnUnequip from its equip callbacks.
--------------------------------------------------------------------------

local BK = TUNING.BK

local SoulGear = {}

local AGGRO_MUST_TAGS = { "_combat", "_health" }
local AGGRO_CANT_TAGS = { "INLIMBO", "player", "playerghost", "FX" }

local function GetOwner(inst)
    local equippable = inst.components.equippable
    if equippable == nil or not equippable:IsEquipped() then
        return nil
    end
    return inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
end

-- What 100% charge is worth right now (see the top of the file).
function SoulGear.GetMaxCharge(inst)
    local owner = GetOwner(inst)
    if owner == nil or not owner:IsValid() then
        return inst.bk_default_max
    end
    local x, y, z = owner.Transform:GetWorldPosition()
    local total = 0
    for _, ent in ipairs(TheSim:FindEntities(x, y, z, BK.AGGRO_RADIUS, AGGRO_MUST_TAGS, AGGRO_CANT_TAGS)) do
        local health = ent.components.health
        if ent.components.combat ~= nil and ent.components.combat.target == owner
            and health ~= nil and not health:IsDead() then
            total = total + health.maxhealth
        end
    end
    if total <= 0 then
        return inst.bk_default_max -- nothing attacking you
    end
    return math.min(inst.bk_cap, math.max(BK.MIN_CHARGE, total * BK.AGGRO_SCALE))
end

local function UpdateArmor(inst)
    -- empty gear stays equipped but stops protecting
    inst.components.armor:SetAbsorption(inst.bk_frac > 0 and inst.bk_absorb or 0)
    -- percent on the inventory slot. Never exactly 0: the game would think
    -- the armor broke and make the character comment on it.
    inst:PushEvent("percentusedchange", { percent = math.max(0.001, inst.bk_frac) })
end

-- frac: 0 (empty) .. 1 (full)
function SoulGear.SetCharge(inst, frac)
    inst.bk_frac = math.max(0, math.min(frac, 1))
    UpdateArmor(inst)
end

-- Eat souls from the owner's inventory while there is room for them.
-- (An empty piece always eats one, even if part of it would be wasted.)
function SoulGear.TryRefill(inst)
    local owner = GetOwner(inst)
    if owner == nil or owner.components.inventory == nil then
        return
    end
    local inv = owner.components.inventory
    local ate = false
    while (inst.bk_frac <= 1 - BK.SOUL_CHARGE_PCT or inst.bk_frac <= 0) and inv:Has("wortox_soul", 1) do
        inv:ConsumeByName("wortox_soul", 1)
        SoulGear.SetCharge(inst, inst.bk_frac + BK.SOUL_CHARGE_PCT)
        ate = true
    end
    if ate then
        -- Wortox's "soul going in" effect on the wearer
        local fx = SpawnPrefab("wortox_soul_in_fx")
        if fx ~= nil then
            fx.Transform:SetPosition(owner.Transform:GetWorldPosition())
            fx:Setup(owner)
        end
    end
end

local function OnTakeDamage(inst, amount)
    -- the bigger the fight, the more damage one percent of charge can take
    local max_charge = SoulGear.GetMaxCharge(inst)
    SoulGear.SetCharge(inst, inst.bk_frac - amount * BK.CHARGE_DRAIN / max_charge)
    SoulGear.TryRefill(inst)
end

-- cap: the most 100% charge can be worth in a big fight
function SoulGear.Setup(inst, absorb, default_max, cap)
    inst.bk_absorb = absorb
    inst.bk_default_max = default_max
    inst.bk_cap = cap
    inst.bk_frac = 1 -- freshly crafted gear is fully charged

    inst:AddComponent("armor")
    inst.components.armor:InitIndestructible(absorb)
    inst.components.armor.ontakedamage = OnTakeDamage

    -- the wearer picked something up: maybe a soul to eat
    inst._bk_onitemget = function(owner, data)
        if data ~= nil and data.item ~= nil and data.item.prefab == "wortox_soul" then
            SoulGear.TryRefill(inst)
        end
    end

    inst.OnSave = function(inst, data)
        data.bk_frac = inst.bk_frac
    end
    inst.OnLoad = function(inst, data)
        if data ~= nil and data.bk_frac ~= nil then
            SoulGear.SetCharge(inst, data.bk_frac)
        elseif data ~= nil and data.bk_charge ~= nil then
            -- saved by the older version (charge in points)
            SoulGear.SetCharge(inst, data.bk_charge / default_max)
        end
    end

    -- push the first percentage once the item exists in the world
    inst:DoTaskInTime(0, UpdateArmor)
end

-- Upgraded at the Runic Armor Table: keep the charge of the piece being used up.
-- (Set as inst.onPreBuilt; the game calls it before removing the ingredients.)
function SoulGear.OnPreBuilt(inst, builder, materials)
    for _, items in pairs(materials or {}) do
        for item in pairs(items) do
            if item.bk_frac ~= nil then
                SoulGear.SetCharge(inst, item.bk_frac)
                return
            end
        end
    end
end

function SoulGear.OnEquip(inst, owner)
    -- "itemget" fires for a new slot, "gotnewitem" also when it joins a stack
    inst:ListenForEvent("itemget", inst._bk_onitemget, owner)
    inst:ListenForEvent("gotnewitem", inst._bk_onitemget, owner)
    inst:DoTaskInTime(0, SoulGear.TryRefill) -- after the equip has finished
end

function SoulGear.OnUnequip(inst, owner)
    inst:RemoveEventCallback("itemget", inst._bk_onitemget, owner)
    inst:RemoveEventCallback("gotnewitem", inst._bk_onitemget, owner)
end

return SoulGear
