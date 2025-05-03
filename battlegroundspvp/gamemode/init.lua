-- Server-side file: init.lua
-- Respawn Persistence for CW2, FAS2 & Attachments + Shop Hook Bridge
-- Version: v1.27 (Full multi-source attach capture & correct restore mapping)

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Network Strings
util.AddNetworkString("DeployPlayer")
util.AddNetworkString("SafeTeleportCountdown")
util.AddNetworkString("ConfirmDeploy")
util.AddNetworkString("RequestDeployMenu")

-- Death-save storage
PlayerDeathInventories = PlayerDeathInventories or {}

-- Spawn points
local INITIAL_SPAWN_POS   = Vector(1819.3, 136.8, -11896.7)
local INITIAL_SPAWN_ANGLE = Angle(40.64, -179.75, 0)
local PVP_SPAWNS = {
    Vector(-2121.2, -2410.7, -14512),
    Vector(-3729.3, -1272.9, -14512),
    Vector(-3751.1, 1314.4, -14512),
    Vector(-1464.1, 2510.7, -14512),
    Vector(-464.4, 973.96, -14512),
}

-- Spawn points
local INITIAL_SPAWN_POS   = Vector(1819.3, 136.8, -11896.7) = {
    Vector(-2121.2, -2410.7, -14512),
    Vector(-3729.3, -1272.9, -14512),
    Vector(-3751.1, 1314.4, -14512),
    Vector(-1464.1, 2510.7, -14512),
    Vector(-464.4, 973.96, -14512),
}

-- Utility: capture attachments table
local function CaptureAttachments(wep)
    -- 1. CW2 GetSetup
    if isfunction(wep.GetSetup) then
        local setup = wep:GetSetup()
        if istable(setup) and next(setup) then return table.Copy(setup) end
    end
    -- 2. ActiveAttachments
    if istable(wep.ActiveAttachments) and next(wep.ActiveAttachments) then
        return table.Copy(wep.ActiveAttachments)
    end
    -- 3. CW_Attachments
    if istable(wep.CW_Attachments) and next(wep.CW_Attachments) and not isnumber(next(wep.CW_Attachments)) then
        return table.Copy(wep.CW_Attachments)
    end
    -- 4. FAS2 Attachments table
    if istable(wep.Attachments) and next(wep.Attachments) then
        return table.Copy(wep.Attachments)
    end
    return nil
end

-- CW2/FAS2 detection
local function IsCW2(wep)
    return isfunction(wep.GetSetup) and isfunction(wep.ApplySetup)
end
local function IsFAS2(wep)
    return isfunction(wep.IsFAS2Weapon) and wep:IsFAS2Weapon()
end

-- Initialize
function GM:Initialize()
    if self.BaseClass and self.BaseClass.Initialize then self.BaseClass:Initialize() end
    print("init.lua v1.27 loaded")
end

-- Save inventory on death
function GM:DoPlayerDeath(ply, attacker, dmginfo)
    local uid = ply:UniqueID()
    local inv = { weapons = {}, ammo = {}, active = nil }

    for _, w in ipairs(ply:GetWeapons()) do
        if not IsValid(w) then continue end
        -- skip admin tools
        local cls = w:GetClass()
        if cls == "weapon_physgun" or cls == "gmod_tool" then continue end
        -- only CW2 or FAS2 or attachments
        if not (IsCW2(w) or IsFAS2(w) or istable(w.Attachments)) then continue end

        local atts = CaptureAttachments(w)
        inv.weapons[cls] = { attachments = atts }

        -- save ammo
        for _, ammoID in ipairs({ w:GetPrimaryAmmoType(), w:GetSecondaryAmmoType() }) do
            local name = game.GetAmmoName(ammoID)
            if name and name ~= "" then
                inv.ammo[name] = ply:GetAmmoCount(name)
            end
        end
    end

    -- active
    local aw = ply:GetActiveWeapon()
    if IsValid(aw) and inv.weapons[aw:GetClass()] then
        inv.active = aw:GetClass()
    end

    PlayerDeathInventories[uid] = inv
end

-- Clear on join
function GM:PlayerInitialSpawn(ply)
    ply.HasSpawnedOnce = false
    PlayerDeathInventories[ply:UniqueID()] = nil
end

