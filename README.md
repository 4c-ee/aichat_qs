# AI Chat Quickshell Panel

A specialized quick-access AI chat panel for Arch Linux and Hyprland, built with Quickshell (QML/Wayland).

## Features
- **Slide-in Panel**: Seamlessly slides from the left edge.
- **AI Integration**: Supports OpenAI-compatible endpoints.
- **Multimedia Support**: Drag and drop images, audio, and files.
- **Session Persistence**: Chat history is saved across restarts.
- **Markdown Support**: Basic rendering of bold, italic, and code blocks.
- **SearXNG integration**: Ask your AI to search the web and recieve summarized answers.
- **Wayland Optimized**: Uses Layer Shell for proper placement and focus.

## Installation & Usage

1. **Install Quickshell**: Ensure `quickshell` is installed on your system.
2. **Configure the API**:
   - Open the panel's settings.
   - Enter your API endpoint and key, then click **Save**.
   - Expand **SearXNG** to configure web search settings.
   - Defaults are defined in `src/Config.qml`; the active model can be changed from the model picker.
3. **Run the Panel**:
   ```bash
   quickshell -p /path/to/aichat_qs/shell.qml
   ```
4. **Hyprland Keybinding**:
   Add the following to your `hyprland.conf` to toggle the panel:
   ```hyprlang
   # If running with a specific path, you may need to specify it or use the global target
   bind = SUPER, Space, exec, quickshell ipc call chat toggle
   ```
   *Note: If `quickshell ipc call chat toggle` fails, ensure the panel is already running and try `quickshell ipc chat toggle` or check `quickshell --help` for the correct IPC syntax on your version.*

## Development Structure
- `shell.qml`: Main entry point and IPC handling.
- `src/MainPanel.qml`: Core UI and chat logic.
- `src/Config.qml`: User configuration and themes.
- `src/ApiClient.js`: API interaction logic.
- `src/`: Contains other QML components and scripts.

## Advanced
- **Drag and Drop**: Drag files onto the panel to attach them.
- **Clear Chat**: Use the "Clear" button to reset the current session.
- **Attachments**: Images are sent as multimodal content (if supported by the model).
