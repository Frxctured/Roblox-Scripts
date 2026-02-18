local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "FRXCTURED'S MM2",
   LoadingTitle = "FrxcturedMM2 Suite",
   LoadingSubtitle = "by Frxctured",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

-- ### 1. STATE MANAGEMENT ### --
getgenv().Config = {
    Farm = false,
    ESP = true,
    GunESP = true,
    AutoHide = true,
    SubtleESP = true,
    Speed = 50,
    SafetyDist = 18,
    HideDepth = -50,
    MinWait = 0.2
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local playerRoles = {}
local collectedCoins = {}
local isHiding = false
local isInRound = false
local collectedCount = 0
local currentMax = 50
local lastHrpPos = hrp.Position
local bodyVelocity = nil

-- ### 2. UI TABS & ELEMENTS ### --
local MainTab = Window:CreateTab("Farming", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)

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

MainTab:CreateToggle({
   Name = "Auto Hide from Murderer",
   CurrentValue = true,
   Callback = function(Value) getgenv().Config.AutoHide = Value end,
})

VisualsTab:CreateToggle({
   Name = "Player Role ESP",
   CurrentValue = true,
   Callback = function(Value) getgenv().Config.ESP = Value end,
})

VisualsTab:CreateToggle({
   Name = "Innocent ESP (As Murd)",
   CurrentValue = true,
   Callback = function(Value) getgenv().Config.SubtleESP = Value end,
})

VisualsTab:CreateToggle({
   Name = "Dropped Gun ESP",
   CurrentValue = true,
   Callback = function(Value) getgenv().Config.GunESP = Value end,
})

--- ### 3. THE VISUALS ENGINE ### ---

local function clearHighlights()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("RoleHighlight") then 
            p.Character.RoleHighlight:Destroy() 
        end
    end
end

local function updateVisuals()
    if getgenv().Config.ESP then
        local amIMurderer = (playerRoles[player.Name] and playerRoles[player.Name].Role == "Murderer")
        for name, data in pairs(playerRoles) do
            if name == player.Name then continue end
            local targetPlayer = Players:FindFirstChild(name)
            if targetPlayer and targetPlayer.Character then
                local hl = targetPlayer.Character:FindFirstChild("RoleHighlight") or Instance.new("Highlight", targetPlayer.Character)
                hl.Name = "RoleHighlight"
                
                if data.Role == "Murderer" then
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.FillTransparency = 0.5
                elseif data.Role == "Sheriff" or data.Role == "Hero" then
                    hl.FillColor = Color3.fromRGB(0, 120, 255)
                    hl.FillTransparency = 0.5
                elseif amIMurderer and getgenv().Config.SubtleESP then
                    hl.FillTransparency = 1 
                    hl.OutlineColor = Color3.white
                    hl.OutlineTransparency = 0.6
                else
                    if not amIMurderer then hl:Destroy() end
                end
            end
        end
    else
        clearHighlights()
    end

    if getgenv().Config.GunESP then
        local gun = workspace:FindFirstChild("GunDrop")
        if gun then
            local handle = gun:FindFirstChild("Handle") or gun:FindFirstChildWhichIsA("BasePart")
            if handle and not handle:FindFirstChild("GunHighlight") then
                local hl = Instance.new("Highlight", handle)
                hl.Name = "GunHighlight"
                hl.FillColor = Color3.fromRGB(255, 215, 0)
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            end
        end
    end
end

--- ### 4. REMOTE LISTENERS ### ---
local GameplayRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay")

GameplayRemotes.RoundStart.OnClientEvent:Connect(function(_, roles) 
    playerRoles = roles 
    isInRound = true 
    collectedCoins = {}
end)

GameplayRemotes.RoundEndFade.OnClientEvent:Connect(function() 
    playerRoles = {} 
    isInRound = false 
    isHiding = false 
    clearHighlights() 
end)

GameplayRemotes.CoinCollected.OnClientEvent:Connect(function(_, cur, max) 
    collectedCount = tonumber(cur) or 0 
    currentMax = tonumber(max) or 50 
end)

--- ### 5. THE CORE ENGINE ### ---

RunService.Stepped:Connect(function()
    if getgenv().Config.Farm and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

local function getMurderer()
    for name, data in pairs(playerRoles) do
        if data.Role == "Murderer" and name ~= player.Name then
            local p = Players:FindFirstChild(name)
            if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then return p.Character.HumanoidRootPart end
        end
    end
    return nil
end

task.spawn(function()
    while true do
        character
