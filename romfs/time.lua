function showtime()
	local date_t
	local uartid = uart.CDC

	stm32f4.rtc.set(1471406400)

	while uart.getchar( uartid, 0 ) == "" do
		print("Now Unix time : "..stm32f4.rtc.gettime())
		date_t = stm32f4.rtc.getdate()
		print(string.format("Now data : %d-%d-%d %d:%d:%d",date_t.year,date_t.month,date_t.day,date_t.hour,date_t.min,date_t.sec))
		tmr.delay( 0, 1000000 )
	end
end

showtime()
