--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local PoseSolverR15 = require(WeaponSystem:WaitForChild("Rig"):WaitForChild("PoseSolverR15"))
local Settings = require(WeaponSystem:WaitForChild("Settings"))
local Spring = require(WeaponSystem:WaitForChild("Spring"))
local Types = require(WeaponSystem:WaitForChild("Types"))

local AnimationTracks = require(script.Parent.Parent.AnimationTracks)
local ClientTypes = require(script.Parent.Parent.ClientTypes)
local Mechanics = require(script.Parent.Parent.Mechanics)
local WeaponRig = require(script.Parent.Parent.R15.WeaponRig)

local MOVE_SWAY_REFERENCE_SPEED = 10

local function getGroundVelocity(character: Model): Vector3
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) or humanoid.FloorMaterial == Enum.Material.Air then
		return Vector3.zero
	end
	local velocity = root.AssemblyLinearVelocity
	if Vector3.new(velocity.X, 0, velocity.Z).Magnitude <= 0 then
		return Vector3.zero
	end
	return root.CFrame:VectorToObjectSpace(velocity) / MOVE_SWAY_REFERENCE_SPEED
end

local function updateMoveSway(character: Model, state: ClientTypes.AimState, deltaTime: number)
	local localVelocity = getGroundVelocity(character)
	local strafeTarget = math.clamp(localVelocity.X, -1, 1)
	local surgeTarget = math.clamp(-localVelocity.Z, -1, 1)
	state.strafe, state.strafeVelocity =
		Spring.Step(state.strafe, state.strafeVelocity, strafeTarget, deltaTime, Spring.Sway)
	state.surge, state.surgeVelocity =
		Spring.Step(state.surge, state.surgeVelocity, surgeTarget, deltaTime, Spring.Sway)
end

local R15: ClientTypes.ClientRig = {
	Name = "R15",
	Solver = PoseSolverR15,
	AlignTorso = "UpperTorso",
	ResetOnToolChange = true,
	ViewConfig = function(config: Types.WeaponConfig): Types.WeaponConfig
		local view = table.clone(config)
		view.FirstPersonFOV = Settings.R15.FirstPersonFOV
		return view
	end,
	ShowCrosshair = function(config: Types.WeaponConfig): boolean
		return Settings.R15.ShowCrosshair and config.ShowCrosshair
	end,
	Compose = function(
		character: Model,
		state: ClientTypes.AimState,
		tool: Tool,
		config: Types.WeaponConfig,
		deltaTime: number,
		view: ClientTypes.View?
	)
		updateMoveSway(character, state, deltaTime)
		local pose = state.pose
		pose.armYaw = state.transientYaw + state.alignYaw
		pose.armPitch = state.transientPitch + state.alignPitch
		PoseSolverR15.Apply(character, pose)
		WeaponRig.Update(character, tool, config, pose, state, view, deltaTime)
	end,
	Stop = function(character: Model)
		PoseSolverR15.Clear(character)
		WeaponRig.Stop(character)
	end,
	LocalFrame = function(_equipped: ClientTypes.Equipped, _isFirstPerson: boolean, _deltaTime: number) end,
	Unequip = function(_equipped: ClientTypes.Equipped) end,
	Reload = function(character: Model, tool: Tool, config: Types.WeaponConfig, options: ClientTypes.ReloadOptions)
		local usesAnimation = config.Handling.ReloadUsesAnimation
		if options.isLocal then
			local track = options.track
			if track then
				track:Play(0.1)
			end
			if usesAnimation and track then
				Mechanics.Reload(tool, config, character, "R15", track, options.onSeated)
				if options.isTracked() then
					WeaponRig.ReleaseArms(character, track)
				end
			elseif options.isTracked() then
				WeaponRig.StartReload(
					character,
					tool,
					config,
					{ onSeated = options.onSeated, chamber = options.chamber }
				)
			end
			return
		end
		if not usesAnimation then
			if options.isTracked() then
				WeaponRig.StartReload(character, tool, config, { onSeated = options.onSeated })
			end
			return
		end
		task.spawn(function()
			local track = AnimationTracks.WaitForPlaying(character, config, "R15", "Reload")
			if track and options.isTracked() then
				WeaponRig.ReleaseArms(character, track)
			end
			Mechanics.Reload(tool, config, character, "R15", track, options.onSeated)
		end)
	end,
}

return R15
