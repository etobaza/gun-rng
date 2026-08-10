--!strict
--!optimize 2
-- CRC32C for buffers

local bxor = bit32.bxor
local band = bit32.band
local rshift = bit32.rshift

local POLY = 0x82F63B78

local CRC32C_TABLE = buffer.create(256 * 4)
for i = 0, 255 do
	local c = i
	for _ = 1, 8 do
		if band(c, 1) ~= 0 then
			c = bxor(rshift(c, 1), POLY)
		else
			c = rshift(c, 1)
		end
	end
	buffer.writeu32(CRC32C_TABLE, i * 4, c)
end

return @native function(buf: buffer, offset: number?, length: number?): number
	local startOffset = offset or 0
	local totalLen = buffer.len(buf)
	local byteLength = length or (totalLen - startOffset)

	local crc = 0xFFFFFFFF

	local endOffset = startOffset + byteLength
	for i = startOffset, endOffset - 1 do
		local b = buffer.readu8(buf, i)
		local idx = band(bxor(crc, b), 0xFF)
		crc = bxor(rshift(crc, 8), buffer.readu32(CRC32C_TABLE, idx * 4))
	end

	crc = bxor(crc, 0xFFFFFFFF)
	return band(crc, 0xFFFFFFFF)
end
