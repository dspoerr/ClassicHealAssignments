local ClassicHealAssignments = LibStub("AceAddon-3.0"):NewAddon("ClassicHealAssignments", "AceConsole-3.0", "AceEvent-3.0");
local AceGUI = LibStub("AceGUI-3.0")
local healLDB = LibStub("LibDataBroker-1.1"):NewDataObject("HealAssignments", {
   type = "launcher",
   text = "HealAssignments",
   icon = "135907",
   OnTooltipShow = function(tooltip)
      tooltip:AddLine("ClassicHealAssignments")
      tooltip:AddLine(format("|cFFC41F3B%s:|r %s", "Click", "Open Assignment Panel"))
   end,
   OnClick = function()
      ClassicHealAssignments:ShowFrame()
   end,
})
local icon = LibStub("LibDBIcon-1.0")


local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS

local playerFrames = {}

local assignmentList = {}

local assignmentGroups = {}


-- Arrays for Healers under Assignments and Assignments under Healers respectively
assignedHealers = {}
reverseAssignments = {}


local classes = {}
local roles = {}

local healerColors = {["Druid"] = {1.00, 0.49, 0.04}, ["Mage"] = {0.25, 0.78, 0.92}, ["Priest"] = {1.00, 1.00, 1.00}, ["Paladin"] = {0.96, 0.55, 0.73}, ["Shaman"] = {0.96, 0.55, 0.73}}

local defaultChannels = {"SAY", "PARTY", "WHISPER", "GUILD", "OFFICER", "YELL", "RAID", "RAID_WARNING"}
local activeChannels = {}
local channelDropdown = nil
local selectedChannels = {["RAID"] = "default"}

function ClassicHealAssignments:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("ClassicHealAssignmentsDB", {
      profile = {
         minimap = {
            hide = false
         },
      },
   })
   icon:Register("HealAssignments", healLDB, self.db.profile.minimap)
   ClassicHealAssignments:RegisterChatCommand("heal", "ShowFrame")
end


function ClassicHealAssignments:OnEnable()
   UpdateChannels()
   SetupFrame()
   SetupFrameContainers()
   UpdateFrame()
   RegisterEvents()

   debug = false

   if not debug then
      mainWindow:Hide()
   end
end

function ClassicHealAssignments:OnDisable()
end


function RegisterEvents()
   -- Listen for changes in raid roster
   ClassicHealAssignments:RegisterEvent("CHANNEL_UI_UPDATE", "HandleChannelUpdate")
   ClassicHealAssignments:RegisterEvent("GROUP_ROSTER_UPDATE", "HandleRosterChange")
   ClassicHealAssignments:RegisterEvent("CHAT_MSG_WHISPER", "ReplyWithAssignment")
end


function ClassicHealAssignments:ShowFrame(input)
   DebugPrint("\n-----------\nHEAL")

   if mainWindow:IsVisible() then
      mainWindow:Hide()
   else
      CleanupFrame()
      SetupFrameContainers()
      UpdateFrame()
      mainWindow:Show()
   end
end


function UpdateFrame()
   DebugPrint("\n-----------\nUPDATE")

   local roles = {}
   local classes = {}
   local healerList = {}

   classes, roles = GetRaidRoster()

   roles["DISPELS"] = {"DISPELS"}
   roles["RAID"] = {"RAID"}

   for class, players in pairs(classes) do
      if healerColors[class] ~= nil then
         for _, player in ipairs(players) do
            if playerFrames[player] == nil then
               local nameFrame = AceGUI:Create("DragLabel")
               nameFrame:SetRelativeWidth(1)
               local classColors = healerColors[class]
               nameFrame:SetColor(classColors[1], classColors[2], classColors[3])
               nameFrame:SetUserData("playerName", player)
               nameFrame:SetCallback("OnDragStart", function(widget) DragStart(widget) end )    
               nameFrame:SetCallback("OnDragStop", function(widget) DragStop(widget) end)
               playerFrames[player] = nameFrame
               playerFrames[player]:SetText(player)
               local nameContainer = AceGUI:Create("SimpleGroup")
               nameContainer:SetRelativeWidth(1)
               nameContainer:AddChild(nameFrame)

               -- add the player frame to the healer container only if they are unassigned
               if reverseAssignments[player] == nil then
                  healerGroup:AddChild(nameContainer)
               end
            end

            tinsert(healerList, player)

            DebugPrint(player)
         end
      end
   end

   for role, players in pairs(roles) do
      if role == "MAINTANK" then
         for _, player in ipairs(players) do
            if assignmentGroups[player] == nil then
               CreateAssignmentGroup(player)
            end
            DebugPrint(player)
         end
      elseif role == "RAID" then
         if assignmentGroups[role] == nil then
            CreateAssignmentGroup("RAID")
         end
      elseif role == "DISPELS" then
         if assignmentGroups[role] == nil then
            CreateAssignmentGroup("DISPELS")
         end
      end
   end

   AssignmentPresetsUpdatePresets()
   UpdateAssignments()

   -- calling thrice to avoid inconsistencies between re-renders
   mainWindow:DoLayout()
   mainWindow:DoLayout()
   mainWindow:DoLayout()
