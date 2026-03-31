require 'minitest/autorun'
require_relative '../../src/lib/helper'

class MetadataGenerationSourceTest < Minitest::Test

  # Shared base content used across all test cases
  BASE_CONTENT = {
    'datafeed_uri'   => 'urn:datafeed:test-feed',
    'datafeed_url'   => 'https://example.com',
    'datafeed_title' => 'Test Feed',
    'datafeed_name'  => 'Test Organization',
    'crawl_name'     => 'Test Crawl',
    'crawl_description' => 'A test crawl',
    'databus_id'     => 'http://example.com/databus/version',
    'url_count'      => '10',
    'start_time'     => '2025-01-01T00:00:00Z',
    'end_time'       => '2025-01-01T01:00:00Z',
    'structured_score' => '75.0',
    'event_count'    => '5'
  }.freeze

  def test_wikidata_source_mints_org_uri
    content = BASE_CONTENT.merge(
      'same_as'     => 'http://www.wikidata.org/entity/Q12345',
      'artsdata_uri' => nil
    )
    graph = Helper.generate_metadata_file_content(content)
    subjects = graph.subjects.map(&:to_s)

    assert_includes subjects, 'urn:organization:Q12345',
      'Expected a minted urn:organization: URI for wikidata source'
  end

  def test_wikidata_source_emits_organization_type
    content = BASE_CONTENT.merge(
      'same_as'      => 'http://www.wikidata.org/entity/Q12345',
      'artsdata_uri' => nil
    )
    graph = Helper.generate_metadata_file_content(content)

    org_type_triple = graph.query(
      [RDF::URI('urn:organization:Q12345'),
       RDF.type,
       RDF::URI('http://schema.org/Organization')]
    )
    refute_empty org_type_triple, 'Expected schema:Organization type for wikidata source'
  end

  def test_wikidata_source_with_artsdata_uri_emits_both_same_as
    content = BASE_CONTENT.merge(
      'same_as'      => 'http://www.wikidata.org/entity/Q12345',
      'artsdata_uri' => 'http://kg.artsdata.ca/resource/K16-33'
    )
    graph = Helper.generate_metadata_file_content(content)

    same_as_objects = graph.query(
      [RDF::URI('urn:organization:Q12345'),
       RDF::URI('http://schema.org/sameAs'),
       nil]
    ).objects.map(&:to_s)

    assert_includes same_as_objects, 'http://www.wikidata.org/entity/Q12345'
    assert_includes same_as_objects, 'http://kg.artsdata.ca/resource/K16-33'
  end

  def test_artsdata_source_does_not_mint_org_uri
    content = BASE_CONTENT.merge(
      'same_as'      => '',
      'artsdata_uri' => 'http://kg.artsdata.ca/resource/K10-279'
    )
    graph = Helper.generate_metadata_file_content(content)
    subjects = graph.subjects.map(&:to_s)

    refute(subjects.any? { |s| s.start_with?('urn:organization:') },
      'Expected no urn:organization: URI for artsdata source')
  end

  def test_artsdata_source_does_not_emit_organization_type
    content = BASE_CONTENT.merge(
      'same_as'      => '',
      'artsdata_uri' => 'http://kg.artsdata.ca/resource/K10-279'
    )
    graph = Helper.generate_metadata_file_content(content)

    org_type_triples = graph.query(
      [nil, RDF.type, RDF::URI('http://schema.org/Organization')]
    )
    assert_empty org_type_triples, 'Expected no schema:Organization type for artsdata source'
  end


  def test_recrawl_source_does_not_mint_org_uri
    content = BASE_CONTENT.merge(
      'same_as'      => '',
      'artsdata_uri' => ''
    )
    graph = Helper.generate_metadata_file_content(content)
    subjects = graph.subjects.map(&:to_s)

    refute(subjects.any? { |s| s.start_with?('urn:organization:') },
      'Expected no urn:organization: URI for recrawl source')
  end

  def test_recrawl_source_datafeed_present
    content = BASE_CONTENT.merge(
      'same_as'      => '',
      'artsdata_uri' => ''
    )
    graph = Helper.generate_metadata_file_content(content)
    subjects = graph.subjects.map(&:to_s)

    assert_includes subjects, 'urn:datafeed:test-feed',
      'Expected DataFeed URI present for recrawl source'
  end

  def test_recrawl_source_website_uri_present
    content = BASE_CONTENT.merge(
      'same_as'      => '',
      'artsdata_uri' => ''
    )
    graph = Helper.generate_metadata_file_content(content)
    subjects = graph.subjects.map(&:to_s)

    assert_includes subjects, 'https://example.com',
      'Expected Website URI (datafeed_url) present for recrawl source'
  end

  # -----------------------------------------------------------------------
  # Common — DataFeed and crawl activity always present regardless of source
  # -----------------------------------------------------------------------
  def test_datafeed_always_present
    [
      BASE_CONTENT.merge('same_as' => 'http://www.wikidata.org/entity/Q1', 'artsdata_uri' => nil),
      BASE_CONTENT.merge('same_as' => '', 'artsdata_uri' => 'http://kg.artsdata.ca/resource/K10-1'),
      BASE_CONTENT.merge('same_as' => '', 'artsdata_uri' => '')
    ].each do |content|
      graph = Helper.generate_metadata_file_content(content)
      assert_includes graph.subjects.map(&:to_s), 'urn:datafeed:test-feed',
        "Expected DataFeed for source with same_as=#{content['same_as'].inspect}"
    end
  end

  def test_crawl_activity_always_present
    [
      BASE_CONTENT.merge('same_as' => 'http://www.wikidata.org/entity/Q1', 'artsdata_uri' => nil),
      BASE_CONTENT.merge('same_as' => '', 'artsdata_uri' => 'http://kg.artsdata.ca/resource/K10-1'),
      BASE_CONTENT.merge('same_as' => '', 'artsdata_uri' => '')
    ].each do |content|
      graph = Helper.generate_metadata_file_content(content)
      crawl_activities = graph.query(
        [nil, RDF.type, RDF::URI('http://www.w3.org/ns/prov#Activity')]
      )
      refute_empty crawl_activities,
        "Expected prov:Activity for source with same_as=#{content['same_as'].inspect}"
    end
  end

end