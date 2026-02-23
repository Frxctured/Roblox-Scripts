local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Frxctured's MM2 Menu",
    Icon = "audio-waveform",
    LoadingTitle = "Loading bleh :3",
    LoadingSubtitle = "by Frxctured",
    ShowText = "Menu",
    ConfigurationSaving = { Enabled = false },
})

-- ### 1. STATE MANAGEMENT ### --
getgenv().Config = {
    Farm = {
        Active = false,
        Speed = 50,
        MinWait = 0.2,
        Reset = true,
    },
    AutoWin = {
        Murderer = false,
        Sheriff = false,
        Innocent = false,
    },
    ESP = {
        Murderer = false,
        Sheriff = false,
        Innocent = false,
        Gun = false,
    },
}
local cfg = getgenv().Config

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local playerRoles = {}
local collectedCoins = {}
local isActiveRound = true
local isInLobby = true
local collectedCount = 0
local currentMax = 40 
local bodyVelocity = nil

-- ### UI TABS & ELEMENTS ### --
local MainTab = Window:CreateTab("Farming", "hand-coins")
local ESPTab = Window:CreateTab("ESP", "eye")
local OtherTab = Window:CreateTab("Other", "info")

local DEBUGTab = Window:CreateTab("Debug", "bug")


-- ## MAIN TAB ## --

-- # Coin farming # --
MainTab:CreateSection("Coins")

MainTab:CreateToggle({
    Name = "Coin Farm",
    CurrentValue = false,
    Callback = function(Value) cfg.Farm.Active = Value end,
})

local StatusLabel = MainTab:CreateLabel("Status: Initializing...")

MainTab:CreateSlider({
    Name = "Farm Speed",
    Range = {25, 85},
    Increment = 1,
    Suffix = " studs/s",
    CurrentValue = 50,
    Callback = function(Value) cfg.Farm.Speed = Value end,
})

MainTab:CreateToggle({
    Name = "Reset at full bag",
    CurrentValue = true,
    Callback = function(Value) cfg.Farm.Reset = Value end,
})

-- # Auto Win # -- (soon)
MainTab:CreateSection("Auto Win (soon)")

MainTab:CreateToggle({
    Name = "Win as Murderer",
    CurrentValue = false,
    Callback = function(Value) cfg.AutoWin.Murderer = Value end,
})

local winAsSheriffToggle = MainTab:CreateToggle({
    Name = "Win as Sheriff",
    CurrentValue = false,
    Callback = function(Value) 
        cfg.AutoWin.Sheriff = Value 
        if cfg.AutoWin.Innocent then
            winAsSheriffToggle:Set(true)
        end
    end,
})

MainTab:CreateToggle({
    Name = "Win as Innocent (Sheriff)",
    CurrentValue = false,
    Callback = function(Value) 
        cfg.AutoWin.Innocent = Value 
        if Value then
            winAsSheriffToggle:Set(true)
        end
    end,
})

-- ## ESP TAB ## --

ESPTab:CreateToggle({
    Name = "Show Murderer",
    CurrentValue = false,
    Callback = function(Value) cfg.ESP.Murderer = Value end,
})

ESPTab:CreateToggle({
    Name = "Show Sheriff",
    CurrentValue = false,
    Callback = function(Value) cfg.ESP.Sheriff = Value end,
})

ESPTab:CreateToggle({
    Name = "Show Innocents (only as Murderer)",
    CurrentValue = false,
    Callback = function(Value) cfg.ESP.Innocent = Value end,
})

ESPTab:CreateToggle({
    Name = "Show Gun Drop",
    CurrentValue = false,
    Callback = function(Value) cfg.ESP.Gun = Value end,
})


-- ## OTHER TAB ## --

OtherTab:CreateButton({
    Name = "Get Gun",
    Callback = function()
        local gun = workspace:FindFirstChild("GunDrop", true)
        if gun then
            local oldCFrame = hrp.CFrame
            hrp.CFrame = gun.CFrame
            task.wait(0.1)
            hrp.CFrame = oldCFrame
        end
    end,
})

