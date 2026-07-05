--[[
	AzeriteUI 3.3.5 port - Ascension client workarounds.

	1) Phantom focus guard: the Ascension client's internal chat-delay
	   editbox (anonymous, 0x0, parentless) can end up holding keyboard
	   focus permanently after AzeriteUI restyles the chat frames, eating
	   all key presses. A zero-sized editbox is never a legitimate typing
	   target, so focus on one is always bogus - clear it.

	2) Error capture fallback: the client's own error display bypasses
	   seterrorhandler; hook its display function if present.
]]
local Addon, ns = ...

local log = ns.Log335 or function() end

--------------------------------------------------------------
-- Phantom focus guard
--------------------------------------------------------------

local guard = CreateFrame("Frame")
local hider = CreateFrame("Frame")
hider:Hide()

local elapsed = 0
local neutered = {}

guard:SetScript("OnUpdate", function(self, e)
	elapsed = elapsed + e
	if elapsed < 0.2 then return end
	elapsed = 0

	if not GetCurrentKeyBoardFocus then return end
	local focus = GetCurrentKeyBoardFocus()
	if not focus then return end
	if not (focus.IsObjectType and focus:IsObjectType("EditBox")) then return end

	local w = (focus.GetWidth and focus:GetWidth()) or 0
	local h = (focus.GetHeight and focus:GetHeight()) or 0
	if w < 2 and h < 2 then
		-- ClearFocus alone is not enough: the client re-focuses this box.
		-- Reparent it under a permanently hidden frame so it can never
		-- receive keyboard focus again.
		if focus.ClearFocus then
			focus:ClearFocus()
		end
		if not neutered[focus] then
			neutered[focus] = true
			local name = (focus.GetName and focus:GetName()) or "(anonymous)"
			local ok = pcall(function()
				focus:SetParent(hider)
				focus:EnableKeyboard(false)
				if focus.HookScript then
					focus:HookScript("OnEditFocusGained", function(self) self:ClearFocus() end)
				end
			end)
			log("FIX", string.format("neutered phantom focus editbox %s (reparent=%s)", name, tostring(ok)))
		end
	end
end)

--------------------------------------------------------------
-- Error capture fallback via the client's error display
--------------------------------------------------------------

local errloader = CreateFrame("Frame")
errloader:RegisterEvent("PLAYER_LOGIN")
errloader:SetScript("OnEvent", function(self)
	-- report what error machinery this client actually has
	log("INFO", string.format("error machinery: ScriptErrorsFrame=%s ScriptErrorsFrame_OnError=%s debuglocals=%s BasicScriptErrorsText=%s",
		type(_G.ScriptErrorsFrame), type(_G.ScriptErrorsFrame_OnError), type(_G.debuglocals), type(_G.BasicScriptErrorsText)))

	if type(_G.ScriptErrorsFrame_OnError) == "function" and hooksecurefunc then
		hooksecurefunc("ScriptErrorsFrame_OnError", function(message)
			log("ERROR", "via ScriptErrorsFrame: " .. tostring(message))
		end)
		log("INFO", "hooked ScriptErrorsFrame_OnError")
	end

	-- BasicScriptErrors path (the simple red error dialog)
	if _G.BasicScriptErrorsText and _G.BasicScriptErrorsText.SetText then
		if hooksecurefunc then
			hooksecurefunc(_G.BasicScriptErrorsText, "SetText", function(self, text)
				if text and text ~= "" then
					log("ERROR", "via BasicScriptErrors: " .. tostring(text))
				end
			end)
			log("INFO", "hooked BasicScriptErrorsText")
		end
	end
end)
