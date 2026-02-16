local Version = require("Starlit/Version")


Events.OnGameStart.Add(function()
    Version.ensureVersion(1, 5, 0)
end)
