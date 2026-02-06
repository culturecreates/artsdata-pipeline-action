require 'minitest/autorun'
require 'linkeddata'

class AddUrlTest < Minitest::Test

  def setup
    @add_url_sparql_file = "./sparql/add_url_if_not_exist.sparql"
  end

  def test_add_url
    sparql_file = File.read(@add_url_sparql_file)
    sparql_file = sparql_file.gsub("subject_url", "www.example-uri.com")
    sparql = SPARQL.parse(sparql_file, update: true)
    graph = RDF::Graph.load("./test/fixtures/test_add_url.jsonld")
    puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    puts "after: #{graph.dump(:jsonld)}"
    assert_equal(RDF::URI("www.example-uri.com"),
                 graph.query([nil, RDF::URI("http://schema.org/url"), nil]).each.objects.first)
  end
end
