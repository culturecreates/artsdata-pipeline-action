require 'minitest/autorun'
require 'linkeddata'

class AddMissingSecondsTest < Minitest::Test

  def setup
    @add_missing_seconds_sparql_file = "./sparql/fix_date_missing_seconds.sparql"
  end

  def test_add_missing_seconds
    sparql_file = File.read(@add_missing_seconds_sparql_file)
    sparql = SPARQL.parse(sparql_file, update: true)
    graph = RDF::Graph.load("./test/fixtures/test_date_missing_seconds.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"

    assert_equal(
      RDF::Literal.new("2025-09-01T19:30:00", datatype: RDF::URI("http://schema.org/Date")), 
      graph.query([RDF::URI("http://example.com/event1"), RDF::URI("http://schema.org/startDate"), nil]).first.object
    )

    assert_equal(
      RDF::Literal.new("2025-09-01T19:30:00-05:00", datatype: RDF::URI("http://schema.org/DateTime")), 
      graph.query([RDF::URI("http://example.com/event2"), RDF::URI("http://schema.org/startDate"), nil]).first.object
    )

    assert_equal(
      RDF::Literal.new("2025-09-01T19:30:00", datatype: RDF::URI("http://schema.org/Date")), 
      graph.query([RDF::URI("http://example.com/event3"), RDF::URI("http://schema.org/startDate"), nil]).first.object
    )

    assert_equal(
      RDF::Literal.new("2025-09-01T19:30:00-05:00", datatype: RDF::URI("http://schema.org/DateTime")), 
      graph.query([RDF::URI("http://example.com/event4"), RDF::URI("http://schema.org/startDate"), nil]).first.object
    )
  end
end
