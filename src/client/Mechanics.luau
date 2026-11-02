--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponAxes = require(WeaponSystem:WaitForChild("WeaponAxes"))

local AnimationTracks = require(script.Parent.AnimationTracks)
local Effects = require(script.Parent.Effects)

local Mechanics = {}

local R15_HANDS: { [string]: string } = {
	["Left Arm"] = "LeftHand",
	["Right Arm"] = "RightHand",
}
local RELOAD_STEPS = { "Out", "Drop", "Grab", "In" }
local RELOAD_MARKERS: { [string]: string } = {
	Out = "MagOut",
	Drop = "MagDrop",
	Grab = "MagGrab",
	In = "MagIn",
}
local RELOAD_TIMEOUT_PADDING = 0.5
local DROP_COLLIDE_DELAY = 0.15

type JointBase = {
	C0: CFrame,
	Part0: BasePart?,
}

type BoltCycle = {
	started: number,
	base: CFrame,
	travel: Vector3,
	outTime: number,
	returnTime: number,
}

type ActiveReload = {
	joint: Motor6D,
	part: BasePart,
	connections: { RBXScriptConnection },
	finished: { [string]: boolean },
	tween: Tween?,
}

local rng = Random.new()
local jointBases: { [Motor6D]: JointBase } = setmetatable({}, { __mode = "k" }) :: any
local hiddenTransparency: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local activeReloads: { [Tool]: ActiveReload } = setmetatable({}, { __mode = "k" }) :: any
local cyclingBolts: { [Motor6D]: BoltCycle } = {}
local boltConnection: RBXScriptConnection? = nil

local dropFolder = Instance.new("Folder")
dropFolder.Name = "GunDrops"
dropFolder.Parent = workspace

local function getJoint(tool: Tool, partName: string): (Motor6D?, BasePart?)
	local joint, part = WeaponAxes.FindJoint(tool, partName)
	if joint and not jointBases[joint] then
		jointBases[joint] = { C0 = joint.C0, Part0 = joint.Part0 }
	end
	return joint, part
end

local function getHand(character: Model, handName: string): BasePart?
	local hand = character:FindFirstChild(handName) or character:FindFirstChild(R15_HANDS[handName] or "")
	return if hand and hand:IsA("BasePart") then hand else nil
end

local function getPalm(hand: BasePart, attachmentName: string): CFrame
	local grip = WeaponAxes.GetAttachment(hand, attachmentName)
	if grip then
		return grip.CFrame
	end
	return CFrame.new(0, -hand.Size.Y / 2, 0)
end

local function setVisible(part: BasePart, visible: boolean)
	if visible then
		local saved = hiddenTransparency[part]
		if saved ~= nil then
			part.Transparency = saved
			hiddenTransparency[part] = nil
		end
	elseif hiddenTransparency[part] == nil then
		hiddenTransparency[part] = part.Transparency
		part.Transparency = 1
	end
end

local function reattach(joint: Motor6D, newPart0: BasePart)
	local part1 = joint.Part1
	if part1 then
		joint.C0 = newPart0.CFrame:ToObjectSpace(part1.CFrame * joint.C1)
	end
	joint.Part0 = newPart0
end

local function getInsertAxis(tool: Tool, joint: Motor6D): Vector3
	local forward = WeaponAxes.ForwardAxis(tool)
	local position = jointBases[joint].C0.Position
	local sideways = position - forward * position:Dot(forward)
	if sideways.Magnitude < 1e-3 then
		return Vector3.yAxis
	end
	return -sideways.Unit
end

local function getHoldTarget(joint: Motor6D, part: BasePart, hand: BasePart, magazine: Types.MagazineConfig): CFrame
	local palm = getPalm(hand, magazine.GripAttachment) * magazine.HoldOffset
	local magGrip = WeaponAxes.GetAttachment(part, "MagGrip")
	if magGrip then
		return palm * magGrip.CFrame:Inverse() * joint.C1
	end
	local relative = hand.CFrame:ToObjectSpace(part.CFrame)
	return CFrame.new(palm.Position) * relative.Rotation * joint.C1
