local _G = _G or getfenv(0)
local C = _G.CapriUI or {}
_G.CapriUI = C
if not C.Print then
C.Print = function(msg)
if DEFAULT_CHAT_FRAME then
DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[CaprimedinaUI]|r " .. tostring(msg))
end
end
end

local function ChatEnabled()
return type(CaprimedinaUIDB) == "table" and CaprimedinaUIDB.enableChat ~= false
end
local function SafeShown(f)
return f ~= nil and f:IsShown()
end

-- Botones de accion del addon (objetivo / atacar / saltar).
-- Se ocultan mientras el chat esta grande y se restauran al volver a chico.
local function ChatActionButtonsShow()
	local ab = _G.CapriBotonesAccion
	if not ab then return end
	if CaprimedinaUIDB and CaprimedinaUIDB.botonesVisible == false then
		return
	end
	if not ab:IsShown() then ab:Show() end
end
local function ChatActionButtonsHide()
	local ab = _G.CapriBotonesAccion
	if ab then ab:Hide() end
end


local CAPRI_NOOP_MOVE = function() end   
local CAPRI_NOOP_DRAG = function() end  
local CAPRI_ORIG_CF_DRAGSTART = _G.ChatFrame_OnDragStart
local function KillGlobalChatDrag()
	_G.ChatFrame_OnDragStart = CAPRI_NOOP_DRAG
end
local function RestoreGlobalChatDrag()
	if CAPRI_ORIG_CF_DRAGSTART then
		_G.ChatFrame_OnDragStart = CAPRI_ORIG_CF_DRAGSTART
	end
end


CAPRI_HARDSTOP_TICKS = 0
CAPRI_CTRL_TICKS = 0


local hiddenButtons = {}
local movedButtons = {}
local editBoxBackup = nil
local function HideButton(f, key)
if not f then
return
end
if not hiddenButtons[key] then
    hiddenButtons[key] = {
        frame = f,
        show = f.Show,
        wasShown = f:IsShown()
    }
end
f:Hide()
f.Show = function() end
end
local function RestoreHiddenButtons()
for key, data in pairs(hiddenButtons) do
local f = data.frame
    if f then
        if data.show then
            f.Show = data.show
        else
            f.Show = nil
        end
        if data.wasShown then
            f:Show()
        else
            f:Hide()
        end
    end
    hiddenButtons[key] = nil
end
end
local function MoveButton(f, key, point, relativeTo, relativePoint, x, y)
if not f then
return
end
if not movedButtons[key] then
    local p, rt, rp, ox, oy = f:GetPoint(1)
    movedButtons[key] = {
        frame = f,
        point = p,
        relativeTo = rt,
        relativePoint = rp,
        x = ox,
        y = oy
    }
end
f:ClearAllPoints()
f:SetPoint(point, relativeTo, relativePoint, x, y)
end
local function RestoreMovedButtons()
for key, data in pairs(movedButtons) do
local f = data.frame
    if f and data.point then
        f:ClearAllPoints()
        local rel = data.relativeTo or UIParent
        f:SetPoint(data.point, rel, data.relativePoint, data.x, data.y)
    end
    movedButtons[key] = nil
end
end
local function BackupEditBox()
local eb = ChatFrame1EditBox
if not eb or editBoxBackup then
return
end
local point, relativeTo, relativePoint, x, y = eb:GetPoint(1)
editBoxBackup = {
    frame = eb,
    parent = eb:GetParent(),
    strata = eb:GetFrameStrata(),
    level = eb:GetFrameLevel(),
    point = point,
    relativeTo = relativeTo,
    relativePoint = relativePoint,
    x = x,
    y = y,
    scale = eb:GetScale(),
    width = eb:GetWidth()
}
end
local function RestoreEditBox()
local eb = ChatFrame1EditBox
if not eb or not editBoxBackup then
return
end
if editBoxBackup.parent then
     eb:SetParent(editBoxBackup.parent)
 end
 if editBoxBackup.strata then
     eb:SetFrameStrata(editBoxBackup.strata)
 end
 if editBoxBackup.level then
     eb:SetFrameLevel(editBoxBackup.level)
 end
 eb:ClearAllPoints()
 if editBoxBackup.point then
     local rel = editBoxBackup.relativeTo or UIParent
     eb:SetPoint(editBoxBackup.point, rel, editBoxBackup.relativePoint, editBoxBackup.x, editBoxBackup.y)
 end
 eb:SetScale(editBoxBackup.scale or 1)
 if editBoxBackup.width and editBoxBackup.width > 0 then
     eb:SetWidth(editBoxBackup.width)
 end
 editBoxBackup = nil
end

local chatHiddenByUser = false
local hiddenFrames = {}
local hiddenTabs = {}
local hiddenExtra = {}
-- Declaraciones adelantadas: estas funciones se definen mas abajo pero
-- HideAllChat/ShowAllChat las usan.
local UpdateChatDockLayout
local ApplyChatOverlayState
local function GetChatTab(i)
local cf = _G["ChatFrame" .. i]
return _G["ChatFrame" .. i .. "Tab"] or (cf and cf.tab) or nil
end
local function IsInMicroMenu(f)
local p = f:GetParent()
while p do
    if p == MainMenuBar or p == MainMenuBarArtFrame then
        return true
    end
    p = p:GetParent()
