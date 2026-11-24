local _, ns = ...

-- File de recherches, envoyées une par une au rythme autorisé par le serveur.
local queue, queued = {}, {}
ns.verbose = {} -- itemID -> true : afficher les résultats bruts de la prochaine recherche (/lp prix)

local function Raw(id, fmt, ...)
  if ns.verbose[id] then ns.Print(fmt, ...) end
end

local function Report(id, key)
  if not ns.verbose[id] then return end
  ns.verbose[id] = nil
  local p = ns.market.prices[key]
  if p and p.avg then
    ns.Print("→ calculé : plus bas %s, moyenne %s sur %d, net x1 %s",
      ns.Money(p.low), ns.Money(p.avg), p.n or 0, ns.Money(ns.Net(p.avg)))
  else
    ns.Print("→ aucune annonce exploitable")
  end
end
local pending, timer

local SORT = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }

local function Ready()
  local ah = C_AuctionHouse
  return not ah.IsThrottledMessageSystemReady or ah.IsThrottledMessageSystemReady()
end

function ns.QueueSize() return #queue + (pending and 1 or 0) end

function ns.Enqueue(id, itemKey, front)
  if queued[id] or pending == id then return end
  queued[id] = true
  local entry = { id = id, key = itemKey }
  if front then table.insert(queue, 1, entry) else table.insert(queue, entry) end
  ns.Pump()
end

local function Done(id)
  if pending ~= id then return end
  pending = nil
  if timer then timer:Cancel(); timer = nil end
  ns.RefreshPanel()
  ns.Pump()
end

function ns.Pump()
  if pending or not ns.ahOpen then return end
  local entry = queue[1]
  if not entry then return ns.RefreshPanel() end
  if not Ready() then return end -- on repartira sur AUCTION_HOUSE_THROTTLED_SYSTEM_READY
  table.remove(queue, 1)
  queued[entry.id] = nil
  pending = entry.id
  local key = entry.key or C_AuctionHouse.MakeItemKey(entry.id)
  C_AuctionHouse.SendSearchQuery(key, SORT, true)
  timer = C_Timer.NewTimer(ns.TIMEOUT, function()
    timer = nil
    Done(entry.id)
  end)
end

ns.On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function() ns.Pump() end)

