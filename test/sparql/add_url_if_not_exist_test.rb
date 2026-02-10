require 'minitest/autorun'
require 'linkeddata'

class AddUrlIfNotExistTest < Minitest::Test

  def setup
    @add_url_sparql_file = "./sparql/add_url_if_not_exist.sparql"
  end

  def test_add_url
    sparql_file = File.read(@add_url_sparql_file)
    sparql_file = sparql_file.gsub("subject_url", "www.example-url.com")
    sparql = SPARQL.parse(sparql_file, update: true)
    graph = RDF::Graph.load("./test/fixtures/test_add_url.jsonld")
    graph.query(sparql)
    assert_equal(RDF::URI("www.example-url.com"),
                 graph.query([nil, RDF::Vocab::SCHEMA.url, nil]).each.objects.first)
  end

  def test_do_not_url_if_exists
    sparql_file = File.read(@add_url_sparql_file)
    sparql_file = sparql_file.gsub("subject_url", "www.example-new-url.com")
    sparql = SPARQL.parse(sparql_file, update: true)
    graph = RDF::Graph.load("./test/fixtures/test_event_with_url.jsonld")
    graph.query(sparql)
    assert_equal(RDF::URI("http://www.example-url.com"),
                 graph.query([nil, RDF::Vocab::SCHEMA.url, nil]).each.objects.first)
  end

end
