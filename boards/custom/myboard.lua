-- Fileboards/custom/stm32f4discovery .lua
local t =dofile( "boards/known/stm32f4discovery.lua" )
t.components.wofs=true
t.components.stm32f4_rtc=true
return t