-- Résultats : marchandises ----------------------------------------------------
ns.On("COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID)
  if itemID ~= pending then return end
  local ah, list = C_AuctionHouse, {}
  local total = ah.GetNumCommoditySearchResults(itemID) or 0
  Raw(itemID, "marchandise %d : %d ligne(s) reçue(s), complet = %s", itemID, total,
    tostring(ah.HasFullCommoditySearchResults and ah.HasFullCommoditySearchResults(itemID)))
  for i = 1, total do
    local r = ah.GetCommoditySearchResultInfo(itemID, i)
    if r and i <= 8 then
      Raw(itemID, "  #%d %s x%d (dont à moi : %d)", i, ns.Money(r.unitPrice), r.quantity, r.numOwnerItems or 0)
    end
    if r then
      local qty = r.quantity - (r.numOwnerItems or 0) -- on ignore nos propres annonces
      if qty > 0 then list[#list + 1] = { price = r.unitPrice, qty = qty } end
    end
  end
  ns.Store(tostring(itemID), ns.Commodity(list))
  Report(itemID, tostring(itemID))
  Done(itemID)
end)

-- Résultats : équipement (regroupés par suffixe aléatoire) --------------------
ns.On("ITEM_SEARCH_RESULTS_UPDATED", function(itemKey)
  if not itemKey or itemKey.itemID ~= pending then return end
  local ah, id = C_AuctionHouse, itemKey.itemID
  local groups, all = {}, {}
  local total = ah.GetNumItemSearchResults(itemKey) or 0
  Raw(id, "objet %d : %d annonce(s) reçue(s)", id, total)
  for i = 1, total do
    local r = ah.GetItemSearchResultInfo(itemKey, i)
    if r and i <= 8 then
      Raw(id, "  #%d %s x%d %s", i, ns.Money(r.buyoutAmount or 0), r.quantity or 1, r.containsOwnerItem and "(à moi)" or "")
    end
    if r and r.buyoutAmount and not r.containsOwnerItem then
      local unit = math.floor(r.buyoutAmount / math.max(r.quantity or 1, 1))
      local _, suffix = ns.ParseLink(r.itemLink)
      local k = ns.Key(id, suffix)
      groups[k] = groups[k] or {}
      table.insert(groups[k], unit)
      table.insert(all, unit)
    end
  end
  local idKey = tostring(id)
  for k, l in pairs(groups) do
    if k ~= idKey then ns.Store(k, ns.Items(l)) end
  end
  ns.Store(idKey, ns.Items(all)) -- agrégat tous suffixes confondus
  Report(id, idKey)
  Done(id)
end)

-- Scan des sacs ----------------------------------------------------------------
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

function ns.QueueBags(force)
  local ah, seen, now, added = C_AuctionHouse, {}, time(), 0
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, GetNumSlots(bag) or 0 do
      local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
      if loc:IsValid() then
        local id = C_Item.GetItemID(loc)
        -- IsSellItemValid écarte d'un coup les objets liés, de quête, invendables...
        if id and not seen[id] and ah.IsSellItemValid(loc, false) then
          seen[id] = true
          local p = ns.market.prices[tostring(id)]
          if force or not p or now - p.t > ns.STALE then
            ns.Enqueue(id, ah.GetItemKeyFromItem(loc))
            added = added + 1
          end
        end
      end
    end
  end
  if added > 0 then ns.Print("%d objet(s) des sacs à scanner", added) end
end

-- Scan des objets de tous les personnages (bouton « Mes persos ») ----------------
function ns.QueueAllChars()
  ns.SnapshotBags()
  local prices, now, list = ns.market.prices, time(), {}
  for k, e in pairs(ns.AllCharItems()) do
    local p = prices[k]
    if not p or now - p.t > ns.STALE then
      list[#list + 1] = { e = e, t = p and p.t or 0 }
    end
  end
  table.sort(list, function(a, b) return a.t < b.t end) -- jamais relevés puis les plus anciens
  for _, x in ipairs(list) do
    local e = x.e
    local key
    if e.equip then
      key = C_AuctionHouse.MakeItemKey(e.id, e.level or 0, e.suffix or 0)
    else
      key = C_AuctionHouse.MakeItemKey(e.id)
    end
    ns.Enqueue(e.id, key)
  end
  ns.Print("%d objet(s) de tes personnages à scanner", #list)
  ns.RefreshPanel()
end

-- Rafraîchissement complet (ouverture de l'HV et bouton « Actualiser ») ----------
-- Ordre : liste de surveillance, sacs, puis le reste du cache du plus ancien au plus récent.
function ns.QueueRefreshAll()
  ns.QueueWatch()
  ns.QueueBags(true)
  local known = ns.AllCharItems() -- donne niveau et suffixe pour l'équipement des persos
  local list = {}
  for k, p in pairs(ns.market.prices) do
    local id = tonumber(k:match("^(%d+)"))
    if id then list[#list + 1] = { id = id, k = k, t = p.t or 0 } end
  end
  table.sort(list, function(a, b) return a.t < b.t end)
  for _, x in ipairs(list) do
    local e = known[x.k]
    local key
    if e and e.equip then
      key = C_AuctionHouse.MakeItemKey(e.id, e.level or 0, e.suffix or 0)
    end
    ns.Enqueue(x.id, key) -- dédoublonné par itemID
  end
  ns.Print("%d recherche(s) en file", ns.QueueSize())
  ns.RefreshPanel()
end

-- Ouverture / fermeture de l'HV ----------------------------------------------
ns.On("AUCTION_HOUSE_SHOW", function()
  if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then
    return ns.Print("API de l'HV introuvable sur ce client, voir /lp debug")
  end
  ns.ahOpen = true
  -- Un tick plus tard : l'interface de l'HV de Blizzard est alors chargée et affichée.
  C_Timer.After(0, function()
    ns.ShowPanel()
    ns.QueueRefreshAll()
  end)
end)

ns.On("AUCTION_HOUSE_CLOSED", function()
  ns.ahOpen = false
  wipe(queue); wipe(queued)
  pending = nil
  if timer then timer:Cancel(); timer = nil end
  ns.HidePanel()
end)
