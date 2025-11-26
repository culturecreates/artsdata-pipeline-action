require 'minitest/autorun'
require 'linkeddata'

class FixSchemaOrgHttpsObjectsTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/fix_schemaorg_https_objects.sparql"
  end

  def test_fix_schemaorg_https_objects
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_schemaorg_https_objects.jsonld")
    graph.query(sparql)
    assert_equal(
      RDF::URI("http://schema.org/Example1"),
      graph.query([RDF::URI("http://example.org/resource1"), RDF::URI("http://schema.org/someProperty"), nil]).objects.first
    )
  end
end
