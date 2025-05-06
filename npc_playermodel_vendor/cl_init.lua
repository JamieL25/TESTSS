-- NPC Player Model Vendor Entity
-- cl_init.lua - Client-side code
-- Updated: 2025-05-06 21:56:35 by JamieL25

include("shared.lua")

-- Draw distance for text and info
local MAX_DRAW_DISTANCE = 1000
local TEXT_COLOR = Color(255, 255, 100)

-- Cache for models and config data
local cachedModels = {}
local cachedConfig = {}
local cachedOwnedModels = {}

-- Create bold font
surface.CreateFont("NPCText_Bold", {
    font = "DermaLarge",
    size = 40,
    weight = 800,
    antialias = true,
    shadow = false
})

-- Initialize client-side
function ENT:Initialize()
    self:SetModel(self:GetModel())
    self:SetPoseParameter("move_x", 0)
    self:SetPoseParameter("move_y", 0)
    self:SetPoseParameter("aim_pitch", 0)
    self:SetPoseParameter("aim_yaw", 0)
    self:InvalidateBoneCache()
end

function ENT:Think()
    self:SetNoDraw(false)
    self:DrawShadow(true)
end

function ENT:Draw()
    self:DrawModel()
    
    local pos = self:GetPos()
    local myPos = LocalPlayer():GetPos()
    
    if pos:Distance(myPos) < MAX_DRAW_DISTANCE then
        local textPos = pos + Vector(0, 0, 85)
        
        cam.Start3D2D(textPos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.1)
            draw.SimpleTextOutlined("Player Model Vendor", "NPCText_Bold", 0, 0, TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
            draw.SimpleTextOutlined("Press E to open shop", "NPCText_Bold", 0, 50, TEXT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0))
        cam.End3D2D()
    end
end

local function CreateModelPanel(parent, modelData, config, isOwned)
    local itemPanel = vgui.Create("DPanel")
    itemPanel:SetSize(240, 270)
    
    itemPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 250))
    end

    local modelPreview = vgui.Create("DModelPanel", itemPanel)
    modelPreview:SetSize(230, 200)
    modelPreview:SetPos(5, 5)
    modelPreview:SetModel(modelData.Model)
    modelPreview:SetFOV(40)
    
    local mn, mx = modelPreview.Entity:GetRenderBounds()
    local size = 0
    size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
    size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
    size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
    modelPreview:SetCamPos(Vector(size, size, size/2))
    modelPreview:SetLookAt((mn + mx) * 0.5)

    function modelPreview:LayoutEntity(ent)
        ent:SetAngles(Angle(0, RealTime() * 50, 0))
    end

    local nameLabel = vgui.Create("DLabel", itemPanel)
    nameLabel:SetPos(10, 210)
    nameLabel:SetSize(220, 20)
    nameLabel:SetText(modelData.Name)
    nameLabel:SetTextColor(Color(255, 255, 255))
    nameLabel:SetFont("DermaDefaultBold")

    if isOwned then
        local useButton = vgui.Create("DButton", itemPanel)
        useButton:SetPos(10, 230)
        useButton:SetSize(220, 25)
        useButton:SetText("Use Model")
        useButton.DoClick = function()
            net.Start("BG_PlayerModelVendor_AttemptPurchase")
            net.WriteString(modelData.Model)
            net.SendToServer()
        end
        useButton.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 170, 100) or Color(80, 150, 80)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
    else
        local priceLabel = vgui.Create("DLabel", itemPanel)
        priceLabel:SetPos(10, 230)
        priceLabel:SetSize(130, 20)
        priceLabel:SetText("Price: £" .. (config.prices[modelData.Model] or config.default_price))
        priceLabel:SetTextColor(Color(255, 255, 255))

        local buyButton = vgui.Create("DButton", itemPanel)
        buyButton:SetPos(140, 230)
        buyButton:SetSize(90, 25)
        buyButton:SetText("Purchase")
        buyButton.DoClick = function()
            net.Start("BG_PlayerModelVendor_AttemptPurchase")
            net.WriteString(modelData.Model)
            net.SendToServer()
        end
        buyButton.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 170, 100) or Color(80, 150, 80)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
    end

    return itemPanel
end

