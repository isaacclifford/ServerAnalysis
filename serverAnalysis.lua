-- Load the wxLua module, does nothing if running from wxLua, wxLuaFreeze, or wxLuaEdit
package.cpath = package.cpath..";./?.dll;./?.so;../lib/?.so;../lib/vc_dll/?.dll;../lib/bcc_dll/?.dll;../lib/mingw_dll/?.dll;"
require("wx")
-- ================ Local Variable Initializations ================ --
local counter1 = 0
--Socket Data and Window
local xmlResource
local dialog

local proccessTimer
local READLENGTH
local totalTimer = 0 
local urlTable

--Set-Up Panel Variables 
local maxRequestCount = 0
--Status Panel Variables
local requestGoal = 50

local proccessing  = false
local urlTable 
local finishCounter = 0


--================ GUI-SRC Functions ================--

-- return the path part of the currently executing file
function GetExePath()
	local function findLast(filePath) -- find index of last / or \ in string
		local lastOffset = nil
		local offset = nil
		repeat
			offset = string.find(filePath, "\\") or string.find(filePath, "/")
			if offset then
				lastOffset = (lastOffset or 0) + offset
				filePath = string.sub(filePath, offset + 1)
			end
		until not offset
		return lastOffset
	end

	local filePath = debug.getinfo(1, "S").source

	if string.byte(filePath) == string.byte('@') then
		local offset = findLast(filePath)
		if offset ~= nil then
			filePath = string.sub(filePath, 2, offset - 1)
		else
			filePath = "."
		end
	else
		filePath = wx.wxGetCwd()
	end

	return filePath
end

-- ====== STATUS AND LOGBOX FUNCTIONS ===== -- 
local function GetNumberOfLines(m)
	count = 0
	message = logBox:GetLabel()
	for i in string.gfind(message, "\r\n")	do
		count = count+1
	end
	for i = 100, count do 
		_start , ending = string.find(logBox:GetLabel(), "\r\n")
		logBox:SetLabel(string.sub(logBox:GetLabel(), ending))
	end
end

local function display(m) -- Display on the Log Box
	pastMessage = logBox:GetLabel()
	logBox:SetLabel(pastMessage.."\r\n"..m)
	GetNumberOfLines()
end


local function statusUpdate(passed, statTime, url)
	if passed then 
		print(statTime)
		url.numRequest = url.numRequest + 1
		url.numReqCtrl:SetLabel(tostring(url.numRequest))
		url.totalTime = url.totalTime + statTime
		url.avgTime = url.totalTime/url.numRequest
		url.avgCtrl:SetLabel(tostring(string.format("%0.3f", url.avgTime)))
		
		if statTime > url.maxTime then 
			url.maxTime = statTime
			url.maxCtrl:SetLabel(tostring(url.maxTime))
			url.maxTimeRequest = {}
			url.maxCounter = 1
			url.maxTimeRequest[url.maxCounter]= url.numRequest
		elseif statTime == maxTime then
			url.maxCounter = url.maxCounter + 1
			url.maxTimeRequest[url.maxCounter] = url.numRequest
		end

		if statTime < url.minTime then 
			url.minTime = statTime 
			url.minCtrl:SetLabel(tostring(url.minTime))
			url.minTimeRequest = {}
			url.minCounter = 1
			url.minTimeRequest[url.minCounter] = url.numRequest
		elseif statTime == url.minTime then 
			url.minCounter = url.minCounter + 1
			url.minTimeRequest[url.minCounter] = url.numRequest
		end
	elseif not passed then
		url.numFail = url.numFail +1
		url.numFailCtrl:SetLabel(tostring(url.numFail))
	end
end

local function clearStatusPanel(url)
	url.numReqCtrl:SetLabel('0')
	url.numFailCtrl:SetLabel('0')
	url.avgCtrl:SetLabel("0")
	url.maxCtrl:SetLabel("0")
	url.minCtrl:SetLabel("0")
	url.numRequest = 0
	url.numFail = 0
	url.totalTime = 0
	url.minTime = 1000
	url.maxTime = 0
	url.maxTimeRequest = {}
	url.minTimeRequest = {}
	url.totalTimer = 0
	url.place:SetLabel("    SERVER    "..url.SOCKET_ID)
	url.status:SetLabel("IDLE")
end

