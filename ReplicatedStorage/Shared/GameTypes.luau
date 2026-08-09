local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage.Assets
local weaponModules = ReplicatedStorage.Shared.Weapons

export type GunModel = typeof(assets.Tools.M1911)
export type R15Character = typeof(assets.R15Character)
export type ButtonDisplayInfo = typeof(assets.Tycoon.ButtonDisplayInfo)

export type GunModule = typeof(require(weaponModules.M1911)()) & typeof(require(weaponModules["AK-103"])())
export type PumpGunModule = typeof(require(weaponModules["SPAS-12"])())
export type SniperGunModule = typeof(require(weaponModules["M24"])())

return nil
