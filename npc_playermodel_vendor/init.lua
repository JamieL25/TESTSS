-- NPC Player Model Vendor Entity
-- init.lua - Server-side code
-- Updated: 2025-05-07 16:47:47 by JamieL25

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Configuration
local CONFIG_PATH = "playermodel_vendor/config.json"
local DEFAULT_MODEL = "models/player/kleiner.mdl"

-- Money system functions
local function CanAfford(ply, amount)
    if not IsValid(ply) then return false end
    local currentBalance = ply:GetNWInt("Currency", 0)
    return currentBalance >= amount
end

local function ProcessPayment(ply, amount)
    if not IsValid(ply) then return false end
    local currentBalance = ply:GetNWInt("Currency", 0)
    local newBalance = currentBalance - amount
    -- Use the UpdatePlayerCurrency function from the currency system
    UpdatePlayerCurrency(ply, newBalance, "purchase", false)
    return true
end

-- Initialize
function ENT:Initialize()
    self:SetModel("models/Humans/Group01/male_07.mdl")
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:SetUseType(SIMPLE_USE)
    self:DropToFloor()
    
    -- Load or create config
    self:LoadConfig()
end

-- Load configuration
function ENT:LoadConfig()
    if not file.Exists("playermodel_vendor", "DATA") then
        file.CreateDir("playermodel_vendor")
    end
    
    if file.Exists(CONFIG_PATH, "DATA") then
        local content = file.Read(CONFIG_PATH, "DATA")
        PLAYERMODEL_VENDOR.Config = util.JSONToTable(content) or {
            blacklist = {},
            prices = {},
            default_price = 1000
        }
    end
    self:SaveConfig()
end

-- Save configuration
function ENT:SaveConfig()
    file.Write(CONFIG_PATH, util.TableToJSON(PLAYERMODEL_VENDOR.Config, true))
end

-- Get player's owned models
local function GetPlayerOwnedModels(ply)
    if not file.Exists("playermodel_vendor/players", "DATA") then
        file.CreateDir("playermodel_vendor/players")
    end
    
    local steamID = ply:SteamID64()
    local path = "playermodel_vendor/players/" .. steamID .. ".txt"
    
    if file.Exists(path, "DATA") then
        local content = file.Read(path, "DATA")
        return util.JSONToTable(content) or {}
    end
    return {}
end

-- Save player's owned models
local function SavePlayerOwnedModels(ply, models)
    local steamID = ply:SteamID64()
    local path = "playermodel_vendor/players/" .. steamID .. ".txt"
    file.Write(path, util.TableToJSON(models, true))
end

-- Recursively scan for models in a directory
local function ScanModelDirectory(baseDir, models)
    local files, directories = file.Find(baseDir .. "/*", "GAME")
    
    -- Add models from current directory
    for _, mdl in pairs(files) do
        if string.EndsWith(mdl, ".mdl") then
            local fullPath = baseDir .. "/" .. mdl
            -- Remove the 'models/' prefix for the actual model path
            local modelPath = fullPath
            local displayName = string.gsub(mdl, ".mdl", ""):gsub("^%l", string.upper)
            
            -- Check if model is valid
            if util.IsValidModel(fullPath) then
                table.insert(models, {
                    Model = modelPath,
                    Name = displayName
                })
            end
        end
    end
    
    -- Recursively scan subdirectories
    for _, dir in pairs(directories) do
        ScanModelDirectory(baseDir .. "/" .. dir, models)
    end
end

-- Get all available models
local function GetAvailableModels()
    local models = {}
    
    -- Scan main player model directory
    ScanModelDirectory("models/player", models)
    
    -- Additional model directories
    local additionalDirs = {
        "models/humans",
        "models/playermodels"
    }
    
    for _, dir in pairs(additionalDirs) do
        if file.Exists(dir, "GAME") then
            ScanModelDirectory(dir, models)
        end
    end
    
    -- Sort models by name
    table.sort(models, function(a, b)
        return a.Name < b.Name
    end)
    
    return models
end

-- Send models to player
local function SendModelsToPlayer(ply)
    if not IsValid(ply) then return end
    
    local models = GetAvailableModels()
    local ownedModels = GetPlayerOwnedModels(ply)
    
    net.Start("BG_PlayerModelVendor_UpdateOwned")
    net.WriteTable(ownedModels)
    net.WriteTable(models)
    net.WriteString(util.TableToJSON(PLAYERMODEL_VENDOR.Config))
    net.Send(ply)
