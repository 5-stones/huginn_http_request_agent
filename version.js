const fs = require('fs')
const filePath = './huginn_http_request_agent.gemspec';
const version = require('./package.json').version;

fs.readFile(filePath, 'utf8', (err, data) => {
  if (err) {
    return console.log(err);
  }

  const reg = /spec.version       = "([^"]+)"/g;
  const currentVersion = reg.exec(data)[1];
  console.log(`updating gemspec from v${currentVersion} to v${version}`);
  const result = data.replace(reg, `spec.version       = "${version}"`);

  fs.writeFile(filePath, result, 'utf8', (err) => {
     if (err) return console.log(err);
  });
});
