@echo off
start '%CD%/../../redist/ParaEngineClient.exe single="false" mc="true" noupdate="true" dev="%CD%" bootstrapper="mods/HelloWorld/main.lua"'