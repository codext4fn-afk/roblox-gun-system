--!strict

local RequestLimiter = {}
RequestLimiter.__index = RequestLimiter

export type RequestLimiter = typeof(setmetatable(
	{} :: {
		intervals: { [string]: number },
		lastTimes: { [any]: { [string]: number } },
	},
	RequestLimiter
))

function RequestLimiter.new(intervals: { [string]: number }): RequestLimiter
	return setmetatable({
		intervals = intervals,
		lastTimes = {},
	}, RequestLimiter)
end

function RequestLimiter.Allow(self: RequestLimiter, key: any, kind: string, now: number): boolean
	local interval = self.intervals[kind]
	assert(interval, `no interval for request kind '{kind}'`)
	local times = self.lastTimes[key]
	if not times then
		times = {}
		self.lastTimes[key] = times
	end
	local last = times[kind]
	if last and now - last < interval then
		return false
	end
	times[kind] = now
	return true
end

function RequestLimiter.Interval(self: RequestLimiter, kind: string): number
	return self.intervals[kind]
end

function RequestLimiter.Forget(self: RequestLimiter, key: any)
	self.lastTimes[key] = nil
end

return RequestLimiter
