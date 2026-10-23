local MakePlayerCharacter = require "prefabs/player_common"

-- Flags written by modmain.lua: which optional art files are present.
-- (rawget because the game runs with strict global checking.)
local ART = rawget(_G, "BK_ART") or {}
local BK = TUNING.BK

local assets =
{
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}
if ART.build then
    table.insert(assets, Asset("ANIM", "anim/bloodknight.zip"))
end
if ART.ghost then
    table.insert(assets, Asset("ANIM", "anim/ghost_bloodknight_build.zip"))
end

-- Starting inventory ---------------------------------------------------------
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.BLOODKNIGHT =
{
    "bk_runeblade",
    "boneshard",
    "boneshard",
    "boneshard",
}

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
    start_inv[string.lower(k)] = v.BLOODKNIGHT
end

-- Everything this character can spawn, so the game loads it with the player.
local prefabs = FlattenTree(start_inv, true)
table.insert(prefabs, "bk_decayzone")
table.insert(prefabs, "bk_drw_blade")
table.insert(prefabs, "wortox_soul_spawn") -- souls of kills fly to the Blood Knight
table.insert(prefabs, "wortox_soul")
table.insert(prefabs, "shadowprotector") -- Raise Dead's ghoul (placeholder)
table.insert(prefabs, "shadow_despawn")
for _, fxname in pairs(BK.FX) do
    table.insert(prefabs, fxname)
end

-- Network variables ------------------------------------------------------------
-- Created for both server and clients (before SetPristine). The server
-- component writes them; the client HUD only reads them.
local function CreateNetVars(inst)
    inst._bk_runes = net_byte(inst.GUID, "bk.runes", "bk_runesdirty")         -- 0..6
    -- recharge progress (0..95 %) of the up to 3 runes that recharge at the same time
    inst._bk_runeprog = net_byte(inst.GUID, "bk.runeprog", "bk_runeprogdirty")
    inst._bk_runeprog2 = net_byte(inst.GUID, "bk.runeprog2", "bk_runeprog2dirty")
    inst._bk_runeprog3 = net_byte(inst.GUID, "bk.runeprog3", "bk_runeprog3dirty")
    inst._bk_rp = net_byte(inst.GUID, "bk.rp", "bk_rpdirty")                   -- 0..RP_MAX (125)
    inst._bk_bbcharges = net_byte(inst.GUID, "bk.bbcharges", "bk_bbchargesdirty") -- Blood Boil charges 0..2
    inst._bk_bbprog = net_byte(inst.GUID, "bk.bbprog", "bk_bbprogdirty")       -- 0..95 (% of the next charge)
    inst._bk_ddcharges = net_byte(inst.GUID, "bk.ddcharges", "bk_ddchargesdirty") -- Death and Decay charges 0..2
    inst._bk_ddprog = net_byte(inst.GUID, "bk.ddprog", "bk_ddprogdirty")       -- 0..95 (% of the next charge)
    inst._bk_shield = net_byte(inst.GUID, "bk.shield", "bk_shielddirty")       -- 0..10
    inst._bk_bloodshield = net_ushortint(inst.GUID, "bk.bloodshield", "bk_bloodshielddirty") -- Blood Shield absorb left
    inst._bk_hemo = net_byte(inst.GUID, "bk.hemo", "bk_hemodirty")             -- Hemostasis stacks 0..5
    inst._bk_tier = net_tinybyte(inst.GUID, "bk.tier", "bk_tierdirty")         -- tier of the Rune Blade in hand (0 = none)
    inst._bk_craft = net_smallbyte(inst.GUID, "bk.craft", "bk_craftdirty")     -- station crafting tags (bits), see UpdateCraftTags
    inst._bk_purg = net_ushortint(inst.GUID, "bk.purg", "bk_purgdirty")        -- Purgatory: healing still needed
    inst._bk_purgcd = net_ushortint(inst.GUID, "bk.purgcd", "bk_purgcddirty")  -- Purgatory cooldown (set when it triggers)
    inst._bk_debt = net_byte(inst.GUID, "bk.debt", "bk_debtdirty")             -- 0..10
    inst._bk_flags = net_byte(inst.GUID, "bk.flags", "bk_flagsdirty")          -- 1 DRW, 2 free HS, 4 debt buff, 8 in decay
    inst._bk_drwlen = net_byte(inst.GUID, "bk.drwlen", "bk_drwlendirty")       -- DRW length in 0.1s, 0 when off
    inst._bk_drwcd = net_ushortint(inst.GUID, "bk.drwcd", "bk_drwcddirty")     -- DRW cooldown seconds left (shrinks with Bone Shield)
    -- "cast counters": +1 every time an ability goes on cooldown. The HUD
    -- notices the change and starts its own cooldown sweep.
    for i = 1, 10 do -- one per ability
        inst["_bk_cd" .. i] = net_byte(inst.GUID, "bk.cd" .. i, "bk_cd" .. i .. "dirty")
    end
end

-- This initializes for both the server and client. Tags can be added here.
local common_postinit = function(inst)
    inst:AddTag("bloodknight")

    -- Minimap icon
    inst.MiniMapEntity:SetIcon("bloodknight.tex")

    CreateNetVars(inst)

    -- standing at / leaving a Rune Forge or Runic Armor Table changes which
    -- recipes we may craft: make the crafting menu look again
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("bk_craftdirty", function()
            inst:PushEvent("refreshcrafting")
            -- once more a moment later, in case the tags arrive a bit after
            inst:DoTaskInTime(0.2, function() inst:PushEvent("refreshcrafting") end)
        end)
    end
end

-- This initializes for the server only. Components are added here.
local master_postinit = function(inst)
    inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

    -- choose which sounds this character will play
    inst.soundsname = "wolfgang"

    -- Stats
    inst.components.health:SetMaxHealth(BK.HEALTH)
    inst.components.hunger:SetMax(BK.HUNGER)
    inst.components.sanity:SetMax(BK.SANITY)

    inst.components.combat.damagemultiplier = 1

    -- Drawbacks: hungers faster, food heals only half as much health
    inst.components.hunger.hungerrate = BK.HUNGER_RATE_MULT * TUNING.WILSON_HUNGER_RATE
    inst.components.eater:SetAbsorptionModifiers(BK.FOOD_HEALTH_ABSORB, 1, 1)

    -- Runes, Bone Shield, abilities...
    inst:AddComponent("bk_bloodknight")
end

return MakePlayerCharacter("bloodknight", prefabs, assets, common_postinit, master_postinit)
