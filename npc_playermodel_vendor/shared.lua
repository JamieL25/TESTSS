-- NPC Player Model Vendor Entity
-- shared.lua - Shared configuration and functions
-- Updated: 2025-05-07 16:47:09 by JamieL25

ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Player Model Vendor"
ENT.Author = "JamieL25"
ENT.Category = "Player Models"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Network strings
if SERVER then
    util.AddNetworkString("BG_PlayerModelVendor_OpenMenu")
    util.AddNetworkString("BG_PlayerModelVendor_AttemptPurchase")
    util.AddNetworkString("BG_PlayerModelVendor_PurchaseResult")
    util.AddNetworkString("BG_PlayerModelVendor_UpdateOwned")
    util.AddNetworkString("BG_PlayerModelVendor_RequestModels")
    util.AddNetworkString("BG_PlayerModelVendor_ToggleBlacklist")
    util.AddNetworkString("BG_PlayerModelVendor_SetPrice")
    util.AddNetworkString("BG_PlayerModelVendor_UseModel")
end

-- Shared Config table
PLAYERMODEL_VENDOR = PLAYERMODEL_VENDOR or {}
PLAYERMODEL_VENDOR.Config = {
    blacklist = {},
    prices = {},
    default_price = 1000
}