end

local function dropCopy(part: BasePart, source: BasePart, lifetime: number)
	local copy = part:Clone()
	for _, item in copy:GetDescendants() do
		if item:IsA("JointInstance") or item:IsA("WeldConstraint") or item:IsA("Constraint") then
			item:Destroy()
		end
	end
	copy.Transparency = hiddenTransparency[part] or part.Transparency
	copy.Anchored = false
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Massless = false
	copy.CFrame = part.CFrame
	copy.Parent = dropFolder
	copy.AssemblyLinearVelocity = source.AssemblyLinearVelocity + Vector3.new(0, -4, 0)
	copy.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4))
	task.delay(DROP_COLLIDE_DELAY, function()
		if copy.Parent then
			copy.CanCollide = true
		end
	end)
	task.delay(lifetime, function()
		copy:Destroy()
	end)
end

local function restoreMagazine(reload: ActiveReload)
	local tween = reload.tween
	if tween then
		tween:Cancel()
	end
	local base = jointBases[reload.joint]
	reload.joint.Part0 = base.Part0
	reload.joint.C0 = base.C0
	setVisible(reload.part, true)
end

local function boltCurve(cycle: BoltCycle, elapsed: number): number
	if elapsed < cycle.outTime then
		local t = elapsed / cycle.outTime
		return 1 - (1 - t) * (1 - t)
	end
	local t = math.clamp((elapsed - cycle.outTime) / cycle.returnTime, 0, 1)
	return 1 - t * t
end

local function stepBolts()
	local now = os.clock()
	for joint, cycle in cyclingBolts do
		local elapsed = now - cycle.started
		if not joint.Parent or elapsed >= cycle.outTime + cycle.returnTime then
			if joint.Parent then
				joint.C0 = cycle.base
			end
			cyclingBolts[joint] = nil
		else
			joint.C0 = CFrame.new(cycle.travel * boltCurve(cycle, elapsed)) * cycle.base
		end
	end
	local connection = boltConnection
	if next(cyclingBolts) == nil and connection then
		connection:Disconnect()
		boltConnection = nil
	end
end

function Mechanics.CycleBolt(tool: Tool, config: Types.WeaponConfig)
	local bolt = config.Bolt
	local joint = getJoint(tool, bolt.Part)
	if not joint then
		return
	end
	cyclingBolts[joint] = {
		started = os.clock(),
		base = jointBases[joint].C0,
		travel = -WeaponAxes.ForwardAxis(tool) * bolt.Travel,
		outTime = bolt.OutTime,
		returnTime = bolt.ReturnTime,
	}
	if not boltConnection then
		boltConnection = RunService.PreRender:Connect(stepBolts)
	end
end

function Mechanics.RackDuringReload(tool: Tool, config: Types.WeaponConfig, wasEmpty: boolean)
	local reload, bolt = config.Reload, config.Bolt
	local joint = getJoint(tool, bolt.Part)
	if not joint then
		return
	end
	local feed = reload.Style == "BoltFeed"
	if not (feed or reload.Rack == "Always" or (reload.Rack == "Empty" and wasEmpty)) then
		return
	end
	local magazine = config.Magazine
	local duration = config.ReloadTime
	local openAt = (if feed then magazine.Out else magazine.In + 0.12) * duration
	local closeAt = (if feed then magazine.In + 0.13 else magazine.In + 0.2) * duration
	local base = jointBases[joint].C0
	local open = CFrame.new(-WeaponAxes.ForwardAxis(tool) * bolt.Travel * 1.2) * base
	task.delay(openAt, function()
		if joint.Parent and tool.Parent then
			TweenService
				:Create(joint, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = open })
				:Play()
		end
	end)
	task.delay(closeAt, function()
		if joint.Parent then
			TweenService
				:Create(joint, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = base })
				:Play()
		end
	end)
