if not task then
task = {
wait  = function(t) return wait(t or 0) end,
spawn = function(f, ...)
local args = {...}
local co = coroutine.create(function() return f(table.unpack(args)) end)
local ok, err = coroutine.resume(co)
if not ok then pcall(warn, "[task.spawn] "..tostring(err)) end
return co
end,
delay = function(t, f, ...) delay(t, f) end,
defer = function(f, ...)
local args = {...}
local co = coroutine.create(function() return f(table.unpack(args)) end)
coroutine.resume(co)
return co
end,
}
end
if not getgenv then
getgenv = function() return _G end
end
-- ── Localized stdlib for hot-path performance ──────────────
local _msin    = math.sin
local _mcos    = math.cos
local _mfloor  = math.floor
local _mabs    = math.abs
local _mrad    = math.rad
local _mrandom = math.random
local _V3new   = Vector3.new
local _CFnew   = CFrame.new
local _CFlookAt = CFrame.lookAt
if not writefile then
writefile = function() end
end
if not readfile then
readfile = function() return nil end
end
if not isfile then
isfile = function() return false end
end
-- ════════════════════════════════════════════════════════════════
--  PERFORMANCE OPTIMISATIONS
--  · Localized math.*/Vector3/CFrame at file top
--  · _getTI nested-table cache (no string concat per tween)
--  · twP(): create+play in one call
--  · _tlAlive() caches env table
--  · BB loop: AssemblyLinearVelocity + AssemblyAngularVelocity reset every frame (pre-branch, zero alloc)
--  · Ghost/BB/Invis loops: conditional property writes
--  · Fly loop: cached cam CFrame
--  · Orbit: _workspace, guard CameraType, localized math
--  · FPS widget: no pcall, cached color
--  · Ping: cached Stats service
--  · Shimmer: *0.25, index loops, reuse Vector2
--  · Circle segments: cached XYZ, localized math
--  · Noclip/RushNoclip: early exit
--  · CFrame.Angles constants cached (_CF_ROT180Y, _CF_SUCK_ROT)
--  · Vector3.zero → _V3_ZERO in velocity resets
--  · ESP acc → _espAcc (global leak fixed)
--  · tick() → os.clock()
-- ════════════════════════════════════════════════════════════════

local function _TL_SendKey(keyCode, down)
local ok1 = pcall(function()
game:GetService("VirtualInputManager"):SendKeyEvent(down, keyCode, false, game)
end)
if ok1 then return end
if down then
pcall(function()
if keypress then keypress(keyCode.Value) end
end)
else
pcall(function()
if keyrelease then keyrelease(keyCode.Value) end
end)
end
end
pcall(function()
local FILE = "TLMenuV2.lua"
if not getgenv()._TLSourceSaved then
pcall(function()
if writefile then
local src = nil
pcall(function()
if getgenv()._TLScriptSource then
src = getgenv()._TLScriptSource
end
end)
pcall(function()
if not src and script then
src = game:GetService("ScriptEditorService") and nil
or (rawget(script,"Source") or script.Source)
end
end)
if src and #src > 500 then
writefile(FILE, src)
getgenv()._TLSourceSaved = true
end
end
end)
end
if not getgenv()._TLScriptSource then
pcall(function()
if readfile and isfile and isfile(FILE) then
local s = readfile(FILE)
if s and #s > 500 then getgenv()._TLScriptSource = s end
end
end)
end
if not getgenv()._TLAutoReinject then
getgenv()._TLAutoReinject = true
task.spawn(function()
local lastJob = tostring(game.JobId)
while true do
task.wait(0.8)
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
src = getgenv()._TLScriptSource
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
end)
if getgenv then
getgenv()._TLSessionToken = (getgenv()._TLSessionToken or 0) + 1
end
if not getgenv and _G then
_G._TLSessionToken = (_G._TLSessionToken or 0) + 1
end
local _MY_TOKEN = (getgenv and getgenv()._TLSessionToken)
or (_G and _G._TLSessionToken)
or 1
local _tlEnv = (getgenv ~= nil and getgenv()) or _G or {}
local function _tlAlive()
    return (_tlEnv._TLSessionToken == nil) or (_tlEnv._TLSessionToken == _MY_TOKEN)
end
pcall(function()
local env = getgenv and getgenv() or _G
if env and env.TLUnload then pcall(env.TLUnload) end
end)
pcall(function()
if getgenv()._TLAnimConns then
for _, c in ipairs(getgenv()._TLAnimConns) do pcall(function() c:Disconnect() end) end
getgenv()._TLAnimConns = nil
end
if getgenv()._TLAllConns then
for _, c in ipairs(getgenv()._TLAllConns) do pcall(function() c:Disconnect() end) end
getgenv()._TLAllConns = nil
end
if getgenv()._TLFlingConn then
pcall(function() getgenv()._TLFlingConn:Disconnect() end)
getgenv()._TLFlingConn = nil
end
end)
_G.EmotesGUIRunning = nil
pcall(function()
local ew = game:GetService("CoreGui").RobloxGui.EmotesMenu.Children.Main.EmotesWheel
for _, n in ipairs({"Under","Top"}) do
local el = ew:FindFirstChild(n); if el then el:Destroy() end
end
end)
pcall(function()
local lp = game:GetService("Players").LocalPlayer
local pg = lp:FindFirstChild("PlayerGui")
if pg then
local g = pg:FindFirstChild("SmartBarGui"); if g then g:Destroy() end
local g3 = pg:FindFirstChild("MatrixTrackerGUI"); if g3 then g3:Destroy() end
end
local ok, cg = pcall(function() return game:GetService("CoreGui") end)
if ok and cg then
local g2 = cg:FindFirstChild("SmartBarGui"); if g2 then g2:Destroy() end
local g4 = cg:FindFirstChild("MatrixTrackerGUI"); if g4 then g4:Destroy() end
end
-- gethui()-Container aufräumen (Solara und andere Executoren)
if gethui then pcall(function()
local hui = gethui()
local g5 = hui:FindFirstChild("SmartBarGui"); if g5 then g5:Destroy() end
local g6 = hui:FindFirstChild("MatrixTrackerGUI"); if g6 then g6:Destroy() end
end) end
end)
if getgenv then getgenv()._TLAllConns = {} end
local function _tlTrackConn(c)
pcall(function()
local env = getgenv and getgenv() or _G
if env and env._TLAllConns then
env._TLAllConns[#env._TLAllConns + 1] = c
end
end)
return c
end
pcall(function()
if getgenv then getgenv().SmartBarLoaded = true end
end)
local _workspace = workspace or game:GetService("Workspace")
local PIGGYBACK_ANIM_ID, PIGGYBACK2_ANIM_ID = "108744973494490", "112201741232797"
task.spawn(function()
local _MY_TOKEN = getgenv and getgenv()._TLSessionToken or 1
local function _tlAlive()
if getgenv ~= nil then return getgenv()._TLSessionToken == _MY_TOKEN end
return true
end
-- Always clear stale flag on re-execute; only skip if same session already running
_G.EmotesGUIRunning = nil
if not _tlAlive() then return end
_G.EmotesGUIRunning = true
local AnimHttpService; pcall(function() AnimHttpService = game:GetService("HttpService") end)
if not AnimHttpService then AnimHttpService = {JSONDecode=function(_,s) return {} end, JSONEncode=function(_,t) return "{}" end} end
local AnimRunService; pcall(function() AnimRunService = game:GetService("RunService") end)
if not AnimRunService then AnimRunService = {Heartbeat={Connect=function(_,f) return {Disconnect=function()end} end}, Stepped={Connect=function(_,f) return {Disconnect=function()end} end}} end
local AnimPlayers; pcall(function() AnimPlayers = game:GetService("Players") end)
if not AnimPlayers then AnimPlayers = game:GetService("Players") end
local AnimUIS; pcall(function() AnimUIS = game:GetService("UserInputService") end)
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
getgenv().TLSendNotif(title, text, dur or 3)
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
local _btnConns = {}  -- persistent button connections (Mode, Nav, Search…); only cleared on GUI rebuild
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
function extractAssetId(imageUrl)
return imageUrl:match("Asset&id=(%d+)")
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
else                           hideFavIcon(btn) end
else hideFavIcon(btn) end
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
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
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
local cleanName = emoteName:gsub(" %- ⭐$", "")
local key = tostring(emoteId)
local found, idx = false, 0
for i, f in ipairs(favoriteEmotes) do
if tostring(f.id) == key then found = true; idx = i; break end
end
if found then
table.remove(favoriteEmotes, idx); _favSetEmote[key] = nil
animNotif("Animations-Menu", '🗑️ "' .. cleanName .. '" removed', 3)
else
table.insert(favoriteEmotes, {id=emoteId, name=cleanName.." - ⭐"})
_favSetEmote[key] = true
animNotif("Animations-Menu", '✅ "' .. cleanName .. '" added', 3)
end
saveFavorites(); invalidatePagesCache()
totalPages  = calculateTotalPages()
currentPage = math.min(currentPage, totalPages)
updatePageDisplay(); updateEmotes()
end
toggleFavoriteAnimation = function(animData)
local cleanName = animData.name:gsub(" %- ⭐$", "")
local key = tostring(animData.id)
local found, idx = false, 0
for i, f in ipairs(favoriteAnimations) do
if tostring(f.id) == key then found = true; idx = i; break end
end
if found then
table.remove(favoriteAnimations, idx); _favSetAnim[key] = nil
animNotif("Animations-Menu", '🗑️ "' .. cleanName .. '" removed', 3)
else
table.insert(favoriteAnimations, {id=animData.id, name=cleanName.." - ⭐", bundledItems=animData.bundledItems})
_favSetAnim[key] = true
animNotif("Animations-Menu", '✅ "' .. cleanName .. '" added', 3)
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
animNotif("Animations-Menu", "⭐ Favorites ON – click image to add/remove", 4)
else
animNotif("Animations-Menu", "⭐ Favorites OFF", 2)
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
animNotif("Animations-Menu", "⭐ Nur Favorites – " .. totalPages .. " Seite(n)", 2)
else
animNotif("Animations-Menu", "⭐ Alle anzeigen", 2)
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
if not animate or not hum then animNotif("Animations-Menu","❌ Animate/Humanoid missing",3); return end
if not animData.bundledItems then animNotif("Animations-Menu","❌ No bundledItems",3); return end
if getgenv then getgenv().lastPlayedAnimation = animData end
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
animNotif("Animations-Menu","🎉 "..totalEmotesLoaded.." Emotes loaded!", 4)
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
if isLoading then animNotif("Animations-Menu","⚠️ Loading...",2); return end
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
if isLoading then animNotif("Animations-Menu","⚠️ Loading...",2); return end
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
getgenv().TLAnimFreeze = function(on)
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
getgenv().autoReloadEnabled = not (getgenv().autoReloadEnabled or false)
animNotif("Animations-Menu", getgenv().autoReloadEnabled and "🔄 Auto-Reload ON" or "🔄 Auto-Reload OFF", 2)
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
animNotif("Animations-Menu","🔄 Mode: Animation",2)
task.spawn(function()
fetchAllAnimations()
if Search then Search.Text = animationSearchTerm end
invalidatePagesCache()
totalPages = calculateTotalPages(); currentPage = 1
updatePageDisplay(); updateEmotes()
end)
else
currentMode = "emote"
animNotif("Animations-Menu","🔄 Mode: Emote",2)
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
task.wait(0.3); applyAnimation(getgenv().lastPlayedAnimation)
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
animPlayer.CharacterAdded:Connect(checkR6Hint)
local createGUIElements, connectEvents
createGUIElements = function()
local exists, emotesWheel = checkEmotesMenuExists()
if not exists then return false end
for _, n in ipairs({"Under","Top","EmoteWalkButton","Favorite","SpeedEmote","SpeedBox","Changepage","Reload"}) do
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
btn.MouseEnter:Connect(function() btn.BackgroundTransparency=0.78 end)
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
FavOnlyBtn      = makeIconBtn(Top,"FavOnlyBtn",     "⭐",              btnStartX+btnGap*2, "Only",  false)
SpeedEmote      = makeIconBtn(Top,"SpeedEmote",     defaultButtonImage,btnStartX+btnGap*3, "Speed", true)
SpeedBox=Instance.new("TextBox",Top); SpeedBox.Name="SpeedBox"
SpeedBox.Size=UDim2.new(0,28,0,BTN_H); SpeedBox.Position=UDim2.new(0,btnStartX+btnGap*4,0,BTN_Y)
SpeedBox.BackgroundColor3=Color3.fromRGB(255,255,255); SpeedBox.BackgroundTransparency=0.92
SpeedBox.TextColor3=Color3.fromRGB(220,220,220); SpeedBox.TextSize=11; SpeedBox.Font=Enum.Font.GothamBold
SpeedBox.TextScaled=false; SpeedBox.Text="1"; SpeedBox.ZIndex=7; SpeedBox.Visible=false
SpeedBox.ClearTextOnFocus=false; SpeedBox.TextXAlignment=Enum.TextXAlignment.Center
UICorner_5=Instance.new("UICorner",SpeedBox); UICorner_5.CornerRadius=UDim.new(0,7)
local div=Instance.new("Frame",Top); div.Size=UDim2.new(0,1,0,20)
div.Position=UDim2.new(1,-66,0,BTN_Y+2); div.BackgroundColor3=Color3.fromRGB(255,255,255)
div.BackgroundTransparency=0.8; div.BorderSizePixel=0; div.ZIndex=6
Changepage=makeIconBtn(Top,"Changepage","⇄",nil,"Mode",false); Changepage.Parent.Position=UDim2.new(1,-61,0,BTN_Y)
Reload    =makeIconBtn(Top,"Reload",    "⟳",nil,"Reload",false); Reload.Parent.Position=UDim2.new(1,-31,0,BTN_Y)
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
animPlayer.CharacterAdded:Connect(function(char)
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
end)
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
table.insert(getgenv()._TLAnimConns, _hbConn)
table.insert(getgenv()._TLAnimConns, _stConn)
end
end)
task.spawn(function()
local StarterGui = game:GetService("StarterGui")
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
task.wait(1.0)
end
end)
task.spawn(function()
pcall(function()
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
end)
local _ewTimeout2 = 0
while not checkEmotesMenuExists() do
task.wait(0.1)
_ewTimeout2 = _ewTimeout2 + 0.1
if _ewTimeout2 > 15 then break end
end
if createGUIElements() then
loadFavorites(); loadFavoritesAnimations(); rebuildFavSet()
fetchAllEmotes(); loadSpeedEmoteConfig()
end
end)
if AnimUIS.KeyboardEnabled then
animNotif("Animations-Menu", '💻 Emote Menu: Press "."', 5)
end
end)
;(function()
local _TL_refs = {}  -- shared refs table: upvalue-safe across all nested IIFEs
local Players; pcall(function() Players = game:GetService("Players") end)
if not Players then Players = game:GetService("Players") end
local UserInputService; pcall(function() UserInputService = game:GetService("UserInputService") end)
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
local _C3_BG3              = Color3.fromRGB(7,  22, 10)   -- Matrix bg3
local _C3_BG2              = Color3.fromRGB(3,  14,  6)   -- Matrix bg2
local _C3_SUB2             = Color3.fromRGB(0,  140, 38)  -- Matrix sub gedimmt
local _C3_SUB              = Color3.fromRGB(0,  110, 28)  -- Matrix sub dunkel
local _C3_BG4              = Color3.fromRGB(5,  18,  8)   -- Matrix bg zwischen bg2/bg3
local _C3_TEXT2            = Color3.fromRGB(180, 255, 195) -- Matrix text2
local _C3_BLACK            = Color3.fromRGB(0,0,0)
local _C3_LGRAY            = Color3.fromRGB(160, 255, 180) -- Matrix hell (Icons)
local _C3_TEXT3            = Color3.fromRGB(160, 245, 178) -- Matrix text3
local _C3_DRED             = Color3.fromRGB(255, 60,  60)  -- bleibt rot
local _C3_MGRAY            = Color3.fromRGB(0,  155, 44)   -- Matrix mid (Icons inaktiv)
local _C3_RED              = Color3.fromRGB(255,80,80)
local _C3_ORANGE           = Color3.fromRGB(255,140,40)
local _C3_GREEN            = Color3.fromRGB(80,255,120)
local TweenService; pcall(function() TweenService = game:GetService("TweenService") end)
local RunService; pcall(function() RunService = game:GetService("RunService") end)
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
-- ── Matrix Green Palette ──────────────────────────────
bg        = Color3.fromRGB(10, 10, 10),   -- matt schwarz
bg2       = Color3.fromRGB(20, 20, 20),   -- Card-Hintergrund (neutral grau)
bg3       = Color3.fromRGB(28, 28, 28),   -- Hover / aktiv (neutral grau)
bghov     = Color3.fromRGB(11, 30, 14),   -- tiefer Hover
border    = Color3.fromRGB(0,  255, 65),  -- #00ff41 hell
borderdim = Color3.fromRGB(0,  80,  20),  -- gedimmte Border
accent    = Color3.fromRGB(0,  255, 65),  -- Akzent = Matrix-Grün
accent2   = Color3.fromRGB(0,  200, 50),  -- zweiter Akzent
green     = Color3.fromRGB(0,  230, 80),  -- Erfolgs-Grün
red       = Color3.fromRGB(255, 60, 90),  -- bleibt rot
orange    = Color3.fromRGB(255,155, 45),  -- bleibt orange
text      = Color3.fromRGB(210, 255, 220),-- leicht grün getöntes Weiß
sub       = Color3.fromRGB(0,  175, 50),  -- gedimmter Text
gradL     = Color3.fromRGB(0,  255, 65),  -- Gradient links
gradR     = Color3.fromRGB(0,  200, 50),  -- Gradient rechts
}

-- ════════════════════════════════════════════════════════════════
-- COLOR THEMES
-- ════════════════════════════════════════════════════════════════
local _TL_THEMES = {
    { id="matrix",  name="Matrix",   accent=Color3.fromRGB(0,255,65),  accent2=Color3.fromRGB(0,200,50),   sub=Color3.fromRGB(0,175,50),   borderdim=Color3.fromRGB(0,80,20),   text=Color3.fromRGB(210,255,220) },
    { id="blue",    name="Cyber",    accent=Color3.fromRGB(0,200,255), accent2=Color3.fromRGB(0,160,220),  sub=Color3.fromRGB(0,135,195),  borderdim=Color3.fromRGB(0,40,85),   text=Color3.fromRGB(210,235,255) },
    { id="purple",  name="Neon",     accent=Color3.fromRGB(190,80,255),accent2=Color3.fromRGB(160,55,220), sub=Color3.fromRGB(140,45,195), borderdim=Color3.fromRGB(55,10,85),  text=Color3.fromRGB(240,220,255) },
    { id="red",     name="Crimson",  accent=Color3.fromRGB(255,55,80), accent2=Color3.fromRGB(220,40,60),  sub=Color3.fromRGB(195,30,50),  borderdim=Color3.fromRGB(80,10,20),  text=Color3.fromRGB(255,220,225) },
    { id="gold",    name="Gold",     accent=Color3.fromRGB(255,200,0), accent2=Color3.fromRGB(220,168,0),  sub=Color3.fromRGB(195,148,0),  borderdim=Color3.fromRGB(80,58,0),   text=Color3.fromRGB(255,245,210) },
    { id="cyan",    name="Ice",      accent=Color3.fromRGB(0,255,200), accent2=Color3.fromRGB(0,218,168),  sub=Color3.fromRGB(0,188,148),  borderdim=Color3.fromRGB(0,60,48),   text=Color3.fromRGB(210,255,248) },
    { id="rose",    name="Rose",     accent=Color3.fromRGB(255,100,160),accent2=Color3.fromRGB(220,75,130),sub=Color3.fromRGB(195,55,110), borderdim=Color3.fromRGB(80,15,40),  text=Color3.fromRGB(255,225,235) },
    { id="orange",  name="Blaze",    accent=Color3.fromRGB(255,130,0), accent2=Color3.fromRGB(220,105,0),  sub=Color3.fromRGB(195,88,0),   borderdim=Color3.fromRGB(80,38,0),   text=Color3.fromRGB(255,238,215) },
    { id="lime",    name="Toxic",    accent=Color3.fromRGB(150,255,0), accent2=Color3.fromRGB(118,215,0),  sub=Color3.fromRGB(100,185,0),  borderdim=Color3.fromRGB(38,70,0),   text=Color3.fromRGB(230,255,205) },
    { id="white",   name="Ghost",    accent=Color3.fromRGB(220,225,235),accent2=Color3.fromRGB(185,190,200),sub=Color3.fromRGB(160,165,175),borderdim=Color3.fromRGB(60,62,70),  text=Color3.fromRGB(240,242,248) },
    { id="teal",    name="Teal",     accent=Color3.fromRGB(0,210,185), accent2=Color3.fromRGB(0,175,155),  sub=Color3.fromRGB(0,150,135),  borderdim=Color3.fromRGB(0,55,48),   text=Color3.fromRGB(210,252,248) },
    { id="indigo",  name="Void",     accent=Color3.fromRGB(100,120,255),accent2=Color3.fromRGB(75,95,220), sub=Color3.fromRGB(58,75,195),  borderdim=Color3.fromRGB(18,22,80),  text=Color3.fromRGB(225,228,255) },
    { id="peach",   name="Peach",    accent=Color3.fromRGB(255,175,100),accent2=Color3.fromRGB(220,145,75),sub=Color3.fromRGB(195,122,58), borderdim=Color3.fromRGB(80,45,15),  text=Color3.fromRGB(255,242,228) },
    { id="mint",    name="Mint",     accent=Color3.fromRGB(80,255,185), accent2=Color3.fromRGB(58,215,152),sub=Color3.fromRGB(42,185,130), borderdim=Color3.fromRGB(10,68,45),  text=Color3.fromRGB(215,255,242) },
}
local _TL_activeThemeId = "matrix"
local function _TL_applyTheme(themeId)
    -- ── 1. Resolve themes ───────────────────────────────────────
    local newT = nil
    for _, t in ipairs(_TL_THEMES) do if t.id == themeId  then newT = t; break end end
    if not newT then return end
    local oldT = nil
    for _, t in ipairs(_TL_THEMES) do if t.id == _TL_activeThemeId then oldT = t; break end end
    if not oldT then oldT = _TL_THEMES[1] end

    -- ── 2. Color remap helper ───────────────────────────────────
    local function lerp3(a, b, t)
        return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t)
    end
    local function close(a, b, tol)  -- tol in 0-1 per channel
        return math.abs(a.R-b.R)<tol and math.abs(a.G-b.G)<tol and math.abs(a.B-b.B)<tol
    end
    -- Find t if col lies on gradient c0→c1 (returns nil if it doesn't)
    local function gradientT(col, c0, c1)
        local sum, cnt = 0, 0
        local function ch(v, a, b)
            local r = b - a
            if math.abs(r) > 0.04 then sum = sum + (v-a)/r; cnt = cnt+1 end
        end
        ch(col.R, c0.R, c1.R); ch(col.G, c0.G, c1.G); ch(col.B, c0.B, c1.B)
        if cnt == 0 then return nil end
        local t = math.clamp(sum/cnt, 0, 1)
        local fit = lerp3(c0, c1, t)
        local err = math.abs(fit.R-col.R)+math.abs(fit.G-col.G)+math.abs(fit.B-col.B)
        return err < 0.22 and t or nil
    end
    -- Explicit anchor colors from BOTH old theme AND current C (handles accumulated mutations)
    -- Also include hardcoded Matrix green shades used in panels/widgets that bypass C palette
    local _HC_MG    = C.accent   -- P_MG / MG / MG_B
    local _HC_MGA   = Color3.fromRGB(0, 210, 58)   -- P_MGA
    local _HC_MGA2  = Color3.fromRGB(0, 200, 55)   -- MKEY / widget accent (0,200,55)
    local _HC_MGDIM = Color3.fromRGB(0, 175, 50)   -- P_MGDIM / sub
    local _HC_MGLOW = Color3.fromRGB(30, 255, 90)  -- MGLOW
    local _HC_FW    = Color3.fromRGB(0, 200, 55)   -- fwStroke / gb widgets
    local anchors = {
        {oldT.accent,    newT.accent},
        {oldT.accent2,   newT.accent2},
        {oldT.sub,       newT.sub},
        {oldT.borderdim, newT.borderdim},
        {oldT.text,      newT.text},
        {C.accent,       newT.accent},
        {C.accent2,      newT.accent2},
        {C.sub,          newT.sub},
        {C.borderdim,    newT.borderdim},
        {C.text,         newT.text},
        {C.green,        newT.accent},
        {C.gradL,        newT.accent},
        {C.gradR,        newT.accent2},
        {C.border,       newT.accent},
        -- Hardcoded Matrix greens (panels, GB/Rush/Fling widgets, aim lines)
        {_HC_MG,    newT.accent},
        {_HC_MGA,   newT.accent2},
        {_HC_MGA2,  newT.accent2},
        {_HC_MGDIM, newT.sub},
        {_HC_MGLOW, newT.accent},
        {_HC_FW,    newT.accent2},
    }
    local function remapColor(col)
        -- Exact / near-exact anchor match (tolerance ~20 RGB units)
        for _, a in ipairs(anchors) do
            if close(col, a[1], 0.09) then return a[2] end
        end
        -- Gradient interpolation: any color on the dim→bright gradient of old theme
        local t = gradientT(col, oldT.borderdim, oldT.accent)
        if t then return lerp3(newT.borderdim, newT.accent, t) end
        -- Also try C.borderdim→C.accent in case C was already partially mutated
        t = gradientT(col, C.borderdim, C.accent)
        if t then return lerp3(newT.borderdim, newT.accent, t) end
        return nil
    end

    -- ── 3. Update C palette ─────────────────────────────────────
    C.accent    = newT.accent
    C.accent2   = newT.accent2
    C.sub       = newT.sub
    C.borderdim = newT.borderdim
    C.text      = newT.text
    C.green     = newT.accent
    C.gradL     = newT.accent
    C.gradR     = newT.accent2
    C.border    = newT.accent
    _TL_activeThemeId = themeId
    -- Sync P_MG* panel palette vars and MG_B tab bar color
    pcall(function()
        if _panelColorHooks then
            for _, fn in ipairs(_panelColorHooks) do pcall(fn, newT) end
        end
    end)
    -- MG_B/MGA_B/MGDIM are now functions reading C.* directly

    -- ── 4. Scan & recolor all GUI descendants ───────────────────
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
            elseif cn == "ImageLabel" or cn == "ImageButton" then
                local n = remapColor(d.ImageColor3); if n then d.ImageColor3 = n end
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

    -- ── 5. Persist ──────────────────────────────────────────────
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
        if getgenv then getgenv()._TL_savedTheme = themeId end
    end)
    
    -- ── 6. Restore hardcoded chip colors (immune to remapping) ──────
    pcall(function()
        if _tlEnv._TL_FixThemeChips then
            _tlEnv._TL_FixThemeChips(themeId)
        end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
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
local RS         = RunService or game:GetService("RunService")
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
conn = RS.Heartbeat:Connect(function(dt)
t = t + dt
if t < 0.5 then return end
t = 0
pcall(scanBackpack)
end)
Players.LocalPlayer.CharacterAdded:Connect(function()
task.wait(1)
patched = {}
t = 0
end)
pcall(function()
if getgenv then
getgenv()._TLInvPatchCleanup = function() end
end
end)
end)
pcall(function()
local RS      = RunService or game:GetService("RunService")
local UIS     = UserInputService or game:GetService("UserInputService")
local PG = Players.LocalPlayer:FindFirstChild("PlayerGui")
or Players.LocalPlayer:WaitForChild("PlayerGui", 8)
if not PG then return end
local CYAN    = Color3.fromRGB(0, 220, 255)
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
hl.OutlineColor        = CYAN
hl.OutlineTransparency = 0
hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
hl.Parent              = workspace
outlines[p] = hl
end)
end
end
local function openCard(p)
if cards[p] then return end
if not p or not p.Character then return end

-- ── Palette (exact match to HTML design) ─────────────
local MG    = C.accent     -- #00ff41
local MGA   = C.accent2                       -- #00c832
local MGLOW = C.accent                        -- #1eff5a
local MDARK = Color3.fromRGB(2, 8, 4)        -- #020804
local MHDR  = Color3.fromRGB(3, 10, 5)       -- #030a05
local MKEY  = C.accent2                       -- #00c837
local MVAL  = Color3.fromRGB(180, 255, 190)  -- #b4ffbe
local MSEP  = C.sub                           -- #00b42d

local PW, PH = 258, 360

-- ── ScreenGui ────────────────────────────────────────
local bb = Instance.new("ScreenGui")
bb.Name = "_TLHolo_"..p.Name
bb.ResetOnSpawn = false
bb.IgnoreGuiInset = true
bb.DisplayOrder = 9999
_tryParentGui(bb)

-- ── Mobile/Tablet responsive scaling ─────────────────
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

-- ── Root (right-anchored, vertically centered) ───────
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

-- Outer glow: Roblox hat kein CSS blur → kein sichtbarer box-shadow möglich.
-- Der UIStroke auf bg übernimmt den Rand-Effekt bereits. Glow-Frame entfernt.

-- ── Background panel ─────────────────────────────────
-- HTML: background:#020804; border:1.5px solid #00ff41; border-radius:10px; overflow:hidden
local bg = Instance.new("Frame", root)
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = MDARK
bg.BackgroundTransparency = 0
bg.BorderSizePixel = 0; bg.ZIndex = 1
bg.ClipsDescendants = true
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)

-- kein Gradient: nicht im HTML-Design vorhanden

-- pulsing border stroke
local mainStroke = Instance.new("UIStroke", bg)
mainStroke.Color = MG
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.2
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ── Top accent bars ───────────────────────────────────
-- HTML: .tb1{width:60%;height:2px;background:#00ff41}
--       .tb2{width:40%;height:2px;background:#1eff5a;opacity:0.4}
local tb1 = Instance.new("Frame", bg)
tb1.Size = UDim2.new(0.6, 0, 0, 2); tb1.Position = UDim2.new(0, 0, 0, 0)
tb1.BackgroundColor3 = MG; tb1.BorderSizePixel = 0; tb1.ZIndex = 4
local tb2 = Instance.new("Frame", bg)
tb2.Size = UDim2.new(0.4, 0, 0, 2); tb2.Position = UDim2.new(0.6, 0, 0, 0)
tb2.BackgroundColor3 = MGLOW; tb2.BackgroundTransparency = 0.6
tb2.BorderSizePixel = 0; tb2.ZIndex = 4

-- ── Corner brackets ───────────────────────────────────
-- HTML: .corner{width:18px;height:18px} ::before{width:100%;height:2px} ::after{width:2px;height:100%}
local function bracket(ax, ay)
    local br = Instance.new("Frame", bg)
    br.Size = UDim2.new(0, 18, 0, 18)
    br.AnchorPoint = Vector2.new(ax, ay)
    br.Position = UDim2.new(ax, ax==0 and 4 or -4, ay, ay==0 and 4 or -4)
    br.BackgroundTransparency = 1; br.BorderSizePixel = 0; br.ZIndex = 6
    -- horizontal bar
    local h = Instance.new("Frame", br)
    h.Size = UDim2.new(1, 0, 0, 2); h.Position = UDim2.new(0, 0, ay==0 and 0 or 1, ay==0 and 0 or -2)
    h.BackgroundColor3 = MG; h.BackgroundTransparency = 0; h.BorderSizePixel = 0; h.ZIndex = 7
    -- vertical bar
    local v = Instance.new("Frame", br)
    v.Size = UDim2.new(0, 2, 1, 0); v.Position = UDim2.new(ax==0 and 0 or 1, ax==0 and 0 or -2, 0, 0)
    v.BackgroundColor3 = MG; v.BackgroundTransparency = 0; v.BorderSizePixel = 0; v.ZIndex = 7
end
bracket(0, 0); bracket(1, 0); bracket(0, 1); bracket(1, 1)

-- ── Scanline ─────────────────────────────────────────
-- HTML: height:3px; opacity:0.35; animation:scan 2.8s linear infinite (top:-3px→100%)
local scan = Instance.new("Frame", bg)
scan.Size = UDim2.new(1, 0, 0, 3)
scan.Position = UDim2.new(0, 0, 0, 0)
scan.BackgroundColor3 = MG
scan.BackgroundTransparency = 0.65   -- 1-0.35=0.65
scan.BorderSizePixel = 0; scan.ZIndex = 15

-- ── Matrix rain strip (right edge) ───────────────────
-- HTML: right:0; width:18px; background:#00ff410a; border-radius:0 8px 8px 0; overflow:hidden
-- FIX: Narrowed 18→14px so scrollbar + footer buttons don't overlap rain strip
local rainStrip = Instance.new("Frame", bg)
rainStrip.Size = UDim2.new(0, 14, 1, 0)
rainStrip.Position = UDim2.new(1, -14, 0, 0)
rainStrip.BackgroundColor3 = MG
rainStrip.BackgroundTransparency = 0.96   -- #00ff410a ≈ 96% transparent
-- FIX: ZIndex lowered to 1 so header (ZIndex 3) always renders on top
rainStrip.BorderSizePixel = 0; rainStrip.ZIndex = 1
rainStrip.ClipsDescendants = true  -- verhindert Überlauf des animierten rainLbl
Instance.new("UICorner", rainStrip).CornerRadius = UDim.new(0, 4)
local rainLbl = Instance.new("TextLabel", rainStrip)
rainLbl.Size = UDim2.new(1, 0, 2, 0)    -- 2× tall so scrolling looks continuous
rainLbl.Position = UDim2.new(0, 0, 0, 0)
rainLbl.BackgroundTransparency = 1
rainLbl.Text = "1\n0\n1\n1\n0\n0\n1\n0\n1\n1\n0\n1\n0\n1\n0\n0\n1\n1\n0\n1\n0\n1\n1\n0\n1\n0"
rainLbl.TextColor3 = MG; rainLbl.Font = Enum.Font.Code
rainLbl.TextSize = 8; rainLbl.LineHeight = 1.45
rainLbl.TextTransparency = 0.6
rainLbl.TextXAlignment = Enum.TextXAlignment.Center
rainLbl.ZIndex = 3

-- ── Header ────────────────────────────────────────────
-- HTML: top:3px; left:1px; right:1px; height:52px; background:#030a05; border-radius:8px
local hdr = Instance.new("Frame", bg)
hdr.Size     = UDim2.new(1, -2, 0, 52)
hdr.Position = UDim2.new(0, 1, 0, 3)
hdr.BackgroundColor3 = MHDR; hdr.BackgroundTransparency = 0
-- FIX: ZIndex raised from 2→3 so header sits above rain strip (ZIndex 1)
hdr.BorderSizePixel = 0; hdr.ZIndex = 3
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 8)

-- header bottom separator (.hdr-sep: top:56px; height:1px; opacity:0.35)
local hdrSep = Instance.new("Frame", bg)
hdrSep.Size     = UDim2.new(1, -8, 0, 1)
hdrSep.Position = UDim2.new(0, 4, 0, 57)
hdrSep.BackgroundColor3 = MG; hdrSep.BackgroundTransparency = 0.65
hdrSep.BorderSizePixel = 0; hdrSep.ZIndex = 3

-- LIVE label (top:8px; right:28px)
local statusLbl = Instance.new("TextLabel", bg)
statusLbl.Size     = UDim2.new(0, 26, 0, 10)
-- FIX: was UDim2.new(1,-38,0,10) → right edge was 246px, overlapping 14px rain strip at 244
statusLbl.Position = UDim2.new(1, -56, 0, 10)
statusLbl.BackgroundTransparency = 1; statusLbl.Text = "LIVE"
statusLbl.TextColor3 = MG; statusLbl.Font = Enum.Font.Code
statusLbl.TextSize = 8; statusLbl.ZIndex = 5

-- blinking dot (top:8px; right:12px; 6×6)
local statusDot = Instance.new("Frame", bg)
statusDot.Size     = UDim2.new(0, 6, 0, 6)
-- FIX: was UDim2.new(1,-14,0,10) → dot sat at 244px, exactly on rain strip edge
statusDot.Position = UDim2.new(1, -26, 0, 10)
statusDot.BackgroundColor3 = MG; statusDot.BorderSizePixel = 0; statusDot.ZIndex = 5
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

-- Avatar circle (10px from left in header, vertically centered, 38×38)
local ava = Instance.new("Frame", hdr)
ava.Size = UDim2.new(0, 38, 0, 38); ava.Position = UDim2.new(0, 10, 0.5, -19)
ava.BackgroundColor3 = Color3.fromRGB(0, 20, 5)
ava.BackgroundTransparency = 0; ava.BorderSizePixel = 0; ava.ZIndex = 3
Instance.new("UICorner", ava).CornerRadius = UDim.new(1, 0)
local avaSt = Instance.new("UIStroke", ava)
avaSt.Color = MG; avaSt.Thickness = 1.5; avaSt.Transparency = 0.85  -- #00ff4126 ≈ 85%
avaSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
-- avatar image
local avaImg = Instance.new("ImageLabel", ava)
avaImg.Size = UDim2.new(1, 0, 1, 0); avaImg.BackgroundTransparency = 1
avaImg.Image = ""; avaImg.ScaleType = Enum.ScaleType.Crop; avaImg.ZIndex = 4
Instance.new("UICorner", avaImg).CornerRadius = UDim.new(1, 0)
-- green tint overlay (.ava-tint: background:#00ff4118 ≈ 91% transparent)
local avaTint = Instance.new("Frame", ava)
avaTint.Size = UDim2.new(1, 0, 1, 0); avaTint.BackgroundColor3 = MG
avaTint.BackgroundTransparency = 0.91; avaTint.BorderSizePixel = 0; avaTint.ZIndex = 5
Instance.new("UICorner", avaTint).CornerRadius = UDim.new(1, 0)
task.spawn(function()
    pcall(function()
        local img = Players:GetUserThumbnailAsync(p.UserId,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        if avaImg.Parent then avaImg.Image = img end
    end)
end)

-- player name (.nm-main: color:#1eff5a; font-size:13px; font-weight:bold)
local nm = Instance.new("TextLabel", hdr)
-- FIX: was UDim2.new(1,-60,0,18) → nm right edge in bg was ~253px, overlapping LIVE at 202px
-- New width: hdr(256) - 115 = 141px. From x=56 in hdr → right edge 197 in hdr, 198 in bg. LIVE at 202. ✓
nm.Size = UDim2.new(1, -115, 0, 18); nm.Position = UDim2.new(0, 56, 0, 8)
nm.BackgroundTransparency = 1; nm.Text = p.Name
nm.TextColor3 = MGLOW; nm.Font = Enum.Font.GothamBold
nm.TextSize = 13; nm.TextXAlignment = Enum.TextXAlignment.Left
nm.TextTruncate = Enum.TextTruncate.AtEnd; nm.ZIndex = 3

-- display name (.nm-sub: color:#00c832; font-size:9px)
local nmSub = Instance.new("TextLabel", hdr)
-- FIX: same right-margin correction as nm label above
nmSub.Size = UDim2.new(1, -115, 0, 13); nmSub.Position = UDim2.new(0, 56, 0, 29)
nmSub.BackgroundTransparency = 1
nmSub.Text = "> @"..(p.DisplayName or p.Name)
nmSub.TextColor3 = MGA; nmSub.Font = Enum.Font.Code
nmSub.TextSize = 9; nmSub.TextXAlignment = Enum.TextXAlignment.Left
nmSub.TextTruncate = Enum.TextTruncate.AtEnd; nmSub.ZIndex = 3

-- ── Scroll frame ─────────────────────────────────────
-- HTML: .sf{left:2px; right:2px} → width = 258-4 = 254px
local sf = Instance.new("ScrollingFrame", bg)
sf.Size     = UDim2.new(1, -4, 1, -124)
sf.Position = UDim2.new(0, 2, 0, 60)
sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
sf.ScrollBarThickness = 2; sf.ScrollBarImageColor3 = C.accent
sf.ScrollBarImageTransparency = 0
sf.CanvasSize = UDim2.new(0, 0, 0, 0)
sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
sf.ElasticBehavior = Enum.ElasticBehavior.Never
sf.ScrollingDirection = Enum.ScrollingDirection.Y; sf.ZIndex = 3

local ll = Instance.new("UIListLayout", sf)
ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0, 1)

-- HTML: .sf-inner{padding:3px 22px 6px 4px}
local sfPad = Instance.new("UIPadding", sf)
sfPad.PaddingLeft   = UDim.new(0, 4)
-- HTML: .sf-inner{padding:3px 22px 6px 4px} → 22px right keeps text clear of rain strip + scrollbar
sfPad.PaddingRight  = UDim.new(0, 22)
sfPad.PaddingTop    = UDim.new(0, 3)
sfPad.PaddingBottom = UDim.new(0, 6)

-- ── Row builder ──────────────────────────────────────
-- HTML: .row{height:22px; border-radius:3px; font-size:10px}
-- .row.alt{background:#00ff4114}
-- .row-bar{width:2px; height:14px; background:#00ff41; opacity:0.9}
-- .row-k{color:#00c837; width:82px}  .row-sep{color:#00c832; opacity:0.55}  .row-v{color:#b4ffbe}
local ord = 0
local function mkRow(key, val)
    ord = ord + 1
    local f = Instance.new("Frame", sf)
    f.Size = UDim2.new(1, 0, 0, 22); f.LayoutOrder = ord
    f.BackgroundColor3 = MG
    f.BackgroundTransparency = (ord % 2 == 1) and (1 - 0.078) or 1  -- #00ff4114 ≈ 92.2% tr
    f.BorderSizePixel = 0; f.ZIndex = 4
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 3)
    -- left accent bar
    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 2, 0, 14); bar.Position = UDim2.new(0, 0, 0.5, -7)
    bar.BackgroundColor3 = MG; bar.BackgroundTransparency = 0.1
    bar.BorderSizePixel = 0; bar.ZIndex = 5
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    -- key label
    local k = Instance.new("TextLabel", f)
    k.Size = UDim2.new(0, 82, 1, 0); k.Position = UDim2.new(0, 8, 0, 0)
    k.BackgroundTransparency = 1; k.Text = tostring(key or "")
    k.TextColor3 = MKEY; k.Font = Enum.Font.Code
    k.TextSize = 10; k.TextXAlignment = Enum.TextXAlignment.Left; k.ZIndex = 5
    -- separator │
    local sep2 = Instance.new("TextLabel", f)
    sep2.Size = UDim2.new(0, 14, 1, 0); sep2.Position = UDim2.new(0, 88, 0, 0)
    sep2.BackgroundTransparency = 1; sep2.Text = "│"
    sep2.TextColor3 = MGA; sep2.Font = Enum.Font.Code
    sep2.TextSize = 10; sep2.TextTransparency = 0.45; sep2.ZIndex = 5
    -- value label
    local v = Instance.new("TextLabel", f)
    v.Size = UDim2.new(1, -104, 1, 0); v.Position = UDim2.new(0, 104, 0, 0)
    v.BackgroundTransparency = 1; v.Text = tostring(val ~= nil and val or "–")
    v.TextColor3 = MVAL; v.Font = Enum.Font.Code
    v.TextSize = 10; v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextTruncate = Enum.TextTruncate.AtEnd; v.ZIndex = 5
    return v
end

-- HTML: .sec{height:18px; font-size:9px; color:#00b42d} ::after{height:1px; background:#00ff41; opacity:0.3}
local function mkSec(title)
    ord = ord + 1
    local f = Instance.new("Frame", sf)
    f.Size = UDim2.new(1, 0, 0, 18); f.LayoutOrder = ord
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.ZIndex = 4
    -- bottom line
    local ln = Instance.new("Frame", f)
    ln.Size = UDim2.new(1, 0, 0, 1); ln.Position = UDim2.new(0, 0, 1, -1)
    ln.BackgroundColor3 = MG; ln.BackgroundTransparency = 0.7
    ln.BorderSizePixel = 0; ln.ZIndex = 5
    -- label
    local lb = Instance.new("TextLabel", f)
    lb.Size = UDim2.new(1, 0, 1, -2); lb.Position = UDim2.new(0, 4, 0, 0)
    lb.BackgroundTransparency = 1; lb.Text = "// "..tostring(title or "")
    lb.TextColor3 = MSEP; lb.Font = Enum.Font.Code
    lb.TextSize = 9; lb.TextXAlignment = Enum.TextXAlignment.Left; lb.ZIndex = 5
end

-- populate rows
mkRow("name",    p.Name)
mkRow("display", p.DisplayName)
mkRow("uid",     p.UserId)
mkRow("age",     tostring(p.AccountAge or "?").."d")
local mem = "false"
pcall(function() if p.MembershipType == Enum.MembershipType.Premium then mem = "true  ⭐" end end)
mkRow("premium", mem)
local ping = "–"
pcall(function()
    ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()).."ms"
end)
mkRow("ping",  ping)
mkRow("team",  (p.Team and p.Team.Name) or "nil")
local hp, mhp = "–", "–"
pcall(function()
    local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    if h then hp = math.floor(h.Health); mhp = math.floor(h.MaxHealth) end
end)
mkRow("hp", hp ~= "–" and (hp.."/"..mhp) or "–")
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

-- ── Footer ────────────────────────────────────────────
-- HTML: .foot-sep{bottom:52px; height:1px; opacity:0.35}
--       .foot{bottom:14px; left:8px; right:8px; height:32px}
-- In absolute: footSep Y = PH - 52 = 308 → from top = 308
-- buttons bottom edge: PH - 14 = 346; top = PH - 14 - 32 = 314 → from top = 314

local footSep = Instance.new("Frame", bg)
-- button top: 1,-38; sep 8px above button → 1,-46
footSep.Size     = UDim2.new(1, -8, 0, 1)
footSep.Position = UDim2.new(0, 4, 1, -46)
footSep.BackgroundColor3 = MG; footSep.BackgroundTransparency = 0.65
footSep.BorderSizePixel = 0; footSep.ZIndex = 8

-- HTML: .foot{left:8px;right:8px;gap:6px} → 258-16=242px total
-- .btn-add{flex:0 0 63%} → 63% × 242 = 152px
-- Usable footer width: 244(rain start) - 8(left) = 236px, -6(gap) = 230px
-- addBtn 63%: floor(230*0.63)=144px → right edge: 8+144=152px ✓
local addBtn = Instance.new("TextButton", bg)
addBtn.Size     = UDim2.new(0, 144, 0, 24)
addBtn.Position = UDim2.new(0, 8, 1, -38)
addBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 45)
addBtn.BackgroundTransparency = 0.15
addBtn.BorderSizePixel = 0
addBtn.Text = "[ + ADD FRIEND ]"
addBtn.TextColor3 = Color3.fromRGB(200, 255, 210)
addBtn.Font = Enum.Font.Code; addBtn.TextSize = 9
addBtn.ZIndex = 9; addBtn.Active = true
Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 5)
local addSt = Instance.new("UIStroke", addBtn)
addSt.Color = MG; addSt.Thickness = 1; addSt.Transparency = 0.5
addSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
addBtn.MouseEnter:Connect(function()
    addBtn.BackgroundTransparency = 0.0; addBtn.TextColor3 = Color3.fromRGB(255,255,255)
end)
addBtn.MouseLeave:Connect(function()
    addBtn.BackgroundTransparency = 0.15; addBtn.TextColor3 = Color3.fromRGB(200,255,210)
end)
addBtn.MouseButton1Click:Connect(function()
    if not addBtn.Active then return end
    addBtn.Text = "[ SENDING… ]"; addBtn.BackgroundTransparency = 0.4
    task.spawn(function()
        local ok = pcall(function()
            game:GetService("Players").LocalPlayer:RequestFriendship(p)
        end)
        task.wait(0.5)
        if addBtn.Parent then
            addBtn.Text = ok and "[ ✓ SENT ]" or "[ ALREADY FRIENDS ]"
            addBtn.BackgroundColor3 = ok and Color3.fromRGB(0,110,30) or Color3.fromRGB(55,55,55)
            addBtn.BackgroundTransparency = 0.2; addBtn.Active = false
        end
    end)
end)
addBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        if not addBtn.Active then return end
        addBtn.Text = "[ SENDING… ]"; addBtn.BackgroundTransparency = 0.4
        task.spawn(function()
            local ok = pcall(function()
                game:GetService("Players").LocalPlayer:RequestFriendship(p)
            end)
            task.wait(0.5)
            if addBtn.Parent then
                addBtn.Text = ok and "[ ✓ SENT ]" or "[ ALREADY FRIENDS ]"
                addBtn.BackgroundColor3 = ok and Color3.fromRGB(0,110,30) or Color3.fromRGB(55,55,55)
                addBtn.BackgroundTransparency = 0.2; addBtn.Active = false
            end
        end)
    end
end)

-- HTML: .btn-names{flex:1} → 242-152-6(gap)=84px, starts at 8+152+6=166
-- namesBtn flex:1 → 230-144=86px, left: 8+144+6=158, right: 158+86=244px = rain strip start ✓
local namesBtn = Instance.new("TextButton", bg)
namesBtn.Size     = UDim2.new(0, 86, 0, 24)
namesBtn.Position = UDim2.new(0, 158, 1, -38)
namesBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 35)
namesBtn.BackgroundTransparency = 0.25
namesBtn.BorderSizePixel = 0
namesBtn.Text = "[ NAMES ▸ ]"
namesBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
namesBtn.Font = Enum.Font.Code; namesBtn.TextSize = 9
namesBtn.ZIndex = 9; namesBtn.Active = true
Instance.new("UICorner", namesBtn).CornerRadius = UDim.new(0, 5)
local namesSt = Instance.new("UIStroke", namesBtn)
namesSt.Color = MG; namesSt.Thickness = 1; namesSt.Transparency = 0.56
namesSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
namesBtn.MouseEnter:Connect(function()
    namesBtn.BackgroundTransparency = 0.0; namesBtn.TextColor3 = Color3.fromRGB(255,255,255)
end)
namesBtn.MouseLeave:Connect(function()
    namesBtn.BackgroundTransparency = 0.25; namesBtn.TextColor3 = Color3.fromRGB(180,255,200)
end)

-- ── Names popup ───────────────────────────────────────
-- HTML: .popup{width:160px; background:#020804; border:1.5px solid #00ff41; border-radius:8px}
-- positioned to the LEFT of the panel, aligned to top of header
local namesPopup = nil
local function _doNamesBtn()
    if namesPopup and namesPopup.Parent then
        namesPopup:Destroy(); namesPopup = nil
        namesBtn.Text = "[ NAMES ▸ ]"; return
    end
    namesBtn.Text = "[ NAMES × ]"

    local POP_W = 160
    local pop = Instance.new("Frame", root)
    pop.Name = "_NamesPopup"
    -- align: right edge of popup = left edge of panel (x=0), 8px gap
    -- top aligned with panel top
    pop.AnchorPoint = Vector2.new(0, 0)
    pop.Position    = UDim2.new(1, 8, 0, 0)
    pop.Size        = UDim2.new(0, POP_W, 0, 36)   -- starts at header height, expands
    pop.BackgroundColor3 = MDARK
    pop.BackgroundTransparency = 0
    pop.BorderSizePixel = 0; pop.ZIndex = 20
    pop.ClipsDescendants = true
    Instance.new("UICorner", pop).CornerRadius = UDim.new(0, 8)
    local popSt = Instance.new("UIStroke", pop)
    popSt.Color = MG; popSt.Thickness = 1.5; popSt.Transparency = 0.0
    popSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    -- popup header (.popup-hdr: background:#030a05; border-bottom:1px solid #00ff4128; padding:5px 8px)
    local popHdr = Instance.new("Frame", pop)
    popHdr.Size = UDim2.new(1, 0, 0, 26)
    popHdr.BackgroundColor3 = MHDR; popHdr.BackgroundTransparency = 0
    popHdr.BorderSizePixel = 0; popHdr.ZIndex = 21
    Instance.new("UICorner", popHdr).CornerRadius = UDim.new(0, 7)
    -- square bottom corners on header
    local hdrBtm = Instance.new("Frame", popHdr)
    hdrBtm.Size = UDim2.new(1, 0, 0, 8); hdrBtm.Position = UDim2.new(0, 0, 1, -8)
    hdrBtm.BackgroundColor3 = MHDR; hdrBtm.BackgroundTransparency = 0
    hdrBtm.BorderSizePixel = 0; hdrBtm.ZIndex = 21
    -- header bottom separator line
    local hdrLn = Instance.new("Frame", pop)
    hdrLn.Size = UDim2.new(1, 0, 0, 1); hdrLn.Position = UDim2.new(0, 0, 0, 26)
    hdrLn.BackgroundColor3 = MG; hdrLn.BackgroundTransparency = 0.85
    hdrLn.BorderSizePixel = 0; hdrLn.ZIndex = 22
    -- title
    local popTit = Instance.new("TextLabel", popHdr)
    popTit.Size = UDim2.new(1, -26, 1, 0); popTit.Position = UDim2.new(0, 8, 0, 0)
    popTit.BackgroundTransparency = 1; popTit.Text = "// PREV NAMES"
    popTit.TextColor3 = MG; popTit.Font = Enum.Font.Code
    popTit.TextSize = 9; popTit.TextXAlignment = Enum.TextXAlignment.Left; popTit.ZIndex = 22
    -- close X
    local xBtn = Instance.new("TextButton", popHdr)
    xBtn.Size = UDim2.new(0, 18, 0, 18); xBtn.Position = UDim2.new(1, -20, 0.5, -9)
    xBtn.BackgroundTransparency = 1; xBtn.Text = "×"
    xBtn.TextColor3 = MGA; xBtn.Font = Enum.Font.GothamBold; xBtn.TextSize = 14; xBtn.ZIndex = 23
    xBtn.MouseButton1Click:Connect(function()
        if namesPopup then namesPopup:Destroy(); namesPopup = nil end
        namesBtn.Text = "[ NAMES ▸ ]"
    end)
    xBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            if namesPopup then namesPopup:Destroy(); namesPopup = nil end
            namesBtn.Text = "[ NAMES ▸ ]"
        end
    end)

    -- rows container
    local lf = Instance.new("Frame", pop)
    lf.Position = UDim2.new(0, 0, 0, 27)
    lf.Size = UDim2.new(1, 0, 0, 0)
    lf.BackgroundTransparency = 1; lf.BorderSizePixel = 0; lf.ZIndex = 21
    lf.AutomaticSize = Enum.AutomaticSize.Y
    local lfl = Instance.new("UIListLayout", lf)
    lfl.Padding = UDim.new(0, 0); lfl.SortOrder = Enum.SortOrder.LayoutOrder
    -- padding: .popup-rows{padding:4px 8px 8px}
    local lfp = Instance.new("UIPadding", lf)
    lfp.PaddingLeft = UDim.new(0, 8); lfp.PaddingRight = UDim.new(0, 8)
    lfp.PaddingTop = UDim.new(0, 4); lfp.PaddingBottom = UDim.new(0, 8)

    -- HTML: .prow{height:≈20px; border-radius:3px; font-size:9px}
    -- .prow.alt{background:#00ff4114}  .pi{color:#00c832}  .pn{color:#b4ffbe}
    local function addNRow(idx, name)
        local rf = Instance.new("Frame", lf)
        rf.Size = UDim2.new(1, 0, 0, 20); rf.LayoutOrder = idx
        rf.BackgroundColor3 = MG
        rf.BackgroundTransparency = (idx % 2 == 1) and (1 - 0.078) or 1
        rf.BorderSizePixel = 0; rf.ZIndex = 22
        Instance.new("UICorner", rf).CornerRadius = UDim.new(0, 3)
        local il = Instance.new("TextLabel", rf)
        il.Size = UDim2.new(0, 14, 1, 0); il.Position = UDim2.new(0, 2, 0, 0)
        il.BackgroundTransparency = 1; il.Text = tostring(idx)
        il.TextColor3 = MGA; il.Font = Enum.Font.Code; il.TextSize = 9; il.ZIndex = 23
        local nl = Instance.new("TextLabel", rf)
        nl.Size = UDim2.new(1, -22, 1, 0); nl.Position = UDim2.new(0, 18, 0, 0)
        nl.BackgroundTransparency = 1; nl.Text = name
        nl.TextColor3 = MVAL; nl.Font = Enum.Font.Code; nl.TextSize = 9
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

-- ── Scroll: native touch on mobile, mouse wheel on desktop ───
local scrollConn = nil
local mouseIn = false
sf.ScrollingEnabled = true
if _isMobile or _isTablet then
    -- touch: ScrollingFrame handles swipe natively, no-op conn keeps scrollConn valid
    scrollConn = UIS.InputChanged:Connect(function() end)
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

-- ── Heartbeat animations ──────────────────────────────
-- scanline: 2.8s for full height sweep (rate = PH/2.8 ≈ 128px/s)
-- rain: scrolls at ~18px/s, wraps at 80px offset
local scanAcc, pulseAcc, blinkAcc, rainAcc = 0, 0, 0, 0
local _fAcc = 0
local hbConn = RS.Heartbeat:Connect(function(dt)
    if not bb.Parent then return end
    _fAcc = _fAcc + dt; if _fAcc < 0.033 then return end; _fAcc = 0  -- ~30fps

    -- scanline sweep (full panel height / 2.8s)
    scanAcc = (scanAcc + dt * (PH / 2.8)) % (PH + 4)
    scan.Position = UDim2.new(0, 0, 0, math.floor(scanAcc) - 3)

    -- pulse border (3s period, like HTML animation:pulse 3s ease-in-out)
    pulseAcc = pulseAcc + dt * (math.pi * 2 / 3)
    local pulse = (math.sin(pulseAcc) + 1) * 0.5  -- 0..1
    -- HTML: 0%,100%→rgba(0,255,65,.8)  50%→rgba(0,255,65,.25)
    mainStroke.Transparency = 0.2 + pulse * 0.55   -- 0.2↔0.75
    -- glow frame entfernt (kein blur in Roblox möglich)

    -- blink dot (1.4s, 0%,100%→opacity:1  50%→opacity:0.2)
    blinkAcc = blinkAcc + dt * (math.pi * 2 / 1.4)
    local blink = (math.sin(blinkAcc) + 1) * 0.5   -- 0..1
    statusDot.BackgroundTransparency = blink * 0.8   -- 0↔0.8

    -- FIX: rain scroll — was 13.3px/s wrapping at 80px (just a micro-wobble).
    -- Text has ~26 lines × 11.6px = ~302px content. Wrap at 302 for one full seamless sweep.
    -- Speed 35px/s → full cycle ≈ 8.6s, matches HTML rainFlow 4s*2 feel.
    rainAcc = rainAcc + dt * 35
    rainLbl.Position = UDim2.new(0, 0, 0, -(rainAcc % 302))
end)

p.CharacterAdded:Connect(function(c)
    task.wait(0.2)
    if outlines[p] then pcall(function() outlines[p].Adornee = c end) end
end)
cards[p] = { gui=bb, hb=hbConn, sc=scrollConn }
end

local function closeCard(p)
    local d = cards[p]; if not d then return end
    pcall(function() d.hb:Disconnect() end)
    pcall(function() d.sc:Disconnect() end)
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
if getgenv then getgenv()._TLRemoveTool = removeTLTool end
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

-- ── F5 Maus-Unlock (Ego-Perspektive: Maus frei bewegen, Perspektive bleibt) ──
-- F5 togglet nur MouseBehavior Default<->LockCenter.
-- Kamera-Typ, Zoom und CameraMode werden NICHT verändert.
do
    local _cursorUnlocked = false
    local _f5Conn    = nil
    local _f5HBConn  = nil
    local _savedMouseBehavior = Enum.MouseBehavior.LockCenter

    local function _applyMouseState(unlock)
        pcall(function()
            if unlock then
                -- Speichere aktuellen Zustand (meistens LockCenter in Ego)
                _savedMouseBehavior = UserInputService.MouseBehavior
                -- Nur Maus freischalten — KEINE Kamera-Änderung
                UserInputService.MouseBehavior   = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            else
                -- Originalzustand wiederherstellen
                UserInputService.MouseBehavior   = _savedMouseBehavior
                UserInputService.MouseIconEnabled = false
            end
        end)
    end

    -- Heartbeat: jeden Frame erzwingen solange aktiv,
    -- damit das Spiel MouseBehavior nicht überschreibt
    _f5HBConn = RunService.Heartbeat:Connect(function()
        if not _cursorUnlocked then return end
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
        end
        if not UserInputService.MouseIconEnabled then
            pcall(function() UserInputService.MouseIconEnabled = true end)
        end
    end)

    _f5Conn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode ~= Enum.KeyCode.F5 then return end
        _cursorUnlocked = not _cursorUnlocked
        _applyMouseState(_cursorUnlocked)
        pcall(function()
            local msg = _cursorUnlocked
                and "🖱 Maus frei [F5] — Perspektive bleibt"
                or  "🔒 Maus gesperrt [F5]"
            if sendNotif then sendNotif("Kamera", msg, 2) end
        end)
    end)

    -- Cleanup on unload
    pcall(function()
        local env = getgenv and getgenv() or _G
        local _prevUnload = env.TLUnload
        env.TLUnload = function()
            if _f5Conn   then pcall(function() _f5Conn:Disconnect()   end) end
            if _f5HBConn then pcall(function() _f5HBConn:Disconnect() end) end
            if _cursorUnlocked then _applyMouseState(false) end
            if _prevUnload then pcall(_prevUnload) end
        end
    end)
end
-- ─────────────────────────────────────────────────────────────────
local function registerKeybind(actionName, defaultKey, callback)
keybinds[actionName] = { key = defaultKey, callback = callback }
end
local keybindLabelUpdaters, SAVE_FILE = {}, "SmartBar_Save.json"
local settingsState = {
soundEnabled  = true,
themeColor    = "matrix",
notifications = true,
showHint      = false,
autoOpen      = false,
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
notif_settings_loaded = "Settings loaded ✓",
notif_saved           = "✓  Saved!",
save_settings         = "💾  Save Settings & Keybinds",
kb_hint               = "Click a key, then press a button  •  Esc to clear",
kb_reset              = "Reset",
profile_online        = "Online",
smartbar_hint         = "Press  K  to open the SmartBar",
qa_nobody             = "Nobody nearby",
qa_title              = "QUICK ACTIONS",
qa_subtitle           = "Select an action",
qa_stopped            = "Stopped",
qa_no_target          = "⚠  No target found",
qa_idle               = "Idle  ·  Select an action",
qa_extras             = "⚡  EXTRAS",
script_active         = "Active",
script_inactive       = "Inactive",
gb_label              = "Gangbang",
gb_player_pill        = "Player...",
gb_target_key         = "TARGET",
gb_no_players         = "No players online",
gb_select_player      = "Select a player first!",
gb_stopped            = "Stopped ✋",
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
rush_running          = "🏃 Rush → ",
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
orbit_respawn         = "Target respawned · Orbit reset! 🌀",
coming_soon           = "coming soon",
no_players_online     = "No players online",
}
local function onLangChange(fn) end
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
local function extractJsonBool(json, key)
local val = json:match('"' .. key .. '":%s*(true|false)')
return val == "true"
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
-- apply saved theme
pcall(function()
if settingsState.themeColor and settingsState.themeColor ~= "matrix" then
_TL_applyTheme(settingsState.themeColor)
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
local function corner(p, r)
Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 16)
end
local function stroke(p, t, col, tr)
local s = Instance.new("UIStroke", p)
s.Thickness  = t or 1.2
s.Color      = col or C.border
s.Transparency = tr or 0.35
return s
end
local function gradStroke(p, t, tr)
local s = Instance.new("UIStroke", p)
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
function addShadow(parent)
task.defer(function()
local s = Instance.new("ImageLabel", ScreenGui)
s.Image = "rbxassetid://1316045217"
s.Size  = UDim2.new(0, parent.Size.X.Offset + 60, 0, parent.Size.Y.Offset + 60)
s.AnchorPoint = parent.AnchorPoint
s.BackgroundTransparency = 1
s.ImageColor3 = C.sub
s.ImageTransparency = 0.72
s.ZIndex = 1
local function syncPos()
s.Position = UDim2.new(
parent.Position.X.Scale,
parent.Position.X.Offset,
parent.Position.Y.Scale,
parent.Position.Y.Offset + 8
)
end
syncPos()
pcall(function() parent:GetPropertyChangedSignal("Position"):Connect(syncPos) end)
pcall(function() parent:GetPropertyChangedSignal("Visible"):Connect(function() end)
s.Visible = parent.Visible
end)
s.Visible = parent.Visible
end)
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
local function rowBg(row, accentColor)
local g = Instance.new("UIGradient", row)
local ac = accentColor or C.accent
g.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0,   Color3.fromRGB(
math.floor(ac.R*255*0.08 + 12),
math.floor(ac.G*255*0.08 + 12),
math.floor(ac.B*255*0.08 + 18)
)),
ColorSequenceKeypoint.new(1,   Color3.fromRGB(12,12,18)),
}
g.Rotation = 0
local bar = Instance.new("Frame", row)
bar.Size = UDim2.new(0, 2, 1, -12)
bar.Position = UDim2.new(0, 0, 0, 6)
bar.BackgroundColor3 = ac
bar.BorderSizePixel = 0
corner(bar, 99)
return bar
end
local function cleanRow(parent, yPos, label, sublabel, col, initOn, onToggle)
local ROW_H = 46
local card = Instance.new("Frame", parent)
card.Size = UDim2.new(1,0,0,ROW_H)
card.Position = UDim2.new(0,0,0,yPos)
card.BackgroundColor3 = C.bg2 or _C3_BG2
card.BackgroundTransparency = 0; card.BorderSizePixel = 0
corner(card, 12)
local cStr = Instance.new("UIStroke", card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local cdot = Instance.new("Frame", card)
cdot.Size = UDim2.new(0,3,0,ROW_H-16)
cdot.Position = UDim2.new(0,0,0.5,-(ROW_H-16)/2)
cdot.BackgroundColor3 = col or C.accent; cdot.BackgroundTransparency = 0.4
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
togTrack.BackgroundColor3 = col or C.accent; togTrack.BackgroundTransparency = 0.55
cStr.Color = col or C.accent; cStr.Transparency = 0.5
end
local togState = initOn or false
local function setToggle(on)
togState = on
if on then
twP(togTrack, 0.15, {BackgroundColor3 = col or C.accent, BackgroundTransparency = 0.55})
twP(togKnob,  0.15, {BackgroundColor3 = _C3_WHITE, Position = UDim2.new(1,-14,0.5,-6)})
twP(cStr,     0.15, {Color = col or C.accent, Transparency = 0.5})
-- ✅ Sound bei Toggle ON
pcall(function()
    local soundService = game:GetService("SoundService")
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://136697607304800"
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 2)
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
btn.MouseButton1Click:Connect(function() setToggle(not togState) end)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then setToggle(not togState) end
end)
btn.MouseEnter:Connect(function()
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
track.BackgroundColor3 = initState and C.green or C.bg3
track.BorderSizePixel  = 0
corner(track, 16)
local ts = stroke(track, 1, initState and C.green or C.borderdim, initState and 0.0 or 0.3)
local knob = Instance.new("Frame", track)
knob.Size             = UDim2.new(0, H-6, 0, H-6)
knob.Position         = initState
and UDim2.new(0, W-(H-6)-3, 0, 3)
or  UDim2.new(0, 3, 0, 3)
knob.BackgroundColor3 = _C3_WHITE
knob.BorderSizePixel  = 0
corner(knob, 99)
local ks = Instance.new("UIStroke", knob)
ks.Thickness = 0.8; ks.Color = _C3_BLACK; ks.Transparency = 0.5
local state = initState
local function setState(on)
state = on
tw(knob, 0.20, {
Position = on and UDim2.new(0, W-(H-6)-3, 0, 3)
or  UDim2.new(0, 3, 0, 3)
}, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
twP(track, 0.18, {BackgroundColor3 = on and C.green or C.bg3})
tw(ts, 0.18, {
Color       = on and C.green or C.borderdim,
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
local SoundService = game:GetService("SoundService")
local s = Instance.new("Sound")
s.SoundId = "rbxassetid://79062163283657"
s.Volume = 0.6
s.Parent = SoundService
s:Play()
game:GetService("Debris"):AddItem(s, 5)
end)
end
end)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        local turningOn = not state
        setState(turningOn)
        if turningOn then
            pcall(function()
                local SoundService = game:GetService("SoundService")
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://79062163283657"
                s.Volume = 0.6; s.Parent = SoundService; s:Play()
                game:GetService("Debris"):AddItem(s, 5)
            end)
        end
    end
end)
return track, setState, function() return state end
end
local function makeNumberField(parent, x, y, w, defaultVal, minVal, maxVal, col, onChange)
local acCol = col or C.accent
local currentVal = math.clamp(math.floor(defaultVal), minVal, maxVal)
local container = Instance.new("Frame", parent)
container.Size             = UDim2.new(0, w + 36, 0, 29)
container.Position         = UDim2.new(0, x - 18, 0, y)
container.BackgroundColor3 = C.bg2
container.BackgroundTransparency = 0
container.BorderSizePixel  = 0
corner(container, 12)
local fs = stroke(container, 1.5, acCol, 0.55)
local cgrad = Instance.new("UIGradient", container)
cgrad.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 22, 9)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 10, 4)),
}
cgrad.Rotation = 90
local minusBtn = Instance.new("TextButton", container)
minusBtn.Size = UDim2.new(0, 24, 1, 0)
minusBtn.Position = UDim2.new(0, 0, 0, 0)
minusBtn.BackgroundTransparency = 1
minusBtn.Text = "−"
minusBtn.Font = Enum.Font.GothamBlack
minusBtn.TextSize = 15
minusBtn.TextColor3 = acCol
minusBtn.BorderSizePixel = 0
minusBtn.ZIndex = 3
local plusBtn = Instance.new("TextButton", container)
plusBtn.Size = UDim2.new(0, 24, 1, 0)
plusBtn.Position = UDim2.new(1, -24, 0, 0)
plusBtn.BackgroundTransparency = 1
plusBtn.Text = "+"
plusBtn.Font = Enum.Font.GothamBlack
plusBtn.TextSize = 15
plusBtn.TextColor3 = acCol
plusBtn.BorderSizePixel = 0
plusBtn.ZIndex = 3
local sepL = Instance.new("Frame", container)
sepL.Size = UDim2.new(0, 1, 0, 16); sepL.Position = UDim2.new(0, 24, 0.5, -8)
sepL.BackgroundColor3 = acCol; sepL.BackgroundTransparency = 0.6; sepL.BorderSizePixel = 0
local sepR = Instance.new("Frame", container)
sepR.Size = UDim2.new(0, 1, 0, 16); sepR.Position = UDim2.new(1, -25, 0.5, -8)
sepR.BackgroundColor3 = acCol; sepR.BackgroundTransparency = 0.6; sepR.BorderSizePixel = 0
local display = Instance.new("TextButton", container)
display.Size = UDim2.new(1, -50, 1, 0)
display.Position = UDim2.new(0, 25, 0, 0)
display.BackgroundTransparency = 1
display.Text = tostring(currentVal)
display.Font = Enum.Font.GothamBlack
display.TextSize = 15
display.TextColor3 = _C3_WHITE
display.BorderSizePixel = 0
display.ZIndex = 2
local input = Instance.new("TextBox", container)
input.Size = UDim2.new(1, -50, 1, 0)
input.Position = UDim2.new(0, 25, 0, 0)
input.BackgroundTransparency = 1
input.Text = ""; input.PlaceholderText = tostring(currentVal)
input.Font = Enum.Font.GothamBold; input.TextSize = 15
input.TextColor3 = acCol; input.BorderSizePixel = 0
input.Visible = false; input.ClearTextOnFocus = true
input.ZIndex = 2
local function applyVal(n)
n = math.clamp(math.floor(n), minVal, maxVal)
currentVal = n
display.Text = tostring(n)
if onChange then onChange(n) end
end
local editing = false
display.MouseButton1Click:Connect(function()
if editing then return end
editing = true
twP(fs, 0.12, {Transparency = 0.1})
twP(container, 0.12, {BackgroundColor3 = C.bg3})
input.Text = display.Text; input.Visible = true; display.Visible = false
input:CaptureFocus()
end)
input.FocusLost:Connect(function()
editing = false
local n = tonumber(input.Text)
if n then applyVal(n) end
input.Visible = false; display.Visible = true
twP(fs, 0.12, {Transparency = 0.55})
twP(container, 0.12, {BackgroundColor3 = C.bg2})
end)
local step = 1
minusBtn.MouseButton1Click:Connect(function() applyVal(currentVal - step) end)
plusBtn.MouseButton1Click:Connect(function()  applyVal(currentVal + step) end)
local function holdRepeat(btn, dir)
btn.MouseButton1Down:Connect(function()
task.delay(0.4, function()
while btn and btn.Parent and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
applyVal(currentVal + dir * step)
task.wait(0.07)
end
end)
end)
end
holdRepeat(minusBtn, -1)
holdRepeat(plusBtn,   1)
for _, b in ipairs({minusBtn, plusBtn}) do
b.MouseEnter:Connect(function() tw(b, 0.1, {TextTransparency = 0.2}):Play() end)
b.MouseLeave:Connect(function() tw(b, 0.1, {TextTransparency = 0}):Play() end)
end
return container, function(v)
applyVal(v)
end
end
local function makeRow(parent, yPos, labelText, badgeText, badgeColor, initOn, onToggle)
return cleanRow(parent, yPos, labelText, badgeText, badgeColor, initOn, onToggle)
end
-- FIX Mobile: Panel-Breite an Bildschirmbreite anpassen
local PANEL_W
do
    local _ok, _vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp = _ok and _vp or Vector2.new(1920, 1080)
    local _touch = pcall(function() return game:GetService("UserInputService").TouchEnabled end)
                   and game:GetService("UserInputService").TouchEnabled
    local _kbd   = pcall(function() return game:GetService("UserInputService").KeyboardEnabled end)
                   and game:GetService("UserInputService").KeyboardEnabled
    local _short = math.min(_vp.X, _vp.Y)
    local _long  = math.max(_vp.X, _vp.Y)
    if _touch and not _kbd then
        -- Mobile/Tablet: Panel darf maximal bis zum rechten Bildschirmrand reichen
        -- SmartBar (VL_W=58) + gap(8) + gap(5) = 71px left offset; leave 8px right margin
        local _maxW = _long - 71 - 8
        PANEL_W = math.min(495, math.max(260, _maxW))
    else
        PANEL_W = 495
    end
end
local panels, panelCreditGrads = {}, {}
local _panelTweens = {}   -- laufender Öffnungs-Tween pro Panel-Name (für Drag-Start cancel)
-- ── Panel-Farbpalette – wird von _TL_applyTheme synchron gehalten ─
local P_MG    = C.accent    -- accent bright  (sync: C.accent)
local P_MGA   = C.accent2  -- accent2 mid    (sync: C.accent2)
local P_MGDIM = C.sub      -- sub dim        (sync: C.sub)
local P_BG    = Color3.fromRGB(1, 8, 3)       -- panel bg (bleibt dunkel)
local P_HDR   = Color3.fromRGB(2, 12, 5)      -- header bg (bleibt dunkel)
-- Hook so _TL_applyTheme keeps P_MG* in sync for newly created panels
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function(newT)
    P_MG    = newT.accent
    P_MGA   = newT.accent2
    P_MGDIM = newT.sub
end

local function makePanel(name, accentDot)
local p = Instance.new("Frame", ScreenGui)
p.Name             = name
p.Size             = UDim2.new(0, PANEL_W, 0, 10)
p.AnchorPoint      = Vector2.new(0, 0)
p.Position         = UDim2.new(0, 71, 0, -(600))  -- 5 (gap) + 58 (VL_W) + 8 (gap)
p.BackgroundColor3 = P_BG
p.BackgroundTransparency = 0
p.BorderSizePixel  = 0
p.Visible          = false
p.ClipsDescendants = true
corner(p, 8)   -- eckiger Matrix-Look, identisch zur SmartBar BAR_R=8

-- Rahmen: UIStroke mit grüner Farbe
local pStroke = Instance.new("UIStroke", p)
pStroke.Thickness       = 1.5
pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pStroke.Color           = P_MG
pStroke.Transparency    = 0.55

-- Top-Border: 2px voller grüner Strich (Variant-C Kennzeichen)
local topBar = Instance.new("Frame", p)
topBar.Size             = UDim2.new(1, 0, 0, 2)
topBar.Position         = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = P_MG
topBar.BackgroundTransparency = 0
topBar.BorderSizePixel  = 0; topBar.ZIndex = 6

-- Header-Bereich: 48px, dunkel mit subtiler Tiefe
local hdr = Instance.new("Frame", p)
hdr.Size             = UDim2.new(1, 0, 0, 48)
hdr.Position         = UDim2.new(0, 0, 0, 0)
hdr.BackgroundColor3 = P_HDR
hdr.BackgroundTransparency = 0
hdr.BorderSizePixel  = 0; hdr.ZIndex = 2
-- Header-Gradient: leicht heller oben → dunkel unten (gibt Tiefe zum Body hin)
local hdrGrad = Instance.new("UIGradient", hdr)
hdrGrad.Rotation = 90
hdrGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(5, 22, 10)),
    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(3, 15,  7)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(2, 10,  4)),
}

-- Header-Separator: 1px grün (unten an hdr)
local sep = Instance.new("Frame", p)
sep.Size             = UDim2.new(1, 0, 0, 1)
sep.Position         = UDim2.new(0, 0, 0, 48)
sep.BackgroundColor3 = P_MG
sep.BackgroundTransparency = 0.45
sep.BorderSizePixel  = 0; sep.ZIndex = 3

-- Rain-Hintergrund im Header (subtil, passend zur SmartBar)
local rainHdr = Instance.new("TextLabel", hdr)
rainHdr.Size             = UDim2.new(1, 0, 1, 0)
rainHdr.Position         = UDim2.new(0, 0, 0, 0)
rainHdr.BackgroundTransparency = 1
rainHdr.Text = "1 0 1 1 0 0 1 0 1 1 0 1 0 1 0 0 1 1 0 1 0 1 1 0 1 0 1 0 1 1 0 0 1 0 1 1 0 1 0 1 1 0 0 1 0 1 0 0 1 1 0 1"
rainHdr.TextColor3       = P_MG
rainHdr.Font             = Enum.Font.Code
rainHdr.TextSize         = 9
rainHdr.TextTransparency = 0.88
rainHdr.TextXAlignment   = Enum.TextXAlignment.Left
rainHdr.TextYAlignment   = Enum.TextYAlignment.Center
rainHdr.ZIndex           = 3

-- Blink-Dot links im Header (wie SmartBar statusDot)
local blinkDot = Instance.new("Frame", hdr)
blinkDot.Size             = UDim2.new(0, 6, 0, 6)
blinkDot.Position         = UDim2.new(0, 14, 0.5, -3)
blinkDot.BackgroundColor3 = P_MG
blinkDot.BackgroundTransparency = 0
blinkDot.BorderSizePixel  = 0; blinkDot.ZIndex = 5
corner(blinkDot, 99)
-- Blink-Animation: synchron mit SmartBar statusDot (1.4s Zyklus)
task.spawn(function()
local acc = 0
while blinkDot.Parent do
task.wait(0.04)
acc = acc + 0.04
local b = (math.sin(acc * math.pi * 2 / 1.4) + 1) * 0.5
blinkDot.BackgroundTransparency = b * 0.8
end
end)

-- Panel-Titel: Code-Font, Matrix-grün
local htitle = Instance.new("TextLabel", hdr)
htitle.Size              = UDim2.new(0, 220, 1, 0)
htitle.Position          = UDim2.new(0, 26, 0, 0)
htitle.BackgroundTransparency = 1
htitle.Text              = "// "..name:upper()
htitle.Font              = Enum.Font.Code
htitle.TextSize          = 14
htitle.TextColor3        = P_MG
htitle.TextXAlignment    = Enum.TextXAlignment.Left
htitle.ZIndex            = 5

-- Credit-Label rechts: dim-grün, Code-Font
local credit = Instance.new("TextLabel", hdr)
credit.Size              = UDim2.new(0, 140, 1, 0)
credit.Position          = UDim2.new(1, -148, 0, 0)
credit.BackgroundTransparency = 1
credit.Text              = "telelumi"
credit.Font              = Enum.Font.Code
credit.TextSize          = 11
credit.TextColor3        = P_MGDIM
credit.TextXAlignment    = Enum.TextXAlignment.Right
credit.ZIndex            = 5
-- Shimmer-Gradient auf Credit (identisch zum SmartBar-shimmer)
local creditGrad = Instance.new("UIGradient", credit)
creditGrad.Rotation = 0
creditGrad.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0,    P_MGDIM),
ColorSequenceKeypoint.new(0.30, P_MGDIM),
ColorSequenceKeypoint.new(0.50, P_MGA),
ColorSequenceKeypoint.new(0.70, P_MGDIM),
ColorSequenceKeypoint.new(1,    P_MGDIM),
}
creditGrad.Offset = Vector2.new(-1.5, 0)
table.insert(panelCreditGrads, creditGrad)
-- ── Body-Struktur: Gradient + Scan-Lines + Glow + innerer Rahmen ───────
-- 1. Vertikaler Gradient auf dem Panel-Body
local bodyGrad = Instance.new("UIGradient", p)
bodyGrad.Rotation = 90
bodyGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(6,  18, 9)),
    ColorSequenceKeypoint.new(0.18, Color3.fromRGB(3,  11, 5)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(1,   7, 3)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,   4, 2)),
}
-- 2. Diagonaler Glow-Schimmer oben-links
local cornerGlow = Instance.new("Frame", p)
cornerGlow.Name = "CornerGlow"
cornerGlow.Size = UDim2.new(0, 180, 0, 80)
cornerGlow.Position = UDim2.new(0, 0, 0, 48)
cornerGlow.BackgroundTransparency = 1
cornerGlow.BorderSizePixel = 0
cornerGlow.ZIndex = 1
local cgGrad = Instance.new("UIGradient", cornerGlow)
cgGrad.Rotation = 135
cgGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, P_MG),
    ColorSequenceKeypoint.new(1, P_BG),
}
cgGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,    0.93),
    NumberSequenceKeypoint.new(0.45, 0.97),
    NumberSequenceKeypoint.new(1,    1),
}
-- 3. Horizontale Scan-Lines (Textur/Tiefe)
local scanLines = Instance.new("TextLabel", p)
scanLines.Name = "ScanLines"
scanLines.Size = UDim2.new(1, 0, 1, -50)
scanLines.Position = UDim2.new(0, 0, 0, 50)
scanLines.BackgroundTransparency = 1
scanLines.BorderSizePixel = 0
scanLines.ZIndex = 1
scanLines.Text = string.rep("──────────────────────────────────────────────────────────────────────────────────────────────────────────────\n", 60)
scanLines.Font = Enum.Font.Code
scanLines.TextSize = 7
scanLines.TextColor3 = P_MG
scanLines.TextTransparency = 0.935
scanLines.TextXAlignment = Enum.TextXAlignment.Left
scanLines.TextYAlignment = Enum.TextYAlignment.Top
-- 4. Innerer Rahmen für den Content-Bereich
local innerBorder = Instance.new("Frame", p)
innerBorder.Name = "InnerBorder"
innerBorder.Size = UDim2.new(1, -10, 1, -62)
innerBorder.Position = UDim2.new(0, 5, 0, 56)
innerBorder.BackgroundTransparency = 1
innerBorder.BorderSizePixel = 0
innerBorder.ZIndex = 2
local ibStroke = Instance.new("UIStroke", innerBorder)
ibStroke.Thickness = 1
ibStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ibStroke.Color = P_MG
ibStroke.Transparency = 0.82
corner(innerBorder, 6)
-- ── Scrollable Content ──────────────────────────────────────────────────
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
-- Scrollbar: grün, rechts
local sbTrack = Instance.new("Frame", p)
sbTrack.Name              = "ScrollTrack"
sbTrack.Size              = UDim2.new(0, 2, 1, -66)
sbTrack.Position          = UDim2.new(1, -6, 0, 58)
sbTrack.BackgroundColor3  = P_MG
sbTrack.BackgroundTransparency = 0.85
sbTrack.BorderSizePixel   = 0
sbTrack.Visible           = false  -- FIX: initially hidden, shown only when content overflows
corner(sbTrack, 99)
local sbThumb = Instance.new("Frame", sbTrack)
sbThumb.BackgroundColor3  = P_MG
sbThumb.BackgroundTransparency = 0.35
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

	-- ── Panel Drag — Direct/Synchronous Implementation ──────────────────────────
	do
	    local dragHint = Instance.new("TextLabel", hdr)
	    dragHint.Size                   = UDim2.new(0, 20, 0, 20)
	    dragHint.Position               = UDim2.new(1, -28, 0.5, -10)
	    dragHint.BackgroundTransparency = 1
	    dragHint.Text                   = "⡀"
	    dragHint.Font                   = Enum.Font.Code
	    dragHint.TextSize               = 14
	    dragHint.TextColor3             = P_MGA
	    dragHint.TextTransparency       = 0.5
	    dragHint.ZIndex                 = 6

	    p.AnchorPoint = Vector2.new(0, 0)

	    local dragging  = false
	    local dragStart = nil
	    local startPos  = nil
	    local targetPos = nil
	    local renderConn   = nil  -- nur aktiv während Drag
	    local inputConn    = nil  -- nur aktiv während Drag

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
	            twP(hdr,      0.08, {BackgroundColor3 = Color3.fromRGB(4, 22, 8)})
	            twP(dragHint, 0.08, {TextTransparency = 0})
	        else
	            twP(hdr,      0.12, {BackgroundColor3 = P_HDR})
	            twP(dragHint, 0.12, {TextTransparency = 0.5})
	        end
	    end

	    local function stopDrag()
	        dragging = false
	        -- RenderStepped und InputChanged nur trennen wenn Drag endet — kein permanenter Overhead
	        if renderConn then pcall(function() renderConn:Disconnect() end); renderConn = nil end
	        if inputConn  then pcall(function() inputConn:Disconnect()  end); inputConn  = nil end
	        updateFeedback(false)
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
	            dragStart = (inp.UserInputType == Enum.UserInputType.Touch)
	                and inp.Position
	                or UserInputService:GetMouseLocation()
	            startPos  = p.Position
	            targetPos = p.Position
	            updateFeedback(true)

	            inp.Changed:Connect(function()
	                if inp.UserInputState == Enum.UserInputState.End then
	                    stopDrag()
	                end
	            end)

	            -- RenderStepped: frame-rate-unabhängiger Lerp (dt-basiert)
	            -- Faktor 22 → alpha ~0.31 bei 60fps (smooth & synchron)
	            -- pcall-Fallback auf Heartbeat falls RenderStepped blockiert (z.B. Solara)
	            if renderConn then pcall(function() renderConn:Disconnect() end) end
	            local _dragFn = function(dt)
	                if not dragging then stopDrag(); return end
	                local alpha = 1 - math.exp(-dt * 22)
	                p.Position = p.Position:Lerp(targetPos, alpha)
	            end
	            local _rOk, _rConn = pcall(function() return RunService.RenderStepped:Connect(_dragFn) end)
	            if _rOk and _rConn then
	                renderConn = _rConn
	            else
	                renderConn = RunService.Heartbeat:Connect(_dragFn)
	            end

	            -- InputChanged NUR beim aktiven Drag registrieren
	            if inputConn then pcall(function() inputConn:Disconnect() end) end
	            inputConn = UserInputService.InputChanged:Connect(function(inp2)
	                if not dragging then return end
	                local t = inp2.UserInputType
	                if t ~= Enum.UserInputType.MouseMovement
	                and t ~= Enum.UserInputType.Touch then return end

	                local cur = (t == Enum.UserInputType.Touch)
	                    and inp2.Position
	                    or UserInputService:GetMouseLocation()
	                local delta = cur - dragStart

	                local nx = startPos.X.Offset + delta.X
	                local ny = startPos.Y.Offset + delta.Y

	                local sw = p.AbsoluteSize.X
	                local sh = p.AbsoluteSize.Y
	                if nx < 0 then nx = 0 elseif nx > viewport.X - sw then nx = viewport.X - sw end
	                if ny < 0 then ny = 0 elseif ny > viewport.Y - sh then ny = viewport.Y - sh end

	                targetPos = UDim2.new(
	                    startPos.X.Scale, nx,
	                    startPos.Y.Scale, ny
	                )
	            end)
	        end
	    end)

	    local hoverTween = nil
	    hdr.MouseEnter:Connect(function()
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
	-- ─────────────────────────────────────────────────────────────────────

panels[name] = p
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
-- ── Forward-declarations (M-1 / M-3 fix) ─────────────────────────────────
-- These upvalues are used by the Invis-Heartbeat and safeStand loops below
-- but are assigned their real values/tables much later in the file.
-- Declaring them here as upvalues ensures the closures capture the correct
-- slot instead of accidentally reading globals (nil).
local ppActive       = false
local _act_following = false
local _SOH           = nil   -- filled at ~10791 (assignment, no new local)
local _AF            = nil   -- filled at ~10915 (assignment, no new local)
-- ──────────────────────────────────────────────────────────────────────────
local invisActive, invisParts, invisHeartConn = false, {}, nil
local _invisSavedCF    = nil
local _invisHealthConn = nil
local _invisHL         = nil
local _hasRenderStepped = pcall(function()
local c = RunService.RenderStepped:Connect(function() end); c:Disconnect()
end)
local function _RSConnect(fn)
if _hasRenderStepped then
local ok, conn = pcall(function() return RunService.RenderStepped:Connect(fn) end)
if ok and conn then return conn end
end
return RunService.Heartbeat:Connect(fn)
end
local function _makeInvisSelfHL(ch)
local ok, hl = pcall(function()
local h = Instance.new("Highlight")
h.Adornee             = ch
h.FillColor           = _C3_WHITE
h.OutlineColor        = Color3.fromRGB(0,210,255)
h.FillTransparency    = 0.5
h.OutlineTransparency = 0.0
h.Parent              = PlayerGui
return h
end)
if ok and hl and hl.Parent then return hl end
local ok2, sb = pcall(function()
local s = Instance.new("SelectionBox")
s.Adornee     = ch:FindFirstChild("HumanoidRootPart") or ch
s.Color3      = Color3.fromRGB(0,210,255)
s.LineThickness = 0.06
s.SurfaceTransparency = 0.85
s.SurfaceColor3 = Color3.fromRGB(0,210,255)
s.Parent      = PlayerGui
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
if invisHeartConn   then pcall(function() invisHeartConn:Disconnect() end);   invisHeartConn   = nil end
if _invisHealthConn then pcall(function() _invisHealthConn:Disconnect() end); _invisHealthConn = nil end
if _invisHL and _invisHL.Parent then pcall(function() _invisHL:Destroy() end); _invisHL = nil end
local ch   = LocalPlayer.Character
local hum  = ch and ch:FindFirstChild("Humanoid")
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
if hum then
pcall(function()
_invisHealthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
if not invisActive then return end
local h2 = _myC and _myC:FindFirstChildOfClass("Humanoid")
if h2 and h2.Health < h2.MaxHealth then
pcall(function() h2.Health = h2.MaxHealth end)
end
end)
end)
end
local _invCachedChar = LocalPlayer.Character
local _invCachedHum  = _invCachedChar and _invCachedChar:FindFirstChild("Humanoid")
local _invCachedRoot = _invCachedChar and _invCachedChar:FindFirstChild("HumanoidRootPart")
invisHeartConn = RunService.Heartbeat:Connect(function()
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
local qaRunning = _AF and (
_AF.kissActive or _AF.lickingActive or _AF.suckingActive or _AF.backshotsActive
or _AF.facefuckActive or _AF.pussySpreadActive or _AF.hugActive or _AF.carryActive
or _AF.orbitActive or _AF.backpackActive or _AF.upsideDownActive or _AF.spinningActive
or _AF.friendActive or _AF.ghostActive or _AF.bbActive or _AF.qa74Active
or _AF.pp2Active or _AF.shoulderSitActive
)
if qaRunning or _act_following or (ppActive) or (_SOH and _SOH.active) then return end
local curCF = r.CFrame
if curCF.Position.Y > -100000 then
_invisSavedCF = curCF
end
local origOff; pcall(function() origOff = h.CameraOffset end)
if not origOff then origOff = Vector3.zero end
pcall(function()
r.CFrame       = CFrame.new(curCF.Position.X, -200000, curCF.Position.Z)
h.CameraOffset = Vector3.new(0, curCF.Position.Y + 200000, 0)
end)
task.spawn(function()
if _hasRenderStepped then
pcall(function() RunService.RenderStepped:Wait() end)
else
task.wait()
end
if not invisActive then return end
local qaNow = _AF and (
_AF.kissActive or _AF.lickingActive or _AF.suckingActive or _AF.backshotsActive
or _AF.facefuckActive or _AF.pussySpreadActive or _AF.hugActive or _AF.carryActive
or _AF.orbitActive or _AF.backpackActive or _AF.upsideDownActive or _AF.spinningActive
or _AF.friendActive or _AF.ghostActive or _AF.bbActive or _AF.qa74Active
or _AF.pp2Active or _AF.shoulderSitActive
)
if qaNow or _act_following or ppActive or (_SOH and _SOH.active) then return end
pcall(function()
r.CFrame       = curCF
h.CameraOffset = origOff
end)
end)
end)
end
local FLY_BASE_SPEED, flyActive, flyConn, flyBodyVel, flyBodyGyro = 150, false, nil, nil, nil
local _flyMutedSounds = {}
local function _flyMuteSounds(on)
local myChar = LocalPlayer.Character
if not myChar then return end
if on then
_flyMutedSounds = {}
local root = myChar:FindFirstChild("HumanoidRootPart")
if root then
for _, s in ipairs(root:GetDescendants()) do
if s:IsA("Sound") then
_flyMutedSounds[#_flyMutedSounds+1] = { s, s.Volume }
s.Volume = 0
end
end
end
for _, s in ipairs(myChar:GetChildren()) do
if s:IsA("Sound") then
_flyMutedSounds[#_flyMutedSounds+1] = { s, s.Volume }
s.Volume = 0
end
end
else
for _, entry in ipairs(_flyMutedSounds) do
pcall(function() entry[1].Volume = entry[2] end)
end
_flyMutedSounds = {}
end
end
local function setFly(on)
flyActive = on
if flyConn     then flyConn:Disconnect();     flyConn     = nil end
if flyBodyVel  then flyBodyVel:Destroy();     flyBodyVel  = nil end
if flyBodyGyro then flyBodyGyro:Destroy();    flyBodyGyro = nil end
if on then
local root = getRootPart()
if not root then flyActive = false; return end
local hum = getHumanoid()
if hum then hum.PlatformStand = true end
_flyMuteSounds(true)
pcall(function()
flyBodyGyro = Instance.new("BodyGyro", root)
flyBodyGyro.MaxTorque = Vector3.new(40000, 40000, 40000)
flyBodyGyro.P         = 20000
end)
pcall(function()
flyBodyVel = Instance.new("BodyVelocity", root)
flyBodyVel.MaxForce = Vector3.new(40000, 40000, 40000)
flyBodyVel.Velocity = Vector3.new(0, 0, 0)
end)
if not flyBodyGyro or not flyBodyVel then
flyActive = false
if hum then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
return
end
local _V3_ZERO = Vector3.zero
local _CF_ROT180Y  = CFrame.Angles(0, math.rad(180), 0)
local _CF_SUCK_ROT = CFrame.Angles(math.rad(15), math.rad(180), 0)
local _V3_UP   = Vector3.new(0, 1, 0)
local _V3_DOWN = Vector3.new(0, -1, 0)
flyConn = RunService.Heartbeat:Connect(function()
    local r = getRootPart()
    if not r or not flyBodyVel or not flyBodyGyro then return end
    local cam = _workspace.CurrentCamera
    if not cam then return end
    local cf    = cam.CFrame
    local look  = cf.LookVector
    local right = cf.RightVector
    local md = _V3_ZERO
    if UserInputService:IsKeyDown(Enum.KeyCode.W)         then md = md + look  end
    if UserInputService:IsKeyDown(Enum.KeyCode.S)         then md = md - look  end
    if UserInputService:IsKeyDown(Enum.KeyCode.A)         then md = md - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.D)         then md = md + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then md = md + _V3_UP   end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md = md + _V3_DOWN end
    flyBodyVel.Velocity = (md.Magnitude > 0 and md.Unit or md) * FLY_BASE_SPEED
    flyBodyGyro.CFrame  = CFrame.new(r.Position, r.Position + look)
end)
else
_flyMuteSounds(false)
local hum = getHumanoid()
local anyActionActive = _SOH and _SOH.active or ppActive or
(_AF and (_AF.orbitActive or _AF.kissActive or _AF.lickingActive or _AF.suckingActive
or _AF.backshotsActive or _AF.backpackActive or _AF.upsideDownActive or _AF.friendActive
or _AF.spinningActive or _AF.pussySpreadActive or _AF.hugActive or _AF.qa74Active
or _AF.facefuckActive or _AF.pp2Active or _AF.ghostActive or _AF.bbActive
or _AF.carryActive or _AF.shoulderSitActive)) or false
if hum and not anyActionActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
end
end
local noclipActive, _espRadConn = false, nil
local function toggleNoclip()
noclipActive = not noclipActive
setNoclip(noclipActive)
end
local espData    = {}
local espCharConns = {}
local espEnabled = false
local ESP_COLORS = {
{ name = "White",    color = _C3_WHITE },
{ name = "Red",     color = _C3_DRED },
{ name = "Green",    color = Color3.fromRGB(60,230,100) },
{ name = "Blue",    color = Color3.fromRGB(60,140,255) },
{ name = "Cyan",    color = Color3.fromRGB(0,220,220) },
{ name = "Pink",    color = Color3.fromRGB(255,100,200) },
{ name = "Orange",  color = Color3.fromRGB(255,160,40) },
{ name = "Yellow",    color = Color3.fromRGB(255,230,40) },
{ name = "Purple",    color = Color3.fromRGB(180,80,255) },
{ name = "Black", color = Color3.fromRGB(20,20,20) },
}
local espColorIdx      = 1
local ESP_NEAR_DIST_SQ = 110 * 110
local ESP_NAME_DIST_SQ = 110 * 110
local ESP_FILL_NEAR    = 0.6
local ESP_FILL_FAR     = 1.0
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
hl.LineThickness    = 0.05
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
-- Verbindung immer (neu) setzen, auch wenn bereits ein Eintrag existiert
if espCharConns[pl] then pcall(function() espCharConns[pl]:Disconnect() end) end
espCharConns[pl] = pl.CharacterAdded:Connect(function(char)
-- cachedRoot invalidieren damit der Heartbeat-Loop ihn neu holt
if espData[pl] then espData[pl].cachedRoot = nil end
task.wait(0.15)
applyESPToChar(pl, char)
end)
-- Nur überspringen wenn bereits vollständige Daten mit gültigem Highlight vorhanden
if espData[pl] and espData[pl].hl and espData[pl].hl.Parent then return end
espData[pl] = {}
if pl.Character then
applyESPToChar(pl, pl.Character)
else
-- Character noch nicht da: warten und nochmal versuchen
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
local acc = 0.25
local _espMyRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
LocalPlayer.CharacterAdded:Connect(function(char)
task.wait(0.1)
_espMyRoot = char:FindFirstChild("HumanoidRootPart")
end)
_espRadConn = RunService.Heartbeat:Connect(function(dt)
if not espEnabled then return end
_espAcc = (_espAcc or 0) + dt
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
local _NS = {stack={}, W=288, H=64, GAP=8, PAD_R=16, PAD_B=40}
local _notifCategoryActive, _notifCategoryQueue = {}, {}
local function _notifRestack()
local baseY = 1
for i = #_NS.stack, 1, -1 do
local entry = _NS.stack[i]
if entry and entry.frame and entry.frame.Parent then
local targetY = UDim2.new(1, _NS.PAD_R, baseY, -_NS.PAD_B - _NS.H * (#_NS.stack - i + 1) - _NS.GAP * (#_NS.stack - i))
TweenService:Create(entry.frame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
{Position = targetY}):Play()
end
end
end
local function _showNotifNow(title, text, dur, accentOverride)
task.spawn(function()
local TS2 = TweenService or game:GetService("TweenService")
local notifGui = Instance.new("ScreenGui")
notifGui.Name           = "TLNotif_" .. tostring(os.clock())
notifGui.ResetOnSpawn   = false
notifGui.DisplayOrder   = 99999
notifGui.IgnoreGuiInset = true
_tryParentGui(notifGui)
local ac = accentOverride or C.accent
local frame = Instance.new("Frame", notifGui)
frame.Size            = UDim2.new(0, _NS.W, 0, _NS.H)
frame.AnchorPoint     = Vector2.new(1, 1)
frame.Position        = UDim2.new(1, _NS.W + _NS.PAD_R, 1, -_NS.PAD_B)
frame.BackgroundColor3 = C.bg2
frame.BackgroundTransparency = 0.06
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)
gradStroke(frame, 1.5, 0.20)
local fg = Instance.new("UIGradient", frame)
fg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, C.bg2),
ColorSequenceKeypoint.new(1, Color3.fromRGB(
math.clamp(C.bg2.R*255 - 4, 0, 255),
math.clamp(C.bg2.G*255 - 6, 0, 255),
math.clamp(C.bg2.B*255 - 8, 0, 255)
)),
}
fg.Rotation = 135
local shimmer = Instance.new("Frame", frame)
shimmer.Size             = UDim2.new(1, -24, 0, 1)
shimmer.Position         = UDim2.new(0, 12, 0, 0)
shimmer.BackgroundColor3 = _C3_WHITE
shimmer.BackgroundTransparency = 0.88
shimmer.BorderSizePixel  = 0
Instance.new("UICorner", shimmer).CornerRadius = UDim.new(0, 99)
local shimG = Instance.new("UIGradient", shimmer)
shimG.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
ColorSequenceKeypoint.new(0.3, Color3.new(1,1,1)),
ColorSequenceKeypoint.new(0.7, Color3.new(1,1,1)),
ColorSequenceKeypoint.new(1, Color3.new(0,0,0)),
}
local acBar = Instance.new("Frame", frame)
acBar.Size             = UDim2.new(0, 3, 0, _NS.H - 20)
acBar.Position         = UDim2.new(0, 10, 0.5, -(_NS.H - 20)/2)
acBar.BackgroundColor3 = ac
acBar.BorderSizePixel  = 0
Instance.new("UICorner", acBar).CornerRadius = UDim.new(0, 99)
local abg = Instance.new("UIGradient", acBar)
abg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, C.gradL),
ColorSequenceKeypoint.new(1, C.gradR),
}
abg.Rotation = 90
local iconDot = Instance.new("Frame", frame)
iconDot.Size             = UDim2.new(0, 6, 0, 6)
iconDot.Position         = UDim2.new(0, 22, 0, 14)
iconDot.BackgroundColor3 = ac
iconDot.BorderSizePixel  = 0
Instance.new("UICorner", iconDot).CornerRadius = UDim.new(0, 99)
local idg = Instance.new("UIGradient", iconDot)
idg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, C.gradL),
ColorSequenceKeypoint.new(1, C.gradR),
}
local titleLbl = Instance.new("TextLabel", frame)
titleLbl.Size             = UDim2.new(1, -42, 0, 20)
titleLbl.Position         = UDim2.new(0, 34, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = title
titleLbl.Font             = Enum.Font.GothamBlack
titleLbl.TextSize = 15
titleLbl.TextColor3       = C.text
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
local textLbl = Instance.new("TextLabel", frame)
textLbl.Size             = UDim2.new(1, -42, 0, 16)
textLbl.Position         = UDim2.new(0, 34, 0, 30)
textLbl.BackgroundTransparency = 1
textLbl.Text             = text
textLbl.Font             = Enum.Font.GothamBold
textLbl.TextSize = 15
textLbl.TextColor3       = C.sub
textLbl.TextXAlignment   = Enum.TextXAlignment.Left
textLbl.TextTruncate     = Enum.TextTruncate.AtEnd
local barTrack = Instance.new("Frame", frame)
barTrack.Size             = UDim2.new(1, -20, 0, 2)
barTrack.Position         = UDim2.new(0, 10, 1, -5)
barTrack.BackgroundColor3 = C.bg3
barTrack.BackgroundTransparency = 0.4
barTrack.BorderSizePixel  = 0
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 99)
local barFill = Instance.new("Frame", barTrack)
barFill.Size             = UDim2.new(1, 0, 1, 0)
barFill.BackgroundColor3 = ac
barFill.BorderSizePixel  = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 99)
local bfg = Instance.new("UIGradient", barFill)
bfg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, C.gradL),
ColorSequenceKeypoint.new(1, C.gradR),
}
local entry = { frame = frame, gui = notifGui }
table.insert(_NS.stack, entry)
local stackIdx = #_NS.stack
_notifRestack()
local myTargetY = UDim2.new(1, -_NS.PAD_R, 1,
-_NS.PAD_B - (_NS.H + _NS.GAP) * (stackIdx - 1))
frame.Position = UDim2.new(1, _NS.W + _NS.PAD_R, 1,
-_NS.PAD_B - (_NS.H + _NS.GAP) * (stackIdx - 1))
TS2:Create(frame, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
{Position = myTargetY}):Play()
task.wait(0.35)
TS2:Create(barFill, TweenInfo.new(dur or 3, Enum.EasingStyle.Linear),
{Size = UDim2.new(0, 0, 1, 0)}):Play()
task.wait(dur or 3)
TS2:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
{Position = UDim2.new(1, _NS.W + _NS.PAD_R, frame.Position.Y.Scale, frame.Position.Y.Offset)}):Play()
task.wait(0.25)
for i, e in ipairs(_NS.stack) do
if e == entry then table.remove(_NS.stack, i); break end
end
_notifRestack()
pcall(function() notifGui:Destroy() end)
local q = _notifCategoryQueue[title]
if q and #q > 0 then
local next = table.remove(q, 1)
_showNotifNow(title, next.text, next.dur, next.accentOverride)
else
_notifCategoryActive[title] = nil
end
end)
end
local function sendNotif(title, text, dur, accentOverride)
if not settingsState.notifications then return end
if _notifCategoryActive[title] then
if not _notifCategoryQueue[title] then
_notifCategoryQueue[title] = {}
end
_notifCategoryQueue[title] = { {text = text, dur = dur, accentOverride = accentOverride} }
else
_notifCategoryActive[title] = true
_showNotifNow(title, text, dur, accentOverride)
end
end
pcall(function()
if getgenv then
getgenv().TLSendNotif = sendNotif
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
sendNotif("⚠️ Moderator", pl.Name .. " ist im Spiel", 6, Color3.fromRGB(255,200,80))
end
end
Players.PlayerAdded:Connect(function(pl)
if staffList[pl.Name] then
sendNotif("⚠️ Moderator", "Moderator joined the game", 6, Color3.fromRGB(255,200,80))
end
end)
end
end
do
local p, c = makePanel("Home", C.accent)
local HOME_COL = Color3.fromRGB(1,8,3)
p.BackgroundColor3   = HOME_COL
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
ch.BackgroundColor3 = HOME_COL
ch.BackgroundTransparency = 0
local g = ch:FindFirstChildOfClass("UIGradient"); if g then g:Destroy() end
end
end
local PAD   = 16
local PW    = PANEL_W - PAD * 2
local Y     = 14
local AV_SIZE = 52
local avBg = Instance.new("Frame", c)
avBg.Size             = UDim2.new(0, AV_SIZE, 0, AV_SIZE)
avBg.Position         = UDim2.new(0, PAD, 0, Y)
avBg.BackgroundColor3 = C.bg3 or _C3_BG4
avBg.BackgroundTransparency = 0
avBg.BorderSizePixel  = 0
corner(avBg, 99)
local avRing = Instance.new("UIStroke", avBg)
avRing.Thickness = 1.5; avRing.Color = C.accent; avRing.Transparency = 0.45
local avClip = Instance.new("Frame", avBg)
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
local TX = PAD + AV_SIZE + 12
local nameLbl = Instance.new("TextLabel", c)
nameLbl.Size = UDim2.new(0, PW - AV_SIZE - 12, 0, 22)
nameLbl.Position = UDim2.new(0, TX, 0, Y + 3)
nameLbl.BackgroundTransparency = 1
nameLbl.Text = LocalPlayer.DisplayName
nameLbl.Font = Enum.Font.GothamBlack; nameLbl.TextSize = 16
nameLbl.TextColor3 = C.text or Color3.fromRGB(230,232,245)
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
local tagLbl = Instance.new("TextLabel", c)
tagLbl.Size = UDim2.new(0, PW - AV_SIZE - 12, 0, 16)
tagLbl.Position = UDim2.new(0, TX, 0, Y + 27)
tagLbl.BackgroundTransparency = 1
tagLbl.Text = "@" .. LocalPlayer.Name
tagLbl.Font = Enum.Font.GothamBold; tagLbl.TextSize = 11
tagLbl.TextColor3 = C.sub or Color3.fromRGB(0,140,38)
tagLbl.TextXAlignment = Enum.TextXAlignment.Left
local dotF = Instance.new("Frame", c)
dotF.Size = UDim2.new(0,6,0,6); dotF.Position = UDim2.new(0, TX, 0, Y+48)
dotF.BackgroundColor3 = C.green; dotF.BackgroundTransparency = 0
dotF.BorderSizePixel = 0; corner(dotF, 99)
local onLbl = Instance.new("TextLabel", c)
onLbl.Size = UDim2.new(0,80,0,14); onLbl.Position = UDim2.new(0, TX+10, 0, Y+44)
onLbl.BackgroundTransparency = 1; onLbl.Text = "Online"
onLbl.Font = Enum.Font.GothamBold; onLbl.TextSize = 11
onLbl.TextColor3 = C.green; onLbl.TextXAlignment = Enum.TextXAlignment.Left
local verF = Instance.new("Frame", c)
verF.Size = UDim2.new(0,62,0,22)
verF.Position = UDim2.new(1,-PAD-62, 0, Y+15)
verF.BackgroundColor3 = C.accent; verF.BackgroundTransparency = 0.86
verF.BorderSizePixel = 0; corner(verF, 6)
local verStr = Instance.new("UIStroke", verF)
verStr.Thickness = 1; verStr.Color = C.accent; verStr.Transparency = 0.55
local verLbl = Instance.new("TextLabel", verF)
verLbl.Size = UDim2.new(1,0,1,0); verLbl.BackgroundTransparency = 1
verLbl.Text = "TLMenu"; verLbl.Font = Enum.Font.GothamBlack; verLbl.TextSize = 11
verLbl.TextColor3 = C.accent; verLbl.TextXAlignment = Enum.TextXAlignment.Center
Y = Y + AV_SIZE + 18
local function divider(yPos)
local d = Instance.new("Frame", c)
d.Size = UDim2.new(1,-PAD*2,0,1); d.Position = UDim2.new(0,PAD,0,yPos)
d.BackgroundColor3 = C.bg3 or _C3_BG4
d.BackgroundTransparency = 0.2; d.BorderSizePixel = 0
end
divider(Y); Y = Y + 14
local CHIP_H   = 54
local CHIP_GAP = 8
local CHIP_W   = math.floor((PANEL_W - PAD*2 - CHIP_GAP*2) / 3)
local statDefs = {
{ label="FPS",     icon="⚡", col=C.green,  key="fps"     },
{ label="Ping",    icon="📡", col=C.accent, key="ping"    },
{ label="Players", icon="👥", col=C.orange or Color3.fromRGB(255,155,60), key="players" },
}
local homeStatLabels = {}
for i, stat in ipairs(statDefs) do
local xOff = PAD + (i-1) * (CHIP_W + CHIP_GAP)
local chip = Instance.new("Frame", c)
chip.Size = UDim2.new(0, CHIP_W, 0, CHIP_H)
chip.Position = UDim2.new(0, xOff, 0, Y)
chip.BackgroundColor3 = C.bg2 or _C3_BG2
chip.BackgroundTransparency = 0; chip.BorderSizePixel = 0
corner(chip, 12)
local chipStr = Instance.new("UIStroke", chip)
chipStr.Thickness = 1
chipStr.Color = C.bg3 or _C3_BG3
chipStr.Transparency = 0.3
local cdot = Instance.new("Frame", chip)
cdot.Size = UDim2.new(0,4,0,4); cdot.Position = UDim2.new(0,10,0,10)
cdot.BackgroundColor3 = stat.col; cdot.BackgroundTransparency = 0
cdot.BorderSizePixel = 0; corner(cdot, 99)
local valL = Instance.new("TextLabel", chip)
valL.Size = UDim2.new(1,-12,0,22); valL.Position = UDim2.new(0,10,0,16)
valL.BackgroundTransparency = 1; valL.Text = "—"
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
    if _homeSvcStats then _homeStatPingItem = _homeSvcStats.Network.ServerStatsItem["Data Ping"] end
end)
local _homeMaxPlayers = game.Players.MaxPlayers
_tlTrackConn(RunService.Heartbeat:Connect(function(dt)
if not _tlAlive() or not p.Visible then return end
_ff = _ff + 1; _fa = _fa + dt
if _fa >= 0.25 then
local fps = _mfloor(_ff / _fa); _fa = 0; _ff = 0
local l = homeStatLabels["fps"]
if l and l.Parent then
l.Text = fps .. " FPS"
l.TextColor3 = fps >= 55 and C.green or (fps >= 30 and C.orange or C.red)
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
lping.TextColor3 = v < 80 and C.green or (v < 150 and C.orange or C.red)
end
end
end
end))
Y = Y + CHIP_H + 18
divider(Y); Y = Y + 14
local saveBtn = Instance.new("TextButton", c)
saveBtn.Size = UDim2.new(1,-PAD*2,0,40)
saveBtn.Position = UDim2.new(0,PAD,0,Y)
saveBtn.BackgroundColor3 = C.accent
saveBtn.BackgroundTransparency = 0; saveBtn.BorderSizePixel = 0
saveBtn.Text = ""; saveBtn.ZIndex = 5; corner(saveBtn, 10)
local saveLbl = Instance.new("TextLabel", saveBtn)
saveLbl.Size = UDim2.new(1,0,1,0); saveLbl.BackgroundTransparency = 1
saveLbl.Text = T.save_settings; saveLbl.Font = Enum.Font.GothamBlack; saveLbl.TextSize = 13
saveLbl.TextColor3 = _C3_WHITE
saveLbl.TextXAlignment = Enum.TextXAlignment.Center
saveBtn.MouseEnter:Connect(function() tw(saveBtn,0.1,{BackgroundTransparency=0.18}):Play() end)
saveBtn.MouseLeave:Connect(function() tw(saveBtn,0.1,{BackgroundTransparency=0.0}):Play() end)
saveBtn.MouseButton1Click:Connect(function()
twP(saveBtn,0.06,{BackgroundTransparency=0.35},Enum.EasingStyle.Linear)
task.delay(0.06, function() tw(saveBtn,0.2,{BackgroundTransparency=0}):Play() end)
saveData()
local orig = saveLbl.Text
saveLbl.Text = "Saved ✓"
task.delay(2, function() pcall(function() saveLbl.Text = orig end) end)
end)
saveBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        twP(saveBtn,0.06,{BackgroundTransparency=0.35},Enum.EasingStyle.Linear)
        task.delay(0.06, function() tw(saveBtn,0.2,{BackgroundTransparency=0}):Play() end)
        saveData()
        local orig = saveLbl.Text
        saveLbl.Text = "Saved ✓"
        task.delay(2, function() pcall(function() saveLbl.Text = orig end) end)
    end
end)
Y = Y + 40 + 14
local dcRow = Instance.new("Frame", c)
dcRow.Size = UDim2.new(1,-PAD*2,0,44)
dcRow.Position = UDim2.new(0,PAD,0,Y)
dcRow.BackgroundColor3 = C.bg2 or _C3_BG2
dcRow.BackgroundTransparency = 0; dcRow.BorderSizePixel = 0; corner(dcRow, 10)
local dcStr = Instance.new("UIStroke", dcRow)
dcStr.Thickness = 1; dcStr.Color = C.accent2; dcStr.Transparency = 0.55
local dcIco = Instance.new("TextLabel", dcRow)
dcIco.Size = UDim2.new(0,30,1,0); dcIco.Position = UDim2.new(0,10,0,0)
dcIco.BackgroundTransparency = 1; dcIco.Text = "🎮"
dcIco.Font = Enum.Font.GothamBlack; dcIco.TextSize = 18
dcIco.TextXAlignment = Enum.TextXAlignment.Center
local dcTxtF = Instance.new("Frame", dcRow)
dcTxtF.Size = UDim2.new(1,-50,1,0); dcTxtF.Position = UDim2.new(0,44,0,0)
dcTxtF.BackgroundTransparency = 1; dcTxtF.BorderSizePixel = 0
local dcTitle = Instance.new("TextLabel", dcTxtF)
dcTitle.Size = UDim2.new(1,0,0,18); dcTitle.Position = UDim2.new(0,0,0,5)
dcTitle.BackgroundTransparency = 1; dcTitle.Text = "Discord Server"
dcTitle.Font = Enum.Font.GothamBlack; dcTitle.TextSize = 12
dcTitle.TextColor3 = C.text or _C3_TEXT3
dcTitle.TextXAlignment = Enum.TextXAlignment.Left
local dcSub = Instance.new("TextLabel", dcTxtF)
dcSub.Size = UDim2.new(1,0,0,14); dcSub.Position = UDim2.new(0,0,0,22)
dcSub.BackgroundTransparency = 1; dcSub.Text = "discord.gg/tXHG8jyxpb"
dcSub.Font = Enum.Font.GothamBold; dcSub.TextSize = 10
dcSub.TextColor3 = C.sub
dcSub.TextXAlignment = Enum.TextXAlignment.Left
local dcBtn = Instance.new("TextButton", dcRow)
dcBtn.Size = UDim2.new(1,0,1,0); dcBtn.BackgroundTransparency = 1
dcBtn.Text = ""; dcBtn.ZIndex = 8
dcBtn.MouseEnter:Connect(function() tw(dcRow,0.1,{BackgroundColor3 = C.bg3 or _C3_BG4}):Play() end)
dcBtn.MouseLeave:Connect(function() tw(dcRow,0.1,{BackgroundColor3 = C.bg2 or _C3_BG2}):Play() end)
dcBtn.MouseButton1Click:Connect(function()
pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/tXHG8jyxpb") end)
end)
dcBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        pcall(function() game:GetService("GuiService"):OpenBrowserWindow("https://discord.gg/tXHG8jyxpb") end)
    end
end)
Y = Y + 44 + 14
p.Size = UDim2.new(0, PANEL_W, 0, Y)
end
local createScriptWidget
do
local p, c = makePanel("Character", C.green)
p.BackgroundColor3 = Color3.fromRGB(1,8,3)
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
local card = Instance.new("Frame", c)
card.Size = UDim2.new(1,-PAD*2,0,CARD_H)
card.Position = UDim2.new(0,PAD,0,yPos)
card.BackgroundColor3 = C.bg2 or _C3_BG2
card.BackgroundTransparency = 0; card.BorderSizePixel = 0
corner(card, 12)
local cStr = Instance.new("UIStroke", card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local cdot = Instance.new("Frame", card)
cdot.Size = UDim2.new(0,3,0,CARD_H-20)
cdot.Position = UDim2.new(0,0,0.5,-(CARD_H-20)/2)
cdot.BackgroundColor3 = col; cdot.BackgroundTransparency = 0.4
cdot.BorderSizePixel = 0; corner(cdot, 99)
local nameLbl = Instance.new("TextLabel", card)
nameLbl.Size = UDim2.new(0,120,0,18); nameLbl.Position = UDim2.new(0,14,0,8)
nameLbl.BackgroundTransparency = 1; nameLbl.Text = label
nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = C.text or _C3_TEXT3
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
local subLbl = Instance.new("TextLabel", card)
subLbl.Size = UDim2.new(0,120,0,13); subLbl.Position = UDim2.new(0,14,0,26)
subLbl.BackgroundTransparency = 1; subLbl.Text = sublabel
subLbl.Font = Enum.Font.GothamBold; subLbl.TextSize = 9
subLbl.TextColor3 = C.sub or _C3_SUB
subLbl.TextXAlignment = Enum.TextXAlignment.Left
local valLbl = Instance.new("TextLabel", card)
valLbl.Size = UDim2.new(0,52,0,18); valLbl.Position = UDim2.new(1,-100,0,8)
valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(vDef)
valLbl.Font = Enum.Font.GothamBlack; valLbl.TextSize = 13
valLbl.TextColor3 = col; valLbl.TextXAlignment = Enum.TextXAlignment.Left
local rstBtn = Instance.new("TextButton", card)
rstBtn.Size = UDim2.new(0,30,0,22); rstBtn.Position = UDim2.new(1,-136,0,5)
rstBtn.BackgroundColor3 = C.bg3 or _C3_BG3
rstBtn.BackgroundTransparency = 0.2; rstBtn.BorderSizePixel = 0
rstBtn.Text = "R"; rstBtn.Font = Enum.Font.GothamBold; rstBtn.TextSize = 12
rstBtn.TextColor3 = C.sub or _C3_SUB2
rstBtn.ZIndex = 8; corner(rstBtn, 6)
local rstStr = Instance.new("UIStroke", rstBtn)
rstStr.Thickness = 1; rstStr.Color = C.bg3 or Color3.fromRGB(0,80,20); rstStr.Transparency = 0.4
rstBtn.MouseEnter:Connect(function()
twP(rstBtn, 0.1, {BackgroundColor3 = col, BackgroundTransparency = 0.75})
rstBtn.TextColor3 = col
rstStr.Color = col; rstStr.Transparency = 0.5
end)
rstBtn.MouseLeave:Connect(function()
twP(rstBtn, 0.1, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
rstBtn.TextColor3 = C.sub or _C3_SUB2
rstStr.Color = C.bg3 or Color3.fromRGB(0,80,20); rstStr.Transparency = 0.4
end)
local togTrack = Instance.new("Frame", card)
togTrack.Size = UDim2.new(0,32,0,18); togTrack.Position = UDim2.new(1,-46,0,10)
togTrack.BackgroundColor3 = C.bg3 or _C3_BG3
togTrack.BackgroundTransparency = 0.2; togTrack.BorderSizePixel = 0; corner(togTrack, 99)
local togKnob = Instance.new("Frame", togTrack)
togKnob.Size = UDim2.new(0,12,0,12); togKnob.Position = UDim2.new(0,2,0.5,-6)
togKnob.BackgroundColor3 = _C3_SUB2
togKnob.BackgroundTransparency = 0; togKnob.BorderSizePixel = 0; corner(togKnob, 99)
local TRACK_W = PW - 28
local track = Instance.new("Frame", card)
track.Size = UDim2.new(1,-28,0,4); track.Position = UDim2.new(0,14,1,-14)
track.BackgroundColor3 = C.bg3 or _C3_BG3
track.BackgroundTransparency = 0.2; track.BorderSizePixel = 0; corner(track, 99)
local fill = Instance.new("Frame", track)
fill.Size = UDim2.new((vDef-vMin)/(vMax-vMin),0,1,0)
fill.BackgroundColor3 = col; fill.BackgroundTransparency = 0
fill.BorderSizePixel = 0; corner(fill, 99)
local knob = Instance.new("Frame", track)
knob.Size = UDim2.new(0,12,0,12)
knob.Position = UDim2.new((vDef-vMin)/(vMax-vMin),-6,0.5,-6)
knob.BackgroundColor3 = Color3.fromRGB(240,242,255)
knob.BackgroundTransparency = 0; knob.BorderSizePixel = 0; knob.ZIndex = 5; corner(knob, 99)
local kStr = Instance.new("UIStroke", knob); kStr.Thickness = 1.5; kStr.Color = col; kStr.Transparency = 0
local dragging, togState = false, false
local curVal = vDef
local function applyRatio(ratio)
ratio = math.clamp(ratio, 0, 1)
curVal = math.floor(vMin + ratio*(vMax-vMin))
fill.Size = UDim2.new(ratio,0,1,0)
knob.Position = UDim2.new(ratio,-6,0.5,-6)
valLbl.Text = tostring(curVal)
if onSlide then onSlide(curVal, togState) end
end
local sliderBtn = Instance.new("TextButton", track)
sliderBtn.Size = UDim2.new(1,12,1,12); sliderBtn.Position = UDim2.new(0,-6,0,-4)
sliderBtn.BackgroundTransparency = 1; sliderBtn.Text = ""; sliderBtn.ZIndex = 6
sliderBtn.MouseButton1Down:Connect(function(x)
dragging = true
applyRatio((x - track.AbsolutePosition.X) / track.AbsoluteSize.X)
end)
sliderBtn.MouseMoved:Connect(function(x)
if dragging then applyRatio((x - track.AbsolutePosition.X) / track.AbsoluteSize.X) end
end)
sliderBtn.MouseButton1Up:Connect(function() dragging = false end)
sliderBtn.MouseLeave:Connect(function() dragging = false end)
local function setToggle(on)
togState = on
if on then
twP(togTrack, 0.15, {BackgroundColor3 = col, BackgroundTransparency = 0.55})
tw(togKnob,  0.15, {BackgroundColor3 = _C3_WHITE,
Position = UDim2.new(1,-14,0.5,-6)}):Play()
twP(cStr,     0.15, {Color = col, Transparency = 0.5})
-- ✅ Sound bei Toggle ON
pcall(function()
    local soundService = game:GetService("SoundService")
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://136697607304800"
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 2)
end)
else
twP(togTrack, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
tw(togKnob,  0.15, {BackgroundColor3 = _C3_SUB2,
Position = UDim2.new(0,2,0.5,-6)}):Play()
twP(cStr,     0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.3})
end
if onToggle then onToggle(on, curVal) end
end
local togBtn = Instance.new("TextButton", card)
togBtn.Size = UDim2.new(0,44,0,28); togBtn.Position = UDim2.new(1,-50,0,6)
togBtn.BackgroundTransparency = 1; togBtn.Text = ""; togBtn.ZIndex = 7
togBtn.MouseButton1Click:Connect(function() setToggle(not togState) end)
togBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then setToggle(not togState) end
end)
rstBtn.MouseButton1Click:Connect(function()
applyRatio((vDef-vMin)/(vMax-vMin))
if onReset then onReset(curVal) end
end)
rstBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        applyRatio((vDef-vMin)/(vMax-vMin))
        if onReset then onReset(curVal) end
    end
end)
return card, setToggle, function() return curVal end
end
local TOG_H = 46
local function makeToggleRow(yPos, label, sublabel, col, onToggle)
local card = Instance.new("Frame", c)
card.Size = UDim2.new(1,-PAD*2,0,TOG_H)
card.Position = UDim2.new(0,PAD,0,yPos)
card.BackgroundColor3 = C.bg2 or _C3_BG2
card.BackgroundTransparency = 0; card.BorderSizePixel = 0
corner(card, 12)
local cStr = Instance.new("UIStroke", card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local cdot = Instance.new("Frame", card)
cdot.Size = UDim2.new(0,3,0,TOG_H-16)
cdot.Position = UDim2.new(0,0,0.5,-(TOG_H-16)/2)
cdot.BackgroundColor3 = col; cdot.BackgroundTransparency = 0.4
cdot.BorderSizePixel = 0; corner(cdot, 99)
local nameLbl = Instance.new("TextLabel", card)
nameLbl.Size = UDim2.new(1,-60,0,18); nameLbl.Position = UDim2.new(0,14,0,7)
nameLbl.BackgroundTransparency = 1; nameLbl.Text = label
nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = C.text or _C3_TEXT3
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
local subLbl = Instance.new("TextLabel", card)
subLbl.Size = UDim2.new(1,-60,0,13); subLbl.Position = UDim2.new(0,14,0,25)
subLbl.BackgroundTransparency = 1; subLbl.Text = sublabel
subLbl.Font = Enum.Font.GothamBold; subLbl.TextSize = 9
subLbl.TextColor3 = C.sub or _C3_SUB
subLbl.TextXAlignment = Enum.TextXAlignment.Left
local togTrack = Instance.new("Frame", card)
togTrack.Size = UDim2.new(0,32,0,18); togTrack.Position = UDim2.new(1,-46,0.5,-9)
togTrack.BackgroundColor3 = C.bg3 or _C3_BG3
togTrack.BackgroundTransparency = 0.2; togTrack.BorderSizePixel = 0; corner(togTrack, 99)
local togKnob = Instance.new("Frame", togTrack)
togKnob.Size = UDim2.new(0,12,0,12); togKnob.Position = UDim2.new(0,2,0.5,-6)
togKnob.BackgroundColor3 = _C3_SUB2
togKnob.BackgroundTransparency = 0; togKnob.BorderSizePixel = 0; corner(togKnob, 99)
local togState = false
local function setToggle(on)
togState = on
if on then
twP(togTrack, 0.15, {BackgroundColor3 = col, BackgroundTransparency = 0.55})
tw(togKnob,  0.15, {BackgroundColor3 = _C3_WHITE,
Position = UDim2.new(1,-14,0.5,-6)}):Play()
twP(cStr,     0.15, {Color = col, Transparency = 0.5})
-- ✅ Sound bei Toggle ON
pcall(function()
    local soundService = game:GetService("SoundService")
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://136697607304800"
    sound.Volume = 0.5
    sound.Parent = workspace
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 2)
end)
else
twP(togTrack, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
tw(togKnob,  0.15, {BackgroundColor3 = _C3_SUB2,
Position = UDim2.new(0,2,0.5,-6)}):Play()
twP(cStr,     0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.3})
end
if onToggle then onToggle(on) end
end
local btn = Instance.new("TextButton", card)
btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1
btn.Text = ""; btn.ZIndex = 7
btn.MouseButton1Click:Connect(function() setToggle(not togState) end)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then setToggle(not togState) end
end)
btn.MouseEnter:Connect(function()
twP(card, 0.08, {BackgroundColor3 = C.bg3 or _C3_BG4})
end)
btn.MouseLeave:Connect(function()
twP(card, 0.08, {BackgroundColor3 = C.bg2 or _C3_BG2})
end)
return card, setToggle
end
local GAP = 8
sectionLbl(CY, "MOVEMENT"); CY = CY + 18
local FLY_MIN, FLY_MAX, FLY_DEFAULT = 1, 500, 150
local _, _flyPanelSetFn = makeSliderRow(CY, "Fly", "speed", C.accent,
FLY_MIN, FLY_MAX, FLY_DEFAULT,
function(on, val) flyActive = on; setFly(on) end,
function() FLY_BASE_SPEED = FLY_DEFAULT end,
function(val, on) FLY_BASE_SPEED = val end
)
CY = CY + CARD_H + GAP
local _, noclipSetFn = makeToggleRow(CY, "Noclip", "no collision", C.orange,
function(on) noclipActive = on; setNoclip(on) end)
CY = CY + TOG_H + GAP
divider(CY); CY = CY + 14
sectionLbl(CY, "STATS"); CY = CY + 18
local SPEED_MIN, SPEED_MAX, SPEED_DEFAULT = 1, 500, 16
local speedVal = SPEED_DEFAULT
makeSliderRow(CY, "Walk Speed", "walkspeed", C.green,
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
makeSliderRow(CY, "Jump Power", "jumppower", C.accent2 or C.accent,
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
local _, invisSetFn2 = makeToggleRow(CY, "Invisible", "server-side", C.accent2 or C.accent,
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
makeToggleRow(CY, "Godmode", "health lock", C.green,
function(on) if on then godStart() else godStop() end end)
CY = CY + TOG_H + GAP
end
p.Size = UDim2.new(0, PANEL_W, 0, CY)
LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.5)
local h = getHumanoid()
if h then h.WalkSpeed = 16; h.JumpPower = 50 end
invisActive = false; invisParts = {}
if invisHeartConn then invisHeartConn:Disconnect(); invisHeartConn = nil end
pcall(function() if invisSetFn2 then invisSetFn2(false) end end)
task.wait(1); invisSetupParts()
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
    local _t2 = pcall(function() return game:GetService("UserInputService").TouchEnabled end)
             and game:GetService("UserInputService").TouchEnabled
    local _k2 = pcall(function() return game:GetService("UserInputService").KeyboardEnabled end)
             and game:GetService("UserInputService").KeyboardEnabled
    if _t2 and not _k2 then
        c.ScrollingEnabled   = true
        c.ScrollBarThickness = 3
        c.ClipsDescendants   = true
        p.ClipsDescendants   = true
    end
end
local SCRIPT_CATS = {
    { id = "Troll",    img = "rbxassetid://120351884957369", col = Color3.fromRGB(255,  80,  80) },
    { id = "Movement", img = "rbxassetid://90240237917328",  col = Color3.fromRGB( 80, 180, 255) },
    { id = "Visual",   img = "rbxassetid://77303382760322",  col = Color3.fromRGB(160,  80, 255) },
    { id = "Misc",     img = "rbxassetid://123514430148126", col = Color3.fromRGB(255, 200,  60) },
    { id = "Combat",   img = "rbxassetid://84261020849153",  col = Color3.fromRGB(255, 120,  40), iconSize = 56 },
}
local S_CARD_GAP = 8
local S_CARD_W   = math.floor((PANEL_W - 32 - S_CARD_GAP * (#SCRIPT_CATS - 1)) / #SCRIPT_CATS)
local S_CARD_H   = 80
local sCatBtns   = {}
local sSubPages  = {}
local sActiveCat = nil
local sGrid = Instance.new("Frame", c)
sGrid.Size             = UDim2.new(1, 0, 0, S_CARD_H)
sGrid.Position         = UDim2.new(0, 0, 0, 0)
sGrid.BackgroundTransparency = 1
sGrid.BorderSizePixel  = 0
local sSubArea = Instance.new("Frame", c)
sSubArea.Size             = UDim2.new(1, 0, 0, 0)
sSubArea.Position         = UDim2.new(0, 0, 0, S_CARD_H + 12)
sSubArea.BackgroundTransparency = 1
sSubArea.BorderSizePixel  = 0
sSubArea.ClipsDescendants = false
createScriptWidget = function(scriptName, accentCol, onToggleFn, initState, extraBuilder)
-- ── Green Matrix themed script widget — design from GB widget ──
local ac = accentCol or C.accent2  -- use passed accent, fallback to theme
local acDim= C.sub
local acBg = Color3.fromRGB(1, 14, 5)     -- near-black green bg
local acBg2= Color3.fromRGB(3, 20, 8)
local acHdr= Color3.fromRGB(2, 18, 6)
local WW   = 240
local HDR_H= 36
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
shadow.Size               = UDim2.new(0, WW+40, 0, 0)
shadow.Position           = UDim2.new(0.5, -(WW+40)/2+4, 0.5, 0)
shadow.BackgroundTransparency = 1
shadow.Image              = "rbxassetid://6014261993"
shadow.ImageColor3        = Color3.new(0,0,0)
shadow.ImageTransparency  = 0.45
shadow.ScaleType          = Enum.ScaleType.Slice
shadow.SliceCenter        = Rect.new(49,49,450,450)
shadow.ZIndex             = 9499
-- Main frame
local W = Instance.new("Frame", ScreenGui)
W.Name             = "SW_" .. scriptName
W.Size             = UDim2.new(0, WW, 0, 0)
W.Position         = UDim2.new(0.5, -WW/2, 0.5, -60)
W.BackgroundColor3 = acBg
W.BorderSizePixel  = 0
W.ZIndex           = 9500
W.Active           = true
W.ClipsDescendants = true
corner(W, 14)
-- BG gradient
pcall(function()
    local bg = Instance.new("UIGradient", W)
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   acBg2),
        ColorSequenceKeypoint.new(0.6, acBg),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(1, 8, 3)),
    })
    bg.Rotation = 135
end)
-- Border stroke (green)
local wStroke = Instance.new("UIStroke", W)
wStroke.Thickness       = 1.2
wStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
wStroke.LineJoinMode    = Enum.LineJoinMode.Round
wStroke.Color           = ac
wStroke.Transparency    = 0.5
-- Accent top line sweep
local wAccLine = Instance.new("Frame", W)
wAccLine.Size                   = UDim2.new(1,-20,0,2)
wAccLine.Position               = UDim2.new(0,10,0,0)
wAccLine.BackgroundColor3       = ac
wAccLine.BackgroundTransparency = 0.4
wAccLine.BorderSizePixel        = 0
wAccLine.ZIndex                 = 9502
corner(wAccLine, 99)
-- Header
local hdr = Instance.new("Frame", W)
hdr.Size             = UDim2.new(1,0,0,HDR_H+8)
hdr.Position         = UDim2.new(0,0,0,0)
hdr.BackgroundColor3 = acHdr
hdr.BackgroundTransparency = 0
hdr.BorderSizePixel  = 0
hdr.ZIndex           = 9501
corner(hdr, 14)
-- fill bottom half of header (straight bottom corners)
local hdrFill = Instance.new("Frame", hdr)
hdrFill.Size = UDim2.new(1,0,0.5,0); hdrFill.Position = UDim2.new(0,0,0.5,0)
hdrFill.BackgroundColor3 = acHdr; hdrFill.BackgroundTransparency = 0
hdrFill.BorderSizePixel = 0; hdrFill.ZIndex = 9501
-- Header separator line
local hdrLine = Instance.new("Frame", W)
hdrLine.Size             = UDim2.new(1,-20,0,1)
hdrLine.Position         = UDim2.new(0,10,0,HDR_H)
hdrLine.BackgroundColor3 = ac
hdrLine.BackgroundTransparency = 0.75
hdrLine.BorderSizePixel  = 0
hdrLine.ZIndex           = 9501
-- Left accent dot in header
local hdot = Instance.new("Frame", hdr)
hdot.Size             = UDim2.new(0,3,0,18)
hdot.Position         = UDim2.new(0,0,0.5,-9)
hdot.BackgroundColor3 = ac
hdot.BackgroundTransparency = 0.35
hdot.BorderSizePixel  = 0
hdot.ZIndex           = 9503
corner(hdot, 99)
-- Title label
local titleLbl = Instance.new("TextLabel", hdr)
titleLbl.Size              = UDim2.new(1,-74,0,HDR_H)
titleLbl.Position          = UDim2.new(0,12,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text              = string.upper(scriptName)
titleLbl.Font              = Enum.Font.GothamBlack
titleLbl.TextSize          = 12
titleLbl.TextColor3        = ac
titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
titleLbl.TextYAlignment    = Enum.TextYAlignment.Center
titleLbl.ZIndex            = 9503
-- Close button X
local closeBtn = Instance.new("TextButton", hdr)
closeBtn.Size              = UDim2.new(0,28,0,28)
closeBtn.Position          = UDim2.new(1,-32,0.5,-14)
closeBtn.BackgroundColor3  = Color3.fromRGB(5, 22, 10)
closeBtn.BackgroundTransparency = 0.1
closeBtn.BorderSizePixel   = 0
closeBtn.Text              = "✕"
closeBtn.Font              = Enum.Font.GothamBlack
closeBtn.TextSize          = 13
closeBtn.TextColor3        = ac
closeBtn.ZIndex            = 9505
corner(closeBtn, 9)
local closeBtnS = Instance.new("UIStroke", closeBtn)
closeBtnS.Thickness = 1.5; closeBtnS.Color = ac; closeBtnS.Transparency = 0.4
closeBtn.MouseEnter:Connect(function()
    twP(closeBtn, 0.1, {BackgroundColor3 = ac, TextColor3 = Color3.fromRGB(1,8,3)})
    closeBtnS.Transparency = 0
end)
closeBtn.MouseLeave:Connect(function()
    twP(closeBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(5,22,10), TextColor3 = ac})
    closeBtnS.Transparency = 0.4
end)
closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        twP(closeBtn, 0.1, {BackgroundColor3 = ac, TextColor3 = Color3.fromRGB(1,8,3)})
        task.delay(0.18, function() twP(closeBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(5,22,10), TextColor3 = ac}) end)
    end
end)
-- Minimize button
local minBtn = Instance.new("TextButton", hdr)
minBtn.Size              = UDim2.new(0,28,0,28)
minBtn.Position          = UDim2.new(1,-64,0.5,-14)
minBtn.BackgroundColor3  = Color3.fromRGB(5, 22, 10)
minBtn.BackgroundTransparency = 0.1
minBtn.BorderSizePixel   = 0
minBtn.Text              = "─"
minBtn.TextColor3        = acDim
minBtn.TextSize          = 11
minBtn.Font              = Enum.Font.GothamBlack
minBtn.ZIndex            = 9505
corner(minBtn, 9)
local minBtnS = Instance.new("UIStroke", minBtn)
minBtnS.Thickness = 1.5; minBtnS.Color = acDim; minBtnS.Transparency = 0.5
minBtn.MouseEnter:Connect(function()
    twP(minBtn, 0.1, {BackgroundColor3 = acDim, TextColor3 = Color3.fromRGB(1,8,3)})
    minBtnS.Transparency = 0.2
end)
minBtn.MouseLeave:Connect(function()
    twP(minBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(5,22,10), TextColor3 = acDim})
    minBtnS.Transparency = 0.5
end)
-- Status pill (matches GB widget status row)
local stPill = Instance.new("Frame", W)
stPill.Size             = UDim2.new(1,-20,0,28)
stPill.Position         = UDim2.new(0,10,0,HDR_H+10)
stPill.BackgroundColor3 = Color3.fromRGB(2, 18, 6)
stPill.BackgroundTransparency = 0.1
stPill.BorderSizePixel  = 0
stPill.ZIndex           = 9501
corner(stPill, 8)
local stPillS = Instance.new("UIStroke", stPill)
stPillS.Thickness    = 1
stPillS.Color        = initState and ac or acDim
stPillS.Transparency = initState and 0.5 or 0.7
-- Status dot
local sDot = Instance.new("Frame", stPill)
sDot.Size = UDim2.new(0,5,0,5); sDot.Position = UDim2.new(0,8,0.5,-2)
sDot.BackgroundColor3 = initState and ac or acDim; sDot.BackgroundTransparency = 0.3
sDot.BorderSizePixel = 0; sDot.ZIndex = 9503; corner(sDot, 99)
local stLbl = Instance.new("TextLabel", stPill)
stLbl.Size              = UDim2.new(1,-90,1,0)
stLbl.Position          = UDim2.new(0,18,0,0)
stLbl.BackgroundTransparency = 1
stLbl.Text              = initState and "● ACTIVE" or "● INACTIVE"
stLbl.Font              = Enum.Font.GothamBlack
stLbl.TextSize          = 10
stLbl.TextColor3        = initState and ac or acDim
stLbl.TextXAlignment    = Enum.TextXAlignment.Left
stLbl.ZIndex            = 9503
-- Toggle track (right side of status pill)
local TW2, TH2 = 34, 18
local togTrack = Instance.new("Frame", stPill)
togTrack.Size             = UDim2.new(0,TW2,0,TH2)
togTrack.Position         = UDim2.new(1,-(TW2+8),0.5,-TH2/2)
togTrack.BackgroundColor3 = initState and ac or Color3.fromRGB(5,22,10)
togTrack.BackgroundTransparency = initState and 0.5 or 0.15
togTrack.BorderSizePixel  = 0
togTrack.ZIndex           = 9503
corner(togTrack, 99)
local togKnob = Instance.new("Frame", togTrack)
togKnob.Size             = UDim2.new(0,12,0,12)
togKnob.Position         = initState and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6)
togKnob.BackgroundColor3 = initState and Color3.fromRGB(1,8,3) or acDim
togKnob.BorderSizePixel  = 0
togKnob.ZIndex           = 9504
corner(togKnob, 99)
local togState = initState or false
local wSetFn
local function setTogState(on)
    togState = on
    -- Toggle track
    twP(togTrack, 0.15, {
        BackgroundColor3 = on and ac or Color3.fromRGB(5,22,10),
        BackgroundTransparency = on and 0.5 or 0.15
    })
    tw(togKnob, 0.15, {
        BackgroundColor3 = on and Color3.fromRGB(1,8,3) or acDim,
        Position = on and UDim2.new(1,-14,0.5,-6) or UDim2.new(0,2,0.5,-6),
    }, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
    -- Status pill
    twP(stPillS, 0.15, {Color = on and ac or acDim, Transparency = on and 0.5 or 0.7})
    twP(sDot,    0.15, {BackgroundColor3 = on and ac or acDim})
    twP(stLbl,   0.15, {TextColor3 = on and ac or acDim})
    stLbl.Text = on and "● ACTIVE" or "● INACTIVE"
    if onToggleFn then pcall(onToggleFn, on) end
end
wSetFn = setTogState
local togBtn = Instance.new("TextButton", stPill)
togBtn.Size = UDim2.new(1,0,1,0); togBtn.BackgroundTransparency = 1
togBtn.Text = ""; togBtn.ZIndex = 9505
togBtn.MouseButton1Click:Connect(function() setTogState(not togState) end)
togBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then setTogState(not togState) end
end)
-- Auto-nearest target display row
local tgtRow = Instance.new("Frame", W)
tgtRow.Size             = UDim2.new(1,-20,0,26)
tgtRow.Position         = UDim2.new(0,10,0,HDR_H+46)
tgtRow.BackgroundColor3 = Color3.fromRGB(2, 18, 6)
tgtRow.BackgroundTransparency = 0.15
tgtRow.BorderSizePixel  = 0; tgtRow.ZIndex = 9501
corner(tgtRow, 8)
local tgtRowS = Instance.new("UIStroke", tgtRow)
tgtRowS.Thickness = 1; tgtRowS.Color = acDim; tgtRowS.Transparency = 0.7
local tgtDot = Instance.new("Frame", tgtRow)
tgtDot.Size = UDim2.new(0,5,0,5); tgtDot.Position = UDim2.new(0,8,0.5,-2)
tgtDot.BackgroundColor3 = ac; tgtDot.BackgroundTransparency = 0.4
tgtDot.BorderSizePixel = 0; tgtDot.ZIndex = 9503; corner(tgtDot, 99)
local tgtLbl = Instance.new("TextLabel", tgtRow)
tgtLbl.Size = UDim2.new(0,44,1,0); tgtLbl.Position = UDim2.new(0,18,0,0)
tgtLbl.BackgroundTransparency = 1; tgtLbl.Text = "Target:"
tgtLbl.Font = Enum.Font.GothamBold; tgtLbl.TextSize = 9
tgtLbl.TextColor3 = acDim; tgtLbl.TextXAlignment = Enum.TextXAlignment.Left
tgtLbl.ZIndex = 9503
local tgtVal = Instance.new("TextLabel", tgtRow)
tgtVal.Size = UDim2.new(1,-66,1,0); tgtVal.Position = UDim2.new(0,62,0,0)
tgtVal.BackgroundTransparency = 1; tgtVal.Text = "— none —"
tgtVal.Font = Enum.Font.GothamBold; tgtVal.TextSize = 10
tgtVal.TextColor3 = C.text
tgtVal.TextXAlignment = Enum.TextXAlignment.Left
tgtVal.TextTruncate = Enum.TextTruncate.AtEnd; tgtVal.ZIndex = 9503
-- Update target on open/toggle
local function swUpdateTarget()
    pcall(function()
        local np = getNearestPlayer()
        tgtVal.Text = np and np.Name or "— none —"
    end)
end
togBtn.MouseButton1Click:Connect(swUpdateTarget)
togBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then swUpdateTarget() end
end)
local extraH = 0
if extraBuilder then
    extraH = extraBuilder(W, WW, HDR_H+80, ac, wSetFn) or 0
end
local WH = HDR_H + 82 + extraH
-- Dragging
local dragging, dragStart, startPos = false, nil, nil
hdr.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = inp.Position; startPos = W.Position
    end
end)
hdr.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
local UISd = UserInputService or game:GetService("UserInputService")
UISd.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local d  = inp.Position - dragStart
        local nx = startPos.X.Offset + d.X
        local ny = startPos.Y.Offset + d.Y
        W.Position      = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
        shadow.Position = UDim2.new(startPos.X.Scale, nx-20+4, startPos.Y.Scale, ny-20+6)
    end
end)
-- Minimize / Close
local minimized = false
local function doMinimize2()
    minimized = not minimized
    if minimized then
        tw(W, 0.20, {Size=UDim2.new(0,WW,0,HDR_H+8)},
            Enum.EasingStyle.Exponential, Enum.EasingDirection.Out):Play()
        tw(shadow, 0.16, {ImageTransparency=1},
            Enum.EasingStyle.Exponential, Enum.EasingDirection.Out):Play()
        minBtn.Text = "+"
    else
        tw(W, 0.26, {Size=UDim2.new(0,WW,0,WH)},
            Enum.EasingStyle.Exponential, Enum.EasingDirection.Out):Play()
        tw(shadow, 0.24, {ImageTransparency=0.45, Size=UDim2.new(0,WW+40,0,WH+40)},
            Enum.EasingStyle.Exponential, Enum.EasingDirection.Out):Play()
        minBtn.Text = "─"
    end
end
minBtn.MouseButton1Click:Connect(doMinimize2)
minBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then doMinimize2() end
end)
local function doClose()
    local cPos = W.Position
    local cx, cy = cPos.X.Offset, cPos.Y.Offset
    local curH = W.AbsoluteSize.Y > 0 and W.AbsoluteSize.Y or WH
    tw(W, 0.18, {
        Size = UDim2.new(0, math.floor(WW*0.94), 0, math.floor(curH*0.94)),
        Position = UDim2.new(cPos.X.Scale, cx+math.floor(WW*0.03), cPos.Y.Scale, cy+math.floor(curH*0.03)),
        BackgroundTransparency = 0.9},
        Enum.EasingStyle.Exponential, Enum.EasingDirection.In):Play()
    tw(shadow, 0.14, {ImageTransparency=1},
        Enum.EasingStyle.Exponential, Enum.EasingDirection.In):Play()
    task.delay(0.20, function()
        pcall(function() W:Destroy() end)
        pcall(function() shadow:Destroy() end)
    end)
end
closeBtn.MouseButton1Click:Connect(doClose)
closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then doClose() end
end)
-- Entrance animation
local finalPos       = UDim2.new(0.5, -WW/2, 0.5, -WH/2)
local finalShadowPos = UDim2.new(0.5, -(WW+40)/2+4, 0.5, -WH/2+6)
W.Size               = UDim2.new(0, math.floor(WW*0.92), 0, math.floor(WH*0.92))
W.Position           = UDim2.new(0.5, -math.floor(WW*0.92)/2, 0.5, -math.floor(WH*0.92)/2)
W.BackgroundTransparency = 0.9
shadow.ImageTransparency = 1
shadow.Size          = UDim2.new(0, WW+40, 0, WH+40)
shadow.Position      = finalShadowPos
tw(W, 0.28, {Size=UDim2.new(0,WW,0,WH), Position=finalPos, BackgroundTransparency=0},
    Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
tw(shadow, 0.22, {ImageTransparency=0.45},
    Enum.EasingStyle.Exponential, Enum.EasingDirection.Out):Play()
swUpdateTarget()
end

local function addWidgetBtn(rowFrame, scriptName, accentCol, onToggleFn, getStateFn, xPos)
local ac = accentCol or C.accent
-- Pill container — 52×26px, rounded, accent-bordered
local pill = Instance.new("Frame", rowFrame)
pill.Name             = "WBtn_" .. scriptName
pill.Size             = UDim2.new(0, 52, 0, 26)
local scl = xPos < 0 and 1 or 0
pill.Position         = UDim2.new(scl, xPos < 0 and (xPos - 24) or xPos, 0.5, -13)
pill.BackgroundColor3 = Color3.fromRGB(3, 20, 8)
pill.BackgroundTransparency = 0.05
pill.BorderSizePixel  = 0
pill.ZIndex           = 7
corner(pill, 13)
local iS = Instance.new("UIStroke", pill)
iS.Thickness = 1.5; iS.Color = ac; iS.Transparency = 0.55
-- Left accent dot
local adot = Instance.new("Frame", pill)
adot.Size = UDim2.new(0,3,0,14); adot.Position = UDim2.new(0,0,0.5,-7)
adot.BackgroundColor3 = ac; adot.BackgroundTransparency = 0.4
adot.BorderSizePixel = 0; adot.ZIndex = 8; corner(adot, 99)
-- Icon label "⊞"
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
    twP(pill,   0.10, {BackgroundColor3 = ac, BackgroundTransparency = 0.78})
    twP(icoLbl, 0.10, {TextColor3 = _C3_WHITE})
    twP(txtLbl, 0.10, {TextColor3 = _C3_WHITE})
    iS.Transparency = 0.2
end)
hitBtn.MouseLeave:Connect(function()
    twP(pill,   0.10, {BackgroundColor3 = Color3.fromRGB(3,20,8), BackgroundTransparency = 0.05})
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
sendNotif("Gangbang", T.gb_stopped, 2)
end
local function gbStart(targetPlayer)
gbStop()
local targetChar = targetPlayer and targetPlayer.Character
if not targetChar then
sendNotif("Gangbang", T.gb_no_target_char, 2); return false
end
local myChar = LocalPlayer.Character
if not myChar then sendNotif("Gangbang", T.gb_no_own_char, 2); return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not hum then sendNotif("Gangbang", T.gb_missing_parts, 2); return false end
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
sendNotif("Gangbang", T.gb_orbit .. targetPlayer.Name, 3)
return true
end
local gbRow = Instance.new("Frame", trollPage)
gbRow.Size = UDim2.new(1,0,0,72); gbRow.Position = UDim2.new(0,0,0,0)
gbRow.BackgroundColor3 = C.bg2 or _C3_BG2; gbRow.BackgroundTransparency = 0
gbRow.BorderSizePixel = 0; corner(gbRow, 12)
local gbRowS = Instance.new("UIStroke", gbRow)
gbRowS.Thickness = 1; gbRowS.Color = C.bg3 or _C3_BG3; gbRowS.Transparency = 0.3
local gbRowDot = Instance.new("Frame", gbRow)
gbRowDot.Size = UDim2.new(0,3,0,52); gbRowDot.Position = UDim2.new(0,0,0.5,-26)
gbRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220,60,60); gbRowDot.BackgroundTransparency = 0.4
gbRowDot.BorderSizePixel = 0; corner(gbRowDot, 99)
local gbLbl = Instance.new("TextLabel", gbRow)
gbLbl.Size = UDim2.new(0,90,0,28); gbLbl.Position = UDim2.new(0,14,0,4)
gbLbl.BackgroundTransparency = 1; gbLbl.Text = T.gb_label
gbLbl.Font = Enum.Font.GothamBold; gbLbl.TextSize = 13
gbLbl.TextColor3 = C.text; gbLbl.TextXAlignment = Enum.TextXAlignment.Left
local gbPill = Instance.new("Frame", gbRow)
gbPill.Size = UDim2.new(0,110,0,24); gbPill.Position = UDim2.new(0,14,1,-34)
gbPill.BackgroundColor3 = C.bg3; gbPill.BackgroundTransparency = 0.05
gbPill.BorderSizePixel = 0
corner(gbPill, 10); gradStroke(gbPill, 1, 0.3)
local gbPillLbl = Instance.new("TextLabel", gbPill)
gbPillLbl.Size = UDim2.new(1,-8,1,0); gbPillLbl.Position = UDim2.new(0,4,0,0)
gbPillLbl.BackgroundTransparency = 1; gbPillLbl.Text = T.gb_player_pill
gbPillLbl.Font = Enum.Font.GothamBold; gbPillLbl.TextSize = 13
gbPillLbl.TextColor3 = C.text; gbPillLbl.TextXAlignment = Enum.TextXAlignment.Left
gbPillLbl.TextTruncate = Enum.TextTruncate.AtEnd
local gbPillBtn = Instance.new("TextButton", gbPill)
gbPillBtn.Size = UDim2.new(1,0,1,0); gbPillBtn.BackgroundTransparency = 1
gbPillBtn.Text = ""; gbPillBtn.ZIndex = 6
local gbSelectedPlayer = nil
local gbSetToggle
local gbState = false
do
local GB_SLIDER_MIN, GB_SLIDER_MAX = 1, 50
local gbSpeedVal = math.floor(GB_SPEED * 10)
local gbSpeedLbl = Instance.new("TextLabel", gbRow)
gbSpeedLbl.Size = UDim2.new(0, 32, 0, 22); gbSpeedLbl.Position = UDim2.new(0, 130, 1, -33)
gbSpeedLbl.BackgroundTransparency = 1; gbSpeedLbl.Text = tostring(gbSpeedVal)
gbSpeedLbl.Font = Enum.Font.GothamBold; gbSpeedLbl.TextSize = 11
gbSpeedLbl.TextColor3 = C.red; gbSpeedLbl.TextXAlignment = Enum.TextXAlignment.Center
local gbTrack = Instance.new("Frame", gbRow)
gbTrack.Size = UDim2.new(0, 130, 0, 8); gbTrack.Position = UDim2.new(0, 166, 1, -28)
gbTrack.BackgroundColor3 = C.bg3; gbTrack.BorderSizePixel = 0
corner(gbTrack, 4); stroke(gbTrack, 1, C.red, 0.6)
local gbFill = Instance.new("Frame", gbTrack)
gbFill.Size = UDim2.new((gbSpeedVal - GB_SLIDER_MIN) / (GB_SLIDER_MAX - GB_SLIDER_MIN), 0, 1, 0)
gbFill.BackgroundColor3 = C.red; gbFill.BorderSizePixel = 0; corner(gbFill, 4)
local gbKnob = Instance.new("Frame", gbTrack)
gbKnob.Size = UDim2.new(0, 14, 0, 14)
gbKnob.Position = UDim2.new((gbSpeedVal - GB_SLIDER_MIN) / (GB_SLIDER_MAX - GB_SLIDER_MIN), -7, 0.5, -7)
gbKnob.BackgroundColor3 = _C3_WHITE; gbKnob.BorderSizePixel = 0; gbKnob.ZIndex = 5
corner(gbKnob, 99)
local gbKS = Instance.new("UIStroke", gbKnob); gbKS.Thickness = 1.5; gbKS.Color = C.red; gbKS.Transparency = 0
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
local _, gbSetToggleFn, gbGetFn = makeToggle(gbRow, 419, 42, false, function(on)
gbState = on
if on then
if not gbSelectedPlayer then
sendNotif("Gangbang", T.gb_select_player, 2)
task.defer(function() gbSetToggleFn(false) end); return
end
local ok = gbStart(gbSelectedPlayer)
if not ok then task.defer(function() gbSetToggleFn(false) end) end
else
gbStop()
end
end)
;(function() -- Gangbang widget
-- ── Gangbang draggable panel widget ──────────────────────────────────────
local GB_W    = 260
local GB_H    = 0   -- starts collapsed, expands on open
local GB_FULL = 210 -- full expanded height
local gbWidget = Instance.new("Frame", ScreenGui)
gbWidget.Name              = "GangbangWidget"
gbWidget.Size              = UDim2.new(0, GB_W, 0, 0)
gbWidget.Position          = UDim2.new(1, -(GB_W + 16), 0, 80)
gbWidget.BackgroundColor3  = C.bg
gbWidget.BorderSizePixel   = 0
gbWidget.ZIndex            = 9500
gbWidget.Active            = true
gbWidget.ClipsDescendants  = true
gbWidget.Visible            = false
corner(gbWidget, 14)
pcall(function()
    local bg = Instance.new("UIGradient", gbWidget)
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   C.bg2),
        ColorSequenceKeypoint.new(0.6, C.bg),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(9,10,18)),
    })
    bg.Rotation = 135
end)
local gbWStroke = Instance.new("UIStroke", gbWidget)
gbWStroke.Thickness       = 1.2
gbWStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
gbWStroke.LineJoinMode    = Enum.LineJoinMode.Round
gbWStroke.Color           = C.accent2
gbWStroke.Transparency    = 0.5

-- Shadow
local gbShadow = Instance.new("ImageLabel", ScreenGui)
gbShadow.Name               = "GangbangWidgetShadow"
gbShadow.Size               = UDim2.new(0, GB_W+40, 0, GB_FULL+30)
gbShadow.Position           = UDim2.new(1, -(GB_W + 16) - 20, 0, 74)
gbShadow.BackgroundTransparency = 1
gbShadow.Image              = "rbxassetid://6014261993"
gbShadow.ImageColor3        = Color3.new(0,0,0)
gbShadow.ImageTransparency  = 0.45
gbShadow.ScaleType          = Enum.ScaleType.Slice
gbShadow.SliceCenter        = Rect.new(49,49,450,450)
gbShadow.ZIndex             = 9499
gbShadow.Visible            = false

-- Title bar (also drag handle)
local gbHdr = Instance.new("Frame", gbWidget)
gbHdr.Size             = UDim2.new(1, 0, 0, 36)
gbHdr.BackgroundColor3 = Color3.fromRGB(1, 14, 5)
gbHdr.BackgroundTransparency = 0.1
gbHdr.BorderSizePixel  = 0
gbHdr.ZIndex           = 9501
corner(gbHdr, 14)
-- bottom-straight corners via overlap
local gbHdrFill = Instance.new("Frame", gbHdr)
gbHdrFill.Size = UDim2.new(1,0,0.5,0); gbHdrFill.Position = UDim2.new(0,0,0.5,0)
gbHdrFill.BackgroundColor3 = Color3.fromRGB(1,14,5); gbHdrFill.BackgroundTransparency = 0.1
gbHdrFill.BorderSizePixel = 0; gbHdrFill.ZIndex = 9501

local gbHdrDot = Instance.new("Frame", gbHdr)
gbHdrDot.Size = UDim2.new(0,3,0,18); gbHdrDot.Position = UDim2.new(0,0,0.5,-9)
gbHdrDot.BackgroundColor3 = C.accent2; gbHdrDot.BackgroundTransparency = 0.3
gbHdrDot.BorderSizePixel = 0; gbHdrDot.ZIndex = 9502; corner(gbHdrDot, 99)

local gbWTitle = Instance.new("TextLabel", gbHdr)
gbWTitle.Size = UDim2.new(1,-64,1,0); gbWTitle.Position = UDim2.new(0,14,0,0)
gbWTitle.BackgroundTransparency = 1; gbWTitle.Text = "⚔  Gangbang"
gbWTitle.Font = Enum.Font.GothamBlack; gbWTitle.TextSize = 13
gbWTitle.TextColor3 = C.accent2; gbWTitle.TextXAlignment = Enum.TextXAlignment.Left
gbWTitle.ZIndex = 9502

-- Close button — larger X, prominent
local gbWCloseBtn = Instance.new("TextButton", gbHdr)
gbWCloseBtn.Size = UDim2.new(0,30,0,30); gbWCloseBtn.Position = UDim2.new(1,-34,0.5,-15)
gbWCloseBtn.BackgroundColor3 = Color3.fromRGB(5,22,10); gbWCloseBtn.BackgroundTransparency = 0.1
gbWCloseBtn.BorderSizePixel = 0; gbWCloseBtn.Text = "✕"
gbWCloseBtn.Font = Enum.Font.GothamBlack; gbWCloseBtn.TextSize = 14
gbWCloseBtn.TextColor3 = C.accent2; gbWCloseBtn.ZIndex = 9503
corner(gbWCloseBtn, 10)
local gbWCloseS = Instance.new("UIStroke", gbWCloseBtn)
gbWCloseS.Thickness = 1.5; gbWCloseS.Color = C.accent2; gbWCloseS.Transparency = 0.35

-- Header separator
local gbWSep = Instance.new("Frame", gbWidget)
gbWSep.Size = UDim2.new(1,-20,0,1); gbWSep.Position = UDim2.new(0,10,0,36)
gbWSep.BackgroundColor3 = C.accent2; gbWSep.BackgroundTransparency = 0.78
gbWSep.BorderSizePixel = 0; gbWSep.ZIndex = 9501

-- Body
local gbBody = Instance.new("Frame", gbWidget)
gbBody.Size = UDim2.new(1,0,1,-37); gbBody.Position = UDim2.new(0,0,0,37)
gbBody.BackgroundTransparency = 1; gbBody.BorderSizePixel = 0; gbBody.ZIndex = 9501

-- ── Status row ─────────────────────────────────────────────────────
local gbWStatusRow = Instance.new("Frame", gbBody)
gbWStatusRow.Size = UDim2.new(1,-20,0,32); gbWStatusRow.Position = UDim2.new(0,10,0,10)
gbWStatusRow.BackgroundColor3 = Color3.fromRGB(2,18,6); gbWStatusRow.BackgroundTransparency = 0.15
gbWStatusRow.BorderSizePixel = 0; gbWStatusRow.ZIndex = 9502
corner(gbWStatusRow, 8)
local gbWStatusS = Instance.new("UIStroke", gbWStatusRow)
gbWStatusS.Thickness = 1; gbWStatusS.Color = C.accent2; gbWStatusS.Transparency = 0.7

local gbWStatusLbl = Instance.new("TextLabel", gbWStatusRow)
gbWStatusLbl.Size = UDim2.new(1,-16,1,0); gbWStatusLbl.Position = UDim2.new(0,8,0,0)
gbWStatusLbl.BackgroundTransparency = 1; gbWStatusLbl.Text = "● INACTIVE"
gbWStatusLbl.Font = Enum.Font.GothamBlack; gbWStatusLbl.TextSize = 10
gbWStatusLbl.TextColor3 = C.sub; gbWStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
gbWStatusLbl.ZIndex = 9503

-- ── Toggle row ──────────────────────────────────────────────────────
local gbWToggleRow = Instance.new("Frame", gbBody)
gbWToggleRow.Size = UDim2.new(1,-20,0,36); gbWToggleRow.Position = UDim2.new(0,10,0,142)
gbWToggleRow.BackgroundColor3 = C.bg2; gbWToggleRow.BackgroundTransparency = 0.05
gbWToggleRow.BorderSizePixel = 0; gbWToggleRow.ZIndex = 9502
corner(gbWToggleRow, 10)
local gbWTogRowS = Instance.new("UIStroke", gbWToggleRow)
gbWTogRowS.Thickness = 1; gbWTogRowS.Color = C.bg3; gbWTogRowS.Transparency = 0.3

local gbWTogLbl = Instance.new("TextLabel", gbWToggleRow)
gbWTogLbl.Size = UDim2.new(1,-52,1,0); gbWTogLbl.Position = UDim2.new(0,12,0,0)
gbWTogLbl.BackgroundTransparency = 1; gbWTogLbl.Text = "Active"
gbWTogLbl.Font = Enum.Font.GothamBold; gbWTogLbl.TextSize = 12
gbWTogLbl.TextColor3 = C.text; gbWTogLbl.TextXAlignment = Enum.TextXAlignment.Left
gbWTogLbl.ZIndex = 9503

-- Toggle track
local gbWTrack = Instance.new("Frame", gbWToggleRow)
gbWTrack.Size = UDim2.new(0,36,0,20); gbWTrack.Position = UDim2.new(1,-44,0.5,-10)
gbWTrack.BackgroundColor3 = C.bg3; gbWTrack.BackgroundTransparency = 0.2
gbWTrack.BorderSizePixel = 0; gbWTrack.ZIndex = 9503; corner(gbWTrack, 99)
local gbWKnob = Instance.new("Frame", gbWTrack)
gbWKnob.Size = UDim2.new(0,14,0,14); gbWKnob.Position = UDim2.new(0,2,0.5,-7)
gbWKnob.BackgroundColor3 = C.sub; gbWKnob.BorderSizePixel = 0; gbWKnob.ZIndex = 9504
corner(gbWKnob, 99)
local gbWTogBtn = Instance.new("TextButton", gbWToggleRow)
gbWTogBtn.Size = UDim2.new(1,0,1,0); gbWTogBtn.BackgroundTransparency = 1
gbWTogBtn.Text = ""; gbWTogBtn.ZIndex = 9505

-- ── Auto-target info row (shows nearest player) ───────────────────
local gbWTargRow = Instance.new("Frame", gbBody)
gbWTargRow.Size = UDim2.new(1,-20,0,28); gbWTargRow.Position = UDim2.new(0,10,0,50)
gbWTargRow.BackgroundColor3 = Color3.fromRGB(2,18,6); gbWTargRow.BackgroundTransparency = 0.15
gbWTargRow.BorderSizePixel = 0; gbWTargRow.ZIndex = 9502
corner(gbWTargRow, 8)
local gbWTargRowS = Instance.new("UIStroke", gbWTargRow)
gbWTargRowS.Thickness = 1; gbWTargRowS.Color = C.accent2; gbWTargRowS.Transparency = 0.7

local gbWTargDot = Instance.new("Frame", gbWTargRow)
gbWTargDot.Size = UDim2.new(0,5,0,5); gbWTargDot.Position = UDim2.new(0,8,0.5,-2)
gbWTargDot.BackgroundColor3 = C.accent2; gbWTargDot.BackgroundTransparency = 0.3
gbWTargDot.BorderSizePixel = 0; gbWTargDot.ZIndex = 9504; corner(gbWTargDot, 99)

local gbWTargLbl = Instance.new("TextLabel", gbWTargRow)
gbWTargLbl.Size = UDim2.new(0,38,1,0); gbWTargLbl.Position = UDim2.new(0,18,0,0)
gbWTargLbl.BackgroundTransparency = 1; gbWTargLbl.Text = "Target:"
gbWTargLbl.Font = Enum.Font.GothamBold; gbWTargLbl.TextSize = 9
gbWTargLbl.TextColor3 = C.sub; gbWTargLbl.TextXAlignment = Enum.TextXAlignment.Left
gbWTargLbl.ZIndex = 9503

local gbWTargVal = Instance.new("TextLabel", gbWTargRow)
gbWTargVal.Size = UDim2.new(1,-62,1,0); gbWTargVal.Position = UDim2.new(0,58,0,0)
gbWTargVal.BackgroundTransparency = 1
gbWTargVal.Text = "— none —"
gbWTargVal.Font = Enum.Font.GothamBold; gbWTargVal.TextSize = 10
gbWTargVal.TextColor3 = C.text; gbWTargVal.TextXAlignment = Enum.TextXAlignment.Left
gbWTargVal.TextTruncate = Enum.TextTruncate.AtEnd; gbWTargVal.ZIndex = 9503

-- ── Toggle row moved up ─────────────────────────────────────────────

-- ── Speed row ──────────────────────────────────────────────────────
local gbWSpeedRow = Instance.new("Frame", gbBody)
gbWSpeedRow.Size = UDim2.new(1,-20,0,48); gbWSpeedRow.Position = UDim2.new(0,10,0,86)
gbWSpeedRow.BackgroundColor3 = C.bg2; gbWSpeedRow.BackgroundTransparency = 0.05
gbWSpeedRow.BorderSizePixel = 0; gbWSpeedRow.ZIndex = 9502
corner(gbWSpeedRow, 10)
local gbWSpeedRowS = Instance.new("UIStroke", gbWSpeedRow)
gbWSpeedRowS.Thickness = 1; gbWSpeedRowS.Color = C.bg3; gbWSpeedRowS.Transparency = 0.3

local gbWSpeedHdr = Instance.new("TextLabel", gbWSpeedRow)
gbWSpeedHdr.Size = UDim2.new(1,-16,0,16); gbWSpeedHdr.Position = UDim2.new(0,12,0,4)
gbWSpeedHdr.BackgroundTransparency = 1; gbWSpeedHdr.Text = "Speed"
gbWSpeedHdr.Font = Enum.Font.GothamBold; gbWSpeedHdr.TextSize = 10
gbWSpeedHdr.TextColor3 = C.sub; gbWSpeedHdr.TextXAlignment = Enum.TextXAlignment.Left
gbWSpeedHdr.ZIndex = 9503

local gbWSpeedVal = Instance.new("TextLabel", gbWSpeedRow)
gbWSpeedVal.Size = UDim2.new(0,36,0,16); gbWSpeedVal.Position = UDim2.new(1,-44,0,4)
gbWSpeedVal.BackgroundTransparency = 1; gbWSpeedVal.Text = tostring(math.floor(GB_SPEED*10))
gbWSpeedVal.Font = Enum.Font.GothamBlack; gbWSpeedVal.TextSize = 10
gbWSpeedVal.TextColor3 = C.accent2; gbWSpeedVal.TextXAlignment = Enum.TextXAlignment.Right
gbWSpeedVal.ZIndex = 9503

local gbWSliderTrack = Instance.new("Frame", gbWSpeedRow)
gbWSliderTrack.Size = UDim2.new(1,-24,0,8); gbWSliderTrack.Position = UDim2.new(0,12,0,28)
gbWSliderTrack.BackgroundColor3 = Color3.fromRGB(2,18,6); gbWSliderTrack.BorderSizePixel = 0
gbWSliderTrack.ZIndex = 9503; corner(gbWSliderTrack, 4)
local gbWSliderFill = Instance.new("Frame", gbWSliderTrack)
local _initRatio = math.clamp((GB_SPEED*10 - 1) / 49, 0, 1)
gbWSliderFill.Size = UDim2.new(_initRatio,0,1,0); gbWSliderFill.BackgroundColor3 = C.accent2
gbWSliderFill.BorderSizePixel = 0; gbWSliderFill.ZIndex = 9504; corner(gbWSliderFill, 4)
local gbWSliderKnob = Instance.new("Frame", gbWSliderTrack)
gbWSliderKnob.Size = UDim2.new(0,14,0,14); gbWSliderKnob.Position = UDim2.new(_initRatio,-7,0.5,-7)
gbWSliderKnob.BackgroundColor3 = _C3_WHITE; gbWSliderKnob.BorderSizePixel = 0; gbWSliderKnob.ZIndex = 9505
corner(gbWSliderKnob, 99)
local gbWSliderS = Instance.new("UIStroke", gbWSliderKnob); gbWSliderS.Thickness = 1.5
gbWSliderS.Color = C.accent2; gbWSliderS.Transparency = 0

local gbWSliderInput = Instance.new("TextButton", gbWSliderTrack)
gbWSliderInput.Size = UDim2.new(1,14,1,14); gbWSliderInput.Position = UDim2.new(0,-7,0,-7)
gbWSliderInput.BackgroundTransparency = 1; gbWSliderInput.Text = ""; gbWSliderInput.ZIndex = 9506

-- Slider logic
local gbWDragging = false
local function updateGbWSlider(absX)
    local ratio = math.clamp((absX - gbWSliderTrack.AbsolutePosition.X) / gbWSliderTrack.AbsoluteSize.X, 0, 1)
    local val = math.floor(1 + ratio * 49)
    gbWSliderFill.Size = UDim2.new(ratio,0,1,0)
    gbWSliderKnob.Position = UDim2.new(ratio,-7,0.5,-7)
    gbWSpeedVal.Text = tostring(val)
    GB_SPEED = val / 10
    -- sync original slider too
    gbSpeedLbl.Text = tostring(val)
    local origRatio = math.clamp((val - 1) / 49, 0, 1)
    gbFill.Size = UDim2.new(origRatio, 0, 1, 0)
    gbKnob.Position = UDim2.new(origRatio, -7, 0.5, -7)
end
gbWSliderInput.MouseButton1Down:Connect(function(x) gbWDragging = true; updateGbWSlider(x) end)
gbWSliderInput.MouseMoved:Connect(function(x) if gbWDragging then updateGbWSlider(x) end end)
gbWSliderInput.MouseButton1Up:Connect(function() gbWDragging = false end)
gbWSliderInput.MouseLeave:Connect(function() gbWDragging = false end)
-- Touch support for Gangbang slider
gbWSliderInput.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        gbWDragging = true; updateGbWSlider(inp.Position.X)
    end
end)
gbWSliderInput.InputChanged:Connect(function(inp)
    if gbWDragging and inp.UserInputType == Enum.UserInputType.Touch then
        updateGbWSlider(inp.Position.X)
    end
end)
gbWSliderInput.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then gbWDragging = false end
end)

-- ── Widget open/close ───────────────────────────────────────────────
local gbWidgetOpen = false
local gbWSlot = {tween=nil}

local function gbWOpen()
    if gbWidgetOpen then return end
    gbWidgetOpen = true
    -- Show nearest player in target display
    pcall(function()
        local np = getNearestPlayer()
        if gbWTargVal then gbWTargVal.Text = np and np.Name or "— none —" end
    end)
    gbWidget.Visible = true; gbShadow.Visible = true
    gbWidget.Size = UDim2.new(0, GB_W, 0, 0)
    if gbWSlot.tween then pcall(function() gbWSlot.tween:Cancel() end) end
    gbWSlot.tween = twP(gbWidget, 0.30, {Size = UDim2.new(0, GB_W, 0, GB_FULL)},
        Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    twP(gbWStroke, 0.20, {Transparency = 0.2})
end

local gbOBTxt_ref, gbOBIco_ref = nil, nil  -- set after pill creation
local function gbWClose()
    if not gbWidgetOpen then return end
    gbWidgetOpen = false
    if gbWSlot.tween then pcall(function() gbWSlot.tween:Cancel() end) end
    gbWSlot.tween = twP(gbWidget, 0.22, {Size = UDim2.new(0, GB_W, 0, 0)},
        Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    twP(gbWStroke, 0.15, {Transparency = 0.5})
    task.delay(0.24, function()
        if not gbWidgetOpen then
            gbWidget.Visible = false; gbShadow.Visible = false
        end
    end)
    -- Sync open button label
    pcall(function()
        if gbOBTxt_ref then gbOBTxt_ref.Text = "OPEN" end
        if gbOBIco_ref  then twP(gbOBIco_ref, 0.1, {TextColor3 = C.accent2}) end
    end)
end

-- Sync toggle state visual
local function gbWSyncToggle(on)
    if on then
        twP(gbWTrack, 0.15, {BackgroundColor3 = C.accent2, BackgroundTransparency = 0.55})
        twP(gbWKnob,  0.15, {BackgroundColor3 = _C3_WHITE, Position = UDim2.new(1,-16,0.5,-7)})
        gbWStatusLbl.Text = "● ACTIVE"; gbWStatusLbl.TextColor3 = C.accent2
        gbWTogRowS.Color = C.accent2; gbWTogRowS.Transparency = 0.4
    else
        twP(gbWTrack, 0.15, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2})
        twP(gbWKnob,  0.15, {BackgroundColor3 = C.sub, Position = UDim2.new(0,2,0.5,-7)})
        gbWStatusLbl.Text = "● INACTIVE"; gbWStatusLbl.TextColor3 = C.sub
        gbWTogRowS.Color = C.bg3; gbWTogRowS.Transparency = 0.3
    end
end

-- Toggle button click
local function gbWDoToggle()
    gbState = not gbState
    gbWSyncToggle(gbState)
    gbSetToggleFn(gbState)
    if gbState then
        -- Auto-select nearest player
        local np = getNearestPlayer()
        if np then
            gbSelectedPlayer = np
            gbPillLbl.Text = np.Name
            gbPillLbl.TextColor3 = C.accent2
            if gbWTargVal then gbWTargVal.Text = np.Name end
        end
        if not gbSelectedPlayer then
            sendNotif("Gangbang", T.gb_nobody_near, 2)
            gbState = false; gbWSyncToggle(false); gbSetToggleFn(false); return
        end
        local ok = gbStart(gbSelectedPlayer)
        if not ok then gbState = false; gbWSyncToggle(false); gbSetToggleFn(false) end
    else
        gbStop()
        if gbWTargVal then gbWTargVal.Text = "— none —" end
    end
end
gbWTogBtn.MouseButton1Click:Connect(gbWDoToggle)
gbWTogBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then gbWDoToggle() end
end)

-- Keep widget toggle in sync with main row toggle
gbSetToggle = function(on)
    gbState = on; gbWSyncToggle(on); gbSetToggleFn(on)
end

-- Update target label when player selected
-- Target val updated directly by toggle / open

-- Close button
gbWCloseBtn.MouseButton1Click:Connect(function() gbWClose() end)
gbWCloseBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then gbWClose() end
end)
gbWCloseBtn.MouseEnter:Connect(function()
    twP(gbWCloseBtn, 0.08, {BackgroundColor3 = Color3.fromRGB(10,35,15), BackgroundTransparency = 0.1})
end)
gbWCloseBtn.MouseLeave:Connect(function()
    twP(gbWCloseBtn, 0.08, {BackgroundColor3 = Color3.fromRGB(5,20,8), BackgroundTransparency = 0.3})
end)

-- No player picker — auto-nearest is used on toggle

-- Dragging
local gbWDragActive = false
local gbWDragStart, gbWDragOrigin
gbHdr.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        gbWDragActive = true
        gbWDragStart  = inp.Position
        gbWDragOrigin = gbWidget.Position
    end
end)
gbHdr.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        gbWDragActive = false
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if gbWDragActive and (inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - gbWDragStart
        gbWidget.Position = UDim2.new(
            gbWDragOrigin.X.Scale, gbWDragOrigin.X.Offset + d.X,
            gbWDragOrigin.Y.Scale, gbWDragOrigin.Y.Offset + d.Y)
        gbShadow.Position = UDim2.new(
            gbWidget.Position.X.Scale, gbWidget.Position.X.Offset - 20,
            gbWidget.Position.Y.Scale, gbWidget.Position.Y.Offset - 6)
    end
end)

-- Open button next to Gangbang label (replaces old _gbWBtnPill)
-- ── Gangbang Widget-Open Button (Pill, 52×26) ──────────────────
local gbOpenBtnPill = Instance.new("Frame", gbRow)
gbOpenBtnPill.Size             = UDim2.new(0, 52, 0, 26)
gbOpenBtnPill.Position         = UDim2.new(0, 110, 0, 5)
gbOpenBtnPill.BackgroundColor3 = Color3.fromRGB(3, 20, 8)
gbOpenBtnPill.BackgroundTransparency = 0.05
gbOpenBtnPill.BorderSizePixel  = 0
gbOpenBtnPill.ZIndex           = 7
corner(gbOpenBtnPill, 13)
local gbOpenBtnS = Instance.new("UIStroke", gbOpenBtnPill)
gbOpenBtnS.Thickness = 1.5; gbOpenBtnS.Color = C.accent2; gbOpenBtnS.Transparency = 0.55
-- Left accent dot
local gbOBDot = Instance.new("Frame", gbOpenBtnPill)
gbOBDot.Size = UDim2.new(0,3,0,14); gbOBDot.Position = UDim2.new(0,0,0.5,-7)
gbOBDot.BackgroundColor3 = C.accent2; gbOBDot.BackgroundTransparency = 0.4
gbOBDot.BorderSizePixel = 0; gbOBDot.ZIndex = 8; corner(gbOBDot, 99)
-- Icon
local gbOBIco = Instance.new("TextLabel", gbOpenBtnPill)
gbOBIco.Size = UDim2.new(0,18,1,0); gbOBIco.Position = UDim2.new(0,4,0,0)
gbOBIco.BackgroundTransparency = 1; gbOBIco.Text = "+"
gbOBIco.Font = Enum.Font.GothamBlack; gbOBIco.TextSize = 12
gbOBIco.TextColor3 = C.accent2; gbOBIco.TextXAlignment = Enum.TextXAlignment.Center
gbOBIco.ZIndex = 9
-- Text
local gbOBTxt = Instance.new("TextLabel", gbOpenBtnPill)
gbOBTxt.Size = UDim2.new(1,-24,1,0); gbOBTxt.Position = UDim2.new(0,22,0,0)
gbOBTxt.BackgroundTransparency = 1; gbOBTxt.Text = "OPEN"
gbOBTxt.Font = Enum.Font.GothamBlack; gbOBTxt.TextSize = 9
gbOBTxt.TextColor3 = C.sub; gbOBTxt.TextXAlignment = Enum.TextXAlignment.Left
gbOBTxt.ZIndex = 9
-- Hitbox button
local gbOpenBtn = Instance.new("TextButton", gbOpenBtnPill)
gbOpenBtn.Size = UDim2.new(1,0,1,0); gbOpenBtn.BackgroundTransparency = 1
gbOpenBtn.Text = ""; gbOpenBtn.ZIndex = 12; gbOpenBtn.Active = true
gbOpenBtn.AutoButtonColor = false
local function gbDoOpenClose()
    if gbWidgetOpen then
        gbWClose()
        gbOBTxt.Text = "OPEN"; gbOBIco.TextColor3 = C.accent2
    else
        gbWOpen()
        gbOBTxt.Text = "CLOSE"; gbOBIco.TextColor3 = C.sub
    end
end
gbOpenBtn.MouseEnter:Connect(function()
    twP(gbOpenBtnPill, 0.08, {BackgroundColor3 = C.accent2, BackgroundTransparency = 0.78})
    twP(gbOBIco, 0.08, {TextColor3 = _C3_WHITE})
    twP(gbOBTxt, 0.08, {TextColor3 = _C3_WHITE})
    gbOpenBtnS.Transparency = 0.2
end)
gbOpenBtn.MouseLeave:Connect(function()
    twP(gbOpenBtnPill, 0.08, {BackgroundColor3 = Color3.fromRGB(3,20,8), BackgroundTransparency = 0.05})
    twP(gbOBIco, 0.08, {TextColor3 = C.accent2})
    twP(gbOBTxt, 0.08, {TextColor3 = C.sub})
    gbOpenBtnS.Transparency = 0.55
end)
gbOpenBtn.MouseButton1Click:Connect(gbDoOpenClose)
gbOpenBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then gbDoOpenClose() end
end)
-- Wire label refs for external close sync
gbOBTxt_ref = gbOBTxt
gbOBIco_ref = gbOBIco


end)()
local gbDdOpen = false
local gbDdFrame = Instance.new("Frame", ScreenGui)
gbDdFrame.BackgroundColor3 = C.bg2; gbDdFrame.BackgroundTransparency = 0.06
gbDdFrame.BorderSizePixel = 0; gbDdFrame.ZIndex = 50; gbDdFrame.Visible = false
gbDdFrame.ClipsDescendants = true
corner(gbDdFrame, 14); gradStroke(gbDdFrame, 1.5, 0.22)
local gbDdBg = Instance.new("UIGradient", gbDdFrame)
gbDdBg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, Color3.fromRGB(4,16,7)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(2,10,4)),
}; gbDdBg.Rotation = 135
local gbDdScroll = Instance.new("ScrollingFrame", gbDdFrame)
gbDdScroll.Size = UDim2.new(1,0,1,0); gbDdScroll.BackgroundTransparency = 1
gbDdScroll.BorderSizePixel = 0; gbDdScroll.ScrollBarThickness = 3
gbDdScroll.ScrollBarImageColor3 = C.red
gbDdScroll.ScrollingDirection = Enum.ScrollingDirection.Y
gbDdScroll.CanvasSize = UDim2.new(0,0,0,0); gbDdScroll.ZIndex = 51
local gbDdList = Instance.new("UIListLayout", gbDdScroll)
gbDdList.SortOrder = Enum.SortOrder.LayoutOrder; gbDdList.Padding = UDim.new(0,2)
local DD_IH = 34; local DD_MX = 5
local gbDdSlot = {tween=nil}
local function gbCloseDd()
if not gbDdOpen then return end; gbDdOpen = false
local t = twC(gbDdSlot,gbDdFrame,0.18,{Size=UDim2.new(0,gbDdFrame.Size.X.Offset,0,0)},Enum.EasingStyle.Quart,Enum.EasingDirection.In)
t.Completed:Connect(function() if not gbDdOpen then gbDdFrame.Visible = false end end)
end
local function gbBuildDd()
for _, ch in ipairs(gbDdScroll:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
local plrs = {}
for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LocalPlayer then table.insert(plrs, pl) end end
if #plrs == 0 then
local noLbl = Instance.new("TextLabel", gbDdScroll)
noLbl.Size = UDim2.new(1,0,0,DD_IH); noLbl.BackgroundTransparency = 1
noLbl.Text = T.rush_no_players; noLbl.Font = Enum.Font.GothamBold; noLbl.TextSize = 13
noLbl.TextColor3 = C.text; noLbl.ZIndex = 52
end
for _, pl in ipairs(plrs) do
local row = Instance.new("Frame", gbDdScroll)
row.Size = UDim2.new(1,-8,0,DD_IH); row.BackgroundColor3 = C.bg3
row.BackgroundTransparency = 0.85; row.BorderSizePixel = 0; row.ZIndex = 52
corner(row, 10)
local pad = Instance.new("UIPadding", row); pad.PaddingLeft = UDim.new(0, 11)
local nameLbl = Instance.new("TextLabel", row)
nameLbl.Size = UDim2.new(1,-10,1,0); nameLbl.BackgroundTransparency = 1
nameLbl.Text = pl.DisplayName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = (gbSelectedPlayer == pl) and C.red or C.text
nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 53
local rBtn = Instance.new("TextButton", row)
rBtn.Size = UDim2.new(1,0,1,0); rBtn.BackgroundTransparency = 1
rBtn.Text = ""; rBtn.ZIndex = 54
rBtn.MouseEnter:Connect(function() tw(row,0.1,{BackgroundTransparency=0.55}):Play(); tw(nameLbl,0.1,{TextColor3=C.red}):Play() end)
rBtn.MouseLeave:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.85})
if gbSelectedPlayer ~= pl then tw(nameLbl,0.1,{TextColor3=C.text}):Play() end
end)
rBtn.MouseButton1Click:Connect(function()
gbSelectedPlayer = pl
gbPillLbl.Text = pl.DisplayName; gbPillLbl.TextColor3 = C.red
twP(gbPill,0.08,{BackgroundTransparency=0.0})
task.delay(0.1, function() tw(gbPill,0.15,{BackgroundTransparency=0.08}):Play() end)
gbCloseDd()
end)
end
local cnt = math.max(1, #plrs)
gbDdScroll.CanvasSize = UDim2.new(0,0,0,cnt*(DD_IH+2)+6)
return math.min(cnt, DD_MX)*(DD_IH+2)+6
end
local function gbOpenDd()
if gbDdOpen then gbCloseDd(); return end; gbDdOpen = true
local abs = gbPill.AbsolutePosition; local absS = gbPill.AbsoluteSize
gbDdFrame.Position = UDim2.new(0, abs.X, 0, abs.Y + absS.Y + 4)
local th = gbBuildDd()
gbDdFrame.Size = UDim2.new(0, absS.X, 0, 0); gbDdFrame.Visible = true
twC(gbDdSlot,gbDdFrame,0.22,{Size=UDim2.new(0,absS.X,0,th)},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end
gbPillBtn.MouseButton1Click:Connect(gbOpenDd)
UserInputService.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function()
if gbDdOpen then
local mp = UserInputService:GetMouseLocation()
local ab = gbDdFrame.AbsolutePosition; local abS = gbDdFrame.AbsoluteSize
local ins = mp.X>=ab.X and mp.X<=ab.X+abS.X and mp.Y>=ab.Y and mp.Y<=ab.Y+abS.Y
local onP = false; pcall(function()
local pa = gbPill.AbsolutePosition; local ps = gbPill.AbsoluteSize
onP = mp.X>=pa.X and mp.X<=pa.X+ps.X and mp.Y>=pa.Y and mp.Y<=pa.Y+ps.Y
end)
if not ins and not onP then gbCloseDd() end
end
end)
end
end)
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. RUSH_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
sendNotif("Rush", T.rush_stopped, 1)
end
local function rushStart(targetPlayer)
rushStop()
local targetChar = targetPlayer and targetPlayer.Character
if not targetChar then sendNotif("Rush", T.rush_no_target_char, 2); return false end
local myChar = LocalPlayer.Character
if not myChar then sendNotif("Rush", T.rush_no_char, 2); return false end
local myHRP = myChar:FindFirstChild("HumanoidRootPart")
local hum   = myChar:FindFirstChildOfClass("Humanoid")
if not myHRP or not hum then sendNotif("Rush", T.rush_missing_parts, 2); return false end
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
sendNotif("Rush", T.rush_running .. targetPlayer.Name, 2)
return true
end
local rushRow = Instance.new("Frame", trollPage)
rushRow.Size = UDim2.new(1,0,0,72); rushRow.Position = UDim2.new(0,0,0,80)
rushRow.BackgroundColor3 = C.bg2 or _C3_BG2; rushRow.BackgroundTransparency = 0
rushRow.BorderSizePixel = 0; corner(rushRow, 12)
local rushRowS = Instance.new("UIStroke", rushRow)
rushRowS.Thickness = 1; rushRowS.Color = C.bg3 or _C3_BG3; rushRowS.Transparency = 0.3
local rushRowDot = Instance.new("Frame", rushRow)
rushRowDot.Size = UDim2.new(0,3,0,52); rushRowDot.Position = UDim2.new(0,0,0.5,-26)
rushRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220,60,60); rushRowDot.BackgroundTransparency = 0.4
rushRowDot.BorderSizePixel = 0; corner(rushRowDot, 99)
local rushLbl = Instance.new("TextLabel", rushRow)
rushLbl.Size = UDim2.new(0,50,0,28); rushLbl.Position = UDim2.new(0,14,0,4)
rushLbl.BackgroundTransparency = 1; rushLbl.Text = T.rush_label
rushLbl.Font = Enum.Font.GothamBold; rushLbl.TextSize = 13
rushLbl.TextColor3 = C.text; rushLbl.TextXAlignment = Enum.TextXAlignment.Left
local rushPill = Instance.new("Frame", rushRow)
rushPill.Size = UDim2.new(0,200,0,28); rushPill.Position = UDim2.new(0,14,1,-36)
rushPill.BackgroundColor3 = C.bg3; rushPill.BackgroundTransparency = 0.08
rushPill.BorderSizePixel = 0
corner(rushPill, 11); gradStroke(rushPill, 1.5, 0.3)
local rushPillLbl = Instance.new("TextLabel", rushPill)
rushPillLbl.Size = UDim2.new(1,-8,1,0); rushPillLbl.Position = UDim2.new(0,6,0,0)
rushPillLbl.BackgroundTransparency = 1; rushPillLbl.Text = T.rush_player_pill
rushPillLbl.Font = Enum.Font.GothamBold; rushPillLbl.TextSize = 13
rushPillLbl.TextColor3 = C.text; rushPillLbl.TextXAlignment = Enum.TextXAlignment.Left
rushPillLbl.TextTruncate = Enum.TextTruncate.AtEnd
local rushPillBtn = Instance.new("TextButton", rushPill)
rushPillBtn.Size = UDim2.new(1,0,1,0); rushPillBtn.BackgroundTransparency = 1
rushPillBtn.Text = ""; rushPillBtn.ZIndex = 6
local rushBtn = Instance.new("TextButton", rushRow)
rushBtn.Size = UDim2.new(0,70,0,28); rushBtn.Position = UDim2.new(1,-82,1,-36)
rushBtn.BackgroundColor3 = Color3.fromRGB(18,8,8); rushBtn.BackgroundTransparency = 0
rushBtn.BorderSizePixel = 0; rushBtn.Text = "Rush"
rushBtn.Font = Enum.Font.GothamBold; rushBtn.TextSize = 13
rushBtn.TextColor3 = C.text; rushBtn.ZIndex = 5
corner(rushBtn, 11)
local rushBtnS = Instance.new("UIStroke", rushBtn)
rushBtnS.Thickness = 1.2; rushBtnS.Color = C.red; rushBtnS.Transparency = 0.1
rushBtn.MouseButton1Click:Connect(function()
if not rushSelectedPlayer then
sendNotif("Rush", T.gb_select_player, 2); return
end
rushStart(rushSelectedPlayer)
end)
rushBtn.MouseEnter:Connect(function()
twP(rushBtn, 0.1, {BackgroundTransparency = 0.0})
end)
rushBtn.MouseLeave:Connect(function()
twP(rushBtn, 0.1, {BackgroundTransparency = 0.1})
end)
local rushWBtnPill = Instance.new("Frame", rushRow)
rushWBtnPill.Size             = UDim2.new(0, 52, 0, 26)
rushWBtnPill.Position         = UDim2.new(0, 70, 0, 5)
rushWBtnPill.BackgroundColor3 = Color3.fromRGB(3, 20, 8)
rushWBtnPill.BackgroundTransparency = 0.05
rushWBtnPill.BorderSizePixel  = 0
rushWBtnPill.ZIndex           = 7
corner(rushWBtnPill, 13)
local rushWBtnPillS = Instance.new("UIStroke", rushWBtnPill)
rushWBtnPillS.Thickness = 1.5; rushWBtnPillS.Color = C.accent2; rushWBtnPillS.Transparency = 0.55
local rushWBtnPillDot = Instance.new("Frame", rushWBtnPill)
rushWBtnPillDot.Size = UDim2.new(0,3,0,14); rushWBtnPillDot.Position = UDim2.new(0,0,0.5,-7)
rushWBtnPillDot.BackgroundColor3 = C.accent2; rushWBtnPillDot.BackgroundTransparency = 0.4
rushWBtnPillDot.BorderSizePixel = 0; rushWBtnPillDot.ZIndex = 8; corner(rushWBtnPillDot, 99)
local rushWBtnPillIco = Instance.new("TextLabel", rushWBtnPill)
rushWBtnPillIco.Size = UDim2.new(0,18,1,0); rushWBtnPillIco.Position = UDim2.new(0,4,0,0)
rushWBtnPillIco.BackgroundTransparency = 1; rushWBtnPillIco.Text = "+"
rushWBtnPillIco.Font = Enum.Font.GothamBlack; rushWBtnPillIco.TextSize = 12
rushWBtnPillIco.TextColor3 = C.accent2; rushWBtnPillIco.TextXAlignment = Enum.TextXAlignment.Center
rushWBtnPillIco.ZIndex = 9
local rushWBtnPillTxt = Instance.new("TextLabel", rushWBtnPill)
rushWBtnPillTxt.Size = UDim2.new(1,-24,1,0); rushWBtnPillTxt.Position = UDim2.new(0,22,0,0)
rushWBtnPillTxt.BackgroundTransparency = 1; rushWBtnPillTxt.Text = "OPEN"
rushWBtnPillTxt.Font = Enum.Font.GothamBlack; rushWBtnPillTxt.TextSize = 9
rushWBtnPillTxt.TextColor3 = C.sub; rushWBtnPillTxt.TextXAlignment = Enum.TextXAlignment.Left
rushWBtnPillTxt.ZIndex = 9
local rushWBtnPillBtn = Instance.new("TextButton", rushWBtnPill)
rushWBtnPillBtn.Size = UDim2.new(1,0,1,0); rushWBtnPillBtn.BackgroundTransparency = 1
rushWBtnPillBtn.Text = ""; rushWBtnPillBtn.ZIndex = 12; rushWBtnPillBtn.Active = true
rushWBtnPillBtn.AutoButtonColor = false
local rushWState = false
local function rushWBtnPillDo()
    local rushWState2 = rushWState or false
    createScriptWidget("Rush", C.accent2, function(on)
        rushWState = on
        if on then
            -- Auto-nearest
            local np = getNearestPlayer()
            if np then rushSelectedPlayer = np; rushPillLbl.Text = np.Name; rushPillLbl.TextColor3 = C.red end
            if not rushSelectedPlayer then sendNotif("Rush", T.gb_nobody_near, 2); return end
            rushStart(rushSelectedPlayer)
        else rushStop() end
    end, rushWState2)
end
rushWBtnPillBtn.MouseEnter:Connect(function()
    twP(rushWBtnPill, 0.08, {BackgroundColor3 = C.accent2, BackgroundTransparency = 0.78})
    twP(rushWBtnPillIco, 0.08, {TextColor3 = _C3_WHITE})
    twP(rushWBtnPillTxt, 0.08, {TextColor3 = _C3_WHITE})
    rushWBtnPillS.Transparency = 0.2
end)
rushWBtnPillBtn.MouseLeave:Connect(function()
    twP(rushWBtnPill, 0.08, {BackgroundColor3 = Color3.fromRGB(3,20,8), BackgroundTransparency = 0.05})
    twP(rushWBtnPillIco, 0.08, {TextColor3 = C.accent2})
    twP(rushWBtnPillTxt, 0.08, {TextColor3 = C.sub})
    rushWBtnPillS.Transparency = 0.55
end)
rushWBtnPillBtn.MouseButton1Click:Connect(rushWBtnPillDo)
rushWBtnPillBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then rushWBtnPillDo() end
end)
local rushDdOpen = false
local rushDdFrame = Instance.new("Frame", ScreenGui)
rushDdFrame.BackgroundColor3 = C.bg2; rushDdFrame.BackgroundTransparency = 0.06
rushDdFrame.BorderSizePixel = 0; rushDdFrame.ZIndex = 50; rushDdFrame.Visible = false
rushDdFrame.ClipsDescendants = true
corner(rushDdFrame, 14); gradStroke(rushDdFrame, 1.5, 0.22)
local rushDdBg = Instance.new("UIGradient", rushDdFrame)
rushDdBg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, Color3.fromRGB(4,16,7)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(2,10,4)),
}; rushDdBg.Rotation = 135
local rushDdScroll = Instance.new("ScrollingFrame", rushDdFrame)
rushDdScroll.Size = UDim2.new(1,0,1,0); rushDdScroll.BackgroundTransparency = 1
rushDdScroll.BorderSizePixel = 0; rushDdScroll.ScrollBarThickness = 3
rushDdScroll.ScrollBarImageColor3 = C.red
rushDdScroll.ScrollingDirection = Enum.ScrollingDirection.Y
rushDdScroll.CanvasSize = UDim2.new(0,0,0,0); rushDdScroll.ZIndex = 51
local rushDdList = Instance.new("UIListLayout", rushDdScroll)
rushDdList.SortOrder = Enum.SortOrder.LayoutOrder; rushDdList.Padding = UDim.new(0,2)
local RUSH_IH = 34; local RUSH_MX = 5
local rushDdSlot = {tween=nil}
local function rushCloseDd()
if not rushDdOpen then return end; rushDdOpen = false
local t = twC(rushDdSlot,rushDdFrame,0.18,{Size=UDim2.new(0,rushDdFrame.Size.X.Offset,0,0)},Enum.EasingStyle.Quart,Enum.EasingDirection.In)
t.Completed:Connect(function() if not rushDdOpen then rushDdFrame.Visible = false end end)
end
local function rushBuildDd()
for _, ch in ipairs(rushDdScroll:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
local plrs = {}
for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LocalPlayer then table.insert(plrs, pl) end end
if #plrs == 0 then
local noLbl = Instance.new("TextLabel", rushDdScroll)
noLbl.Size = UDim2.new(1,0,0,RUSH_IH); noLbl.BackgroundTransparency = 1
noLbl.Text = "No players online"; noLbl.Font = Enum.Font.GothamBold; noLbl.TextSize = 13
noLbl.TextColor3 = C.text; noLbl.ZIndex = 52
end
for _, pl in ipairs(plrs) do
local row = Instance.new("Frame", rushDdScroll)
row.Size = UDim2.new(1,-8,0,RUSH_IH); row.BackgroundColor3 = C.bg3
row.BackgroundTransparency = 0.85; row.BorderSizePixel = 0; row.ZIndex = 52
corner(row, 10)
local pad = Instance.new("UIPadding", row); pad.PaddingLeft = UDim.new(0, 11)
local nameLbl = Instance.new("TextLabel", row)
nameLbl.Size = UDim2.new(1,-10,1,0); nameLbl.BackgroundTransparency = 1
nameLbl.Text = pl.DisplayName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = (rushSelectedPlayer == pl) and C.red or C.text
nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 53
local rBtn = Instance.new("TextButton", row)
rBtn.Size = UDim2.new(1,0,1,0); rBtn.BackgroundTransparency = 1
rBtn.Text = ""; rBtn.ZIndex = 54
rBtn.MouseEnter:Connect(function() tw(row,0.1,{BackgroundTransparency=0.55}):Play(); tw(nameLbl,0.1,{TextColor3=C.red}):Play() end)
rBtn.MouseLeave:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.85})
if rushSelectedPlayer ~= pl then tw(nameLbl,0.1,{TextColor3=C.text}):Play() end
end)
rBtn.MouseButton1Click:Connect(function()
rushSelectedPlayer = pl
rushPillLbl.Text = pl.DisplayName; rushPillLbl.TextColor3 = C.red
twP(rushPill,0.08,{BackgroundTransparency=0.0})
task.delay(0.1, function() tw(rushPill,0.15,{BackgroundTransparency=0.08}):Play() end)
rushCloseDd()
end)
end
local cnt = math.max(1, #plrs)
rushDdScroll.CanvasSize = UDim2.new(0,0,0,cnt*(RUSH_IH+2)+6)
return math.min(cnt, RUSH_MX)*(RUSH_IH+2)+6
end
local function rushOpenDd()
if rushDdOpen then rushCloseDd(); return end; rushDdOpen = true
local abs = rushPill.AbsolutePosition; local absS = rushPill.AbsoluteSize
rushDdFrame.Position = UDim2.new(0, abs.X, 0, abs.Y + absS.Y + 4)
local th = rushBuildDd()
rushDdFrame.Size = UDim2.new(0, absS.X, 0, 0); rushDdFrame.Visible = true
twC(rushDdSlot,rushDdFrame,0.22,{Size=UDim2.new(0,absS.X,0,th)},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end
rushPillBtn.MouseButton1Click:Connect(rushOpenDd)
UserInputService.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function()
if rushDdOpen then
local mp = UserInputService:GetMouseLocation()
local ab = rushDdFrame.AbsolutePosition; local abS = rushDdFrame.AbsoluteSize
local ins = mp.X>=ab.X and mp.X<=ab.X+abS.X and mp.Y>=ab.Y and mp.Y<=ab.Y+abS.Y
local onP = false; pcall(function()
local pa = rushPill.AbsolutePosition; local ps = rushPill.AbsoluteSize
onP = mp.X>=pa.X and mp.X<=pa.X+ps.X and mp.Y>=pa.Y and mp.Y<=pa.Y+ps.Y
end)
if not ins and not onP then rushCloseDd() end
end
end)
end
end)
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
        pcall(function() if getgenv then getgenv()._TLFlingConn = nil end end)
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
    pcall(function() if getgenv then getgenv()._TLFlingConn = flingConn end end)
end
local flingRow = Instance.new("Frame", trollPage)
flingRow.Size = UDim2.new(1,0,0,72); flingRow.Position = UDim2.new(0,0,0,152)
flingRow.BackgroundColor3 = C.bg2 or _C3_BG2; flingRow.BackgroundTransparency = 0
flingRow.BorderSizePixel = 0; corner(flingRow, 12)
local flingRowS = Instance.new("UIStroke", flingRow)
flingRowS.Thickness = 1; flingRowS.Color = C.bg3 or _C3_BG3; flingRowS.Transparency = 0.3
local flingRowDot = Instance.new("Frame", flingRow)
flingRowDot.Size = UDim2.new(0,3,0,52); flingRowDot.Position = UDim2.new(0,0,0.5,-26)
flingRowDot.BackgroundColor3 = C.red or Color3.fromRGB(220,60,60); flingRowDot.BackgroundTransparency = 0.4
flingRowDot.BorderSizePixel = 0; corner(flingRowDot, 99)
local flingLbl = Instance.new("TextLabel", flingRow)
flingLbl.Size = UDim2.new(0,80,0,18); flingLbl.Position = UDim2.new(0,14,0,6)
flingLbl.BackgroundTransparency = 1; flingLbl.Text = "Fling"
flingLbl.Font = Enum.Font.GothamBold; flingLbl.TextSize = 13
flingLbl.TextColor3 = C.text or _C3_TEXT3
flingLbl.TextXAlignment = Enum.TextXAlignment.Left
local flingSub = Instance.new("TextLabel", flingRow)
flingSub.Size = UDim2.new(0,130,0,11); flingSub.Position = UDim2.new(0,14,0,24)
flingSub.BackgroundTransparency = 1; flingSub.Text = "skid fling  •  BodyVelocity"
flingSub.Font = Enum.Font.GothamBold; flingSub.TextSize = 9
flingSub.TextColor3 = C.sub or _C3_SUB
flingSub.TextXAlignment = Enum.TextXAlignment.Left
local flingPill = Instance.new("Frame", flingRow)
flingPill.Size = UDim2.new(0,170,0,26); flingPill.Position = UDim2.new(0,14,1,-34)
flingPill.BackgroundColor3 = C.bg3; flingPill.BackgroundTransparency = 0.08
flingPill.BorderSizePixel = 0
corner(flingPill, 11); gradStroke(flingPill, 1.5, 0.3)
local flingPillLbl = Instance.new("TextLabel", flingPill)
flingPillLbl.Size = UDim2.new(1,-8,1,0); flingPillLbl.Position = UDim2.new(0,6,0,0)
flingPillLbl.BackgroundTransparency = 1; flingPillLbl.Text = T.rush_player_pill
flingPillLbl.Font = Enum.Font.GothamBold; flingPillLbl.TextSize = 12
flingPillLbl.TextColor3 = C.text; flingPillLbl.TextXAlignment = Enum.TextXAlignment.Left
flingPillLbl.TextTruncate = Enum.TextTruncate.AtEnd
local flingPillBtn = Instance.new("TextButton", flingPill)
flingPillBtn.Size = UDim2.new(1,0,1,0); flingPillBtn.BackgroundTransparency = 1
flingPillBtn.Text = ""; flingPillBtn.ZIndex = 6
local flingTrack = Instance.new("Frame", flingRow)
flingTrack.Size = UDim2.new(0,32,0,18); flingTrack.Position = UDim2.new(1,-46,1,-34+4)
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
twP(flingRowS,  0.15, {Color = C.red or Color3.fromRGB(220,60,60), Transparency = 0.5})
-- Always get nearest player on toggle-ON
local np = getNearestPlayer()
if np then
    flingSelectedPlayer = np
    flingPillLbl.Text = np.DisplayName
    flingPillLbl.TextColor3 = C.red
end
if flingSelectedPlayer then
flingStart(flingSelectedPlayer)
else
sendNotif("Fling", T.gb_nobody_near, 2)
flingSetToggle(false); return
end
else
twP(flingTrack, 0.15, {BackgroundColor3 = C.bg3 or _C3_BG3, BackgroundTransparency = 0.2})
twP(flingKnob,  0.15, {BackgroundColor3 = _C3_SUB2, Position = UDim2.new(0,2,0.5,-6)})
twP(flingRowS,  0.15, {Color = C.bg3 or _C3_BG3, Transparency = 0.3})
flingSelectedPlayer = nil  -- reset so next ON picks fresh nearest
flingStop()
end
end
local flingRowBtn = Instance.new("TextButton", flingRow)
flingRowBtn.Size = UDim2.new(1,0,0,38); flingRowBtn.Position = UDim2.new(0,0,0,0)
flingRowBtn.BackgroundTransparency = 1; flingRowBtn.Text = ""; flingRowBtn.ZIndex = 5
flingRowBtn.MouseEnter:Connect(function()
twP(flingRow, 0.08, {BackgroundColor3 = C.bg3 or _C3_BG4})
end)
flingRowBtn.MouseLeave:Connect(function()
twP(flingRow, 0.08, {BackgroundColor3 = C.bg2 or _C3_BG2})
end)
local flingTogBtn = Instance.new("TextButton", flingRow)
flingTogBtn.Size = UDim2.new(0,50,0,30); flingTogBtn.Position = UDim2.new(1,-58,1,-36)
flingTogBtn.BackgroundTransparency = 1; flingTogBtn.Text = ""; flingTogBtn.ZIndex = 7
flingTogBtn.MouseButton1Click:Connect(function() flingSetToggle(not flingTogState) end)
local flingDdOpen  = false
local flingDdFrame = Instance.new("Frame", ScreenGui)
flingDdFrame.BackgroundColor3 = C.bg2; flingDdFrame.BackgroundTransparency = 0.06
flingDdFrame.BorderSizePixel = 0; flingDdFrame.ZIndex = 50; flingDdFrame.Visible = false
flingDdFrame.ClipsDescendants = true
corner(flingDdFrame, 14); gradStroke(flingDdFrame, 1.5, 0.22)
do
local flingDdBg = Instance.new("UIGradient", flingDdFrame)
flingDdBg.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0, Color3.fromRGB(4,16,7)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(2,10,4)),
}; flingDdBg.Rotation = 135
end
local flingDdScroll = Instance.new("ScrollingFrame", flingDdFrame)
flingDdScroll.Size = UDim2.new(1,0,1,0); flingDdScroll.BackgroundTransparency = 1
flingDdScroll.BorderSizePixel = 0; flingDdScroll.ScrollBarThickness = 3
flingDdScroll.ScrollBarImageColor3 = C.red
flingDdScroll.ScrollingDirection = Enum.ScrollingDirection.Y
flingDdScroll.CanvasSize = UDim2.new(0,0,0,0); flingDdScroll.ZIndex = 51
local flingDdList = Instance.new("UIListLayout", flingDdScroll)
flingDdList.SortOrder = Enum.SortOrder.LayoutOrder; flingDdList.Padding = UDim.new(0,2)
local FLING_IH = 34; local FLING_MX = 5
local flingDdSlot = {tween=nil}
local function flingCloseDd()
if not flingDdOpen then return end; flingDdOpen = false
local t = twC(flingDdSlot, flingDdFrame, 0.18,
{Size=UDim2.new(0,flingDdFrame.Size.X.Offset,0,0)},
Enum.EasingStyle.Quart, Enum.EasingDirection.In)
t.Completed:Connect(function() if not flingDdOpen then flingDdFrame.Visible = false end end)
end
local function flingBuildDd()
for _, ch in ipairs(flingDdScroll:GetChildren()) do
if ch:IsA("GuiObject") then ch:Destroy() end
end
local plrs = {}
for _, pl in ipairs(Players:GetPlayers()) do
if pl ~= LocalPlayer then table.insert(plrs, pl) end
end
if #plrs == 0 then
local noLbl = Instance.new("TextLabel", flingDdScroll)
noLbl.Size = UDim2.new(1,0,0,FLING_IH); noLbl.BackgroundTransparency = 1
noLbl.Text = "No players online"; noLbl.Font = Enum.Font.GothamBold; noLbl.TextSize = 13
noLbl.TextColor3 = C.text; noLbl.ZIndex = 52
end
for _, pl in ipairs(plrs) do
local row = Instance.new("Frame", flingDdScroll)
row.Size = UDim2.new(1,-8,0,FLING_IH); row.BackgroundColor3 = C.bg3
row.BackgroundTransparency = 0.85; row.BorderSizePixel = 0; row.ZIndex = 52
corner(row, 10)
local pad = Instance.new("UIPadding", row); pad.PaddingLeft = UDim.new(0,11)
local nameLbl = Instance.new("TextLabel", row)
nameLbl.Size = UDim2.new(1,-10,1,0); nameLbl.BackgroundTransparency = 1
nameLbl.Text = pl.DisplayName; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 13
nameLbl.TextColor3 = (flingSelectedPlayer == pl) and C.red or C.text
nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 53
local rBtn = Instance.new("TextButton", row)
rBtn.Size = UDim2.new(1,0,1,0); rBtn.BackgroundTransparency = 1
rBtn.Text = ""; rBtn.ZIndex = 54
rBtn.MouseEnter:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.55})
twP(nameLbl,0.1,{TextColor3=C.red})
end)
rBtn.MouseLeave:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.85})
if flingSelectedPlayer ~= pl then tw(nameLbl,0.1,{TextColor3=C.text}):Play() end
end)
rBtn.MouseButton1Click:Connect(function()
flingSelectedPlayer = pl
flingPillLbl.Text = pl.DisplayName; flingPillLbl.TextColor3 = C.red
twP(flingPill,0.08,{BackgroundTransparency=0.0})
task.delay(0.1, function() tw(flingPill,0.15,{BackgroundTransparency=0.08}):Play() end)
if flingTogState then flingStart(pl) end
flingCloseDd()
end)
end
local cnt = math.max(1, #plrs)
flingDdScroll.CanvasSize = UDim2.new(0,0,0,cnt*(FLING_IH+2)+6)
return math.min(cnt, FLING_MX)*(FLING_IH+2)+6
end
local function flingOpenDd()
if flingDdOpen then flingCloseDd(); return end; flingDdOpen = true
local abs = flingPill.AbsolutePosition; local absS = flingPill.AbsoluteSize
flingDdFrame.Position = UDim2.new(0, abs.X, 0, abs.Y + absS.Y + 4)
local th = flingBuildDd()
flingDdFrame.Size = UDim2.new(0, absS.X, 0, 0); flingDdFrame.Visible = true
twC(flingDdSlot, flingDdFrame, 0.22, {Size=UDim2.new(0,absS.X,0,th)},
Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end
flingPillBtn.MouseButton1Click:Connect(flingOpenDd)
_tlTrackConn(UserInputService.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
task.defer(function()
if flingDdOpen then
local mp = UserInputService:GetMouseLocation()
local ab = flingDdFrame.AbsolutePosition; local abS = flingDdFrame.AbsoluteSize
local ins = mp.X>=ab.X and mp.X<=ab.X+abS.X and mp.Y>=ab.Y and mp.Y<=ab.Y+abS.Y
local onP = false; pcall(function()
local pa = flingPill.AbsolutePosition; local ps = flingPill.AbsoluteSize
onP = mp.X>=pa.X and mp.X<=pa.X+ps.X and mp.Y>=pa.Y and mp.Y<=pa.Y+ps.Y
end)
if not ins and not onP then flingCloseDd() end
end
end)
end
end))
local flingWBtnPill = Instance.new("Frame", flingRow)
flingWBtnPill.Size             = UDim2.new(0, 52, 0, 26)
flingWBtnPill.Position         = UDim2.new(1, -106, 0, 5)
flingWBtnPill.BackgroundColor3 = Color3.fromRGB(3, 20, 8)
flingWBtnPill.BackgroundTransparency = 0.05
flingWBtnPill.BorderSizePixel  = 0
flingWBtnPill.ZIndex           = 7
corner(flingWBtnPill, 13)
local flingWBtnPillS = Instance.new("UIStroke", flingWBtnPill)
flingWBtnPillS.Thickness = 1.5; flingWBtnPillS.Color = C.accent2; flingWBtnPillS.Transparency = 0.55
local flingWBtnPillDot = Instance.new("Frame", flingWBtnPill)
flingWBtnPillDot.Size = UDim2.new(0,3,0,14); flingWBtnPillDot.Position = UDim2.new(0,0,0.5,-7)
flingWBtnPillDot.BackgroundColor3 = C.accent2; flingWBtnPillDot.BackgroundTransparency = 0.4
flingWBtnPillDot.BorderSizePixel = 0; flingWBtnPillDot.ZIndex = 8; corner(flingWBtnPillDot, 99)
local flingWBtnPillIco = Instance.new("TextLabel", flingWBtnPill)
flingWBtnPillIco.Size = UDim2.new(0,18,1,0); flingWBtnPillIco.Position = UDim2.new(0,4,0,0)
flingWBtnPillIco.BackgroundTransparency = 1; flingWBtnPillIco.Text = "+"
flingWBtnPillIco.Font = Enum.Font.GothamBlack; flingWBtnPillIco.TextSize = 12
flingWBtnPillIco.TextColor3 = C.accent2; flingWBtnPillIco.TextXAlignment = Enum.TextXAlignment.Center
flingWBtnPillIco.ZIndex = 9
local flingWBtnPillTxt = Instance.new("TextLabel", flingWBtnPill)
flingWBtnPillTxt.Size = UDim2.new(1,-24,1,0); flingWBtnPillTxt.Position = UDim2.new(0,22,0,0)
flingWBtnPillTxt.BackgroundTransparency = 1; flingWBtnPillTxt.Text = "OPEN"
flingWBtnPillTxt.Font = Enum.Font.GothamBlack; flingWBtnPillTxt.TextSize = 9
flingWBtnPillTxt.TextColor3 = C.sub; flingWBtnPillTxt.TextXAlignment = Enum.TextXAlignment.Left
flingWBtnPillTxt.ZIndex = 9
local flingWBtnPillBtn = Instance.new("TextButton", flingWBtnPill)
flingWBtnPillBtn.Size = UDim2.new(1,0,1,0); flingWBtnPillBtn.BackgroundTransparency = 1
flingWBtnPillBtn.Text = ""; flingWBtnPillBtn.ZIndex = 12; flingWBtnPillBtn.Active = true
flingWBtnPillBtn.AutoButtonColor = false
local flingWState = false
local function flingWBtnPillDo()
    local flingWState2 = flingWState or false
    createScriptWidget("Fling", C.accent2, function(on)
        flingWState = on
        if on then
            -- Always get nearest on toggle-ON
            local np = getNearestPlayer()
            if np then flingSelectedPlayer = np; flingPillLbl.Text = np.DisplayName; flingPillLbl.TextColor3 = C.red end
            if flingSelectedPlayer then flingStart(flingSelectedPlayer)
            else sendNotif("Fling", T.gb_nobody_near, 2) end
        else
            flingSelectedPlayer = nil  -- reset for next ON
            flingStop()
        end
    end, flingWState2)
end
flingWBtnPillBtn.MouseEnter:Connect(function()
    twP(flingWBtnPill, 0.08, {BackgroundColor3 = C.accent2, BackgroundTransparency = 0.78})
    twP(flingWBtnPillIco, 0.08, {TextColor3 = _C3_WHITE})
    twP(flingWBtnPillTxt, 0.08, {TextColor3 = _C3_WHITE})
    flingWBtnPillS.Transparency = 0.2
end)
flingWBtnPillBtn.MouseLeave:Connect(function()
    twP(flingWBtnPill, 0.08, {BackgroundColor3 = Color3.fromRGB(3,20,8), BackgroundTransparency = 0.05})
    twP(flingWBtnPillIco, 0.08, {TextColor3 = C.accent2})
    twP(flingWBtnPillTxt, 0.08, {TextColor3 = C.sub})
    flingWBtnPillS.Transparency = 0.55
end)
flingWBtnPillBtn.MouseButton1Click:Connect(flingWBtnPillDo)
flingWBtnPillBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then flingWBtnPillDo() end
end)
LocalPlayer.CharacterAdded:Connect(function()
_flingSavedCFrame = nil
_flingDisconnect()
flingTogState = false
twP(flingTrack, 0.15, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2})
twP(flingKnob,  0.15, {BackgroundColor3 = _C3_SUB2, Position = UDim2.new(0,2,0.5,-6)})
twP(flingRowS,  0.15, {Color = C.bg3, Transparency = 0.3})
end)
end
trollPage.Size = UDim2.new(1, 0, 0, 232)
local movePage = Instance.new("Frame", sSubArea)
movePage.BackgroundTransparency = 1; movePage.BorderSizePixel = 0
movePage.Visible = false
do
local row = Instance.new("Frame", movePage)
row.Size = UDim2.new(1, 0, 0, 46); row.Position = UDim2.new(0, 0, 0, 0)
row.BackgroundColor3 = C.bg2 or _C3_BG2; row.BackgroundTransparency = 0; row.BorderSizePixel = 0
corner(row, 12)
local rowS = Instance.new("UIStroke", row); rowS.Thickness = 1; rowS.Color = C.bg3 or _C3_BG3; rowS.Transparency = 0.3
local rowD = Instance.new("Frame", row); rowD.Size = UDim2.new(0,3,0,26); rowD.Position = UDim2.new(0,0,0.5,-13)
rowD.BackgroundColor3 = C.green; rowD.BackgroundTransparency = 0.4; rowD.BorderSizePixel = 0; corner(rowD, 99)
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
speedLbl.TextColor3 = C.green; speedLbl.TextXAlignment = Enum.TextXAlignment.Center
local trackBg = Instance.new("Frame", row)
trackBg.Size = UDim2.new(0, 140, 0, 8); trackBg.Position = UDim2.new(0, 182, 0.5, -4)
trackBg.BackgroundColor3 = C.bg3; trackBg.BorderSizePixel = 0
corner(trackBg, 4); stroke(trackBg, 1, C.green, 0.6)
local trackFill = Instance.new("Frame", trackBg)
trackFill.Size = UDim2.new((SPEED_DEFAULT - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1, 0)
trackFill.Position = UDim2.new(0, 0, 0, 0); trackFill.BackgroundColor3 = C.green
trackFill.BorderSizePixel = 0; corner(trackFill, 4)
local knob = Instance.new("Frame", trackBg)
knob.Size = UDim2.new(0, 14, 0, 14)
knob.Position = UDim2.new((SPEED_DEFAULT - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), -7, 0.5, -7)
knob.BackgroundColor3 = _C3_WHITE; knob.BorderSizePixel = 0; knob.ZIndex = 5
corner(knob, 99)
local ks = Instance.new("UIStroke", knob); ks.Thickness = 1.5; ks.Color = C.green; ks.Transparency = 0
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
addWidgetBtn(row, "Speed Hack", C.green, function(on)
speedActive = on
local h = getHumanoid(); if h then h.WalkSpeed = on and speedVal or 16 end
end, function() return speedActive end, 330)
makeToggle(row, 405, 11, false, function(on)
speedActive = on
local h = getHumanoid(); if h then h.WalkSpeed = on and speedVal or 16 end
end)
end
local circleModel      = nil
local circleRadius     = 5
local segments         = 24
local segmentParts     = {}
local updateConnUI     = nil
local highlightMap     = {}
local uiActive         = false
local lastRadius       = 5
local teleportCooldown = 0.1
local lastTeleportTime = 0
local function isPositionSafe(pos)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Blacklist
params.FilterDescendantsInstances = {LocalPlayer.Character}
local ray = _workspace:Raycast(pos + Vector3.new(0,5,0), Vector3.new(0,-15,0), params)
return ray ~= nil
end
local function ultraTeleport(enemyPos)
local myChar = LocalPlayer.Character
if not myChar or not myChar.PrimaryPart then return end
local myPos = myChar.PrimaryPart.Position
local dir  = (myPos - enemyPos).Unit
local perp = Vector3.new(-dir.Z, 0, dir.X)
local dodges = {
myPos + perp * circleRadius * 1.2, myPos - perp * circleRadius * 1.2,
myPos + dir  * circleRadius * 1.3, myPos - dir  * circleRadius * 1.3,
}
for _, dodgePos in ipairs(dodges) do
local safePos = Vector3.new(dodgePos.X, myPos.Y, dodgePos.Z)
if isPositionSafe(safePos) then myChar.PrimaryPart.CFrame = CFrame.new(safePos); lastTeleportTime = os.clock(); return true end
end
return false
end
local function clearCircleUI()
if updateConnUI then updateConnUI:Disconnect(); updateConnUI = nil end
if circleModel  then circleModel:Destroy(); circleModel = nil end
segmentParts = {}
for _, hl in pairs(highlightMap) do if hl then hl:Destroy() end end
highlightMap = {}; uiActive = false
end
local function createCircleUI(radius)
clearCircleUI(); circleRadius = radius
local char = LocalPlayer.Character
if not char or not char.PrimaryPart then return end
circleModel = Instance.new("Model"); circleModel.Name = "UltraInstinctCircle"; circleModel.Parent = _workspace
for i = 1, segments do
local angle = (i-1) * (2 * math.pi / segments)
local seg = Instance.new("Part"); seg.Anchored = true; seg.CanCollide = false
seg.Size = Vector3.new(1.2,0.15,1.2); seg.Material = Enum.Material.Neon
seg.Color = Color3.fromRGB(60,180,210); seg.Transparency = 0.2; seg.Parent = circleModel
seg.CFrame = CFrame.new(char.PrimaryPart.Position + Vector3.new(math.cos(angle)*radius, 0.3, math.sin(angle)*radius))
table.insert(segmentParts, seg)
end
local _uiAcc = 0
local _segAcc = 0
local _lastCenter = Vector3.new(1e6, 1e6, 1e6)
local _uiSegCount  = #segmentParts
local _uiStep      = _uiSegCount > 0 and (2*math.pi/_uiSegCount) or 0
if updateConnUI then pcall(function() updateConnUI:Disconnect() end); updateConnUI = nil end
updateConnUI = RunService.Heartbeat:Connect(function(dt)
local ch = LocalPlayer.Character; if not ch or not ch.PrimaryPart then return end
local centerPos = ch.PrimaryPart.Position
_segAcc = _segAcc + dt
if _segAcc >= 0.1 then
_segAcc = 0
local t = os.clock()
local r = circleRadius*0.95
local cX, cY, cZ = centerPos.X, centerPos.Y + 0.3, centerPos.Z
local t4 = t * 4
for i = 1, _uiSegCount do
    local seg = segmentParts[i]
    if seg then
        local angle = (i-1)*_uiStep + t4
        seg.CFrame = _CFnew(cX + _mcos(angle)*r, cY, cZ + _msin(angle)*r)
    end
end
end
_uiAcc = _uiAcc + dt
if _uiAcc < 0.1 then return end
_uiAcc = 0
if os.clock()-lastTeleportTime < teleportCooldown then return end
local _r2 = (circleRadius+8)*(circleRadius+8)
local _plrs = Players:GetPlayers()
for _pi = 1, #_plrs do
local pl = _plrs[_pi]
if pl ~= LocalPlayer then
local plChar = pl.Character
local plPP = plChar and plChar.PrimaryPart
if plPP then
local enemyPos = plPP.Position
local dx = centerPos.X-enemyPos.X; local dz = centerPos.Z-enemyPos.Z
local dist2 = dx*dx + dz*dz
if dist2 <= _r2 and dist2 > 9 then
if not highlightMap[pl] then
pcall(function()
local hl = Instance.new("Highlight"); hl.Adornee = pl.Character
hl.FillColor = Color3.fromRGB(255,100,100); hl.OutlineColor = Color3.fromRGB(255,0,0)
hl.FillTransparency = 0.4; hl.Parent = _workspace; highlightMap[pl] = hl
end)
end
ultraTeleport(enemyPos); break
else
if highlightMap[pl] then highlightMap[pl]:Destroy(); highlightMap[pl] = nil end
end
end
end
end
end)
uiActive = true
end
LocalPlayer.CharacterAdded:Connect(function()
task.wait(0.5); if uiActive and lastRadius then createCircleUI(lastRadius) end
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
sendNotif("Anti-Void", "🛡 Void erkannt – zurückgerettet!", 2)
task.delay(0.5, function()
avRescuing = false
end)
end)
end
sRow(movePage, 0, "Anti-Void", "Movement", C.accent2 or C.accent, false, function(on)
if on then avStart()
else avStop() end
end)
pcall(function()
if getgenv then
local prev = getgenv().TLUnload
getgenv().TLUnload = function()
pcall(avStop)
if prev then pcall(prev) end
end
end
end)
end
local uiRow, uiSetToggle, _ = sRow(movePage, 56, "Ultra Instinct", "Movement", C.accent, false, function(on)
if on then createCircleUI(lastRadius)
else clearCircleUI() end
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
corner(uiTrack, 4); stroke(uiTrack, 1, C.accent, 0.6)
local uiFill = Instance.new("Frame", uiTrack)
uiFill.Size = UDim2.new((lastRadius - UI_MIN) / (UI_MAX - UI_MIN), 0, 1, 0)
uiFill.Position = UDim2.new(0, 0, 0, 0); uiFill.BackgroundColor3 = C.accent
uiFill.BorderSizePixel = 0; corner(uiFill, 4)
local uiKnob = Instance.new("Frame", uiTrack)
uiKnob.Size = UDim2.new(0, 14, 0, 14)
uiKnob.Position = UDim2.new((lastRadius - UI_MIN) / (UI_MAX - UI_MIN), -7, 0.5, -7)
uiKnob.BackgroundColor3 = _C3_WHITE; uiKnob.BorderSizePixel = 0; uiKnob.ZIndex = 5
corner(uiKnob, 99)
local uiKS = Instance.new("UIStroke", uiKnob); uiKS.Thickness = 1.5; uiKS.Color = C.accent; uiKS.Transparency = 0
local uiDragging = false
local UIS = UserInputService or game:GetService("UserInputService")
local function updateUISlider(absX)
local trackX = uiTrack.AbsolutePosition.X
local trackW = uiTrack.AbsoluteSize.X
if trackW <= 0 then return end
local ratio = math.clamp((absX - trackX) / trackW, 0, 1)
lastRadius = math.max(1, math.floor(UI_MIN + ratio * (UI_MAX - UI_MIN)))
uiFill.Size = UDim2.new(ratio, 0, 1, 0)
uiKnob.Position = UDim2.new(ratio, -7, 0.5, -7)
uiValLbl.Text = tostring(lastRadius)
if uiActive then circleRadius = lastRadius end
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
local _uiDragAcc = 0
_tlTrackConn(RunService.Heartbeat:Connect(function(dt)
if not uiDragging then return end
_uiDragAcc = _uiDragAcc + dt
if _uiDragAcc < 0.033 then return end
_uiDragAcc = 0
if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
uiDragging = false; return
end
updateUISlider(UIS:GetMouseLocation().X)
end))
end
movePage.Size = UDim2.new(1, 0, 0, 164)
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
local espDdFrame = Instance.new("Frame", visualPage)
espDdFrame.Size              = UDim2.new(0, PILL_W, 0, 0)
espDdFrame.Position          = UDim2.new(0, 210, 0, 46 + 3)
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
espDdScroll.ScrollBarThickness   = 2
espDdScroll.ScrollBarImageColor3 = C.accent2
espDdScroll.ScrollingDirection   = Enum.ScrollingDirection.Y
espDdScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
espDdScroll.ElasticBehavior      = Enum.ElasticBehavior.Never
espDdScroll.ZIndex               = 21
local espDdList = Instance.new("UIListLayout", espDdScroll)
espDdList.SortOrder = Enum.SortOrder.LayoutOrder
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
twP(item, 0.08, {BackgroundTransparency=0.5})
end)
item.MouseLeave:Connect(function()
twP(item, 0.08, {BackgroundTransparency=0.85})
end)
item.MouseButton1Click:Connect(function()
espColorIdx = i
espSwatch.BackgroundColor3 = entry.color
espColLbl.Text = entry.name
-- ✅ FIX: Alle Texte zurücksetzen auf C.text
for _, ch in ipairs(espDdScroll:GetChildren()) do
if ch:IsA("TextButton") then
local l = ch:FindFirstChildOfClass("TextLabel")
if l then l.TextColor3 = C.text end
end
end
-- ✅ NUR der aktuelle Text wird farbig (nicht wie alle anderen)
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
        -- ✅ FIX: Alle Texte zurücksetzen auf C.text
        for _, ch in ipairs(espDdScroll:GetChildren()) do
            if ch:IsA("TextButton") then
                local l = ch:FindFirstChildOfClass("TextLabel")
                if l then l.TextColor3 = C.text end
            end
        end
        -- ✅ NUR der aktuelle Text wird farbig (nicht wie alle anderen)
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
visualPage.Size = UDim2.new(1, 0, 0, 46)
local sonstigePage = Instance.new("Frame", sSubArea)
sonstigePage.BackgroundTransparency = 1; sonstigePage.BorderSizePixel = 0
sonstigePage.Visible = false
-- ── UIListLayout: stapelt Misc-Einträge automatisch ───────────────────────
local miscLayout = Instance.new("UIListLayout", sonstigePage)
miscLayout.SortOrder     = Enum.SortOrder.LayoutOrder
miscLayout.FillDirection = Enum.FillDirection.Vertical
miscLayout.Padding       = UDim.new(0, 0)

-- Panel-Höhe nach Ordner-Toggle neu berechnen
local function updateMiscSize()
    local H = miscLayout.AbsoluteContentSize.Y
    sonstigePage.Size = UDim2.new(1, 0, 0, math.max(H, 1))
    if sActiveCat ~= "Misc" then return end
    local newH = 56 + (S_CARD_H + 12) + H + 32
    p.ClipsDescendants = false; c.ClipsDescendants = false
    twP(sSubArea, 0.22, {Size = UDim2.new(1, 0, 0, H + 16)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    twP(p,        0.22, {Size = UDim2.new(0, PANEL_W, 0, newH)},  Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    c.Size = UDim2.new(1, 0, 0, newH - 56)
    c.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- Generic panel resize — called by any folder open/close in any subpage
local function updateActiveCatSize()
    if not sActiveCat then return end
    local pg = sSubPages and sSubPages[sActiveCat]
    if not pg then return end
    -- Let the page's layout settle first
    task.defer(function()
        local pgH = pg.AbsoluteSize.Y
        if pgH < 1 then pgH = pg.Size.Y.Offset end
        local HEADER_OFF  = 56
        local CONTENT_OFF = S_CARD_H + 12
        local newH = HEADER_OFF + CONTENT_OFF + pgH + 32
        p.ClipsDescendants = false; c.ClipsDescendants = false
        twP(sSubArea, 0.22, {Size = UDim2.new(1, 0, 0, pgH + 16)},
            Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        twP(p, 0.22, {Size = UDim2.new(0, PANEL_W, 0, newH)},
            Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        c.Size = UDim2.new(1, 0, 0, newH - HEADER_OFF)
        c.CanvasSize = UDim2.new(0, 0, 0, 0)
    end)
end

-- ── Ordner-Funktion für Misc ──────────────────────────────────────────────
-- Gibt (container, content, addRow) zurück.
-- addRow(label, badge, badgeCol, initOn, onToggle) → row, setFn, getFn
local FOLDER_HDR_H = 40
local function makeMiscFolder(folderName, folderIcon, accentCol, layoutOrder, pageParent)
    local isOpen    = false
    local childrenH = 0
    local childCount = 0

    local container = Instance.new("Frame", pageParent or sonstigePage)
    container.Size                   = UDim2.new(1, 0, 0, FOLDER_HDR_H)
    container.BackgroundTransparency = 1
    container.BorderSizePixel        = 0
    container.LayoutOrder            = layoutOrder
    container.ClipsDescendants       = false

    -- Header
    local hdr = Instance.new("Frame", container)
    hdr.Size             = UDim2.new(1, 0, 0, FOLDER_HDR_H)
    hdr.Position         = UDim2.new(0, 0, 0, 0)
    hdr.BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)
    hdr.BackgroundTransparency = 0
    hdr.BorderSizePixel  = 0
    corner(hdr, 10)

    local hdrStr = Instance.new("UIStroke", hdr)
    hdrStr.Thickness       = 1
    hdrStr.Color           = accentCol
    hdrStr.Transparency    = 0.55
    hdrStr.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local hdrDot = Instance.new("Frame", hdr)
    hdrDot.Size             = UDim2.new(0, 3, 0, FOLDER_HDR_H - 16)
    hdrDot.Position         = UDim2.new(0, 0, 0.5, -(FOLDER_HDR_H - 16) / 2)
    hdrDot.BackgroundColor3 = accentCol
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
    iconLbl.TextColor3           = accentCol
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

    -- Badge (Anzahl Scripts)
    local badge = Instance.new("Frame", hdr)
    badge.Size             = UDim2.new(0, 18, 0, 14)
    badge.Position         = UDim2.new(1, -50, 0.5, -7)
    badge.BackgroundColor3 = accentCol
    badge.BackgroundTransparency = 0.78
    badge.BorderSizePixel  = 0
    corner(badge, 99)
    local badgeLbl = Instance.new("TextLabel", badge)
    badgeLbl.Size                 = UDim2.new(1, 0, 1, 0)
    badgeLbl.BackgroundTransparency = 1
    badgeLbl.Text                 = "0"
    badgeLbl.Font                 = Enum.Font.GothamBlack
    badgeLbl.TextSize             = 9
    badgeLbl.TextColor3           = accentCol
    badgeLbl.TextXAlignment       = Enum.TextXAlignment.Center

    -- Chevron-Pfeil
    local chevron = Instance.new("TextLabel", hdr)
    chevron.Size                 = UDim2.new(0, 20, 0, 20)
    chevron.Position             = UDim2.new(1, -26, 0.5, -10)
    chevron.BackgroundTransparency = 1
    chevron.Text                 = "▶"
    chevron.Font                 = Enum.Font.GothamBlack
    chevron.TextSize             = 10
    chevron.TextColor3           = accentCol
    chevron.TextXAlignment       = Enum.TextXAlignment.Center

    -- Inhalt (ClipsDescendants für Slide-Animation)
    -- Thin divider line between header and content
    local divider = Instance.new("Frame", container)
    divider.Size             = UDim2.new(1, -16, 0, 1)
    divider.Position         = UDim2.new(0, 8, 0, FOLDER_HDR_H)
    divider.BackgroundColor3 = accentCol
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

    -- Klick-Button
    local btn = Instance.new("TextButton", hdr)
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""; btn.ZIndex  = 6

    btn.MouseEnter:Connect(function()
        twP(hdr, 0.08, {BackgroundColor3 = C.bg3 or Color3.fromRGB(7, 22, 10)})
    end)
    btn.MouseLeave:Connect(function()
        twP(hdr, 0.08, {BackgroundColor3 = C.bg2 or Color3.fromRGB(3, 14, 6)})
    end)
    local _folderAnimating = false
    btn.MouseButton1Click:Connect(function()
        if _folderAnimating then return end
        isOpen = not isOpen
        if isOpen then
            _folderAnimating = true
            content.Size    = UDim2.new(1, 0, 0, 0)
            content.Visible = true
            divider.Visible = true
            -- container.Size sofort auf Endgröße setzen → miscLayout-Signal feuert
            -- nur EINMAL mit dem korrekten Endwert, nicht jeden Tween-Frame
            container.Size = UDim2.new(1, 0, 0, FOLDER_HDR_H + childrenH)
            -- Nur content tweenen; ClipsDescendants blendet den Rest aus
            twP(content, 0.24, {Size = UDim2.new(1, 0, 0, childrenH)},
                Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            twP(chevron, 0.20, {Rotation = 90},  Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            twP(hdrStr,  0.20, {Transparency = 0.18})
            task.delay(0.26, function()
                _folderAnimating = false
            end)
        else
            _folderAnimating = true
            twP(content, 0.20, {Size = UDim2.new(1, 0, 0, 0)},
                Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            twP(chevron, 0.18, {Rotation = 0},  Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            twP(hdrStr,  0.18, {Transparency = 0.55})
            task.delay(0.22, function()
                -- container zurücksetzen nachdem content-Tween fertig
                container.Size  = UDim2.new(1, 0, 0, FOLDER_HDR_H)
                content.Visible = false
                divider.Visible = false
                _folderAnimating = false
            end)
        end
    end)

    -- Hilfsfunktion: Kind-Row zum Ordner hinzufügen
    local function addRow(label, badge2, badgeCol, initOn, onToggle)
        local ROW_H    = 46
        local PAD_H    = 6   -- top padding before first row + gap between rows
        local PAD_SIDE = 8   -- horizontal inset on each side
        local yPos = PAD_H + childCount * (ROW_H + 4)
        local row, setFn, getFn = cleanRow(content, yPos, label, badge2, badgeCol, initOn, onToggle)
        -- Apply horizontal margin and slight height reduction to avoid cramping
        row.Size     = UDim2.new(1, -PAD_SIDE * 2, 0, ROW_H)
        row.Position = UDim2.new(0, PAD_SIDE, 0, yPos)
        childCount  = childCount + 1
        childrenH   = PAD_H + childCount * (ROW_H + 4) + PAD_H
        badgeLbl.Text = tostring(childCount)
        content.Size    = UDim2.new(1, 0, 0, isOpen and childrenH or 0)
        container.Size  = UDim2.new(1, 0, 0, FOLDER_HDR_H + (isOpen and childrenH or 0))
        return row, setFn, getFn
    end

    return container, content, addRow
end
-- ══════════════════════════════════════════════════════════════════
-- Combat Page (Aimbot)
-- ══════════════════════════════════════════════════════════════════
local combatPage = Instance.new("Frame", sSubArea)
combatPage.BackgroundTransparency = 1; combatPage.BorderSizePixel = 0
combatPage.Visible = false
local combatLayout = Instance.new("UIListLayout", combatPage)
combatLayout.SortOrder     = Enum.SortOrder.LayoutOrder
combatLayout.FillDirection = Enum.FillDirection.Vertical
combatLayout.Padding       = UDim.new(0, 0)
combatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local H = combatLayout.AbsoluteContentSize.Y
    if H > 1 then
        combatPage.Size = UDim2.new(1, 0, 0, H)
        if typeof(updateActiveCatSize) == "function" then
            updateActiveCatSize()
        end
    end
end)

local combatContainer, combatContent, combatAddRow = makeMiscFolder("Combat Tools", "TL", C.red, 1, combatPage)

do
-- Outer refs so toggle can control the script
local _espStop  = nil
local _espStart = nil
local _espGui   = nil  -- direct outer reference to the ScreenGui

local function _launchESPTracker()
    if _espStop then _espStop() end  -- cleanup previous run

    local _conns = {}
    local function _trackFn(c) _conns[#_conns+1] = c; return c end

    local Camera = workspace.CurrentCamera

-- ╔══════════════════════════════════════════════════════╗
-- ║      MATRIX HITBOX TRACKER — ESP FIXED               ║
-- ║  Drawing API 2D Box ESP (kein SelectionBox Bug)      ║
-- ╚══════════════════════════════════════════════════════╝

local Camera           = workspace.CurrentCamera

-- ══════════════════════════════════════════════════════
--  KONFIGURATION
-- ══════════════════════════════════════════════════════
local CFG = {
    espEnabled      = true,
    tagEnabled      = true,
    teamCheck       = false,
    espMaxDist      = 500,
    tagStudsOffset  = Vector3.new(0, 3.2, 0),
    green           = Color3.fromRGB(0,   255, 65),
    greendim        = Color3.fromRGB(0,   170, 42),
    red             = Color3.fromRGB(255, 34,  68),
    yellow          = Color3.fromRGB(255, 227, 0),
    numSegments     = 10,
    critThreshold   = 25,
    boxThickness    = 1.5,
    cornerLen       = 0.22,   -- Anteil der Seite der als Ecke gezeichnet wird
}

-- ══════════════════════════════════════════════════════
--  HILFSFUNKTIONEN
-- ══════════════════════════════════════════════════════
local function getHRP(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
end

local function getHP(plr)
    local char = plr.Character
    if not char then return 0, 100 end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return 0, 100 end
    return hum.Health, hum.MaxHealth
end

local function getDistance(plr)
    local myChar = LocalPlayer.Character
    local theirChar = plr.Character
    if not myChar or not theirChar then return 9999 end
    local myRoot    = getHRP(myChar)
    local theirRoot = getHRP(theirChar)
    if not myRoot or not theirRoot then return 9999 end
    return (myRoot.Position - theirRoot.Position).Magnitude
end

local function hpColor(hp, maxHp)
    local pct = hp / math.max(maxHp, 1)
    if hp <= 0        then return CFG.red
    elseif pct <= 0.25 then return CFG.red
    elseif pct <= 0.60 then return CFG.yellow
    else                   return CFG.green
    end
end

local function threatText(hp, maxHp)
    local pct = hp / math.max(maxHp, 1)
    if hp <= 0         then return "FLATLINE"
    elseif pct <= 0.25 then return "CRITICAL"
    elseif pct <= 0.60 then return "MEDIUM"
    else                   return "LOW"
    end
end

-- ══════════════════════════════════════════════════════
--  DRAWING API — ESP BOX
--  Zeichnet einen 2D-Rahmen mit L-förmigen Ecken
--  direkt auf den Screen. Kein SelectionBox-Bug.
-- ══════════════════════════════════════════════════════
local function newLine(col, thick)
    local l = Drawing.new("Line")
    l.Visible   = false
    l.Color     = col or CFG.green
    l.Thickness = thick or CFG.boxThickness
    l.Transparency = 1
    return l
end

local function newDrawText(txt, size, col)
    local t = Drawing.new("Text")
    t.Visible   = false
    t.Text      = txt or ""
    t.Size      = size or 13
    t.Color     = col or CFG.green
    t.Outline   = true
    t.OutlineColor = Color3.new(0,0,0)
    t.Font      = Drawing.Fonts.Monospace
    t.Transparency = 1
    return t
end

-- Erstellt 8 Linien für L-Ecken + 1 Healthbar + 1 Namenstext
local function createESPBox()
    local lines = {}
    -- 8 Linien: je 2 pro Ecke (TL, TR, BL, BR)
    for i = 1, 8 do
        lines[i] = newLine(CFG.green, CFG.boxThickness)
    end
    local hpBg   = newLine(Color3.fromRGB(0,20,8), CFG.boxThickness + 1)
    local hpBar  = newLine(CFG.green, CFG.boxThickness)
    local nameTx = newDrawText("", 12, CFG.green)
    local distTx = newDrawText("", 10, CFG.greendim)
    return { lines=lines, hpBg=hpBg, hpBar=hpBar, nameTx=nameTx, distTx=distTx }
end

local function removeESPBox(esp)
    if not esp then return end
    for _, l in ipairs(esp.lines) do pcall(function() l:Remove() end) end
    pcall(function() esp.hpBg:Remove() end)
    pcall(function() esp.hpBar:Remove() end)
    pcall(function() esp.nameTx:Remove() end)
    pcall(function() esp.distTx:Remove() end)
end

local function hideESPBox(esp)
    if not esp then return end
    for _, l in ipairs(esp.lines) do l.Visible = false end
    esp.hpBg.Visible  = false
    esp.hpBar.Visible = false
    esp.nameTx.Visible = false
    esp.distTx.Visible = false
end

--[[
    updateESPBox berechnet die Screen-Bounding-Box des Characters,
    dann zeichnet es L-förmige Ecken + HP-Bar + Name.
    
    Skeleton-Punkte: Head-Top, Foot-Bottom, Left/Right-Seiten
    werden per WorldToViewportPoint projiziert.
]]
local function updateESPBox(esp, plr)
    if not esp or not CFG.espEnabled then hideESPBox(esp) return end

    local char = plr.Character
    if not char then hideESPBox(esp) return end

    local hrp  = getHRP(char)
    local head = getHead(char)
    if not hrp or not head then hideESPBox(esp) return end

    local hp, maxHp = getHP(plr)
    local dist      = getDistance(plr)

    if dist > CFG.espMaxDist or hp <= 0 then hideESPBox(esp) return end

    -- Projiziere Top (über dem Kopf) und Bottom (Füße) auf Screen
    local topWorld    = head.Position + Vector3.new(0, 0.7, 0)
    local bottomWorld = hrp.Position  - Vector3.new(0, 3.2, 0)

    local topScrn,    topVis    = Camera:WorldToViewportPoint(topWorld)
    local bottomScrn, bottomVis = Camera:WorldToViewportPoint(bottomWorld)

    if not topVis or topScrn.Z < 0 then hideESPBox(esp) return end

    -- Höhe in Pixeln
    local screenH = math.abs(topScrn.Y - bottomScrn.Y)
    if screenH < 5 then hideESPBox(esp) return end

    -- Breite proportional zu Distanz (ungefähr 0.5× der Höhe für menschliche Figur)
    local screenW = screenH * 0.52

    -- Bounding-Box Kanten
    local x = topScrn.X - screenW / 2
    local y = math.min(topScrn.Y, bottomScrn.Y)
    local x2 = x + screenW
    local y2 = y + screenH

    -- Ecken-Länge
    local cX = screenW * CFG.cornerLen
    local cY = screenH * CFG.cornerLen
    local col = hpColor(hp, maxHp)

    -- Setze Linien-Farbe
    for _, l in ipairs(esp.lines) do l.Color = col end

    -- L-Ecken zeichnen:
    -- TL horizontal, TL vertikal
    -- TR horizontal, TR vertikal
    -- BL horizontal, BL vertikal
    -- BR horizontal, BR vertikal
    local pts = {
        -- TL
        { Vector2.new(x,    y),    Vector2.new(x+cX,  y)    }, -- TL h
        { Vector2.new(x,    y),    Vector2.new(x,     y+cY)  }, -- TL v
        -- TR
        { Vector2.new(x2,   y),    Vector2.new(x2-cX, y)    }, -- TR h
        { Vector2.new(x2,   y),    Vector2.new(x2,    y+cY)  }, -- TR v
        -- BL
        { Vector2.new(x,    y2),   Vector2.new(x+cX,  y2)   }, -- BL h
        { Vector2.new(x,    y2),   Vector2.new(x,     y2-cY) }, -- BL v
        -- BR
        { Vector2.new(x2,   y2),   Vector2.new(x2-cX, y2)   }, -- BR h
        { Vector2.new(x2,   y2),   Vector2.new(x2,    y2-cY) }, -- BR v
    }

    for i, pt in ipairs(pts) do
        esp.lines[i].From    = pt[1]
        esp.lines[i].To      = pt[2]
        esp.lines[i].Visible = true
    end

    -- HP Bar (links neben der Box)
    local barX    = x - 5
    local barTopY = y
    local barBotY = y2
    local barH    = barBotY - barTopY
    local hpPct   = math.clamp(hp / math.max(maxHp,1), 0, 1)

    esp.hpBg.From    = Vector2.new(barX, barTopY)
    esp.hpBg.To      = Vector2.new(barX, barBotY)
    esp.hpBg.Visible = true

    esp.hpBar.From    = Vector2.new(barX, barBotY)
    esp.hpBar.To      = Vector2.new(barX, barBotY - barH * hpPct)
    esp.hpBar.Color   = col
    esp.hpBar.Visible = true

    -- Name über der Box
    esp.nameTx.Text      = plr.Name
    esp.nameTx.Color     = col
    esp.nameTx.Position  = Vector2.new(x + screenW/2 - (#plr.Name * 3.5), y - 16)
    esp.nameTx.Visible   = true

    -- Distanz unter der Box
    esp.distTx.Text     = string.format("%.0fm", dist)
    esp.distTx.Position = Vector2.new(x + screenW/2 - 14, y2 + 2)
    esp.distTx.Visible  = true
end

-- ══════════════════════════════════════════════════════
--  NAMETAG — V3 WIDE HUD
--  Linker farbiger Akzent-Streifen, Status-Dot,
--  Name + Threat inline, schlanker HP-Balken + Distanz
-- ══════════════════════════════════════════════════════
local function createMatrixTag(plr)
    local char = plr.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil end

    local old = head:FindFirstChild("MatrixTag")
    if old then old:Destroy() end

    -- BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name           = "MatrixTag"
    bb.Adornee        = head
    bb.Size           = UDim2.new(0, 110, 0, 32)
    bb.StudsOffset    = Vector3.new(0, 2.2, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.Enabled        = CFG.tagEnabled
    bb.Parent         = head

    -- Haupt-Hintergrund
    local bg = Instance.new("Frame", bb)
    bg.Size                  = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3      = Color3.fromRGB(0, 8, 2)
    bg.BackgroundTransparency = 0.15
    bg.BorderSizePixel       = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 3)

    -- Border
    local borderStroke = Instance.new("UIStroke", bg)
    borderStroke.Color        = CFG.greendim
    borderStroke.Thickness    = 1
    borderStroke.Transparency = 0.5

    -- Linker Akzent-Streifen
    local accentBar = Instance.new("Frame", bg)
    accentBar.Name              = "AccentBar"
    accentBar.Size              = UDim2.new(0, 2, 1, 0)
    accentBar.Position          = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3  = CFG.green
    accentBar.BorderSizePixel   = 0
    Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 3)

    -- ── ZEILE 1: Dot + Name + Threat ──
    local row1 = Instance.new("Frame", bg)
    row1.Size                  = UDim2.new(1, -6, 0, 14)
    row1.Position              = UDim2.new(0, 5, 0, 2)
    row1.BackgroundTransparency = 1
    row1.BorderSizePixel       = 0

    local dot = Instance.new("Frame", row1)
    dot.Name             = "Dot"
    dot.Size             = UDim2.new(0, 4, 0, 4)
    dot.Position         = UDim2.new(0, 0, 0.5, -2)
    dot.BackgroundColor3 = CFG.green
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local nameLbl = Instance.new("TextLabel", row1)
    nameLbl.Name               = "NameLbl"
    nameLbl.Size               = UDim2.new(1, -38, 1, 0)
    nameLbl.Position           = UDim2.new(0, 7, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = plr.Name
    nameLbl.Font               = Enum.Font.GothamBlack
    nameLbl.TextSize           = 8
    nameLbl.TextColor3         = CFG.green
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.TextStrokeTransparency = 0.5

    local threatBadge = Instance.new("Frame", row1)
    threatBadge.Name             = "ThreatBadge"
    threatBadge.Size             = UDim2.new(0, 30, 0, 10)
    threatBadge.Position         = UDim2.new(1, -30, 0.5, -5)
    threatBadge.BackgroundColor3 = Color3.fromRGB(0, 20, 6)
    threatBadge.BackgroundTransparency = 0.2
    threatBadge.BorderSizePixel  = 0
    Instance.new("UICorner", threatBadge).CornerRadius = UDim.new(0, 2)
    local threatStroke = Instance.new("UIStroke", threatBadge)
    threatStroke.Color = CFG.greendim; threatStroke.Thickness = 1; threatStroke.Transparency = 0.4

    local threatLbl = Instance.new("TextLabel", threatBadge)
    threatLbl.Name             = "ThreatLbl"
    threatLbl.Size             = UDim2.new(1, 0, 1, 0)
    threatLbl.BackgroundTransparency = 1
    threatLbl.Text             = "LOW"
    threatLbl.Font             = Enum.Font.GothamBlack
    threatLbl.TextSize         = 6
    threatLbl.TextColor3       = CFG.green
    threatLbl.TextXAlignment   = Enum.TextXAlignment.Center

    -- ── ZEILE 2: HP-Balken + Zahl ──
    local row2 = Instance.new("Frame", bg)
    row2.Size                  = UDim2.new(1, -6, 0, 8)
    row2.Position              = UDim2.new(0, 5, 0, 18)
    row2.BackgroundTransparency = 1
    row2.BorderSizePixel       = 0

    local barTrack = Instance.new("Frame", row2)
    barTrack.Size              = UDim2.new(1, -20, 0, 3)
    barTrack.Position          = UDim2.new(0, 0, 0.5, -1)
    barTrack.BackgroundColor3  = Color3.fromRGB(0, 22, 7)
    barTrack.BorderSizePixel   = 0
    Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 1)

    local barFill = Instance.new("Frame", barTrack)
    barFill.Name              = "BarFill"
    barFill.Size              = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3  = CFG.green
    barFill.BorderSizePixel   = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 1)

    local hpPctLbl = Instance.new("TextLabel", row2)
    hpPctLbl.Name             = "HpPct"
    hpPctLbl.Size             = UDim2.new(0, 18, 1, 0)
    hpPctLbl.Position         = UDim2.new(1, -18, 0, 0)
    hpPctLbl.BackgroundTransparency = 1
    hpPctLbl.Text             = "100"
    hpPctLbl.Font             = Enum.Font.GothamBlack
    hpPctLbl.TextSize         = 6
    hpPctLbl.TextColor3       = CFG.green
    hpPctLbl.TextXAlignment   = Enum.TextXAlignment.Right

    -- Distanz (sehr klein, unter dem Tag)
    local distLbl = Instance.new("TextLabel", bb)
    distLbl.Name             = "DistLbl"
    distLbl.Size             = UDim2.new(1, 0, 0, 8)
    distLbl.Position         = UDim2.new(0, 0, 1, 1)
    distLbl.BackgroundTransparency = 1
    distLbl.Text             = "0m"
    distLbl.Font             = Enum.Font.Gotham
    distLbl.TextSize         = 6
    distLbl.TextColor3       = Color3.fromRGB(0, 90, 35)
    distLbl.TextXAlignment   = Enum.TextXAlignment.Center

    local velLbl = Instance.new("TextLabel", bg)
    velLbl.Name             = "VelLbl"
    velLbl.Size             = UDim2.new(0, 0, 0, 0)
    velLbl.Visible          = false  -- versteckt, nur noch Distanz sichtbar
    velLbl.BackgroundTransparency = 1
    velLbl.Text             = ""

    return {
        bb         = bb,
        accentBar  = accentBar,
        dot        = dot,
        barFill    = barFill,
        hpPctLbl   = hpPctLbl,
        threatLbl  = threatLbl,
        threatStroke = threatStroke,
        borderStroke = borderStroke,
        distLbl    = distLbl,
        velLbl     = velLbl,
    }
end

local function updateMatrixTag(plr, tag)
    if not tag or not tag.bb or not tag.bb.Parent then return end

    local hp, maxHp = getHP(plr)
    local dist      = getDistance(plr)
    local pct       = math.clamp(hp / math.max(maxHp, 1), 0, 1)
    local col       = hpColor(hp, maxHp)
    local thr       = threatText(hp, maxHp)

    -- Akzent-Streifen + Dot Farbe
    tag.accentBar.BackgroundColor3 = col
    tag.dot.BackgroundColor3       = col

    -- HP Bar
    tag.barFill.Size             = UDim2.new(pct, 0, 1, 0)
    tag.barFill.BackgroundColor3 = col

    -- HP Prozent
    tag.hpPctLbl.Text       = tostring(math.floor(hp))
    tag.hpPctLbl.TextColor3 = col

    -- Threat Badge
    tag.threatLbl.Text       = thr
    tag.threatLbl.TextColor3 = col
    tag.threatStroke.Color   = col

    -- Border
    tag.borderStroke.Color = col

    -- Distanz + Velocity
    tag.distLbl.Text = string.format("%.0fm", dist)

    -- Velocity aus HRP (falls verfügbar)
    local char = plr.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local vel = hrp.Velocity
            local speed = math.floor(Vector3.new(vel.X, 0, vel.Z).Magnitude)
            tag.velLbl.Text = "VEL " .. speed
        end
    end

    tag.bb.Enabled = CFG.tagEnabled and dist <= CFG.espMaxDist
end

-- ══════════════════════════════════════════════════════
--  PLAYER TRACKING
-- ══════════════════════════════════════════════════════
local tracked = {}

local function trackPlayer(plr)
    if plr == LocalPlayer then return end
    if tracked[plr] then return end

    local data = {}
    tracked[plr] = data

    local function onChar(char)
        task.wait(0.6)

        -- Tag
        if data.tag and data.tag.bb then pcall(function() data.tag.bb:Destroy() end) end
        data.tag = createMatrixTag(plr)

        -- ESP Box (Drawing API)
        if data.esp then removeESPBox(data.esp) end
        data.esp = createESPBox()

        -- Heartbeat disconnect
        if data.conn then data.conn:Disconnect() end
        data.conn = RunService.Heartbeat:Connect(_trackFn(function()
            if not plr or not plr.Parent then return end
            updateMatrixTag(plr, data.tag)
            updateESPBox(data.esp, plr)
        end))
    end

    if plr.Character then onChar(plr.Character) end
    data.charConn = plr.CharacterAdded:Connect(onChar)
end

local function untrackPlayer(plr)
    local data = tracked[plr]
    if not data then return end
    if data.conn     then data.conn:Disconnect()              end
    if data.charConn then data.charConn:Disconnect()          end
    if data.tag and data.tag.bb then pcall(function() data.tag.bb:Destroy() end) end
    removeESPBox(data.esp)
    tracked[plr] = nil
end

-- ══════════════════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════════════════
local Gui = Instance.new("ScreenGui")
_espGui = Gui  -- store in outer scope immediately
Gui.Name = "MatrixTrackerGUI"; Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 9999
pcall(function() Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)

local mainFrame = Instance.new("Frame", Gui)
mainFrame.Size = UDim2.new(0,220,0,390)
mainFrame.Position = UDim2.new(1,-230,0,10)
mainFrame.BackgroundColor3 = Color3.fromRGB(0,8,2)
mainFrame.BackgroundTransparency = 0.08
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0,8)
local ms = Instance.new("UIStroke", mainFrame)
ms.Color = CFG.greendim; ms.Thickness = 1; ms.Transparency = 0.3

-- Title
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1,0,0,28); titleBar.BackgroundColor3 = Color3.fromRGB(0,18,5)
titleBar.BackgroundTransparency = 0.2; titleBar.BorderSizePixel = 0; titleBar.Active = true
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,8)
local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(1,0,1,0); titleLbl.BackgroundTransparency = 1
titleLbl.Text = "TLAimbot"; titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 13; titleLbl.TextColor3 = CFG.green
titleLbl.TextXAlignment = Enum.TextXAlignment.Center

-- Mobile/Tablet scaling
do
    local vp    = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
    local touch = pcall(function() return UserInputService.TouchEnabled end) and UserInputService.TouchEnabled
    local kbd   = pcall(function() return UserInputService.KeyboardEnabled end) and UserInputService.KeyboardEnabled
    local short = math.min(vp.X, vp.Y)
    local isMobile = touch and not kbd and short < 500
    local isTablet = touch and not kbd and short >= 500 and short < 900
    if isMobile or isTablet then
        local scl = isMobile
            and math.clamp((short * 0.9) / 220, 0.6, 1.1)
            or  math.clamp((short * 0.6) / 220, 0.8, 1.1)
        local uisc = Instance.new("UIScale", mainFrame)
        uisc.Scale = scl
        mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        mainFrame.Position    = UDim2.new(0.5, 0, 0.5, 0)
    end
end

-- Drag: titleBar only, Mouse + Touch
do
    local _dragActive = false
    local _dragStart, _frameStart = nil, nil
    titleBar.InputBegan:Connect(_trackFn(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            _dragActive = true
            _dragStart  = inp.Position
            _frameStart = mainFrame.Position
        end
    end))
    UserInputService.InputChanged:Connect(_trackFn(function(inp)
        if _dragActive and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - _dragStart
            mainFrame.Position = UDim2.new(
                _frameStart.X.Scale, _frameStart.X.Offset + delta.X,
                _frameStart.Y.Scale, _frameStart.Y.Offset + delta.Y)
        end
    end))
    UserInputService.InputEnded:Connect(_trackFn(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            _dragActive = false
        end
    end))
end

-- Status
local statusLbl = Instance.new("TextLabel", mainFrame)
statusLbl.Size = UDim2.new(0.9,0,0,22); statusLbl.Position = UDim2.new(0.05,0,0,32)
statusLbl.BackgroundColor3 = Color3.fromRGB(0,15,3); statusLbl.BackgroundTransparency = 0.3
statusLbl.BorderSizePixel = 0; statusLbl.Text = "STATUS: AKTIV"
statusLbl.Font = Enum.Font.GothamBold; statusLbl.TextSize = 11
statusLbl.TextColor3 = CFG.green; statusLbl.TextXAlignment = Enum.TextXAlignment.Center
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0,4)

-- Helper: Button
local function mkBtn(parent, x, y, w, h, txt)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0,w,0,h); b.Position = UDim2.new(0,x,0,y)
    b.BackgroundColor3 = Color3.fromRGB(0,28,10); b.BackgroundTransparency = 0.2
    b.BorderSizePixel = 0; b.Text = txt
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextColor3 = CFG.green
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,4)
    local bs = Instance.new("UIStroke", b)
    bs.Color = CFG.greendim; bs.Thickness = 1; bs.Transparency = 0.4
    b.MouseEnter:Connect(_trackFn(function() b.BackgroundTransparency = 0 end))
    b.MouseLeave:Connect(_trackFn(function() b.BackgroundTransparency = 0.2 end))
    return b
end

-- ══════════════════════════════════════════════════════
--  AIMLOCK — SYSTEM
-- ══════════════════════════════════════════════════════
local AIM = {
    enabled     = false,
    target      = nil,       -- aktuell gelockter Player
    bone        = "Head",    -- Ziel-Body-Part: "Head" oder "HumanoidRootPart"
    smoothing   = 0.18,      -- 0.0 = sofort, 1.0 = sehr langsam
    fov         = 120,        -- Radius in Pixeln für FOV-Kreis
    maxDist     = 500,        -- Max Studs
    prediction  = true,       -- Velocity-Prediction aktiviert
    predStrength = 0.08,      -- Stärke der Prediction
    holdKey     = Enum.UserInputType.MouseButton2, -- RMB = Aim
    active      = false,      -- Wird gerade gezielt?
}

-- ── Crosshair / Target-Line (Drawing) ─────────────────
local aimLine = Drawing.new("Line")
aimLine.Visible     = false
aimLine.Color       = C.accent
aimLine.Thickness   = 1
aimLine.Transparency = 0.5

-- ── Target-Dot auf dem Ziel ───────────────────────────
local targetDot = Drawing.new("Circle")
targetDot.Visible     = false
targetDot.Radius      = 4
targetDot.Color       = Color3.fromRGB(255, 34, 68)
targetDot.Thickness   = 1.5
targetDot.Transparency = 0
targetDot.Filled      = true

-- ── Hilfsfunktionen Aimlock ───────────────────────────
local function getScreenCenter()
    local vp = Camera.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function getAimPos(plr)
    local char = plr.Character
    if not char then return nil end
    local part = char:FindFirstChild(AIM.bone)
    if not part then return nil end

    local pos = part.Position

    -- Velocity Prediction: kompensiert Bewegung des Ziels
    if AIM.prediction then
        local hrp = getHRP(char)
        if hrp then
            local vel = hrp.Velocity
            pos = pos + vel * AIM.predStrength
        end
    end

    return pos
end

local function worldToScreen(worldPos)
    local screenPos, visible = Camera:WorldToViewportPoint(worldPos)
    if not visible or screenPos.Z < 0 then return nil end
    return Vector2.new(screenPos.X, screenPos.Y)
end

local function distToCenter(screenPos)
    return (screenPos - getScreenCenter()).Magnitude
end

-- Findet den besten Spieler im FOV (nächstes zum Crosshair)
local function findBestTarget()
    local best     = nil
    local bestDist = AIM.fov  -- nur Spieler im FOV-Radius

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hp, maxHp = getHP(plr)
            if hp > 0 then
                local aimPos = getAimPos(plr)
                if aimPos then
                    local dist3D = getDistance(plr)
                    if dist3D <= AIM.maxDist then
                        local screenPos = worldToScreen(aimPos)
                        if screenPos then
                            local d = distToCenter(screenPos)
                            if d < bestDist then
                                bestDist = d
                                best     = plr
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

-- ── Aimlock Haupt-Loop ────────────────────────────────
local mouse = LocalPlayer:GetMouse()

_RSConnect(_trackFn(function()
    local center = getScreenCenter()

    -- FOV-Kreis immer in der Mitte
    fovCircle.Position = center
    fovCircle.Visible  = AIM.enabled

    -- Nicht aktiv → aufräumen
    if not AIM.active or not AIM.enabled then
        aimLine.Visible    = false
        targetDot.Visible  = false
        AIM.target         = nil
        return
    end

    -- Bestes Ziel suchen (oder aktuelles behalten wenn noch im FOV)
    if AIM.target then
        local hp, _ = getHP(AIM.target)
        local aimPos = getAimPos(AIM.target)
        if hp <= 0 or not aimPos then
            AIM.target = nil
        else
            local sp = worldToScreen(aimPos)
            if not sp or distToCenter(sp) > AIM.fov * 2.5 then
                AIM.target = nil
            end
        end
    end

    if not AIM.target then
        AIM.target = findBestTarget()
    end

    if not AIM.target then
        aimLine.Visible   = false
        targetDot.Visible = false
        return
    end

    -- Ziel-Position berechnen
    local aimWorldPos = getAimPos(AIM.target)
    if not aimWorldPos then return end

    local aimScreenPos = worldToScreen(aimWorldPos)
    if not aimScreenPos then return end

    -- Smoothing: Kamera sanft zum Ziel drehen
    local currentCF = Camera.CFrame
    local targetCF  = CFrame.lookAt(currentCF.Position, aimWorldPos)

    -- Interpolation zwischen aktueller und Ziel-Rotation
    local smooth = math.clamp(AIM.smoothing, 0.01, 0.99)
    Camera.CFrame = currentCF:Lerp(targetCF, 1 - smooth)

    -- Aim-Line: Mitte → Ziel
    local hp, maxHp = getHP(AIM.target)
    local lineCol   = hpColor(hp, maxHp)

    aimLine.From      = center
    aimLine.To        = aimScreenPos
    aimLine.Color     = lineCol
    aimLine.Visible   = true

    -- Target-Dot auf dem Ziel
    targetDot.Position = aimScreenPos
    targetDot.Visible  = true
end))

-- ══════════════════════════════════════════════════════
--  AIMLOCK — MAXIMIZED
-- ══════════════════════════════════════════════════════
local AIM = {
    -- Core
    enabled      = false,
    active       = false,
    target       = nil,

    -- Targeting
    bone         = "Head",        -- "Head" / "HumanoidRootPart" / "UpperTorso"
    fov          = 120,           -- FOV-Radius in Pixeln
    maxDist      = 500,           -- Max Studs
    teamCheck    = false,         -- Team ignorieren

    -- Smoothing (delta-time basiert — konsistent bei jeder FPS)
    smoothSpeed  = 14,            -- höher = schneller (1–30)
    minSmooth    = 0.04,          -- Mindest-Interpolation pro Frame

    -- Prediction
    prediction   = true,
    predFrames   = 3,             -- wie viele Frames voraus (1–8)

    -- Gravity Compensation (für Projectile-Spiele)
    gravComp     = false,
    gravity      = 196.2,         -- Roblox Standard-Gravity
    bulletSpeed  = 200,           -- Studs/s

    -- Silent Aim (Kamera bewegt sich NICHT, nur MouseDelta)
    silentAim    = false,

    -- Snap Resistance (verhindert hartes Ruckeln beim Wechsel)
    snapThresh   = 180,           -- Max Pixel-Sprung pro Frame

    -- Keybind
    holdKey      = Enum.UserInputType.MouseButton2,

    -- Intern
    lastTargetPos = nil,
    switchCooldown = 0,
    switchDelay    = 0.35,        -- Sekunden bevor Zielwechsel erlaubt
    hitCount       = 0,           -- wie oft dieses Ziel getroffen
    sessionKills   = 0,
}

-- ── Drawing Objekte ───────────────────────────────────
-- FOV Kreis
local fovCircle = Drawing.new("Circle")
fovCircle.Visible      = false
fovCircle.Radius       = AIM.fov
fovCircle.Color        = Color3.fromRGB(200, 200, 200)
fovCircle.Thickness    = 1
fovCircle.Transparency = 1
fovCircle.Filled       = false

-- FOV Kreis Füllung (sehr transparent)

-- Aim Linie (Crosshair → Ziel)
local aimLine = Drawing.new("Line")
aimLine.Visible      = false
aimLine.Color        = C.accent
aimLine.Thickness    = 1
aimLine.Transparency = 0.55

-- Target Box Highlight (4 Linien um das Ziel-Bone)
local tBoxLines = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Visible = false; l.Color = Color3.fromRGB(255, 34, 68)
    l.Thickness = 1.5; l.Transparency = 0.1
    tBoxLines[i] = l
end

-- Target Dot (Punkt auf Ziel)
local targetDot = Drawing.new("Circle")
targetDot.Visible      = false
targetDot.Radius       = 3
targetDot.Color        = Color3.fromRGB(255, 34, 68)
targetDot.Thickness    = 1
targetDot.Transparency = 0
targetDot.Filled       = true

-- Target Ring (Ring um den Dot)
local targetRing = Drawing.new("Circle")
targetRing.Visible      = false
targetRing.Radius       = 7
targetRing.Color        = Color3.fromRGB(255, 34, 68)
targetRing.Thickness    = 1
targetRing.Transparency = 0.4
targetRing.Filled       = false

-- HUD Text (oben rechts: Target-Info)
local aimHUD = Drawing.new("Text")
aimHUD.Visible        = false
aimHUD.Size           = 13
aimHUD.Font           = Drawing.Fonts.Monospace
aimHUD.Color          = C.accent
aimHUD.Outline        = true
aimHUD.OutlineColor   = Color3.new(0,0,0)
aimHUD.Transparency   = 1

-- ── Hilfsfunktionen ───────────────────────────────────
local function getScreenCenter()
    local vp = Camera.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function worldToScreen(pos)
    local sp, vis = Camera:WorldToViewportPoint(pos)
    if not vis or sp.Z < 0 then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function distToCenter(sp)
    return (sp - getScreenCenter()).Magnitude
end

-- Gravity Compensation: berechnet wie viel nach oben zielen
local function gravityOffset(worldPos)
    if not AIM.gravComp then return Vector3.new(0,0,0) end
    local myChar = LocalPlayer.Character
    if not myChar then return Vector3.new(0,0,0) end
    local myHRP = getHRP(myChar)
    if not myHRP then return Vector3.new(0,0,0) end
    local dist  = (worldPos - myHRP.Position).Magnitude
    local tFlight = dist / AIM.bulletSpeed
    local drop  = 0.5 * AIM.gravity * tFlight * tFlight
    return Vector3.new(0, drop, 0)
end

-- Beste Zielposition inkl. Prediction + Gravity
local function getAimWorldPos(plr)
    local char = plr.Character
    if not char then return nil end
    local bone = char:FindFirstChild(AIM.bone)
        or char:FindFirstChild("Head")
        or getHRP(char)
    if not bone then return nil end

    local pos = bone.Position

    -- Velocity Prediction (delta-basiert)
    if AIM.prediction then
        local hrp = getHRP(char)
        if hrp then
            local vel = hrp.Velocity
            -- predFrames / 60 ≈ Sekunden voraus
            pos = pos + vel * (AIM.predFrames / 60)
        end
    end

    -- Gravity Compensation
    pos = pos + gravityOffset(pos)

    return pos
end

-- Bestes Ziel im FOV finden (nach Screen-Distanz zum Crosshair)
local function findBestTarget()
    local best     = nil
    local bestDist = AIM.fov

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not (AIM.teamCheck and plr.Team == LocalPlayer.Team) then
            local hp, _ = getHP(plr)
            if hp > 0 then
                local dist3D = getDistance(plr)
                if dist3D <= AIM.maxDist then
                    local worldPos = getAimWorldPos(plr)
                    if worldPos then
                        local sp = worldToScreen(worldPos)
                        if sp then
                            local d = distToCenter(sp)
                            if d < bestDist then
                                bestDist = d
                                best     = plr
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

-- Target Box um Bone zeichnen (kleines Quadrat)
local function drawTargetBox(sp)
    if not sp then
        for _, l in ipairs(tBoxLines) do l.Visible = false end
        return
    end
    local S = 10  -- halbe Seitenlänge
    local tl = Vector2.new(sp.X - S, sp.Y - S)
    local tr = Vector2.new(sp.X + S, sp.Y - S)
    local bl = Vector2.new(sp.X - S, sp.Y + S)
    local br = Vector2.new(sp.X + S, sp.Y + S)
    local pts = { {tl,tr},{tr,br},{br,bl},{bl,tl} }
    for i, p in ipairs(pts) do
        tBoxLines[i].From    = p[1]
        tBoxLines[i].To      = p[2]
        tBoxLines[i].Visible = true
    end
end

-- ── Haupt-Loop ────────────────────────────────────────
local lastDT = 0

_RSConnect(_trackFn(function(dt)
    lastDT = dt
    local center = getScreenCenter()
    local vp     = Camera.ViewportSize

    -- FOV Kreis
    fovCircle.Position = center
    fovCircle.Visible  = AIM.enabled

    -- Switch Cooldown
    if AIM.switchCooldown > 0 then
        AIM.switchCooldown = math.max(0, AIM.switchCooldown - dt)
    end

    -- HUD Position (oben rechts)
    aimHUD.Position = Vector2.new(vp.X - 160, 10)

    if not AIM.active or not AIM.enabled then
        aimLine.Visible    = false
        targetDot.Visible  = false
        targetRing.Visible = false
        aimHUD.Visible     = false
        for _, l in ipairs(tBoxLines) do l.Visible = false end
        if not AIM.enabled then AIM.target = nil end
        return
    end

    -- Ziel validieren
    if AIM.target then
        local hp, _ = getHP(AIM.target)
        local wp    = getAimWorldPos(AIM.target)
        if hp <= 0 or not wp then
            if hp <= 0 then AIM.sessionKills += 1 end
            AIM.target = nil
        elseif AIM.switchCooldown <= 0 then
            local sp = worldToScreen(wp)
            -- Ziel wechseln wenn weit aus FOV heraus
            if not sp or distToCenter(sp) > AIM.fov * 2.8 then
                AIM.target = nil
            end
        end
    end

    -- Neues Ziel suchen
    if not AIM.target and AIM.switchCooldown <= 0 then
        AIM.target = findBestTarget()
        if AIM.target then
            AIM.switchCooldown = AIM.switchDelay
            AIM.hitCount       = 0
        end
    end

    if not AIM.target then
        aimLine.Visible    = false
        targetDot.Visible  = false
        targetRing.Visible = false
        aimHUD.Visible     = false
        for _, l in ipairs(tBoxLines) do l.Visible = false end
        return
    end

    -- Zielposition
    local aimWorldPos = getAimWorldPos(AIM.target)
    if not aimWorldPos then return end

    local aimSP = worldToScreen(aimWorldPos)
    if not aimSP then return end

    -- Snap Resistance: Max-Pixel-Sprung begrenzen
    if AIM.lastTargetPos then
        local jump = (aimSP - AIM.lastTargetPos).Magnitude
        if jump > AIM.snapThresh then
            local dir = (aimSP - AIM.lastTargetPos).Unit
            aimSP = AIM.lastTargetPos + dir * AIM.snapThresh
        end
    end
    AIM.lastTargetPos = aimSP

    -- ── KAMERA-BEWEGUNG ────────────────────────────────
    if not AIM.silentAim then
        local currentCF = Camera.CFrame
        local targetCF  = CFrame.lookAt(currentCF.Position, aimWorldPos)

        -- Delta-Time basiertes Smoothing: FPS-unabhängig
        local alpha = math.clamp(AIM.smoothSpeed * dt, AIM.minSmooth, 1)
        Camera.CFrame = currentCF:Lerp(targetCF, alpha)
    end

    -- ── DRAWING ────────────────────────────────────────
    local hp, maxHp = getHP(AIM.target)
    local col       = hpColor(hp, maxHp)
    local dist3D    = getDistance(AIM.target)

    -- Aim Line
    aimLine.From      = center
    aimLine.To        = aimSP
    aimLine.Color     = col
    aimLine.Visible   = true

    -- Target Dot + Ring
    targetDot.Position  = aimSP
    targetDot.Color     = col
    targetDot.Visible   = true
    targetRing.Position = aimSP
    targetRing.Color    = col
    targetRing.Visible  = true

    -- Target Box
    drawTargetBox(aimSP)
    for _, l in ipairs(tBoxLines) do l.Color = col end

    -- HUD Info
    local threat = threatText(hp, maxHp)
    aimHUD.Text    = string.format(
        "[AIM] %s\nHP: %d/%d\nDIST: %.0fm\nTHREAT: %s\nKILLS: %d",
        AIM.target.Name,
        math.floor(hp), math.floor(maxHp),
        dist3D,
        threat,
        AIM.sessionKills
    )
    aimHUD.Color   = col
    aimHUD.Visible = true
end))

-- ── Keybind ───────────────────────────────────────────
UserInputService.InputBegan:Connect(_trackFn(function(inp, gp)
    if gp then return end
    if inp.UserInputType == AIM.holdKey then
        AIM.active         = true
        AIM.target         = nil
        AIM.lastTargetPos  = nil
        AIM.switchCooldown = 0
    end
end))
UserInputService.InputEnded:Connect(_trackFn(function(inp)
    if inp.UserInputType == AIM.holdKey then
        AIM.active        = false
        AIM.target        = nil
        AIM.lastTargetPos = nil
        aimLine.Visible    = false
        targetDot.Visible  = false
        targetRing.Visible = false
        aimHUD.Visible     = false
        for _, l in ipairs(tBoxLines) do l.Visible = false end
    end
end))

-- ══════════════════════════════════════════════════════
--  GUI LOGIK
-- ══════════════════════════════════════════════════════

-- ── Sektion: Aimlock ──────────────────────────────────
local function sectionDivider(parent, y, txt)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0.9,0,0,12); lbl.Position = UDim2.new(0.05,0,0,y)
    lbl.BackgroundTransparency = 1; lbl.Text = txt
    lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 8
    lbl.TextColor3 = C.borderdim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local line = Instance.new("Frame", parent)
    line.Size = UDim2.new(0.9,0,0,1); line.Position = UDim2.new(0.05,0,0,y+12)
    line.BackgroundColor3 = Color3.fromRGB(0,50,15); line.BorderSizePixel=0
end

local function mkSliderRow(parent, y, labelTxt, initVal, minV, maxV, fmt, onChange)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0.9,0,0,13); lbl.Position = UDim2.new(0.05,0,0,y)
    lbl.BackgroundTransparency=1; lbl.Text=string.format(labelTxt..": "..fmt, initVal)
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=9
    lbl.TextColor3=CFG.greendim; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local track = Instance.new("Frame", parent)
    track.Size=UDim2.new(0.9,0,0,14); track.Position=UDim2.new(0.05,0,0,y+14)
    track.BackgroundColor3=Color3.fromRGB(0,28,10); track.BorderSizePixel=0
    track.Active=true
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)

    local pct0 = math.clamp((initVal-minV)/(maxV-minV),0,1)
    local fill = Instance.new("Frame", track)
    fill.Size=UDim2.new(pct0,1,0,5); fill.Position=UDim2.new(0,0,0.5,-2.5)
    fill.BackgroundColor3=CFG.green; fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

    local knob = Instance.new("Frame", track)
    knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(pct0,-7,0.5,-7)
    knob.BackgroundColor3=CFG.green; knob.BorderSizePixel=0; knob.ZIndex=3
    Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
    local knobStroke = Instance.new("UIStroke",knob)
    knobStroke.Color=Color3.fromRGB(180,255,200); knobStroke.Thickness=1; knobStroke.Transparency=0.4

    local dragging = false

    local function applyX(mx)
        local p = math.clamp((mx - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(p,1,0,5)
        knob.Position = UDim2.new(p,-7,0.5,-7)
        local val = minV + (maxV-minV)*p
        lbl.Text = string.format(labelTxt..": "..fmt, val)
        onChange(val)
    end

    track.InputBegan:Connect(_trackFn(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            applyX(inp.Position.X)
        end
    end))
    UserInputService.InputChanged:Connect(_trackFn(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            applyX(inp.Position.X)
        end
    end))
    UserInputService.InputEnded:Connect(_trackFn(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end))
    return lbl
end

local function mkToggleBtn(parent, x, y, w, h, labelOn, labelOff, initState, onChange)
    local b = mkBtn(parent, x, y, w, h, initState and labelOn or labelOff)
    b.TextColor3 = initState and CFG.green or Color3.fromRGB(80,80,80)
    local state = initState
    b.MouseButton1Click:Connect(_trackFn(function()
        state = not state
        b.Text = state and labelOn or labelOff
        b.TextColor3 = state and CFG.green or Color3.fromRGB(80,80,80)
        onChange(state)
    end))
    return b
end

-- ── AIMLOCK BUTTON ────────────────────────────────────
sectionDivider(mainFrame, 93, "// AIMLOCK")

local aimBtn = mkToggleBtn(mainFrame, 10, 110, 200, 26,
    "AIMLOCK: ON", "AIMLOCK: OFF", false, function(on)
    AIM.enabled = on
    fovCircle.Visible = on
    if not on then
        AIM.target = nil
        aimLine.Visible=false; targetDot.Visible=false
        targetRing.Visible=false; aimHUD.Visible=false
        for _,l in ipairs(tBoxLines) do l.Visible=false end
    end
end)

-- PRED
local predBtn = mkToggleBtn(mainFrame, 10, 170, 200, 22,
    "PRED: ON", "PRED: OFF", true, function(on)
    AIM.prediction = on
end)
predBtn.TextSize = 9

-- Sliders
mkSliderRow(mainFrame, 198, "SMOOTH", AIM.smoothSpeed, 1, 30, "%.1f", function(v)
    AIM.smoothSpeed = v
end)

mkSliderRow(mainFrame, 222, "FOV", AIM.fov, 20, 300, "%.0fpx", function(v)
    AIM.fov = math.floor(v)
    fovCircle.Radius = AIM.fov
end)

mkSliderRow(mainFrame, 246, "PRED FRAMES", AIM.predFrames, 1, 8, "%.0f", function(v)
    AIM.predFrames = math.floor(v)
end)

-- ── STANDARD CONTROLS ─────────────────────────────────
sectionDivider(mainFrame, 273, "// TRACKER")

local espBtn = mkToggleBtn(mainFrame, 10, 290, 93, 26,
    "ESP: ON", "ESP: OFF", true, function(on)
    CFG.espEnabled = on
    if not on then for _,d in pairs(tracked) do hideESPBox(d.esp) end end
end)

local tagBtn = mkToggleBtn(mainFrame, 117, 290, 93, 26,
    "TAG: ON", "TAG: OFF", true, function(on)
    CFG.tagEnabled = on
    for _,d in pairs(tracked) do
        if d.tag and d.tag.bb then d.tag.bb.Enabled = on end
    end
end)

-- Range Slider
local rangeLbl = Instance.new("TextLabel", mainFrame)
rangeLbl.Size=UDim2.new(0.9,0,0,13); rangeLbl.Position=UDim2.new(0.05,0,0,322)
rangeLbl.BackgroundTransparency=1; rangeLbl.Text="REICHWEITE: 500"
rangeLbl.Font=Enum.Font.Gotham; rangeLbl.TextSize=9
rangeLbl.TextColor3=CFG.greendim; rangeLbl.TextXAlignment=Enum.TextXAlignment.Left

local sliderTrack = Instance.new("Frame", mainFrame)
sliderTrack.Size=UDim2.new(0.9,0,0,5); sliderTrack.Position=UDim2.new(0.05,0,0,337)
sliderTrack.BackgroundColor3=Color3.fromRGB(0,28,10); sliderTrack.BorderSizePixel=0
Instance.new("UICorner",sliderTrack).CornerRadius=UDim.new(1,0)

local sliderFill = Instance.new("Frame", sliderTrack)
sliderFill.Size=UDim2.new(1,1,0,5); sliderFill.Position=UDim2.new(0,0,0.5,-2.5)
sliderFill.BackgroundColor3=CFG.green; sliderFill.BorderSizePixel=0
Instance.new("UICorner",sliderFill).CornerRadius=UDim.new(1,0)

local sliderKnob = Instance.new("Frame", sliderTrack)
sliderKnob.Size=UDim2.new(0,14,0,14); sliderKnob.Position=UDim2.new(1,-7,0.5,-7)
sliderKnob.BackgroundColor3=CFG.green; sliderKnob.BorderSizePixel=0; sliderKnob.ZIndex=3
Instance.new("UICorner",sliderKnob).CornerRadius=UDim.new(1,0)
local _rKS=Instance.new("UIStroke",sliderKnob); _rKS.Color=Color3.fromRGB(180,255,200); _rKS.Thickness=1; _rKS.Transparency=0.4

local function updateRange(pct)
    pct=math.clamp(pct,0,1)
    CFG.espMaxDist=math.floor(50+450*pct)
    AIM.maxDist=CFG.espMaxDist
    rangeLbl.Text="REICHWEITE: "..CFG.espMaxDist
    sliderFill.Size=UDim2.new(pct,1,0,5)
    sliderKnob.Position=UDim2.new(pct,-7,0.5,-7)
end

local rangeDown=false
sliderTrack.Active=true
sliderTrack.InputBegan:Connect(_trackFn(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        rangeDown=true
        local p=math.clamp((inp.Position.X-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X,0,1)
        updateRange(p)
    end
end))
UserInputService.InputChanged:Connect(_trackFn(function(inp)
    if rangeDown and (inp.UserInputType==Enum.UserInputType.MouseMovement
    or inp.UserInputType==Enum.UserInputType.Touch) then
        local p=math.clamp((inp.Position.X-sliderTrack.AbsolutePosition.X)/sliderTrack.AbsoluteSize.X,0,1)
        updateRange(p)
    end
end))

-- Counted Info
local countLbl = Instance.new("TextLabel", mainFrame)
countLbl.Size=UDim2.new(0.9,0,0,18); countLbl.Position=UDim2.new(0.05,0,0,348)
countLbl.BackgroundColor3=Color3.fromRGB(0,15,3); countLbl.BackgroundTransparency=0.3
countLbl.BorderSizePixel=0; countLbl.Text="TRACKED: 0  |  KILLS: 0"
countLbl.Font=Enum.Font.GothamBold; countLbl.TextSize=9; countLbl.TextColor3=CFG.greendim
countLbl.TextXAlignment=Enum.TextXAlignment.Center
Instance.new("UICorner",countLbl).CornerRadius=UDim.new(0,4)

local infoLbl = Instance.new("TextLabel", mainFrame)
infoLbl.Size=UDim2.new(0.9,0,0,12); infoLbl.Position=UDim2.new(0.05,0,0,370)
infoLbl.BackgroundTransparency=1; infoLbl.Text="RMB = Aim  |  X = GUI"
infoLbl.Font=Enum.Font.Gotham; infoLbl.TextSize=8
infoLbl.TextColor3=Color3.fromRGB(0,70,20); infoLbl.TextXAlignment=Enum.TextXAlignment.Center

-- ── Haupt-Render-Update ───────────────────────────────
UserInputService.InputEnded:Connect(_trackFn(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then rangeDown=false end
end))
local _trackedLblAcc = 0
_RSConnect(_trackFn(function(dt)
    _trackedLblAcc = _trackedLblAcc + dt
    if _trackedLblAcc < 0.5 then return end
    _trackedLblAcc = 0
    local n=0 for _ in pairs(tracked) do n+=1 end
    countLbl.Text="TRACKED: "..n.."  |  KILLS: "..AIM.sessionKills
end))

UserInputService.InputBegan:Connect(_trackFn(function(inp,gp)
    if gp then return end
end))

-- ══════════════════════════════════════════════════════
--  INIT
-- ══════════════════════════════════════════════════════
for _, plr in ipairs(Players:GetPlayers()) do trackPlayer(plr) end
Players.PlayerAdded:Connect(_trackFn(trackPlayer))
Players.PlayerRemoving:Connect(_trackFn(untrackPlayer))

LocalPlayer.CharacterAdded:Connect(_trackFn(function()
    task.wait(1)
    for plr, data in pairs(tracked) do
        if data.tag and data.tag.bb then pcall(function() data.tag.bb:Destroy() end) end
        removeESPBox(data.esp)
        data.tag = createMatrixTag(plr)
        data.esp = createESPBox()
    end
end))

updateRange(1)

print("✅ MATRIX TRACKER + AIMLOCK MAX geladen")
print("RMB = Aim halten | X = GUI | Silent/Pred/Grav togglebar")
    -- expose stop/start
    local _capturedGui = Gui  -- capture before nil risk
    _espStop = function()
        -- Disconnect all connections
        for _, c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
        _conns = {}
        -- Hide + Destroy GUI
        if _capturedGui then
            _capturedGui.Enabled = false
            if _capturedGui.Parent then _capturedGui:Destroy() end
            _capturedGui = nil
        end
        -- Remove all Drawing objects
        pcall(function() aimLine:Remove() end)
        pcall(function() targetDot:Remove() end)
        pcall(function() targetRing:Remove() end)
        pcall(function() fovCircle:Remove() end)
        pcall(function() aimHUD:Remove() end)
        for _, l in ipairs(tBoxLines) do pcall(function() l:Remove() end) end
        for plr, data in pairs(tracked) do
            pcall(function()
                if data.conn then data.conn:Disconnect() end
                if data.charConn then data.charConn:Disconnect() end
                if data.tag and data.tag.bb then data.tag.bb:Destroy() end
                removeESPBox(data.esp)
            end)
        end
        _espStop = nil
    end
end  -- end _launchESPTracker

combatAddRow("ESP + Aimlock", "Combat", C.red, false, function(on)
    if on then
        _launchESPTracker()
        sendNotif("Combat", "ESP + Aimlock aktiv  |  RMB = Aim", 3)
    else
        -- Hide panel immediately via outer reference
        if _espGui then
            _espGui.Enabled = false
            _espGui:Destroy()
            _espGui = nil
        end
        -- Run full cleanup
        if _espStop then _espStop() end
        sendNotif("Combat", "ESP + Aimlock deaktiviert", 2)
    end
end)

end  -- outer do

combatPage.Size = UDim2.new(1, 0, 0, 46)

-- ─────────────────────────────────────────────────────────────────────────
-- ── Bladeball-Ordner (enthält AutoParry + weitere Bladeball-Scripts) ──────
local bbContainer, bbContent, bbAddRow = makeMiscFolder("Bladeball", "⚔", C.orange, 1)
-- ─────────────────────────────────────────────────────────────────────────
local apRow, apSetFn
do
-- ── AutoParry BB Multi-Agent 2026 ─────────────────────────────────────────
--[[
  5 Spezialisierte KI-Agenten arbeiten parallel:
  AGENT 1 · PREDICTOR  — Berechnet wann der Ball ankommt
  AGENT 2 · PHYSICIST  — Analysiert Physik/Kurven/Spin
  AGENT 3 · ABILITY_AI — Erkennt & kontern alle 60 Abilities
  AGENT 4 · TIMING_AI  — Adaptiver Ping/Latenz-Ausgleich
  AGENT 5 · GUARDIAN   — Fallback & Sicherheitsnetz
]]
(function()
local CFG = {
    -- Zonen
    ULTRA_RANGE   = 10,
    RUSH_RANGE    = 18,
    MACRO_RANGE   = 22,
    SPAM_RANGE    = 40,
    MIN_FIRE_DIST = 8,

    -- Speeds
    MIN_SPEED       = 5,
    CONFIRM_SPEED   = 18,
    MACRO_MIN_SPEED = 40,
    HIGH_SPEED      = 120,   -- "extrem schnell"

    -- Parry-Cooldowns
    BASE_CD  = 0.10,
    MIN_CD   = 0.06,
    MAX_CD   = 0.16,
    ULTRA_CD = 0.016,        -- 1 Frame

    -- Ping
    PING_TTL = 0.8,

    -- Ability-Schwellen
    FREEZE_THRESH    = 2.0,
    FREEZE_MAX_WAIT  = 3.5,
    FREEZE_REFIRE    = 0.035,
    CURVE_HS_THRESH  = 75,
    CURVE_TRAJ_LOOSE = 0.28,
    TRAJ_NORMAL      = 0.75,
    TELEPORT_JUMP    = 25,
    PULL_RANGE       = 55,
    DRIBBLE_CD       = 0.4,
}

-- ══════════════════════════════════════════════════════════════════
--  SHARED STATE  (von allen Agenten gelesen/geschrieben)
-- ══════════════════════════════════════════════════════════════════
local State = {
    -- Parry-Timestamps
    lastParry        = 0,
    lastGlobalParry  = 0,
    parryCount       = 0,

    -- Ball-Tracking (pro Ball gesetzt)
    speed            = 0,
    distance         = math.huge,
    velocity         = Vector3.zero,
    ballPos          = Vector3.zero,
    prevBallPos      = Vector3.zero,
    prevDist         = math.huge,
    closingFrames    = 0,
    lastVelDir       = Vector3.zero,
    isClosing        = false,

    -- Ability-States
    isFrozen         = false,
    frozenSince      = 0,
    wasHighSpeedPre  = false,
    highCurveActive  = false,
    ballTeleported   = false,
    ballTeleportAt   = 0,
    targetChangeCount= 0,
    lastTargetChange = 0,
    dribbleMode      = false,

    -- Agent-Empfehlungen (jeder Agent schreibt seinen Score)
    -- Score: 0 = kein Parry, 1 = normaler Parry, 2 = Instant-Parry, 3 = Ultra-Parry
    agentScore       = {0, 0, 0, 0, 0},
    agentReason      = {"", "", "", "", ""},

    -- Timing
    lastSpamFire     = 0,
    lastNormalFire   = 0,
    lastReversalTime = 0,
    spinStartTime    = 0,
    abilityStartTime = 0,
    firedDir         = nil,
    lastFiredAt      = 0,
    targetAssignTime = 0,
    targetChangedAt  = 0,

    -- Status
    isMyTarget       = false,
    enabled          = false,
}

-- ══════════════════════════════════════════════════════════════════
--  ROOT CACHE
-- ══════════════════════════════════════════════════════════════════
local cachedRoot = nil
local function refreshRoot()
    local char = LocalPlayer.Character
    if not char then return end
    cachedRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end
refreshRoot()
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.15)
    cachedRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end)

-- ══════════════════════════════════════════════════════════════════
--  PING SYSTEM
-- ══════════════════════════════════════════════════════════════════
local _cachedPing    = 55
local _lastPingTime  = 0
local _pingItem      = nil
pcall(function() _pingItem = Stats.Network.ServerStatsItem["Data Ping"] end)

local function getPing()
    local now = tick()
    if now - _lastPingTime < CFG.PING_TTL then return _cachedPing end
    _lastPingTime = now
    if _pingItem then
        local ok, v = pcall(function() return _pingItem:GetValue() end)
        if ok and v then _cachedPing = math.clamp(v, 15, 400) end
    end
    return _cachedPing
end

-- ══════════════════════════════════════════════════════════════════
--  PARRY EXECUTOR  (einzige Stelle die tatsächlich feuert)
-- ══════════════════════════════════════════════════════════════════
local flashCallback = nil

local VirtualInputManager
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local function _keyDown() VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.F, false, game) end
local function _keyUp()   VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game) end

-- Führt Parry aus basierend auf dem höchsten Agenten-Score
-- score 1 = Standard, 2 = Instant, 3 = Ultra (kein Cooldown außer 1 Frame)
local function executeParry(score, reason)
    local now = tick()

    if score >= 3 then
        -- ULTRA: nur 1-Frame-Gate (16ms)
        if now - State.lastGlobalParry < CFG.ULTRA_CD then return false end
        State.lastParry      = now
        State.lastGlobalParry = now
        _keyDown(); _keyUp()
    elseif score >= 2 then
        -- INSTANT: kein Cooldown-Gate, kein task.spawn
        local cd = math.clamp(CFG.BASE_CD * math.clamp(getPing()/100, 0.6, 1.4),
            CFG.MIN_CD, CFG.MAX_CD)
        if now - State.lastParry < cd * 0.5 then return false end
        if now - State.lastGlobalParry < 0.008 then return false end
        State.lastParry      = now
        State.lastGlobalParry = now
        _keyDown(); _keyUp()
    else
        -- NORMAL: voller adaptiver Cooldown
        local cd = math.clamp(CFG.BASE_CD * math.clamp(getPing()/100, 0.6, 1.4),
            CFG.MIN_CD, CFG.MAX_CD)
        if now - State.lastParry       < cd    then return false end
        if now - State.lastGlobalParry < 0.01  then return false end
        State.lastParry      = now
        State.lastGlobalParry = now
        _keyDown()
        task.spawn(function() task.wait(0.038); _keyUp() end)
    end

    State.parryCount = State.parryCount + 1
    if flashCallback then flashCallback(score, reason) end
    return true
end

-- ══════════════════════════════════════════════════════════════════
--  BALL VELOCITY READER
-- ══════════════════════════════════════════════════════════════════
local function getBallVelocity(ball)
    local z = ball:FindFirstChild("zoomies")
    if z then
        if z:IsA("BasePart") then return z.AssemblyLinearVelocity or Vector3.zero end
        if z:IsA("Vector3Value") then return z.Value or Vector3.zero end
        local ok, v = pcall(function() return z.VectorVelocity end)
        if ok and typeof(v) == "Vector3" then return v end
    end
    local ok2, v2 = pcall(function() return ball.AssemblyLinearVelocity end)
    if ok2 and v2 then return v2 end
    return Vector3.zero
end

local function isRealBall(ball)
    if not ball:IsA("BasePart") then return false end
    return ball:GetAttribute("realBall") == true
end

local ME = tostring(LocalPlayer.UserId)
local function iAmTarget(ball)
    local t = ball:GetAttribute("target")
    if t ~= nil then return tostring(t) == ME end
    local char = LocalPlayer.Character
    if char then return char:FindFirstChildWhichIsA("Highlight") ~= nil end
    return false
end

-- ══════════════════════════════════════════════════════════════════
--  ████████████████████████████████████████████████████████████
--  AGENT 1 · PREDICTOR
--  Berechnet präzise wann der Ball den Spieler erreicht.
--  Nutzt lineare Extrapolation + Ping-Kompensation.
--  Output: Score 0-3 (0=kein Parry, 3=Ultra sofort)
--  ████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════
local PREDICTOR = {}

function PREDICTOR.init()
    PREDICTOR.arrivalTime   = math.huge   -- geschätzte Ankunftszeit in Sekunden
    PREDICTOR.confidence    = 0           -- 0..1 Konfidenz der Vorhersage
    PREDICTOR.preFireWindow = 0           -- Fenster in dem gefeuert werden soll
    PREDICTOR.lastScore     = 0
end

function PREDICTOR.tick(ball, rootPos, ballVel, ballPos, speed, distance)
    if speed < CFG.MIN_SPEED then
        PREDICTOR.lastScore = 0; return 0
    end

    local ping       = getPing() / 1000  -- in Sekunden
    local toPlayer   = rootPos - ballPos
    local distToHit  = toPlayer.Magnitude

    -- Lineare Ankunftszeit: distToHit / speed
    -- + Ping-Kompensation: wir müssen ping/2 früher feuern (RTT/2)
    local eta = (speed > 1) and (distToHit / speed) or math.huge
    PREDICTOR.arrivalTime = eta

    -- Präzise Vorhersage: Brechne velocity-korrigierte Position
    -- Ball-Position in ping/2 Millisekunden = ballPos + velocity * (ping/2)
    local futurePos  = ballPos + ballVel * (ping * 0.5)
    local futureDist = (rootPos - futurePos).Magnitude

    -- Konfidenz: höher bei geringer Distanz und hoher Geschwindigkeit
    local conf = math.clamp(1 - (futureDist / CFG.SPAM_RANGE), 0, 1)
        * math.clamp(speed / 60, 0, 1)
    PREDICTOR.confidence = conf

    -- Score-Berechnung
    local score = 0

    if futureDist <= CFG.ULTRA_RANGE then
        -- Ball ist in ping/2 Zeit im Ultra-Bereich → sofort Ultra
        score = 3
        PREDICTOR.preFireWindow = 0
    elseif futureDist <= CFG.RUSH_RANGE and speed >= CFG.CONFIRM_SPEED then
        -- Rush-Zone in naher Zukunft
        score = eta < (ping + 0.04) and 2 or 1
    elseif futureDist <= CFG.MACRO_RANGE and speed >= CFG.MACRO_MIN_SPEED then
        -- Macro-Zone: normaler Parry
        score = 1
    elseif distance <= CFG.SPAM_RANGE and speed >= CFG.CONFIRM_SPEED then
        -- Spam-Zone: nur wenn Ball tatsächlich auf uns zielt
        local traj = ballVel.Unit:Dot(toPlayer.Unit)
        score = (traj > 0.4 and conf > 0.3) and 1 or 0
    end

    -- Pre-Fire: wenn Ankunftszeit < ping → 1 Frame früher schießen
    if eta < ping * 1.2 and eta > 0 and score == 0 and distance <= CFG.SPAM_RANGE then
        score = 1
    end

    State.agentScore[1]  = score
    State.agentReason[1] = string.format("ETA=%.0fms conf=%.0f%%", eta*1000, conf*100)
    PREDICTOR.lastScore  = score
    return score
end
PREDICTOR.init()

-- ══════════════════════════════════════════════════════════════════
--  ████████████████████████████████████████████████████████████
--  AGENT 2 · PHYSICIST
--  Analysiert Physik: Spin, Kurven, Richtungsänderungen,
--  Geschwindigkeits-Vektoren und Closing-Rate.
--  Output: Score 0-3
--  ████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════
local PHYSICIST = {}

function PHYSICIST.init()
    PHYSICIST.closingRate    = 0    -- studs/frame nähert sich der Ball
    PHYSICIST.spinDetected   = false
    PHYSICIST.curveDetected  = false
    PHYSICIST.angularVel     = 0    -- Richtungsänderungs-Rate (rad/frame)
    PHYSICIST.lastScore      = 0
    PHYSICIST._prevVelDir    = Vector3.zero
    PHYSICIST._prevDist      = math.huge
    PHYSICIST._spinFrames    = 0
    PHYSICIST._curveFrames   = 0
end

function PHYSICIST.tick(ball, rootPos, ballVel, ballPos, speed, distance)
    if speed < CFG.MIN_SPEED then
        PHYSICIST.lastScore = 0; return 0
    end

    local dir    = ballVel.Unit
    local toPlayer = (rootPos - ballPos)
    local toUnit   = toPlayer.Magnitude > 0.1 and toPlayer.Unit or Vector3.zero

    -- Closing Rate: wie schnell nähert sich der Ball (positiv = nähert sich)
    local closingRate = PHYSICIST._prevDist - distance
    PHYSICIST.closingRate  = closingRate
    PHYSICIST._prevDist    = distance

    -- Richtungsänderung (angular velocity approximation)
    local angVel = 0
    if PHYSICIST._prevVelDir ~= Vector3.zero and speed > 1 then
        local dot = math.clamp(dir:Dot(PHYSICIST._prevVelDir), -1, 1)
        angVel = math.acos(dot)  -- in Radians
    end
    PHYSICIST.angularVel   = angVel
    PHYSICIST._prevVelDir  = dir

    -- Spin-Erkennung: hohe Winkelgeschwindigkeit + nahe Distanz
    if angVel > 0.15 and distance < CFG.MACRO_RANGE then
        PHYSICIST._spinFrames = PHYSICIST._spinFrames + 1
        PHYSICIST.spinDetected = PHYSICIST._spinFrames >= 2
    else
        PHYSICIST._spinFrames  = math.max(0, PHYSICIST._spinFrames - 1)
        PHYSICIST.spinDetected = false
    end

    -- Kurven-Erkennung: Ball ändert Richtung aber fährt immer noch auf uns zu
    local traj = dir:Dot(toUnit)
    if angVel > 0.08 and traj > 0.2 and speed >= CFG.CONFIRM_SPEED then
        PHYSICIST._curveFrames = PHYSICIST._curveFrames + 1
        PHYSICIST.curveDetected = PHYSICIST._curveFrames >= 1
    else
        PHYSICIST._curveFrames  = math.max(0, PHYSICIST._curveFrames - 1)
        PHYSICIST.curveDetected = false
    end

    -- Score-Entscheidung
    local score = 0

    -- Direkte Closing-Analyse
    local isClosingNow = closingRate > 0 or (ballVel:Dot(toPlayer) > 0)

    if distance <= CFG.ULTRA_RANGE and speed >= CFG.MIN_SPEED then
        score = 3  -- Ultra immer
    elseif distance <= CFG.RUSH_RANGE and speed >= CFG.CONFIRM_SPEED then
        score = (isClosingNow or speed >= CFG.HIGH_SPEED) and 2 or 0
    elseif PHYSICIST.curveDetected and distance <= CFG.SPAM_RANGE then
        -- Kurve auf uns → parieren auch ohne direkte Linie
        score = (traj > (State.highCurveActive and 0.2 or 0.5)) and 1 or 0
    elseif isClosingNow and distance <= CFG.SPAM_RANGE and speed >= CFG.CONFIRM_SPEED then
        score = 1
    end

    -- Spin blockiert Parry (Spin bedeutet Ball dreht sich weg)
    if PHYSICIST.spinDetected and score > 0 and angVel > 0.3 then
        score = math.max(0, score - 1)  -- Score reduzieren aber nicht komplett sperren
    end

    State.agentScore[2]  = score
    State.agentReason[2] = string.format("rate=%.1f ang=%.2f traj=%.2f", closingRate, angVel, traj)
    PHYSICIST.lastScore  = score
    return score
end
PHYSICIST.init()

-- ══════════════════════════════════════════════════════════════════
--  ████████████████████████████████████████████████████████████
--  AGENT 3 · ABILITY_AI
--  Erkennt & kontert alle 60 Abilities in Blade Ball.
--  Hat Wissen über jede Ability-Kategorie und reagiert spezifisch.
--  Output: Score 0-3
--  ████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════
local ABILITY_AI = {}

--[[
ABILITY-KATEGORIEN (alle 60 Abilities):

KATEGORIE A — FREEZE/SLOW (Ball stoppt kurz):
  Freeze, Freeze Trap, Telekinesis, Time Stop (falls vorhanden)
  → Erkennbar: speed < FREEZE_THRESH plötzlich
  → Konter: Gate öffnen, sofort nach Unfreeze parieren

KATEGORIE B — REDIRECT/CURVE (Ball ändert Richtung):
  Rapture, Raging Deflect, Curve, Spin, Whirlwind, Tornado,
  Boomerang, Ricochet, Zigzag, Echo
  → Erkennbar: hoher angular velocity + Ball noch auf uns zu
  → Konter: lockere Trajectory-Schwelle, früher feuern

KATEGORIE C — TELEPORT/PORTAL (Ball springt):
  Time Hole, Portal, Void, Warp, Blink Ball
  → Erkennbar: Positionssprung > TELEPORT_JUMP studs
  → Konter: Reset Gates, kurze Pause, dann sofort parieren

KATEGORIE D — TARGET-CHANGE (Ball wechselt zu uns):
  Pull, Dribble, Magnet, Leech, Chain, Gravity, Attract,
  Hook, Lasso, Tether, Force
  → Erkennbar: target-Attribut ändert sich zu uns
  → Konter: sofortiger Parry ohne Speed-Check

KATEGORIE E — SPEED-BOOST (Ball wird sehr schnell):
  Raging Deflect (nach Parry), Boost, Overdrive, Surge,
  Accelerate, Turbo, Rush, Blitz, Lightning
  → Erkennbar: speed > HIGH_SPEED plötzlich
  → Konter: ULTRA-Zone erweitern temporär

KATEGORIE F — SELF-TELEPORT (Spieler bewegt sich):
  Phase Bypass, Blink, Swap, Waypoint, Shadow Step,
  Dash (kurze Distanz)
  → Erkennbar: Root-Position springt (root-cache refresh)
  → Konter: Root-Cache auto-refresh (bereits in CharacterAdded)

KATEGORIE G — DEFENSIVE (Gegner-Ability, keine direkte Wirkung auf uns):
  Shield, Block, Reflect, Counter, Mirror
  → Kein spezifisches Kontern nötig — Ball kommt zurück schneller
  → Erkennbar: Ball kehrt mit höherer Speed zurück (Reversal)
]]

function ABILITY_AI.init()
    ABILITY_AI.currentCategory  = "NONE"
    ABILITY_AI.abilityActive     = false
    ABILITY_AI.abilityStartTime  = 0
    ABILITY_AI.lastScore         = 0

    -- Freeze/Slow
    ABILITY_AI.isFrozen          = false
    ABILITY_AI.frozenSince       = 0
    ABILITY_AI.wasHighSpeed      = false
    ABILITY_AI.unfreezeParryPending = false

    -- Speed-Boost Tracking
    ABILITY_AI.speedBoostActive  = false
    ABILITY_AI.speedBoostStart   = 0
    ABILITY_AI.ultraExpanded     = false   -- temporär ULTRA_RANGE erweitert

    -- Teleport
    ABILITY_AI.teleportPending   = false
    ABILITY_AI.teleportAt        = 0
    ABILITY_AI._prevBallPos      = nil

    -- Target-Change
    ABILITY_AI.targetChanges     = 0
    ABILITY_AI.lastTargetChange  = 0

    -- Reversal-Erkennung (Kategorie G Konter)
    ABILITY_AI._prevVelDir       = Vector3.zero
    ABILITY_AI.reversalDetected  = false
    ABILITY_AI.lastReversalTime  = 0
end

-- Wird bei jedem target-Attribut-Wechsel aufgerufen
function ABILITY_AI.onTargetChanged(ball, isNowTarget)
    if not isNowTarget then return end
    local now = tick()
    local dt  = now - ABILITY_AI.lastTargetChange
    ABILITY_AI.lastTargetChange = now

    -- Schnelle Wechsel = Dribble/Pull/Chain
    if dt < CFG.DRIBBLE_CD then
        ABILITY_AI.targetChanges = ABILITY_AI.targetChanges + 1
        State.dribbleMode = ABILITY_AI.targetChanges >= 2
        ABILITY_AI.currentCategory = "DRIBBLE"
    else
        ABILITY_AI.targetChanges = 1
        State.dribbleMode = false
        ABILITY_AI.currentCategory = "PULL"
    end
end

function ABILITY_AI.tick(ball, rootPos, ballVel, ballPos, speed, distance)
    local now     = tick()
    local score   = 0
    local reason  = ABILITY_AI.currentCategory

    -- ── KATEGORIE A: Freeze/Slow ──────────────────────────────────────────
    if speed < CFG.FREEZE_THRESH then
        if not ABILITY_AI.isFrozen then
            ABILITY_AI.isFrozen    = true
            ABILITY_AI.frozenSince = now
            ABILITY_AI.wasHighSpeed = (State.speed > CFG.CONFIRM_SPEED)
            ABILITY_AI.currentCategory = "FREEZE"
            -- Gate öffnen
            State.firedDir = nil
        end
        -- Timeout-Schutz
        if now - ABILITY_AI.frozenSince > CFG.FREEZE_MAX_WAIT then
            ABILITY_AI.isFrozen = false
        end
        -- Während Freeze: kein Parry
        State.isFrozen = true
        State.agentScore[3]  = 0
        State.agentReason[3] = "FROZEN"
        ABILITY_AI.lastScore = 0
        return 0
    else
        State.isFrozen = false
        if ABILITY_AI.isFrozen then
            -- Unfreeze erkannt → sofortiger Parry
            ABILITY_AI.isFrozen = false
            ABILITY_AI.currentCategory = "UNFREEZE"
            if ABILITY_AI.wasHighSpeed and State.isMyTarget then
                task.delay(CFG.FREEZE_REFIRE, function()
                    if not State.enabled or not State.isMyTarget then return end
                    local root = cachedRoot; if not root then return end
                    local d = (root.Position - ball.Position).Magnitude
                    if d <= CFG.SPAM_RANGE then
                        executeParry(d <= CFG.ULTRA_RANGE and 3 or 2, "UNFREEZE")
                        State.lastSpamFire = tick()
                        State.firedDir     = nil
                    end
                end)
                score = 0  -- Task übernimmt, kein doppelter Score
                reason = "UNFREEZE_QUEUED"
            end
        end
    end

    -- ── KATEGORIE C: Teleport ─────────────────────────────────────────────
    if ABILITY_AI._prevBallPos then
        local jump = (ballPos - ABILITY_AI._prevBallPos).Magnitude
        if jump > CFG.TELEPORT_JUMP then
            ABILITY_AI.teleportPending  = true
            ABILITY_AI.teleportAt       = now
            ABILITY_AI.currentCategory  = "TELEPORT"
            State.firedDir   = nil
            State.prevDist   = math.huge
            State.closingFrames = 0
            State.isFrozen   = false
        end
    end
    ABILITY_AI._prevBallPos = ballPos

    if ABILITY_AI.teleportPending then
        if now - ABILITY_AI.teleportAt < 0.08 then
            -- Kurze Pause nach Teleport
            State.agentScore[3]  = 0
            State.agentReason[3] = "POST_TELEPORT"
            ABILITY_AI.lastScore = 0
            return 0
        else
            ABILITY_AI.teleportPending = false
            -- Sofort parieren nach Teleport-Pause
            if distance <= CFG.SPAM_RANGE and speed >= CFG.CONFIRM_SPEED then
                score  = distance <= CFG.ULTRA_RANGE and 3 or 2
                reason = "POST_TELEPORT_FIRE"
            end
        end
    end

    -- ── KATEGORIE B: Redirect/Curve ───────────────────────────────────────
    -- Hohe Angular-Velocity von PHYSICIST genutzt
    if PHYSICIST.curveDetected and State.isMyTarget then
        ABILITY_AI.currentCategory = "CURVE"
        State.highCurveActive = true
        local traj = ballVel.Unit:Dot((rootPos - ballPos).Unit)
        if traj > CFG.CURVE_TRAJ_LOOSE and distance <= CFG.SPAM_RANGE then
            score = math.max(score, distance <= CFG.RUSH_RANGE and 2 or 1)
            reason = "CURVE_COUNTER"
        end
    elseif speed < CFG.CONFIRM_SPEED then
        State.highCurveActive = false
    end

    -- ── KATEGORIE E: Speed-Boost ──────────────────────────────────────────
    -- Ball wird plötzlich sehr schnell (Raging Deflect, Boost, etc.)
    if speed > CFG.HIGH_SPEED and not ABILITY_AI.speedBoostActive then
        ABILITY_AI.speedBoostActive = true
        ABILITY_AI.speedBoostStart  = now
        ABILITY_AI.currentCategory  = "SPEED_BOOST"
        ABILITY_AI.ultraExpanded    = true
    elseif speed < CFG.MACRO_MIN_SPEED then
        ABILITY_AI.speedBoostActive = false
        ABILITY_AI.ultraExpanded    = false
    end

    if ABILITY_AI.ultraExpanded and distance <= CFG.RUSH_RANGE then
        -- Erweiterte Ultra-Zone bei Speed-Boost
        score  = math.max(score, 3)
        reason = "SPEED_BOOST_ULTRA"
    end

    -- ── KATEGORIE G: Reversal (Gegner pariert, Ball kommt zurück) ────────
    if speed >= CFG.CONFIRM_SPEED and ABILITY_AI._prevVelDir ~= Vector3.zero then
        local dir = ballVel.Unit
        local dot = dir:Dot(ABILITY_AI._prevVelDir)
        if dot < -0.7 then
            -- Ball hat die Richtung fast komplett umgekehrt = Reversal
            ABILITY_AI.reversalDetected = true
            ABILITY_AI.lastReversalTime = now
            ABILITY_AI.currentCategory  = "REVERSAL"
            State.firedDir    = nil
            State.prevDist    = math.huge
            State.closingFrames = 0
            -- Nach Reversal: Score erhöhen (Ball kommt jetzt schnell auf uns)
            if distance <= CFG.SPAM_RANGE and State.isMyTarget then
                score  = math.max(score, distance <= CFG.RUSH_RANGE and 2 or 1)
                reason = "REVERSAL_COUNTER"
            end
        elseif now - ABILITY_AI.lastReversalTime > 0.5 then
            ABILITY_AI.reversalDetected = false
        end
    end
    if speed > 0 then ABILITY_AI._prevVelDir = ballVel.Unit end

    -- ── KATEGORIE D: Dribble/Pull (aus onTargetChanged) ──────────────────
    if State.dribbleMode and State.isMyTarget then
        ABILITY_AI.currentCategory = "DRIBBLE"
        -- Dribble: immer parieren wenn Ball in Range, ohne Speed-Check
        if distance <= CFG.PULL_RANGE then
            score  = math.max(score, distance <= CFG.ULTRA_RANGE and 3
                or distance <= CFG.RUSH_RANGE and 2 or 1)
            reason = "DRIBBLE_COUNTER"
        end
    end

    State.agentScore[3]  = score
    State.agentReason[3] = reason
    ABILITY_AI.lastScore = score
    return score
end
ABILITY_AI.init()

-- ══════════════════════════════════════════════════════════════════
--  ████████████████████████████████████████████████████████████
--  AGENT 4 · TIMING_AI
--  Adaptiver Ping/Latenz-Ausgleich.
--  Misst tatsächliche Parry-Latenz, lernt optimales Timing,
--  korrigiert Pre-Fire-Zeitpunkt basierend auf Verlauf.
--  Output: Score 0-3
--  ████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════
local TIMING_AI = {}

function TIMING_AI.init()
    TIMING_AI.samples        = {}     -- letzte N Parry-Erfolge/Misses
    TIMING_AI.sampleCount    = 0
    TIMING_AI.learnedOffset  = 0      -- gelernter Zeitversatz in Sekunden
    TIMING_AI.pingVariance   = 0      -- Ping-Varianz (Jitter)
    TIMING_AI.optimalPreFire = 0.04   -- wie früh wir feuern sollen (dynamisch)
    TIMING_AI.lastScore      = 0

    TIMING_AI._pingHistory   = {}
    TIMING_AI._pingHistLen   = 10
    TIMING_AI._jitter        = 0
end

function TIMING_AI.samplePing()
    local p = getPing()
    table.insert(TIMING_AI._pingHistory, p)
    if #TIMING_AI._pingHistory > TIMING_AI._pingHistLen then
        table.remove(TIMING_AI._pingHistory, 1)
    end
    -- Jitter berechnen (Standardabweichung der Ping-Samples)
    if #TIMING_AI._pingHistory >= 3 then
        local sum = 0
        for _, v in ipairs(TIMING_AI._pingHistory) do sum = sum + v end
        local mean = sum / #TIMING_AI._pingHistory
        local variance = 0
        for _, v in ipairs(TIMING_AI._pingHistory) do
            variance = variance + (v - mean)^2
        end
        TIMING_AI._jitter = math.sqrt(variance / #TIMING_AI._pingHistory)
    end
end

function TIMING_AI.tick(ball, rootPos, ballVel, ballPos, speed, distance)
    TIMING_AI.samplePing()

    if speed < CFG.MIN_SPEED then
        TIMING_AI.lastScore = 0; return 0
    end

    local ping   = getPing() / 1000   -- in Sekunden
    local jitter = TIMING_AI._jitter / 1000
    local score  = 0

    -- Optimale Pre-Fire Zeit = ping/2 + jitter (worst case latency)
    TIMING_AI.optimalPreFire = (ping * 0.5) + jitter + TIMING_AI.learnedOffset

    -- Effektive Distanz nach Pre-Fire-Window
    local futurePos  = ballPos + ballVel * TIMING_AI.optimalPreFire
    local futureDist = (rootPos - futurePos).Magnitude

    -- Timing-Score: wie gut der Pre-Fire passt
    local eta = (speed > 0) and (distance / speed) or math.huge

    if futureDist <= CFG.ULTRA_RANGE then
        score = 3
    elseif futureDist <= CFG.RUSH_RANGE and speed >= CFG.CONFIRM_SPEED then
        -- Pre-Fire window: wenn eta < 2x optimal_prefire → jetzt feuern
        score = (eta < TIMING_AI.optimalPreFire * 2.5) and 2 or 1
    elseif futureDist <= CFG.SPAM_RANGE and speed >= CFG.CONFIRM_SPEED then
        -- Timing-Check: feuern wenn eta knapp unter dem Threshold
        local traj = ballVel.Unit:Dot((rootPos - ballPos).Unit)
        if eta < TIMING_AI.optimalPreFire * 4 and traj > 0.35 then
            score = 1
        end
    end

    -- High-Jitter Kompensation: bei instabilem Ping früher feuern
    if jitter > 20 and score > 0 then
        -- Jitter > 20ms: eine Zone früher reagieren
        if distance <= CFG.MACRO_RANGE and score < 2 then score = 2 end
    end

    State.agentScore[4]  = score
    State.agentReason[4] = string.format("preFire=%.0fms jitter=%.0fms ETA=%.0fms",
        TIMING_AI.optimalPreFire*1000, jitter, eta*1000)
    TIMING_AI.lastScore  = score
    return score
end
TIMING_AI.init()

-- ══════════════════════════════════════════════════════════════════
--  ████████████████████████████████████████████████████████████
--  AGENT 5 · GUARDIAN
--  Sicherheitsnetz: fängt alles auf was die anderen Agenten
--  verpassen. Reagiert auf anomale Zustände, letzter Ausweg.
--  Hat auch die "Veto"-Macht um falsche Parries zu verhindern.
--  Output: Score -1 (Veto/Block), 0 (neutral), 1-3 (Fallback)
--  ████████████████████████████████████████████████████████████
-- ══════════════════════════════════════════════════════════════════
local GUARDIAN = {}

function GUARDIAN.init()
    GUARDIAN.vetoing          = false
    GUARDIAN.vetoUntil        = 0
    GUARDIAN.lastScore        = 0
    GUARDIAN.anomalyCount     = 0
    GUARDIAN.lastAnomalyTime  = 0
    GUARDIAN._prevSpeed       = 0
    GUARDIAN._speedHistory    = {}
    GUARDIAN._avgSpeed        = 0
    GUARDIAN.consecutiveFires = 0
    GUARDIAN.lastFireTime     = 0
    GUARDIAN.overFireProtect  = false
end

function GUARDIAN.tick(ball, rootPos, ballVel, ballPos, speed, distance)
    local now   = tick()
    local score = 0

    -- ── Speed-Anomalie-Erkennung ──────────────────────────────────────────
    table.insert(GUARDIAN._speedHistory, speed)
    if #GUARDIAN._speedHistory > 8 then
        table.remove(GUARDIAN._speedHistory, 1)
    end
    local speedSum = 0
    for _, v in ipairs(GUARDIAN._speedHistory) do speedSum = speedSum + v end
    GUARDIAN._avgSpeed = speedSum / math.max(#GUARDIAN._speedHistory, 1)

    -- Plötzlicher extremer Speed-Anstieg = Ability-Anomalie
    local speedRatio = speed / math.max(GUARDIAN._avgSpeed, 1)

    -- ── Over-Fire-Schutz (zu viele Parries in kurzer Zeit) ────────────────
    if now - GUARDIAN.lastFireTime < 0.05 then
        GUARDIAN.consecutiveFires = GUARDIAN.consecutiveFires + 1
    else
        GUARDIAN.consecutiveFires = math.max(0, GUARDIAN.consecutiveFires - 1)
    end

    if GUARDIAN.consecutiveFires > 8 then
        GUARDIAN.overFireProtect = true
        GUARDIAN.vetoing  = true
        GUARDIAN.vetoUntil = now + 0.15
    elseif now > GUARDIAN.vetoUntil then
        GUARDIAN.vetoing = false
        GUARDIAN.overFireProtect = false
    end

    -- ── Veto-Check ────────────────────────────────────────────────────────
    if GUARDIAN.vetoing then
        State.agentScore[5]  = -1
        State.agentReason[5] = "VETO_OVERFIRE"
        GUARDIAN.lastScore   = -1
        return -1
    end

    -- ── Fallback: Ball extrem nah und andere Agenten haben 0 ──────────────
    local maxOtherScore = math.max(
        State.agentScore[1],
        State.agentScore[2],
        State.agentScore[3],
        State.agentScore[4]
    )

    if maxOtherScore == 0 and State.isMyTarget then
        -- Alle anderen Agenten sagen 0 — GUARDIAN prüft selbst
        if distance <= CFG.ULTRA_RANGE and speed >= CFG.MIN_SPEED then
            score = 3
            State.agentReason[5] = "GUARDIAN_ULTRA_FALLBACK"
        elseif distance <= CFG.RUSH_RANGE and speed >= CFG.CONFIRM_SPEED then
            -- Ball ist nah und schnell aber alle anderen sagen nein?
            -- Direkte Closing-Check als Fallback
            local isClosing = ballVel:Dot(rootPos - ballPos) > 0
            if isClosing then
                score = 2
                State.agentReason[5] = "GUARDIAN_RUSH_FALLBACK"
            end
        end
    end

    -- ── Anomalie-Score: extremer Speed-Anstieg = Boost-Ability ───────────
    if speedRatio > 2.5 and distance <= CFG.SPAM_RANGE and State.isMyTarget then
        GUARDIAN.anomalyCount    = GUARDIAN.anomalyCount + 1
        GUARDIAN.lastAnomalyTime = now
        score = math.max(score, distance <= CFG.RUSH_RANGE and 3 or 2)
        State.agentReason[5] = string.format("ANOMALY_SPEED x%.1f", speedRatio)
    end

    GUARDIAN._prevSpeed        = speed
    GUARDIAN.lastScore         = score
    State.agentScore[5]        = score
    if score == 0 then State.agentReason[5] = "GUARDIAN_OK" end
    return score
end
GUARDIAN.init()

-- ══════════════════════════════════════════════════════════════════
--  KONSENS-ENGINE  (aggregiert alle 5 Agent-Scores)
-- ══════════════════════════════════════════════════════════════════
--[[
  Entscheidungsregeln:
  1. Wenn Agent 5 VETO (-1) → kein Parry (Schutz vor Over-Fire)
  2. Wenn Agent 3 (ABILITY) Score >= 2 → Ability-Counter hat Priorität
  3. Höchster Score von Agents 1+2+4 (gewichtet)
  4. Agent 5 Fallback nur wenn alle anderen 0
]]
local function getConsensusScore()
    local s = State.agentScore

    -- Regel 1: Veto
    if s[5] == -1 then return 0, "VETO" end

    -- Regel 2: Ability-AI Priorität bei Ability-Events
    if s[3] >= 2 then
        local winReason = State.agentReason[3]
        return s[3], winReason
    end

    -- Regel 3: Höchster Score aus Primary Agents (1, 2, 4)
    local best      = 0
    local bestAgent = 0
    for i = 1, 4 do
        if i ~= 3 and s[i] > best then
            best      = s[i]
            bestAgent = i
        end
    end

    -- Bonus: wenn 2+ Agenten übereinstimmen → Score +0 aber höhere Sicherheit
    local agree = 0
    for i = 1, 4 do
        if i ~= 3 and s[i] >= 1 then agree = agree + 1 end
    end

    -- Bei Übereinstimmung: Score leicht erhöhen
    if agree >= 2 and best == 1 then best = math.min(best + 1, 2) end

    -- Regel 4: Guardian-Fallback
    if best == 0 and s[5] > 0 then
        return s[5], "GUARDIAN_FB"
    end

    local reason = bestAgent > 0 and State.agentReason[bestAgent] or "CONSENSUS"
    return best, reason
end

-- ══════════════════════════════════════════════════════════════════
--  BALL WATCHER  (pro Ball)
-- ══════════════════════════════════════════════════════════════════
local watchedBalls = {}
local topConns     = {}

local function watchBall(ball)
    if not isRealBall(ball) then return end
    if watchedBalls[ball]   then return end

    local cleanupFns = {}

    -- Lokale State-Kopie für diesen Ball
    local isMyTarget     = false
    local lastFiredAt    = 0
    local lastSpamFire   = 0
    local lastNormalFire = 0
    local firedDir       = nil
    local prevBallPos    = nil
    local prevDist       = math.huge
    local closingFrames  = 0
    local lastSpeed      = 0
    local targetAssignTime = 0

    -- Agenten zurücksetzen für neuen Ball
    local function resetAgents()
        PREDICTOR.init()
        PHYSICIST.init()
        ABILITY_AI.init()
        TIMING_AI.init()
        GUARDIAN.init()
        for i = 1, 5 do State.agentScore[i] = 0 end
        firedDir     = nil
        lastFiredAt  = 0
        lastSpamFire = 0
        prevDist     = math.huge
        closingFrames = 0
    end

    local function cleanup()
        isMyTarget = false
        for _, fn in ipairs(cleanupFns) do pcall(fn) end
        table.clear(cleanupFns)
    end

    -- Gate: verhindert doppelte Fires in selber Richtung
    local function gateOpen()
        if firedDir == nil then return true end
        if lastSpeed < CFG.MIN_SPEED then firedDir = nil; return true end
        if lastSpeed >= CFG.HIGH_SPEED then firedDir = nil; return true end
        return false
    end

    local function onTargetChanged()
        if not State.enabled then return end
        local was   = isMyTarget
        isMyTarget  = iAmTarget(ball)
        State.isMyTarget = isMyTarget

        if isMyTarget and not was then
            -- Target-Change Event an ABILITY_AI
            ABILITY_AI.onTargetChanged(ball, true)

            targetAssignTime = tick()
            firedDir     = nil
            lastFiredAt  = 0
            lastNormalFire = 0
            lastSpamFire = 0

            -- Sofort alle Agenten ticken für Instant-Reaktion
            local root = cachedRoot
            if root then
                local bv = getBallVelocity(ball)
                local bp = ball.Position
                local rp = root.Position
                local sp = bv.Magnitude
                local dist = (rp - bp).Magnitude

                State.speed    = sp
                State.distance = dist
                State.velocity = bv
                State.ballPos  = bp

                PREDICTOR.tick(ball, rp, bv, bp, sp, dist)
                PHYSICIST.tick(ball, rp, bv, bp, sp, dist)
                ABILITY_AI.tick(ball, rp, bv, bp, sp, dist)
                TIMING_AI.tick(ball, rp, bv, bp, sp, dist)
                GUARDIAN.tick(ball, rp, bv, bp, sp, dist)

                local score, reason = getConsensusScore()
                if score >= 1 then
                    if executeParry(score, reason) then
                        firedDir     = sp > 0 and bv.Unit or nil
                        lastFiredAt  = tick()
                        lastSpamFire = tick()
                        GUARDIAN.lastFireTime = tick()
                    end
                end
            end
        elseif not isMyTarget then
            State.isMyTarget = false
        end
    end

    local function update()
        if not State.enabled or not isMyTarget then return end
        local root = cachedRoot
        if not root then return end

        local ballVel   = getBallVelocity(ball)
        local ballPos   = ball.Position
        local rootPos   = root.Position
        local speed     = ballVel.Magnitude

        lastSpeed = speed

        -- Positionssprung-Erkennung (für ABILITY_AI)
        if prevBallPos then
            local jump = (ballPos - prevBallPos).Magnitude
            if jump > CFG.TELEPORT_JUMP then
                firedDir    = nil
                lastFiredAt = 0
                prevDist    = math.huge
                closingFrames = 0
            end
        end
        prevBallPos = ballPos

        local distance = (rootPos - ballPos).Magnitude
        if distance < prevDist then closingFrames = closingFrames + 1
        else closingFrames = 0 end
        prevDist = distance

        -- Shared State updaten
        State.speed        = speed
        State.distance     = distance
        State.velocity     = ballVel
        State.ballPos      = ballPos
        State.closingFrames = closingFrames
        State.isMyTarget   = isMyTarget
        State.firedDir     = firedDir

        -- Freeze guard (von ABILITY_AI gesetzt)
        if State.isFrozen then return end

        if speed < CFG.MIN_SPEED then return end

        -- ── Alle 5 Agenten ticken ─────────────────────────────────────────
        PREDICTOR.tick(ball, rootPos, ballVel, ballPos, speed, distance)
        PHYSICIST.tick(ball, rootPos, ballVel, ballPos, speed, distance)
        ABILITY_AI.tick(ball, rootPos, ballVel, ballPos, speed, distance)
        TIMING_AI.tick(ball, rootPos, ballVel, ballPos, speed, distance)
        GUARDIAN.tick(ball, rootPos, ballVel, ballPos, speed, distance)

        -- Gate-Check (verhindert Doppel-Fire in selber Richtung)
        if not gateOpen() then return end

        -- ── Konsens ───────────────────────────────────────────────────────
        local score, reason = getConsensusScore()

        if score < 1 then return end

        -- Zusätzliche Sicherheits-Checks vor dem Fire
        local now = tick()
        local minSpamCD = score >= 3 and CFG.ULTRA_CD
            or score >= 2 and 0.008
            or 0.015
        if now - lastSpamFire < minSpamCD then return end

        -- Parry ausführen
        if executeParry(score, reason) then
            firedDir       = speed > 0 and ballVel.Unit or nil
            lastFiredAt    = now
            lastSpamFire   = now
            lastNormalFire = now
            State.firedDir = firedDir
            GUARDIAN.lastFireTime = now
        end
    end

    -- Connections
    local attrConn = ball:GetAttributeChangedSignal("target"):Connect(onTargetChanged)
    table.insert(cleanupFns, function() attrConn:Disconnect() end)

    local ancestryConn = ball.AncestryChanged:Connect(function()
        if not ball.Parent then cleanup(); watchedBalls[ball] = nil end
    end)
    table.insert(cleanupFns, function() ancestryConn:Disconnect() end)

    -- Heartbeat
    local hbConn = RunService.Heartbeat:Connect(update)
    table.insert(cleanupFns, function() hbConn:Disconnect() end)

    -- Velocity-Signale (3 Quellen für max. Reaktionsgeschwindigkeit)
    local function setupVelListeners()
        local z = ball:FindFirstChild("zoomies")
        if z then
            pcall(function()
                local c = z:GetPropertyChangedSignal("Value"):Connect(function()
                    if isMyTarget then update() end
                end)
                table.insert(cleanupFns, function() c:Disconnect() end)
            end)
            pcall(function()
                local c = z:GetPropertyChangedSignal("VectorVelocity"):Connect(function()
                    if isMyTarget then update() end
                end)
                table.insert(cleanupFns, function() c:Disconnect() end)
            end)
        end
        pcall(function()
            local c = ball:GetPropertyChangedSignal("AssemblyLinearVelocity"):Connect(function()
                if isMyTarget then update() end
            end)
            table.insert(cleanupFns, function() c:Disconnect() end)
        end)
        pcall(function()
            local c = ball:GetPropertyChangedSignal("Position"):Connect(function()
                if isMyTarget then update() end
            end)
            table.insert(cleanupFns, function() c:Disconnect() end)
        end)
    end
    setupVelListeners()

    -- Initial check
    isMyTarget = iAmTarget(ball)
    State.isMyTarget = isMyTarget
    if isMyTarget then
        targetAssignTime = tick()
        ABILITY_AI.onTargetChanged(ball, true)
    end

    watchedBalls[ball] = function() cleanup() end
end

-- ══════════════════════════════════════════════════════════════════
--  START / STOP
-- ══════════════════════════════════════════════════════════════════
local function stopWatchingBall(ball)
    local fn = watchedBalls[ball]
    if fn then fn(); watchedBalls[ball] = nil end
end

local function stopAll()
    State.enabled = false
    for ball in pairs(watchedBalls) do stopWatchingBall(ball) end
    for _, c in ipairs(topConns) do pcall(function() c:Disconnect() end) end
    table.clear(topConns)
end

local function startWatching()
    stopAll()
    State.enabled = true

    local folder = workspace:FindFirstChild("Balls")
    if not folder then
        for _ = 1, 10 do
            task.wait(0.5)
            folder = workspace:FindFirstChild("Balls")
            if folder then break end
        end
        if not folder then warn("[BB MultiAgent] Balls-Folder nicht gefunden."); return end
    end

    for _, obj in ipairs(folder:GetChildren()) do
        task.spawn(watchBall, obj)
    end
    table.insert(topConns, folder.ChildAdded:Connect(function(c)
        if State.enabled then task.spawn(watchBall, c) end
    end))
    table.insert(topConns, folder.ChildRemoved:Connect(stopWatchingBall))
end

apRow, apSetFn = bbAddRow("AutoParry", "Misc", C.orange, false, function(on)
    if on then
        pcall(startWatching)
        sendNotif("AutoParry", "⚔ AutoParry (Multi-Agent) aktiviert", 2)
    else
        pcall(stopAll)
        sendNotif("AutoParry", "AutoParry deaktiviert", 2)
    end
end)
end)()
end

-- ── ANTIVCBAN ─────────────────────────────────────────────────────────────
do
local vcRow = Instance.new("Frame", sonstigePage)
vcRow.Size = UDim2.new(1,0,0,54)
vcRow.BackgroundColor3 = C.bg2 or _C3_BG2; vcRow.BackgroundTransparency = 0
vcRow.BorderSizePixel = 0; corner(vcRow, 12)
vcRow.LayoutOrder = 2
local vcRowS = Instance.new("UIStroke", vcRow)
vcRowS.Thickness = 1; vcRowS.Color = C.bg3 or _C3_BG3; vcRowS.Transparency = 0.3
local vcDot = Instance.new("Frame", vcRow)
vcDot.Size = UDim2.new(0,3,0,34); vcDot.Position = UDim2.new(0,0,0.5,-17)
vcDot.BackgroundColor3 = C.orange or Color3.fromRGB(255,155,45); vcDot.BackgroundTransparency = 0.4
vcDot.BorderSizePixel = 0; corner(vcDot, 99)
local vcLbl = Instance.new("TextLabel", vcRow)
vcLbl.Size = UDim2.new(0,160,0,18); vcLbl.Position = UDim2.new(0,14,0,8)
vcLbl.BackgroundTransparency = 1; vcLbl.Text = "ANTIVCBAN"
vcLbl.Font = Enum.Font.GothamBold; vcLbl.TextSize = 13
vcLbl.TextColor3 = C.text or Color3.new(1,1,1)
vcLbl.TextXAlignment = Enum.TextXAlignment.Left
local vcSub = Instance.new("TextLabel", vcRow)
vcSub.Size = UDim2.new(0,160,0,12); vcSub.Position = UDim2.new(0,14,0,26)
vcSub.BackgroundTransparency = 1; vcSub.Text = "VC Ban Bypass"
vcSub.Font = Enum.Font.Gotham; vcSub.TextSize = 9
vcSub.TextColor3 = C.sub or Color3.fromRGB(0,155,44)
vcSub.TextXAlignment = Enum.TextXAlignment.Left
local vcBadge = Instance.new("Frame", vcRow)
vcBadge.Size = UDim2.new(0,36,0,14); vcBadge.Position = UDim2.new(0,179,0,8)
vcBadge.BackgroundColor3 = C.orange or Color3.fromRGB(255,155,45); vcBadge.BackgroundTransparency = 0.7
vcBadge.BorderSizePixel = 0; corner(vcBadge, 99)
local vcBadgeTxt = Instance.new("TextLabel", vcBadge)
vcBadgeTxt.Size = UDim2.new(1,0,1,0); vcBadgeTxt.BackgroundTransparency = 1
vcBadgeTxt.Text = "Misc"; vcBadgeTxt.Font = Enum.Font.GothamBold
vcBadgeTxt.TextSize = 8; vcBadgeTxt.TextColor3 = C.orange or Color3.fromRGB(255,155,45)
vcBadgeTxt.TextXAlignment = Enum.TextXAlignment.Center
local vcBtnF = Instance.new("Frame", vcRow)
vcBtnF.Size = UDim2.new(0,80,0,26); vcBtnF.Position = UDim2.new(1,-90,0.5,-13)
vcBtnF.BackgroundColor3 = C.bg3 or Color3.fromRGB(7,22,10)
vcBtnF.BackgroundTransparency = 0.2; vcBtnF.BorderSizePixel = 0; corner(vcBtnF, 8)
local vcBtnS2 = Instance.new("UIStroke", vcBtnF)
vcBtnS2.Thickness = 1; vcBtnS2.Color = C.orange or Color3.fromRGB(255,155,45); vcBtnS2.Transparency = 0.55
local vcBtn = Instance.new("TextButton", vcBtnF)
vcBtn.Size = UDim2.new(1,0,1,0); vcBtn.BackgroundTransparency = 1
vcBtn.Text = "RUN"; vcBtn.Font = Enum.Font.GothamBold
vcBtn.TextSize = 11; vcBtn.TextColor3 = Color3.new(1,1,1); vcBtn.ZIndex = 5
vcBtn.Active = true
local function vcRun()
    vcBtn.Text = "..."; vcBtn.TextColor3 = C.sub or Color3.fromRGB(0,155,44)
    twP(vcBtnF, 0.1, {BackgroundTransparency = 0})
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/0riginalWarrior/Stalkie/refs/heads/main/vcbypass.lua"))()
        end)
        if ok then
            vcBtn.Text = "✓ OK"; vcBtn.TextColor3 = C.accent or Color3.fromRGB(0,220,80)
            twP(vcBtnF, 0.15, {BackgroundColor3 = Color3.fromRGB(10,50,20)})
            twP(vcBtnS2, 0.15, {Color = C.accent or Color3.fromRGB(0,220,80), Transparency = 0.2})
            sendNotif("ANTIVCBAN", "VC Ban Bypass aktiv ✓", 3)
        else
            vcBtn.Text = "ERR"; vcBtn.TextColor3 = C.red or Color3.fromRGB(255,80,80)
            sendNotif("ANTIVCBAN", "Fehler: " .. tostring(err):sub(1,60), 4)
        end
        task.wait(2.5)
        if vcBtn.Parent then
            vcBtn.Text = "RUN"; vcBtn.TextColor3 = Color3.new(1,1,1)
            twP(vcBtnF, 0.15, {BackgroundColor3 = C.bg3 or Color3.fromRGB(7,22,10), BackgroundTransparency = 0.2})
            twP(vcBtnS2, 0.15, {Color = C.orange or Color3.fromRGB(255,155,45), Transparency = 0.55})
        end
    end)
end
vcBtn.MouseButton1Click:Connect(vcRun)
vcBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then vcRun() end
end)
vcBtn.MouseEnter:Connect(function()
    twP(vcBtnF, 0.08, {BackgroundTransparency = 0})
    twP(vcBtnS2, 0.08, {Transparency = 0.1})
    twP(vcBtn, 0.08, {TextColor3 = C.orange or Color3.fromRGB(255,155,45)})
end)
vcBtn.MouseLeave:Connect(function()
    if vcBtn.Text ~= "✓ OK" then
        twP(vcBtnF, 0.08, {BackgroundTransparency = 0.2})
        twP(vcBtnS2, 0.08, {Transparency = 0.55})
        twP(vcBtn, 0.08, {TextColor3 = Color3.new(1,1,1)})
    end
end)
end
-- ─────────────────────────────────────────────────────────────────────────
-- ── MM2 Ordner (Murder Mystery 2) ─────────────────────────────────────────
local mm2Container, mm2Content, mm2AddRow = makeMiscFolder("MM2", "🔫", Color3.fromRGB(255, 60, 90), 3)
do
local _mm2Players = game:GetService("Players")
local _mm2RS      = game:GetService("RunService")
local _mm2UIS     = game:GetService("UserInputService")
local _mm2LP      = _mm2Players.LocalPlayer
local _mm2PGui    = _mm2LP:WaitForChild("PlayerGui", 10)
if not _mm2PGui then warn("[TLMenu] PlayerGui not found, mm2 module skipped"); return end
local _mm2WS      = workspace

local _mm2Cfg = {
    ESP      = { Enabled = false,
                 MurdererColor  = Color3.fromRGB(255, 50,  50),
                 SheriffColor   = Color3.fromRGB( 50,100, 255),
                 InnocentColor  = Color3.fromRGB( 50,255, 100),
                 Transparency   = 0.5 },
    AutoFarm = { Enabled = false, CoinRange = 50, DelayBetweenPickups = 0.5 },
    AutoGun  = { AutoPickup = false },
    Movement = { SpeedHack = false, WalkSpeed = 32,
                 Fly = false, FlySpeed = 80, Noclip = false },
}

local _mm2Highlights = {}

-- Role detection
local function _mm2GetRole(player)
    local char = player.Character
    if not char then return "Innocent" end
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        local n = tool.Name:lower()
        if n:find("knife") or n:find("dagger") then return "Murderer" end
        if n:find("gun")   or n:find("pistol")  then return "Sheriff"  end
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local n = tool.Name:lower()
            if n:find("knife") or n:find("dagger") then return "Murderer" end
            if n:find("gun")   or n:find("pistol")  then return "Sheriff"  end
        end
    end
    return "Innocent"
end

-- ESP
local function _mm2UpdateESP()
    if not _mm2Cfg.ESP.Enabled then return end
    for _, player in ipairs(_mm2Players:GetPlayers()) do
        if player ~= _mm2LP and player.Character then
            local role  = _mm2GetRole(player)
            local color = role == "Murderer" and _mm2Cfg.ESP.MurdererColor
                       or role == "Sheriff"  and _mm2Cfg.ESP.SheriffColor
                       or                        _mm2Cfg.ESP.InnocentColor
            if not _mm2Highlights[player] then
                local hl = Instance.new("Highlight")
                hl.Adornee             = player.Character
                hl.FillColor           = color
                hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency    = _mm2Cfg.ESP.Transparency
                hl.OutlineTransparency = 0.3
                hl.Parent              = _mm2PGui
                _mm2Highlights[player] = hl
            else
                _mm2Highlights[player].FillColor = color
                _mm2Highlights[player].Adornee   = player.Character
            end
        end
    end
    for player, hl in pairs(_mm2Highlights) do
        if not player.Parent or not player.Character then
            pcall(function() hl:Destroy() end)
            _mm2Highlights[player] = nil
        end
    end
end

local function _mm2ClearESP()
    for _, hl in pairs(_mm2Highlights) do pcall(function() hl:Destroy() end) end
    table.clear(_mm2Highlights)
end

-- Auto Grab Gun
local function _mm2AutoGrabGun()
    if not _mm2Cfg.AutoGun.AutoPickup then return end
    for _, obj in ipairs(_mm2WS:GetDescendants()) do
        if obj:IsA("Tool") and obj:IsDescendantOf(_mm2WS) then
            local n = obj.Name:lower()
            if n:find("gun") or n:find("pistol") or n:find("revolver") then
                local char = _mm2LP.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - obj.Position).Magnitude < 10 then
                    local orig = hrp.CFrame
                    hrp.CFrame = obj.CFrame * CFrame.new(0, 0, 3)
                    task.wait(0.05)
                    hrp.CFrame = orig
                end
            end
        end
    end
end

-- Auto Farm
local function _mm2AutoFarm()
    if not _mm2Cfg.AutoFarm.Enabled then return end
    local char = _mm2LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(_mm2WS:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("coin") or n:find("money") or n:find("gold") then
                if (hrp.Position - obj.Position).Magnitude < _mm2Cfg.AutoFarm.CoinRange then
                    hrp.CFrame = obj.CFrame * CFrame.new(0, 0, 2)
                    task.wait(_mm2Cfg.AutoFarm.DelayBetweenPickups)
                end
            end
        end
    end
end

-- Movement
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
    _mm2FlyBG.MaxTorque = Vector3.new(40000, 40000, 40000); _mm2FlyBG.P = 20000
    _mm2FlyBV = Instance.new("BodyVelocity", root)
    _mm2FlyBV.MaxForce  = Vector3.new(40000, 40000, 40000)
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
        if _mm2UIS:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0, 1, 0)  end
        if _mm2UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0)  end
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

-- Main loop
task.spawn(function()
    while true do
        pcall(function()
            if _mm2Cfg.ESP.Enabled        then _mm2UpdateESP()    end
            if _mm2Cfg.AutoFarm.Enabled   then _mm2AutoFarm()     end
            if _mm2Cfg.AutoGun.AutoPickup then _mm2AutoGrabGun()  end
        end)
        task.wait(0.5)
    end
end)

-- Respawn re-apply
_mm2LP.CharacterAdded:Connect(function()
    task.wait(1)
    if _mm2Cfg.Movement.SpeedHack then _mm2SetSpeed(true)  end
    if _mm2Cfg.Movement.Fly        then _mm2SetFly(true)    end
    if _mm2Cfg.Movement.Noclip     then _mm2SetNoclip(true) end
end)

-- ── Toggle Rows ───────────────────────────────────────────────────────────
local _mm2Red    = Color3.fromRGB(255, 60,  90)
local _mm2Green  = Color3.fromRGB( 50,255, 100)
local _mm2Blue   = Color3.fromRGB( 80,180, 255)
local _mm2Purple = Color3.fromRGB(175, 80, 255)

mm2AddRow("Role ESP", "Visual", _mm2Red, false, function(on)
    _mm2Cfg.ESP.Enabled = on
    if not on then _mm2ClearESP() end
    sendNotif("MM2", on and "🔴 Role ESP aktiv" or "Role ESP deaktiviert", 2)
end)

mm2AddRow("Auto Farm", "Farm", _mm2Green, false, function(on)
    _mm2Cfg.AutoFarm.Enabled = on
    sendNotif("MM2", on and "💰 Auto Farm aktiv" or "Auto Farm deaktiviert", 2)
end)

mm2AddRow("Auto Grab Gun", "Gun", _mm2Blue, false, function(on)
    _mm2Cfg.AutoGun.AutoPickup = on
    sendNotif("MM2", on and "🔫 Auto Grab Gun aktiv" or "Auto Grab Gun deaktiviert", 2)
end)

mm2AddRow("Speed Hack", "Move", _mm2Purple, false, function(on)
    _mm2Cfg.Movement.SpeedHack = on
    _mm2SetSpeed(on)
    sendNotif("MM2", on and "🏃 Speed Hack aktiv" or "Speed Hack deaktiviert", 2)
end)

mm2AddRow("Fly", "Move", _mm2Purple, false, function(on)
    _mm2Cfg.Movement.Fly = on
    _mm2SetFly(on)
    sendNotif("MM2", on and "✈ Fly aktiv" or "Fly deaktiviert", 2)
end)

mm2AddRow("Noclip", "Move", _mm2Purple, false, function(on)
    _mm2Cfg.Movement.Noclip = on
    _mm2SetNoclip(on)
    sendNotif("MM2", on and "👻 Noclip aktiv" or "Noclip deaktiviert", 2)
end)
end
-- ── Ende MM2 Ordner ────────────────────────────────────────────────────────

-- SHADER
do
local _shA=false
local _shC={}
local _shI={}
local function _shClean()
for _,c in ipairs(_shC) do pcall(function()c:Disconnect()end)end
_shC={}
for _,v in ipairs(_shI) do pcall(function()v:Destroy()end)end
_shI={}
end
local function _shNew(cls,par)local o=Instance.new(cls,par);table.insert(_shI,o);return o end
local function _shApply()
local L=game:GetService("Lighting")
local RS=game:GetService("RunService")
local PL=game:GetService("Players").LocalPlayer
for _,v in pairs(L:GetChildren())do
if v:IsA("PostEffect")or v:IsA("Atmosphere")or v:IsA("Sky")then pcall(function()v:Destroy()end)end
end
L.Brightness=2.1;L.GlobalShadows=true;L.ClockTime=12
L.OutdoorAmbient=Color3.fromRGB(128,124,118);L.Ambient=Color3.fromRGB(55,52,48)
L.EnvironmentDiffuseScale=1.2;L.EnvironmentSpecularScale=0.4
L.ShadowSoftness=0.9;L.GeographicLatitude=47
local Sky=_shNew("Sky",L)
Sky.SkyboxBk="rbxassetid://591058823";Sky.SkyboxDn="rbxassetid://591059876"
Sky.SkyboxFt="rbxassetid://591058104";Sky.SkyboxLf="rbxassetid://591057861"
Sky.SkyboxRt="rbxassetid://591057625";Sky.SkyboxUp="rbxassetid://591059642"
Sky.SunAngularSize=15;Sky.MoonAngularSize=10
local Bloom=_shNew("BloomEffect",L)
Bloom.Intensity=0.18;Bloom.Size=24;Bloom.Threshold=0.92
local CFX=_shNew("ColorCorrectionEffect",L)
CFX.Brightness=0.01;CFX.Contrast=0.08;CFX.Saturation=0.08
CFX.TintColor=Color3.fromRGB(255,251,245)
local SR=_shNew("SunRaysEffect",L)
SR.Intensity=0.12;SR.Spread=0.3
local Atm=_shNew("Atmosphere",L)
Atm.Density=0.04;Atm.Offset=0.04;Atm.Haze=0.0;Atm.Glare=0.0
Atm.Color=Color3.fromRGB(199,220,255);Atm.Decay=Color3.fromRGB(80,90,115)
local Blur=_shNew("BlurEffect",L)
Blur.Size=2.5
local dp=_shNew("Part",workspace)
dp.Anchored=true;dp.CanCollide=false;dp.CastShadow=false
dp.Transparency=1;dp.Size=Vector3.new(1,1,1)
local dust=_shNew("ParticleEmitter",dp)
dust.Texture="rbxassetid://6101261926";dust.LightEmission=1
dust.LightInfluence=0.5;dust.Rate=14
dust.Lifetime=NumberRange.new(4,7);dust.Speed=NumberRange.new(0,0.6)
dust.SpreadAngle=Vector2.new(180,180);dust.RotSpeed=NumberRange.new(-8,8)
dust.Rotation=NumberRange.new(0,360)
dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.15,0.09),NumberSequenceKeypoint.new(0.85,0.06),NumberSequenceKeypoint.new(1,0)})
dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0.45),NumberSequenceKeypoint.new(0.8,0.5),NumberSequenceKeypoint.new(1,1)})
dust.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,248,220)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,240,200)),ColorSequenceKeypoint.new(1,Color3.fromRGB(230,235,255))})
local cachedRoot=nil
local function upRoot(c)cachedRoot=c:WaitForChild("HumanoidRootPart",5)end
local rc1=PL.CharacterAdded:Connect(upRoot)
table.insert(_shC,rc1)
if PL.Character then cachedRoot=PL.Character:FindFirstChild("HumanoidRootPart")end
pcall(function()
local T=workspace:FindFirstChildOfClass("Terrain")
if T then
T:SetMaterialColor(Enum.Material.Grass,Color3.fromRGB(90,115,75))
T:SetMaterialColor(Enum.Material.Ground,Color3.fromRGB(105,88,68))
T:SetMaterialColor(Enum.Material.Rock,Color3.fromRGB(112,112,110))
end
end)
L.ClockTime=12
Atm.Color=Color3.fromRGB(212,228,255);Atm.Decay=Color3.fromRGB(92,100,128)
SR.Intensity=0.08
local rsConn=RS.RenderStepped:Connect(function()
if not _shA then return end
L.ClockTime=12
local root=cachedRoot
if not root or not root.Parent then return end
local pos=root.Position
dp.Position=Vector3.new(pos.X,pos.Y+4,pos.Z)
end)
table.insert(_shC,rsConn)
end
local shRow=Instance.new("Frame",sonstigePage)
shRow.Size=UDim2.new(1,0,0,54)
shRow.BackgroundColor3=C.bg2 or _C3_BG2;shRow.BackgroundTransparency=0
shRow.BorderSizePixel=0;corner(shRow,12);shRow.LayoutOrder=4
local shRowS=Instance.new("UIStroke",shRow)
shRowS.Thickness=1;shRowS.Color=C.bg3 or _C3_BG3;shRowS.Transparency=0.3
local shDot=Instance.new("Frame",shRow)
shDot.Size=UDim2.new(0,3,0,34);shDot.Position=UDim2.new(0,0,0.5,-17)
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
local shBtnS=Instance.new("UIStroke",shBtnF)
shBtnS.Thickness=1;shBtnS.Color=Color3.fromRGB(99,155,255);shBtnS.Transparency=0.55
local shBtn=Instance.new("TextButton",shBtnF)
shBtn.Size=UDim2.new(1,0,1,0);shBtn.BackgroundTransparency=1
shBtn.Text="OFF";shBtn.Font=Enum.Font.GothamBold
shBtn.TextSize=11;shBtn.TextColor3=Color3.new(1,1,1);shBtn.ZIndex=5;shBtn.Active=true
local function shToggle()
_shA=not _shA
if _shA then
_shClean();pcall(_shApply)
shBtn.Text="ON";shBtn.TextColor3=Color3.fromRGB(99,155,255)
twP(shBtnF,0.15,{BackgroundColor3=Color3.fromRGB(12,28,70)})
twP(shBtnS,0.15,{Transparency=0.1})
sendNotif("Shader","Realistic Shader aktiv",2)
else
_shA=false;_shClean()
shBtn.Text="OFF";shBtn.TextColor3=Color3.new(1,1,1)
twP(shBtnF,0.15,{BackgroundColor3=Color3.fromRGB(10,18,40),BackgroundTransparency=0.2})
twP(shBtnS,0.15,{Transparency=0.55})
sendNotif("Shader","Shader deaktiviert",2)
end
end
shBtn.MouseButton1Click:Connect(shToggle)
shBtn.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch then shToggle()end end)
shBtn.MouseEnter:Connect(function()twP(shBtnF,0.08,{BackgroundTransparency=0});twP(shBtnS,0.08,{Transparency=0.1});twP(shBtn,0.08,{TextColor3=Color3.fromRGB(99,155,255)})end)
shBtn.MouseLeave:Connect(function()if not _shA then twP(shBtnF,0.08,{BackgroundTransparency=0.2});twP(shBtnS,0.08,{Transparency=0.55});twP(shBtn,0.08,{TextColor3=Color3.new(1,1,1)})end end)
end
-- Ende Shader

-- Bladeball-Ordner geschlossen(40) + ANTIVCBAN(54) + MM2(40) + Shader(54) = 188px
sonstigePage.Size = UDim2.new(1, 0, 0, 188)
-- Automatisch Größe aktualisieren wenn Ordner auf/zu klappt
miscLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local H = miscLayout.AbsoluteContentSize.Y
    if H > 1 then sonstigePage.Size = UDim2.new(1, 0, 0, H) end
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
local HEADER_OFF = 56
local CONTENT_OFF = S_CARD_H + 12
local newH = HEADER_OFF + CONTENT_OFF + pg.Size.Y.Offset + 32
p.ClipsDescendants = false
c.ClipsDescendants = false
twP(sSubArea, 0.24, {Size = UDim2.new(1, 0, 0, pg.Size.Y.Offset + 16)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
twP(p, 0.24, {Size = UDim2.new(0, PANEL_W, 0, newH)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
c.Size = UDim2.new(1, 0, 0, newH - HEADER_OFF)
c.CanvasSize = UDim2.new(0, 0, 0, 0)
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
for i, cat in ipairs(SCRIPT_CATS) do
local xOff = (i - 1) * (S_CARD_W + S_CARD_GAP)
local card = Instance.new("Frame", sGrid)
card.Size = UDim2.new(0, S_CARD_W, 0, S_CARD_H)
card.Position = UDim2.new(0, xOff, 0, 0)
card.BackgroundColor3 = C.bg2; card.BackgroundTransparency = 0
card.BorderSizePixel = 0; corner(card, 12)
local cStr = Instance.new("UIStroke", card)
cStr.Thickness = 1; cStr.Color = C.bg3 or _C3_BG3; cStr.Transparency = 0.3
local selBar = Instance.new("Frame", card)
selBar.Size = UDim2.new(1,-16,0,2); selBar.Position = UDim2.new(0,8,0,0)
selBar.BackgroundColor3 = cat.col; selBar.BackgroundTransparency = 0
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
if sActiveCat ~= catId then
twP(card, 0.1, {BackgroundColor3 = C.bg3 or _C3_BG4})
end
end)
btn.MouseLeave:Connect(function()
if sActiveCat ~= catId then
twP(card, 0.1, {BackgroundColor3 = C.bg2 or _C3_BG2})
end
end)
btn.MouseButton1Click:Connect(function() switchSCat(catId) end)
btn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then switchSCat(catId) end
end)
table.insert(sCatBtns, { id=catId, card=card, lbl=lbl, selBar=selBar, cStr=cStr, col=cat.col, iconRef=_iconRef })
end
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
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://116967071050039"
_act_bangAnimTrack = hum:LoadAnimation(anim)
_act_bangAnimTrack:Play(); _act_bangAnimTrack:AdjustSpeed(2)
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then desc:AddEmote("SitOnHeadAnim", tonumber(_SOH.ANIM_ID)) end
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(_SOH.ANIM_ID))
end)
if not track then pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(_SOH.ANIM_ID))
end) end
if not track then pcall(function()
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. _SOH.ANIM_ID
local ani = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
track = ani:LoadAnimation(anim)
track.Looped = true; track.Priority = Enum.AnimationPriority.Action4; track:Play()
end) end
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
sendNotif("Sit on Head","Sitting on "..targetPlayer.Name.." 🪑",3)
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
local p, c = makePanel("Actions", C.green)
local function buildPlayerDropdown(playerPill, playerPillLbl, playerPillAvatar, playerPillBtn, getTarget, setTarget)
local dropdownOpen = false
local DD_ITEM_H = 34; local DD_MAX = 5
local ddFrame = Instance.new("Frame", ScreenGui)
ddFrame.Name = "FollowDropdown"
ddFrame.BackgroundColor3 = C.bg2; ddFrame.BackgroundTransparency = 0.06
ddFrame.BorderSizePixel = 0; ddFrame.ZIndex = 50; ddFrame.Visible = false
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
ddScroll.CanvasSize = UDim2.new(0,0,0,0); ddScroll.ZIndex = 51
local ddList = Instance.new("UIListLayout", ddScroll)
ddList.SortOrder = Enum.SortOrder.LayoutOrder; ddList.Padding = UDim.new(0,2)
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
noLbl.TextColor3 = C.text; noLbl.ZIndex = 52
end
local selectedFollowTarget = getTarget()
for _, pl in ipairs(plrs) do
local row = Instance.new("Frame", ddScroll)
row.Size = UDim2.new(1,-8,0,DD_ITEM_H); row.BackgroundColor3 = C.bg3
row.BackgroundTransparency = 0.85; row.BorderSizePixel = 0; row.ZIndex = 52
corner(row, 10)
local avatarClip = Instance.new("Frame", row)
avatarClip.Size = UDim2.new(0,24,0,24); avatarClip.Position = UDim2.new(0,5,0.5,-12)
avatarClip.BackgroundColor3 = C.bg3; avatarClip.BackgroundTransparency = 0.4
avatarClip.BorderSizePixel = 0; avatarClip.ZIndex = 53; avatarClip.ClipsDescendants = true
corner(avatarClip, 99)
local avatarImg = Instance.new("ImageLabel", avatarClip)
avatarImg.Size = UDim2.new(1,0,1,0); avatarImg.BackgroundTransparency = 1
avatarImg.Image = "rbxassetid://142509179"; avatarImg.ImageColor3 = C.sub
avatarImg.ScaleType = Enum.ScaleType.Crop; avatarImg.ZIndex = 54
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
nameLbl.TextColor3 = (selectedFollowTarget == pl) and C.green or C.text
nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 53
if selectedFollowTarget == pl then
local dot = Instance.new("Frame", row)
dot.Size = UDim2.new(0,5,0,5); dot.Position = UDim2.new(1,-12,0.5,-2)
dot.BackgroundColor3 = C.green; dot.BorderSizePixel = 0; corner(dot, 99); dot.ZIndex = 53
end
local rowBtn = Instance.new("TextButton", row)
rowBtn.Size = UDim2.new(1,0,1,0); rowBtn.BackgroundTransparency = 1
rowBtn.Text = ""; rowBtn.ZIndex = 54
rowBtn.MouseEnter:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.55})
twP(nameLbl,0.1,{TextColor3=C.green})
end)
rowBtn.MouseLeave:Connect(function()
twP(row,0.1,{BackgroundTransparency=0.85})
if getTarget() ~= pl then tw(nameLbl,0.1,{TextColor3=C.text}):Play() end
end)
rowBtn.MouseButton1Click:Connect(function()
setTarget(pl)
playerPillLbl.Text = pl.DisplayName; playerPillLbl.TextColor3 = C.green
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
        playerPillLbl.Text = pl.DisplayName; playerPillLbl.TextColor3 = C.green
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
local infoStr = Instance.new("UIStroke", infoCard)
infoStr.Thickness = 1; infoStr.Color = C.bg3 or _C3_BG3; infoStr.Transparency = 0.3
local infoDot = Instance.new("Frame", infoCard)
infoDot.Size = UDim2.new(0,3,0,32); infoDot.Position = UDim2.new(0,0,0.5,-16)
infoDot.BackgroundColor3 = C.green or Color3.fromRGB(80,200,120); infoDot.BackgroundTransparency = 0.4
infoDot.BorderSizePixel = 0; corner(infoDot, 99)
local infoIcon = Instance.new("TextLabel", infoCard)
infoIcon.Size = UDim2.new(0,36,1,0); infoIcon.Position = UDim2.new(0,10,0,0)
infoIcon.BackgroundTransparency = 1; infoIcon.Text = "⚡"
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
local pickStr = Instance.new("UIStroke", pickRow)
pickStr.Thickness = 1; pickStr.Color = C.bg3 or _C3_BG3; pickStr.Transparency = 0.3
local pickDot = Instance.new("Frame", pickRow)
pickDot.Size = UDim2.new(0,3,0,26); pickDot.Position = UDim2.new(0,0,0.5,-13)
pickDot.BackgroundColor3 = C.green or Color3.fromRGB(80,200,120); pickDot.BackgroundTransparency = 0.4
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
local playerPillStr = Instance.new("UIStroke", playerPill)
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
local actionPillStr = Instance.new("UIStroke", actionPill)
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
local actionRowStr = Instance.new("UIStroke", actionRow)
actionRowStr.Thickness = 1; actionRowStr.Color = C.bg3 or _C3_BG3; actionRowStr.Transparency = 0.3
local actionRowDot = Instance.new("Frame", actionRow)
actionRowDot.Size = UDim2.new(0,3,0,26); actionRowDot.Position = UDim2.new(0,0,0.5,-13)
actionRowDot.BackgroundColor3 = C.green or Color3.fromRGB(80,200,120); actionRowDot.BackgroundTransparency = 0.4
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
local statusStr = Instance.new("UIStroke", statusCard)
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
sendNotif("Upside Down", "Hanging over " .. targetPlayer.Name .. " 🙃", 3)
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
pcall(function()
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = Vector3.zero
bv.Parent = myHRP; friendHoverVel = bv
end)
myHRP.CFrame = tHRP0.CFrame * CFrame.new(3, 0, 0)
pcall(function()
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://182435933"
_AF.friendDanceTrack = hum:LoadAnimation(anim)
_AF.friendDanceTrack:Play()
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
sendNotif("Spinning", "Orbiting " .. targetPlayer.Name .. " 🌀", 3)
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
actDdList.SortOrder = Enum.SortOrder.LayoutOrder; actDdList.Padding = UDim.new(0,2)
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
rBtn.MouseEnter:Connect(function() tw(row,0.1,{BackgroundTransparency=0.55}):Play(); tw(nameLbl,0.1,{TextColor3=act.col}):Play() end)
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
statusDot.BackgroundColor3 = C.green
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
statusTxt.TextColor3 = C.green
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
local track = nil
local emoteId = tonumber(PIGGYBACK_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("PiggybackAnim", emoteId)
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. PIGGYBACK_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
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
local bp = Instance.new("BodyPosition")
bp.MaxForce = Vector3.new(1e6, 1e6, 1e6); bp.P = 500000; bp.D = 2500
bp.Position = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0)
bp.Parent = myRoot; ppBodyPos = bp
local _ppTP = tgtTorso.Position + tgtTorso.CFrame.LookVector * -1.1 + Vector3.new(0,0.2,0); local _ppCP = _ppTP
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6); bg.P = 500000; bg.D = 2500
bg.CFrame = tgtTorso.CFrame; bg.Parent = myRoot; ppBodyGyro = bg
ppActive = true; ppTarget = targetPlayer
sendNotif("Piggyback", "Clinging to " .. targetPlayer.Name .. " 🎒", 3)
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
local track = nil
local emoteId = tonumber(PIGGYBACK2_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("Piggyback2Anim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. PIGGYBACK2_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
pcall(function()
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
if not track.IsPlaying then track:Play() end
end)
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
local hum = getHumanoid(); if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
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
sendNotif("Piggyback2", "Clinging to " .. targetPlayer.Name .. " 🐗", 3)
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
local track = nil
local emoteId = tonumber(KISS_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("KissAnim", emoteId)
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. KISS_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
if not _SOH.active and not ppActive then setFreeze(false) end
local hum = getHumanoid()
if hum then
if not flyActive then hum.PlatformStand = false end
hum.WalkSpeed = 16
end
FLY_BASE_SPEED = 150
pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end)
end
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
if hum then hum.PlatformStand = true; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end) end
pcall(function() local myR = getRootPart(); if myR then myR:SetNetworkOwner(LocalPlayer) end end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bv.Velocity = _V3_ZERO
bv.Parent = myRoot; kissBodyPos = bv
local oscTime = 0
local KISS_SPEED = 10.0
_AF.kissActive = true; kissTarget = targetPlayer
sendNotif("Kiss", "💋 Kiss: " .. targetPlayer.Name, 3)
kissStartAnim()
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
local track = nil
local emoteId = tonumber(BACKPACK_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BackpackAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BACKPACK_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("LickingAnim", tonumber(LICKING_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(LICKING_ANIM_ID))
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(LICKING_ANIM_ID))
end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. LICKING_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local track = nil
local emoteId = tonumber(SUCKIT_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("SuckItAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. SUCKIT_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local tgtCF0 = tgtRoot.CFrame * CFrame.new(0, 1.2, -2.0) * _CF_ROT180Y
pcall(function() myRoot.CFrame = tgtCF0; myRoot.AssemblyLinearVelocity = _V3_ZERO end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = _V3_ZERO
bv.Parent = myRoot; suckItBodyPos = bv
local oscTime = 0
local SUCKIT_OSC_SPEED = 8.0
_AF.suckItActive = true; suckItTarget = targetPlayer
sendNotif("Suck it", "💋 " .. targetPlayer.Name, 3)
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
local track = nil
local emoteId = tonumber(SUCKING_ANIM_ID)
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("SuckingAnim", emoteId)
track = hum:PlayEmoteAndGetAnimTrackById(emoteId)
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(emoteId) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. SUCKING_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local tgtCF0 = tgtRoot.CFrame * CFrame.new(0, 0.5, -3.1) * _CF_SUCK_ROT
pcall(function() myRoot.CFrame = tgtCF0; myRoot.AssemblyLinearVelocity = _V3_ZERO end)
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0); bv.Velocity = _V3_ZERO
bv.Parent = myRoot; suckingBodyPos = bv
local oscTime = 0
local SUCKING_SPEED = 10.0
_AF.suckingActive = true; suckingTarget = targetPlayer
sendNotif("Sucking", "💦 Sucking " .. targetPlayer.Name, 3)
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("FacefuckAnim", tonumber(FACEFUCK_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(FACEFUCK_ANIM_ID))
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(FACEFUCK_ANIM_ID))
end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. FACEFUCK_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; facefuckBodyPos = bv
local oscTime = 0
local FF_SPEED  = 12.0
local FF_DEPTH  = 0.9
local FF_BASE_Z = -2.8
_AF.facefuckActive = true; facefuckTarget = targetPlayer
sendNotif("Facefuck", "💦 Facefucking " .. targetPlayer.Name, 3)
facefuckStartAnim()
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
local BACKSHOTS_ANIM_ID = "92086651364994"
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("BackshotsAnim", tonumber(BACKSHOTS_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(BACKSHOTS_ANIM_ID))
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(BACKSHOTS_ANIM_ID))
end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BACKSHOTS_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; backshotsBodyPos = bv
local oscTime = 0
local BS_SPEED = 10.0
_AF.backshotsActive = true; backshotsTarget = targetPlayer
sendNotif("Backshots", "Backshots on " .. targetPlayer.Name, 3)
backshotsStartAnim()
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("LayFuckAnim", tonumber(LAYFUCK_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(LAYFUCK_ANIM_ID))
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(tonumber(LAYFUCK_ANIM_ID)) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. LAYFUCK_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local hum = getHumanoid()
if hum then
hum.PlatformStand = true
pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)
end
pcall(function() myRoot:SetNetworkOwner(LocalPlayer) end)
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
local PS_ANIM_ID = "123786470044230"
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("PussySpreadAnim", tonumber(PS_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(PS_ANIM_ID))
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(PS_ANIM_ID))
end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. PS_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("HugAnim", tonumber(HUG_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(HUG_ANIM_ID))
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(HUG_ANIM_ID))
end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. HUG_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
if hugConn     then hugConn:Disconnect();     hugConn     = nil end
if hugBodyPos  then pcall(function() hugBodyPos:Destroy()  end); hugBodyPos  = nil end
hugStopAnim()
pcall(function()
    local myR = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if myR then sethiddenproperty(myR, "PhysicsRepRootPart", nil) end
end)
setFreeze(false)
local hum = getHumanoid(); if hum and not flyActive then hum.PlatformStand = false; pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end) end
if not flyActive then pcall(function()
local _lpc = LocalPlayer.Character
local myRoot =_lpc and _lpc:FindFirstChild("HumanoidRootPart")
pcall(function() if myRoot then myRoot.AssemblyLinearVelocity = Vector3.zero end end)
end) end
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
bv.Velocity = _V3_ZERO
bv.Parent = myRoot; hugBodyPos = bv
local oscTime = 0
local HUG_SPEED = 10.0
_AF.hugActive = true; hugTarget = targetPlayer
sendNotif("Hug", "Hugging " .. targetPlayer.Name .. " 🤗", 3)
hugStartAnim()
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
end
hugBodyPos.Velocity = _V3_ZERO
oscTime = oscTime + dt * HUG_SPEED
pcall(function()
local offset = -1.2 - math.sin(oscTime) * 0.1
myR.CFrame = torso.CFrame * CFrame.new(0, 0, offset) * _CF_ROT180Y
end)
myR.AssemblyLinearVelocity = _V3_ZERO
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("Hug2Anim", tonumber(HUG2_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(HUG2_ANIM_ID))
end
end)
if not track then
pcall(function()
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(HUG2_ANIM_ID))
end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. HUG2_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
if hug2Conn    then hug2Conn:Disconnect();    hug2Conn    = nil end
if hug2BodyPos then pcall(function() hug2BodyPos:Destroy() end); hug2BodyPos = nil end
hug2StopAnim()
setFreeze(false)
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; hug2BodyPos = bv
_AF.hug2Active = true; hug2Target = targetPlayer
sendNotif("Hug 2", "Hugging " .. targetPlayer.Name .. " from behind 🤗", 3)
hug2StartAnim()
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("CarryAnim", tonumber(CARRY_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(CARRY_ANIM_ID))
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(tonumber(CARRY_ANIM_ID)) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. CARRY_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; carryBodyPos = bv
local oscTime = 0
local CARRY_SPEED = 10.0
_AF.carryActive = true; carryTarget = targetPlayer
sendNotif("Carry", "🤲 Carrying " .. targetPlayer.Name, 3)
carryStartAnim()
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
local track = nil
pcall(function()
local desc = hum:FindFirstChildOfClass("HumanoidDescription")
if not desc then desc = hum:WaitForChild("HumanoidDescription", 3) end
if desc then
desc:AddEmote("SSAnim", tonumber(SS_ANIM_ID))
track = hum:PlayEmoteAndGetAnimTrackById(tonumber(SS_ANIM_ID))
end
end)
if not track then
pcall(function() track = hum:PlayEmoteAndGetAnimTrackById(tonumber(SS_ANIM_ID)) end)
end
if not track then
pcall(function()
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. SS_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; ssBodyPos = bv
local oscTime = 0
local SS_SPEED = 10.0
_AF.shoulderSitActive = true; ssTarget = targetPlayer
sendNotif("Shouldersit", "🪑 Sitting on " .. targetPlayer.Name .. "'s shoulder", 3)
ssStartAnim()
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. QA74_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(0, 1e6, 0)
bv.Velocity = Vector3.zero
bv.Parent = myRoot; qa74BodyPos = bv
local oscTime = 0
local QA74_SPEED = 10.0
_AF.qa74Active = true; qa74Target = targetPlayer
sendNotif("Animation", "▶ Playing near " .. targetPlayer.Name, 3)
qa74StartAnim()
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
sendNotif("Orbit TP", "🌀 Orbit: " .. targetPlayer.Name, 3)
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
do local function _TLact_ByteBreaker() do
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. PIGGYBACK_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. PIGGYBACK2_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_BACKSHOTS_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_CARRY_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_BANGV2_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_CARRY2_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_HUG_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_LICKING_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_HUG2_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then animator = Instance.new("Animator", hum) end
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://" .. BB_LAYFUCK_ANIM_ID
track = animator:LoadAnimation(anim)
track.Looped   = true
track.Priority = Enum.AnimationPriority.Action4
track:Play()
end)
end
if not track then return end
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
end
startBB = function(targetPlayer, modeKey)
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
if not _AF.bbActive then return end
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
sendNotif("ByteBreaker", "⚡ "..pl.Name.." has left", 2)
end
end))
local modeNames = {
bb_attach="ByteBackshots", bb_orbit="Orbit", bb_frontwalk="Front",
bb_behind="Behind", bb_headsit="Head Sit", bb_copy="Copy",
bb_piggyback="Piggyback", bb_piggyback2="Piggyback2", bb_carry="Carry",
bb_bangv2="BangV2", bb_carry2="Carry2", bb_hug="Hug", bb_hug2="Hug2", bb_layfuck="LayFuck", bb_licking="Licking",
}
sendNotif("ByteBreaker", "⚡ "..(modeNames[modeKey] or modeKey)..": "..targetPlayer.Name, 3)
end
end end _TLact_ByteBreaker() end
do
local p, c = makePanel("Playerlist", C.orange)
local ROW_H  = 56
local GAP    = 8
local PAD    = 16
local avatarCache = {}
local rowCache    = {}
local ROW_H_ACTUAL = 66
local STAFF_BY_PLACE = {
[136162036182779] = {
["soulofadore"]=true,["Gzupdrizzy"]=true,["CidsCurse"]=true,
["7Zois"]=true,["DragoX_rblx"]=true,["tenwlk"]=true,
["crashedfantasy"]=true,["HeavenlyHildeLu"]=true,
["o7nov"]=true,["cemalisiert"]=true,
},
}
local function makeBtn(parent, xPos, w, label, accentC)
local btn = Instance.new("Frame", parent)
btn.Size             = UDim2.new(0, w, 0, 24)
btn.Position         = UDim2.new(0, xPos, 0.5, -12)
btn.BackgroundColor3 = C.bg3 or Color3.fromRGB(7,22,10)
btn.BackgroundTransparency = 0.2; btn.BorderSizePixel = 0; corner(btn, 7)
local s = Instance.new("UIStroke", btn)
s.Thickness = 1; s.Color = accentC; s.Transparency = 0.55
local tb = Instance.new("TextButton", btn)
tb.Size = UDim2.new(1,0,1,0); tb.BackgroundTransparency = 1
tb.Text = label; tb.Font = Enum.Font.GothamBold
tb.TextSize = 10; tb.TextColor3 = Color3.new(1,1,1); tb.ZIndex = 4
tb.MouseEnter:Connect(function()
twP(btn,.1,{BackgroundTransparency=0}):Play(); tw(s,.1,{Transparency=0.1})
twP(tb,.1,{TextColor3=accentC})
end)
tb.MouseLeave:Connect(function()
twP(btn,.1,{BackgroundTransparency=0.2}):Play(); tw(s,.1,{Transparency=0.55})
twP(tb,.1,{TextColor3=Color3.new(1,1,1)})
end)
return btn, tb, s
end
local function createRow(pl, yPos)
local isMe  = (pl == LocalPlayer)
local col   = isMe and (C.accent or Color3.fromRGB(0,210,255))
or (C.orange or Color3.fromRGB(255,155,45))
local RH    = ROW_H_ACTUAL
local card = Instance.new("Frame", c)
card.Size             = UDim2.new(1, -PAD*2, 0, RH)
card.Position         = UDim2.new(0, PAD, 0, yPos)
card.BackgroundColor3 = C.bg2 or Color3.fromRGB(3,14,6)
card.BackgroundTransparency = 0; card.BorderSizePixel = 0
corner(card, 12)
local cStr = Instance.new("UIStroke", card)
cStr.Thickness = 1; cStr.Color = C.bg3 or Color3.fromRGB(7,22,10); cStr.Transparency = 0.3
local cdot = Instance.new("Frame", card)
cdot.Size             = UDim2.new(0, 3, 0, RH-16)
cdot.Position         = UDim2.new(0, 0, 0.5, -(RH-16)/2)
cdot.BackgroundColor3 = col; cdot.BackgroundTransparency = 0.3
cdot.BorderSizePixel  = 0; corner(cdot, 99)
local avF = Instance.new("Frame", card)
avF.Size = UDim2.new(0,38,0,38); avF.Position = UDim2.new(0,12,0.5,-19)
avF.BackgroundColor3 = C.bg3 or Color3.fromRGB(7,22,10)
avF.BackgroundTransparency = 0.2; avF.BorderSizePixel = 0; corner(avF,99)
local clipF = Instance.new("Frame",avF); clipF.Size=UDim2.new(1,0,1,0)
clipF.BackgroundTransparency=1; clipF.BorderSizePixel=0; clipF.ClipsDescendants=true; corner(clipF,99)
local avatar = Instance.new("ImageLabel",clipF)
avatar.Size=UDim2.new(1,0,1,0); avatar.BackgroundTransparency=1
avatar.BorderSizePixel=0; avatar.ScaleType=Enum.ScaleType.Crop; avatar.ZIndex=5
if avatarCache[pl.UserId] then
avatar.Image=avatarCache[pl.UserId]; avatar.ImageColor3=Color3.new(1,1,1)
else
avatar.Image="rbxassetid://142509179"; avatar.ImageColor3=C.sub or Color3.fromRGB(0,155,44)
task.spawn(function()
local ok,url=pcall(function()
return Players:GetUserThumbnailAsync(pl.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
end)
if ok and url and avatar.Parent then
avatarCache[pl.UserId]=url; avatar.Image=url; avatar.ImageColor3=Color3.new(1,1,1)
end
end)
end
local ring=Instance.new("UIStroke",avF); ring.Thickness=1.5; ring.Color=col; ring.Transparency=0.3
local nameX = 58
local nameLbl = Instance.new("TextLabel",card)
nameLbl.Size=UDim2.new(0,145,0,18); nameLbl.Position=UDim2.new(0,nameX,0,7)
nameLbl.BackgroundTransparency=1; nameLbl.Text=pl.DisplayName
nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=13
nameLbl.TextColor3=C.text or Color3.new(1,1,1)
nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.TextTruncate=Enum.TextTruncate.AtEnd
local userLbl = Instance.new("TextLabel",card)
userLbl.Size=UDim2.new(0,145,0,12); userLbl.Position=UDim2.new(0,nameX,0,26)
userLbl.BackgroundTransparency=1
userLbl.Text="@"..pl.Name..(isMe and "  ★" or "")
userLbl.Font=Enum.Font.GothamBold; userLbl.TextSize=9
userLbl.TextColor3=C.sub or Color3.fromRGB(0,155,44)
userLbl.TextXAlignment=Enum.TextXAlignment.Left; userLbl.TextTruncate=Enum.TextTruncate.AtEnd
local rankBg = Instance.new("Frame",card)
rankBg.Size=UDim2.new(0,52,0,14); rankBg.Position=UDim2.new(0,nameX,0,41)
rankBg.BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)
rankBg.BackgroundTransparency=0.3; rankBg.BorderSizePixel=0; corner(rankBg,99)
local rankTxt=Instance.new("TextLabel",rankBg)
rankTxt.Size=UDim2.new(1,0,1,0); rankTxt.BackgroundTransparency=1
rankTxt.Font=Enum.Font.GothamBold; rankTxt.TextSize=8
rankTxt.Text="Spieler"; rankTxt.TextColor3=C.sub or Color3.fromRGB(0,155,44)
rankTxt.TextXAlignment=Enum.TextXAlignment.Center; rankTxt.ZIndex=3
task.spawn(function()
local staffList = STAFF_BY_PLACE[game.PlaceId]
if staffList and staffList[pl.Name] then
if rankBg.Parent then
rankBg.BackgroundColor3 = Color3.fromRGB(255,200,80)
rankBg.BackgroundTransparency = 0.7
rankTxt.Text = "Moderator"
rankTxt.TextColor3 = Color3.fromRGB(255,215,100)
end
end
end)
local function makePill(xScale, xOff, w, label, accentC)
local f = Instance.new("Frame", card)
f.Size=UDim2.new(0,w,0,24)
f.Position=UDim2.new(xScale, xOff, 0.5, -12)
f.BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)
f.BackgroundTransparency=0.2; f.BorderSizePixel=0; corner(f,7)
local s=Instance.new("UIStroke",f); s.Thickness=1; s.Color=accentC; s.Transparency=0.55
local tb=Instance.new("TextButton",f)
tb.Size=UDim2.new(1,0,1,0); tb.BackgroundTransparency=1
tb.Text=label; tb.Font=Enum.Font.GothamBold
tb.TextSize=10; tb.TextColor3=Color3.new(1,1,1); tb.ZIndex=10
tb.Active=true
tb.MouseEnter:Connect(function()
twP(f,.1,{BackgroundTransparency=0}):Play(); tw(s,.1,{Transparency=0.1})
twP(tb,.1,{TextColor3=accentC})
end)
tb.MouseLeave:Connect(function()
twP(f,.1,{BackgroundTransparency=0.2}):Play(); tw(s,.1,{Transparency=0.55})
twP(tb,.1,{TextColor3=Color3.new(1,1,1)})
end)
return f, tb, s
end
local PW, GAP2 = 44, 6
local espF, espBtn, espS = makePill(1, -PW-8,          PW, "ESP",  C.green  or Color3.fromRGB(0,230,140))
local espOn = false
espBtn.MouseButton1Click:Connect(function()
espOn = not espOn
if espOn then
espBtn.Text = "ESP ✓"
twP(espF,.15,{BackgroundColor3=C.green or Color3.fromRGB(0,80,40)})
twP(espS,.15,{Transparency=0.1})
twP(cStr,.15,{Color=C.green or Color3.fromRGB(0,230,140),Transparency=0.4})
local char=pl.Character
if char and not espHighlights[pl] then
local h=Instance.new("Highlight",PlayerGui)
h.Adornee=char; h.FillTransparency=1
h.OutlineColor=Color3.new(1,1,1); h.OutlineTransparency=0
espHighlights[pl]=h
end
else
espBtn.Text = "ESP"
twP(espF,.15,{BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)})
twP(espS,.15,{Transparency=0.55})
twP(cStr,.15,{Color=C.bg3 or Color3.fromRGB(7,22,10),Transparency=0.3})
if espHighlights[pl] then espHighlights[pl]:Destroy(); espHighlights[pl]=nil end
end
end)
espBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        espOn = not espOn
        if espOn then
            espBtn.Text = "ESP ✓"
            twP(espF,.15,{BackgroundColor3=C.green or Color3.fromRGB(0,80,40)})
            twP(espS,.15,{Transparency=0.1})
            twP(cStr,.15,{Color=C.green or Color3.fromRGB(0,230,140),Transparency=0.4})
            local char=pl.Character
            if char and not espHighlights[pl] then
                local h=Instance.new("Highlight",PlayerGui)
                h.Adornee=char; h.FillTransparency=1
                h.OutlineColor=Color3.new(1,1,1); h.OutlineTransparency=0
                espHighlights[pl]=h
            end
        else
            espBtn.Text = "ESP"
            twP(espF,.15,{BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)})
            twP(espS,.15,{Transparency=0.55})
            twP(cStr,.15,{Color=C.bg3 or Color3.fromRGB(7,22,10),Transparency=0.3})
            if espHighlights[pl] then espHighlights[pl]:Destroy(); espHighlights[pl]=nil end
        end
    end
end)
if not isMe then
local _, tpBtn2, _ = makePill(1, -PW-8-GAP2-PW-8, PW, "TP",   C.accent or Color3.fromRGB(0,210,255))
tpBtn2.MouseButton1Click:Connect(function()
if pl.Character then
local tR=pl.Character:FindFirstChild("HumanoidRootPart"); local mR=getRootPart()
if tR and mR then mR.CFrame=tR.CFrame*CFrame.new(0,0,3.5) end
end
end)
tpBtn2.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        if pl.Character then
            local tR=pl.Character:FindFirstChild("HumanoidRootPart"); local mR=getRootPart()
            if tR and mR then mR.CFrame=tR.CFrame*CFrame.new(0,0,3.5) end
        end
    end
end)
local isSpectating = false
local specF, specBtn, specS2 = makePill(1, -PW-8-GAP2-PW-8-GAP2-PW-8, PW, "Spec", C.accent2 or C.accent)
specBtn.MouseButton1Click:Connect(function()
isSpectating = not isSpectating
local cam = workspace.CurrentCamera; if not cam then return end
if isSpectating then
specBtn.Text = "Spec ✓"
twP(specF,.15,{BackgroundColor3=C.accent2 or Color3.fromRGB(0,80,20)})
twP(specS2,.15,{Transparency=0.1})
local char=pl.Character
if char then
local hum=char:FindFirstChildOfClass("Humanoid")
if hum then
cam.CameraType=Enum.CameraType.Custom
cam.CameraSubject=hum
end
end
else
specBtn.Text = "Spec"
twP(specF,.15,{BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)})
twP(specS2,.15,{Transparency=0.55})
local myChar=LocalPlayer.Character
if myChar then
cam.CameraType=Enum.CameraType.Custom
cam.CameraSubject=myChar:FindFirstChildOfClass("Humanoid") or myChar:FindFirstChild("HumanoidRootPart")
end
end
end)
specBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        isSpectating = not isSpectating
        local cam = workspace.CurrentCamera; if not cam then return end
        if isSpectating then
            specBtn.Text = "Spec ✓"
            twP(specF,.15,{BackgroundColor3=C.accent2 or Color3.fromRGB(0,80,20)})
            twP(specS2,.15,{Transparency=0.1})
            local char=pl.Character
            if char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum then
                    cam.CameraType=Enum.CameraType.Custom
                    cam.CameraSubject=hum
                end
            end
        else
            specBtn.Text = "Spec"
            twP(specF,.15,{BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)})
            twP(specS2,.15,{Transparency=0.55})
            local myChar=LocalPlayer.Character
            if myChar then
                cam.CameraType=Enum.CameraType.Custom
                cam.CameraSubject=myChar:FindFirstChildOfClass("Humanoid") or myChar:FindFirstChild("HumanoidRootPart")
            end
        end
    end
end)
end
card.MouseEnter:Connect(function() tw(card,.08,{BackgroundColor3=C.bg3 or Color3.fromRGB(7,22,10)}):Play() end)
card.MouseLeave:Connect(function() tw(card,.08,{BackgroundColor3=C.bg2 or Color3.fromRGB(3,14,6)}):Play() end)
rowCache[pl.UserId]={row=card}
return card
end
local function rebuildList()
local plrs=Players:GetPlayers()
local activeIds={}
for _,pl in ipairs(plrs) do activeIds[pl.UserId]=true end
for uid,entry in pairs(rowCache) do
if not activeIds[uid] then entry.row:Destroy(); rowCache[uid]=nil end
end
-- Moderatoren immer zuerst, dann alle anderen
local staffList = STAFF_BY_PLACE[game.PlaceId]
table.sort(plrs, function(a, b)
    local aMod = staffList and staffList[a.Name] and true or false
    local bMod = staffList and staffList[b.Name] and true or false
    if aMod ~= bMod then return aMod end  -- Mod kommt vor Nicht-Mod
    return a.Name < b.Name               -- alphabetisch innerhalb der Gruppe
end)
for i,pl in ipairs(plrs) do
local yPos=(i-1)*(ROW_H_ACTUAL+GAP)
local entry=rowCache[pl.UserId]
if entry then entry.row.Position=UDim2.new(0,PAD,0,yPos)
else createRow(pl,yPos) end
end
local total=#plrs*(ROW_H_ACTUAL+GAP)+16
c.CanvasSize=UDim2.new(0,0,0,math.max(ROW_H_ACTUAL,total))
p.Size=UDim2.new(0,PANEL_W,0,math.min(total,420))
end
rebuildList()
Players.PlayerAdded:Connect(function() task.wait(0.15); rebuildList() end)
Players.PlayerRemoving:Connect(function(pl)
task.wait(0.15)
local entry = rowCache[pl.UserId]
if entry then entry.row:Destroy(); rowCache[pl.UserId] = nil end
rebuildList()
end)
end
function makeKeybindWidget(parent, yPos, actionName, defaultKey, callback)
registerKeybind(actionName, defaultKey, callback)
local row = Instance.new("Frame", parent)
row.Size             = UDim2.new(1, 0, 0, 44)
row.Position         = UDim2.new(0, 0, 0, yPos)
row.BackgroundColor3 = C.bg2 or _C3_BG2
row.BackgroundTransparency = 0
row.BorderSizePixel  = 0
corner(row, 12)
local rowS = Instance.new("UIStroke", row); rowS.Thickness = 1; rowS.Color = C.bg3 or _C3_BG3; rowS.Transparency = 0.3
local rowD = Instance.new("Frame", row); rowD.Size = UDim2.new(0,3,0,24); rowD.Position = UDim2.new(0,0,0.5,-12)
rowD.BackgroundColor3 = C.accent2 or C.accent; rowD.BackgroundTransparency = 0.4; rowD.BorderSizePixel = 0; corner(rowD, 99)
local lbl = Instance.new("TextLabel", row)
lbl.Size             = UDim2.new(0, 230, 1, 0)
lbl.Position         = UDim2.new(0, 14, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Text             = actionName
lbl.Font             = Enum.Font.GothamBold
lbl.TextSize = 13
lbl.TextColor3       = C.text
lbl.TextXAlignment   = Enum.TextXAlignment.Left
local pill = Instance.new("Frame", row)
pill.Size            = UDim2.new(0, 110, 0, 28)
pill.Position        = UDim2.new(1, -122, 0.5, -14)
pill.BackgroundColor3 = C.bg3 or _C3_BG3
pill.BackgroundTransparency = 0.2
pill.BorderSizePixel = 0
corner(pill, 8)
local pillStroke = Instance.new("UIStroke", pill)
pillStroke.Thickness = 1; pillStroke.Color = C.accent2 or C.accent; pillStroke.Transparency = 0.6
local function keyName(kc)
if kc == nil then return "None" end
local n = tostring(kc):gsub("Enum.KeyCode.", "")
return n
end
local kl = Instance.new("TextLabel", pill)
kl.Size              = UDim2.new(1, 0, 1, 0)
kl.BackgroundTransparency = 1
kl.Text              = keyName(defaultKey)
kl.Font              = Enum.Font.GothamBlack
kl.TextSize = 13
kl.TextColor3        = C.text
kl.TextXAlignment    = Enum.TextXAlignment.Center
keybindLabelUpdaters[actionName] = function(kc)
pcall(function() kl.Text = keyName(kc) end)
end
local pillBtn = Instance.new("TextButton", pill)
pillBtn.Size             = UDim2.new(1, 0, 1, 0)
pillBtn.BackgroundTransparency = 1
pillBtn.Text             = ""
pillBtn.ZIndex           = 6
local listening     = false
local listenConn    = nil
local blinkConn     = nil
local blinkState    = false
local function stopListening()
listening = false
if listenConn then listenConn:Disconnect(); listenConn = nil end
blinkConn = nil
twP(pill, 0.15, {BackgroundTransparency = 0.08})
twP(pillStroke, 0.15, {Transparency = 0.28})
kl.TextColor3 = C.text
kl.Text = keyName(keybinds[actionName] and keybinds[actionName].key)
end
local function startListening()
if listening then stopListening(); return end
listening = true
kl.Text = "Press key..."
kl.TextColor3 = C.accent
blinkConn = task.spawn(function()
while listening and _tlAlive() do
blinkState = not blinkState
pcall(function()
pill.BackgroundTransparency = blinkState and 0.02 or 0.25
end)
task.wait(0.5)
end
end)
listenConn = UserInputService.InputBegan:Connect(function(input, gpe)
if input.KeyCode == Enum.KeyCode.Escape then
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
pillBtn.MouseButton1Click:Connect(startListening)
pillBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then startListening() end
end)
pillBtn.MouseEnter:Connect(function()
if not listening then
twP(pill, 0.12, {BackgroundTransparency = 0.0})
twP(kl, 0.12, {TextColor3 = C.accent})
end
end)
pillBtn.MouseLeave:Connect(function()
if not listening then
twP(pill, 0.12, {BackgroundTransparency = 0.08})
twP(kl, 0.12, {TextColor3 = C.text})
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
;(function()
local p, c = makePanel("Settings", C.sub)
-- ── Dynamische Panel-Höhe: passt sich dem Inhalt an ──
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
    local _touch = pcall(function() return game:GetService("UserInputService").TouchEnabled end)
                   and game:GetService("UserInputService").TouchEnabled
    local _kb    = pcall(function() return game:GetService("UserInputService").KeyboardEnabled end)
                   and game:GetService("UserInputService").KeyboardEnabled
    -- intentionally left empty: built-in scrollbar is hidden, custom sbTrack handles visibility
    _ = _touch; _ = _kb
end
local CATS = {
    { id = "General",  icon = "⚙", img = "rbxassetid://126502481176222", col = C.accent,  iconSize = 28 },
    { id = "Keybinds", icon = "⌨", img = "rbxassetid://82757544275536", col = C.accent2, iconSize = 28 },
    { id = "Colors",   icon = "🎨", img = "rbxassetid://82124356614946",  col = C.accent,  iconSize = 28 },
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
local genPage = Instance.new("Frame", subArea)
genPage.BackgroundTransparency = 1; genPage.BorderSizePixel = 0
genPage.Visible = false
local _, notifSet = subRow(genPage,   0, T.settings_notif, T.settings_notif_badge,   C.green,   settingsState.notifications, function(on)
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
_G.settingToggleSetters = settingToggleSetters
genPage.Size = UDim2.new(1, 0, 0, 108 + 8)
local kbPage = Instance.new("Frame", subArea)
kbPage.BackgroundTransparency = 1; kbPage.BorderSizePixel = 0
kbPage.Visible = false
local kbHint = Instance.new("TextLabel", kbPage)
kbHint.Size = UDim2.new(1, -16, 0, 18)
kbHint.Position = UDim2.new(0, 8, 0, 4)
kbHint.BackgroundTransparency = 1
kbHint.Text = T.kb_hint
kbHint.Font = Enum.Font.Gotham
kbHint.TextSize = 11
kbHint.TextColor3 = C.sub or Color3.fromRGB(0,155,44)
kbHint.TextXAlignment = Enum.TextXAlignment.Left
local kbContainer = Instance.new("Frame", kbPage)
kbContainer.Size = UDim2.new(1, 0, 0, 0)
kbContainer.Position = UDim2.new(0, 0, 0, 26)
kbContainer.BackgroundTransparency = 1
kbContainer.BorderSizePixel = 0
local keybindEntries = {
{ "Toggle SmartBar",  "fixed", "K" },
{ "Toggle Fly",       Enum.KeyCode.F,            function()
flyActive = not flyActive
setFly(flyActive)
if _flyPanelSetFn then pcall(_flyPanelSetFn, flyActive) end
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
}
local totalKbRows = 0
for i, entry in ipairs(keybindEntries) do
local yPos = (i - 1) * 54
if entry[2] == "fixed" then
local row = Instance.new("Frame", kbContainer)
row.Size = UDim2.new(1, 0, 0, 44)
row.Position = UDim2.new(0, 0, 0, yPos)
row.BackgroundColor3 = C.bg2 or _C3_BG2
row.BackgroundTransparency = 0; row.BorderSizePixel = 0
corner(row, 12)
local rowStr = Instance.new("UIStroke", row)
rowStr.Thickness = 1; rowStr.Color = C.bg3 or _C3_BG3; rowStr.Transparency = 0.3
local rowDot = Instance.new("Frame", row)
rowDot.Size = UDim2.new(0,3,0,24); rowDot.Position = UDim2.new(0,0,0.5,-12)
rowDot.BackgroundColor3 = C.accent; rowDot.BackgroundTransparency = 0.4
rowDot.BorderSizePixel = 0; corner(rowDot, 99)
local lbl = Instance.new("TextLabel", row)
lbl.Size = UDim2.new(0, 230, 1, 0)
lbl.Position = UDim2.new(0, 14, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Text = entry[1]
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 13
lbl.TextColor3 = C.text
lbl.TextXAlignment = Enum.TextXAlignment.Left
local pill = Instance.new("Frame", row)
pill.Size = UDim2.new(0, 110, 0, 28)
pill.Position = UDim2.new(1, -122, 0.5, -14)
pill.BackgroundColor3 = C.bg3 or _C3_BG3
pill.BackgroundTransparency = 0.2; pill.BorderSizePixel = 0
corner(pill, 8)
local pillStr = Instance.new("UIStroke", pill)
pillStr.Thickness = 1; pillStr.Color = C.accent; pillStr.Transparency = 0.6
local kl = Instance.new("TextLabel", pill)
kl.Size = UDim2.new(1, 0, 1, 0)
kl.BackgroundTransparency = 1
kl.Text = entry[3] .. "  (fixed)"
kl.Font = Enum.Font.GothamBold
kl.TextSize = 11
kl.TextColor3 = C.text
kl.TextXAlignment = Enum.TextXAlignment.Center
else
makeKeybindWidget(kbContainer, yPos, entry[1], entry[2], entry[3])
end
totalKbRows = totalKbRows + 1
end
kbContainer.Size = UDim2.new(1, 0, 0, totalKbRows * 54)
kbPage.Size = UDim2.new(1, 0, 0, 26 + totalKbRows * 54 + 8)

-- ── Colors sub-page ──────────────────────────────────────
local colorsPage = Instance.new("Frame", subArea)
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
    -- ── Chip-Farben: Hardcodiert, nicht vom Theme remapping betroffen ──
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
        local cStr2 = Instance.new("UIStroke", card)
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
    
    -- ── Callback registrieren: Nach jedem Theme-Switch Chips korrigieren ──
    local env = getgenv and getgenv() or _G
    pcall(function()
        env._TL_FixThemeChips = function(themeId)
            task.defer(function()
                pcall(function() updateThemeChips(themeId or _TL_activeThemeId) end)
            end)
        end
    end)
end

subPages = { General = genPage, Keybinds = kbPage, Colors = colorsPage }

-- subArea-Höhe → Panel + CanvasSize updaten
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
-- ✅ Icons behalten IMMER ihre Original-Farbe - NICHT färben!
if cb.iconRef then pcall(function()
    if cb.iconRef:IsA("ImageLabel") then twP(cb.iconRef, 0.15, {ImageColor3 = Color3.fromRGB(180, 180, 180)})
    else twP(cb.iconRef, 0.15, {TextColor3 = Color3.fromRGB(180, 180, 180)}) end
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
-- ✅ Icons behalten IMMER ihre Original-Farbe - NICHT färben!
if cb.iconRef then pcall(function()
    if cb.iconRef:IsA("ImageLabel") then twP(cb.iconRef, 0.20, {ImageColor3 = Color3.fromRGB(180, 180, 180)})
    else twP(cb.iconRef, 0.20, {TextColor3 = Color3.fromRGB(180, 180, 180)}) end
end) end
end
end
end
for i, cat in ipairs(CATS) do
local xOff = (i - 1) * (CARD_W_S + CARD_GAP)
local card = Instance.new("Frame", grid)
card.Size = UDim2.new(0, CARD_W_S, 0, CARD_H_S)
card.Position = UDim2.new(0, xOff, 0, 0)
card.BackgroundColor3 = C.bg2; card.BackgroundTransparency = 0
card.BorderSizePixel = 0; corner(card, 12)
local cStr = Instance.new("UIStroke", card)
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
    iconImg.ImageColor3        = Color3.fromRGB(180, 180, 180)
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
if _iconRef then pcall(function()
    if _iconRef:IsA("ImageLabel") then _iconRef.ImageColor3 = Color3.fromRGB(110,115,125)
    else _iconRef.TextColor3 = C.sub or _C3_SUB end
end) end
end
-- p.Size bereits oben auf SET_PANEL_H gesetzt; kein Überschreiben hier
end)()
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
;(function()
local BAR_W, BAR_H, BAR_R = 514, 58, 8   -- BAR_R 8 = eckiger Matrix-Look (panels still use this)
local TAB_W = math.floor(BAR_W / 6)

-- ── Vertical Tab Launcher dimensions ─────────────────
-- FIX Mobile: Größere Touch-Targets auf Handy
local VL_W, VL_H, VL_GAP, VL_ICON_W, VL_ICON_H
do
    local _ok, _vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp = _ok and _vp or Vector2.new(1920, 1080)
    local _touch = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local _kbd   = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local _short = math.min(_vp.X, _vp.Y)
    if _touch and not _kbd and _short < 500 then
        -- Kleines Handy: deutlich größere Tabs
        VL_W      = 72
        VL_H      = 78
        VL_GAP    = 8
        VL_ICON_W = 72
        VL_ICON_H = 72
    elseif _touch and not _kbd then
        -- Tablet: etwas größere Tabs
        VL_W      = 66
        VL_H      = 72
        VL_GAP    = 7
        VL_ICON_W = 66
        VL_ICON_H = 66
    else
        VL_W      = 58
        VL_H      = 64
        VL_GAP    = 6
        VL_ICON_W = 58
        VL_ICON_H = 58
    end
end
local VL_X_OFF  = -5   -- same x-offset as fpsWidget

-- Mobile/Tablet scaling (kept for panels, not the launcher itself)
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

-- FIX Mobile: Panel-Position an Layout anpassen
-- Desktop: Panels öffnen rechts vom Tab-Strip (oben rechts)
-- Mobile: Panels öffnen links vom Tab-Strip (Tabs sind rechts unten)
local _PNL_X, PANEL_SHOW, PANEL_HIDE
do
    local _okP, _vpP = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vpP = _okP and _vpP or Vector2.new(1920, 1080)
    local _tP  = pcall(function() return UIS.TouchEnabled end) and UIS.TouchEnabled
    local _kP  = pcall(function() return UIS.KeyboardEnabled end) and UIS.KeyboardEnabled
    local _shP = math.min(_vpP.X, _vpP.Y)
    if _tP and not _kP then
        -- Mobile/Tablet: Panels öffnen links des Tab-Strips, von unten nach oben
        -- Tab-Strip ist rechts (AnchorPoint(1,1)), Panels links davon
        -- Panel X: screen_right - VL_W - 8 - PANEL_W  (Panel endet 8px links von Tab-Strip)
        _PNL_X    = 5 + VL_ICON_W + 8   -- bleibt gleich für Panels (links-Offset vom Screen)
        -- Panels erscheinen ausgehend vom unteren Bereich, skaliert zur Bildschirmgröße
        PANEL_SHOW = UDim2.new(0, _PNL_X, 0, 5 + 58 + 8)
        PANEL_HIDE = UDim2.new(0, _PNL_X, 0, -(600))
    else
        -- Desktop: Panels öffnen rechts vom Tab-Strip oben
        _PNL_X    = 5 + VL_ICON_W + 8   -- = 71  (gap + SmartBar width + gap)
        PANEL_SHOW = UDim2.new(0, _PNL_X, 0, 5 + 58 + 8)
        PANEL_HIDE = UDim2.new(0, _PNL_X, 0, -(600))
    end
end

-- ── Matrix Farbpalette ────────────────────────────────
-- Tab-bar accent helpers – always read from live C palette (theme-aware)
local function MG_B()  return C.accent  end
local function MGA_B() return C.accent2 end
local function MGDIM() return C.sub     end

-- ── FPS-Widget Dimensionen (müssen VOR SmartBar stehen, da SmartBar sie referenziert) ──
local FW_W, FW_H, FW_X_OFFSET = 288, 34, -5

-- ── Launcher root: always-visible TL icon button ─────
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

-- TL logo image centered in the icon button
local tlMainIcon = Instance.new("ImageLabel", SmartBar)
tlMainIcon.Size                   = UDim2.new(0, 32, 0, 32)
tlMainIcon.Position               = UDim2.new(0.5, -16, 0.5, -16)
tlMainIcon.BackgroundTransparency = 1
tlMainIcon.Image                  = "rbxassetid://77458828386203"
tlMainIcon.ImageColor3            = Color3.fromRGB(255, 255, 255)  -- Originalfarbe
tlMainIcon.ScaleType              = Enum.ScaleType.Fit
tlMainIcon.ZIndex                 = 10

-- "TL MENU" Label entfernt

-- clickable hitbox over the icon button
local tlMainBtn = Instance.new("TextButton", SmartBar)
tlMainBtn.Size                   = UDim2.new(1, 0, 1, 0)
tlMainBtn.BackgroundTransparency = 1
tlMainBtn.Text                   = ""
tlMainBtn.ZIndex                 = 11

-- Rain/shimmer strip entfernt
local rainLblBar = nil

-- ── Tab cards container (slides out below the icon button) ──
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
        -- Mobile: Tab-Karten wachsen nach OBEN vom fpsWidget-Bereich
        -- fpsWidget AnchorPoint(0.5,1) bei Y=1,-80; Tab-Liste endet bei Y=1,-80-FW_H-8
        local TOTAL_CARDS_H_EST = #{"Home","Character","Scripts","Actions","Playerlist","Settings"} * (VL_H + VL_GAP) - VL_GAP
        tabCardsHolder.AnchorPoint = Vector2.new(1, 1)
        tabCardsHolder.Position    = UDim2.new(1, -5, 1, -80 - 34 - 8)
    else
        -- Desktop: rechts oben, unterhalb des TL-Icons im fpsWidget
        tabCardsHolder.AnchorPoint = Vector2.new(0, 0)
        tabCardsHolder.Position    = UDim2.new(1, -5 - VL_W, 0, 5 + VL_ICON_H + 6)
    end
end

local isOpen, activeTab, _closeTok = false, nil, 0
local tabDefs = {
{ name="Home",       img="rbxassetid://106434334096506" },
{ name="Character",  icon="👤" },
{ name="Scripts",    img="rbxassetid://99812530244292"  },
{ name="Actions",    img="rbxassetid://77458828386203"  },
{ name="Playerlist", icon="👥" },
{ name="Settings",   icon="⚙"  },
}
local tabBtns, selectTab = {}, nil
local TOTAL_CARDS_H = #tabDefs * (VL_H + VL_GAP) - VL_GAP

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
    local cardStroke = Instance.new("UIStroke", card)
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
    if tab.img then
        iconImg = Instance.new("ImageLabel", card)
        iconImg.Size             = UDim2.new(0, 26, 0, 26)
        iconImg.Position         = UDim2.new(0.5, -13, 0, 10)
        iconImg.BackgroundTransparency = 1
        iconImg.Image            = tab.img
        iconImg.ImageColor3      = Color3.new(1, 1, 1)
        iconImg.ScaleType        = Enum.ScaleType.Fit
        iconImg.ZIndex           = 10
    else
        iconLbl = Instance.new("TextLabel", card)
        iconLbl.Size             = UDim2.new(1, 0, 0, 28)
        iconLbl.Position         = UDim2.new(0, 0, 0, 8)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text             = tab.icon or ""
        iconLbl.Font             = Enum.Font.GothamBlack
        iconLbl.TextSize         = 20
        iconLbl.TextColor3 = MGDIM()
        iconLbl.TextXAlignment   = Enum.TextXAlignment.Center
        iconLbl.ZIndex           = 10
    end

    -- label under icon
    local lbl = Instance.new("TextLabel", card)
    lbl.Size             = UDim2.new(1, -4, 0, 12)
    lbl.Position         = UDim2.new(0, 2, 1, -16)
    lbl.BackgroundTransparency = 1
    lbl.Text             = tab.name:upper()
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextSize         = 7
    lbl.TextColor3 = MGDIM()
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
        if activeTab ~= tab.name then
            twP(card, 0.10, {BackgroundColor3 = Color3.fromRGB(22, 22, 22)})
            if iconImg then twP(iconImg, 0.10, {ImageTransparency = 0.2}) end
            if iconLbl then twP(iconLbl, 0.10, {TextColor3 = MGA_B()}) end
            twP(lbl, 0.10, {TextColor3 = MGA_B()})
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.name then
            twP(card, 0.10, {BackgroundColor3 = Color3.fromRGB(14, 14, 14)})
            if iconImg then twP(iconImg, 0.10, {ImageTransparency = 0}) end
            if iconLbl then twP(iconLbl, 0.10, {TextColor3 = MGDIM()}) end
            twP(lbl, 0.10, {TextColor3 = MGDIM()})
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
    twP(tb.lbl, 0.14, {TextColor3 = MGDIM()})
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
    twP(tb.card,  0.18, {BackgroundColor3 = Color3.fromRGB(18, 28, 18)})
    twP(tb.pill,  0.20, {BackgroundTransparency = 0})
    if tb.cardStroke then tb.cardStroke.Color = MG_B(); tb.cardStroke.Transparency = 0.3 end
    if tb.iconLbl then twP(tb.iconLbl, 0.16, {TextColor3 = MG_B()}) end
    if tb.iconImg then twP(tb.iconImg, 0.16, {ImageTransparency = 0}) end
    twP(tb.lbl, 0.16, {TextColor3 = MG_B()})
end
end
if panels[name] then
    local pan = panels[name]
    pan.BackgroundTransparency = 1
    -- FIX Mobile: Panel-Breite dynamisch auf aktuellen PANEL_W setzen
    pan.Size     = UDim2.new(0, PANEL_W, 0, pan.Size.Y.Offset)
    pan.Position = UDim2.new(PANEL_HIDE.X.Scale, PANEL_HIDE.X.Offset, PANEL_HIDE.Y.Scale, PANEL_HIDE.Y.Offset + 18)
    pan.Visible  = true
    -- FIX Mobile: UIScale auf Panel anwenden falls Panel breiter als Bildschirm
    pcall(function()
        local _vps = workspace.CurrentCamera.ViewportSize
        local _availW = _vps.X - _PNL_X - 8
        if PANEL_W > _availW and _availW > 0 then
            local _pScl = pan:FindFirstChildOfClass("UIScale")
            if not _pScl then _pScl = Instance.new("UIScale", pan) end
            _pScl.Scale = math.clamp(_availW / PANEL_W, 0.45, 1.0)
        end
    end)
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
_closeTok = _closeTok + 1
isOpen    = true
tabCardsHolder.Visible = true
tabCardsHolder.Size    = UDim2.new(0, VL_W, 0, 0)
tw(tabCardsHolder, 0.30, {
    Size = UDim2.new(0, VL_W, 0, TOTAL_CARDS_H),
}, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
-- pulse the TL icon (Originalfarbe behalten)
twP(tlMainIcon, 0.18, {ImageColor3 = Color3.fromRGB(255, 255, 255)})
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
-- dim the TL icon (Originalfarbe behalten)
twP(tlMainIcon, 0.18, {ImageColor3 = Color3.fromRGB(255, 255, 255)})
end
_tlTrackConn(UserInputService.InputBegan:Connect(function(input, gpe)
if input.KeyCode ~= Enum.KeyCode.K then
if gpe then return end
end
if input.KeyCode == Enum.KeyCode.K then
if isOpen then closeBar() else openBar() end
end
end))
-- TL icon button click toggles the launcher (legacy SmartBar invisible btn)
-- FIX: Lock verhindert Doppel-Fire (MouseButton1Click + InputBegan:Touch feuern beide)
local _mainBtnLock = false
local function mainBtnActivate()
    if _mainBtnLock then return end
    _mainBtnLock = true
    task.delay(0.35, function() _mainBtnLock = false end)
    if isOpen then closeBar() else openBar() end
end
tlMainBtn.MouseButton1Click:Connect(mainBtnActivate)
tlMainBtn.InputBegan:Connect(function(inp)
if inp.UserInputType == Enum.UserInputType.Touch then
    mainBtnActivate()
end
end)
tlMainBtn.MouseEnter:Connect(function()
twP(SmartBar, 0.12, {BackgroundColor3 = Color3.fromRGB(18, 18, 18)})
end)
tlMainBtn.MouseLeave:Connect(function()
twP(SmartBar, 0.12, {BackgroundColor3 = Color3.fromRGB(10, 10, 10)})
end)
-- Drag entfernt — TL Logo ist nicht verschiebbar
-- Mobile: globaler TouchTap-Handler entfernt — verursachte Konflikt mit tlSmartHitbox
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
fpsWidget.BackgroundColor3       = Color3.fromRGB(1,8,3)
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
        local scl = isMob and math.clamp((short*0.7)/FW_W, 0.5, 0.9)
                           or  math.clamp((short*0.5)/FW_W, 0.65, 0.85)
        local fwUIScale = Instance.new("UIScale", fpsWidget)
        fwUIScale.Scale = scl
        -- bottom-center on mobile instead of right side
        fpsWidget.AnchorPoint = Vector2.new(0.5, 1)
        fpsWidget.Position    = UDim2.new(0.5, 0, 1, -80)
    else
        -- fpsWidget: direkt unterhalb SmartBar (und qaBar), bündig an der rechten Kante
        -- SmartBar right edge = screenW - 5  → fpsWidget AnchorPoint=(1,0), same right edge
        -- SmartBar top=5, height=VL_ICON_H=58 → fpsWidget top = 5 + VL_ICON_H + 4 = 67
        fpsWidget.AnchorPoint = Vector2.new(1, 0)
        fpsWidget.Position    = UDim2.new(1, -(5), 0, 5 + math.floor((VL_ICON_H - FW_H) / 2))
        -- Overlay-Hitbox: AnchorPoint rechts, gleiche rechte Kante wie fpsWidget, gleiche Y-Position
    end
end
do local c = Instance.new("UICorner", fpsWidget); c.CornerRadius = UDim.new(0, 12) end
do
local g = Instance.new("UIGradient", fpsWidget)
g.Color = ColorSequence.new{
ColorSequenceKeypoint.new(0,   Color3.fromRGB(3, 14, 6)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(2, 10, 4)),
ColorSequenceKeypoint.new(1,   Color3.fromRGB(1,  7, 2)),
}
g.Rotation = 135
end
local fwStroke = Instance.new("UIStroke", fpsWidget)
fwStroke.Thickness       = 1
fwStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
fwStroke.Color           = C.accent2
fwStroke.Transparency    = 0.5
local fwAccLine = Instance.new("Frame", fpsWidget)
fwAccLine.Size                   = UDim2.new(1,-20,0,2)
fwAccLine.Position               = UDim2.new(0,10,0,0)
fwAccLine.BackgroundColor3       = Color3.new(1,1,1)
fwAccLine.BackgroundTransparency = 0.15
fwAccLine.BorderSizePixel        = 0
fwAccLine.ZIndex                 = 13
do local c=Instance.new("UICorner",fwAccLine); c.CornerRadius=UDim.new(0,99) end
local fwALG = Instance.new("UIGradient", fwAccLine)
do
local STEPS = 12
local _sweepCache = {}
local function _buildSweepCache()
    for i = 0, STEPS do
        local offset = i / STEPS
        local pL = math.max(0.001, offset - 0.22)
        local pR = math.min(0.999, offset + 0.22)
        local t  = math.clamp(offset, 0.001, 0.999)
        local pts = { ColorSequenceKeypoint.new(0, C.gradL) }
        if pL > 0.001 then table.insert(pts, ColorSequenceKeypoint.new(pL, C.gradL)) end
        table.insert(pts, ColorSequenceKeypoint.new(t, _C3_WHITE))
        if pR < 0.999 then table.insert(pts, ColorSequenceKeypoint.new(pR, C.gradR)) end
        table.insert(pts, ColorSequenceKeypoint.new(1, C.gradR))
        _sweepCache[i] = ColorSequence.new(pts)
    end
end
_buildSweepCache()
-- Register hook so theme changes rebuild the sweep animation cache
if not _panelColorHooks then _panelColorHooks = {} end
_panelColorHooks[#_panelColorHooks+1] = function(_newT)
    _buildSweepCache()
    pcall(function() fwALG.Color = _sweepCache[0] end)
    pcall(function() fwStroke.Color = C.accent2 end)
    pcall(function() fwVal.TextColor3  = C.accent end)
    pcall(function() pingVal.TextColor3 = C.accent end)
    pcall(function() liveDot.BackgroundColor3 = C.accent end)
    -- Update sep frames (borderdim colored separators inside fpsWidget)
    pcall(function()
        for _, ch in ipairs(fpsWidget:GetChildren()) do
            if ch:IsA("Frame") and ch.Size == UDim2.new(0,1,0,16) then
                ch.BackgroundColor3 = C.borderdim
            end
        end
    end)
end
fwALG.Color = _sweepCache[0]
task.spawn(function()
local CYCLE = 1.8; local PAUSE = 0.4
while _tlAlive() and fwAccLine and fwAccLine.Parent do
local t0 = os.clock()
repeat
local p   = math.clamp((os.clock()-t0)/CYCLE, 0, 1)
local idx = math.floor(p * STEPS + 0.5)
fwALG.Color = _sweepCache[idx]
task.wait(0.08)
until (os.clock()-t0) >= CYCLE or not (_tlAlive() and fwAccLine and fwAccLine.Parent)
fwALG.Color = _sweepCache[STEPS]
task.wait(PAUSE)
end
end)
end
function sep(x)
local s = Instance.new("Frame", fpsWidget)
s.Size             = UDim2.new(0,1,0,16)
s.Position         = UDim2.new(0,x,0.5,-8)
s.BackgroundColor3 = C.borderdim
s.BackgroundTransparency = 0.3
s.BorderSizePixel  = 0; s.ZIndex = 11
end
-- Großes TL-Logo (32×32) — öffnet das Menü
local tlLblBig = Instance.new("ImageLabel", fpsWidget)
tlLblBig.Size                   = UDim2.new(0, 22, 0, 22)
tlLblBig.Position               = UDim2.new(0, 9, 0.5, -11)
tlLblBig.BackgroundTransparency = 1
tlLblBig.Image                  = "rbxassetid://77458828386203"
tlLblBig.ImageColor3            = _C3_WHITE
tlLblBig.ScaleType              = Enum.ScaleType.Fit
tlLblBig.ZIndex                 = 11
local tlArrowBig = Instance.new("TextLabel", fpsWidget)
tlArrowBig.Size                 = UDim2.new(0,14,1,0)
tlArrowBig.Position             = UDim2.new(0,33,0,0)
tlArrowBig.BackgroundTransparency = 1
tlArrowBig.Text                 = "▶"
tlArrowBig.Font                 = Enum.Font.GothamBlack
tlArrowBig.TextSize             = 13
tlArrowBig.TextColor3           = Color3.fromRGB(245,245,245)
tlArrowBig.TextXAlignment       = Enum.TextXAlignment.Center
tlArrowBig.ZIndex               = 11
sep(46)
-- Kleines TL-Logo (20×20) — war vorher bereits im Widget
local tlLbl = Instance.new("ImageLabel", fpsWidget)
tlLbl.Size                   = UDim2.new(0, 20, 0, 20)
tlLbl.Position               = UDim2.new(0, 52, 0.5, -10)
tlLbl.BackgroundTransparency = 1
tlLbl.Image                  = "rbxassetid://77458828386203"
tlLbl.ImageColor3            = _C3_WHITE
tlLbl.ScaleType              = Enum.ScaleType.Fit
tlLbl.ZIndex                 = 11
local tlArrow = Instance.new("TextLabel", fpsWidget)
tlArrow.Size                 = UDim2.new(0,14,1,0)
tlArrow.Position             = UDim2.new(0,73,0,0)
tlArrow.BackgroundTransparency = 1
tlArrow.Text                 = "▶"
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
-- tlSmartHitbox: linke Hälfte → öffnet SmartBar
local tlSmartHitbox = Instance.new("TextButton", ScreenGui)
tlSmartHitbox.Name                   = "TLSmartHitbox"
tlSmartHitbox.Size                   = UDim2.new(0, _hitboxW, 0, _hitboxH)
tlSmartHitbox.BackgroundTransparency = 1
tlSmartHitbox.Text                   = ""
tlSmartHitbox.ZIndex                 = 9999
tlSmartHitbox.Active                 = true
tlSmartHitbox.AutoButtonColor        = false
-- tlHitbox: rechte Hälfte → öffnet QABar
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
-- ── Linkes TL-Logo (tlSmartHitbox): SmartBar öffnen/schließen ──────
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
    twP(tlLblBig,  .1, {ImageTransparency=0.3})
    twP(tlArrowBig,.1, {TextTransparency =0.3})
end)
tlSmartHitbox.MouseLeave:Connect(function()
    twP(tlLblBig,  .1, {ImageTransparency=0})
    twP(tlArrowBig,.1, {TextTransparency =0})
end)
sep(88)
local fwTag = Instance.new("TextLabel", fpsWidget)
fwTag.Size             = UDim2.new(0,28,1,0)
fwTag.Position         = UDim2.new(0,94,0,0)
fwTag.BackgroundTransparency = 1
fwTag.Text             = "FPS"
fwTag.Font             = Enum.Font.GothamBlack
fwTag.TextSize         = 9
fwTag.TextColor3       = Color3.fromRGB(245,245,245)
fwTag.TextXAlignment   = Enum.TextXAlignment.Left
fwTag.ZIndex           = 11
local fwVal = Instance.new("TextLabel", fpsWidget)
fwVal.Size             = UDim2.new(0,36,1,0)
fwVal.Position         = UDim2.new(0,124,0,0)
fwVal.BackgroundTransparency = 1
fwVal.Text             = "--"
fwVal.Font             = Enum.Font.GothamBlack
fwVal.TextSize         = 14
fwVal.TextColor3       = C.green
fwVal.TextXAlignment   = Enum.TextXAlignment.Left
fwVal.ZIndex           = 12
sep(165)
local pingTag = Instance.new("TextLabel", fpsWidget)
pingTag.Size             = UDim2.new(0,28,1,0)
pingTag.Position         = UDim2.new(0,171,0,0)
pingTag.BackgroundTransparency = 1
pingTag.Text             = "PING"
pingTag.Font             = Enum.Font.GothamBlack
pingTag.TextSize         = 9
pingTag.TextColor3       = Color3.fromRGB(245,245,245)
pingTag.TextXAlignment   = Enum.TextXAlignment.Left
pingTag.ZIndex           = 11
local pingVal = Instance.new("TextLabel", fpsWidget)
pingVal.Size             = UDim2.new(0,50,1,0)
pingVal.Position         = UDim2.new(0,205,0,0)
pingVal.BackgroundTransparency = 1
pingVal.Text             = "--"
pingVal.Font             = Enum.Font.GothamBlack
pingVal.TextSize         = 14
pingVal.TextColor3       = C.accent
pingVal.TextXAlignment   = Enum.TextXAlignment.Left
pingVal.ZIndex           = 12
sep(260)
local liveDot = Instance.new("Frame", fpsWidget)
liveDot.Size             = UDim2.new(0,6,0,6)
liveDot.Position         = UDim2.new(0, FW_W-18, 0.5,-3)
liveDot.BackgroundColor3 = C.green
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
local _fpsAcc, _fpsFrames, _pingAcc = 0, 0, 0
local _statsService; pcall(function() _statsService = game:GetService("Stats") end)
local _fwPingItem; pcall(function()
    if _statsService then _fwPingItem = _statsService.Network.ServerStatsItem["Data Ping"] end
end)
_tlTrackConn(RunService.Heartbeat:Connect(function(dt)
if not _tlAlive() then return end
_fpsFrames = _fpsFrames + 1
_fpsAcc    = _fpsAcc + dt
if _fpsAcc >= 0.25 then
local fps = _mfloor(_fpsFrames / _fpsAcc)
_fpsAcc = 0; _fpsFrames = 0
if fwVal and fwVal.Parent then
    local col = fps >= 55 and C.green or (fps >= 30 and C.orange or C.red)
    fwVal.Text = fps .. ""
    fwVal.TextColor3 = col
    liveDot.BackgroundColor3 = col
end
end
_pingAcc = _pingAcc + dt
if _pingAcc >= 2 then
    _pingAcc = 0
    if pingVal and pingVal.Parent and _fwPingItem then
        local ok, v = pcall(function() return _fwPingItem:GetValue() end)
        if ok and v then
            pingVal.Text = _mfloor(v) .. "ms"
            pingVal.TextColor3 = v < 80 and C.green or (v < 150 and C.orange or C.red)
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
end)()
local qaStatusDot, qaStatusTxt
;(function()
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
local QA_CH     = 72
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
local f = Instance.new("Frame", parent)
f.Size=sz; f.Position=pos; f.BackgroundColor3=col
f.BackgroundTransparency=alpha; f.BorderSizePixel=0
if r then local c=Instance.new("UICorner",f); c.CornerRadius=UDim.new(0,r) end
return f
end
local function mkTxt(parent, sz, pos, text, font, tsz, col, xAlign)
local l=Instance.new("TextLabel",parent)
l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Text=text
l.Font=font; l.TextSize=tsz; l.TextColor3=col
l.TextXAlignment=xAlign or Enum.TextXAlignment.Left
l.TextTruncate=Enum.TextTruncate.AtEnd
return l
end
local function mkStroke(parent, thick, col, alpha)
local s=Instance.new("UIStroke",parent)
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
P.panel, 0, 14)
qaBar.Name="TLQuickActionsBar"
qaBar.AnchorPoint=Vector2.new(1,0)
qaBar.ClipsDescendants=true
qaBar.Visible=false; qaBar.ZIndex=9
-- Register for drag system
pcall(function() if getgenv then getgenv()._TL_qaBar = qaBar end end)
pcall(function() _TL_refs._TL_qaBar = qaBar end)
local _qaBarStroke = mkStroke(qaBar, 1, P.panelBrd, 0.7)
-- Mobile/Tablet: reposition and scale QA bar
do
    local _ok, _vp = pcall(function() return workspace.CurrentCamera.ViewportSize end)
    _vp = _ok and _vp or Vector2.new(1920,1080)
    local _touch = pcall(function() return game:GetService("UserInputService").TouchEnabled end)
              and game:GetService("UserInputService").TouchEnabled
    local _kbd   = pcall(function() return game:GetService("UserInputService").KeyboardEnabled end)
              and game:GetService("UserInputService").KeyboardEnabled
    local _short = math.min(_vp.X, _vp.Y)
    local _isMob = _touch and not _kbd and _short < 500
    local _isTab = _touch and not _kbd and _short >= 500
    if _isMob or _isTab then
        local _scl = _isMob and 0.80 or 0.90
        local _qaScale = Instance.new("UIScale", qaBar)
        _qaScale.Scale = _scl
        qaBar.AnchorPoint = Vector2.new(1, 0)
        qaBar.Position    = UDim2.new(1, _QA_RIGHT_OFFSET, 0, _QA_TOP_Y)
    end
end
local hdr = mkF(qaBar, UDim2.new(1,0,0,HDR_H), UDim2.new(0,0,0,0), P.hdr, 0, 14)
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
"–", Enum.Font.GothamBold, 9, Color3.new(1,1,1), Enum.TextXAlignment.Left)
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
UDim2.new(0,xPos,0,yPos), P.card, 0, 10)
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
act.label, Enum.Font.GothamBlack, 11, Color3.fromRGB(220,222,240), Enum.TextXAlignment.Center)
lbl.ZIndex=12
local btn = Instance.new("TextButton", bg)
btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
btn.Text=""; btn.ZIndex=15; btn.Active=true
local ci2 = #qaCardRefs+1
qaCardRefs[ci2] = {bg=bg, lbl=lbl, bar=bar, stroke=stroke, key=act.key, col=cat.col}
btn.MouseEnter:Connect(function()
if qaActiveKey==act.key then return end
twP(bg, .1, {BackgroundColor3=P.cardHov})
stroke.Color=P.cardBrdH; stroke.Transparency=0.5
end)
btn.MouseLeave:Connect(function()
if qaActiveKey==act.key then return end
twP(bg, .1, {BackgroundColor3=P.card})
stroke.Color=P.cardBrd; stroke.Transparency=0.5
end)
local function qaCardActivate()
if _qaGlobalLock then return end
_qaGlobalLock = true
task.delay(0.35, function() _qaGlobalLock = false end)
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
qaStatusTxt.Text=act.label..(tgt and(" · "..tgt.Name)or"")
qaStatusTxt.TextColor3=cat.col
end
if qaStatusDot then qaStatusDot.BackgroundColor3=cat.col end
end)
end)
else
if qaStatusTxt then qaStatusTxt.Text="⚠ Kein Ziel"; qaStatusTxt.TextColor3=P.stopTxt end
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
"Idle · Select an action", Enum.Font.Gotham, 8, P.tgtTxt)
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
local np = getNearestPlayer()
tgtNameLbl.Text = np and np.Name or "–"
tgtDot.BackgroundColor3 = np and P.tgtDot or P.tgtTxt
qaBarOpen=true; qaBar.Visible=true
qaBar.Size=UDim2.new(0,QA_W,0,0)
qaBarTween=tw(qaBar,.28,{Size=UDim2.new(0,QA_W,0,FULL_H)},
Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
qaBarTween:Play()
tlArrow.Text="▼"
end
local function closeQABar()
if qaBarTween then pcall(function() qaBarTween:Cancel() end); qaBarTween=nil end
qaBarOpen=false; tlArrow.Text="▶"
qaBarTween=tw(qaBar,.2,{Size=UDim2.new(0,QA_W,0,0)},
Enum.EasingStyle.Quart,Enum.EasingDirection.In)
qaBarTween:Play()
qaBarTween.Completed:Connect(function()
if not qaBarOpen then qaBar.Visible=false end
end)
end
-- ── Rechtes TL-Logo: QABar öffnen/schließen ────────────────────────
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
    twP(tlLbl,  .1,{ImageTransparency=0.3})
    twP(tlArrow,.1,{TextTransparency =0.3})
end)
tlHitbox.MouseLeave:Connect(function()
    twP(tlLbl,  .1,{ImageTransparency=0})
    twP(tlArrow,.1,{TextTransparency =0})
end)
tlArrow.Text="▶"
tlArrowBig.Text="▶"
end)()
pcall(function()
if getgenv then
getgenv().TLUnload = function()
pcall(function()
if _G.TLActionsStop then _G.TLActionsStop() end
end)
pcall(function()
if getgenv()._TLAllConns then
for _, c in ipairs(getgenv()._TLAllConns) do
pcall(function() c:Disconnect() end)
end
getgenv()._TLAllConns = nil
end
end)
pcall(function()
if getgenv()._TLAnimConns then
for _, c in ipairs(getgenv()._TLAnimConns) do
pcall(function() c:Disconnect() end)
end
getgenv()._TLAnimConns = nil
end
end)
pcall(function()
if getgenv and getgenv()._TLFlingConn then
getgenv()._TLFlingConn:Disconnect()
getgenv()._TLFlingConn = nil
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
ghostConn, bbConn, bbRespConn,
bbAnimConn_, bbAnimConn2_, bbAnimConn3_,
bbAnimConn4_, bbAnimConn5_, bbAnimConn6_, bbAnimConn7_,
bbAnimConn8_, bbAnimConn9_, bbAnimConn10_, bbHealthConn_,
bbRespAnimConn_,
invisHeartConn,
}
for _, c in ipairs(_conns) do
if c then pcall(function() c:Disconnect() end) end
end
-- Nil BB anim conns so stale references don't cause false-positive checks after unload
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
if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
-- gethui()-Fallback falls GUI dort liegt (Solara)
if gethui then pcall(function()
local hui = gethui()
local g = hui:FindFirstChild("SmartBarGui"); if g then g:Destroy() end
end) end
end)
pcall(function()
if _espGui and _espGui.Parent then _espGui:Destroy(); _espGui = nil end
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
getgenv()._TLRemoveTool()
getgenv()._TLRemoveTool = nil
end
end)
pcall(function()
if getgenv and getgenv()._TLInvPatchCleanup then
getgenv()._TLInvPatchCleanup()
getgenv()._TLInvPatchCleanup = nil
end
end)
_G.EmotesGUIRunning  = nil
_G.TLActions         = nil
_G.TLActionsStop     = nil
pcall(function()
getgenv().TLUnload       = nil
getgenv().SmartBarLoaded = nil
getgenv().TLSendNotif    = nil
getgenv().TLAnimFreeze   = nil
getgenv().lastPlayedAnimation = nil
getgenv().autoReloadEnabled   = nil
end)
end
end
end)
end)()
