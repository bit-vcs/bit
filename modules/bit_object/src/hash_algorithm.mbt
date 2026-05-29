///| Hash algorithm enum for SHA-1 / SHA-256 dual support

///|
pub(all) enum HashAlgorithm {
  Sha1
  Sha256
} derive(Eq)

///|
pub fn HashAlgorithm::hash_size(self : HashAlgorithm) -> Int {
  match self {
    Sha1 => 20
    Sha256 => 32
  }
}

///|
pub fn HashAlgorithm::hex_size(self : HashAlgorithm) -> Int {
  match self {
    Sha1 => 40
    Sha256 => 64
  }
}

///|
pub fn HashAlgorithm::zero_hex(self : HashAlgorithm) -> String {
  match self {
    Sha1 => "0000000000000000000000000000000000000000"
    Sha256 => "0000000000000000000000000000000000000000000000000000000000000000"
  }
}

///|
pub fn HashAlgorithm::name(self : HashAlgorithm) -> String {
  match self {
    Sha1 => "sha1"
    Sha256 => "sha256"
  }
}

///|
pub fn HashAlgorithm::from_string(s : String) -> HashAlgorithm raise GitError {
  match s.to_lower() {
    "sha1" | "sha-1" => Sha1
    "sha256" | "sha-256" => Sha256
    _ => raise GitError::InvalidObject("Unknown hash algorithm: \{s}")
  }
}

///|
pub impl Show for HashAlgorithm with output(self, logger) {
  logger.write_string(self.name())
}
