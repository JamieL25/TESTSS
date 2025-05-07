-- NPC Player Model Vendor Entity
-- cl_init.lua - Client-side code
-- Updated: 2025-05-07 16:49:19 by JamieL25

include("shared.lua")

-- Draw distance for text and info
local MAX_DRAW_DISTANCE = 1000
local TEXT_COLOR = Color(255, 255, 100)

-- Cache for models and config data
local cachedModels = {}
local cachedConfig = {}
local cachedOwnedModels = {}
local vendorMenu = nil
local g_PropertySheet = nil
local g_ShopGrid = nil
local g_OwnedGrid = nil
local lastPurchaseTime = 0
local lastRefreshTime = 0

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

-- Function to format currency
local function FormatCurrency(amount)
    return "£" .. string.Comma(amount)
end

-- Function to show purchase confirmation
local function ShowPurchaseConfirmation(modelData, price, callback)
    local confirmWindow = vgui.Create("DFrame")
    confirmWindow:SetSize(400, 200)
    confirmWindow:Center()
    confirmWindow:SetTitle("Confirm Purchase")
    confirmWindow:MakePopup()

    local modelPanel = vgui.Create("DModelPanel", confirmWindow)
    modelPanel:SetSize(180, 180)
    modelPanel:SetPos(10, 30)
    modelPanel:SetModel(modelData.Model)
    modelPanel:SetFOV(40)

    local mn, mx = modelPanel.Entity:GetRenderBounds()
    local size = 0
    size = math.max(size, math.abs(mn.x) + math.abs(mx.x))
    size = math.max(size, math.abs(mn.y) + math.abs(mx.y))
    size = math.max(size, math.abs(mn.z) + math.abs(mx.z))
    modelPanel:SetCamPos(Vector(size, size, size/2))
    modelPanel:SetLookAt((mn + mx) * 0.5)

    function modelPanel:LayoutEntity(ent)
        ent:SetAngles(Angle(0, RealTime() * 50, 0))
    end

    local infoPanel = vgui.Create("DPanel", confirmWindow)
    infoPanel:SetPos(200, 30)
    infoPanel:SetSize(190, 120)
    
    infoPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
        draw.SimpleText("Model: " .. modelData.Name, "DermaDefault", 10, 10, color_white)
        draw.SimpleText("Price: " .. FormatCurrency(price), "DermaDefault", 10, 30, color_white)
        draw.SimpleText("Current Balance: " .. FormatCurrency(LocalPlayer():GetNWInt("Currency", 0)), "DermaDefault", 10, 50, color_white)
        draw.SimpleText("Are you sure you want", "DermaDefault", 10, 80, color_white)
        draw.SimpleText("to purchase this model?", "DermaDefault", 10, 100, color_white)
    end

    local buttonPanel = vgui.Create("DPanel", confirmWindow)
    buttonPanel:SetPos(200, 160)
    buttonPanel:SetSize(190, 30)
    buttonPanel:SetPaintBackground(false)

    local confirmButton = vgui.Create("DButton", buttonPanel)
    confirmButton:SetPos(0, 0)
    confirmButton:SetSize(90, 30)
    confirmButton:SetText("Purchase")
    confirmButton.DoClick = function()
        lastPurchaseTime = CurTime()
        callback(true)
        confirmWindow:Close()
    end

    local cancelButton = vgui.Create("DButton", buttonPanel)
    cancelButton:SetPos(100, 0)
    cancelButton:SetSize(90, 30)
    cancelButton:SetText("Cancel")
    cancelButton.DoClick = function()
        callback(false)
        confirmWindow:Close()
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
            net.Start("BG_PlayerModelVendor_UseModel")
            net.WriteString(modelData.Model)
            net.SendToServer()
        end
        useButton.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and Color(100, 170, 100) or Color(80, 150, 80)
            draw.RoundedBox(4, 0, 0, w, h, bgColor)
        end
    else
        local price = config.prices[modelData.Model] or config.default_price
        local priceLabel = vgui.Create("DLabel", itemPanel)
        priceLabel:SetPos(10, 230)
        priceLabel:SetSize(130, 20)
        priceLabel:SetText("Price: " .. FormatCurrency(price))
        priceLabel:SetTextColor(Color(255, 255, 255))

        local buyButton = vgui.Create("DButton", itemPanel)
        buyButton:SetPos(140, 230)
        buyButton:SetSize(90, 25)
        buyButton:SetText("Purchase")
        buyButton.DoClick = function()
            ShowPurchaseConfirmation(modelData, price, function(confirmed)
                if confirmed then
                    net.Start("BG_PlayerModelVendor_AttemptPurchase")
                    net.WriteString(modelData.Model)
                    net.SendToServer()
                end
            end)
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

    -- Auto-switch to Owned tab after purchase if it was recent
    if IsValid(g_PropertySheet) and CurTime() - lastPurchaseTime < 0.5 then
        g_PropertySheet:SetActiveTab(g_PropertySheet:GetItems()[2].Tab)
        lastPurchaseTime = 0
    end

    lastRefreshTime = CurTime()
