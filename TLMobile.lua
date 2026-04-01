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
-- SETTINGS (GEGEN SKIDFLING)
--==================================================
local MAX_VEL = 80
local MAX_ANG = 40
local TELEPORT_DISTANCE = 25
local IMPULSE_POWER = 1.3

--==================================================
-- STATE
--==================================================
local connection
local lastSafeCFrame
local lastVel = Vector3.zero
local lastTime = 0

--==================================================
-- CORE ANTI FLING
--==================================================
local function protect(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local currentVel = hrp.AssemblyLinearVelocity
    local currentAng = hrp.AssemblyAngularVelocity

    local speed = currentVel.Magnitude
    local ang = currentAng.Magnitude

    --==================================================
    -- ANTI TELEPORT (GENAU GEGEN SKIDFLING)
    --==================================================
    if lastSafeCFrame then
        local dist = (hrp.Position - lastSafeCFrame.Position).Magnitude
        if dist > TELEPORT_DISTANCE then
            hrp.CFrame = lastSafeCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            return
        end
    end

    --==================================================
    -- VELOCITY LIMIT
    --==================================================
    if speed > MAX_VEL then
        hrp.AssemblyLinearVelocity = currentVel.Unit * MAX_VEL
    end

    if ang > MAX_ANG then
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    --==================================================
    -- IMPULSE COUNTER (ANTI BODYVELOCITY / ROT)
    --==================================================
    if speed > 60 then
        local counter = -currentVel.Unit * (speed * IMPULSE_POWER)
        hrp:ApplyImpulse(counter)
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    --==================================================
    -- ANTI BODYVELOCITY DELETE
    --==================================================
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end

    --==================================================
    -- SAVE SAFE POSITION
    --==================================================
    if speed < 40 then
        lastSafeCFrame = hrp.CFrame
    end
end

--==================================================
-- HUMANOID PROTECTION
--==================================================
local function stabilize(hum)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
end

--==================================================
-- NETWORK LOCK (ANTI EXPLOIT CONTROL)
--==================================================
local function networkLock(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                v:SetNetworkOwner(LocalPlayer)
            end)
        end
    end
end

--==================================================
-- MAIN
--==================================================
local function start(char)
    local hum = char:WaitForChild("Humanoid")

    lastSafeCFrame = nil

    stabilize(hum)
    networkLock(char)

    connection = RunService.Heartbeat:Connect(function()
        if not char.Parent then return end

        networkLock(char) -- dauerhaft erzwingen
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
