--[[
    ULTIMATE ANTI-FLING v3
    - Immune to high-velocity attacks, BodyVelocity, BodyForce, etc.
    - Auto-repairs character parts and resets velocities
    - Forced network ownership to client
    - Collision group isolation
    - Detects and neutralizes fling attempts instantly
]]

if getgenv().ULTIMATE_ANTI_FLING_CLEANUP then
    getgenv().ULTIMATE_ANTI_FLING_CLEANUP()
end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local COLLISION_GROUP = "ANTIFLING_NO_COLLIDE"
local VELOCITY_THRESHOLD = 150          -- if velocity exceeds this, it's a fling attempt
local REPAIR_DELAY = 0.2                -- time to wait after a fling before resetting

-- Ensure collision group exists
pcall(function()
    PhysicsService:CreateCollisionGroup(COLLISION_GROUP)
end)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

-- Reference to character and parts
local character = nil
local humanoid = nil
local rootPart = nil
local parts = {}
local isFlingProtected = false
local repairCoroutine = nil
local heartbeatConnection = nil
local descendantConnection = nil

-- Store original positions/velocities
local lastPosition = nil
local lastVelocity = Vector3.new()

-- =================================================
-- UTILITY FUNCTIONS
-- =================================================

-- Apply collision group and disable collisions
local function applyCollisionProtection(part)
    if part:IsA("BasePart") then
        pcall(function()
            part.CanCollide = false
            PhysicsService:SetPartCollisionGroup(part, COLLISION_GROUP)
        end)
    end
end

-- Strip all forces and velocity from a part
local function stripForces(part)
    if part:IsA("BasePart") then
        pcall(function()
            part.Velocity = Vector3.new()
            part.RotVelocity = Vector3.new()
        end)
    end
    for _, child in ipairs(part:GetDescendants()) do
        if child:IsA("BodyForce") or child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or
           child:IsA("VectorForce") or child:IsA("BodyGyro") or child:IsA("LinearVelocity") or
           child:IsA("AngularVelocity") then
            pcall(function() child:Destroy() end)
        end
    end
end

-- Reset character parts to a safe state
local function resetCharacter()
    if not character then return end
    for _, part in ipairs(parts) do
        if part and part.Parent then
            stripForces(part)
            applyCollisionProtection(part)
        end
    end
    if humanoid then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    if rootPart then
        lastVelocity = rootPart.Velocity
        lastPosition = rootPart.Position
    end
end

-- Force network ownership of all character parts to client
local function forceNetworkOwnership()
    if not character then return end
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") and part:GetNetworkOwner() ~= LocalPlayer then
            pcall(function()
                part:SetNetworkOwner(LocalPlayer)
            end)
        end
    end
end

-- Check if a part is being flung (excessive velocity)
local function isFlingAttempt(part)
    if part:IsA("BasePart") and part.Velocity.Magnitude > VELOCITY_THRESHOLD then
        return true
    end
    return false
end

-- Immediate reaction to fling: cancel velocity and forces
local function neutralizeFling(part)
    if part:IsA("BasePart") then
        part.Velocity = Vector3.new()
        part.RotVelocity = Vector3.new()
        stripForces(part)
        -- Optional: slight bounce to prevent sinking
        part:ApplyImpulse(Vector3.new(0, 5, 0))
    end
end

-- =================================================
-- FLING DETECTION & NEUTRALIZATION LOOP
-- =================================================
local function monitorFling()
    if not character then return end
    local anyFling = false
    for _, part in ipairs(parts) do
        if part and part.Parent and isFlingAttempt(part) then
            anyFling = true
            neutralizeFling(part)
        end
    end
    if anyFling then
        -- Force full reset
        resetCharacter()
        forceNetworkOwnership()
    end
end

-- =================================================
-- CHARACTER SETUP
-- =================================================
local function setupCharacter(char)
    character = char
    humanoid = char:FindFirstChildOfClass("Humanoid")
    rootPart = char:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then
        return
    end
    
    -- Gather all BaseParts
    parts = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end
    
    -- Apply initial protection
    resetCharacter()
    forceNetworkOwnership()
    
    -- Monitor newly added parts (accessories, etc.)
    if descendantConnection then
        descendantConnection:Disconnect()
    end
    descendantConnection = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            table.insert(parts, desc)
            applyCollisionProtection(desc)
            stripForces(desc)
            if desc:IsA("BasePart") and desc:GetNetworkOwner() ~= LocalPlayer then
                pcall(function() desc:SetNetworkOwner(LocalPlayer) end)
            end
        end
        if desc:IsA("BodyForce") or desc:IsA("BodyVelocity") then
            pcall(function() desc:Destroy() end)
        end
    end)
end

-- =================================================
-- MAIN LOOP
-- =================================================
local function startProtection()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if character and character.Parent then
            monitorFling()
            -- Additional: ensure collision group is always applied
            for _, part in ipairs(parts) do
                if part and part.Parent and part:IsA("BasePart") then
                    if part.CanCollide ~= false then
                        part.CanCollide = false
                    end
                    local group = pcall(function() return PhysicsService:GetPartCollisionGroup(part) end)
                    if group ~= COLLISION_GROUP then
                        pcall(function() PhysicsService:SetPartCollisionGroup(part, COLLISION_GROUP) end)
                    end
                end
            end
        end
    end)
end

-- =================================================
-- RESPAWN HANDLING
-- =================================================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.2)
    setupCharacter(newChar)
    startProtection()
end)

-- =================================================
-- INITIAL SETUP
-- =================================================
if LocalPlayer.Character then
    setupCharacter(LocalPlayer.Character)
end
startProtection()

-- =================================================
-- CLEANUP FUNCTION
-- =================================================
getgenv().ULTIMATE_ANTI_FLING_CLEANUP = function()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    if descendantConnection then
        descendantConnection:Disconnect()
    end
    if repairCoroutine then
        task.cancel(repairCoroutine)
    end
    -- Optional: reset collision groups
    pcall(function()
        PhysicsService:SetCollisionGroupCollidable(COLLISION_GROUP, COLLISION_GROUP, true)
    end)
end

-- =================================================
-- NOTIFICATION (optional)
-- =================================================
local function notify(msg)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Anti-Fling",
        Text = msg,
        Duration = 3
    })
end

-- Optional: display a brief message on load
task.spawn(function()
    wait(1)
    notify("Ultimate Anti-Fling Activated")
end)
