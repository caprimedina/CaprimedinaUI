local addonName, C = ...
C = C or _G.CapriUI or {}
_G.CapriUI = C

local _G = _G or getfenv(0)

CaprimedinaUIDB = CaprimedinaUIDB or {}

local function CapriUIEnabled()
    return type(CaprimedinaUIDB) == "table" and CaprimedinaUIDB.enableBars ~= false
end

local function CallCapriEdit()
    if SlashCmdList and type(SlashCmdList.CAPRIEDIT) == "function" then
        SlashCmdList.CAPRIEDIT()
    end
end

local function CreateStaticAnchor(name, width, height, point, relativePoint, x, y)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetWidth(width)
    f:SetHeight(height)
    f:SetPoint(point, UIParent, relativePoint, x, y)
    f:SetFrameStrata("BACKGROUND")
    return f
end

local CapriDragLeft  = CreateStaticAnchor("CapriDragLeft", 90, 50, "CENTER", "CENTER", 0, 140)
local CapriDragBL    = CreateStaticAnchor("CapriDragBL", 90, 50, "CENTER", "CENTER", 0, 70)
local CapriDragMain  = CreateStaticAnchor("CapriDragMain", 90, 50, "CENTER", "CENTER", 0, 0)
local CapriDragBR    = CreateStaticAnchor("CapriDragBR", 90, 50, "CENTER", "CENTER", 0, -70)
local CapriDragRight = CreateStaticAnchor("CapriDragRight", 90, 50, "CENTER", "CENTER", 0, -140)

local CapriTooltipAnchor = CreateStaticAnchor("CapriTooltipAnchor", 150, 30, "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 20)
local CapriPlayerAnchor  = CreateStaticAnchor("CapriPlayerAnchor", 232, 100, "TOPLEFT", "TOPLEFT", 20, -20)
local CapriTargetAnchor  = CreateStaticAnchor("CapriTargetAnchor", 232, 100, "TOPLEFT", "TOPLEFT", 270, -20)
local CapriMinimapAnchor = CreateStaticAnchor("CapriMinimapAnchor", 150, 150, "TOPRIGHT", "TOPRIGHT", -15, -15)

BINDING_HEADER_CAPRICONTROLLER = "Caprimedina Tutoriales UI"

if type(GameTooltip_SetDefaultAnchor) == "function" then
    local orig_GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor

    function GameTooltip_SetDefaultAnchor(tooltip, parent)
        orig_GameTooltip_SetDefaultAnchor(tooltip, parent)

        if tooltip and CapriUIEnabled() and CapriTooltipAnchor then
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", CapriTooltipAnchor, "BOTTOMRIGHT", 0, 0)
            tooltip:SetScale(CaprimedinaUIDB.ttScale or 1.0)
        end
    end
end

local expText

local function EnsureExpText()
    if expText or not MainMenuExpBar then
        return
    end

    expText = MainMenuExpBar:CreateFontString("CapriExpText", "OVERLAY", "GameFontHighlightSmall")
    expText:SetPoint("CENTER", MainMenuExpBar, "CENTER", 0, 1)
end

local function UpdateExpBarText()
    if not CapriUIEnabled() then
        if expText then
            expText:SetText("")
            expText:Hide()
        end
        return
    end

    EnsureExpText()

    if not expText then
        return
    end

    expText:Show()

    local curr = UnitXP("player") or 0
    local max = UnitXPMax("player") or 0

    if max == 0 then
        max = 1
    end

    local rest = GetXPExhaustion()
    local remaining = max - curr
    local pct = math.floor((curr / max) * 100)
    local text = string.format("%d / %d (%d faltante) - %d%%", curr, max, remaining, pct)

    if rest and rest > 0 then
        local restPct = math.floor((rest / max) * 100)
        text = text .. string.format(" |cff00ccffZzz: %d (%d%%)|r", rest, restPct)
    end

    expText:SetText(text)
end

local function InitUIDefaults()
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    local db = CaprimedinaUIDB

    if db.spinAnim == nil then db.spinAnim = true end

    -- Escala inicial de las bolas Jugador/Objetivo: 1.50 para que se vean
    -- bien en pantallas tactiles (Winlator/Android). Se aplica una sola vez
    -- (version 2); despues manda lo que el usuario elija en el menu.
    if db.unitScaleVer ~= 2 then
        db.unitScaleVer = 2

        if db.playerScale == nil or db.playerScale == 1.0 then
            db.playerScale = 1.50
        end

        if db.targetScale == nil or db.targetScale == 1.0 then
            db.targetScale = 1.50
        end

        -- Con la bola del jugador mas grande, el objetivo en su posicion
        -- original (270) quedaria encima. Se separa solo si sigue en el
        -- sitio por defecto; si el usuario ya lo movio, se respeta.
        if db.targetX == nil or db.targetX == 270 then
            db.targetX = 390
        end
    end

    if db.ttScale == nil then db.ttScale = 1.0 end
    if db.minimapScale == nil then db.minimapScale = 1.0 end

    local anchorDefaults = {
        dragLeft = { p = "CENTER", x = 0, y = 140 },
        dragBL = { p = "CENTER", x = 0, y = 70 },
        dragMain = { p = "CENTER", x = 0, y = 0 },
        dragBR = { p = "CENTER", x = 0, y = -70 },
        dragRight = { p = "CENTER", x = 0, y = -140 },
        ttAnchor = { p = "BOTTOMRIGHT", x = -20, y = 20 },
        player = { p = "TOPLEFT", x = 20, y = -20 },
        target = { p = "TOPLEFT", x = 270, y = -20 },
        minimap = { p = "TOPRIGHT", x = -15, y = -15 },
    }

    for prefix, def in pairs(anchorDefaults) do
        if db[prefix .. "Point"] == nil then
            db[prefix .. "Point"] = def.p
            db[prefix .. "RelPoint"] = def.p
            db[prefix .. "X"] = def.x
            db[prefix .. "Y"] = def.y
        end
    end
end

local function ApplyPoint(frame, prefix)
    if not frame or not CaprimedinaUIDB then
        return
    end

    local point = CaprimedinaUIDB[prefix .. "Point"]
    local relPoint = CaprimedinaUIDB[prefix .. "RelPoint"]
    local x = CaprimedinaUIDB[prefix .. "X"] or 0
    local y = CaprimedinaUIDB[prefix .. "Y"] or 0

    if point and relPoint then
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relPoint, x, y)
    end
