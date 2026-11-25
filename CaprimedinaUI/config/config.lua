local _G = _G or getfenv(0)
local C = _G.CapriUI

local function CreateSectionLabel(parent, text, yOffset)
    local label = parent:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(label, 13)
    label:SetPoint("TOP", parent, "TOP", 0, yOffset)
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0.4)
    return label
end

local function CreateSeparator(parent, yOffset)
    local line = parent:CreateTexture(nil, "OVERLAY")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetWidth(195)
    line:SetHeight(1)
    line:SetPoint("TOP", parent, "TOP", 0, yOffset)
    line:SetVertexColor(0.35, 0.37, 0.40, 0.85)
    return line
end

local function InitDB()
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    if CaprimedinaUIDB.enableBags == nil then
        CaprimedinaUIDB.enableBags = true
    end

    if CaprimedinaUIDB.enableBars == nil then
        if CaprimedinaUIDB.enableUI ~= nil then
            CaprimedinaUIDB.enableBars = CaprimedinaUIDB.enableUI
        else
            CaprimedinaUIDB.enableBars = true
        end
    end
    
    CaprimedinaUIDB.enableBars = (CaprimedinaUIDB.enableBars ~= false)
    CaprimedinaUIDB.enableUI = CaprimedinaUIDB.enableBars

    if CaprimedinaUIDB.enableChat == nil then
        CaprimedinaUIDB.enableChat = true
    end

    if CaprimedinaUIDB.enableVida == nil then
        CaprimedinaUIDB.enableVida = true
    end

    if CaprimedinaUIDB.enableVentanas == nil then
        CaprimedinaUIDB.enableVentanas = true
    end

    -- Escala maxima de las ventanas (auto-ajuste hasta llenar la pantalla).
    if CaprimedinaUIDB.ventanasScale == nil then
        CaprimedinaUIDB.ventanasScale = 2.2
    elseif CaprimedinaUIDB.ventanasScale == 1.35 then
        -- Migracion: valor antiguo por defecto (quedaba chico en Android).
        CaprimedinaUIDB.ventanasScale = 2.2
    end

    if CaprimedinaUIDB.enabled == nil then
        CaprimedinaUIDB.enabled = true
    end

    if CaprimedinaUIDB.minimapPos == nil then
        CaprimedinaUIDB.minimapPos = 45
    end

    if CaprimedinaUIDB.enableEscala == nil then
        CaprimedinaUIDB.enableEscala = true
    end

    if CaprimedinaUIDB.escalaValor == nil then
        CaprimedinaUIDB.escalaValor = 1.0
    end

    if CaprimedinaUIDB.enableSmartClick == nil then
        CaprimedinaUIDB.enableSmartClick = true
    end
end

local function CapriSetCVarSafe(cvar, value)
    if type(SetCVar) == "function" then
        pcall(SetCVar, cvar, value)
    end
end

local function UpdateMinimapButtonPosition()
    if not CapriMinimapBtn then
        return
    end

    local angle = (CaprimedinaUIDB and CaprimedinaUIDB.minimapPos) or 45

    if type(angle) ~= "number" or angle ~= angle then
        angle = 45
    end

    local x = math.cos(math.rad(angle)) * 80
    local y = math.sin(math.rad(angle)) * 80

    CapriMinimapBtn:ClearAllPoints()
    CapriMinimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function CaprimedinaApplyEscala(enabled, value)
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    if CaprimedinaUIDB.enableEscala == nil then
        CaprimedinaUIDB.enableEscala = true
    end

    if CaprimedinaUIDB.escalaValor == nil then
        CaprimedinaUIDB.escalaValor = 1.0
    end

    local v = tonumber(value or CaprimedinaUIDB.escalaValor) or 1.0

    if v < 0.5 then
        v = 0.5
    end

    if v > 3.0 then
        v = 3.0
    end

    CaprimedinaUIDB.escalaValor = v

    if enabled == nil then
        enabled = CaprimedinaUIDB.enableEscala
    end

    CaprimedinaUIDB.enableEscala = enabled and true or false

    if enabled then
        UIParent:SetScale(v)
        CapriSetCVarSafe("useUiScale", "1")
        CapriSetCVarSafe("uiscale", tostring(v))
    else
        UIParent:SetScale(1.0)
        CapriSetCVarSafe("useUiScale", "0")
        CapriSetCVarSafe("uiscale", "1")
    end

    if UIEscaladorFrame and UIEscaladorFrame.UpdateFromDB then
        UIEscaladorFrame:UpdateFromDB()
    end
