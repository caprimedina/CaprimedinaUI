local _G = _G or getfenv(0)
local C = _G.CapriUI


CapriHighlightRegistry = {}

local KEYRING_ID = -2
local mainBagsList = { 0, 1, 2, 3, 4 }
local bankBagsList = { 5, 6, 7, 8, 9, 10, 11 }

local currentScale = 1.0
local currentCols = 10
local showBagTitles = true
local isBagLocked = false
local showSideBags = true
local keyringPage = false
local KR_MAX = 32
local btnKeyring

local bankScale = 1.0
local bankCols = 10
local showBankTitles = true
local isBankLocked = false
local showBankSideBags = true

local updatePending = false
local updateTimer = 0
local currentBagStrata = "HIGH"

local orig_OpenAllBags = OpenAllBags
local orig_CloseAllBags = CloseAllBags
local orig_ToggleBackpack = ToggleBackpack
local orig_ToggleBag = ToggleBag
local orig_updateContainerFrameAnchors = updateContainerFrameAnchors
local orig_OpenBackpack = OpenBackpack
local orig_CloseBackpack = CloseBackpack

local RaiseBagWindow
local RaiseBankWindow

local function BagsEnabled()
    return not (CaprimedinaUIDB and CaprimedinaUIDB.enableBags == false)
end

local function FixPopupStrata(frameName)
    local f = _G[frameName]
    if f then
        f:HookScript("OnShow", function(self)
            self:SetFrameStrata("FULLSCREEN_DIALOG")
            self:SetFrameLevel(150)
        end)
    end
end

FixPopupStrata("CoinPickupFrame")
FixPopupStrata("StackSplitFrame")
FixPopupStrata("LootFrame")

-- ======================================================================
-- Utilidades de piel "bolsa de cuero", compartidas por la mochila y el banco.
-- Los bordes se dibujan a mano (4 esquinas fijas + 4 lados estirados) porque
-- el cliente 3.3.5 parte los edgeFile de SetBackdrop en 8 tiras.
-- ======================================================================
local BAG_MEDIA = C.media

local function CrearTextura(parent, capa, archivo)
    local t = parent:CreateTexture(nil, capa)
    t:SetTexture(BAG_MEDIA .. archivo)
    return t
end

local function CrearDegradado(parent, capa, vertical, r1, g1, b1, a1, r2, g2, b2, a2)
    -- Rampa pregrabada: el cliente 3.3.5 no tiene un SetGradientAlpha fiable y
    -- podia tenirlo de azul. La textura ya trae el alfa; el color va por vertice.
    local t = parent:CreateTexture(nil, capa)
    t:SetTexture(BAG_MEDIA .. (vertical and "degradado_v" or "degradado_h"))
    t:SetVertexColor((r1 + r2) * 0.5, (g1 + g2) * 0.5, (b1 + b2) * 0.5, math.max(a1, a2))
    if a1 < a2 then
        if vertical then
            t:SetTexCoord(0, 1, 1, 0)
        else
            t:SetTexCoord(1, 0, 0, 1)
        end
    end
    return t
end

local function CrearBorde9(parent, textura, tamTex, esquina, capa)
    local c = esquina / tamTex
    local px = 1 / tamTex
    local b = {}
    local function nueva(l, r, t, abajo)
        local x = parent:CreateTexture(nil, capa or "BORDER")
        x:SetTexture(textura)
        x:SetTexCoord(l, r, t, abajo)
        b[#b + 1] = x
        return x
    end
    b.tl = nueva(0, c, 0, c)
    b.tr = nueva(1 - c, 1, 0, c)
    b.bl = nueva(0, c, 1 - c, 1)
    b.br = nueva(1 - c, 1, 1 - c, 1)
    b.izq = nueva(0, c, 0.5, 0.5 + px)
    b.der = nueva(1 - c, 1, 0.5, 0.5 + px)
    b.sup = nueva(0.5, 0.5 + px, 0, c)
    b.inf = nueva(0.5, 0.5 + px, 1 - c, 1)
    return b
end

local function ColocarBorde9(b, w, h, e)
    if not b then return end
    b.tl:ClearAllPoints(); b.tl:SetPoint("TOPLEFT", 0, 0); b.tl:SetSize(e, e)
    b.tr:ClearAllPoints(); b.tr:SetPoint("TOPRIGHT", 0, 0); b.tr:SetSize(e, e)
    b.bl:ClearAllPoints(); b.bl:SetPoint("BOTTOMLEFT", 0, 0); b.bl:SetSize(e, e)
    b.br:ClearAllPoints(); b.br:SetPoint("BOTTOMRIGHT", 0, 0); b.br:SetSize(e, e)
    b.sup:ClearAllPoints(); b.sup:SetPoint("TOPLEFT", e, 0); b.sup:SetPoint("TOPRIGHT", -e, 0); b.sup:SetHeight(e)
    b.inf:ClearAllPoints(); b.inf:SetPoint("BOTTOMLEFT", e, 0); b.inf:SetPoint("BOTTOMRIGHT", -e, 0); b.inf:SetHeight(e)
    b.izq:ClearAllPoints(); b.izq:SetPoint("TOPLEFT", 0, -e); b.izq:SetPoint("BOTTOMLEFT", 0, e); b.izq:SetWidth(e)
    b.der:ClearAllPoints(); b.der:SetPoint("TOPRIGHT", 0, -e); b.der:SetPoint("BOTTOMRIGHT", 0, e); b.der:SetWidth(e)
end

local function StyleLeatherButton(btn)
    if not btn then return end
    btn.defaultColor = { 0.16, 0.11, 0.07, 0.92 }
    btn:SetBackdropColor(0.16, 0.11, 0.07, 0.92)
    if btn.text then btn.text:SetTextColor(1, 0.86, 0.48) end
    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.28, 0.19, 0.11, 0.95) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(self.defaultColor)) end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(0.42, 0.30, 0.17, 1) end)
    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(0.28, 0.19, 0.11, 0.95)
        else
            self:SetBackdropColor(unpack(self.defaultColor))
        end
    end)
end


local frame = CreateFrame("Frame", "UnifiedBagFrame", UIParent)
tinsert(UISpecialFrames, "UnifiedBagFrame")
frame:SetPoint("CENTER", 100, 0)
frame:SetFrameStrata("HIGH")
frame:SetFrameLevel(10)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self)
    _G.CapriUIState.dragging = true
    _G.CapriUIState.dragOwner = "bag"

    if RaiseBagWindow then
        RaiseBagWindow()
    end

    if not isBagLocked then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    if _G.CapriUIState and _G.CapriUIState.dragOwner == "bag" then
        _G.CapriUIState.dragging = false
        _G.CapriUIState.dragOwner = nil
    end

    if CaprimedinaUIDB then
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        CaprimedinaUIDB.bagPos = { p = point, rp = relativePoint, x = xOfs, y = yOfs }
    end

    if RaiseBagWindow then
        RaiseBagWindow()
    end
end)

frame:SetScript("OnHide", function()
    -- Al cerrar la mochila se cierra tambien la pagina del llavero.
    keyringPage = false
    if CaprimedinaUIDB then CaprimedinaUIDB.showKeyringPage = false end
    for i = 0, 4 do
        CloseBag(i)
    end

    local isKeyringOpen = false

    for i = 1, 15 do
        local f = _G["ContainerFrame" .. i]

        if f and f:IsVisible() and f:GetID() == KEYRING_ID then
            isKeyringOpen = true
            break
        end
    end

    if isKeyringOpen and ToggleKeyRing then
        ToggleKeyRing()
    end
end)

frame:Hide()



local pdWidth = 220
local pdHeight = 310

-- ======================================================================
-- Piel de "bolsa grande" para la mochila.
-- Mismo cuero, solapa, asa y costuras que el banco; la ventana de vestuario
-- y los paneles de profesion quedan enmarcados dentro de la bolsa.
-- ======================================================================
local BAG_FLAP_TOP = 0
local BAG_FLAP_H = 62
local BAG_SIDE_PAD = 30
local BAG_BOTTOM_PAD = 56

local bagArt = { costuras = {}, costurasFlap = {}, costuraSeam = {} }

frame:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_cuerpo",
    tile     = true,
    tileSize = 128,
})
frame:SetBackdropColor(1, 1, 1, 1)
local bagBorde = CrearBorde9(frame, BAG_MEDIA .. "bolsa_borde", 128, 32)

bagArt.luz = CrearTextura(frame, "ARTWORK", "bolsa_luz")
bagArt.luzSup = CrearDegradado(frame, "ARTWORK", true, 1, 0.93, 0.76, 0.08, 1, 0.93, 0.76, 0)
bagArt.sombraInf = CrearDegradado(frame, "ARTWORK", true, 0, 0, 0, 0, 0, 0, 0, 0.34)
bagArt.sombraIzq = CrearDegradado(frame, "ARTWORK", false, 0, 0, 0, 0.30, 0, 0, 0, 0)
bagArt.sombraDer = CrearDegradado(frame, "ARTWORK", false, 0, 0, 0, 0, 0, 0, 0, 0.30)
bagArt.sombraSolapa = CrearDegradado(frame, "ARTWORK", true, 0, 0, 0, 0.62, 0, 0, 0, 0)
bagArt.asa = CrearTextura(frame, "ARTWORK", "bolsa_asa")

bagArt.remacheIzq = CrearTextura(frame, "OVERLAY", "remache")
bagArt.remacheIzq:SetSize(16, 16)
bagArt.remacheDer = CrearTextura(frame, "OVERLAY", "remache")
bagArt.remacheDer:SetSize(16, 16)

-- Solapa con el titulo.
local bagFlap = CreateFrame("Frame", "UnifiedBagFlap", frame)
bagFlap:SetFrameStrata(frame:GetFrameStrata())
bagFlap:SetFrameLevel(frame:GetFrameLevel() + 2)
bagFlap:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_solapa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bagFlap:SetBackdropColor(1, 1, 1, 1)
local flapBorde = CrearBorde9(bagFlap, BAG_MEDIA .. "bolsa_solapa_borde", 64, 16)

local title = bagFlap:CreateFontString("UnifiedBagTitle", "OVERLAY")
C.SetOutlineFont(title, 16)
title:SetPoint("TOP", bagFlap, "TOP", 0, -14)
title:SetTextColor(1, 0.88, 0.52)
title:SetShadowColor(0, 0, 0, 0.9)
title:SetShadowOffset(1, -1)
title:SetText("MOCHILA CAPRIMEDINA")

-- Hebilla de la solapa.
bagArt.hebilla = CrearTextura(bagFlap, "ARTWORK", "bolsa_hebilla")
bagArt.hebilla:SetPoint("BOTTOM", bagFlap, "BOTTOM", 0, -6)

-- Placa del dinero (abajo a la derecha, como un bolsillo cosido).
local bagMoneyPlaque = CreateFrame("Frame", "UnifiedBagMoneyPlaque", frame)
bagMoneyPlaque:SetFrameStrata(frame:GetFrameStrata())
bagMoneyPlaque:SetFrameLevel(frame:GetFrameLevel() + 3)
bagMoneyPlaque:SetSize(190, 34)
bagMoneyPlaque:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_solapa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bagMoneyPlaque:SetBackdropColor(0.95, 0.91, 0.86, 1)
local moneyBorde = CrearBorde9(bagMoneyPlaque, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)
ColocarBorde9(moneyBorde, 190, 34, 16)

-- Separador entre el vestuario y la rejilla de bolsas.
local dividerLine = frame:CreateTexture("UnifiedBagDivider", "ARTWORK")
dividerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
dividerLine:SetVertexColor(0.03, 0.02, 0.01, 0.75)
dividerLine:SetWidth(1)
dividerLine:Hide()

