# AGENTS.md - Development and Security Environment Guide

## Project Overview

This project provides a highly customized Kali Linux Docker environment designed for security research, penetration testing, and development work. It features browser-based access via NoVNC and integrates multiple development and security tools in a containerized environment.

### Architecture Components

**Core Services:**
- **NoVNC Web Desktop**: Browser-accessible Kali Linux XFCE desktop environment
- **VS Code Server**: Remote development environment with full IDE capabilities
- **TigerVNC Server**: Underlying VNC service providing desktop functionality
- **Automated Configuration**: Personal dotfiles and environment bootstrap system

**Development Environment:**
- **Go 1.25.1**: Complete Go development setup with pre-installed security tools
- **Python 2 & 3**: Full Python development environment
- **Visual Studio Code**: Both desktop and server versions available
- **Modern Shell**: zsh with oh-my-zsh configuration and tmux multiplexer

**Security Tools:**
- **Pre-installed Go Tools**: subfinder, dnsx, chaos for reconnaissance
- **Kali Linux Toolkit**: Standard penetration testing and security analysis tools
- **Network Utilities**: Comprehensive networking and analysis tools

**Infrastructure:**
- **Persistent Storage**: Home directory and configuration persistence
- **Workspace Mapping**: Local project synchronization capabilities
- **Service Discovery**: Automated health checks and service monitoring

## Build and Test Commands

### Building the Environment

```bash
# Clone the repository
git clone https://github.com/sunick2009/kalilinux-docker.git
cd kalilinux-docker

# Build the Docker image
docker compose build

# Pull pre-built images (alternative)
docker compose pull
```

### Running the Environment

```bash
# Start services in detached mode
docker compose up -d

# Start with custom configuration
export PASSWORD="your-secure-password"
export GEOMETRY="1920x1080"
export BIND="0.0.0.0:8080"
docker compose up -d

# Force dotfiles reinstallation
export DOTFILES_FORCE=1
docker compose up -d
```

### Service Access

```bash
# Access NoVNC web desktop
open http://localhost:8080/vnc.html

# Access VS Code Server
open http://localhost:8088

# Execute commands in container
docker compose exec kalilinux /bin/zsh
```

### Testing Commands

```bash
# Test VNC service
docker compose exec kalilinux vncserver -list

# Test Go environment
docker compose exec kalilinux go version
docker compose exec kalilinux ls /home/kali/go/bin/

# Test installed security tools
docker compose exec kalilinux subfinder -version
docker compose exec kalilinux dnsx -version
docker compose exec kalilinux chaos -version

# Test network connectivity
docker compose exec kalilinux ping -c 3 google.com

# Test Python environments
docker compose exec kalilinux python2 --version
docker compose exec kalilinux python3 --version
```

### Debugging and Logs

```bash
# View container logs
docker compose logs kalilinux

# Follow real-time logs
docker compose logs -f kalilinux

# Check service status
docker compose ps

# Inspect container
docker compose exec kalilinux ps aux
docker compose exec kalilinux ss -tlnp
```

## Code Style Guidelines

### Docker Configuration

**Dockerfile Best Practices:**
- Use multi-stage builds where appropriate
- Minimize layer count and image size
- Clean package manager caches after installation
- Set appropriate user permissions and ownership
- Use specific version tags for base images

**Docker Compose Standards:**
- Use meaningful service names
- Define explicit port mappings
- Implement proper volume management
- Set clear environment variable defaults
- Include necessary security capabilities

### Shell Script Standards

**Bootstrap Scripts (`bootstrap-dotfiles.sh`, `entrypoint.sh`):**
- Use `set -euo pipefail` for error handling
- Implement proper logging with prefixed messages
- Handle edge cases and provide fallback options
- Use meaningful variable names with clear scope
- Include comprehensive error handling

**Environment Configuration:**
- Prefix custom environment variables appropriately
- Provide sensible defaults for all configurations
- Document all available configuration options
- Implement validation for critical parameters

### Configuration Management

**Dotfiles Integration:**
- Maintain clean separation between personal and system configs
- Implement safe takeover mechanisms for existing configurations
- Provide backup options for overwritten files
- Use version control for configuration tracking

## Testing Instructions

### Pre-deployment Testing

**Image Build Verification:**
```bash
# Test image builds successfully
docker compose build --no-cache

# Verify image size and layers
docker images | grep kalilinux-docker
docker history kalilinux-docker-vnc-custom:latest
```

