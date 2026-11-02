--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Types = require(script.Parent.Parent.Types)

local config: Types.WeaponOverrides = {
	Mode = "Auto",
	FireInterval = 60 / 820,
	Damage = { Head = 48, Torso = 24, Limb = 16 },
	Range = 700,
	MagSize = 30,
	ReloadTime = 2.15,
	HipSpread = 2.0,
	AimSpread = 0.3,
	AimFOV = 52,
	ScopeFOV = 40,
	AimWalkSpeed = 11,
	Recoil = 0.24,
	CameraShake = 0.2,
	ArmKick = 0.4,
	Bolt = { Part = "Bolt", Travel = 0.35 },
	Magazine = { Out = 0.07, Drop = 0.28, Grab = 0.42, In = 0.58 },
	Handling = {
		FirstPersonHip = CFrame.new(0.03, -0.06, -0.6) * CFrame.Angles(0, math.rad(2.5), 0),
		SprintCarry = CFrame.new(-0.3, -0.62, -0.25) * CFrame.Angles(math.rad(42), math.rad(16), math.rad(14)),
		LowReady = CFrame.new(0.3, 0.45, -0.5) * CFrame.Angles(math.rad(18), math.rad(18), math.rad(-8)),
		DrawTime = 0.28,
		ReloadTilt = CFrame.new(-0.08, 0.05, 0.1) * CFrame.Angles(math.rad(14), math.rad(8), math.rad(-40)),
	},
	Reload = { Style = "Straight", Pouch = "Chest", Tap = true, Rack = "Empty" },
}

return config
