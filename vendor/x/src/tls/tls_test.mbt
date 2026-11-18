///|
#cfg(target="js")
let key_pem =
  #|-----BEGIN PRIVATE KEY-----
  #|MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDGGuA46vHS2I9u
  #|v5/N6yiyarjUGPm1/cxwWBobxB9IFcn8fXu41C5YmKh7cvRrAreiXf1NeXMNm6rC
  #|9M7JH51V9XqPCIDnJB/mZ6qhQjj7YniNWvUcNqpIHg55cbWkMSttPvub7zYJ3Vbk
  #|mah46la1N5OieCiU974YPuHqZ0qbOCEw3/+5kQQZlYuXEKUz/dLlovYluvUusl2p
  #|Oj3qUaeWfMs8slammPx3OzfoercDyETDNmyJvSXMHmtbJYSCBa5AFZZMtAcw8gWH
  #|PRw5hZy+C7GgCC+26tGKiFuReE6ge6feJ/KOYQMv5zkXH4tmM20hauwGWBY7X86Z
  #|anzARiyhAgMBAAECggEAB7t40P/qnG4zewEjvafWGNCtkim/ZWkYl7H4oujOx8OB
  #|9Mb5E0fE31RmDxt3is26WS4N+v4ojXlr+twPTi5bt8UzGW4diegRDq8xK8Yn7zfy
  #|uKG6O3Wuw83Yhsj3bAc3SLZSn82AcHYhNB8DQmTzKXOX4ZmLC/V3h/68Vqfdc511
  #|pekoNszwRe6mgEIvsmG2+7yaOmhC4GrIVsOeTQJvVCHTtHOOsChoLq9b1yC7/YXa
  #|ReUN+ta9otOgeq2tqgF+saCXIiwZwHGexXegm0jRjJHVWDymQTlpLLxHQmZzwEUe
  #|tRRnTLiF8vx+yrxmxTNGigMMk8CYNN0eLl253faz2QKBgQDqpzSDw0z7jI8XmdvP
  #|dPsAXy6tQgKUbWVBL6j/4bcqpaGtGNph1WSb49naDl2nRdSVBkXrKiRIGwakGDQe
  #|TtuTr+oJW9TjulK0SUif16+dSRYR2IQbUf3p6loaixwCpTOJBW9QCBE9FD0OpC10
  #|8jlBpcPZ+PDjKhHDFgBf/yQHIwKBgQDYIIHW1lNWhlPeyBieC7rUYaq7E+iv8vle
  #|xaGMbpwOMpd7L1OJ9lL3laDDe5ULHNd8H3vTpfrlJA5ww212PnUXpg8NXW7bwL44
  #|UFRadujt54K+MjMq0wt9ILxdlEzen7kcbLnMPqxhFAOobJ8SfWFGxo1kPIXT2O2q
  #|SfqaFVebawKBgQDR+CpqmRDCqqTEFp31RhTv4TvwNvf9/uGy8cXEqiHvnGROcsW+
  #|82big4FFuMMe0cKGUyWvZ3ctulk37px8Xk3nGmtOUojt+aTVxBmjRinTkTmZYGfd
  #|1oFhlZ1o0P+Qcmjp/B39vCpIwFpeRpSSZ8jKMF1PJ43Nh7B7I63UOIbxhwKBgCpi
  #|7bPporyEaax2h8VvPXvrj6VS+T6Qo3F/xvgYtUhfia/iDzsucQUXdkkAUrG0PVqd
  #|fhZ7JeKMmLxqx2v6QdKagbc4TMaSXXwD3RdE3NfToKOWisxqSYWHxwl/TTgYESDO
  #|/f1diUccur7sVqI0rsBHrnErIX/zumC8U4amiuDzAoGAPfeWcT+jfuAJuq9V++5b
  #|9b47IDnxWIzNvr/CWoIcmnz+HEJCX0xxpCjjzG4tbHgVQbXmDPpzPsXIsciavuZT
  #|CxzvJqtmwKhF9Q0mvfb9DHWCqyqEWu+k8UlgMOK3FOcPboaTwHTGdB66ufXexZxV
  #|yDifBJsJWuekwVcfe9tvsow=
  #|-----END PRIVATE KEY-----

