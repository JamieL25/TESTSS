-- sv_shoplogic.lua - Server-Side Shop Logic (v1.9.4 - Added spacing, Expanded Functions, Hooks)
print("[Shop] Loading sv_shoplogic.lua v1.9.4")

-- network strings
local NET_BUY            = "BuyWeapon"
local NET_BUY_AMMO       = "BuyAmmo"
local NET_SEND_BLACKLIST = "SendShopBlacklist"
local NET_SEND_OVERRIDES = "SendShopCategoryOverrides"
local NET_SEND_OWNED     = "SendOwnedWeapons"
local NET_EQUIP          = "EquipWeapon"
local NET_UPDATE_CURRENCY= "UpdateCurrency"

-- data files
local BLACKLIST_FILE     = "f4shop_blacklist.txt"
local OVERRIDES_FILE     = "f4shop_category_overrides.txt"
local OWNED_FILE         = "f4shop_owned.txt"
local EQUIPPED_FILE      = "f4shop_equipped.txt"

-- shop constants
local STARTER_WEAPON     = "cw_ak74"
local AMMO_PACK_COST     = 100
local AMMO_PACK_AMOUNT   = 80
local MAX_EQUIPPED_OWNED = 2
local SAVE_INTERVAL      = 600 -- Seconds between periodic saves (600 = 10 minutes)

-- in-memory tables
WeaponShopBlacklist        = WeaponShopBlacklist or {}
WeaponShopCategoryOverrides= WeaponShopCategoryOverrides or {}
WeaponShopOwnership        = WeaponShopOwnership or {}
PlayerEquippedShopWeapons  = PlayerEquippedShopWeapons or {}

---------------------------------------------------------------------------
-- Data Loading/Saving Functions
---------------------------------------------------------------------------

-- load a newline file into a set (stores keys as lowercase)
local function LoadSetFile(path)
    local t = {}
    if file.Exists(path, "DATA") then
        local content = file.Read(path, "DATA") or ""
        for _, line in ipairs(string.Explode("\n", content)) do
            line = string.Trim(line)
            if line ~= "" then t[string.lower(line)] = true end
        end
    end
    print("[Shop] Loaded blacklist: " .. table.Count(t) .. " items from " .. path)
    return t
end

-- save a set back to disk
local function SaveSetFile(path, set)
    local list = {}
    for k in pairs(set) do table.insert(list, k) end
    table.sort(list)
    file.Write(path, table.concat(list, "\n"))
    print("[Shop] Saved blacklist (" .. table.Count(set) .. " items) to " .. path)
end

-- load KV overrides
local function LoadOverrides()
    if file.Exists(OVERRIDES_FILE, "DATA") then
        local overrides = util.KeyValuesToTable(file.Read(OVERRIDES_FILE, "DATA")) or {}
        print("[Shop] Loaded category overrides: " .. table.Count(overrides) .. " items from " .. OVERRIDES_FILE)
        return overrides
    end
    print("[Shop] Category overrides file not found: " .. OVERRIDES_FILE)
    return {}
end

-- save KV overrides
local function SaveOverrides()
    file.Write(OVERRIDES_FILE, util.TableToKeyValues(WeaponShopCategoryOverrides))
    print("[Shop] Saved category overrides (" .. table.Count(WeaponShopCategoryOverrides) .. " items) to " .. OVERRIDES_FILE)
end

-- load ownership from JSON
local function LoadOwnership()
    if file.Exists(OWNED_FILE, "DATA") then
        local content = file.Read(OWNED_FILE,"DATA") or ""
        local success, decoded = pcall(util.JSONToTable, content)
        if success and type(decoded) == "table" then WeaponShopOwnership = decoded
        else print("[Shop Error] Failed to decode ownership JSON: " .. tostring(decoded)); WeaponShopOwnership = {} end
    else WeaponShopOwnership = {} end
    print("[Shop] Loaded ownership data for " .. table.Count(WeaponShopOwnership) .. " players from " .. OWNED_FILE)
end

