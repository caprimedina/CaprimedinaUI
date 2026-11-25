local addonName, C = ...
local _G = _G or getfenv(0)

local function AccionesDB()
    local db = CaprimedinaUIDB
    if db.botonesVisible == nil then db.botonesVisible = true end
    if not db.botonesScale or db.botonesScale <= 0 then db.botonesScale = 1.5 end
    if not db.botonesSeparacion or db.botonesSeparacion < 0 then db.botonesSeparacion = 10 end
    if db.botonesLayout ~= "recto" and db.botonesLayout ~= "triangulo" then
        -- Valor nuevo por defecto: triangulo.
        db.botonesLayout = "triangulo"
    end
    -- Migracion: valores antiguos -> nuevos por defecto.
    if db.botonesScale == 1.0 then db.botonesScale = 1.5 end
    if db.botonesLayout == "recto" then db.botonesLayout = "triangulo" end
    return db
end

local anchor = CreateFrame("Frame", "CapriAccionesAnchor", UIParent)
anchor:SetSize(230, 80)
anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5)
anchor:SetFrameStrata("BACKGROUND")
anchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
anchor:SetBackdropColor(0, 1, 0, 0)
anchor:SetBackdropBorderColor(0, 1, 0, 0)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:EnableMouse(false)
anchor:RegisterForDrag("LeftButton")
anchor.text = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
anchor.text:SetPoint("CENTER", anchor, "CENTER", 0, 0)
anchor.text:SetText("BOTONES\n(Click Der)")
anchor.text:Hide()
anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)

local frame = CreateFrame("Frame", "CapriBotonesAccion", UIParent)
frame:SetSize(230, 80)
frame:SetPoint("CENTER", anchor, "CENTER")
frame:SetFrameStrata("LOW")

local function AplicarBrillo(btn, texturePath)
    btn:SetPushedTexture(texturePath)
    if btn:GetPushedTexture() then btn:GetPushedTexture():SetAllPoints(btn) end
    if btn:GetNormalTexture() then btn:GetNormalTexture():SetAllPoints(btn) end
    
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(texturePath)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(btn)
    glow:SetVertexColor(1, 1, 1, 0.6)
    glow:Hide()
    btn.glow = glow
end

local CapriIsAttacking = false

local function UpdateAttackVisuals()
    if not CapriBtnMira then return end
    if CapriIsAttacking then
        if CapriBtnMira:GetNormalTexture() then CapriBtnMira:GetNormalTexture():SetVertexColor(1, 0.1, 0.1) end
    else
        if CapriBtnMira:GetNormalTexture() then CapriBtnMira:GetNormalTexture():SetVertexColor(1, 1, 1) end
    end
end

local attackTracker = CreateFrame("Frame")
attackTracker:RegisterEvent("PLAYER_ENTER_COMBAT")
attackTracker:RegisterEvent("PLAYER_LEAVE_COMBAT")
attackTracker:RegisterEvent("START_AUTOREPEAT_SPELL")
attackTracker:RegisterEvent("STOP_AUTOREPEAT_SPELL")
attackTracker:RegisterEvent("PLAYER_TARGET_CHANGED")
attackTracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local btnPushedTimer = 0
local function SyncButtonGlow(btn, elapsed)
    if not btn then return end
    -- Brillo solo mientras el boton esta pulsado. Al soltarlo se apaga en el
    -- acto (antes se quedaba 0.12 s encendido, y por eso se notaba el retraso).
    local pushed = (btn.GetButtonState and btn:GetButtonState() == "PUSHED")
    if btn.glow then
        if pushed then btn.glow:Show() else btn.glow:Hide() end
    end
    if btn.capriHoverGlow then
        if pushed then
            btn.capriHoverGlow:SetAlpha(btn.capriHoverGlowAlpha or 0.55)
        elseif not (btn.IsMouseOver and btn:IsMouseOver()) then
            btn.capriHoverGlow:SetAlpha(0)
        end
    end
