module Config
  SPIDER_CRAWLER = {
    max_pages_to_crawl: 1000, # the crawl will stop when this number of pages have been visited
    default_max_depth: 5, # the maximum depth to crawl from the starting URLs
    starting_url_initial_score: 10, # initial score assigned to starting URLs and sitemaps
    max_event_count: 200, # maximum number of events to retain after crawling
    max_url_length: 100, # maximum length of URL to consider for crawling
    max_forward_slashes: 7, # maximum number of forward slashes in URL to consider for crawling
    max_query_params: 1, # maximum number of query parameters in URL to consider for crawling
    url_contains_score_weight: 3, # score weight for each occurrence of scoring terms in URL
    url_ends_score_weight: 5, # score weight if URL ends with any scoring term
    sitemap_bonus_score: 5 # bonus score for URLs identified as sitemaps
  }.freeze
end
