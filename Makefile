include .env

# repomix --ignore "ufr-lib/"     


REPLICA_URL := $(if $(filter ic,$(subst ',,$(DFX_NETWORK))),https://ic0.app,http://127.0.0.1:4943)
CANISTER_NAME := $(shell grep "CANISTER_ID_" .env | grep -v "INTERNET_IDENTITY\|CANISTER_ID='" | head -1 | sed 's/CANISTER_ID_\([^=]*\)=.*/\1/' | tr '[:upper:]' '[:lower:]')
CANISTER_ID := $(CANISTER_ID_$(shell echo $(CANISTER_NAME) | tr '[:lower:]' '[:upper:]'))

UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
    OPEN_CMD := open
else ifeq ($(UNAME), Linux)
    OPEN_CMD := xdg-open
else
    OPEN_CMD := start
endif

all:
	dfx deploy $(CANISTER_NAME)
	dfx canister call $(CANISTER_NAME) invalidate_cache
	
ic:
	dfx deploy --ic
	dfx canister call --ic $(CANISTER_ID) invalidate_cache

url:
	$(OPEN_CMD) http://$(CANISTER_ID).localhost:4943/

upload_assets:
	icx-asset --replica $(REPLICA_URL) --pem ~/.config/dfx/identity/raygen/identity.pem sync $(CANISTER_ID) src/frontend/
	dfx canister call $(if $(filter https://ic0.app,$(REPLICA_URL)),--ic,) $(CANISTER_NAME) invalidate_cache

protect_route_example:
	python3 scripts/setup_route.py $(CANISTER_ID) page1.html --params "key=value"

random_key:
	python3 scripts/setup_route.py $(CANISTER_ID) page2.html --random-key --params "key=value"

production_ic:
	python3 scripts/setup_route.py $(CANISTER_ID) page1.html --params "key=value" --ic

reinstall:
	dfx canister install $(CANISTER_NAME) --mode=reinstall
