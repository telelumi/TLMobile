--==================================================
-- ULTIMATE ANTI-FLING v10 - COMPLETE IMMUNITY
-- Specifically designed to counter Kilasik Multi-Fling & all variants
--==================================================

if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local lp = Players.LocalPlayer
local GROUP = "ANTIFLING_V10"

pcall(function()
    PhysicsService:CreateCollisionGroup(GROUP)
    PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
    for _, group in ipairs(PhysicsService:GetCollisionGroups()) do
        if group.Name ~= GROUP and group.Name ~= "Default" then
            pcall(function() PhysicsService:CollisionGroupSetCollidable(GROUP, group.Name, false) end)
        end
    end
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
local lastAttacker = nil
local attackHistory = {}
local reflectionCooldown = 0
local positionLock = false
local lockTimer = 0
local originalWalkSpeed = 16
local frozen = false

-- Kill all forces (enhanced)
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
               v:IsA("AngularVelocity") or v:IsA("Attachment") or v:IsA("Constraint") or
               v:IsA("RopeConstraint") or v:IsA("SpringConstraint") then
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
        part.CanQuery = false
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
            hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.Sit = false
            if not frozen then
                hum.WalkSpeed = originalWalkSpeed
            end
        end)
    end
    
    forceOwnershipAll(char)
end

