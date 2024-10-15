const axios = require('axios');

async function run() {
  let artsDataApiResponse;
  try {
    const artifact = process.env.artifact
    const publisher = process.env.publisher
    const downloadFile = process.env.downloadFile
    
    const repo = process.env.GITHUB_REPOSITORY;
    const sha = process.env.GITHUB_SHA;
    const downloadUrl = `https://raw.githubusercontent.com/${repo}/${sha}/output/${downloadFile}`;
    
    const group = process.env.group || repo.split('/')[0];
    const version = process.env.version || new Date().toISOString().replace(/:/g, "_");
    const comment = process.env.comment || `Published by ${group} on ${version}`;

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

    console.log('Data:', data);

    // Perform HTTP request
    artsDataApiResponse = await axios.post('http://api.artsdata.ca/databus/', data, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

  } catch (error) {
    console.log('Error:', error.response?.data);
  }
}

run();
