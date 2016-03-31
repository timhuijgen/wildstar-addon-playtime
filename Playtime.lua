---------------------------------------------------
-- Playtime
-- 
-- @Author: 	Tim Huijgen @ Timmey 
-- @Thanks: 	BarryKun
-- @LastUpdate: 25-5-2014
-- @Version 	2.2
--
---------------------------------------------------

---------------------------------------------------
-- Libraries
---------------------------------------------------

require "ChatSystemLib"
require "GameLib"
require "Window"

---------------------------------------------------
-- Playtime table
---------------------------------------------------

local Playtime = {} 

---------------------------------------------------
-- Constants & settings
---------------------------------------------------

local nSessionRestart 		= 60 * 5 	-- Time spent offline after which a new session will be started
local sSortAlerts 			= "ASC"  	-- Timers sorting ASC / DESC
local sDefaultAlert			= "minute"  -- The multiplier used if no multiplier has been found. second/minute/hour
local nAlertBuzzSound		= 212 		-- The alert sound
local nCommandSound			= 189 		-- The command sound
local bUseCommandSound		= true 		-- Enable or disable / commands sounds
local nNotificationTimer	= 60 		-- Interval to check for notifications
local nAlertTimer			= 1 		-- Interval to update alert timers. 0.5 for faster / smoother window updates but more calls
local bUseAlertWindow		= true 		-- Enable or disable the alert window. Alert finish popups will still come
local bUseSesNotifications	= true		-- Enable or disable hourly notifications about your session playtime
local bUseTotNotifications 	= true		-- Enable or disable hourly notifications about your total playtime
local nSysChannel 			= ChatSystemLib.ChatChannel_System -- System chat channel

local tStrings = {
	-- General
	more_info			= "For more information please check out this addon on Curse.com",
	author				= "Made by Timmey",
	playtime_cmds		= "Playtime Commands:",
	-- Playtime
	playtime_prefix		= "Playtime ",
	char_playtime		= "%s: %s",
	sess_playtime		= "Session: %s",
	total_playtime		= "Total: %s",
	session_reset		= "Session reset",
	-- Alerts
	alert_prefix		= "Alert ",
	alert_done			= "%s is finished",	
	px_alert_done		= "Alert %s is finished",
	name_main_ui		= "Alert list",
	name_alert_ui		= "Alert popup",
	name_newalert_ui	= "Add Alert",
	err_main_ui			= "Could not load the main window for some reason.",
	err_alert_ui		= "Could not load the alert window for some reason.",
	err_newalert_ui		= "Could not load the new alert window .. ?",
	max_alerts 			= "The maximum amount of alerts is 10. Please wait or remove other alerts before you can add more.",
	incorrect_format 	= "Incorrect format. Please use: /setalert alertname amount [second(s),minute(s),hour(s)]. Example: /setalert pizza 1 hour",
	alert_not_found 	= "%s not found",
	alert_removed		= "%s removed",
	alert_preview		= "preview alert!",
	-- Timer
	timer_prefix		= "Timer ",
	timer				= "At: %s",
	timer_stop			= "Stopped at: %s",
	timer_continue		= "Continued",
	timer_start			= "Started",
	timer_reset			= "Reset",
	-- Hourly session notifications, adding more will work automatically on the specified hour
	played_for			= "You have played for %s %s",
	nf_1_hour			= "just getting warmed up!",
	nf_2_hour			= "keep on going!",
	nf_5_hour			= "steady as a rock!",
	nf_9_hour			= "1 more hour and you've hit 10!",
	nf_10_hour			= "you did it! Snack time?",
	nf_20_hour			= "ooh still going are we?!",
	nf_23_hour			= "one more hour and ya'got a day!",
	nf_24_hour			= "impressive a whole day! Time for more or time for bed?",
	nf_30_hour			= "those energy drinks keeping you alive?",
	nf_40_hour			= "personal record broken?",
	-- Hourly total playtime notifications
	total_played		= "You have played a total of %s %s",
	nf_6_total			= "",
	nf_12_total			= "",
	nf_24_total			= ""
}

---------------------------------------------------
-- Initialize and load functions
---------------------------------------------------

function Playtime:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    return o
end

