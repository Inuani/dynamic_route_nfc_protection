import Server "mo:server";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Assets "mo:assets";
import T "mo:assets/Types";
import Cycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Scan "scan";

import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Iter "mo:base/Iter";

shared ({ caller = creator }) actor class () = this {
  type Request = Server.Request;
  type Response = Server.Response;
  type HttpRequest = Server.HttpRequest;
  type HttpResponse = Server.HttpResponse;
  type ResponseClass = Server.ResponseClass;

  stable var serializedEntries : Server.SerializedEntries = ([], [], [creator]);

  type ProtectedRoute = {
    path : Text;
    cmacs_ : [Text];
    scan_count_ : Nat;
  };

  stable var protected_routes : [(Text, ProtectedRoute)] = [];
  var routes = HashMap.fromIter<Text, ProtectedRoute>(protected_routes.vals(), 0, Text.equal, Text.hash);

  public shared ({ caller }) func add_protected_route(path : Text) : async () {
    assert (caller == creator);
    if (Option.isNull(routes.get(path))) {
      let new_route : ProtectedRoute = {
        path;
        cmacs_ = [];
        scan_count_ = 0;
      };
      routes.put(path, new_route);
    };
  };

  public shared ({ caller }) func update_route_cmacs(path : Text, new_cmacs : [Text]) : async () {
    assert (caller == creator);
    switch (routes.get(path)) {
      case (?existing) {
        routes.put(
          path,
          {
            path = existing.path;
            cmacs_ = new_cmacs;
            scan_count_ = existing.scan_count_;
          },
        );
      };
      case null {};
    };
  };

  public shared ({ caller }) func append_route_cmacs(path : Text, new_cmacs : [Text]) : async () {
    assert (caller == creator);
    switch (routes.get(path)) {
      case (?existing) {
        routes.put(
          path,
          {
            path = existing.path;
            cmacs_ = Array.append(existing.cmacs_, new_cmacs);
            scan_count_ = existing.scan_count_;
          },
        );
      };
      case null {};
    };
  };

  public query func get_route_protection(path : Text) : async ?ProtectedRoute {
    routes.get(path);
  };

  public query func get_route_cmacs(path : Text) : async [Text] {
    switch (routes.get(path)) {
      case (?route) {
        route.cmacs_;
      };
      case null { [] };
    };
  };

  var server = Server.Server({ serializedEntries });

  public query ({ caller }) func whoAmI() : async Principal {
    return caller;
  };

  public query func get_cycle_balance() : async Nat {
    return Cycles.balance();
  };

  server.get(
    "/404",
    func(_ : Request, res : ResponseClass) : async Response {
      res.send({
        status_code = 404;
        headers = [("Content-Type", "text/plain")];
        body = Text.encodeUtf8("Not found");
        streaming_strategy = null;
        cache_strategy = #noCache;
      });
    },
  );

  let assets = server.assets;

  public query func listAuthorized() : async [Principal] {
    server.entries().2;
  };

  public shared ({ caller }) func deauthorize(other : Principal) : async () {
    assert (caller == creator);
    let (urls, patterns, authorized) = server.entries();
    let filtered = Array.filter<Principal>(
      authorized,
      func(p) { p != other },
    );
    serializedEntries := (urls, patterns, filtered);
    server := Server.Server({ serializedEntries });
  };

  public shared ({ caller }) func authorize(other : Principal) : async () {
    server.authorize({ caller; other });
  };

  public query func retrieve(path : Assets.Path) : async Assets.Contents {
    assets.retrieve(path);
  };

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

  stable var cmacs : [Text] = [];

  public shared ({ caller }) func update_cmacs(new_cmacs : [Text]) : async () {
    assert (caller == creator);
    cmacs := new_cmacs;
  };

  public shared ({ caller }) func append_cmacs(new_cmacs : [Text]) : async () {
    assert (caller == creator);
    cmacs := Array.append(cmacs, new_cmacs);
  };

  public query func get_cmacs() : async [Text] {
    cmacs;
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

    // if (Text.contains(request.url, #text "admin.html")) {
    //     return {
    //         status_code = 426;
    //         headers = [];
    //         body = Blob.fromArray([]);
    //         streaming_strategy = null;
    //         upgrade = ?true;
    //     }
    // };

    if (
      Array.find<(Text, ProtectedRoute)>(
        Iter.toArray(routes.entries()),
        func((path, _)) : Bool {
          Text.contains(request.url, #text path);
        },
      ) != null
    ) {
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
    for ((path, protection) in routes.entries()) {
      if (Text.contains(request.url, #text path)) {
        let counter = Scan.scan(protection.cmacs_, req.url, protection.scan_count_);

        let new_request = {
          url = if (counter > 0) {
            switch (routes.get(path)) {
              case (?existing) {
                routes.put(
                  path,
                  {
                    path = existing.path;
                    cmacs_ = existing.cmacs_;
                    scan_count_ = counter;
                  },
                );
              };
              case null {};
            };
            "/" # path;
          } else {
            "/edge.html";
          };
          method = request.method;
          body = request.body;
          headers = request.headers;
        };
        Debug.print(new_request.url);
        return await server.http_request_update(new_request);
      };
    };

    await server.http_request_update(req);
  };

  // public func http_request_update(req : HttpRequest) : async HttpResponse {

  // let request = {
  //         url = switch (Text.endsWith(req.url, #text "/")) {
  //             case true {
  //                 let trimmedSlash = Text.trimEnd(req.url, #text "/");
  //                 let trimmedDot = Text.trimEnd(trimmedSlash, #text ".");
  //                 if (Text.contains(trimmedDot, #text ".")) {
  //                   trimmedDot
  //                 } else {
  //                   trimmedDot # ".html"
  //                 }
  //             };
  //             case false {
  //                 if (Text.contains(req.url, #text ".")) {
  //                     req.url
  //                 } else {
  //                     req.url # ".html"
  //                 }
  //             };
  //         };
  //         method = req.method;
  //         body = req.body;
  //         headers = req.headers;
  //     };

  //     if (Text.contains(request.url, #text "admin.html")) {
  //       let counter = Scan.scan(cmacs, req.url, scan_count);
  //         let new_request = {
  //             url = if (counter > 0) {
  //                 scan_count := counter;
  //                 "/admin.html"
  //             } else {
  //                 "/edge.html"
  //             };
  //             method = request.method;
  //             body = request.body;
  //             headers = request.headers;
  //         };
  //         return await server.http_request_update(new_request);
  //     };
  //     await server.http_request_update(req);
  // };

  public func invalidate_cache() : async () {
    server.empty_cache();
  };

  system func preupgrade() {
    serializedEntries := server.entries();

    protected_routes := Iter.toArray(routes.entries());
    // entries := Iter.toArray(storedFiles.entries());
  };

  system func postupgrade() {
    ignore server.cache.pruneAll();

    protected_routes := [];
    // entries := [];
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

  //     server.get(
  //   "/balance",
  //   func(_ : Request, res : ResponseClass) : async Response {
  //     let balance = Nat.toText(Cycles.balance());
  //     res.send({
  //       status_code = 200;
  //       headers = [("Content-Type", "text/plain")];
  //       body = Text.encodeUtf8(balance);
  //       streaming_strategy = null;
  //       cache_strategy = #noCache;
  //     });
  //   },
  // );

  // server.get(
  //   "/json",
  //   func(_ : Request, res : ResponseClass) : async Response {
  //     res.json({
  //       status_code = 200;
  //       body = "{\"hello\":\"world\"}";
  //       cache_strategy = #noCache;
  //     });
  //   },
  // );

  //   public func removeDuplicates() : async () {
  //  // Use a buffer to store unique principals
  //  let seen = Buffer.Buffer<Principal>(0);

  //  for (p in server.authorized.vals()) {
  //    // Only add if not already seen
  //    if (Option.isNull(Array.find(Buffer.toArray(seen), func(x: Principal) : Bool { x == p }))) {
  //      seen.add(p);
  //    };
  //  };

  //  // Update authorized with deduplicated array
  //  server.authorized := Buffer.toArray(seen);

  //  // Recreate server with new authorized list
  //  let (urls, patterns, _) = server.entries();
  //  serializedEntries := (urls, patterns, server.authorized);
  //  server := Server.Server({ serializedEntries });
  // };

};