end

local function CreateOrUpdateMenu()
    if not IsValid(vendorMenu) then
        vendorMenu = vgui.Create("DFrame")
        vendorMenu:SetSize(800, 600)
        vendorMenu:Center()
        vendorMenu:SetTitle("Player Model Shop - Balance: " .. FormatCurrency(LocalPlayer():GetNWInt("Currency", 0)))
        vendorMenu:MakePopup()

        vendorMenu.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 250))
            draw.RoundedBox(8, 0, 0, w, 24, Color(60, 60, 60, 250))
        end

        g_PropertySheet = vgui.Create("DPropertySheet", vendorMenu)
        g_PropertySheet:Dock(FILL)
        g_PropertySheet:DockMargin(5, 5, 5, 5)

        -- Shop Panel
        local shopPanel = vgui.Create("DPanel", g_PropertySheet)
        g_PropertySheet:AddSheet("Shop", shopPanel, "icon16/cart.png", false, false, "Browse available models")

        -- Owned Panel
        local ownedPanel = vgui.Create("DPanel", g_PropertySheet)
        g_PropertySheet:AddSheet("Owned", ownedPanel, "icon16/user.png", false, false, "View your owned models")

        -- Scroll panels
        local shopScroll = vgui.Create("DScrollPanel", shopPanel)
        shopScroll:Dock(FILL)
        shopScroll:DockMargin(10, 10, 10, 10)

        local ownedScroll = vgui.Create("DScrollPanel", ownedPanel)
        ownedScroll:Dock(FILL)
        ownedScroll:DockMargin(10, 10, 10, 10)

        -- Grids
        g_ShopGrid = vgui.Create("DGrid", shopScroll)
        g_ShopGrid:Dock(FILL)
        g_ShopGrid:SetCols(3)
        g_ShopGrid:SetColWide(250)
        g_ShopGrid:SetRowHeight(280)

        g_OwnedGrid = vgui.Create("DGrid", ownedScroll)
        g_OwnedGrid:Dock(FILL)
        g_OwnedGrid:SetCols(3)
        g_OwnedGrid:SetColWide(250)
        g_OwnedGrid:SetRowHeight(280)

        -- Admin Panel
        if LocalPlayer():IsSuperAdmin() then
            local adminPanel = vgui.Create("DPanel", g_PropertySheet)
            g_PropertySheet:AddSheet("Admin", adminPanel, "icon16/shield.png", false, false, "Admin Controls")

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
    end
    
    -- Update balance in title
    vendorMenu:SetTitle("Player Model Shop - Balance: " .. FormatCurrency(LocalPlayer():GetNWInt("Currency", 0)))
    
    -- Refresh models
    RefreshModels(g_ShopGrid, g_OwnedGrid)
end

-- Network Receivers
net.Receive("BG_PlayerModelVendor_OpenMenu", function()
    cachedModels = net.ReadTable() or {}
    cachedConfig = util.JSONToTable(net.ReadString()) or PLAYERMODEL_VENDOR.Config
    cachedOwnedModels = net.ReadTable() or {}
    
    CreateOrUpdateMenu()
end)

-- Handle purchase results with improved refresh
net.Receive("BG_PlayerModelVendor_PurchaseResult", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 3)
    surface.PlaySound(success and "buttons/button14.wav" or "buttons/button10.wav")
    
    -- If purchase was successful, immediately request an update
    if success then
        lastPurchaseTime = CurTime()
        timer.Simple(0.1, function()
            net.Start("BG_PlayerModelVendor_RequestModels")
            net.SendToServer()
        end)
    end
end)

-- Handle owned models update with improved refresh
net.Receive("BG_PlayerModelVendor_UpdateOwned", function()
    local ownedModels = net.ReadTable() or {}
    local models = net.ReadTable() or {}
    local configStr = net.ReadString()
    local config = util.JSONToTable(configStr) or PLAYERMODEL_VENDOR.Config
    
    -- Update cached data
    cachedOwnedModels = ownedModels
    cachedModels = models
    cachedConfig = config
    
    -- Refresh UI if menu is open
    if IsValid(vendorMenu) and IsValid(g_ShopGrid) and IsValid(g_OwnedGrid) then
        timer.Simple(0, function()
            RefreshModels(g_ShopGrid, g_OwnedGrid)
        end)
    end
end)

-- Auto-refresh timer
timer.Create("PlayerModelVendor_AutoRefresh", 1, 0, function()
    if IsValid(vendorMenu) and CurTime() - lastRefreshTime > 1 then
        net.Start("BG_PlayerModelVendor_RequestModels")
        net.SendToServer()
    end
end)