local addonName, C = ...
local _G = _G or getfenv(0)

local MAX_OFFSET = 85

local DPAD_TEXTURE = "Interface\\AddOns\\CaprimedinaUI\\texturas\\ring_thin"

local function DpadDB()
    local db = CaprimedinaUIDB
    if db.dpadVisible == nil then db.dpadVisible = true end
    if not db.dpadScale or db.dpadScale <= 0 then db.dpadScale = 1.0 end
    if not db.dpadAlpha or db.dpadAlpha <= 0 then db.dpadAlpha = 0.3 end
    return db
end

local function CreateJoystickTexture(parent, size, texturePath, alpha, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(texturePath)
    t:SetSize(size, size)
    t:SetPoint("CENTER", parent, "CENTER", 0, 0)
    t:SetVertexColor(1, 1, 1, alpha or 1)
    return t
end

local dpadAnchor = CreateFrame("Frame", "CapriDPadAnchor", UIParent)
dpadAnchor:SetSize(290, 290)
dpadAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 29, 29)
dpadAnchor:SetFrameStrata("BACKGROUND")
dpadAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
dpadAnchor:SetBackdropColor(0, 1, 0, 0)
dpadAnchor:SetBackdropBorderColor(0, 1, 0, 0)
dpadAnchor:SetMovable(true)
dpadAnchor:SetClampedToScreen(true) 
dpadAnchor:EnableMouse(false)
dpadAnchor:RegisterForDrag("LeftButton")

dpadAnchor.text = dpadAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dpadAnchor.text:SetPoint("CENTER", dpadAnchor, "CENTER", 0, 0)
dpadAnchor.text:SetText("JOYSTICK\n(Click Der)")
dpadAnchor.text:Hide()

local stick = CreateFrame("Frame", "CapriDPad", UIParent)
stick:SetSize(290, 290)
stick:SetPoint("CENTER", dpadAnchor, "CENTER")
stick:SetFrameStrata("LOW")
stick:EnableMouse(false)

-- Dos anillos finos dorados, sin letras, como en la referencia movil.
local outerRing = CreateJoystickTexture(stick, 270, DPAD_TEXTURE, 0.95, "ARTWORK")
outerRing:SetVertexColor(1, 0.86, 0.40, 0.95)

local knobFrame = CreateFrame("Frame", nil, stick)
knobFrame:SetSize(106, 106)
knobFrame:SetPoint("CENTER", stick, "CENTER", 0, 0)
knobFrame:SetFrameLevel(stick:GetFrameLevel() + 2)

local knobRing = CreateJoystickTexture(knobFrame, 96, DPAD_TEXTURE, 0.95, "OVERLAY")
knobRing:SetVertexColor(1, 0.86, 0.40, 0.95)

-- Sombra y halo del circulo interior. Al mover la palanca, el circulo
-- "sobresale" (crece un poco, se ilumina y deja sombra debajo), como el
-- stick de un dpad nativo de Android. Quieto queda exactamente igual.
local knobShadow = CreateJoystickTexture(knobFrame, 100,
    "Interface\\AddOns\\CaprimedinaUI\\texturas\\disc", 0, "BACKGROUND")
knobShadow:SetVertexColor(0, 0, 0, 0)
knobShadow:SetPoint("CENTER", knobFrame, "CENTER", 0, -4)

local knobGlow = CreateJoystickTexture(knobFrame, 132,
    "Interface\\AddOns\\CaprimedinaUI\\texturas\\glow", 0, "ARTWORK")
knobGlow:SetVertexColor(1, 0.86, 0.40, 0)

-- 0 = quieto, 1 = palanca al maximo. Se anima suavemente en OnUpdate.
local knobPop, knobPopTarget = 0, 0
local KNOB_POP_SCALE = 0.16

local function ApplyKnobPop()
    knobFrame:SetScale(1 + KNOB_POP_SCALE * knobPop)
    knobRing:SetVertexColor(
        1,
        0.86 + 0.12 * knobPop,
        0.40 + 0.30 * knobPop,
        0.95 + 0.05 * knobPop
    )
    knobGlow:SetVertexColor(1, 0.86, 0.40, 0.55 * knobPop)
    knobShadow:SetVertexColor(0, 0, 0, 0.45 * knobPop)
end

ApplyKnobPop()

local kUp, kDown, kLeft, kRight = false, false, false, false

