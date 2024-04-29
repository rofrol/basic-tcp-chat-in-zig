# Basic TCP Chat in Zig

Fork of https://gist.github.com/karlseguin/53bb8ebf945b20aa0b7472d9d30de801

## Run on MacOS

Sometimes there are multiple processes listening on the same port. And nc does not connect to the recent server.

For that I kill the processes listening on the port and then run the server.

```sh
kill -QUIT $(sudo lsof -sTCP:LISTEN -t -i tcp:5501); sleep 2; zig run basic-tcp-chat.zig
```

In two terminals run clients like that:

```sh
while true; do clear && printf '\e[3J'; nc 127.0.0.1 5501; done
```

You may monitor processes listening on the port with:

```sh
watch sudo ls of -sTCP:LISTEN -t -i tcp:5501
```
