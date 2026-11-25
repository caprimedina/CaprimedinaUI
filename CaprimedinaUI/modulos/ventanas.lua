local addonName, C = ...
local _G = _G or getfenv(0)

-- ============================================================
--  Ventanas Grandes (para Android / Winlator)
--  Agranda las ventanas del juego para que sean clickeables.
--  NO toca: chat, bolas (PlayerFrame/TargetFrame), barras ni botones.
-- ============================================================

local TOP_MARGIN    = 22   -- margen superior (no tapar la barra de arriba)
local BOTTOM_MARGIN = 10   -- margen inferior
local SIDE_MARGIN   = 6    -- margen izquierda/derecha
local DEFAULT_MAX   = 2.2
local MIN_SHRINK    = 0.80 -- si no cabe (UI grande), se puede encoger hasta aqui
local POLL          = 0.4  -- cada cuanto se revisan las ventanas
-- Alto del marco "patron" (Personaje, Hechizos, Talentos = 384x512).
-- Las ventanas mas bajas que esto (ej. Buscador de mazmorras = 355x440) se
-- escalarian de mas para llenar el alto y su texto saldria mas grande.
local REF_HEIGHT    = 512

local function Print(msg)
    if C and C.Print then
        C.Print(msg)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[CaprimedinaUI]|r " .. tostring(msg))
    end
end

local function VentanasEnabled()
    local db = CaprimedinaUIDB
    if type(db) ~= "table" then return true end
    return db.enableVentanas ~= false
end

local function MaxMult()
    local v = 0
    if type(CaprimedinaUIDB) == "table" then
        v = tonumber(CaprimedinaUIDB.ventanasScale) or 0
    end
    if v <= 0 then v = DEFAULT_MAX end
    if v < 1.05 then v = 1.05 end
    if v > 3.0 then v = 3.0 end
    return v
end

-- Ventanas que se agrandan (ventanas "de panel" del juego).
-- Se excluyen a proposito chat, bolas, mochilas y barras de accion.
local VENTANAS_FRAMES = {
    -- Personaje / hechizos / talentos / inspeccionar
    "CharacterFrame",
    "SpellBookFrame",
    "TalentFrame",
    "PlayerTalentFrame",
    "InspectFrame",
    "DressUpFrame",
    "BarberShopFrame",

    -- Misiones / NPC
    "QuestLogFrame",
    "QuestFrame",
    "GossipFrame",

    -- Social
    "FriendsFrame",

    -- JcJ: la ventana real es PVPParentFrame (marco + contenido).
    -- PVPFrame es solo el contenido interno (setAllPoints), NO se escala aparte.
    "PVPParentFrame",

    -- Buscador de mazmorras (LFD = buscador aleatorio; LFG = grupos)
    "LFDParentFrame",
    "LFGParentFrame",

    -- Logros
    "AchievementFrame",
    "CalendarFrame",

    -- Menu de juego / opciones / ayuda
    "GameMenuFrame",
    "HelpFrame",
    "TicketFrame",
    "InterfaceOptionsFrame",
    "VideoOptionsFrame",
    "AudioOptionsFrame",
    "MacroFrame",
    "KeyBindingFrame",

    -- Comercio / servicios
    -- (BankFrame NO va aqui: el modulo de bolsos ya tiene su banco propio.)
    "MerchantFrame",
    "GuildBankFrame",
    "MailFrame",
    "TradeFrame",
    "AuctionFrame",
    "ClassTrainerFrame",
    "SkillFrame",
    "TradeSkillFrame",
    "CraftFrame",
    "PetStableFrame",
    "TaxiFrame",
    "TabardFrame",
    "ItemTextFrame",

    -- Mapa: NO se escala. Es una ventana a pantalla completa y al crecer se
    -- sale de la pantalla (se veia sobresalir). Se deja en su tamano normal.

    -- Botin / avisos
    "LootFrame",
    "ReadyCheckFrame",
    "StaticPopup1",
    "StaticPopup2",
    "StaticPopup3",
    "StaticPopup4",
}

-- Conjunto de ventanas administradas (para no escalar frames ajenos).
local MANAGED = {}
for i = 1, #VENTANAS_FRAMES do MANAGED[VENTANAS_FRAMES[i]] = true end

