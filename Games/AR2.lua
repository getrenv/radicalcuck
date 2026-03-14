local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")

task.spawn(function()
    for Index, Connection in pairs(getconnections(game:GetService("ScriptContext").Error)) do
        Connection:Disable()
    end
    while task.wait(1) do
        for Index, Connection in pairs(getconnections(game:GetService("ScriptContext").Error)) do
            Connection:Disable()
        end
    end
end)

local Camera = Workspace.CurrentCamera
local LocalPlayer = PlayerService.LocalPlayer
local Aimbot, SilentAim, Trigger = false, nil, nil

local Mannequin = ReplicatedStorage.Assets.Mannequin
local Vehicles = Workspace.Vehicles -- FIXED: was Workspace.Vehicles.Spawned
local Characters = Workspace.Characters
local Corpses = Workspace.Corpses
local Zombies = Workspace.Zombies

-- FIXED: LootBins, Randoms, and Loot removed (paths no longer exist)

local Framework = require(ReplicatedFirst:WaitForChild("Framework"))
Framework:WaitForLoaded()

repeat task.wait() until Framework.Classes.Players.get()
local PlayerClass = Framework.Classes.Players.get()

local Globals = Framework.Configs.Globals
local World = Framework.Libraries.World
local Network = Framework.Libraries.Network
local Cameras = Framework.Libraries.Cameras
local Bullets = Framework.Libraries.Bullets
local Lighting = Framework.Libraries.Lighting
local Interface = Framework.Libraries.Interface
local Resources = Framework.Libraries.Resources
local Raycasting = Framework.Libraries.Raycasting

local Maids = Framework.Classes.Maids
local Animators = Framework.Classes.Animators
local VehicleController = Framework.Classes.VehicleControler

local Firearm = nil
task.spawn(function() setthreadidentity(2) Firearm = require(ReplicatedStorage.Client.Abstracts.ItemInitializers.Firearm) end)
if not Firearm then LocalPlayer:Kick("Send this error to owner: Firearm module does not exist") return end
local CharacterCamera = Cameras:GetCamera("Character")

local Events = getupvalue(Network.Add, 1)
local GetSpreadAngle = getupvalue(Bullets.Fire, 1)
local GetSpreadVector = getupvalue(Bullets.Fire, 3)
local CastLocalBullet = getupvalue(Bullets.Fire, 4)
local GetFireImpulse = getupvalue(Bullets.Fire, 6)
local LightingState = getupvalue(Lighting.GetState, 1)
local AnimatedReload = getupvalue(Firearm, 7)

local SetWheelSpeeds = getupvalue(VehicleController.Step, 2)
local SetSteerWheels = getupvalue(VehicleController.Step, 3)

local Effects = getupvalue(CastLocalBullet, 2)
local Sounds = getupvalue(CastLocalBullet, 3)
local ImpactEffects = getupvalue(CastLocalBullet, 6)

if type(Events) == "function" then
    Events = getupvalue(Network.Add, 2)
end

local NetworkSyncHeartbeat
local InteractHeartbeat, FindItemData
for Index, Table in pairs(getgc(true)) do
    if type(Table) == "table" and rawget(Table, "Rate") == 0.05 then
        InteractHeartbeat = Table.Action
        FindItemData = getupvalue(InteractHeartbeat, 11)
    end
end

local ProjectileSpeed = 1000
local ProjectileOrigin = Vector3.new(0, 0, 0)
local ProjectileDirection = Vector3.new(0, 0, 0)
local ProjectileSpread = Vector3.new(0, 0, 0)
local ShotMaxDistance = Globals.ShotMaxDistance
local ProjectileGravity = Globals.ProjectileGravity

local SquadData = nil
local ItemMemory = {}
local GroundPart = Instance.new("Part")
local OldBaseTime = LightingState.BaseTime
local NoClipObjects, NoClipEvent = {}, nil
local SetIdentity = setthreadidentity

local AddObject = Instance.new("BindableEvent")
AddObject.Event:Connect(function(...)
    Radical.Utilities.Drawing:AddObject(...)
end)

local RemoveObject = Instance.new("BindableEvent")
RemoveObject.Event:Connect(function(...)
    Radical.Utilities.Drawing:RemoveObject(...)
end)

-- FIXED: helper to resolve a player's character via Workspace.Players[Name] first, fallback to Player.Character
local WPlayersFolder = Workspace:FindFirstChild("Players")
local function GetPlayerCharacter(Player)
    if WPlayersFolder then
        local pf = WPlayersFolder:FindFirstChild(Player.Name)
        if pf then
            if pf:FindFirstChild("HumanoidRootPart") then return pf end
            local sc = pf:FindFirstChild("StarterCharacter")
            if sc then return sc end
        end
    end
    return Player.Character
end

local RandomEvents, ItemCategory, ZombieInherits, SanityBans, AdminRoles = {
    {"ATVCrashsiteRenegade01", false},
    {"BankTruckRobbery01", false},
    {"BeachedAluminumBoat01", false},
    {"BeechcraftGemBroker01", false},
    {"C-123ProviderMilitary01", true},
    {"C-123ProviderMilitary02", true},
    {"CampSovietBandit01", true},
    {"ConstructionWorksite01", false},
    {"CrashEasterBus01", true},
    {"CrashPrisonBus01", false},
    {"EasterNestEvent01", true},
    {"FuddCampsite01", false},
    {"FuneralProcession01", false},
    {"GraveFresh01", false},
    {"GraveNumberOne1", false},
    {"LifePreserverMilitary01", true},
    {"LifePreserverSoviet01", true},
    {"LifePreserverSpecOps01", true},
    {"LongswordStone01", true},
    {"MilitaryBlockade01", true},
    {"MilitaryConvoy01", true},
    {"ParamedicScene01", false},
    {"PartyTrailerDisco01", true},
    {"PartyTrailerTechnoGold", true},
    {"PartyTrailerTechnoGoldDeagleMod1", true},
    {"PirateTreasure01", true},
    {"PoliceBlockade01", false},
    {"PoolsClosed01", false},
    {"PopupCampsite01", false},
    {"PopupFishing01", false},
    {"PopupFishing02", false},
    {"RandomCrashCessna01", false},
    {"SeahawkCrashsite04", true},
    {"SeahawkCrashsite05", true},
    {"SeahawkCrashsite06", true},
    {"SeahawkCrashsite07", true},
    {"SeahawkCrashsiteRogue01", true},
    {"SedanHaul01", false},
    {"SpecialForcesCrash01", true},
    {"StashFood01", false},
    {"StashFood02", false},
    {"StashFood03", false},
    {"StashGeneral01", false},
    {"StashGeneral02", false},
    {"StashGeneral03", false},
    {"StashMedical01", false},
    {"StashMedical02", false},
    {"StashMedical03", false},
    {"StashWeaponHigh01", false},
    {"StashWeaponHigh02", false},
    {"StashWeaponHigh03", false},
    {"StashWeaponMid01", false},
    {"StashWeaponMid02", false},
    {"StashWeaponMid03", false},
    {"StrandedStation01", false},
    {"StrandedStationKeyboard01", false},
    {"ValentinesBachelor01", false}
},
{
    {"Containers", false}, {"Accessories", true}, {"Ammo", false}, {"Attachments", false},
    {"Backpacks", false}, {"Belts", true}, {"Clothing", true}, {"Consumables", true},
    {"Firearms", false}, {"Hats", true}, {"Medical", false}, {"Melees", false},
    {"Miscellaneous", false}, {"Utility", false}, {"VehicleParts", false}, {"Vests", true}
},
{
    {"Presets.Behavior Boss Level 01", true}, {"Presets.Behavior Boss Level 02", true}, {"Presets.Behavior Boss Level 03", true},
    {"Presets.Behavior Common Level 01", false}, {"Presets.Behavior Common Level 02", false}, {"Presets.Behavior Common Level 03", false},
    {"Presets.Behavior Common Thrall Level 01", false}, {"Presets.Behavior MiniBoss Level 01", false}, {"Presets.Behavior MiniBoss Level 02", false},
    {"Presets.Skin Tone Dark", false}, {"Presets.Skin Tone Dark Servant", false}, {"Presets.Skin Tone Light", false}, {"Presets.Skin Tone LightMid", false},
    {"Presets.Skin Tone LightMidDark", false}, {"Presets.Skin Tone Mid", false}, {"Presets.Skin Tone MidDark", false}, {"Presets.Skin Tone Servant", false}
},
{
    "Chat Message Send", "Ping Return", "Bullet Impact Interaction", "Crouch Audio Mute", "Zombie Pushback Force Request", "Camera CFrame Report",
    "Movestate Sync Request", "Update Character Position", "Map Icon History Sync", "Playerlist Staff Icon Get", "Request Physics State Sync",
    "Inventory Sync Request", "Wardrobe Resync Request", "Door Interact ", "Sorry Mate, Wrong Path :/"
},
{
    [110] = "Contractor",
    [120] = "Moderator",
    [125] = "Senior Moderator",
    [130] = "Administrator",
    [160] = "Chief Administrator",
    [200] = "Developer",
    [255] = "Host"
}