end
attackTracker:SetScript("OnUpdate", function(self, elapsed)
    if btnPushedTimer > 0 then
        btnPushedTimer = btnPushedTimer - elapsed
        if btnPushedTimer <= 0 and CapriBtnAtacar then
            CapriBtnAtacar:SetButtonState("NORMAL")
            CapriBtnAtacar.glow:Hide()
        end
    end
    -- Sincronizar el brillo blanco/dorado con el estado del boton, de modo que
    -- al pulsar la tecla asignada (que deja el boton en PUSHED) tambien aparezca
    -- el brillo, igual que al hacer clic con el raton.
    -- (El boton de saltar NO se sincroniza: su brillo depende de JumpOrAscendStart.)
    SyncButtonGlow(CapriBtnAtacar, elapsed)
    SyncButtonGlow(CapriBtnMira, elapsed)
end)

attackTracker:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTER_COMBAT" or event == "START_AUTOREPEAT_SPELL" then
        CapriIsAttacking = true; UpdateAttackVisuals()
    elseif event == "PLAYER_LEAVE_COMBAT" or event == "STOP_AUTOREPEAT_SPELL" then
        CapriIsAttacking = false; UpdateAttackVisuals()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if not UnitExists("target") or UnitIsDead("target") then CapriIsAttacking = false; UpdateAttackVisuals() end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, sourceGUID = ...
        if sourceGUID == UnitGUID("player") then
            if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" or subEvent == "RANGE_DAMAGE" or subEvent == "RANGE_MISSED" then
                if CapriBtnAtacar then
                    CapriBtnAtacar:SetButtonState("PUSHED", true)
                    CapriBtnAtacar.glow:Show()
                    btnPushedTimer = 0.15 
                end
            end
        end
    end
end)

local btnAtacar = CreateFrame("Button", "CapriBtnAtacar", frame, "SecureActionButtonTemplate")
btnAtacar:SetSize(64, 64)
btnAtacar:SetPoint("LEFT", frame, "LEFT", 10, 0)
-- Icono por defecto del ataque automatico (espada blanca) cuando no hay arma.
local texAtacar = "Interface\\Icons\\INV_Sword_04"
btnAtacar:SetNormalTexture(texAtacar)
btnAtacar:SetAttribute("type", "macro")
btnAtacar:SetAttribute("macrotext", "/startattack")
AplicarBrillo(btnAtacar, texAtacar)

-- Icono del boton de ataque: muestra el arma equipada.
-- Cazador -> ranura de distancia (arco/ballesta); resto -> mano principal.
-- Si no hay textura directa, se consulta el enlace del objeto.
local function CapriTexturaRanura(ranura)
    local textura = GetInventoryItemTexture("player", ranura)
    if textura then return textura end

    local enlace = GetInventoryItemLink("player", ranura)
    local id = enlace and tonumber(enlace:match("item:(%d+)"))
    if id then
        local _, _, _, _, _, _, _, _, _, icono = GetItemInfo(id)
        if icono then return icono end
    end
    return nil
end

local function CapriIconoArma()
    local _, clase = UnitClass("player")
    local ranura = 16
    if clase == "HUNTER" then ranura = 18 end

    local textura = CapriTexturaRanura(ranura)
    -- Cazador sin arco equipado: usa el arma cuerpo a cuerpo.
    if not textura and ranura == 18 then textura = CapriTexturaRanura(16) end
    if not textura then
        -- Sin arma: icono del poder "Atacar" (espada blanca).
        if type(GetSpellTexture) == "function" then
            textura = GetSpellTexture("Attack") or GetSpellTexture(6603)
        end
        if not textura then textura = "Interface\\Icons\\INV_Sword_04" end
    end

    btnAtacar:SetNormalTexture(textura)
    btnAtacar:SetPushedTexture(textura)
    local normal, pushed = btnAtacar:GetNormalTexture(), btnAtacar:GetPushedTexture()
    if normal then normal:SetAllPoints(btnAtacar); normal:SetTexCoord(0, 1, 0, 1) end
    if pushed then pushed:SetAllPoints(btnAtacar); pushed:SetTexCoord(0, 1, 0, 1) end
    if btnAtacar.glow then
        btnAtacar.glow:SetTexture(textura)
        btnAtacar.glow:SetTexCoord(0, 1, 0, 1)
    end
