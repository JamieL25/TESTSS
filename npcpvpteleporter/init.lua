-- NPC PvP Teleporter Entity
-- init.lua - Server-side code
-- Updated: 2025-05-05 13:35:45 by JamieL25

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Fixed PMC model path
local NPC_MODEL = "models/player/PMC_1/PMC__01.mdl"

-- Store the current animation sequence for all NPCs
local CURRENT_SEQUENCE = 1

-- Initialize the NPC
function ENT:Initialize()
    -- Set up the entity with the fixed model
    self:SetModel(NPC_MODEL)
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    
    -- Add capabilities
    self:SetUseType(SIMPLE_USE)
    self:SetMaxHealth(1000)
    self:SetHealth(1000)
    
    -- Set initial animation sequence (use global current sequence)
    self:ResetSequence(CURRENT_SEQUENCE)
    
    -- Extra visibility settings
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:DrawShadow(true)
    
    -- Fix T-Pose by directly setting pose parameters
    self:SetPoseParameter("move_x", 0)
    self:SetPoseParameter("move_y", 0)
    self:SetPoseParameter("aim_pitch", 0)
    self:SetPoseParameter("aim_yaw", 0)
    
    print("[NPC] PvP Teleporter initialized at " .. tostring(self:GetPos()))
    print("[NPC] Using animation sequence: " .. CURRENT_SEQUENCE)
end

-- Handle ongoing animation
function ENT:Think()
    -- Keep the animation going
    self:SetPlaybackRate(1.0)
    
    -- Make sure we're using the globally set sequence
    if self:GetSequence() ~= CURRENT_SEQUENCE then
        self:ResetSequence(CURRENT_SEQUENCE)
    end
    
    -- Keep resetting pose parameters to prevent T-pose
    self:SetPoseParameter("move_x", 0)
    self:SetPoseParameter("move_y", 0)
    self:SetPoseParameter("aim_pitch", 0)
    self:SetPoseParameter("aim_yaw", 0)
    
    self:NextThink(CurTime() + 0.1)
    return true
end

-- Force entity to transmit to clients
function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

-- Handle player usage
function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() then
        print("[NPC Use] " .. activator:Nick() .. " used the PvP Teleporter")
        
        -- Check if the player is in the safe zone
        if activator:GetNWBool("InSafeZone", false) then
            activator:ChatPrint("Deploying to PvP zone...")
            
            -- Call the deploy function
            timer.Simple(0.1, function()
                if IsValid(activator) then
                    if _G.DoDeploy then
                        _G.DoDeploy(activator)
                    else
                        -- Fallback deployment logic
                        activator:SetNWBool("InSafeZone", false)
                        activator:UnLock()
                        
                        -- Teleport to a PvP spawn
                        local PVP_SPAWNS = {
                            Vector(-2121.186279,-2410.672119,-14511.968750),
                            Vector(-3729.331543,-1272.942993,-14511.968750),
                            Vector(-3751.061279,1314.375854,-14511.968750),
                            Vector(-1464.063354,2510.692139,-14511.968750),
                            Vector(-464.353790,973.957520,-14511.968750)
                        }
                        
                        local chosen = table.Random(PVP_SPAWNS)
                        activator:SetPos(chosen)
                        activator:SetEyeAngles(Angle(0, math.random(0, 360), 0))
                        
                        -- Basic weapon
                        activator:StripWeapons()
                        activator:Give("weapon_pistol")
                        activator:GiveAmmo(60, "Pistol", true)
                        
                        -- Temporary god mode
                        activator:GodEnable()
                        timer.Simple(2.5, function() 
                            if IsValid(activator) then 
                                activator:GodDisable() 
                            end 
                        end)
                    end
                end
            end)
        else
            activator:ChatPrint("You must be in the Safe Zone to use this teleporter.")
        end
        
        return true
    end
    
    return false
end

-- Set the animation sequence for all NPCs (global function)
function SetNPCAnimationSequence(seqNumber)
    -- Update the global sequence number
    CURRENT_SEQUENCE = tonumber(seqNumber) or 1
    
    -- Apply to all existing NPCs
    for _, ent in ipairs(ents.FindByClass("npcpvpteleporter")) do
        if IsValid(ent) then
            ent:ResetSequence(CURRENT_SEQUENCE)
        end
    end
    
    print("[NPC] Global animation sequence set to: " .. CURRENT_SEQUENCE)
    return CURRENT_SEQUENCE
end

-- Debug function to print sequence info
function ENT:DebugSequences()
    print("[NPC DEBUG] Beginning sequence debug for PMC model:")
    print("- Entity Valid: " .. tostring(IsValid(self)))
    print("- Model: " .. self:GetModel())
    print("- Current Sequence: " .. self:GetSequence())
    print("- Current Global Sequence: " .. CURRENT_SEQUENCE)
    
    local count = 0
    for i=0, 100 do
        local name = self:GetSequenceName(i)
        if name and name ~= "" then
            count = count + 1
            print("  Seq " .. i .. ": " .. name)
        end
    end
    
    print("[NPC DEBUG] Found " .. count .. " named sequences")
    return count
end