local _G = _G or getfenv(0)
local C = _G.CapriUI

if not C then
    C = {}
    _G.CapriUI = C
end

if not SlashCmdList then
    SlashCmdList = {}
end

if not C.Print then
    C.Print = function(msg)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[CaprimedinaUI]|r " .. tostring(msg))
        end
    end
end

if not C.SetOutlineFont then
    C.SetOutlineFont = function(fs, size)
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
end

if not C.StyleWindow then
    C.StyleWindow = function(frame)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8"
        })
        frame:SetBackdropColor(0.10, 0.11, 0.12, 0.95)
    end
end

if not C.CreateStyledButton then
    C.CreateStyledButton = function(parent, text, w, h, special)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetWidth(w)
        btn:SetHeight(h)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8"
        })

        if special then
            btn:SetBackdropColor(0.25, 0.27, 0.30, 1.00)
        else
            btn:SetBackdropColor(0.18, 0.19, 0.21, 1.00)
        end

        btn.text = btn:CreateFontString(nil, "OVERLAY")
        C.SetOutlineFont(btn.text, 13)
        btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.text:SetText(text or "")

        btn.SetText = function(self, t)
            if self.text then
                self.text:SetText(t)
            end
        end

        return btn
    end
end

if not C.CreateStyledClose then
    C.CreateStyledClose = function(parent)
        local btn = C.CreateStyledButton(parent, "X", 40, 26, true)
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
        btn:SetScript("OnClick", function()
            parent:Hide()
        end)
        return btn
    end
end


local function BarEnabled()
    return type(CaprimedinaUIDB) == "table" and CaprimedinaUIDB.enableBars ~= false
end


local function TrimEnd(s)
    return (string.gsub(s, "%s+$", ""))
end

local function MigrateSpacedDB()
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
        return
    end

    local changes = {}

    for k, v in pairs(CaprimedinaUIDB) do
        if type(k) == "string" then
            local nk = TrimEnd(k)
            if nk ~= k then
                changes[#changes + 1] = {
                    old = k,
                    new = nk,
                    value = v
                }
            end
        end
    end

    for _, ch in ipairs(changes) do
        if CaprimedinaUIDB[ch.new] == nil then
            CaprimedinaUIDB[ch.new] = ch.value
        end

        CaprimedinaUIDB[ch.old] = nil
    end
end

MigrateSpacedDB()

local function GetDBValue(...)
    if type(CaprimedinaUIDB) ~= "table" then
        return nil
    end

    for i = 1, select("#", ...) do
        local k = select(i, ...)
        if type(k) == "string" and CaprimedinaUIDB[k] ~= nil then
            return CaprimedinaUIDB[k]
        end
    end

    return nil
end

local function GetBarValue(barID, suffix, default)
    local v = GetDBValue(
        barID .. suffix,
        barID .. suffix .. " ",
        barID .. " " .. suffix
    )

    if v == nil then
        v = default
    end

    return v
end

local function GetBarBool(barID, suffix, default)
    local v = GetBarValue(barID, suffix, nil)

    if v == nil then
        return default
    end

    if v == true or v == 1 or v == "1" or v == "true" or v == "TRUE" then
        return true
    end

    if v == false or v == 0 or v == "0" or v == "false" or v == "FALSE" then
        return false
    end

    return default
end

local function SetBarValue(barID, suffix, value)
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    CaprimedinaUIDB[barID .. suffix] = value
    CaprimedinaUIDB[barID .. suffix .. " "] = nil
    CaprimedinaUIDB[barID .. " " .. suffix] = nil
end

local function FixSpacedGlobals()
    local names = {
        "CapriDragMain",
        "CapriDragBL",
        "CapriDragBR",
        "CapriDragRight",
        "CapriDragLeft",
        "CapriTooltipAnchor",
        "CapriPlayerAnchor",
        "CapriTargetAnchor",
        "CapriMinimapAnchor",
        "CapriMasterEditControl",
        "CapriContextMenu",
        "CapriBindFrame",
        "CapriQuestAnchor",
        "CapriQuestMenu"
    }

    for _, name in ipairs(names) do
        if _G[name] == nil and _G[name .. " "] ~= nil then
            _G[name] = _G[name .. " "]
        end
    end
end

FixSpacedGlobals()


local orig_CooldownFrame_SetTimer = CooldownFrame_SetTimer

if type(orig_CooldownFrame_SetTimer) == "function" then
    function CooldownFrame_SetTimer(cooldownFrame, start, duration, enable)
        orig_CooldownFrame_SetTimer(cooldownFrame, start, duration, enable)

        if not BarEnabled() then
            return
        end

        if not cooldownFrame then
            return
        end

        local enabled = (enable == nil) or (enable == 1) or (enable == true)

        if start and duration and start > 0 and duration > 2.5 and enabled then
            local f = cooldownFrame.capriTextFrame

            if not f then
                local parent = nil
                if cooldownFrame.GetParent then
                    parent = cooldownFrame:GetParent()
                end

                f = CreateFrame("Frame", nil, parent or UIParent)
                f:SetAllPoints(parent or UIParent)

                if cooldownFrame.GetFrameLevel then
                    f:SetFrameLevel(cooldownFrame:GetFrameLevel() + 5)
                end

                local textStr = f:CreateFontString(nil, "OVERLAY")
                textStr:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
                textStr:SetPoint("CENTER", f, "CENTER", 0, 0)
                f.textStr = textStr
                cooldownFrame.capriTextFrame = f
            end

            f.start = start
            f.duration = duration
            f.cd = cooldownFrame

            f:SetScript("OnUpdate", function(self)
                if not self.start or not self.duration or (self.cd and not self.cd:IsVisible()) then
                    self:SetScript("OnUpdate", nil)
                    if self.textStr then
                        self.textStr:SetText("")
                        self.textStr:Hide()
                    end
                    return
                end

                local remain = self.start + self.duration - GetTime()

                if remain > 0 then
                    if self.textStr and not self.textStr:IsVisible() then
                        self.textStr:Show()
                    end

                    local txt

                    if remain >= 86400 then
                        txt = math.floor(remain / 86400) .. "d"
                    elseif remain >= 3600 then
                        txt = math.floor(remain / 3600) .. "h"
                    elseif remain >= 60 then
                        txt = math.floor(remain / 60) .. "m"
                    else
                        txt = tostring(math.floor(remain))
                    end

                    self.textStr:SetText(txt)

                    if remain < 5 then
                        self.textStr:SetTextColor(1, 0, 0)
                    elseif remain < 60 then
                        self.textStr:SetTextColor(1, 1, 0)
                    else
                        self.textStr:SetTextColor(1, 1, 1)
                    end
                else
                    if self.textStr then
                        self.textStr:SetText("")
                        self.textStr:Hide()
                    end
                    self:SetScript("OnUpdate", nil)
                end
            end)

            if f.textStr then
                f.textStr:Show()
            end
        else
            local f = cooldownFrame.capriTextFrame
            if f then
                if f.textStr then
                    f.textStr:SetText("")
                    f.textStr:Hide()
                end
                f:SetScript("OnUpdate", nil)
            end
        end
    end
end


local function GetBlizzardBindCommand(btnName)
    if not btnName then
        return nil
    end

    if string.find(btnName, "MultiBarBottomLeftButton", 1, true) then
        return (string.gsub(btnName, "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON"))
    end

    if string.find(btnName, "MultiBarBottomRightButton", 1, true) then
        return (string.gsub(btnName, "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON"))
    end

    if string.find(btnName, "MultiBarRightButton", 1, true) then
        return (string.gsub(btnName, "MultiBarRightButton", "MULTIACTIONBAR3BUTTON"))
    end

    if string.find(btnName, "MultiBarLeftButton", 1, true) then
        return (string.gsub(btnName, "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON"))
    end

    if string.find(btnName, "BonusActionButton", 1, true) then
        return (string.gsub(btnName, "BonusActionButton", "BONUSACTIONBUTTON"))
    end

    if string.find(btnName, "ActionButton", 1, true) then
        return (string.gsub(btnName, "ActionButton", "ACTIONBUTTON"))
    end

    if string.find(btnName, "ShapeshiftButton", 1, true) then
        return (string.gsub(btnName, "ShapeshiftButton", "SHAPESHIFTBUTTON"))
    end

    if string.find(btnName, "PetActionButton", 1, true) then
        return (string.gsub(btnName, "PetActionButton", "PETBUTTON"))
    end

    return nil
end

CapriCustomBindButtons = CapriCustomBindButtons or {}

local function GetBindCommand(btnName)
    if not btnName then
        return nil
    end

    if CapriCustomBindButtons[btnName] then
        return CapriCustomBindButtons[btnName]
    end

    return GetBlizzardBindCommand(btnName)
end

local function SafeSaveBindings()
    if type(SaveBindings) == "function" then
        local bindingSet = (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
        SaveBindings(bindingSet)
    end
end

local function FormatKeyText(keyText)
    if not keyText then
        return ""
    end

    keyText = string.gsub(keyText, "SHIFT%-", "S-")
    keyText = string.gsub(keyText, "ALT%-", "A-")
    keyText = string.gsub(keyText, "CTRL%-", "C-")
    keyText = string.gsub(keyText, "NUMPAD", "N")

    return keyText
end

local capriBindOverlays = {}
local capriBindSelected = nil

local BindFrame = CreateFrame("Frame", "CapriBindFrame", UIParent)
BindFrame:SetFrameStrata("DIALOG")
BindFrame:EnableKeyboard(true)
BindFrame:SetPoint("TOP", UIParent, "TOP", 0, -50)
BindFrame:SetWidth(450)
BindFrame:SetHeight(125)
C.StyleWindow(BindFrame)
BindFrame:Hide()

local bindTitle = BindFrame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bindTitle, 16)
bindTitle:SetPoint("TOP", BindFrame, "TOP", 0, -15)
bindTitle:SetText("MODO ASIGNACION DE TECLAS")
bindTitle:SetTextColor(1, 1, 1)

local bindSub = BindFrame:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(bindSub, 13)
bindSub:SetPoint("TOP", BindFrame, "TOP", 0, -35)
bindSub:SetText("Haz click en un aro verde para seleccionarlo.")
bindSub:SetTextColor(1, 1, 1)

local btnAccept = C.CreateStyledButton(BindFrame, "Aceptar", 120, 25, true)
btnAccept:SetPoint("BOTTOMRIGHT", BindFrame, "BOTTOM", -5, 12)
btnAccept:SetScript("OnClick", function()
    SafeSaveBindings()
    BindFrame:Hide()
end)

