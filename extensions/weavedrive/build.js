const esbuild = require('esbuild')

esbuild.build({
  entryPoints: ['src/index.js'],
  platform: 'node',
  format: 'cjs',
  bundle: true,
  outfile: 'dist/index.cjs'
}).then(x => console.log('done'))
