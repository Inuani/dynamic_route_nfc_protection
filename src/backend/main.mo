import Server "mo:server";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Assets "mo:assets";
import T "mo:assets/Types";
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Routes "routes";
import Blob "mo:base/Blob";

shared ({ caller = creator }) actor class () = this {

  

  stable let routesState = Routes.init();
  let routes_storage = Routes.RoutesStorage(routesState);

  public shared ({ caller }) func add_protected_route(path : Text) : async () {
    assert (caller == creator);
    ignore routes_storage.addProtectedRoute(path);
  };

  public shared ({ caller }) func update_route_cmacs(path : Text, new_cmacs : [Text]) : async () {
    assert (caller == creator);
    ignore routes_storage.updateRouteCmacs(path, new_cmacs);
  };

  public shared ({ caller }) func append_route_cmacs(path : Text, new_cmacs : [Text]) : async () {
    assert (caller == creator);
    ignore routes_storage.appendRouteCmacs(path, new_cmacs);
  };

  public query func get_route_protection(path : Text) : async ?Routes.ProtectedRoute {
    routes_storage.getRoute(path);
  };

  public query func get_route_cmacs(path : Text) : async [Text] {
    routes_storage.getRouteCmacs(path);
  };

  public query ({ caller }) func whoAmI() : async Principal {
    return caller;
  };

  public query func get_cycle_balance() : async Nat {
    return Cycles.balance();
  };

  // SERVER CODE
  type Request = Server.Request;
  type Response = Server.Response;
  type HttpRequest = Server.HttpRequest;
  type HttpResponse = Server.HttpResponse;
  type ResponseClass = Server.ResponseClass;

  stable var serializedEntries : Server.SerializedEntries = ([], [], [creator]);
  var server = Server.Server({ serializedEntries });
  let assets = server.assets;

  public shared ({ caller }) func store(
    arg : {
      key : Assets.Key;
      content_type : Text;
      content_encoding : Text;
      content : Blob;
      sha256 : ?Blob;
    }
  ) : async () {
    server.store({ caller; arg });
  };

  public query func http_request(req : HttpRequest) : async HttpResponse {

    let request = {
      url = switch (Text.endsWith(req.url, #text "/")) {
        case true {
          let trimmedSlash = Text.trimEnd(req.url, #text "/");
          let trimmedDot = Text.trimEnd(trimmedSlash, #text ".");
          if (Text.contains(trimmedDot, #text ".")) {
            trimmedDot;
          } else {
            trimmedDot # ".html";
          };
        };
        case false {
          if (Text.contains(req.url, #text ".")) {
            req.url;
          } else {
            req.url # ".html";
          };
        };
      };
      method = req.method;
      body = req.body;
      headers = req.headers;
    };

    if (routes_storage.isProtectedRoute(request.url)) {
      return {
        status_code = 426;
        headers = [];
        body = Blob.fromArray([]);
        streaming_strategy = null;
        upgrade = ?true;
      };
    };

    server.http_request(request);

  };

  public func http_request_update(req : HttpRequest) : async HttpResponse {
    let request = {
      url = switch (Text.endsWith(req.url, #text "/")) {
        case true {
          let trimmedSlash = Text.trimEnd(req.url, #text "/");
          let trimmedDot = Text.trimEnd(trimmedSlash, #text ".");
          if (Text.contains(trimmedDot, #text ".")) {
            trimmedDot;
          } else {
            trimmedDot # ".html";
          };
        };
        case false {
          if (Text.contains(req.url, #text ".")) {
            req.url;
          } else {
            req.url # ".html";
          };
        };
      };
      method = req.method;
      body = req.body;
      headers = req.headers;
    };

    // Check each protected route
    let routes_array = routes_storage.listProtectedRoutes();
    for ((path, protection) in routes_array.vals()) {
      if (Text.contains(request.url, #text path)) {
        let hasAccess = routes_storage.verifyRouteAccess(path, req.url);
        let new_request = {
          url = if (hasAccess) {
            "/" # path;
          } else {
            "/edge.html";
          };
          method = request.method;
          body = request.body;
          headers = request.headers;
        };
        return await server.http_request_update(new_request);
      };
    };

    await server.http_request_update(req);
  };

  public func invalidate_cache() : async () {
    server.empty_cache();
  };

  system func preupgrade() {
    serializedEntries := server.entries();

  };

  system func postupgrade() {
    ignore server.cache.pruneAll();

  };

  public query func list(arg : {}) : async [T.AssetDetails] {
    assets.list(arg);
  };

  public query func get(
    arg : {
      key : T.Key;
      accept_encodings : [Text];
    }
  ) : async ({
    content : Blob;
    content_type : Text;
    content_encoding : Text;
    total_length : Nat;
    sha256 : ?Blob;
  }) {
    assets.get(arg);
  };

  public shared ({ caller }) func create_batch(arg : {}) : async ({
    batch_id : T.BatchId;
  }) {
    assets.create_batch({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func create_chunk(
    arg : {
      batch_id : T.BatchId;
      content : Blob;
    }
  ) : async ({
    chunk_id : T.ChunkId;
  }) {
    assets.create_chunk({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func commit_batch(args : T.CommitBatchArguments) : async () {
    assets.commit_batch({
      caller;
      args;
    });
  };

  public shared ({ caller }) func create_asset(arg : T.CreateAssetArguments) : async () {
    assets.create_asset({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func set_asset_content(arg : T.SetAssetContentArguments) : async () {
    assets.set_asset_content({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func unset_asset_content(args : T.UnsetAssetContentArguments) : async () {
    assets.unset_asset_content({
      caller;
      args;
    });
  };

  public shared ({ caller }) func delete_asset(args : T.DeleteAssetArguments) : async () {
    assets.delete_asset({
      caller;
      args;
    });
  };

  public shared ({ caller }) func clear(args : T.ClearArguments) : async () {
    assets.clear({
      caller;
      args;
    });
  };

  public type StreamingCallbackToken = {
    key : Text;
    content_encoding : Text;
    index : Nat;
    sha256 : ?Blob;
  };

  public type StreamingCallbackHttpResponse = {
    body : Blob;
    token : ?StreamingCallbackToken;
  };

  public query func http_request_streaming_callback(token : T.StreamingCallbackToken) : async StreamingCallbackHttpResponse {
    assets.http_request_streaming_callback(token);
  };

};