**Service Startup Testing:**
```bash
# Test clean startup
docker compose down -v
docker compose up -d

# Verify all services are running
docker compose ps
docker compose logs --tail=50 kalilinux
```

### Functional Testing

**Desktop Environment:**
```bash
# Test VNC connectivity
vncviewer localhost:5901

# Test NoVNC web interface
curl -I http://localhost:8080/vnc.html

# Test resolution settings
export GEOMETRY="1600x900"
docker compose restart kalilinux
```

**Development Environment:**
```bash
# Test Go installation and tools
docker compose exec kalilinux go env
docker compose exec kalilinux which subfinder dnsx chaos

# Test VS Code Server
curl -I http://localhost:8088
docker compose exec kalilinux code --version
```

**Dotfiles Configuration:**
```bash
# Test dotfiles installation
docker compose exec kalilinux ls -la ~/.config
docker compose exec kalilinux zsh --version

# Test forced reinstallation
export DOTFILES_FORCE=1
docker compose restart kalilinux
```

### Integration Testing

**Workspace Mapping:**
```bash
# Create test file in mapped directory
echo "test content" > /Users/susu/Code/sub-domain-automating/test.txt
docker compose exec kalilinux cat /home/kali/sub-domain-automating/test.txt
```

**Persistence Testing:**
```bash
# Test data persistence
docker compose exec kalilinux touch /home/kali/persistent-test
docker compose restart kalilinux
docker compose exec kalilinux ls /home/kali/persistent-test
```

### Performance Testing

**Resource Usage:**
```bash
# Monitor resource consumption
docker stats kalilinux-docker-kalilinux-1

# Test memory and CPU limits
docker compose exec kalilinux htop
```

## Security Considerations

### Access Control

**Authentication Security:**
- **Default Credentials**: Change default VNC password (`kalilinux`) in production
- **Network Exposure**: Limit service exposure to trusted networks only
- **Container Isolation**: Services run in isolated container environment
- **User Privileges**: Container runs with non-root user (`kali`) by default

**Network Security:**
- **Port Binding**: Default binding to all interfaces (`0.0.0.0`) - restrict in production
- **Service Ports**: 
  - 8080 (NoVNC) - Web desktop access
  - 8088 (VS Code) - Development server
  - 5901 (VNC) - Internal only, not exposed
- **Container Capabilities**: `NET_ADMIN` capability enabled for security testing

### Data Protection

**Persistent Data:**
- **Volume Security**: Named volumes for persistent storage
- **Sensitive Data**: Avoid storing secrets in environment variables
- **Backup Strategy**: Implement regular backups of persistent volumes
- **Encryption**: Consider encrypting sensitive data at rest

**Configuration Security:**
- **Dotfiles Repository**: Uses public repository - avoid sensitive information
- **Environment Variables**: Sanitize environment variable exposure
- **File Permissions**: Proper file ownership and permissions in container

### Runtime Security

**Container Security:**
- **Image Updates**: Regularly update base images and packages
- **Vulnerability Scanning**: Implement container image scanning
- **Resource Limits**: Set appropriate CPU and memory limits
- **Security Monitoring**: Monitor container behavior and access patterns

**Network Security:**
- **Firewall Rules**: Implement host-level firewall rules
- **VPN Access**: Consider VPN-only access for remote usage
- **SSL/TLS**: Implement HTTPS for web services in production
- **Access Logging**: Enable and monitor access logs

### Best Practices

**Operational Security:**
1. **Regular Updates**: Keep container images and tools updated
2. **Strong Authentication**: Use strong passwords and consider multi-factor authentication
3. **Network Segmentation**: Isolate security testing environment
4. **Audit Logging**: Enable comprehensive logging and monitoring
5. **Incident Response**: Develop incident response procedures

**Development Security:**
1. **Code Review**: Review configuration changes and scripts
2. **Secrets Management**: Use proper secrets management solutions
3. **Least Privilege**: Apply principle of least privilege
4. **Security Testing**: Regular security testing of the environment
5. **Documentation**: Maintain up-to-date security documentation

### Compliance and Governance

**Security Policies:**
- Implement organizational security policies
- Regular security assessments and penetration testing
- Compliance with relevant security frameworks
- Documentation of security controls and procedures

**Risk Management:**
- Assess and document security risks
- Implement appropriate risk mitigation strategies
- Regular review and update of security measures
- Incident reporting and response procedures

---

*This guide provides comprehensive information for developing, testing, and securely operating the Kali Linux Docker environment. For questions or contributions, please submit issues or contact the maintainers.*