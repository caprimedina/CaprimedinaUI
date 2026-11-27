#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Prueba de humo de la piel del banco de bag.lua sin el cliente de WoW.

Ejecuta bag.lua con un stub minimo del API (frames, texturas, eventos) y
dispara VARIABLES_LOADED + BANKFRAME_OPENED para comprobar que el banco se
organiza y que el arte se recompone en distintos tamanos y escalas.

Uso:
    python herramientas/probar_piel_banco.py
"""

from __future__ import annotations

import os
import sys

import lupa

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAG_LUA = os.path.join(RAIZ, "CaprimedinaUI", "modulos", "bag.lua").replace("\\", "/")

STUB = r"""
-- =====================================================================
-- Stub minimo de WoW 3.3.5 para ejecutar bag.lua fuera del cliente
-- =====================================================================
local noop = function() end

local function nuevaRegion(tipo, nombre, padre)
    local r = {
        _tipo = tipo, _nombre = nombre, _padre = padre,
        _ancho = 0, _alto = 0, _visible = true, _texto = nil, _textura = nil,
    }
    local mt = {}
    mt.__index = function(t, k)
        local v = rawget(t, k)
        if v ~= nil then return v end
        -- Solo los metodos del API empiezan con mayuscula; los campos de datos
        -- (capriIcon, isEnhanced, text...) tienen que devolver nil.
        if type(k) == "string" and k:match("^%u") then return noop end
        return nil
    end
    setmetatable(r, mt)
    r.SetTexture = function(self, tex) self._textura = tex end
    r.GetTexture = function(self) return self._textura end
    r.SetText = function(self, txt) self._texto = txt end
    r.GetText = function(self) return self._texto end
    r.SetWidth = function(self, w) self._ancho = w end
    r.SetHeight = function(self, h) self._alto = h end
    r.SetSize = function(self, w, h) self._ancho, self._alto = w, h end
    r.GetWidth = function(self) return self._ancho end
    r.GetHeight = function(self) return self._alto end
    r.Show = function(self) self._visible = true end
    r.Hide = function(self) self._visible = false end
    r.IsVisible = function(self) return self._visible end
    r.IsShown = function(self) return self._visible end
    r.GetName = function(self) return self._nombre end
    r.GetObjectType = function(self) return self._tipo end
    return r
end

local frames = {}
_G.__frames = frames

