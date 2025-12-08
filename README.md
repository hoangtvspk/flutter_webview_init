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

This will create `.env.dev`, `.env.staging`, and `.env.prod` files in `lib/core/config/` directory.

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
