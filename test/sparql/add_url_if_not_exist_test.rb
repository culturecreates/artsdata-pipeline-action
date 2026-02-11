require 'minitest/autorun'
require 'linkeddata'

class AddUrlIfNotExistTest < Minitest::Test

  def setup
    @add_url_sparql_file = "./sparql/add_url_if_not_exist.sparql"
    sparql_file = File.read(@add_url_sparql_file)
    sparql_file = sparql_file.gsub("subject_url", "http://www.example-url.com")
    @sparql = SPARQL.parse(sparql_file, update: true)
    @graph = RDF::Graph.load("./test/fixtures/test_add_url.jsonld")
  end

  def test_add_url
    @graph.query(@sparql)
    result = @graph.query([nil, RDF::Vocab::SCHEMA.url, nil]).first.object
    assert result.valid?
    assert_equal RDF::URI("http://www.example-url.com"),result
  end

  def test_do_not_add_url_if_exists
    @graph << [RDF::URI("http://event.com/1"), RDF::Vocab::SCHEMA.url, RDF::URI("http://www.example-url.com")]
    @graph.query(@sparql)
    result = @graph.query([nil, RDF::Vocab::SCHEMA.url, nil]).first.object
    assert_equal RDF::URI("http://www.example-url.com"),result
  end

  def test_do_not_add_url_if_not_event
    @graph.delete([RDF::URI("http://event.com/1"), RDF.type, RDF::Vocab::SCHEMA.Event]) 
    @graph << [RDF::URI("http://event.com/1"),  RDF.type, RDF::Vocab::SCHEMA.Person]
    @graph.query(@sparql)
    result = @graph.query([nil, RDF::Vocab::SCHEMA.url, nil])
    assert_equal 0, result.count
  end

  def test_add_url_if_music_event
    @graph.delete([RDF::URI("http://event.com/1"), RDF.type, RDF::Vocab::SCHEMA.Event])
    @graph << [RDF::URI("http://event.com/1"),  RDF.type, RDF::Vocab::SCHEMA.MusicEvent]
    @graph.query(@sparql)
    result = @graph.query([nil, RDF::Vocab::SCHEMA.url, nil]).first.object
    assert_equal RDF::URI("http://www.example-url.com"),result
  end

end
