# Linux Troubleshooter

Linux Troubleshooter is a lightweight Bash script that provides a quick overview of a Linux server's health.

It helps system administrators identify common issues in seconds by collecting the most important troubleshooting information in a clean, readable report.

## Features

- System summary
- CPU load analysis
- Top CPU-consuming process
- Top memory-consuming process
- Memory and swap usage
- Disk usage warnings
- Failed systemd services
- High CPU/RAM process detection
- Recent critical system logs
- OOM Killer detection
- Network listening ports
- Final health summary

## Requirements

- Linux
- Bash
- systemd (recommended)
- journalctl
- ps
- ss

## Usage

```bash
chmod +x troubleshoot.sh
./troubleshoot.sh
```

## Example

The script generates a structured report that helps quickly identify:

- High CPU load
- Memory pressure
- Disk space issues
- Failed services
- Kernel or OOM events
- Long-running resource-intensive processes
