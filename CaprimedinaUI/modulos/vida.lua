local addonName, C = ...
local _G = _G or getfenv(0)

local function IsPlayerOrTargetBar(bar)
    return bar == _G.PlayerFrameHealthBar or bar == _G.PlayerFrameManaBar or
           bar == _G.TargetFrameHealthBar or bar == _G.TargetFrameManaBar
end

local function VidaEnabled()
    return type(CaprimedinaUIDB) ~= "table" or CaprimedinaUIDB.enableVida ~= false
end

hooksecurefunc("TextStatusBar_UpdateTextString", function(bar)
    if not bar or not VidaEnabled() then return end
    if not UnitAffectingCombat("player") then return end
    if not IsPlayerOrTargetBar(bar) then return end

    local value = bar:GetValue()
    local _, valueMax = bar:GetMinMaxValues()

    if valueMax and valueMax > 0 then
        local p = (value / valueMax) * 100
        local text = bar.TextString or _G[bar:GetName() .. "Text"]
        if text then
            text:SetText(math.floor(p) .. "%")
            text:Show()
        end
    end
end)

local frame = CreateFrame("Frame", "CapriVidaFrame", UIParent)
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function()
    if VidaEnabled() then
        TextStatusBar_UpdateTextString(_G.PlayerFrameHealthBar)
        TextStatusBar_UpdateTextString(_G.PlayerFrameManaBar)
        if UnitExists("target") then
            TextStatusBar_UpdateTextString(_G.TargetFrameHealthBar)
            TextStatusBar_UpdateTextString(_G.TargetFrameManaBar)
        end
    end
end)