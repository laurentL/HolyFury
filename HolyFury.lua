-- Holy Fury : alerte bien visible quand la Fureur vertueuse manque ou va expirer.
-- Surveille en donjon/raid quand ta spé active est ta spé tank
-- (Protection = arbre le plus rempli, ou spé choisie avec /hf spe).
-- Les textes sont dans Locales.lua, choisis selon la langue du client.
local ADDON, ns = ...
local L = ns.L

local _, playerClass = UnitClass("player")
if playerClass ~= "PALADIN" then return end

local SPELL_ID = 25780       -- Fureur vertueuse
local WARN_BEFORE = 60       -- avertir quand il reste moins de 60 s
local REPEAT_SOUND = 20      -- répéter le son toutes les 20 s tant qu'elle manque
local FALLBACK_ICON = "Interface\\Icons\\Spell_Holy_SealOfFury"

local DEFAULTS = {
    where = "instance",      -- "instance", "always" ou "off"
    -- tankSpec : nil = détection automatique (arbre Protection le plus rempli),
    -- sinon l'identifiant de la spé choisie avec /hf spe
    sound = true,
    point = { "CENTER", "CENTER", 0, 180 },
}

local db
local seenThisRun = false    -- Fureur vue active depuis l'entrée dans l'instance
local lastKnown, lastExpires = nil, nil
local wasMissing, nextSound = false, 0
local testing, unlocked = false, false

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Usable(v)
    return v ~= nil and not Secret(v)
end

-- Nom et icône du sort : API moderne (C_Spell), sinon anciennes fonctions des clients Classic
local function SpellName()
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(SPELL_ID)
    if not name and GetSpellInfo then name = GetSpellInfo(SPELL_ID) end
    return name or L.SPELL
end

local function SpellIcon()
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(SPELL_ID)
    if not icon and GetSpellTexture then icon = GetSpellTexture(SPELL_ID) end
    return icon or FALLBACK_ICON
end

-- true = active, false = absente, nil = inconnu (données masquées par le jeu)
-- Deuxième valeur : heure d'expiration si elle est lisible
-- (aucune en Cataclysm et Mists : la Fureur y dure jusqu'à annulation).
local function ExpiryOf(exp)
    if Secret(exp) or not exp or exp == 0 then return nil end
    return exp
end

local function FuryStateModern()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(SPELL_ID)
    if aura then return true, ExpiryOf(aura.expirationTime) end
    if not C_UnitAuras.GetAuraDataByIndex then return false end
    for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not a then return false end
        local id = a.spellId
        if Secret(id) then return nil end
        if id == SPELL_ID then return true, ExpiryOf(a.expirationTime) end
    end
    return false
end

-- Anciens clients : UnitBuff renvoie l'expiration en 6e et l'identifiant du sort en 10e
local function FuryStateLegacy()
    local unitBuff = UnitBuff or UnitAura
    if not unitBuff then return nil end
    for i = 1, 40 do
        local name, _, _, _, _, expires, _, _, _, id = unitBuff("player", i, "HELPFUL")
        if not name then return false end
        if id == SPELL_ID then return true, ExpiryOf(expires) end
    end
    return false
end

local function FuryState()
    if C_UnitAuras then return FuryStateModern() end
    return FuryStateLegacy()
end

local function InGroupInstance()
    local inInstance, kind = IsInInstance()
    return inInstance and (kind == "party" or kind == "raid")
end

-- Spé -----------------------------------------------------------------------
-- Arbres de talents du paladin, dans l'ordre du jeu (noms dans L.TREES)
local PROTECTION_TREE = 2

local function ActiveConfigID()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID) then return nil end
    local id = C_ClassTalents.GetActiveConfigID()
    if Usable(id) then return id end
    return nil
end

