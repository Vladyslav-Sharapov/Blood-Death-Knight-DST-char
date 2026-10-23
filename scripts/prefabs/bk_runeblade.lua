-- The Rune Blade: the Blood Knight's weapon, and his progression.
--
-- It comes in 4 tiers. Each tier is its own prefab, crafted from the tier
-- below (see the recipes in modmain.lua):
--   bk_runeblade      Tier 1  Rune Blade (starting weapon)
--   bk_runeblade_t2   Tier 2  Runed Blade
--   bk_runeblade_t3   Tier 3  Bloodforged Blade
--   bk_runeblade_t4   Tier 4  Runeblade of the Ebon Blade
-- The Blood Knight's abilities only work while he HOLDS one of these, and a
-- higher tier unlocks more of them (TUNING.BK.ABILITY_TIER / TALENT_TIER).
--
-- Unbreakable one-handed sword. Until custom art is made it borrows the
-- look of the Dark Sword, tinted redder (and finally purple) per tier.
--
-- Custom art hooks (all optional, see ART_GUIDE.md):
--   anim/bk_runeblade.zip       world + inventory animation (bank/build "bk_runeblade")
--   anim/swap_bk_runeblade.zip  the sword in the character's hand (symbol "swap_bk_runeblade")

local ART = rawget(_G, "BK_ART") or {}
local BK = TUNING.BK

local BANK, BUILD = "nightmaresword", "nightmaresword"
local SWAP_BUILD, SWAP_SYMBOL = "swap_nightmaresword", "swap_nightmaresword"

local assets = {}
if ART.runeblade then
    BANK, BUILD = "bk_runeblade", "bk_runeblade"
    table.insert(assets, Asset("ANIM", "anim/bk_runeblade.zip"))
else
    table.insert(assets, Asset("ANIM", "anim/nightmaresword.zip"))
end
if ART.runeblade_swap then
    SWAP_BUILD, SWAP_SYMBOL = "swap_bk_runeblade", "swap_bk_runeblade"
    table.insert(assets, Asset("ANIM", "anim/swap_bk_runeblade.zip"))
else
    table.insert(assets, Asset("ANIM", "anim/swap_nightmaresword.zip"))
end

-- placeholder tint on the ground, per tier
local TINTS =
{
    { 1.00, 0.62, 0.62 },
    { 1.00, 0.48, 0.48 },
    { 1.00, 0.30, 0.30 },
    { 0.80, 0.35, 1.00 },
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", SWAP_BUILD, SWAP_SYMBOL)
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

--------------------------------------------------------------------------
-- Runeforging: one rune per blade (like WoW). The rune id is stored on the
-- blade (inst.bk_rune), shown in its name, saved, and passed on to the
-- next tier when the blade is upgraded.
--------------------------------------------------------------------------

local function SetRune(inst, rune)
    inst.bk_rune = rune
    if rune ~= nil then
        inst.components.named:SetName(STRINGS.NAMES[string.upper(inst.prefab)] .. " (" .. STRINGS.BK_RUNE_NAMES[rune] .. ")")
    else
        inst.components.named:SetName(nil)
    end
    -- the Blood Knight holding it picks up the new rune right away
    local owner = inst.components.inventoryitem.owner
    if owner ~= nil and owner.components.bk_bloodknight ~= nil then
        owner.components.bk_bloodknight:UpdateTier(true)
    end
end

-- Crafted from the tier below: copy the rune of the blade being used up.
-- (Called by the game before the ingredients are removed.)
local function OnPreBuilt(inst, builder, materials, recipe)
    for _, items in pairs(materials or {}) do
        for item in pairs(items) do
            if item.bk_rune ~= nil then
                SetRune(inst, item.bk_rune)
                return
            end
        end
    end
end

local function OnSave(inst, data)
    data.bk_rune = inst.bk_rune
end

local function OnLoad(inst, data)
    if data ~= nil and data.bk_rune ~= nil and STRINGS.BK_RUNE_NAMES[data.bk_rune] ~= nil then
        SetRune(inst, data.bk_rune)
    end
end

local function MakeBlade(prefab, tier)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(BANK)
        inst.AnimState:SetBuild(BUILD)
        inst.AnimState:PlayAnimation("idle")
        if not ART.runeblade then
            local c = TINTS[tier]
            inst.AnimState:SetMultColour(c[1], c[2], c[3], 1)
        end

        inst:AddTag("sharp")
        inst:AddTag("bk_runeblade") -- "this is a Rune Blade" (any tier)

        --named (from named component) added to pristine state, so clients can show the rune in the name
        inst:AddTag("_named")

        --weapon (from weapon component) added to pristine state for optimization
        inst:AddTag("weapon")

        local swap_data = { sym_build = SWAP_BUILD, bank = BANK }
        MakeInventoryFloatable(inst, "med", 0.05, { 1.0, 0.4, 1.0 }, true, -17.5, swap_data)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.bk_tier = tier

        --Remove these tags so that they can be added properly when replicating components below
        inst:RemoveTag("_named")
        inst:AddComponent("named")

        inst.SetRune = SetRune
        inst.onPreBuilt = OnPreBuilt
        inst.OnSave = OnSave
        inst.OnLoad = OnLoad

        -- Plain swings use the tier's plain damage; the Blood Knight's
        -- abilities count the blade as stronger (see IsAbilityHit).
        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(function(weapon, attacker, target)
            local bk = attacker ~= nil and attacker.components.bk_bloodknight or nil
            if bk ~= nil and bk:IsAbilityHit(target) then
                return BK.BLADE_ABILITY_DAMAGE[tier]
            end
            return BK.BLADE_DAMAGE[tier]
        end)

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = "images/inventoryimages/bk_runeblade.xml"
        inst.components.inventoryitem.imagename = "bk_runeblade" -- one icon for all tiers (for now)

        inst:AddComponent("equippable")
        inst.components.equippable:SetOnEquip(onequip)
        inst.components.equippable:SetOnUnequip(onunequip)

        MakeHauntableLaunch(inst)

        return inst
    end
    return Prefab(prefab, fn, assets)
end

return MakeBlade("bk_runeblade", 1),
    MakeBlade("bk_runeblade_t2", 2),
    MakeBlade("bk_runeblade_t3", 3),
    MakeBlade("bk_runeblade_t4", 4)