end


function CreateHealerDropdown(healers, assignment)
   local dropdown = AceGUI:Create("Dropdown")
   dropdown:SetList(healers)
   dropdown:SetText("Assign healer")
   dropdown:SetFullWidth(true)
   dropdown:SetMultiselect(true)
   if assignedHealers[assignment] ~= nil then
      for _,v in ipairs(assignedHealers[assignment]) do
         dropdown:SetItemValue(table.indexOf(healers, v), true)
      end
   end
   return dropdown
end


function AnnounceHealers()
   DebugPrint("\n-----------\nASSIGNMENTS")

   AnnounceAssignments("Healing Assignments")
   for target, healers in pairs(assignedHealers) do
      if healers ~= nil then
         local assignment = target ..': ' .. table.concat(healers, ", ")

         DebugPrint(assignment)

         AnnounceAssignments(assignment)
      end
   end

   if selectedChannels["WHISPER"] ~= nil then
     AnnounceWhispers()
   end
end


function CreateAssignmentGroup(assignment)
   local nameFrame = AceGUI:Create("InlineGroup")
   nameFrame:SetTitle(assignment)
   nameFrame:SetWidth(140)
   assignmentGroups[assignment] = nameFrame
   assignmentWindow:AddChild(nameFrame)
   assignmentList[assignment] = nameFrame
end


function ClassicHealAssignments:HandleRosterChange()
   if IsInRaid() then
      CleanupFrame()
      SetupFrameContainers()
      UpdateFrame()
   end
end


function SelectChannel(widget, event, key, checked)
   local channels = GetAllChannelNames()
   local s = channels[key]
   if checked then
      if key <= #defaultChannels then
         selectedChannels[s] = "default"
      else
         selectedChannels[s] = activeChannels[s]
      end
   else
      selectedChannels[s] = nil
   end

   DebugFunction(
      function(ch, id)
         print("Selected channels:")
         for ch, id in pairs(selectedChannels) do
            print("ch=" .. ch .. " id=" .. id)
         end
      end
   )
end


function CreateChannelDropdown()
   local dropdown = AceGUI:Create("Dropdown")
   local channels = GetAllChannelNames()
   dropdown:SetList(channels)
   dropdown:SetLabel("Announcement channels")
   dropdown:SetText("Select channels")
   dropdown:SetWidth(200)
   dropdown:SetMultiselect(true)
   dropdown:SetUserData("name", "dropdown")
   dropdown:SetCallback("OnValueChanged", function(widget, event, key, checked) SelectChannel(widget, event, key, checked) end)

   -- looks through channel list to pull the index value & checks the channel in the list
   local channels = GetAllChannelNames()
   for channelName, selected in pairs(selectedChannels) do
      if activeChannels ~= nil then
         dropdown:SetItemValue(table.indexOf(channels, channelName), true)
      end
   end

   return dropdown
end


-- Sends MSG to preselected channels
function AnnounceAssignments(msg)
   for ch, id in pairs(selectedChannels) do
      if id == "default" and ch ~= "WHISPER" then
         SendChatMessage(msg, ch, nil)
      else
         SendChatMessage(msg, "CHANNEL", nil, id)
      end
   end
end


-- Sends assignments to all assigned players in a whisper
function AnnounceWhispers()
    for healer, a in pairs(reverseAssignments) do
      local msg = "Your healing assignments: "..table.concat(a, ", ")
      SendChatMessage(msg, "WHISPER", nil, healer)
    end