local function RefreshModels(shopGrid, ownedGrid)
    if not IsValid(shopGrid) or not IsValid(ownedGrid) then return end
    
    shopGrid:Clear()
    ownedGrid:Clear()

    for _, modelData in pairs(cachedModels) do
        if table.HasValue(cachedOwnedModels, modelData.Model) then
            local itemPanel = CreateModelPanel(ownedGrid, modelData, cachedConfig, true)
            ownedGrid:AddItem(itemPanel)
        elseif not table.HasValue(cachedConfig.blacklist or {}, modelData.Model) then
            local itemPanel = CreateModelPanel(shopGrid, modelData, cachedConfig, false)
            shopGrid:AddItem(itemPanel)
        end
    end
end

net.Receive("BG_PlayerModelVendor_OpenMenu", function()
    cachedModels = net.ReadTable() or {}
    cachedConfig = util.JSONToTable(net.ReadString()) or {blacklist = {}, prices = {}, default_price = 1000}
    cachedOwnedModels = net.ReadTable() or {}
    
    if IsValid(vendorMenu) then
        vendorMenu:Remove()
    end

    vendorMenu = vgui.Create("DFrame")
    vendorMenu:SetSize(800, 600)
    vendorMenu:Center()
    vendorMenu:SetTitle("Player Model Shop")
    vendorMenu:MakePopup()

    vendorMenu.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 250))
        draw.RoundedBox(8, 0, 0, w, 24, Color(60, 60, 60, 250))
    end

    local tabs = vgui.Create("DPropertySheet", vendorMenu)
    tabs:Dock(FILL)
    tabs:DockMargin(5, 5, 5, 5)

    -- Shop Panel
    local shopPanel = vgui.Create("DPanel", tabs)
    tabs:AddSheet("Shop", shopPanel, "icon16/cart.png")

    -- Owned Panel
    local ownedPanel = vgui.Create("DPanel", tabs)
    tabs:AddSheet("Owned", ownedPanel, "icon16/user.png")

    -- Scroll panels
    local shopScroll = vgui.Create("DScrollPanel", shopPanel)
    shopScroll:Dock(FILL)
    shopScroll:DockMargin(10, 10, 10, 10)

    local ownedScroll = vgui.Create("DScrollPanel", ownedPanel)
    ownedScroll:Dock(FILL)
    ownedScroll:DockMargin(10, 10, 10, 10)

    -- Grids
    local shopGrid = vgui.Create("DGrid", shopScroll)
    shopGrid:Dock(FILL)
    shopGrid:SetCols(3)
    shopGrid:SetColWide(250)
    shopGrid:SetRowHeight(280)

    local ownedGrid = vgui.Create("DGrid", ownedScroll)
    ownedGrid:Dock(FILL)
    ownedGrid:SetCols(3)
    ownedGrid:SetColWide(250)
    ownedGrid:SetRowHeight(280)

    -- Initial population
    RefreshModels(shopGrid, ownedGrid)

    -- Admin Panel
    if LocalPlayer():IsSuperAdmin() then
        local adminPanel = vgui.Create("DPanel", tabs)
        tabs:AddSheet("Admin", adminPanel, "icon16/shield.png")

        local adminControls = vgui.Create("DPanel", adminPanel)
        adminControls:Dock(TOP)
        adminControls:SetHeight(40)
        adminControls:DockMargin(5, 5, 5, 5)

        local blacklistButton = vgui.Create("DButton", adminControls)
        blacklistButton:Dock(LEFT)
        blacklistButton:SetWidth(150)
        blacklistButton:DockMargin(5, 5, 5, 5)
        blacklistButton:SetText("Blacklist Selected")

        local unblacklistButton = vgui.Create("DButton", adminControls)
        unblacklistButton:Dock(LEFT)
        unblacklistButton:SetWidth(150)
        unblacklistButton:DockMargin(5, 5, 5, 5)
        unblacklistButton:SetText("Remove from Blacklist")

        local setPriceButton = vgui.Create("DButton", adminControls)
        setPriceButton:Dock(LEFT)
        setPriceButton:SetWidth(150)
        setPriceButton:DockMargin(5, 5, 5, 5)
        setPriceButton:SetText("Set Price for Selected")

        local adminList = vgui.Create("DListView", adminPanel)
        adminList:Dock(FILL)
        adminList:DockMargin(5, 5, 5, 5)
        adminList:AddColumn("Model Path")
        adminList:AddColumn("Price")
        adminList:AddColumn("Blacklisted")
        adminList:SetMultiSelect(true)

        for _, modelData in pairs(cachedModels) do
            local line = adminList:AddLine(
                modelData.Model,
                cachedConfig.prices[modelData.Model] or cachedConfig.default_price,
                table.HasValue(cachedConfig.blacklist or {}, modelData.Model) and "Yes" or "No"
            )
            line.modelData = modelData
        end

        blacklistButton.DoClick = function()
            local selected = adminList:GetSelected()
            for _, line in pairs(selected) do
                if line:GetColumnText(3) ~= "Yes" then
                    net.Start("BG_PlayerModelVendor_ToggleBlacklist")
                    net.WriteString(line.modelData.Model)
                    net.SendToServer()
                    line:SetColumnText(3, "Yes")
                end
            end
        end

        unblacklistButton.DoClick = function()
            local selected = adminList:GetSelected()
            for _, line in pairs(selected) do
                if line:GetColumnText(3) == "Yes" then
                    net.Start("BG_PlayerModelVendor_ToggleBlacklist")
                    net.WriteString(line.modelData.Model)
                    net.SendToServer()
                    line:SetColumnText(3, "No")
                end
            end
        end

        setPriceButton.DoClick = function()
            local selected = adminList:GetSelected()
            if #selected > 0 then
                Derma_StringRequest(
                    "Set Price",
                    "Enter new price for " .. #selected .. " selected models",
                    selected[1]:GetColumnText(2),
                    function(text)
                        local price = tonumber(text)
                        if price then
                            for _, line in pairs(selected) do
                                net.Start("BG_PlayerModelVendor_SetPrice")
                                net.WriteString(line.modelData.Model)
                                net.WriteInt(price, 32)
                                net.SendToServer()
                                line:SetColumnText(2, price)
                            end
                        end
                    end
                )
            end
        end

        adminList.OnRowRightClick = function(_, _, line)
            local menu = DermaMenu()
            
            menu:AddOption("Set Price", function()
                Derma_StringRequest(
                    "Set Price",
                    "Enter new price for " .. line.modelData.Model,
                    line:GetColumnText(2),
                    function(text)
                        local price = tonumber(text)
                        if price then
                            net.Start("BG_PlayerModelVendor_SetPrice")
                            net.WriteString(line.modelData.Model)
                            net.WriteInt(price, 32)
                            net.SendToServer()
                            line:SetColumnText(2, price)
                        end
                    end
                )
            end)

            menu:AddOption(line:GetColumnText(3) == "Yes" and "Remove from Blacklist" or "Add to Blacklist", function()
                net.Start("BG_PlayerModelVendor_ToggleBlacklist")
                net.WriteString(line.modelData.Model)
                net.SendToServer()
                line:SetColumnText(3, line:GetColumnText(3) == "Yes" and "No" or "Yes")
            end)

            menu:Open()
        end
    end
end)

-- Handle purchase results
net.Receive("BG_PlayerModelVendor_PurchaseResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 3)
    surface.PlaySound(success and "buttons/button14.wav" or "buttons/button10.wav")
end)

-- Handle owned models update
net.Receive("BG_PlayerModelVendor_UpdateOwned", function()
    cachedOwnedModels = net.ReadTable() or {}
    cachedModels = net.ReadTable() or {}
    cachedConfig = util.JSONToTable(net.ReadString()) or {blacklist = {}, prices = {}, default_price = 1000}
    
    if IsValid(vendorMenu) then
        local shopPanel = vendorMenu:GetChildren()[1]:GetChildren()[1]
        local ownedPanel = vendorMenu:GetChildren()[1]:GetChildren()[2]
        
        if IsValid(shopPanel) and IsValid(ownedPanel) then
            local shopGrid = shopPanel:GetChildren()[1]:GetChildren()[1]
            local ownedGrid = ownedPanel:GetChildren()[1]:GetChildren()[1]
            
            if IsValid(shopGrid) and IsValid(ownedGrid) then
                RefreshModels(shopGrid, ownedGrid)
            end
        end
    end
end)