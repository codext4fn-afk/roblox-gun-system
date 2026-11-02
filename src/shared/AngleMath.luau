--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local AngleMath = {}

function AngleMath.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function AngleMath.WrapAngle(angle: number): number
	return (angle + math.pi) % (math.pi * 2) - math.pi
end

function AngleMath.YawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

function AngleMath.PitchOf(direction: Vector3): number
	return math.asin(math.clamp(direction.Y, -1, 1))
end

function AngleMath.Smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function AngleMath.ExpBlend(deltaTime: number, speed: number): number
	return 1 - math.exp(-deltaTime * speed)
end

function AngleMath.DominantAxis(vector: Vector3): Vector3
	local x, y, z = math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z)
	if x >= y and x >= z then
		return Vector3.new(math.sign(vector.X), 0, 0)
	elseif y >= z then
		return Vector3.new(0, math.sign(vector.Y), 0)
	end
	return Vector3.new(0, 0, math.sign(vector.Z))
end

return AngleMath
