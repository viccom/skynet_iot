local class = require 'middleclass'
local socket = require 'skynet.socket'
local sc = require "skynet.socketchannel"
local serialchannel = require 'serialchannel'

local app = class("viccom_demo_APP_CLASS")

nums = 100
coilnums = 16

function hstr2bin( hexs )
		local bins = ""
		for i = 1, string.len(hexs) - 1, 2 do
		local doublebytestr = string.sub(hexs, i, i+1);
		local n = tonumber(doublebytestr, 16);
		local binx = string.format("%c", n)
		bins = bins..binx
		end
		return bins
end
function hex(s)
	if (s ~= nil) then
		s=string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
		return s
	end
	return nil
end

local function create_msg_resp(cb)
	return function(sock)
		cb()
		local ret1 = sock:read(6, 1000)
		-- print(ret1)
		-- print(hex(ret1))
		if (#ret1 == 6) then
			local ret2, err = sock:read(3, 1000)
			-- print(hex(ret2))
			if (hex(ret2) ~= "018302") then
				data_len=string.unpack('>B', ret2, 3)
				-- print(data_len)
				local ret3, err = sock:read(data_len, 1000)
				-- print("Received message:", hex(ret2)..hex(ret3))

				return true, ret2..ret3
			else
				-- print("Received message:", hex(ret2))

				return true, ret2
			end
			return true, nil
		end
		return true, nil
	end
end

local function create_coilmsg_resp(cb)
	return function(sock)
		local ret1 = sock:read(6, 1000)
		cb()
		-- print(ret1)
		-- print(hex(ret1))
		if (#ret1 == 6) then
			local ret2, err = sock:read(3, 1000)
			-- print(hex(ret2))
			if (hex(ret2) ~= "018102") then
				data_len=string.unpack('>B', ret2, 3)
				-- print(data_len)
				local ret3, err = sock:read(data_len, 1000)
				-- print("Received message:", hex(ret2)..hex(ret3))

				return true, ret2..ret3
			else
				-- print("Received message:", hex(ret2))

				return true, ret2
			end
			return true, nil
		end
		return true, nil
	end
end

function app:initialize(name, conf, sys)
	self._name = name
	self._conf = conf
	self._sys = sys
	self._api = self._sys:data_api()
	self._log = sys:logger()
end

function app:start()
	self._api:set_handler({
		on_output = function(app, sn, output, prop, value)
			print('on_output', app, sn, output, prop, value)
			return true, "done"
		end,
		on_ctrl = function(app, sn, command, param, ...)
			print('on_ctrl', app, sn ,command, param, ...)
		end,
	})

	local sys_id = self._sys:id()
	local dev_sn = sys_id.."."..self._sys:gen_sn("bg")
	local inputs = {}
	for i=1,nums do
		table.insert( inputs, {
			name = 'tag'..i,
			desc = 'tag'..i,
			auth = "rw",
			} )
	end
	for i=1,coilnums do
		table.insert( inputs, {
			name = 'DI'..i,
			desc = 'DI'..i,
			vt = 'int',
			auth = "rw",
			} )
	end
	self._inputs = inputs
	self._dev = self._api:add_device(dev_sn, inputs, outputs)

	return true
end

function app:close(reason)
	--print(self._name, reason)
	if self._cancel_uptime_timer then
		self._cancel_uptime_timer()
		self._cancel_uptime_timer = nil
	end
end

channel = sc.channel {
		host = "192.168.174.1",
		port = 502,
	}


tn = '>'..string.rep('f',(nums/2)-1)

function app:run(tms)
	---[[ 
	local reqmsg = string.pack('>i4i2bbi2bb', 0, 0, 1, 3, 0, 0, nums)
	-- print("send message:", hex(reqmsg))
	--self._dev:dump_comm('OUT', string.sub(reqmsg, 7, -1))

	local r, resp, err = pcall(function(reqmsg)
		return channel:request(reqmsg, create_msg_resp(function() 
			self._dev:dump_comm('OUT', string.sub(reqmsg, 7, -1))
			end))	
		end, reqmsg)
	-- print(r)


	if r then
		-- self._log:info("read successful: " .. "AI")
		self._dev:dump_comm('IN', resp)
		local now = self._sys:time()
		resp=string.sub(resp, 4, -1)		
		if resp then

			local t = {string.unpack(tn, resp)}
			for i, v in ipairs(t) do
				-- print("标签:"..self._inputs[i]["name"].."  时间:"..os.date('%Y-%m-%d %H:%M:%S').."  数值:"..v)
				self._dev:set_input_prop(self._inputs[i]["name"], "value", v, now, 0)
			end
		end
	else
		self._log:warning("read failed: ")
		tag1value = self._dev:get_input_prop("tag1", "value")
		-- print(tag1value)
		tagt = self._inputs
		for i, v in ipairs(tagt) do
			lastvalue = self._dev:get_input_prop(v.name, "value")
			if not nil then
				self._dev:set_input_prop(v.name, "value", lastvalue, now, 99)
			end
		end
	end
	--]] 
	-- tag1value = self._dev:get_input_prop("tag1", "value")
	-- print(tag1value)

	-- local resp ,err = channel:request(reqmsg, msgresponse)
	-- print(err)
	-- if (resp ~= nil) then
	-- 	self._dev:dump_comm('IN', resp)
	-- 	local t = {string.unpack(tn, resp)}
	-- 	for i, v in ipairs(t) do
	-- 		-- print("标签:"..self._inputs[i]["name"].."  时间:"..os.date('%Y-%m-%d %H:%M:%S').."  数值:"..v)
	-- 		self._dev:set_input_prop(self._inputs[i]["name"], "value", v)
	-- 	end

	-- else
	-- 	print(err)
	-- end

	---[[ 
	local coilreqmsg = string.pack('>i4i2bbi2bb', 0, 0, 1, 1, 0, 0, coilnums)
	-- print("send message:", hex(coilreqmsg))
	-- self._dev:dump_comm('OUT', string.sub(coilreqmsg, 7, -1))
	local ditags = {}
	for i=1,coilnums do
		table.insert( ditags, {
			name = 'DI'..i,
			desc = 'DI'..i,
			vt = 'int',
			auth = "rw",
			} )
	end

	local cr, coilresp, err = pcall(function(coilreqmsg)
		return channel:request(coilreqmsg, create_msg_resp(function() 
			self._dev:dump_comm('OUT', string.sub(coilreqmsg, 7, -1))
			end))
		end, coilreqmsg)
	-- print(cr)


	if cr then
		-- self._log:info("read successful: " .. "DI")
		self._dev:dump_comm('IN', coilresp)
		local now = self._sys:time()
		coilresp=string.sub(coilresp, 4, -1)		
		if coilresp then

			for i, v in ipairs(ditags) do
				i = i - 1
				local index = math.floor(i / 8) + 1
				local bindex = i % 8

				if index > string.len(coilresp) then
					--- ERROR
				end

				local b = string.sub(coilresp, index, index)
				local value = string.byte(b)
				value = 1 & (value >> bindex)
				self._dev:set_input_prop(v.name, "value", value)
				-- print(v.name, value)
			end
		end

	else
		self._log:warning("read failed: ")
		for i, v in ipairs(ditags) do
			lastvalue = self._dev:get_input_prop(v.name, "value")
			if not nil then
				self._dev:set_input_prop(v.name, "value", lastvalue, now, 99)
			end
		end
	end
	--]] 
	return 1000 * 1
end

return app

