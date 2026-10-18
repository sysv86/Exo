local ignis = require("ignis")
local widgets = ignis.widgets

local user_settings = require("user_settings")

local Corners = {}

local windows = {}

--- Creates (or returns an existing) corner window.
---@param anchors string[]
---@param name string
---@param exclusivity string
---@param corner_type string "screen" | "bar"
---@param size? number
---@param layer? string
---@return table
function Corners.corner(anchors, name, exclusivity, corner_type, size, layer)
    size = size or 25
    layer = layer or "top"

    for _, win in ipairs(windows) do
        if win.namespace == name then
            return win
        end
    end

    local win = widgets.Window({
        css_classes = { corner_type .. "-corner" },
        anchor = anchors,
        visible = true,
        namespace = name,
        height_request = size,
        width_request = size,
        exclusivity = exclusivity,
        dynamic_input_region = false,
        layer = layer,
        child = widgets.Corner({ orientation = table.concat(anchors, "-") }),
    })

    windows[#windows + 1] = win
    return win
end

--- Screen corner (outer edge of the monitor).
---@param anchors string[]
---@param corner_size number
---@return table
function Corners.screen(anchors, corner_size)
    local name = "screen_corner_" .. table.concat(anchors, "_")
    return Corners.corner(
        anchors,
        name,
        "ignore",
        "screen",
        corner_size,
        user_settings.interface.misc.screen_corners == "always" and "overlay" or "top"
    )
end

--- Shell corner (around the bar/dock).
---@param anchors string[]
---@return table
function Corners.bar(anchors)
    local name = "bar_corner_" .. table.concat(anchors, "_")
    return Corners.corner(anchors, name, "normal", "bar")
end

--- Rebuilds all corner windows according to the current settings.
function Corners.build()
    local bar = user_settings.interface.bar
    local bar2 = user_settings.interface.bar2
    local misc = user_settings.interface.misc

    local optimal_size = 25
    if bar.density == 1 then
        optimal_size = 22.5
    elseif bar.density == 2 then
        optimal_size = 20
    elseif bar.density == 3 then
        optimal_size = 17.5
    end

    if misc.screen_corners ~= "disabled" then
        if bar.floating and not bar.centered then
            local corners = {
                { { "top", "left" }, (bar.side == "top" or bar.side == "left") and optimal_size or 25 },
                { { "top", "right" }, (bar.side == "top" or bar.side == "right") and optimal_size or 25 },
                { { "bottom", "left" }, (bar.side == "bottom" or bar.side == "left") and optimal_size or 25 },
                { { "bottom", "right" }, (bar.side == "bottom" or bar.side == "right") and optimal_size or 25 },
            }
            for _, entry in ipairs(corners) do
                Corners.screen(entry[1], entry[2])
            end
        else
            for _, corner in ipairs({
                { "top", "left" },
                { "top", "right" },
                { "bottom", "left" },
                { "bottom", "right" },
            }) do
                Corners.screen(corner, 25)
            end
        end
    end

    if misc.shell_corners then
        local corners = {}

        if not bar.floating and not bar.centered then
            if bar.vertical then
                corners[#corners + 1] = { "top", bar.side }
                corners[#corners + 1] = { "bottom", bar.side }
            else
                corners[#corners + 1] = { bar.side, "left" }
                corners[#corners + 1] = { bar.side, "right" }
            end
        end

        if bar2.enabled then
            if not bar2.floating and not bar2.centered then
                if bar2.vertical then
                    corners[#corners + 1] = { "top", bar2.side }
                    corners[#corners + 1] = { "bottom", bar2.side }
                else
                    corners[#corners + 1] = { bar2.side, "left" }
                    corners[#corners + 1] = { bar2.side, "right" }
                end
            end
        end

        local seen = {}
        for _, corner in ipairs(corners) do
            local key = table.concat(corner, "_")
            if not seen[key] then
                seen[key] = true
                Corners.bar(corner)
            end
        end
    end
end

--- Destroys every corner window.
function Corners.destroy_all()
    for _, window in ipairs(windows) do
        window:destroy()
    end
    windows = {}
end

return Corners
