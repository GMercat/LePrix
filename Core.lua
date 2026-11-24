local ADDON, ns = ...

-- Réglages ------------------------------------------------------------------
ns.CUT     = 0.05      -- commission HV de faction
ns.N_UNITS = 200       -- marchandises : moyenne pondérée sur les N unités les moins chères
ns.N_ITEMS = 5         -- équipement : médiane des N annonces les moins chères
ns.STALE   = 15 * 60   -- ne pas rescanner un objet des sacs vu il y a moins de 15 min
ns.TIMEOUT = 5         -- secondes d'attente max d'une réponse de recherche

ns.PREFIX = "|cff33ccffLe Prix|r : "
function ns.Print(...) print(ns.PREFIX .. string.format(...)) end

-- Dispatcher d'événements (tolère les événements absents du client) ---------
local frame = CreateFrame("Frame")
ns.handlers, ns.missingEvents = {}, {}

function ns.On(event, fn)
  if not ns.handlers[event] then
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then
      ns.missingEvents[#ns.missingEvents + 1] = event
      return
    end
    ns.handlers[event] = {}
  end
  table.insert(ns.handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(ns.handlers[event]) do fn(...) end
end)

-- Utilitaires sur les liens d'objets ----------------------------------------
-- item:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:...
function ns.ParseLink(link)
  if type(link) ~= "string" then return end
  local s = link:match("item:([%-%d:]+)")
  if not s then return end
  local f = { strsplit(":", s) }
  return tonumber(f[1]), tonumber(f[7]) or 0
end

function ns.Key(id, suffix)
  if suffix and suffix ~= 0 then return id .. ":" .. suffix end
  return tostring(id)
end

function ns.Net(copper) return math.floor(copper * (1 - ns.CUT)) end

-- Base de données -------------------------------------------------------------
-- Pas de royaumes dans Forever : un marché = région + faction.
function ns.MarketKey()
  local region = GetCurrentRegion and GetCurrentRegion() or 0
  return region .. ":" .. (UnitFactionGroup("player") or "?")
end

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  LePrixDB = LePrixDB or {}
  local db = LePrixDB
  db.version = db.version or 1
  db.markets = db.markets or {}
  ns.prevSession = db.lastSave -- sert à vérifier que les SavedVariables persistent
  ns.db = db
end)

ns.On("PLAYER_LOGIN", function()
  local key = ns.MarketKey()
  local m = ns.db.markets[key]
  if not m then
    m = { prices = {}, watch = {} }
    ns.db.markets[key] = m
  end
  ns.market = m
  ns.db.lastSave = time()
  if not ns.prevSession then
    ns.Print("aucune donnée d'une session précédente. Si ce n'est pas ta première connexion avec l'addon, les SavedVariables ne persistent pas (/lp debug).")
  end
end)

ns.On("PLAYER_LOGOUT", function()
  if ns.db then ns.db.lastSave = time() end
end)

-- Diagnostic ----------------------------------------------------------------
function ns.Debug()
  local version, build, _, toc = GetBuildInfo()
  ns.Print("client %s (build %s), Interface = %s", tostring(version), tostring(build), tostring(toc))
  ns.Print("marché = %s, GetRealmName = %s", ns.MarketKey(), tostring(GetRealmName()))
  if ns.prevSession then
    ns.Print("persistance OK : dernière sauvegarde %s", date("%d/%m %H:%M", ns.prevSession))
  else
    ns.Print("persistance : rien trouvé de la session précédente")
  end
  local n = 0
  for _ in pairs(ns.market and ns.market.prices or {}) do n = n + 1 end
  ns.Print("%d prix en cache, %d objet(s) surveillé(s)", n, ns.market and #ns.market.watch or 0)

  local ah = C_AuctionHouse or {}
  local apis = { "SendSearchQuery", "MakeItemKey", "GetItemKeyFromItem", "IsSellItemValid",
                 "GetNumCommoditySearchResults", "GetCommoditySearchResultInfo",
                 "GetNumItemSearchResults", "GetItemSearchResultInfo", "IsThrottledMessageSystemReady" }
  local missing = {}
  for _, f in ipairs(apis) do
    if type(ah[f]) ~= "function" then missing[#missing + 1] = f end
  end
  ns.Print("C_AuctionHouse : %s", #missing == 0 and "toutes les fonctions utiles sont présentes"
                                   or ("ABSENTES : " .. table.concat(missing, ", ")))
  ns.Print("infobulles : %s", TooltipDataProcessor and "TooltipDataProcessor" or "OnTooltipSetItem")
  if #ns.missingEvents > 0 then
    ns.Print("événements inconnus du client : %s", table.concat(ns.missingEvents, ", "))
  end
end

-- Commandes -------------------------------------------------------------------
SLASH_LEPRIX1 = "/leprix"
SLASH_LEPRIX2 = "/lp"
SlashCmdList.LEPRIX = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "add" or cmd == "del" then
    local id = ns.ParseLink(rest) or tonumber(rest)
    if not id then return ns.Print("usage : /lp %s [lien d'objet ou itemID]", cmd) end
    if cmd == "add" then ns.WatchAdd(id) else ns.WatchRemove(id) end
  elseif cmd == "scan" then
    if not ns.ahOpen then return ns.Print("ouvre l'HV d'abord") end
    ns.QueueBags(true)
  elseif cmd == "persos" then
    ns.ListChars()
  elseif cmd == "oublier" then
    if rest == "" then return ns.Print("usage : /lp oublier NomDuPerso") end
    ns.ForgetChar(rest)
  elseif cmd == "reset" then
    wipe(ns.market.prices)
    ns.Print("cache des prix vidé pour ce marché")
  elseif cmd == "debug" then
    ns.Debug()
  else
    ns.Print("/lp add|del [lien] · /lp scan (force le scan des sacs) · /lp persos · /lp oublier Nom · /lp reset · /lp debug")
  end
end
