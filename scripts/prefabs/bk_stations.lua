-- The Blood Knight's two crafting stations.
--
--   bk_runeforge_station  Rune Forge          blade tier upgrades + runeforging
--   bk_armortable_station Runic Armor Table   Death Knight Plate / Helm and their tiers
--
-- DST has no way for mods to add a new kind of crafting station, so they
-- work like this instead: the Blood Knight's component checks every half
-- second whether he stands next to one, and gives himself a builder tag
-- ("bk_at_runeforge", ...) while he does. The station recipes ask for that
-- tag, so they show up in the crafting menu only at the station.
--
-- Placeholder looks: the Shadow Forge and the Mannequin, tinted.

local function OnHammered(inst, worker)
    inst.components.lootdropper:DropLoot() -- gives back part of the recipe
    local fx = SpawnPrefab("collapse_small")
    if fx ~= nil then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("stone")
    end
    inst:Remove()
end

local function MakeStation(prefab, bank, build, anim, tag, tint, physics_radius)
    local assets = { Asset("ANIM", "anim/" .. build .. ".zip") }

    local function OnBuilt(inst)
        inst.SoundEmitter:PlaySound("dontstarve/common/repair_stonefurniture")
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        MakeObstaclePhysics(inst, physics_radius)

        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)
        inst.AnimState:SetMultColour(tint[1], tint[2], tint[3], 1)

        inst:AddTag("structure")
        inst:AddTag(tag) -- what the Blood Knight looks for

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("lootdropper")

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(4)
        inst.components.workable:SetOnFinishCallback(OnHammered)

        inst:ListenForEvent("onbuilt", OnBuilt)

        MakeHauntableWork(inst)

        return inst
    end

    return Prefab(prefab, fn, assets, { "collapse_small" }),
        MakePlacer(prefab .. "_placer", bank, build, anim)
end

local forge, forge_placer = MakeStation("bk_runeforge_station", "shadow_forge", "shadow_forge", "idle",
    "bk_runeforge_station", { 1, 0.45, 0.45 }, 0.4)
local table_, table_placer = MakeStation("bk_armortable_station", "sewing_mannequin", "sewing_mannequin", "idle",
    "bk_armortable_station", { 0.75, 0.55, 0.55 }, 0.3)

return forge, forge_placer, table_, table_placer