end
return false
end
local function HideAllChat()
if not ChatEnabled() then
return
end
-- Antes de ocultar dejamos la ventana SIEMPRE en su tamano/posicion normal.
-- Asi, si se abrio grande, al volver a mostrarla nunca queda "grande".
UpdateChatDockLayout(true)
if ChatFrame1 and ChatFrame1.EnableMouse then ChatFrame1:EnableMouse(false) end
local count = NUM_CHAT_WINDOWS or 1
 for i = 1, count do
     local cf = _G["ChatFrame" .. i]
     if not chatHiddenByUser then
         hiddenFrames[i] = (cf and cf:IsShown()) and true or false
         local tab = GetChatTab(i)
         hiddenTabs[i] = (tab and tab:IsShown()) and true or false
     end
     if cf then
         cf:Hide()
     end
     local tab = GetChatTab(i)
     if tab then
         tab:Hide()
     end
 end
 local f = EnumerateFrames()
 while f do
     local n = f:GetName()
     if n and not hiddenExtra[n] then
         local low = string.lower(n)
         if not string.find(low, "friendsframe")
             and not string.find(low, "whoframe")
             and not string.find(low, "guildframe")
             and not string.find(low, "ignoreframe") then
             if (string.find(low, "social") or string.find(low, "friend") or string.find(low, "contact"))
                 and string.find(low, "button")
                 and not IsInMicroMenu(f)
                 and f:IsShown() then
                 hiddenExtra[n] = true
                 f:Hide()
             end
         end
     end
     f = EnumerateFrames(f)
 end
 chatHiddenByUser = true
 -- Apagar los overlays: con el chat oculto, un toque sobre la zona del chat
 -- NO debe abrirlo. Solo Enter o el boton de la carta pueden mostrarlo.
 ApplyChatOverlayState()
end
local function ShowAllChat()
if not ChatEnabled() then
return
end
chatHiddenByUser = false
-- Garantizar geometria "pequena" al volver a mostrar (evita quedar grande).
local eb = ChatFrame1EditBox
if not (eb and eb:IsVisible()) then
    UpdateChatDockLayout(true)
end
local count = NUM_CHAT_WINDOWS or 1
 for i = 1, count do
     local cf = _G["ChatFrame" .. i]
     if cf and (i == 1 or hiddenFrames[i] == true) then
         cf:Show()
     end
     local tab = GetChatTab(i)
     if tab and (i == 1 or hiddenTabs[i] == true) then
         tab:Show()
     end
 end
 for n, _ in pairs(hiddenExtra) do
     local f = _G[n]
     if f then
         f:Show()
     end
     hiddenExtra[n] = nil
 end
 for i in pairs(hiddenFrames) do hiddenFrames[i] = nil end
 for i in pairs(hiddenTabs) do hiddenTabs[i] = nil end
 ApplyChatOverlayState()
end
local function RestoreHiddenChatFrames()
for i, shown in pairs(hiddenFrames) do
local cf = _G["ChatFrame" .. i]
if cf and shown then
cf:Show()
end
    hiddenFrames[i] = nil
 end
 for i, shown in pairs(hiddenTabs) do
     local tab = GetChatTab(i)
     if tab and shown then
         tab:Show()
     end
     hiddenTabs[i] = nil
 end
 for n, _ in pairs(hiddenExtra) do
     local f = _G[n]
     if f then
         f:Show()
     end
     hiddenExtra[n] = nil
 end
 chatHiddenByUser = false
end


local DOCK_X = 17
local DOCK_GAP_BASE = 4      -- casi pegado a la barra de experiencia
local DOCK_GAP_BAR = 5       -- aire entre las barras (pet/auras) y el chat

-- Altura que ocupan las barras que van ARRIBA de la barra de experiencia.
-- Si el jugador usa pet, auras/formas o reputacion, el chat sube por encima;
-- si no usa ese espacio, se queda casi pegado a la barra de experiencia.
-- Se detecta en VIVO (UnitExists/GetNumShapeshiftForms) porque los state drivers
-- de las barras no siempre refrescan IsShown() al invocar/retirar la mascota.
local PET_BAR_H    = 30
local STANCE_BAR_H = 34
local REP_BAR_H    = 12
local function HasPetBar()
	if type(UnitExists) == "function" and UnitExists("pet") then return true end
	local pet = _G.CapriPetBarContainer
	return pet ~= nil and pet:IsShown()
end
local function HasStanceBar()
	if type(GetNumShapeshiftForms) == "function" and (GetNumShapeshiftForms() or 0) > 0 then
		return true
	end
	local stance = _G.ShapeshiftBarFrame
	return stance ~= nil and stance:IsShown()
end
local function HasRepBar()
	if type(GetWatchedFactionInfo) == "function" then
		local name = GetWatchedFactionInfo()
		if name then return true end
	end
	local rep = _G.ReputationWatchBar
	return rep ~= nil and rep:IsShown()
end
local function GetChatDockExtraHeight()
	local extra = 0
	if HasPetBar() then
		extra = math.max(extra, PET_BAR_H + DOCK_GAP_BAR)
	end
	if HasStanceBar() then
		extra = math.max(extra, STANCE_BAR_H + DOCK_GAP_BAR)
	end
	if HasRepBar() then
		extra = math.max(extra, REP_BAR_H + DOCK_GAP_BAR)
	end
	return extra
end

-- Aplica SOLO la geometria chica (sirve tambien con el modulo desactivado).
local function ApplySmallGeometry()
	if not ChatFrame1 then return end
	local mainBar = MainMenuBarArtFrame or UIParent
	if not mainBar then return end
	local rel = _G.MainMenuExpBar or mainBar
	ChatFrame1:SetScale(1)
	ChatFrame1:ClearAllPoints()
	ChatFrame1:SetWidth(478)
	ChatFrame1:SetHeight(130)
	ChatFrame1:SetPoint("BOTTOMLEFT", rel, "TOPLEFT", DOCK_X, DOCK_GAP_BASE + GetChatDockExtraHeight())
	if ChatFrame1.SetUserPlaced then ChatFrame1:SetUserPlaced(true) end
end

local function UpdateChatDockLayoutImpl(force)
	if not ChatEnabled() then return end
	if not ChatFrame1 then return end
	if not force then
		if CapriChatControl and CapriChatControl.state == 1 then return end
		local eb = ChatFrame1EditBox
		if eb and eb:IsVisible() then return end
	end
	ApplySmallGeometry()
	-- En modo normal el fondo del chat es invisible (look limpio del addon).
	-- Al forzar (ocultar/mostrar) tambien se limpia el alpha del modo grande.
	local bgCount = NUM_CHAT_WINDOWS or 1
	for i = 1, bgCount do
		local bg = _G["ChatFrame" .. i .. "Background"]
		if bg then bg:SetAlpha(0) end
	end
	ApplyChatOverlayState()
end
UpdateChatDockLayout = UpdateChatDockLayoutImpl

