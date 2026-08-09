--!strict
--!optimize 2
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ConnectionsList = require(ReplicatedStorage.Shared.Classes.ConnectionsList)

const SoundSequence = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type PlaybackSession = {
	Stop: (self: PlaybackSession) -> (),
}

export type SoundSequence = {
	_keyframes: { SoundKeyframe },

	Play: (self: SoundSequence, parent: Instance, soundGroup: SoundGroup?) -> PlaybackSession,
   SetPitch: (self: SoundSequence, pitch: number) -> (),
}

type SoundKeyframe = {
	Volume: number?,
	Pitch: number?,
	Time: number,
	Id: number,
}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SoundSequence.Play(self: SoundSequence, parent: Instance, soundGroup: SoundGroup?): PlaybackSession
	const startTime = os.clock()

	const remainingKeyframes = table.clone(self._keyframes)
	const activeSounds: { [Sound]: RBXScriptConnection } = {}
	const connectionsList = ConnectionsList.new()

	connectionsList:Add(RunService.Heartbeat:Connect(function()
		const passedTime = os.clock() - startTime

		for index = #remainingKeyframes, 1, -1 do
			const keyframe = remainingKeyframes[index]

			if passedTime >= keyframe.Time then
				table.remove(remainingKeyframes, index)
				if not parent or not parent.Parent then continue end

				local sound = Instance.new("Sound")
				sound.Parent = parent
				sound.SoundId = `rbxassetid://{keyframe.Id}`
				sound.Volume = keyframe.Volume or 1
				sound.PlaybackSpeed = keyframe.Pitch or 1
				sound.SoundGroup = soundGroup

				local connection
				connection = sound.Ended:Connect(function()
					if connection then
						connection:Disconnect()
						activeSounds[sound] = nil
					end
					sound:Destroy()
				end)

				activeSounds[sound] = connection
				sound:Play()
			end
		end

		if #remainingKeyframes == 0 then
			connectionsList:Clean()
		end
	end))

	return {
		Stop = function()
			connectionsList:Destroy()

			for sound, connection in next, activeSounds do
				connection:Disconnect()
				sound:Stop()
				sound:Destroy()
			end
		end,
	}
end

function SoundSequence.SetPitch(self: SoundSequence, pitch: number)
   for _, v in next, self._keyframes do
      v.Pitch = pitch
   end
end

-------------------------------------------------------------------------------
-- CONSTRUCTOR
-------------------------------------------------------------------------------

function SoundSequence.new(keyframes: { SoundKeyframe })
	const self = table.clone(SoundSequence) :: SoundSequence

	self._keyframes = keyframes

	return self
end

return SoundSequence