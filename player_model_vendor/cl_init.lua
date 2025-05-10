-- lua/entities/player_model_vendor/cl_init.lua

print("--- [NPC PlayerModelVendor SCRIPT] cl_init.lua is being loaded by CLIENT (VGUI Auto-Refresh) ---")

include("shared.lua")

local vendorFrame = nil
local currentVendorEntity = nil
local availableModelsList_Global = nil -- Make DPanelList accessible for refresh
local ownedModelsList_Global = nil     -- Make DPanelList accessible for refresh
local availableModelsScroll_Global = nil
local ownedModelsScroll_Global = nil


-- Fonts
surface.CreateFont("Vendor_Title", { font = "DermaLarge", size = 32, weight = 700, antialias = true, shadow = true })
surface.CreateFont("Vendor_Tab", { font = "DermaLarge", size = 20, weight = 600, antialias = true })
surface.CreateFont("Vendor_ItemName", { font = "DermaDefault", size = 18, weight = 600, antialias = true })
surface.CreateFont("Vendor_ItemPrice", { font = "DermaDefault", size = 16, weight = 500, antialias = true })
surface.CreateFont("Vendor_Button", { font = "DermaDefault", size = 16, weight = 700, antialias = true })
surface.CreateFont("Vendor_Label", { font = "DermaDefault", size = 16, antialias = true })
surface.CreateFont("VendorNPCText_Title", { font = "DermaLarge", size = 30, weight = 700, antialias = true })
surface.CreateFont("VendorNPCText_Subtitle", { font = "DermaDefault", size = 24, weight = 500, antialias = true })

function ENT:Initialize() end
function ENT:Think() if not IsValid(self) then return end self:SetNoDraw(false); self:DrawShadow(true) end
function ENT:Draw()
    if not IsValid(self) then return end; self:DrawModel()
    local ply = LocalPlayer(); if not IsValid(ply) then return end
    local drawDistance = 750; if self:GetPos():Distance(ply:GetPos()) > drawDistance then return end
    local mins, maxs = self:WorldSpaceAABB(); local topOfHead = Vector(self:GetPos().x, self:GetPos().y, maxs.z + 15)
    local angToPlayer = (ply:EyePos() - topOfHead):Angle(); angToPlayer.p = 0; angToPlayer.r = 0
    cam.Start3D2D(topOfHead, angToPlayer, 0.07)
        local npcName = self.PrintName or "Player Model Vendor"
        draw.SimpleTextOutlined(npcName, "VendorNPCText_Title", 0, 0, Color(255,255,100,220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0,200))
        draw.SimpleTextOutlined("Press E for Models", "VendorNPCText_Subtitle", 0, 35, Color(200,200,255,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0,0,0,180))
    cam.End3D2D()
end
hook.Add("PreDrawOpaqueRenderables", "AlwaysDrawPlayerModelVendor", function(bDrawingDepth, bDrawingSkybox)
    if bDrawingDepth or bDrawingSkybox then return end
    for _, ent in ipairs(ents.FindByClass("player_model_vendor")) do
        if IsValid(ent) then ent:SetNoDraw(false); ent:DrawShadow(true); end
    end
end)

