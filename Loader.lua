repeat task.wait() until game.IsLoaded
repeat task.wait() until game.GameId ~= 0

if Radical and Radical.Loaded then
    Radical.Utilities.UI:Push({
        Title = "Radical Hub | Error (0x1)",
        Description = "Script already running!",
        Duration = 5
    }) return
end

if Radical and (Radical.Game and not Radical.Loaded) then
    Radical.Utilities.UI:Push({
        Title = "Radical Hub | Error (0x2)",
        Description = "Something went wrong!",
        Duration = 5
    }) return
end

local PlayerService = game:GetService("Players")
repeat task.wait() until PlayerService.LocalPlayer
local LocalPlayer = PlayerService.LocalPlayer

local Branch, NotificationTime, IsLocal = ...
--local ClearTeleportQueue = clear_teleport_queue
local QueueOnTeleport = queue_on_teleport

local function GetFile(File)
    return IsLocal and readfile("Radical/" .. File)
    or game:HttpGet(("%s%s"):format(Radical.Source, File))
end

local function LoadScript(Script)
    local code = GetFile(Script .. ".lua")
    if not code then
        error("Failed to load " .. Script .. ".lua")
    end
    local fn = loadstring(code, Script)
    if not fn then
        error("Failed to compile " .. Script .. ".lua")
    end
    return fn()
end

local function GetGameInfo()
    for Id, Info in pairs(Radical.Games) do
        if tostring(game.GameId) == Id then
            return Info
        end
    end

    return Radical.Games.Universal
end

getgenv().Radical = {
    Source = "https://raw.githubusercontent.com/getrenv/radicalcuck/" .. Branch .. "/",

    Games = {
        ["Universal" ] = { Name = "Universal",                  Script = "Universal"  },
        ["1168263273"] = { Name = "Bad Business",               Script = "Games/BB"   },
        ["3360073263"] = { Name = "Bad Business PTR",           Script = "Games/BB"   },
        ["1586272220"] = { Name = "Steel Titans",               Script = "Games/ST"   },
        ["807930589" ] = { Name = "The Wild West",              Script = "Games/TWW"  },
        ["580765040" ] = { Name = "RAGDOLL UNIVERSE",           Script = "Games/RU"   },
        ["187796008" ] = { Name = "Those Who Remain",           Script = "Games/TWR"  },
        ["358276974" ] = { Name = "Apocalypse Rising 2",        Script = "Games/AR2"  },
        ["3495983524"] = { Name = "Apocalypse Rising 2 Dev.",   Script = "Games/AR2"  },
        ["1054526971"] = { Name = "Blackhawk Rescue Mission 5", Script = "Games/BRM5" }
    }
}

Radical.Utilities = LoadScript("Utilities/Main")
Radical.Utilities.UI = LoadScript("Utilities/UI")
Radical.Utilities.Physics = LoadScript("Utilities/Physics")
Radical.Utilities.Drawing = LoadScript("Utilities/Drawing")

if not Radical.Utilities or not Radical.Utilities.UI or not Radical.Utilities.Physics or not Radical.Utilities.Drawing then
    error("Failed to load one or more utilities")
end

Radical.Cursor = GetFile("Utilities/ArrowCursor.png")
Radical.Loadstring = GetFile("Utilities/Loadstring")
Radical.Loadstring = Radical.Loadstring:format(
    Radical.Source, Branch, NotificationTime, tostring(IsLocal)
)

LocalPlayer.OnTeleport:Connect(function(State)
    if State == Enum.TeleportState.InProgress then
        pcall(function()
            if getgenv().Radical and getgenv().Radical.Utilities and type(getgenv().Radical.Utilities.Cleanup) == "function" then
                getgenv().Radical.Utilities.Cleanup()
            end
        end)
        QueueOnTeleport(Radical.Loadstring)
    end
end)

Radical.Game = GetGameInfo()
local success, err = pcall(LoadScript, Radical.Game.Script)
if not success then
    warn("Failed to load game script: " .. tostring(err))
    return
end
Radical.Loaded = true

Radical.Utilities.UI:Push({
    Title = "Radical Hub",
    Description = Radical.Game.Name .. " loaded!",
    Duration = NotificationTime
})
