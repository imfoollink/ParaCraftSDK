--[[
Title: manage all chunk generators
Author(s): LiXizhi
Date: 2015.11.17
Desc: this is singleton class
-----------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/World/ChunkGenerators.lua");
local ChunkGenerators = commonlib.gettable("MyCompany.Aries.Game.World.ChunkGenerators");
local gen_class = ChunkGenerators:GetGeneratorClass("flat");

-- one can register a custom generator at any time.
ChunkGenerators:Register(name, class_def);
-----------------------------------------------
]]
local ChunkGenerators = commonlib.gettable("MyCompany.Aries.Game.World.ChunkGenerators");

local generators = {};

function ChunkGenerators:Init()
	if(self.inited) then
		return;
	end
	self.inited = true;

	self:RegisterBuildinGenerators();
end

function ChunkGenerators:RegisterBuildinGenerators()
	NPL.load("(gl)script/apps/Aries/Creator/Game/World/generators/FlatChunkGenerator.lua");
	local FlatChunkGenerator = commonlib.gettable("MyCompany.Aries.Game.World.Generators.FlatChunkGenerator");
	ChunkGenerators:Register("flat", FlatChunkGenerator);
	
	NPL.load("(gl)script/apps/Aries/Creator/Game/World/generators/EmptyChunkGenerator.lua");
	local EmptyChunkGenerator = commonlib.gettable("MyCompany.Aries.Game.World.Generators.EmptyChunkGenerator");
	ChunkGenerators:Register("empty", EmptyChunkGenerator);

	NPL.load("(gl)script/apps/Aries/Creator/Game/World/generators/NatureV1ChunkGenerator.lua");
	local NatureV1ChunkGenerator = commonlib.gettable("MyCompany.Aries.Game.World.Generators.NatureV1ChunkGenerator");
	ChunkGenerators:Register("custom", NatureV1ChunkGenerator);

	-- TODO: add other buildin generators here. plugins can register using self:Register function. 
end

-- @param generator_class: please note this is the class, not class instance. 
function ChunkGenerators:Register(name, generator_class)
	generators[name] = generator_class;
end

-- get generator class by name. if not found, the default flat generator class is returned. 
function ChunkGenerators:GetGeneratorClass(name)
	self:Init();
	return generators[name or "flat"] or generators["flat"];
end