local btnReset = C.CreateStyledButton(BindFrame, "Restablecer Todo", 120, 25, true)
btnReset:SetPoint("BOTTOMLEFT", BindFrame, "BOTTOM", 5, 12)
btnReset:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then
        C.Print("|cffff0000No puedes restablecer teclas en combate.|r")
        return
    end

    if type(LoadBindings) == "function" then
        LoadBindings(1)
    end

    if type(CapriCustomBindButtons) == "table" then
        for btnName, cmd in pairs(CapriCustomBindButtons) do
            local k1, k2, k3, k4 = GetBindingKey(cmd)
            if k1 then
                SetBinding(k1)
            end
            if k2 then
                SetBinding(k2)
            end
            if k3 then
                SetBinding(k3)
            end
            if k4 then
                SetBinding(k4)
            end
        end
    end

    SafeSaveBindings()

    if type(CapriRefreshCustomHotkeys) == "function" then
        CapriRefreshCustomHotkeys()
    end

    C.Print("Todas las teclas han sido restablecidas.")
    BindFrame:Hide()
end)

BindFrame:SetScript("OnUpdate", function(self)
    local uiScale = UIParent:GetEffectiveScale()
    if not uiScale or uiScale == 0 then
        uiScale = 1
    end

    for _, o in ipairs(capriBindOverlays) do
        local btn = o.targetBtn

        if btn and btn:IsVisible() then
            local btnScale = (btn.GetEffectiveScale and btn:GetEffectiveScale()) or 1
            if btnScale == 0 then
                btnScale = 1
            end

            local btnWidth = (btn.GetWidth and btn:GetWidth()) or 36
            local btnHeight = (btn.GetHeight and btn:GetHeight()) or 36

            if btnWidth == 0 then
                btnWidth = 36
            end

            if btnHeight == 0 then
                btnHeight = 36
            end

            o:ClearAllPoints()
            o:SetPoint("CENTER", btn, "CENTER", 0, 0)
            o:SetScale(btnScale / uiScale)
            o:SetWidth(btnWidth)
            o:SetHeight(btnHeight)

            if not o:IsVisible() then
                o:Show()
            end
        else
            if o:IsVisible() then
                o:Hide()
            end
        end
    end
end)

BindFrame:SetScript("OnShow", function(self)
    self:EnableKeyboard(true)
    bindSub:SetText("Haz click en un aro verde para seleccionarlo.")
end)

BindFrame:SetScript("OnHide", function(self)
    self:EnableKeyboard(false)
    capriBindSelected = nil

    for _, o in ipairs(capriBindOverlays) do
        if o.glow then
            o.glow:Hide()
        end
        if o.tex then
            o.tex:Show()
        end
        o:Hide()
    end
end)

BindFrame:SetScript("OnKeyDown", function(self, key)
    if not key then
        return
    end

    if key == "UNKNOWN" or key == "LSHIFT" or key == "RSHIFT"
        or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" then
        return
    end

    if key == "ESCAPE" then
        if capriBindSelected then
            capriBindSelected = nil

            for _, o in ipairs(capriBindOverlays) do
                if o.glow then
                    o.glow:Hide()
                end
                if o.tex then
                    o.tex:Show()
                end
            end

            bindSub:SetText("Haz click en un aro verde para seleccionarlo.")
        else
            self:Hide()
        end
        return
    end

    if not capriBindSelected then
        return
    end

    local cmd = GetBindCommand(capriBindSelected:GetName())
    if not cmd then
        return
    end

    local hotkey = _G[capriBindSelected:GetName() .. "HotKey"]

    if key == "BACKSPACE" or key == "DELETE" then
        local oldKey = GetBindingKey(cmd)
        if oldKey then
            SetBinding(oldKey)
        end

        C.Print("Tecla eliminada.")

        if hotkey then
            hotkey:SetText("")
            hotkey:Hide()
        end
    else
        local modifier = ""

        if IsAltKeyDown() then
            modifier = "ALT-" .. modifier
        end

        if IsControlKeyDown() then
            modifier = "CTRL-" .. modifier
        end

        if IsShiftKeyDown() then
            modifier = "SHIFT-" .. modifier
        end

        local bindKey = modifier .. key
        local oldCmd = GetBindingAction(bindKey)

        if oldCmd and oldCmd ~= "" then
            SetBinding(bindKey)
        end

        if CapriCustomBindButtons[capriBindSelected:GetName()] then
            local existing = GetBindingKey(cmd)
            if existing then
                SetBinding(existing)
            end
        end

        SetBinding(bindKey, cmd)
        C.Print("Tecla asignada: " .. bindKey)

        if hotkey then
            local keyText = GetBindingKey(cmd)
            if keyText and keyText ~= "" then
                hotkey:SetText(FormatKeyText(keyText))
                hotkey:Show()
            end
        end
    end

    SafeSaveBindings()

    if type(CapriRefreshCustomHotkeys) == "function" then
        CapriRefreshCustomHotkeys()
    end

    capriBindSelected = nil

    for _, o in ipairs(capriBindOverlays) do
        if o.glow then
            o.glow:Hide()
        end
        if o.tex then
            o.tex:Show()
        end
    end

    bindSub:SetText("Asignado exitosamente. Selecciona otro boton.")
end)

SLASH_CAPRIBIND1 = "/capribind"

SlashCmdList["CAPRIBIND"] = function()
    if not BarEnabled() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        C.Print("|cffff0000No puedes asignar teclas en combate.|r")
        return
    end

    if BindFrame:IsVisible() then
        BindFrame:Hide()
    else
        BindFrame:Show()
    end
end


local function SetButtonShape(btn, isCircular)
    if not btn then
        return
    end

    local btnName = btn.GetName and btn:GetName()
    local icon = btnName and _G[btnName .. "Icon"]
    local nt = (btnName and _G[btnName .. "NormalTexture"]) or (btn.GetNormalTexture and btn:GetNormalTexture())
    local btnSize = (btn.GetWidth and btn:GetWidth()) or 36

    if not btnSize or btnSize == 0 then
        btnSize = 36
    end

    local ringSize = btnSize * 1.12
    local iconSize = btnSize * 0.80

    if not btn.capriOverlayFrame then
        btn.capriOverlayFrame = CreateFrame("Frame", nil, btn)
        btn.capriOverlayFrame:SetAllPoints(btn)

        local cd = btnName and _G[btnName .. "Cooldown"]
        if cd then
            btn.capriOverlayFrame:SetFrameLevel(cd:GetFrameLevel() + 3)
        else
            btn.capriOverlayFrame:SetFrameLevel(btn:GetFrameLevel() + 3)
        end

        -- Anillo dorado de Caprimedina.
        btn.circBorder = btn.capriOverlayFrame:CreateTexture(nil, "OVERLAY")
        btn.circBorder:SetTexture(C.tex and C.tex.ring or "Interface\\AddOns\\CaprimedinaUI\\texturas\\ring")
        btn.circBorder:SetPoint("CENTER", btn.capriOverlayFrame, "CENTER", 0, 0)
        btn.circBorder:Hide()

        if C.AddHoverGlow then
            C.AddHoverGlow(btn, btnSize * 2.1, 0.45)
        end
    end

    btn.circBorder:SetWidth(ringSize)
    btn.circBorder:SetHeight(ringSize)

    if isCircular then
        if icon then
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            icon:SetSize(iconSize, iconSize)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        local cd = btnName and _G[btnName .. "Cooldown"]
        if cd then
            cd:ClearAllPoints()
            cd:SetPoint("CENTER", btn, "CENTER", 0, 0)
            cd:SetSize(iconSize, iconSize)
        end

        if nt then
            nt:SetAlpha(0)
        end

        btn.circBorder:Show()

        if btn.SetHighlightTexture then
            btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
            local hl = btn:GetHighlightTexture()
            if hl then
                hl:SetBlendMode("ADD")
                hl:ClearAllPoints()
                hl:SetPoint("CENTER", btn, "CENTER", 0, 0)
                hl:SetWidth(ringSize)
                hl:SetHeight(ringSize)
            end
        end

        if btn.SetPushedTexture then
            btn:SetPushedTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
            local pu = btn:GetPushedTexture()
            if pu then
                pu:SetBlendMode("ADD")
                pu:ClearAllPoints()
                pu:SetPoint("CENTER", btn, "CENTER", 0, 0)
                pu:SetWidth(ringSize)
                pu:SetHeight(ringSize)
            end
        end

        if btn.GetCheckedTexture then
            local chk = btn:GetCheckedTexture()
            if chk then
                chk:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
                chk:SetBlendMode("ADD")
                chk:ClearAllPoints()
                chk:SetPoint("CENTER", btn, "CENTER", 0, 0)
                chk:SetWidth(ringSize)
                chk:SetHeight(ringSize)
            end
        end
    else
        if icon then
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            icon:SetSize(btnSize, btnSize)
            icon:SetTexCoord(0, 1, 0, 1)
        end

        if nt then
            nt:SetAlpha(1)
        end

        btn.circBorder:Hide()

        if btn.SetHighlightTexture then
            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            local hl = btn:GetHighlightTexture()
            if hl then
                hl:SetBlendMode("ADD")
                hl:ClearAllPoints()
                hl:SetAllPoints(btn)
            end
        end

        if btn.SetPushedTexture then
            btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
            local pu = btn:GetPushedTexture()
            if pu then
                pu:SetBlendMode("BLEND")
                pu:ClearAllPoints()
                pu:SetAllPoints(btn)
            end
        end

        if btn.GetCheckedTexture then
            local chk = btn:GetCheckedTexture()
            if chk then
                chk:SetTexture("Interface\\Buttons\\CheckButtonHilight")
                chk:SetBlendMode("ADD")
                chk:ClearAllPoints()
                chk:SetAllPoints(btn)
            end
        end
    end
end


local hookedActionButtonUpdate = false
local hookedMultiActionBarUpdate = false
local hookedInterfaceOptionsUpdate = false

local function CapriAlwaysShowBars()
    if GetCVarBool then
        return GetCVarBool("alwaysShowActionBars")
    end
    return false
end

local function GetButtonActionSlot(btn)
    if not btn then
        return 0
    end

    if btn.action and btn.action ~= 0 then
        return btn.action
    end

    local name = btn.GetName and btn:GetName()
    if not name then
        return 0
    end

    local num = tonumber(string.match(name, "(%d+)$")) or 0

    if string.find(name, "^MultiBarBottomLeftButton") then
        return 12 + num
    elseif string.find(name, "^MultiBarBottomRightButton") then
        return 24 + num
    elseif string.find(name, "^MultiBarRightButton") then
        return 36 + num
    elseif string.find(name, "^MultiBarLeftButton") then
        return 48 + num
    elseif string.find(name, "^BonusActionButton") then
        return num
    elseif string.find(name, "^ActionButton") then
        local page = CURRENT_ACTIONBAR_PAGE or 1
        return num + ((page - 1) * 12)
    end

    return 0
