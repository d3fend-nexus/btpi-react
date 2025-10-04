# BTPI-REACT Security Guide

## 🛡️ Repository Security

This repository is protected by comprehensive pre-commit hooks and security measures to prevent accidental exposure of sensitive data.

## 🚨 Critical Security Rules

### 1. **Never Commit Sensitive Data**
The following files/data should NEVER be committed:
- `.env` files containing actual secrets
- SSL certificates and private keys (`.key`, `.pem`, `.p12`, `.pfx`)
- Database passwords or API keys
- Service account credentials
- Production configuration files with real data

### 2. **Protected Files**
These file patterns are automatically blocked by pre-commit hooks:
```
config/.env
*.key
*.pem
*.p12
*.pfx
*secrets.*
*credentials.*
*.keystore
*.jks
```

### 3. **Safe Configuration Practices**
- Use `config/.env.example` as template
- Generate real secrets during deployment
- Use environment variables for sensitive data
- Document configuration in README, not in code

## 🔧 Pre-commit Hooks Active

### Security Hooks
- **detect-secrets**: Scans for API keys, tokens, passwords
- **detect-private-key**: Blocks private key files
- **detect-aws-credentials**: Blocks AWS credential files
- **block-env-files**: Prevents .env files with secrets
- **block-sensitive-files**: Blocks certificate and key files

### Quality Hooks
- **shellcheck**: Validates shell script syntax and security
- **hadolint**: Docker security and best practices
- **check-yaml/json**: Syntax validation for config files
- **check-added-large-files**: Prevents commits >10MB
- **scan-hardcoded-ips**: Detects hardcoded IP addresses

### File Hygiene
- **end-of-file-fixer**: Ensures files end with newline
- **trailing-whitespace**: Removes trailing spaces
- **mixed-line-ending**: Standardizes line endings

## 🔍 Security Scanning

### Manual Security Scan
```bash
# Check for secrets (requires detect-secrets)
detect-secrets scan --all-files

# Check shell scripts
find . -name "*.sh" -not -path "./archive/*" -exec shellcheck {} \;

# Check for hardcoded secrets
grep -r "password\|secret\|key" --exclude-dir=archive --exclude-dir=logs .
```

### Automated Scanning
Pre-commit hooks run automatically on `git commit` and will:
- ✅ Block commits with detected secrets
- ✅ Validate all shell scripts
- ✅ Check Docker files for security issues
- ✅ Prevent large file commits

## 📋 Pre-deployment Security Checklist

Before deploying BTPI-React:

### Environment Security
- [ ] Generate fresh secrets for production
- [ ] Use strong passwords (16+ chars, mixed case, numbers, symbols)
- [ ] Enable SSL/TLS for all services
- [ ] Configure firewall rules
- [ ] Change all default credentials

### Network Security
- [ ] Restrict access to management interfaces
- [ ] Use VPN for remote access
- [ ] Configure proper network segmentation
- [ ] Enable audit logging

### Container Security
- [ ] Use non-root users in containers where possible
- [ ] Keep container images updated
- [ ] Scan images for vulnerabilities
- [ ] Limit container privileges

## 🔐 Secret Management Best Practices

### Development Environment
```bash
# Create your local .env file
cp config/.env.example config/.env

# Edit with your development values
nano config/.env

# The .env file is automatically ignored by git
```

### Production Environment
```bash
# Generate production secrets
openssl rand -base64 32  # For passwords
openssl rand -hex 32     # For API keys
openssl rand -base64 64  # For JWT secrets
```

### Environment Variables Reference
| Variable | Purpose | Example |
|----------|---------|---------|
| `VELOCIRAPTOR_PASSWORD` | Velociraptor admin password | `$(openssl rand -base64 32)` |
| `WAZUH_API_PASSWORD` | Wazuh API access password | `$(openssl rand -base64 32)` |
| `ELASTIC_PASSWORD` | Elasticsearch password | `$(openssl rand -base64 32)` |
| `JWT_SECRET` | JWT signing secret | `$(openssl rand -base64 64)` |
| `SERVER_IP` | Server IP address | `192.168.1.100` # IP-OK |

## 🚨 Security Incident Response

### If Secrets Are Accidentally Committed
1. **Immediate Actions**:
   ```bash
   # Remove from git history
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch config/.env' HEAD

   # Force push (if you control all clones)
   git push --force-with-lease
   ```

2. **Rotate All Secrets**:
   - Change all passwords immediately
   - Generate new API keys
   - Update production systems
   - Monitor for unauthorized access

### Reporting Security Issues
- **Internal**: Document in `logs/security-incidents.log`
- **External**: Create GitHub security advisory
- **Critical**: Follow incident response procedures

## 🔄 Maintenance

### Weekly Security Tasks
- Review audit logs
- Update dependencies
- Scan for new vulnerabilities
- Review access permissions

### Monthly Security Tasks
- Rotate service passwords
- Update SSL certificates
- Review and update security policies
- Conduct security assessments

## 📞 Security Support

### Tools and Resources
- **Pre-commit hooks**: Automated protection
- **Secrets scanning**: Detect-secrets framework
- **Shell validation**: ShellCheck integration
- **Docker security**: Hadolint validation

### Getting Help
- Check `SECURITY.md` for guidelines
- Review pre-commit errors carefully
- Use `.env.example` as template
- Generate secrets during deployment

## 🏆 Security Compliance

This repository implements:
- ✅ **Secret Detection**: Automated scanning
- ✅ **Access Control**: File-level permissions
- ✅ **Code Quality**: Shell script validation
- ✅ **Container Security**: Docker best practices
- ✅ **Network Security**: Documented network policies
- ✅ **Incident Response**: Clear procedures

---

**Remember**: Security is everyone's responsibility. When in doubt, ask before committing!
