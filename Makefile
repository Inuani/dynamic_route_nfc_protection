include .env

# Access routes in a local replica
# canisterId.localhost:4943/whatever_route
# http://br5f7-7uaaa-aaaaa-qaaca-cai.localhost:4943

#icx-asset --replica http://127.0.0.1:4943 --pem ~/.config/dfx/identity/raygen/identity.pem upload $(CANISTER_ID_VELCRO_BOOT) /index.html=src/frontend/public/index.html

# npx repomix --ignore ".mops/,.dfx/,.vscode,node_module/,.gitignore,src/frontend/public/bundle.js,src/frontend/public/edge.html,ufr-lib/,cmacs.json"


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
	icx-asset --replica $(REPLICA_URL) --pem ~/.config/dfx/identity/raygen/identity.pem sync $(CANISTER_ID) src/frontend/public
	dfx canister call $(if $(filter https://ic0.app,$(REPLICA_URL)),--ic,) $(CANISTER_NAME) invalidate_cache

setup_route_example:
	python3 scripts/setup_route.py $(CANISTER_ID) page1.html --params "key=value"

debug:
	@echo "Canister name is: $(CANISTER_NAME)"
	@echo "Canister ID variable: CANISTER_ID_$(shell echo $(CANISTER_NAME) | tr '[:lower:]' '[:upper:]')"
