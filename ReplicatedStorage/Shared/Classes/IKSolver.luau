--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationJointUtil = require(ReplicatedStorage.Shared.Utils.AnimationJointUtil)

local pi, hpi = math.pi, math.pi / 2
local fwd = Vector3.new(0, 0, -1)

local solver = {}

export type IkSolver = {
   a: number,
   ab2: number,
   asqrd: number,
   b: number,
   bsqrd: number,
   clampDistance: number,
   defaults: { CFrame },
   difference: Vector3,
   elbowOriginFrame: CFrame,
   elbowTargetFrame: CFrame,
   elbowBinding: AnimationJointUtil.Binding,
   flip: boolean,
   handBinding: AnimationJointUtil.Binding,
   shoulderOriginFrame: CFrame,
   shoulderBinding: AnimationJointUtil.Binding,
   z: number,

   solve: (IkSolver, CFrame) -> (),
   reset: (IkSolver) -> (),
}

local order = Enum.RotationOrder.ZYX
local ELBOW_TARGET_FRAME_OFFSET = CFrame.new(0.001, 0, 0)

@native
function solver.solve(data: IkSolver, targetCFrame: CFrame)
   local shoulder, elbow, hand = data.shoulderBinding, data.elbowBinding, data.handBinding
   local difference = data.difference
   local a, b, asqrd, bsqrd = data.a, data.b, data.asqrd, data.bsqrd

   local target = targetCFrame * hand.TargetFrame
   local shoulderSpace = shoulder.OriginPart.CFrame * data.shoulderOriginFrame
   local toTarget = shoulderSpace:PointToObjectSpace(target.Position)
   local c = toTarget.Magnitude
   local axis = fwd:Cross(toTarget)
   local angle = math.acos(-toTarget.Z / c)

   local shoulderFrame = data.shoulderOriginFrame
   local elbowFrame = data.elbowOriginFrame
   if data.clampDistance > c then
      local csqrd = c ^ 2
      local ac, ab = math.acos((asqrd + csqrd - bsqrd) / (2 * a * c)), math.acos((bsqrd + asqrd - csqrd) / data.ab2)
      local flip = data.flip

      shoulderFrame = data.shoulderOriginFrame
         * CFrame.fromAxisAngle(axis, angle)
         * CFrame.fromEulerAngles(flip and ac + hpi or hpi - ac, math.asin(difference.X / c), data.z, order)
      elbowFrame = data.elbowOriginFrame * CFrame.fromEulerAnglesYXZ(flip and -pi + ab or -ab + pi, 0, 0)
   else
      shoulderFrame = data.shoulderOriginFrame
         * CFrame.fromAxisAngle(axis, angle)
         * CFrame.fromEulerAngles(hpi, math.asin(difference.X / c), data.z, order)
         * CFrame.new(0, a + b - c, 0)
   end

   local upperArmWorld = shoulder.OriginPart.CFrame * shoulderFrame * shoulder.TargetFrame:Inverse()
   local lowerArmWorld = upperArmWorld * elbowFrame * data.elbowTargetFrame:Inverse()
   local handFrame = lowerArmWorld:ToObjectSpace(target)

   AnimationJointUtil.setPose(shoulder, shoulderFrame)
   AnimationJointUtil.setPose(elbow, elbowFrame, data.elbowTargetFrame)
   AnimationJointUtil.setPose(hand, handFrame)
end

@native
function solver.reset(data: IkSolver)
   AnimationJointUtil.setPose(data.shoulderBinding, data.defaults[1])
   AnimationJointUtil.setPose(data.elbowBinding, data.defaults[2], data.elbowTargetFrame)
   AnimationJointUtil.setPose(data.handBinding, data.defaults[3])
end

@native
function solver.new(
   shoulderJoint: AnimationConstraint,
   elbowJoint: AnimationConstraint,
   handJoint: AnimationConstraint,
   lengthScale: number?,
   flip: boolean?,
   inclanationAngle: number?,
   startOffset: CFrame?
): IkSolver
   local shoulder = AnimationJointUtil.requireBinding(shoulderJoint)
   local elbow = AnimationJointUtil.requireBinding(elbowJoint)
   local hand = AnimationJointUtil.requireBinding(handJoint)
   local armLengthScale = lengthScale or 1

   local shoulderOriginFrame = shoulder.OriginFrame
   local elbowOriginFrame = elbow.OriginFrame
   local handOriginFrame = hand.OriginFrame
   local solverShoulderFrame = if startOffset then shoulderOriginFrame * startOffset else shoulderOriginFrame

   local shoulderSpace = shoulder.OriginPart.CFrame * shoulder.OriginFrame
   local shoulderPosition = shoulderSpace.Position
   local elbowSpace = shoulderSpace * shoulder.TargetFrame:Inverse() * elbow.OriginFrame
   local elbowPosition = elbowSpace.Position
   local handSpace = elbowSpace * elbow.TargetFrame:Inverse() * hand.OriginFrame
   local handPosition = handSpace.Position

   local difference = (shoulderSpace:Inverse() * handSpace).Position

   local a = math.abs(elbowPosition.Y - shoulderPosition.Y) * armLengthScale
   local b = math.abs(elbowPosition.Y - handPosition.Y) * armLengthScale
   local data: IkSolver = {
      a = a,
      ab2 = a * b * 2,
      asqrd = a ^ 2,
      b = b,
      bsqrd = b ^ 2,
      clampDistance = a + b,
      defaults = { shoulderOriginFrame, elbowOriginFrame, handOriginFrame },
      difference = difference,
      elbowOriginFrame = elbowOriginFrame,
      elbowTargetFrame = elbow.TargetFrame * ELBOW_TARGET_FRAME_OFFSET,
      elbowBinding = elbow,
      flip = if flip then true else false,
      handBinding = hand,
      shoulderOriginFrame = solverShoulderFrame,
      shoulderBinding = shoulder,
      z = math.rad(inclanationAngle or 0),
      solve = solver.solve,
      reset = solver.reset,
   }

   data:reset()
   return data
end

return solver
