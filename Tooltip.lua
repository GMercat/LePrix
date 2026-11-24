local _, ns = ...

function ns.Ago(t)
  if not t then return "?" end
  local d = time() - t
  if d < 3600 then return string.format("%d min", math.max(1, math.floor(d / 60))) end
  if d < 86400 then return string.format("%d h", math.floor(d / 3600)) end
  return string.format("%d j", math.floor(d / 86400))
end

function ns.Money(c) return GetMoneyString(c, true) end

local GREY = "|cff888888"

-- Taille de la pile survolée : connue seulement pour un objet réel (sacs, banque, courrier...),
-- via son GUID. Pour un lien de chat ou un objet de loot, on reste sur 1.
local function StackCount(data)
  local guid = data and data.guid
  if not (guid and C_Item.GetItemLocation and C_Item.GetStackCount) then return 1 end
  local ok, loc = pcall(C_Item.GetItemLocation, guid)
  if not (ok and loc and loc.IsValid and loc:IsValid()) then return 1 end
  local ok2, count = pcall(C_Item.GetStackCount, loc)
  return (ok2 and count and count > 1) and count or 1
end

local function AddPrice(tt, link, count)
  if not ns.market then return end
  local id, suffix = ns.ParseLink(link)
  if not id then return end
  local exact = ns.market.prices[ns.Key(id, suffix)]
  local p = exact or ns.market.prices[tostring(id)]
  if not p or not p.t then return end
  count = count or 1

  if p.avg then
    -- Valeur lissée (moyenne des 200 unités / médiane des 5 annonces les moins chères), nette de commission.
    local tag = (not exact and suffix ~= 0) and " (tous suffixes)" or ""
    local LINE = "|cff33ccffLePrix HV%s%s :|r %s"
    if count > 1 then
      tt:AddLine(LINE:format(" x" .. count, tag, ns.Money(ns.Net(p.avg * count))), 1, 1, 1)
      tt:AddLine(LINE:format(" x1", "", ns.Money(ns.Net(p.avg))), 1, 1, 1)
    else
      tt:AddLine(LINE:format("", tag, ns.Money(ns.Net(p.avg))), 1, 1, 1)
    end
  end
  local status = (p.n == 0) and (p.avg and "aucune annonce, dernier prix connu · " or "aucune annonce · ") or ""
  tt:AddLine(GREY .. status .. "relevé il y a " .. ns.Ago(p.t) .. "|r")
end

if TooltipDataProcessor and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local _, link = tt:GetItem()
    AddPrice(tt, link or (data and data.hyperlink), StackCount(data))
  end)
else
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    tt:HookScript("OnTooltipSetItem", function(self)
      local _, link = self:GetItem()
      AddPrice(self, link)
    end)
  end
end
