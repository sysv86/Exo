local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local base_widget = require("ignis.base_widget")
local Spring = require("ignis.utils.spring")
local palette = require("modules.m3components.palette")

local Ignis = lgi.package("Ignis")
Ignis:class("M3ButtonHalo", Gtk.DrawingArea)

base_widget.apply_to_class(Ignis.M3ButtonHalo)

local math_min = math.min
local math_max = math.max
local math_pi = math.pi

local SIZES = { xs = 32, s = 40, m = 56, l = 96, xl = 136 }
local PRESSED_RADIUS_DP = { xs = 8, s = 8, m = 12, l = 16, xl = 16 }
local SQUARE_RADIUS_PX = { xs = 8, s = 12, m = 16, l = 22, xl = 26 }

local SPECS = {
    filled = {
        bg = "primary", ink = "on_primary",
    },
    tonal = {
        bg = "secondary_container", ink = "on_secondary_container",
    },
    surface = {
        bg = "surface_container_high", ink = "on_surface",
        border = { "outline_variant", 0.22 },
        hover_bg = "surface_container_highest",
        hover_border = { "primary", 0.35 },
    },
    elevated = {
        bg = "surface_container_low", ink = "primary",
        border = { "outline_variant", 0.28 },
        shadow = true,
        hover_bg = "surface_container_high",
    },
    outlined = {
        ink = "on_surface_variant",
        border = { "outline_variant", 1.0 },
        hover_border = { "primary", 1.0 },
    },
    text = {
        ink = "primary",
    },
    danger = {
        bg = "error_container", ink = "on_error_container",
        hover_bg = "error", hover_ink = "on_error",
    },
}

local SEGMENT_SPEC = {
    bg = "surface_container_high",
    ink = "on_surface_variant",
    hover_bg = "surface_container_highest",
    hover_ink = "on_surface",
}

local ACTIVE_SPEC = {
    bg = "primary",
    ink = "on_primary",
}

local OPEN_SPEC = {
    bg = "tertiary_container",
    ink = "on_tertiary_container",
}

local lerp = Spring.lerp


--- Appends a rounded rectangle with four independent corner radii.
local function rounded_path(cr, x, y, w, h, tl, tr, br, bl)
    local m = math_min(w, h) * 0.5
    tl = math_min(math_max(tl or 0, 0), m)
    tr = math_min(math_max(tr or 0, 0), m)
    br = math_min(math_max(br or 0, 0), m)
    bl = math_min(math_max(bl or 0, 0), m)

    cr:move_to(x + tl, y)
    cr:line_to(x + w - tr, y)
    if tr > 0 then cr:arc(x + w - tr, y + tr, tr, -0.5 * math_pi, 0) end
    cr:line_to(x + w, y + h - br)
    if br > 0 then cr:arc(x + w - br, y + h - br, br, 0, 0.5 * math_pi) end
    cr:line_to(x + bl, y + h)
    if bl > 0 then cr:arc(x + bl, y + h - bl, bl, 0.5 * math_pi, math_pi) end
    cr:line_to(x, y + tl)
    if tl > 0 then cr:arc(x + tl, y + tl, tl, math_pi, 1.5 * math_pi) end
    cr:close_path()
end

--- Reads the button spec (variant/size/shape/segment) out of its css classes.
local function read_spec(button)
    local classes = {}
    pcall(function()
        classes = button:get_css_classes()
    end)

    local variant, size, shape
    local segment = nil
    local kind = nil
    local ws_state = nil
    for _, class in ipairs(classes) do
        if class == "workspace" then
            kind = "workspace"
        elseif class == "filled" or class == "tonal" or class == "surface"
            or class == "elevated" or class == "outlined" or class == "text"
            or class == "danger" then
            variant = class
        elseif class == "xs" or class == "s" or class == "m"
            or class == "l" or class == "xl" then
            size = class
        elseif class == "round" then
            shape = "round"
        elseif class == "square" then
            shape = "square"
        elseif class == "segment-first" or class == "m3-split-leading" then
            segment = "first"
        elseif class == "segment-last" or class == "m3-split-trailing" then
            segment = "last"
        elseif class == "segment-middle" then
            segment = "middle"
        elseif class == "segment-single" then
            segment = "single"
        end
        if class == "active" then
            ws_state = "active"
        elseif class == "occupied" and ws_state ~= "active" then
            ws_state = "occupied"
        elseif class == "empty" and ws_state == nil then
            ws_state = "empty"
        end
    end

    return {
        variant = variant or "tonal",
        size = size or "s",
        shape = shape or "round",
        segment = segment,
        kind = kind,
        ws_state = ws_state or "plain",
    }
end


local function retarget(spring, target)
    if spring.target ~= target then
        spring:animate_to(target)
    end
end

