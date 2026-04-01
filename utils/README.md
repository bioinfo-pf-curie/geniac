# Managing Dependencies with `environment.yml`

This project uses a dependency management system based on **Conda** and **pip**, centralized in an automatically generated `environment.yml` file. Below is how to modify and regenerate this environment.

---

## **Modifying Dependencies**

### 1. **Modify pip Dependencies**

- Edit the `pyproject.toml` file to add/remove/modify pip dependencies.
- **Example**:
  ```toml
  [project]
  dependencies = [
      "numpy>=1.21.0",
      "pandas>=1.3.0",
      "requests>=2.25.0"
  ]
  ```

### 2. **Modify conda Dependencies**

- Edit the `utility/environment_minimal.yml` file to add/remove/modify conda dependencies.
- **Example**:
  ```yaml
  name: geniac
  channels:
    - conda-forge
  dependencies:
    - python=3.9
    - numpy=1.21
    - pandas=1.3
  ```

---

## **Regenerating the `environment.yml` File**

After modifying any dependencies (pip or conda), **regenerate** the global `environment.yml` file by running the following script:

```bash
bash gen_env.sh
```

### ⚠️ **What the `gen_env.sh` Script Does**:

1. Creates a temporary environment with conda dependencies (`environment_minimal.yml`).
2. Installs pip dependencies from `pyproject.toml`.
3. Exports the complete environment to `environment.yml`.
4. Removes the temporary environment.

---

## **Important Notes**

- **Never edit** the `environment.yml` file directly: it is automatically generated.
- **Always check** for version conflicts after regeneration.