-- Restore on spawn
function GM:PlayerSpawn(ply)
    self.BaseClass.PlayerSpawn(self, ply)
    ply:StripWeapons()
    ply:SetModel("models/player/group01/male_01.mdl")
    ply:SetWalkSpeed(200); ply:SetRunSpeed(400); ply:SetJumpPower(200)

    local uid = ply:UniqueID()
    local data = PlayerDeathInventories[uid]

    -- first spawn
    if not ply.HasSpawnedOnce then
        ply.HasSpawnedOnce = true
        ply:SetPos(INITIAL_SPAWN_POS)
        ply:SetEyeAngles(INITIAL_SPAWN_ANGLE)
        ply:SetNWBool("InSafeZone", true)
        ply:Lock(); ply:Freeze(true)
        if ply:IsAdmin() or ply:IsListenServerHost() then
            ply:Give("weapon_physgun"); ply:Give("gmod_tool")
        end
        return
    end

    -- death respawn
    if data then
        -- teleport to PvP
        local sp = table.Random(PVP_SPAWNS)
        ply:UnLock(); ply:Freeze(false)
        ply:SetNWBool("InSafeZone", false)
        ply:SetPos(sp)
        ply:SetEyeAngles(Angle(0, math.random(0,360),0))
        ply:GodEnable()
        timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end)

        -- give weapons and restore attachments
        local activeEnt
        for cls, wd in pairs(data.weapons) do
            local w = ply:Give(cls)
            if not IsValid(w) then continue end
            local atts = wd.attachments
            if atts then
                if IsCW2(w) then
                    w:ApplySetup(atts)
                elseif isfunction(w.attach) then
                    for id in pairs(atts) do w:attach(id) end
                elseif isfunction(w.Attach) then
                    for id in pairs(atts) do w:Attach(id) end
                end
                -- rebuild
                if isfunction(w.setupAttachmentModels) then w:setupAttachmentModels() end
                if isfunction(w.ApplyAttachmentsToModel) then w:ApplyAttachmentsToModel() end
                if isfunction(w.SetWeaponModel) then w:SetWeaponModel() end
                if isfunction(w.Deploy) then w:Deploy() end
            end
            if cls == data.active then activeEnt = w end
        end

        -- restore ammo
        for name, amt in pairs(data.ammo) do
            ply:SetAmmo(amt, name)
        end

        -- select active
        if IsValid(activeEnt) then
            timer.Simple(0.1, function() if IsValid(ply) then ply:SelectWeapon(activeEnt:GetClass()) end end)
        end

        PlayerDeathInventories[uid] = nil
        return
    end

    -- fallback teleport
    local sp2 = table.Random(PVP_SPAWNS)
    ply:UnLock(); ply:Freeze(false)
    ply:SetNWBool("InSafeZone", false)
    ply:SetPos(sp2)
    ply:SetEyeAngles(Angle(0, math.random(0,360),0))
    ply:GodEnable(); timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end)
end

-- Deploy Hook Bridge
local function DoDeploy(ply)
    if not IsValid(ply) then return end
    PlayerDeathInventories[ply:UniqueID()] = nil
    ply:StripWeapons()

    -- teleport
    local sp = table.Random(PVP_SPAWNS)
    ply:UnLock(); ply:Freeze(false)
    ply:SetNWBool("InSafeZone", false)
    ply:SetPos(sp)
    ply:SetEyeAngles(Angle(0, math.random(0,360),0))
    ply:GodEnable(); timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end)

    -- shop weapons
    local equip = hook.Run("GetShopEquippedWeapons", ply) or {}
    local owned = hook.Run("GetShopOwnedWeapons", ply) or {}
    local start = hook.Run("GetShopStarterWeapon")
    if start then owned[start] = true end
    local lastW
    for _, c in ipairs(equip) do
        if owned[c] then ply:Give(c); lastW = c end
    end
    if not lastW then ply:Give("weapon_pistol"); ply:GiveAmmo(60, "Pistol", true)
    else timer.Simple(0.1, function() if IsValid(ply) then ply:SelectWeapon(lastW) end end) end
    if ply:IsAdmin() or ply:IsListenServerHost() then ply:Give("weapon_physgun"); ply:Give("gmod_tool") end

    net.Start("ConfirmDeploy"); net.Send(ply)
end
net.Receive("DeployPlayer", function(_,ply) DoDeploy(ply) end)

hook.Add("PlayerSay","CombinedChatCommands", function(ply,txt)
    if string.lower(txt) == "!deploy" then DoDeploy(ply); return "" end
end)

hook.Add("PlayerDisconnected","ClearInv", function(ply)
    PlayerDeathInventories[ply:UniqueID()] = nil
end)
