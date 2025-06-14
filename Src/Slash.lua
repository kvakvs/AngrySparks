---@class SlashModule
local slashModule = LibStub("AngrySparks-Slash")

local coreModule = LibStub("AngrySparks-Core")
local commModule = LibStub("AngrySparks-Comm")
local configModule = LibStub("AngrySparks-Config")
local utilsModule = LibStub("AngrySparks-Utils")
local pagesModule = LibStub("AngrySparks-Pages")

local LSM = LibStub("LibSharedMedia-3.0")

local slashCommand = "as"

function slashModule:ConfigCommandGroup()
    local addon = coreModule.addon
    local configHighlightCommand = {
        type = "input",
        order = 1,
        name = "Highlight",
        desc = "A list of words to highlight on displayed pages (separated by spaces or punctuation)\n\n"
            .. "Use 'Group' to highlight the current group you are in, ex. G2",
        get = function(info) return configModule:GetConfig('highlight') end,
        set = function(info, val)
            configModule:SetConfig('highlight', val)
            coreModule:UpdateDisplayed()
        end
    }
    local configHideOnCombatCommand = {
        type = "toggle",
        order = 3,
        name = "Hide on Combat",
        desc = "Enable to hide display frame upon entering combat",
        get = function(info) return configModule:GetConfig('hideoncombat') end,
        set = function(info, val) configModule:SetConfig('hideoncombat', val) end
    }
    local configScaleCommand = {
        type = "range",
        order = 4,
        name = "Scale",
        desc = "Sets the scale of the edit window",
        min = 0.3,
        max = 3,
        get = function(info) return configModule:GetConfig('scale') end,
        set = function(info, val)
            configModule:SetConfig('scale', val)
            if addon.window then addon.window.frame:SetScale(val) end
        end
    }
    local configBackdropCommand = {
        type = "toggle",
        order = 5,
        name = "Display Backdrop",
        desc = "Enable to display a backdrop behind the assignment display",
        get = function(info) return configModule:GetConfig('backdropShow') end,
        set = function(info, val)
            configModule:SetConfig('backdropShow', val)
            addon:SyncTextSizeFrames()
        end
    }
    local configBackdropColorCommand = {
        type = "color",
        order = 6,
        name = "Backdrop Color",
        desc = "The color used by the backdrop",
        hasAlpha = true,
        get = function(info)
            local hex = configModule:GetConfig('backdropColor')
            return utilsModule:HexToRGB(hex)
        end,
        set = function(info, r, g, b, a)
            configModule:SetConfig('backdropColor', utilsModule:RGBToHex(r, g, b, a))
            coreModule:UpdateMedia()
            coreModule:UpdateDisplayed()
        end
    }
    local configUpdateColorCommand = {
        type = "color",
        order = 7,
        name = "Update Notification Color",
        desc = "The color used by the update notification glow",
        get = function(info)
            local hex = configModule:GetConfig('glowColor')
            return utilsModule:HexToRGB(hex)
        end,
        set = function(info, r, g, b)
            configModule:SetConfig('glowColor', utilsModule:RGBToHex(r, g, b))
            addon.display_glow:SetVertexColor(r, g, b)
            addon.display_glow2:SetVertexColor(r, g, b)
        end
    }

    return {
        type = "group",
        order = 5,
        name = "General",
        inline = true,
        args = {
            highlight = configHighlightCommand,
            hideoncombat = configHideOnCombatCommand,
            scale = configScaleCommand,
            backdrop = configBackdropCommand,
            backdropcolor = configBackdropColorCommand,
            updatecolor = configUpdateColorCommand,
        }
    }
end