end

local armaEventos = CreateFrame("Frame")
armaEventos:RegisterEvent("PLAYER_LOGIN")
armaEventos:RegisterEvent("PLAYER_ENTERING_WORLD")
armaEventos:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
armaEventos:SetScript("OnEvent", function() pcall(CapriIconoArma) end)

-- Reintento corto por si el inventario aun no esta listo al entrar.
local armaReintento = CreateFrame("Frame")
armaReintento.t = 1.0
armaReintento:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t - elapsed
    if self.t <= 0 then
        pcall(CapriIconoArma)
        self:SetScript("OnUpdate", nil)
    end
end)

-- Anillo dorado (estilo Caprimedina) y resplandor rojo del boton grande de ataque.
local RING = (C.tex and C.tex.ring) or "Interface\\AddOns\\CaprimedinaUI\\texturas\\ring"

local atacarGlow = btnAtacar:CreateTexture(nil, "BACKGROUND")
atacarGlow:SetTexture(RING)
atacarGlow:SetBlendMode("BLEND")
atacarGlow:SetVertexColor(0.95, 0.05, 0.05, 0.40)
btnAtacar.circGlow = atacarGlow

-- Anillo dorado fino en los botones redondos (sin disco: tapaba el icono).
local function CapriDressRound(btn, ringScale)
    if not btn then return end

    local size = (btn.GetWidth and btn:GetWidth()) or 64

    if not btn.capriRing then
        btn.capriRing = btn:CreateTexture(nil, "OVERLAY")
        btn.capriRing:SetTexture(RING)
        btn.capriRing:SetBlendMode("BLEND")
        if C.AddHoverGlow then
            C.AddHoverGlow(btn, size * 2.0, 0.45)
        end
    end

    btn.capriRing:ClearAllPoints()
    btn.capriRing:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.capriRing:SetSize(size * ringScale, size * ringScale)
end

btnAtacar:HookScript("OnMouseDown", function(self) self.glow:Show() end)
btnAtacar:HookScript("OnMouseUp",   function(self) self.glow:Hide() end)
btnAtacar:HookScript("OnLeave",     function(self) self.glow:Hide() end)

local btnMira = CreateFrame("Button", "CapriBtnMira", frame, "SecureActionButtonTemplate")
btnMira:SetSize(64, 64)
btnMira:SetPoint("LEFT", btnAtacar, "RIGHT", 10, 0)
local texMira = "Interface\\AddOns\\CaprimedinaUI\\texturas\\mira"
btnMira:SetNormalTexture(texMira)
btnMira:SetAttribute("type", "macro")
btnMira:SetAttribute("macrotext", "/targetenemy")
AplicarBrillo(btnMira, texMira)

btnMira:HookScript("OnMouseDown", function(self) self.glow:Show() end)
btnMira:HookScript("OnMouseUp",   function(self) self.glow:Hide() end)
btnMira:HookScript("OnLeave",     function(self) self.glow:Hide() end)

local btnSaltar = CreateFrame("Button", "CapriBtnSaltar", frame)
btnSaltar:SetSize(64, 64)
btnSaltar:SetPoint("LEFT", btnMira, "RIGHT", 10, 0)
local texSaltar = "Interface\\AddOns\\CaprimedinaUI\\texturas\\saltar"
btnSaltar:SetNormalTexture(texSaltar)
AplicarBrillo(btnSaltar, texSaltar)

-- El salto (JumpOrAscendStart) es una funcion protegida: ningun addon
-- puede provocarlo. Dejamos el boton como indicador visual; en el
-- cliente Android el toque se traduce al boton de salto del juego.
btnSaltar:EnableMouse(false)

hooksecurefunc("JumpOrAscendStart", function()
    if btnSaltar.glow then btnSaltar.glow:Show() end
    if btnSaltar.capriHoverGlow then btnSaltar.capriHoverGlow:SetAlpha(btnSaltar.capriHoverGlowAlpha or 0.55) end
end)
hooksecurefunc("AscendStop", function()
    if btnSaltar.glow then btnSaltar.glow:Hide() end
    if btnSaltar.capriHoverGlow and not (btnSaltar.IsMouseOver and btnSaltar:IsMouseOver()) then
        btnSaltar.capriHoverGlow:SetAlpha(0)
    end
end)

