# Kali Linux Desktop on the Browser

This repository contains a Docker Compose application that runs a Kali Linux desktop accessible through your web browser via NoVNC, with integrated development tools and security utilities.

![Screenshot](.github/images/screenshoot.png)

## Description

This Docker Compose application provides:

- **Kali Linux Desktop**: A complete XFCE desktop environment accessible via web browser
  - Default VNC password: `kalilinux`
  - NoVNC web interface: Port `8080`
  - VS Code Server: Port `8088` for remote development
  
- **Development Environment**: 
  - Go 1.25.1
  - Visual Studio Code with remote server capability
  - Python 2 & 3 development environment
  - Modern terminal setup with zsh and tmux

- **Security Tools**: Pre-configured Kali Linux tools for security research and penetration testing

- **Automated Configuration**: Personal dotfiles and development environment setup via bootstrap scripts

## Requirements

To run this application, you need:

- Docker Engine
- Docker Compose

## Usage

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/sunick2009/kalilinux-docker.git
   ```

2. Navigate to the repository directory:
   ```bash
   cd kalilinux-docker
   ```

3. Pull the required Docker images:
   ```bash
   docker compose pull
   ```

4. Set a custom password for the environment (optional):
   ```bash
   export PASSWORD="YourVNCPassword"
   ```

5. Start the containers in detached mode:
   ```bash
   docker compose up -d
   ```

6. Access the web application:
   - **Kali Desktop via NoVNC**: http://localhost:8080/vnc.html
   - **VS Code Server**: http://localhost:8088 (for remote development)

### Advanced Usage

#### Custom Workspace Mapping
Edit `docker-compose.yml` to map your local projects:
```yaml
volumes:
  - /path/to/your/project:/home/kali/workspace
```

#### Dotfiles Configuration
The container automatically configures the development environment using personal dotfiles:
- Repository: `https://github.com/sunick2009/my-dotfiles`
- Automatic setup on first run
- Skip installation: Set `DOTFILES_DISABLE=1`
- Force reinstall: Set `DOTFILES_FORCE=1`

## Environment Variables

You can customize the application using these environment variables:

### Core Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `PASSWORD` | VNC password | `kalilinux` |
| `BIND` | Address and port to bind the NoVNC server | `0.0.0.0:8080` |
| `GEOMETRY` | Desktop resolution | `1920x1080` |
| `TZ` | Timezone | `Asia/Taipei` |

### Dotfiles Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `DOTFILES_FORCE` | Force reinstall dotfiles | `0` |
| `DOTFILES_DISABLE` | Skip dotfiles installation | `0` |
| `BOOTSTRAP_STRICT` | Fail if bootstrap fails | `1` |
| `DOTFILES_SKIP_NVIM` | Skip Neovim installation | `1` |

### Example Usage
```bash
export PASSWORD="mysecretpassword"
export BIND="0.0.0.0:9090"
export GEOMETRY="1600x900"
export DOTFILES_FORCE="1"
docker compose up -d
```

## Pre-installed Tools

### Development Tools
- **Go 1.25.1**: Complete Go development environment
- **Visual Studio Code**: Both desktop and server versions
- **Python 2 & 3**: With development libraries
- **Git, Vim, Neovim**: Standard development tools

### Security Tools
- **Go-based tools**: subfinder, dnsx, chaos (in `/home/kali/go/bin`)
- **Kali Linux tools**: Standard Kali security toolkit
- **Network tools**: ping, curl, net-tools

### Desktop Environment
- **XFCE4**: Lightweight desktop environment
- **Firefox ESR**: Security-focused browser
- **Terminal**: zsh with oh-my-zsh configuration

## Troubleshooting

### Common Issues

**VNC Connection Problems:**
```bash
# Check VNC server status
docker compose exec kalilinux vncserver -list

# Restart VNC service
docker compose restart kalilinux
```

**VS Code Server Issues:**
```bash
# Check if port 8088 is accessible
curl http://localhost:8088

# Check container logs
docker compose logs kalilinux
```

**Go Tools Not Found:**
```bash
# Verify Go environment
docker compose exec kalilinux go version
docker compose exec kalilinux echo $GOPATH

# Check installed tools
ls /home/kali/go/bin/
```

## License

This Docker Compose application is released under the MIT License. See the [LICENSE](https://www.mit.edu/~amini/LICENSE.md) file for details.

## Disclaimer

The software developed and distributed for hacking purposes is intended for **educational and testing purposes only**. The use of this software for any illegal activity is strictly prohibited. The developers and distributors of the software are not liable for any damages or legal consequences resulting from the misuse of the software.
