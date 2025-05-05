print(">>>> DEBUG: LOADING CORRECT npc_pvp_teleporter init.lua - v_DEBUG_01 <<<<") -- DEBUG LINE ADDED

-- File: gamemodes/battlegroundspvp/entities/npc_pvp_teleporter/init.lua (Server-Side) - DEBUG Version

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua") -- Include shared settings for the entity

-- Helper function to check admin status (can use global one if preferred and accessible)
local function IsPrivileged(p)
    return IsValid(p) and (p:IsAdmin() or p:IsListenServerHost())
end

-- Internal function to handle the teleportation logic for the NPC
local function TeleportToPVPFromNPC(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    print("[NPC Teleport] Player " .. ply:Nick() .. " deploying via NPC.")

    -- Update player state
    ply.InSafeZone = false -- Server variable
    ply:SetNWBool("InSafeZone", false) -- Network to client
    ply:UnLock() -- Ensure player can move after teleporting

    -- <<< Use global PVP_SPAWNS directly >>>
    -- Ensure PVP_SPAWNS is correctly defined in your main gamemode init.lua
    local pvpSpawnsTable = _G.PVP_SPAWNS -- Access global variable safely using _G
    local chosenSpawnPos

    if not pvpSpawnsTable or type(pvpSpawnsTable) ~= "table" or #pvpSpawnsTable == 0 then
         print("[NPC Teleport Error] Global PVP_SPAWNS not found, not a table, or empty! Using fallback Vector(0,0,0).")
         chosenSpawnPos = Vector(0, 0, 0) -- Fallback position
    else
        chosenSpawnPos = table.Random(pvpSpawnsTable)
    end

    ply:SetPos(chosenSpawnPos)
    ply:SetEyeAngles(Angle(0, math.random(0, 360), 0)) -- Random facing angle

    -- Temporary God Mode
    ply:GodEnable()
    timer.Simple(2.5, function()
        if IsValid(ply) then ply:GodDisable() end
    end)

    -- --- Handle Weapons ---
    ply:StripWeapons()
    local sid = ply:SteamID()
    -- <<< Use global _G.WeaponShopEquipped (Ensure it's populated) >>>
    local equippedList = _G.WeaponShopEquipped and _G.WeaponShopEquipped[sid]
    local gaveWeapon = false

    if equippedList and type(equippedList) == "table" and #equippedList > 0 then
        print("[NPC Teleport] Giving equipped weapons to " .. ply:Nick())
        for _, wepClass in ipairs(equippedList) do
            if wepClass and type(wepClass) == "string" and string.len(wepClass) > 0 then
                ply:Give(wepClass)
                gaveWeapon = true
            else
                print("[NPC Teleport Warn] Skipping invalid equipped entry for " .. ply:Nick() .. ":", wepClass)
            end
        end
    end

    -- Give default pistol if nothing else was given
    if not gaveWeapon then
        print("[NPC Teleport] No equipped found for " .. ply:Nick() .. ". Giving pistol.")
        timer.Simple(0.1, function() -- Slight delay
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
    -- --- End Weapon Handling ---

    -- Send confirmation message to client HUD
    net.Start("ConfirmDeploy")
    net.Send(ply)
    ply:ChatPrint("Teleported to the PvP Zone!")
end


-- Called when the entity is spawned on the server
function ENT:Initialize()
    print(">>>> DEBUG: ENT:Initialize called for npc_pvp_teleporter <<<<") -- DEBUG LINE ADDED
    -- Set the NPC model
    self:SetModel("models/player/PMC_2/PMC__01.mdl") -- Ensure this model exists

    -- Standard NPC setup
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:CapabilitiesAdd(CAP_USE)
    self:SetUseType(SIMPLE_USE)
    self:SetMaxHealth(1000)
    self:SetHealth(1000)
    self:SetBloodColor(DONT_BLEED)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:AddEFlags(EFL_NO_DAMAGE_FORCES)

    -- Set specific position/angles directly (Does NOT use GetSafeSpawnPos)
    local npcPos = Vector(1915.832886, -180.473587, -12432.552734)
    local npcAng = Angle(3.267001, 88.209541, 0.000000)

    self:SetPos(npcPos) -- This does NOT call GetSafeSpawnPos
    self:SetAngles(npcAng) -- This does NOT call GetSafeSpawnPos

    print(self.PrintName .. " NPC initialized at " .. tostring(npcPos))
    print(">>>> DEBUG: ENT:Initialize finished successfully <<<<") -- DEBUG LINE ADDED
end -- End of ENT:Initialize

-- Called when a player interacts ('Use') with the NPC
function ENT:AcceptInput(name, activator, caller, data)
    print(">>>> DEBUG: ENT:AcceptInput called with name: "..tostring(name).." <<<<") -- DEBUG LINE ADDED
    -- Only react to the 'Use' input from a valid player
    if name == "Use" and IsValid(activator) and activator:IsPlayer() then
        print("[NPC Use] ".. activator:Nick() .. " used the " .. self.PrintName)

        -- Check if the player is currently in the safe zone (using NW Bool)
        if activator:GetNWBool("InSafeZone", false) then
            activator:ChatPrint("Teleporting you to the battle...")
            TeleportToPVPFromNPC(activator) -- Use the specific NPC teleport function
        else
            activator:ChatPrint("You must be in the Safe Zone to use this teleporter.")
        end
        return true -- Indicate the input was handled
    end
    return false -- Input not handled
end

-- Override Think for static base_ai NPCs (keep empty for performance)
function ENT:Think()
   -- No logic needed here for a static NPC
end

-- Override damage function for invulnerability
function ENT:OnTakeDamage(dmginfo)
   -- Take no damage
   self:SetHealth(self:GetMaxHealth()) -- Keep health full just in case
   return false -- Prevent damage processing
end

print(">>>> DEBUG: FINISHED LOADING npc_pvp_teleporter init.lua - v_DEBUG_01 <<<<") -- DEBUG LINE ADDED