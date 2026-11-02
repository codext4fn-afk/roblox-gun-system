--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

return function(test, expect, load)
	local ConfigMerge = load("shared/ConfigMerge")

	test("overrides nested values and keeps the rest", function()
		local base = { A = 1, Nested = { X = 1, Y = 2 } }
		local merged = ConfigMerge.Merge(base, { Nested = { Y = 5 } })
		expect(merged.A).toBe(1)
		expect(merged.Nested.X).toBe(1)
		expect(merged.Nested.Y).toBe(5)
	end)

	test("never mutates the base table", function()
		local base = { Nested = { X = 1 } }
		local merged = ConfigMerge.Merge(base, { Nested = { X = 9 } })
		merged.Nested.X = 42
		expect(base.Nested.X).toBe(1)
	end)

	test("reports unknown keys with their full path", function()
		local unknown = ConfigMerge.UnknownKeys({ A = 1, Nested = { X = 1 } }, { B = 2, Nested = { Z = 3 } })
		expect(#unknown).toBe(2)
		expect(unknown).toContain("B")
		expect(unknown).toContain("Nested.Z")
	end)
end
