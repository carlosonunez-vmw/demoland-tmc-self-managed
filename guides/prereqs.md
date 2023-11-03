# Prerequisites

## Open a Terminal

Most of the steps you'll perform will be done in a terminal. Make sure that you
have a terminal that you're comfortable with handy before moving on.

Some examples are provided below:

- **Windows**: Windows Terminal, Git Bash
- **macOS**: iTerm2, Terminal

While this guide is written with `bash` in mind, any Bourne-compatible shell
should work.

## On your computer

First, make sure that you have the following installed on your computer.

- [Docker](https://get.docker.io)
- [`jq`](https://github.com/stedolan/jq)
- [`ytt`](https://carvel.dev/ytt)
- [`kapp`](https://carvel.dev/kapp)

Run the command below in your terminal to confirm that you're good to go. You
should see no output if you are.

```sh
for tool in docker jq ytt kapp
do
    &>/dev/null which "$tool" && continue
    >&2 echo "ERROR: Please install this tool to continue: $tool"
    exit 1
done
```

## Okta

Next, you'll need to create a Developer Account in Okta.

First, [click here](https://developer.okta.com/signup/) to sign up for an
account.

Once you validate your email address, you'll be taken to your Dashboard.

Click on "Security", then on "API". This will show you the authorization server
in your tenant.

![](./static/okta-auth-server.png)

From here, we're going to retrieve three things and turn them into environment
variables:

- Organization Name,
- Organization Base URL, and
- An API Token

The Organization Base URL is `okta.com`.

The host in the "Issuer URI" is your "organization name". For instance,
given the issuer URI `https://dev-90830894.okta.com/oauth2/default`, the
organization name is `dev-90830894`.

Now let's create an API token. Click on "Tokens", then on "Create Token." Name
your token something, then click "Create Token."

You'll be presented with the "Token Value". Copy it.

Finally, in your terminal, `export` three environment variables that we'll use
throughout this guide. If you restart your Terminal, make sure to perform this
step again.

```sh
export OKTA_BASE_URL=okta.com
export OKTA_ORG_NAME=$YOUR_ORGANIZATION_NAME
export OKTA_API_TOKEN=$YOUR_API_TOKEN
```
