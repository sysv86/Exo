local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "4.0")
local GLib = lgi.require("GLib")
local base_widget = require("ignis.base_widget")
local Spring = require("ignis.utils.spring")
local engine = require("modules.m3components.shape_engine")

local M = engine

local Ignis = lgi.package("Ignis")
Ignis:class("ShapeBadge", Gtk.DrawingArea)
Ignis:class("LoadingIndicator", Gtk.DrawingArea)

base_widget.apply_to_class(Ignis.ShapeBadge)
base_widget.apply_to_class(Ignis.LoadingIndicator)


local function lerp_contour(a, b, t)
    local out = {}
    for i = 1, math.max(#a, #b) do
        local pa = a[i] or b[i] or { 0.0, 0.0 }
        local pb = b[i] or pa
        out[i] = {
            pa[1] * (1.0 - t) + pb[1] * t,
            pa[2] * (1.0 - t) + pb[2] * t,
        }
    end
    return out
end

local function fill_widget_color(area, cr)
    local ok, color = pcall(function() return area:get_color() end)
    if not (ok and color) then
        local style_ctx = area:get_style_context()
        ok, color = pcall(function() return style_ctx:get_color() end)
    end
    if ok and color then
        cr:set_source_rgba(color.red, color.green, color.blue, color.alpha)
    end
end

local function trace_and_fill(cr, contour, width, height)
    local scale = math.min(width, height)
    local ox, oy = width * 0.5, height * 0.5
    for i = 1, #contour do
        local x = ox + contour[i][1] * scale
        local y = oy + contour[i][2] * scale
        if i == 1 then
            cr:move_to(x, y)
        else
            cr:line_to(x, y)
        end
    end
    cr:close_path()
    cr:fill()
end


function Ignis.ShapeBadge:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.shape = props.shape or "Circle"
    env.from_contour = nil
    env.progress = nil
    env.spring = nil

    self:init_base_widget(props)

    if type(props.size) == "number" then
        self:set_size_request(props.size, props.size)
    end

    if not props.css_classes then
        self:add_css_class("m3-shape-badge")
    end

    self:set_draw_func(function(area, cr, width, height)
        cr:save()
        cr:new_path()
        local from_contour = env.from_contour
        local progress = env.progress
        local shown = engine.contour(env.shape)
        if from_contour and progress and progress < 1.0 then
            shown = lerp_contour(from_contour, shown, progress)
        end
        fill_widget_color(area, cr)
        trace_and_fill(cr, shown, width, height)
        cr:restore()
    end)
end

function Ignis.ShapeBadge:get_shape()
    return base_widget.get_env(self).shape
end

--- Morphs to `shape_name` (one of engine.ALL). `animated` uses the spring.
function Ignis.ShapeBadge:set_shape(shape_name, animated)
    local env = base_widget.get_env(self)
    if type(shape_name) ~= "string" or shape_name == env.shape then
        return
    end
    if not animated then
        env.from_contour = nil
        env.progress = nil
        env.shape = shape_name
        self:queue_draw()
        return
    end
    local from = engine.contour(env.shape)
    env.shape = shape_name
    env.from_contour = from
    if not env.spring then
        env.spring = Spring.new(self, Spring.Presets.EXPRESSIVE_FAST_SPATIAL, function(value)
            env.progress = value
            self:queue_draw()
        end)
    else
        env.spring:stop()
    end
    env.progress = 0.0
    env.spring:set_value(0.0, false)
    env.spring:animate_to(1.0)
end

function M.ShapeBadge(props)
    return Ignis.ShapeBadge(props)
end


local MORPH_STEP = 0.0125  -- per tick at 60 => ~800ms per shape, ~5.6s full cycle

function Ignis.LoadingIndicator:init(props)
    props = props or {}
    local env = base_widget.get_env(self)
    env.seq_idx = 1
    env.from_contour = nil
    env.progress = 1.0
    env.timer_id = nil

    self:init_base_widget(props)

    if type(props.size) == "number" then
        self:set_size_request(props.size, props.size)
    end

    if not props.css_classes then
        self:add_css_class("m3-loading-indicator")
    end
    if props.contained then
        self:add_css_class("contained")
    end

    self:set_draw_func(function(area, cr, width, height)
        cr:save()
        cr:new_path()
        local from_contour = env.from_contour
        local shown = engine.contour(engine.LOADING_SEQUENCE[env.seq_idx])
        if from_contour and env.progress < 1.0 then
            shown = lerp_contour(from_contour, shown, env.progress)
        end
        fill_widget_color(area, cr)
        trace_and_fill(cr, shown, width, height)
        cr:restore()
    end)

    local function step()
        if not self:get_mapped() then
            return true -- hidden: keep timer dormant until shown again
        end
        if env.progress >= 1.0 then
            env.from_contour = engine.contour(engine.LOADING_SEQUENCE[env.seq_idx])
            env.seq_idx = (env.seq_idx % #engine.LOADING_SEQUENCE) + 1
            env.progress = 0.0
        end
        env.progress = math.min(1.0, env.progress + MORPH_STEP)
        self:queue_draw()
        return true
    end

    function self:start_cycle()
        if env.timer_id then
            GLib.source_remove(env.timer_id)
            env.timer_id = nil
        end
        env.seq_idx = 1
        env.from_contour = nil
        env.progress = 1.0
        env.timer_id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 16, step)
    end

    function self:stop_cycle()
        if env.timer_id then
            pcall(GLib.source_remove, env.timer_id)
            env.timer_id = nil
        end
        env.seq_idx = 1
        env.from_contour = nil
        env.progress = 1.0
        self:queue_draw()
    end

    self:connect("map", function() self:start_cycle() end)
    self:connect("unmap", function() self:stop_cycle() end)
    self:connect("destroy", function() self:stop_cycle() end)
end

function M.LoadingIndicator(props)
    return Ignis.LoadingIndicator(props)
end

return M