end

local function CapriShouldShowButton(btn)
    if not btn then
        return false
    end

    if CapriAlwaysShowBars() then
        return true
    end

    local slot = GetButtonActionSlot(btn)
    if slot and slot > 0 and HasAction and HasAction(slot) then
        return true
    end

    return false
end

local function CapriRefreshActionButton(btn)
    if not btn then
        return
    end

    if not BarEnabled() then
        return
    end

    if btn.capriLayoutHidden then
        btn:Hide()
        return
    end

    if CapriShouldShowButton(btn) then
        btn:Show()
    else
        btn:Hide()
    end
end

-- Al pulsar un boton de la barra de accion, se enciende el mismo brillo
-- (capriHoverGlow) que aparece al pasar el raton por encima.
local function CapriEnsureActionPressGlow(btn)
    if not btn then return end
    if not btn.capriHoverGlow and C.AddHoverGlow then
        C.AddHoverGlow(btn, (btn.GetWidth and btn:GetWidth() or 36) * 2.1, 0.45)
    end
end

local function CapriSyncActionPressGlow(btn, elapsed)
    if not btn then return end
    if not btn:IsShown() then
        if btn.capriHoverGlow and not (btn.IsMouseOver and btn:IsMouseOver()) then
            btn.capriHoverGlow:SetAlpha(0)
        end
        return
    end
    CapriEnsureActionPressGlow(btn)
    if not btn.capriHoverGlow then return end

    -- Brillo solo mientras el boton esta pulsado (raton o tecla). Al soltarlo
    -- se apaga en el acto, sin temporizador de espera (antes 0.12 s).
    local pushed = (btn.GetButtonState and btn:GetButtonState() == "PUSHED")
    if pushed then
        btn.capriHoverGlow:SetAlpha(btn.capriHoverGlowAlpha or 0.45)
    elseif not (btn.IsMouseOver and btn:IsMouseOver()) then
        btn.capriHoverGlow:SetAlpha(0)
    end
end

local function CapriUpdateAllManagedButtons()
    if not BarEnabled() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    for i = 1, 12 do
        CapriRefreshActionButton(_G["ActionButton" .. i])
        CapriRefreshActionButton(_G["BonusActionButton" .. i])
        CapriRefreshActionButton(_G["MultiBarBottomLeftButton" .. i])
        CapriRefreshActionButton(_G["MultiBarBottomRightButton" .. i])
        CapriRefreshActionButton(_G["MultiBarRightButton" .. i])
        CapriRefreshActionButton(_G["MultiBarLeftButton" .. i])
    end
end

local function TryHookActionBarVisibility()
    if not hookedActionButtonUpdate and type(ActionButton_Update) == "function" then
        hookedActionButtonUpdate = true
        hooksecurefunc("ActionButton_Update", function(button)
            if not BarEnabled() then
                return
            end
            CapriRefreshActionButton(button)
        end)
    end

    if not hookedMultiActionBarUpdate and type(MultiActionBar_Update) == "function" then
        hookedMultiActionBarUpdate = true
        hooksecurefunc("MultiActionBar_Update", function()
            CapriUpdateAllManagedButtons()
        end)
    end

    if not hookedInterfaceOptionsUpdate and type(InterfaceOptionsActionBarsPanel_Update) == "function" then
        hookedInterfaceOptionsUpdate = true
        hooksecurefunc("InterfaceOptionsActionBarsPanel_Update", function()
            CapriUpdateAllManagedButtons()
        end)
    end
end

local function IsMainBarSwapButton(btn)
    if not btn or not btn.GetName then
        return false
    end

    local name = btn:GetName()
    if not name then
        return false
    end

    if string.find(name, "^ActionButton%d+$") then
        return true
    end

    if string.find(name, "^BonusActionButton%d+$") then
        return true
    end

    return false
end


local capriBarStrata = "HIGH"

local capriCoverPanels = {
    "SpellBookFrame",
    "CharacterFrame",
    "QuestLogFrame",
    "MerchantFrame",
    "BankFrame",
    "TradeFrame",
    "AuctionFrame",
    "MailFrame",
    "FriendsFrame",
    "HonorFrame",
    "PVPFrame",
    "ClassTrainerFrame",
    "TradeSkillFrame",
    "CraftFrame",
    "SkillFrame",
    "MacroFrame",
    "ItemTextFrame",
    "GossipFrame",
    "QuestFrame",
    "TaxiFrame",
    "PetStableFrame",
    "InspectFrame",
    "GameMenuFrame",
    "HelpFrame",
    "ChatConfigFrame",
    "KeyBindingFrame",
    "InterfaceOptionsFrame",
    "VideoOptionsFrame",
    "LootFrame",
    "TalentFrame"
}

local function CapriAnyCoverPanelOpen()
    for _, n in ipairs(capriCoverPanels) do
        local f = _G[n]
        if f and f:IsShown() then
            return true
        end
    end
    return false
end