local function LayoutBagSkin()
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    if not w or not h or w < 80 or h < 80 then return end

    local flapH = BAG_FLAP_H
    local flapBottom = BAG_FLAP_TOP + flapH
    local flapW = w - 4

    bagFlap:ClearAllPoints()
    bagFlap:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -BAG_FLAP_TOP)
    bagFlap:SetSize(flapW, flapH)
    ColocarBorde9(bagBorde, w, h, 32)
    ColocarBorde9(flapBorde, flapW, flapH, 16)

    local tam = 16
    if w < 300 then
        tam = 13
    elseif w < 420 then
        tam = 15
    elseif w > 700 then
        tam = 18
    end
    C.SetOutlineFont(title, tam)
    if keyringPage then
        title:SetText("LLAVERO")
    else
        title:SetText(w < 330 and "MOCHILA" or "MOCHILA CAPRIMEDINA")
    end
    title:ClearAllPoints()
    title:SetPoint("TOP", bagFlap, "TOP", 0, -14)

    -- Asa: mantiene su forma y se apoya detras de la solapa.
    local asaW = math.floor(math.min(math.max(flapW * 0.55, 140), 300))
    local asaH = math.floor(asaW * 0.42)
    bagArt.asa:SetSize(asaW, asaH)
    bagArt.asa:ClearAllPoints()
    bagArt.asa:SetPoint("BOTTOM", frame, "TOP", 0, -(BAG_FLAP_TOP + 22))

    bagArt.sombraSolapa:ClearAllPoints()
    bagArt.sombraSolapa:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -(flapBottom + 1))
    bagArt.sombraSolapa:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -(flapBottom + 1))
    bagArt.sombraSolapa:SetHeight(18)

    local cuerpoSup = flapBottom + 4
    local cuerpoInf = 30
    local pad = BAG_SIDE_PAD - 4

    bagArt.luzSup:ClearAllPoints()
    bagArt.luzSup:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(cuerpoSup + 2))
    bagArt.luzSup:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -(cuerpoSup + 2))
    bagArt.luzSup:SetHeight(80)

    bagArt.luz:ClearAllPoints()
    bagArt.luz:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(cuerpoSup + 4))
    bagArt.luz:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, cuerpoInf + 22)

    bagArt.sombraInf:ClearAllPoints()
    bagArt.sombraInf:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, cuerpoInf)
    bagArt.sombraInf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, cuerpoInf)
    bagArt.sombraInf:SetHeight(110)

    bagArt.sombraIzq:ClearAllPoints()
    bagArt.sombraIzq:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(cuerpoSup + 2))
    bagArt.sombraIzq:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, cuerpoInf)
    bagArt.sombraIzq:SetWidth(30)

    bagArt.sombraDer:ClearAllPoints()
    bagArt.sombraDer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -(cuerpoSup + 2))
    bagArt.sombraDer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, cuerpoInf)
    bagArt.sombraDer:SetWidth(30)

    bagArt.remacheIzq:ClearAllPoints()
    bagArt.remacheIzq:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 28, 14)
    bagArt.remacheDer:ClearAllPoints()
    bagArt.remacheDer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 14)

    -- Costuras laterales del cuerpo.
    local paso = 16
    local yIni = cuerpoSup + 10
    local yFin = h - 30
    local cantidad = math.max(0, math.min(60, math.floor((yFin - yIni) / paso)))
    local total = cantidad * 2
    for i = 1, total do
        local t = bagArt.costuras[i]
        if not t then
            t = CrearTextura(frame, "OVERLAY", "puntada_v")
            t:SetVertexColor(1, 1, 1, 0.5)
            bagArt.costuras[i] = t
        end
        t:Show()
    end
    for i = total + 1, #bagArt.costuras do
        bagArt.costuras[i]:Hide()
    end
    for i = 1, cantidad do
        local y = -(yIni + (i - 1) * paso)
        local izq = bagArt.costuras[i]
        izq:ClearAllPoints()
        izq:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, y)
        local der = bagArt.costuras[cantidad + i]
        der:ClearAllPoints()
        der:SetPoint("TOPLEFT", frame, "TOPLEFT", w - 25, y)
    end

    -- Costuras de la solapa.
    local pasoFlap = 14
    local xIni = 22
    local xFin = flapW - 22
    local cantFlap = math.max(0, math.floor((xFin - xIni) / pasoFlap))
    for i = 1, cantFlap do
        local t = bagArt.costurasFlap[i]
        if not t then
            t = CrearTextura(bagFlap, "OVERLAY", "puntada")
            t:SetVertexColor(1, 1, 1, 0.9)
            bagArt.costurasFlap[i] = t
        end
        t:Show()
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", bagFlap, "BOTTOMLEFT", xIni + (i - 1) * pasoFlap, 11)
    end
    for i = cantFlap + 1, #bagArt.costurasFlap do
        bagArt.costurasFlap[i]:Hide()
    end

    -- Costura vertical entre el vestuario y la rejilla.
    local xSeam = BAG_SIDE_PAD + pdWidth + 12
    if showSideBags then
        dividerLine:Show()
        dividerLine:ClearAllPoints()
        dividerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", xSeam, -(flapBottom + 6))
        dividerLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", xSeam, 26)

        local ySeamIni = flapBottom + 14
        local ySeamFin = h - 34
        local cantSeam = math.max(0, math.min(60, math.floor((ySeamFin - ySeamIni) / paso)))
        for i = 1, cantSeam do
            local t = bagArt.costuraSeam[i]
            if not t then
                t = CrearTextura(frame, "OVERLAY", "puntada_v")
                t:SetVertexColor(1, 1, 1, 0.45)
                bagArt.costuraSeam[i] = t
            end
            t:Show()
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", frame, "TOPLEFT", xSeam - 4, -(ySeamIni + (i - 1) * paso))
        end
        for i = cantSeam + 1, #bagArt.costuraSeam do
            bagArt.costuraSeam[i]:Hide()
        end
    else
        dividerLine:Hide()
        for i = 1, #bagArt.costuraSeam do
            bagArt.costuraSeam[i]:Hide()
        end
    end

    -- Hebilla.
    bagArt.hebilla:SetSize(40, 20)
    bagArt.hebilla:ClearAllPoints()
    bagArt.hebilla:SetPoint("BOTTOM", bagFlap, "BOTTOM", 0, -7)

    -- Placa del dinero.
    bagMoneyPlaque:ClearAllPoints()
    bagMoneyPlaque:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 14)
end

UnifiedPaperDollPanel = CreateFrame("Frame", "UnifiedPaperDollPanel", frame)
UnifiedPaperDollPanel:SetWidth(pdWidth)
UnifiedPaperDollPanel:SetHeight(pdHeight)
UnifiedPaperDollPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = false,
})
UnifiedPaperDollPanel:SetBackdropColor(0.015, 0.012, 0.01, 0.9)
UnifiedPaperDollPanel:Hide()

local pdPadding = 14
local innerW = pdWidth - (pdPadding * 2)
local innerH = pdHeight - (pdPadding * 2)


local bgTL = UnifiedPaperDollPanel:CreateTexture("UnifiedPaperDollBgTL", "BORDER")
bgTL:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "TOPLEFT", pdPadding, -pdPadding)
bgTL:SetWidth(innerW * (256/384))
bgTL:SetHeight(innerH * 0.65)

local bgTR = UnifiedPaperDollPanel:CreateTexture("UnifiedPaperDollBgTR", "BORDER")
bgTR:SetPoint("TOPLEFT", bgTL, "TOPRIGHT")
bgTR:SetWidth(innerW * (128/384))
bgTR:SetHeight(innerH * 0.65)

local bgBL = UnifiedPaperDollPanel:CreateTexture("UnifiedPaperDollBgBL", "BORDER")
bgBL:SetPoint("TOPLEFT", bgTL, "BOTTOMLEFT")
bgBL:SetWidth(innerW * (256/384))
bgBL:SetHeight(innerH * 0.35)
bgBL:SetTexCoord(0, 1, 0, 0.6)

local bgBR = UnifiedPaperDollPanel:CreateTexture("UnifiedPaperDollBgBR", "BORDER")
bgBR:SetPoint("TOPLEFT", bgTL, "BOTTOMRIGHT")
bgBR:SetWidth(innerW * (128/384))
bgBR:SetHeight(innerH * 0.35)
bgBR:SetTexCoord(0, 1, 0, 0.6)

-- Marco de cuero del ventanal de vestuario.
local pdBorde = CrearBorde9(UnifiedPaperDollPanel, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)
ColocarBorde9(pdBorde, pdWidth, pdHeight, 16)

local pdRivetes = {}
for _, punto in ipairs({ {"TOPLEFT", 5, -5}, {"TOPRIGHT", -15, -5}, {"BOTTOMLEFT", 5, 5}, {"BOTTOMRIGHT", -15, 5} }) do
    local r = CrearTextura(UnifiedPaperDollPanel, "OVERLAY", "remache")
    r:SetSize(10, 10)
    r:SetPoint(punto[1], UnifiedPaperDollPanel, punto[1], punto[2], punto[3])
    pdRivetes[#pdRivetes + 1] = r
end

local function UpdatePaperDollClassBackground()
    if not UnifiedPaperDollPanel then return end
    local _, raceEn = UnitRace("player")
    if raceEn then
        local basePath = "Interface\\DressUpFrame\\DressUpBackground-" .. raceEn
        bgTL:SetTexture(basePath .. "1")
        bgTR:SetTexture(basePath .. "2")
        bgBL:SetTexture(basePath .. "3")
        bgBR:SetTexture(basePath .. "4")
        bgTL:Show()
        bgTR:Show()
        bgBL:Show()
        bgBR:Show()
    else
        bgTL:Hide()
        bgTR:Hide()
        bgBL:Hide()
        bgBR:Hide()
    end
end

UnifiedPaperDollModel = CreateFrame("PlayerModel", "UnifiedPaperDollModel", UnifiedPaperDollPanel)
UnifiedPaperDollModel:SetFrameLevel(UnifiedPaperDollPanel:GetFrameLevel() + 1)
UnifiedPaperDollModel:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "TOPLEFT", 48, -18)
UnifiedPaperDollModel:SetPoint("BOTTOMRIGHT", UnifiedPaperDollPanel, "BOTTOMRIGHT", -48, 26)
UnifiedPaperDollModel:SetUnit("player")
UnifiedPaperDollModel:SetRotation(0)
UnifiedPaperDollModel:EnableMouse(true)
UnifiedPaperDollModel:SetBackdrop(nil)

UnifiedPaperDollModel:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self.isDragging = true
        self.startX = GetCursorPosition()
        self.startRot = self:GetFacing()
    end
end)

UnifiedPaperDollModel:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self.isDragging = false
    end
end)

UnifiedPaperDollModel:SetScript("OnUpdate", function(self)
    if self.isDragging then
        local x = GetCursorPosition()
        self:SetFacing(self.startRot + (x - self.startX) / 50)
    end
end)

UnifiedPaperDollPanel:SetScript("OnShow", function()
    UpdatePaperDollClassBackground()
    local currentRot = UnifiedPaperDollModel:GetFacing() or 0
    UnifiedPaperDollModel:ClearModel()
    UnifiedPaperDollModel:SetUnit("player")
    UnifiedPaperDollModel:SetFacing(currentRot)
    UnifiedPaperDollModel:SetLight(1, 0, 0, 0, 0, 1.0, 1.0, 1.0, 1.0, 1.0)
end)

UnifiedPaperDollPanel:RegisterEvent("UNIT_MODEL_CHANGED")
UnifiedPaperDollPanel:SetScript("OnEvent", function(self, event, unit)
    if unit == "player" then
        UnifiedPaperDollModel:SetUnit("player")
    end
end)

UpdatePaperDollClassBackground()

local equipSlots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

local pdSlotSize = 32
local pdSpacing = 4