-- Enciende/apaga los overlays (la zona clickeable del chat) segun el estado.
-- Con el chat oculto o abierto/grande, el overlay queda apagado.
local function ApplyChatOverlayStateImpl()
	if not ChatFrame1 then return end
	local eb = ChatFrame1EditBox
	local editing = (eb and eb:IsVisible()) and true or false
	local big = (CapriChatControl and CapriChatControl.state == 1) and true or false
	local so = ChatFrame1.smallOverlay
	if so then
		if chatHiddenByUser or editing or big then
			so:Hide()
		else
			so:ClearAllPoints()
			so:SetAllPoints(ChatFrame1)
			so:Show()
		end
	end
	if ChatFrame1.bigBlocker then
		ChatFrame1.bigBlocker:Hide()
	end
end
ApplyChatOverlayState = ApplyChatOverlayStateImpl


local GREAT_P1 = { point = "TOPLEFT",     rel = "TOPLEFT", x = 150,  y = -50 }
local GREAT_P2 = { point = "BOTTOMRIGHT", rel = "RIGHT",   x = -150, y = -14 }
local function ReanchorGreat()
	if not ChatFrame1 then return end
	local p1, _, rp1, x1, y1 = ChatFrame1:GetPoint(1)
	local p2, _, rp2, x2, y2 = ChatFrame1:GetPoint(2)
	if p1 == GREAT_P1.point and x1 == GREAT_P1.x and y1 == GREAT_P1.y
	   and p2 == GREAT_P2.point and rp2 == GREAT_P2.rel and x2 == GREAT_P2.x and y2 == GREAT_P2.y then
		return  
	end
	ChatFrame1:ClearAllPoints()
	ChatFrame1:SetPoint("TOPLEFT", UIParent, GREAT_P1.rel, GREAT_P1.x, GREAT_P1.y)
	ChatFrame1:SetPoint("BOTTOMRIGHT", UIParent, GREAT_P2.rel, GREAT_P2.x, GREAT_P2.y)
end


local function GuardOneFrame(f)
	if not f then return end
	f.isLocked = 1
	f.isFloating = false
	if f.SetMovable then f:SetMovable(false) end
	if f.RegisterForDrag then f:RegisterForDrag() end
	if f.SetScript then
		f:SetScript("OnDragStart", CAPRI_NOOP_DRAG)
		f:SetScript("OnDragStop", CAPRI_NOOP_DRAG)
	end
	if f.StartMoving ~= CAPRI_NOOP_MOVE then f.StartMoving = CAPRI_NOOP_MOVE end
	if f.StartSizing  ~= CAPRI_NOOP_MOVE then f.StartSizing  = CAPRI_NOOP_MOVE end
end
local function GuardTree(f, depth)
	if not f or (depth or 0) > 8 then return end
	GuardOneFrame(f)
	if f.GetChildren then
		local children = { f:GetChildren() }
		for _, child in ipairs(children) do
			GuardTree(child, (depth or 0) + 1)
		end
	end
end
local function GuardChatFrameMovement()
	if not ChatFrame1 then return end
	GuardTree(ChatFrame1, 0)
	local tab = _G["ChatFrame1Tab"] or (ChatFrame1 and ChatFrame1.tab)
	GuardOneFrame(tab)
	GuardOneFrame(_G["ChatFrame1ButtonFrame"])
	GuardOneFrame(_G["ChatFrame1Background"])
	GuardOneFrame(ChatFrame1EditBox)
end


local function CapriLockFrame(f, isMain)
if not f or not ChatEnabled() then
return
end
if f.SetMovable then
     f:SetMovable(false)
 end
 if isMain then
     if f.SetUserPlaced then f:SetUserPlaced(true) end
     if f.SetDontSavePosition then f:SetDontSavePosition(true) end
 end
 f.isLocked = 1
 f.isFloating = false
 if f.SetScript then
     f:SetScript("OnDragStart", CAPRI_NOOP_DRAG)
     f:SetScript("OnDragStop", CAPRI_NOOP_DRAG)
 end
 if f.RegisterForDrag then
     f:RegisterForDrag()
 end
end
local function CapriLockRecursive(f, isMain, depth)
if not f or (depth or 0) > 8 then
return
end
CapriLockFrame(f, isMain)
if f.GetChildren then
    local children = { f:GetChildren() }
    for _, child in ipairs(children) do
        CapriLockRecursive(child, false, (depth or 0) + 1)
    end
end
end

local function SetupEditBox()
if not ChatEnabled() then
return
end
local editBox = ChatFrame1EditBox
 if not editBox then
     return
 end
 BackupEditBox()
 editBox:SetParent(UIParent)
 editBox:SetFrameStrata("DIALOG")
 editBox:SetFrameLevel(200)
 editBox:ClearAllPoints()
 editBox:SetPoint("TOP", UIParent, "TOP", 0, -10)
 editBox:SetWidth(400)
 editBox:SetScale(1.5)
 if not editBox.capriFocusHooked then
     editBox:HookScript("OnEditFocusLost", function(self)
         if not ChatEnabled() then
             return
         end
         if CapriChatControl and CapriChatControl.state == 1
             and ChatFrame1 and ChatFrame1.capriChatClicked then
             ChatFrame1.capriChatClicked = false
             return
         end
         if ChatFrame1 then
             ChatFrame1.capriChatClicked = false
         end
         self:Hide()
     end)
     editBox.capriFocusHooked = true
 end
 if not editBox.capriStateHooked then
     editBox:HookScript("OnShow", function()
         if not ChatEnabled() then
             return
         end
         if CapriChatControl then
             CapriChatControl.state = -1
         end
     end)
     editBox:HookScript("OnHide", function()
         if not ChatEnabled() then
             return
         end
         if CapriChatControl then
             CapriChatControl.state = -1
         end
     end)
     editBox.capriStateHooked = true
 end
end

