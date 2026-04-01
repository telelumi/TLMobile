--==================================================
-- ULTIMATE ANTI-FLING v11 - VOID TRAP REFLECTION
-- Teleports attacker to void, returns you to safe position
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
local GROUP = "ANTIFLING_V11"

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
local lastSafePos = nil
local lastSafeCFrame = nil
local wasFlinging = false
local lastAttacker = nil
local attackHistory = {}
local reflectionCooldown = 0
local voidTeleportCooldown = 0
local originalWalkSpeed = 16
local frozen = false

-- Kill all forces
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

-- Save safe position (when not being flung and grounded)
local function saveSafePosition(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local isGrounded = hum:GetState() == Enum.HumanoidStateType.Landed or 
                       hum:GetState() == Enum.HumanoidStateType.Running or
                       hum:GetState() == Enum.HumanoidStateType.GettingUp
    
    if isGrounded and not wasFlinging and hrp.Position.Y > 3 then
        lastSafePos = hrp.Position
        lastSafeCFrame = hrp.CFrame
    end
end

-- Teleport attacker to void
local function sendAttackerToVoid(attacker)
    if not attacker or not attacker.Character then return false end
    
    local attackerHrp = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not attackerHrp then return false end
    
    pcall(function()
        -- Store attacker's original position (optional)
        local voidPos = Vector3.new(attackerHrp.Position.X, -500, attackerHrp.Position.Z)
        
        -- Teleport to void
        attackerHrp.CFrame = CFrame.new(voidPos)
        attackerHrp.AssemblyLinearVelocity = Vector3.new(0, -100, 0)
        attackerHrp.AssemblyAngularVelocity = Vector3.new()
        
        -- Kill all forces on attacker
        for _, part in ipairs(attacker.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.new()
                part.AssemblyLinearVelocity = Vector3.new()
            end
            if part:IsA("BodyVelocity") or part:IsA("BodyForce") then
                part:Destroy()
            end
        end
        
        -- Disable humanoid temporarily to ensure death
        local attackerHum = attacker.Character:FindFirstChildOfClass("Humanoid")
        if attackerHum then
            attackerHum.Health = 0
            attackerHum.PlatformStand = true
        end
    end)
    
    return true
end

-- Return player to safe position
local function returnToSafePosition(char)
    if not lastSafeCFrame then return false end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    pcall(function()
        -- Teleport back to safe position
        hrp.CFrame = lastSafeCFrame
        hrp.AssemblyLinearVelocity = Vector3.new()
        hrp.AssemblyAngularVelocity = Vector3.new()
        
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            hum.PlatformStand = false
        end
        
        -- Kill any remaining forces
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                killForces(part)
            end
        end
    end)
    
    return true
end

-- Anti-clipping
local function antiClip(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local pos = hrp.Position
    if pos.Y < 0 then
        if lastSafePos then
            hrp.CFrame = CFrame.new(lastSafePos)
        else
            hrp.CFrame = CFrame.new(pos.X, 5, pos.Z)
        end
        hrp.AssemblyLinearVelocity = Vector3.new()
    end
end

-- Detect Kilasik's BodyVelocity
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

-- Detect attacker
local function detectAttacker()
    local nearest = nil
    local nearestDist = 40
    
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
            
            -- Save safe position when not flinging
            if velMag < 30 and not hasKilasicForce then
                saveSafePosition(char)
            end
            
            local threshold = 85
            if flingCount > 1 then
                threshold = 65
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
                    
                    -- VOID TRAP: Send attacker to void and return to safe position
                    if lastAttacker and tick() - voidTeleportCooldown > 2 then
                        voidTeleportCooldown = tick()
                        
                        -- Send attacker to void
                        local success = sendAttackerToVoid(lastAttacker)
                        
                        if success then
                            -- Immediately return to safe position
                            returnToSafePosition(char)
                            
                            -- Force kill all velocities
                            hrp.AssemblyLinearVelocity = Vector3.new()
                            hrp.AssemblyAngularVelocity = Vector3.new()
                            killForces(hrp)
                            
                            -- Notify
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "Anti-Fling",
                                Text = "Attacker " .. lastAttacker.Name .. " sent to void!",
                                Duration = 2
                            })
                        end
                    end
                end
                
                -- Immediate force kill
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
                killForces(hrp)
                
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        killForces(part)
                    end
                end
                
                -- Remove Kilasik forces
                if hasKilasicForce then
                    for _, v in ipairs(hrp:GetChildren()) do
                        if v:IsA("BodyVelocity") then
                            v:Destroy()
                        end
                    end
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
                    flingCount = flingCount - 0.15
                end
            end
            
            -- Anti-clip
            antiClip(char)
            
            -- Prevent freeze
            if hum and hum.WalkSpeed < 1 and not frozen then
                frozen = true
                hum.WalkSpeed = 16
                task.wait(0.5)
                frozen = false
            end
        end
    end)
