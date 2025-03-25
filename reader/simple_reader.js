const ffi = require('ffi-napi');
const ref = require('ref-napi');
const { exec } = require('child_process');

// Path to uFCoder library 
var dllPath = "./libuFCoder-x86_64.so"

// Define the functions we need from the library
var uFCoder = ffi.Library(dllPath, {
  "ReaderOpen": ['int', []],
  "ReaderClose": ['int', []],
  "GetDlogicCardType": ['byte', ['byte*']],
  "nt4h_set_global_parameters": ['int', ['byte', 'byte', 'byte']],
  "LinearRead": ['int', ['byte*', 'ushort', 'ushort', 'ushort*', 'byte', 'byte']],
  "UFR_Status2String": ['string', ['int']],
});

// Authentication constants
const T4T_AUTHENTICATION = {
  T4T_WITHOUT_PWD_AUTH: 0x60
};

// Function to open URL in browser based on platform
function openURL(url) {
  let command;
  switch (process.platform) {
    case 'darwin':  // macOS
      command = `open "${url}"`;
      break;
    case 'win32':   // Windows
      command = `start "${url}"`;
      break;
    default:        // Linux and others
      command = `xdg-open "${url}"`;
      break;
  }

  exec(command, (error) => {
    if (error) {
      console.error('Error opening browser:', error);
    }
  });
}

// Main function to read SDM data and open browser
async function readSDMDataAndOpenBrowser() {
  // Open reader
  let status = uFCoder.ReaderOpen();
  if (status !== 0) {
    console.log("Failed to open reader:", uFCoder.UFR_Status2String(status));
    return;
  }
  console.log("Reader opened successfully");

  try {
    // Set global parameters for NDEF file
    const file_no = 2;  // NDEF file number
    const key_no = 0x0E; // NDEF read key
    const comm_mode = 0; // Plain communication mode

    status = uFCoder.nt4h_set_global_parameters(file_no, key_no, comm_mode);
    if (status !== 0) {
      console.log("Failed to set parameters:", uFCoder.UFR_Status2String(status));
      return;
    }

    // Read NDEF data
    const read_data = Buffer.alloc(200); // Buffer for data
    const bytes_ret = ref.alloc('int', 0);
    
    status = uFCoder.LinearRead(
      read_data,
      0, // linear address
      200, // length to read
      bytes_ret,
      T4T_AUTHENTICATION.T4T_WITHOUT_PWD_AUTH,
      0 // reader key index
    );

    if (status !== 0) {
      console.log("Failed to read data:", uFCoder.UFR_Status2String(status));
      return;
    }

    // Parse NDEF message
    const ndef_length = read_data[4];
    const ndef_data = read_data.slice(7, 7 + ndef_length - 1);
    const url = ndef_data.toString('utf-8');

    console.log("Opening URL:", url);
    
    // Open the URL in the default browser
    openURL(url);

  } finally {
    // Close reader
    uFCoder.ReaderClose();
    console.log("Reader closed");
  }
}

// Run the function
readSDMDataAndOpenBrowser().catch(console.error);