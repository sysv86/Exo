local ignis = require("ignis")
local widgets = ignis.widgets
local services = ignis.services

local user_settings = require("user_settings")
local m3 = require("modules.m3components")
local compositor = require("modules.compositor")

local ApplicationsService = services.ApplicationsService

local Tasks = {}
Tasks.__index = Tasks

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

function Tasks.new()
    local self = setmetatable({
        applications_service = ApplicationsService.get_default(),
        _buttons_by_id = {},
        _last_signature = "",
    }, Tasks)

    self.box = widgets.Box({ css_classes = { "tasks" } })
    self.box:set_spacing(4)

    self.applications_service:connect("notify::pinned", function()
        self:_update_dock(true)
    end)
    if compositor.service then
        compositor.service:connect("notify::windows", function()
            self:_update_dock(false)
        end)
        compositor.service:connect("notify::active_window", function()
            self:_update_active_only()
        end)
    end

    self:update_layout()
    return self
end

function Tasks:_get_app_from_window(window)
    local app_id = compositor.window_app_id(window)
    if not app_id then return nil end

    for _, app in ipairs(self.applications_service.apps or {}) do
        if compositor.is_same_app(app.id, app_id) then
            return app
        end
    end
    return nil
end

function Tasks:_handle_app_click(app, widget)
    if not compositor.service then
        app:launch()
        return
    end

    local app_windows = {}
    for _, window in ipairs(compositor.service.windows or {}) do
        if compositor.is_same_app(app.id, compositor.window_app_id(window)) then
            app_windows[#app_windows + 1] = window
        end
    end

    if #app_windows == 0 then
        app:launch()
    elseif #app_windows == 1 then
        compositor.focus_window(app_windows[1])
    else
        self:_show_window_list_popover(app_windows, widget)
    end
end

function Tasks:_show_window_list_popover(windows, parent_widget)
    local items = {}
    for _, window in ipairs(windows) do
        local target = window
        items[#items + 1] = {
            label = (target.title and target.title ~= "") and target.title or "Untitled Window",
            on_activate = function()
                compositor.focus_window(target)
            end,
        }
    end

    local popover = widgets.PopoverMenu({ items = items })
    local container = parent_widget:get_child()
    if container and container.add_overlay then
        container:add_overlay(popover)
        popover:popup()
    end
end

function Tasks:_create_app_button(app, is_open, is_active)
    local bar = bar_for(user_settings.interface.modules.bar_id.tasks)
    local side = bar.side or "bottom"
    local icon_size = (bar.density == 0 or bar.density == 1) and 20 or 16

    local icon = widgets.Icon({ image = app.icon, pixel_size = icon_size })

    local overlays = {}
    if is_open then
        local indicator = widgets.Box({ css_classes = { "app-indicator", side } })
        if not bar.vertical then
            indicator:set_halign("center")
        elseif side == "left" then
            indicator:set_halign("start")
        elseif side == "right" then
            indicator:set_halign("end")
        end
        if side == "left" or side == "right" then
            indicator:set_valign("center")
        elseif side == "top" then
            indicator:set_valign("start")
        elseif side == "bottom" then
            indicator:set_valign("end")
        end
        overlays[#overlays + 1] = indicator
    end

    local overlay = widgets.Overlay({ child = icon, overlays = overlays })

    local app_button = widgets.Button({
        child = overlay,
        tooltip_text = app.name,
        on_click = function(btn)
            self:_handle_app_click(app, btn)
        end,
        css_classes = { "app-button" },
    })

    m3.enhance_button(app_button, {
        ink = "on_surface",
        hover_bg = "surface_container_highest",
        active_bg = "secondary_container",
        radius = { rest = "pill", hover = 12, press = 6, active = 12 },
    })

    if is_open then
        app_button:add_css_class("open-app")
    end
    if is_active then
        app_button:add_css_class("active-app")
    end

    local items = {
        { label = app.name, enabled = false },
        { separator = true },
        {
            label = app.is_pinned and "Unpin from Dock" or "Pin to Dock",
            on_activate = function()
                if app.is_pinned then
                    app:unpin()
                else
                    app:pin()
                end
            end,
        },
    }

    local has_extra_actions = is_open or (app.actions and #app.actions > 0)
    if has_extra_actions then
        items[#items + 1] = { separator = true }
    end

    if is_open then
        items[#items + 1] = {
            label = "New Window",
            on_activate = function()
                app:launch()
            end,
        }
    end

    for _, action in ipairs(app.actions or {}) do
        items[#items + 1] = {
            label = action.name,
            on_activate = function()
                action:launch()
            end,
        }
    end

    app_button.on_right_click = function(widget)
        local popover = widgets.PopoverMenu({ items = items })
        local container = widget:get_child()
        if container and container.add_overlay then
            container:add_overlay(popover)
            popover:popup()
        end
    end

    return app_button
end

function Tasks:_update_active_only()
    local active_app = nil
    if compositor.service and compositor.service.active_window then
        active_app = self:_get_app_from_window(compositor.service.active_window)
    end
    local active_id = active_app and active_app.id or nil
    for app_id, btn in pairs(self._buttons_by_id) do
        if active_id and app_id == active_id then
            btn:add_css_class("active-app")
        else
            btn:remove_css_class("active-app")
        end
    end
end

function Tasks:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.tasks)
    local side = bar.side or "bottom"
    local vertical = (side == "left" or side == "right")

    self.box:set_vertical(vertical)
    if side == "left" then
        self.box:set_halign("start")
        self.box:set_valign("fill")
    elseif side == "right" then
        self.box:set_halign("end")
        self.box:set_valign("fill")
    elseif side == "top" then
        self.box:set_halign("fill")
        self.box:set_valign("start")
    elseif side == "bottom" then
        self.box:set_halign("fill")
        self.box:set_valign("end")
    end

    self:_update_dock(true)
end

function Tasks:_update_dock(force)
    local bar = bar_for(user_settings.interface.modules.bar_id.tasks)
    local side = bar.side or "bottom"
    local vertical = (side == "left" or side == "right")
    self.box:set_vertical(vertical)

    local active_app = nil
    if compositor.service and compositor.service.active_window then
        active_app = self:_get_app_from_window(compositor.service.active_window)
    end

    local pinned_apps = self.applications_service.pinned or {}

    local open_app_ids = {}
    if compositor.service then
        for _, window in ipairs(compositor.service.windows or {}) do
            local app = self:_get_app_from_window(window)
            if app then
                open_app_ids[app.id] = true
            end
        end
    end

    local pinned_app_ids = {}
    local sig_parts = { side, tostring(bar.density) }
    for _, app in ipairs(pinned_apps) do
        pinned_app_ids[app.id] = true
        sig_parts[#sig_parts + 1] = "P:" .. tostring(app.id) .. ":" .. (open_app_ids[app.id] and "1" or "0")
    end

    local open_unpinned_apps = {}
    if compositor.service then
        for _, window in ipairs(compositor.service.windows or {}) do
            local app = self:_get_app_from_window(window)
            if app and not pinned_app_ids[app.id] then
                local already = false
                for _, existing in ipairs(open_unpinned_apps) do
                    if existing.id == app.id then
                        already = true
                        break
                    end
                end
                if not already then
                    open_unpinned_apps[#open_unpinned_apps + 1] = app
                    sig_parts[#sig_parts + 1] = "U:" .. tostring(app.id)
                end
            end
        end
    end

    local sig = table.concat(sig_parts, "|")
    if not force and sig == self._last_signature then
        self:_update_active_only()
        return
    end
    self._last_signature = sig

    self.box:set_child({})
    self._buttons_by_id = {}

    for _, app in ipairs(pinned_apps) do
        local is_open = open_app_ids[app.id] == true
        local is_active = active_app ~= nil and app.id == active_app.id
        local btn = self:_create_app_button(app, is_open, is_active)
        self._buttons_by_id[app.id] = btn
        self.box:append(btn)
    end

    if #open_unpinned_apps > 0 and #pinned_apps > 0 then
        self.box:append(widgets.Separator({ vertical = not vertical }))
    end

    for _, app in ipairs(open_unpinned_apps) do
        local is_active = active_app ~= nil and app.id == active_app.id
        local btn = self:_create_app_button(app, true, is_active)
        self._buttons_by_id[app.id] = btn
        self.box:append(btn)
    end
end

function Tasks:widget()
    return self.box
end

return Tasks
