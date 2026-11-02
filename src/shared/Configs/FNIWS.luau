--!strict
local Types = require(script.Parent.Parent.Types)

local config: Types.WeaponOverrides = {
	Mode = "Auto",
	FireInterval = 60 / 620,
	Damage = { Head = 62, Torso = 33, Limb = 22 },
	Range = 950,
	MagSize = 20,
	ReloadTime = 2.65,
	HipSpread = 2.8,
	AimSpread = 0.32,
	AimFOV = 48,
	ScopeFOV = 36,
	AimWalkSpeed = 9,
	Recoil = 0.48,
	CameraShake = 0.42,
	ArmKick = 0.7,
	Bolt = { Part = "Bolt", Travel = 0.3 },
	Magazine = { Out = 0.1, Drop = 0.32, Grab = 0.5, In = 0.66, InsertDepth = 0.4 },
	Handling = {
		LowReady = CFrame.new(0.25, 0.05, -0.35) * CFrame.Angles(math.rad(-48), math.rad(16), math.rad(-6)),
		DrawTime = 0.42,
		ReloadTilt = CFrame.new(-0.06, 0.02, 0.14) * CFrame.Angles(math.rad(6), math.rad(16), math.rad(-26)),
	},
	Reload = { Style = "Straight", Pouch = "Hip", Rack = "Always" },
}

return config
