# opalite

A containerized working environment for the particle tracking code
[OPAL](https://gitlab.psi.ch/OPAL/src) ([version 1.6.2](https://gitlab.psi.ch/OPAL/src/-/tree/OPAL-1.6.2))

## Usage

1) Create a named Docker container (note: we also mount a volume here, but this is
strictly optional)

`docker container create --name mycontainer --volume /path/to/host/dir:/path/to/container/dir opalite:latest`

2) Then run whatever command you'd like (i.e. a `bash` shell) in the container

`docker run mycontainer bash  # or whatever you want to run`

3) OPAL is available inside the container as `/usr/local/bin/opal`

**Note:** You could also start the container separately and execute a command
in it, which might be useful if you'd like to run multiple OPAL sessions at
once in a single container.


## Data persistence

Data inside of the container should be persisted until you delete it, but I
recommend you store any important data in a mounted volume for safe-keeping.
Permissions can be a little tricky when doing this, so you may also like to
pass `--user ${UID}:${UID}` to run under your current user ID, giving you the
same permissions in any mounted volumes as you have on the host. See the Docker
docs for more information

## Notes

In order to get this image to build I had to make a few edits to the project's
CMake; see the commentary in `Dockerfile` for more details.
