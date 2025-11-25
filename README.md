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
          token: "${{ secrets.GITHUB_TOKEN }}"
```

## Usage 

To use this action, add the following YAML configuration to your GitHub Actions workflow file:

```yml
artsdata-pipeline:
  runs-on: ubuntu-latest
  needs: fetch-and-commit-data
  steps:
    - name: Action setup
      uses: culturecreates/artsdata-pipeline-action@v1.1.0
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
```

<br>

## Inputs
### All modes

| Name                                  | Description      |
| ------------------------------------- | -------------------------- |
| `mode`                             | **required**: Mode to run the workflow in. MUST be one of `fetch \| fetch-test \| push \| fetch-push`. Defaults to `push`.  
| `artifact`                         | **required**: Name of the artifact (required for push and fetch-push modes).
| `downloadFile`                      | Optional filename override with extension and path. When using fetch and fetch-push modes, the data will be saved to the Github repo calling the action. If not provided, it will be set to `output/[artifact].jsonld`.
| `report-callback-url`               | Optional URL to send back the data validation report asynchronously using POST "Content-Type: application/json". 

### Fetch mode (including fetch-push)

| Name                                  | Description      |
| ------------------------------------- | -------------------------- |
| `page-url`                          | **required**: URL of the page to crawl (required for fetch and fetch-push modes).
| `entity-identifier`                 | Identifier of the entity to fetch URL, defaults to spider mode if not provided.
| `token`                             | **required**: GitHub token (required for fetch and fetch-push modes, secret).
| `headless`                          | Whether to run in headless mode (optional, defaults to false).
| `fetch-urls-headlessly`             | Fetch the URLs of entities using a headless browser(optional, defaults to false).
| `is-paginated`                      | Whether the page is paginated (optional, defaults to false).
| `offset`                            | Offset for pagination strategy (optinal, defaults to 1).
| `custom-user-agent`                 | custom-user-agent for the http requests (optional, defaults to artsdata-crawler)
| `html-extract-config`               | custom xpath-config to fetch additional_data. 

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
| `publisher`                         | **required**: URI of the publisher (required for push and fetch-push modes).
| `downloadUrl`                       | **required**: URL of the file to download (required for push mode).
| `group`                             | Group of artifacts/versions. Use unreserved characters. (If not provided, group will be set as your repository name).
| `version`                           | Version of the artifact. Usually a date (e.g., 2020-10-23). Use unreserved characters. (If not provided, version will be set as the current date).
| `comment`                           | Comment about the artifact push (optional)
| `shacl`                             | URL to the SHACL file to perform validations (optional)
| `custom-databus-url`                | Custom databus URL to push the data to (optional, default - http://api.artsdata.ca/databus/)


<br>

## Potential Issues

Remember to use only unreserved characters ([0-9a-zA-Z-._]) for input variables where mentioned.

# Release Instructions
Follow these instructions to make a new release.

## Steps
1. Run tests with `> rake` and ensure all pass
2. Update file `action.yml` with the new version vX.X.X (2 different places in file)
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


