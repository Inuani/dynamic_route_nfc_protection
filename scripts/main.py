#!/usr/bin/env python3
"""
NFC Tools Main Script
A unified entry point for NFC tag programming and route management tools.
"""
import argparse
import sys
import os
import json
import subprocess

# Import our modules
from lib import nfc_utils
from lib import cmac

def get_canister_name_from_dfx():
    """Read dfx.json and get the primary canister name."""
    try:
        with open('dfx.json', 'r') as f:
            dfx_config = json.load(f)
            for canister_name in dfx_config.get('canisters', {}):
                if canister_name != 'internet_identity':
                    return canister_name
        return None
    except Exception as e:
        print(f"Error reading dfx.json: {str(e)}")
        return None

def run_command(command):
    """Run a shell command and return its exit code, stdout, and stderr."""
    process = subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate()
    return process.returncode, stdout, stderr

def cmd_program_card(args):
    """Handle the 'program' command to program an NFC card."""
    # Import here to avoid loading uFR library unless needed
    import ntag424_programmer
    
    # Construct the URI from canister or use provided URI
    if args.canister_id:
        if not args.page:
            print("Error: --page is required when using --canister-id")
            return False
            
        uri = f"http://{args.canister_id}.localhost:4943/{args.page}"
    else:
        if not args.uri:
            print("Error: either --canister-id and --page, or --uri must be provided")
            return False
        uri = args.uri
    
    # Program the card
    success, uid = ntag424_programmer.program_card(
        uri, 
        args.param_name, 
        args.param_value, 
        args.random_key
    )
    
    # If successful and route protection is requested, set up the route
    if success and args.protect_route:
        if not args.canister_id or not args.page:
            print("Error: --canister-id and --page are required for route protection")
            return False
            
        return setup_protected_route(args.canister_id, args.page, uid)
    
    return success

def cmd_generate_cmacs(args):
    """Handle the 'cmacs' command to generate CMACs."""
    if not args.uid:
        print("Error: --uid is required")
        return False
    
    # Generate CMACs
    hashes = cmac.generate_cmac_hashes(1, args.count+1, args.uid, args.key)
    
    # Save to file
    cmac.save_cmacs_to_file(hashes, args.output)
    
    return True

def cmd_upload_cmacs(args):
    """Handle the 'upload' command to upload CMACs to a canister."""
    # Import batch_cmacs functionality
    import batch_cmacs
    
    if not args.file or not args.canister_name or not args.page:
        print("Error: --file, --canister-name, and --page are all required")
        return False
    
    return batch_cmacs.upload_cmacs(args.file, args.canister_name, args.page)

def setup_protected_route(canister_id, page, uid):
    """Set up a protected route using a card's UID."""
    print(f"Setting up protected route for {page} using card UID {uid}")
    
    # Step 1: Generate CMACs for the UID
    cmac_file = "cmacs.json"
    hashes = cmac.generate_cmac_hashes(1, 31, uid, "00000000000000000000000000000000")
    cmac.save_cmacs_to_file(hashes, cmac_file)
    
    # Step 2: Add the protected route to the canister
    canister_name = get_canister_name_from_dfx() if canister_id == "auto" else canister_id
    if not canister_name:
        print("Error: Could not determine canister name")
        return False
    
    cmd = f'dfx canister call {canister_name} add_protected_route \'("{page}")\''
    exit_code, stdout, stderr = run_command(cmd)
    if exit_code != 0:
        print(f"Error adding protected route: {stderr}")
        return False
    print("Added protected route successfully")
    
    # Step 3: Upload CMACs to the canister
    import batch_cmacs
    if not batch_cmacs.upload_cmacs(cmac_file, canister_name, page):
        return False
    
    # Step 4: Invalidate cache
    cmd = f'dfx canister call {canister_name} invalidate_cache'
    exit_code, stdout, stderr = run_command(cmd)
    if exit_code != 0:
        print(f"Error invalidating cache: {stderr}")
        return False
    print("Invalidated cache successfully")
    
    return True

def cmd_setup_route(args):
    """Handle the 'setup-route' command to set up a protected route."""
    if not args.canister_id or not args.page:
        print("Error: --canister-id and --page are required")
        return False
        
    if not args.uid:
        print("Error: --uid is required")
        return False
    
    return setup_protected_route(args.canister_id, args.page, args.uid)

def main():
    """Main entry point for the NFC tools."""
    parser = argparse.ArgumentParser(description="NFC Programming and Route Management Tools")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")
    
    # 'program' command
    program_parser = subparsers.add_parser("program", help="Program an NFC card")
    program_parser.add_argument("--canister-id", help="Canister ID for URI construction")
    program_parser.add_argument("--page", help="Page for URI construction")
    program_parser.add_argument("--uri", help="Direct URI to use (alternative to canister-id and page)")
    program_parser.add_argument("--param-name", default="", help="Optional parameter name to add to the URL")
    program_parser.add_argument("--param-value", default="", help="Optional parameter value to add to the URL")
    program_parser.add_argument("--random-key", action="store_true", help="Generate and use a random key")
    program_parser.add_argument("--protect-route", action="store_true", help="Set up route protection after programming")
    
    # 'cmacs' command
    cmacs_parser = subparsers.add_parser("cmacs", help="Generate CMAC hashes")
    cmacs_parser.add_argument("--uid", required=True, help="Card UID")
    cmacs_parser.add_argument("--key", default="00000000000000000000000000000000", help="Master key (default: all zeros)")
    cmacs_parser.add_argument("--count", type=int, default=30, help="Number of CMACs to generate")
    cmacs_parser.add_argument("--output", default="cmacs.json", help="Output JSON file path")
    
    # 'upload' command
    upload_parser = subparsers.add_parser("upload", help="Upload CMACs to a canister")
    upload_parser.add_argument("--file", required=True, help="JSON file containing CMACs")
    upload_parser.add_argument("--canister-name", required=True, help="Canister name to upload to")
    upload_parser.add_argument("--page", required=True, help="Page path for the protected route")
    
    # 'setup-route' command
    route_parser = subparsers.add_parser("setup-route", help="Set up a protected route")
    route_parser.add_argument("--canister-id", required=True, help="Canister ID (or 'auto' for auto-detect)")
    route_parser.add_argument("--page", required=True, help="Page to protect")
    route_parser.add_argument("--uid", required=True, help="Card UID to use for authentication")
    
    args = parser.parse_args()
    
    if args.command == "program":
        success = cmd_program_card(args)
    elif args.command == "cmacs":
        success = cmd_generate_cmacs(args)
    elif args.command == "upload":
        success = cmd_upload_cmacs(args)
    elif args.command == "setup-route":
        success = cmd_setup_route(args)
    else:
        parser.print_help()
        return 0
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())