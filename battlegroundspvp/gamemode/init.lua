-- Server-side file: init.lua
-- Version: v1.32 (PvP NPC with animation persistence - File saving fixed)
-- Updated: 2025-05-05 14:45:27 by JamieL25

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Network Strings
util.AddNetworkString("DeployPlayer")
util.AddNetworkString("SafeTeleportCountdown")
util.AddNetworkString("ConfirmDeploy")
util.AddNetworkString("RequestDeployMenu")

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
local PRESET_MESSAGE_PARTS = { COLOR_PREFIX, PRESET_REMINDER_PREFIX .. " ", COLOR_MESSAGE, "Remember to save weapon presets! Press ", COLOR_KEYS, "[C]", COLOR_MESSAGE, " then ", COLOR_KEYS, "[F3]" }
local function SendPresetReminder()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsPlayer() then chat.AddText(ply, unpack(PRESET_MESSAGE_PARTS)) end
    end
end

-- Global function to set animation sequence for all NPCs and save it for persistence
function SetNPCAnimationSequence(seqNumber)
    -- Update the global sequence number
    local animNumber = tonumber(seqNumber) or 4  -- Default to sequence 4 if invalid
    
    -- Apply to all existing NPCs
    local count = 0
    for _, ent in ipairs(ents.FindByClass("npcpvpteleporter")) do
        if IsValid(ent) then
            ent:ResetSequence(animNumber)
            count = count + 1
        end
    end
    
    -- Save the sequence number to file for persistence
    if count > 0 then
        -- Create the data directory if it doesn't exist
        if not file.Exists("battlegroundspvp", "DATA") then
            file.CreateDir("battlegroundspvp")
        end
        
        -- Save sequence
        file.Write("battlegroundspvp/npc_anim.txt", tostring(animNumber))
        print("[NPC] Animation sequence " .. animNumber .. " saved to data/battlegroundspvp/npc_anim.txt")
    end
    
    print("[NPC] Animation sequence " .. animNumber .. " set on " .. count .. " NPCs")
    return animNumber
end

-- Shared admin check function
local function IsPrivileged(p)
    return IsValid(p) and (p:IsAdmin() or p:IsListenServerHost())
end

-- Gamemode Initialization Hook
function GM:Initialize()
    -- Always call the base gamemode's Initialize function if deriving
    if self.BaseClass and self.BaseClass.Initialize then self.BaseClass.Initialize(self) end

    print("Server Initialized Gamemode: " .. (self.Name or "Unknown"))
    if timer.Exists("PresetReminderTimer") then timer.Remove("PresetReminderTimer") end
    timer.Create("PresetReminderTimer", PRESET_REMINDER_INTERVAL, 0, SendPresetReminder)
    
    -- Create the data directory for persistence if it doesn't exist
    if not file.Exists("battlegroundspvp", "DATA") then
        file.CreateDir("battlegroundspvp")
        print("[SERVER] Created data directory: data/battlegroundspvp")
    end
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
-- Important: Make this function global so the NPC entity can call it
function DoDeploy(ply)
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

-- Export the DoDeploy function globally so the NPC entity can use it
_G.DoDeploy = DoDeploy

