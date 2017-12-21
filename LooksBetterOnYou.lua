-- Project: Looks Better On You r23
-- File: LooksBetterOnYou.lua
-- Last Modified: 2012-04-11T01:25:41Z
-- Author: msaint
-- Desc: Lets your alts use the dressing room.
-- Acknowledgements: Thanks to a particular pal for pushing me to write this.

--
-- ************* ADDON ADMIN **************
-- ****************************************

-- **Debugging
local DEBUG = false
local debug = DEBUG and function(s) DEFAULT_CHAT_FRAME:AddMessage("LBOY: "..s, 1, 0, 0) end or function() return end  

-- **Set up for future localization --not much to localize, though, I must say.
local L = {} --This just allows me to already write strings as L["text"] 
setmetatable( L, { __index = function(t, text) return text end })


--
-- *********** LOCAL REFERENCES ***********
-- ****************************************

-- **Local references to library functions
local type, tostring, tonumber, next, pairs, ipairs, select = type, tostring, tonumber, next, pairs, ipairs, select 
local math, string, strsplit, table, tinsert = math, string, strsplit, table, tinsert 

-- **Local references to API functions and globals
local GetRealmName, UnitName, UnitRace, UnitSex, UnitClass = GetRealmName, UnitName, UnitRace, UnitSex, UnitClass
local GetItemTransmogrifyInfo, GetInventoryItemID, GetItemInfo, IsEquippableItem = GetItemTransmogrifyInfo, GetInventoryItemID, GetItemInfo, IsEquippableItem
local UIDropDownMenu_Initialize, UIDropDownMenu_AddButton, ToggleDropDownMenu, ShowUIPanel = UIDropDownMenu_Initialize, UIDropDownMenu_AddButton, ToggleDropDownMenu, ShowUIPanel
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local hooksecurefunc = hooksecurefunc


--
-- ******* LOCAL VARIABLES & TABLES *******
-- ****************************************

-- **Constants --Until Blizz changes them
local raceID = {
   HUMAN = 1,
   ORC = 2,
   DWARF = 3,
   NIGHTELF = 4,
   SCOURGE = 5,
   TAUREN = 6,
   GNOME = 7,
   TROLL = 8,
   GOBLIN = 9,
   BLOODELF = 10,
   DRAENEI = 11,
   WORGEN = 22,
}

local menuModelNames = {
   HUMAN = "Human",
	ORC = "Orc",
	DWARF = "Dwarf",
	NIGHTELF = "Nightelf",
	SCOURGE = "Undead",
	TAUREN = "Tauren",
	GNOME = "Gnome",
	TROLL = "Troll",
	GOBLIN = "Goblin",
	BLOODELF = "Bloodelf",
	DRAENEI = "Draenei",
	WORGEN = "Worgen",
}

local alphaOrderedRaces = {
   "BLOODELF",
   "DRAENEI",
   "DWARF",
   "GNOME",
   "GOBLIN",
   "HUMAN",
   "NIGHTELF",
   "ORC",
   "TAUREN",
   "TROLL",
   "SCOURGE", --Undead, so 'U'
   "WORGEN",
}

local transmogInvSlots = {
   INVSLOT_HEAD,
   INVSLOT_SHOULDER,
   INVSLOT_CHEST,
   INVSLOT_WAIST,
   INVSLOT_LEGS,
   INVSLOT_FEET,
   INVSLOT_WRIST,
   INVSLOT_HAND,
   INVSLOT_BACK,
   INVSLOT_MAINHAND,
   INVSLOT_OFFHAND,
   INVSLOT_RANGED,
}

