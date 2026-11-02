--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local AngleMath = require(WeaponSystem:WaitForChild("AngleMath"))
local Raycast = require(WeaponSystem:WaitForChild("Raycast"))
local Types = require(WeaponSystem:WaitForChild("Types"))

local ClientTypes = require(script.Parent.Parent.ClientTypes)
local ArmSolver = require(script.Parent.ArmSolver)
local ReloadMotion = require(script.Parent.ReloadMotion)
local WeaponGeometry = require(script.Parent.WeaponGeometry)

type Body = ReloadMotion.Body & {
	shoulders: { Right: Motor6D?, Left: Motor6D? },
}

type RigState = {
	drawn: number,
	firstPerson: number,
	sprint: number,
	obstructed: number,
	reload: ReloadMotion.ReloadMotion?,
	armWeight: number,
	armTrack: AnimationTrack?,
}

local WeaponRig = {}

local EYE_OFFSET = Vector3.new(0.16, 0.08, -0.3)
local SUPPORT_HAND = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, -Vector3.xAxis, Vector3.zAxis)
local OBSTRUCTED = CFrame.new(0.05, -0.22, 0.45) * CFrame.Angles(math.rad(-38), math.rad(18), math.rad(-8))
local OBSTRUCTION_MARGIN = 0.35
local OBSTRUCTION_SPEED = 10
local RELOAD_VIEW = CFrame.new(-0.06, 0.16, -0.2) * CFrame.Angles(math.rad(32), 0, 0)
local REACH_SLACK = 0.04
local RIGHT_POLE = Vector3.new(1.2, -1.1, 0.7)
local LEFT_POLE = Vector3.new(-0.5, -1.6, -0.2)
local FIRST_PERSON_RIGHT_POLE = Vector3.new(1.9, -0.7, 0.2)
local FIRST_PERSON_LEFT_POLE = Vector3.new(-1.8, -0.8, -0.3)
local VIEW_BLEND_SPEED = 14
local ARM_RELEASE_SPEED = 12
local SPRINT_ENTER_SPEED = 7
local SPRINT_EXIT_SPEED = 12
local BOB_VERTICAL = 0.035
local BOB_LATERAL = 0.045
local BOB_ROLL = math.rad(1.6)
local STRAFE_ROLL = math.rad(7)
local STRAFE_YAW = math.rad(2.5)
local STRAFE_LAG = 0.05
local SURGE_PULL = 0.04
local ADS_SWAY_KEEP = 0.25

local IDENTITY = CFrame.new()
local smoothstep = AngleMath.Smoothstep
local expBlend = AngleMath.ExpBlend

local rigs: { [Model]: RigState } = setmetatable({}, { __mode = "k" }) :: any

