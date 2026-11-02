--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponRegistry = require(WeaponSystem:WaitForChild("WeaponRegistry"))

local WeaponAnimationBuilder = {}

type PoseEntry = {
	path: { string },
	cframe: CFrame,
}

type ShoulderFrame = {
	C0: CFrame,
	C1: CFrame,
}

local DRAFTS_FOLDER = "AnimationDrafts"
local LEFT_SHOULDER: ShoulderFrame = {
	C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
	C1 = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
}
local RIGHT_SHOULDER: ShoulderFrame = {
	C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
	C1 = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
}
local R6_RIGHT_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
local R6_PALM = Vector3.new(0, -1, 0)
local MAGAZINE_HOLD = Vector3.new(0, -0.15, 0)
local BELOW_WELL = 0.45
local REFERENCE_ARM_KICK = 0.6
local BODY_WEIGHT_MIN, BODY_WEIGHT_MAX = 0.7, 1.8
local IDENTITY = CFrame.new()
local R15_BODY_ANIMATIONS: { Types.AnimationName } = { "Hold", "Aim", "Reload" }

local function newSequence(name: string, loop: boolean, priority: Enum.AnimationPriority): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = loop
	sequence.Priority = priority
	return sequence
end

local function newPose(name: string, parent: Instance): Pose
	local pose = Instance.new("Pose")
	pose.Name = name
	pose.Weight = 0
	pose.Parent = parent
	return pose
end

local function getOrCreateFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function addKeyframe(sequence: KeyframeSequence, time: number, rootName: string, poses: { PoseEntry })
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = time
	local root = Instance.new("Pose")
	root.Name = rootName
	root.Weight = 0
	root.Parent = keyframe
	local byName: { [string]: Pose } = { [rootName] = root }
	for _, entry in poses do
		local parent = root
		for index, name in entry.path do
			local pose = byName[name] or newPose(name, parent)
			byName[name] = pose
			if index == #entry.path then
				pose.CFrame = entry.cframe
				pose.Weight = 1
				pose.EasingStyle = Enum.PoseEasingStyle.Cubic
				pose.EasingDirection = Enum.PoseEasingDirection.InOut
			end
			parent = pose
		end
	end
	keyframe.Parent = sequence
end

local function sortedKeyframes(sequence: KeyframeSequence): { Keyframe }
	local keyframes: { Keyframe } = {}
	for _, item in sequence:GetKeyframes() do
		if item:IsA("Keyframe") then
			table.insert(keyframes, item)
		end
	end
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)
	return keyframes
end

local function poseAt(sequence: KeyframeSequence, jointName: string, time: number): CFrame
	local found = CFrame.identity
	for _, keyframe in sortedKeyframes(sequence) do
		if keyframe.Time > time + 1e-3 then
			break
		end
		local pose = keyframe:FindFirstChild(jointName, true)
		if pose and pose:IsA("Pose") and pose.Weight > 0 then
			found = pose.CFrame
		end
	end
	return found
end

local function getDraftRoot(rig: Types.RigName): Instance
	return getOrCreateFolder(getOrCreateFolder(WeaponSystem, DRAFTS_FOLDER), rig)
end

local function loadShared(rig: Types.RigName, name: Types.AnimationName): KeyframeSequence?
	local id = Settings.SharedAnimations[rig][name]
	if id ~= "" then
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(id) :: KeyframeSequence
	end
	local draft = getDraftRoot(rig):FindFirstChild(name)
	return if draft and draft:IsA("KeyframeSequence") then draft else nil
end

local function getDraftFolder(rig: Types.RigName, weaponId: string): Instance
	local folder = getOrCreateFolder(getDraftRoot(rig), weaponId)
	folder:ClearAllChildren()
	return folder
end

local function handleFor(tool: Tool, rightArmPose: CFrame): CFrame
	local arm = RIGHT_SHOULDER.C0 * rightArmPose * RIGHT_SHOULDER.C1:Inverse()
	local gripR6 = tool:GetAttribute("GripR6")
	local grip = if typeof(gripR6) == "CFrame" then gripR6 else tool.Grip
	return arm * R6_RIGHT_GRIP * grip:Inverse()
end

local function reachLeft(target: Vector3, reference: CFrame): CFrame
	local palm = LEFT_SHOULDER.C1:Inverse() * R6_PALM
	local goal = LEFT_SHOULDER.C0:Inverse() * target
	local current = reference.Rotation * palm
	local axis = current:Cross(goal)
	local turn = CFrame.identity
	if axis.Magnitude > 1e-6 then
		local angle = math.acos(math.clamp(current.Unit:Dot(goal.Unit), -1, 1))
		turn = CFrame.fromAxisAngle(axis.Unit, angle)
	end
	local rotation = turn * reference.Rotation
	return CFrame.new(goal - rotation * palm) * rotation
