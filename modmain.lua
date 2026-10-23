--------------------------------------------------------------------------
-- Blood Knight - a Blood Death Knight for Don't Starve Together
--
-- File map:
--   modinfo.lua                      mod description + configuration screen
--   modmain.lua                      (this file) wiring: assets, strings, HUD, RPC
--   scripts/bk_tuning.lua            every balance number (TUNING.BK)
--   scripts/components/bk_bloodknight.lua   all gameplay rules (server only)
--   scripts/widgets/bk_hud.lua       runes / ability bar (client only)
--   scripts/prefabs/*.lua            the character + its items and effects
--   scripts/speech_bloodknight.lua   what the character says
--
-- The game runs this file on the server AND on every client.
--------------------------------------------------------------------------

local STRINGS = GLOBAL.STRINGS
local TUNING = GLOBAL.TUNING
local require = GLOBAL.require

--------------------------------------------------------------------------
-- Balance numbers + configuration screen values
--------------------------------------------------------------------------

require("bk_tuning")

-- Reads one configuration value, falling back to `default` if the option is
-- missing (for example a settings file written by an older version).
-- Options marked `client = true` in modinfo.lua are read locally.
local function Config(name, default, is_client_option)
    local value = GetModConfigData(name, is_client_option or false)
    if value == nil then
        return default
    end
    return value
end

TUNING.BK.RUNE_RECHARGE = Config("rune_time", TUNING.BK.RUNE_RECHARGE)
TUNING.BK.AUTO_HS = Config("hs_mode", "manual") == "auto"
TUNING.BK.DAMAGE_SCALE = Config("damage_scale", 1.0)

local HUD_CONFIG =
{
    keys =
    {
        Config("key_hs",  122, true),   -- Z
        Config("key_ds",  120, true),   -- X
        Config("key_mr",   99, true),   -- C
        Config("key_bb",  118, true),   -- V
        Config("key_dd",   98, true),   -- B
        Config("key_drw", 114, true),   -- R
        Config("key_grip", 103, true),  -- G
        Config("key_dc",  116, true),   -- T
        Config("key_vb",  104, true),   -- H
        Config("key_rd",  106, true),   -- J
    },
    scale = Config("hud_scale", 1.0, true),
    y = Config("hud_y", 135, true),
}

--------------------------------------------------------------------------
-- Optional hand-drawn art
--
-- Everything below works with placeholder art. When the artist delivers a
-- file listed here, just drop it into the mod's anim/ folder: the prefabs
-- notice it and use it instead of the placeholder. (See ART_GUIDE.md.)
--
-- modmain runs before the prefab files are loaded, so the result is handed
-- to them through one global table. Prefabs read it with rawget(_G, "BK_ART").
--------------------------------------------------------------------------

local function ModFileExists(relative_path)
    local ok, exists = GLOBAL.pcall(function()
        return GLOBAL.kleifileexists(MODROOT .. relative_path)
    end)
    return ok and exists and true or false
end

GLOBAL.BK_ART =
{
    build = ModFileExists("anim/bloodknight.zip"),                  -- the character
    ghost = ModFileExists("anim/ghost_bloodknight_build.zip"),      -- the character as a ghost
    runeblade = ModFileExists("anim/bk_runeblade.zip"),             -- sword on the ground / in the inventory
    runeblade_swap = ModFileExists("anim/swap_bk_runeblade.zip"),   -- sword in the character's hand
    decayzone = ModFileExists("anim/bk_decayzone.zip"),             -- Death and Decay ground circle
    drwblade = ModFileExists("anim/bk_drw_blade.zip"),              -- Dancing Rune Weapon's spectral blade
}

--------------------------------------------------------------------------
-- Prefabs and assets
--------------------------------------------------------------------------

PrefabFiles =
{
    "bloodknight",
    "bloodknight_none",
    "bk_runeblade",
    "bk_decayzone",
    "bk_drw_blade",
    "bk_armor",
    "bk_helm",
    "bk_runes",
    "bk_stations",
}

Assets =
{
    -- character select / lobby
    Asset("IMAGE", "images/saveslot_portraits/bloodknight.tex"),
    Asset("ATLAS", "images/saveslot_portraits/bloodknight.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/bloodknight.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/bloodknight.xml"),

    Asset("IMAGE", "images/selectscreen_portraits/bloodknight_silho.tex"),
    Asset("ATLAS", "images/selectscreen_portraits/bloodknight_silho.xml"),

    Asset("IMAGE", "bigportraits/bloodknight.tex"),
    Asset("ATLAS", "bigportraits/bloodknight.xml"),

    Asset("IMAGE", "images/names_bloodknight.tex"),
    Asset("ATLAS", "images/names_bloodknight.xml"),

    Asset("IMAGE", "images/names_gold_bloodknight.tex"),
    Asset("ATLAS", "images/names_gold_bloodknight.xml"),

    -- map, player list, inspect-self
    Asset("IMAGE", "images/map_icons/bloodknight.tex"),
    Asset("ATLAS", "images/map_icons/bloodknight.xml"),

    Asset("IMAGE", "images/avatars/avatar_bloodknight.tex"),
    Asset("ATLAS", "images/avatars/avatar_bloodknight.xml"),

    Asset("IMAGE", "images/avatars/avatar_ghost_bloodknight.tex"),
    Asset("ATLAS", "images/avatars/avatar_ghost_bloodknight.xml"),

    Asset("IMAGE", "images/avatars/self_inspect_bloodknight.tex"),
    Asset("ATLAS", "images/avatars/self_inspect_bloodknight.xml"),

    -- in-game HUD and item icons
    Asset("IMAGE", "images/bk_hud.tex"),
    Asset("ATLAS", "images/bk_hud.xml"),

    Asset("IMAGE", "images/inventoryimages/bk_runeblade.tex"),
    Asset("ATLAS", "images/inventoryimages/bk_runeblade.xml"),
}

AddMinimapAtlas("images/map_icons/bloodknight.xml")
GLOBAL.RegisterInventoryItemAtlas("images/inventoryimages/bk_runeblade.xml", "bk_runeblade.tex")

--------------------------------------------------------------------------
-- Strings
--------------------------------------------------------------------------

-- Character select screen
STRINGS.CHARACTER_TITLES.bloodknight = "The Death Knight"
STRINGS.CHARACTER_NAMES.bloodknight = "Blood Knight"
STRINGS.CHARACTER_DESCRIPTIONS.bloodknight =
    "*Heals through combat\n*Bone Shield cuts damage taken\n*Hungers faster, food heals only half"
STRINGS.CHARACTER_QUOTES.bloodknight = "\"Hold the line.\""
STRINGS.CHARACTER_SURVIVABILITY.bloodknight = "Grim"

-- Names shown in game
STRINGS.NAMES.BLOODKNIGHT = "Blood Knight"
STRINGS.SKIN_NAMES.bloodknight_none = "Blood Knight"
STRINGS.NAMES.BK_RUNEBLADE = "Rune Blade"
STRINGS.NAMES.BK_RUNEBLADE_T2 = "Runed Blade"
STRINGS.NAMES.BK_RUNEBLADE_T3 = "Bloodforged Blade"
STRINGS.NAMES.BK_RUNEBLADE_T4 = "Runeblade of the Ebon Blade"
STRINGS.RECIPE_DESC.BK_RUNEBLADE = "Tier 1. Forge a new Rune Blade."
STRINGS.RECIPE_DESC.BK_RUNEBLADE_T2 = "Tier 2: Death and Decay, Death Grip, Dark Command."
STRINGS.RECIPE_DESC.BK_RUNEBLADE_T3 = "Tier 3: Vampiric Blood, Raise Dead, the Plate and Helm."
STRINGS.RECIPE_DESC.BK_RUNEBLADE_T4 = "Tier 4: Dancing Rune Weapon and Purgatory."
STRINGS.BK_TIER_NAMES = { "Rune Blade", "Runed Blade", "Bloodforged Blade", "Runeblade of the Ebon Blade" }

-- Runeforging (rune id -> name; the id is what the blade saves)
STRINGS.BK_RUNE_NAMES =
{
    crusader = "Fallen Crusader",
    gargoyle = "Stoneskin Gargoyle",
    sanguination = "Sanguination",
    thirst = "Unending Thirst",
    razorice = "Razorice",
}
STRINGS.NAMES.BK_RUNE_CRUSADER = "Rune of the Fallen Crusader"
STRINGS.NAMES.BK_RUNE_GARGOYLE = "Rune of the Stoneskin Gargoyle"
STRINGS.NAMES.BK_RUNE_SANGUINATION = "Rune of Sanguination"
STRINGS.NAMES.BK_RUNE_THIRST = "Rune of Unending Thirst"
STRINGS.NAMES.BK_RUNE_RAZORICE = "Rune of Razorice"
STRINGS.RECIPE_DESC.BK_RUNE_CRUSADER = "Hits may heal you and boost your damage. Replaces the blade's rune."
STRINGS.RECIPE_DESC.BK_RUNE_GARGOYLE = "5% tougher and 5% stronger. Replaces the blade's rune."
STRINGS.RECIPE_DESC.BK_RUNE_SANGUINATION = "Death Strike executes; heals you when you drop low. Replaces the blade's rune."
STRINGS.RECIPE_DESC.BK_RUNE_THIRST = "Faster; kills heal you and speed you up. Replaces the blade's rune."
STRINGS.RECIPE_DESC.BK_RUNE_RAZORICE = "Frost damage that grows with every hit. Replaces the blade's rune."
STRINGS.NAMES.BK_DECAYZONE = "Death and Decay"
STRINGS.NAMES.BK_DRW_BLADE = "Spectral Rune Blade"
STRINGS.NAMES.BK_GHOUL = "Risen Ghoul"
STRINGS.NAMES.BK_ARMOR = "Death Knight Plate"
STRINGS.RECIPE_DESC.BK_ARMOR = "Never breaks. Runs on souls of the fallen."
STRINGS.NAMES.BK_HELM = "Death Knight Helm"
STRINGS.RECIPE_DESC.BK_HELM = "Never breaks. Runs on souls of the fallen."
STRINGS.NAMES.BK_ARMOR_T2 = "Runed Plate"
STRINGS.NAMES.BK_ARMOR_T3 = "Ebon Plate"
STRINGS.NAMES.BK_HELM_T2 = "Runed Helm"
STRINGS.NAMES.BK_HELM_T3 = "Ebon Helm"
STRINGS.RECIPE_DESC.BK_ARMOR_T2 = "Tier 2 plate: blocks more, holds more charge."
STRINGS.RECIPE_DESC.BK_ARMOR_T3 = "Tier 3 plate: the strongest Soul armor."
STRINGS.RECIPE_DESC.BK_HELM_T2 = "Tier 2 helm: blocks more, holds more charge."
STRINGS.RECIPE_DESC.BK_HELM_T3 = "Tier 3 helm: the strongest Soul armor."

-- crafting stations
STRINGS.NAMES.BK_RUNEFORGE_STATION = "Rune Forge"
STRINGS.RECIPE_DESC.BK_RUNEFORGE_STATION = "Upgrade your Rune Blade and engrave runes here."
STRINGS.NAMES.BK_ARMORTABLE_STATION = "Runic Armor Table"
STRINGS.RECIPE_DESC.BK_ARMORTABLE_STATION = "Craft and upgrade Death Knight armor here."

-- What other characters say when they examine a Blood Knight.
STRINGS.CHARACTERS.GENERIC.DESCRIBE.BLOODKNIGHT =
{
    GENERIC = "He looks like he has already survived the worst of it.",
    ATTACKER = "That blade has been in more than one back, %s.",
    MURDERER = "Murderer! Hold the line, %s!",
    REVIVER = "%s drags the living back from the edge.",
    GHOST = "Even the Death Knight falls. Someone fetch a heart.",
    FIRESTARTER = "Careful with the flames, %s. Even bones burn.",
}

-- Custom speech for the character (a full copy of the stock lines with a few
-- of our own on top, see scripts/speech_bloodknight.lua).
STRINGS.CHARACTERS.BLOODKNIGHT = require "speech_bloodknight"

-- Texts used by the HUD (scripts/widgets/bk_hud.lua)
local BK = TUNING.BK
local function Cost(runes, rp, cd)
    local parts = {}
    if runes > 0 then
        table.insert(parts, runes .. (runes == 1 and " Rune" or " Runes"))
    end
    if rp > 0 then
        table.insert(parts, rp .. " Runic Power")
    end
    if #parts == 0 then
        table.insert(parts, "No cost")
    end
    return table.concat(parts, ", ") .. "  -  " .. cd .. "s cooldown"
end

STRINGS.BK_UI =
{
    ABILITY =
    {
        "Heart Strike",
        "Death Strike",
        "Marrowrend",
        "Blood Boil",
        "Death and Decay",
        "Dancing Rune Weapon",
        "Death Grip",
        "Dark Command",
        "Vampiric Blood",
        "Raise Dead",
    },
    TIP =
    {
        "Hit " .. BK.HS_TARGETS .. " enemies (" .. BK.HS_TARGETS_DECAY .. " while you stand in Death and Decay) and heal "
            .. BK.HS_HEAL_PER_ENEMY .. " health for each one hit. Builds Runic Power.\n"
            .. Cost(BK.RUNE_COST[1], BK.RP_COST[1], BK.COOLDOWN[1]),
        "Heal for " .. math.floor(BK.DS_HEAL_PCT * 100 + 0.5) .. "% of the damage you took in the last "
            .. BK.DS_WINDOW .. " seconds (at least " .. math.floor(BK.DS_MIN_HEAL_PCT * 100 + 0.5)
            .. "% of your max health), and " .. math.floor(BK.DS_BLOOD_SHIELD * 100 + 0.5) .. "% of the heal becomes a Blood Shield that "
            .. "absorbs damage for " .. BK.DS_BLOOD_SHIELD_TIME .. "s. Needs a target. Hits harder than Heart Strike, and "
            .. BK.DS_REACH_TARGETS .. " nearby enemies take " .. math.floor(BK.DS_REACH_MULT * 100 + 0.5)
            .. "% of the hit (Deadly Reach). Each enemy hit by Blood Boil makes it " .. math.floor(BK.HEMO_PER_STACK * 100 + 0.5)
            .. "% stronger (Hemostasis, up to " .. BK.HEMO_MAX .. "). Makes your Blood Plague stronger (Coagulopathy). "
            .. "Costs " .. (BK.RP_COST[2] - BK.OSSUARY_COST_CUT) .. " with " .. BK.OSSUARY_STACKS .. "+ Bone Shield (Ossuary). Adds Blood Debt.\n"
            .. Cost(BK.RUNE_COST[2], BK.RP_COST[2], BK.COOLDOWN[2]),
        "Strike your target (a bit harder than Heart Strike) and rebuild " .. BK.SHIELD_PER_MARROWREND
            .. " stacks of Bone Shield, which last " .. BK.SHIELD_TIME .. "s. Works without a target too.\n"
            .. Cost(BK.RUNE_COST[3], BK.RP_COST[3], BK.COOLDOWN[3]),
        "Burst of damage around you. Every enemy hit gets Blood Plague, which slowly heals you.\n"
            .. BK.BB_CHARGES .. " charges, one comes back every " .. BK.BB_RECHARGE .. "s. No rune cost.",
        "Create a zone that hurts enemies and toughens you while you stand in it. Inside it, Heart Strike hits up to "
            .. BK.HS_TARGETS_DECAY .. " enemies.\n" .. BK.DD_CHARGES .. " charges, one comes back every "
            .. BK.DD_RECHARGE .. "s. Crimson Scourge: your swings on enemies with Blood Plague have a "
            .. math.floor(BK.CRIMSON_CHANCE * 100 + 0.5) .. "% chance to give a charge back and make the next one free (gold glow).\n"
            .. BK.RUNE_COST[5] .. " Rune",
        "For " .. BK.DRW_TIME .. "s a rune weapon copies every attack and ability you use, you deal "
            .. math.floor(BK.DOM_DAMAGE * 100 + 0.5) .. "% more damage, take " .. math.floor(BK.DOM_DEFENSE * 100 + 0.5)
            .. "% less, and you dodge "
            .. math.floor(BK.DRW_DODGE * 100 + 0.5) .. "% more often. Losing Bone Shield lowers the cooldown by "
            .. BK.DRW_CDR_PER_SHIELD .. "s per stack. When it ends, runes recharge faster for "
            .. BK.DRW_END_HASTE_TIME .. "s.\n"
            .. Cost(BK.RUNE_COST[6], BK.RP_COST[6], BK.COOLDOWN[6]),
        "Pull an enemy to you and force it to attack you for " .. BK.TAUNT_TIME .. "s. Point at it with the mouse, "
            .. "otherwise it grabs the closest enemy attacking a friend. Bosses are too big to pull, they are only taunted.\n"
            .. Cost(BK.RUNE_COST[7], BK.RP_COST[7], BK.COOLDOWN[7]),
        "Force an enemy to attack you for " .. BK.TAUNT_TIME .. "s (range " .. BK.DC_RANGE .. "). Point at it with the "
            .. "mouse, otherwise it picks the closest enemy attacking a friend.\n"
            .. Cost(BK.RUNE_COST[8], BK.RP_COST[8], BK.COOLDOWN[8]),
        "For " .. BK.VB_TIME .. "s: +" .. math.floor(BK.VB_HEALTH * 100 + 0.5) .. "% max health (you get that health), +"
            .. math.floor(BK.VB_HEAL * 100 + 0.5) .. "% healing and Blood Shield received.\n"
            .. Cost(BK.RUNE_COST[9], BK.RP_COST[9], BK.COOLDOWN[9]),
        "Raise a ghoul that fights by your side for " .. BK.GHOUL_TIME .. "s. Only one at a time.\n"
            .. Cost(BK.RUNE_COST[10], BK.RP_COST[10], BK.COOLDOWN[10]),
    },
    TIP_PURGATORY = "Purgatory (passive): a hit that would kill you leaves you at 1 health instead. Get healed "
        .. "for that much within " .. BK.PURGATORY_TIME .. "s or you die. Once every " .. (BK.PURGATORY_COOLDOWN / 60) .. " minutes.",
    TIP_RP = "Runic Power. Every rune you spend gives " .. BK.RP_PER_RUNE .. ", Heart Strike gives "
        .. BK.RP_PER_HEART_STRIKE .. " more. It fades when you stop fighting.\n"
        .. "Death Strike needs " .. BK.RP_COST[2] .. " (the white mark). With " .. BK.OSSUARY_STACKS
        .. "+ Bone Shield (Ossuary) it needs " .. (BK.RP_COST[2] - BK.OSSUARY_COST_CUT) .. " and the bar holds "
        .. (BK.RP_MAX + BK.OSSUARY_RP_BONUS) .. ".",
    TIP_SHIELD = "Bone Shield. With at least one stack you take "
        .. math.floor(BK.SHIELD_REDUCTION * 100 + 0.5) .. "% less damage. Each hit costs a stack.",
    TIP_DEBT = "Blood Debt. Every Death Strike adds one, each one gives +" .. (BK.DEBT_PER_STACK * 100)
        .. "% damage. At " .. BK.DEBT_MAX
        .. " the next Marrowrend spends them: bonus damage, extra Bone Shield and a shadow burst.",
}

--------------------------------------------------------------------------
-- Crafting: Death Knight Plate and Helm (only the Blood Knight can make them)
--------------------------------------------------------------------------

local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

--------------------------------------------------------------------------
-- Crafting stations (bk_stations.lua). Standing next to one gives the Blood
-- Knight a builder tag (UpdateCraftTags in the component); the recipes
-- below ask for those tags, so they only show up at the station.
--------------------------------------------------------------------------

AddRecipe2("bk_runeforge_station",
    { Ingredient("cutstone", 3), Ingredient("boneshard", 4), Ingredient("nightmarefuel", 3) },
    TECH.NONE,
    { builder_tag = "bloodknight", placer = "bk_runeforge_station_placer", min_spacing = 2,
      image = "shadow_forge_kit.tex" }, -- stock Shadow Forge icon
    { "STRUCTURES", "CHARACTER" })

AddRecipe2("bk_armortable_station",
    { Ingredient("boards", 4), Ingredient("boneshard", 4), Ingredient("nightmarefuel", 2) },
    TECH.NONE,
    { builder_tag = "bloodknight", placer = "bk_armortable_station_placer", min_spacing = 2,
      image = "sewing_mannequin.tex" }, -- stock Mannequin icon
    { "STRUCTURES", "CHARACTER" })

--------------------------------------------------------------------------
-- Armor tiers (Runic Armor Table). Tier N needs a Rune Blade of tier
-- ARMOR_BLADE_TIER[N] in hand ("bk_armor_tN" tag). An upgrade is crafted
-- from the tier below and keeps its charge.
--------------------------------------------------------------------------

local function ArmorRecipe(name, ingredients, tier, image)
    AddRecipe2(name, ingredients, TECH.NONE,
        { builder_tag = "bk_armor_t" .. tier, image = image },
        { "ARMOUR", "CHARACTER" })
end
local function OldPiece(prefab, image)
    return Ingredient(prefab, 1, nil, nil, image)
end

-- Tier 1
ArmorRecipe("bk_armor", { Ingredient("boneshard", 6), Ingredient("nightmarefuel", 4), Ingredient("redgem", 1) }, 1, "armorskeleton.tex")
ArmorRecipe("bk_helm", { Ingredient("boneshard", 4), Ingredient("nightmarefuel", 3), Ingredient("redgem", 1) }, 1, "skeletonhat.tex")
-- Tier 2
ArmorRecipe("bk_armor_t2", { OldPiece("bk_armor", "armorskeleton.tex"), Ingredient("marble", 6), Ingredient("redgem", 2), Ingredient("nightmarefuel", 6) }, 2, "armorskeleton.tex")
ArmorRecipe("bk_helm_t2", { OldPiece("bk_helm", "skeletonhat.tex"), Ingredient("marble", 4), Ingredient("redgem", 1), Ingredient("nightmarefuel", 4) }, 2, "skeletonhat.tex")
-- Tier 3
ArmorRecipe("bk_armor_t3", { OldPiece("bk_armor_t2", "armorskeleton.tex"), Ingredient("thulecite", 6), Ingredient("purplegem", 1), Ingredient("nightmarefuel", 6) }, 3, "armorskeleton.tex")
ArmorRecipe("bk_helm_t3", { OldPiece("bk_helm_t2", "skeletonhat.tex"), Ingredient("thulecite", 4), Ingredient("purplegem", 1), Ingredient("nightmarefuel", 4) }, 3, "skeletonhat.tex")

--------------------------------------------------------------------------
-- Progression: Rune Blade tiers
--
-- Each tier is crafted from the one below it. The blade must be in the
-- inventory (not in your hand) to be used as an ingredient. All tiers share
-- the Rune Blade icon for now.
--------------------------------------------------------------------------

local BLADE_ATLAS = "images/inventoryimages/bk_runeblade.xml"
-- upgrades need the Rune Forge ("bk_at_runeforge"); the Tier 1 replacement works anywhere
local BLADE_CONFIG = { builder_tag = "bk_at_runeforge", atlas = BLADE_ATLAS, image = "bk_runeblade.tex" }
local function BladeIngredient(prefab)
    return Ingredient(prefab, 1, BLADE_ATLAS, nil, "bk_runeblade.tex")
end
local function BladeConfig(extra)
    local config = {}
    for k, v in pairs(BLADE_CONFIG) do
        config[k] = v
    end
    for k, v in pairs(extra or {}) do
        config[k] = v
    end
    return config
end

-- Runeforging: engrave the Rune Blade in your hand (bk_runes.lua). One rune
-- per blade; "bk_runeforge" = standing at a Rune Forge with a blade in hand.
local RUNE_RECIPES =
{
    { "crusader",     "amulet.tex",       { Ingredient("goldnugget", 4), Ingredient("lightbulb", 3), Ingredient("nightmarefuel", 2) } },
    { "gargoyle",     "marble.tex",       { Ingredient("marble", 4), Ingredient("cutstone", 2), Ingredient("nightmarefuel", 2) } },
    { "sanguination", "mosquitosack.tex", { Ingredient("mosquitosack", 2), Ingredient("redgem", 1), Ingredient("nightmarefuel", 2) } },
    { "thirst",       "batwing.tex",      { Ingredient("batwing", 4), Ingredient("monstermeat", 4), Ingredient("redgem", 1), Ingredient("nightmarefuel", 4) } },
    { "razorice",     "bluegem.tex",      { Ingredient("bluegem", 3), Ingredient("ice", 10), Ingredient("walrus_tusk", 1), Ingredient("nightmarefuel", 4) } },
}
for _, r in ipairs(RUNE_RECIPES) do
    AddRecipe2("bk_rune_" .. r[1], r[3], TECH.NONE,
        { builder_tag = "bk_runeforge", image = r[2] },
        { "WEAPONS", "CHARACTER" })
end

-- Tier 1: replace a lost blade
AddRecipe2("bk_runeblade",
    { Ingredient("twigs", 2), Ingredient("flint", 2), Ingredient("nightmarefuel", 1) },
    TECH.NONE, BladeConfig({ builder_tag = "bloodknight" }), { "WEAPONS", "CHARACTER" })

-- Tier 2: Runed Blade
AddRecipe2("bk_runeblade_t2",
    { BladeIngredient("bk_runeblade"), Ingredient("goldnugget", 3), Ingredient("nightmarefuel", 4), Ingredient("boneshard", 4) },
    TECH.NONE, BladeConfig(), { "WEAPONS", "CHARACTER" })

-- Tier 3: Bloodforged Blade
AddRecipe2("bk_runeblade_t3",
    { BladeIngredient("bk_runeblade_t2"), Ingredient("redgem", 2), Ingredient("purplegem", 1), Ingredient("livinglog", 2), Ingredient("nightmarefuel", 6) },
    TECH.NONE, BladeConfig(), { "WEAPONS", "CHARACTER" })

-- Tier 4: Runeblade of the Ebon Blade.
-- One recipe per boss trophy, any of them works.
for _, trophy in ipairs({ "deerclops_eyeball", "bearger_fur", "dragon_scales" }) do
    AddRecipe2("bk_runeblade_t4_" .. trophy,
        { BladeIngredient("bk_runeblade_t3"), Ingredient("thulecite", 6), Ingredient("purplegem", 1), Ingredient(trophy, 1) },
        TECH.NONE, BladeConfig({ product = "bk_runeblade_t4" }), { "WEAPONS", "CHARACTER" })
end

--------------------------------------------------------------------------
-- Casting: key press / button click -> RPC -> server component
--------------------------------------------------------------------------

-- `target` (optional) is the entity under the player's mouse, used by
-- Death Grip and Dark Command. The server checks it again before using it.
AddModRPCHandler("BloodKnight", "Cast", function(player, id, target)
    if type(id) ~= "number" then
        return
    end
    if type(target) ~= "table" or target.IsValid == nil or not target:IsValid() then
        target = nil
    end
    local bk = player ~= nil and player.components.bk_bloodknight or nil
    if bk ~= nil then
        bk:Cast(id, target)
    end
end)

--------------------------------------------------------------------------
-- Stun resistance: stunned at most once every STUN_IMMUNE_TIME seconds
--
-- The player stategraph sends hits to "hit" (stagger), knockbacks to
-- "knockback" and electric hits to "electrocute". For the Blood Knight we
-- wrap those two event handlers: right after a stun, the next ones only
-- play the hurt sound instead of interrupting him.
--------------------------------------------------------------------------

local STUN_STATES =
{
    hit = true, hit_push = true, hit_spike = true, hit_darkness = true,
    electrocute = true, knockback = true, knockbacklanded = true,
}
-- states where a hit does something special (wake up, parry, ...): never skipped
local SPECIAL_TAGS = { "sleeping", "bedroll", "knockout", "parrying", "devoured", "suspended",
    "drowning", "falling", "transform", "dismounting", "shell", "wxshielding" }

AddStategraphPostInit("wilson", function(sg)
    for _, name in ipairs({ "attacked", "knockback" }) do
        local handler = sg.events[name]
        if handler ~= nil then
            local original = handler.fn
            handler.fn = function(inst, data)
                if not inst:HasTag("bloodknight") then
                    return original(inst, data)
                end
                local now = GLOBAL.GetTime()
                local last = inst.sg.mem.bk_laststun
                if last ~= nil and now - last < BK.STUN_IMMUNE_TIME
                    and not inst.components.health:IsDead()
                    and not inst.sg:HasAnyStateTag(GLOBAL.unpack(SPECIAL_TAGS)) then
                    inst.SoundEmitter:PlaySound("dontstarve/wilson/hit") -- felt it, kept going
                    return
                end
                local before = inst.sg.currentstate
                original(inst, data)
                if inst.sg.currentstate ~= before and STUN_STATES[inst.sg.currentstate.name] then
                    inst.sg.mem.bk_laststun = now
                end
            end
        end
    end
end)

--------------------------------------------------------------------------
-- HUD (only built for the Blood Knight's own player)
--------------------------------------------------------------------------

AddClassPostConstruct("widgets/controls", function(self)
    local owner = self.owner
    if owner == nil or not owner:HasTag("bloodknight") then
        return
    end
    local BKHud = require("widgets/bk_hud")
    self.bk_hud = self.bottom_root:AddChild(BKHud(owner, HUD_CONFIG))
end)

--------------------------------------------------------------------------
-- Character registration
--------------------------------------------------------------------------

-- The ghost shown in the cycle view on the character select screen.
local skin_modes =
{
    {
        type = "ghost_skin",
        anim_bank = "ghost",
        idle_anim = "idle",
        scale = 0.75,
        offset = { 0, -25 },
    },
}

-- Possible genders: MALE, FEMALE, ROBOT, NEUTRAL, PLURAL.
AddModCharacter("bloodknight", "MALE", skin_modes)
