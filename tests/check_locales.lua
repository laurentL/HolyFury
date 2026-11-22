GetLocale = function() return "enUS" end
local ns = {}
assert(loadfile(arg[1]))("RappelFureur", ns)
local L = ns.LOCALES
local base = L.enUS
local function count(s) local n = 0 for _ in tostring(s):gmatch("%%[ds]") do n = n + 1 end return n end
local problems = 0
for name, loc in pairs(L) do
  local missing = {}
  for k, v in pairs(base) do
    if loc[k] == nil then missing[#missing+1] = k
    elseif type(v) == "string" and count(v) ~= count(loc[k]) then print(name, "FORMAT", k); problems = problems + 1 end
    if type(v) == "table" and loc[k] and #loc[k] ~= #v and k == "TREES" then print(name, "TREES size") problems = problems + 1 end
  end
  for k in pairs(loc) do if base[k] == nil then print(name, "CLE INCONNUE", k); problems = problems + 1 end end
  table.sort(missing)
  print(string.format("%-5s anglais par defaut pour : %s", name, table.concat(missing, ", ")))
end
-- collisions de mots de commande
local seen = {}
for name, loc in pairs(L) do for canon, word in pairs(loc.CMD or {}) do
  if seen[word] and seen[word] ~= canon then print("COLLISION", word, seen[word], canon); problems = problems + 1 end
  seen[word] = canon end end
print("problemes :", problems)
os.exit(problems == 0 and 0 or 1)