local function draw_halo(area, cr, width, height)
    local env = base_widget.get_env(area)
    local button = env.button
    if not button or width <= 0 or height <= 0 then
        return
    end

    if not env.spec or env.spec_dirty then
        env.spec = read_spec(button)
        env.spec_dirty = false
    end
    local spec = env.spec

    local content = env.content
    if content then
        local cw, ch = 0, 0
        pcall(function()
            local _, nat_w = content:measure(Gtk.Orientation.HORIZONTAL, -1)
            local _, nat_h = content:measure(Gtk.Orientation.VERTICAL, -1)
            cw, ch = nat_w or 0, nat_h or 0
        end)
        if cw > 0 and area.width_request ~= cw then
            area.width_request = cw
        end
        if ch > 0 and area.height_request ~= ch then
            area.height_request = ch
        end
    end

    local flags = nil
    pcall(function() flags = button:get_state_flags() end)
    flags = flags or {}
    local sensitive = true
    pcall(function() sensitive = button:get_sensitive() ~= false end)
    local hovered = flags.PRELIGHT == true and sensitive
    local pressed = flags.ACTIVE == true and sensitive
    local checked = flags.CHECKED == true

    local is_open = false
    local is_active = false
    pcall(function()
        is_open = button:has_css_class("open")
        is_active = button:has_css_class("active")
    end)
    if is_active then
        checked = true
    end
    env.open_target = is_open and 1 or 0

    retarget(env.press, pressed and 1 or 0)
    retarget(env.hover, hovered and 1 or 0)
    retarget(env.open, env.open_target or 0)

    local press_t = env.press.value
    local hover_t = env.hover.value
    local open_t = env.open.value
    local custom = env.custom_spec
    local morph = 0.5 * hover_t

    local u = height / (SIZES[spec.size] or 40)
    local pressed_r = (PRESSED_RADIUS_DP[spec.size] or 8) * u
    local pill = height * 0.5

    local function as_px(value, fallback)
        if value == nil then return fallback end
        if value == "pill" then return pill end
        return value
    end

    local tl, tr, br, bl
    if custom then
        local rad = custom.radius or {}
        local active_now = checked or is_active
        local rest_r = as_px(rad.rest, pill)
        local hover_r = as_px(rad.hover, rest_r)
        local r = lerp(rest_r, hover_r, hover_t)
        if active_now then
            r = lerp(r, as_px(rad.active, r), 1.0)
        end
        tl, tr, br, bl = r, r, r, r
    elseif spec.kind == "workspace" then
        local rest = pill
        if spec.ws_state == "active" then
            rest = 8.0
        elseif spec.ws_state == "occupied" then
            rest = 9.0
        end
        local ws_hover = math_min(8.0, pill)
        local ws_press = math_min(6.0, pill)
        local ws_r = lerp(rest, ws_hover, hover_t)
        ws_r = lerp(ws_r, ws_press, press_t)
        tl, tr, br, bl = ws_r, ws_r, ws_r, ws_r
    elseif spec.segment == "first" then
        local inner = lerp(4 * u, 12 * u, morph)
        tl, tr, br, bl = pill, inner, inner, pill
    elseif spec.segment == "last" and open_t < 0.02 then
        local inner = lerp(4 * u, 12 * u, morph)
        tl, tr, br, bl = inner, pill, pill, inner
    elseif spec.segment == "middle" then
        local inner = lerp(4 * u, 12 * u, morph)
        tl, tr, br, bl = inner, inner, inner, inner
    elseif spec.segment == "single" or spec.segment == nil then
        local rest = (spec.shape == "square") and (SQUARE_RADIUS_PX[spec.size] or 12) or pill
        tl, tr, br, bl = lerp(rest, pressed_r, morph), lerp(rest, pressed_r, morph),
            lerp(rest, pressed_r, morph), lerp(rest, pressed_r, morph)
    else
        tl, tr, br, bl = pill, pill, pill, pill
    end
    local open_morph = open_t
    if spec.segment == "last" and open_t > 0.001 then
        tl = lerp(tl, pill, open_morph)
        tr = lerp(tr, pill, open_morph)
        br = lerp(br, pill, open_morph)
        bl = lerp(bl, pill, open_morph)
    end

    local active = checked
    local enabled = (not sensitive) and 0.38 or 1.0
    local blend = math_max(hover_t, press_t)

    local spec_colors
    if custom then
        spec_colors = nil -- computed below
    elseif spec.kind == "workspace" then
        if spec.ws_state == "active" then
            spec_colors = { bg = "primary", ink = "on_primary" }
        elseif spec.ws_state == "occupied" then
            spec_colors = { bg = "secondary_container", ink = "on_secondary_container",
                hover_bg = "primary_fixed_dim", hover_ink = "on_primary_fixed" }
        elseif spec.ws_state == "empty" then
            spec_colors = { bg = "surface_container", ink = "on_surface_variant",
                hover_bg = "primary_fixed_dim", hover_ink = "on_primary_fixed" }
        else
            spec_colors = { bg = "surface_container_high", ink = "on_surface_variant",
                hover_bg = "primary_fixed_dim", hover_ink = "on_primary_fixed" }
        end
    elseif active then
        spec_colors = ACTIVE_SPEC
    elseif spec.segment then
        spec_colors = SEGMENT_SPEC
    else
        spec_colors = SPECS[spec.variant] or SPECS.tonal
    end

    local bg, ink
    local border_color, border_alpha = nil, 0

    if custom then
        local active_now = checked or is_active
        local function color_of(name)
            return name and palette.get(name) or nil
        end
        bg = color_of(custom.bg)
        ink = color_of(custom.ink) or { r = 0, g = 0, b = 0, a = 1 }
        if active_now then
            bg = color_of(custom.active_bg) or bg
            ink = color_of(custom.active_ink) or ink
        else
            if custom.hover_bg then
                local target = color_of(custom.hover_bg)
                bg = bg and palette.mix(bg, target, hover_t)
                    or (target and palette.with_alpha(target, hover_t) or bg)
            end
            if custom.hover_ink then
                ink = palette.mix(ink, color_of(custom.hover_ink), hover_t)
            end
        end
        if custom.border then
            border_color = color_of(custom.border[1])
            border_alpha = custom.border[2]
            if custom.hover_border then
                border_color = palette.mix(border_color, color_of(custom.hover_border[1]), hover_t)
                border_alpha = lerp(border_alpha, custom.hover_border[2], hover_t)
            end
        end
    else
        bg = spec_colors.bg and palette.get(spec_colors.bg)
        ink = palette.get(spec_colors.ink) or { r = 0, g = 0, b = 0, a = 1 }

        if active then
            bg = ACTIVE_SPEC.bg and palette.get(ACTIVE_SPEC.bg) or bg
            ink = palette.get(ACTIVE_SPEC.ink) or ink
        else
            if spec_colors.hover_bg then
                bg = palette.mix(bg, palette.get(spec_colors.hover_bg), blend)
            end
            if spec.segment and SEGMENT_SPEC.hover_ink then
                ink = palette.mix(palette.get(SEGMENT_SPEC.ink), palette.get(SEGMENT_SPEC.hover_ink), hover_t)
            elseif spec_colors.hover_ink then
                ink = palette.mix(ink, palette.get(spec_colors.hover_ink), blend)
            end

            if spec.segment == "last" and open_t > 0.001 then
                bg = palette.mix(bg, palette.get(OPEN_SPEC.bg), open_t)
                ink = palette.mix(ink, palette.get(OPEN_SPEC.ink), open_t)
            end
        end

        if spec_colors.border and not active then
            border_color = palette.get(spec_colors.border[1])
            border_alpha = spec_colors.border[2]
            if spec_colors.hover_border then
                local hb_color = palette.get(spec_colors.hover_border[1])
                border_color = palette.mix(border_color, hb_color, hover_t)
                border_alpha = lerp(border_alpha, spec_colors.hover_border[2], hover_t)
            end
        end
    end

    local A = palette.with_alpha
    cr:save()

    if spec_colors and spec_colors.shadow then
        local shadow_a = lerp(0.16, 0.26, blend) * enabled
        cr:new_path()
        rounded_path(cr, 0, 1.5 * u + blend * u, width, height - (1.5 * u + blend * u), tl, tr, br, bl)
        local sc = A({ r = 0, g = 0, b = 0, a = 1 }, shadow_a)
        cr:set_source_rgba(sc.r, sc.g, sc.b, sc.a)
        cr:fill()
    end

    if bg then
        cr:new_path()
        rounded_path(cr, 0, 0, width, height, tl, tr, br, bl)
        cr:set_source_rgba(bg.r, bg.g, bg.b, bg.a * enabled)
        cr:fill()
    end

    if border_color then
        local bc = palette.with_alpha(border_color, border_alpha * enabled)
        if bc.a > 0.004 then
            cr:new_path()
            rounded_path(cr, 0.5, 0.5, width - 1, height - 1, tl, tr, br, bl)
            cr:set_source_rgba(bc.r, bc.g, bc.b, bc.a)
            cr:set_line_width(1.0)
            cr:stroke()
        end
    end

    local layer = 0
    if not custom then
        layer = math_max(press_t * 0.12, hover_t * 0.08 * (1.0 - 0.6 * press_t))
    end
    if layer > 0.004 and ink then
        cr:new_path()
        rounded_path(cr, 0, 0, width, height, tl, tr, br, bl)
        local lc = A(ink, layer * enabled)
        cr:set_source_rgba(lc.r, lc.g, lc.b, lc.a)
        cr:fill()
    end

    cr:restore()
