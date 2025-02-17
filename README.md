<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./logos/aOS_darkmode.svg">
  <source media="(prefers-color-scheme: light)" srcset="./logos/aOS.svg">
  <img alt="logo">
</picture>


Version: 2.0.5
Module: `Do_Uc2Sju_ffp6Ev0AnLVdPtot15rvMjP-a9VVaA5fM`

Sqlite-Module: `GuzQrkf50rBUqz3uUgjOIFOL1XmW9nSNysTBC-wyiWM`

## Requirements

- [NodeJS](https://nodejs.org) version 20+

## Getting Started

```sh
npm i -g https://get_ao.g8way.io && aos
```

> NOTE: after the first time you run `aos` it installs it to your local machine, so the next time you want to run `aos`, just type `aos` + [enter]

## User Documentation

Go to [ao Cookbook](https://cookbook_ao.g8way.io)

## Design Principals

- aos the module is designed to be an operating system on the ao network, it provides developers the ability to build ao processes that are fast to iterate with and highly flexible. The design goal of the aos process is to not have too many opinions and implement the core functionality extremely well. The design should quickly reach a complete status. Currently it is in the `Preview` stage and should be progressing to an `Early` stage, then finally a `Complete` stage.

- aos console is an interactive shell to the aos module, the purpose of this shell is to provide developers with a fun and engaging experience with the aos operating system module, as well as users. Users should enjoy to run their personal processes and engage on the network, from trading, to chats, to games. So the console should be easy to install on all major os platforms.

## Preview Implementation

The current implementation of aos is using the ao wasm module and building with the ao cli that uses a emscripten `c` compiler and embeds `Lua v5.3` in the wasm binary. This gives the developers and users with a built in operating system with a first class interactive language to engage with the Process business logic. The `aos` module also provides features like `json`, `base64`,

## For Developers

The aos console is a command-line application that provides a easy to use DX experience to create Processes (aka Smart Contracts) on the ao Computer.

### Setup

Use yarn to build the project and run.

```sh
yarn
yarn build
yarn start
```


### Command-line options

You can provide a name for a specific Process, if the Process does not exist aos will spawn the process, then every time you run `aos [name]` it will locate that process and interact with it.

```sh
aos [name]
```

#### Flags

| Name                                          | Description                                                                                                                                                                                                                        | Required |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `--relay [Relay URL]`                           | The relay flag can be used to run your process with payments enabled through a HyperBEAM relay | 0-1      |
| `--cron [Interval]`                           | The cron flag can only be used when spawning a process, it instructs the Process to generate messages every `Interval`. An Interval can be defined with a [n]-(period) for example: 1-minute, 10-minutes, 5-hours, 10-blocks, etc. | 0-1      |
| `--get-blueprints [dir]`                      | This command will grab blueprints from the `/blueprints` folder or a folder specified by the user. These blueprints are small lua files that can be applied to your process to automatically give it some functionality.           | 0-1      |
| `--tag-name [name]` and `--tag-value [value]` | These flags are also only when aos is spawning a Process. You may add many of these combinations as you would like and they will appear on the Process tags object                                                                 | 0-n      |
| `--load [luaFile]`                            | The load command allows you to load lua source files from your local directory.                                                                                                                                                    | 0-n      |
| `--gateway-url [url]`                         | The gateway-url flag allows you to specify a custom Gateway to connect to.                                                                                                                                                         | 0-1      |
| `--cu-url [url]`                              | The cu-url flag allows you to specify a custom Computer Unit to connect to.                                                                                                                                                        | 0-1      |
| `--mu-url [url]`                                | The mu-url flag allows you to specify a custom Memory Unit to connect to.                                                                                                                                                          | 0-1      |
| `--sqlite` | 0-1 | Use sqlite aos module when spawning new process |
| `--data [filepath]` | 0-1 | Set file contents as the data field of your Process. Will run when the process boots up if the On-Boot tag is set to Data, if On-Boot is set to Data make sure the file contains valid lua code |

### Commands

When running the console, you can type `dot` commands to instruct the console to perform special instructions.

| Command                  | Description                                                                                                                                  |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `.editor`                | This command opens a simple cli editor that you can type on multiple lines, and then you can type `.done` or `.cancel` to exist editor mode. |
| `.load`                  | This command allows you to load a lua source file from your local directory                                                                  |
| `.load-blueprint [name]` | This command will grab a lua file from the blueprints directory and load it into your process.                                               |
| `.exit`                  | This command will exit you console, but you can also do `Ctrl-C` or `Ctrl-D`                                                                 |

### Boot Loading

When booting up a new aos you can specify a script as the Data field of your process and use the On-Boot tag to run at startup. If On-Boot is set to Data, the script can be read from a local file

```sh
aos boottest --tag-name="On-Boot" --tag-value="Data" --data=../bootup.lua
```

Or On-Boot can be a tx id, which must also contain a valid lua script.

```sh
aos boottest --tag-name="On-Boot" --tag-value="arweavetxid"
```

## License

The ao and aos codebases are offered under the BSL 1.1 license for the duration
of the testnet period. After the testnet phase is over, the code will be made
available under either a new
[evolutionary forking](https://arweave.medium.com/arweave-is-an-evolutionary-protocol-e072f5e69eaa)
license, or a traditional OSS license (GPLv3/v2, MIT, etc).

## Advanced AOS Development Guide

### Requirements

* Docker
* Nodejs

### Setup

```
curl -L https://install_ao.g8way.io | bash
```

> Follow install instructions

change console directory to process

```
cd process
```

### Build WASM Module

```
ao build
```

### Develop using os loader

Making changes and debugging can be a challege with aos modules.

```
node ../src/index.js
aos> .update
```

Will load the current changes into a process. This workflow will allow you to make changes and update the os verify changes. Rinse Repeat.


### Run AOS Tests

```
yarn
yarn test
```

### Deploy WASM Module

> NOTE: you will need a keyfile with turbo credits from ardrive.io
> Add keyfile to $HOME/.wallet.json file

```
yarn deploy
```

### Copy the new module id

Create a new aos with module id

```
$MODULE={moduleId}
aos new1 --module=$MODULE
```

### Deploy a new version of AOS Console

in the project directory
Update package.json with new Module ID and new Version. Use semantic versioning.
Update README.md with new Module ID and new Version

### Update aos-sqlite with latest

```
cd process
docker run -v .:/src p3rmaw3b/aos-sqlite:0.0.0 emcc-lua
yarn 
yarn test
yarn deploy-sqlite
```

copy module id to package.json and readme


