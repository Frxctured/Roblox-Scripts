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
    ESP = {
        Murderer = false,
        Sheriff = false,
        Innocent = false,
        Gun = false,
    },
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local playerRoles = {}
local collectedCoins = {}
local isInRound = false
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

local StatusLabel = MainTab:CreateLabel("Status: Initializing...")

MainTab:CreateToggle({
    Name = "Coin Farm",
    CurrentValue = false,
    Callback = function(Value) getgenv().Config.Farm.Active = Value end,
})

MainTab:CreateSlider({
    Name = "Farm Speed",
    Range = {25, 85},
    Increment = 1,
    Suffix = " studs/s",
    CurrentValue = 50,
    Callback = function(Value) getgenv().Config.Farm.Speed = Value end,
})

MainTab:CreateToggle({
    Name = "Reset at full bag",
    CurrentValue = true,
    Callback = function(Value) getgenv().Config.Farm.Reset = Value end,
})


-- ## ESP TAB ## --

ESPTab:CreateToggle({
    Name = "Show Murderer",
    CurrentValue = false,
    Callback = function(Value) getgenv().Config.ESP.Murderer = Value end,
})

ESPTab:CreateToggle({
    Name = "Show Sheriff",
    CurrentValue = false,
    Callback = function(Value) getgenv().Config.ESP.Sheriff = Value end,
})

ESPTab:CreateToggle({
    Name = "Show Innocents (only as Murderer)",
    CurrentValue = false,
    Callback = function(Value) getgenv().Config.ESP.Innocent = Value end,
})

ESPTab:CreateToggle({
    Name = "Show Gun Drop",
    CurrentValue = false,
    Callback = function(Value) getgenv().Config.ESP.Gun = Value end,
})


-- ## OTHER TAB ## --

OtherTab:CreateButton({
    Name = "Server Hop",
    Callback = function()
        local Servers = game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Desc&limit=100"))
        for i,v in pairs(Servers.data) do
            if v.playing < v.maxPlayers and v.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
                break
            end
        end
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
    CfgESPGun = DEBUGTab:CreateLabel("Cfg ESP Gun: ...")
}

task.spawn(function()
    while true do
        task.wait(0.5) -- Update every 0.5s to reduce lag
        pcall(function()
            -- State Variables
            DebugLabels.RoundResult:Set("isInRound: " .. tostring(isInRound))
            DebugLabels.LobbyResult:Set("isInLobby: " .. tostring(isInLobby))
            DebugLabels.CoinsResult:Set("collectedCount: " .. tostring(collectedCount) .. " / currentMax: " .. tostring(currentMax))
            
            local roleCount = 0
            for _ in pairs(playerRoles) do roleCount = roleCount + 1 end
            DebugLabels.RolesResult:Set("Roles Found: " .. tostring(roleCount))
            
            -- Config Variables
            local cfg = getgenv().Config
            DebugLabels.FarmResult:Set("Farm.Active: " .. tostring(cfg.Farm.Active))
            DebugLabels.CfgSpeed:Set("Farm.Speed: " .. tostring(cfg.Farm.Speed))
            DebugLabels.CfgReset:Set("Farm.Reset: " .. tostring(cfg.Farm.Reset))
            
            DebugLabels.CfgESPMurder:Set("ESP.Murderer: " .. tostring(cfg.ESP.Murderer))
            DebugLabels.CfgESPSheriff:Set("ESP.Sheriff: " .. tostring(cfg.ESP.Sheriff))
            DebugLabels.CfgESPInnocent:Set("ESP.Innocent: " .. tostring(cfg.ESP.Innocent))
            DebugLabels.CfgESPGun:Set("ESP.Gun: " .. tostring(cfg.ESP.Gun))
        end)
    end
end)


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

    if not isInRound then 
        clearHighlights() 
        return 
    end    -- Dynamic Role Detection (Checks Backpack/Character for weapons)
    local function getRole(p)
        if p.Backpack:FindFirstChild("Knife") or (p.Character and p.Character:FindFirstChild("Knife")) then
            return "Murderer"
        elseif p.Backpack:FindFirstChild("Gun") or (p.Character and p.Character:FindFirstChild("Gun")) then
            return "Sheriff"
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
        
        if pRole == "Murderer" and getgenv().Config.ESP.Murderer then
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif pRole == "Sheriff" and getgenv().Config.ESP.Sheriff then
            hl.FillColor = Color3.fromRGB(0, 120, 255)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif amIMurderer and getgenv().Config.ESP.Innocent  then
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
    if getgenv().Config.ESP.Gun then
        local gun = workspace:FindFirstChild("GunDrop", true)
        if gun then
            local ghl = Instance.new("Highlight", gun)
            ghl.Name = "GunHighlight"
            ghl.FillColor = Color3.fromRGB(255, 215, 0)
            ghl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end
end)

--- ### 5. REMOTE LISTENERS ### ---
local GameplayRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay")

GameplayRemotes.RoundStart.OnClientEvent:Connect(function(_, roles) 
    playerRoles = roles 
    isInRound = true 
    isInLobby = false
    collectedCoins = {}
    collectedCount = 0
end)

GameplayRemotes.RoundEndFade.OnClientEvent:Connect(function() 
    playerRoles = {} 
    isInRound = false 
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
        if getgenv().Config.Farm.Active then
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
        if not getgenv().Config.Farm.Active then
            StatusLabel:Set("Status: Farm Disabled")
        elseif inInLobby then
            StatusLabel:Set("Status: Waiting for next Round...")
        elseif collectedCount >= currentMax then
            StatusLabel:Set("Status: Bag Full - Resetting")
        else
            StatusLabel:Set("Status: Farming ("..collectedCount.."/"..currentMax..")")
        end

        -- Check for death to stop farming permanently for this round
        if isInRound and humanoid and humanoid.Health <= 0 then
            isInLobby = true
        end

        if getgenv().Config.Farm.Active and isInRound and not isInLobby and hrp and humanoid and humanoid.Health > 0 then
            
            -- AGGRESSIVE RESET LOGIC
            if getgenv().Config.Farm.Reset and collectedCount >= currentMax and currentMax > 0 then
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
                local adaptiveDelay = math.clamp(distanceToCoin / 35, getgenv().Config.Farm.MinWait, 2.5)
                
                bodyVelocity.Velocity = Vector3.zero
                task.wait(adaptiveDelay)

                while getgenv().Config.Farm.Active and target and target.Parent and (target.Position-hrp.Position).Magnitude > 0.5 do
                    if isInLobby or humanoid.Health <= 0 then break end
                    bodyVelocity.Velocity = (target.Position - hrp.Position).Unit * getgenv().Config.Farm.Speed
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
