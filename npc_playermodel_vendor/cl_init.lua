-- Player Model Vendor Entity
-- cl_init.lua - Client-side code
-- Updated: 2025-05-06 20:55:21 by JamieL25

include("shared.lua")

-- Draw distance for text and info
local MAX_DRAW_DISTANCE = 1000
local TEXT_COLOR = Color(255, 255, 100)

-- Create bold font
surface.CreateFont("NPCText_Bold", {
    font = "DermaLarge",
    size = 40,
    weight = 800,  -- This makes it bold (normal is 400)
    antialias = true,
    shadow = false
})

-- Initialize client-side
function ENT:Initialize()
    -- Force proper model loading
    self:SetModel(self:GetModel())
    
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
        local textPos = pos + Vector(0, 0, 85)
        
        -- Draw text with bold font
        cam.Start3D2D(textPos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.1)
            draw.SimpleTextOutlined("Player Model Vendor", "NPCText_Bold", 0, 0, TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
            draw.SimpleTextOutlined("Press E to open shop", "NPCText_Bold", 0, 50, TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
        cam.End3D2D()
    end
end

-- Menu Variables
local vendorMenu = nil

-- Menu Creation and Handling
net.Receive("BG_PlayerModelVendor_OpenMenu", function()
    local models = net.ReadTable()
    
    if IsValid(vendorMenu) then
        vendorMenu:Remove()
    end

    -- Create main frame
    vendorMenu = vgui.Create("DFrame")
    vendorMenu:SetSize(800, 600)
    vendorMenu:Center()
    vendorMenu:SetTitle("Player Model Shop")
    vendorMenu:MakePopup()

    -- Style the frame
    vendorMenu.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 250))
        draw.RoundedBox(8, 0, 0, w, 24, Color(60, 60, 60, 250))
    end

    -- Create scroll panel for model list
    local scroll = vgui.Create("DScrollPanel", vendorMenu)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    -- Grid for model items
    local grid = vgui.Create("DGrid", scroll)
    grid:Dock(FILL)
    grid:SetCols(3)
    grid:SetColWide(250)
    grid:SetRowHeight(280)

    -- Add each model to the grid
    for i, modelData in ipairs(models) do
        local itemPanel = vgui.Create("DPanel")
        itemPanel:SetSize(240, 270)
        
        -- Style the item panel
        itemPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 250))
        end

        -- Model preview panel
        local modelPreview = vgui.Create("DModelPanel", itemPanel)
        modelPreview:SetSize(230, 200)
        modelPreview:SetPos(5, 5)
        modelPreview:SetModel(modelData.Model)
        modelPreview:SetFOV(40)
        
        -- Center the camera on the model
        local mn, mx = modelPreview.Entity:GetRenderBounds()
        local size = 0
        size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
        size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
        size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
        modelPreview:SetCamPos(Vector(size, size, size/2))
        modelPreview:SetLookAt((mn + mx) * 0.5)

        -- Enable rotation
        function modelPreview:LayoutEntity(ent)
            ent:SetAngles(Angle(0, RealTime() * 50, 0))
        end

        -- Model name label
        local nameLabel = vgui.Create("DLabel", itemPanel)
        nameLabel:SetPos(10, 210)
        nameLabel:SetSize(220, 20)
        nameLabel:SetText(modelData.Name)
        nameLabel:SetTextColor(Color(255, 255, 255))
        nameLabel:SetFont("DermaDefaultBold")

        -- Price label
        local priceLabel = vgui.Create("DLabel", itemPanel)
        priceLabel:SetPos(10, 230)
        priceLabel:SetSize(220, 20)
        priceLabel:SetText("Price: £" .. modelData.Price)
        priceLabel:SetTextColor(Color(255, 255, 255))

        -- Buy button
        local buyButton = vgui.Create("DButton", itemPanel)
        buyButton:SetPos(140, 230)
        buyButton:SetSize(90, 25)
        buyButton:SetText("Purchase")
        buyButton.DoClick = function()
            net.Start("BG_PlayerModelVendor_AttemptPurchase")
            net.WriteUInt(i, 8)
            net.SendToServer()
        end

        -- Style the buy button
        buyButton.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 170, 100) or Color(80, 150, 80)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end

        grid:AddItem(itemPanel)
    end
end)

-- Handle purchase results
net.Receive("BG_PlayerModelVendor_PurchaseResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    -- Create notification
    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 3)
    
    -- Play sound
    surface.PlaySound(success and "buttons/button14.wav" or "buttons/button10.wav")
    
    -- Close menu if purchase was successful
    if success and IsValid(vendorMenu) then
        vendorMenu:Close()
    end
end)