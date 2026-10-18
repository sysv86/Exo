local paths = require("paths")

local M = {}

local cache = nil
local cache_mtime = nil

local function clamp01(value)
    return math.max(0.0, math.min(1.0, value))
end

--- Converts a color value into {r, g, b, a} floats.
---@param value string
---@return table? color
local function parse_color(value)
    if type(value) ~= "string" then
        return nil
    end

    local hex = value:match("^%s*#(%x+)%s*$")
    if hex then
        local r, g, b, a
        if #hex == 3 or #hex == 4 then
            r, g, b, a = hex:match("^(%x)(%x)(%x)(%x?)$")
            if not r then return nil end
            local rr, gg, bb = tonumber(r .. r, 16), tonumber(g .. g, 16), tonumber(b .. b, 16)
            local aa = a and (tonumber(a .. a, 16) or 255) or 255
            return { r = rr / 255.0, g = gg / 255.0, b = bb / 255.0, a = aa / 255.0 }
        elseif #hex == 6 or #hex == 8 then
            r, g, b, a = hex:match("^(%x%x)(%x%x)(%x%x)(%x?%x?)$")
            if not r then return nil end
            local rr, gg, bb = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
            local aa = (a and #a == 2) and tonumber(a, 16) or 255
            return { r = rr / 255.0, g = gg / 255.0, b = bb / 255.0, a = aa / 255.0 }
        end
        return nil
    end

    local nums = value:match("^%s*rgba?%s*%(([^)]*)%)%s*$")
    if nums then
        local parts = {}
        for num in nums:gmatch("[-%d%.]+") do
            parts[#parts + 1] = tonumber(num)
        end
        local r = parts[1] and parts[1] / 255.0
        local g = parts[2] and parts[2] / 255.0
        local b = parts[3] and parts[3] / 255.0
        local a = parts[4] and clamp01(parts[4]) or 1.0
        if r and g and b then
            return { r = clamp01(r), g = clamp01(g), b = clamp01(b), a = a }
        end
    end

    return nil
end

local function snake_to_camel(snake)
    return (snake:gsub("_(%a)", function(c) return c:upper() end))
end

--- Loads and parses colors.scss into a name -> {r,g,b,a} table.
---@return table
function M.load()
    if cache ~= nil then
        return cache
    end

    cache = {}
    local file = io.open(paths.COLORS_FILE, "r")
    if not file then
        return cache
    end

    for line in file:lines() do
        local name, value = line:match("^%$([%w_]+)%s*:%s*(.-)%s*;")
        if name and value then
            local color = parse_color(value)
            if color then
                cache[name] = color
                if name:find("_", 1, true) then
                    cache[snake_to_camel(name)] = color
                end
            end
        end
    end
    file:close()

    return cache
end

--- Drops the cached palette so the next `get` re-reads colors.scss.
function M.clear_cache()
    cache = nil
    cache_mtime = nil
end

--- Gets one palette color.
---@param name string snake_case name, e.g. "on_primary"
---@return table? color
function M.get(name)
    local palette = M.load()
    local color = palette[name]
    if not color then
        color = palette[snake_to_camel(name)]
    end
    if color then
        return { r = color.r, g = color.g, b = color.b, a = color.a }
    end
    return nil
end

--- Linear blend of two colors; when `other` is missing returns `color`.
---@param color table?
---@param other table?
---@param t number 0..1
---@return table color
function M.mix(color, other, t)
    if not color then
        return other
    end
    if not other then
        return color
    end
    t = clamp01(t)
    return {
        r = color.r + (other.r - color.r) * t,
        g = color.g + (other.g - color.g) * t,
        b = color.b + (other.b - color.b) * t,
        a = color.a + (other.a - color.a) * t,
    }
end

--- Returns a copy of the color with a replaced alpha.
---@param color table?
---@param alpha number
---@return table? color
function M.with_alpha(color, alpha)
    if not color then
        return nil
    end
    return { r = color.r, g = color.g, b = color.b, a = alpha }
end

return M
