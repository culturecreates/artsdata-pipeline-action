require 'minitest/autorun'
require 'linkeddata'

class ReplaceBlankNodesTest < Minitest::Test

  def setup
    @replace_blank_nodes_sparql_file = "./sparql/replace_blank_nodes.sparql"
  end

  # check that the blank node is replaced
  def test_blank_node_replaced
    sparql = SPARQL.parse(File.read(@replace_blank_nodes_sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_blank_nodes.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"
    assert_equal false, graph.query([nil, RDF::type, RDF::URI("http://schema.org/Thing")]).first_subject.node?
    assert_equal true, graph.query([nil, RDF::type, RDF::URI("http://schema.org/Thing")]).first_subject.uri?
  end

end
