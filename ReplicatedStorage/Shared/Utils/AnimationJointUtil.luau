--!strict
--!optimize 2

local AnimationJointUtil = {}

export type Binding = {
   Constraint: AnimationConstraint,
   OriginPart: BasePart,
   TargetPart: BasePart,
   OriginFrame: CFrame,
   TargetFrame: CFrame,
}

local appliedOriginFrames: { [AnimationConstraint]: CFrame } = {}

local function destroyAttachmentsWith(constraint: AnimationConstraint, attachment0: Attachment, attachment1: Attachment)
   constraint.Destroying:Connect(function()
      if attachment0.Parent then
         attachment0:Destroy()
      end
      if attachment1.Parent then
         attachment1:Destroy()
      end
   end)
end

function AnimationJointUtil.find(parent: Instance, name: string): AnimationConstraint?
   for _, descendant in parent:GetDescendants() do
      if descendant.Name == name and descendant:IsA("AnimationConstraint") then
         return descendant
      end
   end

   return nil
end

function AnimationJointUtil.waitFor(parent: Instance, name: string): AnimationConstraint
   while true do
      local constraint = AnimationJointUtil.find(parent, name)
      if constraint then
         return constraint
      end
      parent.DescendantAdded:Wait()
   end
end

function AnimationJointUtil.bind(constraint: AnimationConstraint): Binding?
   local attachment0, attachment1 = constraint.Attachment0, constraint.Attachment1
   local originPart = if attachment0 then attachment0.Parent else nil
   local targetPart = if attachment1 then attachment1.Parent else nil
   if
      not (
         attachment0
         and attachment1
         and originPart
         and originPart:IsA("BasePart")
         and targetPart
         and targetPart:IsA("BasePart")
      )
   then
      return nil
   end

   return {
      Constraint = constraint,
      OriginPart = originPart,
      TargetPart = targetPart,
      OriginFrame = attachment0.CFrame,
      TargetFrame = attachment1.CFrame,
   }
end

function AnimationJointUtil.requireBinding(constraint: AnimationConstraint): Binding
   local binding = AnimationJointUtil.bind(constraint)
   assert(binding, `{constraint:GetFullName()} is missing valid attachments`)
   return binding
end

function AnimationJointUtil.calculateTransform(
   binding: Binding,
   desiredOriginFrame: CFrame,
   desiredTargetFrame: CFrame?
): CFrame
   local targetFrame = desiredTargetFrame or binding.TargetFrame
   return binding.OriginFrame:Inverse() * desiredOriginFrame * targetFrame:Inverse() * binding.TargetFrame
end

function AnimationJointUtil.setPose(binding: Binding, desiredOriginFrame: CFrame, desiredTargetFrame: CFrame?)
   binding.Constraint.Transform = AnimationJointUtil.calculateTransform(binding, desiredOriginFrame, desiredTargetFrame)
end

function AnimationJointUtil.applyOriginFrame(binding: Binding, desiredOriginFrame: CFrame, preserveAnimation: boolean)
   local transform = binding.OriginFrame:Inverse() * desiredOriginFrame
   if preserveAnimation then
      transform *= binding.Constraint.Transform
   end

   appliedOriginFrames[binding.Constraint] = desiredOriginFrame
   binding.Constraint.Transform = transform
end

function AnimationJointUtil.applyTargetFrameOffset(constraint: AnimationConstraint, offset: CFrame)
   constraint.Transform *= offset:Inverse()
end

function AnimationJointUtil.getAppliedOriginFrame(binding: Binding): CFrame
   return appliedOriginFrames[binding.Constraint] or binding.OriginFrame
end

function AnimationJointUtil.clearAppliedOriginFrame(binding: Binding)
   appliedOriginFrames[binding.Constraint] = nil
end

function AnimationJointUtil.createKinematic(
   name: string,
   originPart: BasePart,
   targetPart: BasePart,
   originFrame: CFrame?,
   targetFrame: CFrame?,
   parent: Instance?
): AnimationConstraint
   local attachment0 = Instance.new("Attachment")
   attachment0.Name = `{name}ConstraintAttachment0`
   attachment0.CFrame = originFrame or CFrame.identity
   attachment0.Parent = originPart

   local attachment1 = Instance.new("Attachment")
   attachment1.Name = `{name}ConstraintAttachment1`
   attachment1.CFrame = targetFrame or CFrame.identity
   attachment1.Parent = targetPart

   local constraint = Instance.new("AnimationConstraint")
   constraint.Name = name
   constraint.Attachment0 = attachment0
   constraint.Attachment1 = attachment1
   constraint.IsKinematic = true
   constraint.Parent = parent or targetPart

   destroyAttachmentsWith(constraint, attachment0, attachment1)
   return constraint
end

return AnimationJointUtil