-- Function to populate the "Available Models" tab
local function PopulateAvailableModelsTab(listPanel, scrollPanel, modelsData)
    if not IsValid(listPanel) then print("[PMV CLIENT ERR] PopulateAvailable: listPanel invalid"); return end
    listPanel:Clear()
    if not modelsData or #modelsData == 0 then
        local lbl = vgui.Create("DLabel", listPanel); lbl:SetText("No models currently available for sale."); lbl:SetFont("Vendor_Label"); lbl:SetTextColor(color_white); lbl:Dock(TOP); lbl:SizeToContents(); listPanel:AddItem(lbl)
    else
        for i, modelData in ipairs(modelsData) do
            if modelData.Name and modelData.Model and modelData.Price then
                local itemPanel = vgui.Create("DPanel"); itemPanel:SetTall(60)
                itemPanel.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h,Color(70,70,70,150)); draw.RoundedBox(4,1,1,w-2,h-2,Color(80,80,80,200)) end
                local modelIcon = vgui.Create("SpawnIcon", itemPanel); modelIcon:SetModel(modelData.Model); modelIcon:SetSize(50,50)
                local nameLabel = vgui.Create("DLabel", itemPanel); nameLabel:SetText(modelData.Name); nameLabel:SetFont("Vendor_ItemName"); nameLabel:SetTextColor(color_white); nameLabel:SizeToContents()
                local priceLabel = vgui.Create("DLabel", itemPanel); priceLabel:SetText("Price: " .. modelData.Price .. " credits"); priceLabel:SetFont("Vendor_ItemPrice"); priceLabel:SetTextColor(Color(220,180,100)); priceLabel:SizeToContents()
                local purchaseButton = vgui.Create("DButton", itemPanel); purchaseButton:SetText("Select"); purchaseButton:SetFont("Vendor_Button"); purchaseButton:SetSize(80,30)
                purchaseButton.DoClick = function()
                    if not IsValid(currentVendorEntity) then print("[PMV CLIENT ERR] Vendor invalid for purchase."); return end
                    net.Start("BG_PlayerModelVendor_AttemptPurchase"); net.WriteEntity(currentVendorEntity); net.WriteUInt(i,16); net.SendToServer()
                end
                purchaseButton.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h,s:IsHovered() and Color(0,150,0,255) or Color(0,100,0,255)) end
                itemPanel.PerformLayout = function(pS,w,h) modelIcon:SetPos(5,(h-modelIcon:GetTall())/2); nameLabel:SetPos(modelIcon:GetWide()+15,8); priceLabel:SetPos(modelIcon:GetWide()+15,h-priceLabel:GetTall()-8); purchaseButton:SetPos(w-purchaseButton:GetWide()-10,(h-purchaseButton:GetTall())/2) end
                listPanel:AddItem(itemPanel)
            end
        end
    end
    listPanel:InvalidateLayout(true)
    if IsValid(scrollPanel) then scrollPanel:InvalidateLayout(true); if IsValid(scrollPanel:GetCanvas()) then scrollPanel:GetCanvas():InvalidateLayout(true) end end
    local totalHeight = 0; for _,item in ipairs(listPanel:GetItems()) do if IsValid(item) then totalHeight=totalHeight+item:GetTall()+listPanel:GetSpacing() end end
    if #listPanel:GetItems()>0 then totalHeight=totalHeight-listPanel:GetSpacing() end; totalHeight=totalHeight+listPanel:GetPadding()*2; listPanel:SetTall(totalHeight)
end

-- Function to populate the "Owned Models" tab
local function PopulateOwnedModelsTab(listPanel, scrollPanel, modelsData)
    if not IsValid(listPanel) then print("[PMV CLIENT ERR] PopulateOwned: listPanel invalid"); return end
    listPanel:Clear()
    if not modelsData or #modelsData == 0 then
        local lbl = vgui.Create("DLabel", listPanel); lbl:SetText("You do not own any models yet."); lbl:SetFont("Vendor_Label"); lbl:SetTextColor(color_white); lbl:Dock(TOP); lbl:SetWrap(true); lbl:SizeToContents(); listPanel:AddItem(lbl)
    else
        for i, modelData in ipairs(modelsData) do
            if modelData.Name and modelData.Model then
                local itemPanel = vgui.Create("DPanel"); itemPanel:SetTall(60)
                itemPanel.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h,Color(70,70,70,150)); draw.RoundedBox(4,1,1,w-2,h-2,Color(80,80,80,200)) end
                local modelIcon = vgui.Create("SpawnIcon", itemPanel); modelIcon:SetModel(modelData.Model); modelIcon:SetSize(50,50)
                local nameLabel = vgui.Create("DLabel", itemPanel); nameLabel:SetText(modelData.Name); nameLabel:SetFont("Vendor_ItemName"); nameLabel:SetTextColor(color_white); nameLabel:SizeToContents()
                local equipButton = vgui.Create("DButton", itemPanel); equipButton:SetText("Equip"); equipButton:SetFont("Vendor_Button"); equipButton:SetSize(80,30)
                equipButton.DoClick = function()
                    print("[PlayerModelVendor CLIENT] Attempting to equip owned model: " .. modelData.Model)
                    net.Start("BG_PlayerModelVendor_EquipOwnedModel"); net.WriteString(modelData.Model); net.SendToServer()
                end
                equipButton.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h,s:IsHovered() and Color(0,100,150,255) or Color(0,80,120,255)) end
                itemPanel.PerformLayout = function(pS,w,h) modelIcon:SetPos(5,(h-modelIcon:GetTall())/2); nameLabel:SetPos(modelIcon:GetWide()+15,(h-nameLabel:GetTall())/2); equipButton:SetPos(w-equipButton:GetWide()-10,(h-equipButton:GetTall())/2) end
                listPanel:AddItem(itemPanel)
            end
        end
    end
    listPanel:InvalidateLayout(true)
    if IsValid(scrollPanel) then scrollPanel:InvalidateLayout(true); if IsValid(scrollPanel:GetCanvas()) then scrollPanel:GetCanvas():InvalidateLayout(true) end end
    local totalHeight = 0; for _,item in ipairs(listPanel:GetItems()) do if IsValid(item) then totalHeight=totalHeight+item:GetTall()+listPanel:GetSpacing() end end
    if #listPanel:GetItems()>0 then totalHeight=totalHeight-listPanel:GetSpacing() end; totalHeight=totalHeight+listPanel:GetPadding()*2; listPanel:SetTall(totalHeight)
