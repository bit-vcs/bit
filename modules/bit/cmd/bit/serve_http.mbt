///|
/// `bit serve --http`: a real HTTP listener for the Git smart protocol.
///
/// Distinct from `bit relay serve`, which tunnels requests through a relay and
/// rewrites incoming refs into `refs/relay/incoming/*`. This serves
/// repositories directly, so a push lands on the ref the client named.
///
/// Phase 0 of `docs/scalable-git-server.md`: local disk, many repositories,
/// no object store yet. Every later phase is tested against this listener.

///|
struct HttpServeOptions {
  host : String
  port : Int
  /// Directory holding the repositories this server exposes.
  root : String
  allow_push : Bool
  /// Shared bearer token. `None` serves anonymously, which is only
  /// appropriate on a loopback address or behind an authenticating proxy.
  token : String?
}

///|
fn print_http_serve_usage() -> Unit {
  println("Usage: bit serve --http [--port <n>] [--host <addr>] [--root <dir>]")
  println("")
  println("Serve repositories under <dir> over the Git smart HTTP protocol.")
  println("")
  println("Options:")
  println("  --http           Run an HTTP listener (rather than relay serve)")
  println("  --port <n>       Port to listen on (default 8420)")
  println("  --host <addr>    Address to bind (default 127.0.0.1)")
  println("  --root <dir>     Directory containing repositories (default .)")
  println("  --allow-push     Accept pushes (receive-pack)")
  println("  --token <tok>    Require 'Authorization: Bearer <tok>'")
  println("  -h, --help       Show this help")
  println("")
  println("Repositories are addressed by path under <dir>, so a repository at")
  println("<dir>/acme/app.git is cloned from http://<host>:<port>/acme/app.git")
}

///|
fn parse_http_serve_options(args : Array[String]) -> HttpServeOptions? {
  let mut host = "127.0.0.1"
  let mut port = 8420
  let mut root = "."
  let mut allow_push = false
  let mut token : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      print_http_serve_usage()
      return None
    } else if arg == "--http" {
      i += 1
    } else if arg == "--allow-push" {
      allow_push = true
      i += 1
    } else if arg == "--port" && i + 1 < args.length() {
      port = @string.parse_int(args[i + 1]) catch {
        _ => {
          println("bit serve: invalid port: \{args[i + 1]}")
          return None
        }
      }
      i += 2
    } else if arg == "--host" && i + 1 < args.length() {
      host = args[i + 1]
      i += 2
    } else if arg == "--root" && i + 1 < args.length() {
      root = args[i + 1]
      i += 2
    } else if arg == "--token" && i + 1 < args.length() {
      token = Some(args[i + 1])
      i += 2
    } else {
      i += 1
    }
  }
  Some({ host, port, root, allow_push, token })
}

///|
/// Split a request target into its repository path and the service endpoint.
///
/// A repository path may contain slashes (`acme/app.git`), so the split is
/// driven by the endpoint suffix rather than by counting path segments.
fn http_split_route(target : String) -> (String, String, String)? {
  let (path, query) = match target.find("?") {
    Some(i) => (
      String::unsafe_substring(target, start=0, end=i),
      String::unsafe_substring(target, start=i + 1, end=target.length()),
    )
    None => (target, "")
  }
  for endpoint in ["/info/refs", "/git-upload-pack", "/git-receive-pack"] {
    if path.has_suffix(endpoint) {
      let repo = String::unsafe_substring(
        path,
        start=0,
        end=path.length() - endpoint.length(),
      )
      return Some((repo, endpoint, query))
    }
  }
  None
}

///|
/// Resolve a repository path from the URL to a directory under the root.
///
/// Rejects anything that could climb out of the root: the path arrives from
/// an unauthenticated client, so a traversal here would expose the whole
/// filesystem.
fn http_resolve_repo(root : String, repo_path : String) -> String? {
  let trimmed = if repo_path.has_prefix("/") {
    String::unsafe_substring(repo_path, start=1, end=repo_path.length())
  } else {
    repo_path
  }
  if trimmed.length() == 0 {
    return None
  }
  if trimmed.contains("..") || trimmed.contains("//") || trimmed.has_prefix("/") {
    return None
  }
  // A backslash is a separator on some hosts; refuse rather than guess.
  if trimmed.contains("\\") {
    return None
  }
  let base = if root.has_suffix("/") {
    String::unsafe_substring(root, start=0, end=root.length() - 1)
  } else {
    root
  }
  Some(normalize_repo_root("\{base}/\{trimmed}"))
}

