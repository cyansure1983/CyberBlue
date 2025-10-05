# 🔍 Arkime Enhancements & PCAP Generation Guide

Comprehensive guide for the enhanced Arkime setup, live traffic capture, and PCAP generation capabilities in CyberBlueSOC.

---

## 🎯 Overview

CyberBlueSOC now includes advanced Arkime capabilities with live traffic capture, real-time monitoring, and flexible PCAP generation. These enhancements provide Blue Teams with powerful network analysis tools that integrate seamlessly with the platform.

---

## 🚀 **Enhanced Arkime Features**

### **1. Live Traffic Capture**
- **Real-time network capture** with customizable durations
- **Background processing** with live progress monitoring
- **Auto-cleanup** of PCAP files after processing
- **Dynamic interface detection** for any environment

### **2. Flexible Duration Control**
- **Default 1-minute** captures for quick analysis
- **Custom durations** from seconds to hours
- **Multiple format support** (30s, 5min, 300, etc.)
- **Intelligent time parsing** and display

### **3. Production-Ready Operation**
- **Timeout protection** prevents hanging
- **Clean process termination** with Ctrl+C support
- **Error handling** for corrupted or incomplete captures
- **Resource management** with automatic cleanup

---

## 🛠️ **Available Scripts**

### **1. fix-arkime.sh - Enhanced Arkime Setup**

**Purpose**: Comprehensive Arkime setup, troubleshooting, and live capture

**Location**: `/fix-arkime.sh`

**Usage**:
```bash
# Basic setup (no live capture)
./fix-arkime.sh

# Default 1-minute live capture
./fix-arkime.sh --live

# Custom duration captures
./fix-arkime.sh --live-30s          # 30 seconds
./fix-arkime.sh --live-5min         # 5 minutes
./fix-arkime.sh --live-600          # 600 seconds (10 minutes)

# Using time flag
./fix-arkime.sh -t 2min             # 2 minutes
./fix-arkime.sh -t 45s              # 45 seconds
./fix-arkime.sh --time 300          # 300 seconds

# Force database reinitialization
./fix-arkime.sh --force

# Combined options
./fix-arkime.sh --live-5min --force
```

### **2. generate-pcap-for-arkime.sh - PCAP Generator Alias**

**Purpose**: Convenient alias for PCAP generation (same as fix-arkime.sh)

**Location**: `/generate-pcap-for-arkime.sh` → `/fix-arkime.sh` (symlink)

**Usage**: *Same as fix-arkime.sh - all options work identically*
```bash
# Default 1-minute capture
./generate-pcap-for-arkime.sh --live

# Custom durations  
./generate-pcap-for-arkime.sh --live-30s
./generate-pcap-for-arkime.sh --live-5min
./generate-pcap-for-arkime.sh -t 2min

# Force database setup + capture
./generate-pcap-for-arkime.sh --force --live
```

**Note**: This is a symlink to `fix-arkime.sh` - both scripts are identical and provide the same functionality.

---

## 📋 **Command Reference**

### **Duration Formats**

| Format | Example | Description |
|--------|---------|-------------|
| `Ns` | `30s`, `45s` | Seconds |
| `Nmin` | `5min`, `10min` | Minutes |
| `Nm` | `5m`, `10m` | Minutes (short) |
| `N` | `60`, `300` | Seconds (default unit) |

### **Common Use Cases**

| Scenario | Command | Duration | Purpose |
|----------|---------|----------|---------|
| **Quick Test** | `--live-30s` | 30 seconds | Verify Arkime functionality |
| **Standard Analysis** | `--live` | 1 minute | Default investigation |
| **Deep Investigation** | `--live-10min` | 10 minutes | Extended analysis |
| **Incident Response** | `-t 30min` | 30 minutes | Major incident analysis |
| **Continuous Monitoring** | `--keep-files` | Custom | Long-term monitoring |

---

## 🔧 **Technical Implementation**

### **Network Interface Detection**

The scripts automatically detect the primary network interface using multiple methods:

