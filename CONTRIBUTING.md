# Contributing

Contributions are welcome — thank you for your interest in Patchi-Wani!

## Bug reports and feature requests

Please use [GitHub Issues](https://github.com/<your-username>/patchi-wani/issues).

When reporting a bug, please include:

- OS, Flutter version, and target device
- Steps to reproduce
- Expected behavior vs. actual behavior

## Pull request workflow

```bash
# 1. Fork and clone
git clone https://github.com/<your-username>/patchi-wani.git
cd patchi-wani

# 2. Set up the environment
chmod +x setup.sh && ./setup.sh

# 3. Create a branch
git checkout -b fix/target-spawn-timing

# 4. Make changes and run tests
cd patchi_wani_engine && cargo test
cd ../patchi_wani_flutter && flutter test

# 5. Commit and push
git add .
git commit -m "[FIX] Correct target spawn interval"
git push origin fix/target-spawn-timing
```

## Code style

- Rust: run `cargo fmt` and `cargo clippy` from `patchi_wani_engine/` before committing
- Dart: run `dart format` before committing
- Commit messages must follow the project tag convention — see **[COMMIT_CONVENTION.md](./COMMIT_CONVENTION.md)**

## Important notes

- Do not include copyrighted images or audio files in the repository
- Do not accidentally commit personal recordings — check `.gitignore` before pushing
- Do not make unsubstantiated effectiveness claims in code or documentation