local invTypeToSlot = {
   INVTYPE_HEAD = INVSLOT_HEAD,
   INVTYPE_SHOULDER = INVSLOT_SHOULDER,
   INVTYPE_BODY = INVSLOT_BODY,
   INVTYPE_CHEST = INVSLOT_CHEST,
   INVTYPE_ROBE = INVSLOT_CHEST,
   INVTYPE_WAIST = INVSLOT_WAIST,
   INVTYPE_LEGS = INVSLOT_LEGS,
   INVTYPE_FEET = INVSLOT_FEET,
   INVTYPE_WRIST = INVSLOT_WRIST,
   INVTYPE_HAND = INVSLOT_HAND,
   INVTYPE_CLOAK = INVSLOT_BACK,
   INVTYPE_SHIELD = INVSLOT_OFFHAND,
   INVTYPE_2HWEAPON = INVSLOT_MAINHAND,
   INVTYPE_WEAPONMAINHAND = INVSLOT_MAINHAND,
   INVTYPE_WEAPONOFFHAND = INVSLOT_OFFHAND,
   INVTYPE_HOLDABLE = INVSLOT_OFFHAND,
   INVTYPE_RANGED = INVSLOT_RANGED,
   INVTYPE_THROWN = INVSLOT_RANGED,
   INVTYPE_TABARD = INVSLOT_TABARD, 
} 

local noTransmogInvSlots = {
   INVSLOT_BODY,
   INVSLOT_TABARD,
}

local visibleNoWepInvSlots = {
   INVSLOT_BODY,
   INVSLOT_TABARD,
   INVSLOT_HEAD,
   INVSLOT_SHOULDER,
   INVSLOT_CHEST,
   INVSLOT_WAIST,
   INVSLOT_LEGS,
   INVSLOT_FEET,
   INVSLOT_WRIST,
   INVSLOT_HAND,
   INVSLOT_BACK,
}

local DEFAULT_MH, DEFAULT_EH = 25318, 36497 --Used to force correct weapon loading sequence

--local saveOutfitPopup --Defined later because the OnAccept needs local utility functions


-- **Variables & Tables
local events = {} --Object on which event handlers will be placed
local lbDB, playerDB --Local references to saved alt databases
local savedOutfits --Local reference to saved outfits 
local lbSideButton, lbSideName, lbTopButton, lbTopName, lbMenu --UI elements
local currentAlt = {realm = GetRealmName(), name = UnitName('player')}
local tryOnList = {} --Items currently being tried on in the Dressing Room
local sideTryOnList = {} --^^ but for SideDressUpFrame
local lbIsTryingOn = nil --Used to prevent a loop when hooking DressUpModel:TryOn
local lastWeaponSlot = INVSLOT_OFFHAND --This is ugly, but so is the DressUp code's handling of weapons

--
-- *********** LOCAL FUNCTIONS ************
-- ****************************************


-- **Miscellaneous
--
local function chatMsg(s, r, g, b)
   DEFAULT_CHAT_FRAME:AddMessage(s, r, g, b)
end

local function shallowCopy(destT, sourceT)
--Does a shallow copy of sourceT INTO destT (i.e. overwrites only as needed)
--If only one table is passed, a shallow copy is placed in a new table and returned.
   if not sourceT then
      sourceT = destT
      destT = {}
   end
   if not destT or type(destT) ~= "table" then
      destT = {}
   end
   if sourceT and type(sourceT) == "table" then
      for a, b in pairs(sourceT) do
         destT[a] = b
      end
   end
   return destT
end

StaticPopupDialogs["LBOY_SAVE_OUTFIT"] = {
   text = "Save the current outfit as:",
   button1 = "Save",
   button2 = "Cancel",
   hasEditBox = true,
   maxLetters = 18,
   OnShow = function(self) --Since the editbox starts blank, the save button should be disabled
         self.editBox:SetText("")
         self.button1:Disable()
      end, 
   OnAccept = function(self)
         local outfitName = self.editBox:GetText()
         if not savedOutfits[outfitName] then
            local list = DressUpFrame:IsVisible() and tryOnList or sideTryOnList  
            savedOutfits[outfitName] = shallowCopy(shallowCopy(currentAlt.info.equip), list)
         end
      end,
   EditBoxOnTextChanged = function(self)
         text = self:GetText()
         if text and text ~= "" and not savedOutfits[text] then
            self:GetParent().button1:Enable()
         else
            self:GetParent().button1:Disable()
         end
      end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   exclusive = true,
   preferredIndex = 3,  --claims abound that this avoids some UI taint to the glyph frame. I'll have to look into it. 
}

