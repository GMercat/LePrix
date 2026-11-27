"""Charge l'addon dans un environnement WoW simulé et rejoue un passage à l'HV."""
import sys, pathlib
try:
    from lupa import lua51 as lupa_mod
except ImportError:
    import lupa as lupa_mod

ADDON = pathlib.Path(sys.argv[1])
FILES = ["Core.lua", "Price.lua", "Scanner.lua", "Inventory.lua", "Tooltip.lua", "Watchlist.lua"]

MOCK = r'''
NOW = 1000000
function time() return NOW end
function date(f, t) return "date" end
function strsplit(sep, s) local t = {} for p in (s..sep):gmatch("(.-)"..sep) do t[#t+1]=p end return unpack(t) end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
function GetMoneyString(c) return tostring(c).."c" end
PRINTS = {}
function print(s) PRINTS[#PRINTS+1]=s end
function GetBuildInfo() return "1.0.0", "123", "", 11508 end
function GetCurrentRegion() return 3 end
function GetRealmName() return "Forever" end
function UnitFactionGroup() return "Alliance" end
function GetCursorInfo() return nil end
function ClearCursor() end
NUM_BAG_SLOTS = 0
SlashCmdList = {}
Enum = { AuctionHouseSortOrder = { Price = 0 }, TooltipDataType = { Item = 0 }, BagIndex = { ReagentBag = 5 } }

local function newFrame()
  local f = { scripts = {}, shown = true }
  setmetatable(f, { __index = function(t, k)
    return function(self, ...) return nil end
  end })
  f.RegisterEvent = function(self, e) if e == "UNKNOWN_EVENT" then error("unknown") end REG[e]=self end
  f.SetScript = function(self, k, fn) self.scripts[k] = fn end
  f.HookScript = f.SetScript
  f.Show = function(self) self.shown = true end
  f.Hide = function(self) self.shown = false end
  f.IsShown = function(self) return self.shown end
  f.CreateFontString = function(self) local fs = newFrame(); fs.SetText = function(s, t) s.text = t end; return fs end
  f.CreateTexture = function() return newFrame() end
  return f
end
REG = {}
function CreateFrame(_, _, _, template)
  local f = newFrame(); FRAMES = FRAMES or {}; FRAMES[#FRAMES+1]=f
  if template == "ButtonFrameTemplate" then
    f.CloseButton = newFrame(); f.Inset = newFrame(); f.TitleText = newFrame(); f.templated = true
  end
  return f
end
function Fire(e, ...) for _, f in pairs(FRAMES) do if f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end

TIMERS = {}
C_Timer = {
  After = function(_, fn) fn() end,
  NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(s) s.cancelled = true end }; TIMERS[#TIMERS+1]=t; return t end,
}

-- Tooltip
TT_LINES = {}
POSTCALL = nil
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) POSTCALL = fn end }
GameTooltip = newFrame(); ItemRefTooltip = newFrame()
GameTooltip.AddDoubleLine = function(_, a, b) TT_LINES[#TT_LINES+1] = a.." = "..b end
GameTooltip.AddLine = function(_, a) TT_LINES[#TT_LINES+1] = (a:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
CURRENT_LINK = nil
GameTooltip.GetItem = function() return "x", CURRENT_LINK end
AuctionHouseFrame = newFrame()

-- Sacs : un minerai (commodité, id 2772) et une épée avec suffixe (id 15211, suffixe 1047)
C_Container = { GetContainerNumSlots = function(bag) if bag == 0 then return 4 elseif bag == 5 then return 1 end return 0 end }
BAG = { [1] = 2772, [2] = 15211, [3] = 9999, [4] = 8888, [501] = 2589 }
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot)
  return { slot = bag * 100 + slot, IsValid = function(s) return BAG[s.slot] ~= nil end } end }
function UnitName() return "Alpha" end
BOUND = { [3] = true }
C_Item = { GetItemID = function(loc) return BAG[loc.slot] end,
           IsBound = function(loc) return BOUND[loc.slot] or false end,
           GetItemQuality = function(loc) return loc.slot == 4 and 0 or 2 end,
           GetItemInfoInstant = function(id) if id == 15211 then return id, "", "", "INVTYPE_WEAPON", 1, 2 end return id, "", "", "", 1, 7 end,
           GetItemLink = function(loc) if BAG[loc.slot] == 15211 then return "|Hitem:15211:0:0:0:0:0:1047:0|h" end return "|Hitem:"..BAG[loc.slot].."::::::::|h" end,
           GetStackCount = function(loc) return loc.stack or 5 end,
           GetItemLocation = function(guid) local n = tonumber(guid:match("%d+")); return { stack = n, IsValid = function() return true end } end,
           GetCurrentItemLevel = function() return 30 end, GetItemIconByID = function() return 1 end,
           GetItemInfo = function(id) return "Objet"..id, nil, 2, nil,nil,nil,nil,nil,nil, 1 end }

SENT = {}
THROTTLE_READY = true
C_AuctionHouse = {
  IsThrottledMessageSystemReady = function() return THROTTLE_READY end,
  MakeItemKey = function(id, lvl, suf) MK = { id, lvl, suf }; return { itemID = id } end,
  GetItemKeyFromItem = function(loc) return { itemID = BAG[loc.slot] } end,
  IsSellItemValid = function(loc) return loc.slot <= 2 or loc.slot > 500 end,
  SendSearchQuery = function(key) SENT[#SENT+1] = key.itemID end,
  GetNumCommoditySearchResults = function() return #COMM end,
  GetCommoditySearchResultInfo = function(_, i) return COMM[i] end,
  GetNumItemSearchResults = function() return #ITEMS end,
  GetItemSearchResultInfo = function(_, i) return ITEMS[i] end,
}
-- 150 unités à 100c, 100 à 200c, dont 20 à nous dans la seconde ligne -> 200 premières : 150*100 + 50*200
COMM = { { unitPrice = 100, quantity = 150 }, { unitPrice = 200, quantity = 100, numOwnerItems = 20 } }
ITEMS = {
  { buyoutAmount = 5000, quantity = 1, itemLink = "|Hitem:15211:0:0:0:0:0:1047:0|h" },
  { buyoutAmount = 7000, quantity = 1, itemLink = "|Hitem:15211:0:0:0:0:0:1047:0|h" },
  { buyoutAmount = 9000, quantity = 1, itemLink = "|Hitem:15211:0:0:0:0:0:1047:0|h" },
  { buyoutAmount = 3000, quantity = 1, itemLink = "|Hitem:15211:0:0:0:0:0:200:0|h" },
  { buyoutAmount = 1000, quantity = 1, itemLink = "|Hitem:15211:0:0:0:0:0:1047:0|h", containsOwnerItem = true },
}
'''