local function CapriUpdateBarStrata()
    if not BarEnabled() then
        return
    end

    local want = CapriAnyCoverPanelOpen() and "LOW" or "HIGH"

    if want == capriBarStrata then
        return
    end

    capriBarStrata = want

    local prefixes = {
        "ActionButton",
        "BonusActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }

    for i = 1, 12 do
        for _, p in ipairs(prefixes) do
            local b = _G[p .. i]
            if b and b.SetFrameStrata then
                b:SetFrameStrata(want)
            end
        end
    end
end


local function ManageButton(frame, anchor, x, y, image, bonus, scale, isCircular)
    if not frame or not anchor or not BarEnabled() then
        return
    end

    if not CapriActionHideFrame then
        CapriActionHideFrame = CreateFrame("Frame", "CapriActionHide", BonusActionBarFrame or UIParent)
        CapriActionHideFrame.buttons = {}

        CapriActionHideFrame:SetScript("OnShow", function(self)
            if not BarEnabled() then
                return
            end

            for button, isBonus in pairs(self.buttons) do
                if IsMainBarSwapButton(button) then
                    button:SetAlpha(isBonus == 1 and 1 or 0)
                end
            end
        end)

        CapriActionHideFrame:SetScript("OnHide", function(self)
            if not BarEnabled() then
                return
            end

            for button, isBonus in pairs(self.buttons) do
                if IsMainBarSwapButton(button) then
                    button:SetAlpha(isBonus == 0 and 1 or 0)
                end
            end
        end)
    end

    if IsMainBarSwapButton(frame) then
        CapriActionHideFrame.buttons[frame] = bonus and 1 or 0

        if not (InCombatLockdown and InCombatLockdown()) then
            frame:EnableMouse(true)
        end
    else
        CapriActionHideFrame.buttons[frame] = nil
    end

    if frame.SetFrameStrata then
        frame:SetFrameStrata(capriBarStrata)
    end

    if frame.SetScale then
        frame:SetScale(scale)
    end

    if frame.ClearAllPoints then
        frame:ClearAllPoints()
    end

    if frame.SetPoint then
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
    end

    local frameName = frame.GetName and frame:GetName()
    local hotkey = frameName and _G[frameName .. "HotKey"]

    if hotkey then
        local cmd = GetBindCommand(frameName)
        if cmd then
            local keyText = GetBindingKey(cmd)
            if keyText and keyText ~= "" then
                hotkey:SetText(FormatKeyText(keyText))
                hotkey:Show()
            else
                hotkey:Hide()
            end
        else
            hotkey:Hide()
        end
    end

    SetButtonShape(frame, isCircular)
end

local function ForceExtraBarsVisible()
    if not BarEnabled() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local prefixes = {
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
    }

    for i = 1, 12 do
        for _, prefix in ipairs(prefixes) do
            local btn = _G[prefix .. i]
            if btn then
                btn:SetAlpha(1)
                btn:EnableMouse(true)
            end
        end
    end
end


local capriLastIcons = {}
local capriGhostPool = {}
local capriAnim = nil
local capriAnimDriver = CreateFrame("Frame")
capriAnimDriver:Hide()

local function CapriGetGhost(i)
    local g = capriGhostPool[i]

    if not g then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetFrameStrata("DIALOG")
        g:SetWidth(36)
        g:SetHeight(36)

        g.icon = g:CreateTexture(nil, "ARTWORK")
        g.icon:SetAllPoints()

        g.border = g:CreateTexture(nil, "OVERLAY")
        g.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        g.border:SetPoint("CENTER", g, "CENTER", 0, 0)
        g.border:SetWidth(66)
        g.border:SetHeight(66)

        capriGhostPool[i] = g
    end

    return g
end

local capriIconTicker = CreateFrame("Frame")
capriIconTicker.elapsed = 0

capriIconTicker:SetScript("OnUpdate", function(self, el)
    self.elapsed = self.elapsed + el

    if self.elapsed < 0.25 then
        return
    end

    self.elapsed = 0

    if not BarEnabled() then
        return
    end

    CapriUpdateBarStrata()

    if capriAnim then
        return
    end

    local isBonus = BonusActionBarFrame and BonusActionBarFrame:IsShown()

    for i = 1, 12 do
        local prefix = isBonus and "BonusActionButton" or "ActionButton"
        local ic = _G[prefix .. i .. "Icon"]
        if ic then
            capriLastIcons[i] = ic:GetTexture()
        end
    end
end)

capriAnimDriver:SetScript("OnUpdate", function(self, el)
    local A = capriAnim

    if not A then
        self:Hide()
        return
    end

    A.t = A.t + el

    local localDur = 0.45
    local u = A.t / localDur

    if u < 0 then
        u = 0
    end

    if u > 1 then
        u = 1
    end

    local done = (u == 1)

    for _, it in ipairs(A.items) do
        local s = it.s

        if A.curved then
            local e = math.pow(u, 1.5)
            local mid_th = (A.min_th + A.max_th) / 2
            local th1 = mid_th + (A.max_th - mid_th + 0.3) * e
            local th2 = mid_th - (mid_th - A.min_th + 0.3) * e
            local diff

            if it.theta >= mid_th then
                diff = th1 - it.theta
            else
                diff = it.theta - th2
            end

            local fade_width = 0.10
            local btn_alpha = 0

            if diff > fade_width then
                btn_alpha = 1
            elseif diff < -fade_width then
                btn_alpha = 0
            else
                btn_alpha = (diff + fade_width) / (fade_width * 2)
            end

            it.ghost:ClearAllPoints()
            it.ghost:SetPoint(it.p, it.rel, it.rp, it.x, it.y)
            it.ghost:SetAlpha(1 - btn_alpha)

            it.btn:ClearAllPoints()
            it.btn:SetPoint(it.p, it.rel, it.rp, it.x, it.y)
            it.btn:SetAlpha(btn_alpha)

            local distToLine = math.abs(diff)
            local popScale = 1

            if distToLine < 0.15 then
                popScale = 1 + 0.15 * (1 - (distToLine / 0.15))
            end

            it.ghost:SetScale(s * popScale)
            it.btn:SetScale(s * popScale)
        else
            local e = 1 - (1 - u) ^ 3
            local slideDist = 90
            local dir = (it.i % 2 == 0) and 1 or -1

            it.ghost:ClearAllPoints()
            it.ghost:SetPoint(it.p, it.rel, it.rp, it.x, it.y + (dir * slideDist * e) / s)
            it.ghost:SetAlpha(1 - u)
            it.ghost:SetScale(s)

            it.btn:ClearAllPoints()
            it.btn:SetPoint(it.p, it.rel, it.rp, it.x, it.y - (dir * slideDist * (1 - e)) / s)
            it.btn:SetAlpha(u)
            it.btn:SetScale(s)
        end
    end

    if done or A.t > localDur + 0.05 then
        for _, it in ipairs(A.items) do
            it.btn:ClearAllPoints()
            it.btn:SetPoint(it.p, it.rel, it.rp, it.x, it.y)

            if CapriActionHideFrame and CapriActionHideFrame.buttons[it.btn] ~= nil then
                local isBonusActive = (BonusActionBarFrame and BonusActionBarFrame:IsShown()) and 1 or 0
                it.btn:SetAlpha(CapriActionHideFrame.buttons[it.btn] == isBonusActive and 1 or 0)
            else
                it.btn:SetAlpha(1)
            end

            it.btn:SetScale(it.s)
            it.ghost:Hide()
        end

        capriAnim = nil
        self:Hide()
    end
end)

local function CapriStartPageAnim()
    if not BarEnabled() then
        return
    end

    if CaprimedinaUIDB and CaprimedinaUIDB.spinAnim == false then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if capriAnim then
        return
    end

    local curved = GetBarBool("Main", "Curved", true)
    local shape = GetBarValue("Main", "Shape", 2)
    local circular = (shape == 2)

    local items = {}
    local min_th = 9999
    local max_th = -9999
    local isBonus = BonusActionBarFrame and BonusActionBarFrame:IsShown()

    for i = 1, 12 do
        local btn = isBonus and _G["BonusActionButton" .. i] or _G["ActionButton" .. i]

        if btn and btn:IsVisible() then
            local p, rel, rp, x, y = btn:GetPoint(1)

            if p then
                local s = btn:GetScale()
                if not s or s == 0 then
                    s = 1
                end

                local g = CapriGetGhost(i)
                g:ClearAllPoints()
                g:SetPoint(p, rel, rp, x, y)
                g:SetScale(s)
                g.icon:SetTexture(capriLastIcons[i])

                if circular then
                    g.icon:ClearAllPoints()
                    g.icon:SetPoint("CENTER", g, "CENTER", 0, 0)
                    g.icon:SetWidth(36 * 0.80)
                    g.icon:SetHeight(36 * 0.80)
                    g.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    g.border:SetTexture(C.tex and C.tex.ring or "Interface\\AddOns\\CaprimedinaUI\\texturas\\ring")
                    g.border:SetWidth(36 * 1.12)
                    g.border:SetHeight(36 * 1.12)
                else
                    g.icon:ClearAllPoints()
                    g.icon:SetAllPoints()
                    g.icon:SetTexCoord(0, 1, 0, 1)
                    g.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                    g.border:SetWidth(66)
                    g.border:SetHeight(66)
                end

                g:SetAlpha(1)
                g:Show()
                btn:SetAlpha(0)

                local it = {
                    btn = btn,
                    ghost = g,
                    p = p,
                    rel = rel,
                    rp = rp,
                    x = x,
                    y = y,
                    i = i,
                    s = s
                }

                if curved then
                    local vx = x * s
                    local vy = y * s
                    it.rad = math.sqrt(vx * vx + vy * vy)
                    it.theta = math.atan2(vy, vx)

                    if it.theta < min_th then
                        min_th = it.theta
                    end

                    if it.theta > max_th then
                        max_th = it.theta
                    end
                end

                table.insert(items, it)
            end
        end
    end

    if #items == 0 then
        return
    end

    capriAnim = {
        items = items,
        t = 0,
        curved = curved,
        min_th = min_th,
        max_th = max_th,
    }

    capriAnimDriver:Show()
end


local function NormalizeAnchorCenter(anchor)
    if not anchor then
        return
    end

    if anchor.capriCurveCentered then
        return
    end

    local p, rf, rp, ox, oy = anchor:GetPoint(1)

    if not p or not rp then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        p, rf, rp, ox, oy = anchor:GetPoint(1)
    end

    if not p or not rp then
        return
    end

    local W, H = UIParent:GetSize()

    if not W or W <= 0 or not H or H <= 0 then
        return
    end

    local baseX, baseY = 0, 0

    if rp == "CENTER" then
        baseX, baseY = W / 2, H / 2
    elseif rp == "TOPLEFT" then
        baseX, baseY = 0, H
    elseif rp == "TOPRIGHT" then
        baseX, baseY = W, H
    elseif rp == "BOTTOMLEFT" then
        baseX, baseY = 0, 0
    elseif rp == "BOTTOMRIGHT" then
        baseX, baseY = W, 0
    else
        return
    end

    local w, h = anchor:GetWidth(), anchor:GetHeight()

    if not w or w <= 0 then
        w = 40
    end

    if not h or h <= 0 then
        h = 40
    end

    local cx, cy = ox, oy

    if p == "CENTER" then
        cx, cy = ox, oy
    elseif p == "TOPLEFT" then
        cx, cy = ox + w / 2, oy - h / 2
    elseif p == "TOPRIGHT" then
        cx, cy = ox - w / 2, oy - h / 2
    elseif p == "BOTTOMLEFT" then
        cx, cy = ox + w / 2, oy + h / 2
    elseif p == "BOTTOMRIGHT" then
        cx, cy = ox - w / 2, oy + h / 2
    else
        return
    end

    local X = baseX + cx
    local Y = baseY + cy

    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "BOTTOMRIGHT", X - W, Y)
    anchor:SetClampedToScreen(true)
    anchor.capriCurveCentered = true
end