end


local function CreateVendorMenu(initialAvailableModelsData, initialOwnedModelsData, npcEnt)
    currentVendorEntity = npcEnt
    if IsValid(vendorFrame) then vendorFrame:Remove(); vendorFrame = nil; end

    vendorFrame = vgui.Create("DFrame")
    vendorFrame:SetSize(ScrW() * 0.8, ScrH() * 0.85); vendorFrame:Center(); vendorFrame:SetTitle("")
    vendorFrame:SetVisible(true); vendorFrame:SetDraggable(false); vendorFrame:ShowCloseButton(false)
    vendorFrame:SetDeleteOnClose(true)
    vendorFrame.OnClose = function(selfFrame) vendorFrame = nil; currentVendorEntity = nil; gui.EnableScreenClicker(false) end
    vendorFrame:MakePopup(); gui.EnableScreenClicker(true)

    local titleBar = vgui.Create("DPanel", vendorFrame); titleBar:SetTall(40); titleBar:Dock(TOP)
    titleBar.Paint = function(s,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(40,40,40,230))
        local titleText = "Player Model Vendor"
        if IsValid(npcEnt) then
            local success, name = pcall(function() return npcEnt:GetPrintName() end)
            if success and name and name ~= "" then titleText = name
            elseif type(ENT) == "table" and ENT.PrintName then titleText = ENT.PrintName end
        elseif type(ENT) == "table" and ENT.PrintName then titleText = ENT.PrintName end
        draw.SimpleText(titleText, "Vendor_Title", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local closeButton = vgui.Create("DButton", titleBar)
    closeButton:SetText("X"); closeButton:SetFont("DermaLarge"); closeButton:SetTextColor(Color(200,200,200))
    closeButton:SetSize(30,30); closeButton:Dock(RIGHT); closeButton:SetPaintBackground(false)
    closeButton.DoClick = function() if IsValid(vendorFrame) then vendorFrame:Close() end end
    closeButton.OnCursorEntered = function(pnl) pnl:SetTextColor(color_white) end
    closeButton.OnCursorExited = function(pnl) pnl:SetTextColor(Color(200,200,200)) end

    local tabPanel = vgui.Create("DPropertySheet", vendorFrame)
    tabPanel:Dock(FILL); tabPanel:DockMargin(5,0,5,5)
    tabPanel.Paint = function(s,w,h) draw.RoundedBox(0,0,0,w,h,Color(60,60,60,200)) end

    availableModelsScroll_Global = vgui.Create("DScrollPanel", tabPanel)
    tabPanel:AddSheet("Available Models", availableModelsScroll_Global, "icon16/coins.png", false, false, "Browse and purchase player models.")
    availableModelsList_Global = vgui.Create("DPanelList", availableModelsScroll_Global)
    availableModelsList_Global:Dock(FILL); availableModelsList_Global:SetPadding(10); availableModelsList_Global:SetSpacing(10)
    PopulateAvailableModelsTab(availableModelsList_Global, availableModelsScroll_Global, initialAvailableModelsData)

    ownedModelsScroll_Global = vgui.Create("DScrollPanel", tabPanel)
    tabPanel:AddSheet("My Models", ownedModelsScroll_Global, "icon16/heart.png", false, false, "View and manage your purchased models.")
    ownedModelsList_Global = vgui.Create("DPanelList", ownedModelsScroll_Global)
    ownedModelsList_Global:Dock(FILL); ownedModelsList_Global:SetPadding(10); ownedModelsList_Global:SetSpacing(10)
    PopulateOwnedModelsTab(ownedModelsList_Global, ownedModelsScroll_Global, initialOwnedModelsData)

    if LocalPlayer():IsSuperAdmin() then
        local adminScroll = vgui.Create("DScrollPanel", tabPanel)
        tabPanel:AddSheet("Admin Panel", adminScroll, "icon16/shield.png", false, false, "Manage vendor settings (Admin only).")
        local adminLabel = vgui.Create("DLabel", adminScroll); adminLabel:SetText("Admin controls coming soon!"); adminLabel:SetFont("Vendor_Label"); adminLabel:SetTextColor(color_white); adminLabel:Dock(FILL); adminLabel:SetContentAlignment(5)
    end
end

-- Central function to refresh tab content
function RefreshVendorTabs(newAvailableData, newOwnedData)
    if not IsValid(vendorFrame) then
        print("[PMV CLIENT REFRESH ERR] Vendor frame is not valid. Cannot refresh.")
        return
    end
    if IsValid(availableModelsList_Global) and IsValid(availableModelsScroll_Global) then
        PopulateAvailableModelsTab(availableModelsList_Global, availableModelsScroll_Global, newAvailableData)
    else
        print("[PMV CLIENT REFRESH ERR] Available models list/scroll panel invalid.")
    end
    if IsValid(ownedModelsList_Global) and IsValid(ownedModelsScroll_Global) then
        PopulateOwnedModelsTab(ownedModelsList_Global, ownedModelsScroll_Global, newOwnedData)
    else
        print("[PMV CLIENT REFRESH ERR] Owned models list/scroll panel invalid.")
    end
end

net.Receive("BG_PlayerModelVendor_OpenMenu", function(len)
    local availableModelsData = net.ReadTable()
    local ownedModelsData = net.ReadTable()
    local npcEnt = net.ReadEntity()
    print("--- [NPC PlayerModelVendor CLIENT] Received BG_PlayerModelVendor_OpenMenu signal. Available: " .. (#availableModelsData or 0) .. ", Owned: " .. (#ownedModelsData or 0))
    CreateVendorMenu(availableModelsData, ownedModelsData, npcEnt)
end)

net.Receive("BG_PlayerModelVendor_PurchaseResult", function(len)
    local success = net.ReadBool(); local message = net.ReadString()
    local newAvailableData = {}; local newOwnedData = {}
    if success then
        newAvailableData = net.ReadTable() -- Read updated available models
        newOwnedData = net.ReadTable()     -- Read updated owned models
    end

    if GAMEMODE and GAMEMODE.AddNotify then GAMEMODE:AddNotify(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 5)
    else chat.AddText(success and Color(100,255,100) or Color(255,100,100),"[Model Vendor] ",color_white,message) end
    
    if success and IsValid(vendorFrame) then
        print("[PlayerModelVendor CLIENT] Purchase successful. Refreshing tabs.")
        RefreshVendorTabs(newAvailableData, newOwnedData) -- Refresh instead of closing
    elseif success and not IsValid(vendorFrame) then
         print("[PlayerModelVendor CLIENT ERR] Purchase success but vendorFrame invalid for refresh.")
    end
end)

net.Receive("BG_PlayerModelVendor_EquipResult", function(len)
    local success = net.ReadBool(); local message = net.ReadString()
    local newAvailableData = {}; local newOwnedData = {}
    if success then
        newAvailableData = net.ReadTable() -- Read updated available models
        newOwnedData = net.ReadTable()     -- Read updated owned models
    end

    print("[PlayerModelVendor CLIENT] Equip result: " .. message .. " (Success: " .. tostring(success) .. ")")
    if GAMEMODE and GAMEMODE.AddNotify then GAMEMODE:AddNotify(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 5)
    else chat.AddText(success and Color(100,255,100) or Color(255,100,100),"[Model Vendor] ",color_white,message) end
    
    if success and IsValid(vendorFrame) then
        print("[PlayerModelVendor CLIENT] Equip successful. Refreshing tabs.")
        RefreshVendorTabs(newAvailableData, newOwnedData) -- Refresh instead of closing
    elseif success and not IsValid(vendorFrame) then
         print("[PlayerModelVendor CLIENT ERR] Equip success but vendorFrame invalid for refresh.")
    end
end)

net.Receive("BG_PlayerModelVendor_Admin_ActionResponse", function(len)
    local success = net.ReadBool(); local message = net.ReadString()
    print("[PlayerModelVendor Admin] Server response: " .. message .. " (Success: " .. tostring(success) .. ")")
end)

print("--- [NPC PlayerModelVendor SCRIPT] cl_init.lua finished loading by CLIENT (VGUI Auto-Refresh) ---")