-- Export the SetNPCAnimationSequence function globally
_G.SetNPCAnimationSequence = SetNPCAnimationSequence

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
        if not ply:GetNWBool("InSafeZone", true) then -- Check if already NOT in safe zone
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

    -- Command to spawn NPC
    if lowerText == "!spawnnpc" or lowerText == "/spawnnpc" then
        if IsPrivileged(ply) then
            -- Try to spawn the NPC
            local ent = ents.Create("npcpvpteleporter")
            if IsValid(ent) then
                -- Set position near the player
                local tr = util.TraceLine({
                    start = ply:EyePos(),
                    endpos = ply:EyePos() + ply:EyeAngles():Forward() * 200,
                    filter = ply
                })
                
                local spawnPos = tr.HitPos + Vector(0, 0, 10)  -- Slightly above surface
                local spawnAng = Angle(0, ply:EyeAngles().y - 180, 0)  -- Face the player
                
                ent:SetPos(spawnPos)
                ent:SetAngles(spawnAng)
                ent:Spawn()
                
                -- Load saved animation if exists
                if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                    local seqNumber = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
                    if seqNumber and seqNumber > 0 then
                        ent:ResetSequence(seqNumber)
                        ply:ChatPrint("NPC spawned with saved animation: " .. seqNumber)
                    end
                else
                    -- Default to animation sequence 4
                    ent:ResetSequence(4)
                    ply:ChatPrint("NPC spawned with default animation")
                end
                
                ply:ChatPrint("[ADMIN] PvP Teleporter NPC spawned successfully!")
                print("[ADMIN] " .. ply:Nick() .. " spawned a PvP Teleporter NPC at " .. tostring(spawnPos))
            else
                ply:ChatPrint("[ERROR] Failed to create PvP Teleporter NPC!")
                print("[ERROR] Failed to create PvP Teleporter NPC for " .. ply:Nick())
            end
        else
            ply:ChatPrint("You do not have permission to use this command.")
        end
        return "" -- Hide command
    end
    
    -- Command to teleport to NPC
    if lowerText == "!gotopvpnpc" or lowerText == "/gotopvpnpc" then
        if IsPrivileged(ply) then
            -- Find the nearest NPC
            local closestNPC = nil
            local closestDist = 99999999
            
            for _, ent in ipairs(ents.FindByClass("npcpvpteleporter")) do
                if IsValid(ent) then
                    local dist = ent:GetPos():DistToSqr(ply:GetPos())
                    if dist < closestDist then
                        closestNPC = ent
                        closestDist = dist
                    end
                end
            end
            
            if IsValid(closestNPC) then
                -- Teleport to the NPC position with slight offset
                local npcPos = closestNPC:GetPos() + Vector(0, 0, 5)
                local lookAngle = closestNPC:GetAngles()
                
                -- Save the player's current position for returning
                ply.LastPosition = ply:GetPos()
                ply.LastAngle = ply:EyeAngles()
                
                ply:SetPos(npcPos)
                ply:SetEyeAngles(lookAngle)
                ply:ChatPrint("[ADMIN] Teleported to PvP NPC")
                print("[ADMIN] " .. ply:Nick() .. " teleported to PvP NPC at " .. tostring(npcPos))
            else
                -- No NPC found, create one and teleport to it
                local newNPC = ents.Create("npcpvpteleporter")
                if IsValid(newNPC) then
                    local npcPos = Vector(1915.832886, -180.473587, -12432.552734)
                    local npcAng = Angle(3.267001, 88.209541, 0.000000)
                    
                    newNPC:SetPos(npcPos)
                    newNPC:SetAngles(npcAng)
                    newNPC:Spawn()
                    
                    -- Load saved animation if exists
                    if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                        local seqNumber = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
                        if seqNumber and seqNumber > 0 then
                            newNPC:ResetSequence(seqNumber)
                        end
                    else
                        -- Default to animation sequence 4
                        newNPC:ResetSequence(4)
                    end
                    
                    -- Save player's current position
                    ply.LastPosition = ply:GetPos()
                    ply.LastAngle = ply:EyeAngles()
                    
                    -- Teleport to the NPC
                    ply:SetPos(npcPos + Vector(0, 0, 5))
                    ply:SetEyeAngles(npcAng)
                    ply:ChatPrint("[ADMIN] Created and teleported to PvP NPC")
                    print("[ADMIN] " .. ply:Nick() .. " created and teleported to PvP NPC at " .. tostring(npcPos))
                else
                    ply:ChatPrint("[ERROR] Failed to create PvP NPC")
                end
            end
        else
            ply:ChatPrint("You don't have permission to use this command.")
        end
        return ""
    end
    
    -- Return to previous position command
    if lowerText == "!goback" or lowerText == "/goback" then
        if IsPrivileged(ply) and ply.LastPosition then
            ply:SetPos(ply.LastPosition)
            ply:SetEyeAngles(ply.LastAngle)
            ply:ChatPrint("[ADMIN] Returned to previous position")
            print("[ADMIN] " .. ply:Nick() .. " returned to previous position at " .. tostring(ply.LastPosition))
        else
            ply:ChatPrint("No previous position saved or you don't have permission.")
        end
        return ""
    end

    -- Command to create NPC at current position
    if lowerText == "!npchere" or lowerText == "/npchere" then
        if IsPrivileged(ply) then
            -- Create a new NPC entity right where the player is standing
            local ent = ents.Create("npcpvpteleporter")
            if IsValid(ent) then
                -- Position the NPC exactly where the player is standing
                local playerPos = ply:GetPos()
                local playerAng = ply:GetAngles()
                
                -- Offset slightly so it doesn't overlap with the player
                local spawnPos = playerPos + Vector(0, 0, 10)
                
                ent:SetPos(spawnPos)
                ent:SetAngles(Angle(0, playerAng.y, 0))  -- Only use the yaw component
                ent:Spawn()
                
                -- Load saved animation if exists
                if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                    local seqNumber = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
                    if seqNumber and seqNumber > 0 then
                        ent:ResetSequence(seqNumber)
                        ply:ChatPrint("NPC created with saved animation: " .. seqNumber)
                    else
                        -- Default to animation sequence 4
                        ent:ResetSequence(4)
                    end
                else
                    -- Default to animation sequence 4
                    ent:ResetSequence(4)
                    ply:ChatPrint("NPC created with default animation (4)")
                end
                
                ply:ChatPrint("PvP NPC created right at your position!")
                
                -- Print the exact coordinates for reference
                local pos = ent:GetPos()
                ply:ChatPrint("NPC position: " .. math.floor(pos.x) .. ", " .. math.floor(pos.y) .. ", " .. math.floor(pos.z))
                print("[ADMIN] " .. ply:Nick() .. " created PvP NPC at " .. tostring(pos))
            else
                ply:ChatPrint("Failed to create NPC entity!")
            end
        else
            ply:ChatPrint("You don't have permission to use this command.")
        end
        return ""
    end
    
    -- NPC Animation command - improved version
    if string.sub(lowerText, 1, 9) == "!npcanim " then
        if IsPrivileged(ply) then
            local animNumber = tonumber(string.sub(lowerText, 10)) or 4
            
            -- Use the global function
            local seq = SetNPCAnimationSequence(animNumber)
            ply:ChatPrint("[ADMIN] Set animation " .. seq .. " on all NPCs and saved for persistence")
            ply:ChatPrint("[ADMIN] File saved to: data/battlegroundspvp/npc_anim.txt")
            print("[ADMIN] " .. ply:Nick() .. " set animation " .. seq .. " on all NPCs")
            
            -- Try a wide range of animations if the user entered "test"
            if string.sub(lowerText, 10) == "test" then
                ply:ChatPrint("Testing sequence range 1-15, check results...")
                
                for i = 1, 15 do
                    timer.Simple(i * 1.5, function()
                        if IsValid(ply) then
                            SetNPCAnimationSequence(i)
                            ply:ChatPrint("Testing animation " .. i .. "...")
                        end
                    end)
                end
            end
        else
            ply:ChatPrint("You don't have permission to use this command.")
        end
        return ""
    end
    
    -- NPC Debug command
    if lowerText == "!npcdebug" or lowerText == "/npcdebug" then
        if IsPrivileged(ply) then
            -- Find an NPC to debug
            local debugNPC = nil
            for _, ent in ipairs(ents.FindByClass("npcpvpteleporter")) do
                if IsValid(ent) then
                    debugNPC = ent
                    break
                end
            end
            
            if IsValid(debugNPC) then
                local currentSeq = debugNPC:GetSequence()
                local seqName = debugNPC:GetSequenceName(currentSeq)
                
                ply:ChatPrint("NPC Info:")
                ply:ChatPrint("- Current Sequence: " .. currentSeq .. " (" .. (seqName or "unknown") .. ")")
                ply:ChatPrint("- Model: " .. debugNPC:GetModel())
                
                -- Check if saved animation exists
                if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                    local savedSeq = file.Read("battlegroundspvp/npc_anim.txt", "DATA")
                    ply:ChatPrint("- Saved animation: " .. savedSeq)
                    ply:ChatPrint("- File location: data/battlegroundspvp/npc_anim.txt")
                else
                    ply:ChatPrint("- No saved animation found")
                    ply:ChatPrint("- Use !npcanim to set a persistent animation")
                end
                
                -- List some sequences
                ply:ChatPrint("Common sequences:")
                for i=1, 10 do
                    local name = debugNPC:GetSequenceName(i)
                    if name and name ~= "" then
                        ply:ChatPrint("  " .. i .. ": " .. name)
                    end
                end
                
                print("[ADMIN] " .. ply:Nick() .. " debugged NPC animations")
            else
                ply:ChatPrint("No NPCs found to debug")
            end
        else
            ply:ChatPrint("You don't have permission to use this command.")
        end
        return ""
    end
    
    -- Special animation test command
    if lowerText == "!npcfix" or lowerText == "/npcfix" then
        if IsPrivileged(ply) then
            local count = 0
            for _, ent in ipairs(ents.FindByClass("npcpvpteleporter")) do
                if IsValid(ent) then
                    -- Try default pose parameters
                    ent:SetPoseParameter("move_x", 0)
                    ent:SetPoseParameter("move_y", 0)
                    ent:SetPoseParameter("aim_pitch", 0)
                    ent:SetPoseParameter("aim_yaw", 0)
                    
                    -- Load saved animation if exists, otherwise use default (4)
                    local seqNumber = 4
                    if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                        local savedSeq = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
                        if savedSeq and savedSeq > 0 then
                            seqNumber = savedSeq
                        end
                    end
                    
                    ent:ResetSequence(seqNumber)
                    count = count + 1
                end
            end
            
            ply:ChatPrint("Fixed " .. count .. " NPCs with saved animation")
            print("[ADMIN] " .. ply:Nick() .. " fixed " .. count .. " NPCs with !npcfix")
        else
            ply:ChatPrint("You don't have permission to use this command.")
        end
        return ""
    end
    
    -- File test command
    if lowerText == "!filetest" or lowerText == "/filetest" then
        if IsPrivileged(ply) then
            -- Create the directory if it doesn't exist
            if not file.Exists("battlegroundspvp", "DATA") then
                file.CreateDir("battlegroundspvp")
                ply:ChatPrint("Created directory: data/battlegroundspvp")
            else
                ply:ChatPrint("Directory already exists: data/battlegroundspvp")
            end
            
            -- Write a test file
            file.Write("battlegroundspvp/test.txt", "Test file created at " .. os.date("%Y-%m-%d %H:%M:%S"))
            ply:ChatPrint("Wrote test file to: data/battlegroundspvp/test.txt")
            
            -- Check if our animation file exists
            if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                local content = file.Read("battlegroundspvp/npc_anim.txt", "DATA")
                ply:ChatPrint("npc_anim.txt exists with content: " .. content)
            else
                ply:ChatPrint("npc_anim.txt does not exist yet")
                ply:ChatPrint("Use !npcanim <number> to create it")
            end
            
            -- List all files in the data directory
            local files = file.Find("battlegroundspvp/*", "DATA")
            ply:ChatPrint("Files in data/battlegroundspvp:")
            for _, f in ipairs(files) do
                ply:ChatPrint("- " .. f)
            end
            
            print("[ADMIN] " .. ply:Nick() .. " ran file system test")
        else
            ply:ChatPrint("You don't have permission to use this command.")
        end
        return ""
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
function GM:ShutDown()
    if timer.Exists("PresetReminderTimer") then timer.Remove("PresetReminderTimer") end
    if self.BaseClass and self.BaseClass.ShutDown then self.BaseClass.ShutDown(self) end
    print("Gamemode ShutDown.")
