local ResponseCodes = {}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local messages: { [number]: string } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- Success
ResponseCodes.Ok = 200
ResponseCodes.Created = 201
ResponseCodes.Prompted = 202
ResponseCodes.Sent = 203

-- Client errors
ResponseCodes.BadRequest = 400
ResponseCodes.Unauthorized = 401
ResponseCodes.Forbidden = 403
ResponseCodes.NotFound = 404
ResponseCodes.Conflict = 409
ResponseCodes.UnprocessableEntity = 422
ResponseCodes.TooManyRequests = 429

-- Server errors
ResponseCodes.InternalError = 500
ResponseCodes.NotImplemented = 501
ResponseCodes.ServiceUnavailable = 503

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ResponseCodes.getMessage(code: number): string
	return messages[code] or `Unknown Code ({code})`
end

function ResponseCodes.isSuccess(code: number): boolean
	return code >= 200 and code < 300
end

function ResponseCodes.isError(code: number): boolean
	return code >= 400
end

-------------------------------------------------------------------------------
-- LOGIC
-------------------------------------------------------------------------------

for name, code in ResponseCodes do
	if type(code) == "number" then
		messages[code] = name:gsub("(%l)(%u)", "%1 %2")
	end
end

return ResponseCodes
