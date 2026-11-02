--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local PARAMS = { recovery = 14, sideways = 0.25, shakeRecovery = 10, shakeMax = 3 }

return function(test, expect, load)
	local Recoil = load("shared/Recoil")
	local Spring = load("shared/Spring")

	test("a kick adds its full pitch", function()
		local recoil = Recoil.new(PARAMS)
		recoil:Kick(0.35 * 0.6, 0.5)
		expect(recoil.pitch).toBeNear(0.21)
		expect(recoil.yaw).toBeNear(0)
	end)

	test("sideways kick stays within the configured share", function()
		local recoil = Recoil.new(PARAMS)
		recoil:Kick(2, 0)
		expect(recoil.yaw).toBeNear(-0.5)
		recoil:Reset()
		recoil:Kick(2, 1)
		expect(recoil.yaw).toBeNear(0.5)
	end)

	test("recoil decays exponentially and frame-rate independently", function()
		local a, b = Recoil.new(PARAMS), Recoil.new(PARAMS)
		a:Kick(3, 0.5)
		b:Kick(3, 0.5)
		a:Step(0.1)
		for _ = 1, 10 do
			b:Step(0.01)
		end
		expect(a.pitch).toBeNear(3 * math.exp(-1.4))
		expect(b.pitch).toBeNear(a.pitch, 1e-9)
	end)

	test("shake stacks but never exceeds the cap", function()
		local recoil = Recoil.new(PARAMS)
		for _ = 1, 10 do
			recoil:Shake(1.6)
		end
		expect(recoil.shake).toBeNear(3)
	end)

	test("the sway spring settles on its target", function()
		local position, velocity = 0, 0
		for _ = 1, 240 do
			position, velocity = Spring.Step(position, velocity, 1, 1 / 60, Spring.Sway)
		end
		expect(position).toBeNear(1, 1e-3)
	end)

	test("the sway spring stays stable through a long frame", function()
		local position, velocity = Spring.Step(0, 0, 1, 0.5, Spring.Sway)
		expect(math.abs(position)).toBeAtMost(2)
		expect(math.abs(velocity)).toBeAtMost(50)
	end)
end
