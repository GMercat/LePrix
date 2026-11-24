local _, ns = ...

local panel, content, status
local rows = {}
local ROW_H, WIDTH = 28, 300

local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Liste -----------------------------------------------------------------------
local function IndexOf(id)
  for i, v in ipairs(ns.market.watch) do if v == id then return i end end
end

function ns.WatchAdd(id)
  if IndexOf(id) then return end
  table.insert(ns.market.watch, id)
  if ns.ahOpen then ns.Enqueue(id, nil, true) end
  ns.RefreshPanel()
end

function ns.WatchRemove(id)
  local i = IndexOf(id)
  if i then table.remove(ns.market.watch, i) end
  ns.RefreshPanel()
end

function ns.QueueWatch()
  -- Prioritaire sur les sacs : la liste est courte et c'est elle qu'on regarde.
  for i = #ns.market.watch, 1, -1 do ns.Enqueue(ns.market.watch[i], nil, true) end
end

-- Interface ---------------------------------------------------------------------
local function AddFromCursor()
  local kind, id = GetCursorInfo()
  if kind == "item" and id then
    ClearCursor()
    ns.WatchAdd(id)
  end
end

local function Delta(p)
  if not (p.avg and p.prevAvg and p.prevAvg > 0) then return "" end
  local pct = (p.avg - p.prevAvg) / p.prevAvg * 100
  if math.abs(pct) < 0.5 then return " |cff888888=|r" end
  local color = pct > 0 and "|cff20ff20" or "|cffff4040"
  return string.format(" %s%+.0f%%|r", color, pct)
end

local function GetRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, content)
  r:SetSize(WIDTH - 40, ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(ROW_H - 2, ROW_H - 2)
  r.icon:SetPoint("LEFT")

  r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
  r.del:SetSize(ROW_H, ROW_H)
  r.del:SetPoint("RIGHT")
  r.del:SetScript("OnClick", function() ns.WatchRemove(r.id) end)

  r.price = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.price:SetPoint("RIGHT", r.del, "LEFT", -2, 0)
  r.price:SetJustifyH("RIGHT")

  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r.price, "LEFT", -4, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)

  r:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.id)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  r:RegisterForDrag("LeftButton")
  r:SetScript("OnReceiveDrag", AddFromCursor)
  r:SetScript("OnClick", AddFromCursor)

  rows[i] = r
  return r
end

function ns.CreatePanel()
  local parent = AuctionHouseFrame or UIParent
  panel = CreateFrame("Frame", "LePrixPanel", parent, "BackdropTemplate")
  panel:SetSize(WIDTH, 420)
  if AuctionHouseFrame then
    panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
  else
    panel:SetPoint("CENTER")
  end
  panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  panel:SetBackdropColor(0, 0, 0, 0.85)
  panel:EnableMouse(true)
  panel:SetScript("OnReceiveDrag", AddFromCursor)
  panel:SetScript("OnMouseUp", AddFromCursor)

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetText("Surveillance HV")

  local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  refresh:SetSize(80, 20)
  refresh:SetPoint("TOPRIGHT", -8, -6)
  refresh:SetText("Actualiser")
  refresh:SetScript("OnClick", function() ns.QueueRefreshAll() end)
  refresh:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Rafraîchir tous les prix en cache")
    GameTooltip:AddLine("Liste de surveillance, puis sacs, puis le reste du cache du plus ancien au plus récent.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  refresh:SetScript("OnLeave", GameTooltip_Hide)

  local chars = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  chars:SetSize(90, 20)
  chars:SetPoint("RIGHT", refresh, "LEFT", -4, 0)
  chars:SetText("Mes persos")
  chars:SetScript("OnClick", function() ns.QueueAllChars() end)
  chars:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Scanner les objets de tous tes personnages")
    GameTooltip:AddLine("Sacs et banque, tels qu'enregistrés à leur dernière connexion.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  chars:SetScript("OnLeave", GameTooltip_Hide)

  local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 10, -30)
  hint:SetText("Glisse un objet ici pour le surveiller")

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -48)
  scroll:SetPoint("BOTTOMRIGHT", -28, 26)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH - 40, 1)
  scroll:SetScrollChild(content)

  status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", 10, 9)
end

function ns.RefreshPanel()
  if not (panel and panel:IsShown()) then return end
  local watch = ns.market.watch
  for i, id in ipairs(watch) do
    local r = GetRow(i)
    r.id = id
    local name, _, quality, _, _, _, _, _, _, icon = GetInfo(id)
    r.icon:SetTexture(icon or C_Item.GetItemIconByID(id))
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    r.name:SetText((color and color.hex or "") .. (name or ("item:" .. id)) .. "|r")

    local p = ns.market.prices[tostring(id)]
    if p and p.avg then
      r.price:SetText(ns.Money(ns.Net(p.avg)) .. Delta(p) .. "\n|cff888888" ..
        (p.n == 0 and "absent · " or "") .. ns.Ago(p.t) .. "|r")
    elseif p then
      r.price:SetText("|cff888888aucune annonce · " .. ns.Ago(p.t) .. "|r")
    else
      r.price:SetText("|cff888888jamais relevé|r")
    end
    r:Show()
  end
  for i = #watch + 1, #rows do rows[i]:Hide() end
  content:SetHeight(math.max(1, #watch * ROW_H))

  local q = ns.QueueSize()
  status:SetText(q > 0 and string.format("Recherches en attente : %d", q) or "À jour")
end

function ns.ShowPanel()
  if not panel then ns.CreatePanel() end
  panel:Show()
  ns.RefreshPanel()
end

function ns.HidePanel()
  if panel then panel:Hide() end
end

-- Les noms et icônes arrivent en asynchrone la première fois qu'on voit un objet.
ns.On("GET_ITEM_INFO_RECEIVED", function() ns.RefreshPanel() end)