-- save ownership to JSON
local function SaveOwnership()
    local success, encoded = pcall(util.TableToJSON, WeaponShopOwnership, true)
    if success then file.Write(OWNED_FILE, encoded); print("[Shop] Saved ownership data for " .. table.Count(WeaponShopOwnership) .. " players to " .. OWNED_FILE)
    else print("[Shop Error] Failed to encode ownership JSON: " .. tostring(encoded)) end
end

-- Load equipped weapons from JSON
local function LoadEquippedWeapons()
    if file.Exists(EQUIPPED_FILE, "DATA") then
        local data = file.Read(EQUIPPED_FILE, "DATA") or ""
        if data == "" then print("[Shop] Equipped weapons file is empty: " .. EQUIPPED_FILE); PlayerEquippedShopWeapons = {}; return end
        local success, decoded = pcall(util.JSONToTable, data)
        if success and type(decoded) == "table" then PlayerEquippedShopWeapons = decoded; print("[Shop] Loaded equipped weapon data for " .. table.Count(PlayerEquippedShopWeapons) .. " players from " .. EQUIPPED_FILE)
        else print("[Shop Error] Failed to decode equipped weapons JSON from " .. EQUIPPED_FILE .. ": " .. tostring(decoded)); PlayerEquippedShopWeapons = {} end
    else print("[Shop] Equipped weapons file not found: " .. EQUIPPED_FILE .. ". Starting fresh."); PlayerEquippedShopWeapons = {} end
end

-- Save equipped weapons to JSON (Writes {} if empty)
local function SaveEquippedWeapons()
    local dataToSave = PlayerEquippedShopWeapons or {}
    local playerCount = table.Count(dataToSave)
    local success, encoded = pcall(util.TableToJSON, dataToSave, true)
    if success then file.Write(EQUIPPED_FILE, encoded); print("[Shop] Saved equipped weapon data for " .. playerCount .. " players to " .. EQUIPPED_FILE)
    else print("[Shop Error] Failed to encode equipped weapons table to JSON: " .. tostring(encoded)) end
end

---------------------------------------------------------------------------
-- Networking / Helper Functions
---------------------------------------------------------------------------

-- send blacklist array to a player
local function SendBlacklistTo(ply)
    if not IsValid(ply) then return end
    local arr = {}
    for cls in pairs(WeaponShopBlacklist) do table.insert(arr, cls) end
    net.Start(NET_SEND_BLACKLIST); net.WriteTable(arr); net.Send(ply)
end

