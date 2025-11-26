require 'minitest/autorun'
require 'linkeddata'

class FixMalformedUrlsTest < Minitest::Test

  def setup
    @fix_malformed_urls_sparql_file = "./sparql/fix_malformed_urls.sparql"
  end

  # check that the blank node is replaced
  def test_fix_malformed_urls
    sparql = SPARQL.parse(File.read(@fix_malformed_urls_sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_malformed_urls.jsonld")
    graph.query(sparql)
    assert graph.has_statement?(RDF::Statement.new(RDF::URI("http://example.com/123"), RDF::Vocab::SCHEMA.url, RDF::URI("https://example.com/?post_type=event&p=12292")))
  end
end
