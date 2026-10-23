-- The Blood Knight's helmet, in 3 tiers crafted at the Runic Armor Table:
--   bk_helm     Tier 1  Death Knight Helm
--   bk_helm_t2  Tier 2  Runed Helm
--   bk_helm_t3  Tier 3  Ebon Helm
-- Like the plate it never breaks, but it runs on Soul charge (see
-- scripts/bk_soulgear.lua). Numbers per tier: TUNING.BK.ARMOR_TIERS.
--
-- Placeholder look: the stock Bone Helm, tinted per tier on the ground
-- (without the Bone Helm's insanity effect). Its inventory icon is the Bone Helm's.

local BK = TUNING.BK
local SoulGear = require("bk_soulgear")

local assets =
{
    Asset("ANIM", "anim/hat_skeleton.zip"),
}

local function OnBlocked(owner)
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
end

-- the same body-part switches the game's own hats use
local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_hat", "hat_skeleton", "swap_hat")
    owner.AnimState:Show("HAT")
    owner.AnimState:Show("HAIR_HAT")
    owner.AnimState:Hide("HAIR_NOHAT")
    owner.AnimState:Hide("HAIR")
    if owner.isplayer then
        owner.AnimState:Hide("HEAD")
        owner.AnimState:Show("HEAD_HAT")
        owner.AnimState:Show("HEAD_HAT_NOHELM")
        owner.AnimState:Hide("HEAD_HAT_HELM")
    end

    inst:ListenForEvent("blocked", OnBlocked, owner)
    SoulGear.OnEquip(inst, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_hat")
    owner.AnimState:Hide("HAT")
    owner.AnimState:Hide("HAIR_HAT")
    owner.AnimState:Show("HAIR_NOHAT")
    owner.AnimState:Show("HAIR")
    if owner.isplayer then
        owner.AnimState:Show("HEAD")
        owner.AnimState:Hide("HEAD_HAT")
        owner.AnimState:Hide("HEAD_HAT_NOHELM")
        owner.AnimState:Hide("HEAD_HAT_HELM")
    end

    inst:RemoveEventCallback("blocked", OnBlocked, owner)
    SoulGear.OnUnequip(inst, owner)
end

local TINTS = { { 1, 0.6, 0.6 }, { 1, 0.42, 0.42 }, { 0.75, 0.4, 1 } }

local function MakeHelm(prefab, tier)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("skeletonhat")
        inst.AnimState:SetBuild("hat_skeleton")
        inst.AnimState:PlayAnimation("anim")
        local c = TINTS[tier]
        inst.AnimState:SetMultColour(c[1], c[2], c[3], 1)

        inst:AddTag("hat")

        MakeInventoryFloatable(inst, "med", nil, 0.68)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.bk_tier = tier

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = "skeletonhat" -- stock Bone Helm icon

        -- never breaks; protects only while it has Soul charge
        local t = BK.ARMOR_TIERS[tier]
        SoulGear.Setup(inst, t.absorb, t.default, t.cap)
        inst.onPreBuilt = SoulGear.OnPreBuilt -- an upgrade keeps the old piece's charge

        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
        inst.components.equippable:SetOnEquip(onequip)
        inst.components.equippable:SetOnUnequip(onunequip)

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(prefab, fn, assets, { "wortox_soul_in_fx" })
end

return MakeHelm("bk_helm", 1),
    MakeHelm("bk_helm_t2", 2),
    MakeHelm("bk_helm_t3", 3)
