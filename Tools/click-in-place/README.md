# Click-in-Place

A Python program that detects the exact position of a mouse click and automatically simulates repeated clicks at the same position with a configurable interval.

## Features

- **Click Detection**: Detects the exact position of left mouse clicks
- **Auto-Clicking**: Automatically repeats clicks at the detected position
- **Configurable Interval**: Set the time between repeated clicks
- **Detailed Logging**: Comprehensive logging with configurable log levels
- **Easy Control**: Simple keyboard shortcuts to start/stop

## Requirements

- Python 3.6 or higher
- `pynput` library

## Installation

1. Install the required dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage

Run the program with default settings (1 second interval):
```bash
python click_in_place.py
```

### Custom Interval

Set a custom interval between clicks (in seconds):
```bash
python click_in_place.py --interval 0.5
```

### Debug Logging

Enable detailed debug logging:
```bash
python click_in_place.py --log-level DEBUG
```

### Command Line Options

- `--interval FLOAT`: Time in seconds between repeated clicks (default: 1.0)
- `--log-level LEVEL`: Logging level - DEBUG, INFO, WARNING, or ERROR (default: INFO)

## How to Use

1. **Start the program**: Run `python click_in_place.py` with your desired options
2. **Record click position**: Left-click anywhere on the screen to record that position
3. **Auto-clicking starts**: The program will automatically start clicking at that position
4. **Change position**: Left-click at a new position to change the click target
5. **Stop clicking**: Press the ESC key to stop auto-clicking

## Logging

The program provides detailed logging with timestamps:
- **INFO**: General information about clicks, start/stop events
- **DEBUG**: Detailed information including mouse movements
- **WARNING**: Non-critical issues (e.g., clicking already active)
- **ERROR**: Errors and exceptions

## Examples

```bash
# Click every 0.5 seconds
python click_in_place.py --interval 0.5

# Click every 2 seconds with debug logging
python click_in_place.py --interval 2.0 --log-level DEBUG

# Quick clicks (0.1 seconds) with minimal logging
python click_in_place.py --interval 0.1 --log-level WARNING
```

## Notes

- The program requires appropriate permissions to control the mouse
- On some systems, you may need to run with administrator/sudo privileges
- The ESC key stops the auto-clicking but keeps the program running to detect new clicks
- Use Ctrl+C to completely exit the program

## License

This project is provided as-is for educational and personal use.