for i, slotName in ipairs(equipSlots) do
    local slotId, emptyTexture = GetInventorySlotInfo(slotName)

    local btn = CreateFrame("Button", "CapriPDSlot" .. slotId, UnifiedPaperDollPanel)
    btn:SetFrameLevel(UnifiedPaperDollPanel:GetFrameLevel() + 3)
    btn:SetWidth(pdSlotSize)
    btn:SetHeight(pdSlotSize)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(emptyTexture)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetWidth(pdSlotSize * 1.6)
    border:SetHeight(pdSlotSize * 1.6)
    border:SetPoint("CENTER", 0, 0)

    
    local rBorder = btn:CreateTexture(nil, "OVERLAY")
    rBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    rBorder:SetBlendMode("ADD")
    rBorder:SetWidth(pdSlotSize * 1.8)
    rBorder:SetHeight(pdSlotSize * 1.8)
    rBorder:SetPoint("CENTER", 0, 0)
    rBorder:Hide()
    btn.rarityBorder = rBorder

    local durText = btn:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(durText, 10)
    durText:SetPoint("BOTTOM", btn, "BOTTOM", 0, -4)
    btn.durability = durText

    if i <= 8 then
        btn:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "TOPLEFT", 16, -16 - (i - 1) * (pdSlotSize + pdSpacing))
    elseif i <= 16 then
        btn:SetPoint("TOPRIGHT", UnifiedPaperDollPanel, "TOPRIGHT", -16, -16 - (i - 9) * (pdSlotSize + pdSpacing))
    else
        local bottomIndex = i - 16
        btn:SetPoint("BOTTOMLEFT", UnifiedPaperDollPanel, "BOTTOMLEFT", 60 + (bottomIndex - 1) * (pdSlotSize + pdSpacing), 16)
    end

    btn:RegisterEvent("UNIT_INVENTORY_CHANGED")
    btn:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

    btn:SetScript("OnEvent", function(self, event, unit)
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        self:Update()
    end)

    btn.Update = function(self)
        local texture = GetInventoryItemTexture("player", slotId)
        if texture then
            self.icon:SetTexture(texture)
            self.icon:Show()

            local quality = GetInventoryItemQuality("player", slotId)
            if quality and quality > 1 then 
                local r, g, b = GetItemQualityColor(quality)
                self.rarityBorder:SetVertexColor(r, g, b, 1)
                self.rarityBorder:Show()
            else
                self.rarityBorder:Hide()
            end

            local v1, v2 = GetInventoryItemDurability(slotId)
            if v1 and v2 and v2 > 0 then
                local pct = math.floor((v1 / v2) * 100)
                self.durability:SetText(v1 .. "/" .. v2)

                if pct > 50 then self.durability:SetTextColor(0, 1, 0)
                elseif pct > 20 then self.durability:SetTextColor(1, 1, 0)
                else self.durability:SetTextColor(1, 0, 0) end
            else
                self.durability:SetText("")
            end
        else
            self.icon:Hide()
            self.durability:SetText("")
            self.rarityBorder:Hide()
        end
    end

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then UseInventoryItem(slotId)
        else PickupInventoryItem(slotId) end
    end)

    btn:SetScript("OnReceiveDrag", function() PickupInventoryItem(slotId) end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local hasItem = GameTooltip:SetInventoryItem("player", slotId)
        if not hasItem then GameTooltip:SetText(_G[string.upper(slotName)] or slotName) end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Update()
end

local bagSlotPanel = CreateFrame("Frame", "UnifiedBagSlotPanel", frame)
bagSlotPanel:SetWidth(pdWidth)
bagSlotPanel:SetHeight(52)
bagSlotPanel:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bagSlotPanel:SetBackdropColor(0.92, 0.88, 0.84, 1)
bagSlotPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
local bagSlotBorde = CrearBorde9(bagSlotPanel, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)
ColocarBorde9(bagSlotBorde, pdWidth, 52, 16)

UnifiedProfSlots = {}

UnifiedProfMainPanel = CreateFrame("Frame", "UnifiedProfMainPanel", frame)
UnifiedProfMainPanel:SetWidth(pdWidth)
UnifiedProfMainPanel:SetHeight(100)
UnifiedProfMainPanel:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_solapa_cuerpo",
    tile     = true,
    tileSize = 128,
})
UnifiedProfMainPanel:SetBackdropColor(0.96, 0.92, 0.88, 1)
UnifiedProfMainPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
local profMainBorde = CrearBorde9(UnifiedProfMainPanel, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)
ColocarBorde9(profMainBorde, pdWidth, 100, 16)
UnifiedProfMainPanel:Hide()

local headerMain = UnifiedProfMainPanel:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(headerMain, 12)
headerMain:SetPoint("TOPLEFT", UnifiedProfMainPanel, "TOPLEFT", 16, -13)
headerMain:SetText("Principales")
headerMain:SetTextColor(1, 0.84, 0.34)

UnifiedProfSecPanel = CreateFrame("Frame", "UnifiedProfSecPanel", frame)
UnifiedProfSecPanel:SetWidth(pdWidth)
UnifiedProfSecPanel:SetHeight(130)
UnifiedProfSecPanel:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_solapa_cuerpo",
    tile     = true,
    tileSize = 128,
})
UnifiedProfSecPanel:SetBackdropColor(0.96, 0.92, 0.88, 1)
UnifiedProfSecPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
local profSecBorde = CrearBorde9(UnifiedProfSecPanel, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)
ColocarBorde9(profSecBorde, pdWidth, 130, 16)
UnifiedProfSecPanel:Hide()

local headerSec = UnifiedProfSecPanel:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(headerSec, 12)
headerSec:SetPoint("TOPLEFT", UnifiedProfSecPanel, "TOPLEFT", 16, -13)
headerSec:SetText("Secundarias")
headerSec:SetTextColor(1, 0.84, 0.34)

local function CreateProfSlot(parent, index, yOffset)
    local pBtn = CreateFrame("Button", nil, parent)
    pBtn:SetWidth(pdWidth - 32)
    pBtn:SetHeight(24)
    pBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)

    local hl = pBtn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    hl:SetAlpha(0.5)

    local icon = pBtn:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("LEFT", pBtn, "LEFT", 4, 0)

    local text = pBtn:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(text, 11)
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)

    pBtn:SetScript("OnClick", function(self)
        if self.skillName then
            local spellToCast = self.skillName
            if spellToCast == "Minería" then spellToCast = "Fundición" end
            if spellToCast == "Mining" then spellToCast = "Smelting" end
            CastSpellByName(spellToCast)
        end
    end)

    UnifiedProfSlots[index] = { btn = pBtn, icon = icon, text = text }
end

CreateProfSlot(UnifiedProfMainPanel, 1, -32)
CreateProfSlot(UnifiedProfMainPanel, 2, -60)
CreateProfSlot(UnifiedProfSecPanel, 3, -32)
CreateProfSlot(UnifiedProfSecPanel, 4, -60)
CreateProfSlot(UnifiedProfSecPanel, 5, -88)

-- Costura bajo el titulo de cada panel de profesion.
local function CrearCosturaHorizontal(panel, y)
    local surco = panel:CreateTexture(nil, "ARTWORK")
    surco:SetTexture("Interface\\Buttons\\WHITE8X8")
    surco:SetVertexColor(0.05, 0.03, 0.02, 0.8)
    surco:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    surco:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y)
    surco:SetHeight(1)

    local brillo = panel:CreateTexture(nil, "ARTWORK")
    brillo:SetTexture("Interface\\Buttons\\WHITE8X8")
    brillo:SetVertexColor(0.85, 0.7, 0.4, 0.22)
    brillo:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y - 1)
    brillo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y - 1)
    brillo:SetHeight(1)
end

CrearCosturaHorizontal(UnifiedProfMainPanel, -28)
CrearCosturaHorizontal(UnifiedProfSecPanel, -28)

local function UpdateProfSlots()
    local primaries = {}
    local fa, cook, fish = nil, nil, nil

    for i = 1, GetNumSkillLines() do
        local skillName, header, _, skillRank, _, _, skillMaxRank, isAbandonable = GetSkillLineInfo(i)
        if not header then
            if isAbandonable then
                table.insert(primaries, { name = skillName, rank = skillRank, max = skillMaxRank })
            elseif skillName == "First Aid" or skillName == "Primeros auxilios" then
                fa = { name = skillName, rank = skillRank, max = skillMaxRank }
            elseif skillName == "Cooking" or skillName == "Cocina" then
                cook = { name = skillName, rank = skillRank, max = skillMaxRank }
            elseif skillName == "Fishing" or skillName == "Pesca" then
                fish = { name = skillName, rank = skillRank, max = skillMaxRank }
            end
        end
    end

    local function ApplyProfData(slotIndex, data, defaultName, defaultIcon)
        local slot = UnifiedProfSlots[slotIndex]
        if data then
            local _, _, spellIcon = GetSpellInfo(data.name)
            slot.btn.skillName = data.name
            slot.icon:SetTexture(spellIcon or defaultIcon)
            slot.text:SetText(data.name .. " " .. data.rank .. "/" .. data.max)
            slot.text:SetTextColor(0, 1, 0)
            if slot.icon.SetDesaturated then slot.icon:SetDesaturated(false) end
            
            if data.name == "Pesca" or data.name == "Fishing" then
                slot.btn:EnableMouse(false)
            else
                slot.btn:EnableMouse(true)
            end
        else
            slot.btn.skillName = nil
            slot.icon:SetTexture(defaultIcon)
            slot.text:SetText(defaultName .. " (Faltante)")
            slot.text:SetTextColor(0.5, 0.5, 0.5)
            if slot.icon.SetDesaturated then slot.icon:SetDesaturated(true) end
            
            slot.btn:EnableMouse(false)
        end
    end

    ApplyProfData(1, primaries[1], "Profesión 1", "Interface\\Icons\\INV_Scroll_03")
    ApplyProfData(2, primaries[2], "Profesión 2", "Interface\\Icons\\INV_Scroll_03")
    ApplyProfData(3, fa, "Primeros Aux.", "Interface\\Icons\\Spell_Holy_SealOfSacrifice")
    ApplyProfData(4, cook, "Cocina", "Interface\\Icons\\INV_Misc_Food_15")
    ApplyProfData(5, fish, "Pesca", "Interface\\Icons\\Trade_Fishing")
end

UnifiedProfMainPanel:RegisterEvent("SKILL_LINES_CHANGED")
UnifiedProfMainPanel:SetScript("OnEvent", function()
    if UnifiedProfMainPanel:IsVisible() then UpdateProfSlots() end
end)

local btnToggleSideBags = C.CreateStyledButton(frame, "<", 22, 22)
btnToggleSideBags:SetPoint("TOPLEFT", 12, -10)
btnToggleSideBags:SetFrameLevel(frame:GetFrameLevel() + 4)
StyleLeatherButton(btnToggleSideBags)

local moneyFrame = CreateFrame("Frame", "UnifiedBagMoneyFrame", bagMoneyPlaque, "SmallMoneyFrameTemplate")
moneyFrame:SetFrameLevel(bagMoneyPlaque:GetFrameLevel() + 2)
moneyFrame:SetPoint("CENTER", bagMoneyPlaque, "CENTER", 0, 0)

local bankFrame = CreateFrame("Frame", "UnifiedBankFrame", UIParent)
tinsert(UISpecialFrames, "UnifiedBankFrame")
bankFrame:SetPoint("CENTER", -200, 0)
C.StyleWindow(bankFrame)
bankFrame:SetFrameStrata("HIGH")
bankFrame:SetFrameLevel(30)
bankFrame:EnableMouse(true)
bankFrame:SetMovable(true)
bankFrame:RegisterForDrag("LeftButton")

bankFrame:SetScript("OnDragStart", function(self)
    _G.CapriUIState.dragging = true
    _G.CapriUIState.dragOwner = "bank"
    if RaiseBankWindow then RaiseBankWindow() end
    if not isBankLocked then self:StartMoving() end
end)

bankFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if _G.CapriUIState and _G.CapriUIState.dragOwner == "bank" then
        _G.CapriUIState.dragging = false
        _G.CapriUIState.dragOwner = nil
    end
    if CaprimedinaUIDB then
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        CaprimedinaUIDB.bankPos = { p = point, rp = relativePoint, x = xOfs, y = yOfs }
    end
    if RaiseBankWindow then RaiseBankWindow() end
end)

bankFrame:SetScript("OnHide", function() CloseBankFrame() end)
bankFrame:Hide()

-- ======================================================================
-- Piel de "bolsa grande" para el banco.
-- Todas las texturas son propias y viven en texturas\bolsa_*.tga.
-- El arte se recompone en LayoutBankSkin() cada vez que el marco cambia de
-- tamano: asi la bolsa respeta el crecimiento en columnas/filas y la escala
-- del banco sin deformar las esquinas ni el asa.
-- ======================================================================
local BANK_FLAP_TOP = 0
local BANK_FLAP_H = 62
local BANK_SIDE_PAD = 30
local BANK_BOTTOM_PAD = 56

local bankArt = { costuras = {}, costurasFlap = {} }

-- Bolsillo lateral para las bolsas del banco (cuelga del lado izquierdo).
local bankSlotPanel = CreateFrame("Frame", "UnifiedBankSlotPanel", bankFrame)
bankSlotPanel:SetWidth(72)
bankSlotPanel:SetPoint("TOPRIGHT", bankFrame, "TOPLEFT", 10, -16)
bankSlotPanel:SetFrameStrata(bankFrame:GetFrameStrata())
bankSlotPanel:SetFrameLevel(bankFrame:GetFrameLevel() + 1)
bankSlotPanel:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bankSlotPanel:SetBackdropColor(0.90, 0.86, 0.82, 1)
local pocketBorde = CrearBorde9(bankSlotPanel, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)

local pocketLabel = bankSlotPanel:CreateFontString("UnifiedBankPocketLabel", "OVERLAY")
C.SetOutlineFont(pocketLabel, 11)
pocketLabel:SetPoint("TOP", bankSlotPanel, "TOP", 0, -13)
pocketLabel:SetText("BOLSAS")
pocketLabel:SetTextColor(1, 0.86, 0.46)

local pocketRivet = CrearTextura(bankSlotPanel, "OVERLAY", "remache")
pocketRivet:SetSize(12, 12)
pocketRivet:SetPoint("BOTTOM", bankSlotPanel, "BOTTOM", 0, 8)

