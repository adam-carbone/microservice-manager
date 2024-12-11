# Microservices Manager

The **Microservices Manager** provides a lightweight and extensible framework for managing microservices. This setup includes:

- **`managerw.sh`**: A wrapper script that ensures the main management script is up-to-date and delegates commands.
- **`microservices-manager.sh`**: The main script containing all the functionality to manage your microservices.
- **Automated Versioning**: Uses a CalVer (Calendar Versioning) scheme for clarity and precision.

---

## Features

1. **Lightweight Bootstrap**: Quickly set up the `managerw.sh` script with a single command.
2. **Automatic Updates**:
    - Ensures `microservices-manager.sh` is always up-to-date.
    - Warns users if `managerw.sh` itself is outdated and provides an update command.
3. **Independent Version Management**:
    - Easily update the versions of `managerw.sh` and `microservices-manager.sh` independently.
4. **Centralized State Management**:
    - Stores cached version information and state in `~/.microservices-manager`.
5. **Extensive Functionality**:
    - Build, package, and run Docker containers.
    - Manage service discovery and state.
    - Generate Postman collections from OpenAPI specs.

---

## Installation

To set up the **Microservices Manager**, run the following command:

```bash
curl -sSL https://raw.githubusercontent.com/adam-carbone/microservice-manager/main/bootstrap-managerw.sh | bash -s install
```

This will:
1. Download the `managerw.sh` wrapper script to your current directory.
2. Make the script executable.

---

## Usage

### **Run Commands**

Once installed, you can run commands using `managerw.sh`:

```bash
./managerw.sh [COMMAND]
```

### **Common Commands**

| Command                 | Description                                              |
|-------------------------|----------------------------------------------------------|
| `build`                 | Build the project using Gradle.                          |
| `debug`                 | Start the application in debug mode.                     |
| `dev`                   | Run the application locally with the 'dev' profile.      |
| `prod`                  | Run the application locally with the 'prod' profile.     |
| `package`               | Package the application for production deployment.       |
| `docker-build`          | Build and push the Docker image using Jib.               |
| `docker-local`          | Build the Docker image locally using Jib.                |
| `docker-run`            | Run the Docker container locally.                        |
| `docker-stop`           | Stop the running Docker container.                       |
| `docker-status`         | Check the status of the Docker container.                |
| `postman-collection`    | Generate a Postman collection based on OpenAPI spec.     |
| `update`                | Update the `managerw.sh` script.                         |
| `--help` or `help`      | Display help information.                                |

---

## Version Management

The project uses **CalVer (Calendar Versioning)** for both `managerw.sh` and `microservices-manager.sh`.

**Version Format**:
```
<YEAR>.<WEEK>.<TIMESTAMP>+<COMMIT_HASH>
```

- **YEAR**: Current year (e.g., `2024`).
- **WEEK**: Week of the year (e.g., `50`).
- **TIMESTAMP**: Seconds within the current week, truncated to 6 digits (e.g., `123456`).
- **COMMIT_HASH**: Short Git commit hash (e.g., `abc1234`).

**Example**: `2024.50.123456+abc1234`

### **Automated Version Updates**

To simplify version management, the repository includes a helper script: `update-version.sh`.

#### **Update `managerw.sh` Version**

1. Run the following command:
   ```bash
   ./update-version.sh managerw.sh
   ```
2. Commit and push the changes:
   ```bash
   git commit -am "Update version of managerw.sh to <new-version>"
   git push origin main
   ```

#### **Update `microservices-manager.sh` Version**

1. Run the following command:
   ```bash
   ./update-version.sh microservices-manager.sh
   ```
2. Commit and push the changes:
   ```bash
   git commit -am "Update version of microservices-manager.sh to <new-version>"
   git push origin main
   ```

---

## State and Configuration

The manager uses the following directory for state and cache management:

**`~/.microservices-manager`**

| File                     | Description                                              |
|--------------------------|----------------------------------------------------------|
| `manager_cache`          | Stores remote version information to reduce frequent remote checks. |
| `state-*`                | Maintains runtime state for various microservices.       |

---

## Making Changes (For Maintainers)

### **Editing `managerw.sh` or `microservices-manager.sh`**

When making changes to either script, update the `# Version:` metadata to reflect the new version using the `update-version.sh` helper script.

1. Update the version:
   ```bash
   ./update-version.sh <script-name>
   ```
2. Test your changes thoroughly.
3. Commit and push the changes:
   ```bash
   git commit -am "Update <script-name> to <new-version>"
   git push origin main
   ```

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature
   ```
3. Make changes and commit:
   ```bash
   git commit -am "Add your feature"
   ```
4. Push your branch and create a pull request.

---

## License