local function ActiveTalentGroup()
    local getGroup = GetActiveTalentGroup
        or (C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or GetActiveSpecGroup
    if not getGroup then return nil end
    local g = getGroup()
    if Usable(g) then return g end
    return nil
end

-- Identifiant de la spé active (Principale / Secondaire)
local function ActiveSpecKey()
    local config = ActiveConfigID()
    if config then return "config" .. config end
    local g = ActiveTalentGroup()
    if g then return "groupe" .. g end
    return nil
end

-- Forever : points dépensés dans chaque arbre du système de traits
local function TraitTreePoints()
    local configID = ActiveConfigID()
    if not (configID and C_Traits and C_Traits.GetGroupDisplayInfoByTreeID) then return nil end
    local config = C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return nil end
    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
    if not groups or #groups == 0 then return nil end
    local ids = {}
    for i, group in ipairs(groups) do ids[i] = group.groupID end
    local spentBy = {}
    for _, info in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
        local currency = info.currencyInfos and info.currencyInfos[1]
        local spent = currency and currency.spent
        spentBy[info.traitNodeGroupID] = Usable(spent) and spent or 0
    end
    local points = {}
    for i, group in ipairs(groups) do points[i] = spentBy[group.groupID] or 0 end
    return points
end

-- Classic, TBC, Wrath, Cataclysm : onglets de talents classiques.
-- Selon le client, les points sont en 5e valeur (format récent) ou en 3e (ancien format).
local function TabPoints()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
    local tabs = GetNumTalentTabs()
    if not tabs or tabs == 0 then return nil end
    local group = ActiveTalentGroup()
    local points = {}
    for tab = 1, tabs do
        local r = { GetTalentTabInfo(tab, false, false, group) }
        local spent = (type(r[5]) == "number" and r[5]) or (type(r[3]) == "number" and r[3]) or 0
        points[tab] = spent
    end
    return points
end

local function ReadTreePoints()
    return TraitTreePoints() or TabPoints()
end

local function TreePoints()
    local ok, points = pcall(ReadTreePoints)
    if ok then return points end
    return nil
end

-- Mists et versions avec spécialisations : rôle annoncé par le jeu
local function SpecRole()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not (getSpec and getInfo) then return nil end
    local ok, role = pcall(function()
        local s = getSpec()
        if not Usable(s) or s == 0 then return nil end
        return select(5, getInfo(s))
    end)
    if ok and Usable(role) then return role end
    return nil
end

-- Spé tank détectée automatiquement, relue au plus toutes les 5 s ou quand les talents changent.
-- Les points de talents passent avant le rôle : sur Forever, le rôle annoncé est faux.
local autoTank, autoTankAt = nil, nil
local function InvalidateSpec()
    autoTankAt = nil
end

local function AutoTank()
    local now = GetTime()
    if autoTankAt and now - autoTankAt < 5 then return autoTank end
    autoTankAt = now
    autoTank = nil
    local points = TreePoints()
    if points then
        local best, most = nil, 0
        for i, spent in ipairs(points) do
            if spent > most then best, most = i, spent end
        end
        if best then autoTank = (best == PROTECTION_TREE) return autoTank end
    end
    local role = SpecRole()
    if role == "TANK" then autoTank = true
    elseif role == "HEALER" or role == "DAMAGER" then autoTank = false end
    return autoTank
end

-- true / false, ou nil si on ne peut pas savoir
local function IsTankSpec()
    if db.tankSpec then
        local key = ActiveSpecKey()
        if key then return key == db.tankSpec end
        return nil
    end
    return AutoTank()
end

local function Watching()
    if db.where == "off" then return false end
    if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return false end
    if IsPlayerSpell and not IsPlayerSpell(SPELL_ID) then return false end
    if db.where == "instance" and not InGroupInstance() then return false end
    local tank = IsTankSpec()
    if tank == nil then tank = seenThisRun end   -- spé illisible : on se fie à la Fureur déjà lancée
    return tank
end

-- Affichage -----------------------------------------------------------------

local f = CreateFrame("Frame", "HolyFuryFrame", UIParent)
f:SetSize(64, 64)
f:SetFrameStrata("HIGH")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(false)
f:RegisterForDrag("LeftButton")
f:Hide()

f.glow = f:CreateTexture(nil, "BACKGROUND")
f.glow:SetPoint("TOPLEFT", -4, 4)
f.glow:SetPoint("BOTTOMRIGHT", 4, -4)

f.icon = f:CreateTexture(nil, "ARTWORK")
f.icon:SetAllPoints()
f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
f.text:SetPoint("TOP", f, "BOTTOM", 0, -8)

f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.hint:SetPoint("TOP", f.text, "BOTTOM", 0, -4)
f.hint:SetText(string.format(L.DRAG_HINT, L.SLASH .. " " .. L.CMD.move))
f.hint:Hide()

f.anim = f:CreateAnimationGroup()
f.anim:SetLooping("BOUNCE")
local fade = f.anim:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.3)
fade:SetDuration(0.45)

