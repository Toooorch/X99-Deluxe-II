# Release notes

## 1.3.0

#### Recent changes

- Automatic Clover patching that survives driver and OS updates
- Improved driver list display
- Add an option to install drivers from a local package file
- Command now accepts long options
- More useful status updates when SIP is enabled
- General fixes and improvements

#### Unadvertised options in 1.3.0

- -a	used with --list, -l, may show additional drivers
- -!	argument assigned to CONFIG_ARGS for use in etc/~*.conf scripts
- -#	provide SHA512 checksum e.g. for --url, -u option
- -Y	no user interaction (installs/updates)

#### Alternative invocation

exactly ```swebdriver -u URL``` updates NVIDIA's drivers, then does ```softwareupdate -ir``` without interaction

#### Portable download

```source <(curl -s https://raw.githubusercontent.com/vulgo/webdriver.sh/v1.3.0/get)```