local function LayoutBarGroup(buttons, anchor, barID)
    if not BarEnabled() or not anchor then
        return
    end

    TryHookActionBarVisibility()
    FixSpacedGlobals()

    local isMain = (barID == "Main")

    local scale = tonumber(GetBarValue(barID, "Scale", isMain and 1.80 or 1.0)) or 1.0
    if scale <= 0 then
        scale = 1.0
    end

    local spacing = tonumber(GetBarValue(barID, "Spacing", 42)) or 42
    local cols = math.floor(tonumber(GetBarValue(barID, "Columns", isMain and 6 or 12)) or (isMain and 6 or 12))
    local count = math.floor(tonumber(GetBarValue(barID, "Count", 12)) or 12)

    local invertRaw = GetBarValue(barID, "Invert", 1)
    local invert

    if invertRaw == true then
        invert = 2
    elseif invertRaw == false then
        invert = 1
    else
        invert = tonumber(invertRaw) or 1
    end

    if invert < 1 or invert > 4 then
        invert = 1
    end

    invert = math.floor(invert)

    local shapeRaw = GetBarValue(barID, "Shape", isMain and 2 or 1)
    local shape

    if shapeRaw == true then
        shape = 2
    elseif shapeRaw == false then
        shape = 1
    else
        shape = tonumber(shapeRaw) or (isMain and 2 or 1)
    end

    local curved = GetBarBool(barID, "Curved", isMain and true or false)

    if cols < 1 then
        cols = 1
    end

    if count < 1 then
        count = 1
    end

    if count > 12 then
        count = 12
    end

    if curved then
        NormalizeAnchorCenter(anchor)

        local radius  = tonumber(GetBarValue(barID, "ArcRadius", 420)) or 420
        local radius2 = tonumber(GetBarValue(barID, "ArcRadius2", isMain and 328 or 358)) or 358
        local span    = tonumber(GetBarValue(barID, "ArcSpan", 80)) or 80
        local a1      = tonumber(GetBarValue(barID, "ArcA1", isMain and 97 or 90)) or 90

        local perArc = math.floor(cols)
        if perArc < 1 then
            perArc = 1
        end

        if perArc > 12 then
            perArc = 12
        end

        local gap = radius - radius2
        if gap < 10 then
            gap = 10
        end

        local a0 = a1 + span
        local groups = {}
        local k = 0

        while k * perArc < count do
            table.insert(groups, {
                f = k * perArc + 1,
                l = math.min(count, (k + 1) * perArc),
                k = k,
            })
            k = k + 1
        end

        local total = #groups
        local placements = {}
        local minDX, maxDX, minDY, maxDY = 0, 0, 0, 0
        local firstPt = true

        for _, g in ipairs(groups) do
            local n = g.l - g.f + 1

            if n >= 1 then
                local arcIndex = g.k

                if invert == 2 or invert == 4 then
                    arcIndex = (total - 1) - g.k
                end

                local r = math.max(radius - arcIndex * gap, 80)

                for i = 1, n do
                    local idx = g.f + i - 1

                    if buttons[idx] then
                        local t = (n > 1) and ((i - 1) / (n - 1)) or 0

                        if invert == 3 or invert == 4 then
                            t = 1 - t
                        end

                        local ang = math.rad(a0 + (a1 - a0) * t)
                        local dx = r * math.cos(ang)
                        local dy = r * math.sin(ang)

                        table.insert(placements, { idx = idx, dx = dx, dy = dy })

                        if firstPt then
                            minDX, maxDX, minDY, maxDY = dx, dx, dy, dy
                            firstPt = false
                        else
                            if dx < minDX then
                                minDX = dx
                            end
                            if dx > maxDX then
                                maxDX = dx
                            end
                            if dy < minDY then
                                minDY = dy
                            end
                            if dy > maxDY then
                                maxDY = dy
                            end
                        end
                    end
                end
            end
        end

        local halfBtn = 18 * scale
        local pad = 5

        local visMinX = minDX - halfBtn - pad
        local visMaxX = maxDX + halfBtn + pad
        local visMinY = minDY - halfBtn - pad
        local visMaxY = maxDY + halfBtn + pad

        local bcx = (visMinX + visMaxX) / 2
        local bcy = (visMinY + visMaxY) / 2

        local placed = {}

        for _, pl in ipairs(placements) do
            local bd = buttons[pl.idx]

            if bd then
                placed[pl.idx] = true

                if bd.main then
                    bd.main.capriLayoutHidden = false
                end

                if bd.bonus then
                    bd.bonus.capriLayoutHidden = false
                end

                local px = (pl.dx - bcx) / scale
                local py = (pl.dy - bcy) / scale

                if bd.main then
                    ManageButton(bd.main, anchor, 0, 0, "", nil, scale, shape == 2)
                    bd.main:ClearAllPoints()
                    bd.main:SetPoint("CENTER", anchor, "CENTER", px, py)
                    CapriRefreshActionButton(bd.main)
                end

                if bd.bonus then
                    ManageButton(bd.bonus, anchor, 0, 0, "", true, scale, shape == 2)
                    bd.bonus:ClearAllPoints()
                    bd.bonus:SetPoint("CENTER", anchor, "CENTER", px, py)

                    if bd.main then
                        bd.bonus:SetFrameLevel(bd.main:GetFrameLevel() + 2)
                    end

                    CapriRefreshActionButton(bd.bonus)
                end
            end
        end

        for i = 1, #buttons do
            if not placed[i] then
                local bd = buttons[i]

                if bd then
                    if bd.main then
                        bd.main.capriLayoutHidden = true
                        bd.main:Hide()
                        bd.main:ClearAllPoints()
                    end

                    if bd.bonus then
                        bd.bonus.capriLayoutHidden = true
                        bd.bonus:Hide()
                        bd.bonus:ClearAllPoints()
                    end
                end
            end
        end

        local aw = math.max(40, visMaxX - visMinX)
        local ah = math.max(40, visMaxY - visMinY)

        if anchor.SetWidth then
            anchor:SetWidth(aw)
        end

        if anchor.SetHeight then
            anchor:SetHeight(ah)
        end

        anchor:SetClampedToScreen(true)

        if anchor.Show and not anchor:IsShown() then
            anchor:Show()
        end

        return
    end

    anchor.capriCurveCentered = nil

    local rows = math.ceil(count / cols)
    if rows < 1 then
        rows = 1
    end

    local visualSpacing = spacing * scale
    local visualBtnSize = 36 * scale
    local gridWidth = ((cols - 1) * visualSpacing) + visualBtnSize + 10
    local gridHeight = ((rows - 1) * visualSpacing) + visualBtnSize + 10

    if anchor.SetWidth then
        anchor:SetWidth(math.max(gridWidth, 40))
    end

    if anchor.SetHeight then
        anchor:SetHeight(math.max(gridHeight, 40))
    end

    for i, btnData in ipairs(buttons) do
        if i <= count then
            if btnData.main then
                btnData.main.capriLayoutHidden = false
            end

            if btnData.bonus then
                btnData.bonus.capriLayoutHidden = false
            end

            local col = (i - 1) % cols
            local rowCalc = math.floor((i - 1) / cols)
            local visualRow = rowCalc
            local visualCol = col

            if invert == 2 or invert == 4 then
                visualRow = (rows - 1) - rowCalc
            end

            if invert == 3 or invert == 4 then
                visualCol = (cols - 1) - col
            end

            local visualX = 5 + (visualCol * visualSpacing)
            local visualY = 5 + (visualRow * visualSpacing)

            local pointX = visualX / scale
            local pointY = -visualY / scale

            if btnData.main then
                ManageButton(btnData.main, anchor, pointX, pointY, "", nil, scale, shape == 2)
                CapriRefreshActionButton(btnData.main)
            end

            if btnData.bonus then
                ManageButton(btnData.bonus, anchor, pointX, pointY, "", true, scale, shape == 2)

                if btnData.main then
                    btnData.bonus:SetFrameLevel(btnData.main:GetFrameLevel() + 2)
                end

                CapriRefreshActionButton(btnData.bonus)
            end
        else
            if btnData.main then
                btnData.main.capriLayoutHidden = true
                btnData.main:Hide()
                btnData.main:ClearAllPoints()
            end

            if btnData.bonus then
                btnData.bonus.capriLayoutHidden = true
                btnData.bonus:Hide()
                btnData.bonus:ClearAllPoints()
            end
        end
    end
end


local function CapriUpdateBarLayout()
    if not BarEnabled() then
        return
    end

    FixSpacedGlobals()

    if not _G["CapriDragMain"] then
        return
    end

    TryHookActionBarVisibility()
    ForceExtraBarsVisible()

    for i = 1, 10 do
        local btn = _G["ShapeshiftButton" .. i]
        if btn then
            SetButtonShape(btn, false)
            if btn.SetFrameStrata then
                btn:SetFrameStrata("LOW")
            end
        end
    end

    local mainBtns = {}
    for i = 1, 12 do
        mainBtns[i] = {
            main = _G["ActionButton" .. i],
            bonus = _G["BonusActionButton" .. i],
        }
    end

    LayoutBarGroup(mainBtns, _G["CapriDragMain"], "Main")

    if _G["CapriDragBL"] then
        local blBtns = {}
        for i = 1, 12 do
            blBtns[i] = { main = _G["MultiBarBottomLeftButton" .. i] }
        end
        LayoutBarGroup(blBtns, _G["CapriDragBL"], "BL")
    end

    if _G["CapriDragBR"] then
        local brBtns = {}
        for i = 1, 12 do
            brBtns[i] = { main = _G["MultiBarBottomRightButton" .. i] }
        end
        LayoutBarGroup(brBtns, _G["CapriDragBR"], "BR")
    end

    if _G["CapriDragRight"] then
        local rightBtns = {}
        for i = 1, 12 do
            rightBtns[i] = { main = _G["MultiBarRightButton" .. i] }
        end
        LayoutBarGroup(rightBtns, _G["CapriDragRight"], "Right")
    end

    if _G["CapriDragLeft"] then
        local leftBtns = {}
        for i = 1, 12 do
            leftBtns[i] = { main = _G["MultiBarLeftButton" .. i] }
        end
        LayoutBarGroup(leftBtns, _G["CapriDragLeft"], "Left")
    end

    CapriUpdateBarStrata()
end


local currentMenuKey = nil
local ctxRows = {}
local curveRows = {}

local CapriBarContextMenu = CreateFrame("Frame", "CapriBarContextMenu", UIParent)
CapriBarContextMenu:SetWidth(280)
CapriBarContextMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
CapriBarContextMenu:SetFrameStrata("TOOLTIP")
C.StyleWindow(CapriBarContextMenu)
CapriBarContextMenu:SetMovable(true)
CapriBarContextMenu:EnableMouse(true)
CapriBarContextMenu:RegisterForDrag("LeftButton")
CapriBarContextMenu:SetScript("OnDragStart", function(self) self:StartMoving() end)
CapriBarContextMenu:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
CapriBarContextMenu:Hide()

local ctxTitle = CapriBarContextMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(ctxTitle, 16)
ctxTitle:SetPoint("TOP", 0, -15)

local ctxClose = C.CreateStyledClose(CapriBarContextMenu)
ctxClose:SetScript("OnClick", function()
    CapriBarContextMenu:Hide()
end)

local function ApplyBarChange(dbKey, delta, minVal, maxVal, row)
    local v = (CaprimedinaUIDB[dbKey] or 0) + delta
    if minVal and v < minVal then v = minVal end
    if maxVal and v > maxVal then v = maxVal end
    CaprimedinaUIDB[dbKey] = v
    row:UpdateText(v)
    if CapriUpdateBarLayout then CapriUpdateBarLayout() end
end

local function CreateAdjustRow(parent, labelText, step, minVal, maxVal, onChange)
    local r = CreateFrame("Frame", nil, parent)
    r:SetWidth(240)
    r:SetHeight(25)

    r.label = r:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(r.label, 13)
    r.label:SetPoint("LEFT", 10, 0)
    r.label:SetText(labelText)

    r.val = r:CreateFontString(nil, "OVERLAY")
    C.SetOutlineFont(r.val, 13)
    r.val:SetPoint("RIGHT", -60, 0)

    r.btnMinus = C.CreateStyledButton(r, "-", 22, 22)
    r.btnMinus:SetPoint("RIGHT", -30, 0)

    r.btnPlus = C.CreateStyledButton(r, "+", 22, 22)
    r.btnPlus:SetPoint("RIGHT", -5, 0)

    r.UpdateText = function(self, val)
        self.val:SetText(val == math.floor(val) and tostring(val) or string.format("%.2f", val))
    end

    r.btnMinus:SetScript("OnClick", function() onChange(-step) end)
    r.btnPlus:SetScript("OnClick", function() onChange(step) end)

    return r
end

local mainKeysConfig = {
    { label = "Botones", suffix = "Count", step = 1, min = 1, max = 12 },
    { label = "Escala", suffix = "Scale", step = 0.05, min = 0.5, max = 3.0 },
    { label = "Espacio", suffix = "Spacing", step = 2, min = 0, max = 100 },
    { label = "Columnas", suffix = "Columns", step = 1, min = 1, max = 12 },
}

local curveKeysConfig = {
    { label = "Radio 1", suffix = "ArcRadius", step = 5, min = 50, max = 1000 },
    { label = "Radio 2", suffix = "ArcRadius2", step = 5, min = 50, max = 1000 },
    { label = "Amplitud", suffix = "ArcSpan", step = 5, min = 10, max = 360 },
    { label = "Angulo", suffix = "ArcA1", step = 5, min = -360, max = 360 },
}

local yOffBase = -45
for _, k in ipairs(mainKeysConfig) do
    local r = CreateAdjustRow(CapriBarContextMenu, k.label, k.step, k.min, k.max, function(delta)
        if currentMenuKey then
            ApplyBarChange(currentMenuKey .. k.suffix, delta, k.min, k.max, ctxRows[k.suffix])
        end
    end)
    r:SetPoint("TOP", 0, yOffBase)
    ctxRows[k.suffix] = r
    yOffBase = yOffBase - 30
end

for _, k in ipairs(curveKeysConfig) do
    local r = CreateAdjustRow(CapriBarContextMenu, k.label, k.step, k.min, k.max, function(delta)
        if currentMenuKey then
            ApplyBarChange(currentMenuKey .. k.suffix, delta, k.min, k.max, curveRows[k.suffix])
        end
    end)
    curveRows[k.suffix] = r
    r:Hide()
end

