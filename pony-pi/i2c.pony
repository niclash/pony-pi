use "files"

primitive I2COk
primitive I2COpenError
primitive I2CNotOpenError
primitive I2CWriteError
primitive I2CReadError
primitive I2CUnknownError

type I2CResult is (I2COk | I2COpenError | I2CNotOpenError | I2CWriteError | I2CReadError | I2CUnknownError)

interface val I2CCallback[A]
  fun apply(value:A, result:I2CResult)

trait tag I2CBus
  be open(callback:(I2CCallback[None]))
  be close()

  be read_byte(device:U8, callback:(I2CCallback[U8]) )
  be read_bytes(device:U8, expected:USize, callback:(I2CCallback[Array[U8] val]) )

  be write_byte(device:U8,data:U8, callback:I2CCallback[None])
  be write_bytes(device:U8,buffer:Array[U8] val, offset:USize, size:USize, callback:I2CCallback[I32])

  be write_read_bytes(device:U8,writeBuffer:Array[U8] val,writeOffset:USize,writeSize:USize,expected:USize,callback:(I2CCallback[Array[U8] val]) )

  be ioctl(command:I64, value:I32)


actor I2CBusPhys is I2CBus
  var _fd:I32 = -1
  var _filename:String
  var _opened:Bool = false
  var _last_address:U8 = 255

  new create(filename':String) =>
    _filename = filename'

  be open(callback:I2CCallback[None]) =>
    if _fd == -1 then
      var flags: I32 = @ponyint_o_rdwr[I32]()
      _fd = @open[I32](_filename.cstring(), flags)
      if _fd < 0 then
        I2COpenError
      else
        _last_address = 255
        callback(None, I2COk)
      end
    else
      callback(None, I2COpenError)
    end

  be close() =>
    if _fd != -1 then
      @close[I32](_fd)
    end

  be read_byte(device:U8, callback:I2CCallback[U8] ) =>
    let result = _read_bytes( device, 1)
    match result
    | let bytes:Array[U8] val =>
      try
        callback(bytes(0)?, I2COk)
      else
        callback(bytes.size().u8(), I2CUnknownError )
      end
    | let err:I2CResult =>
      callback(0, err)
    end

  be read_bytes(device:U8, expected:USize, callback:I2CCallback[Array[U8] val]) =>
    let result = _read_bytes( device, 1)
    match result
    | let b:Array[U8] val =>
      let bytes:Array[U8] val = recover val
        let arr:Array[U8] = []
        arr.copy_from(b,0,0,b.size())
        arr
      end
      callback(bytes, I2COk)
    | let err:I2CResult => callback([], err)
    end

  fun ref _read_bytes(device:U8, expected:USize) : (Array[U8] val|I2CResult) =>
    if _fd == -1 then
      I2CNotOpenError
    end
    _select(device)
    let buffer: Array[U8] = [device]
    let write_result = @write[ISize]( _fd, buffer.cpointer(), I32(1) )
    if( write_result != 1 ) then
      return I2CWriteError
    end
    recover val
      let read_result:Array[U8] = Array[U8](expected)
      let bytes_read = @read[I32](_fd, read_result.cpointer(), expected)
      if bytes_read != expected.i32() then
        return I2CReadError
      end
      let result = Array[U8](expected)
      result.copy_from(read_result,0,0,expected)
      result
    end
    
  be write_byte(device:U8, data:U8, callback:I2CCallback[None]) =>
    let result = _write_bytes( device, [data], 0, 1 )
    callback(None, result._2)

  be write_bytes(device:U8, data:Array[U8] val, offset:USize, size:USize, callback:I2CCallback[I32]) =>
    let result = _write_bytes( device, data, offset, size )
    callback(result._1, result._2)

  fun ref _write_bytes(device:U8, data:Array[U8] val, offset:USize, size:USize) : (I32,I2CResult) =>
    if _fd == -1 then
      return (0, I2CNotOpenError)
    end
    _select(device)
    let buffer = Array[U8](size + 1)
    buffer.push(device)
    buffer.copy_from(data,offset,1,size)
    let bytes_written = @write[ISize]( _fd, buffer.cpointer(), buffer.size() )
    if bytes_written != buffer.size().isize() then
      (bytes_written.i32(), I2CWriteError )
    end
    (bytes_written.i32(), I2COk )

  be write_read_bytes(device:U8,writeBuffer:Array[U8] val,writeOffset:USize,writeSize:USize,expected:USize,callback:(I2CCallback[Array[U8] val]) ) => None

  be ioctl(command:I64, value:I32) => None
    if _fd != -1 then
      @ioctl[I32](_fd, command, value)
    end

  fun ref _select(device:U8) =>
    if _last_address != device then
      _last_address = device
      @ioctl[I32](_fd,I2CSLAVE(),device and 0x7f)
    end

actor I2CBusEmulator is I2CBus
  be open(callback:(I2CCallback[None])) => None
  be close() => None
  be read_byte(device:U8, callback:(I2CCallback[U8]) ) => None
  be read_bytes(device:U8, expected:USize, callback:(I2CCallback[Array[U8] val]) ) => None
  be write_byte(device:U8,data:U8, callback:I2CCallback[None]) => None
  be write_bytes(device:U8,buffer:Array[U8] val, offset:USize, size:USize, callback:I2CCallback[I32]) => None
  be write_read_bytes(device:U8,writeBuffer:Array[U8] val,writeOffset:USize,writeSize:USize,expected:USize,callback:(I2CCallback[Array[U8] val]) ) => None
  be ioctl(command:I64, value:I32) => None

primitive I2C
  fun bus( bus_number:U8, auth:AmbientAuth ):I2CBus =>
    try
      let sysfs = FilePath(auth, "/sys/bus/i2c/devices/i2c-" + bus_number.string())?
      let i2cbus:I2CBus = ifdef "wiringpi" then
        if sysfs.exists() then
          let filename = "/dev/i2c-" + bus_number.string()
          let devfs = FilePath(auth, filename)?
          if not devfs.exists() then
            error
          end
          I2CBusPhys(filename)
        else
          I2CBusEmulator
        end
      else
        I2CBusEmulator
      end
      i2cbus.open({(n,s) => None})
      i2cbus
    else
      I2CBusEmulator
    end

class val I2CDevice
  let _address:U8
  let _bus:I2CBus

  new val create(address':U8, bus':I2CBus ) =>
    _address = address'
    _bus = bus'

  fun write_byte( data:U8 ) =>
  """
   This method writes one byte directly to i2c device.
  """
    _bus.write_byte(_address, data, {(n,v) => None })


  fun write_bytes(buffer: Array[U8] val, offset:USize, size:USize) =>
  """
  This method writes several bytes directly to the i2c device from given buffer at given offset.
  """
    _bus.write_bytes(_address, buffer, offset, size, {(n,v) => None})


  fun write(buffer:Array[U8] val) =>
  """
  This method writes all bytes included in the given buffer directly to the i2c device.
  """
    write_bytes(buffer, 0, buffer.size())


  fun read_byte( callback:I2CCallback[U8] ) =>
  """
  This method reads one byte from the i2c device.
  Result is between 0 and 255 if read operation was successful, else a negative number for an error.
  """
    _bus.read_byte(_address, callback )

  fun read_bytes( expected:USize, callback:I2CCallback[Array[U8] val] ) =>
  """
  This method reads bytes directly from the i2c device to given buffer at asked offset.
  Returns number of bytes read.
  """
    _bus.read_bytes(_address, expected, callback)

  fun val ioctl(command:I64, value:I32) =>
  """
  Runs an ioctl on this device.
  """
    _bus.ioctl(command, value)

  fun val write_read( write_buffer:Array[U8] val, write_offset:USize, write_size:USize,
                      expected_read:USize, callback:I2CCallback[Array[U8] val]) =>
  """
  This method writes and reads bytes to/from the i2c device in a single method call
  """
    _bus.write_read_bytes( _address, write_buffer, write_offset, write_size, expected_read, callback )


// ioctl commands
primitive I2CRetries
  fun apply(): U16 =>  0x0701

primitive I2CTIMEOUT
  fun apply(): U16 => 0x0702

primitive I2CSLAVE
  fun apply(): U16 => 0x0703

primitive I2CSLAVEFORCE
  fun apply(): U16 => 0x0706

primitive I2CTENBIT
  fun apply(): U16 => 0x0704

primitive I2CFUNCS
  fun apply(): U16 => 0x0705

primitive I2CRDWR
  fun apply(): U16 => 0x0707

primitive I2CPEC
  fun apply(): U16 => 0x0708

primitive I2CSMBUS
  fun apply(): U16 => 0x0720

