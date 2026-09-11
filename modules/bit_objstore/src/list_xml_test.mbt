///|
test "list xml: truncated pages report their last key as the cursor" {
  let xml =
    #|<ListBucketResult>
    #|<IsTruncated>true</IsTruncated>
    #|<Contents><Key>a/1</Key><Size>1</Size><ETag>&quot;e1&quot;</ETag></Contents>
    #|<Contents><Key>a/2</Key><Size>2</Size><ETag>&quot;e2&quot;</ETag></Contents>
    #|</ListBucketResult>
  let page = parse_list_objects_v2(xml)
  inspect(page.entries.length(), content="2")
  inspect(page.next.unwrap_or("<none>"), content="a/2")
}

///|
test "list xml: an empty result is not an error" {
  let xml =
    #|<ListBucketResult><IsTruncated>false</IsTruncated></ListBucketResult>
  let page = parse_list_objects_v2(xml)
  inspect(page.entries.length(), content="0")
  inspect(page.next is None, content="true")
}

///|
test "list xml: a truncated but empty page yields no cursor to loop on" {
  // Guards the pathological case where reporting a cursor would spin.
  let xml =
    #|<ListBucketResult><IsTruncated>true</IsTruncated></ListBucketResult>
  let page = parse_list_objects_v2(xml)
  inspect(page.next is None, content="true")
}

///|
test "list xml: keys are XML-unescaped" {
  let xml =
    #|<ListBucketResult><IsTruncated>false</IsTruncated>
    #|<Contents><Key>a&amp;b/c&lt;d&gt;e&apos;f&quot;g</Key><Size>0</Size><ETag>&quot;x&quot;</ETag></Contents>
    #|</ListBucketResult>
  let page = parse_list_objects_v2(xml)
  inspect(page.entries[0].key, content="a&b/c<d>e'f\"g")
}

///|
test "xml_unescape: unknown entities and bare ampersands survive" {
  inspect(xml_unescape("plain"), content="plain")
  inspect(xml_unescape("a&b"), content="a&b")
  inspect(xml_unescape("&unknown;"), content="&unknown;")
  inspect(xml_unescape("&amp;&amp;"), content="&&")
  inspect(xml_unescape("x&amp;"), content="x&")
  inspect(xml_unescape("&amp;x"), content="&x")
}

///|
test "list xml: sizes parse and a missing size defaults to zero" {
  let xml =
    #|<ListBucketResult><IsTruncated>false</IsTruncated>
    #|<Contents><Key>k1</Key><Size>1234567890123</Size><ETag>&quot;a&quot;</ETag></Contents>
    #|<Contents><Key>k2</Key><ETag>&quot;b&quot;</ETag></Contents>
    #|</ListBucketResult>
  let page = parse_list_objects_v2(xml)
  inspect(page.entries[0].size, content="1234567890123")
  inspect(page.entries[1].size, content="0")
}

///|
test "lex_compare: byte order, not length order" {
  // The distinction that broke SigV4: String::compare answers -1 here.
  inspect(lex_compare("b", "aa"), content="1")
  inspect(lex_compare("x-amz-content-sha256", "x-amz-date"), content="-1")
  // A separator sorts before a letter, which is what Git and S3 both assume.
  inspect(lex_compare("a/b", "ab"), content="-1")
  inspect(lex_compare("log/10", "log/2"), content="-1")
  inspect(lex_compare("same", "same"), content="0")
  inspect(lex_compare("a", "ab"), content="-1")
}