local function CreateChatOverlays()
if not ChatEnabled() then
return
end
if not ChatFrame1 or ChatFrame1.capriOverlaysDone then
     return
 end
 ChatFrame1.capriOverlaysDone = true
 if ChatFrame1.SetHyperlinksEnabled then
     ChatFrame1:SetHyperlinksEnabled(true)
 end
 local smallOverlay = CreateFrame("Button", "CapriChatSmallOverlay", UIParent)
 smallOverlay:SetFrameStrata("MEDIUM")
 smallOverlay:SetAllPoints(ChatFrame1)
 smallOverlay:RegisterForClicks("AnyUp")
 smallOverlay:SetScript("OnClick", function()
     if not ChatEnabled() then
         return
     end
     -- Si el usuario oculto el chat, tocar esta zona NO debe abrirlo.
     -- (Solo Enter o el boton de la carta lo muestran.)
     if chatHiddenByUser then
         return
     end
     local eb = ChatFrame1EditBox
     if eb and not eb:IsVisible() then
         eb:Show()
         eb:SetFocus()
     end
 end)
 smallOverlay:EnableMouseWheel(true)
 smallOverlay:SetScript("OnMouseWheel", function(self, delta)
     if not ChatEnabled() then
         return
     end
     if delta > 0 then
         if ChatFrame1.ScrollUp then
             ChatFrame1:ScrollUp()
         end
     else
         if ChatFrame1.ScrollDown then
             ChatFrame1:ScrollDown()
         end
     end
 end)
 ChatFrame1.smallOverlay = smallOverlay
 local bigBlocker = CreateFrame("Button", "CapriChatBigBlocker", UIParent)
 bigBlocker:SetFrameStrata("HIGH")
 bigBlocker:SetAllPoints(ChatFrame1)
 bigBlocker:RegisterForClicks("AnyUp")
 bigBlocker:SetScript("OnClick", function()
     if not ChatEnabled() then
         return
     end
     local eb = ChatFrame1EditBox
     if eb and eb:IsVisible() then
         eb:SetFocus()
     end
 end)
 ChatFrame1.bigBlocker = bigBlocker
 bigBlocker:Hide()
end
local function InstallChatClickHandlers()
if not ChatEnabled() then
return
end
if not ChatFrame1 or ChatFrame1.capriHandlersInstalled then
     return
 end
 ChatFrame1.capriHandlersInstalled = true
 if WorldFrame and not WorldFrame.capriHooked then
     if WorldFrame:HasScript("OnMouseDown") then
         WorldFrame:HookScript("OnMouseDown", function()
             if not ChatEnabled() then
                 return
             end
             local eb = ChatFrame1EditBox
             if eb and eb:IsVisible() then
                 eb:ClearFocus()
                 eb:Hide()
             end
         end)
     end
     WorldFrame.capriHooked = true
 end
 if ChatFrame1:HasScript("OnHyperlinkClick") then
     ChatFrame1:HookScript("OnHyperlinkClick", function(self)
         self.capriLinkClicked = true
     end)
 end
 local prevMouseDown = ChatFrame1:GetScript("OnMouseDown")
 local prevMouseUp = ChatFrame1:GetScript("OnMouseUp")
 ChatFrame1.capriPrevMouseDown = prevMouseDown
 ChatFrame1.capriPrevMouseUp = prevMouseUp
 local linkCheck = CreateFrame("Frame")
 linkCheck:Hide()
 linkCheck:SetScript("OnUpdate", function(self)
     self:Hide()
     if not ChatEnabled() then
         return
     end
     local cf = ChatFrame1
     local wasLink = cf.capriLinkClicked
     cf.capriLinkClicked = false
     cf.capriChatClicked = false
     if not wasLink then
         if CapriChatControl and CapriChatControl.state == 1 then
             local eb = ChatFrame1EditBox
             if eb and eb:IsVisible() then
                 eb:SetFocus()
             end
         end
     end
 end)
 ChatFrame1.capriLinkCheck = linkCheck
 local function CapriOnMouseDown(self, button)
     if not ChatEnabled() then
         if self.capriPrevMouseDown then
             self.capriPrevMouseDown(self, button)
         end
         return
     end
     self.isLocked = 1
     self.isFloating = false
     if self.SetMovable then
         self:SetMovable(false)
     end
     self.capriChatClicked = true
     if CapriChatControl and CapriChatControl.state == 1 and button == "LeftButton" then
         return
     end
     if self.capriPrevMouseDown then
         self.capriPrevMouseDown(self, button)
     end
 end
 local function CapriOnMouseUp(self, button)
     if not ChatEnabled() then
         if self.capriPrevMouseUp then
             self.capriPrevMouseUp(self, button)
         end
         return
     end
     if CapriChatControl and CapriChatControl.state == 1 and button == "LeftButton" then
         if self.capriLinkCheck then
             self.capriLinkCheck:Show()
         end
         return
     end
     if self.capriPrevMouseUp then
         self.capriPrevMouseUp(self, button)
     end
 end
 ChatFrame1.capriMouseDownHandler = CapriOnMouseDown
 ChatFrame1.capriMouseUpHandler = CapriOnMouseUp
 ChatFrame1:SetScript("OnMouseDown", CapriOnMouseDown)
 ChatFrame1:SetScript("OnMouseUp", CapriOnMouseUp)
end
local function SetupChatClick()
if not ChatEnabled() then
return
end
CreateChatOverlays()
InstallChatClickHandlers()
end

local function SetupChatButtons()
if not ChatEnabled() then
return
end
HideButton(ChatFrameMenuButton, "ChatFrameMenuButton")
 local count = NUM_CHAT_WINDOWS or 1
 for i = 1, count do
     local chatFrame = _G["ChatFrame" .. i]
     local down = _G["ChatFrame" .. i .. "DownButton"]
     local up = _G["ChatFrame" .. i .. "UpButton"]
     local bot = _G["ChatFrame" .. i .. "BottomButton"]
     if down and chatFrame then
         MoveButton(down, "ChatFrame" .. i .. "DownButton", "BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", 0, -5)
     end
     if up and down then
         MoveButton(up, "ChatFrame" .. i .. "UpButton", "RIGHT", down, "LEFT", 0, 0)
     end
     if bot then
         HideButton(bot, "ChatFrame" .. i .. "BottomButton")
     end
 end
end

