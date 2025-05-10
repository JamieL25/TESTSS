--[[---------------------------------------------------------
    NPC Player Model Vendor
    Created by: JamieL25
    Last Updated: (MySQL Integration - Robust Callback Handling & pcall Debug for Create Table)
-----------------------------------------------------------]]

print("--- [NPC PlayerModelVendor SCRIPT] init.lua is being loaded by the SERVER (MySQL Integration - Robust Callback Handling & pcall Debug for Create Table) ---")

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua") -- ENT.Base is defined here

DEFINE_BASECLASS(ENT.Base)

-- At the top of your file
print("[PlayerModelVendor INFO] Attempting to require('mysqloo') at the top...")
local require_status_top, require_err_top = pcall(require, "mysqloo")
if not require_status_top then
    print(string.format("[PlayerModelVendor FATAL ERROR] Top-level require('mysqloo') failed: %s", tostring(require_err_top)))
    print("[PlayerModelVendor FATAL ERROR] Ensure gmsv_mysqloo_winXX.dll is correctly installed, matches server architecture, and all dependencies are met.")
else
    print("[PlayerModelVendor INFO] Top-level require('mysqloo') executed.")
    if not mysqloo and sql then
        print("[PlayerModelVendor INFO] 'mysqloo' global not found, but 'sql' global exists. Aliasing 'mysqloo = sql'.")
        mysqloo = sql
    elseif not mysqloo and not sql then
        print("[PlayerModelVendor WARNING] Top-level require('mysqloo') succeeded, but neither 'mysqloo' nor 'sql' globals were populated.")
    elseif mysqloo then
         print("[PlayerModelVendor INFO] 'mysqloo' global is populated after top-level require.")
    end
end


--[[---------------------------------------------------------
    !!! IMPORTANT MYSQL CONFIGURATION !!!
    You MUST configure these settings below to match your MySQL server.
-----------------------------------------------------------]]
local MYSQL_HOST        = "127.0.0.1"     -- IP address or hostname of your MySQL server
local MYSQL_USER        = "gmod_pmv_user" -- MySQL username (Ensure this is updated)
local MYSQL_PASSWORD    = "85ofB1Nx*Rc4Wjo#q"  -- MySQL password (Ensure this is updated)
local MYSQL_DB_NAME     = "gmod_playermodels" -- Name of the database to use (it must exist)
local MYSQL_PORT        = 3306            -- MySQL server port (default is 3306)
--[[---------------------------------------------------------]]

local db -- Database object

-- Helper function to normalize SteamID64 representations (essential for consistent DB keys)
local function getNormalizedSteamID64(steamIDInput)
    if not steamIDInput then
        print("[PlayerModelVendor WARNING] getNormalizedSteamID64: received nil input.")
        return nil
    end
    local idStr = string.Trim(tostring(steamIDInput))
    if string.match(idStr, "^%-?%d*%.?%d*[eE][%-+]?%d+$") then
        local numVal = tonumber(idStr)
        if numVal then
            idStr = string.format("%.0f", numVal)
        else
            print(string.format("[PlayerModelVendor WARNING] getNormalizedSteamID64: Failed to convert scientific notation '%s' to number.", idStr))
        end
    end
    if not string.match(idStr, "^7656119%d%d%d%d%d%d%d%d%d%d$") then
        print(string.format("[PlayerModelVendor WARNING] getNormalizedSteamID64: Potentially invalid SteamID64 format after processing: '%s'", idStr))
        return nil
    end
    return idStr
end