-- Una ventana se escala solo si ella misma esta en la lista y ningun
-- ancestro suyo tambien lo esta. Si el padre ya se escala, el hijo hereda
-- la escala; escalarlo otra vez lo multiplicaria (bug de JcJ a 4x).
local function IsManaged(f)
    if not f or type(f.GetName) ~= "function" then return false end
    local name = f:GetName()
    if not name or not MANAGED[name] then return false end

    local p = (f.GetParent and f:GetParent()) or nil
    local guard = 0
    while p and guard < 32 do
        guard = guard + 1
        local pn = (p.GetName and p:GetName()) or nil
        if pn and MANAGED[pn] then return false end
        p = (p.GetParent and p:GetParent()) or nil
    end
    return true
end

-- Escala base original de cada ventana (para no acumular multiplicaciones).
local function FrameBase(f)
    if not f._capriVentBase then
        local s = (f.GetScale and f:GetScale()) or 1
        if not s or s <= 0 then s = 1 end
        f._capriVentBase = s
    end
    return f._capriVentBase
end

-- Cuanto sobresale la ventana por debajo (pestanas tipo "Logros/Estadisticas").
-- Se calcula desde el anclaje para que funcione tambien con la ventana oculta.
local function TabExtraUnits(f)
    local name = f.GetName and f:GetName()
    if not name then return 0 end
    local extra = 0
    for i = 1, 4 do
        local t = _G[name .. "Tab" .. i]
        if t and t.GetPoint then
            local ok, p, rel, rp, x, y = pcall(t.GetPoint, t, 1)
            if ok and p and (p == "BOTTOMLEFT" or p == "BOTTOMRIGHT" or p == "BOTTOM") then
                -- Solo cuenta si la pestana cuelga POR DEBAJO del marco.
                local hang = -(y or 0)
                if hang > 0 then
                    local below = hang + 4   -- +4 de margen para el arte
                    if below > extra then extra = below end
                end
            end
        end
    end
    return extra
end

-- Posicion del punto de anclaje en unidades de pantalla (alto 768).
-- Con la ventana visible se toma de su rectangulo real (incluye anclajes,
-- offsets ya escalados y el clamp a pantalla). Si esta oculta se calcula
-- desde el frame relativo, porque el rectangulo puede ser nil o viejo.
local function AnchorPosPx(f)
    local ok, point, rel, relPoint, x, y = pcall(f.GetPoint, f, 1)
    if not ok or not point then return nil end
    point = tostring(point)

    local eff = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
    local l = (f.GetLeft and f:GetLeft()) or nil
    local r = (f.GetRight and f:GetRight()) or nil
    local b = (f.GetBottom and f:GetBottom()) or nil
    local t = (f.GetTop and f:GetTop()) or nil

    -- El rectangulo solo es fiable con la ventana visible. Oculto puede
    -- devolver nil o un valor viejo, y entonces se usa el anclaje real.
    local shown = (f.IsShown and f:IsShown()) or false
    if shown and l and r and b and t then
        local cx, cy = (l + r) / 2, (b + t) / 2
        local ax, ay = cx, cy
        if string.find(point, "LEFT", 1, true) then ax = l end
        if string.find(point, "RIGHT", 1, true) then ax = r end
        if string.find(point, "BOTTOM", 1, true) then ay = b end
        if string.find(point, "TOP", 1, true) then ay = t end
        return ax * eff, ay * eff, point
    end

    if type(rel) == "string" then rel = _G[rel] end
    local hasRel = rel ~= nil
    rel = rel or UIParent
    relPoint = tostring(relPoint or point)
    x = tonumber(x) or 0
    y = tonumber(y) or 0

    local relEff = (rel.GetEffectiveScale and rel:GetEffectiveScale()) or 1
    local rl = (rel.GetLeft and rel:GetLeft()) or 0
    local rr = (rel.GetRight and rel:GetRight()) or 0
    local rb = (rel.GetBottom and rel:GetBottom()) or 0
    local rt = (rel.GetTop and rel:GetTop()) or 0

    local ax, ay
    if string.find(relPoint, "LEFT", 1, true) then ax = rl
    elseif string.find(relPoint, "RIGHT", 1, true) then ax = rr
    else ax = (rl + rr) / 2 end
    if string.find(relPoint, "BOTTOM", 1, true) then ay = rb
    elseif string.find(relPoint, "TOP", 1, true) then ay = rt
    else ay = (rb + rt) / 2 end

    -- Los offsets de SetPoint van en unidades del frame relativo (no del
    -- propio frame): escalar una ventana no mueve su punto de anclaje.
    -- Si el anclaje es a la pantalla (sin relativo), ya van en unidades
    -- de pantalla y no se escalan.
    local offScale = hasRel and relEff or 1
    return (ax * relEff) + (x * offScale), (ay * relEff) + (y * offScale), point