f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    db.point = { point, relPoint, x, y }
end)

local function PlacePosition()
    local p = db.point
    f:ClearAllPoints()
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function ShowAlert(mode, left)
    f.icon:SetTexture(SpellIcon())
    if mode == "missing" then
        f.glow:SetColorTexture(1, 0, 0, 0.9)
        f.text:SetText("|cffff2020" .. string.format(L.MISSING, string.upper(SpellName())) .. "|r")
        if not f.anim:IsPlaying() then f.anim:Play() end
    else
        f.glow:SetColorTexture(1, 0.8, 0, 0.9)
        f.text:SetText("|cffffd100" .. string.format(L.COUNTDOWN, SpellName(), math.max(0, math.ceil(left))) .. "|r")
        f.anim:Stop()
        f:SetAlpha(1)
    end
    f:Show()
end

local function HideAlert()
    f.anim:Stop()
    f:SetAlpha(1)
    f:Hide()
end

local function Alarm(now)
    if not db.sound then return end
    PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    nextSound = now + REPEAT_SOUND
end

-- Boucle --------------------------------------------------------------------

local function Update()
    if not db then return end
    if testing or unlocked then
        ShowAlert("missing")
        return
    end

    local now = GetTime()
    local state, expires = FuryState()
    if state == nil then
        -- Données masquées (combat) : on garde le dernier état connu
        -- et on se fie à l'heure d'expiration lue auparavant.
        state = lastKnown
        if state and lastExpires and now >= lastExpires then state = false end
    else
        lastKnown = state
        if state then
            if expires then
                lastExpires = expires
            elseif lastExpires and lastExpires <= now then
                lastExpires = nil
            end
        else
            lastExpires = nil
        end
    end
    if state then seenThisRun = true end

    if not Watching() then
        HideAlert()
        wasMissing = false
        return
    end

    if state == false then
        ShowAlert("missing")
        if not wasMissing then
            Alarm(now)
            if RaidNotice_AddMessage and RaidWarningFrame then
                RaidNotice_AddMessage(RaidWarningFrame, string.format(L.EXPIRED, SpellName()), ChatTypeInfo["RAID_WARNING"])
            end
        elseif now >= nextSound then
            Alarm(now)
        end
        wasMissing = true
    elseif state and lastExpires and lastExpires - now <= WARN_BEFORE then
        ShowAlert("expiring", lastExpires - now)
        wasMissing = false
    else
        HideAlert()
        wasMissing = false
    end
end

-- Événements ----------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
local SPEC_EVENTS = {
    ACTIVE_TALENT_GROUP_CHANGED = true, PLAYER_SPECIALIZATION_CHANGED = true,
    ACTIVE_COMBAT_CONFIG_CHANGED = true, TRAIT_CONFIG_UPDATED = true, PLAYER_TALENT_UPDATE = true,
    CHARACTER_POINTS_CHANGED = true,
}
for name in pairs(SPEC_EVENTS) do
    pcall(events.RegisterEvent, events, name)
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        HolyFuryDB = HolyFuryDB or {}
        db = HolyFuryDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        PlacePosition()
    elseif event == "PLAYER_LOGIN" then
        C_Timer.NewTicker(0.25, Update)
    elseif event == "PLAYER_ENTERING_WORLD" then
        InvalidateSpec()
        if not InGroupInstance() then seenThisRun = false end
    elseif SPEC_EVENTS[event] then
        InvalidateSpec()
        if event ~= "TRAIT_CONFIG_UPDATED" and event ~= "PLAYER_TALENT_UPDATE" and event ~= "CHARACTER_POINTS_CHANGED" then
            seenThisRun = false
        end
    end