local function CrearHotKey(btn)
    local name = btn:GetName()
    if not name or _G[name .. "HotKey"] then return end
    local hk = btn:CreateFontString(name .. "HotKey", "OVERLAY")
    C.SetOutlineFont(hk, 12)
    hk:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -4)
    hk:SetTextColor(1, 1, 1)
    hk:SetText("")
    hk:Hide()
end
CrearHotKey(btnAtacar)
CrearHotKey(btnMira)

-- Fila recta: Atacar -> Objetivo -> Saltar.
local function LayoutRecto()
    local sep = AccionesDB().botonesSeparacion
    local big, med = 68, 56
    frame:SetSize(big + med * 2 + sep * 2, big)

    btnAtacar:SetSize(big, big); btnAtacar:ClearAllPoints(); btnAtacar:SetPoint("LEFT", frame, "LEFT", 0, 0)
    btnMira:SetSize(med, med); btnMira:ClearAllPoints(); btnMira:SetPoint("LEFT", btnAtacar, "RIGHT", sep, 0)
    btnSaltar:SetSize(med, med); btnSaltar:ClearAllPoints(); btnSaltar:SetPoint("LEFT", btnMira, "RIGHT", sep, 0)

    CapriDressRound(btnAtacar, 1.20)
    CapriDressRound(btnMira, 1.16)
    CapriDressRound(btnSaltar, 1.16)

    if btnAtacar.circGlow then
        btnAtacar.circGlow:ClearAllPoints()
        btnAtacar.circGlow:SetPoint("CENTER", btnAtacar, "CENTER", 0, 0)
        btnAtacar.circGlow:SetSize(big * 1.34, big * 1.34)
    end
end

-- Triangulo: apunta hacia la IZQUIERDA.
-- Atacar (grande) a la izquierda; Objetivo arriba-derecha; Saltar abajo-derecha.
local function LayoutTriangulo()
    local sep = AccionesDB().botonesSeparacion
    local big, med = 72, 56
    frame:SetSize(big + med + sep, med * 2 + sep)

    btnAtacar:SetSize(big, big); btnAtacar:ClearAllPoints(); btnAtacar:SetPoint("LEFT", frame, "LEFT", 0, 0)
    btnMira:SetSize(med, med); btnMira:ClearAllPoints(); btnMira:SetPoint("LEFT", btnAtacar, "RIGHT", sep, (med + sep) * 0.5)
    btnSaltar:SetSize(med, med); btnSaltar:ClearAllPoints(); btnSaltar:SetPoint("LEFT", btnAtacar, "RIGHT", sep, -(med + sep) * 0.5)

    CapriDressRound(btnAtacar, 1.20)
    CapriDressRound(btnMira, 1.16)
    CapriDressRound(btnSaltar, 1.16)

    if btnAtacar.circGlow then
        btnAtacar.circGlow:ClearAllPoints()
        btnAtacar.circGlow:SetPoint("CENTER", btnAtacar, "CENTER", 0, 0)
        btnAtacar.circGlow:SetSize(big * 1.34, big * 1.34)
    end
end

local function ApplyBotonesLayout()
    local db = AccionesDB()
    if db.botonesLayout == "triangulo" then LayoutTriangulo() else LayoutRecto() end
    anchor:SetSize(frame:GetWidth(), frame:GetHeight())

    if db.botonesVisible then frame:Show() else frame:Hide() end
    frame:SetScale(db.botonesScale)
    anchor:SetScale(db.botonesScale)
end

anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db = AccionesDB()
    db.accionesPoint, _, db.accionesRelPoint, db.accionesX, db.accionesY = self:GetPoint()
end)