end

-- Use function
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local models = GetAvailableModels()
    local ownedModels = GetPlayerOwnedModels(activator)
    
    net.Start("BG_PlayerModelVendor_OpenMenu")
    net.WriteTable(models)
    net.WriteString(util.TableToJSON(PLAYERMODEL_VENDOR.Config))
    net.WriteTable(ownedModels)
    net.Send(activator)
end

-- Request models
net.Receive("BG_PlayerModelVendor_RequestModels", function(len, ply)
    if not IsValid(ply) then return end
    SendModelsToPlayer(ply)
end)

-- Handle purchase attempt
net.Receive("BG_PlayerModelVendor_AttemptPurchase", function(len, ply)
    if not IsValid(ply) then return end
    
    local modelPath = net.ReadString()
    local ownedModels = GetPlayerOwnedModels(ply)
    
    -- Check if already owned
    if table.HasValue(ownedModels, modelPath) then
        ply:SetModel(modelPath)
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(true)
        net.WriteString("Model applied successfully!")
        net.Send(ply)
        return
    end
    
    -- Check if blacklisted
    if table.HasValue(PLAYERMODEL_VENDOR.Config.blacklist, modelPath) then
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("This model is not available for purchase.")
        net.Send(ply)
        return
    end
    
    -- Get price
    local price = PLAYERMODEL_VENDOR.Config.prices[modelPath] or PLAYERMODEL_VENDOR.Config.default_price
    
    -- Check if player can afford
    if not CanAfford(ply, price) then
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You need £" .. price .. " to buy this model!")
        net.Send(ply)
        return
    end
    
    -- Process purchase
    if ProcessPayment(ply, price) then
        table.insert(ownedModels, modelPath)
        SavePlayerOwnedModels(ply, ownedModels)
        ply:SetModel(modelPath)
        
        -- Send success message
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(true)
        net.WriteString("Model purchased and applied successfully!")
        net.Send(ply)
        
        -- Update the client's model list
        SendModelsToPlayer(ply)
    else
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("Transaction failed! Please try again.")
        net.Send(ply)
    end
end)

-- Handle use model request
net.Receive("BG_PlayerModelVendor_UseModel", function(len, ply)
    if not IsValid(ply) then return end
    
    local modelPath = net.ReadString()
    local ownedModels = GetPlayerOwnedModels(ply)
    
    if table.HasValue(ownedModels, modelPath) then
        ply:SetModel(modelPath)
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(true)
        net.WriteString("Model applied successfully!")
        net.Send(ply)
    end
end)

-- Admin: Toggle blacklist
net.Receive("BG_PlayerModelVendor_ToggleBlacklist", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    local modelPath = net.ReadString()
    PLAYERMODEL_VENDOR.Config.blacklist = PLAYERMODEL_VENDOR.Config.blacklist or {}
    
    if table.HasValue(PLAYERMODEL_VENDOR.Config.blacklist, modelPath) then
        table.RemoveByValue(PLAYERMODEL_VENDOR.Config.blacklist, modelPath)
    else
        table.insert(PLAYERMODEL_VENDOR.Config.blacklist, modelPath)
    end
    
    -- Save config
    file.Write(CONFIG_PATH, util.TableToJSON(PLAYERMODEL_VENDOR.Config, true))
    
    -- Update all players
    for _, p in ipairs(player.GetAll()) do
        SendModelsToPlayer(p)
    end
end)

-- Admin: Set price
net.Receive("BG_PlayerModelVendor_SetPrice", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    
    local modelPath = net.ReadString()
    local price = net.ReadInt(32)
    
    PLAYERMODEL_VENDOR.Config.prices = PLAYERMODEL_VENDOR.Config.prices or {}
    PLAYERMODEL_VENDOR.Config.prices[modelPath] = price
    
    -- Save config
    file.Write(CONFIG_PATH, util.TableToJSON(PLAYERMODEL_VENDOR.Config, true))
    
    -- Update all players
    for _, p in ipairs(player.GetAll()) do
        SendModelsToPlayer(p)
    end
end)