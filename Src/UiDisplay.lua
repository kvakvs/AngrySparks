---@class UiDisplayModule
local uiDisplayModule = LibStub("AngrySparks-Ui-Display") --[[@as UiDisplayModule]]
local coreModule = LibStub("AngrySparks-Core") --[[@as CoreModule]]
local utilsModule = LibStub("AngrySparks-Utils") --[[@as UtilsModule]]
local configModule = LibStub("AngrySparks-Config") --[[@as ConfigModule]]

local lwin = LibStub("LibWindow-1.1")
local LSM = LibStub("LibSharedMedia-3.0")

local function DragHandle_MouseDown(frame) frame:GetParent():GetParent():StartSizing("RIGHT") end
local function DragHandle_MouseUp(frame)
    local addon = coreModule.addon
	local display = frame:GetParent():GetParent()
	display:StopMovingOrSizing()
	AngrySparks_State.display.width = display:GetWidth()
	lwin.SavePosition(display)
	addon:SyncTextSizeFrames()
end

local function Mover_MouseDown(frame) frame:GetParent():StartMoving() end
local function Mover_MouseUp(frame)
	local display = frame:GetParent()
	display:StopMovingOrSizing()
	lwin.SavePosition(display)
end

function uiDisplayModule:CreateDisplay()
    local addon = coreModule.addon

	local frame = CreateFrame("Frame", "AngrySp", UIParent)
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
	addon.frame = frame

	lwin.RegisterConfig(frame, AngrySparks_State.display)
	lwin.RestorePosition(frame)

	local text = CreateFrame("ScrollingMessageFrame", "AngrySpScrollingMessage", frame)
	text:SetIndentedWordWrap(true)
	text:SetJustifyH("LEFT")
	text:SetFading(false)
	text:SetMaxLines(70)
	text:SetHeight(700)
	text:SetHyperlinksEnabled(false)
	addon.display_text = text

	local backdrop = text:CreateTexture()
	backdrop:SetDrawLayer("BACKGROUND")
	addon.backdrop = backdrop

	local clickOverlay = CreateFrame("Frame", "AngrySpClickOverlay", text)
	clickOverlay:SetAllPoints(text)
	clickOverlay:SetScript("OnMouseDown", function(_, button)
		local direction
		if button == "LeftButton" then
			direction = "forward"
		else
			direction = "backward"
		end
		addon:Paginate(direction)
	end)
	addon.clickOverlay = clickOverlay

	local pagination = CreateFrame("Frame", "AngrySpPagination", clickOverlay)
	pagination:SetPoint("TOPRIGHT", -4, -4)
	pagination:SetHeight(1)
	pagination:SetWidth(1)
	addon.pagination = pagination

	local paginationText = pagination:CreateFontString()
	local fontName = LSM:Fetch("font", configModule:GetConfig('fontName') --[[@as string]])
	local fontHeight = configModule:GetConfig('fontHeight')
	local fontFlags = configModule:GetConfig('fontFlags')

	paginationText:SetTextColor(utilsModule:HexToRGB(configModule:GetConfig('color')))
	paginationText:SetFont(fontName, fontHeight, fontFlags)
	paginationText:SetPoint("TOPRIGHT")
	addon.paginationText = paginationText

	local mover = CreateFrame("Frame", "AngrySpMover", frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mover:SetFrameLevel(clickOverlay:GetFrameLevel() + 10)
	mover:SetPoint("LEFT", 0, 0)
	mover:SetPoint("RIGHT", 0, 0)
	mover:SetHeight(16)
	mover:EnableMouse(true)
	mover:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	mover:SetBackdropColor(0.616, 0.149, 0.114, 0.9)
	mover:SetScript("OnMouseDown", Mover_MouseDown)
	mover:SetScript("OnMouseUp", Mover_MouseUp)
	addon.mover = mover
	if AngrySparks_State.locked then mover:Hide() end

	local label = mover:CreateFontString()
	label:SetFontObject("GameFontNormal")
	label:SetJustifyH("CENTER")
	label:SetPoint("LEFT", 38, 0)
	label:SetPoint("RIGHT", -38, 0)
	label:SetText("Angry Sparks")

	local direction = CreateFrame("Button", "AngrySpDirection", mover)
	direction:SetPoint("LEFT", 2, 0)
	direction:SetWidth(16)
	direction:SetHeight(16)
	direction:SetNormalTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetPushedTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	direction:SetScript("OnClick", function() addon:ToggleDirection() end)
	addon.direction_button = direction

	local lock = CreateFrame("Button", "AngrySpLock", mover)
	lock:SetNormalTexture("Interface\\LFGFRAME\\UI-LFG-ICON-LOCK")
	lock:GetNormalTexture():SetTexCoord(0, 0.71875, 0, 0.875)
	lock:SetPoint("LEFT", direction, "RIGHT", 4, 0)
	lock:SetWidth(12)
	lock:SetHeight(14)
	lock:SetScript("OnClick", function() addon:ToggleLock() end)

	local drag = CreateFrame("Frame", "AngrySpDrag", mover)
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
	glow:SetVertexColor(utilsModule:HexToRGB(configModule:GetConfig('glowColor')))
	glow:SetAlpha(0)
	addon.display_glow = glow

	local glow2 = text:CreateTexture()
	glow2:SetDrawLayer("BORDER")
	glow2:SetTexture("Interface\\AddOns\\AngryGirls\\Textures\\LevelUpTex")
	glow2:SetSize(418, 7)
	glow2:SetTexCoord(0.00195313, 0.81835938, 0.01953125, 0.03320313)
	glow2:SetVertexColor(utilsModule:HexToRGB(configModule:GetConfig('glowColor')))
	glow2:SetAlpha(0)
	addon.display_glow2 = glow2

	if AngrySparks_State.display.hidden then text:Hide() end
	coreModule:UpdateMedia()
	coreModule:UpdateDirection()
end
