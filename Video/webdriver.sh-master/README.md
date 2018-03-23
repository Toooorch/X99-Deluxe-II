# webdriver.sh

<p align="center">
<picture>
<source srcset="https://github.com/vulgo/webdriver.sh/raw/master/Images/screenshot.png, https://github.com/vulgo/webdriver.sh/raw/master/Images/screenshot@2x.png 2x" />
<img src="https://github.com/vulgo/webdriver.sh/raw/master/Images/screenshot@2x.png" alt="webdriver.sh screenshot" width="800" />
</picture>
</p>

Bash script for managing NVIDIA's web drivers on macOS High Sierra.

- The easiest way to install NVIDIA's drivers
- Quickly roll back to a previous driver version with ```webdriver list```
- Automatically applies a Clover kext patch - use any driver version (Clover systems)
- Or patches the drivers to load on your current macOS version (non-Clover systems)
- Also sets the required build number in NVDAEGPUSupport.kext (EGPU systems)

<br/>

<pre><code>source&nbsp;<(curl&nbsp;-s&nbsp;https://raw.githubusercontent.com/vulgo/webdriver.sh/v1.3.0/get)</code></pre>

<br/>

## Installing

Install webdriver.sh with [Homebrew](https://brew.sh)

```shell-script
brew tap vulgo/repo
brew install webdriver.sh
```

Update to the latest release

```shell-script
brew upgrade webdriver.sh
```

<br/>

# Example Usage

<p align="center">
<img src="https://raw.githubusercontent.com/vulgo/webdriver.sh/master/Images/egpu.svg?sanitize=true" alt="Macbook Pro NVIDIA EGPU" width="50%">
</p>

## Install the latest drivers

```shell-script
webdriver
```

Installs/updates to the latest available NVIDIA web drivers for your current version of macOS.

<br/>

## Choose from a list of drivers

```shell-script
webdriver --list
```

Displays a list of driver versions, choose one to download and install it.

<br />

#### Install from local package or URL

```shell-script
webdriver FILE
```

Installs the drivers from package <em>FILE</em> on the local filesystem.

```shell-script
webdriver -u URL
```

Downloads the package at <em>URL</em> and installs the drivers within. There is a nice list of available URLs maintained [here](http://www.macvidcards.com/drivers.html).

<br />

#### Uninstall drivers

```shell-script
webdriver --remove
```

Removes NVIDIA's web drivers from your system.

<br />

#### Patch drivers to load on a different version of macOS

```shell-script
webdriver -m [BUILD]
```

Modifies the installed driver's NVDARequiredOS. If no [BUILD] is provided for option -m, the installed macOS's build version string will be used.

<br />

#### Show help

```shell-script
webdriver --help
```

Displays help, lists options.

<br />
<br />

## Frequently Asked Questions

#### Is webdriver.sh compatible with regular, or other third-party methods of driver installation?

Yes, you can use webdriver.sh before or after using any other method of driver installation.

#### Does webdriver.sh install the NVIDIA preference pane?

No, you can install it at any point via NVIDIA's installer package - webdriver.sh works fine with or without it. Alternatively, [Web Driver Manager](https://github.com/vulgo/WebDriverManager/releases/download/v1.3/WebDriverManager.dmg) is a minimal menu bar app ([source](https://github.com/vulgo/WebDriverManager)) that monitors driver status and the nvda_drv NVRAM variable.

#### Do I need to disable SIP?

No, but you'll want to if you are modifying the drivers to load - making changes to a kext's Info.plist excludes it from the prelinked kernel the next time it's built.

#### Will webdriver.sh mess with NVIDIA's installer or 'repackage' the driver?

No, there are [other tools](https://www.google.com/search?q=nvidia+web+driver+repackager) available for doing this. For example,  [NvidiaWebDriverRepackager](https://github.com/Pavo-IM/NvidiaWebDriverRepackager)

#### Won't there be problems without repackaging?

No, the drivers are installed in exactly the same way (yes, it's just copying files) - and NVIDIA's own installer removes anything installed by webdriver.sh.

#### Can't I just uninstall the drivers using webdriver.sh?

Yes, ```webdriver -r```

#### Does webdriver.sh install things to the wrong place?

No.

<br />

## License

webdriver.sh is free software licensed under the terms of the GPL version 3 or later.

<br />