StaticPopupDialogs["LBOY_DELETE_CONFIRM"] = {
   text = "Are you sure you want to delete saved outfit \'%s\'?",
   button1 = "Delete",
   button2 = "Cancel",
   OnAccept = function(self, outfitName)
         if savedOutfits[outfitName] then
            savedOutfits[outfitName] = nil
         end
      end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
   exclusive = true,
   preferredIndex = 3,  --claims abound that this avoids some UI taint to the glyph frame. I'll have to look into it. 
}


-- **Alt handling functions
--
local function altIsPlayer()
   return currentAlt.name == UnitName("player") and currentAlt.realm == GetRealmName()
end

local function setGenericAlt(race, sex)
   local name = menuModelNames[race] .. (((sex==2) and " Male") or ((sex==3) and " Female")) 
   currentAlt.name = name 
   currentAlt.realm = "GENERIC"
   currentAlt.info = {race = race, sex = sex, class = "WARRIOR", equip = {}}
   if lbSideButton:IsVisible() then 
      lbSideButton.tooltip = L["Currently viewing "]..name..L[" in the Dressing Room.  Click to select another character"]
      lbSideButton:SetChecked(not altIsPlayer())
      lbSideName:SetText(name)
   end
   if lbTopButton:IsVisible() then
      lbTopButton.tooltip = L["Currently viewing "]..name..L[" in the Dressing Room.  Click to select another character"]
      lbTopButton:SetChecked(not altIsPlayer())
      lbTopName:SetText(name)
   end
   return name, realm
end

local function setCurrentAlt(name, realm)
   if not name then
      return
   elseif not realm then
      realm, name = strsplit(".", name)
      if not name then
         name = realm
         realm = GetRealmName()
         --See if the name exists on the current realm, otherwise search for it.
         if not (lbDB[realm] and lbDB[realm][name]) then
            for realmname, realmDB in pairs(lbDB) do
               if realmDB[name] then
                  realm = realmname
                  break
               end
            end
         end
      end
   end
   local alt = lbDB and lbDB[realm] and lbDB[realm][name] or nil
   if alt and alt.race and alt.sex then
      currentAlt.name = name
      currentAlt.realm = realm
      currentAlt.info = alt
      if lbSideButton:IsVisible() then 
         lbSideButton.tooltip = L["Currently viewing "]..name..L[" in the Dressing Room.  Click to select another character"]
         lbSideButton:SetChecked(not altIsPlayer())
         lbSideName:SetText(name)
      end
      if lbTopButton:IsVisible() then
         lbTopButton.tooltip = L["Currently viewing "]..name..L[" in the Dressing Room.  Click to select another character"]
         lbTopButton:SetChecked(not altIsPlayer())
         lbTopName:SetText(name)
      end
      return name, realm
   end
end

-- **I'm not sure why, but my instinct is to keep the slash commands for now
-- 

local function listSavedAlts()
--Lists alts on this realm for which we have data, called only via "/lboy list"
   for realm, realmDB in pairs(lbDB) do
      for name, info in pairs(realmDB) do
         chatMsg(realm.."."..name..", "..info.race..", "..info.sex)
      end
   end
end

local function slashCmdParser(name)
--Leaving in slash command functionality for now, although it is not documented
   if type(name) == "string" then
      if name == "list" then
         listSavedAlts()
      elseif name == "reset" then
         setCurrentAlt(UnitName("player"))
         if DressUpFrame:IsVisible() then
            DressUpModel:SetUnit("player")
         end
         if SideDressUpFrame:IsVisible() then
            SideDressUpModel:SetUnit("player")
         end
      else
         if setCurrentAlt(name) then
            if not (DressUpFrame:IsVisible() or SideDressUpFrame:IsVisible()) then
      			ShowUIPanel(DressUpFrame)
      		end
            if DressUpFrame:IsVisible() then
               DressUpModel:SetUnit("player")
            end
            if SideDressUpFrame:IsVisible() then
               SideDressUpModel:SetUnit("player")
            end
         end
      end
   end
end


-- **Character model functions
--

