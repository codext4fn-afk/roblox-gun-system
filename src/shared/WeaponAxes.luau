--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local AngleMath = require(script.Parent.AngleMath)

local WeaponAxes = {}

local DEFAULT_MUZZLE = Vector3.new(-1, 0, 0)
local SHOOT_POINT = "ShootFirst"

function WeaponAxes.GetHandle(tool: Instance): BasePart?
	local handle = tool:FindFirstChild("Handle")
	return if handle and handle:IsA("BasePart") then handle else nil
end

function WeaponAxes.GetAttachment(parent: Instance?, name: string): Attachment?
	local attachment = parent and parent:FindFirstChild(name)
	return if attachment and attachment:IsA("Attachment") then attachment else nil
end

function WeaponAxes.ForwardAxis(tool: Instance): Vector3
	local muzzle = WeaponAxes.GetAttachment(WeaponAxes.GetHandle(tool), "Muzzle")
	return AngleMath.DominantAxis(if muzzle then muzzle.Position else DEFAULT_MUZZLE)
end

function WeaponAxes.GunRay(tool: Instance): (Vector3?, Vector3?)
	local handle = WeaponAxes.GetHandle(tool)
	local point = tool:FindFirstChild(SHOOT_POINT, true)
	if not (handle and point and point:IsA("Attachment")) then
		return nil, nil
	end
	return point.WorldPosition, handle.CFrame:VectorToWorldSpace(WeaponAxes.ForwardAxis(tool))
end

function WeaponAxes.FindJoint(tool: Instance, partName: string?): (Motor6D?, BasePart?)
	if type(partName) ~= "string" then
		return nil, nil
	end
	local part = tool:FindFirstChild(partName, true)
	if not (part and part:IsA("BasePart")) then
		return nil, nil
	end
	local joint = part:FindFirstChild("GunJoint")
	if joint and joint:IsA("Motor6D") then
		return joint, part
	end
	return nil, nil
end

return WeaponAxes
