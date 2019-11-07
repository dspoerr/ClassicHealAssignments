local ClassicHealAssignments = LibStub("AceAddon-3.0"):NewAddon("ClassicHealAssignments", "AceConsole-3.0", "AceEvent-3.0");
local AceGUI = LibStub("AceGUI-3.0")
local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS

local playerFrames = {}

local assignmentGroups = {}

local assignedHealers = {}

--variables to store presets
local presetList = {}
local presetFrames = {}
local presetStore
local presetEditBoxText = "Store your preset name here"

local classes = {}
local roles = {}

local healerColors = {["Druid"] = {1.00, 0.49, 0.04}, ["Priest"] = {1.00, 1.00, 1.00}, ["Paladin"] = {0.96, 0.55, 0.73}, ["Shaman"] = {0.96, 0.55, 0.73}}


function ClassicHealAssignments:OnInitialize()
      ClassicHealAssignments:RegisterChatCommand("heal", "ShowFrame")
end


function ClassicHealAssignments:OnEnable()
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
   ClassicHealAssignments:RegisterEvent("GROUP_ROSTER_UPDATE", "HandleRosterChange")
end


function ClassicHealAssignments:ShowFrame(input)
   if debug then
      print("\n-----------\nHEAL")
   end
   if mainWindow:IsVisible() then
      mainWindow:Hide()
   else
      UpdateFrame()
      mainWindow:Show()
   end
end


function UpdateFrame()
   if debug then
      print("\n-----------\nUPDATE")
   end
   local roles = {}
   local classes = {}
   local dispellerList = {}
   local healerList = {}

   local presetName --used to iterate through preset list

   classes, roles = GetRaidRoster()

   roles["DISPELS"] = {"DISPELS"}
   roles["RAID"] = {"RAID"}


   for class, players in pairs(classes) do
      if healerColors[class] ~= nil then
         for _, player in ipairs(players) do
            if playerFrames[player] == nil then
               local nameframe = AceGUI:Create("InteractiveLabel")
               nameframe:SetRelativeWidth(1)
               nameframe:SetText(player)
               local classColors = healerColors[class]
               nameframe:SetColor(classColors[1], classColors[2], classColors[3])
               playerFrames[player] = nameframe
               healerGroup:AddChild(nameframe)
            end
            tinsert(healerList, player)
            tinsert(dispellerList, player)
            if debug then
               print(player)
            end
         end
      elseif class == "Mage" then
         for _, player in ipairs(players) do
            tinsert(dispellerList, player)
         end
      end
   end

   for role, players in pairs(roles) do
      if role == "MAINTANK" then
         for _, player in ipairs(players) do
            if assignmentGroups[player] == nil then
               CreateAssignmentGroup(player, healerList)
            end
            if debug then
               print(player)
            end
         end
      elseif role == "RAID" then
         if assignmentGroups[role] == nil then
            CreateAssignmentGroup("RAID", healerList)
         end
      elseif role == "DISPELS" then
         if assignmentGroups[role] == nil then
            CreateAssignmentGroup("DISPELS", dispellerList)
         end
      end
   end

   --add preset names to container
   print("preset list: " .. table.concat(presetList, ","))
   if presetList ~= nil then
		for presetName, assignments in pairs(presetList) do 
			if presetFrames[presetName] == nil then
				print("creating frame for preset...")
               local nameframe = AceGUI:Create("InteractiveLabel")
               nameframe:SetRelativeWidth(1)
               nameframe:SetText(presetName)
			   nameframe:SetColor(168, 159, 255)
			   nameframe:SetHighlight(0.33, 10, 145, 100)
			   nameframe:SetCallback("OnClick", function() LoadState(presetName, nameframe) end)
               presetFrames[presetName] = nameframe
			   presetGroup:AddChild(nameframe)
			end
		end
	end

   -- calling twice to avoid inconsistencies between re-renders
   mainWindow:DoLayout()
   mainWindow:DoLayout()
end


function AssignHealer(widget, event, key, checked, healerList)
   local target = widget:GetUserData("target")
   if not assignedHealers[target] then
      assignedHealers[target] = {}
      if debug then 
         print("creating assigned healers dict")
      end
   end
   if checked then
      if debug then
         print("assigning " .. healerList[key] .. " to " .. target)
      end
      tinsert(assignedHealers[target], healerList[key])
   else
      local healerIndex = table.indexOf(assignedHealers[target], healerList[key])
      tremove(assignedHealers[target], healerIndex)
   end
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

--dummy function which will later implement a save state feature
function SaveState(savename)
	if debug then
		print("\n-----------\nSAVESTATE")
	end

	--CATCH IF SAVENAME IS NULL

	print("saving preset list..." .. savename)

	presetList[savename] = {}
	local copyTargets = {}
	for target, healers in pairs(assignedHealers) do
		local copyHealers = {}
		for i, players in ipairs(healers) do 
			copyHealers[i] = players 
		end
		copyTargets[target] = copyHealers
	end

	presetList[savename] = copyTargets

	for presetName, assignments in pairs(presetList) do
		print("present name: " .. presetName)
		if assignments[DISPELS] ~= nil then
			print("First assignment: " .. table.concat(assignments[DISPELS], ","))
		end
	end

	CleanupFrame()
	SetupFrameContainers()
	UpdateFrame()
