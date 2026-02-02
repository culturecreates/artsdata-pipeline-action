require 'minitest/autorun'
require_relative '../../src/lib/helper'
require 'json/ld'
require 'rdf'

class MergeGraphsTest < Minitest::Test
  def setup
    @duplicate_graph_1 = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_with_duplicate_1.jsonld', __FILE__))
    @duplicate_graph_2 = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_with_duplicate_2.jsonld', __FILE__))

    @non_duplicate_postal_code_graph_1 = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_without_duplicate_postal_code_1.jsonld', __FILE__))
    @non_duplicate_postal_code_graph_2 = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_without_duplicate_postal_code_2.jsonld', __FILE__))

    @non_duplicate_place_name_graph_1 = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_without_duplicate_place_name_1.jsonld', __FILE__))
    @non_duplicate_place_name_graph_2 = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_without_duplicate_place_name_2.jsonld', __FILE__))
  end

  def test_merge_graphs_remove_duplicate_events
    merged_graph = Helper.merge_graph(@duplicate_graph_1, @duplicate_graph_2)
    event_uris = merged_graph.query([nil, RDF::RDFV.type, RDF::Vocab::SCHEMA.Event]).subjects.map(&:to_s)
    expected_uri = "http://example.com/resource/event-abc123"
    unexpected_uri = "http://example.com/temporary/event-temp-999"
    assert_equal true, event_uris.include?(expected_uri), "Expected to find event URI #{expected_uri} in the merged graph"
    assert_equal false, event_uris.include?(unexpected_uri), "Did not expect to find temporary event URI #{unexpected_uri} in the merged graph"

    organization_count = merged_graph.query([nil, RDF::RDFV.type, RDF::Vocab::SCHEMA.Organization]).count
    assert_equal 1, organization_count, "Expected only one Organization node in the merged graph"

    place_count = merged_graph.query([nil, RDF::RDFV.type, RDF::Vocab::SCHEMA.Place]).count
    assert_equal 2, place_count, "Expected two Place nodes in the merged graph"
  end

  def test_merge_graphs_without_duplicate_postal_code
    merged_graph = Helper.merge_graph(@non_duplicate_postal_code_graph_1, @non_duplicate_postal_code_graph_2)
    event_uris = merged_graph.query([nil, RDF::RDFV.type, RDF::Vocab::SCHEMA.Event]).subjects.map(&:to_s)
    expected_uri_1 = "http://example.com/temporary/event-temp-999"
    expected_uri_2 = "http://example.com/resource/event-abc123"
    assert_equal true, event_uris.include?(expected_uri_1), "Expected to find event URI #{expected_uri_1} in the merged graph"
    assert_equal true, event_uris.include?(expected_uri_2), "Expected to find event URI #{expected_uri_2} in the merged graph"
  end

  
  def test_merge_graphs_without_duplicate_place_name
    merged_graph = Helper.merge_graph(@non_duplicate_place_name_graph_1, @non_duplicate_place_name_graph_2)
    event_uris = merged_graph.query([nil, RDF::RDFV.type, RDF::Vocab::SCHEMA.Event]).subjects.map(&:to_s)
    expected_uri_1 = "http://example.com/temporary/event-temp-999"
    expected_uri_2 = "http://example.com/resource/event-abc123"
    assert_equal true, event_uris.include?(expected_uri_1), "Expected to find event URI #{expected_uri_1} in the merged graph"
    assert_equal true, event_uris.include?(expected_uri_2), "Expected to find event URI #{expected_uri_2} in the merged graph"
  end

  def test_shovel_operator_vs_merge_graph_without_duplicates
    deep_copy = RDF::Graph.new
    deep_copy << @non_duplicate_place_name_graph_1
    deep_copy << @non_duplicate_place_name_graph_2
    merged_graph = Helper.merge_graph(@non_duplicate_place_name_graph_1, @non_duplicate_place_name_graph_2)
    assert_equal deep_copy, merged_graph, "Merged graph does not match deep copy when no duplicates are present"
  end

  def test_shovel_operator_vs_merge_graph_with_duplicates
    deep_copy = RDF::Graph.new
    deep_copy << @duplicate_graph_1
    deep_copy << @duplicate_graph_2

    merged_graph = Helper.merge_graph(@duplicate_graph_1, @duplicate_graph_2)

    assert_equal false, deep_copy.equal?(merged_graph), "Merged graph should not be identical to deep copy when duplicates are present"
  end
  
  def test_merge_graphs_with_multilingual_duplicates
    duplicate_graph_fr = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_with_duplicate_1_french.jsonld', __FILE__))
    duplicate_graph_en = RDF::Graph.load(File.expand_path('../../fixtures/test_merge_graph_with_duplicate_1_english.jsonld', __FILE__))

    merged_graph = Helper.merge_graph(duplicate_graph_fr, duplicate_graph_en)
    event_uris = merged_graph.query([nil, RDF::RDFV.type, RDF::Vocab::SCHEMA.Event]).subjects.map(&:to_s)
    expected_uri = "http://example.com/temporary/event-temp-999"
    assert_equal true, event_uris.include?(expected_uri), "Expected to find event URI #{expected_uri} in the merged graph"

    name_solutions = merged_graph.query([RDF::URI(expected_uri), RDF::Vocab::SCHEMA.name, nil])
    names = name_solutions.objects.map { |obj| { value: obj.value, language: obj.language } }

    expected_names = [
      { value: "Test Duplicate Multilingual Event", language: :en },
      { value: "Test Duplicate Multilingual Event", language: :fr }
    ]

    assert_equal expected_names.sort_by { |n| n[:language].to_s }, names.sort_by { |n| n[:language].to_s }, "Expected multilingual names to be present in the merged graph"
  end

end