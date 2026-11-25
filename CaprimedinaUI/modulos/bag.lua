local _G = _G or getfenv(0)
local C = _G.CapriUI


CapriHighlightRegistry = {}

local KEYRING_ID = -2
local mainBagsList = { 0, 1, 2, 3, 4, KEYRING_ID }
local bankBagsList = { 5, 6, 7, 8, 9, 10, 11 }

local currentScale = 1.0
local currentCols = 10
local showBagTitles = true
local isBagLocked = false
local showSideBags = true

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


local frame = CreateFrame("Frame", "UnifiedBagFrame", UIParent)
tinsert(UISpecialFrames, "UnifiedBagFrame")
frame:SetPoint("CENTER", 100, 0)
C.StyleWindow(frame)
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

local dividerLine = frame:CreateTexture(nil, "ARTWORK")
dividerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
dividerLine:SetVertexColor(0.2, 0.22, 0.25, 0.8)
dividerLine:SetWidth(2)
dividerLine:Hide()


local pdWidth = 220
local pdHeight = 310

UnifiedPaperDollPanel = CreateFrame("Frame", "UnifiedPaperDollPanel", frame)
UnifiedPaperDollPanel:SetWidth(pdWidth)
UnifiedPaperDollPanel:SetHeight(pdHeight)
UnifiedPaperDollPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
UnifiedPaperDollPanel:SetBackdropColor(0, 0, 0, 0.75)
UnifiedPaperDollPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
UnifiedPaperDollPanel:Hide()

local pdPadding = 4
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
    UnifiedPaperDollPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
end

UnifiedPaperDollModel = CreateFrame("PlayerModel", "UnifiedPaperDollModel", UnifiedPaperDollPanel)
UnifiedPaperDollModel:SetFrameLevel(UnifiedPaperDollPanel:GetFrameLevel() + 1)
UnifiedPaperDollModel:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "TOPLEFT", 45, -10)
UnifiedPaperDollModel:SetPoint("BOTTOMRIGHT", UnifiedPaperDollPanel, "BOTTOMRIGHT", -45, 20)
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
        btn:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "TOPLEFT", 8, -8 - (i - 1) * (pdSlotSize + pdSpacing))
    elseif i <= 16 then
        btn:SetPoint("TOPRIGHT", UnifiedPaperDollPanel, "TOPRIGHT", -8, -8 - (i - 9) * (pdSlotSize + pdSpacing))
    else
        local bottomIndex = i - 16
        btn:SetPoint("BOTTOMLEFT", UnifiedPaperDollPanel, "BOTTOMLEFT", 52 + (bottomIndex - 1) * (pdSlotSize + pdSpacing), 8)
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
bagSlotPanel:SetHeight(45)
bagSlotPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
bagSlotPanel:SetBackdropColor(0, 0, 0, 0.6)
bagSlotPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
bagSlotPanel:SetFrameLevel(frame:GetFrameLevel() + 2)

UnifiedProfSlots = {}

UnifiedProfMainPanel = CreateFrame("Frame", "UnifiedProfMainPanel", frame)
UnifiedProfMainPanel:SetWidth(pdWidth)
UnifiedProfMainPanel:SetHeight(90)
UnifiedProfMainPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
UnifiedProfMainPanel:SetBackdropColor(0, 0, 0, 0.6)
UnifiedProfMainPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
UnifiedProfMainPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
UnifiedProfMainPanel:Hide()

local headerMain = UnifiedProfMainPanel:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(headerMain, 12)
headerMain:SetPoint("TOPLEFT", UnifiedProfMainPanel, "TOPLEFT", 12, -12)
headerMain:SetText("Principales")
headerMain:SetTextColor(1, 0.8, 0)

UnifiedProfSecPanel = CreateFrame("Frame", "UnifiedProfSecPanel", frame)
UnifiedProfSecPanel:SetWidth(pdWidth)
UnifiedProfSecPanel:SetHeight(120)
UnifiedProfSecPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
UnifiedProfSecPanel:SetBackdropColor(0, 0, 0, 0.6)
UnifiedProfSecPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
UnifiedProfSecPanel:SetFrameLevel(frame:GetFrameLevel() + 2)
UnifiedProfSecPanel:Hide()

local headerSec = UnifiedProfSecPanel:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(headerSec, 12)
headerSec:SetPoint("TOPLEFT", UnifiedProfSecPanel, "TOPLEFT", 12, -12)
headerSec:SetText("Secundarias")
headerSec:SetTextColor(1, 0.8, 0)

local function CreateProfSlot(parent, index, yOffset)
    local pBtn = CreateFrame("Button", nil, parent)
    pBtn:SetWidth(pdWidth - 20)
    pBtn:SetHeight(24)
    pBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)

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

CreateProfSlot(UnifiedProfMainPanel, 1, -30)
CreateProfSlot(UnifiedProfMainPanel, 2, -58)
CreateProfSlot(UnifiedProfSecPanel, 3, -30)
CreateProfSlot(UnifiedProfSecPanel, 4, -58)
CreateProfSlot(UnifiedProfSecPanel, 5, -86)

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