OtherTab:CreateButton({
    Name = "Server Hop",
    Callback = function()
        task.spawn(function()
            local success, err = pcall(function()
                local Http = game:GetService("HttpService")
                local TPS = game:GetService("TeleportService")
                local Api = "https://games.roblox.com/v1/games/"
                local _place = game.PlaceId
                local _servers = Api.._place.."/servers/Public?sortOrder=Desc&limit=100"
                
                local List = Http:JSONDecode(game:HttpGet(_servers))
                if List and List.data then
                    for i,v in next, List.data do
                        if v.playing < v.maxPlayers and v.id ~= game.JobId then
                            TPS:TeleportToPlaceInstance(_place, v.id, player)
                            return
                        end
                    end
                end
            end)
            if not success then 
                warn("Server Hop Failed: " .. tostring(err)) 
                Rayfield:Notify({
                    Title = "Serverhop Failed",
                    Content = "Error content: ".. tostring(err),
                    Duration = 3,
                    Image = "circle-x",
                })
            end
        end)
    end,
})

-- ## DEBUG TAB ## --

DEBUGTab:CreateSection("Live Variables")

local DebugLabels = {
    RoundResult = DEBUGTab:CreateLabel("Round: ..."),
    LobbyResult = DEBUGTab:CreateLabel("Lobby: ..."),
    CoinsResult = DEBUGTab:CreateLabel("Coins: ..."),
    RolesResult = DEBUGTab:CreateLabel("Roles Found: ..."),
    FarmResult = DEBUGTab:CreateLabel("Farm Active: ..."),
    
    -- Config Debugs
    CfgSpeed = DEBUGTab:CreateLabel("Cfg Speed: ..."),
    CfgReset = DEBUGTab:CreateLabel("Cfg Reset: ..."),
    CfgESPMurder = DEBUGTab:CreateLabel("Cfg ESP Murder: ..."),
    CfgESPSheriff = DEBUGTab:CreateLabel("Cfg ESP Sheriff: ..."),
    CfgESPInnocent = DEBUGTab:CreateLabel("Cfg ESP Innocent: ..."),
    CfgESPGun = DEBUGTab:CreateLabel("Cfg ESP Gun: ..."),
    
    -- Auto Win Debugs
    CfgAutoWinMurder = DEBUGTab:CreateLabel("Cfg AutoWin Murder: ..."),
    CfgAutoWinSheriff = DEBUGTab:CreateLabel("Cfg AutoWin Sheriff: ..."),
    CfgAutoWinInnocent = DEBUGTab:CreateLabel("Cfg AutoWin Innocent: ...")
}

task.spawn(function()
    while true do
        task.wait(0.5) -- Update every 0.5s to reduce lag
        pcall(function()
            -- State Variables
            DebugLabels.RoundResult:Set("isActiveRound: " .. tostring(isActiveRound))
            DebugLabels.LobbyResult:Set("isInLobby: " .. tostring(isInLobby))
            DebugLabels.CoinsResult:Set("collectedCount: " .. tostring(collectedCount) .. " / currentMax: " .. tostring(currentMax))
            
            local roleCount = 0
            for _ in pairs(playerRoles) do roleCount = roleCount + 1 end
            DebugLabels.RolesResult:Set("Roles Found: " .. tostring(roleCount))
            
            -- Config Variables
            DebugLabels.FarmResult:Set("Farm.Active: " .. tostring(cfg.Farm.Active))
            DebugLabels.CfgSpeed:Set("Farm.Speed: " .. tostring(cfg.Farm.Speed))
            DebugLabels.CfgReset:Set("Farm.Reset: " .. tostring(cfg.Farm.Reset))
            
            DebugLabels.CfgESPMurder:Set("ESP.Murderer: " .. tostring(cfg.ESP.Murderer))
            DebugLabels.CfgESPSheriff:Set("ESP.Sheriff: " .. tostring(cfg.ESP.Sheriff))
            DebugLabels.CfgESPInnocent:Set("ESP.Innocent: " .. tostring(cfg.ESP.Innocent))
            DebugLabels.CfgESPGun:Set("ESP.Gun: " .. tostring(cfg.ESP.Gun))

            -- To be added (soon)
            DebugLabels.CfgAutoWinMurder:Set("AutoWin.Murderer: " .. tostring(cfg.AutoWin.Murderer))
            DebugLabels.CfgAutoWinSheriff:Set("AutoWin.Sheriff: " .. tostring(cfg.AutoWin.Sheriff))
            DebugLabels.CfgAutoWinInnocent:Set("AutoWin.Innocent: " .. tostring(cfg.AutoWin.Innocent))
        end)
    end
end)

