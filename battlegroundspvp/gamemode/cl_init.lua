-- cl_init.lua (Client-side)

include("shared.lua")

--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
-- DEPLOY MENU TOGGLE (F2 via Think + input)
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

local MainMenu = nil

hook.Add("Think", "DeployMenu_Toggle_F2", function()
    if input.WasKeyReleased(KEY_F2) then
        if IsValid(MainMenu) then
            MainMenu:Remove()
            MainMenu = nil
        else
            OpenMainMenu()
        end
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
local SAFE_ZONE_MAX = Vector(2298.709229,  543.457153, -12235.714844)
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
-- HUD & DEPLOY MENU UI
--––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

local SafeCountdownEnd      = 0
local SafeCooldownEnd       = 0
local DeployConfirmationEnd = 0

net.Receive("SafeTeleportCountdown", function()
    SafeCountdownEnd = CurTime() + 4
    SafeCooldownEnd  = CurTime() + 120
end)

net.Receive("ConfirmDeploy", function()
    DeployConfirmationEnd = CurTime() + 3
end)

hook.Add("HUDPaint", "SafeTeleportCountdownHUD", function()
    local cx, cy = ScrW()/2, ScrH()/2 - 100

    if SafeCountdownEnd > CurTime() then
        draw.SimpleText(
            "Teleporting to Safe Zone in " .. math.ceil(SafeCountdownEnd - CurTime()) .. "...",
            "DermaLarge", cx, cy, Color(0,255,0,255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    if SafeCooldownEnd > CurTime() and SafeCountdownEnd <= CurTime() then
        draw.SimpleText(
            "!safe cooldown: " .. math.ceil(SafeCooldownEnd - CurTime()) .. "s",
            "DermaDefault", ScrW()-20, ScrH()-100,
            Color(255,255,0,200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
        )
    end

    if DeployConfirmationEnd > CurTime() then
        draw.SimpleText(
            "You have entered the battlefield!",
            "DermaLarge", cx, cy + 80, Color(0,200,255,255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end
end)

hook.Add("InitPostEntity", "OpenDeployMenuOnJoin", function()
    timer.Simple(0.5, function()
        if not IsValid(MainMenu) then
            OpenMainMenu()
        end
    end)
end)

function OpenMainMenu()
    if IsValid(MainMenu) then
        MainMenu:Remove()
    end

    local serverName = GetHostName() or GM.Name or "GMod Server"
    MainMenu = vgui.Create("DFrame")
    MainMenu:SetSize(ScrW(), ScrH())
    MainMenu:SetTitle("")
    MainMenu:ShowCloseButton(false)
    MainMenu:SetDraggable(false)
    MainMenu:MakePopup()
    MainMenu.startTime = SysTime()

    MainMenu.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, self.startTime)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(
            serverName, "DermaLarge", w/2, 50,
            Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    local function makeButton(text, x, y, hoverCol, baseCol, onClick)
        local btn = vgui.Create("DButton", MainMenu)
        btn:SetSize(300, 60)
        btn:SetPos(x, y)
        btn:SetText(text)
        btn:SetFont("DermaLarge")
        btn:SetTextColor(Color(255,255,255))
        btn.Paint = function(self, w, h)
            local bg = self:IsHovered() and hoverCol or baseCol
            draw.RoundedBox(10, 0, 0, w, h, bg)
        end
        btn.DoClick = onClick
    end

    -- DEPLOY
    makeButton("DEPLOY",
        ScrW()/2 - 150, ScrH()/2 - 100,
        Color(0,230,0), Color(0,200,0),
        function()
            net.Start("DeployPlayer")
            net.SendToServer()
            MainMenu:Remove()
            MainMenu = nil
        end
    )
    -- SETTINGS (stub)
    makeButton("SETTINGS",
        ScrW()/2 - 150, ScrH()/2,
        Color(80,80,80), Color(60,60,60),
        function() end
    )
    -- DONATE
    makeButton("DONATE",
        ScrW()/2 - 150, ScrH()/2 + 100,
        Color(0,150,255), Color(0,120,255),
        function() gui.OpenURL("https://yourdonatelink.com") end
    )
end

-- Hide Safe-Zone players
hook.Add("PrePlayerDraw", "HideSafeZonePlayers", function(target)
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

hook.Add("Shutdown", "ResetPlayerVisibility", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(Color(255,255,255,255))
        end
    end
end)

print("Military Gamemode - cl_init.lua loaded (Client)")
