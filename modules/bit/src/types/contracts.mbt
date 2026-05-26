///| Shared contract layer traits and HTTP abstractions.

///|
pub(open) trait FileSystem {
  mkdir_p(Self, String) -> Unit raise GitError
  write_file(Self, String, Bytes) -> Unit raise GitError
  write_string(Self, String, String) -> Unit raise GitError
  remove_file(Self, String) -> Unit raise GitError
  remove_dir(Self, String) -> Unit raise GitError
}

///|
pub(open) trait RepoFileSystem {
  read_file(Self, String) -> Bytes raise GitError
  readdir(Self, String) -> Array[String] raise GitError
  is_dir(Self, String) -> Bool
  is_file(Self, String) -> Bool
}

///|
pub struct HttpResponse {
  code : Int
  headers : Map[String, String]
}

///|
pub fn HttpResponse::new(code : Int) -> HttpResponse {
  { code, headers: {} }
}

///|
pub fn HttpResponse::with_headers(
  code : Int,
  headers : Map[String, String],
) -> HttpResponse {
  { code, headers }
}

///|
pub(open) trait HttpClient {
  get(Self, String, Map[String, String]) -> (HttpResponse, Bytes) raise GitError
  post(Self, String, Bytes, Map[String, String]) -> (HttpResponse, Bytes) raise GitError
}

///|
pub struct MockHttpClient {
  responses : Map[String, (Int, Bytes)]
}

///|
pub fn MockHttpClient::new() -> MockHttpClient {
  { responses: {} }
}

///|
pub fn MockHttpClient::add_response(
  self : MockHttpClient,
  url : String,
  code : Int,
  body : Bytes,
) -> Unit {
  self.responses[url] = (code, body)
}

///|
pub impl HttpClient for MockHttpClient with get(self, url, _headers) {
  match self.responses.get(url) {
    Some((code, body)) => (HttpResponse::new(code), body)
    None => raise GitError::IoError("Mock: No response for URL: " + url)
  }
}

///|
pub impl HttpClient for MockHttpClient with post(self, url, _body, _headers) {
  match self.responses.get(url) {
    Some((code, body)) => (HttpResponse::new(code), body)
    None => raise GitError::IoError("Mock: No response for URL: " + url)
  }
}
