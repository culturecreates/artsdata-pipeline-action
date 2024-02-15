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
        artifact:
          description: 'Name of the artifact'
          required: true
        publisher:
          description: 'URI of the publisher'
          required: true
          secret: true
        downloadUrl:
          description: 'URL to download'
          required: true
        downloadFile:
          description: 'Name of the file to download with extension'
          required: false
        comment:
          description: 'Comment'
          required: false
        group:
          description: 'Group of artifacts/versions. Typically the name of the tool creating the artifact. Use unreserved characters.'
          required: false
        version:
          description: 'Version of the artifact. Usually a date. For example: 2020-10-23. Use unreserved characters.'
          required: false
        reportCallbackUrl:
          description: 'URL to send back the data validation report asynchronously using POST "Content-Type: application/json"'
          required: false
        shacl:
          description: 'URL to the SHACL file'
          required: false

```

<br>

## Inputs

| Name                                  | Description                                                                                                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `artifact`                            | Name of the artifact.                                                                                                                                                    |
| `publisher`                           | URI of the publisher.                                                                                                                                                    |
| `downloadUrl`                         | URL to download the JSON-LD file.                                                                                                                                        |
| `downloadFile` (**Optional**)         | Name of the file to download with extension. (If this is not provided, the download file will be assumed to be the file at the end of downloadUrl).                      |
| `comment` (**Optional**)              | Comment about the artsdata push.                                                                                                                                         |
| `group` (**Optional**)                | Group of artifacts/versions. Use unreserved characters. (If this is not provided, group will be set as your repository name).                                            |
| `version` (**Optional**)              | Version of the artifact. Usually a date. For example: 2020-10-23. Use unreserved characters. (If this is not provided, version will be set as the current date).         |
| `reportCallbackUrl` (**Optional**)    | URL to send back the data validation report asynchronously using POST "Content-Type: application/json".                                                                  |
| `shacl` (**Optional**)                | URL to the SHACL file to perform validations.                                                                                                                            |

<br>

## Potential Issues

Remember to use only unreserved characters ([0-9a-zA-Z-._]) for input variables where mentioned.