end


local function CapriSetupPetBar()
    if not CapriUIEnabled() then return end
    if _G["CapriPetBarContainer"] then return end 

    
    local petContainer
    if type(CreateFrame) == "function" and RegisterStateDriver then
        petContainer = CreateFrame("Frame", "CapriPetBarContainer", UIParent, "SecureHandlerStateTemplate")
    else
        petContainer = CreateFrame("Frame", "CapriPetBarContainer", UIParent) -- Fallback para 1.12.1
    end

    
    petContainer:SetWidth((30 * 10) + (4 * 9))
    petContainer:SetHeight(30)
    

    if MainMenuExpBar then
        petContainer:SetPoint("BOTTOMRIGHT", MainMenuExpBar, "TOPRIGHT", 0, 5)
    end


    for i = 1, 10 do
        local btn = _G["PetActionButton" .. i]
        if btn then
            btn:SetParent(petContainer)
            btn:ClearAllPoints()
            
           
            if i == 1 then
                btn:SetPoint("LEFT", petContainer, "LEFT", 0, 0)
            else
                btn:SetPoint("LEFT", _G["PetActionButton" .. (i - 1)], "RIGHT", 4, 0)
            end
        end
    end


    if RegisterStateDriver then
        RegisterStateDriver(petContainer, "visibility", "[pet] show; hide")
    else
        
        petContainer:RegisterEvent("UNIT_PET")
        petContainer:RegisterEvent("PLAYER_ENTERING_WORLD")
        petContainer:RegisterEvent("PET_BAR_UPDATE")
        petContainer:SetScript("OnEvent", function(self)
            if PetHasActionBar() then
                self:Show()
            else
                self:Hide()
            end
        end)
    end
end