local function tryOnWeapons(model, mh, oh)
--Model is very quirky when trying on weapons where the offhand 
--can be equipped in the main hand. To guarantee that the correct
--weapon goes in each hand, we have to first try on a main-hand-only
--weapon, then one that can go in either hand, then our OH, then
--our MH.
   if mh and IsEquippableItem(mh) then 
      model:TryOn("item:"..tostring(DEFAULT_MH))
      model:TryOn("item:"..tostring(DEFAULT_EH))
   end
   if oh and IsEquippableItem(oh) then 
      model:TryOn("item:"..oh)
   end
   if mh and IsEquippableItem(mh) then 
      model:TryOn("item:"..mh)
      lastWeaponSlot = INVSLOT_MAINHAND
   end
end

local function loadAltDressup()
   local alt = currentAlt.info
   if alt and alt.race and alt.sex then
      lbIsTryingOn = true --Prevent a loop in hooked TryOn function
      for _, model in pairs({DressUpModel, SideDressUpModel}) do
         if model:IsVisible() then      
            model:SetCustomRace(raceID[string.upper(alt.race)], alt.sex - 2)
            model:Undress() --Must be after SetCustomRace
            for _, i in ipairs(visibleNoWepInvSlots) do --Load the alts visible items
               local item = alt.equip[i]
               if IsEquippableItem(item) then
                  model:TryOn("item:"..item)
               end
            end
            --Now overwrite with whatever has been tried on in this session
            local list = (model == DressUpModel) and tryOnList or sideTryOnList
            for slot, item in pairs(list) do --Load any items that have been ctr-clicked already
               if (not ((slot == INVSLOT_MAINHAND) or (slot == INVSLOT_OFFHAND) or (slot == INVSLOT_RANGED))) and
                     IsEquippableItem(item) and not ((select(9, GetItemInfo(item))) == "INVTYPE_BAG") then
                  debug("Dressing from tryOnList: "..(GetItemInfo(item)))
                  model:TryOn("item:"..item)
               end
            end
            --Weapons are last, since they are tricky to handle individually
            local mh = list[INVSLOT_MAINHAND] or alt.equip[INVSLOT_MAINHAND]
            local oh = list[INVSLOT_OFFHAND] or alt.equip[INVSLOT_OFFHAND] 
            tryOnWeapons(model, mh, oh)
            --Special handling for hunters - they should show ranged weapon by default.
            if alt.class == "HUNTER" and IsEquippableItem(alt.equip[INVSLOT_RANGED]) then
               model:TryOn("item:"..alt.equip[INVSLOT_RANGED])
               lastWeaponSlot = INVSLOT_OFFHAND --Because after a ranged item, the next item goes in the mainhand
            end 
         end
      end
      lbIsTryingOn = nil
   end
end

local function saveCurrentOutfit()
--Show a dialog with and edit box to name and save the current outfit
   StaticPopup_Show("LBOY_SAVE_OUTFIT")
end

local function loadSavedOutfit(outfitName)
--Loading an outfit makes it the reset outfit for the current alt.
--To return an alt to their actual saved equipment, they must be re-selected
--in the menu.
   local outfit = savedOutfits[outfitName] 
   if not outfit then
      return
   end
   local list = (DressUpFrame:IsVisible()) and tryOnList or sideTryOnList
   wipe(list)
   shallowCopy(list, outfit)
   loadAltDressup()
end

local function deleteSavedOutfit(f, outfitName)
   local dialog = StaticPopup_Show("LBOY_DELETE_CONFIRM", outfitName)
   if (dialog) then
     dialog.data  = outfitName
   end
end

local function onDress(self)
--Hook to keep model of currentAlt (see ADDON_LOADED)
   if not lbIsTryingOn then
      debug("Entered onDress")
      if self == DressUpModel then
         wipe(tryOnList)
      elseif self == SideDressUpModel then 
         wipe(sideTryOnList)
      end
      loadAltDressup()
   end
end