local function SetupChatToggle()
if not ChatEnabled() then
return
end
if not ChatFrame1 then
     return
 end
 if ChatFrame1.chatToggleBtn and ChatFrame1.chatToggleBtn:IsShown() then
     return
 end
 local tb = _G.CapriChatToggleBtn
 if not tb then
     tb = CreateFrame("Button", "CapriChatToggleBtn", UIParent)
     tb:SetWidth(32)
     tb:SetHeight(32)
     local anchor = MainMenuBarArtFrame or UIParent
     tb:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", -50, 20)
     tb:SetBackdrop({
         bgFile = "Interface\\Buttons\\WHITE8X8",
         edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
         tile = false,
         edgeSize = 12,
         insets = { left = 2, right = 2, top = 2, bottom = 2 }
     })
     tb:SetBackdropColor(0.10, 0.11, 0.12, 0.95)
     local icon = tb:CreateTexture(nil, "ARTWORK")
     icon:SetTexture("Interface\\Icons\\INV_Letter_01")
     icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
     icon:SetPoint("TOPLEFT", tb, "TOPLEFT", 4, -4)
     icon:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", -4, 4)
     tb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
     tb:SetScript("OnEnter", function(self)
         if not ChatEnabled() then
             return
         end
         GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
         GameTooltip:SetText("Ocultar / Mostrar chat", 1, 1, 1)
         GameTooltip:Show()
     end)
     tb:SetScript("OnLeave", function()
         GameTooltip:Hide()
     end)
     tb:SetScript("OnClick", function()
         if not ChatEnabled() then
             return
         end
         if chatHiddenByUser then
             ShowAllChat()
         else
             HideAllChat()
         end
     end)
 end
 tb:Show()
 ChatFrame1.chatToggleBtn = tb
end

local function LockChatFrame()
if not ChatEnabled() then
return
end
if not ChatFrame1 then
     return
 end
 CapriLockRecursive(ChatFrame1, true, 0)
 ChatFrame1.isDocked = 1
 if CHAT_OPTIONS then
     CHAT_OPTIONS.LOCKED = 1
 end
 local tab = _G["ChatFrame1Tab"] or (ChatFrame1 and ChatFrame1.tab)
 CapriLockRecursive(tab, true, 0)
 CapriLockRecursive(_G["ChatFrame1ButtonFrame"], false, 0)
 CapriLockRecursive(ChatFrame1EditBox, false, 0)
 local bg = _G["ChatFrame1Background"]
 if bg then
     CapriLockRecursive(bg, false, 0)
     if bg.EnableMouse then
         bg:EnableMouse(false)
     end
     if bg.EnableMouseWheel then
         bg:EnableMouseWheel(false)
     end
 end
 CapriLockFrame(ChatFrame1.smallOverlay, false)
 CapriLockFrame(ChatFrame1.bigBlocker, false)
 if CapriChatControl and CapriChatControl.state == 1 then
     if ChatFrame1.capriMouseDownHandler
         and ChatFrame1:GetScript("OnMouseDown") ~= ChatFrame1.capriMouseDownHandler then
         ChatFrame1:SetScript("OnMouseDown", ChatFrame1.capriMouseDownHandler)
     end
     if ChatFrame1.capriMouseUpHandler
         and ChatFrame1:GetScript("OnMouseUp") ~= ChatFrame1.capriMouseUpHandler then
         ChatFrame1:SetScript("OnMouseUp", ChatFrame1.capriMouseUpHandler)
     end
 end
end

