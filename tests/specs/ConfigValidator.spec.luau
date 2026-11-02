--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

return function(test, expect, load)
	local ConfigMerge = load("shared/ConfigMerge")
	local ConfigValidator = load("shared/ConfigValidator")
	local Defaults = load("shared/Defaults")

	local function withDefaults(overrides: { [string]: any }): { [string]: any }
		local config = ConfigMerge.Merge(Defaults, overrides)
		config.Id = "Test"
		return config
	end

	test("accepts the defaults", function()
		expect(#ConfigValidator.Validate(withDefaults({}))).toBe(0)
	end)

	test("rejects an empty id", function()
		local config = withDefaults({})
		config.Id = ""
		expect(ConfigValidator.Validate(config)).toContain("Id")
	end)

	test("rejects an unknown fire mode", function()
		expect(ConfigValidator.Validate(withDefaults({ Mode = "Burst" }))).toContain("Mode")
	end)

	test("rejects zero pellets and fractional magazines", function()
		local errors = ConfigValidator.Validate(withDefaults({ Pellets = 0, MagSize = 2.5 }))
		expect(errors).toContain("Pellets")
		expect(errors).toContain("MagSize")
	end)

	test("rejects a non-positive fire interval and NaN range", function()
		local errors = ConfigValidator.Validate(withDefaults({ FireInterval = 0, Range = 0 / 0 }))
		expect(errors).toContain("FireInterval")
		expect(errors).toContain("Range")
	end)

	test("rejects magazine timings out of order", function()
		local errors = ConfigValidator.Validate(withDefaults({ Magazine = { Drop = 0.05 } }))
		expect(errors).toContain("Magazine.Drop")
	end)

	test("rejects malformed animation ids", function()
		local errors = ConfigValidator.Validate(withDefaults({ Animations = { R6 = { Hold = "12345" } } }))
		expect(errors).toContain("Animations.R6.Hold")
	end)

	test("accepts published animation ids", function()
		local errors = ConfigValidator.Validate(
			withDefaults({ Animations = { R15 = { Reload = "rbxassetid://107321042976212" } } })
		)
		expect(#errors).toBe(0)
	end)

	test("rejects unknown reload styles", function()
		expect(ConfigValidator.Validate(withDefaults({ Reload = { Style = "Spin" } }))).toContain("Reload.Style")
	end)

	test("rejects fields of view outside 1 to 120", function()
		expect(ConfigValidator.Validate(withDefaults({ ScopeFOV = 150 }))).toContain("ScopeFOV")
	end)
end
