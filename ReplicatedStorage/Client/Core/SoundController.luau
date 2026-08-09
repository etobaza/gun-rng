--[[
  SoundController

  Description:
  Handles sound on the client

  Author:
  @SixthAtom

  Date:
  07-04-2026
]]

local SoundController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type SoundData = {
   Pitch: number?
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local soundsLUT: { [string]: Sound } = {}
local soundBundles: { [string]: { string } } = {} 

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SoundController.play(name: string, soundData: SoundData?)
   soundData = soundData or {}

	local sound = soundsLUT[name]
	if not sound then
		error(`Sound {name} doesn't exist`)
	end

	sound.PlaybackSpeed = soundData.Pitch or 1
	sound:Play()
end

function SoundController.playFromBundle(bundleName: string, soundData: SoundData?)
   const bundle = soundBundles[bundleName]
   assert(bundle, `Bundle '{bundleName}' doesn't exist`)

   SoundController.play(bundle[math.random(#bundle)], soundData)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SoundController.init()
	for _, v in next, SoundService:QueryDescendants("Sound") :: { Sound } do
		soundsLUT[v.Name] = v
	end

   for _, v in next, SoundService:QueryDescendants("Folder") :: {Folder} do
      const sounds = {}
      for _, s in next, v:QueryDescendants("Sound") :: {Sound} do
         table.insert(sounds, s.Name)
      end

      if #sounds>0 then
         soundBundles[v.Name] = sounds
      end
   end
end

-- function SoundController.start() end

-- function SoundController.test() end

return SoundController
