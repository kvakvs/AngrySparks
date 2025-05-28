---@class ConfigModule
local configModule = LibStub("AngrySparks-Config") --[[@as ConfigModule]]
local coreModule = LibStub("AngrySparks-Core") --[[@as CoreModule]]

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

function configModule:GetConfig(key)
	if AngrySparks_Config[key] == nil then
		return configDefaults[key]
	else
		return AngrySparks_Config[key]
	end
end

function configModule:SetConfig(key, value)
	if configDefaults[key] == value then
		AngrySparks_Config[key] = nil
	else
		AngrySparks_Config[key] = value
	end
end

function configModule:RestoreDefaults()
	AngrySparks_Config = {}
	coreModule:UpdateMedia()
	coreModule:UpdateDisplayed()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("AngrySparks")
end