local btnToggleBankSideBags = C.CreateStyledButton(bankFrame, "<", 22, 22)
btnToggleBankSideBags:SetPoint("TOPLEFT", 12, -10)
btnToggleBankSideBags:SetFrameLevel(bankFrame:GetFrameLevel() + 4)
StyleLeatherButton(btnToggleBankSideBags)

-- Cuerpo de la bolsa.
bankFrame:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bankFrame:SetBackdropColor(1, 1, 1, 1)
local bankBorde = CrearBorde9(bankFrame, BAG_MEDIA .. "bolsa_borde", 128, 32)

-- Volumen: luz central, sombra inferior y de los costados.
bankArt.luz = CrearTextura(bankFrame, "ARTWORK", "bolsa_luz")
bankArt.luzSup = CrearDegradado(bankFrame, "ARTWORK", true, 1, 0.93, 0.76, 0.08, 1, 0.93, 0.76, 0)
bankArt.sombraInf = CrearDegradado(bankFrame, "ARTWORK", true, 0, 0, 0, 0, 0, 0, 0, 0.34)
bankArt.sombraIzq = CrearDegradado(bankFrame, "ARTWORK", false, 0, 0, 0, 0.30, 0, 0, 0, 0)
bankArt.sombraDer = CrearDegradado(bankFrame, "ARTWORK", false, 0, 0, 0, 0, 0, 0, 0, 0.30)
bankArt.sombraSolapa = CrearDegradado(bankFrame, "ARTWORK", true, 0, 0, 0, 0.62, 0, 0, 0, 0)

-- Asa de cuerda: queda detras de la solapa.
bankArt.asa = CrearTextura(bankFrame, "ARTWORK", "bolsa_asa")

-- Remaches de las esquinas inferiores.
bankArt.remacheIzq = CrearTextura(bankFrame, "OVERLAY", "remache")
bankArt.remacheIzq:SetSize(16, 16)
bankArt.remacheDer = CrearTextura(bankFrame, "OVERLAY", "remache")
bankArt.remacheDer:SetSize(16, 16)

-- Solapa superior con el titulo.
local bankFlap = CreateFrame("Frame", "UnifiedBankFlap", bankFrame)
bankFlap:SetFrameStrata(bankFrame:GetFrameStrata())
bankFlap:SetFrameLevel(bankFrame:GetFrameLevel() + 2)
bankFlap:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_solapa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bankFlap:SetBackdropColor(1, 1, 1, 1)
local flapBorde = CrearBorde9(bankFlap, BAG_MEDIA .. "bolsa_solapa_borde", 64, 16)

local bankTitle = bankFlap:CreateFontString("UnifiedBankTitle", "OVERLAY")
C.SetOutlineFont(bankTitle, 16)
bankTitle:SetPoint("TOP", bankFlap, "TOP", 0, -14)
bankTitle:SetTextColor(1, 0.88, 0.52)
bankTitle:SetShadowColor(0, 0, 0, 0.9)
bankTitle:SetShadowOffset(1, -1)
bankTitle:SetText("BANCO CAPRIMEDINA")

-- Hebilla de la solapa.
bankArt.hebilla = CrearTextura(bankFlap, "ARTWORK", "bolsa_hebilla")
bankArt.hebilla:SetPoint("BOTTOM", bankFlap, "BOTTOM", 0, -6)

-- Placa inferior para comprar ranuras.
local bankPlaque = CreateFrame("Frame", "UnifiedBankPlaque", bankFrame)
bankPlaque:SetFrameStrata(bankFrame:GetFrameStrata())
bankPlaque:SetFrameLevel(bankFrame:GetFrameLevel() + 3)
bankPlaque:SetBackdrop({
    bgFile   = BAG_MEDIA .. "bolsa_solapa_cuerpo",
    tile     = true,
    tileSize = 128,
})
bankPlaque:SetBackdropColor(0.95, 0.91, 0.86, 1)
local plaqueBorde = CrearBorde9(bankPlaque, BAG_MEDIA .. "bolsa_borde_peq", 64, 16)

-- Costo de las ranuras con el mismo formato de monedas que la mochila.
local bankCostMoney = CreateFrame("Frame", "UnifiedBankCostMoney", bankPlaque, "SmallMoneyFrameTemplate")
bankCostMoney:SetFrameStrata(bankFrame:GetFrameStrata())
bankCostMoney:SetFrameLevel(bankPlaque:GetFrameLevel() + 2)
bankCostMoney:Hide()

-- Recompone todo el arte segun el tamano actual del marco.
local function LayoutBankSkin()
    local w = bankFrame:GetWidth()
    local h = bankFrame:GetHeight()
    if not w or not h or w < 60 or h < 60 then return end

    local flapH = BANK_FLAP_H
    local flapBottom = BANK_FLAP_TOP + flapH
    local flapW = w - 4

    bankFlap:ClearAllPoints()
    bankFlap:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 2, -BANK_FLAP_TOP)
    bankFlap:SetSize(flapW, flapH)
    ColocarBorde9(bankBorde, w, h, 32)
    ColocarBorde9(flapBorde, flapW, flapH, 16)

    local tamTitulo = 16
    if w < 260 then
        tamTitulo = 13
    elseif w < 380 then
        tamTitulo = 15
    elseif w > 620 then
        tamTitulo = 18
    end
    C.SetOutlineFont(bankTitle, tamTitulo)
    bankTitle:SetText(w < 300 and "BANCO" or "BANCO CAPRIMEDINA")
    bankTitle:ClearAllPoints()
    bankTitle:SetPoint("TOP", bankFlap, "TOP", 0, -14)

    -- Asa: mantiene su forma 2:1 y se apoya detras de la solapa.
    local asaW = math.floor(math.min(math.max(flapW * 0.60, 150), 320))
    local asaH = math.floor(asaW * 0.42)
    bankArt.asa:SetSize(asaW, asaH)
    bankArt.asa:ClearAllPoints()
    bankArt.asa:SetPoint("BOTTOM", bankFrame, "TOP", 0, -(BANK_FLAP_TOP + 22))

    -- Sombra que proyecta la solapa.
    bankArt.sombraSolapa:ClearAllPoints()
    bankArt.sombraSolapa:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 24, -(flapBottom + 1))
    bankArt.sombraSolapa:SetPoint("TOPRIGHT", bankFrame, "TOPRIGHT", -24, -(flapBottom + 1))
    bankArt.sombraSolapa:SetHeight(18)

    local cuerpoSup = flapBottom + 4
    local cuerpoInf = 34
    local pad = BANK_SIDE_PAD - 4

    bankArt.luzSup:ClearAllPoints()
    bankArt.luzSup:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", pad, -(cuerpoSup + 2))
    bankArt.luzSup:SetPoint("TOPRIGHT", bankFrame, "TOPRIGHT", -pad, -(cuerpoSup + 2))
    bankArt.luzSup:SetHeight(80)

    bankArt.luz:ClearAllPoints()
    bankArt.luz:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", pad, -(cuerpoSup + 4))
    bankArt.luz:SetPoint("BOTTOMRIGHT", bankFrame, "BOTTOMRIGHT", -pad, cuerpoInf + 22)

    bankArt.sombraInf:ClearAllPoints()
    bankArt.sombraInf:SetPoint("BOTTOMLEFT", bankFrame, "BOTTOMLEFT", pad, cuerpoInf)
    bankArt.sombraInf:SetPoint("BOTTOMRIGHT", bankFrame, "BOTTOMRIGHT", -pad, cuerpoInf)
    bankArt.sombraInf:SetHeight(110)

    bankArt.sombraIzq:ClearAllPoints()
    bankArt.sombraIzq:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", pad, -(cuerpoSup + 2))
    bankArt.sombraIzq:SetPoint("BOTTOMLEFT", bankFrame, "BOTTOMLEFT", pad, cuerpoInf)
    bankArt.sombraIzq:SetWidth(30)

    bankArt.sombraDer:ClearAllPoints()
    bankArt.sombraDer:SetPoint("TOPRIGHT", bankFrame, "TOPRIGHT", -pad, -(cuerpoSup + 2))
    bankArt.sombraDer:SetPoint("BOTTOMRIGHT", bankFrame, "BOTTOMRIGHT", -pad, cuerpoInf)
    bankArt.sombraDer:SetWidth(30)

    -- Remaches inferiores.
    bankArt.remacheIzq:ClearAllPoints()
    bankArt.remacheIzq:SetPoint("BOTTOMLEFT", bankFrame, "BOTTOMLEFT", 28, 14)
    bankArt.remacheDer:ClearAllPoints()
    bankArt.remacheDer:SetPoint("BOTTOMRIGHT", bankFrame, "BOTTOMRIGHT", -28, 14)

    -- Costuras verticales del cuerpo.
    local paso = 16
    local yIni = cuerpoSup + 10
    local yFin = h - 30
    local cantidad = math.max(0, math.min(60, math.floor((yFin - yIni) / paso)))
    local total = cantidad * 2
    for i = 1, total do
        local t = bankArt.costuras[i]
        if not t then
            t = CrearTextura(bankFrame, "OVERLAY", "puntada_v")
            t:SetVertexColor(1, 1, 1, 0.5)
            bankArt.costuras[i] = t
        end
        t:Show()
    end
    for i = total + 1, #bankArt.costuras do
        bankArt.costuras[i]:Hide()
    end
    for i = 1, cantidad do
        local y = -(yIni + (i - 1) * paso)
        local izq = bankArt.costuras[i]
        izq:ClearAllPoints()
        izq:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 17, y)
        local der = bankArt.costuras[cantidad + i]
        der:ClearAllPoints()
        der:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", w - 25, y)
    end

    -- Costuras de la solapa.
    local pasoFlap = 14
    local xIni = 22
    local xFin = flapW - 22
    local cantFlap = math.max(0, math.floor((xFin - xIni) / pasoFlap))
    for i = 1, cantFlap do
        local t = bankArt.costurasFlap[i]
        if not t then
            t = CrearTextura(bankFlap, "OVERLAY", "puntada")
            t:SetVertexColor(1, 1, 1, 0.9)
            bankArt.costurasFlap[i] = t
        end
        t:Show()
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", bankFlap, "BOTTOMLEFT", xIni + (i - 1) * pasoFlap, 11)
    end
    for i = cantFlap + 1, #bankArt.costurasFlap do
        bankArt.costurasFlap[i]:Hide()
    end

    -- Hebilla y placa de compra.
    bankArt.hebilla:SetSize(40, 20)
    bankArt.hebilla:ClearAllPoints()
    bankArt.hebilla:SetPoint("BOTTOM", bankFlap, "BOTTOM", 0, -7)

    local plW = math.floor(math.min(math.max(w * 0.62, 240), 380, w - 16))
    bankPlaque:ClearAllPoints()
    bankPlaque:SetPoint("BOTTOM", bankFrame, "BOTTOM", 0, 12)
    bankPlaque:SetSize(plW, 42)
    ColocarBorde9(plaqueBorde, plW, 42, 16)

    -- Bolsillo lateral.
    bankSlotPanel:ClearAllPoints()
    bankSlotPanel:SetPoint("TOPRIGHT", bankFrame, "TOPLEFT", 10, -16)
    bankSlotPanel:SetSize(72, 320)
    ColocarBorde9(pocketBorde, 72, 320, 16)
end       -- LayoutBankSkin()


local function SetBagStrata(strata)
    currentBagStrata = strata

    if frame then frame:SetFrameStrata(strata) end
    if bankFrame then bankFrame:SetFrameStrata(strata) end
    if bagSlotPanel then bagSlotPanel:SetFrameStrata(strata) end
    if bagFlap then bagFlap:SetFrameStrata(strata) end
    if bagMoneyPlaque then bagMoneyPlaque:SetFrameStrata(strata) end
    if bankCostMoney then bankCostMoney:SetFrameStrata(strata) end
    if bankSlotPanel then bankSlotPanel:SetFrameStrata(strata) end
    if bankFlap then bankFlap:SetFrameStrata(strata) end
    if bankPlaque then bankPlaque:SetFrameStrata(strata) end
    if UnifiedProfMainPanel then UnifiedProfMainPanel:SetFrameStrata(strata) end
    if UnifiedProfSecPanel then UnifiedProfSecPanel:SetFrameStrata(strata) end

    for _, list in pairs(CapriHighlightRegistry) do
        for _, b in ipairs(list) do
            if b then b:SetFrameStrata(strata) end
        end
    end

    for i = 0, 4 do
        local c = _G["UnifiedBagSideClone" .. i]
        if c then c:SetFrameStrata(strata) end
    end

    for i = 1, 7 do
        local b = _G["BankFrameBag" .. i]
        if b then b:SetFrameStrata(strata) end
    end

    for i = 1, 28 do
        local b = _G["BankFrameItem" .. i]
        if b then b:SetFrameStrata(strata) end
    end

    local vkb = _G.AndroidTouchKeyboard
    if vkb then
        if strata == "DIALOG" then vkb:SetFrameStrata("HIGH")
        elseif strata == "HIGH" then vkb:SetFrameStrata("FULLSCREEN") end
    end
