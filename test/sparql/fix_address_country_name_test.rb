require 'minitest/autorun'
require 'linkeddata'

class FixAddressCountryNameTest < Minitest::Test

  def setup
    @fix_address_country_sparql_file = "./sparql/fix_address_country_name.sparql"
  end

  def test_address_country_name
    sparql = SPARQL.parse(File.read(@fix_address_country_sparql_file), update: true)
    graph = RDF::Graph.load("./test/fixtures/test_fix_address_country_name.jsonld")
    # puts "before: #{graph.dump(:jsonld)}"
    graph.query(sparql)
    # puts "after: #{graph.dump(:jsonld)}"
    assert_equal(RDF::Literal("Canada"), graph.query([nil, RDF::URI("http://schema.org/addressCountry"), nil]).each.objects.first)
  end
end