local function onTryOn(self, link)
   if not lbIsTryingOn then
      if not currentAlt.info then
         local name, realm = UnitName("player"), GetRealmName()
         setCurrentAlt(name, realm)
      end
      local itemId = string.match(link, "^.-:(%d*)", 1)
      local _, _, _, _, _, itemType , _, _, invType = GetItemInfo(itemId)
      local slot = invTypeToSlot[invType]  
      if (slot == INVSLOT_MAINHAND) or (slot == INVSLOT_OFFHAND) then
         lastWeaponSlot = INVSLOT_OFFHAND --Reflects reality, more or less, however odd it may seem.
      elseif (not slot) and (invType == "INVTYPE_WEAPON") then
         slot = (lastWeaponSlot == INVSLOT_OFFHAND) and INVSLOT_MAINHAND or INVSLOT_OFFHAND
         lastWeaponSlot = slot
      end
      debug("Tryed on item:"..tostring(itemId))
      if self == DressUpModel then
         tryOnList[slot] = tonumber(itemId)   
      elseif self == SideDressUpModel then 
         sideTryOnList[slot] = tonumber(itemId)
      else
         debug("onTryon: Invalid model frame")
      end
   end
end


-- **Button functions
--

local function lbButtonOnClick(self)
   self:SetChecked(not altIsPlayer()) --Button is highlighted if an Alt is shown
   ToggleDropDownMenu(1, nil, lbMenu, self, 0, 0)
end

local function lbButtonOnShow(self)
   debug("Entered lbButtonOnShow")
   self:SetChecked(not altIsPlayer())
   _G[self:GetName().."Name"]:SetText(currentAlt.name)
end


-- **Menu functions
--

local function rgbToStr(rgb)
--takes a table of r,g,b values and gives back a string to prepend to text
   local r, g, b = math.floor(rgb.r * 255), math.floor(rgb.g * 255), math.floor(rgb.b * 255)
   return string.format("|cff%.2x%.2x%.2x", r, g, b)
end

local function getAltMenuInfo(name, realm)
--generate UIDropDownMenu_AddButton info table with information about handling the entries for this alt
   local db = lbDB[realm][name]
   if db then
      local classColor = rgbToStr(RAID_CLASS_COLORS[db.class]) 
      local info = UIDropDownMenu_CreateInfo() 
      info.text = name
      info.value = realm.."."..name
      info.checked = ((name == currentAlt.name) and (realm == currentAlt.realm))
      info.colorCode = classColor 
      info.func = function(self, arg1, arg2)
            setCurrentAlt(arg1, arg2)
            loadAltDressup()   
         end
      info.arg1 = name
      info.arg2 = realm
      return info
   end
end

local function getGenericMenuInfo(race, sex)
--generate UIDropDownMenu_AddButton info table with information about handling the entries for this model
   if menuModelNames[race] and ((sex == 3) or (sex == 2)) then
      local info = UIDropDownMenu_CreateInfo()
      info.text = menuModelNames[race] .. (((sex==2) and " Male") or ((sex==3) and " Female"))
      info.value = {race = race, sex = sex}
      info.checked = (info.text == currentAlt.name) and (currentAlt.realm == "GENERIC")
      info.arg1 = race
      info.arg2 = sex
      info.func = function(self, arg1, arg2)
            setGenericAlt(arg1, arg2)
            loadAltDressup()
         end
      return info
   end
end

local function getSavedOutfitInfo(outfitName)
--generate UIDropDownMenu_AddButton info table with information about handling the entries for this outfit
   if savedOutfits[outfitName] then
      local info = UIDropDownMenu_CreateInfo()
      info.text = outfitName
      info.value = outfitName
      info.notCheckable = true
      info.arg1 = outfitName
      info.func = function(self, arg1)
            loadSavedOutfit(arg1)
         end
      return info
   end
end