end

local CoreInit = CreateFrame("Frame")
CoreInit:RegisterEvent("VARIABLES_LOADED")
CoreInit:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        InitDB()
        CaprimedinaApplyEscala(CaprimedinaUIDB.enableEscala, CaprimedinaUIDB.escalaValor)
        UpdateMinimapButtonPosition()
    end
end)

if not StaticPopupDialogs then
    StaticPopupDialogs = {}
end

StaticPopupDialogs["CAPRI_RELOAD_UI"] = {
    text = "Has cambiado la configuracion de los modulos.\n\nSe requiere recargar la interfaz para aplicar los cambios.",
    button1 = "Recargar Ahora",
    button2 = "Mas Tarde",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local ConfigMenu = CreateFrame("Frame", "CapriMasterConfigMenu", UIParent)
ConfigMenu:SetFrameStrata("DIALOG")
ConfigMenu:SetWidth(240)
ConfigMenu:SetHeight(480)
ConfigMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
C.StyleWindow(ConfigMenu)
ConfigMenu:SetClampedToScreen(true)
ConfigMenu:Hide()

local menuTitle = ConfigMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(menuTitle, 16)
menuTitle:SetPoint("TOP", ConfigMenu, "TOP", 0, -12)
menuTitle:SetText("Caprimedina UI")
menuTitle:SetTextColor(1, 1, 1)

local closeX = C.CreateStyledClose(ConfigMenu)

CreateSectionLabel(ConfigMenu, "Modulos ON/OFF", -38)
CreateSeparator(ConfigMenu, -54)

local function CreateToggleBtn(parent, text, dbKey, yOffset)
    local btn = C.CreateStyledButton(parent, text, 195, 26)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)

    btn.UpdateState = function(self)
        if CaprimedinaUIDB and CaprimedinaUIDB[dbKey] then
            self:SetText(text .. ": |cff00ff00ON|r")
        else
            self:SetText(text .. ": |cffff0000OFF|r")
        end
    end

    btn:SetScript("OnClick", function(self)
        if type(CaprimedinaUIDB) ~= "table" then
            CaprimedinaUIDB = {}
        end

        CaprimedinaUIDB[dbKey] = not CaprimedinaUIDB[dbKey]

        if dbKey == "enableBars" then
            CaprimedinaUIDB.enableUI = CaprimedinaUIDB.enableBars
        end

        self:UpdateState()
        StaticPopup_Show("CAPRI_RELOAD_UI")
    end)

    return btn
end

local btnBags   = CreateToggleBtn(ConfigMenu, "Mochila y Banco", "enableBags", -62)
local btnBars   = CreateToggleBtn(ConfigMenu, "Interfaz UI", "enableBars", -92)
local btnUI     = CreateToggleBtn(ConfigMenu, "Chat", "enableChat", -122)
local btnVida   = CreateToggleBtn(ConfigMenu, "Vida", "enableVida", -152)
local btnVentanas = CreateToggleBtn(ConfigMenu, "Ventanas Grandes", "enableVentanas", -182)
local btnSmart  = CreateToggleBtn(ConfigMenu, "Click Inteligente", "enableSmartClick", -212)

local btnVKB = C.CreateStyledButton(ConfigMenu, "Teclado Virtual", 195, 26)
btnVKB:SetPoint("TOP", ConfigMenu, "TOP", 0, -242)

