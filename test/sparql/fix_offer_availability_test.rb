require 'minitest/autorun'
require 'linkeddata'

class FixOfferAvailabilityTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/fix_offer_availability.sparql"
  end

  def test_fix_offer_availability
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_offer_availability.jsonld")
    graph.query(sparql)
    assert_equal(
      "http://schema.org/outOfStock",
      graph.query([nil, RDF::URI("http://schema.org/availability"), nil]).objects.first.value
    )
  end
end
