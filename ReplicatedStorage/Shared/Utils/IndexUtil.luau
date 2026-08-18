local IndexUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type DiscoverySet = { [number]: true }

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function IndexUtil.decodeDiscoveredLoot(b: buffer): (DiscoverySet, number)
   local discovered: DiscoverySet = {}
   local byteLength = buffer.len(b)
   if byteLength < 2 then
      return discovered, 0
   end

   local declaredCount, offset = BufferUtil.readu16(b, 0)
   local readableCount = math.min(declaredCount, (byteLength - offset) // 4)
   local count = 0

   for _ = 1, readableCount do
      local hash
      hash, offset = BufferUtil.readu32(b, offset)
      if discovered[hash] then
         continue
      end

      discovered[hash] = true
      count += 1
   end

   return discovered, count
end

function IndexUtil.encodeDiscoveredLoot(discovered: DiscoverySet): buffer
   local hashes = {}
   for hash in discovered do
      table.insert(hashes, hash)
   end

   table.sort(hashes)
   assert(#hashes <= 65_535, "Index discovery count exceeds the buffer format")

   local b = buffer.create(2 + #hashes * 4)
   local offset = BufferUtil.writeu16(b, 0, #hashes)
   for _, hash in hashes do
      offset = BufferUtil.writeu32(b, offset, hash)
   end

   return b
end

return IndexUtil
