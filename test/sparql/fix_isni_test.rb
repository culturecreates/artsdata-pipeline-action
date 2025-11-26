require 'minitest/autorun'
require 'linkeddata'

class FixIsniTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/fix_isni.sparql"
  end

  def test_fix_isni
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_isni.jsonld")
    graph.query(sparql)
    assert_equal(
      "https://isni.org/isni/00001234567",
      graph.query([RDF::URI("https://example.org/person/123"), RDF::URI("http://schema.org/sameAs"), nil]).objects.first.value
    )
  end
end