-- DEBUG: Log all Gameplay Remote Calls
for _, remote in ipairs(ReplicatedStorage.Remotes.Gameplay:GetChildren()) do
    if remote:IsA("RemoteEvent") then
        remote.OnClientEvent:Connect(function(...)
            local args = {...}
            print("REMOTE EVENT FIRED: " .. remote.Name)
            for i, v in ipairs(args) do
                print("  Arg " .. i .. ": ", v)
            end
            print("---------------------------------------------------")
        end)
    end
end

--- ### 3. AFK ANTI-KICK ### ---
-- Prevents 20-minute idle kick
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        StatusLabel:Set("Status: Anti-AFK Triggered")
    end)
end)

--- ### 4. REACTIVE VISUALS ENGINE ### ---

local function clearHighlights()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("RoleHighlight") then 
            p.Character.RoleHighlight:Destroy() 
        end
    end
end

RunService.Heartbeat:Connect(function()

    if not isActiveRound then 
        clearHighlights() 
        return 
    end
    
    local function getRole(p)
        -- if deadPlayers[p.Name] then return "Dead" end -- Ignore dead players
        if playerRoles[p.Name] then
            return playerRoles[p.Name]
        end
        return "Innocent" 
    end

    local myRole = getRole(player)
    local amIMurderer = (myRole == "Murderer")

    for _, p in pairs(Players:GetPlayers()) do
        if p == player or not p.Character then continue end
        
        local pRole = getRole(p)
        local hl = p.Character:FindFirstChild("RoleHighlight") or Instance.new("Highlight", p.Character)
        hl.Name = "RoleHighlight"
        
        if pRole == "Murderer" and cfg.ESP.Murderer then
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif pRole == "Sheriff" and cfg.ESP.Sheriff then
            hl.FillColor = Color3.fromRGB(0, 120, 255)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif pRole == "Hero" and cfg.ESP.Sheriff then
            hl.FillColor = Color3.fromRGB(255, 215, 0)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif amIMurderer and (pRole == "Innocent" or pRole == "inno") and cfg.ESP.Innocent  then
            hl.FillColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.8 
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.OutlineTransparency = 0.5
            hl.Enabled = true
        else
            hl.Enabled = false 
        end
    end

    -- GUN ESP LOGIC
    if cfg.ESP.Gun then
        local gun = workspace:FindFirstChild("GunDrop", true)
        if gun then
            local ghl = Instance.new("Highlight", gun)
            ghl.Name = "GunHighlight"
            ghl.FillColor = Color3.fromRGB(255, 215, 0)
            ghl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end
end)

-- Kill All Logic (Murderer)
local function KillAll()
    local knife = character:FindFirstChild("Knife") or player.Backpack:FindFirstChild("Knife")
    if not knife then return end

    character.Humanoid:EquipTool(knife)

    for _, target in ipairs(Players:GetPlayers()) do
        if not isActiveRound or not cfg.AutoWin.Murderer or not character or character.Humanoid.Health <= 0 then break end
        
        if target ~= player and target.Character then
            local thrp = target.Character:FindFirstChild("HumanoidRootPart")
            local thumanoid = target.Character:FindFirstChild("Humanoid")
            
            if thrp and thumanoid and thumanoid.Health > 0 and playerRoles[target.Name] then

                hrp.CFrame = thrp.CFrame * CFrame.new(0, 0, 2)
                task.wait() 
                
                if knife.Parent ~= character then character.Humanoid:EquipTool(knife) end
                knife:Activate()
                task.wait()
            end
        end
    end
end

task.spawn(function()
    while true do
        if isActiveRound and cfg.AutoWin.Murderer then
            local isMurderer = false
            if player.Backpack:FindFirstChild("Knife") or (character and character:FindFirstChild("Knife")) then
                isMurderer = true
            end

            if isMurderer then
                KillAll() 
            end
        end
        task.wait(1)
    end
end)

--- ### 5. REMOTE LISTENERS ### ---
local GameplayRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay")

