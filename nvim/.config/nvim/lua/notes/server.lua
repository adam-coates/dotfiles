-- A small HTTP server inside Neovim for the pages that need a browser (graph,
-- canvas). It listens on 127.0.0.1 only, answers only requests addressed to
-- 127.0.0.1 or localhost (so a web page can't reach it by rebinding DNS), and
-- only with this session's random token.

local util = require("notes.util")

local M = {}

local server ---@type uv.uv_tcp_t?
local port, token
local routes = {} ---@type table<string, fun(req: table): (string, string, string)?>
local streams = {} ---@type table<uv.uv_tcp_t, boolean>

local MAX_BODY = 32 * 1024 * 1024

local function respond(client, status, mime, body)
	local head = {
		"HTTP/1.1 " .. status,
		"Content-Type: " .. mime,
		"Content-Length: " .. #body,
		"Cache-Control: no-store",
		"X-Content-Type-Options: nosniff",
		"Connection: close",
		"",
		"",
	}
	client:write(table.concat(head, "\r\n") .. body, function()
		if not client:is_closing() then
			client:close()
		end
	end)
end

local function decode(text)
	return (text:gsub("+", " "):gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function encode(text)
	return (tostring(text):gsub("[^%w%-_%.~/]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
end

local function handle(client, head, body)
	local method, target = head:match("^(%u+) (%S+) HTTP")
	local host = head:match("\r\n[Hh]ost:%s*([^\r\n]+)")
	local origin = head:match("\r\n[Oo]rigin:%s*([^\r\n]+)")
	local ours = { ["127.0.0.1:" .. port] = true, ["localhost:" .. port] = true }
	if not method or not ours[host] then
		return respond(client, "403 Forbidden", "text/plain", "forbidden")
	end
	-- A write must come from our own page.
	if method ~= "GET" and origin and not ours[origin:gsub("^https?://", "")] then
		return respond(client, "403 Forbidden", "text/plain", "forbidden")
	end
	local path, query = target:match("^([^?]*)%??(.*)$")
	local args = {}
	for key, value in query:gmatch("([^&=]+)=([^&]*)") do
		args[decode(key)] = decode(value)
	end
	if args.t ~= token then
		return respond(client, "403 Forbidden", "text/plain", "forbidden")
	end
	if path == "/events" and method == "GET" then
		client:write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\nConnection: keep-alive\r\n\r\n: hello\n\n")
		streams[client] = args.topic or true
		return
	end
	local route = routes[path]
	if not route then
		return respond(client, "404 Not Found", "text/plain", "not found")
	end
	local status, mime, out = route({ method = method, path = path, args = args, body = body })
	respond(client, status or "200 OK", mime or "text/plain; charset=utf-8", out or "")
end

function M.start()
	if server then
		return true
	end
	server = assert(vim.uv.new_tcp())
	server:bind("127.0.0.1", 0)
	local name = server:getsockname()
	if not name then
		server:close()
		server = nil
		return false
	end
	port = name.port
	token = vim.fn.sha256(tostring(vim.uv.hrtime()) .. vim.uv.random(16)):sub(1, 32)
	server:listen(64, function(err)
		if err or not server then
			return
		end
		local client = assert(vim.uv.new_tcp())
		server:accept(client)
		local buffer, head, need = "", nil, nil
		client:read_start(function(read_err, chunk)
			if read_err or not chunk then
				streams[client] = nil
				if not client:is_closing() then
					client:close()
				end
				return
			end
			buffer = buffer .. chunk
			if not head then
				local stop = buffer:find("\r\n\r\n", 1, true)
				if not stop then
					if #buffer > 16384 then
						client:close()
					end
					return
				end
				head = buffer:sub(1, stop + 3)
				buffer = buffer:sub(stop + 4)
				need = tonumber(head:match("\r\n[Cc]ontent%-[Ll]ength:%s*(%d+)")) or 0
				if need > MAX_BODY then
					return client:close()
				end
			end
			if #buffer >= need then
				local h, body = head, buffer:sub(1, need)
				head, buffer = nil, ""
				vim.schedule(function()
					if not client:is_closing() then
						local ok, problem = pcall(handle, client, h, body)
						if not ok and not client:is_closing() then
							respond(client, "500 Internal Server Error", "text/plain", tostring(problem))
						end
					end
				end)
			end
		end)
	end)
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("notes_server", { clear = true }),
		callback = M.stop,
	})
	return true
end

function M.stop()
	for client in pairs(streams) do
		if not client:is_closing() then
			client:close()
		end
	end
	streams = {}
	if server and not server:is_closing() then
		server:close()
	end
	server = nil
end

--- Answer requests to `path`. The handler gets { method, args, body } and
--- returns status, content type and body.
function M.route(path, handler)
	routes[path] = handler
end

--- Send an event to the pages listening on a topic.
function M.send(topic, event, payload)
	local text = "event: " .. event .. "\ndata: " .. vim.json.encode(payload) .. "\n\n"
	for client, listening in pairs(streams) do
		if client:is_closing() then
			streams[client] = nil
		elseif listening == true or listening == topic then
			client:write(text, function(err)
				if err then
					streams[client] = nil
				end
			end)
		end
	end
end

--- The address of a page, with the token.
function M.url(path, args)
	local parts = { "t=" .. token }
	for key, value in vim.spairs(args or {}) do
		parts[#parts + 1] = key .. "=" .. encode(value)
	end
	return ("http://127.0.0.1:%d%s?%s"):format(port, path, table.concat(parts, "&"))
end

--- A page from assets/, with the token filled in.
function M.page(name)
	local html = util.read(vim.fn.stdpath("config") .. "/assets/" .. name) or (name .. " is missing")
	return "200 OK", "text/html; charset=utf-8", (html:gsub("__TOKEN__", token))
end

return M
