-- The Blood Knight's body armor, in 3 tiers crafted at the Runic Armor Table:
--   bk_armor     Tier 1  Death Knight Plate
--   bk_armor_t2  Tier 2  Runed Plate
--   bk_armor_t3  Tier 3  Ebon Plate
-- It never breaks, but it runs on Soul charge (see scripts/bk_soulgear.lua):
-- blocked damage drains it, souls refill it. Numbers per tier: TUNING.BK.ARMOR_TIERS.
-- An upgraded piece keeps the charge of the one it was made from.
--
-- Placeholder look: the stock Bone Armor, tinted per tier on the ground. Its
-- inventory icon is the stock Bone Armor icon too.

local BK = TUNING.BK
local SoulGear = require("bk_soulgear")

local assets =
{
    Asset("ANIM", "anim/armor_skeleton.zip"),
}

local TINTS = { { 1, 0.6, 0.6 }, { 1, 0.42, 0.42 }, { 0.75, 0.4, 1 } }

local function OnBlocked(owner)
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "armor_skeleton", "swap_body")
    inst:ListenForEvent("blocked", OnBlocked, owner)
    SoulGear.OnEquip(inst, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst:RemoveEventCallback("blocked", OnBlocked, owner)
    SoulGear.OnUnequip(inst, owner)
end

local function MakePlate(prefab, tier)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("armor_skeleton")
        inst.AnimState:SetBuild("armor_skeleton")
        inst.AnimState:PlayAnimation("anim")
        local c = TINTS[tier]
        inst.AnimState:SetMultColour(c[1], c[2], c[3], 1)

        inst.foleysound = "dontstarve/movement/foley/bone"

        local swap_data = { bank = "armor_skeleton", anim = "anim" }
        MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.bk_tier = tier

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = "armorskeleton" -- stock Bone Armor icon

        -- never breaks; protects only while it has Soul charge
        local t = BK.ARMOR_TIERS[tier]
        SoulGear.Setup(inst, t.absorb, t.default, t.cap)
        inst.onPreBuilt = SoulGear.OnPreBuilt -- an upgrade keeps the old piece's charge

        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.BODY
        inst.components.equippable:SetOnEquip(onequip)
        inst.components.equippable:SetOnUnequip(onunequip)

        MakeHauntableLaunch(inst)

        return inst
    end
    return Prefab(prefab, fn, assets, { "wortox_soul_in_fx" })
end

return MakePlate("bk_armor", 1),
    MakePlate("bk_armor_t2", 2),
    MakePlate("bk_armor_t3", 3)
