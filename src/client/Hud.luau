--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Hud = {}

local HUD_NAME = "GunHUD"
local VIGNETTE_OPACITY = 0.4
local DOT_INTERVAL = 0.25
local HITMARKER_FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HIT_COLOR = Color3.new(1, 1, 1)
local HEADSHOT_COLOR = Color3.fromRGB(255, 70, 70)
local AMMO_COLOR = Color3.new(1, 1, 1)
local EMPTY_COLOR = Color3.fromRGB(255, 80, 80)
local RELOADING_COLOR = Color3.fromRGB(200, 200, 200)
local LINE_DIRECTIONS: { [string]: Vector2 } = {
	Top = Vector2.new(0, -1),
	Bottom = Vector2.new(0, 1),
	Left = Vector2.new(-1, 0),
	Right = Vector2.new(1, 0),
}

type CrosshairLine = {
	frame: GuiObject,
	direction: Vector2,
}

type Elements = {
	gui: ScreenGui,
	crosshair: GuiObject,
	lines: { CrosshairLine },
	hitmarkerTicks: { GuiObject },
	vignetteEdges: { GuiObject },
	nameLabel: TextLabel,
	ammoLabel: TextLabel,
}

local elements: Elements? = nil
local reloadAnimating = false
local reloadToken = 0

local function guiChildren(parent: Instance): { GuiObject }
	local found = {}
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(found, child)
		end
	end
	return found
end

local function bind(): Elements
	local gui = player:WaitForChild("PlayerGui"):WaitForChild(HUD_NAME) :: ScreenGui
	local crosshair = gui:WaitForChild("Crosshair") :: GuiObject
	local lines = {}
	for name, direction in LINE_DIRECTIONS do
		table.insert(lines, { frame = crosshair:WaitForChild(name) :: GuiObject, direction = direction })
	end
	return {
		gui = gui,
		crosshair = crosshair,
		lines = lines,
		hitmarkerTicks = guiChildren(crosshair:WaitForChild("Hitmarker")),
		vignetteEdges = guiChildren(gui:WaitForChild("Vignette")),
		nameLabel = gui:WaitForChild("WeaponName") :: TextLabel,
		ammoLabel = gui:WaitForChild("Ammo") :: TextLabel,
	}
end

local function startReloadDots(hud: Elements)
	if reloadAnimating then
		return
	end
	reloadAnimating = true
	reloadToken += 1
	local token = reloadToken
	task.spawn(function()
		local count = 0
		while reloadAnimating and token == reloadToken do
			count = count % 3 + 1
			hud.ammoLabel.Text = string.rep("• ", count - 1) .. "•"
			task.wait(DOT_INTERVAL)
		end
	end)
end

function Hud.Show(weaponName: string)
	local hud = elements or bind()
	elements = hud
	hud.nameLabel.Text = string.upper(weaponName)
	hud.gui.Enabled = true
	UserInputService.MouseIconEnabled = false
end

function Hud.Hide()
	reloadAnimating = false
	local hud = elements
	if hud then
		hud.gui.Enabled = false
	end
	UserInputService.MouseIconEnabled = true
end

function Hud.SetAmmo(ammo: number, magSize: number, reloading: boolean)
	local hud = elements
	if not hud then
		return
	end
	if reloading then
		hud.ammoLabel.TextColor3 = RELOADING_COLOR
		startReloadDots(hud)
	else
		reloadAnimating = false
		hud.ammoLabel.Text = string.format("%d / %d", ammo, magSize)
		hud.ammoLabel.TextColor3 = if ammo == 0 then EMPTY_COLOR else AMMO_COLOR
	end
end

function Hud.Hitmarker(headshot: boolean)
	local hud = elements
	if not hud then
		return
	end
	local color = if headshot then HEADSHOT_COLOR else HIT_COLOR
	for _, tick in hud.hitmarkerTicks do
		tick.BackgroundColor3 = color
		tick.BackgroundTransparency = 0
		TweenService:Create(tick, HITMARKER_FADE, { BackgroundTransparency = 1 }):Play()
	end
end

function Hud.SetAim(alpha: number)
	local hud = elements
	if not hud then
		return
	end
	for _, edge in hud.vignetteEdges do
		edge.BackgroundTransparency = 1 - alpha * VIGNETTE_OPACITY
	end
end

function Hud.SetSpread(gap: number)
	local hud = elements
	if not hud then
		return
	end
	for _, line in hud.lines do
		line.frame.Position = UDim2.fromOffset(line.direction.X * gap, line.direction.Y * gap)
	end
end

function Hud.SetCrosshairVisible(visible: boolean)
	local hud = elements
	if hud then
		hud.crosshair.Visible = visible
	end
end

function Hud.SetCrosshairPosition(screenPosition: Vector2)
	local hud = elements
	if hud then
		hud.crosshair.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	end
end

return Hud