end


function UpdateChannels()
   activeChannels = {}
   local channels = {GetChannelList()} --returns triads of values: id,name,disabled
   local blizzChannels = {EnumerateServerChannels()}
   for i = 1, table.getn(channels), 3 do
      local id, name = GetChannelName(channels[i])
      if name ~= nil then
         local prunedName = string.match(name, "(%w+)") --filter out blizzard channels
         if not tContains(blizzChannels, prunedName) then
            activeChannels[name] = id
         end
      else --only cleans selectedChannels if the channel name was removed from the list
        if selectedChannels[name] ~= nil then
            selectedChannels[name] = nil
        end
      end
   end
end


function GetAllChannelNames()
   local names = {}
   table.merge(names, defaultChannels)
   table.merge(names, table.getKeys(activeChannels))
   return names
end


function ClassicHealAssignments:HandleChannelUpdate()
   UpdateChannels()

   DebugFunction(
      function()
         print("Selected announcement channels: " .. table.concat(table.getKeys(selectedChannels), ","))
      end
   )

   if channelDropdown ~= nil then
      local channels = GetAllChannelNames()
      channelDropdown:SetList(channels)
   end
   CleanupFrame()
   SetupFrameContainers()
   UpdateFrame()
end


function CleanupFrame()
   _, roles = GetRaidRoster()

   -- unassign healers from assignment targets that have been unchecked
   for assignment, assignmentFrame in pairs(assignmentGroups) do
      if assignment ~= "RAID" and assignment ~= "DISPELS" and (roles["MAINTANK"] == nil or not tContains(roles["MAINTANK"], assignment)) then
         assignedHealers[assignment] = nil
      end
   end

   assignmentGroups = {}
   playerFrames = {}
   AssignmentPresetsCleanup()
   mainWindow:ReleaseChildren()
end


function SetupFrame()
   uiRegisterCustomLayouts()

   mainWindow = AceGUI:Create("Frame")
   mainWindow:SetTitle("Classic Heal Assignments")
   mainWindow:SetStatusText("Classic Heal Assignments")
   mainWindow:SetLayout("mainWindowLayout")
   mainWindow:SetWidth("1000")
end


function SetupFrameContainers()

   healerGroup = AceGUI:Create("InlineGroup")
   healerGroup:SetTitle("Healers")
   healerGroup:SetWidth(90)
   healerGroup:SetUserData("name", "healerGroup")
   mainWindow:AddChild(healerGroup)

   assignmentWindow = AceGUI:Create("InlineGroup")
   assignmentWindow:SetTitle("Assignments")
   assignmentWindow:SetRelativeWidth(0.9)
   assignmentWindow:SetLayout("Flow")
   assignmentWindow:SetUserData("name", "assignmentWindow")
   mainWindow:AddChild(assignmentWindow)

   AssignmentPresetsSetupFrameContainers(mainWindow)

   announceMaster = AceGUI:Create("SimpleGroup")
   announceMaster:SetWidth(200)
   announceMaster:SetHeight(65)
   announceMaster:SetUserData("name", "announceMaster")
   announceMaster:SetLayout("AnnouncementsPane")
   mainWindow:AddChild(announceMaster)

   channelDropdown = CreateChannelDropdown()
   announceMaster:AddChild(channelDropdown)

   local announceButton = AceGUI:Create("Button")
   announceButton:SetText("Announce assignments")
   announceButton:SetCallback("OnClick", function() AnnounceHealers() end)
   announceButton:SetHeight(20)
   announceButton:SetWidth(200)
   announceButton:SetUserData("name", "announceButton")
   announceMaster:AddChild(announceButton)

end


function GetRaidRoster()
   local classes = {}
   local roles = {}

   for i=1, MAX_RAID_MEMBERS do
      local name, _, _, _, class, _, _, _, _, role, _, _ = GetRaidRosterInfo(i);
      if name then
         if not classes[class] then
            classes[class] = {}
         end
         if role ~= nil and not roles[role] then
            roles[role] = {}
         end

         DebugPrint(role)

         if not tContains(classes[class], name) then
            DebugPrint(name .. " was added")

            tinsert(classes[class], name)
            if role ~= nil then
               tinsert(roles[role], name)
            end
         end
      end
   end

   return classes, roles
