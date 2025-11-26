require 'minitest/autorun'
require 'linkeddata'

class CreateEventSeriesTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/create_eventseries.sparql"
  end

  def test_create_eventseries
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_create-eventseries.jsonld")
    graph.query(sparql)
    assert_equal(
      4,
      graph.query([nil, RDF::URI("http://schema.org/subEvent"), nil]).objects.count
    )
  end
end
