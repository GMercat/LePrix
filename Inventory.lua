local _, ns = ...

-- Inventaire de chaque personnage (sacs + banque), stocké dans le marché de sa faction,
-- pour que le personnage à l'HV puisse scanner les objets de tous les autres.

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local QUEST_CLASS = (Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local function BagContainers()
  local list = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0) do list[#list + 1] = bag end
  return list
end

local function BankContainers()
  local B = Enum.BagIndex
  if B and B.Bank and B.BankBag_1 then
    local list = { B.Bank }
    for i = 1, 7 do
      if B["BankBag_" .. i] then list[#list + 1] = B["BankBag_" .. i] end
    end
    return list
  end
  local list = { BANK_CONTAINER or -1 }
  local first = (NUM_BAG_SLOTS or 4) + 1
  for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = bag end
  return list
end

-- Filtre « vendable à l'HV » utilisable hors HV : IsSellItemValid n'est fiable que devant l'HV.
local function Sellable(loc, id)
  if C_Item.IsBound and C_Item.IsBound(loc) then return false end
  local quality = C_Item.GetItemQuality and C_Item.GetItemQuality(loc)
  if quality == 0 then return false end
  local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(id)
  if classID == QUEST_CLASS then return false end
  return true, equipLoc and equipLoc ~= ""
end

local function Snapshot(containers)
  local items = {}
  for _, bag in ipairs(containers) do
    for slot = 1, GetNumSlots(bag) or 0 do
      local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
      if loc:IsValid() then
        local id = C_Item.GetItemID(loc)
        local ok, equip = Sellable(loc, id)
        if id and ok then
          local _, suffix = ns.ParseLink(C_Item.GetItemLink(loc))
          local k = ns.Key(id, suffix)
          local e = items[k]
          if e then
            e.count = e.count + (C_Item.GetStackCount(loc) or 1)
          else
            items[k] = {
              id = id, suffix = suffix or 0, equip = equip or nil,
              level = equip and C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(loc) or nil,
              count = C_Item.GetStackCount(loc) or 1,
            }
          end
        end
      end
    end
  end
  return items
end

local function Me()
  if not ns.market then return end
  ns.market.chars = ns.market.chars or {}
  local name = UnitName("player")
  local c = ns.market.chars[name]
  if not c then
    c = {}
    ns.market.chars[name] = c
  end
  return c
end

function ns.SnapshotBags()
  local c = Me()
  if not c then return end
  c.bags, c.bagsT = Snapshot(BagContainers()), time()
end

local bankOpen = false
function ns.SnapshotBank()
  local c = Me()
  if not (c and bankOpen) then return end
  c.bank, c.bankT = Snapshot(BankContainers()), time()
end

ns.On("PLAYER_LOGIN", function() ns.SnapshotBags() end)
ns.On("BAG_UPDATE_DELAYED", function()
  ns.SnapshotBags()
  ns.SnapshotBank()
end)
ns.On("BANKFRAME_OPENED", function()
  bankOpen = true
  ns.SnapshotBank()
end)
ns.On("PLAYERBANKSLOTS_CHANGED", function() ns.SnapshotBank() end)
ns.On("BANKFRAME_CLOSED", function() bankOpen = false end)

-- Liste dédoublonnée des objets de tous les personnages de ce marché.
function ns.AllCharItems()
  local all = {}
  for _, c in pairs(ns.market.chars or {}) do
    for _, where in ipairs({ c.bags or {}, c.bank or {} }) do
      for k, e in pairs(where) do
        if not all[k] then all[k] = e end
      end
    end
  end
  return all
end

function ns.ListChars()
  local chars = ns.market.chars or {}
  local any = false
  for name, c in pairs(chars) do
    any = true
    local nb, nk = 0, 0
    for _ in pairs(c.bags or {}) do nb = nb + 1 end
    for _ in pairs(c.bank or {}) do nk = nk + 1 end
    ns.Print("%s : %d objet(s) en sacs (%s), %d en banque (%s)", name,
      nb, c.bagsT and ("il y a " .. ns.Ago(c.bagsT)) or "jamais",
      nk, c.bankT and ("il y a " .. ns.Ago(c.bankT)) or "banque jamais ouverte")
  end
  if not any then ns.Print("aucun personnage enregistré pour ce marché") end
end

function ns.ForgetChar(name)
  local chars = ns.market.chars or {}
  for n in pairs(chars) do
    if n:lower() == name:lower() then
      chars[n] = nil
      return ns.Print("%s oublié", n)
    end
  end
  ns.Print("personnage inconnu : %s", name)
end