def main():
    lua = lupa_mod.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    ns = lua.table()
    for f in FILES:
        src = (ADDON / f).read_text(encoding="utf-8")
        chunk = lua.eval("function(src, name) local f, err = loadstring(src, name); if not f then error(err) end; return f end")(src, f)
        chunk("LePrix", ns)
    G = lua.globals()
    fire = G.Fire
    fire("ADDON_LOADED", "LePrix"); fire("PLAYER_LOGIN")
    assert any("aucune donnée" in s for s in G.PRINTS.values()), "avertissement persistance absent"

    fire("AUCTION_HOUSE_SHOW")
    sent = list(G.SENT.values())
    assert sent == [2772], f"une seule recherche en vol attendue, eu {sent}"
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2772)
    assert list(G.SENT.values()) == [2772, 15211], list(G.SENT.values())
    assert ns.QueueSize() == 2, ns.QueueSize()  # 15211 en vol + 2589 (sac de composants) en file
    # Throttle : la file attend le signal
    G.THROTTLE_READY = False
    key = lua.eval("{ itemID = 15211 }")
    fire("ITEM_SEARCH_RESULTS_UPDATED", key)

    prices = ns.market.prices
    ore = prices["2772"]
    assert ore.low == 100 and ore.avg == (150*100 + 50*200)//200 and ore.n == 200, (ore.low, ore.avg, ore.n)
    sword = prices["15211:1047"]
    assert sword.low == 5000 and sword.avg == 7000 and sword.n == 3, (sword.low, sword.avg, sword.n)
    agg = prices["15211"]
    assert agg.low == 3000 and agg.n == 4, (agg.low, agg.n)

    # Watchlist : ajout pendant que le throttle bloque, puis signal
    ns.WatchAdd(4306)
    assert list(G.SENT.values())[-1] == 15211
    G.THROTTLE_READY = True
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    assert list(G.SENT.values())[-1] == 4306
    # Pas de réponse -> timeout -> on libère la file
    G.TIMERS[len(G.TIMERS)].fn()
    assert list(G.SENT.values())[-1] == 2589  # le sac de composants passe ensuite
    G.TIMERS[len(G.TIMERS)].fn()
    assert ns.QueueSize() == 0

    # Infobulle
    G.CURRENT_LINK = "|Hitem:15211:0:0:0:0:0:1047:0|h"
    G.POSTCALL(G.GameTooltip, None)
    lines = list(G.TT_LINES.values())
    assert lines[0] == f"LePrix HV : {int(7000*0.95)}c", lines
    assert lines[1].startswith("relevé il y a"), lines
    # Pile de 20 minerais survolée dans les sacs (GUID connu)
    G.TT_LINES = lua.table(); G.CURRENT_LINK = "|Hitem:2772::::::::|h"
    G.POSTCALL(G.GameTooltip, lua.eval('{ guid = "Item-20" }'))
    lines = list(G.TT_LINES.values())
    assert lines[0] == f"LePrix HV : {int(125*20*0.95)}c", lines
    assert len(lines) == 2 and lines[1].startswith("relevé"), lines
    # Lien de chat (pas de GUID) -> prix unitaire seulement, pas de ligne x1
    G.TT_LINES = lua.table()
    G.POSTCALL(G.GameTooltip, None)
    lines = list(G.TT_LINES.values())
    assert lines[0] == f"LePrix HV : {int(125*0.95)}c" and not any("x1" in l for l in lines), lines
    # Suffixe jamais vu -> repli sur l'agrégat
    G.TT_LINES = lua.table(); G.CURRENT_LINK = "|Hitem:15211:0:0:0:0:0:999:0|h"
    G.POSTCALL(G.GameTooltip, None)
    assert "(tous suffixes)" in list(G.TT_LINES.values())[0]

    # Évolution : nouveau relevé 1 h plus tard, plus cher
    G.NOW = G.NOW + 3600
    ns.Store("2772", 110, 165, 200)
    assert ore.prevAvg == 125 and ore.avg == 165
    # Aucune annonce : on garde le dernier prix
    ns.Store("2772", None, None, 0)
    assert ore.avg == 165 and ore.n == 0

    # Inventaire : Alpha (perso courant) filtré, + Beta enregistré lors d'une session précédente
    alpha = ns.market.chars["Alpha"].bags
    keys = sorted(alpha.keys())
    assert keys == ["15211:1047", "2589", "2772"], keys
    assert alpha["2772"].count == 5 and alpha["15211:1047"].equip and alpha["15211:1047"].level == 30
    beta = lua.eval('{ bags = { ["2589"] = { id = 2589, suffix = 0, count = 20 } }, bank = { ["14047"] = { id = 14047, suffix = 0, count = 3 }, ["2772"] = { id = 2772, suffix = 0, count = 2 } }, bagsT = 1 }')
    ns.market.chars["Beta"] = beta
    G.NOW = G.NOW + 3600   # tout est périmé
    before = len(G.SENT)
    ns.QueueAllChars()
    sent = list(G.SENT.values())[before:]
    # 4306 (surveillé, en vol), puis jamais relevés d'abord : 2589/14047, puis 15211 (1047), 2772 déjà en file? non -> doit venir
    assert ns.QueueSize() >= 3, ns.QueueSize()
    # vide la file en simulant des réponses vides
    for _ in range(10):
        if ns.QueueSize() == 0: break
        G.TIMERS[len(G.TIMERS)].fn()
    allsent = set(list(G.SENT.values())[before:])
    assert {2589, 14047, 2772, 15211} <= allsent, allsent
    assert 9999 not in allsent and 8888 not in allsent
    G.SlashCmdList.LEPRIX("persos")
    # /lp prix : relance détaillée
    n0 = len(G.PRINTS)
    G.SlashCmdList.LEPRIX("prix 2772")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2772)
    out = list(G.PRINTS.values())[n0:]
    assert any("2 ligne(s)" in l for l in out) and any("calculé" in l for l in out), out
    fire("AUCTION_HOUSE_CLOSED")
    # Réouverture de l'HV : tout le cache est rafraîchi, surveillance d'abord
    n0 = len(G.SENT)
    fire("AUCTION_HOUSE_SHOW")
    for _ in range(20):
        if ns.QueueSize() == 0: break
        G.TIMERS[len(G.TIMERS)].fn()
    sent = list(G.SENT.values())[n0:]
    # 2772 relevé à l'instant -> ignoré ; 15211 relevé il y a plus d'1 h -> relancé
    assert sent[0] == 4306 and 15211 in sent and 2772 not in sent and len(sent) == len(set(sent)), sent
    assert any("ignoré" in l for l in G.PRINTS.values())
    # 4 min plus tard : toujours frais ; 6 min plus tard : relancé automatiquement
    fire("AUCTION_HOUSE_CLOSED")
    G.NOW = G.NOW + 4 * 60
    n1 = len(G.SENT); fire("AUCTION_HOUSE_SHOW")
    for _ in range(20):
        if ns.QueueSize() == 0: break
        G.TIMERS[len(G.TIMERS)].fn()
    assert 2772 not in list(G.SENT.values())[n1:]
    fire("AUCTION_HOUSE_CLOSED")
    G.NOW = G.NOW + 2 * 60
    n1 = len(G.SENT); fire("AUCTION_HOUSE_SHOW")
    for _ in range(20):
        if ns.QueueSize() == 0: break
        G.TIMERS[len(G.TIMERS)].fn()
    assert 2772 in list(G.SENT.values())[n1:]
    # Bouton Actualiser sans fermer : même chose
    n0 = len(G.SENT)
    ns.Store("2772", 110, 165, 200)  # prix tout frais
    ns.QueueRefreshAll(True)         # bouton Actualiser : relance quand même
    for _ in range(20):
        if ns.QueueSize() == 0: break
        G.TIMERS[len(G.TIMERS)].fn()
    assert {4306, 2772, 15211} <= set(list(G.SENT.values())[n0:])
    # Bouton Liste : uniquement la liste de surveillance, même si elle est fraîche
    n0 = len(G.SENT)
    ns.RefreshWatchOnly()
    for _ in range(20):
        if ns.QueueSize() == 0: break
        G.TIMERS[len(G.TIMERS)].fn()
    assert list(G.SENT.values())[n0:] == [4306], list(G.SENT.values())[n0:]
    fire("AUCTION_HOUSE_CLOSED")
    G.SlashCmdList.LEPRIX("debug")
    print("\n".join(list(G.PRINTS.values())[-6:]))
    print("OK : tous les scénarios passent")

main()