local function KeyboardKnob()
    local dx, dy = 0, 0
    if kUp then dy = dy + 1 end
    if kDown then dy = dy - 1 end
    if kLeft then dx = dx - 1 end
    if kRight then dx = dx + 1 end

    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.7071
        dy = dy * 0.7071
    end
    knobFrame:ClearAllPoints()
    knobFrame:SetPoint("CENTER", stick, "CENTER", dx * MAX_OFFSET, dy * MAX_OFFSET)

    -- Cuanto mas lejos del centro, mas sobresale el circulo.
    local m = math.sqrt(dx * dx + dy * dy)
    if m > 1 then m = 1 end
    knobPopTarget = m
end

-- Animacion del "sobresalir": sube y baja suave, sin saltos.
stick:SetScript("OnUpdate", function(self, elapsed)
    if knobPop == knobPopTarget then return end
    local step = (elapsed or 0.016) * 9
    local diff = knobPopTarget - knobPop
    if math.abs(diff) <= step then
        knobPop = knobPopTarget
    else
        knobPop = knobPop + (diff > 0 and step or -step)
    end
    ApplyKnobPop()
end)

hooksecurefunc("MoveForwardStart",  function() kUp = true    KeyboardKnob() end)
hooksecurefunc("MoveForwardStop",   function() kUp = false   KeyboardKnob() end)
hooksecurefunc("MoveBackwardStart", function() kDown = true  KeyboardKnob() end)
hooksecurefunc("MoveBackwardStop",  function() kDown = false KeyboardKnob() end)
hooksecurefunc("TurnLeftStart",     function() kLeft = true  KeyboardKnob() end)
hooksecurefunc("TurnLeftStop",      function() kLeft = false KeyboardKnob() end)
hooksecurefunc("StrafeLeftStart",   function() kLeft = true  KeyboardKnob() end)
hooksecurefunc("StrafeLeftStop",    function() kLeft = false KeyboardKnob() end)
hooksecurefunc("TurnRightStart",    function() kRight = true  KeyboardKnob() end)
hooksecurefunc("TurnRightStop",     function() kRight = false KeyboardKnob() end)
hooksecurefunc("StrafeRightStart",  function() kRight = true  KeyboardKnob() end)
hooksecurefunc("StrafeRightStop",   function() kRight = false KeyboardKnob() end)

local function ApplyDPadLayout()
    local db = DpadDB()
    if db.dpadVisible then stick:Show() else stick:Hide() end
    stick:SetScale(db.dpadScale)
    stick:SetAlpha(db.dpadAlpha)
    dpadAnchor:SetScale(db.dpadScale)
end

local dpadMenu = CreateFrame("Frame", "CapriDPadMenu", UIParent)
dpadMenu:SetFrameStrata("TOOLTIP")
dpadMenu:SetSize(300, 160)
dpadMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
C.StyleWindow(dpadMenu)
dpadMenu:SetMovable(true)
dpadMenu:EnableMouse(true)
dpadMenu:RegisterForDrag("LeftButton")
dpadMenu:SetScript("OnDragStart", function(self) self:StartMoving() end)
dpadMenu:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
dpadMenu:Hide()

local dmTitle = dpadMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(dmTitle, 16)
dmTitle:SetPoint("TOP", dpadMenu, "TOP", 0, -15)
dmTitle:SetText("AJUSTES DE JOYSTICK")
dmTitle:SetTextColor(1, 1, 1)

local dmClose = C.CreateStyledClose(dpadMenu)

local dmScaleVal = dpadMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(dmScaleVal, 14)
local dmAlphaVal = dpadMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(dmAlphaVal, 14)

local dmToggle = C.CreateStyledButton(dpadMenu, "Visible", 120, 22, true)

local function DpadMenuUpdate()
    local db = DpadDB()
    dmScaleVal:SetText(string.format("%.2f", db.dpadScale))
    dmAlphaVal:SetText(string.format("%.0f%%", db.dpadAlpha * 100))
    dmToggle:SetText(db.dpadVisible and "|cff00ff00Visible|r" or "|cffff0000Oculto|r")
end

local function DpadAdjustScale(delta)
    local db = DpadDB()
    local v = db.dpadScale + delta
    if v < 0.5 then v = 0.5 end
    if v > 2.0 then v = 2.0 end
    db.dpadScale = v
    ApplyDPadLayout(); DpadMenuUpdate()
end

local function DpadAdjustAlpha(delta)
    local db = DpadDB()
    local v = db.dpadAlpha + delta
    if v < 0.1 then v = 0.1 end
    if v > 1.0 then v = 1.0 end
    db.dpadAlpha = v
    ApplyDPadLayout(); DpadMenuUpdate()
end

