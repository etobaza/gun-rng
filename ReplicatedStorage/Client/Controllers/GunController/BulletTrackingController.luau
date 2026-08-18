--[[
  BulletTrackingController

  Description:
  Tracks bullet projectiles and handles VFX/SFX of them.

  Author:
  @SixthAtom

  Date:
  24-03-2026
]]

local BulletTrackingController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
local ObjectPool = require(ReplicatedStorage.Shared.Classes.ObjectPool)
local Scheduler = require(ReplicatedStorage.Shared.Classes.Scheduler)
local BulletTrackingConstants = require(ReplicatedStorage.Shared.Constants.BulletTrackingConstants)
local CreatureConstants = require(ReplicatedStorage.Shared.Constants.CreatureConstants)
local BulletTrackingProtocol = require(ReplicatedStorage.Shared.Networking.Protocols.BulletTrackingProtocol)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local ArrayUtil = require(ReplicatedStorage.Shared.Utils.ArrayUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)
local PartUtil = require(ReplicatedStorage.Shared.Utils.PartUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EVENT_CODES = RemoteCodes.Guns.Events
local OWNER_TYPES = BulletTrackingConstants.OwnerTypes

local MIN_TRACER_WIDTH = 0.02
local AIR_DRAG = 0.003
local MAX_FLIGHT_TIME = 7
local MAX_RAYCAST_ITERATIONS = 3

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type TrackedBullet = {
   ShotFrom: BasePart,
   Velocity: Vector3,
   Position: Vector3,

   StudsTravelled: number,
   FlightTime: number,

   RayParams: RaycastParams,
   IgnoreList: { Instance },
   Attachment0: Attachment,
   Attachment1: Attachment,
   Beam: Beam,

   Caliber: number,
   TracerPixelWidth: number,
   PreviousCameraPosition: Vector3,

   OnImpactHandler: ((result: RaycastResult, trackedBullet: TrackedBullet) -> ())?,

   _destroyed: true?,
   _index: number,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local remoteEvent = SimpleRemotes.getEvent("BulletTracking")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local assets = ReplicatedStorage.Assets
const impactPartTemplate = assets.GunVisuals.ImpactPart
const impactPartBaseSize = impactPartTemplate.Size

local trackedBullets: { TrackedBullet } = {}
local trackedBulletsToDestroy: { { TrackedBullet: TrackedBullet, FrameCount: number } } = {}

local rng = Random.new()
local scheduler = Scheduler.new()

local trackCore: BasePart
local tracerProjectionScale = 0
local tracerProjectionFov = -1
local tracerProjectionViewportHeight = -1

-- Object pools
local impactPartPool = ObjectPool.new(impactPartTemplate, 2000, "ImpactParts", true)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onImpact(result: RaycastResult, trackedBullet: TrackedBullet)
   local impactPart = impactPartPool:Draw(workspace)

   local up = result.Normal.Unit
   local reference = math.abs(up:Dot(Vector3.zAxis)) > 0.99 and Vector3.xAxis or Vector3.zAxis
   local right = reference:Cross(up).Unit
   local look = up:Cross(right).Unit

   local color = result.Instance.Color or Color3.new(1, 1, 1)
   const bulletHoleScale = BulletTrackingConstants.getBulletHoleScale(trackedBullet.Caliber)

   impactPart.CFrame = CFrame.fromMatrix(result.Position, right, up, -look)
   impactPart.Size =
      Vector3.new(impactPartBaseSize.X * bulletHoleScale, impactPartBaseSize.Y, impactPartBaseSize.Z * bulletHoleScale)
   local weld = PartUtil.weld(result.Instance, impactPart)

   impactPart.BulletHole.Color3 = color
   impactPart.ImpactParticles.Color = ColorSequence.new(color)

   const particleCount = math.max(1, math.round(rng:NextInteger(7, 12) * bulletHoleScale))
   impactPart.ImpactParticles:Emit(particleCount)

   scheduler:Add(rng:NextNumber(6, 8), function()
      weld:Destroy()
      impactPartPool:Return(impactPart)
   end)

   if trackedBullet.OnImpactHandler then
      trackedBullet.OnImpactHandler(result, trackedBullet)
   end
end

local function onRenderStepped(dT)
   if #trackedBullets == 0 then
      return
   end

   const cameraCFrame = camera.CFrame
   const cameraPosition = cameraCFrame.Position
   const cameraUpVector = cameraCFrame.UpVector
   const fieldOfView = camera.FieldOfView
   const viewportHeight = math.max(camera.ViewportSize.Y, 1)

   -- Cache the camera projection shared by every tracer, recalculating only when FOV or resolution changes.
   -- The resulting scale converts a desired screen-pixel width into world-space Beam width at any distance.

   if fieldOfView ~= tracerProjectionFov or viewportHeight ~= tracerProjectionViewportHeight then
      tracerProjectionScale = 2 * math.tan(math.rad(fieldOfView) * 0.5) / viewportHeight
      tracerProjectionFov = fieldOfView
      tracerProjectionViewportHeight = viewportHeight
   end

   const gravity = Vector3.new(0, -workspace.Gravity, 0)
   const dragFactor = math.exp(-AIR_DRAG * dT)

   for _, trackedBullet in next, trackedBullets do
      if trackedBullet._destroyed then
         continue
      end

      -- Update values
      local rayParams = trackedBullet.RayParams
      local previousVelocity = trackedBullet.Velocity
      local currentVelocity = previousVelocity * dragFactor + gravity * dT

      local previousPosition = trackedBullet.Position
      local currentPosition = previousPosition + (previousVelocity + currentVelocity) * 0.5 * dT

      trackedBullet.Velocity = currentVelocity
      trackedBullet.Position = currentPosition
      trackedBullet.FlightTime += dT

      -- Raycasting
      local frameCastStart = previousPosition
      local frameCastEnd = currentPosition
      local forceFakeCast = trackedBullet.StudsTravelled >= 3000
      local didImpact = false

      for _ = 1, MAX_RAYCAST_ITERATIONS do
         local castDirection = frameCastEnd - frameCastStart
         if castDirection.Magnitude <= 0 then
            currentPosition = frameCastStart
            break
         end

         local result = GeneralUtil.customCast(frameCastStart, castDirection, rayParams, forceFakeCast)
         trackedBullet.StudsTravelled += result.Distance

         if not result.Instance then
            currentPosition = result.Position
            break
         end

         local validImpact, ignoredInstance = BulletTrackingController.validateImpact(result)
         if validImpact then
            onImpact(result, trackedBullet)
            currentPosition = result.Position
            trackedBullet._destroyed = true
            didImpact = true
            break
         end

         table.insert(trackedBullet.IgnoreList, ignoredInstance or result.Instance)
         rayParams.ExcludeInstances = trackedBullet.IgnoreList

         frameCastStart = result.Position + castDirection.Unit * 0.01
         currentPosition = frameCastStart
      end

      if not didImpact then
         currentPosition = frameCastEnd
      end

      -- Update visuals
      local beam = trackedBullet.Beam
      local distToEnd = (cameraPosition - currentPosition).Magnitude
      local thickness = math.max(MIN_TRACER_WIDTH, distToEnd * tracerProjectionScale * trackedBullet.TracerPixelWidth)
      beam.Width0, beam.Width1 = thickness, thickness

      local visualStartPosition = cameraCFrame * trackedBullet.PreviousCameraPosition
      local visualEndPosition = currentPosition
      trackedBullet.PreviousCameraPosition = cameraCFrame:PointToObjectSpace(currentPosition)

      local toBulletCFrame = CFrame.lookAt(cameraPosition, visualEndPosition):Inverse()
      local cp0, cp1 = toBulletCFrame * visualStartPosition, toBulletCFrame * visualEndPosition
      local a0, a1 = trackedBullet.Attachment0, trackedBullet.Attachment1

      if vector.magnitude(vector.create(cp0.X - cp1.X, cp0.Y - cp1.Y, 0)) < thickness * 0.9 then
         local hval = cameraUpVector * thickness / 2
         visualEndPosition += hval
         visualStartPosition = currentPosition - hval
      end
      a1.Position = visualEndPosition
      a0.Position = visualStartPosition

      -- List for removal (if valid)
      if trackedBullet.FlightTime >= MAX_FLIGHT_TIME then
         trackedBullet._destroyed = true
      end

      if trackedBullet._destroyed then
         table.insert(trackedBulletsToDestroy, {
            TrackedBullet = trackedBullet,
            FrameCount = 0,
         })
      end
   end

   -- Remove destroyed bullets
   local i = 1
   while i <= #trackedBulletsToDestroy do
      local v = trackedBulletsToDestroy[i]
      v.FrameCount += 1

      if v.FrameCount > 2 then
         local trackedBullet = v.TrackedBullet

         local swappedBullet = ArrayUtil.swapbackRemove(trackedBullets, trackedBullet._index)
         if swappedBullet ~= trackedBullet then
            swappedBullet._index = trackedBullet._index
         end

         trackedBullet.Attachment0:Destroy()
         trackedBullet.Attachment1:Destroy()
         trackedBullet.Beam:Destroy()

         ArrayUtil.swapbackRemove(trackedBulletsToDestroy, i)
      else
         i += 1
      end
   end
end

local function loadRemotes()
   SimpleRemotesUtil.bindRemoteEventActions(remoteEvent, {
      [EVENT_CODES.CastTracers] = function(b: buffer, ignoreLists: { [number]: { Instance } })
         local payloadLength, offset = buffer.len(b), 0
         while offset < payloadLength do
            local shotId, ownerType, ownerId, instanceId, caliber, pelletCount
            shotId, offset = BufferUtil.readu16(b, offset)
            ownerType, offset = BufferUtil.readu8(b, offset)
            ownerId, offset = BufferUtil.readf64(b, offset)
            instanceId, offset = BufferUtil.readu32(b, offset)
            caliber, offset = BufferUtil.readu8(b, offset)
            pelletCount, offset = BufferUtil.readu8(b, offset)

            local instance = GlobalInstanceController.getInstance(instanceId) :: BasePart?
            local isLocalPlayer = ownerType == OWNER_TYPES.Player and ownerId == player.UserId
            local trackedFrom = if not isLocalPlayer then instance else nil
            if not trackedFrom then
               offset += pelletCount * BulletTrackingProtocol.VelocitySizeBytes
               continue
            end

            local ignoreList = ignoreLists[shotId] or {}

            for _ = 1, pelletCount do
               local velocity
               velocity, offset = BufferUtil.readVector3_96(b, offset)

               BulletTrackingController.track(trackedFrom, trackedFrom.Position, velocity, ignoreList, caliber)
            end
         end
      end,
   }, SimpleRemotesUtil.DecodeActionBuffer)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function BulletTrackingController.track(
   node: BasePart,
   position: Vector3,
   velocity: Vector3,
   ignoreList: { Instance },
   caliber: number,
   onImpactHandler: ((result: RaycastResult, trackedBullet: TrackedBullet) -> ())?
)
   const tracerPixelWidth = BulletTrackingConstants.getTracerPixelWidth(caliber)
   local a0 = Instance.new("Attachment")
   a0.Position = node.Position
   a0.Parent = trackCore

   local a1 = Instance.new("Attachment")
   a1.Position = node.Position
   a1.Parent = trackCore

   local beam = Instance.fromExisting(assets.GunVisuals.BulletTracer)
   beam.Attachment0, beam.Attachment1 = a0, a1
   beam.Parent = trackCore

   local params = RaycastParams.new()
   params.ExcludeInstances = ignoreList

   local trackedBullet: TrackedBullet = {
      ShotFrom = node,
      Velocity = velocity,
      Position = position,

      StudsTravelled = 0,
      FlightTime = 0,

      RayParams = params,
      IgnoreList = ignoreList,
      Attachment0 = a0,
      Attachment1 = a1,
      Beam = beam,
      Caliber = caliber,
      TracerPixelWidth = tracerPixelWidth,
      PreviousCameraPosition = camera.CFrame:PointToObjectSpace(position),

      OnImpactHandler = onImpactHandler,

      _index = #trackedBullets + 1,
   }

   trackedBullets[trackedBullet._index] = trackedBullet
end

function BulletTrackingController.validateImpact(result: RaycastResult): (boolean, Instance?)
   local hitInstance = result.Instance
   if not hitInstance then
      return false, nil -- RETURN: Invalid raycast result, no hit instance.
   end

   local hitTool = hitInstance:FindFirstAncestorOfClass("Tool")
   if hitTool then
      return false, hitTool -- RETURN: Ignore tool hierarchy hits entirely.
   end

   if hitInstance:GetAttribute(CreatureConstants.CreatureIdAttribute) ~= nil then
      return true, hitInstance
   end

   if hitInstance.Name == "Handle" then
      if hitInstance:FindFirstAncestorOfClass("Accessory") or hitInstance:FindFirstAncestorOfClass("Tool") then
         return false, hitInstance -- RETURN: Ignore accessory/tool handles.
      end
   end

   local characters = workspace:FindFirstChild("Characters")
   if characters and hitInstance:IsDescendantOf(characters) then
      return true, hitInstance -- RETURN: Valid hit on a character body part.
   end

   local model = hitInstance:FindFirstAncestorOfClass("Model")
   if model then
      local humanoid = model:FindFirstChildOfClass("Humanoid")
      if humanoid then
         return true, hitInstance -- RETURN: Valid hit on a humanoid model (NPC/player rig).
      end
   end

   if hitInstance:IsA("BasePart") and not hitInstance.CanCollide then
      return false, hitInstance -- RETURN: Ignore non-collidable world part.
   end

   return true, hitInstance -- RETURN: Valid default hit.
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function BulletTrackingController.init()
   trackCore = Instance.new("Part")
   trackCore.Anchored = true
   trackCore.CFrame = CFrame.identity
   trackCore.CanCollide, trackCore.CanQuery, trackCore.CanTouch = false, false, false
   trackCore.Name = "BulletTrackCore"
   trackCore.Parent = workspace.Terrain

   loadRemotes()

   RunService.RenderStepped:Connect(onRenderStepped)
end

return BulletTrackingController
