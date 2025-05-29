-- local _TOC, VERSION, DATE = ...

---@class CommModule
---@field CURSEFORGE_URL string
---@field AngrySparks_Version string
---@field AngrySparks_Timestamp string
---@field warnedOOD boolean Warned out of date
---@field versionList table<string, {valid: boolean, version: string}>
---@field protocolVersion number
---@field comPrefix string Registered in AceComm as that prefix
---@field pageLastUpdate table<number, number>
---@field pageTimerId table<number, AceTimerObj>
---@field displayLastUpdate number
---@field displayTimerId AceTimerObj|nil Scheduled timer id to send display message
---@field versionLastUpdate number
---@field versionTimerId AceTimerObj|nil Scheduled timer id to send version message
---@field updateThrottle number
local commModule = LibStub("AngrySparks-Comm") ---@type CommModule
commModule.CURSEFORGE_URL = "https://legacy.curseforge.com/wow/addons/angry-sparks"
commModule.AngrySparks_Version = "@version"
commModule.AngrySparks_Timestamp = "@date"
commModule.warnedOOD = false
commModule.versionList = {}
commModule.protocolVersion = 100
commModule.comPrefix = "Sparks" .. commModule.protocolVersion .. "!!"
commModule.pageLastUpdate = {}
commModule.pageTimerId = {}
commModule.displayLastUpdate = nil
commModule.displayTimerId = nil
commModule.versionLastUpdate = nil
commModule.versionTimerId = nil
local updateThrottle = 4

local coreModule = LibStub("AngrySparks-Core") ---@type CoreModule
local utilsModule = LibStub("AngrySparks-Utils") ---@type UtilsModule

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

---Constants for dealing with our addon communication
---@class Protocol
---@field COMMAND number
---@field PAGE_Id number
---@field PAGE_Updated number
---@field PAGE_Name number
---@field PAGE_Contents number
---@field PAGE_UpdateId number
---@field PAGE_Variables number
---@field REQUEST_PAGE_Id number
---@field DISPLAY_Id number
---@field DISPLAY_Updated number
---@field DISPLAY_UpdateId number
---@field VERSION_Version number
---@field VERSION_Timestamp number
---@field VERSION_ValidRaid number
local protocol = {
    COMMAND = 1,
    PAGE_Id = 2,
    PAGE_Updated = 3,
    PAGE_Name = 4,
    PAGE_Contents = 5,
    PAGE_UpdateId = 6,
    PAGE_Variables = 7,

    REQUEST_PAGE_Id = 2,

    DISPLAY_Id = 2,
    DISPLAY_Updated = 3,
    DISPLAY_UpdateId = 4,

    VERSION_Version = 2,
    VERSION_Timestamp = 3,
    VERSION_ValidRaid = 4,
}

