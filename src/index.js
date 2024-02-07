const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');


async function run() {
  try {
    const artifactName = core.getInput('artifact_name');
    const pageUrl = core.getInput('page_url');
    const publisherUri = core.getInput('publisher_uri');
    const downloadUrl = core.getInput('download_url');
    const downloadFile = core.getInput('download_file');

    // Construct data payload
    const data = {
      artifact: artifactName,
      comment: `Entities from ${pageUrl}`,
      publisher: publisherUri,
      group: github.context.repo,
      version: Date.now(),
      downloadUrl: downloadUrl,
      downloadFile: downloadFile,
      reportCallbackUrl: 'https://huginn-staging.herokuapp.com/users/1/web_requests/273/databus'
    };

    // Perform HTTP request
    const response = await axios.post('http://api.artsdata.ca/databus/', data, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    console.log('Response:', response.data);
    core.setOutput('response', response.data);
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