-- Function to save blacklist and notify all players
local function UpdateAndBroadcastBlacklist()
    SaveSetFile(BLACKLIST_FILE, WeaponShopBlacklist)
    for _, p in ipairs(player.GetAll()) do if IsValid(p) then SendBlacklistTo(p) end end
    print("[Shop] Broadcasted updated blacklist to all players (" .. #player.GetAll() .. ").")
end

-- send overrides table to a player
local function SendOverridesTo(ply)
    if not IsValid(ply) then return end
    net.Start(NET_SEND_OVERRIDES); net.WriteTable(WeaponShopCategoryOverrides); net.Send(ply)
end

-- send owned-weapons (plus starter) to a player
local function SendOwnedTo(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID(); local owned = table.Copy(WeaponShopOwnership[sid] or {}); owned[STARTER_WEAPON] = true
    net.Start(NET_SEND_OWNED); net.WriteTable(owned); net.Send(ply)
end

-- Function to update currency and notify client
local function UpdatePlayerCurrency(ply, newAmount)
    if not IsValid(ply) then return end
    ply:SetNWInt("Currency", newAmount); net.Start(NET_UPDATE_CURRENCY); net.WriteInt(newAmount, 32); net.Send(ply)
    print("[Shop] Updated currency for " .. ply:Nick() .. " to £" .. newAmount)
end

-- Function to handle ammo purchase logic
local function TryPurchaseAmmo(ply, cost, amount)
    if not IsValid(ply) then return false end
    local cash = ply:GetNWInt("Currency", 0) -- Use 'cash'
    print("[Shop] " .. ply:Nick() .. " is attempting to buy " .. amount .. " ammo for £" .. cost)
    if cash < cost then -- Use 'cash'
        ply:ChatPrint("Not enough money (£" .. cost .. " required)."); print("[Shop] Ammo Purchase failed: Insufficient funds"); return false
    end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then
        ply:ChatPrint("You need to be holding a weapon to buy ammo for it."); print("[Shop] Ammo Purchase failed: No active weapon"); return false
    end
    local ammoType = wep:GetPrimaryAmmoType()
    if not ammoType or ammoType == "" or ammoType == "none" then
        ammoType = wep:GetSecondaryAmmoType()
        if not ammoType or ammoType == "" or ammoType == "none" then
            ply:ChatPrint("This weapon does not use standard ammo."); print("[Shop] Ammo Purchase failed: Weapon uses no standard ammo type"); return false
        end
        print("[Shop Debug] Using secondary ammo type: " .. ammoType)
    end
    UpdatePlayerCurrency(ply, cash - cost) -- Use 'cash'
    ply:GiveAmmo(amount, ammoType, false)
    ply:ChatPrint("You bought " .. amount .. " rounds of " .. game.GetAmmoName(ammoType) .. " ammo.")
    print("[Shop] " .. ply:Nick() .. " successfully purchased " .. amount .. " " .. ammoType .. " ammo.")
    return true
end

---------------------------------------------------------------------------
-- Initialization Hook
---------------------------------------------------------------------------
hook.Add("Initialize","Shop_Init",function()
    -- Define network strings in a table first
    local netStringsToRegister = {
        NET_BUY,
        NET_BUY_AMMO,
        NET_SEND_BLACKLIST,
        NET_SEND_OVERRIDES,
        NET_SEND_OWNED,
        NET_EQUIP,
        NET_UPDATE_CURRENCY
    }
    -- Loop through the table to register them
    for _, name in ipairs(netStringsToRegister) do
        util.AddNetworkString(name)
    end

    -- Load data files
    WeaponShopBlacklist = LoadSetFile(BLACKLIST_FILE)
    WeaponShopCategoryOverrides = LoadOverrides()
    LoadOwnership()
    LoadEquippedWeapons()
    print("[Shop] sv_shoplogic.lua initialized.")

    -- Removed _G.ShopBridge assignment

    -- Start periodic save timer
    if timer.Exists("Shop_PeriodicDataSave") then timer.Remove("Shop_PeriodicDataSave") end
    timer.Create("Shop_PeriodicDataSave", SAVE_INTERVAL, 0, function() if not timer.Exists("Shop_PeriodicDataSave") then print("[Shop Error] Periodic save timer missing!") return end; print("[Shop] Performing periodic data save..."); SaveOwnership(); SaveEquippedWeapons(); print("[Shop] Periodic data save complete.") end)
    print("[Shop] Started periodic data saving every " .. SAVE_INTERVAL .. " seconds.")
end) -- End of Initialize hook


---------------------------------------------------------------------------
-- Hooks for Gamemode Data Access
---------------------------------------------------------------------------
hook.Add("GetShopEquippedWeapons", "ShopHook_GetEquipped", function(ply)
    if not IsValid(ply) then return nil end; local sid = ply:SteamID()
    return PlayerEquippedShopWeapons[sid]
end)

hook.Add("GetShopOwnedWeapons", "ShopHook_GetOwned", function(ply)
    if not IsValid(ply) then return nil end; local sid = ply:SteamID()
    return WeaponShopOwnership[sid]
end)

hook.Add("GetShopStarterWeapon", "ShopHook_GetStarter", function()
    return STARTER_WEAPON
end)


---------------------------------------------------------------------------
-- Player Connection Hooks
---------------------------------------------------------------------------
-- when a player joins, send them data and restore weapons
hook.Add("PlayerInitialSpawn","Shop_SendData",function(ply)
    timer.Simple(1.5, function()
        if not IsValid(ply) then return end; local sid=ply:SteamID()
        print("[Shop] Sending initial shop data and checking equipped weapons for "..ply:Nick())
        SendBlacklistTo(ply); SendOverridesTo(ply); SendOwnedTo(ply); UpdatePlayerCurrency(ply, ply:GetNWInt("Currency",0))
        local pE=PlayerEquippedShopWeapons[sid]
        if pE and #pE>0 then
            print("[Shop] Restoring "..#pE.." equipped weapon(s) for "..ply:Nick()..": ", table.concat(pE,", "))
            local rW={}; local cO=WeaponShopOwnership[sid] or {}; cO[STARTER_WEAPON]=true
            for _,wCls in ipairs(pE) do
                if cO[wCls] then print("[Shop Debug] Giving restored weapon: "..wCls); ply:Give(wCls); table.insert(rW,wCls)
                else print("[Shop Warning] Player "..ply:Nick().." no longer owns previously equipped weapon "..wCls..". Not restoring.") end
            end
            PlayerEquippedShopWeapons[sid]=rW
            if #rW>0 then local lW=rW[#rW]; timer.Simple(0.2, function() if IsValid(ply) and IsValid(ply:GetWeapon(lW)) then ply:SelectWeapon(lW); print("[Shop Debug] Selected last restored weapon: "..lW) end end) end
        else
            print("[Shop Debug] No previously equipped weapons found for "..ply:Nick().." ("..sid.."). Clearing tracking.")
            PlayerEquippedShopWeapons[sid]=nil
        end
    end)
end)

-- Player disconnect hook
hook.Add("PlayerDisconnect", "Shop_PlayerDisconnectInfo", function(ply)
    print("[Shop] Player disconnected: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")")
end)

-- Shutdown hook to save data
hook.Add("Shutdown", "Shop_SaveDataOnShutdown", function()
    print("[Shop Debug] Shutdown hook called!")
    print("[Shop] Server shutting down. Saving shop data...")
    if timer.Exists("Shop_PeriodicDataSave") then timer.Remove("Shop_PeriodicDataSave"); print("[Shop] Stopped periodic save timer.") end
    SaveOwnership()
    SaveEquippedWeapons()
    print("[Shop] Shop data saving complete.")
end)


---------------------------------------------------------------------------
-- Network Receivers
---------------------------------------------------------------------------
-- handle weapon purchases
net.Receive(NET_BUY,function(len,ply)
    if not IsValid(ply) then return end; local cls=net.ReadString(); local p=net.ReadInt(32); local c=ply:GetNWInt("Currency",0)
    print("[Shop] "..ply:Nick().." is attempting to buy "..cls.." for £"..p)
    if WeaponShopBlacklist[string.lower(cls)] then ply:ChatPrint("That weapon is disabled."); print("[Shop] Purchase failed: Weapon '"..cls.."' is blacklisted"); return end
    if c<p then ply:ChatPrint("Not enough money (£"..p.." required)."); print("[Shop] Purchase failed: Insufficient funds"); return end
    local s=ply:SteamID(); UpdatePlayerCurrency(ply,c-p); ply:Give(cls); WeaponShopOwnership[s]=WeaponShopOwnership[s] or {}; WeaponShopOwnership[s][cls]=true; SaveOwnership(); SendOwnedTo(ply)
    ply:ChatPrint("You purchased "..cls); print("[Shop] "..ply:Nick().." successfully purchased "..cls)
end)

-- handle ammo purchases (from button/command)
net.Receive(NET_BUY_AMMO, function(len, ply)
    if not IsValid(ply) then return end; TryPurchaseAmmo(ply, AMMO_PACK_COST, AMMO_PACK_AMOUNT)
end)

-- Function to handle equip logic
local function HandleEquip(ply, cls)
    local sid = ply:SteamID(); local equipped_list = PlayerEquippedShopWeapons[sid] or {}; local current_count = #equipped_list
    -- Check if already equipped
    for i, equipped_cls in ipairs(equipped_list) do
        if equipped_cls == cls then
            print("[Shop Equip Debug] Weapon " .. cls .. " already in tracked list for " .. ply:Nick() .. ". Re-selecting.")
            if IsValid(ply:GetWeapon(cls)) then ply:SelectWeapon(cls); ply:ChatPrint("Re-selected " .. cls .. ".")
            else print("[Shop Equip Debug] Player " .. ply:Nick() .. " didn't have tracked weapon " .. cls .. ". Giving it back."); ply:Give(cls); timer.Simple(0.1, function() if IsValid(ply) then ply:SelectWeapon(cls) end end); ply:ChatPrint("Equipped " .. cls .. ".") end
            return
        end
    end
    -- Limit check and replacement
    local wep_to_remove = nil; local notification = "Equipped " .. cls
    if current_count >= MAX_EQUIPPED_OWNED then
        wep_to_remove = equipped_list[1]
        print("[Shop Equip Debug] Limit ("..MAX_EQUIPPED_OWNED..") reached for " .. ply:Nick() .. ". Removing oldest: " .. wep_to_remove)
        ply:StripWeapon(wep_to_remove); table.remove(equipped_list, 1)
        notification = notification .. " (Replaced " .. wep_to_remove .. ")"
    end
    -- Add new weapon and update tracking table
    table.insert(equipped_list, cls); PlayerEquippedShopWeapons[sid] = equipped_list
    print("[Shop Equip Debug] Updated PlayerEquippedShopWeapons["..sid.."] = ", util.TableToJSON(PlayerEquippedShopWeapons[sid]))
    -- Saving happens periodically or on shutdown
    -- Give and select
    print("[Shop Equip Debug] Giving weapon " .. cls .. " to " .. ply:Nick()); ply:Give(cls); timer.Simple(0.1, function() if IsValid(ply) and IsValid(ply:GetWeapon(cls)) then ply:SelectWeapon(cls) end end)
    ply:ChatPrint(notification .. "."); print("[Shop] " .. ply:Nick() .. " equipped " .. cls .. (wep_to_remove and " (Replaced " .. wep_to_remove .. ")" or ""))
end

-- Handle Equip Network Message
net.Receive(NET_EQUIP,function(len,ply)
    if not IsValid(ply) then return end; local cls = net.ReadString(); local sid = ply:SteamID()
    local owned = WeaponShopOwnership[sid] or {}; owned[STARTER_WEAPON] = true
    print("[Shop Debug] NET_EQUIP received for " .. cls .. " from " .. ply:Nick())
    if not owned[cls] then ply:ChatPrint("You don't own " .. cls .. "!"); print("[Shop] Equip failed: Not owned (" .. cls .. ")"); return end
    HandleEquip(ply, cls)
end)


---------------------------------------------------------------------------
-- Admin Commands Section
---------------------------------------------------------------------------

-- Console command to add money
concommand.Add("shop_addmoney", function(ply, cmd, args)
    local isAdmin = not IsValid(ply) or ply:IsAdmin() or ply:IsSuperAdmin()
    if not isAdmin then
        if IsValid(ply) then ply:ChatPrint("You don't have permission!") end
        return
    end

    local targetPlayer = ply
    local amount = tonumber(args[1] or "0")
    local targetName = nil

    if IsValid(ply) and args[2] then -- Player console: <cmd> <amount> <name>
        targetName = table.concat(args, " ", 2) -- Capture full name
        amount = tonumber(args[1] or "0")
    elseif not IsValid(ply) and args[1] and args[2] then -- Server console: <cmd> <name> <amount>
        targetName = args[1] -- Assume name is first arg
        amount = tonumber(args[2] or "0") -- Amount is second
    elseif not IsValid(ply) and args[1] then -- Server console: <cmd> <amount> (invalid target)
        print("Usage: shop_addmoney <player_name> <amount>")
        return
    end -- If only <cmd> <amount> from player console, targetName remains nil, targetPlayer remains ply

    -- Find target player if name was provided
    if targetName and targetName ~= "" then
        targetPlayer = nil -- Reset before search
        local found = player.Find(targetName)
        if #found == 1 then
            targetPlayer = found[1]
        elseif #found > 1 then
            local msg = "Multiple players match '"..targetName.."'. Be more specific."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        elseif #found == 0 then
            local msg = "Player '"..targetName.."' not found."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
    end

    -- Validate amount
    if not amount or amount <= 0 then
        local msg = "Invalid amount! Usage: shop_addmoney <amount> [partial_player_name]"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    -- Validate target player
    if not IsValid(targetPlayer) then
        local msg = "Target player not found or invalid!"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    -- Perform action
    local currentMoney = targetPlayer:GetNWInt("Currency", 0)
    UpdatePlayerCurrency(targetPlayer, currentMoney + amount)
    local sourceName = IsValid(ply) and ply:Nick() or "Console"
    if IsValid(ply) and ply ~= targetPlayer then
        ply:ChatPrint("Added £"..amount.." to "..targetPlayer:Nick())
    end
    targetPlayer:ChatPrint("You received £"..amount.." from "..sourceName..".")
    print("[Shop Admin] "..sourceName.." gave £"..amount.." to "..targetPlayer:Nick())
    return -- Added explicit return
end, nil, "Gives currency to a player. Usage: shop_addmoney <amount> [player_name]", {FCVAR_GAMEDLL})


-- Console command to add weapon to blacklist
concommand.Add("shop_blacklist_add", function(ply, cmd, args)
    if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("You don't have permission.")
        return
    end
    local wepClass = args[1]
    if not wepClass or wepClass == "" then
        local msg = "Usage: shop_blacklist_add <weapon_class_name>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    wepClass = string.lower(wepClass)
    if WeaponShopBlacklist[wepClass] then
        local msg = "'"..wepClass.."' is already blacklisted."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    WeaponShopBlacklist[wepClass] = true
    UpdateAndBroadcastBlacklist()
    local msg = "Added '"..wepClass.."' to the shop blacklist."
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    print("[Shop Admin] "..(IsValid(ply) and ply:Nick() or "Console").." added '"..wepClass.."' to blacklist.")
    return -- Added explicit return
end, nil, "Adds a weapon class to the shop blacklist.", {FCVAR_GAMEDLL})


-- Console command to remove weapon from blacklist
concommand.Add("shop_blacklist_remove", function(ply, cmd, args)
    if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("You don't have permission.")
        return
    end
    local wepClass = args[1]
    if not wepClass or wepClass == "" then
        local msg = "Usage: shop_blacklist_remove <weapon_class_name>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    wepClass = string.lower(wepClass)
    if not WeaponShopBlacklist[wepClass] then
        local msg = "'"..wepClass.."' is not currently blacklisted."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    WeaponShopBlacklist[wepClass] = nil
    UpdateAndBroadcastBlacklist()
    local msg = "Removed '"..wepClass.."' from the shop blacklist."
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end -- Use 'msg' here
    print("[Shop Admin] "..(IsValid(ply) and ply:Nick() or "Console").." removed '"..wepClass.."' from blacklist.")
    return -- Added explicit return
end, nil, "Removes a weapon class from the shop blacklist.", {FCVAR_GAMEDLL})


-- Extra blank line for safety
-- Chat command processing hook
hook.Add("PlayerSay", "Shop_PlayerSayCommands", function(sender, text, teamChat)
    if not IsValid(sender) then return nil end
    if not text or not (string.StartWith(text, "/") or string.StartWith(text, "!")) then return nil end

    local cmdText = string.lower(text)
    local args = string.Explode(" ", cmdText)
    local cmd = args[1]
    local arg1 = args[2] or ""
    -- Capture all remaining arguments for target name
    local targetNameArgs = {}
    for i = 3, #args do
        table.insert(targetNameArgs, args[i])
    end
    local arg2 = table.concat(targetNameArgs, " ")


    local function IsSenderAdmin()
        -- Consider using your specific admin mod's check here if needed
        return sender:IsAdmin() or sender:IsSuperAdmin()
    end

    -- Ammo purchase command
    if cmd == "/ammo" or cmd == "!ammo" then
        print("[Shop Debug] /ammo command received from " .. sender:Nick())
        TryPurchaseAmmo(sender, AMMO_PACK_COST, AMMO_PACK_AMOUNT)
        return "" -- Suppress chat message
    end

    -- Add money command
    if cmd == "/addmoney" or cmd == "!addmoney" then
        if not IsSenderAdmin() then
            sender:ChatPrint("You don't have permission.")
            return ""
        end
        local amount = tonumber(arg1)
        local targetName = arg2 -- Use the rest of the string
        if not amount or amount <= 0 then
            sender:ChatPrint("Usage: " .. cmd .. " <amount> [partial_player_name]")
            return ""
        end
        local targetPlayer = sender
        if targetName and targetName ~= "" then
            local foundPlayers = player.Find(targetName)
            if #foundPlayers == 0 then
                sender:ChatPrint("Player '"..targetName.."' not found.")
                return ""
            elseif #foundPlayers > 1 then
                sender:ChatPrint("Multiple players match '"..targetName.."'. Be more specific.")
                return ""
            else
                targetPlayer = foundPlayers[1]
            end
        end
        if not IsValid(targetPlayer) then
            sender:ChatPrint("Target player is not valid.")
            return ""
        end
        local currentMoney = targetPlayer:GetNWInt("Currency", 0)
        UpdatePlayerCurrency(targetPlayer, currentMoney + amount)
        if sender ~= targetPlayer then
            sender:ChatPrint("Added £"..amount.." to "..targetPlayer:Nick())
        end
        targetPlayer:ChatPrint("You receive £"..amount.." from "..sender:Nick()..".")
        print("[Shop Admin] "..sender:Nick().." gave £"..amount.." to "..targetPlayer:Nick())
        return ""
    end

    -- Blacklist Add command
    if cmd == "/blacklistadd" or cmd == "!blacklistadd" then
        if not IsSenderAdmin() then
            sender:ChatPrint("You don't have permission.")
            return ""
        end
        local wepClass = arg1 -- Class name is first argument
        if not wepClass or wepClass == "" then
            sender:ChatPrint("Usage: " .. cmd .. " <weapon_class_name>")
            return ""
        end
        wepClass = string.lower(wepClass)
        if WeaponShopBlacklist[wepClass] then
            sender:ChatPrint("'"..wepClass.."' is already blacklisted.")
            return ""
        end
        WeaponShopBlacklist[wepClass] = true
        UpdateAndBroadcastBlacklist()
        sender:ChatPrint("Added '"..wepClass.."' to the shop blacklist.")
        print("[Shop Admin] "..sender:Nick().." added '"..wepClass.."' to blacklist.")
        return ""
    end

    -- Blacklist Remove command
    if cmd == "/blacklistremove" or cmd == "!blacklistremove" then
        if not IsSenderAdmin() then
            sender:ChatPrint("You don't have permission.")
            return ""
        end
        local wepClass = arg1 -- Class name is first argument
        if not wepClass or wepClass == "" then
            sender:ChatPrint("Usage: " .. cmd .. " <weapon_class_name>")
            return ""
        end
        wepClass = string.lower(wepClass)
        if not WeaponShopBlacklist[wepClass] then
            sender:ChatPrint("'"..wepClass.."' is not currently blacklisted.")
            return ""
        end
        WeaponShopBlacklist[wepClass] = nil
        UpdateAndBroadcastBlacklist()
        sender:ChatPrint("Removed '"..wepClass.."' from the shop blacklist.")
        print("[Shop Admin] "..sender:Nick().." removed '"..wepClass.."' from blacklist.")
        return ""
    end

    -- Suppress unrecognized commands starting with / or !
    if string.StartWith(text, "/") or string.StartWith(text, "!") then
        return ""
    end

    -- Allow normal chat
    return nil
end) -- END OF PlayerSay HOOK


print("[Shop] sv_shoplogic.lua v1.9.4 loaded") -- Updated version number