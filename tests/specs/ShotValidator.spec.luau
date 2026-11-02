--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

return function(test, expect, load)
	local ShotValidator = load("server/ShotValidator")
	local origin = Vector3.new(0, 5, 0)
	local aim = Vector3.new(0, 0, -1)

	test("accepts a well-formed shot", function()
		expect(ShotValidator.CheckArguments(origin, aim, { aim }, 1)).toBe(nil)
	end)

	test("rejects a non-vector origin", function()
		expect(ShotValidator.CheckArguments("here", aim, { aim }, 1)).toBe("OriginNotVector")
	end)

	test("rejects NaN and infinite vectors", function()
		local nan = 0 / 0
		expect(ShotValidator.CheckArguments(Vector3.new(nan, 0, 0), aim, { aim }, 1)).toBe("OriginNotVector")
		expect(ShotValidator.CheckArguments(origin, Vector3.new(math.huge, 0, 0), { aim }, 1)).toBe("AimNotDirection")
	end)

	test("rejects a zero-length aim", function()
		expect(ShotValidator.CheckArguments(origin, Vector3.zero, { aim }, 1)).toBe("AimNotDirection")
	end)

	test("rejects pellet lists that are missing, empty or too long", function()
		expect(ShotValidator.CheckArguments(origin, aim, aim, 1)).toBe("DirectionsNotList")
		expect(ShotValidator.CheckArguments(origin, aim, {}, 1)).toBe("NoPellets")
		expect(ShotValidator.CheckArguments(origin, aim, { aim, aim }, 1)).toBe("TooManyPellets")
	end)

	test("rejects pellet lists padded with extra keys", function()
		local padded: { [any]: any } = { aim }
		padded.extra = aim
		expect(ShotValidator.CheckArguments(origin, aim, padded, 1)).toBe("DirectionsNotList")
	end)

	test("drops pellets outside the allowed spread", function()
		local inside = Vector3.new(math.tan(math.rad(1)), 0, -1).Unit
		local outside = Vector3.new(math.tan(math.rad(10)), 0, -1).Unit
		local accepted = ShotValidator.FilterDirections({ inside, outside, "junk" }, aim, 4)
		expect(#accepted).toBe(1)
		expect(accepted[1].Magnitude).toBeNear(1, 1e-5)
	end)

	test("measures spread against the aim direction", function()
		local edge = Vector3.new(math.tan(math.rad(4)), 0, -1)
		expect(ShotValidator.WithinSpread(edge, aim, 4.01)).toBeTruthy()
		expect(ShotValidator.WithinSpread(edge, aim, 3.99)).toBeFalsy()
	end)

	test("limits how far the origin may sit from the head", function()
		local head = Vector3.new(0, 5, 0)
		expect(ShotValidator.OriginWithinReach(Vector3.new(0, 5, 5.9), head, 6)).toBeTruthy()
		expect(ShotValidator.OriginWithinReach(Vector3.new(0, 5, 6.1), head, 6)).toBeFalsy()
	end)
end
