--[[
	Sef's Ftap Visuals v3
	CLIENT-SIDE VISUALS ONLY. Everything is local: lighting, camera, GUI overlays,
	local-only parts / particles and local property changes. Nothing is sent to the
	server and nobody else sees any of it.
	Loads only in "Fling Things and People".
]]

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local Market = game:GetService("MarketplaceService")
local SG = game:GetService("StarterGui")
local Stats = game:GetService("Stats")
local Debris = game:GetService("Debris")
local LP = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local BG_URL = "https://i.ibb.co/pjNPybk2/7467eb4ddbf6abb58e0b2c2f8f7c3466.jpg"
local BG_FILE = "SefFtap/bg_pjNPybk2.jpg"
local CFG_FILE = "SefFtap/config.json"
local FTAP_IDS = { [8316902627] = true }

local function notify(t, x)
	pcall(function() SG:SetCore("SendNotification", { Title = t, Text = x, Duration = 6 }) end)
end

if not game:IsLoaded() then game.Loaded:Wait() end

local function inFtap()
	if FTAP_IDS[game.PlaceId] then return true end
	local ok, info = pcall(function() return Market:GetProductInfo(game.PlaceId) end)
	return ok and info and type(info.Name) == "string" and info.Name:lower():find("fling things and people") ~= nil
end

if not inFtap() then
	notify("Sef's Ftap Visuals", "Not in Fling Things and People - script not loaded.")
	return
end

if env.SefFtapUnload then pcall(env.SefFtapUnload) end

----------------------------------------------------------------------
-- utils
----------------------------------------------------------------------
local alive = true
local conns = {}
local function C(sig, fn) local c = sig:Connect(fn) conns[#conns + 1] = c return c end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function cr(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function tw(o, t, p, st, dr)
	local x = TS:Create(o, TweenInfo.new(t, st or Enum.EasingStyle.Quint, dr or Enum.EasingDirection.Out), p)
	x:Play()
	return x
end
local function fire(cb, ...)
	if cb then
		local ok, e = pcall(cb, ...)
		if not ok then warn("[Sef's Ftap Visuals]", e) end
	end
end
local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	local ok2 = pcall(function() return game:GetService("CoreGui").Name end)
	if ok2 then return game:GetService("CoreGui") end
	return LP:WaitForChild("PlayerGui")
end
local function cam() return workspace.CurrentCamera end
local function hsv(h, s, v) return Color3.fromHSV(h % 1, s or 1, v or 1) end

----------------------------------------------------------------------
-- state
----------------------------------------------------------------------
local S, Ctl, RF = {}, {}, {}
local TEX -- forward-declared (used by L.rig before the grab-line section defines it)
S.accent = Color3.fromRGB(210, 210, 210)
local FEATURES = 0
local L = {}
L.tabs = {}
L.steps = {}
L.cleanups = {}
L.onChar = {}
L.kick = 0
L.names = {}
L.kApplied = 0
local listening = false
local zoomHeld = false
local shk = 0
local T0 = tick()

----------------------------------------------------------------------
-- GUI roots
----------------------------------------------------------------------
local gui = new("ScreenGui", { Name = Http:GenerateGUID(false), ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 50 }, guiParent())
local hud = new("ScreenGui", { Name = Http:GenerateGUID(false), ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 40 }, guiParent())

local WIN_W, WIN_H = 660, 440
local BLACK = Color3.fromRGB(12, 12, 12)

local Main = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = BLACK, BorderSizePixel = 0, ClipsDescendants = true }, gui)
cr(Main, 20)
new("UIStroke", { Color = Color3.fromRGB(190, 190, 190), Transparency = .75, Thickness = 1 }, Main)
local uiScale = new("UIScale", { Scale = 1 }, Main)
local GuiService = game:GetService("GuiService")
local autoFit = 1
local isOpenUI = true
local function computeFit()
	local c = workspace.CurrentCamera
	local vp = c and c.ViewportSize or Vector2.new(1280, 720)
	local inset = Vector2.new(0, 36)
	pcall(function() local tl = GuiService:GetGuiInset() inset = tl end)
	local availX, availY = vp.X - 24, vp.Y - inset.Y - 24
	autoFit = math.clamp(math.min(availX / WIN_W, availY / WIN_H), .35, 1.25)
	return autoFit, inset
end
local function targetScale() return autoFit * ((S and S.ui_scale) or 1) end
local function clampMain()
	local c = workspace.CurrentCamera
	if not c then return end
	local vp = c.ViewportSize
	local _, inset = computeFit()
	local sc = uiScale.Scale
	local hw, hh = WIN_W * sc / 2, WIN_H * sc / 2
	local p = Main.Position
	local ax = vp.X * p.X.Scale + p.X.Offset
	local ay = vp.Y * p.Y.Scale + p.Y.Offset
	local cx = math.clamp(ax, math.min(hw, vp.X / 2), math.max(vp.X - hw, vp.X / 2))
	local cy = math.clamp(ay, math.min(inset.Y + hh, vp.Y / 2), math.max(vp.Y - hh, vp.Y / 2))
	Main.Position = UDim2.fromOffset(cx, cy)
end

local bg = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ImageTransparency = .35, ZIndex = 1 }, Main)
cr(bg, 20)
local ov = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = .3, BorderSizePixel = 0, ZIndex = 2 }, Main)
cr(ov, 20)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(30, 30, 30), Color3.fromRGB(5, 5, 5)), Rotation = 60 }, ov)
local plr = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, ClipsDescendants = true }, Main)
local UI = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, Main)

-- background image (downloaded locally, falls back to gradient if executor can't)
task.spawn(function()
	pcall(function()
		if makefolder then pcall(makefolder, "SefFtap") end
		if not (isfile and isfile(BG_FILE)) then
			local req = request or http_request or (syn and syn.request)
			local body
			if req then
				local r = req({ Url = BG_URL, Method = "GET" })
				body = r and r.Body
			end
			if not body then body = game:HttpGet(BG_URL) end
			if body and #body > 1000 then writefile(BG_FILE, body) end
		end
		if isfile and isfile(BG_FILE) and getcustomasset then
			bg.Image = getcustomasset(BG_FILE)
		end
	end)
end)

-- header
local header = new("Frame", { Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -140, 0, 44), BackgroundTransparency = 1 }, UI)
new("TextLabel", { Text = "Sef's Ftap Visuals", Font = Enum.Font.GothamBlack, TextSize = 19, TextColor3 = Color3.fromRGB(240, 240, 240), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24) }, header)
local subtitle = new("TextLabel", { Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(160, 160, 160), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16) }, header)
local closeBtn = new("TextButton", { Text = "-", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(230, 230, 230), BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = .2, AutoButtonColor = false, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -44, 0, 16) }, UI)
cr(closeBtn, 15)
new("TextLabel", { Text = "script made by Sef | Tiktok: Sef.goat", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(165, 165, 165), BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -8), Size = UDim2.new(1, -100, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, TextXAlignment = Enum.TextXAlignment.Right }, UI)

-- search box
local RowsReg, curTab, searchBox, applySearch = {}, nil, nil, nil
searchBox = new("TextBox", { PlaceholderText = "Search this tab...", Text = "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(235, 235, 235), PlaceholderColor3 = Color3.fromRGB(130, 130, 130), BackgroundColor3 = Color3.fromRGB(28, 28, 28), BackgroundTransparency = .2, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(160, 28), Position = UDim2.new(1, -212, 0, 16) }, UI)
cr(searchBox, 14)
new("UIPadding", { PaddingLeft = UDim.new(0, 30) }, searchBox)
searchBox:GetPropertyChangedSignal("Text"):Connect(function() applySearch() end)

-- sidebar
local sidebar = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0, 54, 1, -28), BackgroundColor3 = Color3.fromRGB(20, 20, 20), BackgroundTransparency = .1 }, UI)
cr(sidebar, 27)
new("UIStroke", { Color = Color3.fromRGB(190, 190, 190), Transparency = .85 }, sidebar)
new("TextLabel", { Text = "S", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4) }, sidebar)
new("Frame", { Size = UDim2.new(.6, 0, 0, 1), Position = UDim2.new(.2, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(120, 120, 120), BackgroundTransparency = .6, BorderSizePixel = 0 }, sidebar)
local tabList = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, tabList)

-- icon sheet (cropped from your icon templates, embedded)
local ICON_B64 = "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"
local function b64dec(d)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local map = {}
	for i = 1, 64 do map[chars:sub(i, i)] = i - 1 end
	local out, acc, bits = {}, 0, 0
	for i = 1, #d do
		local v = map[d:sub(i, i)]
		if v then
			acc = acc * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local b = math.floor(acc / 2 ^ bits)
				acc = acc % (2 ^ bits)
				out[#out + 1] = string.char(b)
			end
		end
	end
	return table.concat(out)
end
local iconAsset
pcall(function()
	if makefolder then pcall(makefolder, "SefFtap") end
	writefile("SefFtap/icons3.png", b64dec(ICON_B64))
	iconAsset = getcustomasset("SefFtap/icons3.png")
end)

local Tabs, P = {}, nil
function applySearch()
	if not curTab or not searchBox then return end
	local q = searchBox.Text:lower()
	for _, e in ipairs(RowsReg[curTab.page] or {}) do
		if q == "" then e.r.Visible = true
		elseif e.hdr then e.r.Visible = false
		else e.r.Visible = e.t:find(q, 1, true) ~= nil end
	end
end
local function selectTab(t)
	curTab = t
	for _, x in ipairs(Tabs) do
		local on = x == t
		x.page.Visible = on
		if on and S.ui_anim ~= false then
			x.page.Position = UDim2.fromOffset(84, 72)
			tw(x.page, .28, { Position = UDim2.fromOffset(84, 60) })
		end
		tw(x.btn, .2, { BackgroundTransparency = on and 0 or 1 })
		x.ind.Visible = on
	end
	subtitle.Text = t.name
	applySearch()
end
local function tab(name, icon)
	local page = new("ScrollingFrame", { Position = UDim2.fromOffset(84, 60), Size = UDim2.new(1, -100, 1, -92), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, UI)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, page)
	local btn = new("TextButton", { Text = iconAsset and "" or tostring(icon), TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Size = UDim2.fromOffset(UIS.TouchEnabled and 38 or 32, UIS.TouchEnabled and 38 or 32), BackgroundColor3 = Color3.fromRGB(52, 52, 52), BackgroundTransparency = 1, LayoutOrder = (type(icon) == "number") and icon or 99 }, tabList)
	cr(btn, 16)
	if iconAsset and type(icon) == "number" then
		local ix, iy = ((icon - 1) % 5) * 64, math.floor((icon - 1) / 5) * 64
		new("ImageLabel", { BackgroundTransparency = 1, Image = iconAsset, ImageRectOffset = Vector2.new(ix, iy), ImageRectSize = Vector2.new(64, 64), Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(6, 6), ImageColor3 = Color3.fromRGB(235, 235, 235) }, btn)
	end
	local ind = new("Frame", { Size = UDim2.fromOffset(3, 16), Position = UDim2.fromOffset(-10, 8), BackgroundColor3 = S.accent, BorderSizePixel = 0, Visible = false }, btn)
	cr(ind, 2)
	RF[#RF + 1] = function() ind.BackgroundColor3 = S.accent end
	local t = { name = name, page = page, btn = btn, ind = ind }
	Tabs[#Tabs + 1] = t
	if #Tabs == 1 then curTab = t page.Visible = true btn.BackgroundTransparency = 0 ind.Visible = true subtitle.Text = name end -- first tab visible even if a later step fails
	btn.MouseButton1Click:Connect(function() selectTab(t) end)
	btn.MouseEnter:Connect(function() if not page.Visible then tw(btn, .15, { BackgroundTransparency = .6 }) end end)
	btn.MouseLeave:Connect(function() if not page.Visible then tw(btn, .15, { BackgroundTransparency = 1 }) end end)
	P = page
	return t
end

if iconAsset then
	new("ImageLabel", { BackgroundTransparency = 1, Image = iconAsset, ImageRectOffset = Vector2.new(2 * 64, 3 * 64), ImageRectSize = Vector2.new(64, 64), Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(8, 6), ImageColor3 = Color3.fromRGB(170, 170, 170) }, searchBox)
end

-- control building blocks
local function row(h)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Color3.fromRGB(26, 26, 26), BackgroundTransparency = .3, BorderSizePixel = 0, ClipsDescendants = true }, P)
	cr(r, 10)
	new("UIStroke", { Color = Color3.fromRGB(150, 150, 150), Transparency = .88 }, r)
	local reg = RowsReg[P]
	if not reg then reg = {} RowsReg[P] = reg end
	reg[#reg + 1] = { r = r, t = "" }
	return r
end
local function nameRow(r, t)
	local reg = RowsReg[P]
	for i = #reg, 1, -1 do if reg[i].r == r then reg[i].t = t:lower() break end end
end
local function lab(r, t)
	nameRow(r, t)
	return new("TextLabel", { Text = t, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(230, 230, 230), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(.62, -12, 0, 36) }, r)
end
local function H(title)
	local r = new("TextLabel", { Text = "  " .. title:upper(), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(150, 150, 150), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22) }, P)
	local reg = RowsReg[P]
	if not reg then reg = {} RowsReg[P] = reg end
	reg[#reg + 1] = { r = r, t = "", hdr = true }
end
local function usePage(name) P = L.tabs[name].page end
local OFFC = Color3.fromRGB(58, 58, 58)
local Active = nil
C(UIS.InputChanged, function(i)
	if Active and (i == Active.inp or i.UserInputType == Enum.UserInputType.MouseMovement) then Active.move(i.Position) end
end)
C(UIS.InputEnded, function(i)
	if Active and (i == Active.inp or (i.UserInputType == Enum.UserInputType.MouseButton1 and Active.inp.UserInputType == Enum.UserInputType.MouseButton1)) then
		local a = Active
		Active = nil
		if a.done then a.done() end
	end
end)
local function makeDraggable(handle, target, onClick)
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			local st, sp, moved = i.Position, target.Position, false
			Active = { inp = i, move = function(p)
				local d = p - st
				if d.Magnitude > 8 then moved = true end
				if moved then target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end
			end, done = function() if not moved and onClick then onClick() end end }
		end
	end)
end

local function bar(parent, y, onchg, plain)
	local pg = P
	local track = new("Frame", { Position = UDim2.new(0, 12, 0, y), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = Color3.fromRGB(58, 58, 58), BorderSizePixel = 0 }, parent)
	cr(track, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = S.accent, BackgroundTransparency = plain and 1 or 0, BorderSizePixel = 0 }, track)
	cr(fill, 3)
	local knob = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(13, 13), Position = UDim2.fromScale(1, .5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, fill)
	cr(knob, 7)
	new("UIStroke", { Color = Color3.fromRGB(20, 20, 20), Thickness = 1.5 }, knob)
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -9), Size = UDim2.new(1, 0, 0, 24) }, track)
	local function upd(x)
		local v = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		fill.Size = UDim2.fromScale(v, 1)
		onchg(v)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			pg.ScrollingEnabled = false
			upd(i.Position.X)
			Active = { inp = i, move = function(p) upd(p.X) end, done = function() pg.ScrollingEnabled = true end }
		end
	end)
	if not plain then RF[#RF + 1] = function() fill.BackgroundColor3 = S.accent end end
	return { track = track, set = function(v) fill.Size = UDim2.fromScale(math.clamp(v, 0, 1), 1) end }
end

local function T(name, key, def, cb)
	FEATURES = FEATURES + 1
	L.names[key] = name
	S[key] = def
	local r = row(36)
	lab(r, name)
	local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, .5, -10), BackgroundColor3 = OFFC }, r)
	cr(sw, 10)
	local kn = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(200, 200, 200) }, sw)
	cr(kn, 7)
	local function paint(v)
		tw(sw, .18, { BackgroundColor3 = v and S.accent or OFFC })
		tw(kn, .18, { Position = v and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = v and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(200, 200, 200) })
	end
	local function set(v, silent)
		S[key] = v
		paint(v)
		if not silent then fire(cb, v) end
	end
	Ctl[key] = { set = set }
	RF[#RF + 1] = function() paint(S[key]) end
	sw.MouseButton1Click:Connect(function() set(not S[key]) end)
	paint(def)
end

local function SL(name, key, min, max, def, dec, cb)
	FEATURES = FEATURES + 1
	dec = dec or 0
	S[key] = def
	local r = row(52)
	lab(r, name)
	local val = new("TextLabel", { Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(170, 170, 170), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -92, 0, 0), Size = UDim2.fromOffset(80, 36), Text = "" }, r)
	local m = 10 ^ dec
	local b
	local function show(v) val.Text = (dec == 0) and tostring(math.floor(v + .5)) or string.format("%." .. dec .. "f", v) end
	b = bar(r, 40, function(x)
		local v = min + (max - min) * x
		v = math.floor(v * m + .5) / m
		S[key] = v
		show(v)
		fire(cb, v)
	end)
	local function set(v, silent)
		v = math.clamp(v, min, max)
		S[key] = v
		b.set((v - min) / (max - min))
		show(v)
		if not silent then fire(cb, v) end
	end
	Ctl[key] = { set = set }
	set(def, true)
end

local function CO(name, key, def, cb)
	FEATURES = FEATURES + 1
	S[key] = def
	local r = row(36)
	lab(r, name)
	local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0, 8), BackgroundColor3 = def }, r)
	cr(sw, 6)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = .6 }, sw)
	local h, s, v = def:ToHSV()
	local bh, bs, bv
	local pg = P
	local function grad()
		if bs then
			local g1 = bs.track:FindFirstChildOfClass("UIGradient")
			if g1 then g1.Color = ColorSequence.new(Color3.new(1, 1, 1), hsv(h, 1, 1)) end
			local g2 = bv.track:FindFirstChildOfClass("UIGradient")
			if g2 then g2.Color = ColorSequence.new(Color3.new(0, 0, 0), hsv(h, s, 1)) end
		end
	end
	local function apply(silent)
		local c = Color3.fromHSV(h, s, v)
		S[key] = c
		sw.BackgroundColor3 = c
		grad()
		if not silent then fire(cb, c) end
	end
	local function build()
		if bh then return end
		local keep = P
		P = pg
		bh = bar(r, 52, function(x) h = x apply() end, true)
		bs = bar(r, 70, function(x) s = x apply() end, true)
		bv = bar(r, 88, function(x) v = x apply() end, true)
		P = keep
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hsv(0)), ColorSequenceKeypoint.new(.17, hsv(.17)), ColorSequenceKeypoint.new(.33, hsv(.33)), ColorSequenceKeypoint.new(.5, hsv(.5)), ColorSequenceKeypoint.new(.67, hsv(.67)), ColorSequenceKeypoint.new(.83, hsv(.83)), ColorSequenceKeypoint.new(1, hsv(.999)) }) }, bh.track)
		new("UIGradient", {}, bs.track)
		new("UIGradient", {}, bv.track)
		bh.track.BackgroundColor3 = Color3.new(1, 1, 1)
		bs.track.BackgroundColor3 = Color3.new(1, 1, 1)
		bv.track.BackgroundColor3 = Color3.new(1, 1, 1)
		bh.set(h) bs.set(s) bv.set(v)
		grad()
	end
	local function set(c, silent)
		h, s, v = c:ToHSV()
		if bh then bh.set(h) bs.set(s) bv.set(v) end
		apply(silent)
	end
	Ctl[key] = { set = set }
	local open = false
	sw.MouseButton1Click:Connect(function()
		open = not open
		if open then build() end
		tw(r, .25, { Size = UDim2.new(1, 0, 0, open and 108 or 36) })
	end)
end

local function DD(name, key, opts, def, cb)
	FEATURES = FEATURES + 1
	S[key] = def
	local r = row(36)
	lab(r, name)
	local btn = new("TextButton", { Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(235, 235, 235), AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(46, 46, 46), Size = UDim2.fromOffset(140, 24), Position = UDim2.new(1, -152, .5, -12) }, r)
	cr(btn, 8)
	local function set(v, silent)
		S[key] = v
		btn.Text = tostring(v) .. "  >"
		if not silent then fire(cb, v) end
	end
	Ctl[key] = { set = set }
	btn.MouseButton1Click:Connect(function()
		local idx = 1
		for i, o in ipairs(opts) do if o == S[key] then idx = i end end
		set(opts[idx % #opts + 1])
		tw(btn, .1, { BackgroundColor3 = Color3.fromRGB(80, 80, 80) })
		task.delay(.12, function() tw(btn, .2, { BackgroundColor3 = Color3.fromRGB(46, 46, 46) }) end)
	end)
	set(def, true)
end

local function PK(name, key, opts, def, cb)
	FEATURES = FEATURES + 1
	S[key] = def
	local r = row(40)
	lab(r, name)
	local g = new("Frame", { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 10), BackgroundTransparency = 1 }, r)
	new("UIGridLayout", { CellSize = UDim2.new(.5, -4, 0, 26), CellPadding = UDim2.fromOffset(6, 5), SortOrder = Enum.SortOrder.LayoutOrder }, g)
	local chips = {}
	local function paint()
		for o, b in pairs(chips) do
			local on = (o == S[key])
			b.BackgroundColor3 = on and S.accent or Color3.fromRGB(44, 44, 44)
			b.TextColor3 = on and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(225, 225, 225)
		end
	end
	local function set(v, silent)
		S[key] = v
		paint()
		if not silent then fire(cb, v) end
	end
	local function build()
		for _, b in pairs(chips) do b:Destroy() end
		chips = {}
		for i, o in ipairs(opts) do
			local b = new("TextButton", { Text = tostring(o), Font = Enum.Font.GothamMedium, TextSize = 11, AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(44, 44, 44), TextColor3 = Color3.fromRGB(225, 225, 225), LayoutOrder = i, TextTruncate = Enum.TextTruncate.AtEnd }, g)
			cr(b, 8)
			b.MouseButton1Click:Connect(function() set(o) end)
			chips[o] = b
		end
		local rows = math.ceil(#opts / 2)
		local h = rows * 26 + math.max(0, rows - 1) * 5
		g.Size = UDim2.new(1, -20, 0, h)
		r.Size = UDim2.new(1, 0, 0, 44 + h)
		paint()
	end
	Ctl[key] = { set = set, refresh = build }
	RF[#RF + 1] = paint
	build()
end

local function B(name, cb)
	FEATURES = FEATURES + 1
	local r = row(34)
	nameRow(r, name)
	local b = new("TextButton", { Text = name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(235, 235, 235), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, r)
	b.MouseButton1Click:Connect(function()
		tw(r, .08, { BackgroundColor3 = Color3.fromRGB(90, 90, 90) })
		task.delay(.1, function() tw(r, .25, { BackgroundColor3 = Color3.fromRGB(26, 26, 26) }) end)
		fire(cb)
	end)
end

local function KB(name, key, def)
	FEATURES = FEATURES + 1
	S[key] = def
	local r = row(36)
	lab(r, name)
	local btn = new("TextButton", { Text = def.Name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(235, 235, 235), AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(46, 46, 46), Size = UDim2.fromOffset(100, 24), Position = UDim2.new(1, -112, .5, -12) }, r)
	cr(btn, 8)
	local function set(k) S[key] = k btn.Text = k.Name end
	Ctl[key] = { set = set }
	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "press key..."
		local con
		con = UIS.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Keyboard then
				if i.KeyCode ~= Enum.KeyCode.Escape then set(i.KeyCode) else btn.Text = S[key].Name end
				con:Disconnect()
				task.defer(function() listening = false end)
			end
		end)
	end)
end

local function IN(name, key, def, cb)
	FEATURES = FEATURES + 1
	S[key] = def
	local r = row(36)
	lab(r, name)
	local tb = new("TextBox", { Text = def, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(235, 235, 235), BackgroundColor3 = Color3.fromRGB(46, 46, 46), Size = UDim2.fromOffset(150, 24), Position = UDim2.new(1, -162, .5, -12), ClearTextOnFocus = false }, r)
	cr(tb, 8)
	tb.ClipsDescendants = true
	tb.TextXAlignment = Enum.TextXAlignment.Left
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, tb)
	Ctl[key] = { set = function(v, silent) tb.Text = tostring(v) S[key] = tostring(v) if not silent then fire(cb, tostring(v)) end end }
	tb.FocusLost:Connect(function() S[key] = tb.Text fire(cb, tb.Text) end)
end

local PALETTE = { "#FFFFFF", "#C8C8C8", "#808080", "#1A1A1A", "#FF3B3B", "#FF8A1F", "#FFD21F", "#B6FF1F", "#2BFF6A", "#1FFFD2", "#1FB6FF", "#3B5BFF", "#8A3BFF", "#D13BFF", "#FF3BB6", "#FF7A9C", "#8B5A2B", "#F5DEB3" }
local function hex(h) h = h:gsub("#", "") return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end
local function PAL(name, target)
	FEATURES = FEATURES + 1
	local r = row(92)
	lab(r, name)
	local g = new("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 52), BackgroundTransparency = 1 }, r)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(26, 22), CellPadding = UDim2.fromOffset(5, 5) }, g)
	for _, h in ipairs(PALETTE) do
		local c = hex(h)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = c }, g)
		cr(b, 6)
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = .7 }, b)
		b.MouseButton1Click:Connect(function() Ctl[target].set(c) end)
	end
end

----------------------------------------------------------------------
-- LOGIC
----------------------------------------------------------------------
-- fx folder (client-only parts live under the camera)
local fxFolder = new("Folder", { Name = "SefFX" }, cam())

-- lighting snapshot
local LMAP = { lt_br = "Brightness", lt_clock = "ClockTime", lt_amb = "Ambient", lt_outamb = "OutdoorAmbient", lt_exp = "ExposureCompensation", lt_soft = "ShadowSoftness", lt_fogs = "FogStart", lt_foge = "FogEnd", lt_fogc = "FogColor", lt_top = "ColorShift_Top", lt_bot = "ColorShift_Bottom", lt_diff = "EnvironmentDiffuseScale", lt_spec = "EnvironmentSpecularScale" }
local orig = {}
for _, p in pairs(LMAP) do pcall(function() orig[p] = Lighting[p] end) end
pcall(function() orig.GlobalShadows = Lighting.GlobalShadows end)
local function setL(p, v) pcall(function() Lighting[p] = v end) end

-- effects
local FX = {}
local function mkfx(class, name)
	local o = new(class, { Name = "Sef" .. name, Enabled = false }, Lighting)
	FX[name] = o
	return o
end
mkfx("BloomEffect", "Bloom")
mkfx("ColorCorrectionEffect", "CC")
mkfx("BlurEffect", "Blur")
mkfx("SunRaysEffect", "Rays")
mkfx("DepthOfFieldEffect", "DOF")

function L.fx()
	pcall(function()
		FX.Bloom.Enabled = S.bloom_on FX.Bloom.Intensity = S.bloom_i FX.Bloom.Size = S.bloom_s FX.Bloom.Threshold = S.bloom_t
		local c = FX.CC
		c.Enabled = S.cc_on or S.gray or S.night or S.sepia
		c.Brightness = S.cc_br c.Contrast = S.cc_ct
		c.Saturation = S.gray and -1 or (S.sepia and -.4 or S.cc_sat)
		c.TintColor = S.night and Color3.fromRGB(120, 255, 140) or (S.sepia and Color3.fromRGB(255, 225, 180) or (S.cc_on and S.cc_tint or Color3.new(1, 1, 1)))
		FX.Blur.Enabled = S.blur_on FX.Blur.Size = S.blur_s
		FX.Rays.Enabled = S.rays_on FX.Rays.Intensity = S.rays_i FX.Rays.Spread = S.rays_s
		FX.DOF.Enabled = S.dof_on FX.DOF.FocusDistance = S.dof_f FX.DOF.FarIntensity = S.dof_far FX.DOF.InFocusRadius = S.dof_r FX.DOF.NearIntensity = 0
	end)
end

-- atmosphere / sky / clouds
local atmos
function L.atmos()
	if S.at_on then
		if not atmos then atmos = new("Atmosphere", { Name = "SefAtmos" }, Lighting) end
		atmos.Parent = Lighting
		atmos.Density = S.at_den atmos.Offset = S.at_off atmos.Color = S.at_col atmos.Decay = S.at_dec atmos.Glare = S.at_gl atmos.Haze = S.at_hz
	elseif atmos then
		atmos.Parent = nil
	end
end
local function getSky()
	local s = Lighting:FindFirstChildOfClass("Sky")
	if not s then s = new("Sky", { Name = "SefSky" }, Lighting) end
	return s
end
L.getSky = getSky
function L.sky()
	pcall(function()
		local s = getSky()
		s.StarCount = S.sky_stars s.SunAngularSize = S.sky_sun s.MoonAngularSize = S.sky_moon
		s.CelestialBodiesShown = S.sky_cel
		s.SkyboxOrientation = Vector3.new(S.sk_tx or 0, S.sky_rot, S.sk_tz or 0)
	end)
end
function L.clouds()
	pcall(function()
		local c = workspace.Terrain:FindFirstChildOfClass("Clouds") or new("Clouds", {}, workspace.Terrain)
		c.Enabled = S.cl_on c.Cover = S.cl_cover c.Density = S.cl_den c.Color = S.cl_col
	end)
end

-- weather (client-only emitters following the camera)
local weather = new("Part", { Name = "SefWeather", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(70, 1, 70) }, fxFolder)
local snow = new("ParticleEmitter", { Name = "Snow", Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(4, 8), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(20, 20), LightEmission = .6, Size = NumberSequence.new(.35), Transparency = NumberSequence.new(0, 1), Acceleration = Vector3.new(0, -2, 0), Enabled = false }, weather)
local rain = new("ParticleEmitter", { Name = "Rain", Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, Lifetime = NumberRange.new(1.6, 2), Speed = NumberRange.new(70, 90), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(4, 4), LightEmission = .3, Size = NumberSequence.new(.25), Transparency = NumberSequence.new(.35, .6), Orientation = Enum.ParticleOrientation.VelocityParallel, Enabled = false }, weather)
function L.weather()
	snow.Enabled = S.snow_on snow.Rate = S.snow_rate snow.Color = ColorSequence.new(S.snow_col)
	rain.Enabled = S.rain_on rain.Rate = S.rain_rate rain.Color = ColorSequence.new(S.rain_col)
end

-- lighting presets / reset
local LPRE = {
	Night = { lt_clock = 0, lt_br = 1, lt_amb = Color3.fromRGB(35, 40, 80), lt_outamb = Color3.fromRGB(40, 45, 90), lt_exp = 0 },
	Sunset = { lt_clock = 17.7, lt_br = 2.5, lt_amb = Color3.fromRGB(150, 80, 70), lt_outamb = Color3.fromRGB(200, 110, 80), lt_top = Color3.fromRGB(255, 140, 60) },
	Vaporwave = { lt_clock = 20, lt_amb = Color3.fromRGB(140, 60, 200), lt_outamb = Color3.fromRGB(200, 70, 220), lt_top = Color3.fromRGB(255, 80, 200), lt_bot = Color3.fromRGB(60, 180, 255) },
	["Foggy Gray"] = { lt_clock = 12, lt_amb = Color3.fromRGB(110, 110, 110), lt_outamb = Color3.fromRGB(130, 130, 130), lt_fogc = Color3.fromRGB(150, 150, 150), lt_fogs = 0, lt_foge = 400 },
	["Cold Blue"] = { lt_clock = 4, lt_amb = Color3.fromRGB(60, 90, 150), lt_outamb = Color3.fromRGB(80, 120, 190), lt_top = Color3.fromRGB(120, 190, 255) },
	["Neon Purple"] = { lt_clock = 0, lt_br = 2, lt_amb = Color3.fromRGB(110, 30, 170), lt_outamb = Color3.fromRGB(150, 40, 220), lt_fogc = Color3.fromRGB(90, 20, 140), lt_fogs = 0, lt_foge = 700 },
	Sunrise = { lt_clock = 6, lt_br = 2, lt_amb = Color3.fromRGB(170, 110, 90), lt_outamb = Color3.fromRGB(220, 150, 110), lt_top = Color3.fromRGB(255, 170, 100) },
	["Golden Hour"] = { lt_clock = 17.4, lt_br = 3, lt_amb = Color3.fromRGB(190, 140, 70), lt_outamb = Color3.fromRGB(230, 170, 80), lt_top = Color3.fromRGB(255, 200, 100) },
	["Midnight Blue"] = { lt_clock = 0, lt_br = .6, lt_amb = Color3.fromRGB(20, 30, 70), lt_outamb = Color3.fromRGB(25, 40, 95), lt_bot = Color3.fromRGB(40, 70, 160) },
	["Toxic Green"] = { lt_clock = 22, lt_amb = Color3.fromRGB(40, 140, 50), lt_outamb = Color3.fromRGB(60, 190, 70), lt_fogc = Color3.fromRGB(40, 110, 40), lt_fogs = 0, lt_foge = 500 },
	["Blood Moon"] = { lt_clock = 0, lt_br = 1, lt_amb = Color3.fromRGB(120, 25, 25), lt_outamb = Color3.fromRGB(160, 35, 35), lt_fogc = Color3.fromRGB(90, 10, 10), lt_fogs = 0, lt_foge = 600 },
	["Cotton Candy"] = { lt_clock = 14, lt_amb = Color3.fromRGB(200, 150, 210), lt_outamb = Color3.fromRGB(240, 170, 220), lt_top = Color3.fromRGB(255, 190, 240), lt_bot = Color3.fromRGB(170, 220, 255) },
	Ocean = { lt_clock = 12, lt_amb = Color3.fromRGB(50, 120, 160), lt_outamb = Color3.fromRGB(70, 150, 200), lt_fogc = Color3.fromRGB(60, 140, 190), lt_fogs = 0, lt_foge = 900 },
	Desert = { lt_clock = 13, lt_br = 3, lt_amb = Color3.fromRGB(200, 160, 100), lt_outamb = Color3.fromRGB(230, 190, 120), lt_top = Color3.fromRGB(255, 220, 140) },
	Arctic = { lt_clock = 11, lt_amb = Color3.fromRGB(150, 180, 210), lt_outamb = Color3.fromRGB(190, 220, 245), lt_fogc = Color3.fromRGB(200, 225, 245), lt_fogs = 0, lt_foge = 700 },
	Void = { lt_clock = 0, lt_br = 0, lt_amb = Color3.fromRGB(5, 5, 8), lt_outamb = Color3.fromRGB(8, 8, 14), lt_fogc = Color3.fromRGB(0, 0, 0), lt_fogs = 0, lt_foge = 250 },
	["Retro Orange"] = { lt_clock = 18.5, lt_amb = Color3.fromRGB(190, 100, 40), lt_outamb = Color3.fromRGB(230, 120, 40), lt_top = Color3.fromRGB(255, 130, 40), lt_bot = Color3.fromRGB(120, 40, 140) },
}
function L.resetLighting()
	for k, p in pairs(LMAP) do
		if orig[p] ~= nil and Ctl[k] then Ctl[k].set(orig[p], true) setL(p, orig[p]) end
	end
	setL("GlobalShadows", orig.GlobalShadows)
	for _, k in ipairs({ "fullb", "nofog" }) do if Ctl[k] then Ctl[k].set(false, true) end end
end

-- camera
local camState = { default = cam().FieldOfView, rest = false }
function L.fixCam(now)
	pcall(function()
		local c = cam()
		if c.CameraType ~= Enum.CameraType.Custom then c.CameraType = Enum.CameraType.Custom end
		local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if hum and c.CameraSubject ~= hum then c.CameraSubject = hum end
		LP.CameraMode = Enum.CameraMode.Classic
		LP.CameraMaxZoomDistance = S.maxzoom
		LP.CameraMinZoomDistance = math.min(S.minzoom, S.maxzoom)
		LP.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
		if now then c.FieldOfView = S.fov_on and S.fov or camState.default end
	end)
end
function L.fovReset() camState.rest = true end

local function camStep(dt)
	local c = cam()
	if not c then return end
	if L.kApplied ~= 0 then c.FieldOfView = c.FieldOfView - L.kApplied L.kApplied = 0 end
	local t = tick() - T0
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local speed = hrp and hrp.AssemblyLinearVelocity.Magnitude or 0
	local active = S.fov_on or (S.zoom_on and zoomHeld) or S.spdfov_on
	if active or camState.rest then
		local tgt = camState.default
		if active then
			tgt = S.fov_on and S.fov or camState.default
			if S.spdfov_on then tgt = tgt + math.clamp(speed / 100, 0, 1) * S.spdfov end
			if S.zoom_on and zoomHeld then tgt = S.zoom_fov end
		end
		c.FieldOfView = S.fov_smooth and (c.FieldOfView + (tgt - c.FieldOfView) * math.min(1, dt * 10)) or tgt
		camState.rest = active or math.abs(c.FieldOfView - camState.default) > .1
	end
	if L.kick ~= 0 then
		c.FieldOfView = c.FieldOfView + L.kick
		L.kApplied = L.kick
		L.kick = L.kick * (1 - math.min(1, dt * 6))
		if math.abs(L.kick) < .05 then L.kick = 0 end
	end
	local cf = c.CFrame
	if S.offx ~= 0 or S.offy ~= 0 or S.offz ~= 0 then cf = cf * CFrame.new(S.offx, S.offy, S.offz) end
	if S.roll ~= 0 then cf = cf * CFrame.Angles(0, 0, math.rad(S.roll)) end
	if S.bob_on and speed > 4 then
		cf = cf * CFrame.new(0, math.sin(t * 9) * .12 * S.bob, 0) * CFrame.Angles(0, 0, math.sin(t * 4.5) * .01 * S.bob)
	end
	local amt = (S.shk_on and S.shk_amt or 0) + shk
	if amt > 0 then
		cf = cf * CFrame.new((math.random() - .5) * amt, (math.random() - .5) * amt, 0)
		shk = math.max(0, shk - dt * 2.2)
	end
	if S.str_on then cf = cf * CFrame.new(0, 0, 0, S.strx, 0, 0, 0, S.stry, 0, 0, 0, 1) end
	c.CFrame = cf
end

-- HUD overlays
local statsLbl = new("TextLabel", { Position = UDim2.fromOffset(12, 64), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = .4, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Text = "" }, hud)
cr(statsLbl, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, statsLbl)
local wm = new("TextLabel", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 8), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Color3.fromRGB(12, 12, 12), BackgroundTransparency = .25, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13, Visible = false, Text = "Sef's Ftap Visuals" }, hud)
cr(wm, 12)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, wm)
local barT = new("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, ZIndex = 5 }, hud)
local barB = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, ZIndex = 5 }, hud)
function L.bars()
	barT.Visible = S.bars_on barB.Visible = S.bars_on
	barT.Size = UDim2.fromScale(1, S.bars_sz) barB.Size = UDim2.fromScale(1, S.bars_sz)
end
local vig = {}
local function vedge(ap, pos, size, rot)
	local f = new("Frame", { AnchorPoint = ap, Position = pos, Size = size, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, ZIndex = 2 }, hud)
	local g = new("UIGradient", { Rotation = rot }, f)
	vig[#vig + 1] = { f = f, g = g }
end
vedge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(.24, 1), 0)
vedge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(.24, 1), 180)
vedge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, .3), 90)
vedge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, .3), 270)
function L.vig()
	for _, e in ipairs(vig) do
		e.f.Visible = S.vig_on
		e.f.BackgroundColor3 = S.vig_col
		e.g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - S.vig_str), NumberSequenceKeypoint.new(1, 1) })
	end
end
local flashF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9 }, hud)

local xh = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, Visible = false, ZIndex = 6 }, hud)
function L.xhair()
	for _, c in ipairs(xh:GetChildren()) do c:Destroy() end
	xh.Visible = S.xh_on
	if not S.xh_on then return end
	local sz, th, gap, col, st = S.xh_size, S.xh_th, S.xh_gap, S.xh_col, S.xh_style
	local function xb(x, y, w, h) new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, x, .5, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = col, BorderSizePixel = 0 }, xh) end
	if st == "Cross" or st == "X" then
		xb(0, -(gap + sz / 2), th, sz) xb(0, gap + sz / 2, th, sz) xb(-(gap + sz / 2), 0, sz, th) xb(gap + sz / 2, 0, sz, th)
	elseif st == "Dot" then
		local d = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = col, BorderSizePixel = 0 }, xh)
		cr(d, sz)
	else
		local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(sz * 2, sz * 2), BackgroundTransparency = 1 }, xh)
		cr(f, sz)
		new("UIStroke", { Color = col, Thickness = th }, f)
	end
	xh.Rotation = (st == "X") and 45 or 0
end

local function ping()
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	return ok and math.floor(v) or 0
end
local fps, hudAcc, sessionStart = 60, 0, tick()
function L.hudStep(dt)
	fps = fps + ((1 / math.max(dt, 1e-4)) - fps) * .1
	hudAcc = hudAcc + dt
	if hudAcc < .25 then return end
	hudAcc = 0
	local fs = L.fling
	local lines = {}
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if S.h_fps then lines[#lines + 1] = "FPS     " .. math.floor(fps) end
	if S.h_ping then lines[#lines + 1] = "PING    " .. ping() .. " ms" end
	if S.h_clock then lines[#lines + 1] = "TIME    " .. os.date("%H:%M:%S") end
	if S.h_sess then
		local s = math.floor(tick() - sessionStart)
		lines[#lines + 1] = string.format("SESSION %02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	end
	if S.h_speed and hrp then lines[#lines + 1] = "SPEED   " .. math.floor(hrp.AssemblyLinearVelocity.Magnitude) .. " st/s" end
	if S.h_pos and hrp then local p = hrp.Position lines[#lines + 1] = string.format("POS     %d %d %d", p.X, p.Y, p.Z) end
	if S.h_toys then
		local f = workspace:FindFirstChild(LP.Name .. "SpawnedInToys")
		lines[#lines + 1] = "TOYS    " .. (f and #f:GetChildren() or 0)
	end
	if S.h_max and fs then lines[#lines + 1] = "MAX SPD " .. math.floor(fs.max) .. " st/s" end
	if S.h_fling and fs then lines[#lines + 1] = "FLINGS  " .. fs.flings end
	if S.h_air and fs then lines[#lines + 1] = string.format("AIR     %.1fs", fs.air) end
	if S.h_height and hrp then lines[#lines + 1] = "HEIGHT  " .. math.floor(hrp.Position.Y) end
	if S.h_dist and hrp and fs and fs.home then lines[#lines + 1] = "FROM SP " .. math.floor((hrp.Position - fs.home).Magnitude) end
	if S.h_grab then lines[#lines + 1] = "GRAB    " .. (workspace:FindFirstChild("GrabParts") and "HOLDING" or "-") end
	if S.h_players then lines[#lines + 1] = "PLAYERS " .. #Players:GetPlayers() end
	if S.h_mem then
		local ok, v = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
		lines[#lines + 1] = "MEMORY  " .. (ok and math.floor(v) or 0) .. " MB"
	end
	if S.h_fov and cam() then lines[#lines + 1] = "FOV     " .. math.floor(cam().FieldOfView) end
	if S.h_cdist and cam() and hrp then lines[#lines + 1] = "CAM DST " .. math.floor((cam().CFrame.Position - hrp.Position).Magnitude) end
	statsLbl.Visible = #lines > 0
	statsLbl.Text = table.concat(lines, "\n")
	statsLbl.TextColor3 = S.h_col
	statsLbl.TextSize = S.h_size
	statsLbl.BackgroundTransparency = S.h_bgt
	statsLbl.Position = UDim2.fromOffset(S.h_x, S.h_y)
	pcall(function() statsLbl.Font = Enum.Font[S.h_font] end)
	wm.Visible = S.h_wm
	wm.TextColor3 = S.h_col
	wm.Text = "Sef's Ftap Visuals  |  " .. math.floor(fps) .. " fps"
end

-- character visuals ---------------------------------------------------
local charOrig = setmetatable({}, { __mode = "k" })
local function cap(p)
	local o = charOrig[p]
	if not o then o = { p.Color, p.Material, p.Transparency } charOrig[p] = o end
	return o
end
function L.char()
	local ch = LP.Character
	if not ch then return end
	for _, p in ipairs(ch:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local o = cap(p)
			local col, mat, tr = o[1], o[2], o[3]
			if S.ch_col_on then col = S.ch_col end
			if S.ch_neon then mat = Enum.Material.Neon end
			if S.ch_ff then mat = Enum.Material.ForceField end
			if S.ch_ghost then tr = S.ch_tr end
			if S.limb_on then
				local n = p.Name:lower()
				local lk
				if n:find("head") then lk = "head"
				elseif n:find("torso") then lk = "torso"
				elseif n:find("left") and (n:find("arm") or n:find("hand")) then lk = "larm"
				elseif n:find("right") and (n:find("arm") or n:find("hand")) then lk = "rarm"
				elseif n:find("left") and (n:find("leg") or n:find("foot")) then lk = "lleg"
				elseif n:find("right") and (n:find("leg") or n:find("foot")) then lk = "rleg" end
				if lk and S["limb_" .. lk] then col = S["limb_" .. lk] end
			end
			if S.ch_hideacc and p.Parent:IsA("Accessory") then tr = 1 end
			p.Color = col p.Material = mat p.Transparency = tr
		end
	end
	local hl = ch:FindFirstChild("SefHL")
	if S.ch_hl then
		if not hl then hl = new("Highlight", { Name = "SefHL", FillTransparency = .6 }, ch) end
		hl.FillColor = S.ch_hlc hl.OutlineColor = S.ch_hlc
	elseif hl then hl:Destroy() end
end
function L.rig()
	local ch = LP.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local tr = hrp:FindFirstChild("SefTrail")
	if S.tr_on then
		if not tr then
			local a0 = new("Attachment", { Name = "SefA0", Position = Vector3.new(0, 1, 0) }, hrp)
			local a1 = new("Attachment", { Name = "SefA1", Position = Vector3.new(0, -1, 0) }, hrp)
			tr = new("Trail", { Name = "SefTrail", Attachment0 = a0, Attachment1 = a1, LightEmission = 1, FaceCamera = true }, hrp)
		end
		tr.Color = ColorSequence.new(S.tr_col) tr.Lifetime = S.tr_life tr.Transparency = NumberSequence.new(S.tr_tr or .1, 1) tr.WidthScale = NumberSequence.new(S.tr_w or 1, 0) tr.Texture = (S.tr_tex and TEX[S.tr_tex]) or ""
	elseif tr then
		tr:Destroy()
		for _, n in ipairs({ "SefA0", "SefA1" }) do local a = hrp:FindFirstChild(n) if a then a:Destroy() end end
	end
	local au = hrp:FindFirstChild("SefAura")
	if S.aura_on then
		if not au then
			au = new("ParticleEmitter", { Name = "SefAura", Texture = "rbxasset://textures/particles/sparkles_main.dds", Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(.7, 0), LightEmission = 1, Transparency = NumberSequence.new(0, 1) }, hrp)
		end
		au.Rate = S.aura_rate au.Color = ColorSequence.new(S.aura_col)
	elseif au then au:Destroy() end
end
function L.rainbowChar(t)
	local ch = LP.Character
	if not ch then return end
	local c = hsv(t * S.ch_rs)
	for _, p in ipairs(ch:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then cap(p) p.Color = c end
	end
end

-- samurai hat + halo ------------------------------------------------------
local hat = { model = nil, parts = {} }
local HATDEF = { ["Soft Ellipsoid"] = { 3.6, .9, .55 }, Dome = { 2.8, 1.8, .45 }, ["Cone (Kasa)"] = { 3.6, 1.4, .65 }, Sphere = { 2.6, 2.6, .6 } }
function L.hat()
	if hat.model then hat.model:Destroy() hat.model = nil end
	hat.parts = {}
	if not S.hat_on then return end
	local m = new("Folder", { Name = "SefHat" }, fxFolder)
	hat.model = m
	local mat = S.hat_neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local w, th = S.hat_w, S.hat_th
	local first
	local function add(shape, size, y, tr, rot, mesh)
		local p = new("Part", { Name = "SefHatPart", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = shape, Material = mat, Color = S.hat_col, Transparency = tr, Size = size }, m)
		if mesh then new("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p) end
		hat.parts[#hat.parts + 1] = { p = p, y = y, rot = rot }
		first = first or p
	end
	local shape = S.hat_shape
	if shape == "Cone (Kasa)" then
		local n = 16
		for i = 0, n - 1 do
			local f = i / (n - 1)
			local d = w * (1 - f * .92) + .12
			add(Enum.PartType.Cylinder, Vector3.new(th / n * 1.5, d, d), f * th, S.hat_tr, true)
		end
	else
		local layers = S.hat_soft and 3 or 1
		for k = 1, layers do
			local sc = 1 + (k - 1) * .16
			local tr = math.min(.98, S.hat_tr + (k - 1) * (1 - S.hat_tr) * .35)
			if shape == "Sphere" then add(Enum.PartType.Ball, Vector3.new(w * sc, w * sc, w * sc), 0, tr, false)
			else add(Enum.PartType.Block, Vector3.new(w * sc, th * sc, w * sc), 0, tr, false, true) end
		end
	end
	if first and S.hat_glow then new("PointLight", { Color = S.hat_glowc, Range = 10, Brightness = 1, Shadows = false }, first) end
	if first and S.hat_part then
		new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 8, Lifetime = NumberRange.new(.8, 1.4), Speed = NumberRange.new(.5, 2), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(.4, 0), LightEmission = 1, Color = ColorSequence.new(S.hat_glowc), Transparency = NumberSequence.new(0, 1) }, first)
	end
end
function L.hatLive() L.hat() end
local halo = { model = nil, parts = {} }
function L.halo()
	if halo.model then halo.model:Destroy() halo.model = nil end
	halo.parts = {}
	if not S.halo_on then return end
	halo.model = new("Folder", { Name = "SefHalo" }, fxFolder)
	for i = 1, 20 do
		halo.parts[i] = new("Part", { Name = "SefHaloPart", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = S.halo_col, Size = Vector3.new(.22, .22, .22) }, halo.model)
	end
end
function L.accStep(t)
	local ch = LP.Character
	local head = ch and ch:FindFirstChild("Head")
	if not head then return end
	if hat.model then
		local bob = S.hat_bob and math.sin(t * 2) * .08 or 0
		local base = CFrame.new(head.Position + Vector3.new(0, S.hat_h + bob, 0)) * CFrame.Angles(math.rad(S.hat_tilt), 0, 0)
		for _, e in ipairs(hat.parts) do
			e.p.CFrame = base * CFrame.new(0, e.y, 0) * (e.rot and CFrame.Angles(0, 0, math.pi / 2) or CFrame.new())
		end
	end
	if halo.model then
		for i, p in ipairs(halo.parts) do
			local a = i / #halo.parts * math.pi * 2 + t * 1.5
			p.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.3, S.halo_h + math.sin(t * 2 + i) * .05, math.sin(a) * 1.3))
		end
	end
end

-- grab lines --------------------------------------------------------------
TEX = { None = "", Sparkles = "rbxasset://textures/particles/sparkles_main.dds", Smoke = "rbxasset://textures/particles/smoke_main.dds", Fire = "rbxasset://textures/particles/fire_main.dds" }
local GLP = {
	["Neon Cyan"] = { gl_c1 = Color3.fromRGB(0, 255, 255), gl_c2 = Color3.fromRGB(0, 120, 255), gl_w = .35, gl_tex = "Sparkles", gl_ts = 1.5, gl_rain = false, gl_pulse = true },
	Rainbow = { gl_rain = true, gl_w = .4, gl_tex = "None", gl_pulse = false },
	Lightning = { gl_c1 = Color3.fromRGB(255, 255, 255), gl_c2 = Color3.fromRGB(150, 200, 255), gl_w = .25, gl_tex = "Sparkles", gl_ts = 8, gl_rain = false, gl_pulse = false },
	Inferno = { gl_c1 = Color3.fromRGB(255, 210, 40), gl_c2 = Color3.fromRGB(255, 40, 0), gl_w = .5, gl_tex = "Fire", gl_ts = 3, gl_rain = false, gl_pulse = true },
	Matrix = { gl_c1 = Color3.fromRGB(0, 255, 70), gl_c2 = Color3.fromRGB(0, 90, 20), gl_w = .3, gl_tex = "None", gl_rain = false, gl_pulse = false },
	Plasma = { gl_c1 = Color3.fromRGB(200, 0, 255), gl_c2 = Color3.fromRGB(0, 150, 255), gl_w = .55, gl_tex = "Smoke", gl_ts = 2, gl_rain = false, gl_pulse = true },
	Candy = { gl_c1 = Color3.fromRGB(255, 60, 100), gl_c2 = Color3.fromRGB(255, 255, 255), gl_w = .4, gl_tex = "Sparkles", gl_ts = 4, gl_rain = false, gl_pulse = false },
	Galaxy = { gl_c1 = Color3.fromRGB(90, 0, 200), gl_c2 = Color3.fromRGB(255, 100, 220), gl_w = .45, gl_tex = "Sparkles", gl_ts = 2, gl_rain = false, gl_pulse = true },
}
local GLN = { "Neon Cyan", "Rainbow", "Lightning", "Inferno", "Matrix", "Plasma", "Candy", "Galaxy" }
function L.glPreset(n)
	local p = GLP[n] or {}
	if Ctl.gl_mode and not p.gl_mode then Ctl.gl_mode.set("Gradient", true) end
	for k, v in pairs(p) do if Ctl[k] then Ctl[k].set(v, true) end end
end
local glHidden = false
function L.grabStep(t)
	local gp = workspace:FindFirstChild("GrabParts")
	if not gp or not S.gl_on then return end
	local mode = S.gl_rain and "Rainbow" or S.gl_mode
	local c1, c2 = S.gl_c1, S.gl_c2
	local cs, tipc
	if mode == "Rainbow" then
		local h = t * S.gl_rs
		cs = ColorSequence.new({ ColorSequenceKeypoint.new(0, hsv(h)), ColorSequenceKeypoint.new(.5, hsv(h + .2)), ColorSequenceKeypoint.new(1, hsv(h + .4)) })
		tipc = hsv(h)
	elseif mode == "Solid" then cs = ColorSequence.new(c1) tipc = c1
	elseif mode == "Breathing" then
		local c = c1:Lerp(c2, (math.sin(t * 3) + 1) / 2)
		cs = ColorSequence.new(c) tipc = c
	elseif mode == "Flicker" then
		local c = (math.random() < .5) and c1 or c2
		cs = ColorSequence.new(c) tipc = c
	else cs = ColorSequence.new(c1, c2) tipc = c1 end
	local w = S.gl_w * (S.gl_pulse and (1 + .3 * math.sin(t * 8)) or 1)
	for _, b in ipairs(gp:GetDescendants()) do
		if b:IsA("Beam") then
			if b.Name ~= "SefGlow" then
				pcall(function()
					b.Color = cs
					b.Transparency = NumberSequence.new(S.gl_tr)
					if S.gl_wov then b.Width0 = w b.Width1 = w end
					b.LightEmission = S.gl_le
					b.Texture = TEX[S.gl_tex] or ""
					if S.gl_tex ~= "None" then b.TextureSpeed = S.gl_ts b.TextureLength = S.gl_tl end
					if S.gl_cov then b.CurveSize0 = S.gl_curve b.CurveSize1 = -S.gl_curve end
					if S.gl_sov then b.Segments = S.gl_seg end
					if S.gl_fc == "On" then b.FaceCamera = true elseif S.gl_fc == "Off" then b.FaceCamera = false end
					if S.gl_hide then b.Enabled = false glHidden = true elseif glHidden then b.Enabled = true end
					local g = b.Parent and b.Parent:FindFirstChild("SefGlow")
					if S.gl_glow then
						if not g then g = b:Clone() g.Name = "SefGlow" g.Parent = b.Parent end
						g.Attachment0 = b.Attachment0 g.Attachment1 = b.Attachment1
						g.Enabled = not S.gl_hide
						g.Color = ColorSequence.new(S.gl_glowc)
						g.Width0 = b.Width0 * S.gl_glowm g.Width1 = b.Width1 * S.gl_glowm
						g.Transparency = NumberSequence.new(S.gl_glowt)
						g.LightEmission = 1 g.Texture = ""
						g.CurveSize0 = b.CurveSize0 g.CurveSize1 = b.CurveSize1
						g.Segments = b.Segments g.FaceCamera = b.FaceCamera
					elseif g then g:Destroy() end
				end)
			end
		elseif S.gl_tip then
			pcall(function()
				if b:IsA("BasePart") then
					b.Color = tipc
					b.Material = Enum.Material.Neon
					if S.gl_hidetip then b.Transparency = 1 end
				elseif b:IsA("ParticleEmitter") or b:IsA("Trail") then
					b.Color = cs
				elseif b:IsA("PointLight") or b:IsA("SpotLight") then
					b.Color = tipc
				elseif b:IsA("Highlight") then
					b.FillColor = tipc b.OutlineColor = tipc
				elseif b:IsA("SelectionBox") or b:IsA("SelectionSphere") then
					b.Color3 = tipc
				elseif b:IsA("Decal") or b:IsA("Texture") then
					b.Color3 = tipc
				end
			end)
		end
	end
	if glHidden and not S.gl_hide then glHidden = false end
	local gpart = gp:FindFirstChild("GrabPart")
	if gpart and gpart:IsA("BasePart") then
		pcall(function()
			local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			local sp = gpart:FindFirstChild("SefSpark")
			if S.gl_spark and not sp then
				new("ParticleEmitter", { Name = "SefSpark", Texture = TEX.Sparkles, Rate = 40, Lifetime = NumberRange.new(.4, .8), Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(.5, 0), LightEmission = 1, Color = cs }, gpart)
			elseif sp and not S.gl_spark then sp:Destroy()
			elseif sp then sp.Color = cs end
			local lt = gpart:FindFirstChild("SefGL")
			if S.gl_tiplight then
				if not lt then lt = new("PointLight", { Name = "SefGL", Shadows = false }, gpart) end
				lt.Color = tipc lt.Range = S.gl_tlr lt.Brightness = 2
			elseif lt then lt:Destroy() end
			local g1 = gpart:FindFirstChild("SefGD")
			if S.gl_dist then
				if not g1 then
					g1 = new("BillboardGui", { Name = "SefGD", Size = UDim2.fromOffset(120, 24), AlwaysOnTop = true, StudsOffset = Vector3.new(0, 2.2, 0) }, gpart)
					new("TextLabel", { Name = "T", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextStrokeTransparency = .3 }, g1)
				end
				g1.T.TextColor3 = tipc
				g1.T.Text = hrp and (math.floor((hrp.Position - gpart.Position).Magnitude) .. " studs") or ""
			elseif g1 then g1:Destroy() end
			local g2 = gpart:FindFirstChild("SefGR")
			if S.gl_ret then
				if not g2 then
					g2 = new("BillboardGui", { Name = "SefGR", AlwaysOnTop = true }, gpart)
					local fr = new("Frame", { Name = "F", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1 }, g2)
					cr(fr, 100)
					new("UIStroke", { Thickness = 2 }, fr)
				end
				g2.Size = UDim2.fromOffset(S.gl_retsz, S.gl_retsz)
				g2.F.Size = UDim2.fromScale(1, 1)
				g2.F.UIStroke.Color = tipc
			elseif g2 then g2:Destroy() end
		end)
	end
end

-- pallets -----------------------------------------------------------------
local MATS = { Default = false, Neon = Enum.Material.Neon, Glass = Enum.Material.Glass, Ice = Enum.Material.Ice, Metal = Enum.Material.Metal, Plastic = Enum.Material.SmoothPlastic, Foil = Enum.Material.Foil, ForceField = Enum.Material.ForceField, Marble = Enum.Material.Marble }
local MATN = { "Default", "Neon", "Glass", "Ice", "Metal", "Plastic", "Foil", "ForceField", "Marble" }
local palOrig = setmetatable({}, { __mode = "k" })
local palActive, palAcc = false, 0
local function palFolders()
	local res = {}
	if S.pal_all then
		for _, c in ipairs(workspace:GetChildren()) do
			if (c:IsA("Folder") or c:IsA("Model")) and c.Name:find("SpawnedInToys") then res[#res + 1] = c end
		end
	else
		local f = workspace:FindFirstChild(LP.Name .. "SpawnedInToys")
		if f then res[1] = f end
	end
	return res
end
function L.palRestore()
	for p, o in pairs(palOrig) do
		pcall(function()
			p.Color = o.c p.Material = o.m p.Transparency = o.t p.Reflectance = o.r
			if o.tex and p:IsA("MeshPart") then p.TextureID = o.tex end
		end)
	end
	palOrig = setmetatable({}, { __mode = "k" })
	for _, f in ipairs(palFolders()) do
		for _, d in ipairs(f:GetDescendants()) do if d.Name == "SefPalHL" then d:Destroy() end end
	end
end
function L.palStep(dt, t)
	if not S.pal_on then
		if palActive then L.palRestore() palActive = false end
		return
	end
	palAcc = palAcc + dt
	if palAcc < .05 then return end
	palAcc = 0
	palActive = true
	local col = S.pal_col
	if S.pal_rain then col = hsv(t * S.pal_rs, .85, 1) elseif S.pal_pulse then col = col:Lerp(Color3.new(1, 1, 1), (math.sin(t * 4) + 1) / 4) end
	for _, f in ipairs(palFolders()) do
		for _, m in ipairs(f:GetChildren()) do
			if m.Name:lower():find("pallet") then
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then
						local o = palOrig[p]
						if not o then
							o = { c = p.Color, m = p.Material, t = p.Transparency, r = p.Reflectance, tex = p:IsA("MeshPart") and p.TextureID or nil }
							palOrig[p] = o
						end
						p.Color = col
						local mt = MATS[S.pal_mat]
						if mt then p.Material = mt end
						p.Transparency = (S.pal_tr > 0) and S.pal_tr or o.t
						p.Reflectance = S.pal_ref
						if S.pal_strip and p:IsA("MeshPart") and p.TextureID ~= "" then p.TextureID = "" end
					elseif p:IsA("SurfaceAppearance") and S.pal_strip then
						p:Destroy()
					end
				end
				local hl = m:FindFirstChild("SefPalHL")
				if S.pal_hl then
					if not hl then hl = new("Highlight", { Name = "SefPalHL", FillTransparency = .7 }, m) end
					hl.FillColor = S.pal_hlc hl.OutlineColor = S.pal_hlc
				elseif hl then hl:Destroy() end
			end
		end
	end
end

-- custom explosions -------------------------------------------------------
local function mk(shape, pos, size, color, mat)
	return new("Part", { Name = "SefFXPart", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = shape, Material = mat or Enum.Material.Neon, Color = color, Size = size, CFrame = CFrame.new(pos), Parent = fxFolder })
end
local TEXS = TEX.Sparkles
local function burst(pos, color, n, speed, life, size, tex, accel)
	local p = mk(Enum.PartType.Block, pos, Vector3.new(.2, .2, .2), Color3.new(1, 1, 1))
	p.Transparency = 1
	local e = new("ParticleEmitter", { Texture = tex or TEXS, Color = (typeof(color) == "ColorSequence") and color or ColorSequence.new(color), Rate = 0, Lifetime = NumberRange.new(life * .6, life), Speed = NumberRange.new(speed * .4, speed), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), LightEmission = 1, Acceleration = accel or Vector3.new(0, 0, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120) }, p)
	e:Emit(n)
	Debris:AddItem(p, life + 1)
end
local function sphere(pos, c, s0, s1, t)
	local p = mk(Enum.PartType.Ball, pos, Vector3.new(s0, s0, s0), c)
	p.Transparency = .15
	tw(p, t, { Size = Vector3.new(s1, s1, s1), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(p, t + .2)
end
local function ring(pos, c, s1, t, tilt)
	local p = mk(Enum.PartType.Cylinder, pos, Vector3.new(.3, 1, 1), c)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(tilt or 0, 0, math.pi / 2)
	tw(p, t, { Size = Vector3.new(.3, s1, s1), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(p, t + .2)
end
local function flash(pos, c, s, t)
	if not S.ex_flash then return end
	local p = mk(Enum.PartType.Block, pos, Vector3.new(.2, .2, .2), c)
	p.Transparency = 1
	local l = new("PointLight", { Color = c, Range = 45 * s, Brightness = 8, Shadows = false }, p)
	tw(l, t, { Brightness = 0 })
	Debris:AddItem(p, t + .2)
	local cm = cam()
	if cm and (cm.CFrame.Position - pos).Magnitude < 80 then
		flashF.BackgroundColor3 = c
		flashF.BackgroundTransparency = .75
		tw(flashF, .6, { BackgroundTransparency = 1 })
	end
end
local RAINBOWSEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, hsv(0)), ColorSequenceKeypoint.new(.2, hsv(.2)), ColorSequenceKeypoint.new(.4, hsv(.4)), ColorSequenceKeypoint.new(.6, hsv(.6)), ColorSequenceKeypoint.new(.8, hsv(.8)), ColorSequenceKeypoint.new(1, hsv(.999)) })
local EXC = {
	Nuke = { Color3.fromRGB(255, 150, 30), Color3.fromRGB(255, 60, 20) }, Shockwave = { Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 255, 255) },
	Lightning = { Color3.fromRGB(190, 220, 255), Color3.fromRGB(255, 255, 255) }, ["Black Hole"] = { Color3.fromRGB(150, 40, 255), Color3.fromRGB(20, 0, 40) },
	Confetti = { Color3.fromRGB(255, 80, 160), Color3.fromRGB(80, 220, 255) }, Sakura = { Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 220, 235) },
	["Cube Shatter"] = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 120) }, ["Ice Crystal"] = { Color3.fromRGB(150, 230, 255), Color3.fromRGB(230, 250, 255) },
}
local EXN = { "Nuke", "Shockwave", "Lightning", "Black Hole", "Confetti", "Sakura", "Cube Shatter", "Ice Crystal" }
local EX = {}
EX.Nuke = function(pos, s, c1, c2, d)
	sphere(pos, c1, 2 * s, 26 * s, d * .6)
	sphere(pos, c2, s, 16 * s, d * .5)
	ring(pos - Vector3.new(0, 1, 0), c1, 55 * s, d * .8)
	sphere(pos + Vector3.new(0, 9 * s, 0), c2, 3 * s, 14 * s, d * .9)
	burst(pos + Vector3.new(0, 6 * s, 0), c2, 45, 30 * s, d, 4 * s, TEX.Smoke)
	burst(pos, c1, 40, 40 * s, d * .8, 1.2 * s)
end
EX.Shockwave = function(pos, s, c1, c2, d)
	sphere(pos, c2, s, 10 * s, d * .3)
	for i = 1, 4 do task.delay(i * .12, function() if alive then ring(pos, i % 2 == 1 and c1 or c2, 48 * s, d * .7) end end) end
	ring(pos, c1, 30 * s, d * .6, math.rad(90))
	burst(pos, c1, 30, 35 * s, d * .7, s)
end
EX.Lightning = function(pos, s, c1, c2, d)
	sphere(pos, c2, 2 * s, 12 * s, d * .35)
	for i = 1, 16 do
		local dir = Vector3.new(math.random() - .5, math.random() - .2, math.random() - .5).Unit
		local len = (8 + math.random() * 14) * s
		local p = mk(Enum.PartType.Block, pos, Vector3.new(.3 * s, .3 * s, len), i % 2 == 0 and c1 or c2)
		p.CFrame = CFrame.lookAt(pos + dir * len / 2, pos + dir * len)
		tw(p, d * .5, { Transparency = 1, Size = Vector3.new(.05, .05, len) })
		Debris:AddItem(p, d)
	end
	burst(pos, c1, 40, 45 * s, d * .6, .8 * s)
end
EX["Black Hole"] = function(pos, s, c1, c2, d)
	local core = mk(Enum.PartType.Ball, pos, Vector3.new(14, 14, 14) * s, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	tw(core, d * .8, { Size = Vector3.new(.2, .2, .2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(core, d)
	local r = mk(Enum.PartType.Cylinder, pos, Vector3.new(.3, 36 * s, 36 * s), c1)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(.4, 0, math.pi / 2)
	tw(r, d * .8, { Size = Vector3.new(.3, 1, 1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(r, d)
	task.delay(d * .8, function() if alive then sphere(pos, c1, 2 * s, 24 * s, d * .4) burst(pos, c1, 50, 40 * s, d * .6, s) end end)
end
EX.Confetti = function(pos, s, c1, c2, d)
	burst(pos, RAINBOWSEQ, 90, 45 * s, d * 1.2, .9 * s, TEXS, Vector3.new(0, -30, 0))
	sphere(pos, c2, s, 9 * s, d * .3)
end
EX.Sakura = function(pos, s, c1, c2, d)
	burst(pos, ColorSequence.new(c1, c2), 70, 22 * s, d * 1.6, 1.2 * s, TEXS, Vector3.new(2, -4, 2))
	sphere(pos, c1, s, 12 * s, d * .35)
	ring(pos, c2, 26 * s, d * .6)
end
EX["Cube Shatter"] = function(pos, s, c1, c2, d)
	sphere(pos, c1, s, 8 * s, d * .25)
	for i = 1, 26 do
		local dir = Vector3.new(math.random() - .5, math.random() * .8 + .1, math.random() - .5).Unit
		local p = mk(Enum.PartType.Block, pos, Vector3.new(1, 1, 1) * s * (.5 + math.random()), i % 2 == 0 and c1 or c2)
		tw(p, d, { CFrame = CFrame.new(pos + dir * math.random(8, 26) * s) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, d + .2)
	end
end
EX["Ice Crystal"] = function(pos, s, c1, c2, d)
	ring(pos, c1, 30 * s, d * .6)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local h = (5 + math.random() * 6) * s
		local base = CFrame.new(pos) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(2 + math.random() * 5) * s) * CFrame.Angles(math.rad(-15 - math.random() * 15), 0, 0)
		local p = mk(Enum.PartType.Block, pos, Vector3.new(.9 * s, h, .9 * s), i % 2 == 0 and c1 or c2, Enum.Material.Ice)
		p.Transparency = .1
		p.CFrame = base * CFrame.new(0, -h, 0)
		tw(p, .25, { CFrame = base * CFrame.new(0, h / 2, 0) })
		task.delay(d * .6, function() if p.Parent then tw(p, d * .4, { Transparency = 1 }) end end)
		Debris:AddItem(p, d + .3)
	end
	burst(pos, c2, 40, 25 * s, d, .8 * s)
end
local lastEx = { t = 0, p = Vector3.new(0, -1e5, 0) }
function L.alive() return alive end
function L.addShake(a) shk = math.max(shk, a) end
function L.toyFolders(all)
	local res = {}
	if all then
		for _, c in ipairs(workspace:GetChildren()) do
			if (c:IsA("Folder") or c:IsA("Model")) and c.Name:find("SpawnedInToys") then res[#res + 1] = c end
		end
	else
		local f = workspace:FindFirstChild(LP.Name .. "SpawnedInToys")
		if f then res[1] = f end
	end
	return res
end
function L.explode(pos)
	local now = tick()
	if now - lastEx.t < .25 and (pos - lastEx.p).Magnitude < 15 then return end
	lastEx.t, lastEx.p = now, pos
	local style = (S.ex_rand and EXN[math.random(#EXN)]) or S.ex_style
	local f = EX[style]
	if not f then return end
	local pr = EXC[style]
	local c1, c2 = pr[1], pr[2]
	if S.ex_ccol then c1 = S.ex_col c2 = c1:Lerp(Color3.new(1, 1, 1), .5) end
	if S.ex_cycle then c1 = hsv(now * .3) c2 = hsv(now * .3 + .5) end
	if S.ex_dbg then warn("[Sef] custom explosion:", style, pos) end
	pcall(f, pos, S.ex_scale, c1, c2, S.ex_dur)
	flash(pos, c1, S.ex_scale, S.ex_dur * .5)
	if S.ex_shk then
		local cm = cam()
		local dist = cm and (cm.CFrame.Position - pos).Magnitude or 0
		shk = math.max(shk, S.ex_shk_amt * math.clamp(1 - dist / 220, 0, 1))
	end
	if S.ex_kick then L.kick = math.max(L.kick, S.ex_kick_amt) end
	if S.ex_scorch and L.scorch then pcall(L.scorch, pos, S.ex_scale) end
	L.supUntil = now + .7
	L.supPos = pos
end
function L.testExplosion()
	local c = cam()
	local pos = c.CFrame.Position + c.CFrame.LookVector * 35
	local r = workspace:Raycast(pos, Vector3.new(0, -250, 0))
	if r then pos = r.Position + Vector3.new(0, 2, 0) end
	L.explode(pos)
end
L.EX, L.EXC, L.EXN, L.MATS, L.MATN, L.TEX, L.GLP, L.GLN, L.HATDEF = EX, EXC, EXN, MATS, MATN, TEX, GLP, GLN, HATDEF

-- config ------------------------------------------------------------------
function L.save()
	local out = {}
	for k, v in pairs(S) do
		local t = typeof(v)
		if t == "Color3" then out[k] = { c = { v.R, v.G, v.B } }
		elseif t == "EnumItem" then out[k] = { kc = v.Name }
		elseif t == "number" or t == "boolean" or t == "string" then out[k] = v end
	end
	local ok = pcall(function()
		if makefolder then pcall(makefolder, "SefFtap") end
		writefile(CFG_FILE, Http:JSONEncode(out))
	end)
	notify("Sef's Ftap Visuals", ok and "Config saved." or "Executor can't write files.")
end
function L.load()
	local ok, data = pcall(function() return Http:JSONDecode(readfile(CFG_FILE)) end)
	if not ok then notify("Sef's Ftap Visuals", "No saved config found.") return end
	for k, v in pairs(data) do
		local c = Ctl[k]
		if c then
			if type(v) == "table" then
				if v.c then c.set(Color3.new(v.c[1], v.c[2], v.c[3])) elseif v.kc and Enum.KeyCode[v.kc] then c.set(Enum.KeyCode[v.kc]) end
			else c.set(v) end
		end
	end
	notify("Sef's Ftap Visuals", "Config loaded.")
end

----------------------------------------------------------------------
-- TABS / FEATURES
----------------------------------------------------------------------
L.tabs.Camera = tab("Camera", 1)
local firstTab = L.tabs.Camera
T("FOV Changer", "fov_on", false, function() L.fovReset() end)
SL("Field Of View", "fov", 30, 120, 90, 0)
T("Smooth FOV", "fov_smooth", true)
T("Hold-To-Zoom", "zoom_on", false, function() L.fovReset() end)
SL("Zoom FOV", "zoom_fov", 5, 70, 25, 0)
KB("Zoom Key", "zoom_key", Enum.KeyCode.C)
T("Camera Fixer (auto)", "cam_fix", false, function(v) if v then L.fixCam() end end)
SL("Max Zoom Out", "maxzoom", 10, 3000, 800, 0, function() if S.cam_fix then L.fixCam() end end)
SL("Min Zoom In", "minzoom", 0, 20, .5, 1, function() if S.cam_fix then L.fixCam() end end)
B("Fix Camera Now", function() L.fixCam(true) end)
T("Camera Stretcher", "str_on", false)
SL("Stretch X", "strx", .2, 3, 1, 2)
SL("Stretch Y", "stry", .2, 3, .75, 2)
SL("Camera Roll", "roll", -180, 180, 0, 0)
SL("Camera Offset X", "offx", -10, 10, 0, 1)
SL("Camera Offset Y", "offy", -10, 10, 0, 1)
SL("Camera Offset Z", "offz", -10, 10, 0, 1)
T("Camera Shake", "shk_on", false)
SL("Shake Intensity", "shk_amt", 0, 2, .3, 2)
T("Head Bob", "bob_on", false)
SL("Head Bob Strength", "bob", 0, 3, 1, 1)
T("Speed FOV", "spdfov_on", false, function() L.fovReset() end)
SL("Speed FOV Amount", "spdfov", 0, 40, 12, 0)
T("Cinematic Bars", "bars_on", false, L.bars)
SL("Bar Size", "bars_sz", 0, .3, .1, 2, L.bars)
B("Reset Camera", function()
	for _, k in ipairs({ "roll", "offx", "offy", "offz" }) do Ctl[k].set(0) end
	for _, k in ipairs({ "fov_on", "str_on", "shk_on", "bob_on", "spdfov_on", "bars_on" }) do Ctl[k].set(false) end
	L.fovReset() L.fixCam(true)
end)

L.tabs["Lighting"] = tab("Lighting", 2)
local function LSL(name, key, min, max, dec) SL(name, key, min, max, orig[LMAP[key]] or min, dec, function(v) setL(LMAP[key], v) end) end
local function LCO(name, key) CO(name, key, orig[LMAP[key]] or Color3.new(1, 1, 1), function(v) setL(LMAP[key], v) end) end
do
	local names = {}
	for k in pairs(LPRE) do names[#names + 1] = k end
	table.sort(names)
	table.insert(names, 1, "None")
	DD("Lighting Preset", "lt_pre", names, "None", function(n)
		L.resetLighting()
		local pr = LPRE[n]
		if not pr then return end
		for k, v in pairs(pr) do if Ctl[k] then Ctl[k].set(v) end end
	end)
end
LSL("Brightness", "lt_br", 0, 10, 1)
LSL("Time Of Day", "lt_clock", 0, 24, 1)
T("Day/Night Cycle", "tloop", false)
SL("Cycle Speed", "tspeed", .1, 5, .5, 1)
LCO("Ambient Color", "lt_amb")
LCO("Outdoor Ambient", "lt_outamb")
T("Fullbright", "fullb", false, function(v)
	if v then setL("Brightness", 2) setL("Ambient", Color3.new(1, 1, 1)) setL("OutdoorAmbient", Color3.new(1, 1, 1)) setL("GlobalShadows", false)
	else
		setL("Brightness", S.lt_br) setL("Ambient", S.lt_amb) setL("OutdoorAmbient", S.lt_outamb) setL("GlobalShadows", orig.GlobalShadows)
	end
end)
LSL("Exposure", "lt_exp", -3, 3, 2)
T("Global Shadows", "lt_sh", orig.GlobalShadows ~= false, function(v) setL("GlobalShadows", v) end)
LSL("Shadow Softness", "lt_soft", 0, 1, 2)
T("Remove Fog", "nofog", false, function(v) setL("FogEnd", v and 1e6 or S.lt_foge) end)
LSL("Fog Start", "lt_fogs", 0, 5000, 0)
LSL("Fog End", "lt_foge", 10, 20000, 0)
LCO("Fog Color", "lt_fogc")
LCO("Color Shift Top", "lt_top")
LCO("Color Shift Bottom", "lt_bot")
LSL("Env Diffuse", "lt_diff", 0, 1, 2)
LSL("Env Specular", "lt_spec", 0, 1, 2)
T("Custom Atmosphere", "at_on", false, L.atmos)
SL("Atmosphere Density", "at_den", 0, 1, .3, 2, L.atmos)
SL("Atmosphere Offset", "at_off", 0, 1, 0, 2, L.atmos)
CO("Atmosphere Color", "at_col", Color3.fromRGB(199, 199, 199), L.atmos)
CO("Atmosphere Decay", "at_dec", Color3.fromRGB(106, 112, 125), L.atmos)
SL("Atmosphere Glare", "at_gl", 0, 10, 0, 1, L.atmos)
SL("Atmosphere Haze", "at_hz", 0, 10, 0, 1, L.atmos)
B("Reset Lighting", L.resetLighting)

L.tabs["Effects"] = tab("Effects", 3)
T("Bloom", "bloom_on", false, L.fx)
SL("Bloom Intensity", "bloom_i", 0, 5, 1, 2, L.fx)
SL("Bloom Size", "bloom_s", 0, 100, 24, 0, L.fx)
SL("Bloom Threshold", "bloom_t", 0, 5, .8, 2, L.fx)
T("Color Correction", "cc_on", false, L.fx)
SL("CC Brightness", "cc_br", -1, 1, 0, 2, L.fx)
SL("CC Contrast", "cc_ct", -1, 2, 0, 2, L.fx)
SL("CC Saturation", "cc_sat", -1, 2, 0, 2, L.fx)
CO("CC Tint", "cc_tint", Color3.new(1, 1, 1), L.fx)
T("Grayscale", "gray", false, L.fx)
T("Sepia", "sepia", false, L.fx)
T("Night Vision", "night", false, L.fx)
T("Blur", "blur_on", false, L.fx)
SL("Blur Size", "blur_s", 0, 56, 8, 0, L.fx)
T("Sun Rays", "rays_on", false, L.fx)
SL("Sun Ray Intensity", "rays_i", 0, 1, .25, 2, L.fx)
SL("Sun Ray Spread", "rays_s", 0, 1, 1, 2, L.fx)
T("Depth Of Field", "dof_on", false, L.fx)
SL("DOF Focus Distance", "dof_f", 0, 500, 60, 0, L.fx)
SL("DOF Far Intensity", "dof_far", 0, 1, .5, 2, L.fx)
SL("DOF Focus Radius", "dof_r", 0, 500, 40, 0, L.fx)
T("Vignette", "vig_on", false, L.vig)
SL("Vignette Strength", "vig_str", 0, 1, .6, 2, L.vig)
CO("Vignette Color", "vig_col", Color3.new(0, 0, 0), L.vig)

L.tabs["Sky"] = tab("Sky", 4)
SL("Star Count", "sky_stars", 0, 5000, 3000, 0, L.sky)
SL("Sun Size", "sky_sun", 0, 60, 21, 0, L.sky)
SL("Moon Size", "sky_moon", 0, 60, 11, 0, L.sky)
T("Show Sun/Moon", "sky_cel", true, L.sky)
SL("Sky Rotation", "sky_rot", 0, 360, 0, 0, L.sky)
T("Clouds", "cl_on", false, L.clouds)
SL("Cloud Cover", "cl_cover", 0, 1, .6, 2, L.clouds)
SL("Cloud Density", "cl_den", 0, 1, .5, 2, L.clouds)
CO("Cloud Color", "cl_col", Color3.new(1, 1, 1), L.clouds)
T("Snow", "snow_on", false, L.weather)
SL("Snow Amount", "snow_rate", 10, 600, 150, 0, L.weather)
CO("Snow Color", "snow_col", Color3.new(1, 1, 1), L.weather)
T("Rain", "rain_on", false, L.weather)
SL("Rain Amount", "rain_rate", 10, 800, 300, 0, L.weather)
CO("Rain Color", "rain_col", Color3.fromRGB(170, 200, 255), L.weather)

L.tabs["Character"] = tab("Character", 6)
T("Samurai Hat", "hat_on", false, L.hat)
DD("Hat Shape", "hat_shape", { "Soft Ellipsoid", "Dome", "Cone (Kasa)", "Sphere" }, "Soft Ellipsoid", function(n)
	local d = HATDEF[n]
	Ctl.hat_w.set(d[1], true) Ctl.hat_th.set(d[2], true) Ctl.hat_h.set(d[3], true)
	L.hat()
end)
CO("Hat Color", "hat_col", Color3.fromRGB(238, 238, 245), L.hat)
SL("Hat Width", "hat_w", 1, 6, 3.6, 2, L.hat)
SL("Hat Thickness", "hat_th", .2, 3, .9, 2, L.hat)
SL("Hat Transparency", "hat_tr", 0, .95, .55, 2, L.hat)
SL("Hat Height (on head)", "hat_h", 0, 2.5, .55, 2)
SL("Hat Tilt", "hat_tilt", -45, 45, 0, 0)
T("Soft Layered Look", "hat_soft", true, L.hat)
T("Hat Neon (keeps color in any lighting)", "hat_neon", true, L.hat)
T("Hat Float Bob", "hat_bob", false)
T("Hat Glow Light", "hat_glow", false, L.hat)
CO("Hat Glow Color", "hat_glowc", Color3.fromRGB(110, 180, 255), L.hat)
T("Hat Sparkles", "hat_part", false, L.hat)
T("Halo", "halo_on", false, L.halo)
CO("Halo Color", "halo_col", Color3.fromRGB(255, 255, 255), function(c) for _, p in ipairs(halo.parts) do p.Color = c end end)
SL("Halo Height", "halo_h", 1, 4, 1.8, 2)
T("Rainbow Character", "ch_rain", false, function(v) if v then L.char() else L.char() end end)
SL("Rainbow Speed", "ch_rs", .05, 3, .4, 2)
T("Character Color", "ch_col_on", false, L.char)
CO("Character Tint", "ch_col", Color3.fromRGB(120, 180, 255), L.char)
T("Neon Material", "ch_neon", false, L.char)
T("ForceField Material", "ch_ff", false, L.char)
T("Ghost Mode", "ch_ghost", false, L.char)
SL("Ghost Transparency", "ch_tr", 0, 1, .5, 2, L.char)
T("Hide Accessories", "ch_hideacc", false, L.char)
T("Body Outline Glow", "ch_hl", false, L.char)
CO("Outline Color", "ch_hlc", Color3.fromRGB(120, 200, 255), L.char)
T("Movement Trail", "tr_on", false, L.rig)
CO("Trail Color", "tr_col", Color3.fromRGB(120, 200, 255), L.rig)
SL("Trail Length", "tr_life", .1, 4, 1, 1, L.rig)
T("Sparkle Aura", "aura_on", false, L.rig)
CO("Aura Color", "aura_col", Color3.fromRGB(200, 220, 255), L.rig)
SL("Aura Amount", "aura_rate", 1, 80, 20, 0, L.rig)

L.tabs["Grab Lines"] = tab("Grab Lines", 8)
T("Custom Grab Lines", "gl_on", false)
DD("Grab Line Style", "gl_style", GLN, "Neon Cyan", function(n) L.glPreset(n) end)
CO("Line Color 1", "gl_c1", Color3.fromRGB(0, 255, 255))
CO("Line Color 2", "gl_c2", Color3.fromRGB(0, 120, 255))
T("Rainbow Line", "gl_rain", false)
SL("Rainbow Speed", "gl_rs", .05, 3, .5, 2)
T("Recolor Grab Tip", "gl_tip", true)
T("Hide Grab Tip", "gl_hidetip", false)
T("Override Width", "gl_wov", true)
SL("Line Width", "gl_w", .05, 2, .35, 2)
T("Pulse Width", "gl_pulse", false)
SL("Line Transparency", "gl_tr", 0, 1, 0, 2)
SL("Light Emission", "gl_le", 0, 1, 1, 2)
DD("Line Texture", "gl_tex", { "None", "Sparkles", "Smoke", "Fire" }, "Sparkles")
SL("Texture Speed", "gl_ts", -10, 10, 1.5, 1)
SL("Texture Length", "gl_tl", .2, 20, 3, 1)
T("Override Curve (stops sway)", "gl_cov", false)
SL("Curve Amount", "gl_curve", -10, 10, 0, 1)
T("Override Segments", "gl_sov", false)
SL("Line Segments", "gl_seg", 1, 60, 10, 0)
DD("Face Camera", "gl_fc", { "Game Default", "On", "Off" }, "Game Default")
T("Grab Sparks", "gl_spark", false)
T("Hide Line", "gl_hide", false)

L.tabs["Pallets"] = tab("Pallets", 9)
T("Custom Pallet Color", "pal_on", false)
PAL("Pallet Color Palette", "pal_col")
CO("Custom Pallet Color", "pal_col", Color3.fromRGB(255, 255, 255))
IN("Hex Color (#RRGGBB)", "pal_hex", "#FFFFFF", function(h) pcall(function() Ctl.pal_col.set(hex(h)) end) end)
T("Rainbow Pallets", "pal_rain", false)
SL("Rainbow Speed", "pal_rs", .05, 3, .4, 2)
T("Pulse Color", "pal_pulse", false)
DD("Pallet Material", "pal_mat", MATN, "Default")
SL("Pallet Transparency", "pal_tr", 0, .95, 0, 2)
SL("Pallet Reflectance", "pal_ref", 0, 1, 0, 2)
T("Pallet Outline Glow", "pal_hl", false)
CO("Outline Color", "pal_hlc", Color3.fromRGB(255, 255, 255))
T("Strip Textures", "pal_strip", false)
T("Apply To Everyone's Pallets", "pal_all", false)

L.tabs["Explosions"] = tab("Explosions", 12)
T("Custom Explosion VFX", "ex_on", false)
PK("Explosion Style", "ex_style", EXN, "Nuke")
SL("Explosion Scale", "ex_scale", .3, 3, 1, 2)
SL("Duration", "ex_dur", .4, 4, 1.4, 1)
T("Use Custom Color", "ex_ccol", false)
CO("Explosion Color", "ex_col", Color3.fromRGB(255, 120, 40))
T("Hide Default Explosion", "ex_hide", true)
T("Screen Shake", "ex_shk", true)
SL("Shake Strength", "ex_shk_amt", 0, 2, .6, 2)
T("Light Flash", "ex_flash", true)
B("Test Explosion", L.testExplosion)

L.tabs["HUD"] = tab("HUD", 15)
T("FPS Counter", "h_fps", false)
T("Ping", "h_ping", false)
T("Clock", "h_clock", false)
T("Session Timer", "h_sess", false)
T("Speedometer", "h_speed", false)
T("Coordinates", "h_pos", false)
T("Toy Counter", "h_toys", false)
T("Watermark", "h_wm", false)
CO("HUD Color", "h_col", Color3.new(1, 1, 1))
SL("HUD Text Size", "h_size", 10, 24, 14, 0)
T("Custom Crosshair", "xh_on", false, L.xhair)
DD("Crosshair Style", "xh_style", { "Cross", "X", "Dot", "Circle" }, "Cross", L.xhair)
SL("Crosshair Size", "xh_size", 2, 40, 10, 0, L.xhair)
SL("Crosshair Thickness", "xh_th", 1, 8, 2, 0, L.xhair)
SL("Crosshair Gap", "xh_gap", 0, 20, 4, 0, L.xhair)
CO("Crosshair Color", "xh_col", Color3.fromRGB(230, 230, 230), L.xhair)
T("Spinning Crosshair", "xh_spin", false, function(v) if not v then L.xhair() end end)

L.tabs["Settings"] = tab("Settings", 17)
KB("Menu Toggle Key", "ui_key", Enum.KeyCode.RightShift)
CO("Accent Color", "accent", Color3.fromRGB(210, 210, 210), function() for _, f in ipairs(RF) do pcall(f) end end)
SL("Menu Transparency", "ui_t", 0, .9, .3, 2, function(v) ov.BackgroundTransparency = v end)
SL("Background Image Visibility", "ui_bg", 0, 1, .65, 2, function(v) bg.ImageTransparency = 1 - v end)
SL("Menu Scale (x auto-fit)", "ui_scale", .5, 1.5, 1, 2, function() computeFit() uiScale.Scale = targetScale() task.defer(clampMain) end)
SL("Menu Particles", "ui_pn", 0, 28, 18, 0)
T("Menu Animations", "ui_anim", true)
B("Save Config", L.save)
B("Load Config", L.load)
B("Unload Script", function() if env.SefFtapUnload then env.SefFtapUnload() end end)

----------------------------------------------------------------------
-- NEW FEATURE MODULES
----------------------------------------------------------------------
local U = { S = S, Ctl = Ctl, L = L, new = new, cr = cr, tw = tw, fire = fire, hsv = hsv, C = C, cam = cam,
	T = T, SL = SL, CO = CO, DD = DD, B = B, KB = KB, IN = IN, PAL = PAL, H = H, tab = tab, usePage = usePage,
	mk = mk, burst = burst, sphere = sphere, ring = ring, flash = flash, fxFolder = fxFolder, hud = hud, flashF = flashF,
	notify = notify, Players = Players, RS = RS, UIS = UIS, TS = TS, Lighting = Lighting, Debris = Debris, Http = Http,
	LP = LP, bg = bg, setL = setL, orig = orig, LMAP = LMAP, getSky = getSky, MATS = MATS, MATN = MATN,
	RAINBOWSEQ = RAINBOWSEQ, PK = PK, BG_FILE = BG_FILE, TEXS = TEXS, statsLbl = statsLbl }
local function MOD(name, fn)
	local ok, e = pcall(fn)
	if not ok then warn("[Sef's Ftap Visuals] module " .. name .. " failed: " .. tostring(e)) end
end

-- module: 00_helpers
MOD("00_helpers", function()
local S, L, new, cr, tw, hsv, C = U.S, U.L, U.new, U.cr, U.tw, U.hsv, U.C
local LP, Players, Debris, notify = U.LP, U.Players, U.Debris, U.notify

function L.ensure(par, name, class, props, on)
	local o = par:FindFirstChild(name)
	if on then
		if not o then o = Instance.new(class) o.Name = name o.Parent = par end
		for k, v in pairs(props) do pcall(function() o[k] = v end) end
	elseif o then
		o:Destroy()
	end
	return o
end
function L.firstPart(m)
	if m:IsA("BasePart") then return m end
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then return d end end
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
function L.groundY(pos)
	rp.FilterDescendantsInstances = { LP.Character, U.fxFolder }
	local r = workspace:Raycast(pos, Vector3.new(0, -60, 0), rp)
	return r and r.Position.Y
end

-- download helper (shared by background / skybox / sound)
function L.fetchAsset(url, fname)
	local ok, res = pcall(function()
		if makefolder then pcall(makefolder, "SefFtap") end
		local req = request or http_request or (syn and syn.request)
		local body
		if req then
			local r = req({ Url = url, Method = "GET" })
			body = r and r.Body
		end
		if not body then body = game:HttpGet(url) end
		if not body or #body < 200 then error("empty download") end
		writefile("SefFtap/" .. fname, body)
		return getcustomasset("SefFtap/" .. fname)
	end)
	if ok then return res end
	notify("Sef's Ftap Visuals", "Download failed: " .. tostring(res):sub(1, 80))
end
function L.toAsset(x)
	x = tostring(x or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if x == "" then return nil end
	if x:match("^%d+$") then return "rbxassetid://" .. x end
	if x:lower():match("^https?://") then return L.fetchAsset(x, "dl_" .. os.time() .. "_" .. math.random(9999) .. ".dat") end
	if isfile and isfile(x) and getcustomasset then return getcustomasset(x) end
	return x
end

-- shared particle definitions (character auras + weather volumes)
local SP = "rbxasset://textures/particles/sparkles_main.dds"
local SM = "rbxasset://textures/particles/smoke_main.dds"
L.EMD = {
	{ key = "embers", name = "Embers", tex = SP, lt = { 1.6, 2.6 }, sp = { 2, 5 }, sz = { .35, 0 }, acc = Vector3.new(0, 3, 0), col = Color3.fromRGB(255, 140, 40), rate = 30, tr = { 0, 1 }, le = 1, dir = "Top" },
	{ key = "fireflies", name = "Fireflies", tex = SP, lt = { 3, 5 }, sp = { .3, 1 }, sz = { .3, .3 }, col = Color3.fromRGB(190, 255, 90), rate = 12, tr = { .3, .9 }, le = 1, dir = "Top" },
	{ key = "petals", name = "Petals", tex = SP, lt = { 4, 6 }, sp = { 1, 3 }, sz = { .5, .5 }, acc = Vector3.new(2, -3, 1), col = Color3.fromRGB(255, 170, 205), rate = 18, tr = { 0, .8 }, le = .2, dir = "Bottom" },
	{ key = "confetti", name = "Confetti", tex = SP, lt = { 3, 4 }, sp = { 4, 9 }, sz = { .45, .45 }, acc = Vector3.new(0, -14, 0), col = Color3.new(1, 1, 1), rate = 40, tr = { 0, .3 }, le = .3, dir = "Top", rainbow = true },
	{ key = "ash", name = "Ash", tex = SM, lt = { 4, 6 }, sp = { .5, 2 }, sz = { .5, .5 }, acc = Vector3.new(0, -1, 0), col = Color3.fromRGB(150, 150, 150), rate = 25, tr = { .5, 1 }, dir = "Bottom" },
	{ key = "bubbles", name = "Bubbles", tex = SP, lt = { 3, 5 }, sp = { 1, 3 }, sz = { .3, .9 }, acc = Vector3.new(0, 2.5, 0), col = Color3.fromRGB(200, 230, 255), rate = 14, tr = { .3, 1 }, le = .4, dir = "Top" },
	{ key = "leaves", name = "Leaves", tex = SP, lt = { 4, 6 }, sp = { 1, 3 }, sz = { .6, .6 }, acc = Vector3.new(3, -3, 2), col = Color3.fromRGB(110, 160, 60), rate = 14, tr = { 0, .6 }, dir = "Bottom" },
	{ key = "stars", name = "Stars", tex = SP, lt = { 1, 2 }, sp = { 0, 1 }, sz = { 1.2, 0 }, col = Color3.fromRGB(255, 245, 190), rate = 18, tr = { 0, 1 }, le = 1, dir = "Top" },
	{ key = "magic", name = "Magic Dust", tex = SP, lt = { 1.2, 2 }, sp = { 1, 3 }, sz = { .6, 0 }, acc = Vector3.new(0, 1, 0), col = Color3.fromRGB(170, 90, 255), rate = 30, tr = { 0, 1 }, le = 1, dir = "Top" },
	{ key = "electric", name = "Electric Sparks", tex = SP, lt = { .15, .35 }, sp = { 10, 20 }, sz = { .5, 0 }, col = Color3.fromRGB(90, 220, 255), rate = 45, tr = { 0, 1 }, le = 1, dir = "Top" },
	{ key = "smoke", name = "Smoke", tex = SM, lt = { 1, 2 }, sp = { 1, 3 }, sz = { 1, 3.5 }, acc = Vector3.new(0, 2, 0), col = Color3.fromRGB(120, 120, 120), rate = 20, tr = { .5, 1 }, dir = "Top" },
	{ key = "glitter", name = "Glitter", tex = SP, lt = { 1, 1.8 }, sp = { 2, 6 }, sz = { .35, 0 }, acc = Vector3.new(0, -2, 0), col = Color3.new(1, 1, 1), rate = 40, tr = { 0, 1 }, le = 1, dir = "Top", rainbow = true },
}
function L.emProps(d, col, rate, vol)
	local p = {
		Texture = d.tex, Rate = rate, Lifetime = NumberRange.new(d.lt[1], d.lt[2]), Speed = NumberRange.new(d.sp[1], d.sp[2]),
		SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(d.sz[1], d.sz[2]), Transparency = NumberSequence.new(d.tr[1], d.tr[2]),
		LightEmission = d.le or 0, Acceleration = d.acc or Vector3.new(0, 0, 0), Color = ColorSequence.new(col),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), EmissionDirection = Enum.NormalId[d.dir or "Top"],
	}
	if d.rainbow and col == Color3.new(1, 1, 1) then p.Color = U.RAINBOWSEQ end
	if vol then
		p.Shape = Enum.ParticleEmitterShape.Box
		p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	return p
end

-- generic cleanup of anything we parented into characters / toys / players
L.cleanups[#L.cleanups + 1] = function()
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			for _, d in ipairs(pl.Character:GetDescendants()) do
				if d.Name:sub(1, 3) == "Sef" then pcall(function() d:Destroy() end) end
			end
		end
	end
	for _, f in ipairs(L.toyFolders(true)) do
		for _, d in ipairs(f:GetDescendants()) do
			if d.Name:sub(1, 3) == "Sef" then pcall(function() d:Destroy() end) end
		end
	end
end
end)

-- module: 01_lighting_hud_settings
MOD("01_lighting_hud_settings", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, KB, H, use = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.KB, U.H, U.usePage
local hsv, setL, notify, bg = U.hsv, U.setL, U.notify, U.bg

---------------------------------------------------------------- LIGHTING
use("Lighting")
H("Time Of Day Quick Set")
for _, e in ipairs({ { "Sunrise (6:00)", 6 }, { "Noon (12:00)", 12 }, { "Golden Hour (17:30)", 17.5 }, { "Sunset (18:30)", 18.5 }, { "Dusk (19:30)", 19.5 }, { "Midnight (0:00)", 0 } }) do
	B(e[1], function() Ctl.lt_clock.set(e[2]) end)
end
H("Color Grades")
local GR = {
	Cinematic = { -.02, .25, -.15, Color3.fromRGB(255, 240, 225) }, Cyberpunk = { 0, .3, .6, Color3.fromRGB(230, 200, 255) },
	Retro = { .05, .1, -.3, Color3.fromRGB(255, 225, 180) }, Noir = { 0, .4, -1, Color3.new(1, 1, 1) }, Vivid = { 0, .15, .7, Color3.new(1, 1, 1) },
	Faded = { .08, -.25, -.35, Color3.new(1, 1, 1) }, Warm = { 0, .1, .1, Color3.fromRGB(255, 215, 170) }, Cold = { 0, .1, -.1, Color3.fromRGB(180, 215, 255) },
	Horror = { -.1, .35, -.5, Color3.fromRGB(200, 230, 210) }, Dream = { .1, -.1, .3, Color3.fromRGB(255, 210, 245) }, Toxic = { 0, .25, .5, Color3.fromRGB(190, 255, 170) },
}
DD("Color Grade Preset", "lg_pre", { "None", "Cinematic", "Cyberpunk", "Retro", "Noir", "Vivid", "Faded", "Warm", "Cold", "Horror", "Dream", "Toxic" }, "None", function(n)
	local g = GR[n]
	if not g then
		Ctl.cc_br.set(0, true) Ctl.cc_ct.set(0, true) Ctl.cc_sat.set(0, true) Ctl.cc_tint.set(Color3.new(1, 1, 1), true)
		Ctl.cc_on.set(false)
		return
	end
	Ctl.cc_br.set(g[1], true) Ctl.cc_ct.set(g[2], true) Ctl.cc_sat.set(g[3], true) Ctl.cc_tint.set(g[4], true)
	Ctl.cc_on.set(true)
end)
H("Animated Lighting")
T("Rainbow Ambient", "lt_rain", false, function(v) if not v then setL("Ambient", S.lt_amb) setL("OutdoorAmbient", S.lt_outamb) end end)
SL("Rainbow Ambient Speed", "lt_rainsp", .05, 2, .3, 2)
T("Brightness Pulse", "lt_pulse", false, function(v) if not v then setL("Brightness", S.lt_br) end end)
SL("Pulse Amount", "lt_pulseamt", 0, 3, .6, 2)
SL("Pulse Speed", "lt_pulsesp", .2, 8, 2, 1)
T("Horror Flicker", "lt_flick", false, function(v) if not v then setL("Brightness", S.lt_br) end end)
SL("Flicker Strength", "lt_flickamt", 0, 3, 1.2, 2)
SL("Sun Latitude", "lt_lat", -90, 90, 0, 0, function(v) setL("GeoLatitude", v) end)
L.steps[#L.steps + 1] = function(dt, t)
	if S.lt_rain then
		setL("Ambient", hsv(t * S.lt_rainsp, .55, .7))
		setL("OutdoorAmbient", hsv(t * S.lt_rainsp + .1, .55, .8))
	end
	if S.lt_pulse and not S.lt_flick then setL("Brightness", math.max(0, S.lt_br + math.sin(t * S.lt_pulsesp) * S.lt_pulseamt)) end
	if S.lt_flick then
		setL("Brightness", (math.random() < .07) and math.max(0, S.lt_br - S.lt_flickamt * math.random()) or S.lt_br)
	end
end

---------------------------------------------------------------- HUD
use("HUD")
H("More Stats")
T("Max Speed Record", "h_max", false)
T("Fling Counter", "h_fling", false)
T("Air Time", "h_air", false)
T("Height", "h_height", false)
T("Distance From Spawn", "h_dist", false)
T("Grab Status", "h_grab", false)
T("Player Count", "h_players", false)
T("Memory Usage", "h_mem", false)
T("Camera FOV", "h_fov", false)
T("Camera Distance", "h_cdist", false)
H("HUD Layout")
SL("HUD X", "h_x", 0, 600, 12, 0)
SL("HUD Y", "h_y", 0, 400, 64, 0)
SL("HUD Background", "h_bgt", 0, 1, .4, 2)
DD("HUD Font", "h_font", { "Code", "Gotham", "GothamBold", "Arcade", "SciFi", "Ubuntu" }, "Code")

---------------------------------------------------------------- SETTINGS: custom menu background + button
use("Settings")
H("Custom Menu Background")
IN("Background Image URL", "bg_url", "")
B("Apply URL Background", function()
	if S.bg_url == "" then notify("Sef's Ftap Visuals", "Paste an image URL first.") return end
	task.spawn(function()
		local a = L.fetchAsset(S.bg_url, "bgc_" .. os.time() .. ".jpg")
		if a then bg.Image = a end
	end)
end)
IN("Background File (executor workspace)", "bg_file", "")
B("Apply File Background", function()
	local p = S.bg_file
	if isfile and p ~= "" and isfile(p) and getcustomasset then bg.Image = getcustomasset(p)
	else notify("Sef's Ftap Visuals", "File not found in your executor workspace folder.") end
end)
IN("Background Roblox Asset ID", "bg_id", "")
B("Apply Asset ID Background", function()
	local a = L.toAsset(S.bg_id)
	if a then bg.Image = a end
end)
B("Reset To Default Background", function()
	pcall(function() if isfile(U.BG_FILE) then bg.Image = getcustomasset(U.BG_FILE) end end)
end)
DD("Background Fit", "bg_fit", { "Crop", "Fit", "Stretch", "Tile" }, "Crop", function(v) pcall(function() bg.ScaleType = Enum.ScaleType[v] end) end)
H("Floating S Button")
SL("Button Size", "fb_sz", 24, 70, 36, 0, function(v) L.fb.Size = UDim2.fromOffset(v, v) end)
SL("Button Transparency", "fb_tr", 0, .9, .1, 2, function(v) L.fb.BackgroundTransparency = v end)
end)

-- module: 02_skybox_weather
MOD("02_skybox_weather", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, H, use, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.H, U.usePage, U.tab
local new, tw, hsv, Debris, Lighting, setL, notify, cam, LP, fxFolder, flashF = U.new, U.tw, U.hsv, U.Debris, U.Lighting, U.setL, U.notify, U.cam, U.LP, U.fxFolder, U.flashF

---------------------------------------------------------------- SKYBOX (Sky tab)
use("Sky")
H("Custom Skybox")
local FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }
local skyOrig
local function sky()
	local s = L.getSky()
	if not skyOrig then
		skyOrig = {}
		for _, f in ipairs(FACES) do skyOrig[f] = s["Skybox" .. f] end
	end
	return s
end
local function skyAll(asset)
	if not asset then return end
	local s = sky()
	for _, f in ipairs(FACES) do s["Skybox" .. f] = asset end
end
IN("Skybox Image URL (all sides)", "sk_url", "")
B("Apply URL To All Sides", function()
	if S.sk_url == "" then notify("Sef's Ftap Visuals", "Paste an image URL first.") return end
	task.spawn(function() skyAll(L.fetchAsset(S.sk_url, "sky_" .. os.time() .. ".png")) end)
end)
IN("Skybox Roblox Asset ID (all sides)", "sk_id", "")
B("Apply Asset ID To All Sides", function() skyAll(L.toAsset(S.sk_id)) end)
IN("Skybox File (executor workspace)", "sk_file", "")
B("Apply File To All Sides", function()
	if isfile and S.sk_file ~= "" and isfile(S.sk_file) then skyAll(getcustomasset(S.sk_file))
	else notify("Sef's Ftap Visuals", "File not found in your executor workspace folder.") end
end)
H("Individual Faces (URL, asset id, or file)")
local faceKey = { Bk = "sk_bk", Dn = "sk_dn", Ft = "sk_ft", Lf = "sk_lf", Rt = "sk_rt", Up = "sk_up" }
local faceName = { Bk = "Back", Dn = "Down", Ft = "Front", Lf = "Left", Rt = "Right", Up = "Up" }
for _, f in ipairs(FACES) do IN("Skybox " .. faceName[f], faceKey[f], "") end
B("Apply Individual Faces", function()
	task.spawn(function()
		local s = sky()
		for _, f in ipairs(FACES) do
			local a = L.toAsset(S[faceKey[f]])
			if a then s["Skybox" .. f] = a end
		end
	end)
end)
B("Reset Skybox", function()
	if skyOrig then
		local s = L.getSky()
		for _, f in ipairs(FACES) do s["Skybox" .. f] = skyOrig[f] end
	end
end)
H("Skybox Motion")
T("Spin Skybox", "sk_spin", false)
SL("Spin Speed", "sk_spinsp", -30, 30, 3, 1)
SL("Skybox Tilt X", "sk_tx", 0, 360, 0, 0, L.sky)
SL("Skybox Tilt Z", "sk_tz", 0, 360, 0, 0, L.sky)
T("Rainbow Atmosphere", "at_rain", false)
SL("Rainbow Atmosphere Speed", "at_rainsp", .05, 2, .2, 2)
L.steps[#L.steps + 1] = function(dt, t)
	if S.sk_spin then
		local s = Lighting:FindFirstChildOfClass("Sky")
		if s then s.SkyboxOrientation = Vector3.new(S.sk_tx, (S.sky_rot + t * S.sk_spinsp) % 360, S.sk_tz) end
	end
	if S.at_rain then
		local a = Lighting:FindFirstChild("SefAtmos")
		if a then a.Color = hsv(t * S.at_rainsp, .5, 1) end
	end
end

---------------------------------------------------------------- WEATHER TAB
L.tabs.Weather = tab("Weather", 5)
H("Weather Volumes (follow your camera)")
local vol = new("Part", { Name = "SefWeatherVol", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(90, 50, 90) }, fxFolder)
local ems = {}
for _, d in ipairs(L.EMD) do
	local e = new("ParticleEmitter", { Name = "E_" .. d.key, Enabled = false }, vol)
	ems[d.key] = e
end
local function apply()
	for _, d in ipairs(L.EMD) do
		local e = ems[d.key]
		local p = L.emProps(d, S["wxc_" .. d.key], S["wxr_" .. d.key], true)
		for k, v in pairs(p) do pcall(function() e[k] = v end) end
		e.Enabled = S["wx_" .. d.key]
	end
end
for _, d in ipairs(L.EMD) do
	T(d.name, "wx_" .. d.key, false, apply)
	CO(d.name .. " Color", "wxc_" .. d.key, d.col, apply)
	SL(d.name .. " Amount", "wxr_" .. d.key, 1, 300, d.rate * 2, 0, apply)
end
H("Thunderstorm")
T("Thunderstorm", "st_on", false)
SL("Min Time Between Strikes", "st_min", 1, 30, 4, 0)
SL("Max Time Between Strikes", "st_max", 2, 60, 12, 0)
T("Lightning Bolt Visual", "st_bolt", true)
SL("Flash Strength", "st_flash", 0, 1, .45, 2)
T("Thunder Camera Shake", "st_shk", true)
SL("Bolt Distance", "st_dist", 40, 400, 160, 0)
H("Shooting Stars")
T("Shooting Stars", "ss_on", false)
SL("Frequency", "ss_rate", .1, 5, 1, 1)
CO("Star Color", "ss_col", Color3.fromRGB(200, 225, 255))
SL("Star Size", "ss_sz", .3, 4, 1.2, 1)
SL("Trail Length", "ss_len", .2, 3, 1, 1)
SL("Star Speed", "ss_spd", .3, 3, 1, 1)

local nextStrike = 0
local function strike()
	local c = cam()
	if not c then return end
	local ang = math.random() * math.pi * 2
	local d = S.st_dist * (.5 + math.random() * .5)
	local cp = c.CFrame.Position
	local base = Vector3.new(cp.X + math.cos(ang) * d, cp.Y, cp.Z + math.sin(ang) * d)
	local gy = L.groundY(base + Vector3.new(0, 300, 0)) or (cp.Y - 5)
	if S.st_bolt then
		local pts = { Vector3.new(base.X, gy + 240, base.Z) }
		for i = 1, 9 do
			local f = i / 9
			pts[#pts + 1] = Vector3.new(base.X + (math.random() - .5) * 26 * (1 - f), gy + 240 * (1 - f), base.Z + (math.random() - .5) * 26 * (1 - f))
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local len = (b - a).Magnitude
			local p = new("Part", { Name = "SefBolt", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(225, 235, 255), Size = Vector3.new(.7, .7, len), CFrame = CFrame.lookAt((a + b) / 2, b) }, fxFolder)
			tw(p, .45, { Transparency = 1, Size = Vector3.new(.1, .1, len) })
			Debris:AddItem(p, .6)
		end
	end
	flashF.BackgroundColor3 = Color3.new(1, 1, 1)
	flashF.BackgroundTransparency = 1 - S.st_flash
	tw(flashF, .5, { BackgroundTransparency = 1 })
	setL("ExposureCompensation", S.lt_exp + 1.2)
	task.delay(.12, function() setL("ExposureCompensation", S.lt_exp) end)
	if S.st_shk then L.addShake(.5 * math.clamp(1 - d / 400, .1, 1)) end
end
L.steps[#L.steps + 1] = function(dt, t)
	local c = cam()
	if c then vol.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, 10, 0)) end
	if S.st_on and t > nextStrike then
		strike()
		nextStrike = t + S.st_min + math.random() * math.max(0, S.st_max - S.st_min)
	end
	if S.ss_on and c and math.random() < dt * S.ss_rate then
		local dir = Vector3.new(math.random() - .5, 0, math.random() - .5).Unit
		local from = c.CFrame.Position + Vector3.new(math.random(-300, 300), math.random(140, 260), math.random(-300, 300))
		local to = from + dir * math.random(400, 600) + Vector3.new(0, -math.random(60, 120), 0)
		local p = new("Part", { Name = "SefStar", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = S.ss_col, Size = Vector3.new(1, 1, 1) * S.ss_sz, CFrame = CFrame.new(from) }, fxFolder)
		local a0 = new("Attachment", { Position = Vector3.new(0, S.ss_sz / 2, 0) }, p)
		local a1 = new("Attachment", { Position = Vector3.new(0, -S.ss_sz / 2, 0) }, p)
		new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = S.ss_len, Color = ColorSequence.new(S.ss_col), LightEmission = 1, Transparency = NumberSequence.new(0, 1), FaceCamera = true }, p)
		local dur = 1.6 / S.ss_spd
		tw(p, dur, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
		Debris:AddItem(p, dur + S.ss_len + .3)
	end
end
end)

-- module: 03_character
MOD("03_character", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, H, use = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.H, U.usePage
local new, tw, hsv, LP, fxFolder, cam, ring, burst = U.new, U.tw, U.hsv, U.LP, U.fxFolder, U.cam, U.ring, U.burst
local EMD = L.EMD
use("Character")

---------------------------------------------------------------- limbs / trail extras
H("Per-Limb Colors")
T("Per-Limb Colors", "limb_on", false, L.char)
CO("Head Color", "limb_head", Color3.fromRGB(255, 220, 190), L.char)
CO("Torso Color", "limb_torso", Color3.fromRGB(40, 40, 50), L.char)
CO("Left Arm Color", "limb_larm", Color3.fromRGB(255, 220, 190), L.char)
CO("Right Arm Color", "limb_rarm", Color3.fromRGB(255, 220, 190), L.char)
CO("Left Leg Color", "limb_lleg", Color3.fromRGB(30, 30, 40), L.char)
CO("Right Leg Color", "limb_rleg", Color3.fromRGB(30, 30, 40), L.char)
H("Trail Extras")
SL("Trail Start Transparency", "tr_tr", 0, 1, .1, 2, L.rig)
SL("Trail Width", "tr_w", .2, 4, 1, 2, L.rig)
DD("Trail Texture", "tr_tex", { "None", "Sparkles", "Smoke", "Fire" }, "None", L.rig)
T("Rainbow Trail", "tr_rain", false)

---------------------------------------------------------------- particle auras
H("Particle Auras (only you see them)")
local function charFx() L.charFx() end
for _, d in ipairs(EMD) do
	T(d.name .. " Aura", "ce_" .. d.key, false, charFx)
	CO(d.name .. " Aura Color", "cec_" .. d.key, d.col, charFx)
	SL(d.name .. " Aura Amount", "cer_" .. d.key, 1, 120, d.rate, 0, charFx)
end
H("Classic Effects")
T("Body Fire", "cf_fire", false, charFx)
CO("Fire Color", "cf_firec", Color3.fromRGB(255, 120, 20), charFx)
SL("Fire Size", "cf_firesz", 2, 20, 6, 0, charFx)
T("Body Smoke", "cf_smoke", false, charFx)
CO("Smoke Color", "cf_smokec", Color3.fromRGB(110, 110, 110), charFx)
SL("Smoke Size", "cf_smokesz", 1, 20, 5, 0, charFx)
SL("Smoke Opacity", "cf_smokeop", 0, 1, .5, 2, charFx)
T("Body Sparkles", "cf_spk", false, charFx)
CO("Sparkle Color", "cf_spkc", Color3.fromRGB(255, 240, 150), charFx)
H("Body Glow Light")
T("Body Light", "chl_on", false, charFx)
CO("Light Color", "chl_col", Color3.fromRGB(150, 200, 255), charFx)
SL("Light Range", "chl_rng", 4, 60, 18, 0, charFx)
SL("Light Brightness", "chl_br", 0, 6, 1.5, 1, charFx)
H("Custom Name Tag (only you see it)")
T("Name Tag Above Head", "nt_on", false, charFx)
IN("Name Tag Text", "nt_txt", "Sef's Ftap", charFx)
CO("Name Tag Color", "nt_col", Color3.fromRGB(240, 240, 240), charFx)
SL("Name Tag Size", "nt_sz", 10, 40, 22, 0, charFx)
SL("Name Tag Height", "nt_h", 1.5, 6, 3, 1, charFx)
T("Rainbow Name Tag", "nt_rain", false)

function L.charFx()
	local ch = LP.Character
	if not ch then return end
	local hrp, head = ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChild("Head")
	if not hrp then return end
	for _, d in ipairs(EMD) do
		L.ensure(hrp, "SefE_" .. d.key, "ParticleEmitter", L.emProps(d, S["cec_" .. d.key], S["cer_" .. d.key], true), S["ce_" .. d.key])
	end
	L.ensure(hrp, "SefFire", "Fire", { Color = S.cf_firec, SecondaryColor = S.cf_firec:Lerp(Color3.fromRGB(255, 60, 0), .5), Size = S.cf_firesz, Heat = 8 }, S.cf_fire)
	L.ensure(hrp, "SefSmoke", "Smoke", { Color = S.cf_smokec, Size = S.cf_smokesz, Opacity = S.cf_smokeop, RiseVelocity = 4 }, S.cf_smoke)
	L.ensure(hrp, "SefSpk", "Sparkles", { SparkleColor = S.cf_spkc }, S.cf_spk)
	L.ensure(hrp, "SefLight", "PointLight", { Color = S.chl_col, Range = S.chl_rng, Brightness = S.chl_br, Shadows = false }, S.chl_on)
	if head then
		local g = L.ensure(head, "SefNT", "BillboardGui", { Size = UDim2.fromOffset(260, 50), StudsOffset = Vector3.new(0, S.nt_h, 0), AlwaysOnTop = false }, S.nt_on)
		if g then
			local t = g:FindFirstChild("T")
			if not t then t = new("TextLabel", { Name = "T", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextStrokeTransparency = .35 }, g) end
			t.Text = S.nt_txt t.TextColor3 = S.nt_col t.TextSize = S.nt_sz
		end
	end
end

---------------------------------------------------------------- wings
H("Wings (local, neon)")
T("Wings", "wg_on", false, function() L.wings() end)
CO("Wing Color", "wg_col", Color3.fromRGB(235, 240, 255), function() L.wings() end)
SL("Wing Size", "wg_sz", .4, 3, 1, 2, function() L.wings() end)
SL("Feathers Per Wing", "wg_n", 3, 10, 6, 0, function() L.wings() end)
SL("Flap Speed", "wg_fs", 0, 12, 3, 1)
SL("Flap Amount", "wg_fa", 0, 40, 14, 0)
SL("Wing Transparency", "wg_tr", 0, .9, .25, 2, function() L.wings() end)
T("Wing Neon", "wg_neon", true, function() L.wings() end)
T("Rainbow Wings", "wg_rain", false)
local wings = { folder = nil, f = {} }
function L.wings()
	if wings.folder then wings.folder:Destroy() wings.folder = nil end
	wings.f = {}
	if not S.wg_on then return end
	wings.folder = new("Folder", { Name = "SefWings" }, fxFolder)
	for side = -1, 1, 2 do
		for i = 1, S.wg_n do
			local len = math.max(.8, (3.4 - (i - 1) * (2.4 / S.wg_n))) * S.wg_sz
			local p = new("Part", { Name = "SefWingPart", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = S.wg_neon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = S.wg_col, Transparency = S.wg_tr, Size = Vector3.new(.35 * S.wg_sz, len, .08) }, wings.folder)
			wings.f[#wings.f + 1] = { p = p, side = side, a = 12 + (i - 1) * (80 / S.wg_n), len = len, i = i }
		end
	end
end

---------------------------------------------------------------- orbiting orbs
H("Orbiting Orbs")
T("Orbiting Orbs", "ob_on", false, function() L.orbs() end)
SL("Orb Count", "ob_n", 1, 16, 5, 0, function() L.orbs() end)
CO("Orb Color", "ob_col", Color3.fromRGB(120, 200, 255), function() L.orbs() end)
SL("Orb Size", "ob_sz", .2, 2, .6, 2, function() L.orbs() end)
SL("Orbit Radius", "ob_r", 1.5, 8, 3.2, 1)
SL("Orbit Speed", "ob_sp", .2, 8, 1.6, 1)
SL("Orbit Height", "ob_h", -2, 4, .5, 1)
T("Rainbow Orbs", "ob_rain", false)
local orbs = { folder = nil, p = {} }
function L.orbs()
	if orbs.folder then orbs.folder:Destroy() orbs.folder = nil end
	orbs.p = {}
	if not S.ob_on then return end
	orbs.folder = new("Folder", { Name = "SefOrbs" }, fxFolder)
	for i = 1, S.ob_n do
		orbs.p[i] = new("Part", { Name = "SefOrb", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = S.ob_col, Size = Vector3.new(1, 1, 1) * S.ob_sz }, orbs.folder)
	end
end

---------------------------------------------------------------- magic circle
H("Magic Circle Under You")
T("Magic Circle", "mc_on", false, function() L.circle() end)
CO("Circle Color", "mc_col", Color3.fromRGB(170, 120, 255), function() L.circle() end)
SL("Circle Size", "mc_sz", 2, 14, 6, 1)
SL("Circle Spin Speed", "mc_sp", -6, 6, 1.2, 1)
SL("Circle Transparency", "mc_tr", 0, .9, .15, 2, function() L.circle() end)
T("Pulsing Circle", "mc_pulse", true)
local circ = { folder = nil, dots = {}, bars = {} }
function L.circle()
	if circ.folder then circ.folder:Destroy() circ.folder = nil end
	circ.dots, circ.bars = {}, {}
	if not S.mc_on then return end
	circ.folder = new("Folder", { Name = "SefCircle" }, fxFolder)
	local function mkp(size, shape)
		return new("Part", { Name = "SefCircPart", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = shape or Enum.PartType.Block, Material = Enum.Material.Neon, Color = S.mc_col, Transparency = S.mc_tr, Size = size }, circ.folder)
	end
	for i = 1, 28 do circ.dots[i] = mkp(Vector3.new(.35, .35, .35), Enum.PartType.Ball) end
	for i = 1, 3 do circ.bars[i] = mkp(Vector3.new(1, .08, .18)) end
end

---------------------------------------------------------------- jump / land rings
H("Jump And Landing Effects")
T("Jump Ring", "jr_on", false)
CO("Jump Ring Color", "jr_col", Color3.fromRGB(120, 220, 255))
SL("Jump Ring Size", "jr_sz", 4, 40, 14, 0)
T("Landing Shockwave", "ld_on", false)
CO("Landing Color", "ld_col", Color3.fromRGB(255, 220, 140))
SL("Landing Size", "ld_sz", 4, 60, 22, 0)
local hconn
local function hook()
	if hconn then hconn:Disconnect() hconn = nil end
	local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hconn = hum.StateChanged:Connect(function(_, ns)
		local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local pos = hrp.Position - Vector3.new(0, 2.8, 0)
		if ns == Enum.HumanoidStateType.Jumping and S.jr_on then ring(pos, S.jr_col, S.jr_sz, .5) end
		if ns == Enum.HumanoidStateType.Landed and S.ld_on then
			ring(pos, S.ld_col, S.ld_sz, .6)
			burst(pos, S.ld_col, 10, 10, .6, .6)
		end
	end)
end

---------------------------------------------------------------- per-frame
L.steps[#L.steps + 1] = function(dt, t)
	local ch = LP.Character
	if not ch then return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local torso = ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso")
	local head = ch:FindFirstChild("Head")
	if S.tr_rain and hrp then
		local tr = hrp:FindFirstChild("SefTrail")
		if tr then tr.Color = ColorSequence.new(hsv(t * .5)) end
	end
	if S.nt_rain and head then
		local g = head:FindFirstChild("SefNT")
		if g and g:FindFirstChild("T") then g.T.TextColor3 = hsv(t * .4) end
	end
	if #wings.f > 0 and torso then
		local flap = math.sin(t * S.wg_fs) * S.wg_fa
		local rc = S.wg_rain and hsv(t * .4) or nil
		for _, e in ipairs(wings.f) do
			local a = math.rad(e.a + flap * (1 + e.i * .06))
			e.p.CFrame = torso.CFrame * CFrame.new(e.side * .5, .4, .55) * CFrame.Angles(0, e.side * math.rad(25), 0) * CFrame.Angles(0, 0, -e.side * a) * CFrame.new(0, e.len / 2, 0)
			if rc then e.p.Color = rc end
		end
	end
	if #orbs.p > 0 and hrp then
		local n = #orbs.p
		for i, p in ipairs(orbs.p) do
			local ang = t * S.ob_sp + i / n * math.pi * 2
			p.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(ang) * S.ob_r, S.ob_h + math.sin(t * 2 + i) * .3, math.sin(ang) * S.ob_r))
			if S.ob_rain then p.Color = hsv(t * .4 + i / n) end
		end
	end
	if circ.folder and hrp then
		local gy = L.groundY(hrp.Position) or (hrp.Position.Y - 3)
		local c = Vector3.new(hrp.Position.X, gy + .1, hrp.Position.Z)
		local r = S.mc_sz * (S.mc_pulse and (1 + .06 * math.sin(t * 3)) or 1) / 2
		local rot = t * S.mc_sp
		for i, d in ipairs(circ.dots) do
			local a = i / #circ.dots * math.pi * 2 + rot
			d.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
		for i, b in ipairs(circ.bars) do
			b.Size = Vector3.new(r * 2, .08, .18)
			b.CFrame = CFrame.new(c) * CFrame.Angles(0, rot + (i - 1) * math.pi / 3, 0)
		end
	end
end

L.onChar[#L.onChar + 1] = function()
	hook()
	L.charFx() L.wings() L.orbs() L.circle()
end
L.cleanups[#L.cleanups + 1] = function() if hconn then hconn:Disconnect() end end
task.defer(function() pcall(hook) end)
end)

-- module: 04_players
MOD("04_players", function()
local S, Ctl, L, T, SL, CO, DD, B, H, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.tab
local new, hsv, LP, Players, cam = U.new, U.hsv, U.LP, U.Players, U.cam
L.tabs.Players = tab("Players", 7)
local dirty = true
local function mark() dirty = true end
H("Other Players (local visuals only)")
T("Enable Player Visuals", "pl_on", false, mark)
T("Ghost Players", "pl_ghost", false, mark)
SL("Ghost Transparency", "pl_gtr", 0, .95, .6, 2, mark)
T("Neon Players", "pl_neon", false, mark)
T("Tint Players", "pl_tint", false, mark)
CO("Player Tint Color", "pl_col", Color3.fromRGB(255, 120, 200), mark)
T("Rainbow Players", "pl_rain", false, mark)
SL("Rainbow Speed", "pl_rs", .05, 3, .4, 2)
T("Player Outline Glow", "pl_hl", false, mark)
CO("Outline Color", "pl_hlc", Color3.fromRGB(255, 255, 255), mark)
SL("Outline Fill", "pl_hlf", 0, 1, .7, 2, mark)
T("Hide Player Names", "pl_nm", false, mark)
T("Hide Health Bars", "pl_hp", false, mark)
T("Hide Accessories", "pl_acc", false, mark)
T("Hide Faces", "pl_face", false, mark)
T("Player Trails", "pl_tr", false, mark)
CO("Player Trail Color", "pl_trc", Color3.fromRGB(255, 255, 255), mark)
T("Player Aura Sparkles", "pl_au", false, mark)
CO("Aura Color", "pl_auc", Color3.fromRGB(255, 240, 160), mark)
T("Distance Labels", "pl_lbl", false, mark)
CO("Label Color", "pl_lblc", Color3.fromRGB(255, 255, 255), mark)
T("Hide Far Players", "pl_far", false, mark)
SL("Hide Beyond (studs)", "pl_fard", 20, 600, 150, 0, mark)

local orig = setmetatable({}, { __mode = "k" })
local MATS = U.MATS
local function restore(ch)
	for _, p in ipairs(ch:GetDescendants()) do
		local o = orig[p]
		if o then
			pcall(function() p.Color = o.c p.Material = o.m p.Transparency = o.t end)
			orig[p] = nil
		elseif p.Name:sub(1, 4) == "SefP" then p:Destroy() end
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function() hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged end)
	end
end
local acc = 0
L.steps[#L.steps + 1] = function(dt, t)
	acc = acc + dt
	if acc < (S.pl_rain and .08 or .3) then return end
	acc = 0
	local was = dirty
	dirty = false
	local c = cam()
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		if pl ~= LP and ch then
			if not S.pl_on then
				if was then restore(ch) end
			else
				local hrp = ch:FindFirstChild("HumanoidRootPart")
				local dist = (hrp and c) and (hrp.Position - c.CFrame.Position).Magnitude or 0
				local far = S.pl_far and dist > S.pl_fard
				local col = S.pl_tint and S.pl_col or nil
				if S.pl_rain then col = hsv(t * S.pl_rs) end
				for _, p in ipairs(ch:GetDescendants()) do
					if p:IsA("BasePart") then
						local o = orig[p]
						if not o then o = { c = p.Color, m = p.Material, t = p.Transparency } orig[p] = o end
						local tr = o.t
						if S.pl_ghost then tr = math.max(tr, S.pl_gtr) end
						if S.pl_acc and p.Parent:IsA("Accessory") then tr = 1 end
						if far then tr = 1 end
						p.Color = col or o.c
						p.Material = S.pl_neon and Enum.Material.Neon or o.m
						p.Transparency = tr
					elseif p:IsA("Decal") and S.pl_face and p.Name == "face" then
						p.Transparency = 1
					end
				end
				local hum = ch:FindFirstChildOfClass("Humanoid")
				if hum then
					pcall(function()
						hum.DisplayDistanceType = S.pl_nm and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
						hum.HealthDisplayType = S.pl_hp and Enum.HumanoidHealthDisplayType.AlwaysOff or Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
					end)
				end
				if hrp then
					L.ensure(ch, "SefPHL", "Highlight", { FillColor = S.pl_hlc, OutlineColor = S.pl_hlc, FillTransparency = S.pl_hlf }, S.pl_hl and not far)
					L.ensure(hrp, "SefPAu", "ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 20, Lifetime = NumberRange.new(.8, 1.4), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(.6, 0), LightEmission = 1, Color = ColorSequence.new(S.pl_auc), Transparency = NumberSequence.new(0, 1) }, S.pl_au and not far)
					local tr = L.ensure(hrp, "SefPTr", "Trail", { Lifetime = .8, Color = ColorSequence.new(S.pl_trc), LightEmission = 1, Transparency = NumberSequence.new(.1, 1), FaceCamera = true }, S.pl_tr and not far)
					if tr and not tr.Attachment0 then
						tr.Attachment0 = new("Attachment", { Name = "SefPA0", Position = Vector3.new(0, 1, 0) }, hrp)
						tr.Attachment1 = new("Attachment", { Name = "SefPA1", Position = Vector3.new(0, -1, 0) }, hrp)
					end
					if not S.pl_tr then
						for _, n in ipairs({ "SefPA0", "SefPA1" }) do local a = hrp:FindFirstChild(n) if a then a:Destroy() end end
					end
					local g = L.ensure(hrp, "SefPLbl", "BillboardGui", { Size = UDim2.fromOffset(150, 28), StudsOffset = Vector3.new(0, 3.6, 0), AlwaysOnTop = true }, S.pl_lbl and not far)
					if g then
						local tl = g:FindFirstChild("T")
						if not tl then tl = new("TextLabel", { Name = "T", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextStrokeTransparency = .3 }, g) end
						tl.TextColor3 = S.pl_lblc
						tl.Text = pl.DisplayName .. "  " .. math.floor(dist) .. "m"
					end
				end
			end
		end
	end
end
L.cleanups[#L.cleanups + 1] = function()
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP and pl.Character then pcall(restore, pl.Character) end
	end
end
end)

-- module: 05_toys
MOD("05_toys", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, H, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.H, U.tab
local new, hsv, LP, Players, cam, ring, burst, notify = U.new, U.hsv, U.LP, U.Players, U.cam, U.ring, U.burst, U.notify
local MATS, MATN = U.MATS, U.MATN
L.tabs.Toys = tab("Toys", 10)
local dirty = true
local function mark() dirty = true end

H("Global Toy Effects (pallets use the Pallets tab)")
T("Enable Toy Effects", "toy_on", false, mark)
T("Apply To Everyone's Toys", "toy_all", false, mark)
SL("Only Within Studs (0 = no limit)", "toy_rad", 0, 600, 0, 0, mark)
T("Strip Textures When Recoloring (needed for color on textured toys)", "toy_strip", true, mark)
T("Pulse Transparency", "toy_pulse", false, mark)
SL("Pulse Speed", "toy_pulsespd", .2, 4, 1.2, 1)
SL("Pulse Amount", "toy_pulseamt", 0, .9, .4, 2)
T("Tint Toys", "toy_tint", false, mark)
CO("Toy Tint Color", "toy_col", Color3.fromRGB(120, 200, 255), mark)
T("Rainbow Toys", "toy_rain", false, mark)
SL("Rainbow Speed", "toy_rs", .05, 3, .4, 2)
DD("Toy Material", "toy_mat", MATN, "Default", mark)
T("Neon Toys", "toy_neon", false, mark)
SL("Toy Transparency", "toy_tr", 0, .95, 0, 2, mark)
SL("Toy Reflectance", "toy_ref", 0, 1, 0, 2, mark)
T("Toy Outline Glow (max ~30 at once)", "toy_hl", false, mark)
CO("Outline Color", "toy_hlc", Color3.fromRGB(255, 255, 255), mark)
SL("Outline Fill", "toy_hlf", 0, 1, .8, 2, mark)
T("Toy Sparkles", "toy_spk", false, mark)
CO("Sparkle Color", "toy_spkc", Color3.fromRGB(255, 240, 160), mark)
T("Toy Fire", "toy_fire", false, mark)
CO("Fire Color", "toy_firec", Color3.fromRGB(255, 120, 20), mark)
T("Toy Smoke", "toy_smoke", false, mark)
T("Toy Glow Light", "toy_light", false, mark)
CO("Light Color", "toy_lightc", Color3.fromRGB(255, 255, 255), mark)
SL("Light Range", "toy_lightr", 4, 40, 12, 0, mark)
T("Toy Trails", "toy_trail", false, mark)
CO("Trail Color", "toy_trailc", Color3.fromRGB(120, 200, 255), mark)
SL("Trail Lifetime", "toy_trailr", .1, 3, .6, 1, mark)
T("Toy Name Labels", "toy_lbl", false, mark)
SL("Label Size", "toy_lblsz", 10, 30, 14, 0, mark)
T("Spawn Pop Effect", "toy_pop", false)
CO("Pop Color", "toy_popc", Color3.fromRGB(120, 255, 200))
SL("Pop Size", "toy_pops", 4, 30, 10, 0)
T("Despawn Poof Effect", "toy_poof", false)
CO("Poof Color", "toy_poofc", Color3.fromRGB(255, 160, 160))

-- per-toy-type recolor groups (match by name keyword)
local GROUPS = {}
local KW = { { "Planks", "plank" }, { "Balls", "ball" }, { "Cubes", "cube" }, { "Missiles", "missile" }, { "Bombs", "bomb" }, { "Chairs", "chair" },
	{ "Couches", "couch" }, { "Tables", "table" }, { "Trees", "tree" }, { "Logs", "log" }, { "Bricks", "brick" }, { "Cones", "cone" },
	{ "Barrels", "barrel" }, { "Crates", "crate" }, { "Tires", "tire" }, { "Signs", "sign" }, { "Bananas", "banana" }, { "Cakes", "cake" },
	{ "Fish", "fish" }, { "Ducks", "duck" }, { "Cats", "cat" }, { "Dogs", "dog" }, { "Swords", "sword" }, { "Snowballs", "snow" },
	{ "Ice Toys", "ice" }, { "Fireworks", "firework" }, { "Boomboxes", "boombox" }, { "Trampolines", "trampoline" }, { "Beds", "bed" },
	{ "Lamps", "lamp" }, { "Cars", "car" }, { "Boats", "boat" } }
H("Recolor By Toy Type")
for i, e in ipairs(KW) do
	T(e[1] .. " Recolor", "tg_" .. i, false, mark)
	CO(e[1] .. " Color", "tgc_" .. i, hsv(i / #KW, .75, 1), mark)
	DD(e[1] .. " Material", "tgm_" .. i, MATN, "Default", mark)
	GROUPS[#GROUPS + 1] = { kw = e[2], on = "tg_" .. i, col = "tgc_" .. i, mat = "tgm_" .. i }
end
H("Custom Keyword Groups (type any part of a toy name)")
for i = 1, 5 do
	IN("Custom Group " .. i .. " Keyword", "tk_" .. i, "", mark)
	T("Custom Group " .. i .. " Recolor", "tkg_" .. i, false, mark)
	CO("Custom Group " .. i .. " Color", "tkc_" .. i, hsv(i / 5, .6, 1), mark)
	DD("Custom Group " .. i .. " Material", "tkm_" .. i, MATN, "Neon", mark)
	GROUPS[#GROUPS + 1] = { kwk = "tk_" .. i, on = "tkg_" .. i, col = "tkc_" .. i, mat = "tkm_" .. i }
end
H("Tools")
B("Show Toy Names (find keywords)", function()
	local seen, order = {}, {}
	for _, f in ipairs(L.toyFolders(true)) do
		for _, m in ipairs(f:GetChildren()) do
			if not seen[m.Name] then seen[m.Name] = 0 order[#order + 1] = m.Name end
			seen[m.Name] = seen[m.Name] + 1
		end
	end
	table.sort(order)
	local lines = {}
	for _, n in ipairs(order) do lines[#lines + 1] = n .. " x" .. seen[n] end
	if L.showList then L.showList("Toys in server", lines) end
	pcall(function() if setclipboard then setclipboard(table.concat(lines, "\n")) end end)
end)
B("Scan Toys (how many were found)", function()
	local fs, tot, mine = L.toyFolders(true), 0, 0
	for _, f in ipairs(fs) do
		local n = #f:GetChildren()
		tot = tot + n
		if f.Name == LP.Name .. "SpawnedInToys" then mine = n end
	end
	notify("Sef's Ftap Visuals", string.format("%d toy folder(s), %d toys total, %d are yours.", #fs, tot, mine))
end)
B("Restore All Toys", function()
	Ctl.toy_on.set(false)
	for i = 1, #GROUPS do if Ctl[GROUPS[i].on] then Ctl[GROUPS[i].on].set(false, true) end end
	mark()
end)

local orig = setmetatable({}, { __mode = "k" })
local function partsIn(m)
	local list = m:GetDescendants()
	if m:IsA("BasePart") then list[#list + 1] = m end
	return list
end
local function restoreModel(m)
	for _, p in ipairs(partsIn(m)) do
		local o = orig[p]
		if o then
			pcall(function()
				p.Color = o.c p.Material = o.m p.Transparency = o.t p.Reflectance = o.r
				if o.tex ~= nil and p:IsA("MeshPart") then p.TextureID = o.tex end
				if o.sas then for _, sa in ipairs(o.sas) do sa.Parent = p end end
			end)
			orig[p] = nil
		end
	end
end
function L.bigPart(m)
	if m:IsA("BasePart") then return m end
	local best, bv = nil, -1
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local s = d.Size
			local v = s.X * s.Y * s.Z
			if v > bv then best, bv = d, v end
		end
	end
	return best
end
local function groupsOn()
	for _, g in ipairs(GROUPS) do if S[g.on] then return true end end
	return false
end
local function specFor(m)
	local nm = m.Name:lower()
	local base
	if S.toy_on then
		base = { col = S.toy_tint and S.toy_col or nil, rain = S.toy_rain, mat = (S.toy_neon and Enum.Material.Neon) or MATS[S.toy_mat] or nil, tr = S.toy_tr, ref = S.toy_ref }
	end
	for _, g in ipairs(GROUPS) do
		if S[g.on] then
			local kw = (g.kw or S[g.kwk] or ""):lower()
			if kw ~= "" and nm:find(kw, 1, true) then
				local sp = { tr = base and base.tr or 0, ref = base and base.ref or 0 }
				sp.col = S[g.col]
				sp.mat = MATS[S[g.mat]] or nil
				return sp
			end
		end
	end
	return base
end
local function appear(m, sp, t)
	local recolor = sp.rain or sp.col ~= nil
	local trv = sp.tr or 0
	if S.toy_pulse then trv = math.clamp(trv + (math.sin(t * S.toy_pulsespd * 3) + 1) / 2 * S.toy_pulseamt, 0, .95) end
	for _, p in ipairs(partsIn(m)) do
		if p:IsA("BasePart") then
			local o = orig[p]
			if not o then
				o = { c = p.Color, m = p.Material, t = p.Transparency, r = p.Reflectance }
				if p:IsA("MeshPart") then o.tex = p.TextureID end
				orig[p] = o
			end
			if recolor and S.toy_strip then
				if p:IsA("MeshPart") and p.TextureID ~= "" then p.TextureID = "" end
				for _, ch in ipairs(p:GetChildren()) do
					if ch:IsA("SurfaceAppearance") then
						o.sas = o.sas or {}
						o.sas[#o.sas + 1] = ch
						ch.Parent = nil
					end
				end
			end
			p.Color = sp.rain and hsv(t * S.toy_rs) or sp.col or o.c
			p.Material = sp.mat or o.m
			p.Transparency = math.max(o.t, trv)
			p.Reflectance = (sp.ref and sp.ref > 0) and sp.ref or o.r
		end
	end
end
local function fxModel(m, on)
	local main = L.bigPart(m)
	if not main then return end
	L.ensure(main, "SefTSpk", "ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 15, Lifetime = NumberRange.new(.6, 1), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(.5, 0), LightEmission = 1, Color = ColorSequence.new(S.toy_spkc), Transparency = NumberSequence.new(0, 1) }, on and S.toy_spk)
	L.ensure(main, "SefTFire", "Fire", { Color = S.toy_firec, SecondaryColor = S.toy_firec:Lerp(Color3.fromRGB(255, 60, 0), .5), Size = math.clamp(main.Size.Magnitude, 2, 14), Heat = 8 }, on and S.toy_fire)
	L.ensure(main, "SefTSmoke", "Smoke", { Color = Color3.fromRGB(110, 110, 110), Size = math.clamp(main.Size.Magnitude, 2, 14), Opacity = .5, RiseVelocity = 4 }, on and S.toy_smoke)
	L.ensure(main, "SefTLight", "PointLight", { Color = S.toy_lightc, Range = S.toy_lightr, Brightness = 1.5, Shadows = false }, on and S.toy_light)
	L.ensure(m, "SefTHL", "Highlight", { FillColor = S.toy_hlc, OutlineColor = S.toy_hlc, FillTransparency = S.toy_hlf }, on and S.toy_hl)
	local tr = L.ensure(main, "SefTTrail", "Trail", { Color = ColorSequence.new(S.toy_trailc), Lifetime = S.toy_trailr, LightEmission = 1, Transparency = NumberSequence.new(.1, 1), FaceCamera = true }, on and S.toy_trail)
	if tr and not tr.Attachment0 then
		local h = math.max(.5, main.Size.Y / 2)
		tr.Attachment0 = new("Attachment", { Name = "SefTA0", Position = Vector3.new(0, h, 0) }, main)
		tr.Attachment1 = new("Attachment", { Name = "SefTA1", Position = Vector3.new(0, -h, 0) }, main)
	elseif not (on and S.toy_trail) then
		for _, n in ipairs({ "SefTA0", "SefTA1" }) do local a = main:FindFirstChild(n) if a then a:Destroy() end end
	end
	local g = L.ensure(main, "SefTLbl", "BillboardGui", { Size = UDim2.fromOffset(160, 26), StudsOffset = Vector3.new(0, main.Size.Y / 2 + 1.5, 0), AlwaysOnTop = true }, on and S.toy_lbl)
	if g then
		local tl = g:FindFirstChild("T")
		if not tl then tl = new("TextLabel", { Name = "T", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = .3 }, g) end
		tl.Text = m.Name tl.TextSize = S.toy_lblsz
	end
end

local acc = 0
L.steps[#L.steps + 1] = function(dt, t)
	acc = acc + dt
	if acc < ((S.toy_rain or S.toy_pulse) and .06 or .25) then return end
	acc = 0
	local anyOn = S.toy_on or groupsOn()
	if not anyOn and not dirty then return end
	local was = dirty
	dirty = false
	local mine = LP.Name .. "SpawnedInToys"
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local rad = S.toy_rad or 0
	for _, f in ipairs(L.toyFolders(true)) do
		local scopeF = S.toy_all or f.Name == mine
		for _, m in ipairs(f:GetChildren()) do
			if not m.Name:lower():find("pallet", 1, true) then
				local inScope = scopeF
				if inScope and rad > 0 and hrp then
					local okp, pv = pcall(function() return m:GetPivot().Position end)
					if okp and (pv - hrp.Position).Magnitude > rad then inScope = false end
				end
				if inScope then
					local sp = specFor(m)
					if sp then appear(m, sp, t) elseif was then restoreModel(m) end
					if S.toy_on or was then fxModel(m, S.toy_on) end
				elseif was then
					restoreModel(m)
					fxModel(m, false)
				end
			end
		end
	end
end

-- spawn / despawn effects
local hooked = {}
local function pivot(m)
	local ok, p = pcall(function() return m:GetPivot().Position end)
	return ok and p or nil
end
local function hookFolder(f)
	if hooked[f] or not f.Name:find("SpawnedInToys") then return end
	hooked[f] = true
	f.ChildAdded:Connect(function(m)
		if not (L.alive() and S.toy_pop) then return end
		task.defer(function()
			local p = pivot(m)
			if p then ring(p, S.toy_popc, S.toy_pops, .6) burst(p, S.toy_popc, 12, 12, .7, .6) end
		end)
	end)
	f.ChildRemoved:Connect(function(m)
		if not (L.alive() and S.toy_poof) then return end
		local p = pivot(m)
		if p then ring(p, S.toy_poofc, S.toy_pops, .6) burst(p, S.toy_poofc, 20, 16, .8, .8) end
	end)
end
for _, c in ipairs(workspace:GetChildren()) do hookFolder(c) end
U.C(workspace.ChildAdded, hookFolder)

L.cleanups[#L.cleanups + 1] = function()
	for _, f in ipairs(L.toyFolders(true)) do
		for _, m in ipairs(f:GetChildren()) do pcall(restoreModel, m) end
	end
end
end)

-- module: 06_world
MOD("06_world", function()
local S, Ctl, L, T, SL, CO, DD, B, H, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.tab
local hsv, LP, Players, notify, fxFolder = U.hsv, U.LP, U.Players, U.notify, U.fxFolder
local MATS, MATN = U.MATS, U.MATN
L.tabs.World = tab("World", 13)
local terrain = workspace:FindFirstChildOfClass("Terrain")

---------------------------------------------------------------- water
H("Water")
local function water()
	if not terrain or not S.wt_on then return end
	pcall(function()
		terrain.WaterColor = S.wt_col terrain.WaterTransparency = S.wt_tr
		terrain.WaterWaveSize = S.wt_ws terrain.WaterWaveSpeed = S.wt_sp terrain.WaterReflectance = S.wt_rf
	end)
end
local wOrig = terrain and { terrain.WaterColor, terrain.WaterTransparency, terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance }
T("Custom Water", "wt_on", false, function(v)
	if v then water()
	elseif wOrig then pcall(function() terrain.WaterColor, terrain.WaterTransparency, terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance = wOrig[1], wOrig[2], wOrig[3], wOrig[4], wOrig[5] end) end
end)
CO("Water Color", "wt_col", wOrig and wOrig[1] or Color3.fromRGB(12, 84, 91), water)
SL("Water Transparency", "wt_tr", 0, 1, wOrig and wOrig[2] or .3, 2, water)
SL("Wave Size", "wt_ws", 0, 1, wOrig and wOrig[3] or .15, 2, water)
SL("Wave Speed", "wt_sp", 0, 100, wOrig and wOrig[4] or 10, 0, water)
SL("Water Reflectance", "wt_rf", 0, 1, wOrig and wOrig[5] or 1, 2, water)

---------------------------------------------------------------- terrain material colors
H("Terrain Material Colors")
local TM = { "Grass", "LeafyGrass", "Sand", "Sandstone", "Rock", "Slate", "Basalt", "Mud", "Ground", "Snow", "Ice", "Glacier", "Asphalt", "Brick", "Cobblestone", "Concrete", "Pavement", "Salt", "Limestone", "WoodPlanks", "CrackedLava" }
local tOrig = {}
local tOn = false
T("Apply Terrain Colors", "tm_on", false, function(v)
	tOn = v
	for _, n in ipairs(TM) do
		pcall(function()
			local m = Enum.Material[n]
			if v then terrain:SetMaterialColor(m, S["tm_" .. n]) elseif tOrig[n] then terrain:SetMaterialColor(m, tOrig[n]) end
		end)
	end
end)
for _, n in ipairs(TM) do
	local def = Color3.new(.5, .5, .5)
	pcall(function() def = terrain:GetMaterialColor(Enum.Material[n]) end)
	tOrig[n] = def
	CO(n .. " Terrain Color", "tm_" .. n, def, function(c) if tOn then pcall(function() terrain:SetMaterialColor(Enum.Material[n], c) end) end end)
end
T("Rainbow Terrain", "tm_rain", false, function(v)
	if not v and tOn then for _, n in ipairs(TM) do pcall(function() terrain:SetMaterialColor(Enum.Material[n], S["tm_" .. n]) end) end end
end)
SL("Rainbow Terrain Speed", "tm_rs", .05, 3, .3, 2)

---------------------------------------------------------------- part recolor engine
H("Map Parts (recolor by material)")
local wm = { all = {}, by = {}, scanned = false, scanning = false }
local wOrigP = setmetatable({}, { __mode = "k" })
local applying, again = false, false
local function isMapPart(p)
	if not p:IsA("BasePart") or not p.Anchored then return false end
	if p:IsDescendantOf(fxFolder) or p:IsDescendantOf(workspace.CurrentCamera) then return false end
	local m = p:FindFirstAncestorWhichIsA("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return false end
		if m.Name:find("SpawnedInToys") or m.Name == "GrabParts" then return false end
		m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model")
	end
	local par = p.Parent
	while par and par ~= workspace do
		if par.Name:find("SpawnedInToys") or par.Name == "GrabParts" then return false end
		par = par.Parent
	end
	return true
end
function L.worldScan(cb)
	if wm.scanning then return end
	wm.scanning = true
	task.spawn(function()
		local all, by = {}, {}
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			n = n + 1
			if n % 600 == 0 then task.wait() end
			if d:IsA("BasePart") and d ~= nil and not d:IsA("Terrain") and isMapPart(d) then
				all[#all + 1] = d
				local k = d.Material.Name
				by[k] = by[k] or {}
				by[k][#by[k] + 1] = d
			end
		end
		wm.all, wm.by, wm.scanned, wm.scanning = all, by, true, false
		notify("Sef's Ftap Visuals", "Map scanned: " .. #all .. " parts.")
		if cb then cb() end
	end)
end
local PM = { "Grass", "Concrete", "Sand", "Slate", "Granite", "Marble", "Brick", "Wood", "WoodPlanks", "Metal", "Plastic", "SmoothPlastic", "Ground", "Cobblestone", "Asphalt", "Pavement" }
local function anyWorld()
	if S.wm_tint or S.wm_rain or S.wm_ref > 0 or (S.wm_mat ~= "Default") then return true end
	for _, n in ipairs(PM) do if S["pm_" .. n] then return true end end
	return false
end
local function worldApply(t)
	if not wm.scanned then L.worldScan(function() worldApply(t) end) return end
	if applying then again = true return end
	applying = true
	task.spawn(function()
		local on = anyWorld()
		local tintc = S.wm_rain and hsv(t * S.wm_rs) or (S.wm_tint and S.wm_col) or nil
		local mt = MATS[S.wm_mat]
		local n = 0
		for _, p in ipairs(wm.all) do
			n = n + 1
			if n % 500 == 0 then task.wait() end
			pcall(function()
				local o = wOrigP[p]
				if on then
					if not o then o = { c = p.Color, m = p.Material, r = p.Reflectance } wOrigP[p] = o end
					local mk = o.m.Name
					local col = tintc or o.c
					if S["pm_" .. mk] then col = S["pmc_" .. mk] end
					p.Color = col
					p.Material = mt or o.m
					p.Reflectance = S.wm_ref > 0 and S.wm_ref or o.r
				elseif o then
					p.Color = o.c p.Material = o.m p.Reflectance = o.r
					wOrigP[p] = nil
				end
			end)
		end
		applying = false
		if again then again = false end
	end)
end
local function ap() worldApply(tick()) end
B("Rescan Map Parts", function() wm.scanned = false L.worldScan(ap) end)
T("Tint Whole Map", "wm_tint", false, ap)
CO("Map Tint Color", "wm_col", Color3.fromRGB(150, 120, 255), ap)
T("Rainbow Map", "wm_rain", false, ap)
SL("Rainbow Map Speed", "wm_rs", .05, 2, .25, 2)
DD("Map Material Override", "wm_mat", MATN, "Default", ap)
SL("Map Reflectance", "wm_ref", 0, 1, 0, 2, ap)
for _, n in ipairs(PM) do
	T(n .. " Parts Recolor", "pm_" .. n, false, ap)
	CO(n .. " Parts Color", "pmc_" .. n, hsv(#n / 14, .6, 1), ap)
end

local acc = 0
L.steps[#L.steps + 1] = function(dt, t)
	acc = acc + dt
	if acc < .3 then return end
	acc = 0
	if S.tm_rain and tOn then
		for i, n in ipairs(TM) do pcall(function() terrain:SetMaterialColor(Enum.Material[n], hsv(t * S.tm_rs + i / #TM)) end) end
	end
	if S.wm_rain then worldApply(t) end
end
L.cleanups[#L.cleanups + 1] = function()
	for p, o in pairs(wOrigP) do pcall(function() p.Color = o.c p.Material = o.m p.Reflectance = o.r end) end
	if tOn then for _, n in ipairs(TM) do pcall(function() terrain:SetMaterialColor(Enum.Material[n], tOrig[n]) end) end end
	if wOrig and S.wt_on then pcall(function() terrain.WaterColor, terrain.WaterTransparency, terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance = wOrig[1], wOrig[2], wOrig[3], wOrig[4], wOrig[5] end) end
end
end)

-- module: 07_fling
MOD("07_fling", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, H, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.H, U.tab
local new, tw, hsv, LP, cam, ring, burst, hud, flashF = U.new, U.tw, U.hsv, U.LP, U.cam, U.ring, U.burst, U.hud, U.flashF
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local st = { flings = 0, max = 0, air = 0, last = 0, cool = 0, imp = 0, home = nil }
L.fling = st
L.onFling = {}
L.tabs["Fling FX"] = tab("Fling FX", 11)

H("Fling Detector")
T("Fling Detector", "fl_on", false)
SL("Fling Speed Threshold", "fl_th", 30, 400, 80, 0)
H("When You Get Flung")
T("Screen Flash", "fl_flash", true)
CO("Flash Color", "fl_flashc", Color3.fromRGB(255, 255, 255))
T("Camera Shake", "fl_shk", true)
SL("Shake Strength", "fl_shkamt", 0, 2, .7, 2)
T("FOV Kick", "fl_kick", true)
SL("FOV Kick Amount", "fl_kickamt", 0, 40, 18, 0)
T("Shockwave Ring", "fl_ring", true)
CO("Ring Color", "fl_ringc", Color3.fromRGB(120, 220, 255))
SL("Ring Size", "fl_ringsz", 5, 80, 28, 0)
T("Popup Text", "fl_text", true)
IN("Popup Text Message", "fl_txt", "FLUNG!")
CO("Popup Color", "fl_txtc", Color3.fromRGB(255, 230, 120))
SL("Popup Size", "fl_txtsz", 18, 80, 40, 0)
T("Dizzy Stars", "fl_stars", false)
SL("Dizzy Duration", "fl_stardur", .5, 6, 2.5, 1)
CO("Star Color", "fl_starc", Color3.fromRGB(255, 240, 100))
H("While Moving Fast")
T("Speed Lines", "fl_sl", false)
SL("Speed Lines Start Speed", "fl_slth", 20, 300, 60, 0)
CO("Speed Lines Color", "fl_slc", Color3.fromRGB(255, 255, 255))
SL("Speed Lines Opacity", "fl_slop", 0, 1, .6, 2)
SL("Speed Lines Length", "fl_sllen", 20, 300, 120, 0)
T("Trail Color By Speed", "fl_trcol", false)
H("Impacts")
T("Impact Dust (hard stop)", "fl_imp", true)
SL("Impact Sensitivity (speed drop)", "fl_impth", 20, 200, 60, 0)
CO("Impact Dust Color", "fl_impc", Color3.fromRGB(200, 190, 170))
H("Stats")
B("Reset Fling Stats", function() st.flings = 0 st.max = 0 st.air = 0 end)

local popup = new("TextLabel", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .3), Size = UDim2.fromOffset(500, 80), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextStrokeTransparency = .2, Visible = false, ZIndex = 8, Text = "" }, hud)

local slData, slFrames = {}, {}
for i = 1, 28 do
	slData[i] = { r = math.random() * 400, a = math.random() * math.pi * 2, v = math.random() }
	slFrames[i] = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, AnchorPoint = Vector2.new(.5, .5), ZIndex = 0 }, hud)
end
local stars = { parts = {}, untilT = 0 }
local function starsOff()
	for _, p in ipairs(stars.parts) do p:Destroy() end
	stars.parts = {}
end
local function trigger(hrp, sp)
	st.flings = st.flings + 1
	for _, fn in ipairs(L.onFling) do pcall(fn, sp) end
	if S.fl_flash then flashF.BackgroundColor3 = S.fl_flashc flashF.BackgroundTransparency = .55 tw(flashF, .5, { BackgroundTransparency = 1 }) end
	if S.fl_shk then L.addShake(S.fl_shkamt) end
	if S.fl_kick then L.kick = math.max(L.kick, S.fl_kickamt) end
	if S.fl_ring then ring(hrp.Position, S.fl_ringc, S.fl_ringsz, .7) end
	if S.fl_text then
		popup.Text = S.fl_txt .. "  " .. math.floor(sp)
		popup.TextColor3 = S.fl_txtc popup.TextSize = S.fl_txtsz
		popup.TextTransparency = 0 popup.TextStrokeTransparency = .2
		popup.Position = UDim2.fromScale(.5, .3)
		popup.Visible = true
		tw(popup, 1.3, { Position = UDim2.fromScale(.5, .2), TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(1.4, function() popup.Visible = false end)
	end
	if S.fl_stars then
		stars.untilT = tick() + S.fl_stardur
		if #stars.parts == 0 then
			for i = 1, 5 do
				stars.parts[i] = new("Part", { Name = "SefStarOrb", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = S.fl_starc, Size = Vector3.new(.5, .5, .5) }, U.fxFolder)
			end
		end
	end
end
local function impact(hrp, speed)
	local pos = hrp.Position - Vector3.new(0, 2.5, 0)
	ring(pos, S.fl_impc, 12 + speed * .1, .5)
	burst(pos, S.fl_impc, 25, 18, 1, 2, SMOKE, Vector3.new(0, 2, 0))
	L.addShake(math.min(.6, speed / 300))
end

L.steps[#L.steps + 1] = function(dt, t)
	local ch = LP.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not st.home then st.home = hrp.Position end
	local sp = hrp.AssemblyLinearVelocity.Magnitude
	if sp > st.max then st.max = sp end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if hum then
		local s = hum:GetState()
		if s == Enum.HumanoidStateType.Freefall or s == Enum.HumanoidStateType.Jumping or s == Enum.HumanoidStateType.Flying then st.air = st.air + dt end
	end
	if S.fl_on then
		if sp > S.fl_th and st.last <= S.fl_th and t - st.cool > 1 then
			st.cool = t
			trigger(hrp, sp)
		end
		if S.fl_imp and st.last > S.fl_th * .6 and st.last - sp > S.fl_impth and t - st.imp > .4 then
			st.imp = t
			impact(hrp, st.last)
		end
	end
	if S.fl_trcol then
		local tr = hrp:FindFirstChild("SefTrail")
		if tr then tr.Color = ColorSequence.new(hsv(.62 - .62 * math.clamp(sp / (S.fl_th * 3), 0, 1))) end
	end
	st.last = sp
	-- dizzy stars
	if #stars.parts > 0 then
		local head = ch:FindFirstChild("Head")
		if tick() < stars.untilT and head then
			for i, p in ipairs(stars.parts) do
				local a = t * 5 + i / #stars.parts * math.pi * 2
				p.Color = S.fl_starc
				p.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.7, 1.6, math.sin(a) * 1.7))
			end
		else
			starsOff()
		end
	end
	-- speed lines
	local c = cam()
	local on = S.fl_sl and sp > S.fl_slth and c
	local vp = c and c.ViewportSize or Vector2.new(800, 400)
	local cx, cy = vp.X / 2, vp.Y / 2
	local maxr = math.max(vp.X, vp.Y) * .6
	for i, f in ipairs(slFrames) do
		if on then
			local e = slData[i]
			e.r = e.r + dt * maxr * (1.2 + e.v)
			if e.r > maxr then e.r = maxr * .25 e.a = math.random() * math.pi * 2 e.v = math.random() end
			f.Visible = true
			f.Position = UDim2.fromOffset(cx + math.cos(e.a) * e.r, cy + math.sin(e.a) * e.r)
			f.Size = UDim2.fromOffset(2, S.fl_sllen * (.5 + e.v))
			f.Rotation = math.deg(e.a) - 90
			f.BackgroundColor3 = S.fl_slc
			f.BackgroundTransparency = 1 - S.fl_slop * math.clamp((e.r - maxr * .25) / (maxr * .5), 0, 1)
		else
			f.Visible = false
		end
	end
end
L.onChar[#L.onChar + 1] = function() st.home = nil st.last = 0 starsOff() end
L.cleanups[#L.cleanups + 1] = starsOff

-- small list panel used by "Show Toy Names"
local listBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 70), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = .25, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Visible = false, ZIndex = 9, Text = "" }, hud)
U.cr(listBtn, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, listBtn)
listBtn.MouseButton1Click:Connect(function() listBtn.Visible = false end)
function L.showList(title, lines)
	local n = math.min(#lines, 40)
	local txt = { title .. " (tap to close)" }
	for i = 1, n do txt[#txt + 1] = lines[i] end
	if #lines > n then txt[#txt + 1] = "... +" .. (#lines - n) .. " more" end
	if #lines == 0 then txt[#txt + 1] = "(none found)" end
	listBtn.Text = table.concat(txt, "\n")
	listBtn.Visible = true
end
end)

-- module: 08_overlays
MOD("08_overlays", function()
local S, Ctl, L, T, SL, CO, DD, B, H, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.tab
local new, hsv, cam, hud = U.new, U.hsv, U.cam, U.hud
L.tabs.Overlays = tab("Overlays", 14)
local function full(extra)
	local p = { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, Visible = false, ZIndex = 0 }
	for k, v in pairs(extra or {}) do p[k] = v end
	return new("Frame", p, hud)
end

H("Color Overlay")
local f1 = full()
local function u1() f1.Visible = S.o1_on f1.BackgroundColor3 = S.o1_c f1.BackgroundTransparency = 1 - S.o1_a end
T("Color Overlay", "o1_on", false, u1)
CO("Overlay Color", "o1_c", Color3.fromRGB(255, 80, 120), u1)
SL("Overlay Strength", "o1_a", 0, .8, .15, 2, u1)

H("Gradient Overlay")
local f2 = full({ BackgroundColor3 = Color3.new(1, 1, 1) })
local g2 = new("UIGradient", {}, f2)
local function u2() f2.Visible = S.o2_on g2.Color = ColorSequence.new(S.o2_c1, S.o2_c2) g2.Rotation = S.o2_rot f2.BackgroundTransparency = 1 - S.o2_a end
T("Gradient Overlay", "o2_on", false, u2)
CO("Gradient Top Color", "o2_c1", Color3.fromRGB(120, 60, 255), u2)
CO("Gradient Bottom Color", "o2_c2", Color3.fromRGB(255, 60, 160), u2)
SL("Gradient Angle", "o2_rot", 0, 360, 90, 0, u2)
SL("Gradient Strength", "o2_a", 0, .8, .2, 2, u2)

H("Rainbow Overlay")
local f3 = full()
T("Rainbow Overlay", "o3_on", false, function(v) f3.Visible = v end)
SL("Rainbow Speed", "o3_sp", .05, 2, .25, 2)
SL("Rainbow Strength", "o3_a", 0, .8, .12, 2)

H("Breathing Overlay")
local f4 = full()
T("Breathing Overlay", "o4_on", false, function(v) f4.Visible = v f4.BackgroundColor3 = S.o4_c end)
CO("Breathing Color", "o4_c", Color3.fromRGB(80, 160, 255), function(c) f4.BackgroundColor3 = c end)
SL("Breathing Speed", "o4_sp", .3, 8, 2, 1)
SL("Breathing Strength", "o4_a", 0, .8, .25, 2)

H("Screen Border")
local f5 = full()
local st5 = new("UIStroke", { Thickness = 6 }, f5)
local function u5() f5.Visible = S.o5_on st5.Color = S.o5_c st5.Thickness = S.o5_th end
T("Screen Border", "o5_on", false, u5)
CO("Border Color", "o5_c", Color3.fromRGB(255, 255, 255), u5)
SL("Border Thickness", "o5_th", 1, 40, 8, 0, u5)

H("Corner Brackets")
local brFolder = full({ Name = "Brackets" })
local function u6()
	for _, c in ipairs(brFolder:GetChildren()) do c:Destroy() end
	brFolder.Visible = S.o6_on
	if not S.o6_on then return end
	local sz, th, m = S.o6_sz, S.o6_th, 18
	for _, cx in ipairs({ 0, 1 }) do
		for _, cy in ipairs({ 0, 1 }) do
			local ax, ay = cx, cy
			local ox, oy = (cx == 0) and m or -m, (cy == 0) and m or -m
			new("Frame", { AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(cx, ox, cy, oy), Size = UDim2.fromOffset(sz, th), BackgroundColor3 = S.o6_c, BorderSizePixel = 0 }, brFolder)
			new("Frame", { AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(cx, ox, cy, oy), Size = UDim2.fromOffset(th, sz), BackgroundColor3 = S.o6_c, BorderSizePixel = 0 }, brFolder)
		end
	end
end
T("Corner Brackets", "o6_on", false, u6)
CO("Bracket Color", "o6_c", Color3.fromRGB(255, 255, 255), u6)
SL("Bracket Size", "o6_sz", 20, 200, 70, 0, u6)
SL("Bracket Thickness", "o6_th", 1, 10, 3, 0, u6)

H("Scanlines")
local slF = full({ Name = "Scan" })
local function u7()
	for _, c in ipairs(slF:GetChildren()) do c:Destroy() end
	slF.Visible = S.o7_on
	if not S.o7_on then return end
	local n = math.floor(S.o7_n)
	for i = 1, n do
		new("Frame", { Position = UDim2.fromScale(0, i / n), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = S.o7_c, BackgroundTransparency = 1 - S.o7_a, BorderSizePixel = 0 }, slF)
	end
end
T("Scanlines", "o7_on", false, u7)
CO("Scanline Color", "o7_c", Color3.new(0, 0, 0), u7)
SL("Scanline Count", "o7_n", 20, 160, 90, 0, u7)
SL("Scanline Strength", "o7_a", 0, 1, .35, 2, u7)

H("Film Noise")
local nF = full({ Name = "Noise" })
local dots = {}
for i = 1, 70 do dots[i] = new("Frame", { Size = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, nF) end
T("Film Noise", "o8_on", false, function(v) nF.Visible = v end)
SL("Noise Strength", "o8_a", 0, 1, .5, 2)
SL("Noise Dot Size", "o8_sz", 1, 6, 2, 0)

H("Chromatic Edges")
local cL = full({ Name = "ChL", Size = UDim2.fromScale(.16, 1), BackgroundColor3 = Color3.fromRGB(255, 40, 60) })
local cR = full({ Name = "ChR", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(.16, 1), BackgroundColor3 = Color3.fromRGB(40, 220, 255) })
local gL = new("UIGradient", { Rotation = 0 }, cL)
local gR = new("UIGradient", { Rotation = 180 }, cR)
local function u9()
	cL.Visible = S.o9_on cR.Visible = S.o9_on
	local seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - S.o9_a), NumberSequenceKeypoint.new(1, 1) })
	gL.Transparency = seq gR.Transparency = seq
	cL.Size = UDim2.fromScale(S.o9_w, 1) cR.Size = UDim2.fromScale(S.o9_w, 1)
end
T("Chromatic Edges", "o9_on", false, u9)
SL("Edge Width", "o9_w", .05, .4, .16, 2, u9)
SL("Edge Strength", "o9_a", 0, 1, .5, 2, u9)

H("Heartbeat Pulse")
local f10 = full()
T("Heartbeat Pulse", "o10_on", false, function(v) f10.Visible = v f10.BackgroundColor3 = S.o10_c end)
CO("Pulse Color", "o10_c", Color3.fromRGB(255, 30, 60), function(c) f10.BackgroundColor3 = c end)
SL("Beats Per Minute", "o10_bpm", 30, 200, 70, 0)
SL("Pulse Strength", "o10_a", 0, .8, .3, 2)

local acc = 0
L.steps[#L.steps + 1] = function(dt, t)
	if S.o3_on then f3.BackgroundColor3 = hsv(t * S.o3_sp, .8, 1) f3.BackgroundTransparency = 1 - S.o3_a end
	if S.o4_on then f4.BackgroundTransparency = 1 - S.o4_a * (math.sin(t * S.o4_sp) + 1) / 2 end
	if S.o10_on then
		local ph = (t * S.o10_bpm / 60) % 1
		local a = math.max(math.max(0, 1 - ph * 6), math.max(0, 1 - math.abs(ph - .25) * 8) * .7)
		f10.BackgroundTransparency = 1 - S.o10_a * a
	end
	if S.o8_on then
		acc = acc + dt
		if acc > .07 then
			acc = 0
			local c = cam()
			local vp = c and c.ViewportSize or Vector2.new(800, 400)
			for _, d in ipairs(dots) do
				d.Position = UDim2.fromOffset(math.random(0, vp.X), math.random(0, vp.Y))
				d.Size = UDim2.fromOffset(S.o8_sz, S.o8_sz)
				d.BackgroundTransparency = 1 - S.o8_a * (.3 + math.random() * .7)
			end
		end
	end
end
end)

-- module: 09_explosions
MOD("09_explosions", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, H, use = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.H, U.usePage
local new, tw, hsv, LP, Players, cam, mk, burst, sphere, ring = U.new, U.tw, U.hsv, U.LP, U.Players, U.cam, U.mk, U.burst, U.sphere, U.ring
local Debris, fxFolder = U.Debris, U.fxFolder
local EX, EXC, EXN = L.EX, L.EXC, L.EXN
local TEXS = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local RB = U.RAINBOWSEQ

---------------------------------------------------------------- new presets
EX["Plasma Orb"] = function(pos, s, c1, c2, d)
	sphere(pos, c1, 3 * s, 18 * s, d * .7) sphere(pos, c2, 1.5 * s, 10 * s, d * .5)
	for i = 1, 3 do task.delay(i * .1, function() ring(pos, c2, 30 * s, d * .6, math.rad(60 * i)) end) end
	burst(pos, c1, 50, 30 * s, d, 1.2 * s)
end
EX.Fireworks = function(pos, s, c1, c2, d)
	burst(pos, RB, 120, 55 * s, d * 1.4, s, TEXS, Vector3.new(0, -15, 0))
	for k = 1, 3 do
		task.delay(k * .18, function() burst(pos + Vector3.new(math.random(-6, 6), 10 + k * 4, math.random(-6, 6)) * s, RB, 90, 45 * s, d * 1.3, .9 * s, TEXS, Vector3.new(0, -15, 0)) end)
	end
end
EX.Supernova = function(pos, s, c1, c2, d)
	sphere(pos, Color3.new(1, 1, 1), 2 * s, 40 * s, d * .6) sphere(pos, c1, 2 * s, 30 * s, d * .8) sphere(pos, c2, s, 20 * s, d)
	for i = 1, 3 do task.delay(i * .15, function() ring(pos, i % 2 == 0 and c1 or c2, 70 * s, d * .9, math.rad(i * 30)) end) end
	burst(pos, c1, 80, 60 * s, d, 2 * s)
end
EX.Vortex = function(pos, s, c1, c2, d)
	for i = 1, 26 do
		local a, h0 = i * .55, i * .4 * s
		local p = mk(Enum.PartType.Ball, pos + Vector3.new(math.cos(a) * s, h0 * .2, math.sin(a) * s), Vector3.new(1, 1, 1) * s * .9, i % 2 == 0 and c1 or c2)
		local a2, r1 = a + 4, (10 + i * .9) * s
		tw(p, d, { CFrame = CFrame.new(pos + Vector3.new(math.cos(a2) * r1, h0, math.sin(a2) * r1)), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, d + .2)
	end
	ring(pos, c1, 30 * s, d * .6)
end
EX["Toxic Cloud"] = function(pos, s, c1, c2, d)
	burst(pos, ColorSequence.new(c1, c2), 60, 18 * s, d * 1.6, 6 * s, SMOKE, Vector3.new(0, 3, 0))
	sphere(pos, c1, 2 * s, 14 * s, d * .4) ring(pos, c2, 26 * s, d * .7)
end
EX["Meteor Rain"] = function(pos, s, c1, c2, d)
	for i = 1, 10 do
		task.delay(i * .08, function()
			local g = pos + Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)) * s
			local p = mk(Enum.PartType.Ball, g + Vector3.new(0, 45 * s, 0), Vector3.new(1, 1, 1) * 2 * s, c1)
			tw(p, .35, { CFrame = CFrame.new(g) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(p, .5)
			task.delay(.35, function() sphere(g, c2, s, 7 * s, d * .4) burst(g, c1, 12, 16 * s, d * .6, .8 * s) end)
		end)
	end
end
EX["Rainbow Rings"] = function(pos, s, c1, c2, d)
	for i = 1, 6 do task.delay(i * .09, function() ring(pos, hsv(i / 6), (20 + i * 8) * s, d * .7, math.rad(i * 12)) end) end
	burst(pos, RB, 60, 30 * s, d, s)
end
EX["Pixel Burst"] = function(pos, s, c1, c2, d)
	for i = 1, 40 do
		local dir = Vector3.new(math.random() - .5, math.random() * .9, math.random() - .5).Unit
		local p = mk(Enum.PartType.Block, pos, Vector3.new(.7, .7, .7) * s, i % 2 == 0 and c1 or c2)
		tw(p, d, { CFrame = CFrame.new(pos + dir * math.random(6, 24) * s), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, d + .2)
	end
end
local NEW = {
	["Plasma Orb"] = { Color3.fromRGB(190, 60, 255), Color3.fromRGB(80, 200, 255) }, Fireworks = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 80, 120) },
	Supernova = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 80, 40) }, Vortex = { Color3.fromRGB(120, 80, 255), Color3.fromRGB(60, 220, 255) },
	["Toxic Cloud"] = { Color3.fromRGB(120, 255, 70), Color3.fromRGB(40, 140, 40) }, ["Meteor Rain"] = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 220, 120) },
	["Rainbow Rings"] = { Color3.new(1, 1, 1), Color3.new(1, 1, 1) }, ["Pixel Burst"] = { Color3.fromRGB(80, 255, 160), Color3.fromRGB(80, 160, 255) },
}
for _, n in ipairs({ "Plasma Orb", "Fireworks", "Supernova", "Vortex", "Toxic Cloud", "Meteor Rain", "Rainbow Rings", "Pixel Burst" }) do
	EXC[n] = NEW[n]
	EXN[#EXN + 1] = n
end

function L.scorch(pos, s)
	local gy = L.groundY(pos + Vector3.new(0, 10, 0))
	if not gy then return end
	local p = mk(Enum.PartType.Cylinder, pos, Vector3.new(.1, 14 * s, 14 * s), Color3.new(.04, .04, .04), Enum.Material.SmoothPlastic)
	p.CFrame = CFrame.new(pos.X, gy + .06, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
	p.Transparency = .25
	task.delay(4, function() if p.Parent then tw(p, 3, { Transparency = 1 }) end end)
	Debris:AddItem(p, 7.5)
end

---------------------------------------------------------------- controls
use("Explosions")
H("Triggers (what counts as a missile explosion)")
T("Detect Explosion Objects", "ex_t_obj", true)
T("Detect Explosion-Named Parts", "ex_t_part", true)
T("Detect Missile Removal (explodes when it vanishes)", "ex_t_rm", true)
T("Detect Sudden Stop (missile hits something)", "ex_stop", false)
IN("Missile Toy Name Keywords", "ex_kw", "missile,rocket")
T("Include Everyone's Missiles", "ex_all", true)
T("Debug Output (executor console)", "ex_dbg", false)
H("Extras")
T("Random Style Each Time", "ex_rand", false)
T("Color Cycle", "ex_cycle", false)
T("Explosion FOV Kick", "ex_kick", false)
SL("FOV Kick Amount", "ex_kick_amt", 0, 40, 14, 0)
T("Ground Scorch Mark", "ex_scorch", false)
H("Missile Visuals (on the missile toy itself)")
local function mfx() L.missileFx() end
T("Missile Trail", "mf_trail", false, mfx)
CO("Missile Trail Color", "mf_trailc", Color3.fromRGB(255, 160, 60), mfx)
SL("Missile Trail Length", "mf_trailr", .1, 3, .8, 1, mfx)
SL("Missile Trail Width", "mf_trailw", .2, 4, 1.2, 1, mfx)
T("Missile Fire", "mf_fire", false, mfx)
CO("Missile Fire Color", "mf_firec", Color3.fromRGB(255, 120, 20), mfx)
T("Missile Smoke", "mf_smoke", false, mfx)
T("Missile Glow Light", "mf_light", false, mfx)
CO("Missile Light Color", "mf_lightc", Color3.fromRGB(255, 170, 80), mfx)

---------------------------------------------------------------- missile tracking
local tracked = {}
local function toyPos(m)
	local ok, p = pcall(function() return m:GetPivot().Position end)
	return ok and p or nil
end
local function matchKW(name)
	local n = name:lower()
	for kw in S.ex_kw:lower():gmatch("[^,%s]+") do
		if n:find(kw, 1, true) then return true end
	end
	return false
end
function L.missileFx()
	for m in pairs(tracked) do
		local main = m.Parent and L.firstPart(m)
		if main then
			local tr = L.ensure(main, "SefMTrail", "Trail", { Color = ColorSequence.new(S.mf_trailc), Lifetime = S.mf_trailr, LightEmission = 1, Transparency = NumberSequence.new(.1, 1), WidthScale = NumberSequence.new(S.mf_trailw, 0), FaceCamera = true }, S.mf_trail)
			if tr and not tr.Attachment0 then
				local h = math.max(.4, main.Size.Z / 2)
				tr.Attachment0 = new("Attachment", { Name = "SefMA0", Position = Vector3.new(0, 0, h) }, main)
				tr.Attachment1 = new("Attachment", { Name = "SefMA1", Position = Vector3.new(0, .8, h) }, main)
			end
			if not S.mf_trail then
				for _, n in ipairs({ "SefMA0", "SefMA1" }) do local a = main:FindFirstChild(n) if a then a:Destroy() end end
			end
			L.ensure(main, "SefMFire", "Fire", { Color = S.mf_firec, SecondaryColor = Color3.fromRGB(255, 60, 0), Size = math.clamp(main.Size.Magnitude, 3, 12), Heat = 10 }, S.mf_fire)
			L.ensure(main, "SefMSmoke", "Smoke", { Color = Color3.fromRGB(120, 120, 120), Size = 6, Opacity = .6, RiseVelocity = 3 }, S.mf_smoke)
			L.ensure(main, "SefMLight", "PointLight", { Color = S.mf_lightc, Range = 16, Brightness = 2, Shadows = false }, S.mf_light)
		end
	end
end
local function track(m)
	if tracked[m] or not (m:IsA("Model") or m:IsA("BasePart")) then return end
	local rec = { pos = toyPos(m) or Vector3.new(), fast = 0, stopT = 0, lastsp = 0 }
	tracked[m] = rec
	rec.conn = m.AncestryChanged:Connect(function()
		if m:IsDescendantOf(workspace) then return end
		if L.alive() and S.ex_on and S.ex_t_rm and tick() - rec.fast < 3 then
			if S.ex_dbg then warn("[Sef] missile removed -> explosion", m.Name) end
			L.explode(rec.pos)
		end
		if rec.conn then rec.conn:Disconnect() end
		tracked[m] = nil
	end)
	task.defer(L.missileFx)
end
local sc = 0
L.steps[#L.steps + 1] = function(dt, t)
	for m, rec in pairs(tracked) do
		local p = toyPos(m)
		if p then
			local sp = (p - rec.pos).Magnitude / math.max(dt, 1e-3)
			if sp > 25 then rec.fast = tick() end
			if S.ex_stop and S.ex_on and rec.lastsp > 45 and sp < 6 and tick() - rec.stopT > 1 then
				rec.stopT = tick()
				L.explode(p)
			end
			rec.lastsp = sp
			rec.pos = p
		end
	end
	sc = sc + dt
	if sc > .25 then
		sc = 0
		if S.ex_on then
			for _, f in ipairs(L.toyFolders(S.ex_all)) do
				for _, m in ipairs(f:GetChildren()) do
					if not tracked[m] and matchKW(m.Name) then track(m) end
				end
			end
		end
	end
end

---------------------------------------------------------------- detection of the game's own explosion
local function charOf(d)
	local m = d:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return true end
		m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
	end
	return false
end
local function nearSup(pos) return tick() < (L.supUntil or 0) and L.supPos and (pos - L.supPos).Magnitude < 60 end
U.C(workspace.DescendantAdded, function(d)
	if not L.alive() or not S.ex_on then return end
	if d:IsDescendantOf(fxFolder) then return end
	if d:IsA("Explosion") then
		if S.ex_dbg then warn("[Sef] Explosion object:", d:GetFullName()) end
		if S.ex_hide then pcall(function() d.Visible = false end) end
		if S.ex_t_obj then L.explode(d.Position) end
	elseif d:IsA("BasePart") then
		local n = d.Name:lower()
		if (n:find("explosion") or n:find("blast") or n:find("shockwave") or n:find("fireball")) and not charOf(d) then
			if S.ex_dbg then warn("[Sef] explosion-named part:", d:GetFullName()) end
			local pos = d.Position
			if S.ex_hide then
				task.defer(function()
					pcall(function()
						d.Transparency = 1
						for _, e in ipairs(d:GetDescendants()) do
							if e:IsA("ParticleEmitter") or e:IsA("Light") then e.Enabled = false end
						end
					end)
				end)
			end
			if S.ex_t_part then L.explode(pos) end
		elseif S.ex_hide and nearSup(d.Position) and not d.CanCollide and not charOf(d) and not d:IsDescendantOf(workspace:FindFirstChild("GrabParts") or fxFolder) then
			if S.ex_dbg then warn("[Sef] hid part near blast:", d:GetFullName()) end
			task.defer(function() pcall(function() d.Transparency = 1 end) end)
		end
	elseif S.ex_hide and tick() < (L.supUntil or 0) and d.Name:sub(1, 3) ~= "Sef"
		and (d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Trail") or d:IsA("PointLight")) then
		local par = d.Parent
		local pos = par and (par:IsA("BasePart") and par.Position or (par:IsA("Attachment") and par.WorldPosition))
		if pos and nearSup(pos) and not charOf(d) and not d:IsDescendantOf(workspace:FindFirstChild("GrabParts") or fxFolder) then
			if S.ex_dbg then warn("[Sef] disabled default effect:", d:GetFullName()) end
			task.defer(function() pcall(function() d.Enabled = false end) end)
		end
	end
end)
L.cleanups[#L.cleanups + 1] = function()
	for m, rec in pairs(tracked) do if rec.conn then rec.conn:Disconnect() end end
end
end)

-- module: 10_grab_sounds
MOD("10_grab_sounds", function()
local S, Ctl, L, T, SL, CO, DD, B, IN, H, use, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.IN, U.H, U.usePage, U.tab
local new, tw, LP, Players, notify, flashF = U.new, U.tw, U.LP, U.Players, U.notify, U.flashF
local GLP, GLN = L.GLP, L.GLN

---------------------------------------------------------------- more grab-line presets + controls
local function P(n, t) GLP[n] = t GLN[#GLN + 1] = n end
P("Ocean", { gl_mode = "Gradient", gl_c1 = Color3.fromRGB(0, 200, 255), gl_c2 = Color3.fromRGB(0, 60, 200), gl_w = .4, gl_tex = "Smoke", gl_ts = 1, gl_rain = false, gl_pulse = false })
P("Sunset", { gl_mode = "Gradient", gl_c1 = Color3.fromRGB(255, 190, 60), gl_c2 = Color3.fromRGB(255, 60, 140), gl_w = .45, gl_tex = "None", gl_rain = false, gl_pulse = true })
P("Toxic", { gl_mode = "Breathing", gl_c1 = Color3.fromRGB(120, 255, 40), gl_c2 = Color3.fromRGB(20, 120, 20), gl_w = .4, gl_tex = "Smoke", gl_ts = 2, gl_rain = false, gl_pulse = false })
P("Ghost", { gl_mode = "Solid", gl_c1 = Color3.fromRGB(235, 245, 255), gl_c2 = Color3.fromRGB(180, 200, 220), gl_w = .3, gl_tex = "Smoke", gl_ts = .5, gl_rain = false, gl_pulse = true })
P("Gold", { gl_mode = "Gradient", gl_c1 = Color3.fromRGB(255, 230, 120), gl_c2 = Color3.fromRGB(200, 130, 20), gl_w = .35, gl_tex = "Sparkles", gl_ts = 3, gl_rain = false, gl_pulse = false })
P("Blood", { gl_mode = "Flicker", gl_c1 = Color3.fromRGB(255, 20, 20), gl_c2 = Color3.fromRGB(110, 0, 0), gl_w = .4, gl_tex = "None", gl_rain = false, gl_pulse = false })
P("Cotton Candy", { gl_mode = "Gradient", gl_c1 = Color3.fromRGB(255, 170, 230), gl_c2 = Color3.fromRGB(150, 220, 255), gl_w = .45, gl_tex = "Sparkles", gl_ts = 2, gl_rain = false, gl_pulse = false })
P("Void", { gl_mode = "Gradient", gl_c1 = Color3.fromRGB(30, 0, 60), gl_c2 = Color3.fromRGB(150, 0, 255), gl_w = .5, gl_tex = "Smoke", gl_ts = 1, gl_rain = false, gl_pulse = true })

use("Grab Lines")
H("Line Color Mode")
DD("Color Mode", "gl_mode", { "Gradient", "Solid", "Rainbow", "Breathing", "Flicker" }, "Gradient")
H("Glow Layer")
T("Glow Layer Behind Line", "gl_glow", false)
CO("Glow Color", "gl_glowc", Color3.fromRGB(255, 255, 255))
SL("Glow Width Multiplier", "gl_glowm", 1, 6, 2.2, 1)
SL("Glow Transparency", "gl_glowt", 0, 1, .6, 2)
H("Grab Point Extras")
T("Tip Glow Light", "gl_tiplight", false)
SL("Tip Light Range", "gl_tlr", 4, 40, 14, 0)
T("Distance Label At Tip", "gl_dist", false)
T("Targeting Reticle", "gl_ret", false)
SL("Reticle Size", "gl_retsz", 20, 160, 70, 0)

---------------------------------------------------------------- custom scream sound
local SoundService = game:GetService("SoundService")
local snd = new("Sound", { Name = "SefScream", Volume = 3, RollOffMaxDistance = 1e5 }, SoundService)
L.tabs.Sounds = tab("Sounds", 16)
H("Custom Grab Scream (plays only for you)")
T("Custom Scream On Grab", "sc_on", false)
T("Only When Grabbing A Player", "sc_players", true)
T("Play On Any Grab", "sc_any", false)
T("Scream When You Get Flung", "sc_fling", false)
H("Sound Source")
local function setSound(asset, label)
	if not asset then return end
	snd.SoundId = asset
	notify("Sef's Ftap Visuals", (label or "Sound") .. " set. Press Test Sound.")
end
IN("Sound Asset ID", "sc_id", "")
B("Use Asset ID", function() setSound(L.toAsset(S.sc_id), "Asset ID") end)
IN("Sound URL (direct mp3 / ogg link)", "sc_url", "")
B("Download + Use URL Sound", function()
	if S.sc_url == "" then notify("Sef's Ftap Visuals", "Paste a direct audio link first.") return end
	task.spawn(function() setSound(L.fetchAsset(S.sc_url, "scream_" .. os.time() .. ".mp3"), "URL sound") end)
end)
IN("Sound File (executor workspace)", "sc_file", "")
B("Use File Sound", function()
	if isfile and S.sc_file ~= "" and isfile(S.sc_file) and getcustomasset then setSound(getcustomasset(S.sc_file), "File sound")
	else notify("Sef's Ftap Visuals", "File not found in your executor workspace folder.") end
end)
H("Playback")
SL("Volume", "sc_vol", 0, 10, 3, 1)
SL("Pitch", "sc_pitch", .3, 3, 1, 2)
T("Random Pitch", "sc_rp", false)
SL("Pitch Variation", "sc_rpv", 0, 1, .2, 2)
SL("Cooldown (seconds)", "sc_cd", 0, 10, 1.5, 1)
SL("Start Offset (seconds)", "sc_start", 0, 10, 0, 1)
T("Loop While Holding", "sc_loop", false)
T("Stop When You Let Go", "sc_stop", true)
T("Camera Shake On Scream", "sc_shk", false)
SL("Scream Shake Strength", "sc_shkamt", 0, 2, .4, 2)
T("Red Flash On Scream", "sc_flash", false)
local lastPlay = 0
function L.scream(force)
	if snd.SoundId == "" then notify("Sef's Ftap Visuals", "Set a sound first (asset id, URL or file).") return end
	local now = tick()
	if not force and now - lastPlay < S.sc_cd then return end
	lastPlay = now
	snd.Volume = S.sc_vol
	snd.PlaybackSpeed = S.sc_pitch * (S.sc_rp and (1 + (math.random() * 2 - 1) * S.sc_rpv) or 1)
	snd.Looped = S.sc_loop
	snd:Stop()
	snd.TimePosition = S.sc_start
	snd:Play()
	if S.sc_shk then L.addShake(S.sc_shkamt) end
	if S.sc_flash then flashF.BackgroundColor3 = Color3.fromRGB(255, 20, 20) flashF.BackgroundTransparency = .65 tw(flashF, .5, { BackgroundTransparency = 1 }) end
end
B("Test Sound", function() L.scream(true) end)
B("Stop Sound", function() snd:Stop() end)
B("Show Current Sound ID", function() notify("Sef's Ftap Visuals", snd.SoundId == "" and "No sound set." or snd.SoundId) end)
L.onFling[#L.onFling + 1] = function() if S.sc_on and S.sc_fling then L.scream() end end

local function cands(d)
	local out = {}
	local function add(x) if typeof(x) == "Instance" then out[#out + 1] = x end end
	if d:IsA("WeldConstraint") or d:IsA("JointInstance") then add(d.Part0) add(d.Part1)
	elseif d:IsA("Constraint") then add(d.Attachment0 and d.Attachment0.Parent) add(d.Attachment1 and d.Attachment1.Parent)
	elseif d:IsA("ObjectValue") then add(d.Value)
	elseif d:IsA("Beam") then add(d.Attachment0 and d.Attachment0.Parent) add(d.Attachment1 and d.Attachment1.Parent) end
	return out
end
local function grabbedPlayer(gp)
	for _, d in ipairs(gp:GetDescendants()) do
		for _, part in ipairs(cands(d)) do
			local m = part:FindFirstAncestorOfClass("Model")
			while m do
				if m:FindFirstChildOfClass("Humanoid") then
					if m ~= LP.Character and Players:GetPlayerFromCharacter(m) then return true end
					break
				end
				m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
			end
		end
	end
	return false
end
local was = false
L.steps[#L.steps + 1] = function(dt, t)
	local gp = workspace:FindFirstChild("GrabParts")
	local holding = gp ~= nil
	if holding and not was then
		task.delay(.15, function()
			local g = workspace:FindFirstChild("GrabParts")
			if g and S.sc_on and (S.sc_any or not S.sc_players or grabbedPlayer(g)) then L.scream() end
		end)
	elseif not holding and was and S.sc_stop then
		snd:Stop()
	end
	was = holding
end
L.cleanups[#L.cleanups + 1] = function() snd:Stop() snd:Destroy() end
end)

-- module: 11_covers_vfx  (menu covers, animated grab VFX, grab-pallet transparency, spirit auras, constellations)
MOD("11_covers_vfx", function()
local CW, CH = 660, 440 -- design size of the menu (same as W, H at the top of the script)
local S, Ctl, L, T, SL, CO, DD, B, H, use, tab = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.usePage, U.tab
local new, hsv, LP, cam, fxFolder = U.new, U.hsv, U.LP, U.cam, U.fxFolder
local TAU = math.pi * 2
local sin, cos, floor, max, min, clamp = math.sin, math.cos, math.floor, math.max, math.min, math.clamp
local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

----------------------------------------------------------------------
-- COVER SYSTEM : animated frames built around the main menu (all from scratch, no images)
----------------------------------------------------------------------
local function tint(c)
	local h = S.cv_hue or 0
	local sa, br = S.cv_sat or 1, S.cv_br or 1
	if h <= .001 and sa == 1 and br == 1 then return c end
	local ch, cs, cv = c:ToHSV()
	return Color3.fromHSV((ch + h) % 1, clamp(cs * sa, 0, 1), clamp(cv * br, 0, 1))
end
local function F(parent, cx, cy, w, h, col, tr, rot, rad, z)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(.5, .5)
	f.Position = UDim2.fromOffset(cx, cy)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = col
	f.BackgroundTransparency = tr or 0
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	f.ZIndex = z or 1
	if rad then
		local c = Instance.new("UICorner")
		c.CornerRadius = (rad == true) and UDim.new(.5, 0) or UDim.new(0, rad)
		c.Parent = f
	end
	f.Parent = parent
	return f
end
local function G(parent, c1, c2, rot, tr)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 0
	if tr then g.Transparency = tr end
	g.Parent = parent
	return g
end
local function ST(parent, col, th, tr)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = th
	s.Transparency = tr or 0
	s.Parent = parent
	return s
end
-- point on a rectangle around the menu (d = 0..1), margin m outward; returns x, y and the outward normal
local function perim(d, m)
	local w, h = CW + m * 2, CH + m * 2
	local p = (d % 1) * 2 * (w + h)
	if p < w then return -m + p, -m, 0, -1
	elseif p < w + h then return CW + m, -m + (p - w), 1, 0
	elseif p < 2 * w + h then return CW + m - (p - w - h), CH + m, 0, 1 end
	return -m, CH + m - (p - 2 * w - h), -1, 0
end
local function plate(bk, c1, c2)
	local p = F(bk, CW / 2, CH / 2, CW + 20, CH + 20, WHITE, 0, 0, 28, 0)
	return p, G(p, c1, c2, 45)
end
local function edge(fr, col)
	local e = F(fr, CW / 2, CH / 2, CW + 3, CH + 3, WHITE, 1, 0, 21, 1)
	e.Name = "SefEdge"
	local s = ST(e, col, 2.5, .1)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col), ColorSequenceKeypoint.new(.5, WHITE), ColorSequenceKeypoint.new(1, col) })
	g.Parent = s
	return g
end
local function outAng(nx, ny) return math.deg(math.atan2(nx, -ny)) end

local STY = {}
local STN = { "Spirit Fox", "Frost Crown", "Inferno", "Void Eclipse", "Spirit Aura", "Circuit Scan", "Sakura Bloom", "Aurora Veil" }

-- 1) SPIRIT FOX : purple neon frame, twitching white ears, wagging tail, drifting sparkles ----------
STY["Spirit Fox"] = function(bk, fr)
	local pl, pg = plate(bk, tint(rgb(200, 70, 255)), tint(rgb(80, 10, 160)))
	local eg = edge(fr, tint(rgb(235, 190, 255)))
	local tipc = tint(rgb(215, 170, 255))
	local ears = {}
	for i = 1, 2 do
		local sx = (i == 1) and 1 or -1
		local o = F(fr, (i == 1) and 44 or CW - 44, -14, 40, 78, WHITE, 0, -16 * sx, true, 3)
		G(o, WHITE, tint(rgb(255, 225, 255)), 90)
		local inn = F(o, 0, 0, 18, 46, WHITE, 0, 0, true, 4)
		inn.Position = UDim2.fromScale(.5, .62)
		G(inn, tint(rgb(210, 110, 255)), tint(rgb(110, 20, 190)), 90)
		ears[i] = { o = o, sx = sx, base = -16 * sx }
	end
	local tail, sparks = {}, {}
	for k = 1, 10 do tail[k] = F(fr, 0, 0, 20, 20, (k > 7) and tipc or WHITE, 0, 0, true, 3 + (10 - k)) end
	for k = 1, 12 do sparks[k] = F(fr, 0, 0, 6, 6, WHITE, .2, 45, 1, 6) end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 40) % 360
		eg.Rotation = (t * 90) % 360
		for i, e in ipairs(ears) do
			local flick = (max(0, sin(t * .9 + i * 2.1)) ^ 14) * 16 * -e.sx
			e.o.Rotation = e.base + sin(t * 1.7 + i) * 3 + flick
		end
		for k, c in ipairs(tail) do
			local u = k / #tail
			local s = 28 * (1 - u * .62) + 4
			c.Size = UDim2.fromOffset(s, s)
			c.Position = UDim2.fromOffset(16 - 66 * u + sin(t * 2.4 - u * 4) * 9 * u, CH + 6 + 26 * u - 74 * u * u)
		end
		for k, s in ipairs(sparks) do
			local x, y = perim(k / #sparks + t * .02, 10 + 10 * sin(t * 1.3 + k))
			local pu = .5 + .5 * sin(t * 3 + k * 1.7)
			local z = 4 + 4 * pu
			s.Position = UDim2.fromOffset(x, y)
			s.Size = UDim2.fromOffset(z, z)
			s.Rotation = 45 + t * 60
			s.BackgroundTransparency = 1 - pu * .9
		end
	end }
end

-- 2) FROST CROWN : ice spikes breathing on top, dripping icicles, falling snow ----------------------
STY["Frost Crown"] = function(bk, fr)
	local ice, ice2 = tint(rgb(235, 250, 255)), tint(rgb(110, 205, 255))
	local pl, pg = plate(bk, tint(rgb(150, 235, 255)), tint(rgb(30, 110, 230)))
	local eg = edge(fr, ice)
	local top, bot, snow = {}, {}, {}
	for i = 1, 11 do
		local w = (i % 2 == 0) and 14 or 20
		local x = 36 + (i - 1) * (CW - 72) / 10
		local f = F(fr, x, -2, w, 40, WHITE, .05, (i - 6) * 2.5, true, 3)
		G(f, ice, ice2, 90)
		top[i] = { f = f, x = x, w = w, h = 22 + 34 * sin(math.pi * (i - 1) / 10) }
	end
	for i = 1, 7 do
		local w = (i % 2 == 0) and 10 or 14
		local x = 50 + (i - 1) * (CW - 100) / 6
		local f = F(fr, x, CH + 10, w, 20, WHITE, .05, 0, true, 3)
		G(f, ice2, ice, 90)
		local d = F(fr, x, CH + 10, 7, 9, ice, 0, 0, true, 3)
		bot[i] = { f = f, d = d, x = x, w = w }
	end
	for i = 1, 14 do snow[i] = F(fr, 0, 0, 5, 5, WHITE, .1, 0, true, 6) end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 18) % 360
		eg.Rotation = (t * 60) % 360
		for i, s in ipairs(top) do
			local h = s.h * (.78 + .22 * sin(t * 2.2 + i * .9))
			s.f.Size = UDim2.fromOffset(s.w, h)
			s.f.Position = UDim2.fromOffset(s.x, -2 - h / 2)
		end
		for i, b in ipairs(bot) do
			local p = (t * .3 + i * .29) % 1
			local len = 10 + 28 * min(p / .8, 1)
			b.f.Size = UDim2.fromOffset(b.w, len)
			b.f.Position = UDim2.fromOffset(b.x, CH + 6 + len / 2)
			if p > .8 then
				local q = (p - .8) / .2
				b.d.Visible = true
				b.d.Position = UDim2.fromOffset(b.x, CH + 6 + len + q * 46)
				b.d.BackgroundTransparency = q
			else b.d.Visible = false end
		end
		for i, s in ipairs(snow) do
			local left = i % 2 == 0
			local x = (left and -15 or CW + 15) + sin(t + i) * 8
			s.Position = UDim2.fromOffset(x, ((t * (18 + i * 2) + i * 53) % (CH + 60)) - 20)
		end
	end }
end

-- 3) INFERNO : ring of fire around the menu + rising embers ---------------------------------------
STY["Inferno"] = function(bk, fr)
	local y1, r1 = tint(rgb(255, 235, 90)), tint(rgb(255, 45, 0))
	local pl, pg = plate(bk, tint(rgb(255, 170, 30)), tint(rgb(170, 15, 5)))
	local eg = edge(fr, tint(rgb(255, 210, 90)))
	local fl, em = {}, {}
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.35, .2), NumberSequenceKeypoint.new(1, 0) })
	for i = 1, 30 do
		local f = F(fr, 0, 0, 22, 30, WHITE, .1, 0, true, 3)
		G(f, r1, y1, 90, fade)
		fl[i] = f
	end
	for i = 1, 16 do em[i] = F(fr, 0, 0, 4, 4, y1, 0, 0, true, 6) end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 70) % 360
		eg.Rotation = (t * 120) % 360
		for i, f in ipairs(fl) do
			local x, y, nx, ny = perim((i - 1) / #fl, 4)
			local len = max(14, 28 + 16 * sin(t * 5 + i * 1.7) + 8 * sin(t * 9.1 + i * 2.3))
			f.Size = UDim2.fromOffset(20 + 4 * sin(t * 6 + i), len)
			f.Position = UDim2.fromOffset(x + nx * len / 2, y + ny * len / 2)
			f.Rotation = outAng(nx, ny) + sin(t * 4 + i) * 9
		end
		for i, e in ipairs(em) do
			local p = (t * (.16 + (i % 5) * .03) + i * .137) % 1
			local left = i % 2 == 0
			e.Position = UDim2.fromOffset((left and -16 or CW + 16) + ((i * 7) % 12) + sin(t * 2 + i) * 8, CH + 14 - p * (CH + 100))
			e.BackgroundColor3 = y1:Lerp(r1, p)
			e.BackgroundTransparency = p * p
			local z = 3 + 4 * (1 - p)
			e.Size = UDim2.fromOffset(z, z)
		end
	end }
end

-- 4) VOID ECLIPSE : spinning arc rings in the corners, orbiting orbs with trails, eclipse on top -----
STY["Void Eclipse"] = function(bk, fr)
	local v1, v2 = tint(rgb(150, 30, 255)), tint(rgb(235, 190, 255))
	local pl, pg = plate(bk, tint(rgb(25, 0, 55)), tint(rgb(125, 15, 230)))
	local eg = edge(fr, v1)
	local arc = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(.42, 0), NumberSequenceKeypoint.new(.5, 1), NumberSequenceKeypoint.new(1, 1) })
	local rings, orbs = {}, {}
	for i, c in ipairs({ { 0, 0 }, { CW, 0 }, { 0, CH }, { CW, CH } }) do
		local o = F(fr, c[1], c[2], 92, 92, WHITE, 1, 0, true, 3)
		local go = G(ST(o, v2, 3, 0), v1, v2, 0, arc)
		local n = F(fr, c[1], c[2], 56, 56, WHITE, 1, 0, true, 3)
		local gn = G(ST(n, v1, 2.5, 0), v2, v1, 0, arc)
		local core = F(fr, c[1], c[2], 16, 16, Color3.new(0, 0, 0), 0, 0, true, 4)
		ST(core, v2, 2, 0)
		rings[i] = { go = go, gn = gn, core = core }
	end
	for h = 1, 3 do
		orbs[h] = {}
		for k = 1, 5 do orbs[h][k] = F(fr, 0, 0, 12 - k * 1.6, 12 - k * 1.6, (k == 1) and v2 or v1, (k - 1) * .17, 0, true, 5) end
	end
	local disc = F(fr, CW / 2, -4, 54, 54, Color3.new(0, 0, 0), 0, 0, true, 6)
	local ds = ST(disc, v2, 5, 0)
	local corona = F(fr, CW / 2, -4, 80, 80, WHITE, 1, 0, true, 5)
	local cs = ST(corona, v1, 4, .5)
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 25) % 360
		eg.Rotation = (-t * 70) % 360
		for i, r in ipairs(rings) do
			local dir = (i % 2 == 0) and -1 or 1
			r.go.Rotation = (t * 140 * dir) % 360
			r.gn.Rotation = (-t * 200 * dir) % 360
			local s = 14 + 4 * sin(t * 3 + i)
			r.core.Size = UDim2.fromOffset(s, s)
		end
		for h, trail in ipairs(orbs) do
			for k, o in ipairs(trail) do
				local x, y = perim(t * .07 + h / 3 - k * .011, 14)
				o.Position = UDim2.fromOffset(x, y)
			end
		end
		ds.Thickness = 4 + 2 * sin(t * 2.5)
		cs.Transparency = .45 + .35 * sin(t * 2.5 + 1)
		local cz = 76 + 8 * sin(t * 2.5)
		corona.Size = UDim2.fromOffset(cz, cz)
	end }
end

-- 5) SPIRIT AURA : blue frame, travelling wave of spikes, stepped cone hat with spinning rings ----------
STY["Spirit Aura"] = function(bk, fr)
	local b1, b2 = tint(rgb(80, 175, 255)), tint(rgb(225, 245, 255))
	local pl, pg = plate(bk, tint(rgb(45, 100, 255)), tint(rgb(8, 16, 80)))
	local eg = edge(fr, b2)
	local sp, wi, rg = {}, {}, {}
	for i = 1, 36 do
		local s = F(fr, 0, 0, 9, 20, WHITE, .08, 0, true, 3)
		G(s, b2, b1, 90)
		sp[i] = s
	end
	for j = 1, 6 do
		local w = 27 - (j - 1) * 4.4
		local c = F(fr, CW / 2, -4 - (j - 1) * 11, w, 12, (j == 6) and b2 or WHITE, 0, 0, 2, 4)
		G(c, b2, b1, 90)
	end
	for i = 1, 3 do
		local r = F(fr, CW / 2, -8 - i * 14, 90, 14, WHITE, 1, 0, true, 5)
		ST(r, b2, 2, .1)
		rg[i] = r
	end
	for i = 1, 8 do wi[i] = F(fr, 0, 0, 8, 8, b2, .3, 0, true, 5) end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 30) % 360
		eg.Rotation = (t * 80) % 360
		for i, s in ipairs(sp) do
			local x, y, nx, ny = perim((i - 1) / #sp, 5)
			local len = 12 + 18 * (.5 + .5 * sin(t * 3 - i * .55))
			s.Size = UDim2.fromOffset(9, len)
			s.Position = UDim2.fromOffset(x + nx * len / 2, y + ny * len / 2)
			s.Rotation = outAng(nx, ny)
		end
		for i, r in ipairs(rg) do
			r.Size = UDim2.fromOffset(96 * math.abs(cos(t * 1.6 + i * 1.1)) + 8, 14)
			r.Position = UDim2.fromOffset(CW / 2, -8 - i * 14 + sin(t * 2 + i) * 2)
		end
		for j, w in ipairs(wi) do
			local x, y = perim(j / #wi + t * .03, 20 + 8 * sin(t * 2 + j))
			w.Position = UDim2.fromOffset(x, y)
			w.BackgroundTransparency = .15 + .6 * (.5 + .5 * sin(t * 4 + j * 2))
		end
	end }
end

-- 6) CIRCUIT SCAN : chasing lights around the border, glowing corner brackets, blinking data nodes -------
STY["Circuit Scan"] = function(bk, fr)
	local g1, g2 = tint(rgb(0, 255, 180)), tint(rgb(0, 150, 255))
	local pl, pg = plate(bk, tint(rgb(0, 225, 160)), tint(rgb(0, 40, 90)))
	local eg = edge(fr, g1)
	local dots, brk, nodes = {}, {}, {}
	for i = 1, 76 do
		local x, y = perim(i / 76, 3)
		dots[i] = F(fr, x, y, 5, 5, g1:Lerp(g2, i / 76), 0, 45, 1, 3)
	end
	for _, b in ipairs({
		{ 12, -4, 36, 4 }, { -4, 12, 4, 36 }, { CW - 12, -4, 36, 4 }, { CW + 4, 12, 4, 36 },
		{ 12, CH + 4, 36, 4 }, { -4, CH - 12, 4, 36 }, { CW - 12, CH + 4, 36, 4 }, { CW + 4, CH - 12, 4, 36 },
	}) do brk[#brk + 1] = F(fr, b[1], b[2], b[3], b[4], g1, 0, 0, 2, 4) end
	for i = 1, 8 do
		nodes[i] = F(fr, CW * ((i - 1) % 4 + 1) / 5, (i <= 4) and -12 or CH + 12, 9, 9, g2, 0, 0, 2, 4)
	end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 20) % 360
		eg.Rotation = (t * 100) % 360
		local h1, h2 = (t * .16) % 1, (t * .16 + .5) % 1
		for i, d in ipairs(dots) do
			local p = i / #dots
			local v1, v2 = (h1 - p) % 1, (h2 - p) % 1
			local a = max(v1 < .22 and (1 - v1 / .22) or 0, v2 < .22 and (1 - v2 / .22) or 0)
			d.BackgroundTransparency = 1 - (.15 + .85 * a)
			local z = 4 + 5 * a
			d.Size = UDim2.fromOffset(z, z)
		end
		local bt = .1 + .35 * (.5 + .5 * sin(t * 4))
		for _, b in ipairs(brk) do b.BackgroundTransparency = bt end
		for i, n in ipairs(nodes) do n.BackgroundTransparency = (sin(t * 3 + i * 5) > .3) and 0 or .8 end
	end }
end

-- 7) SAKURA BLOOM : pink frame, spinning corner blossoms, falling petals ----------------------------
STY["Sakura Bloom"] = function(bk, fr)
	local p1, p2 = tint(rgb(255, 235, 245)), tint(rgb(255, 150, 190))
	local pl, pg = plate(bk, tint(rgb(255, 160, 205)), tint(rgb(130, 30, 100)))
	local eg = edge(fr, p1)
	local flowers, petals = {}, {}
	for i, c in ipairs({ { 6, 6 }, { CW - 6, 6 }, { 6, CH - 6 }, { CW - 6, CH - 6 } }) do
		local f = F(fr, c[1], c[2], 60, 60, WHITE, 1, 0, nil, 4)
		for k = 1, 5 do
			local pt = F(f, 30, 30, 18, 30, WHITE, .05, (k - 1) * 72, true, 4)
			pt.AnchorPoint = Vector2.new(.5, 1)
			G(pt, p1, p2, 90)
		end
		F(f, 30, 30, 10, 10, tint(rgb(255, 215, 90)), 0, 0, true, 5)
		flowers[i] = f
	end
	for i = 1, 16 do petals[i] = F(fr, 0, 0, 8, 12, (i % 2 == 0) and p1 or p2, .1, 0, true, 6) end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 25) % 360
		eg.Rotation = (t * 70) % 360
		for i, f in ipairs(flowers) do f.Rotation = (t * ((i % 2 == 0) and 14 or -14)) % 360 end
		for i, s in ipairs(petals) do
			local left = i % 2 == 0
			local x = (left and -14 or CW + 14) + sin(t * 1.3 + i) * 12
			s.Position = UDim2.fromOffset(x, ((t * (22 + i * 3) + i * 47) % (CH + 80)) - 30)
			s.Rotation = (t * 80 + i * 40) % 360
		end
	end }
end

-- 8) AURORA VEIL : green / violet curtain bars waving over the top edge ----------------------------
STY["Aurora Veil"] = function(bk, fr)
	local a1, a2 = tint(rgb(60, 255, 170)), tint(rgb(150, 90, 255))
	local pl, pg = plate(bk, tint(rgb(30, 220, 150)), tint(rgb(60, 20, 140)))
	local eg = edge(fr, a1)
	local bars, stars = {}, {}
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, .2), NumberSequenceKeypoint.new(1, 0) })
	for i = 1, 26 do
		local x = 18 + (i - 1) * (CW - 36) / 25
		local b = F(fr, x, -2, 14, 40, WHITE, .1, 0, 4, 3)
		G(b, a1, a2, 90, fade)
		bars[i] = { f = b, x = x }
	end
	for i = 1, 14 do stars[i] = F(fr, 0, 0, 4, 4, WHITE, .2, 45, 1, 6) end
	return { plate = pl, upd = function(t)
		pg.Rotation = (t * 22) % 360
		eg.Rotation = (t * 80) % 360
		for i, b in ipairs(bars) do
			local h = 24 + 26 * (.5 + .5 * sin(t * 1.6 + i * .5)) + 10 * sin(t * 3.1 + i)
			b.f.Size = UDim2.fromOffset(14, h)
			b.f.Position = UDim2.fromOffset(b.x + sin(t + i) * 3, -2 - h / 2)
		end
		for i, s in ipairs(stars) do
			local x, y = perim(i / #stars + t * .015, 12)
			local pu = .5 + .5 * sin(t * 3 + i * 2)
			s.Position = UDim2.fromOffset(x, y)
			s.BackgroundTransparency = 1 - pu * .9
		end
	end }
end

-- cover hosts: two layers (behind + in front of the menu), both follow the menu every frame
local layers = {}
for _, z in ipairs({ 0, 2 }) do
	local root = new("Frame", { Name = "SefCoverRoot" .. z, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), ZIndex = z, Active = false, Visible = false }, gui)
	local host = new("Frame", { Name = "SefCover" .. z, BackgroundTransparency = 1, Size = UDim2.fromOffset(CW, CH), ZIndex = 1 }, root)
	local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CW, CH) }, host)
	local us = new("UIScale", {}, art)
	layers[#layers + 1] = { root = root, host = host, art = art, us = us, z = z }
end
local cur, clock = nil, 0
function L.coverBuild()
	for _, l in ipairs(layers) do
		for _, c in ipairs(l.art:GetChildren()) do if not c:IsA("UIScale") then c:Destroy() end end
	end
	cur = nil
	if not S.cv_on then return end
	local b = STY[S.cv_style]
	if not b then return end
	local ok, r = pcall(b, layers[1].art, layers[2].art)
	if ok then
		cur = r
		cur.edge = layers[2].art:FindFirstChild("SefEdge")
	else
		warn("[Sef's Ftap Visuals] cover failed: " .. tostring(r))
	end
end
L.steps[#L.steps + 1] = function(dt)
	local vis = S.cv_on and Main.Visible and cur ~= nil
	for _, l in ipairs(layers) do
		local show = vis and (l.z == 0 or S.cv_orn)
		l.root.Visible = show
		if show then
			local ap, as = Main.AbsolutePosition, Main.AbsoluteSize
			local o = l.root.AbsolutePosition
			local sc = as.X / CW
			l.host.Position = UDim2.fromOffset(ap.X - o.X, ap.Y - o.Y)
			l.host.Size = UDim2.fromOffset(as.X, as.Y)
			l.us.Scale = sc
			l.art.Position = UDim2.fromOffset((S.cv_ox or 0) * sc, -(S.cv_oy or 0) * sc)
		end
	end
	if not vis then return end
	clock = clock + dt * S.cv_spd
	cur.plate.BackgroundTransparency = 1 - S.cv_op
	if cur.edge then cur.edge.Visible = S.cv_edge ~= false end
	local ok, e = pcall(cur.upd, clock)
	if not ok and S.ex_dbg then warn("[Sef cover]", e) end
end

----------------------------------------------------------------------
-- ANIMATED GRAB VFX : replaces the game's grab line with a made-from-scratch animated effect (local only)
----------------------------------------------------------------------
local PT = Enum.PartType
local GVS = {
	["Spirit Helix"] = { K = 2, orbs = 6, orbSize = .5, tr = .05,
		off = function(k, u, t, amp) local a = u * TAU * 3 - t * 5 + (k - 1) * math.pi return cos(a) * amp, sin(a) * amp end },
	["Lightning Arc"] = { K = 2, orbs = 0, tr = .0, jitter = true, flick = true,
		off = function(k, u, t, amp, rx, ry) local m = (k == 1) and .7 or 1.2 return rx * amp * m, ry * amp * m end },
	["Sine Ribbon"] = { K = 3, orbs = 4, orbSize = .4, tr = .1,
		off = function(k, u, t, amp) local a = u * TAU * 2 - t * 4 + (k - 1) * .9 return cos(a) * amp * .3, sin(a) * amp * (1 - (k - 1) * .28) end },
	["Pulse Orbs"] = { K = 1, orbs = 9, orbSize = .55, tr = .35, thin = .35, long = true, shape = PT.Cylinder,
		off = function() return 0, 0 end },
	["Void Tendrils"] = { K = 3, orbs = 3, orbSize = .6, tr = .1, thin = 1.3,
		off = function(k, u, t, amp)
			local ph = (k - 1) * 2.1
			return sin(u * 7 + t * 2 + ph) * cos(u * 5 - t * 1.3 + ph) * amp * 1.1, cos(u * 6 - t * 2.2 + ph) * sin(u * 4 + t + ph) * amp * 1.1
		end },
}
local GVN = { "Spirit Helix", "Lightning Arc", "Sine Ribbon", "Pulse Orbs", "Void Tendrils" }
local gvFolder = Instance.new("Folder")
gvFolder.Name = "SefGV"
local gv = { n = 0, K = 0, nodes = {}, atts = {}, beams = {}, orbs = {}, rnd = {}, jt = -1, shown = false, style = nil }
local function newPart(size, shape, neon)
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
	p.Size = size
	if shape then p.Shape = shape end
	if neon then p.Material = Enum.Material.Neon p.Transparency = .1 else p.Transparency = 1 end
	return p
end
local function buildGV()
	gvFolder:ClearAllChildren()
	local st = GVS[S.gv_style] or GVS["Spirit Helix"]
	gv.style, gv.n, gv.K = S.gv_style, S.gv_n, st.K
	gv.nodes, gv.atts, gv.beams, gv.orbs, gv.rnd = {}, {}, {}, {}, {}
	local N = gv.n
	for k = 1, st.K do
		gv.nodes[k], gv.atts[k], gv.beams[k], gv.rnd[k] = {}, {}, {}, {}
		for i = 1, N do
			local p = newPart(Vector3.new(.2, .2, .2))
			local a = Instance.new("Attachment")
			a.Parent = p
			p.Parent = gvFolder
			gv.nodes[k][i], gv.atts[k][i], gv.rnd[k][i] = p, a, { 0, 0 }
		end
		for i = 1, N - 1 do
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = gv.atts[k][i], gv.atts[k][i + 1]
			b.FaceCamera = true b.LightEmission = 1 b.LightInfluence = 0 b.Segments = 1
			b.Parent = gv.nodes[k][i]
			gv.beams[k][i] = b
		end
	end
	for j = 1, st.orbs do
		local o = newPart(Vector3.new(.5, .5, .5), st.shape or PT.Ball, true)
		o.Parent = gvFolder
		gv.orbs[j] = o
	end
	local tip = newPart(Vector3.new(.3, .3, .3))
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = L.TEX.Sparkles pe.Rate = 30 pe.Lifetime = NumberRange.new(.35, .8) pe.Speed = NumberRange.new(4, 10)
	pe.SpreadAngle = Vector2.new(180, 180) pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, .6), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = tip
	tip.Parent = gvFolder
	gv.tip, gv.pe = tip, pe
end
local gvHid, gt = false, 0
L.steps[#L.steps + 1] = function(dt)
	local gp = workspace:FindFirstChild("GrabParts")
	local beam
	if gp then
		for _, d in ipairs(gp:GetDescendants()) do
			if d:IsA("Beam") then
				if S.gv_on then d.Enabled = false gvHid = true
				elseif gvHid and not S.gl_hide then d.Enabled = true end
				if not beam and d.Name ~= "SefGlow" and d.Attachment0 and d.Attachment1 then beam = d end
			end
		end
	end
	if not S.gv_on or not gp then gvHid = false end
	if not (S.gv_on and beam and GVS[S.gv_style]) then
		if gv.shown then gvFolder.Parent = nil gv.shown = false end
		return
	end
	if gv.style ~= S.gv_style or gv.n ~= S.gv_n then buildGV() end
	if not gv.shown then gvFolder.Parent = fxFolder gv.shown = true end
	gt = gt + dt * S.gv_spd
	local p0, p1 = beam.Attachment0.WorldPosition, beam.Attachment1.WorldPosition
	local d = p1 - p0
	local dist = d.Magnitude
	if dist < .3 then gvFolder.Parent = nil gv.shown = false return end
	local dir = d / dist
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude < .05 then right = dir:Cross(Vector3.xAxis) end
	right = right.Unit
	local up = right:Cross(dir)
	local amp = S.gv_amp * clamp(dist / 18, .3, 1)
	local st = GVS[gv.style]
	local N = gv.n
	if st.jitter then
		local q = floor(gt * 24)
		if q ~= gv.jt then
			gv.jt = q
			for k = 1, gv.K do for i = 1, N do
				local r = gv.rnd[k][i]
				r[1] = math.random() * 2 - 1
				r[2] = math.random() * 2 - 1
			end end
		end
	end
	local wBase = S.gv_w * (st.thin or 1)
	for k = 1, gv.K do
		local nd, bm, rn = gv.nodes[k], gv.beams[k], gv.rnd[k]
		for i = 1, N do
			local u = (i - 1) / (N - 1)
			local env = max(0, sin(u * math.pi)) ^ .6
			local ox, oy = st.off(k, u, gt, amp, rn[i][1], rn[i][2])
			nd[i].Position = p0 + d * u + right * (ox * env) + up * (oy * env)
		end
		for i = 1, N - 1 do
			local u = (i - .5) / (N - 1)
			local env = max(0, sin(u * math.pi)) ^ .6
			local col = S.gv_rain and hsv(gt * .35 + u * .6 + k * .08) or S.gv_c1:Lerp(S.gv_c2, (sin(u * TAU + gt * 3 + k) + 1) / 2)
			local w = wBase * (.3 + .7 * env) * (1 + .3 * sin(gt * 8 + u * 10 + k))
			local b = bm[i]
			b.Color = ColorSequence.new(col)
			b.Width0 = w
			b.Width1 = w
			b.Transparency = NumberSequence.new(clamp(st.tr + ((k > 1) and .15 or 0) + (st.flick and math.random() * .35 or 0), 0, 1))
		end
	end
	local no = #gv.orbs
	for j, o in ipairs(gv.orbs) do
		local u = (gt * .45 + (j - 1) / no) % 1
		local env = max(0, sin(u * math.pi)) ^ .6
		local ox, oy = st.off(1, u, gt, amp, 0, 0)
		local pos = p0 + d * u + right * (ox * env) + up * (oy * env)
		local s = (st.orbSize or .5) * math.sqrt(S.gv_w / .25) * (.8 + .3 * sin(gt * 10 + j * 2))
		if st.long then
			o.Size = Vector3.new(s * 2.6, s, s)
			o.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
		else
			o.Size = Vector3.new(s, s, s)
			o.Position = pos
		end
		o.Color = S.gv_rain and hsv(gt * .35 + u) or S.gv_c1:Lerp(S.gv_c2, u)
	end
	local ap = beam.Attachment1.Parent
	gv.tip.Position = (ap and ap:IsDescendantOf(gp)) and p1 or p0
	gv.pe.Enabled = S.gv_tip
	gv.pe.Color = ColorSequence.new(S.gv_c1, S.gv_c2)
end

----------------------------------------------------------------------
-- PALLET TRANSPARENCY (grab settings): held pallet and/or all of my pallets
----------------------------------------------------------------------
local origT = setmetatable({}, { __mode = "k" })
local heldRoot, heldParts, heldSet = nil, {}, {}
local mineParts, mineSet, mAcc = {}, {}, 0
local function relT(p)
	local o = origT[p]
	if o ~= nil then origT[p] = nil pcall(function() p.Transparency = o end) end
end
local function applyT(p)
	local v = 0
	if heldSet[p] then v = max(v, S.gh_tr) end
	if mineSet[p] then v = max(v, S.gm_tr) end
	if origT[p] == nil then origT[p] = p.Transparency end
	p.Transparency = max(origT[p], v)
end
local function toyRoot(p)
	local c = p
	while c and c.Parent do
		local par = c.Parent
		if par == workspace then return nil end
		if (par:IsA("Folder") or par:IsA("Model")) and par.Name:find("SpawnedInToys") then return c end
		c = par
	end
end
local function heldTarget(gp)
	local found
	local function try(p)
		if found or typeof(p) ~= "Instance" or p == gp or p:IsDescendantOf(gp) then return end
		local ch = LP.Character
		if ch and p:IsDescendantOf(ch) then return end
		local r = toyRoot(p)
		if r and (S.gh_any or r.Name:lower():find("pallet")) then found = r end
	end
	for _, d in ipairs(gp:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("JointInstance") then try(d.Part0) try(d.Part1)
		elseif d:IsA("Constraint") or d:IsA("Beam") then
			try(d.Attachment0 and d.Attachment0.Parent)
			try(d.Attachment1 and d.Attachment1.Parent)
		end
		if found then break end
	end
	return found
end
local function partsOf(root, nl, ns)
	for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then nl[#nl + 1] = d ns[d] = true end end
	if root:IsA("BasePart") then nl[#nl + 1] = root ns[root] = true end
end
L.steps[#L.steps + 1] = function(dt)
	local gp = workspace:FindFirstChild("GrabParts")
	local root = (S.gh_on and gp) and heldTarget(gp) or nil
	if root ~= heldRoot then
		heldRoot = root
		local nl, ns = {}, {}
		if root then partsOf(root, nl, ns) end
		for _, p in ipairs(heldParts) do if not ns[p] and not mineSet[p] then relT(p) end end
		heldParts, heldSet = nl, ns
	end
	mAcc = mAcc + dt
	if mAcc >= .25 then
		mAcc = 0
		local nl, ns = {}, {}
		if S.gm_on then
			local f = workspace:FindFirstChild(LP.Name .. "SpawnedInToys")
			if f then
				for _, m in ipairs(f:GetChildren()) do
					if m.Name:lower():find("pallet") then partsOf(m, nl, ns) end
				end
			end
		end
		for _, p in ipairs(mineParts) do if not ns[p] and not heldSet[p] then relT(p) end end
		mineParts, mineSet = nl, ns
	end
	for _, p in ipairs(heldParts) do pcall(applyT, p) end
	for _, p in ipairs(mineParts) do if not heldSet[p] then pcall(applyT, p) end end
end

----------------------------------------------------------------------
-- SPIRIT AURAS (from the blue spirit reference) : spikes + spinning dashed rings + particles, local only
----------------------------------------------------------------------
local AUS = {
	["Spirit Aura"] = { c1 = rgb(70, 170, 255), c2 = rgb(215, 240, 255),
		spikes = { { n = 16, r = 2.4, y = -2.6, len = 3.4, w = 1.0, tilt = 22, wave = .35, spin = .6 },
			{ n = 9, r = 1.3, y = -2.9, len = 2.1, w = .6, tilt = 8, wave = .3, spin = -.9 },
			{ n = 1, r = 0, y = 1.9, len = 3.6, w = 1.5, tilt = 0, wave = .12, spin = 0, hat = true } },
		rings = { { r = 3.3, y = -2.5, tx = 0, tz = 0, spin = 1.2, w = .14 }, { r = 2.6, y = -1.2, tx = 0, tz = 0, spin = -1.7, w = .1 },
			{ r = 3.0, y = 0, tx = 55, tz = 20, spin = .9, w = .08 },
			{ r = 1.6, y = 2.8, tx = 0, tz = 0, spin = 3, w = .1, seg = 16, hat = true }, { r = 1.1, y = 3.7, tx = 0, tz = 0, spin = -3.4, w = .08, seg = 16, hat = true } },
		part = { tex = "Sparkles", rate = 18, speed = 3, size = .5 } },
	["Frost Shards"] = { c1 = rgb(140, 230, 255), c2 = rgb(255, 255, 255),
		spikes = { { n = 10, r = 3.0, y = -1.0, len = 4.6, w = .8, tilt = 38, wave = .12, spin = .25 },
			{ n = 6, r = 1.8, y = -2.2, len = 2.4, w = .5, tilt = 15, wave = .2, spin = -.4 } },
		rings = { { r = 3.6, y = -1, tx = 0, tz = 0, spin = .7, w = .1, seg = 6 }, { r = 2.8, y = 0, tx = 70, tz = 0, spin = -1.1, w = .08, seg = 6 } },
		part = { tex = "Smoke", rate = 22, speed = 2, size = .35 } },
	["Inferno Crown"] = { c1 = rgb(255, 200, 40), c2 = rgb(255, 40, 0),
		spikes = { { n = 8, r = .9, y = 1.6, len = 3.0, w = .9, tilt = 12, wave = .45, spin = 1.5 },
			{ n = 14, r = 2.2, y = -2.8, len = 2.4, w = .8, tilt = 10, wave = .5, spin = -1.2 } },
		rings = { { r = 2.8, y = -.5, tx = 0, tz = 0, spin = 2.2, w = .18, seg = 16 } },
		part = { tex = "Fire", rate = 30, speed = 5, size = .9 } },
	["Void Orbit"] = { c1 = rgb(150, 0, 255), c2 = rgb(30, 0, 70), orbs = 3,
		spikes = { { n = 6, r = 1.2, y = -3, len = 2.5, w = .6, tilt = -10, wave = .3, spin = .8 } },
		rings = { { r = 3.6, y = 0, tx = 0, tz = 0, spin = 1.4, w = .12 }, { r = 3.6, y = 0, tx = 90, tz = 0, spin = -1.1, w = .12 }, { r = 3.6, y = 0, tx = 0, tz = 90, spin = .8, w = .12 } },
		part = { tex = "Smoke", rate = 14, speed = 1.5, size = 1.2 } },
	["Storm Halo"] = { c1 = rgb(255, 245, 120), c2 = rgb(120, 200, 255),
		spikes = { { n = 8, r = .6, y = 0, len = 4.5, w = .3, tilt = 90, wave = .5, spin = .7 },
			{ n = 5, r = .5, y = .2, len = 3.2, w = .2, tilt = 70, wave = .6, spin = -1.3 } },
		rings = { { r = 1.9, y = 3.1, tx = 0, tz = 0, spin = 2.5, w = .16, seg = 24 }, { r = 3.2, y = 0, tx = 80, tz = 10, spin = -1.5, w = .08, seg = 20 } },
		part = { tex = "Sparkles", rate = 35, speed = 6, size = .4 } },
}
local AUN = { "Spirit Aura", "Frost Shards", "Inferno Crown", "Void Orbit", "Storm Halo" }
local auFolder = Instance.new("Folder")
auFolder.Name = "SefAura"
local au = { style = nil, groups = {}, rings = {}, orbs = {}, shown = false, t = 0 }
local function mkRoot()
	local p = newPart(Vector3.new(.2, .2, .2))
	p.Parent = auFolder
	return p
end
local function mkBeam(root, a0, a1, w0, w1)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = w0, w1
	b.FaceCamera = true b.LightEmission = 1 b.LightInfluence = 0 b.Segments = 1
	b.Color = ColorSequence.new(S.au_c1, S.au_c2)
	b.Transparency = NumberSequence.new(.05)
	b.Parent = root
	return b
end
local function mkAtt(p) local a = Instance.new("Attachment") a.Parent = p return a end
local function buildAura()
	auFolder:ClearAllChildren()
	au.groups, au.rings, au.orbs, au.beams = {}, {}, {}, {}
	au.style = S.au_style
	local sp = AUS[S.au_style] or AUS["Spirit Aura"]
	au.root = mkRoot()
	au.root.Size = Vector3.new(5, .2, 5)
	for gi, g in ipairs(sp.spikes) do
		local root = mkRoot()
		local items = {}
		for i = 1, g.n do
			local a0, a1 = mkAtt(root), mkAtt(root)
			local b = mkBeam(root, a0, a1, g.w, 0)
			au.beams[#au.beams + 1] = b
			items[i] = { a0 = a0, a1 = a1, b = b, ang = (i - 1) / g.n * TAU }
		end
		au.groups[gi] = { root = root, g = g, items = items }
	end
	for ri, r in ipairs(sp.rings) do
		local root = mkRoot()
		local seg = r.seg or 24
		local atts, beams = {}, {}
		for i = 1, seg do atts[i] = mkAtt(root) end
		for i = 1, seg do
			if i % 2 == 1 then
				local b = mkBeam(root, atts[i], atts[i % seg + 1], r.w, r.w)
				beams[#beams + 1] = b
				au.beams[#au.beams + 1] = b
			end
		end
		au.rings[ri] = { root = root, r = r, atts = atts, beams = beams }
	end
	for i = 1, (sp.orbs or 0) do
		local o = newPart(Vector3.new(.7, .7, .7), PT.Ball, true)
		o.Parent = auFolder
		au.orbs[i] = o
	end
	local pt = sp.part
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = L.TEX[pt.tex] or L.TEX.Sparkles
	pe.Rate = pt.rate pe.Lifetime = NumberRange.new(.8, 1.6) pe.Speed = NumberRange.new(pt.speed * .5, pt.speed)
	pe.SpreadAngle = Vector2.new(25, 25) pe.EmissionDirection = Enum.NormalId.Top pe.LightEmission = 1
	pe.Rotation = NumberRange.new(0, 360)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, pt.size), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .2), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(S.au_c1, S.au_c2)
	pcall(function() pe.Shape = Enum.ParticleEmitterShape.Disc end)
	pe.Parent = au.root
	au.pe = pe
	au.cc1, au.cc2 = S.au_c1, S.au_c2
end
local function auHide() if au.shown then auFolder.Parent = nil au.shown = false end end
L.steps[#L.steps + 1] = function(dt)
	local ch = LP.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not S.au_on or not hrp then auHide() return end
	if au.style ~= S.au_style or not au.root then buildAura() end
	if not au.shown then auFolder.Parent = fxFolder au.shown = true end
	au.t = au.t + dt * S.au_spd
	local t, sz = au.t, S.au_sz
	local pos = hrp.Position
	if au.cc1 ~= S.au_c1 or au.cc2 ~= S.au_c2 then
		au.cc1, au.cc2 = S.au_c1, S.au_c2
		for _, b in ipairs(au.beams) do b.Color = ColorSequence.new(S.au_c1, S.au_c2) end
		au.pe.Color = ColorSequence.new(S.au_c1, S.au_c2)
	end
	au.root.CFrame = CFrame.new(pos + Vector3.new(0, -2.8 * sz, 0))
	au.root.Size = Vector3.new(5 * sz, .2, 5 * sz)
	for _, G2 in ipairs(au.groups) do
		local g = G2.g
		G2.root.CFrame = CFrame.new(pos) * CFrame.Angles(0, t * g.spin, 0)
		local tl = math.rad(g.tilt)
		local en = not (g.hat and not S.au_hat)
		for i, it in ipairs(G2.items) do
			local ca, sa = cos(it.ang), sin(it.ang)
			local base = Vector3.new(ca * g.r, g.y, sa * g.r) * sz
			local dir = Vector3.new(ca, 0, sa) * sin(tl) + Vector3.yAxis * cos(tl)
			local len = g.len * sz * (1 + g.wave * sin(t * 3.2 + i * .9) * sin(t * 1.3 + i))
			it.a0.Position = base
			it.a1.Position = base + dir * len
			it.b.Width0 = g.w * sz * (1 + .15 * sin(t * 6 + i))
			it.b.Enabled = en
		end
	end
	for _, R in ipairs(au.rings) do
		local r = R.r
		R.root.CFrame = CFrame.new(pos + Vector3.new(0, r.y * sz, 0)) * CFrame.Angles(0, t * r.spin, 0) * CFrame.Angles(math.rad(r.tx), 0, math.rad(r.tz))
		if R.sz ~= sz then
			R.sz = sz
			for i, a in ipairs(R.atts) do
				local ang = (i - 1) / #R.atts * TAU
				a.Position = Vector3.new(cos(ang), 0, sin(ang)) * r.r * sz
			end
		end
		if r.hat then
			local en = S.au_hat
			for _, b in ipairs(R.beams) do b.Enabled = en end
		end
	end
	for i, o in ipairs(au.orbs) do
		local a = t * 2.4 + i * TAU / #au.orbs
		o.Position = pos + Vector3.new(cos(a) * 3.4, sin(a * .7 + i) * 1.5, sin(a) * 3.4) * sz
		o.Color = S.au_c1:Lerp(S.au_c2, .5 + .5 * sin(t * 2 + i))
	end
end

----------------------------------------------------------------------
-- CONSTELLATION SKY (stars joined by glowing lines, follows the camera)
----------------------------------------------------------------------
local csFolder = Instance.new("Folder")
csFolder.Name = "SefConst"
local cs = { key = nil, stars = {}, beams = {}, shown = false }
local function buildCS()
	csFolder:ClearAllChildren()
	cs.stars, cs.beams = {}, {}
	cs.key = S.cs_n .. "_" .. S.cs_d
	local rnd = Random.new(7)
	local R = 420
	for i = 1, S.cs_n do
		local th, ph = rnd:NextNumber(0, TAU), rnd:NextNumber(.15, 1.25)
		local p = newPart(Vector3.new(3, 3, 3), PT.Ball, true)
		local a = Instance.new("Attachment")
		a.Parent = p
		p.Parent = csFolder
		cs.stars[i] = { p = p, a = a, v = Vector3.new(cos(th) * cos(ph), sin(ph), sin(th) * cos(ph)) * R, ph = rnd:NextNumber(0, TAU) }
	end
	for i = 1, #cs.stars do
		for j = i + 1, #cs.stars do
			if #cs.beams < 120 and (cs.stars[i].v - cs.stars[j].v).Magnitude < S.cs_d * 1.6 then
				local b = Instance.new("Beam")
				b.Attachment0, b.Attachment1 = cs.stars[i].a, cs.stars[j].a
				b.Width0, b.Width1 = 1.1, 1.1
				b.FaceCamera = true b.LightEmission = 1 b.LightInfluence = 0 b.Segments = 1
				b.Parent = cs.stars[i].p
				cs.beams[#cs.beams + 1] = { b = b, ph = rnd:NextNumber(0, TAU) }
			end
		end
	end
end
L.steps[#L.steps + 1] = function(dt, t)
	local c = cam()
	if not S.cs_on or not c then
		if cs.shown then csFolder.Parent = nil cs.shown = false end
		return
	end
	if cs.key ~= (S.cs_n .. "_" .. S.cs_d) then buildCS() end
	if not cs.shown then csFolder.Parent = fxFolder cs.shown = true end
	local cp = c.CFrame.Position
	for _, s in ipairs(cs.stars) do
		s.p.Position = cp + s.v
		s.p.Color = S.cs_c
		s.p.Transparency = .1 + .5 * (sin(t * S.cs_tw + s.ph) ^ 2)
	end
	for _, b in ipairs(cs.beams) do
		b.b.Color = ColorSequence.new(S.cs_c)
		b.b.Transparency = NumberSequence.new(.4 + .35 * sin(t * S.cs_tw * .7 + b.ph))
	end
end

----------------------------------------------------------------------
-- UI : Covers tab, Grab Lines additions, Effects additions
----------------------------------------------------------------------
local hueTok = 0
local function hueChanged()
	hueTok = hueTok + 1
	local my = hueTok
	task.delay(.25, function() if my == hueTok then L.coverBuild() end end)
end
L.tabs.Covers = tab("Covers", 19)
L.tabs.Covers.btn.LayoutOrder = 18
H("Menu Cover (frame around the menu)")
T("Enable Cover", "cv_on", true, function() L.coverBuild() end)
DD("Cover Style", "cv_style", STN, "Spirit Fox", function() L.coverBuild() end)
SL("Frame Opacity", "cv_op", 0, 1, .92, 2)
SL("Animation Speed", "cv_spd", .2, 3, 1, 2)
SL("Hue Shift", "cv_hue", 0, 1, 0, 2, hueChanged)
T("Ornaments (ears / spikes / flames / rings)", "cv_orn", true)
SL("Offset Up (cover sits above the menu)", "cv_oy", 0, 160, 88, 0)
SL("Offset Sideways", "cv_ox", -80, 80, 0, 0)
T("Outline Over Menu", "cv_edge", true)
SL("Saturation", "cv_sat", 0, 1.6, 1, 2, hueChanged)
SL("Brightness", "cv_br", .4, 1.5, 1, 2, hueChanged)
B("Reset Cover Look", function()
	Ctl.cv_oy.set(88) Ctl.cv_ox.set(0) Ctl.cv_hue.set(0, true) Ctl.cv_sat.set(1, true) Ctl.cv_br.set(1, true) Ctl.cv_op.set(.92)
	L.coverBuild()
end)
B("Random Cover", function()
	Ctl.cv_style.set(STN[math.random(#STN)], true)
	L.coverBuild()
end)

L.G3N = { "DNA Helix", "Chain Links", "Plasma Coil", "Energy Pipe", "Crystal Shards", "Orbit Rings", "Laser Core", "Star Trail" }
local ALLGV = {}
for _, n in ipairs(GVN) do ALLGV[#ALLGV + 1] = n end
for _, n in ipairs(L.G3N) do ALLGV[#ALLGV + 1] = n end
L.ALLGV = ALLGV
L.tabs["3D Lines"] = tab("3D Lines", 3)
H("Animated + 3D Grab Lines (13 styles, first 5 beam-based, last 8 part-built 3D)")
T("Animated Grab Line", "gv_on", false)
U.PK("Line Style", "gv_style", ALLGV, "Spirit Helix")
CO("VFX Color 1", "gv_c1", rgb(0, 255, 255))
CO("VFX Color 2", "gv_c2", rgb(120, 80, 255))
T("Rainbow VFX", "gv_rain", false)
SL("VFX Thickness", "gv_w", .05, 1.2, .25, 2)
SL("Wave Size", "gv_amp", .2, 6, 1.6, 1)
SL("Animation Speed", "gv_spd", .2, 4, 1.5, 1)
SL("Detail (beam styles, more = smoother)", "gv_n", 8, 40, 24, 0)
T("Tip Sparkles", "gv_tip", true)
use("Grab Lines")
H("Pallet Transparency (grab settings)")
T("Make Held Pallet Transparent", "gh_on", false)
SL("Held Pallet Transparency", "gh_tr", 0, .95, .6, 2)
T("Also Other Held Toys", "gh_any", false)
T("Make My Pallets Transparent", "gm_on", false)
SL("My Pallets Transparency", "gm_tr", 0, .95, .5, 2)

use("Effects")
H("Spirit Auras (character)")
T("Character Aura", "au_on", false)
DD("Aura Style", "au_style", AUN, "Spirit Aura", function(n)
	local sp = AUS[n]
	if sp then Ctl.au_c1.set(sp.c1, true) Ctl.au_c2.set(sp.c2, true) end
end)
CO("Aura Color 1", "au_c1", AUS["Spirit Aura"].c1)
CO("Aura Color 2", "au_c2", AUS["Spirit Aura"].c2)
SL("Aura Size", "au_sz", .5, 2.5, 1, 2)
SL("Aura Speed", "au_spd", .2, 3, 1, 2)
T("Cone Hat + Rings (Spirit Aura)", "au_hat", true)
H("Constellation Sky")
T("Constellation Network", "cs_on", false)
SL("Star Count", "cs_n", 12, 60, 34, 0)
SL("Link Distance", "cs_d", 40, 300, 140, 0)
SL("Twinkle Speed", "cs_tw", .2, 6, 1.6, 1)
CO("Constellation Color", "cs_c", rgb(190, 215, 255))

L.cleanups[#L.cleanups + 1] = function()
	for p in pairs(origT) do relT(p) end
	pcall(function() gvFolder:Destroy() end)
	pcall(function() auFolder:Destroy() end)
	pcall(function() csFolder:Destroy() end)
	local gp = workspace:FindFirstChild("GrabParts")
	if gp then for _, d in ipairs(gp:GetDescendants()) do if d:IsA("Beam") then pcall(function() d.Enabled = true end) end end end
end

buildGV()
L.coverBuild()
end)


-- module: 12_ftap_plus (v2 additions; all local-only visuals)
MOD("12_ftap_plus", function()
local S, Ctl, L, T, SL, CO, DD, B, H = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H
local new, tw, hsv, C, LP, Players = U.new, U.tw, U.hsv, U.C, U.LP, U.Players
local burst, ring, sphere, mk = U.burst, U.ring, U.sphere, U.mk
local Debris, Lighting = U.Debris, U.Lighting
local rgb = Color3.fromRGB

L.tabs["FTAP+"] = tab("FTAP+", 18)

-- ---------------------------------------------------------- scene presets
H("Scene Presets (lighting + atmosphere + grade)")
local SCN = {
	["Clean Day"] = { lt = { lt_clock = 13, lt_br = 2.2, lt_exp = 0 }, at = { .28, 0, rgb(200, 215, 235), rgb(110, 125, 150), 0, .5 }, cc = { 0, .08, .12, rgb(255, 255, 255) } },
	["Golden Hour"] = { lt = { lt_clock = 17.6, lt_br = 2.6, lt_exp = .1, lt_top = rgb(255, 170, 90) }, at = { .38, .1, rgb(255, 196, 140), rgb(170, 100, 80), 2.5, 1.5 }, cc = { .02, .12, .2, rgb(255, 230, 205) } },
	["Neon Night"] = { lt = { lt_clock = 0.5, lt_br = 1.2, lt_amb = rgb(60, 30, 110), lt_outamb = rgb(90, 40, 160), lt_exp = .2 }, at = { .45, .2, rgb(120, 60, 220), rgb(30, 10, 80), 3, 2 }, cc = { 0, .25, .45, rgb(225, 200, 255) } },
	["Foggy Morning"] = { lt = { lt_clock = 7, lt_br = 1.6, lt_exp = -.1 }, at = { .62, .25, rgb(210, 215, 220), rgb(150, 160, 170), 0, 6 }, cc = { .03, -.08, -.2, rgb(235, 240, 245) } },
	["Blood Moon"] = { lt = { lt_clock = 23, lt_br = 1, lt_amb = rgb(90, 20, 20), lt_outamb = rgb(130, 30, 30), lt_exp = 0 }, at = { .5, .1, rgb(170, 40, 40), rgb(60, 0, 0), 4, 2 }, cc = { -.02, .3, -.2, rgb(255, 190, 180) } },
	["Arctic"] = { lt = { lt_clock = 11, lt_br = 2.8, lt_exp = .15, lt_amb = rgb(160, 190, 230) }, at = { .4, .05, rgb(200, 230, 255), rgb(120, 160, 210), 1, 3 }, cc = { .04, .1, -.15, rgb(215, 235, 255) } },
	["Toxic Haze"] = { lt = { lt_clock = 15, lt_br = 1.8, lt_amb = rgb(60, 110, 40) }, at = { .55, .15, rgb(150, 230, 90), rgb(40, 90, 20), 2, 4 }, cc = { 0, .2, .3, rgb(200, 255, 180) } },
}
local SCNN = { "None" }
for k in pairs(SCN) do SCNN[#SCNN + 1] = k end
table.sort(SCNN, function(a, b) if a == "None" then return true elseif b == "None" then return false end return a < b end)
local function setc(k, v) if Ctl[k] then pcall(Ctl[k].set, v) end end
DD("Scene Preset", "sc_pre", SCNN, "None", function(n)
	local p = SCN[n]
	if not p then pcall(L.resetLighting) setc("at_on", false) setc("cc_on", false) return end
	pcall(L.resetLighting)
	for k, v in pairs(p.lt) do setc(k, v) end
	local a = p.at
	setc("at_den", a[1]) setc("at_off", a[2]) setc("at_col", a[3]) setc("at_dec", a[4]) setc("at_gl", a[5]) setc("at_hz", a[6])
	setc("at_on", true)
	local c = p.cc
	setc("cc_br", c[1]) setc("cc_ct", c[2]) setc("cc_sat", c[3]) setc("cc_tint", c[4])
	setc("cc_on", true)
	if S.sc_bloom then setc("bloom_i", .8) setc("bloom_s", 28) setc("bloom_t", 1.2) setc("bloom_on", true) end
end)
T("Add Soft Bloom With Presets", "sc_bloom", true)

-- ---------------------------------------------------------- ESP-style outlines
H("Player Outlines (ESP-style, local only)")
T("Player Outlines", "es_on", false)
DD("Outline Color Mode", "es_mode", { "Distance", "Team", "Rainbow", "Custom" }, "Distance")
CO("Custom Outline Color", "es_col", rgb(255, 80, 120))
SL("Fill Transparency", "es_fill", 0, 1, .85, 2)
T("Show Through Walls", "es_top", true)
SL("Max Distance (studs)", "es_max", 50, 2000, 600, 0)
T("Name + Distance Tags", "es_tag", false)
SL("Tag Size", "es_tsz", 10, 22, 13, 0)
-- Roblox renders at most 31 Highlights at once; we cap to the nearest ones.
local esFolder = new("Folder", { Name = "SefESP" }, U.fxFolder)
local esTags = new("Folder", { Name = "SefESPTags" }, U.hud)
local esObj = {}
local function esClear(p)
	local o = esObj[p]
	if o then pcall(function() o.hl:Destroy() end) pcall(function() o.tag:Destroy() end) esObj[p] = nil end
end
C(Players.PlayerRemoving, esClear)
local esAcc = 0
L.steps[#L.steps + 1] = function(dt, t)
	if not S.es_on then
		if next(esObj) then for p in pairs(esObj) do esClear(p) end end
		return
	end
	esAcc = esAcc + dt
	if esAcc < .1 then return end
	esAcc = 0
	local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local ch = p.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			if hrp and me then
				local d = (hrp.Position - me.Position).Magnitude
				if d <= S.es_max then list[#list + 1] = { p = p, ch = ch, hrp = hrp, d = d } end
			end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local keep = {}
	for i = 1, math.min(#list, 30) do
		local e = list[i]
		keep[e.p] = true
		local o = esObj[e.p]
		if not o or o.ch ~= e.ch or not o.hl.Parent then
			esClear(e.p)
			o = { ch = e.ch }
			o.hl = new("Highlight", { Name = "SefESP", Adornee = e.ch, OutlineTransparency = 0 }, esFolder)
			o.tag = new("BillboardGui", { Name = "SefTag", Adornee = e.hrp, AlwaysOnTop = true, Size = UDim2.fromOffset(160, 34), StudsOffset = Vector3.new(0, 3.6, 0), LightInfluence = 0 }, esTags)
			o.lbl = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextStrokeTransparency = .4, TextColor3 = Color3.new(1, 1, 1) }, o.tag)
			esObj[e.p] = o
		end
		local col
		if S.es_mode == "Team" and e.p.Team then col = e.p.TeamColor.Color
		elseif S.es_mode == "Rainbow" then col = hsv(t * .3 + i * .07)
		elseif S.es_mode == "Custom" then col = S.es_col
		else col = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(60, 255, 120), math.clamp(e.d / S.es_max, 0, 1)) end
		o.hl.OutlineColor = col
		o.hl.FillColor = col
		o.hl.FillTransparency = S.es_fill
		o.hl.DepthMode = S.es_top and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		o.tag.Enabled = S.es_tag
		if S.es_tag then
			o.lbl.Text = e.p.DisplayName .. "  [" .. math.floor(e.d) .. "m]"
			o.lbl.TextSize = S.es_tsz
			o.lbl.TextColor3 = col
		end
	end
	for p in pairs(esObj) do if not keep[p] then esClear(p) end end
end

-- ---------------------------------------------------------- grab tip + release fx
H("Grab & Throw FX (your own grabs, local only)")
T("Grab Start Burst", "gx_start", false)
T("Grab Tip Pulse Rings", "gx_pulse", false)
SL("Pulse Rate (per sec)", "gx_rate", .5, 8, 2.5, 1)
T("Release / Throw Burst", "gx_rel", false)
T("Throw Shockwave", "gx_wave", false)
T("Use Grab Line Colors", "gx_usegl", true)
CO("Grab FX Color", "gx_col", rgb(0, 230, 255))
SL("Grab FX Scale", "gx_sc", .3, 3, 1, 2)
local function gxCol(t)
	if S.gx_usegl then
		if S.gl_rain then return hsv(t * (S.gl_rs or .5)) end
		return S.gl_c1 or S.gx_col
	end
	return S.gx_col
end
local function tipOf(gp)
	local best
	for _, d in ipairs(gp:GetDescendants()) do
		if d:IsA("BasePart") then best = d break end
	end
	return best
end
local gxHeld, gxLast, gxAcc, gxVel = false, nil, 0, Vector3.zero
L.steps[#L.steps + 1] = function(dt, t)
	local gp = workspace:FindFirstChild("GrabParts")
	local tip = gp and tipOf(gp)
	local sc = S.gx_sc
	if tip then
		local pos = tip.Position
		if gxLast then gxVel = gxVel:Lerp((pos - gxLast) / math.max(dt, 1e-3), .35) end
		gxLast = pos
		if not gxHeld then
			gxHeld = true
			if S.gx_start then
				local c = gxCol(t)
				burst(pos, c, math.floor(18 * sc), 10 * sc, .5, .35 * sc)
				sphere(pos, c, .4 * sc, 3.2 * sc, .35)
			end
		end
		if S.gx_pulse then
			gxAcc = gxAcc + dt
			if gxAcc >= 1 / S.gx_rate then
				gxAcc = 0
				ring(pos, gxCol(t), 3.5 * sc, .45, t % math.pi)
			end
		end
	elseif gxHeld then
		gxHeld = false
		if gxLast then
			local c = gxCol(t)
			local spd = gxVel.Magnitude
			if S.gx_rel then
				burst(gxLast, c, math.floor(math.clamp(10 + spd * .3, 10, 60) * sc), math.clamp(spd * .25, 6, 40) * sc, .7, .45 * sc, nil, gxVel * -.15)
			end
			if S.gx_wave and spd > 25 then
				ring(gxLast, c, math.clamp(spd * .15, 6, 30) * sc, .6, 0)
				ring(gxLast, Color3.new(1, 1, 1), math.clamp(spd * .1, 4, 20) * sc, .45, math.pi / 2)
				pcall(L.addShake, math.clamp(spd / 300, .05, .35))
			end
		end
		gxLast, gxVel = nil, Vector3.zero
	end
end

-- ---------------------------------------------------------- own character fx
H("My Character FX (local only)")
T("Landing Dust", "mc_land", false)
SL("Landing Sensitivity", "mc_lth", 20, 150, 45, 0)
CO("Dust Color", "mc_lc", rgb(215, 205, 185))
T("Jump Puff", "mc_jump", false)
T("Ragdoll Spark Trail", "mc_rag", false)
CO("Spark Color", "mc_rc", rgb(255, 200, 90))
T("Soft Body Glow Light", "mc_glow", false)
CO("Glow Color", "mc_gc", rgb(120, 200, 255))
SL("Glow Range", "mc_gr", 4, 30, 12, 0)
local lastVY, ragAcc, jumpDb = 0, 0, 0
local function groundBelow(hrp)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { LP.Character, workspace.CurrentCamera }
	local r = workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0), rp)
	return r and r.Position
end
L.steps[#L.steps + 1] = function(dt, t)
	local ch = LP.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	local v = hrp.AssemblyLinearVelocity
	jumpDb = math.max(0, jumpDb - dt)
	if S.mc_land and lastVY < -S.mc_lth and v.Y > -5 then
		local g = groundBelow(hrp)
		if g then
			local k = math.clamp(-lastVY / 100, .4, 2.5)
			burst(g + Vector3.new(0, .3, 0), S.mc_lc, math.floor(14 * k), 9 * k, .9, 1.1 * k, TEX and TEX.Smoke, Vector3.new(0, 3, 0))
			ring(g + Vector3.new(0, .2, 0), S.mc_lc, 7 * k, .5, 0)
		end
	end
	if S.mc_jump and jumpDb == 0 and lastVY < 2 and v.Y > 25 and hum.FloorMaterial ~= Enum.Material.Air then
		jumpDb = .4
		burst(hrp.Position - Vector3.new(0, 2.6, 0), S.mc_lc, 8, 5, .5, .7, TEX and TEX.Smoke)
	end
	lastVY = v.Y
	local st = hum:GetState()
	if S.mc_rag and (st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown) and v.Magnitude > 20 then
		ragAcc = ragAcc + dt
		if ragAcc > .05 then
			ragAcc = 0
			burst(hrp.Position, S.mc_rc, 3, 3, .5, .25)
		end
	end
	local gl = hrp:FindFirstChild("SefBodyGlow")
	if S.mc_glow then
		if not gl then gl = new("PointLight", { Name = "SefBodyGlow", Shadows = false }, hrp) end
		gl.Color = S.mc_gc gl.Range = S.mc_gr gl.Brightness = 1.6 + .4 * math.sin(t * 2)
	elseif gl then gl:Destroy() end
end

L.cleanups[#L.cleanups + 1] = function()
	for p in pairs(esObj) do esClear(p) end
	pcall(function() esFolder:Destroy() end)
	pcall(function() esTags:Destroy() end)
	pcall(function()
		local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		local g = hrp and hrp:FindFirstChild("SefBodyGlow")
		if g then g:Destroy() end
	end)
end
end)

-- module: 13_grab3d  (8 new part-built 3D grab lines, stretch / elastic engine, 3D tips, live preview)
MOD("13_grab3d", function()
local S, Ctl, L, T, SL, CO, DD, B, H, use, PK = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.usePage, U.PK
local new, hsv, LP, cam, fxFolder, RS = U.new, U.hsv, U.LP, U.cam, U.fxFolder, U.RS
local sin, cos, floor, max, min, clamp, abs, sqrt, pi = math.sin, math.cos, math.floor, math.max, math.min, math.clamp, math.abs, math.sqrt, math.pi
local TAU = pi * 2
local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)

----------------------------------------------------------------------
-- controls (tab "3D Lines" is created in the covers/vfx module)
----------------------------------------------------------------------
use("3D Lines")
H("3D Line Look (the 8 part-built 3D styles)")
DD("Color Style", "g3_cmode", { "Flow", "Gradient", "Pulse", "Solid" }, "Flow")
DD("Material", "g3_mat", { "Neon", "Plastic", "Glass", "ForceField" }, "Neon")
SL("Opacity", "g3_op", .05, 1, .92, 2)
SL("Detail Density", "g3_dens", .4, 2, 1, 2)
SL("Quality (part limit)", "g3_q", 1, 3, 2, 0)
SL("Twist Amount", "g3_twist", .2, 3, 1, 2)
SL("Taper (thin at the ends)", "g3_taper", 0, 1, .35, 2)
H("Stretch (how the line behaves when you pull far)")
SL("Stretch Thinning", "g3_thin", 0, 1.2, .35, 2)
SL("Elastic Stretch (springy tip)", "g3_elastic", 0, 1, .25, 2)
SL("Rope Sag", "g3_sag", 0, 1, 0, 2)
H("Grab Tip (3D)")
PK("Tip Shape", "g3_tip", { "Gyro", "Orb", "Diamond", "Cube Spin", "None" }, "Gyro")
SL("Tip Size", "g3_tipsz", .3, 3, 1, 2)
T("Tip Glow Shell", "g3_shell", true)
T("Tip Light", "g3_light", false)
T("Show Start Orb (at your hand)", "g3_origin", false)
H("Preview")
T("Preview Line (no grab needed, 3D styles)", "g3_demo", false)

----------------------------------------------------------------------
-- part pools : everything is drawn with real anchored parts
----------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "SefG3D"
local KINDS = { "cyl", "ball", "blk" }
local pool = { cyl = {}, ball = {}, blk = {} }
local usedN = { cyl = 0, ball = 0, blk = 0 }
local lastN = { cyl = 0, ball = 0, blk = 0 }
local total = 0
local shown = false
local MAT = Enum.Material.Neon
local MATS3 = { Neon = Enum.Material.Neon, Plastic = Enum.Material.SmoothPlastic, Glass = Enum.Material.Glass, ForceField = Enum.Material.ForceField }
local G = { cap = 170, t = 0, spd = 1, qf = 1, dens = 1, twist = 1, taper = 0, amp = 1, w = .25, tr = .1, sag = 0, thinF = 1, len = 1 }

local function mkPart(kind)
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "cyl" then p.Shape = Enum.PartType.Cylinder elseif kind == "ball" then p.Shape = Enum.PartType.Ball end
	return p
end
local function take(kind)
	if total >= G.cap then return nil end
	local u = usedN[kind] + 1
	usedN[kind] = u
	total = total + 1
	local p = pool[kind][u]
	if not p then p = mkPart(kind) pool[kind][u] = p end
	if p.Parent ~= folder then p.Parent = folder end
	return p
end
local function paint(p, col, tr)
	p.Color = col
	p.Transparency = clamp(tr, 0, 1)
	p.Material = MAT
end
function G.cyl(a, b, th, col, tr)
	local d = b - a
	local len = d.Magnitude
	if len < .01 then return end
	local p = take("cyl")
	if not p then return end
	p.Size = V3(len, th, th)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, pi / 2, 0)
	paint(p, col, tr)
end
function G.disc(c, dir, dia, th, col, tr)
	local p = take("cyl")
	if not p then return end
	p.Size = V3(th, dia, dia)
	p.CFrame = CFrame.lookAt(c, c + dir) * CFrame.Angles(0, pi / 2, 0)
	paint(p, col, tr)
end
function G.ball(pos, sz, col, tr)
	local p = take("ball")
	if not p then return end
	p.Size = V3(sz, sz, sz)
	p.CFrame = CFrame.new(pos)
	paint(p, col, tr)
end
function G.blk(cf, size, col, tr)
	local p = take("blk")
	if not p then return end
	p.Size = size
	p.CFrame = cf
	paint(p, col, tr)
end
local function beginFrame()
	usedN.cyl, usedN.ball, usedN.blk, total = 0, 0, 0, 0
end
local function endFrame()
	for _, k in ipairs(KINDS) do
		local pl = pool[k]
		for i = usedN[k] + 1, lastN[k] do
			local p = pl[i]
			if p then p.Parent = nil end
		end
		lastN[k] = usedN[k]
	end
end

-- tip helper part (particles + light)
local tipPart = Instance.new("Part")
tipPart.Anchored = true tipPart.CanCollide = false tipPart.CanQuery = false tipPart.CanTouch = false
tipPart.CastShadow = false tipPart.Transparency = 1 tipPart.Size = V3(.3, .3, .3)
tipPart.Parent = folder
local tipPE = Instance.new("ParticleEmitter")
tipPE.Texture = "rbxasset://textures/particles/sparkles_main.dds"
tipPE.Rate = 34 tipPE.Lifetime = NumberRange.new(.35, .8) tipPE.Speed = NumberRange.new(4, 10)
tipPE.SpreadAngle = Vector2.new(180, 180) tipPE.LightEmission = 1
tipPE.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, .6), NumberSequenceKeypoint.new(1, 0) })
tipPE.Enabled = false
tipPE.Parent = tipPart
local tipLight = Instance.new("PointLight")
tipLight.Range = 14 tipLight.Brightness = 2 tipLight.Shadows = false tipLight.Enabled = false
tipLight.Parent = tipPart

local spring = { pos = nil, vel = V3() }
local function hideAll()
	for _, k in ipairs(KINDS) do
		local pl = pool[k]
		for i = 1, lastN[k] do
			local p = pl[i]
			if p then p.Parent = nil end
		end
		lastN[k] = 0
	end
	spring.pos = nil
	tipPE.Enabled = false
	tipLight.Enabled = false
	if shown then folder.Parent = nil shown = false end
end

----------------------------------------------------------------------
-- geometry helpers (all read the per-frame state in G)
----------------------------------------------------------------------
local function P(u)
	return G.A + G.d * u + V3(0, -G.sag * 4 * u * (1 - u), 0)
end
local function R(u, a, r)
	return P(u) + G.right * (cos(a) * r) + G.up * (sin(a) * r)
end
local function envf(u)
	return max(0, sin(u * pi)) ^ .55
end
local function wid(u)
	return G.w * (1 - G.taper + G.taper * envf(u))
end
function G.col(u, k)
	k = k or 0
	if S.gv_rain then return hsv(G.t * .35 + u * .6 + k * .08, .85, 1) end
	local m = S.g3_cmode
	if m == "Solid" then return S.gv_c1
	elseif m == "Pulse" then return S.gv_c1:Lerp(S.gv_c2, (sin(G.t * 3 + k) + 1) / 2)
	elseif m == "Flow" then return S.gv_c1:Lerp(S.gv_c2, (sin(u * TAU * 1.5 - G.t * 3 + k) + 1) / 2) end
	return S.gv_c1:Lerp(S.gv_c2, clamp(u, 0, 1))
end
function G.cnt(per, lo, hi, perStep)
	local n = floor(G.len * per * G.dens * G.qf)
	n = clamp(n, lo, hi)
	return max(2, min(n, floor(G.cap * .8 / perStep)))
end

----------------------------------------------------------------------
-- the 8 styles
----------------------------------------------------------------------
local STY3 = {}

STY3["DNA Helix"] = function()
	local n = G.cnt(1.1, 12, 56, 4.5)
	local turns = max(1.5, G.len / 7) * G.twist
	local prev1, prev2
	for i = 0, n do
		local u = i / n
		local e = envf(u)
		local a = u * TAU * turns - G.t * 3
		local r = G.amp * .55 * (.25 + .75 * e)
		local p1, p2 = R(u, a, r), R(u, a + pi, r)
		local c1, c2 = G.col(u, 0), G.col(u, 2)
		local th = wid(u)
		G.ball(p1, th * 1.7, c1, G.tr)
		G.ball(p2, th * 1.7, c2, G.tr)
		if prev1 then
			G.cyl(prev1, p1, th * .55, c1, G.tr + .08)
			G.cyl(prev2, p2, th * .55, c2, G.tr + .08)
		end
		if i % 2 == 0 then G.cyl(p1, p2, th * .35, c1:Lerp(c2, .5), G.tr + .22) end
		prev1, prev2 = p1, p2
	end
end

STY3["Chain Links"] = function()
	local linkL = max(.9, G.w * 4.4)
	local n = clamp(floor(G.len / (linkL * .8)), 2, floor(G.cap * .8 / 4))
	local spacing = G.len / n
	linkL = max(linkL, spacing * 1.25)
	local half = linkL / 2
	local off = G.w * 1.3
	for i = 1, n do
		local u = (i - .5) / n
		local c = P(u)
		local roll = ((i % 2 == 0) and 0 or pi / 2) + sin(G.t * 1.5 + i) * .12
		local side = G.right * cos(roll) + G.up * sin(roll)
		local col = G.col(u, i * .4)
		local f, b = G.dir * half, G.dir * -half
		G.cyl(c + b + side * off, c + f + side * off, G.w * .85, col, G.tr)
		G.cyl(c + b - side * off, c + f - side * off, G.w * .85, col, G.tr)
		G.ball(c + b, off * 2 + G.w * .85, col, G.tr + .05)
		G.ball(c + f, off * 2 + G.w * .85, col, G.tr + .05)
	end
end

STY3["Plasma Coil"] = function()
	local n = G.cnt(2.2, 24, 100, 1)
	local turns = max(3, G.len / 2.2) * G.twist
	local prev
	for i = 0, n do
		local u = i / n
		local e = envf(u)
		local a = u * TAU * turns - G.t * 6
		local r = G.amp * .42 * (.35 + .65 * e) * (1 + .18 * sin(G.t * 7 + u * 20))
		local p = R(u, a, r)
		if prev then G.cyl(prev, p, wid(u) * 1.15, G.col(u, 0), G.tr) end
		prev = p
	end
	for k = 0, 5 do
		local u0, u1 = k / 6, (k + 1) / 6
		G.cyl(P(u0), P(u1), G.w * .55, WHITE:Lerp(G.col((u0 + u1) / 2, 1), .45), G.tr + .25)
	end
end

STY3["Energy Pipe"] = function()
	local seg = 8
	for k = 0, seg - 1 do
		local u0, u1 = k / seg, (k + 1) / seg
		local um = (u0 + u1) / 2
		G.cyl(P(u0), P(u1), G.w * 3.4 * (1 - G.taper * .4 + G.taper * .4 * envf(um)), G.col(um, 0), min(.96, G.tr + .62))
		G.cyl(P(u0), P(u1), G.w * 1.1, WHITE:Lerp(G.col(um, 1), .5), G.tr)
	end
	local nb = clamp(floor(G.len / 3.2 * G.dens), 3, 26)
	for i = 0, nb - 1 do
		local u = ((i / nb) + G.t * .12) % 1
		local pulse = .85 + .3 * sin(G.t * 6 + i)
		G.disc(P(u), G.dir, G.w * 5.4 * pulse, G.w * .7, G.col(u, 2), G.tr + .04)
	end
end

STY3["Crystal Shards"] = function()
	for k = 0, 5 do
		G.cyl(P(k / 6), P((k + 1) / 6), G.w * .45, G.col(k / 6, 0), .4 + G.tr * .5)
	end
	local n = G.cnt(.55, 6, 34, 2)
	for i = 1, n do
		local u = (i - .5) / n
		local e = envf(u)
		local ph = i * 2.399
		local a = ph + G.t * 1.2
		local r = G.amp * .35 * e * (.6 + .4 * sin(G.t * 2 + ph))
		local pos = R(u, a, r)
		local sz = G.w * (3.2 + 2.4 * sin(G.t * 3 + ph * 1.7) ^ 2)
		local cf = CFrame.lookAt(pos, pos + G.dir) * CFrame.Angles(G.t * 1.5 + ph, G.t * 2.1 + ph * .6, pi / 4)
		G.blk(cf, V3(sz, sz * 1.9, sz), G.col(u, i * .3), G.tr)
	end
end

STY3["Orbit Rings"] = function()
	local nr = G.cnt(.38, 3, 11, 9)
	local dots = 8
	for i = 1, nr do
		local u = (i - .5) / nr
		local e = envf(u)
		local rad = G.amp * .55 * (.3 + .7 * e) * (1 + .15 * sin(G.t * 4 + i))
		local c = P(u)
		G.disc(c, G.dir, rad * 2, G.w * .35, G.col(u, 0), min(.96, G.tr + .72))
		local base = G.t * 2.2 * ((i % 2 == 0) and 1 or -1) + i
		for k = 1, dots do
			local a = base + k / dots * TAU
			G.ball(c + G.right * (cos(a) * rad) + G.up * (sin(a) * rad), G.w * 1.7, G.col(u, k * .3), G.tr)
		end
	end
	for k = 0, 5 do
		G.cyl(P(k / 6), P((k + 1) / 6), G.w * .4, G.col(k / 6, 1), G.tr + .3)
	end
end

STY3["Laser Core"] = function()
	local seg = 8
	for k = 0, seg - 1 do
		local u0, u1 = k / seg, (k + 1) / seg
		local um = (u0 + u1) / 2
		local w = wid(um)
		G.cyl(P(u0), P(u1), w * 1.5, WHITE:Lerp(G.col(um, 0), .35), G.tr)
		G.cyl(P(u0), P(u1), w * 3.6, G.col(um, 0), min(.96, G.tr + .45))
		G.cyl(P(u0), P(u1), w * 6.4, G.col(um, 1), min(.97, G.tr + .8))
	end
	local n = G.cnt(1.1, 12, 40, 3)
	for s = 0, 2 do
		local prev
		for i = 0, n do
			local u = i / n
			local a = u * TAU * max(2, G.len / 5) * G.twist - G.t * 5 + s * TAU / 3
			local p = R(u, a, G.w * 2.6 * (.4 + .6 * envf(u)))
			if prev then G.cyl(prev, p, G.w * .45, G.col(u, s), G.tr) end
			prev = p
		end
	end
	for i = 1, 4 do
		local u = (G.t * .6 + i / 4) % 1
		G.ball(P(u), G.w * 4, WHITE:Lerp(G.col(u, i), .3), G.tr)
	end
end

STY3["Star Trail"] = function()
	for k = 0, 7 do
		G.cyl(P(k / 8), P((k + 1) / 8), G.w * .4, G.col(k / 8, 0), .35 + .3 * sin(G.t * 4 + k))
	end
	local n = G.cnt(.7, 8, 32, 3)
	for i = 1, n do
		local ph = i * 1.618
		local u = ((i - .5) / n + G.t * .08 * (1 + (i % 3) * .3)) % 1
		local e = envf(u)
		local a = ph * 3.1 + G.t * (.8 + (i % 4) * .3)
		local r = G.amp * .5 * e * (.4 + .6 * abs(sin(ph)))
		local pos = R(u, a, r)
		local tw2 = .5 + .5 * sin(G.t * 6 + ph * 5)
		local sz = G.w * (2.5 + 3.5 * tw2)
		local c = G.col(u, i * .3)
		local cf = CFrame.lookAt(pos, G.cam) * CFrame.Angles(0, 0, G.t * 2 + ph)
		G.blk(cf, V3(sz * 2.2, sz * .35, sz * .35), c, G.tr)
		G.blk(cf * CFrame.Angles(0, 0, pi / 2), V3(sz * 2.2, sz * .35, sz * .35), c, G.tr)
		G.ball(pos, sz * .7, WHITE:Lerp(c, .3), G.tr)
	end
end

----------------------------------------------------------------------
-- 3D tip
----------------------------------------------------------------------
local function drawTip(pos)
	local st = S.g3_tip
	if st == "None" then return end
	local t = G.t
	local c1, c2 = G.col(1, 0), G.col(.7, 2)
	local base = G.w * 5 * S.g3_tipsz * (1 + .1 * sin(t * 8))
	local tr = G.tr
	if st == "Gyro" then
		G.ball(pos, base * .8, WHITE:Lerp(c1, .4), tr)
		for ringI = 0, 2 do
			for k = 1, 6 do
				local a = t * (2.2 + ringI * .5) + k / 6 * TAU + ringI
				local lx, ly = cos(a) * base * 1.25, sin(a) * base * 1.25
				local off
				if ringI == 0 then off = G.right * lx + G.up * ly
				elseif ringI == 1 then off = G.right * lx + G.dir * ly
				else off = G.up * lx + G.dir * ly end
				G.ball(pos + off, base * .22, (ringI == 1) and c2 or c1, tr)
			end
		end
	elseif st == "Orb" then
		G.ball(pos, base, WHITE:Lerp(c1, .35), tr)
	elseif st == "Diamond" then
		local cf = CFrame.new(pos) * CFrame.Angles(t * 1.4, t * 2, pi / 4)
		G.blk(cf, V3(base, base * 1.7, base), c1, tr)
		G.blk(cf * CFrame.Angles(pi / 2, 0, 0), V3(base * .8, base * 1.4, base * .8), c2, tr + .15)
	elseif st == "Cube Spin" then
		local cf = CFrame.new(pos) * CFrame.Angles(t * 2, t * 1.5, 0)
		G.blk(cf, V3(base, base, base), c1, tr)
		G.blk(cf * CFrame.Angles(pi / 4, pi / 4, 0), V3(base * 1.35, base * 1.35, base * 1.35), c2, .6)
	end
	if S.g3_shell then G.ball(pos, base * 2.1, c1, .82) end
end

----------------------------------------------------------------------
-- main update : runs at the very end of the render step so it never lags behind the game's line
----------------------------------------------------------------------
local beamRef
local function findBeam(gp)
	if beamRef and beamRef.Parent and beamRef:IsDescendantOf(gp) and beamRef.Attachment0 and beamRef.Attachment1 then return beamRef end
	beamRef = nil
	for _, d in ipairs(gp:GetDescendants()) do
		if d:IsA("Beam") and d.Name ~= "SefGlow" and d.Attachment0 and d.Attachment1 then
			beamRef = d
			return d
		end
	end
end
local function update(dt)
	if not L.alive() then return end
	local fn = STY3[S.gv_style]
	if not (fn and (S.gv_on or S.g3_demo)) then
		if shown then hideAll() end
		return
	end
	local A, Bt
	local gp = workspace:FindFirstChild("GrabParts")
	local c = cam()
	if S.gv_on and gp then
		local beam = findBeam(gp)
		if beam then
			local a0, a1 = beam.Attachment0, beam.Attachment1
			local p0, p1 = a0.WorldPosition, a1.WorldPosition
			local tipIs1 = a1.Parent and a1.Parent:IsDescendantOf(gp)
			if tipIs1 then A, Bt = p0, p1 else A, Bt = p1, p0 end
		end
	end
	if not A and S.g3_demo and c then
		local cf, tk = c.CFrame, tick()
		A = cf.Position + cf.LookVector * 3 + cf.RightVector * -2.2 + cf.UpVector * -2
		Bt = cf.Position + cf.LookVector * (24 + 8 * sin(tk * .8)) + cf.RightVector * (2 + 3 * sin(tk * .5)) + cf.UpVector * (-1 + 2 * cos(tk * .7))
	end
	if not A then
		if shown then hideAll() end
		return
	end
	-- elastic tip : the far end follows on a spring so a hard pull / snap stretches and wobbles
	local tip = Bt
	local el = S.g3_elastic
	if el > .001 then
		if not spring.pos or (spring.pos - Bt).Magnitude > 250 then spring.pos = Bt spring.vel = V3() end
		local k = 260 - 190 * el
		local damp = 2 * sqrt(k) * (1 - .75 * el)
		local stp = min(dt, 1 / 30)
		local acc = (Bt - spring.pos) * k - spring.vel * damp
		spring.vel = spring.vel + acc * stp
		spring.pos = spring.pos + spring.vel * stp
		tip = spring.pos
	else
		spring.pos = nil
	end
	local d = tip - A
	local len = d.Magnitude
	if len < .3 then
		if shown then hideAll() end
		return
	end
	local dir = d / len
	local right = dir:Cross(V3(0, 1, 0))
	if right.Magnitude < .05 then right = dir:Cross(V3(1, 0, 0)) end
	right = right.Unit
	local up = right:Cross(dir)
	G.t = G.t + dt * S.gv_spd
	local q = clamp(floor(S.g3_q + .5), 1, 3)
	G.A, G.d, G.dir, G.len, G.right, G.up = A, d, dir, len, right, up
	G.cam = c and c.CFrame.Position or A
	G.qf = (q == 1 and .65) or (q == 2 and 1) or 1.45
	G.cap = (q == 1 and 90) or (q == 2 and 170) or 280
	G.dens, G.twist, G.taper = S.g3_dens, S.g3_twist, S.g3_taper
	G.amp = S.gv_amp * clamp(len / 18, .35, 1.2)
	G.thinF = clamp((14 / max(len, 1)) ^ S.g3_thin, .35, 1.6)
	G.w = S.gv_w * G.thinF
	G.tr = 1 - S.g3_op
	G.sag = S.g3_sag * len * .12
	MAT = MATS3[S.g3_mat] or Enum.Material.Neon
	beginFrame()
	local ok, e = pcall(fn)
	if not ok and S.ex_dbg then warn("[Sef 3D line] " .. tostring(e)) end
	pcall(drawTip, tip)
	if S.g3_origin then G.ball(A, G.w * 4, G.col(0, 0), G.tr) end
	endFrame()
	if not shown then folder.Parent = fxFolder shown = true end
	local c1 = G.col(1, 0)
	tipPart.CFrame = CFrame.new(tip)
	tipPE.Enabled = S.gv_tip
	tipPE.Color = ColorSequence.new(S.gv_c1, S.gv_c2)
	tipLight.Enabled = S.g3_light
	tipLight.Color = c1
end

local bindName = "SefG3D" .. U.Http:GenerateGUID(false)
RS:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, function(dt)
	local ok, e = pcall(update, dt)
	if not ok and S.ex_dbg then warn("[Sef 3D line] " .. tostring(e)) end
end)
L.cleanups[#L.cleanups + 1] = function()
	pcall(function() RS:UnbindFromRenderStep(bindName) end)
	pcall(function() folder:Destroy() end)
end
end)

-- module: 14_throwfx  (effects for toys / players you throw : flight styles, launch burst, impact)
MOD("14_throwfx", function()
local S, Ctl, L, T, SL, CO, DD, B, H, tab, PK = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.tab, U.PK
local new, tw, hsv, LP, cam, hud, fxFolder, Debris, RS = U.new, U.tw, U.hsv, U.LP, U.cam, U.hud, U.fxFolder, U.Debris, U.RS
local burst, ring, sphere = U.burst, U.ring, U.sphere
local sin, cos, floor, max, min, clamp, abs, sqrt, pi, rnd = math.sin, math.cos, math.floor, math.max, math.min, math.clamp, math.abs, math.sqrt, math.pi, math.random
local TAU = pi * 2
local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromRGB
local TEXS = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

local TSTY = {
	["Comet"] = { pal = { rgb(120, 220, 255), rgb(255, 255, 255) }, core = 1.5, light = true,
		trails = { { w = 1.6, life = 1 }, { w = .7, life = 1.6 } },
		emit = { { tex = TEXS, rate = 90, life = { .5, 1.1 }, speed = { 2, 9 }, size = { 1.1, 0 }, le = 1 } } },
	["Ribbon Weave"] = { pal = { rgb(255, 90, 200), rgb(110, 90, 255) },
		trails = { { w = 1, life = .8 } },
		orbit = { n = 3, r = 1.7, spd = 7, size = .5, trail = { w = .9, life = .9 } } },
	["Afterimage"] = { pal = { rgb(150, 255, 200), rgb(60, 180, 255) },
		trails = { { w = .8, life = .5 } }, ghost = { every = .035, life = .4 } },
	["Shock Rings"] = { pal = { rgb(255, 200, 80), rgb(255, 110, 40) }, core = 1,
		trails = { { w = .8, life = .5 } }, rings = { every = .1, size = 7, life = .5 } },
	["Lightning Crackle"] = { pal = { rgb(190, 225, 255), rgb(255, 255, 255) }, core = .9, light = true,
		arcs = { n = 4, len = 6 },
		emit = { { tex = TEXS, rate = 50, life = { .15, .35 }, speed = { 10, 20 }, size = { .7, 0 }, le = 1 } } },
	["Fire Streak"] = { pal = { rgb(255, 210, 60), rgb(255, 60, 0) }, core = 1.4, light = true,
		trails = { { w = 1.8, life = .7 } },
		emit = { { tex = FIRE, rate = 70, life = { .4, .9 }, speed = { 1, 5 }, size = { 3.2, 0 }, le = 1 },
			{ tex = SMOKE, rate = 25, life = { .9, 1.6 }, speed = { 1, 3 }, size = { 2.5, 5 }, le = 0, tr = { .5, 1 }, dark = true } } },
	["Ice Crystals"] = { pal = { rgb(170, 240, 255), rgb(240, 252, 255) },
		trails = { { w = 1.2, life = .8 } }, shards = { every = .07 },
		emit = { { tex = TEXS, rate = 40, life = { .8, 1.4 }, speed = { 1, 4 }, size = { .7, 0 }, le = 1 } } },
	["Star Burst"] = { pal = { rgb(255, 240, 150), rgb(255, 160, 60) },
		trails = { { w = 1, life = .7 } },
		orbit = { n = 3, r = 2, spd = 5, size = 1, star = true },
		emit = { { tex = TEXS, rate = 45, life = { .6, 1.2 }, speed = { 3, 10 }, size = { 1.6, 0 }, le = 1 } } },
	["Sonic Boom"] = { pal = { rgb(230, 245, 255), rgb(150, 200, 255) },
		trails = { { w = 1, life = .6 } }, cone = { n = 6, r = 4.5 }, rings = { every = .3, size = 11, life = .55 },
		emit = { { tex = SMOKE, rate = 30, life = { .6, 1.2 }, speed = { 1, 3 }, size = { 1.5, 4 }, le = 0, tr = { .55, 1 } } } },
	["Rainbow Streak"] = { pal = { rgb(255, 80, 80), rgb(80, 120, 255) }, rainbow = true,
		trails = { { w = 1.2, life = 1.1 }, { w = 1.2, life = 1.1, off = 1.1 }, { w = 1.2, life = 1.1, off = -1.1 } },
		emit = { { tex = TEXS, rate = 60, life = { .6, 1.2 }, speed = { 2, 8 }, size = { 1, 0 }, le = 1, rainbow = true } } },
	["Void Rip"] = { pal = { rgb(150, 50, 255), rgb(30, 0, 60) }, core = 1.6, coreDark = true,
		orbit = { n = 3, r = 2.2, spd = 4.5, size = .7, trail = { w = .9, life = .8 } },
		rings = { every = .22, size = 6, life = .6 },
		emit = { { tex = SMOKE, rate = 40, life = { 1, 1.8 }, speed = { 1, 4 }, size = { 2, 5 }, le = 0, tr = { .4, 1 }, dark = true } } },
	["Plasma Spin"] = { pal = { rgb(255, 80, 220), rgb(80, 255, 240) }, core = 1.1,
		trails = { { w = .6, life = .5 } },
		orbit = { n = 4, r = 1.6, spd = 9, size = .6, trail = { w = .6, life = .55 }, double = true } },
}
local THN = { "Comet", "Ribbon Weave", "Afterimage", "Shock Rings", "Lightning Crackle", "Fire Streak", "Ice Crystals", "Star Burst", "Sonic Boom", "Rainbow Streak", "Void Rip", "Plasma Spin" }

----------------------------------------------------------------------
-- controls
----------------------------------------------------------------------
L.tabs["Throw FX"] = tab("Throw FX", 11)
H("Throw Effects (your own throws, local only)")
T("Throw Effects", "th_on", false)
PK("Flight Effect", "th_style", THN, "Comet")
PK("Launch Burst", "th_launch", { "None", "Pop", "Shockwave Ring", "Sonic Cone", "Star Burst", "Lightning Crown" }, "Shockwave Ring")
PK("Impact Effect", "th_impact", { "None", "Shatter", "Shockwave", "Star Pop", "Dust Puff", "Lightning Strike", "Nova" }, "Shatter")
H("Colors")
DD("Color Source", "th_cmode", { "Style Default", "Grab Line Colors", "Custom", "Rainbow", "By Speed" }, "Style Default")
CO("Custom Color 1", "th_c1", rgb(0, 230, 255))
CO("Custom Color 2", "th_c2", rgb(170, 90, 255))
H("Tuning")
SL("Min Throw Speed", "th_min", 8, 200, 30, 0)
SL("Effect Size", "th_sz", .4, 3, 1, 2)
SL("Intensity (particles)", "th_int", .3, 2.5, 1, 2)
SL("Trail Width", "th_trw", .2, 4, 1, 2)
SL("Trail Length", "th_life", .2, 3, 1, 2)
SL("Max Effect Time (s)", "th_dur", 1, 12, 5, 1)
SL("Impact Sensitivity (speed drop)", "th_impth", 15, 150, 40, 0)
H("Feedback")
SL("Throw Camera Shake", "th_shk", 0, 1.5, .2, 2)
SL("Impact Camera Shake", "th_ishk", 0, 2, .5, 2)
SL("Throw FOV Kick", "th_kick", 0, 30, 6, 0)
T("Speed Popup Text", "th_pop", true)
T("Hold Charge Rings (while grabbing)", "th_hold", false)
T("Also When Throwing Players", "th_players", true)
H("Tools")
B("Test Throw Effect", function() L.testThrow() end)
B("Reset Best Throw", function() L.thBest = 0 end)

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function palette(sp, t, speed)
	local m = S.th_cmode
	if m == "Custom" then return S.th_c1, S.th_c2 end
	if m == "Grab Line Colors" then return S.gv_c1, S.gv_c2 end
	if m == "Rainbow" or sp.rainbow then
		local h = (t * .45) % 1
		return hsv(h), hsv(h + .18)
	end
	if m == "By Speed" then
		local f = clamp(speed / 180, 0, 1)
		local h = .62 - .62 * f
		return hsv(h), hsv(h + .08)
	end
	return sp.pal[1], sp.pal[2]
end
local function mkFollower()
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
	p.Transparency = 1 p.Size = V3(.4, .4, .4)
	p.Parent = fxFolder
	return p
end
local function mkNeon(shape, size)
	local p = Instance.new("Part")
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
	p.Shape = shape p.Material = Enum.Material.Neon p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = fxFolder
	return p
end
local function addTrail(host, w, life, offX)
	local a0 = Instance.new("Attachment")
	a0.Position = V3(offX or 0, w / 2, 0)
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.Position = V3(offX or 0, -w / 2, 0)
	a1.Parent = host
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0 tr.Attachment1 = a1 tr.Lifetime = life tr.LightEmission = 1 tr.LightInfluence = 0
	tr.FaceCamera = true tr.MinLength = .05
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .05), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	tr.Parent = host
	return tr
end
local function addEmitter(host, e)
	local pe = Instance.new("ParticleEmitter")
	local sz = S.th_sz
	local t = e.tr or { 0, 1 }
	pe.Texture = e.tex
	pe.Rate = e.rate * S.th_int
	pe.Lifetime = NumberRange.new(e.life[1], e.life[2])
	pe.Speed = NumberRange.new(e.speed[1], e.speed[2])
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, e.size[1] * sz), NumberSequenceKeypoint.new(1, e.size[2] * sz) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t[1]), NumberSequenceKeypoint.new(1, t[2]) })
	pe.LightEmission = e.le or 0
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-80, 80)
	pe.Parent = host
	return pe
end
-- ring that faces a direction (cylinder axis along dir)
local function ringDir(pos, dir, col, size, life, startSize)
	local p = mkNeon(CYL, V3(.25, startSize or 1, startSize or 1))
	p.Color = col
	p.Transparency = .1
	p.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, pi / 2, 0)
	tw(p, life, { Size = V3(.25, size, size), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(p, life + .2)
end
local function bolt(a, b, col, th, life, segs, jit)
	local prev = a
	for i = 1, segs do
		local nxt = (i == segs) and b or (a + (b - a) * (i / segs) + V3(rnd() - .5, rnd() - .5, rnd() - .5) * jit)
		local d = nxt - prev
		if d.Magnitude > .05 then
			local p = mkNeon(BLOCK, V3(th, th, d.Magnitude))
			p.Color = col
			p.CFrame = CFrame.lookAt((prev + nxt) / 2, nxt)
			tw(p, life, { Transparency = 1, Size = V3(th * .2, th * .2, d.Magnitude) }, Enum.EasingStyle.Quad)
			Debris:AddItem(p, life + .1)
		end
		prev = nxt
	end
end
local function shardBurst(pos, c1, c2, n, dist, life, sz0)
	for i = 1, n do
		local dv = V3(rnd() - .5, rnd() * .9 + .1, rnd() - .5).Unit
		local sz = (.5 + rnd()) * sz0
		local p = mkNeon(BLOCK, V3(sz, sz, sz))
		p.Color = (i % 2 == 0) and c1 or c2
		p.CFrame = CFrame.new(pos)
		tw(p, life, { CFrame = CFrame.new(pos + dv * (dist * (.4 + rnd() * .6))) * CFrame.Angles(rnd() * 6, rnd() * 6, rnd() * 6), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, life + .1)
	end
end

----------------------------------------------------------------------
-- launch + impact one-shots
----------------------------------------------------------------------
local function launchFx(pos, dir, speed, c1, c2)
	local k, sz = S.th_launch, S.th_sz
	if k == "None" then return end
	if k == "Pop" then
		sphere(pos, c1, sz, 7 * sz, .35)
		burst(pos, c2, floor(24 * S.th_int), 16 * sz, .6, .5 * sz)
	elseif k == "Shockwave Ring" then
		for i = 1, 3 do
			task.delay(i * .06, function() if L.alive() then ringDir(pos, dir, i % 2 == 0 and c2 or c1, (10 + i * 5) * sz, .5) end end)
		end
		burst(pos, c1, floor(20 * S.th_int), 18 * sz, .5, .45 * sz)
	elseif k == "Sonic Cone" then
		for i = 1, 6 do
			task.delay(i * .035, function()
				if L.alive() then ringDir(pos + dir * (i * 1.4 * sz), dir, c1:Lerp(c2, i / 6), (5 + i * 3.2) * sz, .5, 1) end
			end)
		end
		sphere(pos, c2, sz, 9 * sz, .3)
	elseif k == "Star Burst" then
		for i = 1, 10 do
			local a = i / 10 * TAU
			local dv = V3(cos(a), sin(a), 0)
			local fr = CFrame.lookAt(pos, pos + dir)
			local wd = fr:VectorToWorldSpace(dv)
			local p = mkNeon(BLOCK, V3(.25 * sz, .25 * sz, 2.4 * sz))
			p.Color = (i % 2 == 0) and c1 or c2
			p.CFrame = CFrame.lookAt(pos, pos + wd)
			tw(p, .45, { CFrame = CFrame.lookAt(pos + wd * 9 * sz, pos + wd * 10 * sz), Transparency = 1 }, Enum.EasingStyle.Quad)
			Debris:AddItem(p, .6)
		end
		burst(pos, c1, floor(30 * S.th_int), 20 * sz, .6, .7 * sz)
	elseif k == "Lightning Crown" then
		local fr = CFrame.lookAt(pos, pos + dir)
		for i = 1, 8 do
			local a = i / 8 * TAU
			local wd = fr:VectorToWorldSpace(V3(cos(a), sin(a), .3))
			bolt(pos, pos + wd * 9 * sz, (i % 2 == 0) and c1 or c2, .22 * sz, .3, 4, 2.5 * sz)
		end
		sphere(pos, WHITE, sz, 6 * sz, .25)
	end
end
local function impactFx(pos, speed, c1, c2)
	local k, sz = S.th_impact, S.th_sz
	if S.th_ishk > 0 then pcall(L.addShake, S.th_ishk * clamp(speed / 150, .2, 1)) end
	if k == "None" then return end
	if k == "Shatter" then
		shardBurst(pos, c1, c2, 18, 18 * sz, .9, .8 * sz)
		ring(pos, c1, 22 * sz, .5, 0)
		burst(pos, c2, floor(25 * S.th_int), 22 * sz, .6, .5 * sz)
	elseif k == "Shockwave" then
		ring(pos, c1, 34 * sz, .6, 0)
		task.delay(.08, function() if L.alive() then ring(pos, c2, 24 * sz, .5, 0) end end)
		sphere(pos, c2, 1.5 * sz, 12 * sz, .3)
		burst(pos, WHITE, floor(18 * S.th_int), 16 * sz, .7, 1.4 * sz, SMOKE, V3(0, 2, 0))
	elseif k == "Star Pop" then
		sphere(pos, c1, sz, 8 * sz, .3)
		burst(pos, c1, floor(45 * S.th_int), 30 * sz, .8, 1.1 * sz)
		shardBurst(pos, c1, c2, 8, 12 * sz, .6, .6 * sz)
	elseif k == "Dust Puff" then
		burst(pos, rgb(200, 190, 170), floor(30 * S.th_int), 14 * sz, 1.1, 2.2 * sz, SMOKE, V3(0, 2, 0))
		ring(pos, rgb(210, 200, 180), 16 * sz, .5, 0)
	elseif k == "Lightning Strike" then
		bolt(pos + V3(rnd() * 3, 70, rnd() * 3), pos, c1, .6 * sz, .35, 9, 5)
		bolt(pos + V3(rnd() * 3, 70, rnd() * 3), pos, WHITE, .25 * sz, .25, 9, 4)
		sphere(pos, WHITE, sz, 10 * sz, .25)
		ring(pos, c2, 20 * sz, .5, 0)
	elseif k == "Nova" then
		sphere(pos, WHITE, sz, 14 * sz, .35)
		local rots = { CFrame.Angles(0, 0, pi / 2), CFrame.Angles(0, 0, 0), CFrame.Angles(0, pi / 2, 0) }
		for i = 1, 3 do
			local p = mkNeon(CYL, V3(.3, 2, 2))
			p.Color = (i == 2) and c2 or c1
			p.CFrame = CFrame.new(pos) * rots[i]
			tw(p, .7, { Size = V3(.3, 34 * sz, 34 * sz), Transparency = 1 }, Enum.EasingStyle.Quad)
			Debris:AddItem(p, .9)
		end
		burst(pos, c1, floor(40 * S.th_int), 34 * sz, .8, sz)
	end
end

----------------------------------------------------------------------
-- flight instances
----------------------------------------------------------------------
local insts = {}
local function newInst(style, part, vel, pos, test)
	local sp = TSTY[style] or TSTY["Comet"]
	local inst = { sp = sp, part = part, test = test, pos = pos, vel = vel, age = 0, slowT = 0, prev = vel.Magnitude, cd = 0,
		acc = {}, orb = {}, trails = {}, emits = {}, arcP = {}, arcRel = {}, coneP = {}, last = V3(0, 0, -1) }
	inst.f = mkFollower()
	for _, tsp in ipairs(sp.trails or {}) do
		local tr = addTrail(inst.f, tsp.w * S.th_trw * S.th_sz, tsp.life * S.th_life, (tsp.off or 0) * S.th_sz)
		inst.trails[#inst.trails + 1] = tr
	end
	for _, e in ipairs(sp.emit or {}) do
		inst.emits[#inst.emits + 1] = { pe = addEmitter(inst.f, e), spec = e, base = e.rate * S.th_int }
	end
	if sp.core then
		inst.core = mkNeon(BALL, V3(1, 1, 1))
		inst.shell = mkNeon(BALL, V3(1, 1, 1))
		inst.shell.Transparency = .75
	end
	if sp.light then
		local l = Instance.new("PointLight")
		l.Range = 16 l.Brightness = 2 l.Shadows = false
		l.Parent = inst.f
		inst.light = l
	end
	if sp.orbit then
		for i = 1, sp.orbit.n do
			local o = mkNeon(sp.orbit.star and BLOCK or BALL, V3(.5, .5, .5))
			local e = { p = o }
			if sp.orbit.trail then
				e.tr = addTrail(o, sp.orbit.trail.w * S.th_trw * S.th_sz * .6, sp.orbit.trail.life * S.th_life, 0)
			end
			inst.orb[i] = e
		end
	end
	if sp.arcs then
		for i = 1, sp.arcs.n * 4 do inst.arcP[i] = mkNeon(BLOCK, V3(.1, .1, .5)) end
	end
	if sp.cone then
		for i = 1, sp.cone.n do
			local p = mkNeon(CYL, V3(.15, 2, 2))
			p.Transparency = 1
			inst.coneP[i] = p
		end
	end
	return inst
end
local function killInst(inst)
	for _, e in ipairs(inst.emits) do pcall(function() e.pe.Enabled = false end) end
	for _, e in ipairs(inst.orb) do
		pcall(function()
			if e.tr then e.tr.Enabled = false end
			e.p.Transparency = 1
			Debris:AddItem(e.p, 2)
		end)
	end
	for _, k in ipairs({ "core", "shell" }) do
		if inst[k] then pcall(function() inst[k]:Destroy() end) end
	end
	for _, p in ipairs(inst.arcP) do pcall(function() p:Destroy() end) end
	for _, p in ipairs(inst.coneP) do pcall(function() p:Destroy() end) end
	for _, tr in ipairs(inst.trails) do pcall(function() tr.Enabled = false end) end
	if inst.light then pcall(function() inst.light.Enabled = false end) end
	Debris:AddItem(inst.f, 2.6)
end
local function killAll()
	for i = #insts, 1, -1 do
		killInst(insts[i])
		table.remove(insts, i)
	end
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function stepInst(inst, dt, t)
	local sp = inst.sp
	if inst.test then
		local prevPos = inst.pos
		inst.vel = inst.vel + V3(0, -workspace.Gravity * .35 * dt, 0)
		inst.pos = prevPos + inst.vel * dt
		rp.FilterDescendantsInstances = { LP.Character, fxFolder }
		local hit = workspace:Raycast(prevPos, inst.pos - prevPos, rp)
		if hit then
			local c1, c2 = palette(sp, t, inst.vel.Magnitude)
			impactFx(hit.Position, inst.vel.Magnitude, c1, c2)
			return false
		end
	else
		local p = inst.part
		if not p or not p.Parent then return false end
		inst.pos = p.Position
		inst.vel = p.AssemblyLinearVelocity
	end
	local speed = inst.vel.Magnitude
	inst.age = inst.age + dt
	inst.cd = max(0, inst.cd - dt)
	local dirV = (speed > 1) and (inst.vel / speed) or inst.last
	inst.last = dirV
	local c1, c2 = palette(sp, t, speed)
	local sz = S.th_sz
	local pos = inst.pos
	inst.f.CFrame = CFrame.lookAt(pos, pos + dirV)
	local cs = ColorSequence.new(c1, c2)
	for _, tr in ipairs(inst.trails) do tr.Color = cs end
	local sf = clamp(speed / 60, .3, 1.5)
	for _, e in ipairs(inst.emits) do
		e.pe.Rate = e.base * sf
		e.pe.Color = e.spec.rainbow and U.RAINBOWSEQ or ColorSequence.new(e.spec.dark and c2 or c1, c2)
	end
	if inst.core then
		local cz = sp.core * sz * (1 + .1 * sin(t * 12))
		inst.core.Size = V3(cz, cz, cz)
		inst.core.CFrame = CFrame.new(pos)
		inst.core.Color = sp.coreDark and Color3.new(0, 0, 0) or WHITE:Lerp(c1, .35)
		inst.shell.Size = V3(cz * 2.1, cz * 2.1, cz * 2.1)
		inst.shell.CFrame = CFrame.new(pos)
		inst.shell.Color = c1
	end
	if inst.light then
		inst.light.Color = c1
		inst.light.Range = 14 * sz
	end
	if sp.orbit then
		local o = sp.orbit
		local up0 = (abs(dirV.Y) > .95) and V3(1, 0, 0) or V3(0, 1, 0)
		local rgt = dirV:Cross(up0).Unit
		local upv = rgt:Cross(dirV)
		for i, e in ipairs(inst.orb) do
			local alt = o.double and (i % 2 == 0)
			local sgn = alt and -1 or 1
			local rad = o.r * sz * (alt and .6 or 1)
			local a = t * o.spd * sgn + i / #inst.orb * TAU
			local op = pos + rgt * (cos(a) * rad) + upv * (sin(a) * rad)
			local s2 = o.size * sz
			if o.star then
				e.p.Size = V3(s2 * 1.3, s2 * 1.3, s2 * 1.3)
				e.p.CFrame = CFrame.new(op) * CFrame.Angles(t * 3 + i, t * 2, pi / 4)
			else
				e.p.Size = V3(s2, s2, s2)
				e.p.CFrame = CFrame.new(op)
			end
			e.p.Color = (i % 2 == 0) and c2 or c1
			if e.tr then e.tr.Color = ColorSequence.new(e.p.Color, c2) end
		end
	end
	if sp.rings and speed > 12 then
		inst.acc.ring = (inst.acc.ring or 0) + dt
		if inst.acc.ring >= sp.rings.every then
			inst.acc.ring = 0
			ringDir(pos, dirV, c1, sp.rings.size * sz, sp.rings.life, 1)
		end
	end
	if sp.ghost and inst.part then
		inst.acc.gh = (inst.acc.gh or 0) + dt
		if inst.acc.gh >= sp.ghost.every then
			inst.acc.gh = 0
			local g = mkNeon(BLOCK, inst.part.Size)
			g.Color = c1
			g.Transparency = .4
			g.CFrame = inst.part.CFrame
			tw(g, sp.ghost.life, { Transparency = 1, Color = c2 }, Enum.EasingStyle.Quad)
			Debris:AddItem(g, sp.ghost.life + .1)
		end
	end
	if sp.shards then
		inst.acc.sh = (inst.acc.sh or 0) + dt
		if inst.acc.sh >= sp.shards.every then
			inst.acc.sh = 0
			local s3 = (.5 + rnd() * .6) * sz
			local g = mkNeon(BLOCK, V3(s3, s3 * 1.9, s3))
			local base = pos + V3(rnd() - .5, rnd() - .5, rnd() - .5) * 2.4 * sz
			g.Color = (rnd() < .5) and c1 or c2
			g.Material = Enum.Material.Glass
			g.Transparency = .1
			g.CFrame = CFrame.new(base) * CFrame.Angles(rnd() * 6, rnd() * 6, rnd() * 6)
			tw(g, .9, { CFrame = CFrame.new(base + V3(0, -6, 0)) * CFrame.Angles(rnd() * 6, rnd() * 6, rnd() * 6), Transparency = 1 }, Enum.EasingStyle.Quad)
			Debris:AddItem(g, 1)
		end
	end
	if sp.arcs then
		inst.acc.arc = (inst.acc.arc or 0) + dt
		if inst.acc.arc >= .05 then
			inst.acc.arc = 0
			local idx = 0
			for _ = 1, sp.arcs.n do
				local d0 = V3(rnd() - .5, rnd() - .5, rnd() - .5).Unit
				local a = V3()
				for _ = 1, 4 do
					local b = a + (d0 + V3(rnd() - .5, rnd() - .5, rnd() - .5) * 1.1).Unit * (sp.arcs.len * sz / 4)
					idx = idx + 1
					inst.arcRel[idx] = { a, b }
					a = b
				end
			end
		end
		for i, p in ipairs(inst.arcP) do
			local r = inst.arcRel[i]
			if r then
				local a, b = pos + r[1], pos + r[2]
				local d = b - a
				p.Size = V3(.14 * sz, .14 * sz, max(.05, d.Magnitude))
				p.CFrame = CFrame.lookAt((a + b) / 2, b)
				p.Color = (i % 2 == 0) and c1 or c2
			end
		end
	end
	if sp.cone then
		local on = speed > 25
		for i, p in ipairs(inst.coneP) do
			if on then
				local f = i / sp.cone.n
				local back = pos - dirV * (i * .9 * sz)
				local dia = sp.cone.r * sz * 2 * (f ^ .85)
				p.Size = V3(.15, dia, dia)
				p.CFrame = CFrame.lookAt(back, back + dirV) * CFrame.Angles(0, pi / 2, 0)
				p.Transparency = .55 + .4 * f
				p.Color = c1:Lerp(c2, f)
			else
				p.Transparency = 1
			end
		end
	end
	-- impact : sudden speed drop
	if inst.age > .12 and inst.cd <= 0 and inst.prev - speed > S.th_impth and not inst.test then
		inst.cd = .3
		impactFx(pos, inst.prev, c1, c2)
	end
	inst.prev = speed
	if speed < 8 then inst.slowT = inst.slowT + dt else inst.slowT = 0 end
	if inst.age > S.th_dur or (inst.age > .5 and inst.slowT > .35) then return false end
	return true
end

----------------------------------------------------------------------
-- popup + throw detection
----------------------------------------------------------------------
L.thBest = 0
local popup = new("TextLabel", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .34), Size = UDim2.fromOffset(500, 60), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 34, TextStrokeTransparency = .2, TextColor3 = WHITE, Visible = false, ZIndex = 8, Text = "" }, hud)
local popTok = 0
local function showPopup(speed, col)
	if not S.th_pop then return end
	local txt = "THROW  " .. floor(speed)
	if speed > L.thBest then
		if L.thBest > 0 then txt = txt .. "  NEW BEST" end
		L.thBest = speed
	end
	popTok = popTok + 1
	local my = popTok
	popup.Text = txt
	popup.TextColor3 = col
	popup.TextTransparency = 0
	popup.TextStrokeTransparency = .2
	popup.Position = UDim2.fromScale(.5, .34)
	popup.Visible = true
	tw(popup, 1.1, { Position = UDim2.fromScale(.5, .27), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(1.15, function() if my == popTok then popup.Visible = false end end)
end

local function inMyChar(p)
	local ch = LP.Character
	return ch ~= nil and p:IsDescendantOf(ch)
end
local function targetOf(gp)
	local best
	local function try(p)
		if best or typeof(p) ~= "Instance" or not p:IsA("BasePart") or p:IsDescendantOf(gp) or inMyChar(p) then return end
		best = p
	end
	for _, d in ipairs(gp:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			try(d.Part0) try(d.Part1)
		elseif d:IsA("Constraint") or d:IsA("Beam") then
			try(d.Attachment0 and d.Attachment0.Parent)
			try(d.Attachment1 and d.Attachment1.Parent)
		end
		if best then break end
	end
	return best
end
local function isPlayerPart(p)
	local m = p:FindFirstAncestorOfClass("Model")
	return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function onRelease(part, pre)
	if not (L.alive() and S.th_on) or not part or not part.Parent then return end
	if not S.th_players and isPlayerPart(part) then return end
	local nowV = part.AssemblyLinearVelocity
	local v = (nowV.Magnitude >= pre.Magnitude) and nowV or pre
	local speed = v.Magnitude
	if speed < S.th_min then return end
	local t = tick()
	local sp = TSTY[S.th_style] or TSTY["Comet"]
	local c1, c2 = palette(sp, t, speed)
	launchFx(part.Position, v.Unit, speed, c1, c2)
	if #insts >= 4 then
		killInst(insts[1])
		table.remove(insts, 1)
	end
	insts[#insts + 1] = newInst(S.th_style, part, v, part.Position, false)
	if S.th_shk > 0 then pcall(L.addShake, S.th_shk * clamp(speed / 120, .3, 1)) end
	if S.th_kick > 0 then L.kick = max(L.kick or 0, S.th_kick * clamp(speed / 150, .3, 1)) end
	showPopup(speed, c1)
end
function L.testThrow()
	local c = cam()
	if not c then return end
	local cf = c.CFrame
	local pos = cf.Position + cf.LookVector * 5 - cf.UpVector * 1.2
	local vel = cf.LookVector * 110 + V3(0, 26, 0)
	local sp = TSTY[S.th_style] or TSTY["Comet"]
	local c1, c2 = palette(sp, tick(), 110)
	launchFx(pos, vel.Unit, 110, c1, c2)
	if #insts >= 4 then
		killInst(insts[1])
		table.remove(insts, 1)
	end
	insts[#insts + 1] = newInst(S.th_style, nil, vel, pos, true)
	showPopup(110, c1)
end

-- hold charge rings
local holdP = {}
local hold = { part = nil, t = 0, chk = 0 }
local function holdOff()
	for _, p in ipairs(holdP) do pcall(function() p:Destroy() end) end
	holdP = {}
end
local function holdStep(dt, t)
	local part = hold.part
	if not (S.th_on and S.th_hold and part and part.Parent) then
		if #holdP > 0 then holdOff() end
		return
	end
	if #holdP == 0 then
		for i = 1, 7 do holdP[i] = mkNeon(i == 7 and BALL or BALL, V3(.5, .5, .5)) end
		holdP[7].Transparency = .8
	end
	hold.t = hold.t + dt
	local sp = TSTY[S.th_style] or TSTY["Comet"]
	local c1, c2 = palette(sp, t, part.AssemblyLinearVelocity.Magnitude)
	local sz = part.Size
	local rad = max(sz.X, sz.Y, sz.Z) * .75 + .8
	local spd = 2 + min(hold.t, 4) * 2
	for i = 1, 6 do
		local a = t * spd + i / 6 * TAU
		local p = holdP[i]
		p.Size = V3(.45, .45, .45)
		p.CFrame = CFrame.new(part.Position + V3(cos(a) * rad, sin(a * 1.3) * rad * .35, sin(a) * rad))
		p.Color = (i % 2 == 0) and c1 or c2
	end
	holdP[7].Size = V3(rad * 2, rad * 2, rad * 2)
	holdP[7].CFrame = CFrame.new(part.Position)
	holdP[7].Color = c1
end

local function update(dt)
	if not L.alive() then return end
	local t = tick()
	local gp = workspace:FindFirstChild("GrabParts")
	if S.th_on then
		if gp then
			hold.chk = hold.chk - dt
			if hold.chk <= 0 or not (hold.part and hold.part.Parent) then
				hold.chk = .15
				local np = targetOf(gp)
				if np ~= hold.part then hold.t = 0 end
				hold.part = np
			end
		elseif hold.part then
			local part = hold.part
			hold.part = nil
			local pre = part.Parent and part.AssemblyLinearVelocity or V3()
			task.delay(.05, function() onRelease(part, pre) end)
		end
	else
		hold.part = nil
		if #insts > 0 then killAll() end
	end
	holdStep(dt, t)
	for i = #insts, 1, -1 do
		local ok, alive = pcall(stepInst, insts[i], dt, t)
		if not ok and S.ex_dbg then warn("[Sef throw] " .. tostring(alive)) end
		if not ok or not alive then
			killInst(insts[i])
			table.remove(insts, i)
		end
	end
end
local bindName = "SefThrow" .. U.Http:GenerateGUID(false)
RS:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, function(dt)
	local ok, e = pcall(update, dt)
	if not ok and S.ex_dbg then warn("[Sef throw] " .. tostring(e)) end
end)
L.cleanups[#L.cleanups + 1] = function()
	pcall(function() RS:UnbindFromRenderStep(bindName) end)
	pcall(killAll)
	pcall(holdOff)
	pcall(function() popup:Destroy() end)
end
end)

-- module: 15_extras  (more 3D explosions, 3D fling extras, maintenance buttons)
MOD("15_extras", function()
local S, Ctl, L, T, SL, CO, DD, B, H, use, PK = U.S, U.Ctl, U.L, U.T, U.SL, U.CO, U.DD, U.B, U.H, U.usePage, U.PK
local new, tw, hsv, LP, cam, fxFolder, Debris, RS = U.new, U.tw, U.hsv, U.LP, U.cam, U.fxFolder, U.Debris, U.RS
local mk, burst, sphere, ring = U.mk, U.burst, U.sphere, U.ring
local sin, cos, floor, max, min, clamp, abs, pi, rnd = math.sin, math.cos, math.floor, math.max, math.min, math.clamp, math.abs, math.pi, math.random
local TAU = pi * 2
local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromRGB
local EX, EXC, EXN = L.EX, L.EXC, L.EXN
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

----------------------------------------------------------------------
-- 6 new 3D explosion styles
----------------------------------------------------------------------
EX["Crystal Burst"] = function(pos, s, c1, c2, d)
	sphere(pos, c2, s, 9 * s, d * .3)
	ring(pos, c1, 26 * s, d * .6, 0)
	for i = 1, 22 do
		local a = i / 22 * TAU
		local dv = V3(cos(a), .25 + rnd() * .9, sin(a)).Unit
		local len = (7 + rnd() * 10) * s
		local p = mk(BLOCK, pos, V3(.7 * s, .7 * s, len), (i % 2 == 0) and c1 or c2, Enum.Material.Glass)
		p.Transparency = .1
		p.CFrame = CFrame.lookAt(pos + dv, pos + dv * 2)
		local dist = (6 + rnd() * 10) * s
		tw(p, d * .8, { CFrame = CFrame.lookAt(pos + dv * dist, pos + dv * (dist + 1)), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, d)
	end
	burst(pos, c2, 40, 30 * s, d, .8 * s)
end
EX["Mushroom Cloud"] = function(pos, s, c1, c2, d)
	local stem = mk(CYL, pos, V3(1, 3 * s, 3 * s), c1)
	stem.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, pi / 2)
	tw(stem, d * .7, { Size = V3(22 * s, 5 * s, 5 * s), CFrame = CFrame.new(pos + V3(0, 11 * s, 0)) * CFrame.Angles(0, 0, pi / 2), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(stem, d)
	for i = 1, 3 do
		local cp = mk(BALL, pos, V3(2, 2, 2) * s, (i == 1) and c2 or c1)
		cp.Transparency = .1
		local h = (14 + i * 2.5) * s
		tw(cp, d * .9, { Size = V3(1, 1, 1) * (20 - i * 3.5) * s, CFrame = CFrame.new(pos + V3(0, h, 0)), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(cp, d)
	end
	ring(pos, c1, 50 * s, d * .7, 0)
	burst(pos + V3(0, 8 * s, 0), c2, 40, 22 * s, d, 3 * s, "rbxasset://textures/particles/smoke_main.dds")
end
EX["Vortex Tornado"] = function(pos, s, c1, c2, d)
	local parts = {}
	for i = 1, 28 do parts[i] = mk(BALL, pos, V3(1, 1, 1) * s * (.6 + (i % 3) * .3), (i % 2 == 0) and c1 or c2) end
	task.spawn(function()
		local t0, life = tick(), d * 1.2
		while L.alive() do
			local e = tick() - t0
			if e >= life then break end
			local f = e / life
			for i, p in ipairs(parts) do
				local u = i / #parts
				local h = ((u + e * .6) % 1) * 22 * s
				local r = (2 + h * .35) * (1 - f * .6)
				local a = e * 7 + u * TAU * 3
				p.Position = pos + V3(cos(a) * r, h, sin(a) * r)
				p.Transparency = clamp(f * 1.1 - .05 + (h / (22 * s)) * .3, 0, 1)
			end
			RS.Heartbeat:Wait()
		end
		for _, p in ipairs(parts) do p:Destroy() end
	end)
	ring(pos, c1, 24 * s, d * .6, 0)
	burst(pos, c2, 30, 25 * s, d, s)
end
EX["Light Pillar"] = function(pos, s, c1, c2, d)
	local h = 90 * s
	local col = mk(CYL, pos, V3(h, 2 * s, 2 * s), c2)
	col.CFrame = CFrame.new(pos + V3(0, h / 2, 0)) * CFrame.Angles(0, 0, pi / 2)
	col.Transparency = .2
	tw(col, d, { Size = V3(h, .2, .2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(col, d + .2)
	local glow = mk(CYL, pos, V3(h, 6 * s, 6 * s), c1)
	glow.CFrame = CFrame.new(pos + V3(0, h / 2, 0)) * CFrame.Angles(0, 0, pi / 2)
	glow.Transparency = .65
	tw(glow, d, { Size = V3(h, .3, .3), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(glow, d + .2)
	for i = 1, 5 do
		task.delay(i * .08, function() if L.alive() then ring(pos + V3(0, i * 4 * s, 0), c1, 28 * s, d * .5, 0) end end)
	end
	burst(pos, c2, 40, 30 * s, d, s)
end
EX["Gyro Nova"] = function(pos, s, c1, c2, d)
	sphere(pos, WHITE, 2 * s, 20 * s, d * .4)
	local rots = { CFrame.Angles(0, 0, pi / 2), CFrame.Angles(0, 0, 0), CFrame.Angles(0, pi / 2, 0) }
	for i = 1, 3 do
		local r = mk(CYL, pos, V3(.4 * s, 2, 2), (i == 2) and c2 or c1)
		r.CFrame = CFrame.new(pos) * rots[i]
		tw(r, d * .8, { Size = V3(.4 * s, 42 * s, 42 * s), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(r, d)
	end
	burst(pos, c1, 60, 45 * s, d, 1.3 * s)
end
EX["Shard Storm"] = function(pos, s, c1, c2, d)
	local list = {}
	for i = 1, 36 do
		local dv = V3(rnd() - .5, rnd() * .9 + .35, rnd() - .5).Unit
		local sz = (.4 + rnd() * .9) * s
		list[i] = { p = mk(BLOCK, pos, V3(sz, sz * 2.2, sz), (i % 2 == 0) and c1 or c2), v = dv * (18 + rnd() * 30) * s, r = V3(rnd() * 8, rnd() * 8, rnd() * 8) }
	end
	sphere(pos, c2, s, 10 * s, d * .3)
	task.spawn(function()
		local t0, life = tick(), d * 1.3
		while L.alive() do
			local e = tick() - t0
			if e > life then break end
			for _, it in ipairs(list) do
				it.p.CFrame = CFrame.new(pos + it.v * e + V3(0, -28 * e * e, 0)) * CFrame.Angles(it.r.X * e, it.r.Y * e, it.r.Z * e)
				it.p.Transparency = clamp((e / life - .55) * 2.2, 0, 1)
			end
			RS.Heartbeat:Wait()
		end
		for _, it in ipairs(list) do it.p:Destroy() end
	end)
	burst(pos, c1, 30, 30 * s, d, s)
end
local NEWX = {
	["Crystal Burst"] = { rgb(160, 235, 255), rgb(255, 255, 255) },
	["Mushroom Cloud"] = { rgb(255, 140, 40), rgb(110, 80, 70) },
	["Vortex Tornado"] = { rgb(120, 200, 255), rgb(255, 255, 255) },
	["Light Pillar"] = { rgb(255, 235, 150), rgb(255, 255, 255) },
	["Gyro Nova"] = { rgb(255, 90, 220), rgb(90, 240, 255) },
	["Shard Storm"] = { rgb(255, 170, 60), rgb(255, 80, 40) },
}
for _, n in ipairs({ "Crystal Burst", "Mushroom Cloud", "Vortex Tornado", "Light Pillar", "Gyro Nova", "Shard Storm" }) do
	EXC[n] = NEWX[n]
	EXN[#EXN + 1] = n
end
if Ctl.ex_style and Ctl.ex_style.refresh then Ctl.ex_style.refresh() end

----------------------------------------------------------------------
-- Fling FX : 3D speed streaks + 3D impact shards
----------------------------------------------------------------------
use("Fling FX")
H("3D Extras")
T("3D Speed Streaks", "fl_s3", false)
SL("Streak Count", "fl_s3n", 6, 40, 18, 0)
SL("Streak Length", "fl_s3l", 4, 60, 22, 0)
SL("Streak Start Speed", "fl_s3th", 20, 300, 55, 0)
CO("Streak Color", "fl_s3c", rgb(200, 230, 255))
T("3D Impact Shards", "fl_shard", false)
CO("Shard Color 1", "fl_sh1", rgb(255, 255, 255))
CO("Shard Color 2", "fl_sh2", rgb(120, 200, 255))

local streaks = {}
local sFolder = Instance.new("Folder")
sFolder.Name = "SefStreaks"
local sShown = false
local lastSp, shCd = 0, 0
L.steps[#L.steps + 1] = function(dt, t)
	local ch = LP.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local c = cam()
	if not (hrp and c) then return end
	local v = hrp.AssemblyLinearVelocity
	local sp = v.Magnitude
	shCd = max(0, shCd - dt)
	if S.fl_shard and shCd <= 0 and lastSp > 70 and lastSp - sp > 55 then
		shCd = .5
		local pos = hrp.Position - V3(0, 2.5, 0)
		for i = 1, 14 do
			local dv = V3(rnd() - .5, rnd() * .9 + .2, rnd() - .5).Unit
			local sz = .5 + rnd() * .8
			local p = mk(BLOCK, pos, V3(sz, sz, sz), (i % 2 == 0) and S.fl_sh1 or S.fl_sh2)
			tw(p, .8, { CFrame = CFrame.new(pos + dv * (6 + rnd() * 12)) * CFrame.Angles(rnd() * 6, rnd() * 6, rnd() * 6), Transparency = 1 }, Enum.EasingStyle.Quad)
			Debris:AddItem(p, 1)
		end
	end
	lastSp = sp
	local on = S.fl_s3 and sp > S.fl_s3th
	if not on then
		if sShown then sFolder.Parent = nil sShown = false end
		return
	end
	local n = floor(S.fl_s3n)
	while #streaks < n do
		local p = Instance.new("Part")
		p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Parent = sFolder
		streaks[#streaks + 1] = { p = p, ph = rnd(), a = rnd() * TAU, r = 7 + rnd() * 20 }
	end
	if not sShown then sFolder.Parent = fxFolder sShown = true end
	local vd = v / sp
	local up0 = (abs(vd.Y) > .95) and V3(1, 0, 0) or V3(0, 1, 0)
	local rgt = vd:Cross(up0).Unit
	local upv = rgt:Cross(vd)
	local cpos = c.CFrame.Position
	for i, st in ipairs(streaks) do
		if i <= n then
			st.ph = (st.ph + dt * (.5 + sp / 160)) % 1
			local along = 45 - st.ph * 90
			local pos = cpos + vd * along + rgt * (cos(st.a) * st.r) + upv * (sin(st.a) * st.r)
			local len = S.fl_s3l * (.6 + (i % 4) * .2)
			st.p.Size = V3(.14, .14, len)
			st.p.CFrame = CFrame.lookAt(pos, pos + vd)
			st.p.Color = S.fl_s3c
			st.p.Transparency = clamp(.25 + abs(st.ph - .5) * 1.4, 0, 1)
			if st.p.Parent ~= sFolder then st.p.Parent = sFolder end
		else
			st.p.Parent = nil
		end
	end
end
L.cleanups[#L.cleanups + 1] = function() pcall(function() sFolder:Destroy() end) end

----------------------------------------------------------------------
-- Maintenance buttons
----------------------------------------------------------------------
use("Settings")
H("Maintenance")
local function activeList()
	local out = {}
	for k, v in pairs(S) do
		if v == true and L.DEF and L.DEF[k] == false then out[#out + 1] = (L.names and L.names[k]) or k end
	end
	table.sort(out)
	return out
end
B("Show What's Turned On", function()
	local l = activeList()
	if L.showList then L.showList("Turned on", l) end
	U.notify("Sef's Ftap Visuals", #l == 0 and "Nothing is turned on." or (#l .. " feature(s) on."))
end)
B("Turn Everything Off", function()
	local n = 0
	for k, v in pairs(S) do
		if v == true and L.DEF and L.DEF[k] == false and Ctl[k] then
			pcall(Ctl[k].set, false)
			n = n + 1
		end
	end
	U.notify("Sef's Ftap Visuals", "Turned off " .. n .. " feature(s).")
end)
B("Reset All Settings", function()
	if not L.DEF then return end
	for k, v in pairs(L.DEF) do
		if Ctl[k] and S[k] ~= v then pcall(Ctl[k].set, v) end
	end
	U.notify("Sef's Ftap Visuals", "All settings reset to defaults.")
end)
end)

-- module: 16_guide  (S button opens a sliding panel that explains every tab)
MOD("16_guide", function()
local S, L = U.S, U.L
local new, tw, cr = U.new, U.tw, U.cr
local DESC = {
	["Camera"] = "FOV, zoom key, roll, shake, head-bob, cinematic bars",
	["Lighting"] = "Time of day, brightness, fog, ambient and light presets",
	["Effects"] = "Bloom, blur, color grading, depth of field, vignette",
	["Sky"] = "Stars, sun and moon size, clouds, custom skybox",
	["Weather"] = "Rain, snow, storms and floating particles around you",
	["Character"] = "Hat, halo, wings, auras, trails and body colors",
	["Players"] = "Local-only looks and outlines for other players",
	["Grab Lines"] = "Recolor the game's own grab line, tip and sounds",
	["3D Lines"] = "13 animated 3D grab lines, stretch, elastic, 3D tips",
	["Pallets"] = "Pallet colors, materials, glow and transparency",
	["Toys"] = "Recolor, glow, trails and effects on spawned toys",
	["Fling FX"] = "Effects when you get flung or move fast, 3D streaks",
	["Throw FX"] = "Trails, launch bursts and impacts when you throw",
	["Explosions"] = "Swap missile explosions for custom 3D blasts",
	["World"] = "Water, terrain and map part colors",
	["Overlays"] = "Screen tints, scanlines, borders, film grain",
	["Covers"] = "The animated frame around this menu, offset and hue",
	["HUD"] = "FPS, ping, stats, crosshair and watermark",
	["Sounds"] = "Custom grab scream and sound options",
	["Settings"] = "Menu key, accent color, scale, save / load / reset",
	["FTAP+"] = "Scene presets, player outlines, grab and landing FX",
}
local ORDER = { "Camera", "Lighting", "Effects", "Sky", "Weather", "Character", "Players", "Grab Lines", "3D Lines", "Pallets", "Toys", "Fling FX", "Throw FX", "Explosions", "World", "Overlays", "Covers", "HUD", "Sounds", "FTAP+", "Settings" }
for i, name in ipairs(ORDER) do
	local t = L.tabs[name]
	if t then t.btn.LayoutOrder = i end
end

local PW = 256
local panel = new("Frame", { Name = "SefTabGuide", Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0, 54, 1, -28), BackgroundColor3 = Color3.fromRGB(16, 16, 16), BackgroundTransparency = .02, BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 40 }, UI)
cr(panel, 27)
new("UIStroke", { Color = Color3.fromRGB(190, 190, 190), Transparency = .7 }, panel)
local catcher = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 39 }, UI)
local head = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), ZIndex = 41 }, panel)
new("TextLabel", { Text = "S", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromOffset(54, 44), Position = UDim2.fromOffset(0, 4), ZIndex = 42 }, panel)
new("TextLabel", { Text = "What each tab does", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(240, 240, 240), TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(62, 9), Size = UDim2.fromOffset(PW - 74, 18), ZIndex = 42 }, panel)
new("TextLabel", { Text = "tap a row to jump to it", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Color3.fromRGB(150, 150, 150), TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(62, 27), Size = UDim2.fromOffset(PW - 74, 14), ZIndex = 42 }, panel)
new("Frame", { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = Color3.fromRGB(120, 120, 120), BackgroundTransparency = .6, BorderSizePixel = 0, ZIndex = 41 }, panel)
local list = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 41 }, panel)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
new("UIPadding", { PaddingBottom = UDim.new(0, 8) }, list)

local open = false
local function setGuide(v)
	open = v
	if v then
		panel.Visible = true
		catcher.Visible = true
		panel.Size = UDim2.new(0, 54, 1, -28)
		tw(panel, .34, { Size = UDim2.new(0, PW, 1, -28) }, Enum.EasingStyle.Quint)
	else
		catcher.Visible = false
		tw(panel, .22, { Size = UDim2.new(0, 54, 1, -28) }, Enum.EasingStyle.Quint)
		task.delay(.24, function() if not open then panel.Visible = false end end)
	end
end
for i, name in ipairs(ORDER) do
	local t = L.tabs[name]
	if t then
		local row = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 50), LayoutOrder = i, ZIndex = 42 }, list)
		cr(row, 14)
		local src = t.btn:FindFirstChildOfClass("ImageLabel")
		if src then
			local ic = src:Clone()
			ic.AnchorPoint = Vector2.new(0, 0)
			ic.Position = UDim2.fromOffset(15, 12)
			ic.ZIndex = 43
			ic.Parent = row
		end
		new("TextLabel", { Text = name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(240, 240, 240), TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 5), Size = UDim2.new(1, -62, 0, 16), ZIndex = 43 }, row)
		new("TextLabel", { Text = DESC[name] or "", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Color3.fromRGB(160, 160, 160), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 21), Size = UDim2.new(1, -62, 0, 26), ZIndex = 43 }, row)
		row.MouseButton1Click:Connect(function()
			selectTab(t)
			setGuide(false)
		end)
		row.MouseEnter:Connect(function() tw(row, .12, { BackgroundTransparency = .55 }) end)
		row.MouseLeave:Connect(function() tw(row, .15, { BackgroundTransparency = 1 }) end)
	end
end
head.MouseButton1Click:Connect(function() setGuide(false) end)
catcher.MouseButton1Click:Connect(function() setGuide(false) end)
local sBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), ZIndex = 12 }, sidebar)
makeDraggable(sBtn, Main, function() setGuide(not open) end)
L.cleanups[#L.cleanups + 1] = function() pcall(function() panel:Destroy() catcher:Destroy() end) end

-- snapshot of the default state (used by "Turn Everything Off" / "Reset All Settings")
L.DEF = {}
for k, v in pairs(S) do L.DEF[k] = v end
end)

-- run character hooks for the current character
task.defer(function() for _, fn in ipairs(L.onChar) do pcall(fn) end end)

-- defaults chosen above for sliders that tune the UI itself
ov.BackgroundTransparency = S.ui_t
bg.ImageTransparency = 1 - S.ui_bg
pcall(function()
	computeFit()
	uiScale.Scale = targetScale()
	clampMain()
end)
pcall(function()
	local c = workspace.CurrentCamera
	if c then C(c:GetPropertyChangedSignal("ViewportSize"), function() computeFit() if isOpenUI ~= false then uiScale.Scale = targetScale() end clampMain() end) end
end)
pcall(L.glPreset, "Neon Cyan")

----------------------------------------------------------------------
-- UI behaviour
----------------------------------------------------------------------
local okSel, errSel = pcall(selectTab, firstTab)
if not okSel then warn("[Sef's Ftap Visuals] selectTab failed: " .. tostring(errSel)) for _, x in ipairs(Tabs) do x.page.Visible = (x == firstTab) end end

-- menu particles
for i = 1, 28 do
	local sz = math.random(2, 5)
	local p = new("Frame", { Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = Color3.fromRGB(220, 220, 220), BackgroundTransparency = 1, BorderSizePixel = 0 }, plr)
	cr(p, 3)
	task.spawn(function()
		task.wait(math.random() * 5)
		while alive do
			if i <= S.ui_pn then
				local x = math.random()
				local dur = math.random(60, 120) / 10
				p.Position = UDim2.new(x, 0, 1, 10)
				p.BackgroundTransparency = 1
				tw(p, dur, { Position = UDim2.new(math.clamp(x + (math.random() - .5) * .2, 0, 1), 0, 0, -10) }, Enum.EasingStyle.Linear)
				tw(p, 1.2, { BackgroundTransparency = .5 })
				task.wait(dur - 1.2)
				tw(p, 1.2, { BackgroundTransparency = 1 })
				task.wait(1.4)
			else
				task.wait(1)
			end
		end
	end)
end

makeDraggable(header, Main)
makeDraggable(sidebar, Main)
C(UIS.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then task.defer(clampMain) end end)

-- open / close
local isOpen = true
isOpenUI = true
local function toggleUI(force)
	if force ~= nil then isOpen = force else isOpen = not isOpen end
	isOpenUI = isOpen
	if isOpen then
		Main.Visible = true
		if S.ui_anim then
			uiScale.Scale = targetScale() * .85
			tw(uiScale, .35, { Scale = targetScale() }, Enum.EasingStyle.Back)
		end
	else
		if S.ui_anim then
			tw(uiScale, .2, { Scale = targetScale() * .85 }, Enum.EasingStyle.Quad)
			task.delay(.2, function() if not isOpen then Main.Visible = false end end)
		else
			Main.Visible = false
		end
	end
end
closeBtn.MouseButton1Click:Connect(function() toggleUI(false) end)

local fb = new("TextButton", { Text = "S", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(15, 15, 15), BackgroundTransparency = .1, AutoButtonColor = false, Size = UDim2.fromOffset(UIS.TouchEnabled and 44 or 36, UIS.TouchEnabled and 44 or 36), Position = UDim2.fromOffset(12, 120) }, gui)
cr(fb, 18)
new("UIStroke", { Color = Color3.fromRGB(200, 200, 200), Transparency = .6 }, fb)
makeDraggable(fb, fb, function() toggleUI() end)
L.fb = fb

C(UIS.InputBegan, function(i)
	if listening or UIS:GetFocusedTextBox() then return end
	if i.KeyCode == S.ui_key then toggleUI() end
	if i.KeyCode == S.zoom_key then zoomHeld = true end
end)
C(UIS.InputEnded, function(i)
	if i.KeyCode == S.zoom_key then zoomHeld = false end
end)

----------------------------------------------------------------------
-- main loops
----------------------------------------------------------------------
local camName = "SefCam" .. Http:GenerateGUID(false)
RS:BindToRenderStep(camName, Enum.RenderPriority.Camera.Value + 1, function(dt)
	if alive then pcall(camStep, dt) end
end)

local fixAcc = 0
C(RS.RenderStepped, function(dt)
	if not alive then return end
	local t = tick() - T0
	local c = cam()
	if c and fxFolder.Parent ~= c then fxFolder.Parent = c end
	pcall(L.accStep, t)
	pcall(L.grabStep, t)
	pcall(L.palStep, dt, t)
	pcall(L.hudStep, dt)
	for _, fn in ipairs(L.steps) do
		local ok, e = pcall(fn, dt, t)
		if not ok and S.ex_dbg then warn("[Sef step]", e) end
	end
	if c then weather.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, 35, 0)) end
	if S.ch_rain then pcall(L.rainbowChar, t) end
	if S.tloop then Lighting.ClockTime = (Lighting.ClockTime + dt * S.tspeed) % 24 end
	if S.xh_spin and xh.Visible then xh.Rotation = (xh.Rotation + dt * 120) % 360 end
	fixAcc = fixAcc + dt
	if fixAcc > .5 then
		fixAcc = 0
		if S.cam_fix then L.fixCam() end
	end
end)

C(LP.CharacterAdded, function()
	task.wait(1)
	if not alive then return end
	pcall(L.char) pcall(L.rig)
	for _, fn in ipairs(L.onChar or {}) do pcall(fn) end
end)

L.fx() L.vig() L.bars() L.weather()

-- unload
env.SefFtapUnload = function()
	alive = false
	for _, cn in ipairs(conns) do pcall(function() cn:Disconnect() end) end
	pcall(function() RS:UnbindFromRenderStep(camName) end)
	pcall(L.palRestore)
	S.ch_rain, S.ch_col_on, S.ch_neon, S.ch_ff, S.ch_ghost, S.ch_hideacc, S.ch_hl = false, false, false, false, false, false, false
	S.tr_on, S.aura_on, S.limb_on, S.hat_on, S.halo_on = false, false, false, false, false
	pcall(L.char) pcall(L.rig)
	for _, fn in ipairs(L.cleanups) do pcall(fn) end
	pcall(function() cam().FieldOfView = camState.default - 0 end)
	for _, o in pairs(FX) do pcall(function() o:Destroy() end) end
	if atmos then pcall(function() atmos:Destroy() end) end
	for k, p in pairs(LMAP) do if orig[p] ~= nil then setL(p, orig[p]) end end
	setL("GlobalShadows", orig.GlobalShadows)
	pcall(function() fxFolder:Destroy() end)
	pcall(function() gui:Destroy() end)
	pcall(function() hud:Destroy() end)
	env.SefFtapUnload = nil
end

notify("Sef's Ftap Visuals", "Loaded - " .. FEATURES .. " features. Toggle: RightShift or the S button.")