-- Database Initialization
local function InitializeDatabase()
    print("[PlayerModelVendor DB] Initializing MySQL database connection...")

    if not mysqloo or type(mysqloo.connect) ~= "function" then
        print("[PlayerModelVendor DB FATAL ERROR] 'mysqloo.connect' function not found. mysqloo module is likely not installed or loaded correctly.")
        db = nil
        return
    end

    local tempDB_obj = mysqloo.connect(
        MYSQL_HOST,
        MYSQL_USER,
        MYSQL_PASSWORD,
        MYSQL_DB_NAME,
        MYSQL_PORT
    )

    print(string.format("[PlayerModelVendor DB] mysqloo.connect called for MySQL: %s@%s:%d, DB: %s",
        MYSQL_USER, MYSQL_HOST, MYSQL_PORT, MYSQL_DB_NAME))

    if not tempDB_obj then
        print("[PlayerModelVendor DB ERROR] mysqloo.connect returned nil. Database object could not be created.")
        db = nil
        return
    end

    function tempDB_obj:onConnected()
        print("[PlayerModelVendor DB] Successfully connected to MySQL database! (onConnected called)")

        if not self then
            print("[PlayerModelVendor DB ERROR] 'self' is nil inside onConnected! This should not happen.")
            return
        end
        if type(self.query) ~= "function" then
            print("[PlayerModelVendor DB ERROR] self.query is not a function inside onConnected! Cannot proceed.")
            print("[PlayerModelVendor DB DEBUG] Type of self: " .. type(self))
            if type(self) == "table" or type(self) == "userdata" then
                print("[PlayerModelVendor DB DEBUG] Keys/methods in self (or its metatable):")
                for k, v in pairs(getmetatable(self) or {}) do print("  Meta: ", k, type(v)) end
                for k, v in pairs(self) do print("  Direct: ", k, type(v)) end
            end
            return
        end

        local query_str = [[
            CREATE TABLE IF NOT EXISTS player_owned_models (
                steam_id_64 VARCHAR(20) NOT NULL,
                model_path VARCHAR(255) NOT NULL,
                purchase_date INT UNSIGNED DEFAULT (UNIX_TIMESTAMP()),
                PRIMARY KEY (steam_id_64, model_path)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
        -- NEW DEBUG
        print("[PlayerModelVendor DB DEBUG onConnected] About to execute self:query for CREATE TABLE. SQL snippet: " .. string.sub(query_str, 1, 100))

        local query_success, query_error_msg = pcall(function()
            self:query(query_str, nil,
                function()
                    print("[PlayerModelVendor DB] 'player_owned_models' table ensured successfully.")
                end,
                function(err)
                    print("[PlayerModelVendor DB ERROR] Failed to create table: " .. tostring(err))
                end
            )
        end)

        if not query_success then
            -- NEW DEBUG for pcall failure
            print("[PlayerModelVendor DB FATAL ERROR onConnected] pcall caught error during self:query dispatch for CREATE TABLE: " .. tostring(query_error_msg))
        else
            -- NEW DEBUG for successful dispatch
            print("[PlayerModelVendor DB DEBUG onConnected] self:query for CREATE TABLE dispatched. Waiting for callbacks.")
        end
    end

    function tempDB_obj:onConnectionFailed(err)
        print("[PlayerModelVendor DB ERROR] Connection failed: " .. tostring(err))
        db = nil
    end

    db = tempDB_obj

    print("[PlayerModelVendor DB] Attempting to connect using db:connect()...")
    if db and type(db.connect) == "function" then
        db:connect()
    else
        print("[PlayerModelVendor DB WARNING] db.connect (lowercase 'c') method not found on the database object.")
        if db and type(db.onConnected) == "function" then
             print("[PlayerModelVendor DB WARNING] Manually triggering onConnected logic.")
            db:onConnected()
        elseif db then
             print("[PlayerModelVendor DB ERROR] db object exists, but onConnected callback is not defined or not a function for manual trigger.")
        else
             print("[PlayerModelVendor DB ERROR] db object is nil, cannot manually trigger onConnected.")
        end
    end

    timer.Simple(5, function()
        if db and type(db.status) == "function" then
            local status_val = db:status()
            if mysqloo and status_val == mysqloo.DATABASE_CONNECTED then
                print("[PlayerModelVendor DB] Connection verified as mysqloo.DATABASE_CONNECTED after 5 seconds.")
            else
                print("[PlayerModelVendor DB ERROR] Connection not established after 5 seconds. Status: " .. tostring(status_val) .. " (mysqloo.DATABASE_CONNECTED value: " .. tostring(mysqloo and mysqloo.DATABASE_CONNECTED) .. ")")
            end
        elseif db then
            print("[PlayerModelVendor DB ERROR] Connection not established after 5 seconds. db object exists but 'status' method is missing or mysqloo global is not available.")
        else
            print("[PlayerModelVendor DB ERROR] Connection not established after 5 seconds. Global 'db' object is nil.")
        end
    end)
end

InitializeDatabase()

if not _G.BG_PMV_NetStringsRegistered_V_Owned_Refresh_MYSQL_ROBUST then
    util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
    util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
    util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")
    util.AddNetworkString("BG_PlayerModelVendor_Admin_GetServerModels")
    util.AddNetworkString("BG_PlayerModelVendor_Admin_SendServerModels")
    util.AddNetworkString("BG_PlayerModelVendor_Admin_UpdateModelSettings")
    util.AddNetworkString("BG_PlayerModelVendor_Admin_ActionResponse")
    util.AddNetworkString("BG_PlayerModelVendor_EquipOwnedModel")
    util.AddNetworkString("BG_PlayerModelVendor_EquipResult")
    _G.BG_PMV_NetStringsRegistered_V_Owned_Refresh_MYSQL_ROBUST = true
    print("--- [NPC PlayerModelVendor SCRIPT] Network strings registered. ---")
end


if not player_model_vendor then player_model_vendor = {} end
if not player_model_vendor.MYSQL_DataInitialized_ROBUST then
    player_model_vendor.ServerModels = {}
    player_model_vendor.Blacklist = {}
    player_model_vendor.CustomPrices = {}
    player_model_vendor.ModelsLoaded = false
    player_model_vendor.InitialScanComplete = false
    player_model_vendor.DefaultPrice = 100
    player_model_vendor.DefaultNewModelPrice = 250
    player_model_vendor.MYSQL_DataInitialized_ROBUST = true
    print("[PlayerModelVendor] Core tables initialized for MySQL version.")
end

local StaticDefaultModels = {
    { Name = "Citizen Male 01", Model = "models/player/group01/male_01.mdl", Price = 100 },
    { Name = "Citizen Male 02", Model = "models/player/group01/male_02.mdl", Price = 100 },
    { Name = "Citizen Female 01", Model = "models/player/group01/female_01.mdl", Price = 100 },
    { Name = "Citizen Female 02", Model = "models/player/group01/female_02.mdl", Price = 100 },
    { Name = "Combine Soldier", Model = "models/player/combine_soldier.mdl", Price = 500 },
    { Name = "Police", Model = "models/player/police.mdl", Price = 300 },
    { Name = "Barney", Model = "models/player/barney.mdl", Price = 250 },
    { Name = "Alyx", Model = "models/player/alyx.mdl", Price = 400 }
}

local function IsLikelyPlayerModel(modelPath)
    local playerModelIndicators = {
        "/player/", "/humans/", "/characters/", "/playermodels/", "/custom/player",
        "/gmod_tower/", "/pmc", "/pmcs/", "/pmc_", "/military/", "/operator/"
    }
    modelPath = string.lower(modelPath)
    for _, indicator in ipairs(playerModelIndicators) do
        if string.find(modelPath, indicator) then return true end
    end
    if player_manager and type(player_manager.IsPlayerModel) == "function" then
        local success, result = pcall(player_manager.IsPlayerModel, modelPath)
        if success then return result end
    end
    return false
end

local function GetAllAvailablePlayerModelsInternal()
    local modelsTable = {}
    local finalModelList = {}
    if player_manager and type(player_manager.AllValidModels) == "function" then
        local success, pmModels = pcall(player_manager.AllValidModels)
        if success and pmModels and type(pmModels) == "table" then
            for _, model in pairs(pmModels) do
                if model and model ~= "" then modelsTable[string.lower(model)] = true; end
            end
        end
    end
    local searchPatterns = {
        "models/player/*.mdl", "models/player/*/*.mdl", "models/player/*/*/*.mdl",
        "models/humans/*.mdl", "models/humans/*/*.mdl",
        "models/characters/*.mdl", "models/characters/*/*.mdl",
        "models/pmc/*.mdl", "models/pmc/*/*.mdl",
        "models/operator/*.mdl", "models/operator/*/*.mdl",
        "models/military/*.mdl", "models/military/*/*.mdl"
    }
    for _, pattern in ipairs(searchPatterns) do
        local files, _ = file.Find(pattern, "GAME")
        if files and #files > 0 then
            for _, filePath in pairs(files) do
                if filePath and filePath ~= "" then modelsTable[string.lower(filePath)] = true; end
            end
        end
    end
    for modelPath, _ in pairs(modelsTable) do
        if util.IsValidModel(modelPath) and IsLikelyPlayerModel(modelPath) then
            table.insert(finalModelList, modelPath)
        end
    end
    print("[PlayerModelVendor DEBUG] Validated " .. #finalModelList .. " unique player models from all sources.")
    return finalModelList
end

function player_model_vendor.GetNameFromModelPath(modelPath)
    local name = modelPath
    local lastSlash = string.match(name, ".+/(.+)")
    if lastSlash then name = lastSlash end
    local dotMdl = string.match(name, "(.+)%.mdl")
    if dotMdl then name = dotMdl end
    name = name:gsub("_", " "):gsub("%b()", ""):gsub("^%s*(.-)%s*$", "%1")
    name = name:gsub("^%l", string.upper)
    return name
end

function player_model_vendor.LoadAndPrepareServerModels(isManualRescan)
    if player_model_vendor.ModelsLoaded and not isManualRescan and player_model_vendor.InitialScanComplete then return end
    if isManualRescan then print("[PlayerModelVendor] Manual rescan initiated.") end
    print("[PlayerModelVendor DEBUG] Starting model scan...")
    player_model_vendor.ServerModels = {}
    local allFoundPlayerModels = GetAllAvailablePlayerModelsInternal()
    local processedModelPaths = {}
    for _, data in ipairs(StaticDefaultModels) do
        if data.Model and data.Model ~= "" then
            local modelPath = string.lower(data.Model)
            player_model_vendor.ServerModels[modelPath] = {
                Name = data.Name or player_model_vendor.GetNameFromModelPath(modelPath),
                Model = modelPath,
                Price = player_model_vendor.CustomPrices[modelPath] or data.Price or player_model_vendor.DefaultPrice,
                IsBlacklisted = player_model_vendor.Blacklist[modelPath] or false
            }
            processedModelPaths[modelPath] = true
        end
    end
    for _, modelPath in ipairs(allFoundPlayerModels) do
        if modelPath and modelPath ~= "" and not processedModelPaths[modelPath] then
            player_model_vendor.ServerModels[modelPath] = {
                Name = player_model_vendor.GetNameFromModelPath(modelPath),
                Model = modelPath,
                Price = player_model_vendor.CustomPrices[modelPath] or player_model_vendor.DefaultNewModelPrice,
                IsBlacklisted = player_model_vendor.Blacklist[modelPath] or false
            }
        end
    end
    for modelPathKey, data in pairs(player_model_vendor.ServerModels) do
        if player_model_vendor.Blacklist[modelPathKey] then data.IsBlacklisted = true end
        if player_model_vendor.CustomPrices[modelPathKey] then data.Price = player_model_vendor.CustomPrices[modelPathKey] end
    end
    player_model_vendor.ModelsLoaded = true
    if not isManualRescan then player_model_vendor.InitialScanComplete = true end
    print("[PlayerModelVendor] Scan complete. Total models prepared: " .. table.Count(player_model_vendor.ServerModels))
end

timer.Simple(15, function()
    if not player_model_vendor.InitialScanComplete then
        player_model_vendor.LoadAndPrepareServerModels(false)
    end
end)

function ENT:Initialize()
    if not player_model_vendor.InitialScanComplete then
        print("[PlayerModelVendor " .. self:EntIndex() .. " INIT] Models not loaded by timer, attempting load now.")
        player_model_vendor.LoadAndPrepareServerModels(false)
    end
    if self.Initialized then return end
    self.Initialized = true
    self:SetModel("models/Humans/Group01/Female_01.mdl"); self:SetHullType(HULL_HUMAN); self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_IDLE); self:SetSolid(SOLID_BBOX); self:SetUseType(SIMPLE_USE); self:DropToFloor()
    local caps = bit.bor(CAP_ANIMATEDFACE, CAP_TURN_HEAD, CAP_USE); self:CapabilitiesAdd(caps)
    local idleSequence = self:LookupSequence("idle_subtle") or self:LookupSequence("idle") or self:LookupSequence("act_idle") or 0
    if idleSequence > 0 then self:SetSequence(idleSequence); self:ResetSequenceInfo(); self:SetCycle(0)
    else print("[NPC PlayerModelVendor " .. self:EntIndex() .. " INIT] No suitable idle animation for model: " .. self:GetModel()) end
    self:SetMaxHealth(1000); self:SetHealth(1000); self:DrawShadow(true)
    print("--- [NPC PlayerModelVendor " .. self:EntIndex() .. "] Initialized successfully. ---")
end

local function FetchOwnedModelsForPlayerFromDB(plySteamID64_normalized, callback)
    print("[PlayerModelVendor DB DEBUG FetchOwned] Entered function for " .. plySteamID64_normalized)

    if not db then
        print("[PlayerModelVendor DB ERROR] Database connection object ('db') is nil. Cannot fetch owned models.")
        callback({})
        return
    end
    if type(db.query) ~= "function" then
        print("[PlayerModelVendor DB ERROR] 'db.query' is not a function. Database object might be invalid or not fully initialized.")
        callback({})
        return
    end

    local query_str = "SELECT model_path FROM player_owned_models WHERE steam_id_64 = ?;"
    print("[PlayerModelVendor DB DEBUG FetchOwned] About to execute db:query. SQL: " .. query_str .. " for SteamID: " .. plySteamID64_normalized)

    db:query(query_str, {plySteamID64_normalized},
        function(queryData)
            print("[PlayerModelVendor DB DEBUG FetchOwned] Query success callback entered for " .. plySteamID64_normalized)
            local ownedModelsMap = {}
            if queryData and #queryData > 0 then
                for _, row in ipairs(queryData) do
                    if row and row.model_path then
                        ownedModelsMap[string.lower(row.model_path)] = true
                    end
                end
            end
            print(string.format("[PlayerModelVendor DB] Fetched %d owned models for %s from MySQL DB.", table.Count(ownedModelsMap), plySteamID64_normalized))
            callback(ownedModelsMap)
        end,
        function(err)
            print("[PlayerModelVendor DB DEBUG FetchOwned] Query error callback entered for " .. plySteamID64_normalized .. ". Error: " .. tostring(err))
            print(string.format("[PlayerModelVendor DB ERROR] Failed to fetch owned models for %s from MySQL: %s", plySteamID64_normalized, err))
            callback({})
        end
    )
    print("[PlayerModelVendor DB DEBUG FetchOwned] db:query has been dispatched for " .. plySteamID64_normalized .. ". Waiting for callbacks.")
end

local function GetModelListsForPlayer(ply, resultCallback)
    local normPlySteamID64 = getNormalizedSteamID64(ply:SteamID64())
    if not normPlySteamID64 then
        print("[PlayerModelVendor ERROR GetModelLists] Could not normalize player's SteamID64: " .. tostring(ply:SteamID64()))
        resultCallback({}, {})
        return
    end

    print("[PlayerModelVendor DEBUG GetModelLists] For player: '" .. normPlySteamID64 .. "' (Normalized, Type: " .. type(normPlySteamID64) .. ") - About to fetch from DB.")

    FetchOwnedModelsForPlayerFromDB(normPlySteamID64, function(playerOwnedModelsMap)
        local available = {}
        local owned = {}

        for modelPath, modelData in pairs(player_model_vendor.ServerModels) do
            local modelPathKey = string.lower(modelPath)
            if not modelData.IsBlacklisted then
                if not playerOwnedModelsMap[modelPathKey] then
                    table.insert(available, { Name = modelData.Name, Model = modelData.Model, Price = modelData.Price })
                end
            end
            if playerOwnedModelsMap[modelPathKey] then
                 table.insert(owned, { Name = modelData.Name, Model = modelData.Model })
            end
        end
        table.sort(available, function(a, b) return a.Name < b.Name end)
        table.sort(owned, function(a, b) return a.Name < b.Name end)

        print("[PlayerModelVendor DEBUG GetModelLists] Processed for " .. normPlySteamID64 .. " - Available: " .. #available .. ", Owned: " .. #owned .. " - Calling resultCallback now.")
        resultCallback(available, owned)
    end)
end


function ENT:Use(activator, caller)
    print("[PlayerModelVendor USE DEBUG] ENT:Use called by: " .. activator:Nick())
    if not IsValid(activator) or not activator:IsPlayer() then
        print("[PlayerModelVendor USE DEBUG] Activator not valid or not a player. Returning.")
        return false
    end
    if not player_model_vendor.InitialScanComplete then
        print("[PlayerModelVendor USE] Models not fully loaded (initial scan pending). Forcing load for " .. activator:Nick())
        player_model_vendor.LoadAndPrepareServerModels(false)
        if not player_model_vendor.ModelsLoaded then
            print("[PlayerModelVendor USE DEBUG] Models still not loaded after forced scan. Informing player.")
            activator:ChatPrint("Model list is still loading, please try again in a moment.")
            return false
        end
    end

    GetModelListsForPlayer(activator, function(availableModelsForClient, ownedModelsForClient)
        print("[PlayerModelVendor USE DEBUG] About to send BG_PlayerModelVendor_OpenMenu. Available: " .. #availableModelsForClient .. ", Owned: " .. #ownedModelsForClient .. " to " .. activator:Nick())

        net.Start("BG_PlayerModelVendor_OpenMenu")
            net.WriteTable(availableModelsForClient)
            net.WriteTable(ownedModelsForClient)
            net.WriteEntity(self)
        net.Send(activator)
        print("[PlayerModelVendor USE DEBUG] BG_PlayerModelVendor_OpenMenu net message sent to " .. activator:Nick())
    end)
    return true
end

net.Receive("BG_PlayerModelVendor_AttemptPurchase", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local vendorEntity = net.ReadEntity()
    if not IsValid(vendorEntity) or vendorEntity:GetClass() ~= "player_model_vendor" then return end
    local receivedModelIndex = net.ReadUInt(16)

    GetModelListsForPlayer(ply, function(availableModelsForThisPlayer, ownedModelsForThisPlayer_Unused)
        local selectedModel = availableModelsForThisPlayer[receivedModelIndex]
        if not selectedModel then
            GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                net.Start("BG_PlayerModelVendor_PurchaseResult"); net.WriteBool(false); net.WriteString("Invalid model selection!"); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
            end)
            return
        end

        if string.lower(ply:GetModel()) == string.lower(selectedModel.Model) then
            GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                net.Start("BG_PlayerModelVendor_PurchaseResult"); net.WriteBool(false); net.WriteString("You already have this model equipped!"); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
            end)
            return
        end

        local price = selectedModel.Price
        local currentMoney = ply:GetNWInt("Currency", 0)

        if currentMoney >= price then
            ply:SetNWInt("Currency", currentMoney - price)

            local normPlySteamID64 = getNormalizedSteamID64(ply:SteamID64())
            if not normPlySteamID64 then
                print("[PlayerModelVendor ERROR Purchase] Failed to normalize SteamID for purchase: " .. tostring(ply:SteamID64()))
                GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                    net.Start("BG_PlayerModelVendor_PurchaseResult"); net.WriteBool(false); net.WriteString("Error processing your SteamID for purchase."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
                end)
                return
            end

            local modelPathKey = string.lower(selectedModel.Model)

            if not db or type(db.query) ~= "function" then
                print("[PlayerModelVendor DB ERROR] Database not connected or invalid. Cannot save purchase.")
                GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                    net.Start("BG_PlayerModelVendor_PurchaseResult"); net.WriteBool(false); net.WriteString("Database error, purchase not saved."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
                end)
                return
            end

            local query_str = "INSERT IGNORE INTO player_owned_models (steam_id_64, model_path) VALUES (?, ?);"
            db:query(query_str, {normPlySteamID64, modelPathKey},
                function()
                    print("[PlayerModelVendor DB] Player " .. ply:Nick() .. " (" .. normPlySteamID64 .. ") now owns model: " .. modelPathKey .. " (MySQL DB updated)")

                    local oldPos, oldAng = ply:GetPos(), ply:GetAngles()
                    ply:SetModel(selectedModel.Model)
                    ply:SetPos(oldPos); ply:SetAngles(oldAng)

                    GetModelListsForPlayer(ply, function(newAvailable, newOwned)
                        net.Start("BG_PlayerModelVendor_PurchaseResult")
                            net.WriteBool(true)
                            net.WriteString("Successfully purchased and equipped " .. selectedModel.Name .. "!")
                            net.WriteTable(newAvailable)
                            net.WriteTable(newOwned)
                        net.Send(ply)
                    end)
                end,
                function(err)
                    print(string.format("[PlayerModelVendor DB ERROR] Failed to insert purchase into MySQL for %s (%s): %s", ply:Nick(), normPlySteamID64, err))
                    ply:SetNWInt("Currency", currentMoney)
                    GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                        net.Start("BG_PlayerModelVendor_PurchaseResult"); net.WriteBool(false); net.WriteString("Failed to save purchase to database."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
                    end)
                end
            )
        else
            GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                net.Start("BG_PlayerModelVendor_PurchaseResult")
                    net.WriteBool(false)
                    net.WriteString(string.format("Not enough money! (Need: %d, Have: %d)", price, currentMoney))
                    net.WriteTable(currentAvail)
                    net.WriteTable(currentOwn)
                net.Send(ply)
            end)
        end
    end)
end)

net.Receive("BG_PlayerModelVendor_EquipOwnedModel", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local modelPathToEquip = net.ReadString()
    local modelPathToEquipKey = string.lower(modelPathToEquip)

    if not modelPathToEquipKey or modelPathToEquipKey == "" then
        GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
            net.Start("BG_PlayerModelVendor_EquipResult"); net.WriteBool(false); net.WriteString("Invalid model path to equip."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
        end)
        return
    end

    local normPlySteamID64 = getNormalizedSteamID64(ply:SteamID64())
    if not normPlySteamID64 then
        print("[PlayerModelVendor ERROR Equip] Failed to normalize SteamID for equip: " .. tostring(ply:SteamID64()))
        GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
             net.Start("BG_PlayerModelVendor_EquipResult"); net.WriteBool(false); net.WriteString("Error processing your SteamID for equip."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
        end)
        return
    end

    if not db or type(db.query) ~= "function" then
        print("[PlayerModelVendor DB ERROR] Database not connected or invalid. Cannot verify ownership for equip.")
         GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
            net.Start("BG_PlayerModelVendor_EquipResult"); net.WriteBool(false); net.WriteString("Database error, cannot equip model."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
        end)
        return
    end

    local query_str = "SELECT COUNT(*) as count FROM player_owned_models WHERE steam_id_64 = ? AND model_path = ?;"
    db:query(query_str, {normPlySteamID64, modelPathToEquipKey},
        function(queryData)
            if queryData and queryData[1] and queryData[1].count > 0 then
                if string.lower(ply:GetModel()) == modelPathToEquipKey then
                    GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                        net.Start("BG_PlayerModelVendor_EquipResult"); net.WriteBool(false); net.WriteString("You already have this model equipped."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
                    end)
                    return
                end

                print("[PlayerModelVendor] Player " .. ply:Nick() .. " (" .. normPlySteamID64 .. ") equipping owned model: " .. modelPathToEquipKey)
                local oldPos, oldAng = ply:GetPos(), ply:GetAngles()
                ply:SetModel(modelPathToEquip)
                ply:SetPos(oldPos); ply:SetAngles(oldAng)

                local modelName = (player_model_vendor.ServerModels[modelPathToEquipKey] and player_model_vendor.ServerModels[modelPathToEquipKey].Name) or player_model_vendor.GetNameFromModelPath(modelPathToEquip)

                GetModelListsForPlayer(ply, function(newAvailable, newOwned)
                    net.Start("BG_PlayerModelVendor_EquipResult")
                        net.WriteBool(true)
                        net.WriteString("Successfully equipped " .. modelName .. "!")
                        net.WriteTable(newAvailable)
                        net.WriteTable(newOwned)
                    net.Send(ply)
                end)
            else
                GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                    net.Start("BG_PlayerModelVendor_EquipResult"); net.WriteBool(false); net.WriteString("You do not own this model (" .. modelPathToEquipKey .. ")."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
                end)
            end
        end,
        function(err)
            print(string.format("[PlayerModelVendor DB ERROR] Failed to check ownership in MySQL for %s (%s): %s", ply:Nick(), normPlySteamID64, err))
            GetModelListsForPlayer(ply, function(currentAvail, currentOwn)
                net.Start("BG_PlayerModelVendor_EquipResult"); net.WriteBool(false); net.WriteString("Error checking model ownership."); net.WriteTable(currentAvail); net.WriteTable(currentOwn); net.Send(ply)
            end)
        end
    )
end)


concommand.Add("pmv_rescan_models", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() and ply ~= NULL then
        ply:ChatPrint("You must be an admin to use this command!")
        return
    end
    player_model_vendor.LoadAndPrepareServerModels(true)
    if IsValid(ply) and ply ~= NULL then ply:ChatPrint("Model rescan complete.") end
end)


concommand.Add("pmv_inspect_owned_db", function(ply_admin, cmd, args)
    if IsValid(ply_admin) and not ply_admin:IsAdmin() and ply_admin ~= NULL then
        ply_admin:ChatPrint("You must be an admin to use this command!")
        return
    end

    local targetIdentifier = args[1]
    if not targetIdentifier then
        if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint("Usage: pmv_inspect_owned_db <SteamID64 or NicknamePart>") end
        print("Usage: pmv_inspect_owned_db <SteamID64 or NicknamePart>")
        return
    end

    local targetPly = nil
    local normalizedInputID = getNormalizedSteamID64(targetIdentifier)

    if normalizedInputID then
        for _, p in ipairs(player.GetAll()) do
            if getNormalizedSteamID64(p:SteamID64()) == normalizedInputID then targetPly = p; break; end
        end
    end
    if not IsValid(targetPly) then
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(targetIdentifier), 1, true) then targetPly = p; break; end
        end
    end


    local steamIDToInspect
    if IsValid(targetPly) then
        steamIDToInspect = getNormalizedSteamID64(targetPly:SteamID64())
        if steamIDToInspect then
            local msg = "[PlayerModelVendor DB INSPECT] Inspecting online player: " .. targetPly:Nick() .. " (Normalized ID: " .. steamIDToInspect .. ")"
            if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(msg) end; print(msg)
        else
             local failMsg = "[PlayerModelVendor DB INSPECT] Could not normalize SteamID for online player: " .. targetPly:Nick()
             if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(failMsg) end; print(failMsg)
             return
        end
    else
        steamIDToInspect = normalizedInputID
        if steamIDToInspect then
            local msg = "[PlayerModelVendor DB INSPECT] No online player matched. Assuming input is SteamID. Inspecting normalized ID: " .. steamIDToInspect
            if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(msg) end; print(msg)
        else
            local failMsg = "[PlayerModelVendor DB INSPECT] Input identifier '" .. targetIdentifier .. "' could not be normalized to a valid SteamID format."
            if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(failMsg) end; print(failMsg)
            return
        end
    end

    if not db or type(db.query) ~= "function" then
        print("[PlayerModelVendor DB INSPECT ERROR] Database not connected or invalid.")
        if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint("Database error during inspection.") end
        return
    end

    FetchOwnedModelsForPlayerFromDB(steamIDToInspect, function(ownedMap)
        if table.Count(ownedMap) > 0 then
            local listMsg = "[PlayerModelVendor DB INSPECT] Models owned by " .. steamIDToInspect .. " (MySQL):"
            if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(listMsg) end; print(listMsg)
            for modelPath, _ in pairs(ownedMap) do
                local itemMsg = "  - " .. modelPath
                if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(itemMsg) end; print(itemMsg)
            end
        else
            local noneMsg = "[PlayerModelVendor DB INSPECT] No models found in MySQL DB for " .. steamIDToInspect
            if IsValid(ply_admin) and ply_admin ~= NULL then ply_admin:ChatPrint(noneMsg) end; print(noneMsg)
        end
    end)
end)


print("--- [NPC PlayerModelVendor SCRIPT] init.lua loaded successfully (MySQL Integration - Robust Callback Handling & pcall Debug for Create Table) ---")