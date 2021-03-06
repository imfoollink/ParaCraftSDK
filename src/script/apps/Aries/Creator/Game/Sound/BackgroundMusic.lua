--[[
Title: BackgroundMusic
Author(s): LiXizhi
Date: 2014/1/9
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Sound/BackgroundMusic.lua");
local BackgroundMusic = commonlib.gettable("MyCompany.Aries.Game.Sound.BackgroundMusic");
BackgroundMusic:Play(filename)
-------------------------------------------------------
]]
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")

local BackgroundMusic = commonlib.gettable("MyCompany.Aries.Game.Sound.BackgroundMusic");

local last_audio_src;

local default_music_map = {
	["1"] = "Audio/Haqi/AriesRegionBGMusics/ambForest.ogg",
	["2"] = "Audio/Haqi/AriesRegionBGMusics/Area_SunnyBeach.ogg",
	["3"] = "Audio/Haqi/AriesRegionBGMusics/ambIceSeaSide.ogg",
	["4"] = "Audio/Haqi/AriesRegionBGMusics/ambSnowMountain.ogg",
	["5"] = "Audio/Haqi/AriesRegionBGMusics/ambDesert.ogg",
	["6"] = "Audio/Haqi/AriesRegionBGMusics/AmbLava.ogg",
	["7"] = "Audio/Haqi/AriesRegionBGMusics/ambDarkForestSea.ogg",
	["8"] = "Audio/Haqi/AriesRegionBGMusics/ambPhoenixIsland.ogg",
	["9"] = "Audio/Haqi/AriesRegionBGMusics/ambDarkPlain.ogg",
	["10"] = "Audio/Haqi/AriesRegionBGMusics/ambDarkforest.ogg",
}

-- @param filename: sound name or a table array of sound names. 
function BackgroundMusic:Init()
end

-- return true if we have just played a midi file
function BackgroundMusic:CheckPlayMidiFile(filename)
	if(filename and filename:match("%.mid$")) then
		self:Stop();
		ParaAudio.PlayWaveFile(filename);
		return true;
	end
end

function BackgroundMusic:PlayMidiNote(note)
	ParaAudio.PlayMidiMsg(note);
end

-- get audio source from file name. 
function BackgroundMusic:GetMusic(filename)
	if(not filename) then
		return;
	end
	filename = default_music_map[filename] or filename;

	local audio_src = AudioEngine.Get(filename);
	if(not audio_src) then
		if(not ParaIO.DoesAssetFileExist(filename, true)) then
			filename = ParaWorld.GetWorldDirectory()..filename;
			if(not ParaIO.DoesAssetFileExist(filename, true)) then
				return;
			end
		end
		-- just in case it is midi file 
		if(self:CheckPlayMidiFile(filename)) then
			return;
		end
		
		audio_src = AudioEngine.CreateGet(filename);
		audio_src.loop = true;
		audio_src.file = filename;
	end
	
	return audio_src;
end

-- @param filename: file name or known audio key name. The filepath can be relative to current world directory or root directory. 
-- @return: audio source object or nil
function BackgroundMusic:Play(filename, bToggleIfSame)
	local audio_src = BackgroundMusic:GetMusic(filename)
	if(audio_src) then
		self:PlayBackgroundSound(audio_src, bToggleIfSame);
		return audio_src;
	end
end

-- set the current background music. but do not call play. 
function BackgroundMusic:SetMusic(audio_src, bToggleIfSame)
	if(audio_src) then
		if(last_audio_src ~= audio_src) then
			if(last_audio_src) then
				last_audio_src:stop();
			end
			last_audio_src = audio_src;
		elseif(bToggleIfSame) then
			self:Stop();
		end
	end
end

-- replace old bg music with the new one. 
function BackgroundMusic:PlayBackgroundSound(audio_src, bToggleIfSame)
	if(audio_src) then
		if(last_audio_src ~= audio_src) then
			if(last_audio_src) then
				last_audio_src:stop();
			end
			last_audio_src = audio_src;
			-- TODO: shall we fade in and fade out?
			audio_src:play2d(); -- then play with default. 
		elseif(bToggleIfSame) then
			self:Stop();
		end
	end
end

function BackgroundMusic:Stop()
	-- stop currently playing music
	if(last_audio_src) then
		last_audio_src:stop();
		last_audio_src = nil;
	end
end

-- return the audio source object. 
function BackgroundMusic:GetCurrentMusic()
	return last_audio_src;
end


function BackgroundMusic:ToggleMusic(filename)
	self:Play(filename, true)
end

