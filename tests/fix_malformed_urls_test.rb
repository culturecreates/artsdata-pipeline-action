require 'minitest/autorun'
require 'linkeddata'

class FixMalformedUrlsTest < Minitest::Test

  def setup
    @fix_malformed_urls_sparql_file = "./sparql/fix_malformed_urls.sparql"
  end

  # check that the blank node is replaced
  def test_fix_malformed_urls
    sparql = SPARQL.parse(File.read(@fix_malformed_urls_sparql_file), update: true)
    graph = RDF::Graph.load("./tests/fixtures/test_fix_malformed_urls.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"
    assert_equal RDF::URI("https://example.com/?post_type=event&p=12292"), graph.query([RDF::URI("http://example.com/123"), RDF::URI("http://schema.org/url"), nil]).each.objects.first
  end
end
