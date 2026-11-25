local _G = _G or getfenv(0)
local C = _G.CapriUI

local ADDON_NAME = "UI Escalador"
local ESCALA_MIN = 0.5
local ESCALA_MAX = 2.0
local ESCALA_PASO = 0.1

local valorSeleccionado = 1.0

local function GetDB()
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    if CaprimedinaUIDB.enableEscala == nil then
        CaprimedinaUIDB.enableEscala = true
    end

    if CaprimedinaUIDB.escalaValor == nil then
        CaprimedinaUIDB.escalaValor = 1.0
    end

    return CaprimedinaUIDB
end

local function ClampScale(value)
    value = tonumber(value) or 1.0

    if value < ESCALA_MIN then
        value = ESCALA_MIN
    end

    if value > ESCALA_MAX then
        value = ESCALA_MAX
    end

    return value
end

local function Percent(value)
    return math.floor(ClampScale(value) * 100 + 0.5)
end

local frame = CreateFrame("Frame", "UIEscaladorFrame", UIParent)
frame:SetSize(240, 200)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
frame:Hide()
C.StyleWindow(frame)
frame:SetClampedToScreen(true)

local titulo = frame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(titulo, 16)
titulo:SetPoint("TOP", 0, -12)
titulo:SetText("Escala de Interfaz")
titulo:SetTextColor(1, 1, 1)

local closeX = C.CreateStyledClose(frame)

local slider = CreateFrame("Slider", "UIEscaladorSlider", frame, "OptionsSliderTemplate")
slider:SetPoint("TOP", 0, -55)
slider:SetWidth(190)
slider:SetMinMaxValues(ESCALA_MIN, ESCALA_MAX)
slider:SetValueStep(ESCALA_PASO)
slider:SetValue(1.0)

local sliderName = slider:GetName()
if sliderName then
    local text = _G[sliderName .. "Text"]
    local low = _G[sliderName .. "Low"]
    local high = _G[sliderName .. "High"]

    if text then
        text:SetText("Tamano de la UI")
        C.SetOutlineFont(text, 13)
    end

    if low then
        low:SetText("50%")
        C.SetOutlineFont(low, 12)
    end

    if high then
        high:SetText("200%")
        C.SetOutlineFont(high, 12)
    end
end

local textoValor = frame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(textoValor, 14)
textoValor:SetPoint("TOP", slider, "BOTTOM", 0, -8)
textoValor:SetText("Seleccionado: 100%")

local function UpdateValueText(value)
    textoValor:SetText("Seleccionado: " .. Percent(value) .. "%")
end

slider:SetScript("OnValueChanged", function(self, value)
    valorSeleccionado = ClampScale(value)
    UpdateValueText(valorSeleccionado)
end)

function frame:Refresh()
    local value = ClampScale(UIParent:GetScale())
    slider:SetValue(value)
    valorSeleccionado = value
    UpdateValueText(value)
end

function frame:UpdateFromDB()
    local db = GetDB()
    local value = ClampScale(db.escalaValor or 1.0)

    if db.enableEscala then
        slider:SetValue(value)
        valorSeleccionado = value
    else
        slider:SetValue(1.0)
        valorSeleccionado = 1.0
    end

    UpdateValueText(valorSeleccionado)
end

local function ApplyScale(value, showMessage)
    local db = GetDB()
    value = ClampScale(value)

    db.enableEscala = true
    db.escalaValor = value
    valorSeleccionado = value

    UIParent:SetScale(value)
    SetCVar("useUiScale", "1")
    SetCVar("uiscale", tostring(value))

    if showMessage then
        C.Print("[" .. ADDON_NAME .. "] Escala aplicada: " .. Percent(value) .. "%")
    end

    if frame.UpdateFromDB then
        frame:UpdateFromDB()
    end
end

local btnAplicar = C.CreateStyledButton(frame, "Aplicar", 100, 26)
btnAplicar:SetPoint("BOTTOMLEFT", 12, 12)
btnAplicar:SetScript("OnClick", function()
    ApplyScale(valorSeleccionado, true)
end)

local btnReset = C.CreateStyledButton(frame, "Reset 100%", 100, 26, true)
btnReset:SetPoint("BOTTOMRIGHT", -12, 12)
btnReset:SetScript("OnClick", function()
    slider:SetValue(1.0)
    valorSeleccionado = 1.0
    UpdateValueText(1.0)
    ApplyScale(1.0, false)

    C.Print("[" .. ADDON_NAME .. "] Escala reiniciada a 100%")
end)

SLASH_UIESCALADOR1 = "/escala"
SLASH_UIESCALADOR2 = "/uiscale"
SlashCmdList["UIESCALADOR"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Refresh()
        frame:Show()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function()
    local db = GetDB()

    if db.enableEscala then
        local value = ClampScale(db.escalaValor or UIParent:GetScale())
        UIParent:SetScale(value)
        SetCVar("useUiScale", "1")
        SetCVar("uiscale", tostring(value))
    else
        UIParent:SetScale(1.0)
        SetCVar("useUiScale", "0")
        SetCVar("uiscale", "1")
    end

    frame:UpdateFromDB()

    C.Print("[" .. ADDON_NAME .. "] Cargado. Usa /escala o /uiscale")
end)