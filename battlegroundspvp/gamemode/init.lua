-- Server-side file: init.lua
-- Version: v1.25 (Restored Lock on First Spawn Only) - Corrected

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")
-- Make sure your entity files are correctly placed in 'gamemodes/battlegroundspvp/entities/'
-- DO NOT include the entity's init.lua here. The engine loads entities automatically.

-- Network Strings
util.AddNetworkString("DeployPlayer")
util.AddNetworkString("SafeTeleportCountdown")
util.AddNetworkString("ConfirmDeploy")
util.AddNetworkString("RequestDeployMenu") -- Note: This wasn't used in cl_init, but defined here. Keep or remove as needed.

-- Position Constants (Made Global for easier access by entities)
-- Ensure these coordinates are correct for your map ('gm_battlegrounds' perhaps?)
INITIAL_SPAWN_POS   = Vector(1819.304443,  136.818985, -11896.761719)
INITIAL_SPAWN_ANGLE = Angle(  40.641457, -179.751663,   0.000000)
SAFE_SPAWN_POS      = Vector(2127.101318,  168.765152, -12432.550781)
SAFE_SPAWN_ANGLE    = Angle(-1.242542, -178.839386,   0.000000)
PVP_SPAWNS          = {
    Vector(-2121.186279,-2410.672119,-14511.968750),
    Vector(-3729.331543,-1272.942993,-14511.968750),
    Vector(-3751.061279,1314.375854,-14511.968750),
    Vector(-1464.063354,2510.692139,-14511.968750),
    Vector(-464.353790,973.957520,-14511.968750)
}

-- Weapon Shop Integration Placeholder
-- NOTE: Ensure your weapon shop system correctly populates _G.WeaponShopEquipped[SteamID] = { "weapon_class_1", "weapon_class_2", ... }
_G.WeaponShopEquipped = _G.WeaponShopEquipped or {} -- Ensure the table exists globally

-- << Preset Reminder Configuration >> --
local PRESET_REMINDER_INTERVAL = 480 -- seconds (8 minutes)
local PRESET_REMINDER_PREFIX   = "[TIP]"
local COLOR_PREFIX    = Color(100, 150, 255)
local COLOR_MESSAGE   = Color(255, 255, 255)
local COLOR_KEYS      = Color(255, 255, 100)
local PRESET_MESSAGE_PARTS = { COLOR_PREFIX, PRESET_REMINDER_PREFIX .. " ", COLOR_MESSAGE, "Remember to save weapon presets! Press ", COLOR_KEYS, "[C]", COLOR_MESSAGE, " then ", COLOR_KEYS, "[F3]", COLOR_MESSAGE, "." }
local function SendPresetReminder()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() then chat.AddText(ply, unpack(PRESET_MESSAGE_PARTS)) end
    end
end

-- Gamemode Initialization Hook
function GM:Initialize()
    -- Always call the base gamemode's Initialize function if deriving
    if self.BaseClass and self.BaseClass.Initialize then self.BaseClass.Initialize(self) end

    print("Server Initialized Gamemode: " .. (self.Name or "Unknown"))
    if timer.Exists("PresetReminderTimer") then timer.Remove("PresetReminderTimer") end
    timer.Create("PresetReminderTimer", PRESET_REMINDER_INTERVAL, 0, SendPresetReminder)
end

-- Shared admin check function
local function IsPrivileged(p)
    return IsValid(p) and (p:IsAdmin() or p:IsListenServerHost())
end

-- PlayerInitialSpawn Hook
function GM:PlayerInitialSpawn(ply)
    -- Always call the base gamemode's function if deriving
    if self.BaseClass and self.BaseClass.PlayerInitialSpawn then self.BaseClass.PlayerInitialSpawn(self, ply) end

    -- Initialize custom variables
    ply.InSafeZone = false -- Using a standard Lua variable server-side
    ply.HasSpawnedBefore = false
    ply.NextSafeTeleportTime = 0 -- Initialize cooldown timer
end

