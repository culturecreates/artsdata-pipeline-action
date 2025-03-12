module EntityFetcherHelper
  def self.create_url_identifier_mapping(page_url, entity_identifier)
    raise ArgumentError, "page_url must be an array" unless page_url.is_a?(Array)
  
    mapping = {}
    page_url.each { |url| mapping[url] = entity_identifier }
  
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