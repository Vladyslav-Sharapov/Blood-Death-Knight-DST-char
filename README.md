# Blood Knight - a Blood Death Knight for Don't Starve Together

A tank character based on the Blood Death Knight of *World of Warcraft: Midnight, Season 2*.
Version 0.1.0 - Don't Starve Together (API version 10) - every player on the server needs the mod.

> **Status.** Work in progress. The mod loads and plays in the real game; many features added later
> (progression, runeforging, crafting stations, armor tiers, ...) have only been checked for Lua syntax
> and still need a proper playtest. The list at the end ("What is not verified") says what to look at.
> The character still *looks like Wilson* until the animated character is drawn; everything else has
> placeholder art (mostly stock item icons and tinted stock models).

## The character

| | |
|---|---|
| Health / Hunger / Sanity | 150 / 150 / 150 |
| Starts with | Rune Blade (unbreakable sword: plain swings 15 damage, abilities count it as 15; stronger tiers are crafted, see Progression) and 3 Bone Shards |
| Perks | Heals through combat (Death Strike). Takes 20% less damage while the Bone Shield is up. |
| Drawbacks | Hunger drains 1.25x faster. Food restores only 50% of its health. |
| Best at | Tanking bosses and big fights |

### Resources (the bar above your inventory)

* **Runes** - 6, working like World of Warcraft: up to **3 runes recharge at the same time**, each takes 10 seconds
  (configurable, 4-12 s). Spend all 6 and 3 are back after 10 s, all 6 after 20 s.
* **Runic Power** - 0 to 125 (135 with **Ossuary**: 5+ Bone Shield stacks). **Every rune you spend gives +10** (like WoW). Heart Strike adds +5 more (15 in total,
  like WoW), +10 more during Dancing Rune Weapon; Marrowrend gives +20 (2 runes); each spectral blade hit gives +5.
  It fades by 2 per second once you have been out of combat for 6 seconds.
* **Bone Shield** - up to 10 stacks. With 1 or more stacks you take 20% less damage. A hit costs one
  stack (at most one stack per 1.5 seconds). Dodged hits cost nothing.
* **Blood Debt** - each Death Strike adds 1, up to 10; every stack gives +0.5% damage (up to +5%, like WoW). At 10, your next Marrowrend spends them all:
  +10% damage for 10 s, 3 extra Bone Shield stacks and a shadow burst around you.

### Abilities (default keys, all configurable)

