require 'minitest/autorun'
require 'linkeddata'

class AddDerivedFromTest < Minitest::Test

  def setup
    @add_derived_from_sparql_file = "./sparql/add_derived_from.sparql"
  end

  def test_add_derived_from
    sparql_file = File.read(@add_derived_from_sparql_file)
    sparql_file = sparql_file.gsub("subject_url", "www.example-uri.com")
    sparql = SPARQL.parse(sparql_file, update: true)
    graph = RDF::Graph.load("./tests/fixtures/test_add_derived_from.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"
    assert_equal(RDF::URI("www.example-uri.com"), graph.query([nil, RDF::URI("http://www.w3.org/ns/prov#wasDerivedFrom"), nil]).each.objects.first)
  end
end
