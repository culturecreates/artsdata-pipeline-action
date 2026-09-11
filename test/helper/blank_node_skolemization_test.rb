require 'minitest/autorun'
require 'rdf'
require 'linkeddata'
require_relative '../../src/lib/helper'

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
    
  end

  def test_html_entity_encoded_literals_produce_same_uri
    base_url = "http://www.petittheatre.org"

    # Real-world variants captured from petittheatre.org: each is a different
    # per-render HTML-entity encoding of the SAME email, produced by the
    # site's anti-scraping obfuscation. They must not affect skolemization.
    encoded_email_variants = [
      "&#105;&#110;f&#111;&#64;&#112;et&#105;t&#116;h&#101;a&#116;r&#101;.&#111;r&#103;",
      "&#105;n&#102;&#111;&#64;p&#101;t&#105;t&#116;h&#101;a&#116;r&#101;.&#111;r&#103;",
      "in&#102;o&#64;p&#101;&#116;i&#116;&#116;he&#97;t&#114;e&#46;o&#114;&#103;",
      "in&#102;&#111;&#64;p&#101;&#116;i&#116;&#116;&#104;e&#97;tre.or&#103;",
      "info@petittheatre.org", # fully decoded form, for completeness
    ]

    uris = encoded_email_variants.map do |encoded_email|
      graph = RDF::Graph.new
      person = RDF::Node.new

      graph << [person, RDF.type, RDF::Vocab::SCHEMA.Person]
      graph << [person, RDF::Vocab::SCHEMA.name, "Petit Théâtre du Vieux Noranda"]
      graph << [person, RDF::Vocab::SCHEMA.telephone, "(819) 797-6436"]
      graph << [person, RDF::Vocab::SCHEMA.email, encoded_email]

      skolemized = Helper.skolemize_blank_nodes(graph, base_url)
      skolemized.query([nil, RDF.type, RDF::Vocab::SCHEMA.Person]).subjects.first.to_s
    end

    assert_equal 1, uris.uniq.size,
      "Same Person data with differently HTML-entity-encoded (but semantically identical) " \
      "email should skolemize to the SAME URI. Got distinct URIs: #{uris.uniq.inspect}"
  end
  
  def test_normalize_literals_decodes_double_encoded_entities
    graph = RDF::Graph.new
    person = RDF::URI("http://example.com/person/1")

    # Simulates what RDFa extraction hands back when the source HTML
    # double-encodes an email (encodes the leading "&" of "&#105;..." as "&amp;"),
    # so a single HTML-parse pass only strips one layer.
    double_encoded_email = "&#105;&#110;f&#111;&#64;&#112;et&#105;t&#116;h&#101;a&#116;r&#101;.&#111;r&#103;"

    graph << [person, RDF.type, RDF::Vocab::SCHEMA.Person]
    graph << [person, RDF::Vocab::SCHEMA.email, double_encoded_email]

    normalized = Helper.normalize_literals(graph)

    email = normalized.query([person, RDF::Vocab::SCHEMA.email, nil]).objects.first.to_s
    assert_equal "info@petittheatre.org", email,
      "normalize_literals should fully decode HTML entities in literal values"
  end

  # --- skolemization-exclude feature ---------------------------------------

  # Helper: builds a Brantford-style Place blank node whose only per-event
  # difference is schema:url (a different event page each time).
  def build_place_graph(event_url)
    graph = RDF::Graph.new
    place = RDF::Node.new
    graph << [place, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph << [place, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Sanderson Centre for the Performing Arts", language: :en)]
    graph << [place, RDF::Vocab::SCHEMA.telephone, RDF::Literal.new("519-758-8090", language: :en)]
    graph << [place, RDF::Vocab::SCHEMA.sameAs, RDF::URI("http://www.sandersoncentre.ca")]
    graph << [place, RDF::Vocab::SCHEMA.url, RDF::URI(event_url)]
    graph
  end

  def skolemized_place_uri(graph, base_url)
    Helper.skolemize_blank_nodes(graph, base_url)
      .query([nil, RDF.type, RDF::Vocab::SCHEMA.Place]).subjects.first.to_s
  end

  def test_excluded_property_gives_same_uri_across_events
    base_url = "https://brantfordsymphony.ca"
    ENV['SKOLEMIZE_EXCLUDE_CONFIG'] =
      { "http://schema.org/Place" => ["http://schema.org/url"] }.to_json

    uri1 = skolemized_place_uri(
      build_place_graph("https://brantfordsymphony.ca/event/silver-bells/"), base_url)
    uri2 = skolemized_place_uri(
      build_place_graph("https://brantfordsymphony.ca/event/spring-gala/"), base_url)

    assert_equal uri1, uri2,
      "Place appearing on two different events should skolemize to the same URI " \
      "when schema:url is excluded"
  ensure
    ENV.delete('SKOLEMIZE_EXCLUDE_CONFIG')
  end

  def test_without_exclusion_differing_property_gives_different_uris
    base_url = "https://brantfordsymphony.ca"
    ENV.delete('SKOLEMIZE_EXCLUDE_CONFIG')

    uri1 = skolemized_place_uri(
      build_place_graph("https://brantfordsymphony.ca/event/silver-bells/"), base_url)
    uri2 = skolemized_place_uri(
      build_place_graph("https://brantfordsymphony.ca/event/spring-gala/"), base_url)

    refute_equal uri1, uri2,
      "Without exclusion, a differing schema:url should still produce different URIs"
  end

  def test_exclusion_only_applies_to_matching_type
    base_url = "https://brantfordsymphony.ca"
    # Excludes url only for Place, but here the node is an Event.
    ENV['SKOLEMIZE_EXCLUDE_CONFIG'] =
      { "http://schema.org/Place" => ["http://schema.org/url"] }.to_json

    build_event = lambda do |url|
      graph = RDF::Graph.new
      event = RDF::Node.new
      graph << [event, RDF.type, RDF::Vocab::SCHEMA.Event]
      graph << [event, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Concert", language: :en)]
      graph << [event, RDF::Vocab::SCHEMA.url, RDF::URI(url)]
      graph
    end

    uri1 = Helper.skolemize_blank_nodes(build_event.call("https://brantfordsymphony.ca/a"), base_url)
      .query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).subjects.first.to_s
    uri2 = Helper.skolemize_blank_nodes(build_event.call("https://brantfordsymphony.ca/b"), base_url)
      .query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).subjects.first.to_s

    refute_equal uri1, uri2,
      "Exclusion configured for Place must not affect Event skolemization"
  ensure
    ENV.delete('SKOLEMIZE_EXCLUDE_CONFIG')
  end
  
end