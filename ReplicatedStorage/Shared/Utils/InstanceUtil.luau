--!strict
local InstanceUtil = {}

local CollectionService = game:GetService("CollectionService")

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function InstanceUtil.newNameParent(class: string, name: string, parent: Instance?): Instance
	local instance = Instance.new(class)
	instance.Name = name
	instance.Parent = parent

	return instance
end

function InstanceUtil.newProperties(class: string, props: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(class)
	for property, value in props do
		(instance :: any)[property] = value
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	return instance
end

function InstanceUtil.onDestroyed(instance: Instance, callback: () -> ())
	return instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			callback()
		end
	end)
end

function InstanceUtil.findFirstDescendant(instance: Instance, searchingFor: string): Instance?
	for _, descendant in (instance:GetDescendants()) do
		if descendant.Name == searchingFor then
			return descendant
		end
	end
	return nil
end

function InstanceUtil.findFirstDescendantWhichIsA(instance: Instance, className: string): Instance?
	for _, descendant in (instance:GetDescendants()) do
		if descendant:IsA(className) then
			return descendant
		end
	end
	return nil
end

function InstanceUtil.waitForDescendant(instance, searchingFor: string): Instance
	local descendant
	repeat
		task.wait()
		descendant = InstanceUtil.findFirstDescendant(instance, searchingFor)
	until descendant

	return descendant :: Instance
end

function InstanceUtil.waitForFirstChildOfClass(instance: Instance, className: string)
	local child = instance:FindFirstChildOfClass(className)
	if child then
		return child
	end

	repeat
		instance.ChildAdded:Wait()
		child = instance:FindFirstChildOfClass(className)
	until child

	return child :: Instance
end

function InstanceUtil.getChildrenOfClass(parent: Instance, class: string, filterMethod: ((child: Instance) -> boolean)?)
	local children = {}
	for _, v in parent:GetChildren() do
		if v:IsA(class) then
			if filterMethod ~= nil and not filterMethod(v) then
				continue
			end
			table.insert(children, v)
		end
	end
	return children
end

function InstanceUtil.findLastAncestorOfClass(instance: Instance, className: string): Instance?
	local lastAncestor = nil
	local parent = instance.Parent

	while parent and parent ~= game do
		if not parent:IsA(className) then
			break
		end
		lastAncestor = parent
		parent = parent.Parent
	end

	return lastAncestor
end

function InstanceUtil.connectChildAdded(instance: Instance, handler: (child: Instance) -> ())
	for _, v in next, instance:GetChildren() do
		task.spawn(handler, v)
	end
	return instance.ChildAdded:Connect(handler)
end

function InstanceUtil.connectAttributeChangedSignal(
	instance: Instance,
	attribute: string,
	handler: (value: any, instance: Instance) -> ()
)
	local initialValue = instance:GetAttribute(attribute)
	if initialValue ~= nil then
		handler(initialValue, instance)
	end

	return instance:GetAttributeChangedSignal(attribute):Connect(function()
		handler(instance:GetAttribute(attribute), instance)
	end)
end

function InstanceUtil.connectInstanceAddedByTag<T>(tag: string, handler: (instance: T) -> ()): RBXScriptConnection
	for _, v: T in CollectionService:GetTagged(tag) do
		task.spawn(handler, v)
	end

	return CollectionService:GetInstanceAddedSignal(tag):Connect(handler)
end

function InstanceUtil.connectChildAdded(instance: Instance, handler: (child: Instance) -> ()): RBXScriptConnection
	for _, v in instance:GetChildren() do
		task.spawn(handler, v)
	end

	return instance.ChildAdded:Connect(handler)
end

function InstanceUtil.connectInstanceRemovedByTag<T>(tag: string, handler: (instance: T) -> ()): RBXScriptConnection
	return CollectionService:GetInstanceRemovedSignal(tag):Connect(handler)
end

function InstanceUtil.clearAttributes(instance: Instance, ignore: { string }?)
	for i in instance:GetAttributes() do
		if not ignore or not table.find(ignore, i) then
			instance:SetAttribute(i, nil)
		end
	end
end

function InstanceUtil.setAttributesWithPrefix(instance: Instance, attributes: { [string]: any }, prefix: string)
	for i, v in attributes do
		instance:SetAttribute(`{prefix}_{i}`, v)
	end
end

function InstanceUtil.getAttributeWithPrefix(instance: Instance, attribute: string, prefix: string)
	return instance:GetAttribute(`{prefix}_{attribute}`)
end

return InstanceUtil