local btnToggleSideBags = C.CreateStyledButton(frame, "<", 20, 20)
btnToggleSideBags:SetPoint("TOPLEFT", 10, -10)

local title = frame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(title, 14)
title:SetPoint("TOPLEFT", 35, -12)
title:SetText("MOCHILA CAPRIMEDINA")
title:SetTextColor(1, 1, 1)

local moneyFrame = CreateFrame("Frame", "UnifiedBagMoneyFrame", frame, "SmallMoneyFrameTemplate")
moneyFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 10)

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

local bankSlotPanel = CreateFrame("Frame", "UnifiedBankSlotPanel", bankFrame)
bankSlotPanel:SetWidth(45)
bankSlotPanel:SetPoint("TOPRIGHT", bankFrame, "TOPLEFT", 1, 0)
C.StyleWindow(bankSlotPanel)
bankSlotPanel:SetFrameLevel(bankFrame:GetFrameLevel() + 2)

local btnToggleBankSideBags = C.CreateStyledButton(bankFrame, "<", 20, 20)
btnToggleBankSideBags:SetPoint("TOPLEFT", 10, -10)

local bankTitle = bankFrame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bankTitle, 14)
bankTitle:SetPoint("TOPLEFT", 35, -12)
bankTitle:SetText("BANCO CAPRIMEDINA")
bankTitle:SetTextColor(1, 1, 1)

local function SetBagStrata(strata)
    currentBagStrata = strata

    if frame then frame:SetFrameStrata(strata) end
    if bankFrame then bankFrame:SetFrameStrata(strata) end
    if bagSlotPanel then bagSlotPanel:SetFrameStrata(strata) end
    if bankSlotPanel then bankSlotPanel:SetFrameStrata(strata) end
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

local function OrganizeItems()
    if not frame:IsVisible() then return end

    local buttonSize = 41
    local startY = -45
    local currentY = startY
    local globalSlotIndex = 0
    local startX = 15
    local totalLeftHeight = 0

    for _, bag in ipairs(mainBagsList) do CapriHighlightRegistry[bag] = {} end

    if showSideBags then
        UnifiedPaperDollPanel:Show()
        bagSlotPanel:Show()
        dividerLine:Show()

        UnifiedPaperDollPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -40)
        bagSlotPanel:SetPoint("TOPLEFT", UnifiedPaperDollPanel, "BOTTOMLEFT", 0, -5)
        dividerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 15 + pdWidth + 10, -35)

        startX = 15 + pdWidth + 25
        totalLeftHeight = 40 + pdHeight + 5 + 45 + 10

        if showBagTitles then
            UnifiedProfMainPanel:Show()
            UnifiedProfSecPanel:Show()
            UnifiedProfMainPanel:SetPoint("TOPLEFT", bagSlotPanel, "BOTTOMLEFT", 0, -5)
            UnifiedProfSecPanel:SetPoint("TOPLEFT", UnifiedProfMainPanel, "BOTTOMLEFT", 0, -5)
            totalLeftHeight = totalLeftHeight + 90 + 5 + 120 + 5
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
            bagSlotBtn:SetPoint("LEFT", bagSlotPanel, "LEFT", 10 + (i - 1) * 40, 0)
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
        startX = 15
        totalLeftHeight = 0
    end

    for _, bag in ipairs(mainBagsList) do
        local slots = GetContainerNumSlots(bag)

        if bag == KEYRING_ID then
            local krSize = GetKeyRingSize and GetKeyRingSize() or 32
            if krSize > 0 then slots = krSize end
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
                icon:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, currentY + 2)
                icon:Show()

                label:SetPoint("TOPLEFT", frame, "TOPLEFT", startX + 20, currentY)
                label:SetTextColor(1, 0.8, 0)
                if bag == 0 then label:SetText("MOCHILA PRINCIPAL")
                elseif bag == KEYRING_ID then label:SetText("LLAVERO")
                else label:SetText("BOLSA " .. bag) end
                label:Show()

                currentY = currentY - 20
                local localSlotIndex = 0

                for slot = 1, slots do
                    local itemButton = GetSlotButton(bagContainer, slot, slots)
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
                        localSlotIndex = localSlotIndex + 1
                    end
                end

                local numRows = math.ceil(slots / currentCols)
                currentY = currentY - (numRows * buttonSize) - 10
            else
                label:Hide()
                icon:Hide()

                for slot = 1, slots do
                    local itemButton = GetSlotButton(bagContainer, slot, slots)
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

    local totalRightHeight = math.abs(currentY) + 30
    local finalHeight = math.max(totalLeftHeight, totalRightHeight)

    if showSideBags then dividerLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15 + pdWidth + 10, 15) end

    frame:SetScale(currentScale)
    frame:SetWidth(startX + (currentCols * buttonSize) + 15)
    frame:SetHeight(finalHeight)

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
    local currentY = -40
    local globalBankSlotIndex = 0

    bankFrame:SetWidth(35 + (bankCols * buttonSize))
    bankFrame:SetScale(bankScale)

    for _, bag in ipairs(bankBagsList) do CapriHighlightRegistry[bag] = {} end

    if showBankSideBags then
        bankSlotPanel:Show()
        local slotY = -12

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
                bagSlotItem:SetScale(0.95)
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
        bankSlotPanel:SetHeight(math.abs(slotY) + 10)
    else
        bankSlotPanel:Hide()
    end

    local labelBank = _G["UnifiedBankLabelMain"] or bankFrame:CreateFontString("UnifiedBankLabelMain", "OVERLAY")
    local iconBank = _G["UnifiedBankIconMain"] or bankFrame:CreateTexture("UnifiedBankIconMain", "OVERLAY")

    if labelBank.SetFont then C.SetOutlineFont(labelBank, 12) end

    if showBankTitles then
        globalBankSlotIndex = 0
        labelBank:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 35, currentY)
        labelBank:SetTextColor(1, 0.8, 0)
        labelBank:SetText("BANCO PRINCIPAL")
        labelBank:Show()

        iconBank:SetWidth(16)
        iconBank:SetHeight(16)
        iconBank:SetTexture("Interface\\Icons\\Inv_box_02")
        iconBank:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 15, currentY + 2)
        iconBank:Show()
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
            itemButton:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 15 + (col * buttonSize), currentY - (row * buttonSize))
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
                icon:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 15, currentY + 2)
                icon:Show()

                label:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 35, currentY)
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

                    itemButton:SetPoint("TOPLEFT", bankFrame, "TOPLEFT", 15 + (col * buttonSize), currentY - (row * buttonSize))
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

    bankFrame:SetHeight(math.abs(currentY) + 50)

    local purchaseBtn = _G["BankFramePurchaseButton"]
    local costText = _G["UnifiedBankCostText"] or bankFrame:CreateFontString("UnifiedBankCostText", "OVERLAY")

    if costText.SetFont then C.SetOutlineFont(costText, 12) end

    if purchaseBtn then
        purchaseBtn:SetParent(bankFrame)
        purchaseBtn:ClearAllPoints()
        purchaseBtn:SetPoint("BOTTOM", bankFrame, "BOTTOM", -40, 15)
        purchaseBtn:SetFrameStrata(currentBagStrata)
        purchaseBtn:SetFrameLevel(bankFrame:GetFrameLevel() + 15)
        purchaseBtn:EnableMouse(true)

        local numSlots, full = GetNumBankSlots()

        if full then
            purchaseBtn:Hide()
            costText:SetText("Ranuras al maximo")
            costText:SetTextColor(0, 1, 0)
            costText:ClearAllPoints()
            costText:SetPoint("BOTTOM", bankFrame, "BOTTOM", 0, 18)
        else
            purchaseBtn:Show()
            local cost = GetBankSlotCost(numSlots)
            local g = math.floor(cost / 10000)
            local s = math.floor((cost % 10000) / 100)
            local c = cost % 100

            local costString = "Costo: "
            if g > 0 then costString = costString .. g .. "g " end
            if s > 0 then costString = costString .. s .. "s " end
            costString = costString .. c .. "c"

            costText:SetText(costString)
            costText:SetTextColor(1, 0.8, 0)
            costText:ClearAllPoints()
            costText:SetPoint("LEFT", purchaseBtn, "RIGHT", 10, 0)
        end
        costText:Show()
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