///|
#cfg(target="js")
let cert_pem =
  #|-----BEGIN CERTIFICATE-----
  #|MIICpDCCAYwCCQDY75kUA6AxsTANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
  #|b2NhbGhvc3QwHhcNMjYwNTEyMTIzMjQ1WhcNMjcwNTEyMTIzMjQ1WjAUMRIwEAYD
  #|VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDG
  #|GuA46vHS2I9uv5/N6yiyarjUGPm1/cxwWBobxB9IFcn8fXu41C5YmKh7cvRrArei
  #|Xf1NeXMNm6rC9M7JH51V9XqPCIDnJB/mZ6qhQjj7YniNWvUcNqpIHg55cbWkMStt
  #|Pvub7zYJ3Vbkmah46la1N5OieCiU974YPuHqZ0qbOCEw3/+5kQQZlYuXEKUz/dLl
  #|ovYluvUusl2pOj3qUaeWfMs8slammPx3OzfoercDyETDNmyJvSXMHmtbJYSCBa5A
  #|FZZMtAcw8gWHPRw5hZy+C7GgCC+26tGKiFuReE6ge6feJ/KOYQMv5zkXH4tmM20h
  #|auwGWBY7X86ZanzARiyhAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAKzPXMrQrdYj
  #|2ziE6hzDy5+p9xuZYC7kso1lOYsPqtylBBrQtNkIwe0+1FIUHB5Jg9c6hpD+Ta+Q
  #|Q5LFTUXsaSAYSNcKRi4+yA2sCllyT0b4temgsjG/1145ZTmezWH5zPuWNmOWGgRa
  #|No+B2SFH4uKZF8Em4XwlK9xWJar9udAUbptZO2WJNmN0Pd7siP+Cm5iJTprIwegw
  #|hLCu6HeRobP4ATdu4MIKK2OQwEZBrCOGP2UV8HSqzTwGdjv6qqxB2g3yqo/WouZi
  #|5H7UHRztzdIjLhTRK2zX4O+0f4x6SENtTu8JYyxxbeCNEKUF9nbLEzTs93RU5cR9
  #|ABeu8O5K8jo=
  #|-----END CERTIFICATE-----

