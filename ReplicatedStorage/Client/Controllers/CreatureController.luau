local CreatureController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CreatureConstants = require(ReplicatedStorage.Shared.Constants.CreatureConstants)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local CreatureProtocol = require(ReplicatedStorage.Shared.Networking.Protocols.CreatureProtocol)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local CreatureUtil = require(ReplicatedStorage.Shared.Utils.CreatureUtil)

local EVENT_CODES = RemoteCodes.Creature.Events
local FUNCTION_CODES = RemoteCodes.Creature.Functions
local CREATURE_ID_ATTRIBUTE = CreatureConstants.CreatureIdAttribute

type RenderedCreature = {
   Snapshot: CreatureConstants.Snapshot,
   Model: Model,
   Body: BasePart,
   HealthFill: Frame,
   HealthText: TextLabel,
}

local creatureRemoteEvent = SimpleRemotes.getEvent("Creature")
local creatureRemoteFunction = SimpleRemotes.getFunction("Creature")

local renderedCreatures: { [number]: RenderedCreature } = {}
local renderFolder: Folder

local function updateHealth(rendered: RenderedCreature)
   local snapshot = rendered.Snapshot
   local alpha = math.clamp(snapshot.Health / snapshot.MaxHealth, 0, 1)
   rendered.HealthFill.Size = UDim2.fromScale(alpha, 1)
   rendered.HealthText.Text = `{math.ceil(snapshot.Health)}/{math.ceil(snapshot.MaxHealth)}`
end

local function removeCreature(creatureId: number)
   local rendered = renderedCreatures[creatureId]
   if not rendered then
      return
   end

   rendered.Model:Destroy()
   renderedCreatures[creatureId] = nil
end

local function renderCreature(snapshot: CreatureConstants.Snapshot)
   removeCreature(snapshot.Id)

   local species = CreatureConstants.SpeciesById[snapshot.SpeciesId]
   local mutation = CreatureConstants.MutationsById[snapshot.MutationId]
   local templates = ReplicatedStorage.Assets:FindFirstChild("Creatures")
   local template = templates and templates:FindFirstChild(species and species.DisplayName or "")
   if not (species and mutation and template and template:IsA("Model")) then
      return
   end

   local model = template:Clone()
   model.Name = string.format("Creature_%u", snapshot.Id)
   local body = model:FindFirstChild("Body")
   local overhead = body and body:FindFirstChild("Overhead")
   local healthBack = overhead and overhead:FindFirstChild("HealthBack")
   local healthFill = healthBack and healthBack:FindFirstChild("HealthFill")
   local healthText = overhead and overhead:FindFirstChild("HealthText")
   local nameLabel = overhead and overhead:FindFirstChild("NameLabel")
   if
      not (
         body
         and body:IsA("BasePart")
         and healthFill
         and healthFill:IsA("Frame")
         and healthText
         and healthText:IsA("TextLabel")
         and nameLabel
         and nameLabel:IsA("TextLabel")
      )
   then
      model:Destroy()
      return
   end

   model:SetAttribute(CREATURE_ID_ATTRIBUTE, snapshot.Id)
   body:SetAttribute(CREATURE_ID_ATTRIBUTE, snapshot.Id)
   body.Color = mutation.Color or species.Color
   nameLabel.Text = if mutation.Name == "None" then species.DisplayName else `{mutation.Name} {species.DisplayName}`
   nameLabel.TextColor3 = mutation.Color or Color3.new(1, 1, 1)
   model.Parent = renderFolder

   local rendered = {
      Snapshot = snapshot,
      Model = model,
      Body = body,
      HealthFill = healthFill,
      HealthText = healthText,
   }
   renderedCreatures[snapshot.Id] = rendered
   updateHealth(rendered)
end

local function loadRemotes()
   SimpleRemotesUtil.bindRemoteEventActions(creatureRemoteEvent, {
      [EVENT_CODES.Spawned] = function(b: buffer)
         local snapshot = CreatureProtocol.decodeSnapshot(b)
         renderCreature(snapshot)
      end,
      [EVENT_CODES.HealthChanged] = function(b: buffer)
         local creatureId, health
         creatureId = BufferUtil.readu32(b, 0)
         health = BufferUtil.readf32(b, 4)

         local rendered = renderedCreatures[creatureId]
         if rendered then
            rendered.Snapshot.Health = health
            updateHealth(rendered)
         end
      end,
      [EVENT_CODES.Removed] = function(b: buffer)
         local creatureId = BufferUtil.readu32(b, 0)
         removeCreature(creatureId)
      end,
   }, SimpleRemotesUtil.DecodeActionBuffer)
end

local function loadSnapshot()
   local request = BufferUtil.construct({ { Type = "U8", Value = FUNCTION_CODES.GetSnapshot } })
   local snapshotBuffer = creatureRemoteFunction:InvokeServer(request)
   if typeof(snapshotBuffer) ~= "buffer" then
      return
   end

   for _, snapshot in CreatureProtocol.decodeSnapshotList(snapshotBuffer) do
      renderCreature(snapshot)
   end
end

local function onRenderStepped()
   local serverTime = workspace:GetServerTimeNow()
   for creatureId, rendered in renderedCreatures do
      if serverTime >= rendered.Snapshot.ExpiresAt then
         removeCreature(creatureId)
         continue
      end

      local position = CreatureUtil.getPosition(rendered.Snapshot, serverTime)
      rendered.Model:PivotTo(CFrame.new(position))
   end
end

function CreatureController.getCreatureId(instance: Instance): number?
   local creatureId = instance:GetAttribute(CREATURE_ID_ATTRIBUTE)
   if type(creatureId) == "number" then
      return creatureId
   end

   local model = instance:FindFirstAncestorOfClass("Model")
   local modelCreatureId = model and model:GetAttribute(CREATURE_ID_ATTRIBUTE)
   return if type(modelCreatureId) == "number" then modelCreatureId else nil
end

function CreatureController.init()
   renderFolder = Instance.new("Folder")
   renderFolder.Name = "ClientCreatures"
   renderFolder.Parent = workspace
   loadRemotes()
   RunService.RenderStepped:Connect(onRenderStepped)
end

function CreatureController.start()
   loadSnapshot()
end

return CreatureController
