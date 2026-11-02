--!strict

local Spring = {}

export type Params = {
	stiffness: number,
	damping: number,
	step: number,
}

Spring.Sway = table.freeze({
	stiffness = 140,
	damping = 18,
	step = 1 / 240,
}) :: Params

function Spring.Step(
	position: number,
	velocity: number,
	target: number,
	deltaTime: number,
	params: Params
): (number, number)
	local steps = math.max(1, math.ceil(deltaTime / params.step))
	local step = deltaTime / steps
	for _ = 1, steps do
		local acceleration = (target - position) * params.stiffness - velocity * params.damping
		velocity += acceleration * step
		position += velocity * step
	end
	return position, velocity
end

return Spring
