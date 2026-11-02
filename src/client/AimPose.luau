--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local AngleMath = require(WeaponSystem:WaitForChild("AngleMath"))
local Remotes = require(WeaponSystem:WaitForChild("Remotes"))
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Spring = require(WeaponSystem:WaitForChild("Spring"))
local WeaponRegistry = require(WeaponSystem:WaitForChild("WeaponRegistry"))

local Camera = require(script.Parent.Camera)
local ClientTypes = require(script.Parent.ClientTypes)
local Rigs = require(script.Parent.Rigs)

local player = Players.LocalPlayer

local AimPose = {}

type Entry = {
	state: ClientTypes.AimState,
	rig: ClientTypes.ClientRig,
}

local POSE_BIND_NAME = "GunAimPose"
local POSE_PRIORITY = Enum.RenderPriority.Camera.Value + 3
local MAX_DELTA = 0.1
local REMOTE_SMOOTHING = 15
local SEND_INTERVAL = 1 / 15
local SEND_THRESHOLD = math.rad(0.5)
local SEND_HEARTBEAT = 0.5

local WALK_REFERENCE_SPEED = 16
local WALK_MAX_SCALE = 1.6
local WALK_RATE = 0.3
local WALK_SWAY = math.rad(2.5)
local WALK_BLEND = 8
local AIM_STEADINESS = 0.3

local IDLE_SWAY = math.rad(0.6)
local IDLE_SPEED = 0.35

local KICK_BACK = 0.15
local KICK_PITCH = math.rad(5)
local KICK_RECOVERY = 18
local KICK_MAX = 1.5

local TURN_SWAY = 0.012
local TURN_SWAY_MAX = math.rad(4)
local LOOK_SWAY = 0.01
local LOOK_SWAY_MAX = math.rad(3)
local RATE_SMOOTHING = 20

local ALIGN_SPEED = 12
local ALIGN_MAX = math.rad(25)

local SPRINTING_ATTRIBUTE = "Sprinting"

local lerp = AngleMath.Lerp
local expBlend = AngleMath.ExpBlend

local tracked: { [Model]: Entry } = {}
local localAim = 0
local lastSendTime, lastSentPitch = 0, 0
local rng = Random.new()
local started = false

local function newState(entry: ClientTypes.ClientRig, tool: Tool): ClientTypes.AimState
	return {
		pose = entry.Solver.NewPose(),
		tool = tool,
		seed = rng:NextNumber(0, 1000),
		walk = 0,
		phase = 0,
		kick = 0,
		lastYaw = nil,
		lastArmPitch = nil,
		yawRate = 0,
		pitchRate = 0,
		turnSway = 0,
		turnVelocity = 0,
		lookSway = 0,
		lookVelocity = 0,
		strafe = 0,
		strafeVelocity = 0,
		surge = 0,
		surgeVelocity = 0,
		sprint = 0,
		alignYaw = 0,
		alignPitch = 0,
		transientYaw = 0,
		transientPitch = 0,
	}
end

local function stopTracking(character: Model)
	local entry = tracked[character]
	if entry then
		tracked[character] = nil
		entry.rig.Stop(character)
	end
end

local function refreshTracking(character: Model)
	local tool = WeaponRegistry.GetEquipped(character)
	local entry = tracked[character]
	if entry then
		if tool and (entry.state.tool == tool or not entry.rig.ResetOnToolChange) then
			entry.state.tool = tool
			return
		end
		stopTracking(character)
	end
	local rig = Rigs.Get(character)
	if tool and rig then
		tracked[character] = { state = newState(rig, tool), rig = rig }
	end
end

local function watchCharacter(character: Model)
	refreshTracking(character)
	local function onToolChanged(child: Instance)
		if child:IsA("Tool") then
			refreshTracking(character)
		end
	end
	character.ChildAdded:Connect(onToolChanged)
	character.ChildRemoved:Connect(onToolChanged)
