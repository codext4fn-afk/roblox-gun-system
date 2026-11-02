--!strict
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local function sequence(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

return function(test, expect, load)
	local Spread = load("shared/Spread")

	test("blends from hip spread to aim spread", function()
		expect(Spread.Current(2.5, 0.5, 0)).toBeNear(2.5)
		expect(Spread.Current(2.5, 0.5, 1)).toBeNear(0.5)
		expect(Spread.Current(2.5, 0.5, 0.5)).toBeNear(1.5)
	end)

	test("crosshair gap grows with spread", function()
		expect(Spread.CrosshairGap(0)).toBeNear(6)
		expect(Spread.CrosshairGap(2)).toBeNear(16)
	end)

	test("every sample stays inside the cone", function()
		local aim = Vector3.new(0.3, 0.1, -1).Unit
		local nextNumber = sequence(7)
		for _ = 1, 2000 do
			local direction = Spread.SampleCone(aim, 2.5, nextNumber)
			expect(direction.Magnitude).toBeNear(1, 1e-4)
			expect(Spread.AngleBetween(direction, aim)).toBeAtMost(2.5 + 1e-3)
		end
	end)

	test("zero spread fires straight down the aim line", function()
		local aim = Vector3.new(0, 0, -1)
		local direction = Spread.SampleCone(aim, 0, sequence(3))
		expect(Spread.AngleBetween(direction, aim)).toBeNear(0, 1e-3)
	end)

	test("samples cover the whole cone area", function()
		local aim = Vector3.new(0, 0, -1)
		local nextNumber = sequence(11)
		local outer, total = 0, 4000
		for _ = 1, total do
			if Spread.AngleBetween(Spread.SampleCone(aim, 2, nextNumber), aim) > 2 * math.sqrt(0.5) then
				outer += 1
			end
		end
		expect(outer / total).toBeNear(0.5, 0.05)
	end)

	test("pattern returns one direction per pellet", function()
		local pattern = Spread.Pattern(Vector3.new(1, 0, 0), 6, 8, sequence(5))
		expect(#pattern).toBe(8)
	end)
end