end

function Mechanics.DropMagazine(part: BasePart, lifetime: number)
	dropCopy(part, part, lifetime)
end

function Mechanics.Cancel(tool: Tool)
	local reload = activeReloads[tool]
	if not reload then
		return
	end
	activeReloads[tool] = nil
	for _, connection in reload.connections do
		connection:Disconnect()
	end
	restoreMagazine(reload)
end

function Mechanics.Reload(
	tool: Tool,
	config: Types.WeaponConfig,
	character: Model,
	rig: Types.RigName,
	track: AnimationTrack?,
	onSeated: (() -> ())?
)
	local magazine = config.Magazine
	local joint, part = getJoint(tool, magazine.Part)
	local hand = getHand(character, magazine.Hand)
	if not (joint and part and hand) then
		return
	end

	Mechanics.Cancel(tool)
	local reload: ActiveReload = { joint = joint, part = part, connections = {}, finished = {}, tween = nil }
	activeReloads[tool] = reload

	local base = jointBases[joint]
	local unseated = CFrame.new(-getInsertAxis(tool, joint) * magazine.InsertDepth) * base.C0

	local function isActive(): boolean
		return activeReloads[tool] == reload and tool.Parent == character and hand.Parent ~= nil
	end

	local function moveMagazine(
		goal: CFrame,
		duration: number,
		style: Enum.EasingStyle,
		direction: Enum.EasingDirection
	): boolean
		local tween = TweenService:Create(joint, TweenInfo.new(duration, style, direction), { C0 = goal })
		reload.tween = tween
		tween:Play()
		tween.Completed:Wait()
		return isActive()
	end

	local actions: { [string]: () -> () } = {
		Out = function()
			Effects.PlaySound(tool, "MagOut")
			if not moveMagazine(unseated, magazine.SlideTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) then
				return
			end
			reattach(joint, hand)
			moveMagazine(
				getHoldTarget(joint, part, hand, magazine),
				magazine.AttachTime,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
		end,
		Drop = function()
			dropCopy(part, hand, magazine.DropLifetime)
			setVisible(part, false)
		end,
		Grab = function()
			setVisible(part, true)
		end,
		In = function()
			setVisible(part, true)
			local restPart0 = base.Part0
			if restPart0 then
				reattach(joint, restPart0)
			end
			if not moveMagazine(unseated, magazine.AlignTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) then
				return
			end
			if not moveMagazine(base.C0, magazine.SeatTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In) then
				return
			end
			Effects.PlaySound(tool, "MagIn")
			if onSeated then
				onSeated()
			end
			Mechanics.Cancel(tool)
		end,
	}

	local function runStep(stepName: string)
		if activeReloads[tool] ~= reload or reload.finished[stepName] then
			return
		end
		if not isActive() then
			Mechanics.Cancel(tool)
			return
		end
		reload.finished[stepName] = true
		task.spawn(actions[stepName])
	end

	local function scheduleByTime()
		for _, stepName in RELOAD_STEPS do
			task.delay(config.ReloadTime * (magazine :: any)[stepName], runStep, stepName)
		end
	end

	task.delay(config.ReloadTime + RELOAD_TIMEOUT_PADDING, function()
		if activeReloads[tool] == reload then
			Mechanics.Cancel(tool)
		end
	end)

	if not magazine.UseMarkers then
		scheduleByTime()
		return
	end

	task.spawn(function()
		local reloadTrack = track or AnimationTracks.WaitForPlaying(character, config, rig, "Reload")
		if activeReloads[tool] ~= reload then
			return
		end
		if not reloadTrack then
			scheduleByTime()
			return
		end
		for _, stepName in RELOAD_STEPS do
			local signal = reloadTrack:GetMarkerReachedSignal(RELOAD_MARKERS[stepName])
			table.insert(
				reload.connections,
				signal:Connect(function()
					runStep(stepName)
				end)
			)
		end
	end)
end

return Mechanics
