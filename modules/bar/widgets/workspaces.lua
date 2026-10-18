local ignis = require("ignis")
local widgets = ignis.widgets

local user_settings = require("user_settings")
local AppIcon = require("modules.shared_modules.app_icon")
local compositor = require("modules.compositor")
local m3 = require("modules.m3components")


local DummyWorkspace = {}
DummyWorkspace.__index = DummyWorkspace

function DummyWorkspace.new(id)
    return setmetatable({ id = id, idx = id }, DummyWorkspace)
end

function DummyWorkspace:switch_to()
    compositor.switch_to_workspace(self.id)
end


local WorkspaceButton = {}
WorkspaceButton.__index = WorkspaceButton

local function bar_for_workspaces()
    if user_settings.interface.modules.bar_id.workspaces == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

function WorkspaceButton.new(workspace)
    local self = setmetatable({ workspace = workspace }, WorkspaceButton)

    local label_text = tostring(compositor.workspace_id(workspace) or 1)
    self._label = widgets.Label({
        label = label_text,
        halign = "center",
        valign = "center",
        css_classes = { "workspace-label", "monospace-num" },
    })

    self._icons_box = widgets.Box({
        spacing = 4,
        visible = false,
        css_classes = { "workspace-icons" },
    })

    self._main_content_box = widgets.Box({
        halign = "center",
        valign = "center",
        spacing = 4,
        child = { self._label, self._icons_box },
    })

    self._button = widgets.Button({
        css_classes = { "workspace" },
        on_click = function()
            if self.workspace then
                self.workspace:switch_to()
            end
        end,
        child = self._main_content_box,
    })
    m3.enhance_button(self._button)

    self:set_workspace(workspace)
    return self
end

function WorkspaceButton:set_workspace(workspace)
    self.workspace = workspace
    local ws_id = compositor.workspace_id(workspace) or 1
    self._label:set_label(tostring(ws_id))
    self:_update_css_classes()
    self:update_layout()
    local style = user_settings.interface.modules.options.workspaces_style
    if style == "windows" then
        self:_update_icons()
    else
        self._icons_box:set_visible(false)
    end
end

function WorkspaceButton:_get_windows_for_workspace()
    local workspace_id = compositor.workspace_id(self.workspace)
    if workspace_id == nil then return {} end
    return compositor.windows_on_workspace(workspace_id)
end

function WorkspaceButton:_update_css_classes()
    local active = compositor.active_workspace()
    local active_id = compositor.workspace_id(active)
    local ws_id = compositor.workspace_id(self.workspace)
    local is_active = (active_id ~= nil and ws_id == active_id)

    self._button:toggle_css_class("active", is_active)

    local win_count = #self:_get_windows_for_workspace()
    if win_count == 0 and not is_active then
        self._button:add_css_class("empty")
        self._button:remove_css_class("occupied")
    else
        self._button:remove_css_class("empty")
        if not is_active then
            self._button:add_css_class("occupied")
        else
            self._button:remove_css_class("occupied")
        end
    end
end

