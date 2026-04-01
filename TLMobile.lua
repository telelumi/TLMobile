--[[
    ULTIMATE ANTI-FLING v5
    Client-side fling protection with force neutralization
]]

if getgenv().ANTIFLING_CLEANUP then
    getgenv().ANTIFLING_CLEANUP()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local lp = Players.LocalPlayer

local COLLISION_GROUP = "ANTIFLING"
local VELOCITY_LIMIT = 180
local connections = {}
local protectedChars = {}

pcall(function()
    PhysicsService:CreateCollisionGroup(COLLISION_GROUP)
    PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

local function killForces(part)
    if not part:IsA("BasePart") then return end
    part.Velocity = Vector3.new()
    part.RotVelocity = Vector3.new()
    for _, c in ipairs(part:GetChildren()) do
        if c:IsA("BodyForce") or c:IsA("BodyVelocity") or c:IsA("BodyAngularVelocity") or
           c:IsA("VectorForce") or c:IsA("BodyGyro") or c:IsA("LinearVelocity") or
           c:IsA("AngularVelocity") then
            c:Destroy()
        end
    end
end

local function protectPart(part)
    if not part:IsA("BasePart") then return end
    pcall(function()
        part.CanCollide = false
        PhysicsService:SetPartCollisionGroup(part, COLLISION_GROUP)
        part:SetNetworkOwner(lp)
        killForces(part)
    end)
end

local function protectCharacter(char)
    if protectedChars[char] then return end
    protectedChars[char] = true
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            protectPart(part)
        end
    end
    
    local addedConn = char.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            protectPart(desc)
        end
        if desc:IsA("BodyForce") or desc:IsA("BodyVelocity") or desc:IsA("VectorForce") then
            desc:Destroy()
        end
    end)
    table.insert(connections, addedConn)
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    end
end

local function monitorVelocity()
    for _, char in ipairs(protectedChars) do
        if char and char.Parent then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and root.Velocity.Magnitude > VELOCITY_LIMIT then
                killForces(root)
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        killForces(part)
                    end
                end
                if root.Position.Y < -50 then
                    root.CFrame = CFrame.new(0, 10, 0) + Vector3.new(math.random(-20,20), 0, math.random(-20,20))
                end
            end
        end
    end
end

if lp.Character then
    protectCharacter(lp.Character)
end

lp.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    protectCharacter(char)
end)

local heartbeat = RunService.Heartbeat:Connect(monitorVelocity)
table.insert(connections, heartbeat)

getgenv().ANTIFLING_CLEANUP = function()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    protectedChars = {}
end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Anti-Fling",
    Text = "Active | Velocity Limit: " .. VELOCITY_LIMIT,
    Duration = 3
})
