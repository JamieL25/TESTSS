-- shared.lua
DeriveGamemode("sandbox")
DEFINE_BASECLASS("sandbox")

GM.Name    = "BattleGrounds [PvP]"
GM.Author  = "JamieL"
GM.Email   = ""
GM.Website = ""

function GM:Initialize()
    -- Called on both client & server
end

print("Military Gamemode - shared.lua loaded")
