--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

export type Expectation = {
	toBe: (expected: any) -> (),
	toBeNear: (expected: number, tolerance: number?) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeAtMost: (limit: number) -> (),
	toBeAtLeast: (limit: number) -> (),
	toContain: (needle: any) -> (),
}

local DEFAULT_TOLERANCE = 1e-6

local function fail(message: string)
	error(message, 3)
end

local function expect(actual: any): Expectation
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {tostring(expected)}, got {tostring(actual)}`)
			end
		end,
		toBeNear = function(expected: number, tolerance: number?)
			local limit = tolerance or DEFAULT_TOLERANCE
			if type(actual) ~= "number" or math.abs(actual - expected) > limit then
				fail(`expected {expected} within {limit}, got {tostring(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected a truthy value, got {tostring(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected a falsy value, got {tostring(actual)}`)
			end
		end,
		toBeAtMost = function(limit: number)
			if type(actual) ~= "number" or actual > limit then
				fail(`expected at most {limit}, got {tostring(actual)}`)
			end
		end,
		toBeAtLeast = function(limit: number)
			if type(actual) ~= "number" or actual < limit then
				fail(`expected at least {limit}, got {tostring(actual)}`)
			end
		end,
		toContain = function(needle: any)
			if type(actual) ~= "table" then
				fail(`expected a list, got {typeof(actual)}`)
			end
			for _, item in actual do
				if
					item == needle
					or (type(item) == "string" and type(needle) == "string" and string.find(item, needle, 1, true))
				then
					return
				end
			end
			fail(`expected the list to contain {tostring(needle)}`)
		end,
	}
end

return expect
