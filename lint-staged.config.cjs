module.exports = {
  '**/*.js': [
    'standard --fix'
  ],
  '**/*.lua': (allFiles) => {
    const styluaArgs = allFiles.reduce((acc, file) => {
      const path = "**" + file.replace(process.cwd(), '')
      return acc + ` -g ${path}`
    }, '')

    const luacheckArgs = allFiles.reduce((acc, file) => {
      const path = "." + file.replace(process.cwd(), '')
      return acc + ` ${path}`
    }, '')

    return [
      `stylua ${styluaArgs} -- .`,
      `luacheck --config .luacheckrc ${luacheckArgs}`,
    ]
  },
  '**/package.json': [
    'sort-package-json'
  ],
  '**/*.md': [
    'markdown-toc-gen insert'
  ]
}
