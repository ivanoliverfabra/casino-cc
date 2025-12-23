-- Musiclo music player made by timuzkas
-- edited by Fabra (Volume control)
-- licensed under Creative Commons CC0
-- Simple, sleek player for YT.
-- //
-- //
-- Backend code from @terreng on github, using MIT license
-- Frontend code by timuzkas, using MIT license
-- Transliterator by timuzkas, using MIT license
-- PrimeUI by JackMacWindows, using CC0 license

local expect = require("cc.expect").expect

local PrimeUI = {}
do
	local coros = {}
	local restoreCursor

	function PrimeUI.addTask(func)
		expect(1, func, "function")
		local t = { coro = coroutine.create(func) }
		coros[#coros + 1] = t
		_, t.filter = coroutine.resume(t.coro)
	end

	function PrimeUI.resolve(...)
		coroutine.yield(coros, ...)
	end

	function PrimeUI.clear()
		term.setCursorPos(1, 1)
		term.setCursorBlink(false)
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
		term.clear()

		coros = {}
		restoreCursor = nil
	end

	function PrimeUI.setCursorWindow(win)
		expect(1, win, "table", "nil")
		restoreCursor = win and win.restoreCursor
	end

	function PrimeUI.getWindowPos(win, x, y)
		if win == term then
			return x, y
		end
		while win ~= term.native() and win ~= term.current() do
			if not win.getPosition then
				return x, y
			end
			local wx, wy = win.getPosition()
			x, y = x + wx - 1, y + wy - 1
			_, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1)
		end
		return x, y
	end

	function PrimeUI.run()
		while true do
			if restoreCursor then
				restoreCursor()
			end
			local ev = table.pack(os.pullEvent())

			for _, v in ipairs(coros) do
				if v.filter == nil or v.filter == ev[1] then
					local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))

					if not res[1] then
						error(res[2], 2)
					end

					if res[2] == coros then
						return table.unpack(res, 3, res.n)
					end

					v.filter = res[2]
				end
			end
		end
	end
end

function PrimeUI.borderBox(win, x, y, width, height, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, height, "number")
	fgColor = expect(6, fgColor, "number", "nil") or colors.white
	bgColor = expect(7, bgColor, "number", "nil") or colors.black

	win.setBackgroundColor(bgColor)
	win.setTextColor(fgColor)
	win.setCursorPos(x - 1, y - 1)
	win.write("\x9C" .. ("\x8C"):rep(width))

	win.setBackgroundColor(fgColor)
	win.setTextColor(bgColor)
	win.write("\x93")

	for i = 1, height do
		win.setCursorPos(win.getCursorPos() - 1, y + i - 1)
		win.write("\x95")
	end

	win.setBackgroundColor(bgColor)
	win.setTextColor(fgColor)
	for i = 1, height do
		win.setCursorPos(x - 1, y + i - 1)
		win.write("\x95")
	end

	win.setCursorPos(x - 1, y + height)
	win.write("\x8D" .. ("\x8C"):rep(width) .. "\x8E")
end

function PrimeUI.button(win, x, y, text, action, fgColor, bgColor, clickedColor, periphName)
	expect(1, win, "table")
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, text, "string")
	expect(5, action, "function", "string")
	fgColor = expect(6, fgColor, "number", "nil") or colors.white
	bgColor = expect(7, bgColor, "number", "nil") or colors.gray
	clickedColor = expect(8, clickedColor, "number", "nil") or colors.lightGray
	periphName = expect(9, periphName, "string", "nil")

	win.setCursorPos(x, y)
	win.setBackgroundColor(bgColor)
	win.setTextColor(fgColor)
	win.write(" " .. text .. " ")

	PrimeUI.addTask(function()
		local buttonDown = false
		while true do
			local event, button, clickX, clickY = os.pullEvent()
			local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
			if
				event == "mouse_click"
				and periphName == nil
				and button == 1
				and clickX >= screenX
				and clickX < screenX + #text + 2
				and clickY == screenY
			then
				buttonDown = true

				win.setCursorPos(x, y)
				win.setBackgroundColor(clickedColor)
				win.setTextColor(fgColor)
				win.write(" " .. text .. " ")
			elseif
				(
					event == "monitor_touch"
					and periphName == button
					and clickX >= screenX
					and clickX < screenX + #text + 2
					and clickY == screenY
				) or (event == "mouse_up" and button == 1 and buttonDown)
			then
				if clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
					if type(action) == "string" then
						PrimeUI.resolve("button", action)
					else
						action()
					end
				end

				win.setCursorPos(x, y)
				win.setBackgroundColor(bgColor)
				win.setTextColor(fgColor)
				win.write(" " .. text .. " ")
			end
		end
	end)
end