local botonesMenu = CreateFrame("Frame", "CapriBotonesMenu", UIParent)
botonesMenu:SetFrameStrata("TOOLTIP")
botonesMenu:SetSize(300, 150)
botonesMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
C.StyleWindow(botonesMenu)
botonesMenu:SetMovable(true)
botonesMenu:EnableMouse(true)
botonesMenu:RegisterForDrag("LeftButton")
botonesMenu:SetScript("OnDragStart", function(self) self:StartMoving() end)
botonesMenu:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
botonesMenu:Hide()

local bmTitle = botonesMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bmTitle, 16)
bmTitle:SetPoint("TOP", botonesMenu, "TOP", 0, -15)
bmTitle:SetText("AJUSTES DE BOTONES")
bmTitle:SetTextColor(1, 1, 1)

local bmClose = C.CreateStyledClose(botonesMenu)

local bmLabel1 = botonesMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bmLabel1, 14); bmLabel1:SetPoint("TOPLEFT", 20, -45); bmLabel1:SetText("Escala:")
local bmScaleVal = botonesMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bmScaleVal, 14); bmScaleVal:SetPoint("TOPLEFT", 110, -45)

local bmScaleMinus = C.CreateStyledButton(botonesMenu, "-", 26, 22); bmScaleMinus:SetPoint("TOPLEFT", 160, -40)
local bmScalePlus = C.CreateStyledButton(botonesMenu, "+", 26, 22); bmScalePlus:SetPoint("TOPLEFT", 195, -40)

local bmLabel2 = botonesMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bmLabel2, 14); bmLabel2:SetPoint("TOPLEFT", 20, -75); bmLabel2:SetText("Separación:")
local bmSepVal = botonesMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bmSepVal, 14); bmSepVal:SetPoint("TOPLEFT", 110, -75)

local bmSepMinus = C.CreateStyledButton(botonesMenu, "-", 26, 22); bmSepMinus:SetPoint("TOPLEFT", 160, -70)
local bmSepPlus = C.CreateStyledButton(botonesMenu, "+", 26, 22); bmSepPlus:SetPoint("TOPLEFT", 195, -70)

local bmToggle = C.CreateStyledButton(botonesMenu, "Visible", 120, 22, true)
bmToggle:SetPoint("TOP", botonesMenu, "TOP", -65, -105)

local bmLayout = C.CreateStyledButton(botonesMenu, "Triángulo", 120, 22, true)
bmLayout:SetPoint("TOP", botonesMenu, "TOP", 65, -105)

local function BotonesMenuUpdate()
    local db = AccionesDB()
    bmScaleVal:SetText(string.format("%.2f", db.botonesScale))
    bmSepVal:SetText(string.format("%d", db.botonesSeparacion))
    bmToggle:SetText(db.botonesVisible and "|cff00ff00Visible|r" or "|cffff0000Oculto|r")
    bmLayout:SetText(db.botonesLayout == "triangulo" and "|cff00ccffTriángulo|r" or "|cff00ccffRecto|r")
end

local function BotonesAdjustScale(delta)
    local db = AccionesDB()
    local v = db.botonesScale + delta
    if v < 0.5 then v = 0.5 end
    if v > 2.5 then v = 2.5 end
    db.botonesScale = v
    ApplyBotonesLayout(); BotonesMenuUpdate()
end

local function BotonesAdjustSep(delta)
    local db = AccionesDB()
    local v = db.botonesSeparacion + delta
    if v < 0 then v = 0 end
    if v > 40 then v = 40 end
    db.botonesSeparacion = v
    ApplyBotonesLayout(); BotonesMenuUpdate()
end

local function BotonesMenuShow()
    BotonesMenuUpdate(); botonesMenu:Show()
end

bmScaleMinus:SetScript("OnClick", function() BotonesAdjustScale(-0.05) end)
bmScalePlus:SetScript("OnClick",  function() BotonesAdjustScale( 0.05) end)
bmSepMinus:SetScript("OnClick", function() BotonesAdjustSep(-2) end)
bmSepPlus:SetScript("OnClick",  function() BotonesAdjustSep( 2) end)

bmToggle:SetScript("OnClick", function()
    local db = AccionesDB(); db.botonesVisible = not db.botonesVisible
    ApplyBotonesLayout(); BotonesMenuUpdate()
end)

