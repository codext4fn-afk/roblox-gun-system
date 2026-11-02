--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("Types"))

local ScopeOverlay = {}

local SHOW_AT = 0.92
local LENS_SIZE = 0.9
local LINE_THICKNESS = 2
local CENTER_GAP = 0.04
local TINT = Color3.new(0, 0, 0)
local STROKE_THICKNESS = 4000
local DISPLAY_ORDER = 5

local gui: ScreenGui? = nil
local hiddenTool: Tool? = nil

local function line(parent: Instance, size: UDim2, position: UDim2)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = TINT
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Position = position
	frame.Parent = parent
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "ScopeOverlay"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = DISPLAY_ORDER
	screen.Enabled = false

	local lens = Instance.new("Frame")
	lens.Name = "Lens"
	lens.AnchorPoint = Vector2.new(0.5, 0.5)
	lens.Position = UDim2.fromScale(0.5, 0.5)
	lens.Size = UDim2.fromScale(LENS_SIZE, LENS_SIZE)
	lens.BackgroundTransparency = 1
	lens.Parent = screen
	Instance.new("UIAspectRatioConstraint").Parent = lens
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = lens
	local stroke = Instance.new("UIStroke")
	stroke.Color = TINT
	stroke.Thickness = STROKE_THICKNESS
	stroke.Parent = lens

	local arm = (1 - CENTER_GAP) / 4
	local offset = CENTER_GAP / 2 + arm / 2
	line(lens, UDim2.new(arm, 0, 0, LINE_THICKNESS), UDim2.fromScale(0.5 - offset, 0.5))
	line(lens, UDim2.new(arm, 0, 0, LINE_THICKNESS), UDim2.fromScale(0.5 + offset, 0.5))
	line(lens, UDim2.new(0, LINE_THICKNESS, arm, 0), UDim2.fromScale(0.5, 0.5 - offset))
	line(lens, UDim2.new(0, LINE_THICKNESS, arm, 0), UDim2.fromScale(0.5, 0.5 + offset))
	line(lens, UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5))

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

local function setToolHidden(tool: Tool, hidden: boolean)
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function ScopeOverlay.Hide()
	local screen = gui
	if screen then
		screen.Enabled = false
	end
	local tool = hiddenTool
	if tool then
		setToolHidden(tool, false)
		hiddenTool = nil
	end
end

function ScopeOverlay.Update(tool: Tool, config: Types.WeaponConfig, zoomAlpha: number)
	if not (config.ScopeOverlay and zoomAlpha >= SHOW_AT) then
		ScopeOverlay.Hide()
		return
	end
	local existing = gui
	local screen: ScreenGui = if existing and existing.Parent then existing else build()
	gui = screen
	if hiddenTool ~= tool then
		ScopeOverlay.Hide()
		hiddenTool = tool
	end
	screen.Enabled = true
	setToolHidden(tool, true)
end

return ScopeOverlay
