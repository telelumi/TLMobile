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

local LocalPlayer = Players.LocalPlayer

--==================================================
-- SETTINGS
--==================================================
local MAX_VEL = 85
local MAX_ANG = 45
local TELEPORT_DIST = 30
local ACCEL_TRIGGER = 500
local IMPULSE_MULT = 1.4
local COOLDOWN = 0.12

--==================================================
-- STATE
--==================================================
local connection
local lastSafeCF
local lastImpulse = 0
local history = {}

--==================================================
-- HISTORY SYSTEM
--==================================================
local function push(v)
    table.insert(history, {t = os.clock(), v = v})
    if #history > 6 then
        table.remove(history, 1)
    end
end

local function accel()
    if #history < 2 then return 0 end
    local a = history[#history]
    local b = history[#history - 1]
    local dt = a.t - b.t
    if dt <= 0 then return 0 end
    return (a.v - b.v) / dt
end

--==================================================
-- FIND ATTACKER (SMART DETECTION)
--==================================================
local function getClosestPlayer(pos)
    local closest, dist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - pos).Magnitude
            if d < dist then
                dist = d
                closest = plr
            end
        end
    end
    return closest
end

--==================================================
-- REFLECT FLING (CORE FEATURE)
--==================================================
local function reflectFling(hrp, velVec)
    local attacker = getClosestPlayer(hrp.Position)
    if not attacker then return end

    local aChar = attacker.Character
    local aHRP = aChar and aChar:FindFirstChild("HumanoidRootPart")
    if not aHRP then return end

    -- übertrage impulse zurück
    local power = velVec.Magnitude * IMPULSE_MULT

    aHRP:ApplyImpulse(velVec.Unit * power)
    aHRP.AssemblyAngularVelocity = Vector3.new(9e5,9e5,9e5)
end

--==================================================
-- CORE PROTECTION
--==================================================
local function protect(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local velVec = hrp.AssemblyLinearVelocity
    local angVec = hrp.AssemblyAngularVelocity

    local vel = velVec.Magnitude
    local ang = angVec.Magnitude

    push(vel)
    local a = accel()

    --==================================================
    -- ANTI TELEPORT (SKIDFLING COUNTER)
    --==================================================
    if lastSafeCF then
        if (hrp.Position - lastSafeCF.Position).Magnitude > TELEPORT_DIST then
            hrp.CFrame = lastSafeCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            return
        end
    end

    --==================================================
    -- REMOVE BODY MOVERS
    --==================================================
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end

    --==================================================
    -- LIMITS
    --==================================================
    if vel > MAX_VEL then
        hrp.AssemblyLinearVelocity = velVec.Unit * MAX_VEL
    end

    if ang > MAX_ANG then
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    --==================================================
    -- DETECT + REFLECT
    --==================================================
    if a > ACCEL_TRIGGER and vel > 70 then
        local now = os.clock()
        if now - lastImpulse > COOLDOWN then
            lastImpulse = now

            -- REFLECT INSTEAD OF TAKING DAMAGE
            reflectFling(hrp, velVec)

            -- STOP OWN MOVEMENT
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end

    --==================================================
    -- SAVE SAFE POSITION
    --==================================================
    if vel < 40 then
        lastSafeCF = hrp.CFrame
    end
end

--==================================================
-- NETWORK LOCK
--==================================================
local function netLock(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                v:SetNetworkOwner(LocalPlayer)
            end)
        end
    end
end

--==================================================
-- HUMANOID STABILIZE
--==================================================
local function stabilize(hum)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
end

--==================================================
-- MAIN
--==================================================
local function start(char)
    local hum = char:WaitForChild("Humanoid")

    history = {}
    lastSafeCF = nil
    lastImpulse = 0

    stabilize(hum)
    netLock(char)

    connection = RunService.Heartbeat:Connect(function()
        if not char.Parent then return end

        netLock(char)
        protect(char)
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
