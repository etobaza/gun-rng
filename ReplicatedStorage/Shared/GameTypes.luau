local ReplicatedStorage = game:GetService("ReplicatedStorage")

local weaponModules = ReplicatedStorage.Shared.Weapons

export type GunModel = typeof(ReplicatedStorage.Assets.Tools.M1911)
export type R15Character = typeof(ReplicatedStorage.Assets.R15Character)
export type ButtonDisplayInfo = typeof(ReplicatedStorage.Assets.Tycoon.ButtonDisplayInfo)

export type GunModule = typeof(require(weaponModules.M1911)()) & typeof(require(weaponModules["AK-103"])())
export type PumpGunModule = typeof(require(weaponModules["SPAS-12"])())
export type SniperGunModule = typeof(require(weaponModules["M24"])())

return nil
