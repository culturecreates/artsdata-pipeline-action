require 'minitest/autorun'
require 'rdf'
require 'linkeddata'
require 'digest'
require_relative '../../src/lib/helper'
require_relative '../../src/config/spider_config'

class TopLevelSkolemizationTest < Minitest::Test

  def test_top_level_blank_nodes_get_deterministic_uri_after_pipeline
    base_url = "https://thecultch.com"
    link = "https://thecultch.com/events/show-page"

    # Simulate RDFa extraction: event as top-level blank node
    graph = RDF::Graph.new
    event = RDF::Node.new    # Top-level blank node
    location = RDF::Node.new # Nested blank node (pointed to by event)

    graph << [event, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph << [event, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Test Show", language: :en)]
    graph << [event, RDF::Vocab::SCHEMA.startDate, RDF::Literal.new("2026-05-25T19:30:00")]
    graph << [event, RDF::Vocab::SCHEMA.location, location]
    graph << [location, RDF.type, RDF::Vocab::SCHEMA.Place]
    graph << [location, RDF::Vocab::SCHEMA.name, "The Cultch"]

    # Run the full transform pipeline
    transformed = Helper.transform_event_graph(graph, link, base_url)

    event_uri = transformed.query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).subjects.first

    # Should not be a blank node
    refute event_uri.node?, "Event should have a URI not a blank node"

    # Should NOT be temporary (current broken behaviour)
    refute event_uri.to_s.include?("temporary"),
      "Event URI should not be temporary, got: #{event_uri}"

    # Should be a deterministic genid URI (new expected behaviour)
    assert event_uri.to_s.include?("/genid/"),
      "Event URI should be a deterministic genid URI, got: #{event_uri}"
  end

  def test_same_top_level_blank_node_data_gives_same_uri_across_two_crawls
    base_url = "https://thecultch.com"
    link = "https://thecultch.com/events/show-page"

    # Crawl 1
    graph1 = RDF::Graph.new
    event1 = RDF::Node.new
    graph1 << [event1, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph1 << [event1, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Test Show", language: :en)]
    graph1 << [event1, RDF::Vocab::SCHEMA.startDate, RDF::Literal.new("2026-05-25T19:30:00")]

    # Crawl 2: same data, different blank node object
    graph2 = RDF::Graph.new
    event2 = RDF::Node.new
    graph2 << [event2, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph2 << [event2, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Test Show", language: :en)]
    graph2 << [event2, RDF::Vocab::SCHEMA.startDate, RDF::Literal.new("2026-05-25T19:30:00")]

    transformed1 = Helper.transform_event_graph(graph1, link, base_url)
    transformed2 = Helper.transform_event_graph(graph2, link, base_url)

    uri1 = transformed1.query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).subjects.first
    uri2 = transformed2.query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).subjects.first

    # KEY TEST: Same data across two crawls must give same URI
    assert_equal uri1, uri2,
      "Same event data across two crawls should produce same URI (no more random temporary UUIDs)"
  end

  def test_top_level_non_event_blank_node_also_gets_deterministic_uri
    base_url = "https://thecultch.com"
    link = "https://thecultch.com/about"

    # A top-level Person blank node (not an event)
    graph = RDF::Graph.new
    person = RDF::Node.new  # Top-level blank node
    graph << [person, RDF.type, RDF::Vocab::SCHEMA.Person]
    graph << [person, RDF::Vocab::SCHEMA.name, "John Doe"]

    transformed = Helper.transform_event_graph(graph, link, base_url)

    person_uri = transformed.query([nil, RDF.type, RDF::Vocab::SCHEMA.Person]).subjects.first

    refute person_uri.node?, "Person should have a URI not a blank node"
    refute person_uri.to_s.include?("temporary"),
      "Person URI should not be temporary"
    assert person_uri.to_s.include?("/genid/"),
      "Person URI should be a deterministic genid URI"
  end

  def test_existing_uri_not_changed_by_pipeline
    base_url = "https://thecultch.com"
    link = "https://thecultch.com/events/show-123"

    # Event already has a proper URI in the HTML
    graph = RDF::Graph.new
    event = RDF::URI("https://thecultch.com/events/show-123")
    graph << [event, RDF.type, RDF::Vocab::SCHEMA.Event]
    graph << [event, RDF::Vocab::SCHEMA.name, RDF::Literal.new("Show With URI", language: :en)]

    transformed = Helper.transform_event_graph(graph, link, base_url)

    event_uri = transformed.query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).subjects.first

    assert_equal "https://thecultch.com/events/show-123", event_uri.to_s,
      "Event with existing URI should not be changed"
  end
end