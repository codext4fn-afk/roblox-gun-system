--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local ShotValidator = {}

export type Rejection =
	"OriginNotVector"
	| "AimNotDirection"
	| "DirectionsNotList"
	| "TooManyPellets"
	| "NoPellets"
	| "OriginTooFar"

local MIN_DIRECTION_MAGNITUDE = 0.5

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function ShotValidator.IsFiniteVector(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local vector = value :: Vector3
	return isFinite(vector.X) and isFinite(vector.Y) and isFinite(vector.Z)
end

function ShotValidator.IsDirection(value: unknown): boolean
	return ShotValidator.IsFiniteVector(value) and (value :: Vector3).Magnitude > MIN_DIRECTION_MAGNITUDE
end

function ShotValidator.CheckArguments(
	origin: unknown,
	aimDirection: unknown,
	directions: unknown,
	pellets: number
): Rejection?
	if not ShotValidator.IsFiniteVector(origin) then
		return "OriginNotVector"
	end
	if not ShotValidator.IsDirection(aimDirection) then
		return "AimNotDirection"
	end
	if type(directions) ~= "table" then
		return "DirectionsNotList"
	end
	local list = directions :: { [any]: any }
	local length = #list
	if length == 0 then
		return "NoPellets"
	end
	if length > pellets then
		return "TooManyPellets"
	end
	local count = 0
	for _ in list do
		count += 1
		if count > length then
			return "DirectionsNotList"
		end
	end
	return nil
end

function ShotValidator.WithinSpread(direction: Vector3, aimDirection: Vector3, maxDegrees: number): boolean
	local cosine = math.clamp(direction.Unit:Dot(aimDirection.Unit), -1, 1)
	return math.acos(cosine) <= math.rad(maxDegrees)
end

function ShotValidator.FilterDirections(directions: { unknown }, aimDirection: Vector3, maxDegrees: number): { Vector3 }
	local accepted = {}
	for _, direction in directions do
		if ShotValidator.IsDirection(direction) then
			local unit = (direction :: Vector3).Unit
			if ShotValidator.WithinSpread(unit, aimDirection, maxDegrees) then
				table.insert(accepted, unit)
			end
		end
	end
	return accepted
end

function ShotValidator.OriginWithinReach(origin: Vector3, headPosition: Vector3, maxOffset: number): boolean
	return (origin - headPosition).Magnitude <= maxOffset
end

return ShotValidator