-- PlayerSpawn Hook
function GM:PlayerSpawn(ply)
    -- Always call the base gamemode's function if deriving
    if self.BaseClass and self.BaseClass.PlayerSpawn then self.BaseClass.PlayerSpawn(self, ply) end

    -- Set basic player properties
    ply:SetModel("models/player/group01/male_01.mdl") -- Consider making this configurable or using player model selectors
    ply:SetWalkSpeed(200)
    ply:SetRunSpeed(400)
    ply:SetJumpPower(200)

    local sid = ply:SteamID() -- Get SteamID once

    if not ply.HasSpawnedBefore then -- First Spawn Logic
        ply.HasSpawnedBefore = true
        ply:StripWeapons()
        ply:SetPos(INITIAL_SPAWN_POS)
        ply:SetEyeAngles(INITIAL_SPAWN_ANGLE)
        ply:SetNWBool("InSafeZone", true) -- Network to client
        ply.InSafeZone = true -- Update server-side variable
        ply:Lock() -- <<< RESTORED: Lock player ONLY on initial spawn
        if IsPrivileged(ply) then ply:Give("weapon_physgun"); ply:Give("gmod_tool") end
        print("[Spawn] First spawn setup for: " .. ply:Nick())
        -- Maybe open deploy menu automatically here via network message?
        return -- Important: Return after setting up initial spawn
    end

    -- Subsequent Spawns Logic (Needs slight delay to ensure physics are ready)
    timer.Simple(0.01, function()
        if not IsValid(ply) then return end -- Player might disconnect

        ply:StripWeapons() -- Strip weapons regardless of spawn location first

        if ply:GetNWBool("InSafeZone", false) then -- Check Networked Var for current state (may have changed via commands)
             -- Safe Zone Spawn
             ply:SetPos(SAFE_SPAWN_POS)
             ply:SetEyeAngles(SAFE_SPAWN_ANGLE)
             -- ply:Lock() -- Stays REMOVED: Don't lock player on subsequent safe zone spawns
             if IsPrivileged(ply) then ply:Give("weapon_physgun"); ply:Give("gmod_tool") end
        else
             -- PvP Zone Spawn
             local chosen = table.Random(PVP_SPAWNS)
             ply:SetPos(chosen)
             ply:SetEyeAngles(Angle(0, math.random(0, 360), 0))
             ply:UnLock() -- Ensure player is unlocked when spawning in PvP
             ply:SetNWBool("InSafeZone", false) -- Ensure client knows they are not safe

             -- Give Weapons based on _G.WeaponShopEquipped
             local equippedList = _G.WeaponShopEquipped and _G.WeaponShopEquipped[sid]
             local gaveWeapon = false
             if equippedList and #equippedList > 0 then
                 for _, wepClass in ipairs(equippedList) do
                     if wepClass and type(wepClass) == "string" and string.len(wepClass) > 0 then
                         ply:Give(wepClass)
                         gaveWeapon = true
                     else
                         print("[Spawn Warn] Skipping invalid equipped entry for " .. ply:Nick() .. ":", wepClass)
                     end
                 end
             end

             -- Give default pistol if nothing else was given
             if not gaveWeapon then
                 ply:Give("weapon_pistol")
                 ply:GiveAmmo(60, "Pistol", true) -- Ensure ammo is given
             end

             -- Give admin tools
             if IsPrivileged(ply) then ply:Give("weapon_physgun"); ply:Give("gmod_tool") end

             -- Temporary God Mode
             ply:GodEnable()
             timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end)
        end
    end)
end

