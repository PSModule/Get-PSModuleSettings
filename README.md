# Get-PSModuleSettings

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule).

## Inputs

| Input | Description | Required | Default |
| :---- | :---------- | :------: | :------ |
| `Name` | Name of the module. | No | Repository name |
| `SettingsPath` | Path to the settings file (json, yaml/yml, or psd1). | No | |
| `ImportantFilePatterns` | Newline-separated list of regex patterns that identify important files. Changes matching these patterns trigger build, test, and publish stages. | No | `^src/` and `^README\.md$` |
| `Debug` | Enable debug output. | No | `false` |
| `Verbose` | Enable verbose output. | No | `false` |
| `Version` | Specifies the version of the GitHub module to be installed. | No | |
| `Prerelease` | Allow prerelease versions if available. | No | `false` |
| `WorkingDirectory` | The working directory where the script will run from. | No | `${{ github.workspace }}` |

## Settings file

The action reads settings from a file (default: `.github/PSModule.yml`). Settings in the file take precedence over action inputs.

### ImportantFilePatterns

Controls which file changes trigger build, test, and publish stages. When a PR only changes files that don't match any
of these patterns, those stages are skipped.

Default patterns (used when not configured):

- `^src/` — Module source code
- `^README\.md$` — Root documentation

To override, add `ImportantFilePatterns` to your settings file:

```yaml
ImportantFilePatterns:
  - '^src/'
  - '^README\.md$'
  - '^examples/'
```

When configured, the provided list fully replaces the defaults. Include the default patterns in your list if you still
want them to trigger releases.
