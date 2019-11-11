const { exec } = require('child_process');
const version = require('./package.json').version;

dir = exec(`gem push huginn_http_request_agent-${version}.gem`, (err, stdout, stderr) => {
  if (err) {
    console.log(err);
  }

  console.log(stdout);
});
