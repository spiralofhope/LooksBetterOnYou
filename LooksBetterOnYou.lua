-- Project: Looks Better On You 1.03-beta
-- File: LooksBetterOnYou.lua
-- Last Modified: 2012-03-14T00:16:02Z
-- Author: msaint
-- Desc: Lets your alts use the dressing room.


local OUR_NAME = "LooksBetterOnYou"
local OUR_VERSION = string.match("1.03-beta", "([%d\.]+)")
OUR_VERSION = tonumber(OUR_VERSION) or 2
local DEBUG = nil
local debug = DEBUG and function(s) DEFAULT_CHAT_FRAME:AddMessage("LBOY: "..s, 1, 0, 0) end or function() return end  

-- **Constants -- Until Blizz changes them
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

local noTransmogInvSlots = {
   INVSLOT_BODY,
   INVSLOT_TABARD,
}

-- **Our Addon Object -- In this case, only used to avoid reloading same or older version
if (LooksBetter and LooksBetter.Version and LooksBetter.Version >= OUR_VERSION) then return end
LooksBetter = LooksBetter or {AddonName = OUR_NAME, Version = OUR_VERSION}

-- **Local references to library functions
local type, tostring, tonumber, next, pairs, ipairs, select, setmetatable = type, tostring, tonumber, next, pairs, ipairs, select, setmetatable 
local math, string, strsplit, table, tinsert = math, string, strsplit, table, tinsert 

-- **Local references to API functions and globals
local GetRealmName, UnitName, UnitRace, UnitSex, UnitClass = GetRealmName, UnitName, UnitRace, UnitSex, UnitClass
local GetTransmogrifySlotInfo, GetInventoryItemID, GetItemInfo, IsEquippableItem = GetTransmogrifySlotInfo, GetInventoryItemID, GetItemInfo, IsEquippableItem
local UIDropDownMenu_Initialize, UIDropDownMenu_AddButton, ToggleDropDownMenu, ShowUIPanel = UIDropDownMenu_Initialize, UIDropDownMenu_AddButton, ToggleDropDownMenu, ShowUIPanel
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local hooksecurefunc = hooksecurefunc

-- **Set up for future localization -- not much to localize, though, I must say.
local L = LooksBetter.L or {}
setmetatable( L, { __index = function(t, text) return text end })

-- **Locals
local events = {}
local lbDB, playerDB
local eFrame = LooksBetterEventFrame or CreateFrame("Frame", "LooksBetterEventFrame", UIParent)
local lbSideButton, lbSideName, lbTopButton, lbTopName, lbMenu
local currentAlt = {realm = GetRealmName(), name = UnitName('player')}
local tryOnList = {} -- Items currently being tried on in the Dressing Room
local sideTryOnList = {} -- ^^ but for SideDressUpFrame
local lbIsTryingOn = nil -- Used to prevent a loop when hooking DressUpModel:TryOn

-- **Local functions
local function chatMsg(s, r, g, b)
   DEFAULT_CHAT_FRAME:AddMessage(s, r, g, b)
end

local function freshenItemData()
-- Calling GetItemInfo fails at the time for uncached items, but triggers a 
-- request to the server. 
   for realm, realmDB in pairs(lbDB) do
      for name, altinfo in pairs(realmDB) do
         debug(name, altinfo.race, altinfo.sex)
         for _, item in pairs(altinfo.equip) do
            GetItemInfo(item)
         end
      end
   end
end

local function initDB()
   local realm = GetRealmName()
   local player = UnitName('player')
   lbDB = LooksBetterDB or {}
   LooksBetterDB = lbDB
   lbDB[realm] = lbDB[realm] or {}
   lbDB[realm][player] = lbDB[realm][player] or {race=(select(2, UnitRace('player'))) , sex=UnitSex('player') , class=(select(2, UnitClass('player'))), equip={}}
   playerDB = lbDB[realm][player] 
end


local function altIsPlayer()
   return currentAlt.name == UnitName("player") and currentAlt.realm == GetRealmName()
end

local function listSavedAlts()
-- Lists alts on this realm for which we have data
   for realm, realmDB in pairs(lbDB) do
      for name, info in pairs(realmDB) do
         chatMsg(realm.."."..name..", "..info.race..", "..info.sex)
      end
   end
end

