function f_b64(prod)
	local base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
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
				if coroutine.status(prod) == "dead" then
					if s ~= "" then padd = 3 - (s:len() % 3) end
					s = s .. string.rep("\000", padd)
					break
				end
			until s:len() >= 3
			local ret = {}
			local mod = s:len() % 3
			for i = 1, s:len() - mod, 3 do
				local bits = s:byte(i) * 2^16 + s:byte(i + 1) * 2^8 + s:byte(i + 2)
				local s64 = ""
				for n = 1, 4 do
					local index = bits % 64 + 1
					if n > padd then s64 = base64:sub(index, index) .. s64 end
					bits = math.floor(bits / 64)
				end
				table.insert(ret, s64)
			end
			if mod == 0 then s = "" else s = s:sub(-mod) end
			if padd ~= 0 then table.insert(ret, string.rep("=", padd)) end
			send(table.concat(ret))
		end
	end)
end

function f_b64_meta(prod)
	local base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local base64memoize = {}
	setmetatable(base64memoize, { __index = function (t, s3)
			local bits = s3:byte(1) * 2^16 + s3:byte(2) * 2^8 + s3:byte(3)
			local s64 = ""
			for n = 1, 4 do
				local index = bits % 64 + 1
				s64 = base64:sub(index, index) .. s64
				bits = math.floor(bits / 64)
			end
			t[s3] = s64
			return s64
	end })
						
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
				table.insert(ret, base64memoize[sub3])
			end
			if coroutine.status(prod) == "dead" and mod > 0 then
				local subs = s:sub(s:len() - mod, -1)
				local padd = 3 - subs:len()
				subs = base64memoize[subs .. ("\000"):rep(padd)]
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

consumer(f_b64_meta(producer_file(...)))
--consumer(f_b64(producer_file(...)))