function slashModule:FontCommandGroup()
    local addon = coreModule.addon

    local fontFontnameCommand = {
        type = 'select',
        order = 1,
        dialogControl = 'LSM30_Font',
        name = 'Face',
        desc = 'Sets the font face used to display a page',
        values = LSM:HashTable("font"),
        get = function(info) return configModule:GetConfig('fontName') end,
        set = function(info, val)
            configModule:SetConfig('fontName', val)
            coreModule:UpdateMedia()
        end
    }
    local fontFontHeightCommand = {
        type = "range",
        order = 2,
        name = "Size",
        desc = function()
            return "Sets the font height used to display a page"
        end,
        min = 6,
        max = 24,
        step = 1,
        get = function(info) return configModule:GetConfig('fontHeight') end,
        set = function(info, val)
            configModule:SetConfig('fontHeight', val)
            coreModule:UpdateMedia()
        end
    }
    local fontFontFlagsCommand = {
        type = "select",
        order = 3,
        name = "Outline",
        desc = "Sets the font outline used to display a page",
        values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROMEOUTLINE"] = "Monochrome" },
        get = function(info) return configModule:GetConfig('fontFlags') end,
        set = function(info, val)
            configModule:SetConfig('fontFlags', val)
            coreModule:UpdateMedia()
        end
    }
    local fontColorCommand = {
        type = "color",
        order = 4,
        name = "Normal Color",
        desc = "The normal color used to display assignments",
        get = function(info)
            local hex = configModule:GetConfig('color')
            return utilsModule:HexToRGB(hex)
        end,
        set = function(info, r, g, b)
            configModule:SetConfig('color', utilsModule:RGBToHex(r, g, b))
            coreModule:UpdateMedia()
            coreModule:UpdateDisplayed()
        end
    }
    local fontHighlightColorCommand = {
        type = "color",
        order = 5,
        name = "Highlight Color",
        desc = "The color used to emphasize highlighted words",
        get = function(info)
            local hex = configModule:GetConfig('highlightColor')
            return utilsModule:HexToRGB(hex)
        end,
        set = function(info, r, g, b)
            configModule:SetConfig('highlightColor', utilsModule:RGBToHex(r, g, b))
            coreModule:UpdateDisplayed()
        end
    }
    local fontLineSpacingCommand = {
        type = "range",
        order = 6,
        name = "Line Spacing",
        desc = function()
            return "Sets the line spacing used to display a page"
        end,
        min = 0,
        max = 10,
        step = 1,
        get = function(info) return configModule:GetConfig('lineSpacing') end,
        set = function(info, val)
            configModule:SetConfig('lineSpacing', val)
            coreModule:UpdateMedia()
            coreModule:UpdateDisplayed()
        end
    }
    local fontEditBoxFontCommand = {
        type = "toggle",
        order = 7,
        name = "Change Edit Box Font",
        desc = "Enable to set edit box font to display font",
        get = function(info) return configModule:GetConfig('editBoxFont') end,
        set = function(info, val)
            configModule:SetConfig('editBoxFont', val)
            coreModule:UpdateMedia()
        end
    }

    return {
        type = "group",
        order = 6,
        name = "Font",
        inline = true,
        args = {
            fontname = fontFontnameCommand,
            fontheight = fontFontHeightCommand,
            fontflags = fontFontFlagsCommand,
            color = fontColorCommand,
            highlightcolor = fontHighlightColorCommand,
            linespacing = fontLineSpacingCommand,
            editBoxFont = fontEditBoxFontCommand,
        }
    }
end

function slashModule:PermissionsCommandGroup()
    local addon = coreModule.addon

    local permissionsAllowAllCommand = {
        type = "toggle",
        order = 1,
        name = "Allow All",
        desc = "Enable to allow changes from any raid assistant, even if you aren't in a guild raid",
        get = function(info) return configModule:GetConfig('allowall') end,
        set = function(info, val)
            configModule:SetConfig('allowall', val)
            addon:PermissionsUpdated()
        end
    }
    local permissionsAllowPlayersCommand = {
        type = "input",
        order = 2,
        name = "Allow Players",
        desc =
        "A list of players that when they are the raid leader to allow changes from all raid assistants",
        get = function(info) return configModule:GetConfig('allowplayers') end,
        set = function(info, val)
            configModule:SetConfig('allowplayers', val)
            addon:PermissionsUpdated()
        end
    }

    return {
        type = "group",
        order = 7,
        name = "Permissions",
        inline = true,
        args = {
            allowall = permissionsAllowAllCommand,
            allowplayers = permissionsAllowPlayersCommand,
        }
    }
end

