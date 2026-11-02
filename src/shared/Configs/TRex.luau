--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Types = require(script.Parent.Parent.Types)

local config: Types.WeaponOverrides = {
	Mode = "Semi",
	FireInterval = 0.9,
	Damage = { Head = 250, Torso = 150, Limb = 95 },
	Range = 2000,
	MagSize = 5,
	ReloadTime = 3.6,
	HipSpread = 6,
	AimSpread = 0.05,
	AimFOV = 42,
	FirstPersonFOV = 60,
	ScopeFOV = 12,
	ScopeOverlay = true,
	AimSensitivity = 0.3,
	EyeOffset = Vector3.new(0, 0, 0.45),
	ShowCrosshair = false,
	FirstPersonPushR6 = 1.1,
	AimWalkSpeed = 6,
	Recoil = 3.2,
	CameraShake = 1.6,
	ArmKick = 1.5,
	CasingSize = Vector3.new(0.42, 0.13, 0.13),
	Bolt = { Part = "Bolt", Travel = 0.7, OutTime = 0.06, ReturnTime = 0.14 },
	Magazine = { Out = 0.1, Drop = 0.3, Grab = 0.5, In = 0.68, InsertDepth = 0.5, SeatKick = 0.6 },
	Handling = {
		FirstPersonHip = CFrame.new(0.02, -0.04, -0.85) * CFrame.Angles(0, math.rad(2.5), 0),
		LowReady = CFrame.new(0.45, -0.25, -0.2) * CFrame.Angles(math.rad(-25), math.rad(22), math.rad(-4)),
		DrawnDown = CFrame.new(0.2, -1.1, 0.6) * CFrame.Angles(math.rad(-50), math.rad(20), math.rad(-15)),
		DrawTime = 0.75,
		SprintCarry = CFrame.new(-0.05, -0.3, 0.3) * CFrame.Angles(math.rad(10), math.rad(45), math.rad(12)),
		ReloadTilt = CFrame.new(0.04, 0.02, 0.16) * CFrame.Angles(math.rad(6), math.rad(-10), math.rad(24)),
	},
	Reload = { Style = "BoltFeed", Pouch = "Hip", Prop = "HeavyRounds" },
}

return config
