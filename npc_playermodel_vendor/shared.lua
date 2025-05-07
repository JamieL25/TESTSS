ENT = ENT or {}

ENT.Base = "base_ai"
ENT.Type = "ai"

ENT.PrintName = "Player Model Vendor"
ENT.Author = "JamieL25"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.Category = "Jamie's NPCs"

-- Player Models
ENT.PlayerModels = {
    { Name = "Citizen Male 01", Model = "models/player/group01/male_01.mdl", Price = 100 },
    { Name = "Citizen Male 02", Model = "models/player/group01/male_02.mdl", Price = 100 },
    { Name = "Citizen Female 01", Model = "models/player/group01/female_01.mdl", Price = 100 },
    { Name = "Citizen Female 02", Model = "models/player/group01/female_02.mdl", Price = 100 },
    { Name = "Combine Soldier", Model = "models/player/combine_soldier.mdl", Price = 500 },
    { Name = "Police", Model = "models/player/police.mdl", Price = 300 },
    { Name = "Barney", Model = "models/player/barney.mdl", Price = 250 },
    { Name = "Alyx", Model = "models/player/alyx.mdl", Price = 400 }
}

if SERVER then
    util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
    util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
    util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")
end

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "NPCState")
end