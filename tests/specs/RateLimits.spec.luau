--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

return function(test, expect, load)
	local RequestLimiter = load("server/RequestLimiter")
	local ShotClock = load("server/ShotClock")

	test("the first shot is always allowed", function()
		expect(ShotClock.new(0.1, 1.15):TryConsume(0)).toBeTruthy()
	end)

	test("a second shot inside the jitter window is rejected", function()
		local clock = ShotClock.new(0.1, 1.15)
		clock:TryConsume(0)
		expect(clock:TryConsume(0.08)).toBeFalsy()
	end)

	test("a slightly early shot within tolerance is allowed", function()
		local clock = ShotClock.new(0.1, 1.15)
		clock:TryConsume(0)
		expect(clock:TryConsume(0.086)).toBeTruthy()
	end)

	test("sustained fire never beats the configured rate", function()
		local interval = 60 / 820
		local clock = ShotClock.new(interval, 1.15)
		local accepted = 0
		local now = 0
		while now < 10 do
			if clock:TryConsume(now) then
				accepted += 1
			end
			now += interval * 0.85
		end
		expect(accepted).toBeAtMost(math.floor(10 / interval) + 2)
	end)

	test("an honest shooter at the exact rate is never rejected", function()
		local interval = 0.9
		local clock = ShotClock.new(interval, 1.15)
		for shot = 0, 20 do
			expect(clock:TryConsume(shot * interval)).toBeTruthy()
		end
	end)

	test("request limiter spaces requests per key and kind", function()
		local limiter = RequestLimiter.new({ Reload = 0.3, AimPitch = 1 / 30 })
		expect(limiter:Allow("a", "Reload", 0)).toBeTruthy()
		expect(limiter:Allow("a", "Reload", 0.2)).toBeFalsy()
		expect(limiter:Allow("b", "Reload", 0.2)).toBeTruthy()
		expect(limiter:Allow("a", "AimPitch", 0.2)).toBeTruthy()
		expect(limiter:Allow("a", "Reload", 0.31)).toBeTruthy()
	end)

	test("forgetting a key resets its history", function()
		local limiter = RequestLimiter.new({ Reload = 0.3 })
		limiter:Allow("a", "Reload", 0)
		limiter:Forget("a")
		expect(limiter:Allow("a", "Reload", 0.1)).toBeTruthy()
	end)
end
