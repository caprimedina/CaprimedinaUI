local _G = _G or getfenv(0)
local C = _G.CapriUI
_G.CapriUIState = _G.CapriUIState or {}
if _G.CapriUIState.dragging == nil then _G.CapriUIState.dragging = false end
if _G.CapriUIState.dragOwner == nil then _G.CapriUIState.dragOwner = nil end
local function G(name)
return _G[name]
end
local colorKey     = {0.18, 0.19, 0.21, 1.00}
local colorSpecial = {0.25, 0.27, 0.30, 1.00}
local VKB = CreateFrame("Frame", "AndroidTouchKeyboard", UIParent)
VKB:SetSize(900, 360)
VKB:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
VKB:SetFrameStrata("FULLSCREEN")
C.StyleWindow(VKB)
VKB:SetMovable(true)
VKB:SetClampedToScreen(true)
VKB:Hide()
local isKeyboardEnabled = true
local activeEditBox = nil
local loginDone = false
local suppressShowUntil = 0
local function CapriOtherWindowDragging()
local s = _G.CapriUIState
return s and s.dragging and s.dragOwner ~= "vkb"
end
local function RaiseKeyboardTop()
if CapriOtherWindowDragging() then return end
local ub = G("UnifiedBagFrame")
if ub then ub:SetFrameStrata("HIGH") end
local ubk = G("UnifiedBankFrame")
if ubk then ubk:SetFrameStrata("HIGH") end
for _, n in ipairs({"UnifiedBagSlotPanel", "UnifiedBankSlotPanel"}) do
local p = G(n)
if p then p:SetFrameStrata("HIGH") end
end
for i = 1, 4 do
local c = G("UnifiedBagSideClone" .. i)
if c then c:SetFrameStrata("HIGH") end
end
for i = 1, 7 do
local b = G("BankFrameBag" .. i)
if b then b:SetFrameStrata("HIGH") end
end
for i = 1, 28 do
local b = G("BankFrameItem" .. i)
if b then b:SetFrameStrata("HIGH") end
end
local reg = _G.CapriHighlightRegistry
if reg then
for _, list in pairs(reg) do
for _, b in ipairs(list) do
if b then b:SetFrameStrata("HIGH") end
end
end
end
if _G.CapriSetBagStrata then
_G.CapriSetBagStrata("HIGH")
end
VKB:SetFrameStrata("FULLSCREEN")
end
VKB:EnableMouse(true)
VKB:SetScript("OnMouseDown", function()
if CapriOtherWindowDragging() then return end
RaiseKeyboardTop()
if activeEditBox then
activeEditBox:SetFocus()
end
end)
SLASH_VKB_TOGGLE1 = "/vkb"
SlashCmdList["VKB_TOGGLE"] = function()
isKeyboardEnabled = not isKeyboardEnabled
if type(CaprimedinaUIDB) ~= "table" then
CaprimedinaUIDB = {}
end
CaprimedinaUIDB.enabled = isKeyboardEnabled
if isKeyboardEnabled then
C.Print("|cff00ff00Teclado Virtual activado.|r Aparecerá al escribir.")
else
C.Print("|cffff0000Teclado Virtual desactivado.|r Ya no aparecerá automáticamente.")
if VKB:IsShown() then
VKB:Hide()
end
end
end
local DragOverlay = CreateFrame("Button", nil, VKB)
DragOverlay:SetSize(900, 60)
DragOverlay:SetPoint("TOPLEFT", VKB, "TOPLEFT", 0, 0)
DragOverlay:SetFrameLevel(VKB:GetFrameLevel() + 20)
DragOverlay:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
DragOverlay:SetBackdropColor(0.2, 0.6, 0.3, 0.85)
DragOverlay.text = DragOverlay:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(DragOverlay.text, 16)
DragOverlay.text:SetPoint("CENTER", 0, 0)
DragOverlay.text:SetText("ARRASTRA DESDE AQUI PARA MOVER - TOCA PARA FIJAR")
DragOverlay:Hide()
DragOverlay:RegisterForDrag("LeftButton")
DragOverlay:SetScript("OnDragStart", function()
_G.CapriUIState.dragging = true
_G.CapriUIState.dragOwner = "vkb"
VKB:StartMoving()
end)
DragOverlay:SetScript("OnDragStop", function()
VKB:StopMovingOrSizing()
_G.CapriUIState.dragging = false
_G.CapriUIState.dragOwner = nil
local point, _, _, xOfs, yOfs = VKB:GetPoint()
if type(CaprimedinaUIDB) ~= "table" then
CaprimedinaUIDB = {}
end
CaprimedinaUIDB.point = point
CaprimedinaUIDB.xOfs = xOfs
CaprimedinaUIDB.yOfs = yOfs
end)
DragOverlay:SetScript("OnClick", function(self)
self:Hide()
end)
local optBtn = C.CreateStyledButton(VKB, "Ajustes", 110, 40, true)
optBtn:SetPoint("TOPLEFT", VKB, "TOPLEFT", 10, -10)
local canalesTop = {
{"Decir", "/s "},
{"Grupo", "/p "},
{"Hermandad", "/g "},
{"Banda", "/ra "},
{"CdB", "/bg "},
{"Gritar", "/y "}
}
local cStartX = 130
for _, cmd in ipairs(canalesTop) do
local cBtn = C.CreateStyledButton(VKB, cmd[1], 90, 40)
cBtn:SetPoint("TOPLEFT", VKB, "TOPLEFT", cStartX, -10)
cBtn:SetScript("OnClick", function(self)
RaiseKeyboardTop()
local eb = activeEditBox or ChatFrame1EditBox
if eb then
if not eb:IsShown() then
eb:Show()
end
eb:SetText(cmd[2])
eb:SetFocus()
end
end)
cStartX = cStartX + 95
end
local closeBtn = C.CreateStyledButton(VKB, "X", 60, 40, true)
closeBtn:SetPoint("TOPRIGHT", VKB, "TOPRIGHT", -10, -10)
closeBtn:SetScript("OnClick", function(self)
if activeEditBox then
local onEsc = activeEditBox:GetScript("OnEscapePressed")
if onEsc then
onEsc(activeEditBox)
end
activeEditBox:ClearFocus()
end
VKB:Hide()
end)
local SettingsPanel = CreateFrame("Frame", nil, VKB)
SettingsPanel:SetPoint("TOPLEFT", VKB, "TOPLEFT", 0, -60)
SettingsPanel:SetPoint("BOTTOMRIGHT", VKB, "BOTTOMRIGHT", 0, 0)
C.StyleWindow(SettingsPanel)
SettingsPanel:SetFrameLevel(VKB:GetFrameLevel() + 5)
SettingsPanel:Hide()
optBtn:SetScript("OnClick", function(self)
if SettingsPanel:IsShown() then
SettingsPanel:Hide()
else
SettingsPanel:Show()
end
end)
local function CreateSettingsButton(text, x, y, w, h, onClickFunc)
local btn = C.CreateStyledButton(SettingsPanel, text, w, h, true)
btn:SetPoint("TOPLEFT", SettingsPanel, "TOPLEFT", x, y)
btn:SetScript("OnClick", function(self)
onClickFunc()
end)
return btn
end
local function CreateTitle(text, x, y)
local t = SettingsPanel:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(t, 15)
t:SetPoint("TOPLEFT", SettingsPanel, "TOPLEFT", x, y)
t:SetText(text)
end
CreateTitle("1. Tamano del Teclado (Escala Libre):", 20, -10)
CreateTitle("2. Posicion en Pantalla:", 20, -95)
CreateTitle("3. Emociones / Acciones Rapidas:", 20, -180)
local scaleDisplay = SettingsPanel:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(scaleDisplay, 16)
scaleDisplay:SetPoint("TOPLEFT", SettingsPanel, "TOPLEFT", 95, -45)
scaleDisplay:SetText("95%")
local function UpdateScaleDisplay()
local current = VKB:GetScale()
scaleDisplay:SetText(math.floor(current * 100 + 0.5) .. "%")
if type(CaprimedinaUIDB) ~= "table" then
CaprimedinaUIDB = {}
end
CaprimedinaUIDB.scale = current
end
CreateSettingsButton("-", 20, -35, 55, 40, function()
VKB:SetScale(math.max(0.4, VKB:GetScale() - 0.05))
UpdateScaleDisplay()
end)
CreateSettingsButton("+", 155, -35, 55, 40, function()
VKB:SetScale(math.min(2.5, VKB:GetScale() + 0.05))
UpdateScaleDisplay()
end)
CreateSettingsButton("Restablecer", 230, -35, 140, 40, function()
VKB:SetScale(0.95)
UpdateScaleDisplay()
end)
CreateSettingsButton("Desbloquear / Mover", 20, -120, 220, 40, function()
SettingsPanel:Hide()
DragOverlay:Show()
end)
CreateSettingsButton("Restaurar al Centro", 250, -120, 220, 40, function()
VKB:ClearAllPoints()
VKB:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
if type(CaprimedinaUIDB) ~= "table" then
CaprimedinaUIDB = {}
end
CaprimedinaUIDB.point = "BOTTOM"
CaprimedinaUIDB.xOfs = 0
CaprimedinaUIDB.yOfs = 0
end)
local emociones = {
{"Bailar", "/bailar "},
{"Aplaudir", "/aplaudir "},
{"Reir", "/risa "},
{"Saludar", "/saludar "},
{"Llorar", "/llorar "},
{"Burla", "/burla "}
}
local startX = 20
for _, emote in ipairs(emociones) do
CreateSettingsButton(emote[1], startX, -205, 130, 40, function()
local eb = activeEditBox or ChatFrame1EditBox
if eb then
eb:SetText(emote[2])
local onEnter = eb:GetScript("OnEnterPressed")
if onEnter then
onEnter(eb)
elseif ChatEdit_SendText then
ChatEdit_SendText(eb)
end
eb:ClearFocus()
end
SettingsPanel:Hide()
VKB:Hide()
end)
startX = startX + 140
end
local pages = {
lower = {
{"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
{"q", "w", "e", "r", "t", "y", "u", "i", "o", "p"},
{"a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"},
{"Mayus", "z", "x", "c", "v", "b", "n", "m", "<-"},
{"?123", ",", "Espacio", ".", "Enter"}
},
upper = {
{"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
{"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"},
{"A", "S", "D", "F", "G", "H", "J", "K", "L", "Ñ"},
{"Mayus", "Z", "X", "C", "V", "B", "N", "M", "<-"},
{"?123", ",", "Espacio", ".", "Enter"}
},
sym1 = {
{"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
{"@", "#", "$", "%", "&", "-", "+", "(", ")", "/"},
{"\"", "'", ":", ";", "!", "?", "~", "*", "|"},
{"=\\<", "\\", "%", "^", "=", "{", "}", "[", "<-"},
{"ABC", ",", "Espacio", ".", "Enter"}
},
sym2 = {
{"~", "`", "|", "+", "-", "_", "/", "<", ">", "="},
{"[", "]", "{", "}", "\\", "^", "\"", "@", "#", "$"},
{"%", "&", "(", ")", "'", "\"", ":", ";", "!", "?"},
{"?123", "¡", "¿", "º", "ª", "€", "£", "§", "<-"},
{"ABC", ",", "Espacio", ".", "Enter"}
}
}
local rowWeights = {
{1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1},
{1,1,1,1,1,1,1,1,1,1},
{1.5,1,1,1,1,1,1,1,1.5},
{1.5,1,4,1,1.5}
}
local buttons = {}
local currentPage = "lower"
local function SafeBackspace(editBox)
local text = editBox:GetText()
local len = string.len(text)
if len > 0 then
local lastByte = string.byte(text, len)
if lastByte >= 128 and lastByte <= 191 then
editBox:SetText(string.sub(text, 1, len - 2))
else
editBox:SetText(string.sub(text, 1, len - 1))
end
end
end
local function UpdateKeyboard()
for r, row in ipairs(pages[currentPage]) do
for c, keyText in ipairs(row) do
local btn = buttons[r][c]
if btn then
btn:SetText(keyText)
btn.keyAction = keyText
if keyText == "Mayus"
or keyText == "<-"
or keyText == "Enter"
or keyText == "?123"
or keyText == "ABC"
or keyText == "=\\<" then
btn.defaultColor = colorSpecial
else
btn.defaultColor = colorKey
end
btn:SetBackdropColor(unpack(btn.defaultColor))
end
end
end
end
local function BuildKeyboard()
local padX, padY, spacing = 10, 60, 8
local availWidth = 900 - (padX * 2)
local rowHeight = (360 - padY - 10 - (spacing * 4)) / 5
for r, weights in ipairs(rowWeights) do
buttons[r] = {}
local totalWeight = 0
for _, w in ipairs(weights) do
totalWeight = totalWeight + w
end
local widthToShare = availWidth - (spacing * (#weights - 1))
local currentX = padX
local currentY = -padY - ((r - 1) * (rowHeight + spacing))
for c, weight in ipairs(weights) do
local btnWidth = (weight / totalWeight) * widthToShare
local btn = C.CreateStyledButton(VKB, "", btnWidth, rowHeight)
btn:SetPoint("TOPLEFT", VKB, "TOPLEFT", currentX, currentY)
local oldDown = btn:GetScript("OnMouseDown")
btn:SetScript("OnMouseDown", function(self, button)
if oldDown then oldDown(self, button) end
RaiseKeyboardTop()
end)
btn:SetScript("OnClick", function(self)
local eb = activeEditBox
if not eb or not eb:IsVisible() then
return
end
local key = self.keyAction
if key == "Mayus" then
currentPage = (currentPage == "lower") and "upper" or "lower"
UpdateKeyboard()
elseif key == "?123" then
currentPage = "sym1"
UpdateKeyboard()
elseif key == "=\\<" then
currentPage = "sym2"
UpdateKeyboard()
elseif key == "ABC" then
currentPage = "lower"
UpdateKeyboard()
elseif key == "Espacio" then
eb:Insert(" ")
eb:SetFocus()
elseif key == "<-" then
SafeBackspace(eb)
eb:SetFocus()
elseif key == "Enter" then
local onEnter = eb:GetScript("OnEnterPressed")
if onEnter then
onEnter(eb)
end
eb:ClearFocus()
VKB:Hide()
else
eb:Insert(key)
eb:SetFocus()
end
end)
buttons[r][c] = btn
currentX = currentX + btnWidth + spacing
end
end
end
BuildKeyboard()
UpdateKeyboard()
local function HookBagDragStates()
local function hookWindow(win, owner)
if not win or win.capriVkbDragHooked then
return
end
win.capriVkbDragHooked = true
win:HookScript("OnMouseDown", function()
if CapriOtherWindowDragging() then return end
VKB:SetFrameStrata("HIGH")
end)
win:HookScript("OnDragStart", function()
_G.CapriUIState.dragging = true
_G.CapriUIState.dragOwner = owner
VKB:SetFrameStrata("HIGH")
end)
win:HookScript("OnDragStop", function()
if _G.CapriUIState.dragOwner == owner then
_G.CapriUIState.dragging = false
_G.CapriUIState.dragOwner = nil
end
end)
end
hookWindow(G("UnifiedBagFrame"), "bag")
hookWindow(G("UnifiedBankFrame"), "bank")
end
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
local function ShowVKBFor(self)
activeEditBox = self
if CapriOtherWindowDragging() then
return
end
if isKeyboardEnabled and loginDone and GetTime() > suppressShowUntil then
currentPage = "lower"
UpdateKeyboard()
SettingsPanel:Hide()
DragOverlay:Hide()
RaiseKeyboardTop()
VKB:Show()
end
end
local function HookAllEditBoxes()
local f = EnumerateFrames()
while f do
if f:IsObjectType("EditBox") and not f.vkbHooked then
f.vkbHooked = true
f:HookScript("OnEditFocusGained", function(self)
ShowVKBFor(self)
end)
f:HookScript("OnMouseDown", function(self)
ShowVKBFor(self)
end)
f:HookScript("OnEnterPressed", function()
VKB:Hide()
end)
f:HookScript("OnEscapePressed", function()
VKB:Hide()
end)
end
f = EnumerateFrames(f)
end
end
EventFrame:SetScript("OnEvent", function(self, event)
if type(CaprimedinaUIDB) ~= "table" then
CaprimedinaUIDB = {}
end
if CaprimedinaUIDB.scale == nil then CaprimedinaUIDB.scale = 0.95 end
if CaprimedinaUIDB.enabled == nil then CaprimedinaUIDB.enabled = true end
if CaprimedinaUIDB.point == nil then CaprimedinaUIDB.point = "BOTTOM" end
if CaprimedinaUIDB.xOfs == nil then CaprimedinaUIDB.xOfs = 0 end
if CaprimedinaUIDB.yOfs == nil then CaprimedinaUIDB.yOfs = 0 end
isKeyboardEnabled = CaprimedinaUIDB.enabled
VKB:SetScale(CaprimedinaUIDB.scale)
scaleDisplay:SetText(math.floor(CaprimedinaUIDB.scale * 100 + 0.5) .. "%")
VKB:ClearAllPoints()
VKB:SetPoint(
CaprimedinaUIDB.point,
UIParent,
CaprimedinaUIDB.point,
CaprimedinaUIDB.xOfs,
CaprimedinaUIDB.yOfs
)
loginDone = true
suppressShowUntil = GetTime() + 1.5
VKB:Hide()
HookAllEditBoxes()
HookBagDragStates()
end)
local scanTimer = 0
local hookTimer = 0
local vkbCheckTimer = 0
EventFrame:SetScript("OnUpdate", function(self, elapsed)
scanTimer = scanTimer + elapsed
hookTimer = hookTimer + elapsed
if scanTimer > 8.0 then
scanTimer = 0
HookAllEditBoxes()
end
if hookTimer > 2.0 then
hookTimer = 0
HookBagDragStates()
end
if _G.CapriUIState and _G.CapriUIState.dragging and not IsMouseButtonDown("LeftButton") then
_G.CapriUIState.dragging = false
_G.CapriUIState.dragOwner = nil
end
vkbCheckTimer = vkbCheckTimer + elapsed
if vkbCheckTimer < 0.1 then return end
vkbCheckTimer = 0
if not VKB:IsShown() then return end
if IsMouseButtonDown("LeftButton")
and MouseIsOver(VKB)
and not CapriOtherWindowDragging() then
RaiseKeyboardTop()
end
if activeEditBox and not CapriOtherWindowDragging() then
if not activeEditBox:HasFocus()
and not IsMouseButtonDown("LeftButton")
and not VKB:IsMouseOver() then
VKB:Hide()
end
end
end)