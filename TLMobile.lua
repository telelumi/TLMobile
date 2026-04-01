--==================================================
-- ULTIMATE ANTI-FLING v8 - PERSISTENT DEFENSE
-- Handles continuous fling attacks with adaptive force cancellation
--==================================================

if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local GROUP = "ANTIFLING_V8"

pcall(function()
    PhysicsService:CreateCollisionGroup(GROUP)
    PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

-- Persistent state
local active = true
local conn = nil
local forceConn = nil
local partMonitor = nil
local lastCheck = 0
local flingCount = 0
local lastResetPos = nil
local resetCooldown = 0

-- Advanced force killing
local function killForces(part)
    if not part or not part.Parent then return end
    pcall(function()
        part.Velocity = Vector3.new()
        part.RotVelocity = Vector3.new()
        part.AssemblyLinearVelocity = Vector3.new()
        part.AssemblyAngularVelocity = Vector3.new()
    end)
    
    -- Kill ALL force objects recursively
    local function scan(obj)
        for _, v in ipairs(obj:GetChildren()) do
            if v:IsA("BodyForce") or v:IsA("BodyVelocity") or v:IsA("BodyAngularVelocity") or
               v:IsA("VectorForce") or v:IsA("BodyGyro") or v:IsA("LinearVelocity") or
               v:IsA("AngularVelocity") or v:IsA("Attachment") or v:IsA("Constraint") then
                pcall(function() v:Destroy() end)
            end
            if #v:GetChildren() > 0 then
                scan(v)
            end
        end
    end
    scan(part)
end

local function protectPart(part)
    if not part:IsA("BasePart") then return end
    pcall(function()
        part.CanCollide = false
        part.CanTouch = false
        part.Massless = true
        PhysicsService:SetPartCollisionGroup(part, GROUP)
        part:SetNetworkOwner(lp)
        killForces(part)
    end)
end

local function forceOwnershipAll(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part:SetNetworkOwner(lp) end)
        end
    end
end

local function protectChar(char)
    if not char then return end
    
    -- Full part protection
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            protectPart(part)
        end
    end
    
    -- Humanoid lockdown
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum.PlatformStand = false
            hum.AutoRotate = true
        end)
    end
    
    forceOwnershipAll(char)
end

-- Continuous force scanner (runs every frame)
local function startForceScanner(char)
    if forceConn then forceConn:Disconnect() end
    
    forceConn = RunService.Heartbeat:Connect(function()
        if not active or not char or not char.Parent then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        -- Persistent ownership
        forceOwnershipAll(char)
        
        if hrp then
            local velMag = hrp.AssemblyLinearVelocity.Magnitude
            
            -- Adaptive threshold - if fling detected multiple times, lower threshold
            local threshold = 100
            if flingCount > 3 then
                threshold = 70
            end
            
            -- Continuous fling detection
            if velMag > threshold then
                flingCount = flingCount + 1
                
                -- Aggressive counter
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
                killForces(hrp)
                
                -- Kill forces on ALL parts
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        killForces(part)
                    end
                end
                
                -- Position lock (prevents being moved)
                local currentPos = hrp.Position
                if lastResetPos then
                    local delta = (currentPos - lastResetPos).Magnitude
                    if delta > 20 then
                        hrp.CFrame = CFrame.new(lastResetPos)
                    end
                else
                    lastResetPos = currentPos
                end
                
                -- Platform stand prevents external movement
                if hum and not hum.PlatformStand then
                    hum.PlatformStand = true
                    task.wait(0.05)
                    hum.PlatformStand = false
                end
                
                -- Anti-stun: force getting up
                if hum and hum:GetState() == Enum.HumanoidStateType.Ragdoll then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
                
                -- Reset cooldown to prevent spam
                local now = tick()
                if now - lastCheck > 0.5 then
                    lastCheck = now
                end
            else
                -- Gradually reduce fling count when not being flung
                if flingCount > 0 then
                    flingCount = flingCount - 0.5
                end
            end
            
            -- Position anchor (teleport prevention)
            if lastResetPos and (hrp.Position - lastResetPos).Magnitude > 30 then
                hrp.CFrame = CFrame.new(lastResetPos)
                hrp.AssemblyLinearVelocity = Vector3.new()
            end
        end
    end)
end

-- Monitor for new force objects being added
local function monitorPartAddition(char)
    if partMonitor then partMonitor:Disconnect() end
    
    partMonitor = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            protectPart(desc)
        end
        if desc:IsA("BodyForce") or desc:IsA("BodyVelocity") or desc:IsA("VectorForce") or
           desc:IsA("BodyAngularVelocity") or desc:IsA("LinearVelocity") then
            task.wait(0.01)
            pcall(function() desc:Destroy() end)
            flingCount = flingCount + 1
        end
        if desc:IsA("Attachment") or desc:IsA("Constraint") then
            pcall(function() desc:Destroy() end)
        end
    end)
end

-- Periodic reset (prevents persistent fling accumulation)
local function startPeriodicReset(char)
    task.spawn(function()
        while active and char and char.Parent do
            wait(2)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Force reset velocity every 2 seconds to prevent buildup
                if hrp.AssemblyLinearVelocity.Magnitude > 30 then
                    hrp.AssemblyLinearVelocity = Vector3.new()
                    hrp.AssemblyAngularVelocity = Vector3.new()
                end
                -- Update last position for teleport detection
                lastResetPos = hrp.Position
            end
        end
    end)
end

-- Main start function
local function start()
    if conn then conn:Disconnect() end
    if forceConn then forceConn:Disconnect() end
    if partMonitor then partMonitor:Disconnect() end
    
    local char = lp.Character
    if not char then return end
    
    wait(0.2) -- Wait for character to stabilize
    
    protectChar(char)
    startForceScanner(char)
    monitorPartAddition(char)
    startPeriodicReset(char)
    
    -- Continuous protection heartbeat
    conn = RunService.Heartbeat:Connect(function()
        if not active then return end
        local currentChar = lp.Character
        if currentChar then
            protectChar(currentChar)
            
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Emergency stop for any velocity above safe limit
                if hrp.AssemblyLinearVelocity.Magnitude > 80 then
                    hrp.AssemblyLinearVelocity = Vector3.new()
                    hrp.AssemblyAngularVelocity = Vector3.new()
                end
            end
        end
    end)
end

-- Respawn handling
lp.CharacterAdded:Connect(function(char)
    wait(0.3)
    flingCount = 0
    lastResetPos = nil
    start()
end)

-- Initial start
if lp.Character then
    start()
end

-- Cleanup
getgenv().AntiFling_Cleanup = function()
    active = false
    if conn then conn:Disconnect() end
    if forceConn then forceConn:Disconnect() end
    if partMonitor then partMonitor:Disconnect() end
    conn = nil
    forceConn = nil
    partMonitor = nil
end

-- Notification
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Anti-Fling v8",
    Text = "Persistent Defense ACTIVE | Adaptive Counter",
    Duration = 3
})
