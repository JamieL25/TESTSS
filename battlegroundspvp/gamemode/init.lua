-- Server-side file

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("DeployPlayer")
util.AddNetworkString("SafeTeleportCountdown")
util.AddNetworkString("ConfirmDeploy")
util.AddNetworkString("RequestDeployMenu")

-- First-login position
local INITIAL_SPAWN_POS   = Vector(1819.304443,  136.818985, -11896.761719)
local INITIAL_SPAWN_ANGLE = Angle(  40.641457, -179.751663,   0.000000)

-- Where !safe teleports you
local SAFE_SPAWN_POS   = Vector(2127.101318,  168.765152, -12432.550781)
local SAFE_SPAWN_ANGLE = Angle(-1.242542, -178.839386,   0.000000)

local PVP_SPAWNS = {
    Vector(-2121.186279, -2410.672119, -14511.968750),
    Vector(-3729.331543, -1272.942993, -14511.968750),
    Vector(-3751.061279,  1314.375854, -14511.968750),
    Vector(-1464.063354,  2510.692139, -14511.968750),
    Vector(-464.353790,    973.957520, -14511.968750),
}

function GM:Initialize()
    if self.BaseClass and self.BaseClass.Initialize then
        self.BaseClass:Initialize()
    end
    print("Server Initialized Gamemode: " .. self.Name)
end

-- Track first joiners
function GM:PlayerInitialSpawn(ply)
    ply.InSafeZone       = false
    ply.HasSpawnedBefore = false
end

function GM:PlayerSpawn(ply)
    -- Default sandbox behavior
    self.BaseClass.PlayerSpawn(self, ply)

    -- Model & movement setup
    ply:SetModel("models/player/group01/male_01.mdl")
    ply:SetWalkSpeed(200)
    ply:SetRunSpeed(400)
    ply:SetJumpPower(200)

    -- Give admin/host physgun & toolgun
    if ply:IsAdmin() or ply:IsListenServerHost() then
        ply:Give("weapon_physgun")
        ply:Give("gmod_tool")
    end

    -- First-ever spawn: send to initial spot and lock/hide
    if not ply.HasSpawnedBefore then
        ply.HasSpawnedBefore = true
        ply:SetPos(INITIAL_SPAWN_POS)
        ply:SetEyeAngles(INITIAL_SPAWN_ANGLE)
        ply:SetNWBool("InSafeZone", true)
        ply:Lock()
        return
    end

    -- All later spawns use safe/PvP logic
    timer.Simple(0, function()
        if not IsValid(ply) then return end

        if ply.InSafeZone then
            ply:SetPos(SAFE_SPAWN_POS)
            ply:SetEyeAngles(SAFE_SPAWN_ANGLE)
            ply:SetNWBool("InSafeZone", true)
        else
            local chosen = table.Random(PVP_SPAWNS)
            ply:SetPos(chosen)
            ply:UnLock()
            ply:SetNWBool("InSafeZone", false)

            ply:GodEnable()
            timer.Simple(2.5, function()
                if IsValid(ply) then ply:GodDisable() end
            end)
        end
    end)
end

-- Shared deploy logic
local function DoDeploy(ply)
    if not IsValid(ply) then return end

    ply.InSafeZone       = false
    ply:SetNWBool("InSafeZone", false)
    ply:UnLock()

    local chosen = table.Random(PVP_SPAWNS)
    ply:SetPos(chosen)

    ply:GodEnable()
    timer.Simple(2.5, function()
        if IsValid(ply) then ply:GodDisable() end
    end)

    ply:StripWeapons()
    timer.Simple(0.1, function()
        if IsValid(ply) and #ply:GetWeapons() == 0 then
            ply:Give("weapon_pistol")
            ply:GiveAmmo(60, "Pistol", true)
        end
    end)

    if ply:IsAdmin() or ply:IsListenServerHost() then
        timer.Simple(0.2, function()
            if IsValid(ply) then
                ply:Give("weapon_physgun")
                ply:Give("gmod_tool")
            end
        end)
    end

    net.Start("ConfirmDeploy")
    net.Send(ply)
end

-- Fired by F2/Deploy menu
net.Receive("DeployPlayer", function(_, ply)
    DoDeploy(ply)
end)

-- !deploy chat command
hook.Add("PlayerSay", "DeployTextCommand", function(ply, text)
    if string.lower(text) == "!deploy" then
        DoDeploy(ply)
        return ""  -- prevent the message from appearing
    end
end)

-- !safe chat command
hook.Add("PlayerSay", "SafeZoneCommand", function(ply, text)
    if string.lower(text) ~= "!safe" then return end

    if ply:GetNWBool("InSafeZone", false) then
        ply:ChatPrint("[SAFEZONE] You are already in the safe zone!")
        return ""
    end
    if ply.NextSafeTeleportTime and ply.NextSafeTeleportTime > CurTime() then
        local wait = math.ceil(ply.NextSafeTeleportTime - CurTime())
        ply:ChatPrint("[SAFEZONE] Wait " .. wait .. "s before teleporting again.")
        return ""
    end

    ply:ChatPrint("[SAFEZONE] Teleporting to Safe Zone in 4 seconds...")
    net.Start("SafeTeleportCountdown")
    net.Send(ply)

    timer.Simple(4, function()
        if not IsValid(ply) or not ply:Alive() then return end
        ply.InSafeZone           = true
        ply.NextSafeTeleportTime = CurTime() + 120
        ply:SetPos(SAFE_SPAWN_POS)
        ply:SetEyeAngles(SAFE_SPAWN_ANGLE)
        ply:SetNWBool("InSafeZone", true)
        ply:ChatPrint("[SAFEZONE] You are now in the Safe Zone.")
    end)

    return ""
end)

-- Privileged spawn permissions
local function IsPrivileged(p) return p:IsAdmin() or p:IsListenServerHost() end
function GM:CanTool(ply, trace, mode)         return IsPrivileged(ply) end
function GM:PlayerSpawnProp(ply, model)      return IsPrivileged(ply) end
function GM:PlayerSpawnSWEP(ply, cls, dat)   return IsPrivileged(ply) end
function GM:PlayerSpawnEffect(ply, mdl)      return IsPrivileged(ply) end
function GM:PlayerSpawnRagdoll(ply, mdl)     return IsPrivileged(ply) end
function GM:PlayerSpawnSENT(ply, cls)        return IsPrivileged(ply) end
function GM:PlayerSpawnVehicle(ply, m, c, t) return IsPrivileged(ply) end
function GM:AllowPlayerSpawn(ply)            return IsPrivileged(ply) end

hook.Add("PlayerCanUseWeapon", "AllowAdminToolgun", function(ply, wep)
    if IsValid(wep)
    and wep:GetClass() == "gmod_tool"
    and IsPrivileged(ply) then
        return true
    end
end)

print("Military Gamemode - init.lua loaded (Server)")
