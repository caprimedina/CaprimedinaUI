local addonName, C = ...
_G.CapriUI = C -- (Opcional) Lo exponemos globalmente por si lo necesitas luego


_G.CapriUIState = _G.CapriUIState or { dragging = false, dragOwner = nil }


C.colorBg      = {0.10, 0.11, 0.12, 0.95}
C.colorKey     = {0.18, 0.19, 0.21, 1.00}
C.colorSpecial = {0.25, 0.27, 0.30, 1.00}
C.colorHover   = {0.35, 0.37, 0.40, 1.00}
C.colorPress   = {0.70, 0.75, 0.80, 1.00}
C.colorMenu    = {0.14, 0.15, 0.17, 0.98}


function C.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[CaprimedinaUI]|r " .. tostring(msg))
    end
end

function C.SetOutlineFont(fs, size)
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
end

function C.StyleWindow(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame:SetBackdropColor(unpack(C.colorBg))
end

function C.ApplyButtonAnimations(btn)
    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(C.colorHover)) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(self.defaultColor or C.colorKey)) end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(unpack(C.colorPress)) end)
    btn:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(unpack(C.colorHover))
        else
            self:SetBackdropColor(unpack(self.defaultColor or C.colorKey))
        end
    end)
end

function C.CreateStyledButton(parent, text, w, h, special)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, h)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    
    local col = special and C.colorSpecial or C.colorKey
    btn:SetBackdropColor(unpack(col))
    btn.defaultColor = col
    
    btn.text = btn:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(btn.text, 13)
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetText(text or "")
    
    
    btn.SetTextOriginal = btn.SetText
    btn.SetText = function(self, t) self.text:SetText(t) end
    
    C.ApplyButtonAnimations(btn)
    return btn
end

function C.CreateStyledClose(parent)
    local btn = C.CreateStyledButton(parent, "X", 40, 26, true)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    btn:SetScript("OnClick", function() parent:Hide() end)
    return btn
end


function C.InitDB()
    if type(CaprimedinaUIDB) ~= "table" then CaprimedinaUIDB = {} end
    local db = CaprimedinaUIDB
    
   
    if db.enableBags == nil then db.enableBags = true end
    if db.enableUI ~= nil and db.enableBars == nil then db.enableBars = db.enableUI end
    if db.enableBars == nil then db.enableBars = true end
    db.enableUI = db.enableBars
    if db.enableChat == nil then db.enableChat = true end
    if db.enableVida == nil then db.enableVida = true end
    if db.enabled == nil then db.enabled = true end 
    if db.enableEscala == nil then db.enableEscala = true end
    if db.enableSmartClick == nil then db.enableSmartClick = true end

    if db.escalaValor == nil then db.escalaValor = 1.0 end
    if db.minimapPos == nil then db.minimapPos = 45 end

    return db
end

-- ======================================================================
-- Skin compartido "estilo consola" (anillos dorados, discos y brillos)
-- Todas las texturas son creacion propia de Caprimedina y viven en texturas\.
-- ======================================================================
C.media = "Interface\\AddOns\\CaprimedinaUI\\texturas\\"
C.tex = {
    ring         = C.media .. "ring",
    ringPortrait = C.media .. "ring_portrait",
    disc         = C.media .. "disc",
    glow         = C.media .. "glow",
    barBg        = C.media .. "bar_bg",
    gloss        = C.media .. "gloss",
    ringThin     = C.media .. "ring_thin",
}

C.gold     = { 1.00, 0.84, 0.34 }
C.goldSoft = { 0.55, 0.45, 0.22 }

-- Anillo dorado centrado en parent.
function C.CreateRing(parent, size, texture, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture(texture or C.tex.ring)
    t:SetSize(size, size)
    t:SetPoint("CENTER", parent, "CENTER", 0, 0)
    return t
end

-- Disco oscuro centrado en parent.
function C.CreateDisc(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(C.tex.disc)
    t:SetSize(size, size)
    t:SetPoint("CENTER", parent, "CENTER", 0, 0)
    return t
end

-- Brillo dorado al pasar el raton por encima del boton.
function C.AddHoverGlow(btn, size, alpha)
    if not btn then return end
    if btn.capriHoverGlow then return btn.capriHoverGlow end

    local g = btn:CreateTexture(nil, "OVERLAY")
    g:SetTexture(C.tex.glow)
    g:SetSize(size, size)
    g:SetPoint("CENTER", btn, "CENTER", 0, 0)
    g:SetBlendMode("ADD")
    g:SetAlpha(0)
    btn.capriHoverGlow = g
    btn.capriHoverGlowAlpha = alpha or 0.55

    btn:HookScript("OnEnter", function(self)
        if self.capriHoverGlow then
            self.capriHoverGlow:SetAlpha(self.capriHoverGlowAlpha or 0.55)
        end
    end)

    btn:HookScript("OnLeave", function(self)
        if self.capriHoverGlow then
            self.capriHoverGlow:SetAlpha(0)
        end
    end)

    return g
end

-- Panel oscuro con borde dorado fino (estilo consola).
function C.SkinPanel(frame, small)
    local edge  = small and 8 or 12
    local inset = small and 2 or 3

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = false,
        edgeSize = edge,
        insets   = { left = inset, right = inset, top = inset, bottom = inset },
    })

    frame:SetBackdropColor(0.03, 0.025, 0.02, 0.92)
    frame:SetBackdropBorderColor(C.goldSoft[1], C.goldSoft[2], C.goldSoft[3], 0.95)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function()
    C.InitDB()
end)
