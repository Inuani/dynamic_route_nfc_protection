# Dynamic NFC Route Protection

This project implements a system for protecting web routes using NFC cards with NTAG 424 DNA technology, 
creating dynamically secured URLs that can only be accessed with a programmed NFC tag.

## Overview

The system consists of:

- A Motoko canister that act as a backend service and serves web content and validates NFC authentication
- Python scripts to program NFC cards and configure protected routes
- Frontend pages to demonstrate the concept

## Prerequisites

- **DFINITY Canister SDK (dfx)**
- **Python 3.6+** with the required packages:
  - `pycrypto`
  - `ctypes`
- **An NFC card reader** 
Only works with D-Logic uFR and uFR ZERO series: https://www.d-logic.com/
with the appropriate drivers :
https://code.d-logic.com/-/snippets/1

- **NTAG 424 DNA NFC tags**

## Setup and Installation

1. **Clone the repository**

   ```sh
   git clone <repository_url>
   cd dynamic-nfc-protection
   ```

2. **Set up your Python environment**

   ```sh
   python -m venv venv
   source venv/bin/activate  # On Windows use `venv\Scripts\activate`
   pip install pycrypto ctypes
   ```

3. **Deploy the Motoko Canister**

   ```sh
   dfx start --background
   dfx deploy
   ```

5. **Program NFC Cards**

   Use the provided Python script to encode your NTAG 424 DNA cards with secure URLs.

   ```sh
   python program_nfc.py
   ```

## Usage

- Tap the NFC card to access a protected route with the d-logic 
- The system will validate the dynamic URL signature.
- If authentication succeeds, access is granted to the protected content.

## Security Considerations

- URLs are dynamically generated and expire after one-time use.
- The Motoko backend verifies NFC authentication against a stored key.
- Ensure that only trusted devices can program NFC cards.

## License

This project is licensed under the MIT License.
