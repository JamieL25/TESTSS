net.Receive("BG_PlayerModelVendor_OpenMenu", function()
    local models = net.ReadTable()

    if IsValid(vendorMenu) then
        vendorMenu:Remove()
    end

    -- Create main frame
    vendorMenu = vgui.Create("DFrame")
    vendorMenu:SetSize(ScrW(), ScrH())  -- Fullscreen
    vendorMenu:Center()
    vendorMenu:SetTitle("Player Model Shop")
    vendorMenu:MakePopup()

    -- Style the frame
    vendorMenu.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 250))
        draw.RoundedBox(8, 0, 0, w, 24, Color(60, 60, 60, 250))
    end

    -- Create panel to split left and right sections
    local splitPanel = vgui.Create("DPanel", vendorMenu)
    splitPanel:Dock(FILL)
    splitPanel:DockMargin(10, 10, 10, 10)

    -- Left Panel for model selection
    local leftPanel = vgui.Create("DPanel", splitPanel)
    leftPanel:Dock(LEFT)
    leftPanel:SetWidth(vendorMenu:GetWide() * 0.4)  -- 40% width
    leftPanel:DockMargin(10, 10, 10, 10)

    -- Right Panel for model preview
    local rightPanel = vgui.Create("DPanel", splitPanel)
    rightPanel:Dock(RIGHT)
    rightPanel:SetWidth(vendorMenu:GetWide() * 0.6)  -- 60% width
    rightPanel:DockMargin(10, 10, 10, 10)

    -- Scroll panel for model list (Left panel)
    local scroll = vgui.Create("DScrollPanel", leftPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    -- Grid to display model items
    local grid = vgui.Create("DGrid", scroll)
    grid:Dock(FILL)
    grid:SetCols(1)
    grid:SetRowHeight(70)

    -- Loop through the models and add them to the grid
    for i, modelData in ipairs(models) do
        local itemPanel = vgui.Create("DPanel")
        itemPanel:SetSize(240, 60)
        
        -- Style the item panel
        itemPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 250))
        end

        -- Model name label
        local nameLabel = vgui.Create("DLabel", itemPanel)
        nameLabel:SetPos(10, 10)
        nameLabel:SetSize(220, 20)
        nameLabel:SetText(modelData.Name)
        nameLabel:SetTextColor(Color(255, 255, 255))
        nameLabel:SetFont("DermaDefaultBold")

        -- Price label
        local priceLabel = vgui.Create("DLabel", itemPanel)
        priceLabel:SetPos(10, 30)
        priceLabel:SetSize(220, 20)
        priceLabel:SetText("Price: £" .. modelData.Price)
        priceLabel:SetTextColor(Color(255, 255, 255))

        -- Select button
        local selectButton = vgui.Create("DButton", itemPanel)
        selectButton:SetPos(140, 30)
        selectButton:SetSize(90, 25)
        selectButton:SetText("Select")
        selectButton.DoClick = function()
            -- Update the preview model
            previewModel:SetModel(modelData.Model)
        end

        -- Style the select button
        selectButton.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 170, 100) or Color(80, 150, 80)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end

        grid:AddItem(itemPanel)
    end

    -- Right panel for model preview
    local previewModel = vgui.Create("DModelPanel", rightPanel)
    previewModel:SetSize(rightPanel:GetWide() - 20, rightPanel:GetTall() - 20)
    previewModel:SetPos(10, 10)

    -- Default model preview (First model from list)
    previewModel:SetModel(models[1].Model)
    previewModel:SetFOV(40)

    -- Center the camera on the model
    local mn, mx = previewModel.Entity:GetRenderBounds()
    local size = 0
    size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
    size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
    size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
    previewModel:SetCamPos(Vector(size, size, size / 2))
    previewModel:SetLookAt((mn + mx) * 0.5)

    -- Rotate the model in the preview
    function previewModel:LayoutEntity(ent)
        ent:SetAngles(Angle(0, RealTime() * 50, 0))  -- Rotate model around the Y-axis
    end
end)