local function menuOnLoad(f, level)
--Load either the level one menu showing alts, or the level two menu
--showing all generic models.
   if level == 1 then
      --Populate the menu with class-colored alt names
      local player, thisRealm = UnitName('player'), GetRealmName()
      local info = UIDropDownMenu_CreateInfo()
      --Realm line for this realm
      info.isTitle = true
      info.notCheckable = true
      info.text = thisRealm
      info.value = thisRealm
      UIDropDownMenu_AddButton(info, 1)           
         --Start with the player
      UIDropDownMenu_AddButton(getAltMenuInfo(player, thisRealm), 1)
         --Now other characters on the current realm
      for name, _ in pairs(lbDB[thisRealm]) do
         if not (name == player) then
            UIDropDownMenu_AddButton(getAltMenuInfo(name, thisRealm), 1)
         end
      end
      --Now all alts on other realms
      for realm, realmDB in pairs(lbDB) do
         if not (realm == thisRealm) then
            info.text = realm --reuse info as is changing realm name for each realm title line
            info.value = realm
            UIDropDownMenu_AddButton(info, 1)           
            for name, _ in pairs(realmDB) do
               UIDropDownMenu_AddButton(getAltMenuInfo(name, realm), 1)
            end
         end
      end
      do
         --Save the current outfit
         info = UIDropDownMenu_CreateInfo()
         info.text = "Save Outfit"
         info.value = "saveOutfit"
         info.notCheckable = true
         info.arg1 = outfitName
         info.func = saveCurrentOutfit
         UIDropDownMenu_AddButton(info, 1)
         --Sub-menu with saved outfits
         info = UIDropDownMenu_CreateInfo()
         info.text = "Load Outfit"
         info.value = "loadOutfit"
         info.hasArrow = true
         info.notCheckable = true
         info.disabled = not next(savedOutfits)
         UIDropDownMenu_AddButton(info, 1)
         --Sub-menu to delete saved outfits
         info = UIDropDownMenu_CreateInfo()
         info.text = "Delete Outfit"
         info.value = "deleteOutfit"
         info.hasArrow = true
         info.notCheckable = true
         info.disabled = not next(savedOutfits)
         UIDropDownMenu_AddButton(info, 1)
         --Sub-menu with generic models
         info = UIDropDownMenu_CreateInfo()
         info.text = "All Models"
         info.value = "allModelsSubmenu"
         info.hasArrow = true
         info.notCheckable = true
         UIDropDownMenu_AddButton(info, 1)
      end      
   elseif level == 2 then
      if UIDROPDOWNMENU_MENU_VALUE == "allModelsSubmenu" then
         for _, race in ipairs(alphaOrderedRaces) do
            UIDropDownMenu_AddButton(getGenericMenuInfo(race, 3), 2)
            UIDropDownMenu_AddButton(getGenericMenuInfo(race, 2), 2)
         end
      elseif UIDROPDOWNMENU_MENU_VALUE == "loadOutfit" then
         for outfitName, _ in pairs(savedOutfits) do
            UIDropDownMenu_AddButton(getSavedOutfitInfo(outfitName), 2)
         end
      elseif UIDROPDOWNMENU_MENU_VALUE == "deleteOutfit" then
         for outfitName, _ in pairs(savedOutfits) do
            local info = getSavedOutfitInfo(outfitName)
            info.func = deleteSavedOutfit
            UIDropDownMenu_AddButton(info, 2)
         end
      end
   end
end   


-- **Initialization of item data, UI elements, and alt database
--

local function freshenItemData()
--Calling GetItemInfo fails at the time for uncached items, but triggers a 
--request to the server and caches the data. 
   for realm, realmDB in pairs(lbDB) do
      for name, altinfo in pairs(realmDB) do
         debug(name, altinfo.race, altinfo.sex)
         for _, item in pairs(altinfo.equip) do
            GetItemInfo(item)
         end
      end
   end
   --The next two are used for properly loading weapons
   local _, _ = GetItemInfo(DEFAULT_MH), GetItemInfo(DEFAULT_EH)
end

local function initMenu()
   debug("Initializing Menu")
   lbMenu = LooksBetterMenu
   UIDropDownMenu_Initialize(lbMenu, menuOnLoad, "MENU")
end