local btnBordes = C.CreateStyledButton(CapriBarContextMenu, "Bordes: OFF", 110, 22)
local btnCurva = C.CreateStyledButton(CapriBarContextMenu, "Curva: OFF", 110, 22)
local btnInvertir = C.CreateStyledButton(CapriBarContextMenu, "Invertir: 1", 240, 22)

local function UpdateMenuLayout(key)
    local isCurved = CaprimedinaUIDB[key .. "Curved"]
    local cyOff = yOffBase
    
    if isCurved then
        for _, k in ipairs(curveKeysConfig) do
            local r = curveRows[k.suffix]
            r:SetPoint("TOP", 0, cyOff)
            r:Show()
            cyOff = cyOff - 30
        end
    else
        for _, k in ipairs(curveKeysConfig) do
            curveRows[k.suffix]:Hide()
        end
    end
    
    btnBordes:SetPoint("TOPLEFT", CapriBarContextMenu, "TOPLEFT", 20, cyOff - 10)
    btnCurva:SetPoint("TOPRIGHT", CapriBarContextMenu, "TOPRIGHT", -20, cyOff - 10)
    btnInvertir:SetPoint("TOP", CapriBarContextMenu, "TOP", 0, cyOff - 40)
    
    CapriBarContextMenu:SetHeight(math.abs(cyOff) + 80)
end

btnBordes:SetScript("OnClick", function(self)
    if currentMenuKey then
        local dbKey = currentMenuKey .. "Shape"
        local v = CaprimedinaUIDB[dbKey]
        CaprimedinaUIDB[dbKey] = (v == 1) and 2 or 1
        self:SetText(CaprimedinaUIDB[dbKey] == 2 and "Bordes: ON" or "Bordes: OFF")
        if CapriUpdateBarLayout then CapriUpdateBarLayout() end
    end
end)

btnCurva:SetScript("OnClick", function(self)
    if currentMenuKey then
        local dbKey = currentMenuKey .. "Curved"
        CaprimedinaUIDB[dbKey] = not CaprimedinaUIDB[dbKey]
        self:SetText(CaprimedinaUIDB[dbKey] and "Curva: ON" or "Curva: OFF")
        UpdateMenuLayout(currentMenuKey)
        if CapriUpdateBarLayout then CapriUpdateBarLayout() end
    end
end)

btnInvertir:SetScript("OnClick", function(self)
    if currentMenuKey then
        local dbKey = currentMenuKey .. "Invert"
        local v = tonumber(CaprimedinaUIDB[dbKey]) or 1
        v = v + 1
        if v > 4 then v = 1 end
        CaprimedinaUIDB[dbKey] = v
        self:SetText("Invertir: " .. v)
        if CapriUpdateBarLayout then CapriUpdateBarLayout() end
    end
end)

local barTitles = {
    Main = "BARRA PRINCIPAL",
    BL = "BARRA INF. IZQ.",
    BR = "BARRA INF. DER.",
    Right = "BARRA DERECHA",
    Left = "BARRA IZQUIERDA"
}

local function ShowBarContextMenu(key)
    currentMenuKey = key
    ctxTitle:SetText(barTitles[key] or "BARRA")

    for _, k in ipairs(mainKeysConfig) do
        ctxRows[k.suffix]:UpdateText(CaprimedinaUIDB[key .. k.suffix] or 0)
    end
    for _, k in ipairs(curveKeysConfig) do
        curveRows[k.suffix]:UpdateText(CaprimedinaUIDB[key .. k.suffix] or 0)
    end

    btnBordes:SetText(CaprimedinaUIDB[key .. "Shape"] == 2 and "Bordes: ON" or "Bordes: OFF")
    btnCurva:SetText(CaprimedinaUIDB[key .. "Curved"] and "Curva: ON" or "Curva: OFF")
    
    local inv = CaprimedinaUIDB[key .. "Invert"] or 1
    if inv == true then inv = 2 elseif inv == false then inv = 1 end
    btnInvertir:SetText("Invertir: " .. math.floor(tonumber(inv) or 1))

    UpdateMenuLayout(key)
    CapriBarContextMenu:Show()
end

local function CapriOverrideBarDragMenus()
    local drags = {
        Main = _G["CapriDragMain"],
        BL = _G["CapriDragBL"],
        BR = _G["CapriDragBR"],
        Right = _G["CapriDragRight"],
        Left = _G["CapriDragLeft"]
    }
    for key, frame in pairs(drags) do
        if frame then
            frame:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and _G["CapriMasterEditControl"] and _G["CapriMasterEditControl"]:IsVisible() then
                    ShowBarContextMenu(key)
                end
            end)
        end
    end
end


local overlaysCreated = false
local capriOverlayNames = {}

local function MakeBindOverlay(btnName)
    local btn = _G[btnName]

    if not btn or capriOverlayNames[btnName] then
        return
    end

    capriOverlayNames[btnName] = true

    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:EnableMouse(true)
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    overlay:SetWidth(36)
    overlay:SetHeight(36)

    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    bg:SetVertexColor(0, 0, 0, 0.6)
    bg:SetAllPoints(overlay)

    local tex = overlay:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(0, 1, 0, 0.6)
    tex:SetWidth(66)
    tex:SetHeight(66)
    tex:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    overlay.tex = tex

    local glow = overlay:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 1, 0, 1)
    glow:SetWidth(66)
    glow:SetHeight(66)
    glow:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    glow:Hide()
    overlay.glow = glow

    overlay.targetBtn = btn

    overlay:SetScript("OnClick", function(self)
        for _, o in ipairs(capriBindOverlays) do
            if o.glow then
                o.glow:Hide()
            end
            if o.tex then
                o.tex:Show()
            end
        end

        capriBindSelected = self.targetBtn
        self.glow:Show()
        self.tex:Hide()

        bindSub:SetText("Boton seleccionado.\nPresiona una tecla (ESC para cancelar, BORRAR para limpiar).")
    end)

    overlay:SetScript("OnEnter", function(self)
        if capriBindSelected ~= self.targetBtn then
            self.tex:SetVertexColor(0, 1, 0, 1)
        end
    end)

    overlay:SetScript("OnLeave", function(self)
        if capriBindSelected ~= self.targetBtn then
            self.tex:SetVertexColor(0, 1, 0, 0.6)
        end
    end)

    overlay:Hide()
    table.insert(capriBindOverlays, overlay)
end

local function CreateBindOverlays()
    if overlaysCreated then
        return
    end

    overlaysCreated = true

    local allButtons = {}

    for i = 1, 12 do
        table.insert(allButtons, "ActionButton" .. i)
        table.insert(allButtons, "MultiBarBottomLeftButton" .. i)
        table.insert(allButtons, "MultiBarBottomRightButton" .. i)
        table.insert(allButtons, "MultiBarRightButton" .. i)
        table.insert(allButtons, "MultiBarLeftButton" .. i)
        table.insert(allButtons, "BonusActionButton" .. i)
    end

    for i = 1, 10 do
        table.insert(allButtons, "ShapeshiftButton" .. i)
        table.insert(allButtons, "PetActionButton" .. i)
    end

    for name, _ in pairs(CapriCustomBindButtons) do
        table.insert(allButtons, name)
    end

    for _, btnName in ipairs(allButtons) do
        MakeBindOverlay(btnName)
    end
end

function CapriRegisterBindButton(btn, bindCmd)
    if not btn or not btn.GetName then
        return
    end

    local name = btn:GetName()
    if not name then
        return
    end

    CapriCustomBindButtons[name] = bindCmd or ("CLICK " .. name .. ":LeftButton")

    if overlaysCreated then
        MakeBindOverlay(name)
    end
end

function CapriRefreshCustomHotkeys()
    for name, cmd in pairs(CapriCustomBindButtons) do
        local hk = _G[name .. "HotKey"]

        if hk then
            local keyText = GetBindingKey(cmd)

            if keyText and keyText ~= "" then
                hk:SetText(FormatKeyText(keyText))
                hk:Show()
            else
                hk:SetText("")
                hk:Hide()
            end
        end
    end
end


local barLayoutHooked = false

local function HookBarLayout()
    if barLayoutHooked then
        return
    end

    if type(UIParent_ManageFramePositions) ~= "function" then
        return
    end

    barLayoutHooked = true

    hooksecurefunc("UIParent_ManageFramePositions", function()
        if not BarEnabled() then
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            return
        end

        TryHookActionBarVisibility()
        CapriUpdateBarLayout()
    end)
end


local function MigrateArcRedesign()
    if type(CaprimedinaUIDB) ~= "table" then
        return
    end

    local db = CaprimedinaUIDB
    db.uiRedesign = 1

    -- Solo tocamos la configuracion si sigue con los valores antiguos.
    if db.MainScale == 1.25
        and db.MainArcRadius == 350
        and db.MainArcRadius2 == 283
        and db.MainArcSpan == 85
        and db.MainArcA1 == 102
        and db.MainX == -50
        and db.MainY == 50 then
        db.MainScale = 1.45
        db.MainArcRadius = 425
        db.MainArcRadius2 = 330
        db.MainArcSpan = 90
        db.MainArcA1 = 90
        db.MainX = -240
        db.MainY = 195
    end

    -- Segundo ajuste: aleja el arco del borde derecho.
    if db.MainScale == 1.38
        and db.MainArcRadius == 405
        and db.MainArcRadius2 == 310
        and db.MainArcSpan == 90
        and db.MainArcA1 == 90
        and db.MainX == -170
        and db.MainY == 195 then
        db.MainScale = 1.45
        db.MainArcRadius = 425
        db.MainArcRadius2 = 330
        db.MainX = -240
    end
end

