require 'minitest/autorun'
require_relative '../src/robots_txt_parser_service/robots_txt_parser'

# this test file follows google's robots.txt specification derived from RFC 9309 Robots Exclusion Protocol
# https://github.com/google/robotstxt/blob/master/robots_test.cc

class RobotsTxtParserTests < Minitest::Test
  def isAllowed?(robots_txt_content, user_agent, path)
    ruleset = RobotsTxtParser.parse(robots_txt_content)
    ruleset.allowed?(user_agent, path)
  end

  def default_tests
    robots_txt = <<~ROBOTS
      user-agent: FooBot
      disallow: /
    ROBOTS

    # Empty robots.txt: everything allowed.
    assert_equal(true, isAllowed?("", "FooBot", ""))
    # Empty user-agent to be matched: everything allowed.
    assert_equal(true, isAllowed?(robots_txt, "", ""))
    # FooBot disallowed from everything.
    assert_equal(false, isAllowed?(robots_txt, "FooBot", ""))
    # All params empty: same as robots.txt empty, everything allowed.
    assert_equal(true, isAllowed?("", "", ""))
  end

  # Rules are colon-separated name-value pairs. The following names are
  # provisioned:
  #   user-agent: <value>
  #   allow: <value>
  #   disallow: <value>
  # See REP RFC section "Protocol Definition":
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.1
  #
  # Google specific: webmasters sometimes miss the colon separator, but it's
  # obvious what they mean by "disallow /", so we assume the colon if it's
  # missing.
  def test_line_syntax
    robotstxt_correct = <<~ROBOTS
      user-agent: FooBot
      disallow: /
    ROBOTS

    robotstxt_incorrect = <<~ROBOTS
      foo: FooBot
      bar: /
    ROBOTS

    robotstxt_incorrect_accepted = <<~ROBOTS
      user-agent FooBot
      disallow /
    ROBOTS

    path = "x/y"

    assert_equal(false, isAllowed?(robotstxt_correct, "FooBot", path))
    assert_equal(true, isAllowed?(robotstxt_incorrect, "FooBot", path))
    assert_equal(false, isAllowed?(robotstxt_incorrect_accepted, "FooBot", path))
  end

  # A group is one or more user-agent lines followed by rules, and terminated
  # by another user-agent line. Rules for the same user-agents are combined
  # opaquely into one group. Rules outside groups are ignored.
  # See REP RFC section "Protocol Definition":
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.1
  def test_line_syntax_groups
    robotstxt = <<~ROBOTS
      allow: /foo/bar/

      user-agent: FooBot
      disallow: /
      allow: /x/
      user-agent: BarBot
      disallow: /
      allow: /y/


      allow: /w/
      user-agent: BazBot

      user-agent: FooBot
      allow: /z/
      disallow: /
    ROBOTS

    path_w = "w/a"
    path_x = "x/b"
    path_y = "y/c"
    path_z = "z/d"
    path_foo = "foo/bar/"

    assert_equal(true,  isAllowed?(robotstxt, "FooBot", path_x))
    assert_equal(true,  isAllowed?(robotstxt, "FooBot", path_z))
    assert_equal(false, isAllowed?(robotstxt, "FooBot", path_y))

    assert_equal(true,  isAllowed?(robotstxt, "BarBot", path_y))
    assert_equal(true,  isAllowed?(robotstxt, "BarBot", path_w))
    assert_equal(false, isAllowed?(robotstxt, "BarBot", path_z))

    assert_equal(true,  isAllowed?(robotstxt, "BazBot", path_z))

    assert_equal(false, isAllowed?(robotstxt, "FooBot", path_foo))
    assert_equal(false, isAllowed?(robotstxt, "BarBot", path_foo))
    assert_equal(false, isAllowed?(robotstxt, "BazBot", path_foo))
  end

  # A group must not be closed by rules not explicitly defined in the REP RFC.
  # See REP RFC section "Protocol Definition":
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.1
  def test_line_syntax_groups_other_rules
    robotstxt_1 = <<~ROBOTS
      User-agent: BarBot
      Sitemap: https://foo.bar/sitemap
      User-agent: *
      Disallow: /
    ROBOTS

    path = "/"

    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", path))
    assert_equal(false, isAllowed?(robotstxt_1, "BarBot", path))

    robotstxt_2 = <<~ROBOTS
      User-agent: FooBot
      Invalid-Unknown-Line: unknown
      User-agent: *
      Disallow: /
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", path))
    assert_equal(false, isAllowed?(robotstxt_2, "BarBot", path))
  end

  #REP lines are case insensitive. See REP RFC section "Protocol Definition".
  #https://www.rfc-editor.org/rfc/rfc9309.html#section-2.1
  def test_rep_line_names_case_insensitive
    robotstxt_upper = <<~ROBOTS
      USER-AGENT: FooBot
      ALLOW: /x/
      DISALLOW: /
    ROBOTS

    robotstxt_lower = <<~ROBOTS
      user-agent: FooBot
      allow: /x/
      disallow: /
    ROBOTS

    robotstxt_camel = <<~ROBOTS
      uSeR-aGeNt: FooBot
      AlLoW: /x/
      dIsAlLoW: /
    ROBOTS

    path_allowed = "/x/y"
    path_disallowed = "/a/b"

    # Case-insensitive directive names
    assert_equal(true,  isAllowed?(robotstxt_upper, "FooBot", path_allowed))
    assert_equal(true,  isAllowed?(robotstxt_lower, "FooBot", path_allowed))
    assert_equal(true,  isAllowed?(robotstxt_camel, "FooBot", path_allowed))

    assert_equal(false, isAllowed?(robotstxt_upper, "FooBot", path_disallowed))
    assert_equal(false, isAllowed?(robotstxt_lower, "FooBot", path_disallowed))
    assert_equal(false, isAllowed?(robotstxt_camel, "FooBot", path_disallowed))
  end
  
  # User-agent line values are case insensitive. See REP RFC section "The
  # user-agent line".
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.1
  def test_user_agent_value_case_insensitive
    robotstxt_upper = <<~ROBOTS
      User-Agent: FOO BAR
      Allow: /x/
      Disallow: /
    ROBOTS

    robotstxt_lower = <<~ROBOTS
      User-Agent: foo bar
      Allow: /x/
      Disallow: /
    ROBOTS

    robotstxt_camel = <<~ROBOTS
      User-Agent: FoO bAr
      Allow: /x/
      Disallow: /
    ROBOTS

    path_allowed = "/x/y"
    path_disallowed = "/a/b"

    # Match on user agent "Foo" (case-insensitive)
    assert_equal(true,  isAllowed?(robotstxt_upper, "Foo", path_allowed))
    assert_equal(true,  isAllowed?(robotstxt_lower, "Foo", path_allowed))
    assert_equal(true,  isAllowed?(robotstxt_camel, "Foo", path_allowed))
    assert_equal(false, isAllowed?(robotstxt_upper, "Foo", path_disallowed))
    assert_equal(false, isAllowed?(robotstxt_lower, "Foo", path_disallowed))
    assert_equal(false, isAllowed?(robotstxt_camel, "Foo", path_disallowed))

    # Match on user agent "foo" (case-insensitive)
    assert_equal(true,  isAllowed?(robotstxt_upper, "foo", path_allowed))
    assert_equal(true,  isAllowed?(robotstxt_lower, "foo", path_allowed))
    assert_equal(true,  isAllowed?(robotstxt_camel, "foo", path_allowed))
    assert_equal(false, isAllowed?(robotstxt_upper, "foo", path_disallowed))
    assert_equal(false, isAllowed?(robotstxt_lower, "foo", path_disallowed))
    assert_equal(false, isAllowed?(robotstxt_camel, "foo", path_disallowed))
  end

  # Google specific: accept user-agent value up to the first space. Space is not
  # allowed in user-agent values, but that doesn't stop webmasters from using
  # them. This is more restrictive than the RFC, since in case of the bad value
  # "Googlebot Images" we'd still obey the rules with "Googlebot".
  # Extends REP RFC section "The user-agent line"
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.1
  def test_google_only_accept_user_agent_up_to_first_space

    robotstxt = <<~ROBOTS
      User-Agent: *
      Disallow: /
      User-Agent: Foo Bar
      Allow: /x/
      Disallow: /
    ROBOTS

    path = "/x/y"

    assert_equal(true,  isAllowed?(robotstxt, "Foo", path))
    assert_equal(false, isAllowed?(robotstxt, "Foo Bar", path))
  end

  # If no group matches the user-agent, crawlers must obey the first group with a
  # user-agent line with a "*" value, if present. If no group satisfies either
  # condition, or no groups are present at all, no rules apply.
  # See REP RFC section "The user-agent line".
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.1
  def test_global_groups_secondary
    robotstxt_empty = ""
    
    robotstxt_global = <<~ROBOTS
      user-agent: *
      allow: /
      user-agent: FooBot
      disallow: /
    ROBOTS

    robotstxt_only_specific = <<~ROBOTS
      user-agent: FooBot
      allow: /
      user-agent: BarBot
      disallow: /
      user-agent: BazBot
      disallow: /
    ROBOTS

    path = "/x/y"

    assert_equal(true,  isAllowed?(robotstxt_empty, "FooBot", path))
    assert_equal(false, isAllowed?(robotstxt_global, "FooBot", path))
    assert_equal(true,  isAllowed?(robotstxt_global, "BarBot", path))
    assert_equal(true,  isAllowed?(robotstxt_only_specific, "QuxBot", path))
  end
  
  # Matching rules against URIs is case sensitive.
  # See REP RFC section "The Allow and Disallow lines".
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.2
  def test_allow_disallow_value_case_sensitive
    robotstxt_lowercase_url = <<~ROBOTS
      user-agent: FooBot
      disallow: /x/
    ROBOTS

    robotstxt_uppercase_url = <<~ROBOTS
      user-agent: FooBot
      disallow: /X/
    ROBOTS

    path = "/x/y"

    assert_equal(false, isAllowed?(robotstxt_lowercase_url, "FooBot", path))
    assert_equal(true,  isAllowed?(robotstxt_uppercase_url, "FooBot", path))
  end

  # The most specific match found MUST be used. The most specific match is the
  # match that has the most octets. In case of multiple rules with the same
  # length, the least strict rule must be used.
  # See REP RFC section "The Allow and Disallow lines".
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.2
  def test_longest_match
    path = "/x/page.html"

    robotstxt_1 = <<~ROBOTS
      user-agent: FooBot
      disallow: /x/page.html
      allow: /x/
    ROBOTS
    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", path))

    robotstxt_2 = <<~ROBOTS
      user-agent: FooBot
      allow: /x/page.html
      disallow: /x/
    ROBOTS
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", path))
    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", "/x/"))

    robotstxt_3 = <<~ROBOTS
      user-agent: FooBot
      disallow:
      allow:
    ROBOTS
    assert_equal(true, isAllowed?(robotstxt_3, "FooBot", path))

    robotstxt_4 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /
    ROBOTS
    assert_equal(true, isAllowed?(robotstxt_4, "FooBot", path))

    path_a = "/x"
    path_b = "/x/"
    robotstxt_5 = <<~ROBOTS
      user-agent: FooBot
      disallow: /x
      allow: /x/
    ROBOTS
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", path_a))
    assert_equal(true,  isAllowed?(robotstxt_5, "FooBot", path_b))

    robotstxt_6 = <<~ROBOTS
      user-agent: FooBot
      disallow: /x/page.html
      allow: /x/page.html
    ROBOTS
    assert_equal(true, isAllowed?(robotstxt_6, "FooBot", path))

    robotstxt_7 = <<~ROBOTS
      user-agent: FooBot
      allow: /page
      disallow: /*.html
    ROBOTS
    assert_equal(false, isAllowed?(robotstxt_7, "FooBot", "/page.html"))
    assert_equal(true,  isAllowed?(robotstxt_7, "FooBot", "/page"))

    robotstxt_8 = <<~ROBOTS
      user-agent: FooBot
      allow: /x/page.
      disallow: /*.html
    ROBOTS
    assert_equal(true,  isAllowed?(robotstxt_8, "FooBot", path))
    assert_equal(false, isAllowed?(robotstxt_8, "FooBot", "/x/y.html"))

    robotstxt_9 = <<~ROBOTS
      user-agent: *
      disallow: /x/
      user-agent: FooBot
      disallow: /y/
    ROBOTS
    assert_equal(true,  isAllowed?(robotstxt_9, "FooBot", "/x/page"))
    assert_equal(false, isAllowed?(robotstxt_9, "FooBot", "/y/page"))
  end

  # Octets in the URI and robots.txt paths outside the range of the US-ASCII
  # coded character set, and those in the reserved range defined by RFC3986,
  # MUST be percent-encoded as defined by RFC3986 prior to comparison.
  # See REP RFC section "The Allow and Disallow lines".
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.2
  #
  # NOTE: It's up to the caller to percent encode a URL before passing it to the
  # parser. Percent encoding URIs in the rules is unnecessary.
  def test_encoding
    # /foo/bar?baz=http://foo.bar stays unencoded.
    robotstxt_query = <<~ROBOTS
      User-agent: FooBot
      Disallow: /
      Allow: /foo/bar?qux=taz&baz=http://foo.bar?tar&par
    ROBOTS

    path_query = "/foo/bar?qux=taz&baz=http://foo.bar?tar&par"
    assert_equal(true, isAllowed?(robotstxt_query, "FooBot", path_query))

    # 3-byte character: /foo/bar/ツ -> /foo/bar/%E3%83%84
    robotstxt_utf8 = <<~ROBOTS
      User-agent: FooBot
      Disallow: /
      Allow: /foo/bar/ツ
    ROBOTS

    path_encoded = "/foo/bar/%E3%83%84"
    path_unencoded = "/foo/bar/ツ"

    # Encoded form allowed
    assert_equal(true, isAllowed?(robotstxt_utf8, "FooBot", path_encoded))
    # Unencoded form disallowed
    assert_equal(false, isAllowed?(robotstxt_utf8, "FooBot", path_unencoded))

    # Percent-encoded 3-byte character: /foo/bar/%E3%83%84
    robotstxt_percent_encoded = <<~ROBOTS
      User-agent: FooBot
      Disallow: /
      Allow: /foo/bar/%E3%83%84
    ROBOTS

    assert_equal(true,  isAllowed?(robotstxt_percent_encoded, "FooBot", path_encoded))
    assert_equal(false, isAllowed?(robotstxt_percent_encoded, "FooBot", path_unencoded))

    # Percent-encoded unreserved US-ASCII: /foo/bar/%62%61%7A
    # (Illegal per RFC3986; works by string match only)
    robotstxt_ascii_encoded = <<~ROBOTS
      User-agent: FooBot
      Disallow: /
      Allow: /foo/bar/%62%61%7A
    ROBOTS

    path_baz = "/foo/bar/baz"
    path_baz_encoded = "/foo/bar/%62%61%7A"

    assert_equal(false, isAllowed?(robotstxt_ascii_encoded, "FooBot", path_baz))
    assert_equal(true,  isAllowed?(robotstxt_ascii_encoded, "FooBot", path_baz_encoded))
  end

  # The REP RFC defines the following characters that have special meaning in
  # robots.txt:
  # # - inline comment.
  # $ - end of pattern.
  # * - any number of characters.
  # See REP RFC section "Special Characters".
  # https://www.rfc-editor.org/rfc/rfc9309.html#section-2.2.3
  def test_special_characters
    robotstxt_1 = <<~ROBOTS
      User-agent: FooBot
      Disallow: /foo/bar/quz
      Allow: /foo/*/qux
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", "/foo/bar/quz"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/foo/quz"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/foo//quz"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/foo/bax/quz"))

    robotstxt_2 = <<~ROBOTS
      User-agent: FooBot
      Disallow: /foo/bar$
      Allow: /foo/bar/qux
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", "/foo/bar"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/foo/bar/qux"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/foo/bar/"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/foo/bar/baz"))

    robotstxt_3 = <<~ROBOTS
      User-agent: FooBot
      # Disallow: /
      Disallow: /foo/quz#qux
      Allow: /
    ROBOTS

    assert_equal(true,  isAllowed?(robotstxt_3, "FooBot", "/foo/bar"))
    assert_equal(false, isAllowed?(robotstxt_3, "FooBot", "/foo/quz"))
  end

  # Test documentation from
  # https://developers.google.com/search/reference/robots_txt
  def test_google_only_documentation_checks
    # Section: "URL matching based on path values"
    robotstxt_1 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /fish
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", "/bar"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/fish"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/fish.html"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/fish/salmon.html"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/fishheads"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/fishheads/yummy.html"))
    assert_equal(true,  isAllowed?(robotstxt_1, "FooBot", "/fish.html?id=anything"))
    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", "/Fish.asp"))
    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", "/catfish"))
    assert_equal(false, isAllowed?(robotstxt_1, "FooBot", "/?id=fish"))

    # "/fish*" equals "/fish"
    robotstxt_2 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /fish*
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", "/bar"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/fish"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/fish.html"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/fish/salmon.html"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/fishheads"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/fishheads/yummy.html"))
    assert_equal(true,  isAllowed?(robotstxt_2, "FooBot", "/fish.html?id=anything"))
    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", "/Fish.bar"))
    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", "/catfish"))
    assert_equal(false, isAllowed?(robotstxt_2, "FooBot", "/?id=fish"))

    # "/fish/" does not equal "/fish"
    robotstxt_3 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /fish/
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_3, "FooBot", "/bar"))
    assert_equal(true,  isAllowed?(robotstxt_3, "FooBot", "/fish/"))
    assert_equal(true,  isAllowed?(robotstxt_3, "FooBot", "/fish/salmon"))
    assert_equal(true,  isAllowed?(robotstxt_3, "FooBot", "/fish/?salmon"))
    assert_equal(true,  isAllowed?(robotstxt_3, "FooBot", "/fish/salmon.html"))
    assert_equal(true,  isAllowed?(robotstxt_3, "FooBot", "/fish/?id=anything"))
    assert_equal(false, isAllowed?(robotstxt_3, "FooBot", "/fish"))
    assert_equal(false, isAllowed?(robotstxt_3, "FooBot", "/fish.html"))
    assert_equal(false, isAllowed?(robotstxt_3, "FooBot", "/Fish/Salmon.html"))

    # "/*.php"
    robotstxt_4 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /*.php
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_4, "FooBot", "/bar"))
    assert_equal(true,  isAllowed?(robotstxt_4, "FooBot", "/filename.php"))
    assert_equal(true,  isAllowed?(robotstxt_4, "FooBot", "/folder/filename.php"))
    assert_equal(true,  isAllowed?(robotstxt_4, "FooBot", "/folder/filename.php?parameters"))
    assert_equal(true,  isAllowed?(robotstxt_4, "FooBot", "/folder/any.php.file.html"))
    assert_equal(true,  isAllowed?(robotstxt_4, "FooBot", "/filename.php/"))
    assert_equal(true,  isAllowed?(robotstxt_4, "FooBot", "/index?f=filename.php/"))
    assert_equal(false, isAllowed?(robotstxt_4, "FooBot", "/php/"))
    assert_equal(false, isAllowed?(robotstxt_4, "FooBot", "/index?php"))
    assert_equal(false, isAllowed?(robotstxt_4, "FooBot", "/windows.PHP"))

    # "/*.php$"
    robotstxt_5 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /*.php$
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/bar"))
    assert_equal(true,  isAllowed?(robotstxt_5, "FooBot", "/filename.php"))
    assert_equal(true,  isAllowed?(robotstxt_5, "FooBot", "/folder/filename.php"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/filename.php?parameters"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/filename.php/"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/filename.php5"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/php/"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/filename?php"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/aaaphpaaa"))
    assert_equal(false, isAllowed?(robotstxt_5, "FooBot", "/windows.PHP"))

    # "/fish*.php"
    robotstxt_6 = <<~ROBOTS
      user-agent: FooBot
      disallow: /
      allow: /fish*.php
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_6, "FooBot", "/bar"))
    assert_equal(true,  isAllowed?(robotstxt_6, "FooBot", "/fish.php"))
    assert_equal(true,  isAllowed?(robotstxt_6, "FooBot", "/fishheads/catfish.php?parameters"))
    assert_equal(false, isAllowed?(robotstxt_6, "FooBot", "/Fish.PHP"))

    # Section: "Order of precedence for group-member records"
    robotstxt_7 = <<~ROBOTS
      user-agent: FooBot
      allow: /p
      disallow: /
    ROBOTS

    assert_equal(true, isAllowed?(robotstxt_7, "FooBot", "/page"))

    robotstxt_8 = <<~ROBOTS
      user-agent: FooBot
      allow: /folder
      disallow: /folder
    ROBOTS

    assert_equal(true, isAllowed?(robotstxt_8, "FooBot", "/folder/page"))

    robotstxt_9 = <<~ROBOTS
      user-agent: FooBot
      allow: /page
      disallow: /*.htm
    ROBOTS

    assert_equal(false, isAllowed?(robotstxt_9, "FooBot", "/page.htm"))

    robotstxt_10 = <<~ROBOTS
      user-agent: FooBot
      allow: /$
      disallow: /
    ROBOTS

    assert_equal(true,  isAllowed?(robotstxt_10, "FooBot", "/"))
    assert_equal(false, isAllowed?(robotstxt_10, "FooBot", "/page.html"))
  end


end