local function SetupChatControl()
if not ChatEnabled() then
return
end
if not CapriChatControl then
     CapriChatControl = CreateFrame("Frame", "CapriChatControl", UIParent)
     CapriChatControl.state = -1
 end
 if CapriChatControl:GetScript("OnUpdate") then
     CapriChatControl:Show()
     return
 end
 CapriChatControl.state = -1
 CapriChatControl:Show()
 local chatCtrlTimer = 0
 CapriChatControl:SetScript("OnUpdate", function(self, elapsed)
     if not ChatEnabled() then
         return
     end
     if not ChatFrame1 then
         return
     end


     CAPRI_CTRL_TICKS = (CAPRI_CTRL_TICKS or 0) + 1
     if self.state == 1 then
         KillGlobalChatDrag()
        
         if ChatFrame1.StartMoving ~= CAPRI_NOOP_MOVE then ChatFrame1.StartMoving = CAPRI_NOOP_MOVE end
         if ChatFrame1.StartSizing  ~= CAPRI_NOOP_MOVE then ChatFrame1.StartSizing  = CAPRI_NOOP_MOVE end
         if ChatFrame1.SetScript then
             ChatFrame1:SetScript("OnDragStart", CAPRI_NOOP_DRAG)
             ChatFrame1:SetScript("OnDragStop",  CAPRI_NOOP_DRAG)
         end
         if ChatFrame1.RegisterForDrag then ChatFrame1:RegisterForDrag() end
         if ChatFrame1.SetMovable then ChatFrame1:SetMovable(false) end
         ChatFrame1.isLocked = 1
         ChatFrame1.isFloating = false
         local tab = _G["ChatFrame1Tab"] or ChatFrame1.tab
         if tab then
             if tab.StartMoving ~= CAPRI_NOOP_MOVE then tab.StartMoving = CAPRI_NOOP_MOVE end
             if tab.StartSizing  ~= CAPRI_NOOP_MOVE then tab.StartSizing  = CAPRI_NOOP_MOVE end
             if tab.SetScript then
                 tab:SetScript("OnDragStart", CAPRI_NOOP_DRAG)
                 tab:SetScript("OnDragStop",  CAPRI_NOOP_DRAG)
             end
             if tab.RegisterForDrag then tab:RegisterForDrag() end
             if tab.SetMovable then tab:SetMovable(false) end
             tab.isLocked = 1
         end
    
         ReanchorGreat()
         if ChatFrame1.StopMovingOrSizing then ChatFrame1:StopMovingOrSizing() end
     end

     
     chatCtrlTimer = chatCtrlTimer + elapsed
     if chatCtrlTimer < 0.05 then
         return
     end
     chatCtrlTimer = 0
     local eb = ChatFrame1EditBox
     if not eb then
         return
     end
     local isChatOpen = eb:IsVisible()
     local count = NUM_CHAT_WINDOWS or 1
     if isChatOpen and self.state ~= 1 then
         self.state = 1
         KillGlobalChatDrag()
         ChatFrame1:SetFrameStrata("DIALOG")
         ChatFrame1:EnableMouse(true)
         if ChatFrame1.SetHyperlinksEnabled then
             ChatFrame1:SetHyperlinksEnabled(true)
         end
         if ChatFrame1.smallOverlay then
             ChatFrame1.smallOverlay:Hide()
         end
         if ChatFrame1.bigBlocker then
             ChatFrame1.bigBlocker:Hide()
         end
         ChatFrame1:Show()
         -- Si se abrio con Enter estando oculto, mostrar tambien la pestana.
         if chatHiddenByUser then
             local hiddenTab = GetChatTab(1)
             if hiddenTab then hiddenTab:Show() end
         end
         ChatFrame1:SetScale(1.8)
         ChatFrame1:ClearAllPoints()
         ChatFrame1:SetPoint("TOPLEFT", UIParent, GREAT_P1.rel, GREAT_P1.x, GREAT_P1.y)
         ChatFrame1:SetPoint("BOTTOMRIGHT", UIParent, GREAT_P2.rel, GREAT_P2.x, GREAT_P2.y)
         for i = 1, count do
             local bg = _G["ChatFrame" .. i .. "Background"]
             if bg then
                 bg:SetAlpha(0.6)
             end
         end
         local framesToAlpha = {
             PlayerFrame, TargetFrame, MinimapCluster, ShapeshiftBarFrame,
             PetActionBarFrame, BonusActionBarFrame,
             _G.CapriDragMain, _G.CapriDragBL, _G.CapriDragBR,
             _G.CapriDragRight, _G.CapriDragLeft, _G.CapriDPad
         }
         for _, f in ipairs(framesToAlpha) do
             if f then f:SetAlpha(0) end
         end
         if BuffFrame then BuffFrame:SetAlpha(0) end
         if WatchFrame then WatchFrame:SetAlpha(0) end
         local allBarPrefixes = {
             "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
             "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton"
         }
         for _, prefix in ipairs(allBarPrefixes) do
             for i = 1, 12 do
                 local btn = _G[prefix .. i]
                 if btn then btn:SetAlpha(0) end
             end
         end
         if ChatFrame1.chatToggleBtn then ChatFrame1.chatToggleBtn:Hide() end
         ChatActionButtonsHide()
         LockChatFrame()
         GuardChatFrameMovement()
     elseif not isChatOpen and self.state ~= 0 then
         self.state = 0
         RestoreGlobalChatDrag()
         ChatFrame1:SetFrameStrata("LOW")
         ChatFrame1:EnableMouse(false)
         if ChatFrame1.bigBlocker then ChatFrame1.bigBlocker:Hide() end
         for i = 1, count do
             local bg = _G["ChatFrame" .. i .. "Background"]
             if bg then bg:SetAlpha(0) end
         end
         local framesToShow = {
             PlayerFrame, TargetFrame, MinimapCluster, ShapeshiftBarFrame,
             PetActionBarFrame, BonusActionBarFrame,
             _G.CapriDragMain, _G.CapriDragBL, _G.CapriDragBR,
             _G.CapriDragRight, _G.CapriDragLeft, _G.CapriDPad
         }
         for _, f in ipairs(framesToShow) do
             if f then f:SetAlpha(1) end
         end
         if BuffFrame then BuffFrame:SetAlpha(1) end
         if WatchFrame then WatchFrame:SetAlpha(1) end
         local sideBars = {
             "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
             "MultiBarRightButton", "MultiBarLeftButton"
         }
         for _, prefix in ipairs(sideBars) do
             for i = 1, 12 do
                 local btn = _G[prefix .. i]
                 if btn then btn:SetAlpha(1) end
             end
         end
         local isBonus = BonusActionBarFrame and BonusActionBarFrame:IsShown()
         for i = 1, 12 do
             local main = _G["ActionButton" .. i]
             local bonus = _G["BonusActionButton" .. i]
             if isBonus then
                 if main then main:SetAlpha(0) end
                 if bonus then bonus:SetAlpha(1) end
             else
                 if main then main:SetAlpha(1) end
                 if bonus then bonus:SetAlpha(0) end
             end
         end
         UpdateChatDockLayout(true)
         if chatHiddenByUser then
             HideAllChat()
         else
             ApplyChatOverlayState()
         end
         if ChatFrame1.chatToggleBtn then ChatFrame1.chatToggleBtn:Show() end
         ChatActionButtonsShow()
         LockChatFrame()
         GuardChatFrameMovement()
     end
 end)
end

local chatFixCtrl
local capriHardStop

local function DisableChatModifications()
RestoreGlobalChatDrag()
if CapriChatControl then
CapriChatControl:SetScript("OnUpdate", nil)
CapriChatControl:Hide()
CapriChatControl.state = -1
end
if chatFixCtrl then chatFixCtrl:Hide() end
if capriHardStop then capriHardStop:Hide() end
if _G.CapriChatToggleBtn then _G.CapriChatToggleBtn:Hide() end
if ChatFrame1 and ChatFrame1.chatToggleBtn then
     ChatFrame1.chatToggleBtn:Hide()
     ChatFrame1.chatToggleBtn = nil
 end
 if ChatFrame1 then
     if ChatFrame1.smallOverlay then ChatFrame1.smallOverlay:Hide() end
     if ChatFrame1.bigBlocker then ChatFrame1.bigBlocker:Hide() end
     if ChatFrame1.capriHandlersInstalled then
         ChatFrame1:SetScript("OnMouseDown", ChatFrame1.capriPrevMouseDown)
         ChatFrame1:SetScript("OnMouseUp", ChatFrame1.capriPrevMouseUp)
         ChatFrame1.capriHandlersInstalled = nil
         ChatFrame1.capriPrevMouseDown = nil
         ChatFrame1.capriPrevMouseUp = nil
     end
 end
 RestoreHiddenButtons()
 RestoreMovedButtons()
 RestoreEditBox()
 RestoreHiddenChatFrames()
 ChatActionButtonsShow()
 -- Dejar la ventana visible y con la geometria chica al desactivar el modulo.
 ApplySmallGeometry()
 if ChatFrame1 then
     if ChatFrame1.EnableMouse then ChatFrame1:EnableMouse(false) end
     if ChatFrame1.SetFrameStrata then ChatFrame1:SetFrameStrata("LOW") end
 end
