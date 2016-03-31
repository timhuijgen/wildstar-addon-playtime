function _dump(o)
	if type(o) == 'string' or type(o) == 'number' or type(o) == 'boolean' or type(o) then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, tostring(o), "")
	elseif type(o) == 'function' or type(o) == 'nil' then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, type(o), "")
	else
		_dumpTable(o)
	end
end

function _dumpTable(o)
	local data = _getAllData(o)
	
	if type(data) == 'table' then
		for key, value in pairs(data) do
			if type(value) == 'string' or type(value) == 'number'or type(value) == 'boolean' or type(value) then
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, tostring(key)..' -> '..tostring(value), "")
			else
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, tostring(key), "")
			end
		end
	end
end

function _getAllData(t, prevData)

	local data = prevData or {}
	
	if type(t) == 'table' then
		for k,v in pairs(t) do
			if not data[k] then data[k] = v end
		end
	end
	
	local mt = getmetatable(t)
	if type(mt)~='table' then return data end
	
	local index = mt.__index
	if type(index)~='table' then return data end
	
	return _getAllData(index, data)
end