-- New Listener for Early Role Detection via PlayerDataChanged
GameplayRemotes:WaitForChild("PlayerDataChanged").OnClientEvent:Connect(function(arg1)
    if type(arg1) == "table" then
        for key, data in pairs(arg1) do
            local playerName = nil
            
            -- Resolve Key to Player Name
            if typeof(key) == "Instance" and key:IsA("Player") then
                playerName = key.Name
            elseif type(key) == "string" then
                -- Check if this string is a player name (simple check)
                playerName = key
            end
            
            -- Process Data if valid
            -- User specified NO MAPPING is needed. We trust the remote provides correct role names.
            if playerName and type(data) == "table" then
                if data.Role then

                    local role = data.Role
                    playerRoles[playerName] = role
                    
                    if role == "Murderer" or role == "murd" then
                        warn("!!! MURDERER DETECTED (Remote): " .. playerName)
                    elseif role == "Sheriff" or role == "sheriff" or role == "hero" then
                        warn("!!! SHERIFF DETECTED (Remote): " .. playerName)
                    end
                    
                    isActiveRound = true
                end
                
                -- Handle Dead/Killed updates
                if data.Dead == true or data.Killed == true then
                    deadPlayers[playerName] = true
                    -- Remove highlight immediately if they die
                    if Players:FindFirstChild(playerName) and Players[playerName].Character and Players[playerName].Character:FindFirstChild("RoleHighlight") then
                        Players[playerName].Character.RoleHighlight:Destroy()
                    end
                end
            end
        end
    end
end)

GameplayRemotes.RoundStart.OnClientEvent:Connect(function(_, roles) 
    -- playerRoles = roles
    deadPlayers = {}
    isActiveRound = true 
    isInLobby = false
    collectedCoins = {}
    collectedCount = 0
end)

GameplayRemotes.RoundEndFade.OnClientEvent:Connect(function() 
    playerRoles = {} 
    deadPlayers = {}
    isActiveRound = false 
    isInLobby = true 
    clearHighlights() 
    collectedCount = 0
end)

GameplayRemotes.CoinCollected.OnClientEvent:Connect(function(_, cur, max) 
    collectedCount = tonumber(cur) or 0 
    currentMax = tonumber(max) or 50 
    StatusLabel:Set("Status: Farming ("..collectedCount.."/"..currentMax..")")
end)

--- ### 6. THE CORE ENGINE ### ---

RunService.Stepped:Connect(function()
    if character then
        if cfg.Farm.Active then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        else
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

task.spawn(function()
    while true do
        character = player.Character
        hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChild("Humanoid")
        
        -- ### STATUS UPDATE LOGIC ### --
        if not cfg.Farm.Active then
            StatusLabel:Set("Status: Farm Disabled")
        elseif isInLobby then
            StatusLabel:Set("Status: Waiting for next Round...")
        elseif collectedCount >= currentMax then
            StatusLabel:Set("Status: Bag Full - Resetting")
        else
            StatusLabel:Set("Status: Farming ("..collectedCount.."/"..currentMax..")")
        end

        -- Check for death to stop farming permanently for this round
        if isActiveRound and humanoid and humanoid.Health <= 0 then
            isInLobby = true
        end

        if cfg.Farm.Active and isActiveRound and not isInLobby and hrp and humanoid and humanoid.Health > 0 then
            
            -- AGGRESSIVE RESET LOGIC
            if cfg.Farm.Reset and collectedCount >= currentMax and currentMax > 0 then
                humanoid.Health = 0
                collectedCount = 0
                isInLobby = true
                task.wait(2)
                continue
            end

            -- BodyVelocity Setup
            if not bodyVelocity or bodyVelocity.Parent ~= hrp then
                if bodyVelocity then bodyVelocity:Destroy() end
                bodyVelocity = Instance.new("BodyVelocity", hrp)
                bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                humanoid.PlatformStand = true
            end

            -- Target Selection
            local target, shortest = nil, math.huge
            for _, v in pairs(workspace:GetDescendants()) do
                if v.Name == "Coin_Server" and not collectedCoins[v] then
                    local d = (v.Position - hrp.Position).Magnitude
                    if d < shortest then shortest = d target = v end
                end
            end

            if target then
                local distanceToCoin = (target.Position - hrp.Position).Magnitude
                local adaptiveDelay = math.clamp(distanceToCoin / 35, cfg.Farm.MinWait, 2.5)
                
                bodyVelocity.Velocity = Vector3.zero
                task.wait(adaptiveDelay)

                while cfg.Farm.Active and target and target.Parent and (target.Position-hrp.Position).Magnitude > 0.5 do
                    if isInLobby or humanoid.Health <= 0 then break end
                    bodyVelocity.Velocity = (target.Position - hrp.Position).Unit * cfg.Farm.Speed
                    RunService.Heartbeat:Wait()
                end
                
                if bodyVelocity then bodyVelocity.Velocity = Vector3.zero end
                collectedCoins[target] = true
            end
        else
            if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
            if humanoid then humanoid.PlatformStand = false end
        end
        RunService.Heartbeat:Wait()
    end
end)
