-- CLEANUP (ganz oben)
if getgenv().AntiFling_Cleanup then
    getgenv().AntiFling_Cleanup()
end

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ============================================
-- EIGENES MOVEMENT ERKENNUNG
-- ============================================
local function isMovementFromSelf()
    return _G.IS_MY_EXPLOIT_MOVEMENT == true
end

-- ============================================
-- IMPULS-BASIERTE FLING-ABWEHR (KEIN TELEPORT)
-- ============================================

-- Einstellungen
local MAX_VELOCITY = 180
local MAX_ANGULAR = 80
local IMPULSE_STRENGTH = 0.85  -- Gegenimpuls-Stärke
local VELOCITY_HISTORY_SIZE = 5

-- Geschwindigkeits-Historie
local velocityHistory = {}
local lastImpulseTime = 0
local IMPULSE_COOLDOWN = 0.3

-- Physik-Gruppe für temporäre Isolierung
local FLING_GROUP = "FlingProtection"
pcall(function()
    PhysicsService:CreateCollisionGroup(FLING_GROUP)
    PhysicsService:CollisionGroupSetCollidable(FLING_GROUP, FLING_GROUP, false)
end)

-- Funktion zum Berechnen des Gegenimpulses
local function calculateCounterImpulse(currentVel, currentDir)
    -- Gegenrichtung mit reduzierter Stärke
    local counterDir = -currentDir
    local impulseStrength = math.min(currentVel * IMPULSE_STRENGTH, 250)
    return counterDir * impulseStrength
end

-- Verbesserte Fling-Erkennung mit Impuls-Analyse
local function detectFling(hrp, currentVel, currentAng, deltaTime)
    local character = hrp.Parent
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    
    -- Eigene Bewegung ignorieren
    if isMovementFromSelf() then
        return false
    end
    
    -- Geschwindigkeits-Historie aktualisieren
    table.insert(velocityHistory, {
        time = os.clock(),
        vel = currentVel,
        ang = currentAng,
        pos = hrp.Position
    })
    
    while #velocityHistory > VELOCITY_HISTORY_SIZE do
        table.remove(velocityHistory, 1)
    end
    
    -- Impuls-basierte Erkennung (plötzliche Beschleunigung)
    if #velocityHistory >= 2 then
        local prev = velocityHistory[#velocityHistory - 1]
        local curr = velocityHistory[#velocityHistory]
        
        local deltaVel = curr.vel - prev.vel
        local deltaTimeActual = curr.time - prev.time
        
        if deltaTimeActual > 0 then
            local acceleration = deltaVel / deltaTimeActual
            
            -- Unnatürliche Beschleunigung > 800 units/s²
            if acceleration > 800 and curr.vel > 120 then
                return true, acceleration
            end
        end
    end
    
    -- Extremwerte erkennen
    if currentVel > 300 or currentAng > 150 then
        return true, 0
    end
    
    -- Boden-Check mit Toleranz
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        if currentVel < 140 then
            return false, 0
        end
    end
    
    -- Fall-Check
    if hum and hum:GetState() == Enum.HumanoidStateType.FallingDown then
        if currentVel < 130 then
            return false, 0
        end
    end
    
    return false, 0
end

-- Impuls-basierte Gegenmaßnahme (kein Teleport)
local function applyCounterImpulse(hrp, currentVel, currentDir, acceleration)
    local now = os.clock()
    if now - lastImpulseTime < IMPULSE_COOLDOWN then
        return false
    end
    
    -- Gegenimpuls berechnen
    local counterImpulse = calculateCounterImpulse(currentVel, currentDir)
    
    -- Zusätzliche Dämpfung bei extremer Beschleunigung
    if acceleration > 1200 then
        counterImpulse = counterImpulse * 1.2
    end
    
    -- Impuls anwenden (kein CFrame-Teleport!)
    hrp:ApplyImpulse(counterImpulse)
    
    -- Rotation stoppen
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    lastImpulseTime = now
    
    -- Kurze Kollisions-Isolierung
    pcall(function()
        PhysicsService:SetPartCollisionGroup(hrp, FLING_GROUP)
        task.delay(0.2, function()
            if hrp and hrp.Parent then
                pcall(function()
                    PhysicsService:SetPartCollisionGroup(hrp, "Default")
                end)
            end
        end)
    end)
    
    return true
end

-- SOUND
local function playSound(id)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume = 1.5
    s.PlayOnRemove = true
    s.Parent = SoundService
    s:Destroy()
end

-- NOTIFICATION
task.wait(1)
playSound("117945572498547")

game:GetService("StarterGui"):SetCore("SendNotification", { 
    Title = "Anti-Fling v2";
    Text = "Impuls-basierte Abwehr aktiv";
    Icon = "rbxassetid://80783156310584";
    Duration = 3;
})

getgenv().AntiSystem_Connection = nil
getgenv().AntiFling_Cleanup = nil

local function setupCharacter(char)
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    -- Variablen zurücksetzen
    velocityHistory = {}
    lastImpulseTime = 0
    
    -- Letzte stabile Geschwindigkeit speichern
    local lastStableVel = Vector3.zero
    local lastStableTime = 0
    
    getgenv().AntiSystem_Connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not hrp or not hrp.Parent then
            return
        end
        
        -- Eigene Bewegung ignorieren
        if isMovementFromSelf() then
            return
        end
        
        local currentVelVector = hrp.AssemblyLinearVelocity
        local currentVel = currentVelVector.Magnitude
        local currentAng = hrp.AssemblyAngularVelocity.Magnitude
        local currentDir = currentVelVector.Unit
        
        -- Fling erkennen
        local isFling, acceleration = detectFling(hrp, currentVel, currentAng, deltaTime)
        
        if isFling then
            -- Gegenimpuls anwenden (KEIN TELEPORT)
            local applied = applyCounterImpulse(hrp, currentVel, currentDir, acceleration)
            
            -- Bei Erfolg: Kurze Vibration als Feedback
            if applied and hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
                task.delay(0.15, function()
                    if hum then
                        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
                    end
                end)
            end
        else
            -- Stabile Geschwindigkeit speichern
            if currentVel < 50 then
                lastStableVel = currentVelVector
                lastStableTime = os.clock()
            end
        end
    end)
    
    -- Humanoid-Optimierung (Ragdoll verhindern, Fallen erlauben)
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        
        -- Fallgeschwindigkeit begrenzen
        local originalGetState = hum.GetState
        if not hum._flingProtected then
            hum._flingProtected = true
        end
    end
end

-- START
if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(setupCharacter)

-- CLEANUP
getgenv().AntiFling_Cleanup = function()
    if getgenv().AntiSystem_Connection then
        pcall(function()
            getgenv().AntiSystem_Connection:Disconnect()
        end)
        getgenv().AntiSystem_Connection = nil
    end
    
    -- Collision Group cleanup
    pcall(function()
        PhysicsService:SetCollisionGroupSettings(FLING_GROUP, {})
    end)
end