local function CapriSetupBarArt()
    if not CapriUIEnabled() then
        return
    end

   
    CapriSetupPetBar()

    local framesToHide = {
        "BonusActionBarTexture0",
        "BonusActionBarTexture1",
        "ShapeshiftBarLeft",
        "ShapeshiftBarMiddle",
        "ShapeshiftBarRight",
        "MainMenuMaxLevelBar2",
        "MainMenuMaxLevelBar3",
        "SlidingActionBarTexture0",
        "SlidingActionBarTexture1",
    }

    local texturesToEmpty = {
        "MainMenuBarTexture0",
        "MainMenuBarTexture1",
        "MainMenuXPBarTexture2",
        "MainMenuXPBarTexture3",
        "ReputationWatchBarTexture2",
        "ReputationWatchBarTexture3",
        "ReputationXPBarTexture2",
        "ReputationXPBarTexture3",
    }

    for _, name in pairs(framesToHide) do
        local f = _G[name]
        if f then
            f:Hide()
            f.Show = function() end
            f:ClearAllPoints()
        end
    end

    for _, name in pairs(texturesToEmpty) do
        local f = _G[name]
        if f and f.SetTexture then
            f:SetTexture("")
        end
    end

    for i = 1, 10 do
        local f = _G["ShapeshiftButton" .. i]
        if f and f.SetNormalTexture then
            f:SetNormalTexture("")
        end
    end

    if MainMenuBar then MainMenuBar:SetWidth(488) end
    if MainMenuExpBar then MainMenuExpBar:SetWidth(488) end
    if MainMenuBarMaxLevelBar then MainMenuBarMaxLevelBar:SetWidth(488) end
    if ReputationWatchBar then ReputationWatchBar:SetWidth(488) end
    if ReputationWatchStatusBar then ReputationWatchStatusBar:SetWidth(488) end

    local noClickFrames = {
        ShapeshiftBarFrame,
        BonusActionBarFrame,
        MainMenuBar,
        MainMenuBarArtFrame,
        PetActionBarFrame,
    }

    for _, f in pairs(noClickFrames) do
        if f then
            f:EnableMouse(false)
            if f.SetHitRectInsets then
                f:SetHitRectInsets(5000, 5000, 5000, 5000)
            end
        end
    end
end

local function CapriUpdateBlizzardBarLayout()
    if not CapriUIEnabled() then
        return
    end

 
    
    if ShapeshiftBarFrame and MainMenuExpBar then
        ShapeshiftBarFrame:ClearAllPoints()
        ShapeshiftBarFrame:SetPoint("BOTTOMLEFT", MainMenuExpBar, "TOPLEFT", 0, 5)
    end

    if MainMenuXPBarTexture0 then
        MainMenuXPBarTexture0:SetPoint("LEFT", MainMenuExpBar, "LEFT")
    end

    if MainMenuXPBarTexture1 then
        MainMenuXPBarTexture1:SetPoint("RIGHT", MainMenuExpBar, "RIGHT")
    end

    if ReputationWatchBar then
        ReputationWatchBar:SetPoint("BOTTOM", MainMenuExpBar, "TOP", 0, 0)

        if ReputationWatchBarTexture0 then
            ReputationWatchBarTexture0:SetPoint("LEFT", ReputationWatchBar, "LEFT")
        end

        if ReputationWatchBarTexture1 then
            ReputationWatchBarTexture1:SetPoint("RIGHT", ReputationWatchBar, "RIGHT")
        end
    end

    if MainMenuMaxLevelBar0 then
        MainMenuMaxLevelBar0:SetPoint("LEFT", MainMenuBarArtFrame, "LEFT")
    end

    if MainMenuBarTexture2 then
        MainMenuBarTexture2:SetPoint("LEFT", MainMenuBarArtFrame, "LEFT")
    end

    if MainMenuBarTexture3 then
        MainMenuBarTexture3:SetPoint("RIGHT", MainMenuBarArtFrame, "RIGHT")
    end

    if ActionBarDownButton then
        ActionBarDownButton:SetPoint("BOTTOMLEFT", MainMenuBarArtFrame, "BOTTOMLEFT", -5, -5)
    end

    if ActionBarUpButton then
        ActionBarUpButton:SetPoint("TOPLEFT", MainMenuBarArtFrame, "TOPLEFT", -5, -5)
    end

    if MainMenuBarPageNumber then
        MainMenuBarPageNumber:SetPoint("LEFT", MainMenuBarArtFrame, "LEFT", 25, -5)
    end

    if CharacterMicroButton then
        CharacterMicroButton:SetPoint("LEFT", MainMenuBarArtFrame, "LEFT", 38, 0)
    end

    if MainMenuBarLeftEndCap then
        MainMenuBarLeftEndCap:SetPoint("RIGHT", MainMenuBarArtFrame, "LEFT", 30, 0)
    end

    if MainMenuBarRightEndCap then
        MainMenuBarRightEndCap:SetPoint("LEFT", MainMenuBarArtFrame, "RIGHT", -30, 0)
    end
end

