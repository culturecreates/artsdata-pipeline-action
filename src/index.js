const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');


async function run() {
  let artsDataApiResponse;
  try {
    const artifact = core.getInput('artifact');
    const publisher = core.getInput('publisher');
    const downloadUrl = core.getInput('downloadUrl');
    const downloadFile = core.getInput('downloadFile') || downloadUrl.split("/").pop();
    const group = core.getInput('group') || github.context.repo.repo;
    const version = core.getInput('version') || new Date().toISOString().replace(/:/g, "_")
    const comment = core.getInput('comment') || `Published by ${group} on ${version}`

    // Construct data payload
    const data = {
      artifact: artifact,
      publisher: publisher,
      group: group,
      version: version,
      downloadUrl: downloadUrl,
      downloadFile: downloadFile,
      comment: comment
    };

    console.log('Data:', data)

    // Perform HTTP request
    artsDataApiResponse = await axios.post('http://api.artsdata.ca/databus/', data, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.log('Error:', error.response?.data)
    core.setFailed(error.message);
  }
}

run();
