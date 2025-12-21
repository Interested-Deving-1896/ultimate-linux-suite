# TUI Advanced Library Documentation

## Overview

The `tui_advanced.sh` library provides sophisticated Terminal User Interface components for the Ultimate Linux Suite. It builds upon the basic `tui.sh` library with advanced features specifically designed for application installation, system scanning, and complex menu navigation.

**File:** `/var/home/mintys/ultimate-linux-suite/lib/tui_advanced.sh`
**Lines:** 1,438
**Functions:** 31
**Dependencies:** `logging.sh`, `tui.sh`

## Key Features

### 1. Application Browser and Installation
- Category-based application browsing
- Multi-select with search functionality
- Installation status tracking
- Support for multiple installation methods (native, flatpak, snap, appimage)
- Real-time progress display
- Batch installation with individual status tracking

### 2. Advanced Menu Navigation
- Hierarchical category menus
- Breadcrumb navigation
- Tree-style selection
- Grouped multi-select

### 3. Progress Tracking
- Multiple simultaneous progress bars
- Task lists with status icons
- Real-time log viewer
- Step-by-step wizard interface

### 4. Display Components
- Formatted tables
- Key-value pair displays
- Multi-column lists
- Styled boxes with borders
- Application detail cards

### 5. System Management
- Hardware scan display
- Optimization preview with toggles
- Queue management (view, reorder, execute)

### 6. File Operations
- File picker with preview
- Directory picker
- Text editor integration

## Function Reference

### Helper Functions

| Function | Description |
|----------|-------------|
| `tui_truncate TEXT WIDTH` | Truncate text with ellipsis |
| `tui_wrap TEXT WIDTH` | Wrap text to specified width |
| `tui_format_bytes BYTES` | Convert bytes to human-readable format |
| `tui_pad TEXT WIDTH ALIGN` | Pad string (left/right/center) |
| `tui_box TITLE WIDTH CONTENT` | Draw bordered box with title |

### State Management

| Function | Description |
|----------|-------------|
| `tui_state_save NAME` | Save TUI state to temp file |
| `tui_state_restore NAME` | Restore TUI state from temp file |

### Navigation Menus

| Function | Description |
|----------|-------------|
| `tui_category_menu TITLE CATEGORY_DATA` | Hierarchical category navigation |
| `tui_breadcrumb_menu PATH_ARRAY ITEMS` | Breadcrumb-style navigation |
| `tui_tree_select ROOT_NODE` | Tree-style selection |

### Enhanced Selection

| Function | Description |
|----------|-------------|
| `tui_multiselect_search TITLE ITEMS...` | Multi-select with fuzzy search |
| `tui_select_all TITLE ITEMS...` | Multi-select with select/deselect all |
| `tui_grouped_select TITLE GROUPS...` | Grouped checkbox selection |

### Progress Display

| Function | Description |
|----------|-------------|
| `tui_progress_multi TASK_ARRAY` | Multiple progress bars |
| `tui_task_list TITLE TASKS...` | Task list with status icons |
| `tui_log_viewer LOG_FILE [TITLE]` | Scrollable log viewer |

### Tables and Lists

| Function | Description |
|----------|-------------|
| `tui_table HEADERS... -- DATA...` | Formatted table display |
| `tui_keyvalue KEY VAL...` | Key-value pair display |
| `tui_list_columns ITEMS...` | Multi-column list |

### Wizard Interface

| Function | Description |
|----------|-------------|
| `tui_step_indicator CURRENT TOTAL LABELS...` | Progress indicator |
| `tui_wizard STEPS_ARRAY` | Multi-step wizard with navigation |

### Application Browser (Core Feature)

| Function | Description |
|----------|-------------|
| `tui_app_card APP_NAME APP_DATA` | Display application details |
| `tui_app_browser APPS_ARRAY` | Browse and select applications |

### Installation Progress (Core Feature)

| Function | Description |
|----------|-------------|
| `tui_install_progress APP METHOD [LOG]` | Single app install progress |
| `tui_batch_install BATCH_ARRAY` | Batch installation tracker |

### System Management

| Function | Description |
|----------|-------------|
| `tui_scan_display SCAN_DATA` | Hardware detection results |
| `tui_optimization_preview OPT_ITEMS` | Preview optimizations with toggles |
| `tui_queue_view QUEUE_ITEMS` | Queue management interface |