-- Los buffs/debuffs del jugador cuelgan de ConsolidatedBuffs (BuffFrame se
-- re-ancla ahi solo cada frame). Si el minimapa crece, el bloque de auras
-- queda tapado; anclandolo al borde izquierdo del minimapa se mueve con el
-- y queda siempre visible. -8/+24 = posicion original con escala 1.
local function CapriAnchorPlayerAuras()
    if not CapriUIEnabled() then return end
    if not (Minimap and ConsolidatedBuffs) then return end

    local s = tonumber(CaprimedinaUIDB and CaprimedinaUIDB.minimapScale) or 1.0
    if s <= 0 then s = 1.0 end

    ConsolidatedBuffs:ClearAllPoints()
    ConsolidatedBuffs:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -8, 24)

    -- Que los iconos de buffs/debuffs crezcan o encojan junto al minimapa.
    ConsolidatedBuffs:SetScale(s)
    if BuffFrame then BuffFrame:SetScale(s) end
    if TemporaryEnchantFrame then TemporaryEnchantFrame:SetScale(s) end
end

local uiManageHooked = false

local function HookUIManage()
    if uiManageHooked or type(UIParent_ManageFramePositions) ~= "function" then
        return
    end

    uiManageHooked = true

    hooksecurefunc("UIParent_ManageFramePositions", function()
        if not CapriUIEnabled() or (InCombatLockdown and InCombatLockdown()) then
            return
        end

        if CapriPlayerAnchor and PlayerFrame then
            CapriPlayerAnchor:SetScale(CaprimedinaUIDB.playerScale or 1.0)
            PlayerFrame:SetScale(CaprimedinaUIDB.playerScale or 1.0)
            PlayerFrame:ClearAllPoints()
            PlayerFrame:SetPoint("TOPLEFT", CapriPlayerAnchor, "TOPLEFT", 0, 0)
        end

        if CapriTargetAnchor and TargetFrame then
            CapriTargetAnchor:SetScale(CaprimedinaUIDB.targetScale or 1.0)
            TargetFrame:SetScale(CaprimedinaUIDB.targetScale or 1.0)
            TargetFrame:ClearAllPoints()
            TargetFrame:SetPoint("TOPLEFT", CapriTargetAnchor, "TOPLEFT", 0, 0)
        end

        if CapriMinimapAnchor and MinimapCluster then
            CapriMinimapAnchor:SetScale(CaprimedinaUIDB.minimapScale or 1.0)
            MinimapCluster:SetScale(CaprimedinaUIDB.minimapScale or 1.0)
            MinimapCluster:ClearAllPoints()
            MinimapCluster:SetPoint("TOPRIGHT", CapriMinimapAnchor, "TOPRIGHT", 0, 0)
        end

        CapriAnchorPlayerAuras()

        CapriUpdateBlizzardBarLayout()
    end)
end

local isEditMode = false

local function SavePos(f, dbKey)
    if not f then
        return
    end

    local point, _, relPoint, x, y = f:GetPoint(1)

    if point then
        CaprimedinaUIDB[dbKey .. "Point"] = point
        CaprimedinaUIDB[dbKey .. "RelPoint"] = relPoint
        CaprimedinaUIDB[dbKey .. "X"] = x
        CaprimedinaUIDB[dbKey .. "Y"] = y
    end
end


local ctxMenu = CreateFrame("Frame", "CapriContextMenu", UIParent)
ctxMenu:SetWidth(300)
ctxMenu:SetPoint("CENTER")
ctxMenu:SetFrameStrata("TOOLTIP")
C.StyleWindow(ctxMenu)
ctxMenu:SetMovable(true)
ctxMenu:EnableMouse(true)
ctxMenu:RegisterForDrag("LeftButton")
ctxMenu:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
ctxMenu:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
ctxMenu:Hide()

local ctxTitle = ctxMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(ctxTitle, 16)
ctxTitle:SetPoint("TOP", 0, -15)

local ctxClose = C.CreateStyledClose(ctxMenu)

local ctxAccept = C.CreateStyledButton(ctxMenu, "Aceptar", 120, 25, true)
ctxAccept:SetPoint("BOTTOM", 0, 12)
ctxAccept:SetScript("OnClick", function()
    ctxMenu:Hide()
end)

local adjustRows = {}