end

local function getHandle(tool: Tool): BasePart
	local handle = tool:FindFirstChild("Handle")
	assert(handle and handle:IsA("BasePart"), `{tool.Name} has no Handle`)
	return handle
end

local function handleAttachment(tool: Tool, name: string): Vector3?
	local attachment = getHandle(tool):FindFirstChild(name)
	return if attachment and attachment:IsA("Attachment") then attachment.Position else nil
end

local function magazinePoint(tool: Tool, config: Types.WeaponConfig): Vector3?
	local part = tool:FindFirstChild(config.Magazine.Part, true)
	local joint = part and part:FindFirstChild("GunJoint")
	if not (joint and joint:IsA("Motor6D")) then
		return nil
	end
	return (joint.C0 * CFrame.new(MAGAZINE_HOLD)).Position
end

local function supportPoint(tool: Tool): Vector3
	local point = handleAttachment(tool, "SupportGrip")
	if point then
		return point
	end
	local muzzle = handleAttachment(tool, "Muzzle") or Vector3.new(-getHandle(tool).Size.X / 2, 0, 0)
	local eye = handleAttachment(tool, "AimPoint") or Vector3.zero
	return eye:Lerp(muzzle, 0.38) - Vector3.new(0, 0.16, 0)
end

local function buildR6Reload(tool: Tool, config: Types.WeaponConfig, shared: KeyframeSequence): KeyframeSequence
	local magazine = config.Magazine
	local duration = config.ReloadTime
	local right = poseAt(shared, "Right Arm", 0)
	local handle = handleFor(tool, right)
	local restLeft = poseAt(shared, "Left Arm", 0)
	local support = reachLeft(handle * supportPoint(tool), restLeft)

	local magPoint = magazinePoint(tool, config)
	local atMagazine = if magPoint then reachLeft(handle * magPoint, restLeft) else support
	local belowWell = if magPoint
		then reachLeft(handle * (magPoint - Vector3.new(0, BELOW_WELL, 0)), restLeft)
		else atMagazine
	local sharedKeys = sortedKeyframes(shared)
	local sharedLength = sharedKeys[#sharedKeys].Time
	local function sharedLeft(fraction: number): CFrame
		return poseAt(shared, "Left Arm", fraction * sharedLength)
	end

	local keys: { { number | CFrame } } = {
		{ 0, support },
		{ math.max(magazine.Out - 0.04, 0.02), atMagazine },
		{ magazine.Out + 0.03, atMagazine },
		{ magazine.Drop, sharedLeft(0.25) },
		{ magazine.Grab, sharedLeft(0.5) },
		{ magazine.In - 0.06, belowWell },
		{ magazine.In, atMagazine },
		{ magazine.In + 0.08, atMagazine },
		{ math.min(magazine.In + 0.22, 0.95), support },
		{ 1, support },
	}
	local sequence = newSequence("Reload", false, Enum.AnimationPriority.Action4)
	local headStart = poseAt(shared, "Head", 0)
	local headEnd = poseAt(shared, "Head", sharedLength)
	for _, key in keys do
		local fraction, leftPose = key[1] :: number, key[2] :: CFrame
		addKeyframe(sequence, fraction * duration, "HumanoidRootPart", {
			{ path = { "Torso", "Right Arm" }, cframe = right },
			{ path = { "Torso", "Left Arm" }, cframe = leftPose },
			{ path = { "Torso", "Head" }, cframe = headStart:Lerp(headEnd, math.sin(fraction * math.pi)) },
		})
	end
	return sequence
end

local function buildR6BoltFeed(tool: Tool, config: Types.WeaponConfig, shared: KeyframeSequence): KeyframeSequence
	local magazine = config.Magazine
	local duration = config.ReloadTime
	local right = poseAt(shared, "Right Arm", 0)
	local handle = handleFor(tool, right)
	local restLeft = poseAt(shared, "Left Arm", 0)
	local support = reachLeft(handle * supportPoint(tool), restLeft)
	local bolt = tool:FindFirstChild(config.Bolt.Part, true)
	local joint = bolt and bolt:FindFirstChild("GunJoint")
	local knob = if joint and joint:IsA("Motor6D") then joint.C0.Position else supportPoint(tool)
	local back = Vector3.new(config.Bolt.Travel * 1.2, 0, 0)
	local port = handleAttachment(tool, "MagazineWell") or knob
	local atKnob = reachLeft(handle * knob, restLeft)
	local pulled = reachLeft(handle * (knob + back), restLeft)
	local atPort = reachLeft(handle * (port + Vector3.new(0, 0.15, -0.25)), restLeft)
	local hip = poseAt(shared, "Left Arm", 0):Lerp(CFrame.identity, 0.85)
	local sharedKeys = sortedKeyframes(shared)
	local headDown = poseAt(shared, "Head", sharedKeys[#sharedKeys].Time)
	local keys: { { number | CFrame } } = {
		{ 0, support },
		{ magazine.Out, atKnob },
		{ magazine.Out + 0.1, pulled },
		{ magazine.Drop, hip },
		{ magazine.Grab, hip },
		{ magazine.In - 0.04, atPort },
		{ magazine.In + 0.04, atPort },
		{ magazine.In + 0.09, pulled },
		{ magazine.In + 0.13, atKnob },
		{ math.min(magazine.In + 0.24, 0.95), support },
		{ 1, support },
	}
	local sequence = newSequence("Reload", false, Enum.AnimationPriority.Action4)
	for _, key in keys do
		local fraction = key[1] :: number
		addKeyframe(sequence, fraction * duration, "HumanoidRootPart", {
			{ path = { "Torso", "Right Arm" }, cframe = right },
			{ path = { "Torso", "Left Arm" }, cframe = key[2] :: CFrame },
			{ path = { "Torso", "Head" }, cframe = IDENTITY:Lerp(headDown, math.sin(fraction * math.pi)) },
		})
	end
	return sequence
end

local function rescale(shared: KeyframeSequence, name: string, amount: number, duration: number?): KeyframeSequence
	local keyframes = sortedKeyframes(shared)
	local length = keyframes[#keyframes].Time
	local timeScale = if duration and length > 0 then duration / length else 1
	local sequence = newSequence(name, shared.Loop, shared.Priority)
	for _, keyframe in keyframes do
		local copy = keyframe:Clone()
		copy.Time = keyframe.Time * timeScale
		for _, pose in copy:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 then
				pose.CFrame = IDENTITY:Lerp(pose.CFrame, amount)
			end
		end
		copy.Parent = sequence
	end
	return sequence
end

function WeaponAnimationBuilder.GetWeapon(weaponId: string): (Tool, Types.WeaponConfig)
	local tool = StarterPack:FindFirstChild(weaponId)
	assert(
		tool and tool:IsA("Tool") and tool:FindFirstChild("Handle"),
		`No Tool '{weaponId}' with a Handle in StarterPack`
	)
	local config = WeaponRegistry.GetConfig(tool)
	assert(config, `No config '{weaponId}' in WeaponSystem.Configs`)
	return tool, config
end

function WeaponAnimationBuilder.BuildR6(weaponId: string): Instance
	local tool, config = WeaponAnimationBuilder.GetWeapon(weaponId)
	local folder = getDraftFolder("R6", weaponId)
	local reload = loadShared("R6", "Reload")
	if reload and config.Reload.Style == "BoltFeed" then
		buildR6BoltFeed(tool, config, reload).Parent = folder
	elseif reload and magazinePoint(tool, config) then
		buildR6Reload(tool, config, reload).Parent = folder
	end
	return folder
end

function WeaponAnimationBuilder.BuildR15(weaponId: string): Instance
	local _, config = WeaponAnimationBuilder.GetWeapon(weaponId)
	local folder = getDraftFolder("R15", weaponId)
	local weight = math.clamp(config.ArmKick / REFERENCE_ARM_KICK, BODY_WEIGHT_MIN, BODY_WEIGHT_MAX)
	for _, name: Types.AnimationName in R15_BODY_ANIMATIONS do
		local shared = loadShared("R15", name)
		if shared then
			local duration = if name == "Reload" then config.ReloadTime else nil
			rescale(shared, name, weight, duration).Parent = folder
		end
	end
	return folder
end

function WeaponAnimationBuilder.Build(weaponId: string)
	WeaponAnimationBuilder.BuildR6(weaponId)
	WeaponAnimationBuilder.BuildR15(weaponId)
	ChangeHistoryService:SetWaypoint(`WeaponAnimationBuilder.Build {weaponId}`)
	print(`WeaponAnimationBuilder: built R6 and R15 drafts for {weaponId}`)
end

return WeaponAnimationBuilder