end

_G.CapriSetBagStrata = SetBagStrata
local vkbHooked = false

local function TryHookVKB()
    if vkbHooked then return end
    local vkb = _G.AndroidTouchKeyboard
    if not vkb then return end
    vkbHooked = true

    local function BagBelow() SetBagStrata("HIGH") end
    vkb:HookScript("OnShow", BagBelow)
    vkb:HookScript("OnMouseDown", BagBelow)
end

local function StripFrameTextures(frameName)
    local f = _G[frameName]
    if not f then return end
    local textures = {
        "Portrait", "BackgroundTop", "BackgroundMiddle1", "BackgroundMiddle2",
        "BackgroundBottom", "Background1Slot", "Name", "CloseButton"
    }
    for _, tex in ipairs(textures) do
        local obj = _G[f:GetName() .. tex]
        if obj then obj:Hide() end
    end
end

local function GetBagIcon(bagID)
    if bagID == 0 then return "Interface\\Buttons\\Button-Backpack-Up" end
    if bagID == KEYRING_ID then return "Interface\\Icons\\INV_Misc_Key_03" end

    local invID = nil
    if bagID >= 1 and bagID <= 4 then
        invID = ContainerIDToInventoryID(bagID)
    elseif bagID >= 5 and bagID <= 11 then
        if BankButtonIDToInvSlotID then invID = BankButtonIDToInvSlotID(bagID - 4, 1) end
    end

    if invID then
        local texture = GetInventoryItemTexture("player", invID)
        if texture then return texture end
    end
    return "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
end

local function GetSlotButton(containerFrame, slot, slots)
    if not containerFrame then return nil end
    local name = containerFrame:GetName()
    return _G[name .. "Item" .. slot] or _G[name .. "Item" .. (slots - slot + 1)]
end


local function EnhanceSlot(button, bagID)
    if not button then return end

    if button.isEnhanced then
        if button.capriEmptyKey then
            if bagID == KEYRING_ID then
                button.capriEmptyKey:Show()
            else
                button.capriEmptyKey:Hide()
            end
        end
        return
    end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    bg:SetVertexColor(0, 0, 0, 0.8)
    bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)

    local nt = button:GetNormalTexture()
    if nt then nt:SetVertexColor(0.9, 0.9, 0.9, 1) end

   
    button.capriEmptyKey = button:CreateTexture(nil, "BORDER")
    button.capriEmptyKey:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
    button.capriEmptyKey:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.capriEmptyKey:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.capriEmptyKey:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.capriEmptyKey:SetAlpha(0.25)
    
    if bagID == KEYRING_ID then
        button.capriEmptyKey:Show()
    else
        button.capriEmptyKey:Hide()
    end

    button.isEnhanced = true
end

local function ForceOpenBags(bagArray)
    for _, bag in ipairs(bagArray) do
        local slots = GetContainerNumSlots(bag)

        if bag == KEYRING_ID then
            local krSize = GetKeyRingSize and GetKeyRingSize() or 32
            if krSize > 0 then slots = krSize end
        end

        if slots and slots > 0 then
            local isOpen = false

            for i = 1, 15 do
                local f = _G["ContainerFrame" .. i]
                if f and f:IsVisible() and f:GetID() == bag then
                    isOpen = true
                    break
                end
            end

            if not isOpen then
                if bag == KEYRING_ID then ToggleKeyRing()
                else OpenBag(bag) end
            end
        end
    end
end

-- ======================================================================
-- Llavero como pagina aparte.
-- ======================================================================
local function LlaveroAbierto()
    for i = 1, 15 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsVisible() and f:GetID() == KEYRING_ID then
            return true
        end
    end
    return false
end

local function CerrarLlavero()
    if LlaveroAbierto() and ToggleKeyRing then
        ToggleKeyRing()
    end
end

local function ActualizarTecla()
    if not btnKeyring then return end
    local tex = btnKeyring:GetNormalTexture()
    if tex then
        if keyringPage then
            tex:SetVertexColor(1, 0.82, 0.2)
        else
            tex:SetVertexColor(1, 1, 1)
        end
    end
end

local function CrearBotonLlavero(contenedor, slot)
    if not contenedor or not contenedor.GetName then return nil end
    local nombre = contenedor:GetName()
    if not nombre then return nil end
    nombre = nombre .. "Item" .. slot
    local b = _G[nombre]
    if not b then
        b = CreateFrame("Button", nombre, contenedor, "ContainerFrameItemButtonTemplate")
        b:SetID(slot)
        b:SetSize(37, 37)
    end
    return b
end

local function ActualizarBotonLlavero(b, slot)
    if not b then return end
    local textura, cantidad
    if GetContainerItemInfo then
        textura, cantidad = GetContainerItemInfo(KEYRING_ID, slot)
    end
    if SetItemButtonTexture then SetItemButtonTexture(b, textura) end
    if SetItemButtonCount then SetItemButtonCount(b, cantidad or 0) end
    if b.icon and type(b.icon) ~= "function" and b.icon.SetTexture then
        b.icon:SetTexture(textura)
    end
    if b.Count and type(b.Count) ~= "function" and b.Count.SetText then
        if cantidad and cantidad > 1 then b.Count:SetText(cantidad) else b.Count:SetText("") end
    end
    b.hasItem = textura ~= nil
end

local function OrganizeItems()
    if not frame:IsVisible() then return end

    if keyringPage then
        ForceOpenBags({ KEYRING_ID })
    end
    ActualizarTecla()

    local buttonSize = 41
    local startY = -(BAG_FLAP_TOP + BAG_FLAP_H + 12)
    local currentY = startY
    local globalSlotIndex = 0
    local startX = BAG_SIDE_PAD
    local totalLeftHeight = 0

    local lista = keyringPage and { KEYRING_ID } or mainBagsList
    local enLista = {}
    for _, bag in ipairs(lista) do enLista[bag] = true end

    for _, bag in ipairs(mainBagsList) do
        if not enLista[bag] then
            local lbl = _G["UnifiedBagLabel" .. tostring(bag)]
            local ic = _G["UnifiedBagIcon" .. tostring(bag)]
            if lbl then lbl:Hide() end
            if ic then ic:Hide() end
            local listaVieja = CapriHighlightRegistry[bag]
            if listaVieja then
                for _, btn in ipairs(listaVieja) do btn:Hide() end
            end
        end
    end
    if not keyringPage then
        local lbl = _G["UnifiedBagLabelKeyring"]
        local ic = _G["UnifiedBagIconKeyring"]
        if lbl then lbl:Hide() end
        if ic then ic:Hide() end
        local listaVieja = CapriHighlightRegistry[KEYRING_ID]
        if listaVieja then
            for _, btn in ipairs(listaVieja) do btn:Hide() end
        end
    end

    for _, bag in ipairs(mainBagsList) do CapriHighlightRegistry[bag] = {} end
    if keyringPage then CapriHighlightRegistry[KEYRING_ID] = {} end

    if showSideBags then
        UnifiedPaperDollPanel:Show()
        bagSlotPanel:Show()
        dividerLine:Show()

        UnifiedPaperDollPanel:ClearAllPoints()
        UnifiedPaperDollPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", BAG_SIDE_PAD, startY)
        bagSlotPanel:ClearAllPoints()
        bagSlotPanel:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "BOTTOMLEFT", 0, -8)

        startX = BAG_SIDE_PAD + pdWidth + 24
        totalLeftHeight = -startY + pdHeight + 8 + 52 + 8

        if showBagTitles then
            UnifiedProfMainPanel:Show()
            UnifiedProfSecPanel:Show()
            UnifiedProfMainPanel:ClearAllPoints()
            UnifiedProfMainPanel:SetPoint("TOPLEFT", bagSlotPanel, "BOTTOMLEFT", 0, -8)
            UnifiedProfSecPanel:ClearAllPoints()
            UnifiedProfSecPanel:SetPoint("TOPLEFT", UnifiedProfMainPanel, "BOTTOMLEFT", 0, -8)
            totalLeftHeight = totalLeftHeight + 100 + 8 + 130 + 8
            UpdateProfSlots()
        else
            UnifiedProfMainPanel:Hide()
            UnifiedProfSecPanel:Hide()
        end

        for i, bag in ipairs({ 4, 3, 2, 1, 0 }) do
            local btnName = "UnifiedBagSideClone" .. tostring(bag)
            local bagSlotBtn = _G[btnName] or CreateFrame("Button", btnName, bagSlotPanel)
            bagSlotBtn.capriBagID = bag

            if bag == 0 then bagSlotBtn.capriInvID = nil
            else bagSlotBtn.capriInvID = ContainerIDToInventoryID(bag) end

            bagSlotBtn:SetWidth(36)
            bagSlotBtn:SetHeight(36)
            bagSlotBtn:ClearAllPoints()
            bagSlotBtn:SetPoint("LEFT", bagSlotPanel, "LEFT", 16 + (i - 1) * 38, 0)
            bagSlotBtn:SetFrameLevel(bagSlotPanel:GetFrameLevel() + 1)

            if not bagSlotBtn.capriIcon then
                bagSlotBtn.capriIcon = bagSlotBtn:CreateTexture(nil, "ARTWORK")
                bagSlotBtn.capriIcon:SetPoint("TOPLEFT", bagSlotBtn, "TOPLEFT", 2, -2)
                bagSlotBtn.capriIcon:SetPoint("BOTTOMRIGHT", bagSlotBtn, "BOTTOMRIGHT", -2, 2)
            end

            bagSlotBtn.capriIcon:SetTexture(GetBagIcon(bag))
            EnhanceSlot(bagSlotBtn, bag)
            bagSlotBtn:EnableMouse(true)
            bagSlotBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            bagSlotBtn:RegisterForDrag("LeftButton")
            bagSlotBtn:Show()

            if not bagSlotBtn.capriHoverHooked then
                bagSlotBtn:SetScript("OnEnter", function(self)
                    if self.capriBagID and CapriHighlightRegistry[self.capriBagID] then
                        for _, slotBtn in ipairs(CapriHighlightRegistry[self.capriBagID]) do
                            if slotBtn.LockHighlight and slotBtn:IsVisible() then slotBtn:LockHighlight() end
                        end
                    end
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    if self.capriBagID == 0 then GameTooltip:SetText("Mochila Principal", 1.0, 1.0, 1.0)
                    elseif self.capriInvID then
                        local hasItem = GameTooltip:SetInventoryItem("player", self.capriInvID)
                        if not hasItem then GameTooltip:SetText("Bolsa " .. self.capriBagID, 1.0, 1.0, 1.0) end
                    end
                    GameTooltip:Show()
                end)

                bagSlotBtn:SetScript("OnLeave", function(self)
                    if self.capriBagID and CapriHighlightRegistry[self.capriBagID] then
                        for _, slotBtn in ipairs(CapriHighlightRegistry[self.capriBagID]) do
                            if slotBtn.UnlockHighlight then slotBtn:UnlockHighlight() end
                        end
                    end
                    GameTooltip:Hide()
                end)

                bagSlotBtn:SetScript("OnClick", function(self)
                    if keyringPage then
                        keyringPage = false
                        if CaprimedinaUIDB then CaprimedinaUIDB.showKeyringPage = false end
                        CerrarLlavero()
                        OrganizeItems()
                        return
                    end
                    if self.capriInvID then
                        if CursorHasItem() then PutItemInBag(self.capriInvID)
                        else PickupBagFromSlot(self.capriInvID) end
                    end
                end)

                bagSlotBtn:SetScript("OnReceiveDrag", function(self)
                    if self.capriInvID then PutItemInBag(self.capriInvID) end
                end)

                bagSlotBtn:SetScript("OnDragStart", function(self)
                    if self.capriInvID then
                        _G.CapriUIState.dragging = true
                        _G.CapriUIState.dragOwner = "bagitem"
                        PickupBagFromSlot(self.capriInvID)
                    end
                end)

                bagSlotBtn:SetScript("OnDragStop", function()
                    if _G.CapriUIState and _G.CapriUIState.dragOwner == "bagitem" then
                        _G.CapriUIState.dragging = false
                        _G.CapriUIState.dragOwner = nil
                    end
                end)
                bagSlotBtn.capriHoverHooked = true
            end
        end
    else
        UnifiedPaperDollPanel:Hide()
        bagSlotPanel:Hide()
        dividerLine:Hide()
        UnifiedProfMainPanel:Hide()
        UnifiedProfSecPanel:Hide()
        startX = BAG_SIDE_PAD
        totalLeftHeight = 0
    end

    for _, bag in ipairs(lista) do
        local slots = GetContainerNumSlots(bag)

        if bag == KEYRING_ID then
            slots = KR_MAX
        end

        local bagContainer = nil
        for i = 1, 15 do
            local f = _G["ContainerFrame" .. i]
            if f and f:IsVisible() and f:GetID() == bag then
                bagContainer = f
                break
            end
        end

        local idStr = (bag == KEYRING_ID) and "Keyring" or tostring(bag)
        local label = _G["UnifiedBagLabel" .. idStr] or frame:CreateFontString("UnifiedBagLabel" .. idStr, "OVERLAY")
        local icon = _G["UnifiedBagIcon" .. idStr] or frame:CreateTexture("UnifiedBagIcon" .. idStr, "OVERLAY")

        if label.SetFont then C.SetOutlineFont(label, 12) end

        if slots and slots > 0 and bagContainer then
            bagContainer:ClearAllPoints()
            bagContainer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, 9999)
            bagContainer:SetScale(currentScale)
            StripFrameTextures(bagContainer:GetName())

            if showBagTitles then
                icon:SetWidth(16)
                icon:SetHeight(16)
                icon:SetTexture(GetBagIcon(bag))
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, currentY + 2)
                icon:Show()

                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + 20, currentY)
                label:SetTextColor(1, 0.8, 0)
                if bag == 0 then label:SetText("MOCHILA PRINCIPAL")
                elseif bag == KEYRING_ID then label:SetText("LLAVERO")
                else label:SetText("BOLSA " .. bag) end
                label:Show()

                currentY = currentY - 20
                local localSlotIndex = 0

                for slot = 1, slots do
                    local itemButton
                    if bag == KEYRING_ID then
                        itemButton = CrearBotonLlavero(bagContainer, slot)
                    else
                        itemButton = GetSlotButton(bagContainer, slot, slots)
                    end
                    if itemButton then
                        tinsert(CapriHighlightRegistry[bag], itemButton)
                        itemButton:ClearAllPoints()

                        local row = math.floor(localSlotIndex / currentCols)
                        local col = localSlotIndex % currentCols

                        itemButton:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + (col * buttonSize), currentY - (row * buttonSize))
                        itemButton:SetFrameStrata(currentBagStrata)
                        itemButton:SetFrameLevel(frame:GetFrameLevel() + 5)
                        itemButton:EnableMouse(true)
                        itemButton:Show()
                        EnhanceSlot(itemButton, bag)
                        if bag == KEYRING_ID then
                            ActualizarBotonLlavero(itemButton, slot)
                        end
                        localSlotIndex = localSlotIndex + 1
                    end
                end

                local numRows = math.ceil(slots / currentCols)
                currentY = currentY - (numRows * buttonSize) - 10
            else
                label:Hide()
                icon:Hide()

                for slot = 1, slots do
                    local itemButton
                    if bag == KEYRING_ID then
                        itemButton = CrearBotonLlavero(bagContainer, slot)
                    else
                        itemButton = GetSlotButton(bagContainer, slot, slots)
                    end
                    if itemButton then
                        tinsert(CapriHighlightRegistry[bag], itemButton)
                        itemButton:ClearAllPoints()

                        local row = math.floor(globalSlotIndex / currentCols)
                        local col = globalSlotIndex % currentCols

                        itemButton:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + (col * buttonSize), startY - (row * buttonSize))
                        itemButton:SetFrameStrata(currentBagStrata)
                        itemButton:SetFrameLevel(frame:GetFrameLevel() + 5)
                        itemButton:EnableMouse(true)
                        itemButton:Show()
                        EnhanceSlot(itemButton, bag)
                        if bag == KEYRING_ID then
                            ActualizarBotonLlavero(itemButton, slot)
                        end
                        globalSlotIndex = globalSlotIndex + 1
                    end
                end
            end
        else
            label:Hide()
            icon:Hide()
        end
    end

    if not showBagTitles then
        local totalRows = math.ceil(globalSlotIndex / currentCols)
        currentY = startY - (totalRows * buttonSize) - 15
    end

    MoneyFrame_Update("UnifiedBagMoneyFrame", GetMoney())

    local rightHeight = math.abs(currentY) + 15
    local finalHeight = math.max(totalLeftHeight, rightHeight)

    frame:SetScale(currentScale)
    frame:SetWidth(startX + (currentCols * buttonSize) + BAG_SIDE_PAD)
    frame:SetHeight(finalHeight + BAG_BOTTOM_PAD)
    LayoutBagSkin()

    if UnifiedPaperDollModel and UnifiedPaperDollModel:IsVisible() then
        local rot = UnifiedPaperDollModel:GetFacing() or 0
        UnifiedPaperDollModel:ClearModel()
        UnifiedPaperDollModel:SetUnit("player")
        UnifiedPaperDollModel:SetFacing(rot)
    end
