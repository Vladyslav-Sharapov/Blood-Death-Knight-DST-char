-- The "base skin" of the character. The game uses it to find the character's
-- animation build (and the ghost build).
--
-- Until the custom art exists (anim/bloodknight.zip and
-- anim/ghost_bloodknight_build.zip, see ART_GUIDE.md) the character falls
-- back to the stock Wilson / Wilson-ghost builds, so the mod is playable
-- from day one.

local ART = rawget(_G, "BK_ART") or {}

local assets = {}
if ART.build then
    table.insert(assets, Asset("ANIM", "anim/bloodknight.zip"))
end
if ART.ghost then
    table.insert(assets, Asset("ANIM", "anim/ghost_bloodknight_build.zip"))
end

local normal_build = ART.build and "bloodknight" or "wilson"
local ghost_build = ART.ghost and "ghost_bloodknight_build" or "ghost_wilson_build"

local skins =
{
    normal_skin = normal_build,
    ghost_skin = ghost_build,
}

return CreatePrefabSkin("bloodknight_none",
{
    base_prefab = "bloodknight",
    type = "base",
    assets = assets,
    skins = skins,
    skin_tags = { "BLOODKNIGHT", "CHARACTER", "BASE" },
    build_name_override = normal_build,
    rarity = "Character",
})