end

-- Monitor for new force objects
local function monitorPartAddition(char)
    if partMonitor then partMonitor:Disconnect() end
    
    partMonitor = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            protectPart(desc)
        end
        
        if desc:IsA("BodyVelocity") or desc:IsA("BodyForce") or desc:IsA("VectorForce") or
           desc:IsA("BodyAngularVelocity") or desc:IsA("LinearVelocity") then
            task.wait(0.01)
            pcall(function() desc:Destroy() end)
            flingCount = flingCount + 1
            
            local attacker = detectAttacker()
            if attacker and tick() - voidTeleportCooldown > 1.5 then
                voidTeleportCooldown = tick()
                sendAttackerToVoid(attacker)
                if lp.Character then
                    returnToSafePosition(lp.Character)
                end
            end
        end
        
        if desc:IsA("Attachment") or desc:IsA("Constraint") then
            pcall(function() desc:Destroy() end)
        end
    end)
end

-- Periodic safe position backup
local function startPeriodicBackup(char)
    task.spawn(function()
        while active and char and char.Parent do
            wait(0.5)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum then
                local isGrounded = hum:GetState() == Enum.HumanoidStateType.Landed or 
                                   hum:GetState() == Enum.HumanoidStateType.Running
                if isGrounded and hrp.Position.Y > 3 then
                    lastSafePos = hrp.Position
                    lastSafeCFrame = hrp.CFrame
                end
                
                if hrp.AssemblyLinearVelocity.Magnitude > 40 then
                    hrp.AssemblyLinearVelocity = Vector3.new()
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
    
    -- Initialize safe position
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Position.Y > 3 then
        lastSafePos = hrp.Position
        lastSafeCFrame = hrp.CFrame
    end
    
    protectChar(char)
    startForceScanner(char)
    monitorPartAddition(char)
    startPeriodicBackup(char)
    
    conn = RunService.Heartbeat:Connect(function()
        if not active then return end
        local currentChar = lp.Character
        if currentChar then
            protectChar(currentChar)
            antiClip(currentChar)
            
            local hrp = currentChar:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.AssemblyLinearVelocity.Magnitude > 70 then
                hrp.AssemblyLinearVelocity = Vector3.new()
                hrp.AssemblyAngularVelocity = Vector3.new()
            end
        end
    end)
end

-- Respawn handling
lp.CharacterAdded:Connect(function(char)
    wait(0.3)
    flingCount = 0
    wasFlinging = false
    lastAttacker = nil
    frozen = false
    
    -- Restore safe position after respawn if needed
    task.wait(0.5)
    if lastSafePos and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        if hrp.Position.Y < 10 then
            hrp.CFrame = lastSafeCFrame or CFrame.new(lastSafePos)
        end
    end
    
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
    Title = "Anti-Fling v11",
    Text = "Void Trap ACTIVE | Attacker = Instant Death",
    Duration = 3
})
