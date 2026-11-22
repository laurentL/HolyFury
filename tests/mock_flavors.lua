-- Simule les API de chaque version de WoW pour Holy Fury.
local flavor, localesFile, mainFile = arg[1], arg[2], arg[3]
local now, inst = 100, true
local fury = nil            -- nil = absente, sinon heure d'expiration (0 = permanente)
local spec = "tank"         -- "tank" ou "heal"
local log = {}

local function obj()
  local o = {}
  return setmetatable(o, {__index = function(t, k)
    if k == "IsPlaying" then return function() return t._playing end end
    if k == "Play" then return function() t._playing = true end end
    if k == "Stop" then return function() t._playing = false end end
    if k == "Show" then return function() t._shown = true end end
    if k == "Hide" then return function() t._shown = false end end
    if k == "SetText" then return function(_, s) t._text = s end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 180 end end
    if k:match("^Create") then return function() return obj() end end
    if k == "SetScript" then return function(_, ev, fn) t["_"..ev] = fn end end
    return function() end
  end})
end
local frames = {}
CreateFrame = function() local o = obj(); frames[#frames+1] = o; return o end
UIParent = obj()
UnitClass = function() return "Paladin", "PALADIN" end
GetTime = function() return now end
GetLocale = function() return "frFR" end
IsInInstance = function() return inst, inst and "party" or "none" end
UnitIsDeadOrGhost = function() return false end
UnitOnTaxi = function() return false end
PlaySound = function() log[#log+1] = "SON" end
SOUNDKIT = { RAID_WARNING = 8959 }
RaidWarningFrame = {}; ChatTypeInfo = { RAID_WARNING = {} }
RaidNotice_AddMessage = function(_, m) log[#log+1] = "RW:"..m end
local tick
C_Timer = { NewTicker = function(_, fn) tick = fn end }
SlashCmdList = {}
print = function(...) log[#log+1] = table.concat({...}, " ") end
IsPlayerSpell = function(id) return flavor ~= "retail" and id == 25780 end

local function furyAura() if fury then return { spellId = 25780, expirationTime = fury } end end
local function points() if spec == "tank" then return {0, 31, 20} else return {41, 10, 0} end end
local group = function() return spec == "tank" and 2 or 1 end

local modernAuras = { GetPlayerAuraBySpellID = function(id) return id == 25780 and furyAura() or nil end,
  GetAuraDataByIndex = function(_, i) if i == 1 then return furyAura() end end }
local modernSpell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 135962 end }
local function legacyUnitBuff(_, i)
  if i == 1 and fury then return "Fureur vertueuse", 1, 0, nil, (fury == 0 and 0 or 1800), fury, "player", false, false, 25780 end
end
local function tabsNew() GetNumTalentTabs = function() return 3 end
  GetTalentTabInfo = function(tab, _, _, g) return 800 + tab, "Arbre"..tab, "desc", 1, points()[tab], "bg", 0, true end end
local function tabsOld() GetNumTalentTabs = function() return 3 end
  GetTalentTabInfo = function(tab) return "Arbre"..tab, 1, points()[tab], "bg" end end

if flavor == "forever" then
  C_UnitAuras = modernAuras; C_Spell = modernSpell
  issecretvalue = function() return false end
  C_ClassTalents = { GetActiveConfigID = function() return spec == "tank" and 11 or 12 end }
  C_Traits = { GetConfigInfo = function() return { treeIDs = { 900 } } end,
    GetGroupDisplayInfoByTreeID = function() return { {groupID=101}, {groupID=102}, {groupID=103} } end,
    GetGroupCurrencyInfo = function(_, ids) local r, p = {}, points()
      for i, id in ipairs(ids) do r[i] = { traitNodeGroupID = id, currencyInfos = { { spent = p[i] } } } end return r end }
  C_SpecializationInfo = { GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 65, "x", "d", 0, "DAMAGER" end }   -- rôle faux, comme sur Forever
elseif flavor == "era" or flavor == "tbc" then        -- clients Classic récents
  C_UnitAuras = modernAuras; C_Spell = modernSpell
  GetActiveTalentGroup = group; tabsNew()
elseif flavor == "era-ancien" then                   -- client Classic sans API modernes
  UnitBuff = legacyUnitBuff; GetSpellInfo = function() return "Fureur vertueuse" end
  GetSpellTexture = function() return 135962 end
  GetActiveTalentGroup = group; tabsOld()
elseif flavor == "cata" then
  C_UnitAuras = modernAuras; C_Spell = modernSpell
  GetActiveTalentGroup = group; tabsNew()
elseif flavor == "mop" then
  C_UnitAuras = modernAuras; C_Spell = modernSpell
  C_SpecializationInfo = { GetSpecialization = function() return spec == "tank" and 2 or 1 end,
    GetSpecializationInfo = function(i) return 64 + i, "x", "d", 0, (i == 2 and "TANK" or "HEALER") end,
    GetActiveSpecGroup = function() return group() end }
elseif flavor == "retail" then
  C_UnitAuras = modernAuras; C_Spell = modernSpell
  issecretvalue = function() return false end
  C_SpecializationInfo = { GetSpecialization = function() return 2 end,
    GetSpecializationInfo = function() return 66, "x", "d", 0, "TANK" end }
end

local ns = {}
assert(loadfile(localesFile))("HolyFury", ns)
assert(loadfile(mainFile))("HolyFury", ns)
local alert, events = frames[1], frames[2]
local ev = events._OnEvent
ev(events, "ADDON_LOADED", "HolyFury"); ev(events, "PLAYER_LOGIN"); ev(events, "PLAYER_ENTERING_WORLD")
local permanent = (flavor == "cata" or flavor == "mop")
local results, fails = {}, 0
local function check(label, want)
  local ok, err = pcall(tick)
  for _, line in ipairs(log) do   -- erreur attrapée par l'addon et affichée dans le chat
    if ok and line:find("|cffff2020", 1, true) then ok, err = false, line end
  end
  local shown = alert._shown and true or false
  local good = ok and shown == want
  if not good then fails = fails + 1 end
  results[#results+1] = string.format("  %-4s %-40s affichée=%s%s", good and "OK" or "ÉCHEC", label, tostring(shown), ok and "" or (" ERREUR: "..tostring(err)))
  log = {}
end
check("spé tank, Fureur absente", flavor ~= "retail")
fury = permanent and 0 or now + 1800; check("Fureur active", false)
if not permanent then now = now + 1750; check("reste 50 s (compte à rebours)", flavor ~= "retail") end
if not permanent then now = now + 60; check("Fureur expirée", flavor ~= "retail") end
fury = nil; spec = "heal"; ev(events, "ACTIVE_TALENT_GROUP_CHANGED"); ev(events, "PLAYER_SPECIALIZATION_CHANGED"); check("spé soins, Fureur absente", false)
spec = "tank"; ev(events, "ACTIVE_TALENT_GROUP_CHANGED"); ev(events, "PLAYER_SPECIALIZATION_CHANGED"); check("retour spé tank", flavor ~= "retail")
-- Forever en combat : auras masquées. L'API d'aura échoue ou renvoie des valeurs secrètes,
-- l'addon doit se fier à l'heure d'expiration lue avant le combat, sans erreur.
if flavor == "forever" then
  local secret = {}
  local hidden = false
  issecretvalue = function(v) return v == secret end
  issecrettable = function(t) return t == secret end
  C_Secrets = { ShouldAurasBeSecret = function() return hidden end }
  local realAuras = C_UnitAuras
  local function restricted(f) return function(...) if hidden then error("aura API blocked in combat") end return f(...) end end
  C_UnitAuras = { GetPlayerAuraBySpellID = restricted(realAuras.GetPlayerAuraBySpellID),
    GetAuraDataByIndex = restricted(realAuras.GetAuraDataByIndex) }
  fury = now + 1800; check("combat : avant le pull, Fureur active", false)
  hidden = true
  for _ = 1, 8 do now = now + 1; check("combat : auras masquées (pack)", false) end
  now = now + 1800; check("combat : expirée pendant le combat", true)
  fury = now + 1800; hidden = false; check("combat : fin, Fureur relancée et relue", false)
  -- Variante : pas de C_Secrets, mais l'aura renvoyée est une valeur secrète
  C_Secrets = nil; C_UnitAuras = { GetPlayerAuraBySpellID = function() return secret end,
    GetAuraDataByIndex = function() return { spellId = secret, expirationTime = secret } end }
  now = now + 1; check("combat : aura secrète, sans erreur", false)
  C_UnitAuras = realAuras; issecretvalue = function() return false end; issecrettable = nil
end
local ok, err = pcall(SlashCmdList.HOLYFURY, ""); if not ok then fails = fails + 1 end
results[#results+1] = "  " .. (ok and "OK  " or "ÉCHEC") .. " /hf (statut)" .. (ok and "" or (" ERREUR: "..tostring(err)))
local statusLine = log[3] or ""
ok, err = pcall(SlashCmdList.HOLYFURY, "spe"); if not ok then fails = fails + 1 end
results[#results+1] = "  " .. (ok and "OK  " or "ÉCHEC") .. " /hf spe" .. (ok and "" or (" ERREUR: "..tostring(err)))
io.write(string.format("== %-11s %s\n", flavor, fails == 0 and "tout bon" or (fails .. " échec(s)")))
for _, r in ipairs(results) do io.write(r, "\n") end
io.write("  statut :", statusLine, "\n")

os.exit(fails == 0 and 0 or 1)