end

chatFixCtrl = CreateFrame("Frame", "CapriChatFixCtrl", UIParent)
chatFixCtrl:RegisterEvent("UPDATE_CHAT_WINDOWS")
chatFixCtrl:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
chatFixCtrl:RegisterEvent("UNIT_PET")
chatFixCtrl:RegisterEvent("PET_BAR_UPDATE")
chatFixCtrl:RegisterEvent("PET_BAR_HIDE")
chatFixCtrl:RegisterEvent("PET_BAR_SHOW")
chatFixCtrl:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
chatFixCtrl:RegisterEvent("UPDATE_FACTION")
chatFixCtrl:RegisterEvent("PLAYER_PET_CHANGED")
chatFixCtrl:Hide()
chatFixCtrl:SetScript("OnEvent", function(self, event, unit)
if not ChatEnabled() then return end
-- Solo nos interesa el jugador para UNIT_PET
if event == "UNIT_PET" and unit and unit ~= "player" then return end
LockChatFrame()
GuardChatFrameMovement()
if CapriChatControl and CapriChatControl.state == 1 then
KillGlobalChatDrag()
ReanchorGreat()
end
-- Refrescar dock al instante cuando cambia pet/auras/reputacion.
-- Si el chat esta oculto, JAMAS mostrarlo: solo reforzar el ocultamiento.
if chatHiddenByUser then
	EnforceHiddenChat()
else
	UpdateChatDockLayout(true)
end
end)
function EnforceHiddenChat()
	if not chatHiddenByUser then return end
	local eb = ChatFrame1EditBox
	local escribiendo = eb and eb:IsVisible()
	if escribiendo then return end
	if CapriChatControl and CapriChatControl.state == 1 then return end
	local cnt = NUM_CHAT_WINDOWS or 1
	for i = 1, cnt do
		local cf2 = _G["ChatFrame" .. i]
		if cf2 and cf2:IsShown() then cf2:Hide() end
		local tab2 = GetChatTab(i)
		if tab2 and tab2:IsShown() then tab2:Hide() end
	end
end

local function EnsureDockPosition()
	if not ChatFrame1 then return end
	if not ChatEnabled() then return end
	-- Si esta oculto, JAMAS aplicar geometria ni mostrar: solo ocultar.
	if chatHiddenByUser then
		EnforceHiddenChat()
		return
	end
	if CapriChatControl and CapriChatControl.state == 1 then return end
	local eb = ChatFrame1EditBox
	if eb and eb:IsVisible() then return end
	local _, _, _, cx, cy = ChatFrame1:GetPoint(1)
	local desiredY = DOCK_GAP_BASE + GetChatDockExtraHeight()
	if cx ~= DOCK_X or cy ~= desiredY then
		ApplySmallGeometry()
	end
end

-- Acceso para pruebas/diagnostico (no afecta produccion)
_G.CapriChatSetHiddenByUser = function(v)
	chatHiddenByUser = (v and true or false)
	if v then
		EnforceHiddenChat()
	else
		UpdateChatDockLayout(true)
	end
end

local chatFixTimer = 0
chatFixCtrl:SetScript("OnUpdate", function(self, elapsed)
if not ChatEnabled() then return end
if not ChatFrame1 then return end
-- Cada frame: mantener la posicion chica frente al reanclaje del juego.
EnsureDockPosition()
chatFixTimer = chatFixTimer + elapsed
if chatFixTimer < 0.2 then return end
chatFixTimer = 0
LockChatFrame()
GuardChatFrameMovement()
UpdateChatDockLayout()
if CapriChatControl and CapriChatControl.state == 1 then
     KillGlobalChatDrag()
     ReanchorGreat()
 end
 local eb = ChatFrame1EditBox
 local escribiendo = eb and eb:IsVisible()
 -- Si el usuario oculto el chat, mantenerlo oculto de verdad:
 -- nada (ni pestañas ni pestanas sociales) debe reabrirlo, salvo Enter.
 if chatHiddenByUser and not escribiendo
     and not (CapriChatControl and CapriChatControl.state == 1) then
     local cnt = NUM_CHAT_WINDOWS or 1
     for i = 1, cnt do
         local cf2 = _G["ChatFrame" .. i]
         if cf2 and cf2:IsShown() then cf2:Hide() end
         local tab2 = GetChatTab(i)
         if tab2 and tab2:IsShown() then tab2:Hide() end
     end
 end
 ApplyChatOverlayState()
 if ChatFrame1.chatToggleBtn then
     if escribiendo then
         if ChatFrame1.chatToggleBtn:IsShown() then ChatFrame1.chatToggleBtn:Hide() end
     else
         if not ChatFrame1.chatToggleBtn:IsShown() then ChatFrame1.chatToggleBtn:Show() end
     end
 end
end)
capriHardStop = CreateFrame("Frame", "CapriHardStop", UIParent)
capriHardStop:Hide()
capriHardStop:SetScript("OnUpdate", function()
if not ChatEnabled() then return end
if ChatFrame1 and CapriChatControl and CapriChatControl.state == 1 then
     CAPRI_HARDSTOP_TICKS = (CAPRI_HARDSTOP_TICKS or 0) + 1
     KillGlobalChatDrag()
     GuardChatFrameMovement()
     ReanchorGreat()
     if ChatFrame1.StopMovingOrSizing then ChatFrame1:StopMovingOrSizing() end
     if ChatFrame1.capriMouseDownHandler
         and ChatFrame1:GetScript("OnMouseDown") ~= ChatFrame1.capriMouseDownHandler then
         ChatFrame1:SetScript("OnMouseDown", ChatFrame1.capriMouseDownHandler)
     end
     if ChatFrame1.capriMouseUpHandler
         and ChatFrame1:GetScript("OnMouseUp") ~= ChatFrame1.capriMouseUpHandler then
         ChatFrame1:SetScript("OnMouseUp", ChatFrame1.capriMouseUpHandler)
     end
 end
end)

