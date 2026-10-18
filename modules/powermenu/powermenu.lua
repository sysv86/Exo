local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local Gtk = ignis.Gtk
local Gdk = ignis.Gdk
local window_manager = ignis.WindowManager.get_default()

local PowerMenu = {}
PowerMenu.__index = PowerMenu

local function create_exec_task(command)
    window_manager:close_window("PowerMenu")
    utils.exec_sh_async(command)
end

local OPTIONS = {
    {
        icon = "power_settings_new",
        label = "Power Off",
        key = "1 / P",
        danger = true,
        cmd = "shutdown now || systemctl poweroff",
    },
    {
        icon = "restart_alt",
        label = "Reboot",
        key = "2 / R",
        danger = true,
        cmd = "reboot || systemctl reboot",
    },
    {
        icon = "lock",
        label = "Lock Screen",
        key = "3 / L",
        danger = false,
        cmd = "hyprlock || loginctl lock-session",
    },
    {
        icon = "logout",
        label = "Log Out",
        key = "4 / E",
        danger = false,
        cmd = "niri msg action quit || hyprctl dispatch exit || loginctl terminate-user ''",
    },
    {
        icon = "dark_mode",
        label = "Sleep",
        key = "5 / S",
        danger = false,
        cmd = "systemctl suspend",
    },
    {
        icon = "frame_reload",
        label = "Restart Exo",
        key = "6",
        danger = false,
        cmd = "ignis reload",
    },
}

local function power_menu_button(opt)
    local button_content = widgets.Box({
        child = {
            widgets.Label({ label = opt.icon, css_classes = { "power-menu-icon" } }),
            widgets.Label({ label = opt.label, css_classes = { "power-menu-label" } }),
            widgets.Label({ label = opt.key, css_classes = { "power-menu-shortcut" } }),
        },
        spacing = 8,
        vertical = true,
        halign = "center",
        valign = "center",
    })

    return widgets.Button({
        child = button_content,
        on_click = function()
            create_exec_task(opt.cmd)
        end,
        css_classes = { "power-option", opt.danger and "danger-option" or "" },
        height_request = 156,
        width_request = 156,
    })
end

function PowerMenu.new()
    local self = setmetatable({}, PowerMenu)

    local btns = {}
    for i, opt in ipairs(OPTIONS) do
        btns[i] = power_menu_button(opt)
    end

    local main_box = widgets.Grid({
        valign = "center",
        halign = "center",
        css_classes = { "panel-surface", "powermenu" },
        row_num = 2,
        child = btns,
    })

    local revealer = widgets.Revealer({
        child = main_box,
        transition_duration = 240,
        transition_type = "crossfade",
        halign = "center",
        valign = "center",
    })

    local close_button = widgets.Button({
        vexpand = true,
        hexpand = true,
        can_focus = false,
        css_classes = { "scrim-backdrop" },
        on_click = function()
            window_manager:close_window("PowerMenu")
        end,
    })

    local main_overlay = widgets.Overlay({
        css_classes = { "popup-close" },
        child = close_button,
        overlays = { revealer },
    })

    self.window = widgets.RevealerWindow({
        revealer = revealer,
        child = main_overlay,
        popup = true,
        kb_mode = "exclusive",
        namespace = "PowerMenu",
        exclusivity = "ignore",
        visible = false,
        css_classes = { "popup-close" },
        anchor = { "left", "right", "top", "bottom" },
    })

    local key_ctrl = Gtk.EventControllerKey()
    key_ctrl.on_key_pressed = function(_, keyval)
        if keyval == Gdk.KEY_Escape or keyval == 65307 then
            window_manager:close_window("PowerMenu")
            return true
        elseif keyval == Gdk.KEY_1 or keyval == Gdk.KEY_p or keyval == Gdk.KEY_P then
            create_exec_task(OPTIONS[1].cmd)
            return true
        elseif keyval == Gdk.KEY_2 or keyval == Gdk.KEY_r or keyval == Gdk.KEY_R then
            create_exec_task(OPTIONS[2].cmd)
            return true
        elseif keyval == Gdk.KEY_3 or keyval == Gdk.KEY_l or keyval == Gdk.KEY_L then
            create_exec_task(OPTIONS[3].cmd)
            return true
        elseif keyval == Gdk.KEY_4 or keyval == Gdk.KEY_e or keyval == Gdk.KEY_E then
            create_exec_task(OPTIONS[4].cmd)
            return true
        elseif keyval == Gdk.KEY_5 or keyval == Gdk.KEY_s or keyval == Gdk.KEY_S then
            create_exec_task(OPTIONS[5].cmd)
            return true
        elseif keyval == Gdk.KEY_6 then
            create_exec_task(OPTIONS[6].cmd)
            return true
        end
        return false
    end
    self.window:add_controller(key_ctrl)

    self.main_box = main_box
    self.revealer = revealer

    return self
end

setmetatable(PowerMenu, {
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

return PowerMenu
