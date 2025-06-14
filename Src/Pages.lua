---@class PagesModule
local pagesModule = LibStub("AngrySparks-Pages")
local coreModule = LibStub("AngrySparks-Core")
local commModule = LibStub("AngrySparks-Comm")

function AngrySparks_ToggleWindow()
    local addon = coreModule.addon
    local window = addon:GetWindow()

    if not window then addon:CreateWindow() end

    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

function AngrySparks_ToggleLock()
    local addon = coreModule.addon
    addon:ToggleLock()
end

function AngrySparks_AddPage(widget, event, value)
    local popup_name = "AngrySparks_AddPage"
    local addon = coreModule.addon

    if StaticPopupDialogs[popup_name] == nil then
        StaticPopupDialogs[popup_name] = {
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function(self)
                local text = self.editBox:GetText()
                if text ~= "" then addon:CreatePage(text) end
            end,
            EditBoxOnEnterPressed = function(self)
                local text = self:GetParent().editBox:GetText()
                if text ~= "" then addon:CreatePage(text) end
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

function AngrySparks_RenamePage(pageId)
    local addon = coreModule.addon
    local page = addon:Get(pageId)
    if not page then return end

    local popup_name = "AngrySparks_RenamePage_" .. page.Id
    if StaticPopupDialogs[popup_name] == nil then
        StaticPopupDialogs[popup_name] = {
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function(self)
                local text = self.editBox:GetText()
                addon:RenamePage(page.Id, text)
            end,
            EditBoxOnEnterPressed = function(self)
                local text = self:GetParent().editBox:GetText()
                addon:RenamePage(page.Id, text)
                self:GetParent():Hide()
            end,
            OnShow = function(self) self.editBox:SetText(page.Name) end,
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

function AngrySparks_DeletePage(pageId)
    local addon = coreModule.addon
    local page = addon:Get(pageId)
    if not page then return end

    local popup_name = "AngrySparks_DeletePage_" .. page.Id
    if StaticPopupDialogs[popup_name] == nil then
        StaticPopupDialogs[popup_name] = {
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function(self) addon:DeletePage(page.Id) end,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
    end
    StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete page "' .. page.Name .. '"?'

    StaticPopup_Show(popup_name)
end

function AngrySparks_AddCategory(widget, event, value)
    local addon = coreModule.addon
    local popup_name = "AngrySparks_AddCategory"

    if StaticPopupDialogs[popup_name] == nil then
        StaticPopupDialogs[popup_name] = {
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function(self)
                local text = self.editBox:GetText()
                if text ~= "" then addon:CreateCategory(text) end
            end,
            EditBoxOnEnterPressed = function(self)
                local text = self:GetParent().editBox:GetText()
                if text ~= "" then addon:CreateCategory(text) end
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

function AngrySparks_RenameCategory(catId)
    local addon = coreModule.addon
    local cat = addon:GetCat(catId)
    if not cat then return end

    local popup_name = "AngrySparks_RenameCategory_" .. cat.Id
    if StaticPopupDialogs[popup_name] == nil then
        StaticPopupDialogs[popup_name] = {
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function(self)
                local text = self.editBox:GetText()
                addon:RenameCategory(cat.Id, text)
            end,
            EditBoxOnEnterPressed = function(self)
                local text = self:GetParent().editBox:GetText()
                addon:RenameCategory(cat.Id, text)
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

function AngrySparks_DeleteCategory(catId)
    local addon = coreModule.addon
    local cat = addon:GetCat(catId)
    if not cat then return end

    local popup_name = "AngrySparks_DeleteCategory_" .. cat.Id
    if StaticPopupDialogs[popup_name] == nil then
        StaticPopupDialogs[popup_name] = {
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function(self) addon:DeleteCategory(cat.Id) end,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
    end
    StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete category "' .. cat.Name .. '"?'

    StaticPopup_Show(popup_name)
end

-- TODO: Merge this with the call location in menu or slash command
function pagesModule:AssignCategory(frame, entryId, catId)
    local addon = coreModule.addon
    HideDropDownMenu(1)

    addon:AssignCategory(entryId, catId)
end

function pagesModule:RevertPage(widget, event, value)
    local addon = coreModule.addon
    if not addon.window then return end
    addon:UpdateSelected(true)
end

function pagesModule:DisplayPageByName(name)
    for id, page in pairs(AngrySparks_Pages) do
        if page.Name == name then
            return self:DisplayPage(id)
        end
    end
    return false
end

function pagesModule:DisplayPage(id)
    local addon = coreModule.addon
    if not addon:PermissionCheck() then return end

    addon:TouchPage(id)
    commModule:SendPage(id, true)
    commModule:SendDisplay(id, true)

    if AngrySparks_State.displayed ~= id then
        AngrySparks_State.displayed = id
        coreModule:UpdateDisplayed()
        addon:ShowDisplay()
        addon:UpdateTree()
        addon:DisplayUpdateNotification()
    end

    return true
end

-- TODO: Merge this with the call location in menu or slash command
function pagesModule:DisplayPage0()
    local addon = coreModule.addon
    if not addon:PermissionCheck() then return end
    local id = addon:SelectedId()
    self:DisplayPage(id)
end

function pagesModule:ClearPage(widget, event, value)
    local addon = coreModule.addon
    if not addon:PermissionCheck() then return end

    addon:ClearDisplayed()
    commModule:SendDisplay(nil, true)
end
