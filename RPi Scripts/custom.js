var util = require('util');
var bleno = require('./index');
var BlenoPrimaryService = bleno.PrimaryService;
var BlenoCharacteristic = bleno.Characteristic;
var BlenoDescriptor = bleno.Descriptor;
var credentials = []
var details = {}
var initializePromise = getSSIDandIPPromise();
initializePromise.then(result => {
  details = result
  console.log("Callback : ", details)
}).catch(error => {
  console.log(error)
})

console.log('bleno');



function hexToString(str)
{
    const buf = new Buffer(str, 'hex');
    return buf.toString('utf8');
}

function execute(){
    console.log("SSID:"+credentials[0])
    console.log("PSK:"+credentials[1])
    if (credentials[0].length = 0 || credentials[1].length <8){
      console.log("SSID or Password Error! Not long enough")
      return
    }
    var command = 'wpa_passphrase '+"\""+credentials[0]+"\" "+"\""+credentials[1]+"\""+'| sudo tee -a '+ "/etc/wpa_supplicant/wpa_supplicant.conf" +' > /dev/null'
    console.log(command)
    const { exec } = require("child_process");
    //let cmd = "sudo python3 /home/pi/Documents/Projects/Python_BT/BT_Wifi_Handler.py "+credentials[0]+","+credentials[1]
    exec(command, (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
          return;
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
          return;
      }
      console.log(`stdout: ${stdout}`);
    });
    credentials = []
    setTimeout(function() {
    command = "sudo wpa_cli -i wlan0 reconfigure"
    exec(command, (error, stdout, stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
          return;
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
          return;
      }
      console.log(`stdout: ${stdout}`);
    });
    },500)
    
    setTimeout(function() {
      initializePromise = getSSIDandIPPromise();
      initializePromise.then(result => {
        details = result
        console.log("Callback : ", details)
        let cmd2 = "sudo systemctl restart cloudbasedtesting"
        exec(cmd2, (error, stdout, stderr) => {
        if (error) {
            console.log(`error: ${error.message}`);
            return;
        }
        if (stderr) {
            console.log(`stderr: ${stderr}`);
            return;
        }
        console.log(`stdout: ${stdout}`);
      })
      
    }).catch( error => {
      console.log(error);
    });
      
    },4000)
}

function getSSIDandIPPromise(){ 
    return new Promise (function (resolve, reject) {
    
    var details = {}
    let cmd = "iwgetid -r"
    const { exec } = require("child_process");
    exec(cmd, (error,stdout,stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
          reject(error);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
          reject(stderr);
      }
      let SSID = stdout
      SSID = SSID.replace(/(\r\n|\n|\r)/gm, "");
      details['SSID'] = SSID
      console.log(`SSID: ${SSID}`);
      console.log(details)
      console.log(details.SSID)
      console.log(details.IP)
      resolve(details)
    });
    
    
    let cmd2 = "hostname -I | awk '{print $1}'"
    exec(cmd2, (error,stdout,stderr) => {
      if (error) {
          console.log(`error: ${error.message}`);
          reject(error);
      }
      if (stderr) {
          console.log(`stderr: ${stderr}`);
          reject(stderr);
      }
      let IP = stdout
      IP = IP.replace(/(\r\n|\n|\r)/gm, "");
      details['IP'] = IP      
      console.log(`stdout: ${IP}`);
      console.log(details)
    });
    
  });
};

var WriteOnlyCharacteristic = function() {
  WriteOnlyCharacteristic.super_.call(this, {
    uuid: 'fffffffffffffffffffffffffffffff4',
    properties: ['write', 'writeWithoutResponse']
  });
};

util.inherits(WriteOnlyCharacteristic, BlenoCharacteristic);

WriteOnlyCharacteristic.prototype.onWriteRequest = function(data, offset, withoutResponse, callback) {
  console.log('WriteOnlyCharacteristic write request: ' + data.toString('hex') + ' ' + offset + ' ' + withoutResponse);
  readable = hexToString(data.toString('hex'));
  console.log('Readable '+readable);
  credentials.push(readable);
  console.log('Credentials :'+credentials);
  if(credentials.length == 2){
    execute()
  }
  callback(this.RESULT_SUCCESS);
};

var DynamicReadOnlyCharacteristic = function() {
  DynamicReadOnlyCharacteristic.super_.call(this, {
    uuid: 'fffffffffffffffffffffffffffffff2',
    properties: ['read']
  });
};

util.inherits(DynamicReadOnlyCharacteristic, BlenoCharacteristic);

DynamicReadOnlyCharacteristic.prototype.onReadRequest = function(offset, callback) {
  var result = this.RESULT_SUCCESS;
  console.log(details)
  var data = new Buffer(details.SSID+","+details.IP);

  if (offset > data.length) {
    result = this.RESULT_INVALID_OFFSET;
    data = null;
  } else {
    data = data.slice(offset);
  }

  callback(result, data);
};

function SampleService() {
  SampleService.super_.call(this, {
    uuid: 'fffffffffffffffffffffffffffffff0',
    characteristics: [
      new WriteOnlyCharacteristic(),
      new DynamicReadOnlyCharacteristic()
    ]
  });
}


util.inherits(SampleService, BlenoPrimaryService);

bleno.on('stateChange', function(state) {
  console.log('on -> stateChange: ' + state + ', address = ' + bleno.address);

  if (state === 'poweredOn') {
    bleno.startAdvertising('test', ['fffffffffffffffffffffffffffffff0']);
  } else {
    bleno.stopAdvertising();
  }
});

// Linux only events /////////////////
bleno.on('accept', function(clientAddress) {
  console.log('on -> accept, client: ' + clientAddress);

  bleno.updateRssi();
});

bleno.on('disconnect', function(clientAddress) {
  console.log('on -> disconnect, client: ' + clientAddress);
  const { exec } = require("child_process");
  let cmd = "sleep 5 && sudo systemctl restart BTWifi"
  //exec(cmd, (error, stdout, stderr) => {
      //if (error) {
          //console.log(`error: ${error.message}`);
          //return;
      //}
      //if (stderr) {
          //console.log(`stderr: ${stderr}`);
          //return;
      //}
      //console.log('restarting service');
      //console.log(`stdout: ${stdout}`);
  //});
  setTimeout((function() {
    
    return process.exit(22);
  }), 100);
    
 
});

bleno.on('rssiUpdate', function(rssi) {
  console.log('on -> rssiUpdate: ' + rssi);
});
//////////////////////////////////////

bleno.on('mtuChange', function(mtu) {
  console.log('on -> mtuChange: ' + mtu);
});

bleno.on('advertisingStart', function(error) {
  console.log('on -> advertisingStart: ' + (error ? 'error ' + error : 'success'));

  if (!error) {
    bleno.setServices([
      new SampleService()
    ]);
  }
});

bleno.on('advertisingStop', function() {
  console.log('on -> advertisingStop');
});

bleno.on('servicesSet', function(error) {
  console.log('on -> servicesSet: ' + (error ? 'error ' + error : 'success'));
});
