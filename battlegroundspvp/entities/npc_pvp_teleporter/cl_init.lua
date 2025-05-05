-- File: gamemodes/battlegroundspvp/gamemode/entities/npc_pvp_teleporter/cl_init.lua (Client-Side) - Revised

include('shared.lua')

-- Draw function called each frame for the entity on the client
function ENT:Draw()
    -- Simple check if the function is being called at all (check client console)
    -- print("DEBUG: npc_pvp_teleporter ENT:Draw called") -- Uncomment this line temporarily for debugging if needed

    -- Draw the NPC model itself first
    self:DrawModel()

    -- Prepare text drawing settings
    local text = "Deploy To PvP Zone"
    local font = "DermaDefaultBold" -- Standard readable font
    local textColor = Color(255, 255, 0, 255) -- Yellow text
    local textAlpha = 255 -- Start fully opaque

    -- Calculate distance for potential fading (optional, but good practice)
    local distance = LocalPlayer():GetPos():Distance(self:GetPos())
    local maxDist = 500 -- Max distance to see text
    local minDist = 200 -- Distance at which text is fully opaque

    -- Fade text out as player moves away (or hide completely if too far)
    if distance > maxDist then
        return -- Don't draw if too far
    elseif distance > minDist then
        -- Calculate fade based on distance between minDist and maxDist
        textAlpha = 255 * (1 - (distance - minDist) / (maxDist - minDist))
    end

    -- Ensure alpha doesn't go below 0
    textAlpha = math.max(textAlpha, 0)
    textColor.a = textAlpha -- Apply calculated alpha to the text color

    -- Calculate position reliably above the NPC's bounding box
    -- Using OBBMaxs().z gets the top extent of the entity's collision box
    local posAboveHead = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 15) -- Increased offset slightly to 15

    -- Use 3D2D drawing for text that faces the player
    -- Increased scale slightly to 0.25
    cam.Start3D2D(posAboveHead, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.25)
        -- Calculate text width for centering
        surface.SetFont(font)
        local textWidth, textHeight = surface.GetTextSize(text)

        -- Draw the text centered
        -- Note: Using textAlpha in the color variable handles fading
        draw.DrawText(text, font, -textWidth / 2, -textHeight / 2, textColor, TEXT_ALIGN_LEFT) -- Align left within the 3D2D space (centering is done by offsetting x by -textWidth/2)

    cam.End3D2D()

end

-- Function to check if the entity should be drawn (standard)
function ENT:DrawTranslucent(flags)
    -- Check if we have transparency before bothering to draw
    if self:GetColor().a <= 0 then return end

    -- If distance demands text transparency, draw the entity translucently too potentially
    local distance = LocalPlayer():GetPos():Distance(self:GetPos())
    local maxDist = 500 -- Match the distance from ENT:Draw

    if distance > maxDist then return end -- Don't draw if too far anyway

    -- Call the main draw function
    self:Draw(flags)
end