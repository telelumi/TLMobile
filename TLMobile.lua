--==================================================
-- ULTIMATE ANTI-FLING v6
-- Enhanced with prediction, force cancellation, and exploit pattern detection
--==================================================

if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

--==================================================
-- SERVICES
--==================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- SETTINGS (OPTIMIZED)
--==================================================
local CONFIG = {
    MAX_LINEAR = 85,           -- normal speed limit
    MAX_ANGULAR = 40,          -- spin limit
    HARD_LIMIT = 160,          -- absolute kill threshold
    ACCEL_TRIGGER = 450,       -- acceleration that triggers counter
    IMPULSE_POWER = 1.5,       -- counter force strength
    COOLDOWN = 0.08,           -- impulse cooldown
    HISTORY_SIZE = 8,          -- velocity history for prediction
    PREDICTION_FRAMES = 2,     -- frames ahead for prediction
    FORCE_SCAN_RATE = 0.05,    -- force object scan rate
}

local GROUP = "AF_GHOST_V2"

--==================================================
-- STATE
--==================================================
local connection = nil
local forceScanConnection = nil
local velocityHistory = {}
local positionHistory = {}
local lastImpulse = 0
local lastDamage = 0
local isProtected = false
local currentCharacter = nil

--==================================================
-- COLLISION GROUP SETUP
--==================================================
pcall(function()
    PhysicsService:CreateCollisionGroup(GROUP)
end)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
    for _, group in ipairs(PhysicsService:GetCollisionGroups()) do
        if group.Name ~= GROUP then
            pcall(function()
                PhysicsService:CollisionGroupSetCollidable(GROUP, group.Name, false)
            end)
        end
    end
end)

--==================================================
-- ADVANCED PREDICTION (detects fling before it happens)
--==================================================
local function predictVelocity()
    if #velocityHistory < 3 then return 0 end
    
    local velocities = {}
    for i = #velocityHistory - 2, #velocityHistory do
        table.insert(velocities, velocityHistory[i].v)
    end
    
    local avgVel = (velocities[1] + velocities[2] + velocities[3]) / 3
    local delta1 = velocities[2] - velocities[1]
    local delta2 = velocities[3] - velocities[2]
    local acceleration = (delta2 - delta1) / 2
    
    return avgVel + (acceleration * CONFIG.PREDICTION_FRAMES)
end