function commModule:ProcessMessage(sender, data)
    local cmd = data[COMMAND]
    sender = utilsModule:EnsureUnitFullName(sender)

    local addon = coreModule.addon

    if cmd == "PAGE" then
        if sender == utilsModule:PlayerFullName() then return end
        if not addon:PermissionCheck(sender) then
            addon:PermissionCheckFailError(sender)
            return
        end

        local contents_updated = true
        local id = data[protocol.PAGE_Id]
        local page = AngrySparks_Pages[id]
        if page then
            if data[protocol.PAGE_UpdateId]
                and page.UpdateId == data[protocol.PAGE_UpdateId] then
                -- The version received is same as the one we already have
                return
            end

            contents_updated = page.Contents ~= data[protocol.PAGE_Contents]

            AngrySparks_Variables = data[protocol.PAGE_Variables]

            page.Name = data[protocol.PAGE_Name]
            page.Contents = data[protocol.PAGE_Contents]
            page.Updated = data[protocol.PAGE_Updated]
            page.UpdateId = data[protocol.PAGE_UpdateId] or
                addon:Hash(page.Name, page.Contents, addon:SerializeVariables())

            if addon:SelectedId() == id then
                addon:SelectedUpdated(sender)
                addon:UpdateSelected()
            end
        else
            AngrySparks_Pages[id] = {
                Id = id,
                Updated = data[protocol.PAGE_Updated],
                UpdateId = data[protocol.PAGE_UpdateId],
                Name = data[protocol.PAGE_Name],
                Contents = data[protocol.PAGE_Contents]
            }
            AngrySparks_Variables = data[protocol.PAGE_Variables]
        end

        if AngrySparks_State.displayed == id then
            coreModule:UpdateDisplayed()
            addon:ShowDisplay()
            if contents_updated then addon:DisplayUpdateNotification() end
        end

        addon:UpdateTree()
        --
    elseif cmd == "DISPLAY" then
        if sender == utilsModule:PlayerFullName() then return end
        if not addon:PermissionCheck(sender) then
            if data[protocol.DISPLAY_Id] then addon:PermissionCheckFailError(sender) end
            return
        end

        local id = data[protocol.DISPLAY_Id]
        local updated = data[protocol.DISPLAY_Updated]
        local updateId = data[protocol.DISPLAY_UpdateId]
        local page = AngrySparks_Pages[id]
        local sameVersion = (updateId and page and updateId == page.UpdateId) or
            (not updateId and page and updated == page.Updated)
        if id and not sameVersion then
            self:SendRequestPage(id, sender)
        end

        if AngrySparks_State.displayed ~= id then
            AngrySparks_State.displayed = id
            addon:UpdateTree()
            coreModule:UpdateDisplayed()
            addon:ShowDisplay()
            if id then addon:DisplayUpdateNotification() end
        end
    elseif cmd == "REQUEST_DISPLAY" then
        if sender == utilsModule:PlayerFullName() then return end
        if not addon:IsPlayerRaidLeader() then return end

        self:SendDisplay(AngrySparks_State.displayed)
    elseif cmd == "REQUEST_PAGE" then
        if sender == utilsModule:PlayerFullName() then return end

        self:SendPage(data[protocol.REQUEST_PAGE_Id])
    elseif cmd == "VER_QUERY" then
        self:SendVersion(false)
    elseif cmd == "VERSION" then
        local localTimestamp, ver, timestamp

        if self.AngrySparks_Timestamp:sub(1, 1) == "@" then
            localTimestamp = "dev"
        else
            localTimestamp = tonumber(self.AngrySparks_Timestamp)
        end
        ver = data[protocol.VERSION_Version]
        timestamp = data[protocol.VERSION_Timestamp]

        local localStr = tostring(localTimestamp)
        local remoteStr = tostring(timestamp)

        if (localStr ~= "dev" and localStr:len() ~= 14) or (remoteStr ~= "dev" and remoteStr:len() ~= 14) then
            if localStr ~= "dev" then localTimestamp = tonumber(localStr:sub(1, 8)) end
            if remoteStr ~= "dev" then timestamp = tonumber(remoteStr:sub(1, 8)) end
        end

        if localTimestamp ~= "dev"
            and timestamp ~= "dev"
            and timestamp > localTimestamp
            and not self.warnedOOD
        then
            addon:Print("Your version of Angry Sparks is out of date! Download the latest from "
                .. self.CURSEFORGE_URL)
            self.warnedOOD = true
        end

        self.versionList[sender] = { valid = data[protocol.VERSION_ValidRaid], version = ver }
    end
end

function commModule:ReceiveMessage(prefix, data, channel, sender)
    if prefix ~= self.comPrefix then return end

    local decoded = LibDeflate:DecodeForWoWAddonChannel(data)
    if not decoded then return end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end
    local success, final = LibSerialize:Deserialize(decompressed)
    if not success then return end

    self:ProcessMessage(sender, final)
end

function commModule:SendOutMessage(data, channel, target)
    local addon = coreModule.addon
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

    addon:SendCommMessage(self.comPrefix, encoded, channel, target, "BULK")
    return true
end

function commModule:SendPage(id, force)
    local lastUpdate = self.pageLastUpdate[id]
    local timerId = self.pageTimerId[id]
    local curTime = time()
    local addon = coreModule.addon

    if lastUpdate and (curTime - lastUpdate <= self.updateThrottle) then
        if not timerId then
            if force then
                self:SendPageMessage(id)
            else
                self.pageTimerId[id] = addon:ScheduleTimer(
                    "SendPageMessage",
                    updateThrottle - (curTime - lastUpdate),
                    id
                )
            end
        elseif force then
            addon:CancelTimer(timerId)
            self:SendPageMessage(id)
        end
    else
        self:SendPageMessage(id)
    end
end

function commModule:SendPageMessage(id)
    self.pageLastUpdate[id] = time()
    self.pageTimerId[id] = nil

    local page = AngrySparks_Pages[id]
    if not page then
        error("Can't send page, does not exist"); return
    end

    if not page.UpdateId then
        local addon = coreModule.addon
        page.UpdateId = addon:Hash(page.Name, page.Contents, addon:SerializeVariables())
    end

    self:SendOutMessage({
        "PAGE",
        [protocol.PAGE_Id] = page.Id,
        [protocol.PAGE_Updated] = page.Updated,
        [protocol.PAGE_Name] = page.Name,
        [protocol.PAGE_Contents] = page.Contents,
        [protocol.PAGE_UpdateId] = page.UpdateId,
        [protocol.PAGE_Variables] = AngrySparks_Variables
    })
end

function commModule:SendDisplay(id, force)
    local curTime = time()
    local addon = coreModule.addon

    if self.displayLastUpdate and (curTime - self.displayLastUpdate <= self.updateThrottle) then
        if not self.displayTimerId then
            if force then
                self:SendDisplayMessage(id)
            else
                self.displayTimerId = addon:ScheduleTimer(
                    "SendDisplayMessage",
                    self.updateThrottle - (curTime - self.displayLastUpdate),
                    id
                )
            end
        elseif force then
            addon:CancelTimer(self.displayTimerId)
            self:SendDisplayMessage(id)
        end
    else
        self:SendDisplayMessage(id)
    end