function PrimeUI.centerLabel(win, x, y, width, text, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, text, "string")
	fgColor = expect(6, fgColor, "number", "nil") or colors.white
	bgColor = expect(7, bgColor, "number", "nil") or colors.black
	assert(#text <= width, "string is too long")
	win.setCursorPos(x + math.floor((width - #text) / 2), y)
	win.setTextColor(fgColor)
	win.setBackgroundColor(bgColor)
	win.write(text)
end

function PrimeUI.checkSelectionBox(win, x, y, width, height, selections, action, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, height, "number")
	expect(6, selections, "table")
	expect(7, action, "function", "string", "nil")
	fgColor = expect(8, fgColor, "number", "nil") or colors.white
	bgColor = expect(9, bgColor, "number", "nil") or colors.black

	local nsel = 0
	for _ in pairs(selections) do
		nsel = nsel + 1
	end

	local outer = window.create(win, x, y, width, height)
	outer.setBackgroundColor(bgColor)
	outer.clear()

	local inner = window.create(outer, 1, 1, width - 1, nsel)
	inner.setBackgroundColor(bgColor)
	inner.setTextColor(fgColor)
	inner.clear()

	local lines = {}
	local nl, selected = 1, 1
	for k, v in pairs(selections) do
		inner.setCursorPos(1, nl)
		inner.write((v and (v == "R" and "[-] " or "[\xD7] ") or "[ ] ") .. k)
		lines[nl] = { k, not not v }
		nl = nl + 1
	end

	if nsel > height then
		outer.setCursorPos(width, height)
		outer.setBackgroundColor(bgColor)
		outer.setTextColor(fgColor)
		outer.write("\31")
	end

	inner.setCursorPos(2, selected)
	inner.setCursorBlink(true)
	PrimeUI.setCursorWindow(inner)

	local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
	PrimeUI.addTask(function()
		local scrollPos = 1
		while true do
			local ev = table.pack(os.pullEvent())

			local dir
			if ev[1] == "key" then
				if ev[2] == keys.up then
					dir = -1
				elseif ev[2] == keys.down then
					dir = 1
				elseif ev[2] == keys.space and selections[lines[selected][1]] ~= "R" then
					lines[selected][2] = not lines[selected][2]
					inner.setCursorPos(2, selected)
					inner.write(lines[selected][2] and "\xD7" or " ")

					if type(action) == "string" then
						PrimeUI.resolve("checkSelectionBox", action, lines[selected][1], lines[selected][2])
					elseif action then
						action(lines[selected][1], lines[selected][2])
					else
						selections[lines[selected][1]] = lines[selected][2]
					end

					for i, v in ipairs(lines) do
						local vv = selections[v[1]] == "R" and "R" or v[2]
						inner.setCursorPos(2, i)
						inner.write((vv and (vv == "R" and "-" or "\xD7") or " "))
					end
					inner.setCursorPos(2, selected)
				end
			elseif
				ev[1] == "mouse_scroll"
				and ev[3] >= screenX
				and ev[3] < screenX + width
				and ev[4] >= screenY
				and ev[4] < screenY + height
			then
				dir = ev[2]
			end

			if dir and (selected + dir >= 1 and selected + dir <= nsel) then
				selected = selected + dir
				if selected - scrollPos < 0 or selected - scrollPos >= height then
					scrollPos = scrollPos + dir
					inner.reposition(1, 2 - scrollPos)
				end
				inner.setCursorPos(2, selected)
			end

			outer.setCursorPos(width, 1)
			outer.write(scrollPos > 1 and "\30" or " ")
			outer.setCursorPos(width, height)
			outer.write(scrollPos < nsel - height + 1 and "\31" or " ")
			inner.restoreCursor()
		end
	end)
end

function PrimeUI.clickRegion(win, x, y, width, height, action, periphName)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, height, "number")
	expect(6, action, "function", "string")
	expect(7, periphName, "string", "nil")
	PrimeUI.addTask(function()
		local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
		local buttonDown = false
		while true do
			local event, button, clickX, clickY = os.pullEvent()
			if
				(event == "monitor_touch" and periphName == button)
				or (event == "mouse_click" and button == 1 and periphName == nil)
			then
				if
					clickX >= screenX
					and clickX < screenX + width
					and clickY >= screenY
					and clickY < screenY + height
				then
					if type(action) == "string" then
						PrimeUI.resolve("clickRegion", action)
					else
						action()
					end
				end
			end
		end
	end)
end

function PrimeUI.drawNFT(win, x, y, data)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, data, "string", "table")

	if type(data) == "string" then
		data = assert(nft.load("data/example.nft"), "File is not a valid NFT file")
	end
	nft.draw(data, x, y, win)
end

function PrimeUI.drawText(win, text, resizeToFit, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, text, "string")
	expect(3, resizeToFit, "boolean", "nil")
	fgColor = expect(4, fgColor, "number", "nil") or colors.white
	bgColor = expect(5, bgColor, "number", "nil") or colors.black

	win.setBackgroundColor(bgColor)
	win.setTextColor(fgColor)

	local old = term.redirect(win)

	local lines = print(text)

	term.redirect(old)

	if resizeToFit then
		local x, y = win.getPosition()
		local w = win.getSize()

		win.reposition(x, y, w, lines)
	end
	return lines
end

function PrimeUI.horizontalLine(win, x, y, width, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	fgColor = expect(5, fgColor, "number", "nil") or colors.white
	bgColor = expect(6, bgColor, "number", "nil") or colors.black

	win.setCursorPos(x, y)
	win.setTextColor(fgColor)
	win.setBackgroundColor(bgColor)
	win.write(("\x8C"):rep(width))
end

function PrimeUI.inputBox(win, x, y, width, action, fgColor, bgColor, replacement, history, completion, default)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, action, "function", "string")
	fgColor = expect(6, fgColor, "number", "nil") or colors.white
	bgColor = expect(7, bgColor, "number", "nil") or colors.black
	expect(8, replacement, "string", "nil")
	expect(9, history, "table", "nil")
	expect(10, completion, "function", "nil")
	expect(11, default, "string", "nil")

	local box = window.create(win, x, y, width, 1)
	box.setTextColor(fgColor)
	box.setBackgroundColor(bgColor)
	box.clear()

	PrimeUI.addTask(function()
		local coro = coroutine.create(read)

		local old = term.redirect(box)
		local ok, res = coroutine.resume(coro, replacement, history, completion, default)
		term.redirect(old)

		while coroutine.status(coro) ~= "dead" do
			local ev = table.pack(os.pullEvent())

			old = term.redirect(box)
			ok, res = coroutine.resume(coro, table.unpack(ev, 1, ev.n))
			term.redirect(old)

			if not ok then
				error(res)
			end
		end

		if type(action) == "string" then
			PrimeUI.resolve("inputBox", action, res)
		else
			action(res)
		end

		while true do
			os.pullEvent()
		end
	end)
end

function PrimeUI.interval(time, action)
	expect(1, time, "number")
	expect(2, action, "function", "string")

	local timer = os.startTimer(time)

	PrimeUI.addTask(function()
		while true do
			local _, tm = os.pullEvent("timer")
			if tm == timer then
				local res
				if type(action) == "string" then
					PrimeUI.resolve("timeout", action)
				else
					res = action()
				end

				if type(res) == "number" then
					time = res
				end

				if res ~= false then
					timer = os.startTimer(time)
				end
			end
		end
	end)

	return function()
		os.cancelTimer(timer)
	end
end

function PrimeUI.keyAction(key, action)
	expect(1, key, "number")
	expect(2, action, "function", "string")
	PrimeUI.addTask(function()
		while true do
			local _, param1 = os.pullEvent("key")
			if param1 == key then
				if type(action) == "string" then
					PrimeUI.resolve("keyAction", action)
				else
					action()
				end
			end
		end
	end)
end

function PrimeUI.label(win, x, y, text, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, text, "string")
	fgColor = expect(5, fgColor, "number", "nil") or colors.white
	bgColor = expect(6, bgColor, "number", "nil") or colors.black
	win.setCursorPos(x, y)
	win.setTextColor(fgColor)
	win.setBackgroundColor(bgColor)
	win.write(text)
end

function PrimeUI.progressBar(win, x, y, width, fgColor, bgColor, useShade)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	fgColor = expect(5, fgColor, "number", "nil") or colors.white
	bgColor = expect(6, bgColor, "number", "nil") or colors.black
	expect(7, useShade, "boolean", "nil")
	local function redraw(progress)
		expect(1, progress, "number")
		if progress < 0 or progress > 1 then
			error("bad argument #1 (value out of range)", 2)
		end

		win.setCursorPos(x, y)
		win.setBackgroundColor(bgColor)
		win.setBackgroundColor(fgColor)
		win.write((" "):rep(math.floor(progress * width)))

		win.setBackgroundColor(bgColor)
		win.setTextColor(fgColor)
		win.write((useShade and "\x7F" or " "):rep(width - math.floor(progress * width)))
	end
	redraw(0)
	return redraw
end

function PrimeUI.scrollBox(
	win,
	x,
	y,
	width,
	height,
	innerHeight,
	allowArrowKeys,
	showScrollIndicators,
	fgColor,
	bgColor
)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, height, "number")
	expect(6, innerHeight, "number")
	expect(7, allowArrowKeys, "boolean", "nil")
	expect(8, showScrollIndicators, "boolean", "nil")
	fgColor = expect(9, fgColor, "number", "nil") or colors.white
	bgColor = expect(10, bgColor, "number", "nil") or colors.black
	if allowArrowKeys == nil then
		allowArrowKeys = true
	end

	local outer = window.create(win == term and term.current() or win, x, y, width, height)
	outer.setBackgroundColor(bgColor)
	outer.clear()

	local inner = window.create(outer, 1, 1, width - (showScrollIndicators and 1 or 0), innerHeight)
	inner.setBackgroundColor(bgColor)
	inner.clear()

	if showScrollIndicators then
		outer.setBackgroundColor(bgColor)
		outer.setTextColor(fgColor)
		outer.setCursorPos(width, height)
		outer.write(innerHeight > height and "\31" or " ")
	end

	x, y = PrimeUI.getWindowPos(win, x, y)

	local scrollPos = 1

	local originalEventFilter = PrimeUI.eventFilter

	PrimeUI.eventFilter = function(event, ...)
		if event == "mouse_click" or event == "mouse_up" or event == "mouse_drag" then
			local _, mouseX, mouseY = ...

			if mouseX >= x and mouseX < x + width and mouseY >= y and mouseY < y + height then
				local adjustedY = mouseY + scrollPos - 1

				return originalEventFilter(event, _, mouseX, adjustedY, select(4, ...))
			end
		end

		return originalEventFilter(event, ...)
	end

	PrimeUI.addTask(function()
		while true do
			local ev = table.pack(os.pullEvent())

			innerHeight = select(2, inner.getSize())

			local dir
			if ev[1] == "key" and allowArrowKeys then
				if ev[2] == keys.up then
					dir = -1
				elseif ev[2] == keys.down then
					dir = 1
				end
			elseif
				ev[1] == "mouse_scroll"
				and ev[3] >= x
				and ev[3] < x + width
				and ev[4] >= y
				and ev[4] < y + height
			then
				dir = ev[2]
			end

			if dir and (scrollPos + dir >= 1 and scrollPos + dir <= innerHeight - height) then
				scrollPos = scrollPos + dir
				inner.reposition(1, 2 - scrollPos)
			end

			if showScrollIndicators then
				outer.setBackgroundColor(bgColor)
				outer.setTextColor(fgColor)
				outer.setCursorPos(width, 1)
				outer.write(scrollPos > 1 and "\30" or " ")
				outer.setCursorPos(width, height)
				outer.write(scrollPos < innerHeight - height and "\31" or " ")
			end
		end
	end)

	local function scroll(pos)
		expect(1, pos, "number")
		pos = math.floor(pos)
		expect.range(pos, 1, innerHeight - height)

		scrollPos = pos
		inner.reposition(1, 2 - scrollPos)

		if showScrollIndicators then
			outer.setBackgroundColor(bgColor)
			outer.setTextColor(fgColor)
			outer.setCursorPos(width, 1)
			outer.write(scrollPos > 1 and "\30" or " ")
			outer.setCursorPos(width, height)
			outer.write(scrollPos < innerHeight - height and "\31" or " ")
		end
	end

	PrimeUI.addTask(function()
		while true do
			local event = os.pullEvent("term_resize")

			if not outer.isColor then
				PrimeUI.eventFilter = originalEventFilter
				return
			end
		end
	end)

	return inner, scroll
end

function PrimeUI.selectionBox(win, x, y, width, height, entries, action, selectChangeAction, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, height, "number")
	expect(6, entries, "table")
	expect(7, action, "function", "string")
	expect(8, selectChangeAction, "function", "string", "nil")
	fgColor = expect(9, fgColor, "number", "nil") or colors.white
	bgColor = expect(10, bgColor, "number", "nil") or colors.black

	if #entries == 0 then
		error("bad argument #6 (table must not be empty)", 2)
	end
	for i, v in ipairs(entries) do
		if type(v) ~= "string" then
			error("bad item " .. i .. " in entries table (expected string, got " .. type(v), 2)
		end
	end

	local entrywin = window.create(win, x, y, width, height)
	local selection, scroll = 1, 1

	local function drawEntries()
		entrywin.setVisible(false)
		entrywin.setBackgroundColor(bgColor)
		entrywin.clear()

		for i = scroll, scroll + height - 1 do
			local e = entries[i]
			if not e then
				break
			end

			entrywin.setCursorPos(2, i - scroll + 1)
			if i == selection then
				entrywin.setBackgroundColor(fgColor)
				entrywin.setTextColor(bgColor)
			else
				entrywin.setBackgroundColor(bgColor)
				entrywin.setTextColor(fgColor)
			end

			entrywin.clearLine()
			entrywin.write(#e > width - 1 and e:sub(1, width - 4) .. "..." or e)
		end

		entrywin.setBackgroundColor(bgColor)
		entrywin.setTextColor(fgColor)
		entrywin.setCursorPos(width, 1)
		entrywin.write("\30")
		entrywin.setCursorPos(width, height)
		entrywin.write("\31")

		entrywin.setVisible(true)
	end

	drawEntries()

	PrimeUI.addTask(function()
		while true do
			local event, key, cx, cy = os.pullEvent()
			if event == "key" then
				if key == keys.down and selection < #entries then
					selection = selection + 1
					if selection > scroll + height - 1 then
						scroll = scroll + 1
					end

					if type(selectChangeAction) == "string" then
						PrimeUI.resolve("selectionBox", selectChangeAction, selection)
					elseif selectChangeAction then
						selectChangeAction(selection)
					end

					drawEntries()
				elseif key == keys.up and selection > 1 then
					selection = selection - 1
					if selection < scroll then
						scroll = scroll - 1
					end

					if type(selectChangeAction) == "string" then
						PrimeUI.resolve("selectionBox", selectChangeAction, selection)
					elseif selectChangeAction then
						selectChangeAction(selection)
					end

					drawEntries()
				elseif key == keys.enter then
					if type(action) == "string" then
						PrimeUI.resolve("selectionBox", action, entries[selection])
					else
						action(entries[selection])
					end
				end
			elseif event == "mouse_click" and key == 1 then
				local wx, wy = PrimeUI.getWindowPos(entrywin, 1, 1)
				if cx == wx + width - 1 then
					if cy == wy and selection > 1 then
						selection = selection - 1
						if selection < scroll then
							scroll = scroll - 1
						end

						if type(selectChangeAction) == "string" then
							PrimeUI.resolve("selectionBox", selectChangeAction, selection)
						elseif selectChangeAction then
							selectChangeAction(selection)
						end

						drawEntries()
					elseif cy == wy + height - 1 and selection < #entries then
						selection = selection + 1
						if selection > scroll + height - 1 then
							scroll = scroll + 1
						end

						if type(selectChangeAction) == "string" then
							PrimeUI.resolve("selectionBox", selectChangeAction, selection)
						elseif selectChangeAction then
							selectChangeAction(selection)
						end

						drawEntries()
					end
				elseif cx >= wx and cx < wx + width - 1 and cy >= wy and cy < wy + height then
					local sel = scroll + (cy - wy)
					if sel == selection then
						if type(action) == "string" then
							PrimeUI.resolve("selectionBox", action, entries[selection])
						else
							action(entries[selection])
						end
					else
						selection = sel

						if type(selectChangeAction) == "string" then
							PrimeUI.resolve("selectionBox", selectChangeAction, selection)
						elseif selectChangeAction then
							selectChangeAction(selection)
						end

						drawEntries()
					end
				end
			elseif event == "mouse_scroll" then
				local wx, wy = PrimeUI.getWindowPos(entrywin, 1, 1)
				if cx >= wx and cx < wx + width and cy >= wy and cy < wy + height then
					if key < 0 and selection > 1 then
						selection = selection - 1
						if selection < scroll then
							scroll = scroll - 1
						end

						if type(selectChangeAction) == "string" then
							PrimeUI.resolve("selectionBox", selectChangeAction, selection)
						elseif selectChangeAction then
							selectChangeAction(selection)
						end

						drawEntries()
					elseif key > 0 and selection < #entries then
						selection = selection + 1
						if selection > scroll + height - 1 then
							scroll = scroll + 1
						end

						if type(selectChangeAction) == "string" then
							PrimeUI.resolve("selectionBox", selectChangeAction, selection)
						elseif selectChangeAction then
							selectChangeAction(selection)
						end

						drawEntries()
					end
				end
			end
		end
	end)
end

function PrimeUI.textBox(win, x, y, width, height, text, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, width, "number")
	expect(5, height, "number")
	expect(6, text, "string")
	fgColor = expect(7, fgColor, "number", "nil") or colors.white
	bgColor = expect(8, bgColor, "number", "nil") or colors.black

	local box = window.create(win, x, y, width, height)

	function box.getSize()
		return width, math.huge
	end

	local function redraw(_text)
		expect(1, _text, "string")

		box.setBackgroundColor(bgColor)
		box.setTextColor(fgColor)
		box.clear()
		box.setCursorPos(1, 1)

		local old = term.redirect(box)
		print(_text)
		term.redirect(old)
	end
	redraw(text)
	return redraw
end

function PrimeUI.toggleButton(win, x, y, textOn, textOff, action, fgColor, bgColor, clickedColor, periphName)
	expect(1, win, "table")
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, textOn, "string")
	expect(5, textOff, "string")
	if #textOn ~= #textOff then
		error("On and off text must be the same length", 2)
	end
	expect(6, action, "function", "string")
	fgColor = expect(7, fgColor, "number", "nil") or colors.white
	bgColor = expect(8, bgColor, "number", "nil") or colors.gray
	clickedColor = expect(9, clickedColor, "number", "nil") or colors.lightGray
	periphName = expect(10, periphName, "string", "nil")

	win.setCursorPos(x, y)
	win.setBackgroundColor(bgColor)
	win.setTextColor(fgColor)
	win.write(" " .. textOff .. " ")
	local state = false

	PrimeUI.addTask(function()
		local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
		local buttonDown = false
		while true do
			local event, button, clickX, clickY = os.pullEvent()
			if
				event == "mouse_click"
				and periphName == nil
				and button == 1
				and clickX >= screenX
				and clickX < screenX + #textOn + 2
				and clickY == screenY
			then
				buttonDown = true

				win.setCursorPos(x, y)
				win.setBackgroundColor(clickedColor)
				win.setTextColor(fgColor)
				win.write(" " .. (state and textOn or textOff) .. " ")
			elseif
				(
					event == "monitor_touch"
					and periphName == button
					and clickX >= screenX
					and clickX < screenX + #textOn + 2
					and clickY == screenY
				) or (event == "mouse_up" and button == 1 and buttonDown)
			then
				state = not state
				if clickX >= screenX and clickX < screenX + #textOn + 2 and clickY == screenY then
					if type(action) == "string" then
						PrimeUI.resolve("toggleButton", action, state)
					else
						action(state)
					end
				end

				win.setCursorPos(x, y)
				win.setBackgroundColor(bgColor)
				win.setTextColor(fgColor)
				win.write(" " .. (state and textOn or textOff) .. " ")
			end
		end
	end)
end

function PrimeUI.verticalLine(win, x, y, height, right, fgColor, bgColor)
	expect(1, win, "table")
	expect(2, x, "number")
	expect(3, y, "number")
	expect(4, height, "number")
	right = expect(5, right, "boolean", "nil") or false
	fgColor = expect(6, fgColor, "number", "nil") or colors.white
	bgColor = expect(7, bgColor, "number", "nil") or colors.black

	win.setTextColor(right and bgColor or fgColor)
	win.setBackgroundColor(right and fgColor or bgColor)
	for j = 1, height do
		win.setCursorPos(x, y + j - 1)
		win.write("\x95")
	end
end

ui = PrimeUI

local Transliteration = {}
Transliteration.__index = Transliteration

local cyrillicAlphabet = {
	{ "А", "а", "A", "a" },
	{ "Б", "б", "B", "b" },
	{ "В", "в", "V", "v" },
	{ "Г", "г", "G", "g" },
	{ "Д", "д", "D", "d" },
	{ "Е", "е", "E", "e" },
	{ "Ё", "ё", "YO", "yo" },
	{ "Ж", "ж", "ZH", "zh" },
	{ "З", "з", "Z", "z" },
	{ "И", "и", "I", "i" },
	{ "Й", "й", "Y", "y" },
	{ "К", "к", "K", "k" },
	{ "Л", "л", "L", "l" },
	{ "М", "м", "M", "m" },
	{ "Н", "н", "N", "n" },
	{ "О", "о", "O", "o" },
	{ "П", "п", "P", "p" },
	{ "Р", "р", "R", "r" },
	{ "С", "с", "S", "s" },
	{ "Т", "т", "T", "t" },
	{ "У", "у", "U", "u" },
	{ "Ф", "ф", "F", "f" },
	{ "Х", "х", "KH", "kh" },
	{ "Ц", "ц", "TS", "ts" },
	{ "Ч", "ч", "CH", "ch" },
	{ "Ш", "ш", "SH", "sh" },
	{ "Щ", "щ", "SHCH", "shch" },
	{ "Ъ", "ъ", "", "" },
	{ "Ы", "ы", "Y", "y" },
	{ "Ь", "ь", "", "" },
	{ "Э", "э", "E", "e" },
	{ "Ю", "ю", "YU", "yu" },
	{ "Я", "я", "YA", "ya" },
}

function Transliteration.new()
	local self = setmetatable({}, Transliteration)
	self.cyrillicToLatin = {}
	self.latinToCyrillic = {}
	self.isSetup = false
	return self
end

function Transliteration:setup()
	if self.isSetup then
		return
	end
	for _, pair in ipairs(cyrillicAlphabet) do
		self.cyrillicToLatin[utf8.codepoint(pair[1])] = pair[3]
		self.cyrillicToLatin[utf8.codepoint(pair[2])] = pair[4]
		if pair[3] ~= "" then
			if not self.latinToCyrillic[pair[3]] then
				self.latinToCyrillic[pair[3]] = {}
			end
			table.insert(self.latinToCyrillic[pair[3]], pair[1])
			table.insert(self.latinToCyrillic[pair[3]], pair[2])
		end
		if pair[4] ~= "" then
			if not self.latinToCyrillic[pair[4]] then
				self.latinToCyrillic[pair[4]] = {}
			end
			table.insert(self.latinToCyrillic[pair[4]], pair[1])
			table.insert(self.latinToCyrillic[pair[4]], pair[2])
		end
	end
	self.isSetup = true
end

function Transliteration:translate(str)
	if not self.isSetup then
		self:setup()
	end
	local result = ""

	local chars = {}
	for char in str:gmatch(utf8.charpattern) do
		table.insert(chars, char)
	end

	for _, char in ipairs(chars) do
		local codepoint = utf8.codepoint(char)
		local latin = self.cyrillicToLatin[codepoint]
		if latin then
			result = result .. latin
		else
			result = result .. char
		end
	end

	return result
end

local function box(terminal, x, y, width, height, color, cornerStyle)
	cornerStyle = cornerStyle or "square"
	terminal.setBackgroundColor(color)

	if cornerStyle == "square" then
		for i = y, y + height - 1 do
			terminal.setCursorPos(x, i)
			terminal.write(string.rep(" ", width))
		end
	elseif cornerStyle == "round" then
		terminal.setCursorPos(x + 1, y)
		terminal.write(string.rep(" ", width - 2))

		for i = y + 1, y + height - 2 do
			terminal.setCursorPos(x, i)
			terminal.write(string.rep(" ", width))
		end

		terminal.setCursorPos(x + 1, y + height - 1)
		terminal.write(string.rep(" ", width - 2))
	end
end
ui.box = box

local api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"

local width, height = term.getSize()

local last_search_url = nil
local search_results = nil
local playing = false
local queue = {}
local now_playing = nil
local looping = false
local volume = 0.5

local playing_id = nil
local last_download_url = nil
local playing_status = 0

local player_handle = nil
local start = nil
local pcm = nil
local size = nil
local decoder = nil
local needs_next_chunk = 0
local buffer

local speakers = { peripheral.find("speaker") }

if #speakers == 0 then
	error(
		"No speakers attached. You need to connect a speaker to this computer. If this is an Advanced Noisy Pocket Computer, then this is a bug, and you should try restarting your Minecraft game.",
		0
	)
end

local speaker = speakers[1]

os.startTimer(1)

local function playSong(song)
	now_playing = song
	playing = true
	playing_id = nil
end

local function stopPlayback()
	playing = false
	speaker.stop()
	playing_id = nil
end

local function togglePlayPause()
	if playing then
		stopPlayback()
	else
		if now_playing or #queue > 0 then
			playSong(now_playing or queue[1])
		end
	end
end

local function skipSong()
	if #queue > 0 then
		now_playing = queue[1]
		table.remove(queue, 1)
		playing_id = nil
	else
		now_playing = nil
		playing = false
	end
end

local function toggleLoop()
	looping = not looping
end

local function addToQueue(song, position)
	if position then
		table.insert(queue, position, song)
	else
		table.insert(queue, song)
	end
end

local function removeFromQueue(position)
	if position and position <= #queue then
		table.remove(queue, position)
	end
end

local function clearQueue()
	queue = {}
end

local function searchMusic(query)
	last_search = query
	last_search_url = api_base_url .. "?search=" .. textutils.urlEncode(query)
	http.request(last_search_url)
	search_results = nil
	search_error = false
end

local function handleAudioStream(response)
	player_handle = response
	start = response.read(4)
	size = 16 * 1024 - 4
	playing_status = 1
	decoder = require("cc.audio.dfpwm").make_decoder()
end

local original_palette = {}
local function initCustomPallete()
	for i = 1, 16 do
		original_palette[i] = term.getPaletteColor(i)
	end

	term.setPaletteColor(colors.green, 0x1ED760)
	term.setPaletteColor(colors.lightGray, 0xb3b3b3)
	term.setPaletteColor(colors.gray, 0x212121)
	term.setPaletteColor(colors.purple, 0x457e59)
	term.setPaletteColor(colors.magenta, 0x62d089)
	term.setPaletteColor(colors.brown, 0x2e2e2e)
end

local function fixString(str, limit)
	if not str then
		return ""
	end

	if #str <= limit then
		return str
	end

	return string.sub(str, 1, limit - 3) .. "..."
end

ui.page = 1

local function redrawScreen()
	initCustomPallete()

	while true do
		ui.clear()
		ui.borderBox(term.current(), 3, 2, width - 4, 1, colors.gray)

		local isSmallScreen = width <= 30

		if now_playing then
			if playing then
				if isSmallScreen then
					ui.button(term.current(), 4, 2, "S", "stop", colors.white, colors.red, colors.orange)
				else
					ui.button(term.current(), 4, 2, "Stop", "stop", colors.white, colors.red, colors.orange)
				end
			else
				ui.button(term.current(), 4, 2, "\16", "pause", colors.white, colors.green, colors.lightGray)
				ui.button(term.current(), 8, 2, "R", "clear", colors.white, colors.red, colors.orange)
			end
			if not isSmallScreen then
				ui.label(term.current(), 12, 2, fixString(now_playing.name, 20), colors.white)
				ui.label(
					term.current(),
					12 + string.len(fixString(now_playing.name, 20)) + 1,
					2,
					"| " .. fixString(now_playing.artist, 14),
					colors.lightGray
				)
			else
				ui.label(term.current(), 8, 2, fixString(now_playing.name, 16), colors.white)
			end
		else
			ui.label(term.current(), 4, 2, "Musiclo", colors.green)
			if not isSmallScreen then
				ui.label(
					term.current(),
					4 + string.len("Musiclo") + 2,
					2,
					"| CC:T music player made easy",
					colors.lightGray
				)
			else
				ui.label(term.current(), 4 + string.len("Musiclo") + 1, 2, "| CC:T player", colors.lightGray)
			end
		end

		local titleTruncateLimit = 41
		local artistTruncateLimit = 26

		if isSmallScreen then
			titleTruncateLimit = 19
			artistTruncateLimit = 15
		end

		if ui.page == 1 then
			ui.borderBox(term.current(), 3, 5, width - 4, height - 6, colors.gray)

			ui.button(term.current(), width - 9, 4, "Search", "page.2", colors.white, colors.magenta, colors.purple)
			ui.keyAction(keys.enter, "page.2")

			ui.label(term.current(), 4, 4, "Queue", colors.white)

			ui.keyAction(keys.space, "pause")

			if looping then
				ui.button(term.current(), 4, height - 1, "Loop", "loop", colors.white, colors.magenta, colors.purple)
			else
				ui.button(term.current(), 4, height - 1, "Loop", "loop", colors.white, colors.gray, colors.lightGray)
			end

			if #queue > 0 then
				ui.button(term.current(), 11, height - 1, "Skip", "skip", colors.white, colors.gray, colors.lightGray)
				if isSmallScreen then
					ui.button(term.current(), 18, height - 1, "Clr", "clear.q", colors.white, colors.red, colors.orange)
				else
					ui.button(
						term.current(),
						18,
						height - 1,
						"Clear queue",
						"clear.q",
						colors.white,
						colors.red,
						colors.orange
					)
				end
			end

			local volStr = "Vol: " .. math.floor(volume * 100) .. "%"
			ui.label(term.current(), 4, height, volStr, colors.lightGray)

			local volBtnX = 4 + #volStr + 1
			ui.button(term.current(), volBtnX, height, "-", "vol.down", colors.white, colors.gray, colors.lightGray)
			ui.button(term.current(), volBtnX + 4, height, "+", "vol.up", colors.white, colors.gray, colors.lightGray)

			ui.label(term.current(), 4, 6, "Now playing", colors.white)

			local scroller = ui.scrollBox(term.current(), 3, 5, width - 4, height - 6, 9000, true, true)

			y = 2
			if #queue > 0 then
				for i, song in ipairs(queue) do
					ui.box(scroller, 1, y, width - 5, 5, colors.brown)
					ui.label(scroller, 2, y + 1, fixString(song.name, titleTruncateLimit), colors.white, colors.brown)
					ui.label(
						scroller,
						2,
						y + 2,
						fixString(song.artist, artistTruncateLimit),
						colors.lightGray,
						colors.brown
					)
					if isSmallScreen then
						y = y + 1
					end
					ui.button(
						scroller,
						width - 20,
						y + 2,
						"Play",
						"play." .. i,
						colors.white,
						colors.magenta,
						colors.purple
					)
					local songInQueue = false
					for _, queuedSong in ipairs(queue) do
						if queuedSong.id == song.id then
							songInQueue = true
							break
						end
					end
					if songInQueue then
						ui.button(
							scroller,
							width - 13,
							y + 2,
							"Remove",
							"rem." .. i,
							colors.white,
							colors.red,
							colors.orange
						)
					else
						ui.button(
							scroller,
							width - 13,
							y + 2,
							"Add",
							"add." .. i,
							colors.white,
							colors.gray,
							colors.lightGray
						)
					end
					y = y + 6
				end
			else
				ui.centerLabel(scroller, 1, 5, width - 4, "No songs in queue", colors.lightGray)
				ui.button(
					scroller,
					((width - 4 - 3) / 2 - (string.len("Add song") / 2)) + 1,
					7,
					"Add song",
					"page.2",
					colors.white,
					colors.gray,
					colors.lightGray
				)
			end
		elseif ui.page == 2 then
			ui.borderBox(term.current(), 3, 5, width - 4, height - 6, colors.gray)

			ui.button(term.current(), width - 10, 4, "Go back", "page.1", colors.white, colors.gray, colors.lightGray)
			ui.label(term.current(), 4, 4, "Search", colors.white)

			ui.label(term.current(), 4, 6, "Search on Youtube...", colors.lightGray)

			ui.horizontalLine(term.current(), 3, 8, width - 4, colors.gray)

			local scroller = ui.scrollBox(term.current(), 3, 9, width - 4, height - 10, 9000, true, true)

			y = 2
			if search_results then
				for i, song in ipairs(search_results) do
					ui.box(scroller, 1, y, width - 6, 5, colors.brown)
					ui.label(scroller, 2, y + 1, fixString(song.name, titleTruncateLimit), colors.white, colors.brown)
					ui.label(
						scroller,
						2,
						y + 2,
						fixString(song.artist, artistTruncateLimit),
						colors.lightGray,
						colors.brown
					)
					if isSmallScreen then
						y = y + 1
					end
					ui.button(
						scroller,
						width - 21,
						y + 2,
						"Play",
						"play." .. i,
						colors.white,
						colors.magenta,
						colors.purple
					)
					local songInQueue = false
					for _, queuedSong in ipairs(queue) do
						if queuedSong.id == song.id then
							songInQueue = true
							break
						end
					end
					if songInQueue then
						ui.button(
							scroller,
							width - 14,
							y + 2,
							"Remove",
							"rem." .. i,
							colors.white,
							colors.red,
							colors.orange
						)
					else
						ui.button(
							scroller,
							width - 14,
							y + 2,
							"Add",
							"add." .. i,
							colors.white,
							colors.gray,
							colors.lightGray
						)
					end
					y = y + 6
				end
			end

			ui.inputBox(term.current(), 4, 7, width - 7, "search", colors.white, colors.gray)
		end

		local object, callback, text = ui.run()
		term.clear()
		term.setCursorPos(1, 1)

		if object == "button" then
			if callback == "page.2" then
				ui.page = 2
			elseif callback == "page.1" then
				ui.page = 1
			elseif callback:sub(1, 4) == "play" then
				local index = tonumber(callback:sub(6))
				if index and search_results[index] then
					playSong(search_results[index])
					ui.page = 1
				end
			elseif callback:sub(1, 3) == "add" then
				local index = tonumber(callback:sub(5))
				if index and search_results[index] then
					addToQueue(search_results[index])
				end
			elseif callback:sub(1, 4) == "rem" then
				local index = tonumber(callback:sub(6))
				if index and search_results[index] then
					removeFromQueue(index)
				end
			elseif callback == "stop" then
				stopPlayback()
			elseif callback == "pause" then
				togglePlayPause()
			elseif callback == "loop" then
				toggleLoop()
			elseif callback == "skip" then
				skipSong()
			elseif callback == "clear.q" then
				clearQueue()
			elseif callback == "clear" then
				playing = false
				now_playing = nil
				playing_id = nil
			elseif callback == "vol.up" then
				volume = volume + 0.1
				if volume > 1.0 then
					volume = 1.0
				end
			elseif callback == "vol.down" then
				volume = volume - 0.1
				if volume < 0.0 then
					volume = 0.0
				end
			end
		elseif object == "keyAction" then
		elseif object == "keyAction" then
			if callback == "page.2" then
				ui.page = 2
			elseif callback == "page.1" then
				ui.page = 1
			end
		elseif object == "inputBox" and callback == "search" then
			if text ~= "" then
				searchMusic(text)
				term.clear()
				local sx, sy = term.getSize()
				term.setTextColor(colors.lightGray)
				term.setCursorPos(sx / 2 - #"Fetching..." / 2, sy / 2)
				term.write("Fetching...")
				ui.searchDone = false
				repeat
					sleep(0.1)
				until ui.searchDone == true
				ui.searchDone = false
			end
		elseif object == "rerender" then
			print("rerender")
		else
			term.clear()
			term.setCursorPos(1, 1)
			error(
				"["
					.. (object or "No object")
					.. "] "
					.. (callback or "No callback")
					.. " "
					.. (text or "No text")
					.. " not handled! Exiting",
				0
			)
		end
	end
end

local function audioLoop()
	while true do
		sleep(0.1)
		if playing and now_playing then
			if playing_id ~= now_playing.id then
				playing_id = now_playing.id
				last_download_url = api_base_url .. "?v=2&id=" .. textutils.urlEncode(playing_id)
				playing_status = 0
				needs_next_chunk = 1

				http.request({ url = last_download_url, binary = true })
				is_loading = true
			end
			if playing_status == 1 and needs_next_chunk == 3 then
				needs_next_chunk = 1
				for _, speaker in ipairs(speakers) do
					while not speaker.playAudio(buffer) do
						needs_next_chunk = 2
						break
					end
				end
			end
			if playing_status == 1 and needs_next_chunk == 1 then
				while true do
					local chunk = player_handle.read(size)
					if not chunk then
						if looping then
							playing_id = nil
						else
							if #queue > 0 then
								now_playing = queue[1]
								table.remove(queue, 1)
								playing_id = nil
							else
								now_playing = nil
								playing = false
								playing_id = nil
								is_loading = false
								is_error = false
							end
						end

						player_handle.close()
						needs_next_chunk = 0
						break
					else
						if start then
							chunk, start = start .. chunk, nil
							size = size + 4
						end

						buffer = decoder(chunk)

						if volume ~= 1.0 then
							for k, v in ipairs(buffer) do
								buffer[k] = v * volume
							end
						end

						for _, speaker in ipairs(speakers) do
							while not speaker.playAudio(buffer) do
								needs_next_chunk = 2
								break
							end
						end
					end
				end
			end
		end
	end
end

local function eventLoop()
	while true do
		local event, param1, param2 = os.pullEvent()

		if event == "timer" then
			os.startTimer(1)
		end

		if event == "speaker_audio_empty" then
			if needs_next_chunk == 2 then
				needs_next_chunk = 3
			end
		end

		if event == "http_success" then
			local url = param1
			local handle = param2
			if url == last_search_url then
				search_results = textutils.unserialiseJSON(handle.readAll())
				table.remove(search_results, 1)
				ui.searchDone = true
			end
			if url == last_download_url then
				player_handle = handle
				start = handle.read(4)
				size = 16 * 1024 - 4
				if start == "RIFF" then
					error("WAV not supported!")
				end
				playing_status = 1
				decoder = require("cc.audio.dfpwm").make_decoder()
			end
		end

		if event == "http_failure" then
			local url = param1

			if url == last_search_url then
				search_error = true
			end
			if url == last_download_url then
				if #queue > 0 then
					now_playing = queue[1]
					table.remove(queue, 1)
					playing_id = nil
				else
					now_playing = nil
					playing = false
					playing_id = nil
				end
			end
		end
	end
end

parallel.waitForAny(audioLoop, eventLoop, redrawScreen)

for i = 1, 16 do
	term.setPaletteColor(i, original_palette[i])
end
term.setCursorBlink(false)
term.clear()
term.setCursorPos(1, 1)
