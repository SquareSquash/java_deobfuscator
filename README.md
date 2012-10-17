Squash Java Deobfuscation Library
=================================

This gem serves three purposes:

* to upload yGuard obfuscation data to Squash,
* to map class names to their file paths, and upload that data to Squash, and
* to notify Squash of new releases of Java software (internally or externally).

This gem installs a `deobfuscate` binary that converts a renamelog.xml file into
a format usable for Squash, locates the files in which classes are defined, and
then uploads that data to the Squash host. It also installs a `squash_release`
binary that notifies Squash of the release.

Documentation
-------------

Comprehensive documentation is written in YARD- and Markdown-formatted comments
throughout the source. To view this documentation as an HTML site, run
`rake doc`.

For an overview of the various components of Squash, see the website
documentation at https://github.com/SquareSquash/web.

Compatibility
-------------

This library is compatible with Ruby 1.8.6 and later, including Ruby Enterprise
Edition.

Requirements
------------

This gem requires the `json` gem (http://rubygems.org/gems/json). You can use
any JSON gem that conforms to the typical standard
(`require 'json'; object.to_json`).

Usage
-----

### Uploading Obfuscation and Class Path Data

This gem installs a command-line binary named `deobfuscate`. It is called in the
following format:

````
deobfuscate [options] <API key> <environment> <build number> <renamelog file>
````

Example: `deobfuscate --no-ssl-verification a9232f94-6c2d-45ae-8f9e-9add5bd7ff35 production 103 /path/to/renamelog.xml`

This binary is intended to be used as part of your release process. It will
first parse the renamelog file and generate an internal representation of your
program's namespace, along with all obfuscated aliases. Then it will attempt to
map class names to the files in which the classes are defined. In order for this
to work, your classes should be organized in folder structures according to
their package names. For example, the source of the class `com.foo.bar.Baz`
should be found in a "com/foo/bar/Baz.java" file path somewhere in your project.

By default this program assumes it's being run from the project root, but you
can also specify the root with the `--project-dir` switch. For documentation on
`deobfuscate`'s command-line options, run `deobfuscate --help.`

### Release Notification

This gem installs a command-line binary named `squash_release`. It is called in
the following format:

````
squash_release [options] <API key> <environment> <build number>
````

Example: `squash_release a9232f94-6c2d-45ae-8f9e-9add5bd7ff35 production 103 `

This binary is intended to be used as part of your release process, similar to
`deobfuscate` (see above). Like `deobfuscate`, sensible defaults are provided
for all command line switches.

For documentation on `squash_release`'s command-line options, run
`squash_release --help`.

Data Transmission
-----------------

Deobfuscation and release data is transmitted to Squash using JSON-over-HTTPS. A
default API endpoint is pre-configured, though you can always set your own (see
`deobfuscate --help` or `squash_release --help`).

By default, `Net::HTTP` is used to transmit errors to the API server. If you
would prefer to use your own HTTP library, see the `squash_uploader` gem.

Use as a Library
----------------

In addition to using the rename map with Squash, you can also use the gem as
a library, to perform deobfuscation for your own purposes (even unrelated to
Squash). See the {Squash::Java::Namespace} class documentation for more
information.
