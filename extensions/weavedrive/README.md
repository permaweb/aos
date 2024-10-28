# WeaveDrive

SPEC: https://hackmd.io/@ao-docs/H1JK_WezR

## Building

`npm run build`

## Testing

`npm test`

## Contributing

### Publish a new Version of the package

We use a Github workflow to build and publish new version of the Loader to NPM.
To publish a new version, go to the
[WeaveDrive CI workflow](https://github.com/permaweb/aos/actions/workflows/weavedrive.yml)
and click the `Run Workflow` button. Provide the semver compatible version you
would like to bump to, and then click `Run Workflow`. This will trigger a
Workflow Dispatch that will bump the version is the manifest files, build the module, and finally publish it to NPM
