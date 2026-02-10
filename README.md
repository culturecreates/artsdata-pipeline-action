# artsdata-pipeline-action
Action to manage the data pipeline for Artsdata.

Use this Github action from your Github project repo with mode `push` to send your data to the Artsdata databus. Use the mode `fetch-push` to first crawl a website, extract strucutred data, and then push to Artsdata.

Example file to add to your repo .github/workflows/mydata.yml
```
name: My data

on:
  workflow_dispatch:

jobs:
  artsdata-pipeline:
    runs-on: ubuntu-latest
    steps:
      - name: Action setup
        uses: culturecreates/artsdata-pipeline-action@v3
        with:
          mode: "fetch-test"
          artifact: "my-artifact-name"
          publisher: "http://my-publisher-uri"
          page-url: "https://website-to-crawl"
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Usage 

To use this action, add the following YAML configuration to your GitHub Actions workflow file:

```yml
artsdata-pipeline:
  runs-on: ubuntu-latest
  needs: fetch-and-commit-data
  steps:
    - name: Action setup
      uses: culturecreates/artsdata-pipeline-action@v3
      with:
        mode: 
        page-url:
        entity-identifier:
        downloadFile:
        downloadUrl:
        is-paginated:
        headless:
        artifact:
        token:
        publisher:
        comment:
        group:
        version:
        report-callback-url:
        shacl:
        fetch-urls-headlessly:
        offset:
        custom-user-agent:
        custum-databus-url:
        html-extract-config:
        register-only:
        cloudflare-private-key:
```

<br>

To run locally

1. ``` cp sample.config.yml config.yml ``` 
2. Update config.yml to provide inputs mentioned [here.](https://github.com/culturecreates/artsdata-pipeline-action/tree/v3.7.1?tab=readme-ov-file#inputs)
3. ``` bundle install ```
4. ``` bundle exec ruby src/main.rb config.yml ```

Note: Ferrum gem requires Xvfb (X virtual framebuffer) to run headless browser sessions. On macOS, Xvfb is not available by default. To resolve this on macOS, you should install XQuartz, which provides X11 support (including Xvfb-like functionality): `brew install --cask xquartz`

## Inputs
### All modes

| Name                                  | Description      |
| ------------------------------------- | -------------------------- |
| `artifact`                         | **required**: Name of the artifact. When fetching data, the artifact is used in the filename, and when data is pushed to Artsdata, the artifact is the last part of the graph URI. Example: `http://kg.artsdata.ca/account/group/artifact`
| `mode`                             | Mode to run the workflow in. MUST be one of `fetch \| fetch-test \| push \| fetch-push`. Defaults to `push`.  
| `downloadFile`                      | Optional filename override with extension and path. When using fetch and fetch-push modes, the data will be saved to the Github repo calling the action. If not provided, it will be set to `output/[artifact].jsonld`.
| `report-callback-url`               | Optional URL to send back the data validation report asynchronously using POST "Content-Type: application/json". 

### Fetch mode (including fetch-push)

| Name                                  | Description      |
| ------------------------------------- | -------------------------- |
| `page-url`                          | **required**: URL of the page to crawl (required for fetch and fetch-push modes).
| `token`                             | **required**: Constant. Must be set to `${{ secrets.GITHUB_TOKEN }}`. [Automatic GitHub token](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token) generated with each run of the workflow. Needed for the action to save the crawled data to your repo.
| `entity-identifier`                 | Identifier of the entity to fetch URL, defaults to spider mode if not provided.
| `headless`                          | Whether to run in headless mode (optional, defaults to false).
| `fetch-urls-headlessly`             | Fetch the URLs of entities using a headless browser(optional, defaults to false).
| `is-paginated`                      | Whether the page is paginated (optional, defaults to false).
| `offset`                            | Offset for pagination strategy (optinal, defaults to 1).
| `custom-user-agent`                 | custom-user-agent for the http requests (optional, defaults to artsdata-crawler)
| `html-extract-config`               | custom xpath-config to fetch additional_data. 
| `cloudflare-private-key`            | Ed25519 private key in PEM format for signing HTTP requests to identify the Artsdata bot to Cloudflare-protected sites. Should be stored as an organization or repository secret. (optional)


html-extract-config format: 

    { 
      "entity_type": "type of entity you want to add additional info to, example "http://schema.org/Event", 
      "extract": { 
        "xpath" : "xpath expression, example ://div[@class=\"um-name\"]", 
        "css": "css expression, example: div.um-name", either css or xpath is required.
        "isArray": "set as true if the object should be an array, default is false",
        "isUri": "set as true if the object should be a URI, default is false",
        "transform": {
          "function": "function_name", eg : split (this is the only function currently available)
          "args": "arguments" eg : [","]
        }
      } 
    }

### Push mode (including fetch-push)

