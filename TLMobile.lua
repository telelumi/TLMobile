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
-- SETTINGS (TUNED)
--==================================================
local MAX_LINEAR = 120
local MAX_ANGULAR = 60
local HARD_CLAMP = 250

local IMPULSE_POWER = 1.15
local IMPULSE_COOLDOWN = 0.15

local HISTORY_SIZE = 6
local ACCEL_TRIGGER = 650

local COLLISION_GROUP = "AF_PROTECT"

--==================================================
-- STATE
--==================================================
local connection
local velocityHistory = {}
local lastImpulse = 0

--==================================================
-- COLLISION SYSTEM (ANTI PLAYER CONTACT)
--==================================================
pcall(function()
    PhysicsService:CreateCollisionGroup(COLLISION_GROUP)
end)

pcall(function()
    PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

local function applyNoCollision(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                v.CanCollide = false
                PhysicsService:SetPartCollisionGroup(v, COLLISION_GROUP)
            end)
        end
    end
end

--==================================================
-- VELOCITY ANALYSIS
--==================================================
local function pushHistory(v, a)
    table.insert(velocityHistory, {
        t = os.clock(),
        v = v,
        a = a
    })
    if #velocityHistory > HISTORY_SIZE then
        table.remove(velocityHistory, 1)
    end
end

local function getAcceleration()
    if #velocityHistory < 2 then return 0 end
    local a = velocityHistory[#velocityHistory]
    local b = velocityHistory[#velocityHistory - 1]

    local dt = a.t - b.t
    if dt <= 0 then return 0 end

    return (a.v - b.v) / dt
end

--==================================================
-- CORE PROTECTION
--==================================================
local function protect(hrp)
    local velVec = hrp.AssemblyLinearVelocity
    local angVec = hrp.AssemblyAngularVelocity

    local vel = velVec.Magnitude
    local ang = angVec.Magnitude

    pushHistory(vel, ang)
    local accel = getAcceleration()

    -- HARD LIMIT (EXTREME FLING)
    if vel > HARD_CLAMP then
        hrp.AssemblyLinearVelocity = velVec.Unit * MAX_LINEAR
        hrp.AssemblyAngularVelocity = Vector3.zero
        return
    end

    -- NORMAL LIMIT
    if vel > MAX_LINEAR then
        hrp.AssemblyLinearVelocity = velVec.Unit * MAX_LINEAR
    end

    if ang > MAX_ANGULAR then
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    -- ACCELERATION BASED DETECTION
    if accel > ACCEL_TRIGGER and vel > 90 then
        local now = os.clock()
        if now - lastImpulse > IMPULSE_COOLDOWN then
            lastImpulse = now

            local counter = -velVec.Unit * (vel * IMPULSE_POWER)
            hrp:ApplyImpulse(counter)

            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

--==================================================
-- NETWORK STABILIZER (ANTI EXPLOIT SYNC)
--==================================================
local function stabilize(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
    end
end

--==================================================
-- MAIN LOOP (MULTI LAYER PROTECTION)
--==================================================
local function start(char)
    local hrp = char:WaitForChild("HumanoidRootPart")

    velocityHistory = {}
    lastImpulse = 0

    applyNoCollision(char)
    stabilize(char)

    connection = RunService.Heartbeat:Connect(function()
        if not char.Parent then return end

        -- APPLY EVERY FRAME (ANTI BYPASS)
        applyNoCollision(char)

        protect(hrp)
    end)
end

--==================================================
-- PLAYER HANDLING
--==================================================
if LocalPlayer.Character then
    start(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    start(char)
end)

-- APPLY TO OTHERS (ANTI CONTACT FORCE)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            applyNoCollision(char)
        end)
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        applyNoCollision(char)
    end)
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