local function findMotor(character: Model, partName: string, motorName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function solveChild(part0: CFrame, motor: Motor6D): CFrame
	return part0 * motor.C0 * motor.Transform * motor.C1:Inverse()
end

local function getBody(character: Model): Body?
	local root = character:FindFirstChild("HumanoidRootPart")
	local rootJoint = findMotor(character, "LowerTorso", "Root")
	local waist = findMotor(character, "UpperTorso", "Waist")
	local neck = findMotor(character, "Head", "Neck")
	if not (root and root:IsA("BasePart") and rootJoint and waist and neck) then
		return nil
	end
	local lowerTorso = solveChild(root.CFrame, rootJoint)
	local upperTorso = solveChild(lowerTorso, waist)
	return {
		root = root.CFrame,
		lowerTorso = lowerTorso,
		upperTorso = upperTorso,
		head = solveChild(upperTorso, neck),
		shoulders = {
			Right = findMotor(character, "RightUpperArm", "RightShoulder"),
			Left = findMotor(character, "LeftUpperArm", "LeftShoulder"),
		},
	}
end

local function getRig(character: Model): RigState
	local rig = rigs[character]
	if not rig then
		rig = {
			drawn = 0,
			firstPerson = 0,
			sprint = 0,
			obstructed = 0,
			reload = nil,
			armWeight = 1,
			armTrack = nil,
		}
		rigs[character] = rig
	end
	return rig
end

local function aimFrame(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

local function thirdPersonEye(body: Body, aimDirection: Vector3, aim: number, handling: Types.HandlingConfig): CFrame
	local cheekWeld = aimFrame(body.head * EYE_OFFSET, aimDirection)
	local lowReady = body.upperTorso * handling.LowReady
	return lowReady:Lerp(cheekWeld, smoothstep(aim))
end

local function hipEye(camera: CFrame, config: Types.WeaponConfig, tool: Tool, geometry: WeaponGeometry.Geometry): CFrame
	local handling = config.Handling
	local rotation = camera.Rotation * handling.FirstPersonHip.Rotation
	local gripInEye = geometry.eyeFrame:PointToObjectSpace(tool.Grip.Position)
	return CFrame.new(camera * (handling.FirstPersonGrip + handling.FirstPersonHip.Position) - rotation * gripInEye)
		* rotation
end

local function firstPersonEye(
	camera: CFrame,
	config: Types.WeaponConfig,
	zoom: number,
	tool: Tool,
	geometry: WeaponGeometry.Geometry
): CFrame
	local sights = camera * CFrame.new(-config.EyeOffset)
	return hipEye(camera, config, tool, geometry):Lerp(sights, smoothstep(zoom))
end

local function measureObstruction(character: Model, view: ClientTypes.View, reach: number): number
	local length = reach + OBSTRUCTION_MARGIN
	local result =
		workspace:Raycast(view.camera.Position, view.camera.LookVector * length, Raycast.Excluding({ character }))
	if not result then
		return 0
	end
	return math.clamp(1 - result.Distance / length, 0, 1)
end

local function motionOffset(pose: Types.Pose, motion: ClientTypes.AimState, swayScale: number): CFrame
	local phase, walk = motion.phase, motion.walk
	local strafe = motion.strafe * swayScale
	local surge = motion.surge * swayScale
	local bob = CFrame.new(
		math.sin(phase) * BOB_LATERAL * walk - strafe * STRAFE_LAG,
		math.sin(phase * 2) * BOB_VERTICAL * walk,
		pose.armBack + surge * SURGE_PULL
	)
	return bob
		* CFrame.Angles(
			pose.armPitch,
			pose.armYaw - strafe * STRAFE_YAW,
			math.sin(phase) * BOB_ROLL * walk - strafe * STRAFE_ROLL
		)
end

local function reloadTilt(progress: number): number
	return smoothstep(progress / 0.12) * (1 - smoothstep((progress - 0.8) / 0.15))
end

local function palmToHand(hand: BasePart, palmFrame: CFrame): CFrame
	return palmFrame * CFrame.new(-hand.Size.X * 0.42, hand.Size.Y * 0.1, 0)
end

local function supportPalm(
	handle: CFrame,
	geometry: WeaponGeometry.Geometry,
	tool: Tool,
	hand: BasePart
): (CFrame?, CFrame?)
	if geometry.verticalGrip then
		local attachment = hand:FindFirstChild("LeftGripAttachment")
		local gripFrame = CFrame.new(geometry.supportFrame.Position) * tool.Grip.Rotation
		local offset = if attachment and attachment:IsA("Attachment")
			then attachment.CFrame:Inverse()
			else CFrame.identity
		return nil, handle * gripFrame * offset
	end
	return handle * geometry.supportFrame * SUPPORT_HAND, nil
end

local function evaluateLeftHand(
	rig: RigState,
	hand: BasePart,
	handle: CFrame,
	geometry: WeaponGeometry.Geometry,
	body: Body,
	tool: Tool
): CFrame
	local palm, authoredHand = supportPalm(handle, geometry, tool, hand)
	local reload = rig.reload
	if reload then
		return palmToHand(hand, reload:Evaluate(handle, (palm or authoredHand) :: CFrame, body))
	end
	return authoredHand or palmToHand(hand, palm :: CFrame)
end

local function pole(character: Model, shoulderSpace: CFrame, side: ArmSolver.Side, offset: Vector3): Vector3
	local rest = ArmSolver.GetShoulder(character, side)
	return shoulderSpace * ((rest or Vector3.zero) + offset)
end

local SIDES: { ArmSolver.Side } = { "Right", "Left" }

local function reachCorrection(
	character: Model,
	shoulderSpace: CFrame,
	rightTarget: CFrame,
	leftTarget: CFrame
): Vector3
	local shift = Vector3.zero
	for _, side: ArmSolver.Side in SIDES do
		local target = if side == "Right" then rightTarget else leftTarget
		local rest, reach = ArmSolver.GetShoulder(character, side)
		if rest then
			local shoulder = shoulderSpace * rest
			local toHand = target.Position + shift - shoulder
			local excess = toHand.Magnitude - (reach - REACH_SLACK)
			if excess > 0 then
				shift -= toHand.Unit * excess
			end
		end
	end
	return shift
end

local function getPole(character: Model, shoulderSpace: CFrame, side: ArmSolver.Side, viewBlend: number): Vector3
	local default = if side == "Right"
		then RIGHT_POLE:Lerp(FIRST_PERSON_RIGHT_POLE, viewBlend)
		else LEFT_POLE:Lerp(FIRST_PERSON_LEFT_POLE, viewBlend)
	return pole(character, shoulderSpace, side, default)
end

local function advance(
	rig: RigState,
	deltaTime: number,
	view: ClientTypes.View?,
	handling: Types.HandlingConfig,
	obstruction: number
)
	rig.drawn = math.min(rig.drawn + deltaTime / handling.DrawTime, 1)
	local targetView = if view and view.firstPerson then 1 else 0
	rig.firstPerson += (targetView - rig.firstPerson) * expBlend(deltaTime, VIEW_BLEND_SPEED)
	local sprinting = view ~= nil and view.sprinting
	local sprintSpeed = if sprinting then SPRINT_ENTER_SPEED else SPRINT_EXIT_SPEED
	rig.sprint += ((if sprinting then 1 else 0) - rig.sprint) * expBlend(deltaTime, sprintSpeed)
	rig.obstructed += (obstruction - rig.obstructed) * expBlend(deltaTime, OBSTRUCTION_SPEED)
	local reload = rig.reload
	if reload and not reload:Advance(deltaTime) then
		reload:Finish()
		rig.reload = nil
	end
	local track = rig.armTrack
	if track and not track.IsPlaying then
		rig.armTrack = nil
	end
	local targetWeight = if rig.armTrack then 0 else 1
	rig.armWeight += (targetWeight - rig.armWeight) * expBlend(deltaTime, ARM_RELEASE_SPEED)
end

function WeaponRig.Update(
	character: Model,
	tool: Tool,
	config: Types.WeaponConfig,
	pose: Types.Pose,
	motion: ClientTypes.AimState,
	view: ClientTypes.View?,
	deltaTime: number
)
	local geometry = WeaponGeometry.Get(tool, config)
	local body = geometry and getBody(character)
	local rightHand = character:FindFirstChild("RightHand")
	local leftHand = character:FindFirstChild("LeftHand")
	local gripAttachment = rightHand and rightHand:FindFirstChild("RightGripAttachment")
	if
		not (
			geometry
			and body
			and leftHand
			and leftHand:IsA("BasePart")
			and gripAttachment
			and gripAttachment:IsA("Attachment")
			and body.shoulders.Right
			and body.shoulders.Left
		)
	then
		return
	end
	local handling = config.Handling
	local rig = getRig(character)
	local obstruction = if view and view.firstPerson then measureObstruction(character, view, geometry.reach) else 0
	advance(rig, deltaTime, view, handling, obstruction)

	local aimDirection = if view then view.aimDirection else (body.root * CFrame.Angles(pose.pitch, 0, 0)).LookVector
	local eye = thirdPersonEye(body, aimDirection, pose.aim, handling)
	if view and rig.firstPerson > 1e-3 then
		eye = eye:Lerp(firstPersonEye(view.camera, config, view.zoom, tool, geometry), smoothstep(rig.firstPerson))
	end
	local swayScale = if view then 1 + (ADS_SWAY_KEEP - 1) * smoothstep(view.zoom) else 1
	eye *= motionOffset(pose, motion, swayScale)
	if rig.sprint > 1e-3 then
		eye *= IDENTITY:Lerp(handling.SprintCarry, smoothstep(rig.sprint))
	end
	local reload = rig.reload
	if reload then
		local tilt = reloadTilt(reload.progress)
		if view then
			eye *= IDENTITY:Lerp(RELOAD_VIEW, tilt * smoothstep(rig.firstPerson))
		end
		eye *= IDENTITY:Lerp(handling.ReloadTilt, tilt)
	end
	if rig.obstructed > 1e-3 then
		eye *= IDENTITY:Lerp(OBSTRUCTED, smoothstep(rig.obstructed))
	end
	eye = (eye * handling.DrawnDown):Lerp(eye, smoothstep(rig.drawn))

	local shoulderSpace = body.upperTorso
	local function placeHands(handle: CFrame): (CFrame, CFrame)
		local right = handle * tool.Grip * gripAttachment.CFrame:Inverse()
		return right, evaluateLeftHand(rig, leftHand, handle, geometry, body, tool)
	end
	local handle = eye * geometry.eyeFrame:Inverse()
	local rightTarget, leftTarget = placeHands(handle)
	if view and rig.firstPerson > 1e-3 then
		local weight = smoothstep(rig.firstPerson) * (1 - smoothstep(view.zoom))
		local shift = reachCorrection(character, shoulderSpace, rightTarget, leftTarget) * weight
		if shift.Magnitude > 1e-4 then
			handle += shift
			rightTarget, leftTarget = placeHands(handle)
		end
	end

	local viewBlend = if view then smoothstep(rig.firstPerson) else 0
	local rightPole = getPole(character, shoulderSpace, "Right", viewBlend)
	local leftPole = getPole(character, shoulderSpace, "Left", viewBlend)
	ArmSolver.Solve(character, "Right", body.upperTorso, rightTarget, rightPole, rig.armWeight, shoulderSpace)
	ArmSolver.Solve(character, "Left", body.upperTorso, leftTarget, leftPole, rig.armWeight, shoulderSpace)
end

function WeaponRig.StartReload(character: Model, tool: Tool, config: Types.WeaponConfig, options: ReloadMotion.Options)
	local rig = getRig(character)
	local reload = rig.reload
	if reload then
		reload:Finish()
	end
	rig.reload = ReloadMotion.new(tool, config, options)
end

function WeaponRig.ReleaseArms(character: Model, track: AnimationTrack)
	getRig(character).armTrack = track
end

function WeaponRig.Stop(character: Model)
	local rig = rigs[character]
	local reload = rig and rig.reload
	if reload then
		reload:Finish()
	end
	rigs[character] = nil
	ArmSolver.Reset(character)
end

return WeaponRig
