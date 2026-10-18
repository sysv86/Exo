-- exo/themes/landroid.lua
-- Static themes ported from https://github.com/kerneldroid/Landroid
-- ("Landroid Helmlab", 6 variants: dark/light x main/soft/contrast).
--
-- The palette row in the Appearance tab lists these; applying one writes the
-- full Material 3 colour sheet (`exo/colors.scss`) from `build_colors_scss()`
-- and reloads the CSS — no `matugen` / wallpaper involved.
--
-- Colour values are the theme's own nvchad `base_30` table verbatim. Tokens
-- that the source theme does not define (containers, fixed variants, inverse
-- colours) are derived by linear mixing between the theme's own background,
-- foreground and accent colours, so a static theme needs only the 17 base
-- colours below.

local M = {}

M.THEMES = {
    { id = "landroid-dark-main", label = "Landroid Dark Main", mode = "dark",
      bg = "#0f0f13", bg0 = "#09090d", bg2 = "#18181d", bg3 = "#22222b", bg4 = "#26262f", bg5 = "#2a2a33",
      fg = "#cacce1", muted = "#9496a9", outline = "#515263", outline_variant = "#606172",
      primary = "#89b6f4", secondary = "#abadf5", tertiary = "#00c8c0", error = "#f69a9a" },
    { id = "landroid-dark-soft", label = "Landroid Dark Soft", mode = "dark",
      bg = "#131316", bg0 = "#0d0d10", bg2 = "#1b1b1f", bg3 = "#24252a", bg4 = "#28292e", bg5 = "#2c2d32",
      fg = "#cccddc", muted = "#9697a3", outline = "#525460", outline_variant = "#60636f",
      primary = "#94b6e7", secondary = "#aeafe7", tertiary = "#00cac1", error = "#eaa0a0" },
    { id = "landroid-dark-contrast", label = "Landroid Dark Contrast", mode = "dark",
      bg = "#050508", bg0 = "#000002", bg2 = "#0f0f15", bg3 = "#1a1a24", bg4 = "#1d1d28", bg5 = "#20202c",
      fg = "#e3e4f1", muted = "#aeb1c5", outline = "#73748d", outline_variant = "#82839d",
      primary = "#aecefd", secondary = "#c8c7fd", tertiary = "#00e4da", error = "#febbb9" },
    { id = "landroid-light-main", label = "Landroid Light Main", mode = "light",
      bg = "#f4f4f9", bg0 = "#f0f0f5", bg2 = "#e5e5ed", bg3 = "#d5d5e1", bg4 = "#d0d0dc", bg5 = "#cbcbd7",
      fg = "#1e1e2c", muted = "#5d5d6c", outline = "#b4b5c5", outline_variant = "#a4a5b5",
      primary = "#174daf", secondary = "#5628c6", tertiary = "#00635f", error = "#c42c41" },
    { id = "landroid-light-soft", label = "Landroid Light Soft", mode = "light",
      bg = "#f0ede6", bg0 = "#edeae3", bg2 = "#e2ddd4", bg3 = "#d3cdc0", bg4 = "#cec8bb", bg5 = "#c9c3b6",
      fg = "#2a2316", muted = "#6e685d", outline = "#b6afa1", outline_variant = "#a69f91",
      primary = "#2754a7", secondary = "#583abb", tertiary = "#006763", error = "#a43841" },
    { id = "landroid-light-contrast", label = "Landroid Light Contrast", mode = "light",
      bg = "#fcfcff", bg0 = "#f8f8fb", bg2 = "#f1f2f8", bg3 = "#e1e2ec", bg4 = "#dcdde7", bg5 = "#d7d8e2",
      fg = "#0f0f16", muted = "#444554", outline = "#8f91a8", outline_variant = "#808198",
      primary = "#033389", secondary = "#3e0a9a", tertiary = "#004643", error = "#aa0f30" },
}

local by_id = {}
for _, theme in ipairs(M.THEMES) do
    by_id[theme.id] = theme
end

---@param id string
---@return table|nil
function M.get(id)
    return by_id[id]
end