-- Anti-Kilasik specific: prevents the FPos function from working
local function antiKilasicPositionLock(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Kilasik uses RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
    -- We detect rapid CFrame changes and revert them
    if lastResetPos then
        local delta = (hrp.Position - lastResetPos).Magnitude
        if delta > 15 then
            hrp.CFrame = CFrame.new(lastResetPos)
            hrp.AssemblyLinearVelocity = Vector3.new()
            hrp.AssemblyAngularVelocity = Vector3.new()
            positionLock = true
            lockTimer = 0.5
        end
    end
    
    if positionLock then
        lockTimer = lockTimer - 0.016
        if lockTimer <= 0 then
            positionLock = false
        end
    end
end

-- Detect Kilasik's BodyVelocity injection
local function detectKilasicForce(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") and v.MaxForce == Vector3.new(9e9, 9e9, 9e9) then
            return true
        end
    end
    return false
end

-- Anti-freeze protection
local function preventFreeze(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if hum.WalkSpeed < 1 and not frozen then
        frozen = true
        hum.WalkSpeed = 16
        hum.JumpPower = 50
        task.wait(0.5)
        frozen = false
    end
end

-- Anti-clipping (prevents underground)
local function antiClip(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local pos = hrp.Position
    if pos.Y < 0 then
        hrp.CFrame = CFrame.new(pos.X, 5, pos.Z)
        hrp.AssemblyLinearVelocity = Vector3.new()
    end
    
    local rayOrigin = pos
    local rayDirection = Vector3.new(0, -6, 0)
    local ray = Ray.new(rayOrigin, rayDirection)
    local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, {char})
    
    if hit and hitPos and (pos.Y - hitPos.Y) < 1 then
        hrp.CFrame = CFrame.new(pos.X, hitPos.Y + 2.5, pos.Z)
    end
end

-- Reflect force back to attacker (enhanced for Kilasik)
local function reflectToAttacker(attacker, forceMagnitude)
    if not attacker or not attacker.Character then return end
    
    local attackerHrp = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not attackerHrp then return end
    
    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    local direction = (attackerHrp.Position - myHrp.Position).Unit
    local reflectForce = direction * math.min(forceMagnitude * 1.5, 400)
    
    pcall(function()
        attackerHrp.AssemblyLinearVelocity = reflectForce
        attackerHrp:ApplyImpulse(reflectForce * 15)
        
        local attackerHum = attacker.Character:FindFirstChildOfClass("Humanoid")
        if attackerHum then
            attackerHum.PlatformStand = true
            task.wait(0.15)
            attackerHum.PlatformStand = false
        end
        
        for _, v in ipairs(attacker.Character:GetDescendants()) do
            if v:IsA("BodyVelocity") or v:IsA("BodyForce") then
                v:Destroy()
            end
        end
    end)
end

-- Detect attacker (who is flinging you)
local function detectAttacker()
    local nearest = nil
    local nearestDist = 30
    
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

-- Main protection scanner
local function startForceScanner(char)
    if forceConn then forceConn:Disconnect() end
    
    forceConn = RunService.Heartbeat:Connect(function()
        if not active or not char or not char.Parent then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        forceOwnershipAll(char)
        
        if hrp then
            local velMag = hrp.AssemblyLinearVelocity.Magnitude
            local hasKilasicForce = detectKilasicForce(char)
            
            -- Adaptive threshold
            local threshold = 85
            if flingCount > 2 or hasKilasicForce then
                threshold = 60
            end
            
            -- Fling detection
            if velMag > threshold or hasKilasicForce then
                if not wasFlinging then
                    wasFlinging = true
                    flingCount = flingCount + 1
                    
                    local attacker = detectAttacker()
                    if attacker then
                        lastAttacker = attacker
                        table.insert(attackHistory, {attacker = attacker, time = tick()})
                        while #attackHistory > 10 do table.remove(attackHistory, 1) end
                    end
                end
                
                -- IMMEDIATE force kill
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
                killForces(hrp)
                
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        killForces(part)
                    end
                end
                
                -- Position lock
                if lastResetPos then
                    local delta = (hrp.Position - lastResetPos).Magnitude
                    if delta > 10 then
                        hrp.CFrame = CFrame.new(lastResetPos)
                    end
                else
                    lastResetPos = hrp.Position
                end
                
                -- Anti-Kilasik specific: remove BodyVelocity immediately
                if hasKilasicForce then
                    for _, v in ipairs(hrp:GetChildren()) do
                        if v:IsA("BodyVelocity") then
                            v:Destroy()
                        end
                    end
                end
                
                -- Reflect to attacker (with cooldown)
                if flingCount > 1 and lastAttacker and tick() - reflectionCooldown > 0.3 then
                    reflectionCooldown = tick()
                    reflectToAttacker(lastAttacker, velMag)
                end
                
                -- Anti-stun
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
                if now - lastCheck > 0.3 then
                    lastCheck = now
                end
            else
                wasFlinging = false
                if flingCount > 0 then
                    flingCount = flingCount - 0.2
                end
            end
            
            -- Anti-Kilasik position lock
            antiKilasicPositionLock(char)
            
            -- Anti-clip
            antiClip(char)
            
            -- Prevent freeze
            if hum then
                preventFreeze(char)
            end
            
            -- Update last position
            if not wasFlinging then
                lastResetPos = hrp.Position
            end
        end
    end)
end

-- Monitor for new force objects (Kilasic's BodyVelocity)
local function monitorPartAddition(char)
    if partMonitor then partMonitor:Disconnect() end
    
    partMonitor = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            protectPart(desc)
        end
        
        -- Kill Kilasik's BodyVelocity instantly
        if desc:IsA("BodyVelocity") or desc:IsA("BodyForce") or desc:IsA("VectorForce") or
           desc:IsA("BodyAngularVelocity") or desc:IsA("LinearVelocity") then
            task.wait(0.01)
            pcall(function() desc:Destroy() end)
            flingCount = flingCount + 1
            
            local attacker = detectAttacker()
            if attacker and tick() - reflectionCooldown > 0.2 then
                reflectionCooldown = tick()
                reflectToAttacker(attacker, 200)
            end
        end
        
        if desc:IsA("Attachment") or desc:IsA("Constraint") then
            pcall(function() desc:Destroy() end)
        end
    end)
end

-- Periodic reset (prevents accumulation)
local function startPeriodicReset(char)
    task.spawn(function()
        while active and char and char.Parent do
            wait(1)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hrp then
                if hrp.AssemblyLinearVelocity.Magnitude > 30 then
                    hrp.AssemblyLinearVelocity = Vector3.new()
                    hrp.AssemblyAngularVelocity = Vector3.new()
                end
                lastResetPos = hrp.Position
                antiClip(char)
            end
            
            if hum and hum.PlatformStand then
                hum.PlatformStand = false
            end
        end
    end)
end

-- Attacker punisher (continuous flingers)
local function startAttackerPunisher()
    task.spawn(function()
        while active do
            wait(1.5)
            if flingCount > 2 and lastAttacker and lastAttacker.Character then
                local attackerHrp = lastAttacker.Character:FindFirstChild("HumanoidRootPart")
                if attackerHrp then
                    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                    if myHrp then
                        local dir = (attackerHrp.Position - myHrp.Position).Unit
                        attackerHrp.AssemblyLinearVelocity = dir * 500
                        attackerHrp:ApplyImpulse(dir * 800)
                        
                        local attackerHum = lastAttacker.Character:FindFirstChildOfClass("Humanoid")
                        if attackerHum then
                            attackerHum.PlatformStand = true
                            task.wait(0.25)
                            attackerHum.PlatformStand = false
                        end
                        
                        for _, v in ipairs(lastAttacker.Character:GetDescendants()) do
                            if v:IsA("BodyVelocity") or v:IsA("BodyForce") then
                                v:Destroy()
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- Main start
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
                if hrp.AssemblyLinearVelocity.Magnitude > 70 then
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
    wasFlinging = false
    lastAttacker = nil
    positionLock = false
    frozen = false
    start()
end)

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

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Anti-Fling v10",
    Text = "Immunity | Reflection ON | Anti-Freeze",
    Duration = 3
})
