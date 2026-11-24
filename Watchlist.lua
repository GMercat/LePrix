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
  r:SetSize(WIDTH - 44, ROW_H)
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

-- Cadre au style des fenêtres Blizzard (même modèle que l'HV) ; repli sur un fond simple
-- si le modèle n'existe pas sur ce client.
local function NewStyledFrame(parent)
  local ok, f = pcall(CreateFrame, "Frame", "LePrixPanel", parent, "ButtonFrameTemplate")
  if ok and f then
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    if f.CloseButton then f.CloseButton:Hide() end -- le panneau suit l'HV
    if f.SetTitle then
      f:SetTitle("Surveillance HV")
    else
      local t = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
      if t then t:SetText("Surveillance HV") end
    end
    return f, f.Inset or f
  end
  f = CreateFrame("Frame", "LePrixPanel", parent, "BackdropTemplate")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0, 0, 0, 0.85)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -8)
  title:SetText("Surveillance HV")
  return f, f
end

function ns.CreatePanel()
  local parent = AuctionHouseFrame or UIParent
  local inset
  panel, inset = NewStyledFrame(parent)
  panel:SetWidth(WIDTH)
  if AuctionHouseFrame then
    -- Collé à droite de l'HV, sur toute sa hauteur.
    panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
    panel:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 2, 0)
  else
    panel:SetSize(WIDTH, 420)
    panel:SetPoint("CENTER")
  end
  for _, f in ipairs({ panel, inset }) do
    f:EnableMouse(true)
    f:SetScript("OnReceiveDrag", AddFromCursor)
    f:SetScript("OnMouseUp", AddFromCursor)
  end

  local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  refresh:SetSize(80, 20)
  refresh:SetPoint("TOPRIGHT", -10, -30)
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
  chars:SetSize(100, 20)
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

  -- Liste dans l'encart, avec un rappel tant qu'elle est vide.
  local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -26, 6)
  scroll:SetScript("OnReceiveDrag", AddFromCursor)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(WIDTH - 44, 1)
  scroll:SetScrollChild(content)

  panel.empty = inset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  panel.empty:SetPoint("CENTER")
  panel.empty:SetWidth(WIDTH - 40)
  panel.empty:SetText("Glisse un objet ici\npour le surveiller")

  status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("BOTTOMLEFT", 12, 8)
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
  panel.empty:SetShown(#watch == 0)

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