local function GetAdjustRow(i)
    if not adjustRows[i] then
        local r = CreateFrame("Frame", nil, ctxMenu)
        r:SetWidth(200)
        r:SetHeight(25)

        r.label = r:CreateFontString(nil, "OVERLAY")
        C.SetOutlineFont(r.label, 13)
        r.label:SetPoint("LEFT", 10, 0)

        r.val = r:CreateFontString(nil, "OVERLAY")
        C.SetOutlineFont(r.val, 13)
        r.val:SetPoint("RIGHT", -60, 0)

        r.btnMinus = C.CreateStyledButton(r, "-", 22, 22)
        r.btnMinus:SetPoint("RIGHT", -30, 0)

        r.btnPlus = C.CreateStyledButton(r, "+", 22, 22)
        r.btnPlus:SetPoint("RIGHT", -5, 0)

        r.UpdateText = function(self)
            if not self.adj then
                return
            end

            local v = CaprimedinaUIDB[self.adj.db] or 0
            self.val:SetText(v == math.floor(v) and tostring(v) or string.format("%.2f", v))
        end

        local function applyChange(self, delta)
            local a = self.adj
            if not a then
                return
            end

            local v = (CaprimedinaUIDB[a.db] or 0) + delta

            if a.min and v < a.min then v = a.min end
            if a.max and v > a.max then v = a.max end

            CaprimedinaUIDB[a.db] = v
            self.row:UpdateText()

            if type(UIParent_ManageFramePositions) == "function" then
                UIParent_ManageFramePositions()
            end
        end

        r.btnMinus:SetScript("OnClick", function(self)
            applyChange(self, -self.adj.step)
        end)

        r.btnPlus:SetScript("OnClick", function(self)
            applyChange(self, self.adj.step)
        end)

        adjustRows[i] = r
    end

    return adjustRows[i]
end

local menuOptions = {
    player = {
        title = "JUGADOR",
        adjusts = {
            { label = "Escala", db = "playerScale", step = 0.05 }
        }
    },
    target = {
        title = "OBJETIVO",
        adjusts = {
            { label = "Escala", db = "targetScale", step = 0.05 }
        }
    },
    ttAnchor = {
        title = "TOOLTIP",
        adjusts = {
            { label = "Escala", db = "ttScale", step = 0.05 }
        }
    },
    minimap = {
        title = "MINIMAPA",
        adjusts = {
            { label = "Escala", db = "minimapScale", step = 0.05 }
        }
    }
}

local function ShowContextMenu(menuKey)
    local data = menuOptions[menuKey]
    if not data then
        return
    end

    ctxTitle:SetText(data.title)

    for _, r in pairs(adjustRows) do
        r:Hide()
    end

    local yOff = -40

    if data.adjusts then
        for i, adj in ipairs(data.adjusts) do
            local row = GetAdjustRow(i)
            row:SetPoint("TOP", 0, yOff)
            row.label:SetText(adj.label)
            row.adj, row.btnMinus.adj, row.btnMinus.row, row.btnPlus.adj, row.btnPlus.row = adj, adj, row, adj, row
            row:UpdateText()
            row:Show()
            yOff = yOff - 30
        end
    end

    ctxMenu:SetHeight(math.abs(yOff) + 45)
    ctxMenu:Show()
end

local function CreateDraggable(f, name, dbKey, menuKey)
    if not f then
        return
    end

    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    f:SetBackdropColor(0, 1, 0, 0)
    f:SetBackdropBorderColor(0, 1, 0, 0)
    f:SetClampedToScreen(true)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("CENTER")
    f.text:SetText(name .. "\n(Click Der)")
    f.text:Hide()

    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self)
        if self:IsMovable() then
            self:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePos(self, dbKey)

        if UIParent_ManageFramePositions then
            UIParent_ManageFramePositions()
        end
    end)

    f:SetScript("OnMouseUp", function(self, button)
        
        if button == "RightButton" and isEditMode and menuKey then
            ShowContextMenu(menuKey)
        end
    end)
end


CreateDraggable(CapriDragMain, "PRINCIPAL", "dragMain")
CreateDraggable(CapriDragBL, "INF. IZQ.", "dragBL")
CreateDraggable(CapriDragBR, "INF. DER.", "dragBR")
CreateDraggable(CapriDragRight, "DERECHA", "dragRight")
CreateDraggable(CapriDragLeft, "IZQUIERDA", "dragLeft")


CreateDraggable(CapriPlayerAnchor, "JUGADOR", "player", "player")
CreateDraggable(CapriTargetAnchor, "TARGET", "target", "target")
CreateDraggable(CapriTooltipAnchor, "TOOLTIP", "ttAnchor", "ttAnchor")
CreateDraggable(CapriMinimapAnchor, "MINIMAPA", "minimap", "minimap")