local dmLabel1 = dpadMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(dmLabel1, 14); dmLabel1:SetPoint("TOPLEFT", 20, -45); dmLabel1:SetText("Escala:")
dmScaleVal:SetPoint("TOPLEFT", 110, -45)

local dmScaleMinus = C.CreateStyledButton(dpadMenu, "-", 26, 22); dmScaleMinus:SetPoint("TOPLEFT", 160, -40)
dmScaleMinus:SetScript("OnClick", function() DpadAdjustScale(-0.05) end)

local dmScalePlus = C.CreateStyledButton(dpadMenu, "+", 26, 22); dmScalePlus:SetPoint("TOPLEFT", 195, -40)
dmScalePlus:SetScript("OnClick", function() DpadAdjustScale(0.05) end)

local dmLabel2 = dpadMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(dmLabel2, 14); dmLabel2:SetPoint("TOPLEFT", 20, -80); dmLabel2:SetText("Opacidad:")
dmAlphaVal:SetPoint("TOPLEFT", 110, -80)

local dmAlphaMinus = C.CreateStyledButton(dpadMenu, "-", 26, 22); dmAlphaMinus:SetPoint("TOPLEFT", 160, -75)
dmAlphaMinus:SetScript("OnClick", function() DpadAdjustAlpha(-0.05) end)

local dmAlphaPlus = C.CreateStyledButton(dpadMenu, "+", 26, 22); dmAlphaPlus:SetPoint("TOPLEFT", 195, -75)
dmAlphaPlus:SetScript("OnClick", function() DpadAdjustAlpha(0.05) end)

dmToggle:SetPoint("TOP", dpadMenu, "TOP", 0, -115)
dmToggle:SetScript("OnClick", function()
    local db = DpadDB()
    db.dpadVisible = not db.dpadVisible
    ApplyDPadLayout(); DpadMenuUpdate()
end)

dpadAnchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
dpadAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    CaprimedinaUIDB.dpadPoint, CaprimedinaUIDB.dpadRelPoint, CaprimedinaUIDB.dpadX, CaprimedinaUIDB.dpadY = point, relPoint, x, y
end)
dpadAnchor:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and CapriMasterEditControl and CapriMasterEditControl:IsVisible() then DpadMenuUpdate(); dpadMenu:Show() end
end)

local origCapriEdit = SlashCmdList["CAPRIEDIT"]
SlashCmdList["CAPRIEDIT"] = function(msg)
    if origCapriEdit then origCapriEdit(msg) end
    local editing = CapriMasterEditControl and CapriMasterEditControl:IsVisible()
    dpadAnchor:EnableMouse(editing)
    local alpha = editing and 0.6 or 0
    dpadAnchor:SetBackdropColor(0, 1, 0, alpha)
    dpadAnchor:SetBackdropBorderColor(0, 1, 0, alpha)
    if editing then dpadAnchor:SetFrameStrata("DIALOG"); dpadAnchor.text:Show(); stick:EnableMouse(false) 
    else dpadAnchor:SetFrameStrata("BACKGROUND"); dpadAnchor.text:Hide(); dpadMenu:Hide(); stick:EnableMouse(false) end
end

SLASH_CAPRIDPAD1 = "/dpad"
SlashCmdList["CAPRIDPAD"] = function()
    local db = DpadDB(); db.dpadVisible = not db.dpadVisible
    ApplyDPadLayout()
    C.Print("Joystick: " .. (db.dpadVisible and "|cff00ff00Visible|r" or "|cffff0000Oculto|r"))
end

local dpadInit = CreateFrame("Frame")
dpadInit:RegisterEvent("VARIABLES_LOADED")
dpadInit:SetScript("OnEvent", function()
    local db = DpadDB()

    -- Rediseno movil: el joystick pasa de la mitad izquierda a la
    -- esquina inferior izquierda.
    if db.dpadPoint == "LEFT" then
        db.dpadPoint = "BOTTOMLEFT"
        db.dpadRelPoint = "BOTTOMLEFT"
        db.dpadX = 29
        db.dpadY = 29
    end

    -- Segundo paso: joystick mas grande, pegado a la esquina.
    if db.dpadPoint == "BOTTOMLEFT" and db.dpadX == 55 and db.dpadY == 110 then
        db.dpadX = 29
        db.dpadY = 29
    end

    if db.dpadPoint then
        dpadAnchor:ClearAllPoints()
        dpadAnchor:SetPoint(db.dpadPoint, UIParent, db.dpadRelPoint, db.dpadX, db.dpadY)
    end
    ApplyDPadLayout()
end)