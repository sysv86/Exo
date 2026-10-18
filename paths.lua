local source = debug.getinfo(1, "S").source:sub(2)
local config_dir = source:match("^(.*)/[^/]+$") or "."

local M = {}

M.CONFIG_DIR = config_dir
M.STYLES_DIR = config_dir .. "/styles"
M.COLORS_FILE = config_dir .. "/colors.scss"
M.PALETTES_FILE = config_dir .. "/styles/palettes.scss"
M.PREVIEW_COLORS_FILE = config_dir .. "/styles/preview-colors.scss"
M.USER_SETTINGS_FILE = config_dir .. "/user_settings.json"

---@param name? string
---@return string
function M.style_path(name)
    return M.STYLES_DIR .. "/" .. (name or "main.scss")
end

return M
