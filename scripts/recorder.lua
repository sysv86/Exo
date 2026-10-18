local ignis = require("ignis")
local utils = ignis.utils
local services = ignis.services

local user_settings = require("user_settings")
local send_notification = require("scripts.send_notification")

local command_manager = ignis.CommandManager.get_default()
local recorder = services.RecorderService.get_default()
local RecorderConfig = services.RecorderConfig

local M = {}

local last_recording_path = nil
local recording_indicator_instance = nil

local function options()
    return user_settings.services.recorder
end

--- Registers the bar's recording indicator so it can follow recorder state.
---@param indicator table
function M.set_indicator(indicator)
    recording_indicator_instance = indicator
end

local function on_recording_started()
    if recording_indicator_instance then
        recording_indicator_instance:set_paused(false)
        if user_settings.interface.modules.options.recording_indicator ~= "never" then
            recording_indicator_instance:start_timer()
        end
    end

    if options().start_notification then
        send_notification("Recording Started", string.format("Recording to: %s", tostring(last_recording_path)))
    end
end

local function on_recording_stopped()
    if recording_indicator_instance then
        recording_indicator_instance:stop_timer()
    end

    if last_recording_path and options().stop_notification then
        send_notification("Recording Stopped", string.format("Recording saved to: %s", tostring(last_recording_path)))
    end

    last_recording_path = nil
end

local function update_pause_state()
    if recording_indicator_instance then
        recording_indicator_instance:set_paused(recorder.is_paused)
    end
end

local function start_recording_task(source, file_path, extra)
    local config = RecorderConfig({
        source = source,
        path = file_path,
        audio_devices = options().record_audio and { "default_output" } or {},
    })
    for key, value in pairs(extra or {}) do
        config[key] = value
    end

    local ok, err = pcall(function()
        recorder:start_recording(config)
    end)
    if not ok then
        if recording_indicator_instance then
            recording_indicator_instance:stop_timer()
        end
        last_recording_path = nil
        send_notification("Recording Error", string.format("An unexpected error occurred: %s", tostring(err)))
    end
end

local function record_source(source, extra)
    if not recorder.is_available then
        send_notification("No recorder", "gpu-screen-recorder was not found.")
        return
    end

    if recorder.active then
        recorder:stop_recording()
        return
    end

    local file_path = (os.getenv("HOME") or ".") .. "/Videos/recording_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".mp4"
    last_recording_path = file_path

    start_recording_task(source, file_path, extra)
end

--- Stops an active recording.
function M.stop_recording()
    if recorder.active then
        recorder:stop_recording()
    end
end

--- Pauses an active recording.
function M.pause_recording()
    if recorder.active and not recorder.is_paused then
        recorder:pause_recording()
        update_pause_state()
    end
end

--- Resumes a paused recording.
function M.unpause_recording()
    if recorder.active and recorder.is_paused then
        recorder:continue_recording()
        update_pause_state()
    end
end

--- Records the whole screen.
function M.record_screen()
    record_source("screen")
end

--- Records through the xdg-desktop-portal picker (Niri "window" recording).
function M.record_portal()
    record_source("portal")
end

--- Selects a region with `slurp` and records it.
function M.record_region()
    if recorder.active then
        recorder:stop_recording()
        return
    end

    send_notification("Region Selection", "Please select a region to record.")

    local result = utils.exec_sh("slurp")
    local returncode = result and result.returncode or -1
    local stdout = (result and result.stdout or ""):gsub("%s+$", "")

    if returncode ~= 0 then
        if returncode == 127 then
            send_notification("Dependency Missing",
                "The 'slurp' tool is required for region recording but was not found.")
        else
            send_notification("Region Selection Canceled", "No region was selected or an error occurred.")
        end
        return
    end

    if stdout == "" then
        send_notification("Region Selection Canceled", "No region was selected.")
        return
    end

    local xy, wh = stdout:match("^(%S+)%s+(%S+)$")
    if not xy then
        send_notification("Region Selection Error", "Could not parse the selected region.")
        return
    end
    local x, y = xy:match("^(%-?%d+),(%-?%d+)$")
    if not x then
        send_notification("Region Selection Error", "Could not parse the selected region.")
        return
    end

    record_source("region", { region = string.format("%s+%s+%s", wh, x, y) })
end

--- Registers the recorder CLI commands.
function M.setup_commands()
    command_manager:add_command("recorder-record-screen", M.record_screen)
    command_manager:add_command("recorder-record-portal", M.record_portal)
    command_manager:add_command("recorder-record-region", M.record_region)
end

--- Wires the recorder's signals to notifications and the bar indicator.
function M.setup_signals()
    recorder:connect("recording-started", function()
        on_recording_started()
    end)
    recorder:connect("recording-stopped", function()
        on_recording_stopped()
    end)
end

M.setup_commands()
M.setup_signals()

M.recorder = recorder

return M
