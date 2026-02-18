local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FRXCTURED'S MM2",
   LoadingTitle = "Frxctured's MM2 Menu",
   LoadingSubtitle = "by Frxctured",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

-- ### 1. STATE MANAGEMENT ### --
getgenv().Config = {
    Farm = false,
    ESP = true,
    GunESP = true,
    Speed = 50,
    SafetyDist = 18,
    HideDepth = -50,
    MinWait = 0.2
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
local currentMax = 50 
local bodyVelocity = nil

-- ### 2. UI TABS & ELEMENTS ### --
local MainTab = Window:CreateTab("Farming", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)

-- Added Status Label
local StatusLabel = MainTab:CreateLabel("Status: Initializing...")

MainTab:CreateToggle({
   Name = "Coin Farm",
   CurrentValue = false,
   Callback = function(Value) getgenv().Config.Farm = Value end,
})

MainTab:CreateSlider({
   Name = "Farm Speed",
   Range = {25, 85},
   Increment = 1,
   Suffix = " studs/s",
   CurrentValue = 50,
   Callback = function(Value) getgenv().Config.Speed = Value end,
})

MainTab:CreateButton({
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

VisualsTab:CreateToggle({
   Name = "Player Role ESP",
   CurrentValue = true,
   Callback = function(Value) getgenv().Config.ESP = Value end,
})

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
    if not getgenv().Config.ESP then clearHighlights() return end
    
    -- Added isInRound check to ensure we only ESP during gameplay
    if not isInRound then 
        clearHighlights() 
        return 
    end

    -- Dynamic Role Detection (Checks Backpack/Character for weapons)
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
        
        if pRole == "Murderer" then
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif pRole == "Sheriff" then
            hl.FillColor = Color3.fromRGB(0, 120, 255)
            hl.FillTransparency = 0.5
            hl.Enabled = true
        elseif amIMurderer then
            -- Highlight innocents as transparent white for Murderer
            hl.FillColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.8 
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.OutlineTransparency = 0.5
            hl.Enabled = true
        else
            hl.Enabled = false 
        end
    end

    -- RESTORED GUN ESP LOGIC
    if getgenv().Config.GunESP then
        local gun = workspace:FindFirstChild("GunDrop")
        if gun then
            -- local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
            -- if handle and not handle:FindFirstChild("GunHighlight") then
                local ghl = Instance.new("Highlight", gun)
                ghl.Name = "GunHighlight"
                ghl.FillColor = Color3.fromRGB(0, 120, 255)
                ghl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            -- end
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
        if getgenv().Config.Farm then
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
        if not getgenv().Config.Farm then
            StatusLabel:Set("Status: Farm Disabled")
        elseif not isInRound then
            StatusLabel:Set("Status: Waiting for Round...")
        elseif collectedCount >= currentMax then
            StatusLabel:Set("Status: Bag Full - Resetting")
        else
            StatusLabel:Set("Status: Farming ("..collectedCount.."/"..currentMax..")")
        end

        -- Check for death to stop farming permanently for this round
        if isInRound and humanoid and humanoid.Health <= 0 then
            isInLobby = true
        end

        if getgenv().Config.Farm and isInRound and not isInLobby and hrp and humanoid and humanoid.Health > 0 then
            
            -- AGGRESSIVE RESET LOGIC
            if collectedCount >= currentMax and currentMax > 0 then
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
                local adaptiveDelay = math.clamp(distanceToCoin / 35, getgenv().Config.MinWait, 2.5)
                
                bodyVelocity.Velocity = Vector3.zero
                task.wait(adaptiveDelay)

                while getgenv().Config.Farm and target and target.Parent and (target.Position-hrp.Position).Magnitude > 0.5 do
                    if not isInRound or humanoid.Health <= 0 then break end
                    local jitterSpeed = getgenv().Config.Speed + math.random(-3, 3)
                    bodyVelocity.Velocity = (target.Position - hrp.Position).Unit * jitterSpeed
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
