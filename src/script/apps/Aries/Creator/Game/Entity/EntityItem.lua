--[[
Title: EntityItem
Author(s): LiXizhi
Date: 2013/12/25
Desc: entity for an ItemStack in the world.
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityItem.lua");
local ItemStack = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
local EntityItem = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityItem")
local entity = EntityItem:new():Init(19995.1,-128,20004,ItemStack:new():Init(62,1))
entity:Attach();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemClient.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/Direction.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityBlockBase.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Effects/Image3DDisplay.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemClient.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemStack.lua");
local ItemStack = commonlib.gettable("MyCompany.Aries.Game.Items.ItemStack");
local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
local Image3DDisplay = commonlib.gettable("MyCompany.Aries.Game.Effects.Image3DDisplay");
local Direction = commonlib.gettable("MyCompany.Aries.Game.Common.Direction")
local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
local PhysicsWorld = commonlib.gettable("MyCompany.Aries.Game.PhysicsWorld");
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");

local Entity = commonlib.inherit(commonlib.gettable("MyCompany.Aries.Game.EntityManager.Entity"), commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityItem"));

-- class name
Entity.class_name = "EntityItem";
EntityManager.RegisterEntityClass(Entity.class_name, Entity);
Entity.is_persistent = true;
-- always serialize to 512*512 regional entity file
Entity.is_regional = true;
Entity.text_offset = {x=0,y=0.3,z=0};
Entity.obj_rotate_speed = 1.2;
Entity.anim_speed_vertical = 0.3;
-- amplitude vertically
Entity.anim_amp_vertical = 0.2;
Entity.framemove_interval = 0.03;
-- number of seconds before can pick
Entity.delayBeforeCanPickup = nil;
-- only stay for 3 minutes by default. 
-- Entity.lifetime = 1000*60*3; 
Entity.offset_y = BlockEngine.half_blocksize - Entity.anim_amp_vertical;

function Entity:ctor()
	self.tick = 0;
end

function Entity:Init(x,y,z,itemStack, lifetime )
	self.x,self.y, self.z = x,y,z;
	self.bx, self.by, self.bz = BlockEngine:block(x,y+0.1,z);
	self.lifetime = lifetime;
	self:SetItemStack(itemStack);
	return self:init();
end

function Entity:LoadFromXMLNode(node)
	Entity._super.LoadFromXMLNode(self, node);

	for _, subnode in ipairs(node) do 
		if(subnode.name == "itemstack") then
			self:SetItemStack(ItemStack:new():LoadFromXMLNode(subnode));
		end
	end
end

function Entity:SaveToXMLNode(node)
	node = Entity._super.SaveToXMLNode(self, node);

	node[#node+1] = self:GetItemStack():SaveToXMLNode({name="itemstack"});
	return node;
end

-- @param Entity: the half radius of the object. 
function Entity:init()
	if(not Entity._super.init(self)) then
		return
	end
	self.x, self.y, self.z = self:GetPosition();
	self:CreateInnerObject(self.x, self.y, self.z);
	self:UpdateBlockContainer();
	return self;
end

local offsets_map = {
	["model/blockworld/BlockModel/block_model_one.x"] = 0;
	["model/blockworld/BlockModel/block_model_four.x"] = 0;
	["model/blockworld/BlockModel/block_model_cross.x"] = 0;
	["model/blockworld/BlockModel/block_model_slab.x"] = 0;
	["model/blockworld/BlockModel/block_model_plate.x"] = 0;
	["model/blockworld/IconModel/IconModel_16x16.x"] = nil;
	[""] = 0;
}

-- create the raw 3d model ParaObject and return it. 
-- @param x,y,z: is real world position. 
function Entity:CreateInnerObject(x,y,z,facing, scaling)
	local item = self:GetItemStack():GetItem();
	if(item) then
		local model_filename = item:GetItemModel();	
		local bUseIcon;
		if(not model_filename or model_filename == "icon") then
			model_filename = "model/blockworld/IconModel/IconModel_32x32.x";
			scaling = scaling or 1;
			bUseIcon = true;
		end
		if(model_filename) then
			self.offset_y = offsets_map[model_filename];
		end

		local obj = ObjEditor.CreateObjectByParams({
			name = "",
			IsCharacter = false,
			AssetFile = model_filename or "",
			x = x or self.x,
			y = (y or self.y) + self.offset_y,
			z = z or self.z,
			scaling = scaling or 0.3, 
			facing = facing or self.facing,
			IsPersistent = false,
			EnablePhysics = false,
		});
		-- MESH_USE_LIGHT = 0x1<<7: use block ambient and diffuse lighting for this model. 
		obj:SetAttribute(128, true);
		-- OBJ_SKIP_PICKING = 0x1<<15:
		obj:SetAttribute(0x8000, true);
		obj:SetField("progress", 1);
		-- obj:SetField("persistent", false); 
		-- obj:SetScale(BlockEngine.blocksize);
		obj:SetField("RenderDistance", 160);

		if(model_filename and model_filename~="") then
			if(bUseIcon) then
				local tex = item:GetIconObject();
				if(tex) then
					obj:SetReplaceableTexture(2, tex);
				end
				obj:SetField("FaceCullingDisabled", true);
			else
				local block = item:GetBlock();
				if(block) then
					local tex = block:GetTextureObj();
					if(tex) then
						obj:SetReplaceableTexture(2, tex);
					end
				end
			end
		else
			-- display using GUI.
			local icon_path = item:GetIcon();
			Image3DDisplay.ShowHeadonDisplay(true, obj, icon_path or "", 30, 30, nil, self.text_offset, -1.57);
		end
		
		ParaScene.Attach(obj);	
		self:SetInnerObject(obj);
		return obj;
	end
end

-- returned the represented itemstack 
function Entity:GetItemStack()
	local item = self:GetDataContainer():GetField("ItemStack");
    if (item) then
		return item;
	else
        LOG.log(nil, "warn", "EntityItem", "does not have an item inside");
        local item = ItemStack:new():Init(block_types.names.Dirt);
		SetItemStack(item);
		return item;
    end
end

function Entity:SetItemStack(itemStack)
	self:GetDataContainer():SetField("ItemStack", itemStack);
end


function Entity:Destroy()
	self:DestroyInnerObject();
	Entity._super.Destroy(self);
end

function Entity:Refresh()
	
end


-- Adds to the current velocity of the entity. 
-- @param x,y,z: velocity in x,y,z direction. 
function Entity:AddVelocity(x,y,z)
	Entity._super.AddVelocity(self, x,y,z);
	self.delayBeforeCanPickup = 3;
end


-- when the body of the player hit this entity. 
function Entity:OnCollideWithPlayer(entity, bx,by,bz)
	local item = self:GetItemStack();
    local count = item.count;

    if (not self.delayBeforeCanPickup and entity.inventory:AddItemToInventory(item)) then
        self:PlaySound();
        entity:OnItemPickup(self, count);

        if (item.count <= 0) then
            self:SetDead();
        end
    end
end

function Entity:FrameMove(deltaTime)
	self.tick = self.tick + 1;
	if(self.tick%30 == 0) then
		-- only frame move physics once per second(30 ticks). 
		Entity._super.FrameMove(self, 1);
	end

	if(self.delayBeforeCanPickup) then
		self.delayBeforeCanPickup = self.delayBeforeCanPickup - deltaTime;
		if(self.delayBeforeCanPickup<=0) then
			self.delayBeforeCanPickup = nil;
		end
	end

	self:MoveEntity(deltaTime);

	local obj = self:GetInnerObject();
	if(obj) then
		if(self.obj_rotate_speed) then
			obj:SetFacing(obj:GetFacing() + deltaTime * self.obj_rotate_speed);
		end
		if(self.anim_speed_vertical and not self:HasSpeed()) then
			local x, y, z = obj:GetPosition();
			local dy = y - (self.y+self.offset_y+self.anim_amp_vertical);
			if(self.anim_up) then
				dy = dy + deltaTime * self.anim_speed_vertical * math.max(0.3, 1-math.abs(dy)/self.anim_amp_vertical);
				if(dy > self.anim_amp_vertical) then
					dy = self.anim_amp_vertical;
					self.anim_up = false;
				end
			else
				dy = dy - deltaTime * self.anim_speed_vertical * math.max(0.3, 1-math.abs(dy)/self.anim_amp_vertical);
				if(dy < -self.anim_amp_vertical) then
					dy = -self.anim_amp_vertical;
					self.anim_up = true;
				end
			end
			obj:SetPosition(self.x, self.y+dy+self.offset_y+self.anim_amp_vertical, self.z);
		else
			obj:SetPosition(self.x, self.y+self.offset_y, self.z);
		end
	end
end