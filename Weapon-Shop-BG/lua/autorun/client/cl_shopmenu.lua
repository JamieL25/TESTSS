-- cl_shopmenu.lua - Client v1.26 Full (Added Buy Ammo Button)
print("[Shop Debug] cl_shopmenu.lua v1.26 starting")

local NET_BUY            = "BuyWeapon"
local NET_BUY_AMMO       = "BuyAmmo" -- Added new network string for buying ammo
local NET_SEND_BLACKLIST = "SendShopBlacklist"
local NET_SEND_OVERRIDES = "SendShopCategoryOverrides"
local NET_SEND_OWNED     = "SendOwnedWeapons"
local NET_EQUIP          = "EquipWeapon"

local lastBuyTime       = 0
local buyCooldown       = 1
local WeaponShopFrame
local ShopPropertySheet

local CurrentCategorizedItems = { rifles={}, pistols={}, other={}, all={} }
local LocalShopBlacklist      = {}
local LocalCategoryOverrides  = {}
local LocalOwnedWeapons       = {}
local DEFAULT_WEAPON_PRICE    = 1500
local AMMO_COST               = 100 -- Define ammo cost
local AMMO_AMOUNT             = 80  -- Define ammo amount

--------------------------------------------------------------------------
-- Refresh all visible tabs (FIXED: use sheetItem.Panel, not sheetItem.Tab!)
--------------------------------------------------------------------------
local function RefreshAllPanels()
  CurrentCategorizedItems = DetectAndCategorizeWeapons()
  if not IsValid(ShopPropertySheet) then return end

  for _, sheetItem in ipairs(ShopPropertySheet:GetItems()) do
    local title = sheetItem.Name or sheetItem.Text
    local content = sheetItem.Panel    -- <— this must be the content panel!
    if title == "Rifles" then
      PopulateShopPanel(content, CurrentCategorizedItems.rifles)
    elseif title == "Pistols" then
      PopulateShopPanel(content, CurrentCategorizedItems.pistols)
    elseif title == "Other" then
      PopulateShopPanel(content, CurrentCategorizedItems.other)
    elseif title == "Owned" then
      -- build only owned set
      local ownedData = {}
      for cls,_ in pairs(LocalOwnedWeapons) do
        if CurrentCategorizedItems.all[cls] then
          ownedData[cls] = CurrentCategorizedItems.all[cls]
        end
      end
      PopulateShopPanel(content, ownedData)
    end
  end
end