local function predictPosition(hrp)
    if #positionHistory < 2 then return hrp.Position end
    
    local last = positionHistory[#positionHistory]
    local secondLast = positionHistory[#positionHistory - 1]
    local vel = (last.pos - secondLast.pos) / last.dt
    
    return last.pos + vel * (CONFIG.PREDICTION_FRAMES / 60)
end

--==================================================
-- FORCE OBJECT SCANNER (removes hidden forces)
--==================================================
local function scanAndRemoveForces(part)
    if not part or not part.Parent then return end
    
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("BodyForce") or child:IsA("BodyVelocity") or 
           child:IsA("BodyAngularVelocity") or child:IsA("VectorForce") or
           child:IsA("BodyGyro") or child:IsA("LinearVelocity") or
           child:IsA("AngularVelocity") or child:IsA("Constraint") then
            pcall(function() 
                child:Destroy()
            end)
        end
    end
    
    for _, child in ipairs(part:GetDescendants()) do
        if child:IsA("BodyForce") or child:IsA("BodyVelocity") then
            pcall(function() child:Destroy() end)
        end
    end
end

--==================================================
-- NETWORK OWNERSHIP FORCE (prevents remote flings)
--==================================================
local function forceOwnership(part)
    if part:IsA("BasePart") and part:GetNetworkOwner() ~= LocalPlayer then
        pcall(function()
            part:SetNetworkOwner(LocalPlayer)
        end)
    end
end

--==================================================
-- ADVANCED PROTECTION CORE
--==================================================
local function protectPart(part, isRoot)
    if not part or not part:IsA("BasePart") then return end
    
    pcall(function()
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Massless = true
        part.Material = Enum.Material.Air
        
        if isRoot then
            part.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
        end
        
        PhysicsService:SetPartCollisionGroup(part, GROUP)
        forceOwnership(part)
        scanAndRemoveForces(part)
    end)
end

--==================================================
-- ANTI-TARGET & ANTI-TRACKING
--==================================================
local function makeUntargetable(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            protectPart(v, v.Name == "HumanoidRootPart")
        elseif v:IsA("Humanoid") then
            pcall(function()
                v.BreakJointsOnDeath = false
                v.Name = "Humanoid_" .. tostring(os.clock()):gsub("%.", "")
            end)
        end
    end
end

--==================================================
-- CORE ANTI FLING LOGIC (ENHANCED)
--==================================================
local function protect(hrp, hum)
    if not hrp or not hrp.Parent then return end
    
    local velVec = hrp.AssemblyLinearVelocity
    local angVec = hrp.AssemblyAngularVelocity
    local vel = velVec.Magnitude
    local ang = angVec.Magnitude
    
    -- Record history
    local now = os.clock()
    table.insert(velocityHistory, {t = now, v = vel})
    if #velocityHistory > CONFIG.HISTORY_SIZE then
        table.remove(velocityHistory, 1)
    end
    
    table.insert(positionHistory, {t = now, pos = hrp.Position, dt = 1/60})
    if #positionHistory > CONFIG.HISTORY_SIZE then
        table.remove(positionHistory, 1)
    end
    
    -- PREDICTION CHECK (preemptive)
    local predictedVel = predictVelocity()
    if predictedVel > CONFIG.HARD_LIMIT * 0.8 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if hum then hum.PlatformStand = true end
        return
    end
    
    -- HARD STOP
    if vel > CONFIG.HARD_LIMIT then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if hum then
            hum.PlatformStand = true
            task.wait(0.05)
            hum.PlatformStand = false
        end
        return
    end
    
    -- LINEAR LIMIT
    if vel > CONFIG.MAX_LINEAR then
        hrp.AssemblyLinearVelocity = velVec.Unit * CONFIG.MAX_LINEAR
    end
    
    -- ANGULAR LIMIT (anti-spin)
    if ang > CONFIG.MAX_ANGULAR then
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    
    -- ACCELERATION-BASED COUNTER
    if #velocityHistory >= 2 then
        local lastVel = velocityHistory[#velocityHistory - 1].v
        local accel = (vel - lastVel) / (now - velocityHistory[#velocityHistory - 1].t)
        
        if accel > CONFIG.ACCEL_TRIGGER and vel > 60 then
            local nowTime = os.clock()
            if nowTime - lastImpulse > CONFIG.COOLDOWN then
                lastImpulse = nowTime
                
                local counterForce = -velVec.Unit * (vel * CONFIG.IMPULSE_POWER)
                hrp:ApplyImpulse(counterForce)
                hrp.AssemblyAngularVelocity = Vector3.zero
                
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end
        end
    end
    
    -- POSITION CORRECTION (anti-teleport)
    if #positionHistory >= 2 then
        local predictedPos = predictPosition(hrp)
        local distance = (predictedPos - hrp.Position).Magnitude
        if distance > 50 then
            hrp.CFrame = CFrame.new(predictedPos) * CFrame.Angles(0, 0, 0)
        end
    end
end

--==================================================
-- HUMANOD STABILIZER (prevents ragdoll fling)
--==================================================
local function stabilizeHumanoid(hum)
    if not hum then return end
    
    pcall(function()
        hum.PlatformStand = false
        hum.AutoRotate = true
        hum.JumpPower = 50
        hum.WalkSpeed = 16
        hum.MaxSlopeAngle = 45
        
        for _, state in ipairs(Enum.HumanoidStateType:GetEnumItems()) do
            if state ~= Enum.HumanoidStateType.Dead and 
               state ~= Enum.HumanoidStateType.Ragdoll then
                hum:SetStateEnabled(state, true)
            end
        end
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
    end)
end

--==================================================
-- FORCE SCAN LOOP (removes injected forces)
--==================================================
local function startForceScan(char)
    if forceScanConnection then
        forceScanConnection:Disconnect()
    end
    
    forceScanConnection = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent then return end
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                scanAndRemoveForces(part)
                forceOwnership(part)
            end
        end
    end)
end

--==================================================
-- CHARACTER CONNECTION MONITOR (detects force injection)
--==================================================
local function monitorCharacterParts(char)
    local partAddedConn = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            protectPart(desc, desc.Name == "HumanoidRootPart")
        elseif desc:IsA("BodyForce") or desc:IsA("BodyVelocity") or desc:IsA("VectorForce") then
            task.wait(0.01)
            pcall(function() desc:Destroy() end)
        end
    end)
    return partAddedConn
end

--==================================================
-- MAIN PROTECTION LOOP
--==================================================
local function start(char)
    if connection then
        connection:Disconnect()
    end
    
    currentCharacter = char
    velocityHistory = {}
    positionHistory = {}
    lastImpulse = 0
    
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp then return end
    
    -- Apply all protections
    makeUntargetable(char)
    
    if hum then
        stabilizeHumanoid(hum)
    end
    
    -- Start force scanner
    startForceScan(char)
    
    -- Monitor part additions
    local partMonitor = monitorCharacterParts(char)
    
    -- Main velocity protection
    connection = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent then return end
        
        local currentHrp = char:FindFirstChild("HumanoidRootPart")
        local currentHum = char:FindFirstChildOfClass("Humanoid")
        
        if not currentHrp then return end
        
        -- Re-apply protection every frame (anti-bypass)
        makeUntargetable(char)
        
        -- Core protection
        protect(currentHrp, currentHum)
        
        -- Extra: if PlatformStand was set by exploit, fix it
        if currentHum and currentHum.PlatformStand and not flying then
            currentHum.PlatformStand = false
        end
    end)
    
    -- Store connections for cleanup
    if not char._antiflingConns then
        char._antiflingConns = {}
    end
    table.insert(char._antiflingConns, connection)
    table.insert(char._antiflingConns, partMonitor)
end

--==================================================
-- RESPAWN HANDLING
--==================================================
if LocalPlayer.Character then
    start(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    start(char)
end)

--==================================================
-- ANTI-KICK PREVENTION (optional)
--==================================================
local function preventKick()
    local oldKick = game:Kick
    game.Kick = function(...) end
    
    game:GetService("TeleportService").Teleport = function(...) return end
    
    task.wait(60)
    game.Kick = oldKick
end
task.spawn(preventKick)

--==================================================
-- CLEANUP
--==================================================
getgenv().AntiFling_Cleanup = function()
    if connection then
        pcall(function() connection:Disconnect() end)
        connection = nil
    end
    if forceScanConnection then
        pcall(function() forceScanConnection:Disconnect() end)
        forceScanConnection = nil
    end
    if currentCharacter and currentCharacter._antiflingConns then
        for _, conn in ipairs(currentCharacter._antiflingConns) do
            pcall(function() conn:Disconnect() end)
        end
        currentCharacter._antiflingConns = nil
    end
    velocityHistory = {}
    positionHistory = {}
end

--==================================================
-- NOTIFICATION
--==================================================
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Anti-Fling v6",
    Text = string.format("Active | Limits: %s/%s | Counter: %s",
        CONFIG.MAX_LINEAR, CONFIG.HARD_LIMIT, CONFIG.IMPULSE_POWER),
    Duration = 3
})