end

-- Escala efectiva maxima (unidades de pantalla por unidad del frame) para
-- que la ventana, con sus pestanas, quepa desde su punto de anclaje.
-- IMPORTANTE: es un valor ABSOLUTO. No depende de la escala actual, por lo
-- que se puede aplicar de una sola vez (sin efecto de crecer/encoger).
local function FitScale(f)
    local fw = (f.GetWidth and f:GetWidth()) or 0
    local fh = (f.GetHeight and f:GetHeight()) or 0
    if fw <= 1 or fh <= 1 then return nil end

    -- GetScreenWidth/Height vienen en unidades de UIParent. Se pasan a
    -- unidades de pantalla (alto 768) para que coincidan con GetLeft()*eff,
    -- que es como se mide el anclaje. Asi funciona con cualquier escala UI.
    local uiEff = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if not uiEff or uiEff <= 0 then uiEff = 1 end
    local sw = (GetScreenWidth() or 0) * uiEff
    local sh = (GetScreenHeight() or 0) * uiEff
    if sw <= 0 or sh <= 0 then return nil end

    local extra = TabExtraUnits(f)
    local ax, ay, point = AnchorPosPx(f)
    if not ax or not ay then return nil end

    local fitW
    if string.find(point, "LEFT", 1, true) then
        fitW = (sw - SIDE_MARGIN - ax) / fw
    elseif string.find(point, "RIGHT", 1, true) then
        fitW = (ax - SIDE_MARGIN) / fw
    else
        fitW = (2 * math.min(sw - SIDE_MARGIN - ax, ax - SIDE_MARGIN)) / fw
    end

    local fitH
    if string.find(point, "TOP", 1, true) then
        -- Anclada arriba: crece hacia abajo (las pestanas cuelgan abajo).
        fitH = (ay - BOTTOM_MARGIN) / (fh + extra)
    elseif string.find(point, "BOTTOM", 1, true) then
        -- Anclada abajo: crece hacia arriba y las pestanas cuelgan abajo.
        local up = (sh - TOP_MARGIN - ay) / fh
        local down = 999
        if extra > 0 then down = (ay - BOTTOM_MARGIN) / extra end
        fitH = math.min(up, down)
    else
        -- CENTER (o desconocido): crece hacia los dos lados.
        local up = (sh - TOP_MARGIN - ay) / (fh / 2)
        local down = (ay - BOTTOM_MARGIN) / (fh / 2 + extra)
        fitH = math.min(up, down)
    end

    if fitW < 0.05 then fitW = 0.05 end
    if fitH < 0.05 then fitH = 0.05 end

    -- Consistencia de tamano: una ventana anclada arriba que sea MAS BAJA que
    -- el marco patron (384x512) no debe escalarse mas que el. Si no, al llenar
    -- el alto se agranda (texto y botones mas grandes) y se ve distinta.
    -- Se limita a la escala que tendria un marco de REF_HEIGHT en ese mismo
    -- anclaje. Las ventanas igual de altas o mas altas no cambian.
    if string.find(point, "TOP", 1, true) then
        local refFit = (ay - BOTTOM_MARGIN) / REF_HEIGHT
        if refFit > 0 and refFit < fitH then
            fitH = refFit
        end
    end

    return math.min(fitW, fitH)
end

