# The RobotsTxtParser module provides functionality to parse and evaluate
# robots.txt files according to the Robots Exclusion Protocol (REP).
#
# It defines a `Ruleset` class that:
# - Parses a robots.txt file and organizes its directives (User-agent, Allow, Disallow)
#   into a structured set of rules grouped by user agent.
# - Normalizes and escapes rule paths safely, handling both encoded and unencoded inputs.
# - Converts robots.txt wildcard patterns (`*`) and end markers (`$`) into
#   Ruby-compatible regular expressions for matching URLs.
# - Implements user-agent matching logic that follows the "longest match wins" rule.
# - Provides a method (`allowed?`) to determine if a specific URL path is allowed
#   for a given user agent.
#
# Example usage:
#   ruleset = RobotsTxtParser.parse(File.read("robots.txt"))
#   ruleset.allowed?("Googlebot", "/private/page")  # => false
#
# The module is designed to closely follow REP semantics while being resilient to
# malformed or non-standard robots.txt files.
module RobotsTxtParser
  class Ruleset
    attr_reader :rules_by_agent

    def initialize
      @rules_by_agent = {}
    end

    # Parses the contents of a robots.txt file and builds a mapping of crawl rules
    # (Allow/Disallow) for each user agent.
    #
    # This method:
    # - Iterates over each line of the robots.txt content.
    # - Strips comments (starting with '#') and ignores blank lines.
    # - Handles malformed lines where the colon (:) is missing, such as "Disallow /".
    # - Groups consecutive `User-agent` directives together so that multiple agents
    #   can share the same rule set.
    # - Normalizes rule paths (ensuring they start with '/') and safely escapes them.
    # - Converts wildcard patterns (`*`) and end-of-line markers (`$`) into
    #   equivalent Ruby regular expressions for URL matching.
    # - Stores each rule (with type, path, regex, and specificity) under every
    #   applicable user agent in `@rules_by_agent`.
    #
    # Returns `self` to allow method chaining.
    def parse(content)
      current_agents = []
      previous_line_was_agent = false

      content.each_line.with_index do |line, index|
        line = line.split('#', 2).first.strip
        next if line.empty?

        # Handle cases where the colon is missing, e.g. "Disallow /"
        if !line.include?(':')
          if line =~ /^(user-agent|disallow|allow)\s+(.+)$/i
            key = Regexp.last_match(1)
            value = Regexp.last_match(2)
          else
            next # Skip unrecognized or malformed lines
          end
        else
          key, value = line.split(':', 2).map(&:strip)
        end

        next unless key && value # Malformed line

        key = key.downcase

        case key
        when 'user-agent'
          agent_value = value.downcase.split(' ').first
          if previous_line_was_agent
            current_agents << agent_value
          else
            current_agents = [agent_value]
            previous_line_was_agent = true
          end

        when 'allow', 'disallow'
          previous_line_was_agent = false
          next if current_agents.empty? || value.nil? || value.empty?

          type = key.to_sym
          raw = safe_escape(value)

          raw = "/#{raw}" unless raw.start_with?('/')

          escaped = Regexp.escape(raw)
          regex_str = "^" + escaped.gsub('\\*', '.*').gsub('\\$', '\\z')
          begin
            regex = Regexp.new(regex_str)
          rescue RegexpError
            regex = Regexp.new("^" + Regexp.escape(raw))
          end

          specificity = raw.length

          rule = {
            type: type,
            path: raw,
            path_length: specificity,
            regex: regex
          }

          current_agents.each do |agent|
            @rules_by_agent[agent] ||= []
            @rules_by_agent[agent] << rule
          end

        else
          # Ignore unknown directives (e.g., Crawl-delay, Sitemap)
        end
      end
      self
    end

    # Safely escapes a path or URL segment for use in robots.txt rules.
    #
    # This method checks whether the input already contains percent-encoded
    # sequences (e.g., "%E3%83%84"). If so, it returns the value unchanged to
    # avoid double-encoding. Otherwise, it applies URI escaping using Ruby’s
    # default URI parser to ensure the value is properly encoded.
    #
    # Example:
    #   safe_escape("/foo/bar/ツ")     # => "/foo/bar/%E3%83%84"
    #   safe_escape("/foo/%E3%83%84")  # => "/foo/%E3%83%84" (unchanged)
    private
    def safe_escape(value)
      if value.match?(/%[0-9A-Fa-f]{2}/)
        value
      else
        URI::DEFAULT_PARSER.escape(value)
      end
    end

    # Finds the most specific group of crawl rules that applies to the given user agent.
    #
    # This method selects the best-matching user-agent group based on the longest
    # substring match between the given `user_agent` and the keys stored in
    # `@rules_by_agent`.
    #
    # Matching logic:
    # - Comparison is case-insensitive.
    # - The wildcard group `*` acts as a default fallback if no specific match is found.
    # - The "best" group is the one with the longest key that is contained within
    #   the provided `user_agent`.
    #
    # Returns an array of rules (Allow/Disallow) for the best-matching user agent.
    private
    def find_best_group(user_agent)
      agent_to_match = user_agent.downcase

      best_group_key = '*'
      max_key_length = 1 

      @rules_by_agent.each_key do |key|
        next if key == '*'
        
        if key.include?(agent_to_match) && key.length > max_key_length
          max_key_length = key.length
          best_group_key = key
        end
      end
      
      return @rules_by_agent.fetch(best_group_key, [])
    end

    # Determines whether a given path is allowed to be crawled by a specific user agent.
    #
    # This method applies the robots.txt "longest match wins" rule:
    # - Finds the most relevant set of rules for the given `user_agent` using `find_best_group`.
    # - Normalizes the input path to ensure it starts with a '/'.
    # - Iterates through all rules and finds the one whose pattern (regex) matches
    #   the path with the greatest length (most specific match).
    # - In case of a tie (two rules of equal length), an `Allow` rule takes precedence
    #   over a `Disallow` rule.
    # - If no rules match, access is allowed by default.
    #
    # Returns:
    # - `true`  if the path is allowed.
    # - `false` if the path is disallowed.
    public
    def allowed?(user_agent, path)
      rules = find_best_group(user_agent)
      return true if rules.empty?

      normalized_path = path
      normalized_path = "/#{normalized_path}" unless normalized_path.start_with?('/')

      best_match = nil
      max_length = -1

      rules.each do |rule|
        if rule[:regex].match?(normalized_path)
          rule_length = rule[:path_length]

          if rule_length > max_length
            max_length = rule_length
            best_match = rule
          elsif rule_length == max_length
            if rule[:type] == :allow
              best_match = rule
            end
          end
        end
      end

      return true unless best_match

      best_match[:type] == :allow
    end
  end

  def self.parse(content)
    Ruleset.new.parse(content)
  end
end