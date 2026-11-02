--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

export type ActionName = "Fire" | "Aim" | "Reload" | "SwitchShoulder"

export type TouchButton = {
	Title: string,
	Position: UDim2,
	Toggle: boolean,
}

export type Binding = Enum.UserInputType | Enum.KeyCode

local Types = require(script.Parent.Types)

local controls: { [ActionName]: { Binding } } = {
	Fire = { Enum.UserInputType.MouseButton1 :: Binding, Enum.KeyCode.ButtonR2 :: Binding },
	Aim = { Enum.UserInputType.MouseButton2 :: Binding, Enum.KeyCode.ButtonL2 :: Binding },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX },
	SwitchShoulder = { Enum.KeyCode.Q, Enum.KeyCode.DPadRight },
}

local touch: { [ActionName]: TouchButton } = {
	Fire = { Title = "Fire", Position = UDim2.new(1, -95, 1, -170), Toggle = false },
	Aim = { Title = "Aim", Position = UDim2.new(1, -170, 1, -95), Toggle = true },
	Reload = { Title = "Reload", Position = UDim2.new(1, -95, 1, -245), Toggle = false },
	SwitchShoulder = { Title = "Swap", Position = UDim2.new(1, -170, 1, -245), Toggle = false },
}

local sharedAnimations: { [Types.RigName]: Types.AnimationIds } = {
	R6 = {
		Hold = "rbxassetid://114270828340458",
		Aim = "rbxassetid://118899500324432",
		Fire = "",
		Reload = "rbxassetid://107321042976212",
	},
	R15 = { Hold = "", Aim = "", Fire = "", Reload = "" },
}

local Settings = {
	Server = {
		MaxOriginOffset = 6,
		FireRateBurst = 1.15,
		SpreadTolerance = 1.5,
		MaxPitch = math.rad(80),
		ReplicateDistance = 300,
		CreatorTagLifetime = 2,
		HumanoidWait = 5,
		PoseSmoothing = 15,
		RequestIntervals = {
			Reload = 0.3,
			SetAiming = 1 / 20,
			AimPitch = 1 / 30,
		},
	},
	SharedAnimations = sharedAnimations,
	R15 = {
		WeaponScale = 0.72,
		EyeRelief = 0.8,
		FirstPersonFOV = 80,
		ShowCrosshair = false,
	},
	Controls = controls,
	Touch = touch,
	Effects = {
		BulletSpeed = 1100,
		StreakLength = 5,
		MaxBullets = 64,
		MaxHoles = 40,
		HoleLifetime = 8,
		HoleFadeTime = 1,
		MaxCasings = 24,
		CasingLifetime = 2.5,
		TracerColor = Color3.fromRGB(255, 220, 150),
		FlashColor = Color3.fromRGB(255, 180, 80),
	},
	Camera = {
		ShoulderOffset = Vector3.new(1.75, 0.35, 0),
		ZoomSpeed = 12,
		RecoilRecovery = 14,
		RecoilSideways = 0.25,
		ShakeRecovery = 10,
		ShakeFrequency = 25,
		ShakeMax = 3,
	},
}

return Settings
