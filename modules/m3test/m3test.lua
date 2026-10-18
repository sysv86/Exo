local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils

local m3 = require("modules.m3components")
local Button = m3.Button
local Slider = m3.Slider
local Shapes = m3.Shapes

local M3Test = {}
M3Test.__index = M3Test

local function category(label)
    return widgets.Label({
        label = label,
        halign = "start",
        css_classes = { "settings-category-label" },
    })
end

local function button_row(icon, size, label)
    local variants = { "elevated", "filled", "tonal", "outlined", "text" }
    local names = { "Elevated", "Filled", "Tonal", "Outlined", "Text" }
    local result = {}
    for index, variant in ipairs(variants) do
        result[#result + 1] = Button.button({
            icon = icon,
            label = label and names[index] or nil,
            type = variant,
            size = size,
        })
    end
    return widgets.Box({
        spacing = 8,
        halign = "start",
        valign = "center",
        child = result,
    })
end

function M3Test.new()
    local self = setmetatable({}, M3Test)

    local children = {}

    local bench_lbl = widgets.Label({
        label = "Measuring C11 telemetry & analytical spring solver...",
        halign = "start",
        css_classes = { "m3-studio-bench", "monospace-num" },
    })

    local function run_benchmark()
        local t0 = utils.monotonic_us()
        for _ = 1, 100 do
            utils.read_sys_telemetry()
        end
        local t1 = utils.monotonic_us()
        local tel_us = (t1 - t0) / 100.0

        local s0 = utils.monotonic_us()
        local x, v = 0.0, 0.0
        for _ = 1, 10000 do
            x, v = ignis.Spring.solve(x, v, 1.0, 0.6, 800.0, 0.00833)
        end
        local s1 = utils.monotonic_us()
        local spring_us = (s1 - s0) / 10000.0

        bench_lbl.label = string.format(
            "C11 Telemetry: %.1f µs/call (0 forks)  •  Analytical Spring.solve: %.3f µs/step",
            tel_us, spring_us
        )
    end
    run_benchmark()

    children[#children + 1] = widgets.Box({
        spacing = 12,
        valign = "center",
        css_classes = { "m3-studio-header-card" },
        child = {
            m3.LoadingIndicator({ size = 40, contained = true }),
            widgets.Box({
                vertical = true,
                spacing = 2,
                hexpand = true,
                child = {
                    widgets.Label({
                        label = "Material 3 Expressive Developer Studio",
                        halign = "start",
                        css_classes = { "m3-studio-title" },
                    }),
                    bench_lbl,
                },
            }),
            Button.button({
                icon = "speed",
                label = "Re-run Benchmark",
                type = "tonal",
                size = "xs",
                on_click = run_benchmark,
            }),
        },
    })

    children[#children + 1] = category("35 Material 3 Expressive Shapes & Spring Morphing (Cairo)")
    local shape_idx = 1
    local hero_shape = m3.ShapeBadge({
        shape = Shapes.ALL[1],
        size = 64,
        css_classes = { "m3-studio-hero-shape" },
    })
    local hero_name = widgets.Label({
        label = Shapes.ALL[1] .. " (1 / 35)",
        css_classes = { "m3-studio-chip", "monospace-num" },
    })

    local featured_shapes = {
        "SoftBurst", "Cookie9Sided", "Pentagon", "Pill", "Sunny", "Cookie4Sided",
        "Oval", "Clover4Leaf", "Gem", "VerySunny", "Bun", "Heart",
    }
    local shape_buttons = {}
    for _, sname in ipairs(featured_shapes) do
        local target_shape = sname
        shape_buttons[#shape_buttons + 1] = Button.button({
            label = target_shape,
            type = "surface",
            size = "xs",
            shape = "square",
            on_click = function()
                hero_shape:set_shape(target_shape, true)
                hero_name.label = target_shape
            end,
        })
    end

    children[#children + 1] = widgets.Box({
        spacing = 16,
        valign = "center",
        css_classes = { "m3-studio-shape-card" },
        child = {
            widgets.Box({
                vertical = true,
                spacing = 6,
                valign = "center",
                halign = "center",
                child = {
                    hero_shape,
                    hero_name,
                    Button.button({
                        icon = "auto_awesome",
                        label = "Cycle All 35",
                        type = "filled",
                        size = "xs",
                        on_click = function()
                            shape_idx = (shape_idx % #Shapes.ALL) + 1
                            local sname = Shapes.ALL[shape_idx]
                            hero_shape:set_shape(sname, true)
                            hero_name.label = string.format("%s (%d / 35)", sname, shape_idx)
                        end,
                    }),
                },
            }),
            widgets.Box({
                vertical = true,
                spacing = 6,
                valign = "center",
                child = {
                    widgets.Box({ spacing = 6, child = { shape_buttons[1], shape_buttons[2], shape_buttons[3], shape_buttons[4], shape_buttons[5], shape_buttons[6] } }),
                    widgets.Box({ spacing = 6, child = { shape_buttons[7], shape_buttons[8], shape_buttons[9], shape_buttons[10], shape_buttons[11], shape_buttons[12] } }),
                },
            }),
        },
    })

    children[#children + 1] = category("Connected Button Groups, SplitButton & Floating Toolbar")
    local group_children = {}
    local group_labels = { "Code", "Build", "Test", "Profile", "Deploy" }
    local group_icons = { "code", "terminal", "science", "speed", "rocket_launch" }
    for index = 1, 5 do
        local btn
        btn = Button.button({
            icon = group_icons[index],
            label = group_labels[index],
            shape = "square",
            css_classes = index == 1 and { "active" } or {},
            on_click = function()
                for _, other in ipairs(group_children) do
                    other:remove_css_class("active")
                end
                btn:add_css_class("active")
            end,
        })
        group_children[#group_children + 1] = btn
    end

    children[#children + 1] = widgets.Box({
        spacing = 12,
        valign = "center",
        child = {
            Button.connected_group(group_children),
            m3.SplitButton.new({
                icon = "play_arrow",
                label = "Run Target",
                type = "filled",
                size = "s",
            }),
            m3.FloatingToolbar.new({
                variant = "vibrant",
                items = {
                    { icon = "home", active = true },
                    { icon = "terminal" },
                    { separator = true },
                    { icon = "settings" },
                },
            }),
        },
    })

    children[#children + 1] = category("Button Variants (Elevated, Filled, Tonal, Outlined, Text)")
    children[#children + 1] = button_row("edit", "s", true)

    children[#children + 1] = category("5 Official Size Tiers (XS 32dp · S 38dp · M 48dp · L 64dp · XL 84dp)")
    children[#children + 1] = widgets.Box({
        spacing = 10,
        valign = "center",
        child = {
            Button.button({ icon = "bolt", label = "XS", type = "filled", size = "xs" }),
            Button.button({ icon = "star", label = "Small", type = "filled", size = "s" }),
            Button.button({ icon = "palette", label = "Medium", type = "tonal", size = "m" }),
            Button.button({ icon = "layers", label = "Large", type = "outlined", size = "l" }),
            Button.button({ icon = "auto_awesome", label = "XL", type = "elevated", size = "xl", shape = "square" }),
        },
    })

    children[#children + 1] = category("Expressive Switches, Checkboxes & Thick-Track Sliders")
    children[#children + 1] = widgets.Box({
        spacing = 16,
        valign = "center",
        child = {
            widgets.Switch({ halign = "center" }),
            widgets.Switch({ active = true, halign = "center" }),
            widgets.CheckButton({ label = "Checkbox Off", halign = "center" }),
            widgets.CheckButton({ label = "Checkbox On", active = true, halign = "center" }),
        },
    })
    children[#children + 1] = Slider.slider({ min = 0, max = 100, value = 68, icon = "volume_up" })

    self.window = widgets.RegularWindow({
        css_classes = { "m3-testing-window" },
        hide_on_close = true,
        visible = false,
        default_width = 880,
        default_height = 680,
        title = "Exo — Material 3 Expressive Developer Studio",
        namespace = "M3Test",
        child = widgets.Scroll({
            child = widgets.Box({
                style = "padding: 20px;",
                vertical = true,
                spacing = 12,
                halign = "fill",
                child = children,
            }),
        }),
    })

    return self
end

return M3Test