end

btnToggleSideBags:SetScript("OnClick", function(self)
    showSideBags = not showSideBags
    if CaprimedinaUIDB then CaprimedinaUIDB.showSideBags = showSideBags end
    if showSideBags then self:SetText("<") else self:SetText(">") end
    OrganizeItems()
end)

local function OrganizeBankItems()
    if not bankFrame:IsVisible() then return end

    local purchaseInfo = _G["BankFramePurchaseInfo"]
    if purchaseInfo then purchaseInfo:Hide() end

    BankFrame:ClearAllPoints()
    BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, 9999)
    BankFrame:SetScale(bankScale)
    StripFrameTextures("BankFrame")

    local buttonSize = 41
    local currentY = -(BANK_FLAP_TOP + BANK_FLAP_H + 12)
    local globalBankSlotIndex = 0

    for _, bag in ipairs(bankBagsList) do CapriHighlightRegistry[bag] = {} end

    if showBankSideBags then
        bankSlotPanel:Show()
        local slotY = -32

        for i = 1, 7 do
            local bagID = 4 + i
            local btnName = (_G["BankFrameBag" .. i] and "BankFrameBag" .. i)
                or (_G["BankFrameItem" .. (28 + i)] and "BankFrameItem" .. (28 + i))
                or "BankFrameItem" .. (24 + i)
            local bagSlotItem = _G[btnName]

            if bagSlotItem then
                bagSlotItem.capriBagID = bagID
                bagSlotItem:SetParent(bankSlotPanel)
                bagSlotItem:ClearAllPoints()
                bagSlotItem:SetPoint("TOP", bankSlotPanel, "TOP", 0, slotY)
                bagSlotItem:SetSize(38, 38)
                bagSlotItem:SetScale(1)
                bagSlotItem:SetFrameStrata(currentBagStrata)
                bagSlotItem:SetFrameLevel(bankSlotPanel:GetFrameLevel() + 2)
                bagSlotItem:EnableMouse(true)
                bagSlotItem:Show()
                EnhanceSlot(bagSlotItem, bagID)

                if not bagSlotItem.capriHoverHooked then
                    local oldEnter = bagSlotItem:GetScript("OnEnter")
                    local oldLeave = bagSlotItem:GetScript("OnLeave")

                    bagSlotItem:SetScript("OnEnter", function(self)
                        if oldEnter then oldEnter(self) end
                        if self.capriBagID and CapriHighlightRegistry[self.capriBagID] then
                            for _, slotBtn in ipairs(CapriHighlightRegistry[self.capriBagID]) do
                                if slotBtn.LockHighlight and slotBtn:IsVisible() then slotBtn:LockHighlight() end
                            end
                        end
                    end)

                    bagSlotItem:SetScript("OnLeave", function(self)
                        if oldLeave then oldLeave(self) end
                        if self.capriBagID and CapriHighlightRegistry[self.capriBagID] then
                            for _, slotBtn in ipairs(CapriHighlightRegistry[self.capriBagID]) do
                                if slotBtn.UnlockHighlight then slotBtn:UnlockHighlight() end
                            end
                        end
                    end)
                    bagSlotItem.capriHoverHooked = true
                end
                slotY = slotY - 40
            end
        end
    else
        bankSlotPanel:Hide()
    end

    local labelBank = _G["UnifiedBankLabelMain"] or bankFrame:CreateFontString("UnifiedBankLabelMain", "OVERLAY")
    local iconBank = _G["UnifiedBankIconMain"] or bankFrame:CreateTexture("UnifiedBankIconMain", "OVERLAY")

    if labelBank.SetFont then C.SetOutlineFont(labelBank, 12) end

    if showBankTitles then
        globalBankSlotIndex = 0
        iconBank:SetWidth(16)
        iconBank:SetHeight(16)
        iconBank:SetTexture("Interface\\Icons\\Inv_box_02")
        iconBank:ClearAllPoints()
        iconBank:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", BANK_SIDE_PAD, currentY + 2)
        iconBank:Show()

        labelBank:ClearAllPoints()
        labelBank:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", BANK_SIDE_PAD + 20, currentY)
        labelBank:SetTextColor(1, 0.8, 0)
        labelBank:SetText("BANCO PRINCIPAL")
        labelBank:Show()

        currentY = currentY - 20
    else
        labelBank:Hide()
        iconBank:Hide()
    end

    for slot = 1, 28 do
        local itemButton = _G["BankFrameItem" .. slot]
        if itemButton then
            itemButton:ClearAllPoints()
            local row = math.floor(globalBankSlotIndex / bankCols)
            local col = globalBankSlotIndex % bankCols
            itemButton:SetPoint("TOPLEFT", bankFrame, "TOPLEFT",
                BANK_SIDE_PAD + (col * buttonSize), currentY - (row * buttonSize))
            itemButton:SetFrameStrata(currentBagStrata)
            itemButton:SetFrameLevel(bankFrame:GetFrameLevel() + 5)
            itemButton:EnableMouse(true)
            itemButton:SetAlpha(1)
            itemButton:Show()
            EnhanceSlot(itemButton, nil)
            globalBankSlotIndex = globalBankSlotIndex + 1
        end
    end

    if showBankTitles then
        local numRowsMain = math.ceil(28 / bankCols)
        currentY = currentY - (numRowsMain * buttonSize) - 15
    end

    for _, bag in ipairs(bankBagsList) do
        local slots = GetContainerNumSlots(bag)
        local bagContainer = nil

        for i = 1, 15 do
            local f = _G["ContainerFrame" .. i]
            if f and f:IsVisible() and f:GetID() == bag then
                bagContainer = f
                break
            end
        end

        local label = _G["UnifiedBankBagLabel" .. bag] or bankFrame:CreateFontString("UnifiedBankBagLabel" .. bag, "OVERLAY")
        local icon = _G["UnifiedBankBagIcon" .. bag] or bankFrame:CreateTexture("UnifiedBankBagIcon" .. bag, "OVERLAY")

        if label.SetFont then C.SetOutlineFont(label, 12) end

        if slots and slots > 0 and bagContainer then
            bagContainer:ClearAllPoints()
            bagContainer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, 9999)
            bagContainer:SetScale(bankScale)
            StripFrameTextures(bagContainer:GetName())

            if showBankTitles then
                globalBankSlotIndex = 0
                icon:SetWidth(16)
                icon:SetHeight(16)
                icon:SetTexture(GetBagIcon(bag))
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", BANK_SIDE_PAD, currentY + 2)
                icon:Show()

                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", BANK_SIDE_PAD + 20, currentY)
                label:SetTextColor(1, 0.8, 0)
                label:SetText("CONTENIDO DE BOLSA " .. (bag - 4))
                label:Show()
                currentY = currentY - 20
            else
                label:Hide()
                icon:Hide()
            end

            for slot = 1, slots do
                local itemButton = GetSlotButton(bagContainer, slot, slots)
                if itemButton then
                    tinsert(CapriHighlightRegistry[bag], itemButton)
                    itemButton:ClearAllPoints()

                    local row = math.floor(globalBankSlotIndex / bankCols)
                    local col = globalBankSlotIndex % bankCols

                    itemButton:SetPoint("TOPLEFT", bankFrame, "TOPLEFT",
                        BANK_SIDE_PAD + (col * buttonSize), currentY - (row * buttonSize))
                    itemButton:SetFrameStrata(currentBagStrata)
                    itemButton:SetFrameLevel(bankFrame:GetFrameLevel() + 5)
                    itemButton:EnableMouse(true)
                    itemButton:Show()
                    EnhanceSlot(itemButton, bag)
                    globalBankSlotIndex = globalBankSlotIndex + 1
                end
            end

            if showBankTitles then
                local numRows = math.ceil(slots / bankCols)
                currentY = currentY - (numRows * buttonSize) - 15
            end
        else
            label:Hide()
            icon:Hide()
        end
    end

    if not showBankTitles then
        local totalRows = math.ceil(globalBankSlotIndex / bankCols)
        currentY = currentY - (totalRows * buttonSize) - 15
    end

    bankFrame:SetWidth((BANK_SIDE_PAD * 2) + (bankCols * buttonSize))
    bankFrame:SetHeight(math.abs(currentY) + BANK_BOTTOM_PAD)
    bankFrame:SetScale(bankScale)
    LayoutBankSkin()

    local purchaseBtn = _G["BankFramePurchaseButton"]
    local costText = _G["UnifiedBankCostText"]
    if not costText then
        costText = bankPlaque:CreateFontString("UnifiedBankCostText", "OVERLAY")
    elseif costText.SetParent then
        costText:SetParent(bankPlaque)
    end
    local anchoBanco = bankFrame:GetWidth() or 0

    if costText.SetFont then C.SetOutlineFont(costText, anchoBanco < 300 and 11 or 12) end

    if purchaseBtn then
        purchaseBtn:SetParent(bankPlaque)
        purchaseBtn:ClearAllPoints()
        purchaseBtn:SetPoint("LEFT", bankPlaque, "LEFT", anchoBanco < 300 and 10 or 14, 0)
        purchaseBtn:SetFrameStrata(currentBagStrata)
        purchaseBtn:SetFrameLevel(bankPlaque:GetFrameLevel() + 2)
        purchaseBtn:EnableMouse(true)

        local numSlots, full = GetNumBankSlots()

        if full then
            purchaseBtn:Hide()
            if bankCostMoney then bankCostMoney:Hide() end
            costText:SetText("Ranuras al maximo")
            costText:SetTextColor(0, 1, 0)
            costText:ClearAllPoints()
            costText:SetPoint("CENTER", bankPlaque, "CENTER", 0, 0)
            costText:Show()
        else
            purchaseBtn:Show()
            costText:Hide()
            local cost = GetBankSlotCost(numSlots)
            if bankCostMoney then
                bankCostMoney:ClearAllPoints()
                bankCostMoney:SetPoint("LEFT", purchaseBtn, "RIGHT", anchoBanco < 300 and 6 or 10, 0)
                MoneyFrame_Update("UnifiedBankCostMoney", cost)
                bankCostMoney:Show()
            end
        end
    end