local function finalStatusUpdate()
	for _key, url in pairs(urlTable) do 
		display("\r\n--Final Status Report --")
		display("Data For Server: "..url.hostname.."\r\nNumber of Threads: ")
		display("\r\nTotal Number of Requests Sent: "..url.numRequest+url.numFail)
		display("Number of Successful Requests: "..url.numRequest)
		display("Number of Failed Requests: "..url.numFail)
		--display("Average Request Time: "..string.format("%0.3f",tonumber(url.avgCtrl:GetLabel())))
		display("Longest Request Time: "..url.maxTime)
		if url.numRequest == 0 then
			url.minTime = 0
			display("Shortest Request Time: "..url.minTime)
		else
			display("Shortest Request Time: "..url.minTime)
		end
		if finishCounter == 3 then 
			display("Total Time: "..url.finalTime .." seconds")
		end
		url.m_sock:Close()
		url = nil 
	end
end


-- ========== SOCKET VARIABLE FUNCTIONS ========= -- 

local function createTables(tableName, ID)
	local tableName = {}
	tableName.m_sock = wx.wxSocketClient()
	tableName.foundDataLength = false
	tableName.endOfHeaderFound = false
	tableName.endOfHeader = 0
	tableName.totalLength = 0
	tableName.storeUrl = ''
	tableName.UrlTimer = maxTimeOut
	tableName.SOCKET_ID = ID 
	tableName.location = "URL"..ID..".txt"
	tableName.statusTimer = 0
	
	tableName.hostname = tostring(dialog:FindWindow(xmlResource.GetXRCID("url"..ID)):DynamicCast("wxTextCtrl"):GetValue())
	print("Hostname : "..tableName.hostname)
	
	tableName.numReqCtrl = dialog:FindWindow(xmlResource.GetXRCID("request"..ID))
	tableName.numFailCtrl = dialog:FindWindow(xmlResource.GetXRCID("fails"..ID))
	tableName.avgCtrl = dialog:FindWindow(xmlResource.GetXRCID("average"..ID))
	tableName.minCtrl = dialog:FindWindow(xmlResource.GetXRCID("shortest"..ID))
	tableName.maxCtrl = dialog:FindWindow(xmlResource.GetXRCID("longest"..ID))
	
	--TODO STATUS UPDATE VARIABLES
	tableName.numRequest = 0
	tableName.totalTime = 0
	tableName.maxTime = 0 
	tableName.minTime = 1000
	tableName.maxTimeRequest = {}
	tableName.maxCounter = 0
	tableName.minTimeRequest = {}
	tableName.minCounter = 0
	tableName.numFail = 0
	tableName.place = dialog:FindWindow(xmlResource.GetXRCID("serverPlace"..ID))
	tableName.status = dialog:FindWindow(xmlResource.GetXRCID("urlStatus"..ID))
	return tableName
end


local function variableReset(tableName)
	tableName.foundDataLength = false
	tableName.endOfHeaderFound = false
	tableName.endOfHeader = 0
	tableName.totalLength = 0
	tableName.storeUrl = ''
	tableName.UrlTimer = maxTimeOut
	tableName.statusTimer = 0
end
-- ============= SOCKET EVENT FUNCTIONS + STOP BUTTON EVENT ============ -- 
local function openClient(url)
	variableReset(url)
	url.addr = wx.wxIPV4address()
	url.addr:Service(80)
	url.addr:Hostname(url.hostname)
	url.m_sock:SetClientData(url.SOCKET_ID)
	url.m_sock:Connect(url.addr, false)
	timeCountUp:Start(10)
	proccessTimer:Start(1000)
	display("Client "..url.SOCKET_ID.. "is Connected? "..tostring(url.m_sock:IsConnected()))
	--TODO: TIMERS
end