function CreateFrame(tipo, nombre, padre, plantilla)
    local f = {
        _tipo = tipo or "Frame", _nombre = nombre, _padre = padre,
        _ancho = 100, _alto = 100, _escala = 1, _nivel = 1,
        _estrato = "MEDIUM", _visible = false, _alpha = 1,
        _scripts = {}, _eventos = {}, _hijos = {}, _regiones = {},
        _puntos = {}, _backdrop = nil, _normal = nil,
    }
    local mt = {}
    mt.__index = function(t, k)
        local v = rawget(t, k)
        if v ~= nil then return v end
        if type(k) == "string" and k:match("^%u") then return noop end
        return nil
    end
    setmetatable(f, mt)

    f.SetPoint = function(self, p, rel, rp, x, y)
        self._puntos[#self._puntos + 1] = { p, rel, rp, x, y }
    end
    f.GetPoint = function(self, i)
        local p = self._puntos[i or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    f.ClearAllPoints = function(self) self._puntos = {} end
    f.SetSize = function(self, w, h) self._ancho, self._alto = w, h end
    f.SetWidth = function(self, w) self._ancho = w end
    f.SetHeight = function(self, h) self._alto = h end
    f.GetWidth = function(self) return self._ancho end
    f.GetHeight = function(self) return self._alto end
    f.SetScale = function(self, s) self._escala = s end
    f.GetScale = function(self) return self._escala end
    f.SetAlpha = function(self, a) self._alpha = a end
    f.GetAlpha = function(self) return self._alpha end
    f.SetFrameLevel = function(self, n) self._nivel = n end
    f.GetFrameLevel = function(self) return self._nivel end
    f.SetFrameStrata = function(self, s) self._estrato = s end
    f.GetFrameStrata = function(self) return self._estrato end
    f.SetParent = function(self, p) self._padre = p end
    f.GetParent = function(self) return self._padre end
    f.GetName = function(self) return self._nombre end
    f.GetObjectType = function(self) return self._tipo end
    f.SetID = function(self, id) self._id = id end
    f.GetID = function(self) return self._id or 0 end
    f.Show = function(self) self._visible = true end
    f.Hide = function(self) self._visible = false end
    f.IsVisible = function(self) return self._visible end
    f.IsShown = function(self) return self._visible end
    f.SetScript = function(self, evento, fn)
        self._scripts[evento] = fn
        if evento == "OnEvent" then _G.__handlers[self] = true end
    end
    f.GetScript = function(self, evento) return self._scripts[evento] end
    f.HookScript = function(self, evento, fn)
        local old = self._scripts[evento]
        self._scripts[evento] = function(...)
            if old then old(...) end
            fn(...)
        end
    end
    f.RegisterEvent = function(self, evento) self._eventos[evento] = true end
    f.UnregisterEvent = function(self, evento) self._eventos[evento] = nil end
    f.RegisterAllEvents = noop
    f.CreateTexture = function(self, nombre, capa)
        local t = nuevaRegion("Texture", nombre, self)
        self._regiones[#self._regiones + 1] = t
        if nombre then _G[nombre] = t end
        return t
    end
    f.CreateFontString = function(self, nombre, capa)
        local t = nuevaRegion("FontString", nombre, self)
        self._regiones[#self._regiones + 1] = t
        if nombre then _G[nombre] = t end
        return t
    end
    f.GetNormalTexture = function(self) return self._normal end
    f.SetNormalTexture = function(self, t) self._normal = nil end
    f.GetRegions = function(self) return self._regiones end
    f.GetChildren = function(self) return self._hijos end
    f.SetBackdrop = function(self, b) self._backdrop = b end
    f.GetBackdrop = function(self) return self._backdrop end
    f.StartMoving = noop
    f.StopMovingOrSizing = noop

    if nombre then _G[nombre] = f end
    frames[#frames + 1] = f
    return f
end

_G.__handlers = {}
_G.__frames = frames

_G.UIParent = CreateFrame("Frame", "UIParent")
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.CapriUIState = { dragging = false, dragOwner = nil }

_G.OpenAllBags = noop
_G.CloseAllBags = noop
_G.ToggleBackpack = noop
_G.ToggleBag = noop
_G.updateContainerFrameAnchors = noop
_G.OpenBackpack = noop
_G.CloseBackpack = noop
_G.CloseBankFrame = noop
_G.OpenBag = noop
_G.CloseBag = noop
_G.ToggleKeyRing = noop
_G.PlaySound = noop
_G.MoneyFrame_Update = noop
_G.CastSpellByName = noop
_G.GetCursorPosition = function() return 0, 0 end
_G.GetTime = function() return 100 end
_G.SetCVar = noop

local bolsasBanco = { [5]=true, [6]=true, [7]=true, [8]=true, [9]=true, [10]=true, [11]=true }
_G.GetContainerNumSlots = function(bag)
    if bag >= 0 and bag <= 4 then return 16 end
    if bolsasBanco[bag] then return 20 end
    return 0
end

-- ContainerFrames visibles para las bolsas del banco.
local function crearContenedores()
    for i = 1, 15 do
        local f = CreateFrame("Frame", "ContainerFrame" .. i, _G.UIParent)
        local id = (i <= 7) and (4 + i) or 0
        f:SetID(id)
        f.Show(f)
        for s = 1, 20 do
            CreateFrame("Button", "ContainerFrame" .. i .. "Item" .. s, f)
        end
    end

    -- Contenedores de las bolsas de la mochila (0..4), 16 huecos cada una.
    for i = 8, 12 do
        local f = CreateFrame("Frame", "ContainerFrame" .. i, _G.UIParent)
        f:SetID(i - 8)
        f.Show(f)
        for s = 1, 16 do
            CreateFrame("Button", "ContainerFrame" .. i .. "Item" .. s, f)
        end
    end
end
crearContenedores()
_G.ContainerIDToInventoryID = function(bag) return bag end
_G.BankButtonIDToInvSlotID = function() return 0 end
_G.GetKeyRingSize = function() return 32 end
_G.GetInventoryItemTexture = function() return nil end
_G.GetInventoryItemQuality = function() return nil end
_G.GetInventoryItemDurability = function() return nil end
_G.GetItemQualityColor = function() return 1, 1, 1, 1 end
_G.GetInventorySlotInfo = function(nombre) return 1, "Interface\\Icons\\INV_Misc_QuestionMark" end
_G.GetMoney = function() return 1480 end
_G.GetNumBankSlots = function() return 0, false end
_G.GetBankSlotCost = function() return 1000 end
_G.UnitRace = function() return "Humano", "Human" end
_G.GetSpellInfo = function(nombre) return nombre, nil, "Interface\\Icons\\INV_Misc_QuestionMark" end
_G.GetNumSkillLines = function() return 0 end
_G.GetSkillLineInfo = function() return nil end

-- Marco de banco de Blizzard
_G.BankFrame = CreateFrame("Frame", "BankFrame")
for i = 1, 28 do CreateFrame("Button", "BankFrameItem" .. i, _G.BankFrame) end
for i = 1, 7 do CreateFrame("Button", "BankFrameBag" .. i, _G.BankFrame) end
CreateFrame("Button", "BankFramePurchaseButton", _G.BankFrame)
CreateFrame("Frame", "BankFramePurchaseInfo", _G.BankFrame)

-- CapriUI (lo minimo que usa bag.lua)
local C = {}
_G.CapriUI = C
C.media = "Interface\\AddOns\\CaprimedinaUI\\texturas\\"
C.tex = { ring = C.media .. "ring", ringPortrait = C.media .. "ring_portrait", disc = C.media .. "disc",
          glow = C.media .. "glow", barBg = C.media .. "bar_bg", gloss = C.media .. "gloss",
          ringThin = C.media .. "ring_thin" }
C.colorBg = {0.1, 0.11, 0.12, 0.95}
C.colorKey = {0.18, 0.19, 0.21, 1}
C.colorSpecial = {0.25, 0.27, 0.30, 1}
C.colorHover = {0.35, 0.37, 0.40, 1}
C.colorPress = {0.70, 0.75, 0.80, 1}
C.colorMenu = {0.14, 0.15, 0.17, 0.98}
C.gold = {1, 0.84, 0.34}
C.goldSoft = {0.55, 0.45, 0.22}

function C.Print(msg) end
function C.SetOutlineFont(fs, size) if fs and fs.SetFont then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE") end end
function C.StyleWindow(f) if f then f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }) end end
function C.ApplyButtonAnimations(btn) end
function C.CreateStyledButton(parent, texto, w, h, especial)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.SetText = function(self, t) self._texto = t end
    b.GetText = function(self) return self._texto end
    return b
end
function C.CreateStyledClose(parent)
    local b = C.CreateStyledButton(parent, "X", 40, 26, true)
    b:SetScript("OnClick", function() parent:Hide() end)
    return b
end
function C.CreateRing() return nil end
function C.CreateDisc() return nil end
function C.AddHoverGlow() return nil end
function C.SkinPanel() end
function C.InitDB() end

_G.GetContainerItemInfo = function() return nil end
_G.SetItemButtonTexture = function() end
_G.SetItemButtonCount = function() end
_G.GetKeyRingSize = function() return 32 end

local llaveroFrame = CreateFrame("Frame", "ContainerFrame13", _G.UIParent)
llaveroFrame:SetID(-2)
llaveroFrame:Hide()
for s = 1, 4 do
    CreateFrame("Button", "ContainerFrame13Item" .. s, llaveroFrame)
end
_G.ToggleKeyRing = function()
    if llaveroFrame:IsVisible() then llaveroFrame:Hide() else llaveroFrame:Show() end
end
"""


def preparar(lua):
    lua.execute(STUB)
    with open(BAG_LUA, encoding="utf-8") as fh:
        codigo = fh.read()
    lua.execute(codigo, name="bag.lua")


def disparar(lua, evento, *args):
    _G = lua.globals()
    handlers = _G.__handlers
    n = 0
    for f in handlers:
        eventos = f._eventos
        if eventos and eventos[evento]:
            script = f._scripts["OnEvent"]
            if script:
                script(f, evento, *args)
                n += 1
    return n


def escenario(cols, escala, side_bags=True, banco_lleno=False):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    preparar(lua)
    _G = lua.globals()

    _G.CaprimedinaUIDB = lua.table_from({
        "bankCols": cols,
        "bankScale": escala,
        "showBankSideBags": side_bags,
        "showBankTitles": True,
        "enableBags": True,
    })
    if banco_lleno:
        _G.GetNumBankSlots = lua.eval("function() return 7, true end")

    disparar(lua, "VARIABLES_LOADED")
    banco = _G.UnifiedBankFrame
    banco.Show(banco)
    disparar(lua, "BANKFRAME_OPENED")
    # Segundo pase: comprueba que recrear/ocultar costuras es idempotente.
    disparar(lua, "BAG_UPDATE")
    disparar(lua, "BANKFRAME_OPENED")

    medir = lua.eval("""function()
        local b = UnifiedBankFrame
        local f = UnifiedBankFlap
        local p = UnifiedBankPlaque
        local s = UnifiedBankSlotPanel
        return {
            ancho = b:GetWidth(), alto = b:GetHeight(),
            flapW = f:GetWidth(), flapH = f:GetHeight(),
            placaW = p:GetWidth(), placaH = p:GetHeight(),
            bolsilloW = s:GetWidth(), bolsilloH = s:GetHeight(),
            regiones = #b:GetRegions(), regionesFlap = #f:GetRegions(),
            visible = b:IsVisible() and true or false,
            strataFlap = f:GetFrameStrata(),
            nivelFlap = f:GetFrameLevel(), nivelBanco = b:GetFrameLevel(),
            escalaFrame = b:GetScale(),
        }
    end""")
    datos = medir()
    datos = {k: datos[k] for k in datos}

    coste = lua.eval("""function()
        local ct = UnifiedBankCostText
        local cm = UnifiedBankCostMoney
        return {
            padre = (ct and ct._padre and ct._padre:GetName()) or "nil",
            texto = (ct and ct:GetText()) or "",
            shown = (ct and ct:IsShown()) and true or false,
            moneyShown = (cm and cm:IsShown()) and true or false,
            moneyP = (cm and cm._puntos[1] and cm._puntos[1][1]) or "nil",
        }
    end""")()
    assert coste["padre"] == "UnifiedBankPlaque", coste
    if banco_lleno:
        assert coste["shown"] and coste["texto"] == "Ranuras al maximo", coste
        assert not coste["moneyShown"], coste
    else:
        assert not coste["shown"], coste
        assert coste["moneyShown"], coste
        assert coste["moneyP"] == "LEFT", coste

    assert datos["ancho"] > 100, datos
    assert datos["alto"] > 100, datos
    assert datos["flapW"] == datos["ancho"] - 4, datos
    assert datos["flapH"] == 62, datos
    assert datos["placaW"] <= datos["ancho"] - 16, datos
    assert datos["nivelFlap"] > datos["nivelBanco"], datos
    assert abs(datos["escalaFrame"] - escala) < 0.001, datos
    assert datos["regionesFlap"] >= 22, datos
    assert datos["regiones"] > 12, datos
    datos["cols"] = cols
    datos["escala"] = escala
    return datos


def escenario_mochila(cols, escala, side_bags=True, titulos=True):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    preparar(lua)
    _G = lua.globals()
    _G.CaprimedinaUIDB = lua.table_from({
        "bagCols": cols,
        "bagScale": escala,
        "showSideBags": side_bags,
        "showBagTitles": titulos,
        "enableBags": True,
    })

    disparar(lua, "VARIABLES_LOADED")
    _G.OpenAllBags()
    disparar(lua, "BAG_UPDATE")
    _G.OpenAllBags()

    medir = lua.eval("""function()
        local b = UnifiedBagFrame
        local f = UnifiedBagFlap
        local p = UnifiedPaperDollPanel
        local s = UnifiedBagSlotPanel
        local mp = UnifiedBagMoneyPlaque
        local pl = UnifiedBagPlaque
        local pd = p._puntos[1] or {0, 0, 0, 0, 0}
        local sd = s._puntos[1] or {0, 0, 0, 0, 0}
        local fd = f._puntos[1]
        local md = mp._puntos[1]
        return {
            ancho = b:GetWidth(), alto = b:GetHeight(),
            escalaFrame = b:GetScale(),
            visible = b:IsVisible() and true or false,
            flapW = f:GetWidth(), flapH = f:GetHeight(),
            flapX = fd[4], flapY = fd[5],
            pdW = p:GetWidth(), pdH = p:GetHeight(),
            pdX = pd[4], pdY = pd[5], pdShown = p:IsVisible() and true or false,
            slotW = s:GetWidth(), slotH = s:GetHeight(),
            slotX = sd[4], slotY = sd[5],
            moneyW = mp:GetWidth(), moneyH = mp:GetHeight(),
            moneyP = md[1],
            regiones = #b:GetRegions(),
            nivelFlap = f:GetFrameLevel(), nivelBanco = b:GetFrameLevel(),
        }
    end""")
    datos = medir()
    datos = {k: datos[k] for k in datos}

    assert datos["ancho"] > 300, datos
    assert datos["alto"] > 300, datos
    assert abs(datos["escalaFrame"] - escala) < 0.001, datos
    assert datos["flapW"] == datos["ancho"] - 4, datos
    assert datos["flapH"] == 62, datos
    assert datos["nivelFlap"] > datos["nivelBanco"], datos
    if side_bags:
        assert datos["pdShown"], datos
        assert datos["pdY"] == -74, datos
        assert datos["pdX"] == 30, datos
        assert datos["slotH"] == 52, datos
        assert datos["slotW"] == 220, datos
    else:
        assert not datos["pdShown"], datos
    datos["cols"] = cols
    datos["escala"] = escala
    datos["side_bags"] = side_bags
    return datos


def escenario_llavero():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    preparar(lua)
    _G = lua.globals()
    _G.CaprimedinaUIDB = lua.table_from({
        "bagCols": 10,
        "bagScale": 1.0,
        "showSideBags": True,
        "showBagTitles": True,
        "enableBags": True,
    })
    disparar(lua, "VARIABLES_LOADED")
    _G.OpenAllBags()

    _G.UnifiedBagKeyringButton._scripts["OnClick"](_G.UnifiedBagKeyringButton)

    datos = lua.eval("""function()
        local b = UnifiedBagFrame
        return {
            titulo = UnifiedBagTitle:GetText(),
            llavero = (UnifiedBagLabelKeyring and UnifiedBagLabelKeyring:IsShown()) and true or false,
            bag1 = (ContainerFrame8Item1 and ContainerFrame8Item1:IsShown()) and true or false,
            slot32 = (ContainerFrame13Item32 and ContainerFrame13Item32._puntos[1] ~= nil) and true or false,
            n32 = (ContainerFrame13Item32 ~= nil) and true or false,
            ancho = b:GetWidth(), alto = b:GetHeight(),
        }
    end""")()
    datos = {k: datos[k] for k in datos}
    assert datos["titulo"] == "LLAVERO", datos
    assert datos["llavero"], datos
    assert not datos["bag1"], datos
    assert datos["n32"] and datos["slot32"], datos

    _G.UnifiedBagKeyringButton._scripts["OnClick"](_G.UnifiedBagKeyringButton)

    datos2 = lua.eval("""function()
        return {
            titulo = UnifiedBagTitle:GetText(),
            llavero = (UnifiedBagLabelKeyring and UnifiedBagLabelKeyring:IsShown()) and true or false,
            bag1 = (ContainerFrame8Item1 and ContainerFrame8Item1:IsShown()) and true or false,
        }
    end""")()
    datos2 = {k: datos2[k] for k in datos2}
    assert datos2["titulo"] != "LLAVERO", datos2
    assert not datos2["llavero"], datos2
    assert datos2["bag1"], datos2
    datos["vuelta"] = datos2["titulo"]

    # Cerrar la mochila estando en el llavero: al reabrir debe salir la mochila.
    _G.UnifiedBagKeyringButton._scripts["OnClick"](_G.UnifiedBagKeyringButton)
    _G.UnifiedBagFrame._scripts["OnHide"](_G.UnifiedBagFrame)
    _G.OpenAllBags()
    datos3 = lua.eval("""function()
        return {
            titulo = UnifiedBagTitle:GetText(),
            llavero = (UnifiedBagLabelKeyring and UnifiedBagLabelKeyring:IsShown()) and true or false,
            bag1 = (ContainerFrame8Item1 and ContainerFrame8Item1:IsShown()) and true or false,
        }
    end""")()
    datos3 = {k: datos3[k] for k in datos3}
    assert datos3["titulo"] != "LLAVERO", datos3
    assert not datos3["llavero"], datos3
    assert datos3["bag1"], datos3
    datos["reabierta"] = datos3["titulo"]
    return datos


def main():
    resultados = []
    for cols in (4, 10, 20):
        for escala in (0.6, 1.0, 1.8):
            resultados.append(escenario(cols, escala))
    resultados.append(escenario(10, 1.0, side_bags=False))
    resultados.append(escenario(10, 1.0, banco_lleno=True))

    for cols in (4, 10, 16):
        for escala in (0.6, 1.0, 1.4):
            resultados.append(escenario_mochila(cols, escala))
    resultados.append(escenario_mochila(10, 1.0, side_bags=False))
    resultados.append(escenario_mochila(10, 1.0, titulos=False))
    resultados.append(escenario_llavero())

    for d in resultados:
        print(d)
    print("OK: %d escenarios" % len(resultados))


if __name__ == "__main__":
    sys.exit(main())