end

local function watchPlayer(otherPlayer: Player)
	otherPlayer.CharacterAdded:Connect(watchCharacter)
	otherPlayer.CharacterRemoving:Connect(stopTracking)
	if otherPlayer.Character then
		watchCharacter(otherPlayer.Character)
	end
end

local function getCameraPitch(): number
	local pitch = AngleMath.PitchOf(workspace.CurrentCamera.CFrame.LookVector)
	return math.clamp(pitch, -Settings.Server.MaxPitch, Settings.Server.MaxPitch)
end

local function getRootYaw(character: Model): number?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then AngleMath.YawOf(root.CFrame.LookVector) else nil
end

local function getGroundSpeed(character: Model): number
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) or humanoid.FloorMaterial == Enum.Material.Air then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function updateAimInputs(character: Model, state: ClientTypes.AimState, remoteBlend: number)
	local pose = state.pose
	if character == player.Character then
		pose.pitch = getCameraPitch()
		pose.aim = localAim
	else
		local pitch = character:GetAttribute("AimPitch")
		local targetPitch = if type(pitch) == "number" then pitch else 0
		local targetAim = if character:GetAttribute("Aiming") == true then 1 else 0
		pose.pitch = lerp(pose.pitch, targetPitch, remoteBlend)
		pose.aim = lerp(pose.aim, targetAim, remoteBlend)
	end
end

local function updateWalkAndIdle(
	character: Model,
	state: ClientTypes.AimState,
	deltaTime: number,
	walkBlend: number,
	now: number
): (number, number)
	local steadiness = lerp(1, AIM_STEADINESS, state.pose.aim)
	local speed = getGroundSpeed(character)
	local targetWalk = math.clamp(speed / WALK_REFERENCE_SPEED, 0, WALK_MAX_SCALE) * steadiness
	state.walk = lerp(state.walk, targetWalk, walkBlend)
	state.phase = (state.phase + deltaTime * speed * WALK_RATE) % (math.pi * 2)

	local walkPitch = math.sin(state.phase) * WALK_SWAY * state.walk
	local idleAmount = IDLE_SWAY * steadiness * math.max(0, 1 - state.walk)
	local idleYaw = math.noise(now * IDLE_SPEED, state.seed) * 2 * idleAmount
	local idlePitch = math.noise(now * IDLE_SPEED, state.seed + 17.3) * 2 * idleAmount
	return walkPitch + idlePitch, idleYaw
end

local function updateSprings(character: Model, state: ClientTypes.AimState, deltaTime: number)
	local yaw = getRootYaw(character)
	local armPitch = state.pose.pitch * state.pose.aim
	local lastYaw, lastArmPitch = state.lastYaw, state.lastArmPitch
	local rawYawRate = if yaw and lastYaw then AngleMath.WrapAngle(yaw - lastYaw) / deltaTime else 0
	local rawPitchRate = if lastArmPitch then (armPitch - lastArmPitch) / deltaTime else 0
	state.lastYaw, state.lastArmPitch = yaw, armPitch

	local rateBlend = expBlend(deltaTime, RATE_SMOOTHING)
	state.yawRate = lerp(state.yawRate, rawYawRate, rateBlend)
	state.pitchRate = lerp(state.pitchRate, rawPitchRate, rateBlend)

	local turnTarget = math.clamp(-state.yawRate * TURN_SWAY, -TURN_SWAY_MAX, TURN_SWAY_MAX)
	local lookTarget = math.clamp(-state.pitchRate * LOOK_SWAY, -LOOK_SWAY_MAX, LOOK_SWAY_MAX)
	state.turnSway, state.turnVelocity =
		Spring.Step(state.turnSway, state.turnVelocity, turnTarget, deltaTime, Spring.Sway)
	state.lookSway, state.lookVelocity =
		Spring.Step(state.lookSway, state.lookVelocity, lookTarget, deltaTime, Spring.Sway)
