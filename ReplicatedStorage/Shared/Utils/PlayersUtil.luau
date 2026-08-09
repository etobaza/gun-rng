local PlayersUtil = {}

local Players = game:GetService("Players")

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PlayersUtil.onPlayerAdded(handler: (player: Player) -> ())
	for _, plr in Players:GetPlayers() do
		task.spawn(handler, plr)
	end

	return Players.PlayerAdded:Connect(handler)
end

function PlayersUtil.onCharacterAdded(player: Player, handler: (character: Model) -> ())
	if player.Character then
		task.spawn(handler, player.Character)
	end
	return player.CharacterAdded:Connect(handler)
end

function PlayersUtil.isAlive(player: Player)
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0
end

function PlayersUtil.getHumanoid(player: Player): Humanoid?
	if PlayersUtil.isAlive(player) then
		return player.Character:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

return PlayersUtil
