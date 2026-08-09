local UIUtil = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UDim2Util = require(ReplicatedStorage.Shared.Utils.UDim2Util)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type GuiImage = ImageButton | ImageLabel
export type Input = Enum.UserInputType | Enum.KeyCode | nil

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local tweenInfoIn = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenInfoOut = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local tweenInfoSlide = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, true)
local tweenInfoImpulse = TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, true)

local actualSizesCache: { [GuiObject]: UDim2 } = {}
local actualPositionsCache: { [GuiObject]: UDim2 } = {}
local actualTransparencyCache: { [GuiObject]: number } = {}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

UIUtil.ObjectAnimations = {
   slideShine = function(object: GuiObject, customSlideFrom: UDim2?, customSlideTo: UDim2?, customTweenInfo: TweenInfo?)
      local tweenInfo = customTweenInfo or tweenInfoSlide
      local slideFrom = customSlideFrom or UDim2.fromScale(-0.5, 0.5)
      local slideTo = customSlideTo or UDim2.fromScale(1.5, 0.5)

      local shineObject: GuiObject? = object:FindFirstChild("Shine")
      if not shineObject then return 
         warn(`No 'Shine' found in object '{object.Name}'`)
      end

      shineObject.Position = slideFrom
      local tween = TweenService:Create(shineObject, tweenInfo, {
         Position = slideTo
      })

      tween:Play()

      return tween
   end,

   impulseSize = function(object: GuiObject, sizeMultiplier: number, customTweenInfo: TweenInfo?)
      local tweenInfo = customTweenInfo or tweenInfoImpulse

      if not actualSizesCache[object] then
         actualSizesCache[object] = object.Size
      end

      object.Size = actualSizesCache[object]
      local tween = TweenService:Create(object, tweenInfo, {
         Size = UDim2Util.multiply(object.Size, sizeMultiplier),
      })

      tween:Play()
      return tween
   end
}

function UIUtil.frameAnimateIn(frame: Frame, customTweenInfo: TweenInfo?)
	local tweenInfo = customTweenInfo or tweenInfoIn

	if not actualSizesCache[frame] then
		actualSizesCache[frame] = frame.Size
	end

	frame.Size = UDim2.fromScale(0, 0)

	local tween = TweenService:Create(frame, tweenInfo, {
		Size = actualSizesCache[frame],
	})
	tween:Play()

	return tween
end

function UIUtil.frameAnimateOut(frame: Frame, customTweenInfo: TweenInfo?)
	local tweenInfo = customTweenInfo or tweenInfoOut

	local tween = TweenService:Create(frame, tweenInfo, {
		Size = UDim2.fromScale(0, 0),
	})
	tween:Play()

	return tween
end

function UIUtil.frameSlideIn(frame: Frame, customTweenInfo: TweenInfo?, fromPosition: UDim2?)
	local tweenInfo = customTweenInfo or tweenInfoIn

	if not actualPositionsCache[frame] then
		actualPositionsCache[frame] = frame.Position
	end

	local target = actualPositionsCache[frame]
	local startPosition = fromPosition or UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale + 1.5, target.Y.Offset)
	frame.Position = startPosition

	local tween = TweenService:Create(frame, tweenInfo, {
		Position = actualPositionsCache[frame],
	})
	tween:Play()

	return tween
end

function UIUtil.frameSlideOut(frame: Frame, customTweenInfo: TweenInfo?, toPosition: UDim2?)
	local tweenInfo = customTweenInfo or tweenInfoOut

	if not actualPositionsCache[frame] then
		actualPositionsCache[frame] = frame.Position
	end

	local target = actualPositionsCache[frame]
	local endPosition = toPosition or UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale - 1.5, target.Y.Offset)

	local tween = TweenService:Create(frame, tweenInfo, {
		Position = endPosition,
	})
	tween:Play()

	return tween
end

function UIUtil.frameFadeIn(frame: Frame, customTweenInfo: TweenInfo?)
	local tweenInfo = customTweenInfo or tweenInfoIn

	if not actualTransparencyCache[frame] then
		actualTransparencyCache[frame] = frame.BackgroundTransparency
	end

	frame.BackgroundTransparency = 1

	local tween = TweenService:Create(frame, tweenInfo, {
		BackgroundTransparency = actualTransparencyCache[frame],
	})
	tween:Play()

	return tween
end

function UIUtil.frameFadeOut(frame: Frame, customTweenInfo: TweenInfo?)
	local tweenInfo = customTweenInfo or tweenInfoOut

	local tween = TweenService:Create(frame, tweenInfo, {
		BackgroundTransparency = 1,
	})
	tween:Play()

	return tween
end

function UIUtil.templatify<T>(guiObject: T)
	local parent = guiObject.Parent
	guiObject.Parent = nil

	return function()
		local clone = guiObject:Clone() :: T
		clone.Parent = parent
		return clone
	end
end

function UIUtil.getAnchorDirection(object: GuiObject)
	local position = object.Position
	local scale = Vector2.new(position.X.Scale, position.Y.Scale)
	local difference = scale - object.AnchorPoint
	local length = difference.Magnitude

	return if length > 0 then difference / length else Vector2.zero
end

function UIUtil.bulkTweenCreate(instance: GuiObject, tweens: { { TweenInfo: TweenInfo, PropertyTable: { [string]: any } } }): ...Tween
	local createdTweens = {}
	for _, v in next, tweens do
		table.insert(createdTweens, TweenService:Create(instance, v.TweenInfo, v.PropertyTable))
	end
	return unpack(createdTweens)
end

return UIUtil