end


-- listens for 'heal' and replies the target's current healing assignments if any
-- only replies if character is in raid
function ClassicHealAssignments:ReplyWithAssignment(event, msg, character)
   -- chopping off server tag that comes with character to parse it more easily
   local characterParse = string.gsub(character, "-(.*)", "")
   if msg == "heal" and UnitInRaid(characterParse) then
      SendChatMessage("You are assigned to: " .. table.concat(GetAssignmentsForPlayer(characterParse), ", "), "WHISPER", nil, character)
   end
end


function GetAssignmentsForPlayer(player)
   if reverseAssignments[player] ~= nil then
      return reverseAssignments[player]
   else
      return {}
   end
end


function DragStart(widget)
   widget.frame:ClearAllPoints()
   widget.frame:StartMoving()
end


function DragStop(widget)
   local uiScale = UIParent:GetEffectiveScale()
   local cursorX, cursorY = GetCursorPosition()
   local scaleCursorX = cursorX / uiScale
   local scaleCursorY = cursorY / uiScale

   local playerName = widget:GetUserData("playerName")

   -- check the unassigned group
   if scaleCursorX > healerGroup.frame:GetLeft() and scaleCursorX < healerGroup.frame:GetRight() then
      if scaleCursorY > healerGroup.frame:GetBottom() and scaleCursorY < healerGroup.frame:GetTop() then
         -- Cursor in the unassigned group. Just need to reset assignments
         ClearAssignments(playerName)
      end
   else
      for assignment, frame in pairs(assignmentList) do
        -- check if the cursor drop is within the frame area
        if scaleCursorX >= frame.frame:GetLeft() and scaleCursorX <= frame.frame:GetRight() then
          if scaleCursorY >= frame.frame:GetBottom() and scaleCursorY <= frame.frame:GetTop() then
            -- correct frame found, clearing all assignments for correct reassignment
            ClearAssignments(playerName)
            AssignHealer(assignment, playerName)
          end
         end
      end
   end
     -- refresh frame
      CleanupFrame()
      SetupFrameContainers()
      UpdateFrame()
end


function UpdateAssignments()
   if assignmentList ~= nil then
      for assignment, frame in pairs(assignmentList) do
         if assignedHealers[assignment] ~= nil then
            for _, healer in ipairs(assignedHealers[assignment]) do
            -- uses nameContainer or else the healer frames will stick to each other
               local nameContainer = AceGUI:Create("SimpleGroup") 
               nameContainer:SetRelativeWidth(1)
               nameContainer:AddChild(playerFrames[healer])
               frame:AddChild(nameContainer)
            end
         end
      end
   end
end


-- Clears all assignments for the selected player
-- Alters both assignedHealers array and reverseAssignments array
function ClearAssignments(playerName)
   -- if there aren't any assignments for the player, do nothing
   if reverseAssignments[playerName] ~= nil then
      for _, assignment in pairs (reverseAssignments[playerName]) do
         -- if the assignment itself is empty, no reason to do anything
         if assignedHealers[assignment] ~= nil then
            local healerIndex = table.indexOf(assignedHealers[assignment], playerName)
            tremove(assignedHealers[assignment], healerIndex)
            local assignmentIndex = table.indexOf(reverseAssignments[playerName], assignment)
            tremove(reverseAssignments[playerName], assignmentIndex)
            
            -- if the tables are empty, clear them so they can be initialized on refresh
            if table.isEmpty(reverseAssignments[playerName]) then
               reverseAssignments[playerName] = nil
            end

            if table.isEmpty(assignedHealers[assignment]) then
               assignedHealers[assignment] = nil
            end
         end
      end
   end
end

function AssignHealer(assignment, playerName)
-- set assignments, initialize if the tables are empty
   if(assignedHealers[assignment] ~= nil) then
      tinsert(assignedHealers[assignment], playerName)
   else
      assignedHealers[assignment] = {playerName}
   end
   
   -- separate if statement to check if the individual player's assignments are empty
   if(reverseAssignments[player] ~= nil) then
      tinsert(reverseAssignments[playerName], assignment)
   else
      reverseAssignments[playerName] = {assignment}				
   end
end