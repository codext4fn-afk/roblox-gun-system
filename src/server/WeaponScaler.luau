--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponAxes = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("WeaponAxes"))

local WeaponScaler = {}

local SCALED_ATTRIBUTE = "R15Scale"

local function scaleOffset(cframe: CFrame, factor: number): CFrame
	return CFrame.new(cframe.Position * factor) * cframe.Rotation
end

local function moveAimPointToEye(tool: Tool, handle: BasePart, eyeRelief: number)
	local aimPoint = WeaponAxes.GetAttachment(handle, "AimPoint")
	if aimPoint then
		aimPoint.Position -= WeaponAxes.ForwardAxis(tool) * eyeRelief
	end
end

function WeaponScaler.Apply(tool: Tool, factor: number, eyeRelief: number)
	local handle = WeaponAxes.GetHandle(tool)
	if tool:GetAttribute(SCALED_ATTRIBUTE) or not handle then
		return
	end
	local origin = handle.CFrame
	local welds: { WeldConstraint } = {}
	for _, item in tool:GetDescendants() do
		if item:IsA("WeldConstraint") and item.Enabled then
			item.Enabled = false
			table.insert(welds, item)
		elseif item:IsA("JointInstance") then
			item.C0 = scaleOffset(item.C0, factor)
			item.C1 = scaleOffset(item.C1, factor)
		elseif item:IsA("Attachment") then
			item.Position *= factor
		end
	end
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			local relative = origin:ToObjectSpace(part.CFrame)
			part.Size *= factor
			part.CFrame = origin * scaleOffset(relative, factor)
		end
	end
	for _, weld in welds do
		weld.Enabled = true
	end
	tool.Grip = scaleOffset(tool.Grip, factor)
	moveAimPointToEye(tool, handle, eyeRelief)
	tool:SetAttribute(SCALED_ATTRIBUTE, factor)
end

return WeaponScaler