end

-- Hook to ensure our NPC spawns properly with the fixed PMC model
hook.Add("InitPostEntity", "SpawnPvPTeleporter", function()
    print("[SERVER] Attempting to spawn PvP Teleporter NPC...")
    
    -- Create data directory if it doesn't exist
    if not file.Exists("battlegroundspvp", "DATA") then
        file.CreateDir("battlegroundspvp")
        print("[SERVER] Created data directory: data/battlegroundspvp")
    end
    
    -- Fixed PMC model
    local modelPath = "models/player/PMC_1/PMC__01.mdl"
    
    -- Wait a moment for the map to fully load
    timer.Simple(5, function()
        -- Attempt to create the entity
        local ent = ents.Create("npcpvpteleporter")
        if IsValid(ent) then
            local npcPos = Vector(1915.832886, -180.473587, -12432.552734)
            local npcAng = Angle(3.267001, 88.209541, 0.000000)
            
            ent:SetPos(npcPos)
            ent:SetAngles(npcAng)
            
            -- Set the model before spawning
            ent:SetModel(modelPath)
            
            ent:Spawn()
            
            -- Load saved animation sequence if exists
            if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
                local seqNumber = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
                if seqNumber and seqNumber > 0 then
                    ent:ResetSequence(seqNumber)
                    print("[SERVER] Loaded saved animation for NPC: " .. seqNumber)
                else
                    -- Default to sequence 4 if saved value is invalid
                    ent:ResetSequence(4)
                    print("[SERVER] Using default animation for NPC (sequence 4)")
                end
            else
                -- No saved animation, use default
                ent:ResetSequence(4)
                print("[SERVER] Using default animation for NPC (sequence 4)")
            end
            
            print("[SERVER] Successfully spawned PvP Teleporter NPC at " .. tostring(npcPos))
        else
            print("[SERVER ERROR] Failed to create PvP Teleporter NPC!")
        end
    end)
end)

