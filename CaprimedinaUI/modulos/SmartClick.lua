local addonName, C = ...
local _G = _G or getfenv(0)

local SmartClickFrame = CreateFrame("Frame")

SmartClickDB = SmartClickDB or { smartClickOn = false, autoCamOn = false }
local isSmartActive = false    
local autoCamTriggered = false 


CapriSmartClickMenu = CreateFrame("Frame", "CapriSmartClickMenu", UIParent)
CapriSmartClickMenu:SetFrameStrata("DIALOG")
CapriSmartClickMenu:SetSize(250, 150)
CapriSmartClickMenu:SetPoint("CENTER")
C.StyleWindow(CapriSmartClickMenu)
CapriSmartClickMenu:EnableMouse(true)
CapriSmartClickMenu:SetMovable(true)
CapriSmartClickMenu:RegisterForDrag("LeftButton")
CapriSmartClickMenu:SetScript("OnDragStart", CapriSmartClickMenu.StartMoving)
CapriSmartClickMenu:SetScript("OnDragStop", CapriSmartClickMenu.StopMovingOrSizing)
CapriSmartClickMenu:Hide()

local title = CapriSmartClickMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(title, 16)
title:SetPoint("TOP", 0, -12)
title:SetText("Ajustes SmartClick")
title:SetTextColor(1, 1, 1)

local closeBtn = C.CreateStyledClose(CapriSmartClickMenu)

local btnToggleClick = C.CreateStyledButton(CapriSmartClickMenu, "", 190, 26)
btnToggleClick:SetPoint("TOP", 0, -55)
btnToggleClick.UpdateState = function(self)
    self:SetText("Click Inteligente: " .. (SmartClickDB.smartClickOn and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end
btnToggleClick:SetScript("OnClick", function(self)
    SmartClickDB.smartClickOn = not SmartClickDB.smartClickOn
    self:UpdateState()
    if not SmartClickDB.smartClickOn and not InCombatLockdown() and isSmartActive then
        ClearOverrideBindings(SmartClickFrame)
        isSmartActive = false
    end
end)

local btnToggleCam = C.CreateStyledButton(CapriSmartClickMenu, "", 190, 26)
btnToggleCam:SetPoint("TOP", 0, -95)
btnToggleCam.UpdateState = function(self)
    self:SetText("Auto Cámara: " .. (SmartClickDB.autoCamOn and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end
btnToggleCam:SetScript("OnClick", function(self)
    SmartClickDB.autoCamOn = not SmartClickDB.autoCamOn
    self:UpdateState()
    if not SmartClickDB.autoCamOn and autoCamTriggered
        and type(IsMouselooking) == "function" and type(MouselookStop) == "function"
        and IsMouselooking() then
        MouselookStop()
        autoCamTriggered = false
    end
end)

CapriSmartClickMenu:SetScript("OnShow", function()
    btnToggleClick:UpdateState()
    btnToggleCam:UpdateState()
end)

SLASH_SMARTCLICKMENU1 = "/sc"
SLASH_SMARTCLICKMENU2 = "/smartclick"
SlashCmdList["SMARTCLICKMENU"] = function()
    if type(CaprimedinaUIDB) == "table" and CaprimedinaUIDB.enableSmartClick == false then
        C.Print("El módulo SmartClick está apagado en la configuración principal.")
        return
    end
    if CapriSmartClickMenu:IsVisible() then CapriSmartClickMenu:Hide() else CapriSmartClickMenu:Show() end
end

local function IsSmartClickEnabledGlobally()
    return type(CaprimedinaUIDB) ~= "table" or CaprimedinaUIDB.enableSmartClick ~= false
end

local function ApplySmartClicks()
    if isSmartActive or InCombatLockdown() then return end
    SetOverrideBinding(SmartClickFrame, true, "BUTTON1", "TURNORACTION")
    SetOverrideBinding(SmartClickFrame, true, "BUTTON2", "CAMERAORSELECTORMOVE")
    isSmartActive = true
end

local function RemoveSmartClicks()
    if not isSmartActive or InCombatLockdown() then return end
    ClearOverrideBindings(SmartClickFrame)
    isSmartActive = false
end

local function CheckUIElements()
    if not SmartClickDB.smartClickOn or not IsSmartClickEnabledGlobally() or InCombatLockdown() then return end
    if SpellIsTargeting() or GetCursorInfo() then RemoveSmartClicks(); return end

    for i = 1, STATICPOPUP_NUMDIALOGS do
        local popup = _G["StaticPopup"..i]
        if popup and popup:IsVisible() then RemoveSmartClicks(); return end
    end

    for i = 1, NUM_CONTAINER_FRAMES do
        local bag = _G["ContainerFrame"..i]
        if bag and bag:IsVisible() then RemoveSmartClicks(); return end
    end
    
    if BankFrame and BankFrame:IsVisible() then RemoveSmartClicks(); return end
    if UnifiedBagFrame and UnifiedBagFrame:IsVisible() then RemoveSmartClicks(); return end
    if UnifiedBankFrame and UnifiedBankFrame:IsVisible() then RemoveSmartClicks(); return end
    if CapriMasterConfigMenu and CapriMasterConfigMenu:IsVisible() then RemoveSmartClicks(); return end
    if CapriSmartClickMenu and CapriSmartClickMenu:IsVisible() then RemoveSmartClicks(); return end

    local blockFrames = {
        CharacterFrame, SpellBookFrame, QuestLogFrame, GossipFrame, 
        QuestFrame, MerchantFrame, MailFrame, FriendsFrame, 
        LFGParentFrame, WorldMapFrame, GameMenuFrame, TaxiFrame, 
        TradeFrame, LootFrame, TalentFrame, MacroFrame
    }
    for _, frame in pairs(blockFrames) do
        if frame and frame:IsVisible() then RemoveSmartClicks(); return end
    end

    ApplySmartClicks()
end

SmartClickFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
SmartClickFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
SmartClickFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then RemoveSmartClicks()
    elseif event == "PLAYER_REGEN_ENABLED" then CheckUIElements() end
end)

local timer = 0
local function MouselookAvailable()
    return type(IsMouselooking) == "function"
        and type(MouselookStart) == "function"
        and type(MouselookStop) == "function"
end

SmartClickFrame:SetScript("OnUpdate", function(self, elapsed)
    local mouselookOk = MouselookAvailable()

    if SmartClickDB.autoCamOn and IsSmartClickEnabledGlobally() and mouselookOk then
        local speed = (type(GetUnitSpeed) == "function") and GetUnitSpeed("player") or 0
        if speed > 0 then
            if not IsMouselooking() then MouselookStart(); autoCamTriggered = true end
        else
            if autoCamTriggered and IsMouselooking() then MouselookStop(); autoCamTriggered = false end
        end
    elseif not IsSmartClickEnabledGlobally() and autoCamTriggered and mouselookOk and IsMouselooking() then
        MouselookStop()
        autoCamTriggered = false
    end

    if not IsSmartClickEnabledGlobally() then RemoveSmartClicks(); return end

    timer = timer + elapsed
    if timer > 0.1 then 
        timer = 0
        CheckUIElements()
    end
end)