bmLayout:SetScript("OnClick", function()
    local db = AccionesDB()
    db.botonesLayout = (db.botonesLayout == "recto") and "triangulo" or "recto"
    ApplyBotonesLayout(); BotonesMenuUpdate()
end)

anchor:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and CapriMasterEditControl and CapriMasterEditControl:IsVisible() then BotonesMenuShow() end
end)

local origCapriEdit2 = SlashCmdList["CAPRIEDIT"]
SlashCmdList["CAPRIEDIT"] = function(msg)
    if origCapriEdit2 then origCapriEdit2(msg) end
    local editing = CapriMasterEditControl and CapriMasterEditControl:IsVisible()
    anchor:EnableMouse(editing)
    local alpha = editing and 0.6 or 0
    anchor:SetBackdropColor(0, 1, 0, alpha)
    anchor:SetBackdropBorderColor(0, 1, 0, alpha)
    if editing then anchor:SetFrameStrata("DIALOG"); anchor.text:Show() else anchor:SetFrameStrata("BACKGROUND"); anchor.text:Hide(); botonesMenu:Hide() end
end

SLASH_CAPRIBOTONES1 = "/botones"
SlashCmdList["CAPRIBOTONES"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "menu" or msg == "ajustes" or msg == "config" then BotonesMenuShow(); return end
    if msg == "reset" or msg == "reiniciar" then
        local db = AccionesDB()
        db.botonesScale, db.botonesSeparacion, db.botonesLayout, db.botonesVisible = 1.5, 10, "triangulo", true
        db.accionesPoint, db.accionesRelPoint, db.accionesX, db.accionesY = nil, nil, nil, nil
        anchor:SetScale(1.5); anchor:ClearAllPoints(); anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5); pcall(anchor.SetUserPlaced, anchor, false)
        ApplyBotonesLayout()
        C.Print("Botones restablecidos: modo Triángulo en la esquina inferior derecha.")
        return
    end
    local db = AccionesDB(); db.botonesVisible = not db.botonesVisible; ApplyBotonesLayout()
    C.Print("Botones: " .. (db.botonesVisible and "|cff00ff00Visible|r" or "|cffff0000Oculto|r"))
end

local function RegistrarEnBind()
    if type(CapriRegisterBindButton) ~= "function" then return false end
    CapriRegisterBindButton(btnAtacar, "CLICK CapriBtnAtacar:LeftButton")
    CapriRegisterBindButton(btnMira,   "CLICK CapriBtnMira:LeftButton")
    if type(CapriRefreshCustomHotkeys) == "function" then CapriRefreshCustomHotkeys() end
    return true
end

RegistrarEnBind()
local bindRegFrame = CreateFrame("Frame")
bindRegFrame:RegisterEvent("VARIABLES_LOADED")
bindRegFrame:RegisterEvent("PLAYER_LOGIN")
bindRegFrame:SetScript("OnEvent", function(self, event)
    if RegistrarEnBind() and event == "PLAYER_LOGIN" then self:UnregisterAllEvents() end
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
    local db = AccionesDB()

    if db.accionesPoint == "BOTTOMRIGHT" and db.accionesX == 0 and db.accionesY == 0 then
        db.accionesX = -5
        db.accionesY = 5
    end

    -- Migracion: posicion antigua -> bien al borde de la esquina inferior derecha.
    if db.accionesPoint == "BOTTOMRIGHT" and (db.accionesX == -30 or db.accionesX == -10) and (db.accionesY == 29 or db.accionesY == 10) then
        db.accionesX = -5
        db.accionesY = 5
    end

    if not anchor:IsUserPlaced() and not db.accionesPoint then
        anchor:ClearAllPoints(); anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5)
    elseif db.accionesPoint then
        anchor:ClearAllPoints(); anchor:SetPoint(db.accionesPoint, UIParent, db.accionesRelPoint, db.accionesX, db.accionesY)
    else
        anchor:ClearAllPoints(); anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5)
    end
    ApplyBotonesLayout()
end)

-- (Se removio la flecha roja sobre el objetivo; el boton solo selecciona objetivo.)