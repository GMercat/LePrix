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

local function AddPrice(tt, link)
  if not ns.market then return end
  local id, suffix = ns.ParseLink(link)
  if not id then return end
  local exact = ns.market.prices[ns.Key(id, suffix)]
  local p = exact or ns.market.prices[tostring(id)]
  if not p or not p.t then return end

  if p.avg then
    local tag = (not exact and suffix ~= 0) and " (tous suffixes)" or ""
    tt:AddDoubleLine("HV valeur nette" .. tag, ns.Money(ns.Net(p.avg)), 0.2, 0.8, 1, 1, 1, 1)
    tt:AddDoubleLine("HV vendre à (net)", ns.Money(ns.Net(math.max(p.low - 1, 1))), 0.2, 0.8, 1, 1, 1, 1)
  end
  local status = (p.n == 0) and (p.avg and "aucune annonce, dernier prix connu · " or "aucune annonce · ") or ""
  tt:AddLine(GREY .. status .. "relevé il y a " .. ns.Ago(p.t) .. "|r")
end

if TooltipDataProcessor and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local _, link = tt:GetItem()
    AddPrice(tt, link or (data and data.hyperlink))
  end)
else
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    tt:HookScript("OnTooltipSetItem", function(self)
      local _, link = self:GetItem()
      AddPrice(self, link)
    end)
  end
end