### File Operations

| Function | Description |
|----------|-------------|
| `tui_file_picker TITLE [START_DIR]` | File selection dialog |
| `tui_dir_picker TITLE [START_DIR]` | Directory selection dialog |
| `tui_editor TITLE CONTENT` | Simple text editor |

## Usage Examples

### Application Browser

```bash
# Define applications
declare -A apps=(
    [firefox]="Web|Firefox|Fast browser|0|85 MB|native,flatpak"
    [vscode]="Dev|VS Code|Code editor|1|250 MB|native"
)

# Browse and select
selected=$(tui_app_browser apps)
```

### Batch Installation

```bash
declare -A batch=(
    [0]="Firefox|pending|flatpak"
    [1]="GIMP|running|native"
    [2]="VLC|complete|native"
)

tui_batch_install batch
```

### Wizard

```bash
declare -a steps=(
    "Welcome:step1_func"
    "Configure:step2_func"
    "Install:step3_func"
)

tui_wizard steps
```

### Tables

```bash
tui_table "Name" "Status" "Size" -- \
    "pkg1" "Installed" "1.2 MB" \
    "pkg2" "Available" "3.4 MB"
```

## Graceful Fallbacks

The library automatically detects available tools and provides fallbacks:

- **gum**: Preferred for modern, styled interfaces
- **fzf**: Used for fuzzy search and selection
- **dialog/whiptail**: Traditional TUI dialogs
- **Pure bash**: Fallback when no tools available

Detection flags:
- `TUI_HAS_GUM`
- `TUI_HAS_FZF`
- `TUI_HAS_DIALOG`
- `TUI_HAS_WHIPTAIL`

## Integration with Ultimate Linux Suite

### App Installer Module

The library is specifically designed to upgrade the app installer with:

1. **Category browsing** - Organize apps by type (Web, Development, Graphics, etc.)
2. **Status tracking** - Show which apps are already installed
3. **Method selection** - Support native, Flatpak, Snap, and AppImage
4. **Batch operations** - Install multiple apps with progress tracking
5. **Search functionality** - Find apps quickly with fuzzy search

### System Optimizer Module

Components for system optimization:

1. **Hardware scanning** - Display detected hardware in organized sections
2. **Optimization preview** - Show proposed changes before applying
3. **Toggle selection** - Enable/disable individual optimizations

### Queue System

Enhanced queue management for any module:

1. **Visual queue display** - See all queued operations
2. **Reordering** - Move items up/down
3. **Removal** - Remove unwanted items
4. **Execution** - Execute queue with confirmation

## Status Icons

The library uses Unicode icons for status indication:

- ⏳ Pending
- ⟳ Running (animated in some terminals)
- ✓ Complete (green)
- ✗ Failed (red)
- ● Current step (blue)
- ○ Future step

## Color Scheme

Inherits colors from `logging.sh`:

- **CYAN**: Titles, current selections
- **GREEN**: Success, completed items
- **YELLOW**: Warnings, running items
- **RED**: Errors, failed items
- **BLUE**: Information, navigation
- **BOLD**: Headers, emphasis

## Testing

A comprehensive test suite is available:

```bash
./test_tui_advanced.sh
```

Tests include:
1. Helper functions
2. Box display
3. Key-value pairs
4. Table display
5. Task list
6. Step indicator
7. App card
8. Batch installation
9. Multi-column list

## Performance

- Minimal dependencies (only bash, coreutils)
- Efficient text processing
- No external rendering engines
- Fast fallback mechanisms
- Lightweight state management

## Best Practices

1. **Always source dependencies** - Ensure `logging.sh` and `tui.sh` are loaded first
2. **Check tool availability** - Use detection flags before advanced features
3. **Provide fallbacks** - Don't require specific tools
4. **Clear state** - Clean up temp files with `tui_state_*` functions
5. **Handle errors** - Check return codes and provide user feedback
6. **Use appropriate components** - Match UI component to task complexity

## Future Enhancements

Potential additions:

- Mouse support (for terminals that support it)
- Custom color schemes
- Animation support
- Progress bar animations
- Configurable status icons
- Theme system
- Plugin architecture

## License

Part of the Ultimate Linux Suite - see main project license.

## Credits

Built for the Ultimate Linux Suite project with focus on the application installer upgrade and system optimization modules.
