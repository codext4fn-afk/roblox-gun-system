--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

local WeaponRegistry = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("WeaponRegistry"))

local GunSetup = {}

export type NudgeOptions = {
	left: number?,
	up: number?,
	forward: number?,
	yaw: number?,
	pitch: number?,
	roll: number?,
}

local JOINT_NAMES: { [string]: boolean } = {
	GunWeld = true,
	GunJoint = true,
}
local SOUND_NAMES = { "Fire", "Reload", "Empty", "MagOut", "MagIn" }

local function waypoint(name: string)
	pcall(ChangeHistoryService.SetWaypoint, ChangeHistoryService, name)
end

local function getParts(tool: Tool): { BasePart }
	local parts = {}
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end

local function getMovingPartNames(tool: Tool): { [string]: boolean }
	local names = {}
	local config = WeaponRegistry.GetConfig(tool)
	if config then
		names[config.Bolt.Part] = true
		names[config.Magazine.Part] = true
	end
	return names
end

local function removeJoints(tool: Tool)
	for _, item in tool:GetDescendants() do
		if JOINT_NAMES[item.Name] and (item:IsA("WeldConstraint") or item:IsA("JointInstance")) then
			item:Destroy()
		end
	end
end

local function attachToHandle(tool: Tool, handle: BasePart): { string }
	local movingNames = getMovingPartNames(tool)
	local movable = {}
	for _, part in getParts(tool) do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		if part ~= handle then
			part.Massless = true
			if movingNames[part.Name] then
				local joint = Instance.new("Motor6D")
				joint.Name = "GunJoint"
				joint.Part0 = handle
				joint.Part1 = part
				joint.C0 = handle.CFrame:ToObjectSpace(part.CFrame)
				joint.C1 = CFrame.identity
				joint.Parent = part
				table.insert(movable, part.Name)
			else
				local weld = Instance.new("WeldConstraint")
				weld.Name = "GunWeld"
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	return movable
end

local function hasAttachment(parent: Instance?, name: string, recursive: boolean?): boolean
	local item = parent and parent:FindFirstChild(name, recursive)
	return item ~= nil and item:IsA("Attachment")
end

function GunSetup.Build(tool: Tool, handlePart: BasePart?): BasePart
	assert(typeof(tool) == "Instance" and tool:IsA("Tool"), "Pass a Tool")
	local parts = getParts(tool)
	assert(#parts > 0, "The Tool has no parts")

	local existing = tool:FindFirstChild("Handle")
	local handle: BasePart
	if handlePart then
		handle = handlePart
	elseif existing and existing:IsA("BasePart") then
		handle = existing
	else
		table.sort(parts, function(a, b)
			return a.Size.Magnitude > b.Size.Magnitude
		end)
		handle = parts[1]
	end
	for _, item in tool:GetDescendants() do
		if item.Name == "Handle" and item ~= handle then
			item.Name = "GunPart"
		end
	end
	handle.Name = "Handle"
	handle.Parent = tool

	removeJoints(tool)
	local movable = attachToHandle(tool, handle)
	tool.RequiresHandle = true

	print(`GunSetup: {tool.Name} built, movable parts: {if #movable > 0 then table.concat(movable, ", ") else "none"}`)
	waypoint("GunSetup.Build")
	GunSetup.Validate(tool)
	return handle
end

function GunSetup.Validate(tool: Tool)
	assert(typeof(tool) == "Instance" and tool:IsA("Tool"), "Pass a Tool")
	local config = WeaponRegistry.GetConfig(tool)
	local handle = tool:FindFirstChild("Handle")
	local lines = {}

	local function check(passed: boolean, required: boolean, description: string)
		local status = if passed then "OK      " elseif required then "MISSING " else "OPTIONAL"
		table.insert(lines, `{status}  {description}`)
	end

	local weaponId = tool:GetAttribute("Weapon")
	check(
		config ~= nil,
		true,
		`Config module named '{if type(weaponId) == "string" then weaponId else tool.Name}' in Configs`
	)
	check(handle ~= nil and handle:IsA("BasePart"), true, "Part named Handle directly in the Tool")
	check(hasAttachment(handle, "Muzzle"), true, "Attachment 'Muzzle' in Handle at the barrel tip")
	check(
		hasAttachment(tool, "ShootFirst", true),
		false,
		"Attachment 'ShootFirst' on the sight line (first-person shots)"
	)
	check(hasAttachment(handle, "AimPoint"), false, "Attachment 'AimPoint' in Handle behind the sight (scope camera)")
	check(hasAttachment(handle, "Ejection"), false, "Attachment 'Ejection' in Handle at the ejection port")
	check(
		hasAttachment(handle, "SupportGrip"),
		false,
		"Attachment 'SupportGrip' in Handle where the support hand holds (R15)"
	)

	if config then
		local features: { { name: string, part: string } } = {
			{ name = "Bolt", part = config.Bolt.Part },
			{ name = "Magazine", part = config.Magazine.Part },
		}
		for _, feature in features do
			local part = tool:FindFirstChild(feature.part, true)
			local joint = part and part:FindFirstChild("GunJoint")
			check(joint ~= nil, false, `{feature.name} part '{feature.part}' with a GunJoint (run GunSetup.Build)`)
		end
	end

	for _, soundName in SOUND_NAMES do
		local sound = handle and handle:FindFirstChild(soundName)
		check(sound ~= nil and sound:IsA("Sound"), false, `Sound '{soundName}' in Handle`)
	end

	print(`GunSetup.Validate: {tool.Name}\n{table.concat(lines, "\n")}`)
end

function GunSetup.Scale(tool: Tool, factor: number)
	local handle = tool:FindFirstChild("Handle")
	assert(handle and handle:IsA("BasePart"), "Run GunSetup.Build first")
	removeJoints(tool)

	local origin = handle.CFrame
	for _, part in getParts(tool) do
		local relative = origin:ToObjectSpace(part.CFrame)
		part.Size *= factor
		part.CFrame = origin * (relative - relative.Position) + origin:VectorToWorldSpace(relative.Position * factor)
	end
	for _, item in tool:GetDescendants() do
		if item:IsA("Attachment") then
			item.Position *= factor
		end
	end
	local grip = tool.Grip
	tool.Grip = CFrame.new(grip.Position * factor) * (grip - grip.Position)

	attachToHandle(tool, handle)
	waypoint("GunSetup.Scale")
end

function GunSetup.AddAimPoint(tool: Tool): Attachment
	local handle = tool:FindFirstChild("Handle")
	assert(handle and handle:IsA("BasePart"), "Run GunSetup.Build first")
	local existing = handle:FindFirstChild("AimPoint")
	local point: Attachment
	if existing and existing:IsA("Attachment") then
		point = existing
	else
		point = Instance.new("Attachment")
		point.Name = "AimPoint"
		point.Parent = handle
	end
	Selection:Set({ point })
	waypoint("GunSetup.AddAimPoint")
	return point
end

function GunSetup.Nudge(tool: Tool, options: NudgeOptions?)
	local settings: NudgeOptions = options or {}
	local offset = Vector3.new(-(settings.left or 0), settings.up or 0, -(settings.forward or 0))
	local rotation = CFrame.Angles(0, math.rad(-(settings.yaw or 0)), 0)
		* CFrame.Angles(math.rad(settings.pitch or 0), 0, 0)
		* CFrame.Angles(0, 0, math.rad(-(settings.roll or 0)))
	tool.Grip = tool.Grip * rotation:Inverse() * CFrame.new(-offset)
	waypoint("GunSetup.Nudge")
end

return GunSetup
