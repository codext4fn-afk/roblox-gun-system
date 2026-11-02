--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

export type FireMode = "Auto" | "Semi"
export type HitZone = "Head" | "Torso" | "Limb"
export type RigName = "R6" | "R15"
export type AnimationName = "Hold" | "Aim" | "Fire" | "Reload"
export type ReloadStyle = "Straight" | "RockIn" | "BoltFeed"
export type ReloadPouch = "Chest" | "Hip"
export type RackRule = "Never" | "Empty" | "Always"

export type DamageTable = {
	Head: number,
	Torso: number,
	Limb: number,
}

export type BoltConfig = {
	Part: string,
	Travel: number,
	OutTime: number,
	ReturnTime: number,
}

export type MagazineConfig = {
	Part: string,
	Hand: string,
	GripAttachment: string,
	HoldOffset: CFrame,
	UseMarkers: boolean,
	Out: number,
	Drop: number,
	Grab: number,
	In: number,
	InsertDepth: number,
	SlideTime: number,
	AttachTime: number,
	AlignTime: number,
	SeatTime: number,
	SeatKick: number,
	DropLifetime: number,
}

export type ReloadConfig = {
	Style: ReloadStyle,
	Pouch: ReloadPouch,
	Tap: boolean,
	Rack: RackRule,
	Prop: string,
}

export type AnimationIds = {
	Hold: string,
	Aim: string,
	Fire: string,
	Reload: string,
}

export type HandlingConfig = {
	FirstPersonGrip: Vector3,
	FirstPersonHip: CFrame,
	LowReady: CFrame,
	DrawnDown: CFrame,
	DrawTime: number,
	ReloadTilt: CFrame,
	SprintCarry: CFrame,
	ReloadUsesAnimation: boolean,
}

export type WeaponConfig = {
	Id: string,
	Mode: FireMode,
	FireInterval: number,
	Damage: DamageTable,
	FriendlyFire: boolean,
	Pellets: number,
	Range: number,
	MagSize: number,
	ReloadTime: number,
	HipSpread: number,
	AimSpread: number,
	AimFOV: number,
	FirstPersonFOV: number,
	ScopeFOV: number,
	ScopeOverlay: boolean,
	AimSensitivity: number,
	ShowCrosshair: boolean,
	FirstPersonPushR6: number,
	EyeOffset: Vector3,
	AimWalkSpeed: number,
	Recoil: number,
	AimRecoilMultiplier: number,
	CameraShake: number,
	ArmKick: number,
	EjectCasings: boolean,
	CasingSize: Vector3,
	CasingColor: Color3,
	Bolt: BoltConfig,
	Magazine: MagazineConfig,
	Reload: ReloadConfig,
	Animations: {
		R6: AnimationIds,
		R15: AnimationIds,
	},
	Handling: HandlingConfig,
}

export type WeaponOverrides = {
	Mode: FireMode?,
	FireInterval: number?,
	Damage: { Head: number?, Torso: number?, Limb: number? }?,
	FriendlyFire: boolean?,
	Pellets: number?,
	Range: number?,
	MagSize: number?,
	ReloadTime: number?,
	HipSpread: number?,
	AimSpread: number?,
	AimFOV: number?,
	FirstPersonFOV: number?,
	ScopeFOV: number?,
	ScopeOverlay: boolean?,
	AimSensitivity: number?,
	ShowCrosshair: boolean?,
	FirstPersonPushR6: number?,
	EyeOffset: Vector3?,
	AimWalkSpeed: number?,
	Recoil: number?,
	AimRecoilMultiplier: number?,
	CameraShake: number?,
	ArmKick: number?,
	EjectCasings: boolean?,
	CasingSize: Vector3?,
	CasingColor: Color3?,
	Bolt: {
		Part: string?,
		Travel: number?,
		OutTime: number?,
		ReturnTime: number?,
	}?,
	Magazine: {
		Part: string?,
		Hand: string?,
		GripAttachment: string?,
		HoldOffset: CFrame?,
		UseMarkers: boolean?,
		Out: number?,
		Drop: number?,
		Grab: number?,
		In: number?,
		InsertDepth: number?,
		SlideTime: number?,
		AttachTime: number?,
		AlignTime: number?,
		SeatTime: number?,
		SeatKick: number?,
		DropLifetime: number?,
	}?,
	Reload: {
		Style: ReloadStyle?,
		Pouch: ReloadPouch?,
		Tap: boolean?,
		Rack: RackRule?,
		Prop: string?,
	}?,
	Animations: {
		R6: { Hold: string?, Aim: string?, Fire: string?, Reload: string? }?,
		R15: { Hold: string?, Aim: string?, Fire: string?, Reload: string? }?,
	}?,
	Handling: {
		FirstPersonGrip: Vector3?,
		FirstPersonHip: CFrame?,
		LowReady: CFrame?,
		DrawnDown: CFrame?,
		DrawTime: number?,
		ReloadTilt: CFrame?,
		SprintCarry: CFrame?,
		ReloadUsesAnimation: boolean?,
	}?,
}

export type Pose = {
	pitch: number,
	aim: number,
	armPitch: number,
	armYaw: number,
	armBack: number,
}

export type PoseSolver = {
	NewPose: () -> Pose,
	Apply: (character: Model, pose: Pose) -> (),
	Clear: (character: Model) -> (),
}

return nil