-- Console command to spawn NPC manually
concommand.Add("spawnpvpnpc", function(ply)
    -- Check if player is privileged (admin or listen server host)
    if IsValid(ply) and not (ply:IsAdmin() or ply:IsListenServerHost()) then
        ply:ChatPrint("You don't have permission to use this command")
        return
    end
    
    -- Create the NPC entity
    local ent = ents.Create("npcpvpteleporter")
    if IsValid(ent) then
        -- Set position based on player's view or predefined location
        local spawnPos
        local spawnAng
        
        if IsValid(ply) then
            local tr = util.TraceLine({
                start = ply:EyePos(),
                endpos = ply:EyePos() + ply:EyeAngles():Forward() * 200,
                filter = ply
            })
            
            spawnPos = tr.HitPos + Vector(0, 0, 10)  -- Slightly above surface
            spawnAng = Angle(0, ply:EyeAngles().y - 180, 0)  -- Face the player
        else
            -- Default position if called from server console
            spawnPos = Vector(1915.832886, -180.473587, -12432.552734)
            spawnAng = Angle(3.267001, 88.209541, 0.000000)
        end
        
        -- Set the fixed PMC model
        ent:SetModel("models/player/PMC_1/PMC__01.mdl")
        
        ent:SetPos(spawnPos)
        ent:SetAngles(spawnAng)
        ent:Spawn()
        
        -- Load saved animation if exists
        if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
            local seqNumber = tonumber(file.Read("battlegroundspvp/npc_anim.txt", "DATA"))
            if seqNumber and seqNumber > 0 then
                ent:ResetSequence(seqNumber)
                if IsValid(ply) then
                    ply:ChatPrint("NPC created with saved animation: " .. seqNumber)
                end
            else
                -- Default to sequence 4
                ent:ResetSequence(4)
            end
        else
            -- Default to sequence 4
            ent:ResetSequence(4)
        end
        
        if IsValid(ply) then
            ply:ChatPrint("PvP Teleporter NPC spawned successfully")
        end
        print("[SERVER] PvP Teleporter NPC manually spawned at " .. tostring(spawnPos))
    else
        if IsValid(ply) then
            ply:ChatPrint("Failed to create PvP Teleporter NPC")
        end
        print("[SERVER ERROR] Failed to manually create PvP Teleporter NPC!")
    end
end, nil, "Spawns a PvP Teleporter NPC", FCVAR_CHEAT)

