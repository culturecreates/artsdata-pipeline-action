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

    @skipped_metadata_content = {
			'datafeed_uri'   => 'http://example.com/datafeed',
			'datafeed_url'  => 'http://example.com/feed',
			'datafeed_title'=> 'Test Feed',
			'datafeed_name' => 'Test Organization',
			'same_as'       => ['http://example.com/org'],
			'databus_id'    => 'http://example.com/databus',
			'url_count'     => 0,
			'start_time'    => '2025-11-26T10:00:00Z',
			'end_time'      => '2025-11-26T11:00:00Z',
      'skip_crawl'    => true,
      'crawl_name'    => 'Website skipped',
      'crawl_description' => 'Skipped crawl because website is already loaded by another activity.'
		}

    @metadata_content_with_score = @metadata_content.merge({'structured_score' => 85.12345})

    @metadata_content_with_artsdata_uri = @metadata_content.merge({'artsdata_uri' => 'http://kg.artsdata.ca/resource/org/TestOrganization'})
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
    solution = graph.query([nil, RDF::URI("http://schema.org/dataFeedElement"), nil])
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

  def test_crawl_name_does_not_exist_when_not_skipped
    graph = Helper.generate_metadata_file_content(@metadata_content)
    solution = graph.query([nil, RDF::Vocab::SCHEMA.name, RDF::Literal.new(@skipped_metadata_content['crawl_name'])]).size
    assert_equal 0, solution, "Did not expect to find schema:name with the crawl_name value"
  end

  def test_crawl_name
    graph = Helper.generate_metadata_file_content(@skipped_metadata_content)
    solution = graph.query([nil, RDF::Vocab::SCHEMA.name, RDF::Literal.new(@skipped_metadata_content['crawl_name'])]).size
    assert_equal 1, solution, "Expected to find one schema:name with the crawl_name value"
  end

  def test_structured_score_included
    graph = Helper.generate_metadata_file_content(@metadata_content_with_score)
    additional_properties = graph.query([nil, RDF::Vocab::SCHEMA.additionalProperty, nil])
    additional_properties.each do |property|
      value = graph.query([property.object, RDF::Vocab::SCHEMA.name, nil]).first&.object
      if value == RDF::Literal.new('structuredScore')
        score_value = graph.query([property.object, RDF::Vocab::SCHEMA.value, nil]).first.object.to_s
        assert_equal "85.12345", score_value, "Expected structuredScore value to be 85"
        return
      end
    end
  end

  def test_artsdata_uri_included
    graph = Helper.generate_metadata_file_content(@metadata_content_with_artsdata_uri)
    solution = graph.query([nil, RDF::Vocab::SCHEMA.sameAs, RDF::URI(@metadata_content_with_artsdata_uri['artsdata_uri'])]).size
    assert_equal 1, solution, "Expected to find one schema:sameAs with the artsdata_uri value"
  end

end