local close = C.CreateStyledButton(frame, "X", 40, 26, true)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
close:SetScript("OnClick", function() CloseAllBags() end)

local gearBag = CreateFrame("Button", nil, frame)
gearBag:SetWidth(18)
gearBag:SetHeight(18)
gearBag:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
gearBag:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
gearBag:SetPoint("RIGHT", close, "LEFT", -4, 0)
gearBag:SetScript("OnClick", function()
    if CapriBagConfigFrame:IsVisible() then CapriBagConfigFrame:Hide()
    else CapriBagConfigFrame:Show() end
end)

local closeBank = C.CreateStyledButton(bankFrame, "X", 40, 26, true)
closeBank:SetPoint("TOPRIGHT", bankFrame, "TOPRIGHT", -8, -8)
closeBank:SetScript("OnClick", function() bankFrame:Hide() end)

local gearBank = CreateFrame("Button", nil, bankFrame)
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
        { frame, 0 }, { bagSlotPanel, 1 }, { btnToggleSideBags, 2 }, { close, 2 },
        { gearBag, 2 }, { moneyFrame, 2 }, { UnifiedPaperDollPanel, 1 },
        { UnifiedPaperDollModel, 2 }, { dividerLine, 1 }, { UnifiedProfMainPanel, 1 },
        { UnifiedProfSecPanel, 1 },
    }

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

    RaiseFamily(members)
    SetBagStrata("DIALOG")
end

RaiseBankWindow = function()
    local members = {
        { bankFrame, 0 }, { bankSlotPanel, 1 }, { btnToggleBankSideBags, 2 },
        { closeBank, 2 }, { gearBank, 2 },
    }

    local pb = _G["BankFramePurchaseButton"]
    if pb then table.insert(members, { pb, 2 }) end

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