--[[
Title: Rules
Author(s): LiXizhi
Date: 2014/1/29
Desc: slash command 
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandRules.lua");
-------------------------------------------------------
]]
local SlashCommand = commonlib.gettable("MyCompany.Aries.SlashCommand.SlashCommand");
local WorldManager = commonlib.gettable("MyCompany.Aries.WorldManager");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local BroadcastHelper = commonlib.gettable("CommonCtrl.BroadcastHelper");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");

local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

Commands["addrule"] = {
	name="addrule", 
	quick_ref="/addrule class_name rule", 
	desc=[[add a given game rule. Some examples rules: 
/addrule Block CanPlace Lever Glowstone
/addrule Block CanDestroy Glowstone true
/addrule Player AutoWalkupBlock false
/addrule Player CanJump true
/addrule Player PickingDist 5
/addrule Player CanJumpInAir true
/addrule Player CanJumpInWater true
/addrule Player JumpUpSpeed 5
/addrule Player AllowRunning false
]], 
	handler = function(cmd_name, cmd_text, cmd_params)
		local name, value = cmd_text:match("(%w+)%s+(.*)$");
		if(name and value) then
			NPL.load("(gl)script/apps/Aries/Creator/Game/GameRules/GameRules.lua");
			local GameRules = commonlib.gettable("MyCompany.Aries.Game.GameRules");
			GameRules:AddRule(name, value);
		end
	end,
};

-- /rule			:show all rules
-- /rule reset		:reset all rules
-- /rule reload		:reload from rule.lua file. 
Commands["rule"] = {
	name="rule", 
	quick_ref="/rule", 
	desc="show all rules or reset rules" , 
	handler = function(cmd_name, cmd_text, cmd_params)
		if(cmd_text == "") then
			NPL.load("(gl)script/apps/Aries/Creator/Game/GameRules/GameRules.lua");
			local GameRules = commonlib.gettable("MyCompany.Aries.Game.GameRules");
			GameRules:ShowAllRules();
		elseif(cmd_text == "reset") then
			NPL.load("(gl)script/apps/Aries/Creator/Game/GameRules/GameRules.lua");
			local GameRules = commonlib.gettable("MyCompany.Aries.Game.GameRules");
			GameRules:Reset();
		elseif(cmd_text == "reload") then
			NPL.load("(gl)script/apps/Aries/Creator/Game/GameRules/GameRules.lua");
			local GameRules = commonlib.gettable("MyCompany.Aries.Game.GameRules");
			GameRules:LoadFromFile();
		end
	end,
};