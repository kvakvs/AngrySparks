---@class EventsModule
local eventsModule = LibStub("AngrySparks-Events")

local coreModule = LibStub("AngrySparks-Core")
local configModule = LibStub("AngrySparks-Config")
local commModule = LibStub("AngrySparks-Comm")

function eventsModule:OnEnableAddon()
	local addon = coreModule.addon

    addon:RegisterEvent("PLAYER_REGEN_DISABLED", eventsModule.PLAYER_REGEN_DISABLED)
	addon:RegisterEvent("PLAYER_GUILD_UPDATE", eventsModule.PLAYER_GUILD_UPDATE)
	addon:RegisterEvent("GUILD_ROSTER_UPDATE", eventsModule.GUILD_ROSTER_UPDATE)
end

function eventsModule:AfterEnableAddon()
	local addon = coreModule.addon

    addon:RegisterEvent("PARTY_LEADER_CHANGED", eventsModule.PARTY_LEADER_CHANGED)
	addon:RegisterEvent("GROUP_JOINED", eventsModule.GROUP_JOINED)
	addon:RegisterEvent("GROUP_ROSTER_UPDATE", eventsModule.GROUP_ROSTER_UPDATE)
end

function eventsModule:PLAYER_REGEN_DISABLED()
    local addon = coreModule.addon

	if configModule:GetConfig('hideoncombat') then
		addon:HideDisplay()
	end
end

function eventsModule:PLAYER_GUILD_UPDATE()
	local addon = coreModule.addon

	addon:PermissionsUpdated()
end

function eventsModule:GUILD_ROSTER_UPDATE(...)
	local canRequestRosterUpdate = ...

    if canRequestRosterUpdate then
		C_GuildInfo.GuildRoster()
	end
end

function eventsModule:GROUP_ROSTER_UPDATE()
	local addon = coreModule.addon

	addon:UpdateSelected()
	if not (IsInRaid() or IsInGroup()) then
		if addon.displayed then
			addon:ClearDisplayed()
		end
		coreModule.currentGroup = nil
		coreModule.warnedPermission = false
	else
		addon:UpdateDisplayedIfNewGroup()
	end
end

function eventsModule:GROUP_JOINED()
	local addon = coreModule.addon

	commModule:SendVerQuery()
	addon:UpdateDisplayedIfNewGroup()
	addon:ScheduleTimer(function() commModule:SendRequestDisplay() end, 0.5)
end

function eventsModule:PARTY_LEADER_CHANGED()
	local addon = coreModule.addon

	addon:PermissionsUpdated()
	if addon.displayed and not addon:IsValidRaid() then
		addon:ClearDisplayed()
	end
end
