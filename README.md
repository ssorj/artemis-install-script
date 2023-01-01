# Artemis install script

[![main](https://github.com/ssorj/artemis-install-script/actions/workflows/main.yaml/badge.svg)](https://github.com/ssorj/artemis-install-script/actions/workflows/main.yaml)

## Install Artemis

~~~ shell
curl https://raw.githubusercontent.com/ssorj/artemis-install-script/main/install.sh | sh
~~~

## Uninstall Artemis

~~~ shell
curl https://raw.githubusercontent.com/ssorj/artemis-install-script/main/uninstall.sh | sh
~~~

## Notes

 - Goal 1 - Make it really easy to start using Artemis
 - Goal 2 - Be helpful when users face trouble
 - Goal 3 - Guide users to their next step
   - Default start config is about evaluation
   - Subsequent steps to change the config and open up access and add access controls
 - Goal 4 - Support as many environments as possible
   - Bourne shell with optional Bash extensions - *should* work on BSD and other unixes
   - My primary target environments are Fedora, Mac OS, and Ubuntu
 - Tries to follow the XDG base dir spec - https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
