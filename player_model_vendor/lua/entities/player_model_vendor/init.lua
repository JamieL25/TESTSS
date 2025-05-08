AddCSLuaFile("cl_init.lua")  -- Make sure the client script is sent to the client
AddCSLuaFile("shared.lua")   -- Ensure shared code is sent to the client

include("shared.lua")  -- Include shared code

util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")

-- NPC Initialization
function ENT:Initialize()
    self:SetModel("models/Humans/Group01/Female_01.mdl")  -- Set NPC model
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)
end

-- When the player interacts with the NPC
function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() then
        -- Send the model list to the player
        net.Start("BG_PlayerModelVendor_OpenMenu")
        net.WriteTable(self.PlayerModels)  -- Send the list of models
        net.Send(activator)
    end
end

-- Register the NPC for spawn menu
scripted_ents.Register(ENT, "npc_player_model_vendor")