local function EnsureBarDefaults()
    MigrateSpacedDB()
    MigrateArcRedesign()

    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    local bars = { "Main", "BL", "BR", "Right", "Left" }

    for _, id in ipairs(bars) do
        local isMain = (id == "Main")

        if CaprimedinaUIDB[id .. "Scale"] == nil then
            CaprimedinaUIDB[id .. "Scale"] = isMain and 2.50 or 1.0
        end

        if CaprimedinaUIDB[id .. "Spacing"] == nil then
            CaprimedinaUIDB[id .. "Spacing"] = 42
        end

        if CaprimedinaUIDB[id .. "Columns"] == nil then
            CaprimedinaUIDB[id .. "Columns"] = isMain and 6 or 12
        end

        if CaprimedinaUIDB[id .. "Count"] == nil then
            CaprimedinaUIDB[id .. "Count"] = 12
        end

        if CaprimedinaUIDB[id .. "Shape"] == nil then
            CaprimedinaUIDB[id .. "Shape"] = isMain and 2 or 1
        end

        if CaprimedinaUIDB[id .. "Invert"] == nil then
            CaprimedinaUIDB[id .. "Invert"] = 1
        end

        if CaprimedinaUIDB[id .. "Curved"] == nil then
            CaprimedinaUIDB[id .. "Curved"] = isMain and true or false
        end

        if CaprimedinaUIDB[id .. "ArcRadius"] == nil then
            CaprimedinaUIDB[id .. "ArcRadius"] = isMain and 425 or 420
        end

        if CaprimedinaUIDB[id .. "ArcRadius2"] == nil then
            CaprimedinaUIDB[id .. "ArcRadius2"] = isMain and 330 or 358
        end

        if CaprimedinaUIDB[id .. "ArcSpan"] == nil then
            CaprimedinaUIDB[id .. "ArcSpan"] = isMain and 90 or 80
        end

        if CaprimedinaUIDB[id .. "ArcA1"] == nil then
            CaprimedinaUIDB[id .. "ArcA1"] = isMain and 90 or 90
        end
    end

    if CaprimedinaUIDB.MainPoint == nil then
        CaprimedinaUIDB.MainPoint = "BOTTOMRIGHT"
    end

    if CaprimedinaUIDB.MainRelPoint == nil then
        CaprimedinaUIDB.MainRelPoint = "BOTTOMRIGHT"
    end

    if CaprimedinaUIDB.MainX == nil then
        CaprimedinaUIDB.MainX = -120
    end

    if CaprimedinaUIDB.MainY == nil then
        CaprimedinaUIDB.MainY = 80
    end

    -- Migracion: valores antiguos -> nuevos por defecto (primer inicio).
    if (CaprimedinaUIDB.MainScale == 1.45 or CaprimedinaUIDB.MainScale == 2.50)
        and (CaprimedinaUIDB.MainX == -240 or CaprimedinaUIDB.MainX == -180)
        and (CaprimedinaUIDB.MainY == 195 or CaprimedinaUIDB.MainY == 120) then
        CaprimedinaUIDB.MainScale = 2.50
        CaprimedinaUIDB.MainX = -120
        CaprimedinaUIDB.MainY = 80
    end

    -- Posicion en fraccion de pantalla (0..1 desde arriba); se recalcula al cargar.
    if CaprimedinaUIDB.MainCx == nil then
        CaprimedinaUIDB.MainCx = 0.84
    end

    if CaprimedinaUIDB.MainCy == nil then
        CaprimedinaUIDB.MainCy = 0.60
    end

    -- Migracion: bajar el arco de acciones respecto a la version anterior.
    if CaprimedinaUIDB.MainCx == 0.84 and CaprimedinaUIDB.MainCy == 0.52 then
        CaprimedinaUIDB.MainCy = 0.60
    end

    FixSpacedGlobals()
end


local CapriBarsInit = CreateFrame("Frame")
CapriBarsInit:RegisterEvent("VARIABLES_LOADED")
CapriBarsInit:RegisterEvent("PLAYER_ENTERING_WORLD")

local barsSetupDone = false

CapriBarsInit:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        EnsureBarDefaults()
        FixSpacedGlobals()

        if _G["CapriDragMain"] and not _G["CapriDragMain"]:IsUserPlaced() then
            local db = CaprimedinaUIDB
            local mw, mh = UIParent:GetWidth(), UIParent:GetHeight()

            if db.MainCx and db.MainCy and mw and mh and mw > 0 and mh > 0 then
                db.MainPoint, db.MainRelPoint = "CENTER", "CENTER"
                db.MainX = (db.MainCx - 0.5) * mw
                db.MainY = (0.5 - db.MainCy) * mh
                db.dragMainPoint, db.dragMainRelPoint = "CENTER", "CENTER"
                db.dragMainX, db.dragMainY = db.MainX, db.MainY
            end

            _G["CapriDragMain"]:ClearAllPoints()
            _G["CapriDragMain"]:SetPoint(
                CaprimedinaUIDB.MainPoint or "BOTTOMRIGHT",
                UIParent,
                CaprimedinaUIDB.MainRelPoint or "BOTTOMRIGHT",
                CaprimedinaUIDB.MainX or -50,
                CaprimedinaUIDB.MainY or 50
            )
            _G["CapriDragMain"].capriCurveCentered = nil
        end
        
        CapriOverrideBarDragMenus()

        if not BarEnabled() then
            return
        end

        if barsSetupDone then
            return
        end

        barsSetupDone = true

        CreateBindOverlays()
        HookBarLayout()
        TryHookActionBarVisibility()

        if type(UIParent_ManageFramePositions) == "function" then
            UIParent_ManageFramePositions()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        FixSpacedGlobals()
        CapriOverrideBarDragMenus()

        if not barsSetupDone then
            if not BarEnabled() then
                return
            end

            barsSetupDone = true
            CreateBindOverlays()
            HookBarLayout()
            TryHookActionBarVisibility()
        end

        if not BarEnabled() then
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            return
        end

        HookBarLayout()
        TryHookActionBarVisibility()

        if type(UIParent_ManageFramePositions) == "function" then
            UIParent_ManageFramePositions()
        else
            CapriUpdateBarLayout()
        end
    end
end)


local CapriBarLateInitDelay = CreateFrame("Frame")
CapriBarLateInitDelay:Hide()
CapriBarLateInitDelay.elapsed = 0

CapriBarLateInitDelay:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed

    if self.elapsed > 0.75 then
        if InCombatLockdown and InCombatLockdown() then
            self.elapsed = 0
            return
        end

        if BarEnabled() then
            HookBarLayout()
            TryHookActionBarVisibility()
            CapriUpdateBarLayout()
        end

        self:Hide()
    end
end)

local CapriBarLateInit = CreateFrame("Frame")
CapriBarLateInit:RegisterEvent("PLAYER_LOGIN")
CapriBarLateInit:RegisterEvent("PLAYER_ENTERING_WORLD")

CapriBarLateInit:SetScript("OnEvent", function()
    if not BarEnabled() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    CapriBarLateInitDelay.elapsed = 0
    CapriBarLateInitDelay:Show()
end)


local questAnchor = CreateFrame("Frame", "CapriQuestAnchor", UIParent)
questAnchor:SetWidth(230)
questAnchor:SetHeight(400)
questAnchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -250)
questAnchor:SetFrameStrata("BACKGROUND")
questAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
questAnchor:SetBackdropColor(0, 1, 0, 0)
questAnchor:SetBackdropBorderColor(0, 1, 0, 0)
questAnchor:SetMovable(true)
questAnchor:EnableMouse(false)
questAnchor:RegisterForDrag("LeftButton")
questAnchor:SetClampedToScreen(true)

questAnchor.text = questAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
questAnchor.text:SetPoint("CENTER", questAnchor, "CENTER", 0, 0)
questAnchor.text:SetText("MISIONES\n(Click Der)")
questAnchor.text:Hide()

local questDragging = false

local function FixQuestTracker()
    if not (WatchFrame and questAnchor) then
        return
    end

    if type(CaprimedinaUIDB) ~= "table" then
        return
    end

    if not BarEnabled() then
        return
    end

    local qHeight = CaprimedinaUIDB.questHeight or 600
    local qScale = CaprimedinaUIDB.questScale or 1.0

    WatchFrame:ClearAllPoints()
    WatchFrame:SetPoint("TOPRIGHT", questAnchor, "TOPRIGHT", 0, 0)
    WatchFrame:SetHeight(qHeight)
    WatchFrame:SetScale(qScale)

    questAnchor:SetHeight(qHeight)
    questAnchor:SetScale(qScale)
end

local function ClampQuestAnchorToScreen()
    if not questAnchor then
        return
    end

    questAnchor:SetClampedToScreen(true)

    local uiScale = UIParent:GetEffectiveScale() or 1
    if uiScale == 0 then
        uiScale = 1
    end

    local screenW, screenH

    if GetScreenWidth and GetScreenHeight then
        screenW, screenH = GetScreenWidth(), GetScreenHeight()
    else
        screenW = UIParent:GetWidth() * uiScale
        screenH = UIParent:GetHeight() * uiScale
    end

    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        return
    end

    local effScale = questAnchor:GetEffectiveScale() or uiScale
    if effScale == 0 then
        effScale = uiScale
    end

    local w = (questAnchor:GetWidth() or 0) * effScale
    local h = (questAnchor:GetHeight() or 0) * effScale

    local left = questAnchor:GetLeft()
    local bottom = questAnchor:GetBottom()

    if not left then
        left = 0
    end

    if not bottom then
        local top = questAnchor:GetTop() or screenH
        bottom = top - h
    end

    local newLeft = left
    local newBottom = bottom

    if w > screenW then
        newLeft = (screenW - w) / 2
    else
        if newLeft < 0 then
            newLeft = 0
        end
        if newLeft + w > screenW then
            newLeft = screenW - w
        end
    end

    if h > screenH then
        newBottom = (screenH - h) / 2
    else
        if newBottom < 0 then
            newBottom = 0
        end
        if newBottom + h > screenH then
            newBottom = screenH - h
        end
    end

    if math.abs(newLeft - left) > 0.5 or math.abs(newBottom - bottom) > 0.5 then
        local newTop = newBottom + h

        questAnchor:ClearAllPoints()
        questAnchor:SetPoint(
            "TOPLEFT",
            UIParent,
            "TOPLEFT",
            newLeft / uiScale,
            (newTop - screenH) / uiScale
        )

        if type(CaprimedinaUIDB) == "table" then
            CaprimedinaUIDB.questPoint = "TOPLEFT"
            CaprimedinaUIDB.questRelPoint = "TOPLEFT"
            CaprimedinaUIDB.questX = newLeft / uiScale
            CaprimedinaUIDB.questY = (newTop - screenH) / uiScale
        end
    end
end

local questMenu = CreateFrame("Frame", "CapriQuestMenu", UIParent)
questMenu:SetFrameStrata("TOOLTIP")
questMenu:SetWidth(300)
questMenu:SetHeight(120)
questMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
C.StyleWindow(questMenu)
questMenu:SetMovable(true)
questMenu:EnableMouse(true)
questMenu:RegisterForDrag("LeftButton")
questMenu:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
questMenu:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
questMenu:Hide()

local qmTitle = questMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(qmTitle, 16)
qmTitle:SetPoint("TOP", questMenu, "TOP", 0, -15)
qmTitle:SetText("AJUSTES DE MISIONES")
qmTitle:SetTextColor(1, 1, 1)

local qmClose = C.CreateStyledClose(questMenu)

local qmScaleVal = questMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(qmScaleVal, 14)

local qmHeightVal = questMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(qmHeightVal, 14)

