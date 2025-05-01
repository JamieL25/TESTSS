-- cl_init.lua (Client-side)
include("shared.lua")

--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- Enhanced Deploy Menu UI (F2)
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- 1. Define custom fonts
surface.CreateFont("BGTitle", {
    font = "Roboto",    -- Ensure Roboto is installed or replace
    size = 24,
    weight = 700,
    antialias = true,
})
surface.CreateFont("BGButton", {
    font = "Roboto",
    size = 20,
    weight = 600,
    antialias = true,
})

-- 2. Deploy options (sync with server IDs)
local BG_DEPLOY_OPTIONS = {
    { id = 1, name = "Assault Loadout" },
    { id = 2, name = "Sniper Kit" },
    { id = 3, name = "Support Package" },
    { id = 4, name = "Heavy Armor" },
}

-- 3. Deploy Menu Panel Definition
local PANEL = {}
function PANEL:Init()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(false)
    self:MakePopup()
    self:SetSize(ScrW() * 0.4, ScrH() * 0.6)
    self:Center()
    self.StartTime = CurTime()

    -- Close button
    local btnClose = vgui.Create("DButton", self)
    btnClose:SetText("✕")
    btnClose:SetFont("BGButton")
    btnClose:Dock(RIGHT)
    btnClose:SetWide(40)
    btnClose:DockMargin(0, 8, 8, 0)
    function btnClose:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(200,50,50,220))
        draw.SimpleText(self:GetText(), "BGButton", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    function btnClose:DoClick()
        self:AlphaTo(0, 0.2, 0, function() self:Remove() end)
    end

    -- Scrollable list area
    self.content = vgui.Create("DScrollPanel", self)
    self.content:Dock(FILL)
    self.content:DockMargin(10, 40, 10, 10)
    local sbar = self.content:GetVBar()
    function sbar:Paint() end
    function sbar.btnUp:Paint() end
    function sbar.btnDown:Paint() end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(100,100,100,200))
    end

    -- Add buttons
    for _, opt in ipairs(BG_DEPLOY_OPTIONS) do
        local btn = vgui.Create("DButton", self.content)
        btn:SetText(opt.name)
        btn:SetFont("BGButton")
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetTall(45)
        function btn:Paint(w, h)
            local bg = self:IsHovered() and Color(80,80,80,220) or Color(60,60,60,220)
            draw.RoundedBox(6, 0, 0, w, h, bg)
            draw.SimpleText(self:GetText(), "BGButton", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        function btn:DoClick()
            RunConsoleCommand("bg_deploy", opt.id)
            self:GetParent():GetParent():AlphaTo(0, 0.2, 0, function() self:GetParent():GetParent():Remove() end)
        end
    end
end

function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.StartTime)
    draw.RoundedBox(8, 0, 0, w, h, Color(30,30,30,240))
    draw.SimpleText("Select Deploy Option", "BGTitle", 20, 15, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end
vgui.Register("BGDeployMenu", PANEL, "DFrame")

-- 4. F2 Toggle: open/close Deploy Menu
hook.Add("Think", "BG_ToggleDeployMenu", function()
    if input.WasKeyReleased(KEY_F2) then
        if IsValid(_G.BGDeployMenu) then
            _G.BGDeployMenu:Remove()
            _G.BGDeployMenu = nil
        else
            _G.BGDeployMenu = vgui.Create("BGDeployMenu")
        end
    end
end)

-- Auto-open Deploy Menu on initial spawn
hook.Add("InitPostEntity", "BG_AutoOpenMenu", function()
    timer.Simple(0.5, function()
        if not IsValid(_G.BGDeployMenu) then
            _G.BGDeployMenu = vgui.Create("BGDeployMenu")
        end
    end)
end)
end)
    end
end)

--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- Q-Menu Permission
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
function GM:SpawnMenuEnabled()
    local ply = LocalPlayer()
    return IsValid(ply) and (ply:IsAdmin() or ply:IsListenServerHost())
end

--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- SAFE ZONE HIDE-BOX LOGIC
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
local SAFE_ZONE_MIN = Vector(1870.538818, -275.760559, -12532.864258)
local SAFE_ZONE_MAX = Vector(2298.709229, 543.457153, -12235.714844)
local safeZoneEntities = {}

hook.Add("OnEntityCreated", "TagSafeZoneEntities", function(ent)
    timer.Simple(0, function()
        if IsValid(ent) and ent:GetPos():WithinAABox(SAFE_ZONE_MIN, SAFE_ZONE_MAX) then
            safeZoneEntities[ent] = true
        end
    end)
end)

timer.Simple(1, function()
    for _, ent in ipairs(ents.GetAll()) do
        if ent:GetPos():WithinAABox(SAFE_ZONE_MIN, SAFE_ZONE_MAX) then
            safeZoneEntities[ent] = true
        end
    end
end)

hook.Add("PreDrawOpaqueRenderables", "HideSafeZoneObjects", function()
    local inside = LocalPlayer():GetNWBool("InSafeZone", false)
    for ent in pairs(safeZoneEntities) do
        if IsValid(ent) then
            ent:SetNoDraw(not inside)
        else
            safeZoneEntities[ent] = nil
        end
    end
end)

--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- HUD & DEPLOY CONFIRMATION
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
local SafeCountdownEnd = 0
local SafeCooldownEnd = 0
local DeployConfirmationEnd = 0

net.Receive("SafeTeleportCountdown", function()
    SafeCountdownEnd = CurTime() + 4
    SafeCooldownEnd = CurTime() + 120
end)

net.Receive("ConfirmDeploy", function()
    DeployConfirmationEnd = CurTime() + 3
end)

hook.Add("HUDPaint", "BG_SafeDeployHUD", function()
    local cx, cy = ScrW()/2, ScrH()/2 - 100
    -- Safe countdown
    if SafeCountdownEnd > CurTime() then
        draw.SimpleText(
            "Teleporting to Safe Zone in "..math.ceil(SafeCountdownEnd - CurTime()).."...",
            "DermaLarge", cx, cy, Color(0,255,0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    -- Safe cooldown
    if SafeCooldownEnd > CurTime() and SafeCountdownEnd <= CurTime() then
        draw.SimpleText(
            "!safe cooldown: "..math.ceil(SafeCooldownEnd - CurTime()).."s",
            "DermaDefault", ScrW()-20, ScrH()-100, Color(255,255,0,200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    -- Deploy confirmation
    if DeployConfirmationEnd > CurTime() then
        draw.SimpleText(
            "You have entered the battlefield!", "DermaLarge",
            cx, cy + 80, Color(0,200,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- Hide Safe-Zone players
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
hook.Add("PrePlayerDraw", "BG_HideSafePlayers", function(target)
    if target == LocalPlayer() or LocalPlayer():IsSpec() then return end
    local viewerIn = LocalPlayer():GetNWBool("InSafeZone", false)
    local targetIn = target:GetNWBool("InSafeZone", false)
    if not viewerIn and targetIn then
        target:SetRenderMode(RENDERMODE_TRANSALPHA)
        target:SetColor(Color(255,255,255,0))
        return true
    else
        target:SetRenderMode(RENDERMODE_NORMAL)
        target:SetColor(Color(255,255,255,255))
    end
end)

hook.Add("Shutdown", "BG_ResetVisibility", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(Color(255,255,255,255))
        end
    end
end)

print("Military Gamemode - cl_init.lua loaded (Client)")
