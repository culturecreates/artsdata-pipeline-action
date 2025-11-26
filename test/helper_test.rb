require 'minitest/autorun'
require_relative '../src/lib/helper'
require 'json/ld'
require 'rdf'

class HelperTest < Minitest::Test

  def setup
    @metadata_content = {
			'datafeed_uri'   => 'http://example.com/datafeed',
			'datafeed_url'  => 'http://example.com/feed',
			'datafeed_title'=> 'Test Feed',
			'datafeed_name' => 'Test Organization',
			'same_as'       => ['http://example.com/org'],
			'databus_id'    => 'http://example.com/databus',
			'url_count'     => 42,
			'start_time'    => '2025-11-26T10:00:00Z',
			'end_time'      => '2025-11-26T11:00:00Z'
		}
  end
	def test_generate_metadata_file_content
		graph = Helper.generate_metadata_file_content(@metadata_content)
		assert_instance_of RDF::Graph, graph
		# Check that the graph contains the expected datafeed URI as a subject
		subjects = graph.subjects.map(&:to_s)
		assert_includes subjects, @metadata_content['datafeed_uri']
		# Check that the graph contains the expected databus ID as a subject
		assert_includes subjects, @metadata_content['databus_id']
		# Check that the graph contains at least one triple
		refute_empty graph
	end

  def test_url
    graph = Helper.generate_metadata_file_content(@metadata_content)
    solution = graph.query([nil, RDF::Vocab::SCHEMA.url, nil])
    assert_equal RDF::URI, solution.first.object.class, "Expected schema:url object to be of type RDF::URI"
  end

  def test_datafeedElement
    graph = Helper.generate_metadata_file_content(@metadata_content)
    solution = graph.query([nil, RDF::URI("https://schema.org/dataFeedElement"), nil])
    assert_equal RDF::URI, solution.first&.object&.class, "Expected schema:datafeedElement object to be of type RDF::URI"
  end

  def test_used
    graph = Helper.generate_metadata_file_content(@metadata_content)
    solution = graph.query([nil, RDF::Vocab::PROV.used, nil])
    assert_equal RDF::URI, solution.first.object.class, "Expected prov:used object to be of type RDF::URI"
  end

  def test_wasInformedBy
    graph = Helper.generate_metadata_file_content(@metadata_content)
    solution = graph.query([nil, RDF::Vocab::PROV.wasInformedBy, nil])
    assert_equal RDF::URI, solution.first.object.class, "Expected prov:wasInformedBy object to be of type RDF::URI"
  end

  def test_startedAtTime
    graph = Helper.generate_metadata_file_content(@metadata_content)
    solution = graph.query([nil, RDF::Vocab::PROV.startedAtTime, nil])
    assert_equal RDF::Literal::DateTime, solution.first.object.class, "Expected prov:startedAtTime object to be of type RDF::Literal::DateTime"
  end


end