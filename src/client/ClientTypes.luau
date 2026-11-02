--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("WeaponSystem"):WaitForChild("Types"))

export type View = {
	camera: CFrame,
	firstPerson: boolean,
	zoom: number,
	aimDirection: Vector3,
	sprinting: boolean,
}

export type AimState = {
	pose: Types.Pose,
	tool: Tool?,
	seed: number,
	walk: number,
	phase: number,
	kick: number,
	lastYaw: number?,
	lastArmPitch: number?,
	yawRate: number,
	pitchRate: number,
	turnSway: number,
	turnVelocity: number,
	lookSway: number,
	lookVelocity: number,
	strafe: number,
	strafeVelocity: number,
	surge: number,
	surgeVelocity: number,
	sprint: number,
	alignYaw: number,
	alignPitch: number,
	transientYaw: number,
	transientPitch: number,
}

export type ReloadOptions = {
	onSeated: () -> (),
	chamber: boolean,
	track: AnimationTrack?,
	isTracked: () -> boolean,
	isLocal: boolean,
}

export type Equipped = {
	tool: Tool,
	config: Types.WeaponConfig,
	character: Model,
	humanoid: Humanoid,
	rig: ClientRig,
	params: RaycastParams,
	tracks: { [string]: AnimationTrack },
	walkSpeed: number,
	lastShot: number,
	triggerHeld: boolean,
	aiming: boolean,
	zooming: boolean,
	push: number,
	connections: { RBXScriptConnection },
}

export type ClientRig = {
	Name: Types.RigName,
	Solver: Types.PoseSolver,
	AlignTorso: string,
	ResetOnToolChange: boolean,
	ViewConfig: (config: Types.WeaponConfig) -> Types.WeaponConfig,
	ShowCrosshair: (config: Types.WeaponConfig) -> boolean,
	Compose: (
		character: Model,
		state: AimState,
		tool: Tool,
		config: Types.WeaponConfig,
		deltaTime: number,
		view: View?
	) -> (),
	Stop: (character: Model) -> (),
	LocalFrame: (equipped: Equipped, isFirstPerson: boolean, deltaTime: number) -> (),
	Unequip: (equipped: Equipped) -> (),
	Reload: (character: Model, tool: Tool, config: Types.WeaponConfig, options: ReloadOptions) -> (),
}

return nil