function Playtime:Init()
    Apollo.RegisterAddon(self)

	Apollo.RegisterSlashCommand("playtime", "onPlaytimeCommand", self)
	Apollo.RegisterSlashCommand("fullplaytime", "onFullPlaytimeCommand", self)
	Apollo.RegisterSlashCommand("resetsession", "onResetSessionCommand", self)
	
	-- Timer is not finished, and will be released at a later version
	--Apollo.RegisterSlashCommand("timerstart", "onTimerStartCommand", self)
	--Apollo.RegisterSlashCommand("timerstop", "onTimerStopCommand", self)
	--Apollo.RegisterSlashCommand("timerreset", "onTimerResetCommand", self)
	--Apollo.RegisterSlashCommand("timer", "onTimerCommand", self)
	
	Apollo.RegisterSlashCommand("setalert", "onAlertCommand", self)
	Apollo.RegisterSlashCommand("removealert", "onRemoveAlertCommand", self)
	Apollo.RegisterSlashCommand("alertpreview", "onAlertPreview", self)
	
	Apollo.RegisterSlashCommand("newalert", "onNewAlert", self)
end

function Playtime:OnLoad()
	self.data = { 
		characters = {}
	}
	self.timerdata = {
		timerRunning = false,
		timerPauzed = false,
		timerStart = 0,
		timerStop = 0,
	}
	self.alerts = {}
	self.notificationsShown = {}
	self.totalNotificationsShown = {}
	self.startSession = os.time()
	self.lastUpdate = os.time()
	
	self.xmlDoc = XmlDoc.CreateFromFile("TimerWindow.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	Apollo.CreateTimer("update", nAlertTimer, true)
	Apollo.RegisterTimerHandler("update", "updateUI", self)
	Apollo.StopTimer("update")
	
	Apollo.CreateTimer("notifications", nNotificationTimer, true)
	Apollo.RegisterTimerHandler("notifications", "notifications", self)
end

function Playtime:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain  = Apollo.LoadForm(self.xmlDoc, "TimerForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, tStrings.err_main_ui)
			return
		end

	    self.wndMain:Show(false)
		
		self.wndAlert  = Apollo.LoadForm(self.xmlDoc, "AlertForm", nil, self)
		if self.wndAlert  == nil then
			Apollo.AddAddonErrorText(self, tStrings.err_alert_ui)
			return
		end
		self.wndAlert:Show(false)
		
		self.wndNewAlert = Apollo.LoadForm(self.xmlDoc, "NewAlert", nil, self)
		if self.wndNewAlert == nil then
			Apollo.AddAddonErrorText(self, tStrings.err_newalert_ui)
			return
		end
		self.wndNewAlert:Show(false)	
		
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = tStrings.name_main_ui})
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndAlert, strName = tStrings.name_alert_ui})
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndNewAlert, strName = tStrings.name_newalert_ui})

		
		self:updateUIWindow()

		self.xmlDoc = nil
	end
end

---------------------------------------------------
-- Update and Apollo timer callback functions
---------------------------------------------------

function Playtime:updateData()
	self.character = GameLib.GetPlayerUnit():GetName()
	if self.data.characters[self.character] == nil then 
		self.data.characters[self.character] = 0
	end
	
	self.data.characters[self.character] = self.data.characters[self.character] + (os.time() - self.lastUpdate)
	self.lastUpdate = os.time()
end

function Playtime:updateUI()
	if next(self.alerts) ~= nil then
		local count = 0
		for name, alert in spairs(self.alerts, sSortAlerts) do
			count = count + 1
			local leftover = alert - os.time()
			if leftover > 0 then
				self.wndMain:FindChild("Button"..count):SetText(secondsToTime(leftover))
			else
				ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.alert_done, name), tStrings.alert_prefix)
				self.wndAlert:FindChild('Text'):SetText(string.format(tStrings.px_alert_done, name))
				self.wndAlert:Show(true)
				Sound.Play(nAlertBuzzSound)
				Sound.Play(nAlertBuzzSound)
				Sound.Play(nAlertBuzzSound)
				Sound.Play(nAlertBuzzSound)
				self.alerts[name] = nil
				self:updateUIWindow()
			end
		end
	end
end

