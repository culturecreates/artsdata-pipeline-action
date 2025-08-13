require 'minitest/autorun'
require 'linkeddata'

class FixStartDateTest < Minitest::Test

  def setup
    @fix_start_date_sparql_file = "./sparql/fix_date.sparql"
  end

  def test_fix_start_date
    sparql_file = File.read(@fix_start_date_sparql_file)
    sparql = SPARQL.parse(sparql_file, update: true)
    graph = RDF::Graph.load("./tests/fixtures/test_fix_start_date.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"
    assert_equal(
      RDF::Literal.new("2015-03-31T20:00:00", datatype: RDF::URI("http://schema.org/DateTime")), 
      graph.query([RDF::URI("http://example.org/events/1"), RDF::URI("http://schema.org/startDate"), nil]).first.object
    )
    assert_equal(
      RDF::Literal.new("2015-03-31T20:00:00", datatype: RDF::URI("http://schema.org/Date")), 
      graph.query([RDF::URI("http://example.org/events/2"), RDF::URI("http://schema.org/startDate"), nil]).first.object
    )
  end
end