local function initButton()
   debug("Initializing Button")
   lbSideButton = LooksBetterSideButton
   lbSideName = LooksBetterSideButtonName 
   lbSideButton:SetScript("OnShow", lbButtonOnShow)
   lbSideButton:SetScript("OnClick", lbButtonOnClick)
   lbSideButton.tooltip = L["Currently viewing "]..currentAlt.name..L[" in the Dressing Room.\nClick to select another character."]
   lbTopButton = LooksBetterTopButton
   lbTopName = LooksBetterTopButtonName
   lbTopButton:SetScript("OnShow", lbButtonOnShow)
   lbTopButton:SetScript("OnClick", lbButtonOnClick)
   lbTopButton.tooltip = L["Currently viewing "]..currentAlt.name..L[" in the Dressing Room.\nClick to select another character."]
end

local function initDB()
   local realm = GetRealmName()
   local player = UnitName('player')
   lbDB = LooksBetterDB or {}
   LooksBetterDB = lbDB
   lbDB[realm] = lbDB[realm] or {}
   lbDB[realm][player] = lbDB[realm][player] or {race=(select(2, UnitRace('player'))) , sex=UnitSex('player') , class=(select(2, UnitClass('player'))), equip={}}
   playerDB = lbDB[realm][player]
   savedOutfits = LooksBetterSavedOutfits or {}
   LooksBetterSavedOutfits = savedOutfits
end

local function addonInit()
   hooksecurefunc(DressUpModel, "SetUnit", onDress)
   hooksecurefunc(DressUpModel, "Dress", onDress)
   hooksecurefunc(DressUpModel, "TryOn", onTryOn)            
   hooksecurefunc(SideDressUpModel, "SetUnit", onDress)
   hooksecurefunc(SideDressUpModel, "Dress", onDress)
   hooksecurefunc(SideDressUpModel, "TryOn", onTryOn)            
   initDB() --Make sure our database is there and contains this character
   initButton() --Attach our button to the dressup frame
   initMenu() --Tell the client about our dropdown menu
   freshenItemData() --Loads item data for everything our alts have equipped
   SlashCmdList["LOOKSBETTER"] = slashCmdParser --Add Slash Commands
   SLASH_LOOKSBETTER1 = "/lboy"
   events:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
end
                                                 

--
-- *********** EVENT HANDLING *************
-- ****************************************

function events:PLAYER_ENTERING_WORLD()
   addonInit() --Set up db and ui elements, cache item data, set hooks, set /cmd
   events:SetTimedCallback(events.PLAYER_EQUIPMENT_CHANGED, 3)  --Trigger saving of equipped item information
   chatMsg(L["\"Looks Better On You!\" loaded."]) --Hello, world! ... or hello, player, anyhow
   chatMsg(L["  Click the tab at the top right of the Dressing Room to select and view Alts."])
   self:UnregisterEvent('PLAYER_ENTERING_WORLD')
   self.PLAYER_ENTERING_WORLD = nil
end   

function events:PLAYER_EQUIPMENT_CHANGED(slot, hasItem)
--Store any changes in this character's equipped items   
   debug("Entered PLAYER_EQUIPMENT_CHANGED")
   --We do not actually track changes in helm/cloak visibility. We only check
   --here.
   local helm, cloak = ShowingHelm(), ShowingCloak() 
   if (playerDB.helm ~= helm) or (playerDB.cloak ~= cloak) then
      slot = nil --Force refresh of all items
      playerDB.helm = helm
      playerDB.cloak = cloak
   end
   for _, i in ipairs(transmogInvSlots) do
      --Store the item id for the visible item
      if (not slot) or (i == slot) then
         if GetInventoryItemID("player", i) then
         --GetInventoryItemID above is used to guarantee that item data is there.
         --GetTransmogrigySlotInfo will crash WoW in Mac and 64-bit Windows
         --clients if called before item data is available. 
            playerDB.equip[i] = (select(6, GetItemTransmogrifyInfo(i)))
         elseif not (slot and hasItem) then
            playerDB.equip[i] = nil
         end
      end
   end
   for _, i in ipairs(noTransmogInvSlots) do
      --Store the item id for the actual item for shirt and tabard
      if (not slot) or (i == slot) then
         playerDB.equip[i] = GetInventoryItemID("player", i)
      end 
   end
   playerDB.equip[INVSLOT_HEAD] = helm and playerDB.equip[INVSLOT_HEAD] or nil
   playerDB.equip[INVSLOT_BACK] = cloak and playerDB.equip[INVSLOT_BACK] or nil