function Playtime:updateUIWindow()
	if next(self.alerts) ~= nil then
		local count = 0
		for name, alert in spairs(self.alerts, sSortAlerts) do
			count = count + 1
			self.wndMain:FindChild("Button"..count):SetTooltip(name)
		end

		local alertAmount = countTable(self.alerts)
		local left, top, right, bottom = self.wndMain:GetAnchorOffsets()
		self.wndMain:SetAnchorOffsets(left, top, right, (top + 12 + (28 * alertAmount)))
		
		if bUseAlertWindow then
			self.wndMain:Show(true)
		end
		Apollo.StartTimer("update")
	else
		self.wndMain:Show(false)
		Apollo.StopTimer("update")
	end
end

function Playtime:notifications()
	if bUseSesNotifications then
		local sessionSeconds = os.time() - self.startSession
		local hours = math.floor(sessionSeconds / 3600)
		if hours > 0 and self.notificationsShown[hours] == nil then
			local suffix = "hour"
			if hours > 1 then suffix = suffix .. "s" end
			local main_message = string.format(tStrings.played_for, hours, suffix)
		
			local message = ""
			if tStrings["nf_" .. hours .. "_hour"] ~= nil then
				message = ", " .. tStrings["nf_" .. hours .. "_hour"]
			end
	
			ChatSystemLib.PostOnChannel(nSysChannel, main_message .. message, tStrings.playtime_prefix)
			self.notificationsShown[hours] = 1
		end
	end
	
	if bUseTotNotifications then
		self:updateData()
		local totalSeconds = 0 
		
		for key, value in pairs(self.data.characters) do
			totalSeconds = totalSeconds + value
		end
		
		local hours = math.floor(totalSeconds / 3600)
		if hours > 0 and self.totalNotificationsShown[hours] == nil then
			local suffix = "hour"
			if hours > 1 then suffix = suffix .. "s" end
			local main_message = string.format(tStrings.total_played, hours, suffix)
		
			local message = ""
			if tStrings["nf_" .. hours .. "_total"] ~= nil then
				message = ", " .. tStrings["nf_" .. hours .. "_total"]
			end
	
			ChatSystemLib.PostOnChannel(nSysChannel, main_message .. message, tStrings.playtime_prefix)
			self.totalNotificationsShown[hours] = 1
		end
	end
end

---------------------------------------------------
-- Playtime system commands
---------------------------------------------------

-- /playtime command
function Playtime:onPlaytimeCommand(cmd, param)
	playCommandSound()
	self:updateData()

	if param == "help" or param == "?" or param == "info" then
		self:onAddonHelp()
	else		
		sessionSeconds = os.time() - self.startSession
		characterSeconds = self.data.characters[self.character]
		
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.char_playtime, self.character, secondsToString(characterSeconds)), tStrings.playtime_prefix)
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.sess_playtime, secondsToString(sessionSeconds)), tStrings.playtime_prefix)
	end
end

-- /fullplaytime command
function Playtime:onFullPlaytimeCommand()
	playCommandSound()
	self:updateData()
	
	sessionSeconds = os.time() - self.startSession
	characterSeconds = self.data.characters[self.character]
	
	local totalSeconds = 0 
	
	for key, value in pairs(self.data.characters) do
		totalSeconds = totalSeconds + value
	end
	
	ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.total_playtime, secondsToString(totalSeconds)), tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.sess_playtime, secondsToString(sessionSeconds)), tStrings.playtime_prefix)
	
	for key, value in spairs(self.data.characters, "DESC") do
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.char_playtime, key, secondsToString(value)), tStrings.playtime_prefix)
	end
end

-- /resetsession command
function Playtime:onResetSessionCommand()
	playCommandSound()
	self:updateData()
	self.startSession = os.time()
	ChatSystemLib.PostOnChannel(nSysChannel, tStrings.session_reset, tStrings.playtime_prefix)
end

function Playtime:onAddonHelp()
	ChatSystemLib.PostOnChannel(nSysChannel, tStrings.playtime_cmds, tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, "/playtime", tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, "/fullplaytime", tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, "/resetplaytime", tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, "/setalert", tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, "/removealert", tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, tStrings.more_info, tStrings.playtime_prefix)
	ChatSystemLib.PostOnChannel(nSysChannel, tStrings.author, tStrings.playtime_prefix)