-- Console command to test different animations for the NPC
concommand.Add("npc_anim", function(ply, cmd, args)
    -- Check if player is privileged
    if IsValid(ply) and not IsPrivileged(ply) then
        ply:ChatPrint("You don't have permission to use this command")
        return
    end
    
    -- Get animation number from args
    local animNumber = tonumber(args[1]) or 4
    
    -- Update all NPCs using the global function and save to file
    local seq = SetNPCAnimationSequence(animNumber)
    
    -- Notify user
    local message = "All NPCs now using animation sequence " .. seq .. " (saved for persistence)"
    print("[ANIM] " .. message)
    if IsValid(ply) then 
        ply:PrintMessage(HUD_PRINTCONSOLE, message)
        ply:ChatPrint("Animation #" .. seq .. " applied to all NPCs and saved")
        ply:ChatPrint("File saved to: data/battlegroundspvp/npc_anim.txt")
    end
    
    -- List sequences command
    if args[1] == "list" or args[1] == "dump" then
        -- Create a temporary entity to check sequences
        local tempNPC = ents.Create("npcpvpteleporter")
        if IsValid(tempNPC) then
            tempNPC:SetModel("models/player/PMC_1/PMC__01.mdl")
            
            -- Dump sequence info to console
            print("[ANIM DUMP] --- Sequence Info for PMC_1 Model ---")
            print("Total Sequences: " .. (tempNPC:GetSequenceCount() or "unknown"))
            
            -- Try each sequence number and print its name if it exists
            for i=0, 100 do
                local name = tempNPC:GetSequenceName(i)
                if name and name ~= "" then
                    local info = "Sequence #" .. i .. " = " .. name
                    print(info)
                    if IsValid(ply) then
                        ply:PrintMessage(HUD_PRINTCONSOLE, info)
                        -- Also send to chat for better visibility
                        if i % 5 == 0 or i < 10 then -- Only send some to avoid spam
                            ply:ChatPrint("Seq " .. i .. ": " .. name)
                        end
                    end
                end
            end
            
            -- Clean up the temporary entity
            tempNPC:Remove()
            
            -- Inform player where to find results
            if IsValid(ply) then
                ply:ChatPrint("Animation list printed to console (~ key)")
                ply:ChatPrint("Try animations 1, 2, 4, 6, 9, or 12")
            end
        else
            print("[ANIM ERROR] Failed to create temporary entity for sequence listing")
            if IsValid(ply) then ply:ChatPrint("Failed to list animations") end
        end
    end
    
    -- Animation test cycle
    if args[1] == "test" then
        if IsValid(ply) then
            ply:ChatPrint("Testing animation sequences 1-10...")
            
            for i=1, 10 do
                timer.Simple(i * 1.5, function()
                    if IsValid(ply) then
                        SetNPCAnimationSequence(i)
                        ply:ChatPrint("Testing animation " .. i .. "...")
                    end
                end)
            end
        end
    end
end, nil, "Test different animations for the PvP Teleporter NPC\nUsage: npc_anim <number>\nnpc_anim list - Lists available animations\nnpc_anim test - Cycles through animations", FCVAR_CHEAT)