function slashModule:Initialize()
    local addon = coreModule.addon
    local ver = commModule:GetVersion()

    local windowCommand = {
        type = "execute",
        order = 3,
        name = "Toggle Window",
        desc = "Shows/hides the edit window (also available in game keybindings)",
        func = function() AngrySparks_ToggleWindow() end
    }
    local helpCommand = {
        type = "execute",
        order = 99,
        name = "Help",
        hidden = true,
        func = function()
            LibStub("AceConfigCmd-3.0").HandleCommand(self, slashCommand, "AngrySparks", "")
        end
    }
    local toggleCommand = {
        type = "execute",
        order = 1,
        name = "Toggle Display",
        desc = "Shows/hides the display frame (also available in game keybindings)",
        func = function() AngrySparks_ToggleDisplay() end
    }
    local deleteAllCommand = {
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
            addon:UpdateTree()
            addon:UpdateSelected()
            coreModule:UpdateDisplayed()
            if addon.window then addon.window.tree:SetSelected(nil) end
            addon:Print("All pages have been deleted.")
        end
    }
    local defaultsCommand = {
        type = "execute",
        name = "Restore Defaults",
        desc = "Restore configuration values to their default settings",
        order = 10,
        hidden = true,
        cmdHidden = false,
        confirm = true,
        func = function() configModule:RestoreDefaults() end
    }
    local outputCommand = {
        type = "execute",
        name = "Output",
        desc = "Outputs currently displayed assignents to chat",
        order = 11,
        hidden = true,
        cmdHidden = false,
        confirm = true,
        func = function() addon:OutputDisplayed() end
    }
    local sendCommand = {
        type = "input",
        name = "Send and Display",
        desc = "Sends page with specified name",
        order = 12,
        hidden = true,
        cmdHidden = false,
        confirm = true,
        get = function(info) return "" end,
        set = function(info, val)
            local result = pagesModule:DisplayPageByName(val:trim())
            if result == false then
                addon:Print(RED_FONT_COLOR_CODE ..
                    "A page with the name \"" .. val:trim() .. "\" could not be found.|r")
            elseif not result then
                addon:Print(RED_FONT_COLOR_CODE .. "You don't have permission to send a page.|r")
            end
        end
    }
    local clearCommand = {
        type = "execute",
        name = "Clear",
        desc = "Clears currently displayed page",
        order = 13,
        hidden = true,
        cmdHidden = false,
        confirm = true,
        func = function() pagesModule:ClearPage() end
    }
    local backupCommand = {
        type = "execute",
        order = 20,
        name = "Backup Pages",
        desc = "Creates a backup of all pages with their current contents",
        func = function()
            addon:CreateBackup()
            addon:Print("Created a backup of all pages.")
        end
    }
    local resetPositionCommand = {
        type = "execute",
        order = 22,
        name = "Reset Position",
        desc = "Resets position for the assignment display",
        func = function() addon:ResetPosition() end
    }
    local versionCommand = {
        type = "execute",
        order = 21,
        name = "Version Check",
        desc = "Displays a list of all users (in the raid) running the addon and the version they're running",
        func = function()
            -- if (IsInRaid() or IsInGroup()) then
                commModule.versionList = {} -- start with a fresh version list, when displaying it
                commModule:SendVerQuery()
                addon:ScheduleTimer(function() commModule:VersionCheckOutput() end, commModule.updateThrottle)
                addon:Print("Version check running...")
            -- else
                -- addon:Print("You must be in a raid group to run the version check.")
            -- end
        end
    }
    local lockCommand = {
        type = "execute",
        order = 2,
        name = "Toggle Lock",
        desc = "Shows/hides the display mover (also available in game keybindings)",
        func = function() addon:ToggleLock() end
    }

    local options = {
        name = "Angry Sparks " .. ver,
        handler = addon,
        type = "group",
        args = {
            window = windowCommand,
            help = helpCommand,
            toggle = toggleCommand,
            deleteall = deleteAllCommand,
            defaults = defaultsCommand,
            output = outputCommand,
            send = sendCommand,
            clear = clearCommand,
            backup = backupCommand,
            resetposition = resetPositionCommand,
            version = versionCommand,
            lock = lockCommand,
            config = self:ConfigCommandGroup(),
            font = self:FontCommandGroup(),
            permissions = self:PermissionsCommandGroup()
        }
    }

    addon:RegisterChatCommand(slashCommand, "ChatCommand")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("AngrySparks", options)
end