-- Calcula y aplica la escala de una sola vez: que la ventana (con sus
-- pestanas) quepa en el espacio real que tiene desde su anclaje, sin moverla.
local function ApplyToFrame(f)
    if not f or type(f.SetScale) ~= "function" or not f.GetScale then return end

    local base = FrameBase(f)
    local cur  = f:GetScale() or base

    if not VentanasEnabled() then
        if math.abs(cur - base) > 0.001 then
            pcall(f.SetScale, f, base)
        end
        return
    end

    local maxAbs = base * MaxMult()
    local minAbs = base * MIN_SHRINK

    -- Varias pasadas en la MISMA llamada (antes de que se dibuje). Asi, si
    -- al cambiar la escala el anclaje se desplaza un poco, se corrige al
    -- instante y la ventana no se ve crecer/encoger. Normalmente sale en la
    -- primera pasada; las demas son para anclajes con offsets grandes.
    for _ = 1, 8 do
        cur = f:GetScale() or base
        local eff = (f.GetEffectiveScale and f:GetEffectiveScale()) or 0
        if eff <= 0 then break end

        local fit = FitScale(f)
        if not fit then break end

        local curScale = cur
        if curScale <= 0 then curScale = base end
        local parentEff = eff / curScale
        if parentEff <= 0 then break end

        -- fit ya es escala efectiva; se pasa a escala del frame.
        local desired = fit / parentEff
        if desired > maxAbs then desired = maxAbs end
        if desired < minAbs then desired = minAbs end

        -- Zona muerta: evita micro-oscilaciones entre polls.
        local dead = cur * 0.02
        if dead < 0.02 then dead = 0.02 end
        if math.abs(desired - cur) <= dead then break end

        pcall(f.SetScale, f, desired)
    end
end

local function HookFrame(f)
    if not f or f._capriVentHooked then return end
    f._capriVentHooked = true
    -- Aplicar en OnShow, antes de que la ventana se dibuje: aparece ya con
    -- el tamano final. Antes se aplicaba en el siguiente poll y por eso se
    -- veia crecer/encoger al abrir.
    if f.HookScript then
        f:HookScript("OnShow", function(self)
            ApplyToFrame(self)
        end)
    end
end

local function ApplyAll()
    for i = 1, #VENTANAS_FRAMES do
        local f = _G[VENTANAS_FRAMES[i]]
        if f and IsManaged(f) then
            HookFrame(f)
            ApplyToFrame(f)
        end
    end
end

local function ResetAll()
    for i = 1, #VENTANAS_FRAMES do
        local f = _G[VENTANAS_FRAMES[i]]
        -- Solo las ventanas que este modulo escala de verdad.
        if f and IsManaged(f) and f.SetScale then
            pcall(f.SetScale, f, FrameBase(f))
        end
    end
end

-- Se engancha al sistema de paneles de Blizzard: cuando muestra/coloca
-- una ventana administrada, se le aplica la escala inmediatamente.
-- IMPORTANTE: solo ventanas de la lista. Escalar cualquier frame que pase
-- por ShowUIPanel provocaba doble escala (ej: PVPParentFrame + PVPFrame = 4x).
if type(ShowUIPanel) == "function" then
    hooksecurefunc("ShowUIPanel", function(frame)
        if IsManaged(frame) then
            HookFrame(frame)
            ApplyToFrame(frame)
        end
    end)
end

if type(SetUIPanel) == "function" then
    hooksecurefunc("SetUIPanel", function(frame)
        if IsManaged(frame) then
            ApplyToFrame(frame)
        end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
ev:RegisterEvent("UI_SCALE_CHANGED")
local announced = false
ev:SetScript("OnEvent", function()
    ApplyAll()
    if not announced and type(CaprimedinaUIDB) == "table" then
        announced = true
        if VentanasEnabled() then
            Print("Ventanas Grandes: |cff00ff00ON|r (auto, max " .. MaxMult() .. "x)")
        else
            Print("Ventanas Grandes: |cffff0000OFF|r")
        end
    end
end)

-- Poll: atrapa ventanas que se cargan tarde (Logros, LFG, etc.)
-- y corrige cualquier reset de escala que haga Blizzard.
local poll = CreateFrame("Frame")
local acc = 0
poll:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + (elapsed or 0)
    if acc < POLL then return end
    acc = 0
    ApplyAll()
end)