-- Console command to test file system
concommand.Add("test_npc_file", function(ply)
    -- Check if player is privileged
    if IsValid(ply) and not IsPrivileged(ply) then
        ply:ChatPrint("You don't have permission to use this command")
        return
    end
    
    -- Create the directory if it doesn't exist
    if not file.Exists("battlegroundspvp", "DATA") then
        file.CreateDir("battlegroundspvp")
        print("[TEST] Created directory: data/battlegroundspvp")
    else
        print("[TEST] Directory already exists: data/battlegroundspvp")
    end
    
    -- Write a test file
    file.Write("battlegroundspvp/test.txt", "Test file created at " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("[TEST] Wrote test file to data/battlegroundspvp/test.txt")
    
    -- Check if our animation file exists
    if file.Exists("battlegroundspvp/npc_anim.txt", "DATA") then
        local content = file.Read("battlegroundspvp/npc_anim.txt", "DATA")
        print("[TEST] npc_anim.txt exists with content: " .. content)
    else
        print("[TEST] npc_anim.txt does not exist")
    end
    
    -- List all files in the directory
    local files = file.Find("battlegroundspvp/*", "DATA")
    print("[TEST] Files in data/battlegroundspvp:")
    for _, f in ipairs(files) do
        print("- " .. f)
    end
    
    -- Return results to player
    if IsValid(ply) then
        ply:ChatPrint("Test complete - check console for results")
        ply:ChatPrint("Use !filetest for more detailed results")
    end
end)

-- Final server loaded message
print("Military Gamemode - init.lua loaded (Server - v1.32 - PvP NPC with animation persistence - File saving fixed - Updated 2025-05-05 14:45:27 by JamieL25)")