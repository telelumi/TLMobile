-- ANTI-FLING + EXPLOIT-NEUTRALIZER
-- Kombiniert CollisionGroup, Velocity Clamp & BodyForce Filter

-- CLEANUP
if getgenv().ULTIMATE_ANTI_FLING_CLEANUP then
    getgenv().ULTIMATE_ANTI_FLING_CLEANUP()
end

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local LocalPlayer = Players.LocalPlayer
local COLLISION_GROUP = "ULTIMATE_NO_COLLIDE"

-- CREATE COLLISION GROUP
pcall(function()
    PhysicsService:CreateCollisionGroup(COLLISION_GROUP)
end)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

-- SET PART NO COLLIDE + GROUP
local function disableCollision(part)
    if part:IsA("BasePart") then
        pcall(function() part.CanCollide = false end)
        pcall(function() PhysicsService:SetPartCollisionGroup(part, COLLISION_GROUP) end)
    end
end

-- ZERO OUT VELOCITY
local function resetVelocity(part)
    if part:IsA("BasePart") then
        part.Velocity = Vector3.new()
        part.RotVelocity = Vector3.new()
    end
end

-- REMOVE BODYFORCE/BODYVELOCITY/VECTORFORCE
local function stripForces(obj)
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("BodyForce")
        or child:IsA("BodyVelocity")
        or child:IsA("BodyAngularVelocity")
        or child:IsA("VectorForce")
        or child:IsA("BodyGyro")
        or child:IsA("LinearVelocity")
        or child:IsA("AngularVelocity")
        then
            pcall(function() child:Destroy() end)
        end
    end
end

-- APPLY ANTI-FLING TO CHARACTER
local function applyAntiFling(character)
    for _, part in ipairs(character:GetDescendants()) do
        disableCollision(part)
        resetVelocity(part)
    end
    stripForces(character)
end

-- DETECT EXPLOITER FORCES (neutralisiert)
local function monitorForces(character)
    -- Überwacht neu hinzugefügte BodyForces
    character.DescendantAdded:Connect(function(desc)
        if desc:IsA("BodyForce")
        or desc:IsA("BodyVelocity")
        or desc:IsA("VectorForce")
        then
            task.wait(0.01)
            stripForces(character)
        end
    end)
end

-- FORCE TRANSFER (wenn jemand dich flingt)
local function forceTransfer(targetChar)
    if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
        local hrp = targetChar.HumanoidRootPart
        hrp.Velocity = LocalPlayer.Character.HumanoidRootPart.Velocity
        hrp.RotVelocity = LocalPlayer.Character.HumanoidRootPart.RotVelocity
    end
end

-- APPLY TO ALL PLAYERS
local function handlePlayer(plr)
    if plr.Character then
        applyAntiFling(plr.Character)
        monitorForces(plr.Character)
    end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        applyAntiFling(char)
        monitorForces(char)
    end)
end

-- HEARTBEAT LOOP (permanent enforce)
local heartbeatConn
heartbeatConn = RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            applyAntiFling(plr.Character)
        end
    end
end)

-- INITIAL SETUP
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        handlePlayer(plr)
    end
end

Players.PlayerAdded:Connect(handlePlayer)

if LocalPlayer.Character then
    applyAntiFling(LocalPlayer.Character)
    monitorForces(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    applyAntiFling(char)
    monitorForces(char)
end)

-- CLEANUP FUNCTION
getgenv().ULTIMATE_ANTI_FLING_CLEANUP = function()
    if heartbeatConn then
        pcall(function() heartbeatConn:Disconnect() end)
    end
end
