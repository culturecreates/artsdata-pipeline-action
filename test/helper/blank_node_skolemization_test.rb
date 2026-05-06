require 'minitest/autorun'
require 'rdf'
require 'linkeddata'
require 'digest'
require_relative '../../src/lib/helper'
require_relative '../../src/config/spider_config'

class TestBlankNodeSkolemization < Minitest::Test
  
  def test_identical_blank_nodes_become_same_uri
    event_uri = RDF::URI("http://www.kingstongrand.ca/events/menopause-2026#2953")
    base_url = "http://www.kingstongrand.ca"
    
    # Graph 1: Event with location blank node
    graph1 = RDF::Graph.new
    location1 = RDF::Node.new
    
    graph1 << [event_uri, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph1 << [event_uri, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Test Event", language: :en)]
    graph1 << [event_uri, RDF::Vocab::SCHEMA.location, location1]
    graph1 << [location1, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph1 << [location1, RDF::Vocab::SCHEMA.name, "Kingston Grand Theatre"]
    graph1 << [location1, RDF::Vocab::SCHEMA.address, "218 Princess St"]
    
    # Graph 2: SAME event with SAME location data (different blank node)
    graph2 = RDF::Graph.new
    location2 = RDF::Node.new  # Different blank node object
    
    graph2 << [event_uri, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph2 << [event_uri, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Test Event", language: :en)]
    graph2 << [event_uri, RDF::Vocab::SCHEMA.location, location2]
    graph2 << [location2, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph2 << [location2, RDF::Vocab::SCHEMA.name, "Kingston Grand Theatre"]
    graph2 << [location2, RDF::Vocab::SCHEMA.address, "218 Princess St"]
    
    # Skolemize both graphs
    skolemized1 = Helper.skolemize_blank_nodes(graph1, base_url)
    skolemized2 = Helper.skolemize_blank_nodes(graph2, base_url)
    
    # Get location URIs from both graphs
    location_uri1 = skolemized1.query([event_uri, RDF::Vocab::SCHEMA.location, nil]).objects.first
    location_uri2 = skolemized2.query([event_uri, RDF::Vocab::SCHEMA.location, nil]).objects.first
    
    puts "\n=== Skolemization Results ==="
    puts "Location 1 URI: #{location_uri1}"
    puts "Location 2 URI: #{location_uri2}"
    
    # CRITICAL: Same data should produce SAME URI
    assert_equal location_uri1, location_uri2, 
      "Identical location data should produce identical URI after skolemization"
    
    # Verify it's a URI, not a blank node
    refute location_uri1.node?, "Location should be a URI, not a blank node"
    
    # Verify the URI is deterministic
    assert location_uri1.to_s.start_with?(base_url), 
      "Skolemized URI should start with base URL"
  end
  
  def test_different_blank_nodes_become_different_uris
    base_url = "http://www.kingstongrand.ca"
    graph = RDF::Graph.new
    event_uri = RDF::URI("http://example.com/event")
    
    # Two different locations
    location1 = RDF::Node.new
    location2 = RDF::Node.new
    
    graph << [event_uri, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph << [event_uri, RDF::Vocab::SCHEMA.location, location1]
    graph << [event_uri, RDF::Vocab::SCHEMA.location, location2]
    
    graph << [location1, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph << [location1, RDF::Vocab::SCHEMA.name, "Kingston Grand Theatre"]
    
    graph << [location2, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph << [location2, RDF::Vocab::SCHEMA.name, "Different Theatre"]
    
    skolemized = Helper.skolemize_blank_nodes(graph, base_url)
    
    location_uris = skolemized.query([event_uri, RDF::Vocab::SCHEMA.location, nil]).objects
    
    puts "\n=== Different Locations ==="
    puts "Location URIs: #{location_uris.map(&:to_s)}"
    
    # Different data should produce DIFFERENT URIs
    assert_equal 2, location_uris.size
    refute_equal location_uris[0], location_uris[1], 
      "Different locations should have different URIs"
  end
  
  def test_nested_blank_nodes_skolemized
    base_url = "http://www.kingstongrand.ca"
    graph = RDF::Graph.new
    event_uri = RDF::URI("http://example.com/event")
    
    # Nested structure: Event → Location → Address (blank node)
    location = RDF::Node.new
    address = RDF::Node.new
    
    graph << [event_uri, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph << [event_uri, RDF::Vocab::SCHEMA.location, location]
    
    graph << [location, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph << [location, RDF::Vocab::SCHEMA.name, "Kingston Grand Theatre"]
    graph << [location, RDF::Vocab::SCHEMA.address, address]
    
    graph << [address, RDF.type, RDF::Vocab::SCHEMA.PostalAddress]
    graph << [address, RDF::Vocab::SCHEMA.streetAddress, "218 Princess St"]
    graph << [address, RDF::Vocab::SCHEMA.addressLocality, "Kingston"]
    
    skolemized = Helper.skolemize_blank_nodes(graph, base_url)
    
    # Check location is URI
    location_uri = skolemized.query([event_uri, RDF::Vocab::SCHEMA.location, nil]).objects.first
    refute location_uri.node?, "Location should be URI"
    
    # Check address is URI
    address_uri = skolemized.query([location_uri, RDF::Vocab::SCHEMA.address, nil]).objects.first
    refute address_uri.node?, "Address should be URI"
    
    puts "\n=== Nested Skolemization ==="
    puts "Location URI: #{location_uri}"
    puts "Address URI: #{address_uri}"
  end
end