require 'minitest/autorun'
require 'linkeddata'

class RemoveObjectTest < Minitest::Test
  def setup
    @remove_object_sparql_file = "./sparql/remove_objects.sparql"
  end

  def test_remove_object
    sparql = SPARQL.parse(File.read(@remove_object_sparql_file), update: true)
    graph = RDF::Graph.load("./tests/fixtures/test_remove_object.jsonld")
    
    graph.query(sparql)

    assert_equal(4, graph.count, "The graph should have few triples after the SPARQL update.")
    assert graph.has_statement?(RDF::Statement.new(RDF::URI("https://keep.com"), RDF::Vocab::SCHEMA.name, "Keep event with id"))
    assert !graph.has_statement?(RDF::Statement.new(RDF::URI("https://agoradanse.com/evenement/montreal-marrakech/#panel-choregraphe-accordeon0"), RDF::URI("http://www.w3.org/ns/prov#wasDerivedFrom"), RDF::URI("https://agoradanse.com/evenement/montreal-marrakech/"))),  "Should not keep wasDerivedFrom statement"
  end

  

end