SLASH_CAPRIVENTANAS1 = "/ventanas"
SlashCmdList["CAPRIVENTANAS"] = function(msg)
    msg = (msg or ""):lower()
    if type(CaprimedinaUIDB) ~= "table" then CaprimedinaUIDB = {} end

    local cmd, arg = string.match(msg, "^(%S*)%s*(.-)$")
    cmd = cmd or ""

    if cmd == "max" or cmd == "scale" then
        local v = tonumber(arg)
        if v then
            CaprimedinaUIDB.ventanasScale = v
            ApplyAll()
            Print("Ventanas escala maxima: " .. MaxMult() .. "x")
        else
            Print("Uso: /ventanas max 2.2")
        end
        return
    end

    if cmd == "list" then
        Print("Ventanas (escala maxima " .. MaxMult() .. "x):")
        for i = 1, #VENTANAS_FRAMES do
            local name = VENTANAS_FRAMES[i]
            local f = _G[name]
            if f then
                Print(string.format("  %s: %.2fx%s", name, (f:GetScale() or 0),
                    f:IsShown() and " [abierta]" or ""))
            end
        end
        return
    end

    if cmd == "dump" then
        local uiEff = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if not uiEff or uiEff <= 0 then uiEff = 1 end
        local sw = (GetScreenWidth() or 0) * uiEff
        local sh = (GetScreenHeight() or 0) * uiEff
        local out = {}
        out[#out + 1] = string.format(
            "Pantalla: %.0fx%.0f uds (alto 768). UIParent esc=%.3f eff=%.3f cvar=%s/%s. Ventanas=%s. Max=%.2fx",
            sw, sh, (UIParent and UIParent.GetScale and UIParent:GetScale()) or 1, uiEff,
            tostring(GetCVar and GetCVar("useUiScale")), tostring(GetCVar and GetCVar("uiScale")),
            VentanasEnabled() and "ON" or "OFF", MaxMult())
        for i = 1, #VENTANAS_FRAMES do
            local name = VENTANAS_FRAMES[i]
            local f = _G[name]
            if f and f.GetName then
                local managed = IsManaged(f)
                local shown = (f.IsShown and f:IsShown()) or false
                local base = FrameBase(f)
                local cur = (f.GetScale and f:GetScale()) or 0
                local eff = (f.GetEffectiveScale and f:GetEffectiveScale()) or 0
                local w = (f.GetWidth and f:GetWidth()) or 0
                local h = (f.GetHeight and f:GetHeight()) or 0
                local ex = TabExtraUnits(f)
                local okp, p, rel, rp, x, y = pcall(f.GetPoint, f, 1)
                local fit = shown and FitScale(f) or nil
                local des = nil
                if fit and cur > 0 and eff > 0 then
                    des = fit / (eff / cur)
                    local maxAbs = base * MaxMult()
                    local minAbs = base * MIN_SHRINK
                    if des > maxAbs then des = maxAbs end
                    if des < minAbs then des = minAbs end
                end
                local rect = "nil"
                if shown and f.GetTop and f:GetTop() and f.GetBottom() then
                    rect = string.format("L%.0f R%.0f B%.0f T%.0f",
                        (f:GetLeft() or 0) * eff, (f:GetRight() or 0) * eff,
                        (f:GetBottom() or 0) * eff, (f:GetTop() or 0) * eff)
                end
                out[#out + 1] = string.format(
                    "%s%s esc=%.3f base=%.3f eff=%.3f tam=%.0fx%.0f pest=%.0f fit=%s des=%s ancla=%s/%s %s,%s rect=%s",
                    name, managed and "" or " (hereda)", cur, base, eff, w, h, ex,
                    fit and string.format("%.3f", fit) or "nil",
                    des and string.format("%.3f", des) or "nil",
                    okp and tostring(p) or "ERR", tostring(rp),
                    tostring(x), tostring(y), rect)
            end
        end
        for _, line in ipairs(out) do Print(line) end
        if type(CaprimedinaUIDB) == "table" then
            CaprimedinaUIDB.ventanasDump = table.concat(out, "\n")
            CaprimedinaUIDB.ventanasDumpStamp = date("%Y-%m-%d %H:%M:%S")
        end
        Print("Dump guardado en SavedVariables. Haz /reload para escribirlo.")
        return
    end

    if cmd == "reset" then
        CaprimedinaUIDB.ventanasScale = DEFAULT_MAX
        CaprimedinaUIDB.enableVentanas = true
        ApplyAll()
        Print("Ventanas reiniciadas (auto, max " .. MaxMult() .. "x)")
        return
    end

    if cmd == "on" then
        CaprimedinaUIDB.enableVentanas = true
    elseif cmd == "off" then
        CaprimedinaUIDB.enableVentanas = false
    else
        CaprimedinaUIDB.enableVentanas = not CaprimedinaUIDB.enableVentanas
    end

    if CaprimedinaUIDB.enableVentanas then
        ApplyAll()
        Print("Ventanas: |cff00ff00ON|r (auto, max " .. MaxMult() .. "x)")
    else
        ResetAll()
        Print("Ventanas: |cffff0000OFF|r")
    end
end