end

--dummy function which will later implement the load state feature. activated by clicking frames
function LoadState(loadname, loadframe)
	if debug then
		print("\n-----------\nLOADSTATE")
	end

	presetEditBoxText = loadname
	assignedHealers = {}
	local copyTargets = {}
	for target, healers in pairs(presetList[loadname]) do
		local copyHealers = {}
		for i, players in ipairs(healers) do 
			copyHealers[i] = players 
		end
		copyTargets[target] = copyHealers
	end

	assignedHealers = copyTargets

	for i, x in pairs(assignedHealers) do
		print("Current assignments after loading: " .. i .. table.concat(x, ","))
	end
	CleanupFrame()
	SetupFrameContainers()
	UpdateFrame()
end

--will eventually need an option to delete presets
function DeleteState(savename)
	if debug then
		print("\n-----------\nDELETESTATE")
	end
	presetList[savename] = {}
	CleanupFrame()
	UpdateFrame()
end

function AnnounceHealers()
   if debug then
      print("\n-----------\nASSIGNMENTS")
   end
   SendChatMessage("Healing assignments", "RAID", nil)
   for target, healers in pairs(assignedHealers) do
      if healers ~= nil then
         local assignment = target ..': ' .. table.concat(healers, ", ")
         if debug then
            print(assignment)
         end
         SendChatMessage(assignment, "RAID", nil)
      end
   end
end


function CreateAssignmentGroup(assignment, playerList)
   local nameframe = AceGUI:Create("InlineGroup")
   nameframe:SetTitle(assignment)
   nameframe:SetWidth(140)
   assignmentGroups[assignment] = nameframe
   assignmentWindow:AddChild(nameframe)
   local dropdown = CreateHealerDropdown(playerList, assignment)
   dropdown:SetUserData("target", assignment)
   dropdown:SetCallback("OnValueChanged", function(widget, event, key, checked) AssignHealer(widget, event, key, checked, playerList) end)
   nameframe:AddChild(dropdown)
end


function ClassicHealAssignments:HandleRosterChange()
   if IsInRaid() then
      CleanupFrame()
      SetupFrameContainers()
      UpdateFrame()
   end
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
   presetFrames = {}
   mainWindow:ReleaseChildren()
end


function SetupFrame()
   mainWindow = AceGUI:Create("Frame")
   mainWindow:SetTitle("Classic Heal Assignments")
   mainWindow:SetStatusText("Classic Heal Assignments")
   mainWindow:SetLayout("Flow")
   mainWindow:SetWidth("1000")
end


function SetupFrameContainers()
   healerGroup = AceGUI:Create("InlineGroup")
   healerGroup:SetTitle("Healers")
   healerGroup:SetWidth(80)
   mainWindow:AddChild(healerGroup)

   assignmentWindow = AceGUI:Create("InlineGroup")
   assignmentWindow:SetTitle("Assignments")
   assignmentWindow:SetRelativeWidth(0.9)
   assignmentWindow:SetLayout("Flow")
   mainWindow:AddChild(assignmentWindow)

   --creates a basic window to test presets
   presetGroup = AceGUI:Create("InlineGroup")
   presetGroup:SetTitle("Presets")
   presetGroup:SetWidth(80)
   mainWindow:AddChild(presetGroup)

   local announceButton = AceGUI:Create("Button")
   announceButton:SetText("Announce assignments")
   announceButton:SetCallback("OnClick", function() AnnounceHealers() end)
   mainWindow:AddChild(announceButton)

   --button to save the state of all of the locations of the healers at the time
   local savestateButton = AceGUI:Create("Button");
   savestateButton:SetText("Save");
   savestateButton:SetCallback("OnClick", function () SaveState(presetStore) end)
   mainWindow:AddChild(savestateButton)

   --creates the name for the save state
    savestateNameBox = AceGUI:Create("EditBox");
	savestateNameBox:SetWidth(200)
	savestateNameBox:SetLabel("Preset Name")
	savestateNameBox:SetText(presetEditBoxText)
	savestateNameBox:SetCallback("OnEnterPressed", function(widget, event, text) presetStore = text end)
	mainWindow:AddChild(savestateNameBox)

	--deletes the currently selected preset
	local deletestateButton = AceGUI:Create("Button")
	deletestateButton:SetText("Delete Preset")
	deletestateButton:SetCallback("OnClick", function() DeleteState(presetStore) end)
	--mainWindow:AddChild(deletestateButton)
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

         if debug then 
            print(role)
         end

         if not tContains(classes[class], name) then
            if debug then
               print(name .. " was added")
            end
            tinsert(classes[class], name)
            if role ~= nil then
               tinsert(roles[role], name)
            end
         end
      end
   end

   return classes, roles
end