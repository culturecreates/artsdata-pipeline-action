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
        reportCallbackUrl:
        shacl:
```

<br>

## Inputs

| Name                                  | Description                                                                                                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `mode`                            | Mode to run the workflow in (fetch/push/fetch-push, defaults to push).    
| `page-url`                            | URL of the page to crawl (required for fetch and fetch-push modes).
| `entity-identifier	`                            | Identifier of the entity (required for fetch and fetch-push modes).
| `downloadFile`                            | Name of the file to download with extension (required for fetch and fetch-push modes).
| `downloadUrl`                            | URL of the file to download (required for push mode).
| `is-paginated`                            | Whether the page is paginated (defaults to false).
| `headless`                            | Whether to run in headless mode (defaults to false).
| `artifact`                            | Name of the artifact (required for push and fetch-push modes).
| `token`                            | GitHub token (required for fetch and fetch-push modes, secret).
| `publisher`                            | 	URI of the publisher (required for push and fetch-push modes).
| `comment`                            | Comment about the artsdata push.
| `group`                            | Group of artifacts/versions. Use unreserved characters. (If not provided, group will be set as your repository name).
| `version`                            | Version of the artifact. Usually a date (e.g., 2020-10-23). Use unreserved characters. (If not provided, version will be set as the current date).
| `reportCallbackUrl	`                            | URL to send back the data validation report asynchronously using POST "Content-Type: application/json".
| `shacl`                            | URL to the SHACL file to perform validations.


<br>

## Potential Issues

Remember to use only unreserved characters ([0-9a-zA-Z-._]) for input variables where mentioned.