---@return table[]
function M.list()
    return M.THEMES
end

-- ---------------------------------------------------------------------------
-- Colour maths
-- ---------------------------------------------------------------------------

local function to_rgb(hex)
    hex = tostring(hex):gsub("^#", "")
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

--- Linear mix; `t` is the weight of `b`.
local function mix(a, b, t)
    local ar, ag, ab = to_rgb(a)
    local br, bg, bb = to_rgb(b)
    local function ch(x, y)
        local v = math.floor(x + (y - x) * t + 0.5)
        if v < 0 then v = 0 elseif v > 255 then v = 255 end
        return string.format("%02x", v)
    end
    return "#" .. ch(ar, br) .. ch(ag, bg) .. ch(ab, bb)
end

-- ---------------------------------------------------------------------------
-- Token sheet
-- ---------------------------------------------------------------------------

--- Material 3 token map for `theme` (snake_case names -> hex), i.e. exactly
--- what `ignis`'s colour sheet consumes. `write_colors_scss()` in
--- `scripts/wallpaper.lua` adds the camelCase spellings.
---@param theme table
---@return table<string, string>
function M.tokens(theme)
    local bg, bg0, bg2, bg3, bg4, bg5 = theme.bg, theme.bg0, theme.bg2, theme.bg3, theme.bg4, theme.bg5
    local fg, muted, outline, outline_variant = theme.fg, theme.muted, theme.outline, theme.outline_variant
    local primary, secondary, tertiary, error = theme.primary, theme.secondary, theme.tertiary, theme.error

    local function container(accent) return mix(bg, accent, 0.30) end
    local function on_container(accent) return mix(fg, accent, 0.20) end
    local function fixed(accent, weight) return mix(bg, accent, weight) end

    local tokens = {
        { "primary", primary },
        { "on_primary", bg },
        { "primary_container", container(primary) },
        { "on_primary_container", on_container(primary) },
        { "primary_fixed", fixed(primary, 0.55) },
        { "primary_fixed_dim", fixed(primary, 0.40) },
        { "on_primary_fixed", bg },
        { "on_primary_fixed_variant", on_container(primary) },

        { "secondary", secondary },
        { "on_secondary", bg },
        { "secondary_container", container(secondary) },
        { "on_secondary_container", on_container(secondary) },
        { "secondary_fixed", fixed(secondary, 0.55) },
        { "secondary_fixed_dim", fixed(secondary, 0.40) },
        { "on_secondary_fixed", bg },
        { "on_secondary_fixed_variant", on_container(secondary) },

        { "tertiary", tertiary },
        { "on_tertiary", bg },
        { "tertiary_container", container(tertiary) },
        { "on_tertiary_container", on_container(tertiary) },
        { "tertiary_fixed", fixed(tertiary, 0.55) },
        { "tertiary_fixed_dim", fixed(tertiary, 0.40) },
        { "on_tertiary_fixed", bg },
        { "on_tertiary_fixed_variant", on_container(tertiary) },

        { "error", error },
        { "on_error", bg },
        { "error_container", container(error) },
        { "on_error_container", on_container(error) },

        { "background", bg },
        { "on_background", fg },
        { "surface", bg },
        { "on_surface", fg },
        { "surface_variant", mix(bg, outline, 0.35) },
        { "on_surface_variant", muted },
        { "surface_dim", mix(bg, bg0, 0.5) },
        { "surface_bright", mix(bg, bg4, 0.7) },
        { "surface_container_lowest", bg0 },
        { "surface_container_low", bg2 },
        { "surface_container", bg3 },
        { "surface_container_high", bg4 },
        { "surface_container_highest", bg5 },

        { "outline", outline },
        { "outline_variant", outline_variant },

        { "inverse_surface", fg },
        { "inverse_on_surface", bg },
        { "inverse_primary", fixed(primary, 0.60) },

        { "scrim", "#000000" },
        { "shadow", "#000000" },
        { "source_color", primary },
        { "surface_tint", primary },
    }

    local map = {}
    for _, token in ipairs(tokens) do
        map[token[1]] = token[2]
    end
    return map
end

return M
