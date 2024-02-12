const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');


async function run() {
  let artsDataApiResponse;
  try {
    const artifact = core.getInput('artifact');
    const publisher = core.getInput('publisher');
    const downloadUrl = core.getInput('downloadUrl');

    const group = github.context.repo.repo;

    const downloadFile = downloadUrl.split("/").pop();

    // Construct data payload
    const today = new Date().toISOString().replace(/:/g, "_")
    const data = {
      artifact: artifact,
      publisher: publisher,
      group: group,
      version: today,
      downloadUrl: downloadUrl,
      downloadFile: downloadFile,
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
