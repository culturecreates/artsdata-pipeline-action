require 'minitest/autorun'
require 'linkeddata'

class FixAttendanceModeTest < Minitest::Test
  def setup
    @sparql_file = "./sparql/fix_attendance_mode.sparql"
  end

  def test_fix_attendance_mode
    sparql = SPARQL.parse(File.read(@sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_attendance_mode.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"

    # event with one language tag attendance mode
    assert_equal(
      RDF::URI("http://schema.org/OfflineEventAttendanceMode"),
      graph.query([RDF::URI("http://example.org/events/1"), RDF::URI("http://schema.org/eventAttendanceMode"), nil]).first.object
    )
    # event with no language tag attendance modes
    assert_equal(
      RDF::URI("http://schema.org/OfflineEventAttendanceMode"),
      graph.query([RDF::URI("http://example.org/events/2"), RDF::URI("http://schema.org/eventAttendanceMode"), nil]).first.object
    )
    # event with multiple language tag attendance modes
    assert_equal(
      RDF::URI("http://schema.org/MixedEventAttendanceMode"),
      graph.query([RDF::URI("http://example.org/events/3"), RDF::URI("http://schema.org/eventAttendanceMode"), nil]).first.object
    )
    # proper event
    assert_equal(
      RDF::URI("http://schema.org/MixedEventAttendanceMode"),
      graph.query([RDF::URI("http://example.org/events/4"), RDF::URI("http://schema.org/eventAttendanceMode"), nil]).first.object
    )
  end
end
