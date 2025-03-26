# Dynamic NFC Route Protection

This project built with canisters on the ICP (Internet Computer Protocol) implements a system for protecting web routes using the NFC tags NTAG 424 DNA. 
Afer canister deployment it allows to dynamically protects specific web pages URLs by requiring NTAG 424 DNA tag authentication.

## Overview

The system consists of:

- A Motoko canister that act at the same time as a backend service that validates NFC authentication and serves web content. 
- Python scripts to program NFC cards and configure protected routes on the deployed canisters
- Simple web pages to demonstrate the concept
- reader script with node to test the system locally

## Prerequisites

- **DFINITY SDK (dfx)** - [Installation Guide]https://internetcomputer.org/docs/building-apps/getting-started/install
- **Python 3+** with the required packages:
  - `pycrypto`
  - `ctypes`

- **Rust Toolchain & icx-asset**
  If Rust is not installed, install it using [rustup](https://rustup.rs/):
  
  ```sh
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source $HOME/.cargo/env  # Ensure Rust is in the path
  ```
  
  Then, install `icx-asset`:
  
  ```sh
  cargo install icx-asset
  ```

- **A D-Logic NFC card reader/writer** 
Only works with D-Logic uFR and uFR ZERO series: [Available here]https://www.d-logic.com/
with the appropriate drivers :
[D-Logic code repository]https://code.d-logic.com/-/snippets/1

- **One NTAG 424 DNA NFC tag for each protected URL**

## Setup

1. **Clone this repo**

   ```sh
   git clone git@github.com:Inuani/dynamic_route_nfc_protection.git dynamic-nfc-route-protec
   cd dynamic-nfc-route-protec
   ```

2. **Set up your Python environment**

   ```sh
   python3 -m venv venv
   source venv/bin/activate
   pip3 install pycrypto ctypes
   ```

3. **Deploy the Motoko Canister and upload the assets locally**

Before you begin, update the Makefile to use your identity:
- locate the `upload_assets` target
- Change the path from `~/.config/dfx/identity/raygen/identity.pem` to your identity's pem file path [more doc here]https://internetcomputer.org/docs/building-apps/getting-started/identities

Then deploy with:

```sh
# Start the local IC replica
dfx start --background

# Deploy the canister
make

# Upload frontend assets
make upload_assets
```

5. **Program NFC Cards**

Connect the D-Logic NFC reader/writer to your computer.
Place an empty NTAG 424 NFC tag on the device.
Choose one of the following commands:

```sh
# Protect page1.html with default key
make protect_route_example

# Protect page1.html with a randomly generated key (more secure)
make random_key

# For deploying to the IC mainnet instead of local replica
make production_ic
```

## Understanding Route Proection Creation

```sh
python scripts/setup_route.py <canister_id> <page_path> [--random-key] [--params "key=value"] [--ic]
```
Arguments:

<canister_id> (required): The unique identifier for your deployed canister (e.g., "br5f7-7uaaa-aaaaa-qaaca-cai")

<page_path> (required): The web page you want to protect (e.g., "page1.html")

Optional Flags:

--random-key: Generates a unique cryptographic key for the NFC tag instead of using the default zero key. Recommended for production use to increase security.

--params "key=value": Adds custom query parameters to the protected URL. These parameters will be included in the URL when the NFC tag is read.

--ic: Configures the tag for the Internet Computer mainnet instead of a local replica. Use this flag when deploying to production on the IC network.

## Usage

- Tap the NFC card to access a protected route with a NFC reader such as a smartphone. 
- The system will validate the dynamic URL signature.
- If authentication succeeds, access is granted to the protected URL.

## Security Considerations

- URLs are dynamically generated and expire after one-time use.
- The Motoko backend verifies NFC authentication.
- Ensure that only trusted devices can program NFC cards.

## License

This project is licensed under the MIT License.
