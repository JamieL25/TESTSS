-- lua/entities/player_model_vendor/shared.lua

print("--- [NPC PlayerModelVendor SCRIPT] shared.lua loading (Owned Models Update) ---")

ENT = ENT or {}

ENT.Type                = "ai"
ENT.Base                = "base_ai"
ENT.PrintName           = "Player Model Vendor"
ENT.Author              = "JamieL25"
ENT.Category            = "Jamie's NPCs" -- Or your preferred category
ENT.Spawnable           = true
ENT.AdminSpawnable      = true
ENT.RenderGroup         = RENDERGROUP_OPAQUE
ENT.Model               = "models/props_c17/oildrum001.mdl" -- Icon for Q Menu
ENT.AutomaticFrameAdvance = true

-- Network Strings:
-- The actual util.AddNetworkString calls are in init.lua (server-side).
-- This is a reference list of net strings used by this addon.
--
-- BG_PlayerModelVendor_OpenMenu
-- BG_PlayerModelVendor_AttemptPurchase
-- BG_PlayerModelVendor_PurchaseResult
-- BG_PlayerModelVendor_Admin_GetServerModels
-- BG_PlayerModelVendor_Admin_SendServerModels
-- BG_PlayerModelVendor_Admin_UpdateModelSettings
-- BG_PlayerModelVendor_Admin_ActionResponse
--
-- BG_PlayerModelVendor_EquipOwnedModel (New: Client to Server to equip an owned model)
-- BG_PlayerModelVendor_EquipResult     (New: Server to Client with result of equipping)

player_model_vendor = player_model_vendor or {}
-- Default prices are now primarily managed in init.lua's player_model_vendor table setup

-- Function to get a display name from a model path (used by both server and client)
function player_model_vendor.GetNameFromModelPath(path)
    if not path or path == "" then return "Unknown Model" end
    local name = string.match(path, "([^/]+)%.mdl$")
    if not name then
        name = string.match(path, "([^/\\]+)$") -- Fallback if no .mdl extension
    end
    name = name or "Unknown Model"

    name = name:gsub("_", " ") -- Replace underscores with spaces

    -- Attempt to capitalize words nicely
    local words = {}
    for word in string.gmatch(name, "%S+") do
        table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.lower(string.sub(word, 2)))
    end
    name = table.concat(words, " ")

    -- Specific common capitalizations (can be expanded)
    name = name:gsub("Female", "Female"):gsub("Male", "Male"):gsub("Citizen", "Citizen")
    name = name:gsub("Police", "Police"):gsub("Combine", "Combine"):gsub("Soldier", "Soldier")
    name = name:gsub("Pmc", "PMC"):gsub("Alyx", "Alyx"):gsub("Barney", "Barney")


    return string.Trim(name)
end

print("--- [NPC PlayerModelVendor SCRIPT] shared.lua finished loading (Owned Models Update) ---")
