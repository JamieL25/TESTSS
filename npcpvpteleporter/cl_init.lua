-- NPC PvP Teleporter Entity
-- cl_init.lua - Client-side code
-- Updated: 2025-05-05 13:35:45 by JamieL25

include("shared.lua")

-- Draw distance for text and info
local MAX_DRAW_DISTANCE = 1000
local TEXT_COLOR = Color(255, 255, 100)

-- Initialize client-side
function ENT:Initialize()
    -- Force proper model loading
    self:SetModel("models/player/PMC_1/PMC__01.mdl")
    
    -- Set fixed pose parameters
    self:SetPoseParameter("move_x", 0)
    self:SetPoseParameter("move_y", 0)
    self:SetPoseParameter("aim_pitch", 0)
    self:SetPoseParameter("aim_yaw", 0)
    
    -- Force bone cache update
    self:InvalidateBoneCache()
end

-- Regular client-side thinking
function ENT:Think()
    -- Make sure we're always visible
    self:SetNoDraw(false)
    self:DrawShadow(true)
    
    -- Keep pose parameters set
    self:SetPoseParameter("move_x", 0)
    self:SetPoseParameter("move_y", 0)
    self:SetPoseParameter("aim_pitch", 0)
    self:SetPoseParameter("aim_yaw", 0)
end

-- Draw the entity
function ENT:Draw()
    -- Always make sure we're visible
    self:DrawModel()
    
    -- Draw text above the NPC when close enough
    local pos = self:GetPos()
    local myPos = LocalPlayer():GetPos()
    
    -- Only draw text when close enough
    if pos:Distance(myPos) < MAX_DRAW_DISTANCE then
        -- Calculate position above the NPC's head
        local textPos = pos + Vector(0, 0, 75)
        
        -- Draw text
        cam.Start3D2D(textPos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.1)
            draw.SimpleTextOutlined("PvP Teleporter", "DermaLarge", 0, 0, TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
            draw.SimpleTextOutlined("Press E to deploy", "DermaLarge", 0, 50, TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
        cam.End3D2D()
    end
end

-- REMOVED: DrawTranslucent function that was adding the glow effect

-- REMOVED: PreDrawHalos hook that was adding the halo effect