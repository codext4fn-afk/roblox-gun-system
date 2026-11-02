--!strict

local Recoil = {}
Recoil.__index = Recoil

export type Params = {
	recovery: number,
	sideways: number,
	shakeRecovery: number,
	shakeMax: number,
}

export type Recoil = typeof(setmetatable(
	{} :: {
		params: Params,
		pitch: number,
		yaw: number,
		shake: number,
	},
	Recoil
))

function Recoil.new(params: Params): Recoil
	return setmetatable({
		params = params,
		pitch = 0,
		yaw = 0,
		shake = 0,
	}, Recoil)
end

function Recoil.Kick(self: Recoil, degrees: number, sidewaysRoll: number)
	self.pitch += degrees
	self.yaw += (sidewaysRoll * 2 - 1) * self.params.sideways * degrees
end

function Recoil.Shake(self: Recoil, degrees: number)
	self.shake = math.min(self.shake + degrees, self.params.shakeMax)
end

function Recoil.Step(self: Recoil, deltaTime: number): (number, number, number)
	local decay = math.exp(-deltaTime * self.params.recovery)
	self.pitch *= decay
	self.yaw *= decay
	self.shake *= math.exp(-deltaTime * self.params.shakeRecovery)
	return self.pitch, self.yaw, self.shake
end

function Recoil.Reset(self: Recoil)
	self.pitch, self.yaw, self.shake = 0, 0, 0
end

return Recoil
