# artsdata-pipeline-action
Action to manage the data pipeline for Artsdata

## Usage 

To use this action, add the following YAML configuration to your GitHub Actions workflow file (workflow.yml):

```yml
artsdata-push:
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
```

<br>

## Inputs
### All modes

| Name                                  | Description      |
| ------------------------------------- | -------------------------- |
| `mode`                             | **required**: Mode to run the workflow in. MUST be one of `fetch \| push \| fetch-push`. Defaults to `push`.  
| `artifact`                         | **required**: Name of the artifact (required for push and fetch-push modes).
| `downloadFile`                      | Optional filename override with extension and path. When using fetch and fetch-push modes, the data will be saved to the Github repo calling the action. If not provided, it will be set to `output/[artifact].jsonld`.
| `report-callback-url`               | Optional URL to send back the data validation report asynchronously using POST "Content-Type: application/json". 

### Fetch mode (including fetch-push)

| Name                                  | Description      |
| ------------------------------------- | -------------------------- |
| `page-url`                          | **required**: URL of the page to crawl (required for fetch and fetch-push modes).
| `entity-identifier`               | **required**: Identifier of the entity (required for fetch and fetch-push modes).
| `token`                             | **required**: GitHub token (required for fetch and fetch-push modes, secret).
| `headless`                          | Whether to run in headless mode (optional, defaults to false).
| `fetch-urls-headlessly`             | Fetch the URLs of entities using a headless browser(optional, defaults to false).
| `is-paginated`                      | Whether the page is paginated (optional, defaults to false).
| `offset`                            | Offset for pagination strategy (optinal, defaults to 1).
| `custom-user-agent`                 | custom-user-agent for the http requests (optional, defaults to artsdata-crawler)

### Push mode (including fetch-push)

| Name                                  | Description         |
| ------------------------------------- | -------------------------- |
| `publisher`                         | **required**: URI of the publisher (required for push and fetch-push modes).
| `downloadUrl`                       | **required**: URL of the file to download (required for push mode).
| `group`                             | Group of artifacts/versions. Use unreserved characters. (If not provided, group will be set as your repository name).
| `version`                           | Version of the artifact. Usually a date (e.g., 2020-10-23). Use unreserved characters. (If not provided, version will be set as the current date).
| `comment`                           | Comment about the artifact push (optional)
| `shacl`                             | URL to the SHACL file to perform validations (optional)
| `shacl`                             | URL to the SHACL file to perform validations (optional)
| `custom-databus-url`                | Custom databus URL to push the data to (optional, default - http://api.artsdata.ca/databus/)


<br>

## Potential Issues

Remember to use only unreserved characters ([0-9a-zA-Z-._]) for input variables where mentioned.

# Release Instructions

When preparing a release for the artsdata-pipeline-action, please follow these versioning guidelines:

## Minor release (e.g., 2.0.7 → 2.0.8): 

For small feature additions or bug fixes.

## Major release (e.g., 2.0.7 → 2.1.0): 

For larger changes or significant improvements that could impact compatibility.

## Significant Update (e.g., 2.0.7 → 3.0.0): 

For major overhauls or breaking changes. If there's a drastic change in functionality or usage, increment to the next "big update" version.
