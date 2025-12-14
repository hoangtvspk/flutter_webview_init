# flutter webview base

A flutter project to initialize with inappwebview package.

## Getting Started

### Create Environment Files

The project requires environment files for different environments. Run the setup script:

```bash
# Make the script executable
chmod +x scripts/create-env.sh

# Create environment files (default: dev)
./scripts/create-env.sh

# Or specify environment
ENVIRONMENT=dev ./scripts/create-env.sh
ENVIRONMENT=staging ./scripts/create-env.sh
ENVIRONMENT=prod ./scripts/create-env.sh
```

This will create `.env.dev`, `.env.staging`, and `.env.prod` files in `lib/config/` directory.

Remove git locally:

- rm -rf .git

Change package name:

- dart run change_app_package_name:main com.new.package.name

Change app's icon:

- dart run flutter_launcher_icons

Change native splash:

- flutter pub run flutter_native_splash:create

Flutter run generate:

```bash
make build-runner
```

Or manually:

- `flutter pub run build_runner build --delete-conflicting-outputs`
- `dart run build_runner build --delete-conflicting-outputs`

## Deploy via GitHub Actions

- Workflows run only if the commit message contains the keyword `deploy`.
- Environment is determined by branch:
  - `dev` → deploy to dev.
  - `staging` → deploy to staging.
  - `main`/`master` → deploy to prod.
- Platform is determined by keywords in the commit message:
  - `android` → build/deploy Android only.
  - `ios` → build/deploy iOS only.
  - `android-ios` → build/deploy both Android and iOS.
- Example commit messages:
  - `chore: deploy android`
  - `deploy ios`
  - `deploy android-ios`
  - `feat: deploy android-ios hotfix`
    Push to the corresponding branch and the self-hosted runner will build & deploy based on the commit message.