btnVKB.UpdateState = function(self)
    local on = CaprimedinaUIDB and CaprimedinaUIDB.enabled
    self:SetText("Teclado Virtual: " .. (on and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end

btnVKB:SetScript("OnClick", function(self)
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    if SlashCmdList and type(SlashCmdList["VKB_TOGGLE"]) == "function" then
        SlashCmdList["VKB_TOGGLE"]()
    else
        CaprimedinaUIDB.enabled = not CaprimedinaUIDB.enabled
        StaticPopup_Show("CAPRI_RELOAD_UI")
    end

    self:UpdateState()
end)

local btnEscala = C.CreateStyledButton(ConfigMenu, "Escala UI", 195, 26)
btnEscala:SetPoint("TOP", ConfigMenu, "TOP", 0, -272)

btnEscala.UpdateState = function(self)
    local on = CaprimedinaUIDB and CaprimedinaUIDB.enableEscala
    self:SetText("Escala UI: " .. (on and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end

btnEscala:SetScript("OnClick", function(self)
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    CaprimedinaUIDB.enableEscala = not CaprimedinaUIDB.enableEscala
    CaprimedinaApplyEscala(CaprimedinaUIDB.enableEscala, CaprimedinaUIDB.escalaValor)
    self:UpdateState()
end)

CreateSectionLabel(ConfigMenu, "Abrir Interfaces", -306)
CreateSeparator(ConfigMenu, -322)

local btnEdit = C.CreateStyledButton(ConfigMenu, "Barras de accion", 195, 26, true)
btnEdit:SetPoint("TOP", ConfigMenu, "TOP", 0, -330)
btnEdit:SetScript("OnClick", function()
    if SlashCmdList and type(SlashCmdList["CAPRIEDIT"]) == "function" then
        SlashCmdList["CAPRIEDIT"]()
        ConfigMenu:Hide()
    else
        C.Print("|cffff0000El modulo de Barras de accion aun no esta cargado.|r")
    end
end)

local btnBind = C.CreateStyledButton(ConfigMenu, "Asignar Teclas", 195, 26, true)
btnBind:SetPoint("TOP", ConfigMenu, "TOP", 0, -360)
btnBind:SetScript("OnClick", function()
    if SlashCmdList and type(SlashCmdList["CAPRIBIND"]) == "function" then
        SlashCmdList["CAPRIBIND"]()
        ConfigMenu:Hide()
    else
        C.Print("|cffff0000El modulo de asignar teclas aun no esta cargado.|r")
    end
end)

local btnEscalaOpen = C.CreateStyledButton(ConfigMenu, "Abrir Escala", 195, 26, true)
btnEscalaOpen:SetPoint("TOP", ConfigMenu, "TOP", 0, -390)
btnEscalaOpen:SetScript("OnClick", function()
    if UIEscaladorFrame then
        if UIEscaladorFrame.Refresh then
            UIEscaladorFrame:Refresh()
        end

        UIEscaladorFrame:Show()
        ConfigMenu:Hide()
    elseif SlashCmdList and type(SlashCmdList["UIESCALADOR"]) == "function" then
        SlashCmdList["UIESCALADOR"]()
        ConfigMenu:Hide()
    else
        C.Print("|cffff0000El modulo Escala no esta cargado.|r")
    end
end)

local btnSmartCfg = C.CreateStyledButton(ConfigMenu, "Configurar SmartClick", 195, 26, true)
btnSmartCfg:SetPoint("TOP", ConfigMenu, "TOP", 0, -420)
btnSmartCfg:SetScript("OnClick", function()
    if CaprimedinaUIDB and CaprimedinaUIDB.enableSmartClick == false then
        C.Print("|cffff0000El modulo SmartClick esta apagado. Enciendelo primero.|r")
    elseif CapriSmartClickMenu then
        CapriSmartClickMenu:Show()
        ConfigMenu:Hide()
    else
        C.Print("|cffff0000SmartClick no esta instalado o cargado.|r")
    end
end)

ConfigMenu:SetScript("OnShow", function()
    btnBags:UpdateState()
    btnBars:UpdateState()
    btnUI:UpdateState()
    btnVida:UpdateState()
    btnVentanas:UpdateState()
    btnSmart:UpdateState()
    btnVKB:UpdateState()
    btnEscala:UpdateState()
end)


CapriMinimapBtn = CreateFrame("Button", "CapriMinimapBtn", Minimap)
CapriMinimapBtn:SetWidth(32)
CapriMinimapBtn:SetHeight(32)
CapriMinimapBtn:SetFrameStrata("HIGH")
CapriMinimapBtn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
CapriMinimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
CapriMinimapBtn:RegisterForDrag("LeftButton")

CapriMinimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()

    self:SetScript("OnUpdate", function(btn)
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()

        if not scale or scale == 0 then
            scale = 1
        end

        local cx = (Minimap:GetLeft() or 0) + (Minimap:GetWidth() / 2)
        local cy = (Minimap:GetBottom() or 0) + (Minimap:GetHeight() / 2)
        local angle = math.deg(math.atan2((ypos / scale) - cy, (xpos / scale) - cx))

        if type(angle) ~= "number" or angle ~= angle then
            angle = 45
        end

        if type(CaprimedinaUIDB) ~= "table" then
            CaprimedinaUIDB = {}
        end

        CaprimedinaUIDB.minimapPos = angle

        btn:ClearAllPoints()
        btn:SetPoint(
            "CENTER",
            Minimap,
            "CENTER",
            math.cos(math.rad(angle)) * 80,
            math.sin(math.rad(angle)) * 80
        )
    end)
end)

CapriMinimapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

CapriMinimapBtn:SetScript("OnClick", function(self)
    if ConfigMenu:IsVisible() then
        ConfigMenu:Hide()
    else
        ConfigMenu:ClearAllPoints()
        ConfigMenu:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", 0, 0)
        ConfigMenu:Show()
    end
end)

CapriMinimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Caprimedina UI", 1, 0.8, 0)
    GameTooltip:AddLine("Click para abrir menu", 1, 1, 1)
    GameTooltip:AddLine("Arrastra para mover el boton", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

CapriMinimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local mIcon = CapriMinimapBtn:CreateTexture(nil, "BACKGROUND")
mIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
mIcon:SetWidth(20)
mIcon:SetHeight(20)
mIcon:SetPoint("CENTER", CapriMinimapBtn, "CENTER", 0, 0)

local mBorder = CapriMinimapBtn:CreateTexture(nil, "OVERLAY")
mBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mBorder:SetWidth(54)
mBorder:SetHeight(54)
mBorder:SetPoint("TOPLEFT", CapriMinimapBtn, "TOPLEFT", 0, 0)

CapriMinimapBtn:Show()
UpdateMinimapButtonPosition()


local function CapriPerfApply()
    CapriSetCVarSafe("rotateMinimap", "0")
    CapriSetCVarSafe("farclip", "500")
    CapriSetCVarSafe("horizonfarclip", "700")
    CapriSetCVarSafe("unitDrawDist", "60")
    CapriSetCVarSafe("terrainMip", "1")
    CapriSetCVarSafe("baseMip", "1")
    CapriSetCVarSafe("specular", "0")
    CapriSetCVarSafe("pixelShaders", "0")
    CapriSetCVarSafe("vertexAnimation", "0")
    CapriSetCVarSafe("particleDensity", "0.5")
    CapriSetCVarSafe("maxFPS", "60")

    C.Print("Modo rendimiento APLICADO. (Se guarda solo, no lo repitas)")
end

if not SlashCmdList then
    SlashCmdList = {}
end

SLASH_CAPRIPERF1 = "/perf"
SlashCmdList["CAPRIPERF"] = function()
    CapriPerfApply()
end