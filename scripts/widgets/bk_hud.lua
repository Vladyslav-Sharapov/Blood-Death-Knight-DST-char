--------------------------------------------------------------------------
-- Blood Knight HUD
--
-- Shows the six runes, Runic Power, Bone Shield, Blood Debt and the nine
-- ability buttons (with cooldown shading and "ready / proc" glows).
--
-- The widget does no game logic. It only
--   * reads the net variables the server component publishes
--     (player._bk_runes, _bk_rp, _bk_cd1.._bk_cd6, ...), and
--   * sends the "Cast" RPC when a key is pressed or a button is clicked.
--
-- All pictures come from one atlas: images/bk_hud.xml (see ART_GUIDE.md).
--------------------------------------------------------------------------

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local Text = require "widgets/text"

local ATLAS = "images/bk_hud.xml"

-- ability ids, same as in the server component and the RPC
local NUM_ABILITIES = 10
local ICONS = { "ico_hs.tex", "ico_ds.tex", "ico_mr.tex", "ico_bb.tex", "ico_dd.tex", "ico_drw.tex" }
-- Death Grip, Dark Command, Vampiric Blood and Raise Dead have no drawn icon
-- yet: they borrow stock item icons (whip, nightmare fuel, telltale heart,
-- shadow heart).
local STOCK_ICONS = { [7] = "whip.tex", [8] = "nightmarefuel.tex", [9] = "reviver.tex", [10] = "shadowheart.tex" }
local GRIP, COMMAND = 7, 8 -- these two send the entity under the mouse
-- colour of the glow behind a slot when it has something to say
local GLOWS =
{
    [1] = { 1.00, 0.82, 0.30 },     -- free Heart Strike
    [3] = { 1.00, 0.22, 0.22 },     -- Marrowrend would consume the Blood Debt
    [5] = { 0.55, 0.95, 0.40 },     -- standing in Death and Decay
    [6] = { 0.45, 0.80, 1.00 },     -- Dancing Rune Weapon is out
    [9] = { 1.00, 0.25, 0.30 },     -- Vampiric Blood is up
}

-- bit flags published in player._bk_flags (same values as the component)
local FLAG_DRW, FLAG_FREEHS, FLAG_DEBT, FLAG_DECAY, FLAG_OSSUARY, FLAG_VB, FLAG_PURG, FLAG_CRIMSON = 1, 2, 4, 8, 16, 32, 64, 128
local CRIMSON_GLOW = { 1.00, 0.82, 0.30 } -- Death and Decay is free (Crimson Scourge)