local MasterEditControl = CreateFrame("Frame", "CapriMasterEditControl", UIParent)
MasterEditControl:SetFrameStrata("DIALOG")
MasterEditControl:SetWidth(320)
MasterEditControl:SetHeight(100)
MasterEditControl:SetPoint("TOP", 0, -80)
C.StyleWindow(MasterEditControl)
MasterEditControl:Hide()

local masterEditTitle = MasterEditControl:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(masterEditTitle, 16)
masterEditTitle:SetPoint("TOP", 0, -15)
masterEditTitle:SetText("MODO EDICION ACTIVO")

local masterEditSub = MasterEditControl:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(masterEditSub, 13)
masterEditSub:SetPoint("TOP", 0, -35)
masterEditSub:SetText("Mueve los recuadros verdes.")
masterEditSub:SetTextColor(0.8, 0.8, 0.8)

local masterEditClose = C.CreateStyledClose(MasterEditControl)
masterEditClose:SetScript("OnClick", function()
    CallCapriEdit()
end)

local btnMasterAccept = C.CreateStyledButton(MasterEditControl, "Aceptar y Cerrar", 150, 25, true)
btnMasterAccept:SetPoint("BOTTOM", 0, 12)
btnMasterAccept:SetScript("OnClick", function()
    CallCapriEdit()
end)


local ui = CreateFrame("Frame", "CapriUICoreFrame", UIParent)
ui:RegisterEvent("VARIABLES_LOADED")
ui:RegisterEvent("PLAYER_ENTERING_WORLD")
ui:RegisterEvent("PLAYER_XP_UPDATE")
ui:RegisterEvent("UPDATE_EXHAUSTION")
ui:RegisterEvent("PLAYER_REGEN_ENABLED")

ui:SetScript("OnEvent", function(self, event)
    CaprimedinaUIDB = CaprimedinaUIDB or {}

    if event == "VARIABLES_LOADED" then
        InitUIDefaults()

        ApplyPoint(CapriDragLeft, "dragLeft")
        ApplyPoint(CapriDragBL, "dragBL")
        ApplyPoint(CapriDragMain, "dragMain")
        ApplyPoint(CapriDragBR, "dragBR")
        ApplyPoint(CapriDragRight, "dragRight")
        ApplyPoint(CapriTooltipAnchor, "ttAnchor")
        ApplyPoint(CapriPlayerAnchor, "player")
        ApplyPoint(CapriTargetAnchor, "target")
        ApplyPoint(CapriMinimapAnchor, "minimap")

        if CapriUIEnabled() then
            HookUIManage()
            CapriAnchorPlayerAuras()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if CapriUIEnabled() then
            CapriSetupBarArt()
            CapriUpdateBlizzardBarLayout()
            UpdateExpBarText()
            HookUIManage()
            CapriAnchorPlayerAuras()

            if not (InCombatLockdown and InCombatLockdown()) and type(UIParent_ManageFramePositions) == "function" then
                UIParent_ManageFramePositions()
            end
        else
            UpdateExpBarText()
        end

    elseif event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" then
        UpdateExpBarText()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if CapriUIEnabled() and type(UIParent_ManageFramePositions) == "function" then
            UIParent_ManageFramePositions()
        end
    end
end)

SlashCmdList["CAPRIEDIT"] = function()
    if InCombatLockdown and InCombatLockdown() then
        C.Print("No puedes editar en combate.")
        return
    end

    isEditMode = not isEditMode

    if isEditMode and not CapriUIEnabled() then
        C.Print("Modo edicion activo. La interfaz personalizada esta OFF. Los cambios se aplicaran al encenderla.")
    end

    local frames = {
        CapriDragMain,
        CapriDragBL,
        CapriDragBR,
        CapriDragRight,
        CapriDragLeft,
        CapriPlayerAnchor,
        CapriTargetAnchor,
        CapriTooltipAnchor,
        CapriMinimapAnchor
    }

    for _, f in pairs(frames) do
        if f then
            f:EnableMouse(isEditMode)
            f:SetBackdropColor(0, 1, 0, isEditMode and 0.6 or 0)
            f:SetBackdropBorderColor(0, 1, 0, isEditMode and 0.6 or 0)
            f:SetFrameStrata(isEditMode and "DIALOG" or "BACKGROUND")

            if f.text then
                if isEditMode then
                    f.text:Show()
                else
                    f.text:Hide()
                end
            end
        end
    end

    if isEditMode then
        MasterEditControl:Show()
    else
        MasterEditControl:Hide()
        ctxMenu:Hide()
    end
end

SLASH_CAPRIEDIT1 = "/capri"
SLASH_CAPRIEDIT2 = "/cui"