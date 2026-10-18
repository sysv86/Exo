local M = {}

local function is_callable(value)
    local t = type(value)
    if t == "function" then return true end
    if t == "userdata" or t == "table" then
        local mt = getmetatable(value)
        return mt ~= nil and mt.__call ~= nil
    end
    return false
end

--- Builds the metatable for a proxy object.
---@param own table the wrapper's own methods/constants
---@param target table the wrapped widget
---@return table
function M.proxy(own, target)
    return {
        __index = function(_, key)
            local value = own[key]
            if value ~= nil then
                return value
            end
            local raw = target[key]
            if is_callable(raw) then
                return function(_, ...)
                    return raw(target, ...)
                end
            end
            return raw
        end,
        __newindex = function(_, key, value)
            target[key] = value
        end,
    }
end

return M