end

---------------------------------------------------
-- Timer system commands
---------------------------------------------------

-- /timer
function Playtime:onTimerCommand()
	playCommandSound()
	if self.timerdata.timerRunning then
		timeRun = os.time() - self.timerdata.timerStart
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.timer, secondsToTime(timeRun)), tStrings.timer_prefix)
	else
		timeRun = self.timerdata.timerStop - self.timerdata.timerStart
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.timer, secondsToTime(timeRun)), tStrings.timer_prefix)
	end
end

-- /timerstart
function Playtime:onTimerStartCommand()
	playCommandSound()
	if self.timerdata.timerStop ~= 0 then
		self.timerdata.timerStart = self.timerdata.timerStop
	end
	if self.timerdata.timerStart == 0 then
		self.timerdata.timerStart = os.time()
		ChatSystemLib.PostOnChannel(nSysChannel, tStrings.timer_start, tStrings.timer_prefix)
	else
		ChatSystemLib.PostOnChannel(nSysChannel, tStrings.timer_continue, tStrings.timer_prefix)
	end
	self.timerdata.timerRunning = true
end

-- /timerstop
function Playtime:onTimerStopCommand()
	playCommandSound()
	self.timerdata.timerStop = os.time()
	self.timerdata.timerRunning = false
	timeRun = self.timerdata.timerStop - self.timerdata.timerStart
	ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.timer_stop, secondsToTime(timeRun)), tStrings.timer_prefix)
end

-- /timerreset
function Playtime:onTimerResetCommand()
	playCommandSound()
	self.timerdata.timerStart = 0
	self.timerdata.timerRunning = false
	self.timerdata.timerStop = os.time()
	ChatSystemLib.PostOnChannel(nSysChannel, tStrings.timer_reset, tStrings.timer_prefix)
end

---------------------------------------------------
-- Alert notification system commands
---------------------------------------------------

-- /setalert params
function Playtime:onAlertCommand(cmd, param)
	playCommandSound()
	if countTable(self.alerts) == 9 then
		ChatSystemLib.PostOnChannel(nSysChannel, tStrings.max_alerts, tStrings.alert_prefix)
	else
		local split = {}
		for w in param:gmatch("%S+") do table.insert(split, w) end
		local amount = tonumber(split[2])
		local name = split[1]
		local multiplier = split[3]
		
		if multiplier == nil then multiplier = sDefaultAlert end
		
		if amount == nil or name == nil or multiplier == nil then
			ChatSystemLib.PostOnChannel(nSysChannel, tStrings.incorrect_format, tStrings.alert_prefix)
		else
			local seconds = 0
			if multiplier == "second" or multiplier == "seconds" or multiplier == "sec" or multiplier == "s" then
				seconds = amount
			elseif multiplier == "minute" or multiplier == "minutes" or multiplier == "min" or multiplier == "m" then
				seconds = amount * 60
			elseif multiplier == "hour" or multiplier == "hours" or multiplier == "h" then
				seconds = amount * ( 60 * 60 )
			else
				ChatSystemLib.PostOnChannel(nSysChannel, tStrings.incorrect_format, tStrings.alert_prefix)
			end
			
			if seconds > 0 then
				self.alerts[name] = os.time() + seconds
				self:updateUIWindow()
			end
		end
	end
end

-- /removealert
function Playtime:onRemoveAlertCommand(cmd, param)
	playCommandSound()
	if self.alerts[param] ~= nil then
		self.alerts[param] = nil
		self:updateUIWindow()
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.alert_removed, param), tStrings.alert_prefix)
	else
		ChatSystemLib.PostOnChannel(nSysChannel, string.format(tStrings.alert_not_found, param), tStrings.alert_prefix)	
	end
end

function Playtime:onNewAlert()
	self.wndNewAlert:Show(true)
end

function Playtime:onAlertPreview()
	self.wndAlert:FindChild('Text'):SetText(tStrings.alert_preview)
	self.wndAlert:Show(true)
	Sound.Play(nAlertBuzzSound)
	Sound.Play(nAlertBuzzSound)
	Sound.Play(nAlertBuzzSound)
	Sound.Play(nAlertBuzzSound)
end

----------------------------------------------------
-- Utility functions
----------------------------------------------------

