const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');


async function run() {
  try {
    const artifactName = core.getInput('artifact_name');
    const pageUrl = core.getInput('page_url');
    const publisherUri = core.getInput('publisher_uri');
    const downloadUrl = core.getInput('download_uri');
    const downloadFile = core.getInput('download_file');
    const group = core.getInput('group');

    // Construct data payload
    const today = new Date();
    const data = {
      artifact: artifactName,
      comment: `Entities from ${pageUrl}`,
      publisher: publisherUri,
      group: group,
      version: today.toISOString(),
      downloadUrl: downloadUrl,
      downloadFile: downloadFile,
      reportCallbackUrl: 'https://huginn-staging.herokuapp.com/users/1/web_requests/273/databus'
    };

    console.log('Data:', data)

    // Perform HTTP request
    const response = await axios.post('http://api.artsdata.ca/databus/', data, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    console.log('Response:', response.data);
    core.setOutput('response', response.data);
  } catch (error) {
    console.log('Error:', error.message)
    core.setFailed(error.message);
  }
}

run();