```bash
# Method 1: Default route interface (most reliable)
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# Method 2: First active non-loopback interface
INTERFACE=$(ip link show | grep -E '^[0-9]+:' | grep -v lo | grep 'state UP' | awk -F': ' '{print $2}' | head -1)

# Method 3: Any UP interface except loopback
INTERFACE=$(ip a | grep 'state UP' | grep -v lo | awk -F: '{print $2}' | head -1 | xargs)

# Fallback: Common AWS default
INTERFACE="ens5"
```

### **Live Capture Process**

```bash
# Background capture with timeout
timeout ${DURATION}s tcpdump -i "$INTERFACE" -w "$PCAP_FILE" &
TCPDUMP_PID=$!

# Real-time monitoring loop
while kill -0 $TCPDUMP_PID 2>/dev/null; do
    # Show file size growth
    CURRENT_SIZE=$(stat --format=%s "$PCAP_FILE")
    
    # Check Arkime document count
    DOCS=$(curl -s "http://os01:9200/_cat/indices/arkime*?h=docs.count")
    
    # Display progress
    echo "⏰ ${ELAPSED}s | 📦 ${SIZE}MB | 📈 Docs: ${DOCS} | ⏳ ${REMAINING}s left"
    
    sleep 10
done
```

### **PCAP Processing**

```bash
# Process PCAP into Arkime with timeout protection
timeout 30s docker exec arkime /opt/arkime/bin/capture \
    -c /opt/arkime/etc/config.ini \
    -r "/data/pcap/$PCAP_FILE"
```

---

## 📊 **Real-Time Monitoring Output**

### **Progress Display Format**
```
⏰ 20s | 📦 2MB (+1024KB) | 📈 Docs: 45 (+22) | ⏳ 40s left
```

**Legend**:
- **⏰ Time**: Elapsed capture time
- **📦 Size**: Current PCAP file size (+ growth since last update)
- **📈 Docs**: Total Arkime documents (+ new documents)
- **⏳ Remaining**: Time left in capture

### **Status Indicators**

| Status | Meaning |
|--------|---------|
| `📊 Capture progress` | File is growing, capture active |
| `📈 Docs: 123 (+45)` | Arkime is indexing data |
| `⏳ Indices creating...` | Arkime initializing indices |
| `🛑 Stopping capture` | Clean termination |
| `✅ PCAP data processed` | Successfully imported to Arkime |

---

## 🔒 **Security Considerations**

### **Network Interface Access**
- Requires **sudo privileges** for tcpdump
- Uses **promiscuous mode** for complete packet capture
- **Network interface detection** respects system security

### **Data Protection**
- **Auto-cleanup** prevents sensitive data accumulation
- **Timeout protection** prevents resource exhaustion
- **Process isolation** within Docker containers

### **Access Control**
- **Arkime authentication** required (admin/admin)
- **Docker network isolation** for security
- **SSL/TLS encryption** for web interface access

---

## 🚨 **Troubleshooting**

### **Common Issues**

#### **"Interface not detected"**
```bash
# Manual interface specification
echo "SURICATA_INT=eth0" >> .env
./fix-arkime.sh --live
```

#### **"tcpdump permission denied"**
```bash
# Add user to appropriate groups
sudo usermod -aG wireshark $USER
newgrp wireshark
```

#### **"No data in Arkime web interface"**
```bash
# Check time range in Arkime web interface
# Set to "Last Hour" or "Last 24 Hours"

# Verify data is indexed
sudo docker exec arkime curl -s "http://os01:9200/_cat/indices/arkime*"
```

#### **"PCAP file truncated"**
```bash
# Normal for live captures - Arkime processes what it can
# Use longer capture durations for complete sessions
./fix-arkime.sh --live-2min
```

#### **"Script hanging"**
```bash
# All operations now have timeout protection
# Use Ctrl+C to interrupt safely
# Check logs: sudo docker logs arkime
```

### **Diagnostic Commands**

```bash
# Check Arkime container status
sudo docker ps | grep arkime

# Check OpenSearch connectivity
sudo docker exec arkime curl -s http://os01:9200/_cluster/health

# View Arkime logs
sudo docker logs arkime

# Check network interfaces
ip link show

# Test network capture
sudo tcpdump -i ens5 -c 10
```

