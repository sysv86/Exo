local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services
local Gtk = ignis.Gtk
local Gdk = ignis.Gdk
local window_manager = ignis.WindowManager.get_default()
local css_manager = ignis.CssManager.get_default()

local user_settings = require("user_settings")
local Wallpaper = require("scripts.wallpaper")
local recorder_script = require("scripts.recorder")
local send_notification = require("scripts.send_notification")
local LauncherLayout = require("scripts.set_launcher_layout")
local compositor = require("modules.compositor")
local m3 = require("modules.m3components")

local applications = services.ApplicationsService.get_default()

local MAX_SLOTS = 8
local PINNED_COLUMNS = 8


local MATH_ENV = {
    math = math,
    sin = math.sin,
    cos = math.cos,
    tan = math.tan,
    asin = math.asin,
    acos = math.acos,
    atan = math.atan,
    sqrt = math.sqrt,
    abs = math.abs,
    floor = math.floor,
    ceil = math.ceil,
    log = math.log,
    exp = math.exp,
    deg = math.deg,
    rad = math.rad,
    max = math.max,
    min = math.min,
    pi = math.pi,
    e = math.exp(1),
}

local function evaluate_math(expr)
    local clean = (expr or ""):gsub("^=%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then return nil, nil end
    clean = clean:gsub("(%d+%.?%d*)%%", "(%1/100)")
    local fn = load("return (" .. clean .. ")", "exo_calc", "t", MATH_ENV)
    if not fn then return nil, nil end
    local ok, res = pcall(fn)
    if ok and type(res) == "number" and res == res and res ~= math.huge and res ~= -math.huge then
        local dec_str
        local hex_str = nil
        if math.floor(res) == res and math.abs(res) < 1e15 then
            dec_str = string.format("%d", res)
            if res >= 0 and res <= 0xFFFFFFFFFFFF then
                hex_str = string.format("0x%X", res)
            end
        else
            dec_str = tostring(tonumber(string.format("%.8g", res)) or res)
        end
        return dec_str, hex_str
    end
    return nil, nil
end


local QUICK_COMMANDS = {
    {
        name = "Toggle Dark / Light Mode",
        desc = "Switch Material 3 Expressive polarity",
        glyph = "contrast",
        action = function()
            local next_dark = not user_settings.appearance.wallcolors.dark_mode
            Wallpaper.set_dark_mode(next_dark)
        end,
    },
    {
        name = "Open Material 3 Expressive Studio",
        desc = "Inspect 35 M3 shapes, morphing loader, and C11 engine benchmark",
        glyph = "science",
        action = function()
            window_manager:open_window("M3Test")
        end,
    },
    {
        name = "Scheme: Material 3 Expressive",
        desc = "Apply high-contrast Expressive tonal palette",
        glyph = "palette",
        action = function()
            Wallpaper.set_colors("expressive")
        end,
    },
    {
        name = "Scheme: Tonal Spot",
        desc = "Apply balanced Material 3 Tonal Spot palette",
        glyph = "color_lens",
        action = function()
            Wallpaper.set_colors("tonal-spot")
        end,
    },
    {
        name = "Scheme: Vibrant",
        desc = "Apply saturated Vibrant accent palette",
        glyph = "auto_awesome",
        action = function()
            Wallpaper.set_colors("vibrant")
        end,
    },
    {
        name = "Scheme: Rainbow",
        desc = "Apply chromatic Rainbow palette",
        glyph = "looks",
        action = function()
            Wallpaper.set_colors("rainbow")
        end,
    },
    {
        name = "Open Exo Settings",
        desc = "Configure appearance, bars, audio & network",
        glyph = "settings",
        action = function()
            window_manager:open_window("Settings")
        end,
    },
    {
        name = "Open Quick Center",
        desc = "Open telemetry, toggles, sliders & notifications panel",
        glyph = "tune",
        action = function()
            window_manager:open_window("QuickCenter")
        end,
    },
    {
        name = "Open Power Menu",
        desc = "Shutdown, reboot, lock, suspend or log out",
        glyph = "power_settings_new",
        action = function()
            window_manager:open_window("PowerMenu")
        end,
    },
    {
        name = "Record Screen / Stop Recording",
        desc = "Toggle full-screen GPU recording",
        glyph = "screen_record",
        action = function()
            recorder_script.record_screen()
        end,
    },
    {
        name = "Record Region (Slurp)",
        desc = "Select a screen region to record",
        glyph = "screenshot_region",
        action = function()
            recorder_script.record_region()
        end,
    },
    {
        name = "Reload Styles (SCSS)",
        desc = "Hot-reload Material 3 Expressive stylesheets in-place",
        glyph = "refresh",
        action = function()
            css_manager:reload_all_css()
            send_notification("Exo Shell", "Material 3 Expressive styles reloaded.")
        end,
    },
}


local function build_app_menu(application)
    local items = {
        { label = application.name, enabled = false },
        { separator = true },
        {
            label = application.is_pinned and "Unpin from Dock" or "Pin to Dock",
            on_activate = function()
                if application.is_pinned then
                    application:unpin()
                else
                    application:pin()
                end
            end,
        },
    }

    if application.actions and #application.actions > 0 then
        items[#items + 1] = { separator = true }
        for _, action in ipairs(application.actions) do
            local act = action
            items[#items + 1] = {
                label = act.name,
                on_activate = function()
                    act:launch()
                    window_manager:close_window("Launcher")
                end,
            }
        end
    end

    return items
end

local function show_app_menu(parent_widget, application)
    if not application then return end
    local popover = widgets.PopoverMenu({ items = build_app_menu(application) })
    local child = parent_widget:get_child()
    if child and child.append then
        child:append(popover)
    end
    popover:popup()
end


local PinnedAppItem = {}
PinnedAppItem.__index = PinnedAppItem

function PinnedAppItem.new(application, launcher_instance)
    local self = setmetatable({
        _application = application,
        _launcher = launcher_instance,
    }, PinnedAppItem)

    self.button = widgets.Button({
        tooltip_text = application.name,
        on_click = function()
            self:launch()
        end,
        on_right_click = function(widget)
            show_app_menu(widget, application)
        end,
        css_classes = { "pinned-item" },
        child = widgets.Box({
            halign = "center",
            valign = "center",
            child = {
                widgets.Icon({ image = application.icon, pixel_size = 28, halign = "center" }),
            },
        }),
    })
    m3.enhance_button(self.button, {
        bg = "surface_container_high",
        ink = "on_surface",
        hover_bg = "primary_container",
        hover_ink = "on_primary_container",
        radius = { rest = "pill", hover = 12, press = 6 },
    })

    return self
end

function PinnedAppItem:launch()
    self._launcher:close_launcher()
    self._application:launch({ terminal_format = "kitty %command%" })
end

function PinnedAppItem:widget()
    return self.button
end


local Launcher = {}
Launcher.__index = Launcher

function Launcher.new()
    local self = setmetatable({
        _slots = {},
        _active_items = {},
        _selected_index = 1,
        _hint_pills = {},
    }, Launcher)

    self._mode_chip = widgets.Label({
        label = "APPS",
        css_classes = { "launcher-mode-chip", "monospace-num" },
        valign = "center",
    })

    self._entry = widgets.Entry({
        hexpand = true,
        placeholder_text = "Search apps, '=' calc, ':' actions, '>' shell, '/' windows, '@' procs...",
        css_classes = { "launcher-entry", "launcher-search" },
        on_change = function(entry)
            self:_populate_slots(entry.text)
        end,
        on_accept = function()
            self:_trigger_slot(self._selected_index)
        end,
    })

    self._clear_btn = widgets.Button({
        css_classes = { "m3-button", "text", "xs", "icon-only" },
        visible = false,
        on_click = function()
            self:_clear_search()
        end,
        child = widgets.Label({ label = "close", css_classes = { "m3-button-icon" } }),
    })
    m3.enhance_button(self._clear_btn)

    self._search_bar = widgets.Box({
        spacing = 12,
        valign = "center",
        css_classes = { "launcher-search-bar", "search-bar-container" },
        child = {
            widgets.Label({ label = "search", css_classes = { "search-lead-icon" } }),
            self._entry,
            self._clear_btn,
            self._mode_chip,
        },
    })

    local prefix_modes = {
        { id = "APPS",   label = "Apps",     prefix = "",   icon = "apps" },
        { id = "WIN",    label = "/ Win",    prefix = "/ ", icon = "window" },
        { id = "PROC",   label = "@ Proc",   prefix = "@ ", icon = "memory" },
        { id = "CALC",   label = "= Calc",   prefix = "= ", icon = "calculate" },
        { id = "SHELL",  label = "> Shell",  prefix = "> ", icon = "terminal" },
        { id = "ACTION", label = ": Action", prefix = ": ", icon = "bolt" },
    }
    local hints_children = {}
    for _, pm in ipairs(prefix_modes) do
        local mode_info = pm
        local pill = m3.Button.button({
            icon = mode_info.icon,
            label = mode_info.label,
            size = "xs",
            shape = "square",
            css_classes = { "launcher-hint-pill" },
            on_click = function()
                self._entry.text = mode_info.prefix
                self._entry:grab_focus()
                self._entry:set_position(-1)
                self:_populate_slots(mode_info.prefix)
            end,
        })
        self._hint_pills[mode_info.id] = pill
        hints_children[#hints_children + 1] = pill
    end

    self._hints_row = m3.Button.connected_group(hints_children, {
        halign = "start",
        css_classes = { "launcher-hints-row" },
    })

    self._pinned_apps_container = widgets.Grid({
        css_classes = { "pinned-apps-container" },
        column_spacing = 8,
        row_spacing = 8,
        halign = "center",
    })

    self._pinned_revealer = widgets.Revealer({
        transition_type = "slide_down",
        transition_duration = 180,
        reveal_child = true,
        child = self._pinned_apps_container,
    })

    self:_populate_pinned_apps_list()
    applications:connect("notify::pinned", function()
        self:refresh_pinned_apps_list()
        if (self._entry.text or "") == "" then
            self:_populate_slots("")
        end
    end)

    self._results_box = widgets.Box({
        vertical = true,
        spacing = 6,
        css_classes = { "launcher-results" },
    })

    for i = 1, MAX_SLOTS do
        local idx = i
        local app_icon = widgets.Icon({
            pixel_size = 32,
            css_classes = { "slot-icon" },
            visible = true,
        })
        local glyph_icon = widgets.Label({
            label = "bolt",
            css_classes = { "slot-glyph" },
            visible = false,
            halign = "center",
            valign = "center",
        })
        local title = widgets.Label({
            halign = "start",
            css_classes = { "slot-title" },
            ellipsize = "end",
        })
        local subtitle = widgets.Label({
            halign = "start",
            css_classes = { "slot-subtitle" },
            ellipsize = "end",
        })
        local pin_badge = widgets.Label({
            label = "keep",
            css_classes = { "slot-pin-badge" },
            visible = false,
            valign = "center",
        })
        local badge = widgets.Label({
            halign = "end",
            valign = "center",
            css_classes = { "slot-badge", "monospace-num" },
            label = "Launch ↵",
        })

        local btn = widgets.Button({
            css_classes = { "launcher-slot" },
            visible = false,
            can_focus = false,
            on_click = function()
                self:_trigger_slot(idx)
            end,
            on_right_click = function(widget)
                local item = self._active_items[idx]
                if item and item.app then
                    show_app_menu(widget, item.app)
                end
            end,
            child = widgets.Box({
                spacing = 14,
                valign = "center",
                child = {
                    app_icon,
                    glyph_icon,
                    widgets.Box({
                        vertical = true,
                        valign = "center",
                        hexpand = true,
                        spacing = 1,
                        child = { title, subtitle },
                    }),
                    pin_badge,
                    badge,
                },
            }),
        })

        m3.enhance_button(btn, {
            bg = "surface_container_low",
            ink = "on_surface",
            hover_bg = "secondary_container",
            hover_ink = "on_secondary_container",
            radius = { rest = "pill", hover = 22, press = 8 },
        })

        self._slots[i] = {
            btn = btn,
            icon = app_icon,
            glyph = glyph_icon,
            title = title,
            subtitle = subtitle,
            pin_badge = pin_badge,
            badge = badge,
        }
        self._results_box:append(btn)
    end

    self._empty_state = widgets.Box({
        vertical = true,
        spacing = 6,
        halign = "center",
        valign = "center",
        visible = false,
        css_classes = { "launcher-empty-state" },
        child = {
            widgets.Label({ label = "search_off", css_classes = { "empty-icon" } }),
            widgets.Label({ label = "No matching items found", css_classes = { "empty-title" } }),
        },
    })

    local key_controller = Gtk.EventControllerKey()
    if Gtk.PropagationPhase and Gtk.PropagationPhase.CAPTURE then
        key_controller:set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
    end
    key_controller.on_key_pressed = function(_, keyval, _, state)
        -- LuaGObject hands GdkModifierType to signal callbacks as a table in
        -- this build, so `state & CONTROL_MASK` raised "attempt to perform
        -- bitwise operation on a table value" and killed every key this
        -- controller handles (Escape / arrows / Tab / Enter never returned
        -- true). Only use the numeric form when it actually is one.
        local ctrl = false
        if type(state) == "number" and Gdk.ModifierType then
            ctrl = (state & Gdk.ModifierType.CONTROL_MASK) ~= 0
        end
        if keyval == Gdk.KEY_Escape or keyval == 65307 then
            self:close_launcher()
            return true
        elseif keyval == Gdk.KEY_Down or keyval == Gdk.KEY_Tab or (ctrl and (keyval == Gdk.KEY_j or keyval == Gdk.KEY_n)) then
            self:_update_selection(self._selected_index + 1)
            return true
        elseif keyval == Gdk.KEY_Up or keyval == Gdk.KEY_ISO_Left_Tab or (ctrl and (keyval == Gdk.KEY_k or keyval == Gdk.KEY_p)) then
            self:_update_selection(self._selected_index - 1)
            return true
        elseif keyval == Gdk.KEY_Return or keyval == Gdk.KEY_KP_Enter then
            self:_trigger_slot(self._selected_index)
            return true
        end
        return false
    end
    self._entry:add_controller(key_controller)

    local win_key_ctrl = Gtk.EventControllerKey()
    win_key_ctrl.on_key_pressed = function(_, keyval)
        if keyval == Gdk.KEY_Escape or keyval == 65307 then
            self:close_launcher()
            return true
        end
        return false
    end

    self.surface = widgets.Box({
        vertical = true,
        spacing = 10,
        valign = "start",
        halign = "center",
        css_classes = { "panel-surface", "launcher-surface", "launcher-window" },
        child = {
            self._search_bar,
            self._hints_row,
            self._pinned_revealer,
            self._results_box,
            self._empty_state,
        },
    })

    self.revealer = widgets.Revealer({
        transition_type = "slide_down",
        transition_duration = 220,
        child = self.surface,
    })

    self.window = widgets.RevealerWindow({
        namespace = "Launcher",
        visible = false,
        hide_on_close = true,
        kb_mode = "exclusive",
        layer = "overlay",
        exclusivity = "ignore",
        anchor = { "top", "right", "bottom", "left" },
        revealer = self.revealer,
        child = widgets.Overlay({
            css_classes = { "popup-close" },
            child = widgets.Button({
                vexpand = true,
                hexpand = true,
                can_focus = false,
                css_classes = { "scrim-backdrop" },
                on_click = function()
                    self:close_launcher()
                end,
            }),
            overlays = {
                widgets.Box({
                    valign = "start",
                    halign = "center",
                    style = "margin-top: 76px;",
                    child = { self.revealer },
                }),
            },
        }),
    })
    self.window:add_controller(win_key_ctrl)

    self.window:connect("notify::visible", function()
        if self.window.visible then
            self._entry.text = ""
            self:_populate_pinned_apps_list()
            self:_populate_slots("")
            self._entry:grab_focus()
            self._entry:set_position(-1)
        end
    end)

    self:_populate_slots("")
    LauncherLayout.set_launcher_instance(self)

    return self
end

function Launcher:_set_active_mode(mode_id, is_accent)
    self._mode_chip.label = mode_id
    self._mode_chip:toggle_css_class("accent", is_accent)
    for id, pill in pairs(self._hint_pills) do
        pill:toggle_css_class("active", id == mode_id)
    end
end

function Launcher:_update_selection(new_idx)
    local count = #self._active_items
    if count == 0 then
        self._selected_index = 1
        for i = 1, MAX_SLOTS do
            self._slots[i].btn:remove_css_class("selected")
        end
        return
    end

    self._selected_index = ((new_idx - 1) % count) + 1
    for i = 1, MAX_SLOTS do
        if i == self._selected_index and i <= count then
            self._slots[i].btn:add_css_class("selected")
        else
            self._slots[i].btn:remove_css_class("selected")
        end
    end
end

function Launcher:_trigger_slot(idx)
    local item = self._active_items[idx]
    if not item then return end
    self:close_launcher()
    if item.on_trigger then
        item.on_trigger()
    end
end

function Launcher:_populate_slots(query)
    self._active_items = {}
    local raw_q = query or ""
    local q = raw_q:gsub("^%s+", "")

    self._clear_btn.visible = (raw_q ~= "")
    self._pinned_revealer.reveal_child = (q == "" and #(applications.pinned or {}) > 0)

    local prefix = q:sub(1, 1)

    if prefix == "=" then
        self:_set_active_mode("CALC", true)
        local expr = q:sub(2):gsub("^%s+", "")
        local ans, hex_ans = evaluate_math(q)
        if ans then
            local sub_txt = hex_ans and (hex_ans .. "  •  Copy result (" .. expr .. ")") or ("Copy result (" .. expr .. ")")
            table.insert(self._active_items, {
                glyph = "calculate",
                title = ans,
                subtitle = sub_txt,
                badge = hex_ans or "Copy ↵",
                on_trigger = function()
                    utils.exec_sh_async(string.format("wl-copy %q 2>/dev/null", ans))
                    send_notification("Calculator", ans .. " copied to clipboard.")
                end,
            })
        else
            table.insert(self._active_items, {
                glyph = "calculate",
                title = expr ~= "" and ("Expression: " .. expr) or "Type a math or hex expression...",
                subtitle = "Supports +, -, *, /, ^, %, 0xFF, sin(), cos(), sqrt(), pi",
                badge = "Math",
                on_trigger = function() end,
            })
        end

    elseif prefix == ">" then
        self:_set_active_mode("SHELL", true)
        local cmd = q:sub(2):gsub("^%s+", "")
        if cmd ~= "" then
            table.insert(self._active_items, {
                glyph = "terminal",
                title = cmd,
                subtitle = "Execute asynchronously in background shell",
                badge = "Run ↵",
                on_trigger = function()
                    utils.exec_sh_async(cmd)
                end,
            })
            table.insert(self._active_items, {
                glyph = "open_in_new",
                title = "kitty -e " .. cmd,
                subtitle = "Run inside interactive terminal window",
                badge = "Term ↵",
                on_trigger = function()
                    utils.exec_sh_async("kitty sh -c " .. string.format("%q", cmd .. "; exec $SHELL"))
                end,
            })
        else
            table.insert(self._active_items, {
                glyph = "terminal",
                title = "Type a shell command to execute...",
                subtitle = "Example: > btop  or  > notify-send Hello",
                badge = "Shell",
                on_trigger = function() end,
            })
        end

    elseif prefix == "@" then
        self:_set_active_mode("PROC", true)
        local sub_q = q:sub(2):lower():gsub("^%s+", "")
        local ps_res = utils.exec_sh("ps -eo pid=,pcpu=,pmem=,comm= --sort=-pcpu 2>/dev/null | head -n 20")
        for line in (ps_res.stdout or ""):gmatch("[^\r\n]+") do
            local pid, cpu, mem, comm = line:match("^%s*(%d+)%s+([%d%.]+)%s+([%d%.]+)%s+(.+)$")
            if pid and comm then
                if sub_q == "" or comm:lower():find(sub_q, 1, true) or pid:find(sub_q, 1, true) then
                    local target_pid = pid
                    local target_comm = comm
                    table.insert(self._active_items, {
                        glyph = "memory",
                        title = target_comm,
                        subtitle = string.format("CPU %s%%  •  RAM %s%%  •  Click/Enter to send SIGTERM", cpu, mem),
                        badge = "PID " .. target_pid,
                        on_trigger = function()
                            utils.exec_sh_async("kill -15 " .. target_pid .. " 2>/dev/null")
                            send_notification("Process Terminated", string.format("Sent SIGTERM to %s (PID %s)", target_comm, target_pid))
                        end,
                    })
                    if #self._active_items >= MAX_SLOTS then break end
                end
            end
        end

    elseif prefix == ":" then
        self:_set_active_mode("ACTION", true)
        local sub_q = q:sub(2):lower():gsub("^%s+", "")
        for _, act in ipairs(QUICK_COMMANDS) do
            if sub_q == ""
                or act.name:lower():find(sub_q, 1, true)
                or act.desc:lower():find(sub_q, 1, true) then
                table.insert(self._active_items, {
                    glyph = act.glyph,
                    title = act.name,
                    subtitle = act.desc,
                    badge = "Action ↵",
                    on_trigger = act.action,
                })
                if #self._active_items >= MAX_SLOTS then break end
            end
        end

    elseif prefix == "/" then
        self:_set_active_mode("WIN", true)
        local sub_q = q:sub(2):lower():gsub("^%s+", "")
        local wins = (compositor.service and compositor.service.windows) or {}
        for _, win in ipairs(wins) do
            local w_title = compositor.window_title(win) or "Untitled"
            local w_app = compositor.window_app_id(win) or "Window"
            local w_pid = compositor.window_pid(win)
            if sub_q == ""
                or w_title:lower():find(sub_q, 1, true)
                or w_app:lower():find(sub_q, 1, true) then
                local target_win = win
                local icon_name = utils.get_app_icon_name(w_app) or "application-x-executable-symbolic"
                table.insert(self._active_items, {
                    icon = icon_name,
                    title = w_title,
                    subtitle = string.format(
                        "%s  •  Workspace %s%s",
                        w_app,
                        tostring(compositor.window_workspace_id(win) or "?"),
                        w_pid and string.format("  •  PID %d", w_pid) or ""
                    ),
                    badge = w_pid and ("PID " .. tostring(w_pid)) or "Focus ↵",
                    on_trigger = function()
                        compositor.focus_window(target_win)
                    end,
                })
                if #self._active_items >= MAX_SLOTS then break end
            end
        end

    else
        self:_set_active_mode("APPS", false)
        local all_apps = applications.apps or {}
        local list = (q == "") and all_apps or applications.search(all_apps, q)
        for idx = 1, math.min(#list, MAX_SLOTS) do
            local app = list[idx]
            table.insert(self._active_items, {
                app = app,
                icon = (app.icon and app.icon ~= "") and app.icon or "application-x-executable-symbolic",
                title = app.name or "Unknown",
                subtitle = (app.description and app.description ~= "") and app.description or (app.executable or "Application"),
                is_pinned = app.is_pinned,
                badge = "Launch ↵",
                on_trigger = function()
                    app:launch({ terminal_format = "kitty %command%" })
                end,
            })
        end
    end

    for i = 1, MAX_SLOTS do
        local slot = self._slots[i]
        local data = self._active_items[i]
        if data then
            if data.glyph then
                slot.icon.visible = false
                slot.glyph.label = data.glyph
                slot.glyph.visible = true
            else
                slot.glyph.visible = false
                slot.icon.image = data.icon or "application-x-executable-symbolic"
                slot.icon.visible = true
            end
            slot.title.label = data.title or ""
            slot.subtitle.label = data.subtitle or ""
            slot.pin_badge.visible = data.is_pinned == true
            slot.badge.label = data.badge or "↵"
            slot.btn.visible = true
        else
            slot.btn.visible = false
        end
    end

    local has_results = (#self._active_items > 0)
    self._results_box.visible = has_results
    self._empty_state.visible = (not has_results)
    self:_update_selection(1)
end

function Launcher:_populate_pinned_apps_list()
    local pinned_apps = applications.pinned or {}
    if #pinned_apps == 0 then
        self._pinned_apps_container:set_child({})
        self._pinned_revealer.reveal_child = false
        return
    end

    local children = {}
    for index, app in ipairs(pinned_apps) do
        local item = PinnedAppItem.new(app, self)
        local col = (index - 1) % PINNED_COLUMNS
        local row = math.floor((index - 1) / PINNED_COLUMNS)
        children[#children + 1] = { item:widget(), col, row }
    end
    self._pinned_apps_container:set_child(children)
end

function Launcher:refresh_pinned_apps_list()
    self:_populate_pinned_apps_list()
end

function Launcher:_clear_search()
    self._entry.text = ""
    self._entry:grab_focus()
    self:_populate_slots("")
end

function Launcher:close_launcher()
    self.window.visible = false
end

function Launcher:toggle_window()
    self.window.visible = not self.window.visible
end

function Launcher:_set_layout(layout)
    user_settings.interface.launcher.layout = layout
    self:_populate_slots(self._entry.text)
end

setmetatable(Launcher, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

return Launcher
