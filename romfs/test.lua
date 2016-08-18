-- eLua blinking led example, the Hello World of embedded :)

  ledpin = pio.PD_13
  uartid = uart.CDC


function cycle()
  if not invert then
    pio.pin.sethigh( ledpin )
  else
    pio.pin.setlow( ledpin )
  end
  tmr.delay( 0, 500000 )
  if not invert then
    pio.pin.setlow( ledpin )
  else
    pio.pin.sethigh( ledpin )
  end
  tmr.delay( 0, 500000 )
end

pio.pin.setdir( pio.OUTPUT, ledpin )

print( "I'm running on platform " .. pd.platform() )
print( "The CPU is a " .. pd.cpu() )
print( "The board name is " .. pd.board() )
print "Watch your LED blinking :)"
print "Enjoy eLua !"
print "Press any key to end this demo.\n"

while uart.getchar( uartid, 0 ) == "" do
  cycle()
end
