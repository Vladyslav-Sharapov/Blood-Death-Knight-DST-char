-- Blood Knight balance numbers.
-- Loaded by modmain.lua via require("bk_tuning"); everything lives in
-- TUNING.BK so the character prefab, the server component, the world
-- prefabs and the client HUD all read the same values.
--
-- To rebalance the character, edit the numbers below (or use the mod's
-- configuration screen for the few options exposed there).

TUNING.BK = {
    ---------------------------------------------------------------- stats
    HEALTH = 150,               -- standard DST health; the healing kit does the tanking
    HUNGER = 150,
    SANITY = 150,
    HUNGER_RATE_MULT = 1.25,    -- hunger drains this much faster
    FOOD_HEALTH_ABSORB = 0.5,   -- food restores only this share of its health

    ------------------------------------------------------------- resources
    -- Runes work like World of Warcraft (Legion and later): 6 runes, up to 3
    -- of them recharge at the same time, every rune spent gives Runic Power.
    RUNES_MAX = 6,
    RUNES_RECHARGING = 3,       -- how many runes recharge at once
    RUNE_RECHARGE = 10,         -- seconds for one rune to recharge (config: rune_time)
    RP_PER_RUNE = 10,           -- Runic Power for every rune spent

    RP_MAX = 125,
    RP_PER_HEART_STRIKE = 5,    -- like WoW: on top of the rune's 10, so 15 per strike
    RP_DRW_BONUS = 10,          -- extra RP when the rune weapon copies a Heart Strike (WoW: 3)
    RP_PER_DRW_BLADE_HIT = 5,   -- RP each time the rune weapon copies one of your normal attacks
    RP_DECAY_DELAY = 6,         -- seconds out of combat before Runic Power drains
    RP_DECAY_RATE = 2,          -- RP lost per second once it starts draining

    SHIELD_MAX = 10,
    SHIELD_REDUCTION = 0.20,    -- damage taken is multiplied by (1 - this) while shield >= 1
    SHIELD_HIT_ICD = 1.5,       -- a hit removes at most one stack per this many seconds
    SHIELD_PER_MARROWREND = 3,
    SHIELD_TIME = 30,           -- like WoW: Bone Shield fades 30 s after it was last built up
    SHARD_STACKS = 3,           -- stacks restored by an automatically consumed Bone Shard
    SHARD_ICD = 8,              -- seconds between automatic Bone Shard uses

    -------------------------------------------------------------- abilities
    -- Index order is the ability id used by the keybinds / RPC / HUD:
    -- 1 Heart Strike, 2 Death Strike, 3 Marrowrend, 4 Blood Boil,
    -- 5 Death and Decay, 6 Dancing Rune Weapon,
    -- 7 Death Grip, 8 Dark Command, 9 Vampiric Blood, 10 Raise Dead
    -- Blood Boil / Death and Decay: short pause between their charges (the real
    -- recharge is BB_RECHARGE / DD_RECHARGE). DRW 3 min, Death Grip 15 s,
    -- Dark Command 8 s, Vampiric Blood 90 s, Raise Dead 2 min: like WoW.
    COOLDOWN = { 0.5, 2, 0.3, 0.3, 0.3, 180, 15, 8, 90, 120 },
    RUNE_COST = { 1, 0, 2, 0, 1, 0, 0, 0, 0, 0 },
    RP_COST = { 0, 45, 0, 0, 0, 0, 0, 0, 0, 0 },  -- Death Strike: 45 like WoW (40 with Ossuary)

    -- Stun resistance: after being staggered, knocked back or electrocuted,
    -- the Blood Knight cannot be stunned again for this many seconds (hits
    -- still do damage, they just do not interrupt you).
    STUN_IMMUNE_TIME = 3,

    -- Threat (like a WoW tank): every enemy your ABILITIES hit turns to attack
    -- you, even if it was chasing a friend. Taunts (Death Grip, Dark Command)
    -- also hold it on you for TAUNT_TIME seconds.
    TAUNT_TIME = 3,

    -- Death Grip: pull an enemy to you and taunt it (bosses are only taunted)
    GRIP_RANGE = 14,
    GRIP_DISTANCE = 1.5,        -- where it lands, in front of you (plus its own size)

    -- Dark Command: taunt from range
    DC_RANGE = 16,

    -- Vampiric Blood: +30% max health (you get that health too) and +30% healing
    -- and absorbs received, for 10 s
    VB_HEALTH = 0.30,
    VB_HEAL = 0.30,
    VB_TIME = 10,

    -- Raise Dead (Blood version): a ghoul fights for you for 1 minute. Only one at a time.
    GHOUL_TIME = 60,

    -- Purgatory (passive, like WoW): damage that would kill you is prevented.
    -- Instead you must be HEALED for that much within 3 s, or you die when it
    -- ends. Further damage during those 3 s cannot kill you either, it just
    -- adds to the healing you need. Then it cannot happen again for 4 minutes.
    PURGATORY_TIME = 3,
    PURGATORY_COOLDOWN = 240,

    -- Heart Strike
    HS_RANGE = 3.5,             -- how far away it will pick a target
    HS_TARGETS = 2,             -- enemies hit in total (main target included)
    HS_TARGETS_DECAY = 5,       -- ...while you stand in your Death and Decay
    HS_CLEAVE_RADIUS = 3.5,     -- the extra targets are picked this close to you
    HS_CLEAVE_MULT = 0.75,      -- of your normal hit damage, for the extra enemies
    HS_HEAL_PER_ENEMY = 3,      -- health you regain for each enemy hit (main target included)
    HS_HEAL_MAX = 12,           -- most health one Heart Strike can heal
    HS_SLOW = 0.20,             -- like WoW: enemies hit move 20% slower...
    HS_SLOW_TIME = 8,           -- ...for 8 seconds

    -- Marrowrend (like WoW): a strong hit on your target as well as the Bone
    -- Shield. WoW: 220.65% of Attack Power vs Heart Strike's 196.7%, so ~1.1x.
    MR_MULT = 1.1,              -- of your normal hit damage

    -- Death Strike
    -- WoW (Midnight): 20% of damage taken in the last 5 s, at least 7% of max
    -- health; Blood's Improved Death Strike talent adds 15% (20% x 1.15 = 23%)
    DS_HEAL_PCT = 0.23,         -- of damage taken in the window
    DS_WINDOW = 5,
    DS_MIN_HEAL_PCT = 0.07,     -- of max health
    -- WoW: Death Strike is single-target; Blood's Deadly Reach talent makes it
    -- also hit 2 nearby enemies for 60% of its damage (hotfix 22 Sep 2026)
    DS_REACH_RADIUS = 3.5,      -- how close to you the 2 extra enemies must be
    DS_REACH_TARGETS = 2,       -- extra enemies hit (the closest ones)
    DS_REACH_MULT = 0.6,        -- of the main Death Strike hit
    DS_TARGET_BONUS = 1.0,      -- extra hit on the main target on top of the swing (swing 1.0 + this = 2x)
    -- WoW's Blood mastery "Blood Shield": Death Strike's heal also gives an absorb shield
    DS_BLOOD_SHIELD = 0.5,      -- shield = this share of the Death Strike heal
    DS_BLOOD_SHIELD_TIME = 10,  -- seconds the shield lasts (a new Death Strike adds to it and refreshes it)
    -- WoW's Hemostasis: every enemy hit by Blood Boil makes the next Death Strike stronger
    HEMO_PER_STACK = 0.08,      -- +8% Death Strike damage and healing per stack
    HEMO_MAX = 5,               -- at most 5 stacks (+40%); Death Strike uses them all up
    -- WoW's Ossuary: with at least 5 Bone Shield stacks Death Strike is cheaper
    -- and the Runic Power bar is bigger
    OSSUARY_STACKS = 5,
    OSSUARY_COST_CUT = 5,       -- Death Strike costs 40 instead of 45
    OSSUARY_RP_BONUS = 10,      -- max Runic Power 135 instead of 125
    -- WoW's Coagulopathy (Midnight): enemies with Blood Plague take more damage
    -- from you, and every Death Strike makes your Blood Plague stronger
    COAG_TARGET_DAMAGE = 0.05,  -- +5% damage from you to enemies with Blood Plague
    COAG_PER_STACK = 0.10,      -- +10% Blood Plague damage per stack
    COAG_MAX = 4,
    COAG_TIME = 15,             -- seconds, refreshed by every Death Strike

    -- Blood Boil
    BB_CHARGES = 2,             -- uses stored up; Blood Boil costs no runes
    BB_RECHARGE = 7.5,          -- seconds to get one charge back (WoW: 7.5)
    BB_RADIUS = 4.5,
    BB_MULT = 0.8,              -- of your normal hit damage (scaled by "Ability damage")
    PLAGUE_DPS = 3,             -- damage per second (scaled by "Ability damage")
    PLAGUE_TIME = 24,
    PLAGUE_HEAL_PER_TARGET = 1, -- health per second you regain for each enemy with Blood Plague
    PLAGUE_HEAL_MAX = 4,        -- most health per second Blood Plague can give back in total
    PLAGUE_TINT = { 0.35, 0, 0.05 }, -- red glow added to enemies that have Blood Plague

    -- Death and Decay
    -- like WoW: 30 s cooldown, 1 rune, ~10 s on the ground; here with 2 charges
    DD_CHARGES = 2,
    DD_RECHARGE = 30,           -- seconds to get one charge back
    DD_RADIUS = 6,
    DD_TIME = 10,
    DD_DPS = 8,                 -- damage per second to each enemy inside
    DD_DEFENSE = 0.15,          -- extra damage reduction while you stand inside
    DD_TICK = 1,
    -- WoW's Crimson Scourge: each normal swing that hits an enemy with Blood
    -- Plague has a 25% chance to give back a Death and Decay charge and make
    -- the next Death and Decay free (no rune)
    CRIMSON_CHANCE = 0.25,
    CRIMSON_TIME = 15,          -- seconds the free Death and Decay is kept

    -- Dancing Rune Weapon
    -- Works like WoW: the rune weapon copies every attack and ability you use
    -- (it does not attack on its own), you parry (here: dodge) more often,
    -- losing Bone Shield stacks lowers the cooldown, and when it ends your
    -- runes recharge faster for a while.
    DRW_TIME = 8,
    DRW_DODGE = 0.30,           -- WoW: +30% parry (patch 12.1)
    DRW_BLADE_MULT = 0.6,       -- rune weapon's copy of a hit, of your normal hit damage
    DRW_CDR_PER_SHIELD = 3,     -- seconds off the cooldown for every Bone Shield stack you lose
    DRW_END_HASTE = 0.4,        -- runes recharge 40% faster after the weapon fades...
    DRW_END_HASTE_TIME = 10,    -- ...for this many seconds
    DRW_FREE_HS_TIME = 15,      -- how long a "free Heart Strike" proc is kept (WoW: 15 s)

    ------------------------------------------------------- Season 2 systems
    DEBT_MAX = 10,
    DEBT_PER_STACK = 0.005,     -- like WoW: +0.5% damage per Blood Debt stack while building (up to 5%)
    DEBT_DAMAGE = 1.10,         -- damage dealt multiplier while the buff is up
    DEBT_TIME = 10,
    DEBT_EXTRA_SHIELD = 3,
    DEBT_BURST_RADIUS = 5,
    DEBT_BURST_MULT = 1.0,

    -- Dance of Midnight (WoW Blood apex talent, all 4 ranks)
    DOM_CHANCE = 0.125,         -- rank 4: chance per rune spent to call a rune weapon (WoW: 12.5%)
    DOM_TIME = 8,               -- ...for 8 s (WoW)
    DOM_DODGE_CHANCE = 0.25,    -- rank 1: chance per dodge during DRW for a free, empowered Heart Strike
                                -- (WoW says only "a chance"; 25% is our pick)
    DOM_HS_BONUS = 1.5,         -- rank 1: that Heart Strike deals +150% damage
    DOM_DAMAGE = 0.06,          -- ranks 2-3: +6% damage dealt while a rune weapon is out
    DOM_DEFENSE = 0.06,         -- ranks 2-3: -6% damage taken while a rune weapon is out

    ------------------------------------------------------------ rune blade
    ------------------------------------------------- progression (Rune Blade tiers)
    -- The Rune Blade is upgraded by crafting (recipes in modmain.lua). The
    -- abilities only work while you HOLD a Rune Blade, and its tier decides
    -- which ones: 1 Rune Blade, 2 Runed Blade, 3 Bloodforged Blade,
    -- 4 Runeblade of the Ebon Blade.
    BLADE_DAMAGE = { 15, 20, 25, 30 },          -- plain swings, per tier
    BLADE_ABILITY_DAMAGE = { 15, 25, 40, 60 },  -- what abilities count as the blade's damage, per tier

    -- tier needed for each ability (same order as COOLDOWN):
    -- HS, DS, Marrowrend, Blood Boil, DnD, DRW, Grip, Dark Command, Vampiric Blood, Raise Dead
    ABILITY_TIER = { 1, 1, 1, 1, 2, 4, 2, 2, 3, 3 },

    -- tier needed for each passive talent
    TALENT_TIER =
    {
        crimson = 2,        -- Crimson Scourge
        hemostasis = 2,
        bloodshield = 3,    -- Blood Shield from Death Strike
        ossuary = 3,
        coagulopathy = 3,
        dance = 4,          -- Dance of Midnight (all ranks)
        purgatory = 4,
        blooddebt = 4,      -- Blood Debt (the Season 2 "tier set")
    },
    -- Crafting stations (bk_stations.lua): stand this close to use them
    STATION_RANGE = 4,

    ----------------------------------------------------------- runeforging
    -- Like WoW: engrave ONE rune into your Rune Blade (any tier). A new rune
    -- replaces the old one, and upgrading the blade keeps its rune.
    -- Fallen Crusader: hits have a chance to heal 4% and give +15% damage (WoW: Strength) for 15 s
    CRUSADER_CHANCE = 0.10,
    CRUSADER_HEAL = 0.04,
    CRUSADER_DAMAGE = 0.15,
    CRUSADER_TIME = 15,
    -- Stoneskin Gargoyle: WoW +5% armor and +5% all stats
    GARGOYLE_DEFENSE = 0.05,    -- 5% less damage taken
    GARGOYLE_DAMAGE = 0.05,     -- 5% more damage
    -- Sanguination: Death Strike hits harder the more health the target is missing;
    -- falling below 35% health heals you over time (once every 2 min)
    SANGUINATION_DS_BONUS = 0.5,    -- up to +50% Death Strike damage on an almost dead target
    SANGUINATION_THRESHOLD = 0.35,
    SANGUINATION_HEAL = 0.48,       -- 48% of max health...
    SANGUINATION_TIME = 8,          -- ...over 8 s
    SANGUINATION_COOLDOWN = 120,
    -- Unending Thirst: +5% move speed; every kill heals and speeds you up
    THIRST_SPEED = 0.05,
    THIRST_KILL_HEAL = 0.05,        -- 5% of max health per kill
    THIRST_KILL_SPEED = 0.10,       -- +10% move speed and rune recharge...
    THIRST_KILL_TIME = 10,          -- ...for 10 s
    -- Razorice: extra frost damage, and each hit makes the target take more from you
    RAZORICE_DAMAGE = 0.04,         -- +4% damage on every hit
    RAZORICE_PER_STACK = 0.03,      -- +3% damage taken from you per stack
    RAZORICE_MAX = 5,
    RAZORICE_TIME = 20,

    ---------------------------------------------------------- bone armor
    -- Death Knight Plate (body) and Death Knight Helm (head) never break, but
    -- they only protect while they hold Soul charge. Blocked damage drains
    -- the charge; souls of nearby kills (Wortox's souls) refill it.
    -- Armor tiers, crafted at the Runic Armor Table. Plate and Helm use the
    -- same numbers per tier. Tier N needs a Rune Blade of tier N+1 in hand.
    --   absorb:  share of damage blocked while it has charge
    --   default: what 100% charge is worth with nothing attacking you
    --   cap:     the most 100% charge can be worth (see AGGRO_SCALE)
    ARMOR_TIERS =
    {
        { absorb = 0.50, default = 350, cap = 1000 },  -- 1 Death Knight Plate / Helm
        { absorb = 0.60, default = 450, cap = 1500 },  -- 2 Runed Plate / Helm
        { absorb = 0.70, default = 550, cap = 2000 },  -- 3 Ebon Plate / Helm
    },
    ARMOR_BLADE_TIER = { 2, 3, 4 },  -- Rune Blade tier needed in hand to craft armor tier 1 / 2 / 3
    -- The charge is kept as a percentage. How much damage 100% is worth
    -- ("max charge") scales with the fight: HALF the total max health of
    -- every enemy attacking you, between MIN_CHARGE and the tier's cap. With
    -- nothing attacking you it is the tier's default.
    MIN_CHARGE = 150,           -- max charge never goes below this, even against tiny mobs
    AGGRO_SCALE = 0.5,          -- only HALF of the attacking enemies' health counts
    AGGRO_RADIUS = 25,          -- enemies this close that target you count as "aggro"
    SOUL_CHARGE_PCT = 0.17,     -- one soul refills 17% of the charge
    CHARGE_DRAIN = 0.4,         -- max charge used per point of damage blocked (full charge blocks max / 0.4)
    SOUL_FLY_DELAY = 0.8,       -- seconds a soul hovers over the corpse before flying to you

    --------------------------------------------------------- visual effects
    -- Stock Don't Starve effects used as placeholders. They are listed in
    -- the character's prefab dependencies so the game loads them.
    FX = {
        SHIELD = "elixir_player_forcefield",
        HEAL = "pocketwatch_heal_fx",
        WISP = "wurt_terraformer_fx_shadow",
        PUFF = "shadow_puff",
        PUFF_BIG = "shadow_puff_large_front",
        RING = "slingshot_aoe_fx",          -- flat ring on the ground, tinted with SetColorType()
        SMOKE = "statue_transition_2",
        PORTAL_IN = "shadow_teleport_in",
        PORTAL_OUT = "shadow_teleport_out",
    },

    FX_RING_RADIUS = 3,         -- radius of that ring picture at scale 1 (used to size it)

    ------------------------------------------------------- set from config
    AUTO_HS = false,            -- config "hs_mode"
    DAMAGE_SCALE = 1.0,         -- config "damage_scale"
}

return TUNING.BK