end

local function ensure_tick(halo)
    local env = base_widget.get_env(halo)
    if env.tick_loop then return end
    env.tick_loop = true
    local started = pcall(function()
        halo:add_tick_callback(function(self)
            local env = base_widget.get_env(self)
            local button = env.button
            if not button then
                halo.env_tick_active = false
                return false -- stops the tick loop
            end

            local flags = nil
            pcall(function() flags = button:get_state_flags() end)
            flags = flags or {}
            local sensitive = true
            pcall(function() sensitive = button:get_sensitive() ~= false end)
            local hovered = flags.PRELIGHT == true and sensitive
            local pressed = flags.ACTIVE == true and sensitive

            retarget(env.hover, hovered and 1 or 0)
            retarget(env.press, pressed and 1 or 0)

            self:queue_draw()

            local animating = (hovered or pressed)
                or env.hover.tick_id ~= nil
                or env.press.tick_id ~= nil
                or env.open.tick_id ~= nil
            if not animating then
                env.tick_loop = false
                return false
            end
            return true
        end)
    end)
    if not started then
        env.tick_loop = false
    end
end

--- Creates a halo bound to `button`.
---@param button table Gtk.Button that carries the visual state
---@return table Ignis.M3ButtonHalo
local function new_halo(button, custom_spec)
    local halo = Ignis.M3ButtonHalo({ visible = true })
    local env = base_widget.get_env(halo)
    env.button = button
    env.custom_spec = custom_spec
    env.spec = nil
    env.spec_dirty = true
    env.open_target = 0
    env.press = Spring.new(halo, Spring.Presets.EXPRESSIVE_FAST_SPATIAL, function()
        halo:queue_draw()
    end)
    env.hover = Spring.new(halo, Spring.Presets.EXPRESSIVE_DEFAULT_EFFECTS, function()
        halo:queue_draw()
    end)
    env.open = Spring.new(halo, Spring.Presets.EXPRESSIVE_FAST_SPATIAL, function()
        halo:queue_draw()
    end)

    pcall(function()
        button:connect("notify::css-classes", function()
            env.spec_dirty = true
            halo:queue_draw()
        end)
    end)

    pcall(function()
        button:connect("state-flags-changed", function()
            ensure_tick(halo)
        end)
    end)

    local motion = Gtk.EventControllerMotion()
    motion.on_enter = function()
        ensure_tick(halo)
    end
    motion.on_leave = function()
        ensure_tick(halo)
    end
    pcall(function()
        button:add_controller(motion)
    end)

    pcall(function()
        local legacy = Gtk.EventControllerLegacy()
        legacy:set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        legacy.on_event = function()
            ensure_tick(halo)
            return false -- let the button handle the click
        end
        button:add_controller(legacy)
    end)

    halo:set_draw_func(draw_halo)
    return halo