local function QuestMenuUpdate()
    if type(CaprimedinaUIDB) ~= "table" then
        return
    end

    qmScaleVal:SetText(string.format("%.2f", CaprimedinaUIDB.questScale or 1.0))
    qmHeightVal:SetText(tostring(CaprimedinaUIDB.questHeight or 600))
end

local function QuestAdjust(key, delta, min, max)
    if type(CaprimedinaUIDB) ~= "table" then
        return
    end

    local v = (CaprimedinaUIDB[key] or 0) + delta

    if v < min then
        v = min
    end

    if v > max then
        v = max
    end

    CaprimedinaUIDB[key] = v

    FixQuestTracker()
    ClampQuestAnchorToScreen()
    QuestMenuUpdate()
end

local qLabel1 = questMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(qLabel1, 14)
qLabel1:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 20, -45)
qLabel1:SetText("Escala:")
qLabel1:SetTextColor(1, 1, 1)

qmScaleVal:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 95, -45)

local qmScaleMinus = C.CreateStyledButton(questMenu, "-", 26, 22)
qmScaleMinus:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 150, -40)
qmScaleMinus:SetScript("OnClick", function()
    QuestAdjust("questScale", -0.05, 0.5, 2.0)
end)

local qmScalePlus = C.CreateStyledButton(questMenu, "+", 26, 22)
qmScalePlus:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 185, -40)
qmScalePlus:SetScript("OnClick", function()
    QuestAdjust("questScale", 0.05, 0.5, 2.0)
end)

local qLabel2 = questMenu:CreateFontString(nil, "OVERLAY")
C.SetOutlineFont(qLabel2, 14)
qLabel2:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 20, -75)
qLabel2:SetText("Altura:")
qLabel2:SetTextColor(1, 1, 1)

qmHeightVal:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 95, -75)

local qmHeightMinus = C.CreateStyledButton(questMenu, "-", 26, 22)
qmHeightMinus:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 150, -70)
qmHeightMinus:SetScript("OnClick", function()
    QuestAdjust("questHeight", -50, 200, 1500)
end)

local qmHeightPlus = C.CreateStyledButton(questMenu, "+", 26, 22)
qmHeightPlus:SetPoint("TOPLEFT", questMenu, "TOPLEFT", 185, -70)
qmHeightPlus:SetScript("OnClick", function()
    QuestAdjust("questHeight", 50, 200, 1500)
end)

questAnchor:SetScript("OnDragStart", function(self)
    questDragging = true
    self:StartMoving()
end)

questAnchor:SetScript("OnDragStop", function(self)
    questDragging = false
    self:StopMovingOrSizing()
    ClampQuestAnchorToScreen()

    if type(CaprimedinaUIDB) == "table" then
        local point, _, relPoint, x, y = self:GetPoint(1)
        CaprimedinaUIDB.questPoint = point
        CaprimedinaUIDB.questRelPoint = relPoint
        CaprimedinaUIDB.questX = x
        CaprimedinaUIDB.questY = y
    end

    FixQuestTracker()
end)

questAnchor:SetScript("OnUpdate", function(self)
    if questDragging then
        FixQuestTracker()
    end
end)

questAnchor:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and _G["CapriMasterEditControl"] and _G["CapriMasterEditControl"]:IsVisible() then
        QuestMenuUpdate()
        questMenu:Show()
    end
end)


local origCapriEdit = SlashCmdList["CAPRIEDIT"]

SlashCmdList["CAPRIEDIT"] = function(msg)
    if origCapriEdit then
        origCapriEdit(msg)
    end

    FixSpacedGlobals()

    if not BarEnabled() then
        questAnchor:EnableMouse(false)
        questAnchor:SetBackdropColor(0, 1, 0, 0)
        questAnchor:SetBackdropBorderColor(0, 1, 0, 0)
        questAnchor:SetFrameStrata("BACKGROUND")

        if questAnchor.text then
            questAnchor.text:Hide()
        end

        questMenu:Hide()
        return
    end

    local editing = _G["CapriMasterEditControl"] and _G["CapriMasterEditControl"]:IsVisible()

    questAnchor:EnableMouse(editing)

    local alpha = editing and 0.6 or 0
    questAnchor:SetBackdropColor(0, 1, 0, alpha)
    questAnchor:SetBackdropBorderColor(0, 1, 0, alpha)

    if editing then
        questAnchor:SetFrameStrata("DIALOG")
        if questAnchor.text then
            questAnchor.text:Show()
        end
    else
        questAnchor:SetFrameStrata("BACKGROUND")
        if questAnchor.text then
            questAnchor.text:Hide()
        end
        questMenu:Hide()
        
        
        if CapriBarContextMenu then CapriBarContextMenu:Hide() end
    end
end


local questInit = CreateFrame("Frame")
questInit:RegisterEvent("VARIABLES_LOADED")
questInit:RegisterEvent("PLAYER_ENTERING_WORLD")

questInit:SetScript("OnEvent", function(self, event)
    if type(CaprimedinaUIDB) ~= "table" then
        CaprimedinaUIDB = {}
    end

    if CaprimedinaUIDB.questScale == nil or CaprimedinaUIDB.questScale <= 0 then
        CaprimedinaUIDB.questScale = 1.0
    end

    if CaprimedinaUIDB.questHeight == nil or CaprimedinaUIDB.questHeight < 200 then
        CaprimedinaUIDB.questHeight = 600
    end

    if not BarEnabled() then
        questAnchor:EnableMouse(false)
        questAnchor:SetBackdropColor(0, 1, 0, 0)
        questAnchor:SetBackdropBorderColor(0, 1, 0, 0)
        questAnchor:SetFrameStrata("BACKGROUND")

        if questAnchor.text then
            questAnchor.text:Hide()
        end

        questMenu:Hide()
        return
    end

    if event == "VARIABLES_LOADED" then
        if CaprimedinaUIDB.questPoint then
            questAnchor:ClearAllPoints()
            questAnchor:SetPoint(
                CaprimedinaUIDB.questPoint,
                UIParent,
                CaprimedinaUIDB.questRelPoint or CaprimedinaUIDB.questPoint,
                CaprimedinaUIDB.questX or -50,
                CaprimedinaUIDB.questY or -250
            )
        end
    end

    FixQuestTracker()
    ClampQuestAnchorToScreen()
end)


local CapriActionBarVisibilityInit = CreateFrame("Frame")
CapriActionBarVisibilityInit:RegisterEvent("PLAYER_LOGIN")
CapriActionBarVisibilityInit:RegisterEvent("PLAYER_ENTERING_WORLD")
CapriActionBarVisibilityInit:RegisterEvent("PLAYER_REGEN_ENABLED")
CapriActionBarVisibilityInit:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
CapriActionBarVisibilityInit:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
CapriActionBarVisibilityInit:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")

CapriActionBarVisibilityInit:SetScript("OnEvent", function(self, event)
    if not BarEnabled() then
        return
    end

    if event == "PLAYER_LOGIN" and type(CapriRefreshCustomHotkeys) == "function" then
        CapriRefreshCustomHotkeys()
    end

    if event == "ACTIONBAR_PAGE_CHANGED" then
        CapriStartPageAnim()
    end

    HookBarLayout()
    TryHookActionBarVisibility()
    CapriUpdateAllManagedButtons()
end)


local CapriAlwaysShowWatcher = CreateFrame("Frame")
CapriAlwaysShowWatcher.elapsed = 0
CapriAlwaysShowWatcher.pending = false
CapriAlwaysShowWatcher.lastAlways = CapriAlwaysShowBars() and 1 or 0

CapriAlwaysShowWatcher:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed

    if self.elapsed >= 1 then
        self.elapsed = 0

        if not BarEnabled() then
            self.lastAlways = CapriAlwaysShowBars() and 1 or 0
            self.pending = false
            return
        end

        HookBarLayout()
        TryHookActionBarVisibility()

        local current = CapriAlwaysShowBars() and 1 or 0

        if current ~= self.lastAlways then
            self.pending = true
        end

        if self.pending and not (InCombatLockdown and InCombatLockdown()) then
            self.lastAlways = current
            self.pending = false
            CapriUpdateAllManagedButtons()
        end
    end
end)

if type(UIParent_ManageFramePositions) == "function" then
    hooksecurefunc("UIParent_ManageFramePositions", function()
        FixQuestTracker()
    end)
end


SLASH_CAPRIBARRA1 = "/capribarra"

SlashCmdList["CAPRIBARRA"] = function(msg)
    msg = (msg or ""):lower()

    if msg == "reset" then
        MigrateSpacedDB()

        if type(CaprimedinaUIDB) ~= "table" then
            CaprimedinaUIDB = {}
        end

        CaprimedinaUIDB.MainCurved = true
        CaprimedinaUIDB.MainCount = 12
        CaprimedinaUIDB.MainColumns = 6
        CaprimedinaUIDB.MainScale = 2.50
        CaprimedinaUIDB.MainArcRadius = 425
        CaprimedinaUIDB.MainArcRadius2 = 330
        CaprimedinaUIDB.MainArcSpan = 90
        CaprimedinaUIDB.MainArcA1 = 90
        CaprimedinaUIDB.MainShape = 2

        CaprimedinaUIDB.MainPoint = "BOTTOMRIGHT"
        CaprimedinaUIDB.MainRelPoint = "BOTTOMRIGHT"
        CaprimedinaUIDB.MainX = -120
        CaprimedinaUIDB.MainY = 80

        FixSpacedGlobals()

        if _G["CapriDragMain"] then
            _G["CapriDragMain"]:ClearAllPoints()
            _G["CapriDragMain"]:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -120, 80)
            _G["CapriDragMain"].capriCurveCentered = nil
            pcall(_G["CapriDragMain"].SetUserPlaced, _G["CapriDragMain"], false)
        end

        CapriUpdateBarLayout()

        C.Print("Barra principal restablecida a los valores por defecto.")
    end
end

-- Brillo blanco en los botones de la barra de accion al pulsarlos (raton o tecla).
do
    local _agTimer = 0
    local _agButtons = {
        "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton",
    }
    local f = CreateFrame("Frame", "CapriActionBarWhiteGlow", UIParent)
    f:SetScript("OnUpdate", function(self, elapsed)
        if not BarEnabled() then return end
        _agTimer = _agTimer + elapsed
        -- Limitar a ~30 fps para no saturar.
        if _agTimer < 0.033 then return end
        local dt = _agTimer
        _agTimer = 0
        for _, prefix in ipairs(_agButtons) do
            for i = 1, 12 do
                local btn = _G[prefix .. i]
                if btn then
                    CapriSyncActionPressGlow(btn, dt)
                end
            end
        end
    end)
end