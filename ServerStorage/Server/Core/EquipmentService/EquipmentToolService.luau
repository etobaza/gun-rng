--[[
  EquipmentToolService

  Description:
  Handles equipment tool behavior

  Author:
  @SixthAtom

  Date:
  13-03-2026
]]

const EquipmentToolService = {}

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")

const CharacterService = require(ServerStorage.Server.Core.CharacterService)
const ItemService = require(ServerStorage.Server.Core.ItemService)
const EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)
const EquipmentService = require(ServerStorage.Server.Core.EquipmentService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

const SLOTS = EquipmentConstants.Slots

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Slot = EquipmentConstants.Slot
type SlotHandlers = {
   Apply: (player: Player, itemName: string) -> (),
   Remove: (player: Player, itemName: string) -> (),
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

const assets = ReplicatedStorage.Assets

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

const deleteItemFromPlayer = function(player: Player, itemName: string)
   for _, parent in next, { player.Backpack, player.Character } do
      if not parent then
         continue
      end

      for _, tool in next, parent:QueryDescendants(">Tool") do
         if tool.Name == itemName then
            tool:Destroy()
         end
      end
   end
end

const waitForItemInventory = function(player: Player): boolean
   while not ItemService.getInventory(player) do
      if player.Parent == nil then
         return false
      end
      task.wait()
   end

   return true
end

const slotHandlers: { [Slot]: SlotHandlers } = {
   [SLOTS.Gun] = {
      Apply = function(player, itemName)
         deleteItemFromPlayer(player, itemName)

         const gunToolTemplate = assets.Tools:FindFirstChild(itemName)
         if not gunToolTemplate then
            return
         end

         const gunTool = gunToolTemplate:Clone()
         gunTool:SetAttribute("Slot", SLOTS.Gun)
         gunTool.Parent = player.Backpack

         task.defer(function()
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and gunTool.Parent == player.Backpack then
               humanoid:EquipTool(gunTool)
            end
         end)
      end,

      Remove = deleteItemFromPlayer,
   },
}

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EquipmentToolService.init()
   EquipmentService.ItemEquippedTasks:Add(function(player, slot, itemName)
      const handler = slotHandlers[slot]
      if handler then
         handler.Apply(player, itemName)
      end
   end)

   EquipmentService.ItemUnequippedTasks:Add(function(player, slot, itemName)
      const handler = slotHandlers[slot]
      if handler then
         handler.Remove(player, itemName)
      end
   end)

   CharacterService.CharacterAddedTasks:Add(function(character, player)
      if not waitForItemInventory(player) or player.Character ~= character then
         return
      end

      for slot, handler in slotHandlers do
         const itemName = EquipmentService.getEquippedItemName(player, slot)
         if itemName then
            handler.Apply(player, itemName)
         end
      end
   end)
end

return EquipmentToolService