///|
#cfg(target="js")
let other_key_pem =
  #|-----BEGIN PRIVATE KEY-----
  #|MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDjTOGQXq+yJzvj
  #|P5IZMM0eGdBRgzHrFmfABULuG6V5c4zkmdVfyVxoNVHZFnaDmFovKQjDCqoxMKyR
  #|JmjkPRzEOaME8Wykz2K+71Tw94aZMTtcViitOiUE6LQyPTbMfg6f2Zv80SmrtB+t
  #|Tnl5XwQ3ClrtrzU7yXWHcz7e1tkgYIPJKiQKFd29Roe+5sXYEvfgY2NK8Tw3dW4b
  #|wf9aojdJ96jdPKV1q1I9feKHtClGbY97TvSDu2GouS4b273IBXlvZZIpSvtkRzZe
  #|d21xFrh+z9t85+04wxKMVMbovIqdCsKRtRWNoIT2ez1QEvHOdsqflAUlZ9z8Dr+c
  #|3x45nTNZAgMBAAECggEBAL+smFXnEt/3p8/VTr1BYucsO3hRWun0hd7uUOd7lsnZ
  #|AAnSE5Xntq4FsJSRFbWY5wv33XSj7Kr4cb0hF7jINBbgx7Cmach9PbbnGcjt4qoS
  #|Uw1ldn3Fl2wRU8s9xZUiA/EWTy0dsLcjeMbrcxI/Zs2HRPBEHG7jTuG+9Fhz8rsS
  #|MWkI3/UW+otU2BmINjOXeUkj84qAkQAqEBKP5oGqxDSMtbi6W/9QkGfZWAKhG9Ds
  #|V/aJElippWaXoMi2Ina8CCckFEzOsvCGQpxI+9jsbMvcA3cbroHtHGc4mNQqbqxN
  #|+1no75fi8MXFwCj58afQYHs0uyu7PIIeqq9oc5KZz4ECgYEA+K9G5y/rZ4TO1FKQ
  #|1YQRp1F6XhYmPFceX7NRmqG2ouaKj+19FaImvhWKkImI+FFpyd8UXB2bKNdOwNjJ
  #|vRUoU8U7PGuIXSBO8MkJjLdanE5hBgtk5e0pYcgcgTyc5Fohj+cv82YtQjA6moZ4
  #|W3j3o1gET49N9MjxBCayXDnI9akCgYEA6fyRp6voo7nj45/YOKzX7lHcbBJtDQ5n
  #|EsviQNV3pkWeQNriZb51CfX/aTpslkJUmtPcnNQdDZ8U8lNlCNodc8STxrjGpRG3
  #|7ycxgDMaPi3c6ZkAObgK5C2TPoVz3TSW9X5QOfbuCPJxBkGvQNjsDROz3eJympI4
  #|NgLvBQN1fjECgYA7kikm6ji2xH6TJ/Af5ZIhBYiNjzq7i5bwD9GFfCV24kjg71/e
  #|Vch4EkruErQn38C6peCHrGPlpaXs1kGFNNNDNeTZtVymCj4+ubm65pUjCjd9ri8O
  #|UQBvtvL1FmLy5JBTm2rGIHzI9Sqkp3+fUdvoWgY2VLq034m0l9xz8TeteQKBgQDL
  #|oNv5eWfqJHoovBDlsbXxVxhmjNqOhDw7ZWevWJbaArgoZNSmCsu8MXNnVkrtsSgD
  #|3eCeMxJdqlYGVYEV5QvAlhCs3l0xhmv2Gru/f7mU50DboiVKFdqUnP0JagZdOcku
  #|OBEFgNnCu4qVEVC9NIqpDr53mPx3fEyi5IaybEIx4QKBgEKws2C9VnPCdlZKeJvA
  #|fmVdHc1/cADZe+NGpZqmQY1Kl5r7jo+l1ipvMjlikCWssIciUycwSdchrfXi1ahD
  #|O3UBeO2YM4YI7QGpV3xkLzgRv1gfmrVoeo3TJVJTYgErukFsQ8vfoNmYIBtKBw9J
  #|0GLaJrQUpdUgfJUwCqte73ga
  #|-----END PRIVATE KEY-----

///|
#cfg(target="js")
let other_cert_pem =
  #|-----BEGIN CERTIFICATE-----
  #|MIICpDCCAYwCCQC2A5LcYyLsATANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
  #|b2NhbGhvc3QwHhcNMjYwNTEyMTUwNTQwWhcNMjcwNTEyMTUwNTQwWjAUMRIwEAYD
  #|VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDj
  #|TOGQXq+yJzvjP5IZMM0eGdBRgzHrFmfABULuG6V5c4zkmdVfyVxoNVHZFnaDmFov
  #|KQjDCqoxMKyRJmjkPRzEOaME8Wykz2K+71Tw94aZMTtcViitOiUE6LQyPTbMfg6f
  #|2Zv80SmrtB+tTnl5XwQ3ClrtrzU7yXWHcz7e1tkgYIPJKiQKFd29Roe+5sXYEvfg
  #|Y2NK8Tw3dW4bwf9aojdJ96jdPKV1q1I9feKHtClGbY97TvSDu2GouS4b273IBXlv
  #|ZZIpSvtkRzZed21xFrh+z9t85+04wxKMVMbovIqdCsKRtRWNoIT2ez1QEvHOdsqf
  #|lAUlZ9z8Dr+c3x45nTNZAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAN+ADvhU4y4M
  #|xfshB/pngDhCXOPGR1M1ZqoDshzBqnJ3vjlKvXITQELX2+tu72ceOvk5iEs2jF6L
  #|EeocPVADNQct8uFrpsmW0nssYv+YS4W/jS7q6w6xVRizEzw2ILZ4vExIv3xZjMFN
  #|sc3dRmAv4/gt9sG2affy9L4tNOx7iiVTZCzufILM0eucxRyjs+4Mv3jfF4b1z8HT
  #|7h+P8ugQcZ5+uc0v3MqyAXGLekJfKkSpqhlonwwiQJSUiE/gj0nslcXlGOKa9x6Y
  #|6w6oIN+1cKpE65vyFudGjHhBWLc2zfOPA7p/OMainIeCObCXuc65Ca9SlhGEKIzl
  #|d9ZtzROFG7o=
  #|-----END CERTIFICATE-----

