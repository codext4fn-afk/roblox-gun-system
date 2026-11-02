--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local fs = require("@lune/fs")

type Expected = {
	FireInterval: number,
	Head: number,
	Torso: number,
	Limb: number,
	MagSize: number,
	ReloadTime: number,
	HipSpread: number,
	AimSpread: number,
	Recoil: number,
	Range: number,
}

local SHIPPED: { [string]: Expected } = {
	AK = {
		FireInterval = 60 / 600,
		Head = 55,
		Torso = 27,
		Limb = 18,
		MagSize = 30,
		ReloadTime = 2.4,
		HipSpread = 2.5,
		AimSpread = 0.4,
		Recoil = 0.35,
		Range = 800,
	},
	SCAR = {
		FireInterval = 60 / 500,
		Head = 55,
		Torso = 35,
		Limb = 21,
		MagSize = 20,
		ReloadTime = 2.6,
		HipSpread = 2.2,
		AimSpread = 0.35,
		Recoil = 0.5,
		Range = 900,
	},
	URGI = {
		FireInterval = 60 / 820,
		Head = 48,
		Torso = 24,
		Limb = 16,
		MagSize = 30,
		ReloadTime = 2.15,
		HipSpread = 2.0,
		AimSpread = 0.3,
		Recoil = 0.24,
		Range = 700,
	},
	FNIWS = {
		FireInterval = 60 / 620,
		Head = 62,
		Torso = 33,
		Limb = 22,
		MagSize = 20,
		ReloadTime = 2.65,
		HipSpread = 2.8,
		AimSpread = 0.32,
		Recoil = 0.48,
		Range = 950,
	},
	M16A1 = {
		FireInterval = 60 / 600,
		Head = 52,
		Torso = 26,
		Limb = 17,
		MagSize = 20,
		ReloadTime = 2.3,
		HipSpread = 2.6,
		AimSpread = 0.35,
		Recoil = 0.3,
		Range = 850,
	},
	TRex = {
		FireInterval = 0.9,
		Head = 250,
		Torso = 150,
		Limb = 95,
		MagSize = 5,
		ReloadTime = 3.6,
		HipSpread = 6,
		AimSpread = 0.05,
		Recoil = 3.2,
		Range = 2000,
	},
}

return function(test, expect, load)
	local ConfigMerge = load("shared/ConfigMerge")
	local ConfigValidator = load("shared/ConfigValidator")
	local Defaults = load("shared/Defaults")

	local function build(id: string): { [string]: any }
		local merged = ConfigMerge.Merge(Defaults, load(`shared/Configs/{id}`))
		merged.Id = id
		return merged
	end

	test("every config file has an expected entry", function()
		for _, file in fs.readDir("src/shared/Configs") do
			local id = string.gsub(file, "%.luau$", "")
			expect(SHIPPED[id] ~= nil).toBeTruthy()
		end
	end)

	for id, expected in SHIPPED do
		test(`{id} merges over defaults and validates`, function()
			local config = build(id)
			local errors = ConfigValidator.Validate(config)
			expect(#errors).toBe(0)
			expect(#ConfigMerge.UnknownKeys(Defaults, load(`shared/Configs/{id}`))).toBe(0)
		end)

		test(`{id} keeps its tuned gameplay values`, function()
			local config = build(id)
			expect(config.FireInterval).toBeNear(expected.FireInterval)
			expect(config.Damage.Head).toBe(expected.Head)
			expect(config.Damage.Torso).toBe(expected.Torso)
			expect(config.Damage.Limb).toBe(expected.Limb)
			expect(config.MagSize).toBe(expected.MagSize)
			expect(config.ReloadTime).toBeNear(expected.ReloadTime)
			expect(config.HipSpread).toBeNear(expected.HipSpread)
			expect(config.AimSpread).toBeNear(expected.AimSpread)
			expect(config.Recoil).toBeNear(expected.Recoil)
			expect(config.Range).toBe(expected.Range)
			expect(config.AimRecoilMultiplier).toBeNear(0.6)
		end)
	end
end