--------------------------------------------------------------------------
-- Detect & categorize (don't skip owned weapons for 'all' category)
--------------------------------------------------------------------------
function DetectAndCategorizeWeapons()
  local cats = { rifles={}, pistols={}, other={}, all={} }

  for _, w in ipairs(weapons.GetList()) do
    local cls = w.ClassName
    if not cls then continue end
    if LocalShopBlacklist[cls] then continue end
    if not (string.StartWith(cls,"cw_") or string.StartWith(cls,"fas2_")) then continue end

    local cat = "other"
    local ovr = LocalCategoryOverrides[cls]
    if ovr == "rifles" or ovr == "pistols" or ovr == "other" then
      cat = ovr
    else
      local cs = tostring(w.Category or ""):lower()
      if cs:find("rifle",1,true)
      or cs:find("assault",1,true)
      or cs:find("sniper",1,true) then
        cat = "rifles"
      elseif cs:find("pistol",1,true)
          or cs:find("handgun",1,true) then
        cat = "pistols"
      else
        local lc = cls:lower()
        if lc:find("rifle",1,true)
        or lc:find("_ak",1,true)
        or lc:find("_m4",1,true) then
          cat = "rifles"
        elseif lc:find("pistol",1,true)
            or lc:find("deagle",1,true)
            or lc:find("glock",1,true) then
          cat = "pistols"
        end
      end
    end

    if w.Spawnable ~= false and not w.AdminOnly then
      -- Store all weapons in the 'all' category for reference
      cats.all[cls] = { class=cls, price=DEFAULT_WEAPON_PRICE, wepData=w }

      -- Only add to regular categories if not owned
      if not LocalOwnedWeapons[cls] then
        cats[cat][cls] = { class=cls, price=DEFAULT_WEAPON_PRICE, wepData=w }
      end
    end
  end

  return cats
end

--------------------------------------------------------------------------
-- Populate a single scroll panel
--------------------------------------------------------------------------
function PopulateShopPanel(parent, items)
  parent:Clear()
  local keys = {}
  for cls in pairs(items) do table.insert(keys,cls) end
  table.sort(keys)

  if #keys == 0 then
    local lbl = vgui.Create("DLabel", parent)
    lbl:Dock(TOP); lbl:SetTall(50)
    lbl:SetFont("Trebuchet24"); lbl:SetTextColor(Color(200,200,200))
    lbl:SetContentAlignment(5); lbl:DockMargin(5,5,5,5)

    if parent.isSearchResultsPanel then
      lbl:SetText("Type to search weapons...")
    else
      lbl:SetText(parent:GetName()=="OwnedTab"
                  and "No owned weapons."
                  or "No weapons in this category.")
    end
    return
  end

  for i,cls in ipairs(keys) do
    local data = items[cls]
    local wdat = data.wepData

    local pnl = vgui.Create("DPanel", parent)
    pnl:Dock(TOP); pnl:DockMargin(5,5,5,5); pnl:SetTall(115)
    local bg = (i%2==0) and Color(40,50,70,220) or Color(45,55,75,220)
    pnl.Paint = function(self,w,h) draw.RoundedBox(8,0,0,w,h,bg) end

    -- Name & price
    local name = wdat.PrintName or cls
    local lblN = vgui.Create("DLabel", pnl)
    lblN:SetFont("Trebuchet24")
    lblN:SetText(name .. (parent:GetName()=="OwnedTab" and "" or " - £"..data.price))
    lblN:SetPos(80,5); lblN:SizeToContents(); lblN:SetTextColor(Color(220,220,220))

    -- Class
    local lblC = vgui.Create("DLabel", pnl)
    lblC:SetFont("Trebuchet18")
    lblC:SetText("Class: "..cls)
    lblC:SetPos(80,30); lblC:SizeToContents(); lblC:SetTextColor(Color(150,150,150))

    -- Description
    local lblD = vgui.Create("DLabel", pnl)
    lblD:SetFont("Trebuchet18")
    lblD:SetText(wdat.Description or "No description available.")
    lblD:SetWrap(true)
    lblD:SetPos(80,50); lblD:SetSize(pnl:GetWide()-200,20)
    lblD:SetTextColor(Color(180,180,190))

    -- Stats
    local y,sc = 70, Color(170,190,210)
    local dmg = (wdat.Primary and wdat.Primary.Damage) or wdat.Damage or "N/A"
    local lblDMG = vgui.Create("DLabel", pnl)
    lblDMG:SetFont("DermaDefault")
    lblDMG:SetText("Damage: "..dmg)
    lblDMG:SetPos(80,y); lblDMG:SizeToContents(); lblDMG:SetTextColor(sc)
    y = y + 18
    local rt = wdat.ReloadTime and string.format("%.2f",wdat.ReloadTime).."s" or "N/A"
    local lblRT = vgui.Create("DLabel", pnl)
    lblRT:SetFont("DermaDefault")
    lblRT:SetText("Reload: "..rt)
    lblRT:SetPos(80,y); lblRT:SizeToContents(); lblRT:SetTextColor(sc)

    -- Icon
    local icon = vgui.Create("SpawnIcon", pnl)
    icon:SetSize(64,64); icon:SetPos(10,10)
    icon:SetModel(wdat.IconOverride or wdat.WorldModel or "models/props_junk/garbage_metalcan002a.mdl")

    -- Buy/Equip button
    local btn = vgui.Create("DButton", pnl)
    btn:SetFont("Trebuchet24")
    btn:SetSize(100,40)
    btn:SetPos(pnl:GetWide()-110, pnl:GetTall()/2-20)
    if parent:GetName()=="OwnedTab" then
      btn:SetText("Equip")
      btn.DoClick = function()
        net.Start(NET_EQUIP); net.WriteString(cls); net.SendToServer()
      end
    else
      btn:SetText("Buy")
      btn.DoClick = function()
        if CurTime()-lastBuyTime < buyCooldown then
          chat.AddText(Color(255,100,100),"Please wait before buying!")
          return
        end
        lastBuyTime = CurTime()
        Derma_Query(
          "Buy "..name.." for £"..data.price.."?",
          "Confirm Purchase",
          "Yes", function()
            net.Start(NET_BUY)
              net.WriteString(cls)
              net.WriteInt(data.price,32)
            net.SendToServer()
          end,
          "No" -- Add a "No" button
        )
      end
    end

    pnl.PerformLayout = function(self,w,h)
      lblD:SetSize(w-200,20)
      btn:SetPos(w-110,h/2-20)
    end
  end
end

--------------------------------------------------------------------------
-- Build & show the shop
--------------------------------------------------------------------------
function OpenWeaponShop()
  if IsValid(WeaponShopFrame) then WeaponShopFrame:Remove() end
  CurrentCategorizedItems = DetectAndCategorizeWeapons()

  WeaponShopFrame = vgui.Create("DFrame")
  WeaponShopFrame:SetTitle("Weapon Shop (Auto-Detected)")
  WeaponShopFrame:SetSize(ScrW()*0.8, ScrH()*0.8)
  WeaponShopFrame:Center()
  WeaponShopFrame:MakePopup()
  WeaponShopFrame.Paint = function(self,w,h)
    draw.RoundedBox(8,0,0,w,h,Color(20,30,55,240))
  end

  ShopPropertySheet = vgui.Create("DPropertySheet", WeaponShopFrame)
  ShopPropertySheet:Dock(FILL); ShopPropertySheet:DockMargin(5,30,5,30) -- Adjusted bottom margin for ammo button

  local pnlR   = vgui.Create("DScrollPanel", ShopPropertySheet)
  local pnlP   = vgui.Create("DScrollPanel", ShopPropertySheet)
  local pnlO   = vgui.Create("DScrollPanel", ShopPropertySheet)
  local pnlOwn = vgui.Create("DScrollPanel", ShopPropertySheet); pnlOwn:SetName("OwnedTab")
  local pnlS   = vgui.Create("DPanel",      ShopPropertySheet); pnlS:Dock(FILL)

  ShopPropertySheet:AddSheet("Rifles",  pnlR,   "icon16/bullet_red.png", false, false)
  ShopPropertySheet:AddSheet("Pistols", pnlP,   "icon16/gun.png",        false, false)
  ShopPropertySheet:AddSheet("Other",   pnlO,   "icon16/box.png",        false, false)
  ShopPropertySheet:AddSheet("Owned",   pnlOwn, "icon16/star.png",       false, false)
  ShopPropertySheet:AddSheet("Search",  pnlS,   "icon16/find.png",       false, false)

  -- Currency footer (keep at bottom but above ammo button)
  local footerPanel = vgui.Create("DPanel", WeaponShopFrame)
  footerPanel:Dock(BOTTOM)
  footerPanel:SetTall(30) -- Height for the footer area
  footerPanel.Paint = function(self, w, h)
      -- Optional: Paint a background for the footer if needed
      -- draw.RoundedBox(0, 0, 0, w, h, Color(30, 40, 65, 240))
  end

  local lblMoney = vgui.Create("DLabel", footerPanel)
  lblMoney:Dock(LEFT) -- Align money to the left
  lblMoney:SetFont("Trebuchet24")
  lblMoney:SetTextColor(Color(200,220,255))
  lblMoney:DockMargin(10, 0, 0, 5) -- Left margin
  lblMoney.Think = function(self)
    local cash = LocalPlayer():GetNWInt("Currency",0)
    self:SetText("Your Money: £"..cash)
    self:SizeToContentsY()
    self:SetWide(250) -- Give it some width
  end

  -- Buy Ammo Button
  local btnBuyAmmo = vgui.Create("DButton", footerPanel)
  btnBuyAmmo:Dock(RIGHT) -- Dock to the right within the footer
  btnBuyAmmo:SetFont("Trebuchet18") -- Use Trebuchet18 instead
  btnBuyAmmo:SetText(string.format("Buy %d Ammo (£%d)", AMMO_AMOUNT, AMMO_COST))
  btnBuyAmmo:SetSize(180, 25) -- Set fixed size
  btnBuyAmmo:DockMargin(0, 2, 10, 3) -- Right and vertical margins
  btnBuyAmmo.DoClick = function()
      if CurTime()-lastBuyTime < buyCooldown then
          chat.AddText(Color(255,100,100),"Please wait before buying!")
          return
      end
      lastBuyTime = CurTime()
      -- No confirmation needed as requested ("only want 1 click")
      net.Start(NET_BUY_AMMO)
        net.WriteInt(AMMO_COST, 32)
        net.WriteInt(AMMO_AMOUNT, 16) -- Send ammo amount too
      net.SendToServer()
      print("[Shop Debug] Sent BuyAmmo request to server.")
  end

  RefreshAllPanels()

  -- Search UI
  local txt = vgui.Create("DTextEntry", pnlS)
  txt:Dock(TOP); txt:SetTall(30); txt:DockMargin(5,5,5,5)
  txt:SetPlaceholderText("Type to search weapons...")
  local pnlRes = vgui.Create("DScrollPanel", pnlS)
  pnlRes:Dock(FILL); pnlRes:DockMargin(5,0,5,5)
  pnlRes.isSearchResultsPanel = true

  txt.OnChange = function(self)
    local q = string.lower(self:GetValue())
    if q=="" then
      pnlRes:Clear()
      local lbl = vgui.Create("DLabel", pnlRes)
      lbl:Dock(TOP); lbl:SetTall(50); lbl:SetFont("Trebuchet24")
      lbl:SetTextColor(Color(200,200,200)); lbl:SetContentAlignment(5)
      lbl:DockMargin(5,5,5,5)
      lbl:SetText("Type to search weapons...")
      return
    end
    local out = {}
    for _,cat in pairs(CurrentCategorizedItems) do
      if _ ~= "all" then -- Skip the 'all' category when searching
        for cls,dat in pairs(cat) do
          local nm = string.lower(dat.wepData.PrintName or cls)
          if nm:find(q,1,true) or cls:lower():find(q,1,true) then
            out[cls] = dat
          end
        end
      end
    end
    PopulateShopPanel(pnlRes, out)
  end

  -- Add help text to the title bar
  local helpLabel = vgui.Create("DLabel", WeaponShopFrame)
  helpLabel:SetPos(WeaponShopFrame:GetWide() - 300, 5)
  helpLabel:SetFont("DermaDefault")
  helpLabel:SetText("Type '/shop' in chat to open")
  helpLabel:SetTextColor(Color(180, 180, 200))
  helpLabel:SizeToContents()
  WeaponShopFrame.PerformLayout = function(self, w, h)
    ShopPropertySheet:DockMargin(5, 30, 5, footerPanel:GetTall() + 5) -- Adjust sheet margin based on footer height
    helpLabel:SetPos(w - helpLabel:GetWide() - 10, 5)
    footerPanel:SetPos(0, h - footerPanel:GetTall()) -- Ensure footer is at the bottom
    footerPanel:SetWide(w)
  end
end

--------------------------------------------------------------------------
-- Toggle + hooks + commands
--------------------------------------------------------------------------
function ToggleShop()
  print("[Shop Debug] ToggleShop function called")
  if WeaponShopFrame and WeaponShopFrame:IsVisible() then
    WeaponShopFrame:Close()
    print("[Shop Debug] Shop menu closed")
  else
    timer.Simple(0.1, OpenWeaponShop)
    print("[Shop Debug] Shop menu opening")
  end
end

-- Simpler key tracking variables
local lastF4PressTime = 0
local lastBPressTime = 0
local keyPressDelay = 0.2  -- Prevent double triggers

-- Simple key monitoring using Think hook
hook.Add("Think", "WeaponShopKeyMonitor", function()
    -- Only check every 0.1 seconds to reduce performance impact
    if (CurTime() % 0.1) > 0.05 then return end

    -- Check F4 with cooldown to prevent multiple triggers
    if input.IsKeyDown(KEY_F4) and CurTime() - lastF4PressTime > keyPressDelay then
        lastF4PressTime = CurTime()
        print("[Shop Debug] F4 key detected, toggling shop")
        ToggleShop()
    end

    -- Check B key with cooldown
    if input.IsKeyDown(KEY_B) and CurTime() - lastBPressTime > keyPressDelay then
        lastBPressTime = CurTime()
        print("[Shop Debug] B key detected, toggling shop")
        ToggleShop()
    end
end)

-- Chat command to open shop
hook.Add("OnPlayerChat", "WeaponShopChatCommand", function(ply, text, team, isDead)
    if (ply == LocalPlayer() and (text:lower() == "!shop" or text:lower() == "/shop")) then
        print("[Shop Debug] Shop command detected, toggling shop")
        ToggleShop()
        return true
    end
end)

-- Keep this as a fallback method
concommand.Add("toggle_weapon_shop", function()
    print("[Shop Debug] Console command toggle_weapon_shop executed")
    ToggleShop()
end)

--------------------------------------------------------------------------
-- net receivers
--------------------------------------------------------------------------
net.Receive(NET_SEND_BLACKLIST, function()
  LocalShopBlacklist = {}
  for _,c in ipairs(net.ReadTable() or {}) do
    LocalShopBlacklist[c] = true
  end
  print("[Shop Debug] Received blacklist: " .. table.Count(LocalShopBlacklist) .. " items")
  RefreshAllPanels()
end)

net.Receive(NET_SEND_OVERRIDES, function()
  LocalCategoryOverrides = net.ReadTable() or {}
  print("[Shop Debug] Received category overrides: " .. table.Count(LocalCategoryOverrides) .. " items")
  RefreshAllPanels()
end)

net.Receive(NET_SEND_OWNED, function()
  LocalOwnedWeapons = net.ReadTable() or {}
  print("[Shop Debug] Received owned weapons: " .. table.Count(LocalOwnedWeapons) .. " items")
  --[[ Debug print removed for brevity
  for cls, _ in pairs(LocalOwnedWeapons) do
    print(" - " .. cls)
  end
  ]]
  RefreshAllPanels()
end)

net.Receive("UpdateCurrency", function()
  local amount = net.ReadInt(32)
  LocalPlayer():SetNWInt("Currency", amount)
  print("[Shop Debug] Currency updated: £" .. amount)
end)

-- Add a player notification to inform about available methods
hook.Add("InitPostEntity", "WeaponShopHelpMessage", function()
    timer.Simple(5, function()
        chat.AddText(Color(100, 200, 255), "[Weapon Shop] ", Color(255, 255, 255),
            "Type !shop or /shop in chat to open the weapon shop")
    end)
end)

print("[Shop Debug] cl_shopmenu.lua v1.26 loaded")