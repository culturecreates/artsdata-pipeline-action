module Config
  SPIDER_CRAWLER = {
    max_pages_to_crawl: 1000, # the crawl will stop when this number of pages have been visited
    default_max_depth: 5, # the maximum depth to crawl from the starting URLs
    starting_url_initial_score: 10, # initial score assigned to starting URLs and sitemaps
    max_event_count: 200, # maximum number of events to retain after crawling
    max_organization_count: 300, # maximum number of organizations to retain after crawling
    max_place_count: 400, # maximum number of places to retain after crawling
    max_person_count: 300, # maximum number of persons to retain after crawling
    max_url_length: 100, # maximum length of URL to consider for crawling
    max_forward_slashes: 7, # maximum number of forward slashes in URL to consider for crawling
    max_query_params: 1, # maximum number of query parameters in URL to consider for crawling
    url_contains_score_weight: 3, # score weight for each occurrence of scoring terms in URL
    url_ends_score_weight: 5, # score weight if URL ends with any scoring term
    sitemap_bonus_score: 5, # bonus score for URLs identified as sitemaps
    place_types: [
      RDF::Vocab::SCHEMA.Place, 
      RDF::Vocab::SCHEMA.PerformingArtsTheater, 
      RDF::Vocab::SCHEMA.MusicVenue, 
      RDF::Vocab::SCHEMA.CivicStructure, 
      RDF::Vocab::SCHEMA.MovieTheater
    ],
    organization_types: [
      RDF::Vocab::SCHEMA.Organization,
      RDF::Vocab::SCHEMA.LocalBusiness,     # All types of data the crawler considers worth retaining
    ],
    person_types: [
      RDF::Vocab::SCHEMA.Person
    ],
    event_types: [
      RDF::Vocab::SCHEMA.Event,
      RDF::Vocab::SCHEMA.TheaterEvent,
      RDF::Vocab::SCHEMA.MusicEvent,
      RDF::Vocab::SCHEMA.Festival
    ],
    scoring_terms: [
      'sitemap', 'calendar', 'calendrier',
      'event', 'events', 'evenement',
      'evenements', 'spectacle', 'spectacles',
      'exposition', 'season', 'members',
      'performance', 'performances', 'programmation',   # scoring terms for URL evaluation
      'programme', 'ticket', 'tickets',
      'billet', 'billets', 'designer',
      'entertainment', 'divertissement'
    ],
    exclusion_terms: [
      'mailto', 'timestamp'                            # exclusion terms for URL filtering 
    ]


  }.freeze
end
