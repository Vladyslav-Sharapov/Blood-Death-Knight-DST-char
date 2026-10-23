--------------------------------------------------------------------------
-- What the Blood Knight says.
--
-- The game asks the character table for hundreds of lines (every item,
-- every announcement). To make sure none of them is ever missing we start
-- from a copy of the stock generic lines and then replace the ones that
-- should sound like a grim, dry-humoured Death Knight.
--
-- Add or change lines at the bottom of this file. Keys are the same as in
-- the game's own scripts/speech_wilson.lua.
--------------------------------------------------------------------------

local function DeepCopy(source, seen)
    if type(source) ~= "table" then
        return source
    end
    seen = seen or {}
    if seen[source] ~= nil then
        return seen[source]
    end
    local copy = {}
    seen[source] = copy
    for k, v in pairs(source) do
        copy[k] = DeepCopy(v, seen)
    end
    return copy
end

local speech = DeepCopy(STRINGS.CHARACTERS.GENERIC)

--------------------------------------------------------------------------
-- Blood Knight mechanics (keys used by scripts/components/bk_bloodknight.lua)
--------------------------------------------------------------------------

speech.ANNOUNCE_BK_NORUNES = "My runes are still recharging."
speech.ANNOUNCE_BK_NORP = "I need more Runic Power for that."
speech.ANNOUNCE_BK_NOTARGET = "Nothing in reach to strike."
speech.ANNOUNCE_BK_NOCHARGES = "Not ready yet. It is still recharging."
speech.ANNOUNCE_BK_NOBLADE = "I need my Rune Blade in hand."
speech.ANNOUNCE_BK_LOCKED = "My blade is not strong enough for that yet."
speech.ANNOUNCE_BK_PURGATORY = "Not yet! The grave can wait!"
speech.ANNOUNCE_BK_PURGATORY_FAIL = "The pact... is called in..."

--------------------------------------------------------------------------
-- Everyday announcements
--------------------------------------------------------------------------

speech.ANNOUNCE_HUNGRY = "The blood wants meat. So do I."
speech.ANNOUNCE_COLD = "Cold? The grave was colder."
speech.ANNOUNCE_HOT = "Too hot. Even this armour is cooking me."
speech.ANNOUNCE_DUSK = "Dusk. The shadows are waking."
speech.ANNOUNCE_ENTER_DARK = "The dark again. Good. I am ready."
speech.ANNOUNCE_DAMP = "Rain on steel. Wonderful."
speech.ANNOUNCE_GHOSTDRAIN = "My grip on the living is slipping..."
speech.ANNOUNCE_REVIVING_CORPSE = "Not yet. Stay with me."
speech.ANNOUNCE_ACCOMPLISHMENT = "A fight well won."
speech.ANNOUNCE_PECKED = "Get off my armour, bird!"
speech.ANNOUNCE_BEES = "Bees! My shield will not stop those!"
speech.ANNOUNCE_NODANGERSLEEP = "No sleep. Not with that thing out there."
speech.ANNOUNCE_CHARLIE = "Something hunts in the dark. I can feel it."

--------------------------------------------------------------------------
-- Descriptions
--------------------------------------------------------------------------

speech.DESCRIBE.BK_RUNEBLADE = "Runes crawl along the edge. It is warm in my hand."
speech.DESCRIBE.BK_RUNEBLADE_T2 = "The runes burn brighter. It remembers how to kill."
speech.DESCRIBE.BK_RUNEBLADE_T3 = "Forged in blood. It drinks before I do."
speech.DESCRIBE.BK_RUNEBLADE_T4 = "The Ebon Blade's own steel. Nothing stands against it."
speech.DESCRIBE.BK_RUNEFORGE_STATION = "The runeforge. Here the blade learns new hungers."
speech.DESCRIBE.BK_ARMORTABLE_STATION = "Bone, plate and souls. My armor takes shape here."
speech.DESCRIBE.BK_ARMOR_T2 = "Runes hold the souls tighter now."
speech.DESCRIBE.BK_ARMOR_T3 = "Ebon plate. The Lich King would be jealous."
speech.DESCRIBE.BK_HELM_T2 = "Runes hold the souls tighter now."
speech.DESCRIBE.BK_HELM_T3 = "Ebon steel. My face is the last thing they see."
speech.DESCRIBE.BK_ARMOR = "Bone and blood. It hungers for souls."
speech.DESCRIBE.BK_HELM = "It whispers for the souls of my enemies."
speech.DESCRIBE.BK_DECAYZONE = "Death and Decay. Stay out of it."
speech.DESCRIBE.BK_DRW_BLADE = "My other blade. It fights on its own."
speech.DESCRIBE.BONESHARD = "A shard of bone. It will mend my shield when it breaks."

-- examining yourself
speech.DESCRIBE.BLOODKNIGHT =
{
    GENERIC = "Still standing. Still bleeding. Still angry.",
    ATTACKER = "That blade has been in more than one back, %s.",
    MURDERER = "Murderer! I will hold the line against you, %s!",
    REVIVER = "%s drags the living back from the edge.",
    GHOST = "So even I fall. Someone find me a heart.",
    FIRESTARTER = "Careful with the flames, %s. Even bones burn.",
}

return speech
