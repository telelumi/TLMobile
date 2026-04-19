local _T = (type(task) == "table" and task) or {}
if not _T.wait  then _T.wait  = function(t) return wait(t or 0) end end
if not _T.spawn then _T.spawn = function(f, ...) return (spawn or function(fn, ...) local c = coroutine.create(fn); coroutine.resume(c, ...); return c end)(f, ...) end end
if not _T.delay then _T.delay = function(t, f, ...) return (delay or function(tm, fn) _T.spawn(function() wait(tm); fn() end) end)(t, f, ...) end end
if not _T.defer then _T.defer = function(f, ...) return (spawn or _T.spawn)(f, ...) end end
local task = _T

-- -- TLCACHE System ---------------------------------------------
local TLCACHE_DIR = "TLCACHE"
local _TLCACHE = {}
local function _initCache()
if makefolder then pcall(function() makefolder(TLCACHE_DIR) end) end
end
local function _saveCache(key, data)
if not writefile then return end
pcall(function()
writefile(TLCACHE_DIR.."/"..key..".json", game:GetService("HttpService"):JSONEncode(data))
end)
end
local function _loadCache(key)
if not readfile then return nil end
local ok, data = pcall(function()
return game:GetService("HttpService"):JSONDecode(readfile(TLCACHE_DIR.."/"..key..".json"))
end)
if ok then return data else return nil end
end
_initCache()

local _mfloor  = math.floor
local _mceil   = math.ceil
local _mabs    = math.abs
local _mclamp  = math.clamp
local _mmin    = math.min
local _mmax    = math.max
local _mrandom = math.random
local _msqrt   = math.sqrt
local _mrad    = math.rad
local _mdeg    = math.deg
local _mcos    = math.cos
local _msin    = math.sin
if not getgenv then
getgenv = function() return _G end
end
-- -- Cached services (avoids repeated GetService hash-lookup overhead) --
local _SvcUIS  = game:GetService("UserInputService")
local _SvcRS   = game:GetService("RunService")
local _SvcPlr  = game:GetService("Players")
local _SvcSG   = game:GetService("StarterGui")
local _SvcSnd  = game:GetService("SoundService")
local _SvcDeb  = game:GetService("Debris")
local _SvcCP   = game:GetService("ContentProvider")
local _SvcCG   = nil
pcall(function() _SvcCG = game:GetService("CoreGui") end)
if not _SvcCG then
    -- Fallback: Try PlayerGui for executors that don't support CoreGui access
    pcall(function()
        _SvcCG = LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
end

local _SvcVIM   = game:GetService("VirtualInputManager")
local _SvcStats = game:GetService("Stats")

local function _makeDummyStroke(p)
    local s = Instance.new("UIStroke")
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Thickness = 1.5
    s.Transparency = 0.5
    s.Parent = p
    -- Force bold, matte look even if script tries to make it a thin outline
    pcall(function()
        s:GetPropertyChangedSignal("Thickness"):Connect(function()
            if s.Thickness ~= 1.5 then s.Thickness = 1.5 end
        end)
        s:GetPropertyChangedSignal("Transparency"):Connect(function()
            if s.Transparency ~= 0.5 then s.Transparency = 0.5 end
        end)
    end)
    return s
end

-- -- Asset Preloader (Ultra Instinct Warm-up) ---------------------
task.spawn(function()
    local assets = {
        "rbxassetid://139800881181209", -- Hover Sound
        "rbxassetid://77458828386203",  -- QA Icon
        "rbxassetid://72579312094126",  -- Action Icons
        "rbxassetid://86857269527024",
        "rbxassetid://139840976938907",
        "rbxassetid://113740413795794",
        "rbxassetid://89009236995193",
        "rbxassetid://77104113506431",
        "rbxassetid://119518980113353",
        "rbxassetid://135716031985311",
        "rbxassetid://79735988088948"
    }
    local preloadList = {}
    for _, id in ipairs(assets) do
        local s = Instance.new("Sound")
        s.SoundId = id
        table.insert(preloadList, s)
    end
    pcall(function() _SvcCP:PreloadAsync(preloadList) end)
    for _, obj in ipairs(preloadList) do obj:Destroy() end
end)
-- -- Cached getgenv table (avoid 75+ function call overhead) --
local _genv    = (getgenv and getgenv()) or _G
if not writefile then
writefile = function() end
end
if not readfile then
readfile = function() return nil end
end
if not isfile then
isfile = function() return false end
end
-- ----------------------------------------------------------------
--  PERFORMANCE OPTIMISATIONS
-- * Localized math.*/Vector3/CFrame at file top
-- * _getTI nested-table cache (no string concat per tween)
-- * twP(): create+play in one call
-- * _tlAlive() caches env table
-- * BB loop: AssemblyLinearVelocity + AssemblyAngularVelocity reset every frame (pre-branch, zero alloc)
-- * Ghost/BB/Invis loops: conditional property writes
-- * Fly loop: cached cam CFrame
-- * Orbit: _workspace, guard CameraType, localized math
-- * FPS widget: no pcall, cached color
-- * Ping: cached Stats service
-- * Shimmer: *0.25, index loops, reuse Vector2
-- * Circle segments: cached XYZ, localized math
-- * Noclip/RushNoclip: early exit
-- * CFrame.Angles constants cached (_CF_ROT180Y, _CF_SUCK_ROT)
-- * Vector3.zero → _V3_ZERO in velocity resets
-- * ESP acc → _espAcc (global leak fixed)
-- * tick() → os.clock()
-- ----------------------------------------------------------------

local function _AF_loadAndPlayAnimation(humanoid, ANIMATION_ID)
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator", humanoid)
    end
    local cleanId = tostring(ANIMATION_ID or ""):gsub("rbxassetid://", "")
    if cleanId == "" or cleanId == "0" then return nil end
    local resolvedId = "rbxassetid://" .. cleanId
    pcall(function()
        local objects = game:GetObjects("rbxassetid://" .. cleanId)
        if objects and objects[1] then
            local obj = objects[1]
            if obj:IsA("Animation") then
                resolvedId = obj.AnimationId
            else
                local child = obj:FindFirstChildOfClass("Animation")
                if child then resolvedId = child.AnimationId end
            end
            obj.Parent = workspace
            task.delay(1, function() pcall(function() obj:Destroy() end) end)
        end
    end)
    local anim = Instance.new("Animation")
    anim.AnimationId = resolvedId
    local track = nil
    pcall(function()
        track = animator:LoadAnimation(anim)
    end)
    if not track then return nil end
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = true
    return track
end

local function _AF_prepareActionTrack(track)
    if not track or type(track) ~= "userdata" then return nil end
    pcall(function()
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = true
        track:AdjustSpeed(1)
        if not track.IsPlaying then
            track:Play(0.05, 1, 1)
        end
    end)
    return track
end

local function _AF_getReliableActionTrack(humanoid, animationId, emoteName)
    if not humanoid then return nil end
    local rawId = tostring(animationId or "")
    if rawId == "" or rawId == "0" then return nil end
    local track = nil
    pcall(function()
        track = _AF_loadAndPlayAnimation(humanoid, rawId)
        if track then
            track:Play(0.05, 1, 1)
        end
    end)
    track = _AF_prepareActionTrack(track)
    if not track then return nil end
    for _ = 1, 3 do
        local ok, isPlaying = pcall(function() return track.IsPlaying end)
        if ok and isPlaying then
            return track
        end
        pcall(function() track:Play(0.05, 1, 1) end)
        task.wait()
    end
    return track
end


if not getgenv()._TLScriptSource then
pcall(function()
if readfile and isfile and isfile(FILE) then
local s = readfile(FILE)
if s and #s > 500 then _genv._TLScriptSource = s end
end
end)
end
if not getgenv()._TLAutoReinject then
_genv._TLAutoReinject = true
task.spawn(function()
local lastJob = tostring(game.JobId)
while true do
task.wait(2.0)
local ok, newJob = pcall(function() return tostring(game.JobId) end)
if not ok then newJob = lastJob end
local changed = (newJob ~= lastJob) and (newJob ~= "") and (lastJob ~= "")
if changed then
lastJob = newJob
task.wait(3.5)
pcall(function()
if not game:IsLoaded() then game.Loaded:Wait() end
end)
task.wait(0.8)
local src
pcall(function()
if readfile and isfile and isfile(FILE) then
src = readfile(FILE)
end
end)
if not src or #(src or "") < 500 then
src = _genv._TLScriptSource
end
if src and #src > 500 then
local fn = loadstring(src)
if fn then task.spawn(fn) end
end
task.wait(5)
end
end
end)
end
if getgenv then
_genv._TLSessionToken = (_genv._TLSessionToken or 0) + 1
end
if not getgenv and _G then
_G._TLSessionToken = (_G._TLSessionToken or 0) + 1
end
local _MY_TOKEN = (getgenv and getgenv()._TLSessionToken)
or (_G and _G._TLSessionToken)
or 1
local _tlEnv = (getgenv ~= nil and _genv) or _G or {}
local function _tlAlive()
    return (_tlEnv._TLSessionToken == nil) or (_tlEnv._TLSessionToken == _MY_TOKEN)
end
pcall(function()
local env = getgenv and getgenv() or _G
if env and type(env.TLMenuCleanup) == "function" then
pcall(env.TLMenuCleanup)
elseif env and type(env.TLUnload) == "function" then
pcall(env.TLUnload)
end
end)
_G.EmotesGUIRunning = nil
if getgenv then
_genv._TLAllConns = {}
_genv._TLAllInsts = {}
end
local function _tlTrackConn(c)
pcall(function()
local env = getgenv and getgenv() or _G
if env and env._TLAllConns then
env._TLAllConns[#env._TLAllConns + 1] = c
end
end)
return c
end
local function _tlTrackInst(obj)
pcall(function()
local env = getgenv and getgenv() or _G
if env and env._TLAllInsts then
env._TLAllInsts[#env._TLAllInsts + 1] = obj
end
end)
return obj
end
pcall(function()
if getgenv then _genv.SmartBarLoaded = true end
end)
local _workspace = workspace or game:GetService("Workspace")
local PIGGYBACK_ANIM_ID, PIGGYBACK2_ANIM_ID = "108744973494490", "112201741232797"
-- Gecachte Konstanten
local _V3_ZERO     = Vector3.zero
local _CF_ROT180Y  = CFrame.Angles(0, math.rad(180), 0)
local _CF_SUCK_ROT = CFrame.Angles(0, math.rad(180), 0)
task.spawn(function()
local _MY_TOKEN = getgenv and getgenv()._TLSessionToken or 1
local function _tlAlive()
if getgenv ~= nil then return _genv._TLSessionToken == _MY_TOKEN end
return true
end
-- Always clear stale flag on re-execute; only skip if same session already running
_G.EmotesGUIRunning = nil
if not _tlAlive() then return end
_G.EmotesGUIRunning = true
local AnimHttpService; pcall(function() AnimHttpService = game:GetService("HttpService") end)
if not AnimHttpService then AnimHttpService = {JSONDecode=function(_,s) return {} end, JSONEncode=function(_,t) return "{}" end} end
local AnimRunService; pcall(function() AnimRunService = _SvcRS end)
if not AnimRunService then AnimRunService = {Heartbeat={Connect=function(_,f) return {Disconnect=function()end} end}, Stepped={Connect=function(_,f) return {Disconnect=function()end} end}} end
local AnimPlayers; pcall(function() AnimPlayers = _SvcPlr end)
if not AnimPlayers then AnimPlayers = _SvcPlr end
local AnimUIS; pcall(function() AnimUIS = _SvcUIS end)
if not AnimUIS then AnimUIS = {KeyboardEnabled=false, InputBegan={Connect=function(_,f) return {Disconnect=function()end} end}, InputChanged={Connect=function(_,f) return {Disconnect=function()end} end}} end
local AnimCoreGui; pcall(function() AnimCoreGui = game:GetService("CoreGui") end)
if not AnimCoreGui then
AnimCoreGui = setmetatable({}, {
__index = function() return nil end
})
end
local animPlayer = AnimPlayers.LocalPlayer
local animCharacter = animPlayer.Character
if not animCharacter then
local _acc, _conn, _done = 0, nil, false
_conn = animPlayer.CharacterAdded:Connect(function(c)
animCharacter = c; _done = true
pcall(function() _conn:Disconnect() end)
end)
while not _done and _acc < 8 do task.wait(0.1); _acc = _acc + 0.1 end
pcall(function() _conn:Disconnect() end)
if not animCharacter then animCharacter = animPlayer.Character end
end
local animHumanoid = nil
if animCharacter then
pcall(function() animHumanoid = animCharacter:WaitForChild("Humanoid", 5) end)
if not animHumanoid then animHumanoid = animCharacter:FindFirstChildOfClass("Humanoid") end
end
function animNotif(title, text, dur)
pcall(function()
if getgenv and getgenv().TLSendNotif then
_genv.TLSendNotif(title, text, dur or 3)
end
end)
end
local currentMode, currentPage, totalPages, itemsPerPage = "emote", 1, 1, 8
local isLoading = false -- used by search guards
local isLoadingEmotes, isLoadingAnimations = false, false
local emotesData, originalEmotesData, filteredEmotes = {}, {}, {}
local totalEmotesLoaded, favoriteEmotes = 0, {}
local favoriteFileName, emoteSearchTerm = "FavoriteEmotes.json", ""
local animationsData, originalAnimationsData, filteredAnimations = {}, {}, {}
local favoriteAnimations         = {}
local favoriteAnimationsFileName = "FavoriteAnimations.json"
local animationSearchTerm        = ""
local favoriteEnabled, favOnlyEnabled, emotesWalkEnabled = false, false, false
local speedEmoteEnabled, currentEmoteTrack, isGUICreated, speedEmoteConfigFile = false, nil, false, "SpeedEmoteConfig.json"
local Under, UIListLayout, _1left, _9right, _4pages, _3TextLabel, _2Routenumber
local Top, EmoteWalkButton, Search, Favorite, FavOnlyBtn, SpeedEmote, SpeedBox, Changepage, Reload
local UICorner, UICorner1, UICorner2, UIListLayout_2, UICorner_2, UICorner_4, UICorner_5, UICorner_6
local defaultButtonImage = "rbxassetid://71408678974152"
local enabledButtonImage, favoriteIconId, notFavoriteIconId = "rbxassetid://106798555684020", "rbxassetid://97307461910825", "rbxassetid://124025954365505"
local _normalListCache = nil
local _emoteNameCache  = nil
local function _getNormalList()
if _normalListCache then return _normalListCache end
local src = currentMode == "animation" and filteredAnimations or filteredEmotes
local t = {}
for _, item in ipairs(src) do
if not isInFavorites(item.id) then t[#t+1] = item end
end
_normalListCache = t
return t
end
function invalidatePagesCache() _pagesCache = nil; _normalListCache = nil end
local _clickConns, _clickCooldown, COOLDOWN = {}, {}, 0.1
local _btnConns = {}  -- persistent button connections (Mode, Nav, Search?); only cleared on GUI rebuild
local _frontButtonsCache = nil
local _pagesCache = nil
function _safeDisconnect(c)
pcall(c.Disconnect, c)
end
function _disconnectAll()
for i = 1, #_clickConns do
if _clickConns[i] then _safeDisconnect(_clickConns[i]) end
end
_clickConns = {}
end
function _disconnectBtns()
for i = 1, #_btnConns do
if _btnConns[i] then _safeDisconnect(_btnConns[i]) end
end
_btnConns = {}
end
function getAnimCharAndHumanoid()
local ch = animPlayer.Character; if not ch then return nil, nil end
return ch, ch:FindFirstChild("Humanoid")
end
function checkEmotesMenuExists()
local ok, ew = pcall(function()
return AnimCoreGui.RobloxGui.EmotesMenu.Children.Main.EmotesWheel
end)
return ok and ew or false, ok and ew or nil
end
function invalidateFrontButtonsCache() _frontButtonsCache = nil end
function getFrontButtons()
if _frontButtonsCache then return _frontButtonsCache end
local ok, fb = pcall(function()
return AnimCoreGui.RobloxGui.EmotesMenu.Children.Main.EmotesWheel.Front.EmotesButtons
end)
if not ok or not fb then return {} end
local list = {}
for _, c in ipairs(fb:GetChildren()) do
if c:IsA("ImageLabel") then list[#list+1] = c end
end
_frontButtonsCache = list
return list
end
function urlToId(id)
id = id:gsub("http://www%.roblox%.com/asset/%?id=", "")
id = id:gsub("rbxassetid://", "")
return id
end
function getEmoteName(assetId)
local ok, info = pcall(function()
return game:GetService("MarketplaceService"):GetProductInfo(tonumber(assetId))
end)
return (ok and info) and info.Name or ("Emote_" .. tostring(assetId))
end
function saveFavorites()
if writefile then writefile(favoriteFileName, AnimHttpService:JSONEncode(favoriteEmotes)) end
end
function saveFavoritesAnimations()
if writefile then writefile(favoriteAnimationsFileName, AnimHttpService:JSONEncode(favoriteAnimations)) end
end
function loadFavorites()
if readfile and isfile and isfile(favoriteFileName) then
local ok, r = pcall(function() return AnimHttpService:JSONDecode(readfile(favoriteFileName)) end)
if ok and r then
for _, f in ipairs(r) do f.id = tonumber(f.id) or f.id end
favoriteEmotes = r
end
end
end
function loadFavoritesAnimations()
if readfile and isfile and isfile(favoriteAnimationsFileName) then
local ok, r = pcall(function() return AnimHttpService:JSONDecode(readfile(favoriteAnimationsFileName)) end)
if ok and r then
for _, f in ipairs(r) do f.id = tonumber(f.id) or f.id end
favoriteAnimations = r
end
end
end
function loadSpeedEmoteConfig()
speedEmoteEnabled = false
emotesWalkEnabled = false
favoriteEnabled   = false
if readfile and isfile and isfile(speedEmoteConfigFile) then
local ok, r = pcall(function() return AnimHttpService:JSONDecode(readfile(speedEmoteConfigFile)) end)
if ok and r and SpeedBox then
SpeedBox.Text    = tostring(r.SpeedValue or 1)
SpeedBox.Visible = false
end
end
end
local _favSetEmote, _favSetAnim = {}, {}
function rebuildFavSet()
_favSetEmote = {}
for _, f in ipairs(favoriteEmotes) do _favSetEmote[tostring(f.id)] = true end
_favSetAnim  = {}
for _, f in ipairs(favoriteAnimations) do _favSetAnim[tostring(f.id)] = true end
invalidatePagesCache()
end
function isInFavorites(assetId)
local key = tostring(assetId)
if currentMode == "animation" then return _favSetAnim[key] == true
else return _favSetEmote[key] == true end
end
function getActiveFavs()
if currentMode == "animation" then
if favOnlyEnabled then return favoriteAnimations end
return _G.filteredFavoritesAnimationsForDisplay or favoriteAnimations
else
if favOnlyEnabled then return favoriteEmotes end
return _G.filteredFavoritesForDisplay or favoriteEmotes
end
end
function calculateTotalPages()
if _pagesCache then return _pagesCache end
local favs = getActiveFavs()
if favOnlyEnabled then
_pagesCache = math.max(#favs > 0 and math.ceil(#favs / itemsPerPage) or 1, 1)
return _pagesCache
end
local favPg = #favs > 0 and math.ceil(#favs / itemsPerPage) or 0
local normal = _getNormalList()
local normPg = #normal > 0 and math.ceil(#normal / itemsPerPage) or 0
_pagesCache = math.max(favPg + normPg, 1)
return _pagesCache
end
function getPageItems(page)
local items = {}
local favs   = getActiveFavs()
if favOnlyEnabled then
if #favs == 0 then return items end
local si = (page-1)*itemsPerPage + 1
local ei = math.min(si + itemsPerPage - 1, #favs)
for i = si, ei do if favs[i] then items[#items+1] = favs[i] end end
return items
end
local favPgs = #favs > 0 and math.ceil(#favs / itemsPerPage) or 0
if page <= favPgs and #favs > 0 then
local si = (page-1)*itemsPerPage + 1
local ei = math.min(si + itemsPerPage - 1, #favs)
for i = si, ei do if favs[i] then items[#items+1] = favs[i] end end
else
local normal = _getNormalList()
local adj = page - favPgs
local si  = (adj-1)*itemsPerPage + 1
local ei  = math.min(si + itemsPerPage - 1, #normal)
for i = si, ei do if normal[i] then items[#items+1] = normal[i] end end
end
return items
end
local _guiColorsDirty = true
function markGUIDirty() _guiColorsDirty = true end
local function updateGUIColors()
if not _guiColorsDirty then return end
_guiColorsDirty = false
if Under then Under.BackgroundColor3 = Color3.fromRGB(230,230,230); Under.BackgroundTransparency = 0.1 end
if Top   then Top.BackgroundColor3   = Color3.fromRGB(18,18,18);   Top.BackgroundTransparency   = 0.15 end
if _4pages       then _4pages.TextColor3       = Color3.fromRGB(0,0,0); _4pages.TextTransparency       = 0 end
if _3TextLabel   then _3TextLabel.TextColor3   = Color3.fromRGB(0,0,0); _3TextLabel.TextTransparency   = 0 end
if _2Routenumber then _2Routenumber.TextColor3 = Color3.fromRGB(0,0,0); _2Routenumber.TextTransparency = 0 end
if Reload then
local vis = (currentMode == "animation")
Reload.Visible = vis
if Reload.Parent then Reload.Parent.Visible = vis end
end
end
local function setFavoriteIcon(btn, isFav)
local icon = btn:FindFirstChild("FavoriteIcon")
if not icon then
icon = Instance.new("ImageLabel")
icon.Name = "FavoriteIcon"
icon.Size = UDim2.new(0.3,0,0.3,0)
icon.Position = UDim2.new(0.7,0,0,0)
icon.AnchorPoint = Vector2.new(0,0)
icon.BackgroundTransparency = 1
icon.ZIndex = btn.ZIndex + 5
icon.ScaleType = Enum.ScaleType.Fit
icon.Parent = btn
end
icon.Image   = isFav and favoriteIconId or notFavoriteIconId
icon.Visible = true
end
local function hideFavIcon(btn)
local icon = btn:FindFirstChild("FavoriteIcon")
if icon then icon.Visible = false end
end
local applyAnimation, toggleFavorite, toggleFavoriteAnimation
local function renderPage()
local buttons = getFrontButtons()
local items   = getPageItems(currentPage)
_disconnectAll()
if currentMode == "animation" then
for i, btn in ipairs(buttons) do
local item = items[i]
if item then
local numId = tonumber(item.id)
btn.Image = numId and ("rbxthumb://type=BundleThumbnail&id=" .. numId .. "&w=420&h=420") or ""
-- Namen-Label aktualisieren (Roblox-natives TextLabel "EmoteName" im Button)
local nameLabel = btn:FindFirstChild("EmoteName")
if nameLabel and nameLabel:IsA("TextLabel") then
nameLabel.Text = item.name or ""
end
local idVal = btn:FindFirstChild("AnimationID")
if not idVal then
idVal = Instance.new("IntValue"); idVal.Name = "AnimationID"; idVal.Parent = btn
end
idVal.Value = numId or 0
local isFav = isInFavorites(item.id)
if isFav then setFavoriteIcon(btn, true)
elseif favoriteEnabled then setFavoriteIcon(btn, false)
else hideFavIcon(btn) end
local cd = btn:FindFirstChild("ClickDetector")
if not cd then
cd = Instance.new("TextButton"); cd.Name = "ClickDetector"
cd.Size = UDim2.new(1,0,1,0); cd.Position = UDim2.new(0,0,0,0)
cd.BackgroundTransparency = 1; cd.Text = ""
cd.ZIndex = btn.ZIndex + 1; cd.Parent = btn
end
cd.Visible = true
local capturedItem = item
local conn = cd.MouseButton1Click:Connect(function()
if favoriteEnabled then toggleFavoriteAnimation(capturedItem)
else applyAnimation(capturedItem) end
end)
_clickConns[#_clickConns+1] = conn
else
btn.Image = ""
-- Namen-Label beim Leeren zurücksetzen
local nameLabel = btn:FindFirstChild("EmoteName")
if nameLabel and nameLabel:IsA("TextLabel") then
nameLabel.Text = ""
end
local idVal = btn:FindFirstChild("AnimationID")
if idVal then idVal.Value = 0 end
hideFavIcon(btn)
local cd = btn:FindFirstChild("ClickDetector")
if cd then cd.Visible = false end
end
end
return
end
for _, btn in ipairs(buttons) do
local liveImg = btn.Image
local liveId  = liveImg and liveImg:match("id=(%d+)")
local liveNum = liveId and tonumber(liveId)
if liveNum then
if isInFavorites(liveNum) then setFavoriteIcon(btn, true)
elseif favoriteEnabled    then setFavoriteIcon(btn, false)
else                          hideFavIcon(btn) end
else                           hideFavIcon(btn) end
local capturedBtn = btn
local restoreConn = capturedBtn.ChildRemoved:Connect(function(child)
if child.Name == "FavoriteIcon" then
task.defer(function()
local img = capturedBtn.Image
local id  = img and img:match("id=(%d+)")
local num = id and tonumber(id)
if num then
if isInFavorites(num) then setFavoriteIcon(capturedBtn, true)
elseif favoriteEnabled then setFavoriteIcon(capturedBtn, false) end
end
end)
end
end)
_clickConns[#_clickConns+1] = restoreConn
local cd = btn:FindFirstChild("ClickDetector")
if favoriteEnabled then
if not cd then
cd = Instance.new("TextButton"); cd.Name = "ClickDetector"
cd.Size = UDim2.new(1,0,1,0); cd.Position = UDim2.new(0,0,0,0)
cd.BackgroundTransparency = 1; cd.Text = ""
cd.ZIndex = btn.ZIndex + 1; cd.Parent = btn
end
cd.Visible = true
local conn = cd.MouseButton1Click:Connect(function()
local img   = capturedBtn.Image
local rawId = img and img:match("id=(%d+)")
if not rawId then return end
local numId = tonumber(rawId)
local name = (_emoteNameCache and _emoteNameCache[rawId]) or "Emote_" .. rawId
if name == "Emote_" .. rawId then
for _, e in ipairs(filteredEmotes) do if tonumber(e.id) == numId then name = e.name; break end end
for _, f in ipairs(favoriteEmotes) do if tonumber(f.id) == numId then name = f.name; break end end
end
toggleFavorite(rawId, name)
end)
_clickConns[#_clickConns+1] = conn
else
if cd then cd.Visible = false end
end
end
end
local function applyHumanoidSlots()
local _, hum = getAnimCharAndHumanoid()
if not hum then return end
local desc = hum.HumanoidDescription
if not desc then return end
pcall(function()
_SvcSG:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
end)
-- In animation mode skip SetEmotes/SetEquippedEmotes entirely.
-- Passing animation pack IDs as emote IDs causes Roblox to reset the
-- EmotesButtons children, destroying our ClickDetectors mid-render.
if currentMode == "animation" then
invalidateFrontButtonsCache()
renderPage()
return
end
local items = getPageItems(currentPage)
local emoteTable = {}
local equippedList = {}
for _, item in ipairs(items) do
local numId = tonumber(item.id)
if numId then
emoteTable[item.name] = {numId}
equippedList[#equippedList+1] = item.name
end
end
pcall(function()
desc:SetEmotes(emoteTable)
desc:SetEquippedEmotes(equippedList)
end)
end
function updateEmotes()
applyHumanoidSlots()
if currentMode == "emote" then
task.delay(0.25, function()
renderPage()
task.delay(0.4, function()
local buttons = getFrontButtons()
for _, btn in ipairs(buttons) do
local img   = btn.Image
local rawId = img and img:match("id=(%d+)")
local numId = rawId and tonumber(rawId)
if numId then
if isInFavorites(numId) then setFavoriteIcon(btn, true)
elseif favoriteEnabled   then setFavoriteIcon(btn, false)
else                          hideFavIcon(btn) end
end
end
end)
end)
end
end
function updatePageDisplay()
if _4pages       then _4pages.Text       = tostring(totalPages)  end
if _2Routenumber then _2Routenumber.Text = tostring(currentPage) end
end
local _navCooldown, _emoteWalkBeforeFreeze = false, nil
local function goToPage(n)
currentPage = math.max(1, math.min(n, totalPages))
updatePageDisplay(); updateEmotes()
end
local function previousPage()
if _navCooldown then return end
_navCooldown = true
currentPage = currentPage <= 1 and totalPages or currentPage - 1
updatePageDisplay(); updateEmotes()
task.delay(0.12, function() _navCooldown = false end)
end
local function nextPage()
if _navCooldown then return end
_navCooldown = true
currentPage = currentPage >= totalPages and 1 or currentPage + 1
updatePageDisplay(); updateEmotes()
task.delay(0.12, function() _navCooldown = false end)
end
toggleFavorite = function(emoteId, emoteName)
local cleanName = emoteName:gsub(" %- ?$", "")
local key = tostring(emoteId)
local found, idx = false, 0
for i, f in ipairs(favoriteEmotes) do
if tostring(f.id) == key then found = true; idx = i; break end
end
if found then
table.remove(favoriteEmotes, idx); _favSetEmote[key] = nil
animNotif("Animations-Menu", '❌ "' .. cleanName .. '" removed', 3)
else
table.insert(favoriteEmotes, {id=emoteId, name=cleanName.." - ?"})
_favSetEmote[key] = true
animNotif("Animations-Menu", '★ "' .. cleanName .. '" added', 3)
end
saveFavorites(); invalidatePagesCache()
totalPages  = calculateTotalPages()
currentPage = math.min(currentPage, totalPages)
updatePageDisplay(); updateEmotes()
end
toggleFavoriteAnimation = function(animData)
local cleanName = animData.name:gsub(" %- ?$", "")
local key = tostring(animData.id)
local found, idx = false, 0
for i, f in ipairs(favoriteAnimations) do
if tostring(f.id) == key then found = true; idx = i; break end
end
if found then
table.remove(favoriteAnimations, idx); _favSetAnim[key] = nil
animNotif("Animations-Menu", '❌ "' .. cleanName .. '" removed', 3)
else
table.insert(favoriteAnimations, {id=animData.id, name=cleanName.." - ?", bundledItems=animData.bundledItems})
_favSetAnim[key] = true
animNotif("Animations-Menu", '★ "' .. cleanName .. '" added', 3)
end
saveFavoritesAnimations(); invalidatePagesCache()
totalPages  = calculateTotalPages()
currentPage = math.min(currentPage, totalPages)
updatePageDisplay(); updateEmotes()
end
local function toggleFavoriteMode()
favoriteEnabled = not favoriteEnabled
if Favorite then Favorite.Image = favoriteEnabled and favoriteIconId or notFavoriteIconId end
if favoriteEnabled then
animNotif("Animations-Menu", "★ Favorites ON – click image to add/remove", 4)
else
animNotif("Animations-Menu", "★ Favorites OFF", 2)
end
invalidateFrontButtonsCache()
invalidatePagesCache()
if currentMode == "emote" then
-- updateEmotes setzt die richtigen Emote-Bilder via applyHumanoidSlots
updateEmotes()
-- renderPage danach: Icons/ClickDetectors korrekt setzen
task.delay(0.3, function()
renderPage()
-- nach dem Roblox-Delay: alle FavIcons die nicht mehr gebraucht werden verstecken
task.delay(0.45, function()
local buttons = getFrontButtons()
for _, btn in ipairs(buttons) do
local img   = btn.Image
local rawId = img and img:match("id=(%d+)")
local numId = rawId and tonumber(rawId)
if numId then
if isInFavorites(numId) then setFavoriteIcon(btn, true)
elseif favoriteEnabled  then setFavoriteIcon(btn, false)
else                         hideFavIcon(btn) end
else
hideFavIcon(btn)
end
end
end)
end)
else
renderPage()
end
end
local function toggleFavOnly()
favOnlyEnabled = not favOnlyEnabled
if FavOnlyBtn then
if favOnlyEnabled then
FavOnlyBtn.BackgroundColor3       = Color3.fromRGB(255, 200, 0)
FavOnlyBtn.BackgroundTransparency = 0
FavOnlyBtn.TextColor3             = Color3.fromRGB(30, 30, 30)
_G.filteredFavoritesForDisplay           = nil
_G.filteredFavoritesAnimationsForDisplay = nil
if Search then Search.Text = "" end
if currentMode == "emote" then emoteSearchTerm = ""; filteredEmotes = originalEmotesData
else animationSearchTerm = ""; filteredAnimations = originalAnimationsData end
else
FavOnlyBtn.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
FavOnlyBtn.BackgroundTransparency = 0.92
FavOnlyBtn.TextColor3             = Color3.fromRGB(210, 210, 210)
end
end
invalidatePagesCache()
totalPages  = calculateTotalPages()
currentPage = 1
updatePageDisplay(); updateEmotes()
if favOnlyEnabled then
animNotif("Animations-Menu", "★ Nur Favorites – " .. totalPages .. " Seite(n)", 2)
else
animNotif("Animations-Menu", "★ Alle anzeigen", 2)
end
end
local function stopAnimEmotes()
if not animHumanoid or not animHumanoid.Parent then return end
pcall(function()
for _, t in ipairs(animHumanoid:GetPlayingAnimationTracks()) do t:Stop() end
end)
end
local function stopCurrentEmote()
if currentEmoteTrack then pcall(function() currentEmoteTrack:Stop() end); currentEmoteTrack = nil end
end
local function playEmote(hum, emoteId)
stopCurrentEmote(); stopAnimEmotes()
local anim = Instance.new("Animation"); anim.AnimationId = "rbxassetid://" .. emoteId
local ok, track = pcall(function() return hum.Animator:LoadAnimation(anim) end)
if ok and track then
currentEmoteTrack = track
track.Priority = Enum.AnimationPriority.Action
track.Looped   = true
if speedEmoteEnabled or emotesWalkEnabled then
track:Play()
if speedEmoteEnabled then track:AdjustSpeed((SpeedBox and tonumber(SpeedBox.Text)) or 1) end
end
end
end
local function isGivenAnimation(holder, animId)
for _, a in ipairs(holder:GetChildren()) do
if a:IsA("Animation") and urlToId(a.AnimationId) == animId then return true end
end
return false
end
local function isDancing(char, track)
local id = urlToId(track.Animation.AnimationId)
for _, h in ipairs(char.Animate:GetChildren()) do
if h:IsA("StringValue") and isGivenAnimation(h, id) then return false end
end
return true
end
applyAnimation = function(animData)
local ch = animPlayer.Character or animPlayer.CharacterAdded:Wait()
local hum = ch:FindFirstChild("Humanoid")
local animate = ch:FindFirstChild("Animate")
if not animate or not hum then animNotif("Animations-Menu","⚠ Animate/Humanoid missing",3); return end
if not animData.bundledItems then animNotif("Animations-Menu","⚠ No bundledItems",3); return end
if getgenv then _genv.lastPlayedAnimation = animData end
for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end
for _, assetIds in pairs(animData.bundledItems) do
for _, assetId in ipairs(assetIds) do
task.spawn(function()
local ok, objects = pcall(function() return game:GetObjects("rbxassetid://"..assetId) end)
if not ok or not objects then return end
local function search(parent, path)
for _, child in ipairs(parent:GetChildren()) do
if child:IsA("Animation") then
local parts = (path.."."..child.Name):split(".")
if #parts >= 2 then
local cat  = parts[#parts-1]
local name = parts[#parts]
local catFolder = animate:FindFirstChild(cat)
if catFolder and catFolder:FindFirstChild(name) then
catFolder[name].AnimationId = child.AnimationId
task.wait(0.1)
local a2 = Instance.new("Animation"); a2.AnimationId = child.AnimationId
local t2 = hum.Animator:LoadAnimation(a2)
t2.Priority = Enum.AnimationPriority.Action; t2:Play()
task.wait(0.1); t2:Stop()
end
end
elseif #child:GetChildren() > 0 then
search(child, path.."."..child.Name)
end
end
end
for _, obj in ipairs(objects) do
search(obj, obj.Name)
obj.Parent = workspace
task.delay(1, function() if obj then obj:Destroy() end end)
end
end)
end
end
end
local function fetchAllEmotes()
if isLoadingEmotes then return end
isLoadingEmotes = true; isLoading = true; emotesData = {}; totalEmotesLoaded = 0
local ok, result = pcall(function()
local json = game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json")
if json and json ~= "" then return AnimHttpService:JSONDecode(json).data or {} end
return nil
end)
if ok and result then
for _, item in ipairs(result) do
local d = {id=tonumber(item.id), name=item.name or ("Emote_"..(item.id or "?"))}
if d.id and d.id > 0 then emotesData[#emotesData+1] = d; totalEmotesLoaded = totalEmotesLoaded + 1 end
end
else
emotesData = {{id=3360686498,name="Stadium"},{id=3360692915,name="Tilt"},{id=3576968026,name="Shrug"},{id=3360689775,name="Salute"}}
totalEmotesLoaded = #emotesData
end
originalEmotesData = emotesData; filteredEmotes = emotesData
_emoteNameCache = {}
for _, e in ipairs(emotesData) do _emoteNameCache[tostring(e.id)] = e.name end
invalidatePagesCache()
totalPages = calculateTotalPages(); currentPage = 1; updatePageDisplay(); updateEmotes()
animNotif("Animations-Menu","📦 "..totalEmotesLoaded.." Emotes loaded!", 4)
isLoadingEmotes = false; isLoading = false
end
local function fetchAllAnimations()
if isLoadingAnimations then return end
isLoadingAnimations = true; animationsData = {}
local ok, result = pcall(function()
local json = game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/AnimationSniper.json")
if json and json ~= "" then return AnimHttpService:JSONDecode(json).data or {} end
return nil
end)
if ok and result then
for _, item in ipairs(result) do
local d = {id=tonumber(item.id), name=item.name or ("Anim_"..(item.id or "?")), bundledItems=item.bundledItems}
if d.id and d.id > 0 then animationsData[#animationsData+1] = d end
end
end
originalAnimationsData = animationsData; filteredAnimations = animationsData
isLoadingAnimations = false
end
local function searchEmotes(term)
if isLoading then animNotif("Animations-Menu","⏳ Loading...",2); return end
term = term:lower()
if term == "" then
filteredEmotes = originalEmotesData
_G.filteredFavoritesForDisplay = nil
else
local isId = term:match("^%d%d%d%d%d+$")
local newList = {}
if isId then
for _, e in ipairs(originalEmotesData) do
if tostring(e.id) == term then newList[#newList+1] = e end
end
if #newList == 0 then
local id = tonumber(term)
if id then
local n = getEmoteName(id)
local ne = {id=id, name=n}
originalEmotesData[#originalEmotesData+1] = ne
newList[#newList+1] = ne
end
end
else
for _, e in ipairs(originalEmotesData) do
if e.name:lower():find(term, 1, true) then newList[#newList+1] = e end
end
end
filteredEmotes = newList
if not isId then
_G.filteredFavoritesForDisplay = {}
for _, f in ipairs(favoriteEmotes) do
if f.name:lower():find(term, 1, true) then _G.filteredFavoritesForDisplay[#_G.filteredFavoritesForDisplay+1] = f end
end
else _G.filteredFavoritesForDisplay = nil end
end
invalidatePagesCache()
totalPages = calculateTotalPages(); currentPage = 1; updatePageDisplay(); updateEmotes()
end
local function searchAnimations(term)
if isLoading then animNotif("Animations-Menu","⏳ Loading...",2); return end
term = term:lower()
if term == "" then
filteredAnimations = originalAnimationsData
_G.filteredFavoritesAnimationsForDisplay = nil
else
local isId = term:match("^%d+$")
local newList = {}
if isId then
for _, a in ipairs(originalAnimationsData) do
if tostring(a.id) == term then newList[#newList+1] = a end
end
else
for _, a in ipairs(originalAnimationsData) do
if a.name:lower():find(term, 1, true) then newList[#newList+1] = a end
end
end
filteredAnimations = newList
if not isId then
_G.filteredFavoritesAnimationsForDisplay = {}
for _, f in ipairs(favoriteAnimations) do
if f.name:lower():find(term, 1, true) then _G.filteredFavoritesAnimationsForDisplay[#_G.filteredFavoritesAnimationsForDisplay+1] = f end
end
else _G.filteredFavoritesAnimationsForDisplay = nil end
end
invalidatePagesCache()
totalPages = calculateTotalPages(); currentPage = 1; updatePageDisplay(); updateEmotes()
end
local function toggleEmoteWalk()
emotesWalkEnabled = not emotesWalkEnabled
if EmoteWalkButton then EmoteWalkButton.Image = emotesWalkEnabled and enabledButtonImage or defaultButtonImage end
task.defer(stopCurrentEmote)
end
if getgenv then
_genv.TLAnimFreeze = function(on)
if on then
_emoteWalkBeforeFreeze = emotesWalkEnabled
emotesWalkEnabled = true
if EmoteWalkButton then EmoteWalkButton.Image = enabledButtonImage end
else
_emoteWalkBeforeFreeze = nil
emotesWalkEnabled = false
if EmoteWalkButton then EmoteWalkButton.Image = defaultButtonImage end
pcall(stopCurrentEmote); pcall(stopAnimEmotes)
end
end
end
local function toggleSpeedEmote()
speedEmoteEnabled = not speedEmoteEnabled
if SpeedBox then SpeedBox.Visible = speedEmoteEnabled end
animNotif("Animations-Menu", speedEmoteEnabled and "⚡ Speed Emote ON" or "⚡ Speed Emote OFF", 2)
task.defer(stopCurrentEmote)
if writefile then
writefile(speedEmoteConfigFile, AnimHttpService:JSONEncode({
Enabled=speedEmoteEnabled,
SpeedValue=(SpeedBox and tonumber(SpeedBox.Text)) or 1
}))
end
end
local function toggleAutoReload()
if getgenv then
_genv.autoReloadEnabled = not (_genv.autoReloadEnabled or false)
animNotif("Animations-Menu", _genv.autoReloadEnabled and "🔄 Auto-Reload ON" or "🔄 Auto-Reload OFF", 2)
end
end
local function switchMode()
_disconnectAll()
if favOnlyEnabled then
favOnlyEnabled = false
if FavOnlyBtn then
FavOnlyBtn.BackgroundColor3       = Color3.fromRGB(255,255,255)
FavOnlyBtn.BackgroundTransparency = 0.92
FavOnlyBtn.TextColor3             = Color3.fromRGB(210,210,210)
end
end
_G.filteredFavoritesForDisplay           = nil
_G.filteredFavoritesAnimationsForDisplay = nil
if currentMode == "emote" then
currentMode = "animation"
animNotif("Animations-Menu","🎬 Mode: Animation",2)
task.spawn(function()
fetchAllAnimations()
if Search then Search.Text = animationSearchTerm end
invalidatePagesCache()
totalPages = calculateTotalPages(); currentPage = 1
updatePageDisplay(); updateEmotes()
end)
else
currentMode = "emote"
animNotif("Animations-Menu","🎬 Mode: Emote",2)
if Search then Search.Text = emoteSearchTerm end
invalidateFrontButtonsCache()
invalidatePagesCache()
totalPages = calculateTotalPages(); currentPage = 1
updatePageDisplay(); updateEmotes()
end
if Reload then
local isAnim = (currentMode == "animation")
Reload.Visible = isAnim
if Reload.Parent then Reload.Parent.Visible = isAnim end
end
end
local function onAnimCharacterAdded(char)
stopCurrentEmote()
local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
if not hum then return end
local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
if getgenv and getgenv().autoReloadEnabled and getgenv().lastPlayedAnimation then
task.wait(0.3); applyAnimation(_genv.lastPlayedAnimation)
animNotif("Animations-Menu","🔄 Animation auto-reloaded",3)
end
animator.AnimationPlayed:Connect(function(track)
if not isDancing(char, track) then return end
local playedId = urlToId(track.Animation.AnimationId)
if not (emotesWalkEnabled or speedEmoteEnabled) then return end
if currentEmoteTrack then
if urlToId(currentEmoteTrack.Animation.AnimationId) == playedId then return end
stopCurrentEmote()
end
playEmote(hum, playedId)
local capturedTrack = currentEmoteTrack
if capturedTrack then
capturedTrack.Ended:Connect(function()
if currentEmoteTrack == capturedTrack then currentEmoteTrack = nil end
end)
end
end)
hum.Died:Connect(function()
emotesWalkEnabled = false; speedEmoteEnabled = false
favoriteEnabled   = false; favOnlyEnabled    = false
currentEmoteTrack = nil
stopAnimEmotes(); stopCurrentEmote()
pcall(function()
if EmoteWalkButton then EmoteWalkButton.Image = defaultButtonImage end
if Favorite        then Favorite.Image        = notFavoriteIconId   end
if SpeedBox        then SpeedBox.Visible      = false               end
if FavOnlyBtn then
FavOnlyBtn.BackgroundColor3       = Color3.fromRGB(255,255,255)
FavOnlyBtn.BackgroundTransparency = 0.92
FavOnlyBtn.TextColor3             = Color3.fromRGB(210,210,210)
end
end)
end)
end
function checkR6Hint(char)
pcall(function()
local hum = char and char:FindFirstChild("Humanoid")
if hum and hum.RigType == Enum.HumanoidRigType.R6 then
local e = AnimCoreGui.RobloxGui.EmotesMenu.Children.ErrorMessage
if e and e.Visible then e.ErrorText.Text = "Only R15 – R6 not supported" end
end
end)
end
if animPlayer.Character then checkR6Hint(animPlayer.Character) end
_tlTrackConn(animPlayer.CharacterAdded:Connect(checkR6Hint))
local createGUIElements, connectEvents
createGUIElements = function()
local exists, emotesWheel = checkEmotesMenuExists()
if not exists then return false end
for _, n in ipairs({"Under","Top","EmoteWalkButton","Favorite","SpeedEmote","AvatarOutfitBtn","SpeedBox","Changepage","Reload"}) do
local old = emotesWheel:FindFirstChild(n); if old then old:Destroy() end
end
invalidateFrontButtonsCache(); markGUIDirty()
local BAR_H = 60; local ICON_SZ = 46; local TXT_SZ = 22; local SEP_SZ = 20
local NUM_W = 36; local SEP_W = 14; local BAR_PAD_X = 12; local GAP = 8
local CONTENT_W = ICON_SZ + NUM_W + SEP_W + NUM_W + ICON_SZ + GAP * 4
local BAR_W = CONTENT_W + BAR_PAD_X * 2
local BAR_R = math.floor(BAR_H / 2)
Under = Instance.new("Frame", emotesWheel)
Under.Name = "Under"; Under.Size = UDim2.new(0,BAR_W,0,BAR_H)
Under.Position = UDim2.new(0.5,-math.floor(BAR_W/2),1,6)
Under.BackgroundColor3 = Color3.fromRGB(230,230,230); Under.BackgroundTransparency = 0.1
Under.BorderSizePixel = 0; Under.ZIndex = 5
UICorner2 = Instance.new("UICorner",Under); UICorner2.CornerRadius = UDim.new(0,BAR_R)
UIListLayout = Instance.new("UIListLayout",Under)
UIListLayout.FillDirection = Enum.FillDirection.Horizontal
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
UIListLayout.Padding = UDim.new(0,GAP)
_1left = Instance.new("ImageButton",Under); _1left.Name="_1left"
_1left.Size=UDim2.new(0,ICON_SZ,0,ICON_SZ); _1left.BackgroundTransparency=1
_1left.Image="rbxassetid://115722085423678"; _1left.ScaleType=Enum.ScaleType.Fit
_1left.ZIndex=6; _1left.BorderSizePixel=0
UICorner1=Instance.new("UICorner",_1left); UICorner1.CornerRadius=UDim.new(0,8)
_2Routenumber = Instance.new("TextBox",Under); _2Routenumber.Name="_2Routenumber"
_2Routenumber.Size=UDim2.new(0,NUM_W,1,0); _2Routenumber.BackgroundTransparency=1
_2Routenumber.Text="1"; _2Routenumber.TextColor3=Color3.fromRGB(0,0,0)
_2Routenumber.TextSize=TXT_SZ; _2Routenumber.Font=Enum.Font.GothamBold
_2Routenumber.ZIndex=6; _2Routenumber.TextXAlignment=Enum.TextXAlignment.Center
_2Routenumber.TextYAlignment=Enum.TextYAlignment.Center; _2Routenumber.ClearTextOnFocus=false
_3TextLabel = Instance.new("TextLabel",Under); _3TextLabel.Name="_3TextLabel"
_3TextLabel.Size=UDim2.new(0,SEP_W,1,0); _3TextLabel.BackgroundTransparency=1
_3TextLabel.Text="/"; _3TextLabel.TextColor3=Color3.fromRGB(0,0,0)
_3TextLabel.TextSize=SEP_SZ; _3TextLabel.Font=Enum.Font.Gotham
_3TextLabel.ZIndex=6; _3TextLabel.TextXAlignment=Enum.TextXAlignment.Center
_3TextLabel.TextYAlignment=Enum.TextYAlignment.Center
_4pages = Instance.new("TextLabel",Under); _4pages.Name="_4pages"
_4pages.Size=UDim2.new(0,NUM_W,1,0); _4pages.BackgroundTransparency=1
_4pages.Text="1"; _4pages.TextColor3=Color3.fromRGB(0,0,0)
_4pages.TextSize=TXT_SZ-2; _4pages.Font=Enum.Font.Gotham
_4pages.ZIndex=6; _4pages.TextXAlignment=Enum.TextXAlignment.Center
_4pages.TextYAlignment=Enum.TextYAlignment.Center
_9right = Instance.new("ImageButton",Under); _9right.Name="_9right"
_9right.Size=UDim2.new(0,ICON_SZ,0,ICON_SZ); _9right.BackgroundTransparency=1
_9right.Image="rbxassetid://116077200359451"; _9right.ScaleType=Enum.ScaleType.Fit
_9right.ZIndex=6; _9right.BorderSizePixel=0
UIListLayout_2=Instance.new("UICorner",_9right); UIListLayout_2.CornerRadius=UDim.new(0,8)
Top = Instance.new("Frame",emotesWheel); Top.Name="Top"
Top.Size=UDim2.new(1,0,0,53); Top.Position=UDim2.new(0,0,0,-54)
Top.BackgroundColor3=Color3.fromRGB(18,18,18); Top.BackgroundTransparency=0.15
Top.BorderSizePixel=0; Top.ZIndex=5
UICorner=Instance.new("UICorner",Top); UICorner.CornerRadius=UDim.new(0,14)
local BTN_H=24; local LBL_H=10; local BTN_Y=6
local function makeIconBtn(parent, name, icon, posX, tip, isImg)
local wrap = Instance.new("Frame",parent)
wrap.Name=name.."_wrap"; wrap.Size=UDim2.new(0,28,0,BTN_H+LBL_H+4)
wrap.Position=UDim2.new(0,posX or 0,0,BTN_Y); wrap.BackgroundTransparency=1; wrap.ZIndex=6
local btn
if isImg then
btn=Instance.new("ImageButton",wrap); btn.Image=icon; btn.ImageColor3=Color3.fromRGB(210,210,210)
else
btn=Instance.new("TextButton",wrap); btn.Text=icon; btn.TextSize=14
btn.Font=Enum.Font.GothamBold; btn.TextColor3=Color3.fromRGB(210,210,210); btn.TextScaled=false
end
btn.Name=name; btn.Size=UDim2.new(1,0,0,BTN_H); btn.Position=UDim2.new(0,0,0,0)
btn.BackgroundColor3=Color3.fromRGB(255,255,255); btn.BackgroundTransparency=0.92
btn.BorderSizePixel=0; btn.ZIndex=7
local bc=Instance.new("UICorner",btn); bc.CornerRadius=UDim.new(0,7)
local lbl=Instance.new("TextLabel",wrap); lbl.Size=UDim2.new(1,0,0,LBL_H)
lbl.Position=UDim2.new(0,0,0,BTN_H+2); lbl.BackgroundTransparency=1; lbl.Text=tip
lbl.TextSize=8; lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=Color3.fromRGB(240,240,240)
lbl.TextScaled=false; lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.ZIndex=7
btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
btn.BackgroundTransparency=0.78
end)
btn.MouseLeave:Connect(function() btn.BackgroundTransparency=0.92 end)
return btn
end
local searchWrap=Instance.new("Frame",Top); searchWrap.Name="Search_wrap"
searchWrap.Size=UDim2.new(0,88,0,BTN_H); searchWrap.Position=UDim2.new(0,6,0,BTN_Y)
searchWrap.BackgroundColor3=Color3.fromRGB(255,255,255); searchWrap.BackgroundTransparency=0.92
searchWrap.BorderSizePixel=0; searchWrap.ZIndex=6
local swc=Instance.new("UICorner",searchWrap); swc.CornerRadius=UDim.new(0,8)
local sico=Instance.new("TextLabel",searchWrap); sico.Size=UDim2.new(0,16,1,0)
sico.Position=UDim2.new(0,3,0,0); sico.BackgroundTransparency=1; sico.Text="🔍"
sico.TextSize=10; sico.Font=Enum.Font.Gotham; sico.TextXAlignment=Enum.TextXAlignment.Center; sico.ZIndex=7
Search=Instance.new("TextBox",searchWrap); Search.Name="Search"
Search.Size=UDim2.new(1,-20,1,0); Search.Position=UDim2.new(0,18,0,0)
Search.BackgroundTransparency=1; Search.Text=""; Search.PlaceholderText="Search…"
Search.PlaceholderColor3=Color3.fromRGB(120,120,120); Search.TextColor3=Color3.fromRGB(220,220,220)
Search.TextSize=11; Search.Font=Enum.Font.Gotham; Search.TextScaled=false
Search.ZIndex=7; Search.ClearTextOnFocus=false; Search.TextXAlignment=Enum.TextXAlignment.Left
local btnStartX=100; local btnGap=32
EmoteWalkButton = makeIconBtn(Top,"EmoteWalkButton",defaultButtonImage,btnStartX,          "Walk",  true)
Favorite        = makeIconBtn(Top,"Favorite",       notFavoriteIconId, btnStartX+btnGap,   "Favs",  true)
FavOnlyBtn      = makeIconBtn(Top,"FavOnlyBtn",     "★",              btnStartX+btnGap*2, "Only",  false)
SpeedEmote      = makeIconBtn(Top,"SpeedEmote",     defaultButtonImage,btnStartX+btnGap*3, "Speed", true)
AvatarOutfitBtn = makeIconBtn(Top,"AvatarOutfitBtn","rbxassetid://97506385486915",btnStartX+btnGap*4,"Outfit",true)
SpeedBox=Instance.new("TextBox",Top); SpeedBox.Name="SpeedBox"
SpeedBox.Size=UDim2.new(0,28,0,BTN_H); SpeedBox.Position=UDim2.new(0,btnStartX+btnGap*5,0,BTN_Y)
SpeedBox.BackgroundColor3=Color3.fromRGB(255,255,255); SpeedBox.BackgroundTransparency=0.92
SpeedBox.TextColor3=Color3.fromRGB(220,220,220); SpeedBox.TextSize=11; SpeedBox.Font=Enum.Font.GothamBold
SpeedBox.TextScaled=false; SpeedBox.Text="1"; SpeedBox.ZIndex=7; SpeedBox.Visible=false
SpeedBox.ClearTextOnFocus=false; SpeedBox.TextXAlignment=Enum.TextXAlignment.Center
UICorner_5=Instance.new("UICorner",SpeedBox); UICorner_5.CornerRadius=UDim.new(0,7)
local div=Instance.new("Frame",Top); div.Size=UDim2.new(0,1,0,20)
div.Position=UDim2.new(1,-66,0,BTN_Y+2); div.BackgroundColor3=Color3.fromRGB(255,255,255)
div.BackgroundTransparency=0.8; div.BorderSizePixel=0; div.ZIndex=6
Changepage=makeIconBtn(Top,"Changepage","🔄",nil,"Mode",false); Changepage.Parent.Position=UDim2.new(1,-61,0,BTN_Y)
Reload    =makeIconBtn(Top,"Reload",    "🔄",nil,"Reload",false); Reload.Parent.Position=UDim2.new(1,-31,0,BTN_Y)
Reload.Visible=false
emotesWalkEnabled=false; speedEmoteEnabled=false; favoriteEnabled=false; favOnlyEnabled=false
EmoteWalkButton.Image=defaultButtonImage; Favorite.Image=notFavoriteIconId
if FavOnlyBtn then
FavOnlyBtn.BackgroundColor3=Color3.fromRGB(255,255,255)
FavOnlyBtn.BackgroundTransparency=0.92
FavOnlyBtn.TextColor3=Color3.fromRGB(210,210,210)
end
if SpeedBox then SpeedBox.Visible=false end
if Reload then Reload.Visible=false; Reload.Parent.Visible=false end
isGUICreated=true; connectEvents(); updateGUIColors()
return true
end
function safe(name, cb)
local now = os.clock()
if not _clickCooldown[name] or (now - _clickCooldown[name]) > COOLDOWN then
_clickCooldown[name] = now; cb()
end
end
connectEvents = function()
_disconnectBtns()
if _1left  then _btnConns[#_btnConns+1] = _1left.MouseButton1Click:Connect(previousPage) end
if _9right then _btnConns[#_btnConns+1] = _9right.MouseButton1Click:Connect(nextPage)     end
if _2Routenumber then
_btnConns[#_btnConns+1] = _2Routenumber.FocusLost:Connect(function()
local p = tonumber(_2Routenumber.Text)
if p then goToPage(p) else _2Routenumber.Text = tostring(currentPage) end
end)
end
if Search then
local _searchDebounceThread = nil
_btnConns[#_btnConns+1] = Search.Changed:Connect(function(prop)
if prop ~= "Text" then return end
local capturedText = Search.Text
if _searchDebounceThread then
pcall(task.cancel, _searchDebounceThread); _searchDebounceThread = nil
end
_searchDebounceThread = task.delay(0.1, function()
_searchDebounceThread = nil
if currentMode == "emote" then
emoteSearchTerm = capturedText; searchEmotes(emoteSearchTerm)
else
animationSearchTerm = capturedText; searchAnimations(animationSearchTerm)
end
end)
end)
end
if EmoteWalkButton then _btnConns[#_btnConns+1] = EmoteWalkButton.MouseButton1Click:Connect(function() safe("Walk",  toggleEmoteWalk)    end) end
if Favorite        then _btnConns[#_btnConns+1] = Favorite.MouseButton1Click:Connect(       function() safe("Favs",  toggleFavoriteMode) end) end
if FavOnlyBtn      then _btnConns[#_btnConns+1] = FavOnlyBtn.MouseButton1Click:Connect(     function() safe("FavOnly",toggleFavOnly)     end) end
if SpeedEmote      then _btnConns[#_btnConns+1] = SpeedEmote.MouseButton1Click:Connect(     function() safe("Speed", toggleSpeedEmote)   end) end
if AvatarOutfitBtn then _btnConns[#_btnConns+1] = AvatarOutfitBtn.MouseButton1Click:Connect(function()
    safe("Outfit", function()
        pcall(function()
            if readfile and loadstring then
                local content = readfile("c:/Users/OPSEC/Downloads/AvatarOutfitPanelTest.lua")
                if content then
                    loadstring(content)()
                    animNotif("Avatar Outfit Panel", "Panel geladen!", 3)
                else
                    animNotif("Avatar Outfit Panel", "Datei nicht gefunden!", 2)
                end
            else
                animNotif("Avatar Outfit Panel", "Executor unterstützt nicht!", 2)
            end
        end)
    end)
end) end
if Reload          then _btnConns[#_btnConns+1] = Reload.MouseButton1Click:Connect(         function() safe("Reload",toggleAutoReload)   end) end
if Changepage      then _btnConns[#_btnConns+1] = Changepage.MouseButton1Click:Connect(     function() safe("Mode",  switchMode)         end) end
if SpeedBox then
_btnConns[#_btnConns+1] = SpeedBox.FocusLost:Connect(function()
if writefile then
writefile(speedEmoteConfigFile, AnimHttpService:JSONEncode({
Enabled=speedEmoteEnabled, SpeedValue=tonumber(SpeedBox.Text) or 1
}))
end
end)
end
end
function checkAndRecreateGUI()
local exists, ew = checkEmotesMenuExists(); if not exists then isGUICreated=false; return end
-- Only check direct children of the wheel (Under/Top are direct children).
-- Favorite, Changepage etc. live inside Top and are NOT direct children,
-- so using FindFirstChild without recursive=true always returned nil,
-- causing createGUIElements() to run every 0.1 s in an infinite loop.
if not ew:FindFirstChild("Under") or not ew:FindFirstChild("Top") then
isGUICreated = false
end
if not isGUICreated then
if createGUIElements() then updatePageDisplay(); updateEmotes(); loadSpeedEmoteConfig() end
end
end
if animPlayer.Character then onAnimCharacterAdded(animPlayer.Character) end
_tlTrackConn(animPlayer.CharacterAdded:Connect(function(char)
animCharacter = char
animHumanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
emotesWalkEnabled=false; speedEmoteEnabled=false; favoriteEnabled=false; favOnlyEnabled=false
currentEmoteTrack=nil; stopAnimEmotes()
_disconnectAll()
onAnimCharacterAdded(char)
task.wait(0.3)
task.spawn(function()
local _ewTimeout = 0
while not checkEmotesMenuExists() do
task.wait(0.1)
_ewTimeout = _ewTimeout + 0.1
if _ewTimeout > 15 then return end
end
task.wait(0.3); stopAnimEmotes()
if createGUIElements() then
if #emotesData > 0 then updatePageDisplay(); updateEmotes(); loadSpeedEmoteConfig() end
end
end)
end))
local _hbAcc, _stAcc = 0, 0
local _hbConn = AnimRunService.Heartbeat:Connect(function(dt)
if not _tlAlive() then return end
_hbAcc = _hbAcc + dt
if _hbAcc < 0.1 then return end
_hbAcc = 0
if not isGUICreated then
pcall(checkAndRecreateGUI)
if isGUICreated then _guiColorsDirty = true end
elseif _guiColorsDirty then
updateGUIColors()
end
end)
local _stConn = AnimRunService.Stepped:Connect(function(_, dt)
if not _tlAlive() then return end
_stAcc = _stAcc + dt
if _stAcc < 0.1 then return end
_stAcc = 0
if animHumanoid and animHumanoid.Parent and currentEmoteTrack and currentEmoteTrack.IsPlaying then
if animHumanoid.MoveDirection.Magnitude > 0 then
if speedEmoteEnabled and not emotesWalkEnabled then
currentEmoteTrack:Stop(); currentEmoteTrack = nil
end
end
end
end)
pcall(function()
if getgenv then
if not getgenv()._TLAnimConns then getgenv()._TLAnimConns = {} end
table.insert(_genv._TLAnimConns, _hbConn)
table.insert(_genv._TLAnimConns, _stConn)
end
end)
task.spawn(function()
local StarterGui = _SvcSG
while _G.EmotesGUIRunning and _tlAlive() do
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true) end)
local ok, ew = checkEmotesMenuExists()
if ok and ew then
if not ew:FindFirstChild("Under") or not ew:FindFirstChild("Top") then
pcall(createGUIElements); pcall(updateGUIColors); pcall(updatePageDisplay)
pcall(function() loadFavorites(); loadFavoritesAnimations(); rebuildFavSet() end)
pcall(loadSpeedEmoteConfig)
end
end
task.wait(2.0)
end
end)
task.spawn(function()
pcall(function()
_SvcSG:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
end)
local _ewTimeout2 = 0
while not checkEmotesMenuExists() do
task.wait(0.2)
_ewTimeout2 = _ewTimeout2 + 0.2
if _ewTimeout2 > 15 then break end
end
if createGUIElements() then
loadFavorites(); loadFavoritesAnimations(); rebuildFavSet()
task.delay(1.5, function()
if not _tlAlive() then return end
if #originalEmotesData == 0 and not isLoadingEmotes then
fetchAllEmotes()
end
end)
loadSpeedEmoteConfig()
end
end)
if AnimUIS.KeyboardEnabled then
animNotif("Animations-Menu", '🎬 Emote Menu: Press "."', 5)
end
end)
;(function()
local _TL_refs = {}  -- shared refs table: upvalue-safe across all nested IIFEs
local Players; pcall(function() Players = _SvcPlr end)
if not Players then Players = _SvcPlr end
local UserInputService; pcall(function() UserInputService = _SvcUIS end)
if not UserInputService then
UserInputService = {
InputBegan = {Connect = function(_, fn) return {Disconnect=function() end} end},
InputChanged = {Connect = function(_, fn) return {Disconnect=function() end} end},
IsKeyDown = function() return false end,
IsMouseButtonPressed = function() return false end,
GetMouseLocation = function() return Vector2.new(0,0) end,
KeyboardEnabled = false,
}
end
local _C3_WHITE            = Color3.fromRGB(255,255,255)
local _C3_BG3              = Color3.fromRGB(26, 26, 28)    -- neutral (UI-Fallback)
local _C3_BG2              = Color3.fromRGB(18, 18, 20)
local _C3_SUB2             = Color3.fromRGB(85, 88, 95)   -- Knob OFF (neutral grau)
local _C3_SUB              = Color3.fromRGB(130, 135, 145)
local _C3_BG4              = Color3.fromRGB(22, 22, 24)
local _C3_TEXT2            = Color3.fromRGB(220, 222, 228)
local _C3_BLACK            = Color3.fromRGB(0,0,0)
local _C3_LGRAY            = Color3.fromRGB(200, 202, 210)
local _C3_TEXT3            = Color3.fromRGB(210, 212, 218)
local _C3_DRED             = Color3.fromRGB(255, 60,  60)  -- bleibt rot
local _C3_MGRAY            = Color3.fromRGB(120, 122, 130)
local _C3_RED              = Color3.fromRGB(255,80,80)
local _C3_ORANGE           = Color3.fromRGB(255,140,40)
local _C3_GREEN            = Color3.fromRGB(80,255,120)
local TweenService; pcall(function() TweenService = game:GetService("TweenService") end)
local RunService; pcall(function() RunService = _SvcRS end)
if not TweenService then
TweenService = {
Create = function(obj, info, props)
return {
Play = function()
pcall(function()
for k, v in pairs(props) do pcall(function() obj[k] = v end) end
end)
end,
Cancel = function() end,
Completed = {Connect = function(_, fn) return {Disconnect=function() end} end},
}
end
}
end
if not RunService then
RunService = {
Heartbeat  = {Connect = function(_, fn) return {Disconnect=function() end} end},
Stepped    = {Connect = function(_, fn) return {Disconnect=function() end} end},
RenderStepped = {Connect = function(_, fn) return {Disconnect=function() end} end},
PreSimulation = {Connect = function(_, fn) return {Disconnect=function() end} end},
PreRender  = {Connect = function(_, fn) return {Disconnect=function() end} end},
}
end
-- Some sandboxes omit Enum.SortOrder; UIListLayout still accepts ordinal 2 for LayoutOrder.
local _ENUM_SORT_ORDER_LAYOUT
pcall(function() _ENUM_SORT_ORDER_LAYOUT = Enum.SortOrder.LayoutOrder end)
if _ENUM_SORT_ORDER_LAYOUT == nil then _ENUM_SORT_ORDER_LAYOUT = 2 end
local Stats; pcall(function() Stats = game:GetService("Stats") end)
local CoreGui; pcall(function() CoreGui = game:GetService("CoreGui") end)
local GroupService; pcall(function() GroupService = game:GetService("GroupService") end)
local LocalPlayer, PlayerGui = Players.LocalPlayer, nil
pcall(function() PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10) end)
if not PlayerGui then PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") end
local Character = LocalPlayer.Character
if not Character then
local charConn, charDone
charConn = LocalPlayer.CharacterAdded:Connect(function(c)
Character = c
charDone = true
if charConn then pcall(function() charConn:Disconnect() end) end
end)
local t = 0
while not charDone and t < 8 do
task.wait(0.1); t = t + 0.1
end
if charConn then pcall(function() charConn:Disconnect() end) end
if not Character then Character = LocalPlayer.Character end
end
local noclipConn, noclipCachedParts, noclipOrigCollide = nil, {}, {}
function noclipRebuildCache(ch)
noclipCachedParts = {}
if not ch then return end
for _, part in ipairs(ch:GetDescendants()) do
if part:IsA("BasePart") then
table.insert(noclipCachedParts, part)
end
end
end
LocalPlayer.CharacterAdded:Connect(function(c)
Character = c
if noclipConn then noclipRebuildCache(c) end
end)
local function getHumanoid()
local c = Character
return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRootPart()
local c = Character
return c and c:FindFirstChild("HumanoidRootPart")
end
function safeStand()
if flyActive then return end
local myChar = LocalPlayer.Character
if not myChar then return end
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then return end
hrp.AssemblyLinearVelocity  = Vector3.zero
pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end)
hum.PlatformStand = false
pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
hum.WalkSpeed = 16
end
local C = {
-- -- Start: Cyber (blue) – Matrix-Grün nur mit Theme "matrix" --
bg        = Color3.fromRGB(10, 10, 10),
bg2       = Color3.fromRGB(20, 20, 20),
bg3       = Color3.fromRGB(28, 28, 28),
bghov     = Color3.fromRGB(18, 20, 26),
border    = Color3.fromRGB(0, 200, 255),
borderdim = Color3.fromRGB(0, 40, 85),
accent    = Color3.fromRGB(0, 200, 255),
accent2   = Color3.fromRGB(0, 160, 220),
green     = Color3.fromRGB(0, 200, 255),
red       = Color3.fromRGB(255, 60, 90),
orange    = Color3.fromRGB(255,155, 45),
text      = Color3.fromRGB(210, 235, 255),
sub       = Color3.fromRGB(0, 135, 195),
gradL     = Color3.fromRGB(0, 200, 255),
gradR     = Color3.fromRGB(0, 160, 220),
panelBg   = Color3.fromRGB(10, 10, 10),
panelHdr  = Color3.fromRGB(20, 20, 20),
}
if _genv then _genv.C = C end

-- ══════════════════════════════════════════════
--  UI UTILITIES (Standardized)
-- ══════════════════════════════════════════════
local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, a, b, c)
    return _makeDummyStroke(parent)
end

local function gradient(parent, rotation, c1, c2)
    local g = Instance.new("UIGradient")
    g.Rotation = rotation or 0
    g.Color = ColorSequence.new(c1 or Color3.new(1,1,1), c2 or c1 or Color3.new(1,1,1))
    g.Parent = parent
    return g
end

local function applyTextStyle(obj, minSize)
    if not obj then return end
    obj.Font = Enum.Font.GothamBold
    if minSize then obj.TextSize = math.max(obj.TextSize, minSize) end
    obj.TextColor3 = C.text or Color3.new(1,1,1)
    obj.TextTransparency = 0
    obj.TextStrokeTransparency = 1
end

local function stylePanelSurface(frame, r, trans)
    frame.BackgroundColor3 = C.panelBg or Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = trans or 0.1
    frame.BorderSizePixel = 0
    corner(frame, r or 10)
    stroke(frame, 1.2, C.bg3 or Color3.fromRGB(45, 45, 45), 0.2)
end

local function styleSurface(frame, radius, fillA, fillB, strokeColor, strokeThickness)
    frame.BorderSizePixel  = 0
    frame.ClipsDescendants = true
    corner(frame, radius or 10)
    local outline = stroke(frame, strokeThickness or 1, strokeColor or C.border or Color3.new(1,1,1), 0.1)
    gradient(frame, 90, fillA or C.bg2 or Color3.new(0,0,0), fillB or C.bg or Color3.new(0,0,0))
    return outline
end

local function styleThumbSurface(frame, radius)
    frame.BorderSizePixel  = 0
    frame.ClipsDescendants = true
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
    corner(frame, radius or 8)
    return stroke(frame, 1, C.bg3 or Color3.fromRGB(45, 45, 45), 0.28)
end

-- ----------------------------------------------------------------
-- COLOR THEMES
-- ----------------------------------------------------------------
local _TL_THEMES = {
    { id="matrix",  name="Matrix",   accent=C.accent or Color3.fromRGB(0, 200, 255),  accent2=C.accent or Color3.fromRGB(0, 200, 255),   sub=C.accent or Color3.fromRGB(0, 200, 255),   borderdim=C.bg or Color3.fromRGB(15, 15, 20),   text=Color3.fromRGB(210,255,220), panelBg=Color3.fromRGB(1,8,3), panelHdr=Color3.fromRGB(2,12,5) },
    { id="blue",    name="Cyber",    accent=Color3.fromRGB(0,200,255), accent2=Color3.fromRGB(0,160,220),  sub=Color3.fromRGB(0,135,195),  borderdim=Color3.fromRGB(0,40,85),   text=Color3.fromRGB(210,235,255) },
    { id="purple",  name="Neon",     accent=Color3.fromRGB(190,80,255),accent2=Color3.fromRGB(160,55,220), sub=Color3.fromRGB(140,45,195), borderdim=Color3.fromRGB(55,10,85),  text=Color3.fromRGB(240,220,255) },
    { id="red",     name="Crimson",  accent=Color3.fromRGB(255,55,80), accent2=Color3.fromRGB(220,40,60),  sub=Color3.fromRGB(195,30,50),  borderdim=Color3.fromRGB(80,10,20),  text=Color3.fromRGB(255,220,225) },
    { id="gold",    name="Gold",     accent=Color3.fromRGB(255,200,0), accent2=Color3.fromRGB(220,168,0),  sub=Color3.fromRGB(195,148,0),  borderdim=Color3.fromRGB(80,58,0),   text=Color3.fromRGB(255,245,210) },
    { id="cyan",    name="Ice",      accent=Color3.fromRGB(0,255,200), accent2=Color3.fromRGB(0,218,168),  sub=Color3.fromRGB(0,188,148),  borderdim=C.bg or Color3.fromRGB(15, 15, 20),   text=Color3.fromRGB(210,255,248), panelBg=Color3.fromRGB(15, 15, 20), panelHdr=Color3.fromRGB(20, 20, 22) },
    { id="rose",    name="Rose",     accent=Color3.fromRGB(255,100,160),accent2=Color3.fromRGB(220,75,130),sub=Color3.fromRGB(195,55,110), borderdim=Color3.fromRGB(80,15,40),  text=Color3.fromRGB(255,225,235) },
    { id="orange",  name="Blaze",    accent=Color3.fromRGB(255,130,0), accent2=Color3.fromRGB(220,105,0),  sub=Color3.fromRGB(195,88,0),   borderdim=Color3.fromRGB(80,38,0),   text=Color3.fromRGB(255,238,215) },
    { id="lime",    name="Toxic",    accent=Color3.fromRGB(150,255,0), accent2=Color3.fromRGB(118,215,0),  sub=Color3.fromRGB(100,185,0),  borderdim=Color3.fromRGB(38,70,0),   text=Color3.fromRGB(230,255,205) },
    { id="white",   name="Ghost",    accent=Color3.fromRGB(220,225,235),accent2=Color3.fromRGB(185,190,200),sub=Color3.fromRGB(160,165,175),borderdim=Color3.fromRGB(60,62,70),  text=Color3.fromRGB(240,242,248), panelBg=Color3.fromRGB(15, 15, 18), panelHdr=Color3.fromRGB(20, 20, 22) },
    { id="teal",    name="Teal",     accent=Color3.fromRGB(0,210,185), accent2=Color3.fromRGB(0,175,155),  sub=Color3.fromRGB(0,150,135),  borderdim=C.bg or Color3.fromRGB(15, 15, 20),   text=Color3.fromRGB(210,252,248) },
    { id="indigo",  name="Void",     accent=Color3.fromRGB(100,120,255),accent2=Color3.fromRGB(75,95,220), sub=Color3.fromRGB(58,75,195),  borderdim=Color3.fromRGB(18,22,80),  text=Color3.fromRGB(225,228,255) },
    { id="peach",   name="Peach",    accent=Color3.fromRGB(255,175,100),accent2=Color3.fromRGB(220,145,75),sub=Color3.fromRGB(195,122,58), borderdim=Color3.fromRGB(80,45,15),  text=Color3.fromRGB(255,242,228) },
    { id="mint",    name="Mint",     accent=Color3.fromRGB(80,255,185), accent2=Color3.fromRGB(58,215,152),sub=Color3.fromRGB(42,185,130), borderdim=Color3.fromRGB(10,68,45),  text=Color3.fromRGB(215,255,242) },
}
local _TL_activeThemeId = "blue"
local _TL_lastRenderedThemeId = _TL_activeThemeId
-- Bei Re-inject: gespeichertes Theme aus vorheriger Session übernehmen
-- damit oldT in _TL_applyTheme korrekt aufgelöst wird
pcall(function()
    local cachedTheme = _loadCache("theme")
    if cachedTheme and cachedTheme.id then
        _TL_activeThemeId = cachedTheme.id
    elseif getgenv and getgenv()._TL_savedTheme then
        _TL_activeThemeId = _genv._TL_savedTheme
    end
end)
local function _TL_applyTheme(themeId, paletteOnly)
    -- -- 1. Resolve themes ---------------------------------------
    local newT = nil
    for _, t in ipairs(_TL_THEMES) do if t.id == themeId  then newT = t; break end end
    if not newT then return end
    local oldT = nil
    for _, t in ipairs(_TL_THEMES) do if t.id == _TL_lastRenderedThemeId then oldT = t; break end end
    if not oldT then oldT = _TL_THEMES[1] end

    -- -- 2. Color remap helper -----------------------------------
    local function close(a, b, tol)  -- tol in 0-1 per channel
        return math.abs(a.R-b.R)<tol and math.abs(a.G-b.G)<tol and math.abs(a.B-b.B)<tol
    end
    -- Explicit anchor colors from BOTH old theme AND current C (handles accumulated mutations)
    -- Also include hardcoded Matrix green shades used in panels/widgets that bypass C palette
    local _HC_MG    = C.accent   -- P_MG / MG / MG_B
    local _HC_MGA   = C.accent or Color3.fromRGB(0, 200, 255)   -- P_MGA
    local _HC_MGA2  = C.accent or Color3.fromRGB(0, 200, 255)   -- MKEY / widget accent (0,200,55)
    local _HC_MGDIM = C.accent or Color3.fromRGB(0, 200, 255)   -- P_MGDIM / sub
    local _HC_MGLOW = Color3.fromRGB(30, 255, 90)  -- MGLOW
    local _HC_FW    = C.accent or Color3.fromRGB(0, 200, 255)   -- fwStroke / gb widgets
    local anchors = {
        {oldT.accent,    newT.accent},
        {oldT.accent2,   newT.accent2},
        {oldT.sub,       newT.sub},
        {oldT.borderdim, newT.borderdim},
        {oldT.text,      newT.text},
        {oldT.panelBg or Color3.fromRGB(10, 10, 10),  newT.panelBg or Color3.fromRGB(10, 10, 10)},
        {oldT.panelHdr or Color3.fromRGB(20, 20, 20), newT.panelHdr or Color3.fromRGB(20, 20, 20)},
        {C.accent,       newT.accent},
        {C.accent2,      newT.accent2},
        {C.sub,          newT.sub},
        {C.borderdim,    newT.borderdim},
        {C.text,         newT.text},
        {C.green,        newT.accent},
        {C.gradL,        newT.accent},
        {C.gradR,        newT.accent2},
        {C.border,       newT.accent},
        {C.panelBg,      newT.panelBg or Color3.fromRGB(10, 10, 10)},
        {C.panelHdr,     newT.panelHdr or Color3.fromRGB(20, 20, 20)},
        {C.bg,           newT.panelBg or Color3.fromRGB(10, 10, 10)},
        {C.bg2,          newT.panelHdr or Color3.fromRGB(20, 20, 20)},
        -- Hardcoded Matrix greens (panels, GB/Rush/Fling widgets, aim lines)
        {_HC_MG,    newT.accent},
        {_HC_MGA,   newT.accent2},
        {_HC_MGA2,  newT.accent2},
        {_HC_MGDIM, newT.sub},
        {_HC_MGLOW, newT.accent},
        {_HC_FW,    newT.accent2},
    }
    local function remapColor(col)
        -- Exact / near-exact anchor match (strict tolerance to prevent UI mutation bleeding)
        for _, a in ipairs(anchors) do
            if close(col, a[1], 0.015) then return a[2] end
        end
        return nil
    end

    -- -- 3. Update C palette -------------------------------------
    C.accent    = newT.accent
    C.accent2   = newT.accent2
    C.sub       = newT.sub
    C.borderdim = newT.borderdim
    C.text      = newT.text
    C.green     = newT.accent
    C.gradL     = newT.accent
    C.gradR     = newT.accent2
    C.border    = newT.accent
    C.panelBg   = newT.panelBg or C.bg
    C.panelHdr  = newT.panelHdr or C.bg2
    _TL_activeThemeId = themeId
    -- Sync P_MG* panel palette vars and MG_B tab bar color
    pcall(function()
        if _panelColorHooks then
            for _, fn in ipairs(_panelColorHooks) do pcall(fn, newT) end
        end
    end)
    if paletteOnly then
        pcall(function()
            if getgenv then _genv._TL_savedTheme = themeId end
        end)
        return
    end
    -- MG_B/MGA_B/MGDIM are now functions reading C.* directly

    -- -- 4. Scan & recolor all GUI descendants -------------------
    local sg = nil
    pcall(function() sg = _TL_refs and _TL_refs._TL_ScreenGui end)
    if not sg then pcall(function() sg = ScreenGui end) end
    if not sg or not sg.Parent then return end

    for _, d in ipairs(sg:GetDescendants()) do
        pcall(function()
            local cn = d.ClassName
            if cn == "UIStroke" then
                local n = remapColor(d.Color); if n then d.Color = n end
            elseif cn == "Frame" or cn == "ScrollingFrame" then
                if d.BackgroundTransparency < 0.99 then
                    local n = remapColor(d.BackgroundColor3); if n then d.BackgroundColor3 = n end
                end
            elseif cn == "TextLabel" or cn == "TextButton" or cn == "TextBox" then
                local nt = remapColor(d.TextColor3);      if nt then d.TextColor3 = nt end
                if d.BackgroundTransparency < 0.99 then
                    local nb = remapColor(d.BackgroundColor3); if nb then d.BackgroundColor3 = nb end
                end
            -- ImageLabel/ImageButton werden bewusst NICHT umgefärbt (Icons bleiben neutral)
            elseif cn == "UIGradient" then
                local kps = d.Color.Keypoints
                local changed, newKps = false, {}
                for _, kp in ipairs(kps) do
                    local n = remapColor(kp.Value)
                    if n then newKps[#newKps+1]=ColorSequenceKeypoint.new(kp.Time,n); changed=true
                    else       newKps[#newKps+1]=kp end
                end
                if changed then d.Color = ColorSequence.new(newKps) end
            end
        end)
    end

    -- -- 5. Persist ----------------------------------------------
    pcall(function()
        if writefile then
            local ok, cur = pcall(readfile, "SmartBar_Save.json")
            if ok and cur then
                if cur:find('"themeColor"') then
                    cur = cur:gsub('"themeColor"%s*:%s*"[^"]*"', '"themeColor": "'..themeId..'"')
                else
                    cur = cur:gsub('("settings"%s*:%s*{)', '%1\n    "themeColor": "'..themeId..'",')
                end
                pcall(writefile, "SmartBar_Save.json", cur)
            end
        end
        if getgenv then _genv._TL_savedTheme = themeId end
        _saveCache("theme", {id = themeId})
    end)
    
    -- -- 6. Restore hardcoded chip colors (immune to remapping) ------
    pcall(function()
        if _tlEnv._TL_FixThemeChips then
            _tlEnv._TL_FixThemeChips(themeId)
        end
    end)
    _TL_lastRenderedThemeId = themeId
end

local ScreenGui = _tlTrackInst(Instance.new("ScreenGui"))
ScreenGui.Name           = "SmartBarGui"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder   = 999
local function _tryParentGui(gui)
if gui.Parent and gui.Parent.Parent then return true end
-- gethui() ist der sichere Container für Solara und viele andere Executoren
if gethui then pcall(function() gui.Parent = gethui() end) end
if gui.Parent and gui.Parent.Parent then return true end
pcall(function() gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
if gui.Parent and gui.Parent.Parent then return true end
pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui", 3) end)
if gui.Parent and gui.Parent.Parent then return true end
if CoreGui then pcall(function() gui.Parent = CoreGui end) end
if gui.Parent and gui.Parent.Parent then return true end
pcall(function() gui.Parent = game.Players.LocalPlayer.PlayerGui end)
return gui.Parent ~= nil
end
_tryParentGui(ScreenGui)
pcall(function()
local TOOL_NAME  = "_TLMagnifier"
local SLOT_IMAGE = "rbxassetid://71807151037163"
local RS         = RunService or _SvcRS
local patched    = {}
local function patchSlot(slot)
if patched[slot] then return end
patched[slot] = true
for _, d in ipairs(slot:GetDescendants()) do
pcall(function()
if d:IsA("TextLabel") or d:IsA("TextButton") then
d.Text                   = ""
d.TextTransparency       = 1
d.TextStrokeTransparency = 1
d.BackgroundTransparency = 1
end
if d:IsA("Frame") then
d.BackgroundTransparency = 1
d.BorderSizePixel        = 0
end
if d:IsA("ImageLabel") or d:IsA("ImageButton") then
if d.Name ~= "_TLInvImg" then
d.BackgroundTransparency = 1
d.ImageTransparency      = 1
d.BorderSizePixel        = 0
end
end
end)
end
pcall(function()
slot.BackgroundTransparency = 1
slot.BorderSizePixel        = 0
if slot:IsA("ImageButton") or slot:IsA("ImageLabel") then
slot.ImageTransparency = 1
end
end)
if not slot:FindFirstChild("_TLInvImg") then
local img = Instance.new("ImageLabel")
img.Name                   = "_TLInvImg"
img.Size                   = UDim2.new(1, 0, 1, 0)
img.Position               = UDim2.new(0, 0, 0, 0)
img.BackgroundTransparency = 1
img.BorderSizePixel        = 0
img.Image                  = SLOT_IMAGE
img.ScaleType              = Enum.ScaleType.Fit
img.ZIndex                 = 20
img.Parent                 = slot
end
end
local function scanBackpack()
if not ((Players.LocalPlayer.Backpack and Players.LocalPlayer.Backpack:FindFirstChild(TOOL_NAME))
or (Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild(TOOL_NAME))) then
return
end
local cg = game:GetService("CoreGui")
local rg = cg:FindFirstChild("RobloxGui"); if not rg then return end
local bg = rg:FindFirstChild("BackpackGui"); if not bg then return end
for _, d in ipairs(bg:GetDescendants()) do
local isToolLabel = d:IsA("TextLabel") and
(d.Text == TOOL_NAME or d.Text == "TL Magnifyer" or d.Text == "TL Magnifier")
local isToolFrame = d:IsA("Frame") and d.Name == TOOL_NAME
if isToolLabel or isToolFrame then
local slot = d.Parent
while slot and not (slot:IsA("Frame") or slot:IsA("ImageButton")) do
slot = slot.Parent
end
if slot then patchSlot(slot) end
end
end
end
local t = 0
local conn
conn = _tlTrackConn(RS.Heartbeat:Connect(function(dt)
t = t + dt
if t < 0.5 then return end
t = 0
pcall(scanBackpack)
end))
local charResetConn = _tlTrackConn(Players.LocalPlayer.CharacterAdded:Connect(function()
task.wait(1)
patched = {}
t = 0
end))
pcall(function()
if getgenv then
_genv._TLInvPatchCleanup = function()
pcall(function() if conn then conn:Disconnect() end end)
pcall(function() if charResetConn then charResetConn:Disconnect() end end)
conn, charResetConn = nil, nil
patched = {}
end
end
end)
end)
pcall(function()
local RS      = RunService or _SvcRS
local UIS     = UserInputService or _SvcUIS
local PG = Players.LocalPlayer:FindFirstChild("PlayerGui")
or Players.LocalPlayer:WaitForChild("PlayerGui", 8)
if not PG then return end
local HIGHLIGHT_RED = Color3.fromRGB(255, 0, 0)
local cards   = {}
local outlines = {}
local function setOutline(p, on)
if outlines[p] then
pcall(function() outlines[p]:Destroy() end)
outlines[p] = nil
end
if on and p.Character then
pcall(function()
local hl = Instance.new("Highlight")
hl.Adornee             = p.Character
hl.FillTransparency    = 1
hl.OutlineColor        = HIGHLIGHT_RED
hl.OutlineTransparency = 1
hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
hl.Parent              = workspace
outlines[p] = hl
end)
end
end
local function openCard(p)
if cards[p] then return end
if not p or not p.Character then return end

-- -- Palette (Modernized) -------------
local MG    = C.accent or C.accent or Color3.fromRGB(0, 200, 255)
local MGA   = C.sub or Color3.fromRGB(150, 150, 150)
local MGLOW = C.text or Color3.fromRGB(255, 255, 255)
local MDARK = C.bg2 or _C3_BG2 or Color3.fromRGB(15, 15, 15)
local MHDR  = C.bg or _C3_BG or Color3.fromRGB(20, 20, 20)
local MKEY  = C.sub or Color3.fromRGB(150, 150, 150)
local MVAL  = C.text or Color3.fromRGB(220, 220, 220)
local MSEP  = C.sub or Color3.fromRGB(120, 120, 120)

local PW, PH = 258, 360

-- -- ScreenGui ----------------------------------------
local bb = Instance.new("ScreenGui")
bb.Name = "_TLHolo_"..p.Name
bb.ResetOnSpawn = false
bb.IgnoreGuiInset = true
bb.DisplayOrder = 9999
_tryParentGui(bb)

-- -- Mobile/Tablet responsive scaling -----------------
local _isMobile, _isTablet, _uiScale = false, false, 1.0
pcall(function()
    local vp    = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
    local touch = UIS.TouchEnabled
    local kbd   = UIS.KeyboardEnabled
    local short = math.min(vp.X, vp.Y)
    _isMobile = touch and not kbd and short < 500
    _isTablet = touch and not kbd and short >= 500 and short < 900
    if _isMobile then
        _uiScale = math.clamp((short * 0.85) / PW, 0.55, 1.1)
    elseif _isTablet then
        _uiScale = math.clamp((short * 0.55) / PW, 0.75, 1.15)
    elseif vp.X < 1000 then
        _uiScale = math.clamp(vp.X / 1280, 0.75, 1.0)
    end
end)

-- -- Root (right-anchored, vertically centered) -------
local root = Instance.new("Frame", bb)
root.Size        = UDim2.new(0, PW, 0, PH)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
if _isMobile or _isTablet then
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position    = UDim2.new(0.5, 0, 0.5, 0)
else
    root.AnchorPoint = Vector2.new(1, 0.5)
    root.Position    = UDim2.new(1, -16, 0.5, 0)
end
local _uiScaleInst = Instance.new("UIScale", root)
_uiScaleInst.Scale = _uiScale

-- DropShadow (Modern Glassmorphism Style)
local ds = Instance.new("ImageLabel", root)
ds.Name = "DropShadow"
ds.BackgroundTransparency = 1
ds.Position = UDim2.new(0, -7, 0, -5)
ds.Size = UDim2.new(1, 14, 1, 14)
ds.ZIndex = 0
ds.Image = "rbxassetid://1316045217"
ds.ImageColor3 = Color3.fromRGB(0, 0, 0)
ds.ImageTransparency = 0.6
ds.ScaleType = Enum.ScaleType.Slice
ds.SliceCenter = Rect.new(15, 15, 113, 113)
Instance.new("UICorner", ds).CornerRadius = UDim.new(0, 16)

-- -- Background panel ---------------------------------
local bg = Instance.new("Frame", root)
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = MDARK
bg.BackgroundTransparency = 0
bg.BorderSizePixel = 0; bg.ZIndex = 1
bg.ClipsDescendants = true
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)

-- sleek static border instead of matrix pulse
local mainStroke = _makeDummyStroke(bg)
mainStroke.Color = C.bg3 or Color3.fromRGB(50, 50, 50)
mainStroke.Thickness = 1
mainStroke.Transparency = 0.28
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- -- Header --------------------------------------------
local hdr = Instance.new("Frame", bg)
hdr.Size     = UDim2.new(1, 0, 0, 56)
hdr.Position = UDim2.new(0, 0, 0, 0)
hdr.BackgroundColor3 = MHDR; hdr.BackgroundTransparency = 0
hdr.BorderSizePixel = 0; hdr.ZIndex = 3
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)

-- header bottom separator
local hdrSep = Instance.new("Frame", bg)
hdrSep.Size     = UDim2.new(1, 0, 0, 1)
hdrSep.Position = UDim2.new(0, 0, 0, 56)
hdrSep.BackgroundColor3 = C.bg3 or Color3.fromRGB(50, 50, 50)
hdrSep.BackgroundTransparency = 0.5
hdrSep.BorderSizePixel = 0; hdrSep.ZIndex = 3

-- LIVE label (top:8px; right:28px)
local statusLbl = Instance.new("TextLabel", bg)
statusLbl.Size     = UDim2.new(0, 44, 0, 10)
statusLbl.Position = UDim2.new(1, -58, 0, 10)
statusLbl.BackgroundTransparency = 1; statusLbl.Text = "ONLINE"
statusLbl.TextColor3 = MG; statusLbl.Font = Enum.Font.GothamBold
statusLbl.TextSize = 9; statusLbl.TextXAlignment = Enum.TextXAlignment.Right; statusLbl.ZIndex = 5

-- blinking dot (top:8px; right:12px; 6x6)
local statusDot = Instance.new("Frame", bg)
statusDot.Size     = UDim2.new(0, 6, 0, 6)
statusDot.Position = UDim2.new(1, -12, 0, 12)
statusDot.BackgroundColor3 = MG; statusDot.BorderSizePixel = 0; statusDot.ZIndex = 5
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

-- Avatar circle
local ava = Instance.new("Frame", hdr)
ava.Size = UDim2.new(0, 38, 0, 38); ava.Position = UDim2.new(0, 10, 0.5, -19)
ava.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ava.BackgroundTransparency = 0.5; ava.BorderSizePixel = 0; ava.ZIndex = 3
Instance.new("UICorner", ava).CornerRadius = UDim.new(1, 0)
local avaSt = _makeDummyStroke(ava)
avaSt.Color = C.bg3 or Color3.fromRGB(50, 50, 50); avaSt.Thickness = 1.5; avaSt.Transparency = 0
avaSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
-- avatar image
local avaImg = Instance.new("ImageLabel", ava)
avaImg.Size = UDim2.new(1, 0, 1, 0); avaImg.BackgroundTransparency = 1
avaImg.Image = ""; avaImg.ScaleType = Enum.ScaleType.Crop; avaImg.ZIndex = 4
Instance.new("UICorner", avaImg).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    pcall(function()
        local img = Players:GetUserThumbnailAsync(p.UserId,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        if avaImg.Parent then avaImg.Image = img end
    end)
end)

-- player name
local nm = Instance.new("TextLabel", hdr)
nm.Size = UDim2.new(1, -115, 0, 18); nm.Position = UDim2.new(0, 58, 0, 10)
nm.BackgroundTransparency = 1; nm.Text = p.Name
nm.TextColor3 = MGLOW; nm.Font = Enum.Font.GothamBlack
nm.TextSize = 13; nm.TextXAlignment = Enum.TextXAlignment.Left
nm.TextTruncate = Enum.TextTruncate.AtEnd; nm.ZIndex = 3

-- display name
local nmSub = Instance.new("TextLabel", hdr)
nmSub.Size = UDim2.new(1, -115, 0, 13); nmSub.Position = UDim2.new(0, 58, 0, 30)
nmSub.BackgroundTransparency = 1
nmSub.Text = "@"..(p.DisplayName or p.Name)
nmSub.TextColor3 = MGA; nmSub.Font = Enum.Font.GothamBold
nmSub.TextSize = 11; nmSub.TextXAlignment = Enum.TextXAlignment.Left
nmSub.TextTruncate = Enum.TextTruncate.AtEnd; nmSub.ZIndex = 3

-- -- Scroll frame -------------------------------------
local sf = Instance.new("ScrollingFrame", bg)
sf.Size     = UDim2.new(1, -4, 1, -124)
sf.Position = UDim2.new(0, 2, 0, 60)
sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
sf.ScrollBarThickness = 2; sf.ScrollBarImageColor3 = C.bg3 or Color3.fromRGB(50, 50, 50)
sf.ScrollBarImageTransparency = 0
sf.CanvasSize = UDim2.new(0, 0, 0, 0)
sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
sf.ElasticBehavior = Enum.ElasticBehavior.Never
sf.ScrollingDirection = Enum.ScrollingDirection.Y; sf.ZIndex = 3

local ll = Instance.new("UIListLayout", sf)
ll.SortOrder = _ENUM_SORT_ORDER_LAYOUT; ll.Padding = UDim.new(0, 2)

local sfPad = Instance.new("UIPadding", sf)
sfPad.PaddingLeft   = UDim.new(0, 8)
sfPad.PaddingRight  = UDim.new(0, 8)
sfPad.PaddingTop    = UDim.new(0, 8)
sfPad.PaddingBottom = UDim.new(0, 8)

-- -- Row builder --------------------------------------
local ord = 0
local function mkRow(key, val)
    ord = ord + 1
    local f = Instance.new("Frame", sf)
    f.Size = UDim2.new(1, 0, 0, 24); f.LayoutOrder = ord
    f.BackgroundColor3 = C.bg3 or Color3.fromRGB(30, 30, 30)
    f.BackgroundTransparency = (ord % 2 == 1) and 0.5 or 0.8
    f.BorderSizePixel = 0; f.ZIndex = 4
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local k = Instance.new("TextLabel", f)
    k.Size = UDim2.new(0, 82, 1, 0); k.Position = UDim2.new(0, 10, 0, 0)
    k.BackgroundTransparency = 1; k.Text = tostring(key or "")
    k.TextColor3 = MKEY; k.Font = Enum.Font.GothamBold
    k.TextSize = 11; k.TextXAlignment = Enum.TextXAlignment.Left; k.ZIndex = 5

    local v = Instance.new("TextLabel", f)
    v.Size = UDim2.new(1, -96, 1, 0); v.Position = UDim2.new(0, 96, 0, 0)
    v.BackgroundTransparency = 1; v.Text = tostring(val ~= nil and val or "?")
    v.TextColor3 = MVAL; v.Font = Enum.Font.Gotham
    v.TextSize = 11; v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextTruncate = Enum.TextTruncate.AtEnd; v.ZIndex = 5
    return v
end

local function mkSec(title)
    ord = ord + 1
    local f = Instance.new("Frame", sf)
    f.Size = UDim2.new(1, 0, 0, 22); f.LayoutOrder = ord
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.ZIndex = 4

    local lb = Instance.new("TextLabel", f)
    lb.Size = UDim2.new(1, 0, 1, 0); lb.Position = UDim2.new(0, 4, 0, 4)
    lb.BackgroundTransparency = 1; lb.Text = string.upper(tostring(title or ""))
    lb.TextColor3 = MSEP; lb.Font = Enum.Font.GothamBlack
    lb.TextSize = 10; lb.TextXAlignment = Enum.TextXAlignment.Left; lb.ZIndex = 5
end

-- populate rows
mkRow("name",    p.Name)
mkRow("display", p.DisplayName)
mkRow("uid",     p.UserId)
mkRow("age",     tostring(p.AccountAge or "?").."d")
local mem = "false"
pcall(function() if p.MembershipType == Enum.MembershipType.Premium then mem = "true  ✅" end end)
mkRow("premium", mem)
local ping = "?"
pcall(function()
    ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()).."ms"
end)
mkRow("ping",  ping)
mkRow("team",  (p.Team and p.Team.Name) or "nil")
local hp, mhp = "?", "?"
pcall(function()
    local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    if h then hp = math.floor(h.Health); mhp = math.floor(h.MaxHealth) end
end)
mkRow("hp", hp ~= "?" and (hp.."/"..mhp) or "?")
mkSec("ACCOUNT")
local vJoin    = mkRow("joined",  "loading…")
local vAliases = mkRow("aliases", "loading…")
mkSec("SOCIAL")
local vFriends = mkRow("friends", "loading…")

-- async fetch
local _cachedNames = {}
task.spawn(function()
    local HS = game:GetService("HttpService")
    pcall(function()
        local d = HS:JSONDecode(game:HttpGet("https://users.roblox.com/v1/users/"..p.UserId))
        if d and d.created then
            local y, m, dd = d.created:match("(%d+)-(%d+)-(%d+)")
            if y and vJoin.Parent then vJoin.Text = dd.."."..m.."."..y end
        end
    end)
    pcall(function()
        local d = HS:JSONDecode(game:HttpGet(
            "https://users.roblox.com/v1/users/"..p.UserId.."/username-history?limit=10"))
        if d and d.data and #d.data > 0 then
            local ns = {}; for _, v in ipairs(d.data) do ns[#ns+1] = v.name end
            _cachedNames = ns
            if vAliases.Parent then vAliases.Text = table.concat(ns, ", ") end
        elseif vAliases.Parent then vAliases.Text = "none" end
    end)
    pcall(function()
        local d = HS:JSONDecode(game:HttpGet(
            "https://friends.roblox.com/v1/users/"..p.UserId.."/friends/count"))
        if d and d.count ~= nil and vFriends.Parent then vFriends.Text = tostring(d.count) end
    end)
end)

-- -- Footer --------------------------------------------
local footSep = Instance.new("Frame", bg)
footSep.Size     = UDim2.new(1, 0, 0, 1)
footSep.Position = UDim2.new(0, 0, 1, -46)
footSep.BackgroundColor3 = C.bg3 or Color3.fromRGB(50, 50, 50)
footSep.BackgroundTransparency = 0.5
footSep.BorderSizePixel = 0; footSep.ZIndex = 8

local addBtn = Instance.new("TextButton", bg)
addBtn.Size     = UDim2.new(0, 144, 0, 28)
addBtn.Position = UDim2.new(0, 8, 1, -38)
addBtn.BackgroundColor3 = C.bg3 or Color3.fromRGB(40, 40, 40)
addBtn.BackgroundTransparency = 0.5
addBtn.BorderSizePixel = 0
addBtn.Text = "ADD FRIEND"
addBtn.TextColor3 = C.text or Color3.fromRGB(240, 240, 240)
addBtn.Font = Enum.Font.GothamBold; addBtn.TextSize = 10
addBtn.ZIndex = 9; addBtn.Active = true
Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
local addSt = _makeDummyStroke(addBtn)
addSt.Color = C.sub or Color3.fromRGB(80, 80, 80); addSt.Thickness = 1; addSt.Transparency = 0.4
addSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

addBtn.MouseEnter:Connect(function()
    _playHoverSound()
    addBtn.BackgroundTransparency = 0.2; addBtn.BackgroundColor3 = C.accent or C.accent or Color3.fromRGB(0, 200, 255)
end)
addBtn.MouseLeave:Connect(function()
    addBtn.BackgroundTransparency = 0.5; addBtn.BackgroundColor3 = C.bg3 or Color3.fromRGB(40, 40, 40)
end)

addBtn.MouseButton1Click:Connect(function()
    if not addBtn.Active then return end
    addBtn.Text = "SENDING…"; addBtn.BackgroundTransparency = 0.4
    task.spawn(function()
        local ok = pcall(function()
            _SvcPlr.LocalPlayer:RequestFriendship(p)
        end)
        task.wait(0.5)
        if addBtn.Parent then
            addBtn.Text = ok and "✅ SENT" or "ALREADY FRIENDS"
            addBtn.BackgroundColor3 = ok and C.accent or Color3.fromRGB(55,55,55)
            addBtn.BackgroundTransparency = ok and 0.2 or 0.8; addBtn.Active = false
        end
    end)
end)
addBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        if not addBtn.Active then return end
        addBtn.Text = "SENDING…"; addBtn.BackgroundTransparency = 0.4
        task.spawn(function()
            local ok = pcall(function()
                _SvcPlr.LocalPlayer:RequestFriendship(p)
            end)
            task.wait(0.5)
            if addBtn.Parent then
                addBtn.Text = ok and "✅ SENT" or "ALREADY FRIENDS"
                addBtn.BackgroundColor3 = ok and C.accent or Color3.fromRGB(55,55,55)
                addBtn.BackgroundTransparency = ok and 0.2 or 0.8; addBtn.Active = false
            end
        end)
    end
end)

local namesBtn = Instance.new("TextButton", bg)
namesBtn.Size     = UDim2.new(1, -160, 0, 28)
namesBtn.Position = UDim2.new(0, 156, 1, -38)
namesBtn.BackgroundColor3 = C.bg3 or Color3.fromRGB(40, 40, 40)
namesBtn.BackgroundTransparency = 0.5
namesBtn.BorderSizePixel = 0
namesBtn.Text = "NAMES ◈"
namesBtn.TextColor3 = C.text or Color3.fromRGB(240, 240, 240)
namesBtn.Font = Enum.Font.GothamBold; namesBtn.TextSize = 10
namesBtn.ZIndex = 9; namesBtn.Active = true
Instance.new("UICorner", namesBtn).CornerRadius = UDim.new(0, 6)
local namesSt = _makeDummyStroke(namesBtn)
namesSt.Color = C.sub or Color3.fromRGB(80, 80, 80); namesSt.Thickness = 1; namesSt.Transparency = 0.4
namesSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

namesBtn.MouseEnter:Connect(function()
    _playHoverSound()
    namesBtn.BackgroundTransparency = 0.2; namesBtn.BackgroundColor3 = C.accent2 or Color3.fromRGB(0, 150, 255)
end)
namesBtn.MouseLeave:Connect(function()
    namesBtn.BackgroundTransparency = 0.5; namesBtn.BackgroundColor3 = C.bg3 or Color3.fromRGB(40, 40, 40)
end)

-- -- Names popup ---------------------------------------
-- HTML: .popup{width:160px; background:#020804; border:1.5px solid #00ff41; border-radius:8px}
-- positioned to the LEFT of the panel, aligned to top of header
local namesPopup = nil
local function _doNamesBtn()
    if namesPopup and namesPopup.Parent then
        namesPopup:Destroy(); namesPopup = nil
        namesBtn.Text = "[ NAMES ◈ ]"; return
    end
    namesBtn.Text = "[ NAMES ◈ ]"

    local POP_W = 160
    local pop = Instance.new("Frame", root)
    pop.Name = "_NamesPopup"
    pop.AnchorPoint = Vector2.new(1, 0)
    pop.Position    = UDim2.new(0, -8, 0, 0)
    pop.Size        = UDim2.new(0, POP_W, 0, 40)
    pop.BackgroundColor3 = C.bg2 or Color3.fromRGB(15, 15, 15)
    pop.BackgroundTransparency = 0
    pop.BorderSizePixel = 0; pop.ZIndex = 20
    pop.ClipsDescendants = true
    Instance.new("UICorner", pop).CornerRadius = UDim.new(0, 8)
    local popSt = _makeDummyStroke(pop)
    popSt.Color = C.bg3 or Color3.fromRGB(50, 50, 50); popSt.Thickness = 1; popSt.Transparency = 0.28
    popSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local popHdr = Instance.new("Frame", pop)
    popHdr.Size = UDim2.new(1, 0, 0, 30)
    popHdr.BackgroundColor3 = C.bg or Color3.fromRGB(20, 20, 20)
    popHdr.BackgroundTransparency = 0
    popHdr.BorderSizePixel = 0; popHdr.ZIndex = 21
    Instance.new("UICorner", popHdr).CornerRadius = UDim.new(0, 8)

    local hdrLn = Instance.new("Frame", pop)
    hdrLn.Size = UDim2.new(1, 0, 0, 1); hdrLn.Position = UDim2.new(0, 0, 0, 30)
    hdrLn.BackgroundColor3 = C.bg3 or Color3.fromRGB(50, 50, 50); hdrLn.BackgroundTransparency = 0.5
    hdrLn.BorderSizePixel = 0; hdrLn.ZIndex = 22

    local popTit = Instance.new("TextLabel", popHdr)
    popTit.Size = UDim2.new(1, -26, 1, 0); popTit.Position = UDim2.new(0, 10, 0, 0)
    popTit.BackgroundTransparency = 1; popTit.Text = "PREVIOUS NAMES"
    popTit.TextColor3 = C.sub or Color3.fromRGB(150, 150, 150); popTit.Font = Enum.Font.GothamBold
    popTit.TextSize = 10; popTit.TextXAlignment = Enum.TextXAlignment.Left; popTit.ZIndex = 22

    local xBtn = Instance.new("TextButton", popHdr)
    xBtn.Size = UDim2.new(0, 24, 0, 24); xBtn.Position = UDim2.new(1, -28, 0.5, -12)
    xBtn.BackgroundTransparency = 1; xBtn.Text = "✕"
    xBtn.TextColor3 = C.text or Color3.fromRGB(255, 255, 255); xBtn.Font = Enum.Font.GothamBold; xBtn.TextSize = 16; xBtn.ZIndex = 23
    xBtn.MouseButton1Click:Connect(function()
        if namesPopup then namesPopup:Destroy(); namesPopup = nil end
        namesBtn.Text = "NAMES ◈"
    end)
    xBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            if namesPopup then namesPopup:Destroy(); namesPopup = nil end
            namesBtn.Text = "NAMES ◈"
        end
    end)

    local lf = Instance.new("Frame", pop)
    lf.Position = UDim2.new(0, 0, 0, 30)
    lf.Size = UDim2.new(1, 0, 0, 0)
    lf.BackgroundTransparency = 1; lf.BorderSizePixel = 0; lf.ZIndex = 21
    lf.AutomaticSize = Enum.AutomaticSize.Y
    local lfl = Instance.new("UIListLayout", lf)
    lfl.Padding = UDim.new(0, 2); lfl.SortOrder = _ENUM_SORT_ORDER_LAYOUT
    local lfp = Instance.new("UIPadding", lf)
    lfp.PaddingLeft = UDim.new(0, 8); lfp.PaddingRight = UDim.new(0, 8)
    lfp.PaddingTop = UDim.new(0, 6); lfp.PaddingBottom = UDim.new(0, 8)

    local function addNRow(idx, name)
        local rf = Instance.new("Frame", lf)
        rf.Size = UDim2.new(1, 0, 0, 22); rf.LayoutOrder = idx
        rf.BackgroundColor3 = C.bg3 or Color3.fromRGB(30, 30, 30)
        rf.BackgroundTransparency = (idx % 2 == 1) and 0.5 or 0.8
        rf.BorderSizePixel = 0; rf.ZIndex = 22
        Instance.new("UICorner", rf).CornerRadius = UDim.new(0, 4)

        local il = Instance.new("TextLabel", rf)
        il.Size = UDim2.new(0, 20, 1, 0); il.Position = UDim2.new(0, 4, 0, 0)
        il.BackgroundTransparency = 1; il.Text = tostring(idx)
        il.TextColor3 = C.sub or Color3.fromRGB(120, 120, 120); il.Font = Enum.Font.GothamBold; il.TextSize = 10; il.ZIndex = 23

        local nl = Instance.new("TextLabel", rf)
        nl.Size = UDim2.new(1, -28, 1, 0); nl.Position = UDim2.new(0, 24, 0, 0)
        nl.BackgroundTransparency = 1; nl.Text = name
        nl.TextColor3 = C.text or Color3.fromRGB(220, 220, 220); nl.Font = Enum.Font.Gotham; nl.TextSize = 11
        nl.TextXAlignment = Enum.TextXAlignment.Left
        nl.TextTruncate = Enum.TextTruncate.AtEnd; nl.ZIndex = 23
    end

    local function populate(ns)
        for _, c in ipairs(lf:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        local count = #ns > 0 and #ns or 1
        if #ns == 0 then addNRow(1, "none found")
        else for i, n in ipairs(ns) do addNRow(i, n) end end
        -- fixed height calc: no AbsoluteSize race condition
        local rows_h = count * 20
        local pad_h  = 4 + 8   -- top + bottom padding
        local totalH = math.clamp(27 + rows_h + pad_h, 50, 230)
        pop.Size = UDim2.new(0, POP_W, 0, totalH)
    end

    namesPopup = pop
    if #_cachedNames > 0 then
        populate(_cachedNames)
    else
        addNRow(1, "loading…")
        pop.Size = UDim2.new(0, POP_W, 0, 58)
        task.spawn(function()
            local ok, res = pcall(function()
                local HS2 = game:GetService("HttpService")
                local d = HS2:JSONDecode(game:HttpGet(
                    "https://users.roblox.com/v1/users/"..p.UserId.."/username-history?limit=10"))
                local ns = {}
                if d and d.data then for _, v in ipairs(d.data) do ns[#ns+1] = v.name end end
                return ns
            end)
            if ok and res then
                _cachedNames = res
                if namesPopup and namesPopup.Parent then populate(res) end
            end
        end)
    end
end
namesBtn.MouseButton1Click:Connect(_doNamesBtn)
namesBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then _doNamesBtn() end
end)

-- -- Scroll: native touch on mobile, mouse wheel on desktop ---
local scrollConn = nil
local mouseIn = false
sf.ScrollingEnabled = true
if _isMobile or _isTablet then
    -- touch: ScrollingFrame handles swipe natively
    scrollConn = nil
else
    scrollConn = UIS.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            if not bb.Parent then return end
            local ap = bg.AbsolutePosition; local as = bg.AbsoluteSize
            local mp = UIS:GetMouseLocation()
            mouseIn = mp.X>=ap.X and mp.X<=ap.X+as.X and mp.Y>=ap.Y and mp.Y<=ap.Y+as.Y
            return
        end
        if inp.UserInputType ~= Enum.UserInputType.MouseWheel or not mouseIn then return end
        local maxY = math.max(0, sf.AbsoluteCanvasSize.Y - sf.AbsoluteSize.Y)
        sf.CanvasPosition = Vector2.new(0,
            math.clamp(sf.CanvasPosition.Y - inp.Position.Z * 36, 0, maxY))
    end)
end

local respawnConn = p.CharacterAdded:Connect(function(c)
    task.wait(0.2)
    if outlines[p] then pcall(function() outlines[p].Adornee = c end) end
end)
cards[p] = { gui=bb, sc=scrollConn, resp=respawnConn }
end

local function closeCard(p)
    local d = cards[p]; if not d then return end
    pcall(function() d.sc:Disconnect() end)
    pcall(function() d.resp:Disconnect() end)
    pcall(function() d.gui:Destroy()   end)
    cards[p] = nil
end
local function closeAll()
    for p in pairs(cards)    do closeCard(p)       end
    for p in pairs(outlines) do setOutline(p,false) end
end
local function toggle(p)
    if cards[p] then
        closeCard(p); setOutline(p,false)
    else
        setOutline(p,true); openCard(p)
    end
end
local function removeTLTool()
    for _, loc in ipairs({
        Players.LocalPlayer:FindFirstChildOfClass("Backpack"),
        Players.LocalPlayer.Character
    }) do
        if loc then
            local t = loc:FindFirstChild("_TLMagnifier")
            if t then t:Destroy() end
        end
    end
    closeAll()
end

removeTLTool()
local tool = Instance.new("Tool")
tool.Name           = "_TLMagnifier"
tool.ToolTip        = ""
pcall(function() tool.TextureId = "rbxassetid://71807151037163" end)
tool.CanBeDropped   = false
tool.RequiresHandle = true
tool.GripPos        = Vector3.new(0,0,-0.3)
tool.GripForward    = Vector3.new(0,0,-1)
tool.GripRight      = Vector3.new(1,0,0)
tool.GripUp         = Vector3.new(0,1,0)
local handle = Instance.new("Part", tool)
handle.Name         = "Handle"
handle.Size         = Vector3.new(0.1,0.1,0.1)
handle.CanCollide   = false
handle.Massless     = true
handle.CastShadow   = false
handle.Transparency = 1
local clickConn = nil
tool.Equipped:Connect(function(mouse)
if clickConn then clickConn:Disconnect(); clickConn = nil end
if mouse then
clickConn = mouse.Button1Down:Connect(function()
local hit = mouse.Target; if not hit then return end
local ch = hit:FindFirstAncestorOfClass("Model")
local p  = ch and Players:GetPlayerFromCharacter(ch)
if p and p ~= Players.LocalPlayer then toggle(p) end
end)
else
-- detect touch vs mouse
local _hasTouchEnabled = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
if _hasTouchEnabled then
    -- Mobile/Tablet: use TouchTap for tap-to-open
    clickConn = UIS.TouchTap:Connect(function(positions)
        local cam = workspace.CurrentCamera; if not cam then return end
        local pos = positions[1]
        if not pos then return end
        local ray = cam:ScreenPointToRay(pos.X, pos.Y)
        local res = workspace:Raycast(ray.Origin, ray.Direction*500)
        local hit = res and res.Instance; if not hit then return end
        local ch  = hit:FindFirstAncestorOfClass("Model")
        local p   = ch and Players:GetPlayerFromCharacter(ch)
        if p and p ~= Players.LocalPlayer then toggle(p) end
    end)
else
    clickConn = UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local cam = workspace.CurrentCamera; if not cam then return end
    local mp  = UIS:GetMouseLocation()
    local ray = cam:ScreenPointToRay(mp.X, mp.Y)
    local res = workspace:Raycast(ray.Origin, ray.Direction*500)
    local hit = res and res.Instance; if not hit then return end
    local ch  = hit:FindFirstAncestorOfClass("Model")
    local p   = ch and Players:GetPlayerFromCharacter(ch)
    if p and p ~= Players.LocalPlayer then toggle(p) end
    end)
end
end
end)
tool.Unequipped:Connect(function()
if clickConn then clickConn:Disconnect(); clickConn = nil end
closeAll()
end)
local function spawnTool()
for _, loc in ipairs({
Players.LocalPlayer:FindFirstChildOfClass("Backpack"),
Players.LocalPlayer.Character
}) do
if loc then
local old = loc:FindFirstChild("_TLMagnifier")
if old and old ~= tool then old:Destroy() end
end
end
local bp = Players.LocalPlayer:FindFirstChildOfClass("Backpack")
or Players.LocalPlayer:WaitForChild("Backpack", 8)
if bp then tool.Parent = bp end
end
task.spawn(spawnTool)
Players.LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.8); task.spawn(spawnTool)
end)
if getgenv then _genv._TLRemoveTool = removeTLTool end
end)
local keybinds, keybindMainConn = {}, nil
local function rebuildKeybindListener()
if keybindMainConn then keybindMainConn:Disconnect() end
keybindMainConn = UserInputService.InputBegan:Connect(function(input, gpe)
if gpe then return end
if input.KeyCode == Enum.KeyCode.K then return end
for actionName, data in pairs(keybinds) do
if data.key and input.KeyCode == data.key and data.callback then
data.callback()
end
end
end)
end
rebuildKeybindListener()

-- -----------------------------------------------------------------
local function registerKeybind(actionName, defaultKey, callback)
keybinds[actionName] = { key = defaultKey, callback = callback }
end
local keybindLabelUpdaters, SAVE_FILE = {}, "SmartBar_Save.json"
local settingsState = {
soundEnabled  = true,
themeColor    = "blue",
notifications = true,
showHint      = false,
autoOpen      = false,
menuSounds    = true,
}
local T = {
settings_title        = "Settings",
settings_general      = "General",
settings_keybinds     = "Keybinds",
settings_sound        = "Sound Effects",
settings_sound_badge  = "Global",
settings_notif        = "Notifications",
settings_notif_badge  = "Hints",
settings_hint         = "Show Hint",
settings_hint_badge   = "UI",
settings_auto         = "Auto-open",
settings_auto_badge   = "Startup",
settings_menusounds       = "Menu Sounds",
settings_menusounds_badge = "UI",
notif_settings_loaded = "Settings loaded ✅",
notif_saved           = "✅  Saved!",
save_settings         = "💾  Save Settings & Keybinds",
home_section_game     = "CURRENT EXPERIENCE",
home_section_profile  = "YOUR PROFILE",
home_place_id         = "Place ID",
home_universe_id      = "Universe ID",
home_job_id           = "Job ID",
kb_hint               = "Click a key, then press a button  –  Esc to clear",
kb_reset              = "Reset",
profile_online        = "Online",
smartbar_hint         = "Press  K  to open the SmartBar",
qa_nobody             = "Nobody nearby",
qa_title              = "QUICK ACTIONS",
qa_subtitle           = "Select an action",
qa_stopped            = "Stopped",
qa_no_target          = "⚠  No target found",
qa_idle               = "Idle  –  Select an action",
qa_extras             = "  EXTRAS",
script_active         = "Active",
script_inactive       = "Inactive",
gb_label              = "Gangbang",
gb_player_pill        = "Player...",
gb_target_key         = "TARGET",
gb_no_players         = "No players online",
gb_select_player      = "Select a player first!",
gb_stopped            = "Stopped",
gb_no_target_char     = "No target character!",
gb_no_own_char        = "No own character!",
gb_missing_parts      = "Missing parts!",
gb_orbit              = "🔄 Orbit: ",
gb_auto_target        = "Auto-target: ",
gb_nobody_near        = "No player nearby!",
rush_label            = "Rush",
rush_player_pill      = "Player...",
rush_no_players       = "No players online",
rush_stopped          = "Stopped 🛑",
rush_no_target_char   = "No target character!",
rush_no_char          = "No own character!",
rush_missing_parts    = "Missing parts!",
rush_running          = "Rush ⚡ ",
actions_info_lbl      = "Actions",
actions_info_sub      = "Select a player & action, then activate",
actions_pick_target   = "Target",
actions_player_pill   = "Player...",
actions_action_pill   = "Action...",
actions_row_lbl       = "Actions",
actions_status_idle   = "Inactive",
actions_select_player = "Select a player first!",
actions_select_action = "Select an action first!",
actions_following     = "Following: ",
actions_stopped       = "Stopped",
actions_no_players    = "No players online",
playercard_spectate   = "Spectate",
playercard_teleport   = "Teleport",
playercard_esp        = "ESP",
anim_no_nearby        = "No player nearby!",
  orbit_respawn       = "Target respawned – Orbit reset!",
  no_players_online   = "No players online",
}

local function serializeData()
local kbData = {}
for name, data in pairs(keybinds) do
kbData[name] = data.key and tostring(data.key):gsub("Enum.KeyCode.", "") or "None"
end
local lines = {"{\n"}
lines[#lines+1] = '  "settings": {\n'
local settKeys = {}
for k in pairs(settingsState) do settKeys[#settKeys+1] = k end
for i, k in ipairs(settKeys) do
local v = settingsState[k]
local comma = i < #settKeys and "," or ""
if type(v) == "string" then
lines[#lines+1] = string.format('    "%s": "%s"%s\n', k, v, comma)
else
lines[#lines+1] = string.format('    "%s": %s%s\n', k, tostring(v), comma)
end
end
lines[#lines+1] = '  },\n'
lines[#lines+1] = '  "keybinds": {\n'
local kbKeys = {}
for k in pairs(kbData) do kbKeys[#kbKeys+1] = k end
for i, k in ipairs(kbKeys) do
local comma = i < #kbKeys and "," or ""
lines[#lines+1] = string.format('    "%s": "%s"%s\n', k, kbData[k], comma)
end
lines[#lines+1] = '  }\n'
lines[#lines+1] = "}"
return table.concat(lines)
end
local function saveData()
pcall(function()
if writefile then
writefile(SAVE_FILE, serializeData())
end
end)
end

local function extractJsonSection(json, section)
local startPat = '"' .. section .. '":%s*{'
local startPos = json:find(startPat)
if not startPos then return "" end
local braceStart = json:find('{', startPos)
if not braceStart then return "" end
local depth = 0
local i = braceStart
while i <= #json do
local ch = json:sub(i, i)
if ch == '{' then depth = depth + 1
elseif ch == '}' then
depth = depth - 1
if depth == 0 then
return json:sub(braceStart + 1, i - 1)
end
end
i = i + 1
end
return ""
end
local function bootstrapThemeEarly()
    pcall(function()
        if not readfile then return end
        local ok, content = pcall(readfile, SAVE_FILE)
        if not ok or not content or content == "" then return end
        local settBlock = extractJsonSection(content, "settings")
        if settBlock == "" then return end
        local tc = settBlock:match('"themeColor"%s*:%s*"([^"]*)"')
        if tc then settingsState.themeColor = tc end
    end)
    pcall(function()
        if settingsState.themeColor then
            _TL_applyTheme(settingsState.themeColor, true)
        end
    end)
end
bootstrapThemeEarly()
local function loadData()
pcall(function()
if not readfile then return end
local ok, content = pcall(readfile, SAVE_FILE)
if not ok or not content or content == "" then return end
local settBlock = extractJsonSection(content, "settings")
for key in pairs(settingsState) do
do
local val = settBlock:match('"' .. key .. '":%s*(true|false)')
if val then
settingsState[key] = val == "true"
end
end
end
-- load string values (themeColor)
do
local tc = settBlock:match('"themeColor"%s*:%s*"([^"]*)"')
if tc then settingsState.themeColor = tc end
end
task.defer(function()
if _G.settingToggleSetters then
for key, setFn in pairs(_G.settingToggleSetters) do
pcall(function() setFn(settingsState[key]) end)
end
end
-- Single startup apply: recolor the built UI once, instead of rescanning it multiple times.
pcall(function()
local theme = settingsState.themeColor
    or (getgenv and getgenv()._TL_savedTheme)
    or _TL_activeThemeId
if theme and theme ~= _TL_lastRenderedThemeId then
_TL_applyTheme(theme)
end
end)
end)
local kbBlock = extractJsonSection(content, "keybinds")
if kbBlock and kbBlock ~= "" then
for name, data in pairs(keybinds) do
local keyName = kbBlock:match('"' .. name .. '":%s*"([^"]*)"')
if keyName and keyName ~= "None" then
local found = nil
pcall(function()
found = Enum.KeyCode[keyName]
end)
if found then
data.key = found
if keybindLabelUpdaters[name] then
pcall(function() keybindLabelUpdaters[name](found) end)
end
end
elseif keyName == "None" then
data.key = nil
if keybindLabelUpdaters[name] then
pcall(function() keybindLabelUpdaters[name](nil) end)
end
end
end
end
end)
end
local function gradStroke(p, t, tr)
local s = _makeDummyStroke(p)
s.Thickness        = t or 0.9
s.Transparency     = tr or 0.1
s.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
local g = Instance.new("UIGradient", s)
g.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0,   C.gradL),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100,60,200)),
ColorSequenceKeypoint.new(1,   C.gradR),
}
g.Rotation = 90
return s, g
end
local _TI_CACHE = {}
local function _getTI(t, sty, dir)
    local s = sty or Enum.EasingStyle.Quart
    local d = dir or Enum.EasingDirection.Out
    local k1 = _TI_CACHE[t]
    if not k1 then k1 = {}; _TI_CACHE[t] = k1 end
    local k2 = k1[s]
    if not k2 then k2 = {}; k1[s] = k2 end
    local ti = k2[d]
    if not ti then ti = TweenInfo.new(t, s, d); k2[d] = ti end
    return ti
end
local function tw(obj, t, props, sty, dir)
    return TweenService:Create(obj, _getTI(t, sty, dir), props)
end
local function twP(obj, t, props, sty, dir)
    local tw_ = TweenService:Create(obj, _getTI(t, sty, dir), props)
    tw_:Play(); return tw_
end
local function twC(slot, obj, t, props, sty, dir)
if slot.tween then pcall(function() slot.tween:Cancel() end) end
local tween = tw(obj, t, props, sty, dir)
slot.tween = tween
tween:Play()
return tween
end
-- -- Row-Hover Sound ----------------------------------
-- Pro Hover ein Clone abspielen (kein :Play() auf derselben Instanz – sonst Neustart = abgehackt)
local _hoverSoundObj = nil
local _hoverSoundLastT = 0
local _HOVER_SND_GAP = 0.04 -- leichte Drossel bei extrem schnellem Überstreichen (sek)
pcall(function()
    _hoverSoundObj = _tlTrackInst(Instance.new("Sound"))
    _hoverSoundObj.SoundId  = "rbxassetid://139800881181209"
    _hoverSoundObj.Volume   = 0.5
    _hoverSoundObj.RollOffMaxDistance = 10000
    _hoverSoundObj.Name = "HoverSound"
    return 
end)
local function _playHoverSound()
    if not settingsState.menuSounds then return end
    local now = tick()
    if now - _hoverSoundLastT < _HOVER_SND_GAP then return end
    _hoverSoundLastT = now
    pcall(function()
        if not _hoverSoundObj then return end
        local s = _hoverSoundObj:Clone()
        s.Parent = _SvcSnd
        s.Volume = 0.5
        s:Play()
        _SvcDeb:AddItem(s, 3)
    end)
end
local function _themePanelColor(col, fallback)
    -- Support live-tracking via string keys
    if col == "accent" then return C.accent end
    if col == "accent2" then return C.accent2 end
    if col == "sub" then return C.sub end
    
    local base = fallback or C.accent or C.text
    if typeof(col) ~= "Color3" then return base end
    -- Gib col direkt zurück wenn es eine Theme-Farbe ist
    if col == C.orange or col == C.red or col == C.green or col == C.accent or col == C.accent2 then
        return col
    end
    return col
end

-- Scripts-Tab: Kategorie-Akzent (Troll/Movement/...) mit Theme-Farbe mischen
local function _scriptCatAccent(baseCol)
    local ta = C.accent or Color3.fromRGB(0, 255, 140)
    if typeof(baseCol) ~= "Color3" then return ta end
    return baseCol:Lerp(ta, 0.38)
end

local function cleanRow(parent, yPos, label, sublabel, col, initOn, onToggle)
local ROW_H = 46
local card = Instance.new("Frame", parent)
card.Size = UDim2.new(1,0,0,ROW_H)
card.Position = UDim2.new(0,0,0,yPos)
card.BackgroundColor3 = C.bg2 or _C3_BG2
card.BackgroundTransparency = 0; card.BorderSizePixel = 0
corner(card, 12)
local cStr = _makeDummyStroke(card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local cdot = Instance.new("Frame", card)
cdot.Size = UDim2.new(0,3,0,ROW_H-16); cdot.Visible = false
cdot.Position = UDim2.new(0,0,0.5,-(ROW_H-16)/2)
cdot.BackgroundColor3 = _themePanelColor(col, C.accent); cdot.BackgroundTransparency = 0.4
cdot.BorderSizePixel = 0; corner(cdot, 99)
local nameLbl = Instance.new("TextLabel", card)
nameLbl.Size = UDim2.new(1,-60,0,18); nameLbl.Position = UDim2.new(0,14,0, sublabel and 6 or 14)
nameLbl.BackgroundTransparency = 1; nameLbl.Text = label
nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = C.text or _C3_TEXT3
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
if sublabel then
local subLbl = Instance.new("TextLabel", card)
subLbl.Size = UDim2.new(1,-60,0,13); subLbl.Position = UDim2.new(0,14,0,24)
subLbl.BackgroundTransparency = 1; subLbl.Text = sublabel
subLbl.Font = Enum.Font.GothamBold; subLbl.TextSize = 9
subLbl.TextColor3 = C.sub or _C3_SUB
subLbl.TextXAlignment = Enum.TextXAlignment.Left
end
local togTrack = Instance.new("Frame", card)
togTrack.Size = UDim2.new(0,32,0,18); togTrack.Position = UDim2.new(1,-46,0.5,-9)
togTrack.BackgroundColor3 = C.bg3 or _C3_BG3
togTrack.BackgroundTransparency = 0.2; togTrack.BorderSizePixel = 0; corner(togTrack, 99)
local togKnob = Instance.new("Frame", togTrack)
togKnob.Size = UDim2.new(0,12,0,12)
togKnob.Position = initOn and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
togKnob.BackgroundColor3 = initOn and _C3_WHITE or _C3_SUB2
togKnob.BackgroundTransparency = 0; togKnob.BorderSizePixel = 0; corner(togKnob, 99)
if initOn then
togTrack.BackgroundColor3 = C.accent; togTrack.BackgroundTransparency = 0.55
cStr.Color = C.accent; cStr.Transparency = 0.5
end
local togState = initOn or false
local function setToggle(on)
togState = on
local activeCol = C.accent  -- live read statt gecapturtes col (sonst bleibt Grün nach Theme-Wechsel)
if on then
twP(togTrack, 0.15, {BackgroundColor3 = activeCol, BackgroundTransparency = 0.55})
twP(togKnob,  0.15, {BackgroundColor3 = _C3_WHITE, Position = UDim2.new(1,-14,0.5,-6)})
twP(cStr,     0.15, {Color = activeCol, Transparency = 0.5})
-- * Sound bei Toggle ON
pcall(function()
    local soundService = _SvcSnd
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://127366656618533"
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    _SvcDeb:AddItem(sound, 2)
end)
else
twP(togTrack, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
twP(togKnob,  0.15, {BackgroundColor3 = _C3_SUB2, Position = UDim2.new(0,2,0.5,-6)})
twP(cStr,     0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.3})
end
if onToggle then pcall(onToggle, on) end
end
local btn = Instance.new("TextButton", card)
btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 6
local _togDebounceA = false
local _startPosCR = nil
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then _startPosCR = inp.Position end
end)
btn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch and _startPosCR then
        local dist = (inp.Position - _startPosCR).Magnitude
        _startPosCR = nil
        if dist < 8 then
            if _togDebounceA then return end
            _togDebounceA = true
            setToggle(not togState)
            task.delay(0.3, function() _togDebounceA = false end)
        end
    end
end)
btn.MouseButton1Click:Connect(function()
    if not _togDebounceA then setToggle(not togState) end
end)
btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
_playHoverSound()
twP(card, 0.08, {BackgroundColor3 = C.bg3 or _C3_BG4})
end)
btn.MouseLeave:Connect(function()
twP(card, 0.08, {BackgroundColor3 = C.bg2 or _C3_BG2})
end)
return card, setToggle, function() return togState end
end
local function makeToggle(parent, x, y, initState, onChange)
local W, H = 44, 24
local track = Instance.new("Frame", parent)
track.Size             = UDim2.new(0, W, 0, H)
track.Position         = UDim2.new(0, x, 0, y)
track.BackgroundColor3 = initState and C.accent or C.bg3
track.BorderSizePixel  = 0
corner(track, 16)
local ts = stroke(track, 1, initState and C.accent or C.borderdim, initState and 0.0 or 0.3)
local knob = Instance.new("Frame", track)
knob.Size             = UDim2.new(0, H-6, 0, H-6)
knob.Position         = initState
and UDim2.new(0, W-(H-6)-3, 0, 3)
or  UDim2.new(0, 3, 0, 3)
knob.BackgroundColor3 = _C3_WHITE
knob.BorderSizePixel  = 0
corner(knob, 99)
local ks = _makeDummyStroke(knob)
ks.Thickness = 0.8; ks.Color = _C3_BLACK; ks.Transparency = 0.5
local state = initState
local function setState(on)
state = on
tw(knob, 0.20, {
Position = on and UDim2.new(0, W-(H-6)-3, 0, 3)
or  UDim2.new(0, 3, 0, 3)
}, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
twP(track, 0.18, {BackgroundColor3 = on and C.accent or C.bg3})
tw(ts, 0.18, {
Color       = on and C.accent or C.borderdim,
Transparency = on and 0.0 or 0.3,
}):Play()
if onChange then onChange(on) end
end
local btn = Instance.new("TextButton", track)
btn.Size = UDim2.new(1,0,1,0)
btn.BackgroundTransparency = 1
btn.Text = ""
btn.ZIndex = knob.ZIndex + 2
btn.MouseButton1Click:Connect(function()
local turningOn = not state
setState(turningOn)
if turningOn then
pcall(function()
local SoundService = _SvcSnd
local s = Instance.new("Sound")
s.SoundId = "rbxassetid://79062163283657"
s.Volume = 0.6
s.Parent = SoundService
s:Play()
_SvcDeb:AddItem(s, 5)
end)
end
end)
local _startPosT = nil
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        _startPosT = inp.Position
    end
end)
btn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch and _startPosT then
        local dist = (inp.Position - _startPosT).Magnitude
        _startPosT = nil
        if dist < 8 then
            local turningOn = not state
            setState(turningOn)
            if turningOn then
                pcall(function()
                    local SoundService = _SvcSnd
                    local s = Instance.new("Sound")
                    s.SoundId = "rbxassetid://79062163283657"
                    s.Volume = 0.6; s.Parent = SoundService; s:Play()
                    _SvcDeb:AddItem(s, 5)
                end)
            end
        end
    end
end)
return track, setState, function() return state end
end
-- -- Responsive Panel- und Widget-Breite --------------
local _TL_VP = {}
do
    local _ok, _vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp = _ok and _vp or Vector2.new(1920, 1080)
    local _uis   = _SvcUIS
    local _touch = pcall(function() return _uis.TouchEnabled  end) and _uis.TouchEnabled
    local _kbd   = pcall(function() return _uis.KeyboardEnabled end) and _uis.KeyboardEnabled
    local _short = math.min(_vp.X, _vp.Y)
    local _long  = math.max(_vp.X, _vp.Y)
    local _isMob = _touch and not _kbd and _short < 500
    local _isTab = _touch and not _kbd and _short >= 500 and _short < 900
    local _isTch = _touch and not _kbd

    -- Panel-Breite: passt sich an verfügbare Breite an
    -- SmartBar auf Mobile: VL_W=72 (klein) + 5 (gap) + 8 (pad) = 85px links reserviert, 8px rechts
    local _pnlW
    if _isTch then
        local _vlWEst = _isMob and 72 or 66   -- VL_W-Schätzung (noch nicht definiert hier)
        local _avail  = _long - _vlWEst - 5 - 8 - 8
        if _isMob then
            _pnlW = math.floor(math.clamp(_avail, 220, 360))
        else
            _pnlW = math.floor(math.clamp(_avail, 280, 430))
        end
    else
        _pnlW = 430
    end

    -- fpsWidget-Breite: per UIScale skaliert, daher Original-Größe behalten
    -- Nur die Skalierung (scl) wird kleiner – FW_W bleibt 288, damit UIScale korrekt rechnet
    -- Zentraler Mobile-Scale für Panels, QA-Bar, fpsWidget (PC = 1.0)
    local _mobScl = 1.0
    if _isMob then
        _mobScl = math.clamp(_short / 667, 0.50, 0.72)
    elseif _isTab then
        _mobScl = math.clamp(_short / 900, 0.72, 0.88)
    end
    _TL_VP.isMob   = _isMob
    _TL_VP.isTab   = _isTab
    _TL_VP.isTouch = _isTch
    _TL_VP.short   = _short
    _TL_VP.long    = _long
    _TL_VP.pnlW    = _pnlW
    _TL_VP.fwW     = 288
    _TL_VP.fwH     = 34
    _TL_VP.mobScl  = _mobScl
end

-- FIX Mobile: Panel-Breite an Bildschirmbreite anpassen
local PANEL_W = _TL_VP.pnlW
local HOME_PANEL_W_OVERRIDE = nil
local panels, panelCreditGrads = {}, {}
local _panelTweens = {}   -- laufender Öffnungs-Tween pro Panel-Name (für Drag-Start cancel)
-- -- Panel-Farbpalette – wird von _TL_applyTheme synchron gehalten -
local P_MG    = C.accent    -- accent bright  (sync: C.accent)
local P_MGA   = C.accent2  -- accent2 mid    (sync: C.accent2)
local P_MGDIM = C.sub      -- sub dim        (sync: C.sub)
local function _TL_shadeRGB(c, m)
    return Color3.fromRGB(
        math.clamp(math.floor(c.R * 255 * m), 0, 255),
        math.clamp(math.floor(c.G * 255 * m), 0, 255),
        math.clamp(math.floor(c.B * 255 * m), 0, 255))
end
local function _TL_computePanelSurfaceGradients(themeId)
    if themeId == "matrix" then
        return {
            hdr = ColorSequence.new{
                ColorSequenceKeypoint.new(0,    Color3.fromRGB(5, 22, 10)),
                ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(3, 15,  7)),
                ColorSequenceKeypoint.new(1,    Color3.fromRGB(2, 10,  4)),
            },
            body = ColorSequence.new{
                ColorSequenceKeypoint.new(0,    Color3.fromRGB(6,  18, 9)),
                ColorSequenceKeypoint.new(0.18, Color3.fromRGB(3,  11, 5)),
                ColorSequenceKeypoint.new(0.55, Color3.fromRGB(1,   7, 3)),
                ColorSequenceKeypoint.new(1,    C.bg or Color3.fromRGB(15, 15, 20)),
            },
            cg = ColorSequence.new{
                ColorSequenceKeypoint.new(0, C.accent),
                ColorSequenceKeypoint.new(1, C.panelBg),
            },
        }
    end
    local pb = C.panelBg or C.bg
    local ph = C.panelHdr or C.bg2
    return {
        hdr = ColorSequence.new{
            ColorSequenceKeypoint.new(0,   _TL_shadeRGB(ph, 1.12)),
            ColorSequenceKeypoint.new(0.5, ph),
            ColorSequenceKeypoint.new(1,   _TL_shadeRGB(ph, 0.82)),
        },
        body = ColorSequence.new{
            ColorSequenceKeypoint.new(0,   _TL_shadeRGB(pb, 1.08)),
            ColorSequenceKeypoint.new(0.18, _TL_shadeRGB(pb, 1.0)),
            ColorSequenceKeypoint.new(0.55, _TL_shadeRGB(pb, 0.9)),
            ColorSequenceKeypoint.new(1,   _TL_shadeRGB(pb, 0.78)),
        },
        cg = ColorSequence.new{
            ColorSequenceKeypoint.new(0, C.accent),
            ColorSequenceKeypoint.new(1, pb),
        },
    }
end
local function _TL_fpsWidgetBgGradient()
    if _TL_activeThemeId == "matrix" then
        return ColorSequence.new{
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(3, 14, 6)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(2, 10, 4)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(1,  7, 2)),
        }
    end
    local pb = C.panelBg or C.bg
    return ColorSequence.new{
        ColorSequenceKeypoint.new(0,   _TL_shadeRGB(pb, 1.06)),
        ColorSequenceKeypoint.new(0.5, _TL_shadeRGB(pb, 0.94)),
        ColorSequenceKeypoint.new(1,   _TL_shadeRGB(pb, 0.82)),
    }
end
-- Hook so _TL_applyTheme keeps P_MG* in sync for newly created panels
if not _panelColorHooks then _panelColorHooks = {} end
-- Registry: jedes makePanel registriert seine accent-farbigen Objekte hier
local _panelAccentObjs = {}  -- array of {stroke=pStroke, top=topBar, sep=sep, rain=nil, dot=blinkDot, title=htitle, scan=scanLines, ib=ibStroke, sbt=sbTrack, sbth=sbThumb, cgrad=creditGrad}
_panelColorHooks[#_panelColorHooks+1] = function(newT)
    P_MG    = newT.accent
    P_MGA   = newT.accent2
    P_MGDIM = newT.sub
    local surf = _TL_computePanelSurfaceGradients(newT.id)
    -- Alle bestehenden Panel-Objekte live aktualisieren
    for _, r in ipairs(_panelAccentObjs) do
        pcall(function()
            if r.stroke  then r.stroke.Color           = newT.accent end
            if r.top     then r.top.BackgroundColor3   = newT.accent end
            if r.sep     then r.sep.BackgroundColor3   = newT.accent end
            if r.rain    then r.rain.TextColor3         = newT.accent end
            if r.dot     then r.dot.BackgroundColor3   = newT.accent end
            if r.title   then r.title.TextColor3        = newT.accent end
            if r.scan    then r.scan.TextColor3         = newT.accent end
            if r.ib      then r.ib.Color                = newT.accent end
            if r.sbt     then r.sbt.BackgroundColor3   = newT.accent end
            if r.sbth    then r.sbth.BackgroundColor3  = newT.accent end
            if r.cgrad   then r.cgrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0,    newT.sub),
                ColorSequenceKeypoint.new(0.30, newT.sub),
                ColorSequenceKeypoint.new(0.50, newT.accent2),
                ColorSequenceKeypoint.new(0.70, newT.sub),
                ColorSequenceKeypoint.new(1,    newT.sub),
            } end
            if r.pf   and r.pf.Parent   then r.pf.BackgroundColor3   = C.panelBg end
            if r.hdrf and r.hdrf.Parent then r.hdrf.BackgroundColor3 = C.panelHdr end
            if r.bodyGrad and surf.body then r.bodyGrad.Color = surf.body end
            if r.hdrGrad and surf.hdr then r.hdrGrad.Color = surf.hdr end
            if r.cgGrad and surf.cg then r.cgGrad.Color = surf.cg end
        end)
    end
end

local function makePanel(name, accentDot)
    local p = Instance.new("Frame", ScreenGui)
    p.Name             = name
    p.Size             = UDim2.new(0, PANEL_W, 0, 10)
    p.AnchorPoint      = Vector2.new(0, 0)
    p.Position         = UDim2.new(0, 61, 0, -(600))
    p.Visible          = false
    p.ClipsDescendants = true
    stylePanelSurface(p, 12, 0)

    -- Mobile scaling
    if _TL_VP.isTouch and _TL_VP.mobScl < 1.0 then
        local _pScl = Instance.new("UIScale", p)
        _pScl.Scale = _TL_VP.mobScl
    end

-- Rahmen: UIStroke (Modern Style)
local pStroke = _makeDummyStroke(p)
pStroke.Thickness       = 1
pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pStroke.Color           = C.bg3 or Color3.fromRGB(45, 45, 45)
pStroke.Transparency    = 0

    -- Header-Bereich: Modern Matrix Header
    local hdr = Instance.new("Frame", p)
    hdr.Size             = UDim2.new(1, 0, 0, 48)
    hdr.BackgroundColor3 = C.bg2 or Color3.fromRGB(20, 20, 24)
    hdr.BorderSizePixel  = 0; hdr.ZIndex = 2
    corner(hdr, 12)
    gradient(hdr, 90, C.bg3 or Color3.fromRGB(30, 30, 35), C.bg2 or Color3.fromRGB(20, 20, 24))
    
    -- Bottom cut to keep header top rounded but bottom sharp (at separator)
    local hdrCut = Instance.new("Frame", hdr)
    hdrCut.Size = UDim2.new(1, 0, 0, 12); hdrCut.Position = UDim2.new(0, 0, 1, -12)
    hdrCut.BackgroundColor3 = C.bg2 or Color3.fromRGB(20, 20, 24); hdrCut.BorderSizePixel = 0; hdrCut.ZIndex = 2

    -- Header-Separator (Theme Aware Accent)
    local sep = Instance.new("Frame", p)
    sep.Size             = UDim2.new(1, 0, 0, 1)
    sep.Position         = UDim2.new(0, 0, 0, 48)
    sep.BackgroundColor3 = C.accent
    sep.BackgroundTransparency = 0.4
    sep.BorderSizePixel  = 0; sep.ZIndex = 3

    -- Panel-Titel: Standardized Matrix Text
    local htitle = Instance.new("TextLabel", hdr)
    htitle.Size              = UDim2.new(1, -165, 1, 0)
    htitle.Position          = UDim2.new(0, 16, 0, 0)
    htitle.BackgroundTransparency = 1
    htitle.Text              = name:upper()
    htitle.Font              = Enum.Font.GothamBold
    htitle.TextSize          = 15
    htitle.TextColor3        = C.text
    htitle.TextXAlignment    = Enum.TextXAlignment.Left
    htitle.ZIndex            = 5
    
    -- Credit-Label rechts
    local credit = Instance.new("TextLabel", hdr)
    credit.Size              = UDim2.new(0, 100, 1, 0)
    credit.Position          = UDim2.new(1, -135, 0, 0)
    credit.BackgroundTransparency = 1
    credit.Text              = "telelumi"
    credit.Font              = Enum.Font.GothamBold
    credit.TextSize          = 11
    credit.TextColor3        = C.sub
    credit.TextXAlignment    = Enum.TextXAlignment.Right
    credit.ZIndex            = 5
-- -- Body-Struktur: Gradient + Scan-Lines + Glow + innerer Rahmen -------
-- No gradient - matte opaque panel design
-- -- Scrollable Content --------------------------------------------------
local scroll = Instance.new("ScrollingFrame", p)
scroll.Name                 = "Content"
scroll.Size                 = UDim2.new(1, -12, 1, -58)
scroll.Position             = UDim2.new(0, 6, 0, 54)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel      = 0
scroll.ClipsDescendants     = true
scroll.ScrollBarThickness   = 0
scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection   = Enum.ScrollingDirection.Y
scroll.ElasticBehavior      = Enum.ElasticBehavior.Never
    -- Scrollbar: Standardized
    local sbTrack = Instance.new("Frame", p)
    sbTrack.Name              = "ScrollTrack"
    sbTrack.Size              = UDim2.new(0, 2, 1, -66)
    sbTrack.Position          = UDim2.new(1, -6, 0, 58)
    sbTrack.BackgroundColor3  = C.bg3
    sbTrack.BackgroundTransparency = 0.5
    sbTrack.BorderSizePixel   = 0
    sbTrack.Visible           = false
    corner(sbTrack, 99)
    local sbThumb = Instance.new("Frame", sbTrack)
    sbThumb.BackgroundColor3  = C.accent
    sbThumb.BackgroundTransparency = 0
    sbThumb.BorderSizePixel   = 0
    sbThumb.Size              = UDim2.new(1, 0, 0, 30)
    sbThumb.Position          = UDim2.new(0, 0, 0, 0)
    corner(sbThumb, 99)
local function updateScrollbar()
local canvasH = scroll.CanvasSize.Y.Offset
local frameH  = scroll.AbsoluteSize.Y
if canvasH <= frameH then
sbTrack.Visible = false
return
end
sbTrack.Visible = true
local ratio    = frameH / canvasH
local thumbH   = math.max(20, sbTrack.AbsoluteSize.Y * ratio)
local maxScroll = canvasH - frameH
local thumbY   = (scroll.CanvasPosition.Y / maxScroll)
* (sbTrack.AbsoluteSize.Y - thumbH)
sbThumb.Size     = UDim2.new(1, 0, 0, thumbH)
sbThumb.Position = UDim2.new(0, 0, 0, thumbY)
end
pcall(function() scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScrollbar) end)
pcall(function() scroll:GetPropertyChangedSignal("CanvasSize"):Connect(updateScrollbar) end)
local function autoCanvas()
local maxY = 0
for _, ch in ipairs(scroll:GetChildren()) do
if ch:IsA("GuiObject") then
local bottom = ch.Position.Y.Offset + ch.Size.Y.Offset
if bottom > maxY then maxY = bottom end
end
end
scroll.CanvasSize = UDim2.new(0, 0, 0, maxY + 12)
updateScrollbar()
end
scroll.ChildAdded:Connect(function() task.defer(autoCanvas) end)
scroll.ChildRemoved:Connect(function() task.defer(autoCanvas) end)

	-- -- Panel Drag – Direct/Synchronous Implementation --------------------------
	do
	    local dragHint = Instance.new("TextLabel", hdr)
	    dragHint.Size                   = UDim2.new(0, 20, 0, 20)
	    dragHint.Position               = UDim2.new(1, -28, 0.5, -10)
	    dragHint.BackgroundTransparency = 1
	    dragHint.Text                   = "◈"
	    dragHint.Font                   = Enum.Font.Code
	    dragHint.TextSize               = 14
	    dragHint.TextColor3             = P_MGA
	    dragHint.TextTransparency       = 0.5
	    dragHint.ZIndex                 = 6

	    p.AnchorPoint = Vector2.new(0, 0)

	    local dragging  = false
	    local dragStart = nil
	    local startPos  = nil
	    local dragW, dragH = 0, 0 -- AbsoluteSize nur einmal pro Drag (kein Layout-Hit pro Mausbewegung)
	    local inputConn = nil  -- nur aktiv während Drag

	    local viewport  = Vector2.new()
	    local camera    = workspace.CurrentCamera
	    local function updateViewport()
	        local s = camera.ViewportSize; viewport = Vector2.new(s.X, s.Y)
	    end
	    updateViewport()
	    pcall(function()
	        camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewport)
	    end)

	    local function updateFeedback(active)
	        if active then
	            local hOn = (_TL_activeThemeId == "matrix") and Color3.fromRGB(4, 22, 8)
	                or Color3.new(
	                    math.clamp(C.panelHdr.R * 1.18, 0, 1),
	                    math.clamp(C.panelHdr.G * 1.18, 0, 1),
	                    math.clamp(C.panelHdr.B * 1.18, 0, 1))
	            twP(hdr,      0.08, {BackgroundColor3 = hOn})
	            twP(dragHint, 0.08, {TextTransparency = 0})
	        else
	            twP(hdr,      0.12, {BackgroundColor3 = C.panelHdr})
	            twP(dragHint, 0.12, {TextTransparency = 0.5})
	        end
	    end

	    local function stopDrag()
	        dragging = false
	        if inputConn then pcall(function() inputConn:Disconnect() end); inputConn = nil end
	        updateFeedback(false)
            p.ClipsDescendants = true
	    end

	    p.AncestryChanged:Connect(function()
	        if not p.Parent then stopDrag() end
	    end)

	    hdr.InputBegan:Connect(function(inp)
	        if inp.UserInputType == Enum.UserInputType.MouseButton1
	        or inp.UserInputType == Enum.UserInputType.Touch then
	            -- laufenden Öffnungs-Tween canceln
	            pcall(function()
	                local tw = _panelTweens[name]
	                if tw then tw:Cancel(); _panelTweens[name] = nil end
	            end)
	            dragging  = true
                p.ClipsDescendants = false
	            dragStart = (inp.UserInputType == Enum.UserInputType.Touch)
	                and inp.Position
	                or UserInputService:GetMouseLocation()
	            startPos  = p.Position
	            dragW, dragH = p.AbsoluteSize.X, p.AbsoluteSize.Y
	            updateViewport()
	            updateFeedback(true)

	            inp.Changed:Connect(function()
	                if inp.UserInputState == Enum.UserInputState.End then
	                    stopDrag()
	                end
	            end)

	            if inputConn then pcall(function() inputConn:Disconnect() end) end
	            inputConn = _SvcRS.RenderStepped:Connect(function()
	                if not dragging then return end
	                
	                local cur = UserInputService:GetMouseLocation()
	                local delta = cur - dragStart
	                
	                local nx = startPos.X.Offset + delta.X
	                local ny = startPos.Y.Offset + delta.Y
	                
	                local sw, sh = dragW, dragH
	                if nx < 0 then nx = 0 elseif nx > viewport.X - sw then nx = viewport.X - sw end
	                if ny < 0 then ny = 0 elseif ny > viewport.Y - sh then ny = viewport.Y - sh end
	                
	                p.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
	            end)
	        end
	    end)

	    local hoverTween = nil
	    hdr.MouseEnter:Connect(function()
_playHoverSound()
	        if not dragging then
	            if hoverTween then pcall(function() hoverTween:Cancel() end) end
	            hoverTween = twP(dragHint, 0.15, {TextTransparency = 0.1})
	        end
	    end)
	    hdr.MouseLeave:Connect(function()
	        if not dragging then
	            if hoverTween then pcall(function() hoverTween:Cancel() end) end
	            hoverTween = twP(dragHint, 0.15, {TextTransparency = 0.5})
	        end
	    end)
	end
	-- ---------------------------------------------------------------------

panels[name] = p
-- Registry-Eintrag für Theme-Live-Update
table.insert(_panelAccentObjs, {
    stroke = pStroke, top = nil, sep = sep,
    rain = nil,       dot = nil, title = htitle,
    scan = nil, ib  = nil,
    sbt  = sbTrack,   sbth = sbThumb, cgrad = creditGrad,
    pf = p, hdrf = hdr, bodyGrad = bodyGrad, hdrGrad = hdrGrad, cgGrad = nil,
})
return p, scroll
end
local function setNoclip(on)
if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
if on then
noclipOrigCollide = {}
local ch = Character
noclipRebuildCache(ch)
if ch then
for _, part in ipairs(noclipCachedParts) do
noclipOrigCollide[part] = part.CanCollide
end
end
noclipConn = RunService.Heartbeat:Connect(function()
    local parts = noclipCachedParts
    local n = #parts
    if n == 0 then return end
    for i = 1, n do
        local p = parts[i]
        if p then p.CanCollide = false end
    end
end)
else
for _, part in ipairs(noclipCachedParts) do
if part and part.Parent then
if part.Name == "HumanoidRootPart" then
part.CanCollide = false
elseif noclipOrigCollide[part] ~= nil then
part.CanCollide = noclipOrigCollide[part]
else
part.CanCollide = true
end
end
end
noclipOrigCollide = {}
noclipCachedParts = {}
end
end
-- -- Forward-declarations (M-1 / M-3 fix) ---------------------------------
-- These upvalues are used by the Invis-Heartbeat and safeStand loops below
-- but are assigned their real values/tables much later in the file.
-- Declaring them here as upvalues ensures the closures capture the correct
-- slot instead of accidentally reading globals (nil).
local ppActive       = false
local _act_following = false
local _SOH           = nil   -- filled at ~10791 (assignment, no new local)
local _AF            = nil   -- filled at ~10915 (assignment, no new local)
-- --------------------------------------------------------------------------
-- TL Invisible System (Standalone integration)
-- Character teleported to Y = -200000, camera offset compensates
-- All parts set to Transparency = 0.99
-- Server-side invisible
-- --------------------------------------------------------------------------
local invisActive = false
local invisParts = {}
local invisHeartConn = nil
local _invisHealthConn = nil
local _invisHL = nil
local _invisSavedCF = nil
local _invisRespConn = nil
local _invisTogConn = nil
local _hasRenderStepped = pcall(function()
local c = _SvcRS.RenderStepped:Connect(function() end); c:Disconnect()
end)
local function _RSConnect(fn)
if _hasRenderStepped then
local ok, conn = pcall(function() return _SvcRS.RenderStepped:Connect(fn) end)
if ok and conn then return conn end
end
return _SvcRS.Heartbeat:Connect(fn)
end

-- Cleanup bei erneutem Ausführen
if _G._TLInvisConn     then pcall(function() _G._TLInvisConn:Disconnect()       end); _G._TLInvisConn     = nil end
if _G._TLInvisHConn    then pcall(function() _G._TLInvisHConn:Disconnect()      end); _G._TLInvisHConn    = nil end
if _G._TLInvisTogConn  then pcall(function() _G._TLInvisTogConn:Disconnect()    end); _G._TLInvisTogConn  = nil end
if _G._TLInvisRespConn then pcall(function() _G._TLInvisRespConn:Disconnect()   end); _G._TLInvisRespConn = nil end
if _G._TLInvisHL and _G._TLInvisHL.Parent then
pcall(function() _G._TLInvisHL:Destroy() end); _G._TLInvisHL = nil
end
if _G._TLInvisActive then
local ch = LocalPlayer.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum.CameraOffset = Vector3.zero end) end
end
_G._TLInvisActive = false

local function _makeInvisSelfHL(ch)
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
if not PlayerGui then return nil end
local ok, hl = pcall(function()
local h = Instance.new("Highlight")
h.Adornee             = ch
h.FillColor           = Color3.fromRGB(255, 255, 255)
h.OutlineColor        = Color3.fromRGB(0, 210, 255)
h.FillTransparency    = 0.5
h.OutlineTransparency = 0.0
h.Parent              = PlayerGui
return h
end)
if ok and hl and hl.Parent then return hl end
local ok2, sb = pcall(function()
local s = Instance.new("SelectionBox")
s.Adornee           = ch:FindFirstChild("HumanoidRootPart") or ch
s.Color3            = Color3.fromRGB(0, 210, 255)
s.LineThickness     = 0.06
s.SurfaceTransparency = 0.85
s.SurfaceColor3     = Color3.fromRGB(0, 210, 255)
s.Parent            = PlayerGui
return s
end)
if ok2 and sb and sb.Parent then return sb end
return nil
end

local function invisSetupParts()
invisParts = {}
local ch = LocalPlayer.Character
if not ch then return end
for _, d in ipairs(ch:GetDescendants()) do
if d:IsA("BasePart") and d.Transparency < 0.9 then
table.insert(invisParts, {part = d, origTransp = d.Transparency})
end
end
end

local function setInvis(on)
invisActive = on
_G._TLInvisActive = on

if invisHeartConn   then pcall(function() invisHeartConn:Disconnect()   end); invisHeartConn   = nil end
if _invisHealthConn then pcall(function() _invisHealthConn:Disconnect() end); _invisHealthConn = nil end
if _invisHL and _invisHL.Parent then pcall(function() _invisHL:Destroy() end); _invisHL = nil end
_G._TLInvisConn  = nil
_G._TLInvisHConn = nil
_G._TLInvisHL    = nil

local ch   = LocalPlayer.Character
local hum  = ch and ch:FindFirstChildOfClass("Humanoid")
local root = ch and ch:FindFirstChild("HumanoidRootPart")

if not on then
if root and _invisSavedCF then
pcall(function() root.CFrame = _invisSavedCF end)
root.AssemblyLinearVelocity = Vector3.zero
end
_invisSavedCF = nil
if hum then
hum.Health = hum.MaxHealth
pcall(function() hum.CameraOffset = Vector3.zero end)
end
for _, entry in ipairs(invisParts) do
local part = entry.part
if part and part.Parent then
pcall(function() part.Transparency = entry.origTransp end)
end
end
invisParts = {}
return
end

if not ch then return end
invisSetupParts()
_invisHL = _makeInvisSelfHL(ch)
_G._TLInvisHL = _invisHL

if hum then
pcall(function()
_invisHealthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
if not invisActive then return end
local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
if h2 and h2.Health < h2.MaxHealth then
pcall(function() h2.Health = h2.MaxHealth end)
end
end)
_G._TLInvisHConn = _invisHealthConn
end)
end

local _invCachedChar = LocalPlayer.Character
local _invCachedHum  = _invCachedChar and _invCachedChar:FindFirstChild("Humanoid")
local _invCachedRoot = _invCachedChar and _invCachedChar:FindFirstChild("HumanoidRootPart")

invisHeartConn = _SvcRS.Heartbeat:Connect(function()
local c = LocalPlayer.Character
if c ~= _invCachedChar then
_invCachedChar = c
_invCachedHum  = c and c:FindFirstChild("Humanoid")
_invCachedRoot = c and c:FindFirstChild("HumanoidRootPart")
end

local h = _invCachedHum
local r = _invCachedRoot
if not (invisActive and h and r) then return end

for _, entry in ipairs(invisParts) do
local part = entry.part
if part and part.Parent and part.Transparency < 0.98 then
part.Transparency = 0.99
end
end

local curCF = r.CFrame
if curCF.Position.Y > -100000 then
_invisSavedCF = curCF
end

local origOff = Vector3.zero
pcall(function() origOff = h.CameraOffset end)

pcall(function()
r.CFrame       = CFrame.new(curCF.Position.X, -200000, curCF.Position.Z)
h.CameraOffset = Vector3.new(0, curCF.Position.Y + 200000, 0)
end)

task.spawn(function()
if _hasRenderStepped then
pcall(function() _SvcRS.RenderStepped:Wait() end)
else
task.wait()
end
if not invisActive then return end
pcall(function()
r.CFrame       = curCF
h.CameraOffset = origOff
end)
end)
end)
_G._TLInvisConn = invisHeartConn
end

-- Respawn-Cleanup
_invisRespConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
if invisActive then
if invisHeartConn   then pcall(function() invisHeartConn:Disconnect()   end); invisHeartConn   = nil end
if _invisHealthConn then pcall(function() _invisHealthConn:Disconnect() end); _invisHealthConn = nil end
if _invisHL and _invisHL.Parent then pcall(function() _invisHL:Destroy() end); _invisHL = nil end

for _, entry in ipairs(invisParts) do
pcall(function()
if entry.part and entry.part.Parent then
entry.part.Transparency = entry.origTransp
end
end)
end
invisParts    = {}
_invisSavedCF = nil

task.defer(function()
local newHum = newChar:FindFirstChildOfClass("Humanoid")
if newHum then pcall(function() newHum.CameraOffset = Vector3.zero end) end
end)
else
invisParts    = {}
_invisSavedCF = nil
if _invisHL and _invisHL.Parent then pcall(function() _invisHL:Destroy() end); _invisHL = nil end
end

task.wait(0.5)
if invisActive then
invisSetupParts()
_invisHL = _makeInvisSelfHL(newChar)
_G._TLInvisHL = _invisHL
setInvis(true)
else
task.wait(0.5)
invisSetupParts()
end
end)
_G._TLInvisRespConn = _invisRespConn

-- --------------------------------------------------------------
-- --------------------------------------------------------------
--  FLY SYSTEM V4 (TL FLY SYSTEM V4 - HUD + Main Panel)
-- --------------------------------------------------------------
-- Outer locals for TLMenu integration
local flyActive       = false
local setFly          = nil 
local _flyMuteSounds  = function() end -- Stub for compatibility

local GLOBAL_ENV_FLY  = (typeof(getgenv) == "function" and getgenv()) or _G
local RUNTIME_KEY_FLY = "__TLFly_V4_Runtime"

local prevFly = GLOBAL_ENV_FLY and GLOBAL_ENV_FLY[RUNTIME_KEY_FLY]
if type(prevFly) == "table" and type(prevFly.cleanup) == "function" then
    pcall(prevFly.cleanup)
end

local runtimeFly = { connections = {}, instances = {}, destroyed = false }
runtimeFly.cleanup = function()
    if runtimeFly.destroyed then return end
    runtimeFly.destroyed = true
    pcall(function() if clearESP then clearESP() end end)
    for _, c in ipairs(runtimeFly.connections) do pcall(function() c:Disconnect() end) end
    runtimeFly.connections = {}
    for i = #runtimeFly.instances, 1, -1 do
        local inst = runtimeFly.instances[i]
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end
    runtimeFly.instances = {}
    if GLOBAL_ENV_FLY and GLOBAL_ENV_FLY[RUNTIME_KEY_FLY] == runtimeFly then GLOBAL_ENV_FLY[RUNTIME_KEY_FLY] = nil end
end
if GLOBAL_ENV_FLY then GLOBAL_ENV_FLY[RUNTIME_KEY_FLY] = runtimeFly end

local function registerFlyInstance(inst)
    table.insert(runtimeFly.instances, inst)
    return inst
end

local function bindFly(signal, handler)
    local c = signal:Connect(handler)
    table.insert(runtimeFly.connections, c)
    return c
end

do -- Inner scope for Fly V4
    local flying     = false
    local hasBoosted = false
    local speedIndex = 1
    local ctrl       = {f=0, b=0, l=0, r=0}
    local lastctrl   = {f=0, b=0, l=0, r=0}
    local bg, bv     = nil, nil
    local Camera     = workspace.CurrentCamera


    -- -- Geschwindigkeitsstufen ------------------------------------------------
    local speedLevels = {
        { name="GLIDE",  speed=55,  accel=2.1,  decel=1.1, color=Color3.fromRGB(100,200,255), bar=0.3 },
        { name="NORMAL", speed=110, accel=4.5,  decel=2.2, color=Color3.fromRGB(120,200,255), bar=0.5 },
        { name="FAST",   speed=140, accel=5.5,  decel=3.5, color=Color3.fromRGB(255,150,100), bar=0.7 },
        { name="TURBO",  speed=250, accel=10.0, decel=6.5, color=Color3.fromRGB(255,80,80),   bar=1.0 },
    }
    local function getSpeedData(i) return speedLevels[i] end

    -- -- Animation Sets ---------------------------------------------------------
    local animSets = {
        { name="TLFly",          idle="116197008542581", fwd="123428149037867", glide="80246529759410"  },
        { name="Ultra Instinct", idle="114324868852513", fwd="94968443049984",  glide="78718725442144"  },
        { name="Mysterious",     idle="121818495967360", fwd="138488768673643", glide="101573394483995" },
        { name="Tests",          idle="116197008542581", fwd="128582748149019", glide="80246529759410"  },
        { name="Set 5",          idle="116197008542581", fwd="123428149037867", glide="80246529759410"  },
    }
    local currentAnimSet = 1
    local animSetButtons  = {}

    -- -- GUI Creation --
    local ScreenGui = registerFlyInstance(Instance.new("ScreenGui"))
    ScreenGui.Name           = "FlyGui_V4"
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn   = false

    local Wrapper = Instance.new("Frame")
    Wrapper.Name                   = "Wrapper"
    Wrapper.Size                   = UDim2.new(0, 210, 0, 180)
    Wrapper.Position               = UDim2.new(0.5, -105, 0.5, -90)
    Wrapper.BackgroundTransparency = 1
    Wrapper.BorderSizePixel        = 0
    Wrapper.Active                 = true
    Wrapper.Draggable              = true
    Wrapper.Parent                 = ScreenGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Name                   = "MainFrame"
    MainFrame.Size                   = UDim2.new(1, 0, 0, 180)
    MainFrame.BackgroundColor3       = C.panelBg
    MainFrame.BackgroundTransparency = 0
    MainFrame.BorderSizePixel        = 0
    MainFrame.Parent                 = Wrapper
    stylePanelSurface(MainFrame, 10, 0)

    local mStroke = _makeDummyStroke()
    mStroke.Thickness    = 1.5; mStroke.Color = C.accent; mStroke.Transparency = 0.2; mStroke.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 28); Title.BackgroundTransparency = 1; Title.Text = "FLY CONTROLS"; Title.TextColor3 = C.accent
    Title.Font = Enum.Font.GothamBold; Title.TextSize = 13; Title.Parent = MainFrame

    local ButtonContainer = Instance.new("Frame")
    ButtonContainer.Size = UDim2.new(1, -20, 1, -36); ButtonContainer.Position = UDim2.new(0, 10, 0, 33); ButtonContainer.BackgroundTransparency = 1; ButtonContainer.Parent = MainFrame
    local UIListLayout = Instance.new("UIListLayout"); UIListLayout.Padding = UDim.new(0, 7); UIListLayout.Parent = ButtonContainer

    local function createButton(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 28); btn.BackgroundColor3 = C.bg3; btn.BackgroundTransparency = 0.2
        btn.TextColor3 = C.text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.Text = text; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
        corner(btn, 8)
        local s = stroke(btn, 1, C.accent, 0.45)
        bindFly(btn.MouseEnter, function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.accent, BackgroundTransparency = 0.3, TextColor3 = Color3.new(1,1,1)}):Play() end)
        bindFly(btn.MouseLeave, function() TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2, TextColor3 = C.text}):Play() end)
        bindFly(btn.MouseButton1Click, callback); return btn
    end

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, 0, 0, 16); StatusLabel.BackgroundTransparency = 1; StatusLabel.Text = "Status: OFF  |  GLIDE"; StatusLabel.TextColor3 = C.sub
    StatusLabel.Font = Enum.Font.GothamBold; StatusLabel.TextSize = 10; StatusLabel.TextXAlignment = Enum.TextXAlignment.Center; StatusLabel.Parent = ButtonContainer

    local ToggleBtn
    ToggleBtn = createButton("✈  Toggle Fly  [F]", function() setFly(not flying) end)
    ToggleBtn.Parent = ButtonContainer

    local SpeedBtn = createButton("⚡  Speed: GLIDE  [Q]", function()
        if flying then speedIndex = (speedIndex % #speedLevels) + 1; hasBoosted = true; updateHUD() end
    end)
    SpeedBtn.Parent = ButtonContainer

    local SpeedRow = Instance.new("Frame")
    SpeedRow.Size = UDim2.new(1, 0, 0, 28); SpeedRow.BackgroundTransparency = 1; SpeedRow.Parent = ButtonContainer
    local MinusBtn = createButton("−", function() if speedIndex > 1 then speedIndex -= 1; hasBoosted = true; updateHUD() end end)
    MinusBtn.Size = UDim2.new(0.42, 0, 1, 0); MinusBtn.Parent = SpeedRow
    local PlusBtn = createButton("+", function() if speedIndex < #speedLevels then speedIndex += 1; hasBoosted = true; updateHUD() end end)
    PlusBtn.Size = UDim2.new(0.42, 0, 1, 0); PlusBtn.Position = UDim2.new(0.58, 0, 0, 0); PlusBtn.Parent = SpeedRow

    -- -- Dropdown Pill --
    local PILL_COLLAPSED_H, PILL_EXPANDED_H, PILL_GAP = 22, 168, 6
    local dropOpen = false
    local PillOuter = Instance.new("Frame")
    PillOuter.Size = UDim2.new(1, 0, 0, PILL_COLLAPSED_H); PillOuter.Position = UDim2.new(0, 0, 0, 180 + PILL_GAP); PillOuter.BackgroundColor3 = C.panelBg
    PillOuter.BackgroundTransparency = 0.1; PillOuter.BorderSizePixel = 0; PillOuter.ClipsDescendants = true; PillOuter.Parent = Wrapper
    corner(PillOuter, 10)
    local pillStroke = _makeDummyStroke(); pillStroke.Color = C.accent; pillStroke.Thickness = 1; pillStroke.Transparency = 0.55; pillStroke.Parent = PillOuter
    local PillHeader = Instance.new("TextButton")
    PillHeader.Size = UDim2.new(1, 0, 0, PILL_COLLAPSED_H); PillHeader.BackgroundTransparency = 1; PillHeader.Text = ""; PillHeader.AutoButtonColor = false; PillHeader.Parent = PillOuter
    local Arrow = Instance.new("TextLabel")
    Arrow.Size = UDim2.new(0, 16, 0, 16); Arrow.Position = UDim2.new(1, -20, 0.5, -8); Arrow.BackgroundTransparency = 1; Arrow.Text = "▾"; Arrow.TextColor3 = Color3.fromRGB(160, 210, 255); Arrow.Font = Enum.Font.GothamBold; Arrow.TextSize = 12; Arrow.Parent = PillHeader
    local PillLabel = Instance.new("TextLabel")
    PillLabel.Size = UDim2.new(1, -30, 1, 0); PillLabel.Position = UDim2.new(0, 10, 0, 0); PillLabel.BackgroundTransparency = 1; PillLabel.Text = "Anim: " .. animSets[currentAnimSet].name; PillLabel.TextColor3 = Color3.fromRGB(160, 210, 255); PillLabel.Font = Enum.Font.GothamSemibold; PillLabel.TextSize = 10; PillLabel.TextXAlignment = Enum.TextXAlignment.Left; PillLabel.Parent = PillHeader

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -8, 0, PILL_EXPANDED_H - PILL_COLLAPSED_H - 4); ScrollFrame.Position = UDim2.new(0, 4, 0, PILL_COLLAPSED_H + 2); ScrollFrame.BackgroundTransparency = 1; ScrollFrame.BorderSizePixel = 0; ScrollFrame.ScrollBarThickness = 3; ScrollFrame.ScrollBarImageColor3 = C.accent; ScrollFrame.ScrollBarImageTransparency = 0.4; ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y; ScrollFrame.Parent = PillOuter
    local scrollLayout = Instance.new("UIListLayout"); scrollLayout.Padding = UDim.new(0, 5); scrollLayout.Parent = ScrollFrame
    local scrollPadding = Instance.new("UIPadding"); scrollPadding.PaddingTop = UDim.new(0, 4); scrollPadding.PaddingBottom = UDim.new(0, 4); scrollPadding.PaddingLeft = UDim.new(0, 3); scrollPadding.Parent = ScrollFrame

    local function refreshAnimRows()
        for i, btn in ipairs(animSetButtons) do
            local isActive = (i == currentAnimSet)
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = isActive and (C.bg3 or Color3.fromRGB(22, 22, 22)) or C.panelBg, BackgroundTransparency = isActive and 0.15 or 0.5}):Play()
            local stroke = btn:FindFirstChildOfClass("UIStroke"); if stroke then stroke.Color = isActive and C.accent or Color3.fromRGB(80, 100, 120); stroke.Transparency = isActive and 0.2 or 0.7 end
            local label = btn:FindFirstChild("NameLabel"); if label then label.TextColor3 = isActive and C.accent or Color3.fromRGB(180, 200, 220) end
            local dot = btn:FindFirstChild("ActiveDot"); if dot then dot.Visible = isActive end
        end
        PillLabel.Text = "Anim: " .. animSets[currentAnimSet].name
    end

    local function switchAnimSet(index)
        currentAnimSet = index; refreshAnimRows()
        if flying then
            if flyTrack then flyTrack:Stop(); flyTrack = nil end
            if flyFwdTrack then flyFwdTrack:Stop(); flyFwdTrack = nil end
            if flyGlideTrack then flyGlideTrack:Stop(); flyGlideTrack = nil end
            local s = animSets[currentAnimSet]
            flyTrack = loadTrackFromId(s.idle); flyFwdTrack = loadTrackFromId(s.fwd); flyGlideTrack = loadTrackFromId(s.glide)
            if flyTrack then flyTrack:Play() end
        end
    end

    for i, set in ipairs(animSets) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, 26); row.BackgroundColor3 = C.panelBg; row.BackgroundTransparency = 0.5; row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Text = ""; row.Parent = ScrollFrame
        corner(row, 7)
        local rs2 = _makeDummyStroke(); rs2.Color = Color3.fromRGB(80, 100, 120); rs2.Thickness = 0.8; rs2.Transparency = 0.7; rs2.Parent = row
        local numLbl = Instance.new("TextLabel"); numLbl.Size = UDim2.new(0, 20, 1, 0); numLbl.Position = UDim2.new(0, 6, 0, 0); numLbl.BackgroundTransparency = 1; numLbl.Text = tostring(i); numLbl.TextColor3 = Color3.fromRGB(100, 140, 180); numLbl.Font = Enum.Font.GothamBold; numLbl.TextSize = 10; numLbl.Parent = row
        local nameLbl = Instance.new("TextLabel"); nameLbl.Name = "NameLabel"; nameLbl.Size = UDim2.new(1, -46, 1, 0); nameLbl.Position = UDim2.new(0, 28, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Text = set.name; nameLbl.TextColor3 = Color3.fromRGB(180, 200, 220); nameLbl.Font = Enum.Font.Gotham; nameLbl.TextSize = 10; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = row
        local dot = Instance.new("Frame"); dot.Name = "ActiveDot"; dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(1, -14, 0.5, -3); dot.BackgroundColor3 = C.accent; dot.BorderSizePixel = 0; dot.Visible = (i == 1); dot.Parent = row
        corner(dot, 99)
        bindFly(row.MouseButton1Click, function() switchAnimSet(i) end)
        animSetButtons[i] = row
    end

    bindFly(PillHeader.MouseButton1Click, function()
        dropOpen = not dropOpen
        local targetH = dropOpen and PILL_EXPANDED_H or PILL_COLLAPSED_H
        Arrow.Text = dropOpen and "▴" or "▾"
        TweenService:Create(PillOuter, TweenInfo.new(0.22), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
        TweenService:Create(Wrapper, TweenInfo.new(0.22), {Size = UDim2.new(0, 210, 0, 180 + PILL_GAP + targetH)}):Play()
    end)

    -- -- Mini HUD --
    local hudGui, hudSpeedLabel, hudFill, hudStroke2
    function buildHUD()
        pcall(function() if LocalPlayer.PlayerGui:FindFirstChild("FlyHUD") then LocalPlayer.PlayerGui.FlyHUD:Destroy() end end)
        hudGui = registerFlyInstance(Instance.new("ScreenGui")); hudGui.Name = "FlyHUD"; hudGui.ResetOnSpawn = false; hudGui.Parent = LocalPlayer.PlayerGui
        local frame = Instance.new("Frame"); frame.Size = UDim2.fromOffset(180, 48); frame.Position = UDim2.new(0.5, 0, 0, 40); frame.AnchorPoint = Vector2.new(0.5, 0); frame.BackgroundColor3 = C.panelBg; frame.BackgroundTransparency = 0.1; frame.Parent = hudGui
        stylePanelSurface(frame, 10); hudStroke2 = frame:FindFirstChildOfClass("UIStroke")
        hudSpeedLabel = Instance.new("TextLabel"); hudSpeedLabel.Size = UDim2.new(1, 0, 0.55, 0); hudSpeedLabel.Position = UDim2.fromScale(0, 0.05); hudSpeedLabel.BackgroundTransparency = 1; hudSpeedLabel.Parent = frame
        applyTextStyle(hudSpeedLabel, 15)
        local barBg = Instance.new("Frame"); barBg.Size = UDim2.new(0.85, 0, 0, 4); barBg.Position = UDim2.new(0.5, 0, 0.78, 0); barBg.AnchorPoint = Vector2.new(0.5, 0.5); barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35); barBg.BorderSizePixel = 0; barBg.Parent = frame; corner(barBg, 4)
        hudFill = Instance.new("Frame"); hudFill.Size = UDim2.fromScale(0, 1); hudFill.BackgroundColor3 = C.accent; hudFill.BorderSizePixel = 0; hudFill.Parent = barBg; corner(hudFill, 4)
    end
    function updateHUD()
        local data = getSpeedData(speedIndex)
        if not data then return end
        if SpeedBtn then SpeedBtn.Text = "⚡  Speed: " .. data.name .. "  [Q]" end
        StatusLabel.Text = "Status: " .. (flying and "ACTIVE" or "OFF") .. "  |  " .. data.name
        TweenService:Create(mStroke, TweenInfo.new(0.2), {Color = data.color}):Play()
        TweenService:Create(pillStroke, TweenInfo.new(0.2), {Color = data.color}):Play()
        if hudSpeedLabel then hudSpeedLabel.Text = data.name; hudSpeedLabel.TextColor3 = data.color end
        if hudStroke2 then TweenService:Create(hudStroke2, TweenInfo.new(0.2), {Color = data.color}):Play() end
        if hudFill then TweenService:Create(hudFill, TweenInfo.new(0.15), {Size = UDim2.new(data.bar, 0, 1, 0), BackgroundColor3 = data.color}):Play() end
        if speedIndex == 4 then local flash = registerFlyInstance(Instance.new("Frame", hudGui)); flash.Size = UDim2.new(1,0,1,0); flash.BackgroundColor3 = Color3.new(1,1,1); flash.BackgroundTransparency = 0.9; TweenService:Create(flash, TweenInfo.new(0.2), {BackgroundTransparency=1}):Play(); task.delay(0.2, function() flash:Destroy() end) end
    end

    -- -- Animation loading --
    local flyTrack, flyFwdTrack, flyGlideTrack = nil, nil, nil
    local _isFwdAnim, _isGlideIdle = false, false
    local function loadTrackFromId(id)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
        local resolvedId = "rbxassetid://" .. id
        pcall(function()
            local objects = game:GetObjects(resolvedId)
            if objects and objects[1] then
                if objects[1]:IsA("Animation") then resolvedId = objects[1].AnimationId
                elseif objects[1]:FindFirstChildOfClass("Animation") then resolvedId = objects[1]:FindFirstChildOfClass("Animation").AnimationId end
                objects[1].Parent = workspace; task.delay(0.5, function() pcall(function() objects[1]:Destroy() end) end)
            end
        end)
        local anim = Instance.new("Animation"); anim.AnimationId = resolvedId
        local track = animator:LoadAnimation(anim); track.Priority = Enum.AnimationPriority.Action4; track.Looped = true; return track
    end

    -- -- Start/Stop Logic --
    local function startFly()
        flying = true; buildHUD(); updateHUD()
        local s = animSets[currentAnimSet]
        flyTrack = loadTrackFromId(s.idle); flyFwdTrack = loadTrackFromId(s.fwd); flyGlideTrack = loadTrackFromId(s.glide)
        if flyTrack then flyTrack:Play() end
        _isFwdAnim = false; _isGlideIdle = false
        local myChar = LocalPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if not myHRP or not myHum then return end
        myHum.PlatformStand = true
        bg = Instance.new("BodyGyro", myHRP); bg.P = 3.5e4; bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9); bg.CFrame = myHRP.CFrame
        bv = Instance.new("BodyVelocity", myHRP); bv.Velocity = Vector3.new(0, 0.1, 0); bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        local psConn = bindFly(RunService.Heartbeat, function() if flying and myHum then myHum.PlatformStand = true end end)
        local currentVel = Vector3.new(0, 0, 0); local smoothTilt = 0; local driftTime = 0
        while flying do
            local dt = RunService.Heartbeat:Wait(); driftTime = driftTime + dt
            local cam = Camera.CFrame; local lvl = getSpeedData(speedIndex); if not lvl then break end
            local moveSpeed = lvl.speed; local accel = lvl.accel; local decel = lvl.decel; local isGlide = (speedIndex == 1)
            -- Anim logic
            if ctrl.f == 1 and hasBoosted and not isGlide then
                if not _isFwdAnim then if _isGlideIdle and flyGlideTrack then flyGlideTrack:Stop() end; if flyTrack then flyTrack:Stop() end; if flyFwdTrack then flyFwdTrack:Play() end; _isFwdAnim = true; _isGlideIdle = false end
            elseif isGlide then
                if not _isGlideIdle then if _isFwdAnim and flyFwdTrack then flyFwdTrack:Stop() end; if flyTrack then flyTrack:Stop() end; if flyGlideTrack then flyGlideTrack:Play() end; _isGlideIdle = true; _isFwdAnim = false end
            else
                if _isFwdAnim or _isGlideIdle then if flyFwdTrack then flyFwdTrack:Stop() end; if flyGlideTrack then flyGlideTrack:Stop() end; if flyTrack then flyTrack:Play() end; _isFwdAnim = false; _isGlideIdle = false end
            end
            -- Velocity logic
            local inputVec = Vector3.new(0, 0, 0); local hasInput = (ctrl.l + ctrl.r ~= 0 or ctrl.f + ctrl.b ~= 0)
            if hasInput then
                local moveDir = ((cam.LookVector * (ctrl.f + ctrl.b)) + ((cam * CFrame.new(ctrl.l + ctrl.r, (ctrl.f + ctrl.b) * 0.18, 0)).Position - cam.Position)).Unit
                inputVec = moveDir * moveSpeed
            end
            if hasInput then currentVel = currentVel:Lerp(inputVec, math.min(1, accel * dt)) else currentVel = currentVel:Lerp(Vector3.new(0, 0.08 + math.sin(driftTime * 0.6) * 0.06, 0), math.min(1, decel * dt)) end
            if bv then bv.Velocity = currentVel end
            local targetTilt = (ctrl.f + ctrl.b) * 16; smoothTilt = smoothTilt + (targetTilt - smoothTilt) * math.min(1, 5 * dt)
            if bg then
                if _isFwdAnim and currentVel.Magnitude > 1 then
                    local flatDir = Vector3.new(currentVel.X, 0, currentVel.Z)
                    if flatDir.Magnitude > 0.01 then bg.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + flatDir) * CFrame.Angles(-math.rad(smoothTilt), 0, 0) end
                else bg.CFrame = cam * CFrame.Angles(-math.rad(smoothTilt * 0.6), math.sin(driftTime * 0.8) * 0.012, 0) end
            end
        end
        psConn:Disconnect()
        if flyTrack then flyTrack:Stop() end; if flyFwdTrack then flyFwdTrack:Stop() end; if flyGlideTrack then flyGlideTrack:Stop() end
        if bg then bg:Destroy(); bg = nil end; if bv then bv:Destroy(); bv = nil end
        if myHum then myHum.PlatformStand = false end; pcall(removeHUD)
    end

    function stopFly() flying = false end

    -- -- setFly integration --
    setFly = function(on)
        if on then
            if not flying then
                flying    = true
                flyActive = true
                task.spawn(startFly)
                if ToggleBtn then ToggleBtn.Text = "✈  Disable Fly  [F]" end
                if Wrapper   then Wrapper.Visible = true end
            end
        else
            if flying then
                flying    = false
                flyActive = false
                stopFly()
                if ToggleBtn then ToggleBtn.Text = "✈  Toggle Fly  [F]" end
                if Wrapper   then Wrapper.Visible = false end
            end
        end
    end

    -- Link for external menu/keybind updates (must be set for central keybind system)
    _flyPanelSetFn = setFly

    -- -- Movement Inputs Only (No F keybind here, it's in the central system) --
    bindFly(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Q and flyActive then
            speedIndex = (speedIndex % #speedLevels) + 1
            hasBoosted = true
            updateHUD()
        end
        if input.KeyCode == Enum.KeyCode.W then ctrl.f = 1 end
        if input.KeyCode == Enum.KeyCode.S then ctrl.b = -1 end
        if input.KeyCode == Enum.KeyCode.A then ctrl.l = -1 end
        if input.KeyCode == Enum.KeyCode.D then ctrl.r = 1 end
    end)


    bindFly(UserInputService.InputEnded, function(input)
        if input.KeyCode == Enum.KeyCode.W then ctrl.f = 0 end
        if input.KeyCode == Enum.KeyCode.S then ctrl.b = 0 end
        if input.KeyCode == Enum.KeyCode.A then ctrl.l = 0 end
        if input.KeyCode == Enum.KeyCode.D then ctrl.r = 0 end
    end)


    bindFly(LocalPlayer.CharacterAdded, function()
        if flyActive then setFly(false) end
    end)

    Wrapper.Visible = false -- Hidden by default
end

-- --------------------------------------------------------------
-- --------------------------------------------------------------
local noclipActive, _espRadConn = false, nil
local espData    = {}
local espCharConns = {}
local espEnabled = false
local ESP_COLORS = {
{ name = "White",   color = _C3_WHITE },
{ name = "Red",     color = _C3_DRED },
{ name = "Green",   color = Color3.fromRGB(60,230,100) },
{ name = "Blue",    color = Color3.fromRGB(60,140,255) },
{ name = "Cyan",    color = Color3.fromRGB(0,220,220) },
{ name = "Pink",    color = Color3.fromRGB(255,100,200) },
{ name = "Orange",  color = Color3.fromRGB(255,160,40) },
{ name = "Yellow",  color = Color3.fromRGB(255,230,40) },
{ name = "Purple",  color = Color3.fromRGB(180,80,255) },
{ name = "Black",   color = Color3.fromRGB(20,20,20) },
}
local espColorIdx      = 1
local ESP_NEAR_DIST_SQ = 110 * 110
local ESP_NAME_DIST_SQ = 110 * 110
local ESP_FILL_NEAR    = 0.6
local ESP_FILL_FAR     = 1.0
pcall(function()
    local cachedESPColor = _loadCache("esp_color")
    if cachedESPColor and cachedESPColor.idx then
        espColorIdx = cachedESPColor.idx
    end
end)
local function espCurrentColor()
return ESP_COLORS[espColorIdx].color
end
local espHighlights = {}
local espBillboards = {}
local function clearESP()
for pl, d in pairs(espData) do
if d.hl  and d.hl.Parent  then d.hl:Destroy()  end
if d.bb  and d.bb.Parent  then d.bb:Destroy()  end
end
espData      = {}
espHighlights = {}
espBillboards = {}
for _, c in pairs(espCharConns) do
if c then pcall(function() c:Disconnect() end) end
end
espCharConns = {}
end
local function applyESPToChar(pl, char)
if not espEnabled then return end
local d = espData[pl]
if d and d.hl and d.hl.Parent then d.hl:Destroy() end
if d and d.bb and d.bb.Parent then d.bb:Destroy() end
local col = espCurrentColor()
local hl
local hlOk = pcall(function()
hl = Instance.new("Highlight")
hl.Adornee             = char
hl.FillTransparency    = 1
hl.FillColor           = col
hl.OutlineColor        = col
hl.OutlineTransparency = 0
hl.Parent              = char
end)
if not hlOk or not hl or not hl.Parent then
pcall(function()
hl = Instance.new("SelectionBox")
hl.Adornee          = char:FindFirstChild("HumanoidRootPart") or char
hl.Color3           = col
hl.LineThickness    = 0
hl.SurfaceTransparency = 0.9
hl.SurfaceColor3    = col
hl.Parent           = char
end)
end
local head = char:FindFirstChild("Head")
local bb, lbl
if head then
pcall(function()
bb = Instance.new("BillboardGui")
bb.Name         = "ESP_BB"
bb.Adornee      = head
bb.Size         = UDim2.new(0, 120, 0, 20)
bb.StudsOffset  = Vector3.new(0, 2.4, 0)
bb.AlwaysOnTop  = true
bb.ResetOnSpawn = false
bb.Enabled      = true
bb.Parent       = head
lbl = Instance.new("TextLabel", bb)
lbl.Size                    = UDim2.new(1, 0, 1, 0)
lbl.BackgroundTransparency  = 1
lbl.Text                    = pl.DisplayName
lbl.Font                    = Enum.Font.GothamBlack
lbl.TextSize                = 13
lbl.TextColor3              = col
lbl.TextStrokeColor3        = _C3_BLACK
lbl.TextStrokeTransparency  = 0.4
lbl.TextTransparency        = 0
lbl.TextXAlignment          = Enum.TextXAlignment.Center
lbl.TextYAlignment          = Enum.TextYAlignment.Center
lbl.Name                    = "NameLbl"
end)
end
espData[pl] = { hl=hl, bb=bb, lbl=lbl, lastNear=false, lastNameVis=false }
espHighlights[pl] = hl
espBillboards[pl] = bb
end
local function addESPPlayer(pl)
    if not espEnabled or pl == LocalPlayer then return end
    if espCharConns[pl] then pcall(function() espCharConns[pl]:Disconnect() end) end
    espCharConns[pl] = bindFly(pl.CharacterAdded, function(char)
        if espData[pl] then espData[pl].cachedRoot = nil end
        task.wait(0.15)
        applyESPToChar(pl, char)
    end)
    if espData[pl] and espData[pl].hl and espData[pl].hl.Parent then return end
    espData[pl] = {}
    if pl.Character then
        applyESPToChar(pl, pl.Character)
    else
        task.spawn(function()
            local char = pl.Character
            if not char then
                local conn; conn = pl.CharacterAdded:Wait()
                char = conn
            end
            task.wait(0.15)
            if espEnabled and pl and pl.Parent then
                applyESPToChar(pl, pl.Character or char)
            end
        end)
    end
end
local function startESPRadiusLoop()
    if _espRadConn then _espRadConn:Disconnect() end
    local _espAcc = 0
    local _espMyRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    bindFly(LocalPlayer.CharacterAdded, function(char)
        task.wait(0.1)
        _espMyRoot = char:FindFirstChild("HumanoidRootPart")
    end)
    _espRadConn = bindFly(RunService.Heartbeat, function(dt)
        if not espEnabled then return end
        _espAcc = _espAcc + dt
        if _espAcc < 0.25 then return end
        _espAcc = 0
local myRoot = _espMyRoot
if not myRoot or not myRoot.Parent then
local c = LocalPlayer.Character
myRoot = c and c:FindFirstChild("HumanoidRootPart")
_espMyRoot = myRoot
end
if not myRoot then return end
local myPosX = myRoot.Position.X
local myPosY = myRoot.Position.Y
local myPosZ = myRoot.Position.Z
for pl, d in pairs(espData) do
local hl = d.hl
if hl and hl.Parent then
local tRoot = d.cachedRoot
if not tRoot or not tRoot.Parent then
local tChar = pl.Character
tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
d.cachedRoot = tRoot
end
local distSq = math.huge
if tRoot and tRoot.Parent then
local dx = tRoot.Position.X - myPosX
local dy = tRoot.Position.Y - myPosY
local dz = tRoot.Position.Z - myPosZ
distSq = dx*dx + dy*dy + dz*dz
end
local wantNear = distSq <= ESP_NEAR_DIST_SQ
if wantNear ~= d.lastNear then
hl.FillTransparency = wantNear and ESP_FILL_NEAR or 1
d.lastNear = wantNear
end
local bb = d.bb
if not bb or not bb.Parent then
local tChar = pl.Character
local tHead = tChar and tChar:FindFirstChild("Head")
bb = tHead and tHead:FindFirstChild("ESP_BB")
d.bb  = bb
d.lbl = bb and bb:FindFirstChild("NameLbl")
d.lastNameVis = false
end
if bb and bb.Parent and not d.lastNameVis then
bb.Enabled    = true
d.lastNameVis = true
end
end
end
end)
end
local function setESP(on)
espEnabled = on
clearESP()
if on then
for _, pl in ipairs(Players:GetPlayers()) do
if pl ~= LocalPlayer then
addESPPlayer(pl)
end
end
startESPRadiusLoop()
else
if _espRadConn then _espRadConn:Disconnect(); _espRadConn = nil end
end
end
local function refreshESPColor()
local col = espCurrentColor()
for pl, d in pairs(espData) do
if d.hl and d.hl.Parent then
d.hl.FillColor    = col
d.hl.OutlineColor = col
end
if d.lbl then d.lbl.TextColor3 = col end
end
end
Players.PlayerAdded:Connect(function(pl)
-- Mehrfach versuchen bis der Spieler wirklich geladen ist
task.spawn(function()
for attempt = 1, 6 do
task.wait(attempt == 1 and 0.5 or 1.0)
if not espEnabled then return end
if pl and pl.Parent then
addESPPlayer(pl)
-- Abbrechen sobald ESP erfolgreich gesetzt wurde
if espData[pl] and espData[pl].hl and espData[pl].hl.Parent then return end
end
end
end)
end)
Players.PlayerRemoving:Connect(function(pl)
local d = espData[pl]
if d then
if d.hl and d.hl.Parent then pcall(function() d.hl:Destroy() end) end
if d.bb and d.bb.Parent then pcall(function() d.bb:Destroy() end) end
espData[pl] = nil
end
espHighlights[pl] = nil
espBillboards[pl] = nil
if espCharConns[pl] then
pcall(function() espCharConns[pl]:Disconnect() end)
espCharConns[pl] = nil
end
end)
local function sendNotif(title, text, dur, accentOverride)
	if not settingsState.notifications then return end
	pcall(function()
		_SvcSG:SetCore("SendNotification", {
			Title    = "TLMenuSystem";
			Text     = tostring(text);
			Icon     = "rbxassetid://80783156310584";
			Duration = 5;
		})
	end)
end
pcall(function()
if getgenv then
_genv.TLSendNotif = sendNotif
end
end)
do
local _STAFF_NOTIFY = {
[136162036182779] = {
["soulofadore"]     = true,
["Gzupdrizzy"]      = true,
["CidsCurse"]       = true,
["7Zois"]           = true,
["DragoX_rblx"]     = true,
["tenwlk"]          = true,
["crashedfantasy"]  = true,
["HeavenlyHildeLu"] = true,
["o7nov"]           = true,
["cemalisiert"]     = true,
},
}
local staffList = _STAFF_NOTIFY[game.PlaceId]
if staffList then
for _, pl in ipairs(Players:GetPlayers()) do
if pl ~= LocalPlayer and staffList[pl.Name] then
sendNotif("⚠ Moderator", pl.Name .. " ist im Spiel", 6, Color3.fromRGB(255,200,80))
end
end
Players.PlayerAdded:Connect(function(pl)
if staffList[pl.Name] then
sendNotif("⚠ Moderator", "Moderator joined the game", 6, Color3.fromRGB(255,200,80))
end
end)
end
end
do
local p, c = makePanel("Home", C.accent)
p.BackgroundColor3   = C.panelBg
p.BackgroundTransparency = 0
for _, ch in ipairs(p:GetChildren()) do
if ch:IsA("UIGradient") then ch:Destroy() end
end
for _, ch in ipairs(p:GetChildren()) do
if ch:IsA("Frame") and ch.BackgroundTransparency >= 0.9 then
ch:Destroy(); break
end
end
for _, ch in ipairs(p:GetChildren()) do
if ch:IsA("Frame") and ch.Size.Y.Offset == 48 then
ch.BackgroundColor3 = C.panelHdr
ch.BackgroundTransparency = 0
local g = ch:FindFirstChildOfClass("UIGradient"); if g then g:Destroy() end
end
end
local HOME_EXTRA = (_TL_VP.isTouch and math.min(76, math.floor(_TL_VP.long * 0.065))) or 118
local HOME_W = math.floor(math.min(_TL_VP.long - 40, math.max(PANEL_W + HOME_EXTRA, 280)))
HOME_PANEL_W_OVERRIDE = HOME_W
p.Size = UDim2.new(0, HOME_W, 0, p.Size.Y.Offset)
local PAD   = 16
local PW    = HOME_W - PAD * 2
local Y     = 14
local function divider(yPos)
local d = Instance.new("Frame", c)
d.Size = UDim2.new(1,-PAD*2,0,1); d.Position = UDim2.new(0,PAD,0,yPos)
d.BackgroundColor3 = C.bg3 or _C3_BG4
d.BackgroundTransparency = 0.2; d.BorderSizePixel = 0
end
local _placeId = game.PlaceId
local _universeId = 0
pcall(function() _universeId = tonumber(game.GameId) or 0 end)
local _gameTitle = tostring(game.Name)
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset)
    if info and type(info.Name) == "string" and info.Name ~= "" then _gameTitle = info.Name end
end)
local _gameThumb = "rbxasset://textures/ui/GuiImagePlaceholder.png"
if _universeId > 0 then
    _gameThumb = "rbxthumb://type=GameIcon&id=" .. tostring(_universeId) .. "&w=256&h=256"
end
local _jobShow = nil
pcall(function()
    local j = game.JobId
    if j and tostring(j) ~= "" and tostring(j) ~= "00000000-0000-0000-0000-000000000000" then
        _jobShow = tostring(j)
    end
end)
local secGame = Instance.new("TextLabel", c)
secGame.Size = UDim2.new(1, -PAD*2, 0, 13)
secGame.Position = UDim2.new(0, PAD, 0, Y)
secGame.BackgroundTransparency = 1
secGame.Text = T.home_section_game
secGame.Font = Enum.Font.GothamBold; secGame.TextSize = 9
secGame.TextColor3 = C.sub or _C3_SUB
secGame.TextXAlignment = Enum.TextXAlignment.Left
Y = Y + 16
local GAME_CARD_H = 112
local gameCard = Instance.new("Frame", c)
gameCard.Size = UDim2.new(1, -PAD*2, 0, GAME_CARD_H)
gameCard.Position = UDim2.new(0, PAD, 0, Y)
gameCard.BackgroundColor3 = C.bg2 or _C3_BG2
gameCard.BorderSizePixel = 0
corner(gameCard, 12)
local gameCardS = _makeDummyStroke(gameCard)
gameCardS.Thickness = 1; gameCardS.Color = C.bg3 or _C3_BG3; gameCardS.Transparency = 0.28
local iconSz = 76
local iconWrap = Instance.new("Frame", gameCard)
iconWrap.Size = UDim2.new(0, iconSz, 0, iconSz)
iconWrap.Position = UDim2.new(0, 12, 0.5, -iconSz/2)
iconWrap.BackgroundColor3 = Color3.fromRGB(2, 12, 5)
iconWrap.BorderSizePixel = 0
corner(iconWrap, 10)
local iconWrapS = _makeDummyStroke(iconWrap)
iconWrapS.Thickness = 1; iconWrapS.Color = C.accent or C.bg3; iconWrapS.Transparency = 0.5
local gameIcon = Instance.new("ImageLabel", iconWrap)
gameIcon.Size = UDim2.new(1, -4, 1, -4)
gameIcon.Position = UDim2.new(0, 2, 0, 2)
gameIcon.BackgroundTransparency = 1
gameIcon.Image = _gameThumb
gameIcon.ScaleType = Enum.ScaleType.Crop
corner(gameIcon, 8)
local infoX = 12 + iconSz + 10
local gameTitleLbl = Instance.new("TextLabel", gameCard)
gameTitleLbl.Size = UDim2.new(1, -infoX - 10, 0, 22)
gameTitleLbl.Position = UDim2.new(0, infoX, 0, 10)
gameTitleLbl.BackgroundTransparency = 1
gameTitleLbl.Text = _gameTitle
gameTitleLbl.Font = Enum.Font.GothamBlack; gameTitleLbl.TextSize = 14
gameTitleLbl.TextColor3 = C.text or _C3_TEXT3
gameTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
gameTitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
local linePlace = Instance.new("TextLabel", gameCard)
linePlace.Size = UDim2.new(1, -infoX - 10, 0, 16)
linePlace.Position = UDim2.new(0, infoX, 0, 36)
linePlace.BackgroundTransparency = 1
linePlace.Text = T.home_place_id .. ":  " .. tostring(_placeId)
linePlace.Font = Enum.Font.GothamBold; linePlace.TextSize = 11
linePlace.TextColor3 = C.sub or _C3_SUB
linePlace.TextXAlignment = Enum.TextXAlignment.Left
local _metaY = 54
if _universeId > 0 then
    local lineUni = Instance.new("TextLabel", gameCard)
    lineUni.Size = UDim2.new(1, -infoX - 10, 0, 16)
    lineUni.Position = UDim2.new(0, infoX, 0, _metaY)
    lineUni.BackgroundTransparency = 1
    lineUni.Text = T.home_universe_id .. ":  " .. tostring(_universeId)
    lineUni.Font = Enum.Font.GothamBold; lineUni.TextSize = 11
    lineUni.TextColor3 = C.sub or _C3_SUB
    lineUni.TextXAlignment = Enum.TextXAlignment.Left
    _metaY = _metaY + 18
end
if _jobShow then
    local jt = _jobShow
    if #jt > 22 then jt = string.sub(jt, 1, 22) .. "?" end
    local lineJob = Instance.new("TextLabel", gameCard)
    lineJob.Size = UDim2.new(1, -infoX - 10, 0, 16)
    lineJob.Position = UDim2.new(0, infoX, 0, _metaY)
    lineJob.BackgroundTransparency = 1
    lineJob.Text = T.home_job_id .. ":  " .. jt
    lineJob.Font = Enum.Font.GothamBold; lineJob.TextSize = 11
    lineJob.TextColor3 = C.sub or _C3_SUB
    lineJob.TextXAlignment = Enum.TextXAlignment.Left
end
Y = Y + GAME_CARD_H + 12
divider(Y); Y = Y + 12
local secProf = Instance.new("TextLabel", c)
secProf.Size = UDim2.new(1, -PAD*2, 0, 13)
secProf.Position = UDim2.new(0, PAD, 0, Y)
secProf.BackgroundTransparency = 1
secProf.Text = T.home_section_profile
secProf.Font = Enum.Font.GothamBold; secProf.TextSize = 9
secProf.TextColor3 = C.sub or _C3_SUB
secProf.TextXAlignment = Enum.TextXAlignment.Left
Y = Y + 16
local PROF_CARD_H = 126
local profCard = Instance.new("Frame", c)
profCard.Size = UDim2.new(1, -PAD*2, 0, PROF_CARD_H)
profCard.Position = UDim2.new(0, PAD, 0, Y)
profCard.BackgroundColor3 = C.bg2 or _C3_BG2
profCard.BorderSizePixel = 0
corner(profCard, 12)
local profCardS = _makeDummyStroke(profCard)
profCardS.Thickness = 1; profCardS.Color = C.bg3 or _C3_BG3; profCardS.Transparency = 0.28
local profAvSize = 56
local profAvWrap = Instance.new("Frame", profCard)
profAvWrap.Size = UDim2.new(0, profAvSize, 0, profAvSize)
profAvWrap.Position = UDim2.new(0, 12, 0.5, -profAvSize/2)
profAvWrap.BackgroundColor3 = Color3.fromRGB(2, 14, 6)
profAvWrap.BorderSizePixel = 0
corner(profAvWrap, 99)
local profAvWrapS = _makeDummyStroke(profAvWrap)
profAvWrapS.Thickness = 1.5; profAvWrapS.Color = C.accent; profAvWrapS.Transparency = 0.38
local avClip = Instance.new("Frame", profAvWrap)
avClip.Size = UDim2.new(1,-4,1,-4); avClip.Position = UDim2.new(0,2,0,2)
avClip.BackgroundTransparency = 1; avClip.BorderSizePixel = 0
avClip.ClipsDescendants = true; corner(avClip, 99)
local homeAvatar = Instance.new("ImageLabel", avClip)
homeAvatar.Size = UDim2.new(1,0,1,0); homeAvatar.BackgroundTransparency = 1
homeAvatar.Image = "rbxassetid://142509179"
homeAvatar.ImageColor3 = C.sub or _C3_SUB
homeAvatar.ScaleType = Enum.ScaleType.Crop; homeAvatar.ZIndex = 5
task.spawn(function()
local ok, url = pcall(function()
return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
if ok and url and homeAvatar.Parent then
homeAvatar.Image = url
homeAvatar.ImageColor3 = _C3_WHITE
end
end)
local TX = 12 + profAvSize + 12
local nameLbl = Instance.new("TextLabel", profCard)
nameLbl.Size = UDim2.new(1, -(TX + 76), 0, 22)
nameLbl.Position = UDim2.new(0, TX, 0, 14)
nameLbl.BackgroundTransparency = 1
nameLbl.Text = LocalPlayer.DisplayName
nameLbl.Font = Enum.Font.GothamBlack; nameLbl.TextSize = 16
nameLbl.TextColor3 = C.text or Color3.fromRGB(230,232,245)
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
local tagLbl = Instance.new("TextLabel", profCard)
tagLbl.Size = UDim2.new(1, -(TX + 76), 0, 16)
tagLbl.Position = UDim2.new(0, TX, 0, 38)
tagLbl.BackgroundTransparency = 1
tagLbl.Text = "@" .. LocalPlayer.Name
tagLbl.Font = Enum.Font.GothamBold; tagLbl.TextSize = 11
tagLbl.TextColor3 = C.sub or _C3_SUB
tagLbl.TextXAlignment = Enum.TextXAlignment.Left
tagLbl.TextXAlignment = Enum.TextXAlignment.Left
tagLbl.TextTruncate = Enum.TextTruncate.AtEnd
local ageLbl = Instance.new("TextLabel", profCard)
ageLbl.Size = UDim2.new(1, -(TX + 76), 0, 14)
ageLbl.Position = UDim2.new(0, TX, 0, 54)
ageLbl.BackgroundTransparency = 1
local ageDays = LocalPlayer.AccountAge
ageLbl.Text = "Account Age: " .. tostring(ageDays) .. " days"
ageLbl.Font = Enum.Font.GothamBold; ageLbl.TextSize = 10
ageLbl.TextColor3 = C.sub or _C3_SUB
ageLbl.TextXAlignment = Enum.TextXAlignment.Left
local idLbl = Instance.new("TextLabel", profCard)
idLbl.Size = UDim2.new(1, -(TX + 76), 0, 14)
idLbl.Position = UDim2.new(0, TX, 0, 68)
idLbl.BackgroundTransparency = 1
idLbl.Text = "User ID: " .. tostring(LocalPlayer.UserId)
idLbl.Font = Enum.Font.GothamBold; idLbl.TextSize = 10
idLbl.TextColor3 = C.sub or _C3_SUB
idLbl.TextXAlignment = Enum.TextXAlignment.Left
local verF = Instance.new("Frame", profCard)
verF.Size = UDim2.new(0,64,0,24)
verF.Position = UDim2.new(1, -76, 0, 12)
verF.BackgroundColor3 = C.accent; verF.BackgroundTransparency = 0.82
verF.BorderSizePixel = 0; corner(verF, 8)
local verStr = _makeDummyStroke(verF)
verStr.Thickness = 1; verStr.Color = C.accent; verStr.Transparency = 0.5
local verLbl = Instance.new("TextLabel", verF)
verLbl.Size = UDim2.new(1,0,1,0); verLbl.BackgroundTransparency = 1
verLbl.Text = "TLMenu"; verLbl.Font = Enum.Font.GothamBlack; verLbl.TextSize = 11
verLbl.TextColor3 = C.accent; verLbl.TextXAlignment = Enum.TextXAlignment.Center
local profStatPill = Instance.new("Frame", profCard)
profStatPill.Size = UDim2.new(0, 100, 0, 24)
profStatPill.Position = UDim2.new(0, TX, 0, 88)
profStatPill.BackgroundColor3 = (_TL_activeThemeId == "matrix") and Color3.fromRGB(2, 18, 8) or C.bg2
profStatPill.BackgroundTransparency = 0.12
profStatPill.BorderSizePixel = 0
corner(profStatPill, 99)
local profStatPillS = _makeDummyStroke(profStatPill)
profStatPillS.Thickness = 1; profStatPillS.Color = C.accent; profStatPillS.Transparency = 0.65
local profDot = Instance.new("Frame", profStatPill)
profDot.Size = UDim2.new(0,6,0,6); profDot.Position = UDim2.new(0,10,0.5,-3)
profDot.BackgroundColor3 = C.accent; profDot.BorderSizePixel = 0; corner(profDot, 99)
local onLbl = Instance.new("TextLabel", profStatPill)
onLbl.Size = UDim2.new(1,-22,1,0); onLbl.Position = UDim2.new(0,20,0,0)
onLbl.BackgroundTransparency = 1; onLbl.Text = T.profile_online
onLbl.Font = Enum.Font.GothamBold; onLbl.TextSize = 11
onLbl.TextColor3 = C.accent; onLbl.TextXAlignment = Enum.TextXAlignment.Left
Y = Y + PROF_CARD_H + 12
divider(Y); Y = Y + 12
local CHIP_H   = 54
local CHIP_GAP = 8
local CHIP_W   = math.floor((HOME_W - PAD*2 - CHIP_GAP*2) / 3)
local statDefs = {
{ label="FPS",     icon="📊", kind="accent",  key="fps"     },
{ label="Ping",    icon="📡", kind="accent", key="ping"    },
{ label="Players", icon="👥", kind="orange", key="players" },
}
local function _homeChipDotCol(kind)
if kind == "orange" then return C.orange end
return C.accent
end
local homeStatLabels, homeChipDots = {}, {}
for i, stat in ipairs(statDefs) do
local xOff = PAD + (i-1) * (CHIP_W + CHIP_GAP)
local chip = Instance.new("Frame", c)
chip.Size = UDim2.new(0, CHIP_W, 0, CHIP_H)
chip.Position = UDim2.new(0, xOff, 0, Y)
chip.BackgroundColor3 = C.bg2 or _C3_BG2
chip.BackgroundTransparency = 0; chip.BorderSizePixel = 0
corner(chip, 12)
local chipStr = _makeDummyStroke(chip)
chipStr.Thickness = 1
chipStr.Color = C.bg3 or _C3_BG3
chipStr.Transparency = 0.3
local cdot = Instance.new("Frame", chip)
cdot.Size = UDim2.new(0,4,0,4); cdot.Position = UDim2.new(0,10,0,10)
cdot.BackgroundColor3 = _homeChipDotCol(stat.kind); cdot.BackgroundTransparency = 0
homeChipDots[stat.key] = { dot = cdot, kind = stat.kind }
cdot.BorderSizePixel = 0; corner(cdot, 99)
local valL = Instance.new("TextLabel", chip)
valL.Size = UDim2.new(1,-12,0,22); valL.Position = UDim2.new(0,10,0,16)
valL.BackgroundTransparency = 1; valL.Text = "◈"
valL.Font = Enum.Font.GothamBlack; valL.TextSize = 16
valL.TextColor3 = C.text or _C3_TEXT3
valL.TextXAlignment = Enum.TextXAlignment.Left
local subL = Instance.new("TextLabel", chip)
subL.Size = UDim2.new(1,-12,0,13); subL.Position = UDim2.new(0,10,0,36)
subL.BackgroundTransparency = 1; subL.Text = stat.label
subL.Font = Enum.Font.GothamBold; subL.TextSize = 9
subL.TextColor3 = C.sub or _C3_SUB
subL.TextXAlignment = Enum.TextXAlignment.Left
homeStatLabels[stat.key] = valL
end
local _fa, _ff, _sa = 0, 0, 0
local _homeSvcStats; pcall(function() _homeSvcStats = game:GetService("Stats") end)
local _homeStatPingItem; pcall(function()
    if _homeSvcStats then _homeStatPingItem = _homeSvcStats.Network.ServerStatsItem["Data Ping"] or _homeSvcStats.Network.ServerStatsItem["DataPing"] end
end)
local _homeMaxPlayers = game.Players.MaxPlayers
Y = Y + CHIP_H + 18
divider(Y); Y = Y + 14
local function sectionLbl(yPos, txt)
local lbl = Instance.new("TextLabel", c)
lbl.Size = UDim2.new(1,-PAD*2,0,13); lbl.Position = UDim2.new(0,PAD,0,yPos)
lbl.BackgroundTransparency = 1; lbl.Text = txt
lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
lbl.TextColor3 = C.sub or _C3_SUB
lbl.TextXAlignment = Enum.TextXAlignment.Left
end
sectionLbl(Y, "SERVER UTILS")
Y = Y + 18
local srvCard = Instance.new("Frame", c)
srvCard.Size = UDim2.new(1, -PAD*2, 0, 88)
srvCard.Position = UDim2.new(0, PAD, 0, Y)
srvCard.BackgroundColor3 = C.bg2 or _C3_BG2
srvCard.BorderSizePixel = 0; corner(srvCard, 12)
local srvCardS = _makeDummyStroke(srvCard)
srvCardS.Thickness = 1; srvCardS.Color = C.bg3 or _C3_BG3; srvCardS.Transparency = 0.28
local function makeSrvBtn(x, y, w, h, txt, sub, fn)
    local b = Instance.new("TextButton", srvCard)
    b.Size = UDim2.new(0, w, 0, h); b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = C.bg3 or _C3_BG3; b.BackgroundTransparency = 0.4
    b.BorderSizePixel = 0; b.Text = ""; corner(b, 8)
    local t1 = Instance.new("TextLabel", b)
    t1.Size = UDim2.new(1,0,0,18); t1.Position = UDim2.new(0,0,0,6)
    t1.BackgroundTransparency = 1; t1.Text = txt
    t1.Font = Enum.Font.GothamBlack; t1.TextSize = 11; t1.TextColor3 = C.text
    local t2 = Instance.new("TextLabel", b)
    t2.Size = UDim2.new(1,0,0,14); t2.Position = UDim2.new(0,0,0,20)
    t2.BackgroundTransparency = 1; t2.Text = sub
    t2.Font = Enum.Font.GothamBold; t2.TextSize = 9; t2.TextColor3 = C.sub
    b.MouseEnter:Connect(function() _playHoverSound(); tw(b, 0.1, {BackgroundTransparency = 0.2}):Play() end)
    b.MouseLeave:Connect(function() tw(b, 0.1, {BackgroundTransparency = 0.4}):Play() end)
    b.MouseButton1Click:Connect(fn)
end
local bw = (HOME_W - PAD*2 - 24 - 8) / 2
makeSrvBtn(12, 12, bw, 40, "Rejoin", "Current Server", function()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)
makeSrvBtn(12 + bw + 8, 12, bw, 40, "Server Hop", "New Server", function()
    local x = {}
    pcall(function()
        local data = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
        for _, v in ipairs(game:GetService("HttpService"):JSONDecode(data).data) do
            if v.maxPlayers > v.playing and v.id ~= game.JobId then x[#x + 1] = v.id end
        end
    end)
    if #x > 0 then game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, x[math.random(1, #x)]) end
end)
local rstBtn = Instance.new("TextButton", srvCard)
rstBtn.Position = UDim2.new(0, 12, 1, -22)
rstBtn.BackgroundTransparency = 1; rstBtn.Text = "Safe Reset Character"
rstBtn.Font = Enum.Font.GothamBold; rstBtn.TextSize = 9; rstBtn.TextColor3 = C.accent
rstBtn.MouseButton1Click:Connect(function() if LocalPlayer.Character then LocalPlayer.Character:BreakJoints() end end)
Y = Y + 88 + 12
divider(Y); Y = Y + 12
sectionLbl(Y, "MENU UTILS")
Y = Y + 16
local utilCard = Instance.new("Frame", c)
utilCard.Size = UDim2.new(1, -PAD*2, 0, 100)
utilCard.Position = UDim2.new(0, PAD, 0, Y)
utilCard.BackgroundColor3 = C.bg2 or _C3_BG2
utilCard.BorderSizePixel = 0; corner(utilCard, 12)
local utilCardS = _makeDummyStroke(utilCard)
utilCardS.Thickness = 1; utilCardS.Color = C.bg3 or _C3_BG3; utilCardS.Transparency = 0.28
local saveBtn = Instance.new("TextButton", utilCard)
saveBtn.Size = UDim2.new(1, -24, 0, 36); saveBtn.Position = UDim2.new(0, 12, 0, 12)
saveBtn.BackgroundColor3 = C.accent; saveBtn.BorderSizePixel = 0; corner(saveBtn, 10)
local saveLbl = Instance.new("TextLabel", saveBtn)
saveLbl.Size = UDim2.new(1,0,1,0); saveLbl.BackgroundTransparency = 1
saveLbl.Text = T.save_settings; saveLbl.Font = Enum.Font.GothamBlack; saveLbl.TextSize = 13; saveLbl.TextColor3 = _C3_WHITE
saveBtn.MouseButton1Click:Connect(function()
    saveData(); local o = saveLbl.Text; saveLbl.Text = "Saved ★"
    task.delay(2, function() pcall(function() saveLbl.Text = o end) end)
end)
local dcRow = Instance.new("Frame", utilCard)
dcRow.Size = UDim2.new(1,-24,0,36); dcRow.Position = UDim2.new(0,12,0,52)
dcRow.BackgroundColor3 = C.bg3 or _C3_BG3; dcRow.BackgroundTransparency = 0.5; corner(dcRow, 10)
local dcBtn = Instance.new("TextButton", dcRow)
dcBtn.Size = UDim2.new(1,0,1,0); dcBtn.BackgroundTransparency = 1; dcBtn.Text = "Join Discord"
dcBtn.Font = Enum.Font.GothamBold; dcBtn.TextSize = 11; dcBtn.TextColor3 = C.text
dcBtn.MouseButton1Click:Connect(function() pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/tXHG8jyxpb") end) end)
Y = Y + 100 + 20
_tlTrackConn(RunService.Heartbeat:Connect(function(dt)
if not _tlAlive() or not p.Visible then return end
_ff = _ff + 1; _fa = _fa + dt
if _fa >= 0.25 then
local fps = _mfloor(_ff / _fa); _fa = 0; _ff = 0
local l = homeStatLabels["fps"]
if l and l.Parent then
l.Text = fps .. " FPS"
l.TextColor3 = fps >= 55 and C.accent or (fps >= 30 and C.orange or C.red)
end
end
_sa = _sa + dt
if _sa >= 2 then _sa = 0
local lp = homeStatLabels["players"]
if lp and lp.Parent then
lp.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(_homeMaxPlayers)
lp.TextColor3 = C.orange or Color3.fromRGB(255,155,60)
end
local lping = homeStatLabels["ping"]
if lping and lping.Parent and _homeStatPingItem then
local ok, v = pcall(function() return _homeStatPingItem:GetValue() end)
if ok and v then
lping.Text = _mfloor(v) .. " ms"
lping.TextColor3 = v < 80 and C.accent or (v < 150 and C.orange or C.red)
end
end
end
end))
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function()
    for _, item in pairs(homeChipDots) do
        if item.dot and item.dot.Parent then
            item.dot.BackgroundColor3 = _homeChipDotCol(item.kind)
        end
    end
    pcall(function() saveBtn.BackgroundColor3 = C.accent end)
    pcall(function() profStatPillS.Color = C.accent end)
    pcall(function() profDot.BackgroundColor3 = C.accent end)
    pcall(function() onLbl.TextColor3 = C.accent end)
    pcall(function() verF.BackgroundColor3 = C.accent end)
    pcall(function() verStr.Color = C.accent end)
    pcall(function() verLbl.TextColor3 = C.accent end)
    pcall(function()
        profStatPill.BackgroundColor3 = (_TL_activeThemeId == "matrix") and Color3.fromRGB(2, 18, 8) or C.bg2
    end)
    pcall(function() p.BackgroundColor3 = C.panelBg end)
    for _, ch in ipairs(p:GetChildren()) do
        if ch:IsA("Frame") and ch.Size.Y.Offset == 48 then
            ch.BackgroundColor3 = C.panelHdr
        end
    end
end
p.Size = UDim2.new(0, HOME_W, 0, Y)
end
local createScriptWidget
do
local p, c = makePanel("Character", C.accent)
p.BackgroundColor3 = C.panelBg
p.BackgroundTransparency = 0
local _eg = p:FindFirstChildOfClass("UIGradient"); if _eg then _eg:Destroy() end
local PAD  = 16
local PW   = PANEL_W - PAD * 2
local CY   = 14
local function divider(yPos)
local d = Instance.new("Frame", c)
d.Size = UDim2.new(1,-PAD*2,0,1); d.Position = UDim2.new(0,PAD,0,yPos)
d.BackgroundColor3 = C.bg3 or _C3_BG4
d.BackgroundTransparency = 0.2; d.BorderSizePixel = 0
end
local function sectionLbl(yPos, txt)
local lbl = Instance.new("TextLabel", c)
lbl.Size = UDim2.new(1,-PAD*2,0,13); lbl.Position = UDim2.new(0,PAD,0,yPos)
lbl.BackgroundTransparency = 1; lbl.Text = txt
lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
lbl.TextColor3 = C.sub or _C3_SUB
lbl.TextXAlignment = Enum.TextXAlignment.Left
end
local CARD_H = 64
local function makeSliderRow(yPos, label, sublabel, col, vMin, vMax, vDef, onToggle, onReset, onSlide)
    local function liveCol() return _themePanelColor(col, C.accent) end
    local card = Instance.new("Frame", c)
    card.Size = UDim2.new(1,-PAD*2,0,CARD_H)
    card.Position = UDim2.new(0,PAD,0,yPos)
    card.BackgroundColor3 = C.bg2; card.BackgroundTransparency = 0; card.BorderSizePixel = 0
    corner(card, 12)
    local cStr = stroke(card, 1, C.bg3, 0.3)
    
    local cdot = Instance.new("Frame", card)
    cdot.Size = UDim2.new(0,3,0,CARD_H-20); cdot.Visible = false
    cdot.Position = UDim2.new(0,0,0.5,-(CARD_H-20)/2)
    cdot.BackgroundColor3 = liveCol(); cdot.BackgroundTransparency = 0.3
    cdot.BorderSizePixel = 0; corner(cdot, 99)
    
    local nameLbl = Instance.new("TextLabel", card)
    nameLbl.Size = UDim2.new(0,120,0,18); nameLbl.Position = UDim2.new(0,14,0,8)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = label
    nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13; nameLbl.TextColor3 = C.text
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local subLbl = Instance.new("TextLabel", card)
    subLbl.Size = UDim2.new(0,120,0,13); subLbl.Position = UDim2.new(0,14,0,26)
    subLbl.BackgroundTransparency = 1; subLbl.Text = sublabel
    subLbl.Font = Enum.Font.GothamBold; subLbl.TextSize = 9; subLbl.TextColor3 = C.sub
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local valLbl = Instance.new("TextLabel", card)
    valLbl.Size = UDim2.new(0,52,0,18); valLbl.Position = UDim2.new(1,-100,0,8)
    valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(vDef)
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 13; valLbl.TextColor3 = liveCol()
    valLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local rstBtn = Instance.new("TextButton", card)
    rstBtn.Size = UDim2.new(0,30,0,22); rstBtn.Position = UDim2.new(1,-136,0,5)
    rstBtn.BackgroundColor3 = C.bg3; rstBtn.BackgroundTransparency = 0.2
    rstBtn.Text = "R"; rstBtn.Font = Enum.Font.GothamBold; rstBtn.TextSize = 11; rstBtn.TextColor3 = C.sub; corner(rstBtn, 6)
    local rstStr = stroke(rstBtn, 1, C.bg3, 0.4)
    
    rstBtn.MouseEnter:Connect(function() twP(rstBtn, 0.1, {BackgroundColor3 = liveCol(), BackgroundTransparency = 0.6}) end)
    rstBtn.MouseLeave:Connect(function() twP(rstBtn, 0.1, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2}) end)
    
    local track = Instance.new("Frame", card)
    track.Size = UDim2.new(1,-28,0,4); track.Position = UDim2.new(0,14,1,-14)
    track.BackgroundColor3 = C.bg3; track.BackgroundTransparency = 0.4; corner(track, 99)
    
    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new((vDef-vMin)/(vMax-vMin),0,1,0)
    fill.BackgroundColor3 = liveCol(); fill.BorderSizePixel = 0; corner(fill, 99)
    
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0,12,0,12); knob.Position = UDim2.new((vDef-vMin)/(vMax-vMin),-6,0.5,-6)
    knob.BackgroundColor3 = Color3.new(1,1,1); knob.ZIndex = 5; corner(knob, 99)
    local kStr = stroke(knob, 1.5, liveCol(), 0)

    -- -- Ultra Instinct Slider Logic (Lerp + Loop) --------------------------
    local dragging, togState = false, false
    local curVal = vDef
    local sTargetV = (vDef-vMin)/(vMax-vMin)
    local sVisualV = sTargetV

    local function applyRatio(ratio)
        ratio = math.clamp(ratio, 0, 1)
        sTargetV = ratio
        curVal = math.floor(vMin + ratio*(vMax-vMin))
        valLbl.Text = tostring(curVal)
        if onSlide then onSlide(curVal, togState) end
    end

    -- Smooth Lerp Loop + Pulse (Ultra Instinct Reference)
    task.spawn(function()
        while card and card.Parent do
            local dt = task.wait()
            if not card.Visible then continue end
            -- Lerp
            sVisualV = sVisualV + (sTargetV - sVisualV) * math.min(dt * 22, 1)
            fill.Size = UDim2.new(sVisualV,0,1,0)
            knob.Position = UDim2.new(sVisualV,-6,0.5,-6)
            -- Pulse (Breathing effect on knob)
            local p = 0.65 + math.sin(os.clock()*5)*0.35
            knob.BackgroundTransparency = 0.05 * p
            kStr.Transparency = 0.15 * p
        end
    end)

    -- Mobile optimized interaction button (large 80x60 padding for easy grab)
    local sliderBtn = Instance.new("TextButton", track)
    sliderBtn.Size = UDim2.new(1,80,1,60); sliderBtn.Position = UDim2.new(0,-40,0,-30)
    sliderBtn.BackgroundTransparency = 1; sliderBtn.Text = ""; sliderBtn.ZIndex = 25
    
    local function upSlider(ip)
        if not track or not track.Parent then return end
        local ratio = math.clamp((ip.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        applyRatio(ratio)
    end

    sliderBtn.InputBegan:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.Touch then
            dragging = true; upSlider(ip.Position)
        end
    end)
    _SvcUIS.InputChanged:Connect(function(ip)
        if dragging and (ip.UserInputType == Enum.UserInputType.MouseMovement or ip.UserInputType == Enum.UserInputType.Touch) then
            upSlider(ip.Position)
        end
    end)
    sliderBtn.InputEnded:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local togTrack = Instance.new("Frame", card)
    togTrack.Size = UDim2.new(0, 32, 0, 18)
    togTrack.Position = UDim2.new(1, -44, 0, 11)
    togTrack.BackgroundColor3 = C.bg3 or _C3_BG3
    togTrack.BackgroundTransparency = 0.2
    togTrack.BorderSizePixel = 0
    corner(togTrack, 99)
    
    local togKnob = Instance.new("Frame", togTrack)
    togKnob.Size = UDim2.new(0, 12, 0, 12)
    togKnob.Position = UDim2.new(0, 2, 0.5, -6)
    togKnob.BackgroundColor3 = _C3_SUB2
    togKnob.BorderSizePixel = 0
    corner(togKnob, 99)

    local function setToggle(on)
        togState = on
        if on then
            twP(togTrack, 0.15, {BackgroundColor3 = liveCol(), BackgroundTransparency = 0.55})
            tw(togKnob,  0.15, {BackgroundColor3 = _C3_WHITE, Position = UDim2.new(1,-14,0.5,-6)}):Play()
            twP(cStr,     0.15, {Color = liveCol(), Transparency = 0.5})
            -- Sound bei Toggle ON
            pcall(function()
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://136697607304800"; sound.Volume = 0.5
                sound.Parent = workspace; sound:Play()
                _SvcDeb:AddItem(sound, 2)
            end)
        else
            twP(togTrack, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
            tw(togKnob,  0.15, {BackgroundColor3 = _C3_SUB2, Position = UDim2.new(0,2,0.5,-6)}):Play()
            twP(cStr,     0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.3})
        end
        if onToggle then onToggle(on, curVal) end
    end
    local togBtn = Instance.new("TextButton", card)
    togBtn.Size = UDim2.new(0,44,0,28); togBtn.Position = UDim2.new(1,-50,0,6)
    togBtn.BackgroundTransparency = 1; togBtn.Text = ""; togBtn.ZIndex = 7
    local _togDebounce = false
    togBtn.MouseButton1Click:Connect(function()
        if _togDebounce then return end; _togDebounce = true
        setToggle(not togState)
        task.wait(0.2); _togDebounce = false
    end)
    rstBtn.MouseButton1Click:Connect(function()
        applyRatio((vDef-vMin)/(vMax-vMin))
        if onReset then onReset(curVal) end
    end)
    card.MouseEnter:Connect(function() _playHoverSound() end)

    -- Live-Update bei Theme-Wechsel
    if _panelColorHooks then
        _panelColorHooks[#_panelColorHooks+1] = function()
            local ac = liveCol()
            pcall(function() cdot.BackgroundColor3 = ac end)
            pcall(function() fill.BackgroundColor3 = ac end)
            pcall(function() kStr.Color            = ac end)
            pcall(function() valLbl.TextColor3     = ac end)
            if togState then
                pcall(function() togTrack.BackgroundColor3 = ac end)
                pcall(function() cStr.Color                = ac end)
            end
        end
    end
    return card, setToggle, function() return togState end
end
local TOG_H = 46
local function makeToggleRow(yPos, label, sublabel, col, onToggle)
    local _colIsStatic = (col == C.red or col == C.orange)
    local function liveCol() return _colIsStatic and col or C.accent end
    local card = Instance.new("Frame", c)
    card.Size = UDim2.new(1,-PAD*2,0,TOG_H)
    card.Position = UDim2.new(0,PAD,0,yPos)
    card.BackgroundColor3 = C.bg2
    card.BackgroundTransparency = 0; card.BorderSizePixel = 0
    corner(card, 12)
    
    local cdot = Instance.new("Frame", card)
    cdot.Size = UDim2.new(0,3,0,TOG_H-16); cdot.Visible = false
    cdot.Position = UDim2.new(0,0,0.5,-(TOG_H-16)/2)
    cdot.BackgroundColor3 = liveCol(); cdot.BackgroundTransparency = 0.3
    cdot.BorderSizePixel = 0; corner(cdot, 99)
    
    local nameLbl = Instance.new("TextLabel", card)
    nameLbl.Size = UDim2.new(1,-60,0,18); nameLbl.Position = UDim2.new(0,14,0,7)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = label
    nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13; nameLbl.TextColor3 = C.text
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local subLbl = Instance.new("TextLabel", card)
    subLbl.Size = UDim2.new(1,-60,0,13); subLbl.Position = UDim2.new(0,14,0,25)
    subLbl.BackgroundTransparency = 1; subLbl.Text = sublabel
    subLbl.Font = Enum.Font.GothamBold; subLbl.TextSize = 9; subLbl.TextColor3 = C.sub
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local togTrack = Instance.new("Frame", card)
    togTrack.Size = UDim2.new(0,32,0,18); togTrack.Position = UDim2.new(1,-46,0.5,-9)
    togTrack.BackgroundColor3 = C.bg3; togTrack.BackgroundTransparency = 0.1; corner(togTrack, 99)
    
    local togKnob = Instance.new("Frame", togTrack)
    togKnob.Size = UDim2.new(0,12,0,12); togKnob.Position = UDim2.new(0,2,0.5,-6)
    togKnob.BackgroundColor3 = C.sub; togKnob.BackgroundTransparency = 0; corner(togKnob, 99)
    
    local togState = false
    local function setToggle(on)
        togState = on
        if on then
            twP(togTrack, 0.15, {BackgroundColor3 = liveCol(), BackgroundTransparency = 0.4})
            tw(togKnob,  0.15, {BackgroundColor3 = Color3.new(1,1,1), Position = UDim2.new(1,-14,0.5,-6)}):Play()
            pcall(function()
                local sound = Instance.new("Sound", workspace)
                sound.SoundId = "rbxassetid://136697607304800"; sound.Volume = 0.4; sound:Play()
                game:GetService("Debris"):AddItem(sound, 1)
            end)
        else
            twP(togTrack, 0.15, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.1})
            tw(togKnob,  0.15, {BackgroundColor3 = C.sub, Position = UDim2.new(0,2,0.5,-6)}):Play()
        end
        if onToggle then onToggle(on) end
    end
    
    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 10
    btn.MouseEnter:Connect(function() end)
    btn.MouseLeave:Connect(function() end)
    btn.MouseButton1Click:Connect(function() setToggle(not togState) end)

    -- Live-Update bei Theme-Wechsel
    if _panelColorHooks then
        _panelColorHooks[#_panelColorHooks+1] = function()
            local ac = liveCol()
            pcall(function() cdot.BackgroundColor3 = ac end)
            if togState then
                pcall(function() togTrack.BackgroundColor3 = ac end)
                pcall(function() cStr.Color                = ac end)
            end
        end
    end
    return card, setToggle
end
local GAP = 8
-- -- Quick Actions -----------------------------------------------------
do
local QA_ITEMS = {
    { id = "rejoin",  label = "Rejoin",  sub = "Reconnect" },
    { id = "respawn", label = "Respawn", sub = "(Same Position)" },
    { id = "r6anim",  label = "R6 Anim", sub = "Switch to R6" },
}
local QA_GAP  = 8
local QA_W    = math.floor((PANEL_W - PAD * 2 - QA_GAP * (#QA_ITEMS - 1)) / #QA_ITEMS)
local QA_H    = 52
local qaCard  = Instance.new("Frame", c)
qaCard.Size              = UDim2.new(1, 0, 0, QA_H + 26)
qaCard.Position          = UDim2.new(0, 0, 0, CY)
qaCard.BackgroundTransparency = 1
qaCard.BorderSizePixel   = 0
local qaLbl = Instance.new("TextLabel", qaCard)
qaLbl.Size               = UDim2.new(1, -16, 0, 18)
qaLbl.Position           = UDim2.new(0, PAD, 0, 0)
qaLbl.BackgroundTransparency = 1
qaLbl.Text               = "Quick Actions"
qaLbl.Font               = Enum.Font.GothamBold
qaLbl.TextSize           = 12
qaLbl.TextColor3         = C.sub
qaLbl.TextXAlignment     = Enum.TextXAlignment.Left
for i, qa in ipairs(QA_ITEMS) do
    local xOff = PAD + (i - 1) * (QA_W + QA_GAP)
    local chip = Instance.new("Frame", qaCard)
    chip.Size              = UDim2.new(0, QA_W, 0, QA_H)
    chip.Position          = UDim2.new(0, xOff, 0, 22)
    chip.BackgroundColor3  = C.bg2 or _C3_BG2
    chip.BackgroundTransparency = 0
    chip.BorderSizePixel   = 0; corner(chip, 10)
    local cStr = _makeDummyStroke(chip)
    cStr.Thickness = 1.5; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.65
    cStr.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local lbl = Instance.new("TextLabel", chip)
    lbl.Size               = UDim2.new(1, -4, 0, 16)
    lbl.Position           = UDim2.new(0, 2, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Text               = qa.label
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 11
    lbl.TextColor3         = C.sub or _C3_SUB
    lbl.TextXAlignment     = Enum.TextXAlignment.Center
    local subLbl = Instance.new("TextLabel", chip)
    subLbl.Size            = UDim2.new(1, -4, 0, 12)
    subLbl.Position        = UDim2.new(0, 2, 1, -18)
    subLbl.BackgroundTransparency = 1
    subLbl.Text            = qa.sub
    subLbl.Font            = Enum.Font.GothamBold
    subLbl.TextSize        = 9
    subLbl.TextColor3      = C.sub or _C3_SUB
    subLbl.TextXAlignment  = Enum.TextXAlignment.Center
    local btn = Instance.new("TextButton", chip)
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 8
    local captId = qa.id
    local function activate()
        -- Flash-Feedback
        twP(chip, 0.08, {BackgroundColor3 = C.bg3 or _C3_BG4})
        twP(lbl,  0.08, {TextColor3 = C.accent or _C3_TEXT3})
        twP(subLbl, 0.08, {TextColor3 = C.text})
        task.delay(0.22, function()
            twP(chip, 0.15, {BackgroundColor3 = C.bg2 or _C3_BG2})
            twP(lbl,  0.15, {TextColor3 = C.sub or _C3_SUB})
            twP(subLbl, 0.15, {TextColor3 = C.sub or _C3_SUB})
        end)
        if captId == "rejoin" then
            pcall(function()
                local TS = game:GetService("TeleportService")
                local placeId = game.PlaceId
                local Players2 = _SvcPlr
                TS:Teleport(placeId, Players2.LocalPlayer)
            end)
        end
        if captId == "respawn" then
            task.spawn(function()
                local char = LocalPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                local savedCF = hrp and hrp.CFrame
                -- 1. Sofort töten
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.Health = 0 end) end
                -- 2. Fly-State aufräumen
                if flyActive then
                    flyActive = false
                    if flyConn     then pcall(function() flyConn:Disconnect()  end); flyConn     = nil end
                    if flyBodyVel  then pcall(function() flyBodyVel:Destroy()  end); flyBodyVel  = nil end
                    if flyBodyGyro then pcall(function() flyBodyGyro:Destroy() end); flyBodyGyro = nil end
                    pcall(_flyMuteSounds, false)
                    pcall(function() if _flyPanelSetFn then _flyPanelSetFn(false) end end)
                end
                -- 3. CharacterAdded VOR dem Tod registrieren – Position wiederherstellen
                if savedCF then
                    local conn
                    conn = LocalPlayer.CharacterAdded:Connect(function(newChar)
                        conn:Disconnect()
                        local newHrp = newChar:FindFirstChild("HumanoidRootPart")
                                    or newChar:WaitForChild("HumanoidRootPart", 3)
                        if newHrp then
                            pcall(function() newHrp.CFrame = savedCF end)
                            task.defer(function()
                                pcall(function() newHrp.CFrame = savedCF end)
                            end)
                        end
                    end)
                end
                -- 4. Charakter töten – Roblox löst Respawn automatisch aus
                local hum2 = char and char:FindFirstChildOfClass("Humanoid")
                if hum2 then pcall(function() hum2.Health = 0 end) end
            end)
        end
        if captId == "r6anim" then
            task.spawn(function()
                local plr = _SvcPlr.LocalPlayer

                local function RunCustomAnimation(Char)
                    if Char:WaitForChild("Animate") ~= nil then
                        Char.Animate.Disabled = true
                    end
                    Char:WaitForChild("Humanoid")
                    for i,v in next, Char.Humanoid:GetPlayingAnimationTracks() do
                        v:Stop()
                    end
                    local script = Char.Animate
                    local Character = Char
                    local Humanoid = Character:WaitForChild("Humanoid")
                    local pose = "Standing"
                    local UserGameSettings = UserSettings():GetService("UserGameSettings")
                    local userNoUpdateOnLoopSuccess, userNoUpdateOnLoopValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserNoUpdateOnLoop") end)
                    local userNoUpdateOnLoop = userNoUpdateOnLoopSuccess and userNoUpdateOnLoopValue
                    local AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
                    local HumanoidHipHeight = 2
                    local humanoidSpeed = 0
                    local cachedRunningSpeed = 0
                    local cachedLocalDirection = {x=0.0, y=0.0}
                    local smallButNotZero = 0.0001
                    local runBlendtime = 0.2
                    local lastLookVector = Vector3.new(0.0, 0.0, 0.0)
                    local lastBlendTime = 0
                    local WALK_SPEED = 6.4
                    local RUN_SPEED = 12.8
                    local EMOTE_TRANSITION_TIME = 0.1
                    local currentAnim = ""
                    local currentAnimInstance = nil
                    local currentAnimTrack = nil
                    local currentAnimKeyframeHandler = nil
                    local currentAnimSpeed = 1.0
                    local PreloadedAnims = {}
                    local animTable = {}
                    local animNames = {
                        idle    = { { id = "http://www.roblox.com/asset/?id=12521158637", weight = 9 }, { id = "http://www.roblox.com/asset/?id=12521162526", weight = 1 } },
                        walk    = { { id = "http://www.roblox.com/asset/?id=12518152696", weight = 10 } },
                        run     = { { id = "http://www.roblox.com/asset/?id=12518152696", weight = 10 } },
                        jump    = { { id = "http://www.roblox.com/asset/?id=12520880485", weight = 10 } },
                        fall    = { { id = "http://www.roblox.com/asset/?id=12520972571", weight = 10 } },
                        climb   = { { id = "http://www.roblox.com/asset/?id=12520982150", weight = 10 } },
                        sit     = { { id = "http://www.roblox.com/asset/?id=12520993168", weight = 10 } },
                        toolnone   = { { id = "http://www.roblox.com/asset/?id=12520996634", weight = 10 } },
                        toolslash  = { { id = "http://www.roblox.com/asset/?id=12520999032", weight = 10 } },
                        toollunge  = { { id = "http://www.roblox.com/asset/?id=12521002003", weight = 10 } },
                        wave    = { { id = "http://www.roblox.com/asset/?id=12521004586", weight = 10 } },
                        point   = { { id = "http://www.roblox.com/asset/?id=12521007694", weight = 10 } },
                        dance   = { { id = "http://www.roblox.com/asset/?id=12521009666", weight = 10 }, { id = "http://www.roblox.com/asset/?id=12521151637", weight = 10 }, { id = "http://www.roblox.com/asset/?id=12521015053", weight = 10 } },
                        dance2  = { { id = "http://www.roblox.com/asset/?id=12521169800", weight = 10 }, { id = "http://www.roblox.com/asset/?id=12521173533", weight = 10 }, { id = "http://www.roblox.com/asset/?id=12521027874", weight = 10 } },
                        dance3  = { { id = "http://www.roblox.com/asset/?id=12521178362", weight = 10 }, { id = "http://www.roblox.com/asset/?id=12521181508", weight = 10 }, { id = "http://www.roblox.com/asset/?id=12521184133", weight = 10 } },
                        laugh   = { { id = "http://www.roblox.com/asset/?id=12521018724", weight = 10 } },
                        cheer   = { { id = "http://www.roblox.com/asset/?id=12521021991", weight = 10 } },
                    }
                    local strafingLocomotionMap = {}
                    local fallbackLocomotionMap = {}
                    local locomotionMap = strafingLocomotionMap
                    local emoteNames = { wave = false, point = false, dance = true, dance2 = true, dance3 = true, laugh = false, cheer = false }
                    math.randomseed(tick())

                    local function configureAnimationSet(name, fileList)
                        if animTable[name] ~= nil then
                            for _, connection in pairs(animTable[name].connections) do connection:disconnect() end
                        end
                        animTable[name] = { count = 0, totalWeight = 0, connections = {} }
                        if name == "run" or name == "walk" then
                            local speed = name == "run" and RUN_SPEED or WALK_SPEED
                            fallbackLocomotionMap[name] = {lv=Vector2.new(0.0, speed), speed = speed}
                            locomotionMap = fallbackLocomotionMap
                        end
                        if animTable[name].count <= 0 then
                            for idx, anim in pairs(fileList) do
                                animTable[name][idx] = {}
                                animTable[name][idx].anim = Instance.new("Animation")
                                animTable[name][idx].anim.Name = name
                                animTable[name][idx].anim.AnimationId = anim.id
                                animTable[name][idx].weight = anim.weight
                                animTable[name].count = animTable[name].count + 1
                                animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
                            end
                        end
                        for i, animType in pairs(animTable) do
                            for idx = 1, animType.count, 1 do
                                if PreloadedAnims[animType[idx].anim.AnimationId] == nil then
                                    Humanoid:LoadAnimation(animType[idx].anim)
                                    PreloadedAnims[animType[idx].anim.AnimationId] = true
                                end
                            end
                        end
                    end

                    local function scriptChildModified(child)
                        local fileList = animNames[child.Name]
                        if fileList ~= nil then
                            configureAnimationSet(child.Name, fileList)
                        else
                            if child:isA("StringValue") then
                                animNames[child.Name] = {}
                                configureAnimationSet(child.Name, animNames[child.Name])
                            end
                        end
                    end

                    script.ChildAdded:connect(scriptChildModified)
                    script.ChildRemoved:connect(scriptChildModified)

                    local animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator") or nil
                    if animator then
                        local animTracks = animator:GetPlayingAnimationTracks()
                        for i,track in ipairs(animTracks) do track:Stop(0); track:Destroy() end
                    end

                    for name, fileList in pairs(animNames) do configureAnimationSet(name, fileList) end
                    for _,child in script:GetChildren() do
                        if child:isA("StringValue") and not animNames[child.name] then
                            animNames[child.Name] = {}
                            configureAnimationSet(child.Name, animNames[child.Name])
                        end
                    end

                    local toolAnim = "None"
                    local toolAnimTime = 0
                    local jumpAnimTime = 0
                    local jumpAnimDuration = 0.31
                    local toolTransitionTime = 0.1
                    local fallTransitionTime = 0.2
                    local currentlyPlayingEmote = false

                    local function getHeightScale()
                        if Humanoid then
                            if not Humanoid.AutomaticScalingEnabled then return 1 end
                            local scale = Humanoid.HipHeight / HumanoidHipHeight
                            if AnimationSpeedDampeningObject == nil then
                                AnimationSpeedDampeningObject = script:FindFirstChild("ScaleDampeningPercent")
                            end
                            if AnimationSpeedDampeningObject ~= nil then
                                scale = 1 + (Humanoid.HipHeight - HumanoidHipHeight) * AnimationSpeedDampeningObject.Value / HumanoidHipHeight
                            end
                            return scale
                        end
                        return 1
                    end

                    local function signedAngle(a, b)
                        return -math.atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y)
                    end

                    local angleWeight = 2.0
                    local function get2DWeight(px, p1, p2, sx, s1, s2)
                        local avgLength = 0.5 * (s1 + s2)
                        local p_1 = {x = (sx - s1)/avgLength, y = (angleWeight * signedAngle(p1, px))}
                        local p12 = {x = (s2 - s1)/avgLength, y = (angleWeight * signedAngle(p1, p2))}
                        local denom = smallButNotZero + (p12.x*p12.x + p12.y*p12.y)
                        local numer = p_1.x * p12.x + p_1.y * p12.y
                        local r = math.clamp(1.0 - numer/denom, 0.0, 1.0)
                        return r
                    end

                    local function blend2D(targetVelo, targetSpeed)
                        local h = {}
                        local sum = 0.0
                        for n,v1 in pairs(locomotionMap) do
                            if targetVelo.x * v1.lv.x < 0.0 or targetVelo.y * v1.lv.y < 0 then h[n] = 0.0; continue end
                            h[n] = math.huge
                            for j,v2 in pairs(locomotionMap) do
                                if targetVelo.x * v2.lv.x < 0.0 or targetVelo.y * v2.lv.y < 0 then continue end
                                h[n] = math.min(h[n], get2DWeight(targetVelo, v1.lv, v2.lv, targetSpeed, v1.speed, v2.speed))
                            end
                            sum = sum + h[n]
                        end
                        local sum2 = 0.0
                        local weightedVeloX, weightedVeloY = 0, 0
                        for n,v in pairs(locomotionMap) do
                            if (h[n] / sum > 0.1) then
                                sum2 = sum2 + h[n]; weightedVeloX = weightedVeloX + h[n] * v.lv.x; weightedVeloY = weightedVeloY + h[n] * v.lv.y
                            else h[n] = 0.0 end
                        end
                        local animSpeed
                        local wss = weightedVeloX * weightedVeloX + weightedVeloY * weightedVeloY
                        if wss > smallButNotZero then animSpeed = math.sqrt(targetSpeed * targetSpeed / wss) else animSpeed = 0 end
                        animSpeed = animSpeed / getHeightScale()
                        local groupTimePosition = 0
                        for n,v in pairs(locomotionMap) do if v.track and v.track.IsPlaying then groupTimePosition = v.track.TimePosition; break end end
                        for n,v in pairs(locomotionMap) do
                            if h[n] > 0.0 then
                                if v.track and not v.track.IsPlaying then v.track:Play(runBlendtime); v.track.TimePosition = groupTimePosition end
                                if v.track then local w = math.max(smallButNotZero, h[n]/sum2); v.track:AdjustWeight(w, runBlendtime); v.track:AdjustSpeed(animSpeed) end
                            else if v.track then v.track:Stop(runBlendtime) end end
                        end
                    end

                    local function getWalkDirection()
                        local walkToPoint = Humanoid.WalkToPoint; local walkToPart = Humanoid.WalkToPart
                        if Humanoid.MoveDirection ~= Vector3.zero then return Humanoid.MoveDirection
                        elseif walkToPart or walkToPoint ~= Vector3.zero then
                            local destination = walkToPart and walkToPart.CFrame:PointToWorldSpace(walkToPoint) or walkToPoint
                            local moveVector = Vector3.zero
                            if Humanoid.RootPart then
                                moveVector = destination - Humanoid.RootPart.CFrame.Position
                                moveVector = Vector3.new(moveVector.x, 0.0, moveVector.z)
                                local mag = moveVector.Magnitude
                                if mag > 0.01 then moveVector = moveVector / mag end
                            end
                            return moveVector
                        else return Humanoid.MoveDirection end
                    end

                    local function updateVelocity(currentTime)
                        if locomotionMap == strafingLocomotionMap then
                            local moveDirection = getWalkDirection()
                            if not Humanoid.RootPart then return end
                            local cframe = Humanoid.RootPart.CFrame
                            if math.abs(cframe.UpVector.Y) < smallButNotZero or pose ~= "Running" or humanoidSpeed < 0.001 then
                                for n,v in pairs(locomotionMap) do if v.track then v.track:AdjustWeight(smallButNotZero, runBlendtime) end end
                                return
                            end
                            local lookat = cframe.LookVector
                            local direction = Vector3.new(lookat.X, 0.0, lookat.Z); direction = direction / direction.Magnitude
                            local ly = moveDirection:Dot(direction)
                            if ly <= 0.0 and ly > -0.05 then ly = smallButNotZero end
                            local lx = direction.X*moveDirection.Z - direction.Z*moveDirection.X
                            local tempDir2 = Vector2.new(lx, ly)
                            local delta = Vector2.new(tempDir2.x-cachedLocalDirection.x, tempDir2.y-cachedLocalDirection.y)
                            if delta:Dot(delta) > 0.001 or math.abs(humanoidSpeed - cachedRunningSpeed) > 0.01 or currentTime - lastBlendTime > 1 then
                                cachedLocalDirection = tempDir2; cachedRunningSpeed = humanoidSpeed; lastBlendTime = currentTime; blend2D(cachedLocalDirection, cachedRunningSpeed)
                            end
                        else
                            if math.abs(humanoidSpeed - cachedRunningSpeed) > 0.01 or currentTime - lastBlendTime > 1 then
                                cachedRunningSpeed = humanoidSpeed; lastBlendTime = currentTime; blend2D(Vector2.yAxis, cachedRunningSpeed)
                            end
                        end
                    end

                    local function stopAllAnimations()
                        local oldAnim = currentAnim
                        if emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false then oldAnim = "idle" end
                        if currentlyPlayingEmote then oldAnim = "idle"; currentlyPlayingEmote = false end
                        currentAnim = ""; currentAnimInstance = nil
                        if currentAnimKeyframeHandler ~= nil then currentAnimKeyframeHandler:disconnect() end
                        if currentAnimTrack ~= nil then currentAnimTrack:Stop(); currentAnimTrack:Destroy(); currentAnimTrack = nil end
                        for _,v in pairs(locomotionMap) do if v.track then v.track:Stop(); v.track:Destroy(); v.track = nil end end
                        return oldAnim
                    end

                    local function setAnimationSpeed(speed)
                        if currentAnim ~= "walk" then
                            if speed ~= currentAnimSpeed then currentAnimSpeed = speed; currentAnimTrack:AdjustSpeed(currentAnimSpeed) end
                        end
                    end

                    local function rollAnimation(animName)
                        local roll = math.random(1, animTable[animName].totalWeight)
                        local idx = 1
                        while roll > animTable[animName][idx].weight do roll = roll - animTable[animName][idx].weight; idx = idx + 1 end
                        return idx
                    end

                    local function destroyRunAnimations()
                        for _,v in pairs(strafingLocomotionMap) do if v.track then v.track:Stop(); v.track:Destroy(); v.track = nil end end
                        for _,v in pairs(fallbackLocomotionMap) do if v.track then v.track:Stop(); v.track:Destroy(); v.track = nil end end
                        cachedRunningSpeed = 0
                    end

                    local maxVeloX, minVeloX, maxVeloY, minVeloY

                    local function resetVelocityBounds() minVeloX=0; maxVeloX=0; minVeloY=0; maxVeloY=0 end
                    local function updateVelocityBounds(velo)
                        if velo then
                            if velo.x > maxVeloX then maxVeloX=velo.x end; if velo.y > maxVeloY then maxVeloY=velo.y end
                            if velo.x < minVeloX then minVeloX=velo.x end; if velo.y < minVeloY then minVeloY=velo.y end
                        end
                    end
                    local function checkVelocityBounds()
                        if maxVeloX==0 or minVeloX==0 or maxVeloY==0 or minVeloY==0 then locomotionMap=fallbackLocomotionMap
                        else locomotionMap=strafingLocomotionMap end
                    end
                    local function setupWalkAnimation(anim, animName, transitionTime, humanoid)
                        resetVelocityBounds()
                        for n,v in pairs(locomotionMap) do
                            v.track = humanoid:LoadAnimation(animTable[n][1].anim); v.track.Priority = Enum.AnimationPriority.Core; updateVelocityBounds(v.lv)
                        end
                        checkVelocityBounds()
                    end

                    local function keyFrameReachedFunc(frameName)
                        if frameName == "End" then
                            local repeatAnim = currentAnim
                            if emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false then repeatAnim = "idle" end
                            if currentlyPlayingEmote then
                                if currentAnimTrack.Looped then return end
                                repeatAnim = "idle"; currentlyPlayingEmote = false
                            end
                            local animSpeed = currentAnimSpeed
                            playAnimation(repeatAnim, 0.15, Humanoid); setAnimationSpeed(animSpeed)
                        end
                    end

                    local function switchToAnim(anim, animName, transitionTime, humanoid)
                        if anim ~= currentAnimInstance then
                            if currentAnimTrack ~= nil then currentAnimTrack:Stop(transitionTime); currentAnimTrack:Destroy() end
                            if currentAnimKeyframeHandler ~= nil then currentAnimKeyframeHandler:disconnect() end
                            currentAnimSpeed = 1.0; currentAnim = animName; currentAnimInstance = anim
                            if animName == "walk" then
                                setupWalkAnimation(anim, animName, transitionTime, humanoid)
                            else
                                destroyRunAnimations()
                                currentAnimTrack = humanoid:LoadAnimation(anim); currentAnimTrack.Priority = Enum.AnimationPriority.Core
                                currentAnimTrack:Play(transitionTime)
                                currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
                            end
                        end
                    end

                    function playAnimation(animName, transitionTime, humanoid)
                        local idx = rollAnimation(animName); local anim = animTable[animName][idx].anim
                        switchToAnim(anim, animName, transitionTime, humanoid); currentlyPlayingEmote = false
                    end
                    function playEmote(emoteAnim, transitionTime, humanoid)
                        switchToAnim(emoteAnim, emoteAnim.Name, transitionTime, humanoid); currentlyPlayingEmote = true
                    end

                    local toolAnimName = ""; local toolAnimTrack = nil; local toolAnimInstance = nil; local currentToolAnimKeyframeHandler = nil
                    local function toolKeyFrameReachedFunc(frameName)
                        if frameName == "End" then playToolAnimation(toolAnimName, 0.0, Humanoid) end
                    end
                    function playToolAnimation(animName, transitionTime, humanoid, priority)
                        local idx = rollAnimation(animName); local anim = animTable[animName][idx].anim
                        if toolAnimInstance ~= anim then
                            if toolAnimTrack ~= nil then toolAnimTrack:Stop(); toolAnimTrack:Destroy(); transitionTime = 0 end
                            toolAnimTrack = humanoid:LoadAnimation(anim)
                            if priority then toolAnimTrack.Priority = priority end
                            toolAnimTrack:Play(transitionTime); toolAnimName = animName; toolAnimInstance = anim
                            currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
                        end
                    end
                    local function stopToolAnimations()
                        local oldAnim = toolAnimName
                        if currentToolAnimKeyframeHandler ~= nil then currentToolAnimKeyframeHandler:disconnect() end
                        toolAnimName = ""; toolAnimInstance = nil
                        if toolAnimTrack ~= nil then toolAnimTrack:Stop(); toolAnimTrack:Destroy(); toolAnimTrack = nil end
                        return oldAnim
                    end

                    local function onRunning(speed)
                        local movedDuringEmote = currentlyPlayingEmote and Humanoid.MoveDirection == Vector3.new(0,0,0)
                        local speedThreshold = movedDuringEmote and Humanoid.WalkSpeed or 0.75
                        humanoidSpeed = speed
                        if speed > speedThreshold then
                            playAnimation("walk", 0.2, Humanoid); if pose ~= "Running" then pose = "Running"; updateVelocity(0) end
                        else
                            if emoteNames[currentAnim] == nil and not currentlyPlayingEmote then playAnimation("idle", 0.2, Humanoid); pose = "Standing" end
                        end
                    end

                    Humanoid.Died:connect(function() pose = "Dead" end)
                    Humanoid.Running:connect(onRunning)
                    Humanoid.Jumping:connect(function() playAnimation("jump", 0.1, Humanoid); jumpAnimTime = jumpAnimDuration; pose = "Jumping" end)
                    Humanoid.Climbing:connect(function(speed) playAnimation("climb", 0.1, Humanoid); setAnimationSpeed(speed/5.0); pose = "Climbing" end)
                    Humanoid.GettingUp:connect(function() pose = "GettingUp" end)
                    Humanoid.FreeFalling:connect(function() if jumpAnimTime <= 0 then playAnimation("fall", fallTransitionTime, Humanoid) end; pose = "FreeFall" end)
                    Humanoid.FallingDown:connect(function() pose = "FallingDown" end)
                    Humanoid.Seated:connect(function() pose = "Seated" end)
                    Humanoid.PlatformStanding:connect(function() pose = "PlatformStanding" end)
                    Humanoid.Swimming:connect(function(speed) if speed > 0 then pose = "Running" else pose = "Standing" end end)

                    local function getToolAnim(tool)
                        for _, c in ipairs(tool:GetChildren()) do
                            if c.Name == "toolanim" and c.className == "StringValue" then return c end
                        end
                        return nil
                    end
                    local function animateTool()
                        if toolAnim == "None" then playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle); return end
                        if toolAnim == "Slash" then playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action); return end
                        if toolAnim == "Lunge" then playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action); return end
                    end
                    local lastTick = 0
                    local function stepAnimate(currentTime)
                        local deltaTime = currentTime - lastTick; lastTick = currentTime
                        if jumpAnimTime > 0 then jumpAnimTime = jumpAnimTime - deltaTime end
                        if pose == "FreeFall" and jumpAnimTime <= 0 then playAnimation("fall", fallTransitionTime, Humanoid)
                        elseif pose == "Seated" then playAnimation("sit", 0.5, Humanoid); return
                        elseif pose == "Running" then playAnimation("walk", 0.2, Humanoid); updateVelocity(currentTime)
                        elseif pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "PlatformStanding" then stopAllAnimations() end
                        local tool = Character:FindFirstChildOfClass("Tool")
                        if tool and tool:FindFirstChild("Handle") then
                            local asvo = getToolAnim(tool)
                            if asvo then toolAnim = asvo.Value; asvo.Parent = nil; toolAnimTime = currentTime + 0.3 end
                            if currentTime > toolAnimTime then toolAnimTime = 0; toolAnim = "None" end
                            animateTool()
                        else
                            stopToolAnimations(); toolAnim = "None"; toolAnimInstance = nil; toolAnimTime = 0
                        end
                    end

                    _SvcPlr.LocalPlayer.Chatted:connect(function(msg)
                        local emote = ""
                        if string.sub(msg,1,3) == "/e " then emote = string.sub(msg,4)
                        elseif string.sub(msg,1,7) == "/emote " then emote = string.sub(msg,8) end
                        if pose == "Standing" and emoteNames[emote] ~= nil then playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid) end
                    end)

                    if Character.Parent ~= nil then playAnimation("idle", 0.1, Humanoid); pose = "Standing" end
                    task.spawn(function()
                        while Character.Parent ~= nil do
                            local _, currentGameTime = wait(0.1); stepAnimate(currentGameTime)
                        end
                    end)
                end

                pcall(function() RunCustomAnimation(plr.Character) end)
                sendNotif("R6 Anim", "Custom Animationen aktiv ✅", 3)
            end)
        end
    end
    btn.MouseButton1Click:Connect(activate)
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then activate() end
    end)
    btn.MouseEnter:Connect(function()
        _playHoverSound()
        twP(chip, 0.1, {BackgroundColor3 = C.bg3 or _C3_BG4})
    end)
    btn.MouseLeave:Connect(function()
        twP(chip, 0.1, {BackgroundColor3 = C.bg2 or _C3_BG2})
    end)
end
CY = CY + QA_H + 26 + GAP
end
-- ---------------------------------------------------------------------
sectionLbl(CY, "MOVEMENT"); CY = CY + 18
local FLY_MIN, FLY_MAX, FLY_DEFAULT = 1, 500, 150
local _flyPanelCard; _flyPanelCard, _flyPanelSetFn = makeSliderRow(CY, "Fly", "speed", "accent",
FLY_MIN, FLY_MAX, FLY_DEFAULT,
function(on, val) flyActive = on; setFly(on) end,
function() FLY_BASE_SPEED = FLY_DEFAULT end,
function(val, on) FLY_BASE_SPEED = val end
)
CY = CY + CARD_H + GAP
local _, noclipSetFn = makeToggleRow(CY, "Noclip", "no collision", C.accent,
function(on) noclipActive = on; setNoclip(on) end)
CY = CY + TOG_H + GAP
-- -- Anti-Fling ------------------------------------------------
do
local _afActive  = false
local _afConn    = nil
local _afTracked = {}

local function _afDisableCanCollide(part)
    if part:IsA("BasePart") and part.CanCollide then
        part.CanCollide = false
    end
end

local function _afTrackCharacter(character)
    for _, part in pairs(character:GetChildren()) do
        _afDisableCanCollide(part)
    end
    character.ChildAdded:Connect(function(child)
        _afDisableCanCollide(child)
    end)
end

local function _afTrackPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then
        _afTrackCharacter(player.Character)
    end
    player.CharacterAdded:Connect(_afTrackCharacter)
    _afTracked[player] = true
end

local function _afStart()
    _afTracked = {}
    for _, player in pairs(Players:GetPlayers()) do
        _afTrackPlayer(player)
    end
    Players.PlayerAdded:Connect(function(player)
        if _afActive then _afTrackPlayer(player) end
    end)
    _afConn = RunService.RenderStepped:Connect(function()
        for player in pairs(_afTracked) do
            local character = player.Character
            if character then
                for _, part in pairs(character:GetChildren()) do
                    _afDisableCanCollide(part)
                end
            end
        end
    end)
    pcall(function()
        local _s = Instance.new("Sound")
        _s.SoundId = "rbxassetid://117945572498547"
        _s.Volume = 2
        _s.PlayOnRemove = true
        _s.Parent = _SvcSnd
        _s:Destroy()
    end)
    sendNotif("Anti-Fling", "✅ Aktiviert", 3)
end

local function _afStop()
    _afActive = false
    _afTracked = {}
    if _afConn then _afConn:Disconnect(); _afConn = nil end
end

makeToggleRow(CY, "Anti-Fling", "protection", C.accent2,
function(on)
    _afActive = on
    if on then
        _afStart()
    else
        _afStop()
    end
end)
CY = CY + TOG_H + GAP
end -- Anti-Fling block
-- -------------------------------------------------------------
divider(CY); CY = CY + 14
sectionLbl(CY, "STATS"); CY = CY + 18
local SPEED_MIN, SPEED_MAX, SPEED_DEFAULT = 1, 500, 16
local speedVal = SPEED_DEFAULT
makeSliderRow(CY, "Walk Speed", "walkspeed", "accent2",
SPEED_MIN, SPEED_MAX, SPEED_DEFAULT,
function(on, val)
local h = getHumanoid(); if h then h.WalkSpeed = on and val or 16 end
end,
function()
speedVal = SPEED_DEFAULT
local h = getHumanoid(); if h then h.WalkSpeed = 16 end
end,
function(val, on)
speedVal = val
if on then local h = getHumanoid(); if h then h.WalkSpeed = val end end
end
)
CY = CY + CARD_H + GAP
local JUMP_MIN, JUMP_MAX, JUMP_DEFAULT = 1, 999, 50
local jumpVal = JUMP_DEFAULT
makeSliderRow(CY, "Jump Power", "jumppower", "accent2",
JUMP_MIN, JUMP_MAX, JUMP_DEFAULT,
function(on, val)
local h = getHumanoid()
if h then
pcall(function() h.UseJumpPower = on end)
h.JumpPower = on and val or 50
pcall(function() h.JumpHeight = on and (val*0.36) or 7.2 end)
end
end,
function()
jumpVal = JUMP_DEFAULT
local h = getHumanoid()
if h then
pcall(function() h.UseJumpPower = true end)
h.JumpPower = JUMP_DEFAULT
pcall(function() h.JumpHeight = JUMP_DEFAULT * 0.36 end)
end
end,
function(val, on)
jumpVal = val
if on then
local h = getHumanoid()
if h then
pcall(function() h.UseJumpPower = true end)
h.JumpPower = val
pcall(function() h.JumpHeight = val * 0.36 end)
end
end
end
)
CY = CY + CARD_H + GAP
divider(CY); CY = CY + 14
sectionLbl(CY, "VISIBILITY"); CY = CY + 18
local _, invisSetFn2 = makeToggleRow(CY, "Invisible", "server-side", C.accent,
function(on) invisActive = on; setInvis(on) end)
CY = CY + TOG_H + 14
divider(CY); CY = CY + 14
sectionLbl(CY, "GODMODE"); CY = CY + 18
do
local godActive    = false
local godConn      = nil
local godCharConn  = nil
local godDiedConn  = nil
local godFF = nil
local _godChar  = nil
local _godHum   = nil
local _godFF    = nil
local _godConns = {}
local function _godCleanConns()
for _, c in ipairs(_godConns) do pcall(function() c:Disconnect() end) end
_godConns = {}
end
local function _godApply(char)
if not char then return end
_godChar = char
_godHum  = char:FindFirstChildOfClass("Humanoid")
local hum = _godHum
if not hum then return end
pcall(function() hum.BreakJointsOnDeath   = false end)
pcall(function() hum.RequiresNeck          = false end)
pcall(function() hum.AutoRotate            = hum.AutoRotate end)
local hrp = char:FindFirstChild("HumanoidRootPart")
if hrp then pcall(function() hrp:SetNetworkOwner(LocalPlayer) end) end
if _godFF and _godFF.Parent then pcall(function() _godFF:Destroy() end) end
_godFF = nil
pcall(function()
_godFF = Instance.new("ForceField", char)
_godFF.Visible = false
end)
local conn1 = hum:GetPropertyChangedSignal("Health"):Connect(function()
if not godActive then return end
if hum.Health <= 0 then
pcall(function() hum.Health = hum.MaxHealth end)
elseif hum.Health < hum.MaxHealth then
pcall(function() hum.Health = hum.MaxHealth end)
end
end)
local conn2 = hum.Died:Connect(function()
if not godActive then return end
task.spawn(function()
task.wait()
pcall(function()
if hum and hum.Parent then
hum.Health = hum.MaxHealth
end
end)
end)
end)
table.insert(_godConns, conn1)
table.insert(_godConns, conn2)
pcall(function() hum.Health = hum.MaxHealth end)
end
local function godStart()
godActive = true
_godCleanConns()
local charConn = LocalPlayer.CharacterAdded:Connect(function(char)
if not godActive then return end
task.wait(0.15)
_godCleanConns()
_godApply(char)
end)
table.insert(_godConns, charConn)
local hbConn = RunService.Heartbeat:Connect(function()
if not godActive then return end
local char = LocalPlayer.Character
if not char then return end
if char ~= _godChar then
_godChar = char
_godHum  = char:FindFirstChildOfClass("Humanoid")
task.spawn(function() _godApply(char) end)
return
end
local hum = _godHum
if not hum or not hum.Parent then return end
if hum.Health < hum.MaxHealth and hum.Health > 0 then
pcall(function() hum.Health = hum.MaxHealth end)
end
if not char:FindFirstChildOfClass("ForceField") then
pcall(function()
_godFF = Instance.new("ForceField", char)
_godFF.Visible = false
end)
end
end)
table.insert(_godConns, hbConn)
_godApply(LocalPlayer.Character)
end
local function godStop()
godActive = false
_godCleanConns()
if _godFF and _godFF.Parent then
pcall(function() _godFF:Destroy() end)
end
_godFF = nil
local hum = _godHum
if hum and hum.Parent then
pcall(function() hum.BreakJointsOnDeath = true end)
pcall(function() hum.RequiresNeck = true end)
end
_godChar = nil; _godHum = nil
end
makeToggleRow(CY, "Godmode", "health lock", C.accent2,
function(on) if on then godStart() else godStop() end end)
CY = CY + TOG_H + GAP
end
p.Size = UDim2.new(0, PANEL_W, 0, CY)
LocalPlayer.CharacterAdded:Connect(function(newChar)
    -- -- Invisible full cleanup on respawn --------------------------------
    if invisActive then
        invisActive = false
        -- 1. Stop all connections immediately (before any wait)
        if invisHeartConn   then pcall(function() invisHeartConn:Disconnect()   end); invisHeartConn   = nil end
        if invisRenderConn  then pcall(function() invisRenderConn:Disconnect()  end); invisRenderConn  = nil end
        if invisSteppedConn then pcall(function() invisSteppedConn:Disconnect() end); invisSteppedConn = nil end
        if _invisHealthConn then pcall(function() _invisHealthConn:Disconnect() end); _invisHealthConn = nil end
        if _invisHL and _invisHL.Parent then pcall(function() _invisHL:Destroy() end); _invisHL = nil end
        -- 2. Restore transparency on OLD character parts (char might already be gone, pcall each)
        for _, entry in ipairs(invisParts) do
            pcall(function()
                if entry.part and entry.part.Parent then
                    entry.part.Transparency = entry.origTransp
                end
            end)
        end
        invisParts = {}
        _invisSavedCF = nil
        -- 3. Reset new character's CameraOffset (might have been carried over)
        task.defer(function()
            local newHum = newChar:FindFirstChildOfClass("Humanoid")
            if newHum then pcall(function() newHum.CameraOffset = Vector3.zero end) end
        end)
        -- 4. Update UI toggle
        pcall(function() if invisSetFn2 then invisSetFn2(false) end end)
    else
        -- Even if not active, clear stale refs from the old character
        invisParts = {}
        _invisSavedCF = nil
        if _invisHL and _invisHL.Parent then pcall(function() _invisHL:Destroy() end); _invisHL = nil end
    end
    -- 5. Restore stats + re-cache parts for next activation
    task.wait(0.5)
    local h = getHumanoid()
    if h then h.WalkSpeed = 16; h.JumpPower = 50 end
    task.wait(0.5); invisSetupParts()
end)
end
do
local p, c = makePanel("Scripts", C.accent2)
p.Size = UDim2.new(0, PANEL_W, 0, 108)
p.ClipsDescendants = false
c.ClipsDescendants     = false
c.ScrollBarThickness   = 0
c.ScrollingEnabled     = false
c.Size                 = UDim2.new(1, 0, 1, 0)
c.Position             = UDim2.new(0, 0, 0, 56)
local _sbt = p:FindFirstChild("ScrollTrack")
if _sbt then _sbt.Visible = false end
-- Mobile: enable scrolling in Scripts panel
do
    local _ok2, _vp2 = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp2 = _ok2 and _vp2 or Vector2.new(1920,1080)
    local _t2 = pcall(function() return _SvcUIS.TouchEnabled end)
             and _SvcUIS.TouchEnabled
    local _k2 = pcall(function() return _SvcUIS.KeyboardEnabled end)
             and _SvcUIS.KeyboardEnabled
    if _t2 and not _k2 then
        c.ScrollingEnabled   = true
        c.ScrollBarThickness = 3
        c.ClipsDescendants   = true
        p.ClipsDescendants   = true
    end
end
local SCRIPT_CATS = {
    { id = "Troll",    img = "rbxassetid://120351884957369", col = C.red },
    { id = "Movement", img = "rbxassetid://90240237917328",  col = C.accent2 },
    { id = "Visual",   img = "rbxassetid://77303382760322",  col = C.accent3 },
    { id = "Misc",     img = "rbxassetid://123514430148126", col = C.accent },
    { id = "Combat",   img = "rbxassetid://84261020849153",  col = C.orange, iconSize = 56 },
}
local S_CARD_GAP = 8
local S_CARD_W   = math.floor((PANEL_W - 32 - S_CARD_GAP * (#SCRIPT_CATS - 1)) / #SCRIPT_CATS)
local S_CARD_H   = 80
local sCatBtns   = {}
local sSubPages  = {}
local sActiveCat = nil
local sGrid = Instance.new("Frame", c)
sGrid.Size             = UDim2.new(1, -32, 0, S_CARD_H)
sGrid.Position         = UDim2.new(0, 16, 0, 0)
sGrid.BackgroundTransparency = 1
sGrid.BorderSizePixel  = 0
local sSubArea = Instance.new("Frame", c)
sSubArea.Size             = UDim2.new(1, 0, 0, 0)
sSubArea.Position         = UDim2.new(0, 0, 0, S_CARD_H + 12)
sSubArea.BackgroundTransparency = 1
sSubArea.BorderSizePixel  = 0
sSubArea.ClipsDescendants = false
local _TL_WIDGET_CLOSE_ICON = "rbxassetid://111119570195816"
local function makeWidgetOpenBtn(parent, xPos, yPos, label, callback)
    local wrap = Instance.new("Frame", parent)
    wrap.Size = UDim2.new(0, 56, 0, 28)
    wrap.Position = UDim2.new(0, xPos, 0, yPos)
    wrap.BackgroundColor3 = C.bg2
    wrap.BackgroundTransparency = 0.35
    wrap.BorderSizePixel = 0
    wrap.ZIndex = 8
    corner(wrap, 12)
    local str = _makeDummyStroke(wrap)
    str.Thickness = 1.2; str.Color = C.accent2; str.Transparency = 0.5
    local ico = Instance.new("TextLabel", wrap)
    ico.Size = UDim2.new(0, 20, 1, 0); ico.Position = UDim2.new(0, 6, 0, 0)
    ico.BackgroundTransparency = 1; ico.Text = "+"
    ico.Font = Enum.Font.GothamBlack; ico.TextSize = 11
    ico.TextColor3 = C.accent2; ico.ZIndex = 9
    local txt = Instance.new("TextLabel", wrap)
    txt.Size = UDim2.new(1, -28, 1, 0); txt.Position = UDim2.new(0, 24, 0, 0)
    txt.BackgroundTransparency = 1; txt.Text = label or "OPEN"
    txt.Font = Enum.Font.GothamBlack; txt.TextSize = 9
    txt.TextColor3 = C.sub; txt.ZIndex = 9
    local btn = Instance.new("TextButton", wrap)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.ZIndex = 12
    btn.MouseEnter:Connect(function() 
        _playHoverSound()
        twP(wrap, 0.1, {BackgroundTransparency = 0.2, BackgroundColor3 = C.bg3})
        twP(ico, 0.1, {TextColor3 = _C3_WHITE})
        twP(txt, 0.1, {TextColor3 = _C3_WHITE})
        str.Transparency = 0.22
    end)
    btn.MouseLeave:Connect(function() 
        twP(wrap, 0.1, {BackgroundTransparency = 0.35, BackgroundColor3 = C.bg2})
        twP(ico, 0.1, {TextColor3 = C.accent2})
        twP(txt, 0.1, {TextColor3 = C.sub})
        str.Transparency = 0.5
    end)
    btn.MouseButton1Click:Connect(callback)
    return wrap, txt, ico
end

createScriptWidget = function(scriptName, accentCol, onToggleFn, initState, extraBuilder)
-- -- Professional Script Widget (Home Style) – --
local ac = accentCol or C.accent or Color3.fromRGB(0, 160, 255)
local acDim= C.sub or Color3.fromRGB(120, 120, 125)
local WW   = 240
local HDR_H= 40
local existingWidget = ScreenGui:FindFirstChild("SW_" .. scriptName)
if existingWidget then
    local existingShadow = ScreenGui:FindFirstChild("SW_shadow_" .. scriptName)
    pcall(function() existingWidget:Destroy() end)
    pcall(function() if existingShadow then existingShadow:Destroy() end end)
    task.wait()
end
-- Shadow
local shadow = Instance.new("ImageLabel", ScreenGui)
shadow.Name               = "SW_shadow_" .. scriptName
shadow.Size               = UDim2.new(0, WW+28, 0, 0)
shadow.Position           = UDim2.new(0.5, -(WW+28)/2+4, 0.5, 0)
shadow.BackgroundTransparency = 1; shadow.Image = "rbxassetid://1316045217"
shadow.ImageColor3 = Color3.new(0,0,0); shadow.ImageTransparency = 0.55
shadow.ScaleType = Enum.ScaleType.Slice; shadow.SliceCenter = Rect.new(15, 15, 113, 113)
shadow.ZIndex = 9499
-- Root
local W = Instance.new("Frame", ScreenGui)
W.Name = "SW_" .. scriptName; W.Size = UDim2.new(0, WW, 0, HDR_H)
W.Position = UDim2.new(0.5, -WW/2, 0.5, -100); W.BackgroundColor3 = MDARK or Color3.fromRGB(15,15,18)
W.BackgroundTransparency = 0; W.BorderSizePixel = 0; W.ZIndex = 9500
W.Active = true; W.Draggable = false; corner(W, 12); stroke(W, 1, C.bg3, 0.3)
-- Header
local hdr = Instance.new("Frame", W)
hdr.Size = UDim2.new(1,0,0,HDR_H); hdr.BackgroundColor3 = MHDR or Color3.fromRGB(25,25,28)
hdr.BackgroundTransparency = 0; hdr.BorderSizePixel = 0; hdr.ZIndex = 9501; corner(hdr, 12)
local hdrSep = Instance.new("Frame", W); hdrSep.Size = UDim2.new(1,0,0,1); hdrSep.Position = UDim2.new(0,0,0,HDR_H)
hdrSep.BackgroundColor3 = C.bg3; hdrSep.BackgroundTransparency = 0.5; hdrSep.BorderSizePixel = 0; hdrSep.ZIndex = 9501
-- Title
local titleLbl = Instance.new("TextLabel", hdr)
titleLbl.Size = UDim2.new(1,-70,1,0); titleLbl.Position = UDim2.new(0,14,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = string.upper(scriptName)
titleLbl.Font = Enum.Font.GothamBlack; titleLbl.TextSize = 11; titleLbl.TextColor3 = MGLOW or _C3_WHITE
titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 9503
-- Close
local closeBtn = Instance.new("TextButton", hdr)
closeBtn.Size = UDim2.new(0,24,0,24); closeBtn.Position = UDim2.new(1,-30,0.5,-12)
closeBtn.BackgroundColor3 = C.bg3; closeBtn.BackgroundTransparency = 0.5; closeBtn.Text = ""; closeBtn.ZIndex = 9505; corner(closeBtn, 6)
local closeBtnIco = Instance.new("ImageLabel", closeBtn)
closeBtnIco.Size = UDim2.new(0,14,0,14); closeBtnIco.Position = UDim2.new(0.5,-7,0.5,-7)
closeBtnIco.BackgroundTransparency = 1; closeBtnIco.Image = _TL_WIDGET_CLOSE_ICON; closeBtnIco.ImageColor3 = _C3_WHITE; closeBtnIco.ZIndex = 9506
closeBtn.MouseButton1Click:Connect(function() W:Destroy() end)
-- Draggable Logic (High-Performance & Self-Cleaning)
local dragStart, startPos, dragging = nil, nil, false
local dragConn = nil
hdr.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = inp.Position; startPos = W.Position
    end
end)
dragConn = UserInputService.InputChanged:Connect(function(inp)
    if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        W.Position = newPos
        if shadow and shadow.Parent then 
            shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset-3, newPos.Y.Scale, newPos.Y.Offset-3) 
        end
    end
end)
hdr.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
-- Auto-Cleanup
W.Destroying:Connect(function()
    if dragConn then dragConn:Disconnect(); dragConn = nil end
    if shadow then shadow:Destroy(); shadow = nil end
end)
-- Body Container
local body = Instance.new("Frame", W)
body.Size = UDim2.new(1,0,1,-HDR_H); body.Position = UDim2.new(0,0,0,HDR_H)
body.BackgroundTransparency = 1; body.BorderSizePixel = 0; body.ZIndex = 9501
-- Status Pill
local stPill = Instance.new("Frame", body)
stPill.Size = UDim2.new(1,-24,0,32); stPill.Position = UDim2.new(0,12,0,10)
stPill.BackgroundColor3 = C.bg2; stPill.BackgroundTransparency = 0.4; corner(stPill, 8)
local stStroke = _makeDummyStroke(stPill); stStroke.Thickness = 1; stStroke.Color = acDim; stStroke.Transparency = 0.6
local stLbl = Instance.new("TextLabel", stPill)
stLbl.Size = UDim2.new(1,-60,1,0); stLbl.Position = UDim2.new(0,12,0,0)
stLbl.BackgroundTransparency = 1; stLbl.Text = initState and "✅ ACTIVE" or "❌ INACTIVE"
stLbl.Font = Enum.Font.GothamBlack; stLbl.TextSize = 10; stLbl.TextColor3 = initState and ac or acDim; stLbl.TextXAlignment = Enum.TextXAlignment.Left
-- Toggle knob
local TW2, TH2 = 34, 18
local togTrack = Instance.new("Frame", stPill)
togTrack.Size = UDim2.new(0,TW2,0,TH2); togTrack.Position = UDim2.new(1,-(TW2+8),0.5,-TH2/2)
togTrack.BackgroundColor3 = initState and ac or C.bg3; togTrack.BackgroundTransparency = initState and 0.4 or 0.2; corner(togTrack, 99)
local togKnob = Instance.new("Frame", togTrack)
togKnob.Size = UDim2.new(0,12,0,12); togKnob.Position = initState and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
togKnob.BackgroundColor3 = _C3_WHITE; corner(togKnob, 99)
local toggleState = initState or false
local function setToggle(on)
    toggleState = on; stLbl.Text = on and "✅ ACTIVE" or "❌ INACTIVE"; stLbl.TextColor3 = on and ac or acDim
    twP(togTrack, 0.15, {BackgroundColor3 = on and ac or C.bg3, BackgroundTransparency = on and 0.4 or 0.2})
    twP(togKnob, 0.15, {Position = on and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)})
    twP(stStroke, 0.15, {Color = on and ac or acDim, Transparency = on and 0.4 or 0.6})
    if onToggleFn then onToggleFn(on) end
end
local togBtn = Instance.new("TextButton", stPill)
togBtn.Size = UDim2.new(1,0,1,0); togBtn.BackgroundTransparency = 1; togBtn.Text = ""; togBtn.ZIndex = 9510
togBtn.MouseButton1Click:Connect(function() setToggle(not toggleState) end)
-- Target Display
local tgtRow = Instance.new("Frame", body)
tgtRow.Size = UDim2.new(1,-24,0,26); tgtRow.Position = UDim2.new(0,12,0,52)
tgtRow.BackgroundColor3 = C.bg2; tgtRow.BackgroundTransparency = 0.6; corner(tgtRow, 6)
local tgtLbl = Instance.new("TextLabel", tgtRow)
tgtLbl.Size = UDim2.new(0,50,1,0); tgtLbl.Position = UDim2.new(0,10,0,0)
tgtLbl.BackgroundTransparency = 1; tgtLbl.Text = "TARGET:"; tgtLbl.Font = Enum.Font.GothamBold; tgtLbl.TextSize = 8; tgtLbl.TextColor3 = acDim
local tgtVal = Instance.new("TextLabel", tgtRow)
tgtVal.Size = UDim2.new(1,-70,1,0); tgtVal.Position = UDim2.new(0,60,0,0)
tgtVal.BackgroundTransparency = 1; tgtVal.Text = "◈ NONE ◈"; tgtVal.Font = Enum.Font.GothamBlack; tgtVal.TextSize = 10; tgtVal.TextColor3 = _C3_WHITE; tgtVal.TextXAlignment = Enum.TextXAlignment.Left; tgtVal.TextTruncate = Enum.TextTruncate.AtEnd
-- Animation & Extra Content
local baseContentH = 88 -- Total height of Status + Target + Margins
local startExtraY = 82
local finalH = HDR_H + baseContentH
if extraBuilder then
    local extraH = extraBuilder(body, WW, startExtraY, ac, setToggle)
    finalH = finalH + (extraH or 0)
end
W.Size = UDim2.new(0, WW, 0, finalH + 12)
shadow.Size = UDim2.new(0, WW+6, 0, finalH + 6)
shadow.Position = UDim2.new(0.5, -(WW+6)/2, 0.5, -(finalH+6)/2)
shadow.ImageTransparency = 0.7
tw(W, 0.35, {Position = UDim2.new(0.5, -WW/2, 0.5, -(finalH/2))}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- Target update logic
task.spawn(function()
    while W and W.Parent do
        pcall(function()
            local np = getNearestPlayer()
            tgtVal.Text = np and string.upper(np.DisplayName) or "◈ NONE ◈"
        end)
        task.wait(1)
    end
end)
return { W = W, setToggle = setToggle }
end

local function addWidgetBtn(rowFrame, scriptName, accentCol, onToggleFn, getStateFn, xPos)
local ac = accentCol or C.accent
-- Pill container – 52x26px, rounded, accent-bordered
local pill = Instance.new("Frame", rowFrame)
pill.Name             = "WBtn_" .. scriptName
pill.Size             = UDim2.new(0, 52, 0, 26)
local scl = xPos < 0 and 1 or 0
pill.Position         = UDim2.new(scl, xPos < 0 and (xPos - 24) or xPos, 0.5, -13)
pill.BackgroundColor3 = C.bg2
pill.BackgroundTransparency = 0.05
pill.BorderSizePixel  = 0
pill.ZIndex           = 7
corner(pill, 13)
local iS = _makeDummyStroke(pill)
iS.Thickness = 1.5; iS.Color = ac; iS.Transparency = 0.55
-- Left accent dot
local adot = Instance.new("Frame", pill)
adot.Size = UDim2.new(0,3,0,14); adot.Visible = false; adot.Position = UDim2.new(0,0,0.5,-7)
adot.BackgroundColor3 = ac; adot.BackgroundTransparency = 0.4
adot.BorderSizePixel = 0; adot.ZIndex = 8; corner(adot, 99)
-- Icon label "◈"
local icoLbl = Instance.new("TextLabel", pill)
icoLbl.Size             = UDim2.new(0, 18, 1, 0)
icoLbl.Position         = UDim2.new(0, 4, 0, 0)
icoLbl.BackgroundTransparency = 1
icoLbl.Text             = "+"
icoLbl.Font             = Enum.Font.GothamBlack
icoLbl.TextSize         = 12
icoLbl.TextColor3       = ac
icoLbl.TextXAlignment   = Enum.TextXAlignment.Center
icoLbl.ZIndex           = 9
-- Text label
local txtLbl = Instance.new("TextLabel", pill)
txtLbl.Size             = UDim2.new(1, -24, 1, 0)
txtLbl.Position         = UDim2.new(0, 22, 0, 0)
txtLbl.BackgroundTransparency = 1
txtLbl.Text             = "OPEN"
txtLbl.Font             = Enum.Font.GothamBlack
txtLbl.TextSize         = 9
txtLbl.TextColor3       = C.sub
txtLbl.TextXAlignment   = Enum.TextXAlignment.Left
txtLbl.ZIndex           = 9
-- Invisible click button (full size for easy tapping)
local hitBtn = Instance.new("TextButton", pill)
hitBtn.Size = UDim2.new(1,0,1,0); hitBtn.BackgroundTransparency = 1
hitBtn.Text = ""; hitBtn.ZIndex = 12; hitBtn.Active = true
hitBtn.AutoButtonColor = false
local function doOpen()
    local state = getStateFn and getStateFn() or false
    createScriptWidget(scriptName, accentCol, onToggleFn, state)
end
hitBtn.MouseEnter:Connect(function()
_playHoverSound()
    twP(pill,   0.10, {BackgroundColor3 = ac, BackgroundTransparency = 0.78})
    twP(icoLbl, 0.10, {TextColor3 = _C3_WHITE})
    twP(txtLbl, 0.10, {TextColor3 = _C3_WHITE})
    iS.Transparency = 0.2
end)
hitBtn.MouseLeave:Connect(function()
    twP(pill,   0.10, {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.05})
    twP(icoLbl, 0.10, {TextColor3 = ac})
    twP(txtLbl, 0.10, {TextColor3 = C.sub})
    iS.Transparency = 0.55
end)
hitBtn.MouseButton1Click:Connect(doOpen)
hitBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then doOpen() end
end)
end
local function sRow(parent, yPos, labelText, badgeText, badgeCol, initOn, onToggle)
local row, setFn, getFn = cleanRow(parent, yPos, labelText, badgeText, badgeCol, initOn, onToggle)
return row, setFn, getFn
end
local trollPage = Instance.new("Frame", sSubArea)
trollPage.BackgroundTransparency = 1; trollPage.BorderSizePixel = 0
trollPage.Visible = false
local trollLayout = Instance.new("UIListLayout", trollPage)
trollLayout.SortOrder     = _ENUM_SORT_ORDER_LAYOUT
trollLayout.FillDirection = Enum.FillDirection.Vertical
trollLayout.Padding       = UDim.new(0, 6)
trollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    trollPage.Size = UDim2.new(1, 0, 0, trollLayout.AbsoluteContentSize.Y)
end)
-- Troll-Zweizeilen-Layout (Movement-Stil): außerhalb der Feature-`do`-Blöcke, sonst Rush/Fling: nil + crash
local TROLL_TOP_H, TROLL_GAP, TROLL_BOT_H = 46, 4, 34
local TROLL_ROW_H = TROLL_TOP_H + TROLL_GAP + TROLL_BOT_H
local _activePlayerPillDropdown = nil
local function createPlayerPill(parent, yPos, labelText, defaultText, onSelect, onToggle)
    local pill = Instance.new("Frame", parent)
    pill.Size = UDim2.new(1, -32, 0, 24)
    pill.Position = UDim2.new(0, 16, 0, yPos)
    pill.BackgroundColor3 = C.bg2; pill.BackgroundTransparency = 0
    pill.BorderSizePixel = 0; corner(pill, 12)
    
    local pillLbl = Instance.new("TextLabel", pill)
    pillLbl.Size = UDim2.new(1, -24, 1, 0); pillLbl.Position = UDim2.new(0, 10, 0, 0)
    pillLbl.BackgroundTransparency = 1; pillLbl.Text = defaultText
    pillLbl.Font = Enum.Font.GothamBold; pillLbl.TextSize = 13
    pillLbl.TextColor3 = C.text; pillLbl.TextXAlignment = Enum.TextXAlignment.Left
    pillLbl.TextTruncate = Enum.TextTruncate.AtEnd; pillLbl.ZIndex = 9
    
    local pillBtn = Instance.new("TextButton", pill)
    pillBtn.Size = UDim2.new(1, 0, 1, 0); pillBtn.BackgroundTransparency = 1
    pillBtn.Text = ""; pillBtn.ZIndex = 10; pillBtn.Active = true
    
    local pillS = stroke(pill, 1, C.accent, 0.6)
    
    local arrow = Instance.new("TextLabel", pill)
    arrow.Size = UDim2.new(0, 20, 1, 0); arrow.Position = UDim2.new(1, -22, 0, 0)
    arrow.BackgroundTransparency = 1; arrow.Text = "▼"; arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 10; arrow.TextColor3 = C.text; arrow.ZIndex = 9; arrow.TextTransparency = 0.4

    local ddFrame = Instance.new("Frame", pill)
    ddFrame.AnchorPoint = Vector2.new(0, 0); ddFrame.BackgroundColor3 = C.bg2
    ddFrame.BackgroundTransparency = 0; ddFrame.BorderSizePixel = 0
    ddFrame.ZIndex = 5000; ddFrame.Visible = false; ddFrame.ClipsDescendants = true
    corner(ddFrame, 12); local ddStr = stroke(ddFrame, 1.2, C.accent, 0.3)
    
    local ddScroll = Instance.new("ScrollingFrame", ddFrame)
    ddScroll.Size = UDim2.new(1, 0, 1, 0); ddScroll.BackgroundTransparency = 1
    ddScroll.BorderSizePixel = 0; ddScroll.ScrollBarThickness = 2
    ddScroll.ScrollBarImageColor3 = C.accent or C.red; ddScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    ddScroll.CanvasSize = UDim2.new(0, 0, 0, 0); ddScroll.ZIndex = 5001
    
    local ddList = Instance.new("UIListLayout", ddScroll)
    ddList.FillDirection = Enum.FillDirection.Vertical; ddList.VerticalAlignment = Enum.VerticalAlignment.Top
    ddList.SortOrder = Enum.SortOrder.LayoutOrder; ddList.Padding = UDim.new(0, 2)
    local DD_IH, DD_MAX_ROWS = 32, 6
    local ddSlot = {tween = nil}
    local selectedPlayer = nil

    local function setClips(state)
        pcall(function()
            local z = state and 5 or 100 -- Elevate when open (state=false means opening/visible)
            pill.ZIndex = z
            local curr = pill.Parent
            while curr and curr ~= ScreenGui do
                if curr:IsA("GuiObject") then 
                    curr.ClipsDescendants = state 
                    curr.ZIndex = z
                end
                curr = curr.Parent
            end
        end)
    end

    local function closeDd()
        if _activePlayerPillDropdown ~= ddFrame then return end
        _activePlayerPillDropdown = nil; setClips(true)
        if onToggle then onToggle(false, 0) end
        twP(arrow, 0.2, {Rotation = 0})
        local t = twC(ddSlot, ddFrame, 0.2, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        t.Completed:Connect(function() if _activePlayerPillDropdown ~= ddFrame then ddFrame.Visible = false end end)
    end

    local function buildDd()
        for _, ch in ipairs(ddScroll:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
        local plrs = {}
        for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LocalPlayer then table.insert(plrs, pl) end end
        if #plrs == 0 then
            local noLbl = Instance.new("TextLabel", ddScroll)
            noLbl.Size = UDim2.new(1, 0, 0, DD_IH); noLbl.BackgroundTransparency = 1
            noLbl.Text = "No other players online"; noLbl.Font = Enum.Font.GothamBold; noLbl.TextSize = 12
            noLbl.TextColor3 = C.sub; noLbl.ZIndex = 5002
        end
        for _, pl in ipairs(plrs) do
            local row = Instance.new("Frame", ddScroll)
            row.Size = UDim2.new(1, -4, 0, DD_IH); row.BackgroundColor3 = C.bg3
            row.BackgroundTransparency = 0.9; row.BorderSizePixel = 0; row.ZIndex = 5002; corner(row, 10)
            local pad = Instance.new("UIPadding", row); pad.PaddingLeft = UDim.new(0, 12)
            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(1, -10, 1, 0); nameLbl.BackgroundTransparency = 1
            nameLbl.Text = pl.DisplayName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
            nameLbl.TextColor3 = (selectedPlayer == pl) and C.red or C.text
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 5003
            local rBtn = Instance.new("TextButton", row)
            rBtn.Size = UDim2.new(1, 0, 1, 0); rBtn.BackgroundTransparency = 1; rBtn.Text = ""
            rBtn.ZIndex = 5004; rBtn.Active = true
            rBtn.MouseEnter:Connect(function() twP(row, 0.15, {BackgroundTransparency = 0.7}) end)
            rBtn.MouseLeave:Connect(function() twP(row, 0.15, {BackgroundTransparency = 0.9}) end)
            rBtn.MouseButton1Click:Connect(function()
                selectedPlayer = pl; pillLbl.Text = pl.DisplayName; pillLbl.TextColor3 = C.accent
                if onSelect then onSelect(pl) end; closeDd()
            end)
        end
        local cnt = math.max(1, #plrs)
        ddScroll.CanvasSize = UDim2.new(0, 0, 0, cnt * (DD_IH + 2) + 8)
        return math.min(cnt, DD_MAX_ROWS) * (DD_IH + 2) + 8
    end

    pillBtn.MouseButton1Click:Connect(function()
        if _activePlayerPillDropdown == ddFrame then closeDd(); return end
        if _activePlayerPillDropdown then pcall(function() _activePlayerPillDropdown.Visible = false end) end
        _activePlayerPillDropdown = ddFrame
        local targetH = buildDd(); ddScroll.CanvasPosition = Vector2.new(0, 0)
        
        local absPos, absSize = pill.AbsolutePosition, pill.AbsoluteSize
        local screenH = ScreenGui.AbsoluteSize.Y
        local spaceBelow = screenH - (absPos.Y + absSize.Y + 12)
        local spaceAbove = absPos.Y - 12
        local finalH, posUDim
        if spaceBelow >= 80 or spaceBelow >= spaceAbove then
            posUDim = UDim2.new(0, 0, 1, 4); finalH = math.min(targetH, spaceBelow - 4)
        else
            posUDim = UDim2.new(0, 0, 0, -targetH - 4); finalH = math.min(targetH, spaceAbove - 4)
        end
        
        ddFrame.Position = posUDim; ddFrame.Size = UDim2.new(1, 0, 0, 0); ddFrame.Visible = true; setClips(false)
        if onToggle then onToggle(true, finalH) end
        twP(pillS, 0.2, {Color = C.accent or C.red, Transparency = 0.2})
        twP(arrow, 0.2, {Rotation = 180})
        twC(ddSlot, ddFrame, 0.25, {Size = UDim2.new(1, 0, 0, finalH)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)

    UserInputService.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and _activePlayerPillDropdown == ddFrame then
            task.defer(function()
                local mp = UserInputService:GetMouseLocation()
                local abP, abS = ddFrame.AbsolutePosition, ddFrame.AbsoluteSize
                local inD = mp.X >= abP.X and mp.X <= abP.X + abS.X and mp.Y >= abP.Y and mp.Y <= abP.Y + abS.Y
                local paP, paS = pill.AbsolutePosition, pill.AbsoluteSize
                local inP = mp.X >= paP.X and mp.X <= paP.X + paS.X and mp.Y >= paP.Y and mp.Y <= paP.Y + paS.Y
                if not inD and not inP then closeDd() end
            end)
        end
    end)

    return {
        pill = pill,
        setTarget = function(pl)
            if not pl then
                selectedPlayer = nil; pillLbl.Text = defaultText; pillLbl.TextColor3 = C.text
            else
                selectedPlayer = pl; pillLbl.Text = pl.DisplayName; pillLbl.TextColor3 = C.accent or C.red
            end
            if onSelect then onSelect(pl) end
        end,
        getSelected = function() return selectedPlayer end,
        destroy = function() pcall(function() ddFrame:Destroy(); pill:Destroy() end) end
    }
end
do
local gbActive        = false
local gbConn          = nil
local gbTargetPlayer  = nil
local gbAngle         = 0
local GB_RADIUS       = 4
local GB_SPEED        = 3.5
local GB_OSC_AMP      = 2.5
local GB_OSC_SPEED    = 8.0

local function gbStop()
    gbActive = false
    if gbConn then gbConn:Disconnect(); gbConn = nil end
    gbAngle = 0
    local myChar = LocalPlayer.Character
    if myChar then
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        local hrp = myChar:FindFirstChild("HumanoidRootPart")
        if hum then hum.WalkSpeed = 16 end
        if hrp then hrp.Anchored = false end
    end
end

local function gbStart(targetPlayer)
gbStop()
local targetChar = targetPlayer and targetPlayer.Character
if not targetChar then
return false
end
local myChar = LocalPlayer.Character
if not myChar then return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not hum then return false end
gbActive       = true
gbTargetPlayer = targetPlayer
hum.WalkSpeed  = 0
local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
if targetHRP then
local diff = myHRP.Position - targetHRP.Position
gbAngle = math.atan2(diff.Z, diff.X)
end
local _gbMyHRP  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
local _gbTgtHRP = gbTargetPlayer and gbTargetPlayer.Character and gbTargetPlayer.Character:FindFirstChild("HumanoidRootPart")
local _gbCharCache = LocalPlayer.Character
local _gbTgtCharCache = gbTargetPlayer and gbTargetPlayer.Character
gbConn = RunService.Heartbeat:Connect(function(dt)
if not gbActive then return end
local _lpc = LocalPlayer.Character
if _lpc ~= _gbCharCache then
_gbCharCache = _lpc
_gbMyHRP = _lpc and _lpc:FindFirstChild("HumanoidRootPart")
end
local tChar = gbTargetPlayer and gbTargetPlayer.Character
if tChar ~= _gbTgtCharCache then
_gbTgtCharCache = tChar
_gbTgtHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
end
local tHRP = _gbTgtHRP
local myH  = _gbMyHRP
if not tHRP or not tHRP.Parent or not myH or not myH.Parent then gbStop(); return end
gbAngle = gbAngle + GB_SPEED * dt
local center     = tHRP.Position
local radialDir  = _V3new(_mcos(gbAngle), 0, _msin(gbAngle))
local oscillation = _msin(gbAngle * GB_OSC_SPEED) * GB_OSC_AMP
local dynRadius  = GB_RADIUS + oscillation
local newPos     = center + radialDir * dynRadius
pcall(function()
myH.CFrame = CFrame.new(newPos, Vector3.new(center.X, newPos.Y, center.Z))
end)
end)
-- Orbiting successfully
return true
end
-- Zwei Zeilen wie Movement (Speed Hack): oben Label+OPEN+Geschw.+Slider+Toggle, unten volle Breite Player-Pill
local GB_ROW_H = TROLL_TOP_H + TROLL_GAP + TROLL_BOT_H
local gbRow = Instance.new("Frame", trollPage)
gbRow.Size = UDim2.new(1, 0, 0, GB_ROW_H); gbRow.LayoutOrder = 1
gbRow.BackgroundColor3 = C.bg2 or _C3_BG2; gbRow.BackgroundTransparency = 0
gbRow.BorderSizePixel = 0; corner(gbRow, 12)
local gbRowS = _makeDummyStroke(gbRow)
gbRowS.Thickness = 1; gbRowS.Color = C.bg3 or _C3_BG3; gbRowS.Transparency = 0.3
local gbTop = Instance.new("Frame", gbRow)
gbTop.Size = UDim2.new(1, 0, 0, TROLL_TOP_H); gbTop.Position = UDim2.new(0, 0, 0, 0)
gbTop.BackgroundTransparency = 1; gbTop.BorderSizePixel = 0
local gbRowDot = Instance.new("Frame", gbRow)
gbRowDot.Size = UDim2.new(0, 3, 0, 26); gbRowDot.Visible = false; gbRowDot.Position = UDim2.new(0, 0, 0, 10)
gbRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220, 60, 60); gbRowDot.BackgroundTransparency = 0.4
gbRowDot.BorderSizePixel = 0; corner(gbRowDot, 99)
local gbLbl = Instance.new("TextLabel", gbTop)
gbLbl.Size = UDim2.new(0, 120, 1, 0); gbLbl.Position = UDim2.new(0, 16, 0, 0)
gbLbl.BackgroundTransparency = 1; gbLbl.Text = T.gb_label
gbLbl.Font = Enum.Font.GothamBold; gbLbl.TextSize = 13
gbLbl.TextColor3 = C.text; gbLbl.TextXAlignment = Enum.TextXAlignment.Left
local gbPillObj = createPlayerPill(gbRow, TROLL_TOP_H + TROLL_GAP + 4, T.gb_player_pill, T.gb_player_pill, function(pl)
    gbTargetPlayer = pl
end, function(on, h)
    twP(gbRow, 0.25, {Size = UDim2.new(1, 0, 0, on and (TROLL_ROW_H + h) or TROLL_ROW_H)})
end)
local gbPill = gbPillObj.pill
local gbSelectedPlayer = nil -- for toggle logic compatibility
local gbSetToggle
local gbState = false
local GB_TOG_X = PANEL_W - 10 - 44
local GB_SPEED_X = 198
local GB_TRK_X = 240
local GB_TRK_W = math.max(56, GB_TOG_X - 8 - GB_TRK_X)
if GB_TRK_W < 72 then
    GB_TRK_W = math.clamp(GB_TOG_X - 198 - 36 - 16, 56, 140)
    GB_TRK_X = GB_TOG_X - 8 - GB_TRK_W
    GB_SPEED_X = math.max(140, GB_TRK_X - 40)
end
local GB_OPEN_X = (GB_SPEED_X >= 198) and 138 or math.max(70, GB_SPEED_X - 60)
do
local GB_SLIDER_MIN, GB_SLIDER_MAX = 1, 50
local gbSpeedVal = math.floor(GB_SPEED * 10)
local gbSpeedLbl = Instance.new("TextLabel", gbTop)
gbSpeedLbl.Size = UDim2.new(0, 36, 0, 22); gbSpeedLbl.Position = UDim2.new(0, GB_SPEED_X, 0.5, -11)
gbSpeedLbl.BackgroundTransparency = 1; gbSpeedLbl.Text = tostring(gbSpeedVal)
gbSpeedLbl.Font = Enum.Font.GothamBold; gbSpeedLbl.TextSize = 12
gbSpeedLbl.TextColor3 = C.accent or C.red; gbSpeedLbl.TextXAlignment = Enum.TextXAlignment.Center
local gbTrack = Instance.new("Frame", gbTop)
gbTrack.Size = UDim2.new(0, GB_TRK_W, 0, 8); gbTrack.Position = UDim2.new(0, GB_TRK_X, 0.5, -4)
gbTrack.BackgroundColor3 = C.bg3; gbTrack.BorderSizePixel = 0
corner(gbTrack, 4); stroke(gbTrack, 1, C.accent or C.red, 0.6)
local gbFill = Instance.new("Frame", gbTrack)
gbFill.Size = UDim2.new((gbSpeedVal - GB_SLIDER_MIN) / (GB_SLIDER_MAX - GB_SLIDER_MIN), 0, 1, 0)
gbFill.BackgroundColor3 = C.accent or C.red; gbFill.BorderSizePixel = 0; corner(gbFill, 4)
local gbKnob = Instance.new("Frame", gbTrack)
gbKnob.Size = UDim2.new(0, 14, 0, 14)
gbKnob.Position = UDim2.new((gbSpeedVal - GB_SLIDER_MIN) / (GB_SLIDER_MAX - GB_SLIDER_MIN), -7, 0.5, -7)
gbKnob.BackgroundColor3 = _C3_WHITE; gbKnob.BorderSizePixel = 0; gbKnob.ZIndex = 5
corner(gbKnob, 99)
local gbKS = _makeDummyStroke(gbKnob); gbKS.Thickness = 1.5; gbKS.Color = C.accent or C.red; gbKS.Transparency = 0
local gbDragging = false
local function updateGbSlider(absX)
local ratio = math.clamp((absX - gbTrack.AbsolutePosition.X) / gbTrack.AbsoluteSize.X, 0, 1)
gbSpeedVal = math.floor(GB_SLIDER_MIN + ratio * (GB_SLIDER_MAX - GB_SLIDER_MIN))
gbFill.Size = UDim2.new(ratio, 0, 1, 0)
gbKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
gbSpeedLbl.Text = tostring(gbSpeedVal)
GB_SPEED = gbSpeedVal / 10
end
local gbInput = Instance.new("TextButton", gbTrack)
gbInput.Size = UDim2.new(1, 14, 1, 14); gbInput.Position = UDim2.new(0, -7, 0, -7)
gbInput.BackgroundTransparency = 1; gbInput.Text = ""; gbInput.ZIndex = 6
gbInput.MouseButton1Down:Connect(function(x) gbDragging = true; updateGbSlider(x) end)
gbInput.MouseMoved:Connect(function(x) if gbDragging then updateGbSlider(x) end end)
gbInput.MouseButton1Up:Connect(function() gbDragging = false end)
gbInput.MouseLeave:Connect(function() gbDragging = false end)
-- Touch support for GB row slider
gbInput.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        gbDragging = true; updateGbSlider(inp.Position.X)
    end
end)
gbInput.InputChanged:Connect(function(inp)
    if gbDragging and inp.UserInputType == Enum.UserInputType.Touch then
        updateGbSlider(inp.Position.X)
    end
end)
gbInput.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then gbDragging = false end
end)
end
local _, gbSetToggleFn, gbGetFn = makeToggle(gbTop, GB_TOG_X, 11, false, function(on)
gbState = on
if on then
    local target = gbPillObj.getSelected()
    if not target then
        task.defer(function() gbSetToggleFn(false) end); return
    end
    local ok = gbStart(target)
    if not ok then task.defer(function() gbSetToggleFn(false) end) end
else
    gbStop()
end
end)
;(function() -- Gangbang widget
    local GB_FULL = 210
    local gbWState = false

    local function gbWBtnDo()
        createScriptWidget("Gangbang", C.accent2, function(on)
            gbWState = on
            if on then
                local np = getNearestPlayer()
                if np then
                    gbPillObj.setTarget(np)
                end
                local target = gbPillObj.getSelected()
                if not target then
                    return false
                end
                local ok = gbStart(target)
                return ok
            else
                gbStop()
            end
        end, gbWState, function(body, width, yOffset, ac, setToggleFn)
            -- Speed Row (Home Style)
            local sRow = Instance.new("Frame", body)
            sRow.Size = UDim2.new(1,-24,0,54); sRow.Position = UDim2.new(0,12,0,yOffset+4)
            sRow.BackgroundColor3 = C.bg2 or Color3.fromRGB(30, 30, 32); sRow.BackgroundTransparency = 0.4
            sRow.BorderSizePixel = 0; corner(sRow, 10)
            local sStr = _makeDummyStroke(sRow); sStr.Thickness = 1; sStr.Color = ac; sStr.Transparency = 0.8
            
            local sHdr = Instance.new("TextLabel", sRow)
            sHdr.Size = UDim2.new(1,-16,0,20); sHdr.Position = UDim2.new(0,12,0,6)
            sHdr.BackgroundTransparency = 1; sHdr.Text = "VELOCITY SPEED"; sHdr.Font = Enum.Font.GothamBlack
            sHdr.TextSize = 10; sHdr.TextColor3 = ac; sHdr.TextXAlignment = Enum.TextXAlignment.Left
            
            local sVal = Instance.new("TextLabel", sRow)
            sVal.Size = UDim2.new(0,40,0,20); sVal.Position = UDim2.new(1,-52,0,6)
            sVal.BackgroundTransparency = 1; sVal.Text = tostring(math.floor(GB_SPEED*10))
            sVal.Font = Enum.Font.GothamBlack; sVal.TextSize = 11; sVal.TextColor3 = ac
            sVal.TextXAlignment = Enum.TextXAlignment.Right
            
            local sTrack = Instance.new("Frame", sRow)
            sTrack.Size = UDim2.new(1,-24,0,6); sTrack.Position = UDim2.new(0,12,0,34)
            sTrack.BackgroundColor3 = Color3.fromRGB(15,15,18); corner(sTrack,4)
            local sTrackS = _makeDummyStroke(sTrack); sTrackS.Thickness = 1; sTrackS.Color = C.bg3; sTrackS.Transparency = 0.5
            
            local sFill = Instance.new("Frame", sTrack)
            local r = math.clamp((GB_SPEED*10 - 1) / 49, 0, 1)
            sFill.Size = UDim2.new(r,0,1,0); sFill.BackgroundColor3 = ac; corner(sFill,4)
            
            local sKnob = Instance.new("Frame", sTrack)
            sKnob.Size = UDim2.new(0,16,0,16); sKnob.Position = UDim2.new(r,-8,0.5,-8); sKnob.BackgroundColor3 = _C3_WHITE; corner(sKnob,99)
            local skStr = _makeDummyStroke(sKnob); skStr.Thickness = 1.5; skStr.Color = ac; skStr.Transparency = 0.2
            
            local sInp = Instance.new("TextButton", sTrack); sInp.Size = UDim2.new(1,16,1,16); sInp.Position = UDim2.new(0,-8,0,-8); sInp.BackgroundTransparency = 1; sInp.Text = ""
            local dragging = false
            local function up(x)
                local rat = math.clamp((x - sTrack.AbsolutePosition.X) / sTrack.AbsoluteSize.X, 0, 1)
                local v = math.floor(1 + rat * 49)
                sFill.Size = UDim2.new(rat,0,1,0); sKnob.Position = UDim2.new(rat,-8,0.5,-8); sVal.Text = tostring(v); GB_SPEED = v / 10
                pcall(function() gbSpeedLbl.Text = tostring(v) end)
                twP(sKnob, 0.08, {BackgroundColor3 = _C3_WHITE}); skStr.Transparency = 0
            end
            sInp.MouseButton1Down:Connect(function(x) dragging=true; up(x) end)
            sInp.MouseMoved:Connect(function(x) if dragging then up(x) end end)
            sInp.MouseButton1Up:Connect(function() dragging=false; skStr.Transparency = 0.2 end)
            sInp.MouseLeave:Connect(function() dragging=false; skStr.Transparency = 0.2 end)
            
            return 62 -- height with padding
        end)
    end
    makeWidgetOpenBtn(gbTop, 138, 10, "OPEN", gbWBtnDo)

    gbSetToggle = function(on)
        if on and not gbWState then gbWBtnDo() end 
    end

end)()
    -- Player pill logic handled by createPlayerPill helper
LocalPlayer.CharacterAdded:Connect(function()
if gbActive then
gbStop()
task.defer(function() pcall(function() gbSetToggleFn(false) end) end)
end
end)
end
do
local rushActive        = false
local rushConn          = nil
local rushSelectedPlayer = nil
local rushNoclipConn    = nil
local RUSH_ANIM_ID = "132168791204839"
local rushAnimTrack = nil
local rushAnimConn  = nil
local function rushStopAnim()
if rushAnimConn then rushAnimConn:Disconnect(); rushAnimConn = nil end
if rushAnimTrack then
pcall(function() rushAnimTrack:AdjustSpeed(1); rushAnimTrack:Stop() end)
rushAnimTrack = nil
end
end
local function rushPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(RUSH_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("RushAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, RUSH_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
if getgenv and getgenv().TLAnimFreeze then getgenv().TLAnimFreeze(true) end
rushAnimTrack = track
if rushAnimConn then rushAnimConn:Disconnect() end
rushAnimConn = track.Stopped:Connect(function()
if rushActive then
task.wait(0.05)
if rushActive then pcall(function() rushPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function rushStop()
rushActive = false
if rushConn then rushConn:Disconnect(); rushConn = nil end
if rushNoclipConn then rushNoclipConn:Disconnect(); rushNoclipConn = nil end
rushStopAnim()
if getgenv and getgenv().TLAnimFreeze then getgenv().TLAnimFreeze(false) end
local myChar = LocalPlayer.Character
if myChar then
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if hrp then hrp.Anchored = false end
if hum then if not flyActive then hum.PlatformStand = false end; hum.WalkSpeed = 16 end
for _, part in ipairs(myChar:GetDescendants()) do
if part:IsA("BasePart") then part.CanCollide = true end
end
end
-- Stopped successfully
end
local function rushStart(targetPlayer)
rushStop()
local targetChar = targetPlayer and targetPlayer.Character
if not targetChar then return false end
local myChar = LocalPlayer.Character
if not myChar then return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not hum then return false end
rushActive = true
hum.PlatformStand = true
hum.WalkSpeed = 0
pcall(function() myHRP:SetNetworkOwner(LocalPlayer) end)
task.spawn(function() rushPlayAnim(myChar) end)
local _rushParts = {}
do
local c = LocalPlayer.Character
if c then
for _, p in ipairs(c:GetDescendants()) do
if p:IsA("BasePart") then _rushParts[#_rushParts+1] = p end
end
end
end
rushNoclipConn = RunService.Stepped:Connect(function()
    if not rushActive then return end
    local rp = _rushParts; local n = #rp
    if n == 0 then return end
    for i = 1, n do
        local p = rp[i]
        if p and p.Parent then p.CanCollide = false end
    end
end)
local _rushMyHRP  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
local _rushTgtHRP = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
local _rushCharCache = LocalPlayer.Character
local _rushTgtCache  = targetPlayer and targetPlayer.Character
rushConn = RunService.Heartbeat:Connect(function(dt)
if not rushActive then return end
local _lpc = LocalPlayer.Character
if _lpc ~= _rushCharCache then
_rushCharCache = _lpc
_rushMyHRP = _lpc and _lpc:FindFirstChild("HumanoidRootPart")
end
local tChar = targetPlayer and targetPlayer.Character
if tChar ~= _rushTgtCache then
_rushTgtCache = tChar
_rushTgtHRP = tChar and tChar:FindFirstChild("HumanoidRootPart")
end
local tHRP = _rushTgtHRP
local myH  = _rushMyHRP
if not tHRP or not tHRP.Parent or not myH or not myH.Parent then rushStop(); return end
local dist = (myH.Position - tHRP.Position).Magnitude
if dist <= 1.5 then
pcall(function() myH.AssemblyLinearVelocity = Vector3.zero end)
myH.CFrame = CFrame.new(myH.Position, Vector3.new(tHRP.Position.X, myH.Position.Y, tHRP.Position.Z))
rushStop()
return
end
local dir    = (tHRP.Position - myH.Position).Unit
local speed  = math.clamp(dist * 12, 40, 180)
pcall(function() myH.AssemblyLinearVelocity = dir * speed end)
myH.CFrame = CFrame.new(myH.Position, Vector3.new(tHRP.Position.X, myH.Position.Y, tHRP.Position.Z))
end)
-- Running successfully
return true
end
local RUSH_ROW_H = TROLL_TOP_H + TROLL_GAP + TROLL_BOT_H
local rushRow = Instance.new("Frame", trollPage)
rushRow.Size = UDim2.new(1, 0, 0, RUSH_ROW_H); rushRow.LayoutOrder = 2
rushRow.BackgroundColor3 = C.bg2 or _C3_BG2; rushRow.BackgroundTransparency = 0
rushRow.BorderSizePixel = 0; corner(rushRow, 12)
local rushTop = Instance.new("Frame", rushRow)
rushTop.Size = UDim2.new(1, 0, 0, TROLL_TOP_H); rushTop.Position = UDim2.new(0, 0, 0, 0)
rushTop.BackgroundTransparency = 1; rushTop.BorderSizePixel = 0
local rushRowDot = Instance.new("Frame", rushRow)
rushRowDot.Size = UDim2.new(0, 3, 0, 26); rushRowDot.Visible = false; rushRowDot.Position = UDim2.new(0, 0, 0, 10)
rushRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220,60,60); rushRowDot.BackgroundTransparency = 0.4
rushRowDot.BorderSizePixel = 0; corner(rushRowDot, 99)
local rushLbl = Instance.new("TextLabel", rushTop)
rushLbl.Size = UDim2.new(0, 120, 1, 0); rushLbl.Position = UDim2.new(0, 16, 0, 0)
rushLbl.BackgroundTransparency = 1; rushLbl.Text = T.rush_label
rushLbl.Font = Enum.Font.GothamBold; rushLbl.TextSize = 13
rushLbl.TextColor3 = C.text; rushLbl.TextXAlignment = Enum.TextXAlignment.Left
local rushPillObj = createPlayerPill(rushRow, TROLL_TOP_H + TROLL_GAP + 4, T.rush_player_pill, T.rush_player_pill, function(pl)
    rushSelectedPlayer = pl
end, function(on, h)
    twP(rushRow, 0.25, {Size = UDim2.new(1, 0, 0, on and (TROLL_ROW_H + h) or TROLL_ROW_H)})
end)
local rushPill = rushPillObj.pill
local rushBtn = Instance.new("TextButton", rushTop)
rushBtn.Size = UDim2.new(0, 70, 0, 24); rushBtn.Position = UDim2.new(1, -82, 0.5, -12)
rushBtn.BackgroundColor3 = Color3.fromRGB(18,8,8); rushBtn.BackgroundTransparency = 0
rushBtn.BorderSizePixel = 0; rushBtn.Text = "Rush"
rushBtn.Font = Enum.Font.GothamBold; rushBtn.TextSize = 13
rushBtn.TextColor3 = C.text; rushBtn.ZIndex = 5
corner(rushBtn, 11)
local rushBtnS = _makeDummyStroke(rushBtn)
rushBtnS.Thickness = 1.2; rushBtnS.Color = C.red; rushBtnS.Transparency = 0.1
rushBtn.MouseButton1Click:Connect(function()
    local target = rushPillObj.getSelected()
    if not target then return end
    rushStart(target)
end)
rushBtn.MouseEnter:Connect(function()
_playHoverSound()
twP(rushBtn, 0.1, {BackgroundTransparency = 0.0})
end)
rushBtn.MouseLeave:Connect(function()
twP(rushBtn, 0.1, {BackgroundTransparency = 0.1})
end)
local rushWState = false
local function rushWBtnPillDo()
    local rushWState2 = rushWState or false
    createScriptWidget("Rush", C.accent2, function(on)
        rushWState = on
        if on then
            local np = getNearestPlayer()
            if np then rushPillObj.setTarget(np) end
            local target = rushPillObj.getSelected()
            if not target then return end
            rushStart(target)
        else rushStop() end
    end, rushWState2, function(body, width, yOffset, ac, setToggleFn)
        local sRow = Instance.new("Frame", body)
        sRow.Size = UDim2.new(1,-24,0,38); sRow.Position = UDim2.new(0,12,0,yOffset+4)
        sRow.BackgroundColor3 = C.bg2; sRow.BackgroundTransparency = 0.4
        sRow.BorderSizePixel = 0; corner(sRow, 10)
        local sStr = _makeDummyStroke(sRow); sStr.Thickness = 1; sStr.Color = ac; sStr.Transparency = 0.8
        
        local sHdr = Instance.new("TextLabel", sRow)
        sHdr.Size = UDim2.new(1,-16,1,0); sHdr.Position = UDim2.new(0,12,0,0)
        sHdr.BackgroundTransparency = 1; sHdr.Text = "READY TO RUSH"; sHdr.Font = Enum.Font.GothamBlack
        sHdr.TextSize = 10; sHdr.TextColor3 = ac; sHdr.TextXAlignment = Enum.TextXAlignment.Left
        
        local sIco = Instance.new("Frame", sRow)
        sIco.Size = UDim2.new(0,6,0,6); sIco.Position = UDim2.new(1,-18,0.5,-3)
        sIco.BackgroundColor3 = ac; sIco.BorderSizePixel = 0; corner(sIco, 99)
        
        return 46
    end)
end
makeWidgetOpenBtn(rushTop, 138, 10, "OPEN", rushWBtnPillDo)
    -- Player pill logic handled by createPlayerPill helper
LocalPlayer.CharacterAdded:Connect(function()
if rushActive then rushStop() end
end)
end
do
local flingActive         = false
local flingConn           = nil
local flingSelectedPlayer = nil
local _flingSavedCFrame   = nil
local _flingThread        = nil

local function _flingDisconnect()
    flingActive = false
    if flingConn then
        pcall(function() flingConn:Disconnect() end)
        flingConn = nil
        pcall(function() if getgenv then _genv._TLFlingConn = nil end end)
    end
    if _flingThread then
        pcall(function() task.cancel(_flingThread) end)
        _flingThread = nil
    end
end

-- SkidFling: oscillate around target to launch them
local function _skidFling(targetPlayer)
    local Character  = LocalPlayer.Character
    local Humanoid   = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart   = Humanoid and Humanoid.RootPart
    local TCharacter = targetPlayer and targetPlayer.Character
    if not Character or not Humanoid or not RootPart or not TCharacter then return end

    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead     = TCharacter:FindFirstChild("Head")
    local Handle    = (TCharacter:FindFirstChildOfClass("Accessory") or {Handle=nil}).Handle

    local BasePart = TRootPart or THead or Handle
    if not BasePart then return end

    if RootPart.Velocity.Magnitude < 50 then
        _flingSavedCFrame = RootPart.CFrame
    end
    if THumanoid and THumanoid.Sit then return end

    local savedFPDH = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Parent   = RootPart
    BV.Velocity = Vector3.new(0,0,0)
    BV.MaxForce = Vector3.new(9e9,9e9,9e9)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local FPos = function(bp, pos, ang)
        RootPart.CFrame = CFrame.new(bp.Position) * pos * ang
        pcall(function() Character:SetPrimaryPartCFrame(CFrame.new(bp.Position) * pos * ang) end)
        RootPart.Velocity          = Vector3.new(9e7, 9e7*10, 9e7)
        RootPart.RotVelocity       = Vector3.new(9e8, 9e8, 9e8)
    end

    local deadline = tick() + 2
    local angle    = 0
    repeat
        if not (RootPart and RootPart.Parent and THumanoid and THumanoid.Parent) then break end
        if BasePart.Velocity.Magnitude < 50 then
            angle = angle + 100
            FPos(BasePart, CFrame.new(0,1.5,0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude/1.25, CFrame.Angles(math.rad(angle),0,0)) task.wait()
            FPos(BasePart, CFrame.new(0,-1.5,0)+ THumanoid.MoveDirection * BasePart.Velocity.Magnitude/1.25, CFrame.Angles(math.rad(angle),0,0)) task.wait()
            FPos(BasePart, CFrame.new(0,1.5,0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(angle),0,0)) task.wait()
            FPos(BasePart, CFrame.new(0,-1.5,0)+ THumanoid.MoveDirection, CFrame.Angles(math.rad(angle),0,0)) task.wait()
        else
            FPos(BasePart, CFrame.new(0,1.5, THumanoid.WalkSpeed),  CFrame.Angles(math.rad(90),0,0)) task.wait()
            FPos(BasePart, CFrame.new(0,-1.5,-THumanoid.WalkSpeed), CFrame.Angles(0,0,0))             task.wait()
            FPos(BasePart, CFrame.new(0,1.5, THumanoid.WalkSpeed),  CFrame.Angles(math.rad(90),0,0)) task.wait()
            FPos(BasePart, CFrame.new(0,-1.5,0), CFrame.Angles(math.rad(90),0,0)) task.wait()
            FPos(BasePart, CFrame.new(0,-1.5,0), CFrame.Angles(0,0,0))             task.wait()
        end
    until tick() > deadline or not flingActive

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

    -- Reset position
    if _flingSavedCFrame and RootPart and RootPart.Parent then
        local tries = 0
        repeat
            pcall(function()
                RootPart.CFrame = _flingSavedCFrame * CFrame.new(0,0.5,0)
                Character:SetPrimaryPartCFrame(_flingSavedCFrame * CFrame.new(0,0.5,0))
                Humanoid:ChangeState("GettingUp")
                for _, part in ipairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Velocity    = Vector3.zero
                        part.RotVelocity = Vector3.zero
                    end
                end
            end)
            task.wait()
            tries = tries + 1
        until (RootPart.Position - _flingSavedCFrame.p).Magnitude < 25 or tries > 30
    end

    workspace.FallenPartsDestroyHeight = savedFPDH
end

local function flingStop()
    _flingDisconnect()
    local savedCF = _flingSavedCFrame
    _flingSavedCFrame = nil
    task.spawn(function()
        task.wait(0.08)
        pcall(function()
            local ch  = LocalPlayer.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local hrp = hum and hum.RootPart
            if not hum or not hrp then return end
            -- 1) Unfreeze humanoid states that _skidFling may have disabled
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated,     true) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Running,     true) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping,     true) end)
            -- 2) Clear PlatformStand
            hum.PlatformStand = false
            -- 3) Kill all velocities on every body part
            for _, p in ipairs(ch:GetChildren()) do
                if p:IsA("BasePart") then
                    pcall(function() p.Velocity        = Vector3.zero end)
                    pcall(function() p.RotVelocity     = Vector3.zero end)
                    pcall(function() p.AssemblyLinearVelocity  = Vector3.zero end)
                    pcall(function() p.AssemblyAngularVelocity = Vector3.zero end)
                end
            end
            -- 4) Destroy any stray BodyVelocity left by _skidFling
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BodyVelocity") or p:IsA("BodyGyro") or p:IsA("BodyPosition") then
                    pcall(function() p:Destroy() end)
                end
            end
            -- 5) Teleport back to saved position (if we have one)
            if savedCF then
                for attempt = 1, 15 do
                    pcall(function()
                        hrp.CFrame = savedCF * CFrame.new(0, 0.5, 0)
                        ch:SetPrimaryPartCFrame(savedCF * CFrame.new(0, 0.5, 0))
                    end)
                    task.wait(0.05)
                    if (hrp.Position - savedCF.p).Magnitude < 10 then break end
                end
            end
            -- 6) Force humanoid back to running state
            task.wait(0.05)
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(0.1)
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end)
    end)
end

local function flingStart(targetPlayer)
    _flingDisconnect()
    if not targetPlayer then return end
    -- Save current position as return-home point
    pcall(function()
        local ch  = LocalPlayer.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then _flingSavedCFrame = hrp.CFrame end
    end)
    flingActive = true
    _flingThread = task.spawn(function()
        while flingActive do
            _skidFling(targetPlayer)
            if flingActive then task.wait(0.1) end
        end
    end)
    pcall(function() if getgenv then _genv._TLFlingConn = flingConn end end)
end
local FLING_SUB_H = 12
local FLING_ROW_H = TROLL_TOP_H + TROLL_GAP + FLING_SUB_H + 32
local flingRow = Instance.new("Frame", trollPage)
flingRow.Size = UDim2.new(1, 0, 0, FLING_ROW_H); flingRow.LayoutOrder = 3
flingRow.BackgroundColor3 = C.bg2 or _C3_BG2; flingRow.BackgroundTransparency = 0
flingRow.BorderSizePixel = 0; corner(flingRow, 12)
local flingTop = Instance.new("Frame", flingRow)
flingTop.Size = UDim2.new(1, 0, 0, TROLL_TOP_H); flingTop.Position = UDim2.new(0, 0, 0, 0)
flingTop.BackgroundTransparency = 1; flingTop.BorderSizePixel = 0
local flingRowDot = Instance.new("Frame", flingRow)
flingRowDot.Size = UDim2.new(0, 3, 0, 26); flingRowDot.Visible = false; flingRowDot.Position = UDim2.new(0, 0, 0, 10)
flingRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220, 60, 60); flingRowDot.BackgroundTransparency = 0.4
flingRowDot.BorderSizePixel = 0; corner(flingRowDot, 99)
local flingLbl = Instance.new("TextLabel", flingTop)
flingLbl.Size = UDim2.new(0, 120, 1, 0); flingLbl.Position = UDim2.new(0, 16, 0, 0)
flingLbl.BackgroundTransparency = 1; flingLbl.Text = "Fling"
flingLbl.Font = Enum.Font.GothamBold; flingLbl.TextSize = 13
flingLbl.TextColor3 = C.text or _C3_TEXT3
flingLbl.TextXAlignment = Enum.TextXAlignment.Left
local _flingPillY = TROLL_TOP_H + TROLL_GAP + FLING_SUB_H + 4
local flingSub = Instance.new("TextLabel", flingRow)
flingSub.Size = UDim2.new(1, -32, 0, FLING_SUB_H); flingSub.Position = UDim2.new(0, 16, 0, TROLL_TOP_H + TROLL_GAP)
flingSub.BackgroundTransparency = 1; flingSub.Text = "Anchor-Fling  ◈  BodyVelocity"
flingSub.Font = Enum.Font.GothamBold; flingSub.TextSize = 9
flingSub.TextColor3 = C.sub or _C3_SUB
flingSub.TextXAlignment = Enum.TextXAlignment.Left
local flingPillObj = createPlayerPill(flingRow, _flingPillY, T.rush_player_pill, T.rush_player_pill, function(pl)
    flingSelectedPlayer = pl
    if flingTogState then flingStart(pl) end
end, function(on, h)
    twP(flingRow, 0.25, {Size = UDim2.new(1, 0, 0, on and (FLING_ROW_H + h) or FLING_ROW_H)})
end)
local flingPill = flingPillObj.pill
flingPill.ZIndex = 8
flingPillObj.setTarget(flingSelectedPlayer)
local flingTrack = Instance.new("Frame", flingTop)
flingTrack.Size = UDim2.new(0,32,0,18); flingTrack.Position = UDim2.new(1,-44,0.5,-9)
flingTrack.BackgroundColor3 = C.bg3 or _C3_BG3
flingTrack.BackgroundTransparency = 0.2; flingTrack.BorderSizePixel = 0; corner(flingTrack, 99)
local flingKnob = Instance.new("Frame", flingTrack)
flingKnob.Size = UDim2.new(0,12,0,12); flingKnob.Position = UDim2.new(0,2,0.5,-6)
flingKnob.BackgroundColor3 = _C3_SUB2
flingKnob.BackgroundTransparency = 0; flingKnob.BorderSizePixel = 0; corner(flingKnob, 99)
local flingTogState = false
local function flingSetToggle(on)
    flingTogState = on
    if on then
        twP(flingTrack, 0.15, {BackgroundColor3 = C.red or Color3.fromRGB(220,60,60), BackgroundTransparency = 0.55})
        twP(flingKnob,  0.15, {BackgroundColor3 = _C3_WHITE, Position = UDim2.new(1,-14,0.5,-6)})
        
        -- Improved selection: only pick nearest if no player is manually selected
        local target = flingPillObj.getSelected()
        if not target then
            local np = getNearestPlayer()
            if np then
                flingPillObj.setTarget(np)
                target = np
            end
        end
        
        if target then
            flingStart(target)
        else
            flingSetToggle(false); return
        end
    else
        twP(flingTrack, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
        twP(flingKnob,  0.15, {BackgroundColor3 = _C3_SUB2, Position = UDim2.new(0,2,0.5,-6)})
        -- Keep flingSelectedPlayer for persistence; don't reset to nil
        flingStop()
    end
end
local flingRowBtn = Instance.new("TextButton", flingRow)
-- Nur unterer Bereich – volle Höhe würde Top-Zeile (Toggle/Track/OPEN) fangen
flingRowBtn.Size = UDim2.new(1, 0, 0, FLING_ROW_H - TROLL_TOP_H)
flingRowBtn.Position = UDim2.new(0, 0, 0, TROLL_TOP_H)
flingRowBtn.BackgroundTransparency = 1; flingRowBtn.Text = ""; flingRowBtn.ZIndex = 5
flingRowBtn.MouseEnter:Connect(function()
_playHoverSound()
twP(flingRow, 0.08, {BackgroundColor3 = C.bg3 or _C3_BG4})
end)
flingRowBtn.MouseLeave:Connect(function()
twP(flingRow, 0.08, {BackgroundColor3 = C.bg2 or _C3_BG2})
end)
local flingTogBtn = Instance.new("TextButton", flingTop)
flingTogBtn.Size = UDim2.new(0,36,0,24); flingTogBtn.Position = UDim2.new(1,-44,0.5,-12)
flingTogBtn.BackgroundTransparency = 1; flingTogBtn.Text = ""; flingTogBtn.ZIndex = 7
flingTogBtn.MouseButton1Click:Connect(function() flingSetToggle(not flingTogState) end)
    -- Player pill logic handled by createPlayerPill helper
local flingWState = false
local function flingWBtnPillDo()
    local flingWState2 = flingWState or false
    createScriptWidget("Fling", C.accent2, function(on)
        flingWState = on
        if on then
            local target = flingPillObj.getSelected()
            if not target then
                local np = getNearestPlayer()
                if np then 
                    flingPillObj.setTarget(np)
                    target = np
                end
            end
            if not target then return false end
            flingStart(target)
            return true
        else
            flingStop()
        end
    end, flingWState2, function(body, width, yOffset, ac, setToggleFn)
        local sRow = Instance.new("Frame", body)
        sRow.Size = UDim2.new(1,-24,0,38); sRow.Position = UDim2.new(0,12,0,yOffset+4)
        sRow.BackgroundColor3 = C.bg2; sRow.BackgroundTransparency = 0.4
        sRow.BorderSizePixel = 0; corner(sRow, 10)
        local sStr = _makeDummyStroke(sRow); sStr.Thickness = 1; sStr.Color = ac; sStr.Transparency = 0.8
        
        local sHdr = Instance.new("TextLabel", sRow)
        sHdr.Size = UDim2.new(1,-16,1,0); sHdr.Position = UDim2.new(0,12,0,0)
        sHdr.BackgroundTransparency = 1; sHdr.Text = "FLING ACTIVE"; sHdr.Font = Enum.Font.GothamBlack
        sHdr.TextSize = 10; sHdr.TextColor3 = ac; sHdr.TextXAlignment = Enum.TextXAlignment.Left
        
        local sIco = Instance.new("Frame", sRow)
        sIco.Size = UDim2.new(0,6,0,6); sIco.Position = UDim2.new(1,-18,0.5,-3)
        sIco.BackgroundColor3 = ac; sIco.BorderSizePixel = 0; corner(sIco, 99)
        
        return 46
    end)
end
makeWidgetOpenBtn(flingTop, 138, 10, "OPEN", flingWBtnPillDo)
LocalPlayer.CharacterAdded:Connect(function()
_flingSavedCFrame = nil
_flingDisconnect()
flingTogState = false
twP(flingTrack, 0.15, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2})
twP(flingKnob,  0.15, {BackgroundColor3 = _C3_SUB2, Position = UDim2.new(0,2,0.5,-6)})
twP(flingRowS,  0.15, {Color = C.bg3, Transparency = 0.3})
end)
end

do
    local outfitRow = Instance.new("Frame", trollPage)
    outfitRow.Size = UDim2.new(1, 0, 0, 46); outfitRow.LayoutOrder = 4
    outfitRow.BackgroundColor3 = Color3.fromRGB(22, 22, 22); outfitRow.BackgroundTransparency = 0
    outfitRow.BorderSizePixel = 0; 
    local outfitCorner = Instance.new("UICorner", outfitRow); outfitCorner.CornerRadius = UDim.new(0, 12)
    local outfitRowS = _makeDummyStroke(outfitRow)
    outfitRowS.Thickness = 1; outfitRowS.Color = Color3.fromRGB(44, 44, 48); outfitRowS.Transparency = 0.3
    
    local outfitLbl = Instance.new("TextLabel", outfitRow)
    outfitLbl.Size = UDim2.new(0, 150, 1, 0); outfitLbl.Position = UDim2.new(0, 16, 0, 0)
    outfitLbl.BackgroundTransparency = 1; outfitLbl.Text = "Avatar Outfits Stealer"
    outfitLbl.Font = Enum.Font.GothamBold; outfitLbl.TextSize = 13
    outfitLbl.TextColor3 = Color3.fromRGB(255, 255, 255); outfitLbl.TextXAlignment = Enum.TextXAlignment.Left

    local outfitBtn = Instance.new("TextButton", outfitRow)
    outfitBtn.Size = UDim2.new(0, 70, 0, 24); outfitBtn.Position = UDim2.new(1, -82, 0.5, -12)
    outfitBtn.BackgroundColor3 = Color3.fromRGB(18,8,8); outfitBtn.BackgroundTransparency = 0
    outfitBtn.BorderSizePixel = 0; outfitBtn.Text = "Open"
    outfitBtn.Font = Enum.Font.GothamBold; outfitBtn.TextSize = 13
    outfitBtn.TextColor3 = Color3.fromRGB(255, 255, 255); outfitBtn.ZIndex = 5
    local outfitBtnCorner = Instance.new("UICorner", outfitBtn); outfitBtnCorner.CornerRadius = UDim.new(0, 11)
    local outfitBtnS = _makeDummyStroke(outfitBtn)
    outfitBtnS.Thickness = 1.2; outfitBtnS.Color = Color3.fromRGB(220, 60, 60); outfitBtnS.Transparency = 0.1
    
    local GLOBAL_ENV  = (typeof(getgenv) == "function" and getgenv()) or _G
    local RUNTIME_KEY = "__TLSteal_AvatarOutfitPanelRuntime"

    local prev = GLOBAL_ENV and GLOBAL_ENV[RUNTIME_KEY]
    if type(prev) == "table" and type(prev.cleanup) == "function" then
        pcall(prev.cleanup)
    end

    local outfitPanelAPI = nil
    local function initAvatarOutfit()
        -- AvatarOutfitPanelTest.lua content
-- AvatarOutfitPanel – OPTIMIZED
-- Verbesserungen: TweenInfo-Pool, LRU-Cache, gecachte httpFunc,
--   debounced Search, RenderStepped nur bei aktivem Drag, objekt-Pool
--   für Shimmer-Tweens, Batch-Preload, sauberere Zustandsmaschine,
--   alle pcall-Pfade konsolidiert, Forward-Declarations aufgelöst,
--   checkAndMakeFolder dedupliziert, CountLabel-Text gecacht,
--   getSortedPlayers ohne unnötige Tabellen-Allokation,
--   applyTransparencySnapshot schreibt nur bei echter Änderung.

local Services = {
    Players           = game:GetService("Players"),
    UserInputService  = game:GetService("UserInputService"),
    TweenService      = game:GetService("TweenService"),
    HttpService       = game:GetService("HttpService"),
    RunService        = game:GetService("RunService"),
    ContentProvider   = game:GetService("ContentProvider"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    AvatarEditorSvc   = game:GetService("AvatarEditorService"),
}
local Players     = Services.Players
local LocalPlayer = Players.LocalPlayer
local AvatarEditorSvc = Services.AvatarEditorSvc
local HttpService = Services.HttpService
local TweenService = Services.TweenService
local RunService = Services.RunService
local UserInputService = Services.UserInputService

-- ══════════════════════════════════════════════
--  KONFIGURATION
-- ══════════════════════════════════════════════
local C = {
    THUMBNAIL_TYPE       = "AvatarBust",
    PANEL_W              = 440,
    PANEL_H              = 340,
    CARD_W               = 108,
    CARD_H               = 136,
    GAP                  = 8,
    SUB_W                = 480,
    SUB_H                = 360,
    SUB_OUT_W            = 120,
    OUT_W                = 98,
    OUT_H                = 128,
    OUTFIT_THUMB_SIZE    = 150,
    THUMB_PRIORITY_COUNT = 8,
    THUMB_STAGGER_BATCH  = 6,
    THUMB_STAGGER_DELAY  = 0.05,

    -- Global Theme Mapping --
    panelBg      = _genv.C.panelBg or Color3.fromRGB(10, 10, 10),
    panelHdr     = _genv.C.panelHdr or Color3.fromRGB(20, 20, 20),
    bg3          = _genv.C.bg3 or Color3.fromRGB(28, 28, 28),
    accent       = _genv.C.accent or Color3.fromRGB(255, 255, 255),

    BG           = _genv.C.panelBg or Color3.fromRGB(10,  10,  11),
    BG_SOFT      = Color3.fromRGB(16,  16,  18),
    TITLEBAR     = _genv.C.panelHdr or Color3.fromRGB(5,   5,   6),
    CARD         = Color3.fromRGB(20,  20,  22),
    CARD_HOVER   = Color3.fromRGB(30,  30,  33),
    ACCENT       = _genv.C.accent or Color3.fromRGB(255, 255, 255),
    TEXT1        = _genv.C.text or Color3.fromRGB(255, 255, 255),
    TEXT2        = _genv.C.sub or Color3.fromRGB(156, 156, 156),
    BORDER       = _genv.C.bg3 or Color3.fromRGB(70,  70,  74),
    BORDER_SOFT  = Color3.fromRGB(46,  46,  50),
    SHADOW       = Color3.fromRGB(0,   0,   0),
    CLOSE_HOVER  = Color3.fromRGB(200, 30,  30),

    KEYBIND            = Enum.KeyCode.L,
    CLOSE_IMAGE        = "rbxassetid://121032825074289",

    WORKSPACE_ROOT       = "TLSteal",
    CACHE_FOLDER         = "Cache",
    SAVED_FOLDER         = "SavedOutfits",
    DISK_CACHE_DIR       = "TLSteal/Cache",
    DISK_CACHE_TTL       = 86400,
    SAVED_OUTFITS_FILE   = "saved_outfits.dat",
    REMOTE_NAME          = "BLINK_RELIABLE_REMOTE",
    DEBUG_LOGS           = false,
}

-- ══════════════════════════════════════════════
--  RUNTIME / CLEANUP
-- ══════════════════════════════════════════════

local runtime = { connections = {}, instances = {}, destroyed = false }
runtime.cleanup = function()
    if runtime.destroyed then return end
    runtime.destroyed = true
    for _, c in ipairs(runtime.connections) do pcall(function() c:Disconnect() end) end
    runtime.connections = {}
    for i = #runtime.instances, 1, -1 do
        local inst = runtime.instances[i]
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end
    runtime.instances = {}
    if GLOBAL_ENV and GLOBAL_ENV[RUNTIME_KEY] == runtime then GLOBAL_ENV[RUNTIME_KEY] = nil end
end
if GLOBAL_ENV then GLOBAL_ENV[RUNTIME_KEY] = runtime end

local function registerInstance(inst)
    table.insert(runtime.instances, inst)
    return inst
end

local function bind(signal, handler)
    local c = signal:Connect(handler)
    table.insert(runtime.connections, c)
    return c
end

local function log(...)
    if C.DEBUG_LOGS then print(...) end
end

-- ══════════════════════════════════════════════
--  TWEEN-INFO POOL  (verhindert GC-Druck)
-- ══════════════════════════════════════════════
local _tweenInfoPool = {}
local function getTI(t, style, dir, rep, rev, delay)
    style = style or Enum.EasingStyle.Quad
    dir   = dir   or Enum.EasingDirection.Out
    local key = string.format("%s_%s_%s_%s_%s_%s", t, style.Name, dir.Name, rep or 0, rev and 1 or 0, delay or 0)
    if not _tweenInfoPool[key] then
        _tweenInfoPool[key] = TweenInfo.new(t, style, dir, rep or 0, rev or false, delay or 0)
    end
    return _tweenInfoPool[key]
end

local TI = {
    _012 = getTI(0.12),
    _015 = getTI(0.15),
    _016 = getTI(0.16),
    _018 = getTI(0.18),
    _020 = getTI(0.20),
    _025 = getTI(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    _022 = getTI(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
    _008 = getTI(0.08),
    _010 = getTI(0.10),
    _014 = getTI(0.14),
    _080 = getTI(0.80),
    _090_SHIMMER = getTI(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
}

local function tween(obj, info, props)
    return Services.TweenService:Create(obj, info, props)
end

-- ══════════════════════════════════════════════
--  EXECUTOR-FILESYSTEM HELPERS
-- ══════════════════════════════════════════════
local FS = {
    read    = typeof(readfile)    == "function" and readfile    or nil,
    write   = typeof(writefile)   == "function" and writefile   or nil,
    isfile  = typeof(isfile)      == "function" and isfile      or nil,
    isfolder= typeof(isfolder)    == "function" and isfolder    or nil,
    mkdir   = (typeof(makefolder) == "function" and makefolder)
           or (typeof(createfolder) == "function" and createfolder)
           or nil,
    del     = (typeof(delfile)    == "function" and delfile)
           or (typeof(removefile) == "function" and removefile)
           or nil,
}
local diskCacheAvailable = FS.read and FS.write and FS.isfile and FS.mkdir

-- Erstellt Ordner-Struktur einmalig, ohne doppelte pcall-Kaskaden
local _madefolders = {}
local function ensureFolder(path)
    if _madefolders[path] then return end
    _madefolders[path] = true
    if not FS.mkdir then return end
    if FS.isfolder then
        if not FS.isfolder(path) then pcall(FS.mkdir, path) end
    else
        pcall(FS.mkdir, path)
    end
end

local function ensureBaseFolders()
    ensureFolder(C.WORKSPACE_ROOT)
    ensureFolder(C.WORKSPACE_ROOT .. "/" .. C.CACHE_FOLDER)
    ensureFolder(C.WORKSPACE_ROOT .. "/" .. C.SAVED_FOLDER)
end

if diskCacheAvailable then ensureBaseFolders() end

-- ══════════════════════════════════════════════
--  HILFSFUNKTIONEN (UI)
-- ══════════════════════════════════════════════



-- ══════════════════════════════════════════════
--  OBFUSKATION / DISK ENCODE-DECODE
-- ══════════════════════════════════════════════
local OBFUSCATION_KEY = "TLSteal::AvatarOutfitPanel"
local OBF_LEN = #OBFUSCATION_KEY

local function obfuscateString(raw)
    local out = table.create(#raw)
    for i = 1, #raw do
        local src    = string.byte(raw, i)
        local keyB   = string.byte(OBFUSCATION_KEY, ((i - 1) % OBF_LEN) + 1)
        out[i] = string.format("%02x", (src + keyB + i) % 256)
    end
    return "TLS1:" .. table.concat(out)
end

local function deobfuscateString(raw)
    if type(raw) ~= "string" then return nil, "Kein String" end
    if raw:sub(1, 5) ~= "TLS1:" then return raw, nil end
    local hex = raw:sub(6)
    if (#hex % 2) ~= 0 then return nil, "Ungültige Obfuskation" end
    local chars   = table.create(#hex / 2)
    local outIdx  = 0
    for pos = 1, #hex, 2 do
        outIdx = outIdx + 1
        local part = tonumber(hex:sub(pos, pos + 1), 16)
        if not part then return nil, "Ungültige Hex-Daten" end
        local keyB   = string.byte(OBFUSCATION_KEY, ((outIdx - 1) % OBF_LEN) + 1)
        chars[outIdx] = string.char((part - keyB - outIdx) % 256)
    end
    return table.concat(chars), nil
end

local function encodeStoredJson(data)
    local ok, json = pcall(Services.HttpService.JSONEncode, Services.HttpService, data)
    return (ok and json) and obfuscateString(json) or nil
end

local function decodeStoredJson(raw)
    local decodedRaw, decErr = deobfuscateString(raw)
    if not decodedRaw then return nil, decErr end
    local ok, data = pcall(Services.HttpService.JSONDecode, Services.HttpService, decodedRaw)
    if not ok or type(data) ~= "table" then return nil, "JSON-Fehler" end
    return data, nil
end

-- ══════════════════════════════════════════════
--  DISK-CACHE
-- ══════════════════════════════════════════════
local function diskCachePath(userId)
    return C.WORKSPACE_ROOT .. "/" .. C.CACHE_FOLDER .. "/cache_" .. tostring(userId) .. ".dat"
end
local function legacyDiskCachePath(userId)
    return "AvatarOutfitCache/" .. tostring(userId) .. ".json"
end

local function diskCacheRead(userId)
    if not diskCacheAvailable then return nil end
    local path = diskCachePath(userId)
    local ok, raw = pcall(FS.read, path)
    local migrateLegacy = false

    if not ok or not raw or raw == "" then
        local legOk, legRaw = pcall(FS.read, legacyDiskCachePath(userId))
        if legOk and legRaw and legRaw ~= "" then
            raw = legRaw; migrateLegacy = true
        else
            return nil
        end
    end

    local data = decodeStoredJson(raw)
    if type(data) ~= "table" then return nil end

    if C.DISK_CACHE_TTL > 0 and (os.time() - (data.timestamp or 0)) > C.DISK_CACHE_TTL then
        if FS.del then pcall(FS.del, path) end
        return nil
    end

    if type(data.outfits) == "table" and #data.outfits == 0 then
        if FS.del then pcall(FS.del, path) end
        return nil
    end

    if migrateLegacy then
        local encoded = encodeStoredJson({ userId=userId, timestamp=os.time(), outfits=data.outfits or {} })
        if encoded then pcall(FS.write, path, encoded) end
    end

    return data
end

local function diskCacheWrite(userId, outfits)
    if not diskCacheAvailable then return end
    local encoded = encodeStoredJson({ userId=userId, timestamp=os.time(), outfits=outfits })
    if encoded then pcall(FS.write, diskCachePath(userId), encoded) end
end

local function diskCacheInvalidate(userId)
    if not diskCacheAvailable then return end
    if FS.del then
        pcall(FS.del, diskCachePath(userId))
        pcall(FS.del, legacyDiskCachePath(userId))
    end
end

-- ══════════════════════════════════════════════
--  LRU-RAM-CACHE (begrenzt auf 64 Einträge)
-- ══════════════════════════════════════════════
local Cache = {
    TTL       = 120,
    LRU_MAX   = 64,
    outfits   = {},        -- { [userId] = {outfits, timestamp, order} }
    lruOrder  = {},        -- Reihenfolge der userId-Keys
    lruSet    = {},
}

local function lruTouch(userId)
    if Cache.lruSet[userId] then
        for i, v in ipairs(Cache.lruOrder) do
            if v == userId then table.remove(Cache.lruOrder, i); break end
        end
    end
    table.insert(Cache.lruOrder, userId)
    Cache.lruSet[userId] = true
    -- Älteste Einträge verdrängen
    while #Cache.lruOrder > Cache.LRU_MAX do
        local evict = table.remove(Cache.lruOrder, 1)
        Cache.lruSet[evict]    = nil
        Cache.outfits[evict] = nil
    end
end

local function cacheGet(userId)
    local e = Cache.outfits[userId]
    if e and (tick() - e.timestamp) < Cache.TTL then
        lruTouch(userId)
        return e.outfits
    end
    return nil
end

local function cacheSet(userId, outfits)
    Cache.outfits[userId] = { outfits=outfits, timestamp=tick() }
    lruTouch(userId)
end

local function cacheDel(userId)
    Cache.outfits[userId] = nil
    Cache.lruSet[userId] = nil
end

-- ══════════════════════════════════════════════
--  SAVED OUTFITS
-- ══════════════════════════════════════════════
local SavedOutfitsState = {
    outfits            = {},
    workspaceFolder    = C.WORKSPACE_ROOT .. "/" .. C.SAVED_FOLDER,
    workspacePath      = C.WORKSPACE_ROOT .. "/" .. C.SAVED_FOLDER .. "/",
    loaded             = false,
    lastLoad           = 0,
    syncInterval       = 2,
}

local function getSavedOutfitsFilePath()
    return SavedOutfitsState.workspacePath .. C.SAVED_OUTFITS_FILE
end
local function legacySavedOutfitsFilePath()
    return "TLMenu_Outfits/TLSavedOutfits.json"
end

local function persistSavedOutfits()
    local encoded = encodeStoredJson(SavedOutfitsState.outfits)
    if encoded then
        ensureBaseFolders()
        pcall(FS.write, getSavedOutfitsFilePath(), encoded)
        SavedOutfitsState.loaded  = true
        SavedOutfitsState.lastLoad = tick()
    end
end

local function loadSavedOutfitsFromCache(forceReload)
    if not forceReload and SavedOutfitsState.loaded and (tick() - SavedOutfitsState.lastLoad) < SavedOutfitsState.syncInterval then
        return
    end
    local ok, content = pcall(FS.read or function() end, getSavedOutfitsFilePath())
    local migrateLegacy = false
    if not ok or not content or content == "" then
        local lok, lc = pcall(FS.read or function() end, legacySavedOutfitsFilePath())
        if lok and lc and lc ~= "" then
            content = lc; migrateLegacy = true
        else
            SavedOutfitsState.loaded = true; SavedOutfitsState.lastLoad = tick(); return
        end
    end
    local data = decodeStoredJson(content)
    if type(data) == "table" then
        SavedOutfitsState.outfits = data
        SavedOutfitsState.loaded  = true
        SavedOutfitsState.lastLoad = tick()
        if migrateLegacy then
            ensureBaseFolders()
            local enc = encodeStoredJson(SavedOutfitsState.outfits)
            if enc then pcall(FS.write, getSavedOutfitsFilePath(), enc) end
        end
    end
end

local function saveOutfitToCache(outfitId, outfitName, playerName, displayName, userId)
    if not SavedOutfitsState.loaded then loadSavedOutfitsFromCache(true) end
    local key = tostring(userId) .. "_" .. tostring(outfitId)
    SavedOutfitsState.outfits[key] = { outfitId=outfitId, outfitName=outfitName,
                          playerName=playerName, displayName=displayName, userId=userId }
    persistSavedOutfits()
end

local function removeOutfitFromCache(outfitId, userId)
    if not SavedOutfitsState.loaded then loadSavedOutfitsFromCache(true) end
    SavedOutfitsState.outfits[tostring(userId) .. "_" .. tostring(outfitId)] = nil
    persistSavedOutfits()
end

local function countSavedOutfits()
    local n = 0
    for _ in pairs(SavedOutfitsState.outfits) do n = n + 1 end
    return n
end

-- Init
ensureBaseFolders()
loadSavedOutfitsFromCache(true)

-- ══════════════════════════════════════════════
--  HTTP / QUEUE
-- ══════════════════════════════════════════════
local HTTP_CFG = {
    MIN_DELAY         = 0.35,
    MAX_RETRIES       = 2,
    BACKOFF_BASE      = 1.5,
    RATE_LIMIT_WAIT   = 3.5,
    RATE_LIMIT_JITTER = 0.45,
    MIN_DELAY_JITTER  = 0.08,
    ITEMS_PAGE        = 100,
    MAX_PAGES         = 200,
}

-- ══════════════════════════════════════════════
--  PROXY CONFIGURATION
-- ══════════════════════════════════════════════
local PROXY_HOSTS = {
    "avatar.roproxy.com",
}

-- Proxy-Health-Tracking
local proxyHealth = {}
for i, host in ipairs(PROXY_HOSTS) do
    proxyHealth[host] = {
        failures = 0,
        lastFailure = 0,
        cooldownUntil = 0,
        successCount = 0,
        blacklisted = false
    }
end

local PROXY_FAILURE_THRESHOLD = 3
local PROXY_FAILURE_COOLDOWN = 30
local PROXY_SWITCH_COOLDOWN = 5
local globalProxyCooldownUntil = 0
local lastProxySwitch = 0
local proxyIndex = 1

local function getNextProxy()
    local now = tick()
    if now < globalProxyCooldownUntil then
        return PROXY_HOSTS[proxyIndex]
    end
    if now - lastProxySwitch < PROXY_SWITCH_COOLDOWN then
        return PROXY_HOSTS[proxyIndex]
    end
    local attempts = 0
    local maxAttempts = #PROXY_HOSTS
    while attempts < maxAttempts do
        local currentHost = PROXY_HOSTS[proxyIndex]
        local health = proxyHealth[currentHost]
        if health and not health.blacklisted and health.failures < PROXY_FAILURE_THRESHOLD then
            return currentHost
        end
        proxyIndex = (proxyIndex % #PROXY_HOSTS) + 1
        attempts = attempts + 1
    end
    lastProxySwitch = now
    return PROXY_HOSTS[proxyIndex]
end

local function getCurrentProxy()
    local attempts = 0
    local maxAttempts = #PROXY_HOSTS
    while attempts < maxAttempts do
        local currentHost = PROXY_HOSTS[proxyIndex]
        local health = proxyHealth[currentHost]
        if health and not health.blacklisted then
            return currentHost
        end
        proxyIndex = (proxyIndex % #PROXY_HOSTS) + 1
        attempts = attempts + 1
    end
    return PROXY_HOSTS[proxyIndex]
end

local function rotateProxyForNextLoad()
    proxyIndex = (proxyIndex % #PROXY_HOSTS) + 1
end

local function markProxySuccess(host)
    if proxyHealth[host] then
        proxyHealth[host].failures = math.max(0, proxyHealth[host].failures - 1)
        proxyHealth[host].successCount = proxyHealth[host].successCount + 1
    end
end

local function markProxyFailure(host)
    if proxyHealth[host] then
        proxyHealth[host].failures = proxyHealth[host].failures + 1
        proxyHealth[host].lastFailure = tick()
        if proxyHealth[host].failures >= PROXY_FAILURE_THRESHOLD then
            proxyHealth[host].cooldownUntil = tick() + PROXY_FAILURE_COOLDOWN
        end
    end
end

local function isProxyInCooldown(host)
    local health = proxyHealth[host]
    return health and tick() < health.cooldownUntil
end

-- URL Building Functions with Proxy Support
local function buildOutfitDetailsUrl(host, outfitId)
    return string.format("https://%s/v1/outfits/%d/details", host, outfitId)
end

local function buildUrl(host, userId, token)
    local base = string.format(
        "https://%s/v2/avatar/users/%d/outfits?itemsPerPage=%d",
        host, userId, HTTP_CFG.ITEMS_PAGE
    )
    if token and token ~= "" then
        base = base .. "&paginationToken=" .. tostring(token)
    end
    return base
end

local HttpQueue = {
    rateLimitCooldown = 0,
    requestQueue      = {},
    queueRunning      = false,
    inFlightOutfits   = {},
    inFlightDetails   = {},
}

local OutfitDetailsCache = {
    cache = {},
    ttl   = 300,
}

-- httpFunc: broad executor compatibility (Synapse, Velocity, ByteBreaker, Fluxus, KRNL, Hydrogen, Codex, etc.)
local function _resolveHttpFunc()
    local raw = (syn         and type(syn.request)      == "function" and syn.request)
             or (http        and type(http.request)     == "function" and http.request)
             or (fluxus      and type(fluxus.request)   == "function" and fluxus.request)
             or (typeof(request)      == "function" and request)
             or (typeof(http_request) == "function" and http_request)
             or nil
    if not raw then return nil end
    -- Wrap to normalise response fields across all executors
    return function(opts)
        local ok, resp = pcall(raw, opts)
        if not ok or type(resp) ~= "table" then return nil end
        local code = tonumber(resp.StatusCode or resp.statusCode or resp.status_code) or 0
        local body = resp.Body or resp.body or ""
        local hdrs = resp.Headers or resp.headers or {}
        return { StatusCode = code, Body = body, Headers = hdrs }
    end
end
local httpFunc = _resolveHttpFunc()

local function getJitter(max) return math.random() * (max or 0) end

local function parseRetryAfter(resp)
    if type(resp) ~= "table" or type(resp.Headers) ~= "table" then return nil end
    return tonumber(resp.Headers["Retry-After"] or resp.Headers["retry-after"] or "")
end

local function runSingleFlight(store, key, fn)
    local ex = store[key]
    if ex and ex.event then return ex.event.Event:Wait() end
    local ev = Instance.new("BindableEvent")
    store[key] = { event = ev }
    local packed = table.pack(pcall(fn))
    local results
    if packed[1] then
        results = table.pack(table.unpack(packed, 2, packed.n))
    else
        results = table.pack(nil, tostring(packed[2]))
    end
    store[key] = nil
    ev:Fire(table.unpack(results, 1, results.n))
    ev:Destroy()
    return table.unpack(results, 1, results.n)
end

local enqueueRequest
enqueueRequest = function(fn)
    local co = coroutine.running()
    table.insert(HttpQueue.requestQueue, function()
        local r = table.pack(fn())
        task.defer(function() coroutine.resume(co, table.unpack(r, 1, r.n)) end)
    end)
    if not HttpQueue.queueRunning then
        HttpQueue.queueRunning = true
        task.spawn(function()
            while #HttpQueue.requestQueue > 0 do
                local rem = HttpQueue.rateLimitCooldown - tick()
                if rem > 0 then task.wait(rem + getJitter(HTTP_CFG.RATE_LIMIT_JITTER * 0.35)) end
                local nxt = table.remove(HttpQueue.requestQueue, 1)
                nxt()
                task.wait(HTTP_CFG.MIN_DELAY + getJitter(HTTP_CFG.MIN_DELAY_JITTER))
            end
            HttpQueue.queueRunning = false
        end)
    end
    return coroutine.yield()
end

local function httpGetWithRetry(url)
    if not httpFunc then return nil, "Kein HTTP-Executor" end
    local lastErr
    local currentHost = url:match("https://([^/]+)")
    for attempt = 1, HTTP_CFG.MAX_RETRIES do
        if currentHost and isProxyInCooldown(currentHost) then
            local nextProxy = getNextProxy()
            if nextProxy ~= currentHost then
                currentHost = nextProxy
                url = url:gsub("https://[^/]+", "https://" .. nextProxy, 1)
            end
        end
        local ok, resp = pcall(httpFunc, { Url=url, Method="GET", Headers={["Accept"]="application/json"} })
        if ok and resp then
            local code = resp.StatusCode
            if code == 200 then
                if currentHost then markProxySuccess(currentHost) end
                return resp.Body, nil
            elseif code == 429 then
                lastErr = "429 Rate Limit"
                if currentHost then markProxyFailure(currentHost) end
                local ra  = parseRetryAfter(resp)
                local wait = math.max(HTTP_CFG.RATE_LIMIT_WAIT, ra or 0) + getJitter(HTTP_CFG.RATE_LIMIT_JITTER)
                HttpQueue.rateLimitCooldown = math.max(HttpQueue.rateLimitCooldown, tick() + wait)
                local nextProxy = getNextProxy()
                if nextProxy ~= currentHost then
                    currentHost = nextProxy
                    url = url:gsub("https://[^/]+", "https://" .. nextProxy, 1)
                end
                task.wait(0.5 + getJitter(0.2))
            elseif code == 403 then
                lastErr = "403 Forbidden"
                if currentHost then markProxyFailure(currentHost) end
                local nextProxy = getNextProxy()
                if nextProxy ~= currentHost then
                    currentHost = nextProxy
                    url = url:gsub("https://[^/]+", "https://" .. nextProxy, 1)
                end
                task.wait(0.3 + getJitter(0.15))
            elseif code >= 500 then
                lastErr = "Server " .. code
                task.wait((HTTP_CFG.BACKOFF_BASE * (attempt - 0.25)) + getJitter(0.35))
            else
                return nil, "HTTP " .. code
            end
        else
            lastErr = "pcall-Fehler"
            if currentHost then markProxyFailure(currentHost) end
            task.wait(0.45 + getJitter(0.25))
        end
    end
    return nil, lastErr or "Max Versuche erreicht"
end

local function fetchOutfitDetailsViaHttp(outfitId)
    local cached = OutfitDetailsCache.cache[outfitId]
    if cached and (tick() - cached.timestamp) < OutfitDetailsCache.ttl then
        return cached.details, nil
    end
    if not httpFunc then return nil, "Kein HTTP-Executor" end
    return runSingleFlight(HttpQueue.inFlightDetails, outfitId, function()
        local fc = OutfitDetailsCache.cache[outfitId]
        if fc and (tick() - fc.timestamp) < OutfitDetailsCache.ttl then return fc.details, nil end
        local activeHost = getCurrentProxy()
        local url  = buildOutfitDetailsUrl(activeHost, outfitId)
        local body, err = enqueueRequest(function() return httpGetWithRetry(url) end)
        if err then return nil, err end
        local ok, parsed = pcall(Services.HttpService.JSONDecode, Services.HttpService, body)
        if not ok or type(parsed) ~= "table" or not parsed.id then return nil, "Ungültige Details" end
        OutfitDetailsCache.cache[outfitId] = { details=parsed, timestamp=tick() }
        return parsed, nil
    end)
end

local function fetchOutfitsViaHttp(userId)
    local cached = cacheGet(userId)
    if cached then return cached, nil end

    local diskEntry = diskCacheRead(userId)
    if diskEntry and type(diskEntry.outfits) == "table" and #diskEntry.outfits > 0 then
        cacheSet(userId, diskEntry.outfits)
        return diskEntry.outfits, nil
    end

    if not httpFunc then return nil, "Kein HTTP-Executor" end

    return runSingleFlight(HttpQueue.inFlightOutfits, userId, function()
        -- Double-check nach Single-Flight-Eintritt
        local fc = cacheGet(userId)
        if fc then return fc, nil end
        local fd = diskCacheRead(userId)
        if fd and type(fd.outfits) == "table" and #fd.outfits > 0 then
            cacheSet(userId, fd.outfits); return fd.outfits, nil
        end

        rotateProxyForNextLoad()
        local all = {}
        local token = ""
        for page = 1, HTTP_CFG.MAX_PAGES do
            local url = buildUrl(getCurrentProxy(), userId, token)
            local body, err = enqueueRequest(function() return httpGetWithRetry(url) end)
            if err then
                if #all > 0 then break end
                return nil, err
            end
            local ok, parsed = pcall(Services.HttpService.JSONDecode, Services.HttpService, body)
            if not ok or type(parsed) ~= "table" then break end
            if parsed.errors and #parsed.errors > 0 then
                return nil, "Inventar ist Privat"
            end
            if not parsed.data then break end
            for _, item in ipairs(parsed.data) do
                table.insert(all, { name=item.name, id=item.id })
            end
            token = parsed.paginationToken
            if not token or token == "" then break end
        end

        if #all > 0 then
            cacheSet(userId, all)
            diskCacheWrite(userId, all)
        else
            cacheDel(userId)
            diskCacheInvalidate(userId)
        end
        return all, nil
    end)
end
-- Buffer-Objekt wird einmalig gecacht
local _applyBuf = (typeof(buffer) == "table" and buffer.fromstring)
    and buffer.fromstring("\005\014")
    or string.char(5, 14)

local function applyOutfit(outfitId)
    local remote = Services.ReplicatedStorage:FindFirstChild(C.REMOTE_NAME)
    if not remote then warn("[AvatarOutfitPanel] Remote nicht gefunden:", C.REMOTE_NAME); return false end
    local ok, err = pcall(function() remote:FireServer(_applyBuf, {outfitId}) end)
    if not ok then warn("[AvatarOutfitPanel] Fehler beim Anwenden:", err) end
    return ok
end

-- ══════════════════════════════════════════════
--  GUI CLEANUP (bestehende Instanzen)
-- ══════════════════════════════════════════════
local existingPG = LocalPlayer:FindFirstChild("PlayerGui")
if existingPG then
    for _, n in ipairs({"AvatarOutfitPanel","AvatarOutfitPanelHint"}) do
        local e = existingPG:FindFirstChild(n)
        if e then pcall(e.Destroy, e) end
    end
end

-- ══════════════════════════════════════════════
--  SCREEN GUI
-- ══════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "AvatarOutfitPanel"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
registerInstance(ScreenGui)
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════
--  PANEL OPEN/CLOSE TWEENS
-- ══════════════════════════════════════════════
local function getPopScale(frame)
    local s = frame:FindFirstChild("PopScale")
    if not s then
        s = Instance.new("UIScale", frame)
        s.Name = "PopScale"
    end
    return s
end

local function tweenOpen(frame, w, h)
    frame.Size = UDim2.fromOffset(w, h)
    frame.BackgroundTransparency = 0
    frame.Visible = true
    local s = getPopScale(frame)
    s.Scale = 0.85
    -- Clean, modern pop-in with slight bounce
    tween(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function tweenClose(frame, w, h, cb)
    local s = getPopScale(frame)
    -- Fast, clean pop-out without buggy clipping
    tween(s, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.85}):Play()
    
    task.delay(0.15, function()
        frame.Visible = false
        s.Scale = 1 -- Reset for next open
        if cb then cb() end
    end)
end

local function makeCloseBtn(parent, size, posX, posY, anchorX, anchorY)
    local btn = Instance.new("ImageButton")
    btn.Size                  = UDim2.fromOffset(size, size)
    btn.Position              = UDim2.new(posX, posY, anchorX or 0.5, 0)
    btn.AnchorPoint           = Vector2.new(anchorY or 0, 0.5)
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel       = 0
    btn.Image                 = C.CLOSE_IMAGE
    btn.ImageColor3           = Color3.fromRGB(255, 255, 255)
    btn.ZIndex                = 22
    btn.Parent                = parent
    corner(btn, 9)
    bind(btn.MouseEnter,       function() tween(btn, TI._012, { ImageColor3=Color3.fromRGB(242,0,0) }):Play() end)
    bind(btn.MouseLeave,       function() tween(btn, TI._012, { ImageColor3=Color3.fromRGB(255,255,255) }):Play() end)
    bind(btn.MouseButton1Down, function() tween(btn, TI._008, { Size=UDim2.fromOffset(size-1,size-1) }):Play() end)
    bind(btn.MouseButton1Up,   function() tween(btn, TI._008, { Size=UDim2.fromOffset(size,size) }):Play() end)
    return btn
end

local _avatarThumbCache = {}
local function avatarThumbUrl(userId)
    local k = userId
    if not _avatarThumbCache[k] then
        _avatarThumbCache[k] = string.format("rbxthumb://type=%s&id=%d&w=150&h=150", C.THUMBNAIL_TYPE, userId)
    end
    return _avatarThumbCache[k]
end

local _outfitThumbCache = {}
local function outfitThumbUrl(outfitId)
    local n = tonumber(outfitId)
    if not n then return "" end
    if not _outfitThumbCache[n] then
        _outfitThumbCache[n] = string.format("rbxthumb://type=Outfit&id=%d&w=%d&h=%d",
            n, C.OUTFIT_THUMB_SIZE, C.OUTFIT_THUMB_SIZE)
    end
    return _outfitThumbCache[n]
end

-- ══════════════════════════════════════════════
--  DRAGGABLE (RenderStepped NUR bei aktivem Drag)
-- ══════════════════════════════════════════════
local POSITION_CACHE_DIR  = "TLSteal/TLSTEAL-GUI-CACHE"
local POSITION_CACHE_FILE = POSITION_CACHE_DIR .. "/AvatarOutfitPanelPos.json"
local cachedPanels        = {}

local function saveGuiPositions()
    if not FS.write then return end
    local positions = {}
    for _, frame in ipairs(cachedPanels) do
        positions[frame.Name] = {
            X = { Scale=frame.Position.X.Scale, Offset=frame.Position.X.Offset },
            Y = { Scale=frame.Position.Y.Scale, Offset=frame.Position.Y.Offset },
        }
    end
    local ok, enc = pcall(Services.HttpService.JSONEncode, Services.HttpService, positions)
    if ok and enc then
        ensureFolder("TLSteal"); ensureFolder(POSITION_CACHE_DIR)
        pcall(FS.write, POSITION_CACHE_FILE, enc)
    end
end

local function loadGuiPositions()
    if not FS.read then return end
    pcall(function()
        local raw = FS.read(POSITION_CACHE_FILE)
        if not raw then return end
        local posData = Services.HttpService:JSONDecode(raw)
        if type(posData) ~= "table" then return end
        for _, frame in ipairs(cachedPanels) do
            local s = posData[frame.Name]
            if s and s.X and s.Y then
                frame.Position = UDim2.new(s.X.Scale, s.X.Offset, s.Y.Scale, s.Y.Offset)
            end
        end
    end)
end

local function setupDraggable(frame, handle, smoothness)
    table.insert(cachedPanels, frame)
    local dragging = false
    local dragStart
    local startPos
    local targetPos = frame.Position
    local lastTargetPos = targetPos
    local lerpAlpha = smoothness or 0.25
    local instantMode = lerpAlpha <= 0
    local renderConn

    if handle:IsA("GuiObject") then handle.Active = true end
    if frame:IsA("GuiObject")  then frame.Active  = true end

    local function finishDrag()
        if not dragging then return end
        dragging = false
        frame.Position = targetPos
        if renderConn then renderConn:Disconnect(); renderConn = nil end
        saveGuiPositions()
    end

    bind(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            targetPos = startPos
            lastTargetPos = startPos

            bind(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End
                or input.UserInputState == Enum.UserInputState.Cancel then
                    finishDrag()
                end
            end)

            if not renderConn then
                renderConn = bind(Services.RunService.RenderStepped, function()
                    if targetPos ~= lastTargetPos then
                        if instantMode then
                            frame.Position = targetPos
                        else
                            frame.Position = frame.Position:Lerp(targetPos, lerpAlpha)
                        end
                        lastTargetPos = targetPos
                    end
                end)
            end
        end
    end)

    bind(Services.UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            targetPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    bind(Services.UserInputService.WindowFocusReleased, finishDrag)
end

local Panel, TitleBar, SearchBox, ScrollFrame, LoadingLabel, PlayerCountLabel, R6Btn, SavedOutfitsBtn, RefreshBtn, CloseBtn, updatePlayerCountDisplay = (function()
    local Panel = Instance.new("Frame")
    Panel.Name                   = "Panel"
    Panel.Size                   = UDim2.fromOffset(C.PANEL_W, C.PANEL_H)
    Panel.Position               = UDim2.fromScale(0.5, 0.5)
    Panel.AnchorPoint            = Vector2.new(0.5, 0.5)
    Panel.BackgroundColor3       = C.panelBg
    Panel.BorderSizePixel        = 0
    Panel.ZIndex                 = 11
    Panel.Visible                = false
    Panel.Parent                 = ScreenGui
    corner(Panel, 10)
    local pStroke = _makeDummyStroke(Panel)
    pStroke.Thickness = 1.2; pStroke.Color = C.bg3 or Color3.fromRGB(45,45,45); pStroke.Transparency = 0.2

    local TitleBar = Instance.new("Frame")
    TitleBar.Size             = UDim2.new(1, 0, 0, 44)
    TitleBar.BackgroundColor3 = C.panelHdr
    TitleBar.BorderSizePixel  = 0
    TitleBar.ZIndex           = 12
    TitleBar.Parent           = Panel
    corner(TitleBar, 10)
    local TitleBarSep = Instance.new("Frame", Panel)
    TitleBarSep.Size = UDim2.new(1, 0, 0, 1); TitleBarSep.Position = UDim2.new(0,0,0,44)
    TitleBarSep.BackgroundColor3 = C.bg3 or Color3.fromRGB(45,45,45); TitleBarSep.BorderSizePixel = 0; TitleBarSep.ZIndex = 12
    local _tf = Instance.new("Frame")
    _tf.Size = UDim2.new(1,0,0,10); _tf.Position = UDim2.new(0,0,1,-10)
    _tf.BackgroundColor3 = C.TITLEBAR; _tf.BorderSizePixel = 0; _tf.ZIndex = 12; _tf.Parent = TitleBar

    local TitleBarLine = Instance.new("Frame")
    TitleBarLine.Size = UDim2.new(1,0,0,1); TitleBarLine.Position = UDim2.new(0,0,1,-1)
    TitleBarLine.BackgroundColor3 = C.ACCENT; TitleBarLine.BackgroundTransparency = 0.86
    TitleBarLine.BorderSizePixel = 0; TitleBarLine.ZIndex = 13; TitleBarLine.Parent = TitleBar

    local TitleIcon = Instance.new("TextLabel")
    TitleIcon.Text = "◈"; TitleIcon.Size = UDim2.fromOffset(24,24); TitleIcon.Position = UDim2.fromOffset(14,10)
    TitleIcon.BackgroundTransparency = 1; TitleIcon.TextSize = 16; TitleIcon.TextColor3 = C.ACCENT
    TitleIcon.ZIndex = 13; TitleIcon.Parent = TitleBar; applyTextStyle(TitleIcon)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Text = "TLSTEAL AVATARS"; TitleLabel.Size = UDim2.new(1,-210,1,0)
    TitleLabel.Position = UDim2.fromOffset(38,0); TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextSize = 13; TitleLabel.TextColor3 = C.TEXT1; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 13; TitleLabel.Parent = TitleBar; applyTextStyle(TitleLabel)

    local CountBadge = Instance.new("Frame")
    CountBadge.Size = UDim2.fromOffset(85,18); CountBadge.Position = UDim2.new(1,-205,0.5,0)
    CountBadge.AnchorPoint = Vector2.new(0,0.5); CountBadge.BackgroundColor3 = C.bg3 or Color3.fromRGB(22,22,22)
    CountBadge.BackgroundTransparency = 0.5; CountBadge.BorderSizePixel = 0; CountBadge.ZIndex = 13
    CountBadge.Parent = TitleBar
    corner(CountBadge, 7)
    local cbStroke = _makeDummyStroke(CountBadge)
    cbStroke.Color = C.accent; cbStroke.Thickness = 0.8; cbStroke.Transparency = 0.5

    local CountLabel = Instance.new("TextLabel")
    CountLabel.Size = UDim2.fromScale(1,1); CountLabel.BackgroundTransparency = 1
    CountLabel.TextSize = 10; CountLabel.TextColor3 = Color3.fromRGB(255,255,255)
    CountLabel.ZIndex = 14; CountLabel.Parent = CountBadge; applyTextStyle(CountLabel)

    local _lastCountText = ""
    local function updatePlayerCountDisplay(count)
        local txt = "Players > " .. tostring(count)
        if txt == _lastCountText then return end
        _lastCountText = txt
        CountLabel.Text = txt
        tween(CountBadge, TI._012, { Size=UDim2.fromOffset(math.max(85, #txt * 6 + 12), 18) }):Play()
    end


    local R6Btn = Instance.new("TextButton")
    R6Btn.Name = "R6Btn"; R6Btn.Size = UDim2.fromOffset(36,18); R6Btn.Position = UDim2.new(1,-260,0.5,0)
    R6Btn.AnchorPoint = Vector2.new(0,0.5); R6Btn.BackgroundColor3 = Color3.fromRGB(22,22,22)
    R6Btn.BorderSizePixel = 1; R6Btn.BorderColor3 = C.BORDER; R6Btn.Text = "R6"
    R6Btn.TextSize = 10; R6Btn.TextColor3 = C.TEXT1; R6Btn.AutoButtonColor = false
    R6Btn.ZIndex = 15; R6Btn.Parent = TitleBar; corner(R6Btn, 7); applyTextStyle(R6Btn)

    bind(R6Btn.MouseEnter, function() tween(R6Btn, TI._012, {BackgroundColor3=Color3.fromRGB(28,28,32)}):Play() end)
    bind(R6Btn.MouseLeave, function() tween(R6Btn, TI._012, {BackgroundColor3=Color3.fromRGB(22,22,22)}):Play() end)
    bind(R6Btn.MouseButton1Down, function() tween(getPopScale(R6Btn), TI._008, {Scale=0.92}):Play() end)
    bind(R6Btn.MouseButton1Up, function() tween(getPopScale(R6Btn), TI._016, {Scale=1}):Play() end)
    bind(R6Btn.MouseButton1Click, function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.RigType = (hum.RigType == Enum.HumanoidRigType.R15) and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15 end
    end)

    local SavedOutfitsBtn = Instance.new("ImageButton")
    SavedOutfitsBtn.Size = UDim2.fromOffset(32,32); SavedOutfitsBtn.Position = UDim2.new(1,-110,0.5,0)
    SavedOutfitsBtn.AnchorPoint = Vector2.new(0,0.5); SavedOutfitsBtn.BackgroundTransparency = 1
    SavedOutfitsBtn.Image = "rbxassetid://12975878363"; SavedOutfitsBtn.ImageColor3 = Color3.fromRGB(255,255,255)
    SavedOutfitsBtn.ZIndex = 14; SavedOutfitsBtn.Parent = TitleBar; corner(SavedOutfitsBtn, 9)
    bind(SavedOutfitsBtn.MouseEnter, function() tween(SavedOutfitsBtn, TI._012, {ImageColor3=Color3.fromRGB(200,200,200), Size=UDim2.fromOffset(33,33)}):Play() end)
    bind(SavedOutfitsBtn.MouseLeave, function() tween(SavedOutfitsBtn, TI._012, {ImageColor3=Color3.fromRGB(255,255,255), Size=UDim2.fromOffset(32,32)}):Play() end)
    bind(SavedOutfitsBtn.MouseButton1Down, function() tween(getPopScale(SavedOutfitsBtn), TI._008, {Scale=0.88}):Play() end)
    bind(SavedOutfitsBtn.MouseButton1Up, function() tween(getPopScale(SavedOutfitsBtn), TI._016, {Scale=1}):Play() end)

    local RefreshBtn = Instance.new("ImageButton")
    RefreshBtn.Size = UDim2.fromOffset(30,30); RefreshBtn.Position = UDim2.new(1,-74,0.5,0)
    RefreshBtn.AnchorPoint = Vector2.new(0,0.5); RefreshBtn.BackgroundTransparency = 1
    RefreshBtn.Image = "rbxassetid://137689074320233"; RefreshBtn.ImageColor3 = Color3.fromRGB(255,255,255)
    RefreshBtn.Parent = TitleBar; corner(RefreshBtn, 9)
    bind(RefreshBtn.MouseEnter, function() tween(RefreshBtn, TI._012, {ImageColor3=Color3.fromRGB(200,200,200), Size=UDim2.fromOffset(31,31)}):Play() end)
    bind(RefreshBtn.MouseLeave, function() tween(RefreshBtn, TI._012, {ImageColor3=Color3.fromRGB(255,255,255), Size=UDim2.fromOffset(30,30)}):Play() end)
    bind(RefreshBtn.MouseButton1Down, function() tween(getPopScale(RefreshBtn), TI._008, {Scale=0.88}):Play() end)
    bind(RefreshBtn.MouseButton1Up, function() tween(getPopScale(RefreshBtn), TI._016, {Scale=1}):Play() end)

    local CloseBtn = makeCloseBtn(TitleBar, 30, 1, -38, 0.5, 0); CloseBtn.ZIndex = 14

    local SearchPill = Instance.new("Frame")
    SearchPill.Size = UDim2.new(1,-16,0,32); SearchPill.Position = UDim2.fromOffset(8,54)
    SearchPill.BackgroundColor3 = Color3.fromRGB(15,15,15); SearchPill.BorderSizePixel = 0
    SearchPill.ZIndex = 12; SearchPill.Parent = Panel; corner(SearchPill, 10)
    local spS = _makeDummyStroke(SearchPill)
    spS.Thickness = 1; spS.Color = C.bg3 or Color3.fromRGB(45,45,45); spS.Transparency = 0.5

    local SearchIcon = Instance.new("TextLabel")
    SearchIcon.Text = "🔍"; SearchIcon.Size = UDim2.fromOffset(32,32); SearchIcon.Position = UDim2.fromOffset(6,0)
    SearchIcon.BackgroundTransparency = 1; SearchIcon.TextSize = 14; SearchIcon.TextColor3 = C.TEXT2
    SearchIcon.ZIndex = 13; SearchIcon.Parent = SearchPill; applyTextStyle(SearchIcon)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Name = "PlayerSearchBox"; SearchBox.PlaceholderText = "Player suchen..."
    SearchBox.Text = ""; SearchBox.ClearTextOnFocus = false; SearchBox.Size = UDim2.new(1,-50,1,0)
    SearchBox.Position = UDim2.fromOffset(40,0); SearchBox.BackgroundTransparency = 1
    SearchBox.TextSize = 12; SearchBox.TextColor3 = C.TEXT1; SearchBox.PlaceholderColor3 = C.TEXT2
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left; SearchBox.TextYAlignment = Enum.TextYAlignment.Center
    SearchBox.ZIndex = 13; SearchBox.Parent = SearchPill; applyTextStyle(SearchBox)

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1,-16,1,-100); ScrollFrame.Position = UDim2.fromOffset(8,96)
    ScrollFrame.BackgroundTransparency = 1; ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 3; ScrollFrame.ScrollBarImageColor3 = C.accent or Color3.fromRGB(104,104,112)
    ScrollFrame.ZIndex = 12; ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.CanvasSize = UDim2.fromOffset(0,0); ScrollFrame.Parent = Panel

    local GridLayout = Instance.new("UIGridLayout")
    GridLayout.CellSize = UDim2.fromOffset(C.CARD_W, C.CARD_H); GridLayout.CellPadding = UDim2.fromOffset(C.GAP, C.GAP)
    GridLayout.SortOrder = Enum.SortOrder.Name; GridLayout.Parent = ScrollFrame

    local LoadingLabel = Instance.new("TextLabel")
    LoadingLabel.Text = "⌛  Lade Spieler..."; LoadingLabel.Size = UDim2.fromScale(1,1)
    LoadingLabel.BackgroundTransparency = 1; LoadingLabel.TextSize = 14; LoadingLabel.TextColor3 = C.TEXT1
    LoadingLabel.ZIndex = 13; LoadingLabel.Visible = false; LoadingLabel.Parent = ScrollFrame
    applyTextStyle(LoadingLabel)

    local PlayerCountLabel = Instance.new("TextLabel")
    PlayerCountLabel.Text = "0 Spieler"; PlayerCountLabel.Size = UDim2.fromOffset(100,20)
    PlayerCountLabel.Position = UDim2.new(1,-108,0,54+36); PlayerCountLabel.BackgroundTransparency = 1
    PlayerCountLabel.TextSize = 10; PlayerCountLabel.TextColor3 = C.TEXT2; PlayerCountLabel.TextXAlignment = Enum.TextXAlignment.Right
    PlayerCountLabel.ZIndex = 13; PlayerCountLabel.Parent = Panel; applyTextStyle(PlayerCountLabel)

    setupDraggable(Panel, TitleBar, 0)
    return Panel, TitleBar, SearchBox, ScrollFrame, LoadingLabel, PlayerCountLabel, R6Btn, SavedOutfitsBtn, RefreshBtn, CloseBtn, updatePlayerCountDisplay
end)()




-- ══════════════════════════════════════════════
--  OUTFIT-SUBPANEL
-- ══════════════════════════════════════════════
local SubPanel, SubTitleBar, SubTitleName, SubTitleSub, SubAvatarThumb, SubCloseBtn, SubBackBtn, SubRefreshBtn, SubPageContainer, SubPagePrev, SubPageNext, SubPageLabel, OutfitScroll, OutfitLoading, OutfitEmpty, OutfitReloadBtn, OutfitReloadLabel = (function()
    local SubPanel = Instance.new("Frame")
    SubPanel.Name = "SubPanel"; SubPanel.Size = UDim2.fromOffset(C.SUB_W, C.SUB_H)
    SubPanel.Position = UDim2.fromScale(0.5,0.5); SubPanel.AnchorPoint = Vector2.new(0.5,0.5)
    SubPanel.BackgroundColor3 = C.panelBg; SubPanel.BorderSizePixel = 0; SubPanel.ZIndex = 20
    SubPanel.Visible = false; SubPanel.Parent = ScreenGui
    corner(SubPanel, 14)
    local spStroke = _makeDummyStroke(SubPanel)
    spStroke.Thickness = 1.2; spStroke.Color = C.bg3 or Color3.fromRGB(45,45,45); spStroke.Transparency = 0.2
    if stylePanelSurface then stylePanelSurface(SubPanel) end

    local SubTitleBar = Instance.new("Frame")
    SubTitleBar.Size = UDim2.new(1,0,0,50); SubTitleBar.BackgroundColor3 = C.panelHdr
    SubTitleBar.BorderSizePixel = 0; SubTitleBar.ZIndex = 21; SubTitleBar.Parent = SubPanel
    corner(SubTitleBar, 14)
    local SubTitleSep = Instance.new("Frame", SubPanel)
    SubTitleSep.Size = UDim2.new(1, 0, 0, 1); SubTitleSep.Position = UDim2.new(0,0,0,50)
    SubTitleSep.BackgroundColor3 = C.bg3 or Color3.fromRGB(45,45,45); SubTitleSep.BorderSizePixel = 0; SubTitleSep.ZIndex = 21
    local _stf = Instance.new("Frame")
    _stf.Size = UDim2.new(1,0,0,10); _stf.Position = UDim2.new(0,0,1,-10)
    _stf.BackgroundColor3 = C.TITLEBAR; _stf.BorderSizePixel = 0; _stf.ZIndex = 21; _stf.Parent = SubTitleBar

    local SubTitleBarLine = Instance.new("Frame")
    SubTitleBarLine.Size = UDim2.new(1,0,0,1); SubTitleBarLine.Position = UDim2.new(0,0,1,-1)
    SubTitleBarLine.BackgroundColor3 = C.BORDER; SubTitleBarLine.BackgroundTransparency = 0.35
    SubTitleBarLine.BorderSizePixel = 0; SubTitleBarLine.ZIndex = 22; SubTitleBarLine.Parent = SubTitleBar

    local SubAvatarThumb = Instance.new("ImageLabel")
    SubAvatarThumb.Size = UDim2.fromOffset(34,34); SubAvatarThumb.Position = UDim2.fromOffset(10,8)
    SubAvatarThumb.BackgroundColor3 = Color3.fromRGB(18,18,18); SubAvatarThumb.BorderSizePixel = 0
    SubAvatarThumb.ZIndex = 22; SubAvatarThumb.ScaleType = Enum.ScaleType.Fit
    SubAvatarThumb.Parent = SubTitleBar; styleThumbSurface(SubAvatarThumb, 10)

    local SubTitleName = Instance.new("TextLabel")
    SubTitleName.Text = "Outfits"; SubTitleName.Size = UDim2.new(1,-160,0,22)
    SubTitleName.Position = UDim2.fromOffset(52,6); SubTitleName.BackgroundTransparency = 1
    SubTitleName.TextSize = 13; SubTitleName.TextColor3 = C.TEXT1
    SubTitleName.TextXAlignment = Enum.TextXAlignment.Left; SubTitleName.ZIndex = 22
    SubTitleName.Parent = SubTitleBar; applyTextStyle(SubTitleName)

    local SubTitleSub = Instance.new("TextLabel")
    SubTitleSub.Text = "Gespeicherte Outfits"; SubTitleSub.Size = UDim2.new(1,-160,0,16)
    SubTitleSub.Position = UDim2.fromOffset(52,28); SubTitleSub.BackgroundTransparency = 1
    SubTitleSub.TextSize = 10; SubTitleSub.TextColor3 = C.TEXT2
    SubTitleSub.TextXAlignment = Enum.TextXAlignment.Left; SubTitleSub.ZIndex = 22
    SubTitleSub.Parent = SubTitleBar; applyTextStyle(SubTitleSub)

    local SubCloseBtn = makeCloseBtn(SubTitleBar, 30, 1, -38, 0.5, 0); SubCloseBtn.ZIndex = 23

    local SubBackBtn = Instance.new("TextButton")
    SubBackBtn.Text = "← Zurück"; SubBackBtn.Size = UDim2.fromOffset(80,26)
    SubBackBtn.Position = UDim2.new(1,-122,0.5,0); SubBackBtn.AnchorPoint = Vector2.new(0,0.5)
    SubBackBtn.BackgroundColor3 = C.bg3 or Color3.fromRGB(22,22,22); SubBackBtn.BorderSizePixel = 0
    SubBackBtn.TextSize = 11; SubBackBtn.TextColor3 = C.TEXT2; SubBackBtn.ZIndex = 22
    SubBackBtn.Parent = SubTitleBar
    corner(SubBackBtn, 9)
    local sbStroke = _makeDummyStroke(SubBackBtn)
    sbStroke.Color = C.accent; sbStroke.Thickness = 1; sbStroke.Transparency = 0.6
    applyTextStyle(SubBackBtn)
    bind(SubBackBtn.MouseEnter, function() tween(SubBackBtn, TI._012, {BackgroundColor3=Color3.fromRGB(28,28,32)}):Play() end)
    bind(SubBackBtn.MouseLeave, function() tween(SubBackBtn, TI._012, {BackgroundColor3=Color3.fromRGB(22,22,22)}):Play() end)
    bind(SubBackBtn.MouseButton1Down, function() tween(getPopScale(SubBackBtn), TI._008, {Scale=0.95}):Play() end)
    bind(SubBackBtn.MouseButton1Up, function() tween(getPopScale(SubBackBtn), TI._016, {Scale=1}):Play() end)

    local SubRefreshBtn = Instance.new("ImageButton")
    SubRefreshBtn.Name = "SubRefreshBtn"; SubRefreshBtn.Size = UDim2.fromOffset(26,26)
    SubRefreshBtn.Position = UDim2.new(1,-154,0.5,0); SubRefreshBtn.AnchorPoint = Vector2.new(0,0.5)
    SubRefreshBtn.BackgroundTransparency = 1; SubRefreshBtn.BorderSizePixel = 0
    SubRefreshBtn.Image = "rbxassetid://137689074320233"; SubRefreshBtn.ImageColor3 = Color3.fromRGB(255,255,255)
    SubRefreshBtn.ZIndex = 22; SubRefreshBtn.Parent = SubTitleBar
    corner(SubRefreshBtn, 8)
    bind(SubRefreshBtn.MouseEnter, function() tween(SubRefreshBtn, TI._012, {ImageColor3=Color3.fromRGB(200,200,200), BackgroundTransparency=0.9, BackgroundColor3=Color3.fromRGB(255,255,255)}):Play() end)
    bind(SubRefreshBtn.MouseLeave, function() tween(SubRefreshBtn, TI._012, {ImageColor3=Color3.fromRGB(255,255,255), BackgroundTransparency=1}):Play() end)
    bind(SubRefreshBtn.MouseButton1Down, function() tween(getPopScale(SubRefreshBtn), TI._008, {Scale=0.88}):Play() end)
    bind(SubRefreshBtn.MouseButton1Up, function() tween(getPopScale(SubRefreshBtn), TI._016, {Scale=1}):Play() end)

    local SubPageContainer = Instance.new("Frame")
    SubPageContainer.Size = UDim2.fromOffset(100, 26); SubPageContainer.Position = UDim2.new(1,-262,0.5,0)
    SubPageContainer.AnchorPoint = Vector2.new(0, 0.5); SubPageContainer.BackgroundTransparency = 1
    SubPageContainer.ZIndex = 22; SubPageContainer.Parent = SubTitleBar; SubPageContainer.Visible = false

    local SubPagePrev = Instance.new("TextButton")
    SubPagePrev.Text = "◀"; SubPagePrev.Size = UDim2.fromOffset(26,26); SubPagePrev.Position = UDim2.new(0,0,0,0)
    SubPagePrev.BackgroundColor3 = C.bg3 or Color3.fromRGB(22,22,22); SubPagePrev.BorderSizePixel = 0
    SubPagePrev.TextSize = 10; SubPagePrev.TextColor3 = C.TEXT2; SubPagePrev.ZIndex = 22; SubPagePrev.Parent = SubPageContainer
    corner(SubPagePrev, 8); local spStroke1 = _makeDummyStroke(SubPagePrev); spStroke1.Color = C.bg3 or Color3.fromRGB(45,45,45)

    local SubPageNext = Instance.new("TextButton")
    SubPageNext.Text = "▶"; SubPageNext.Size = UDim2.fromOffset(26,26); SubPageNext.Position = UDim2.new(1,-26,0,0)
    SubPageNext.BackgroundColor3 = C.bg3 or Color3.fromRGB(22,22,22); SubPageNext.BorderSizePixel = 0
    SubPageNext.TextSize = 10; SubPageNext.TextColor3 = C.TEXT2; SubPageNext.ZIndex = 22; SubPageNext.Parent = SubPageContainer
    corner(SubPageNext, 8); local spStroke2 = _makeDummyStroke(SubPageNext); spStroke2.Color = C.bg3 or Color3.fromRGB(45,45,45)

    local SubPageLabel = Instance.new("TextLabel")
    SubPageLabel.Text = "1/1"; SubPageLabel.Size = UDim2.new(1,-52,1,0); SubPageLabel.Position = UDim2.fromOffset(26,0)
    SubPageLabel.BackgroundTransparency = 1; SubPageLabel.TextSize = 10; SubPageLabel.TextColor3 = C.TEXT1
    SubPageLabel.ZIndex = 22; SubPageLabel.Parent = SubPageContainer; applyTextStyle(SubPageLabel)


    local function applyPageBtnHover(btn)
        bind(btn.MouseEnter, function() tween(btn, TI._012, {BackgroundColor3=Color3.fromRGB(28,28,32)}):Play(); tween(btn:FindFirstChildOfClass("UIStroke"), TI._012, {Color=C.accent or Color3.fromRGB(255,255,255)}):Play() end)
        bind(btn.MouseLeave, function() tween(btn, TI._012, {BackgroundColor3=C.bg3 or Color3.fromRGB(22,22,22)}):Play(); tween(btn:FindFirstChildOfClass("UIStroke"), TI._012, {Color=C.bg3 or Color3.fromRGB(45,45,45)}):Play() end)
        bind(btn.MouseButton1Down, function() tween(getPopScale(btn), TI._008, {Scale=0.88}):Play() end)
        bind(btn.MouseButton1Up, function() tween(getPopScale(btn), TI._016, {Scale=1}):Play() end)
    end
    applyPageBtnHover(SubPagePrev); applyPageBtnHover(SubPageNext)

    local SubDivider = Instance.new("Frame")
    SubDivider.Size = UDim2.new(1,-28,0,1); SubDivider.Position = UDim2.fromOffset(12,54)
    SubDivider.BackgroundColor3 = C.BORDER; SubDivider.BackgroundTransparency = 0.42
    SubDivider.BorderSizePixel = 0; SubDivider.ZIndex = 21; SubDivider.Parent = SubPanel

    local OutfitScroll = Instance.new("ScrollingFrame")
    OutfitScroll.Size = UDim2.new(1,-16,1,-62); OutfitScroll.Position = UDim2.fromOffset(8,58)
    OutfitScroll.BackgroundTransparency = 1; OutfitScroll.BorderSizePixel = 0
    OutfitScroll.ScrollBarThickness = 4; OutfitScroll.ScrollBarImageColor3 = Color3.fromRGB(104,104,112)
    OutfitScroll.ZIndex = 21; OutfitScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    OutfitScroll.CanvasSize = UDim2.fromOffset(0,0); OutfitScroll.Parent = SubPanel

    local OutfitGrid = Instance.new("UIGridLayout")
    OutfitGrid.CellSize = UDim2.fromOffset(C.SUB_OUT_W, C.OUT_H); OutfitGrid.CellPadding = UDim2.fromOffset(8,8)
    OutfitGrid.SortOrder = Enum.SortOrder.Name; OutfitGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    OutfitGrid.Parent = OutfitScroll

    local OutfitGridPad = Instance.new("UIPadding")
    OutfitGridPad.PaddingLeft = UDim.new(0,6); OutfitGridPad.PaddingTop = UDim.new(0,6)
    OutfitGridPad.PaddingRight = UDim.new(0,0); OutfitGridPad.Parent = OutfitScroll

    local OutfitLoading = Instance.new("TextLabel")
    OutfitLoading.Text = "⏳  Lade Outfits..."; OutfitLoading.Size = UDim2.fromScale(1,1)
    OutfitLoading.BackgroundTransparency = 1; OutfitLoading.TextSize = 14; OutfitLoading.TextColor3 = C.TEXT1
    OutfitLoading.ZIndex = 22; OutfitLoading.Visible = false; OutfitLoading.Parent = OutfitScroll
    applyTextStyle(OutfitLoading)

    local OutfitEmpty = Instance.new("TextLabel")
    OutfitEmpty.Text = "—  Keine Outfits gespeichert"; OutfitEmpty.Size = UDim2.new(1,-40,0,40)
    OutfitEmpty.Position = UDim2.new(0.5,0,0.5,18); OutfitEmpty.AnchorPoint = Vector2.new(0.5,0.5)
    OutfitEmpty.BackgroundTransparency = 1; OutfitEmpty.TextSize = 14; OutfitEmpty.TextColor3 = C.TEXT1
    OutfitEmpty.TextXAlignment = Enum.TextXAlignment.Center; OutfitEmpty.ZIndex = 22
    OutfitEmpty.Visible = false; OutfitEmpty.Parent = SubPanel; applyTextStyle(OutfitEmpty)

    local OutfitReloadBtn = Instance.new("ImageButton")
    OutfitReloadBtn.Name = "OutfitReloadBtn"; OutfitReloadBtn.Size = UDim2.fromOffset(34,34)
    OutfitReloadBtn.Position = UDim2.new(0.5,0,0.5,48); OutfitReloadBtn.AnchorPoint = Vector2.new(0.5,0.5)
    OutfitReloadBtn.BackgroundTransparency = 1; OutfitReloadBtn.BorderSizePixel = 0
    OutfitReloadBtn.Image = "rbxassetid://137689074320233"; OutfitReloadBtn.ImageColor3 = Color3.fromRGB(255,255,255)
    OutfitReloadBtn.ZIndex = 22; OutfitReloadBtn.Visible = false; OutfitReloadBtn.Parent = SubPanel
    corner(OutfitReloadBtn, 10)

    local OutfitReloadLabel = Instance.new("TextLabel")
    OutfitReloadLabel.Text = "Reload Outfits"; OutfitReloadLabel.Size = UDim2.new(1,-40,0,18)
    OutfitReloadLabel.Position = UDim2.new(0.5,0,0.5,76); OutfitReloadLabel.AnchorPoint = Vector2.new(0.5,0.5)
    OutfitReloadLabel.BackgroundTransparency = 1; OutfitReloadLabel.TextSize = 12; OutfitReloadLabel.TextColor3 = C.ACCENT
    OutfitReloadLabel.TextXAlignment = Enum.TextXAlignment.Center; OutfitReloadLabel.ZIndex = 22
    OutfitReloadLabel.Visible = false; OutfitReloadLabel.Parent = SubPanel; applyTextStyle(OutfitReloadLabel)

    bind(OutfitReloadBtn.MouseEnter, function() tween(OutfitReloadBtn, TI._012, {BackgroundColor3=Color3.fromRGB(34,34,38), Size=UDim2.fromOffset(35,35)}):Play() end)
    bind(OutfitReloadBtn.MouseLeave, function() tween(OutfitReloadBtn, TI._012, {BackgroundColor3=Color3.fromRGB(22,22,22), Size=UDim2.fromOffset(34,34)}):Play() end)
    bind(OutfitReloadBtn.MouseButton1Down, function() tween(getPopScale(OutfitReloadBtn), TI._008, {Scale=0.88}):Play() end)
    bind(OutfitReloadBtn.MouseButton1Up, function() tween(getPopScale(OutfitReloadBtn), TI._016, {Scale=1}):Play() end)

    setupDraggable(SubPanel, SubTitleBar, 0)
    return SubPanel, SubTitleBar, SubTitleName, SubTitleSub, SubAvatarThumb, SubCloseBtn, SubBackBtn, SubRefreshBtn, SubPageContainer, SubPagePrev, SubPageNext, SubPageLabel, OutfitScroll, OutfitLoading, OutfitEmpty, OutfitReloadBtn, OutfitReloadLabel
end)()

local SavedPanel, SavedTitleBar, SavedTitleName, SavedTitleSub, SavedCloseBtn, SavedScroll, SavedEmpty = (function()
    local SavedPanel = Instance.new("Frame")
    SavedPanel.Name = "SavedPanel"; SavedPanel.Size = UDim2.fromOffset(C.SUB_W, C.SUB_H)
    SavedPanel.Position = UDim2.fromScale(0.5,0.5); SavedPanel.AnchorPoint = Vector2.new(0.5,0.5)
    SavedPanel.BackgroundColor3 = C.panelBg; SavedPanel.BorderSizePixel = 0; SavedPanel.ZIndex = 25
    SavedPanel.Visible = false; SavedPanel.Parent = ScreenGui
    corner(SavedPanel, 14)
    local savStroke = _makeDummyStroke(SavedPanel)
    savStroke.Thickness = 1.2; savStroke.Color = C.bg3 or Color3.fromRGB(45,45,45); savStroke.Transparency = 0.2
    if stylePanelSurface then stylePanelSurface(SavedPanel) end

    local SavedTitleBar = Instance.new("Frame")
    SavedTitleBar.Size = UDim2.new(1,0,0,50); SavedTitleBar.BackgroundColor3 = C.panelHdr
    SavedTitleBar.BorderSizePixel = 0; SavedTitleBar.ZIndex = 26; SavedTitleBar.Parent = SavedPanel
    corner(SavedTitleBar, 14)
    local SavedTitleSep = Instance.new("Frame", SavedPanel)
    SavedTitleSep.Size = UDim2.new(1, 0, 0, 1); SavedTitleSep.Position = UDim2.new(0,0,0,50)
    SavedTitleSep.BackgroundColor3 = C.bg3 or Color3.fromRGB(45,45,45); SavedTitleSep.BorderSizePixel = 0; SavedTitleSep.ZIndex = 26

    local _s_tf = Instance.new("Frame")
    _s_tf.Size = UDim2.new(1,0,0,10); _s_tf.Position = UDim2.new(0,0,1,-10)
    _s_tf.BackgroundColor3 = C.TITLEBAR; _s_tf.BorderSizePixel = 0; _s_tf.ZIndex = 26; _s_tf.Parent = SavedTitleBar

    local SavedTitleBarLine = Instance.new("Frame")
    SavedTitleBarLine.Size = UDim2.new(1,0,0,1); SavedTitleBarLine.Position = UDim2.new(0,0,1,-1)
    SavedTitleBarLine.BackgroundColor3 = C.BORDER; SavedTitleBarLine.BackgroundTransparency = 0.35
    SavedTitleBarLine.BorderSizePixel = 0; SavedTitleBarLine.ZIndex = 27; SavedTitleBarLine.Parent = SavedTitleBar

    local SavedIcon = Instance.new("TextLabel")
    SavedIcon.Text = "★"; SavedIcon.Size = UDim2.fromOffset(24,24); SavedIcon.Position = UDim2.fromOffset(14,13)
    SavedIcon.BackgroundTransparency = 1; SavedIcon.TextSize = 16; SavedIcon.TextColor3 = C.ACCENT
    SavedIcon.ZIndex = 27; SavedIcon.Parent = SavedTitleBar; applyTextStyle(SavedIcon)

    local SavedTitleName = Instance.new("TextLabel")
    SavedTitleName.Text = "Saved Outfits"; SavedTitleName.Size = UDim2.new(1,-80,0,22)
    SavedTitleName.Position = UDim2.fromOffset(42,5); SavedTitleName.BackgroundTransparency = 1
    SavedTitleName.TextSize = 13; SavedTitleName.TextColor3 = C.TEXT1
    SavedTitleName.TextXAlignment = Enum.TextXAlignment.Left; SavedTitleName.ZIndex = 27
    SavedTitleName.Parent = SavedTitleBar; applyTextStyle(SavedTitleName)

    local SavedTitleSub = Instance.new("TextLabel")
    SavedTitleSub.Text = "Gespeicherte Outfits"; SavedTitleSub.Size = UDim2.new(1,-80,0,16)
    SavedTitleSub.Position = UDim2.fromOffset(42,25); SavedTitleSub.BackgroundTransparency = 1
    SavedTitleSub.TextSize = 10; SavedTitleSub.TextColor3 = C.TEXT2
    SavedTitleSub.TextXAlignment = Enum.TextXAlignment.Left; SavedTitleSub.ZIndex = 27
    SavedTitleSub.Parent = SavedTitleBar; applyTextStyle(SavedTitleSub)

    local SavedCloseBtn = makeCloseBtn(SavedTitleBar, 30, 1, -38, 0.5, 0); SavedCloseBtn.ZIndex = 28

    local SavedDivider = Instance.new("Frame")
    SavedDivider.Size = UDim2.new(1,-28,0,1); SavedDivider.Position = UDim2.fromOffset(12,54)
    SavedDivider.BackgroundColor3 = C.BORDER; SavedDivider.BackgroundTransparency = 0.42
    SavedDivider.BorderSizePixel = 0; SavedDivider.ZIndex = 26; SavedDivider.Parent = SavedPanel

    local SavedScroll = Instance.new("ScrollingFrame")
    SavedScroll.Size = UDim2.new(1,-16,1,-62); SavedScroll.Position = UDim2.fromOffset(8,58)
    SavedScroll.BackgroundTransparency = 1; SavedScroll.BorderSizePixel = 0
    SavedScroll.ScrollBarThickness = 4; SavedScroll.ScrollBarImageColor3 = Color3.fromRGB(104,104,112)
    SavedScroll.ZIndex = 26; SavedScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SavedScroll.CanvasSize = UDim2.fromOffset(0,0); SavedScroll.Parent = SavedPanel

    local SavedGrid = Instance.new("UIGridLayout")
    SavedGrid.CellSize = UDim2.fromOffset(C.OUT_W, C.OUT_H); SavedGrid.CellPadding = UDim2.fromOffset(8,8)
    SavedGrid.SortOrder = Enum.SortOrder.LayoutOrder; SavedGrid.Parent = SavedScroll

    local SavedGridPad = Instance.new("UIPadding")
    SavedGridPad.PaddingLeft = UDim.new(0,6); SavedGridPad.PaddingTop = UDim.new(0,6)
    SavedGridPad.PaddingRight = UDim.new(0,0); SavedGridPad.Parent = SavedScroll

    local SavedEmpty = Instance.new("TextLabel")
    SavedEmpty.Text = "—  Keine gespeicherten Outfits"; SavedEmpty.Size = UDim2.new(1,-40,0,40)
    SavedEmpty.Position = UDim2.new(0.5,0,0.5,18); SavedEmpty.AnchorPoint = Vector2.new(0.5,0.5)
    SavedEmpty.BackgroundTransparency = 1; SavedEmpty.TextSize = 14; SavedEmpty.TextColor3 = C.TEXT1
    SavedEmpty.TextXAlignment = Enum.TextXAlignment.Center; SavedEmpty.ZIndex = 27
    SavedEmpty.Visible = false; SavedEmpty.Parent = SavedPanel; applyTextStyle(SavedEmpty)

    setupDraggable(SavedPanel, SavedTitleBar, 0)
    return SavedPanel, SavedTitleBar, SavedTitleName, SavedTitleSub, SavedCloseBtn, SavedScroll, SavedEmpty
end)()

setupDraggable(Panel, TitleBar, 0)


-- ══════════════════════════════════════════════
--  SKELETON / SHIMMER
-- ══════════════════════════════════════════════
local activeShimmerTweens = {}

local function clearShimmerConns()
    for _, tw in ipairs(activeShimmerTweens) do pcall(function() tw:Cancel() end) end
    activeShimmerTweens = {}
end

local function clearParentFrames(parent)
    for _, ch in ipairs(parent:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
end

local function createSkeletonCard(parent, w, h)
    local card = Instance.new("Frame")
    card.Name = "SkeletonCard"; card.Size = UDim2.fromOffset(w, h)
    card.BackgroundColor3 = C.CARD; card.BorderSizePixel = 0; card.ZIndex = 22; card.Parent = parent
    corner(card, 10)
    local cs = _makeDummyStroke(card)
    cs.Thickness = 1; cs.Color = C.bg3 or Color3.fromRGB(45,45,45); cs.Transparency = 0.5


    local imgPh = Instance.new("Frame")
    imgPh.Size = UDim2.new(1,-12,0,h-42); imgPh.Position = UDim2.fromOffset(6,6)
    imgPh.BackgroundColor3 = Color3.fromRGB(28,28,28); imgPh.BorderSizePixel = 0
    imgPh.ZIndex = 23; imgPh.Parent = card; styleThumbSurface(imgPh, 8)

    local namePh = Instance.new("Frame")
    namePh.Size = UDim2.new(0.7,0,0,7); namePh.Position = UDim2.fromOffset(6,h-32)
    namePh.BackgroundColor3 = Color3.fromRGB(38,38,42); namePh.BorderSizePixel = 0
    namePh.ZIndex = 23; namePh.Parent = card; corner(namePh, 4)

    local subPh = Instance.new("Frame")
    subPh.Size = UDim2.new(0.45,0,0,5); subPh.Position = UDim2.fromOffset(6,h-18)
    subPh.BackgroundColor3 = Color3.fromRGB(30,30,34); subPh.BorderSizePixel = 0
    subPh.ZIndex = 23; subPh.Parent = card; corner(subPh, 4)

    -- Disabled shimmer tween for performance - infinite loops cause FPS drops
    -- local shimmer = tween(imgPh, TI._090_SHIMMER, { BackgroundColor3=Color3.fromRGB(52,52,58) })
    -- shimmer:Play()
    -- table.insert(activeShimmerTweens, shimmer)
    return card
end

local function showSkeletons(parent, count, w, h)
    for _ = 1, count do createSkeletonCard(parent, w, h) end
end

local function estimateVisibleCardCount(scrollFrame, cellW, cellH, gap, extraRows)
    local aw = math.max(1, scrollFrame.AbsoluteSize.X)
    local ah = math.max(1, scrollFrame.AbsoluteSize.Y)
    local cols = math.max(1, math.floor((aw + gap) / (cellW + gap)))
    local rows = math.max(1, math.ceil((ah + gap) / (cellH + gap)) + (extraRows or 1))
    return cols * rows
end

-- ══════════════════════════════════════════════
--  TRANSPARENCY SNAPSHOT (fade-in/out für Spielerkarten)
-- ══════════════════════════════════════════════
local function buildTransparencySnapshot(root)
    local snap = {}
    local function capture(inst)
        if inst:IsA("GuiObject") then
            table.insert(snap, {
                inst  = inst,
                bg    = inst.BackgroundTransparency,
                text  = (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.TextTransparency or nil,
                image = (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.ImageTransparency or nil,
            })
        elseif inst:IsA("UIStroke") then
            table.insert(snap, { inst=inst, stroke=inst.Transparency })
        end
    end
    capture(root)
    for _, inst in ipairs(root:GetDescendants()) do capture(inst) end
    return snap
end

-- Schreibt nur wenn sich Wert tatsächlich ändert (spart Property-Sets)
local function applyTransparencySnapshot(snapshot, alpha)
    for _, e in ipairs(snapshot) do
        local inst = e.inst
        if inst and inst.Parent then
            if e.bg ~= nil then
                local v = e.bg + (1 - e.bg) * alpha
                if math.abs(inst.BackgroundTransparency - v) > 0.001 then
                    inst.BackgroundTransparency = v
                end
            end
            if e.text ~= nil then
                local v = e.text + (1 - e.text) * alpha
                if math.abs(inst.TextTransparency - v) > 0.001 then inst.TextTransparency = v end
            end
            if e.image ~= nil then
                local v = e.image + (1 - e.image) * alpha
                if math.abs(inst.ImageTransparency - v) > 0.001 then inst.ImageTransparency = v end
            end
            if e.stroke ~= nil then
                local v = e.stroke + (1 - e.stroke) * alpha
                if math.abs(inst.Transparency - v) > 0.001 then inst.Transparency = v end
            end
        end
    end
end

local playerCardsByUserId = {}
local playerCardSnapshots = setmetatable({}, { __mode = "k" })

local function tweenPlayerCardVisibility(card, targetAlpha, duration, onComplete)
    local snap = playerCardSnapshots[card]
    if not card or not card.Parent or not snap then if onComplete then onComplete() end; return end
    local driver = registerInstance(Instance.new("NumberValue"))
    driver.Value = card:GetAttribute("FadeAlpha") or 0
    local conn
    conn = bind(driver:GetPropertyChangedSignal("Value"), function()
        applyTransparencySnapshot(snap, driver.Value)
        card:SetAttribute("FadeAlpha", driver.Value)
    end)
    local tw = tween(driver, getTI(duration or 0.16), { Value=targetAlpha })
    bind(tw.Completed, function()
        if conn then conn:Disconnect(); conn = nil end
        driver:Destroy()
        if onComplete then onComplete() end
    end)
    tw:Play()
end

local function clearPlayerCardRegistry()
    table.clear(playerCardsByUserId)
    playerCardSnapshots = setmetatable({}, { __mode = "k" })
end

-- ══════════════════════════════════════════════
--  RENDER TOKENS
-- ══════════════════════════════════════════════
local activeThumbRenderToken = 0
local activePlayerListToken  = 0
local preloadedThumbUrls     = {}

local function nextThumbRenderToken()   activeThumbRenderToken += 1; return activeThumbRenderToken end
local function invalidateThumbRenderToken() activeThumbRenderToken += 1 end
local function nextPlayerListToken()    activePlayerListToken  += 1; return activePlayerListToken end

-- ══════════════════════════════════════════════
--  THUMBNAIL PRELOAD (Batch)
-- ══════════════════════════════════════════════
local function preloadOutfitThumbs(outfits, limit)
    local preloaders = {}
    local maxCount = math.min(#outfits, limit or C.THUMB_PRIORITY_COUNT)
    for i = 1, maxCount do
        local o = outfits[i]
        if o and o.id then
            local url = outfitThumbUrl(o.id)
            if url ~= "" and not preloadedThumbUrls[url] then
                preloadedThumbUrls[url] = true
                local pl = Instance.new("ImageLabel"); pl.Image = url
                table.insert(preloaders, pl)
            end
        end
    end
    if #preloaders == 0 then return end
    task.spawn(function()
        pcall(Services.ContentProvider.PreloadAsync, Services.ContentProvider, preloaders)
        for _, pl in ipairs(preloaders) do pl:Destroy() end
    end)
end

-- ══════════════════════════════════════════════
--  ATTACH OUTFIT THUMBNAIL
-- ══════════════════════════════════════════════
local function attachOutfitThumbnail(thumb, outfitId, renderToken, loadDelay)
    thumb.ImageTransparency = 1
    local function applyThumb()
        if renderToken and activeThumbRenderToken ~= renderToken then return end
        if not thumb or not thumb.Parent then return end
        local url = outfitThumbUrl(outfitId)
        if url == "" then return end
        thumb.Image = url; thumb.Visible = true; thumb.ImageTransparency = 0
    end
    if loadDelay and loadDelay > 0 then task.delay(loadDelay, applyThumb) else applyThumb() end
end

-- ══════════════════════════════════════════════
--  REFRESH SAVED PANEL HEADER
-- ══════════════════════════════════════════════
local function refreshSavedPanelHeader()
    local n = countSavedOutfits()
    if n <= 0 then
        SavedEmpty.Text = "Es wurden noch keine Outfits gesaved!"
        SavedEmpty.Visible = true
        SavedTitleSub.Text = "0 Outfits"
    else
        SavedEmpty.Visible = false
        SavedTitleSub.Text = tostring(n) .. " Outfit(s)"
    end
end

-- ══════════════════════════════════════════════
--  OUTFIT CARD
-- ══════════════════════════════════════════════
local currentSubPlayer = nil

local function resortSavedOutfitCards()
    local cards = {}
    for _, ch in ipairs(SavedScroll:GetChildren()) do
        if ch:IsA("Frame") and ch:GetAttribute("SavedKey") then
            table.insert(cards, ch)
        end
    end
    table.sort(cards, function(a, b)
        return tostring(a:GetAttribute("SortName") or "") < tostring(b:GetAttribute("SortName") or "")
    end)
    for i, card in ipairs(cards) do
        card.LayoutOrder = i
        card.Name = string.format("%04d_%s", i, tostring(card:GetAttribute("SortName") or "Saved"))
    end
end

local function findSavedCardByKey(key)
    for _, ch in ipairs(SavedScroll:GetChildren()) do
        if ch:IsA("Frame") and ch:GetAttribute("SavedKey") == key then return ch end
    end
    return nil
end

local function createOutfitCard(parent, idx, outfitName, outfitId, isSavedPanel, savedOutfitData, renderToken, thumbLoadDelay)
    local cardW = isSavedPanel and C.OUT_W or C.SUB_OUT_W
    local card = Instance.new("Frame")
    card.Name = string.format("%04d_%s", idx, outfitName)
    card.Size = UDim2.fromOffset(cardW, C.OUT_H); card.LayoutOrder = idx
    card.BackgroundColor3 = C.CARD; card.BorderSizePixel = 0; card.ZIndex = 22; card.Parent = parent
    corner(card, 10)
    local cStroke = _makeDummyStroke(card)
    cStroke.Color = C.bg3 or Color3.fromRGB(45,45,45)

    if isSavedPanel and savedOutfitData then
        card:SetAttribute("SavedKey", tostring(savedOutfitData.userId).."_"..tostring(savedOutfitData.outfitId))
        card:SetAttribute("SortName", tostring(outfitName or "Unnamed"))
    end

    local thumb = Instance.new("ImageLabel")
    thumb.Size = UDim2.new(1,-12,0,105); thumb.Position = UDim2.fromOffset(6,6)
    thumb.BackgroundColor3 = Color3.fromRGB(12,12,12); thumb.BorderSizePixel = 0
    thumb.ZIndex = 23; thumb.ScaleType = Enum.ScaleType.Fit; thumb.Parent = card
    styleThumbSurface(thumb, 8)
    attachOutfitThumbnail(thumb, outfitId, renderToken or activeThumbRenderToken, thumbLoadDelay)

    local nameL = Instance.new("TextLabel")
    nameL.Text = outfitName; nameL.Size = UDim2.new(1,-32,0,18); nameL.Position = UDim2.fromOffset(4,113)
    nameL.BackgroundTransparency = 1; nameL.TextSize = 11; nameL.TextColor3 = C.TEXT1
    nameL.TextTruncate = Enum.TextTruncate.AtEnd; nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.ZIndex = 23; nameL.Parent = card; applyTextStyle(nameL, 11)

    local hbtn = Instance.new("TextButton")
    hbtn.Text = ""; hbtn.Size = isSavedPanel and UDim2.new(1,-30,1,-30) or UDim2.fromScale(1,1)
    hbtn.BackgroundTransparency = 1; hbtn.ZIndex = 24; hbtn.Parent = card

    -- Save / Remove Button
    if not isSavedPanel then
        local player = currentSubPlayer
        local saveBtn = Instance.new("ImageButton")
        saveBtn.Name = "SaveBtn"; saveBtn.Size = UDim2.fromOffset(22,22)
        saveBtn.Position = UDim2.new(1,-26,1,-26); saveBtn.Image = "rbxassetid://120703890568713"
        saveBtn.ImageColor3 = Color3.fromRGB(255,255,255); saveBtn.BackgroundTransparency = 1
        saveBtn.BorderSizePixel = 0; saveBtn.ZIndex = 26; saveBtn.Parent = card; corner(saveBtn, 8)
        bind(saveBtn.MouseEnter, function() tween(saveBtn, TI._010, {ImageColor3=Color3.fromRGB(200,200,200), Size=UDim2.fromOffset(23,23)}):Play() end)
        bind(saveBtn.MouseLeave, function() tween(saveBtn, TI._010, {ImageColor3=Color3.fromRGB(255,255,255), Size=UDim2.fromOffset(22,22)}):Play() end)
        bind(saveBtn.MouseButton1Down, function() tween(getPopScale(saveBtn), TI._008, {Scale=0.85}):Play() end)
        bind(saveBtn.MouseButton1Up, function() tween(getPopScale(saveBtn), TI._016, {Scale=1}):Play() end)
        bind(saveBtn.MouseButton1Click, function()
            local p = currentSubPlayer or player
            local entry
            if p then
                saveOutfitToCache(outfitId, outfitName or "Unnamed", p.Name, p.DisplayName, p.UserId)
                entry = { outfitId=outfitId, outfitName=outfitName or "Unnamed",
                           playerName=p.Name, displayName=p.DisplayName, userId=p.UserId }
            else
                saveOutfitToCache(outfitId, outfitName or "Unnamed", LocalPlayer.Name, LocalPlayer.DisplayName, LocalPlayer.UserId)
                entry = { outfitId=outfitId, outfitName=outfitName or "Unnamed",
                           playerName=LocalPlayer.Name, displayName=LocalPlayer.DisplayName, userId=LocalPlayer.UserId }
            end
            if SavedPanel.Visible and entry then
                -- appendSavedOutfitCard wird später definiert – forward call via pcall
                local ok, fn = pcall(function() return appendSavedOutfitCard end)
                if ok and fn then fn(entry) end
            end
            tween(saveBtn, getTI(0.15), {BackgroundColor3=Color3.fromRGB(28,46,28)}):Play()
            task.delay(0.6, function() tween(saveBtn, TI._020, {BackgroundColor3=Color3.fromRGB(18,18,18)}):Play() end)
        end)
    elseif savedOutfitData then
        local removeBtn = Instance.new("ImageButton")
        removeBtn.Name = "RemoveBtn"; removeBtn.Size = UDim2.fromOffset(22,22)
        removeBtn.Position = UDim2.new(1,-26,1,-26); removeBtn.Image = "rbxassetid://85088330963329"
        removeBtn.ImageColor3 = Color3.fromRGB(255,255,255); removeBtn.BackgroundTransparency = 1
        removeBtn.BorderSizePixel = 0; removeBtn.ZIndex = 26; removeBtn.Parent = card; corner(removeBtn, 8)
        bind(removeBtn.MouseEnter, function() tween(removeBtn, TI._010, {ImageColor3=Color3.fromRGB(255,100,100), Size=UDim2.fromOffset(23,23)}):Play() end)
        bind(removeBtn.MouseLeave, function() tween(removeBtn, TI._010, {ImageColor3=Color3.fromRGB(255,255,255), Size=UDim2.fromOffset(22,22)}):Play() end)
        bind(removeBtn.MouseButton1Down, function() tween(getPopScale(removeBtn), TI._008, {Scale=0.85}):Play() end)
        bind(removeBtn.MouseButton1Up, function() tween(getPopScale(removeBtn), TI._016, {Scale=1}):Play() end)
        bind(removeBtn.MouseButton1Click, function()
            removeBtn.Active = false; hbtn.Active = false
            tween(removeBtn, TI._008, {BackgroundColor3=Color3.fromRGB(44,18,18)}):Play()
            tween(card, getTI(0.16, Enum.EasingStyle.Quad), {Size=UDim2.fromOffset(cardW-10, C.OUT_H-10), BackgroundTransparency=0.35}):Play()
            tween(thumb, TI._016, {ImageTransparency=1, BackgroundTransparency=1}):Play()
            tween(nameL, TI._014, {TextTransparency=1}):Play()
            tween(cStroke, TI._014, {Transparency=1}):Play()
            task.delay(0.17, function()
                removeOutfitFromCache(savedOutfitData.outfitId, savedOutfitData.userId)
                if card and card.Parent then card:Destroy() end
                refreshSavedPanelHeader()
            end)
        end)
    end

    bind(hbtn.MouseEnter, function()
        tween(card, TI._012, {BackgroundColor3=C.CARD_HOVER}):Play()
        tween(cStroke, TI._012, {Color=C.accent or Color3.fromRGB(200, 200, 200)}):Play()
    end)
    bind(hbtn.MouseLeave, function()
        tween(card, TI._012, {BackgroundColor3=C.CARD}):Play()
        tween(cStroke, TI._012, {Color=C.bg3 or Color3.fromRGB(45,45,45)}):Play()
    end)
    bind(hbtn.MouseButton1Down, function() tween(getPopScale(card), TI._008, {Scale=0.96}):Play() end)
    bind(hbtn.MouseButton1Up, function() tween(getPopScale(card), TI._016, {Scale=1}):Play() end)
    bind(hbtn.MouseButton1Click, function() applyOutfit(outfitId) end)

    return card
end

local function appendSavedOutfitCard(savedOutfitData)
    if not SavedPanel.Visible or not savedOutfitData then return end
    local cacheKey = tostring(savedOutfitData.userId) .. "_" .. tostring(savedOutfitData.outfitId)
    if findSavedCardByKey(cacheKey) then refreshSavedPanelHeader(); resortSavedOutfitCards(); return end
    local rt = nextThumbRenderToken()
    local nId = tonumber(savedOutfitData.outfitId)
    local card = createOutfitCard(SavedScroll, 9999, savedOutfitData.outfitName or "Unnamed",
        nId or savedOutfitData.outfitId, true, savedOutfitData, rt, 0)
    card.BackgroundTransparency = 1; card.Size = UDim2.fromOffset(C.OUT_W-8, C.OUT_H-8)
    resortSavedOutfitCards(); refreshSavedPanelHeader()
    tween(card, TI._016, {BackgroundTransparency=0, Size=UDim2.fromOffset(C.OUT_W, C.OUT_H)}):Play()
end

local function renderOutfitCards(parent, outfits, isSavedPanel, renderToken)
    local batchSize = math.max(1, C.THUMB_STAGGER_BATCH)
    for i, outfit in ipairs(outfits) do
        if not parent or not parent.Parent then return end
        local thumbDelay = 0
        if i > C.THUMB_PRIORITY_COUNT then
            thumbDelay = math.floor((i - C.THUMB_PRIORITY_COUNT - 1) / batchSize + 1) * C.THUMB_STAGGER_DELAY
        end
        createOutfitCard(parent, i, outfit.name or "Unnamed", outfit.id,
            isSavedPanel, outfit.savedOutfitData, renderToken, thumbDelay)
        if i % batchSize == 0 then task.wait() end
    end
end

-- ══════════════════════════════════════════════
--  OPEN / CLOSE PANELS
-- ══════════════════════════════════════════════
local function closeOutfitPanel()
    clearShimmerConns(); invalidateThumbRenderToken()
    OutfitLoading.Visible = false; OutfitEmpty.Visible = false
    OutfitReloadBtn.Visible = false; OutfitReloadLabel.Visible = false
    tweenClose(SubPanel, C.SUB_W, C.SUB_H)
end

local function closeSavedPanel()
    invalidateThumbRenderToken()
    tweenClose(SavedPanel, C.SUB_W, C.SUB_H)
end

local function openSavedPanel()
    invalidateThumbRenderToken(); clearShimmerConns(); clearParentFrames(SavedScroll)
    SavedEmpty.Visible = false; tweenOpen(SavedPanel, C.SUB_W, C.SUB_H)
    loadSavedOutfitsFromCache(false)
    local savedList = {}
    for _, so in pairs(SavedOutfitsState.outfits) do
        table.insert(savedList, { name=so.outfitName or "Unnamed", id=tonumber(so.outfitId) or so.outfitId, savedOutfitData=so })
    end
    table.sort(savedList, function(a,b) return tostring(a.name) < tostring(b.name) end)
    refreshSavedPanelHeader()
    if #savedList > 0 then
        local rt = nextThumbRenderToken()
        preloadOutfitThumbs(savedList, C.THUMB_PRIORITY_COUNT)
        renderOutfitCards(SavedScroll, savedList, true, rt)
        resortSavedOutfitCards()
    end
end

local currentOutfitPage = 1
local totalOutfitPages = 1
local currentOutfitsList = {}

local function renderOutfitPage(pageIndex, renderToken)
    if activeThumbRenderToken ~= renderToken then return end
    clearShimmerConns(); clearParentFrames(OutfitScroll)
    local startIndex = (pageIndex - 1) * 100 + 1
    local endIndex = math.min(startIndex + 99, #currentOutfitsList)
    local pageOutfits = {}
    for i = startIndex, endIndex do
        table.insert(pageOutfits, currentOutfitsList[i])
    end
    renderOutfitCards(OutfitScroll, pageOutfits, false, renderToken)
    
    SubPageLabel.Text = tostring(pageIndex) .. " / " .. tostring(totalOutfitPages)
    if pageIndex <= 1 then
        tween(SubPagePrev, TI._012, {TextTransparency=0.6, BackgroundColor3=C.bg3 or Color3.fromRGB(22,22,22)}):Play()
    else
        tween(SubPagePrev, TI._012, {TextTransparency=0, BackgroundColor3=C.bg3 or Color3.fromRGB(22,22,22)}):Play()
    end
    if pageIndex >= totalOutfitPages then
        tween(SubPageNext, TI._012, {TextTransparency=0.6, BackgroundColor3=C.bg3 or Color3.fromRGB(22,22,22)}):Play()
    else
        tween(SubPageNext, TI._012, {TextTransparency=0, BackgroundColor3=C.bg3 or Color3.fromRGB(22,22,22)}):Play()
    end
end

bind(SubPagePrev.MouseButton1Click, function()
    if currentOutfitPage > 1 then
        currentOutfitPage = currentOutfitPage - 1
        renderOutfitPage(currentOutfitPage, activeThumbRenderToken)
    end
end)

bind(SubPageNext.MouseButton1Click, function()
    if currentOutfitPage < totalOutfitPages then
        currentOutfitPage = currentOutfitPage + 1
        renderOutfitPage(currentOutfitPage, activeThumbRenderToken)
    end
end)

local function openOutfitPanel(player)
    local renderToken = nextThumbRenderToken()
    currentSubPlayer = player
    clearShimmerConns(); clearParentFrames(OutfitScroll)
    OutfitLoading.Visible = true; OutfitEmpty.Visible = false
    OutfitEmpty.TextTransparency = 1; OutfitEmpty.Text = "—  Keine Outfits gespeichert"
    OutfitReloadBtn.Visible = false; OutfitReloadLabel.Visible = false

    SubAvatarThumb.Image = avatarThumbUrl(player.UserId)
    SubTitleName.Text    = (player.DisplayName .. "'S OUTFITS"):upper()
    SubTitleSub.Text     = "Wird geladen..."

    tweenOpen(SubPanel, C.SUB_W, C.SUB_H)

    -- Skeletons basierend auf gecachten Daten
    local cachedEntry = cacheGet(player.UserId)
    local visCount    = estimateVisibleCardCount(OutfitScroll, C.SUB_OUT_W, C.OUT_H, 8, 1)
    local skCount     = (cachedEntry and #cachedEntry > 0) and math.min(#cachedEntry, math.max(visCount,6)) or math.max(visCount,6)
    showSkeletons(OutfitScroll, skCount, C.SUB_OUT_W, C.OUT_H)

    task.spawn(function()
        local outfits = {}

        if player == LocalPlayer then
            local ok, pages = pcall(AvatarEditorSvc.GetOutfits, AvatarEditorSvc, Enum.OutfitSource.SavedOutfits)
            if ok and pages then
                local ok2, items = pcall(function() return pages:GetCurrentPage() end)
                if ok2 then for _, it in ipairs(items) do table.insert(outfits, {name=it.Name, id=it.Id}) end end
                while not pages.IsFinished do
                    if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
                    task.wait() -- Yield to prevent blocking
                    local ok3, more = pcall(function() return pages:GetCurrentPage() end)
                    if ok3 then for _, it in ipairs(more) do table.insert(outfits, {name=it.Name, id=it.Id}) end end
                end
            end
            if #outfits == 0 then
                local h, _ = fetchOutfitsViaHttp(player.UserId)
                if h then outfits = h end
            end
        else
            local h, err = fetchOutfitsViaHttp(player.UserId)
            if h then
                outfits = h
            else
                if activeThumbRenderToken ~= renderToken or currentSubPlayer ~= player then return end
                clearShimmerConns(); clearParentFrames(OutfitScroll)
                OutfitLoading.Visible = false; OutfitEmpty.TextTransparency = 0
                OutfitEmpty.Text = "✕  " .. (err or "Fehler"); OutfitEmpty.Visible = true
                SubTitleSub.Text = "Fehler"; return
            end
        end

        if activeThumbRenderToken ~= renderToken or currentSubPlayer ~= player then return end
        clearShimmerConns(); clearParentFrames(OutfitScroll)
        OutfitLoading.Visible = false; OutfitEmpty.Visible = false
        OutfitReloadBtn.Visible = false; OutfitReloadLabel.Visible = false

        if #outfits == 0 then
            OutfitEmpty.TextTransparency = 0; OutfitEmpty.Text = "—  Keine Outfits gespeichert"
            OutfitEmpty.Visible = true; OutfitReloadBtn.Visible = true; OutfitReloadLabel.Visible = true
            SubTitleSub.Text = "0 Outfits"; return
        end

        preloadOutfitThumbs(outfits, C.THUMB_PRIORITY_COUNT)
        SubTitleSub.Text = tostring(#outfits) .. " Outfit(s)"
        
        currentOutfitsList = outfits
        totalOutfitPages = math.ceil(#outfits / 100)
        currentOutfitPage = 1
        
        if #outfits >= 100 then
            SubPageContainer.Visible = true
        else
            SubPageContainer.Visible = false
        end
        
        renderOutfitPage(currentOutfitPage, renderToken)
    end)
end

-- ══════════════════════════════════════════════
--  SPIELERKARTE
-- ══════════════════════════════════════════════
local function createPlayerCard(player, index, startHidden)
    local card = Instance.new("Frame")
    card.Name = string.format("%04d_%s", index, player.Name)
    card.Size = UDim2.fromOffset(C.CARD_W, C.CARD_H); card.LayoutOrder = index
    card.BackgroundColor3 = C.CARD; card.BorderSizePixel = 0; card.ZIndex = 13; card.Parent = ScrollFrame
    corner(card, 10)
    local cStroke = _makeDummyStroke(card)
    cStroke.Color = C.bg3 or Color3.fromRGB(45,45,45)

    local thumb = Instance.new("ImageLabel")
    thumb.Size = UDim2.new(1,-16,0,86); thumb.Position = UDim2.fromOffset(8,8)
    thumb.BackgroundColor3 = Color3.fromRGB(10,10,10); thumb.BorderSizePixel = 0
    thumb.ZIndex = 14; thumb.ScaleType = Enum.ScaleType.Fit
    thumb.Image = avatarThumbUrl(player.UserId); thumb.Parent = card; styleThumbSurface(thumb, 8)

    local nameL = Instance.new("TextLabel")
    nameL.Text = player.DisplayName; nameL.Size = UDim2.new(1,-8,0,18); nameL.Position = UDim2.fromOffset(4,96)
    nameL.BackgroundTransparency = 1; nameL.TextSize = 12; nameL.TextColor3 = C.TEXT1
    nameL.TextTruncate = Enum.TextTruncate.AtEnd; nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.ZIndex = 14; nameL.Parent = card; applyTextStyle(nameL, 12)

    local dispL = Instance.new("TextLabel")
    dispL.Text = "@" .. player.Name; dispL.Size = UDim2.new(1,-8,0,13); dispL.Position = UDim2.fromOffset(4,114)
    dispL.BackgroundTransparency = 1; dispL.TextSize = 10; dispL.TextColor3 = C.TEXT2
    dispL.TextTruncate = Enum.TextTruncate.AtEnd; dispL.TextXAlignment = Enum.TextXAlignment.Left
    dispL.ZIndex = 14; dispL.Parent = card; applyTextStyle(dispL, 10)

    if player == LocalPlayer then
        local youBadge = Instance.new("Frame")
        youBadge.Size = UDim2.fromOffset(26,14); youBadge.Position = UDim2.new(1,-32,0,4)
        youBadge.BackgroundColor3 = C.bg3; youBadge.BackgroundTransparency = 0.2
        youBadge.BorderSizePixel = 0; youBadge.ZIndex = 15; youBadge.Parent = card
        corner(youBadge, 6)
        stroke(youBadge, 1, C.accent, 0.5)
        local youL = Instance.new("TextLabel")
        youL.Text = "DU"; youL.Size = UDim2.fromScale(1,1); youL.BackgroundTransparency = 1
        youL.TextSize = 9; youL.TextColor3 = C.TEXT1; youL.ZIndex = 16; youL.Parent = youBadge
        applyTextStyle(youL)
    end

    local btn = Instance.new("TextButton")
    btn.Text = ""; btn.Size = UDim2.fromScale(1,1); btn.BackgroundTransparency = 1
    btn.ZIndex = 17; btn.Parent = card

    bind(btn.MouseEnter, function()
        tween(card, TI._012, {BackgroundColor3=C.CARD_HOVER}):Play()
        tween(cStroke, TI._012, {Color=C.accent or Color3.fromRGB(200, 200, 200)}):Play()
    end)
    bind(btn.MouseLeave, function()
        tween(card, TI._012, {BackgroundColor3=C.CARD}):Play()
        tween(cStroke, TI._012, {Color=C.bg3 or Color3.fromRGB(45,45,45)}):Play()
    end)
    bind(btn.MouseButton1Down, function() tween(getPopScale(card), TI._008, {Scale=0.96}):Play() end)
    bind(btn.MouseButton1Up, function() tween(getPopScale(card), TI._016, {Scale=1}):Play() end)
    bind(btn.MouseButton1Click, function() openOutfitPanel(player) end)

    playerCardSnapshots[card] = buildTransparencySnapshot(card)
    local initialAlpha = startHidden and 1 or 0
    card:SetAttribute("FadeAlpha", initialAlpha)
    applyTransparencySnapshot(playerCardSnapshots[card], initialAlpha)

    return card
end

-- ══════════════════════════════════════════════
--  SPIELER-LISTE
-- ══════════════════════════════════════════════
local playerSearchTerm = ""

local function normalizeSearchText(v) return string.lower(tostring(v or "")) end

local function matchesPlayerSearch(player)
    if playerSearchTerm == "" then return true end
    local dn = normalizeSearchText(player.DisplayName)
    local un = normalizeSearchText(player.Name)
    return string.find(dn, playerSearchTerm, 1, true) or string.find(un, playerSearchTerm, 1, true)
end

local function getSortedPlayers()
    local all      = Players:GetPlayers()
    -- in-place sort (kein extra table.create nötig)
    table.sort(all, function(a, b)
        if a == LocalPlayer then return true end
        if b == LocalPlayer then return false end
        return a.Name < b.Name
    end)
    if playerSearchTerm == "" then return all end
    
    local filtered = {}
    
    if string.match(playerSearchTerm, "^%d+$") then
        local numId = tonumber(playerSearchTerm)
        if numId then
            table.insert(filtered, {
                Name = "UserID_Suche",
                DisplayName = "Suche ID: " .. tostring(numId),
                UserId = numId
            })
        end
    end

    for _, p in ipairs(all) do
        if matchesPlayerSearch(p) then table.insert(filtered, p) end
    end
    return filtered
end

-- ══════════════════════════════════════════════
--  PANEL BEFÜLLEN
-- ══════════════════════════════════════════════
local isOpen = false

local function syncPlayerCardsIncremental()
    if not isOpen or not ScrollFrame.Parent then return end
    clearShimmerConns(); LoadingLabel.Visible = false
    local all = getSortedPlayers()
    if updatePlayerCountDisplay then updatePlayerCountDisplay(#all) end

    local active = {}
    for i, player in ipairs(all) do
        active[player.UserId] = true
        local existing = playerCardsByUserId[player.UserId]
        if existing and existing.Parent then
            existing.Name = string.format("%04d_%s", i, player.Name)
            existing.LayoutOrder = i
            -- Ensure existing card is fully visible
            existing:SetAttribute("FadeAlpha", 0)
            applyTransparencySnapshot(playerCardSnapshots[existing], 0)
        else
            local card = createPlayerCard(player, i, true)
            playerCardsByUserId[player.UserId] = card
            tweenPlayerCardVisibility(card, 0, 0.18)
        end
    end
    for userId, card in pairs(playerCardsByUserId) do
        if not active[userId] then
            playerCardsByUserId[userId] = nil
            tweenPlayerCardVisibility(card, 1, 0.14, function()
                if card and card.Parent then card:Destroy() end
            end)
        end
    end
end

local function populatePanel()
    local renderToken = nextPlayerListToken()
    clearShimmerConns(); clearPlayerCardRegistry(); clearParentFrames(ScrollFrame)
    LoadingLabel.Visible = false
    local all = getSortedPlayers()
    if updatePlayerCountDisplay then updatePlayerCountDisplay(#all) end

    local skCount = math.min(#all, math.max(estimateVisibleCardCount(ScrollFrame, C.CARD_W, C.CARD_H, C.GAP, 1), 8))
    showSkeletons(ScrollFrame, skCount, C.CARD_W, C.CARD_H)
    task.wait()
    local ok, err = pcall(function()
        if activePlayerListToken ~= renderToken or not isOpen or not ScrollFrame.Parent then
            clearShimmerConns(); return
        end
        clearShimmerConns(); clearParentFrames(ScrollFrame); clearPlayerCardRegistry()
        for i, player in ipairs(all) do
            if activePlayerListToken ~= renderToken or not isOpen then return end
            playerCardsByUserId[player.UserId] = createPlayerCard(player, i, false)
            if i % 10 == 0 then task.wait() end
        end
    end)
    if not ok then
        warn("[AvatarOutfitPanel] populatePanel Fehler:", err)
        clearShimmerConns(); clearParentFrames(ScrollFrame)
        LoadingLabel.Text = "✕  Spieler konnten nicht geladen werden"; LoadingLabel.Visible = true
    end
end

-- ══════════════════════════════════════════════
--  OPEN / CLOSE HAUPT-PANEL
-- ══════════════════════════════════════════════
local function openPanel()  isOpen = true;  tweenOpen(Panel, C.PANEL_W, C.PANEL_H); populatePanel() end
local function closePanel()
    isOpen = false
    activePlayerListToken      += 1
    scheduledPlayerRefreshToken = (scheduledPlayerRefreshToken or 0) + 1
    currentSubPlayer = nil
    if SubPanel.Visible  then closeOutfitPanel() end
    if SavedPanel.Visible then closeSavedPanel() end
    tweenClose(Panel, C.PANEL_W, C.PANEL_H)
end

-- ══════════════════════════════════════════════
--  DEBOUNCED PLAYER REFRESH
-- ══════════════════════════════════════════════
local scheduledPlayerRefreshToken = 0
local function schedulePlayerListRefresh(delaySeconds)
    scheduledPlayerRefreshToken += 1
    local token = scheduledPlayerRefreshToken
    task.delay(delaySeconds or 0.12, function()
        if token ~= scheduledPlayerRefreshToken or not isOpen then return end
        syncPlayerCardsIncremental()
    end)
end

-- ══════════════════════════════════════════════
--  DEBOUNCED SEARCH (verhindert Render-Spam)
-- ══════════════════════════════════════════════
local searchDebounceToken = 0
bind(SearchBox:GetPropertyChangedSignal("Text"), function()
    local normalized = normalizeSearchText(SearchBox.Text):match("^%s*(.-)%s*$")
    if normalized == playerSearchTerm then return end
    playerSearchTerm = normalized
    if not isOpen then return end
    searchDebounceToken += 1
    local token = searchDebounceToken
    -- Kurze Verzögerung damit schnelles Tippen nicht jeden Frame triggert
    task.delay(0.08, function()
        if token ~= searchDebounceToken then return end
        schedulePlayerListRefresh(0)
    end)
end)

-- ══════════════════════════════════════════════
--  EVENT BINDINGS
-- ══════════════════════════════════════════════
bind(CloseBtn.MouseButton1Click, closePanel)

bind(RefreshBtn.MouseButton1Click, function()
    if not isOpen then return end
    if SubPanel.Visible and currentSubPlayer then
        diskCacheInvalidate(currentSubPlayer.UserId)
        cacheDel(currentSubPlayer.UserId)
        openOutfitPanel(currentSubPlayer)
    else
        populatePanel()
    end
end)

bind(SavedOutfitsBtn.MouseButton1Click, function()
    if SavedPanel.Visible then closeSavedPanel() else openSavedPanel() end
end)

bind(SubCloseBtn.MouseButton1Click, function() currentSubPlayer = nil; closeOutfitPanel() end)
bind(SubBackBtn.MouseButton1Click,  function() currentSubPlayer = nil; closeOutfitPanel() end)
bind(SavedCloseBtn.MouseButton1Click, closeSavedPanel)

bind(SubRefreshBtn.MouseButton1Click, function()
    if not currentSubPlayer then return end
    local spinTw = tween(SubRefreshBtn, getTI(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false), {Rotation = SubRefreshBtn.Rotation + 360})
    spinTw:Play()
    diskCacheInvalidate(currentSubPlayer.UserId)
    cacheDel(currentSubPlayer.UserId)
    openOutfitPanel(currentSubPlayer)
end)

bind(OutfitReloadBtn.MouseButton1Click, function()
    if not currentSubPlayer then return end
    OutfitEmpty.Visible = false; OutfitReloadBtn.Visible = false; OutfitReloadLabel.Visible = false
    OutfitLoading.Visible = true
    diskCacheInvalidate(currentSubPlayer.UserId); cacheDel(currentSubPlayer.UserId)
    openOutfitPanel(currentSubPlayer)
end)

bind(Services.UserInputService.InputBegan, function(inp, gp)
    if not gp and inp.KeyCode == C.KEYBIND then
        if isOpen then closePanel() else openPanel() end
    end
end)

bind(Players.PlayerAdded,   function() if isOpen then schedulePlayerListRefresh(0.08) end end)
bind(Players.PlayerRemoving, function() if isOpen then schedulePlayerListRefresh(0.14) end end)

bind(LocalPlayer.CharacterAdded, function(char)
    flying = false
    humanoid  = char:WaitForChild("Humanoid")
    rootPart  = char:WaitForChild("HumanoidRootPart")
end)

-- ══════════════════════════════════════════════
--  KEYBIND-HINT
-- ══════════════════════════════════════════════
local function showKeybindHint()
    local hintGui = Instance.new("ScreenGui")
    hintGui.Name = "AvatarOutfitPanelHint"; hintGui.ResetOnSpawn = false
    hintGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    registerInstance(hintGui)
    hintGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local hintF = Instance.new("Frame")
    hintF.Size = UDim2.fromOffset(220,32); hintF.Position = UDim2.new(0.5,0,1,-56)
    hintF.AnchorPoint = Vector2.new(0.5,1); hintF.BackgroundColor3 = Color3.fromRGB(8,8,8)
    hintF.BorderSizePixel = 0; hintF.BackgroundTransparency = 0.15; hintF.Parent = hintGui
    corner(hintF, 6); stroke(hintF, Color3.fromRGB(50,50,50), 1)

    local hintL = Instance.new("TextLabel")
    hintL.Text = string.format("◈  Avatar Panel  [%s]", C.KEYBIND.Name)
    hintL.Size = UDim2.fromScale(1,1); hintL.BackgroundTransparency = 1
    hintL.TextSize = 11; hintL.TextColor3 = Color3.fromRGB(160,160,160); hintL.ZIndex = 2
    hintL.Parent = hintF; applyTextStyle(hintL)

    task.delay(3.5, function()
        tween(hintF, TI._080, {BackgroundTransparency=1, Position=UDim2.new(0.5,0,1,-76)}):Play()
        tween(hintL, TI._080, {TextTransparency=1}):Play()
        task.delay(0.9, function() hintGui:Destroy() end)
    end)
end
showKeybindHint()

-- ══════════════════════════════════════════════
--  POSITIONEN LADEN
-- ══════════════════════════════════════════════
loadGuiPositions()

log("[AvatarOutfitPanel] Geladen. Taste:", C.KEYBIND.Name,
    "| Disk-Cache:", diskCacheAvailable and ("✓ " .. C.DISK_CACHE_DIR) or "✗")
return { open = openPanel, close = closePanel, getIsOpen = function() return isOpen end }

    end
    
    outfitBtn.MouseButton1Click:Connect(function()
        if not outfitPanelAPI then
            outfitPanelAPI = initAvatarOutfit()
            outfitPanelAPI.open()
        else
            if outfitPanelAPI.getIsOpen() then
                outfitPanelAPI.close()
            else
                outfitPanelAPI.open()
            end
        end
    end)
end

local movePage = Instance.new("Frame", sSubArea)
movePage.BackgroundTransparency = 1; movePage.BorderSizePixel = 0
movePage.Visible = false
do
local row = Instance.new("Frame", movePage)
row.Size = UDim2.new(1, 0, 0, 46); row.Position = UDim2.new(0, 0, 0, 0)
row.BackgroundColor3 = C.bg2 or _C3_BG2; row.BackgroundTransparency = 0; row.BorderSizePixel = 0
corner(row, 12)
local rowS = _makeDummyStroke(row); rowS.Thickness = 1; rowS.Color = C.bg3 or _C3_BG3; rowS.Transparency = 0.3
local rowD = Instance.new("Frame", row); rowD.Size = UDim2.new(0,3,0,26); rowD.Visible = false; rowD.Position = UDim2.new(0,0,0.5,-13)
rowD.BackgroundColor3 = C.accent2; rowD.BackgroundTransparency = 0.4; rowD.BorderSizePixel = 0; corner(rowD, 99)
local lbl = Instance.new("TextLabel", row)
lbl.Size = UDim2.new(0, 120, 1, 0); lbl.Position = UDim2.new(0, 16, 0, 0)
lbl.BackgroundTransparency = 1; lbl.Text = "Speed Hack"
lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13
lbl.TextColor3 = C.text; lbl.TextXAlignment = Enum.TextXAlignment.Left
local SPEED_MIN, SPEED_MAX, SPEED_DEFAULT = 1, 500, 100
local speedVal = SPEED_DEFAULT
local speedActive = false
local speedLbl = Instance.new("TextLabel", row)
speedLbl.Size = UDim2.new(0, 36, 0, 22); speedLbl.Position = UDim2.new(0, 140, 0.5, -11)
speedLbl.BackgroundTransparency = 1; speedLbl.Text = tostring(SPEED_DEFAULT)
speedLbl.Font = Enum.Font.GothamBold; speedLbl.TextSize = 12
speedLbl.TextColor3 = C.accent2; speedLbl.TextXAlignment = Enum.TextXAlignment.Center
local trackBg = Instance.new("Frame", row)
trackBg.Size = UDim2.new(0, 140, 0, 8); trackBg.Position = UDim2.new(0, 182, 0.5, -4)
trackBg.BackgroundColor3 = C.bg3; trackBg.BorderSizePixel = 0
corner(trackBg, 4); stroke(trackBg, 1, C.accent2, 0.6)
local trackFill = Instance.new("Frame", trackBg)
trackFill.Size = UDim2.new((SPEED_DEFAULT - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1, 0)
trackFill.Position = UDim2.new(0, 0, 0, 0); trackFill.BackgroundColor3 = C.accent2
trackFill.BorderSizePixel = 0; corner(trackFill, 4)
local knob = Instance.new("Frame", trackBg)
knob.Size = UDim2.new(0, 14, 0, 14)
knob.Position = UDim2.new((SPEED_DEFAULT - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), -7, 0.5, -7)
knob.BackgroundColor3 = _C3_WHITE; knob.BorderSizePixel = 0; knob.ZIndex = 5
corner(knob, 99)
local ks = _makeDummyStroke(knob); ks.Thickness = 1.5; ks.Color = C.accent2; ks.Transparency = 0
local dragging = false
local function updateSlider(absX)
local ratio = math.clamp((absX - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
speedVal = math.floor(SPEED_MIN + ratio * (SPEED_MAX - SPEED_MIN))
trackFill.Size = UDim2.new(ratio, 0, 1, 0)
knob.Position = UDim2.new(ratio, -7, 0.5, -7)
speedLbl.Text = tostring(speedVal)
if speedActive then local h = getHumanoid(); if h then h.WalkSpeed = speedVal end end
end
local inputBg = Instance.new("TextButton", trackBg)
inputBg.Size = UDim2.new(1, 14, 1, 14); inputBg.Position = UDim2.new(0, -7, 0, -7)
inputBg.BackgroundTransparency = 1; inputBg.Text = ""; inputBg.ZIndex = 6
inputBg.MouseButton1Down:Connect(function(x) dragging = true; updateSlider(x) end)
inputBg.MouseMoved:Connect(function(x) if dragging then updateSlider(x) end end)
inputBg.MouseButton1Up:Connect(function() dragging = false end)
inputBg.MouseLeave:Connect(function() dragging = false end)
addWidgetBtn(row, "Speed Hack", C.accent2, function(on)
speedActive = on
local h = getHumanoid(); if h then h.WalkSpeed = on and speedVal or 16 end
end, function() return speedActive end, 330)
makeToggle(row, 405, 11, false, function(on)
speedActive = on
local h = getHumanoid(); if h then h.WalkSpeed = on and speedVal or 16 end
end)
end
;(function()
-- -- Ultra Instinct – Schutz-System -----------------------------------------
-- Schützt gegen:
--   1. Physik-Exploits (AssemblyLinearVelocity / sethiddenproperty Fling)
--   2. Velocity-Fling (zu hohe Geschwindigkeit → sofort cappen)
--   3. Humanoid-Manipulation (WalkSpeed=0, Health=0, PlatformStand=true)
--   4. CFrame-Teleport durch fremde Clients (erkennt plötzliche Positions-Sprünge)
--   5. Forced Ragdoll via sethiddenproperty
--   6. Proximity-Dodge: Spieler im Radius → ausweichen
local _ui_active       = false
local lastRadius       = 5
local _ui_radius       = 5
local _ui_conn         = nil
local _ui_charConn_    = nil
local _ui_lastPos      = nil
local _ui_savedCF      = nil
local _ui_lastAnchored = false
local MAX_VELOCITY  = 250
local MAX_JUMP      = 180

local function _uiGetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart"), c
end
local function _uiGetHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function _uiStart()
    if _ui_conn then return end
    _ui_conn = RunService.Heartbeat:Connect(function(dt)
        if not _ui_active then return end
        local hrp, char = _uiGetHRP()
        local hum = _uiGetHum()
        -- Schutz 1: Velocity-Cap (Fling / sethiddenproperty)
        if hrp then
            local vel = hrp.AssemblyLinearVelocity
            if vel.Magnitude > MAX_VELOCITY then
                pcall(function()
                    hrp.AssemblyLinearVelocity  = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    if _ui_savedCF then hrp.CFrame = _ui_savedCF end
                end)
                sendNotif("Ultra Instinct", "Fling abgeblockt!", 2)
            end
        end
        -- Schutz 2: CFrame-Sprung (fremder Teleport via sethiddenproperty)
        if hrp then
            local curPos = hrp.Position
            if _ui_lastPos then
                local jump = (curPos - _ui_lastPos).Magnitude
                if jump > MAX_JUMP then
                    if os.clock() - _ui_lastTP > 0.5 then
                        pcall(function() if _ui_savedCF then hrp.CFrame = _ui_savedCF end end)
                        sendNotif("Ultra Instinct", "Teleport-Hack geblockt!", 2)
                    end
                end
            end
            _ui_lastPos = curPos
            if hum and hum.Health > 0 and not hum.PlatformStand then
                local state = hum:GetState()
                if state == Enum.HumanoidStateType.Running
                or state == Enum.HumanoidStateType.RunningNoPhysics
                or state == Enum.HumanoidStateType.Landed then
                    _ui_savedCF = hrp.CFrame
                end
            end
        end
        -- Schutz 3: Humanoid-Manipulation
        if hum and hrp then
            if hum.WalkSpeed <= 0 then
                pcall(function() hum.WalkSpeed = 16 end)
            end
            if hum.PlatformStand and not flyActive then
                pcall(function() hum.PlatformStand = false end)
            end
            if hum.Health < 1 and hum.Health > 0 then
                pcall(function() hum.Health = hum.MaxHealth end)
            end
            if hrp.Anchored then
                pcall(function() hrp.Anchored = false end)
                _ui_lastAnchored = true
            end
        end
    end)
end
local function _uiStop()
    _ui_active = false
    if _ui_conn then _ui_conn:Disconnect(); _ui_conn = nil end
    if _ui_charConn_ then _ui_charConn_:Disconnect(); _ui_charConn_ = nil end
    _ui_lastPos      = nil
    _ui_savedCF      = nil
    _ui_lastAnchored = false
end
-- Alias für sRow-Toggle und UI-Slider-Kompatibilität
local function createCircleUI(radius)
    lastRadius  = radius
    _ui_radius  = radius
    _ui_active  = true
    _uiStart()
end
local function clearCircleUI()
    _uiStop()
end
local uiActive = false  -- Alias für Slider-Kompatibilität
_ui_charConn_ = LocalPlayer.CharacterAdded:Connect(function()
    if not _ui_active then return end
    _uiStop()
    task.wait(1)
    _ui_active = true
    _uiStart()
end)
do
local avActive    = false
local avConn      = nil
local avCharConn  = nil
local VOID_Y      = -200
local avLastCF    = nil
local avRescuing  = false
local avLastRescue = 0
local function avStop()
avActive = false
avRescuing = false
if avConn     then avConn:Disconnect();     avConn     = nil end
if avCharConn then avCharConn:Disconnect(); avCharConn = nil end
end
local function avStart()
avStop()
avActive   = true
avLastCF   = nil
avRescuing = false
avCharConn = LocalPlayer.CharacterAdded:Connect(function()
avLastCF   = nil
avRescuing = false
end)
local _avCC = LocalPlayer.Character
local _avRC = _avCC and _avCC:FindFirstChild("HumanoidRootPart")
local _avHC = _avCC and _avCC:FindFirstChildOfClass("Humanoid")
local _avAcc = 0
avConn = RunService.Heartbeat:Connect(function(dt)
if not avActive then return end
if avRescuing  then return end
_avAcc = _avAcc + dt
if _avAcc < 0.1 then return end
_avAcc = 0
local char = LocalPlayer.Character
if not char then return end
if char ~= _avCC then
_avCC = char
_avRC = char:FindFirstChild("HumanoidRootPart")
_avHC = char:FindFirstChildOfClass("Humanoid")
_avAcc = 0
end
local root = _avRC; local hum = _avHC
if not root or not hum then return end
if hum.Health <= 0 then return end
local pos = root.Position
if pos.Y > -100 then
local state = hum:GetState()
if state == Enum.HumanoidStateType.Running
or state == Enum.HumanoidStateType.RunningNoPhysics
or state == Enum.HumanoidStateType.Landed
or state == Enum.HumanoidStateType.Seated then
avLastCF = root.CFrame + Vector3.new(0, 3, 0)
end
return
end
if pos.Y >= VOID_Y then return end
local now = os.clock()
if now - avLastRescue < 2 then return end
avLastRescue = now
avRescuing   = true
local target = avLastCF
if not target then
local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
target = spawnLoc and spawnLoc.CFrame * CFrame.new(0, 8, 0)
or CFrame.new(0, 10, 0)
end
pcall(function()
root.CFrame = target
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end)
sendNotif("Anti-Void", " Void detected ✅ Saved!", 2)
task.delay(0.5, function()
avRescuing = false
end)
end)
end
sRow(movePage, 0, "Anti-Void", "Im not letting you die in the Void!!", C.accent2, false, function(on)
if on then
avStart()
sendNotif("Anti-Void", "Anti-Void aktiviert ✅ ich passe auf dich auf!", 3)
else
avStop()
sendNotif("Anti-Void", "Anti-Void deaktiviert.", 2)
end
end)
pcall(function()
if getgenv then _genv._TL_AntiVoidStop = avStop end
end)
end
local uiRow, uiSetToggle, _ = sRow(movePage, 56, "Ultra Instinct", "Dodge any Player", C.accent2, false, function(on)
if on then
createCircleUI(lastRadius)
sendNotif("Ultra Instinct", "I can feel it... my mind is calm.", 3)
else
clearCircleUI()
sendNotif("Ultra Instinct", "Ultra Instinct deaktiviert.", 2)
end
end)
do
local UI_MIN, UI_MAX = 1, 50
local uiValLbl = Instance.new("TextLabel", uiRow)
uiValLbl.Size = UDim2.new(0, 36, 0, 22); uiValLbl.Position = UDim2.new(0, 140, 0.5, -11)
uiValLbl.BackgroundTransparency = 1; uiValLbl.Text = tostring(lastRadius)
uiValLbl.Font = Enum.Font.GothamBold; uiValLbl.TextSize = 12
uiValLbl.TextColor3 = C.accent; uiValLbl.TextXAlignment = Enum.TextXAlignment.Center
local uiTrack = Instance.new("Frame", uiRow)
uiTrack.Size = UDim2.new(0, 140, 0, 8); uiTrack.Position = UDim2.new(0, 182, 0.5, -4)
uiTrack.BackgroundColor3 = C.bg3; uiTrack.BorderSizePixel = 0
corner(uiTrack, 4); stroke(uiTrack, 1, C.accent2, 0.6)
local uiFill = Instance.new("Frame", uiTrack)
uiFill.Size = UDim2.new((lastRadius - UI_MIN) / (UI_MAX - UI_MIN), 0, 1, 0)
uiFill.Position = UDim2.new(0, 0, 0, 0); uiFill.BackgroundColor3 = C.accent2
uiFill.BorderSizePixel = 0; corner(uiFill, 4)
local uiKnob = Instance.new("Frame", uiTrack)
uiKnob.Size = UDim2.new(0, 14, 0, 14)
uiKnob.Position = UDim2.new((lastRadius - UI_MIN) / (UI_MAX - UI_MIN), -7, 0.5, -7)
uiKnob.BackgroundColor3 = _C3_WHITE; uiKnob.BorderSizePixel = 0; uiKnob.ZIndex = 5
corner(uiKnob, 99)
local uiKS = _makeDummyStroke(uiKnob); uiKS.Thickness = 1.5; uiKS.Color = C.accent2; uiKS.Transparency = 0
local uiDragging = false
local UIS = UserInputService or _SvcUIS
local function updateUISlider(absX)
local trackX = uiTrack.AbsolutePosition.X
local trackW = uiTrack.AbsoluteSize.X
if trackW <= 0 then return end
local ratio = math.clamp((absX - trackX) / trackW, 0, 1)
lastRadius = math.max(1, math.floor(UI_MIN + ratio * (UI_MAX - UI_MIN)))
uiFill.Size = UDim2.new(ratio, 0, 1, 0)
uiKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
uiValLbl.Text = tostring(lastRadius)
if _ui_active then _ui_radius = lastRadius end
end
uiTrack.ClipsDescendants = false
uiKnob.ZIndex = 10
local uiInput = Instance.new("TextButton", uiRow)
uiInput.Size = UDim2.new(0, 164, 1, 0)
uiInput.Position = UDim2.new(0, 170, 0, 0)
uiInput.BackgroundTransparency = 1
uiInput.Text = ""
uiInput.ZIndex = 20
uiInput.Active = true
uiInput.AutoButtonColor = false
uiInput.MouseButton1Down:Connect(function()
uiDragging = true
updateUISlider(UIS:GetMouseLocation().X)
end)
uiInput.MouseButton1Up:Connect(function()
uiDragging = false
end)
uiInput.MouseMoved:Connect(function()
if uiDragging then
updateUISlider(UIS:GetMouseLocation().X)
end
end)
_tlTrackConn(RunService.Heartbeat:Connect(function()
if not uiDragging then return end
if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
uiDragging = false; return
end
updateUISlider(UIS:GetMouseLocation().X)
end))
end
end)()
movePage.Size = UDim2.new(1, 0, 0, 112 + 56 + 56 + 56 + 56 + 56 + 56)  -- +Anti-Ragdoll +Punch-Fling +Touch-Fling +Click-Teleport +Fly

-- -- Anti-Ragdoll ----------------------------------------------------------
do
local antiRagdollEnabled    = false
local antiRagdollConnection = nil

local function startAntiRagdoll()
    if antiRagdollConnection then return end
    antiRagdollConnection = RunService.Heartbeat:Connect(function()
        if not antiRagdollEnabled then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        -- Prevent ragdoll states (but allow if flying)
        if humanoid.PlatformStand and not flyActive then humanoid.PlatformStand = false end
        if humanoid.Sit and not flyActive then humanoid.Sit = false end
        -- Keep joints intact
        for _, v in pairs(character:GetChildren()) do
            if v:IsA("Motor6D") and v.Parent ~= character then
                v.Parent = character
            end
        end
    end)
end

local function stopAntiRagdoll()
    antiRagdollEnabled = false
    if antiRagdollConnection then
        antiRagdollConnection:Disconnect()
        antiRagdollConnection = nil
    end
end

sRow(movePage, 112, "Anti-Ragdoll", "Movement", C.red, false, function(on)
    antiRagdollEnabled = on
    if on then startAntiRagdoll()
    else       stopAntiRagdoll() end
end)
end

-- -- Punch-Fling -----------------------------------------------------------
do
local _pfTool = nil
local _pfActive = false
local _pfFlingActive = false
local _pfLoopRunning = false
local _pfCleanupList = {}
local _pfDiedConn = nil

local function pfAddToCleanup(obj)
    table.insert(_pfCleanupList, obj)
end

local function pfLoadAnimation(humanoid, animId)
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
        pfAddToCleanup(animator)
    end
    local resolvedId = "rbxassetid://" .. animId
    pcall(function()
        local objects = game:GetObjects("rbxassetid://" .. animId)
        if objects and objects[1] then
            local obj = objects[1]
            if obj:IsA("Animation") then
                resolvedId = obj.AnimationId
            else
                local child = obj:FindFirstChildOfClass("Animation")
                if child then
                    resolvedId = child.AnimationId
                end
            end
            obj.Parent = workspace
            pfAddToCleanup(obj)
            task.delay(2, function()
                pcall(function() obj:Destroy() end)
            end)
        end
    end)
    local anim = Instance.new("Animation")
    anim.AnimationId = resolvedId
    pfAddToCleanup(anim)
    local track = animator:LoadAnimation(anim)
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = false
    return track
end

local function pfFindPart(p3, p4, p5)
    local u6 = nil
    pcall(function()
        for _, v11 in pairs(p3:GetChildren()) do
            if v11.Name == p4 and v11:IsA(p5) then
                u6 = v11
                break
            end
        end
    end)
    return u6
end

local function pfDash(hrp)
    if hrp then
        local dir = hrp.CFrame.LookVector
        hrp.Velocity = dir * 120
        hrp.CFrame = hrp.CFrame + (dir * 2)
    end
end

local function pfCleanup()
    _pfLoopRunning = false
    _pfFlingActive = false
    if _pfTool then pcall(function() _pfTool:Destroy() end); _pfTool = nil end
    if _pfDiedConn then pcall(function() _pfDiedConn:Disconnect() end); _pfDiedConn = nil end
    for _, obj in ipairs(_pfCleanupList) do
        pcall(function() obj:Destroy() end)
    end
    _pfCleanupList = {}
end

local function pfStartTool()
    if _pfTool then return end
    local lp = Players.LocalPlayer
    local char = lp.Character
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 3)
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    if not hum or not hrp then return end

    _pfTool = Instance.new("Tool")
    _pfTool.RequiresHandle = false
    _pfTool.Name = "TLPunchFling"
    _pfTool.TextureId = "rbxassetid://139541574667160"
    _pfTool.Parent = lp.Backpack

    _pfLoopRunning = true
    _pfFlingActive = false

    task.spawn(function()
        local v20 = nil
        local v21 = nil
        local v22 = 0.1
        while _pfLoopRunning do
            RunService.Heartbeat:Wait()
            if _pfFlingActive then
                while _pfFlingActive and _pfLoopRunning and not (v20 and v20.Parent and v21 and v21.Parent) do
                    RunService.Heartbeat:Wait()
                    v20 = lp.Character
                    if v20 then
                        v21 = pfFindPart(v20, "HumanoidRootPart", "BasePart")
                            or pfFindPart(v20, "Torso", "BasePart")
                            or pfFindPart(v20, "UpperTorso", "BasePart")
                    end
                end
                if _pfLoopRunning and _pfFlingActive and v21 and v21.Parent then
                    local _Velocity = v21.Velocity
                    v21.AssemblyLinearVelocity = _Velocity * 100 + Vector3.new(99999999, 99999999, 99999999)
                    v21.CFrame = v21.CFrame * CFrame.new(0, 0.001, 0)
                    RunService.RenderStepped:Wait()
                    if v20 and v20.Parent and v21 and v21.Parent then
                        v21.Velocity = _Velocity
                    end
                    RunService.Stepped:Wait()
                    if v20 and v20.Parent and v21 and v21.Parent then
                        v21.Velocity = _Velocity + Vector3.new(0, v22, 0)
                        v22 = v22 * -1
                    end
                end
            end
        end
    end)

    _pfTool.Activated:Connect(function()
        if _pfFlingActive then return end
        local track1 = pfLoadAnimation(hum, "116450987409557")
        local track2 = pfLoadAnimation(hum, "75981039646929")
        if track1 then
            track1:Play()
            track1.Stopped:Wait()
        end
        pfDash(hrp)
        if track2 then track2:Play() end
        _pfFlingActive = true
        task.wait(1.5)
        _pfFlingActive = false
    end)

    _pfDiedConn = hum.Died:Connect(function()
        pfCleanup()
    end)
end

sRow(movePage, 168, "Punch-Fling", "Combat", C.orange, false, function(on)
    _pfActive = on
    if on then
        pfStartTool()
        sendNotif("Punch-Fling", "🔧 Tool im Backpack", 3)
    else
        pfCleanup()
        sendNotif("Punch-Fling", "Deaktiviert & Tool entfernt.", 2)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if _pfActive then pfStartTool() end
end)
end

-- -- Touch Fling V5.0 ------------------------------------------------------
do
    local tfActive = false
    local tfSpeed  = 50
    local tfMode   = "Dash Fling"
    local tfAnims  = {
        ["Dash Fling"]    = "130847442125893",
        ["Tornado Fling"] = "83769457908471",
        ["Mini-Train"]    = "75460531474787",
    }
    local tfModeList = {"Dash Fling", "Tornado Fling", "Mini-Train"}
    local tfModeIdx  = 1
    local tfTrack    = nil
    local tfConn     = nil
    local tfNoCol    = {}
    local tfOrigWS, tfOrigJP = 16, 50

    local function tfStop()
        tfActive = false
        if tfConn then tfConn:Disconnect(); tfConn = nil end
        if tfTrack then pcall(function() tfTrack:Stop() end); tfTrack = nil end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and tfOrigWS then
            hum.WalkSpeed = tfOrigWS; hum.JumpPower = tfOrigJP
        end
        tfNoCol = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then pcall(function() part.CanCollide = true end) end
                end
            end
        end
    end

    local function tfPlayAnim()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if tfTrack then pcall(function() tfTrack:Stop() end); tfTrack = nil end
        local animId = tfAnims[tfMode]
        pcall(function()
            tfTrack = _AF_loadAndPlayAnimation(hum, animId)
            if tfTrack then
                tfTrack:AdjustSpeed(tfSpeed / 16)
                tfTrack:Play()
            end
        end)
    end

    local function tfStep(dt)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        
        hum.WalkSpeed = tfSpeed
        hum.JumpPower = tfSpeed * 1.5
        if not tfTrack or not tfTrack.IsPlaying then tfPlayAnim() end
        if tfTrack then tfTrack:AdjustSpeed(tfSpeed / 16) end

        -- Original Fling Physics (Restored)
        local vel = hrp.Velocity
        hrp.Velocity = vel * 9e9 + Vector3.new(0, 9e9, 0)
        RunService.RenderStepped:Wait()
        hrp.Velocity = vel
    end

    -- Background Collision Handler (Lagsfix)
    task.spawn(function()
        while task.wait(0.25) do
            if not tfActive then continue end
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        for _, part in ipairs(p.Character:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end
                end
            end)
        end
    end)

    local tfRow, tfSetTog, _ = sRow(movePage, 224, "Touch Fling", "Movement V5", C.accent2, false, function(on)
        tfActive = on
        if on then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then tfOrigWS = hum.WalkSpeed; tfOrigJP = hum.JumpPower end
            _flyMuteSounds(true)
            tfConn = RunService.Heartbeat:Connect(tfStep)
            sendNotif("Touch Fling", "Fling active: " .. tfMode, 3)
        else
            tfStop()
            _flyMuteSounds(false)
            sendNotif("Touch Fling", "Disabled.", 2)
        end
    end)

    -- Mode Dropdown Pill (Advanced Top-Layer Version)
    local mPill = Instance.new("Frame", tfRow)
    mPill.Size = UDim2.new(0, 85, 0, 26); mPill.Position = UDim2.new(0, 80, 0.5, -13)
    mPill.BackgroundColor3 = C.bg3; mPill.BackgroundTransparency = 0.5; corner(mPill, 8)
    mPill.ZIndex = 12; local mPillS = stroke(mPill, 1.2, C.accent, 0.6)
    
    local mBtn = Instance.new("TextButton", mPill)
    mBtn.Size = UDim2.new(1,0,1,0); mBtn.BackgroundTransparency = 1; mBtn.Text = tfMode:upper() .. "  ▼"
    mBtn.Font = Enum.Font.GothamBlack; mBtn.TextSize = 8; mBtn.TextColor3 = _C3_WHITE; mBtn.ZIndex = 13
    
    mBtn.MouseEnter:Connect(function() tw(mPill, 0.15, {BackgroundTransparency = 0.2, BackgroundColor3 = C.accent}):Play(); tw(mPillS, 0.15, {Transparency = 0.2}):Play() end)
    mBtn.MouseLeave:Connect(function() tw(mPill, 0.15, {BackgroundTransparency = 0.5, BackgroundColor3 = C.bg3}):Play(); tw(mPillS, 0.15, {Transparency = 0.6}):Play() end)
    
    -- Dropdown Menu (Parented to ScreenGui to avoid clipping)
    local mDrop = Instance.new("Frame", ScreenGui)
    mDrop.Size = UDim2.new(0, 85, 0, #tfModeList * 26 + 4)
    mDrop.BackgroundColor3 = C.bg2; mDrop.Visible = false; mDrop.ZIndex = 11000; corner(mDrop, 8); stroke(mDrop, 1.5, C.accent, 0.3)
    
    -- Sticky Dropdown Position Logic
    RunService.RenderStepped:Connect(function()
        if not mDrop or not mDrop.Parent or not mDrop.Visible then return end
        if not mPill or not mPill.Visible or not mPill.Parent then mDrop.Visible = false; return end
        local abs = mPill.AbsolutePosition
        mDrop.Position = UDim2.new(0, abs.X, 0, abs.Y + 26)
    end)

    for i, m in ipairs(tfModeList) do
        local b = Instance.new("TextButton", mDrop)
        b.Size = UDim2.new(1, -8, 0, 24); b.Position = UDim2.new(0, 4, 0, (i-1)*26 + 2)
        b.BackgroundColor3 = C.bg3; b.BackgroundTransparency = 1; b.Text = m:upper()
        b.Font = Enum.Font.GothamBold; b.TextSize = 8; b.TextColor3 = C.text; b.ZIndex = 11001; corner(b, 4)
        
        b.MouseEnter:Connect(function() tw(b, 0.1, {BackgroundTransparency = 0.7}):Play() end)
        b.MouseLeave:Connect(function() tw(b, 0.1, {BackgroundTransparency = 1}):Play() end)
        
        b.MouseButton1Click:Connect(function()
            tfMode = m; mBtn.Text = tfMode:upper() .. "  ▼"; mDrop.Visible = false
            if tfActive then tfPlayAnim(); sendNotif("Touch Fling", "Mode: " .. tfMode, 1) end
        end)
    end
    mBtn.MouseButton1Click:Connect(function() mDrop.Visible = not mDrop.Visible end)

    -- Speed Slider (Ultra Instinct Edition)
    local sMin, sMax = 10, 250
    local sTrack = Instance.new("Frame", tfRow)
    sTrack.Size = UDim2.new(0, 110, 0, 6); sTrack.Position = UDim2.new(0, 222, 0.5, -3)
    sTrack.BackgroundColor3 = C.bg3; corner(sTrack, 3); stroke(sTrack, 1, C.accent2, 0.5)
    sTrack.ZIndex = 12
    local sFill = Instance.new("Frame", sTrack)
    sFill.Size = UDim2.new((tfSpeed - sMin) / (sMax - sMin), 0, 1, 0); sFill.BackgroundColor3 = C.accent2; corner(sFill, 3); sFill.ZIndex = 13
    local sKnob = Instance.new("Frame", sTrack)
    sKnob.Size = UDim2.new(0, 12, 0, 12); sKnob.Position = UDim2.new((tfSpeed - sMin) / (sMax - sMin), -6, 0.5, -6)
    sKnob.BackgroundColor3 = _C3_WHITE; corner(sKnob, 99); local sKnobS = stroke(sKnob, 1.5, C.accent2, 0); sKnob.ZIndex = 14
    local sVal = Instance.new("TextLabel", tfRow)
    sVal.Size = UDim2.new(0, 24, 0, 14); sVal.Position = UDim2.new(0, 336, 0.5, -7)
    sVal.BackgroundTransparency = 1; sVal.Text = tostring(tfSpeed); sVal.Font = Enum.Font.GothamBold; sVal.TextSize = 10; sVal.TextColor3 = C.text; sVal.ZIndex = 13
    
    local sTargetV = (tfSpeed - sMin) / (sMax - sMin)
    local sVisualV = sTargetV
    local sDrag = false
    local function upTFSlider(pos)
        if not sTrack or not sTrack.Parent then return end
        local rel = math.clamp((pos.X - sTrack.AbsolutePosition.X) / sTrack.AbsoluteSize.X, 0, 1)
        tfSpeed = math.floor(sMin + rel * (sMax - sMin))
        sTargetV = rel; sVal.Text = tostring(tfSpeed)
    end
    
    -- Smooth Lerp Loop
    task.spawn(function()
        while sTrack and sTrack.Parent do
            local dt = task.wait()
            if not movePage.Visible then continue end
            sVisualV = sVisualV + (sTargetV - sVisualV) * math.min(dt * 20, 1)
            sFill.Size = UDim2.new(sVisualV, 0, 1, 0)
            sKnob.Position = UDim2.new(sVisualV, -6, 0.5, -6)
            local p = 0.6 + math.sin(tick()*5)*0.4 -- Pulsing Glow
            sKnob.BackgroundTransparency = 0.1 * p
            if sKnobS then sKnobS.Transparency = 0.2 * p end
        end
    end)

    local sInp = Instance.new("TextButton", sTrack)
    sInp.Size = UDim2.new(1, 80, 1, 60); sInp.Position = UDim2.new(0, -40, 0, -30); sInp.BackgroundTransparency = 1; sInp.Text = ""; sInp.ZIndex = 25
    sInp.InputBegan:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.Touch then
            sDrag = true; upTFSlider(ip.Position)
        end
    end)
    UserInputService.InputChanged:Connect(function(ip)
        if sDrag and (ip.UserInputType == Enum.UserInputType.MouseMovement or ip.UserInputType == Enum.UserInputType.Touch) then
            upTFSlider(ip.Position)
        end
    end)
    UserInputService.InputEnded:Connect(function(ip)
        if ip.UserInputType == Enum.UserInputType.MouseButton1 or ip.UserInputType == Enum.UserInputType.Touch then
            sDrag = false
        end
    end)
end


-- -- Click Teleport --------------------------------------------------------
do
    local _ctActive  = false
    local _ctConn    = nil
    local _ctHoverConn = nil
    local _ctUIS     = UserInputService or _SvcUIS
    local _ctRS      = RunService
    local _ctRP      = RaycastParams.new()
    _ctRP.FilterType = Enum.RaycastFilterType.Exclude

    -- -- Hover-Dot (roter 3D-Part im Workspace) ----------------------------
    local _ctDot = nil
    local function _ctCreateDot()
        if _ctDot and _ctDot.Parent then return end
        _ctDot = Instance.new("Part")
        _ctDot.Name        = "TLClickTeleportDot"
        _ctDot.Shape       = Enum.PartType.Ball
        _ctDot.Size        = Vector3.new(0.5, 0.5, 0.5)
        _ctDot.Material    = Enum.Material.Neon
        _ctDot.Color       = Color3.fromRGB(255, 40, 40)
        _ctDot.Anchored    = true
        _ctDot.CanCollide  = false
        _ctDot.CastShadow  = false
        _ctDot.Transparency = 0.15
        _ctDot.Parent      = workspace
        -- Pulsier-Animation via Heartbeat
        local _dotT = 0
        task.spawn(function()
            while _ctDot and _ctDot.Parent and _ctActive do
                _dotT = _dotT + task.wait()
                local pulse = 0.10 + math.abs(math.sin(_dotT * 3)) * 0.25
                if _ctDot and _ctDot.Parent then
                    _ctDot.Transparency = pulse
                end
            end
        end)
    end

    local function _ctDestroyDot()
        if _ctDot then
            pcall(function() _ctDot:Destroy() end)
            _ctDot = nil
        end
    end

    local function _ctRayFromMouse()
        local char = LocalPlayer.Character
        local cam  = workspace.CurrentCamera
        if not char or not cam then return nil end
        local screenPos
        pcall(function() screenPos = _ctUIS:GetMouseLocation() end)
        if not screenPos then return nil end
        local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
        _ctRP.FilterDescendantsInstances = {char}
        return workspace:Raycast(ray.Origin, ray.Direction * 2000, _ctRP)
    end

    local function _ctStopHover()
        if _ctHoverConn then _ctHoverConn:Disconnect(); _ctHoverConn = nil end
        _ctDestroyDot()
    end

    local function _ctStartHover()
        _ctStopHover()
        _ctCreateDot()
        _ctHoverConn = _ctRS.Heartbeat:Connect(function()
            if not _ctActive then _ctStopHover(); return end
            local result = _ctRayFromMouse()
            if result and _ctDot and _ctDot.Parent then
                local tp = result.Position + result.Normal * 2.5
                _ctDot.CFrame = CFrame.new(tp)
                _ctDot.Visible = true
            elseif _ctDot and _ctDot.Parent then
                _ctDot.Visible = false
            end
        end)
    end

    local function _ctStop()
        _ctActive = false
        if _ctConn then _ctConn:Disconnect(); _ctConn = nil end
        _ctStopHover()
    end

    local function _ctStart()
        _ctStop()
        _ctActive = true
        _ctStartHover()
        _ctConn = _ctUIS.InputBegan:Connect(function(inp, gpe)
            if not _ctActive then return end
            if gpe then return end
            local isMouse = inp.UserInputType == Enum.UserInputType.MouseButton1
            local isTouch = inp.UserInputType == Enum.UserInputType.Touch
            if not isMouse and not isTouch then return end

            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local result
            if isMouse then
                result = _ctRayFromMouse()
            else
                local cam = workspace.CurrentCamera
                if cam then
                    local sp = Vector2.new(inp.Position.X, inp.Position.Y)
                    local ray = cam:ViewportPointToRay(sp.X, sp.Y)
                    _ctRP.FilterDescendantsInstances = {char}
                    result = workspace:Raycast(ray.Origin, ray.Direction * 2000, _ctRP)
                end
            end

            if result then
                local tp = result.Position + result.Normal * 2.5
                pcall(function() hrp.CFrame = CFrame.new(tp) end)
            end
        end)
    end

    sRow(movePage, 280, "Click Teleport", "Movement", C.accent2, false, function(on)
        if on then
            _ctStart()
            sendNotif("Click Teleport", "📍 Klick = Teleport", 2)
        else
            _ctStop()
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        if _ctActive then _ctStart() end
    end)
    
    local flyRow, flySetFn = sRow(movePage, 336, "Fly V4", "Movement System", C.accent, false, function(on)
        if setFly then setFly(on) end
    end)
    -- Sync external toggle (like keybinds) with this row
    _flyPanelSetFn = function(on)
        flySetFn(on)
        if setFly then setFly(on) end
    end
end

local visualPage = Instance.new("Frame", sSubArea)
visualPage.BackgroundTransparency = 1; visualPage.BorderSizePixel = 0
visualPage.Visible = false
local espRow, espSetFn = sRow(visualPage, 0, "ESP / Highlight", "Visual", C.accent2, false, setESP)
do
local PILL_W, PILL_H = 110, 26
local SWATCH_SZ      = 12
local espColorPill   = Instance.new("Frame", espRow)
espColorPill.Size    = UDim2.new(0, PILL_W, 0, PILL_H)
espColorPill.Position= UDim2.new(0, 210, 0.5, -13)
espColorPill.BackgroundColor3 = C.bg2
espColorPill.BackgroundTransparency = 0.1
espColorPill.BorderSizePixel = 0
espColorPill.ZIndex  = 7
corner(espColorPill, 8)
stroke(espColorPill, 1, C.accent2, 0.45)
local espSwatch = Instance.new("Frame", espColorPill)
espSwatch.Size     = UDim2.new(0, SWATCH_SZ, 0, SWATCH_SZ)
espSwatch.Position = UDim2.new(0, 5, 0.5, -SWATCH_SZ/2)
espSwatch.BackgroundColor3 = espCurrentColor()
espSwatch.BorderSizePixel  = 0
corner(espSwatch, 3)
local espColLbl = Instance.new("TextLabel", espColorPill)
espColLbl.Size               = UDim2.new(1, -(SWATCH_SZ+28), 1, 0)
espColLbl.Position           = UDim2.new(0, SWATCH_SZ+10, 0, 0)
espColLbl.BackgroundTransparency = 1
espColLbl.Text               = ESP_COLORS[espColorIdx].name
espColLbl.Font               = Enum.Font.GothamBold
espColLbl.TextSize           = 10
espColLbl.TextColor3         = C.text
espColLbl.TextXAlignment     = Enum.TextXAlignment.Left
local espArrow = Instance.new("ImageLabel", espColorPill)
espArrow.Size              = UDim2.new(0, 16, 0, 16)
espArrow.Position          = UDim2.new(1, -20, 0.5, -8)
espArrow.BackgroundTransparency = 1
espArrow.Image             = "rbxassetid://115943405523448"
espArrow.ImageColor3       = _C3_WHITE
espArrow.ImageTransparency = 0
espArrow.ScaleType         = Enum.ScaleType.Fit
espArrow.BorderSizePixel   = 0
espArrow.ZIndex            = 8
local ITEM_H     = 24
local DD_VISIBLE = 4
local espDdFrame = Instance.new("Frame", espColorPill)
espDdFrame.Size              = UDim2.new(0, PILL_W, 0, 0)
espDdFrame.Position          = UDim2.new(0, 0, 1, 4)
espDdFrame.BackgroundColor3  = C.bg2
espDdFrame.BackgroundTransparency = 0.05
espDdFrame.BorderSizePixel   = 0
espDdFrame.ClipsDescendants  = true
espDdFrame.ZIndex            = 20
corner(espDdFrame, 8)
stroke(espDdFrame, 1, C.accent2, 0.4)
local espDdScroll = Instance.new("ScrollingFrame", espDdFrame)
espDdScroll.Size                 = UDim2.new(1, 0, 1, 0)
espDdScroll.BackgroundTransparency = 1
espDdScroll.BorderSizePixel      = 0
espDdScroll.ScrollBarThickness   = 6
espDdScroll.ScrollBarImageColor3 = C.accent2
espDdScroll.ScrollBarImageTransparency = 0
espDdScroll.ScrollingDirection   = Enum.ScrollingDirection.Y
espDdScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
espDdScroll.ElasticBehavior      = Enum.ElasticBehavior.Never
espDdScroll.ZIndex               = 21
local espDdList = Instance.new("UIListLayout", espDdScroll)
espDdList.SortOrder = _ENUM_SORT_ORDER_LAYOUT
espDdList.Padding   = UDim.new(0, 2)
local ddPad = Instance.new("UIPadding", espDdScroll)
ddPad.PaddingLeft = UDim.new(0, 4); ddPad.PaddingRight = UDim.new(0, 4)
ddPad.PaddingTop  = UDim.new(0, 3); ddPad.PaddingBottom = UDim.new(0, 3)
local ddOpen = false
for i, entry in ipairs(ESP_COLORS) do
local item = Instance.new("TextButton", espDdScroll)
item.Size              = UDim2.new(1, -8, 0, ITEM_H)
item.BackgroundColor3  = C.bg3
item.BackgroundTransparency = 0.85
item.BorderSizePixel   = 0
item.Text              = ""
item.ZIndex            = 21
item.LayoutOrder       = i
corner(item, 6)
local sw = Instance.new("Frame", item)
sw.Size              = UDim2.new(0, 10, 0, 10)
sw.Position          = UDim2.new(0, 5, 0.5, -5)
sw.BackgroundColor3  = entry.color
sw.BorderSizePixel   = 0
sw.ZIndex            = 22
corner(sw, 3)
local nl = Instance.new("TextLabel", item)
nl.Size              = UDim2.new(1, -22, 1, 0)
nl.Position          = UDim2.new(0, 19, 0, 0)
nl.BackgroundTransparency = 1
nl.Text              = entry.name
nl.Font              = Enum.Font.GothamBold
nl.TextSize          = 10
nl.TextColor3        = C.text
nl.TextXAlignment    = Enum.TextXAlignment.Left
nl.ZIndex            = 22
item.MouseEnter:Connect(function()
_playHoverSound()
twP(item, 0.08, {BackgroundTransparency=0.5})
end)
item.MouseLeave:Connect(function()
twP(item, 0.08, {BackgroundTransparency=0.85})
end)
item.MouseButton1Click:Connect(function()
espColorIdx = i
espSwatch.BackgroundColor3 = entry.color
espColLbl.Text = entry.name
_saveCache("esp_color", {idx = espColorIdx})
--- * FIX: Alle Texte zurücksetzen auf C.text
for _, ch in ipairs(espDdScroll:GetChildren()) do
if ch:IsA("TextButton") then
local l = ch:FindFirstChildOfClass("TextLabel")
if l then l.TextColor3 = C.text end
end
end
--- * NUR der aktuelle Text wird farbig (nicht wie alle anderen)
-- * NUR der aktuelle Text wird farbig (nicht wie alle anderen)
nl.TextColor3 = entry.color
refreshESPColor()
twP(espDdFrame, 0.15, {Size=UDim2.new(0,PILL_W,0,0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
twP(espArrow, 0.1, {ImageTransparency=0})
ddOpen = false
end)
item.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        espColorIdx = i
        espSwatch.BackgroundColor3 = entry.color
        espColLbl.Text = entry.name
        _saveCache("esp_color", {idx = espColorIdx})
        -- * FIX: Alle Texte zurücksetzen auf C.text
        for _, ch in ipairs(espDdScroll:GetChildren()) do
            if ch:IsA("TextButton") then
                local l = ch:FindFirstChildOfClass("TextLabel")
                if l then l.TextColor3 = C.text end
            end
        end
        -- * NUR der aktuelle Text wird farbig (nicht wie alle anderen)
        nl.TextColor3 = entry.color
        refreshESPColor()
        twP(espDdFrame, 0.15, {Size=UDim2.new(0,PILL_W,0,0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        twP(espArrow, 0.1, {ImageTransparency=0})
        ddOpen = false
    end
end)
end
local TOTAL_CANVAS_H = #ESP_COLORS * (ITEM_H + 2) + 6
local TOTAL_DD_H     = math.min(DD_VISIBLE, #ESP_COLORS) * (ITEM_H + 2) + 6
espDdScroll.CanvasSize = UDim2.new(0, 0, 0, TOTAL_CANVAS_H)
local espPillBtn = Instance.new("TextButton", espColorPill)
espPillBtn.Size  = UDim2.new(1, 0, 1, 0)
espPillBtn.BackgroundTransparency = 1
espPillBtn.Text  = ""
espPillBtn.ZIndex = 9
espPillBtn.MouseButton1Click:Connect(function()
ddOpen = not ddOpen
if ddOpen then
espDdFrame.Size = UDim2.new(0, PILL_W, 0, 0)
twP(espDdFrame, 0.18, {Size=UDim2.new(0,PILL_W,0,TOTAL_DD_H)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
twP(espArrow, 0.1, {ImageTransparency=0.4})
else
twP(espDdFrame, 0.13, {Size=UDim2.new(0,PILL_W,0,0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
twP(espArrow, 0.1, {ImageTransparency=0})
end
end)
espPillBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        ddOpen = not ddOpen
        if ddOpen then
            espDdFrame.Size = UDim2.new(0, PILL_W, 0, 0)
            twP(espDdFrame, 0.18, {Size=UDim2.new(0,PILL_W,0,TOTAL_DD_H)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            twP(espArrow, 0.1, {ImageTransparency=0.4})
        else
            twP(espDdFrame, 0.13, {Size=UDim2.new(0,PILL_W,0,0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            twP(espArrow, 0.1, {ImageTransparency=0})
        end
    end
end)
end
visualPage.Size = UDim2.new(1, 0, 0, 120)
local sonstigePage = Instance.new("Frame", sSubArea)
sonstigePage.BackgroundTransparency = 1; sonstigePage.BorderSizePixel = 0
sonstigePage.Visible = false
-- -- UIListLayout: stapelt Misc-Einträge automatisch -----------------------
local miscLayout = Instance.new("UIListLayout", sonstigePage)
miscLayout.SortOrder     = _ENUM_SORT_ORDER_LAYOUT
miscLayout.FillDirection = Enum.FillDirection.Vertical
miscLayout.Padding       = UDim.new(0, 0)

-- Shared tween slots – verhindert conflicting tweens auf p/sSubArea
local _sPanelTw = {}  -- {p=tween, sub=tween}
local function _resizeScriptsPanel(contentH, easeStyle, easeDir, duration)
    local HEADER_OFF = 56
    local newH    = HEADER_OFF + (S_CARD_H + 12) + contentH + 32
    local scrollH = newH - HEADER_OFF
    -- cancel laufende tweens
    if _sPanelTw.p   then pcall(function() _sPanelTw.p:Cancel()   end) end
    if _sPanelTw.sub then pcall(function() _sPanelTw.sub:Cancel() end) end
    p.ClipsDescendants = true; c.ClipsDescendants = true
    local dur = duration or 0.22
    local sty = easeStyle or Enum.EasingStyle.Quart
    local dir = easeDir   or Enum.EasingDirection.Out
    _sPanelTw.sub = twP(sSubArea, dur, {Size = UDim2.new(1, 0, 0, contentH + 16)}, sty, dir)
    _sPanelTw.p   = twP(p,        dur, {Size = UDim2.new(0, PANEL_W, 0, newH)},    sty, dir)
    c.Size       = UDim2.new(1, 0, 0, scrollH)
    c.CanvasSize = UDim2.new(0, 0, 0, math.max(contentH + 16, scrollH))
end

-- Panel-Höhe nach Ordner-Toggle neu berechnen (Misc)
local function updateMiscSize()
    local H = miscLayout.AbsoluteContentSize.Y
    sonstigePage.Size = UDim2.new(1, 0, 0, math.max(H, 1))
    if sActiveCat ~= "Misc" then return end
    _resizeScriptsPanel(H)
end

-- Generic panel resize – called by any folder open/close in any subpage
local function updateActiveCatSize()
    if not sActiveCat then return end
    local pg = sSubPages and sSubPages[sActiveCat]
    if not pg then return end
    task.defer(function()
        local pgH = pg.AbsoluteSize.Y
        if pgH < 1 then pgH = pg.Size.Y.Offset end
        _resizeScriptsPanel(pgH)
    end)
end

-- -- Ordner-Funktion für Misc ----------------------------------------------
-- Gibt (container, content, addRow) zurück.
-- addRow(label, badge, badgeCol, initOn, onToggle) → row, setFn, getFn
local FOLDER_HDR_H = 40
local function makeMiscFolder(folderName, folderIcon, accentCol, layoutOrder, pageParent)
    local isOpen = false
    local headerVisible = true
    local childrenH = 0
    local childCount = 0

    local container = Instance.new("Frame", pageParent or sonstigePage)
    container.Size                   = UDim2.new(1, 0, 0, FOLDER_HDR_H)
    container.BackgroundTransparency = 1
    container.BorderSizePixel        = 0
    container.LayoutOrder            = layoutOrder
    container.ClipsDescendants       = false

    local hdr = Instance.new("Frame", container)
    hdr.Size             = UDim2.new(1, 0, 0, FOLDER_HDR_H)
    hdr.Position         = UDim2.new(0, 0, 0, 0)
    hdr.BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)
    hdr.BackgroundTransparency = 0
    hdr.BorderSizePixel  = 0
    corner(hdr, 10)

    local hdrDot = Instance.new("Frame", hdr)
    hdrDot.Size             = UDim2.new(0, 3, 0, FOLDER_HDR_H - 16); hdrDot.Visible = false
    hdrDot.Position         = UDim2.new(0, 0, 0.5, -(FOLDER_HDR_H - 16) / 2)
    hdrDot.BackgroundColor3 = _themePanelColor(accentCol, C.accent)
    hdrDot.BackgroundTransparency = 0.4
    hdrDot.BorderSizePixel  = 0
    corner(hdrDot, 99)

    local iconLbl = Instance.new("TextLabel", hdr)
    iconLbl.Size                 = UDim2.new(0, 20, 0, 20)
    iconLbl.Position             = UDim2.new(0, 12, 0.5, -10)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text                 = folderIcon
    iconLbl.Font                 = Enum.Font.GothamBlack
    iconLbl.TextSize             = 14
    iconLbl.TextColor3           = _themePanelColor(accentCol, C.accent)
    iconLbl.TextXAlignment       = Enum.TextXAlignment.Center

    local nameLbl = Instance.new("TextLabel", hdr)
    nameLbl.Size             = UDim2.new(1, -78, 0, 18)
    nameLbl.Position         = UDim2.new(0, 38, 0.5, -9)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = folderName
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextColor3       = C.text or Color3.fromRGB(210, 255, 220)
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left

    local badge = Instance.new("Frame", hdr)
    badge.Size             = UDim2.new(0, 18, 0, 14)
    badge.Position         = UDim2.new(1, -50, 0.5, -7)
    badge.BackgroundColor3 = _themePanelColor(accentCol, C.accent)
    badge.BackgroundTransparency = 0.78
    badge.BorderSizePixel  = 0
    corner(badge, 99)
    local badgeLbl = Instance.new("TextLabel", badge)
    badgeLbl.Size                 = UDim2.new(1, 0, 1, 0)
    badgeLbl.BackgroundTransparency = 1
    badgeLbl.Text                 = "0"
    badgeLbl.Font                 = Enum.Font.GothamBlack
    badgeLbl.TextSize             = 9
    badgeLbl.TextColor3           = _themePanelColor(accentCol, C.accent)
    badgeLbl.TextXAlignment       = Enum.TextXAlignment.Center

    local chevron = Instance.new("TextLabel", hdr)
    chevron.Size                 = UDim2.new(0, 20, 0, 20)
    chevron.Position             = UDim2.new(1, -26, 0.5, -10)
    chevron.BackgroundTransparency = 1
    chevron.Text                 = "▼"
    chevron.Font                 = Enum.Font.GothamBlack
    chevron.TextSize             = 10
    chevron.TextColor3           = _themePanelColor(accentCol, C.accent)
    chevron.TextXAlignment       = Enum.TextXAlignment.Center

    local divider = Instance.new("Frame", container)
    divider.Size             = UDim2.new(1, -16, 0, 1)
    divider.Position         = UDim2.new(0, 8, 0, FOLDER_HDR_H)
    divider.BackgroundColor3 = _themePanelColor(accentCol, C.accent)
    divider.BackgroundTransparency = 0.82
    divider.BorderSizePixel  = 0
    divider.Visible          = false

    local content = Instance.new("Frame", container)
    content.Size                   = UDim2.new(1, 0, 0, 0)
    content.Position               = UDim2.new(0, 0, 0, FOLDER_HDR_H + 1)
    content.BackgroundTransparency = 1
    content.BorderSizePixel        = 0
    content.ClipsDescendants       = true
    content.Visible                = false

    local btn = Instance.new("TextButton", hdr)
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex  = 6

    local function applyFolderTheme(newT)
        local accent = (newT and newT.accent) or (C.accent or _themePanelColor(accentCol, C.accent))
        local textCol = (newT and newT.text) or (C.text or Color3.fromRGB(210, 255, 220))
        hdr.BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)
        hdrDot.BackgroundColor3 = accent
        iconLbl.TextColor3 = accent
        nameLbl.TextColor3 = textCol
        badge.BackgroundColor3 = accent
        badgeLbl.TextColor3 = accent
        chevron.TextColor3 = accent
        divider.BackgroundColor3 = accent
    end

    local function applyState()
        local effectiveOpen = isOpen or not headerVisible
        local baseH = headerVisible and FOLDER_HDR_H or 0
        local contentH = effectiveOpen and childrenH or 0

        hdr.Visible = headerVisible
        btn.Visible = headerVisible
        btn.Active = headerVisible
        content.Position = UDim2.new(0, 0, 0, headerVisible and (FOLDER_HDR_H + 1) or 0)
        divider.Position = UDim2.new(0, 8, 0, headerVisible and FOLDER_HDR_H or 0)
        divider.Visible = headerVisible and effectiveOpen and childrenH > 0
        content.Visible = effectiveOpen and childrenH > 0
        content.Size = UDim2.new(1, 0, 0, contentH)
        container.Size = UDim2.new(1, 0, 0, baseH + contentH)
        chevron.Rotation = effectiveOpen and 90 or 0
        applyFolderTheme()
    end

    btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
        if headerVisible then
            twP(hdr, 0.08, {BackgroundColor3 = C.bg3 or Color3.fromRGB(7, 22, 10)})
        end
    end)
    btn.MouseLeave:Connect(function()
        if headerVisible then
            twP(hdr, 0.08, {BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)})
        end
    end)

    local _folderAnimating = false
    btn.MouseButton1Click:Connect(function()
        if not headerVisible or _folderAnimating then return end
        isOpen = not isOpen
        if isOpen then
            _folderAnimating = true
            content.Size    = UDim2.new(1, 0, 0, 0)
            content.Visible = true
            divider.Visible = true
            container.Size = UDim2.new(1, 0, 0, FOLDER_HDR_H + childrenH)
            twP(content, 0.24, {Size = UDim2.new(1, 0, 0, childrenH)},
                Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            twP(chevron, 0.20, {Rotation = 90},  Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            task.delay(0.26, function()
                _folderAnimating = false
                applyFolderTheme()
            end)
        else
            _folderAnimating = true
            twP(content, 0.20, {Size = UDim2.new(1, 0, 0, 0)},
                Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            twP(chevron, 0.18, {Rotation = 0},  Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            task.delay(0.22, function()
                container.Size  = UDim2.new(1, 0, 0, FOLDER_HDR_H)
                content.Visible = false
                divider.Visible = false
                _folderAnimating = false
                applyFolderTheme()
            end)
        end
    end)

    local function addRow(label, badge2, badgeCol, initOn, onToggle)
        local ROW_H    = 46
        local PAD_H    = 6
        local PAD_SIDE = 8
        local yPos = PAD_H + childCount * (ROW_H + 4)
        local row, setFn, getFn = cleanRow(content, yPos, label, badge2, _themePanelColor(badgeCol, C.accent), initOn, onToggle)
        row.Size     = UDim2.new(1, -PAD_SIDE * 2, 0, ROW_H)
        row.Position = UDim2.new(0, PAD_SIDE, 0, yPos)
        childCount  = childCount + 1
        childrenH   = PAD_H + childCount * (ROW_H + 4) + PAD_H
        badgeLbl.Text = tostring(childCount)
        applyState()
        return row, setFn, getFn
    end

    if _panelColorHooks then
        _panelColorHooks[#_panelColorHooks+1] = function(newT)
            pcall(applyFolderTheme, newT)
        end
    end
    applyState()

    local api = {
        setOpen = function(openState)
            isOpen = openState == true
            applyState()
        end,
        setHeaderVisible = function(show)
            headerVisible = show ~= false
            if not headerVisible then
                isOpen = true
            end
            applyState()
        end,
        setActive = function(active)
            container.Visible = active ~= false
            if container.Visible then
                applyState()
            else
                content.Visible = false
                divider.Visible = false
                container.Size = UDim2.new(1, 0, 0, 0)
            end
        end,
        refresh = applyState,
        getHeight = function()
            local baseH = headerVisible and FOLDER_HDR_H or 0
            return baseH + ((isOpen or not headerVisible) and childrenH or 0)
        end,
    }

    return container, content, addRow, api
end

-- Game-Script-Panels (Misc): flache Karte ohne Akkordeon-Header – Umschalten nur über Segmentleiste
-- Max. 5 Zeilen sichtbar, weiterer Inhalt im ScrollingFrame (saubere Scrollbar)
local function makeMiscGamePanel(accentCol, layoutOrder, pageParent)
    local childrenH = 0
    local childCount = 0

    local ROW_H    = 46
    local PAD_H    = 6
    local ROW_GAP  = 4
    local PAD_SIDE = 8
    local MAX_VISIBLE_ROWS = 5
    local maxScrollH = PAD_H + MAX_VISIBLE_ROWS * (ROW_H + ROW_GAP) + PAD_H

    local container = Instance.new("Frame", pageParent or sonstigePage)
    container.Size = UDim2.new(1, 0, 0, 0)
    container.BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)
    container.BackgroundTransparency = 0.14
    container.BorderSizePixel = 0
    container.LayoutOrder = layoutOrder
    container.ClipsDescendants = true
    corner(container, 10)

    local scroll = Instance.new("ScrollingFrame", container)
    scroll.Name = "GameScriptScroll"
    scroll.Size = UDim2.new(1, -16, 0, 0)
    scroll.Position = UDim2.new(0, 8, 0, 4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ClipsDescendants = true
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ScrollBarThickness = 5
    scroll.ScrollBarImageColor3 = _themePanelColor(accentCol, C.accent)
    scroll.ScrollBarImageTransparency = 0.42
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
    scroll.ScrollingEnabled = false
    scroll.ElasticBehavior = Enum.ElasticBehavior.Never

    local content = Instance.new("Frame", scroll)
    content.Size = UDim2.new(1, 0, 0, 0)
    content.Position = UDim2.new(0, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0

    local function applyFolderTheme(newT)
        local accent = (newT and newT.accent) or (C.accent or _themePanelColor(accentCol, C.accent))
        container.BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)
        scroll.ScrollBarImageColor3 = _themePanelColor(accentCol, accent)
    end

    local function applyState()
        local ch = childrenH
        local canvasH = math.max(ch, 1)
        content.Size = UDim2.new(1, 0, 0, canvasH)
        scroll.CanvasSize = UDim2.new(0, 0, 0, canvasH)
        local vh = (ch <= 0) and 0 or math.min(ch, maxScrollH)
        scroll.Size = UDim2.new(1, -16, 0, vh)
        scroll.ScrollingEnabled = ch > maxScrollH
        if ch <= maxScrollH then
            scroll.CanvasPosition = Vector2.new(0, 0)
        end
        container.Size = UDim2.new(1, 0, 0, (vh > 0) and (vh + 8) or 0)
    end

    local function addRow(label, badge2, badgeCol, initOn, onToggle)
        local yPos = PAD_H + childCount * (ROW_H + ROW_GAP)
        local row, setFn, getFn = cleanRow(content, yPos, label, badge2, _themePanelColor(badgeCol, C.accent), initOn, onToggle)
        row.Size     = UDim2.new(1, -PAD_SIDE * 2, 0, ROW_H)
        row.Position = UDim2.new(0, PAD_SIDE, 0, yPos)
        childCount  = childCount + 1
        childrenH   = PAD_H + childCount * (ROW_H + ROW_GAP) + PAD_H
        applyState()
        return row, setFn, getFn
    end

    if _panelColorHooks then
        _panelColorHooks[#_panelColorHooks+1] = function(newT)
            pcall(applyFolderTheme, newT)
        end
    end
    applyState()

    local api = {
        setOpen = function() end,
        setHeaderVisible = function() end,
        setActive = function(active)
            container.Visible = active ~= false
            if container.Visible then
                scroll.Visible = true
                content.Visible = true
                applyState()
            else
                scroll.Visible = false
                content.Visible = false
                container.Size = UDim2.new(1, 0, 0, 0)
            end
        end,
        refresh = applyState,
        getHeight = function()
            if childrenH <= 0 then return 0 end
            return math.min(childrenH, maxScrollH) + 8
        end,
    }

    return container, content, addRow, api
end
-- ------------------------------------------------------------------
-- Combat Page (Aimbot)
-- ------------------------------------------------------------------
local combatPage = Instance.new("ScrollingFrame", sSubArea)
combatPage.BackgroundTransparency = 1; combatPage.BorderSizePixel = 0
combatPage.Visible = false
combatPage.ScrollBarThickness = 4
combatPage.ScrollBarImageColor3 = C.accent or Color3.fromRGB(200, 200, 200)
combatPage.ScrollingDirection = Enum.ScrollingDirection.Y
combatPage.CanvasSize = UDim2.new(0, 0, 0, 0)
combatPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
combatPage.ElasticBehavior = Enum.ElasticBehavior.Never
combatPage.ClipsDescendants = true

local combatLayout = Instance.new("UIListLayout", combatPage)
combatLayout.SortOrder     = _ENUM_SORT_ORDER_LAYOUT
combatLayout.FillDirection = Enum.FillDirection.Vertical
combatLayout.Padding       = UDim.new(0, 0)
combatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local H = combatLayout.AbsoluteContentSize.Y
    if H > 1 then
        combatPage.Size = UDim2.new(1, 0, 0, math.min(H, 350))
        if typeof(updateActiveCatSize) == "function" then
            updateActiveCatSize()
        end
    end
end)

local combatContainer, combatContent, combatAddRow = makeMiscFolder("Combat Tools", "TL", C.red, 1, combatPage)

do
-- -------------------------------------------------------------------------------
-- * ADVANCED AIMBOT SYSTEM v2.0                                ◈
-- * Features: Silent Aim, Aimlock, Wall Check, Prediction, Auto-Fire, FOV        ◈
-- +-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Aimbot Configuration
local AimbotConfig = {
    Enabled = false,
    SilentAim = false,
    Aimlock = false,
    WallCheck = false,
    TeamCheck = false,
    VisibilityCheck = false,
    Prediction = 0.165,
    Smoothness = 0.08,
    FOV = 120,
    AimPart = "Head",
    AutoFire = false,
    TriggerBot = false,
    MultiPoint = false,
    AutoAimDistance = 1000,
    CurrentTarget = nil,
    LastTargetTime = 0,
    TargetLockTime = 2.5
}

-- Drawing API for FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 140)
FOVCircle.Transparency = 0.7
FOVCircle.Filled = false
FOVCircle.NumSides = 64

-- Target Line
local TargetLine = Drawing.new("Line")
TargetLine.Visible = false
TargetLine.Thickness = 2
TargetLine.Color = Color3.fromRGB(255, 0, 68)
TargetLine.Transparency = 0.8

-- Aimbot Cache
local AimbotCache = {
    LastAimPosition = nil,
    TargetVelocity = Vector3.zero,
    TargetAcceleration = Vector3.zero,
    LastUpdate = tick()
}

-- Utility Functions
local function GetCharacter(player)
    return player and player.Character
end

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetAimPart(character)
    if not character then return nil end
    if AimbotConfig.AimPart == "Head" then
        return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    elseif AimbotConfig.AimPart == "Torso" then
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    elseif AimbotConfig.AimPart == "Random" then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        return character:FindFirstChild(parts[math.random(1, #parts)])
    end
    return character:FindFirstChild(AimbotConfig.AimPart) or character:FindFirstChild("HumanoidRootPart")
end

local function IsPlayerAlive(player)
    local char = GetCharacter(player)
    local hum = GetHumanoid(char)
    return hum and hum.Health > 0
end

local function IsTeammate(player)
    if not AimbotConfig.TeamCheck then return false end
    return player.Team == LocalPlayer.Team
end

local function IsVisible(targetPart)
    if not AimbotConfig.WallCheck then return true end
    if not targetPart then return false end
    
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * 1000
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, raycastParams)
    if not result then return true end
    
    return false
end

local function PredictPosition(position, velocity)
    local timeToHit = AimbotConfig.Prediction
    return position + (velocity * timeToHit)
end

local function GetTargetPosition(targetPart)
    if not targetPart then return nil end
    
    local position = targetPart.Position
    local velocity = Vector3.zero
    
    -- Calculate velocity
    local rootPart = targetPart.Parent:FindFirstChild("HumanoidRootPart")
    if rootPart then
        if AimbotCache.LastPosition then
            velocity = (rootPart.Position - AimbotCache.LastPosition) / math.max(tick() - AimbotCache.LastUpdate, 0.001)
        end
        AimbotCache.LastPosition = rootPart.Position
        AimbotCache.LastUpdate = tick()
    end
    
    -- Apply prediction
    if AimbotConfig.Prediction > 0 then
        position = PredictPosition(position, velocity)
    end
    
    -- MultiPoint: Add slight offset for multiple hit points
    if AimbotConfig.MultiPoint then
        local offset = Vector3.new(
            math.sin(tick() * 10) * 0.5,
            math.cos(tick() * 8) * 0.3,
            0
        )
        position = position + offset
    end
    
    return position
end

local function GetDistanceToMouse(worldPosition)
    local screenPosition, onScreen = Camera:WorldToViewportPoint(worldPosition)
    if not onScreen then return math.huge end
    
    local mousePos = UserInputService:GetMouseLocation()
    return (Vector2.new(screenPosition.X, screenPosition.Y) - mousePos).Magnitude
end

local function GetBestTarget()
    local bestTarget = nil
    local bestDistance = AimbotConfig.FOV
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsPlayerAlive(player) then continue end
        if IsTeammate(player) then continue end
        
        local character = GetCharacter(player)
        local targetPart = GetAimPart(character)
        if not targetPart then continue end
        
        -- Visibility check
        if not IsVisible(targetPart) then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        -- Check if within FOV
        local distanceFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if distanceFromCenter > AimbotConfig.FOV then continue end
        
        -- Get distance to player
        local rootPart = GetRootPart(character)
        if not rootPart then continue end
        
        local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and 
                         (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude) or 0
        
        if distance > AimbotConfig.AutoAimDistance then continue end
        
        -- Prioritize closest to crosshair
        if distanceFromCenter < bestDistance then
            bestDistance = distanceFromCenter
            bestTarget = {
                Player = player,
                Part = targetPart,
                Position = targetPart.Position,
                ScreenPosition = Vector2.new(screenPos.X, screenPos.Y),
                Distance = distance,
                Health = GetHumanoid(character) and GetHumanoid(character).Health or 100
            }
        end
    end
    
    return bestTarget
end

local function SmoothAim(targetPosition)
    if not targetPosition then return end
    
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
    
    local smoothness = math.clamp(AimbotConfig.Smoothness, 0.01, 1)
    local newCFrame = currentCFrame:Lerp(targetCFrame, 1 - smoothness)
    
    Camera.CFrame = newCFrame
end

local function SilentAim(targetPosition)
    if not targetPosition then return nil end
    
    -- Returns modified position for silent aim
    return targetPosition
end

local function PerformAimbot()
    if not AimbotConfig.Enabled then
        AimbotConfig.CurrentTarget = nil
        FOVCircle.Visible = false
        TargetLine.Visible = false
        return
    end
    
    -- Update FOV Circle
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius = AimbotConfig.FOV
    FOVCircle.Visible = true
    
    -- Target locking logic
    local target = nil
    if AimbotConfig.CurrentTarget then
        local player = AimbotConfig.CurrentTarget.Player
        if player and player.Parent and IsPlayerAlive(player) and tick() - AimbotConfig.LastTargetTime < AimbotConfig.TargetLockTime then
            local char = GetCharacter(player)
            local part = GetAimPart(char)
            if part and IsVisible(part) then
                target = {
                    Player = player,
                    Part = part,
                    Position = part.Position
                }
            end
        end
    end
    
    -- Get new target if needed
    if not target then
        target = GetBestTarget()
        if target then
            AimbotConfig.CurrentTarget = target
            AimbotConfig.LastTargetTime = tick()
        end
    end
    
    if target and target.Part then
        local targetPosition = GetTargetPosition(target.Part)
        
        if targetPosition then
            -- Draw target line
            local screenPos = Camera:WorldToViewportPoint(targetPosition)
            local mousePos = UserInputService:GetMouseLocation()
            TargetLine.From = mousePos
            TargetLine.To = Vector2.new(screenPos.X, screenPos.Y)
            TargetLine.Visible = true
            
            -- Silent Aim (for hit registration)
            if AimbotConfig.SilentAim then
                SilentAim(targetPosition)
            end
            
            -- Aimlock (camera movement)
            if AimbotConfig.Aimlock then
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or AimbotConfig.AutoFire then
                    SmoothAim(targetPosition)
                end
            end
            
            -- Auto Fire logic
            if AimbotConfig.AutoFire and not AimbotConfig.TriggerBot then
                -- Automatically click when target is in sight
                local distToTarget = GetDistanceToMouse(targetPosition)
                if distToTarget < 20 then -- Within 20 pixels of target
                    -- Virtual input would go here
                end
            end
        end
    else
        TargetLine.Visible = false
        AimbotConfig.CurrentTarget = nil
    end
end

-- RenderStepped Connection
local AimbotConnection = nil

local function StartAimbot()
    if AimbotConnection then return end
    
    AimbotConnection = RunService.RenderStepped:Connect(function()
        PerformAimbot()
    end)
end

local function StopAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
    
    FOVCircle.Visible = false
    TargetLine.Visible = false
    AimbotConfig.CurrentTarget = nil
end

-- TriggerBot for automatic shooting
local TriggerBotConnection = nil

local function StartTriggerBot()
    if TriggerBotConnection then return end
    
    TriggerBotConnection = RunService.Heartbeat:Connect(function()
        if not AimbotConfig.TriggerBot or not AimbotConfig.Enabled then return end
        
        local target = GetBestTarget()
        if target and target.Distance < 50 then
            -- Mouse is over target, trigger click
            -- This would use virtual input in a real implementation
        end
    end)
end

local function StopTriggerBot()
    if TriggerBotConnection then
        TriggerBotConnection:Disconnect()
        TriggerBotConnection = nil
    end
end

-- Combat UI Integration
local aimlockToggleGetFn
do
    combatAddRow("Aimbot Master", "Combat", C.red, false, function(on)
        AimbotConfig.Enabled = on
        if on then
            StartAimbot()
            sendNotif("Aimbot", "Aimbot ACTIVATED - Hold RMB to aim", 3)
        else
            StopAimbot()
            sendNotif("Aimbot", "Aimbot DEACTIVATED", 2)
        end
    end)

    combatAddRow("Silent Aim", "Combat", C.red, false, function(on)
        AimbotConfig.SilentAim = on
        sendNotif("Aimbot", "Silent Aim " .. (on and "ON" or "OFF"), 2)
    end)

    local _, __, getFn = combatAddRow("Aimlock", "Combat", C.red, false, function(on)
        AimbotConfig.Aimlock = on
        sendNotif("Aimbot", "Aimlock " .. (on and "ON" or "OFF"), 2)
    end)
    aimlockToggleGetFn = getFn

    combatAddRow("Wall Check", "Combat", C.red, false, function(on)
        AimbotConfig.WallCheck = on
    end)

    combatAddRow("Team Check", "Combat", C.red, false, function(on)
        AimbotConfig.TeamCheck = on
    end)

    combatAddRow("Auto Fire", "Combat", C.red, false, function(on)
        AimbotConfig.AutoFire = on
    end)

    combatAddRow("Trigger Bot", "Combat", C.red, false, function(on)
        AimbotConfig.TriggerBot = on
        if on then StartTriggerBot() else StopTriggerBot() end
    end)
end

-- Slider Scope (IIFE to fix register limit) – Fling-Style Design
;(function()
    local _corner = function(obj, r) local c = Instance.new("UICorner", obj); c.CornerRadius = UDim.new(0, r or 8); return c end
    local _stroke = function(obj, col, th, tr) local s = _makeDummyStroke(obj); s.Color = col or (C.bg3 or Color3.fromRGB(60,60,70)); s.Thickness = th or 1; s.Transparency = tr or 0.3; return s end
    
    -- FOV Slider – Fling Style
    local fovRow = Instance.new("Frame", combatPage)
    fovRow.Size = UDim2.new(1, 0, 0, 54); fovRow.BackgroundColor3 = C.bg2 or Color3.fromRGB(40,40,48)
    fovRow.BackgroundTransparency = 0; fovRow.BorderSizePixel = 0; _corner(fovRow, 12)
    local fovRowS = _stroke(fovRow, C.bg3, 1, 0.3)
    local fovRowDot = Instance.new("Frame", fovRow)
    fovRowDot.Size = UDim2.new(0, 3, 0, 26); fovRowDot.Visible = false; fovRowDot.Position = UDim2.new(0, 0, 0.5, -13)
    fovRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220, 60, 60); fovRowDot.BackgroundTransparency = 0.4
    fovRowDot.BorderSizePixel = 0; _corner(fovRowDot, 99)
    local fovLbl = Instance.new("TextLabel", fovRow)
    fovLbl.Size = UDim2.new(0, 100, 0, 24); fovLbl.Position = UDim2.new(0, 16, 0, 6)
    fovLbl.BackgroundTransparency = 1; fovLbl.Text = "FOV Size"; fovLbl.Font = Enum.Font.GothamBold
    fovLbl.TextSize = 13; fovLbl.TextColor3 = C.text or Color3.fromRGB(240,240,240); fovLbl.TextXAlignment = Enum.TextXAlignment.Left
    local fovVal = Instance.new("TextLabel", fovRow)
    fovVal.Size = UDim2.new(0, 50, 0, 20); fovVal.Position = UDim2.new(1, -58, 0, 8)
    fovVal.BackgroundTransparency = 1; fovVal.Text = tostring(AimbotConfig.FOV); fovVal.Font = Enum.Font.GothamBold
    fovVal.TextSize = 11; fovVal.TextColor3 = C.sub or Color3.fromRGB(180,180,180); fovVal.TextXAlignment = Enum.TextXAlignment.Right
    -- Slider Track
    local fovTrack = Instance.new("Frame", fovRow)
    fovTrack.Size = UDim2.new(1, -32, 0, 6); fovTrack.Position = UDim2.new(0, 16, 0, 34)
    fovTrack.BackgroundColor3 = C.bg3 or Color3.fromRGB(60,60,70); fovTrack.BackgroundTransparency = 0.2
    fovTrack.BorderSizePixel = 0; _corner(fovTrack, 99)
    local fovFill = Instance.new("Frame", fovTrack)
    local fovPct = (AimbotConfig.FOV - 30) / 270
    fovFill.Size = UDim2.new(fovPct, 0, 1, 0); fovFill.BackgroundColor3 = C.red or Color3.fromRGB(220,60,60)
    fovFill.BorderSizePixel = 0; _corner(fovFill, 99)
    local fovKnob = Instance.new("Frame", fovFill)
    fovKnob.Size = UDim2.new(0, 12, 0, 12); fovKnob.Position = UDim2.new(1, -6, 0.5, -6)
    fovKnob.BackgroundColor3 = Color3.fromRGB(255,255,255); fovKnob.BorderSizePixel = 0; _corner(fovKnob, 99)
    -- Slider Logic
    local fovDrag = false
    local function fovUpdateFromMouse(x)
        local p = math.clamp((x - fovTrack.AbsolutePosition.X) / fovTrack.AbsoluteSize.X, 0, 1)
        fovFill.Size = UDim2.new(p, 0, 1, 0)
        AimbotConfig.FOV = 30 + math.floor(p * 270)
        fovVal.Text = tostring(AimbotConfig.FOV)
        FOVCircle.Radius = AimbotConfig.FOV
    end
    fovTrack.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then fovDrag = true; fovUpdateFromMouse(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i) if fovDrag and i.UserInputType == Enum.UserInputType.MouseMovement then fovUpdateFromMouse(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then fovDrag = false end end)
    -- Hover Effects
    fovRow.MouseEnter:Connect(function() _playHoverSound(); game:GetService("TweenService"):Create(fovRow, TweenInfo.new(0.08), {BackgroundColor3 = C.bg3 or Color3.fromRGB(55,55,65)}):Play() end)
    fovRow.MouseLeave:Connect(function() game:GetService("TweenService"):Create(fovRow, TweenInfo.new(0.08), {BackgroundColor3 = C.bg2 or Color3.fromRGB(40,40,48)}):Play() end)
    
    -- Smoothness Slider – Fling Style
    local smRow = Instance.new("Frame", combatPage)
    smRow.Size = UDim2.new(1, 0, 0, 54); smRow.BackgroundColor3 = C.bg2 or Color3.fromRGB(40,40,48)
    smRow.BackgroundTransparency = 0; smRow.BorderSizePixel = 0; _corner(smRow, 12)
    local smRowS = _stroke(smRow, C.bg3, 1, 0.3)
    local smRowDot = Instance.new("Frame", smRow)
    smRowDot.Size = UDim2.new(0, 3, 0, 26); smRowDot.Visible = false; smRowDot.Position = UDim2.new(0, 0, 0.5, -13)
    smRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220, 60, 60); smRowDot.BackgroundTransparency = 0.4
    smRowDot.BorderSizePixel = 0; _corner(smRowDot, 99)
    local smLbl = Instance.new("TextLabel", smRow)
    smLbl.Size = UDim2.new(0, 100, 0, 24); smLbl.Position = UDim2.new(0, 16, 0, 6)
    smLbl.BackgroundTransparency = 1; smLbl.Text = "Smoothness"; smLbl.Font = Enum.Font.GothamBold
    smLbl.TextSize = 13; smLbl.TextColor3 = C.text or Color3.fromRGB(240,240,240); smLbl.TextXAlignment = Enum.TextXAlignment.Left
    local smVal = Instance.new("TextLabel", smRow)
    smVal.Size = UDim2.new(0, 50, 0, 20); smVal.Position = UDim2.new(1, -58, 0, 8)
    smVal.BackgroundTransparency = 1; smVal.Text = string.format("%.2f", AimbotConfig.Smoothness); smVal.Font = Enum.Font.GothamBold
    smVal.TextSize = 11; smVal.TextColor3 = C.sub or Color3.fromRGB(180,180,180); smVal.TextXAlignment = Enum.TextXAlignment.Right
    -- Slider Track
    local smTrack = Instance.new("Frame", smRow)
    smTrack.Size = UDim2.new(1, -32, 0, 6); smTrack.Position = UDim2.new(0, 16, 0, 34)
    smTrack.BackgroundColor3 = C.bg3 or Color3.fromRGB(60,60,70); smTrack.BackgroundTransparency = 0.2
    smTrack.BorderSizePixel = 0; _corner(smTrack, 99)
    local smFill = Instance.new("Frame", smTrack)
    local smPct = (AimbotConfig.Smoothness - 0.01) / 0.19
    smFill.Size = UDim2.new(smPct, 0, 1, 0); smFill.BackgroundColor3 = C.red or Color3.fromRGB(220,60,60)
    smFill.BorderSizePixel = 0; _corner(smFill, 99)
    local smKnob = Instance.new("Frame", smFill)
    smKnob.Size = UDim2.new(0, 12, 0, 12); smKnob.Position = UDim2.new(1, -6, 0.5, -6)
    smKnob.BackgroundColor3 = Color3.fromRGB(255,255,255); smKnob.BorderSizePixel = 0; _corner(smKnob, 99)
    -- Slider Logic
    local smDrag = false
    local function smUpdateFromMouse(x)
        local p = math.clamp((x - smTrack.AbsolutePosition.X) / smTrack.AbsoluteSize.X, 0.01, 1)
        smFill.Size = UDim2.new(p, 0, 1, 0)
        AimbotConfig.Smoothness = 0.01 + (p * 0.19)
        smVal.Text = string.format("%.2f", AimbotConfig.Smoothness)
    end
    smTrack.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then smDrag = true; smUpdateFromMouse(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i) if smDrag and i.UserInputType == Enum.UserInputType.MouseMovement then smUpdateFromMouse(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then smDrag = false end end)
    -- Hover Effects
    smRow.MouseEnter:Connect(function() _playHoverSound(); game:GetService("TweenService"):Create(smRow, TweenInfo.new(0.08), {BackgroundColor3 = C.bg3 or Color3.fromRGB(55,55,65)}):Play() end)
    smRow.MouseLeave:Connect(function() game:GetService("TweenService"):Create(smRow, TweenInfo.new(0.08), {BackgroundColor3 = C.bg2 or Color3.fromRGB(40,40,48)}):Play() end)
end)()

-- Keybind: Right Mouse Button for Aimlock
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 and AimbotConfig.Enabled then
        AimbotConfig.Aimlock = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if aimlockToggleGetFn and not aimlockToggleGetFn() then
            AimbotConfig.Aimlock = false
        end
    end
end)

-- Cleanup on script destroy
LocalPlayer.CharacterRemoving:Connect(function()
    StopAimbot()
    StopTriggerBot()
    FOVCircle:Remove()
    TargetLine:Remove()
end)

end -- End Aimbot System

combatPage.Size = UDim2.new(1, 0, 0, 46)

-- -------------------------------------------------------------------------
-- -- Script-Segmentleiste (iOS-Style): direkt Game wählen, kein Dropdown/Ordner-Header
local _miscActiveScript = "Bladeball"
local _miscApis         = {}
local _miscScripts = {
    { id="Bladeball", icon="",  col=C.accent2,                       label="Bladeball", baseCol=C.accent2 },
    { id="MM2",       icon="", col=C.accent,                         label="MM2",       baseCol=C.accent },
    { id="DaHood",    icon="", col=C.accent3,                        label="Da Hood",   baseCol=C.accent3 },
}
local _miscSegEntries = {}

local function _miscSegApplyVisual()
    for _, e in ipairs(_miscSegEntries) do
        local on = (e.id == _miscActiveScript)
        local ac = e.col or _scriptCatAccent(e.baseCol)
        if on then
            e.seg.BackgroundColor3 = ac
            e.seg.BackgroundTransparency = 0.78
            e.lbl.TextColor3 = C.text
            e.str.Color = ac
            e.str.Transparency = 0.22
        else
            e.seg.BackgroundColor3 = C.bg3
            e.seg.BackgroundTransparency = 0.52
            e.lbl.TextColor3 = C.sub
            e.str.Color = C.bg3
            e.str.Transparency = 0.62
        end
    end
end

local function _miscSegRefreshTheme()
    for _, e in ipairs(_miscSegEntries) do
        e.col = _scriptCatAccent(e.baseCol)
    end
    _miscSegApplyVisual()
end

local function _miscSwitchTo(sc)
    _miscActiveScript = sc.id
    for _, api in pairs(_miscApis) do pcall(api.setActive, false) end
    local api = _miscApis[sc.id]
    if api then pcall(api.setActive, true) end
    _miscSegApplyVisual()
    task.defer(updateMiscSize)
end

local _miscSegWrap = Instance.new("Frame", sonstigePage)
_miscSegWrap.Size = UDim2.new(1, 0, 0, 52)
_miscSegWrap.BackgroundTransparency = 1
_miscSegWrap.BorderSizePixel = 0
_miscSegWrap.LayoutOrder = 0

local _miscSegBar = Instance.new("Frame", _miscSegWrap)
_miscSegBar.Size = UDim2.new(1, 0, 0, 44)
_miscSegBar.Position = UDim2.new(0, 0, 0, 4)
_miscSegBar.BackgroundColor3 = C.bg2
_miscSegBar.BackgroundTransparency = 0.06
_miscSegBar.BorderSizePixel = 0
corner(_miscSegBar, 11)
local _miscSegBarOutline = _makeDummyStroke(_miscSegBar)
_miscSegBarOutline.Thickness = 1
_miscSegBarOutline.Color = C.bg3
_miscSegBarOutline.Transparency = 0.48

local _miscSegInner = Instance.new("Frame", _miscSegBar)
_miscSegInner.Size = UDim2.new(1, -10, 1, -10)
_miscSegInner.Position = UDim2.new(0, 5, 0, 5)
_miscSegInner.BackgroundTransparency = 1
_miscSegInner.BorderSizePixel = 0

local _nMiscSeg = #_miscScripts
local _segGap, _segH = 6, 32
local _segList = Instance.new("UIListLayout", _miscSegInner)
_segList.FillDirection = Enum.FillDirection.Horizontal
_segList.HorizontalAlignment = Enum.HorizontalAlignment.Center
_segList.VerticalAlignment = Enum.VerticalAlignment.Center
_segList.Padding = UDim.new(0, _segGap)
_segList.SortOrder = _ENUM_SORT_ORDER_LAYOUT

for i, sc in ipairs(_miscScripts) do
    local seg = Instance.new("TextButton", _miscSegInner)
    seg.Size = UDim2.new(1 / _nMiscSeg, -((_nMiscSeg - 1) * _segGap) / _nMiscSeg, 0, _segH)
    seg.BackgroundColor3 = C.bg3
    seg.LayoutOrder = i
    seg.BackgroundTransparency = 0.52
    seg.BorderSizePixel = 0
    seg.Text = ""
    seg.AutoButtonColor = false
    seg.ZIndex = 2
    corner(seg, 8)
    local segStr = _makeDummyStroke(seg)
    segStr.Thickness = 1
    local _segTint = _scriptCatAccent(sc.baseCol or sc.col)
    segStr.Color = _segTint
    segStr.Transparency = 0.62
    segStr.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local lbl = Instance.new("TextLabel", seg)
    lbl.Size = UDim2.new(1, -6, 1, 0)
    lbl.Position = UDim2.new(0, 3, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = sc.icon .. "  " .. sc.label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = C.sub
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    _miscSegEntries[#_miscSegEntries + 1] = {
        id = sc.id, seg = seg, lbl = lbl, str = segStr,
        baseCol = sc.baseCol or sc.col,
        col = _scriptCatAccent(sc.baseCol or sc.col),
    }
    local cap = sc
    seg.MouseEnter:Connect(function()
        _playHoverSound()
        if _miscActiveScript ~= cap.id then
            twP(seg, 0.08, { BackgroundTransparency = 0.28 })
        end
    end)
    seg.MouseLeave:Connect(function()
        _miscSegApplyVisual()
    end)
    seg.MouseButton1Click:Connect(function() _miscSwitchTo(cap) end)
    seg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then _miscSwitchTo(cap) end
    end)
end

-- -- Bladeball (Panel) -----------------------------------------------------
local bbContainer, bbContent, bbAddRow, _bbFolderApi = makeMiscGamePanel(C.accent2, 1)
-- -------------------------------------------------------------------------
local apRow, apSetFn
;(function() -- Bladeball-Scripts: eigener Funktions-Scope – eigenes Register-Limit
-- --------------------------------------------------------------------------
-- BLADEBALL SCRIPTS (Drk Baedi Core – integriert)
-- --------------------------------------------------------------------------

local BB_RS      = _SvcRS
local BB_Players = _SvcPlr
local BB_LP      = BB_Players.LocalPlayer
local BB_UIS     = _SvcUIS

local function bbChar()   return BB_LP.Character end
local function bbRoot()   local c=bbChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function bbHum()    local c=bbChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function bbAlive()  local h=bbHum(); return h and h.Health>0 end

-- -- Shared state table für alle Scripts -----------------------------------
local BB = {
    -- Script enable flags
    autoParryOn     = false,
    smartParryOn    = false, -- compatibility/placeholder
    closeCombatMacroOn = false,
    spamOn          = false,
    hitboxOn        = false,
    speedOn         = false,
    jumpOn          = false,
    -- values
    speedVal        = 28,
    jumpVal         = 70,
    parryDist       = 35,
    parryTiming     = 0.45,
    spamDelay       = 0.08,
    hitboxSize      = 15,
}

-- -- SCRIPT 1+2: Complete Ability-Aware KI Parry System ----------------------
local AbilityDatabase = {
    Offensive = {
        ["Flash Counter"] = { type = "teleport_counter", warningTime = 0.15, counterWindow = 0.25, description = "Teleports behind you, freezes and speeds ball", counterStrategy = "Double parry or Forcefield", priority = 1 },
        ["Rapture"] = { type = "speed_boost", warningTime = 0.1, counterWindow = 0.2, description = "Upward slash, massively increases ball speed", counterStrategy = "Early parry prediction", priority = 1 },
        ["Raging Deflect"] = { type = "speed_boost", warningTime = 0.12, counterWindow = 0.22, description = "Strong deflection, greatly increases ball speed", counterStrategy = "Pre-parry before impact", priority = 1 },
        ["Singularity"] = { type = "pull", warningTime = 0.2, counterWindow = 0.3, description = "Pulls ball towards user unpredictably", counterStrategy = "Extended parry window", priority = 1 },
        ["Slashes of Fury"] = { type = "multi_hit", warningTime = 0.08, counterWindow = 0.35, description = "Multiple rapid slashes", counterStrategy = "Spam parry during ability", priority = 1 },
        ["Slash of Duality"] = { type = "double_hit", warningTime = 0.1, counterWindow = 0.3, description = "Two fast slashes", counterStrategy = "Double parry", priority = 1 },
        ["Death Slash"] = { type = "instant", warningTime = 0.05, counterWindow = 0.15, description = "Instant kill slash", counterStrategy = "Pre-emptive parry", priority = 1 },
        ["Dribble"] = { type = "bait", warningTime = 0.12, counterWindow = 0.4, description = "Bounces ball back to user (max 3 times)", counterStrategy = "Wait for final hit or use Forcefield", priority = 2, specialDetection = "ball_color_change" },
        ["Teleport"] = { type = "teleport", warningTime = 0.1, counterWindow = 0.2, description = "Teleports behind player", counterStrategy = "360 parry", priority = 2 },
        ["Phantom"] = { type = "invisible", warningTime = 0.15, counterWindow = 0.25, description = "Turns invisible during attack", counterStrategy = "Audio cue detection", priority = 2 },
        ["Blink"] = { type = "dash", warningTime = 0.08, counterWindow = 0.18, description = "Quick dash attack", counterStrategy = "Direction prediction", priority = 2 }
    },
    Defensive = {
        ["Forcefield"] = { type = "auto_parry", duration = 7.25, description = "Auto-parries for duration", counterStrategy = "Wait out or use Dribble", vulnerabilityWindow = 0.3 },
        ["Guardian Angel"] = { type = "revive", description = "Survives one hit", counterStrategy = "Multi-hit combo" },
        ["Infinity"] = { type = "lock", duration = 10, description = "Locks ball on hit", counterStrategy = "Use ability after lock ends" },
        ["Time Hole"] = { type = "slow", duration = 3, description = "Slows ball dramatically", counterStrategy = "Ability spam after slow ends" }
    },
    Movement = {
        ["Dash"] = { type = "dodge", description = "Quick dodge", counterStrategy = "Predict landing spot", predictionWindow = 0.15 },
        ["Super Jump"] = { type = "vertical", description = "High jump", counterStrategy = "Watch landing trajectory", predictionWindow = 0.2 },
        ["Quad Jump"] = { type = "multi_jump", description = "Multiple jumps", counterStrategy = "Track height pattern" },
        ["Shadow Step"] = { type = "stealth_move", description = "Silent movement", counterStrategy = "Audio detection" }
    },
    Utility = {
        ["Freeze"] = { type = "stop", duration = 5, description = "Stops ball temporarily", counterStrategy = "Prepare parry when unfrozen" },
        ["Telekinesis"] = { type = "redirect", description = "Redirects ball to random player", counterStrategy = "Be ready for any direction" },
        ["Pull"] = { type = "attract", description = "Pulls ball to user", counterStrategy = "Anticipate immediate return" },
        ["Force"] = { type = "push", description = "Pushes players away", counterStrategy = "Maintain distance" },
        ["Invisibility"] = { type = "hide", duration = 5, description = "Becomes invisible", counterStrategy = "Watch ball target indicator" },
        ["Swap"] = { type = "position_swap", description = "Swaps positions with player", counterStrategy = "360 awareness" }
    }
}

local parryDebounce = false
local _parriedState = false
local _macroCoroutine = nil

local function getBall()
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return nil end
    for _, ball in ipairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then return ball end
    end
    return nil
end

local function performRawParry()
    pcall(function()
        _SvcVIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        _SvcVIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function performAbilityParry()
    performRawParry()
    _parriedState = true
    task.spawn(function()
        task.wait(0.2)
        if not BB.closeCombatMacroOn then _parriedState = false end
    end)
end

local AbilityAgent = {
    ActiveAbility = nil, AbilityType = nil, AbilityStartTime = 0, LastAbilityWarning = 0,
    BallColorHistory = {}, LastPosition = nil, LastBallSpeed = nil,
    
    DetectAbility = function(self)
        local now = tick()
        local char = bbChar()
        if char and char:FindFirstChild("HumanoidRootPart") then
            if self.LastPosition then
                local dist = (char.HumanoidRootPart.Position - self.LastPosition).Magnitude
                if dist > 30 and dist < 100 then self:RegisterAbility("Flash Counter", "Offensive", now) end
            end
            self.LastPosition = char.HumanoidRootPart.Position
        end
        local forcefield = char and char:FindFirstChild("Forcefield")
        if forcefield and forcefield.Visible then self:RegisterAbility("Forcefield", "Defensive", now) end
        local ball = getBall()
        if ball then
            local ballColor = ball.BrickColor and ball.BrickColor.Name or ""
            table.insert(self.BallColorHistory, {color = ballColor, time = now})
            if #self.BallColorHistory > 10 then table.remove(self.BallColorHistory, 1) end
            local colorChanges = 0
            for i = 2, #self.BallColorHistory do
                if self.BallColorHistory[i].color ~= self.BallColorHistory[i-1].color then colorChanges = colorChanges + 1 end
            end
            if colorChanges >= 3 then self:RegisterAbility("Dribble", "Offensive", now) end
            local ballVel = ball:GetAttribute("velocity")
            if ballVel and typeof(ballVel) == "Vector3" then
                local currentSpeed = ballVel.Magnitude
                if self.LastBallSpeed and currentSpeed > self.LastBallSpeed * 2.5 then
                    if currentSpeed > 150 then self:RegisterAbility("Rapture", "Offensive", now)
                    elseif currentSpeed > 100 then self:RegisterAbility("Raging Deflect", "Offensive", now) end
                end
                self.LastBallSpeed = currentSpeed
            end
        end
        if char and char:FindFirstChild("Highlight") then
            local highlight = char.Highlight
            local highlightColor = highlight.FillColor and highlight.FillColor.r
            if highlightColor and highlightColor < 0.5 then self:RegisterAbility("Dribble", "Offensive", now, "upgraded") end
        end
        return self.ActiveAbility, self.AbilityType
    end,
    RegisterAbility = function(self, abilityName, category, timestamp, variant)
        if self.ActiveAbility == abilityName and (timestamp - self.AbilityStartTime) < 2 then return end
        self.ActiveAbility = abilityName; self.AbilityType = category
        self.AbilityStartTime = timestamp; self.LastAbilityWarning = timestamp
        self:ExecuteCounterStrategy(abilityName, category, variant)
        task.spawn(function()
            local duration = 2
            if AbilityDatabase[category] and AbilityDatabase[category][abilityName] then
                duration = AbilityDatabase[category][abilityName].duration or 2
            end
            task.wait(duration)
            if self.ActiveAbility == abilityName then self.ActiveAbility = nil; self.AbilityType = nil end
        end)
    end,
    ExecuteCounterStrategy = function(self, abilityName, category, variant)
        local ability = AbilityDatabase[category] and AbilityDatabase[category][abilityName]
        if not ability then return end
        local warningTime = ability.warningTime or 0.1
        sendNotif("⚠️ Ability", abilityName .. " - " .. (ability.description or ""), 3)
        if category == "Offensive" then
            if ability.type == "teleport_counter" then self:ScheduleCounterParry(warningTime, 2)
            elseif ability.type == "speed_boost" then self:ScheduleCounterParry(warningTime * 0.6, 1)
            elseif ability.type == "multi_hit" or ability.type == "double_hit" then self:StartSpamParry(0.1, ability.counterWindow or 0.35)
            elseif ability.type == "bait" then
                if variant == "upgraded" then self:ScheduleDelayedParry(0.8) else self:ScheduleDelayedParry(0.5) end
            elseif ability.type == "teleport" or ability.type == "invisible" then self:StartSpamParry(0.05, 0.3)
            else self:ScheduleCounterParry(warningTime, 1) end
        elseif category == "Defensive" then
            if ability.type == "auto_parry" then self:SetPassiveMode(ability.duration or 7.25) end
        end
    end,
    ScheduleCounterParry = function(self, delay, parryCount)
        task.spawn(function() task.wait(delay) for i = 1, (parryCount or 1) do performAbilityParry(); task.wait(0.05) end end)
    end,
    ScheduleDelayedParry = function(self, delay)
        task.spawn(function() task.wait(delay) performAbilityParry(); task.wait(0.08); performAbilityParry() end)
    end,
    StartSpamParry = function(self, interval, duration)
        local endTime = tick() + duration
        task.spawn(function() while tick() < endTime do performAbilityParry(); task.wait(interval) end end)
    end,
    SetPassiveMode = function(self, duration) task.wait(duration) end,
    ShouldOverrideParry = function(self) return self.AbilityType == "Offensive" and (tick() - self.AbilityStartTime) < 1.5 end,
    GetParryWindowModifier = function(self)
        local ability = self.ActiveAbility and AbilityDatabase[self.AbilityType] and AbilityDatabase[self.AbilityType][self.ActiveAbility]
        if ability and ability.counterWindow then return ability.counterWindow / 0.55 end
        return 1.0
    end
}

local PerformanceMonitor = {
    FrameTimes = {}, LastFrame = tick(), CurrentFPS = 60, Ping = 0,
    Update = function(self)
        local now = tick(); local frameTime = now - self.LastFrame; self.LastFrame = now
        table.insert(self.FrameTimes, frameTime); if #self.FrameTimes > 10 then table.remove(self.FrameTimes, 1) end
        local avg = 0; for _, ft in ipairs(self.FrameTimes) do avg = avg + ft end
        avg = avg / #self.FrameTimes
        self.CurrentFPS = avg > 0 and math.floor(1 / avg) or 60
        pcall(function() self.Ping = _SvcStats.Network.ServerStatsItem["Data Ping"]:GetValue() or 0 end)
    end,
    GetLatencyCompensation = function(self)
        local fpsComp = math.clamp((60 - self.CurrentFPS) / 60, 0, 0.3)
        local pingComp = math.clamp(self.Ping / 200, 0, 0.25)
        return fpsComp + pingComp
    end
}

local CloseCombatMacro = {
    Active = false, SpamRate = 0.08, LastParryTime = 0, EnemyDistance = 15, ParryWindow = 0.12, BurstMode = false, BurstEndTime = 0,
    StartMacro = function(self)
        if self.Active then return end
        self.Active = true; self.BurstMode = true; self.BurstEndTime = tick() + 0.5
        if _macroCoroutine then task.cancel(_macroCoroutine) end
        _macroCoroutine = task.spawn(function()
            while self.Active and BB.autoParryOn and BB.closeCombatMacroOn do
                local now = tick()
                if self.BurstMode and now < self.BurstEndTime then self:PerformSpamParry(0.03)
                else self.BurstMode = false; self:PerformSpamParry(self.SpamRate) end
                task.wait(self.BurstMode and 0.02 or self.SpamRate)
            end
        end)
    end,
    PerformSpamParry = function(self, delay)
        local now = tick()
        if now - self.LastParryTime >= delay then
            for i = 1, 3 do performRawParry() end
            self.LastParryTime = now; _parriedState = true
            task.spawn(function() task.wait(0.15) if not self.Active then _parriedState = false end end)
        end
    end,
    StopMacro = function(self)
        self.Active = false; self.BurstMode = false
        if _macroCoroutine then task.cancel(_macroCoroutine); _macroCoroutine = nil end
    end,
    UpdateDistance = function(self, distance)
        self.EnemyDistance = distance
        if distance < 8 then self.SpamRate = 0.05; self.ParryWindow = 0.08
        elseif distance < 12 then self.SpamRate = 0.07; self.ParryWindow = 0.1
        else self.SpamRate = 0.1; self.ParryWindow = 0.12 end
    end
}

local EnemyTracker = {
    NearestEnemy = nil, Distance = 999,
    Update = function(self)
        local nearest = nil; local minDist = 999; local myRoot = bbRoot()
        if not myRoot then return 999 end
        for _, p in ipairs(BB_Players:GetPlayers()) do
            if p ~= BB_LP and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if r and h and h.Health > 0 then
                    local d = (myRoot.Position - r.Position).Magnitude
                    if d < minDist then minDist = d; nearest = p end
                end
            end
        end
        self.NearestEnemy = nearest; self.Distance = minDist
        return minDist
    end
}

local RangedTracker = {
    ShouldParry = function(self, ball, distance, speed, latencyComp, abilityModifier)
        if _parriedState then return false end
        local target = ball:GetAttribute("target")
        if not target or target ~= BB_LP.Name then return false end
        if speed <= 0.1 then return false end
        local estimatedTime = distance / speed
        local adjustedThreshold = (estimatedTime * 0.75) - (0.06 + latencyComp)
        local parryWindow = 0.55 * abilityModifier
        return adjustedThreshold <= parryWindow and adjustedThreshold >= 0.05
    end
}

BB_RS.Heartbeat:Connect(function()
    if not BB.autoParryOn or not bbAlive() then return end
    AbilityAgent:DetectAbility()
    PerformanceMonitor:Update()
    local dist = EnemyTracker:Update()
    CloseCombatMacro:UpdateDistance(dist)
    
    if dist < 15 and BB.closeCombatMacroOn then
        if not CloseCombatMacro.Active then CloseCombatMacro:StartMacro() end
        return
    else
        if CloseCombatMacro.Active then CloseCombatMacro:StopMacro(); _parriedState = false end
    end
    
    local ball = getBall()
    if not ball then return end
    local myRoot = bbRoot()
    if not myRoot then return end
    local zoomies = ball:FindFirstChild("zoomies")
    local speedVec = zoomies and zoomies:FindFirstChild("VectorVelocity")
    if not speedVec then return end
    
    local speed = speedVec.Magnitude
    local ballDist = (myRoot.Position - ball.Position).Magnitude
    local latency = PerformanceMonitor:GetLatencyCompensation()
    local abilityMod = AbilityAgent:GetParryWindowModifier()
    
    if AbilityAgent:ShouldOverrideParry() then performAbilityParry(); return end
    if RangedTracker:ShouldParry(ball, ballDist, speed, latency, abilityMod) then performAbilityParry() end
end)

-- Visualizer
pcall(function()
    if getgenv().visualizer == nil then getgenv().visualizer = false end
    task.spawn(function()
        while task.wait(1) do
            if BB.autoParryOn and getgenv().visualizer and workspace:FindFirstChild("Balls") then
                pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/1f0yt/community/main/RedCircleBlock"))() end)
                break
            end
        end
    end)
end)

-- -- SCRIPT 3: Auto Spam Click ---------------------------------------------
do
local lastSpam = 0
BB_RS.Heartbeat:Connect(function()
    if not BB.spamOn or not bbAlive() then return end
    local now = tick()
    if now - lastSpam < BB.spamDelay then return end
    lastSpam = now
    pcall(function()
        local mouse = BB_LP:GetMouse()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0)
        task.delay(0.03, function() vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0) end)
    end)
end)
end -- spam click

-- -- SCRIPT 5: Hitbox Expander ---------------------------------------------
do
local origHitboxes = {}
local lastHBRun = 0
BB_RS.Heartbeat:Connect(function(dt)
    lastHBRun = lastHBRun + dt
    if lastHBRun < 0.5 then return end
    lastHBRun = 0
    if not BB.hitboxOn then
        -- restore
        for player, size in pairs(origHitboxes) do
            pcall(function()
                if player.Character then
                    local r = player.Character:FindFirstChild("HumanoidRootPart")
                    if r then r.Size=size; r.Transparency=1; r.CanCollide=true end
                end
            end)
        end
        origHitboxes = {}
        return
    end
    for _, player in ipairs(BB_Players:GetPlayers()) do
        if player ~= BB_LP and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                if not origHitboxes[player] then origHitboxes[player] = root.Size end
                pcall(function()
                    root.Size = Vector3.new(BB.hitboxSize, BB.hitboxSize, BB.hitboxSize)
                    root.Transparency = 0.7
                    root.CanCollide = false
                end)
            end
        end
    end
end)
end -- hitbox

-- -- SCRIPT 6+7: Speed & Jump Boost ----------------------------------------
do
BB_RS.Heartbeat:Connect(function()
    local hum = bbHum(); if not hum or hum.Health<=0 then return end
    if BB.speedOn then hum.WalkSpeed = BB.speedVal end
    if BB.jumpOn  then hum.UseJumpPower=true; hum.JumpPower=BB.jumpVal end
end)
end -- speed+jump



-- -- SCRIPT 10: Infinite Jump ----------------------------------------------
BB_UIS.JumpRequest:Connect(function()
    if not BB.infJumpOn then return end
    local h = bbHum()
    if h and h.Health>0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)



-- -- SCRIPT 13: Auto Equip Tool --------------------------------------------
do
local lastEquip = 0
BB_RS.Heartbeat:Connect(function()
    if not BB.autoEquipOn then return end
    if tick()-lastEquip < 1 then return end
    local bp = BB_LP:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local h = bbHum()
                if h then h:EquipTool(tool); lastEquip=tick(); return end
            end
        end
    end
end)
end -- auto equip



-- -- CharacterAdded: restore speed/jump on respawn ---------------------
BB_LP.CharacterAdded:Connect(function(char)
    task.wait(1.5)
    local h = char:FindFirstChildOfClass("Humanoid"); if not h then return end
    if BB.speedOn then h.WalkSpeed = BB.speedVal end
    if BB.jumpOn  then h.UseJumpPower=true; h.JumpPower=BB.jumpVal end
end)

-- --------------------------------------------------------------------------
-- bbAddRow calls – je ein Toggle pro Script
-- --------------------------------------------------------------------------
apRow, apSetFn = bbAddRow("Auto Parry",   "Parry",    C.accent2, false, function(on)
    BB.autoParryOn = on
    sendNotif("Bladeball", on and " AutoParry Activated!" or "Auto Parry Deactivated!", 2)
end)
bbAddRow("Spam Click",    "Combat",   C.accent2, false, function(on)
    BB.spamOn = on
    sendNotif("Bladeball", on and "🖱 Spam Click ON" or "Spam OFF", 2)
end)
bbAddRow("Hitbox Expand", "Combat",   C.accent2, false, function(on)
    BB.hitboxOn = on
    sendNotif("Bladeball", on and "📦 Hitbox Expand ON" or "Hitbox OFF", 2)
end)
bbAddRow("Speed Boost",   "Move",     C.accent2, false, function(on)
    BB.speedOn = on
    sendNotif("Bladeball", on and ("⚡ Speed "..BB.speedVal) or "Speed OFF", 2)
end)
bbAddRow("Jump Boost",    "Move",     C.accent2, false, function(on)
    BB.jumpOn = on
    sendNotif("Bladeball", on and ("⬆ Jump "..BB.jumpVal) or "Jump OFF", 2)
end)
bbAddRow("Inf. Jump",     "Move",     C.accent2, false, function(on)
    BB.infJumpOn = on
    sendNotif("Bladeball", on and "♾ Inf Jump ON" or "Inf Jump OFF", 2)
end)
bbAddRow("Auto Equip",    "Misc",     C.accent2, false, function(on)
    BB.autoEquipOn = on
    sendNotif("Bladeball", on and "🔧 Auto Equip ON" or "Auto Equip OFF", 2)
end)

end)() -- Ende Bladeball-Scripts

-- -------------------------------------------------------------------------
-- -- MM2 Ordner (Murder Mystery 2) -----------------------------------------
;(function() -- MM2: eigener Funktions-Scope – eigenes Register-Limit (makeMiscFolder innen – äußeres Local-Limit)
local mm2Container, mm2Content, mm2AddRow, _mm2FolderApi = makeMiscGamePanel(C.accent, 2)
local _mm2Players = _SvcPlr
local _mm2RS      = _SvcRS
local _mm2UIS     = _SvcUIS
local _mm2LP      = _mm2Players.LocalPlayer
local _mm2PGui    = _mm2LP:WaitForChild("PlayerGui", 10)
if not _mm2PGui then warn("[TLMenu] PlayerGui not found, mm2 module skipped"); return end
local _mm2WS      = workspace

-- -- Config ----------------------------------------------------------------
local _mm2Cfg = {
    ESP      = { Enabled       = false,
                 MurdererColor = Color3.fromRGB(255, 50,  50),
                 SheriffColor  = Color3.fromRGB( 50,100, 255),
                 InnocentColor = Color3.fromRGB( 50,255, 100),
                 GunColor      = Color3.fromRGB(255, 215,  0), -- Gold for dropped gun
                 Transparency  = 0.45 },
    AutoFarm = { Enabled = false, DelayBetweenPickups = 0.05 },
    AutoGun  = { AutoPickup = false },
    KillAura = { Enabled          = false,
                 Range            = 115,
                 OnlyWhenMurderer = true,
                 SilentAim        = true,
                 AutoEquip        = true,
                 AttackSpeed      = 0.1 },
    Movement = { SpeedHack = false, WalkSpeed = 55,
                 Fly = false, FlySpeed = 80, Noclip = false },
}

-- -- VirtualInputManager (pcall – nicht überall verfügbar) -----------------
local _mm2VIM = nil
pcall(function() _mm2VIM = game:GetService("VirtualInputManager") end)

-- -- Role Detection --------------------------------------------------------
local function _mm2GetRole(player)
    local char = player.Character
    if not char then return "Innocent" end
    local function checkTools(list)
        for _, t in ipairs(list) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("knife") or n:find("dagger") then return "Murderer" end
                if n:find("gun")   or n:find("pistol") or n:find("sheriff") then return "Sheriff" end
            end
        end
    end
    return checkTools(player.Backpack:GetChildren())
        or checkTools(char:GetChildren())
        or "Innocent"
end

local _mm2HL = {}  -- [player] = Highlight
local _mm2GunHL = nil

local function _mm2ApplyESP(player)
    if not _mm2Cfg.ESP.Enabled then return end
    if player == _mm2LP then return end
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local role  = _mm2GetRole(player)
    local color = role == "Murderer" and _mm2Cfg.ESP.MurdererColor
               or role == "Sheriff"  and _mm2Cfg.ESP.SheriffColor
               or _mm2Cfg.ESP.InnocentColor
    if not _mm2HL[player] or not _mm2HL[player].Parent then
        if _mm2HL[player] then pcall(function() _mm2HL[player]:Destroy() end) end
        local hl = Instance.new("Highlight")
        hl.Adornee = char; hl.FillColor = color
        hl.OutlineColor = Color3.fromRGB(255,255,255)
        hl.FillTransparency = _mm2Cfg.ESP.Transparency
        hl.OutlineTransparency = 1 -- Sharp white outline
        hl.Parent = _mm2WS -- Parenting to Workspace or Actor is often better for performance
        _mm2HL[player] = hl
    else
        _mm2HL[player].FillColor = color
        if _mm2HL[player].Adornee ~= char then _mm2HL[player].Adornee = char end
    end
end

local function _mm2RemoveESP(player)
    if _mm2HL[player] then
        pcall(function() _mm2HL[player]:Destroy() end)
        _mm2HL[player] = nil
    end
end

local function _mm2ClearESP()
    for p in pairs(_mm2HL) do _mm2RemoveESP(p) end
    if _mm2GunHL then pcall(function() _mm2GunHL:Destroy() end); _mm2GunHL = nil end
end

local function _mm2HookPlayer(player)
    if player == _mm2LP then return end
    if player.Character then
        task.spawn(function()
            player.Character:WaitForChild("HumanoidRootPart", 5)
            if _mm2Cfg.ESP.Enabled then _mm2ApplyESP(player) end
        end)
    end
    player.CharacterAdded:Connect(function(char)
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 5)
            if _mm2Cfg.ESP.Enabled then _mm2ApplyESP(player) end
        end)
    end)
    player.CharacterRemoving:Connect(function() _mm2RemoveESP(player) end)
end

-- Fallback-Loop: aktualisiert Farben + erstellt fehlende Highlights nach
local function _mm2UpdateESP()
    if not _mm2Cfg.ESP.Enabled then 
        if _mm2GunHL then _mm2GunHL:Destroy(); _mm2GunHL = nil end
        return 
    end
    
    -- Player ESP
    for _, player in ipairs(_mm2Players:GetPlayers()) do
        if player == _mm2LP then continue end
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            if _mm2HL[player] then _mm2RemoveESP(player) end
            continue
        end
        if not _mm2HL[player] or not _mm2HL[player].Parent then
            _mm2ApplyESP(player)
        else
            -- Role tracking: check if role changed (e.g. someone picked up gun)
            local role = _mm2GetRole(player)
            local targetColor = role == "Murderer" and _mm2Cfg.ESP.MurdererColor
                             or role == "Sheriff"  and _mm2Cfg.ESP.SheriffColor
                             or _mm2Cfg.ESP.InnocentColor
                             
            if _mm2HL[player].FillColor ~= targetColor then
                _mm2HL[player].FillColor = targetColor
            end
            if _mm2HL[player].Adornee ~= char then _mm2HL[player].Adornee = char end
        end
    end
    for player in pairs(_mm2HL) do
        if not player.Parent then _mm2RemoveESP(player) end
    end
    
    -- Gun Drop ESP detection
    local droppedGun = nil
    for _, obj in ipairs(_mm2WS:GetChildren()) do
        if obj:IsA("Tool") and obj.Name == "Gun" then
            droppedGun = obj; break
        end
    end
    
    if droppedGun then
        if not _mm2GunHL or not _mm2GunHL.Parent then
            if _mm2GunHL then pcall(function() _mm2GunHL:Destroy() end) end
            local hl = Instance.new("Highlight")
            hl.FillColor = _mm2Cfg.ESP.GunColor
            hl.OutlineColor = Color3.fromRGB(255,255,255)
            hl.FillTransparency = _mm2Cfg.ESP.Transparency
            hl.OutlineTransparency = 1
            hl.Adornee = droppedGun
            hl.Parent = _mm2WS
            _mm2GunHL = hl
        else
            _mm2GunHL.Adornee = droppedGun
            _mm2GunHL.Enabled = true
        end
    else
        if _mm2GunHL then 
            _mm2GunHL.Enabled = false
            pcall(function() _mm2GunHL:Destroy() end)
            _mm2GunHL = nil 
        end
    end
end

for _, p in ipairs(_mm2Players:GetPlayers()) do _mm2HookPlayer(p) end
_mm2Players.PlayerAdded:Connect(_mm2HookPlayer)
_mm2Players.PlayerRemoving:Connect(_mm2RemoveESP)

-- -- AutoGrab Gun ---------------------------------------------------------
local function _mm2AutoGrabGun()
    if not _mm2Cfg.AutoGun.AutoPickup then return end
    local _c = _mm2LP.Character
    local _h = _c and _c:FindFirstChild("HumanoidRootPart")
    if not _h then return end
    for _, v in pairs(_mm2WS:GetChildren()) do
        if v:IsA("Tool") and v.Name == "Gun" then
            local h = v:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then
                pcall(function() _h.CFrame = h.CFrame end)
            end
        end
    end
end

-- -- AutoFarm – Batch + Ground Raycast ------------------------------------
local _mm2CoinKW = {"coin","money","gold","gem","cash","reward","pickup",
                    "collectible","drop","token","shard","crystal","orb"}
local function _mm2IsCoin(name)
    local low = name:lower()
    for _, kw in ipairs(_mm2CoinKW) do if low:find(kw) then return true end end
end

local _mm2CoinReg  = {}  -- [part] = {status, attempts}
local _mm2WatchAdd, _mm2WatchRem = nil, nil
local _mm2FarmRunning = false

local function _mm2IsAlive(p) return p and p.Parent ~= nil end

local function _mm2GetGroundY(pos, charToExclude)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = charToExclude and {charToExclude} or {}
    local res = _mm2WS:Raycast(Vector3.new(pos.X, pos.Y+30, pos.Z), Vector3.new(0,-80,0), rp)
    return res and (res.Position.Y + 3) or (pos.Y + 2)
end

local function _mm2GetFreshHRP()
    local char = _mm2LP.Character; if not char then return nil end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return hrp, char
end

local _mm2COIN_TIMEOUT  = 0.2
local _mm2COIN_ATTEMPTS = 1

local function _mm2TryPickup(coinPart)
    local data = _mm2CoinReg[coinPart]
    if not data or data.status ~= "grabbed" then return end
    if not _mm2IsAlive(coinPart) then _mm2CoinReg[coinPart] = nil; return end

    local function snap(yDelta)
        local hrp, char = _mm2GetFreshHRP(); if not hrp then return false end
        local pos  = coinPart.Position
        local safeY = _mm2GetGroundY(pos, char) + (yDelta or 0)
        pcall(function() hrp.CFrame = CFrame.new(pos.X, safeY, pos.Z) end)
        task.wait()
        return not _mm2IsAlive(coinPart)
    end

    for _, yo in ipairs({0, 1.0, -0.8}) do
        if snap(yo) then _mm2CoinReg[coinPart] = nil; return end
        if not _mm2IsAlive(coinPart) then _mm2CoinReg[coinPart] = nil; return end
    end

    local deadline = tick() + _mm2COIN_TIMEOUT
    while tick() < deadline do
        if not _mm2IsAlive(coinPart) then _mm2CoinReg[coinPart] = nil; return end
        local hrp, char = _mm2GetFreshHRP(); if not hrp then return end
        local lp = coinPart.Position
        pcall(function() hrp.CFrame = CFrame.new(lp.X, _mm2GetGroundY(lp, char), lp.Z) end)
        task.wait()
    end

    data.attempts = (data.attempts or 0) + 1
    if data.attempts >= _mm2COIN_ATTEMPTS then
        _mm2CoinReg[coinPart] = nil
    else
        if _mm2CoinReg[coinPart] then _mm2CoinReg[coinPart].status = "active" end
    end
end

local function _mm2ScanCoins()
    _mm2CoinReg = {}
    for _, obj in ipairs(_mm2WS:GetDescendants()) do
        if obj:IsA("BasePart") and _mm2IsCoin(obj.Name) and _mm2IsAlive(obj) then
            _mm2CoinReg[obj] = {status="active", attempts=0}
        end
    end
end

local function _mm2StartWatcher()
    if _mm2WatchAdd then return end
    _mm2WatchAdd = _mm2WS.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") and _mm2IsCoin(obj.Name) then
            task.delay(0.03, function()
                if _mm2IsAlive(obj) then
                    _mm2CoinReg[obj] = {status="active", attempts=0}
                end
            end)
        end
    end)
    _mm2WatchRem = _mm2WS.DescendantRemoving:Connect(function(obj)
        _mm2CoinReg[obj] = nil
    end)
end

local function _mm2StopWatcher()
    if _mm2WatchAdd then _mm2WatchAdd:Disconnect(); _mm2WatchAdd = nil end
    if _mm2WatchRem then _mm2WatchRem:Disconnect(); _mm2WatchRem = nil end
end

local function _mm2StartFarm()
    if _mm2FarmRunning then return end
    _mm2FarmRunning = true
    task.spawn(function()
        _mm2ScanCoins()
        _mm2StartWatcher()
        while _mm2Cfg.AutoFarm.Enabled do
            local hrp = _mm2GetFreshHRP()
            if hrp then
                local batch = {}
                for part, data in pairs(_mm2CoinReg) do
                    if data.status == "active" then
                        if _mm2IsAlive(part) then
                            local d = (hrp.Position - part.Position)
                            table.insert(batch, {part=part, dist2=d.X*d.X+d.Y*d.Y+d.Z*d.Z})
                        else _mm2CoinReg[part] = nil end
                    end
                end
                table.sort(batch, function(a,b) return a.dist2 < b.dist2 end)
                for _, e in ipairs(batch) do
                    if not _mm2Cfg.AutoFarm.Enabled then break end
                    local d = _mm2CoinReg[e.part]
                    if d and d.status == "active" then
                        d.status = "grabbed"
                        _mm2TryPickup(e.part)
                    end
                end
            end
            task.wait(_mm2Cfg.AutoFarm.DelayBetweenPickups)
        end
        _mm2FarmRunning = false
        _mm2StopWatcher()
    end)
end

-- -- Kill Aura -------------------------------------------------------------
local _mm2KAConn = nil
local _mm2LastAtk = 0

local function _mm2GetWeapon()
    local char = _mm2LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                local n = t.Name:lower()
                if n:find("knife") or n:find("gun") or n:find("pistol") or
                   n:find("sword") or n:find("katana") then return t, true end
            end
        end
    end
    for _, t in ipairs(_mm2LP.Backpack:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("knife") or n:find("gun") or n:find("pistol") or
               n:find("sword") or n:find("katana") then return t, false end
        end
    end
    for _, t in ipairs(_mm2LP.Backpack:GetChildren()) do
        if t:IsA("Tool") then return t, false end
    end
    return nil, false
end

local function _mm2EquipWeapon(weapon, equipped)
    if not _mm2Cfg.KillAura.AutoEquip or equipped then return equipped end
    local char = _mm2LP.Character; if not char then return false end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t ~= weapon then t.Parent = _mm2LP.Backpack end
    end
    if weapon.Parent ~= char then weapon.Parent = char; task.wait(0.05) end
    return true
end

-- Sammelt alle lebenden Spieler (Sheriff-Prio wenn Murderer)
local function _mm2GetAllTargets()
    local isMurderer = _mm2GetRole(_mm2LP) == "Murderer"
    local sheriffs, others = {}, {}
    for _, player in ipairs(_mm2Players:GetPlayers()) do
        if player == _mm2LP then continue end
        local char = player.Character; if not char then continue end
        local tHrp = char:FindFirstChild("HumanoidRootPart")
        local tHum = char:FindFirstChildOfClass("Humanoid")
        if not tHrp or not tHum or tHum.Health <= 0 then continue end
        if isMurderer and _mm2GetRole(player) == "Sheriff" then
            sheriffs[#sheriffs+1] = player
        else
            others[#others+1] = player
        end
    end
    -- Sheriffs zuerst, dann Rest
    local result = {}
    for _, p in ipairs(sheriffs) do result[#result+1] = p end
    for _, p in ipairs(others)   do result[#result+1] = p end
    return result
end

local function _mm2Attack(weapon, tHrp)
    if not weapon or not tHrp then return end
    -- Messer-Handle auf Ziel-HRP via firetouchinterest → löst Slash aus, kein Throw
    local handle = weapon:FindFirstChild("Handle")
    if handle and firetouchinterest then
        pcall(function() firetouchinterest(tHrp, handle, 0) end)
        task.wait(0.02)
        pcall(function() firetouchinterest(tHrp, handle, 1) end)
    elseif handle and _mm2VIM then
        -- Fallback: HRP kurz auf Handle-Position snappen damit Touch feuert
        local myChar = _mm2LP.Character
        local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myHrp then
            myHrp.CFrame = CFrame.new(tHrp.Position)
            task.wait(0.02)
        end
    end
end

local function _mm2ToggleKA(on)
    if _mm2KAConn then _mm2KAConn:Disconnect(); _mm2KAConn = nil end
    if not on then return end
    -- Eigener task.spawn Loop statt Heartbeat – erlaubt task.wait zwischen Teleports
    _mm2KAConn = { _thread = task.spawn(function()
        while _mm2Cfg.KillAura.Enabled do
            if _mm2Cfg.KillAura.OnlyWhenMurderer and _mm2GetRole(_mm2LP) ~= "Murderer" then
                task.wait(0.3); continue
            end
            local char = _mm2LP.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then task.wait(0.2); continue end

            local weapon, equipped = _mm2GetWeapon()
            if not weapon then task.wait(0.2); continue end
            _mm2EquipWeapon(weapon, equipped)

            local targets = _mm2GetAllTargets()
            if #targets == 0 then task.wait(0.3); continue end

            for _, target in ipairs(targets) do
                if not _mm2Cfg.KillAura.Enabled then break end
                local tChar = target.Character; if not tChar then continue end
                local tHrp  = tChar:FindFirstChild("HumanoidRootPart")
                local tHum  = tChar:FindFirstChildOfClass("Humanoid")
                if not tHrp or not tHum or tHum.Health <= 0 then continue end

                -- Teleport direkt auf Ziel
                hrp.CFrame = CFrame.new(tHrp.Position)
                task.wait(0.05)

                -- Nochmal prüfen (Ziel könnte nach Teleport tot/weg sein)
                if not tChar.Parent or tHum.Health <= 0 then continue end

                -- Waffe re-holen (könnte nach Teleport unequipped sein)
                weapon, equipped = _mm2GetWeapon()
                if not weapon then continue end
                _mm2EquipWeapon(weapon, equipped)

                -- Angriff: mehrfach feuern bis tot
                local attempts = 0
                while tChar.Parent and tHum.Health > 0 and _mm2Cfg.KillAura.Enabled and attempts < 8 do
                    hrp.CFrame = CFrame.new(tHrp.Position)
                    _mm2Attack(weapon, tHrp)
                    if _mm2Cfg.KillAura.SilentAim then
                        local cam = _mm2WS.CurrentCamera
                        if cam then pcall(function() cam.CFrame = CFrame.new(cam.CFrame.Position, tHrp.Position) end) end
                    end
                    task.wait(_mm2Cfg.KillAura.AttackSpeed)
                    attempts = attempts + 1
                end
            end

            task.wait(0.1)
        end
    end),
    Disconnect = function(self)
        if self._thread then task.cancel(self._thread); self._thread = nil end
    end }
end

-- -- Movement --------------------------------------------------------------
local _mm2FlyConn, _mm2NoclipConn = nil, nil
local _mm2FlyBV,   _mm2FlyBG      = nil, nil

local function _mm2SetSpeed(on)
    local hum = _mm2LP.Character and _mm2LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = on and _mm2Cfg.Movement.WalkSpeed or 16 end
end

local function _mm2SetFly(on)
    if _mm2FlyConn then _mm2FlyConn:Disconnect(); _mm2FlyConn = nil end
    if _mm2FlyBV   then _mm2FlyBV:Destroy();      _mm2FlyBV   = nil end
    if _mm2FlyBG   then _mm2FlyBG:Destroy();      _mm2FlyBG   = nil end
    local hum  = _mm2LP.Character and _mm2LP.Character:FindFirstChildOfClass("Humanoid")
    if not on then if hum then hum.PlatformStand = false end; return end
    local root = _mm2LP.Character and _mm2LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if hum then hum.PlatformStand = true end
    _mm2FlyBG = Instance.new("BodyGyro", root)
    _mm2FlyBG.MaxTorque = Vector3.new(40000,40000,40000); _mm2FlyBG.P = 20000
    _mm2FlyBV = Instance.new("BodyVelocity", root)
    _mm2FlyBV.MaxForce = Vector3.new(40000,40000,40000)
    _mm2FlyConn = _mm2RS.Heartbeat:Connect(function()
        if not _mm2Cfg.Movement.Fly then return end
        local r   = _mm2LP.Character and _mm2LP.Character:FindFirstChild("HumanoidRootPart")
        if not r or not _mm2FlyBV or not _mm2FlyBG then return end
        local cam = _mm2WS.CurrentCamera; if not cam then return end
        local dir = Vector3.new()
        if _mm2UIS:IsKeyDown(Enum.KeyCode.W)         then dir = dir + cam.CFrame.LookVector  end
        if _mm2UIS:IsKeyDown(Enum.KeyCode.S)         then dir = dir - cam.CFrame.LookVector  end
        if _mm2UIS:IsKeyDown(Enum.KeyCode.A)         then dir = dir - cam.CFrame.RightVector end
        if _mm2UIS:IsKeyDown(Enum.KeyCode.D)         then dir = dir + cam.CFrame.RightVector end
        if _mm2UIS:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0)     end
        if _mm2UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0)     end
        if dir.Magnitude > 0 then dir = dir.Unit end
        _mm2FlyBV.Velocity = dir * _mm2Cfg.Movement.FlySpeed
        _mm2FlyBG.CFrame   = CFrame.new(r.Position, r.Position + cam.CFrame.LookVector)
    end)
end

local function _mm2SetNoclip(on)
    if _mm2NoclipConn then _mm2NoclipConn:Disconnect(); _mm2NoclipConn = nil end
    if not on then return end
    _mm2NoclipConn = _mm2RS.Heartbeat:Connect(function()
        local char = _mm2LP.Character; if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

-- -- Loops ----------------------------------------------------------------
local _mm2ESPLoopRunning = true
local _mm2AutoGunLoopRunning = true

-- ESP-Loop (0.1s Interval, erstellt fehlende Highlights nach)
task.spawn(function()
    while _mm2ESPLoopRunning do
        pcall(_mm2UpdateESP)
        task.wait(0.1)
    end
end)

-- AutoGun-Loop
task.spawn(function()
    while _mm2AutoGunLoopRunning do
        if _mm2Cfg.AutoGun.AutoPickup then pcall(_mm2AutoGrabGun) end
        task.wait(0.5)
    end
end)

-- Cleanup function
function _mm2StopLoops()
    _mm2ESPLoopRunning = false
    _mm2AutoGunLoopRunning = false
end

-- Respawn: Movement + AutoFarm neu anwenden
_mm2LP.CharacterAdded:Connect(function()
    task.wait(1)
    if _mm2Cfg.Movement.SpeedHack then _mm2SetSpeed(true)  end
    if _mm2Cfg.Movement.Fly        then _mm2SetFly(true)    end
    if _mm2Cfg.Movement.Noclip     then _mm2SetNoclip(true) end
    if _mm2Cfg.AutoFarm.Enabled    then
        _mm2FarmRunning = false
        _mm2StartFarm()
    end
end)

-- -- Toggle Rows -----------------------------------------------------------
local _mm2Red    = Color3.fromRGB(255, 60,  90)
local _mm2Green  = Color3.fromRGB( 50, 255, 100)
local _mm2Blue   = Color3.fromRGB( 80, 180, 255)
local _mm2Purple = Color3.fromRGB(175,  80, 255)
local _mm2Orange = Color3.fromRGB(255, 165,   0)

mm2AddRow("Role ESP", "ESP", _mm2Red, false, function(on)
    _mm2Cfg.ESP.Enabled = on
    if not on then _mm2ClearESP() end
    sendNotif("MM2", on and "👁 Role ESP on" or "Role ESP off", 2)
end)

mm2AddRow("Kill Aura", "Combat", _mm2Orange, false, function(on)
    _mm2Cfg.KillAura.Enabled = on
    _mm2ToggleKA(on)
    sendNotif("MM2", on and "🗡 Kill Aura on" or "Kill Aura off", 2)
end)

mm2AddRow("Auto Farm", "Farm", _mm2Green, false, function(on)
    _mm2Cfg.AutoFarm.Enabled = on
    if on then _mm2StartFarm() end
    sendNotif("MM2", on and "🌾 Auto Farm on" or "Auto Farm off", 2)
end)

mm2AddRow("Auto Grab Gun", "Gun", _mm2Blue, false, function(on)
    _mm2Cfg.AutoGun.AutoPickup = on
    sendNotif("MM2", on and "🔫 Auto Grab Gun on" or "Auto Grab Gun off", 2)
end)

mm2AddRow("Speed Hack", "Move", _mm2Purple, false, function(on)
    _mm2Cfg.Movement.SpeedHack = on
    _mm2SetSpeed(on)
    sendNotif("MM2", on and "⚡ Speed Hack on" or "Speed Hack off", 2)
end)
_miscApis["MM2"] = _mm2FolderApi
pcall(function() _mm2FolderApi.setActive(false) end)
end)() -- Ende MM2 IIFE
-- -- Ende MM2 Ordner --------------------------------------------------------

-- -------------------------------------------------------------------------
-- -- Da Hood Ordner --------------------------------------------------------
;(function() -- DaHood: eigener Funktions-Scope (makeMiscFolder hier – weniger Locals im äußeren IIFE)
local dhContainer, dhContent, dhAddRow, _dhFolderApi = makeMiscGamePanel(C.accent3, 3)
local _dhPlayers = _SvcPlr
local _dhRS      = _SvcRS
local _dhUIS     = _SvcUIS
local _dhLP      = _dhPlayers.LocalPlayer
local _dhPGui    = _dhLP:WaitForChild("PlayerGui", 10)
if not _dhPGui then warn("[TLMenu] PlayerGui not found, dahood module skipped"); return end
local _dhWS      = workspace
local _dhRS2     = game:GetService("ReplicatedStorage")

local _dhVIM = nil
pcall(function() _dhVIM = game:GetService("VirtualInputManager") end)

-- -- Helpers ---------------------------------------------------------------
local function _dhChar()   return _dhLP.Character end
local function _dhHRP()
    local c = _dhChar(); if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end
local function _dhHum()
    local c = _dhChar(); if not c then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end
local function _dhAlive()
    local h = _dhHum(); return h and h.Health > 0
end

-- Da Hood: Cops sind im Team "Police", Kriminelle im Team "Criminals" oder kein Team
local function _dhIsCop(p)
    return p.Team and p.Team.Name:lower():find("police") ~= nil
end

-- -- ESP: Cops Blau, Gegner Rot --------------------------------------------
local _dhESPEnabled = false   -- FIX: default off, matches UI toggle
local _dhHL = {}

local function _dhESPColor(p)
    if _dhIsCop(p) then
        return Color3.fromRGB(50, 120, 255)   -- Cop: blau
    end
    return Color3.fromRGB(255, 50, 50)         -- Krimineller: rot
end

local function _dhApplyHL(p)
    if not _dhESPEnabled or p == _dhLP then return end
    local char = p.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    if _dhHL[p] and _dhHL[p].Parent then
        _dhHL[p].FillColor = _dhESPColor(p)
        if _dhHL[p].Adornee ~= char then _dhHL[p].Adornee = char end
        return
    end
    if _dhHL[p] then pcall(function() _dhHL[p]:Destroy() end) end
    local hl = Instance.new("Highlight")
    hl.Adornee             = char
    hl.FillColor           = _dhESPColor(p)
    hl.OutlineColor        = Color3.fromRGB(255,255,255)
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 1.1
    hl.Parent              = _dhPGui
    _dhHL[p] = hl
end

local function _dhRemoveHL(p)
    if _dhHL[p] then pcall(function() _dhHL[p]:Destroy() end); _dhHL[p] = nil end
end

local function _dhClearESP()
    for p in pairs(_dhHL) do _dhRemoveHL(p) end
end

local function _dhHookP(p)
    if p == _dhLP then return end
    if p.Character then
        task.spawn(function()
            p.Character:WaitForChild("HumanoidRootPart", 5)
            _dhApplyHL(p)
        end)
    end
    p.CharacterAdded:Connect(function(c)
        task.spawn(function()
            c:WaitForChild("HumanoidRootPart", 5)
            if _dhESPEnabled then _dhApplyHL(p) end
        end)
    end)
    p.CharacterRemoving:Connect(function() _dhRemoveHL(p) end)
    -- Team-Wechsel → Farbe neu setzen
    p:GetPropertyChangedSignal("Team"):Connect(function()
        if _dhHL[p] and _dhHL[p].Parent then
            _dhHL[p].FillColor = _dhESPColor(p)
        end
    end)
end

for _, p in ipairs(_dhPlayers:GetPlayers()) do _dhHookP(p) end
_dhPlayers.PlayerAdded:Connect(_dhHookP)
_dhPlayers.PlayerRemoving:Connect(_dhRemoveHL)

-- ESP Fallback-Loop (0.15s) – erstellt fehlende Highlights nach
local _dhESPLoopRunning = true
task.spawn(function()
    while _dhESPLoopRunning do
        if _dhESPEnabled then
            for _, p in ipairs(_dhPlayers:GetPlayers()) do
                if p ~= _dhLP then
                    local char = p.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        if not _dhHL[p] or not _dhHL[p].Parent then
                            _dhApplyHL(p)
                        end
                    elseif _dhHL[p] then
                        _dhRemoveHL(p)
                    end
                end
            end
            for p in pairs(_dhHL) do
                if not p.Parent then _dhRemoveHL(p) end
            end
        end
        task.wait(0.15)
    end
end)

-- Cleanup function
function _dhStopLoops()
    _dhESPLoopRunning = false
end


-- -- Auto-Pickup (MoneyDrop) -----------------------------------------------
-- Da Hood: Bei Kills/Robs fällt ein "MoneyDrop" Part mit ProximityPrompt.
-- Wir teleportieren HRP darauf, damit der ProximityPrompt auslöst.
local _dhPickEnabled = false
local _dhPickConn    = nil

local function _dhStartAutoPick()
    if _dhPickConn then return end
    _dhPickConn = _dhRS.Heartbeat:Connect(function()
        if not _dhPickEnabled or not _dhAlive() then return end
        local hrp = _dhHRP(); if not hrp then return end
        for _, obj in ipairs(_dhWS:GetDescendants()) do
            if (obj.Name == "MoneyDrop" or obj.Name == "CashDrop"
                or obj.Name == "DropMoney" or obj.Name == "DroppedCash"
                or obj.Name == "Bag") and obj:IsA("BasePart") then
                local dist = (hrp.Position - obj.Position).Magnitude
                if dist < 60 then
                    -- Proximity-Trigger: einmal kurz teleportieren
                    pcall(function() hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0,3,0)) end)
                    -- ProximityPrompt direkt feuern falls vorhanden
                    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
                        or obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt")
                    if pp then
                        pcall(function()
                            fireproximityprompt(pp)
                        end)
                    end
                    task.wait(0.05)
                    return -- Nur ein Drop pro Frame
                end
            end
        end
    end)
end

local function _dhStopAutoPick()
    if _dhPickConn then _dhPickConn:Disconnect(); _dhPickConn = nil end
end

-- -- Auto Bank Rob ---------------------------------------------------------
-- Da Hood Bank: Im Workspace gibt es ein "Bank"-Modell mit ProximityPrompts
-- ("RobBank", "OpenVault", "FillBag" o.ä.).
-- Wir scannen nach diesen Prompts und feuern sie automatisch.
local _dhBankEnabled = false
local _dhBankConn    = nil
local _dhBankKW      = {"robbank","openvalut","fillbag","vault","bankteller","cashdrawer","opendoor","robstore","checkout"}

local function _dhFirePrompt(pp)
    -- Versuche über fireproximityprompt (Executor API), sonst via VIM
    local ok = pcall(function() fireproximityprompt(pp) end)
    if not ok and _dhVIM then
        pcall(function()
            local hrp = _dhHRP(); if not hrp then return end
            local part = pp.Parent
            if part and part:IsA("BasePart") then
                hrp.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
            end
        end)
    end
end

local function _dhStartBankRob()
    if _dhBankConn then return end
    _dhBankConn = task.spawn(function()
        while _dhBankEnabled do
            if _dhAlive() then
                local hrp = _dhHRP()
                if hrp then
                    -- Alle ProximityPrompts in Reichweite prüfen
                    for _, obj in ipairs(_dhWS:GetDescendants()) do
                        if not _dhBankEnabled then break end
                        if obj:IsA("ProximityPrompt") then
                            local n = obj.ActionText:lower() .. obj.ObjectText:lower()
                            local partN = obj.Parent and obj.Parent.Name:lower() or ""
                            local modelN = obj.Parent and obj.Parent.Parent
                                         and obj.Parent.Parent.Name:lower() or ""
                            local combined = n .. partN .. modelN
                            local match = false
                            for _, kw in ipairs(_dhBankKW) do
                                if combined:find(kw) then match = true; break end
                            end
                            if match then
                                local part = obj.Parent
                                if part and part:IsA("BasePart") then
                                    local dist = (hrp.Position - part.Position).Magnitude
                                    if dist < 50 then
                                        -- Teleportiere hin und feuer
                                        pcall(function()
                                            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                                        end)
                                        task.wait(0.1)
                                        _dhFirePrompt(obj)
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

local function _dhStopBankRob()
    _dhBankEnabled = false
    if _dhBankConn then pcall(function() task.cancel(_dhBankConn) end); _dhBankConn = nil end
end

-- -- Movement --------------------------------------------------------------
local _dhSpeedEnabled = false
local _dhFlyEnabled   = false
local _dhNoclipEnabled = false
local _dhFlyConn, _dhNoclipConn = nil, nil
local _dhFlyBV, _dhFlyBG        = nil, nil

local function _dhSetSpeed(on)
    _dhSpeedEnabled = on
    local hum = _dhHum()
    if hum then hum.WalkSpeed = on and 80 or 16 end
end

local function _dhSetFly(on)
    _dhFlyEnabled = on
    if _dhFlyConn then _dhFlyConn:Disconnect(); _dhFlyConn = nil end
    if _dhFlyBV   then _dhFlyBV:Destroy();      _dhFlyBV   = nil end
    if _dhFlyBG   then _dhFlyBG:Destroy();      _dhFlyBG   = nil end
    local hum = _dhHum()
    if not on then if hum then hum.PlatformStand = false end; return end
    local root = _dhHRP(); if not root then return end
    if hum then hum.PlatformStand = true end
    _dhFlyBG = Instance.new("BodyGyro", root)
    _dhFlyBG.MaxTorque = Vector3.new(4e4,4e4,4e4); _dhFlyBG.P = 20000
    _dhFlyBV = Instance.new("BodyVelocity", root)
    _dhFlyBV.MaxForce  = Vector3.new(4e4,4e4,4e4)
    _dhFlyConn = _dhRS.Heartbeat:Connect(function()
        if not _dhFlyEnabled then return end
        local r = _dhHRP()
        if not r or not _dhFlyBV or not _dhFlyBG then return end
        local cam = _dhWS.CurrentCamera; if not cam then return end
        local dir = Vector3.new()
        if _dhUIS:IsKeyDown(Enum.KeyCode.W)         then dir = dir + cam.CFrame.LookVector  end
        if _dhUIS:IsKeyDown(Enum.KeyCode.S)         then dir = dir - cam.CFrame.LookVector  end
        if _dhUIS:IsKeyDown(Enum.KeyCode.A)         then dir = dir - cam.CFrame.RightVector end
        if _dhUIS:IsKeyDown(Enum.KeyCode.D)         then dir = dir + cam.CFrame.RightVector end
        if _dhUIS:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0)     end
        if _dhUIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0)     end
        if dir.Magnitude > 0 then dir = dir.Unit end
        _dhFlyBV.Velocity = dir * 80
        _dhFlyBG.CFrame   = CFrame.new(r.Position, r.Position + cam.CFrame.LookVector)
    end)
end

local function _dhSetNoclip(on)
    _dhNoclipEnabled = on
    if _dhNoclipConn then _dhNoclipConn:Disconnect(); _dhNoclipConn = nil end
    if not on then return end
    _dhNoclipConn = _dhRS.Heartbeat:Connect(function()
        local char = _dhChar(); if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

-- Respawn-Reconnect
_dhLP.CharacterAdded:Connect(function()
    task.wait(1)
    if _dhSpeedEnabled    then _dhSetSpeed(true)     end
    if _dhFlyEnabled      then _dhSetFly(true)       end
    if _dhNoclipEnabled   then _dhSetNoclip(true)    end
end)

-- -- Toggle Rows -----------------------------------------------------------
local _dhRed    = Color3.fromRGB(255,  60,  90)
local _dhOrange = Color3.fromRGB(255, 140,   0)
local _dhGreen  = Color3.fromRGB( 50, 220,  80)
local _dhBlue   = Color3.fromRGB( 60, 140, 255)
local _dhPurple = Color3.fromRGB(175,  80, 255)
local _dhCyan   = Color3.fromRGB( 50, 220, 220)

-- ESP: Cops=Blau, Kriminelle=Rot
dhAddRow("Player ESP", "ESP", _dhOrange, false, function(on)
    _dhESPEnabled = on
    if not on then _dhClearESP() end
    sendNotif("Da Hood", on and "👁 ESP: Cops=🔵 Crims=🔴" or "ESP off", 2)
end)


-- Auto Pickup: MoneyDrop + Bags automatisch aufheben
dhAddRow("Auto Pickup $", "Farm", _dhGreen, false, function(on)
    _dhPickEnabled = on
    if on then _dhStartAutoPick() else _dhStopAutoPick() end
    sendNotif("Da Hood", on and "💰 Auto Pickup on" or "Auto Pickup off", 2)
end)

-- Auto Bank Rob: Bank/Store ProximityPrompts automatisch feuern
dhAddRow("Auto Bank Rob", "Rob", _dhOrange, false, function(on)
    _dhBankEnabled = on
    if on then _dhStartBankRob() else _dhStopBankRob() end
    sendNotif("Da Hood", on and "🏦 Auto Bank Rob on" or "Auto Rob off", 2)
end)


-- Speed Hack
dhAddRow("Speed Hack", "Move", _dhPurple, false, function(on)
    _dhSetSpeed(on)
    sendNotif("Da Hood", on and "⚡ Speed on" or "Speed off", 2)
end)

-- Fly
dhAddRow("Fly", "Move", _dhPurple, false, function(on)
    _dhSetFly(on)
    sendNotif("Da Hood", on and "🕊 Fly on" or "Fly off", 2)
end)

-- Noclip
dhAddRow("Noclip", "Move", _dhPurple, false, function(on)
    _dhSetNoclip(on)
    sendNotif("Da Hood", on and "👻 Noclip on" or "Noclip off", 2)
end)

-- -- Cursor Aimbot ---------------------------------------------------------
-- Lockt den Cursor auf den nächsten Spieler (3rd-Person kompatibel)
-- Funktioniert ohne Ego-Perspektive: Camera CFrame wird NICHT verändert,
-- nur die Maus-Position wird per VirtualInputManager auf das Ziel gelenkt.
do
local _dhAimEnabled   = false
local _dhAimConn      = nil
local _dhAimTarget    = nil   -- manuell gepinnter Target (nil = auto-nearest)
local _dhAimFOV       = 180   -- Suchradius in Pixel (Bildschirm-Kreis)
local _dhAimSmooth    = 0.30  -- Lerp-Faktor pro Frame (0=kein Lock, 1=instant)
local _dhAimPart      = "HumanoidRootPart"  -- "Head" oder "HumanoidRootPart"
local _dhVIM          = nil
pcall(function() _dhVIM = game:GetService("VirtualInputManager") end)
local _dhCam          = workspace.CurrentCamera
local _dhUIS3         = _SvcUIS

-- Nächsten Spieler im FOV-Kreis finden
local function _dhFindTarget()
    local vp      = _dhCam.ViewportSize
    local center  = Vector2.new(vp.X / 2, vp.Y / 2)
    local bestDist = _dhAimFOV
    local bestPl   = nil
    for _, pl in ipairs(_dhPlayers:GetPlayers()) do
        if pl == _dhLP then continue end
        local char = pl.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(_dhAimPart) or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local screenPos, onScreen = _dhCam:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local sp2 = Vector2.new(screenPos.X, screenPos.Y)
        local d   = (sp2 - center).Magnitude
        if d < bestDist then
            bestDist = d
            bestPl   = pl
        end
    end
    return bestPl
end

-- Cursor auf Ziel verschieben
local function _dhMoveCursor(target)
    if not target then return end
    local char = target.Character
    if not char then return end
    local part = char:FindFirstChild(_dhAimPart) or char:FindFirstChild("HumanoidRootPart")
    if not part then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local screenPos, onScreen = _dhCam:WorldToViewportPoint(part.Position)
    if not onScreen then return end
    local tx = math.floor(screenPos.X + 0.5)
    local ty = math.floor(screenPos.Y + 0.5)
    -- Smooth: aktuelle Cursor-Position mit Ziel interpolieren
    local curMouse = _dhUIS3:GetMouseLocation()
    local nx = math.floor(curMouse.X + (tx - curMouse.X) * _dhAimSmooth + 0.5)
    local ny = math.floor(curMouse.Y + (ty - curMouse.Y) * _dhAimSmooth + 0.5)
    if _dhVIM then
        pcall(function() _dhVIM:SendMouseMoveEvent(nx, ny, game) end)
    end
end

local function _dhStartAimbot()
    if _dhAimConn then _dhAimConn:Disconnect() end
    _dhAimConn = _SvcRS.RenderStepped:Connect(function()
        if not _dhAimEnabled then return end
        local tgt = _dhAimTarget or _dhFindTarget()
        _dhMoveCursor(tgt)
    end)
end

local function _dhStopAimbot()
    if _dhAimConn then _dhAimConn:Disconnect(); _dhAimConn = nil end
    _dhAimTarget = nil
end

dhAddRow("Cursor Aimbot", "Combat", _dhRed, false, function(on)
    _dhAimEnabled = on
    if on then
        _dhStartAimbot()
        sendNotif("Da Hood", "🎯 Cursor Aimbot ON – auto-nearest", 3)
    else
        _dhStopAimbot()
        sendNotif("Da Hood", "Cursor Aimbot off", 2)
    end
end)
end -- Cursor Aimbot block
_miscApis["DaHood"] = _dhFolderApi
pcall(function() _dhFolderApi.setActive(false) end)
end)() -- Ende Da Hood IIFE
-- APIs: Standard = Bladeball aktiv (MM2/Da Hood setzen sich im IIFE auf inaktiv)
_miscApis["Bladeball"] = _bbFolderApi
_miscSegApplyVisual()
task.defer(updateMiscSize)
-- -- Ende Da Hood Ordner ---------------------------------------------------




 -- SHADER (TLShader v2)
 ;(function() -- eigener Funktions-Scope
local _shA = false
local _shConns = {}
local _shInsts = {}

local function _shClean()
    for _, c in ipairs(_shConns) do pcall(function() c:Disconnect() end) end
    _shConns = {}
    for _, v in ipairs(_shInsts) do pcall(function() v:Destroy() end) end
    _shInsts = {}
end

local function _shApply()
    local Lighting   = game:GetService("Lighting")
    local RunService = _SvcRS
    local Players    = _SvcPlr
    local SoundService = _SvcSnd

    -- Sound beim Aktivieren
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://117945572498547"
        s.Volume = 2
        s.Parent = SoundService
        s:Play()
        _SvcDeb:AddItem(s, 5)
    end)

    -- Alte PostEffekte entfernen
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") or child:IsA("Sky") then
            pcall(function() child:Destroy() end)
        end
    end

    -- Lighting Setup
    Lighting.Brightness     = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
    Lighting.Ambient        = Color3.fromRGB(90, 90, 90)
    Lighting.ClockTime      = 13.5
    Lighting.Technology     = Enum.Technology.Future
    Lighting.ShadowSoftness = 0.25

    -- Sky
    local Sky = Instance.new("Sky", Lighting)
    table.insert(_shInsts, Sky)
    Sky.SkyboxBk       = "rbxassetid://591058823"
    Sky.SkyboxDn       = "rbxassetid://591059876"
    Sky.SkyboxFt       = "rbxassetid://591058104"
    Sky.SkyboxLf       = "rbxassetid://591057861"
    Sky.SkyboxRt       = "rbxassetid://591057625"
    Sky.SkyboxUp       = "rbxassetid://591059642"
    Sky.SunAngularSize  = 15
    Sky.MoonAngularSize = 10

    -- Schatten
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            pcall(function() obj.CastShadow = true end)
        end
    end
    local shadowConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then
            pcall(function() obj.CastShadow = true end)
        end
    end)
    table.insert(_shConns, shadowConn)

    -- Boden-Reflektionen
    local FLOOR_REFLECTANCE = 0.12
    local function isFloor(part)
        local size = part.Size
        local nameLower = part.Name:lower()
        local isFlatShape = size.Y <= 2 and size.X > 2 and size.Z > 2
        local isNamedFloor = nameLower:find("floor") or nameLower:find("ground")
                          or nameLower:find("boden") or nameLower:find("base")
                          or nameLower:find("road")  or nameLower:find("street")
        return isFlatShape or isNamedFloor
    end
    local function applyReflection(part)
        if isFloor(part) then pcall(function() part.Reflectance = FLOOR_REFLECTANCE end) end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then applyReflection(obj) end
    end
    local reflConn = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("BasePart") then task.wait(); applyReflection(obj) end
    end)
    table.insert(_shConns, reflConn)

    -- Post Effects
    local function mkFX(cls, props)
        local fx = Instance.new(cls, Lighting)
        for k, v in pairs(props) do fx[k] = v end
        table.insert(_shInsts, fx)
        return fx
    end
    mkFX("BloomEffect", {
        Name = "Shader_Bloom", Intensity = 0.8, Size = 24, Threshold = 0.95,
    })
    mkFX("SunRaysEffect", {
        Name = "Shader_Sun", Intensity = 0.04, Spread = 0.15,
    })
    mkFX("BlurEffect", {
        Name = "Shader_Blur", Size = 1.2,
    })
    mkFX("ColorCorrectionEffect", {
        Name = "Shader_Color", Contrast = 0.4, Saturation = 0.2,
        TintColor = Color3.fromRGB(255, 250, 245),
    })
end

local shRow=Instance.new("Frame",sonstigePage)
shRow.Size=UDim2.new(1,0,0,54)
shRow.BackgroundColor3=C.bg2 or _C3_BG2;shRow.BackgroundTransparency=0
shRow.BorderSizePixel=0;corner(shRow,12);shRow.LayoutOrder=5
local shRowS=_makeDummyStroke(shRow)
shRowS.Thickness=1;shRowS.Color=C.bg3 or _C3_BG3;shRowS.Transparency=0.3
local shDot=Instance.new("Frame",shRow)
shDot.Size=UDim2.new(0,3,0,34); shDot.Visible = false;shDot.Position=UDim2.new(0,0,0.5,-17)
shDot.BackgroundColor3=Color3.fromRGB(99,155,255);shDot.BackgroundTransparency=0.4
shDot.BorderSizePixel=0;corner(shDot,99)
local shLbl=Instance.new("TextLabel",shRow)
shLbl.Size=UDim2.new(0,160,0,18);shLbl.Position=UDim2.new(0,14,0,8)
shLbl.BackgroundTransparency=1;shLbl.Text="Shader"
shLbl.Font=Enum.Font.GothamBold;shLbl.TextSize=13
shLbl.TextColor3=C.text or Color3.new(1,1,1)
shLbl.TextXAlignment=Enum.TextXAlignment.Left
local shSub=Instance.new("TextLabel",shRow)
shSub.Size=UDim2.new(0,160,0,12);shSub.Position=UDim2.new(0,14,0,26)
shSub.BackgroundTransparency=1;shSub.Text="Realistic Lighting"
shSub.Font=Enum.Font.Gotham;shSub.TextSize=9
shSub.TextColor3=Color3.fromRGB(99,155,255)
shSub.TextXAlignment=Enum.TextXAlignment.Left
local shBadge=Instance.new("Frame",shRow)
shBadge.Size=UDim2.new(0,36,0,14);shBadge.Position=UDim2.new(0,179,0,8)
shBadge.BackgroundColor3=Color3.fromRGB(99,155,255);shBadge.BackgroundTransparency=0.7
shBadge.BorderSizePixel=0;corner(shBadge,99)
local shBTxt=Instance.new("TextLabel",shBadge)
shBTxt.Size=UDim2.new(1,0,1,0);shBTxt.BackgroundTransparency=1
shBTxt.Text="Misc";shBTxt.Font=Enum.Font.GothamBold
shBTxt.TextSize=8;shBTxt.TextColor3=Color3.fromRGB(99,155,255)
shBTxt.TextXAlignment=Enum.TextXAlignment.Center
local shBtnF=Instance.new("Frame",shRow)
shBtnF.Size=UDim2.new(0,80,0,26);shBtnF.Position=UDim2.new(1,-90,0.5,-13)
shBtnF.BackgroundColor3=Color3.fromRGB(10,18,40)
shBtnF.BackgroundTransparency=0.2;shBtnF.BorderSizePixel=0;corner(shBtnF,8)
local shBtnS=_makeDummyStroke(shBtnF)
shBtnS.Thickness=1;shBtnS.Color=Color3.fromRGB(99,155,255);shBtnS.Transparency=0.55
local shBtn=Instance.new("TextButton",shBtnF)
shBtn.Size=UDim2.new(1,0,1,0);shBtn.BackgroundTransparency=1
shBtn.Text="OFF";shBtn.Font=Enum.Font.GothamBold
shBtn.TextSize=11;shBtn.TextColor3=Color3.new(1,1,1);shBtn.ZIndex=5;shBtn.Active=true
local function shToggle()
    _shA = not _shA
    if _shA then
        _shClean(); pcall(_shApply)
        shBtn.Text="ON"; shBtn.TextColor3=Color3.fromRGB(99,155,255)
        twP(shBtnF,0.15,{BackgroundColor3=Color3.fromRGB(12,28,70)})
        twP(shBtnS,0.15,{Transparency=0.1})
        sendNotif("Shader","TLShader aktiv",2)
    else
        _shA=false; _shClean()
        shBtn.Text="OFF"; shBtn.TextColor3=Color3.new(1,1,1)
        twP(shBtnF,0.15,{BackgroundColor3=Color3.fromRGB(10,18,40),BackgroundTransparency=0.2})
        twP(shBtnS,0.15,{Transparency=0.55})
        sendNotif("Shader","Shader deaktiviert",2)
    end
end
shBtn.MouseButton1Click:Connect(shToggle)
shBtn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then shToggle() end end)
shBtn.MouseEnter:Connect(function()
    _playHoverSound()
    twP(shBtnF,0.08,{BackgroundTransparency=0}); twP(shBtnS,0.08,{Transparency=0.1}); twP(shBtn,0.08,{TextColor3=Color3.fromRGB(99,155,255)})
end)
shBtn.MouseLeave:Connect(function()
    if not _shA then twP(shBtnF,0.08,{BackgroundTransparency=0.2}); twP(shBtnS,0.08,{Transparency=0.55}); twP(shBtn,0.08,{TextColor3=Color3.new(1,1,1)}) end
end)
end)()
-- Ende Shader


-- Segmentleiste(~52) + ein Game-Panel variabel + ANTIVCBAN(54) + Shader(54) → Höhe dynamisch (miscLayout)
sonstigePage.Size = UDim2.new(1, 0, 0, 228)
-- Automatisch Größe aktualisieren wenn Ordner auf/zu klappt
miscLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    updateMiscSize()
end)
sSubPages = { Troll = trollPage, Movement = movePage, Visual = visualPage, Misc = sonstigePage, Combat = combatPage }
local BASE_H = S_CARD_H + 62
local function switchSCat(id)
for _, pg in pairs(sSubPages) do pg.Visible = false end
for _, cb in ipairs(sCatBtns) do
twP(cb.card, 0.15, {BackgroundColor3 = C.bg2 or _C3_BG2})
twP(cb.lbl,  0.15, {TextColor3 = C.sub or _C3_SUB})
cb.cStr.Color = C.bg3 or _C3_BG3; cb.cStr.Transparency = 0.3
cb.selBar.Visible = false
if cb.iconRef then
pcall(function()
if cb.iconRef:IsA("ImageLabel") then
-- ImageColor3 not touched for image icons (preserve original colors)
else
twP(cb.iconRef, 0.15, {TextColor3 = C.sub or _C3_SUB})
end
end)
end
end
if sActiveCat == id then
sActiveCat = nil
if _sPanelTw.p   then pcall(function() _sPanelTw.p:Cancel()   end) end
if _sPanelTw.sub then pcall(function() _sPanelTw.sub:Cancel() end) end
twP(sSubArea, 0.18, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
twP(p, 0.18, {Size = UDim2.new(0, PANEL_W, 0, BASE_H)}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
task.delay(0.2, function() pcall(function() p.ClipsDescendants = false end) end)
c.Size = UDim2.new(1, 0, 0, BASE_H - 56)
c.CanvasSize = UDim2.new(0, 0, 0, 0)
return
end
sActiveCat = id
local pg = sSubPages[id]
if pg then
pg.Visible = true
task.defer(function()
    local pgH = pg.AbsoluteSize.Y
    if pgH < 1 then pgH = pg.Size.Y.Offset end
    if pgH < 1 then pgH = 188 end
    _resizeScriptsPanel(pgH, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.24)
end)
end
for _, cb in ipairs(sCatBtns) do
if cb.id == id then
twP(cb.card, 0.20, {BackgroundColor3 = C.bg3 or _C3_BG4})
twP(cb.lbl,  0.20, {TextColor3 = C.text})
cb.cStr.Color = cb.col; cb.cStr.Transparency = 0.5
cb.selBar.Visible = true
if cb.iconRef then
pcall(function()
if cb.iconRef:IsA("ImageLabel") then
-- ImageColor3 not touched for image icons (preserve original colors)
else
twP(cb.iconRef, 0.20, {TextColor3 = cb.col})
end
end)
end
end
end
end
;(function() -- eigener Funktions-Scope – eigenes Register-Limit
for i, cat in ipairs(SCRIPT_CATS) do



local xOff = (i - 1) * (S_CARD_W + S_CARD_GAP)
local card = Instance.new("Frame", sGrid)
card.Size = UDim2.new(0, S_CARD_W, 0, S_CARD_H)
card.Position = UDim2.new(0, xOff, 0, 0)
card.BackgroundColor3 = C.bg2; card.BackgroundTransparency = 0
card.BorderSizePixel = 0; corner(card, 12)
local cStr = _makeDummyStroke(card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local selBar = Instance.new("Frame", card)
selBar.Size = UDim2.new(1,-16,0,2); selBar.Position = UDim2.new(0,8,0,0)
selBar.BackgroundColor3 = _scriptCatAccent(cat.col); selBar.BackgroundTransparency = 0
selBar.BorderSizePixel = 0; selBar.Visible = false; corner(selBar, 99)
local _iconRef = nil
if cat.img then
local iconImg = Instance.new("ImageLabel", card)
local _iSz = cat.iconSize or 28
iconImg.Size = UDim2.new(0,_iSz,0,_iSz); iconImg.Position = UDim2.new(0.5,-_iSz/2,0,-(_iSz/2)+29)
iconImg.BackgroundTransparency = 1; iconImg.Image = cat.img
iconImg.ImageColor3 = Color3.new(1,1,1); iconImg.ScaleType = Enum.ScaleType.Fit
_iconRef = iconImg
else
local icon = Instance.new("TextLabel", card)
icon.Size = UDim2.new(1,0,0,32); icon.Position = UDim2.new(0,0,0,8)
icon.BackgroundTransparency = 1; icon.Text = cat.icon or ""
icon.Font = Enum.Font.GothamBlack; icon.TextSize = 22
icon.TextColor3 = C.sub or _C3_SUB; icon.TextXAlignment = Enum.TextXAlignment.Center
_iconRef = icon
end
local lbl = Instance.new("TextLabel", card)
lbl.Size = UDim2.new(1,-4,0,16); lbl.Position = UDim2.new(0,2,1,-22)
lbl.BackgroundTransparency = 1; lbl.Text = cat.id:upper()
lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
lbl.TextColor3 = C.sub or _C3_SUB; lbl.TextXAlignment = Enum.TextXAlignment.Center
local btn = Instance.new("TextButton", card)
btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 6
local catId = cat.id
btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
if sActiveCat ~= catId then
twP(card, 0.1, {BackgroundColor3 = C.bg3 or _C3_BG4})
end
end)
btn.MouseLeave:Connect(function()
if sActiveCat ~= catId then
twP(card, 0.1, {BackgroundColor3 = C.bg2 or _C3_BG2})
end
end)
local _sCatBtnLock = false
local function sCatActivate()
    if _sCatBtnLock then return end
    _sCatBtnLock = true
    task.delay(0.35, function() _sCatBtnLock = false end)
    switchSCat(catId)
end
btn.MouseButton1Click:Connect(sCatActivate)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then sCatActivate() end
end)
table.insert(sCatBtns, {
    id=catId, card=card, lbl=lbl, selBar=selBar, cStr=cStr, iconRef=_iconRef,
    baseCol = cat.col,
    col = _scriptCatAccent(cat.col),
})
end
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function()
    for _, cb in ipairs(sCatBtns) do
        local tc = _scriptCatAccent(cb.baseCol)
        cb.col = tc
        cb.selBar.BackgroundColor3 = tc
        if sActiveCat == cb.id then
            cb.cStr.Color = tc
            cb.cStr.Transparency = 0.5
        end
    end
    pcall(_miscSegRefreshTheme)
end
end)()
p.Size = UDim2.new(0, PANEL_W, 0, BASE_H)
end
_act_following, _act_followTarget, _act_followRSConn = false, nil, nil  -- upvalue assigned here (forward-declared above)
local _act_bangAnimTrack, _act_bangHoverVel = nil, nil
local _act_bangOscTime = 0
local function _act_stopFollow()
_act_following = false
if _act_followRSConn  then _act_followRSConn:Disconnect();  _act_followRSConn  = nil end
_act_followTarget = nil; _act_bangOscTime = 0
if _act_bangAnimTrack then
pcall(function() _act_bangAnimTrack:Stop() end); _act_bangAnimTrack = nil
end
if _act_bangHoverVel then
pcall(function() _act_bangHoverVel:Destroy() end); _act_bangHoverVel = nil
end
local hum = getHumanoid(); if hum then hum.WalkSpeed = 16; if not flyActive then hum.PlatformStand = false end end
pcall(function() setFreeze(false) end)
end
local function _act_startFollow(targetPlayer)
_act_stopFollow()
local targetChar = targetPlayer and targetPlayer.Character
if not targetChar then sendNotif("Bang V2", "Target has no character!", 2); return false end
_act_following = true; _act_followTarget = targetPlayer; _act_bangOscTime = 0
pcall(function()
local myChar = LocalPlayer.Character
local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
if hum then
_act_bangAnimTrack = _AF_loadAndPlayAnimation(hum, "116967071050039")
if _act_bangAnimTrack then _act_bangAnimTrack:Play(); _act_bangAnimTrack:AdjustSpeed(2) end
end
end)
pcall(function()
local myRoot = getRootPart()
if myRoot then
if _act_bangHoverVel then pcall(function() _act_bangHoverVel:Destroy() end) end
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; _act_bangHoverVel = bv
end
end)
_act_followRSConn = _RSConnect(function(dt)
if not _act_following then return end
local tHRP   = _act_followTarget and _act_followTarget.Character and
_act_followTarget.Character:FindFirstChild("HumanoidRootPart")
local myRoot = getRootPart()
if not tHRP or not myRoot then
_act_following = false
task.defer(function() pcall(function() setActionsToggle(false) end) end); return
end
if not _act_bangHoverVel or _act_bangHoverVel.Parent ~= myRoot then
if _act_bangHoverVel then pcall(function() _act_bangHoverVel:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myRoot; _act_bangHoverVel = bv2
end
_act_bangOscTime = _act_bangOscTime + dt * 10.0
pcall(function()
myRoot.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3.5 - (math.sin(_act_bangOscTime) * 3))
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
end)
end)
return true
end
local _ACT = {}
local setActionsToggle
local stopSitOnHead,  startSitOnHead
local stopPiggyback,  startPiggyback
local stopPiggyback2, startPiggyback2
local stopKiss,       startKiss
local stopBackpack,   startBackpack
local stopOrbit,      startOrbit
local stopUpsideDown, startUpsideDown
local stopCrossUD,    startCrossUD
local stopFriend,     startFriend
local stopSpinning,   startSpinning
local stopLicking,    startLicking
local stopSucking,    startSucking
local stopSuckIt,     startSuckIt
local stopBackshots,  startBackshots
local stopLayFuck,    startLayFuck
local stopFacefuck,    startFacefuck
local stopPussySpread,startPussySpread
local stopHug,        startHug
local stopHug2,       startHug2
local stopCarry,      startCarry
local stopShoulderSit, startShoulderSit
local stopQA74,       startQA74
local stopGhost,      startGhost
local stopBB,         startBB
_SOH = {  -- upvalue assigned here (forward-declared above)
active=false, bodyPos=nil, bodyGyro=nil, conn=nil,
target=nil, hoverVel=nil, animTrack=nil, animConn=nil,
charConn=nil, ANIM_ID="119898270336796",
}
ppActive  = false  -- upvalue assigned here (forward-declared above)
local setFreeze = nil
do
local function sohStopAnim()
if _SOH.animConn  then _SOH.animConn:Disconnect();  _SOH.animConn  = nil end
if _SOH.charConn  then _SOH.charConn:Disconnect();  _SOH.charConn  = nil end
if _SOH.animTrack then
pcall(function() _SOH.animTrack:AdjustSpeed(1); _SOH.animTrack:Stop() end)
_SOH.animTrack = nil
end
end
local function sohPlayAnim(char)
if not char then return end
if _SOH.ANIM_ID == "0" or _SOH.ANIM_ID == "" then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
if hum.RigType == Enum.HumanoidRigType.R6 then return end
local track = _AF_getReliableActionTrack(hum, _SOH.ANIM_ID, "SitOnHeadAnim")
if not track then return end
if setFreeze then setFreeze(true) end
_SOH.animTrack = track
if _SOH.animConn then _SOH.animConn:Disconnect() end
task.spawn(function()
task.wait(2)
if not _SOH.active or not _SOH.animTrack then return end
pcall(function() _SOH.animTrack:AdjustSpeed(0); _SOH.animTrack.TimePosition = 2 end)
while _tlAlive() and _SOH.active and _SOH.animTrack do
pcall(function() _SOH.animTrack.TimePosition = 2 end); task.wait(0.03)
end
end)
_SOH.animConn = track.Stopped:Connect(function()
if _SOH.active and _SOH.animTrack then
pcall(function() _SOH.animTrack:AdjustSpeed(0); _SOH.animTrack.TimePosition = 2 end)
end
end)
end
local function sohStartAnim()
sohStopAnim()
task.spawn(function() sohPlayAnim(LocalPlayer.Character) end)
_SOH.charConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _SOH.active then task.wait(0.5); task.spawn(function() sohPlayAnim(char) end) end
end)
end
stopSitOnHead = function()
if _SOH.conn then _SOH.conn:Disconnect(); _SOH.conn = nil end
_SOH.active = false; _SOH.target = nil
if _SOH.bodyPos  then pcall(function() _SOH.bodyPos:Destroy()  end); _SOH.bodyPos  = nil end
if _SOH.bodyGyro then pcall(function() _SOH.bodyGyro:Destroy() end); _SOH.bodyGyro = nil end
if not ppActive and setFreeze then setFreeze(false) end
sohStopAnim()
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
pcall(function()
local _lpc = LocalPlayer.Character
local r =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if r then r.AssemblyLinearVelocity = Vector3.zero end end)
end)
end
startSitOnHead = function(targetPlayer)
stopSitOnHead()
local myChar = LocalPlayer.Character
local tChar  = targetPlayer and targetPlayer.Character
if not myChar or not tChar then sendNotif("Sit on Head","No character!",2); return end
local myRoot = myChar:FindFirstChild("HumanoidRootPart")
local tHead  = tChar:FindFirstChild("Head")
if not myRoot or not tHead then sendNotif("Sit on Head","Missing parts!",2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local r=getRootPart(); if r then r:SetNetworkOwner(LocalPlayer) end end)
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e9,1e9,1e9); bp.P = 500000; bp.D = 2500
bp.Position = tHead.Position + Vector3.new(0,1,0); bp.Parent = myRoot; _SOH.bodyPos = bp
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e9,1e9,1e9); bg.P = 500000; bg.D = 2500
bg.CFrame = tHead.CFrame; bg.Parent = myRoot; _SOH.bodyGyro = bg
local tp = tHead.Position + Vector3.new(0,1,0); local cp = tp
_SOH.active = true; _SOH.target = targetPlayer
sendNotif("Sit on Head","Sitting on "..targetPlayer.Name.." 👑",3)
sohStartAnim(); if setFreeze then setFreeze(true) end
_SOH.conn = _RSConnect(function()
if not _SOH.active then return end
local tc2  = _SOH.target and _SOH.target.Character
local head = tc2 and tc2:FindFirstChild("Head"); if not head then return end
local myC  = LocalPlayer.Character
local myR  = myC and myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not _SOH.bodyPos or _SOH.bodyPos.Parent ~= myR then
pcall(function() if _SOH.bodyPos then _SOH.bodyPos:Destroy() end end)
_SOH.bodyPos = Instance.new("BodyPosition"); _SOH.bodyPos.MaxForce = Vector3.new(1e9,1e9,1e9)
_SOH.bodyPos.P = 500000; _SOH.bodyPos.D = 2500; _SOH.bodyPos.Parent = myR
end
if not _SOH.bodyGyro or _SOH.bodyGyro.Parent ~= myR then
pcall(function() if _SOH.bodyGyro then _SOH.bodyGyro:Destroy() end end)
_SOH.bodyGyro = Instance.new("BodyGyro"); _SOH.bodyGyro.MaxTorque = Vector3.new(1e9,1e9,1e9)
_SOH.bodyGyro.P = 500000; _SOH.bodyGyro.D = 2500; _SOH.bodyGyro.Parent = myR
end
tp = head.Position + Vector3.new(0,1,0)
cp = cp:Lerp(tp, 0.98)
_SOH.bodyPos.Position = cp
_SOH.bodyGyro.CFrame  = CFrame.new(myR.Position, myR.Position + head.CFrame.LookVector)
local h2 = myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end
_AF = {  -- upvalue assigned here (forward-declared above)
kissActive=false, backpackActive=false, orbitActive=false,
upsideDownActive=false, crossUDActive=false, friendActive=false, spinningActive=false,
lickingActive=false, suckingActive=false, suckItActive=false, backshotsActive=false, layFuckActive=false, facefuckActive=false,
pussySpreadActive=false, hugActive=false, hug2Active=false, qa74Active=false,
carryActive=false, shoulderSitActive=false,
pp2Active=false, ghostActive=false, bbActive=false,
friendDanceTrack=nil, spinAngle=0,
udConn=nil, udTarget=nil, udBodyPos=nil, udBodyGyro=nil,
}
local ACTIONS_DEF = {
{ key = "bang",        label = "Bang V2",      col = Color3.fromRGB(43,221,146)  },
{ key = "soh",         label = "On Head",      col = _C3_RED   },
{ key = "piggyback",   label = "Piggyback",    col = Color3.fromRGB(255,170,50)  },
{ key = "piggyback2",  label = "Piggyback2",   col = Color3.fromRGB(255,200,80)  },
{ key = "kiss",        label = "Kiss",          col = Color3.fromRGB(255,120,180) },
{ key = "backpack",    label = "Backpack",      col = Color3.fromRGB(120,180,255) },
{ key = "orbit",       label = "Orbit TP",      col = Color3.fromRGB(100,220,255) },
{ key = "upsidedown",  label = "Upside Down",  col = Color3.fromRGB(200,100,255) },
{ key = "crossud",     label = "Cross UD",     col = Color3.fromRGB(180,80,255)  },
{ key = "friend",      label = "Friend",        col = Color3.fromRGB(255,200,80)  },
{ key = "spinning",    label = "Spinning",      col = Color3.fromRGB(80,220,200)  },
{ key = "licking",     label = "Licking",       col = Color3.fromRGB(255,80,160)  },
{ key = "backshots",   label = "Backshots",     col = _C3_DRED   },
{ key = "layfuck",     label = "Lay Fuck",      col = Color3.fromRGB(255,80,100)  },
{ key = "pussyspread", label = "Pussy Spread",  col = Color3.fromRGB(220,80,220)  },
{ key = "hug",         label = "Hug",           col = Color3.fromRGB(100,220,255) },
{ key = "hug2",        label = "Hug 2",         col = Color3.fromRGB(80,200,240)  },
{ key = "carry",       label = "Carry",         col = Color3.fromRGB(255,160,60)  },
{ key = "shouldersit", label = "Shouldersit",   col = Color3.fromRGB(60,200,140)  },
{ key = "sucking",     label = "Sucking",       col = Color3.fromRGB(255,80,160)  },
{ key = "suckit",      label = "Suck It",       col = Color3.fromRGB(255,100,180) },
{ key = "ghost",       label = "Ghost",         col = Color3.fromRGB(160,160,255) },
}
;(function()
local p, c = makePanel("Actions", C.accent)
local function buildPlayerDropdown(playerPill, playerPillLbl, playerPillAvatar, playerPillBtn, getTarget, setTarget)
local dropdownOpen = false
local DD_ITEM_H = 34; local DD_MAX = 5
local ddFrame = Instance.new("Frame", ScreenGui)
ddFrame.Name = "FollowDropdown"
ddFrame.BackgroundColor3 = C.bg2; ddFrame.BackgroundTransparency = 0.06
ddFrame.BorderSizePixel = 0; ddFrame.ZIndex = 11000; ddFrame.Visible = false
ddFrame.ClipsDescendants = true
corner(ddFrame, 14); gradStroke(ddFrame, 1.5, 0.22)
local ddBg = Instance.new("UIGradient", ddFrame)
ddBg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, Color3.fromRGB(4,16,7)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(2,10,4)),
}; ddBg.Rotation = 135
local ddScroll = Instance.new("ScrollingFrame", ddFrame)
ddScroll.Size = UDim2.new(1,0,1,0); ddScroll.BackgroundTransparency = 1
ddScroll.BorderSizePixel = 0; ddScroll.ScrollBarThickness = 3
ddScroll.ScrollBarImageColor3 = C.gradL
ddScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ddScroll.CanvasSize = UDim2.new(0,0,0,0); ddScroll.ZIndex = 11001
local ddList = Instance.new("UIListLayout", ddScroll)
ddList.SortOrder = _ENUM_SORT_ORDER_LAYOUT; ddList.Padding = UDim.new(0,2)
local function positionDropdown()
local abs = playerPill.AbsolutePosition; local absSize = playerPill.AbsoluteSize
ddFrame.Position = UDim2.new(0, abs.X, 0, abs.Y + absSize.Y + 4)
ddFrame.Size = UDim2.new(0, absSize.X, 0, ddFrame.Size.Y.Offset)
end
local ddSlot = {tween=nil}
local function closeDropdown()
if not dropdownOpen then return end; dropdownOpen = false
local t = twC(ddSlot,ddFrame,0.18,{Size=UDim2.new(0,ddFrame.Size.X.Offset,0,0)},Enum.EasingStyle.Quart,Enum.EasingDirection.In)
t.Completed:Connect(function() if not dropdownOpen then ddFrame.Visible = false end end)
end
local function buildDropdown()
for _, ch in ipairs(ddScroll:GetChildren()) do
if ch:IsA("GuiObject") then ch:Destroy() end
end
local plrs = {}
for _, pl in ipairs(Players:GetPlayers()) do
if pl ~= LocalPlayer then table.insert(plrs, pl) end
end
if #plrs == 0 then
local noLbl = Instance.new("TextLabel", ddScroll)
noLbl.Size = UDim2.new(1,0,0,DD_ITEM_H); noLbl.BackgroundTransparency = 1
noLbl.Text = T.actions_no_players; noLbl.Font = Enum.Font.GothamBold; noLbl.TextSize = 13
noLbl.TextColor3 = C.text; noLbl.ZIndex = 11002
end
local selectedFollowTarget = getTarget()
for _, pl in ipairs(plrs) do
local row = Instance.new("Frame", ddScroll)
row.Size = UDim2.new(1,-8,0,DD_ITEM_H); row.BackgroundColor3 = C.bg3
row.BackgroundTransparency = 0.85; row.BorderSizePixel = 0; row.ZIndex = 11002
corner(row, 10)
local avatarClip = Instance.new("Frame", row)
avatarClip.Size = UDim2.new(0,24,0,24); avatarClip.Position = UDim2.new(0,5,0.5,-12)
avatarClip.BackgroundColor3 = C.bg3; avatarClip.BackgroundTransparency = 0.4
avatarClip.BorderSizePixel = 0; avatarClip.ZIndex = 11003; avatarClip.ClipsDescendants = true
corner(avatarClip, 99)
local avatarImg = Instance.new("ImageLabel", avatarClip)
avatarImg.Size = UDim2.new(1,0,1,0); avatarImg.BackgroundTransparency = 1
avatarImg.Image = "rbxassetid://142509179"; avatarImg.ImageColor3 = C.sub
avatarImg.ScaleType = Enum.ScaleType.Crop; avatarImg.ZIndex = 11004
task.spawn(function()
local ok, url = pcall(function()
return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
end)
if ok and url and avatarImg.Parent then
avatarImg.Image = url; avatarImg.ImageColor3 = _C3_WHITE
end
end)
local nameLbl = Instance.new("TextLabel", row)
nameLbl.Size = UDim2.new(1,-44,1,0); nameLbl.Position = UDim2.new(0,34,0,0)
nameLbl.BackgroundTransparency = 1
nameLbl.Text = pl.DisplayName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = (selectedFollowTarget == pl) and C.accent or C.text
nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 11003
if selectedFollowTarget == pl then
local dot = Instance.new("Frame", row)
dot.Size = UDim2.new(0,5,0,5); dot.Position = UDim2.new(1,-12,0.5,-2)
dot.BackgroundColor3 = C.accent; dot.BorderSizePixel = 0; corner(dot, 99); dot.ZIndex = 11003
end
local rowBtn = Instance.new("TextButton", row)
rowBtn.Size = UDim2.new(1,0,1,0); rowBtn.BackgroundTransparency = 1
rowBtn.Text = ""; rowBtn.ZIndex = 11005
rowBtn.MouseEnter:Connect(function()
_playHoverSound()
twP(row,0.1,{BackgroundTransparency=0.55})
twP(nameLbl,0.1,{TextColor3=C.accent})
end)
rowBtn.MouseLeave:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.85})
if getTarget() ~= pl then tw(nameLbl,0.1,{TextColor3=C.text}):Play() end
end)
rowBtn.MouseButton1Click:Connect(function()
setTarget(pl)
playerPillLbl.Text = pl.DisplayName; playerPillLbl.TextColor3 = C.accent
if playerPillAvatar then
playerPillAvatar.Image = "rbxassetid://142509179"
playerPillAvatar.ImageColor3 = C.sub
task.spawn(function()
local ok2, url2 = pcall(function()
return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
end)
if ok2 and url2 and playerPillAvatar and playerPillAvatar.Parent then
playerPillAvatar.Image = url2
playerPillAvatar.ImageColor3 = _C3_WHITE
end
end)
end
twP(playerPill,0.08,{BackgroundTransparency=0.0})
task.delay(0.1, function() tw(playerPill,0.15,{BackgroundTransparency=0.08}):Play() end)
closeDropdown()
end)
rowBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        setTarget(pl)
        playerPillLbl.Text = pl.DisplayName; playerPillLbl.TextColor3 = C.accent
        if playerPillAvatar then
            playerPillAvatar.Image = "rbxassetid://142509179"
            playerPillAvatar.ImageColor3 = C.sub
            task.spawn(function()
                local ok2, url2 = pcall(function()
                    return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                end)
                if ok2 and url2 and playerPillAvatar and playerPillAvatar.Parent then
                    playerPillAvatar.Image = url2
                    playerPillAvatar.ImageColor3 = _C3_WHITE
                end
            end)
        end
        twP(playerPill,0.08,{BackgroundTransparency=0.0})
        task.delay(0.1, function() tw(playerPill,0.15,{BackgroundTransparency=0.08}):Play() end)
        closeDropdown()
    end
end)
end
local count = math.max(1, #plrs)
ddScroll.CanvasSize = UDim2.new(0,0,0,count*(DD_ITEM_H+2)+6)
return math.min(count, DD_MAX)*(DD_ITEM_H+2)+6
end
local function openDropdown()
if dropdownOpen then closeDropdown(); return end
dropdownOpen = true; positionDropdown()
local targetH = buildDropdown()
ddFrame.Size = UDim2.new(0,playerPill.AbsoluteSize.X,0,0); ddFrame.Visible = true
twP(ddFrame,0.22,{Size=UDim2.new(0,playerPill.AbsoluteSize.X,0,targetH)},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end
playerPillBtn.MouseButton1Click:Connect(openDropdown)
playerPillBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then openDropdown() end
end)
UserInputService.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function()
if not dropdownOpen then return end
local mp = UserInputService:GetMouseLocation()
local abs = ddFrame.AbsolutePosition; local absS = ddFrame.AbsoluteSize
local inside = mp.X>=abs.X and mp.X<=abs.X+absS.X and mp.Y>=abs.Y and mp.Y<=abs.Y+absS.Y
local onPill = false; pcall(function()
local pa = playerPill.AbsolutePosition; local ps = playerPill.AbsoluteSize
onPill = mp.X>=pa.X and mp.X<=pa.X+ps.X and mp.Y>=pa.Y and mp.Y<=pa.Y+ps.Y
end)
if not inside and not onPill then closeDropdown() end
end)
end
end)
return { open = openDropdown, close = closeDropdown }
end
p.Size = UDim2.new(0, PANEL_W, 0, 340)
local stopFollow    = _act_stopFollow
local startFollow   = _act_startFollow
local playerPill, playerPillAvatar, playerPillLbl, playerPillBtn
local actionPill, actionPillLbl, actionPillBtn, actionRow
local statusDot, statusTxt
do
local infoCard = Instance.new("Frame", c)
infoCard.Size = UDim2.new(1,0,0,52); infoCard.Position = UDim2.new(0,0,0,0)
infoCard.BackgroundColor3 = C.bg2 or _C3_BG2; infoCard.BackgroundTransparency = 0
infoCard.BorderSizePixel = 0; corner(infoCard, 12)
local infoStr = _makeDummyStroke(infoCard)
infoStr.Thickness = 1; infoStr.Color = C.bg3 or _C3_BG3; infoStr.Transparency = 0.3
local infoDot = Instance.new("Frame", infoCard)
infoDot.Size = UDim2.new(0,3,0,32); infoDot.Visible = false; infoDot.Position = UDim2.new(0,0,0.5,-16)
infoDot.BackgroundColor3 = C.accent; infoDot.BackgroundTransparency = 0.4
infoDot.BorderSizePixel = 0; corner(infoDot, 99)
local infoIcon = Instance.new("TextLabel", infoCard)
infoIcon.Size = UDim2.new(0,36,1,0); infoIcon.Position = UDim2.new(0,10,0,0)
infoIcon.BackgroundTransparency = 1; infoIcon.Text = "ℹ"
infoIcon.Font = Enum.Font.GothamBlack; infoIcon.TextSize = 21
infoIcon.TextXAlignment = Enum.TextXAlignment.Center
local infoLbl = Instance.new("TextLabel", infoCard)
infoLbl.Size = UDim2.new(1,-52,0,20); infoLbl.Position = UDim2.new(0,46,0,7)
infoLbl.BackgroundTransparency = 1; infoLbl.Text = T.actions_info_lbl
infoLbl.Font = Enum.Font.GothamBold; infoLbl.TextSize = 13
infoLbl.TextColor3 = C.text; infoLbl.TextXAlignment = Enum.TextXAlignment.Left
local infoSub = Instance.new("TextLabel", infoCard)
infoSub.Size = UDim2.new(1,-52,0,14); infoSub.Position = UDim2.new(0,46,0,29)
infoSub.BackgroundTransparency = 1; infoSub.Text = T.actions_info_sub
infoSub.Font = Enum.Font.GothamBold; infoSub.TextSize = 13
infoSub.TextColor3 = C.text; infoSub.TextXAlignment = Enum.TextXAlignment.Left
local pickRow = Instance.new("Frame", c)
pickRow.Size = UDim2.new(1,0,0,46); pickRow.Position = UDim2.new(0,0,0,62)
pickRow.BackgroundColor3 = C.bg2 or _C3_BG2; pickRow.BackgroundTransparency = 0
pickRow.BorderSizePixel = 0; corner(pickRow, 12)
local pickStr = _makeDummyStroke(pickRow)
pickStr.Thickness = 1; pickStr.Color = C.bg3 or _C3_BG3; pickStr.Transparency = 0.3
local pickDot = Instance.new("Frame", pickRow)
pickDot.Size = UDim2.new(0,3,0,26); pickDot.Visible = false; pickDot.Position = UDim2.new(0,0,0.5,-13)
pickDot.BackgroundColor3 = C.accent; pickDot.BackgroundTransparency = 0.4
pickDot.BorderSizePixel = 0; corner(pickDot, 99)
local pickLbl = Instance.new("TextLabel", pickRow)
pickLbl.Size = UDim2.new(0,60,1,0); pickLbl.Position = UDim2.new(0,16,0,0)
pickLbl.BackgroundTransparency = 1; pickLbl.Text = T.actions_pick_target
pickLbl.Font = Enum.Font.GothamBold; pickLbl.TextSize = 13
pickLbl.TextColor3 = C.text; pickLbl.TextXAlignment = Enum.TextXAlignment.Left
playerPill = Instance.new("Frame", pickRow)
playerPill.Size = UDim2.new(0,138,0,28); playerPill.Position = UDim2.new(0,72,0.5,-14)
playerPill.BackgroundColor3 = C.bg3; playerPill.BackgroundTransparency = 0.08
playerPill.BorderSizePixel = 0
corner(playerPill, 11)
local playerPillStr = _makeDummyStroke(playerPill)
playerPillStr.Thickness = 1; playerPillStr.Color = C.bg3 or _C3_BG3; playerPillStr.Transparency = 0.3
local playerPillAvatarClip = Instance.new("Frame", playerPill)
playerPillAvatarClip.Size = UDim2.new(0,20,0,20); playerPillAvatarClip.Position = UDim2.new(0,5,0.5,-10)
playerPillAvatarClip.BackgroundColor3 = C.bg3; playerPillAvatarClip.BackgroundTransparency = 0.4
playerPillAvatarClip.BorderSizePixel = 0; playerPillAvatarClip.ZIndex = 3; playerPillAvatarClip.ClipsDescendants = true
corner(playerPillAvatarClip, 99)
playerPillAvatar = Instance.new("ImageLabel", playerPillAvatarClip)
playerPillAvatar.Size = UDim2.new(1,0,1,0); playerPillAvatar.BackgroundTransparency = 1
playerPillAvatar.Image = "rbxassetid://142509179"; playerPillAvatar.ImageColor3 = C.sub
playerPillAvatar.ScaleType = Enum.ScaleType.Crop; playerPillAvatar.ZIndex = 4
playerPillLbl = Instance.new("TextLabel", playerPill)
playerPillLbl.Size = UDim2.new(1,-44,1,0); playerPillLbl.Position = UDim2.new(0,30,0,0)
playerPillLbl.BackgroundTransparency = 1; playerPillLbl.Text = T.actions_player_pill
playerPillLbl.Font = Enum.Font.GothamBold; playerPillLbl.TextSize = 13
playerPillLbl.TextColor3 = C.text; playerPillLbl.TextXAlignment = Enum.TextXAlignment.Left
playerPillLbl.TextTruncate = Enum.TextTruncate.AtEnd
playerPillBtn = Instance.new("TextButton", playerPill)
playerPillBtn.Size = UDim2.new(1,0,1,0); playerPillBtn.BackgroundTransparency = 1
playerPillBtn.Text = ""; playerPillBtn.ZIndex = 6
actionPill = Instance.new("Frame", pickRow)
actionPill.Size = UDim2.new(0,138,0,28); actionPill.Position = UDim2.new(1,-153,0.5,-14)
actionPill.BackgroundColor3 = C.bg3; actionPill.BackgroundTransparency = 0.08
actionPill.BorderSizePixel = 0
corner(actionPill, 11)
local actionPillStr = _makeDummyStroke(actionPill)
actionPillStr.Thickness = 1; actionPillStr.Color = C.bg3 or _C3_BG3; actionPillStr.Transparency = 0.3
actionPillLbl = Instance.new("TextLabel", actionPill)
actionPillLbl.Size = UDim2.new(1,-22,1,0); actionPillLbl.Position = UDim2.new(0,8,0,0)
actionPillLbl.BackgroundTransparency = 1; actionPillLbl.Text = T.actions_action_pill
actionPillLbl.Font = Enum.Font.GothamBold; actionPillLbl.TextSize = 13
actionPillLbl.TextColor3 = C.text; actionPillLbl.TextXAlignment = Enum.TextXAlignment.Left
actionPillLbl.TextTruncate = Enum.TextTruncate.AtEnd
actionPillBtn = Instance.new("TextButton", actionPill)
actionPillBtn.Size = UDim2.new(1,0,1,0); actionPillBtn.BackgroundTransparency = 1
actionPillBtn.Text = ""; actionPillBtn.ZIndex = 6
actionRow = Instance.new("Frame", c)
actionRow.Size = UDim2.new(1,0,0,46); actionRow.Position = UDim2.new(0,0,0,118)
actionRow.BackgroundColor3 = C.bg2; actionRow.BackgroundTransparency = 0
actionRow.BorderSizePixel = 0
corner(actionRow, 12)
local actionRowStr = _makeDummyStroke(actionRow)
actionRowStr.Thickness = 1; actionRowStr.Color = C.bg3 or _C3_BG3; actionRowStr.Transparency = 0.3
local actionRowDot = Instance.new("Frame", actionRow)
actionRowDot.Size = UDim2.new(0,3,0,26); actionRowDot.Visible = false; actionRowDot.Position = UDim2.new(0,0,0.5,-13)
actionRowDot.BackgroundColor3 = C.accent; actionRowDot.BackgroundTransparency = 0.4
actionRowDot.BorderSizePixel = 0; corner(actionRowDot, 99)
local actionRowLbl = Instance.new("TextLabel", actionRow)
actionRowLbl.Size = UDim2.new(0,140,1,0); actionRowLbl.Position = UDim2.new(0,16,0,0)
actionRowLbl.BackgroundTransparency = 1; actionRowLbl.Text = T.actions_row_lbl
actionRowLbl.Font = Enum.Font.GothamBold; actionRowLbl.TextSize = 13
actionRowLbl.TextColor3 = C.text; actionRowLbl.TextXAlignment = Enum.TextXAlignment.Left
local statusCard = Instance.new("Frame", c)
statusCard.Size = UDim2.new(1,0,0,36); statusCard.Position = UDim2.new(0,0,0,174)
statusCard.BackgroundColor3 = C.bg2; statusCard.BackgroundTransparency = 0.18
statusCard.BorderSizePixel = 0
corner(statusCard, 12)
local statusStr = _makeDummyStroke(statusCard)
statusStr.Thickness = 1; statusStr.Color = C.bg3 or _C3_BG3; statusStr.Transparency = 0.3
statusDot = Instance.new("Frame", statusCard)
statusDot.Size = UDim2.new(0,8,0,8); statusDot.Position = UDim2.new(0,14,0.5,-4)
statusDot.BackgroundColor3 = C.red; statusDot.BorderSizePixel = 0; corner(statusDot, 99)
statusTxt = Instance.new("TextLabel", statusCard)
statusTxt.Size = UDim2.new(1,-40,1,0); statusTxt.Position = UDim2.new(0,30,0,0)
statusTxt.BackgroundTransparency = 1; statusTxt.Text = T.actions_status_idle
statusTxt.Font = Enum.Font.GothamBold; statusTxt.TextSize = 13
statusTxt.TextColor3 = C.text; statusTxt.TextXAlignment = Enum.TextXAlignment.Left
end
local selectedFollowTarget = nil
local selectedAction       = nil
local ACTIONS = ACTIONS_DEF
do
local udHoverVel = nil
stopUpsideDown = function()
if _AF.udConn then _AF.udConn:Disconnect(); _AF.udConn = nil end
_AF.upsideDownActive = false; _AF.udTarget = nil
if _AF.udBodyPos  then pcall(function() _AF.udBodyPos:Destroy()  end); _AF.udBodyPos  = nil end
if _AF.udBodyGyro then pcall(function() _AF.udBodyGyro:Destroy() end); _AF.udBodyGyro = nil end
safeStand()
end
startUpsideDown = function(targetPlayer)
stopUpsideDown()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Upside Down", "No character!", 2); return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local tHRP0 = targetChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not tHRP0 or not hum then sendNotif("Upside Down", "Missing parts!", 2); return false end
hum.PlatformStand = true; hum.WalkSpeed = 0
pcall(function() myHRP:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myHRP, "PhysicsRepRootPart", tHRP0)
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp.P = 500000; bp.D = 2500
bp.Position = tHRP0.Position + Vector3.new(0, 3.5, 0)
bp.Parent = myHRP; _AF.udBodyPos = bp
local _udTargetPos  = tHRP0.Position + Vector3.new(0, 3.5, 0)
local _udCurrentPos = _udTargetPos
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg.P = 500000; bg.D = 2500
bg.CFrame = tHRP0.CFrame * CFrame.Angles(math.rad(180), 0, 0)
bg.Parent = myHRP; _AF.udBodyGyro = bg
_AF.upsideDownActive = true; _AF.udTarget = targetPlayer
sendNotif("Upside Down", "Hanging over " .. targetPlayer.Name .. " 🦇", 3)
_AF.udConn = _RSConnect(function()
if not _AF.upsideDownActive then return end
local tc   = _AF.udTarget and _AF.udTarget.Character
local tHRP = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myR  =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP or not myR then
_AF.upsideDownActive = false
task.defer(function() pcall(function() setActionsToggle(false) end) end); return
end
if not _AF.udBodyPos or _AF.udBodyPos.Parent ~= myR then
if _AF.udBodyPos then pcall(function() _AF.udBodyPos:Destroy() end) end
local bp2 = Instance.new("BodyPosition")
bp2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp2.P = 500000; bp2.D = 2500; bp2.Parent = myR; _AF.udBodyPos = bp2
end
if not _AF.udBodyGyro or _AF.udBodyGyro.Parent ~= myR then
if _AF.udBodyGyro then pcall(function() _AF.udBodyGyro:Destroy() end) end
local bg2 = Instance.new("BodyGyro")
bg2.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg2.P = 500000; bg2.D = 2500; bg2.Parent = myR; _AF.udBodyGyro = bg2
end
_udTargetPos = tHRP.Position + Vector3.new(0, 3.5, 0)
local _udA = 1-(1-0.98)^(1/60*60); _udCurrentPos = _udCurrentPos:Lerp(_udTargetPos,_udA)
_AF.udBodyPos.Position = _udCurrentPos
_AF.udBodyGyro.CFrame = tHRP.CFrame * CFrame.Angles(math.rad(180), 0, 0)
end)
return true
end
end
do
stopCrossUD = function()
if _AF.crossUDConn  then _AF.crossUDConn:Disconnect();  _AF.crossUDConn  = nil end
_AF.crossUDActive = false; _AF.crossUDTarget = nil
if _AF.crossUDBP  then pcall(function() _AF.crossUDBP:Destroy()  end); _AF.crossUDBP  = nil end
if _AF.crossUDBG  then pcall(function() _AF.crossUDBG:Destroy()  end); _AF.crossUDBG  = nil end
local char = LocalPlayer.Character
if char and _AF.crossUDOrigC0 then
for _, m in ipairs(char:GetDescendants()) do
if m:IsA("Motor6D") and _AF.crossUDOrigC0[m] then
pcall(function() m.C0 = _AF.crossUDOrigC0[m] end)
end
end
end
_AF.crossUDOrigC0 = nil
safeStand()
end
startCrossUD = function(targetPlayer)
stopCrossUD()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Cross UD", "No character!", 2); return false end
local myHRP  = myChar:FindFirstChild("HumanoidRootPart")
local tHRP0  = targetChar:FindFirstChild("HumanoidRootPart")
local tHead  = targetChar:FindFirstChild("Head")
local hum    = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not tHRP0 or not hum then sendNotif("Cross UD", "Missing parts!", 2); return false end
hum.PlatformStand = true
pcall(function() myHRP:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myHRP, "PhysicsRepRootPart", tHRP0)
_AF.crossUDOrigC0 = {}
for _, m in ipairs(myChar:GetDescendants()) do
if m:IsA("Motor6D") then
_AF.crossUDOrigC0[m] = m.C0
end
end
local function applyTPose(char2)
if not char2 then return end
local tors = char2:FindFirstChild("UpperTorso") or char2:FindFirstChild("Torso")
if not tors then return end
local rArm = char2:FindFirstChild("Right Arm")
local lArm = char2:FindFirstChild("Left Arm")
if rArm and lArm then
local rJ = tors:FindFirstChild("Right Shoulder")
local lJ = tors:FindFirstChild("Left Shoulder")
if rJ then pcall(function() rJ.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0) end) end
if lJ then pcall(function() lJ.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0) end) end
end
local rUArm = char2:FindFirstChild("RightUpperArm")
local lUArm = char2:FindFirstChild("LeftUpperArm")
if rUArm then
local rJ = rUArm:FindFirstChildOfClass("Motor6D")
if rJ then pcall(function() rJ.C0 = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(-90)) end) end
end
if lUArm then
local lJ = lUArm:FindFirstChildOfClass("Motor6D")
if lJ then pcall(function() lJ.C0 = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90)) end) end
end
end
task.spawn(function() applyTPose(myChar) end)
local headY = tHead and tHead.Size.Y or 0.6
local HOVER_Y = 3.5 + headY
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp.P = 500000; bp.D = 2500
bp.Position = tHRP0.Position + Vector3.new(0, HOVER_Y, 0)
bp.Parent = myHRP; _AF.crossUDBP = bp
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg.P = 500000; bg.D = 2500
bg.CFrame = tHRP0.CFrame * CFrame.Angles(math.rad(180), 0, 0)
bg.Parent = myHRP; _AF.crossUDBG = bg
local _curPos = tHRP0.Position + Vector3.new(0, HOVER_Y, 0)
_AF.crossUDActive = true; _AF.crossUDTarget = targetPlayer
sendNotif("Cross UD", "Crossing over " .. targetPlayer.Name .. " ✝", 3)
_AF.crossUDConn = _RSConnect(function()
if not _AF.crossUDActive then return end
local tc   = _AF.crossUDTarget and _AF.crossUDTarget.Character
local tHRP = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myR  = _lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP or not myR then
_AF.crossUDActive = false
task.defer(function() pcall(function() setActionsToggle(false) end) end); return
end
if not _AF.crossUDBP or _AF.crossUDBP.Parent ~= myR then
if _AF.crossUDBP then pcall(function() _AF.crossUDBP:Destroy() end) end
local bp2 = Instance.new("BodyPosition")
bp2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp2.P = 500000; bp2.D = 2500; bp2.Parent = myR; _AF.crossUDBP = bp2
end
if not _AF.crossUDBG or _AF.crossUDBG.Parent ~= myR then
if _AF.crossUDBG then pcall(function() _AF.crossUDBG:Destroy() end) end
local bg2 = Instance.new("BodyGyro")
bg2.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg2.P = 500000; bg2.D = 2500; bg2.Parent = myR; _AF.crossUDBG = bg2
end
local tHead2 = tc:FindFirstChild("Head")
local hY2 = tHead2 and tHead2.Size.Y or 0.6
local targetPos = tHRP.Position + Vector3.new(0, 3.5 + hY2, 0)
local alpha = 1-(1-0.98)^(1/60*60)
_curPos = _curPos:Lerp(targetPos, alpha)
_AF.crossUDBP.Position = _curPos
_AF.crossUDBG.CFrame   = tHRP.CFrame * CFrame.Angles(math.rad(180), 0, 0)
local myHum = _lpc and _lpc:FindFirstChildOfClass("Humanoid")
if myHum and not myHum.PlatformStand then
myHum.PlatformStand = true
task.spawn(function() applyTPose(_lpc) end)
end
end)
return true
end
end
do
local friendConn   = nil
local friendTarget = nil
local friendHoverVel = nil
stopFriend = function()
if friendConn then friendConn:Disconnect(); friendConn = nil end
_AF.friendActive = false; friendTarget = nil
if _AF.friendDanceTrack then pcall(function() _AF.friendDanceTrack:Stop() end); _AF.friendDanceTrack = nil end
if friendHoverVel then pcall(function() friendHoverVel:Destroy() end); friendHoverVel = nil end
safeStand()
end
startFriend = function(targetPlayer)
stopFriend()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Friend", "No character!", 2); return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local tHRP0 = targetChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not tHRP0 or not hum then sendNotif("Friend", "Missing parts!", 2); return false end
hum.PlatformStand = true; hum.WalkSpeed = 0
pcall(function() myHRP:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myHRP, "PhysicsRepRootPart", tHRP0)
pcall(function()
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = Vector3.zero
bv.Parent = myHRP; friendHoverVel = bv
end)
myHRP.CFrame = tHRP0.CFrame * CFrame.new(3, 0, 0)
pcall(function()
_AF.friendDanceTrack = _AF_loadAndPlayAnimation(hum, "182435933")
if _AF.friendDanceTrack then _AF.friendDanceTrack:Play() end
end)
_AF.friendActive = true; friendTarget = targetPlayer
sendNotif("Friend", "Befriending " .. targetPlayer.Name .. " 🤝", 3)
friendConn = _RSConnect(function()
if not _AF.friendActive then return end
local tc   = friendTarget and friendTarget.Character
local tHRP = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myR  =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP or not myR then
_AF.friendActive = false
task.defer(function() pcall(function() setActionsToggle(false) end) end); return
end
if not friendHoverVel or friendHoverVel.Parent ~= myR then
if friendHoverVel then pcall(function() friendHoverVel:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0); bv2.Velocity = Vector3.zero
bv2.Parent = myR; friendHoverVel = bv2
end
pcall(function()
myR.CFrame = tHRP.CFrame * CFrame.new(3, 0, 0)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
end)
return true
end
end
do
local spinConn   = nil
local spinTarget = nil
local spinHoverVel = nil
stopSpinning = function()
if spinConn then spinConn:Disconnect(); spinConn = nil end
_AF.spinningActive = false; spinTarget = nil; _AF.spinAngle = 0
if spinHoverVel then pcall(function() spinHoverVel:Destroy() end); spinHoverVel = nil end
safeStand()
end
startSpinning = function(targetPlayer)
stopSpinning()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Spinning", "No character!", 2); return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local tHRP0 = targetChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not tHRP0 or not hum then sendNotif("Spinning", "Missing parts!", 2); return false end
hum.PlatformStand = true; hum.WalkSpeed = 0
pcall(function() myHRP:SetNetworkOwner(LocalPlayer) end)
pcall(function()
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = Vector3.zero
bv.Parent = myHRP; spinHoverVel = bv
end)
_AF.spinAngle = 0
myHRP.CFrame = CFrame.new(
tHRP0.Position + Vector3.new(math.cos(0) * 7, 0, math.sin(0) * 7), tHRP0.Position
)
_AF.spinningActive = true; spinTarget = targetPlayer
sendNotif("Spinning", "Orbiting " .. targetPlayer.Name .. " 🔄", 3)
spinConn = _RSConnect(function()
if not _AF.spinningActive then return end
local tc   = spinTarget and spinTarget.Character
local tHRP = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myR  =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP or not myR then
_AF.spinningActive = false
task.defer(function() pcall(function() setActionsToggle(false) end) end); return
end
if not spinHoverVel or spinHoverVel.Parent ~= myR then
if spinHoverVel then pcall(function() spinHoverVel:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0); bv2.Velocity = Vector3.zero
bv2.Parent = myR; spinHoverVel = bv2
end
_AF.spinAngle = _AF.spinAngle + 0.05
pcall(function()
myR.CFrame = CFrame.new(
tHRP.Position + Vector3.new(math.cos(_AF.spinAngle) * 7, 0, math.sin(_AF.spinAngle) * 7),
tHRP.Position
)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
end)
return true
end
end
local function stopCurrentAction()
pcall(stopCurrentEmote)
pcall(stopAnimEmotes)
if _act_following       then stopFollow();        _act_following       = false end
if _SOH.active          then stopSitOnHead();     _SOH.active          = false end
if ppActive             then stopPiggyback();     ppActive             = false end
if _AF.pp2Active        then stopPiggyback2();    _AF.pp2Active        = false end
if _AF.kissActive       then stopKiss();          _AF.kissActive       = false end
if _AF.backpackActive   then stopBackpack();      _AF.backpackActive   = false end
if _AF.orbitActive      then stopOrbit();         _AF.orbitActive      = false end
if _AF.upsideDownActive then stopUpsideDown();    _AF.upsideDownActive = false end
if _AF.crossUDActive    then stopCrossUD();       _AF.crossUDActive    = false end
if _AF.friendActive     then stopFriend();        _AF.friendActive     = false end
if _AF.spinningActive   then stopSpinning();      _AF.spinningActive   = false end
if _AF.lickingActive    then stopLicking();       _AF.lickingActive    = false end
if _AF.suckingActive    then stopSucking();       _AF.suckingActive    = false end
if _AF.suckItActive     then stopSuckIt();        _AF.suckItActive     = false end
if _AF.backshotsActive  then stopBackshots();     _AF.backshotsActive  = false end
if _AF.layFuckActive    then stopLayFuck();       _AF.layFuckActive    = false end
if _AF.pussySpreadActive then stopPussySpread();  _AF.pussySpreadActive = false end
if _AF.hugActive        then stopHug();           _AF.hugActive        = false end
if _AF.hug2Active       then stopHug2();          _AF.hug2Active       = false end
if _AF.carryActive      then stopCarry();         _AF.carryActive      = false end
if _AF.shoulderSitActive then stopShoulderSit();  _AF.shoulderSitActive = false end
if _AF.qa74Active       then stopQA74();          _AF.qa74Active       = false end
if _AF.ghostActive      then stopGhost();         _AF.ghostActive      = false end
if _AF.bbActive         then stopBB();            _AF.bbActive         = false end
pcall(function() if not noclipActive then setNoclip(false) end end)
pcall(safeStand)
emotesWalkEnabled = false
if EmoteWalkButton then EmoteWalkButton.Image = defaultButtonImage end
end
local actDdOpen = false
local ACT_IH = 34; local ACT_MX = 3
local actDdFrame = Instance.new("Frame", ScreenGui)
actDdFrame.Name = "ActionsDropdown"
actDdFrame.BackgroundColor3 = Color3.fromRGB(4,16,7); actDdFrame.BackgroundTransparency = 0.18
actDdFrame.BorderSizePixel = 0; actDdFrame.ZIndex = 50; actDdFrame.Visible = false
actDdFrame.ClipsDescendants = true
corner(actDdFrame, 14); gradStroke(actDdFrame, 1.5, 0.22)
local actDdBg = Instance.new("UIGradient", actDdFrame)
actDdBg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0,   Color3.fromRGB(6,20,9)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(4,14,7)),
ColorSequenceKeypoint.new(1,   Color3.fromRGB(2,10,4)),
}
actDdBg.Rotation = 135
local actDdScroll = Instance.new("ScrollingFrame", actDdFrame)
actDdScroll.Size = UDim2.new(1,0,1,0); actDdScroll.BackgroundTransparency = 1
actDdScroll.BorderSizePixel = 0; actDdScroll.ScrollBarThickness = 3
actDdScroll.ScrollBarImageColor3 = C.gradL
actDdScroll.ScrollingDirection = Enum.ScrollingDirection.Y
actDdScroll.CanvasSize = UDim2.new(0,0,0,0); actDdScroll.ZIndex = 51
local actDdList = Instance.new("UIListLayout", actDdScroll)
actDdList.SortOrder = _ENUM_SORT_ORDER_LAYOUT; actDdList.Padding = UDim.new(0,2)
local function posActDd()
local abs = actionPill.AbsolutePosition; local absS = actionPill.AbsoluteSize
actDdFrame.Position = UDim2.new(0, abs.X, 0, abs.Y + absS.Y + 4)
actDdFrame.Size = UDim2.new(0, absS.X, 0, actDdFrame.Size.Y.Offset)
end
local actDdSlot = {tween=nil}
local function closeActDd()
if not actDdOpen then return end; actDdOpen = false
local t = twC(actDdSlot,actDdFrame,0.18,{Size=UDim2.new(0,actDdFrame.Size.X.Offset,0,0)},Enum.EasingStyle.Quart,Enum.EasingDirection.In)
t.Completed:Connect(function() if not actDdOpen then actDdFrame.Visible = false end end)
end
local function buildActDd()
for _, ch in ipairs(actDdScroll:GetChildren()) do
if ch:IsA("GuiObject") then ch:Destroy() end
end
for _, act in ipairs(ACTIONS) do
local row = Instance.new("Frame", actDdScroll)
row.Size = UDim2.new(1,-8,0,ACT_IH); row.BackgroundColor3 = C.bg3
row.BackgroundTransparency = 0.85; row.BorderSizePixel = 0; row.ZIndex = 52
corner(row, 10)
local pad = Instance.new("UIPadding", row); pad.PaddingLeft = UDim.new(0, 11)
local nameLbl = Instance.new("TextLabel", row)
nameLbl.Size = UDim2.new(1,-10,1,0); nameLbl.BackgroundTransparency = 1
nameLbl.Text = act.label; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = (selectedAction == act.key) and act.col or C.text
nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 53
if selectedAction == act.key then
local dot = Instance.new("Frame", row)
dot.Size = UDim2.new(0,5,0,5); dot.Position = UDim2.new(1,-12,0.5,-2)
dot.BackgroundColor3 = act.col; dot.BorderSizePixel = 0
corner(dot, 99); dot.ZIndex = 53
end
local rBtn = Instance.new("TextButton", row)
rBtn.Size = UDim2.new(1,0,1,0); rBtn.BackgroundTransparency = 1
rBtn.Text = ""; rBtn.ZIndex = 54
rBtn.MouseEnter:Connect(function()
_playHoverSound()
tw(row,0.1,{BackgroundTransparency=0.55}):Play(); tw(nameLbl,0.1,{TextColor3=act.col}):Play()
end)
rBtn.MouseLeave:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.85})
if selectedAction ~= act.key then tw(nameLbl,0.1,{TextColor3=C.text}):Play() end
end)
rBtn.MouseButton1Click:Connect(function()
selectedAction = act.key
actionPillLbl.Text = act.label; actionPillLbl.TextColor3 = act.col
twP(actionPill,0.08,{BackgroundTransparency=0.0})
task.delay(0.1, function() tw(actionPill,0.15,{BackgroundTransparency=0.08}):Play() end)
closeActDd()
end)
rBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        selectedAction = act.key
        actionPillLbl.Text = act.label; actionPillLbl.TextColor3 = act.col
        twP(actionPill,0.08,{BackgroundTransparency=0.0})
        task.delay(0.1, function() tw(actionPill,0.15,{BackgroundTransparency=0.08}):Play() end)
        closeActDd()
    end
end)
end
local cnt = #ACTIONS
actDdScroll.CanvasSize = UDim2.new(0,0,0,cnt*(ACT_IH+2)+6)
return math.min(cnt, ACT_MX)*(ACT_IH+2)+6
end
local function openActDd()
if actDdOpen then closeActDd(); return end; actDdOpen = true; posActDd()
local th = buildActDd(); actDdFrame.Size = UDim2.new(0,actionPill.AbsoluteSize.X,0,0); actDdFrame.Visible = true
twC(actDdSlot,actDdFrame,0.22,{Size=UDim2.new(0,actionPill.AbsoluteSize.X,0,th)},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end
actionPillBtn.MouseButton1Click:Connect(openActDd)
actionPillBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then openActDd() end
end)
UserInputService.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function()
if actDdOpen then
local mp = UserInputService:GetMouseLocation()
local ab = actDdFrame.AbsolutePosition; local abS = actDdFrame.AbsoluteSize
local ins = mp.X>=ab.X and mp.X<=ab.X+abS.X and mp.Y>=ab.Y and mp.Y<=ab.Y+abS.Y
local onP = false; pcall(function()
local pa = actionPill.AbsolutePosition; local ps = actionPill.AbsoluteSize
onP = mp.X>=pa.X and mp.X<=pa.X+ps.X and mp.Y>=pa.Y and mp.Y<=pa.Y+ps.Y
end)
if not ins and not onP then closeActDd() end
end
end)
end
end)
local ddAPI = buildPlayerDropdown(
playerPill, playerPillLbl, playerPillAvatar, playerPillBtn,
function() return selectedFollowTarget end,
function(pl) selectedFollowTarget = pl end
)
local closeDropdown = ddAPI.close
local openDropdown  = ddAPI.open
local _, setActionsToggle, _ = makeToggle(actionRow, 405, 11, false, function(on)
if on then
if not selectedFollowTarget then
sendNotif("Actions", T.actions_select_player, 2)
task.defer(function() setActionsToggle(false) end); return
end
if not selectedAction then
sendNotif("Actions", T.actions_select_action, 2)
task.defer(function() setActionsToggle(false) end); return
end
stopCurrentAction()
local ok = false
if selectedAction == "bang" then
ok = startFollow(selectedFollowTarget)
elseif selectedAction == "soh" then
startSitOnHead(selectedFollowTarget); ok = true
elseif selectedAction == "piggyback" then
startPiggyback(selectedFollowTarget); ok = true
elseif selectedAction == "piggyback2" then
startPiggyback2(selectedFollowTarget); ok = true
elseif selectedAction == "kiss" then
startKiss(selectedFollowTarget); ok = true
elseif selectedAction == "backpack" then
startBackpack(selectedFollowTarget); ok = true
elseif selectedAction == "orbit" then
startOrbit(selectedFollowTarget); ok = true
elseif selectedAction == "upsidedown" then
ok = startUpsideDown(selectedFollowTarget)
elseif selectedAction == "crossud" then
ok = startCrossUD(selectedFollowTarget)
elseif selectedAction == "friend" then
ok = startFriend(selectedFollowTarget)
elseif selectedAction == "spinning" then
ok = startSpinning(selectedFollowTarget)
elseif selectedAction == "licking" then
startLicking(selectedFollowTarget); ok = true
elseif selectedAction == "backshots" then
startBackshots(selectedFollowTarget); ok = true
elseif selectedAction == "layfuck" then
startLayFuck(selectedFollowTarget); ok = true
elseif selectedAction == "pussyspread" then
startPussySpread(selectedFollowTarget); ok = true
elseif selectedAction == "hug" then
startHug(selectedFollowTarget); ok = true
elseif selectedAction == "hug2" then
startHug2(selectedFollowTarget); ok = true
elseif selectedAction == "carry" then
startCarry(selectedFollowTarget); ok = true
elseif selectedAction == "shouldersit" then
startShoulderSit(selectedFollowTarget); ok = true
elseif selectedAction == "sucking" then
startSucking(selectedFollowTarget); ok = true
elseif selectedAction == "suckit" then
startSuckIt(selectedFollowTarget); ok = true
elseif selectedAction == "ghost" then
startGhost(selectedFollowTarget); ok = true
end
if ok then
statusDot.BackgroundColor3 = C.accent
local n = selectedFollowTarget.Name
statusTxt.Text = selectedAction == "bang"        and (T.actions_following..n)
or  selectedAction == "soh"         and ("On Head: "..n)
or  selectedAction == "kiss"        and ("Kiss: "..n)
or  selectedAction == "backpack"    and ("Backpack: "..n)
or  selectedAction == "orbit"       and ("Orbit: "..n)
or  selectedAction == "upsidedown"  and ("Upside Down: "..n)
or  selectedAction == "crossud"     and ("Cross UD: "..n)
or  selectedAction == "friend"      and ("Friend: "..n)
or  selectedAction == "spinning"    and ("Spinning: "..n)
or  selectedAction == "licking"     and ("Licking: "..n)
or  selectedAction == "backshots"   and ("Backshots: "..n)
or  selectedAction == "layfuck"     and ("Lay Fuck: "..n)
or  selectedAction == "pussyspread" and ("Pussy Spread: "..n)
or  selectedAction == "hug"         and ("Hug: "..n)
or  selectedAction == "hug2"        and ("Hug 2: "..n)
or  selectedAction == "carry"       and ("Carry: "..n)
or  selectedAction == "shouldersit" and ("Shouldersit: "..n)
or  selectedAction == "sucking"     and ("Sucking: "..n)
or  selectedAction == "suckit"      and ("Suck It: "..n)
or  selectedAction == "ghost"       and ("Ghost: "..n)
or  ("Piggyback: "..n)
statusTxt.TextColor3 = C.accent
else
task.defer(function() setActionsToggle(false) end)
end
else
stopCurrentAction()
setFreeze(false)
statusDot.BackgroundColor3 = C.red
statusTxt.Text = T.actions_status_idle
statusTxt.TextColor3 = C.text
sendNotif("Actions", T.actions_stopped, 1)
end
end)
setFollowToggle = setActionsToggle
_G.TLActionsStop = function()
setActionsToggle(false)
end
_G.TLActions = {
stopAll = function()
setActionsToggle(false)
end,
start     = function(key, target)
pcall(function() setNoclip(true) end)
if key == "bang"       then return startFollow(target)
elseif key == "soh"    then startSitOnHead(target); return true
elseif key == "piggyback" then startPiggyback(target); return true
elseif key == "piggyback2" then startPiggyback2(target); return true
elseif key == "kiss"   then startKiss(target); return true
elseif key == "backpack" then startBackpack(target); return true
elseif key == "orbit"  then startOrbit(target); return true
elseif key == "upsidedown" then return startUpsideDown(target)
elseif key == "crossud"    then return startCrossUD(target)
elseif key == "friend" then return startFriend(target)
elseif key == "spinning" then return startSpinning(target)
elseif key == "licking"  then startLicking(target); return true
elseif key == "sucking"  then startSucking(target); return true
elseif key == "suck_it"  then startSuckIt(target);  return true
elseif key == "backshots" then startBackshots(target); return true
elseif key == "layfuck"   then startLayFuck(target);   return true
elseif key == "pussyspread" then startPussySpread(target); return true
elseif key == "hug"  then startHug(target);  return true
elseif key == "hug2" then startHug2(target); return true
elseif key == "facefuck" then startFacefuck(target); return true
elseif key == "qa74" then startQA74(target); return true
elseif key == "ghost" then startGhost(target); return true
elseif key == "carry" then startCarry(target); return true
elseif key == "shouldersit" then startShoulderSit(target); return true
end
return false
end,
}
p.Size = UDim2.new(0, PANEL_W, 0, 226)
LocalPlayer.CharacterAdded:Connect(function()
if _act_following or _SOH.active or ppActive or _AF.orbitActive
or _AF.kissActive or _AF.lickingActive or _AF.suckingActive or _AF.backshotsActive
or _AF.backpackActive or _AF.upsideDownActive or _AF.friendActive
or _AF.spinningActive or _AF.pussySpreadActive or _AF.hugActive or _AF.qa74Active
or _AF.facefuckActive or _AF.ghostActive or _AF.bbActive then
stopCurrentAction()
task.defer(function() pcall(function() setActionsToggle(false) end) end)
statusDot.BackgroundColor3 = C.red
statusTxt.Text = "Inactive (Respawn)"
statusTxt.TextColor3 = C.text
end
end)
local freezeEnabled = false
setFreeze = function(on)
freezeEnabled = on
pcall(function()
if getgenv and getgenv().TLAnimFreeze then getgenv().TLAnimFreeze(on) end
end)
end
_SOH.active    = false
do local function _TLact_Piggyback() do
local ppConn      = nil
ppActive          = false
local ppTarget    = nil
local ppBodyPos   = nil
local ppBodyGyro  = nil
local ppAnimTrack = nil
local ppAnimConn  = nil
local ppCharConn  = nil
local function ppStopAnim()
if ppAnimConn then ppAnimConn:Disconnect(); ppAnimConn = nil end
if ppCharConn then ppCharConn:Disconnect(); ppCharConn = nil end
if ppAnimTrack then
pcall(function() ppAnimTrack:AdjustSpeed(1); ppAnimTrack:Stop() end)
ppAnimTrack = nil
end
end
local function ppPlayAnim(char)
if not char then return end
if PIGGYBACK_ANIM_ID == "0" or PIGGYBACK_ANIM_ID == "" then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
if hum.RigType == Enum.HumanoidRigType.R6 then return end
local track = _AF_getReliableActionTrack(hum, PIGGYBACK_ANIM_ID, "PiggybackAnim")
if not track then return end
setFreeze(true)
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
ppAnimTrack = track
if ppAnimConn then ppAnimConn:Disconnect() end
ppAnimConn = track.Stopped:Connect(function()
if ppActive then
task.wait(0.05)
if ppActive then pcall(function() ppPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function ppStartAnim()
ppStopAnim()
task.spawn(function() ppPlayAnim(LocalPlayer.Character) end)
ppCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if ppActive then task.wait(0.5); task.spawn(function() ppPlayAnim(char) end) end
end)
end
stopPiggyback = function()
if ppConn then ppConn:Disconnect(); ppConn = nil end
ppActive = false; ppTarget = nil
if not _SOH.active then setFreeze(false) end
ppStopAnim()
if ppBodyPos  then pcall(function() ppBodyPos:Destroy()  end); ppBodyPos  = nil end
if ppBodyGyro then pcall(function() ppBodyGyro:Destroy() end); ppBodyGyro = nil end
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startPiggyback = function(targetPlayer)
stopPiggyback()
local myChar = LocalPlayer.Character; local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Piggyback", "No character!", 2); return end
local myRoot = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Piggyback", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e6, 1e6, 1e6); bp.P = 500000; bp.D = 2500
bp.Position = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0)
bp.Parent = myRoot; ppBodyPos = bp
local _ppTP = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0); local _ppCP = _ppTP
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6); bg.P = 500000; bg.D = 2500
bg.CFrame = tgtTorso.CFrame; bg.Parent = myRoot; ppBodyGyro = bg
ppActive = true; ppTarget = targetPlayer
sendNotif("Piggyback", "Clinging to " .. targetPlayer.Name .. " 🐵", 3)
ppStartAnim()
ppConn = _RSConnect(function()
if not ppActive then return end
local tc = ppTarget and ppTarget.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart"); if not myR then return end
if not ppBodyPos or ppBodyPos.Parent ~= myR then
if ppBodyPos then pcall(function() ppBodyPos:Destroy() end) end
local bp2 = Instance.new("BodyPosition"); bp2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp2.P = 500000; bp2.D = 2500; bp2.Parent = myR; ppBodyPos = bp2
end
if not ppBodyGyro or ppBodyGyro.Parent ~= myR then
if ppBodyGyro then pcall(function() ppBodyGyro:Destroy() end) end
local bg2 = Instance.new("BodyGyro"); bg2.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg2.P = 500000; bg2.D = 2500; bg2.Parent = myR; ppBodyGyro = bg2
end
_ppTP = torso.Position + torso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0)
local _ppA = 1-(1-0.98)^(1/60*60); _ppCP = _ppCP:Lerp(_ppTP,_ppA)
ppBodyPos.Position = _ppCP
ppBodyGyro.CFrame  = CFrame.new(myR.Position, myR.Position + torso.CFrame.LookVector)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Piggyback() end
do local function _TLact_Piggyback2() do
local pp2Conn      = nil
_AF.pp2Active          = false
local pp2Target    = nil
local pp2BodyPos   = nil
local pp2BodyGyro  = nil
local pp2AnimTrack = nil
local pp2AnimConn  = nil
local pp2CharConn  = nil
local function pp2StopAnim()
if pp2AnimConn then pp2AnimConn:Disconnect(); pp2AnimConn = nil end
if pp2CharConn then pp2CharConn:Disconnect(); pp2CharConn = nil end
if pp2AnimTrack then
pcall(function() pp2AnimTrack:AdjustSpeed(1); pp2AnimTrack:Stop() end)
pp2AnimTrack = nil
end
end
local function pp2PlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
if hum.RigType == Enum.HumanoidRigType.R6 then return end
local track = _AF_getReliableActionTrack(hum, PIGGYBACK2_ANIM_ID, "Piggyback2Anim")
if not track then return end
setFreeze(true)
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
pp2AnimTrack = track
if pp2AnimConn then pp2AnimConn:Disconnect() end
pp2AnimConn = track.Stopped:Connect(function()
if _AF.pp2Active then
task.wait(0.05)
if _AF.pp2Active then pcall(function() pp2PlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function pp2StartAnim()
pp2StopAnim()
task.spawn(function() pp2PlayAnim(LocalPlayer.Character) end)
pp2CharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.pp2Active then task.wait(0.5); task.spawn(function() pp2PlayAnim(char) end) end
end)
end
stopPiggyback2 = function()
if pp2Conn then pp2Conn:Disconnect(); pp2Conn = nil end
_AF.pp2Active = false; pp2Target = nil
if not _SOH.active and not ppActive then setFreeze(false) end
pp2StopAnim()
if pp2BodyPos  then pcall(function() pp2BodyPos:Destroy()  end); pp2BodyPos  = nil end
if pp2BodyGyro then pcall(function() pp2BodyGyro:Destroy() end); pp2BodyGyro = nil end
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startPiggyback2 = function(targetPlayer)
stopPiggyback2()
local myChar = LocalPlayer.Character; local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Piggyback2", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Piggyback2", "Missing parts!", 2); return end
local hum = getHumanoid()
if hum then hum.PlatformStand = true end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e6, 1e6, 1e6); bp.P = 500000; bp.D = 2500
bp.Position = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0)
bp.Parent = myRoot; pp2BodyPos = bp
local _pp2TP = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0)
local _pp2CP = _pp2TP
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6); bg.P = 500000; bg.D = 2500
bg.CFrame = tgtTorso.CFrame; bg.Parent = myRoot; pp2BodyGyro = bg
_AF.pp2Active = true; pp2Target = targetPlayer
sendNotif("Piggyback2", "Clinging to " .. targetPlayer.Name .. " 🐵", 3)
pp2StartAnim()
pp2Conn = _RSConnect(function(dt)
if not _AF.pp2Active then return end
local tc    = pp2Target and pp2Target.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart"); if not myR then return end
if not pp2BodyPos or pp2BodyPos.Parent ~= myR then
if pp2BodyPos then pcall(function() pp2BodyPos:Destroy() end) end
local bp2 = Instance.new("BodyPosition"); bp2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp2.P = 500000; bp2.D = 2500; bp2.Parent = myR; pp2BodyPos = bp2
end
if not pp2BodyGyro or pp2BodyGyro.Parent ~= myR then
if pp2BodyGyro then pcall(function() pp2BodyGyro:Destroy() end) end
local bg2 = Instance.new("BodyGyro"); bg2.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg2.P = 500000; bg2.D = 2500; bg2.Parent = myR; pp2BodyGyro = bg2
end
_pp2TP = torso.Position + torso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0)
local _pp2A = 1-(1-0.98)^(dt*60); _pp2CP = _pp2CP:Lerp(_pp2TP,_pp2A)
pp2BodyPos.Position = _pp2CP
pp2BodyGyro.CFrame  = CFrame.new(myR.Position, myR.Position + torso.CFrame.LookVector)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Piggyback2() end
do local function _TLact_Kiss() do
local kissConn      = nil
local kissTarget    = nil
local kissBodyPos   = nil
local kissBodyGyro  = nil
local _kissCP       = Vector3.new(0,0,0)
local kissAnimTrack = nil
local kissAnimConn  = nil
local kissCharConn  = nil
local KISS_ANIM_ID = "102367337136163"
local function kissStopAnim()
if kissAnimConn then kissAnimConn:Disconnect(); kissAnimConn = nil end
if kissCharConn then kissCharConn:Disconnect(); kissCharConn = nil end
if kissAnimTrack then
pcall(function() kissAnimTrack:AdjustSpeed(1); kissAnimTrack:Stop() end)
kissAnimTrack = nil
end
end
local function kissPlayAnim(char)
if not char then return end
if KISS_ANIM_ID == "0" or KISS_ANIM_ID == "" then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
if hum.RigType == Enum.HumanoidRigType.R6 then return end
local track = _AF_getReliableActionTrack(hum, KISS_ANIM_ID, "KissAnim")
if not track then return end
setFreeze(true)
kissAnimTrack = track
if kissAnimConn then kissAnimConn:Disconnect() end
kissAnimConn = track.Stopped:Connect(function()
if _AF.kissActive then
task.wait(0.05)
if _AF.kissActive then pcall(function() kissPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function kissStartAnim()
kissStopAnim()
task.spawn(function() kissPlayAnim(LocalPlayer.Character) end)
kissCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.kissActive then task.wait(0.5); task.spawn(function() kissPlayAnim(char) end) end
end)
end
stopKiss = function()
_AF.kissActive = false; kissTarget = nil
if kissConn     then kissConn:Disconnect();     kissConn     = nil end
if kissBodyPos  then pcall(function() kissBodyPos:Destroy()  end); kissBodyPos  = nil end
if kissBodyGyro then pcall(function() kissBodyGyro:Destroy() end); kissBodyGyro = nil end
kissStopAnim()
    
    local myChar = LocalPlayer.Character
    local myR = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    
    if myR then
        pcall(function() sethiddenproperty(myR, "PhysicsRepRootPart", nil) end)
        pcall(function() myR.Anchored = false end)
        pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
        pcall(function() myR.AssemblyAngularVelocity = _V3_ZERO end)
        pcall(function()
            for _, o in ipairs(myR:GetChildren()) do
                if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity")
                or o:IsA("BodyPosition") or o:IsA("BodyGyro") then
                    o:Destroy()
                end
            end
        end)
    end
    
    if hum then
        pcall(function() hum.Sit = false end)
        pcall(function() hum.AutoRotate = true end)
        pcall(function() hum.WalkSpeed = 16 end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
        pcall(function() if not flyActive then hum.PlatformStand = false end end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    
    setFreeze(false)
    safeStand()
    
    task.delay(0.08, function()
        local c2 = LocalPlayer.Character
        local r2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        local h2 = c2 and c2:FindFirstChildOfClass("Humanoid")
        if r2 then
            pcall(function() sethiddenproperty(r2, "PhysicsRepRootPart", nil) end)
            pcall(function() r2.AssemblyLinearVelocity = _V3_ZERO end)
            pcall(function()
                for _, o in ipairs(r2:GetChildren()) do
                    if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity")
                    or o:IsA("BodyPosition") or o:IsA("BodyGyro") then
                        o:Destroy()
                    end
                end
            end)
        end
        if h2 then
            pcall(function() h2.Sit = false end)
            pcall(function() if not flyActive then h2.PlatformStand = false end end)
            pcall(function() h2:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        pcall(safeStand)
    end)
    
end







pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end)


startKiss = function(targetPlayer)
stopKiss()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Kiss", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Kiss", "Missing parts!", 2); return end
local hum = getHumanoid()
if hum then hum.PlatformStand = true end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
pcall(function() local hum = getHumanoid(); if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bv.Velocity = _V3_ZERO
bv.Parent = myRoot; kissBodyPos = bv
local oscTime = 0
local KISS_SPEED = 10.0
_AF.kissActive = true; kissTarget = targetPlayer
sendNotif("Kiss", "💋 Kiss: " .. targetPlayer.Name, 3)
kissStartAnim()
pcall(function()
myRoot.CFrame = tgtTorso.CFrame * CFrame.new(0, 1.5, -1.0) * _CF_ROT180Y
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
kissConn = _RSConnect(function(dt)
if not _AF.kissActive then return end
local tc    = kissTarget and kissTarget.Character
local tHRP  = tc and tc:FindFirstChild("HumanoidRootPart")
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso or not tHRP then return end
local _myC = LocalPlayer.Character
local myR  = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
pcall(sethiddenproperty, myR, "PhysicsRepRootPart", tHRP)
if not kissBodyPos or kissBodyPos.Parent ~= myR then
    if kissBodyPos then pcall(function() kissBodyPos:Destroy() end) end
    local bv2 = Instance.new("BodyVelocity")
    bv2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv2.Velocity = _V3_ZERO; bv2.Parent = myR; kissBodyPos = bv2
end
kissBodyPos.Velocity = _V3_ZERO
oscTime = oscTime + dt * KISS_SPEED
pcall(function()
    local offset = -1.2 - math.sin(oscTime) * 0.08
    myR.CFrame = torso.CFrame * CFrame.new(0, 0, offset) * _CF_ROT180Y
end)
myR.AssemblyLinearVelocity = _V3_ZERO
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Kiss() end
do local function _TLact_Backpack() do
local bpConn      = nil
local bpTarget    = nil
local bpBodyPos   = nil
local bpBodyGyro  = nil
local bpHoverVel  = nil
local bpAnimTrack = nil
local bpAnimConn  = nil
local bpCharConn  = nil
local BACKPACK_ANIM_ID = "73500261613116"
local function bpStopAnim()
if bpAnimConn then bpAnimConn:Disconnect(); bpAnimConn = nil end
if bpCharConn then bpCharConn:Disconnect(); bpCharConn = nil end
if bpAnimTrack then
pcall(function() bpAnimTrack:AdjustSpeed(1); bpAnimTrack:Stop() end)
bpAnimTrack = nil
end
end
local function bpPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, BACKPACK_ANIM_ID, "BackpackAnim")
if not track then return end
setFreeze(true)
bpAnimTrack = track
if bpAnimConn then bpAnimConn:Disconnect() end
bpAnimConn = track.Stopped:Connect(function()
if _AF.backpackActive then
task.wait(0.05)
if _AF.backpackActive then pcall(function() bpPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function bpStartAnim()
bpStopAnim()
task.spawn(function() bpPlayAnim(LocalPlayer.Character) end)
bpCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.backpackActive then task.wait(0.5); task.spawn(function() bpPlayAnim(char) end) end
end)
end
stopBackpack = function()
if bpConn then bpConn:Disconnect(); bpConn = nil end
_AF.backpackActive = false; bpTarget = nil
if bpBodyPos  then pcall(function() bpBodyPos:Destroy()  end); bpBodyPos  = nil end
if bpBodyGyro then pcall(function() bpBodyGyro:Destroy() end); bpBodyGyro = nil end
if bpHoverVel  then pcall(function() bpHoverVel:Destroy()  end); bpHoverVel  = nil end
if not _SOH.active and not ppActive and not _AF.kissActive then setFreeze(false) end
bpStopAnim()
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startBackpack = function(targetPlayer)
stopBackpack()
local myChar    = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Backpack", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Backpack", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp.P = 500000; bp.D = 2500
bp.Position = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.2 + Vector3.new(0, 2.5, 0)
bp.Parent = myRoot; bpBodyPos = bp
local _bpkTP = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.2 + Vector3.new(0,2.5,0); local _bpkCP = _bpkTP
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg.P = 500000; bg.D = 2500
bg.CFrame = CFrame.new(myRoot.Position, myRoot.Position + tgtTorso.CFrame.LookVector * 1) * CFrame.Angles(0, -2 * math.pi, 0)
bg.Parent = myRoot; bpBodyGyro = bg
_AF.backpackActive = true; bpTarget = targetPlayer
sendNotif("Backpack", "🎒 Backpack: " .. targetPlayer.Name, 3)
bpStartAnim()
setFreeze(true)
bpConn = _RSConnect(function()
if not _AF.backpackActive then return end
local tc    = bpTarget and bpTarget.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not bpBodyPos or bpBodyPos.Parent ~= myR then
if bpBodyPos then pcall(function() bpBodyPos:Destroy() end) end
local bp2 = Instance.new("BodyPosition")
bp2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bp2.P = 500000; bp2.D = 2500; bp2.Parent = myR; bpBodyPos = bp2
end
if not bpBodyGyro or bpBodyGyro.Parent ~= myR then
if bpBodyGyro then pcall(function() bpBodyGyro:Destroy() end) end
local bg2 = Instance.new("BodyGyro")
bg2.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bg2.P = 500000; bg2.D = 2500; bg2.Parent = myR; bpBodyGyro = bg2
end
_bpkTP = torso.Position + torso.CFrame.LookVector * -1.2 + Vector3.new(0, 2.5, 0)
local _bpkA = 1-(1-0.98)^(1/60*60); _bpkCP = _bpkCP:Lerp(_bpkTP,_bpkA)
bpBodyPos.Position = _bpkCP
bpBodyGyro.CFrame = CFrame.new(myR.Position, myR.Position + torso.CFrame.LookVector * 1) * CFrame.Angles(0, -2 * math.pi, 0)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Backpack() end
do local function _TLact_Licking() do
local lickingConn      = nil
local lickingTarget    = nil
local lickingBodyPos   = nil
local lickingBodyGyro  = nil
local _lickCP          = Vector3.new(0,0,0)
local lickingAnimTrack = nil
local lickingAnimConn  = nil
local lickingCharConn  = nil
local LICKING_ANIM_ID = "86345507952689"
local function lickingStopAnim()
if lickingAnimConn then lickingAnimConn:Disconnect(); lickingAnimConn = nil end
if lickingCharConn then lickingCharConn:Disconnect(); lickingCharConn = nil end
if lickingAnimTrack then
pcall(function() lickingAnimTrack:AdjustSpeed(1); lickingAnimTrack:Stop() end)
lickingAnimTrack = nil
end
end
local function lickingPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, LICKING_ANIM_ID, "LickingAnim")
if not track then return end
setFreeze(true)
lickingAnimTrack = track
if lickingAnimConn then lickingAnimConn:Disconnect() end
lickingAnimConn = track.Stopped:Connect(function()
if _AF.lickingActive then
task.wait(0.05)
if _AF.lickingActive then pcall(function() lickingPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function lickingStartAnim()
lickingStopAnim()
task.spawn(function() lickingPlayAnim(LocalPlayer.Character) end)
lickingCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.lickingActive then task.wait(0.5); task.spawn(function() lickingPlayAnim(char) end) end
end)
end
stopLicking = function()
_AF.lickingActive = false; lickingTarget = nil
if lickingConn     then lickingConn:Disconnect();     lickingConn     = nil end
if lickingBodyPos  then pcall(function() lickingBodyPos:Destroy()  end); lickingBodyPos  = nil end
if lickingBodyGyro then pcall(function() lickingBodyGyro:Destroy() end); lickingBodyGyro = nil end
lickingStopAnim()
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startLicking = function(targetPlayer)
stopLicking()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Licking", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
if not myRoot or not tgtRoot then sendNotif("Licking", "Missing parts!", 2); return end
local hum = getHumanoid()
if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local tgtCF0 = tgtRoot.CFrame * CFrame.new(0, 1.5, -2.5) * _CF_ROT180Y
pcall(function() myRoot.CFrame = tgtCF0; myRoot.AssemblyLinearVelocity = _V3_ZERO end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = _V3_ZERO
bv.Parent = myRoot; lickingBodyPos = bv
local oscTime = 0
local LICKING_SPEED = 10.0
_AF.lickingActive = true; lickingTarget = targetPlayer
sendNotif("Licking", "Licking " .. targetPlayer.Name .. " 👅", 3)
lickingStartAnim()
lickingConn = _RSConnect(function(dt)
if not _AF.lickingActive then return end
local tc    = lickingTarget and lickingTarget.Character
local torso = tc and tc:FindFirstChild("HumanoidRootPart")
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not lickingBodyPos or lickingBodyPos.Parent ~= myR then
if lickingBodyPos then pcall(function() lickingBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0); bv2.Velocity = _V3_ZERO
bv2.Parent = myR; lickingBodyPos = bv2
end
oscTime = oscTime + dt * LICKING_SPEED
local tgtCF = torso.CFrame * CFrame.new(0, 1.5, -2.5 - math.sin(oscTime)*0.4) * _CF_ROT180Y
pcall(function() myR.CFrame = tgtCF; myR.AssemblyLinearVelocity = _V3_ZERO end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Licking() end
do local function _TLact_SuckIt() do
local suckItConn      = nil
local suckItTarget    = nil
local suckItBodyPos   = nil
local suckItBodyGyro  = nil
local _suckItCP       = Vector3.new(0,0,0)
local suckItAnimTrack = nil
local suckItAnimConn  = nil
local suckItCharConn  = nil
local SUCKIT_ANIM_ID = "79294534752809"
local function suckItStopAnim()
if suckItAnimConn then suckItAnimConn:Disconnect(); suckItAnimConn = nil end
if suckItCharConn then suckItCharConn:Disconnect(); suckItCharConn = nil end
if suckItAnimTrack then
pcall(function() suckItAnimTrack:AdjustSpeed(1); suckItAnimTrack:Stop() end)
suckItAnimTrack = nil
end
end
local function suckItPlayAnim(char)
if not char then return end
if SUCKIT_ANIM_ID == "0" or SUCKIT_ANIM_ID == "" then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, SUCKIT_ANIM_ID, "SuckItAnim")
if not track then return end
setFreeze(true)
suckItAnimTrack = track
if suckItAnimConn then suckItAnimConn:Disconnect() end
suckItAnimConn = track.Stopped:Connect(function()
if _AF.suckItActive then
task.wait(0.05)
if _AF.suckItActive then pcall(function() suckItPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function suckItStartAnim()
suckItStopAnim()
task.spawn(function() suckItPlayAnim(LocalPlayer.Character) end)
suckItCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.suckItActive then task.wait(0.5); task.spawn(function() suckItPlayAnim(char) end) end
end)
end
stopSuckIt = function()
_AF.suckItActive = false; suckItTarget = nil
if suckItConn    then suckItConn:Disconnect();    suckItConn    = nil end
if suckItBodyPos  then pcall(function() suckItBodyPos:Destroy()  end); suckItBodyPos  = nil end
if suckItBodyGyro then pcall(function() suckItBodyGyro:Destroy() end); suckItBodyGyro = nil end
suckItStopAnim()
setFreeze(false)
local hum = getHumanoid()
if hum and not flyActive then
hum.PlatformStand = false
pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
end
pcall(function()
local myR = getRootPart()
if myR then myR.AssemblyLinearVelocity = Vector3.zero end
end)
end
startSuckIt = function(targetPlayer)
stopSuckIt()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Suck It", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
if not myRoot or not tgtRoot then sendNotif("Suck It", "Missing parts!", 2); return end
local hum = getHumanoid()
if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local tgtCF0 = tgtRoot.CFrame * CFrame.new(0, 1.2, -2.0) * _CF_ROT180Y
pcall(function() myRoot.CFrame = tgtCF0; myRoot.AssemblyLinearVelocity = _V3_ZERO end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = _V3_ZERO
bv.Parent = myRoot; suckItBodyPos = bv
local oscTime = 0
local SUCKIT_OSC_SPEED = 8.0
_AF.suckItActive = true; suckItTarget = targetPlayer
sendNotif("Suck it", "😈 " .. targetPlayer.Name, 3)
suckItStartAnim()
suckItConn = _RSConnect(function(dt)
if not _AF.suckItActive then return end
local tc    = suckItTarget and suckItTarget.Character
local torso = tc and tc:FindFirstChild("HumanoidRootPart")
if not torso then return end
local _myC = LocalPlayer.Character
local myR  = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not suckItBodyPos or suckItBodyPos.Parent ~= myR then
if suckItBodyPos then pcall(function() suckItBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0); bv2.Velocity = _V3_ZERO
bv2.Parent = myR; suckItBodyPos = bv2
end
oscTime = oscTime + dt * SUCKIT_OSC_SPEED
local tgtCF = torso.CFrame * CFrame.new(0, 1.2, -2.0 - math.sin(oscTime)*1.0) * _CF_ROT180Y
pcall(function() myR.CFrame = tgtCF; myR.AssemblyLinearVelocity = _V3_ZERO end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_SuckIt() end
do local function _TLact_Sucking() do
local suckingConn      = nil
local suckingTarget    = nil
local suckingBodyPos   = nil
local suckingBodyGyro  = nil
local _suckCP          = Vector3.new(0,0,0)
local suckingAnimTrack = nil
local suckingAnimConn  = nil
local suckingCharConn  = nil
local SUCKING_ANIM_ID = "74402438715168"
local function suckingStopAnim()
if suckingAnimConn then suckingAnimConn:Disconnect(); suckingAnimConn = nil end
if suckingCharConn then suckingCharConn:Disconnect(); suckingCharConn = nil end
if suckingAnimTrack then
pcall(function() suckingAnimTrack:AdjustSpeed(1); suckingAnimTrack:Stop() end)
suckingAnimTrack = nil
end
_G._TLSuckingTrack = nil
end
local function suckingPlayAnim(char)
if not char then return end
if SUCKING_ANIM_ID == "0" or SUCKING_ANIM_ID == "" then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, SUCKING_ANIM_ID, "SuckingAnim")
if not track then return end
setFreeze(true)
suckingAnimTrack = track
_G._TLSuckingTrack = track
if suckingAnimConn then suckingAnimConn:Disconnect() end
suckingAnimConn = track.Stopped:Connect(function()
if _AF.suckingActive then
task.wait(0.05)
if _AF.suckingActive then pcall(function() suckingPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function suckingStartAnim()
suckingStopAnim()
task.spawn(function() suckingPlayAnim(LocalPlayer.Character) end)
suckingCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.suckingActive then task.wait(0.5); task.spawn(function() suckingPlayAnim(char) end) end
end)
end
stopSucking = function()
_AF.suckingActive = false; suckingTarget = nil
if suckingConn     then suckingConn:Disconnect();     suckingConn     = nil end
if suckingBodyPos  then pcall(function() suckingBodyPos:Destroy()  end); suckingBodyPos  = nil end
if suckingBodyGyro then pcall(function() suckingBodyGyro:Destroy() end); suckingBodyGyro = nil end
suckingStopAnim()
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startSucking = function(targetPlayer)
stopSucking()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Sucking", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
if not myRoot or not tgtRoot then sendNotif("Sucking", "Missing parts!", 2); return end
local hum = getHumanoid()
if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local tgtCF0 = tgtRoot.CFrame * CFrame.new(0, 0.5, -3.1) * _CF_SUCK_ROT
pcall(function() myRoot.CFrame = tgtCF0; myRoot.AssemblyLinearVelocity = _V3_ZERO end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = _V3_ZERO
bv.Parent = myRoot; suckingBodyPos = bv
local oscTime = 0
local SUCKING_SPEED = 10.0
_AF.suckingActive = true; suckingTarget = targetPlayer
sendNotif("Sucking", "😈 Sucking " .. targetPlayer.Name, 3)
suckingStartAnim()
suckingConn = _RSConnect(function(dt)
if not _AF.suckingActive then return end
local tc    = suckingTarget and suckingTarget.Character
local torso = tc and tc:FindFirstChild("HumanoidRootPart")
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not suckingBodyPos or suckingBodyPos.Parent ~= myR then
if suckingBodyPos then pcall(function() suckingBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0); bv2.Velocity = _V3_ZERO
bv2.Parent = myR; suckingBodyPos = bv2
end
oscTime = oscTime + dt * SUCKING_SPEED
local tgtCF = torso.CFrame * CFrame.new(0, 0.5, -3.1 - math.sin(oscTime)*0.5) * _CF_SUCK_ROT
pcall(function() myR.CFrame = tgtCF; myR.AssemblyLinearVelocity = _V3_ZERO end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Sucking() end
do local function _TLact_Facefuck() do
local facefuckConn      = nil
local facefuckTarget    = nil
local facefuckBodyPos   = nil
local facefuckAnimTrack = nil
local facefuckAnimConn  = nil
local facefuckCharConn  = nil
local FACEFUCK_ANIM_ID = "01180934467755"
local function facefuckStopAnim()
if facefuckAnimConn then facefuckAnimConn:Disconnect(); facefuckAnimConn = nil end
if facefuckCharConn then facefuckCharConn:Disconnect(); facefuckCharConn = nil end
if facefuckAnimTrack then
pcall(function() facefuckAnimTrack:AdjustSpeed(1); facefuckAnimTrack:Stop() end)
facefuckAnimTrack = nil
end
end
local function facefuckPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, FACEFUCK_ANIM_ID, "FacefuckAnim")
if not track then return end
setFreeze(true)
facefuckAnimTrack = track
if facefuckAnimConn then facefuckAnimConn:Disconnect() end
facefuckAnimConn = track.Stopped:Connect(function()
if _AF.facefuckActive then
task.wait(0.05)
if _AF.facefuckActive then pcall(function() facefuckPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function facefuckStartAnim()
facefuckStopAnim()
task.spawn(function() facefuckPlayAnim(LocalPlayer.Character) end)
facefuckCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.facefuckActive then task.wait(0.5); task.spawn(function() facefuckPlayAnim(char) end) end
end)
end
stopFacefuck = function()
_AF.facefuckActive = false; facefuckTarget = nil
if facefuckConn    then facefuckConn:Disconnect();    facefuckConn    = nil end
if facefuckBodyPos then pcall(function() facefuckBodyPos:Destroy() end); facefuckBodyPos = nil end
facefuckStopAnim()
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startFacefuck = function(targetPlayer)
stopFacefuck()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Facefuck", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtHead  = targetChar:FindFirstChild("Head")
if not myRoot or not tgtRoot or not tgtHead then sendNotif("Facefuck", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; facefuckBodyPos = bv
local oscTime = 0
local FF_SPEED  = 12.0
local FF_DEPTH  = 0.9
local FF_BASE_Z = -2.8
_AF.facefuckActive = true; facefuckTarget = targetPlayer
sendNotif("Facefuck", "😈 Facefucking " .. targetPlayer.Name, 3)
facefuckStartAnim()
pcall(function()
myRoot.CFrame = tgtHead.CFrame * CFrame.new(0, 0, FF_BASE_Z) * _CF_ROT180Y
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
facefuckConn = _RSConnect(function(dt)
if not _AF.facefuckActive then return end
local tc   = facefuckTarget and facefuckTarget.Character
local head = tc and tc:FindFirstChild("Head")
if not head then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not facefuckBodyPos or facefuckBodyPos.Parent ~= myR then
if facefuckBodyPos then pcall(function() facefuckBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; facefuckBodyPos = bv2
end
oscTime = oscTime + dt * FF_SPEED
pcall(function()
local zOffset = FF_BASE_Z - math.sin(oscTime) * FF_DEPTH
myR.CFrame = head.CFrame
* CFrame.new(0, 0, zOffset)
* _CF_ROT180Y
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Facefuck() end
do local function _TLact_Backshots() do
local backshotsConn      = nil
local backshotsTarget    = nil
local backshotsBodyPos   = nil
local backshotsBodyGyro  = nil
local backshotsAnimTrack = nil
local backshotsAnimConn  = nil
local backshotsCharConn  = nil
local BACKSHOTS_ANIM_ID = "4689362868"
local function backshotsStopAnim()
if backshotsAnimConn then backshotsAnimConn:Disconnect(); backshotsAnimConn = nil end
if backshotsCharConn then backshotsCharConn:Disconnect(); backshotsCharConn = nil end
if backshotsAnimTrack then
pcall(function() backshotsAnimTrack:AdjustSpeed(1); backshotsAnimTrack:Stop() end)
backshotsAnimTrack = nil
end
end
local function backshotsPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, BACKSHOTS_ANIM_ID, "BackshotsAnim")
if not track then return end
setFreeze(true)
backshotsAnimTrack = track
if backshotsAnimConn then backshotsAnimConn:Disconnect() end
backshotsAnimConn = track.Stopped:Connect(function()
if _AF.backshotsActive then
task.wait(0.05)
if _AF.backshotsActive then pcall(function() backshotsPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function backshotsStartAnim()
backshotsStopAnim()
task.spawn(function() backshotsPlayAnim(LocalPlayer.Character) end)
backshotsCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.backshotsActive then task.wait(0.5); task.spawn(function() backshotsPlayAnim(char) end) end
end)
end
stopBackshots = function()
_AF.backshotsActive = false; backshotsTarget = nil
if backshotsConn    then backshotsConn:Disconnect();    backshotsConn    = nil end
if backshotsBodyPos then pcall(function() backshotsBodyPos:Destroy() end); backshotsBodyPos = nil end
backshotsStopAnim()
pcall(function() setFreeze(false) end)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startBackshots = function(targetPlayer)
stopBackshots()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Backshots", "No character!", 2); return end
local myRoot = myChar:FindFirstChild("HumanoidRootPart")
local tHRP   = targetChar:FindFirstChild("HumanoidRootPart")
if not myRoot or not tHRP then sendNotif("Backshots", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tHRP)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; backshotsBodyPos = bv
local oscTime = 0
local BS_SPEED = 10.0
_AF.backshotsActive = true; backshotsTarget = targetPlayer
sendNotif("Backshots", "Backshots on " .. targetPlayer.Name, 3)
backshotsStartAnim()
pcall(function()
myRoot.CFrame = tHRP.CFrame * CFrame.new(0, 0, -2.0) * CFrame.Angles(math.rad(20), 0, 0)
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
backshotsConn = _RSConnect(function(dt)
if not _AF.backshotsActive then return end
local tc   = backshotsTarget and backshotsTarget.Character
local tHRP2 = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myR   =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP2 or not myR then return end
if not backshotsBodyPos or backshotsBodyPos.Parent ~= myR then
if backshotsBodyPos then pcall(function() backshotsBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; backshotsBodyPos = bv2
end
oscTime = oscTime + dt * BS_SPEED
pcall(function()
local offset = -2.0 - math.sin(oscTime) * 1.5
myR.CFrame = tHRP2.CFrame
* CFrame.new(0, 0, offset)
* CFrame.Angles(math.rad(20), 0, 0)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Backshots() end
do local function _TLact_LayFuck() do
local layFuckConn      = nil
local layFuckTarget    = nil
local layFuckBodyPos   = nil
local layFuckAnimTrack = nil
local layFuckAnimConn  = nil
local layFuckCharConn  = nil
local LAYFUCK_ANIM_ID = "95678189010798"
local function layFuckStopAnim()
if layFuckAnimConn then layFuckAnimConn:Disconnect(); layFuckAnimConn = nil end
if layFuckCharConn then layFuckCharConn:Disconnect(); layFuckCharConn = nil end
if layFuckAnimTrack then
pcall(function() layFuckAnimTrack:AdjustSpeed(1); layFuckAnimTrack:Stop() end)
layFuckAnimTrack = nil
end
end
local function layFuckPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, LAYFUCK_ANIM_ID, "LayFuckAnim")
if not track then return end
setFreeze(true)
layFuckAnimTrack = track
if layFuckAnimConn then layFuckAnimConn:Disconnect() end
layFuckAnimConn = track.Stopped:Connect(function()
if _AF.layFuckActive then
task.wait(0.05)
if _AF.layFuckActive then pcall(function() layFuckPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function layFuckStartAnim()
layFuckStopAnim()
task.spawn(function() layFuckPlayAnim(LocalPlayer.Character) end)
layFuckCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.layFuckActive then task.wait(0.5); task.spawn(function() layFuckPlayAnim(char) end) end
end)
end
stopLayFuck = function()
_AF.layFuckActive = false; layFuckTarget = nil
if layFuckConn    then layFuckConn:Disconnect();    layFuckConn    = nil end
if layFuckBodyPos then pcall(function() layFuckBodyPos:Destroy() end); layFuckBodyPos = nil end
layFuckStopAnim()
pcall(function() setFreeze(false) end)
local hum = getHumanoid()
if hum and not flyActive then
hum.PlatformStand = false
pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot = _lpc and _lpc:FindFirstChild("HumanoidRootPart")
if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end
end) end
end
startLayFuck = function(targetPlayer)
stopLayFuck()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Lay Fuck", "No character!", 2); return end
local myRoot = myChar:FindFirstChild("HumanoidRootPart")
local tHRP   = targetChar:FindFirstChild("HumanoidRootPart")
if not myRoot or not tHRP then sendNotif("Lay Fuck", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tHRP)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; layFuckBodyPos = bv
local oscTime = 0
local LF_SPEED  = 12.0
local LF_DEPTH  = 0.9
local LF_BASE   = 1.1
_AF.layFuckActive = true; layFuckTarget = targetPlayer
sendNotif("Lay Fuck", "Lay Fuck on " .. targetPlayer.Name, 3)
layFuckStartAnim()
pcall(function()
myRoot.CFrame = tHRP.CFrame * CFrame.new(0, -0.8, LF_BASE) * _CF_ROT180Y
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
end)
layFuckConn = _RSConnect(function(dt)
if not _AF.layFuckActive then return end
local tc    = layFuckTarget and layFuckTarget.Character
local tHRP2 = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc  = LocalPlayer.Character
local myR   = _lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP2 or not myR then return end
if not layFuckBodyPos or layFuckBodyPos.Parent ~= myR then
if layFuckBodyPos then pcall(function() layFuckBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; layFuckBodyPos = bv2
end
oscTime = oscTime + dt * LF_SPEED
pcall(function()
local zOff = LF_BASE - math.sin(oscTime) * LF_DEPTH
myR.CFrame = tHRP2.CFrame
* CFrame.new(0, -0.8, zOff)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _lpc and _lpc:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function()
if h2:GetState() == Enum.HumanoidStateType.Seated then
h2:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
h2:ChangeState(Enum.HumanoidStateType.Physics)
end
end)
end)
end
end end _TLact_LayFuck() end
do local function _TLact_PussySpread() do
local psConn      = nil
local psTarget    = nil
local psBodyPos   = nil
local psAnimTrack = nil
local psAnimConn  = nil
local psCharConn  = nil
local PS_ANIM_ID = "120754278085861"
local function psStopAnim()
if psAnimConn then psAnimConn:Disconnect(); psAnimConn = nil end
if psCharConn then psCharConn:Disconnect(); psCharConn = nil end
if psAnimTrack then
pcall(function() psAnimTrack:AdjustSpeed(1); psAnimTrack:Stop() end)
psAnimTrack = nil
end
end
local function psPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, PS_ANIM_ID, "PussySpreadAnim")
if not track then return end
setFreeze(true)
psAnimTrack = track
if psAnimConn then psAnimConn:Disconnect() end
psAnimConn = track.Stopped:Connect(function()
if _AF.pussySpreadActive then
task.wait(0.05)
if _AF.pussySpreadActive then pcall(function() psPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function psStartAnim()
psStopAnim()
task.spawn(function() psPlayAnim(LocalPlayer.Character) end)
psCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.pussySpreadActive then task.wait(0.5); task.spawn(function() psPlayAnim(char) end) end
end)
end
stopPussySpread = function()
_AF.pussySpreadActive = false; psTarget = nil
if psConn    then psConn:Disconnect();    psConn    = nil end
if psBodyPos then pcall(function() psBodyPos:Destroy() end); psBodyPos = nil end
psStopAnim()
pcall(function() setFreeze(false) end)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startPussySpread = function(targetPlayer)
stopPussySpread()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Pussy Spread", "No character!", 2); return end
local myRoot = myChar:FindFirstChild("HumanoidRootPart")
local tHRP   = targetChar:FindFirstChild("HumanoidRootPart")
if not myRoot or not tHRP then sendNotif("Pussy Spread", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tHRP)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; psBodyPos = bv
local oscTime = 0
local PS_SPEED = 10.0
_AF.pussySpreadActive = true; psTarget = targetPlayer
sendNotif("Pussy Spread", "Pussy Spread on " .. targetPlayer.Name, 3)
psStartAnim()
psConn = _RSConnect(function(dt)
if not _AF.pussySpreadActive then return end
local tc    = psTarget and psTarget.Character
local tHRP2 = tc and tc:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myR   =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if not tHRP2 or not myR then return end
if not psBodyPos or psBodyPos.Parent ~= myR then
if psBodyPos then pcall(function() psBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; psBodyPos = bv2
end
oscTime = oscTime + dt * PS_SPEED
pcall(function()
local offset = -2.0 - math.sin(oscTime) * 1.5
myR.CFrame = tHRP2.CFrame * CFrame.new(0, 0, offset)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_PussySpread() end
do local function _TLact_Hug() do
local hugConn      = nil
local hugTarget    = nil
local hugBodyPos   = nil
local hugCurrentCF = nil
local hugAnimTrack = nil
local hugAnimConn  = nil
local hugCharConn  = nil
local HUG_ANIM_ID = "93667149408515"
local function hugStopAnim()
if hugAnimConn then hugAnimConn:Disconnect(); hugAnimConn = nil end
if hugCharConn then hugCharConn:Disconnect(); hugCharConn = nil end
if hugAnimTrack then
pcall(function() hugAnimTrack:AdjustSpeed(1); hugAnimTrack:Stop() end)
hugAnimTrack = nil
end
end
local function hugPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, HUG_ANIM_ID, "HugAnim")
if not track then return end
setFreeze(true)
hugAnimTrack = track
if hugAnimConn then hugAnimConn:Disconnect() end
hugAnimConn = track.Stopped:Connect(function()
if _AF.hugActive then
task.wait(0.05)
if _AF.hugActive then pcall(function() hugPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function hugStartAnim()
hugStopAnim()
task.spawn(function() hugPlayAnim(LocalPlayer.Character) end)
hugCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.hugActive then task.wait(0.5); task.spawn(function() hugPlayAnim(char) end) end
end)
end
stopHug = function()
    _AF.hugActive = false; hugTarget = nil
    if hugConn     then pcall(function() hugConn:Disconnect() end);     hugConn     = nil end
    if hugBodyPos  then pcall(function() hugBodyPos:Destroy()  end); hugBodyPos  = nil end
    hugCurrentCF = nil
    hugStopAnim()
    local myChar = LocalPlayer.Character
    local myR = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if myR then
        pcall(function() sethiddenproperty(myR, "PhysicsRepRootPart", nil) end)
        pcall(function() myR.Anchored = false end)
        pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
        pcall(function() myR.AssemblyAngularVelocity = _V3_ZERO end)
        pcall(function()
            for _, o in ipairs(myR:GetChildren()) do
                if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity")
                or o:IsA("BodyPosition") or o:IsA("BodyGyro") then
                    o:Destroy()
                end
            end
        end)
    end
    if hum then
        pcall(function() hum.Sit = false end)
        pcall(function() hum.AutoRotate = true end)
        pcall(function() hum.WalkSpeed = 16 end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Running, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
        pcall(function() if not flyActive then hum.PlatformStand = false end end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    setFreeze(false)
    safeStand()
    task.delay(0.08, function()
        local char2 = LocalPlayer.Character
        local hrp2 = char2 and char2:FindFirstChild("HumanoidRootPart")
        local hum2 = char2 and char2:FindFirstChildOfClass("Humanoid")
        if hrp2 then
            pcall(function() sethiddenproperty(hrp2, "PhysicsRepRootPart", nil) end)
            pcall(function() hrp2.AssemblyLinearVelocity = _V3_ZERO end)
            pcall(function() hrp2.AssemblyAngularVelocity = _V3_ZERO end)
            pcall(function()
                for _, o in ipairs(hrp2:GetChildren()) do
                    if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity")
                    or o:IsA("BodyPosition") or o:IsA("BodyGyro") then
                        o:Destroy()
                    end
                end
            end)
        end
        if hum2 then
            pcall(function() hum2.Sit = false end)
            pcall(function() if not flyActive then hum2.PlatformStand = false end end)
            pcall(function() hum2:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        pcall(safeStand)
    end)
end
startHug = function(targetPlayer)
stopHug()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Hug", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Hug", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bv.Velocity = _V3_ZERO
bv.Parent = myRoot; hugBodyPos = bv
hugCurrentCF = nil
local oscTime = 0
local HUG_SPEED = 10.0
_AF.hugActive = true; hugTarget = targetPlayer
sendNotif("Hug", "Hugging " .. targetPlayer.Name .. " 🤗", 3)
hugStartAnim()
pcall(function()
local offset = -1.35
local targetCF = tgtTorso.CFrame * CFrame.new(0, 0.05, offset) * _CF_ROT180Y
myRoot.CFrame = targetCF
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
hugConn = _RSConnect(function(dt)
if not _AF.hugActive then return end
local tc    = hugTarget and hugTarget.Character
local tHRP  = tc and tc:FindFirstChild("HumanoidRootPart")
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso or not tHRP then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
pcall(sethiddenproperty, myR, "PhysicsRepRootPart", tHRP)
if not hugBodyPos or hugBodyPos.Parent ~= myR then
if hugBodyPos then pcall(function() hugBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bv2.Velocity = _V3_ZERO; bv2.Parent = myR; hugBodyPos = bv2
hugCurrentCF = nil
end
hugBodyPos.Velocity = _V3_ZERO
oscTime = oscTime + dt * HUG_SPEED
pcall(function()
local offset = -1.35 - math.sin(oscTime) * 0.04
local targetCF = torso.CFrame * CFrame.new(0, 0.05, offset) * _CF_ROT180Y
local alpha = 1 - (1 - 0.88)^(dt * 60)
if not hugCurrentCF then
    hugCurrentCF = targetCF
else
    hugCurrentCF = hugCurrentCF:Lerp(targetCF, alpha)
end
myR.CFrame = hugCurrentCF
end)
myR.AssemblyLinearVelocity = _V3_ZERO
pcall(function() myR.AssemblyAngularVelocity = _V3_ZERO end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Hug() end
do local function _TLact_Hug2() do
local hug2Conn      = nil
local hug2Target    = nil
local hug2BodyPos   = nil
local hug2AnimTrack = nil
local hug2AnimConn  = nil
local hug2CharConn  = nil
local HUG2_ANIM_ID = "101809619267911"
local function hug2StopAnim()
if hug2AnimConn then hug2AnimConn:Disconnect(); hug2AnimConn = nil end
if hug2CharConn then hug2CharConn:Disconnect(); hug2CharConn = nil end
if hug2AnimTrack then
pcall(function() hug2AnimTrack:AdjustSpeed(1); hug2AnimTrack:Stop() end)
hug2AnimTrack = nil
end
end
local function hug2PlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, HUG2_ANIM_ID, "Hug2Anim")
if not track then return end
setFreeze(true)
hug2AnimTrack = track
if hug2AnimConn then hug2AnimConn:Disconnect() end
hug2AnimConn = track.Stopped:Connect(function()
if _AF.hug2Active then
task.wait(0.05)
if _AF.hug2Active then pcall(function() hug2PlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function hug2StartAnim()
hug2StopAnim()
task.spawn(function() hug2PlayAnim(LocalPlayer.Character) end)
hug2CharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.hug2Active then task.wait(0.5); task.spawn(function() hug2PlayAnim(char) end) end
end)
end
stopHug2 = function()
    _AF.hug2Active = false; hug2Target = nil
    if hug2Conn    then pcall(function() hug2Conn:Disconnect() end);    hug2Conn    = nil end
    if hug2BodyPos then pcall(function() hug2BodyPos:Destroy() end); hug2BodyPos = nil end
    hug2StopAnim()
    pcall(function()
        local myR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myR then myR.Anchored = false end
    end)
    setFreeze(false)
    safeStand()
end
startHug2 = function(targetPlayer)
stopHug2()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Hug 2", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Hug 2", "Missing parts!", 2); return end
local hum = getHumanoid()
if hum then
hum.PlatformStand = true
pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)
end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; hug2BodyPos = bv
_AF.hug2Active = true; hug2Target = targetPlayer
sendNotif("Hug 2", "Hugging " .. targetPlayer.Name .. " from behind 🤗", 3)
hug2StartAnim()
pcall(function()
myRoot.CFrame = tgtTorso.CFrame * CFrame.new(0, 0, 1.1)
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
hug2Conn = _RSConnect(function(dt)
if not _AF.hug2Active then return end
local tc    = hug2Target and hug2Target.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR  = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not hug2BodyPos or hug2BodyPos.Parent ~= myR then
if hug2BodyPos then pcall(function() hug2BodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; hug2BodyPos = bv2
end
pcall(function()
myR.CFrame = torso.CFrame * CFrame.new(0, 0, 1.1)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function()
if h2:GetState() == Enum.HumanoidStateType.Seated then
h2:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
h2:ChangeState(Enum.HumanoidStateType.Physics)
end
end)
end)
end
end end _TLact_Hug2() end
do local function _TLact_Carry() do
local carryConn      = nil
local carryTarget    = nil
local carryBodyPos   = nil
local carryAnimTrack = nil
local carryAnimConn  = nil
local carryCharConn  = nil
local CARRY_ANIM_ID = "95469914338674"
local function carryStopAnim()
if carryAnimConn then carryAnimConn:Disconnect(); carryAnimConn = nil end
if carryCharConn then carryCharConn:Disconnect(); carryCharConn = nil end
if carryAnimTrack then
pcall(function() carryAnimTrack:AdjustSpeed(1); carryAnimTrack:Stop() end)
carryAnimTrack = nil
end
end
local function carryPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, CARRY_ANIM_ID, "CarryAnim")
if not track then return end
setFreeze(true)
carryAnimTrack = track
if carryAnimConn then carryAnimConn:Disconnect() end
carryAnimConn = track.Stopped:Connect(function()
if _AF.carryActive then
task.wait(0.05)
if _AF.carryActive then pcall(function() carryPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function carryStartAnim()
carryStopAnim()
task.spawn(function() carryPlayAnim(LocalPlayer.Character) end)
carryCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.carryActive then task.wait(0.5); task.spawn(function() carryPlayAnim(char) end) end
end)
end
stopCarry = function()
_AF.carryActive = false; carryTarget = nil
if carryConn    then carryConn:Disconnect();    carryConn    = nil end
if carryBodyPos then pcall(function() carryBodyPos:Destroy() end); carryBodyPos = nil end
carryStopAnim()
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startCarry = function(targetPlayer)
stopCarry()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Carry", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Carry", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; carryBodyPos = bv
local oscTime = 0
local CARRY_SPEED = 10.0
_AF.carryActive = true; carryTarget = targetPlayer
sendNotif("Carry", "💪 Carrying " .. targetPlayer.Name, 3)
carryStartAnim()
pcall(function()
myRoot.CFrame = tgtTorso.CFrame * CFrame.new(0.5, -0.5, -1.2)
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
carryConn = _RSConnect(function(dt)
if not _AF.carryActive then return end
local tc    = carryTarget and carryTarget.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not carryBodyPos or carryBodyPos.Parent ~= myR then
if carryBodyPos then pcall(function() carryBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; carryBodyPos = bv2
end
oscTime = oscTime + dt * CARRY_SPEED
pcall(function()
myR.CFrame = torso.CFrame
* CFrame.new(0.5, -0.5, -1.2)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_Carry() end
do local function _TLact_ShoulderSit() do
local ssConn      = nil
local ssTarget    = nil
local ssBodyPos   = nil
local ssAnimTrack = nil
local ssAnimConn  = nil
local ssCharConn  = nil
local SS_ANIM_ID = "119898270336796"
local function ssStopAnim()
if ssAnimConn then ssAnimConn:Disconnect(); ssAnimConn = nil end
if ssCharConn then ssCharConn:Disconnect(); ssCharConn = nil end
if ssAnimTrack then
pcall(function() ssAnimTrack:AdjustSpeed(1); ssAnimTrack:Stop() end)
ssAnimTrack = nil
end
end
local function ssPlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = _AF_getReliableActionTrack(hum, SS_ANIM_ID, "SSAnim")
if not track then return end
setFreeze(true)
ssAnimTrack = track
if ssAnimConn then ssAnimConn:Disconnect() end
ssAnimConn = track.Stopped:Connect(function()
if _AF.shoulderSitActive then
task.wait(0.05)
if _AF.shoulderSitActive then pcall(function() ssPlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function ssStartAnim()
ssStopAnim()
task.spawn(function() ssPlayAnim(LocalPlayer.Character) end)
ssCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.shoulderSitActive then task.wait(0.5); task.spawn(function() ssPlayAnim(char) end) end
end)
end
stopShoulderSit = function()
_AF.shoulderSitActive = false; ssTarget = nil
if ssConn    then ssConn:Disconnect();    ssConn    = nil end
if ssBodyPos then pcall(function() ssBodyPos:Destroy() end); ssBodyPos = nil end
ssStopAnim()
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startShoulderSit = function(targetPlayer)
stopShoulderSit()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("Shouldersit", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("Shouldersit", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; ssBodyPos = bv
local oscTime = 0
local SS_SPEED = 10.0
_AF.shoulderSitActive = true; ssTarget = targetPlayer
sendNotif("Shouldersit", "👑 Sitting on " .. targetPlayer.Name .. "'s shoulder", 3)
ssStartAnim()
pcall(function()
myRoot.CFrame = tgtTorso.CFrame * CFrame.new(1.8, 2.2, 0) * CFrame.Angles(0, 0, 0)
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
ssConn = _RSConnect(function(dt)
if not _AF.shoulderSitActive then return end
local tc    = ssTarget and ssTarget.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not ssBodyPos or ssBodyPos.Parent ~= myR then
if ssBodyPos then pcall(function() ssBodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; ssBodyPos = bv2
end
oscTime = oscTime + dt * SS_SPEED
pcall(function()
myR.CFrame = torso.CFrame
* CFrame.new(1.8, 2.2, 0)
* CFrame.Angles(0, 0, 0)
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_ShoulderSit() end
do local function _TLact_QA74() do
local qa74Conn      = nil
local qa74Target    = nil
local qa74BodyPos   = nil
local qa74AnimTrack = nil
local qa74AnimConn  = nil
local qa74CharConn  = nil
local QA74_ANIM_ID  = "74402438715168"
local function qa74StopAnim()
if qa74AnimConn  then qa74AnimConn:Disconnect();  qa74AnimConn  = nil end
if qa74CharConn  then qa74CharConn:Disconnect();  qa74CharConn  = nil end
if qa74AnimTrack then
pcall(function() qa74AnimTrack:AdjustSpeed(1); qa74AnimTrack:Stop() end)
qa74AnimTrack = nil
end
end
local function qa74PlayAnim(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(QA74_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("QA74Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, QA74_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
setFreeze(true)
qa74AnimTrack = track
if qa74AnimConn then qa74AnimConn:Disconnect() end
qa74AnimConn = track.Stopped:Connect(function()
if _AF.qa74Active then
task.wait(0.05)
if _AF.qa74Active then pcall(function() qa74PlayAnim(LocalPlayer.Character) end) end
end
end)
end
local function qa74StartAnim()
qa74StopAnim()
task.spawn(function() qa74PlayAnim(LocalPlayer.Character) end)
qa74CharConn = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.qa74Active then task.wait(0.5); task.spawn(function() qa74PlayAnim(char) end) end
end)
end
stopQA74 = function()
_AF.qa74Active = false; qa74Target = nil
if qa74Conn    then qa74Conn:Disconnect();    qa74Conn    = nil end
if qa74BodyPos then pcall(function() qa74BodyPos:Destroy()  end); qa74BodyPos  = nil end
qa74StopAnim()
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
end
startQA74 = function(targetPlayer)
stopQA74()
local myChar     = LocalPlayer.Character
local targetChar = targetPlayer and targetPlayer.Character
if not myChar or not targetChar then sendNotif("QA74", "No character!", 2); return end
local myRoot   = myChar:FindFirstChild("HumanoidRootPart")
local tgtRoot  = targetChar:FindFirstChild("HumanoidRootPart")
local tgtTorso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
if not myRoot or not tgtRoot or not tgtTorso then sendNotif("QA74", "Missing parts!", 2); return end
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
pcall(sethiddenproperty, myRoot, "PhysicsRepRootPart", tgtRoot)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; qa74BodyPos = bv
local oscTime = 0
local QA74_SPEED = 10.0
_AF.qa74Active = true; qa74Target = targetPlayer
sendNotif("Animation", "🎬 Playing near " .. targetPlayer.Name, 3)
qa74StartAnim()
pcall(function()
myRoot.CFrame = tgtTorso.CFrame * CFrame.new(0, 0, -1.1) * _CF_ROT180Y
pcall(function() myRoot.AssemblyLinearVelocity = _V3_ZERO end)
pcall(function() myRoot.AssemblyAngularVelocity = _V3_ZERO end)
end)
qa74Conn = _RSConnect(function(dt)
if not _AF.qa74Active then return end
local tc    = qa74Target and qa74Target.Character
local torso = tc and (tc:FindFirstChild("UpperTorso") or tc:FindFirstChild("Torso"))
if not torso then return end
local _myC = LocalPlayer.Character
local myR = _myC and _myC:FindFirstChild("HumanoidRootPart")
if not myR then return end
if not qa74BodyPos or qa74BodyPos.Parent ~= myR then
if qa74BodyPos then pcall(function() qa74BodyPos:Destroy() end) end
local bv2 = Instance.new("BodyVelocity")
bv2.MaxForce = Vector3.new(0, 1e6, 0)
bv2.Velocity = Vector3.zero; bv2.Parent = myR; qa74BodyPos = bv2
end
oscTime = oscTime + dt * QA74_SPEED
pcall(function()
local offset = -1.1 - math.sin(oscTime) * 0.2
myR.CFrame = torso.CFrame
* CFrame.new(0, 0, offset)
* _CF_ROT180Y
pcall(function() myR.AssemblyLinearVelocity = _V3_ZERO end)
end)
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and not h2.PlatformStand then h2.PlatformStand = true end
pcall(function() if h2:GetState()==Enum.HumanoidStateType.Seated then h2:SetStateEnabled(Enum.HumanoidStateType.Seated,false); h2:ChangeState(Enum.HumanoidStateType.Physics) end end)
end)
end
end end _TLact_QA74() end
do local function _TLact_Orbit() do
local orbitConn           = nil
local orbitTarget_        = nil
local orbitTargetRespConn = nil
stopOrbit = function()
if orbitConn           then orbitConn:Disconnect();           orbitConn           = nil end
if orbitTargetRespConn then orbitTargetRespConn:Disconnect(); orbitTargetRespConn = nil end
_AF.orbitActive = false; orbitTarget_ = nil
local myChar = LocalPlayer.Character
if myChar then
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if hrp then
hrp.AssemblyLinearVelocity = Vector3.zero
hrp.Anchored = false
end
if hum then if not flyActive then hum.PlatformStand = false end; hum.WalkSpeed = 16 end
end
sendNotif("Orbit TP", T.qa_stopped, 1)
pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
end
startOrbit = function(targetPlayer)
stopOrbit()
if not targetPlayer or not targetPlayer.Character then
sendNotif("Orbit TP", T.gb_no_target_char, 2); return
end
local myChar = LocalPlayer.Character
if not myChar then sendNotif("Orbit TP", T.gb_no_own_char, 2); return end
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then sendNotif("Orbit TP", "Missing HRP/Hum!", 2); return end
_AF.orbitActive  = true
orbitTarget_ = targetPlayer
local initHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
if initHRP then
hrp.CFrame = initHRP.CFrame * CFrame.new(math.random(-3, 3), 0, 5)
end
hum.PlatformStand = true
pcall(function() hrp:SetNetworkOwner(LocalPlayer) end)
pcall(sethiddenproperty, hrp, "PhysicsRepRootPart", initHRP)
hum.WalkSpeed = 0
local ORBIT_NEAR         = 2.2
local ORBIT_FAR          = 6.5
local ORBIT_BREATH_SPEED = 0.35
local orbitSpeed         = 35
local phase              = 0
local breathPhase        = 0
local directionFlipTimer = 0
local flipInterval       = 0.08
local function makeOrbitConn()
if orbitConn then orbitConn:Disconnect() end
phase = 0; breathPhase = 0; directionFlipTimer = 0
local slowPhase = 0
local _orbitVelAcc = 0
local _orCC = LocalPlayer.Character
local _orMH = _orCC and _orCC:FindFirstChild("HumanoidRootPart")
local _orTC = orbitTarget_ and orbitTarget_.Character
local _orTH = _orTC and _orTC:FindFirstChild("HumanoidRootPart")
orbitConn = RunService.Heartbeat:Connect(function(dt)
if not _AF.orbitActive then return end
local _lpc = LocalPlayer.Character
if _lpc ~= _orCC then _orCC=_lpc; _orMH=_lpc and _lpc:FindFirstChild("HumanoidRootPart") end
local tChar = orbitTarget_ and orbitTarget_.Character
if tChar ~= _orTC then _orTC=tChar; _orTH=tChar and tChar:FindFirstChild("HumanoidRootPart") end
local tHRP2 = _orTH; local myHRP = _orMH
if not tHRP2 or not tHRP2.Parent or not myHRP or not myHRP.Parent then return end
local center = tHRP2.Position
phase        = phase        + dt * orbitSpeed * math.pi * 2
breathPhase  = breathPhase  + dt * ORBIT_BREATH_SPEED * math.pi * 2
local breathT    = (math.sin(breathPhase) + 1) * 0.5
local orbitRadius = ORBIT_NEAR + (ORBIT_FAR - ORBIT_NEAR) * breathT
local _cp = _mcos(phase); local _sp = _msin(phase)
local offset = _V3new(_cp * orbitRadius, 1.5 + _msin(phase*3)*1.5, _sp * orbitRadius)
local targetPos   = center + offset
local dist = (myHRP.Position - center).Magnitude
if dist > 30 then
myHRP.CFrame = CFrame.new(center + Vector3.new(_mrandom(-3,3), 1.5, _mrandom(-3,3)))
pcall(function() myHRP.AssemblyLinearVelocity = Vector3.zero end)
return
end
local toCenter    = (center - myHRP.Position).Unit
local tangent     = Vector3.new(-toCenter.Z, 0, toCenter.X).Unit
local velocityDir = tangent * (orbitSpeed * orbitRadius * 4)
directionFlipTimer = directionFlipTimer + dt
if directionFlipTimer > flipInterval then
velocityDir        = -velocityDir
directionFlipTimer = 0
flipInterval       = _mrandom(8, 15) * 0.01
end
pcall(function() myHRP.AssemblyLinearVelocity = velocityDir + (targetPos - myHRP.Position) * 10 end)
myHRP.CFrame = CFrame.lookAt(myHRP.Position, center)
slowPhase = slowPhase + dt * 0.9
local camOffset = Vector3.new(
_mcos(slowPhase) * (orbitRadius + 1.5),
2.5,
_msin(slowPhase) * (orbitRadius + 1.5)
)
local cam = _workspace.CurrentCamera
if cam then
    if cam.CameraType ~= Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Scriptable
    end
    cam.CFrame = _CFlookAt(center + camOffset, center + Vector3.new(0, 1, 0))
end
_orbitVelAcc = (_orbitVelAcc or 0) + dt
if _orbitVelAcc >= 0.06 then
_orbitVelAcc = 0
if _AF.orbitActive then
local _lpc2 = LocalPlayer.Character
local h = _lpc2 and _lpc2:FindFirstChild("HumanoidRootPart")
pcall(function() if h then h.AssemblyLinearVelocity = velocityDir * 0.8 end end)
end
end
end)
end
makeOrbitConn()
orbitTargetRespConn = targetPlayer.CharacterAdded:Connect(function(newChar)
task.wait(0.5)
if not _AF.orbitActive then return end
local newHRP = newChar:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myHRP2 =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if newHRP and myHRP2 then
myHRP2.CFrame = newHRP.CFrame * CFrame.new(math.random(-3, 3), 0, 5)
pcall(function() myHRP2.AssemblyLinearVelocity = Vector3.zero end)
end
sendNotif("Orbit TP", T.orbit_respawn, 2)
makeOrbitConn()
end)
sendNotif("Orbit TP", "🔄 Orbit: " .. targetPlayer.Name, 3)
end
end end _TLact_Orbit() end
do local function _TLact_Ghost() do
local ghostConn         = nil
local ghostRespConn     = nil
local ghostHealthConn   = nil
local ghostTarget_      = nil
local GHOST_DEPTH       = -15
local GHOST_FOLLOW_SPEED = 12
stopGhost = function()
local lastTargetPos = nil
if ghostTarget_ and ghostTarget_.Character then
local tHRP = ghostTarget_.Character:FindFirstChild("HumanoidRootPart")
if tHRP then lastTargetPos = tHRP.Position end
end
if ghostConn       then ghostConn:Disconnect();       ghostConn       = nil end
if ghostRespConn   then ghostRespConn:Disconnect();   ghostRespConn   = nil end
if ghostHealthConn then ghostHealthConn:Disconnect(); ghostHealthConn = nil end
_AF.ghostActive = false; ghostTarget_ = nil
local myChar = LocalPlayer.Character
if myChar then
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if hrp then
hrp.Anchored = false
hrp.AssemblyLinearVelocity = Vector3.zero
task.spawn(function()
task.wait(0.05)
local originX = lastTargetPos and lastTargetPos.X or hrp.Position.X
local originZ = lastTargetPos and lastTargetPos.Z or hrp.Position.Z
local safeY   = lastTargetPos and (lastTargetPos.Y + 1) or 1
hrp.CFrame = CFrame.new(originX, safeY, originZ)
hrp.AssemblyLinearVelocity = Vector3.zero
end)
end
if hum then
if not flyActive then hum.PlatformStand = false end
hum.WalkSpeed = 16
pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
end
end
local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
pcall(function()
workspace.CurrentCamera.CameraSubject = myHum or (myChar and myChar:FindFirstChild("HumanoidRootPart"))
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end)
sendNotif("Ghost", T.qa_stopped, 1)
end
startGhost = function(targetPlayer)
stopGhost()
if not targetPlayer or not targetPlayer.Character then
sendNotif("Ghost", T.gb_no_target_char, 2); return
end
local myChar = LocalPlayer.Character
if not myChar then sendNotif("Ghost", T.gb_no_own_char, 2); return end
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then sendNotif("Ghost", T.gb_missing_parts, 2); return end
_AF.ghostActive = true
ghostTarget_    = targetPlayer
local initHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
if initHRP then
pcall(sethiddenproperty, hrp, "PhysicsRepRootPart", initHRP)
hrp.CFrame = CFrame.new(initHRP.Position.X, GHOST_DEPTH, initHRP.Position.Z)
end
hum.PlatformStand = true
hum.WalkSpeed     = 0
pcall(function() hrp:SetNetworkOwner(LocalPlayer) end)
ghostHealthConn = hum.HealthChanged:Connect(function(newHealth)
if not _AF.ghostActive then return end
if newHealth <= 0 then
hum.Health = hum.MaxHealth
end
end)
local cam = workspace.CurrentCamera
if cam then
cam.CameraSubject = targetPlayer.Character and
(targetPlayer.Character:FindFirstChildOfClass("Humanoid") or
targetPlayer.Character:FindFirstChild("HumanoidRootPart"))
cam.CameraType = Enum.CameraType.Follow
end
local ghostStateTick = 0
local _ghostCamAcc = 0
local _ghCC = LocalPlayer.Character
local _ghMH = _ghCC and _ghCC:FindFirstChild("HumanoidRootPart")
local _ghHm = _ghCC and _ghCC:FindFirstChildOfClass("Humanoid")
local _ghTC = ghostTarget_ and ghostTarget_.Character
local _ghTH = _ghTC and _ghTC:FindFirstChild("HumanoidRootPart")
ghostConn = RunService.Heartbeat:Connect(function(dt)
if not _AF.ghostActive then return end
local myChar2 = LocalPlayer.Character
if myChar2 ~= _ghCC then
_ghCC=myChar2; _ghMH=myChar2 and myChar2:FindFirstChild("HumanoidRootPart")
_ghHm=myChar2 and myChar2:FindFirstChildOfClass("Humanoid")
end
local tChar = ghostTarget_ and ghostTarget_.Character
if tChar ~= _ghTC then _ghTC=tChar; _ghTH=tChar and tChar:FindFirstChild("HumanoidRootPart") end
local tHRP  = _ghTH; local myHRP = _ghMH
if not tHRP or not tHRP.Parent or not myHRP or not myHRP.Parent then return end
local myHum2 = _ghHm
local targetPos = Vector3.new(tHRP.Position.X, GHOST_DEPTH, tHRP.Position.Z)
local delta = targetPos - myHRP.Position
pcall(function() myHRP.AssemblyLinearVelocity = delta * GHOST_FOLLOW_SPEED end)
_ghostCamAcc = _ghostCamAcc + dt
if _ghostCamAcc >= 0.5 then
_ghostCamAcc = 0
local cam2 = _workspace.CurrentCamera
if cam2 then
if cam2.CameraType ~= Enum.CameraType.Follow then
cam2.CameraType = Enum.CameraType.Follow
end
if tChar then
local camSubject = tChar:FindFirstChildOfClass("Humanoid") or tHRP
if cam2.CameraSubject ~= camSubject then
cam2.CameraSubject = camSubject
end
end
end
end
if myHum2 then
    if not myHum2.PlatformStand then myHum2.PlatformStand = true end
    if myHum2.Health < myHum2.MaxHealth then myHum2.Health = myHum2.MaxHealth end
    ghostStateTick = ghostStateTick + dt
    if ghostStateTick >= 0.5 then
        ghostStateTick = 0
        pcall(function() myHum2:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
end
end)
ghostRespConn = targetPlayer.CharacterAdded:Connect(function(newChar)
task.wait(0.5)
if not _AF.ghostActive then return end
local newHRP = newChar:FindFirstChild("HumanoidRootPart")
local _lpc = LocalPlayer.Character
local myHRP2 =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
if newHRP and myHRP2 then
myHRP2.CFrame = CFrame.new(newHRP.Position.X, GHOST_DEPTH, newHRP.Position.Z)
pcall(function() myHRP2.AssemblyLinearVelocity = Vector3.zero end)
end
local cam3 = workspace.CurrentCamera
if cam3 then
cam3.CameraSubject = newChar:FindFirstChildOfClass("Humanoid") or newHRP
cam3.CameraType = Enum.CameraType.Follow
end
end)
local ghostPlayerRemConn
ghostPlayerRemConn = Players.PlayerRemoving:Connect(function(pl)
if pl == ghostTarget_ and _AF.ghostActive then
ghostPlayerRemConn:Disconnect()
stopGhost()
sendNotif("Ghost", "👻 " .. pl.Name .. " has left", 2)
end
end)
sendNotif("Ghost", "👻 Ghost: " .. targetPlayer.Name, 3)
end
end end _TLact_Ghost() end
do
local _genv = getgenv and getgenv()
if _genv then
rawset(_genv, "_TL_AF",               _AF)
rawset(_genv, "_TL_SOH",              _SOH)
rawset(_genv, "_TL_act_stopFollow",   _act_stopFollow)
rawset(_genv, "_TL_stopGhost",        stopGhost)
rawset(_genv, "_TL_startGhost",       startGhost)
rawset(_genv, "_TL_stopSitOnHead",    stopSitOnHead)
rawset(_genv, "_TL_stopPiggyback",    stopPiggyback)
rawset(_genv, "_TL_stopPiggyback2",   stopPiggyback2)
rawset(_genv, "_TL_stopKiss",         stopKiss)
rawset(_genv, "_TL_stopBackpack",     stopBackpack)
rawset(_genv, "_TL_stopOrbit",        stopOrbit)
rawset(_genv, "_TL_stopUpsideDown",   stopUpsideDown)
rawset(_genv, "_TL_stopCrossUD",      stopCrossUD)
rawset(_genv, "_TL_stopFriend",       stopFriend)
rawset(_genv, "_TL_stopSpinning",     stopSpinning)
rawset(_genv, "_TL_stopLicking",      stopLicking)
rawset(_genv, "_TL_stopSucking",      stopSucking)
rawset(_genv, "_TL_stopSuckIt",       stopSuckIt)
rawset(_genv, "_TL_stopBackshots",    stopBackshots)
rawset(_genv, "_TL_stopLayFuck",      stopLayFuck)
rawset(_genv, "_TL_stopFacefuck",     stopFacefuck)
rawset(_genv, "_TL_stopPussySpread",  stopPussySpread)
rawset(_genv, "_TL_stopHug",          stopHug)
rawset(_genv, "_TL_stopHug2",         stopHug2)
rawset(_genv, "_TL_stopCarry",        stopCarry)
rawset(_genv, "_TL_stopShoulderSit",  stopShoulderSit)
end
end
end)()
;(function()

local bbConn        = nil
local bbRespConn    = nil
local bbTarget_     = nil
local bbMode_       = nil
local bbAcc_        = 0
local BB_CFG = {
bb_orbit        = { distance=8,  speed=1.5  },
bb_frontwalk    = { distance=5              },
bb_behind       = { distance=5              },
bb_copy         = { distance=4              },
bb_piggyback    = {},
bb_piggyback2   = {},
bb_attach       = {},
bb_bangv2       = { speed=10.0             },
bb_carry2       = {},
bb_hug          = {},
bb_hug2         = {},
bb_layfuck      = {},
bb_licking      = { speed=3.0 },
}
local bbBP_  = nil
local bbBG_  = nil
local bbPCP_ = nil
local bbBP2_  = nil
local bbBG2_  = nil
local bbPCP2_ = nil
local bbBP3_  = nil
local bbBG3_  = nil
local bbPCP3_ = nil
local bbSBP_  = nil
local bbSBG_  = nil
local bbSPCP_ = nil
local bbAnimTrack_  = nil
local bbAnimConn_   = nil
local bbAnimTrack2_ = nil
local bbAnimConn2_  = nil
local bbAnimTrack3_ = nil
local bbAnimConn3_  = nil
local bbAnimTrack4_ = nil
local bbAnimConn4_  = nil
local bbBP4_  = nil
local bbBG4_  = nil
local bbPCP4_ = nil
local bbBP5_  = nil
local bbBG5_  = nil
local bbPCP5_ = nil
local bbOsc5_ = 0
local bbMainBV_ = nil  -- shared Y-only BodyVelocity
local bbBP6_  = nil   -- Hug BodyPosition
local bbBG6_  = nil   -- Hug BodyGyro
local bbPCP6_ = nil   -- Hug lerp pos
local bbBP7_  = nil   -- Licking BodyPosition
local bbBG7_  = nil   -- Licking BodyGyro
local bbPCP7_ = nil   -- Licking lerp pos
local bbBP8_  = nil   -- Carry
local bbBG8_  = nil
local bbPCP8_ = nil
local bbBP9_  = nil   -- Carry2
local bbBG9_  = nil
local bbPCP9_ = nil
local bbBP10_ = nil   -- Hug2
local bbBG10_ = nil
local bbPCP10_= nil
local bbBP11_ = nil   -- Orbit
local bbBG11_ = nil
local bbPCP11_= nil
local bbBP12_ = nil   -- Frontwalk/Behind/Headsit/Copy
local bbBG12_ = nil
local bbPCP12_= nil
local bbOsc6_ = 0     -- Hug oscillator
local bbAnimTrack5_ = nil
local bbAnimConn5_  = nil
local BB_CARRY_ANIM_ID     = "95469914338674"
local BB_CARRY2_ANIM_ID    = "73126126731268"
local bbAnimTrack6_ = nil
local bbAnimConn6_  = nil
local BB_HUG_ANIM_ID       = "93667149408515"
local bbAnimTrack7_ = nil
local bbAnimConn7_  = nil
local BB_BACKSHOTS_ANIM_ID = "92086651364994"
local BB_LICKING_ANIM_ID    = "86345507952689"
local bbAnimTrack8_ = nil
local bbAnimConn8_  = nil
local BB_HUG2_ANIM_ID      = "101809619267911"
local bbAnimTrack9_ = nil
local bbAnimConn9_  = nil
local BB_LAYFUCK_ANIM_ID   = "95678189010798"
local bbAnimTrack10_ = nil
local bbAnimConn10_  = nil
local bbHealthConn_   = nil
local bbRespAnimConn_ = nil  -- CharacterAdded conn for anim-restart on respawn (separate from bbAnimConn[N]_ track.Stopped slots)
local function bbGetHRP(pl)
local c = pl and pl.Character
return c and c:FindFirstChild("HumanoidRootPart")
end
local function bbGetHead(pl)
local c = pl and pl.Character
return c and c:FindFirstChild("Head")
end
local function bbStopAnim()
if bbAnimConn_  then bbAnimConn_:Disconnect();  bbAnimConn_  = nil end
if bbAnimConn2_ then bbAnimConn2_:Disconnect(); bbAnimConn2_ = nil end
if bbAnimConn3_ then bbAnimConn3_:Disconnect(); bbAnimConn3_ = nil end
if bbAnimTrack_ then
pcall(function() bbAnimTrack_:AdjustSpeed(1); bbAnimTrack_:Stop() end)
bbAnimTrack_ = nil
end
if bbAnimTrack2_ then
pcall(function() bbAnimTrack2_:AdjustSpeed(1); bbAnimTrack2_:Stop() end)
bbAnimTrack2_ = nil
end
if bbAnimTrack3_ then
pcall(function() bbAnimTrack3_:AdjustSpeed(1); bbAnimTrack3_:Stop() end)
bbAnimTrack3_ = nil
end
if bbAnimTrack4_ then
pcall(function() bbAnimTrack4_:AdjustSpeed(1); bbAnimTrack4_:Stop() end)
bbAnimTrack4_ = nil
end
if bbAnimConn4_ then bbAnimConn4_:Disconnect(); bbAnimConn4_ = nil end
if bbAnimTrack5_ then
pcall(function() bbAnimTrack5_:AdjustSpeed(1); bbAnimTrack5_:Stop() end)
bbAnimTrack5_ = nil
end
if bbAnimConn5_ then bbAnimConn5_:Disconnect(); bbAnimConn5_ = nil end
if bbAnimConn6_ then bbAnimConn6_:Disconnect(); bbAnimConn6_ = nil end
if bbAnimTrack6_ then
pcall(function() bbAnimTrack6_:AdjustSpeed(1); bbAnimTrack6_:Stop() end)
bbAnimTrack6_ = nil
end
if bbAnimConn7_ then bbAnimConn7_:Disconnect(); bbAnimConn7_ = nil end
if bbAnimConn8_ then bbAnimConn8_:Disconnect(); bbAnimConn8_ = nil end
if bbAnimConn9_ then bbAnimConn9_:Disconnect(); bbAnimConn9_ = nil end
if bbAnimConn10_ then bbAnimConn10_:Disconnect(); bbAnimConn10_ = nil end
if bbAnimTrack7_ then
pcall(function() bbAnimTrack7_:AdjustSpeed(1); bbAnimTrack7_:Stop() end)
bbAnimTrack7_ = nil
end
if bbAnimTrack9_ then
pcall(function() bbAnimTrack9_:AdjustSpeed(1); bbAnimTrack9_:Stop() end)
bbAnimTrack9_ = nil
end
if bbAnimTrack10_ then
pcall(function() bbAnimTrack10_:AdjustSpeed(1); bbAnimTrack10_:Stop() end)
bbAnimTrack10_ = nil
end
end
local function bbPlayAnim1(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(PIGGYBACK_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBPiggyback1Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, PIGGYBACK_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack_ = track
if bbAnimConn_ then bbAnimConn_:Disconnect() end
bbAnimConn_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_piggyback" then
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim1(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim2(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(PIGGYBACK2_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBPiggyback2Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, PIGGYBACK2_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack2_ = track
if bbAnimConn2_ then bbAnimConn2_:Disconnect() end
bbAnimConn2_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_piggyback2" then
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim2(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim3(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_BACKSHOTS_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBBackshotsAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_BACKSHOTS_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack3_ = track
if bbAnimConn3_ then bbAnimConn3_:Disconnect() end
bbAnimConn3_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_attach" then
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim3(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim4(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_CARRY_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBCarryAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_CARRY_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack4_ = track
if bbAnimConn4_ then bbAnimConn4_:Disconnect() end
bbAnimConn4_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_carry" then
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim4(LocalPlayer.Character) end) end
end
end)
end
local BB_BANGV2_ANIM_ID = "107300675038850"
local function bbPlayAnim5(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_BANGV2_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBBangV2Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_BANGV2_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
track:AdjustSpeed(2)
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack5_ = track
if bbAnimConn5_ then bbAnimConn5_:Disconnect() end
bbAnimConn5_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_bangv2" then
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim5(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim6(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_CARRY2_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBCarry2Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_CARRY2_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack6_ = track
if bbAnimConn6_ then bbAnimConn6_:Disconnect() end
local restarts6 = 0
bbAnimConn6_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_carry2" and restarts6 < 20 then
restarts6 = restarts6 + 1
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim6(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim7(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_HUG_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBHugAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_HUG_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end

pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack7_ = track
if bbAnimConn7_ then bbAnimConn7_:Disconnect() end
local restarts7 = 0
bbAnimConn7_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_hug" and restarts7 < 20 then
restarts7 = restarts7 + 1
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim7(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim8(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_LICKING_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBLickingAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_LICKING_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum =_lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack8_ = track
if bbAnimConn8_ then bbAnimConn8_:Disconnect() end
local restarts8 = 0
bbAnimConn8_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_licking" and restarts8 < 20 then
restarts8 = restarts8 + 1
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim8(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim9(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_HUG2_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBHug2Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_HUG2_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum = _lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack9_ = track
if bbAnimConn9_ then bbAnimConn9_:Disconnect() end
local restarts9 = 0
bbAnimConn9_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_hug2" and restarts9 < 20 then
restarts9 = restarts9 + 1
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim9(LocalPlayer.Character) end) end
end
end)
end
local function bbPlayAnim10(char)
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
local track = nil
local emoteId = tonumber(BB_LAYFUCK_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BBLayFuckAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
    track = _AF_loadAndPlayAnimation(hum, BB_LAYFUCK_ANIM_ID)
    if track then track:Play() end
end)
end
if not track or type(track) ~= "userdata" then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
if setFreeze then setFreeze(true) end
local _lpc = LocalPlayer.Character
local mHum = _lpc and _lpc:FindFirstChildOfClass("Humanoid")
if mHum then mHum.PlatformStand = true end
bbAnimTrack10_ = track
if bbAnimConn10_ then bbAnimConn10_:Disconnect() end
local restarts10 = 0
bbAnimConn10_ = track.Stopped:Connect(function()
if _AF.bbActive and bbMode_ == "bb_layfuck" and restarts10 < 20 then
restarts10 = restarts10 + 1
task.wait(0.05)
if _AF.bbActive then pcall(function() bbPlayAnim10(LocalPlayer.Character) end) end
end
end)
end
stopBB = function()
local wasActive = _AF.bbActive
_AF.bbActive = false
if bbConn       then bbConn:Disconnect();       bbConn       = nil end
if bbRespConn   then bbRespConn:Disconnect();   bbRespConn   = nil end
if bbHealthConn_   then bbHealthConn_:Disconnect();   bbHealthConn_   = nil end
if bbRespAnimConn_ then bbRespAnimConn_:Disconnect(); bbRespAnimConn_ = nil end
bbTarget_ = nil; bbMode_ = nil; bbAcc_ = 0
if bbBP_  then pcall(function() bbBP_:Destroy()  end); bbBP_  = nil end
if bbBG_  then pcall(function() bbBG_:Destroy()  end); bbBG_  = nil end
if bbBP2_ then pcall(function() bbBP2_:Destroy() end); bbBP2_ = nil end
if bbBG2_ then pcall(function() bbBG2_:Destroy() end); bbBG2_ = nil end
if bbBP3_ then pcall(function() bbBP3_:Destroy() end); bbBP3_ = nil end
if bbBG3_ then pcall(function() bbBG3_:Destroy() end); bbBG3_ = nil end
if bbBP4_ then pcall(function() bbBP4_:Destroy() end); bbBP4_ = nil end
if bbBG4_ then pcall(function() bbBG4_:Destroy() end); bbBG4_ = nil end
if bbBP5_ then pcall(function() bbBP5_:Destroy() end); bbBP5_ = nil end
if bbBG5_ then pcall(function() bbBG5_:Destroy() end); bbBG5_ = nil end
if bbMainBV_ then pcall(function() bbMainBV_:Destroy() end); bbMainBV_ = nil end
if bbBP6_ then pcall(function() bbBP6_:Destroy() end); bbBP6_ = nil end
if bbBG6_ then pcall(function() bbBG6_:Destroy() end); bbBG6_ = nil end
if bbBP7_ then pcall(function() bbBP7_:Destroy() end); bbBP7_ = nil end
if bbBG7_ then pcall(function() bbBG7_:Destroy() end); bbBG7_ = nil end
if bbBP8_  then pcall(function() bbBP8_:Destroy()  end); bbBP8_  = nil end
if bbBG8_  then pcall(function() bbBG8_:Destroy()  end); bbBG8_  = nil end
if bbBP9_  then pcall(function() bbBP9_:Destroy()  end); bbBP9_  = nil end
if bbBG9_  then pcall(function() bbBG9_:Destroy()  end); bbBG9_  = nil end
if bbBP10_ then pcall(function() bbBP10_:Destroy() end); bbBP10_ = nil end
if bbBG10_ then pcall(function() bbBG10_:Destroy() end); bbBG10_ = nil end
if bbBP11_ then pcall(function() bbBP11_:Destroy() end); bbBP11_ = nil end
if bbBG11_ then pcall(function() bbBG11_:Destroy() end); bbBG11_ = nil end
if bbBP12_ then pcall(function() bbBP12_:Destroy() end); bbBP12_ = nil end
if bbBG12_ then pcall(function() bbBG12_:Destroy() end); bbBG12_ = nil end
bbPCP6_ = nil; bbPCP7_ = nil; bbPCP8_ = nil; bbPCP9_ = nil
bbPCP10_= nil; bbPCP11_= nil; bbPCP12_= nil
if bbSBP_ then pcall(function() bbSBP_:Destroy() end); bbSBP_ = nil end
if bbSBG_ then pcall(function() bbSBG_:Destroy() end); bbSBG_ = nil end
bbPCP4_ = nil
bbPCP5_ = nil
bbOsc6_ = 0
bbSPCP_ = nil
bbOsc5_ = 0
bbPCP_ = nil
bbPCP2_ = nil
bbPCP3_ = nil
bbStopAnim()
local myChar = LocalPlayer.Character
if myChar then
local hrp = myChar:FindFirstChild("HumanoidRootPart")
local hum = myChar:FindFirstChildOfClass("Humanoid")
if hrp then
pcall(function() sethiddenproperty(hrp, "PhysicsRepRootPart", nil) end)
pcall(function() hrp.AssemblyLinearVelocity  = Vector3.zero end)
pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end)
pcall(function() hrp.Anchored = false end)
-- destroy all remaining mover instances by class
pcall(function()
for _, o in ipairs(hrp:GetChildren()) do
if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity")
or o:IsA("BodyPosition") or o:IsA("BodyGyro") then
pcall(function() o:Destroy() end)
end
end
end)
end
if hum then
pcall(function() if not flyActive then hum.PlatformStand = false end end)
pcall(function() hum.WalkSpeed = 16 end)
pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
end
-- restore collisions for every BasePart in character
pcall(function()
for _, p in ipairs(myChar:GetDescendants()) do
if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
end
end)
end
if setFreeze then pcall(function() setFreeze(false) end) end
if wasActive then sendNotif("ByteBreaker", T.qa_stopped, 1) end
-- Re-enable sitting when ByteBreaker stops
pcall(function() local hum = getHumanoid(); if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end end)
    
    -- Robust delayed cleanup
    task.delay(0.08, function()
        local c2 = LocalPlayer.Character
        local r2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        local h2 = c2 and c2:FindFirstChildOfClass("Humanoid")
        if r2 then
            pcall(function() sethiddenproperty(r2, "PhysicsRepRootPart", nil) end)
            pcall(function() r2.AssemblyLinearVelocity = _V3_ZERO end)
            pcall(function()
                for _, o in ipairs(r2:GetChildren()) do
                    if o:IsA("BodyVelocity") or o:IsA("BodyAngularVelocity")
                    or o:IsA("BodyPosition") or o:IsA("BodyGyro") then
                        o:Destroy()
                    end
                end
            end)
        end
        if h2 then
            pcall(function() h2.Sit = false end)
            if not flyActive then pcall(function() h2.PlatformStand = false end) end
            pcall(function() h2:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        pcall(safeStand)
    end)
end
_TL_refs._TL_startBB = nil
startBB = function(targetPlayer, modeKey)
_TL_refs._TL_startBB = startBB
_G.startBB = startBB
stopBB()
if not targetPlayer or not targetPlayer.Character then
sendNotif("ByteBreaker", T.gb_no_target_char, 2); return
end
local myChar = LocalPlayer.Character
if not myChar then sendNotif("ByteBreaker", T.gb_no_own_char, 2); return end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local myHum = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not myHum then sendNotif("ByteBreaker", T.gb_missing_parts, 2); return end
local tHRP_init = bbGetHRP(targetPlayer)
if not tHRP_init then sendNotif("ByteBreaker", T.gb_no_target_char, 2); return end
_AF.bbActive = true
bbTarget_    = targetPlayer
bbMode_      = modeKey
bbAcc_       = 0
myHum.PlatformStand = true
myHum.WalkSpeed     = 0
pcall(function() myHRP:SetNetworkOwner(LocalPlayer) end)
-- Prevent sitting on benches/chairs during ByteBreaker
pcall(function() local hum = getHumanoid(); if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end end)
if bbHealthConn_ then bbHealthConn_:Disconnect(); bbHealthConn_ = nil end
local VOID_Y     = -200
local RESCUE_Y   = 50
local _lastSafeY = myHRP.Position.Y
local _bbDiedConn = nil
local function hookDied(hm2)
if _bbDiedConn then pcall(function() _bbDiedConn:Disconnect() end) end
_bbDiedConn = hm2.Died:Connect(function()
if not _AF.bbActive then return end
pcall(function() hm2.Health = hm2.MaxHealth end)
task.wait()
pcall(function() hm2.Health = hm2.MaxHealth end)
end)
end
hookDied(myHum)
LocalPlayer.CharacterAdded:Connect(function(newChar)
if not _AF.bbActive then
return
end
local newHum = newChar:WaitForChild("Humanoid", 5)
if newHum then hookDied(newHum) end
end)
local _bbHAcc = 0
local _bbHC_char = LocalPlayer.Character
local _bbHC_hrp  = _bbHC_char and _bbHC_char:FindFirstChild("HumanoidRootPart")
local _bbHC_hm   = _bbHC_char and _bbHC_char:FindFirstChildOfClass("Humanoid")
local _bbHAcc2 = 0
bbHealthConn_ = RunService.Heartbeat:Connect(function(dt)
if not _AF.bbActive then return end
_bbHAcc2 = _bbHAcc2 + dt
if _bbHAcc2 < 0.08 then return end
_bbHAcc2 = 0
local c = LocalPlayer.Character
if c ~= _bbHC_char then
_bbHC_char = c
_bbHC_hrp  = c and c:FindFirstChild("HumanoidRootPart")
_bbHC_hm   = c and c:FindFirstChildOfClass("Humanoid")
end
local hrp = _bbHC_hrp
local hm  = _bbHC_hm
if not hrp or not hrp.Parent or not hm then return end
if hrp.Position.Y > VOID_Y then
_lastSafeY = hrp.Position.Y
end
if hm.Health < hm.MaxHealth then hm.Health = hm.MaxHealth end
_bbHAcc = _bbHAcc + dt
if _bbHAcc >= 0.5 then
    _bbHAcc = 0
    if hm.SeatPart then pcall(function() hm:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
    pcall(function() hm:ChangeState(Enum.HumanoidStateType.Physics) end)
end
if hrp.Position.Y < VOID_Y then
local tHRP2 = bbGetHRP(bbTarget_)
local rescueCF = tHRP2
and (tHRP2.CFrame * CFrame.new(0, RESCUE_Y, 0))
or CFrame.new(hrp.Position.X, math.max(_lastSafeY, RESCUE_Y), hrp.Position.Z)
pcall(function()
hrp.CFrame = rescueCF
hrp.AssemblyLinearVelocity = Vector3.zero
hm.Health = hm.MaxHealth
end)
end
end)
pcall(function() sethiddenproperty(myHRP, "PhysicsRepRootPart", tHRP_init) end)
-- disable collisions for every BasePart in character (mirrors setCollisions(false))
for _, p in ipairs(myChar:GetDescendants()) do
if p:IsA("BasePart") then p.CanCollide = false end
end
-- Zero velocity and pre-position before loop starts (prevents initial bounce)
pcall(function()
    myHRP.AssemblyLinearVelocity  = Vector3.zero
    myHRP.AssemblyAngularVelocity = Vector3.zero
end)
-- BodyVelocity Y-only: counteracts gravity for all direct-CFrame modes
if bbMainBV_ then pcall(function() bbMainBV_:Destroy() end); bbMainBV_ = nil end
bbMainBV_ = Instance.new("BodyVelocity")
bbMainBV_.MaxForce = Vector3.new(0, 1e6, 0)
bbMainBV_.Velocity = Vector3.zero
bbMainBV_.Parent   = myHRP
local _bbMyCharCache = myChar
local _bbMHRP        = myChar:FindFirstChild("HumanoidRootPart")
local _bbMHum        = myChar:FindFirstChildOfClass("Humanoid")
-- cache tHRP so FindFirstChild isn't called every frame
local _bbCachedTHRP   = nil
local _bbCachedTChar  = false  -- false sentinel forces cache on first frame
local _bbCachedTorso  = nil

local function _guardHum()
    local mHum = _bbMHum
    if mHum and not mHum.PlatformStand then mHum.PlatformStand = true end
end

local _bbSHPFrame = 0
bbConn = RunService.Heartbeat:Connect(function(dt)
if not _AF.bbActive then return end
-- update my char cache
local curChar = LocalPlayer.Character
local _charChanged = (curChar ~= _bbMyCharCache)
if _charChanged then
_bbMyCharCache = curChar
_bbMHRP = curChar and curChar:FindFirstChild("HumanoidRootPart")
_bbMHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
end
local mHRP = _bbMHRP
local mHum = _bbMHum
if not bbTarget_ or not bbTarget_.Parent then stopBB(); return end
if not mHRP or not mHRP.Parent then return end
-- cache target HRP: only re-lookup when target char changes
local tChar = bbTarget_.Character
if tChar ~= _bbCachedTChar then
_bbCachedTChar  = tChar
_bbCachedTHRP   = tChar and tChar:FindFirstChild("HumanoidRootPart")
_bbCachedTorso  = tChar and (tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso"))
end
local tHRP = _bbCachedTHRP
if not tHRP or not tHRP.Parent then return end
-- torso is cached with tChar (same change detection as tHRP)
local _torso = _bbCachedTorso or tHRP  -- guaranteed non-nil
-- throttle sethiddenproperty to every 3 frames (reduces hidden-property overhead by 67%)
_bbSHPFrame = _bbSHPFrame + 1
if _bbSHPFrame >= 3 then
    _bbSHPFrame = 0
    pcall(sethiddenproperty, mHRP, "PhysicsRepRootPart", tHRP)
end
-- Velocity-Reset jeden Frame
pcall(function()
    mHRP.AssemblyLinearVelocity  = _V3_ZERO
    mHRP.AssemblyAngularVelocity = _V3_ZERO
end)
-- disable collisions: only re-sweep when character instance changed (avoids per-frame Descendants scan)
if _charChanged and curChar then
    for _, p in ipairs(curChar:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end
-- Refresh shared BodyVelocity only if genuinely lost (no destroy-loop, no GetChildren scan)
if not bbMainBV_ or not bbMainBV_.Parent then
    bbMainBV_ = Instance.new("BodyVelocity")
    bbMainBV_.MaxForce = Vector3.new(0, 1e6, 0)
    bbMainBV_.Velocity = _V3_ZERO
    bbMainBV_.Parent   = mHRP
end
bbAcc_ = bbAcc_ + dt
local key = bbMode_
if key == "bb_attach" then
-- Attached script pattern: BodyVelocity(Y) + oscillating CFrame + velocity=zero
local offset = -2.0 - math.sin(bbAcc_ * 10.0) * 1.5
mHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, offset)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_orbit" then
local dist  = BB_CFG.bb_orbit.distance
local spd   = BB_CFG.bb_orbit.speed
local angle = bbAcc_ * spd
local pos = Vector3.new(
tHRP.Position.X + math.cos(angle) * dist,
tHRP.Position.Y,
tHRP.Position.Z + math.sin(angle) * dist)
mHRP.CFrame = CFrame.new(pos, tHRP.Position)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_frontwalk" then
local look = tHRP.CFrame.LookVector
local pos  = tHRP.Position + look * BB_CFG.bb_frontwalk.distance
mHRP.CFrame = CFrame.new(pos, pos + look)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_behind" then
local look = tHRP.CFrame.LookVector
local pos  = tHRP.Position - look * BB_CFG.bb_behind.distance
mHRP.CFrame = CFrame.new(pos, pos + look)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_headsit" then
local head = tChar and tChar:FindFirstChild("Head")
local base = head and head.CFrame or (tHRP.CFrame * CFrame.new(0, 3, 0))
mHRP.CFrame = CFrame.new(base.Position + Vector3.new(0, 1.4, 0))
* CFrame.fromEulerAnglesXYZ(math.rad(90), select(2, tHRP.CFrame:ToEulerAnglesXYZ()), 0)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_copy" then
mHRP.CFrame = tHRP.CFrame * CFrame.new(BB_CFG.bb_copy.distance, 0, 0)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_piggyback" then
-- Attached script: BodyPosition+BodyGyro+Lerp (startPiggyback pattern)
local torso = _torso
if not bbBP_ then
bbBP_ = Instance.new("BodyPosition")
bbBP_.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bbBP_.P = 500000; bbBP_.D = 2500; bbBP_.Parent = mHRP
end
if not bbBG_ then
bbBG_ = Instance.new("BodyGyro")
bbBG_.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bbBG_.P = 500000; bbBG_.D = 2500; bbBG_.Parent = mHRP
end
if not bbPCP_ then bbPCP_ = mHRP.Position end
local tgt = torso.Position + torso.CFrame.LookVector * -1.1 + Vector3.new(0, 0.2, 0)
bbPCP_ = bbPCP_:Lerp(tgt, 1-(0.02^(dt*60)))
bbBP_.Position = bbPCP_
bbBG_.CFrame   = CFrame.new(mHRP.Position, mHRP.Position + torso.CFrame.LookVector)
_guardHum()
elseif key == "bb_piggyback2" then
local torso = _torso
if not bbBP2_ then
bbBP2_ = Instance.new("BodyPosition")
bbBP2_.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bbBP2_.P = 500000; bbBP2_.D = 2500; bbBP2_.Parent = mHRP
end
if not bbBG2_ then
bbBG2_ = Instance.new("BodyGyro")
bbBG2_.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
bbBG2_.P = 500000; bbBG2_.D = 2500; bbBG2_.Parent = mHRP
end
if not bbPCP2_ then bbPCP2_ = mHRP.Position end
local tgt = torso.Position + torso.CFrame.LookVector * -1.1 + Vector3.new(0, 0.2, 0)
bbPCP2_ = bbPCP2_:Lerp(tgt, 1-(0.02^(dt*60)))
bbBP2_.Position = bbPCP2_
bbBG2_.CFrame   = CFrame.new(mHRP.Position, mHRP.Position + torso.CFrame.LookVector)
_guardHum()
elseif key == "bb_carry" then
-- Attached script: BodyVelocity(Y) + direct CFrame + velocity=zero
local torso = _torso
mHRP.CFrame = torso.CFrame * CFrame.new(0.5, -0.5, -1.2)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_carry2" then
local torso = _torso
mHRP.CFrame = torso.CFrame * CFrame.new(0.5, 1.0, -1.2)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_hug" then
-- Attached script startHug: BodyVelocity(Y) + oscTime + offset = -1.2 - sin(t)*0.1
local torso = _torso
local offset = -1.2 - math.sin(bbAcc_ * 10.0) * 0.1
mHRP.CFrame = torso.CFrame
    * CFrame.new(0, 0, offset)
    * CFrame.Angles(0, math.rad(180), 0)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_hug2" then
local torso = _torso
mHRP.CFrame = torso.CFrame * CFrame.new(0, 0, 1.1)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_layfuck" then
-- Attached script: BodyVelocity(Y) + direct CFrame + velocity=zero
local torso = _torso
local zOff = 1.1 + math.sin(bbAcc_ * 12.0) * 0.9
mHRP.CFrame = torso.CFrame * CFrame.new(0, -0.8, zOff)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_licking" then
-- Attached script startLicking: BodyVelocity(Y) + oscTime + offset = -2.5 - sin(t)*0.4
local torso = _torso
local offset = -2.5 - math.sin(bbAcc_ * 10.0) * 0.4
mHRP.CFrame = torso.CFrame
    * CFrame.new(0, 0, offset)
    * CFrame.Angles(0, math.rad(180), 0)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
elseif key == "bb_bangv2" then
-- Attached script startBackshots pattern: BodyVelocity(Y) + oscTime + relative CFrame
local torso = _torso
bbOsc5_ = bbOsc5_ + dt * BB_CFG.bb_bangv2.speed
local oscOffset = 3.5 - math.sin(bbOsc5_) * 3
mHRP.CFrame = torso.CFrame * CFrame.new(0, 0.2, oscOffset)
mHRP.AssemblyLinearVelocity = _V3_ZERO
_guardHum()
end
end)
-- Map each mode to its play function so a single bbRespAnimConn_ handles all respawn-restarts.
-- bbAnimConn[N]_ slots are ONLY used by bbPlayAnim[N] for track.Stopped auto-restart;
-- mixing CharacterAdded into those slots would overwrite the track.Stopped connection (Bug fix).
local _bbAnimFn = nil
if modeKey == "bb_piggyback" then
task.spawn(function() bbPlayAnim1(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim1
elseif modeKey == "bb_piggyback2" then
task.spawn(function() bbPlayAnim2(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim2
elseif modeKey == "bb_attach" then
task.spawn(function() bbPlayAnim3(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim3
elseif modeKey == "bb_carry" then
task.spawn(function() bbPlayAnim4(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim4
elseif modeKey == "bb_carry2" then
task.spawn(function() bbPlayAnim6(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim6
elseif modeKey == "bb_hug" then
task.spawn(function() bbPlayAnim7(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim7
elseif modeKey == "bb_hug2" then
task.spawn(function() bbPlayAnim9(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim9
elseif modeKey == "bb_layfuck" then
task.spawn(function() bbPlayAnim10(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim10
elseif modeKey == "bb_licking" then
task.spawn(function() bbPlayAnim8(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim8
elseif modeKey == "bb_bangv2" then
bbOsc5_ = 0
task.spawn(function() bbPlayAnim5(LocalPlayer.Character) end)
_bbAnimFn = bbPlayAnim5
end
if _bbAnimFn then
if bbRespAnimConn_ then bbRespAnimConn_:Disconnect() end
bbRespAnimConn_ = LocalPlayer.CharacterAdded:Connect(function(char)
if _AF.bbActive and _bbAnimFn then
task.wait(0.5); task.spawn(function() _bbAnimFn(char) end)
end
end)
end
bbRespConn = targetPlayer.CharacterAdded:Connect(function()
task.wait(0.5)
if not _AF.bbActive then return end
local _lpc = LocalPlayer.Character
local mHRP2 = _lpc and _lpc:FindFirstChild("HumanoidRootPart")
if mHRP2 then
pcall(function()
mHRP2.AssemblyLinearVelocity  = Vector3.zero
mHRP2.AssemblyAngularVelocity = Vector3.zero
end)
end
end)
local bbRemConn
bbRemConn = _tlTrackConn(Players.PlayerRemoving:Connect(function(pl)
if pl == bbTarget_ and _AF.bbActive then
bbRemConn:Disconnect()
stopBB()
sendNotif("ByteBreaker", "👋 "..pl.Name.." has left", 2)
end
end))
local modeNames = {
bb_attach="ByteBackshots", bb_orbit="Orbit", bb_frontwalk="Front",
bb_behind="Behind", bb_headsit="Head Sit", bb_copy="Copy",
bb_piggyback="Piggyback", bb_piggyback2="Piggyback2", bb_carry="Carry",
bb_bangv2="BangV2", bb_carry2="Carry2", bb_hug="Hug", bb_hug2="Hug2", bb_layfuck="LayFuck", bb_licking="Licking",
}
sendNotif("ByteBreaker", "🎬 "..(modeNames[modeKey] or modeKey)..": "..targetPlayer.Name, 3)
end
end)()
local _TL_IIFE_=nil;(function()
local p, c = makePanel("Playerlist", C.accent)
p.BackgroundColor3 = C.panelBg
p.BackgroundTransparency = 0
local _eg = p:FindFirstChildOfClass("UIGradient"); if _eg then _eg:Destroy() end

local PAD           = 16
local PW            = PANEL_W - PAD * 2
local ROW_H_ACTUAL  = 70
local GAP           = 6
local avatarCache   = {}
local rowCache      = {}
local espHighlights = {}
local _plFilterText = ""

local STAFF_BY_PLACE = {
[136162036182779] = {
["soulofadore"]=true,["Gzupdrizzy"]=true,["CidsCurse"]=true,
["7Zois"]=true,["DragoX_rblx"]=true,["tenwlk"]=true,
["crashedfantasy"]=true,["HeavenlyHildeLu"]=true,
["o7nov"]=true,["cemalisiert"]=true,
},
}

-- -- Header: Spieleranzahl + Suchleiste ------------------------------------
local HEADER_H = 44

-- Spieleranzahl-Badge (oben rechts im Panel-Header)
local countBadge = Instance.new("Frame", c)
countBadge.Size              = UDim2.new(0, 36, 0, 20)
countBadge.Position          = UDim2.new(1, -PAD - 36, 0, 12)
countBadge.BackgroundColor3  = C.accent
countBadge.BackgroundTransparency = 0.72
countBadge.BorderSizePixel   = 0
corner(countBadge, 99)
local countLbl = Instance.new("TextLabel", countBadge)
countLbl.Size                = UDim2.new(1,0,1,0)
countLbl.BackgroundTransparency = 1
countLbl.Font                = Enum.Font.GothamBlack
countLbl.TextSize             = 10
countLbl.TextColor3           = C.accent
countLbl.TextXAlignment       = Enum.TextXAlignment.Center
countLbl.Text                 = tostring(#Players:GetPlayers())

-- Suchleiste
local searchFrame = Instance.new("Frame", c)
searchFrame.Size              = UDim2.new(1, -PAD*2, 0, 28)
searchFrame.Position          = UDim2.new(0, PAD, 0, 6)
searchFrame.BackgroundColor3  = C.bg2 or _C3_BG2
searchFrame.BackgroundTransparency = 0
searchFrame.BorderSizePixel   = 0
corner(searchFrame, 8)
local searchStroke = _makeDummyStroke(searchFrame)
searchStroke.Thickness   = 1
searchStroke.Color       = C.bg3 or _C3_BG3
searchStroke.Transparency = 0.3

local searchIcon = Instance.new("TextLabel", searchFrame)
searchIcon.Size              = UDim2.new(0,24,1,0)
searchIcon.Position          = UDim2.new(0,6,0,0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text              = "🔍"
searchIcon.Font              = Enum.Font.GothamBold
searchIcon.TextSize          = 12
searchIcon.TextXAlignment    = Enum.TextXAlignment.Center

local searchBox = Instance.new("TextBox", searchFrame)
searchBox.Size               = UDim2.new(1,-58,1,0)
searchBox.Position           = UDim2.new(0,28,0,0)
searchBox.BackgroundTransparency = 1
searchBox.Font               = Enum.Font.Gotham
searchBox.TextSize           = 12
searchBox.TextColor3         = C.text or Color3.new(1,1,1)
searchBox.PlaceholderText    = "Spieler suchen 🔍"
searchBox.PlaceholderColor3  = C.sub or Color3.fromRGB(120,120,130)
searchBox.Text               = ""
searchBox.ClearTextOnFocus   = false
searchBox.ZIndex             = 5

searchBox.Focused:Connect(function()
    twP(searchStroke, 0.15, {Color = C.accent, Transparency = 0.45})
end)
searchBox.FocusLost:Connect(function()
    twP(searchStroke, 0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.3})
end)

-- Divider unter Suchleiste
local hdrLine = Instance.new("Frame", c)
hdrLine.Size             = UDim2.new(1,-PAD*2,0,1)
hdrLine.Position         = UDim2.new(0,PAD,0,HEADER_H - 2)
hdrLine.BackgroundColor3 = C.bg3 or _C3_BG3
hdrLine.BackgroundTransparency = 0.3
hdrLine.BorderSizePixel  = 0

-- -- Row-Bausteine ----------------------------------------------------------
local function makePillBtn(parent, xScale, xOff, w, label, accentC)
    local col = accentC or C.accent
    -- -- Flat chip: kein Stroke, volle Accent-Füllung, kompakt ----------
    local f = Instance.new("Frame", parent)
    f.Size              = UDim2.new(0, w, 0, 22)
    f.Position          = UDim2.new(xScale, xOff, 0.5, -11)
    f.BackgroundColor3  = col
    f.BackgroundTransparency = 0.72
    f.BorderSizePixel   = 0
    corner(f, 99)   -- vollrund (Pill-Shape)
    local s = _makeDummyStroke(f)
    s.Thickness = 0; s.Color = col; s.Transparency = 1  -- unsichtbar, für Tween-Target
    local tb = Instance.new("TextButton", f)
    tb.Size             = UDim2.new(1,0,1,0)
    tb.BackgroundTransparency = 1
    tb.Text             = label:upper()
    tb.Font             = Enum.Font.GothamBlack
    tb.TextSize         = 9
    tb.TextColor3       = col
    tb.ZIndex           = 8
    tb.Active           = true
    local function onHover()
        _playHoverSound()
        twP(f,  0.08, {BackgroundColor3 = col, BackgroundTransparency = 0.2})
        twP(tb, 0.08, {TextColor3 = Color3.new(1,1,1)})
    end
    local function onLeave()
        twP(f,  0.12, {BackgroundColor3 = col, BackgroundTransparency = 0.72})
        twP(tb, 0.12, {TextColor3 = col})
    end
    tb.MouseEnter:Connect(onHover)
    tb.MouseLeave:Connect(onLeave)
    tb.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then onHover() end
    end)
    tb.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then onLeave() end
    end)
    return f, tb, s
end

local function createRow(pl, yPos)
    local isMe  = (pl == LocalPlayer)
    local col   = isMe and (C.accent or Color3.fromRGB(120,200,255))
                       or  C.accent2 or C.accent

    local card = Instance.new("Frame", c)
    card.Name             = "plRow_"..pl.UserId
    card.Size             = UDim2.new(1, -PAD*2, 0, ROW_H_ACTUAL)
    card.Position         = UDim2.new(0, PAD, 0, yPos)
    card.BackgroundColor3 = C.bg2 or _C3_BG2
    card.BackgroundTransparency = 0
    card.BorderSizePixel  = 0
    corner(card, 12)

    local cStr = _makeDummyStroke(card)
    cStr.Thickness   = 1
    cStr.Color       = C.bg3 or _C3_BG3
    cStr.Transparency = 0.35

    -- accent bar (left edge)
    local cdot = Instance.new("Frame", card)
    cdot.Size             = UDim2.new(0, 3, 0, ROW_H_ACTUAL - 18); cdot.Visible = false
    cdot.Position         = UDim2.new(0, 0, 0.5, -(ROW_H_ACTUAL-18)/2)
    cdot.BackgroundColor3 = col
    cdot.BackgroundTransparency = 0.35
    cdot.BorderSizePixel  = 0
    corner(cdot, 99)

    -- Avatar
    local avF = Instance.new("Frame", card)
    avF.Name              = "avF"
    avF.Size              = UDim2.new(0, 42, 0, 42)
    avF.Position          = UDim2.new(0, 12, 0.5, -21)
    avF.BackgroundColor3  = C.bg3 or _C3_BG3
    avF.BackgroundTransparency = 0.2
    avF.BorderSizePixel   = 0
    corner(avF, 99)
    local clipF = Instance.new("Frame", avF)
    clipF.Size            = UDim2.new(1,0,1,0)
    clipF.BackgroundTransparency = 1
    clipF.ClipsDescendants = true
    corner(clipF, 99)
    local avatar = Instance.new("ImageLabel", clipF)
    avatar.Size           = UDim2.new(1,0,1,0)
    avatar.BackgroundTransparency = 1
    avatar.ScaleType      = Enum.ScaleType.Crop
    avatar.ZIndex         = 4
    if avatarCache[pl.UserId] then
        avatar.Image      = avatarCache[pl.UserId]
        avatar.ImageColor3= Color3.new(1,1,1)
    else
        avatar.Image      = "rbxassetid://142509179"
        avatar.ImageColor3= C.sub or Color3.fromRGB(100,100,110)
        task.spawn(function()
            local ok, url = pcall(function()
                return Players:GetUserThumbnailAsync(
                    pl.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100
                )
            end)
            if ok and url and avatar.Parent then
                avatarCache[pl.UserId] = url
                avatar.Image           = url
                avatar.ImageColor3     = Color3.new(1,1,1)
            end
        end)
    end
    local ring = _makeDummyStroke(avF)
    ring.Thickness   = 1.5
    ring.Color       = col
    ring.Transparency = 0.35

    -- Name + username
    local NX = 62
    local nameLbl = Instance.new("TextLabel", card)
    nameLbl.Size             = UDim2.new(0, PW - NX - 4, 0, 18)
    nameLbl.Position         = UDim2.new(0, NX, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text             = pl.DisplayName
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 13
    nameLbl.TextColor3       = C.text or Color3.new(1,1,1)
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.TextTruncate     = Enum.TextTruncate.AtEnd

    local userLbl = Instance.new("TextLabel", card)
    userLbl.Size             = UDim2.new(0, 160, 0, 12)
    userLbl.Position         = UDim2.new(0, NX, 0, 27)
    userLbl.BackgroundTransparency = 1
    userLbl.Text             = "@"..pl.Name..(isMe and "  ★" or "")
    userLbl.Font             = Enum.Font.GothamBold
    userLbl.TextSize         = 9
    userLbl.TextColor3       = C.sub or Color3.fromRGB(120,120,130)
    userLbl.TextXAlignment   = Enum.TextXAlignment.Left
    userLbl.TextTruncate     = Enum.TextTruncate.AtEnd

    -- Rank badge
    local rankBg = Instance.new("Frame", card)
    rankBg.Size              = UDim2.new(0, 52, 0, 14)
    rankBg.Position          = UDim2.new(0, NX, 0, 42)
    rankBg.BackgroundColor3  = C.bg3 or _C3_BG3
    rankBg.BackgroundTransparency = 0.35
    rankBg.BorderSizePixel   = 0
    corner(rankBg, 99)
    local rankTxt = Instance.new("TextLabel", rankBg)
    rankTxt.Size             = UDim2.new(1,0,1,0)
    rankTxt.BackgroundTransparency = 1
    rankTxt.Font             = Enum.Font.GothamBold
    rankTxt.TextSize         = 8
    rankTxt.Text             = "Spieler"
    rankTxt.TextColor3       = C.sub or Color3.fromRGB(120,120,130)
    rankTxt.TextXAlignment   = Enum.TextXAlignment.Center
    task.spawn(function()
        local staffList = STAFF_BY_PLACE[game.PlaceId]
        if staffList and staffList[pl.Name] then
            if rankBg.Parent then
                rankBg.BackgroundColor3      = Color3.fromRGB(255,200,80)
                rankBg.BackgroundTransparency = 0.72
                rankTxt.Text      = "Moderator"
                rankTxt.TextColor3= Color3.fromRGB(255,215,100)
            end
        end
    end)

    -- Action pills (right side)
    local PW2, G2 = 44, 5

    -- ESP pill
    local espF, espBtn, espS = makePillBtn(card, 1, -PW2-8, PW2, "ESP", C.accent)
    local espOn = false
    local function setEsp(on)
        espOn = on
        if on then
            espBtn.Text = "ESP ◈"
            twP(espF,  0.15, {BackgroundColor3 = C.accent, BackgroundTransparency = 0.75})
            twP(espS,  0.15, {Transparency = 0.1})
            twP(cStr,  0.15, {Color = C.accent, Transparency = 0.35})
            local char = pl.Character
            if char and not espHighlights[pl] then
                local h = Instance.new("Highlight", PlayerGui)
                h.Adornee          = char
                h.FillTransparency = 1
                h.OutlineColor     = Color3.new(1,1,1)
                h.OutlineTransparency = 0
                espHighlights[pl]  = h
            end
        else
            espBtn.Text = "ESP"
            twP(espF,  0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.25})
            twP(espS,  0.15, {Transparency = 0.6})
            twP(cStr,  0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.35})
            if espHighlights[pl] then
                espHighlights[pl]:Destroy(); espHighlights[pl] = nil
            end
        end
    end
    espBtn.MouseButton1Click:Connect(function() setEsp(not espOn) end)
    espBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then setEsp(not espOn) end
    end)

    if not isMe then
        -- TP pill
        local _, tpBtn = makePillBtn(card, 1, -PW2-8-G2-PW2, PW2, "TP", C.accent)
        tpBtn.MouseButton1Click:Connect(function()
            if pl.Character then
                local tR = pl.Character:FindFirstChild("HumanoidRootPart")
                local mR = getRootPart()
                if tR and mR then mR.CFrame = tR.CFrame * CFrame.new(0,0,3.5) end
            end
        end)
        tpBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                if pl.Character then
                    local tR = pl.Character:FindFirstChild("HumanoidRootPart")
                    local mR = getRootPart()
                    if tR and mR then mR.CFrame = tR.CFrame * CFrame.new(0,0,3.5) end
                end
            end
        end)

        -- Spec pill
        local isSpectating = false
        local specF, specBtn, specS2 = makePillBtn(card, 1, -PW2-8-G2-PW2-G2-PW2, PW2, "Spec", C.accent2 or C.accent)
        local function setSpec(on)
            isSpectating = on
            local cam = workspace.CurrentCamera; if not cam then return end
            if on then
                specBtn.Text = "Spec◈"
                twP(specF,  0.15, {BackgroundColor3 = C.accent2 or C.accent, BackgroundTransparency = 0.75})
                twP(specS2, 0.15, {Transparency = 0.1})
                local char = pl.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = hum end
                end
            else
                specBtn.Text = "Spec"
                twP(specF,  0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.25})
                twP(specS2, 0.15, {Transparency = 0.6})
                local myChar = LocalPlayer.Character
                if myChar then
                    cam.CameraType    = Enum.CameraType.Custom
                    cam.CameraSubject = myChar:FindFirstChildOfClass("Humanoid")
                                     or myChar:FindFirstChild("HumanoidRootPart")
                end
            end
        end
        specBtn.MouseButton1Click:Connect(function() setSpec(not isSpectating) end)
        specBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then setSpec(not isSpectating) end
        end)

        -- panelColorHook für Spec-Stroke
        if not _panelColorHooks then _panelColorHooks = {} end
        _panelColorHooks[#_panelColorHooks+1] = function()
            pcall(function() if specS2 then specS2.Color = C.accent2 or C.accent end end)
        end
    end

    -- panelColorHook für ESP-Stroke
    if not _panelColorHooks then _panelColorHooks = {} end
    _panelColorHooks[#_panelColorHooks+1] = function()
        pcall(function() if espS  then espS.Color  = C.accent            end end)
        pcall(function() if ring  then ring.Color   = col                  end end)
    end

    card.MouseEnter:Connect(function()
        _playHoverSound()
        twP(card, 0.1, {BackgroundColor3 = C.bg3 or _C3_BG3})
    end)
    card.MouseLeave:Connect(function()
        twP(card, 0.1, {BackgroundColor3 = C.bg2 or _C3_BG2})
    end)

    rowCache[pl.UserId] = {row = card}
    return card
end

-- -- List rebuild -----------------------------------------------------------
local function rebuildList()
    local plrs     = Players:GetPlayers()
    local filter   = _plFilterText:lower()
    local activeIds = {}

    for _, pl in ipairs(plrs) do activeIds[pl.UserId] = true end
    for uid, entry in pairs(rowCache) do
        if not activeIds[uid] then entry.row:Destroy(); rowCache[uid] = nil end
    end

    -- Sort: Moderators first, then alphabetical
    local staffList = STAFF_BY_PLACE[game.PlaceId]
    table.sort(plrs, function(a, b)
        local aMod = staffList and staffList[a.Name] and true or false
        local bMod = staffList and staffList[b.Name] and true or false
        if aMod ~= bMod then return aMod end
        return a.Name < b.Name
    end)

    local visIdx = 0
    for _, pl in ipairs(plrs) do
        local show = filter == ""
            or pl.Name:lower():find(filter, 1, true)
            or pl.DisplayName:lower():find(filter, 1, true)

        local entry = rowCache[pl.UserId]
        if show then
            local yPos = HEADER_H + visIdx * (ROW_H_ACTUAL + GAP) + 4
            if entry then
                entry.row.Position = UDim2.new(0, PAD, 0, yPos)
                entry.row.Visible  = true
            else
                createRow(pl, yPos)
            end
            visIdx = visIdx + 1
        else
            if entry then entry.row.Visible = false end
        end
    end

    -- Update player count badge
    local total = #plrs
    if countLbl and countLbl.Parent then
        countLbl.Text = tostring(total)
    end

    local contentH = HEADER_H + visIdx * (ROW_H_ACTUAL + GAP) + 16
    c.CanvasSize = UDim2.new(0, 0, 0, math.max(ROW_H_ACTUAL, contentH))
    p.Size       = UDim2.new(0, PANEL_W, 0, math.min(contentH, 420))
end

-- Search filter
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    _plFilterText = searchBox.Text or ""
    rebuildList()
end)

-- -- Theme-Hook: aktualisiert alle Panel-Farben bei Farbwechsel ------------
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function()
    -- Panel-Hintergrund
    pcall(function() p.BackgroundColor3 = C.panelBg end)
    -- Count-Badge
    pcall(function() countBadge.BackgroundColor3 = C.accent end)
    pcall(function() countLbl.TextColor3         = C.accent end)
    -- Header-Linie
    pcall(function() hdrLine.BackgroundColor3 = C.bg3 or _C3_BG3 end)
    -- Suchfeld
    pcall(function() searchFrame.BackgroundColor3 = C.bg2 or _C3_BG2 end)
    pcall(function() searchStroke.Color           = C.bg3 or _C3_BG3 end)
    pcall(function() searchBox.TextColor3         = C.text end)
    pcall(function() searchBox.PlaceholderColor3  = C.sub  end)
    -- Player-Header (Panelkopf)
    for _, ch in ipairs(p:GetChildren()) do
        pcall(function()
            if ch:IsA("Frame") and ch.Size.Y.Offset == 48 then
                ch.BackgroundColor3 = C.panelHdr
            end
        end)
    end
    -- Alle Row-Cards neu einfärben
    for _, entry in pairs(rowCache) do
        pcall(function()
            local card = entry.row
            if card and card.Parent then
                card.BackgroundColor3 = C.bg2 or _C3_BG2
                local str = card:FindFirstChildOfClass("UIStroke")
                if str then str.Color = C.bg3 or _C3_BG3 end
                -- Avatar-Rahmen
                local avF = card:FindFirstChild("avF")
                if avF then avF.BackgroundColor3 = C.bg3 or _C3_BG3 end
                -- Name / Username Labels
                for _, lbl in ipairs(card:GetDescendants()) do
                    if lbl:IsA("TextLabel") then
                        local fs = lbl.TextSize
                        if fs >= 13 then
                            lbl.TextColor3 = C.text
                        else
                            lbl.TextColor3 = C.sub
                        end
                    end
                end
                -- Pill-Buttons neu einfärben (erkennung: Frame mit UICorner + TextButton)
                for _, pill in ipairs(card:GetDescendants()) do
                    if pill:IsA("Frame") and pill:FindFirstChildOfClass("UICorner") and pill:FindFirstChildOfClass("TextButton") then
                        local uc = pill:FindFirstChildOfClass("UICorner")
                        if uc and uc.CornerRadius.Scale >= 0.5 then  -- nur echte Pill-Formen
                            pcall(function() pill.BackgroundColor3 = C.accent end)
                            local tb2 = pill:FindFirstChildOfClass("TextButton")
                            if tb2 then tb2.TextColor3 = C.accent end
                        end
                    end
                end
            end
        end)
    end
end

rebuildList()
Players.PlayerAdded:Connect(function() task.wait(0.15); rebuildList() end)
Players.PlayerRemoving:Connect(function(pl)
    task.wait(0.15)
    local entry = rowCache[pl.UserId]
    if entry then entry.row:Destroy(); rowCache[pl.UserId] = nil end
    rebuildList()
end)
end)()
function makeKeybindWidget(parent, yPos, actionName, defaultKey, callback)
registerKeybind(actionName, defaultKey, callback)
local row = Instance.new("Frame", parent)
row.Size             = UDim2.new(1, 0, 0, 52)
row.Position         = UDim2.new(0, 0, 0, yPos)
row.BackgroundColor3 = C.bg2 or _C3_BG2
row.BackgroundTransparency = 0
row.BorderSizePixel  = 0
corner(row, 14)
local rowS = _makeDummyStroke(row); rowS.Thickness = 1; rowS.Color = C.bg3 or _C3_BG3; rowS.Transparency = 0.4
local rowD = Instance.new("Frame", row); rowD.Size = UDim2.new(0,4,0,28); rowD.Visible = false; rowD.Position = UDim2.new(0,0,0.5,-14)
rowD.BackgroundColor3 = C.accent or C.accent2; rowD.BackgroundTransparency = 0.3; rowD.BorderSizePixel = 0; corner(rowD, 99)
local lbl = Instance.new("TextLabel", row)
lbl.Size             = UDim2.new(0, 160, 1, 0)
lbl.Position         = UDim2.new(0, 16, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Text             = actionName
lbl.Font             = Enum.Font.GothamBold
lbl.TextSize = 14
lbl.TextColor3       = C.text
lbl.TextXAlignment   = Enum.TextXAlignment.Left
local descLbl = Instance.new("TextLabel", row)
descLbl.Size         = UDim2.new(0, 100, 1, 0)
descLbl.Position     = UDim2.new(0, 176, 0, 0)
descLbl.BackgroundTransparency = 1
descLbl.Text         = "Press to change"
descLbl.Font         = Enum.Font.Gotham
descLbl.TextSize     = 11
descLbl.TextColor3   = C.sub or _C3_SUB
descLbl.TextXAlignment = Enum.TextXAlignment.Left
local keyCard = Instance.new("Frame", row)
keyCard.Size         = UDim2.new(0, 90, 0, 36)
keyCard.Position     = UDim2.new(1, -100, 0.5, -18)
keyCard.BackgroundColor3 = C.bg3 or _C3_BG3
keyCard.BackgroundTransparency = 0.3
keyCard.BorderSizePixel = 0
corner(keyCard, 10)
local keyCardStroke = _makeDummyStroke(keyCard)
keyCardStroke.Thickness = 1.5; keyCardStroke.Color = C.accent2 or C.accent; keyCardStroke.Transparency = 0.7
local keyIcon = Instance.new("TextLabel", keyCard)
keyIcon.Size         = UDim2.new(0, 20, 0, 20)
keyIcon.Position     = UDim2.new(0, 6, 0.5, -10)
keyIcon.BackgroundTransparency = 1
keyIcon.Text         = ""
keyIcon.Font         = Enum.Font.GothamBold
keyIcon.TextSize     = 16
keyIcon.TextColor3   = C.accent2 or C.accent
keyIcon.TextXAlignment = Enum.TextXAlignment.Center
local function keyName(kc)
if kc == nil then return "None" end
local n = tostring(kc):gsub("Enum.KeyCode.", "")
return n
end
local kl = Instance.new("TextLabel", keyCard)
kl.Size              = UDim2.new(1, -26, 1, 0)
kl.Position          = UDim2.new(0, 26, 0, 0)
kl.BackgroundTransparency = 1
kl.Text              = keyName(defaultKey)
kl.Font              = Enum.Font.GothamBold
kl.TextSize          = 14
kl.TextColor3        = C.text
kl.TextXAlignment    = Enum.TextXAlignment.Center
keybindLabelUpdaters[actionName] = function(kc)
pcall(function() kl.Text = keyName(kc) end)
end
local keyBtn = Instance.new("TextButton", keyCard)
keyBtn.Size          = UDim2.new(1, 0, 1, 0)
keyBtn.BackgroundTransparency = 1
keyBtn.Text          = ""
keyBtn.ZIndex        = 6
local listening     = false
local listenConn    = nil
local pulseConn     = nil
local pulseState    = false
local function stopListening()
listening = false
if listenConn then listenConn:Disconnect(); listenConn = nil end
pulseConn = nil
twP(keyCard, 0.2, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.3})
twP(keyCardStroke, 0.2, {Color = C.accent2 or C.accent, Transparency = 0.7})
twP(kl, 0.2, {TextColor3 = C.text})
kl.Text = keyName(keybinds[actionName] and keybinds[actionName].key)
descLbl.Text = "Press to change"
descLbl.TextColor3 = C.sub or _C3_SUB
end
local function startListening()
if listening then stopListening(); return end
listening = true
kl.Text = "..."
kl.TextColor3 = C.accent
descLbl.Text = "Press any key"
descLbl.TextColor3 = C.accent
twP(keyCard, 0.2, {BackgroundColor3 = C.accent, BackgroundTransparency = 0.15})
twP(keyCardStroke, 0.2, {Color = C.accent, Transparency = 0.3})
pulseConn = task.spawn(function()
while listening and _tlAlive() do
pulseState = not pulseState
pcall(function()
keyCardStroke.Transparency = pulseState and 0.2 or 0.5
end)
task.wait(0.4)
end
end)
listenConn = UserInputService.InputBegan:Connect(function(input, gpe)
if input.KeyCode == Enum.KeyCode.Delete then
keybinds[actionName].key = nil
stopListening()
task.spawn(saveData)
return
end
if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
local newKey = input.KeyCode
keybinds[actionName].key = newKey
stopListening()
kl.Text = keyName(newKey)
task.spawn(saveData)
end)
end
keyBtn.MouseButton1Click:Connect(startListening)
keyBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then startListening() end
end)
keyBtn.MouseEnter:Connect(function()
_playHoverSound()
if not listening then
twP(keyCard, 0.15, {BackgroundColor3 = C.accent2 or C.accent, BackgroundTransparency = 0.2})
twP(keyCardStroke, 0.15, {Color = C.accent, Transparency = 0.4})
twP(kl, 0.15, {TextColor3 = C.accent})
descLbl.Text = "Click to bind"
descLbl.TextColor3 = C.accent
end
end)
keyBtn.MouseLeave:Connect(function()
if not listening then
twP(keyCard, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.3})
twP(keyCardStroke, 0.15, {Color = C.accent2 or C.accent, Transparency = 0.7})
twP(kl, 0.15, {TextColor3 = C.text})
descLbl.Text = "Press to change"
descLbl.TextColor3 = C.sub or _C3_SUB
end
end)
return row
end
function setupAutoReinject(enable)
pcall(function()
if enable and writefile then
local folderOk = true
pcall(function()
if isfolder and not isfolder("autorun") then
if makefolder then makefolder("autorun") end
end
folderOk = not isfolder or isfolder("autorun")
end)
if folderOk then
pcall(function()
writefile("autorun/SmartBar_Autorun.lua",
"task.wait(1.5)\nprint('[SmartBar] Auto-reinject active')\n")
end)
end
elseif not enable then
pcall(function()
if delfile then delfile("autorun/SmartBar_Autorun.lua") end
end)
end
end)
end
local _ok_Settings, _err_Settings = pcall(function()
local p, c = makePanel("Settings", C.sub)
-- -- Dynamische Panel-Höhe: passt sich dem Inhalt an --
local SET_HDR_H   = 58    -- Header-Offset (makePanel scroll startet bei y=54)
local SET_BASE_H  = SET_HDR_H + 80 + 16  -- Header + Grid (CARD_H_S=80) + Padding = 154px
local SET_MAX_H   = 420   -- Maximal-Höhe (scrollt danach)
p.Size = UDim2.new(0, PANEL_W, 0, SET_BASE_H)
c.Size                 = UDim2.new(1, -12, 1, -SET_HDR_H)
c.ScrollBarThickness   = 0   -- FIX: hide built-in scrollbar (was green and overlapped selected color chips)
c.ScrollingEnabled     = true
c.CanvasSize           = UDim2.new(0, 0, 0, 0)
-- Mobile: ScrollBar bleibt 0 (custom sbTrack übernimmt das)
do
    local _ok2, _vp2 = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    local _touch = pcall(function() return _SvcUIS.TouchEnabled end)
                   and _SvcUIS.TouchEnabled
    local _kb    = pcall(function() return _SvcUIS.KeyboardEnabled end)
                   and _SvcUIS.KeyboardEnabled
    -- intentionally left empty: built-in scrollbar is hidden, custom sbTrack handles visibility
    _ = _touch; _ = _kb
end
local CATS = {
    { id = "General",  icon = "⚙", img = "rbxassetid://117318347375651", col = Color3.fromRGB(160, 80, 255),  iconSize = 28 },
    { id = "Keybinds", icon = "⌨", img = "rbxassetid://77626648521931",  col = Color3.fromRGB(160, 80, 255), iconSize = 28 },
    { id = "Colors",   icon = "🎨", img = "rbxassetid://82124356614946",  col = Color3.fromRGB(160, 80, 255),  iconSize = 28 },
    { id = "Visual",   icon = "👁",  img = "rbxassetid://136959112324947", col = Color3.fromRGB(160, 80, 255), iconSize = 35 },
}
local CARD_GAP = 8
local CARD_W_S = math.floor((PANEL_W - 32 - CARD_GAP * (#CATS - 1)) / #CATS)
local CARD_H_S = 80
local catBtns  = {}
local subPages = {}
local activeCat = nil
local grid = Instance.new("Frame", c)
grid.Size             = UDim2.new(1, 0, 0, CARD_H_S)
grid.Position         = UDim2.new(0, 0, 0, 0)
grid.BackgroundTransparency = 1
grid.BorderSizePixel  = 0
local subArea = Instance.new("Frame", c)
subArea.Size             = UDim2.new(1, 0, 0, 0)
subArea.Position         = UDim2.new(0, 0, 0, CARD_H_S + 12)
subArea.BackgroundTransparency = 1
subArea.BorderSizePixel  = 0
subArea.ClipsDescendants = false
local function subRow(parent, yPos, label, badge, badgeCol, initOn, cb)
local row, setFn = cleanRow(parent, yPos, label, badge, badgeCol, initOn, cb)
return row, setFn
end
local settingToggleSetters = {}
local genPage
local _ok_genPage = pcall(function()
genPage = Instance.new("Frame", subArea)
genPage.BackgroundTransparency = 1; genPage.BorderSizePixel = 0
genPage.Visible = false
local _, notifSet = subRow(genPage,   0, T.settings_notif, T.settings_notif_badge,   C.accent,   settingsState.notifications, function(on)
settingsState.notifications = on
task.spawn(saveData)
end)
settingToggleSetters["notifications"] = notifSet
local _, autoSet = subRow(genPage,  54, T.settings_auto, T.settings_auto_badge,   C.accent2, settingsState.autoOpen,      function(on)
settingsState.autoOpen = on
setupAutoReinject(on)
task.spawn(saveData)
end)
settingToggleSetters["autoOpen"] = autoSet
local _, menuSoundsSet = subRow(genPage, 108, T.settings_menusounds, T.settings_menusounds_badge, C.accent, settingsState.menuSounds, function(on)
settingsState.menuSounds = on
task.spawn(saveData)
end)
settingToggleSetters["menuSounds"] = menuSoundsSet
_G.settingToggleSetters = settingToggleSetters
genPage.Size = UDim2.new(1, 0, 0, 162 + 8)
end) -- /_ok_genPage
local kbPage
local _ok_kbPage = pcall(function()
kbPage = Instance.new("Frame", subArea)
kbPage.BackgroundTransparency = 1; kbPage.BorderSizePixel = 0
kbPage.Visible = false
local kbHint = Instance.new("TextLabel", kbPage)
kbHint.Size = UDim2.new(1, -16, 0, 18)
kbHint.Position = UDim2.new(0, 8, 0, 4)
kbHint.BackgroundTransparency = 1
kbHint.Text = T.kb_hint
kbHint.Font = Enum.Font.Gotham
kbHint.TextSize = 11
kbHint.TextColor3 = C.sub or _C3_SUB
kbHint.TextXAlignment = Enum.TextXAlignment.Left
local kbContainer = Instance.new("Frame", kbPage)
kbContainer.Size = UDim2.new(1, 0, 0, 0)
kbContainer.Position = UDim2.new(0, 0, 0, 26)
kbContainer.BackgroundTransparency = 1
kbContainer.BorderSizePixel = 0
local keybindEntries = {
{ "Toggle SmartBar",  "fixed", "K" },
{ "Toggle Fly",       Enum.KeyCode.F,            function()
local newState = not flyActive
if _flyPanelSetFn then
    pcall(_flyPanelSetFn, newState)  -- ruft intern setFly + UI-Update auf
else
    flyActive = newState
    setFly(newState)
end
end },
{ "Toggle Noclip",    nil,                       function()
noclipActive = not noclipActive
setNoclip(noclipActive)
end },
{ "Toggle ESP",       nil,                       function()
local anyActive = next(espHighlights) ~= nil
if anyActive then setESP(false) else setESP(true) end
end },
{ "Toggle Invisible", nil,                       function()
invisActive = not invisActive
setInvis(invisActive)
end },
{ "Toggle Aimbot",    nil,                       function()
AimbotConfig.Enabled = not AimbotConfig.Enabled
if AimbotConfig.Enabled then
    StartAimbot()
    sendNotif("Aimbot", "Aimbot ACTIVATED - Hold RMB to aim", 3)
else
    StopAimbot()
    sendNotif("Aimbot", "Aimbot DEACTIVATED", 2)
end
end },
}
local totalKbRows = 0
for i, entry in ipairs(keybindEntries) do
local yPos = (i - 1) * 62
if entry[2] == "fixed" then
local row = Instance.new("Frame", kbContainer)
row.Size = UDim2.new(1, 0, 0, 52)
row.Position = UDim2.new(0, 0, 0, yPos)
row.BackgroundColor3 = C.bg2 or _C3_BG2
row.BackgroundTransparency = 0; row.BorderSizePixel = 0
corner(row, 14)
local rowStr = _makeDummyStroke(row)
rowStr.Thickness = 1; rowStr.Color = C.bg3 or _C3_BG3; rowStr.Transparency = 0.4
local rowDot = Instance.new("Frame", row)
rowDot.Size = UDim2.new(0,4,0,28); rowDot.Visible = false; rowDot.Position = UDim2.new(0,0,0.5,-14)
rowDot.BackgroundColor3 = C.accent or C.accent2; rowDot.BackgroundTransparency = 0.3
rowDot.BorderSizePixel = 0; corner(rowDot, 99)
local lbl = Instance.new("TextLabel", row)
lbl.Size = UDim2.new(0, 160, 1, 0)
lbl.Position = UDim2.new(0, 16, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Text = entry[1]
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 14
lbl.TextColor3 = C.text
lbl.TextXAlignment = Enum.TextXAlignment.Left
local descLbl = Instance.new("TextLabel", row)
descLbl.Size = UDim2.new(0, 100, 1, 0)
descLbl.Position = UDim2.new(0, 176, 0, 0)
descLbl.BackgroundTransparency = 1
descLbl.Text = "Cannot be changed"
descLbl.Font = Enum.Font.Gotham
descLbl.TextSize = 11
descLbl.TextColor3 = C.sub or _C3_SUB
descLbl.TextXAlignment = Enum.TextXAlignment.Left
local keyCard = Instance.new("Frame", row)
keyCard.Size = UDim2.new(0, 90, 0, 36)
keyCard.Position = UDim2.new(1, -100, 0.5, -18)
keyCard.BackgroundColor3 = C.bg3 or _C3_BG3
keyCard.BackgroundTransparency = 0.3
keyCard.BorderSizePixel = 0
corner(keyCard, 10)
local keyCardStroke = _makeDummyStroke(keyCard)
keyCardStroke.Thickness = 1.5; keyCardStroke.Color = C.accent2 or C.accent; keyCardStroke.Transparency = 0.7
local keyIcon = Instance.new("TextLabel", keyCard)
keyIcon.Size = UDim2.new(0, 20, 0, 20)
keyIcon.Position = UDim2.new(0, 6, 0.5, -10)
keyIcon.BackgroundTransparency = 1
keyIcon.Text = "🔑"
keyIcon.Font = Enum.Font.GothamBold
keyIcon.TextSize = 16
keyIcon.TextColor3 = C.accent2 or C.accent
keyIcon.TextXAlignment = Enum.TextXAlignment.Center
local kl = Instance.new("TextLabel", keyCard)
kl.Size = UDim2.new(1, -26, 1, 0)
kl.Position = UDim2.new(0, 26, 0, 0)
kl.BackgroundTransparency = 1
kl.Text = entry[3]
kl.Font = Enum.Font.GothamBold
kl.TextSize = 14
kl.TextColor3 = C.text
kl.TextXAlignment = Enum.TextXAlignment.Center
else
makeKeybindWidget(kbContainer, yPos, entry[1], entry[2], entry[3])
end
totalKbRows = totalKbRows + 1
end
kbContainer.Size = UDim2.new(1, 0, 0, totalKbRows * 62)
kbPage.Size = UDim2.new(1, 0, 0, 26 + totalKbRows * 62 + 8)
end) -- /_ok_kbPage

-- -- Colors sub-page --------------------------------------
local colorsPage
local _ok_colorsPage = pcall(function()
colorsPage = Instance.new("Frame", subArea)
colorsPage.BackgroundTransparency = 1; colorsPage.BorderSizePixel = 0
colorsPage.Visible = false
do
    local cpY = 0
    local cpLbl = Instance.new("TextLabel", colorsPage)
    cpLbl.Size = UDim2.new(1,-16,0,18); cpLbl.Position = UDim2.new(0,8,0,cpY)
    cpLbl.BackgroundTransparency = 1; cpLbl.Text = "GUI Farbthema"
    cpLbl.Font = Enum.Font.GothamBold; cpLbl.TextSize = 12
    cpLbl.TextColor3 = C.sub; cpLbl.TextXAlignment = Enum.TextXAlignment.Left
    cpY = cpY + 26
    local CHIP_W = math.floor((PANEL_W - 48) / 3)
    local CHIP_H = 52
    local CHIP_GAP = 8
    local _themeChipBtns = {}
    -- -- Chip-Farben: Hardcodiert, nicht vom Theme remapping betroffen --
    local CHIP_BG_INACTIVE = Color3.fromRGB(20, 20, 20)  -- neutral grau
    local CHIP_BG_ACTIVE   = Color3.fromRGB(28, 28, 28)  -- etwas heller
    local function updateThemeChips(activeId)
        for _, ch in ipairs(_themeChipBtns) do
            local isActive = (ch.id == activeId)
            ch.card.BackgroundColor3 = isActive and CHIP_BG_ACTIVE or CHIP_BG_INACTIVE
            ch.card.BackgroundTransparency = isActive and 0.2 or 0.0
            ch.str.Transparency = isActive and 0.3 or 0.6
            ch.str.Color = isActive and (ch.col or C.accent) or C.bg3
            -- FIX: Dot und Label immer auf die theme-eigene Farbe zurücksetzen,
            -- damit _TL_applyTheme-Recolor sie nicht dauerhaft überschreibt
            if ch.dot then ch.dot.BackgroundColor3 = ch.col end
            if ch.tlbl then ch.tlbl.TextColor3 = ch.col end
        end
    end
    for i, theme in ipairs(_TL_THEMES) do
        local col = i - 1
        local row = math.floor(col / 3)
        local c2  = col % 3
        local cx  = 16 + c2 * (CHIP_W + CHIP_GAP)
        local cy  = cpY + row * (CHIP_H + CHIP_GAP)
        local card = Instance.new("Frame", colorsPage)
        card.Size = UDim2.new(0, CHIP_W, 0, CHIP_H)
        card.Position = UDim2.new(0, cx, 0, cy)
        card.BackgroundColor3 = CHIP_BG_INACTIVE; card.BackgroundTransparency = 0
        card.BorderSizePixel = 0; corner(card, 10)
        local cStr2 = _makeDummyStroke(card)
        cStr2.Thickness = 1.5; cStr2.Color = theme.accent; cStr2.Transparency = 0.6
        cStr2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        -- colour swatch dot
        local dot = Instance.new("Frame", card)
        dot.Size = UDim2.new(0,16,0,16); dot.Position = UDim2.new(0.5,-8,0,8)
        dot.BackgroundColor3 = theme.accent; dot.BackgroundTransparency = 0
        dot.BorderSizePixel = 0; corner(dot, 99)
        local tlbl = Instance.new("TextLabel", card)
        tlbl.Size = UDim2.new(1,-4,0,14); tlbl.Position = UDim2.new(0,2,1,-18)
        tlbl.BackgroundTransparency = 1; tlbl.Text = theme.name:upper()
        tlbl.Font = Enum.Font.GothamBold; tlbl.TextSize = 9
        tlbl.TextColor3 = theme.accent; tlbl.TextXAlignment = Enum.TextXAlignment.Center
        local themeBtn = Instance.new("TextButton", card)
        themeBtn.Size = UDim2.new(1,0,1,0); themeBtn.BackgroundTransparency = 1
        themeBtn.Text = ""; themeBtn.ZIndex = 8
        local captId = theme.id
        local captCol = theme.accent
        themeBtn.MouseButton1Click:Connect(function()
            _TL_applyTheme(captId)
            task.defer(function()
                updateThemeChips(captId)
            end)
        end)
        themeBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                _TL_applyTheme(captId)
                task.defer(function()
                    updateThemeChips(captId)
                end)
            end
        end)
        themeBtn.MouseEnter:Connect(function()
_playHoverSound()
            twP(card, 0.1, {BackgroundColor3 = CHIP_BG_ACTIVE})
        end)
        themeBtn.MouseLeave:Connect(function()
            if _TL_activeThemeId ~= captId then
                twP(card, 0.1, {BackgroundColor3 = CHIP_BG_INACTIVE})
            end
        end)
        table.insert(_themeChipBtns, { id=theme.id, card=card, str=cStr2, col=theme.accent, dot=dot, tlbl=tlbl })
    end
    local rows = math.ceil(#_TL_THEMES / 3)
    cpY = cpY + rows * (CHIP_H + CHIP_GAP) + 8
    colorsPage.Size = UDim2.new(1, 0, 0, cpY)
    updateThemeChips(_TL_activeThemeId)
    -- re-apply chips after theme load
    task.defer(function()
        pcall(function() updateThemeChips(_TL_activeThemeId) end)
    end)
    
    -- -- Callback registrieren: Nach jedem Theme-Switch Chips korrigieren --
    local env = getgenv and getgenv() or _G
    pcall(function()
        env._TL_FixThemeChips = function(themeId)
            task.defer(function()
                pcall(function() updateThemeChips(themeId or _TL_activeThemeId) end)
            end)
        end
    end)
end
end) -- /_ok_colorsPage

-- -- Visual sub-page -------------------------------------------
local _VCOL = C.accent  -- Visual-Akzent: folgt aktuellem Theme
local visualSettingsPage
local _ok_visualPage = pcall(function()
visualSettingsPage = Instance.new("Frame", subArea)
visualSettingsPage.BackgroundTransparency = 1; visualSettingsPage.BorderSizePixel = 0
visualSettingsPage.Visible = false

-- ----------------------------------------------------------------
-- NEW CURSOR SYSTEM (customcursor.lua integriert)
-- ----------------------------------------------------------------
local CURSOR_IMAGE   = "rbxassetid://72906199197416"
local CURSOR_SIZE    = 32
local CURSOR_HOTSPOT = Vector2.new(3, 2)
local FX_ORDER_CUR   = 1000100

local fxEnabled        = false
local fxColor          = C.accent  -- live: refreshed via _panelColorHooks
local fxEffect         = "smoke"
local fxSize           = 6
local fxParticleAmount = 1.00
local fxSmoothness     = 0.70
local fxSpeed          = 1.00
local cursorTheme      = "minimal"
local fxGui            = nil
local fxRoot           = nil
local fxParticles      = {}
local fxConn           = nil
local fxInputConn      = nil
local cursorSyncConn   = nil
local textFocusedConn  = nil
local textReleasedConn = nil
local cursorGui_       = nil
local cursorImage_     = nil
local cursorShadow_    = nil
local cursorScale_     = 1
local cursorShadowScale_ = 1.12
local lastMousePos_    = Vector2.new(0,0)
local mouseVel_        = Vector2.new(0,0)
local spawnAccum_      = 0
local cachedUseOrig_   = false
local lastCheckPos_    = Vector2.new(-9999,-9999)
local lastCheckTime_   = 0

local EFFECT_ORDER = {"none","smoke","trail","rainbow","spark","burst","pulse","orbit","wave","spiral","fire","snow","glitch","neon"}
local THEME_ORDER  = {"default","minimal","vector","glass","neon","dark","light","cyber","pastel","gold","ghost"}

local function _curCleanupGlobals()
    for _, k in ipairs({"_TLNativeCursorFxGui","_TLNativeCursorFxSettings","_TLNativeCursorFxConn",
        "_TLNativeCursorFxInputConn","_TLNativeCursorFxToggleConn","_TLNativeCursorFxCursorConn",
        "_TLNativeCursorFxTextFocusedConn","_TLNativeCursorFxTextReleasedConn","_TLNativeCursorVisualGui"}) do
        if _G[k] then pcall(function() if _G[k].Disconnect then _G[k]:Disconnect() elseif _G[k].Destroy then _G[k]:Destroy() end end) end
        _G[k] = nil
    end
end
_curCleanupGlobals()

local UIS2 = _SvcUIS
local RS2  = _SvcRS
local GS2  = game:GetService("GuiService")
local Mouse_ = LocalPlayer and LocalPlayer:GetMouse()

local function _isTextInput(obj)
    while obj do if obj:IsA("TextBox") then return true end; obj = obj.Parent end
    return false
end

local function _shouldUseOrig(mp)
    if UIS2:GetFocusedTextBox() then return true end
    local ok, obs = pcall(function() return GS2:GetGuiObjectsAtPosition(mp.X, mp.Y) end)
    if ok and obs then for _, o in ipairs(obs) do if _isTextInput(o) then return true end end end
    return false
end

local applyCursorTheme_
applyCursorTheme_ = function()
    if not cursorImage_ or not cursorShadow_ then return end
    local styles = {
        default={scale=1.00,shadowScale=1.08,shadowTransparency=0.80,shadowColor=Color3.fromRGB(0,0,0)},
        minimal={scale=0.92,shadowScale=1.00,shadowTransparency=1.00,shadowColor=Color3.fromRGB(0,0,0)},
        vector ={scale=1.00,shadowScale=1.04,shadowTransparency=0.84,shadowColor=fxColor:Lerp(Color3.new(1,1,1),0.35)},
        glass  ={scale=1.03,shadowScale=1.14,imageTransparency=0.20,shadowTransparency=0.82,shadowColor=Color3.fromRGB(220,240,255)},
        neon   ={scale=1.05,shadowScale=1.24,shadowTransparency=0.48,shadowColor=fxColor},
        dark   ={scale=1.00,shadowScale=1.12,shadowTransparency=0.68,shadowColor=Color3.fromRGB(0,0,0),mode="dark"},
        light  ={scale=1.00,shadowScale=1.10,shadowTransparency=0.78,shadowColor=Color3.fromRGB(255,255,255),mode="light"},
        cyber  ={scale=1.08,shadowScale=1.25,shadowTransparency=0.55,shadowColor=Color3.fromRGB(0,255,230)},
        pastel ={scale=0.98,shadowScale=1.12,shadowTransparency=0.72,shadowColor=fxColor:Lerp(Color3.new(1,1,1),0.55)},
        gold   ={scale=1.04,shadowScale=1.18,shadowTransparency=0.60,shadowColor=Color3.fromRGB(255,205,80),tintColor=Color3.fromRGB(255,235,160)},
        ghost  ={scale=1.06,shadowScale=1.22,imageTransparency=0.28,shadowTransparency=0.84,shadowColor=Color3.fromRGB(210,240,255)},
    }
    local s=styles[cursorTheme] or styles.minimal
    cursorScale_=s.scale or 1; cursorShadowScale_=s.shadowScale or cursorScale_
    local tint=fxColor
    if s.mode=="dark" then tint=fxColor:Lerp(Color3.fromRGB(28,28,36),0.45)
    elseif s.mode=="light" then tint=fxColor:Lerp(Color3.fromRGB(255,255,255),0.35)
    elseif s.tintColor then tint=s.tintColor:Lerp(fxColor,0.45) end
    local sz=math.floor(CURSOR_SIZE*cursorScale_+0.5); local szSh=math.floor(CURSOR_SIZE*cursorShadowScale_+0.5)
    cursorImage_.Size=UDim2.fromOffset(sz,sz); cursorImage_.Image=CURSOR_IMAGE
    cursorImage_.ImageColor3=tint; cursorImage_.ImageTransparency=s.imageTransparency or 0
    cursorShadow_.Size=UDim2.fromOffset(szSh,szSh); cursorShadow_.Image=CURSOR_IMAGE
    cursorShadow_.ImageColor3=s.shadowColor or fxColor; cursorShadow_.ImageTransparency=s.shadowTransparency or 0.75
end

local function _destroyCursorGui()
    if cursorGui_ then pcall(function() cursorGui_:Destroy() end); cursorGui_=nil end
    cursorImage_=nil; cursorShadow_=nil
    _G._TLNativeCursorVisualGui=nil
end

local function _ensureCursorGui()
    if cursorGui_ and cursorGui_.Parent and cursorImage_ and cursorShadow_ then return end
    if cursorGui_ then pcall(function() cursorGui_:Destroy() end) end
    cursorGui_=Instance.new("ScreenGui"); cursorGui_.Name="TLNativeCursorVisual"; cursorGui_.ResetOnSpawn=false
    cursorGui_.IgnoreGuiInset=true; cursorGui_.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; cursorGui_.DisplayOrder=FX_ORDER_CUR+20
    _tryParentGui(cursorGui_); _G._TLNativeCursorVisualGui=cursorGui_
    cursorShadow_=Instance.new("ImageLabel"); cursorShadow_.Name="CursorShadow"
    cursorShadow_.Size=UDim2.fromOffset(CURSOR_SIZE,CURSOR_SIZE); cursorShadow_.BackgroundTransparency=1
    cursorShadow_.BorderSizePixel=0; cursorShadow_.Image=CURSOR_IMAGE; cursorShadow_.Visible=false; cursorShadow_.ZIndex=998; cursorShadow_.Parent=cursorGui_
    cursorImage_=Instance.new("ImageLabel"); cursorImage_.Name="CursorImage"
    cursorImage_.Size=UDim2.fromOffset(CURSOR_SIZE,CURSOR_SIZE); cursorImage_.BackgroundTransparency=1
    cursorImage_.BorderSizePixel=0; cursorImage_.Image=CURSOR_IMAGE; cursorImage_.ImageColor3=fxColor
    cursorImage_.Visible=false; cursorImage_.ZIndex=999; cursorImage_.Parent=cursorGui_
    applyCursorTheme_()
end

local function _setCursorVisual(mp, visible)
    _ensureCursorGui(); if not cursorImage_ then return end
    if mp then
        cursorImage_.Position=UDim2.fromOffset(math.floor(mp.X-(CURSOR_HOTSPOT.X*cursorScale_)+0.5),math.floor(mp.Y-(CURSOR_HOTSPOT.Y*cursorScale_)+0.5))
        if cursorShadow_ then cursorShadow_.Position=UDim2.fromOffset(math.floor(mp.X-(CURSOR_HOTSPOT.X*cursorShadowScale_)+0.5),math.floor(mp.Y-(CURSOR_HOTSPOT.Y*cursorShadowScale_)+0.5)) end
    end
    cursorImage_.Visible=visible==true
    if cursorShadow_ then cursorShadow_.Visible=visible==true and (cursorShadow_.ImageTransparency<0.98) end
end

local function _setNativeCursorVisible(visible)
    local mp; pcall(function() mp=UIS2:GetMouseLocation() end)
    local now=tick()
    if mp and (((mp-lastCheckPos_).Magnitude>0.5) or ((now-lastCheckTime_)>0.08)) then
        cachedUseOrig_=visible and _shouldUseOrig(mp); lastCheckTime_=now; lastCheckPos_=mp
    elseif not visible then cachedUseOrig_=false end
    local useOrig=visible and cachedUseOrig_
    pcall(function() UIS2.MouseIconEnabled=useOrig end)
    if Mouse_ then pcall(function() Mouse_.Icon="" end) end
    if visible and not useOrig then _setCursorVisual(mp,true) else _setCursorVisual(mp,false) end
end

local function _startCursorSync()
    _ensureCursorGui()
    if not textFocusedConn then
        textFocusedConn=UIS2.TextBoxFocused:Connect(function()
            pcall(function() UIS2.MouseIconEnabled=true end)
            if Mouse_ then pcall(function() Mouse_.Icon="" end) end
            _setCursorVisual(nil,false)
        end); _G._TLNativeCursorFxTextFocusedConn=textFocusedConn
    end
    if not textReleasedConn then
        textReleasedConn=UIS2.TextBoxFocusReleased:Connect(function() _setNativeCursorVisible(true) end)
        _G._TLNativeCursorFxTextReleasedConn=textReleasedConn
    end
    if cursorSyncConn then return end
    cursorSyncConn=RS2.RenderStepped:Connect(function() _setNativeCursorVisible(true) end)
    _G._TLNativeCursorFxCursorConn=cursorSyncConn
end

local function _buildFxGui()
    if fxGui then return end
    fxParticles={}
    fxGui=Instance.new("ScreenGui"); fxGui.Name="TLNativeCursorFX"; fxGui.ResetOnSpawn=false
    fxGui.IgnoreGuiInset=true; fxGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; fxGui.DisplayOrder=FX_ORDER_CUR
    _tryParentGui(fxGui); _G._TLNativeCursorFxGui=fxGui
    fxRoot=Instance.new("Frame"); fxRoot.Name="FxRoot"; fxRoot.Size=UDim2.new(1,0,1,0)
    fxRoot.BackgroundTransparency=1; fxRoot.BorderSizePixel=0; fxRoot.Parent=fxGui
    for i=1,28 do
        local dot=Instance.new("Frame"); dot.Name="P"..i; dot.Size=UDim2.new(0,fxSize,0,fxSize)
        dot.AnchorPoint=Vector2.new(0.5,0.5); dot.BackgroundColor3=fxColor; dot.BackgroundTransparency=0.3
        dot.BorderSizePixel=0; dot.Visible=false; dot.ZIndex=20; dot.Parent=fxRoot; corner(dot,999)
        local g=Instance.new("UIGradient"); g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)}); g.Parent=dot
        fxParticles[i]={frame=dot,life=0,maxLife=0.35+i*0.03,x=0,y=0,dx=0,dy=0,size=fxSize,angle=0,spin=0,radius=0,seed=math.random()*math.pi*2}
    end
end

local function _destroyFxGui()
    if fxGui then pcall(function() fxGui:Destroy() end); fxGui=nil; fxRoot=nil; fxParticles={} end
    if fxConn then pcall(function() fxConn:Disconnect() end); fxConn=nil end
    if fxInputConn then pcall(function() fxInputConn:Disconnect() end); fxInputConn=nil end
    _G._TLNativeCursorFxConn=nil; _G._TLNativeCursorFxInputConn=nil
end

local function _updateFxBurst(mx,my,dt)
    if fxEffect=="none" or fxEffect=="rainbow" or fxEffect=="orbit" or fxEffect=="pulse" then return end
    local pf=math.clamp(fxParticleAmount,0.35,2.50); local sf=math.clamp(fxSpeed,0.40,1.80)
    local speed=mouseVel_.Magnitude; local spawnRate,spread,baseAngle,speedMin,speedMax,lifeBase=0.02,0.8,math.random()*math.pi*2,8,20,0.35
    local ac=0; for _,p in ipairs(fxParticles) do if p.life>0 then ac=ac+1 end end
    local cap=math.max(4,math.floor(#fxParticles*math.clamp(0.18+pf*0.32,0.18,1))); if ac>=cap then return end
    if fxEffect=="trail" then spawnRate=math.max(0.008,0.024-speed*0.00003);spread=0.18;baseAngle=math.atan2(-mouseVel_.Y,-mouseVel_.X);speedMin,speedMax,lifeBase=10,20,0.32
    elseif fxEffect=="spark" then spawnRate=0.008;spread=0.45;speedMin,speedMax,lifeBase=20,38,0.20
    elseif fxEffect=="burst" then spawnRate=0.012;spread=math.pi*2;speedMin,speedMax,lifeBase=18,32,0.25
    elseif fxEffect=="wave" then spawnRate=0.010;spread=0.35;baseAngle=tick()*6;speedMin,speedMax,lifeBase=10,18,0.45
    elseif fxEffect=="spiral" then spawnRate=0.010;spread=0.25;baseAngle=tick()*7;speedMin,speedMax,lifeBase=8,14,0.55
    elseif fxEffect=="fire" then spawnRate=0.009;spread=0.60;baseAngle=-math.pi/2;speedMin,speedMax,lifeBase=8,20,0.35
    elseif fxEffect=="snow" then spawnRate=0.018;spread=0.25;baseAngle=math.pi/2;speedMin,speedMax,lifeBase=2,6,0.70
    elseif fxEffect=="glitch" then spawnRate=0.010;spread=math.pi*2;speedMin,speedMax,lifeBase=1,6,0.16
    elseif fxEffect=="neon" then spawnRate=0.008;spread=0.10;baseAngle=math.atan2(-mouseVel_.Y,-mouseVel_.X);speedMin,speedMax,lifeBase=6,12,0.28
    else spawnRate=math.max(0.012,0.040-speed*0.00004);spread=1.00;speedMin,speedMax,lifeBase=8,16,0.45 end
    spawnRate=spawnRate/pf; speedMin=speedMin*sf; speedMax=speedMax*sf
    spawnAccum_=spawnAccum_+(dt or 0.016); if spawnAccum_<spawnRate then return end; spawnAccum_=0
    for i,p in ipairs(fxParticles) do
        if p.life<=0 then
            local angle=baseAngle+(math.random()-0.5)*spread; local mag=speedMin+math.random()*(speedMax-speedMin)
            p.maxLife=lifeBase+(i%3)*0.03; p.life=p.maxLife; p.x=mx; p.y=my; p.dx=math.cos(angle)*mag; p.dy=math.sin(angle)*mag
            p.size=math.max(2,fxSize-2+math.random()*5); p.angle=angle; p.spin=(math.random()-0.5)*8; p.radius=4+math.random()*12; p.seed=math.random()*math.pi*2
            p.frame.Visible=true
            if fxEffect=="fire" then p.frame.BackgroundColor3=Color3.fromRGB(255,170+math.random(0,60),40)
            elseif fxEffect=="snow" then p.frame.BackgroundColor3=Color3.fromRGB(230,245,255)
            elseif fxEffect=="glitch" then p.frame.BackgroundColor3=(i%2==0) and Color3.fromRGB(255,0,170) or Color3.fromRGB(0,255,255)
            elseif fxEffect=="neon" then p.frame.BackgroundColor3=Color3.fromHSV((tick()*0.6+i/#fxParticles)%1,1,1)
            else p.frame.BackgroundColor3=fxColor end
            break
        end
    end
end

local function _startFxLoop()
    if fxConn then return end
    fxInputConn=UIS2.InputChanged:Connect(function(inp)
        if inp.UserInputType~=Enum.UserInputType.MouseMovement then return end
        lastMousePos_=Vector2.new(inp.Position.X,inp.Position.Y)
    end); _G._TLNativeCursorFxInputConn=fxInputConn
    fxConn=RS2.RenderStepped:Connect(function(dt)
        local pos; pcall(function() pos=UIS2:GetMouseLocation() end); if not pos then return end
        local cur=Vector2.new(pos.X,pos.Y)
        local alpha=math.clamp(1-fxSmoothness,0.05,0.65)
        local vx=(cur.X-lastMousePos_.X)/math.max(dt,0.001); local vy=(cur.Y-lastMousePos_.Y)/math.max(dt,0.001)
        mouseVel_=mouseVel_*(1-alpha)+Vector2.new(vx,vy)*alpha; lastMousePos_=cur
        _updateFxBurst(cur.X,cur.Y,dt)
        local hue=(tick()*0.25)%1; local animDt=dt*math.clamp(fxSpeed,0.40,1.80)
        for i,p in ipairs(fxParticles) do
            if p.life>0 then
                p.life=p.life-animDt
                local t=1-math.max(0,p.life/math.max(p.maxLife,0.001))
                local px=p.x+p.dx*t; local py=p.y+p.dy*t; local sz_=p.size*(0.65+t*0.75); local col=fxColor
                if fxEffect=="smoke" then px=p.x+p.dx*t*0.7;py=p.y+p.dy*t*0.7-t*4;sz_=p.size*(0.9+t);col=fxColor:Lerp(Color3.fromRGB(170,170,170),0.35)
                elseif fxEffect=="spark" then sz_=math.max(2,p.size*(1-t*0.35));col=fxColor:Lerp(Color3.new(1,1,1),0.35)
                elseif fxEffect=="burst" then sz_=p.size*(0.8+t*0.45);col=Color3.fromHSV((hue+t*0.2)%1,0.9,1)
                elseif fxEffect=="wave" then px=p.x+math.cos(p.seed+t*8)*(6+t*18);py=p.y+math.sin(p.seed*0.5+t*10)*10;sz_=p.size*(0.9+0.5*t);col=Color3.fromHSV((hue+i/#fxParticles*0.05)%1,0.8,1)
                elseif fxEffect=="spiral" then local ang=p.angle+t*10+p.spin*0.2;local rad=p.radius+t*16;px=p.x+math.cos(ang)*rad;py=p.y+math.sin(ang)*rad;sz_=p.size*(0.85+0.3*t);col=Color3.fromHSV((hue+t*0.15)%1,1,1)
                elseif fxEffect=="fire" then px=p.x+math.sin(p.seed+t*9)*4;py=p.y-t*(20+p.radius);sz_=p.size*(1-t*0.4);col=Color3.fromRGB(255,math.floor(150+70*(1-t)),40)
                elseif fxEffect=="snow" then px=p.x+math.sin(p.seed+t*6)*8;py=p.y+t*(12+p.radius);sz_=p.size*(0.9+0.2*math.sin(t*math.pi));col=Color3.fromRGB(230,245,255)
                elseif fxEffect=="glitch" then px=cur.X+math.random(-8,8);py=cur.Y+math.random(-8,8);sz_=math.max(2,p.size+math.random(-1,2));col=(i%2==0) and Color3.fromRGB(255,0,170) or Color3.fromRGB(0,255,255)
                elseif fxEffect=="neon" then px=p.x+p.dx*t*0.8;py=p.y+p.dy*t*0.8;sz_=p.size*(1+t*0.35);col=Color3.fromHSV((hue+i/#fxParticles*0.08)%1,1,1)
                elseif fxEffect=="trail" then sz_=p.size*(0.65+t*0.55) end
                p.frame.Position=UDim2.new(0,px,0,py); p.frame.Size=UDim2.new(0,sz_,0,sz_)
                p.frame.BackgroundColor3=col; p.frame.BackgroundTransparency=math.clamp(t*1.05,0.10,1); p.frame.Visible=true
                if p.life<=0 then p.life=0; p.frame.Visible=false end
            elseif fxEffect=="rainbow" then
                local ang=((i-1)/#fxParticles)*math.pi*2+tick()*2.5; local rad=7+math.sin(tick()*3+i)*3
                p.frame.Position=UDim2.new(0,cur.X+math.cos(ang)*rad,0,cur.Y+math.sin(ang)*rad)
                p.frame.Size=UDim2.new(0,math.max(2,fxSize+1),0,math.max(2,fxSize+1))
                p.frame.BackgroundColor3=Color3.fromHSV((hue+i/#fxParticles)%1,1,1); p.frame.BackgroundTransparency=0.15; p.frame.Visible=true
            elseif fxEffect=="orbit" then
                local ang=((i-1)/#fxParticles)*math.pi*2+tick()*(1.8+(i%3)*0.2); local rad=10+(i%3)*4
                p.frame.Position=UDim2.new(0,cur.X+math.cos(ang)*rad,0,cur.Y+math.sin(ang)*rad)
                p.frame.Size=UDim2.new(0,math.max(2,fxSize),0,math.max(2,fxSize))
                p.frame.BackgroundColor3=fxColor:Lerp(Color3.new(1,1,1),0.2); p.frame.BackgroundTransparency=0.22; p.frame.Visible=true
            elseif fxEffect=="pulse" then
                local pulse=(tick()*2.6+(i/#fxParticles))%1; local ang=((i-1)/#fxParticles)*math.pi*2
                local rad=2+pulse*16; local psz=math.max(2,fxSize+(1-pulse)*4)
                p.frame.Position=UDim2.new(0,cur.X+math.cos(ang)*rad,0,cur.Y+math.sin(ang)*rad)
                p.frame.Size=UDim2.new(0,psz,0,psz); p.frame.BackgroundColor3=fxColor:Lerp(Color3.new(1,1,1),0.3)
                p.frame.BackgroundTransparency=math.clamp(0.15+pulse*0.75,0.15,0.95); p.frame.Visible=true
            else p.frame.Visible=false end
        end
    end); _G._TLNativeCursorFxConn=fxConn
end

local function _setFxEnabled(enabled)
    fxEnabled=enabled
    if enabled then
        _startCursorSync()       -- Custom Cursor erst beim Einschalten aktivieren
        _setNativeCursorVisible(true)
        _buildFxGui()
        _startFxLoop()
    else
        -- Custom Cursor ausschalten: Roblox Standard-Cursor wiederherstellen
        if cursorSyncConn then
            pcall(function() cursorSyncConn:Disconnect() end)
            cursorSyncConn = nil
            _G._TLNativeCursorFxCursorConn = nil
        end
        if textFocusedConn then
            pcall(function() textFocusedConn:Disconnect() end)
            textFocusedConn = nil
            _G._TLNativeCursorFxTextFocusedConn = nil
        end
        if textReleasedConn then
            pcall(function() textReleasedConn:Disconnect() end)
            textReleasedConn = nil
            _G._TLNativeCursorFxTextReleasedConn = nil
        end
        _destroyFxGui()
        _destroyCursorGui()
        _setCursorVisual(nil, false)
        -- Standard Roblox Cursor zurück
        pcall(function() UIS2.MouseIconEnabled = true end)
        if Mouse_ then pcall(function() Mouse_.Icon = "" end) end
    end
end
-- _startCursorSync() wird NICHT beim Laden aufgerufen – erst wenn Toggle ON
-- Theme-Hook: fxColor + Cursor-Bild live auf neues Theme-Accent updaten
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function()
    fxColor = C.accent
    applyCursorTheme_()
end

-- -- Panel UI --------------------------------------------------
local _vpY  = 0
local _vpPAD = 8

local function _makeVslider(label, sublabel, vMin, vMax, vDef, col, onSlide)
    local CARD_H_V=64
    local card=Instance.new("Frame",visualSettingsPage); card.Size=UDim2.new(1,0,0,CARD_H_V); card.Position=UDim2.new(0,0,0,_vpY); card.BackgroundColor3=C.bg2; card.BackgroundTransparency=0; card.BorderSizePixel=0; corner(card,12)
    local cStr=_makeDummyStroke(card); cStr.Thickness=1; cStr.Color=C.bg3; cStr.Transparency=0.3
    local cdot=Instance.new("Frame",card); cdot.Size=UDim2.new(0,3,0,CARD_H_V-20); cdot.Visible = false; cdot.Position=UDim2.new(0,0,0.5,-(CARD_H_V-20)/2); cdot.BackgroundColor3=col; cdot.BackgroundTransparency=0.4; cdot.BorderSizePixel=0; corner(cdot,99)
    local nameLbl=Instance.new("TextLabel",card); nameLbl.Size=UDim2.new(0,140,0,18); nameLbl.Position=UDim2.new(0,14,0,8); nameLbl.BackgroundTransparency=1; nameLbl.Text=label; nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=13; nameLbl.TextColor3=C.text; nameLbl.TextXAlignment=Enum.TextXAlignment.Left
    local subLbl=Instance.new("TextLabel",card); subLbl.Size=UDim2.new(0,140,0,13); subLbl.Position=UDim2.new(0,14,0,26); subLbl.BackgroundTransparency=1; subLbl.Text=sublabel; subLbl.Font=Enum.Font.GothamBold; subLbl.TextSize=9; subLbl.TextColor3=C.sub; subLbl.TextXAlignment=Enum.TextXAlignment.Left
    local valLbl=Instance.new("TextLabel",card); valLbl.Size=UDim2.new(0,52,0,18); valLbl.Position=UDim2.new(1,-64,0,8); valLbl.BackgroundTransparency=1; valLbl.Font=Enum.Font.GothamBlack; valLbl.TextSize=13; valLbl.TextColor3=col; valLbl.TextXAlignment=Enum.TextXAlignment.Right
    local track=Instance.new("Frame",card); track.Size=UDim2.new(1,-28,0,4); track.Position=UDim2.new(0,14,1,-14); track.BackgroundColor3=C.bg3; track.BackgroundTransparency=0.2; track.BorderSizePixel=0; corner(track,99)
    local fill=Instance.new("Frame",track); fill.BackgroundColor3=col; fill.BackgroundTransparency=0; fill.BorderSizePixel=0; corner(fill,99)
    local knob=Instance.new("Frame",track); knob.Size=UDim2.new(0,12,0,12); knob.BackgroundColor3=_C3_WHITE; knob.BackgroundTransparency=0; knob.BorderSizePixel=0; knob.ZIndex=5; corner(knob,99)
    local kStr=_makeDummyStroke(knob); kStr.Thickness=1.5; kStr.Color=col; kStr.Transparency=0
    local function applyRatio(r)
        r=math.clamp(r,0,1); local v=vMin+r*(vMax-vMin)
        fill.Size=UDim2.new(r,0,1,0); knob.Position=UDim2.new(r,-6,0.5,-6)
        onSlide(v,r,valLbl)
    end
    applyRatio((vDef-vMin)/(vMax-vMin))
    local dragging=false
    local sBtn=Instance.new("TextButton",track); sBtn.Size=UDim2.new(1,12,1,12); sBtn.Position=UDim2.new(0,-6,0,-4); sBtn.BackgroundTransparency=1; sBtn.Text=""; sBtn.ZIndex=6
    sBtn.MouseButton1Down:Connect(function(x) dragging=true; applyRatio((x-track.AbsolutePosition.X)/track.AbsoluteSize.X) end)
    sBtn.MouseMoved:Connect(function(x) if dragging then applyRatio((x-track.AbsolutePosition.X)/track.AbsoluteSize.X) end end)
    sBtn.MouseButton1Up:Connect(function() dragging=false end); sBtn.MouseLeave:Connect(function() dragging=false end)
    if not _panelColorHooks then _panelColorHooks = {} end
    _panelColorHooks[#_panelColorHooks+1] = function()
        local nc = C.accent
        pcall(function() fill.BackgroundColor3 = nc end)
        pcall(function() kStr.Color           = nc end)
        pcall(function() valLbl.TextColor3    = nc end)
    end
    _vpY=_vpY+CARD_H_V+_vpPAD; return card,valLbl
end

local function _makeVtoggle(label, sublabel, col, initOn, onToggle)
    local ROW_H=46
    local card=Instance.new("Frame",visualSettingsPage); card.Size=UDim2.new(1,0,0,ROW_H); card.Position=UDim2.new(0,0,0,_vpY); card.BackgroundColor3=C.bg2; card.BackgroundTransparency=0; card.BorderSizePixel=0; corner(card,12)
    local cStr=_makeDummyStroke(card); cStr.Thickness=1; cStr.Color=C.bg3; cStr.Transparency=0.3
    local cdot=Instance.new("Frame",card); cdot.Size=UDim2.new(0,3,0,ROW_H-16); cdot.Visible = false; cdot.Position=UDim2.new(0,0,0.5,-(ROW_H-16)/2); cdot.BackgroundColor3=col; cdot.BackgroundTransparency=0.4; cdot.BorderSizePixel=0; corner(cdot,99)
    local lbl=Instance.new("TextLabel",card); lbl.Size=UDim2.new(1,-60,0,18); lbl.Position=UDim2.new(0,14,0,6); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=13; lbl.TextColor3=C.text; lbl.TextXAlignment=Enum.TextXAlignment.Left
    local sub=Instance.new("TextLabel",card); sub.Size=UDim2.new(1,-60,0,13); sub.Position=UDim2.new(0,14,0,24); sub.BackgroundTransparency=1; sub.Text=sublabel; sub.Font=Enum.Font.GothamBold; sub.TextSize=9; sub.TextColor3=C.sub; sub.TextXAlignment=Enum.TextXAlignment.Left
    local togTrack=Instance.new("Frame",card); togTrack.Size=UDim2.new(0,32,0,18); togTrack.Position=UDim2.new(1,-46,0.5,-9); togTrack.BorderSizePixel=0; corner(togTrack,99)
    local togKnob=Instance.new("Frame",togTrack); togKnob.Size=UDim2.new(0,12,0,12); togKnob.BorderSizePixel=0; corner(togKnob,99)
    local state=initOn or false
    local function refresh()
        if state then twP(togTrack,0.15,{BackgroundColor3=col,BackgroundTransparency=0.55}); twP(togKnob,0.15,{BackgroundColor3=Color3.fromRGB(255,255,255),Position=UDim2.new(1,-14,0.5,-6)}); twP(cStr,0.15,{Color=col,Transparency=0.5})
        else twP(togTrack,0.15,{BackgroundColor3=C.bg3,BackgroundTransparency=0.2}); twP(togKnob,0.15,{BackgroundColor3=Color3.fromRGB(100,100,100),Position=UDim2.new(0,2,0.5,-6)}); twP(cStr,0.15,{Color=C.bg3,Transparency=0.3}) end
    end
    refresh()
    local btn=Instance.new("TextButton",card); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=5
    local function activate() state=not state; onToggle(state); refresh() end
    btn.MouseButton1Click:Connect(activate)
    btn.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch then activate() end end)
    if not _panelColorHooks then _panelColorHooks = {} end
    _panelColorHooks[#_panelColorHooks+1] = function()
        local nc = C.accent
        pcall(function() cdot.BackgroundColor3  = nc end)
        pcall(function() togTrack.BackgroundColor3 = nc end)
    end
    _vpY=_vpY+ROW_H+_vpPAD; return card
end

local function _makeChipRow(sectionLabel, items, onSelect, getActive)
    local CHIP_H=52; local CHIP_GAP=8
    local CHIP_W=math.floor((PANEL_W-32-CHIP_GAP*(#items-1))/#items)
    local wrap=Instance.new("Frame",visualSettingsPage); wrap.Size=UDim2.new(1,0,0,CHIP_H+26); wrap.Position=UDim2.new(0,0,0,_vpY); wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0
    local secLbl=Instance.new("TextLabel",wrap); secLbl.Size=UDim2.new(1,-16,0,18); secLbl.Position=UDim2.new(0,8,0,0); secLbl.BackgroundTransparency=1; secLbl.Text=sectionLabel; secLbl.Font=Enum.Font.GothamBold; secLbl.TextSize=12; secLbl.TextColor3=C.sub; secLbl.TextXAlignment=Enum.TextXAlignment.Left
    local chips={}
    local function refresh()
        local act=getActive()
        for _,ch in ipairs(chips) do
            local isA=ch.id==act
            twP(ch.card,0.15,{BackgroundColor3=isA and C.bg3 or C.bg2,BackgroundTransparency=isA and 0.1 or 0})
            ch.str.Transparency=isA and 0.3 or 0.65; ch.str.Color=isA and _VCOL or C.bg3
            twP(ch.lbl,0.15,{TextColor3=isA and _VCOL or C.sub}); twP(ch.sub,0.15,{TextColor3=isA and C.text or C.sub})
        end
    end
    for i,item in ipairs(items) do
        local xOff=16+(i-1)*(CHIP_W+CHIP_GAP)
        local chip=Instance.new("Frame",wrap); chip.Size=UDim2.new(0,CHIP_W,0,CHIP_H); chip.Position=UDim2.new(0,xOff,0,22); chip.BackgroundColor3=C.bg2; chip.BackgroundTransparency=0; chip.BorderSizePixel=0; corner(chip,10)
        local cStr=_makeDummyStroke(chip); cStr.Thickness=1.5; cStr.Color=C.bg3; cStr.Transparency=0.65; cStr.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        local lbl=Instance.new("TextLabel",chip); lbl.Size=UDim2.new(1,-4,0,16); lbl.Position=UDim2.new(0,2,0,10); lbl.BackgroundTransparency=1; lbl.Text=item.label; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11; lbl.TextColor3=C.sub; lbl.TextXAlignment=Enum.TextXAlignment.Center
        local subL=Instance.new("TextLabel",chip); subL.Size=UDim2.new(1,-4,0,12); subL.Position=UDim2.new(0,2,1,-18); subL.BackgroundTransparency=1; subL.Text=item.sub or ""; subL.Font=Enum.Font.GothamBold; subL.TextSize=9; subL.TextColor3=C.sub; subL.TextXAlignment=Enum.TextXAlignment.Center
        local btn=Instance.new("TextButton",chip); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=8
        table.insert(chips,{id=item.id,card=chip,str=cStr,lbl=lbl,sub=subL})
        local captId=item.id
        local function activate() onSelect(captId); refresh() end
        btn.MouseButton1Click:Connect(activate)
        btn.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.Touch then activate() end end)
        btn.MouseEnter:Connect(function() _playHoverSound(); if getActive()~=captId then twP(chip,0.1,{BackgroundColor3=C.bg3}) end end)
        btn.MouseLeave:Connect(function() if getActive()~=captId then twP(chip,0.1,{BackgroundColor3=C.bg2}) end end)
    end
    refresh(); _vpY=_vpY+CHIP_H+26+_vpPAD
end

-- 1. Toggle
_makeVtoggle("Custom Cursor","native cursor FX",_VCOL,false,function(on) fxEnabled=on; _setFxEnabled(on) end)

-- 2. Cursor Size
_makeVslider("Cursor Size","pixel",16,64,CURSOR_SIZE,_VCOL,function(v,_,lbl)
    CURSOR_SIZE=math.floor(v+0.5); lbl.Text=tostring(CURSOR_SIZE)
    if cursorImage_ then cursorImage_.Size=UDim2.fromOffset(math.floor(CURSOR_SIZE*cursorScale_+0.5),math.floor(CURSOR_SIZE*cursorScale_+0.5)) end
    if cursorShadow_ then cursorShadow_.Size=UDim2.fromOffset(math.floor(CURSOR_SIZE*cursorShadowScale_+0.5),math.floor(CURSOR_SIZE*cursorShadowScale_+0.5)) end
end)

-- 3. FX Effect (14 Chips, 2 Zeilen)
do
    local EFF_ITEMS = {}
    for _, id in ipairs(EFFECT_ORDER) do 
        table.insert(EFF_ITEMS, {id = id, label = id:sub(1,1):upper() .. id:sub(2), sub = id}) 
    end
    
    -- Korrekte Initialisierung
    local R1 = {}
    local R2 = {}
    
    for i, e in ipairs(EFF_ITEMS) do 
        if i <= 7 then 
            R1[#R1 + 1] = e 
        else 
            R2[#R2 + 1] = e 
        end 
    end
    
    local function onEff(id) 
        fxEffect = id
        if fxEnabled then 
            _startFxLoop() 
        end 
    end
    
    _makeChipRow("FX Effect", R1, onEff, function() return fxEffect end)
    if #R2 > 0 then
        _makeChipRow("", R2, onEff, function() return fxEffect end)
    end
end

-- 4. Cursor Theme (11 Themes, 3 Zeilen)
do
    local THM={}; for _,id in ipairs(THEME_ORDER) do table.insert(THM,{id=id,label=id:sub(1,1):upper()..id:sub(2),sub=id}) end
    local T1,T2,T3={},{},{}
    for i,e in ipairs(THM) do if i<=4 then table.insert(T1,e) elseif i<=8 then table.insert(T2,e) else table.insert(T3,e) end end
    local function onThm(id) cursorTheme=id; applyCursorTheme_() end
    _makeChipRow("Cursor Theme",T1,onThm,function() return cursorTheme end)
    _makeChipRow("",T2,onThm,function() return cursorTheme end)
    _makeChipRow("",T3,onThm,function() return cursorTheme end)
end

-- 5. Partikelmenge
_makeVslider("Partikelmenge","particle count",0.35,2.50,fxParticleAmount,_VCOL,function(v,_,lbl) fxParticleAmount=math.clamp(v,0.35,2.50); lbl.Text=string.format("%d%%",math.floor(v*100+0.5)) end)

-- 6. Smoothness
_makeVslider("Smoothness","motion blur",0.35,0.92,fxSmoothness,_VCOL,function(v,_,lbl) fxSmoothness=math.clamp(v,0.35,0.92); lbl.Text=string.format("%d%%",math.floor(v*100+0.5)) end)

-- 7. Speed
_makeVslider("Tempo","animation speed",0.40,1.80,fxSpeed,_VCOL,function(v,_,lbl) fxSpeed=math.clamp(v,0.40,1.80); lbl.Text=string.format("%d%%",math.floor(v*100+0.5)) end)

-- 8. FX Farbe – 20 Preset-Chips (4 Reihen x 5)
do
    local FX_COLORS = {
        { id="white",   label="White",   color=Color3.fromRGB(255,255,255) },
        { id="lgray",   label="Silver",  color=Color3.fromRGB(180,185,195) },
        { id="gray",    label="Gray",    color=Color3.fromRGB(110,115,125) },
        { id="black",   label="Black",   color=Color3.fromRGB(30, 30, 35)  },
        { id="red",     label="Red",     color=Color3.fromRGB(255, 55, 80) },
        { id="orange",  label="Orange",  color=Color3.fromRGB(255,140, 40) },
        { id="yellow",  label="Yellow",  color=Color3.fromRGB(255,230, 40) },
        { id="lime",    label="Lime",    color=Color3.fromRGB(140,255,  0) },
        { id="green",   label="Green",   color=C.accent or Color3.fromRGB(0, 200, 255) },
        { id="mint",    label="Mint",    color=Color3.fromRGB( 80,255,185) },
        { id="cyan",    label="Cyan",    color=Color3.fromRGB(  0,230,230) },
        { id="sky",     label="Sky",     color=Color3.fromRGB( 80,190,255) },
        { id="blue",    label="Blue",    color=Color3.fromRGB( 60,120,255) },
        { id="indigo",  label="Indigo",  color=Color3.fromRGB(100,100,255) },
        { id="purple",  label="Purple",  color=Color3.fromRGB(185, 75,255) },
        { id="violet",  label="Violet",  color=Color3.fromRGB(220, 80,220) },
        { id="rose",    label="Rose",    color=Color3.fromRGB(255,100,160) },
        { id="pink",    label="Pink",    color=Color3.fromRGB(255,155,200) },
        { id="gold",    label="Gold",    color=Color3.fromRGB(255,200,  0) },
        { id="peach",   label="Peach",   color=Color3.fromRGB(255,175,100) },
    }
    local activeFxColorId = "green"
    -- Section label
    local secLbl = Instance.new("TextLabel", visualSettingsPage)
    secLbl.Size = UDim2.new(1,-16,0,16); secLbl.Position = UDim2.new(0,8,0,_vpY)
    secLbl.BackgroundTransparency = 1; secLbl.Text = "FX Farbe"
    secLbl.Font = Enum.Font.GothamBold; secLbl.TextSize = 11
    secLbl.TextColor3 = C.sub; secLbl.TextXAlignment = Enum.TextXAlignment.Left
    _vpY = _vpY + 20
    -- 4 rows of 5 chips
    local CHIP_W = math.floor((PANEL_W - 16) / 5)
    local CHIP_H2 = 28
    local chipBtns = {}
    local function refreshChips()
        for _, cb in ipairs(chipBtns) do
            local isActive = (cb.id == activeFxColorId)
            cb.frame.BackgroundTransparency = isActive and 0.0 or 0.5
            cb.stroke.Transparency = isActive and 0.15 or 0.7
            cb.lbl.Font = isActive and Enum.Font.GothamBlack or Enum.Font.Gotham
        end
    end
    for row = 0, 3 do
        local rowFrame = Instance.new("Frame", visualSettingsPage)
        rowFrame.Size = UDim2.new(1, 0, 0, CHIP_H2)
        rowFrame.Position = UDim2.new(0, 0, 0, _vpY)
        rowFrame.BackgroundTransparency = 1; rowFrame.BorderSizePixel = 0
        for col = 0, 4 do
            local idx = row * 5 + col + 1
            local item = FX_COLORS[idx]
            if not item then break end
            local f = Instance.new("Frame", rowFrame)
            f.Size = UDim2.new(0, CHIP_W-4, 0, CHIP_H2-4)
            f.Position = UDim2.new(0, col*(CHIP_W)+2, 0, 2)
            f.BackgroundColor3 = item.color
            f.BackgroundTransparency = 0.5; f.BorderSizePixel = 0; corner(f, 6)
            local fs = _makeDummyStroke(f)
            fs.Thickness = 1.5; fs.Color = item.color; fs.Transparency = 0.7
            fs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            local fl = Instance.new("TextLabel", f)
            fl.Size = UDim2.new(1,0,1,0); fl.BackgroundTransparency = 1
            fl.Text = item.label; fl.Font = Enum.Font.Gotham; fl.TextSize = 9
            fl.TextColor3 = Color3.fromRGB(240,242,248); fl.TextXAlignment = Enum.TextXAlignment.Center
            local fb = Instance.new("TextButton", f)
            fb.Size = UDim2.new(1,0,1,0); fb.BackgroundTransparency = 1; fb.Text = ""; fb.ZIndex = 8
            local capId = item.id; local capColor = item.color
            local function activate()
                activeFxColorId = capId
                fxColor = capColor
                applyCursorTheme_()
                refreshChips()
            end
            fb.MouseButton1Click:Connect(activate)
            fb.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.Touch then activate() end
            end)
            fb.MouseEnter:Connect(function() _playHoverSound(); f.BackgroundTransparency = 0.15 end)
            fb.MouseLeave:Connect(function()
                f.BackgroundTransparency = (activeFxColorId == capId) and 0.0 or 0.5
            end)
            table.insert(chipBtns, {id=item.id, frame=f, stroke=fs, lbl=fl})
        end
        _vpY = _vpY + CHIP_H2 + 4
    end
    refreshChips()
end

visualSettingsPage.Size = UDim2.new(1, 0, 0, _vpY)
end) -- /_ok_visualPage

subPages = { General = genPage, Keybinds = kbPage, Colors = colorsPage, Visual = visualSettingsPage }

-- subArea-Höhe – Panel + CanvasSize updaten
local function _updateSubAreaCanvas()
    local subH  = subArea.Size.Y.Offset
    local totalH = (CARD_H_S + 12) + subH + 8
    local newPH  = math.min(SET_BASE_H + math.max(subH, 0), SET_MAX_H)
    p.Size       = UDim2.new(0, PANEL_W, 0, newPH)
    local scrollH = newPH - SET_HDR_H
    c.CanvasSize = UDim2.new(0, 0, 0, math.max(totalH, scrollH))
end

local BASE_H_SET = CARD_H_S + 62
local function switchCat(id)
for _, pg in pairs(subPages) do pg.Visible = false end
for _, cb in ipairs(catBtns) do
twP(cb.card, 0.15, {BackgroundColor3 = C.bg2 or _C3_BG2})
twP(cb.lbl,  0.15, {TextColor3 = C.sub or _C3_SUB})
cb.cStr.Color = C.bg3 or _C3_BG3; cb.cStr.Transparency = 0.3
cb.selBar.Visible = false
-- ImageLabel-Icons bleiben neutral (nicht eingefärbt)
if cb.iconRef then pcall(function()
    if not cb.iconRef:IsA("ImageLabel") then
        twP(cb.iconRef, 0.15, {TextColor3 = C.sub or _C3_SUB})
    end
end) end
end
if activeCat == id then
    activeCat = nil
    tw(subArea, 0.18, {Size = UDim2.new(1, 0, 0, 0)},
        Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
    tw(p, 0.18, {Size = UDim2.new(0, PANEL_W, 0, SET_BASE_H)},
        Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
    task.delay(0.20, _updateSubAreaCanvas)
    return
end
activeCat = id
local pg = subPages[id]
if pg then
    pg.Visible = true
    local pgH = pg.Size.Y.Offset
    local newPH = math.min(SET_BASE_H + pgH + 8, SET_MAX_H)
    tw(subArea, 0.24, {Size = UDim2.new(1, 0, 0, pgH)},
        Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    tw(p, 0.24, {Size = UDim2.new(0, PANEL_W, 0, newPH)},
        Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    task.delay(0.26, _updateSubAreaCanvas)
end
for _, cb in ipairs(catBtns) do
if cb.id == id then
twP(cb.card, 0.20, {BackgroundColor3 = C.bg3 or _C3_BG4})
twP(cb.lbl,  0.20, {TextColor3 = C.text})
cb.cStr.Color = cb.col; cb.cStr.Transparency = 0.5
cb.selBar.Visible = true
-- ImageLabel-Icons bleiben neutral (nicht eingefärbt)
if cb.iconRef then pcall(function()
    if not cb.iconRef:IsA("ImageLabel") then
        twP(cb.iconRef, 0.20, {TextColor3 = cb.col})
    end
end) end
end
end
end
local _ok_catsLoop = pcall(function()
for i, cat in ipairs(CATS) do
local xOff = (i - 1) * (CARD_W_S + CARD_GAP)
local card = Instance.new("Frame", grid)
card.Size = UDim2.new(0, CARD_W_S, 0, CARD_H_S)
card.Position = UDim2.new(0, xOff, 0, 0)
card.BackgroundColor3 = C.bg2; card.BackgroundTransparency = 0
card.BorderSizePixel = 0; corner(card, 12)
local cStr = _makeDummyStroke(card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local selBar = Instance.new("Frame", card)
selBar.Size = UDim2.new(1,-16,0,2); selBar.Position = UDim2.new(0,8,0,0)
selBar.BackgroundColor3 = cat.col; selBar.BackgroundTransparency = 0
selBar.BorderSizePixel = 0; selBar.Visible = false; corner(selBar, 99)
-- Icon: ImageLabel (wie ESP-colorpicker / SCRIPT_CATS), fallback auf TextLabel
local _iconRef = nil
if cat.img then
    local _iSz = cat.iconSize or 28
    local iconImg = Instance.new("ImageLabel", card)
    iconImg.Size               = UDim2.new(0, _iSz, 0, _iSz)
    iconImg.Position           = UDim2.new(0.5, -_iSz/2, 0, -(_iSz/2) + 29)
    iconImg.BackgroundTransparency = 1
    iconImg.Image              = cat.img
    iconImg.ImageColor3        = Color3.fromRGB(255, 255, 255)
    iconImg.ScaleType          = Enum.ScaleType.Fit
    iconImg.BorderSizePixel    = 0
    _iconRef = iconImg
else
    local icon = Instance.new("TextLabel", card)
    icon.Size = UDim2.new(1,0,0,32); icon.Position = UDim2.new(0,0,0,8)
    icon.BackgroundTransparency = 1; icon.Text = cat.icon or ""
    icon.Font = Enum.Font.GothamBlack; icon.TextSize = 22
    icon.TextColor3 = Color3.fromRGB(180, 180, 180); icon.TextXAlignment = Enum.TextXAlignment.Center
    _iconRef = icon
end
local lbl = Instance.new("TextLabel", card)
lbl.Size = UDim2.new(1,-4,0,16); lbl.Position = UDim2.new(0,2,1,-22)
lbl.BackgroundTransparency = 1; lbl.Text = cat.id:upper()
lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
lbl.TextColor3 = C.sub or _C3_SUB; lbl.TextXAlignment = Enum.TextXAlignment.Center
local btn = Instance.new("TextButton", card)
btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 6
local catId = cat.id
btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
if activeCat ~= catId then
twP(card, 0.1, {BackgroundColor3 = C.bg3 or _C3_BG4})
end
end)
btn.MouseLeave:Connect(function()
if activeCat ~= catId then
twP(card, 0.1, {BackgroundColor3 = C.bg2 or _C3_BG2})
end
end)
btn.MouseButton1Click:Connect(function() switchCat(catId) end)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then switchCat(catId) end
end)
table.insert(catBtns, { id=catId, card=card, lbl=lbl, selBar=selBar, cStr=cStr, col=cat.col, iconRef=_iconRef })
-- Startzustand: Icon gedimmt (leuchtet erst beim Aktivieren auf)
-- ImageLabel-Icons bleiben neutral (nicht eingefärbt)
if _iconRef then pcall(function()
    if not _iconRef:IsA("ImageLabel") then
        _iconRef.TextColor3 = C.sub or _C3_SUB
    end
end) end
end
end) -- /_ok_catsLoop
-- p.Size bereits oben auf SET_PANEL_H gesetzt; kein Überschreiben hier
end); if not _ok_Settings then warn("[TL] Settings-IIFE crashed: " .. tostring(_err_Settings)) end
-- getNearestPlayer hier definiert damit _TL_refs den echten Wert bekommt
function getNearestPlayer()
local myRoot = getRootPart(); if not myRoot then return nil end
local best, bestDist = nil, math.huge
for _, pl in ipairs(Players:GetPlayers()) do
if pl ~= LocalPlayer and pl.Character then
local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
if hrp then
local d = (hrp.Position - myRoot.Position).Magnitude
if d < bestDist then bestDist = d; best = pl end
end
end
end
return best
end
-- -- Einstellungen früh laden: Theme muss VOR dem UI-Aufbau aktiv sein ------
pcall(function()
    if readfile and isfile and isfile(SAVE_FILE) then
        local ok, content = pcall(readfile, SAVE_FILE)
        if ok and content and content ~= "" then
            local settBlock = extractJsonSection(content, "settings")
            local tc = settBlock:match('"themeColor"%s*:%s*"([^"]*)"')
            if tc then
                settingsState.themeColor = tc
                _TL_applyTheme(tc)
            end
        end
    end
end)
task.spawn(function()
local _ok_SmartBar, _err_SmartBar = pcall(function()
local BAR_W, BAR_H, BAR_R = 514, 58, 8   -- BAR_R 8 = eckiger Matrix-Look (panels still use this)
local TAB_W = math.floor(BAR_W / 6)

-- -- Vertical Tab Launcher dimensions -----------------
local VL_W, VL_H, VL_GAP, VL_ICON_W, VL_ICON_H
do
    local _ok, _vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp = _ok and _vp or Vector2.new(1920, 1080)
    local _touch = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local _kbd   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local _short = math.min(_vp.X, _vp.Y)
    if _touch and not _kbd and _short < 500 then
    -- Handy: kompakt (10% kleiner)
    VL_W      = 38
    VL_H      = 42
    VL_GAP    = 4
    VL_ICON_W = 36
    VL_ICON_H = 36
elseif _touch and not _kbd then
    -- Tablet: etwas kleiner als PC (10% kleiner)
    VL_W      = 49
    VL_H      = 54
    VL_GAP    = 5
    VL_ICON_W = 48
    VL_ICON_H = 48
else
    -- PC: original (10% kleiner)
    VL_W      = 58
    VL_H      = 65
    VL_GAP    = 5
    VL_ICON_W = 58
    VL_ICON_H = 58
end
end -- close do (VL dimensions)

local VL_X_OFF  = -5

-- Mobile/Tablet scaling
local _sbScale = 1.0
do
    local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    vp = ok and vp or Vector2.new(1920,1080)
    local touch = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local kbd   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local short = math.min(vp.X, vp.Y)
    local long  = math.max(vp.X, vp.Y)
    if touch and not kbd and short < 500 then
        _sbScale = math.clamp(long * 0.88 / BAR_W, 0.55, 1.0)
    elseif touch and not kbd then
        _sbScale = math.clamp(long * 0.72 / BAR_W, 0.7, 1.0)
    elseif vp.X < 900 then
        _sbScale = math.clamp(vp.X * 0.88 / BAR_W, 0.6, 1.0)
    end
end

-- Panel-Position
local _PNL_X   = 5 + VL_ICON_W + 8
local PANEL_SHOW = UDim2.new(0, _PNL_X, 0, 5 + VL_ICON_H + 8)
local PANEL_HIDE = UDim2.new(0, _PNL_X, 0, -(600))

-- -- Matrix Farbpalette --------------------------------
local function MG_B()  return C.accent  end
local function MGA_B() return C.accent2 end
local function MGDIM() return C.sub     end

-- -- FPS-Widget Dimensionen ----------------------------
local FW_W, FW_H, FW_X_OFFSET = 320, 34, -5

-- -- Launcher root: always-visible TL icon button -----
local SmartBar = Instance.new("Frame", ScreenGui)
SmartBar.Name                   = "SmartBar"
SmartBar.Size                   = UDim2.new(0, 1, 0, 1)  -- nur noch als Event-Container, unsichtbar
SmartBar.AnchorPoint            = Vector2.new(1, 0)
SmartBar.Position               = UDim2.new(1, -1, 0, 0)  -- versteckt (TL-Logo jetzt in fpsWidget)
SmartBar.BackgroundColor3       = Color3.fromRGB(10, 10, 10)
SmartBar.BackgroundTransparency = 1
SmartBar.BorderSizePixel        = 0
SmartBar.Visible                = true   -- always visible
SmartBar.ZIndex                 = 8
SmartBar.ClipsDescendants       = false  -- tabs slide out below, not clipped
corner(SmartBar, 10)
-- UIStroke entfernt (kein grüner Rahmen mehr)

-- tlMainIcon + tlMainBtn entfernt (Button ist im fpsWidget, kein doppelter Icon oben rechts)
local tlMainIcon = nil  -- Referenz behalten damit spätere twP-Calls nicht crashen
local tlMainBtn  = nil

-- Rain/shimmer strip entfernt
local rainLblBar = nil

-- -- Tab cards container (slides out below the icon button) --
local tabCardsHolder = Instance.new("Frame", ScreenGui)
tabCardsHolder.Name                   = "TLTabCards"
tabCardsHolder.AnchorPoint            = Vector2.new(0, 0)
tabCardsHolder.Size                   = UDim2.new(0, VL_W, 0, 0)
tabCardsHolder.BackgroundTransparency = 1
tabCardsHolder.BorderSizePixel        = 0
tabCardsHolder.ClipsDescendants       = true
tabCardsHolder.Visible                = false
tabCardsHolder.ZIndex                 = 7
-- FIX Mobile: Tab-Karten auf Mobile links von fpsWidget (unten), auf Desktop rechts oben
do
    local _ok2, _vp2 = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp2 = _ok2 and _vp2 or Vector2.new(1920, 1080)
    local _touch2 = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local _kbd2   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local _short2 = math.min(_vp2.X, _vp2.Y)
    local _isMob2 = _touch2 and not _kbd2 and _short2 < 500
    local _isTab2 = _touch2 and not _kbd2 and _short2 >= 500 and _short2 < 900
    if _isMob2 or _isTab2 then
        tabCardsHolder.AnchorPoint = Vector2.new(1, 1)
        tabCardsHolder.Position    = UDim2.new(1, -5, 1, -80 - 34 - 8)
    else
        tabCardsHolder.AnchorPoint = Vector2.new(0, 0)
        tabCardsHolder.Position    = UDim2.new(1, -5 - VL_W, 0, 5 + VL_ICON_H + 6)
    end
end

local isOpen, activeTab, _closeTok = false, nil, 0
local tabDefs = {
{ name="Home",       img="rbxassetid://77458828386203" },
{ name="Character",  img="rbxassetid://130511578744559" },
{ name="Scripts",    img="rbxassetid://99174931681951"  },
{ name="Actions",    img="rbxassetid://77458828386203"  },
{ name="Playerlist", img="rbxassetid://133085949121423" },
{ name="Settings",   img="rbxassetid://117318347375651"  },
}
local tabBtns, selectTab = {}, nil
local TOTAL_CARDS_H = #tabDefs * (VL_H + VL_GAP) - VL_GAP

-- -- Mobile/Tablet detection (muss VOR der for-Schleife stehen) ----------
local _ok_f, _vp_f = pcall(function() return workspace.CurrentCamera.ViewportSize end)
_vp_f = _ok_f and _vp_f or Vector2.new(1920, 1080)
local _touch_f = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
local _kbd_f   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
local _short_f = math.min(_vp_f.X, _vp_f.Y)
local _isMob   = _touch_f and not _kbd_f and _short_f < 500
local _isTab   = _touch_f and not _kbd_f and _short_f >= 500 and _short_f < 900
-- ------------------------------------------------------------------------

for i, tab in ipairs(tabDefs) do
    local yOff = (i - 1) * (VL_H + VL_GAP)

    -- card background
    local card = Instance.new("Frame", tabCardsHolder)
    card.Size             = UDim2.new(0, VL_W, 0, VL_H)
    card.Position         = UDim2.new(0, 0, 0, yOff)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    card.BackgroundTransparency = 0
    card.BorderSizePixel  = 0
    card.ZIndex           = 8
    corner(card, 10)
    local cardStroke = _makeDummyStroke(card)
    cardStroke.Thickness = 1; cardStroke.Color = MGDIM(); cardStroke.Transparency = 0.65
    cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- active indicator bar (left edge)
    local pill = Instance.new("Frame", card)
    pill.Size             = UDim2.new(0, 2, 0, 28)
    pill.Position         = UDim2.new(0, 0, 0.5, -14)
    pill.BackgroundColor3 = MG_B()
    pill.BackgroundTransparency = 1
    pill.BorderSizePixel  = 0; pill.ZIndex = 10
    corner(pill, 99)

    -- icon (image or emoji)
    local iconImg, iconLbl = nil, nil
    local _ico   = (_isMob and 18) or (_isTab and 25) or 31
    local _icoOff = math.floor(_ico / 2)
    local _icoY  = (_isMob and 5)  or (_isTab and 7)  or 11
    local _emoH  = (_isMob and 20) or (_isTab and 27) or 34
    local _emoY  = (_isMob and 3)  or (_isTab and 5)  or 9
    local _emoSz = (_isMob and 14) or (_isTab and 20) or 25
    if tab.img then
        local _sz, _yPos = _ico, _icoY
        if tab.name == "Character" then
            local _want = (_isMob and 24) or (_isTab and 32) or 42
            _sz = math.min(_want, math.max(14, VL_H - 20))
            _yPos = math.max(1, math.floor((VL_H - 18 - _sz) / 2))
        end
        local _off = math.floor(_sz / 2)
        iconImg = Instance.new("ImageLabel", card)
        iconImg.Size             = UDim2.new(0, _sz, 0, _sz)
        iconImg.Position         = UDim2.new(0.5, -_off, 0, _yPos)
        iconImg.BackgroundTransparency = 1
        iconImg.Image            = tab.img
        iconImg.ImageColor3      = Color3.new(1, 1, 1)
        iconImg.ScaleType        = Enum.ScaleType.Fit
        iconImg.ZIndex           = 10
    else
        iconLbl = Instance.new("TextLabel", card)
        iconLbl.Size             = UDim2.new(1, 0, 0, _emoH)
        iconLbl.Position         = UDim2.new(0, 0, 0, _emoY)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text             = tab.icon or ""
        iconLbl.Font             = Enum.Font.GothamBlack
        iconLbl.TextSize         = _emoSz
        iconLbl.TextColor3       = MGDIM()
        iconLbl.TextXAlignment   = Enum.TextXAlignment.Center
        iconLbl.ZIndex           = 10
    end

    -- label under icon
    local lbl = Instance.new("TextLabel", card)
    lbl.Size             = UDim2.new(1, -4, 0, 9)
    lbl.Position         = UDim2.new(0, 2, 1, -16)
    lbl.BackgroundTransparency = 1
    lbl.Text             = tab.name:upper()
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 9
    lbl.TextScaled       = false
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment   = Enum.TextXAlignment.Center
    lbl.ZIndex           = 10

    -- clickable button over entire card
    local btn = Instance.new("TextButton", card)
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""; btn.ZIndex = 12

    table.insert(tabBtns, {
        name    = tab.name,
        card    = card,
        pill    = pill,
        cardStroke = cardStroke,
        iconLbl = iconLbl,
        iconImg = iconImg,
        lbl     = lbl,
    })

    btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
        if activeTab ~= tab.name then
            twP(card, 0.10, {BackgroundColor3 = Color3.fromRGB(22, 22, 22)})
            if iconImg then twP(iconImg, 0.10, {ImageTransparency = 0.2}) end
            if iconLbl then twP(iconLbl, 0.10, {TextColor3 = MGA_B()}) end
            twP(lbl, 0.10, {TextColor3 = Color3.fromRGB(255, 255, 255)})
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.name then
            twP(card, 0.10, {BackgroundColor3 = Color3.fromRGB(14, 14, 14)})
            if iconImg then twP(iconImg, 0.10, {ImageTransparency = 0}) end
            if iconLbl then twP(iconLbl, 0.10, {TextColor3 = MGDIM()}) end
            twP(lbl, 0.10, {TextColor3 = Color3.fromRGB(255, 255, 255)})
        end
    end)
    -- FIX: Lock verhindert Doppel-Fire auf Touch (MouseButton1Click + InputBegan feuern beide)
    local _tabBtnLock = false
    local captName = tab.name
    local function tabBtnActivate()
        if _tabBtnLock then return end
        _tabBtnLock = true
        task.delay(0.35, function() _tabBtnLock = false end)
        selectTab(captName)
    end
    btn.MouseButton1Click:Connect(tabBtnActivate)
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then tabBtnActivate() end
    end)
end
function deselectAll()
for _, tb in ipairs(tabBtns) do
    twP(tb.card,  0.14, {BackgroundColor3 = Color3.fromRGB(14, 14, 14)})
    twP(tb.pill,  0.14, {BackgroundTransparency = 1})
    if tb.cardStroke then tb.cardStroke.Color = MGDIM(); tb.cardStroke.Transparency = 0.65 end
    if tb.iconLbl then twP(tb.iconLbl, 0.14, {TextColor3 = MGDIM()}) end
    if tb.iconImg then twP(tb.iconImg, 0.14, {ImageTransparency = 0}) end
    twP(tb.lbl, 0.14, {TextColor3 = Color3.fromRGB(255, 255, 255)})
end
end
selectTab = function(name)
if activeTab and panels[activeTab] then
    local old = panels[activeTab]
    tw(old, 0.16, {
        Position               = UDim2.new(PANEL_HIDE.X.Scale, PANEL_HIDE.X.Offset, PANEL_HIDE.Y.Scale, PANEL_HIDE.Y.Offset + 10),
        BackgroundTransparency = 1,
    }, Enum.EasingStyle.Exponential, Enum.EasingDirection.In):Play()
    task.delay(0.18, function() pcall(function() old.Visible=false end) end)
end
deselectAll()
if name == activeTab then activeTab=nil; return end
activeTab = name
for _, tb in ipairs(tabBtns) do
if tb.name == name then
    twP(tb.card,  0.18, {BackgroundColor3 = C.bg3 or Color3.fromRGB(22, 22, 22)})
    twP(tb.pill,  0.20, {BackgroundTransparency = 0})
    if tb.cardStroke then tb.cardStroke.Color = MG_B(); tb.cardStroke.Transparency = 0.3 end
    if tb.iconLbl then twP(tb.iconLbl, 0.16, {TextColor3 = MG_B()}) end
    if tb.iconImg then twP(tb.iconImg, 0.16, {ImageTransparency = 0}) end
    twP(tb.lbl, 0.16, {TextColor3 = Color3.fromRGB(255, 255, 255)})
end
end
if panels[name] then
    local pan = panels[name]
    pan.BackgroundTransparency = 1
    -- FIX Mobile: Panel-Breite dynamisch; Home-Panel kann breiter sein
    local _pwOpen = (name == "Home" and HOME_PANEL_W_OVERRIDE) or PANEL_W
    pan.Size     = UDim2.new(0, _pwOpen, 0, pan.Size.Y.Offset)
    pan.Position = UDim2.new(PANEL_HIDE.X.Scale, PANEL_HIDE.X.Offset, PANEL_HIDE.Y.Scale, PANEL_HIDE.Y.Offset + 18)
    pan.Visible  = true
    local _pt = tw(pan, 0.28, {
        Position               = PANEL_SHOW,
        BackgroundTransparency = 0,
    }, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    _panelTweens[name] = _pt
    _pt:Play()
end
end
do
-- Rain scroll on the TL icon button
local rainAcc = 0
local shimAcc = 0
local _shimV2 = Vector2.new(0, 0)  -- reused, avoids alloc per tick
_tlTrackConn(RunService.Heartbeat:Connect(function(dt)
    if not _tlAlive() then return end
    if not isOpen then return end  -- no visual updates needed while closed
    shimAcc = shimAcc + dt
    if shimAcc < 0.033 then return end
    rainAcc = (rainAcc + shimAcc * 28) % VL_W
    if rainLblBar then
        rainLblBar.Position = UDim2.new(0, -rainAcc, 0, 0)
    end
    local cn = #panelCreditGrads
    if cn > 0 then
        local st = (os.clock() * 0.25) % 1
        local cX = -1.5 + st * 3
        _shimV2 = Vector2.new(cX, 0)
        for i = 1, cn do panelCreditGrads[i].Offset = _shimV2 end
    end
    shimAcc = 0
end))
end
function openBar()
if _TL_refs._TL_closeQABar then _TL_refs._TL_closeQABar() end
_closeTok = _closeTok + 1
isOpen    = true
tabCardsHolder.Visible = true
tabCardsHolder.Size    = UDim2.new(0, VL_W, 0, 0)
tw(tabCardsHolder, 0.30, {
    Size = UDim2.new(0, VL_W, 0, TOTAL_CARDS_H),
}, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
-- pulse the TL icon (entfernt, tlMainIcon ist nil)
if tlMainIcon then twP(tlMainIcon, 0.18, {ImageColor3 = Color3.fromRGB(255, 255, 255)}) end
end
function closeBar()
isOpen = false
if activeTab and panels[activeTab] then
    local pan = panels[activeTab]
    tw(pan, 0.16, {
        Position               = UDim2.new(PANEL_HIDE.X.Scale, PANEL_HIDE.X.Offset, PANEL_HIDE.Y.Scale, PANEL_HIDE.Y.Offset + 10),
        BackgroundTransparency = 1,
    }, Enum.EasingStyle.Exponential, Enum.EasingDirection.In):Play()
    task.delay(0.18, function() pcall(function() pan.Visible=false end) end)
end
activeTab = nil
deselectAll()
local myTok = _closeTok+1; _closeTok = myTok
tw(tabCardsHolder, 0.20, {
    Size = UDim2.new(0, VL_W, 0, 0),
}, Enum.EasingStyle.Quart, Enum.EasingDirection.In):Play()
task.delay(0.22, function()
    if _closeTok == myTok then
        tabCardsHolder.Visible = false
    end
end)
-- dim the TL icon (entfernt, tlMainIcon ist nil)
if tlMainIcon then twP(tlMainIcon, 0.18, {ImageColor3 = Color3.fromRGB(255, 255, 255)}) end
end
-- -- Theme-Hook: Tab-Farben bei Theme-Wechsel aktualisieren ------------------
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function(_newT)
    pcall(function()
        for _, tb in ipairs(tabBtns) do
            local isActive = (tb.name == activeTab)
            if tb.cardStroke then
                tb.cardStroke.Color = isActive and MG_B() or MGDIM()
                tb.cardStroke.Transparency = isActive and 0.3 or 0.65
            end
            if tb.iconLbl then
                twP(tb.iconLbl, 0.12, {TextColor3 = isActive and MG_B() or MGDIM()})
            end
            twP(tb.lbl, 0.12, {TextColor3 = Color3.fromRGB(255, 255, 255)})
            twP(tb.pill, 0.12, {BackgroundColor3 = MG_B()})
            if isActive then
                twP(tb.card, 0.12, {BackgroundColor3 = C.bg3 or Color3.fromRGB(22,22,22)})
            end
        end
    end)
end
_tlTrackConn(UserInputService.InputBegan:Connect(function(input, gpe)
if input.KeyCode ~= Enum.KeyCode.K then
if gpe then return end
end
if input.KeyCode == Enum.KeyCode.K then
if isOpen then closeBar() else openBar() end
end
end))
-- tlMainBtn-Connections entfernt (Button läuft über fpsWidget tlSmartHitbox)
-- Drag entfernt – TL Logo ist nicht verschiebbar
-- Mobile: globaler TouchTap-Handler entfernt – verursachte Konflikt mit tlSmartHitbox
-- (jeder Touch auf den Hitbox-Bereich feuerte BEIDE Handler → Menu öffnet/schließt sofort)
LocalPlayer.CharacterAdded:Connect(function()
task.wait(1.2)
if settingsState.autoOpen and not isOpen then openBar() end
end)
pcall(function()
game:GetService("TeleportService").LocalPlayerArrivedFromTeleport:Connect(function()
task.wait(2)
if settingsState.autoOpen and not isOpen then openBar() end
end)
end)
task.spawn(function()
task.wait(0.5)
loadData()
rebuildKeybindListener()
sendNotif("SmartBar", T.notif_settings_loaded, 2)
end)
do
local existing = PlayerGui:FindFirstChild("FPSWidget")
if not existing then
pcall(function()
existing = game:GetService("CoreGui"):FindFirstChild("FPSWidget")
end)
end
if not existing then
pcall(function()
for _, sg in ipairs(PlayerGui:GetChildren()) do
local w = sg:FindFirstChild("FPSWidget")
if w then w:Destroy() end
end
end)
end
if existing then pcall(function() existing:Destroy() end) end
local inSG = ScreenGui:FindFirstChild("FPSWidget")
if inSG then inSG:Destroy() end
end
-- FW_W, FW_H, FW_X_OFFSET wurden bereits oben definiert (vor SmartBar)
local fpsWidget = Instance.new("Frame", ScreenGui)
fpsWidget.Name                   = "FPSWidget"
fpsWidget.Size                   = UDim2.new(0, FW_W, 0, FW_H)
fpsWidget.AnchorPoint            = Vector2.new(1, 0.5)
fpsWidget.BackgroundColor3       = C.panelBg
fpsWidget.BackgroundTransparency = 0.08
fpsWidget.BorderSizePixel        = 0
fpsWidget.ZIndex                 = 20
fpsWidget.Active                 = false  -- Frame passiert Inputs durch

-- Mobile/Tablet: scale and reposition
do
    local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    vp = ok and vp or Vector2.new(1920,1080)
    local touch = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local kbd   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local short = math.min(vp.X, vp.Y)
    local isMob = touch and not kbd and short < 500
    local isTab = touch and not kbd and short >= 500 and short < 900
    if isMob or isTab then
        local scl = _TL_VP.mobScl  -- zentraler Scale aus _TL_VP
        local fwUIScale = Instance.new("UIScale", fpsWidget)
        fwUIScale.Scale = scl
        -- Position: bündig rechts oben neben den Tab-Karten
        fpsWidget.AnchorPoint = Vector2.new(1, 0)
        fpsWidget.Position    = UDim2.new(1, -(5 + VL_W + 4), 0, 5)
    else
        fpsWidget.AnchorPoint = Vector2.new(1, 0)
        fpsWidget.Position    = UDim2.new(1, -(5), 0, 5 + math.floor((VL_ICON_H - FW_H) / 2))
    end
end
do local c = Instance.new("UICorner", fpsWidget); c.CornerRadius = UDim.new(0, 8) end
local fwBodyGrad = Instance.new("UIGradient", fpsWidget)
pcall(function() fwBodyGrad.Color = _TL_fpsWidgetBgGradient() end)
fwBodyGrad.Rotation = 135
local fwStroke = _makeDummyStroke(fpsWidget)
fwStroke.Thickness       = 1
fwStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
fwStroke.Color           = C.accent2
fwStroke.Transparency    = 0.5
-- RGB bar removed for modern clean look
function sep(x)
local s = Instance.new("Frame", fpsWidget)
s.Size             = UDim2.new(0,1,0,16)
s.Position         = UDim2.new(0,x,0.5,-8)
s.BackgroundColor3 = C.borderdim
s.BackgroundTransparency = 0.3
s.BorderSizePixel  = 0; s.ZIndex = 11
end
-- Großes TL-Logo (32x32) – öffnet das Menü
local tlLblBig = Instance.new("ImageLabel", fpsWidget)
tlLblBig.Size                   = UDim2.new(0, 22, 0, 22)
tlLblBig.Position               = UDim2.new(0, 9, 0.5, -11)
tlLblBig.BackgroundTransparency = 1
tlLblBig.Image                  = "rbxassetid://77458828386203"
tlLblBig.ImageColor3            = _C3_WHITE
tlLblBig.ScaleType              = Enum.ScaleType.Fit
tlLblBig.ZIndex                 = 11
local tlArrowBig = Instance.new("TextLabel", fpsWidget)
tlArrowBig.Size                 = UDim2.new(0,24,1,0)
tlArrowBig.Position             = UDim2.new(0,33,0,0)
tlArrowBig.BackgroundTransparency = 1
tlArrowBig.Text                 = "»"
tlArrowBig.Font                 = Enum.Font.GothamBlack
tlArrowBig.TextSize             = 13
tlArrowBig.TextColor3           = Color3.fromRGB(245,245,245)
tlArrowBig.TextXAlignment       = Enum.TextXAlignment.Center
tlArrowBig.ZIndex               = 11
sep(58)
-- Kleines TL-Logo (20x20) – war vorher bereits im Widget
local tlLbl = Instance.new("ImageLabel", fpsWidget)
tlLbl.Size                   = UDim2.new(0, 20, 0, 20)
tlLbl.Position               = UDim2.new(0, 62, 0.5, -10)
tlLbl.BackgroundTransparency = 1
tlLbl.Image                  = "rbxassetid://77458828386203"
tlLbl.ImageColor3            = _C3_WHITE
tlLbl.ScaleType              = Enum.ScaleType.Fit
tlLbl.ZIndex                 = 11
local tlArrow = Instance.new("TextLabel", fpsWidget)
tlArrow.Size                 = UDim2.new(0,24,1,0)
tlArrow.Position             = UDim2.new(0,84,0,0)
tlArrow.BackgroundTransparency = 1
tlArrow.Text                 = "»"
tlArrow.Font                 = Enum.Font.GothamBlack
tlArrow.TextSize             = 13
tlArrow.TextColor3           = Color3.fromRGB(245,245,245)
tlArrow.TextXAlignment       = Enum.TextXAlignment.Center
tlArrow.ZIndex               = 11
-- FIX Mobile: Hitbox-Größe für bessere Touch-Targets
local _hbTouch = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
local _hbKbd   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
local _hbMob   = _hbTouch and not _hbKbd
local _hitboxW = _hbMob and 56 or 44   -- größere Touch-Targets auf Mobile
local _hitboxH = _hbMob and math.max(FW_H + 10, 44) or FW_H
-- tlSmartHitbox: linke Hälfte – öffnet SmartBar
local tlSmartHitbox = Instance.new("TextButton", ScreenGui)
tlSmartHitbox.Name                   = "TLSmartHitbox"
tlSmartHitbox.Size                   = UDim2.new(0, _hitboxW, 0, _hitboxH)
tlSmartHitbox.BackgroundTransparency = 1
tlSmartHitbox.Text                   = ""
tlSmartHitbox.ZIndex                 = 9999
tlSmartHitbox.Active                 = true
tlSmartHitbox.AutoButtonColor        = false
-- tlHitbox: rechte Hälfte – öffnet QABar
local tlHitbox = Instance.new("TextButton", ScreenGui)
tlHitbox.Name                   = "TLHitbox"
tlHitbox.Size                   = UDim2.new(0, _hitboxW, 0, _hitboxH)
tlHitbox.BackgroundTransparency = 1
tlHitbox.Text                   = ""
tlHitbox.ZIndex                 = 9999
tlHitbox.Active                 = true
tlHitbox.AutoButtonColor        = false
do
    local ok, vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    vp = ok and vp or Vector2.new(1920,1080)
    local touch = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local kbd   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local short = math.min(vp.X, vp.Y)
    local isMob = touch and not kbd and short < 500
    local isTab = touch and not kbd and short >= 500 and short < 900
    local yOff  = 5 + math.floor((VL_ICON_H - FW_H) / 2)
    -- FIX: Hitboxen genau über die Logo-Bereiche im fpsWidget legen
    -- fpsWidget ist AnchorPoint(0.5,1), Position(0.5,0, 1,-80) auf Mobile
    -- SmartBar-Logo: 0..44px, QABar-Logo: 44..88px im Widget
    if isMob or isTab then
        -- Mobile/Tablet: Hitboxen am unteren Bildschirmrand über das fpsWidget legen
        -- fpsWidget: center-bottom bei Y=1,-80; width=FW_W
        -- SmartHitbox über linke Logo-Seite (0..44 innerhalb Widget)
        local _wHalf = math.floor(FW_W / 2)
        tlSmartHitbox.AnchorPoint = Vector2.new(0.5, 1)
        tlSmartHitbox.Position    = UDim2.new(0.5, -(_wHalf - _hitboxW/2), 1, -80 + math.floor((_hitboxH - FW_H)/2))
        tlHitbox.AnchorPoint = Vector2.new(0.5, 1)
        tlHitbox.Position    = UDim2.new(0.5, -(_wHalf - _hitboxW - _hitboxW/2), 1, -80 + math.floor((_hitboxH - FW_H)/2))
    else
        -- Desktop: Hitboxen rechts oben, bündig mit fpsWidget
        tlSmartHitbox.AnchorPoint = Vector2.new(1, 0)
        tlSmartHitbox.Position    = UDim2.new(1, -(5 + FW_W - 44), 0, yOff)
        tlHitbox.AnchorPoint = Vector2.new(1, 0)
        tlHitbox.Position    = UDim2.new(1, -(5 + FW_W - 88), 0, yOff)
    end
end
-- -- Linkes TL-Logo (tlSmartHitbox): SmartBar öffnen/schließen ------
-- Connections hier: beide Hitboxen sind definiert, openBar/closeBar/isOpen im Scope
-- FIX: Lock verhindert Doppel-Fire auf Touch (MouseButton1Click + InputBegan feuern beide)
local _smartHitboxLock = false
local function smartHitboxActivate()
    if _smartHitboxLock then return end
    _smartHitboxLock = true
    task.delay(0.35, function() _smartHitboxLock = false end)
    if isOpen then closeBar() else openBar() end
end
tlSmartHitbox.MouseButton1Click:Connect(smartHitboxActivate)
tlSmartHitbox.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then smartHitboxActivate() end
end)
-- globaler UIS-Fallback entfernt (verursachte doppeltes Feuern auf Touch → Menu öffnet/schließt sofort)
tlSmartHitbox.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
    twP(tlLblBig,  .1, {ImageTransparency=0.3})
    twP(tlArrowBig,.1, {TextTransparency =0.3})
end)
tlSmartHitbox.MouseLeave:Connect(function()
    twP(tlLblBig,  .1, {ImageTransparency=0})
    twP(tlArrowBig,.1, {TextTransparency =0})
end)
sep(110)
local fwTag = Instance.new("TextLabel", fpsWidget)
fwTag.Size             = UDim2.new(0,28,1,0)
fwTag.Position         = UDim2.new(0,116,0,0)
fwTag.BackgroundTransparency = 1
fwTag.Text             = "FPS"
fwTag.Font             = Enum.Font.GothamBold
fwTag.TextSize         = 9
fwTag.TextColor3       = Color3.fromRGB(255, 255, 255)
fwTag.TextXAlignment   = Enum.TextXAlignment.Left
fwTag.ZIndex           = 11
local fwVal = Instance.new("TextLabel", fpsWidget)
fwVal.Size             = UDim2.new(0,36,1,0)
fwVal.Position         = UDim2.new(0,146,0,0)
fwVal.BackgroundTransparency = 1
fwVal.Text             = "--"
fwVal.Font             = Enum.Font.GothamBold
fwVal.TextSize         = 14
fwVal.TextColor3       = Color3.fromRGB(255, 255, 255)
fwVal.TextXAlignment   = Enum.TextXAlignment.Left
fwVal.ZIndex           = 12
sep(188)
local pingTag = Instance.new("TextLabel", fpsWidget)
pingTag.Size             = UDim2.new(0,28,1,0)
pingTag.Position         = UDim2.new(0,194,0,0)
pingTag.BackgroundTransparency = 1
pingTag.Text             = "PING"
pingTag.Font             = Enum.Font.GothamBold
pingTag.TextSize         = 9
pingTag.TextColor3       = Color3.fromRGB(255, 255, 255)
pingTag.TextXAlignment   = Enum.TextXAlignment.Left
pingTag.ZIndex           = 11
local pingVal = Instance.new("TextLabel", fpsWidget)
pingVal.Size             = UDim2.new(0,50,1,0)
pingVal.Position         = UDim2.new(0,228,0,0)
pingVal.BackgroundTransparency = 1
pingVal.Text             = "--"
pingVal.Font             = Enum.Font.GothamBold
pingVal.TextSize         = 14
pingVal.TextColor3       = Color3.fromRGB(255, 255, 255)
pingVal.TextXAlignment   = Enum.TextXAlignment.Left
pingVal.ZIndex           = 12
sep(282)
local liveDot = Instance.new("Frame", fpsWidget)
liveDot.Size             = UDim2.new(0,6,0,6)
liveDot.Position         = UDim2.new(0, FW_W-18, 0.5,-3)
liveDot.BackgroundColor3 = C.accent
liveDot.BorderSizePixel  = 0; liveDot.ZIndex = 12
do local c=Instance.new("UICorner",liveDot); c.CornerRadius=UDim.new(0,99) end
task.spawn(function()
local _ldTw = nil
while _tlAlive() and liveDot and liveDot.Parent do
if _ldTw then pcall(_ldTw.Cancel, _ldTw) end
_ldTw = tw(liveDot,0.5,{BackgroundTransparency=0.7}); _ldTw:Play()
task.wait(1.1)
if _ldTw then pcall(_ldTw.Cancel, _ldTw) end
_ldTw = tw(liveDot,0.5,{BackgroundTransparency=0}); _ldTw:Play()
task.wait(1.1)
end
end)
-- -- Theme-Hook: erst jetzt registrieren, alle Variablen sind definiert ----
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function(_newT)
    pcall(function() fwStroke.Color = C.accent2 end)
    pcall(function() liveDot.BackgroundColor3 = C.accent end)
    pcall(function() fpsWidget.BackgroundColor3 = C.panelBg end)
    pcall(function() fwBodyGrad.Color = _TL_fpsWidgetBgGradient() end)
    pcall(function()
        for _, ch in ipairs(fpsWidget:GetChildren()) do
            if ch:IsA("Frame") and ch.Size == UDim2.new(0,1,0,16) then
                ch.BackgroundColor3 = C.borderdim
            end
        end
    end)
end
local _fpsAcc, _fpsFrames, _pingAcc = 0, 0, 0
local _statsService; pcall(function() _statsService = game:GetService("Stats") end)
local _fwPingItem
pcall(function()
    if _statsService then
        local net = _statsService:FindFirstChild("Network")
        local srv = net and net:FindFirstChild("ServerStatsItem")
        if srv then
            _fwPingItem = srv:FindFirstChild("Data Ping") or srv:FindFirstChild("DataPing")
        end
    end
end)
_tlTrackConn(_SvcRS.Heartbeat:Connect(function(dt)
if not _tlAlive() then return end
_fpsFrames = _fpsFrames + 1
_fpsAcc    = _fpsAcc + dt
if _fpsAcc >= 0.5 then
    local fps = _mfloor(_fpsFrames / _fpsAcc)
    _fpsAcc = 0; _fpsFrames = 0
    if fwVal and fwVal.Parent then
        fwVal.Text = tostring(fps)
        fwVal.TextColor3 = Color3.fromRGB(255, 255, 255)
        if liveDot then liveDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end
    end
end
_pingAcc = _pingAcc + dt
if _pingAcc >= 0.5 then
    _pingAcc = 0
    if pingVal and pingVal.Parent and _fwPingItem then
        local ok, v = pcall(function() return _fwPingItem:GetValue() end)
        if ok and v then
            pingVal.Text = _mfloor(v) .. "ms"
        end
    end
end
end))
do
local _genv = getgenv and getgenv()
if _genv then
rawset(_genv, "_TL_ScreenGui",        ScreenGui)
rawset(_genv, "_TL_fpsWidget",        fpsWidget)
rawset(_genv, "_TL_tlHitbox",         tlHitbox)
rawset(_genv, "_TL_tlLblBig",         tlLblBig)
rawset(_genv, "_TL_tlArrowBig",       tlArrowBig)
rawset(_genv, "_TL_tlLbl",            tlLbl)
rawset(_genv, "_TL_tlArrow",          tlArrow)
rawset(_genv, "_TL_FW_W",             FW_W)
rawset(_genv, "_TL_FW_H",             FW_H)
rawset(_genv, "_TL_FW_X_OFFSET",      FW_X_OFFSET)
rawset(_genv, "_TL_VL_ICON_W",        VL_ICON_W)
rawset(_genv, "_TL_VL_ICON_H",        VL_ICON_H)
rawset(_genv, "_TL_tw",               tw)
rawset(_genv, "_TL_corner",           corner)
rawset(_genv, "_TL_sendNotif",        sendNotif)
rawset(_genv, "_TL_getNearestPlayer", getNearestPlayer)
rawset(_genv, "_TL_getRootPart",      getRootPart)
rawset(_genv, "_TL_getHumanoid",      getHumanoid)
rawset(_genv, "_TL_safeStand",        safeStand)
rawset(_genv, "_TL_stopBB",           stopBB)
rawset(_genv, "_TL_startBB",          startBB)
end
end
-- Also populate _TL_refs for upvalue-safe access (ByteBreaker / isolated envs)
_TL_refs._TL_ScreenGui        = ScreenGui
_TL_refs._TL_fpsWidget        = fpsWidget
_TL_refs._TL_tlHitbox         = tlHitbox
_TL_refs._TL_tlLbl            = tlLbl
_TL_refs._TL_tlArrow          = tlArrow
_TL_refs._TL_tlArrowBig       = tlArrowBig
_TL_refs._TL_FW_W             = FW_W
_TL_refs._TL_FW_H             = FW_H
_TL_refs._TL_FW_X_OFFSET      = FW_X_OFFSET
_TL_refs._TL_VL_ICON_W        = VL_ICON_W
_TL_refs._TL_VL_ICON_H        = VL_ICON_H
_TL_refs._TL_tw               = tw
_TL_refs._TL_corner           = corner
_TL_refs._TL_sendNotif        = sendNotif
_TL_refs._TL_getNearestPlayer = getNearestPlayer
_TL_refs._TL_getRootPart      = getRootPart
_TL_refs._TL_getHumanoid      = getHumanoid
_TL_refs._TL_safeStand        = safeStand
_TL_refs._TL_stopBB           = stopBB
_TL_refs._TL_startBB          = startBB
_TL_refs._TL_AF               = _AF
_TL_refs._TL_SOH              = _SOH
_TL_refs._TL_act_stopFollow   = _act_stopFollow
_TL_refs._TL_stopGhost        = stopGhost
_TL_refs._TL_stopSitOnHead    = stopSitOnHead
_TL_refs._TL_stopPiggyback    = stopPiggyback
_TL_refs._TL_stopPiggyback2   = stopPiggyback2
_TL_refs._TL_stopKiss         = stopKiss
_TL_refs._TL_stopBackpack     = stopBackpack
_TL_refs._TL_stopOrbit        = stopOrbit
_TL_refs._TL_stopUpsideDown   = stopUpsideDown
_TL_refs._TL_stopCrossUD      = stopCrossUD
_TL_refs._TL_stopFriend       = stopFriend
_TL_refs._TL_stopSpinning     = stopSpinning
_TL_refs._TL_stopLicking      = stopLicking
_TL_refs._TL_stopSucking      = stopSucking
_TL_refs._TL_stopSuckIt       = stopSuckIt
_TL_refs._TL_stopBackshots    = stopBackshots
_TL_refs._TL_stopLayFuck      = stopLayFuck
_TL_refs._TL_stopFacefuck     = stopFacefuck
_TL_refs._TL_stopPussySpread  = stopPussySpread
_TL_refs._TL_stopHug          = stopHug
_TL_refs._TL_stopHug2         = stopHug2
_TL_refs._TL_stopCarry        = stopCarry
_TL_refs._TL_stopShoulderSit  = stopShoulderSit
end); if not _ok_SmartBar then warn("[TL] SmartBar-IIFE crashed: " .. tostring(_err_SmartBar)) end
end)
local qaStatusDot, qaStatusTxt
task.spawn(function()
local _ok_QABar, _err_QABar = pcall(function()
-- P palette: live references to C.* so theme changes apply to QA cards instantly
local _P_STOP_BG  = Color3.fromRGB(35, 10, 12)
local _P_STOP_BRD = Color3.fromRGB(180, 45, 45)
local _P_STOP_TXT = Color3.fromRGB(224, 72, 72)
local P = setmetatable({}, {
    __index = function(_, k)
        if     k == "panel"    then return C.bg2
        elseif k == "hdr"      then return C.bg3
        elseif k == "hdrBrd"   then return C.sub
        elseif k == "panelBrd" then return C.accent2
        elseif k == "icoBox"   then return C.accent2
        elseif k == "title"    then return C.text
        elseif k == "tgtBg"    then return C.bg2
        elseif k == "tgtBrd"   then return C.borderdim
        elseif k == "tgtTxt"   then return C.sub
        elseif k == "tgtDot"   then return C.accent
        elseif k == "card"     then return C.bg2
        elseif k == "cardHov"  then return C.bg3
        elseif k == "cardBrd"  then return C.borderdim
        elseif k == "cardBrdH" then return C.accent2
        elseif k == "lblOff"   then return C.sub
        elseif k == "lblOn"    then return C.text
        elseif k == "foot"     then return C.bg2
        elseif k == "footBrd"  then return C.borderdim
        elseif k == "stopBg"   then return _P_STOP_BG
        elseif k == "stopBrd"  then return _P_STOP_BRD
        elseif k == "stopTxt"  then return _P_STOP_TXT
        elseif k == "badge"    then return C.bg2
        elseif k == "badgeTxt" then return C.sub
        end
        return nil
    end,
})
-- Use _TL_refs (upvalue) first, fall back to getgenv() for compatibility
local _qag       = _TL_refs
local _qag_env   = (getgenv and getgenv()) or {}
local ScreenGui  = _qag._TL_ScreenGui  or _qag_env._TL_ScreenGui
local tw         = _qag._TL_tw         or _qag_env._TL_tw
local tlHitbox   = _qag._TL_tlHitbox   or _qag_env._TL_tlHitbox
local tlLbl      = _qag._TL_tlLbl      or _qag_env._TL_tlLbl
local tlArrow    = _qag._TL_tlArrow    or _qag_env._TL_tlArrow
local tlArrowBig = _qag._TL_tlArrowBig or _qag_env._TL_tlArrowBig
local FW_W       = _qag._TL_FW_W       or _qag_env._TL_FW_W       or 230
local FW_H       = _qag._TL_FW_H       or _qag_env._TL_FW_H       or 34
local FW_X_OFFSET= _qag._TL_FW_X_OFFSET or _qag_env._TL_FW_X_OFFSET or -5
local VL_ICON_W  = _qag._TL_VL_ICON_W  or _qag_env._TL_VL_ICON_W  or 58
local sendNotif  = _qag._TL_sendNotif  or _qag_env._TL_sendNotif
local getRootPart= _qag._TL_getRootPart or _qag_env._TL_getRootPart
local safeStand  = _qag._TL_safeStand  or _qag_env._TL_safeStand
local _AF        = _qag._TL_AF         or _qag_env._TL_AF
local _SOH       = _qag._TL_SOH        or _qag_env._TL_SOH
local _act_stopFollow  = _qag._TL_act_stopFollow  or _qag_env._TL_act_stopFollow
local stopBB           = _qag._TL_stopBB          or _qag_env._TL_stopBB
local startBB          = _qag._TL_startBB         or _qag_env._TL_startBB
local stopGhost        = _qag._TL_stopGhost       or _qag_env._TL_stopGhost
local stopSitOnHead    = _qag._TL_stopSitOnHead   or _qag_env._TL_stopSitOnHead
local stopPiggyback    = _qag._TL_stopPiggyback   or _qag_env._TL_stopPiggyback
local stopPiggyback2   = _qag._TL_stopPiggyback2  or _qag_env._TL_stopPiggyback2
local stopKiss         = _qag._TL_stopKiss        or _qag_env._TL_stopKiss
local stopBackpack     = _qag._TL_stopBackpack    or _qag_env._TL_stopBackpack
local stopOrbit        = _qag._TL_stopOrbit       or _qag_env._TL_stopOrbit
local stopUpsideDown   = _qag._TL_stopUpsideDown  or _qag_env._TL_stopUpsideDown
local stopCrossUD      = _qag._TL_stopCrossUD     or _qag_env._TL_stopCrossUD
local stopFriend       = _qag._TL_stopFriend      or _qag_env._TL_stopFriend
local stopSpinning     = _qag._TL_stopSpinning    or _qag_env._TL_stopSpinning
local stopLicking      = _qag._TL_stopLicking      or _qag_env._TL_stopLicking
local stopSucking      = _qag._TL_stopSucking      or _qag_env._TL_stopSucking
local stopSuckIt       = _qag._TL_stopSuckIt       or _qag_env._TL_stopSuckIt
local stopBackshots    = _qag._TL_stopBackshots    or _qag_env._TL_stopBackshots
local stopLayFuck      = _qag._TL_stopLayFuck      or _qag_env._TL_stopLayFuck
local stopFacefuck     = _qag._TL_stopFacefuck     or _qag_env._TL_stopFacefuck
local stopPussySpread  = _qag._TL_stopPussySpread  or _qag_env._TL_stopPussySpread
local stopHug          = _qag._TL_stopHug          or _qag_env._TL_stopHug
local stopHug2         = _qag._TL_stopHug2         or _qag_env._TL_stopHug2
local stopCarry        = _qag._TL_stopCarry        or _qag_env._TL_stopCarry
local stopShoulderSit  = _qag._TL_stopShoulderSit  or _qag_env._TL_stopShoulderSit
local _act_following   = false
local ppActive         = false
if not ScreenGui or not tlHitbox then warn("[QA-IIFE] Missing _TL_ refs"); return end
local QA_W      = FW_W
local QA_PAD    = 10
local QA_COLS   = 3
local QA_GAP    = 5
local QA_CW     = math.floor((QA_W - QA_PAD*2 - QA_GAP*2) / QA_COLS)
local QA_CH     = 68
local HDR_H     = 38
local SEC_H     = 20
local FOOT_H    = 30
local SCROLL_MAX= 320
local QA_CATS = {
{
label="Freaky", col=Color3.fromRGB(255,80,160),
actions={
{ key="licking",      label="Licking",      imageId="rbxassetid://72579312094126"  },
{ key="sucking",      label="Sucking",       imageId="rbxassetid://72579312094126"  },
{ key="suck_it",      label="Suck It",       imageId="rbxassetid://72579312094126"  },
{ key="facefuck",     label="Facefuck",      imageId="rbxassetid://72579312094126"  },
{ key="backshots",    label="Backshots",     imageId="rbxassetid://72579312094126"  },
{ key="layfuck",      label="Lay Fuck",      imageId="rbxassetid://72579312094126"  },
{ key="pussyspread",  label="Pussy Spread",  imageId="rbxassetid://72579312094126"  },
{ key="kiss",         label="Kiss",          imageId="rbxassetid://86857269527024"  },
}
},
{
label="Annoying", col=Color3.fromRGB(55,195,255),
actions={
{ key="orbit",      label="Orbit TP",    imageId="rbxassetid://139840976938907"  },
{ key="spinning",   label="Spinning",     imageId="rbxassetid://113740413795794"  },
{ key="upsidedown", label="Upside Down", imageId="rbxassetid://89009236995193"  },
{ key="crossud",    label="Cross UD",    imageId="rbxassetid://77458828386203"  },
{ key="ghost",      label="Ghost",        imageId="rbxassetid://77104113506431"  },
}
},
{
label="Roleplay", col=Color3.fromRGB(255,175,55),
actions={
{ key="soh",         label="On Head",    imageId="rbxassetid://86857269527024"  },
{ key="piggyback",   label="Piggyback",  imageId="rbxassetid://119518980113353" },
{ key="piggyback2",  label="Piggyback2", imageId="rbxassetid://119518980113353" },
{ key="backpack",    label="Backpack",   imageId="rbxassetid://135716031985311" },
{ key="friend",      label="Friend",     imageId="rbxassetid://79735988088948"  },
{ key="hug",         label="Hug",        imageId="rbxassetid://86857269527024"  },
{ key="hug2",        label="Hug 2",      imageId="rbxassetid://86857269527024"  },
{ key="carry",       label="Carry",      imageId="rbxassetid://86857269527024"  },
{ key="shouldersit", label="Shouldersit",imageId="rbxassetid://86857269527024"  },
}
},
{
label="ByteBreaker", col=C.accent2,
actions={
{ key="bb_attach",    label="BB Backshots", imageId="rbxassetid://72579312094126"  },
{ key="bb_orbit",     label="BB Orbit",     imageId="rbxassetid://139840976938907"  },
{ key="bb_copy",      label="BB Copy",      imageId="rbxassetid://106434334096506" },
{ key="bb_piggyback", label="BB Piggyback", imageId="rbxassetid://119518980113353" },
{ key="bb_piggyback2",label="BB Piggy 2",   imageId="rbxassetid://119518980113353" },
{ key="bb_carry",     label="BB Carry",     imageId="rbxassetid://86857269527024"  },
{ key="bb_carry2",    label="BB Carry 2",   imageId="rbxassetid://86857269527024"  },
{ key="bb_hug",       label="BB Hug",       imageId="rbxassetid://86857269527024"  },
{ key="bb_hug2",      label="BB Hug 2",     imageId="rbxassetid://86857269527024"  },
{ key="bb_layfuck",   label="BB LayFuck",   imageId="rbxassetid://72579312094126"  },
{ key="bb_licking",   label="BB Licking",   imageId="rbxassetid://72579312094126"  },
{ key="bb_bangv2",    label="BB BangV2",    imageId="rbxassetid://72579312094126"  },
{ key="bb_behind",    label="BB Behind",    imageId="rbxassetid://72579312094126"  },
{ key="bb_headsit",   label="BB Headsit",   imageId="rbxassetid://86857269527024"  },
}
},
}
local QA_ACTIONS = {}
for _, cat in ipairs(QA_CATS) do
for _, a in ipairs(cat.actions) do
a.catCol = cat.col; QA_ACTIONS[#QA_ACTIONS+1] = a
end
end
local qaBarOpen      = false
local qaActiveKey    = nil
local qaActiveTarget = nil
local qaCardRefs     = {}
local _qaNoSitConn   = nil  -- verhindert Hinsetzen während QA-Action läuft
local _qaGlobalLock  = false  -- verhindert Race beim schnellen Doppelklick verschiedener Karten

local function _qaStopNoSit()
	if _qaNoSitConn then
		pcall(function() _qaNoSitConn:Disconnect() end)
		_qaNoSitConn = nil
	end
end

local function _qaStartNoSit()
	_qaStopNoSit()
	-- Cache character + humanoid; only re-lookup on character change (avoids per-frame FindFirstChildOfClass)
	local _nsChar = nil
	local _nsHum  = nil
	_qaNoSitConn = RunService.Heartbeat:Connect(function()
		local char = LocalPlayer.Character
		if not char then return end
		if char ~= _nsChar then
			_nsChar = char
			_nsHum  = char:FindFirstChildOfClass("Humanoid")
		end
		local hum = _nsHum
		if not hum then return end
		-- Only write Sit=false when it's actually true (avoids unnecessary property write every frame)
		if hum.Sit then
			hum.Sit = false
		end
		-- Only jump when actually seated (avoids property read overhead when not needed)
		if hum.SeatPart then
			pcall(function() hum.Jump = true end)
		end
	end)
end

local function stopQAAction()
_qaStopNoSit()
if _G.TLActionsStop then pcall(_G.TLActionsStop)
elseif _G.TLActions  then pcall(function() _G.TLActions.stopAll() end) end
pcall(function()
local _af = _AF or {}  -- nil-guard: _AF may be nil on first run / before refs are ready
if _act_following        then _act_stopFollow();   _act_following        = false end
if _SOH and _SOH.active  then stopSitOnHead();     _SOH.active           = false end
if ppActive              then stopPiggyback();      ppActive              = false end
if _af.pp2Active         then stopPiggyback2();     _af.pp2Active         = false end
if _af.kissActive        then stopKiss();           _af.kissActive        = false end
if _af.backpackActive    then stopBackpack();       _af.backpackActive    = false end
if _af.orbitActive       then stopOrbit();          _af.orbitActive       = false end
if _af.upsideDownActive  then stopUpsideDown();     _af.upsideDownActive  = false end
if _af.crossUDActive     then stopCrossUD();        _af.crossUDActive     = false end
if _af.friendActive      then stopFriend();         _af.friendActive      = false end
if _af.spinningActive    then stopSpinning();       _af.spinningActive    = false end
if _af.lickingActive     then stopLicking();        _af.lickingActive     = false end
if _af.suckingActive     then stopSucking();        _af.suckingActive     = false end
if _af.suckItActive      then stopSuckIt();         _af.suckItActive      = false end
if _af.backshotsActive   then stopBackshots();      _af.backshotsActive   = false end
if _af.layFuckActive     then stopLayFuck();        _af.layFuckActive     = false end
if _af.facefuckActive    then stopFacefuck();       _af.facefuckActive    = false end
if _af.pussySpreadActive then stopPussySpread();    _af.pussySpreadActive = false end
if _af.hugActive         then stopHug();            _af.hugActive         = false end
if _af.hug2Active        then stopHug2();           _af.hug2Active        = false end
if _af.carryActive       then stopCarry();          _af.carryActive       = false end
if _af.shoulderSitActive then stopShoulderSit();    _af.shoulderSitActive = false end
if _af.bbActive          then stopBB();             _af.bbActive          = false end
if _af.ghostActive       then stopGhost();          _af.ghostActive       = false end
if _af.qa74Active        then pcall(stopQA74);      _af.qa74Active        = false end
pcall(safeStand)
end)
qaActiveKey = nil; qaActiveTarget = nil
end
local function activateQAAction(key)
local target = getNearestPlayer()
if not target then sendNotif("QuickActions","Kein Spieler in der Nähe!",2); return false end
stopQAAction()
qaActiveKey = key; qaActiveTarget = target
_qaStartNoSit()
local _capturedKey    = key
local _capturedTarget = target
task.spawn(function()
task.wait(0.05)
if qaActiveKey ~= _capturedKey then return end  -- abgebrochen bevor Spawn lief
if _capturedKey:sub(1,3)=="bb_" then startBB(_capturedTarget, _capturedKey)
elseif _G.TLActions    then _G.TLActions.start(_capturedKey, _capturedTarget) end
end)
return true
end
local function mkF(parent, sz, pos, col, alpha, r)
local f = Instance.new("Frame")
f.Size=sz; f.Position=pos; f.BackgroundColor3=col
f.BackgroundTransparency=alpha; f.BorderSizePixel=0
if r then local c=Instance.new("UICorner",f); c.CornerRadius=UDim.new(0,r) end
f.Parent=parent
return f
end
local function mkTxt(parent, sz, pos, text, font, tsz, col, xAlign)
local l=Instance.new("TextLabel")
l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Text=text
l.Font=font; l.TextSize=tsz; l.TextColor3=col
l.TextXAlignment=xAlign or Enum.TextXAlignment.Left
l.TextTruncate=Enum.TextTruncate.AtEnd
l.Parent=parent
return l
end
local function mkStroke(parent, thick, col, alpha)
local s=_makeDummyStroke(parent)
s.Thickness=thick; s.Color=col; s.Transparency=alpha
s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s
end
-- qaBar: unterhalb fpsWidget, rechts bündig mit SmartBar
-- SmartBar right edge = screenW - 5  (AnchorPoint 1,0 → offset = -5)
-- qaBar Y = SmartBar top(5) + SmartBar height(VL_ICON_H=58) + gap(4) + fpsWidget height(FW_H=34) + gap(4) = 105
local _QA_RIGHT_OFFSET = -5   -- bündig mit SmartBar rechter Kante
local _VL_ICON_H = (_qag._TL_VL_ICON_H or _qag_env._TL_VL_ICON_H or 58)
local _QA_TOP_Y = 5 + _VL_ICON_H + 4  -- unterhalb SmartBar (fpsWidget ist jetzt daneben)
local qaBar = mkF(ScreenGui,
UDim2.new(0,QA_W,0,0),
UDim2.new(1, _QA_RIGHT_OFFSET, 0, _QA_TOP_Y),
P.panel, 0, 8)
qaBar.Name="TLQuickActionsBar"
qaBar.AnchorPoint=Vector2.new(1,0)
qaBar.ClipsDescendants=true
qaBar.Visible=false; qaBar.ZIndex=9
-- Register for drag system
pcall(function() if getgenv then _genv._TL_qaBar = qaBar end end)
pcall(function() _TL_refs._TL_qaBar = qaBar end)
local _qaBarStroke = mkStroke(qaBar, 1, P.panelBrd, 0.7)
-- Mobile/Tablet: reposition and scale QA bar
do
    local _ok, _vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp = _ok and _vp or Vector2.new(1920,1080)
    local _touch = pcall(function() return _SvcUIS.TouchEnabled end)
              and _SvcUIS.TouchEnabled
    local _kbd   = pcall(function() return _SvcUIS.KeyboardEnabled end)
              and _SvcUIS.KeyboardEnabled
    local _short = math.min(_vp.X, _vp.Y)
    local _isMob = _touch and not _kbd and _short < 500
    local _isTab = _touch and not _kbd and _short >= 500
    if _isMob or _isTab then
        local _qaScale = Instance.new("UIScale", qaBar)
        _qaScale.Scale = _TL_VP.mobScl  -- zentraler Scale aus _TL_VP
        qaBar.AnchorPoint = Vector2.new(1, 0)
        qaBar.Position    = UDim2.new(1, _QA_RIGHT_OFFSET, 0, _QA_TOP_Y)
    end
end
local hdr = mkF(qaBar, UDim2.new(1,0,0,HDR_H),
UDim2.new(0,0,0,0), P.hdr, 0, 14)
hdr.ZIndex=10
mkF(hdr, UDim2.new(1,0,0,14), UDim2.new(0,0,1,-14), P.hdr, 0, 0)
mkF(qaBar, UDim2.new(1,0,0,1), UDim2.new(0,0,0,HDR_H), P.hdrBrd, 0.75, 0).ZIndex=9
local icoBox = mkF(hdr, UDim2.new(0,22,0,22), UDim2.new(0,8,0.5,-11), P.icoBox, 1, 4)
local icoLbl = Instance.new("ImageLabel", icoBox)
icoLbl.Size                   = UDim2.new(1,0,1,0)
icoLbl.Position               = UDim2.new(0,0,0,0)
icoLbl.BackgroundTransparency = 1
icoLbl.Image                  = "rbxassetid://77458828386203"
icoLbl.ImageColor3            = Color3.new(1,1,1)
icoLbl.ScaleType              = Enum.ScaleType.Fit
icoLbl.ZIndex                 = 12
local titleLbl = mkTxt(hdr, UDim2.new(0,125,0,18), UDim2.new(0,32,0.5,-9),
"Quick Actions", Enum.Font.GothamBlack, 13, Color3.new(1,1,1))
titleLbl.ZIndex=12; titleLbl.TextXAlignment=Enum.TextXAlignment.Left
local tgtBadge = mkF(hdr, UDim2.new(0,90,0,18), UDim2.new(1,-98,0.5,-9), P.tgtBg, 0.1, 20)
local _tgtBadgeStroke = mkStroke(tgtBadge, 1.5, C.accent2, 0); tgtBadge.ZIndex=11
local tgtDot = mkF(tgtBadge, UDim2.new(0,5,0,5), UDim2.new(0,6,0.5,-2), P.tgtDot, 0, 99)
tgtDot.ZIndex=13
local tgtNameLbl = mkTxt(tgtBadge, UDim2.new(1,-16,1,0), UDim2.new(0,14,0,0),
"◈", Enum.Font.GothamBold, 9, Color3.new(1,1,1), Enum.TextXAlignment.Left)
tgtNameLbl.ZIndex=12
task.spawn(function()
local _tdTw = nil
while qaBar and qaBar.Parent and _tlAlive() do
if qaBar.Visible then
if _tdTw then pcall(_tdTw.Cancel, _tdTw) end
_tdTw = tw(tgtDot,0.8,{BackgroundTransparency=0.6}); _tdTw:Play()
task.wait(1.7)
if _tdTw then pcall(_tdTw.Cancel, _tdTw) end
_tdTw = tw(tgtDot,0.8,{BackgroundTransparency=0}); _tdTw:Play()
task.wait(1.7)
else
task.wait(0.5)
end
end
end)
local BODY_TOP = HDR_H + 1
local INNER_W  = QA_W - QA_PAD*2
local qaScroll = Instance.new("ScrollingFrame", qaBar)
qaScroll.Position               = UDim2.new(0, QA_PAD, 0, BODY_TOP + QA_PAD)
qaScroll.BackgroundTransparency = 1; qaScroll.BorderSizePixel = 0
qaScroll.ScrollBarThickness     = 2
qaScroll.ScrollBarImageColor3   = P.panelBrd
qaScroll.ScrollBarImageTransparency = 0.5
qaScroll.ScrollingDirection     = Enum.ScrollingDirection.Y
qaScroll.CanvasSize             = UDim2.new(0,0,0,0)
qaScroll.ElasticBehavior        = Enum.ElasticBehavior.Never
qaScroll.ClipsDescendants       = true; qaScroll.ZIndex = 10
-- Forward-declare so the theme-change hook closure below captures these as upvalues
-- (locals declared AFTER a closure is defined are not visible to it in Lua)
local _footStroke    = nil
local _stopBtnStroke = nil
-- Theme-change hook: reapply all card strokes + scroll bar color immediately
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function(_newT)
    pcall(function() qaScroll.ScrollBarImageColor3 = P.panelBrd end)
    pcall(function() if _qaBarStroke    then _qaBarStroke.Color    = P.panelBrd end end)
    pcall(function() if _tgtBadgeStroke then _tgtBadgeStroke.Color = C.accent2  end end)
    pcall(function() if _footStroke     then _footStroke.Color     = P.footBrd  end end)
    pcall(function() if _stopBtnStroke  then _stopBtnStroke.Color  = P.stopBrd  end end)
    pcall(function() if tgtDot          then tgtDot.BackgroundColor3 = P.tgtDot end end)
    for _, r in ipairs(qaCardRefs) do
        pcall(function()
            if qaActiveKey == r.key then
                r.stroke.Color = r.col; r.stroke.Transparency = 0.6
            else
                r.stroke.Color = P.cardBrd; r.stroke.Transparency = 0.5
            end
        end)
    end
end
local function resetAllCards()
for _, r in ipairs(qaCardRefs) do pcall(function()
twP(r.bg,  .12, {BackgroundColor3=P.card, BackgroundTransparency=0})
twP(r.lbl, .12, {TextColor3=P.lblOff})
twP(r.bar, .12, {BackgroundTransparency=1})
r.stroke.Color=P.cardBrd; r.stroke.Transparency=0.5
end) end
end
local curY = 0
for _, cat in ipairs(QA_CATS) do
if curY > 0 then curY = curY + 4 end
local secRow = mkF(qaScroll, UDim2.new(0,INNER_W,0,SEC_H),
UDim2.new(0,0,0,curY), P.panel, 1, 0)
secRow.ZIndex=11
local secBar = mkF(secRow, UDim2.new(0,4,0,14), UDim2.new(0,0,0.5,-7), cat.col, 0, 99)
secBar.ZIndex=12
local secName = mkTxt(secRow, UDim2.new(1,-36,1,0), UDim2.new(0,14,0,0),
cat.label:upper(), Enum.Font.GothamBlack, 10, cat.col)
secName.ZIndex=12; secName.TextXAlignment=Enum.TextXAlignment.Left
local badge = mkF(secRow, UDim2.new(0,24,0,14), UDim2.new(1,-26,0.5,-7), cat.col, 0.82, 99)
badge.ZIndex=12
local badgeTxt = mkTxt(badge, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
tostring(#cat.actions), Enum.Font.GothamBlack, 10, cat.col, Enum.TextXAlignment.Center)
badgeTxt.ZIndex=13
curY = curY + SEC_H + 5
local rowStartY = curY
for ci, act in ipairs(cat.actions) do
local col_i = (ci-1) % QA_COLS
local row_i = math.floor((ci-1) / QA_COLS)
local xPos  = col_i * (QA_CW + QA_GAP)
local yPos  = rowStartY + row_i * (QA_CH + QA_GAP)
local bg = mkF(qaScroll, UDim2.new(0,QA_CW,0,QA_CH),
UDim2.new(0,xPos,0,yPos), P.card, 0, 8)
bg.ZIndex=11
local stroke = mkStroke(bg, 1, P.cardBrd, 0.5)
local bar = mkF(bg, UDim2.new(0,QA_CW-12,0,2),
UDim2.new(0,6,1,-2), cat.col, 1, 99)
bar.ZIndex=13
local icoL
if act.imageId then
icoL = Instance.new("ImageLabel", bg)
icoL.Size=UDim2.new(0,30,0,30); icoL.Position=UDim2.new(0.5,-15,0,8)
icoL.BackgroundTransparency=1; icoL.Image=act.imageId
icoL.ImageColor3=Color3.new(1,1,1); icoL.ImageTransparency=0
icoL.ScaleType=Enum.ScaleType.Fit; icoL.ZIndex=12
else
icoL = mkTxt(bg, UDim2.new(1,0,0,30), UDim2.new(0,0,0,8),
act.icon, Enum.Font.GothamBold, 20, Color3.new(1,1,1), Enum.TextXAlignment.Center)
icoL.ZIndex=12
end
local lbl = mkTxt(bg, UDim2.new(1,-2,0,12), UDim2.new(0,1,1,-14),
act.label, Enum.Font.GothamBlack, 11, P.lblOff, Enum.TextXAlignment.Center)
lbl.ZIndex=12
local btn = Instance.new("TextButton", bg)
btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
btn.Text=""; btn.ZIndex=15; btn.Active=true
local ci2 = #qaCardRefs+1
qaCardRefs[ci2] = {bg=bg, lbl=lbl, bar=bar, stroke=stroke, key=act.key, col=cat.col}
btn.MouseEnter:Connect(function()
if _isMobile then return end
_playHoverSound()
if qaActiveKey==act.key then return end
twP(bg, .1, {BackgroundColor3=P.cardHov})
stroke.Color=P.cardBrdH; stroke.Transparency=0.5
end)
btn.MouseLeave:Connect(function()
if qaActiveKey==act.key then return end
twP(bg, .1, {BackgroundColor3=P.card})
stroke.Color=P.cardBrd; stroke.Transparency=0.5
end)
local _cardLock = false   -- per-Karte-Lock: blockiert verzögerten zweiten Touch-Event
local function qaCardActivate()
if _qaGlobalLock or _cardLock then return end
_qaGlobalLock = true
_cardLock     = true
task.delay(0.35, function() _qaGlobalLock = false end)
task.delay(0.7,  function() _cardLock     = false end)
local wasActive = (qaActiveKey==act.key)
resetAllCards()
if wasActive then
stopQAAction()
if qaStatusTxt then qaStatusTxt.Text="Stopped"; qaStatusTxt.TextColor3=P.tgtTxt end
if qaStatusDot then qaStatusDot.BackgroundColor3=P.tgtTxt end
else
local ok = activateQAAction(act.key)
if ok ~= false then
twP(bg,  .12, {BackgroundColor3=P.cardHov})
twP(lbl, .12, {TextColor3=P.lblOn})
twP(bar, .12, {BackgroundTransparency=0})
stroke.Color=cat.col; stroke.Transparency=0.6
task.spawn(function()
task.wait(0.2); pcall(function()
local tgt=qaActiveTarget
if qaStatusTxt then
qaStatusTxt.Text=act.label..(tgt and(" → "..tgt.Name)or"")
qaStatusTxt.TextColor3=cat.col
end
if qaStatusDot then qaStatusDot.BackgroundColor3=cat.col end
end)
end)
else
if qaStatusTxt then qaStatusTxt.Text="◈ Kein Ziel"; qaStatusTxt.TextColor3=P.stopTxt end
if qaStatusDot then qaStatusDot.BackgroundColor3=P.stopTxt end
end
end
end
btn.MouseButton1Click:Connect(qaCardActivate)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then qaCardActivate() end
end)
if act.key == "sucking" then
local function qaSuckPause()
    if qaActiveKey=="sucking" and _AF and _AF.suckingActive then
        pcall(function() if _G._TLSuckingTrack then _G._TLSuckingTrack:AdjustSpeed(0) end end)
    end
end
local function qaSuckResume()
    if qaActiveKey=="sucking" and _AF and _AF.suckingActive then
        pcall(function() if _G._TLSuckingTrack then _G._TLSuckingTrack:AdjustSpeed(1) end end)
    end
end
btn.MouseButton1Down:Connect(qaSuckPause)
btn.MouseButton1Up:Connect(qaSuckResume)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then qaSuckPause() end
end)
btn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then qaSuckResume() end
end)
end
end
local rows = math.ceil(#cat.actions / QA_COLS)
curY = rowStartY + rows*(QA_CH+QA_GAP) + 6
end
local TOTAL_H  = curY
local SCROLL_H = math.min(TOTAL_H, SCROLL_MAX)
qaScroll.Size       = UDim2.new(0, INNER_W, 0, SCROLL_H)
qaScroll.CanvasSize = UDim2.new(0, 0, 0, TOTAL_H)
local FOOT_Y   = BODY_TOP + QA_PAD + SCROLL_H + 4
local FULL_H   = FOOT_Y + FOOT_H + QA_PAD
local foot = mkF(qaBar, UDim2.new(0,INNER_W,0,FOOT_H),
UDim2.new(0,QA_PAD,0,FOOT_Y), P.foot, 0, 8)
foot.ZIndex=10; _footStroke = mkStroke(foot, 1, P.footBrd, 0.2)
qaStatusDot = mkF(foot, UDim2.new(0,5,0,5), UDim2.new(0,9,0.5,-2), P.tgtTxt, 0, 99)
qaStatusDot.ZIndex=12
task.spawn(function()
local _sdTw = nil
while foot and foot.Parent and _tlAlive() do
if qaBar and qaBar.Visible then
if _sdTw then pcall(_sdTw.Cancel, _sdTw) end
_sdTw = tw(qaStatusDot,0.7,{BackgroundTransparency=0.6}); _sdTw:Play()
task.wait(1.5)
if _sdTw then pcall(_sdTw.Cancel, _sdTw) end
_sdTw = tw(qaStatusDot,0.7,{BackgroundTransparency=0}); _sdTw:Play()
task.wait(1.5)
else
task.wait(0.5)
end
end
end)
qaStatusTxt = mkTxt(foot, UDim2.new(1,-58,1,0), UDim2.new(0,20,0,0),
"Idle – Select an action", Enum.Font.GothamBold, 11, P.tgtTxt)
qaStatusTxt.ZIndex=12
local stopBtn = Instance.new("TextButton", foot)
stopBtn.Size=UDim2.new(0,38,0,20); stopBtn.Position=UDim2.new(1,-42,0.5,-10)
stopBtn.BackgroundColor3=P.stopBg; stopBtn.BackgroundTransparency=0.1
stopBtn.BorderSizePixel=0; stopBtn.Text="STOP"
stopBtn.Font=Enum.Font.GothamBlack; stopBtn.TextSize=7
stopBtn.TextColor3=P.stopTxt; stopBtn.ZIndex=13; stopBtn.Active=true
do local c=Instance.new("UICorner",stopBtn); c.CornerRadius=UDim.new(0,5) end
_stopBtnStroke = mkStroke(stopBtn, 1, P.stopBrd, 0.6)
stopBtn.MouseEnter:Connect(function()
_playHoverSound()
twP(stopBtn,.1,{BackgroundColor3=Color3.fromRGB(55,14,18)})
end)
stopBtn.MouseLeave:Connect(function()
twP(stopBtn,.1,{BackgroundColor3=P.stopBg})
end)
local function qaDoStop()
resetAllCards(); stopQAAction()
if qaStatusTxt then qaStatusTxt.Text="Stopped"; qaStatusTxt.TextColor3=P.tgtTxt end
if qaStatusDot then qaStatusDot.BackgroundColor3=P.tgtTxt end
end
stopBtn.MouseButton1Click:Connect(qaDoStop)
stopBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then qaDoStop() end
end)
local qaBarTween = nil
local function openQABar()
if qaBarTween then pcall(function() qaBarTween:Cancel() end); qaBarTween=nil end
closeBar()
local np = getNearestPlayer()
tgtNameLbl.Text = np and np.Name or "?"
tgtDot.BackgroundColor3 = np and P.tgtDot or P.tgtTxt
qaBarOpen=true; qaBar.Visible=true
qaBar.Size=UDim2.new(0,QA_W,0,0)
qaBarTween=tw(qaBar,.28,{Size=UDim2.new(0,QA_W,0,FULL_H)},
Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
qaBarTween:Play()
tlArrow.Text                 = "»"
end
local function closeQABar()
if qaBarTween then pcall(function() qaBarTween:Cancel() end); qaBarTween=nil end
qaBarOpen=false; tlArrow.Text                 = "»"
qaBarTween=tw(qaBar,.2,{Size=UDim2.new(0,QA_W,0,0)},
Enum.EasingStyle.Quart,Enum.EasingDirection.In)
qaBarTween:Play()
qaBarTween.Completed:Connect(function()
if not qaBarOpen then qaBar.Visible=false end
end)
end
_TL_refs._TL_closeQABar = closeQABar
-- -- Rechtes TL-Logo: QABar öffnen/schließen ------------------------
local _tlHitboxLock = false
local function tlHitboxActivate()
    if _tlHitboxLock then return end
    _tlHitboxLock = true
    task.delay(0.3, function() _tlHitboxLock = false end)
    if qaBarOpen then closeQABar() else openQABar() end
end
-- MouseButton1Click deckt Maus ab; InputBegan deckt Touch ab
-- globaler UIS-Fallback entfernt (verursachte dreifaches Feuern auf Touch → Crash)
tlHitbox.MouseButton1Click:Connect(tlHitboxActivate)
tlHitbox.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then tlHitboxActivate() end
end)
tlHitbox.MouseEnter:Connect(function()
_playHoverSound()
    twP(tlLbl,  .1,{ImageTransparency=0.3})
    twP(tlArrow,.1,{TextTransparency =0.3})
end)
tlHitbox.MouseLeave:Connect(function()
    twP(tlLbl,  .1,{ImageTransparency=0})
    twP(tlArrow,.1,{TextTransparency =0})
end)
tlArrow.Text                 = "»"
tlArrowBig.Text                 = "»"
end); if not _ok_QABar then warn("[TL] QABar-IIFE crashed: " .. tostring(_err_QABar)) end
end)
local function TLMenuCleanup()
pcall(function()
if getgenv and getgenv()._TL_AntiVoidStop then pcall(getgenv()._TL_AntiVoidStop); getgenv()._TL_AntiVoidStop = nil end
end)
pcall(function()
if keybindMainConn then pcall(function() keybindMainConn:Disconnect() end); keybindMainConn = nil end
end)
pcall(function()
if _G.TLActionsStop then _G.TLActionsStop() end
end)
pcall(function()
if getgenv and getgenv()._TLAllConns then
for _, c in ipairs(_genv._TLAllConns) do
pcall(function() c:Disconnect() end)
end
_genv._TLAllConns = nil
end
end)
pcall(function()
if getgenv and getgenv()._TLAllInsts then
for _, obj in ipairs(_genv._TLAllInsts) do
pcall(function()
if obj and obj.Parent then obj:Destroy() end
end)
end
_genv._TLAllInsts = nil
end
end)
pcall(function()
if getgenv and getgenv()._TLAnimConns then
for _, c in ipairs(_genv._TLAnimConns) do
pcall(function() c:Disconnect() end)
end
_genv._TLAnimConns = nil
end
end)
pcall(function()
if getgenv and getgenv()._TLFlingConn then
_genv._TLFlingConn:Disconnect()
_genv._TLFlingConn = nil
end
end)
local _conns = {
flyConn, noclipConn, _espRadConn, gbConn,
rushConn, rushNoclipConn, updateConnUI,
_act_followRSConn, _SOH and _SOH.conn,
_AF and _AF.udConn,
friendConn, spinConn, ppConn, pp2Conn,
kissConn, bpConn, lickingConn, suckingConn,
facefuckConn, backshotsConn, psConn, hugConn,
carryConn, ssConn, qa74Conn, orbitConn,
ghostConn, bbConn, bbRespConn, bbRemConn,
bbAnimConn_, bbAnimConn2_, bbAnimConn3_,
bbAnimConn4_, bbAnimConn5_, bbAnimConn6_, bbAnimConn7_,
bbAnimConn8_, bbAnimConn9_, bbAnimConn10_, bbHealthConn_,
bbRespAnimConn_,
invisHeartConn, invisRenderConn, invisSteppedConn,
orbitTargetRespConn, ghostRespConn,
ppCharConn, pp2CharConn, kissCharConn, bpCharConn,
lickingCharConn, suckItCharConn, suckingCharConn,
facefuckCharConn, backshotsCharConn, layFuckCharConn,
psCharConn, hugCharConn, hug2CharConn, carryCharConn,
ssCharConn, qa74CharConn, avCharConn, _ui_charConn_,
cursorSyncConn, fxConn, antiRagdollConnection,
tfConn, AimbotConnection, TriggerBotConnection,
_ctHoverConn, _qaNoSitConn, _dhAimConn,
_dhPickConn, _dhFlyConn, _dhNoclipConn,
_mm2FlyConn, _mm2NoclipConn,
}
for _, c in ipairs(_conns) do
if c then pcall(function() c:Disconnect() end) end
end
bbAnimConn_  = nil; bbAnimConn2_ = nil; bbAnimConn3_ = nil
bbAnimConn4_ = nil; bbAnimConn5_ = nil; bbAnimConn6_ = nil
bbAnimConn7_ = nil; bbAnimConn8_ = nil; bbAnimConn9_ = nil
bbAnimConn10_ = nil; bbHealthConn_ = nil; bbRespAnimConn_ = nil
pcall(function()
if flyBodyVel  then flyBodyVel:Destroy();  flyBodyVel  = nil end
if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
flyActive = false
_flyMuteSounds(false)
if _invisHL and _invisHL.Parent then _invisHL:Destroy(); _invisHL = nil end
end)
pcall(function() if stopBB then stopBB() end end)
pcall(function()
if _G._TLCursorRSConn then pcall(function() _G._TLCursorRSConn:Disconnect() end); _G._TLCursorRSConn = nil end
if _G._TLCursorGui and _G._TLCursorGui.Parent then _G._TLCursorGui:Destroy(); _G._TLCursorGui = nil end
pcall(function() _SvcUIS.MouseIconEnabled = true end)
end)
pcall(function()
local lp = _SvcPlr.LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")
if pg then
for _, n in ipairs({"SmartBarGui", "MatrixTrackerGUI"}) do
local g = pg:FindFirstChild(n); if g then g:Destroy() end
end
end
local ok, cg = pcall(function() return game:GetService("CoreGui") end)
if ok and cg then
for _, n in ipairs({"SmartBarGui", "MatrixTrackerGUI"}) do
local gx = cg:FindFirstChild(n); if gx then gx:Destroy() end
end
end
if gethui then pcall(function()
local hui = gethui()
for _, n in ipairs({"SmartBarGui", "MatrixTrackerGUI"}) do
local g = hui:FindFirstChild(n); if g then g:Destroy() end
end
end) end
if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
end)
pcall(function()
if _espGui and _espGui.Parent then _espGui:Destroy(); _espGui = nil end
end)
pcall(function()
if _hoverSoundObj then _hoverSoundObj:Destroy(); _hoverSoundObj = nil end
end)
pcall(function()
local ew = game:GetService("CoreGui")
.RobloxGui.EmotesMenu.Children.Main.EmotesWheel
for _, n in ipairs({"Under","Top"}) do
local el = ew:FindFirstChild(n)
if el then el:Destroy() end
end
end)
pcall(function()
if getgenv and getgenv()._TLRemoveTool then
_genv._TLRemoveTool()
_genv._TLRemoveTool = nil
end
end)
pcall(function()
if getgenv and getgenv()._TLInvPatchCleanup then
_genv._TLInvPatchCleanup()
_genv._TLInvPatchCleanup = nil
end
end)
_G.EmotesGUIRunning  = nil
_G.TLActions         = nil
_G.TLActionsStop     = nil
pcall(function()
if getgenv then
_genv._TL_AntiVoidStop = nil
_genv.TLMenuCleanup    = nil
_genv.TLUnload         = nil
_genv.SmartBarLoaded   = nil
_genv.TLSendNotif      = nil
_genv.TLAnimFreeze     = nil
_genv.lastPlayedAnimation = nil
_genv.autoReloadEnabled   = nil
end
end)
_G.TLMenuCleanup = nil
end
pcall(function()
local env = getgenv and getgenv() or _G
env.TLMenuCleanup = TLMenuCleanup
env.TLUnload = TLMenuCleanup
end)
_G.TLMenuCleanup = TLMenuCleanup
end)()