local function setCurrentAlt(name, realm)
   if not name then
      return
   elseif not realm then
      realm, name = strsplit(".", name)
      if not name then
         name = realm
         realm = GetRealmName()
         -- See if the name exists on the current realm, otherwise search for it.
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
      if lbSideButton:IsShown() then 
         lbSideButton.tooltip = L["Currently viewing "]..name..L[" in the Dressing Room.  Click to select another character"]
         lbSideButton:SetChecked(not altIsPlayer())
         lbSideName:SetText(name)
      end
      if lbTopButton:IsShown() then
         lbTopButton.tooltip = L["Currently viewing "]..name..L[" in the Dressing Room.  Click to select another character"]
         lbTopButton:SetChecked(not altIsPlayer())
         lbTopName:SetText(name)
      end
      return name, realm
   end
end

local function slashCmdParser(name)
-- Leaving in slash command functionality for now, although it is not documented
   if type(name) == "string" then
      if name == "list" then
         listSavedAlts()
      elseif name == "reset" then
         setCurrentAlt(UnitName("player"))
         if DressUpFrame:IsShown() then
            DressUpModel:SetUnit("player")
         end
         if SideDressUpFrame:IsShown() then
            SideDressUpModel:SetUnit("player")
         end
      else
         if setCurrentAlt(name) then
            if not (DressUpFrame:IsShown() or SideDressUpFrame:IsShown()) then
      			ShowUIPanel(DressUpFrame)
      		end
            if DressUpFrame:IsShown() then
               DressUpModel:SetUnit("player")
            end
            if SideDressUpFrame:IsShown() then
               SideDressUpModel:SetUnit("player")
            end
         end
      end
   end
end

local function loadAltDressup()
   local name, realm = currentAlt.name, currentAlt.realm
   local alt = lbDB and lbDB[realm] and lbDB[realm][name] or nil
   if alt and alt.race and alt.sex then
      lbIsTryingOn = true -- Prevent a loop in hooked TryOn function
      for _, model in pairs({DressUpModel, SideDressUpModel}) do
         if model:IsShown() then      
            if altIsPlayer() then
               model:Dress()
            else
               model:SetCustomRace(raceID[string.upper(alt.race)], alt.sex - 2)
               model:Undress() -- Must be after SetCustomRace
               for _, item in pairs(alt.equip) do -- Load the alts visible items
                  if IsEquippableItem(item) and not ((select(9, GetItemInfo(item))) == "INVTYPE_BAG") then
                     --debug((GetItemInfo(item)))
                     model:TryOn("item:"..item)
                  end
               end
            end
            local list = (model == DressUpModel) and tryOnList or sideTryOnList
            for _, item in ipairs(list) do -- Load any items that have been ctr-clicked already
               if IsEquippableItem(item) and not ((select(9, GetItemInfo(item))) == "INVTYPE_BAG") then
                  --debug((GetItemInfo(item)))
                  model:TryOn("item:"..item)
               end
            end
         end
      end
      lbIsTryingOn = nil
   end
end

local function onDress(self)
-- Hook to keep model of currentAlt (see ADDON_LOADED)
   if not lbIsTryingOn then
      debug("Entered onDress")
      if self == DressUpModel then
         tryOnList = {}
      elseif self == SideDressUpModel then 
         sideTryOnList = {}
      end
      if not altIsPlayer() then
         loadAltDressup()
      end
   end
end

local function onTryOn(self, link)
   if not lbIsTryingOn then
      local itemId = string.match(link, "^.-:(%d*)", 1)
      debug("Tryed on item:"..tostring(itemId))
      if self == DressUpModel then
         table.insert(tryOnList, itemId)   
      elseif self == SideDressUpModel then 
         table.insert(sideTryOnList, itemId)
      else
         debug("onTryon: Invalid model frame")
      end
   end
end

-- **Button functionality
local function lbButtonOnClick(self)
   self:SetChecked(not altIsPlayer()) -- Button is highlighted if an Alt is shown
   ToggleDropDownMenu(1, nil, lbMenu, self, 0, 0)
end

local function lbButtonOnShow(self)
   debug("Entered lbButtonOnShow")
   self:SetChecked(not altIsPlayer())
   _G[self:GetName().."Name"]:SetText(currentAlt.name)
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

-- **Menu functions
local function rgbToStr(rgb)
   --takes a table of r,g,b values and gives back a string to prepend to text
   local r, g, b = math.floor(rgb.r * 255), math.floor(rgb.g * 255), math.floor(rgb.b * 255)
   return string.format("|cff%.2x%.2x%.2x", r, g, b)
end

