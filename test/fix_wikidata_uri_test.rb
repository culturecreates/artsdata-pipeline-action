require 'minitest/autorun'
require 'linkeddata'

class FixWikidataUriTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/fix_wikidata_uri.sparql"
  end

  def test_fix_wikidata_uri
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_wikidata_uri.jsonld")
    graph.query(sparql)
    assert_equal(
      RDF::URI("http://www.wikidata.org/entity/Q42"),
      graph.query([RDF::URI("http://example.com/entity/123"), RDF::URI("http://schema.org/sameAs"), nil]).objects.first
    )
  end
end
