--[[
Title: NetClientHandler
Author(s): LiXizhi
Date: 2014/6/25
Desc: used on client side, represent a connection to server. 
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/NetClientHandler.lua");
local NetClientHandler = commonlib.gettable("MyCompany.Aries.Game.Network.NetClientHandler");
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/NetHandler.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/ConnectionTCP.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/Packets/Packet_Types.lua");
NPL.load("(gl)script/ide/math/bit.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Network/NetworkMain.lua");
local NetworkMain = commonlib.gettable("MyCompany.Aries.Game.Network.NetworkMain");
local Packets = commonlib.gettable("MyCompany.Aries.Game.Network.Packets");
local ConnectionTCP = commonlib.gettable("MyCompany.Aries.Game.Network.ConnectionTCP");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local Desktop = commonlib.gettable("MyCompany.Aries.Creator.Game.Desktop");
local ItemStack = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
local BroadcastHelper = commonlib.gettable("CommonCtrl.BroadcastHelper");

local rshift = mathlib.bit.rshift;
local lshift = mathlib.bit.lshift;
local band = mathlib.bit.band;
local bor = mathlib.bit.bor;

local NetClientHandler = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.Network.NetHandler"), commonlib.gettable("MyCompany.Aries.Game.Network.NetClientHandler"));

function NetClientHandler:ctor()
end

-- create a tcp connection to server. 
function NetClientHandler:Init(ip, port, username, password, worldClient)
	self.worldClient = worldClient;
	local nid = self:CheckGetNidFromIPAddress(ip, port);
	BroadcastHelper.PushLabel({id="NetClientHandler", label = format(L"正在建立链接:%s:%s", ip, port or ""), max_duration=7000, color = "255 0 0", scaling=1.1, bold=true, shadow=true,});
	self.connection = ConnectionTCP:new():Init(nid, nil, self);
	self.connection:Connect(5, function(bSucceed)
		-- try authenticate
		if(bSucceed) then
			BroadcastHelper.PushLabel({id="NetClientHandler", label = format(L"成功建立链接:%s:%s", ip, port or ""), max_duration=4000, color = "255 0 0", scaling=1.1, bold=true, shadow=true,});
			self:SendLoginPacket(username, password);
		end
	end);
	return self;
end

function NetClientHandler:SendLoginPacket(username, password)
	self.last_username = username;
	self.last_password = password;
	self:AddToSendQueue(Packets.PacketAuthUser:new():Init(username, password));
end

function NetClientHandler:GetNid()
	return self.connection:GetNid();
end

 -- Adds the packet to the send queue
function NetClientHandler:AddToSendQueue(packet)
    if (not self.disconnected and self.connection) then
        return self.connection:AddPacketToSendQueue(packet);
    end
end

-- clean up connection. 
function NetClientHandler:Cleanup()
    if (self.connection) then
        self.connection:NetworkShutdown();
    end
    self.connection = nil;
	if(self.worldClient) then
	end
end

function NetClientHandler:handleErrorMessage(text)
	LOG.std(nil, "info", "NetClientHandler", "client connection error %s", text or "");

	if(text == "ConnectionNotEstablished") then
		BroadcastHelper.PushLabel({id="NetClientHandler", label = L"无法链接到这个服务器", max_duration=6000, color = "255 0 0", scaling=1.1, bold=true, shadow=true,});
		_guihelper.MessageBox(L"无法链接到这个服务器,可能该服务器未开启或已关闭.详情请联系该服务器管理员.");
	else --if(text == "OnConnectionLost") then
		if(GameLogic.GetWorld() == self.worldClient) then
			BroadcastHelper.PushLabel({id="NetClientHandler", label = L"与服务器的连接断开了", max_duration=6000, color = "255 0 0", scaling=1.1, bold=true, shadow=true,});
			NetworkMain.isClient = false;
			NPL.load("(gl)script/apps/Aries/Creator/Game/Areas/ServerPage.lua");
			local ServerPage = commonlib.gettable("MyCompany.Aries.Creator.Game.Desktop.ServerPage");
			ServerPage.ResetClientInfo()
			_guihelper.MessageBox(L"已与服务器断开连接,可能服务器已关闭或有其他用户使用该帐号登录.点击\"确定\"返回本地世界",function (result)
				NPL.load("(gl)script/apps/Aries/Creator/Game/Login/InternetLoadWorld.lua");
				local InternetLoadWorld = commonlib.gettable("MyCompany.Aries.Creator.Game.Login.InternetLoadWorld");
				InternetLoadWorld.EnterWorld()
				--if(result == _guihelper.DialogResult.Yes) then
				--end
			end,_guihelper.MessageBoxButtons.OK);
			--local player = self.worldClient:GetPlayer();
			--if(player) then
				--player:UpdateDisplayName("oops! ConnectionLost!");
			--end
		end
	end
	self:Cleanup();
end

function NetClientHandler:GetEntityByID(id)
	if(id == self.worldClient:GetPlayer().entityId) then
		return self.worldClient:GetPlayer();
	else
		return self.worldClient:GetEntityByID(id);
	end
end

function NetClientHandler:handleAuthUser(packet_AuthUser)
	if(packet_AuthUser.result == "ok") then
		-- load empty world first and then login. 

		-- create the client side player entity
		self.worldClient.isRemote = true;
	
		-- only add when this is a connected world
		NetworkMain:AddClient(self.worldClient);
		--NetworkMain:SetAsClient();
		NetworkMain.isClient = true;
		local bStartNewWorld = true;
		if(bStartNewWorld) then
			-- spawn in a new world
			MyCompany.Aries.Game.StartEmptyClientWorld(self.worldClient, function()
				-- empty world is prepared, so request to login. 
				self:AddToSendQueue(Packets.PacketLoginClient:new():Init());
			end);
		else
			-- replace current world: only used in debugging
			if(not GameLogic.GetWorld() or (not GameLogic.GetWorld():isa(MyCompany.Aries.Game.World.WorldClient) and not GameLogic.GetWorld():isa(MyCompany.Aries.Game.World.WorldServer))) then
				GameLogic.ReplaceWorld(self.worldClient);
			end
			self:AddToSendQueue(Packets.PacketLoginClient:new():Init());
		end
	elseif(packet_AuthUser.result == "failed") then
		if(not self.last_password or self.last_password=="") then
			BroadcastHelper.PushLabel({id="NetClientHandler", label = L"连接成功：此服务器需要认证", max_duration=7000, color = "0 255 0", scaling=1.1, bold=true, shadow=true,});
		else
			BroadcastHelper.PushLabel({id="NetClientHandler", label = L"用户名密码不正确", max_duration=7000, color = "255 0 0", scaling=1.1, bold=true, shadow=true,});
		end
		--echo("555555555555");
		NPL.load("(gl)script/apps/Aries/Creator/Game/Areas/ServerPage.lua");
		local ServerPage = commonlib.gettable("MyCompany.Aries.Creator.Game.Desktop.ServerPage");
		ServerPage.ShowUserLoginPage(self,packet_AuthUser.info);

		--NPL.load("(gl)script/apps/Aries/Creator/Game/GUI/EnterTextDialog.lua");
		--local EnterTextDialog = commonlib.gettable("MyCompany.Aries.Game.GUI.EnterTextDialog");
		--EnterTextDialog.ShowPage("请输入用户名:密码", function(result)
			--if(result) then
				--local username, password = result:match("^(%S+)%s*[=:%s]%s*(%S+)");
				--if(username and password) then
					--self:SendLoginPacket(username, password);
				--end
			--end
		--end)
		--local params = {
			--url = "script/apps/Aries/Creator/Game/Areas/ServerLogin.html", 
			--name = "ServerLogin", 
			--isShowTitleBar = false,
			--DestroyOnClose = true,
			--bToggleShowHide=true, 
			--style = CommonCtrl.WindowFrame.ContainerStyle,
			--allowDrag = false,
			--enable_esc_key = true,
			----bShow = bShow,
			--click_through = false, 
			--zorder = -1,
			--directPosition = true,
				--align = "_ct",
				--x = -400/2,
				--y = -300/2,
				--width = 400,
				--height = 300,
		--};
		--System.App.Commands.Call("File.MCMLWindowFrame", params);
	end
end

function NetClientHandler:handleLogin(packet_login)
	local entityPlayer = self.worldClient:CreateClientPlayer(packet_login.clientEntityId, self);
	self.currentServerMaxPlayers = packet_login.maxPlayers;
end

function NetClientHandler:handleSpawnPosition(packet_SpawnPosition)
	LOG.std(nil, "debug", "NetClientHandler.handleSpawnPosition", packet_SpawnPosition);
    self.worldClient:SetSpawnPoint(packet_SpawnPosition.x, packet_SpawnPosition.y, packet_SpawnPosition.z);
end

function NetClientHandler:handleChat(packet_Chat)
    LOG.std(nil, "debug", "NetClientHandler.handleChat", "%s", packet_Chat.text);
	Desktop.GetChatGUI():PrintChatMessage(packet_Chat:ToChatMessage())
end

function NetClientHandler:handleAnimation(packet_Animation)
    local entity = self:GetEntityByID(packet_Animation.entityId);
	if(entity) then
		entity:SetAnimation(packet_Animation.anim_id);
	end
end

function NetClientHandler:handlePlayerInfo(packet_PlayerInfo)
end

-- the server tells us to teleport to this location. 
function NetClientHandler:handleMove(packet_Move)
	local curPlayer = self.worldClient:GetPlayer();
	local posX = curPlayer.x;
    local posY = curPlayer.y;
    local posZ = curPlayer.z;
    local yaw = curPlayer.facing;
    local pitch = curPlayer.rotationPitch;
	if (packet_Move.x) then
        posX = packet_Move.x;
        posY = packet_Move.y;
        posZ = packet_Move.z;
    end
	if (packet_Move.yaw) then
        yaw = packet_Move.yaw;
        pitch = packet_Move.pitch;
    end
	curPlayer:SetPositionAndRotation(posX, posY, posZ, yaw, pitch);
	packet_Move.x = curPlayer.x;
    packet_Move.y = curPlayer.y;
	packet_Move.stance = curPlayer.y;
    packet_Move.z = curPlayer.z;
	self:AddToSendQueue(packet_Move);
end

function NetClientHandler:handleEntityPlayerSpawn(packet_EntityPlayerSpawn)
	local x = packet_EntityPlayerSpawn.x / 32;
    local y = packet_EntityPlayerSpawn.y / 32;
    local z = packet_EntityPlayerSpawn.z / 32;
    local facing = packet_EntityPlayerSpawn.facing / 32;
    local pitch = packet_EntityPlayerSpawn.pitch / 32;
	local clientMP = self:GetEntityByID(packet_EntityPlayerSpawn.entityId);
	if(not clientMP or not clientMP:isa(EntityManager.EntityPlayerMPOther)) then
		clientMP = EntityManager.EntityPlayerMPOther:new():init(self.worldClient, packet_EntityPlayerSpawn.name, packet_EntityPlayerSpawn.entityId);	
	else
		LOG.std(nil, "warn", "NetClientHandler", "client MP with id %d already exist", packet_EntityPlayerSpawn.entityId);
	end
    clientMP.prevPosX = packet_EntityPlayerSpawn.x;
	clientMP.lastTickPosX = packet_EntityPlayerSpawn.x;
	clientMP.serverPosX = packet_EntityPlayerSpawn.x;
    clientMP.prevPosY = packet_EntityPlayerSpawn.y;
	clientMP.lastTickPosY = packet_EntityPlayerSpawn.y;
	clientMP.serverPosY = packet_EntityPlayerSpawn.y;
    clientMP.prevPosZ = packet_EntityPlayerSpawn.z;
	clientMP.lastTickPosZ = packet_EntityPlayerSpawn.z;
	clientMP.serverPosZ = packet_EntityPlayerSpawn.z;
    local curItemId = packet_EntityPlayerSpawn.curItem;

    if (curItemId == 0) then
        clientMP.inventory:GetSlots()[clientMP.inventory:GetCurrentItemIndex()] = nil;
    else
        clientMP.inventory:GetSlots()[clientMP.inventory:GetCurrentItemIndex()] = ItemStack:new():Init(curItemId, 1);
    end

    clientMP:SetPositionAndRotation(x, y, z, facing, pitch);
	clientMP:Attach();
	
	-- TODO: watched data? such as animation, action, etc. 
end

-- when entity of other entityMP moves relatively. 
function NetClientHandler:handleRelEntity(packet_RelEntity)
    local entityOther = self:GetEntityByID(packet_RelEntity.entityId);

    if (entityOther) then
        entityOther.serverPosX = entityOther.serverPosX + (packet_RelEntity.x or 0);
        entityOther.serverPosY = entityOther.serverPosY + (packet_RelEntity.y or 0);
        entityOther.serverPosZ = entityOther.serverPosZ + (packet_RelEntity.z or 0);
        local x = entityOther.serverPosX / 32;
        local y = entityOther.serverPosY / 32;
        local z = entityOther.serverPosZ / 32;

		local facing;
		if(packet_RelEntity.facing) then
			facing = packet_RelEntity.facing / 32;
		end
		local pitch;
		if(packet_RelEntity.pitch) then
			pitch = packet_RelEntity.pitch / 32;
		end
        entityOther:SetPositionAndRotation2(x, y, z, facing, pitch, 3);
    end
end

-- called periodially in addition to RelEntity, to force a complete position update. 
function NetClientHandler:handleEntityTeleport(packet_EntityTeleport)
	local entityOther = self:GetEntityByID(packet_EntityTeleport.entityId);

    if (entityOther) then
        entityOther.serverPosX = packet_EntityTeleport.x;
        entityOther.serverPosY = packet_EntityTeleport.y;
        entityOther.serverPosZ = packet_EntityTeleport.z;
        local x = entityOther.serverPosX / 32;
        local y = entityOther.serverPosY / 32 + 0.015625;
        local z = entityOther.serverPosZ / 32;
        local facing;
		if(packet_EntityTeleport.rotating) then
			facing = packet_EntityTeleport.facing / 32;
		end
		local pitch;
		if(packet_EntityTeleport.pitch) then
			pitch = packet_EntityTeleport.pitch / 32;
		end
        entityOther:SetPositionAndRotation2(x, y, z, facing, pitch, 3);
    end
end
 
function NetClientHandler:handleEntityMetadata(packet_EntityMetadata)
    local entity = self:GetEntityByID(packet_EntityMetadata.entityId);

	if(entity~=self.worldClient:GetPlayer()) then
		-- ignore metadata for current player. 
		if (entity and packet_EntityMetadata:GetMetadata()) then
			local watcher = entity:GetDataWatcher();
			if(watcher) then
				watcher:UpdateWatchedObjectsFromList(packet_EntityMetadata:GetMetadata());
			end
		end
	end
end

function NetClientHandler:handleDestroyEntity(packet_DestroyEntity)
    for i =1, #(packet_DestroyEntity.entity_ids) do
        self.worldClient:RemoveEntityFromWorld(packet_DestroyEntity.entity_ids[i]);
    end
end

function NetClientHandler:handleBlockChange(packet_BlockChange)
	self.worldClient:EnableWorldTracker(false);
	BlockEngine:SetBlock(packet_BlockChange.x, packet_BlockChange.y, packet_BlockChange.z, packet_BlockChange.blockid, packet_BlockChange.data, 0);
	self.worldClient:EnableWorldTracker(true);
end    

function NetClientHandler:handleBlockMultiChange(packet_BlockMultiChange)
	self.worldClient:EnableWorldTracker(false);
    local cx = packet_BlockMultiChange.chunkX * 16;
    local cz = packet_BlockMultiChange.chunkZ * 16;
	local blockList = packet_BlockMultiChange.blockList;
	local idList = packet_BlockMultiChange.idList;
	local dataList = packet_BlockMultiChange.dataList;
    if (blockList) then
        for i = 1, #blockList do
			local packedIndex = blockList[i];
			local x, y, z;
			x = cx + band(rshift(packedIndex, 12), 15);
			y = band(packedIndex, 255);
			z = cz + band(rshift(packedIndex, 8), 15);
			BlockEngine:SetBlock(x, y, z, idList[i], dataList[i], 0);
        end
	end
	self.worldClient:EnableWorldTracker(true);
end

function NetClientHandler:handleBlockPieces(packet_BlockPieces)
	local block_template = block_types.get(packet_BlockPieces.blockid);
	if(block_template) then
		block_template:CreateBlockPieces(packet_BlockPieces.x,packet_BlockPieces.y,packet_BlockPieces.z, packet_BlockPieces.granularity);
	end
end

-- full chunk update of blocks, metadata
function NetClientHandler:handleMapChunk(packet_MapChunk)
	if (packet_MapChunk.bIncludeInit) then
        if (packet_MapChunk.chunkExistFlag == 0) then
            self.worldClient:DoPreChunk(packet_MapChunk.x, packet_MapChunk.z, false);
            return;
        end
        self.worldClient:DoPreChunk(packet_MapChunk.xCh, packet_MapChunk.zCh, true);
	end

    self.worldClient:InvalidateBlockReceiveRegion(packet_MapChunk.x*16, 0, packet_MapChunk.z*16, (packet_MapChunk.x*16) + 15, 256, (packet_MapChunk.z*16) + 15);
    local chunk = self.worldClient:GetChunkFromChunkCoords(packet_MapChunk.x, packet_MapChunk.z);

    if (packet_MapChunk.bIncludeInit and not chunk) then
        self.worldClient:DoPreChunk(packet_MapChunk.x, packet_MapChunk.z, true);
        chunk = self.worldClient:GetChunkFromChunkCoords(packet_MapChunk.x, packet_MapChunk.z);
    end

    if (chunk) then
		chunk:FillChunk(packet_MapChunk:GetCompressedChunkData(), packet_MapChunk.chunkExistFlag, packet_MapChunk.includeInitialize);
        -- mark re render the blocks. 
        if (not packet_MapChunk.bIncludeInit) then
            chunk:ResetRelightChecks();
        end
    end
end

-- initial chunk updates
function NetClientHandler:handleMapChunks(packet_MapChunks)
	for i = 1, packet_MapChunks:GetNumberOfChunks() do
        local chunkX = packet_MapChunks:GetChunkPosX(i);
        local chunkZ = packet_MapChunks:GetChunkPosZ(i);
        self.worldClient:DoPreChunk(chunkX, chunkZ, true);
        self.worldClient:InvalidateBlockReceiveRegion(chunkX*16, 0, chunkZ*16, (chunkX*16) + 15, 256, (chunkZ*16) + 15);
        local chunk = self.worldClient:GetChunkFromChunkCoords(chunkX, chunkZ);
		
		if (chunk) then
			chunk:FillChunk(packet_MapChunks:GetCompressedChunkData(i), packet_MapChunks.chunkExistFlag[i], true);
			-- mark re render the blocks. 
			chunk:ResetRelightChecks();
        end
    end
end

function NetClientHandler:handleKickDisconnect(packet_KickDisconnect)
	
end

function NetClientHandler:handleUpdateEntitySign(packet_UpdateEntitySign)
	local blockEntity = EntityManager.GetBlockEntity(packet_UpdateEntitySign.x, packet_UpdateEntitySign.y, packet_UpdateEntitySign.z)
	if(blockEntity) then
		blockEntity:OnUpdateFromPacket(packet_UpdateEntitySign);
	end
end


function NetClientHandler:handleMobSpawn(packet_MobSpawn)
	-- TODO:	
end

function NetClientHandler:handleMovableSpawn(packet_EntityMovableSpawn)
	local x = packet_EntityMovableSpawn.x / 32;
    local y = packet_EntityMovableSpawn.y / 32;
    local z = packet_EntityMovableSpawn.z / 32;
   
	local spawnedEntity;
    local entity_type = packet_EntityMovableSpawn.type;
	if(entity_type == 10) then
		spawnedEntity = EntityManager.EntityRailcar:Create({x=x,y=y,z=z, item_id = block_types.names["railcar"]});
	else
		-- TODO: add other types
	end

	if(spawnedEntity) then
		spawnedEntity.serverPosX = packet_EntityMovableSpawn.x;
        spawnedEntity.serverPosY = packet_EntityMovableSpawn.y;
        spawnedEntity.serverPosZ = packet_EntityMovableSpawn.z;
		spawnedEntity.rotationYaw = packet_EntityMovableSpawn.yaw * 360 / 256.0;
        spawnedEntity.rotationPitch = packet_EntityMovableSpawn.pitch * 360 / 256.0;
		spawnedEntity.entityId = packet_EntityMovableSpawn.entityId;
		
		spawnedEntity:SetPositionAndRotation2(x, y, z, spawnedEntity.rotationYaw, spawnedEntity.rotationPitch);

		-- add to world
		spawnedEntity:Attach();
	end
end

function NetClientHandler:handleAttachEntity(packet_AttachEntity)
	local fromEntity = self:GetEntityByID(packet_AttachEntity.entityId);
	local toEntity = self:GetEntityByID(packet_AttachEntity.vehicleEntityId);
	if(fromEntity) then
		fromEntity:MountEntity(toEntity);
	end
end


