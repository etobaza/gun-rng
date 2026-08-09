local BufferUtil = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local TYPES = table.freeze({
	U8 = "u8",
	U16 = "u16",
	U32 = "u32",
	F32 = "f32",
	F64 = "f64",
	COLOR_24 = "Color_24",
	VECTOR3_96 = "Vector3_96",
	CFRAME_144 = "CFrame_144",
})

local TYPE_SIZES = table.freeze({
	[TYPES.U8] = 1,
	[TYPES.U16] = 2,
	[TYPES.U32] = 4,
	[TYPES.F32] = 4,
	[TYPES.F64] = 8,
	[TYPES.COLOR_24] = 3,
	[TYPES.VECTOR3_96] = 12,
	[TYPES.CFRAME_144] = 18,
})

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type BufferType = keyof<typeof(TYPES)>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function BufferUtil.writeu8(b: buffer, offset: number, value: number)
	buffer.writeu8(b, offset, value)
	return offset + 1
end

function BufferUtil.readu8(b: buffer, offset: number)
	return buffer.readu8(b, offset), offset + 1
end

function BufferUtil.writef32(b: buffer, offset: number, value: number)
	buffer.writef32(b, offset, value)
	return offset + 4
end

function BufferUtil.readf32(b: buffer, offset: number)
	return buffer.readf32(b, offset), offset + 4
end

function BufferUtil.writef64(b: buffer, offset: number, value: number)
	buffer.writef64(b, offset, value)
	return offset + 8
end

function BufferUtil.readf64(b: buffer, offset: number)
	return buffer.readf64(b, offset), offset + 8
end

function BufferUtil.writeu16(b: buffer, offset: number, value: number)
	buffer.writeu16(b, offset, value)
	return offset + 2
end

function BufferUtil.readu16(b: buffer, offset: number)
	return buffer.readu16(b, offset), offset + 2
end

function BufferUtil.writeu32(b: buffer, offset: number, value: number)
	buffer.writeu32(b, offset, value)
	return offset + 4
end

function BufferUtil.readu32(b: buffer, offset: number)
	return buffer.readu32(b, offset), offset + 4
end

function BufferUtil.writeColor_24(b: buffer, offset: number, color: Color3)
	offset = BufferUtil.writeu8(b, offset, color.R * 255)
	offset = BufferUtil.writeu8(b, offset, color.G * 255)
	offset = BufferUtil.writeu8(b, offset, color.B * 255)

	return offset
end

function BufferUtil.readColor_24(b: buffer, offset: number)
	local red, green, blue

	red, offset = BufferUtil.readu8(b, offset)
	green, offset = BufferUtil.readu8(b, offset)
	blue, offset = BufferUtil.readu8(b, offset)

	return Color3.fromRGB(red, green, blue), offset
end

function BufferUtil.writeVector3_96(b: buffer, offset: number, vector3: Vector3)
	offset = BufferUtil.writef32(b, offset, vector3.X)
	offset = BufferUtil.writef32(b, offset, vector3.Y)
	offset = BufferUtil.writef32(b, offset, vector3.Z)

	return offset
end

function BufferUtil.readVector3_96(b: buffer, offset: number)
	local x, y, z

	x, offset = BufferUtil.readf32(b, offset)
	y, offset = BufferUtil.readf32(b, offset)
	z, offset = BufferUtil.readf32(b, offset)

	return Vector3.new(x, y, z), offset
end

function BufferUtil.writeCFrame_144(b: buffer, offset: number, cframe: CFrame)
	local xr, yr, zr = cframe:ToOrientation()

	offset = BufferUtil.writeVector3_96(b, offset, cframe.Position)
	offset = BufferUtil.writeu16(b, offset, math.map(xr, -math.pi, math.pi, 0, 65535))
	offset = BufferUtil.writeu16(b, offset, math.map(yr, -math.pi, math.pi, 0, 65535))
	offset = BufferUtil.writeu16(b, offset, math.map(zr, -math.pi, math.pi, 0, 65535))

	return offset
