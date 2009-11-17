function f_b64(prod, b64memoize)
	if type(prod) ~= "thread" or b64memoize ~= false and type(b64memoize) ~= "table" then error("Wrong arg types to f_b64", 2) end
	local base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	if b64memoize ~= false then setmetatable(b64memoize, { __mode = "v" }) end
	local function tob64(s3)
		if b64memoize == false or b64memoize[s3] == nil then
			local bits = s3:byte(1) * 2^16 + s3:byte(2) * 2^8 + s3:byte(3)
			local s64 = ""
			for n = 1, 4 do
				local index = bits % 64 + 1
				s64 = base64:sub(index, index) .. s64
				bits = math.floor(bits / 64)
			end
			if b64memoize ~= false then b64memoize[s3] = s64 end
			return s64
		else
			return b64memoize[s3]
		end
	end
	local function recv()
		local status, s = coroutine.resume(prod)
		return s
	end
	local send = coroutine.yield
	return coroutine.create(function ()
		local s = ""
		while coroutine.status(prod) ~= "dead" do
			local padd = 0
			repeat
				s = s .. recv()
			until s:len() >= 3 or coroutine.status(prod) == "dead"
			local ret = {}
			local mod = s:len() % 3
			for i = 1, s:len() - mod, 3 do
				local sub3 = s:sub(i, i + 3)
				table.insert(ret, tob64(sub3))
			end
			if coroutine.status(prod) == "dead" and mod > 0 then
				local subs = s:sub(s:len() - mod, -1)
				local padd = 3 - subs:len()
				subs = tob64(subs .. ("\000"):rep(padd))
				table.insert(ret, subs:sub(1, 4 - padd) .. ("="):rep(padd))
			end
			if mod == 0 then s = "" else s = s:sub(-mod) end
			if padd ~= 0 then table.insert(ret, string.rep("=", padd)) end
			send(table.concat(ret))
		end
	end)
end

function producer()
	return coroutine.create(function ()
		while true do
			local x = io.read()
			if x == "" then return x end
			coroutine.yield(x)
		end
	end)
end

function producer_file(file)
	return coroutine.create(function ()
		local filefd = io.open(file, "r")
		while true do
			local x = filefd:read(10000)
			if x == nil then
				filefd:close()
				return ""
			end
			coroutine.yield(x)
		end
	end)
end

function consumer(prod)
	local function recv()
		local status, s = coroutine.resume(prod)
		return s
	end
	while true do
		local x = recv()
		if x == nil then break end
		io.write(x)
	end
end

local t = {}
consumer(f_b64(producer_file(...), t))
consumer(f_b64(producer_file(...), t))