| Name                                  | Description         |
| ------------------------------------- | -------------------------- |
| `publisher`                         | **required**: URI of the publisher. This must be a URI registered with one of the [Artsdata Databus team](https://github.com/orgs/artsdata-stewards/teams/databus/teams) accounts. If you are on a team you can use the format `https://https://github.com/{{your_github_handle}}#this`
| `downloadUrl`                       | URL of the file to download. Default is set to `https://[current repo raw path]/output/[artifact].jsonld`.
| `group`                             | Group of artifacts/versions. Use unreserved characters. (If not provided, group will be set as your repository name).
| `version`                           | Version of the artifact. Usually a date (e.g. 2020-10-23). Use unreserved characters. (If not provided, version will be set as the current date-time).
| `comment`                           | Comment about the artifact push (optional, default - url of the workflow YAML file.)
| `shacl`                             | URL to the SHACL file to perform validations (optional)
| `custom-databus-url`                | Custom databus URL to push the data to (optional, default - http://api.artsdata.ca/databus/)
| `register-only`                     | Set as true to push to artsdata in register only


<br>

## Test Mode

Test mode can be activated by setting the mode as `fetch-test` which limits the maximum URLs that can be crawled to 5 and does not save the data. Useful if you are experimenting with the entity-identifier input. 

## Spider Crawler

The spider crawler kicks in when the entity identifier is not provided. The system starts from the base url and works its way up to find relevant event, place, organization and person data. 

### Pseudo Code for spider

1. Initialize
    - Set an initial score for the base URL.
    - Create an empty graph and an empty priority queue for discovered URLs.

2. Robots.txt Handling
    - Check if robots.txt exists for the base domain.
    - If it exists, parse and extract:
        - Allowed and disallowed paths per user-agent
        - Sitemap URLs
        - Crawl rules relevant to the configured user-agent

    - If it does not exist, assume all paths are allowed.

3. Identify Starting Sitemap
    - Determine initial sitemap source:
        - Use sitemap URLs found in robots.txt, or
        - Use default location: base_url/sitemap.xml

4. Crawl Sitemap
    - Extract URLs from the sitemap.
    - For each discovered URL:
        - Validate the URL using allowed/disallowed paths and exclusion keywords.
        - Load and parse linked data found on the page.
        - Apply SPARQL transformations and insert results into the main RDF graph.
        - Compute URL score based on:
            1. Graph score - derived from counts of Events, Organizations, Places, and People
            2. URL score - based on scoring terms in configuration
            3. Sitemap bonus - if URL came from a sitemap
        - Add the URL to the priority queue (sorted by score).

5. Queue-Driven Crawl
    - Continuously dequeue the highest-scored URL.
    - Repeat the URL processing steps (validation, loading, scoring, graph merge).
    - Stop when:
        1. Maximum crawl URL limit is reached, or
        2. The queue becomes empty.

6. Fallback Crawl
    - After sitemap-based crawling completes, repeat the queue process starting directly from the base URL.

7. Graph Optimization
    - Reduce / trim the graph data based on configured maximum counts for Events, Organizations, Places, and People.

8. Finalize Output
    - Push the resulting optimized graph to the Databus.

### Robots.txt parsing

RobotsTxtParser parses and evaluates robots.txt files according to the Robots Exclusion Protocol (REP). 

It defines a `RobotsTxt` class that:
- Parses a robots.txt file and organizes its directives (User-agent, Allow, Disallow, Sitemap)
  into a structured set of rules grouped by user agent.
- Normalizes and escapes rule paths safely, handling both encoded and unencoded inputs.
- Converts robots.txt wildcard patterns (`*`) and end markers (`$`) into
  Ruby-compatible regular expressions for matching URLs.
- Implements user-agent matching logic that follows the "longest match wins" rule.
- Provides a method `parse` which parses the contents of a robots.txt file and builds a mapping of crawl rules (Allow/Disallow) for each user agent and fetches the common sitemap URLs.
- Provides a method `allowed?` to determine if a specific URL path is allowed
  for a given user agent.
- Rules applied:
    - Uses the longest matching rule wins principle.
    - If two rules match with equal length, Allow overrides Disallow.
    - If no rules match, the path is allowed by default.
    
## Potential Issues

Remember to use only unreserved characters ([0-9a-zA-Z-._]) for input variables where mentioned.

# Release Instructions
Follow these instructions to make a new release.

## Steps
1. Run tests with `rake` and ensure all pass
2. Update file `action.yml` with the new version vX.X.X
3. Commit changes
4. Create a new Github **release** with the new version tag vX.X.X

Creating and saving a new release will run a workflow to build the assets and set a floating tag with the major release version. All workflows using this action will run the latest major release.

**CAUTION: when drafting a new release, ensure that the Docker image version specified in action.yml matches the release version**



## Semantic Versioning
When preparing a release for the artsdata-pipeline-action, please follow the semantic versioning guidelines.

### Minor release (e.g., 2.0.7 → 2.0.8): 

For small feature additions or bug fixes.

### Major release (e.g., 2.0.7 → 2.1.0): 

For larger changes or significant improvements that could impact compatibility.

### Significant Update (e.g., 2.0.7 → 3.0.0): 

For major overhauls or breaking changes. If there's a drastic change in functionality or usage, increment to the next "big update" version.


## Cloudflare Bot Protection
Some websites use Cloudflare to block automated crawlers. The Artsdata pipeline supports HTTP Message Signatures (RFC 9421) to identify itself as a legitimate bot to Cloudflare-protected sites.

### Setup

1. **Store your Ed25519 private key as a GitHub secret:**
   - Organization level (recommended): Settings → Secrets and variables → Actions → New organization secret
   - Secret name: `CLOUDFLARE_PRIVATE_KEY`
   - Value: Your Ed25519 private key in PEM format
   - You need to paste it **with 4 spaces before every line and NO tabs:**

2. **Use in your workflow:**
```yaml
- name: Crawl Cloudflare-protected site
  uses: culturecreates/artsdata-pipeline-action@v3
  with:
    mode: 'fetch-push'
    page-url: 'https://example.com'
    cloudflare-private-key: ${{ secrets.CLOUDFLARE_PRIVATE_KEY }}
```



The crawler will automatically sign all HTTP requests with your private key, allowing Cloudflare to verify the bot's identity.