---

## 📈 **Performance Optimization**

### **Capture Duration Guidelines**

| Use Case | Recommended Duration | Reasoning |
|----------|---------------------|-----------|
| **Quick Test** | 30s | Verify functionality |
| **Standard Analysis** | 1-2min | Balance data/time |
| **Deep Investigation** | 5-10min | Comprehensive analysis |
| **Incident Response** | 15-30min | Full incident scope |
| **Baseline Creation** | 1-2 hours | Normal traffic patterns |

### **Resource Management**

```bash
# Monitor disk usage during capture
df -h ./arkime/pcaps/

# Check memory usage
sudo docker stats arkime

# Network interface statistics
cat /proc/net/dev
```

---

## 🔄 **Integration with CyberBlue Platform**

### **Automatic Integration**
- **cyberblue_init.sh** automatically calls `fix-arkime.sh --live-30s`
- **30-second live capture** during platform initialization
- **Real network data** available immediately after deployment

### **Manual Operations**
```bash
# Standalone Arkime setup
./fix-arkime.sh --live-5min

# Generate PCAP for analysis
./generate-pcap-for-arkime.sh --duration 10min

# Troubleshoot Arkime issues
./fix-arkime.sh --force
```

### **API Integration**
```bash
# Trigger capture via API (future enhancement)
curl -X POST http://localhost:5443/api/arkime/capture \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"duration": "5min"}'
```

---

## 📚 **Advanced Usage**

### **Batch PCAP Generation**
```bash
#!/bin/bash
# Generate multiple PCAP files for different scenarios

# Business hours traffic
./generate-pcap-for-arkime.sh --duration 1min --keep-files
mv ./arkime/pcaps/*.pcap ./arkime/pcaps/business_hours_$(date +%H%M).pcap

# After hours traffic  
./generate-pcap-for-arkime.sh --duration 30s --keep-files
mv ./arkime/pcaps/*.pcap ./arkime/pcaps/after_hours_$(date +%H%M).pcap
```

### **Continuous Monitoring Setup**
```bash
#!/bin/bash
# Continuous 5-minute captures with 1-minute gaps

while true; do
    echo "Starting 5-minute capture cycle..."
    ./generate-pcap-for-arkime.sh --duration 5min
    echo "Waiting 1 minute before next capture..."
    sleep 60
done
```

### **Incident Response Automation**
```bash
#!/bin/bash
# Emergency PCAP capture for incident response

INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
echo "🚨 Emergency capture for incident: $INCIDENT_ID"

# Extended capture for incident analysis
./generate-pcap-for-arkime.sh --duration 30min --keep-files

# Rename for incident tracking
mv ./arkime/pcaps/*.pcap "./arkime/pcaps/incident_${INCIDENT_ID}.pcap"

echo "📋 Incident PCAP saved: incident_${INCIDENT_ID}.pcap"
```

---

## 🔗 **Related Documentation**

- **[Arkime Setup Guide](ARKIME_SETUP.md)** - Original Arkime configuration
- **[Network Analysis Guide](USER_GUIDE.md#arkime-packet-analysis)** - Using Arkime for analysis
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions
- **[API Reference](API_REFERENCE.md)** - Portal API integration
- **[Security Guide](SECURITY.md)** - Security best practices

---

## 📞 **Support & Community**

### **Getting Help**
1. **Check logs**: `sudo docker logs arkime`
2. **Review troubleshooting**: Common issues above
3. **Test connectivity**: `sudo docker exec arkime curl http://os01:9200/_cluster/health`
4. **GitHub Issues**: [Report bugs or request features](https://github.com/CyberBlue0/CyberBlueSOC1/issues)
5. **Community**: [Join discussions](https://github.com/CyberBlue0/CyberBlueSOC1/discussions)

### **Contributing**
- **Submit improvements** to Arkime scripts
- **Share PCAP generation techniques**
- **Report compatibility issues**
- **Suggest new features**

---

*Last Updated: August 31, 2025*
*Version: CyberBlueSOC 1.4 Enhanced*