local function getMenuInfo(name, realm)
   --UIDropDownMenu_AddButton needs a table with information about the entry
   local db = lbDB[realm][name]
   if db then
      local classColor = rgbToStr(RAID_CLASS_COLORS[db.class]) 
      local info = {
         text = name,
         value = realm.."."..name,
         checked = ((name == currentAlt.name) and (realm == currentAlt.realm)),
         colorCode = classColor, 
         func = function(self, arg1, arg2)
               setCurrentAlt(arg1, arg2)
               loadAltDressup()   
            end,
         arg1 = name,
         arg2 = realm,
         }
      return info
   end
end

local function menuOnLoad()
   --Populate our table of menu entries
   local player, thisRealm = UnitName('player'), GetRealmName()
   local realmInfo = {isTitle = true, notCheckable = true}
      --Realm line for this realm
   realmInfo.text = thisRealm
   realmInfo.value = thisRealm
   UIDropDownMenu_AddButton(realmInfo, 1)           
      --Start with the player
   UIDropDownMenu_AddButton(getMenuInfo(player, thisRealm), 1)
      --Now other characters on the current realm
   for name, _ in pairs(lbDB[thisRealm]) do
      if not (name == player) then
         UIDropDownMenu_AddButton(getMenuInfo(name, thisRealm), 1)
      end
   end
      --Now all alts on other realms
   for realm, realmDB in pairs(lbDB) do
      if not (realm == thisRealm) then
         realmInfo.text = realm
         realmInfo.value = realm
         UIDropDownMenu_AddButton(realmInfo, 1)           
         for name, _ in pairs(realmDB) do
            UIDropDownMenu_AddButton(getMenuInfo(name, realm), 1)
         end
      end
   end
end   

local function initMenu()
   debug("Initializing Menu")
   lbMenu = LooksBetterMenu
   UIDropDownMenu_Initialize(lbMenu, menuOnLoad, "MENU")
end

-- **Event handling and triggers
function events:ADDON_LOADED(...)
   local addonName = ...
   if (addonName == OUR_NAME) then
      self:UnregisterEvent("ADDON_LOADED")
      self:RegisterEvent("PLAYER_LOGIN")
      hooksecurefunc(DressUpModel, "SetUnit", onDress)
      hooksecurefunc(DressUpModel, "Dress", onDress)
      hooksecurefunc(DressUpModel, "TryOn", onTryOn)            
      hooksecurefunc(SideDressUpModel, "SetUnit", onDress)
      hooksecurefunc(SideDressUpModel, "Dress", onDress)
      hooksecurefunc(SideDressUpModel, "TryOn", onTryOn)            

      initDB() -- Make sure our database is there and contains this character
      initButton() -- Attach our button to the dressup frame
      initMenu() -- Tell the client about our dropdown menu
      freshenItemData() -- Loads item data for everything our alts have equipped
      SlashCmdList["LOOKSBETTER"] = slashCmdParser -- Add Slash Commands
      SLASH_LOOKSBETTER1 = "/lboy"
      self.ADDON_LOADED = nil -- We don't need this function anymore.
   end
end

function events:PLAYER_LOGIN()
	self:UnregisterEvent('PLAYER_LOGIN')
  	self:RegisterEvent('UNIT_INVENTORY_CHANGED')
   chatMsg(L["\"Looks Better On You!\" loaded."])
   chatMsg(L["  Click the tab at the top right of the Dressing Room to select and view Alts."])
   self:UNIT_INVENTORY_CHANGED("player") -- Store initial equipped items
   self.PLAYER_LOGIN = nil -- We don't need this function anymore.    
end   


function events:UNIT_INVENTORY_CHANGED(unit)
-- Store any changes in this character's equipped items   
   if unit == 'player' then
      for _, i in ipairs(transmogInvSlots) do
         -- Store the item id for the visible item
         playerDB.equip[i] = (select(6, GetTransmogrifySlotInfo(i)))
      end
      for _, i in ipairs(noTransmogInvSlots) do
         -- Store the item id for the actual item for shirt and tabard
         playerDB.equip[i] = GetInventoryItemID("player", i) 
      end
   end
end

do
-- Think of this as an OnLoad function for our event frame.
-- registered events will be redirected to event:EVENT_NAME(...)
   eFrame = LooksBetterEventFrame or CreateFrame("Frame", "LooksBetterEventFrame", UIParent)
   eFrame:SetScript("OnEvent", function(self, event, ...)
         events[event](events, ...)
      end)
   eFrame:RegisterEvent("ADDON_LOADED")
end
   
-- Since the handlers are on the event object, lets make registering intuitive
function events:RegisterEvent(...)
   eFrame:RegisterEvent(...)
end

function events:UnregisterEvent(...)
   eFrame:UnregisterEvent(...)
end