local function CapriInitialize()
if not ChatEnabled() then
DisableChatModifications()
return
end
-- Evitar que el juego reancla el chat dockeado por su cuenta (invocar mascota,
-- cambiar de aura, etc.) pisando nuestra posicion.
if type(hooksecurefunc) == "function" then
  if type(FCF_UpdateDockedFramePosition) == "function" then
    hooksecurefunc("FCF_UpdateDockedFramePosition", function()
      if ChatFrame1 then EnsureDockPosition() end
    end)
  end
  if type(FCF_DockFrame) == "function" then
    hooksecurefunc("FCF_DockFrame", function()
      if ChatFrame1 then EnsureDockPosition() end
    end)
  end
  if type(FCF_UnDockFrame) == "function" then
    hooksecurefunc("FCF_UnDockFrame", function()
      if ChatFrame1 then EnsureDockPosition() end
    end)
  end
end
SetupEditBox()
SetupChatClick()
SetupChatButtons()
SetupChatToggle()
SetupChatControl()

if CapriChatControl then CapriChatControl:Show() end
if chatFixCtrl then chatFixCtrl:Show() end
if capriHardStop then capriHardStop:Show() end

pcall(LockChatFrame)
pcall(GuardChatFrameMovement)
if CapriChatControl then CapriChatControl.state = -1 end
end
local chatInit = CreateFrame("Frame", "CapriChatInit", UIParent)
chatInit:RegisterEvent("VARIABLES_LOADED")
chatInit:RegisterEvent("PLAYER_ENTERING_WORLD")
local chatInitialized = false
chatInit:SetScript("OnEvent", function(self, event)
if not ChatEnabled() then
DisableChatModifications()
chatInitialized = false
return
end
if event == "PLAYER_ENTERING_WORLD" then
     if ChatFrame1EditBox then
         ChatFrame1EditBox:ClearFocus()
         ChatFrame1EditBox:Hide()
     end
     if not chatInitialized then
         CapriInitialize()
         chatInitialized = true
     end
     if ChatFrame1 and CapriChatControl then
         if ChatFrame1EditBox then ChatFrame1EditBox:Hide() end
         CapriChatControl.state = -1
         UpdateChatDockLayout()
         pcall(GuardChatFrameMovement)
     end
 else
     if ChatFrame1 then
         SetupEditBox()
         SetupChatClick()
         SetupChatButtons()
     end
 end
end)

if not SlashCmdList then SlashCmdList = {} end
SLASH_CAPFRAME1 = "/capframe"
SlashCmdList["CAPFRAME"] = function()
local f = GetMouseFocus()
if f and f ~= WorldFrame then
    C.Print("Frame bajo el mouse: " .. (f:GetName() or "(sin nombre)"))
else
    C.Print("|cffff0000Pon el mouse encima del boton y escribe /capframe|r")
end
end

SLASH_CAPDOCK1 = "/capdock"
SlashCmdList["CAPDOCK"] = function()
if not ChatFrame1 then C.Print("|cffff0000ChatFrame1 no existe|r") return end
local st = CapriChatControl and CapriChatControl.state or "?"
local eb = ChatFrame1EditBox
local escribiendo = (eb and eb:IsVisible()) and "SI" or "no"
local sm = (ChatFrame1.StartMoving == CAPRI_NOOP_MOVE) and "noop(BIEN)" or "REAL"
local ds = (ChatFrame1.GetScript and ChatFrame1:GetScript("OnDragStart") == CAPRI_NOOP_DRAG) and "noop(BIEN)" or "no-noop"
local dg = (_G.ChatFrame_OnDragStart == CAPRI_NOOP_DRAG) and "kill(BIEN)" or "vivo"
local p1, _, rp1, x1, y1 = ChatFrame1:GetPoint(1)
local p2, _, rp2, x2, y2 = ChatFrame1:GetPoint(2)
local okPos = (p1 == GREAT_P1.point and x1 == GREAT_P1.x and y1 == GREAT_P1.y
           and p2 == GREAT_P2.point and rp2 == GREAT_P2.rel and x2 == GREAT_P2.x and y2 == GREAT_P2.y)
C.Print(string.format("|cff00ccff[state]|r %s |escribiendo %s |isLocked %s |isFloating %s",
    tostring(st), escribiendo, tostring(ChatFrame1.isLocked), tostring(ChatFrame1.isFloating)))
C.Print(string.format("|StartMoving %s |OnDragStart(inst) %s |DragGlobal %s",
    sm, ds, dg))
C.Print(string.format("|cff00ccff|ctrlTicks|r %s |cff00ccff|hardStopTicks|r %s  <- si ctrlTicks sube, el candado VIVE",
    tostring(CAPRI_CTRL_TICKS), tostring(CAPRI_HARDSTOP_TICKS)))
C.Print(string.format("|P1 %s/%s (%s,%s) |P2 %s/%s (%s,%s) |posFija %s",
    tostring(p1), tostring(rp1), tostring(x1), tostring(y1),
    tostring(p2), tostring(rp2), tostring(x2), tostring(y2),
    okPos and "SI(BIEN)" or "NO(!)"))
local ov = ChatFrame1.smallOverlay
C.Print(string.format("|ocultoPorUsuario %s |overlay %s |escala %s",
    chatHiddenByUser and "SI" or "no",
    ov and (ov:IsShown() and "visible" or "apagado") or "?",
    tostring(ChatFrame1:GetScale())))
local ab = _G.CapriBotonesAccion
local _, _, _, dx, dy = ChatFrame1:GetPoint(1)
C.Print(string.format("|dock: y %s (4 = pegado a XP) |extra %s |barraPet %s |auras %s |botonesAccion %s",
    tostring(dy), tostring(GetChatDockExtraHeight()),
    (_G.CapriPetBarContainer and _G.CapriPetBarContainer:IsShown()) and "SI" or "no",
    (_G.ShapeshiftBarFrame and _G.ShapeshiftBarFrame:IsShown()) and "SI" or "no",
    ab and (ab:IsShown() and "visibles" or "ocultos") or "?"))
end