-- Deploy Function (Called by Deploy Menu, !deploy command, and NPC)
local function DoDeploy(ply)
    if not IsValid(ply) or not ply:Alive() then return end -- Check if player is valid and alive

    print("[Deploy] Player " .. ply:Nick() .. " deploying.")

    -- Update state
    ply.InSafeZone = false -- Server variable
    ply:SetNWBool("InSafeZone", false) -- Network to client
    ply:UnLock() -- *** IMPORTANT: Keep this Unlock call when DEPLOYING ***

    -- Teleport to random PvP spawn
    local chosen = table.Random(PVP_SPAWNS)
    ply:SetPos(chosen)
    ply:SetEyeAngles(Angle(0, math.random(0, 360), 0))

    -- Temporary God Mode
    ply:GodEnable()
    timer.Simple(2.5, function() if IsValid(ply) then ply:GodDisable() end end)

    -- Handle Weapons
    ply:StripWeapons()
    local sid = ply:SteamID()
    local equippedList = _G.WeaponShopEquipped and _G.WeaponShopEquipped[sid]
    local gaveWeapon = false

    if equippedList and #equippedList > 0 then
        for _, wepClass in ipairs(equippedList) do
            if wepClass and type(wepClass) == "string" and string.len(wepClass) > 0 then
                ply:Give(wepClass)
                gaveWeapon = true
            else
                print("[Deploy Warn] Skipping invalid equipped entry for " .. ply:Nick() .. ":", wepClass)
            end
        end
    end

    -- Give default pistol if nothing else was given
    if not gaveWeapon then
        timer.Simple(0.1, function() -- Slight delay helps sometimes
            if IsValid(ply) then
                ply:Give("weapon_pistol")
                ply:GiveAmmo(60, "Pistol", true)
            end
        end)
    end

    -- Give admin tools (with slight delay)
    if IsPrivileged(ply) then
        timer.Simple(0.2, function()
            if IsValid(ply) then
                ply:Give("weapon_physgun")
                ply:Give("gmod_tool")
            end
        end)
    end

    -- Send confirmation message to client HUD
    net.Start("ConfirmDeploy")
    net.Send(ply)
end

-- Network Receiver for Deploy Menu button press
net.Receive("DeployPlayer", function(_, ply)
    -- Add checks here: e.g., ensure player is in safe zone before deploying?
    if IsValid(ply) and ply:GetNWBool("InSafeZone", true) then -- Only allow deploy from safe zone?
         DoDeploy(ply)
    elseif IsValid(ply) then
         ply:ChatPrint("You can only deploy from the Safe Zone or using !deploy.")
    end
end)


-- Chat Commands Hook (!deploy, !safe, !forcesafe)
hook.Add("PlayerSay", "CombinedChatCommands", function(ply, text, teamChat)
    if not IsValid(ply) then return nil end -- Ignore if player is invalid

    local lowerText = string.lower(text)

    -- Standard !deploy command
    if lowerText == "!deploy" or lowerText == "/deploy" then
        if ply:GetNWBool("InSafeZone", false) then -- Check if already NOT in safe zone
            ply:ChatPrint("You are already deployed!")
        else
            DoDeploy(ply) -- Allow deploy from anywhere via command? Or add zone check?
        end
        return "" -- Hide command from chat
    end

    -- Standard !safe command
    if lowerText == "!safe" or lowerText == "/safe" then
        if ply:GetNWBool("InSafeZone", true) then -- Use NWVar for check, assuming it's reliable
            ply:ChatPrint("[SAFEZONE] You are already in the Safe Zone!")
            return "" -- Hide command
        end

        -- Check cooldown (using server-side variable)
        if ply.NextSafeTeleportTime and ply.NextSafeTeleportTime > CurTime() then
             local waitTime = math.ceil(ply.NextSafeTeleportTime - CurTime())
             ply:ChatPrint("[SAFEZONE] Command on cooldown! Wait " .. waitTime .. "s")
             return "" -- Hide command
        end

        ply:ChatPrint("[SAFEZONE] Teleporting to Safe Zone in 4 seconds... Don't move!")
        net.Start("SafeTeleportCountdown"); net.Send(ply) -- Tell client to show countdown HUD
        local startPos = ply:GetPos() -- Store position BEFORE timer starts

        timer.Simple(4, function()
            if not IsValid(ply) or not ply:Alive() then return end -- Check player validity again

            local currentPos = ply:GetPos()
            local distanceMoved = currentPos:Distance(startPos)

            if distanceMoved > 50 then -- Check if player moved too far
                ply:ChatPrint("[SAFEZONE] Teleport cancelled: You moved too much!")
                ply.NextSafeTeleportTime = CurTime() + 10 -- Short cooldown after cancelling
                return -- Stop the teleport
            end

            -- Player didn't move, proceed with teleport
            print("[SafeZone] " .. ply:Nick() .. " teleported to safe zone via !safe.")
            ply.InSafeZone = true -- Server variable
            ply.NextSafeTeleportTime = CurTime() + 120 -- Set the cooldown AFTER successful teleport

            ply:SetPos(SAFE_SPAWN_POS)
            ply:SetEyeAngles(SAFE_SPAWN_ANGLE)
            ply:SetNWBool("InSafeZone", true) -- Network to client
            -- ply:Lock() -- Stays REMOVED: Don't lock player after using !safe
            ply:StripWeapons()

            -- Give admin tools
            if IsPrivileged(ply) then
                ply:Give("weapon_physgun")
                ply:Give("gmod_tool")
            end

            ply:ChatPrint("[SAFEZONE] You have arrived safely.")
        end)

        return "" -- Hide command
    end

    -- Admin Force Safe Command
    if lowerText == "!forcesafe" or lowerText == "/forcesafe" then
        if IsPrivileged(ply) then
            print("[Admin] " .. ply:Nick() .. " used !forcesafe.")
            ply.InSafeZone = true -- Server variable
            ply.NextSafeTeleportTime = CurTime() -- Reset cooldown for admin

            ply:SetPos(SAFE_SPAWN_POS)
            ply:SetEyeAngles(SAFE_SPAWN_ANGLE)
            ply:SetNWBool("InSafeZone", true) -- Network to client
            -- ply:Lock() -- Stays REMOVED: Don't lock player after using !forcesafe
            ply:StripWeapons()
            ply:Give("weapon_physgun")
            ply:Give("gmod_tool")
            ply:ChatPrint("[ADMIN] Forced teleport to Safe Zone (cooldown bypassed).")
        else
            ply:ChatPrint("You do not have permission to use this command.")
        end
        return "" -- Hide command
    end

    return nil -- Let other hooks handle the chat message if it wasn't one of ours
end)