end

btnToggleBankSideBags:SetScript("OnClick", function(self)
    showBankSideBags = not showBankSideBags
    if CaprimedinaUIDB then CaprimedinaUIDB.showBankSideBags = showBankSideBags end
    if showBankSideBags then self:SetText("<") else self:SetText(">") end
    OrganizeBankItems()
end)

local oldBankSetPoint = BankFrame.SetPoint
BankFrame.SetPoint = function(self, point, relativeTo, relativePoint, xOffset, yOffset)
    if bankFrame and bankFrame:IsVisible() then
        oldBankSetPoint(self, "TOPLEFT", UIParent, "TOPLEFT", -9999, 9999)
    else
        oldBankSetPoint(self, point, relativeTo, relativePoint, xOffset, yOffset)
    end
end

local function CreateCfgRow(parent, yOffset, labelText, btn1Text, btn2Text, func1, func2)
    local label = parent:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(label, 13)
    label:SetPoint("TOPLEFT", 20, yOffset - 5)
    label:SetText(labelText)
    label:SetTextColor(1, 1, 1)

    local btn1 = C.CreateStyledButton(parent, btn1Text, 30, 22)
    btn1:SetPoint("TOPLEFT", 110, yOffset)
    btn1:SetScript("OnClick", func1)

    local btn2 = nil
    if btn2Text then
        btn2 = C.CreateStyledButton(parent, btn2Text, 30, 22)
        btn2:SetPoint("TOPLEFT", 145, yOffset)
        btn2:SetScript("OnClick", func2)
    end
    return btn1, btn2
end

local function CreateToggleRow(parent, yOffset, labelText, toggleFunc)
    local label = parent:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(label, 13)
    label:SetPoint("TOPLEFT", 20, yOffset - 5)
    label:SetText(labelText)
    label:SetTextColor(1, 1, 1)

    local btn = C.CreateStyledButton(parent, "", 80, 22)
    btn:SetPoint("TOPLEFT", 110, yOffset)
    btn:SetScript("OnClick", toggleFunc)
    return btn
end

local btnTitlesBag, btnLockBag

local CapriBagConfigFrame = CreateFrame("Frame", "CapriBagConfigFrame", UIParent)
CapriBagConfigFrame:SetFrameStrata("FULLSCREEN_DIALOG")
CapriBagConfigFrame:SetWidth(280)
CapriBagConfigFrame:SetHeight(170)
CapriBagConfigFrame:SetPoint("CENTER", 0, 0)
C.StyleWindow(CapriBagConfigFrame)
CapriBagConfigFrame:SetMovable(true)
CapriBagConfigFrame:EnableMouse(true)
CapriBagConfigFrame:RegisterForDrag("LeftButton")
CapriBagConfigFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
CapriBagConfigFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
CapriBagConfigFrame:Hide()

local cfgBagTitle = CapriBagConfigFrame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(cfgBagTitle, 16)
cfgBagTitle:SetPoint("TOP", 0, -15)
cfgBagTitle:SetText("Ajustes de Mochila")
cfgBagTitle:SetTextColor(1, 1, 1)

local cfgBagClose = C.CreateStyledClose(CapriBagConfigFrame)

CreateCfgRow(CapriBagConfigFrame, -45, "Tamaño: ", "-", "+",
    function()
        currentScale = math.max(currentScale - 0.1, 0.6)
        if CaprimedinaUIDB then CaprimedinaUIDB.bagScale = currentScale end
        OrganizeItems()
    end,
    function()
        currentScale = math.min(currentScale + 0.1, 1.8)
        if CaprimedinaUIDB then CaprimedinaUIDB.bagScale = currentScale end
        OrganizeItems()
    end
)

CreateCfgRow(CapriBagConfigFrame, -75, "Columnas: ", " < ", " > ",
    function()
        currentCols = math.max(currentCols - 1, 4)
        if CaprimedinaUIDB then CaprimedinaUIDB.bagCols = currentCols end
        OrganizeItems()
    end,
    function()
        currentCols = math.min(currentCols + 1, 20)
        if CaprimedinaUIDB then CaprimedinaUIDB.bagCols = currentCols end
        OrganizeItems()
    end
)

btnTitlesBag = CreateToggleRow(CapriBagConfigFrame, -105, "Titulos: ", function(self)
    showBagTitles = not showBagTitles
    if CaprimedinaUIDB then CaprimedinaUIDB.showBagTitles = showBagTitles end
    if showBagTitles then self:SetText("|cff00ff00Mostrar|r") else self:SetText("|cffff0000Quitar|r") end
    OrganizeItems()
end)

btnLockBag = CreateToggleRow(CapriBagConfigFrame, -135, "Posicion: ", function(self)
    isBagLocked = not isBagLocked
    if CaprimedinaUIDB then CaprimedinaUIDB.isBagLocked = isBagLocked end
    if isBagLocked then self:SetText("|cffff0000Mantener|r") else self:SetText("|cff00ff00Libre|r") end
end)

local btnTitlesBank, btnLockBank

local CapriBankConfigFrame = CreateFrame("Frame", "CapriBankConfigFrame", UIParent)
CapriBankConfigFrame:SetFrameStrata("FULLSCREEN_DIALOG")
CapriBankConfigFrame:SetWidth(280)
CapriBankConfigFrame:SetHeight(170)
CapriBankConfigFrame:SetPoint("CENTER", 0, -160)
C.StyleWindow(CapriBankConfigFrame)
CapriBankConfigFrame:SetMovable(true)
CapriBankConfigFrame:EnableMouse(true)
CapriBankConfigFrame:RegisterForDrag("LeftButton")
CapriBankConfigFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
CapriBankConfigFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
CapriBankConfigFrame:Hide()

local cfgBankTitle = CapriBankConfigFrame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(cfgBankTitle, 16)
cfgBankTitle:SetPoint("TOP", 0, -15)
cfgBankTitle:SetText("Ajustes del Banco")
cfgBankTitle:SetTextColor(1, 1, 1)

local cfgBankClose = C.CreateStyledClose(CapriBankConfigFrame)

CreateCfgRow(CapriBankConfigFrame, -45, "Tamaño: ", "-", "+",
    function()
        bankScale = math.max(bankScale - 0.1, 0.6)
        if CaprimedinaUIDB then CaprimedinaUIDB.bankScale = bankScale end
        OrganizeBankItems()
    end,
    function()
        bankScale = math.min(bankScale + 0.1, 1.8)
        if CaprimedinaUIDB then CaprimedinaUIDB.bankScale = bankScale end
        OrganizeBankItems()
    end
)

CreateCfgRow(CapriBankConfigFrame, -75, "Columnas: ", " < ", " > ",
    function()
        bankCols = math.max(bankCols - 1, 4)
        if CaprimedinaUIDB then CaprimedinaUIDB.bankCols = bankCols end
        OrganizeBankItems()
    end,
    function()
        bankCols = math.min(bankCols + 1, 20)
        if CaprimedinaUIDB then CaprimedinaUIDB.bankCols = bankCols end
        OrganizeBankItems()
    end
)

btnTitlesBank = CreateToggleRow(CapriBankConfigFrame, -105, "Titulos: ", function(self)
    showBankTitles = not showBankTitles
    if CaprimedinaUIDB then CaprimedinaUIDB.showBankTitles = showBankTitles end
    if showBankTitles then self:SetText("|cff00ff00Mostrar|r") else self:SetText("|cffff0000Quitar|r") end
    OrganizeBankItems()
end)

btnLockBank = CreateToggleRow(CapriBankConfigFrame, -135, "Posicion: ", function(self)
    isBankLocked = not isBankLocked
    if CaprimedinaUIDB then CaprimedinaUIDB.isBankLocked = isBankLocked end
    if isBankLocked then self:SetText("|cffff0000Mantener|r") else self:SetText("|cff00ff00Libre|r") end
end)

local close = C.CreateStyledButton(frame, "X", 26, 26, true)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -10)
close:SetFrameLevel(frame:GetFrameLevel() + 4)
close:SetScript("OnClick", function() CloseAllBags() end)
StyleLeatherButton(close)

local gearBag = CreateFrame("Button", nil, frame)
gearBag:SetFrameLevel(frame:GetFrameLevel() + 4)
gearBag:SetWidth(18)
gearBag:SetHeight(18)
gearBag:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
gearBag:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
gearBag:SetPoint("RIGHT", close, "LEFT", -4, 0)
gearBag:SetScript("OnClick", function()
    if CapriBagConfigFrame:IsVisible() then CapriBagConfigFrame:Hide()
    else CapriBagConfigFrame:Show() end
end)

btnKeyring = CreateFrame("Button", "UnifiedBagKeyringButton", frame)
btnKeyring:SetSize(22, 22)
btnKeyring:SetFrameLevel(frame:GetFrameLevel() + 4)
btnKeyring:SetNormalTexture("Interface\\Icons\\INV_Misc_Key_03")
btnKeyring:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
btnKeyring:SetPoint("RIGHT", gearBag, "LEFT", -4, 0)
btnKeyring:SetScript("OnClick", function()
    keyringPage = not keyringPage
    if CaprimedinaUIDB then CaprimedinaUIDB.showKeyringPage = keyringPage end
    if keyringPage then
        ForceOpenBags({ KEYRING_ID })
    else
        CerrarLlavero()
    end
    ActualizarTecla()
    if frame:IsVisible() then
        OrganizeItems()
        if RaiseBagWindow then RaiseBagWindow() end
    end
end)
btnKeyring:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Llavero", 1, 0.82, 0.2)
    GameTooltip:AddLine(keyringPage and "Volver a las bolsas." or "Ver las ranuras del llavero.", 1, 1, 1)
    GameTooltip:Show()
end)
btnKeyring:SetScript("OnLeave", function() GameTooltip:Hide() end)
ActualizarTecla()

local closeBank = C.CreateStyledButton(bankFrame, "X", 26, 26, true)
closeBank:SetPoint("TOPRIGHT", bankFrame, "TOPRIGHT", -18, -10)
closeBank:SetFrameLevel(bankFrame:GetFrameLevel() + 4)
closeBank:SetScript("OnClick", function() bankFrame:Hide() end)
StyleLeatherButton(closeBank)

