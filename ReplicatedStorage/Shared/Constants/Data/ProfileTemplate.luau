local ProfileTemplate = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)
local EquipmentConstants = require(ReplicatedStorage.Shared.Constants.EquipmentConstants)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Template = typeof(ProfileTemplate.get())

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ProfileTemplate.get()
   local profile = {}

   -------------------------------------------------------------------------------
   -- PRIVATE VARIABLES
   -------------------------------------------------------------------------------

   local currencies: { [EconomyConstants.Currency]: number } = { Cash = 9e5, Gems = 0 }

   local banData: {
      BanAmount: number,
      Pending: {
         ExecuteAt: number,
         Duration: number,
         PrivateReason: string,
         PublicReason: string,
      }?,
   } =
      { BanAmount = 0 }

   -------------------------------------------------------------------------------
   -- PUBLIC VARIABLES
   -------------------------------------------------------------------------------

   profile.DailyRewards = {
      LastClaim = 0,
      Streak = 0,
   }

   -- Core
   profile.Currencies = currencies
   profile.ItemInventory = buffer.create(0)
   profile.Index = {
      DiscoveredLoot = buffer.create(0),
   }
   profile.EquippedItems = {} :: { [EquipmentConstants.Slot]: string? }
   profile.BanData = banData
   profile.Progression = {
      World = 1,
      Upgrades = {
         Luck = 0,
         ValueMultiplier = 0,
         FireRate = 0,
         Damage = 0,
         MagazineSize = 0,
      },
   }

   -- Services
   profile.TycoonPurchases = buffer.create(0)
   profile.StorageWorth = 50

   -------------------------------------------------------------------------------
   -- LOGIC
   -------------------------------------------------------------------------------

   return profile
end

warn("Profile Template:", ProfileTemplate.get())

return ProfileTemplate
