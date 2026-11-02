--!strict
local RunService = game:GetService("RunService")

local JointLayer = require(script.Parent.JointLayer)
local Types = require(script.Parent.Parent.Types)

local HEAD_FOLLOW = 0.6

type Joints = {
	torso: BasePart,
	neck: Motor6D?,
	rightShoulder: Motor6D?,
	leftShoulder: Motor6D?,
}

local layer = if RunService:IsServer() then JointLayer.Transform else JointLayer.C0
local jointCache: { [Model]: Joints } = setmetatable({}, { __mode = "k" }) :: any

local function findMotor(parent: Instance, name: string): Motor6D?
	local motor = parent:FindFirstChild(name)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function getJoints(character: Model): Joints?
	local joints = jointCache[character]
	if joints and joints.torso.Parent == character then
		return joints
	end
	local torso = character:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return nil
	end
	local found: Joints = {
		torso = torso,
		neck = findMotor(torso, "Neck"),
		rightShoulder = findMotor(torso, "Right Shoulder"),
		leftShoulder = findMotor(torso, "Left Shoulder"),
	}
	jointCache[character] = found
	return found
end

local PoseSolverR6: Types.PoseSolver = {
	NewPose = function(): Types.Pose
		return { pitch = 0, aim = 0, armPitch = 0, armYaw = 0, armBack = 0 }
	end,
	Apply = function(character: Model, pose: Types.Pose)
		local joints = getJoints(character)
		if not joints then
			return
		end
		local armPitch = pose.pitch * pose.aim + pose.armPitch
		local armYaw = CFrame.Angles(0, pose.armYaw, 0)
		if joints.rightShoulder then
			layer.Apply(joints.rightShoulder, CFrame.new(-pose.armBack, 0, 0) * armYaw * CFrame.Angles(0, 0, armPitch))
		end
		if joints.leftShoulder then
			layer.Apply(joints.leftShoulder, CFrame.new(pose.armBack, 0, 0) * armYaw * CFrame.Angles(0, 0, -armPitch))
		end
		if joints.neck then
			layer.Apply(joints.neck, CFrame.Angles(-pose.pitch * HEAD_FOLLOW, 0, 0))
		end
	end,
	Clear = function(character: Model)
		local joints = jointCache[character]
		if not joints then
			return
		end
		if joints.neck then
			layer.Clear(joints.neck)
		end
		if joints.rightShoulder then
			layer.Clear(joints.rightShoulder)
		end
		if joints.leftShoulder then
			layer.Clear(joints.leftShoulder)
		end
		jointCache[character] = nil
	end,
}

return PoseSolverR6
