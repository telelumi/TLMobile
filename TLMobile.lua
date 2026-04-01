--==================================================
-- ULTIMATE ANTI-FLING v7 - WORKING
-- Simple, effective, tested logic
--==================================================

if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local lp = Players.LocalPlayer
local GROUP = "ANTIFLING"

pcall(function()
    PhysicsService:CreateCollisionGroup(GROUP)
    PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

local active = true
local conn = nil

local function killForces(part)
    if not part then return end
    pcall(function()
        part.Velocity = Vector3.new()
        part.RotVelocity = Vector3.new()
    end)
    for _, v in ipairs(part:GetChildren()) do
        if v:IsA("BodyForce") or v:IsA("BodyVelocity") or v:IsA("BodyAngularVelocity") or
           v:IsA("VectorForce") or v:IsA("BodyGyro") then
            pcall(function() v:Destroy() end)
        end
    end
end

local function protectPart(part)
    if not part:IsA("BasePart") then return end
    pcall(function()
        part.CanCollide = false
        PhysicsService:SetPartCollisionGroup(part, GROUP)
        part:SetNetworkOwner(lp)
        killForces(part)
    end)
end

local function protectChar(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            protectPart(part)
        end
    end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum.PlatformStand = false
        end)
    end
    
    if char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp:SetNetworkOwner(lp)
    end
end

local function antiFlingLoop(char)
    if not char or not char.Parent then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local vel = hrp.AssemblyLinearVelocity
    local velMag = vel.Magnitude
    
    if velMag > 120 then
        hrp.AssemblyLinearVelocity = vel.Unit * 85
        hrp.AssemblyAngularVelocity = Vector3.new()
        killForces(hrp)
    end
    
    if velMag > 200 then
        hrp.AssemblyLinearVelocity = Vector3.new()
        hrp.AssemblyAngularVelocity = Vector3.new()
        killForces(hrp)
        
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.PlatformStand then
            hum.PlatformStand = false
        end
    end
    
    if hrp.Position.Y < -30 then
        hrp.CFrame = CFrame.new(0, 50, 0)
        hrp.AssemblyLinearVelocity = Vector3.new()
    end
end

local function start()
    if conn then conn:Disconnect() end
    
    local char = lp.Character
    if not char then return end
    
    protectChar(char)
    
    conn = RunService.Heartbeat:Connect(function()
        if not active then return end
        local currentChar = lp.Character
        if currentChar then
            protectChar(currentChar)
            antiFlingLoop(currentChar)
        end
    end)
end

lp.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    start()
end)

if lp.Character then
    start()
end

getgenv().AntiFling_Cleanup = function()
    active = false
    if conn then
        conn:Disconnect()
        conn = nil
    end
end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Anti-Fling",
    Text = "ACTIVE | Speed Limit: 120",
    Duration = 2
})
