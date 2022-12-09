

primitive LOW fun apply():I32 => 0
primitive HIGH fun apply():I32 => 1

primitive INPUT fun apply():I32 => 0
primitive OUTPUT fun apply():I32 => 1
primitive PmwOutput fun apply():I32 => 2
primitive GpioClock fun apply():I32 => 3
primitive SoftPwmOutput fun apply():I32 => 4
primitive SoftToneOutput fun apply():I32 => 5
primitive PwmToneOutput fun apply():I32 => 6

primitive PudOff fun apply():I32 => 0
primitive PudDown fun apply():I32 => 1
primitive PudUp fun apply():I32 => 2


type PinMode is (INPUT | OUTPUT | PmwOutput | GpioClock | SoftPwmOutput | SoftToneOutput | PwmToneOutput)
type PullUpMode is (PudOff | PudDown | PudUp )
type IoState is (HIGH | LOW)

primitive RPi
  """
  Calls down to the WiringPi C library functions, for the basic GPIO operations.

  One of the setup functions must be called at the start of your program or your program will fail to work correctly.
  You may experience symptoms from it simply not working to segfaults and timing issues.

  Note: wiringPi version 1 returned an error code if these functions failed for whatever reason. Version 2 returns
  always returns zero. After discussions and inspection of many programs written by users of wiringPi and observing
  that many people don’t bother checking the return code, I took the stance that should one of the wiringPi setup
  functions fail, then it would be considered a fatal program fault and the program execution will be terminated at
  that point with an error message printed on the terminal.

      If you want to restore the v1 behaviour, then you need to set the environment variable: WIRINGPI_CODES (to any
      value, it just needs to exist)
  """

  fun pinMode(pin:I32, mode:PinMode) =>
    """
    This sets the mode of a pin to either INPUT, OUTPUT, PWM_OUTPUT or GPIO_CLOCK. Note that only wiringPi pin 1
    (BCM_GPIO 18) supports PWM output and only wiringPi pin 7 (BCM_GPIO 4) supports CLOCK output modes.

    This function has no effect when in Sys mode. If you need to change the pin mode, then you can do it with the gpio
    program in a script before you start your program.
    """
    ifdef "wiringpi" then
      @pinMode[None](pin, mode())
    end

  fun pullUpDnControl(pin:I32, mode:PullUpMode) =>
    """
    This sets the pull-up or pull-down resistor mode on the given pin, which should be set as an input. Unlike the Arduino,
    the BCM2835 has both pull-up an down internal resistors. The parameter pud should be; PUD_OFF, (no pull up/down),
    PUD_DOWN (pull to ground) or PUD_UP (pull to 3.3v) The internal pull up/down resistors have a value of approximately
    50KΩ on the Raspberry Pi.

    This function has no effect on the Raspberry Pi’s GPIO pins when in Sys mode. If you need to activate a
    pull-up/pull-down, then you can do it with the gpio program in a script before you start your program.
    """
    ifdef "wiringpi" then
      @pullUpDnControl[None](pin,mode())
    end

  fun digitalWrite(pin:I32, value:IoState) =>
    """
    Writes the value HIGH or LOW (1 or 0) to the given pin which must have been previously set as an output.

    WiringPi treats any non-zero number as HIGH, however 0 is the only representation of LOW.
    """
    ifdef "wiringpi" then
      @digitalWrite[None](pin, value())
    end

  fun pwmWrite(pin:I32, value:I32) =>
    """
    Writes the value to the PWM register for the given pin. The Raspberry Pi has one on-board PWM pin, pin 1 (BMC_GPIO 18,
    Phys 12) and the range is 0-1024. Other PWM devices may have other PWM ranges.

    This function is not able to control the Pi’s on-board PWM when in Sys mode.
    """
    ifdef "wiringpi" then
      @pwmWrite[None](pin,value)
    end

  fun digitalRead(pin:I32): IoState =>
    """
    This function returns the value read at the given pin. It will be HIGH or LOW (1 or 0) depending on the logic level at the pin.
    """
    ifdef "wiringpi" then
      if @digitalRead[I32](pin) == 0 then LOW else HIGH end
    else
      LOW
    end

  fun analogRead( pin:I32 ): I32 =>
    """
    This returns the value read on the supplied analog input pin. You will need to register additional analog modules to
    enable this function for devices such as the Gertboard, quick2Wire analog board, etc.
    """
    ifdef "wiringpi" then
      @analogRead[I32](pin)
    else
      0
    end

  fun analogWrite(pin:I32, value:I32) =>
    """
    This writes the given value to the supplied analog pin. You will need to register additional analog modules to enable
    this function for devices such as the Gertboard.
    """
    ifdef "wiringpi" then
      @analogWrite[None](pin, value )
    end

  fun isr(pin:I32, edge_type:I32, callback:PiIsrCallback) =>
  """
  This function registers a function to received interrupts on the specified pin. The edgeType parameter is either
  INT_EDGE_FALLING, INT_EDGE_RISING, INT_EDGE_BOTH or INT_EDGE_SETUP. If it is INT_EDGE_SETUP then no initialisation
  of the pin will happen – it’s assumed that you have already setup the pin elsewhere (e.g. with the gpio program),
  but if you specify one of the other types, then the pin will be exported and initialised as specified. This is
  accomplished via a suitable call to the gpio utility program, so it need to be available.

   The pin number is supplied in the current mode – native wiringPi, BCM_GPIO, physical or Sys modes.

   This function will work in any mode, and does not need root privileges to work.

   The function will be called when the interrupt triggers. When it is triggered, it’s cleared in the dispatcher before
   calling your function, so if a subsequent interrupt fires before you finish your handler, then it won’t be missed.
   (However it can only track one more interrupt, if more than one interrupt fires while one is being handled then they
   will be ignored)

   This function is run at a high priority (if the program is run using sudo, or as root) and executes concurrently with
   the main program. It has full access to all the global variables, open file handles and so on.
   """
    ifdef "wiringpi" then
      @wiringPiISR[I32](pin, edge_type, callback)
    end

  fun wiringPiSetup(): I32 =>
    """
    This initialises wiringPi and assumes that the calling program is going to be using the wiringPi pin numbering
    scheme. This is a simplified numbering scheme which provides a mapping from virtual pin numbers 0 through 16 to the
    real underlying Broadcom GPIO pin numbers. See the pins page for a table which maps the wiringPi pin number to the
    Broadcom GPIO pin number to the physical location on the edge connector.

    This function needs to be called with root privileges.
    """
    ifdef "wiringpi" then
      @wiringPiSetup[I32]()
    else
      0
    end

  fun wiringPiSetupGpio(): I32 =>
    """
    This is identical to above, however it allows the calling programs to use the Broadcom GPIO pin numbers directly
    with no re-mapping.

    As above, this function needs to be called with root privileges, and note that some pins are different from revision
    1 to revision 2 boards.
    """
    ifdef "wiringpi" then
      @wiringPiSetupGpio[I32]()
    else
      0
    end

  fun wiringPiSetupPhys(): I32 =>
    """
    Identical to above, however it allows the calling programs to use the physical pin numbers on the P1 connector only.

    As above, this function needs to be called with root priviliges.
    """
    ifdef "wiringpi" then
      @wiringPiSetupPhys[I32]()
    else
      0
    end

  fun wiringPiSetupSys(): I32 =>
    """
    This initialises wiringPi but uses the /sys/class/gpio interface rather than accessing the hardware directly. This
    can be called as a non-root user provided the GPIO pins have been exported before-hand using the gpio program. Pin
    numbering in this mode is the native Broadcom GPIO numbers – the same as wiringPiSetupGpio() above, so be aware of
    the differences between Rev 1 and Rev 2 boards.

    Note: In this mode you can only use the pins which have been exported via the /sys/class/gpio interface before you
    run your program. You can do this in a separate shell-script, or by using the system() function from inside your
    program to call the gpio program.

    Also note that some functions have no effect when using this mode as they’re not currently possible to action unless
    called with root privileges. (although you can use system() to call gpio to set/change modes if needed)
    """
    ifdef "wiringpi" then
      @wiringPiSetupSys[I32]()
    else
      0
    end

interface PiIsrCallback
  fun callback(): None