end)

-- Commandes -----------------------------------------------------------------

local function Say(msg)
    print("|cff0091ed" .. L.TITLE .. "|r" .. L.SEP .. msg)
end

-- Commande complète dans la langue du client, par exemple "/hf deplacer"
local function Cmd(...)
    local words = { L.SLASH }
    for i = 1, select("#", ...) do words[#words + 1] = L.CMD[select(i, ...)] end
    return table.concat(words, " ")
end

local function Help(command, text)
    print("  " .. command .. L.SEP .. text)
end

local function SetWhere(where)
    db.where = where
    local msg = L["SET_" .. where]
    if where == "off" then msg = msg .. string.format(L.REENABLE, Cmd("dungeon")) end
    Say(msg)
end

SLASH_HOLYFURY1 = "/hf"
SLASH_HOLYFURY2 = "/holyfury"
SLASH_HOLYFURY3 = "/fv"      -- ancien raccourci, gardé
SLASH_HOLYFURY4 = "/rfury"
SlashCmdList.HOLYFURY = function(msg)
    if not db then return end
    local word, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local cmd = ns.CMD_ALIASES[string.lower(word or "")]
    if cmd == "test" then
        testing = not testing
        if testing then Alarm(GetTime()) end
        Say(testing and string.format(L.TEST_ON, Cmd("test")) or L.TEST_OFF)
    elseif cmd == "move" then
        unlocked = not unlocked
        f:EnableMouse(unlocked)
        f.hint:SetShown(unlocked)
        Say(unlocked and string.format(L.MOVE_ON, Cmd("move")) or L.MOVE_OFF)
    elseif cmd == "dungeon" then
        SetWhere("instance")
    elseif cmd == "always" then
        SetWhere("always")
    elseif cmd == "off" then
        SetWhere("off")
    elseif cmd == "sound" then
        db.sound = not db.sound
        Say(db.sound and L.SOUND_ON or L.SOUND_OFF)
    elseif cmd == "spec" then
        local protection = L.TREES[PROTECTION_TREE]
        if ns.CMD_ALIASES[string.lower(rest)] == "auto" then
            db.tankSpec = nil
            Say(string.format(L.SPEC_AUTO, protection))
        else
            local key = ActiveSpecKey()
            if key then
                db.tankSpec = key
                Say(string.format(L.SPEC_SET, key))
            else
                Say(L.SPEC_FAIL)
            end
        end
    else
        InvalidateSpec()
        local tank = IsTankSpec()
        local tankText = (tank == true and L.YES) or (tank == false and L.NO) or L.UNKNOWN
        local protection = L.TREES[PROTECTION_TREE]
        local mode = db.tankSpec and string.format(L.MODE_MANUAL, Cmd("spec"), db.tankSpec)
            or string.format(L.MODE_AUTO, protection)
        local points = TreePoints()
        local pointsText = L.UNREADABLE
        if not points and SpecRole() then pointsText = SpecRole() end
        if points then
            local parts = {}
            for i, spent in ipairs(points) do
                parts[i] = (L.TREES[i] or string.format(L.TREE_N, i)) .. " " .. spent
            end
            pointsText = table.concat(parts, ", ")
        end
        Say((L["SET_" .. db.where] or db.where) .. ", " .. (db.sound and L.SOUND_ON or L.SOUND_OFF))
        print("  " .. string.format(L.SPEC_LINE, mode, tankText))
        print("  " .. string.format(L.TALENTS_LINE, pointsText, tostring(ActiveSpecKey())))
        Help(Cmd("test"), L.HELP_TEST)
        Help(Cmd("move"), L.HELP_MOVE)
        Help(L.SLASH .. " " .. L.CMD.dungeon .. " | " .. L.CMD.always .. " | " .. L.CMD.off, L.HELP_WHERE)
        Help(Cmd("sound"), L.HELP_SOUND)
        Help(Cmd("spec"), string.format(L.HELP_SPEC, Cmd("spec", "auto")))
    end
end
