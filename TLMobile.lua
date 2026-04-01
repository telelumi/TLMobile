--==================================================
-- ULTIMATE ANTI-FLING v9 - FINAL
-- No push, no auto-jump, pure stability
--==================================================

if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local lp = Players.LocalPlayer

local GROUP = "ANTIFLING_FINAL"

pcall(function()
    PhysicsService:CreateCollisionGroup(GROUP)
    PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

local active = true
local conn = nil
local forceConn = nil
local partMonitor = nil
local anchored = false
local anchorPart = nil

local function killAllForces(part)
    if not part or not part.Parent then return end
    pcall(function()
        part.Velocity = Vector3.new()
        part.RotVelocity = Vector3.new()
        part.AssemblyLinearVelocity = Vector3.new()
        part.AssemblyAngularVelocity = Vector3.new()
    end)
    
    for _, v in ipairs(part:GetChildren()) do
        if v:IsA("BodyForce") or v:IsA("BodyVelocity") or v:IsA("BodyAngularVelocity") or
           v:IsA("VectorForce") or v:IsA("BodyGyro") or v:IsA("LinearVelocity") or
           v:IsA("AngularVelocity") or v:IsA("Attachment") then
            pcall(function() v:Destroy() end)
        end
    end
end

local function protectPart(part)
    if not part:IsA("BasePart") then return end
    pcall(function()
        part.CanCollide = false
        part.CanTouch = false
        PhysicsService:SetPartCollisionGroup(part, GROUP)
        part:SetNetworkOwner(lp)
        killAllForces(part)
    end)
end

local function forceOwnershipAll(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part:SetNetworkOwner(lp) end)
        end
    end
end

local function lockRootPart(hrp)
    if not hrp then return end
    if not anchored then
        anchored = true
        pcall(function()
            hrp.Anchored = true
        end)
        task.wait(0.05)
        pcall(function()
            hrp.Anchored = false
        end)
        anchored = false
    end
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
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.Sit = false
        end)
    end
    
    forceOwnershipAll(char)
end

local function startForceScanner(char)
    if forceConn then forceConn:Disconnect() end
    
    forceConn = RunService.Heartbeat:Connect(function()
        if not active or not char or not char.Parent then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        forceOwnershipAll(char)
        
        if hrp then
            local vel = hrp.AssemblyLinearVelocity
            local velMag = vel.Magnitude
            
            -- Threshold
            if velMag > 85 then
                -- Kill ALL velocity
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
                killAllForces(hrp)
                
                -- Kill forces on all parts
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        killAllForces(part)
                    end
                end
                
                -- Micro-anchor (prevents push without jumping)
                if velMag > 120 then
                    pcall(function()
                        hrp.Anchored = true
                        task.wait(0.03)
                        hrp.Anchored = false
                    end)
                end
                
                -- Prevent jumping (force grounded)
                if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
                    hum:ChangeState(Enum.HumanoidStateType.Landed)
                end
                
                -- Anti-ragdoll
                if hum and hum:GetState() == Enum.HumanoidStateType.Ragdoll then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end
            
            -- Teleport detection (position clamp)
            if hrp.Position.Y < 0 then
                local currentPos = hrp.Position
                hrp.CFrame = CFrame.new(currentPos.X, 5, currentPos.Z)
                hrp.AssemblyLinearVelocity = Vector3.new()
            end
        end
    end)
end

local function monitorPartAddition(char)
    if partMonitor then partMonitor:Disconnect() end
    
    partMonitor = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            protectPart(desc)
        end
        if desc:IsA("BodyForce") or desc:IsA("BodyVelocity") or desc:IsA("VectorForce") or
           desc:IsA("BodyAngularVelocity") or desc:IsA("LinearVelocity") then
            pcall(function() desc:Destroy() end)
        end
        if desc:IsA("Attachment") then
            pcall(function() desc:Destroy() end)
        end
    end)
end

local function startPeriodicReset(char)
    task.spawn(function()
        while active and char and char.Parent do
            wait(1.5)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.AssemblyLinearVelocity.Magnitude > 40 then
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
            end
        end
    end)
end

local function start()
    if conn then conn:Disconnect() end
    if forceConn then forceConn:Disconnect() end
    if partMonitor then partMonitor:Disconnect() end
    
    local char = lp.Character
    if not char then return end
    
    wait(0.2)
    
    protectChar(char)
    startForceScanner(char)
    monitorPartAddition(char)
    startPeriodicReset(char)
    
    conn = RunService.Heartbeat:Connect(function()
        if not active then return end
        local currentChar = lp.Character
        if currentChar then
            protectChar(currentChar)
            
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.AssemblyLinearVelocity.Magnitude > 75 then
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
            end
        end
    end)
end

lp.CharacterAdded:Connect(function(char)
    wait(0.3)
    start()
end)

if lp.Character then
    start()
end

getgenv().AntiFling_Cleanup = function()
    active = false
    if conn then conn:Disconnect() end
    if forceConn then forceConn:Disconnect() end
    if partMonitor then partMonitor:Disconnect() end
    conn = nil
    forceConn = nil
    partMonitor = nil
end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Anti-Fling v9",
    Text = "Stable | No Push | No Auto-Jump",
    Duration = 3
})