local gearBank = CreateFrame("Button", nil, bankFrame)
gearBank:SetFrameLevel(bankFrame:GetFrameLevel() + 4)
gearBank:SetWidth(18)
gearBank:SetHeight(18)
gearBank:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
gearBank:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
gearBank:SetPoint("RIGHT", closeBank, "LEFT", -4, 0)
gearBank:SetScript("OnClick", function()
    if CapriBankConfigFrame:IsVisible() then CapriBankConfigFrame:Hide()
    else CapriBankConfigFrame:Show() end
end)

local capriTopLevel = 100

local function RaiseFamily(members)
    capriTopLevel = capriTopLevel + 10
    if capriTopLevel > 90000 then capriTopLevel = 100 end

    local base = capriTopLevel
    for _, entry in ipairs(members) do
        local f = entry[1]
        local off = entry[2] or 0
        if f and f.SetFrameLevel then f:SetFrameLevel(base + off) end
    end
end

RaiseBagWindow = function()
    local members = {
        { frame, 0 }, { bagSlotPanel, 1 }, { bagFlap, 2 }, { bagMoneyPlaque, 3 },
        { btnToggleSideBags, 4 }, { close, 4 }, { gearBag, 4 }, { btnKeyring, 4 }, { moneyFrame, 4 },
        { UnifiedPaperDollPanel, 1 }, { UnifiedPaperDollModel, 2 }, { dividerLine, 1 },
        { UnifiedProfMainPanel, 1 }, { UnifiedProfSecPanel, 1 },
    }

    for i = 1, 5 do
        local s = UnifiedProfSlots[i]
        if s and s.btn then table.insert(members, { s.btn, 3 }) end
    end

    for _, slotName in ipairs(equipSlots) do
        local slotId = GetInventorySlotInfo(slotName)
        local btn = _G["CapriPDSlot" .. slotId]
        if btn then table.insert(members, { btn, 3 }) end
    end

    for i = 0, 4 do
        local c = _G["UnifiedBagSideClone" .. i]
        if c then table.insert(members, { c, 2 }) end
    end

    for _, bag in ipairs(mainBagsList) do
        local list = CapriHighlightRegistry[bag]
        if list then
            for _, b in ipairs(list) do table.insert(members, { b, 3 }) end
        end
    end

    local listaKr = CapriHighlightRegistry[KEYRING_ID]
    if listaKr then
        for _, b in ipairs(listaKr) do table.insert(members, { b, 3 }) end
    end

    RaiseFamily(members)
    SetBagStrata("DIALOG")
end

RaiseBankWindow = function()
    local members = {
        { bankFrame, 0 }, { bankSlotPanel, 1 }, { bankFlap, 2 }, { bankPlaque, 3 },
        { btnToggleBankSideBags, 4 }, { closeBank, 4 }, { gearBank, 4 }, { bankCostMoney, 4 },
    }

    local pb = _G["BankFramePurchaseButton"]
    if pb then table.insert(members, { pb, 5 }) end

    for i = 1, 7 do
        local b = _G["BankFrameBag" .. i]
        if b then table.insert(members, { b, 2 }) end
    end

    for i = 1, 28 do
        local b = _G["BankFrameItem" .. i]
        if b then table.insert(members, { b, 3 }) end
    end

    for _, bag in ipairs(bankBagsList) do
        local list = CapriHighlightRegistry[bag]
        if list then
            for _, b in ipairs(list) do table.insert(members, { b, 3 }) end
        end
    end

    RaiseFamily(members)
    SetBagStrata("DIALOG")
end

frame:SetScript("OnMouseDown", function() RaiseBagWindow() end)
bankFrame:SetScript("OnMouseDown", function() RaiseBankWindow() end)

local uiBagsHooked = false

local function HookUIBags()
    if uiBagsHooked then return end

    local bagButtonsMap = {
        ["MainMenuBarBackpackButton"] = 0, ["CharacterBag0Slot"] = 1,
        ["CharacterBag1Slot"] = 2, ["CharacterBag2Slot"] = 3,
        ["CharacterBag3Slot"] = 4, ["KeyRingButton"] = KEYRING_ID,
    }

    for btnName, bagID in pairs(bagButtonsMap) do
        local btn = _G[btnName]
        if btn then
            btn.capriBagID = bagID
            local oldEnter = btn:GetScript("OnEnter")

            btn:SetScript("OnEnter", function(self)
                if oldEnter then oldEnter(self) end
                if self.capriBagID and CapriHighlightRegistry[self.capriBagID] then
                    for _, slotBtn in ipairs(CapriHighlightRegistry[self.capriBagID]) do
                        if slotBtn.LockHighlight and slotBtn:IsVisible() then slotBtn:LockHighlight() end
                    end
                end
            end)

            local oldLeave = btn:GetScript("OnLeave")

            btn:SetScript("OnLeave", function(self)
                if oldLeave then oldLeave(self) end
                if self.capriBagID and CapriHighlightRegistry[self.capriBagID] then
                    for _, slotBtn in ipairs(CapriHighlightRegistry[self.capriBagID]) do
                        if slotBtn.UnlockHighlight then slotBtn:UnlockHighlight() end
                    end
                end
            end)
        end
    end
    uiBagsHooked = true
end

function OpenAllBags(...)
    if not BagsEnabled() then
        if orig_OpenAllBags then orig_OpenAllBags(...) end
        return
    end

    frame:Show()
    ForceOpenBags(mainBagsList)
    OrganizeItems()
    if RaiseBagWindow then RaiseBagWindow() end
    updatePending = true
    updateTimer = 0
end

function CloseAllBags(...)
    if not BagsEnabled() then
        if orig_CloseAllBags then orig_CloseAllBags(...) end
        return
    end
    frame:Hide()
end

function OpenBackpack()
    if not BagsEnabled() then
        if orig_OpenBackpack then orig_OpenBackpack() end
        return
    end
    OpenAllBags()
end

function CloseBackpack()
    if not BagsEnabled() then
        if orig_CloseBackpack then orig_CloseBackpack() end
        return
    end
    CloseAllBags()
end

ToggleBackpack = function(...)
    if not BagsEnabled() then
        if orig_ToggleBackpack then orig_ToggleBackpack(...) end
        return
    end
    if frame:IsVisible() then CloseAllBags()
    else OpenAllBags() end
end

ToggleBag = function(id, ...)
    if not BagsEnabled() then
        if orig_ToggleBag then orig_ToggleBag(id, ...) end
        return
    end
    ToggleBackpack()
end

updateContainerFrameAnchors = function(...)
    if BagsEnabled() then return end
    if orig_updateContainerFrameAnchors then orig_updateContainerFrameAnchors(...) end
end

local oldUpdate = ContainerFrame_Update
ContainerFrame_Update = function(self)
    if oldUpdate then oldUpdate(self) end
    if keyringPage and self and self.GetID and self:GetID() == KEYRING_ID then
        local nombre = self:GetName()
        if nombre then
            for slot = 1, KR_MAX do
                local b = _G[nombre .. "Item" .. slot]
                if b then b:Show() end
            end
        end
    end
end

local eventHandler = CreateFrame("Frame")
eventHandler:RegisterEvent("VARIABLES_LOADED")
eventHandler:RegisterEvent("PLAYER_ENTERING_WORLD")
eventHandler:RegisterEvent("BAG_UPDATE")
eventHandler:RegisterEvent("PLAYER_MONEY")
eventHandler:RegisterEvent("BANKFRAME_OPENED")
eventHandler:RegisterEvent("BANKFRAME_CLOSED")
eventHandler:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventHandler:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")

local initialBagLoadDone = false

eventHandler:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        if type(CaprimedinaUIDB) ~= "table" then CaprimedinaUIDB = {} end
        if CaprimedinaUIDB.enableBags == false then return end

        if CaprimedinaUIDB.bagScale then currentScale = CaprimedinaUIDB.bagScale end
        if CaprimedinaUIDB.bagCols then currentCols = CaprimedinaUIDB.bagCols end
        if CaprimedinaUIDB.showBagTitles ~= nil then showBagTitles = CaprimedinaUIDB.showBagTitles end
        if CaprimedinaUIDB.isBagLocked ~= nil then isBagLocked = CaprimedinaUIDB.isBagLocked end
        if CaprimedinaUIDB.showSideBags ~= nil then showSideBags = CaprimedinaUIDB.showSideBags end
        keyringPage = false
        ActualizarTecla()

        if CaprimedinaUIDB.bagPos then
            frame:ClearAllPoints()
            frame:SetPoint(CaprimedinaUIDB.bagPos.p, UIParent, CaprimedinaUIDB.bagPos.rp, CaprimedinaUIDB.bagPos.x, CaprimedinaUIDB.bagPos.y)
        end

        if CaprimedinaUIDB.bankScale then bankScale = CaprimedinaUIDB.bankScale end
        if CaprimedinaUIDB.bankCols then bankCols = CaprimedinaUIDB.bankCols end
        if CaprimedinaUIDB.showBankTitles ~= nil then showBankTitles = CaprimedinaUIDB.showBankTitles end
        if CaprimedinaUIDB.isBankLocked ~= nil then isBankLocked = CaprimedinaUIDB.isBankLocked end
        if CaprimedinaUIDB.showBankSideBags ~= nil then showBankSideBags = CaprimedinaUIDB.showBankSideBags end

        if CaprimedinaUIDB.bankPos then
            bankFrame:ClearAllPoints()
            bankFrame:SetPoint(CaprimedinaUIDB.bankPos.p, UIParent, CaprimedinaUIDB.bankPos.rp, CaprimedinaUIDB.bankPos.x, CaprimedinaUIDB.bankPos.y)
        end

        if showBagTitles then btnTitlesBag:SetText("|cff00ff00Mostrar|r") else btnTitlesBag:SetText("|cffff0000Quitar|r") end
        if isBagLocked then btnLockBag:SetText("|cffff0000Mantener|r") else btnLockBag:SetText("|cff00ff00Libre|r") end
        if showSideBags then btnToggleSideBags:SetText("<") else btnToggleSideBags:SetText(">") end
        if showBankTitles then btnTitlesBank:SetText("|cff00ff00Mostrar|r") else btnTitlesBank:SetText("|cffff0000Quitar|r") end
        if isBankLocked then btnLockBank:SetText("|cffff0000Mantener|r") else btnLockBank:SetText("|cff00ff00Libre|r") end
        if showBankSideBags then btnToggleBankSideBags:SetText("<") else btnToggleBankSideBags:SetText(">") end

        HookUIBags()

    elseif event == "PLAYER_ENTERING_WORLD" then
        if BagsEnabled() and not initialBagLoadDone then
            local oldAlpha = frame:GetAlpha()
            frame:SetAlpha(0)

            local originalPlaySound = _G.PlaySound
            _G.PlaySound = function() end

            frame:Show()
            ForceOpenBags(mainBagsList)
            OrganizeItems()
            frame:Hide()

            _G.PlaySound = originalPlaySound
            frame:SetAlpha(oldAlpha)
            initialBagLoadDone = true
        end

    elseif BagsEnabled() then
        if event == "PLAYER_MONEY" then
            MoneyFrame_Update("UnifiedBagMoneyFrame", GetMoney())
            if bankFrame:IsVisible() then OrganizeBankItems() end

        elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
            if frame:IsVisible() then
                ForceOpenBags(mainBagsList)
                OrganizeItems()
            end
            if bankFrame:IsVisible() then
                ForceOpenBags(bankBagsList)
                OrganizeBankItems()
            end
            updatePending = true
            updateTimer = 0

        elseif event == "BANKFRAME_OPENED" then
            OpenAllBags()
            bankFrame:Show()
            ForceOpenBags(bankBagsList)
            OrganizeBankItems()
            updatePending = true
            updateTimer = 0

        elseif event == "BANKFRAME_CLOSED" then
            bankFrame:Hide()
            CloseAllBags()
            for i = 5, 11 do CloseBag(i) end
        end
    end
end)

local vkbTryTimer = 0

eventHandler:SetScript("OnUpdate", function(self, elapsed)
    if _G.CapriUIState and _G.CapriUIState.dragging and not IsMouseButtonDown("LeftButton") then
        _G.CapriUIState.dragging = false
        _G.CapriUIState.dragOwner = nil
    end

    if CaprimedinaUIDB and CaprimedinaUIDB.enableBags == false then return end

    if not vkbHooked then
        vkbTryTimer = vkbTryTimer + elapsed
        if vkbTryTimer > 1.0 then
            vkbTryTimer = 0
            TryHookVKB()
        end
    end

    if updatePending then
        updateTimer = updateTimer + elapsed
        if updateTimer > 0.15 then
            if frame:IsVisible() then
                ForceOpenBags(mainBagsList)
                OrganizeItems()
            end
            if bankFrame:IsVisible() then
                ForceOpenBags(bankBagsList)
                OrganizeBankItems()
            end
            updatePending = false
            updateTimer = 0
        end
    end
end)