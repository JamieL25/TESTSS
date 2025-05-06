-- NPC Player Model Vendor Entity
-- init.lua - Server-side code
-- Updated: 2025-05-06 22:06:14 by JamieL25

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")
util.AddNetworkString("BG_PlayerModelVendor_RequestModels")
util.AddNetworkString("BG_PlayerModelVendor_ReceiveModels")
util.AddNetworkString("BG_PlayerModelVendor_SetPrice")
util.AddNetworkString("BG_PlayerModelVendor_ToggleBlacklist")
util.AddNetworkString("BG_PlayerModelVendor_UpdateOwned")

-- Get all available player models
local function GetAllPlayerModels()
    local models = {}
    
    local function AddModelsFromPath(path)
        local files, dirs = file.Find(path .. "/*", "GAME")
        
        for _, mdl in pairs(files) do
            if string.EndsWith(mdl, ".mdl") then
                local modelPath = path .. "/" .. mdl
                table.insert(models, {
                    Model = modelPath,
                    Name = string.StripExtension(mdl)
                })
            end
        end
        
        for _, dir in pairs(dirs) do
            AddModelsFromPath(path .. "/" .. dir)
        end
    end
    
    AddModelsFromPath("models/player")
    return models
end

-- Load configuration
local function LoadConfig()
    if not file.Exists("playermodelvendor/config.txt", "DATA") then
        if not file.Exists("playermodelvendor", "DATA") then
            file.CreateDir("playermodelvendor")
        end
        file.Write("playermodelvendor/config.txt", util.TableToJSON({
            blacklist = {},
            prices = {},
            default_price = 1000
        }))
    end
    return util.JSONToTable(file.Read("playermodelvendor/config.txt", "DATA")) or {
        blacklist = {},
        prices = {},
        default_price = 1000
    }
end

-- Save configuration
local function SaveConfig(config)
    file.Write("playermodelvendor/config.txt", util.TableToJSON(config))
end

-- Setup owned models database
local function SetupOwnedModelsDatabase()
    sql.Query([[
        CREATE TABLE IF NOT EXISTS player_owned_models (
            steamid TEXT,
            model TEXT,
            purchase_date DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (steamid, model)
        )
    ]])
    print("[Player Model Vendor] Owned models database checked/created.")
end

-- Get owned models for a player
local function GetOwnedModels(steamID)
    local result = sql.Query("SELECT model FROM player_owned_models WHERE steamid = " .. sql.SQLStr(steamID))
    if result then
        local models = {}
        for _, row in ipairs(result) do
            table.insert(models, row.model)
        end
        return models
    end
    return {}
end

-- Send updated owned models to a player
local function SendOwnedModelsUpdate(ply)
    local ownedModels = GetOwnedModels(ply:SteamID())
    local models = GetAllPlayerModels()
    local config = LoadConfig()
    
    net.Start("BG_PlayerModelVendor_UpdateOwned")
    net.WriteTable(ownedModels)
    net.WriteTable(models)
    net.WriteString(util.TableToJSON(config))
    net.Send(ply)
end

-- Add owned model for a player
local function AddOwnedModel(ply, model)
    local steamID = ply:SteamID()
    sql.Query(string.format([[
        INSERT OR IGNORE INTO player_owned_models (steamid, model)
        VALUES (%s, %s)
    ]], sql.SQLStr(steamID), sql.SQLStr(model)))

    SendOwnedModelsUpdate(ply)
end

-- Money handling functions
local function CanAfford(ply, amount)
    local currentCurrency = ply:GetNWInt("Currency", 0)
    return currentCurrency >= amount
end

local function TakeMoney(ply, amount)
    local currentCurrency = ply:GetNWInt("Currency", 0)
    local newCurrency = currentCurrency - amount
    
    ply:SetNWInt("Currency", newCurrency)
    
    net.Start("UpdateCurrency")
    net.WriteInt(newCurrency, 32)
    net.Send(ply)

    local steamID = ply:SteamID()
    local query = "REPLACE INTO player_currency (steamid, currency) VALUES (" .. sql.SQLStr(steamID) .. ", " .. tonumber(newCurrency) .. ");"
    sql.Query(query)
end

function ENT:Initialize()
    self:SetModel("models/breen.mdl")
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:CapabilitiesAdd(CAP_ANIMATEDFACE)
    self:SetUseType(SIMPLE_USE)
    self:DropToFloor()
    
    SetupOwnedModelsDatabase()
end

function ENT:Use(activator, caller)
    if IsValid(activator) and activator:IsPlayer() then
        local models = GetAllPlayerModels()
        local config = LoadConfig()
        local ownedModels = GetOwnedModels(activator:SteamID())
        
        net.Start("BG_PlayerModelVendor_OpenMenu")
        net.WriteTable(models)
        net.WriteString(util.TableToJSON(config))
        net.WriteTable(ownedModels)
        net.Send(activator)
    end
end

net.Receive("BG_PlayerModelVendor_AttemptPurchase", function(len, ply)
    local model = net.ReadString()
    if not model then return end

    local config = LoadConfig()
    local ownedModels = GetOwnedModels(ply:SteamID())
    
    if table.HasValue(ownedModels, model) then
        -- If already owned, just set the model
        ply:SetModel(model)
        
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(true)
        net.WriteString("Model applied successfully!")
        net.Send(ply)
        return
    end
    
    if table.HasValue(config.blacklist, model) then
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("This model is not available for purchase.")
        net.Send(ply)
        return
    end
    
    local price = config.prices[model] or config.default_price
    
    if not CanAfford(ply, price) then
        net.Start("BG_PlayerModelVendor_PurchaseResult")
        net.WriteBool(false)
        net.WriteString("You cannot afford this model!")
        net.Send(ply)
        return
    end
    
    TakeMoney(ply, price)
    ply:SetModel(model)
    AddOwnedModel(ply, model)
    
    net.Start("BG_PlayerModelVendor_PurchaseResult")
    net.WriteBool(true)
    net.WriteString("Successfully purchased new player model!")
    net.Send(ply)
end)

-- Admin functionality
net.Receive("BG_PlayerModelVendor_SetPrice", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    
    local model = net.ReadString()
    local price = net.ReadInt(32)
    if not model or not price then return end
    
    local config = LoadConfig()
    config.prices[model] = price
    SaveConfig(config)
end)

net.Receive("BG_PlayerModelVendor_ToggleBlacklist", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    
    local model = net.ReadString()
    if not model then return end
    
    local config = LoadConfig()
    
    if table.HasValue(config.blacklist, model) then
        table.RemoveByValue(config.blacklist, model)
    else
        table.insert(config.blacklist, model)
    end
    
    SaveConfig(config)
end)