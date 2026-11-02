--!strict
local Types = require(script.Parent.Parent.Types)

local config: Types.WeaponOverrides = {
	Mode = "Auto",
	FireInterval = 60 / 500,
	Damage = { Head = 55, Torso = 35, Limb = 21 },
	Range = 900,
	MagSize = 20,
	ReloadTime = 2.6,
	HipSpread = 2.2,
	AimSpread = 0.35,
	AimFOV = 48,
	AimWalkSpeed = 10,
	Recoil = 0.5,
	CameraShake = 0.45,
	ArmKick = 0.75,
	Handling = {
		SprintCarry = CFrame.new(-0.3, -0.62, -0.25) * CFrame.Angles(math.rad(42), math.rad(16), math.rad(14)),
		LowReady = CFrame.new(0.35, 0.2, -0.5) * CFrame.Angles(math.rad(-38), math.rad(20), math.rad(-12)),
		DrawTime = 0.38,
		ReloadTilt = CFrame.new(-0.06, 0.03, 0.1) * CFrame.Angles(math.rad(8), math.rad(10), math.rad(-30)),
	},
	Reload = { Style = "Straight", Pouch = "Hip", Tap = true, Rack = "Empty", Prop = "RifleMagazine" },
}

return config