end

local function sendLocalPitch()
	local character = player.Character
	local entry = character and tracked[character]
	if not entry then
		return
	end
	local pitch = entry.state.pose.pitch
	local now = os.clock()
	local elapsed = now - lastSendTime
	if elapsed < SEND_INTERVAL then
		return
	end
	if math.abs(pitch - lastSentPitch) < SEND_THRESHOLD and elapsed < SEND_HEARTBEAT then
		return
	end
	lastSendTime, lastSentPitch = now, pitch
	Remotes.AimPitch:FireServer(pitch)
end

local function getLocalView(character: Model): ClientTypes.View
	local camera = workspace.CurrentCamera.CFrame
	return {
		camera = camera,
		firstPerson = Camera.IsFirstPerson(),
		zoom = Camera.GetAimAlpha(),
		aimDirection = camera.LookVector,
		sprinting = character:GetAttribute(SPRINTING_ATTRIBUTE) == true,
	}
end

local function update(rawDeltaTime: number)
	local deltaTime = math.min(rawDeltaTime, MAX_DELTA)
	if deltaTime <= 0 then
		return
	end
	local remoteBlend = expBlend(deltaTime, REMOTE_SMOOTHING)
	local walkBlend = expBlend(deltaTime, WALK_BLEND)
	local kickDecay = math.exp(-deltaTime * KICK_RECOVERY)
	local now = os.clock()

	for character, entry in tracked do
		local tool, config = WeaponRegistry.GetEquipped(character)
		local state = entry.state
		if not character.Parent or not tool or not config then
			stopTracking(character)
			continue
		end
		if entry.rig.ResetOnToolChange and tool ~= state.tool then
			stopTracking(character)
			continue
		end
		updateAimInputs(character, state, remoteBlend)
		local motionPitch, motionYaw = updateWalkAndIdle(character, state, deltaTime, walkBlend, now)
		updateSprings(character, state, deltaTime)
		state.kick *= kickDecay

		state.transientYaw = motionYaw + state.turnSway
		state.transientPitch = motionPitch + state.lookSway + state.kick * KICK_PITCH
		state.pose.armBack = state.kick * KICK_BACK

		local view = if character == player.Character then getLocalView(character) else nil
		entry.rig.Compose(character, state, tool, config, deltaTime, view)
	end

	sendLocalPitch()
end

function AimPose.Start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watchPlayer)
	for _, otherPlayer in Players:GetPlayers() do
		watchPlayer(otherPlayer)
	end
	RunService:BindToRenderStep(POSE_BIND_NAME, POSE_PRIORITY, update)
end

function AimPose.IsTracked(character: Model): boolean
	return tracked[character] ~= nil
end

function AimPose.Kick(character: Model?, strength: number)
	local entry = character and tracked[character]
	if entry and strength > 0 then
		entry.state.kick = math.min(entry.state.kick + strength, KICK_MAX)
	end
end

function AimPose.Align(errorYaw: number, errorPitch: number, deltaTime: number)
	local character = player.Character
	local entry = character and tracked[character]
	if not entry then
		return
	end
	local state = entry.state
	local blend = math.min(1, ALIGN_SPEED * deltaTime)
	state.alignYaw = math.clamp(state.alignYaw + (errorYaw + state.transientYaw) * blend, -ALIGN_MAX, ALIGN_MAX)
	state.alignPitch = math.clamp(state.alignPitch + (errorPitch + state.transientPitch) * blend, -ALIGN_MAX, ALIGN_MAX)
end

function AimPose.ClearAlign(deltaTime: number)
	local character = player.Character
	local entry = character and tracked[character]
	if not entry then
		return
	end
	local decay = math.exp(-deltaTime * ALIGN_SPEED)
	entry.state.alignYaw *= decay
	entry.state.alignPitch *= decay
end

function AimPose.SetLocalAim(alpha: number)
	localAim = alpha
end

return AimPose
