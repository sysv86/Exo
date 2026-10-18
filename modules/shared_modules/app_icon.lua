local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services
local widget_proxy = require("widget_proxy")

local ApplicationsService = services.ApplicationsService

local FALLBACK_ICON = "application-x-executable-symbolic"

--- Splits an id on `.`, `_` and `-` into a token set.
local function tokens_of(text)
    local set = {}
    for token in text:gmatch("[^._%-]+") do
        if token ~= "" then set[token] = true end
    end
    return set
end

local function jaccard(a, b)
    local intersection, union = 0, 0
    local seen = {}
    for token in pairs(a) do
        seen[token] = true
        union = union + 1
        if b[token] then intersection = intersection + 1 end
    end
    for token in pairs(b) do
        if not seen[token] then union = union + 1 end
    end
    if union == 0 then return 0 end
    return math.floor(100 * intersection / union)
end

local AppIcon = {}
AppIcon.__index = AppIcon

--- Creates an AppIcon widget.
---@param props table `app`, `app_id`, `name`, plus any `widgets.Icon` properties
---@return table
function AppIcon.new(props)
    props = props or {}

    local icon_props = {}
    for key, value in pairs(props) do
        if key ~= "app" and key ~= "app_id" and key ~= "name" then
            icon_props[key] = value
        end
    end

    local icon = widgets.Icon(icon_props)
    local self = setmetatable({
        _icon = icon,
        _app = props.app,
        _app_id = props.app_id,
        _name = props.name,
        _applications = ApplicationsService.get_default(),
    }, widget_proxy.proxy(AppIcon, icon))

    self:get_icon()
    return self
end

--- Scores how well `app_id` matches an installed application.
---@param app table Application
---@param app_id string
---@return number
function AppIcon:get_match_score(app, app_id)
    if not app or not app_id or app_id == "" then
        return 0
    end

    local app_id_lower = app_id:lower()
    local app_id_from_app_lower = (app.id or ""):lower()

    if app_id_lower == app_id_from_app_lower then
        return 400
    end

    if app_id_from_app_lower ~= ""
        and (app_id_lower:find(app_id_from_app_lower, 1, true)
            or app_id_from_app_lower:find(app_id_lower, 1, true)) then
        return 300
    end

    local score = 0
    local app_name_lower = ""
    if app.name and app.name ~= "" then
        app_name_lower = app.name:lower()
        if app_id_lower == app_name_lower then
            score = 200
        end
    end

    local app_id_tokens = tokens_of(app_id_lower)
    score = math.max(score, jaccard(app_id_tokens, tokens_of(app_id_from_app_lower)))

    if app_name_lower ~= "" then
        score = math.max(score, jaccard(app_id_tokens, tokens_of(app_name_lower)))
    end

    return score
end

--- Resolves and applies the icon image.
function AppIcon:get_icon()
    local icon_path = nil

    if self._app then
        icon_path = (self._app.icon ~= "" and self._app.icon) or FALLBACK_ICON
    else
        if self._app_id and self._app_id ~= "" then
            icon_path = utils.get_app_icon_name(self._app_id)
        end
        if not icon_path and self._name and self._name ~= "" then
            icon_path = utils.get_app_icon_name(self._name)
        end

        if not icon_path and ((self._app_id and self._app_id ~= "") or (self._name and self._name ~= "")) then
            local best_match, highest_score = nil, 0
            for _, app in ipairs(self._applications.apps or {}) do
                local score = 0
                if self._name and self._name ~= "" then
                    score = self:get_match_score(app, self._name)
                end
                if self._app_id and self._app_id ~= "" then
                    score = math.max(score, self:get_match_score(app, self._app_id))
                end
                if score > highest_score then
                    highest_score = score
                    best_match = app
                end
            end
            if best_match then
                icon_path = (best_match.icon and best_match.icon ~= "") and best_match.icon or FALLBACK_ICON
            end
        end
    end

    self._icon:set_image(icon_path or FALLBACK_ICON)
end

function AppIcon:set_app_id(value)
    if value == self._app_id then return end
    self._app_id = value
    self:get_icon()
end

function AppIcon:set_name(value)
    if value == self._name then return end
    self._name = value
    self:get_icon()
end

function AppIcon:set_app(value)
    if value == self._app then return end
    self._app = value
    self:get_icon()
end

function AppIcon:widget()
    return self._icon
end

return AppIcon
