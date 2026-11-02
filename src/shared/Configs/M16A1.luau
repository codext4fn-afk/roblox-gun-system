--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Types = require(script.Parent.Parent.Types)

local config: Types.WeaponOverrides = {
	Mode = "Auto",
	FireInterval = 60 / 600,
	Damage = { Head = 52, Torso = 26, Limb = 17 },
	Range = 850,
	MagSize = 20,
	ReloadTime = 2.3,
	HipSpread = 2.6,
	AimSpread = 0.35,
	AimFOV = 50,
	ScopeFOV = 38,
	AimWalkSpeed = 10,
	Recoil = 0.3,
	CameraShake = 0.3,
	ArmKick = 0.5,
	Bolt = { Part = "Bolt", Travel = 0.35 },
	Magazine = { Out = 0.09, Drop = 0.3, Grab = 0.45, In = 0.62 },
	Handling = {
		SprintCarry = CFrame.new(-0.3, -0.62, -0.25) * CFrame.Angles(math.rad(42), math.rad(16), math.rad(14)),
		LowReady = CFrame.new(0.35, 0.15, -0.55) * CFrame.Angles(math.rad(-40), math.rad(30), math.rad(-10)),
		DrawTime = 0.4,
		ReloadTilt = CFrame.new(-0.05, 0.05, 0.12) * CFrame.Angles(math.rad(12), math.rad(14), math.rad(-36)),
	},
	Reload = { Style = "Straight", Pouch = "Chest", Tap = true, Rack = "Empty" },
}

return config
