local _, ns = ...

-- Marchandises : list = { {price = prixUnitaire, qty = quantité}, ... }
-- Renvoie : prix le plus bas, moyenne pondérée sur les N_UNITS moins chères, unités prises en compte.
function ns.Commodity(list)
  table.sort(list, function(a, b) return a.price < b.price end)
  local need, sum, got = ns.N_UNITS, 0, 0
  for _, e in ipairs(list) do
    local take = math.min(e.qty, need - got)
    if take > 0 then
      sum = sum + take * e.price
      got = got + take
    end
    if got >= need then break end
  end
  if got == 0 then return nil, nil, 0 end
  return list[1].price, math.floor(sum / got), got
end

-- Équipement : list = { prixUnitaire, ... }
-- Renvoie : prix le plus bas, médiane des N_ITEMS moins chères, nombre d'annonces.
function ns.Items(list)
  table.sort(list)
  local n = math.min(#list, ns.N_ITEMS)
  if n == 0 then return nil, nil, 0 end
  local med
  if n % 2 == 1 then
    med = list[(n + 1) / 2]
  else
    med = math.floor((list[n / 2] + list[n / 2 + 1]) / 2)
  end
  return list[1], med, #list
end

-- Enregistre un relevé. low == nil signifie « aucune annonce » : on garde le dernier prix connu.
function ns.Store(key, low, avg, count)
  local prices = ns.market.prices
  local p = prices[key]
  if not p then
    p = {}
    prices[key] = p
  end
  local now = time()
  -- La référence pour l'évolution n'est déplacée que si le relevé précédent date de plus de 30 min,
  -- sinon deux scans rapprochés afficheraient toujours ±0 %.
  if p.avg and p.t and now - p.t > 1800 then
    p.prevAvg, p.prevT = p.avg, p.t
  end
  if low then p.low, p.avg = low, avg end
  p.n, p.t = count or 0, now
end
