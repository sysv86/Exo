local ignis = require("ignis")
local widgets = ignis.widgets
local utils = ignis.utils
local services = ignis.services

local user_settings = require("user_settings")
local m3 = require("modules.m3components")

local mpris = services.MprisService.get_default()

local Player = {}
Player.__index = Player

local function bar_for(bar_id)
    if bar_id == 0 then
        return user_settings.interface.bar
    end
    return user_settings.interface.bar2
end

local function normalize_art_path(art_url)
    if not art_url or art_url == "" then
        return "audio-volume-high"
    end
    if art_url:sub(1, 7) == "file://" then
        local path = art_url:sub(8)
        path = path:gsub("%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
        end)
        return path
    end
    return art_url
end

function Player.new(player, show_labels)
    local self = setmetatable({
        player = player,
        _show_labels = show_labels,
        _last_title = nil,
        _last_artist = nil,
        _last_art = nil,
    }, Player)

    self.icon = widgets.Icon({ css_classes = { "icon" }, valign = "center", pixel_size = 24 })

    self.icon_container = widgets.Box({
        css_classes = { "icon_container" },
        valign = "center",
        child = { self.icon },
    })
    self.icon_container:set_overflow("hidden")

    self.play_pause_label = widgets.Label({
        css_classes = { "overlay-icon" },
        style = "font-family: 'Material Symbols Outlined', 'Material Icons Outlined';",
        halign = "center",
        valign = "center",
    })
    self.overlay_bg = widgets.Box({
        css_classes = { "overlay-bg" },
        halign = "fill",
        valign = "fill",
    })
    self.overlay = widgets.Overlay({
        valign = "center",
        child = self.icon_container,
        overlays = { self.overlay_bg, self.play_pause_label },
        css_classes = { "media-overlay" },
    })

    self.title_label = widgets.Label({
        css_classes = { "title" },
        valign = "end",
        halign = "start",
        ellipsize = "end",
        max_width_chars = 24,
    })
    self.artist_label = widgets.Label({
        css_classes = { "artist" },
        valign = "end",
        halign = "start",
        ellipsize = "end",
        max_width_chars = 24,
    })

    self.labels_box = widgets.Box({
        vertical = true,
        spacing = 0,
        valign = "center",
        vexpand = true,
        child = { self.title_label, self.artist_label },
    })

    self.box = widgets.Box({
        vertical = false,
        spacing = 5,
        valign = "center",
        homogeneous = false,
        vexpand = true,
        child = { self.overlay, self.labels_box },
    })

    self.player:connect("notify::title", function()
        self:update_labels_and_icon()
    end)
    self.player:connect("notify::artist", function()
        self:update_labels_and_icon()
    end)
    self.player:connect("notify::art_url", function()
        self:update_labels_and_icon()
    end)
    self.player:connect("notify::playback_status", function()
        self:on_playback_status_changed()
    end)

    self:update_labels_and_icon()
    self:on_playback_status_changed()
    self:update_layout()

    return self
end

function Player:update_labels_and_icon()
    local title = tostring(self.player.title or "")
    local artist = tostring(self.player.artist or "")
    local art = normalize_art_path(self.player.art_url)

    local changed = false
    if title ~= self._last_title then
        self._last_title = title
        self.title_label:set_label(title)
        changed = true
    end
    if artist ~= self._last_artist then
        self._last_artist = artist
        self.artist_label:set_label(artist)
        changed = true
    end
    if art ~= self._last_art then
        self._last_art = art
        self.icon:set_image(art)
    end

    if changed then
        self:update_tooltip()
    end
end

function Player:update_tooltip()
    local parent = self.box:get_parent()
    if not parent then return end

    if not self._show_labels then
        parent:set_tooltip_text(string.format("%s\nby %s", tostring(self.player.title), tostring(self.player.artist)))
    else
        parent:set_tooltip_text("")
    end
end

function Player:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.media)
    local vertical = bar.vertical

    if self._show_labels and not vertical then
        self.labels_box:set_visible(true)
        if bar.density > 0 then
            self.artist_label:set_visible(false)
            self.icon:set_pixel_size(16)
            self.icon_container:set_size_request(16, 16)
            self.play_pause_label:set_size_request(16, 16)
        else
            self.artist_label:set_visible(true)
            self.icon:set_pixel_size(24)
            self.icon_container:set_size_request(24, 24)
            self.play_pause_label:set_size_request(24, 24)
        end
    else
        self.labels_box:set_visible(false)
        if bar.density > 0 then
            self.icon:set_pixel_size(16)
            self.icon_container:set_size_request(16, 16)
            self.play_pause_label:set_size_request(16, 16)
        else
            self.icon:set_pixel_size(24)
            self.icon_container:set_size_request(24, 24)
            self.play_pause_label:set_size_request(24, 24)
        end
    end

    self:update_tooltip()
end

function Player:on_playback_status_changed()
    local status = self.player.playback_status
    if status == "Playing" or status == "Paused" then
        self.play_pause_label:set_visible(true)
        self.overlay_bg:set_visible(true)
        if status == "Playing" then
            self.play_pause_label:set_label("pause")
            self.box:remove_css_class("is-paused")
        else
            self.play_pause_label:set_label("play_arrow")
            self.box:add_css_class("is-paused")
        end
    else
        self.play_pause_label:set_visible(false)
        self.overlay_bg:set_visible(false)
        self.box:remove_css_class("is-paused")
    end
end

function Player:widget()
    return self.box
end


local Media = {}
Media.__index = Media

function Media.new()
    return setmetatable({
        _player_count = 0,
        _main_box = nil,
        _players = {},
    }, Media)
end

function Media:_setup(widget)
    self._main_box = widget
    mpris:connect("player-added", function()
        self:_poll_players()
    end)
    utils.Poll(2000, function()
        self:_poll_players()
    end)
    self:_update_players()
    self:update_layout()
end

function Media:update_layout()
    local bar = bar_for(user_settings.interface.modules.bar_id.media)
    if not self._main_box then return end

    if bar.vertical then
        self._main_box:set_vertical(true)
        self._main_box.width_request = -1
    else
        self._main_box:set_vertical(false)
        self._main_box.width_request = bar.centered and 150 or -1
    end

    for _, player in ipairs(self._players) do
        player:update_layout()
    end
end

function Media:_poll_players()
    local count = #(mpris.players or {})
    if count ~= self._player_count then
        self._player_count = count
        self:_update_players()
    end
end

function Media:_update_players()
    if not self._main_box then return end
    if not user_settings.interface.modules.visibility.media then return end

    local players = mpris.players or {}
    self._main_box:set_visible(#players > 0)

    self._main_box:set_child({})
    self._players = {}

    for index, player in ipairs(players) do
        self:_add_player(player, index == #players)
    end
end

function Media:_add_player(player_obj, show_labels)
    local player = Player.new(player_obj, show_labels)
    self._players[#self._players + 1] = player

    local player_button = widgets.Button({
        child = player:widget(),
        vexpand = true,
        halign = "center",
        on_click = function()
            player_obj:play_pause()
        end,
        css_classes = { "media" },
    })

    m3.enhance_button(player_button, {
        ink = "on_surface",
        hover_bg = "secondary_container",
        hover_ink = "on_secondary_container",
        radius = { rest = "pill", hover = 12, press = 8 },
    })

    self._main_box:append(player_button)
end

function Media:widget()
    return widgets.Box({
        vertical = false,
        setup = function(widget)
            self:_setup(widget)
        end,
    })
end

return Media