| Key | Ability | Cost | Cooldown | What it does |
|---|---|---|---|---|
| Z | Heart Strike | 1 rune | 0.5 s | Hits your target plus 1 more enemy near you (75% damage); while you stand in Death and Decay it hits 5 enemies. Heals 3 health per enemy hit (max 12). Enemies hit move 20% slower for 8 s (like WoW). Builds Runic Power. |
| X | Death Strike | 45 Runic Power (40 with Ossuary) | 2 s | Needs an enemy in reach. Hits your target for 2x; like WoW's **Deadly Reach** talent the 2 closest other enemies (within 3.5) take 60% of that hit. Heals 23% of the damage you took in the last 5 s (WoW: 20% + Improved Death Strike), at least 7% of max health. +1 Blood Debt. **Blood Shield** (WoW's Blood mastery): 50% of the heal becomes a shield that absorbs hits for 10 s (number above the X button). **Hemostasis**: each enemy hit by Blood Boil gives a stack (max 5, shown as x1..x5 on the X button); the next Death Strike deals and heals 8% more per stack. **Coagulopathy**: every Death Strike makes your Blood Plague 10% stronger for 15 s (up to 4 stacks), and enemies with Blood Plague take 5% more damage from you. |
| C | Marrowrend | 2 runes | 0.3 s | Strikes your target for 1.1x (like WoW, a bit harder than Heart Strike) and gives +3 Bone Shield stacks; Bone Shield fades 30 s after you last built it up. Can be cast with nobody in reach. At 10 Blood Debt it also does the big Season 2 effect above. |
| V | Blood Boil | 2 charges (no runes) | 7.5 s per charge | Burst of damage around you (80% of a normal hit). Every enemy hit gets **Blood Plague** (they glow red): 3 damage per second for 24 s, and you heal 1 health per second for each sick enemy (max 4 per second). |
| B | Death and Decay | 1 rune | 2 charges, 30 s each | Like WoW (30 s cooldown) with a 2nd charge. **Crimson Scourge**: every normal swing that hits an enemy with Blood Plague has a 25% chance to give a charge back and make the next Death and Decay free (button glows gold). A big zone (radius 6) on the ground for 10 s. Enemies inside take 8 damage per second; while you stand in it you take 15% less damage and Heart Strike hits 5 enemies. |
| G | Death Grip | free | 15 s | Pulls an enemy in front of you and forces it to attack you for 3 s. Point at it with the mouse; with nothing under the mouse it takes the closest enemy that is attacking a friend (range 14). Bosses are too big to pull, they are only taunted. |
| T | Dark Command | free | 8 s | Taunt: forces an enemy to attack you for 3 s (range 16). Same targeting as Death Grip. |
| H | Vampiric Blood | free | 90 s | 10 s: +30% max health (you get that health right away), +30% healing and Blood Shield received. When it ends your max health goes back and anything above it is lost. |
| J | Raise Dead | free | 2 min | A ghoul fights by your side for 1 minute (one at a time). Placeholder look: Maxwell's Shadow Protector, tinted red and named "Risen Ghoul". |
| R | Dancing Rune Weapon | free | 3 min | Works like WoW. 8 s: a rune weapon **copies every attack and ability you use** (60% damage): normal hits (+5 Runic Power each), Heart Strike (+10 Runic Power), Death Strike (hits harder), Marrowrend, and Blood Boil (a second burst + Blood Plague around the weapon). +30% dodge (WoW's parry). Every Bone Shield stack you lose takes 3 s off the cooldown. When it fades, runes recharge 40% faster for 10 s. |

**Purgatory (passive, like WoW).** A hit that would kill you leaves you at 1 health instead, and you glow purple.
The damage it saved you from becomes a **healing debt**: for 3 s every heal you get pays the debt first (the text
above the Runic Power bar shows how much is left), and more damage during those 3 s cannot kill you, it only adds to the
debt. If the debt is not paid when the 3 s end, you die. Then it cannot trigger again for 4 minutes (the countdown
shows above the bar). Death Strike, Vampiric Blood and Blood Plague are your ways out.

**Stun resistance.** After you are staggered by a hit, knocked back or electrocuted, you cannot be stunned again
for 3 s: hits still deal damage but do not interrupt you (only the hurt sound plays). Sleep and freezing are not
affected.

**Who area abilities hit.** Everything you could attack: monsters, but also neutral creatures (pigs, beefalo,
bunnymen, a spider that has not noticed you). Never other players, anybody's followers, pets, companions or buildings.
When you have no target, Heart Strike / Death Strike pick something that is fighting before a neutral bystander.

**Threat (like a WoW tank).** Every enemy hit by your abilities (Heart Strike, Death Strike, Blood Boil, Death and
Decay, the rune weapon's copies, ...) turns to attack **you**, even if it was attacking a friend. Plain swings and
Blood Plague ticks do not pull aggro. Death Grip and Dark Command also hold the enemy on you for 3 s.

**Dance of Midnight** (WoW's Blood apex talent, all 4 ranks): every dodge during Dancing Rune Weapon has a 25%
chance to make your next Heart Strike free **and deal +150% damage** (kept for 15 s). While a rune weapon is out you
deal 6% more damage and take 6% less. Spending a rune has a 12.5% chance to call an 8-second Dancing Rune Weapon.

You can also click the ability buttons. Hover a button, the Runic Power bar, the shield or the debt
counter to read what it does.

## Install

1. Put this folder into the `mods` folder of the game's install (Steam: right-click Don't Starve Together >
   Manage > Browse local files > `mods`), so that you get `mods/blood-knight/modinfo.lua`.
   * Download: GitHub's **Code > Download ZIP**, then extract it into `mods` (rename the extracted folder to
     `blood-knight` if you like; `modinfo.lua` must be directly inside it, not one folder deeper).
   * Or clone it: `git clone https://github.com/Vladyslav-Sharapov/Blood-Death-Knight-DST-char.git blood-knight`
     from inside the `mods` folder.
2. Start the game, open **Mods**, enable **Blood Knight** (use **Configure Mod** to change keys and options).
3. Create a world and pick the Blood Knight on the character screen.

## Options

*Per player:* the ten ability keys, HUD size (small to huge) and HUD height (move it up if it covers a backpack).
*Per server:* Heart Strike mode (**manual** key, or **auto**: normal attacks become Heart Strikes while you
have 2+ runes), rune recharge time (4-12 s, 3 runes recharge at once), ability damage (50-200%, scales Blood Boil, Death and Decay,
Blood Plague and the spectral blade).

All other balance numbers are in `scripts/bk_tuning.lua`, one commented line each.

## What comes from the cheat sheet, and what is my own design

Everything in the tables above that has a number came from the cheat sheet. The sheet left a few things open,
so I decided them (change them in `scripts/bk_tuning.lua` if you disagree):

* **Bone Shards** are in your starting items, but the sheet did not say what they do. Now: when a hit breaks
  your last Bone Shield stack and you carry a Shard, one Shard is used up automatically and gives 3 stacks back
  (at most once every 8 seconds).
* **Marrowrend** has no cooldown in the sheet. It has a 0.3 s lockout so a key repeat cannot spend two sets of runes.
* The Blood Debt damage bonus applies *before* the shadow burst, so the burst gets the +10% too.
* Damage values the sheet did not give: Heart Strike side targets 75%, Blood Boil 80%, Death and Decay 8 per
  second in a 4-unit radius with 15% damage reduction, spectral blade 60%, shadow burst 100% of a hit.
* Heart Strike auto mode, rune recharge time and the ability-damage option are extras for testing.

## What is not verified (look at these first)

Nothing here could be started in the real game, so these are the places most likely to need a fix:

1. **The character model.** Until `anim/bloodknight.zip` exists, the character uses the stock Wilson model through the
   base skin `bloodknight_none`. That fallback is the standard pattern but untested here.
2. **Heart Strike animation.** It makes the character perform a normal attack through the game's action system. It
   should play the usual swing for the owner and for other players; check that it does.
3. **Effect sizes.** The rings and bursts reuse stock effects (`slingshot_aoe_fx`, `pocketwatch_heal_fx`, ...).
   Their size and colour are estimates. If an effect prefab has been renamed by a game update it is just skipped.
4. **The textures.** They were written by my own PNG-to-`.tex` converter (DXT5, premultiplied alpha, full mip chain),
   checked by reading them back and by comparing the file header with the format description. The game has not loaded them.
5. **Controller.** Abilities are keyboard / mouse only. Gamepad players cannot press them.
6. **Balance.** The numbers are the sheet's plus my guesses; real fights will tell.

### First run checklist

1. The mod loads (no crash on the loading screen) and the character screen shows name, quote, three perks and a portrait.
2. After spawning you have the Rune Blade and 3 Bone Shards in your inventory (equip the blade), and the bar shows 6 runes.
3. Open the console (`~`), `c_spawn("spider")`, press **Z** next to it: a swing, one rune used, Runic Power +15, the rune comes back after 10 s.
4. Get hit, then press **X** (needs 35 Runic Power): health goes up, Blood Debt +1.
5. **C** adds 3 shield stacks. Taking a hit removes one (and a number on the shield counter changes).
6. **V** shows a ring and damages nearby enemies; they glow red and keep losing health for a while while you slowly heal (Blood Plague).
7. **B** puts a ring on the ground; enemies inside lose health once per second.
8. **R** brings a floating red blade that fights next to you; the button glows blue for 12 s.
9. Die, become a ghost, get revived: the bar reappears and starts again from 6 runes.
10. Try the key options in **Configure Mod** (letters only).

If something fails, the log files show why: `client_log.txt` (and for hosted worlds `Cluster_*/Master/server_log.txt`) in the
Klei folder named above. Search for `LUA ERROR` and for lines mentioning `bk_` or `BloodKnight`, and send me those lines.

## File map

```
modinfo.lua                    name, description, configuration screen
modmain.lua                    assets, strings, key/RPC wiring, HUD hook, character registration
scripts/bk_tuning.lua          every balance number (TUNING.BK)
scripts/components/bk_bloodknight.lua   all gameplay rules (server only)
scripts/widgets/bk_hud.lua     rune / ability bar (client only)
scripts/prefabs/               bloodknight (character), bloodknight_none (base skin), bk_runeblade,
                               bk_decayzone, bk_drw_blade
scripts/speech_bloodknight.lua what the character says
images/, bigportraits/, modicon.*   generated placeholder pictures (.tex + .xml)
```

The pictures are made by the scripts in `BloodKnight_ArtPack/tools/`; replacing them is described in the art guide.
Put your own name in the `author` line of `modinfo.lua` before you publish the mod.

## Progression: Rune Blade tiers

The Blood Knight's power is in his weapon. **Abilities only work while you hold a Rune Blade**, they use its
damage, and its tier decides what is unlocked (locked buttons are dark and show the tier they need, "-" with no blade).

| Tier | Blade | Plain / ability damage | Unlocks | Recipe (blade in inventory, not in hand) |
|---|---|---|---|---|
| 1 | Rune Blade (start) | 15 / 15 | Heart Strike, Death Strike, Marrowrend, Blood Boil (+ Blood Plague, Bone Shield, runes, threat) | lost it? 2 twigs, 2 flint, 1 nightmare fuel |
| 2 | Runed Blade | 20 / 25 | Death and Decay, Death Grip, Dark Command; talents Crimson Scourge, Hemostasis | Rune Blade, 3 gold, 4 nightmare fuel, 4 bone shards (Rune Forge) |
| 3 | Bloodforged Blade | 25 / 40 | Vampiric Blood, Raise Dead; talents Blood Shield, Ossuary, Coagulopathy; the Plate and Helm recipes | Runed Blade, 2 red gems, 1 purple gem, 2 living logs, 6 nightmare fuel (Rune Forge) |
| 4 | Runeblade of the Ebon Blade | 30 / 60 | Dancing Rune Weapon, Purgatory; talents Dance of Midnight, Blood Debt | Bloodforged Blade, 6 thulecite, 1 purple gem, 1 Deerclops Eyeball / Thick Fur / Scales (Rune Forge) |

## Crafting stations

Two buildings the Blood Knight crafts (Structures / Character tab). Their recipes only show up in the crafting menu
while you stand next to them.

* **Rune Forge** (3 cut stone, 4 bone shards, 3 nightmare fuel; looks like a red Shadow Forge for now):
  upgrade the Rune Blade (Tier 2-4) and, with a Rune Blade in hand, engrave runes. The Tier 1 replacement blade can
  still be made anywhere.
* **Runic Armor Table** (4 boards, 4 bone shards, 2 nightmare fuel; looks like a Mannequin for now): craft and
  upgrade the Plate and Helm.

## Armor tiers (Runic Armor Table)

Armor tier N needs a Rune Blade one tier higher in your hand. An upgrade is made from the piece below it and keeps its
charge. Plate and Helm use the same numbers.

| Tier | Plate / Helm | Blocks | Charge with no aggro / cap | Blade in hand | Upgrade cost |
|---|---|---|---|---|---|
| 1 | Death Knight Plate / Helm | 50% | 350 / 1000 | Tier 2+ | Plate: 6 bone shards, 4 nightmare fuel, 1 red gem. Helm: 4, 3, 1 |
| 2 | Runed Plate / Helm | 60% | 450 / 1500 | Tier 3+ | old piece + Plate: 6 marble, 2 red gems, 6 fuel. Helm: 4 marble, 1 red gem, 4 fuel |
| 3 | Ebon Plate / Helm | 70% | 550 / 2000 | Tier 4 | old piece + Plate: 6 thulecite, 1 purple gem, 6 fuel. Helm: 4 thulecite, 1 purple gem, 4 fuel |

## Runeforging

Like WoW: engrave **one rune** into the Rune Blade in your hand (any tier), **at a Rune Forge**. A new rune
replaces the old one, the blade's name shows its rune, and upgrading the blade to the next tier keeps it.

| Rune | Effect | Recipe (+2 nightmare fuel) |
|---|---|---|
| Fallen Crusader | Every hit has a 10% chance to heal 4% and give +15% damage for 15 s | 4 gold, 3 light bulbs |
| Stoneskin Gargoyle | 5% less damage taken, 5% more damage | 4 marble, 2 cut stone |
| Sanguination | Death Strike deals up to +50% on wounded targets; dropping below 35% health heals 48% over 8 s (once per 2 min) | 2 mosquito sacks, 1 red gem |
| Unending Thirst | +5% move speed; every kill heals 5% and gives +10% speed and rune recharge for 10 s | 4 batwings, 4 monster meat, 1 red gem (+4 nightmare fuel) |
| Razorice | +4% damage; each hit stacks +3% damage taken from you on the target (max 5, 20 s) | 3 blue gems, 10 ice, 1 walrus tusk (+4 nightmare fuel) |

## Crafting

Both pieces are crafted at the Runic Armor Table (see Armor tiers), only by the Blood Knight, and they **never break**:

* **Death Knight Plate** (body): 6 Bone Shards, 4 Nightmare Fuel, 1 Red Gem. Blocks 60% of damage.
* **Death Knight Helm** (head): 4 Bone Shards, 3 Nightmare Fuel, 1 Red Gem. Blocks 60% of damage.

**Soul charge.** The % on the inventory slot. At 0% the piece stays on but blocks nothing. **It scales with the
fight:** 100% is worth **half** the total max health of every enemy attacking you, at least 150 and at most 1500
(two 100-health spiders: 150; Deerclops: 1500); with nothing attacking you it is 450. Every point of damage blocked
uses 0.4 of that, so a full piece blocks at most 3750 damage (1125 with no aggro). Refill it with **souls**, using Wortox's soul system: when a
creature dies within 20 units of you, its soul (Wortox's flying soul, 1 per creature, 2 for some, 7-8 for bosses)
flies into your inventory. Worn gear eats a soul from your inventory whenever it has room for it: +17% charge each.
Wearing both pieces splits the damage between them. If a Wortox player is near the kill, the souls go to him instead.

The plate and helm use the stock Bone Armor / Bone Helm look until custom art exists.

## License

The code of this mod is under the **MIT License** (see `LICENSE`), Copyright (c) 2026 Vladyslav-Sharapov.

Not affiliated with or endorsed by Blizzard Entertainment or Klei Entertainment. *World of Warcraft* and the names
of its classes and abilities (Death Knight, Heart Strike, Dancing Rune Weapon, the runes, ...) belong to Blizzard
Entertainment; *Don't Starve Together* belongs to Klei Entertainment. This is a free fan mod.