end


-- **Set up event handling frame
--

do
   local eFrame = LooksBetterEventFrame or CreateFrame("Frame", "LooksBetterEventFrame", UIParent)
   local callbacks = {}
   local timeSinceStart = 0
   
   --No need for OnUpdate until a timer / trigger is set
   eFrame:Hide()
   
   --Registered events will be redirected to events:EVENT_NAME(...)
   eFrame:SetScript("OnEvent", function(self, event, ...)
         events[event](events, ...)
      end)
   --We don't initialize with ADDON_LOADED because item data is not guaranteed
   --to be available until PLAYER_ENTERING_WORLD fires. 
   eFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

   local function OnUpdate(self, elapsed)
      timeSinceStart = timeSinceStart + elapsed
      for handle, tEvent in pairs(callbacks) do 
         local data = tEvent.data 
         if (tEvent.check and tEvent.check(timeSinceStart - tEvent.eventStart, data)) then
            debug("We are now trying to execute the action for " .. tEvent.name)
            tEvent.action(data)
            if (not tEvent.repeating) then
               callbacks[handle] = nil
               if not next(callbacks) then
                  eFrame:Hide()
               end
            end
         end
      end
   end
   eFrame:SetScript("OnUpdate", OnUpdate)
   
   function events:SetTriggeredCallback(eName, check, action, data, repeating)
   --This function is more generalized than needed in this addon at this time,
   --but I have it written, the cost is not high, and it could be useful later.
   --Params:
   --    eName --A name for the event/callback.  If unique, can be used to cancel the event.
   --    check --function(elapsed, data) used to check if a callback should trigger.
   --    action --function(data) will be called back if check returns true.
   --    data --arbitrary data to be passed to both check and action.
   --    repeating --If true, the event/callback will not be removed when triggered
   --          and until canceled will keep firing whenever check returns true.
   --Returns:
   --    handle --A unique identifier for this event/callback.  This should be used
   --          when canceling an event, as this is more efficient than using the
   --          event name.    
      debug("Entered SetTriggeredCallback")
      if (type(check) ~= "function" or type(action) ~= "function") then
         return
      else
         debug("We are setting up event : " .. eName)
         --if repeating then Debug("Event " .. eName .. " is repeating") end
         local tEvent = {
            eventStart = timeSinceStart,
            name = eName,
            check = check,
            action = action,
            data = data,
            repeating = repeating,
         }
         local handle = {}
         callbacks[handle] = tEvent
         eFrame:Show()
         return handle
      end                     
   end

   function events:SetTimedCallback(func, delay, data)
   --A more convenient way to set a simple timed callback.
      local check = function(elapsed)
      	if (elapsed > delay) then
      		return true
      	end
      end
      return events:SetTriggeredCallback("generic_timer", check, func, data)  
   end
   
   function events:CancelTriggeredCallback(handle)
   --Parameter can be the handle returned when creating the triggered event,
   --or else the name given as the first parameter when creating the event.
   --It is less efficient and more dangerous to use the name, as the table of
   --callbacks must be searched, and the first matching event will be canceled.
      if (type(index) == "string") then
         -- What, you can't be bothered to store the index?
         for h, tEvent in pairs(callbacks) do
            if (tEvent.name == index) then
               handle = h
               break
            end
         end
      end
      if (callbacks and handle and callbacks[handle]) then
         --Debug("Canceling timed event : " .. callbacks[index].name)
         callbacks[handle] = nil
         if not next(callbacks) then
            eFrame:Hide()
         end
      end
   end
   events.CancelTimedCallback = events.CancelTriggeredCallback
   
   --Since the handlers are on the 'events' object, lets make registering intuitive
   function events:RegisterEvent(...)
      eFrame:RegisterEvent(...)
   end
   
   function events:UnregisterEvent(...)
      eFrame:UnregisterEvent(...)
   end 
end