///|
fn http_query_param(query : String, name : String) -> String? {
  let prefix = name + "="
  for part in query.split("&") {
    let piece = part.to_owned()
    if piece.has_prefix(prefix) {
      return Some(
        String::unsafe_substring(piece, start=prefix.length(), end=piece.length()),
      )
    }
  }
  None
}

///|
/// Constant-time-ish bearer check.
///
/// Compares the whole string rather than returning early, so the comparison
/// does not leak the length of the matching prefix through timing.
fn http_token_ok(header : String?, expected : String?) -> Bool {
  match expected {
    None => true
    Some(want) => {
      guard header is Some(value) else { return false }
      guard value.has_prefix("Bearer ") else { return false }
      let got = String::unsafe_substring(value, start=7, end=value.length())
      if got.length() != want.length() {
        return false
      }
      let mut diff = 0
      for i in 0..<want.length() {
        if got[i] != want[i] {
          diff += 1
        }
      }
      diff == 0
    }
  }
}

///|
fn http_header(headers : Map[String, String], name : String) -> String? {
  for key, value in headers {
    if key.to_lower() == name {
      return Some(value)
    }
  }
  None
}

///|
/// A prepared response.
struct HttpServeReply {
  status : Int
  reason : String
  headers : Map[String, String]
  body : Bytes
}

///|
fn http_text_reply(
  status : Int,
  reason : String,
  message : String,
) -> HttpServeReply {
  {
    status,
    reason,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
    body: @encoding.encode(@encoding.Encoding::UTF8, message),
  }
}

///|
/// Build the `# service=` banner that precedes a smart-HTTP advertisement.
fn http_advertisement(service : String, payload : Bytes) -> Bytes {
  serve_concat_bytes([
    @protocol.pktline_encode("# service=\{service}\n"),
    @encoding.encode(@encoding.Encoding::UTF8, "0000"),
    payload,
  ])
}

///|
/// Handle one request. Pure with respect to the network: it takes the request
/// and returns the response, so routing and authorization are testable
/// without binding a socket.
fn http_serve_dispatch(
  options : HttpServeOptions,
  verb : String,
  target : String,
  auth_header : String?,
  protocol_version : Int,
  body : Bytes,
) -> HttpServeReply raise Error {
  guard http_split_route(target) is Some((repo_path, endpoint, query)) else {
    return http_text_reply(404, "Not Found", "not found\n")
  }
  if !http_token_ok(auth_header, options.token) {
    let reply = http_text_reply(401, "Unauthorized", "authentication required\n")
    reply.headers["WWW-Authenticate"] = "Bearer"
    return reply
  }
  guard http_resolve_repo(options.root, repo_path) is Some(root) else {
    return http_text_reply(404, "Not Found", "no such repository\n")
  }
  let fs = OsFs::new()
  // A server usually holds bare repositories, whose refs/ and objects/ sit at
  // the top level; a working copy keeps them under .git. Support both, and
  // treat neither as "no such repository" rather than serving an empty one.
  let git_dir = if fs.is_dir("\{root}/.git") {
    "\{root}/.git"
  } else if fs.is_dir("\{root}/refs") && fs.is_dir("\{root}/objects") {
    root
  } else {
    return http_text_reply(404, "Not Found", "no such repository\n")
  }
  let service = match endpoint {
    "/info/refs" =>
      match http_query_param(query, "service") {
        Some(name) => name
        // A dumb-HTTP client asks for info/refs with no service. This server
        // speaks only the smart protocol, so say so rather than half-answer.
        None =>
          return http_text_reply(
            403, "Forbidden", "dumb HTTP protocol is not supported\n",
          )
      }
    "/git-upload-pack" => "git-upload-pack"
    _ => "git-receive-pack"
  }
  if service == "git-receive-pack" && !options.allow_push {
    return http_text_reply(403, "Forbidden", "push is not enabled\n")
  }
  if endpoint == "/info/refs" {
    if verb != "GET" {
      return http_text_reply(405, "Method Not Allowed", "method not allowed\n")
    }
    // The advertisement must answer in the version the client asked for.
    // Advertising v0 to a client that sent `Git-Protocol: version=2` makes it
    // downgrade, and any client that does not downgrade would then POST a v2
    // body that the v0 parser cannot read.
    let payload = if service == "git-receive-pack" {
      @bitlib.build_receive_pack_advertisement(fs, root, git_dir_override=git_dir)
    } else {
      @bitlib.build_upload_pack_advertisement(
        fs,
        root,
        protocol_version~,
        git_dir_override=git_dir,
      )
    }
    return {
      status: 200,
      reason: "OK",
      headers: {
        "Content-Type": "application/x-\{service}-advertisement",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
      },
      body: http_advertisement(service, payload),
    }
  }
  if verb != "POST" {
    return http_text_reply(405, "Method Not Allowed", "method not allowed\n")
  }
  if endpoint == "/git-receive-pack" {
    let out = @bitlib.receive_pack(fs, fs, root, body, git_dir_override=git_dir)
    return {
      status: 200,
      reason: "OK",
      headers: {
        "Content-Type": "application/x-git-receive-pack-result",
        "Cache-Control": "no-cache",
      },
      body: out,
    }
  }
  let out = if protocol_version == 2 {
    let request = @bitlib.parse_upload_pack_request_v2(body)
    let config = @bitlib.build_upload_pack_config_with_overrides(
      fs, root, Map([]),
    )
    @bitlib.upload_pack_v2(fs, root, request, config, git_dir_override=git_dir)
  } else {
    let request = @bitlib.parse_upload_pack_request(body)
    @bitlib.upload_pack(fs, root, request, git_dir_override=git_dir)
  }
  {
    status: 200,
    reason: "OK",
    headers: {
      "Content-Type": "application/x-git-upload-pack-result",
      "Cache-Control": "no-cache",
    },
    body: out,
  }
}

