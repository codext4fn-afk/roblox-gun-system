--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local Types = require(script.Parent.Parent.Types)

local config: Types.WeaponOverrides = {
	Mode = "Auto",
	FireInterval = 60 / 600,
	Damage = { Head = 55, Torso = 27, Limb = 18 },
	Range = 800,
	MagSize = 30,
	ReloadTime = 2.4,
	HipSpread = 2.5,
	AimSpread = 0.4,
	AimFOV = 50,
	ScopeFOV = 40,
	AimWalkSpeed = 10,
	Recoil = 0.35,
	Reload = { Style = "RockIn", Pouch = "Chest", Rack = "Empty" },
	Handling = {
		SprintCarry = CFrame.new(-0.3, -0.62, -0.25) * CFrame.Angles(math.rad(42), math.rad(16), math.rad(14)),
	},
}

return config
