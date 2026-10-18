local ignis = require("ignis")
local services = ignis.services

local niri = services.NiriService.get_default()
local hyprland = services.HyprlandService.get_default()

local M = {
    niri = niri,
    hyprland = hyprland,
    kind = nil,
    service = nil,
}

if niri.is_available then
    M.kind = "niri"
    M.service = niri
elseif hyprland.is_available then
    M.kind = "hyprland"
    M.service = hyprland
end

function M.is_available()
    return M.service ~= nil
end

--- The workspace currently displayed/focused, or nil.
function M.active_workspace()
    if M.kind == "niri" then
        if M.service.active_workspace then
            return M.service.active_workspace
        end
        for _, workspace in ipairs(M.service.workspaces or {}) do
            if workspace.is_active then
                return workspace
            end
        end
        return nil
    elseif M.kind == "hyprland" then
        return M.service.active_workspace
    end
    return nil
end

--- Stable numeric id of a workspace (`idx` on Niri, `id` on Hyprland).
function M.workspace_id(workspace)
    if not workspace then return nil end
    if M.kind == "niri" then
        return workspace.idx or workspace.id
    end
    return workspace.id
end

--- Numeric id of a window's workspace.
function M.window_workspace_id(window)
    if not window then return nil end
    return window.workspace_id
end

--- Window title, or "" when unset.
function M.window_title(window)
    if not window then return nil end
    return window.title
end

--- Application id of a window (`app_id` on Niri, `class` on Hyprland).
function M.window_app_id(window)
    if not window then return nil end
    if M.kind == "niri" then
        return window.app_id
    end
    return window.class or window.class_name
end

--- Window process ID (`pid`) if available.
function M.window_pid(window)
    if not window then return nil end
    local pid = tonumber(window.pid)
    if pid and pid > 0 then return pid end
    return nil
end

--- Whether a window is floating.
function M.window_is_floating(window)
    if not window then return false end
    if M.kind == "niri" then
        return window.is_floating == true
    end
    return window.floating == true
end

--- Short keyboard layout code ("EN", "RU", etc.).
function M.active_kb_layout()
    if not M.service then return "EN" end
    return M.service.active_kb_layout or "EN"
end

--- Full keyboard layout name ("English (US)", "Russian", etc.).
function M.kb_layout_full()
    if not M.service then return "English (US)" end
    return M.service.kb_layout or "English (US)"
end

--- Switches to the next XKB keyboard layout.
function M.switch_kb_layout()
    if not M.service then return end
    if M.service.switch_kb_layout then
        M.service:switch_kb_layout()
    end
end

--- All windows on a given workspace.
function M.windows_on_workspace(workspace_id)
    if not M.service then return {} end
    if M.kind == "niri" then
        local result = {}
        for _, window in ipairs(M.service.windows or {}) do
            if window.workspace_id == workspace_id then
                result[#result + 1] = window
            end
        end
        return result
    end
    return M.service:get_windows_on_workspace(workspace_id) or {}
end

--- All workspaces keyed by their numeric id.
function M.workspaces_by_id()
    local map = {}
    for _, workspace in ipairs(M.service and M.service.workspaces or {}) do
        map[M.workspace_id(workspace)] = workspace
    end
    return map
end

--- Switches to a workspace by numeric id.
function M.switch_to_workspace(id)
    if not M.service then return end
    M.service:switch_to_workspace(id)
end

--- Focuses a window.
function M.focus_window(window)
    if not window then return end
    if M.kind == "niri" then
        M.service:focus_window(window.id)
    else
        M.service:send_command("dispatch focuswindow address:" .. tostring(window.address))
    end
end

--- Compares two application ids loosely ("firefox" matches "firefox-esr").
function M.is_same_app(id1, id2)
    if not id1 or not id2 or id1 == "" or id2 == "" then
        return false
    end
    local a, b = id1:lower(), id2:lower()
    return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

return M