function secondsToString(_seconds)
	local result = {}
	
	local days = math.floor(_seconds / 86400)
	if days ~= 0 then 
		table.insert(result, days .. 'd')
	end
	
	local hours = math.floor(_seconds/3600 - (days * 24))
	if hours ~= 0 then
		table.insert(result, hours .. 'h')
	end
	
	local minutes = math.floor(_seconds/60 - (days * 1440) - (hours * 60) )
	table.insert(result, minutes .. 'm')
	
	local seconds = math.floor(_seconds % 60)
	table.insert(result, seconds .. 's')
	
	return table.concat(result, " ")
end

function secondsToTime(_seconds)
	local result = {}
	
	local hours = math.floor(_seconds/3600)
	if hours ~= 0 then
		if hours < 10 then hours = "0" .. hours end
		table.insert(result, hours)
	end
	
	local minutes = math.floor(_seconds/60 - (hours * 60) )
	if minutes < 10 then minutes = "0" .. minutes end
	table.insert(result, minutes)
	
	local seconds = math.floor(_seconds % 60)
	if seconds < 10 then seconds = "0" .. seconds end
	table.insert(result, seconds)
	
	return table.concat(result, ":")
end

function countTable(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function spairs(t, order)
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end
	
	if order == "ASC" then
		order = function(t,a,b) return t[b] < t[a] end
	elseif order == "DESC" then
		order = function(t,a,b) return t[b] > t[a] end
	end
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function playCommandSound()
	if bUseCommandSound then
		Sound.Play(nCommandSound)
	end	
end

----------------------------------------------------
-- Window callback functions
----------------------------------------------------

function Playtime:AlertClose(wndHandler, wndControl, eMouseButton)
	self.wndAlert:Show(false)
end

function Playtime:OnNewAlertSave( wndHandler, wndControl, eMouseButton )
	local name = self.wndNewAlert:FindChild("Name"):GetText()
	local time = self.wndNewAlert:FindChild("Time"):GetText()
	local multiplier = self.wndNewAlert:FindChild("Sec")
	-- TODO: Get checked option
		
	if amount == nil or name == nil or multiplier == nil then
		ChatSystemLib.PostOnChannel(nSysChannel, tStrings.incorrect_format, tStrings.alert_prefix)
	else
		local seconds = 0
		if multiplier == "sec" then
			seconds = time 
		elseif multiplier == "min" then
			seconds = time * 60
		elseif multiplier == "hour" then
			seconds = time * ( 60 * 60 )
		else
			ChatSystemLib.PostOnChannel(nSysChannel, tStrings.incorrect_format, tStrings.alert_prefix)
		end
		
		if seconds > 0 then
			self.alerts[name] = os.time() + seconds
			self:updateUIWindow()
		end
	end
	
	self.wndNewAlert:Show(false)
end

function Playtime:OnNewAlertCancel( wndHandler, wndControl, eMouseButton )
	self.wndNewAlert:Show(false)
end

----------------------------------------------------
-- Data save and load
----------------------------------------------------

function Playtime:OnSave(eLevel)		
	self:updateData()
	local session = { 
		startSession = self.startSession, 
		endSession = os.time(), 
		notificationsShown = self.notificationsShown,
		totalNotificationsShown = self.totalNotificationsShown
	}
	
	if eLevel == GameLib.CodeEnumAddonSaveLevel.General then
    	return { data = self.data, alerts = self.alerts, session = session }
	else
		return nil;	
	end
end

function Playtime:OnRestore(eLevel, tData)
	if tData.data ~= nil then
        self.data = tData.data
    end
	if tData.alerts ~= nil then
		self.alerts = tData.alerts
	end
	if tData.session ~= nil then
		if tData.session.endSession + nSessionRestart >= os.time() then
			self.startSession = tData.session.startSession
			if tData.session.notificationsShown ~= nil then
				self.notificationsShown = tData.session.notificationsShown
			end
		end
		if tData.session.totalNotificationsShown ~= nil then
			self.totalNotificationsShown = tData.session.totalNotificationsShown
		end
	end
end

----------------------------------------------------
-- Instance and initialize
----------------------------------------------------
local PlaytimeInst = Playtime:new()
PlaytimeInst:Init()
