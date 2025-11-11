# Uninstall data-philter

This guide provides instructions on how to completely remove the data-philter application from your system.

## Steps to Uninstall (Linux/macOS)

1.  **Navigate to the data-philter directory:**
    First, change your current directory to where data-philter was installed. By default, this is `~/.data-philter`.

    ```bash
    cd ~/.data-philter
    ```

2.  **Stop and remove Docker containers:**
    Stop all running Docker containers associated with data-philter and remove them, along with their networks and volumes.

    ```bash
    docker compose down -v --rmi all
    ```
    The `-v` flag ensures that named volumes declared in the `docker-compose.yml` file, including `philter_data`, are also removed.

3.  **Remove the data-philter directory:**
    Finally, remove the entire data-philter installation directory.

    ```bash
    rm -r ~/.data-philter
    ```

    **Caution:** This command will permanently delete all files and data within the `~/.data-philter` directory. Ensure you have backed up any important data before proceeding.

4.  **Uninstall Ollama (Optional):**
    If you installed Ollama specifically for data-philter and no longer need it, you can uninstall it following these instructions on Linux  https://docs.ollama.com/linux#uninstall or on macOS https://docs.ollama.com/macos#uninstall 

## Steps to Uninstall (Windows)

1.  **Navigate to the data-philter directory:**
    First, open PowerShell and change your current directory to where data-philter was installed. By default, this is `C:\Users\<YourUsername>\.data-philter`.

    ```powershell
    cd $HOME\.data-philter
    ```

2.  **Stop and remove Docker containers:**
    Stop all running Docker containers associated with data-philter and remove them, along with their networks and volumes.

    ```powershell
    docker compose down -v --rmi all
    ```
    The `-v` flag ensures that named volumes declared in the `docker-compose.yml` file, including `philter_data`, are also removed.

3.  **Remove the data-philter directory:**
    Finally, remove the entire data-philter installation directory.

    ```powershell
    Remove-Item -Path "$HOME\.data-philter" -Recurse -Force
    ```

    **Caution:** This command will permanently delete all files and data within the `C:\Users\<YourUsername>\.data-philter` directory. Ensure you have backed up any important data before proceeding.

4.  **Uninstall Ollama (Optional):**
    If you installed Ollama specifically for data-philter and no longer need it, you can uninstall it via "Add or remove programs" in Windows settings, or by running the Ollama uninstaller executable if available. You may also manually delete the Ollama installation directory, typically found at `C:\Program Files\Ollama` and its data directory at `C:\Users\<YourUsername>\.ollama`.

## Complete Removal

After following these steps, data-philter and its associated Docker resources will be completely removed from your system.