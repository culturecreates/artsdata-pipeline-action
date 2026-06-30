require 'minitest/autorun'
require_relative '../../src/lib/helper'
require 'rdf'
require 'digest'

class SkolemizeBlankNodesTest < Minitest::Test

  BASE_URL = 'https://example.org'

  def setup
    @graph = RDF::Graph.new

    @event   = RDF::Node.new('event1')
    @place   = RDF::Node.new('place1') # blank node with NO outgoing triples

    # _:event1 schema:name "Concert"
    @graph << [@event, RDF::Vocab::SCHEMA.name, RDF::Literal.new('Concert')]

    # _:event1 schema:location _:place1
    # NOTE: _:place1 has no further triples of its own (empty blank node)
    @graph << [@event, RDF::Vocab::SCHEMA.location, @place]
  end

  # FAILS before fix: location object becomes "genid/" (empty hash)
  # PASSES after fix: location object becomes a valid "genid/<hash>" URI
  def test_blank_node_with_no_outgoing_triples_gets_valid_genid_uri
    skolemized = Helper.skolemize_blank_nodes(@graph, BASE_URL)

    location_statement = skolemized.query(
      [nil, RDF::Vocab::SCHEMA.location, nil]
    ).first

    refute_nil location_statement, 'Expected a schema:location statement in skolemized graph'

    location_uri = location_statement.object

    assert_instance_of RDF::URI, location_uri,
      'Expected schema:location object to be skolemized into an RDF::URI'

    refute_equal "#{BASE_URL}/genid/", location_uri.to_s,
      'schema:location object has an empty genid hash (blank node was never skolemized)'

    assert_match(/\A#{Regexp.escape(BASE_URL)}\/genid\/[0-9a-f]{16}\z/, location_uri.to_s,
      'Expected schema:location object to be a genid/<16-hex-char> URI')
  end

  # Sanity check: a blank node WITH outgoing triples still skolemizes correctly
  def test_blank_node_with_outgoing_triples_gets_valid_genid_uri
    @graph << [@place, RDF::Vocab::SCHEMA.name, RDF::Literal.new('Concert Hall')]

    skolemized = Helper.skolemize_blank_nodes(@graph, BASE_URL)

    location_statement = skolemized.query(
      [nil, RDF::Vocab::SCHEMA.location, nil]
    ).first

    location_uri = location_statement.object

    assert_instance_of RDF::URI, location_uri
    assert_match(/\A#{Regexp.escape(BASE_URL)}\/genid\/[0-9a-f]{16}\z/, location_uri.to_s)

    # the skolemized place node should itself have its schema:name triple
    name_statement = skolemized.query(
      [location_uri, RDF::Vocab::SCHEMA.name, nil]
    ).first

    refute_nil name_statement
    assert_equal 'Concert Hall', name_statement.object.to_s
  end

  # Two distinct empty blank nodes must not collapse onto the SAME genid URI
  def test_two_distinct_empty_blank_nodes_get_distinct_genid_uris
    event2 = RDF::Node.new('event2')
    place2 = RDF::Node.new('place2') # also empty, distinct node

    @graph << [event2, RDF::Vocab::SCHEMA.name, RDF::Literal.new('Play')]
    @graph << [event2, RDF::Vocab::SCHEMA.location, place2]

    skolemized = Helper.skolemize_blank_nodes(@graph, BASE_URL)

    location_uris = skolemized.query(
      [nil, RDF::Vocab::SCHEMA.location, nil]
    ).map(&:object).map(&:to_s)

    assert_equal 2, location_uris.uniq.size,
      'Expected the two distinct empty blank nodes to skolemize to different genid URIs'

    location_uris.each do |uri|
      assert_match(/\A#{Regexp.escape(BASE_URL)}\/genid\/[0-9a-f]{16}\z/, uri)
    end
  end
end