module EntityFetcherHelper
  def self.create_url_identifier_mapping(page_url, entity_identifier)
    raise ArgumentError, "page_url must be an array" unless page_url.is_a?(Array)
    raise ArgumentError, "entity_identifier must be an array" unless entity_identifier.is_a?(Array)
    raise ArgumentError, "entity_identifier length must be 1 or match the length of page_url" unless entity_identifier.length == 1 || entity_identifier.length == page_url.length
  
    mapping = {}
  
    if entity_identifier.length == 1
      page_url.each { |url| mapping[url] = entity_identifier.first }
    else
      page_url.each_with_index { |url, index| mapping[url] = entity_identifier[index] }
    end
  
    mapping
  end

  def self.get_page_number(is_paginated)
    case is_paginated
    when 'false'
      nil
    when 'true'
      1
    else
      is_paginated.to_i
    end
  end

  def self.get_offset(offset)
    offset ? offset.to_i : 1
  end

end