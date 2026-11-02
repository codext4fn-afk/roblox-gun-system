--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local AngleMath = require(WeaponSystem:WaitForChild("AngleMath"))
local PoseSolverR6 = require(WeaponSystem:WaitForChild("Rig"):WaitForChild("PoseSolverR6"))
local Types = require(WeaponSystem:WaitForChild("Types"))
local WeaponAxes = require(WeaponSystem:WaitForChild("WeaponAxes"))

local ClientTypes = require(script.Parent.Parent.ClientTypes)
local Mechanics = require(script.Parent.Parent.Mechanics)

local SPRINTING_ATTRIBUTE = "Sprinting"
local SPRINT_PITCH = math.rad(-38)
local SPRINT_YAW = math.rad(22)
local SPRINT_ENTER_SPEED = 7
local SPRINT_EXIT_SPEED = 12
local FIRST_PERSON_PUSH_SPEED = 12

local function getRightGrip(equipped: ClientTypes.Equipped): JointInstance?
	local arm = equipped.character:FindFirstChild("Right Arm")
	local weld = arm and arm:FindFirstChild("RightGrip")
	if weld and weld:IsA("JointInstance") and weld.Part1 == WeaponAxes.GetHandle(equipped.tool) then
		return weld
	end
	return nil
end

local R6: ClientTypes.ClientRig = {
	Name = "R6",
	Solver = PoseSolverR6,
	AlignTorso = "Torso",
	ResetOnToolChange = false,
	ViewConfig = function(config: Types.WeaponConfig): Types.WeaponConfig
		return config
	end,
	ShowCrosshair = function(config: Types.WeaponConfig): boolean
		return config.ShowCrosshair
	end,
	Compose = function(
		character: Model,
		state: ClientTypes.AimState,
		_tool: Tool,
		_config: Types.WeaponConfig,
		deltaTime: number,
		_view: ClientTypes.View?
	)
		local sprinting = character:GetAttribute(SPRINTING_ATTRIBUTE) == true
		local sprintRate = if sprinting then SPRINT_ENTER_SPEED else SPRINT_EXIT_SPEED
		state.sprint += ((if sprinting then 1 else 0) - state.sprint) * AngleMath.ExpBlend(deltaTime, sprintRate)
		local pose = state.pose
		pose.armYaw = state.transientYaw + state.alignYaw + SPRINT_YAW * state.sprint
		pose.armPitch = state.transientPitch + state.alignPitch + SPRINT_PITCH * state.sprint
		PoseSolverR6.Apply(character, pose)
	end,
	Stop = function(character: Model)
		PoseSolverR6.Clear(character)
	end,
	LocalFrame = function(equipped: ClientTypes.Equipped, isFirstPerson: boolean, deltaTime: number)
		local push = equipped.config.FirstPersonPushR6
		if push == 0 then
			return
		end
		local target = if isFirstPerson then 1 else 0
		equipped.push += (target - equipped.push) * AngleMath.ExpBlend(deltaTime, FIRST_PERSON_PUSH_SPEED)
		local weld = getRightGrip(equipped)
		if weld then
			local forward = WeaponAxes.ForwardAxis(equipped.tool)
			weld.C1 = CFrame.new(-forward * push * equipped.push) * equipped.tool.Grip
		end
	end,
	Unequip = function(equipped: ClientTypes.Equipped)
		local weld = getRightGrip(equipped)
		if weld then
			weld.C1 = equipped.tool.Grip
		end
	end,
	Reload = function(character: Model, tool: Tool, config: Types.WeaponConfig, options: ClientTypes.ReloadOptions)
		Mechanics.RackDuringReload(tool, config, options.chamber)
		Mechanics.Reload(tool, config, character, "R6", options.track, options.onSeated)
		local track = options.track
		if options.isLocal and track then
			track:Play(0.1)
		end
	end,
}

return R6
