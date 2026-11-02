--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

return function(test, expect, load)
	local AngleMath = load("shared/AngleMath")

	test("wraps angles into minus pi to pi", function()
		expect(AngleMath.WrapAngle(math.pi * 3)).toBeNear(-math.pi)
		expect(AngleMath.WrapAngle(-0.5)).toBeNear(-0.5)
	end)

	test("reads yaw and pitch from a direction", function()
		expect(AngleMath.YawOf(Vector3.new(0, 0, -1))).toBeNear(0)
		expect(AngleMath.YawOf(Vector3.new(-1, 0, 0))).toBeNear(math.pi / 2)
		expect(AngleMath.PitchOf(Vector3.new(0, 1, 0))).toBeNear(math.pi / 2)
	end)

	test("smoothstep clamps and eases", function()
		expect(AngleMath.Smoothstep(-1)).toBe(0)
		expect(AngleMath.Smoothstep(2)).toBe(1)
		expect(AngleMath.Smoothstep(0.5)).toBeNear(0.5)
	end)

	test("finds a weapon's dominant axis", function()
		local axis = AngleMath.DominantAxis(Vector3.new(-2.1, 0.3, 0.1))
		expect(axis.X).toBe(-1)
		expect(axis.Y).toBe(0)
	end)
end
