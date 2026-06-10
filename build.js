import esbuild from 'esbuild';
import fs from 'node:fs/promises';
import { constants } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const distDir = path.join(rootDir, 'dist');

const packageJson = JSON.parse(await fs.readFile(path.join(rootDir, 'package.json'), 'utf8'));

await fs.rm(distDir, { force: true, recursive: true });
await fs.mkdir(path.join(distDir, 'bin'), { recursive: true });
await fs.mkdir(path.join(distDir, 'src'), { recursive: true });

await esbuild.build({
  bundle: true,
  entryPoints: [path.join(rootDir, 'src/index.js')],
  external: ['readline/promises'],
  format: 'esm',
  outfile: path.join(distDir, 'src/index.js'),
  packages: 'external',
  platform: 'node',
  sourcemap: true,
  target: 'node18'
});

await fs.writeFile(
  path.join(distDir, 'bin/aos.js'),
  `#!/usr/bin/env node\nimport '../src/index.js'\n`
);
await fs.chmod(
  path.join(distDir, 'bin/aos.js'),
  constants.S_IRWXU | constants.S_IRGRP | constants.S_IXGRP | constants.S_IROTH | constants.S_IXOTH
);

await copyIfExists('README.md');
await copyIfExists('LICENSE');
await copyIfExists('aos-workflow.png');
await fs.cp(path.join(rootDir, 'blueprints'), path.join(distDir, 'blueprints'), {
  recursive: true
});
await fs.cp(path.join(rootDir, 'process'), path.join(distDir, 'process'), {
  filter: src => {
    const relativePath = path.relative(path.join(rootDir, 'process'), src);

    return (
      !['.gitignore', 'wallet.json'].includes(relativePath) &&
      !relativePath.startsWith(`test${path.sep}`)
    );
  },
  recursive: true
});

await fs.writeFile(
  path.join(distDir, 'package.json'),
  `${JSON.stringify(createPublishPackage(packageJson), null, 2)}\n`
);

console.log(`Built ${packageJson.name}@${packageJson.version} in dist/`);

async function copyIfExists(fileName) {
  try {
    await fs.cp(path.join(rootDir, fileName), path.join(distDir, fileName), { recursive: true });
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

function createPublishPackage(pkg) {
  return {
    name: pkg.name,
    version: pkg.version,
    license: pkg.license,
    author: pkg.author,
    repository: createRepository(pkg.repository),
    type: pkg.type,
    main: 'src/index.js',
    bin: {
      aos: 'bin/aos.js'
    },
    files: ['bin', 'src', 'blueprints', 'process', 'README.md', 'LICENSE', 'aos-workflow.png'],
    scripts: {
      start: 'node src/index.js'
    },
    dependencies: {
      ...pkg.dependencies,
      ramda: pkg.dependencies.ramda || '0.30.1'
    },
    aos: pkg.aos,
    hyper: pkg.hyper
  };
}

function createRepository(repository) {
  if (typeof repository !== 'string') return repository;

  return {
    type: 'git',
    url: repository.startsWith('git+') ? repository : `git+${repository}`
  };
}