end

function BufferUtil.readCFrame_144(b: buffer, offset: number)
	local position, xr, yr, zr

	position, offset = BufferUtil.readVector3_96(b, offset)
	xr, offset = BufferUtil.readu16(b, offset)
	yr, offset = BufferUtil.readu16(b, offset)
	zr, offset = BufferUtil.readu16(b, offset)

	xr = math.map(xr, 0, 65535, -math.pi, math.pi)
	yr = math.map(yr, 0, 65535, -math.pi, math.pi)
	zr = math.map(zr, 0, 65535, -math.pi, math.pi)

	return CFrame.fromOrientation(xr, yr, zr) + position, offset
end

-- Takes the size of both buffers and returns a new buffer containing both buffers in one.
function BufferUtil.combine(a: buffer, b: buffer)
	local aLength = buffer.len(a)
	local bLength = buffer.len(b)

	local newBuffer = buffer.create(aLength + bLength)
	buffer.copy(newBuffer, 0, a)
	buffer.copy(newBuffer, aLength, b)

	return newBuffer
end

function BufferUtil.duplicate(source: buffer, start: number, count: number?)
	local b = buffer.create(count or buffer.len(source))
	buffer.copy(b, 0, source, start, buffer.len(b))
	return b
end

function BufferUtil.inject(source: buffer, target: buffer, start: number, sourceStart: number?, count: number?)
	local offset = sourceStart or 0
	local bytes = count or (buffer.len(source) - offset)

	buffer.copy(target, start, source, offset, bytes)

	return start + bytes
end

-- Returns a buffer with X allocated bytes to it
-- - RETURNS: newBuffer: buffer, oldLength: number, newLength: number
function BufferUtil.allocate(b: buffer, bytes: number)
	local oldLength = buffer.len(b)
	local newLength = oldLength + bytes
	local newBuffer = buffer.create(newLength)

	buffer.copy(newBuffer, 0, b, 0, oldLength)

	return newBuffer, oldLength, newLength
end

-- Returns a buffer with "count" bytes removed starting at "start"
-- - RETURNS: newBuffer: buffer, newLength: number
function BufferUtil.deallocate(b: buffer, start: number, count: number?)
	local finish = start + (count or 1)
	local difference = finish - start

	local oldLength = buffer.len(b)
	local newLength = oldLength - difference

	local newBuffer = buffer.create(newLength)

	buffer.copy(newBuffer, 0, b, 0, start)
	buffer.copy(newBuffer, start, b, finish, oldLength - finish)

	return newBuffer, newLength
end

function BufferUtil.construct(
	typeValues: { { Type: BufferType, Value: number | Vector3 | CFrame } },
	totalSize: number?
)
	local byteSize = totalSize
	if not byteSize then
		byteSize = 0
		for _, v in next, typeValues do
			byteSize += TYPE_SIZES[TYPES[v.Type]]
		end
	end

	local b, offset = buffer.create(byteSize), 0
	for i = 1, #typeValues do
		local v = typeValues[i]
		offset = BufferUtil[`write{TYPES[v.Type]}`](b, offset, v.Value)
	end
	return b
end

function BufferUtil.deconstruct(b: buffer, types: { BufferType }, offset: number?)
	local currentOffset = offset or 0
	local values = table.create(#types + 1)

	for i = 1, #types do
		local value
		value, currentOffset = BufferUtil[`read{TYPES[types[i]]}`](b, currentOffset)
		values[i] = value
	end

	values[#types + 1] = currentOffset
	return table.unpack(values, 1, #types + 1)
end

function BufferUtil.deconstructTo<T...>(b: buffer, types: { BufferType }, callback: (T...) -> (), offset: number?)
	local currentOffset = offset or 0
	local values = table.create(#types)

	for i = 1, #types do
		local value
		value, currentOffset = BufferUtil[`read{TYPES[types[i]]}`](b, currentOffset)
		values[i] = value
	end

	callback(table.unpack(values))
	return currentOffset
end

return BufferUtil
