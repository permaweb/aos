# ArBit Repl

The repl is a thin client to access and execute ao contracts on the permaweb.

## Commands

login

The login command lets users with a jwk wallet file to provide that to the CLI to login, then checks to see if the user is running a personal process, if not, we will create one. The personal process is like a pure computer in AO for users to control and communicate in the AO cyberspace.

register

The command sets up a personal process attached to your wallet, the personal process currently provides two commands `echo` and `eval`, these commands allow you and only you to execute code on the personal process.

echo

if logged in, you will be able to call a command echo, this command will submit an interaction to your personal process which will execute and return the output to your screen.

eval

if logged in, you will be able to send simple lua expressions to your personal process which is powered by lua, these expressions will execute and return you a result.

logout

this command will log you out of your repl experience.

