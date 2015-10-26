#require "Onewire.class.nut:1.0.0"

// frequency of getting temperature measurements
TEMPERATURE_FREQUENCY <- 5.0;

// frequency of device discovery
DISCOVER_FREQUENCY <- 15.0;


class OneWireStub
{
    
    _wire = null;
    
    constructor ( uart ) {
        // if ( uart == null ) return null;
        _wire = Onewire( uart );
    }
    
    function uuid( device ) {
        return format("%02x%02x.%02x%02x.%02x%02x.%02x%02x",
                        device[0],device[1],device[2],device[3],device[4],device[5],device[6],device[7])
    }

    function discover( ) {

        // discover devices
        server.log("Scanning 1-wire bus..." );
        local success = _wire.init();
        if (success) {
            local numDevs = _wire.getDeviceCount();
            server.log( format(" discovered %d devices", numDevs) );
            if ( numDevs < 1 ) {
                success = false;
            } else {
                for (local i = 0 ; i < numDevs ; i++) {
                    local device = _wire.getDevice(i);
                    local id = uuid( device );
                    server.log(" found " + id);
                }
            }
        }
    
        

        if (! success) {
            server.log("Error: no 1-_wire devices found");
        }
    
        return success;

    }

}

class DS18B20 extends OneWireStub
{
    
    // conversion time
    static DS18B20_CONVERSION_TIME = 0.75;
    
    function getTemp() {

        // Reset the 1-Wire bus
        local result = _wire.reset();
        if (result) {
                
            // Issue 1-Wire Skip ROM command (0xCC) to select all devices on the bus
            _wire.skipRom()
  
            // Issue DS18B20 Convert command (0x44) to tell all DS18B20s to get the temperature
            _wire.writeByte(0x44);
    
            // Wait 750ms for the temperature conversion to finish
            imp.sleep( DS18B20_CONVERSION_TIME );

            // poll each sensor to get the results
            local numDevs = _wire.getDeviceCount();
            for (local i = 0 ; i < numDevs ; i++) {
            
                local device = _wire.getDevice(i);
                local uuid = uuid( device )
            
                // Run through the list of discovered slave devices, getting the temperature
                // if a given device is of the correct family number: 0x28 for BS18B20
                if (device[7] == 0x28) {
    
                    // Issue 1-Wire MATCH ROM command (0x55) to select device by ID
                    _wire.reset();
                    _wire.writeByte(0x55);
    
                    // Write out the 64-bit ID from the array's eight bytes
                    for (local i = 7 ; i >= 0 ; i--) {
                        _wire.writeByte(device[i]);
                    }
        
                    // Issue the DS18B20's READ SCRATCHPAD command (0xBE) to get temperature
                    _wire.writeByte(0xBE);
        
                    // Read the temperature value from the sensor's RAM
                    local tempLSB = _wire.readByte();
                    local tempMSB = _wire.readByte();
        
                    // Signal that we don't need any more data by resetting the bus
                    _wire.reset();

                    // Calculate the temperature from LSB and MSB
                    local tempCelsius = ((tempMSB * 256) + tempLSB) / 16.0;
                    
                    // if value is 4095.94, then assume not present
                    
                    if ( tempCelsius > 125.0 ) {
                        tempCelsius = null;
                    }
                    
                    if ( tempCelsius == null ) {
                        server.log( format("device %2d: %s (%02x)\t temp: -", i, uuid, device[7]) );
                    } else {
                        server.log( format("device %2d: %s (%02x)\t temp: %3.2f", i, uuid, device[7], tempCelsius) );
                    }
                
                } // if hex is ds18s20

            } // for each device
        
        } // 1 _wire okay

    }
    
} //class

function discover() {
    imp.wakeup( DISCOVER_FREQUENCY, discover );
    foreach( k,this_string in STRING_O_SENSORS ) {
        this_string.discover()
    }
}

function getTemp(){
    imp.wakeup( TEMPERATURE_FREQUENCY, getTemp );
    foreach( k,this_string in STRING_O_SENSORS ) {
        this_string.getTemp()
    }
}

// initiate
STRING_O_SENSORS <- {
    uart12 = DS18B20( hardware.uart12 )
    uart57 = DS18B20( hardware.uart57 )
}

// start loops
discover();
getTemp();

