local user_settings = require("user_settings")

local LauncherLayout = {
    launcher_instance = nil,
}

function LauncherLayout.set_launcher_instance(launcher)
    LauncherLayout.launcher_instance = launcher
end

---@param layout string "grid" | "list"
function LauncherLayout.set_layout(layout)
    if layout ~= "grid" and layout ~= "list" then
        print(string.format("Invalid layout: %s. Must be 'grid' or 'list'.", tostring(layout)))
        return
    end

    user_settings.interface.launcher.layout = layout
    if LauncherLayout.launcher_instance then
        LauncherLayout.launcher_instance:_set_layout(layout)
    end
end

return LauncherLayout