///|
#cfg(target="js")
async fn write_test_keys() -> (String, String) {
  let suffix = @crypto.bytes_to_hex_string(@tls.rand_bytes(8))
  let key = "/tmp/mizchi_x_tls_key_\{suffix}.pem"
  let cert = "/tmp/mizchi_x_tls_cert_\{suffix}.pem"
  @fs.write_file(key, key_pem)
  @fs.write_file(cert, cert_pem)
  (key, cert)
}

///|
#cfg(target="js")
async fn write_other_test_keys() -> (String, String) {
  let suffix = @crypto.bytes_to_hex_string(@tls.rand_bytes(8))
  let key = "/tmp/mizchi_x_tls_other_key_\{suffix}.pem"
  let cert = "/tmp/mizchi_x_tls_other_cert_\{suffix}.pem"
  @fs.write_file(key, other_key_pem)
  @fs.write_file(cert, other_cert_pem)
  (key, cert)
}

///|
#cfg(target="js")
async fn remove_if_exists(path : String) -> Unit {
  try @fs.remove(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
// TLS needs buffered duplex transport: the JS in-memory pipe is a rendezvous
// channel and can deadlock when both peers send handshake records at once.
// Loopback TCP also gives native a raw peer for the client-only tests.
async fn test_pipe() -> (@socket.Tcp, @socket.Tcp) {
  let listener = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  defer listener.close()
  let reader = @socket.Tcp::connect(listener.addr)
  errdefer reader.close()
  let (writer, _) = listener.accept()
  (reader, writer)
}

///|
test "sha1" {
  inspect(
    @crypto.bytes_to_hex_string(@tls.sha1(b"abc")),
    content="a9993e364706816aba3e25717850c26c9cd0d89d",
  )
}

///|
test "rand_bytes length" {
  inspect(@tls.rand_bytes(12).length(), content="12")
}

///|
#cfg(target="js")
async test "one way" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      let server_task = root.spawn(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        let data = server.read_all().text()
        server.shutdown()
        data
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        client.write(b"abcd")
        @async.sleep(50)
        client.write(b"efgh")
        @async.sleep(50)
        client.write(b"ijkl")
        client.shutdown()
        inspect(client.read_all().text(), content="")
      })
      inspect(server_task.wait(), content="abcdefghijkl")
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}

///|
#cfg(target="js")
async test "echo" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        match server.read_some() {
          Some(data) => {
            inspect(@utf8.decode(data), content="ping")
            server.write(b"pong")
          }
          None => fail("expected tls request")
        }
        server.shutdown()
        ignore(server.read_all())
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        assert_true(client.get_peer_certificate() is Some(_))
        client.write(b"ping")
        inspect(@utf8.decode(client.read_exactly(4)), content="pong")
        client.shutdown()
      })
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}

///|
async test "`connect` accidental close" {
  @async.with_timeout(5000, () => {
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        ignore(server_read_from_client.read_some())
        @async.sleep(100)
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = try
          @tls.Tls::client_from_pair(
            client_read_from_server,
            client_write_to_server,
            trust=@tls.NoVerification,
          )
        catch {
          err => Err(err)
        } noraise {
          value => Ok(value)
        }
        match client {
          Ok(client) => {
            client.close()
            fail("expected `ConnectionClosed` error")
          }
          Err(err) => inspect(err, content="ConnectionClosed")
        }
      })
    })
  })
}

