--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

local ShotClock = {}
ShotClock.__index = ShotClock

export type ShotClock = typeof(setmetatable(
	{} :: {
		interval: number,
		burst: number,
		credit: number,
		last: number?,
	},
	ShotClock
))

function ShotClock.new(interval: number, burst: number): ShotClock
	assert(interval > 0, "interval must be above 0")
	assert(burst >= 1, "burst must be 1 or more")
	return setmetatable({
		interval = interval,
		burst = burst,
		credit = burst,
		last = nil,
	}, ShotClock)
end

function ShotClock.Refill(self: ShotClock, now: number)
	local last = self.last
	if last then
		self.credit = math.min(self.burst, self.credit + math.max(now - last, 0) / self.interval)
	end
	self.last = now
end

function ShotClock.TryConsume(self: ShotClock, now: number): boolean
	self:Refill(now)
	if self.credit < 1 then
		return false
	end
	self.credit -= 1
	return true
end

return ShotClock
