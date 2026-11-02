--!strict
-- Copyright (c) 2026 Fahd (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.

export type Layer = {
	Apply: (motor: Motor6D, offset: CFrame) -> (),
	Clear: (motor: Motor6D) -> (),
}

type TransformRecord = {
	offset: CFrame,
	written: CFrame,
}

local MATCH_EPSILON = 1e-4

local transformLayers: { [Motor6D]: TransformRecord } = setmetatable({}, { __mode = "k" }) :: any
local originalC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function getBaseTransform(motor: Motor6D, record: TransformRecord?): CFrame
	if record and motor.Transform:FuzzyEq(record.written, MATCH_EPSILON) then
		return record.offset:Inverse() * record.written
	end
	return motor.Transform
end

local Transform: Layer = {
	Apply = function(motor: Motor6D, offset: CFrame)
		local record = transformLayers[motor]
		local written = offset * getBaseTransform(motor, record)
		motor.Transform = written
		if record then
			record.offset = offset
			record.written = written
		else
			transformLayers[motor] = { offset = offset, written = written }
		end
	end,
	Clear = function(motor: Motor6D)
		local record = transformLayers[motor]
		if record then
			motor.Transform = getBaseTransform(motor, record)
			transformLayers[motor] = nil
		end
	end,
}

local C0: Layer = {
	Apply = function(motor: Motor6D, offset: CFrame)
		local base = originalC0[motor]
		if not base then
			base = motor.C0
			originalC0[motor] = base
		end
		motor.C0 = base * offset
	end,
	Clear = function(motor: Motor6D)
		local base = originalC0[motor]
		if base then
			motor.C0 = base
			originalC0[motor] = nil
		end
	end,
}

return {
	Transform = Transform,
	C0 = C0,
}