end

--- Builds the shell overlay for a button: `halo` (painted) below, `content` above.
--- The button itself must keep a transparent background (css class `m3-morphed`
--- is added automatically here).
---@param button table Gtk.Button
---@param content table child widget (icon/label box)
---@return table Ignis.Overlay shell to use as the button's child
local function attach_layout(button, content, custom_spec)
    local halo = new_halo(button, custom_spec)
    base_widget.get_env(halo).content = content
    pcall(function()
        button:add_css_class("m3-morphed")
    end)

    local overlay = Ignis.Overlay({ child = halo })
    if content then
        overlay:add_overlay(content)
    end
    return overlay
end

return {
    attach_layout = attach_layout,
    new_halo = new_halo,          -- exposed for tests/debugging
    paint = draw_halo,            -- exposed for tests/debugging
    palette = palette,            -- so the wallpaper script can invalidate

    --- Attaches the morph shell to an already-built button (raw widgets.Button
    --- with the `.m3-button` classes), wrapping whatever child it has.
    ---@param button table Gtk.Button
    ---@return table the same button
    enhance = function(button, custom_spec)
        pcall(function()
            if button and not button:has_css_class("m3-morphed") then
                local content = nil
                pcall(function()
                    content = button:get_child()
                end)
                if not content then
                    local text = nil
                    pcall(function() text = button:get_label() end)
                    if text and text ~= "" then
                        pcall(function() button.label = "" end)
                        content = Ignis.Label({
                            label = text,
                            css_classes = { "m3-pad", "m3-icon" },
                            halign = "center",
                            valign = "center",
                        })
                    end
                end
                if content then
                    button.child = nil -- detach before re-parenting into the shell
                    button.child = attach_layout(button, content, custom_spec)
                else
                    button:add_css_class("m3-morphed")
                    button.child = new_halo(button, custom_spec)
                end
            end
        end)
        return button
    end,
}