end

function commModule:SendDisplayMessage(id)
    self.displayLastUpdate = time()
    self.displayTimerId = nil

    local page = AngrySparks_Pages[id]
    local addon = coreModule.addon

    if not page then
        self:SendOutMessage({
            "DISPLAY",
            [protocol.DISPLAY_Id] = nil,
            [protocol.DISPLAY_Updated] = nil,
            [protocol.DISPLAY_UpdateId] = nil
        })
    else
        if not page.UpdateId then
            addon:RehashPage(id)
        end
        self:SendOutMessage({
            "DISPLAY",
            [protocol.DISPLAY_Id] = page.Id,
            [protocol.DISPLAY_Updated] = page.Updated,
            [protocol.DISPLAY_UpdateId] = page.UpdateId
        })
    end
end

function commModule:SendRequestDisplay()
    if (IsInRaid() or IsInGroup()) then
        local addon = coreModule.addon
        local to = addon:GetRaidLeader(true)
        if to then self:SendOutMessage({ "REQUEST_DISPLAY" }, "WHISPER", to) end
    end
end

---@param force boolean
function commModule:SendVersion(force)
    local curTime = time()
    local addon = coreModule.addon

    if self.versionLastUpdate and (curTime - self.versionLastUpdate <= self.updateThrottle) then
        if not self.versionTimerId then
            if force then
                self:SendVersionMessage(id) -- id is not used
            else
                self.versionTimerId = addon:ScheduleTimer(
                    "SendVersionMessage",
                    self.updateThrottle - (curTime - self.versionLastUpdate),
                    id -- id is not used and not defined
                )
            end
        elseif force then
            addon:CancelTimer(self.versionTimerId)
            self:SendVersionMessage()
        end
    else
        self:SendVersionMessage()
    end
end

function commModule:SendVersionMessage()
    self.versionLastUpdate = time()
    self.versionTimerId = nil

    -- local revToSend
    local timestampToSend
    local verToSend
    if self.AngrySparks_Version:sub(1, 1) == "@" then
        verToSend = "dev"
    else
        verToSend = self.AngrySparks_Version
    end
    if self.AngrySparks_Timestamp:sub(1, 1) == "@" then
        timestampToSend = "dev"
    else
        timestampToSend = tonumber(self.AngrySparks_Timestamp)
    end

    local addon = coreModule.addon
    self:SendOutMessage({
        "VERSION",
        [protocol.VERSION_Version] = verToSend,
        [protocol.VERSION_Timestamp] = timestampToSend,
        [protocol.VERSION_ValidRaid] = addon:IsValidRaid()
    })
end

function commModule:SendVerQuery()
    self:SendOutMessage({ "VER_QUERY" })
end

function commModule:SendRequestPage(id, to)
    if (IsInRaid() or IsInGroup()) or to then
        local addon = coreModule.addon
        if not to then to = addon:GetRaidLeader(true) end
        if to then
            self:SendOutMessage({
                "REQUEST_PAGE",
                [protocol.REQUEST_PAGE_Id] = id
            }, "WHISPER", to)
        end
    end
end

function commModule:VersionCheckOutput()
	local missing_addon = {}
	local invalid_raid = {}
	local different_version = {}
	local up_to_date = {}

	local ver = self.AngrySparks_Version
	if ver:sub(1, 1) == "@" then ver = "dev" end

	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
			local fullname = utilsModule:EnsureUnitFullName(name)
			if online then
				if not self.versionList[fullname] then
					tinsert(missing_addon, name)
				elseif self.versionList[fullname].valid == false or self.versionList[fullname].valid == nil then
					tinsert(invalid_raid, name)
				elseif ver ~= self.versionList[fullname].version then
					tinsert(different_version, string.format("%s - %s", name, self.versionList[fullname].version))
				else
					tinsert(up_to_date, name)
				end
			end
		end
	end

    local addon = coreModule.addon
	addon:Print("Version check results:")

	if #up_to_date > 0 then
		addon:Print(LIGHTYELLOW_FONT_COLOR_CODE .. "Same version:|r " .. table.concat(up_to_date, ", "))
	end

	if #different_version > 0 then
		addon:Print(LIGHTYELLOW_FONT_COLOR_CODE .. "Different version:|r " .. table.concat(different_version, ", "))
	end

	if #invalid_raid > 0 then
		addon:Print(LIGHTYELLOW_FONT_COLOR_CODE .. "Not allowing changes:|r " .. table.concat(invalid_raid, ", "))
	end

	if #missing_addon > 0 then
		addon:Print(LIGHTYELLOW_FONT_COLOR_CODE .. "Missing addon:|r " .. table.concat(missing_addon, ", "))
	end
end
