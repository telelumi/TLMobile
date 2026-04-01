-- ============================================
-- PLAYER COLLISION DISABLE (ANTI-FLING)
-- ============================================

local NO_COLLIDE_GROUP = "NoPlayerCollide"

pcall(function()
    PhysicsService:CreateCollisionGroup(NO_COLLIDE_GROUP)
end)

pcall(function()
    PhysicsService:CollisionGroupSetCollidable(NO_COLLIDE_GROUP, NO_COLLIDE_GROUP, false)
end)

-- erkennt Player Parts
local function isCharacterPart(part)
    return part:IsA("BasePart") and part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
end

-- setzt komplette Character Collision aus
local function applyNoCollision(char)
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            pcall(function()
                PhysicsService:SetPartCollisionGroup(v, NO_COLLIDE_GROUP)
            end)
        end
    end
end

-- andere Spieler ebenfalls in gleiche Gruppe setzen (wichtig!)
local function applyOthers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            applyNoCollision(plr.Character)
        end
    end
end

-- dynamisches Nachladen (neue Spieler / Respawn)
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(1)
        applyNoCollision(char)
    end)
end)

-- eigener Charakter
local function setupNoCollision(char)
    applyNoCollision(char)
    applyOthers()
end

if LocalPlayer.Character then
    setupNoCollision(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(setupNoCollision)
