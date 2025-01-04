require 'minitest/autorun'
require 'linkeddata'

class CopySubeventDataToEventSeriesTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/copy_subevent_data_to_eventseries.sparql"
  end

  def test_copy_subevent_data_to_eventseries
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./tests/fixtures/test_copy_subevent_data_to_eventseries.jsonld")
    graph.query(sparql)
    assert_equal(
      ["2024-12-01T18:00:00", "2024-12-02T20:00:00"],
      [
        graph.query([RDF::URI("http://example.com/event-series/1"), RDF::URI("http://schema.org/startDate"), nil]).objects.first.value,
        graph.query([RDF::URI("http://example.com/event-series/1"), RDF::URI("http://schema.org/endDate"), nil]).objects.first.value
      ]
    )
  end
end
