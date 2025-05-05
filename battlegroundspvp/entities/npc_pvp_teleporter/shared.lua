print(">>>> DEBUG: LOADING npc_pvp_teleporter SHARED.LUA <<<<") -- DEBUG LINE ADDED

-- File: gamemodes/battlegroundspvp/entities/npc_pvp_teleporter/shared.lua

ENT.Type            = "ai"
ENT.Base            = "base_ai" -- Using base_ai is fine for a static, non-fighting NPC

ENT.PrintName       = "PvP Teleporter"
ENT.Category = "NPCs"  -- Try changing this
ENT.Spawnable       = true -- Allow admins to spawn via spawn menu if needed
ENT.AdminSpawnable  = true

-- Note: AddCSLuaFile() is usually handled by the entity's init.lua including this file.

print(">>>> DEBUG: FINISHED LOADING npc_pvp_teleporter SHARED.LUA <<<<") -- DEBUG LINE ADDED