-- Runeforging (like WoW): crafting a rune engraves it into the Rune Blade
-- the Blood Knight is holding. A blade holds ONE rune; a new one replaces
-- the old. The recipes (modmain.lua) can only be used while a Rune Blade is
-- in hand ("bk_runeforge" builder tag, set by the component).
--
-- The crafted "rune" is a short-lived helper item: the game calls its
-- onPreBuilt while crafting, it engraves the held blade and then removes
-- itself a moment later. Placeholder icons are stock item icons.

local RUNES =
{
    -- id            stock icon used for the recipe / item
    crusader   = "amulet",
    gargoyle   = "marble",
    sanguination = "mosquitosack",
    thirst     = "batwing",
    razorice   = "bluegem",
}

local function MakeRune(id, icon)
    local function OnPreBuilt(inst, builder)
        local inv = builder ~= nil and builder.components.inventory or nil
        local blade = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
        if blade ~= nil and blade.SetRune ~= nil then
            blade:SetRune(id)
            local x, y, z = builder.Transform:GetWorldPosition()
            local fx = SpawnPrefab(TUNING.BK.FX.PORTAL_IN)
            if fx ~= nil then
                fx.Transform:SetPosition(x, 0, z)
            end
        end
        -- the helper item has done its job: gone right after the game hands it over
        inst:DoTaskInTime(0, inst.Remove)
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState() -- (no build: invisible if it is ever dropped)
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst) -- the game may drop it when the inventory is full

        inst:AddTag("NOCLICK")
        inst:AddTag("bk_rune")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = icon
        inst.components.inventoryitem.canbepickedup = false

        inst.persists = false
        inst.onPreBuilt = OnPreBuilt
        -- safety net: never stays around
        inst:DoTaskInTime(1, inst.Remove)

        return inst
    end

    return Prefab("bk_rune_" .. id, fn)
end

local prefabs = {}
for id, icon in pairs(RUNES) do
    table.insert(prefabs, MakeRune(id, icon))
end
return unpack(prefabs)
