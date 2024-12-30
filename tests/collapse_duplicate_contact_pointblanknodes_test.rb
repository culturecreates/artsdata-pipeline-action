require 'minitest/autorun'
require 'linkeddata'

class CollapseDuplicateContactPointBlankNodesTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/collapse_duplicate_contact_pointblanknodes.sparql"
  end

  def test_collapse_duplicate_contact_pointblanknodes
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./tests/fixtures/test_collapse_duplicate_contact_pointblanknodes.jsonld")
    graph.query(sparql)
    assert_equal(
      1,
      graph.query([nil, RDF::URI("http://schema.org/contactPoint"), nil]).objects.count
    )
  end
end
