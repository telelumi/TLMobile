--==================================================
-- CLEAN START
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

local LocalPlayer = Players.LocalPlayer

--==================================================
-- SETTINGS
--==================================================
local MAX_LINEAR = 90
local MAX_ANGULAR = 45
local HARD_LIMIT = 180

local ACCEL_TRIGGER = 500
local IMPULSE_POWER = 1.25
local COOLDOWN = 0.12

local GROUP = "AF_GHOST"

--==================================================
-- STATE
--==================================================
local connection
local velocityHistory = {}
local lastImpulse = 0

--==================================================
-- COLLISION GROUP (GHOST MODE)
--==================================================
pcall(function()
    PhysicsService:CreateCollisionGroup(GROUP)
end)

pcall(function()
    PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

--==================================================
-- ANTI TARGET SYSTEM (CORE)
-- verhindert Targeting durch Exploits
--==================================================
local function makeUntargetable(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                v.CanCollide = false
                v.Massless = true
                v.CanQuery = false
                v.CanTouch = false
                v:SetNetworkOwner(LocalPlayer)
                PhysicsService:SetPartCollisionGroup(v, GROUP)
            end)
        elseif v:IsA("Humanoid") then
            pcall(function()
                v.Name = "Humanoid_" .. math.random(1000,9999)
            end)
        end
    end
end

--==================================================
-- HISTORY
--==================================================
local function push(v)
    table.insert(velocityHistory, {
        t = os.clock(),
        v = v
    })
    if #velocityHistory > 6 then
        table.remove(velocityHistory, 1)
    end
end

local function accel()
    if #velocityHistory < 2 then return 0 end
    local a = velocityHistory[#velocityHistory]
    local b = velocityHistory[#velocityHistory - 1]
    local dt = a.t - b.t
    if dt <= 0 then return 0 end
    return (a.v - b.v) / dt
end

--==================================================
-- CORE ANTI FLING
--==================================================
local function protect(hrp)
    local velVec = hrp.AssemblyLinearVelocity
    local angVec = hrp.AssemblyAngularVelocity

    local vel = velVec.Magnitude
    local ang = angVec.Magnitude

    push(vel)
    local a = accel()

    -- HARD STOP
    if vel > HARD_LIMIT then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return
    end

    -- LIMITS
    if vel > MAX_LINEAR then
        hrp.AssemblyLinearVelocity = velVec.Unit * MAX_LINEAR
    end

    if ang > MAX_ANGULAR then
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    -- SMART IMPULSE
    if a > ACCEL_TRIGGER and vel > 70 then
        local now = os.clock()
        if now - lastImpulse > COOLDOWN then
            lastImpulse = now

            local counter = -velVec.Unit * (vel * IMPULSE_POWER)
            hrp:ApplyImpulse(counter)

            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

--==================================================
-- HUMANOID STABILIZER
--==================================================
local function stabilize(hum)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
end

--==================================================
-- MAIN
--==================================================
local function start(char)
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    velocityHistory = {}
    lastImpulse = 0

    if hum then
        stabilize(hum)
    end

    makeUntargetable(char)

    connection = RunService.Heartbeat:Connect(function()
        if not char.Parent then return end

        -- ANTI TARGET PER FRAME (ANTI BYPASS)
        makeUntargetable(char)

        protect(hrp)
    end)
end

--==================================================
-- INIT
--==================================================
if LocalPlayer.Character then
    start(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    start(char)
end)

--==================================================
-- CLEANUP
--==================================================
getgenv().AntiFling_Cleanup = function()
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
    end
end
