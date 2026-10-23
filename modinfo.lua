-- Blood Knight: a Blood Death Knight character for Don't Starve Together.
-- NOTE: modinfo.lua runs in a bare environment (no `string`, `math`, `table`
-- globals), so only core Lua syntax is used here.

name = "Blood Knight"
description = "A tanky Blood Death Knight inspired by World of Warcraft: Midnight Season 2.\n\n"
    .. "Spend Runes on Heart Strike, Death Strike, Marrowrend, Blood Boil, Death and Decay "
    .. "and Dancing Rune Weapon. Keep your Bone Shield up and hold the line against bosses.\n\n"
    .. "Default keys: Z X C V B R (change them in the mod's client settings)."
author = "Vladyslav-Sharapov"
version = "0.1.0"
forumthread = ""

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true
client_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = { "character" }

---------------------------------------------------------------------------
-- Configuration helpers
---------------------------------------------------------------------------

-- KEY_A .. KEY_Z are 97 .. 122 in Don't Starve Together.
local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local function KeyOptions()
    local opts = {}
    for i = 1, 26 do
        opts[i] = { description = LETTERS:sub(i, i), data = 96 + i }
    end
    return opts
end

local function KeyOption(optname, label, default_key, hover)
    return {
        name = optname,
        label = label,
        hover = hover,
        options = KeyOptions(),
        default = default_key,
        client = true, -- every player picks their own keys
    }
end

-- An option with a single, empty-text choice is drawn as a section header.
local function Header(title)
    return { name = "", label = title, options = { { description = "", data = 0 } }, default = 0 }
end

configuration_options =
{
    Header("Keybinds (per player)"),
    KeyOption("key_hs",  "Heart Strike",         122, "Default Z. Hits 2 enemies (5 in Death and Decay) and heals you."),
    KeyOption("key_ds",  "Death Strike",         120, "Default X. Strong hit (+2 nearby enemies at 60%) that heals from recent damage."),
    KeyOption("key_mr",  "Marrowrend",            99, "Default C. Rebuilds your Bone Shield."),
    KeyOption("key_bb",  "Blood Boil",           118, "Default V. AoE burst that applies Blood Plague."),
    KeyOption("key_dd",  "Death and Decay",       98, "Default B. Ground zone that hurts enemies."),
    KeyOption("key_drw", "Dancing Rune Weapon",  114, "Default R. Spectral blade, dodge and Runic Power."),
    KeyOption("key_grip", "Death Grip",          103, "Default G. Pulls the enemy under your mouse (or one attacking a friend) to you and taunts it."),
    KeyOption("key_dc",  "Dark Command",         116, "Default T. Taunts the enemy under your mouse (or one attacking a friend)."),
    KeyOption("key_vb",  "Vampiric Blood",       104, "Default H. +30% max health and healing for 10 s."),
    KeyOption("key_rd",  "Raise Dead",           106, "Default J. A ghoul fights for you for 1 minute."),

    Header("HUD (per player)"),
    {
        name = "hud_scale",
        label = "HUD size",
        hover = "Size of the rune / ability bar above the inventory.",
        options = {
            { description = "Small",  data = 0.8 },
            { description = "Normal", data = 1.0 },
            { description = "Large",  data = 1.25 },
            { description = "Huge",   data = 1.5 },
        },
        default = 1.0,
        client = true,
    },
    {
        name = "hud_y",
        label = "HUD height",
        hover = "Move the bar up if it overlaps your backpack or chest.",
        options = {
            { description = "Low",     data = 100 },
            { description = "Normal",  data = 135 },
            { description = "High",    data = 190 },
            { description = "Higher",  data = 250 },
        },
        default = 135,
        client = true,
    },

    Header("Gameplay (server)"),
    {
        name = "hs_mode",
        label = "Heart Strike",
        hover = "Manual: press the key. Auto: normal attacks become Heart Strikes while you have 2+ runes.",
        options = {
            { description = "Manual key", data = "manual" },
            { description = "Auto on attack", data = "auto" },
        },
        default = "manual",
    },
    {
        name = "rune_time",
        label = "Rune recharge",
        hover = "Seconds for one rune to recharge. Up to 3 runes recharge at once, like in WoW (default: 10).",
        options = {
            { description = "4s",  data = 4 },
            { description = "6s",  data = 6 },
            { description = "8s",  data = 8 },
            { description = "10s", data = 10 },
            { description = "12s", data = 12 },
        },
        default = 10,
    },
    {
        name = "damage_scale",
        label = "Ability damage",
        hover = "Scales Blood Boil, Death and Decay, Blood Plague and the spectral blade.",
        options = {
            { description = "50%",  data = 0.5 },
            { description = "75%",  data = 0.75 },
            { description = "100%", data = 1.0 },
            { description = "150%", data = 1.5 },
            { description = "200%", data = 2.0 },
        },
        default = 1.0,
    },
}
