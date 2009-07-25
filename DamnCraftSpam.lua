--[[
	Damn Craft Spam, Mayen of Mal'Ganis (US) PvP
]]
local counterFrame

local function deformat(text)
	text = string.gsub(text, "%.", "%%.")
	text = string.gsub(text, "%%s", "(.+)")
	text = string.gsub(text, "%%d", "([0-9]+)")
	return text
end

local chatFrames, totalCreated, resetTimer, craftList = {}, {}, {}, {}
local youCreate, youCreateMulti = deformat(LOOT_ITEM_CREATED_SELF), deformat(LOOT_ITEM_CREATED_SELF_MULTIPLE)
local craftQuantity, craftItemID
local _G = getfenv(0)
local frame = CreateFrame("Frame")
frame:Hide()

-- Handles sending a chat message to all frames that have it registered
local function sendMessage(event, msg)
	local info = ChatTypeInfo[string.sub(event, 10)]
	for i=1, 7 do
		chatFrames[i] = chatFrames[i] or _G["ChatFrame" .. i]
		if( chatFrames[i] and chatFrames[i]:IsEventRegistered(event) ) then
			chatFrames[i]:AddMessage(msg, info.r, info.g, info.b)
		end
	end
end

-- We only want to reduce the spam when they are trying to craft more than an item at a time, so if they are only doing one then ignore it.
hooksecurefunc("DoTradeSkill", function(id, quantity)
	local itemID = string.match(GetTradeSkillItemLink(id), "item:(%d+)")
	if( itemID ) then
		craftQuantity = quantity
		craftItemID = tonumber(itemID)
		counterFrame = nil
	end
end)

-- Watch for spam to time out and be ready to output
frame:SetScript("OnUpdate", function(self, elapsed)
	local found
	local time = GetTime()
	for itemID, resetAt in pairs(resetTimer) do
		found = true
		
		if( resetAt <= time ) then
			sendMessage("CHAT_MSG_LOOT", string.format(LOOT_ITEM_CREATED_SELF_MULTIPLE, (select(2, GetItemInfo(itemID))), totalCreated[itemID]))
			
			totalCreated[itemID] = nil
			resetTimer[itemID] = nil
		end
	end
	
	-- Nothing else to watch
	if( not found ) then
		self:Hide()
	end
end)

-- Grab a list of items for the tradeskill so we can monitor them for spam
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:SetScript("OnEvent", function(self)
	if( IsTradeSkillLinked() or not GetTradeSkillLine() ) then return end
	
	for i=1, GetNumTradeSkills() do
		if( GetTradeSkillItemLink(i) and GetTradeSkillRecipeLink(i) ) then
			local itemID = string.match(GetTradeSkillItemLink(i), "item:(%d+)")
			local enchantID = string.match(GetTradeSkillRecipeLink(i), "enchant:(%d+)")
			if( itemID and enchantID ) then
				craftList[tonumber(itemID)] = select(7, GetSpellInfo(enchantID)) / 1000
			end
		end
	end
end)

local function isBlockedMessage(self, link, quantity)
	local itemID = tonumber(string.match(link, "item:(%d+)"))
	if( not itemID or not craftList[itemID] or craftItemID ~= itemID or craftQuantity <= 1 ) then return end

	-- This lets us keep blocking item gains on all frames, but only counting item gains for one frame
	if( counterFrame and counterFrame ~= self ) then return true end
	counterFrame = self
	
	-- Add in the total time it takes to craft it, and then add an additional 2 seconds leeway
	totalCreated[itemID] = (totalCreated[itemID] or 0) + (tonumber(quantity) or 1)
	resetTimer[itemID] = GetTime() + craftList[itemID] + 2

	-- Start watching!
	frame:Show()
	
	return true
end

-- Do we need to filter them?
local orig_ChatFrame_MessageEventHandler = ChatFrame_MessageEventHandler
function ChatFrame_MessageEventHandler(self, event, ...)
	-- Not an achievement, don't care about it
	if( event ~= "CHAT_MSG_LOOT" ) then
		return orig_ChatFrame_MessageEventHandler(self, event, ...)
	end
	
	-- First we have to check for the pain in the ass linkxquantity pattern, then link, then block it if it's true
	-- otherwise use the original stuff
	local msg, author = select(1, ...)
	local link, quantity = string.match(msg, youCreateMulti)
	if( not link and not quantity ) then
		link = string.match(msg, youCreate)
	end
	
	if( link and isBlockedMessage(self, link, quantity) ) then
		return true
	end
		
	return orig_ChatFrame_MessageEventHandler(self, event, ...)
end
