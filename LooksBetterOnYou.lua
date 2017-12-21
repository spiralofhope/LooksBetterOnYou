-- Project: Looks Better On You r2
-- File: LooksBetterOnYou.lua
-- Last Modified: 2012-03-11T03:00:12Z
-- Author: msaint
-- Desc: Lets your alts use the dressing room.


local OUR_NAME = "LooksBetterOnYou"
local OUR_VERSION = string.match("r2", "([%d\.]+)")
OUR_VERSION = tonumber(OUR_VERSION) or 2
local DEBUG = nil
local debug = DEBUG and function(s) DEFAULT_CHAT_FRAME:AddMessage(s, 1, 0, 0) end or function() return end  

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

-- **Our Addon Object
if (LooksBetter and LooksBetter.Version and LooksBetter.Version > OUR_VERSION) then return end
LooksBetter = LooksBetter or {}
local lb = LooksBetter
lb.AddonName = OUR_NAME
lb.Version = OUR_VERSION
-- lb.OptionsName = OUR_NAME -- We'll get to these

-- **Set up for future localization
local L = lb.L or {}
setmetatable( L, { __index = function(t, text) return text end })

-- **Local references to library functions
local type, tostring, tonumber, next, pairs, ipairs, setmetatable = type, tostring, tonumber, next, pairs, ipairs, setmetatable 
local math, string, table, tinsert = math, string, table, tinsert 

-- **Local references to API functions
local GetItemInfo = GetItemInfo

-- **Locals
local events = {}
local eFrame
local lbDB, playerDB

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
--          local itemID = string.match(link, "%d+", 1)
            GetItemInfo(item)
         end
      end
   end
end

local function listSavedAlts()
-- Lists alts on this realm for which BagBrother has data
   for realm, realmDB in pairs(lbDB) do
      for name, info in pairs(realmDB) do
         chatMsg(realm.."."..name..", "..info.race..", "..info.sex)
      end
   end
end

local function slashCmdParser(name)
   if type(name) == "string" then
      if name == "list" then
         listSavedAlts()
      else
         lb:loadAltDressup(name)
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

-- **Event handling and triggers
function events:ADDON_LOADED(...)
   local addonName = ...
   chatMsg(addonName)
   if (addonName == OUR_NAME) then
      self:UnregisterEvent("ADDON_LOADED")
      self:RegisterEvent("PLAYER_LOGIN")
      initDB()   
      -- Make sure the client loads item data for everything our alts have equipped
      freshenItemData()
      -- Add Slash Commands
      SlashCmdList["LOOKSBETTER"] = slashCmdParser
      SLASH_LOOKSBETTER1 = "/lboy"

      self.ADDON_LOADED = nil
   end
end

function events:PLAYER_LOGIN()
	self:UnregisterEvent('PLAYER_LOGIN')
  	self:RegisterEvent('UNIT_INVENTORY_CHANGED')
   self.PLAYER_LOGIN = nil
   chatMsg(L["\"Looks Better On You!\" loaded."])
   chatMsg(L["  Type '/lboy AltName' to load AltName in the Dressing Room."])
   chatMsg(L["  Type '/lboy list' to print a list of available alts."])
   chatMsg(L["  If you have an alt named 'list' then that sucks for you."])
   self:UNIT_INVENTORY_CHANGED("player")    
end   


function events:UNIT_INVENTORY_CHANGED(unit)
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
-- After this section, registered events will be redirected to event:EVENT_NAME(...)
--
   eFrame = LooksBetterEventFrame or CreateFrame("Frame", "LooksBetterEventFrame", UIParent)
   do
   -- Think of this as an OnLoad function:
      eFrame:SetScript("OnEvent", function(self, event, ...)
            events[event](events, ...)
         end)
      eFrame:RegisterEvent("ADDON_LOADED")
   end
      
   local queue = {}
   local function OnUpdate(self, elapsed)
   -- Manage the timed event queue
      for index, tEvent in ipairs(queue) do
         local data = tEvent.data 
         if (tEvent.check and tEvent.check(elapsed, data)) then
            --Debug("We are now trying to execute the action for " .. tEvent.name)
            tEvent.action(elapsed, data)
            if (not tEvent.repeating) then
               queue[index] = nil
               if (#queue < 1) then
                  eFrame:Hide()
               end
            end
         end
      end
   end
   eFrame:SetScript("OnUpdate", OnUpdate)
 
   function events:RegisterEvent(...)
      eFrame:RegisterEvent(...)
   end
   
   function events:UnregisterEvent(...)
      eFrame:UnregisterEvent(...)
   end
   
   function events:SetTriggeredEvent(eName, check, action, data, repeating)
   -- Set a [repeating] timer that checks (by calling check()) if it should
   -- perform action().
      if (type(check) ~= "function" or type(action) ~= "function") then
         return
      else
         --Debug("We are setting up event : " .. eName)
         --if repeating then Debug("Event " .. eName .. " is repeating") end
         local tEvent = {
            name = eName,
            check = check,
            action = action,
            data = data,
            repeating = repeating,
         }
         tinsert(queue, tEvent)
         eFrame:Show()
         return #queue
      end                     
   end

   function events:CancelTriggeredEvent(index)
      if (type(index) == "string") then
         for i, tEvent in ipairs(queue) do
            if (tEvent.name == index) then
               index = i
               break
            end
         end
      end
      if (queue and index and queue[index]) then
         --Debug("Canceling timed event : " .. queue[index].name)
         queue[index] = nil
         if (#queue < 1) then
            eFrame:Hide()
         end
      end
   end
end

-- **Public methods


function lb:loadAltDressup(name)
-- Would be a good idea to have a file scope var to see if items have been
-- initialized.  If not, call init function and set a timer to re-run this
-- function. 
   local realm, name = strsplit(".", name)
   if not name then
      name = realm
      realm = GetRealmName()
   end
   local alt = lbDB and lbDB[realm] and lbDB[realm][name] or nil
   if alt and alt.race and alt.sex then
      if ( not DressUpFrame:IsShown() ) then
			ShowUIPanel(DressUpFrame)
			DressUpModel:SetUnit("player")
		end
      DressUpModel:SetCustomRace(raceID[string.upper(alt.race)], alt.sex - 2)
      DressUpModel:Undress() -- Must be after SetCustomRace
      for _, item in pairs(alt.equip) do
         if IsEquippableItem(item) and not ((select(9, GetItemInfo(item))) == "INVTYPE_BAG") then
            debug((select(1,GetItemInfo(item))))
            DressUpModel:TryOn("item:"..item)
         end
      end
   end
end
