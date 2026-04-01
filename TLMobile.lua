--==================================================
-- ULTIMATE ANTI-FLING v9 - ADVANCED REFLECTION
-- Continuous fling blocking + force reflection to attacker
--==================================================

if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local GROUP = "ANTIFLING_V9"

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
local wasFlinging = false
local groundedTimer = 0
local lastAttacker = nil
local attackHistory = {}
local reflectionCooldown = 0

-- Advanced force killing
local function killForces(part)
    if not part or not part.Parent then return end
    pcall(function()
        part.Velocity = Vector3.new()
        part.RotVelocity = Vector3.new()
        part.AssemblyLinearVelocity = Vector3.new()
        part.AssemblyAngularVelocity = Vector3.new()
    end)
    
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
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            protectPart(part)
        end
    end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum.PlatformStand = false
            hum.AutoRotate = true
        end)
    end
    
    forceOwnershipAll(char)
end

local function isGrounded(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local rayOrigin = hrp.Position
    local rayDirection = Vector3.new(0, -5, 0)
    local ray = Ray.new(rayOrigin, rayDirection)
    local hit = workspace:FindPartOnRay(ray, char)
    
    return hit ~= nil
end

-- Detect who is flinging you
local function detectAttacker()
    local nearest = nil
    local nearestDist = 20
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and lp.Character then
                local myHrp = lp.Character:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    local dist = (hrp.Position - myHrp.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = plr
                    end
                end
            end
        end
    end
    
    return nearest
end

-- Reflect force back to attacker
local function reflectToAttacker(attacker, forceMagnitude)
    if not attacker or not attacker.Character then return end
    
    local attackerHrp = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not attackerHrp then return end
    
    local myHrp = lp.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    local direction = (attackerHrp.Position - myHrp.Position).Unit
    local reflectForce = direction * math.min(forceMagnitude * 1.2, 250)
    
    pcall(function()
        attackerHrp.AssemblyLinearVelocity = reflectForce
        attackerHrp:ApplyImpulse(reflectForce * 10)
        
        local attackerHum = attacker.Character:FindFirstChildOfClass("Humanoid")
        if attackerHum then
            attackerHum.PlatformStand = true
            task.wait(0.1)
            attackerHum.PlatformStand = false
        end
    end)
end

-- Anti-clipping (prevents being pushed underground)
local function antiClip(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local pos = hrp.Position
    local rayOrigin = pos
    local rayDirection = Vector3.new(0, -8, 0)
    local ray = Ray.new(rayOrigin, rayDirection)
    local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, {char})
    
    if hit and hitPos then
        local groundLevel = hitPos.Y
        if pos.Y - groundLevel < 1.5 then
            hrp.CFrame = CFrame.new(pos.X, groundLevel + 2.5, pos.Z)
            hrp.AssemblyLinearVelocity = Vector3.new()
        end
    end
    
    if pos.Y < 0 then
        hrp.CFrame = CFrame.new(pos.X, 5, pos.Z)
        hrp.AssemblyLinearVelocity = Vector3.new()
    end
end

-- Position anchoring during fling spikes
local function anchorDuringFling(hrp, isFlinging)
    if isFlinging then
        pcall(function()
            hrp.Anchored = true
            task.wait(0.02)
            hrp.Anchored = false
        end)
    end
end

local function startForceScanner(char)
    if forceConn then forceConn:Disconnect() end
    
    forceConn = RunService.Heartbeat:Connect(function()
        if not active or not char or not char.Parent then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        forceOwnershipAll(char)
        
        if hrp then
            local velMag = hrp.AssemblyLinearVelocity.Magnitude
            local grounded = isGrounded(char)
            
            if grounded then
                groundedTimer = math.min(groundedTimer + 0.016, 1)
            else
                groundedTimer = math.max(groundedTimer - 0.016, 0)
            end
            
            local threshold = 90
            if flingCount > 2 then
                threshold = 70
            end
            
            -- Fling detection with attacker tracking
            if velMag > threshold then
                if not wasFlinging then
                    wasFlinging = true
                    flingCount = flingCount + 1
                    
                    -- Detect and record attacker
                    local attacker = detectAttacker()
                    if attacker then
                        lastAttacker = attacker
                        table.insert(attackHistory, {attacker = attacker, time = tick()})
                        while #attackHistory > 10 do table.remove(attackHistory, 1) end
                    end
                end
                
                -- Aggressive counter
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
                killForces(hrp)
                
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        killForces(part)
                    end
                end
                
                -- Position lock with smoothing
                local currentPos = hrp.Position
                if lastResetPos then
                    local delta = (currentPos - lastResetPos).Magnitude
                    if delta > 12 then
                        hrp.CFrame = CFrame.new(lastResetPos)
                    end
                else
                    lastResetPos = currentPos
                end
                
                -- Micro-anchor to prevent teleport clipping
                anchorDuringFling(hrp, true)
                
                -- Reflect force to attacker (if persistent fling)
                if flingCount > 2 and lastAttacker and tick() - reflectionCooldown > 0.5 then
                    reflectionCooldown = tick()
                    reflectToAttacker(lastAttacker, velMag)
                end
                
                -- Anti-stun: force getting up
                if hum then
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                    if hum.PlatformStand then
                        hum.PlatformStand = false
                    end
                end
                
                local now = tick()
                if now - lastCheck > 0.5 then
                    lastCheck = now
                end
            else
                wasFlinging = false
                if flingCount > 0 then
                    flingCount = flingCount - 0.25
                end
            end
            
            -- Anti-clipping (prevents underground glitch)
            antiClip(char)
            
            -- Position anchor (teleport prevention)
            if lastResetPos and (hrp.Position - lastResetPos).Magnitude > 20 then
                hrp.CFrame = CFrame.new(lastResetPos)
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
            task.wait(0.01)
            pcall(function() desc:Destroy() end)
            flingCount = flingCount + 1
            
            -- If force object added, reflect to attacker
            local attacker = detectAttacker()
            if attacker and tick() - reflectionCooldown > 0.3 then
                reflectionCooldown = tick()
                reflectToAttacker(attacker, 150)
            end
        end
        if desc:IsA("Attachment") or desc:IsA("Constraint") then
            pcall(function() desc:Destroy() end)
        end
    end)
end

local function startPeriodicReset(char)
    task.spawn(function()
        while active and char and char.Parent do
            wait(1.2)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                if hrp.AssemblyLinearVelocity.Magnitude > 35 then
                    hrp.AssemblyLinearVelocity = Vector3.new()
                    hrp.AssemblyAngularVelocity = Vector3.new()
                end
                lastResetPos = hrp.Position
                antiClip(char)
            end
        end
    end)
end

-- Periodic attacker punisher (for persistent flingers)
local function startAttackerPunisher()
    task.spawn(function()
        while active do
            wait(2)
            if flingCount > 3 and lastAttacker and lastAttacker.Character then
                local attackerHrp = lastAttacker.Character:FindFirstChild("HumanoidRootPart")
                if attackerHrp then
                    -- Strong reflection
                    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                    if myHrp then
                        local dir = (attackerHrp.Position - myHrp.Position).Unit
                        attackerHrp.AssemblyLinearVelocity = dir * 300
                        attackerHrp:ApplyImpulse(dir * 500)
                        
                        local attackerHum = lastAttacker.Character:FindFirstChildOfClass("Humanoid")
                        if attackerHum then
                            attackerHum.PlatformStand = true
                            task.wait(0.2)
                            attackerHum.PlatformStand = false
                        end
                    end
                end
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
    startAttackerPunisher()
    
    conn = RunService.Heartbeat:Connect(function()
        if not active then return end
        local currentChar = lp.Character
        if currentChar then
            protectChar(currentChar)
            antiClip(currentChar)
            
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp then
                if hrp.AssemblyLinearVelocity.Magnitude > 80 then
                    hrp.AssemblyLinearVelocity = Vector3.new()
                    hrp.AssemblyAngularVelocity = Vector3.new()
                end
            end
        end
    end)
end

lp.CharacterAdded:Connect(function(char)
    wait(0.3)
    flingCount = 0
    lastResetPos = nil
    wasFlinging = false
    lastAttacker = nil
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
    Text = "Active | Reflection ON | Anti-Clip",
    Duration = 3
})