-- Admin Checks and Permissions (Using shared IsPrivileged function)
function GM:CanTool(ply, trace, mode) return IsPrivileged(ply) end
function GM:PlayerSpawnProp(ply, model) return IsPrivileged(ply) end
function GM:PlayerSpawnSWEP(ply, cls, dat) return IsPrivileged(ply) end
function GM:PlayerSpawnEffect(ply, mdl) return IsPrivileged(ply) end
function GM:PlayerSpawnRagdoll(ply, mdl) return IsPrivileged(ply) end
function GM:PlayerSpawnSENT(ply, cls) return IsPrivileged(ply) end
function GM:PlayerSpawnVehicle(ply, m, c, t) return IsPrivileged(ply) end
function GM:AllowPlayerSpawn(ply) return IsPrivileged(ply) end -- Controls ability to spawn at all via spawnmenu?

-- PlayerCanUseWeapon Hook
hook.Add("PlayerCanUseWeapon", "RestrictWeaponsInSafeZone", function(ply, wep)
    if not IsValid(ply) or not IsValid(wep) then return nil end -- Allow default behavior if invalid

    local wepClass = wep:GetClass()
    local isPrivileged = IsPrivileged(ply)

    -- Allow admins to use tools/physgun always
    if (wepClass == "gmod_tool" or wepClass == "weapon_physgun") then
        return isPrivileged
    end

    -- Check if player is in safe zone (use NWBool as it reflects client state too)
    if ply:GetNWBool("InSafeZone", false) then
        ply:ChatPrint("You cannot use weapons in the safe zone.")
        return false -- Prevent use
    end

    return true -- Allow use if not in safe zone and not a restricted tool
end)

-- Disconnect Hook
hook.Add("PlayerDisconnected", "ClearInventoryOnLeave", function(ply)
    print("[Player] Disconnected: " .. ply:Nick())
    -- Clear saved weapon data? (_G.WeaponShopEquipped[ply:SteamID()] = nil) ? Depends on your persistence needs.
end)

-- Gamemode Shutdown Hook
function GM:ShutDown() -- Line ~328
    if timer.Exists("PresetReminderTimer") then timer.Remove("PresetReminderTimer") end
    if self.BaseClass and self.BaseClass.ShutDown then self.BaseClass.ShutDown(self) end
    print("Gamemode ShutDown.")
end -- Closing end for GM:ShutDown

-- Final server loaded message
print("Military Gamemode - init.lua loaded (Server - v1.25 - Restored Lock on First Spawn)")