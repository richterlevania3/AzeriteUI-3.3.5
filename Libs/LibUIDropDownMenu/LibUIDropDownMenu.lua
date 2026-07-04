--[[
	LibUIDropDownMenu-4.0 adapter for 3.3.5.

	The real library is a taint-free copy of retail's UIDropDownMenu.
	On 3.3.5 the native UIDropDownMenu is perfectly usable, so this
	adapter simply maps the Lib API onto the native functions.
]]
local lib = LibStub:NewLibrary("LibUIDropDownMenu-4.0", 1)
if not lib then return end

function lib:Create_UIDropDownMenu(name, parent)
	return CreateFrame("Frame", name, parent or UIParent, "UIDropDownMenuTemplate")
end

function lib:UIDropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList)
	return UIDropDownMenu_Initialize(frame, initFunction, displayMode, level, menuList)
end

function lib:UIDropDownMenu_AddButton(info, level)
	return UIDropDownMenu_AddButton(info, level)
end

function lib:UIDropDownMenu_CreateInfo()
	return UIDropDownMenu_CreateInfo()
end

function lib:UIDropDownMenu_SetWidth(frame, width, padding)
	return UIDropDownMenu_SetWidth(frame, width, padding)
end

function lib:UIDropDownMenu_SetText(frame, text)
	return UIDropDownMenu_SetText(frame, text)
end

function lib:UIDropDownMenu_SetSelectedValue(frame, value)
	return UIDropDownMenu_SetSelectedValue(frame, value)
end

function lib:UIDropDownMenu_GetSelectedValue(frame)
	return UIDropDownMenu_GetSelectedValue(frame)
end

function lib:UIDropDownMenu_SetAnchor(dropdown, xOffset, yOffset, point, relativeTo, relativePoint)
	dropdown.xOffset = xOffset
	dropdown.yOffset = yOffset
	dropdown.point = point
	dropdown.relativeTo = relativeTo
	dropdown.relativePoint = relativePoint
end

function lib:ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay)
	return ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset)
end

function lib:CloseDropDownMenus(level)
	return CloseDropDownMenus(level)
end

function lib:UIDropDownMenu_AddSeparator(level)
	local info = UIDropDownMenu_CreateInfo()
	info.text = ""
	info.disabled = true
	info.notClickable = true
	return UIDropDownMenu_AddButton(info, level)
end
