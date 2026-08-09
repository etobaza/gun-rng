--!optimize 2

--[[
  Copyright 2026 StaliniumDev/@StaliniumDev
 
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
--[[
    Reverts the Roblox "Avatar Joint Upgrade" constraint bloat back to classic Motor6D joints.
    
    Roblox's new constraint-based rigging introduces significant hierarchy bloat and 
    breaks legacy systems. This script intercepts characters as they spawn to:
		1. Map and convert modern `AnimationConstraint` instances back to standard `Motor6D` joints.
    	2. Purge excess physical constraint instances (e.g., `BallSocketConstraint`, `NoCollisionConstraint`).
    	3. Set an "AnimationConstraintsReplaced" attribute to true to let other scripts know it's done.
      
    Restores hierarchy predictability, legacy script compatibility, and reduces replication overhead.
    After the new constraints are replaced with Motor6D's it adds an "AnimationConstraintsReplaced" attribute to the character, that way you can tell for certain when all of the new constraints are replaced with Motor6D's.
    To make sure your legacy code still runs as before you do one of the following things:
    	1. character:GetAttributeChangedSignal('AnimationConstraintsReplaced'):Wait() -- will wait for all animation constraints to be replaced with Motor6D's
    	2. character:GetAttributeChangedSignal('AnimationConstraintsReplaced'):Connect(onCharacterAdded) -- if you use on character added/character appearance loaded events
    		you can connect to the attribute changed signal instead,
    		but dont forget that the character wont be passed into the funcion you connect to it
]]

const Players = game:GetService('Players')

-- The classes we want to clean up to remove hierarchy bloat and physical constraint simulation overhead.
-- Note: 'AnimationConstraint' is included here because it is purged once replaced by Motor6D.
const REMOVED_CLASSES = "BallSocketConstraint,NoCollisionConstraint,AnimationConstraint"

const onCharacterAdded = function(character:Model)
	-- Map each modern AnimationConstraint to a classic Motor6D joint.
	-- This replicates the exact rigging joints (using Attachment parents and CFrames)
	-- while preserving the constraint's name and parenting structure.
	for _, ac:AnimationConstraint in next, character:QueryDescendants('AnimationConstraint') do
		const motor6d = Instance.new('Motor6D')
		motor6d.Part0, motor6d.Part1 = ac.Attachment0.Parent, ac.Attachment1.Parent
		motor6d.C0, motor6d.C1 = ac.Attachment0.CFrame, ac.Attachment1.CFrame
		motor6d.Name = ac.Name
		motor6d.Parent = ac.Parent
	end

	-- Purge the original constraints and supporting physical constraints to clean up the character hierarchy.
	for _, v in next, character:QueryDescendants(REMOVED_CLASSES) do
		v:Destroy()
	end

	-- Tag the character with an attribute so legacy scripts know the conversion is complete.
	character:SetAttribute('AnimationConstraintsReplaced', true)
end

const onPlayerAdded = function(lplr:Player)
	-- Use 'CharacterAppearanceLoaded' instead of 'CharacterAdded'.
	-- This guarantees that the character's clothing, accessories, and new avatar rig constraints
	-- are fully loaded and present in the character model before the conversion begins.
	lplr.CharacterAppearanceLoaded:Connect(onCharacterAdded)

	-- Immediately process the character if it has already loaded/spawned.
	const character = lplr.Character
	if character then
		onCharacterAdded(character)
	end 
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Safely process players who are already in the game when this script starts/loads.
for _, lplr in next, Players:GetPlayers() do
	task.defer(onPlayerAdded, lplr)
end