///|
#cfg(target="js")
async test "`read` already closed" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        server.close()
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        let result = try client.read_some() catch {
          err => Err(err)
        } noraise {
          value => Ok(value)
        }
        debug_inspect(result, content="Ok(None)")
      })
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}

///|
#cfg(target="js")
async test "get_peer_certificate" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        debug_inspect(
          server.get_peer_certificate().map(cert => cert.length()),
          content="None",
        )
        ignore(server.read_all())
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        assert_true(client.get_peer_certificate() is Some(_))
        client.shutdown()
      })
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}

///|
#cfg(target="js")
async test "client custom root certificate" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        assert_eq(server.read_exactly(2), b"ok")
        server.shutdown()
        ignore(server.read_all())
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          host="localhost",
          trust=@tls.CustomPemFile(cert),
        )
        defer client.close()
        client.write(b"ok")
        client.shutdown()
        inspect(client.read_all().text(), content="")
      })
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}

///|
#cfg(target="js")
async test "client custom root certificate rejects different root" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    let (other_key, other_cert) = write_other_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = try
          @tls.Tls::server_from_pair(
            server_read_from_client,
            server_write_to_client,
            private_key_file=other_key,
            private_key_type=@tls.PEM,
            certificate_file=other_cert,
            certificate_type=@tls.PEM,
          )
        catch {
          err => Err(err)
        } noraise {
          value => Ok(value)
        }
        assert_true(server is Err(_))
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = try
          @tls.Tls::client_from_pair(
            client_read_from_server,
            client_write_to_server,
            host="localhost",
            trust=@tls.CustomPemFile(cert),
          )
        catch {
          err => Err(err)
        } noraise {
          value => Ok(value)
        }
        assert_true(client is Err(_))
      })
    })
    remove_if_exists(key)
    remove_if_exists(cert)
    remove_if_exists(other_key)
    remove_if_exists(other_cert)
  })
}

///|
#cfg(target="js")
async test "channel binding" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      let server_task = root.spawn(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        let binding = (
          server.unique_channel_binding(),
          server.server_endpoint_channel_binding(),
        )
        ignore(server.read_all())
        binding
      })
      let client_task = root.spawn(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        let binding = (
          client.unique_channel_binding(),
          client.server_endpoint_channel_binding(),
        )
        client.shutdown()
        binding
      })
      let (server_unique, server_endpoint) = server_task.wait()
      let (client_unique, client_endpoint) = client_task.wait()
      assert_eq(client_unique, server_unique)
      assert_true(client_unique.length() > 0)
      assert_eq(client_endpoint, server_endpoint)
      assert_true(client_endpoint.length() > 0)
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}

///|
#cfg(target="js")
async test "peer close connection" {
  @async.with_timeout(5000, () => {
    let (key, cert) = write_test_keys()
    @async.with_task_group(root => {
      let (client_read_from_server, server_write_to_client) = test_pipe()
      let (server_read_from_client, client_write_to_server) = test_pipe()
      root.spawn_bg(() => {
        defer {
          server_read_from_client.close()
          server_write_to_client.close()
        }
        let server = @tls.Tls::server_from_pair(
          server_read_from_client,
          server_write_to_client,
          private_key_file=key,
          private_key_type=@tls.PEM,
          certificate_file=cert,
          certificate_type=@tls.PEM,
        )
        defer server.close()
        server.write(b"1234")
        inspect(@utf8.decode(server.read_exactly(4)), content="abcd")
      })
      root.spawn_bg(() => {
        defer {
          client_read_from_server.close()
          client_write_to_server.close()
        }
        let client = @tls.Tls::client_from_pair(
          client_read_from_server,
          client_write_to_server,
          trust=@tls.NoVerification,
        )
        defer client.close()
        inspect(@utf8.decode(client.read_exactly(4)), content="1234")
        client.write(b"abcd")
        client.close()
      })
    })
    remove_if_exists(key)
    remove_if_exists(cert)
  })
}
