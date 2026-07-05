--[[
	AzeriteUI 3.3.5 port - diagnostic logger.

	Captures Lua errors and port diagnostics into the AzeriteUI335_Log
	saved variable so they can be inspected outside the game after logout.

	Slash commands:
	  /azlog        - print summary (compat state + recent errors)
	  /azlog kb     - list visible keyboard-enabled frames (input-grab hunt)
	  /azlog wipe   - clear the stored log
]]
local Addon, ns = ...

local MAXLOG = 300

-- session-local buffer; merged into the saved variable at ADDON_LOADED
local buffer = {}
local sessionStamp = date("%Y-%m-%d %H:%M:%S")

local function rawlog(kind, msg)
	local entry = string.format("[%s][%s] %s", date("%H:%M:%S"), kind, tostring(msg))
	local log = _G.AzeriteUI335_Log
	if log then
		table.insert(log, entry)
		while table.getn and table.getn(log) > MAXLOG do
			table.remove(log, 1)
		end
		while #log > MAXLOG do
			table.remove(log, 1)
		end
	else
		table.insert(buffer, entry)
	end
	return entry
end

local function log(kind, msg)
	rawlog(kind, msg)
end
ns.Log335 = log

--------------------------------------------------------------
-- Error trap: chain into the current error handler
--------------------------------------------------------------

local seenErrors = {}
local origHandler = geterrorhandler()

seterrorhandler(function(msg)
	msg = tostring(msg)
	local count = (seenErrors[msg] or 0) + 1
	seenErrors[msg] = count
	if count <= 3 then
		local stack = debugstack and debugstack(3, 8, 2) or "no stack"
		log("ERROR", msg .. "\n" .. stack)
	elseif count == 4 then
		log("ERROR", "(suppressing further repeats) " .. msg)
	end
	if origHandler then
		return origHandler(msg)
	end
end)

--------------------------------------------------------------
-- Saved variable hookup
--------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == Addon then
		if type(_G.AzeriteUI335_Log) ~= "table" then
			_G.AzeriteUI335_Log = {}
		end
		local logvar = _G.AzeriteUI335_Log
		table.insert(logvar, "===== session " .. sessionStamp .. " =====")
		for _, entry in ipairs(buffer) do
			table.insert(logvar, entry)
		end
		buffer = {}

		-- record the environment + compat report
		local c = _G.AzeriteUI335_Compat
		if c then
			log("INFO", string.format("client %s build %s toc %s legacy=%s",
				tostring(c.version), tostring(c.build), tostring(c.tocversion), tostring(c.legacy)))
			if c.state then
				local parts = {}
				for k, v in pairs(c.state) do
					table.insert(parts, k .. "=" .. tostring(v))
				end
				table.sort(parts)
				log("INFO", "compat state: " .. table.concat(parts, ", "))
			end
		else
			log("WARN", "AzeriteUI335_Compat missing - compat layer did not run!")
		end
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		log("INFO", "PLAYER_LOGIN reached")
	end
end)

log("INFO", "logger active, addon " .. tostring(Addon))

--------------------------------------------------------------
-- /azlog
--------------------------------------------------------------

local function chat(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff4488bbAzLog:|r " .. tostring(msg))
end

SLASH_AZLOG1 = "/azlog"
SlashCmdList["AZLOG"] = function(input)
	input = string.lower(input or "")

	if input == "wipe" then
		_G.AzeriteUI335_Log = {}
		seenErrors = {}
		chat("log wiped")
		return
	end

	if input == "kb" then
		-- hunt for whatever is eating keyboard input
		chat("visible keyboard-enabled frames:")
		local frame = EnumerateFrames()
		local found = 0
		while frame do
			local ok, vis = pcall(frame.IsVisible, frame)
			local ok2, kb = pcall(frame.IsKeyboardEnabled, frame)
			if ok and ok2 and vis and kb then
				found = found + 1
				local name = frame.GetName and frame:GetName() or nil
				local msg = string.format("%d. %s (strata %s, level %s)",
					found, name or "(anonymous)", frame:GetFrameStrata() or "?", frame:GetFrameLevel() or -1)
				chat(msg)
				log("KBSCAN", msg)
			end
			frame = EnumerateFrames(frame)
		end
		if found == 0 then
			chat("none found")
			log("KBSCAN", "no visible keyboard-enabled frames")
		end
		return
	end

	-- default: summary
	local c = _G.AzeriteUI335_Compat
	if c then
		chat(string.format("client %s toc %s legacy=%s", tostring(c.version), tostring(c.tocversion), tostring(c.legacy)))
	else
		chat("compat layer DID NOT RUN")
	end
	local logvar = _G.AzeriteUI335_Log or {}
	local n = #logvar
	chat(string.format("%d log entries; last errors:", n))
	local shown = 0
	for i = n, 1, -1 do
		if string.find(logvar[i], "[ERROR]", 1, true) then
			chat(string.sub(logvar[i], 1, 200))
			shown = shown + 1
			if shown >= 5 then break end
		end
	end
	if shown == 0 then
		chat("no errors recorded")
	end
end
