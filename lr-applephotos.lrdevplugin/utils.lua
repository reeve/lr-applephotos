--[[

    utils.lua - generic utility functions

    Copyright (C) 2024 Fiona Boston <fiona@fbphotography.uk>.

    This file is copied/modified from part of PiwigoPublish

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]


local utils = {}

function utils.nilOrEmpty(val)
    -- check if val is nil or empty

    if val == nil then
        return true
    end
    if type(val) == "string" and val == "" then
        return true
    end
    if type(val) == "table" then
        -- Check if table has any elements (non-empty)
        for _ in pairs(val) do
            return false
        end
        return true
    end
    return false
end

function utils.array_contains(arr, target)
    for _, value in ipairs(arr) do
        if value == target then
            return true
        end
    end
    return false
end

function utils.array_contains_property(arr, property, target)
    for _, value in ipairs(arr) do
        if value[property] == target then
            return true
        end
    end
    return false
end

function utils.serialiseVar(value, indent)
    -- serialises an unknown variable
    indent = indent or ""
    local t = type(value)

    if t == "table" then
        local parts = {}
        table.insert(parts, "{\n")
        local nextIndent = indent .. "  "
        for k, v in pairs(value) do
            local key
            if type(k) == "string" then
                key = string.format("%q", k)
            else
                key = tostring(k)
            end
            table.insert(parts, nextIndent .. "[" .. key .. "] = " .. utils.serialiseVar(v, nextIndent) .. ",\n")
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts)

        -- local parts = {}
        -- table.insert(parts, "{\n")
        -- local nextIndent = indent .. "  "
        -- for k, v in value:pairs() do
        --     local key
        --     if type(k) == "string" then
        --         key = string.format("%q", k)
        --     else
        --         key = tostring(k)
        --     end
        --     table.insert(parts, nextIndent .. "[" .. key .. "] = " .. utils.serialiseVar(v, nextIndent) .. ",\n")
        -- end
        -- table.insert(parts, indent .. "}")
        -- return table.concat(parts)
    elseif t == "string" then
        return string.format("%q", value)
    else
        return tostring(value)
    end
end

return utils
