---@class UtilsModule
---@field playerRealm string
local utilsModule = LibStub("AngrySparks-Utils") --[[@as UtilsModule]]

---Converts a hex color to RGB values
function utilsModule:HexToRGB(hex)
    if string.len(hex) == 8 then
        return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
            tonumber("0x" .. hex:sub(5, 6)) / 255, tonumber("0x" .. hex:sub(7, 8)) / 255
    else
        return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
            tonumber("0x" .. hex:sub(5, 6)) / 255
    end
end

---Converts RGB values to a hex color
---@param r number 0..1 range
---@param g number 0..1 range
---@param b number 0..1 range
---@param a number? 0..1 range
---@return string Either RRGGBB or RRGGBBAA string
function utilsModule:RGBToHex(r, g, b, a)
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

---Splits a string into a table of strings, using a delimiter
---@param separator string
---@param content string
---@return string[]
function utilsModule:Explode(separator, content)
    local t, position
    t = {}
    position = 0
    if (#content == 1) then
        return { content }
    end
    while true do
        -- find the next separator in the string
        local idx = string.find(content, separator, position, true)
        if idx ~= nil then
            table.insert(t, string.sub(content, position, idx - 1))
            -- save just after where we found it for searching next time.
            position = idx + #separator
        else
            -- Save what's left in our array.
            table.insert(t, string.sub(content, position))
            break
        end
    end
    return t
end

---Returns the last value of the input string split by the delimiter, converted to a number
---@param input string
---@return number
function utilsModule:SelectedLastValue(input)
    local a = select(-1, strsplit("", input or ""))
    return tonumber(a)
end

---Reverses table elements (values) in place, preserving order of indexes
---@param tbl table
function utilsModule:TReverse(tbl)
    for i = 1, math.floor(#tbl / 2) do
        tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
    end
end

---Ensures a unit's full name is formatted correctly: Name-Realm
---@param unit string
---@return string
function utilsModule:EnsureUnitFullName(unit)
    if not self.playerRealm then self.playerRealm = select(2, UnitFullName('player')) end
    if unit and not unit:find('-') then
        unit = unit .. '-' .. self.playerRealm
    end
    return unit
end

---Ensures a unit's short name is formatted correctly
---@param unit string
---@return string
function utilsModule:EnsureUnitShortName(unit)
    if not self.playerRealm then self.playerRealm = select(2, UnitFullName('player')) end
    local name, realm = strsplit("-", unit, 2)
    if not realm or realm == self.playerRealm then
        return name
    else
        return unit
    end
end

---Returns the player's full name: Name-Realm
---@return string
function utilsModule:PlayerFullName()
    if not self.playerRealm then self.playerRealm = select(2, UnitFullName('player')) end
    return UnitName('player') .. '-' .. self.playerRealm
end

---@param pattern string
---@return string
function utilsModule:Pattern(pattern)
    local p = pattern:gsub("(%%?)(.)", function(percent, letter)
        if percent ~= "" or not letter:match("%a") then
            return percent .. letter
        else
            return string.format("[%s%s]", letter:lower(), letter:upper())
        end
    end)
    return p
end

function utilsModule:Dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. self:Dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end