///|
/// Read a request body to completion.
///
/// A push body is a pack, so this must not stop early: a short read would be
/// handed to `receive_pack` as a truncated pack.
async fn http_read_body(reader : &@io.Reader) -> Bytes raise Error {
  let chunks : Array[Byte] = []
  while true {
    let chunk = reader.read_some()
    match chunk {
      Some(part) =>
        for b in part {
          chunks.push(b)
        }
      None => break
    }
  }
  Bytes::from_array(FixedArray::makei(chunks.length(), i => chunks[i]))
}

///|
/// Run the listener until interrupted.
async fn http_serve_run(options : HttpServeOptions) -> Unit raise Error {
  let addr = @socket.Addr::resolve(options.host, port=options.port)
  let server = @http.Server::Server(addr, reuse_addr=true)
  println("bit serve: listening on http://\{options.host}:\{options.port}")
  println("bit serve: serving repositories under \{options.root}")
  if options.allow_push {
    println("bit serve: push enabled")
  }
  if options.token is None && options.host != "127.0.0.1" &&
    options.host != "localhost" {
    println(
      "bit serve: warning: no --token set while bound to a non-loopback " +
      "address; every client may read" +
      (if options.allow_push { " and write" } else { "" }),
    )
  }
  server.run_forever(
    (request, body, conn) => {
      let verb = match request.meth {
        @http.RequestMethod::Get => "GET"
        @http.RequestMethod::Post => "POST"
        @http.RequestMethod::Head => "HEAD"
        _ => "OTHER"
      }
      let payload = http_read_body(body)
      let auth = http_header(request.headers, "authorization")
      let protocol_version = match http_header(request.headers, "git-protocol") {
        Some(value) => if value.contains("version=2") { 2 } else { 0 }
        None => 0
      }
      // One bad request must not take the listener down with it, so a
      // handler failure becomes a 500 rather than an escaping error.
      let reply = try {
        http_serve_dispatch(
          options, verb, request.path, auth, protocol_version, payload,
        )
      } catch {
        e => {
          println("bit serve: \{verb} \{request.path}: \{e}")
          http_text_reply(500, "Internal Server Error", "internal error\n")
        }
      }
      conn.send_response(reply.status, reply.reason, extra_headers=reply.headers)
      if reply.body.length() > 0 {
        conn.write(reply.body)
      }
      conn.end_response()
    },
    allow_failure=true,
  )
}

///|
/// Entry point for `bit serve --http`.
async fn handle_serve_http(args : Array[String]) -> Unit raise Error {
  guard parse_http_serve_options(args) is Some(options) else { return }
  http_serve_run(options)
}

///|
fn print_serve_usage() -> Unit {
  print_http_serve_usage()
}

///|
/// Dispatch for `bit serve`.
///
/// Only the HTTP listener exists today; the relay tunnel keeps its own
/// `bit relay serve`, because it answers a different question (exposing one
/// local repository) than this does (serving many).
async fn handle_serve(args : Array[String]) -> Unit raise Error {
  if args.length() == 0 {
    print_serve_usage()
    return ()
  }
  let mut wants_http = false
  for arg in args {
    if arg == "--http" {
      wants_http = true
    }
    if arg == "-h" || arg == "--help" {
      print_serve_usage()
      return ()
    }
  }
  if !wants_http {
    eprint_line("bit serve: --http is required (no other transport yet)")
    print_serve_usage()
    @sys.exit(1)
  }
  handle_serve_http(args)
}
