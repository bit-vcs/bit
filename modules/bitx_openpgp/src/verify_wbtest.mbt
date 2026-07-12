///| Whitebox tests for native OpenPGP verification, exercised against a

///|
/// real signature produced by GnuPG (ed25519, detached, ASCII-armored).
test "verify real gpg ed25519 detached signature" {
  let payload : Bytes = Bytes::from_array([
    b'\x74', b'\x72', b'\x65', b'\x65', b'\x20', b'\x34', b'\x62', b'\x38', b'\x32',
    b'\x35', b'\x64', b'\x63', b'\x36', b'\x34', b'\x32', b'\x63', b'\x62', b'\x36',
    b'\x65', b'\x62', b'\x39', b'\x61', b'\x30', b'\x36', b'\x30', b'\x65', b'\x35',
    b'\x34', b'\x62', b'\x66', b'\x38', b'\x64', b'\x36', b'\x39', b'\x32', b'\x38',
    b'\x38', b'\x66', b'\x62', b'\x65', b'\x65', b'\x34', b'\x39', b'\x30', b'\x34',
    b'\x0a', b'\x61', b'\x75', b'\x74', b'\x68', b'\x6f', b'\x72', b'\x20', b'\x41',
    b'\x20', b'\x3c', b'\x61', b'\x40', b'\x65', b'\x3e', b'\x20', b'\x31', b'\x37',
    b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x20',
    b'\x2b', b'\x30', b'\x30', b'\x30', b'\x30', b'\x0a', b'\x63', b'\x6f', b'\x6d',
    b'\x6d', b'\x69', b'\x74', b'\x74', b'\x65', b'\x72', b'\x20', b'\x41', b'\x20',
    b'\x3c', b'\x61', b'\x40', b'\x65', b'\x3e', b'\x20', b'\x31', b'\x37', b'\x30',
    b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x30', b'\x20', b'\x2b',
    b'\x30', b'\x30', b'\x30', b'\x30', b'\x0a', b'\x0a', b'\x68', b'\x65', b'\x6c',
    b'\x6c', b'\x6f', b'\x20', b'\x73', b'\x69', b'\x67', b'\x6e', b'\x65', b'\x64',
    b'\x20', b'\x63', b'\x6f', b'\x6d', b'\x6d', b'\x69', b'\x74', b'\x0a',
  ])
  let sig_armor = "-----BEGIN PGP SIGNATURE-----\n\niHUEABYKAB0WIQRutwAix16c8psOpLi58o1L69KPJQUCaj60XgAKCRC58o1L69KP\nJcDsAQDg8oJOROgli9EdT8tcYgNWlWm36nUVAsZX8rXmJQyEJQD/XwFt5u3wHPBU\nZkvflGecPDTlu48ZE6969WPhQ77gBgg=\n=ESFu\n-----END PGP SIGNATURE-----\n"
  let keyring = "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nmDMEaj60XhYJKwYBBAHaRw8BAQdAyWNeGvursagoOmzp4FmwmkmVTvYZQgHcsb29\nMTIUFHm0HlRlc3QgU2lnbmVyIDx0ZXN0QGV4YW1wbGUuY29tPoiTBBMWCgA7FiEE\nbrcAIsdenPKbDqS4ufKNS+vSjyUFAmo+tF4CGwMFCwkIBwICIgIGFQoJCAsCBBYC\nAwECHgcCF4AACgkQufKNS+vSjyWEAwD/T7d/NUMv6JMD31Ht09mQfWeVLDA2xLJ0\n5pZbQUzeMRsBAJbt+Eu1yCH1qjQG3AEk9Jr8+oXfZ8kSiAyZXxQdywkJ\n=beqv\n-----END PGP PUBLIC KEY BLOCK-----\n"
  let keys = split_armored_public_keys(keyring)
  inspect(keys.length(), content="1")
  let good = verify_detached_armored(payload, sig_armor, keys)
  inspect(good.verified, content="true")
  let bad = Bytes::from_array([b'\x00', b'\x01', b'\x02'])
  let tampered = verify_detached_armored(bad, sig_armor, keys)
  inspect(tampered.verified, content="false")
  let none_keys = verify_detached_armored(payload, sig_armor, [])
  inspect(none_keys.verified, content="false")
}
