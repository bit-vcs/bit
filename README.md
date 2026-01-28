# MoonBit Template

A minimal MoonBit project template with CI, justfile, and AI coding assistant support.

## Usage

Clone this repository and start coding:

```bash
git clone https://github.com/mizchi/moonbit-template my-project
cd my-project
```

Update `moon.mod.json` with your module name:

```json
{
  "name": "your-username/your-project",
  ...
}
```

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just run       # run main
just info      # generate type definition files
```

## Project Structure

```
my-project/
├── moon.mod.json      # Module configuration
├── src/
│   ├── moon.pkg       # Package configuration
│   ├── lib.mbt        # Library code
│   ├── lib_test.mbt   # Tests
│   ├── lib_bench.mbt  # Benchmarks
│   ├── API.mbt.md     # Doc tests
│   └── main/
│       ├── moon.pkg
│       └── main.mbt   # Entry point
├── justfile           # Task runner
└── .github/workflows/
    └── ci.yml         # GitHub Actions CI
```

## Features

- `src/` directory structure with `moon.pkg` format
- Snapshot testing with `inspect()`
- Doc tests in `.mbt.md` files
- Benchmarks with `moon bench`
- GitHub Actions CI
- Claude Code / GitHub Copilot support (AGENTS.md)

## License

Apache-2.0
