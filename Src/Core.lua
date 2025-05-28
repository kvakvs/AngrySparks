local AngrySparks = LibStub("AceAddon-3.0"):NewAddon(
	"AngrySparks",
	"AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0"
)
local AceGUI = LibStub("AceGUI-3.0")
local lwin = LibStub("LibWindow-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local libC = LibStub("LibCompress")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

BINDING_HEADER_AngrySparks = "Angry Sparks"
BINDING_NAME_AngrySparks_WINDOW = "Toggle Window"
BINDING_NAME_AngrySparks_LOCK = "Toggle Lock"
BINDING_NAME_AngrySparks_DISPLAY = "Toggle Display"
BINDING_NAME_AngrySparks_SHOW_DISPLAY = "Show Display"
BINDING_NAME_AngrySparks_HIDE_DISPLAY = "Hide Display"
BINDING_NAME_AngrySparks_OUTPUT = "Output Assignment to Chat"

local CURSEFORGE_URL = "https://legacy.curseforge.com/wow/addons/angry-sparks"

local AngrySparks_Version = '@project-version@'
local AngrySparks_Timestamp = '@project-date-integer@'

local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

local protocolVersion = 3
local comPrefix = "AngryGirls" .. protocolVersion
local updateThrottle = 4
local pageLastUpdate = {}
local pageTimerId = {}
local displayLastUpdate = nil
local displayTimerId = nil
local versionLastUpdate = nil
local versionTimerId = nil

-- Used for version tracking
local warnedOOD = false
local versionList = {}

local comStarted = false

local warnedPermission = false

local currentGroup = nil

-- Pages Saved Variable Format
-- 	AngrySparks_Pages = {
-- 		[Id] = { Id = 1231, Updated = time(), UpdateId = self:Hash(name, contents), Name = "Name", Contents = "...", Backup = "...", CategoryId = 123 },
--		...
-- 	}
-- 	AngrySparks_Categories = {
-- 		[Id] = { Id = 1231, Name = "Name", CategoryId = 123 },
--		...
-- 	}
-- 	AngrySparks_Variables = {
-- 		[1] = { "variable", "replacement" },
--		...
-- 	}
--
-- Format for our addon communication
--
-- { "PAGE", [Id], [Last Update Timestamp], [Name], [Contents], [Last Update Unique Id], [Variables] }
-- Sent when a page is updated. Id is a random unique value. Unique Id is hash of page contents. Uses RAID.
--
-- { "REQUEST_PAGE", [Id] }
-- Asks to be sent PAGE with given Id. Response is a throttled PAGE. Uses WHISPER to raid leader.
--
-- { "DISPLAY", [Id], [Last Update Timestamp], [Last Update Unique Id] }
-- Raid leader / promoted sends out when new page is to be displayed. Uses RAID.
--
-- { "REQUEST_DISPLAY" }
-- Asks to be sent DISPLAY. Response is a throttled DISPLAY. Uses WHISPER to raid leader.
--
-- { "VER_QUERY" }
-- { "VERSION", [Version], [Project Timestamp], [Valid Raid] }

-- Constants for dealing with our addon communication
local COMMAND = 1

local PAGE_Id = 2
local PAGE_Updated = 3
local PAGE_Name = 4
local PAGE_Contents = 5
local PAGE_UpdateId = 6
local PAGE_Variables = 7

local REQUEST_PAGE_Id = 2

local DISPLAY_Id = 2
local DISPLAY_Updated = 3
local DISPLAY_UpdateId = 4

local VERSION_Version = 2
local VERSION_Timestamp = 3
local VERSION_ValidRaid = 4

-----------------------
-- Utility Functions --
-----------------------
--@debug@
function DBG_dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k, v in pairs(o) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end
			s = s .. '[' .. k .. '] = ' .. DBG_dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

--@end-debug@

--@alpha@
local dbgMessageShown = false
local function dbg(msg, data)
	if ViragDevTool_AddData then
		ViragDevTool_AddData(data, msg)
	else
		if not dbgMessageShown then
			print(
				"Please install ViragDevTool from http://mods.curse.com/addons/wow/varrendevtool to view debug info for Angry Sparks.")
			dbgMessageShown = true
		end
	end
end
--@end-alpha@

local function explode(seperator, content)
	local t, position
	t = {}
	position = 0
	if (#content == 1) then
		return { content }
	end
	while true do
		local idx = string.find(content, seperator, position, true) -- find the next seperator in the string
		if idx ~= nil then                                    -- if "not not" found then..
			table.insert(t, string.sub(content, position, idx - 1)) -- Save it in our array.
			position = idx +
				#seperator                                    -- save just after where we found it for searching next time.
		else
			table.insert(t, string.sub(content, position))    -- Save what's left in our array.
			break                                             -- Break at end, as it should be, according to the lua manual.
		end
	end
	return t
end

local function selectedLastValue(input)
	local a = select(-1, strsplit("", input or ""))
	return tonumber(a)
end

local function tReverse(tbl)
	for i = 1, math.floor(#tbl / 2) do
		tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
	end
end

local _player_realm = nil
local function EnsureUnitFullName(unit)
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	if unit and not unit:find('-') then
		unit = unit .. '-' .. _player_realm
	end
	return unit
end

local function EnsureUnitShortName(unit)
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	local name, realm = strsplit("-", unit, 2)
	if not realm or realm == _player_realm then
		return name
	else
		return unit
	end
end

local function PlayerFullName()
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	return UnitName('player') .. '-' .. _player_realm
end

local function RGBToHex(r, g, b, a)
	r = math.ceil(255 * r)
	g = math.ceil(255 * g)
	b = math.ceil(255 * b)
	if a == nil then
		return string.format("%02x%02x%02x", r, g, b)
	else
		a = math.ceil(255 * a)
		return string.format("%02x%02x%02x%02x", r, g, b, a)
	end
end

local function HexToRGB(hex)
	if string.len(hex) == 8 then
		return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
			tonumber("0x" .. hex:sub(5, 6)) / 255, tonumber("0x" .. hex:sub(7, 8)) / 255
	else
		return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
			tonumber("0x" .. hex:sub(5, 6)) / 255
	end
end

-------------------------
-- Addon Communication --
-------------------------

function AngrySparks:ReceiveMessage(prefix, data, channel, sender)
	if prefix ~= comPrefix then return end

	local decoded = LibDeflate:DecodeForWoWAddonChannel(data)
	if not decoded then return end
	local decompressed = LibDeflate:DecompressDeflate(decoded)
	if not decompressed then return end
	local success, final = LibSerialize:Deserialize(decompressed)
	if not success then return end

	self:ProcessMessage(sender, final)
end

function AngrySparks:SendOutMessage(data, channel, target)
	local serialized = LibSerialize:Serialize(data)
	local compressed = LibDeflate:CompressDeflate(serialized)
	local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

	if not channel then
		if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
			channel = "INSTANCE_CHAT"
		elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
			channel = "RAID"
		elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
			channel = "PARTY"
		end
	end

	if not channel then return end

	--@alpha@
	dbg("AG Send Message " .. data[COMMAND], { target, channel, data, string.len(encoded) })
	--@end-alpha@
	self:SendCommMessage(comPrefix, encoded, channel, target, "BULK")
	return true
end

function AngrySparks:ProcessMessage(sender, data)
	local cmd = data[COMMAND]
	sender = EnsureUnitFullName(sender)

	--@alpha@
	dbg("AG Process " .. cmd, { sender, data })
	--@end-alpha@

	if cmd == "PAGE" then
		if sender == PlayerFullName() then return end
		if not self:PermissionCheck(sender) then
			self:PermissionCheckFailError(sender)
			return
		end

		local contents_updated = true
		local id = data[PAGE_Id]
		local page = AngrySparks_Pages[id]
		if page then
			if data[PAGE_UpdateId] and page.UpdateId == data[PAGE_UpdateId] then return end -- The version received is same as the one we already have

			contents_updated = page.Contents ~= data[PAGE_Contents]

			AngrySparks_Variables = data[PAGE_Variables]

			page.Name = data[PAGE_Name]
			page.Contents = data[PAGE_Contents]
			page.Updated = data[PAGE_Updated]
			page.UpdateId = data[PAGE_UpdateId] or self:Hash(page.Name, page.Contents, AngrySparks:VariablesToString())

			if self:SelectedId() == id then
				self:SelectedUpdated(sender)
				self:UpdateSelected()
			end
		else
			AngrySparks_Pages[id] = {
				Id = id,
				Updated = data[PAGE_Updated],
				UpdateId = data[PAGE_UpdateId],
				Name = data
					[PAGE_Name],
				Contents = data[PAGE_Contents]
			}
			AngrySparks_Variables = data[PAGE_Variables]
		end

		if AngrySparks_State.displayed == id then
			self:UpdateDisplayed()
			self:ShowDisplay()
			if contents_updated then self:DisplayUpdateNotification() end
		end

		self:UpdateTree()
	elseif cmd == "DISPLAY" then
		if sender == PlayerFullName() then return end
		if not self:PermissionCheck(sender) then
			if data[DISPLAY_Id] then self:PermissionCheckFailError(sender) end
			return
		end

		local id = data[DISPLAY_Id]
		local updated = data[DISPLAY_Updated]
		local updateId = data[DISPLAY_UpdateId]
		local page = AngrySparks_Pages[id]
		local sameVersion = (updateId and page and updateId == page.UpdateId) or
			(not updateId and page and updated == page.Updated)
		if id and not sameVersion then
			self:SendRequestPage(id, sender)
		end

		if AngrySparks_State.displayed ~= id then
			AngrySparks_State.displayed = id
			self:UpdateTree()
			self:UpdateDisplayed()
			self:ShowDisplay()
			if id then self:DisplayUpdateNotification() end
		end
	elseif cmd == "REQUEST_DISPLAY" then
		if sender == PlayerFullName() then return end
		if not self:IsPlayerRaidLeader() then return end

		self:SendDisplay(AngrySparks_State.displayed)
	elseif cmd == "REQUEST_PAGE" then
		if sender == PlayerFullName() then return end

		self:SendPage(data[REQUEST_PAGE_Id])
	elseif cmd == "VER_QUERY" then
		self:SendVersion()
	elseif cmd == "VERSION" then
		local localTimestamp, ver, timestamp

		if AngrySparks_Timestamp:sub(1, 1) == "@" then
			localTimestamp = "dev"
		else
			localTimestamp = tonumber(
				AngrySparks_Timestamp)
		end
		ver = data[VERSION_Version]
		timestamp = data[VERSION_Timestamp]

		local localStr = tostring(localTimestamp)
		local remoteStr = tostring(timestamp)

		if (localStr ~= "dev" and localStr:len() ~= 14) or (remoteStr ~= "dev" and remoteStr:len() ~= 14) then
			if localStr ~= "dev" then localTimestamp = tonumber(localStr:sub(1, 8)) end
			if remoteStr ~= "dev" then timestamp = tonumber(remoteStr:sub(1, 8)) end
		end

		if localTimestamp ~= "dev" and timestamp ~= "dev" and timestamp > localTimestamp and not warnedOOD then
			self:Print(
				"Your version of Angry Sparks is out of date! Download the latest version from " .. CURSEFORGE_URL)
			warnedOOD = true
		end

		versionList[sender] = { valid = data[VERSION_ValidRaid], version = ver }
	end
end

function AngrySparks:PermissionCheckFailError(sender)
	if not warnedPermission then
		self:Print(RED_FONT_COLOR_CODE ..
			"You have received a page update from " ..
			Ambiguate(sender, "none") ..
			" that was rejected due to insufficient permissions. If you wish to see this page, please adjust your permission settings.|r")
		warnedPermission = true
	end
end

function AngrySparks:SendPage(id, force)
	local lastUpdate = pageLastUpdate[id]
	local timerId = pageTimerId[id]
	local curTime = time()

	if lastUpdate and (curTime - lastUpdate <= updateThrottle) then
		if not timerId then
			if force then
				self:SendPageMessage(id)
			else
				pageTimerId[id] = self:ScheduleTimer("SendPageMessage", updateThrottle - (curTime - lastUpdate), id)
			end
		elseif force then
			self:CancelTimer(timerId)
			self:SendPageMessage(id)
		end
	else
		self:SendPageMessage(id)
	end
end

function AngrySparks:SendPageMessage(id)
	pageLastUpdate[id] = time()
	pageTimerId[id] = nil

	local page = AngrySparks_Pages[id]
	if not page then
		error("Can't send page, does not exist"); return
	end

	if not page.UpdateId then
		page.UpdateId = self:Hash(page.Name, page.Contents, AngrySparks:VariablesToString())
	end

	self:SendOutMessage({
		"PAGE",
		[PAGE_Id] = page.Id,
		[PAGE_Updated] = page.Updated,
		[PAGE_Name] = page.Name,
		[PAGE_Contents] = page.Contents,
		[PAGE_UpdateId] = page.UpdateId,
		[PAGE_Variables] = AngrySparks_Variables
	})
end

function AngrySparks:SendDisplay(id, force)
	local curTime = time()

	if displayLastUpdate and (curTime - displayLastUpdate <= updateThrottle) then
		if not displayTimerId then
			if force then
				self:SendDisplayMessage(id)
			else
				displayTimerId = self:ScheduleTimer("SendDisplayMessage", updateThrottle - (curTime - displayLastUpdate),
					id)
			end
		elseif force then
			self:CancelTimer(displayTimerId)
			self:SendDisplayMessage(id)
		end
	else
		self:SendDisplayMessage(id)
	end
end

function AngrySparks:SendDisplayMessage(id)
	displayLastUpdate = time()
	displayTimerId = nil

	local page = AngrySparks_Pages[id]
	if not page then
		self:SendOutMessage({ "DISPLAY", [DISPLAY_Id] = nil, [DISPLAY_Updated] = nil, [DISPLAY_UpdateId] = nil })
	else
		if not page.UpdateId then
			self:RehashPage(id)
		end
		self:SendOutMessage({
			"DISPLAY",
			[DISPLAY_Id] = page.Id,
			[DISPLAY_Updated] = page.Updated,
			[DISPLAY_UpdateId] =
				page.UpdateId
		})
	end
end

function AngrySparks:SendRequestDisplay()
	if (IsInRaid() or IsInGroup()) then
		local to = self:GetRaidLeader(true)
		if to then self:SendOutMessage({ "REQUEST_DISPLAY" }, "WHISPER", to) end
	end
end

function AngrySparks:SendVersion(force)
	local curTime = time()

	if versionLastUpdate and (curTime - versionLastUpdate <= updateThrottle) then
		if not versionTimerId then
			if force then
				self:SendVersionMessage(id)
			else
				versionTimerId = self:ScheduleTimer("SendVersionMessage", updateThrottle - (curTime - versionLastUpdate),
					id)
			end
		elseif force then
			self:CancelTimer(versionTimerId)
			self:SendVersionMessage()
		end
	else
		self:SendVersionMessage()
	end
end

function AngrySparks:SendVersionMessage()
	versionLastUpdate = time()
	versionTimerId = nil

	local revToSend
	local timestampToSend
	local verToSend
	if AngrySparks_Version:sub(1, 1) == "@" then verToSend = "dev" else verToSend = AngrySparks_Version end
	if AngrySparks_Timestamp:sub(1, 1) == "@" then
		timestampToSend = "dev"
	else
		timestampToSend = tonumber(
			AngrySparks_Timestamp)
	end
	self:SendOutMessage({
		"VERSION",
		[VERSION_Version] = verToSend,
		[VERSION_Timestamp] = timestampToSend,
		[VERSION_ValidRaid] = self:IsValidRaid()
	})
end

function AngrySparks:SendVerQuery()
	self:SendOutMessage({ "VER_QUERY" })
end

function AngrySparks:SendRequestPage(id, to)
	if (IsInRaid() or IsInGroup()) or to then
		if not to then to = self:GetRaidLeader(true) end
		if to then self:SendOutMessage({ "REQUEST_PAGE", [REQUEST_PAGE_Id] = id }, "WHISPER", to) end
	end
end

function AngrySparks:GetRaidLeader(online_only)
	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
			if rank == 2 then
				if (not online_only) or online then
					return EnsureUnitFullName(name)
				else
					return nil
				end
			end
		end
	end
	return nil
end

function AngrySparks:GetCurrentGroup()
	local player = PlayerFullName()
	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, _, subgroup = GetRaidRosterInfo(i)
			if EnsureUnitFullName(name) == player then
				return subgroup
			end
		end
	end
	return nil
end

function AngrySparks:VersionCheckOutput()
	local missing_addon = {}
	local invalid_raid = {}
	local different_version = {}
	local up_to_date = {}

	local ver = AngrySparks_Version
	if ver:sub(1, 1) == "@" then ver = "dev" end

	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
			local fullname = EnsureUnitFullName(name)
			if online then
				if not versionList[fullname] then
					tinsert(missing_addon, name)
				elseif versionList[fullname].valid == false or versionList[fullname].valid == nil then
					tinsert(invalid_raid, name)
				elseif ver ~= versionList[fullname].version then
					tinsert(different_version, string.format("%s - %s", name, versionList[fullname].version))
				else
					tinsert(up_to_date, name)
				end
			end
		end
	end

	self:Print("Version check results:")
	if #up_to_date > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE .. "Same version:|r " .. table.concat(up_to_date, ", "))
	end

	if #different_version > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE .. "Different version:|r " .. table.concat(different_version, ", "))
	end

	if #invalid_raid > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE .. "Not allowing changes:|r " .. table.concat(invalid_raid, ", "))
	end

	if #missing_addon > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE .. "Missing addon:|r " .. table.concat(missing_addon, ", "))
	end
end

--------------------------
-- Editing Pages Window --
--------------------------

function AngrySparks_ToggleWindow()
	if not AngrySparks.window then AngrySparks:CreateWindow() end
	if AngrySparks.window:IsShown() then
		AngrySparks.window:Hide()
	else
		AngrySparks.window:Show()
	end
end

function AngrySparks_ToggleLock()
	AngrySparks:ToggleLock()
end

local function AngrySparks_AddPage(widget, event, value)
	local popup_name = "AngrySparks_AddPage"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				if text ~= "" then AngrySparks:CreatePage(text) end
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				if text ~= "" then AngrySparks:CreatePage(text) end
				self:GetParent():Hide()
			end,
			text = "New page name:",
			hasEditBox = true,
			whileDead = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopup_Show(popup_name)
end

local function AngrySparks_RenamePage(pageId)
	local page = AngrySparks:Get(pageId)
	if not page then return end

	local popup_name = "AngrySparks_RenamePage_" .. page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				AngrySparks:RenamePage(page.Id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				AngrySparks:RenamePage(page.Id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				self.editBox:SetText(page.Name)
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename page "' .. page.Name .. '" to:'

	StaticPopup_Show(popup_name)
end

local function AngrySparks_DeletePage(pageId)
	local page = AngrySparks:Get(pageId)
	if not page then return end

	local popup_name = "AngrySparks_DeletePage_" .. page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				AngrySparks:DeletePage(page.Id)
			end,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete page "' .. page.Name .. '"?'

	StaticPopup_Show(popup_name)
end

local function AngrySparks_AddCategory(widget, event, value)
	local popup_name = "AngrySparks_AddCategory"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				if text ~= "" then AngrySparks:CreateCategory(text) end
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				if text ~= "" then AngrySparks:CreateCategory(text) end
				self:GetParent():Hide()
			end,
			text = "New category name:",
			hasEditBox = true,
			whileDead = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopup_Show(popup_name)
end

local function AngrySparks_RenameCategory(catId)
	local cat = AngrySparks:GetCat(catId)
	if not cat then return end

	local popup_name = "AngrySparks_RenameCategory_" .. cat.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				AngrySparks:RenameCategory(cat.Id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				AngrySparks:RenameCategory(cat.Id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				self.editBox:SetText(cat.Name)
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename category "' .. cat.Name .. '" to:'

	StaticPopup_Show(popup_name)
end

local function AngrySparks_DeleteCategory(catId)
	local cat = AngrySparks:GetCat(catId)
	if not cat then return end

	local popup_name = "AngrySparks_DeleteCategory_" .. cat.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				AngrySparks:DeleteCategory(cat.Id)
			end,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete category "' .. cat.Name .. '"?'

	StaticPopup_Show(popup_name)
end

local function AngrySparks_AssignCategory(frame, entryId, catId)
	HideDropDownMenu(1)

	AngrySparks:AssignCategory(entryId, catId)
end

local function AngrySparks_RevertPage(widget, event, value)
	if not AngrySparks.window then return end
	AngrySparks:UpdateSelected(true)
end

function AngrySparks:DisplayPageByName(name)
	for id, page in pairs(AngrySparks_Pages) do
		if page.Name == name then
			return self:DisplayPage(id)
		end
	end
	return false
end

function AngrySparks:DisplayPage(id)
	if not self:PermissionCheck() then return end

	self:TouchPage(id)
	self:SendPage(id, true)
	self:SendDisplay(id, true)

	if AngrySparks_State.displayed ~= id then
		AngrySparks_State.displayed = id
		AngrySparks:UpdateDisplayed()
		AngrySparks:ShowDisplay()
		AngrySparks:UpdateTree()
		AngrySparks:DisplayUpdateNotification()
	end

	return true
end

local function AngrySparks_DisplayPage(widget, event, value)
	if not AngrySparks:PermissionCheck() then return end
	local id = AngrySparks:SelectedId()
	AngrySparks:DisplayPage(id)
end

local function AngrySparks_ClearPage(widget, event, value)
	if not AngrySparks:PermissionCheck() then return end

	AngrySparks:ClearDisplayed()
	AngrySparks:SendDisplay(nil, true)
end

local function AngrySparks_TextChanged(widget, event, value)
	AngrySparks.window.button_revert:SetDisabled(false)
	AngrySparks.window.button_restore:SetDisabled(false)
	AngrySparks.window.button_display:SetDisabled(true)
	AngrySparks.window.button_output:SetDisabled(true)
end

local function AngrySparks_TextEntered(widget, event, value)
	AngrySparks:UpdateContents(AngrySparks:SelectedId(), value)
end

local function AngrySparks_RestorePage(widget, event, value)
	if not AngrySparks.window then return end
	local page = AngrySparks_Pages[AngrySparks:SelectedId()]
	if not page or not page.Backup then return end

	AngrySparks.window.text:SetText(page.Backup)
	AngrySparks.window.text.button:Enable()
	AngrySparks_TextChanged(widget, event, value)
end

local function AngrySparks_CategoryMenuList(entryId, parentId)
	local categories = {}

	local checkedId
	if entryId > 0 then
		local page = AngrySparks_Pages[entryId]
		checkedId = page.CategoryId
	else
		local cat = AngrySparks_Categories[-entryId]
		checkedId = cat.CategoryId
	end

	for _, cat in pairs(AngrySparks_Categories) do
		if cat.Id ~= -entryId and (parentId or not cat.CategoryId) and (not parentId or cat.CategoryId == parentId) then
			local subMenu = AngrySparks_CategoryMenuList(entryId, cat.Id)
			table.insert(categories,
				{
					text = cat.Name,
					value = cat.Id,
					menuList = subMenu,
					hasArrow = (subMenu ~= nil),
					checked = (checkedId == cat.Id),
					func =
						AngrySparks_AssignCategory,
					arg1 = entryId,
					arg2 = cat.Id
				})
		end
	end

	table.sort(categories, function(a, b) return a.text < b.text end)

	if #categories > 0 then
		return categories
	end
end

local PagesDropDownList
function AngrySparks_PageMenu(pageId)
	local page = AngrySparks_Pages[pageId]
	if not page then return end

	if not PagesDropDownList then
		PagesDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Rename",     notCheckable = true, func = function(frame, pageId) AngrySparks_RenamePage(pageId) end },
			{ text = "Delete",     notCheckable = true, func = function(frame, pageId) AngrySparks_DeletePage(pageId) end },
			{ text = "Category",   notCheckable = true, hasArrow = true },
		}
	end

	local permission = AngrySparks:PermissionCheck()

	PagesDropDownList[1].text = page.Name
	PagesDropDownList[2].arg1 = pageId
	PagesDropDownList[2].disabled = not permission
	PagesDropDownList[3].arg1 = pageId
	PagesDropDownList[3].disabled = not permission

	local categories = AngrySparks_CategoryMenuList(pageId)
	if categories ~= nil then
		PagesDropDownList[4].menuList = categories
		PagesDropDownList[4].disabled = false
	else
		PagesDropDownList[4].menuList = {}
		PagesDropDownList[4].disabled = true
	end

	return PagesDropDownList
end

local CategoriesDropDownList
local function AngrySparks_CategoryMenu(catId)
	local cat = AngrySparks_Categories[catId]
	if not cat then return end

	if not CategoriesDropDownList then
		CategoriesDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Rename",     notCheckable = true, func = function(frame, pageId) AngrySparks_RenameCategory(pageId) end },
			{ text = "Delete",     notCheckable = true, func = function(frame, pageId) AngrySparks_DeleteCategory(pageId) end },
			{ text = "Category",   notCheckable = true, hasArrow = true },
		}
	end
	CategoriesDropDownList[1].text = cat.Name
	CategoriesDropDownList[2].arg1 = catId
	CategoriesDropDownList[3].arg1 = catId


	local categories = AngrySparks_CategoryMenuList(-catId)
	if categories ~= nil then
		CategoriesDropDownList[4].menuList = categories
		CategoriesDropDownList[4].disabled = false
	else
		CategoriesDropDownList[4].menuList = {}
		CategoriesDropDownList[4].disabled = true
	end

	return CategoriesDropDownList
end

local AngrySparks_DropDown
local function AngrySparks_TreeClick(widget, event, value, selected, button)
	HideDropDownMenu(1)
	local selectedId = selectedLastValue(value)
	if selectedId < 0 then
		if button == "RightButton" then
			if not AngrySparks_DropDown then
				AngrySparks_DropDown = CreateFrame("Frame", "AngrySparksMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			EasyMenu(AngrySparks_CategoryMenu(-selectedId), AngrySparks_DropDown, "cursor", 0, 0, "MENU")
		else
			local status = (widget.status or widget.localstatus).groups
			status[value] = not status[value]
			widget:RefreshTree()
		end
		return false
	else
		if button == "RightButton" then
			if not AngrySparks_DropDown then
				AngrySparks_DropDown = CreateFrame("Frame", "AngrySparksMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			EasyMenu(AngrySparks_PageMenu(selectedId), AngrySparks_DropDown, "cursor", 0, 0, "MENU")

			return false
		end
	end
end

function AngrySparks:CreateWindow()
	local window = AceGUI:Create("Frame")
	window:SetTitle("Angry Sparks")
	window:SetStatusText("")
	window:SetLayout("Flow")
	if AngrySparks:GetConfig('scale') then window.frame:SetScale(AngrySparks:GetConfig('scale')) end
	window:SetStatusTable(AngrySparks_State.window)
	window:Hide()
	AngrySparks.window = window

	AngrySparks_Window = window.frame
	if window.frame.SetResizeBounds then
		window.frame:SetResizeBounds(750, 400)
	else
		window.frame:SetMinResize(750, 400)
	end
	window.frame:SetFrameStrata("HIGH")
	window.frame:SetFrameLevel(1)
	window.frame:SetClampedToScreen(true)
	tinsert(UISpecialFrames, "AngrySparks_Window")

	local tree = AceGUI:Create("AngryTreeGroup")
	tree:SetTree(self:GetTree())
	tree:SelectByValue(1)
	tree:SetStatusTable(AngrySparks_State.tree)
	tree:SetFullWidth(true)
	tree:SetFullHeight(true)
	tree:SetLayout("Flow")
	tree:SetCallback("OnGroupSelected", function(widget, event, value) AngrySparks:UpdateSelected(true) end)
	tree:SetCallback("OnClick", AngrySparks_TreeClick)
	window:AddChild(tree)
	window.tree = tree

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	text:SetCallback("OnTextChanged", AngrySparks_TextChanged)
	text:SetCallback("OnEnterPressed", AngrySparks_TextEntered)
	tree:AddChild(text)
	window.text = text
	text.button:SetWidth(75)
	local buttontext = text.button:GetFontString()
	buttontext:ClearAllPoints()
	buttontext:SetPoint("TOPLEFT", text.button, "TOPLEFT", 15, -1)
	buttontext:SetPoint("BOTTOMRIGHT", text.button, "BOTTOMRIGHT", -15, 1)

	tree:PauseLayout()
	local button_display = AceGUI:Create("Button")
	button_display:SetText("Send and Display")
	button_display:SetWidth(140)
	button_display:SetHeight(22)
	button_display:ClearAllPoints()
	button_display:SetPoint("BOTTOMRIGHT", text.frame, "BOTTOMRIGHT", 0, 4)
	button_display:SetCallback("OnClick", function()
		AngrySparks_DisplayPage()
		button_display:SetDisabled(true)
		button_display:SetText("Sending...")
		self:ScheduleTimer(function()
			button_display:SetDisabled(false)
			button_display:SetText("Send and Display")
		end, updateThrottle)
	end)
	tree:AddChild(button_display)
	window.button_display = button_display

	local button_revert = AceGUI:Create("Button")
	button_revert:SetText("Revert")
	button_revert:SetWidth(80)
	button_revert:SetHeight(22)
	button_revert:ClearAllPoints()
	button_revert:SetDisabled(true)
	button_revert:SetPoint("BOTTOMLEFT", text.button, "BOTTOMRIGHT", 6, 0)
	button_revert:SetCallback("OnClick", AngrySparks_RevertPage)
	tree:AddChild(button_revert)
	window.button_revert = button_revert

	local button_restore = AceGUI:Create("Button")
	button_restore:SetText("Restore")
	button_restore:SetWidth(80)
	button_restore:SetHeight(22)
	button_restore:ClearAllPoints()
	button_restore:SetPoint("LEFT", button_revert.frame, "RIGHT", 6, 0)
	button_restore:SetCallback("OnClick", AngrySparks_RestorePage)
	tree:AddChild(button_restore)
	window.button_restore = button_restore

	local button_output = AceGUI:Create("Button")
	button_output:SetText("/raid")
	button_output:SetWidth(80)
	button_output:SetHeight(22)
	button_output:ClearAllPoints()
	button_output:SetPoint("BOTTOMLEFT", button_restore.frame, "BOTTOMRIGHT", 6, 0)
	button_output:SetCallback("OnClick", AngrySparks_OutputDisplayed)
	tree:AddChild(button_output)
	window.button_output = button_output

	window:PauseLayout()
	local button_add = AceGUI:Create("Button")
	button_add:SetText("+Page")
	button_add:SetWidth(80)
	button_add:SetHeight(19)
	button_add:ClearAllPoints()
	button_add:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 17, 18)
	button_add:SetCallback("OnClick", AngrySparks_AddPage)
	window:AddChild(button_add)
	window.button_add = button_add

	local button_rename = AceGUI:Create("Button")
	button_rename:SetText("Rename")
	button_rename:SetWidth(80)
	button_rename:SetHeight(19)
	button_rename:ClearAllPoints()
	button_rename:SetPoint("BOTTOMLEFT", button_add.frame, "BOTTOMRIGHT", 5, 0)
	button_rename:SetCallback("OnClick", function() AngrySparks_RenamePage() end)
	window:AddChild(button_rename)
	window.button_rename = button_rename

	local button_delete = AceGUI:Create("Button")
	button_delete:SetText("Delete")
	button_delete:SetWidth(80)
	button_delete:SetHeight(19)
	button_delete:ClearAllPoints()
	button_delete:SetPoint("BOTTOMLEFT", button_rename.frame, "BOTTOMRIGHT", 5, 0)
	button_delete:SetCallback("OnClick", function() AngrySparks_DeletePage() end)
	window:AddChild(button_delete)
	window.button_delete = button_delete

	local button_add_cat = AceGUI:Create("Button")
	button_add_cat:SetText("+Category")
	button_add_cat:SetWidth(120)
	button_add_cat:SetHeight(19)
	button_add_cat:ClearAllPoints()
	button_add_cat:SetPoint("BOTTOMLEFT", button_delete.frame, "BOTTOMRIGHT", 5, 0)
	button_add_cat:SetCallback("OnClick", function() AngrySparks_AddCategory() end)
	window:AddChild(button_add_cat)
	window.button_add_cat = button_add_cat

	local button_variables = AceGUI:Create("Button")
	button_variables:SetText("Variables")
	button_variables:SetWidth(120)
	button_variables:SetHeight(19)
	button_variables:ClearAllPoints()
	button_variables:SetPoint("BOTTOMLEFT", button_add_cat.frame, "BOTTOMRIGHT", 5, 0)
	button_variables:SetCallback("OnClick", function() AngrySparks:ToggleVariablesDisplay() end)
	window:AddChild(button_variables)
	window.button_variables = button_variables

	local button_clear = AceGUI:Create("Button")
	button_clear:SetText("Clear")
	button_clear:SetWidth(80)
	button_clear:SetHeight(19)
	button_clear:ClearAllPoints()
	button_clear:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -135, 18)
	button_clear:SetCallback("OnClick", AngrySparks_ClearPage)
	window:AddChild(button_clear)
	window.button_clear = button_clear

	self:UpdateSelected(true)
	self:UpdateMedia()

	self:CreateVariablesWindow()
end

function AngrySparks:CreateVariablesWindow()
	local window = AceGUI:Create("Frame")
	window:Hide()

	window:SetTitle("Variables")
	window:SetStatusText("")
	window:SetLayout("Flow")
	if window.frame.SetResizeBounds then
		window.frame:SetResizeBounds(750, 400)
	else
		window.frame:SetMinResize(750, 400)
	end
	window.frame:SetFrameStrata("HIGH")
	window.frame:SetFrameLevel(1)
	window.frame:SetClampedToScreen(true)
	if AngrySparks:GetConfig('scale') then window.frame:SetScale(AngrySparks:GetConfig('scale')) end

	AngrySparks.variablesWindow = window

	AngrySparks_VariablesWindow = window.frame
	tinsert(UISpecialFrames, "AngrySparks_VariablesWindow")

	local helpLabel = AceGUI:Create("Label")
	helpLabel:SetText(
		"Enter a string and what that string should be replaced with, one per line. Press Accept to update the variables and re-publish the currently selected page.")
	helpLabel:SetWidth(500)
	window:AddChild(helpLabel)

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	text:SetText(AngrySparks:VariablesToString())

	text:SetCallback("OnEnterPressed", function()
		AngrySparks:SaveVariables(text:GetText())
		local id = AngrySparks:SelectedId()
		if id then
			self:RehashPage(id)
			AngrySparks:DisplayPage(id)
			if AngrySparks_State.displayed == id then
				self:UpdateDisplayed()
			end
		end
	end)

	window:AddChild(text)

	window:SetCallback("OnShow", function() text:SetText(AngrySparks:VariablesToString()) end)
end

function AngrySparks:ToggleVariablesDisplay()
	if self.variablesWindow:IsVisible() then
		self.variablesWindow:Hide()
	else
		self.variablesWindow:Show()
	end
end

function AngrySparks:SaveVariables(text)
	local tmp = {}

	for _, v in ipairs({ strsplit("\n", text) }) do
		if v:trim() ~= "" then
			local var, str = string.match(v, "(%w+)%s+(.+)")
			if var and var:trim() ~= "" and str and str:trim() ~= "" then
				tinsert(tmp, { var, str })
			end
		end
	end

	AngrySparks_Variables = tmp
end

function AngrySparks:VariablesToString()
	local s = ""
	for _, v in ipairs(AngrySparks_Variables) do
		if v[1] and v[2] then
			s = s .. v[1] .. " " .. v[2] .. "\n"
		end
	end
	return s
end

function AngrySparks:SelectedUpdated(sender)
	if self.window and self.window.text.button:IsEnabled() then
		local popup_name = "AngrySparks_PageUpdated"
		if StaticPopupDialogs[popup_name] == nil then
			StaticPopupDialogs[popup_name] = {
				button1 = OKAY,
				whileDead = true,
				text = "",
				hideOnEscape = true,
				preferredIndex = 3
			}
		end
		StaticPopupDialogs[popup_name].text = "The page you are editing has been updated by " ..
			sender .. ".\n\nYou can view this update by reverting your changes."
		StaticPopup_Show(popup_name)
		return true
	else
		return false
	end
end

local function GetTree_InsertPage(tree, page)
	if page.Id == AngrySparks_State.displayed then
		table.insert(tree, { value = page.Id, text = page.Name, icon = "Interface\\BUTTONS\\UI-GuildButton-MOTD-Up" })
	else
		table.insert(tree, { value = page.Id, text = page.Name })
	end
end

local function GetTree_InsertChildren(categoryId, displayedPages)
	local tree = {}
	for _, cat in pairs(AngrySparks_Categories) do
		if cat.CategoryId == categoryId then
			table.insert(tree,
				{ value = -cat.Id, text = cat.Name, children = GetTree_InsertChildren(cat.Id, displayedPages) })
		end
	end

	for _, page in pairs(AngrySparks_Pages) do
		if page.CategoryId == categoryId then
			displayedPages[page.Id] = true
			GetTree_InsertPage(tree, page)
		end
	end

	table.sort(tree, function(a, b) return a.text < b.text end)
	return tree
end

function AngrySparks:GetTree()
	local tree = {}
	local displayedPages = {}

	for _, cat in pairs(AngrySparks_Categories) do
		if not cat.CategoryId then
			table.insert(tree,
				{ value = -cat.Id, text = cat.Name, children = GetTree_InsertChildren(cat.Id, displayedPages) })
		end
	end

	for _, page in pairs(AngrySparks_Pages) do
		if not page.CategoryId or not displayedPages[page.Id] then
			GetTree_InsertPage(tree, page)
		end
	end

	table.sort(tree, function(a, b) return a.text < b.text end)

	return tree
end

function AngrySparks:UpdateTree(id)
	if not self.window then return end
	self.window.tree:SetTree(self:GetTree())
	if id then
		self:SetSelectedId(id)
	end
end

function AngrySparks:UpdateSelected(destructive)
	if not self.window then return end
	local page = AngrySparks_Pages[self:SelectedId()]
	local permission = self:PermissionCheck()
	if destructive or not self.window.text.button:IsEnabled() then
		if page then
			self.window.text:SetText(page.Contents)
		else
			self.window.text:SetText("")
		end
		self.window.text.button:Disable()
	end
	if page and permission then
		self.window.button_rename:SetDisabled(false)
		self.window.button_revert:SetDisabled(not self.window.text.button:IsEnabled())
		self.window.button_display:SetDisabled(self.window.text.button:IsEnabled())
		self.window.button_output:SetDisabled(self.window.text.button:IsEnabled())
		self.window.button_restore:SetDisabled(not self.window.text.button:IsEnabled() and page.Backup == page.Contents)
		self.window.text:SetDisabled(false)
	else
		self.window.button_rename:SetDisabled(true)
		self.window.button_revert:SetDisabled(true)
		self.window.button_display:SetDisabled(true)
		self.window.button_output:SetDisabled(true)
		self.window.button_restore:SetDisabled(true)
		self.window.text:SetDisabled(true)
	end
	if page then
		self.window.button_delete:SetDisabled(false)
	else
		self.window.button_delete:SetDisabled(true)
	end
	if permission then
		self.window.button_add:SetDisabled(false)
		self.window.button_clear:SetDisabled(false)
		self.window.button_variables:SetDisabled(false)
	else
		self.window.button_add:SetDisabled(true)
		self.window.button_clear:SetDisabled(true)
		self.window.button_variables:SetDisabled(true)
	end
end

----------------------------------
-- Performing changes functions --
----------------------------------

function AngrySparks:SelectedId()
	return selectedLastValue(AngrySparks_State.tree.selected)
end

function AngrySparks:SetSelectedId(selectedId)
	local page = AngrySparks_Pages[selectedId]
	if page then
		if page.CategoryId then
			local cat = AngrySparks_Categories[page.CategoryId]
			local path = {}
			while cat do
				table.insert(path, -cat.Id)
				if cat.CategoryId then
					cat = AngrySparks_Categories[cat.CategoryId]
				else
					cat = nil
				end
			end
			tReverse(path)
			table.insert(path, page.Id)
			self.window.tree:SelectByPath(unpack(path))
		else
			self.window.tree:SelectByValue(page.Id)
		end
	else
		self.window.tree:SetSelected()
	end
end

function AngrySparks:Get(id)
	if id == nil then id = self:SelectedId() end
	return AngrySparks_Pages[id]
end

function AngrySparks:GetCat(id)
	return AngrySparks_Categories[id]
end

function AngrySparks:Hash(name, contents, variables)
	local code = libC:fcs32init()
	code = libC:fcs32update(code, name)
	code = libC:fcs32update(code, "\n")
	code = libC:fcs32update(code, contents)
	if (variables) then
		code = libC:fcs32update(code, "\n")
		code = libC:fcs32update(code, variables)
	end
	return libC:fcs32final(code)
end

function AngrySparks:CreatePage(name)
	if not self:PermissionCheck() then return end
	local id = self:Hash("page", math.random(2000000000))

	AngrySparks_Pages[id] = {
		Id = id,
		Updated = time(),
		UpdateId = self:Hash(name, "", AngrySparks:VariablesToString()),
		Name =
			name,
		Contents = ""
	}
	self:UpdateTree(id)
	self:SendPage(id, true)
end

function AngrySparks:RenamePage(id, name)
	local page = self:Get(id)
	if not page or not self:PermissionCheck() then return end

	page.Name = name
	page.Updated = time()
	self:RehashPage(id)

	self:SendPage(id, true)
	self:UpdateTree()
	if AngrySparks_State.displayed == id then
		self:UpdateDisplayed()
		self:ShowDisplay()
	end
end

function AngrySparks:DeletePage(id)
	AngrySparks_Pages[id] = nil
	if self.window and self:SelectedId() == id then
		self:SetSelectedId(nil)
		self:UpdateSelected(true)
	end
	if AngrySparks_State.displayed == id then
		self:ClearDisplayed()
	end
	self:UpdateTree()
end

function AngrySparks:TouchPage(id)
	if not self:PermissionCheck() then return end
	local page = self:Get(id)
	if not page then return end

	page.Updated = time()
end

function AngrySparks:RehashPage(id)
	local page = self:Get(id)
	if not page then return end
	page.UpdateId = self:Hash(page.Name, page.Contents, AngrySparks:VariablesToString())
end

function AngrySparks:CreateCategory(name)
	local id = self:Hash("cat", math.random(2000000000))

	AngrySparks_Categories[id] = { Id = id, Name = name }

	if AngrySparks_State.tree.groups then
		AngrySparks_State.tree.groups[-id] = true
	end
	self:UpdateTree()
end

function AngrySparks:RenameCategory(id, name)
	local cat = self:GetCat(id)
	if not cat then return end

	cat.Name = name

	self:UpdateTree()
end

function AngrySparks:DeleteCategory(id)
	local cat = self:GetCat(id)
	if not cat then return end

	local selectedId = self:SelectedId()

	for _, c in pairs(AngrySparks_Categories) do
		if cat.Id == c.CategoryId then
			c.CategoryId = cat.CategoryId
		end
	end

	for _, p in pairs(AngrySparks_Pages) do
		if cat.Id == p.CategoryId then
			p.CategoryId = cat.CategoryId
		end
	end

	AngrySparks_Categories[id] = nil

	self:UpdateTree()
	self:SetSelectedId(selectedId)
end

function AngrySparks:AssignCategory(entryId, parentId)
	local page, cat
	if entryId > 0 then
		page = self:Get(entryId)
	else
		cat = self:GetCat(-entryId)
	end
	local parent = self:GetCat(parentId)
	if not (page or cat) or not parent then return end

	if page then
		if page.CategoryId == parentId then
			page.CategoryId = nil
		else
			page.CategoryId = parentId
		end
	end

	if cat then
		if cat.CategoryId == parentId then
			cat.CategoryId = nil
		else
			cat.CategoryId = parentId
		end
	end

	local selectedId = self:SelectedId()
	self:UpdateTree()
	if selectedId == entryId then
		self:SetSelectedId(selectedId)
	end
end

function AngrySparks:UpdateContents(id, value)
	if not self:PermissionCheck() then return end
	local page = self:Get(id)
	if not page then return end

	local new_content = value:gsub('^%s+', ''):gsub('%s+$', '')
	local contents_updated = new_content ~= page.Contents
	page.Contents = new_content
	page.Backup = new_content
	page.Updated = time()
	self:RehashPage(id)

	self:SendPage(id, true)
	self:UpdateSelected(true)
	if AngrySparks_State.displayed == id then
		self:UpdateDisplayed()
		self:ShowDisplay()
		if contents_updated then self:DisplayUpdateNotification() end
	end
end

function AngrySparks:CreateBackup()
	for _, page in pairs(AngrySparks_Pages) do
		page.Backup = page.Contents
	end
	self:UpdateSelected()
end

function AngrySparks:ClearDisplayed()
	AngrySparks_State.displayed = nil
	self:UpdateDisplayed()
	self:UpdateTree()
end

function AngrySparks:IsPlayerRaidLeader()
	local leader = self:GetRaidLeader()
	return leader and PlayerFullName() == EnsureUnitFullName(leader)
end

function AngrySparks:IsGuildRaid()
	if IsInRaid() then
		local leader = self:GetRaidLeader()

		local totalMembers, _, numOnlineAndMobileMembers = GetNumGuildMembers()
		local scanTotal = GetGuildRosterShowOffline() and totalMembers or
			numOnlineAndMobileMembers --Attempt CPU saving, if "show offline" is unchecked, we can reliably scan only online members instead of whole roster
		for i = 1, scanTotal do
			local name = GetGuildRosterInfo(i)
			if not name then break end
			name = EnsureUnitFullName(name)
			if name == leader then
				return true
			end
		end
	end

	return false
end

function AngrySparks:IsValidRaid()
	if self:GetConfig('allowall') then
		return true
	end

	for token in string.gmatch(AngrySparks:GetConfig('allowplayers'), "[^%s!#$%%&()*+,./:;<=>?@\\^_{|}~%[%]]+") do
		if leader and EnsureUnitFullName(token):lower() == EnsureUnitFullName(leader):lower() then
			return true
		end
	end

	if self:IsPlayerRaidLeader() then
		return true
	end

	if self:IsGuildRaid() then
		return true
	end

	return false
end

function AngrySparks:PermissionCheck(sender)
	if not sender then sender = PlayerFullName() end

	if (IsInRaid() or IsInGroup()) then
		return (UnitIsGroupLeader(EnsureUnitShortName(sender)) == true or UnitIsGroupAssistant(EnsureUnitShortName(sender)) == true) and
			self:IsValidRaid()
	else
		return sender == PlayerFullName()
	end
end

function AngrySparks:PermissionsUpdated()
	self:UpdateSelected()
	if comStarted then
		self:SendRequestDisplay()
	end
	if (IsInRaid() or IsInGroup()) and not self:IsValidRaid() then
		self:ClearDisplayed()
	end
end

---------------------
-- Displaying Page --
---------------------

local function DragHandle_MouseDown(frame) frame:GetParent():GetParent():StartSizing("RIGHT") end
local function DragHandle_MouseUp(frame)
	local display = frame:GetParent():GetParent()
	display:StopMovingOrSizing()
	AngrySparks_State.display.width = display:GetWidth()
	lwin.SavePosition(display)
	AngrySparks:SyncTextSizeFrames()
end
local function Mover_MouseDown(frame) frame:GetParent():StartMoving() end
local function Mover_MouseUp(frame)
	local display = frame:GetParent()
	display:StopMovingOrSizing()
	lwin.SavePosition(display)
end

function AngrySparks:ResetPosition()
	AngrySparks_State.display = {}
	AngrySparks_State.directionUp = false
	AngrySparks_State.locked = false

	self.display_text:Show()
	self.mover:Show()
	self.frame:SetWidth(300)

	lwin.RegisterConfig(self.frame, AngrySparks_State.display)
	lwin.RestorePosition(self.frame)

	self:UpdateDirection()
end

function AngrySparks_ToggleDisplay()
	AngrySparks:ToggleDisplay()
end

function AngrySparks_ShowDisplay()
	AngrySparks:ShowDisplay()
end

function AngrySparks_HideDisplay()
	AngrySparks:HideDisplay()
end

function AngrySparks:ShowDisplay()
	self.display_text:Show()
	self:SyncTextSizeFrames()
	AngrySparks_State.display.hidden = false
end

function AngrySparks:HideDisplay()
	self.display_text:Hide()
	AngrySparks_State.display.hidden = true
end

function AngrySparks:ToggleDisplay()
	if self.display_text:IsShown() then
		self:HideDisplay()
	else
		self:ShowDisplay()
	end
end

function AngrySparks:Paginate(direction)
	if direction == "forward" then
		AngrySparks_State.currentPage = AngrySparks_State.currentPage + 1
	else
		AngrySparks_State.currentPage = AngrySparks_State.currentPage - 1
	end
	self:UpdateDisplayed()
end

function AngrySparks:CreateDisplay()
	local frame = CreateFrame("Frame", "AngryAss", UIParent)
	frame:SetPoint("CENTER", 0, 0)
	frame:SetWidth(AngrySparks_State.display.width or 300)
	frame:SetHeight(1)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetClampedToScreen(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(180, 1, 830, 1)
	else
		frame:SetMinResize(180, 1)
		frame:SetMaxResize(830, 1)
	end
	frame:SetFrameStrata("MEDIUM")
	self.frame = frame

	lwin.RegisterConfig(frame, AngrySparks_State.display)
	lwin.RestorePosition(frame)

	local text = CreateFrame("ScrollingMessageFrame", "AngryAssScrollingMessage", frame)
	text:SetIndentedWordWrap(true)
	text:SetJustifyH("LEFT")
	text:SetFading(false)
	text:SetMaxLines(70)
	text:SetHeight(700)
	text:SetHyperlinksEnabled(false)
	self.display_text = text

	local backdrop = text:CreateTexture()
	backdrop:SetDrawLayer("BACKGROUND")
	self.backdrop = backdrop

	local clickOverlay = CreateFrame("Frame", "AngryAssClickOverlay", text)
	clickOverlay:SetAllPoints(text)
	clickOverlay:SetScript("OnMouseDown", function(_, button)
		local direction
		if button == "LeftButton" then
			direction = "forward"
		else
			direction = "backward"
		end
		AngrySparks:Paginate(direction)
	end)
	self.clickOverlay = clickOverlay

	local pagination = CreateFrame("Frame", "AngryAssPagination", clickOverlay)
	pagination:SetPoint("TOPRIGHT", -4, -4)
	pagination:SetHeight(1)
	pagination:SetWidth(1)
	self.pagination = pagination

	local paginationText = pagination:CreateFontString()
	local fontName = LSM:Fetch("font", AngrySparks:GetConfig('fontName') --[[@as string]])
	local fontHeight = AngrySparks:GetConfig('fontHeight')
	local fontFlags = AngrySparks:GetConfig('fontFlags')

	paginationText:SetTextColor(HexToRGB(self:GetConfig('color')))
	paginationText:SetFont(fontName, fontHeight, fontFlags)
	paginationText:SetPoint("TOPRIGHT")
	self.paginationText = paginationText

	local mover = CreateFrame("Frame", "AngryAssMover", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mover:SetFrameLevel(clickOverlay:GetFrameLevel() + 10)
	mover:SetPoint("LEFT", 0, 0)
	mover:SetPoint("RIGHT", 0, 0)
	mover:SetHeight(16)
	mover:EnableMouse(true)
	mover:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	mover:SetBackdropColor(0.616, 0.149, 0.114, 0.9)
	mover:SetScript("OnMouseDown", Mover_MouseDown)
	mover:SetScript("OnMouseUp", Mover_MouseUp)
	self.mover = mover
	if AngrySparks_State.locked then mover:Hide() end

	local label = mover:CreateFontString()
	label:SetFontObject("GameFontNormal")
	label:SetJustifyH("CENTER")
	label:SetPoint("LEFT", 38, 0)
	label:SetPoint("RIGHT", -38, 0)
	label:SetText("Angry Sparks")

	local direction = CreateFrame("Button", "AngryAssDirection", mover)
	direction:SetPoint("LEFT", 2, 0)
	direction:SetWidth(16)
	direction:SetHeight(16)
	direction:SetNormalTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetPushedTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	direction:SetScript("OnClick", function() AngrySparks:ToggleDirection() end)
	self.direction_button = direction

	local lock = CreateFrame("Button", "AngryAssLock", mover)
	lock:SetNormalTexture("Interface\\LFGFRAME\\UI-LFG-ICON-LOCK")
	lock:GetNormalTexture():SetTexCoord(0, 0.71875, 0, 0.875)
	lock:SetPoint("LEFT", direction, "RIGHT", 4, 0)
	lock:SetWidth(12)
	lock:SetHeight(14)
	lock:SetScript("OnClick", function() AngrySparks:ToggleLock() end)

	local drag = CreateFrame("Frame", "AngryAssDrag", mover)
	drag:SetFrameLevel(mover:GetFrameLevel() + 10)
	drag:SetWidth(16)
	drag:SetHeight(16)
	drag:SetPoint("BOTTOMRIGHT", 0, 0)
	drag:EnableMouse(true)
	drag:SetScript("OnMouseDown", DragHandle_MouseDown)
	drag:SetScript("OnMouseUp", DragHandle_MouseUp)
	drag:SetAlpha(0.5)

	local dragtex = drag:CreateTexture(nil, "OVERLAY")
	dragtex:SetTexture("Interface\\AddOns\\AngryGirls\\Textures\\draghandle")
	dragtex:SetWidth(16)
	dragtex:SetHeight(16)
	dragtex:SetBlendMode("ADD")
	dragtex:SetPoint("CENTER", drag)

	local glow = text:CreateTexture()
	glow:SetDrawLayer("BORDER")
	glow:SetTexture("Interface\\AddOns\\AngryGirls\\Textures\\LevelUpTex")
	glow:SetSize(223, 115)
	glow:SetTexCoord(0.56054688, 0.99609375, 0.24218750, 0.46679688)
	glow:SetVertexColor(HexToRGB(self:GetConfig('glowColor')))
	glow:SetAlpha(0)
	self.display_glow = glow

	local glow2 = text:CreateTexture()
	glow2:SetDrawLayer("BORDER")
	glow2:SetTexture("Interface\\AddOns\\AngryGirls\\Textures\\LevelUpTex")
	glow2:SetSize(418, 7)
	glow2:SetTexCoord(0.00195313, 0.81835938, 0.01953125, 0.03320313)
	glow2:SetVertexColor(HexToRGB(self:GetConfig('glowColor')))
	glow2:SetAlpha(0)
	self.display_glow2 = glow2

	if AngrySparks_State.display.hidden then text:Hide() end
	self:UpdateMedia()
	self:UpdateDirection()
end

function AngrySparks:ToggleLock()
	AngrySparks_State.locked = not AngrySparks_State.locked
	if AngrySparks_State.locked then
		self.mover:Hide()
	else
		self.mover:Show()
	end
end

function AngrySparks:ToggleDirection()
	AngrySparks_State.directionUp = not AngrySparks_State.directionUp
	self:UpdateDirection()
end

function AngrySparks:UpdateDirection()
	if AngrySparks_State.directionUp then
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("BOTTOMLEFT", 0, 8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.display_text:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0.5, 1)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0.5, 1)

		self.display_glow:ClearAllPoints()
		self.display_glow:SetPoint("BOTTOM", 0, -4)
		self.display_glow:SetTexCoord(0.56054688, 0.99609375, 0.24218750, 0.46679688)
		self.display_glow2:ClearAllPoints()
		self.display_glow2:SetPoint("TOP", self.display_glow, "BOTTOM", 0, 6)
	else
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("TOPLEFT", 0, -8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.display_text:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP)
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0, 0.5)

		self.display_glow:ClearAllPoints()
		self.display_glow:SetPoint("TOP", 0, 4)
		self.display_glow:SetTexCoord(0.56054688, 0.99609375, 0.46679688, 0.24218750)
		self.display_glow2:ClearAllPoints()
		self.display_glow2:SetPoint("BOTTOM", self.display_glow, "TOP", 0, 0)
	end
	if self.display_text:IsShown() then
		self.display_text:Hide()
		self.display_text:Show()
	end
	self:UpdateDisplayed()
end

function AngrySparks:SyncTextSizeFrames()
	local first, last
	for lineIndex, visibleLine in ipairs(self.display_text.visibleLines) do
		local messageInfo = self.display_text.historyBuffer:GetEntryAtIndex(lineIndex)
		if messageInfo then
			if not first then first = visibleLine end
			last = visibleLine
		end
	end

	self:ResizeBackdrop(first, last)
	self:ResizeClickOverlay(first, last)
end

function AngrySparks:ResizeClickOverlay(first, last)
	if first and last then
		self.clickOverlay:ClearAllPoints()
		if AngrySparks_State.directionUp then
			self.clickOverlay:SetPoint("TOPLEFT", last, "TOPLEFT", -4, 4)
			self.clickOverlay:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", 4, -4)
		else
			self.clickOverlay:SetPoint("TOPLEFT", first, "TOPLEFT", -4, 4)
			self.clickOverlay:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 4, -4)
		end
		self.clickOverlay:Show()
	else
		self.clickOverlay:Hide()
	end
end

function AngrySparks:ResizeBackdrop(first, last)
	if first and last and self:GetConfig('backdropShow') then
		self.backdrop:ClearAllPoints()
		if AngrySparks_State.directionUp then
			self.backdrop:SetPoint("TOPLEFT", last, "TOPLEFT", -4, 4)
			self.backdrop:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", 4, -4)
		else
			self.backdrop:SetPoint("TOPLEFT", first, "TOPLEFT", -4, 4)
			self.backdrop:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 4, -4)
		end
		self.backdrop:SetColorTexture(HexToRGB(self:GetConfig('backdropColor')))
		self.backdrop:Show()
	else
		self.backdrop:Hide()
	end
end

local editFontName, editFontHeight, editFontFlags
function AngrySparks:UpdateMedia()
	local fontName = LSM:Fetch("font", AngrySparks:GetConfig('fontName'))
	local fontHeight = AngrySparks:GetConfig('fontHeight')
	local fontFlags = AngrySparks:GetConfig('fontFlags')

	self.display_text:SetTextColor(HexToRGB(self:GetConfig('color')))
	self.display_text:SetFont(fontName, fontHeight, fontFlags)
	self.display_text:SetSpacing(AngrySparks:GetConfig('lineSpacing'))

	if self.window then
		if self:GetConfig('editBoxFont') then
			if not editFontName then
				editFontName, editFontHeight, editFontFlags = self.window.text.editBox:GetFont()
			end
			self.window.text.editBox:SetFont(fontName, fontHeight, fontFlags)
		elseif editFontName then
			self.window.text.editBox:SetFont(editFontName, editFontHeight, editFontFlags)
		end
	end

	self:SyncTextSizeFrames()
end

local updateFlasher, updateFlasher2 = nil, nil
function AngrySparks:DisplayUpdateNotification()
	if updateFlasher == nil then
		updateFlasher = self.display_glow:CreateAnimationGroup()

		-- Flashing in
		local fade1 = updateFlasher:CreateAnimation("Alpha")
		fade1:SetDuration(0.5)
		fade1:SetFromAlpha(0)
		fade1:SetToAlpha(1)
		fade1:SetOrder(1)

		-- Holding it visible for 1 second
		fade1:SetEndDelay(5)

		-- Flashing out
		local fade2 = updateFlasher:CreateAnimation("Alpha")
		fade2:SetDuration(0.5)
		fade2:SetFromAlpha(1)
		fade2:SetToAlpha(0)
		fade2:SetOrder(3)
	end
	if updateFlasher2 == nil then
		updateFlasher2 = self.display_glow2:CreateAnimationGroup()

		-- Flashing in
		local fade1 = updateFlasher2:CreateAnimation("Alpha")
		fade1:SetDuration(0.5)
		fade1:SetFromAlpha(0)
		fade1:SetToAlpha(1)
		fade1:SetOrder(1)

		-- Holding it visible for 1 second
		fade1:SetEndDelay(5)

		-- Flashing out
		local fade2 = updateFlasher2:CreateAnimation("Alpha")
		fade2:SetDuration(0.5)
		fade2:SetFromAlpha(1)
		fade2:SetToAlpha(0)
		fade2:SetOrder(3)
	end

	updateFlasher:Play()
	updateFlasher2:Play()
end

local function ci_pattern(pattern)
	local p = pattern:gsub("(%%?)(.)", function(percent, letter)
		if percent ~= "" or not letter:match("%a") then
			return percent .. letter
		else
			return string.format("[%s%s]", letter:lower(), letter:upper())
		end
	end)
	return p
end

function AngrySparks:UpdateDisplayedIfNewGroup()
	local newGroup = self:GetCurrentGroup()
	if newGroup ~= currentGroup then
		currentGroup = newGroup
		self:UpdateDisplayed()
	end
end

function AngrySparks:ReplaceVariables(text)
	for _, v in ipairs(AngrySparks_Variables) do
		text = text:gsub("{" .. v[1] .. "}", v[2])
	end

	return text
end

function AngrySparks:UpdateDisplayed()
	local page = AngrySparks_Pages[AngrySparks_State.displayed]
	if page then
		local text = page.Contents

		local highlights = {}
		for token in string.gmatch(AngrySparks:GetConfig('highlight'), "[^%s%p]+") do
			token = token:lower()
			if token == 'group' then
				tinsert(highlights, 'g' .. (currentGroup or 0))
			else
				tinsert(highlights, token)
			end
		end

		local highlightHex = self:GetConfig('highlightColor')

		text = AngrySparks:ReplaceVariables(text)

		text = text:gsub("||", "|")
			:gsub(ci_pattern('|cblue'), "|cff00cbf4")
			:gsub(ci_pattern('|cgreen'), "|cff0adc00")
			:gsub(ci_pattern('|cred'), "|cffeb310c")
			:gsub(ci_pattern('|cyellow'), "|cfffaf318")
			:gsub(ci_pattern('|corange'), "|cffff9d00")
			:gsub(ci_pattern('|cpink'), "|cfff64c97")
			:gsub(ci_pattern('|cpurple'), "|cffdc44eb")
			:gsub(ci_pattern('|cdruid'), "|cffff7d0a")
			:gsub(ci_pattern('|chunter'), "|cffabd473")
			:gsub(ci_pattern('|cmage'), "|cff40C7eb")
			:gsub(ci_pattern('|cpaladin'), "|cfff58cba")
			:gsub(ci_pattern('|cpriest'), "|cffffffff")
			:gsub(ci_pattern('|crogue'), "|cfffff569")
			:gsub(ci_pattern('|cshaman'), "|cff0070de")
			:gsub(ci_pattern('|cwarlock'), "|cff8787ed")
			:gsub(ci_pattern('|cwarrior'), "|cffc79c6e")
			:gsub("([^%s%p]+)", function(word)
				local word_lower = word:lower()
				for _, token in ipairs(highlights) do
					if token == word_lower then
						return string.format("|cff%s%s|r", highlightHex, word)
					end
				end
				return word
			end)
			:gsub(ci_pattern('{spell%s+(%d+)}'), function(id)
				return GetSpellLink(id)
			end)
			:gsub(ci_pattern('{star}'), "{rt1}")
			:gsub(ci_pattern('{circle}'), "{rt2}")
			:gsub(ci_pattern('{diamond}'), "{rt3}")
			:gsub(ci_pattern('{triangle}'), "{rt4}")
			:gsub(ci_pattern('{moon}'), "{rt5}")
			:gsub(ci_pattern('{square}'), "{rt6}")
			:gsub(ci_pattern('{cross}'), "{rt7}")
			:gsub(ci_pattern('{x}'), "{rt7}")
			:gsub(ci_pattern('{skull}'), "{rt8}")
			:gsub(ci_pattern('{rt([1-8])}'), "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t")
			:gsub(ci_pattern('{healthstone}'), "{hs}")
			:gsub(ci_pattern('{hs}'), "|TInterface\\Icons\\INV_Stone_04:0|t")
			:gsub(ci_pattern('{icon%s+(%d+)}'), function(id)
				return format("|T%s:0|t", select(3, GetSpellInfo(tonumber(id))))
			end)
			:gsub(ci_pattern('{icon%s+([%w_]+)}'), "|TInterface\\Icons\\%1:0|t")
			:gsub(ci_pattern('{damage}'), "{dps}")
			:gsub(ci_pattern('{tank}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t")
			:gsub(ci_pattern('{healer}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:1:20|t")
			:gsub(ci_pattern('{dps}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:22:41|t")
			:gsub(ci_pattern('{hunter}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:16:32|t")
			:gsub(ci_pattern('{warrior}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:0:16|t")
			:gsub(ci_pattern('{rogue}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:0:16|t")
			:gsub(ci_pattern('{mage}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:0:16|t")
			:gsub(ci_pattern('{priest}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:16:32|t")
			:gsub(ci_pattern('{warlock}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:48:64:16:32|t")
			:gsub(ci_pattern('{paladin}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:32:48|t")
			:gsub(ci_pattern('{druid}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:48:64:0:16|t")
			:gsub(ci_pattern('{shaman}'),
				"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:16:32|t")
			:gsub(ci_pattern('{elemental}'), "|T136048:0|t")
			:gsub(ci_pattern('{moonkin}'), "|T136096:0|t")
			:gsub(ci_pattern('{spriest}'), "|T136200:0|t")

		if not isClassic then
			text = text:gsub(ci_pattern('|cdeathknight'), "|cffc41f3b")
				:gsub(ci_pattern('|cmonk'), "|cff00ff96")
				:gsub(ci_pattern('|cdemonhunter'), "|cffa330c9")
				:gsub(ci_pattern('{boss%s+(%d+)}'), function(id)
					return select(5, EJ_GetEncounterInfo(id))
				end)
				:gsub(ci_pattern('{journal%s+(%d+)}'), function(id)
					return C_EncounterJournal.GetSectionInfo(id) and C_EncounterJournal.GetSectionInfo(id).link
				end)
				:gsub(ci_pattern('{hero}'), "{heroism}")
				:gsub(ci_pattern('{heroism}'), "|TInterface\\Icons\\ABILITY_Shaman_Heroism:0|t")
				:gsub(ci_pattern('{bloodlust}'), "{bl}")
				:gsub(ci_pattern('{bl}'), "|TInterface\\Icons\\SPELL_Nature_Bloodlust:0|t")
				:gsub(ci_pattern('{deathknight}'),
					"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:32:48|t")
				:gsub(ci_pattern('{monk}'),
					"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:32:48|t")
				:gsub(ci_pattern('{demonhunter}'),
					"|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:64:48:32:48|t")
		end

		self.display_text:Clear()

		local pages = explode("{page}", text)

		if pages[AngrySparks_State.currentPage] == nil then
			if AngrySparks_State.currentPage == nil or AngrySparks_State.currentPage > 1 then
				AngrySparks_State.currentPage = 1
			else
				AngrySparks_State.currentPage = #pages
			end
		end

		local lines = { strsplit("\n", pages[AngrySparks_State.currentPage]) }

		local lines_count = #lines
		for i = 1, lines_count do
			local line
			if AngrySparks_State.directionUp then
				line = lines[i]
			else
				line = lines[lines_count - i + 1]
			end
			if line == "" then line = " " end
			self.display_text:AddMessage(line)
		end

		if #pages > 1 then
			self.paginationText:SetText("(" .. AngrySparks_State.currentPage .. "/" .. #pages .. ")")
			self.paginationText:Show()
		else
			self.paginationText:Hide()
		end
	else
		self.display_text:Clear()
	end
	self:SyncTextSizeFrames()
end

function AngrySparks_OutputDisplayed()
	return AngrySparks:OutputDisplayed(AngrySparks:SelectedId())
end

function AngrySparks:OutputDisplayed(id)
	if not self:PermissionCheck() then
		self:Print(RED_FONT_COLOR_CODE .. "You don't have permission to output a page.|r")
	end
	if not id then id = AngrySparks_State.displayed end
	local page = AngrySparks_Pages[id]
	local channel
	if not isClassic and (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) then
		channel = "INSTANCE_CHAT"
	elseif IsInRaid() then
		channel = "RAID"
	elseif IsInGroup() then
		channel = "PARTY"
	end
	if channel and page then
		local output = page.Contents

		output = AngrySparks:ReplaceVariables(output)

		output = output:gsub("||", "|")
			:gsub(ci_pattern('|r'), "")
			:gsub(ci_pattern('|cblue'), "")
			:gsub(ci_pattern('|cgreen'), "")
			:gsub(ci_pattern('|cred'), "")
			:gsub(ci_pattern('|cyellow'), "")
			:gsub(ci_pattern('|corange'), "")
			:gsub(ci_pattern('|cpink'), "")
			:gsub(ci_pattern('|cpurple'), "")
			:gsub(ci_pattern('|cdruid'), "")
			:gsub(ci_pattern('|chunter'), "")
			:gsub(ci_pattern('|cmage'), "")
			:gsub(ci_pattern('|cpaladin'), "")
			:gsub(ci_pattern('|cpriest'), "")
			:gsub(ci_pattern('|crogue'), "")
			:gsub(ci_pattern('|cshaman'), "")
			:gsub(ci_pattern('|cwarlock'), "")
			:gsub(ci_pattern('|cwarrior'), "")
			:gsub(ci_pattern('|c%w?%w?%w?%w?%w?%w?%w?%w?'), "")
			:gsub(ci_pattern('{spell%s+(%d+)}'), function(id)
				return GetSpellLink(id)
			end)
			:gsub(ci_pattern('{star}'), "{rt1}")
			:gsub(ci_pattern('{circle}'), "{rt2}")
			:gsub(ci_pattern('{diamond}'), "{rt3}")
			:gsub(ci_pattern('{triangle}'), "{rt4}")
			:gsub(ci_pattern('{moon}'), "{rt5}")
			:gsub(ci_pattern('{square}'), "{rt6}")
			:gsub(ci_pattern('{cross}'), "{rt7}")
			:gsub(ci_pattern('{x}'), "{rt7}")
			:gsub(ci_pattern('{skull}'), "{rt8}")
			:gsub(ci_pattern('{healthstone}'), "{hs}")
			:gsub(ci_pattern('{hs}'), 'Healthstone')
			:gsub(ci_pattern('{icon%s+([%w_]+)}'), '')
			:gsub(ci_pattern('{damage}'), 'Damage')
			:gsub(ci_pattern('{tank}'), 'Tanks')
			:gsub(ci_pattern('{healer}'), 'Healers')
			:gsub(ci_pattern('{dps}'), 'Damage')
			:gsub(ci_pattern('{hunter}'), LOCALIZED_CLASS_NAMES_MALE["HUNTER"])
			:gsub(ci_pattern('{warrior}'), LOCALIZED_CLASS_NAMES_MALE["WARRIOR"])
			:gsub(ci_pattern('{rogue}'), LOCALIZED_CLASS_NAMES_MALE["ROGUE"])
			:gsub(ci_pattern('{mage}'), LOCALIZED_CLASS_NAMES_MALE["MAGE"])
			:gsub(ci_pattern('{priest}'), LOCALIZED_CLASS_NAMES_MALE["PRIEST"])
			:gsub(ci_pattern('{warlock}'), LOCALIZED_CLASS_NAMES_MALE["WARLOCK"])
			:gsub(ci_pattern('{paladin}'), LOCALIZED_CLASS_NAMES_MALE["PALADIN"])
			:gsub(ci_pattern('{druid}'), LOCALIZED_CLASS_NAMES_MALE["DRUID"])
			:gsub(ci_pattern('{shaman}'), LOCALIZED_CLASS_NAMES_MALE["SHAMAN"])
			:gsub(ci_pattern('{page}'), "")
			:gsub(ci_pattern('{elemental}'), "Elemental Shaman")
			:gsub(ci_pattern('{moonkin}'), "Moonkin")
			:gsub(ci_pattern('{spriest}'), "Shadow Priest")

		if not isClassic then
			output = output:gsub(ci_pattern('|cdeathknight'), "")
				:gsub(ci_pattern('|cmonk'), "")
				:gsub(ci_pattern('|cdemonhunter'), "")
				:gsub(ci_pattern('{boss%s+(%d+)}'), function(id)
					return select(5, EJ_GetEncounterInfo(id))
				end)
				:gsub(ci_pattern('{journal%s+(%d+)}'), function(id)
					return C_EncounterJournal.GetSectionInfo(id) and C_EncounterJournal.GetSectionInfo(id).link
				end)
				:gsub(ci_pattern('{bloodlust}'), "{bl}")
				:gsub(ci_pattern('{bl}'), 'Bloodlust')
				:gsub(ci_pattern('{hero}'), "{heroism}")
				:gsub(ci_pattern('{heroism}'), 'Heroism')
				:gsub(ci_pattern('{deathknight}'), LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"])
				:gsub(ci_pattern('{monk}'), LOCALIZED_CLASS_NAMES_MALE["MONK"])
				:gsub(ci_pattern('{demonhunter}'), LOCALIZED_CLASS_NAMES_MALE["DEMONHUNTER"])
		end

		local lines = { strsplit("\n", output) }
		for _, line in ipairs(lines) do
			if line ~= "" then
				SendChatMessage(line, channel)
			end
		end
	end
end

-----------------
-- Addon Setup --
-----------------

local configDefaults = {
	scale = 1,
	hideoncombat = false,
	fontName = "Friz Quadrata TT",
	fontHeight = 12,
	fontFlags = "",
	highlight = "",
	highlightColor = "ffd200",
	color = "ffffff",
	allowall = false,
	lineSpacing = 0,
	allowplayers = "",
	backdropShow = false,
	backdropColor = "00000080",
	glowColor = "FF0000",
	editBoxFont = false,
}

function AngrySparks:GetConfig(key)
	if AngrySparks_Config[key] == nil then
		return configDefaults[key]
	else
		return AngrySparks_Config[key]
	end
end

function AngrySparks:SetConfig(key, value)
	if configDefaults[key] == value then
		AngrySparks_Config[key] = nil
	else
		AngrySparks_Config[key] = value
	end
end

function AngrySparks:RestoreDefaults()
	AngrySparks_Config = {}
	self:UpdateMedia()
	self:UpdateDisplayed()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("AngrySparks")
end

local blizOptionsPanel
function AngrySparks:OnInitialize()
	if AngrySparks_State == nil then
		AngrySparks_State = { tree = {}, window = {}, display = {}, displayed = nil, locked = false, directionUp = false, currentPage = 1 }
	end
	if AngrySparks_Pages == nil then AngrySparks_Pages = {} end
	if AngrySparks_Config == nil then AngrySparks_Config = {} end
	if AngrySparks_Categories == nil then
		AngrySparks_Categories = {}
	else
		for _, cat in pairs(AngrySparks_Categories) do
			if cat.Children then
				for _, pageId in ipairs(cat.Children) do
					local page = AngrySparks_Pages[pageId]
					if page then
						page.CategoryId = cat.Id
					end
				end
				cat.Children = nil
			end
		end
	end
	if AngrySparks_Variables == nil then
		AngrySparks_Variables = {}
		AngrySparks_Variables[1] = { "tank1", "Daxxiz" }
		AngrySparks_Variables[2] = { "mage1", "Praxxis" }
	end

	local ver = AngrySparks_Version
	if ver:sub(1, 1) == "@" then ver = "dev" end

	local options = {
		name = "Angry Sparks " .. ver,
		handler = AngrySparks,
		type = "group",
		args = {
			window = {
				type = "execute",
				order = 3,
				name = "Toggle Window",
				desc = "Shows/hides the edit window (also available in game keybindings)",
				func = function() AngrySparks_ToggleWindow() end
			},
			help = {
				type = "execute",
				order = 99,
				name = "Help",
				hidden = true,
				func = function()
					LibStub("AceConfigCmd-3.0").HandleCommand(self, "aa", "AngrySparks", "")
				end
			},
			toggle = {
				type = "execute",
				order = 1,
				name = "Toggle Display",
				desc = "Shows/hides the display frame (also available in game keybindings)",
				func = function() AngrySparks_ToggleDisplay() end
			},
			deleteall = {
				type = "execute",
				name = "Delete All Pages",
				desc = "Deletes all pages",
				order = 4,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					AngrySparks_State.displayed = nil
					AngrySparks_Pages = {}
					AngrySparks_Categories = {}
					self:UpdateTree()
					self:UpdateSelected()
					self:UpdateDisplayed()
					if self.window then self.window.tree:SetSelected(nil) end
					self:Print("All pages have been deleted.")
				end
			},
			defaults = {
				type = "execute",
				name = "Restore Defaults",
				desc = "Restore configuration values to their default settings",
				order = 10,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					self:RestoreDefaults()
				end
			},
			output = {
				type = "execute",
				name = "Output",
				desc = "Outputs currently displayed assignents to chat",
				order = 11,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					self:OutputDisplayed()
				end
			},
			send = {
				type = "input",
				name = "Send and Display",
				desc = "Sends page with specified name",
				order = 12,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				get = function(info) return "" end,
				set = function(info, val)
					local result = self:DisplayPageByName(val:trim())
					if result == false then
						self:Print(RED_FONT_COLOR_CODE ..
							"A page with the name \"" .. val:trim() .. "\" could not be found.|r")
					elseif not result then
						self:Print(RED_FONT_COLOR_CODE .. "You don't have permission to send a page.|r")
					end
				end
			},
			clear = {
				type = "execute",
				name = "Clear",
				desc = "Clears currently displayed page",
				order = 13,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					AngrySparks_ClearPage()
				end
			},
			backup = {
				type = "execute",
				order = 20,
				name = "Backup Pages",
				desc = "Creates a backup of all pages with their current contents",
				func = function()
					self:CreateBackup()
					self:Print("Created a backup of all pages.")
				end
			},
			resetposition = {
				type = "execute",
				order = 22,
				name = "Reset Position",
				desc = "Resets position for the assignment display",
				func = function()
					self:ResetPosition()
				end
			},
			version = {
				type = "execute",
				order = 21,
				name = "Version Check",
				desc = "Displays a list of all users (in the raid) running the addon and the version they're running",
				func = function()
					if (IsInRaid() or IsInGroup()) then
						versionList = {} -- start with a fresh version list, when displaying it
						self:SendOutMessage({ "VER_QUERY" })
						self:ScheduleTimer("VersionCheckOutput", updateThrottle)
						self:Print("Version check running...")
					else
						self:Print("You must be in a raid group to run the version check.")
					end
				end
			},
			lock = {
				type = "execute",
				order = 2,
				name = "Toggle Lock",
				desc = "Shows/hides the display mover (also available in game keybindings)",
				func = function() self:ToggleLock() end
			},
			config = {
				type = "group",
				order = 5,
				name = "General",
				inline = true,
				args = {
					highlight = {
						type = "input",
						order = 1,
						name = "Highlight",
						desc =
						"A list of words to highlight on displayed pages (separated by spaces or punctuation)\n\nUse 'Group' to highlight the current group you are in, ex. G2",
						get = function(info) return self:GetConfig('highlight') end,
						set = function(info, val)
							self:SetConfig('highlight', val)
							self:UpdateDisplayed()
						end
					},
					hideoncombat = {
						type = "toggle",
						order = 3,
						name = "Hide on Combat",
						desc = "Enable to hide display frame upon entering combat",
						get = function(info) return self:GetConfig('hideoncombat') end,
						set = function(info, val)
							self:SetConfig('hideoncombat', val)
						end
					},
					scale = {
						type = "range",
						order = 4,
						name = "Scale",
						desc = "Sets the scale of the edit window",
						min = 0.3,
						max = 3,
						get = function(info) return self:GetConfig('scale') end,
						set = function(info, val)
							self:SetConfig('scale', val)
							if AngrySparks.window then AngrySparks.window.frame:SetScale(val) end
						end
					},
					backdrop = {
						type = "toggle",
						order = 5,
						name = "Display Backdrop",
						desc = "Enable to display a backdrop behind the assignment display",
						get = function(info) return self:GetConfig('backdropShow') end,
						set = function(info, val)
							self:SetConfig('backdropShow', val)
							self:SyncTextSizeFrames()
						end
					},
					backdropcolor = {
						type = "color",
						order = 6,
						name = "Backdrop Color",
						desc = "The color used by the backdrop",
						hasAlpha = true,
						get = function(info)
							local hex = self:GetConfig('backdropColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b, a)
							self:SetConfig('backdropColor', RGBToHex(r, g, b, a))
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					updatecolor = {
						type = "color",
						order = 7,
						name = "Update Notification Color",
						desc = "The color used by the update notification glow",
						get = function(info)
							local hex = self:GetConfig('glowColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('glowColor', RGBToHex(r, g, b))
							self.display_glow:SetVertexColor(r, g, b)
							self.display_glow2:SetVertexColor(r, g, b)
						end
					}
				}
			},
			font = {
				type = "group",
				order = 6,
				name = "Font",
				inline = true,
				args = {
					fontname = {
						type = 'select',
						order = 1,
						dialogControl = 'LSM30_Font',
						name = 'Face',
						desc = 'Sets the font face used to display a page',
						values = LSM:HashTable("font"),
						get = function(info) return self:GetConfig('fontName') end,
						set = function(info, val)
							self:SetConfig('fontName', val)
							self:UpdateMedia()
						end
					},
					fontheight = {
						type = "range",
						order = 2,
						name = "Size",
						desc = function()
							return "Sets the font height used to display a page"
						end,
						min = 6,
						max = 24,
						step = 1,
						get = function(info) return self:GetConfig('fontHeight') end,
						set = function(info, val)
							self:SetConfig('fontHeight', val)
							self:UpdateMedia()
						end
					},
					fontflags = {
						type = "select",
						order = 3,
						name = "Outline",
						desc = "Sets the font outline used to display a page",
						values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROMEOUTLINE"] = "Monochrome" },
						get = function(info) return self:GetConfig('fontFlags') end,
						set = function(info, val)
							self:SetConfig('fontFlags', val)
							self:UpdateMedia()
						end
					},
					color = {
						type = "color",
						order = 4,
						name = "Normal Color",
						desc = "The normal color used to display assignments",
						get = function(info)
							local hex = self:GetConfig('color')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('color', RGBToHex(r, g, b))
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					highlightcolor = {
						type = "color",
						order = 5,
						name = "Highlight Color",
						desc = "The color used to emphasize highlighted words",
						get = function(info)
							local hex = self:GetConfig('highlightColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('highlightColor', RGBToHex(r, g, b))
							self:UpdateDisplayed()
						end
					},
					linespacing = {
						type = "range",
						order = 6,
						name = "Line Spacing",
						desc = function()
							return "Sets the line spacing used to display a page"
						end,
						min = 0,
						max = 10,
						step = 1,
						get = function(info) return self:GetConfig('lineSpacing') end,
						set = function(info, val)
							self:SetConfig('lineSpacing', val)
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					editBoxFont = {
						type = "toggle",
						order = 7,
						name = "Change Edit Box Font",
						desc = "Enable to set edit box font to display font",
						get = function(info) return self:GetConfig('editBoxFont') end,
						set = function(info, val)
							self:SetConfig('editBoxFont', val)
							self:UpdateMedia()
						end
					},
				}
			},
			permissions = {
				type = "group",
				order = 7,
				name = "Permissions",
				inline = true,
				args = {
					allowall = {
						type = "toggle",
						order = 1,
						name = "Allow All",
						desc = "Enable to allow changes from any raid assistant, even if you aren't in a guild raid",
						get = function(info) return self:GetConfig('allowall') end,
						set = function(info, val)
							self:SetConfig('allowall', val)
							self:PermissionsUpdated()
						end
					},
					allowplayers = {
						type = "input",
						order = 2,
						name = "Allow Players",
						desc =
						"A list of players that when they are the raid leader to allow changes from all raid assistants",
						get = function(info) return self:GetConfig('allowplayers') end,
						set = function(info, val)
							self:SetConfig('allowplayers', val)
							self:PermissionsUpdated()
						end
					},
				}
			}
		}
	}

	self:RegisterChatCommand("aa", "ChatCommand")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("AngrySparks", options)

	blizOptionsPanel = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AngrySparks", "Angry Sparks")
	blizOptionsPanel.default = function() self:RestoreDefaults() end
end

function AngrySparks:ChatCommand(input)
	if not input or input:trim() == "" then
		Settings.OpenToCategory(blizOptionsPanel)
		-- Settings.OpenToCategory(blizOptionsPanel)
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(self, "aa", "AngrySparks", input)
	end
end

function AngrySparks:OnEnable()
	self:CreateDisplay()

	self:ScheduleTimer("AfterEnable", 4)

	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")

	GuildRoster()

	LSM.RegisterCallback(self, "LibSharedMedia_Registered", "UpdateMedia")
	LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", "UpdateMedia")
end

function AngrySparks:PARTY_LEADER_CHANGED()
	self:PermissionsUpdated()
	if AngrySparks_State.displayed and not self:IsValidRaid() then
		self:ClearDisplayed()
	end
end

function AngrySparks:GROUP_JOINED()
	self:SendVerQuery()
	self:UpdateDisplayedIfNewGroup()
	self:ScheduleTimer("SendRequestDisplay", 0.5)
end

function AngrySparks:PLAYER_REGEN_DISABLED()
	if AngrySparks:GetConfig('hideoncombat') then
		self:HideDisplay()
	end
end

function AngrySparks:GROUP_ROSTER_UPDATE()
	self:UpdateSelected()
	if not (IsInRaid() or IsInGroup()) then
		if AngrySparks_State.displayed then
			self:ClearDisplayed()
		end
		currentGroup = nil
		warnedPermission = false
	else
		self:UpdateDisplayedIfNewGroup()
	end
end

function AngrySparks:PLAYER_GUILD_UPDATE()
	self:PermissionsUpdated()
end

function AngrySparks:GUILD_ROSTER_UPDATE(...)
	local canRequestRosterUpdate = ...
	if canRequestRosterUpdate then
		GuildRoster()
	end
end

function AngrySparks:AfterEnable()
	self:RegisterComm(comPrefix, "ReceiveMessage")
	comStarted = true

	if not (IsInRaid() or IsInGroup()) then
		self:ClearDisplayed()
	end

	self:RegisterEvent("PARTY_LEADER_CHANGED")
	self:RegisterEvent("GROUP_JOINED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	self:SendRequestDisplay()
	self:UpdateDisplayedIfNewGroup()
	self:SendVerQuery()
end