local function findDataLength(url)
	local ending
	local newUrl 
	url.endOfHeader = string.find(url.storeUrl, "\r\n\r\n")
	
	if url.endOfHeaderFound ~= 0 then 
		url.endOfHeaderFound = true
		local contentL = "Content%pLength: "
		local start = string.find(url.storeUrl, contentL)
		if start ~= nil then 
			newUrl = string.sub(url.storeUrl, start)
			ending = string.find(newUrl, "\r\n")
		else
			url.m_sock:Close()
			statusUpdate(false, nil, url)
			display("ERROR: Unable to find Content-Length")
			url.UrlTimer = 0
		end
		
	if ending ~= nil then 
		local cLength = string.sub(newUrl, #contentL, ending)
			url.totalLength = url.endOfHeader + #("\r\n\r\n") + tonumber(cLength)
			url.foundDataLength = true
		end
	end
end	 


--STOP BUTTON EVENT -- (Needed Here because onSocket Event calls upon it)
local function stopButEvent(event)
	proccessing = false
	proccessTimer:Stop()
	timeCountUp:Stop()
	overallTimer:Stop()
	finalStatusUpdate()
	urlTable = nil 
	--
end


local function reachRequestGoal(url)
	url.UrlTimer = 0
	url.finalTime = url.statusTimer
	
	finishCounter = finishCounter + 1
		if finishCounter == 1 then 
		url.status:SetLabel("1ST")
		url.place:SetLabel("**1ST PLACE**")
	elseif finishCounter == 2 then 
		url.status:SetLabel("2ND")
		url.place:SetLabel("**2nd PLACE**")
	elseif finishCounter == 3 then 
		url.status:SetLabel("3RD")
		url.place:SetLabel("**3rd PLACE**")
		stopButEvent()
	end
end
	

-- MAIN SOCKET EVENT HANDLER -- 
local function onSocketEvent(event)
	local url = urlTable[event:GetClientData()]
	local socketEvent = event.SocketEvent
	
	if socketEvent == wx.wxSOCKET_LOST then 
	display("Socket State: LOST for url# "..url.SOCKET_ID)
		statusUpdate(false, nil, url)

	elseif socketEvent == wx.wxSOCKET_INPUT then 
		display("Socket State: INPUT for url# "..url.SOCKET_ID)
		local readData = url.m_sock:Read(READLENGTH)
		url.storeUrl = url.storeUrl..readData
		if url.endOfHeaderFound == false then 
			findDataLength(url)
		end
		
		if url.foundDataLength == true and (#(url.storeUrl) >= url.totalLength) then
			url.m_sock:Close()
			url.storeUrl = url.storeUrl:sub(1, url.totalLength - 1)
			statusUpdate(true, url.statusTimer, url)
			display ("Proccess Complete: Socket "..url.SOCKET_ID.." Time: ".. url.statusTimer)
			url.UrlTimer = 0
			url.status:SetLabel("+1")
			if url.numRequest == requestGoal then
				reachRequestGoal(url)
			else 
			openClient(url)
			end
		end
	elseif socketEvent == wx.wxSOCKET_CONNECTION then 
		display("Socket State: CONNECTED for url# "..url.SOCKET_ID)
		url.status:SetLabel("REQ")
		url.req = "GET / HTTP/1.1\r\nHost: "..url.hostname..":80\r\n\r\n"
		url.m_sock:Write(url.req, #(url.req))
		
		end
end	
		
		

local function setHandlersAndFlags()
	--Socket Flags and Event Handlers
	for _key, url in pairs(urlTable) do 
		url.m_sock:SetFlags(wx.wxSOCKET_NOWAIT)
		url.m_sock:SetEventHandler(dialog, url.SOCKET_ID)
		url.m_sock:SetNotify(wx.wxSOCKET_CONNECTION_FLAG + wx.wxSOCKET_INPUT_FLAG + wx.wxSOCKET_LOST_FLAG)
		url.m_sock:Notify(true)
		dialog:Connect(url.SOCKET_ID, wx.wxEVT_SOCKET, onSocketEvent)
		-- display("Socket flags and such have been set for url# "..url.SOCKET_ID)
	end
end


	
	
-- ========== Button FUNCTIONS - STOP BUTTON FUNCTION ========= -- 
local function OnQuit(event) --Top Right Hand Exit Button 
	event:Skip()
	dialog:Show(false)
	dialog:Destroy()
end


local function clearLogButEvent(event) --Clear Button for LogBox
	logBox:SetLabel("")
end

local function enableStart(event) -- Greying out SET-UP Panel, fileLog and Start when in proccess
	event:Enable(not proccessing)
end	

local function enableStop(event) --Greying out the Stop when not in proccess
	event:Enable(proccessing)
end

--===== Timer Functions =====--

--TimeStamp of the Url Proccess
local function timeUpCount() -- for timeCountUp
	for _key, url in pairs(urlTable) do 
		url.statusTimer  = url.statusTimer + .01
	end
end

--When Time Out Occurs
local function urlTimeOut(url)
	display("Connection Time-Out. Passed Max Time")
	statusUpdate(false, nil, url)
	url.m_sock:Close()
	display("Attempt to ReConnect")
	openClient(url)
	end
	
--Time Out Event Handler Function 
local function timerDownCount(event) 
	for _key, url in pairs(urlTable) do 
		if url.UrlTimer ~=0 then 
			url.UrlTimer = url.UrlTimer -1
			if url.UrlTimer == 0 then
				urlTimeOut(url)
			end
		end
	end
end

local function startButEvent() --Start Button Event Handler Function
	display("Start Button Pressed")
	proccessing = true
	urlTable = {} 
	finishCounter = 0
	for i = 1, 3 do 
		urlTable[i] = createTables(url, i)
		clearStatusPanel(urlTable[i])
		openClient(urlTable[i])
	end
	setHandlersAndFlags()
end

-- =============== MAIN FUNCTION ============= -- 

local function main()
	--===XML AND GUI BASED COMMANDS===-- 
	xmlResource = wx.wxXmlResource()
	xmlResource:InitAllHandlers()
	local xrcFilename = GetExePath().."/serverAnalysis.xrc"
	local logNo = wx.wxLogNull() -- silence wxXmlResource error msg since we provide them
	
	-- try to load the resource and ask for path to it if not found
	while not xmlResource:Load(xrcFilename) do
		-- must unload the file before we try again
		xmlResource:Unload(xrcFilename)
		wx.wxMessageBox("Error loading xrc resources, please choose the path to 'serverRace.xrc",
										"serverRace.xrc",
										wx.wxOK + wx.wxICON_EXCLAMATION,
										wx.NULL)
		local fileDialog = wx.wxFileDialog(wx.NULL,
																			"Open 'serverRace.xrc' resource file",
																			"",
																			"serverRace.xrc",
																			".xrc|All files (*)|*XRC files (*.xrc)|*",
																			wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST)

		if fileDialog:ShowModal() == wx.wxID_OK then
			xrcFilename = fileDialog:GetPath()
		else
			return -- quit program
		end
	end
	logNo:delete() -- turn error messages back on
	dialog = wx.wxDialog()
	if not xmlResource:LoadDialog(dialog, wx.NULL, "dialog") then
		wx.wxMessageBox("Error loading xrc resources!",
										"multi_http_test",
										wx.wxOK + wx.wxICON_EXCLAMATION,
										wx.NULL)
		return -- quit program
	end

	
	dialog:Centre()
	dialog:Show(true)
	
	---=======================================---
	READLENGTH = 2000	
	
	--Initializing Text Controls in The Dialog
	logBox = dialog:FindWindow(xmlResource.GetXRCID("logBox"))
	logBox:SetLabel("-- LOG READY --")
	
	dialog:Connect(wx.wxEVT_CLOSE_WINDOW, OnQuit)
	dialog:Connect(xmlResource.GetXRCID("stopBut"), wx.wxEVT_COMMAND_BUTTON_CLICKED, stopButEvent)
	dialog:Connect(xmlResource.GetXRCID("startBut"), wx.wxEVT_COMMAND_BUTTON_CLICKED, startButEvent)
	dialog:Connect(xmlResource.GetXRCID('clearLogBut'), wx.wxEVT_COMMAND_BUTTON_CLICKED, clearLogButEvent)
	
	
	--ENABLE AND DISABLE UIs
	dialog:Connect(xmlResource.GetXRCID("startBut"), wx.wxEVT_UPDATE_UI, enableStart)
	dialog:Connect(xmlResource.GetXRCID("stopBut"), wx.wxEVT_UPDATE_UI, enableStop)
	dialog:Connect(xmlResource.GetXRCID("setUpPanel"), wx.wxEVT_UPDATE_UI, enableStart)
	
	
	maxTimeOut = 10
	timeCountUp = wx.wxTimer(dialog, 1)
	dialog:Connect(1, wx.wxEVT_TIMER, timeUpCount)
	
	proccessTimer = wx.wxTimer(dialog, 2)
	dialog:Connect(2, wx.wxEVT_TIMER, timerDownCount)
		overallTimer = wx.wxTimer(dialog, 3)
		dialog:Connect(3, wx.wxEVT_TIMER,
				function (event)
					totalTimer = totalTimer + .1
				end)
	end
	
	
	
main()
wx.wxGetApp():MainLoop()

