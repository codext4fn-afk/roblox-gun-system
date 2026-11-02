--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local ConfigValidator = {}

local ENUMS = {
	Mode = { Auto = true, Semi = true },
	Style = { Straight = true, RockIn = true, BoltFeed = true },
	Pouch = { Chest = true, Hip = true },
	Rack = { Never = true, Empty = true, Always = true },
}

local ANIMATION_NAMES = { "Hold", "Aim", "Fire", "Reload" }
local MAGAZINE_STEPS = { "Out", "Drop", "Grab", "In" }

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isInteger(value: any): boolean
	return isNumber(value) and value % 1 == 0
end

local function isAnimationId(value: any): boolean
	return type(value) == "string" and (value == "" or string.match(value, "^rbxassetid://%d+$") ~= nil)
end

function ConfigValidator.Validate(config: { [string]: any }): { string }
	local errors: { string } = {}

	local function check(passed: boolean, message: string)
		if not passed then
			table.insert(errors, message)
		end
	end

	local function positive(path: string, value: any)
		check(isNumber(value) and value > 0, `{path} must be a number above 0`)
	end

	local function nonNegative(path: string, value: any)
		check(isNumber(value) and value >= 0, `{path} must be a number of 0 or more`)
	end

	local function fov(path: string, value: any)
		check(isNumber(value) and value > 1 and value < 120, `{path} must be a field of view between 1 and 120`)
	end

	local function oneOf(path: string, value: any, allowed: { [string]: boolean })
		check(type(value) == "string" and allowed[value] == true, `{path} has an unknown value '{tostring(value)}'`)
	end

	check(type(config.Id) == "string" and config.Id ~= "", "Id must be a non-empty string")
	oneOf("Mode", config.Mode, ENUMS.Mode)
	positive("FireInterval", config.FireInterval)
	check(isInteger(config.Pellets) and config.Pellets >= 1, "Pellets must be a whole number of 1 or more")
	check(isInteger(config.MagSize) and config.MagSize >= 1, "MagSize must be a whole number of 1 or more")
	positive("Range", config.Range)
	positive("ReloadTime", config.ReloadTime)
	nonNegative("HipSpread", config.HipSpread)
	nonNegative("AimSpread", config.AimSpread)
	nonNegative("Recoil", config.Recoil)
	nonNegative("AimRecoilMultiplier", config.AimRecoilMultiplier)
	nonNegative("CameraShake", config.CameraShake)
	nonNegative("ArmKick", config.ArmKick)
	positive("AimWalkSpeed", config.AimWalkSpeed)
	positive("AimSensitivity", config.AimSensitivity)
	fov("AimFOV", config.AimFOV)
	fov("FirstPersonFOV", config.FirstPersonFOV)
	fov("ScopeFOV", config.ScopeFOV)

	local damage = config.Damage
	check(type(damage) == "table", "Damage must be a table")
	if type(damage) == "table" then
		for _, zone in { "Head", "Torso", "Limb" } do
			nonNegative(`Damage.{zone}`, damage[zone])
		end
	end

	local magazine = config.Magazine
	check(type(magazine) == "table", "Magazine must be a table")
	if type(magazine) == "table" then
		local previous = 0
		for _, step in MAGAZINE_STEPS do
			local value = magazine[step]
			check(
				isNumber(value) and value >= previous and value <= 1,
				`Magazine.{step} must be a fraction between {previous} and 1, after the step before it`
			)
			if isNumber(value) then
				previous = value
			end
		end
		check(type(magazine.Part) == "string", "Magazine.Part must be a part name")
	end

	local bolt = config.Bolt
	check(type(bolt) == "table", "Bolt must be a table")
	if type(bolt) == "table" then
		check(type(bolt.Part) == "string", "Bolt.Part must be a part name")
		nonNegative("Bolt.Travel", bolt.Travel)
		positive("Bolt.OutTime", bolt.OutTime)
		positive("Bolt.ReturnTime", bolt.ReturnTime)
	end

	local reload = config.Reload
	check(type(reload) == "table", "Reload must be a table")
	if type(reload) == "table" then
		oneOf("Reload.Style", reload.Style, ENUMS.Style)
		oneOf("Reload.Pouch", reload.Pouch, ENUMS.Pouch)
		oneOf("Reload.Rack", reload.Rack, ENUMS.Rack)
		check(type(reload.Prop) == "string", "Reload.Prop must be a string")
	end

	local animations = config.Animations
	check(type(animations) == "table", "Animations must be a table")
	if type(animations) == "table" then
		for _, rig in { "R6", "R15" } do
			local ids = animations[rig]
			check(type(ids) == "table", `Animations.{rig} must be a table`)
			if type(ids) == "table" then
				for _, name in ANIMATION_NAMES do
					check(isAnimationId(ids[name]), `Animations.{rig}.{name} must be "" or "rbxassetid://<number>"`)
				end
			end
		end
	end

	local handling = config.Handling
	check(type(handling) == "table", "Handling must be a table")
	if type(handling) == "table" then
		positive("Handling.DrawTime", handling.DrawTime)
	end

	return errors
end

return ConfigValidator