-- layout (pixels, before the user's HUD scale)
local SLOT_SIZE = 64
local SLOT_INNER = 56           -- area of a slot the cooldown shade covers
local SLOT_SPACING = 70
local RUNE_SPACING = 34
local BAR_WIDTH = 224
local BAR_HEIGHT = 14
local BAR_Y = 64
local RUNE_Y = 40
local SIDE_X = NUM_ABILITIES / 2 * SLOT_SPACING + 36 -- Bone Shield / Blood Debt, outside the buttons

local function HasFlag(flags, bit)
    return math.floor(flags / bit) % 2 == 1
end

local function KeyName(key)
    if type(key) == "number" and key >= 97 and key <= 122 then
        return string.upper(string.char(key))
    end
    return "?"
end

local function FormatSeconds(t)
    if t >= 3 then
        return tostring(math.ceil(t))
    end
    return string.format("%.1f", t)
end

--------------------------------------------------------------------------

local BKHud = Class(Widget, function(self, owner, cfg)
    Widget._ctor(self, "BKHud")
    self.owner = owner
    self.cfg = cfg or {}

    local BK = TUNING.BK
    local UI = STRINGS.BK_UI
    local keys = self.cfg.keys or {}

    -- this widget stays "shown" so it keeps updating, `root` is what we hide
    self.root = self:AddChild(Widget("bk_root"))
    self:SetPosition(0, self.cfg.y or 135)
    self:SetScale(self.cfg.scale or 1)

    local root = self.root

    ------------------------------------------------------------------
    -- Ability buttons
    ------------------------------------------------------------------
    self.slots = {}
    for i = 1, NUM_ABILITIES do
        local s = {}
        s.root = root:AddChild(Widget("bk_slot" .. i))
        s.root:SetPosition((i - (NUM_ABILITIES + 1) / 2) * SLOT_SPACING, 0)

        s.glow = s.root:AddChild(Image(ATLAS, "glow.tex"))
        s.glow:SetClickable(false)
        s.glow:Hide()

        s.btn = s.root:AddChild(ImageButton(ATLAS, "slot.tex", "slot_hover.tex", "slot.tex", "slot_hover.tex", nil, { 1, 1 }, { 0, 0 }))
        s.btn.scale_on_focus = false
        s.btn.clickoffset = Vector3(0, -2, 0)
        s.btn:SetOnClick(function() self:TryCast(i) end)
        local tip = string.format("%s  [%s]\n%s", UI.ABILITY[i], KeyName(keys[i]), UI.TIP[i])
        local need = BK.ABILITY_TIER[i]
        tip = tip .. "\nNeeds a " .. STRINGS.BK_TIER_NAMES[need] .. " (tier " .. need .. ") in hand."
        s.btn:SetTooltip(tip)

        if STOCK_ICONS[i] ~= nil then
            s.icon = s.btn:AddChild(Image(GetInventoryItemAtlas(STOCK_ICONS[i]), STOCK_ICONS[i]))
            s.icon:SetScale(0.8)
        else
            s.icon = s.btn:AddChild(Image(ATLAS, ICONS[i]))
        end
        s.icon:SetClickable(false)

        -- cooldown shade: grows from the bottom edge, so its height is the
        -- time left
        s.shade = s.btn:AddChild(Image(ATLAS, "white.tex"))
        s.shade:SetClickable(false)
        s.shade:SetTint(0, 0, 0, 0.62)
        s.shade:SetVRegPoint(ANCHOR_BOTTOM)
        s.shade:SetPosition(0, -SLOT_INNER / 2)
        s.shade:SetSize(SLOT_INNER, SLOT_INNER)
        s.shade:Hide()

        s.cdtext = s.root:AddChild(Text(NEWFONT_OUTLINE, 28, ""))
        s.cdtext:SetClickable(false)
        s.cdtext:Hide()

        s.key = s.root:AddChild(Text(NEWFONT_OUTLINE, 18, KeyName(keys[i])))
        s.key:SetPosition(-SLOT_SIZE / 2 + 10, SLOT_SIZE / 2 - 11)
        s.key:SetColour(1, 0.93, 0.70, 1)
        s.key:SetClickable(false)

        self.slots[i] = s
    end

    -- Purgatory: above the Runic Power bar while it is active or on cooldown
    self.purgtext = root:AddChild(Text(NEWFONT_OUTLINE, 22, ""))
    self.purgtext:SetPosition(0, BAR_Y + 24)
    self.purgtext:SetClickable(false)
    self.purgtext:Hide()

    -- Death Strike: Hemostasis stacks (bottom-right) and Blood Shield left (above)
    self.hemotext = self.slots[2].root:AddChild(Text(NEWFONT_OUTLINE, 22, ""))
    self.hemotext:SetPosition(SLOT_SIZE / 2 - 10, -SLOT_SIZE / 2 + 11)
    self.hemotext:SetColour(1, 0.55, 0.55, 1)
    self.hemotext:SetClickable(false)

    self.bstext = self.slots[2].root:AddChild(Text(NEWFONT_OUTLINE, 24, ""))
    self.bstext:SetPosition(0, SLOT_SIZE / 2 + 14)
    self.bstext:SetColour(1, 0.82, 0.35, 1)
    self.bstext:SetClickable(false)
    self.bstext:Hide()

    -- Blood Boil charges left, in the bottom-right corner of its button
    -- Death and Decay charges, same corner of its button
    self.ddtext = self.slots[5].root:AddChild(Text(NEWFONT_OUTLINE, 22, ""))
    self.ddtext:SetPosition(SLOT_SIZE / 2 - 10, -SLOT_SIZE / 2 + 11)
    self.ddtext:SetColour(0.7, 1, 0.6, 1)
    self.ddtext:SetClickable(false)

    self.bbtext = self.slots[4].root:AddChild(Text(NEWFONT_OUTLINE, 22, ""))
    self.bbtext:SetPosition(SLOT_SIZE / 2 - 10, -SLOT_SIZE / 2 + 11)
    self.bbtext:SetColour(1, 0.55, 0.55, 1)
    self.bbtext:SetClickable(false)

    -- seconds left of Dancing Rune Weapon, above its button
    self.drwtext = self.slots[6].root:AddChild(Text(NEWFONT_OUTLINE, 24, ""))
    self.drwtext:SetPosition(0, SLOT_SIZE / 2 + 14)
    self.drwtext:SetColour(0.55, 0.85, 1, 1)
    self.drwtext:SetClickable(false)
    self.drwtext:Hide()

    ------------------------------------------------------------------
    -- Runes
    ------------------------------------------------------------------
    self.runes = {}
    for r = 1, BK.RUNES_MAX do
        local item = {}
        item.root = root:AddChild(Widget("bk_rune" .. r))
        item.root:SetPosition((r - (BK.RUNES_MAX + 1) / 2) * RUNE_SPACING, RUNE_Y)
        item.off = item.root:AddChild(Image(ATLAS, "rune_off.tex"))
        item.off:SetClickable(false)
        item.on = item.root:AddChild(Image(ATLAS, "rune_on.tex"))
        item.on:SetClickable(false)
        item.on:Hide()
        self.runes[r] = item
    end

    ------------------------------------------------------------------
    -- Runic Power bar (hover for an explanation)
    ------------------------------------------------------------------
    self.rpback = root:AddChild(ImageButton(ATLAS, "rp_back.tex", "rp_back.tex", "rp_back.tex", "rp_back.tex", nil, { 1, 1 }, { 0, 0 }))
    self.rpback.scale_on_focus = false
    self.rpback.clickoffset = Vector3(0, 0, 0)
    self.rpback.stopclicksound = true
    self.rpback:SetPosition(0, BAR_Y)
    self.rpback:SetTooltip(UI.TIP_RP)

    self.rpfill = self.rpback:AddChild(Image(ATLAS, "rp_fill.tex"))
    self.rpfill:SetClickable(false)
    self.rpfill:SetHRegPoint(ANCHOR_LEFT)
    self.rpfill:SetPosition(-BAR_WIDTH / 2, 0)
    self.rpfill:SetSize(1, BAR_HEIGHT)

    -- the line where Death Strike becomes affordable
    self.rpmark = self.rpback:AddChild(Image(ATLAS, "white.tex"))
    self.rpmark:SetClickable(false)
    self.rpmark:SetTint(1, 1, 1, 0.55)
    self.rpmark:SetSize(2, BAR_HEIGHT + 4)
    self.rpmark:SetPosition(-BAR_WIDTH / 2 + BAR_WIDTH * BK.RP_COST[2] / BK.RP_MAX, 0)

    self.rptext = self.rpback:AddChild(Text(NEWFONT_OUTLINE, 18, "0"))
    self.rptext:SetClickable(false)

    ------------------------------------------------------------------
    -- Bone Shield (left) and Blood Debt (right)
    ------------------------------------------------------------------
    self.shield = root:AddChild(ImageButton(ATLAS, "shield.tex", "shield.tex", "shield.tex", "shield.tex", nil, { 1, 1 }, { 0, 0 }))
    self.shield.scale_on_focus = false
    self.shield.clickoffset = Vector3(0, 0, 0)
    self.shield.stopclicksound = true
    self.shield:SetPosition(-SIDE_X, 0)
    self.shield:SetTooltip(UI.TIP_SHIELD .. "\n\n" .. UI.TIP_PURGATORY)
    self.shieldtext = self.shield:AddChild(Text(NEWFONT_OUTLINE, 30, "0"))
    self.shieldtext:SetClickable(false)

    self.debt = root:AddChild(ImageButton(ATLAS, "debt.tex", "debt.tex", "debt.tex", "debt.tex", nil, { 1, 1 }, { 0, 0 }))
    self.debt.scale_on_focus = false
    self.debt.clickoffset = Vector3(0, 0, 0)
    self.debt.stopclicksound = true
    self.debt:SetPosition(SIDE_X, 0)
    self.debt:SetTooltip(UI.TIP_DEBT)
    self.debttext = self.debt:AddChild(Text(NEWFONT_OUTLINE, 30, "0"))
    self.debttext:SetClickable(false)

    ------------------------------------------------------------------
    -- State used by the update
    ------------------------------------------------------------------
    self.cd_seen = {}       -- last value of each cast counter
    self.cd_end = {}        -- local GetTime() when each cooldown ends
    for i = 1, NUM_ABILITIES do
        self.cd_end[i] = 0
    end
    self.drwlen_seen = nil
    self.drw_end = 0
    self.next_send = {}
    self.ghost = nil
    self.shown_text = {}

    ------------------------------------------------------------------
    -- Key bindings
    ------------------------------------------------------------------
    self.key_handlers = {}
    for i = 1, NUM_ABILITIES do
        local key = keys[i]
        if type(key) == "number" and key > 0 then
            table.insert(self.key_handlers, TheInput:AddKeyDownHandler(key, function() self:OnKey(i) end))
        end
    end

    self:StartUpdating()
end)

--------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------

function BKHud:TryCast(id)
    local player = self.owner
    if player == nil or not player:IsValid() or player ~= ThePlayer or player:HasTag("playerghost") then
        return
    end
    local now = GetTime()
    if now < (self.next_send[id] or 0) then
        return
    end
    self.next_send[id] = now + 0.08
    local target = nil
    if id == GRIP or id == COMMAND then
        -- point at an enemy with the mouse to choose who to grip / taunt
        local ent = TheInput:GetWorldEntityUnderMouse()
        if ent ~= nil and ent ~= player and ent.replica.combat ~= nil then
            target = ent
        end
    end
    SendModRPCToServer(GetModRPC("BloodKnight", "Cast"), id, target)
end

function BKHud:OnKey(id)
    local player = self.owner
    -- chat, console, menus, open inventory... all of those own the keyboard
    if player == nil or not player:IsValid() or player.HUD == nil or player.HUD:HasInputFocus() then
        return
    end
    self:TryCast(id)
end

function BKHud:Kill()
    for _, handler in ipairs(self.key_handlers) do
        TheInput.onkeydown:RemoveHandler(handler)
    end
    self.key_handlers = {}
    BKHud._base.Kill(self)
end

--------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------

local function SetTextOnce(self, name, widget, str)
    if self.shown_text[name] ~= str then
        self.shown_text[name] = str
        widget:SetString(str)
    end
end

function BKHud:OnUpdate(dt)
    local player = self.owner
    if player == nil or not player:IsValid() or player._bk_runes == nil then
        return
    end

    -- ghosts have no runes: hide everything
    local ghost = player:HasTag("playerghost")
    if ghost ~= self.ghost then
        self.ghost = ghost
        if ghost then
            self.root:Hide()
        else
            self.root:Show()
        end
    end
    if ghost then
        return
    end

    local BK = TUNING.BK
    local now = GetTime()

    local runes = player._bk_runes:value()
    -- progress of the runes recharging at the same time (1st, 2nd, 3rd)
    local progs =
    {
        player._bk_runeprog:value(),
        player._bk_runeprog2 ~= nil and player._bk_runeprog2:value() or 0,
        player._bk_runeprog3 ~= nil and player._bk_runeprog3:value() or 0,
    }
    local rp = player._bk_rp:value()
    local shield = player._bk_shield:value()
    local debt = player._bk_debt:value()
    local flags = player._bk_flags:value()
    local free_hs = HasFlag(flags, FLAG_FREEHS)
    local drw_on = HasFlag(flags, FLAG_DRW)
    local debt_buff = HasFlag(flags, FLAG_DEBT)
    local in_decay = HasFlag(flags, FLAG_DECAY)
    -- Ossuary (5+ Bone Shield): bigger Runic Power bar, cheaper Death Strike
    local ossuary = HasFlag(flags, FLAG_OSSUARY)
    local rp_max = BK.RP_MAX + (ossuary and BK.OSSUARY_RP_BONUS or 0)
    local ds_cost = BK.RP_COST[2] - (ossuary and BK.OSSUARY_COST_CUT or 0)
    local bb_charges = player._bk_bbcharges ~= nil and player._bk_bbcharges:value() or 0
    local bb_prog = player._bk_bbprog ~= nil and player._bk_bbprog:value() or 0
    local dd_charges = player._bk_ddcharges ~= nil and player._bk_ddcharges:value() or 0
    local dd_prog = player._bk_ddprog ~= nil and player._bk_ddprog:value() or 0
    local crimson = HasFlag(flags, FLAG_CRIMSON)
    local tier = player._bk_tier ~= nil and player._bk_tier:value() or 0 -- Rune Blade in hand (0 = none)

    -- cooldowns: every time a cast counter changes, that ability just went
    -- on cooldown. (The first look only learns the counters, so joining a
    -- game never shows a fake cooldown.)
    for i = 1, NUM_ABILITIES do
        local counter = player["_bk_cd" .. i]
        if counter ~= nil then
            local v = counter:value()
            if self.cd_seen[i] == nil then
                self.cd_seen[i] = v
            elseif v ~= self.cd_seen[i] then
                self.cd_seen[i] = v
                self.cd_end[i] = now + BK.COOLDOWN[i]
            end
        end
    end

    -- Dancing Rune Weapon cooldown: the server sends the seconds left,
    -- because losing Bone Shield stacks makes it shorter
    if player._bk_drwcd ~= nil then
        local left = player._bk_drwcd:value()
        if left ~= self.drwcd_seen then
            self.drwcd_seen = left
            self.cd_end[6] = now + left
        end
    end

    -- Dancing Rune Weapon length (also changes when a shorter proc turns
    -- into the real thing)
    local drwlen = player._bk_drwlen:value()
    if drwlen ~= self.drwlen_seen then
        self.drwlen_seen = drwlen
        self.drw_end = drwlen > 0 and (now + drwlen * 0.1) or 0
    end

    local pulse = 0.55 + 0.35 * math.sin(now * 6)

    -- ability slots -------------------------------------------------------
    local glowing =
    {
        [1] = free_hs,
        [3] = debt >= BK.DEBT_MAX,
        [5] = in_decay or crimson,
        [6] = drw_on,
        [9] = HasFlag(flags, FLAG_VB),
    }
    for i = 1, NUM_ABILITIES do
        local s = self.slots[i]

        local runes_needed = BK.RUNE_COST[i]
        if i == 1 and free_hs then
            runes_needed = 0
        end
        local usable = runes >= runes_needed and rp >= (i == 2 and ds_cost or BK.RP_COST[i])
        if i == 4 then
            usable = bb_charges > 0 -- Blood Boil spends charges, not runes
        elseif i == 5 then
            usable = dd_charges > 0 and (crimson or runes >= runes_needed) -- charges + a rune (free with Crimson Scourge)
        end
        local locked = tier < BK.ABILITY_TIER[i]
        local c = (locked and 0.18) or (usable and 1) or 0.42
        s.icon:SetTint(c, c, c, 1)

        local remaining = self.cd_end[i] - now
        if locked then
            -- progression: show which blade tier this button needs
            s.shade:Hide()
            s.cdtext:Show()
            SetTextOnce(self, "cd" .. i, s.cdtext, tier == 0 and "-" or ("T" .. BK.ABILITY_TIER[i]))
        elseif remaining > 0.02 then
            local total = BK.COOLDOWN[i]
            s.shade:Show()
            s.shade:SetSize(SLOT_INNER, SLOT_INNER * math.min(1, remaining / total))
            if total >= 1.5 then
                s.cdtext:Show()
                SetTextOnce(self, "cd" .. i, s.cdtext, FormatSeconds(remaining))
            else
                s.cdtext:Hide()
            end
        elseif (i == 4 and bb_charges == 0) or (i == 5 and dd_charges == 0) then
            -- out of charges: the shade shows the next charge filling up
            local prog = i == 4 and bb_prog or dd_prog
            s.shade:Show()
            s.shade:SetSize(SLOT_INNER, SLOT_INNER * math.max(0.02, 1 - prog / 100))
            s.cdtext:Hide()
        else
            s.shade:Hide()
            s.cdtext:Hide()
        end

        local g = GLOWS[i]
        if i == 5 and crimson then
            g = CRIMSON_GLOW
        end
        if g ~= nil and glowing[i] then
            s.glow:Show()
            s.glow:SetTint(g[1], g[2], g[3], pulse)
        else
            s.glow:Hide()
        end
    end

    SetTextOnce(self, "bb", self.bbtext, tostring(bb_charges))
    SetTextOnce(self, "dd", self.ddtext, tostring(dd_charges))

    local hemo = player._bk_hemo ~= nil and player._bk_hemo:value() or 0
    SetTextOnce(self, "hemo", self.hemotext, hemo > 0 and ("x" .. hemo) or "")
    local bshield = player._bk_bloodshield ~= nil and player._bk_bloodshield:value() or 0
    if bshield > 0 then
        self.bstext:Show()
        SetTextOnce(self, "bshield", self.bstext, tostring(bshield))
    else
        self.bstext:Hide()
    end

    -- Purgatory
    local purg_debt = player._bk_purg ~= nil and player._bk_purg:value() or 0
    local purg_cd = player._bk_purgcd ~= nil and player._bk_purgcd:value() or 0
    if HasFlag(flags, FLAG_PURG) then
        self.purgtext:Show()
        self.purgtext:SetColour(0.85, 0.45, 1, 0.6 + 0.4 * pulse)
        SetTextOnce(self, "purg", self.purgtext, "PURGATORY - heal " .. purg_debt .. " or die!")
    elseif purg_cd > 0 then
        self.purgtext:Show()
        self.purgtext:SetColour(0.6, 0.55, 0.65, 0.8)
        SetTextOnce(self, "purg", self.purgtext, string.format("Purgatory %d:%02d", math.floor(purg_cd / 60), purg_cd % 60))
    else
        self.purgtext:Hide()
    end

    -- Dancing Rune Weapon countdown
    if drw_on and self.drw_end > now then
        self.drwtext:Show()
        SetTextOnce(self, "drw", self.drwtext, tostring(math.ceil(self.drw_end - now)))
    else
        self.drwtext:Hide()
    end

    -- runes ---------------------------------------------------------------
    for r = 1, BK.RUNES_MAX do
        local on = self.runes[r].on
        if r <= runes then
            on:Show()
            on:SetTint(1, 1, 1, 1)
        elseif r - runes <= #progs and progs[r - runes] > 0 then
            -- one of the runes recharging right now: fades in as it fills
            local prog = progs[r - runes]
            on:Show()
            on:SetTint(1, 1, 1, 0.12 + 0.55 * prog / 100)
        else
            on:Hide()
        end
    end

    -- Runic Power ---------------------------------------------------------
    local frac = math.max(0, math.min(1, rp / rp_max))
    self.rpmark:SetPosition(-BAR_WIDTH / 2 + BAR_WIDTH * ds_cost / rp_max, 0)
    self.rpfill:SetSize(math.max(1, BAR_WIDTH * frac), BAR_HEIGHT)
    if rp >= ds_cost then
        self.rpfill:SetTint(1, 1, 1, 1)             -- Death Strike is affordable: full colour
    else
        self.rpfill:SetTint(0.62, 0.5, 0.55, 1)     -- not yet: muted
    end
    SetTextOnce(self, "rp", self.rptext, tostring(rp))

    -- Bone Shield / Blood Debt -------------------------------------------------
    SetTextOnce(self, "shield", self.shieldtext, tostring(shield))
    if shield > 0 then
        self.shield.image:SetTint(1, 1, 1, 1)
    else
        self.shield.image:SetTint(0.45, 0.45, 0.45, 0.8)
    end

    SetTextOnce(self, "debt", self.debttext, tostring(debt))
    if debt_buff then
        self.debt.image:SetTint(1, 0.75 + 0.25 * pulse, 0.55, 1)
    elseif debt > 0 then
        self.debt.image:SetTint(1, 1, 1, 1)
    else
        self.debt.image:SetTint(0.45, 0.45, 0.45, 0.8)
    end
    if debt >= BK.DEBT_MAX then
        self.debttext:SetColour(1, 0.85, 0.3, 1)
    else
        self.debttext:SetColour(1, 1, 1, 1)
    end
end

return BKHud