local KnownBodyParts = {
    {"Head", true}, {"HumanoidRootPart", true},
    {"UpperTorso", false}, {"LowerTorso", false},

    {"RightUpperArm", false}, {"RightLowerArm", false}, {"RightHand", false},
    {"LeftUpperArm", false}, {"LeftLowerArm", false}, {"LeftHand", false},

    {"RightUpperLeg", false}, {"RightLowerLeg", false}, {"RightFoot", false},
    {"LeftUpperLeg", false}, {"LeftLowerLeg", false}, {"LeftFoot", false}
}

local Window = Radical.Utilities.UI:Window({
    Name = ("Radical AR2 [BETA] %s %s"):format(utf8.char(8212), Radical.Game.Name),
    Position = UDim2.new(0.5, -248 * 3, 0.5, -248)
}) do

    local CombatTab = Window:Tab({Name = "Combat"}) do
        local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = "Left"}) do
            AimbotSection:Toggle({Name = "Enabled", Flag = "Aimbot/Enabled", Value = false})
            :Keybind({Flag = "Aimbot/Keybind", Value = "MouseButton2", Mouse = true, DisableToggle = true,
            Callback = function(Key, KeyDown) Aimbot = Window.Flags["Aimbot/Enabled"] and KeyDown end})

            AimbotSection:Toggle({Name = "Always Enabled", Flag = "Aimbot/AlwaysEnabled", Value = false})
            AimbotSection:Toggle({Name = "Prediction", Flag = "Aimbot/Prediction", Value = true})

            AimbotSection:Toggle({Name = "Team Check", Flag = "Aimbot/TeamCheck", Value = false})
            AimbotSection:Toggle({Name = "Distance Check", Flag = "Aimbot/DistanceCheck", Value = false})
            AimbotSection:Toggle({Name = "Visibility Check", Flag = "Aimbot/VisibilityCheck", Value = false})
            AimbotSection:Slider({Name = "Sensitivity", Flag = "Aimbot/Sensitivity", Min = 0, Max = 100, Value = 20, Unit = "%"})
            AimbotSection:Slider({Name = "Field Of View", Flag = "Aimbot/FOV/Radius", Min = 0, Max = 500, Value = 100, Unit = "r"})
            AimbotSection:Slider({Name = "Distance Limit", Flag = "Aimbot/DistanceLimit", Min = 25, Max = 10000, Value = 250, Unit = "studs"})

            local PriorityList, BodyPartsList = {{Name = "Closest", Mode = "Button", Value = true}}, {}
            for Index, Value in pairs(KnownBodyParts) do
                PriorityList[#PriorityList + 1] = {Name = Value[1], Mode = "Button", Value = false}
                BodyPartsList[#BodyPartsList + 1] = {Name = Value[1], Mode = "Toggle", Value = Value[2]}
            end

            AimbotSection:Dropdown({Name = "Priority", Flag = "Aimbot/Priority", List = PriorityList})
            AimbotSection:Dropdown({Name = "Body Parts", Flag = "Aimbot/BodyParts", List = BodyPartsList})
        end
        local AFOVSection = CombatTab:Section({Name = "Aimbot FOV Circle", Side = "Left"}) do
            AFOVSection:Toggle({Name = "Enabled", Flag = "Aimbot/FOV/Enabled", Value = true})
            AFOVSection:Toggle({Name = "Filled", Flag = "Aimbot/FOV/Filled", Value = false})
            AFOVSection:Colorpicker({Name = "Color", Flag = "Aimbot/FOV/Color", Value = {1, 0.66666662693024, 1, 0.25, false}})
            AFOVSection:Slider({Name = "NumSides", Flag = "Aimbot/FOV/NumSides", Min = 3, Max = 100, Value = 14})
            AFOVSection:Slider({Name = "Thickness", Flag = "Aimbot/FOV/Thickness", Min = 1, Max = 10, Value = 2})
        end
        local SilentAimSection = CombatTab:Section({Name = "Silent Aim", Side = "Right"}) do
            SilentAimSection:Toggle({Name = "Enabled", Flag = "SilentAim/Enabled", Value = false}):Keybind({Mouse = true, Flag = "SilentAim/Keybind"})

            SilentAimSection:Toggle({Name = "Team Check", Flag = "SilentAim/TeamCheck", Value = false})
            SilentAimSection:Toggle({Name = "Distance Check", Flag = "SilentAim/DistanceCheck", Value = false})
            SilentAimSection:Toggle({Name = "Visibility Check", Flag = "SilentAim/VisibilityCheck", Value = false})
            SilentAimSection:Slider({Name = "Hit Chance", Flag = "SilentAim/HitChance", Min = 0, Max = 100, Value = 100, Unit = "%"})
            SilentAimSection:Slider({Name = "Field Of View", Flag = "SilentAim/FOV/Radius", Min = 0, Max = 500, Value = 100, Unit = "r"})
            SilentAimSection:Slider({Name = "Distance Limit", Flag = "SilentAim/DistanceLimit", Min = 25, Max = 10000, Value = 250, Unit = "studs"})

            local PriorityList, BodyPartsList = {{Name = "Closest", Mode = "Button", Value = true}, {Name = "Random", Mode = "Button"}}, {}
            for Index, Value in pairs(KnownBodyParts) do
                PriorityList[#PriorityList + 1] = {Name = Value[1], Mode = "Button", Value = false}
                BodyPartsList[#BodyPartsList + 1] = {Name = Value[1], Mode = "Toggle", Value = Value[2]}
            end

            SilentAimSection:Dropdown({Name = "Priority", Flag = "SilentAim/Priority", List = PriorityList})
            SilentAimSection:Dropdown({Name = "Body Parts", Flag = "SilentAim/BodyParts", List = BodyPartsList})
        end
        local SAFOVSection = CombatTab:Section({Name = "Silent Aim FOV Circle", Side = "Right"}) do
            SAFOVSection:Toggle({Name = "Enabled", Flag = "SilentAim/FOV/Enabled", Value = true})
            SAFOVSection:Toggle({Name = "Filled", Flag = "SilentAim/FOV/Filled", Value = false})
            SAFOVSection:Colorpicker({Name = "Color", Flag = "SilentAim/FOV/Color",
            Value = {0.6666666865348816, 0.6666666269302368, 1, 0.25, false}})
            SAFOVSection:Slider({Name = "NumSides", Flag = "SilentAim/FOV/NumSides", Min = 3, Max = 100, Value = 14})
            SAFOVSection:Slider({Name = "Thickness", Flag = "SilentAim/FOV/Thickness", Min = 1, Max = 10, Value = 2})
        end
        local TriggerSection = CombatTab:Section({Name = "Trigger", Side = "Right"}) do
            TriggerSection:Toggle({Name = "Enabled", Flag = "Trigger/Enabled", Value = false})
            :Keybind({Flag = "Trigger/Keybind", Value = "MouseButton2", Mouse = true, DisableToggle = true,
            Callback = function(Key, KeyDown) Trigger = Window.Flags["Trigger/Enabled"] and KeyDown end})

            TriggerSection:Toggle({Name = "Always Enabled", Flag = "Trigger/AlwaysEnabled", Value = false})
            TriggerSection:Toggle({Name = "Hold Mouse Button", Flag = "Trigger/HoldMouseButton", Value = false})
            TriggerSection:Toggle({Name = "Prediction", Flag = "Trigger/Prediction", Value = true})

            TriggerSection:Toggle({Name = "Distance Check", Flag = "Trigger/DistanceCheck", Value = false})
            TriggerSection:Toggle({Name = "Visibility Check", Flag = "Trigger/VisibilityCheck", Value = false})

            TriggerSection:Slider({Name = "Click Delay", Flag = "Trigger/Delay", Min = 0, Max = 1, Precise = 2, Value = 0.15, Unit = "sec"})
            TriggerSection:Slider({Name = "Distance Limit", Flag = "Trigger/DistanceLimit", Min = 25, Max = 10000, Value = 250, Unit = "studs"})
            TriggerSection:Slider({Name = "Field Of View", Flag = "Trigger/FOV/Radius", Min = 0, Max = 500, Value = 25, Unit = "r"})

            local PriorityList, BodyPartsList = {{Name = "Closest", Mode = "Button", Value = true}, {Name = "Random", Mode = "Button"}}, {}
            for Index, Value in pairs(KnownBodyParts) do
                PriorityList[#PriorityList + 1] = {Name = Value[1], Mode = "Button", Value = false}
                BodyPartsList[#BodyPartsList + 1] = {Name = Value[1], Mode = "Toggle", Value = Value[2]}
            end

            TriggerSection:Dropdown({Name = "Priority", Flag = "Trigger/Priority", List = PriorityList})
            TriggerSection:Dropdown({Name = "Body Parts", Flag = "Trigger/BodyParts", List = BodyPartsList})
        end
        local TFOVSection = CombatTab:Section({Name = "Trigger FOV Circle", Side = "Left"}) do
            TFOVSection:Toggle({Name = "Enabled", Flag = "Trigger/FOV/Enabled", Value = true})
            TFOVSection:Toggle({Name = "Filled", Flag = "Trigger/FOV/Filled", Value = false})
            TFOVSection:Colorpicker({Name = "Color", Flag = "Trigger/FOV/Color", Value = {0.0833333358168602, 0.6666666269302368, 1, 0.25, false}})
            TFOVSection:Slider({Name = "NumSides", Flag = "Trigger/FOV/NumSides", Min = 3, Max = 100, Value = 14})
            TFOVSection:Slider({Name = "Thickness", Flag = "Trigger/FOV/Thickness", Min = 1, Max = 10, Value = 2})
        end
    end
    local VisualsSection = Radical.Utilities:ESPSection(Window, "Visuals", "ESP/Player", true, true, true, true, true, false) do
        VisualsSection:Colorpicker({Name = "Ally Color", Flag = "ESP/Player/Ally", Value = {0.3333333432674408, 0.6666666269302368, 1, 0, false}})
        VisualsSection:Colorpicker({Name = "Enemy Color", Flag = "ESP/Player/Enemy", Value = {1, 0.6666666269302368, 1, 0, false}})
        VisualsSection:Toggle({Name = "Team Check", Flag = "ESP/Player/TeamCheck", Value = false})
        VisualsSection:Toggle({Name = "Use Team Color", Flag = "ESP/Player/TeamColor", Value = false})
        VisualsSection:Toggle({Name = "Distance Check", Flag = "ESP/Player/DistanceCheck", Value = true})
        VisualsSection:Slider({Name = "Distance", Flag = "ESP/Player/Distance", Min = 25, Max = 10000, Value = 1000, Unit = "studs"})
    end
    local ESPTab = Window:Tab({Name = "AR2 ESP"}) do
        local ItemSection = ESPTab:Section({Name = "Item ESP", Side = "Left"}) do local Items = {}
            ItemSection:Toggle({Name = "Enabled", Flag = "AR2/ESP/Items/Enabled", Value = false})
            ItemSection:Toggle({Name = "Distance Check", Flag = "AR2/ESP/Items/DistanceCheck", Value = true})
            ItemSection:Slider({Name = "Distance", Flag = "AR2/ESP/Items/Distance", Min = 25, Max = 5000, Value = 50, Unit = "studs"})

            for Index, Data in pairs(ItemCategory) do
                local ItemFlag = "AR2/ESP/Items/" .. Data[1]
                Window.Flags[ItemFlag .. "/Enabled"] = Data[2]

                Items[#Items + 1] = {
                    Name = Data[1], Mode = "Toggle", Value = Data[2],
                    Colorpicker = {Flag = ItemFlag .. "/Color", Value = {1, 0, 1, 0.5, false}},
                    Callback = function(Selected, Option) Window.Flags[ItemFlag .. "/Enabled"] = Option.Value end
                }
            end

            ItemSection:Dropdown({Name = "ESP List", Flag = "AR2/Items", List = Items})
        end
        local CorpsesSection = ESPTab:Section({Name = "Corpses ESP", Side = "Left"}) do
            CorpsesSection:Toggle({Name = "Enabled", Flag = "AR2/ESP/Corpses/Enabled", Value = false})
            CorpsesSection:Toggle({Name = "Distance Check", Flag = "AR2/ESP/Corpses/DistanceCheck", Value = true})
            CorpsesSection:Colorpicker({Name = "Color", Flag = "AR2/ESP/Corpses/Color", Value = {1, 0, 1, 0.5, false}})
            CorpsesSection:Slider({Name = "Distance", Flag = "AR2/ESP/Corpses/Distance", Min = 25, Max = 5000, Value = 1500, Unit = "studs"})
        end
        local ZombiesSection = ESPTab:Section({Name = "Zombies ESP", Side = "Left"}) do local ZIs = {}
            ZombiesSection:Toggle({Name = "Enabled", Flag = "AR2/ESP/Zombies/Enabled", Value = false})
            ZombiesSection:Toggle({Name = "Distance Check", Flag = "AR2/ESP/Zombies/DistanceCheck", Value = true})
            ZombiesSection:Slider({Name = "Distance", Flag = "AR2/ESP/Zombies/Distance", Min = 25, Max = 5000, Value = 1500, Unit = "studs"})

            for Index, Data in pairs(ZombieInherits) do
                local Name = Data[1]:gsub("Presets.", ""):gsub(" ", "")
                local ZIFlag = "AR2/ESP/Zombies/" .. Name
                Window.Flags[ZIFlag .. "/Enabled"] = Data[2]

                ZIs[#ZIs + 1] = {
                    Name = Name, Mode = "Toggle", Value = Data[2],
                    Colorpicker = {Flag = ZIFlag .. "/Color", Value = {1, 0, 1, 0.5, false}},
                    Callback = function(Selected, Option) Window.Flags[ZIFlag .. "/Enabled"] = Option.Value end
                }
            end

            ZombiesSection:Dropdown({Name = "ESP List", Flag = "AR2/Zombies", List = ZIs})
        end
        local RESection = ESPTab:Section({Name = "Random Events ESP", Side = "Right"}) do local REs = {}
            RESection:Toggle({Name = "Enabled", Flag = "AR2/ESP/RandomEvents/Enabled", Value = false})
            RESection:Toggle({Name = "Distance Check", Flag = "AR2/ESP/RandomEvents/DistanceCheck", Value = true})
            RESection:Slider({Name = "Distance", Flag = "AR2/ESP/RandomEvents/Distance", Min = 25, Max = 5000, Value = 1500, Unit = "studs"})

            for Index, Data in pairs(RandomEvents) do
                local REFlag = "AR2/ESP/RandomEvents/" .. Data[1]
                Window.Flags[REFlag .. "/Enabled"] = Data[2]

                REs[#REs + 1] = {
                    Name = Data[1], Mode = "Toggle", Value = Data[2],
                    Colorpicker = {Flag = REFlag .. "/Color", Value = {1, 0, 1, 0.5, false}},
                    Callback = function(Selected, Option) Window.Flags[REFlag .. "/Enabled"] = Option.Value end
                }
            end

            RESection:Dropdown({Name = "ESP List", Flag = "AR2/RandomEvents", List = REs})
        end
        local VehiclesSection = ESPTab:Section({Name = "Vehicles ESP", Side = "Right"}) do
            VehiclesSection:Toggle({Name = "Enabled", Flag = "AR2/ESP/Vehicles/Enabled", Value = false})
            VehiclesSection:Toggle({Name = "Distance Check", Flag = "AR2/ESP/Vehicles/DistanceCheck", Value = true})
            VehiclesSection:Colorpicker({Name = "Color", Flag = "AR2/ESP/Vehicles/Color", Value = {1, 0, 1, 0.5, false}})
            VehiclesSection:Slider({Name = "Distance", Flag = "AR2/ESP/Vehicles/Distance", Min = 25, Max = 5000, Value = 1500, Unit = "studs"})
        end
    end
    local MiscTab = Window:Tab({Name = "Miscellaneous"}) do local LModes = {}
        local LightingSection = MiscTab:Section({Name = "Lighting", Side = "Left"}) do
            LightingSection:Toggle({Name = "Enabled", Flag = "AR2/Lighting/Enabled", Value = false,
            Callback = function(Bool) if not Bool then LightingState.BaseTime = OldBaseTime end end})
            LightingSection:Slider({Name = "Time", Flag = "AR2/Lighting/Time", Min = 0, Max = 24, Precise = 1, Value = 12, Unit = "hours"})

            for Name, LightingMode in pairs(getupvalue(Lighting.GetState, 4)) do
                LModes[#LModes + 1] = {Name = Name, Mode = "Button", Value = false,
                Callback = function() Lighting:SetMode(Name) end}
            end

            LightingSection:Dropdown({Name = "Lighting Mode", Flag = "AR2/Lighting/Modes", List = LModes})
            LightingSection:Button({Name = "Reset Lighting Mode", Callback = function() Lighting:Reset() end})

        end
        local RecoilSection = MiscTab:Section({Name = "Weapon", Side = "Left"}) do
            RecoilSection:Toggle({Name = "Bullet Tracer", Flag = "AR2/BulletTracer/Enabled", Value = false})
            :Colorpicker({Flag = "AR2/BulletTracer/Color", Value = {1, 0.75, 1, 0, true}})
            RecoilSection:Toggle({Name = "Silent Wallbang", Flag = "AR2/MagicBullet/Enabled", Value = false}):Keybind({Flag = "AR2/MagicBullet/Keybind"})
            RecoilSection:Slider({Name = "Wallbang Depth", Flag = "AR2/MagicBullet/Depth", Min = 1, Max = 5, Value = 5, Unit = "studs"})
            RecoilSection:Divider()
            RecoilSection:Toggle({Name = "Recoil Control", Flag = "AR2/Recoil/Enabled", Value = false})
            RecoilSection:Slider({Name = "Recoil", Flag = "AR2/Recoil/Value", Min = 0, Max = 100, Value = 0, Unit = "%"})
            RecoilSection:Toggle({Name = "No Spread", Flag = "AR2/NoSpread", Value = false})
            RecoilSection:Toggle({Name = "No Camera Flinch", Flag = "AR2/NoFlinch", Value = false})
            RecoilSection:Toggle({Name = "Unlock Firemodes", Flag = "AR2/UnlockFiremodes", Value = false})
            RecoilSection:Toggle({Name = "Instant Reload", Flag = "AR2/InstantReload", Value = false})
        end
        local VehSection = MiscTab:Section({Name = "Vehicle", Side = "Left"}) do
            VehSection:Toggle({Name = "Enabled", Flag = "AR2/Vehicle/Enabled", Value = false})
            VehSection:Toggle({Name = "No Impact", Flag = "AR2/Vehicle/Impact", Value = false})
            VehSection:Toggle({Name = "Instant Action", Flag = "AR2/Vehicle/Instant", Value = false})
            VehSection:Slider({Name = "Max Speed", Flag = "AR2/Vehicle/MaxSpeed", Min = 0, Max = 500, Value = 100, Unit = "mph"})
        end
        local CharSection = MiscTab:Section({Name = "Character", Side = "Right"}) do
            CharSection:Toggle({Name = "Fly Enabled", Flag = "AR2/Fly/Enabled", Value = false}):Keybind({Flag = "AR2/Fly/Keybind"})
            CharSection:Slider({Name = "", Flag = "AR2/Fly/Speed", Min = 0, Max = 10, Precise = 1, Value = 0.7, Unit = "studs", Wide = true})
            CharSection:Toggle({Name = "Walk Speed", Flag = "AR2/WalkSpeed/Enabled", Value = false}):Keybind({Flag = "AR2/WalkSpeed/Keybind"})
            CharSection:Slider({Name = "", Flag = "AR2/WalkSpeed/Speed", Min = 0, Max = 1.4, Precise = 1, Value = 0.7, Unit = "studs", Wide = true})
            CharSection:Toggle({Name = "Jump Height", Flag = "AR2/JumpHeight/Enabled", Value = false}):Keybind({Flag = "AR2/JumpHeight/Keybind"})
            CharSection:Toggle({Name = "Infinite Jump", Flag = "AR2/JumpHeight/NoFallCheck", Value = false})
            CharSection:Toggle({Name = "No Fall Impact", Flag = "AR2/NoFallImpact", Value = false})
            CharSection:Toggle({Name = "No Jump Debounce", Flag = "AR2/NoJumpDebounce", Value = false})
            CharSection:Slider({Name = "", Flag = "AR2/JumpHeight/Height", Min = 4.8, Max = 100, Precise = 1, Value = 4.8, Unit = "studs", Wide = true})
            CharSection:Toggle({Name = "Use In Air/Water", Flag = "AR2/UseInAir", Value = false})
            CharSection:Toggle({Name = "Fast Respawn", Flag = "AR2/FastRespawn", Value = false})
            CharSection:Button({Name = "Respawn", Callback = function()
                task.spawn(function() SetIdentity(2)
                    PlayerClass:UnloadCharacter()
                    Interface:Hide("Reticle")
                    task.wait(0.5)
                    PlayerClass:LoadCharacter()
                end)
            end}):Tooltip("You will lose loot")
        end
        local MiscSection = MiscTab:Section({Name = "Other", Side = "Right"}) do

            MiscSection:Toggle({Name = "Head Expander", Flag = "AR2/HeadExpander", Value = false,
            Callback = function(Bool)
                if Bool then return end
                for Index, Player in pairs(PlayerService:GetPlayers()) do
                    if Player == LocalPlayer then continue end
                    local Character = GetPlayerCharacter(Player)
                    if not Character then continue end
                    local Head = Character:FindFirstChild("Head")
                    if not Head then continue end

                    Head.Size = Mannequin.Head.Size
                    Head.Transparency = Mannequin.Head.Transparency
                    Head.CanCollide = Mannequin.Head.CanCollide
                end
            end})
            MiscSection:Slider({Name = "Size Mult", Flag = "AR2/HeadExpander/Value", Min = 1, Max = 20, Value = 10, Unit = "x", Wide = true})
            MiscSection:Slider({Name = "Transparency", Flag = "AR2/HeadExpander/Transparency", Min = 0, Max = 1, Value = 0.5, Precise = 1, Wide = true})
            MiscSection:Divider()
            MiscSection:Toggle({Name = "MeleeAura", Flag = "AR2/MeleeAura", Value = false})
            MiscSection:Toggle({Name = "Zombie MeleeAura", Flag = "AR2/AntiZombie/MeleeAura", Value = false})
            MiscSection:Toggle({Name = "Container Persistence", Flag = "AR2/ContainerPersistence", Value = false})
            MiscSection:Toggle({Name = "Instant Search", Flag = "AR2/InstantSearch", Value = false})
            local SpoofSCS = MiscSection:Toggle({Name = "Spoof State", Flag = "AR2/SSCS", Value = false}) SpoofSCS:Keybind()
            SpoofSCS:Tooltip("SCS - Set Character State:\nNo Fall Damage\nLess Hunger / Thirst\nWhile Sprinting")

            local MoveStates = {}
            for MoveState, Value in pairs(Framework.Configs.Character.ValidMoveStates) do
                MoveStates[#MoveStates + 1] = {Name = MoveState, Mode = "Button", Value = false}
                if MoveState == "Climbing" then MoveStates[#MoveStates].Value = true end
            end
            MiscSection:Dropdown({Name = "Move States", Flag = "AR2/MoveState", List = MoveStates})
            MiscSection:Toggle({Name = "NoClip", Flag = "AR2/NoClip", Value = false,
            Callback = function(Bool)
                if Bool and not NoClipEvent then
                    NoClipEvent = RunService.Stepped:Connect(function()
                        if not LocalPlayer.Character then return end

                        for Index, Object in pairs(LocalPlayer.Character:GetDescendants()) do
                            if Object:IsA("BasePart") then
                                if NoClipObjects[Object] == nil then
                                    NoClipObjects[Object] = Object.CanCollide
                                end Object.CanCollide = false
                            end
                        end
                    end)
                elseif not Bool and NoClipEvent then
                    NoClipEvent:Disconnect()
                    NoClipEvent = nil

                    task.wait(0.1)
                    for Object, CanCollide in pairs(NoClipObjects) do
                        Object.CanCollide = CanCollide
                    end table.clear(NoClipObjects)
                end
            end}):Keybind()
            MiscSection:Toggle({Name = "Map ESP", Flag = "AR2/MapESP", Value = false})
            MiscSection:Toggle({Name = "Staff Join", Flag = "AR2/StaffJoin", Value = false})
            MiscSection:Dropdown({HideName = true, Flag = "AR2/StaffJoin/List", List = {
                {Name = "Server Hop", Mode = "Button", Value = false},
                {Name = "Notify", Mode = "Button", Value = true},
                {Name = "Kick", Mode = "Button", Value = false}
            }})
        end
    end Radical.Utilities:SettingsSection(Window, "RightControl", true)
end Radical.Utilities.InitAutoLoad(Window)

Radical.Utilities:SetupWatermark(Window)
Radical.Utilities:SetupLighting(Window.Flags)
Radical.Utilities.Drawing.SetupCursor(Window)
Radical.Utilities.Drawing.SetupCrosshair(Window.Flags)
Radical.Utilities.Drawing.SetupFOV("Aimbot", Window.Flags)
Radical.Utilities.Drawing.SetupFOV("Trigger", Window.Flags)
Radical.Utilities.Drawing.SetupFOV("SilentAim", Window.Flags)

local XZVector = Vector3.new(1, 0, 1)
local WallCheckParams = RaycastParams.new()
WallCheckParams.FilterType = Enum.RaycastFilterType.Blacklist
WallCheckParams.FilterDescendantsInstances = {
    Workspace.Effects, ReplicatedStorage.Assets.Sounds,
    Workspace.Locations, Workspace.Spawns
} WallCheckParams.IgnoreWater = true

local function Raycast(Origin, Direction)
    if not table.find(WallCheckParams.FilterDescendantsInstances, LocalPlayer.Character) then
        WallCheckParams.FilterDescendantsInstances = {
            Workspace.Effects, ReplicatedStorage.Assets.Sounds,
            Workspace.Locations, Workspace.Spawns,
            LocalPlayer.Character
        }
    end

    local RaycastResult = Workspace:Raycast(Origin, Direction, WallCheckParams)
    if RaycastResult then
        if (RaycastResult.Instance.Transparency == 1
        and RaycastResult.Instance.CanCollide == false)
        or (CollectionService:HasTag(RaycastResult.Instance, "Bullets Penetrate")
        or CollectionService:HasTag(RaycastResult.Instance, "Window Part")
        or CollectionService:HasTag(RaycastResult.Instance, "World Mesh")
        or CollectionService:HasTag(RaycastResult.Instance, "World Water Part")) then
            return true
        end
    end
end
local function InEnemyTeam(Enabled, Player)
    if not Enabled then return true end
    if SquadData and SquadData.Members then
        if table.find(SquadData.Members, Player.Name) then
            return false
        end
    end

    return true
end
local function WithinReach(Enabled, Distance, Limit)
    if not Enabled then return true end
    return Distance < Limit
end
local function ObjectOccluded(Enabled, Origin, Position, Object)
    if not Enabled then return false end
    return Raycast(Origin, Position - Origin, {Object, LocalPlayer.Character})
end
local function SolveTrajectory(Origin, Velocity, Time, Gravity)
    Gravity = Vector3.new(0, math.abs(Gravity), 0)
    return Origin + (Velocity * Time) + (Gravity * Time * Time)
end
local function GetClosest(Enabled,
    TeamCheck, VisibilityCheck, DistanceCheck,
    DistanceLimit, FieldOfView, Priority, BodyParts,
    PredictionEnabled
)

    if not Enabled then return end
    if not PlayerClass.Character then return end

    local CameraPosition, Closest = Camera.CFrame.Position, nil
    for Index, Player in ipairs(PlayerService:GetPlayers()) do
        if Player == LocalPlayer then continue end

        -- FIXED: use GetPlayerCharacter for new character path
        local Character = GetPlayerCharacter(Player)
        if not Character then continue end
        if not InEnemyTeam(TeamCheck, Player) then continue end

        if Priority == "Random" then
            Priority = BodyParts[math.random(#BodyParts)]
            BodyPart = Character:FindFirstChild(Priority)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition,
            BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
            local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(BodyPartPosition)
            ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            if not OnScreen then continue end

            Distance = (BodyPartPosition - CameraPosition).Magnitude
            if not WithinReach(DistanceCheck, Distance, DistanceLimit) then continue end
            if ObjectOccluded(VisibilityCheck, CameraPosition, BodyPartPosition, Character) then continue end

            local Magnitude = (ScreenPosition - UserInputService:GetMouseLocation()).Magnitude
            if Magnitude >= FieldOfView then continue end

            return {Player, Character, BodyPart, ScreenPosition}
        elseif Priority ~= "Closest" then
            BodyPart = Character:FindFirstChild(Priority)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition,
            BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
            local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(BodyPartPosition)
            ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            if not OnScreen then continue end

            Distance = (BodyPartPosition - CameraPosition).Magnitude
            if not WithinReach(DistanceCheck, Distance, DistanceLimit) then continue end
            if ObjectOccluded(VisibilityCheck, CameraPosition, BodyPartPosition, Character) then continue end

            local Magnitude = (ScreenPosition - UserInputService:GetMouseLocation()).Magnitude
            if Magnitude >= FieldOfView then continue end

            return {Player, Character, BodyPart, ScreenPosition}
        end

        for Index, BodyPart in ipairs(BodyParts) do
            BodyPart = Character:FindFirstChild(BodyPart)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition,
            BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
            local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(BodyPartPosition)
            ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            if not OnScreen then continue end

            Distance = (BodyPartPosition - CameraPosition).Magnitude
            if not WithinReach(DistanceCheck, Distance, DistanceLimit) then continue end
            if ObjectOccluded(VisibilityCheck, CameraPosition, BodyPartPosition, Character) then continue end

            local Magnitude = (ScreenPosition - UserInputService:GetMouseLocation()).Magnitude
            if Magnitude >= FieldOfView then continue end

            FieldOfView, Closest = Magnitude, {Player, Character, BodyPart, ScreenPosition}
        end
    end

    return Closest
end
local function AimAt(Hitbox, Sensitivity)
    if not Hitbox then return end
    local MouseLocation = UserInputService:GetMouseLocation()

    mousemoverel(
        (Hitbox[4].X - MouseLocation.X) * Sensitivity,
        (Hitbox[4].Y - MouseLocation.Y) * Sensitivity
    )
end

local function CheckForAdmin(Player)
    if Window.Flags["AR2/StaffJoin"] then
        local Rank = Player:GetRankInGroup(15434910)
        if not Rank then return end

        local Role = AdminRoles[Rank]
        if not Role then return end

        local Message = ("Staff member has joined or is in your game\nName: %s\nUserId: %s\nRole: %s"):format(Player.Name, Player.UserId, Role)
        if Window.Flags["AR2/StaffJoin/List"][1] == "Kick" then
            LocalPlayer:Kick(Message)
        elseif Window.Flags["AR2/StaffJoin/List"][1] == "Server Hop" then
            LocalPlayer:Kick(Message)
            task.wait(5)
            Radical.Utilities.ServerHop()
        elseif Window.Flags["AR2/StaffJoin/List"][1] == "Notify" then
            UI:Push({Title = Message, Duration = 20})
        end
    end
end
local function GetStates()
    if not NetworkSyncHeartbeat then print("no") return {} end
    local Seed = debug.getupvalue(NetworkSyncHeartbeat, 6)

    local RandomData = {}
    local SeededRandom = Random.new(Seed)

    local Data = {
        "ServerTime", "RootCFrame", "RootVelocity", "FirstPerson", "InstanceCFrame",
        "LookDirection", "MoveState", "AtEaseInput", "ShoulderSwapped", "Zooming",
        "BinocsActive", "Staggered", "Shoving"
    }

    local DataLength = #Data
    while #Data > 0 do
        local ToRemove = SeededRandom:NextInteger(1, DataLength)
        ToRemove = ToRemove % #Data == 0 and #Data or ToRemove % #Data
        local Removed = table.remove(Data, ToRemove)
        table.insert(RandomData, Removed)
    end

    return RandomData
end

local function CastLocalBulletInstant(Origin, Direction, SpreadDirection)
    local Velocity = Direction * ProjectileSpeed
    local SpreadVelocity = SpreadDirection * ProjectileSpeed

    local ProjectilePosition = Origin
    local ProjectileSpreadPosition = Origin

    local ProjectileRay = nil
    local ProjectileCastInstance = nil
    local ProjectileCastPosition = Vector3.zero

    local ProjectileSpreadRay = nil

    local Frame = 1 / 60
    local TravelTime = 0
    local TravelDistance = 0

    local Exclude = {
        Effects,
        Sounds,
        PlayerClass.Character.Instance
    }

    while true do
        TravelTime += Frame

        ProjectileRay = Ray.new(ProjectilePosition, Origin + Velocity * TravelTime + ProjectileGravity * Vector3.yAxis * TravelTime ^ 2 - ProjectilePosition)
        ProjectileSpreadRay = Ray.new(ProjectileSpreadPosition, Origin + SpreadVelocity * TravelTime + ProjectileGravity * Vector3.yAxis * TravelTime ^ 2 - ProjectileSpreadPosition)

        ProjectileCastInstance, ProjectileCastPosition = Raycasting:BulletCast(ProjectileRay, true, Exclude)
        ProjectileSpreadPosition = ProjectileSpreadRay.Origin + ProjectileSpreadRay.Direction

        TravelDistance = TravelDistance + (ProjectilePosition - ProjectileCastPosition).Magnitude
        ProjectilePosition = ProjectileCastPosition

        if ProjectileCastInstance or TravelDistance > ShotMaxDistance then
            break
        end
    end

    if ProjectileCastInstance then
        local Distance = (ProjectileSpreadPosition - ProjectileCastPosition).Magnitude
        local Unit = (ProjectileSpreadPosition - ProjectileSpreadRay.Origin).Unit

        ProjectileSpreadPosition = ProjectileSpreadPosition - Unit * Distance
        Radical.Utilities.MakeBeam(ProjectileSpreadRay.Origin, ProjectileSpreadPosition, Window.Flags["AR2/BulletTracer/Color"])

        return ProjectileSpreadPosition, {
            ProjectileCastInstance.CFrame:PointToObjectSpace(ProjectileSpreadRay.Origin),
            ProjectileCastInstance.CFrame:VectorToObjectSpace(ProjectileSpreadRay.Direction),
            ProjectileCastInstance.CFrame:PointToObjectSpace(ProjectileSpreadPosition)
        }
    end
end
local function SwingMelee(Enemies)
    local Character = PlayerClass.Character
    if not Character then return end

    local EquippedItem = Character.EquippedItem
    if not EquippedItem then return end

    if EquippedItem.Type ~= "Melee" then return end
    local AttackConfig = EquippedItem.AttackConfig[1]

    local Time = Workspace:GetServerTimeNow()
    Network:Send("Melee Swing", Time, EquippedItem.Id, 1)
    local Stopped = Character.Animator:PlayAnimation(AttackConfig.Animation, 0.05, AttackConfig.PlaybackSpeedMod)
    local Track = Character.Animator:GetTrack(AttackConfig.Animation)

    if Track then
        local Maid = Maids.new()
        Maid:Give(Track:GetMarkerReachedSignal("Swing"):Connect(function(State)
            if State ~= "Begin" then return end
            for Index, Enemy in pairs(Enemies) do
                Network:Send("Melee Hit Register", EquippedItem.Id, Time, Enemy, "Flesh", false)
                if not AttackConfig.CanHitMultipleTargets then break end
            end
            Maid:Destroy()
            Maid = nil
        end))

        Stopped:Wait()
    end
end
local function GetEnemyForMelee(CountPlayers, CountZombies)
    local PlayerCharacter = PlayerClass.Character
    if not PlayerCharacter then return end

    local Distance, Closest = 10, {}

    if CountZombies then
        for Index, Zombie in pairs(Zombies.Mobs:GetChildren()) do
            local PrimaryPart = Zombie.PrimaryPart
            if not PrimaryPart then continue end

            local Magnitude = (PrimaryPart.Position - PlayerCharacter.RootPart.Position).Magnitude
            if Distance > Magnitude then Distance = Magnitude table.insert(Closest, PrimaryPart) end
        end
    end

    if CountPlayers then
        Distance = 10
        -- FIXED: iterate via PlayerService instead of Characters folder (all named StarterCharacter now)
        for Index, Player in pairs(PlayerService:GetPlayers()) do
            if Player == LocalPlayer then continue end
            if not InEnemyTeam(true, Player) then continue end

            local Character = GetPlayerCharacter(Player)
            if not Character then continue end
            local PrimaryPart = Character.PrimaryPart
            if not PrimaryPart then continue end

            local Magnitude = (PrimaryPart.Position - PlayerCharacter.RootPart.Position).Magnitude
            if Distance > Magnitude then Distance = Magnitude table.insert(Closest, PrimaryPart) end
        end
    end

    return Closest
end
local function GetCharactersInRadius(Path, Distance)
    local PlayerCharacter = PlayerClass.Character
    if not PlayerCharacter then return end

    local Closest = {}
    for Index, Character in pairs(Path:GetChildren()) do
        if Character == PlayerCharacter.Instance then continue end
        local PrimaryPart = Character.PrimaryPart
        if not PrimaryPart then continue end

        local Magnitude = (PrimaryPart.Position - PlayerCharacter.RootPart.Position).Magnitude
        if Distance >= Magnitude then Distance = Magnitude table.insert(Closest, Character) end
    end

    return Closest
end

local function Length(Table) local Count = 0
    for Index, Value in pairs(Table) do Count += 1 end
    return Count
end
local function CIIC(Data)
    local Duplicates, Items = {}, {Data.DisplayName}

    for Index, Value in pairs(Data.Occupants) do
        if Duplicates[Value.Name] then
            Duplicates[Value.Name] += 1
        else
            Duplicates[Value.Name] = 1
        end
    end

    for Item, Value in pairs(Duplicates) do
        Items[#Items + 1] = Value == 1 and "[" .. Item .. "]"
        or "[" .. Item .. "] x" .. Value
    end
    return table.concat(Items, "\n")
end

local function HookCharacter(Character)
    for Index, Item in pairs(PlayerClass.Character.Maid.Items) do
        if type(Item) == "table" and rawget(Item, "Action") then
            if table.find(debug.getconstants(Item.Action), "Network sync") then
                NetworkSyncHeartbeat = Item.Action
            end
        end
    end

    local OldEquip; OldEquip = hookfunction(Character.Equip, newcclosure(function(Self, Item, ...)
        if Item.FireConfig and Item.FireConfig.MuzzleVelocity then
            ProjectileSpeed = Item.FireConfig.MuzzleVelocity * Globals.MuzzleVelocityMod
        end

        return OldEquip(Self, Item, ...)
    end))

    local OldJump; OldJump = hookfunction(Character.Actions.Jump, newcclosure(function(Self, ...)
        local Args = {...}

        if Window.Flags["AR2/NoJumpDebounce"] then
            Self.JumpDebounce = 0
        end

        if Args[1] == "Begin" and Window.Flags["AR2/JumpHeight/Enabled"] then
            local ReturnArgs = {OldJump(Self, ...)}

            if Self.Humanoid:GetState() == Enum.HumanoidStateType.Freefall
            and not Window.Flags["AR2/JumpHeight/NoFallCheck"] then return end

            Self.Humanoid.UseJumpPower = false
            Self.Humanoid.JumpHeight = Window.Flags["AR2/JumpHeight/Height"]
            Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

            return unpack(ReturnArgs)
        end

        return OldJump(Self, ...)
    end))

    local OldToolAction; OldToolAction = hookfunction(Character.Actions.ToolAction, newcclosure(function(Self, ...)
        if Window.Flags["AR2/UnlockFiremodes"] then
            if not Self.EquippedItem then return OldToolAction(Self, ...) end
            local FireModes = Self.EquippedItem.FireModes
            if not FireModes then return OldToolAction(Self, ...) end

            for Index, Mode in ipairs({"Semiautomatic", "Automatic", "Burst"}) do
                if not table.find(FireModes, Mode) then
                    setreadonly(FireModes, false)
                    table.insert(FireModes, Mode)
                    setreadonly(FireModes, true)
                end
            end
        end

        return OldToolAction(Self, ...)
    end))
end

local OldIndex, OldNamecall = nil, nil
OldIndex = hookmetamethod(game, "__index", function(Self, Index)
    if Window.Flags["AR2/HeadExpander"] and tostring(Self) == "Head" and Index == "Size" then
        return Vector3.one * 1.15
    end

    return OldIndex(Self, Index)
end)

OldNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
    local Method = getnamecallmethod()

    if Method == "GetChildren"
    and (Self == ReplicatedFirst
    or Self == ReplicatedStorage) then
        print("crash bypass")
        wait(383961600)
    end

    return OldNamecall(Self, ...)
end)

local OldSend; OldSend = hookfunction(Network.Send, newcclosure(function(Self, Name, ...)
    if table.find(SanityBans, Name) then print("bypassed", Name) return end
    if Name == "Character Jumped" and Window.Flags["AR2/SSCS"] then return end

    if Name == "Vehicle Bumper Impact" then
        if Window.Flags["AR2/Vehicle/Impact"] then
            return
        end
    end

    if Name == "Inventory Container Group Disconnect" then
        if Window.Flags["AR2/ContainerPersistence"] then
            return
        end
    end

    return OldSend(Self, Name, ...)
end))

local OldFetch; OldFetch = hookfunction(Network.Fetch, newcclosure(function(Self, Name, ...)
    if table.find(SanityBans, Name) then print("bypassed", Name) return end

    if Name == "Character State Report" then
        local RandomData = GetStates()
        local Args = {...}

        for Index = 1, #Args do
            if Window.Flags["AR2/SSCS"] then
                if RandomData[Index] == "MoveState" then
                    Args[Index] = Window.Flags["AR2/MoveState"][1]
                end
            end
            if Window.Flags["AR2/NoSpread"] then
                if RandomData[Index] == "Zooming" then
                    Args[Index] = true
                elseif RandomData[Index] == "FirstPerson" then
                    Args[Index] = true
                end
            end
        end

        return OldFetch(Self, Name, unpack(Args))
    end

    return OldFetch(Self, Name, ...)
end))

setupvalue(Bullets.Fire, 1, function(Character, CCamera, Weapon, ...)
    if Window.Flags["AR2/NoSpread"] then
        local OldMoveState = Character.MoveState
        local OldZooming = Character.Zooming
        local OldFirstPerson = CCamera.FirstPerson

        Character.MoveState = "Walking"
        Character.Zooming = true
        CCamera.FirstPerson = true

        local ReturnArgs = {GetSpreadAngle(Character, CCamera, Weapon, ...)}

        Character.MoveState = OldMoveState
        Character.Zooming = OldZooming
        CCamera.FirstPerson = OldFirstPerson

        return unpack(ReturnArgs)
    end

    return GetSpreadAngle(Character, CCamera, Weapon, ...)
end)
setupvalue(CastLocalBullet, 6, function(...)
    if Window.Flags["AR2/BulletTracer/Enabled"] then
        local Args = {...}
        if not Args[7] then return ImpactEffects(...) end
        Radical.Utilities.MakeBeam(Args[5], Args[3], Window.Flags["AR2/BulletTracer/Color"])
    end

    return ImpactEffects(...)
end)
setupvalue(Bullets.Fire, 6, function(...)
    if Window.Flags["AR2/Recoil/Enabled"] then
        local ReturnArgs = {GetFireImpulse(...)}

        for Index = 1, #ReturnArgs do
            ReturnArgs[Index] *= (Window.Flags["AR2/Recoil/Value"] / 100)
        end

        return unpack(ReturnArgs)
    end

    return GetFireImpulse(...)
end)
setupvalue(VehicleController.Step, 2, function(Self, Throttle, ...)
    if Window.Flags["AR2/Vehicle/Enabled"] then
        if not PlayerClass.Character then return end
        Throttle = Window.Flags["AR2/Vehicle/Instant"]
        and PlayerClass.Character.MoveVector.Z or -Throttle

        for Index, Wheel in pairs(Self.Wheels:GetChildren()) do
            local DriveMotor = Wheel:FindFirstChild("Drive Motor")
            local PrimaryPart = Wheel.PrimaryPart

            if not DriveMotor or not PrimaryPart then continue end
            PrimaryPart.CustomPhysicalProperties = PhysicalProperties.new(10, 2, 0)
            DriveMotor.AngularVelocity = Throttle * (Window.Flags["AR2/Vehicle/MaxSpeed"] / (PrimaryPart.Size.Y / 2))
        end

        return
    end

    return SetWheelSpeeds(Self, Throttle, ...)
end)
setupvalue(VehicleController.Step, 3, function(Self, Steer, Throttle, ...)
    if Window.Flags["AR2/Vehicle/Enabled"] then
        if not PlayerClass.Character then return end
        Steer = Window.Flags["AR2/Vehicle/Instant"]
        and -PlayerClass.Character.MoveVector.X or -Steer

        for Index, Wheel in pairs(Self.Wheels:GetChildren()) do
            local WheelPhysics = Self.Config.Physics.Wheels[Wheel.Name]
            if not WheelPhysics or not WheelPhysics.DoesSteer then continue end

            local DriveMotor = Wheel:FindFirstChild("Drive Motor")
            if not DriveMotor then continue end

            local Attachment = Wheel.PrimaryPart:FindFirstChild("Attachment")
            local Angle = math.rad(WheelPhysics.SteerAngle * Steer)

            if Attachment then
                Angle += math.rad(Attachment.Orientation.Y)
            end

            DriveMotor.Attachment0.CFrame = CFrame.Angles(0, Angle, 0)
        end

        return
    end

    return SetSteerWheels(Self, Steer, Throttle, ...)
end)
setupvalue(Firearm, 7, function(...)
    if Window.Flags["AR2/InstantReload"] then
        local Args = {...}

        for Index = 0, Args[3].LoopCount do
            Args[4]("Commit", "Load")
        end

        Args[4]("Commit", "End")
        return true
    end

    return AnimatedReload(...)
end)
setupvalue(InteractHeartbeat, 11, function(...)
    if Window.Flags["AR2/InstantSearch"] then
        local ReturnArgs = {FindItemData(...)}
        if ReturnArgs[4] then ReturnArgs[4] = 0 end

        return unpack(ReturnArgs)
    end

    return FindItemData(...)
end)

local OldFire; OldFire = hookfunction(Bullets.Fire, newcclosure(function(Self, ...)
    if SilentAim and math.random(100) <= Window.Flags["SilentAim/HitChance"] then
        local Args = {...}
        local BodyPart = SilentAim[3]
        local BodyPartPosition = BodyPart.Position
        local Direction = BodyPartPosition - Args[4]

        if Window.Flags["AR2/MagicBullet/Enabled"] then
            local Distance = math.clamp(Direction.Magnitude, 0, Window.Flags["AR2/MagicBullet/Depth"])
            Args[4] = Args[4] + (Direction.Unit * Distance)
        end

        BodyPartPosition = SolveTrajectory(BodyPartPosition, BodyPart.AssemblyLinearVelocity,
        Direction.Magnitude / ProjectileSpeed, ProjectileGravity)

        ProjectileDirection = (BodyPartPosition - Args[4]).Unit
        Args[5] = ProjectileDirection

        return OldFire(Self, unpack(Args))
    end

    local Args = {...}
    ProjectileDirection = Args[5]

    return OldFire(Self, ...)
end))

local OldFlinch; OldFlinch = hookfunction(CharacterCamera.Flinch, newcclosure(function(Self, ...)
    if Window.Flags["AR2/NoFlinch"] then return end
    return OldFlinch(Self, ...)
end))
local OldCharacterGroundCast; OldCharacterGroundCast = hookfunction(Raycasting.CharacterGroundCast, newcclosure(function(Self, Position, LengthDown, ...)
    if PlayerClass.Character and Position == PlayerClass.Character.RootPart.CFrame then
        if Window.Flags["AR2/UseInAir"] then
            return GroundPart, CFrame.new(), Vector3.new(0, 1, 0)
        end
    end
    return OldCharacterGroundCast(Self, Position, LengthDown, ...)
end))
local OldPlayAnimation; OldPlayAnimation = hookfunction(Animators.PlayAnimation, newcclosure(function(Self, Path, ...)
    if Path == "Actions.Fall Impact" and Window.Flags["AR2/NoFallImpact"] then return end
    return OldPlayAnimation(Self, Path, ...)
end))

local OldCD; OldCD = hookfunction(Events["Character Dead"], newcclosure(function(...)
    if Window.Flags["AR2/FastRespawn"] then
        task.spawn(function() SetIdentity(2)
            PlayerClass:UnloadCharacter()
            Interface:Hide("Reticle")
            task.wait(0.5)
            PlayerClass:LoadCharacter()
        end)
    end

    return OldCD(...)
end))
local OldLSU; OldLSU = hookfunction(Events["Lighting State Update"], newcclosure(function(Data, ...)
    LightingState = Data
    OldBaseTime = LightingState.BaseTime
    return OldLSU(Data, ...)
end))
local OldSquadUpdate; OldSquadUpdate = hookfunction(Events["Squad Update"], newcclosure(function(Data, ...)
    SquadData = Data
    return OldSquadUpdate(Data, ...)
end))
local OldICA; OldICA = hookfunction(Events["Inventory Container Added"], newcclosure(function(Id, Data, ...)
    if not Window.Flags["AR2/ESP/Items/Containers/Enabled"] then return OldICA(Id, Data, ...) end

    if Data.Type ~= "Corpse" or Data.Type ~= "Vehicle" then
        if Data.WorldPosition and Length(Data.Occupants) > 0 then
            AddObject:Fire(Data.Id, CIIC(Data), Data.WorldPosition,
            "AR2/ESP/Items", "AR2/ESP/Items/Containers", Window.Flags)
        end
    end

    return OldICA(Id, Data, ...)
end))
local OldCC; OldCC = hookfunction(Events["Container Changed"], newcclosure(function(Data, ...)
    if not Window.Flags["AR2/ESP/Items/Containers/Enabled"] then return OldCC(Data, ...) end

    RemoveObject:Fire(Data.Id)

    if Data.Type ~= "Corpse" or Data.Type ~= "Vehicle" then
        if Data.WorldPosition and Length(Data.Occupants) > 0 then
            AddObject:Fire(Data.Id, CIIC(Data), Data.WorldPosition,
            "AR2/ESP/Items", "AR2/ESP/Items/Containers", Window.Flags)
        end
    end

    return OldCC(Data, ...)
end))

if PlayerClass.Character then
    HookCharacter(PlayerClass.Character)
end
PlayerClass.CharacterAdded:Connect(function(Character)
    HookCharacter(Character)
end)

Interface:GetVisibilityChangedSignal("Map"):Connect(function(Visible)
    if Visible and Window.Flags["AR2/MapESP"] then
        Interface:Get("Map"):EnableGodview()
    else
        Interface:Get("Map"):DisableGodview()
    end
end)

Radical.Utilities.NewThreadLoop(0, function()
    if not (Aimbot or Window.Flags["Aimbot/AlwaysEnabled"]) then return end

    AimAt(GetClosest(
        Window.Flags["Aimbot/Enabled"],
        Window.Flags["Aimbot/TeamCheck"],
        Window.Flags["Aimbot/VisibilityCheck"],
        Window.Flags["Aimbot/DistanceCheck"],
        Window.Flags["Aimbot/DistanceLimit"],
        Window.Flags["Aimbot/FOV/Radius"],
        Window.Flags["Aimbot/Priority"][1],
        Window.Flags["Aimbot/BodyParts"],
        Window.Flags["Aimbot/Prediction"]
    ), Window.Flags["Aimbot/Sensitivity"] / 100)
end)
Radical.Utilities.NewThreadLoop(0, function()
    SilentAim = GetClosest(
        Window.Flags["SilentAim/Enabled"],
        Window.Flags["SilentAim/TeamCheck"],
        Window.Flags["SilentAim/VisibilityCheck"],
        Window.Flags["SilentAim/DistanceCheck"],
        Window.Flags["SilentAim/DistanceLimit"],
        Window.Flags["SilentAim/FOV/Radius"],
        Window.Flags["SilentAim/Priority"][1],
        Window.Flags["SilentAim/BodyParts"]
    )
end)
Radical.Utilities.NewThreadLoop(0, function()
    if not (Trigger or Window.Flags["Trigger/AlwaysEnabled"]) then return end
    if not isrbxactive() then return end

    local TriggerClosest = GetClosest(
        Window.Flags["Trigger/Enabled"],
        Window.Flags["Trigger/TeamCheck"],
        Window.Flags["Trigger/VisibilityCheck"],
        Window.Flags["Trigger/DistanceCheck"],
        Window.Flags["Trigger/DistanceLimit"],
        Window.Flags["Trigger/FOV/Radius"],
        Window.Flags["Trigger/Priority"][1],
        Window.Flags["Trigger/BodyParts"],
        Window.Flags["Trigger/Prediction"]
    ) if not TriggerClosest then return end

    task.wait(Window.Flags["Trigger/Delay"]) mouse1press()
    if Window.Flags["Trigger/HoldMouseButton"] then
        while task.wait() do
            TriggerClosest = GetClosest(
                Window.Flags["Trigger/Enabled"],
                Window.Flags["Trigger/TeamCheck"],
                Window.Flags["Trigger/VisibilityCheck"],
                Window.Flags["Trigger/DistanceCheck"],
                Window.Flags["Trigger/DistanceLimit"],
                Window.Flags["Trigger/FOV/Radius"],
                Window.Flags["Trigger/Priority"][1],
                Window.Flags["Trigger/BodyParts"],
                Window.Flags["Trigger/Prediction"]
            ) if not TriggerClosest or not Trigger then break end
        end
    end mouse1release()
end)

Radical.Utilities.NewThreadLoop(0, function(Delta)
    if not Window.Flags["AR2/WalkSpeed/Enabled"] then return end

    if not PlayerClass.Character then return end
    local RootPart = PlayerClass.Character.RootPart
    local MoveDirection = Radical.Utilities.MovementToDirection() * XZVector

    RootPart.CFrame += MoveDirection * Delta * Window.Flags["AR2/WalkSpeed/Speed"] * 100
end)
Radical.Utilities.NewThreadLoop(0, function(Delta)
    if not Window.Flags["AR2/Fly/Enabled"] then return end

    if not PlayerClass.Character then return end
    local RootPart = PlayerClass.Character.RootPart
    local MoveDirection = Radical.Utilities.MovementToDirection()

    RootPart.AssemblyLinearVelocity = Vector3.zero
    RootPart.CFrame += MoveDirection * (Window.Flags["AR2/Fly/Speed"] * (Delta * 60))
end)
Radical.Utilities.NewThreadLoop(0.1, function()
    if not Window.Flags["AR2/MeleeAura"]
    and not Window.Flags["AR2/AntiZombie/MeleeAura"] then return end

    local Enemies = GetEnemyForMelee(
        Window.Flags["AR2/MeleeAura"],
        Window.Flags["AR2/AntiZombie/MeleeAura"]
    )

    if not Enemies then return end
    if #Enemies == 0 then return end
    SwingMelee(Enemies)
end)
Radical.Utilities.NewThreadLoop(1, function()
    if not Window.Flags["AR2/HeadExpander"] then return end
    for Index, Player in pairs(PlayerService:GetPlayers()) do
        if Player == LocalPlayer then continue end
        local Character = GetPlayerCharacter(Player)
        if not Character then continue end
        local Head = Character:FindFirstChild("Head")
        if not Head then continue end

        Head.Size = Mannequin.Head.Size * Window.Flags["AR2/HeadExpander/Value"]
        Head.Transparency = Window.Flags["AR2/HeadExpander/Transparency"]
        Head.CanCollide = true
    end
end)
Radical.Utilities.NewThreadLoop(0.5, function()
    if not Window.Flags["AR2/Lighting/Enabled"] then return end
    local Time = LightingState.StartTime + Workspace:GetServerTimeNow()
    LightingState.BaseTime = Time + ((Window.Flags["AR2/Lighting/Time"] * (86400 / LightingState.CycleLength)) % 1440)
end)

-- FIXED: Loot, Randoms, and LootBins ESP loops removed (paths no longer exist)

for Index, Corpse in pairs(Corpses:GetChildren()) do
    if Corpse.Name == "Zombie" then continue end
    if not Corpse.PrimaryPart then continue end

    Radical.Utilities.Drawing:AddObject(
        Corpse, Corpse.Name, Corpse.PrimaryPart,
        "AR2/ESP/Corpses", "AR2/ESP/Corpses", Window.Flags
    )
end
for Index, Zombie in pairs(Zombies.Mobs:GetChildren()) do
    if not Zombie.PrimaryPart then continue end
    local Config = require(Zombies.Configs[Zombie.Name])

    if not Config.Inherits then continue end
    for Index, Inherit in pairs(Config.Inherits) do
        for Index, Data in pairs(ZombieInherits) do
            if Inherit ~= Data[1] then continue end
            local InheritName = Inherit:gsub("Presets.", ""):gsub(" ", "")

            Radical.Utilities.Drawing:AddObject(
                Zombie, Zombie.Name, Zombie.PrimaryPart, "AR2/ESP/Zombies",
                "AR2/ESP/Zombies/"..InheritName, Window.Flags
            )
        end
    end
end
for Index, Vehicle in pairs(Vehicles:GetChildren()) do
    if not Vehicle.PrimaryPart then continue end

    Radical.Utilities.Drawing:AddObject(
        Vehicle, Vehicle.Name, Vehicle.PrimaryPart,
        "AR2/ESP/Vehicles", "AR2/ESP/Vehicles", Window.Flags
    )
end

Corpses.ChildAdded:Connect(function(Corpse)
    if Corpse.Name == "Zombie" then return end
    repeat task.wait() until Corpse.PrimaryPart
    Radical.Utilities.Drawing:AddObject(
        Corpse, Corpse.Name, Corpse.PrimaryPart,
        "AR2/ESP/Corpses", "AR2/ESP/Corpses", Window.Flags
    )
end)
Zombies.Mobs.ChildAdded:Connect(function(Zombie)
    repeat task.wait() until Zombie.PrimaryPart
    local Config = require(Zombies.Configs[Zombie.Name])

    if not Config.Inherits then return end
    for Index, Inherit in pairs(Config.Inherits) do
        for Index, Data in pairs(ZombieInherits) do
            if Inherit ~= Data[1] then continue end
            local InheritName = Inherit:gsub("Presets.", ""):gsub(" ", "")

            Radical.Utilities.Drawing:AddObject(
                Zombie, Zombie.Name, Zombie.PrimaryPart, "AR2/ESP/Zombies",
                "AR2/ESP/Zombies/"..InheritName, Window.Flags
            )
        end
    end
end)
Vehicles.ChildAdded:Connect(function(Vehicle)
    repeat task.wait() until Vehicle.PrimaryPart

    Radical.Utilities.Drawing:AddObject(
        Vehicle, Vehicle.Name, Vehicle.PrimaryPart,
        "AR2/ESP/Vehicles", "AR2/ESP/Vehicles", Window.Flags
    )
end)

Corpses.ChildRemoved:Connect(function(Corpse)
    Radical.Utilities.Drawing:RemoveObject(Corpse)
end)
Zombies.Mobs.ChildRemoved:Connect(function(Zombie)
    Radical.Utilities.Drawing:RemoveObject(Zombie)
end)
Vehicles.ChildRemoved:Connect(function(Vehicle)
    Radical.Utilities.Drawing:RemoveObject(Vehicle)
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

for Index, Player in pairs(PlayerService:GetPlayers()) do
    if Player == LocalPlayer then continue end
    Radical.Utilities.Drawing:AddESP(Player, "Player", "ESP/Player", Window.Flags)
    task.spawn(function() CheckForAdmin(Player) end)
end
PlayerService.PlayerAdded:Connect(function(Player)
    Radical.Utilities.Drawing:AddESP(Player, "Player", "ESP/Player", Window.Flags)
    task.spawn(function() CheckForAdmin(Player) end)
end)
PlayerService.PlayerRemoving:Connect(function(Player)
    Radical.Utilities.Drawing:RemoveESP(Player)
end)