function WorkspaceButton:_update_icons()
    if not self._icons_box then return end
    local style = user_settings.interface.modules.options.workspaces_style
    if style ~= "windows" then
        self._icons_box:set_visible(false)
        return
    end

    self._icons_box:set_child({})
    local windows = self:_get_windows_for_workspace()
    self._icons_box:set_visible(#windows > 0)

    for i, window in ipairs(windows) do
        if i > 4 then break end
        local icon_widget = AppIcon.new({
            app_id = compositor.window_app_id(window),
            name = window.title,
            pixel_size = 15,
        })
        self._icons_box:append(icon_widget:widget())
    end
end

function WorkspaceButton:update_layout()
    local bar = bar_for_workspaces()
    local vertical = bar.vertical
    local style = user_settings.interface.modules.options.workspaces_style

    if self._icons_box then
        self._icons_box:set_vertical(vertical)
    end

    self._label:set_visible(style ~= "dots")

    if vertical then
        self._main_content_box:set_vertical(true)
        self._button:set_halign("center")
        self._button:set_valign(style == "dots" and "center" or "fill")
    else
        self._main_content_box:set_vertical(false)
        self._button:set_valign("center")
        self._button:set_halign(style == "dots" and "center" or "fill")
    end

    self._main_content_box:set_spacing(style == "dots" and 0 or 4)
end

function WorkspaceButton:set_visible(vis)
    self._button:set_visible(vis)
end

function WorkspaceButton:widget()
    return self._button
end


local Workspaces = {}
Workspaces.__index = Workspaces

function Workspaces.new()
    local self = setmetatable({
        _pool = {},
        _buttons = {},
    }, Workspaces)

    self._workspace_box = widgets.Box({
        css_classes = { "workspaces" },
        halign = "center",
        hexpand = true,
        valign = "center",
        vexpand = true,
    })

    local options = user_settings.interface.modules.options
    options:connect_option("workspaces_style", function()
        self:update_workspaces()
        self:update_layout()
    end)
    options:connect_option("fixed_workspaces_enabled", function()
        self:update_workspaces()
    end)
    options:connect_option("fixed_workspaces_amount", function()
        self:update_workspaces()
    end)

    self._event_box = widgets.EventBox({
        child = { self._workspace_box },
        on_scroll_up = function()
            self:workspaces_scroll(1)
        end,
        on_scroll_down = function()
            self:workspaces_scroll(-1)
        end,
    })

    if compositor.service then
        compositor.service:connect("notify::workspaces", function()
            self:update_workspaces()
        end)
        compositor.service:connect("notify::active_workspace", function()
            self:update_workspaces()
        end)
        compositor.service:connect("notify::windows", function()
            self:update_workspaces()
        end)
        self:update_workspaces()
        self:update_layout()
    end

    return self
end

function Workspaces:update_workspaces()
    local options = user_settings.interface.modules.options
    local current_style = options.workspaces_style
    local fixed_enabled = options.fixed_workspaces_enabled
    local fixed_amount = math.max(1, math.min(20, math.floor(tonumber(options.fixed_workspaces_amount) or 5)))

    self._workspace_box:toggle_css_class("dots", current_style == "dots")
    self._workspace_box:toggle_css_class("windows", current_style == "windows")
    self._workspace_box:toggle_css_class("numbers", current_style == "numbers")

    if not compositor.service then return end

    local all_workspaces_map = compositor.workspaces_by_id()
    local workspaces_to_display = {}

    if fixed_enabled and fixed_amount > 0 then
        local active = compositor.active_workspace()
        local active_id = compositor.workspace_id(active) or 1
        local page_base_id = (fixed_amount == 1) and active_id
            or ((math.floor((active_id - 1) / fixed_amount)) * fixed_amount + 1)

        for i = page_base_id, page_base_id + fixed_amount - 1 do
            workspaces_to_display[#workspaces_to_display + 1] = all_workspaces_map[i] or DummyWorkspace.new(i)
        end
    else
        for _, workspace in pairs(all_workspaces_map) do
            workspaces_to_display[#workspaces_to_display + 1] = workspace
        end
        table.sort(workspaces_to_display, function(a, b)
            return (compositor.workspace_id(a) or 0) < (compositor.workspace_id(b) or 0)
        end)
        if #workspaces_to_display == 0 then
            for i = 1, 5 do
                workspaces_to_display[i] = DummyWorkspace.new(i)
            end
        end
    end

    local count = #workspaces_to_display
    for i = 1, count do
        local ws = workspaces_to_display[i]
        local slot = self._pool[i]
        if not slot then
            slot = WorkspaceButton.new(ws)
            self._pool[i] = slot
            self._workspace_box:append(slot:widget())
        else
            slot:set_workspace(ws)
        end
        slot:set_visible(true)
    end

    for i = count + 1, #self._pool do
        self._pool[i]:set_visible(false)
    end

    self._buttons = self._pool
end

function Workspaces:update_layout()
    local bar = bar_for_workspaces()
    local vertical = bar.vertical
    local style = user_settings.interface.modules.options.workspaces_style
    local spacing = (style == "windows") and 2 or 4

    self._workspace_box:set_vertical(vertical)
    self._workspace_box:set_spacing(spacing)

    for _, button in ipairs(self._pool) do
        button:update_layout()
    end
end

function Workspaces:workspaces_scroll(difference)
    if not compositor.service then return end
    local active = compositor.active_workspace()
    local active_id = compositor.workspace_id(active)
    if active_id == nil then return end
    local target = active_id + difference
    if target >= 1 then
        compositor.switch_to_workspace(target)
    end
end

function Workspaces:widget()
    return self._event_box
end

return Workspaces
