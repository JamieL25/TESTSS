AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- This local variable will be populated from self.PlayerModels in ENT:Initialize
local PlayerModelsForSale = {}

util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")

function ENT:Initialize()
    print("--- [NPC PlayerModelVendor INIT] ENT:Initialize() called ---")
    
    if not IsValid(self) then
        print("[NPC PlayerModelVendor INIT CRITICAL ERROR] 'self' is invalid at ENT:Initialize() start! Class: " .. self:GetClass())
        return
    end
    
    -- Populate PlayerModelsForSale from the instance's ENT table
    if type(self.PlayerModels) == "table" then
        PlayerModelsForSale = self.PlayerModels
        print("[NPC PlayerModelVendor INIT INFO] Captured self.PlayerModels. Item count: " .. table.Count(PlayerModelsForSale))
    else
        print("[NPC PlayerModelVendor INIT ERROR] self.PlayerModels was not a table! Type: " .. type(self.PlayerModels))
        PlayerModelsForSale = {}
    end

    -- Basic NPC Setup
    self:SetModel("models/Humans/Group01/Female_01.mdl")  -- Changed to a more suitable model
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)
    
    -- NPC AI Setup
    self:SetMaxHealth(100)
    self:SetHealth(100)
    
    -- AI Capabilities
    local caps = bit.bor(CAP_ANIMATEDFACE, CAP_TURN_HEAD, CAP_USE)
    self:CapabilitiesAdd(caps)

    -- Set up idle animation
    local idleSequence = self:LookupSequence("idle_subtle") or self:LookupSequence("idle") or self:LookupSequence("idle_all_01") or 0
    if idleSequence > 0 then
        self:SetSequence(idleSequence)
        self:ResetSequenceInfo()
        self:SetCycle(0)
    end

    print("--- [NPC PlayerModelVendor INIT] Initialized successfully at pos: " .. tostring(self:GetPos()) .. " ---")
end

function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() then
        print("[NPC PlayerModelVendor USE] Player " .. activator:Nick() .. " used the vendor.")
        net.Start("BG_PlayerModelVendor_OpenMenu")
        if type(PlayerModelsForSale) ~= "table" then
            print("[NPC PlayerModelVendor USE ERROR] PlayerModelsForSale is not a table! Type: " .. type(PlayerModelsForSale))
            net.WriteTable({})
        else
            net.WriteTable(PlayerModelsForSale)
        end
        net.Send(activator)
        return true
    end
    return false
end

-- Handle purchase attempts
net.Receive("BG_PlayerModelVendor_AttemptPurchase", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local modelIndex = net.ReadUInt(8)
    print("[NPC PlayerModelVendor NET] Received purchase attempt from " .. ply:Nick() .. " for model index: " .. modelIndex)

    if type(PlayerModelsForSale) ~= "table" or not PlayerModelsForSale[modelIndex] then
        print("[NPC PlayerModelVendor NET ERROR] Invalid model index or shop data missing. Index: " .. modelIndex)
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Error: Invalid item or shop data missing.")
        net.Send(ply)
        return
    end

    local selectedModelData = PlayerModelsForSale[modelIndex]
    local price = selectedModelData.Price
    local modelPath = selectedModelData.Model

    if ply:GetModel() == modelPath then
        print("[NPC PlayerModelVendor NET] Player " .. ply:Nick() .. " already has model: " .. modelPath)
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You already have this model equipped.")
        net.Send(ply)
        return
    end

    local currentCurrency = ply:GetNWInt("Currency", 0)
    print("[NPC PlayerModelVendor NET] Player " .. ply:Nick() .. " has £" .. currentCurrency .. ". Price is £" .. price)

    if currentCurrency >= price then
        local newCurrency = currentCurrency - price
        ply:SetNWInt("Currency", newCurrency)
        ply:SetModel(modelPath)
        
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(true)
        net.WriteString("Purchase successful! Model changed to " .. selectedModelData.Name .. ".")
        net.Send(ply)

        -- Update currency display if you have that network message set up
        if util.NetworkStringToID("UpdateCurrency") ~= 0 then
            net.Start("UpdateCurrency")
            net.WriteInt(newCurrency, 32)
            net.Send(ply)
        end
    else
        print("[NPC PlayerModelVendor NET] Insufficient funds for " .. ply:Nick() .. " (Needs £" .. price .. ", Has £" .. currentCurrency .. ")")
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Not enough currency! You need £" .. price .. ".")
        net.Send(ply)
    end
end)

print("--- [NPC PlayerModelVendor INIT] init.lua processed. ---")