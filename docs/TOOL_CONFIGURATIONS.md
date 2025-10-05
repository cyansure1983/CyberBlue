# ⚙️ CyberBlue Tool Configurations

Comprehensive configuration guide for all security tools in the CyberBlue platform.

---

## 🎯 Overview

This guide provides detailed configuration instructions, best practices, and advanced settings for each tool in the CyberBlue platform. Each section includes basic setup, advanced configurations, and integration with other tools.

---

## 🛡️ **SIEM & Monitoring Tools**

### Wazuh Configuration

#### Basic Manager Configuration
```xml
<!-- /opt/cyberblue/wazuh/config/wazuh_cluster/wazuh_manager.conf -->
<ossec_config>
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>no</logall>
    <logall_json>no</logall_json>
    <email_notification>no</email_notification>
    <smtp_server>localhost</smtp_server>
    <email_from>wazuh@cyberblue.local</email_from>
    <email_to>admin@cyberblue.local</email_to>
    <hostname>wazuh-manager</hostname>
    <email_maxperhour>12</email_maxperhour>
  </global>

  <alerts>
    <log_alert_level>3</log_alert_level>
    <email_alert_level>12</email_alert_level>
  </alerts>

  <remote>
    <connection>secure</connection>
    <port>1514</port>
    <protocol>tcp</protocol>
    <queue_size>131072</queue_size>
  </remote>

  <logging>
    <log_format>plain</log_format>
  </logging>
</ossec_config>
```

#### Custom Rules Configuration
```xml
<!-- /opt/cyberblue/wazuh/config/rules/local_rules.xml -->
<group name="local,attack,">
  <!-- SSH Brute Force Detection -->
  <rule id="100001" level="10" frequency="8" timeframe="120">
    <if_matched_sid>5716</if_matched_sid>
    <description>SSH brute force attack detected</description>
    <mitre>
      <id>T1110.001</id>
    </mitre>
    <group>authentication_failed,pci_dss_10.2.4,pci_dss_10.2.5,</group>
  </rule>

  <!-- Suspicious PowerShell Activity -->
  <rule id="100002" level="12">
    <if_sid>61603</if_sid>
    <field name="win.eventdata.commandLine">\.invoke|downloadstring|iex|invoke-expression</field>
    <description>Suspicious PowerShell command detected</description>
    <mitre>
      <id>T1059.001</id>
    </mitre>
  </rule>

  <!-- File Integrity Monitoring -->
  <rule id="100003" level="7">
    <if_sid>550</if_sid>
    <field name="file">/etc/passwd|/etc/shadow|/etc/hosts</field>
    <description>Critical system file modified</description>
    <mitre>
      <id>T1565.001</id>
    </mitre>
  </rule>
</group>
```

#### Agent Configuration
```xml
<!-- Agent ossec.conf template -->
<ossec_config>
  <client>
    <server>
      <address>WAZUH_MANAGER_IP</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>generic</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
  </client>

  <client_buffer>
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <!-- Log Analysis -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>

  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>

  <!-- File Integrity Monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>
    <auto_ignore frequency="10" timeframe="3600">no</auto_ignore>
    
    <!-- Directories to monitor -->
    <directories check_all="yes">/etc,/usr/bin,/usr/sbin</directories>
    <directories check_all="yes" restrict="regedit.exe$|system.ini$|win.ini$">%WINDIR%</directories>
    
    <!-- Files to ignore -->
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
  </syscheck>

  <!-- Rootkit Detection -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>
  </rootcheck>

  <!-- Security Configuration Assessment -->
  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
    <skip_nfs>yes</skip_nfs>
  </sca>
</ossec_config>
```

### Suricata Configuration

#### Main Configuration File
```yaml
# /opt/cyberblue/suricata/suricata.yaml
%YAML 1.1
---

vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"
    HTTP_SERVERS: "$HOME_NET"
    SMTP_SERVERS: "$HOME_NET"
    SQL_SERVERS: "$HOME_NET"
    DNS_SERVERS: "$HOME_NET"
    TELNET_SERVERS: "$HOME_NET"
    AIM_SERVERS: "$EXTERNAL_NET"
    DC_SERVERS: "$HOME_NET"
    DNP3_SERVER: "$HOME_NET"
    DNP3_CLIENT: "$HOME_NET"
    MODBUS_CLIENT: "$HOME_NET"
    MODBUS_SERVER: "$HOME_NET"
    ENIP_CLIENT: "$HOME_NET"
    ENIP_SERVER: "$HOME_NET"

  port-groups:
    HTTP_PORTS: "80"
    SHELLCODE_PORTS: "!80"
    ORACLE_PORTS: 1521
    SSH_PORTS: 22
    DNP3_PORTS: 20000
    MODBUS_PORTS: 502
    FILE_DATA_PORTS: "[$HTTP_PORTS,110,143]"
    FTP_PORTS: 21
    GENEVE_PORTS: 6081
    VXLAN_PORTS: 4789
    TEREDO_PORTS: 3544

default-log-dir: /var/log/suricata/

stats:
  enabled: yes
  interval: 8

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert:
            payload: yes
            payload-buffer-size: 4kb
            payload-printable: yes
            packet: yes
            metadata: no
            http-body: yes
            http-body-printable: yes
            tagged-packets: yes
        - anomaly:
            enabled: yes
            types:
              decode: yes
              stream: yes
              applayer: yes
        - http:
            extended: yes
        - dns:
            query: yes
            answer: yes
        - tls:
            extended: yes
        - files:
            force-magic: no
        - smtp:
            extended: yes
        - ssh
        - stats:
            totals: yes
            threads: no
            deltas: no
        - flow

logging:
  default-log-level: notice
  default-output-filter:
  outputs:
  - console:
      enabled: yes
  - file:
      enabled: yes
      level: info
      filename: /var/log/suricata/suricata.log
  - syslog:
      enabled: no
      facility: local5
      format: "[%i] <%d> -- "

af-packet:
  - interface: eth0
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    tpacket-v3: yes

pcap:
  - interface: eth0

app-layer:
  protocols:
    tls:
      enabled: yes
      detection-ports:
        dp: 443
    http:
      enabled: yes
      libhtp:
        default-config:
          personality: IDS
          request-body-limit: 100kb
          response-body-limit: 100kb
          request-body-minimal-inspect-size: 32kb
          request-body-inspect-window: 4kb
          response-body-minimal-inspect-size: 40kb
          response-body-inspect-window: 16kb
          response-body-decompress-layer-limit: 2
          http-body-inline: auto
          swf-decompression:
            enabled: yes
            type: both
            compress-depth: 100kb
            decompress-depth: 100kb
          double-decode-path: no
          double-decode-query: no
    ftp:
      enabled: yes
    ssh:
      enabled: yes
    smtp:
      enabled: yes
      mime:
        decode-mime: yes
        decode-base64: yes
        decode-quoted-printable: yes
        header-value-depth: 2000
        extract-urls: yes
        body-md5: no
    dns:
      tcp:
        enabled: yes
        detection-ports:
          dp: 53
      udp:
        enabled: yes
        detection-ports:
          dp: 53

threading:
  set-cpu-affinity: no
  cpu-affinity:
    - management-cpu-set:
        cpu: [ 0 ]
    - receive-cpu-set:
        cpu: [ 0 ]
    - worker-cpu-set:
        cpu: [ "all" ]
  detect-thread-ratio: 1.0

profiling:
  rules:
    enabled: yes
    filename: rule_perf.log
    append: yes
    sort: avgticks
    limit: 10
  keywords:
    enabled: yes
    filename: keyword_perf.log
    append: yes
  rulegroups:
    enabled: yes
    filename: rule_group_perf.log
    append: yes

nfq:

nflog:
  - group: 2
    buffer-size: 18432
  - group: default
    qthreshold: 1
    qtimeout: 100
    max-size: 20000

capture:

netmap:
 - interface: eth2
   threads: auto
   copy-mode: ips
   copy-iface: eth3

pfring:
  - interface: eth0
    threads: auto
    cluster-id: 99
    cluster-type: cluster_flow

ipfw:

napatech:
  streams: ["0-3"]
  enable-stream-stats: no
  auto-config: yes
  hardware-bypass: yes

host-mode: auto

unix-command:
  enabled: auto

legacy:
  uricontent: enabled

engine-analysis:
  rules-fast-pattern: yes
  rules: yes

pcre:
  match-limit: 3500
  match-limit-recursion: 1500

host-os-policy:
  windows: [0.0.0.0/0]
  bsd: []
  bsd-right: []
  old-linux: []
  linux: []
  old-solaris: []
  solaris: []
  hpux10: []
  hpux11: []
  irix: []
  macos: []
  vista: []
  windows2k3: []

defrag:
  max-frags: 65535
  prealloc: yes
  timeout: 60

flow:
  memcap: 128mb
  hash-size: 65536
  prealloc: 10000
  emergency-recovery: 30
  managers: 1
  recyclers: 1

vlan:
  use-for-tracking: true

flow-timeouts:
  default:
    new: 30
    established: 300
    closed: 0
    bypassed: 100
    emergency-new: 10
    emergency-established: 100
    emergency-closed: 0
    emergency-bypassed: 50
  tcp:
    new: 60
    established: 600
    closed: 60
    bypassed: 100
    emergency-new: 5
    emergency-established: 100
    emergency-closed: 10
    emergency-bypassed: 50
  udp:
    new: 30
    established: 300
    bypassed: 100
    emergency-new: 10
    emergency-established: 100
    emergency-bypassed: 50
  icmp:
    new: 30
    established: 300
    bypassed: 100
    emergency-new: 10
    emergency-established: 100
    emergency-bypassed: 50

stream:
  memcap: 64mb
  checksum-validation: yes
  inline: auto
  reassembly:
    memcap: 256mb
    depth: 1mb
    toserver-chunk-size: 2560
    toclient-chunk-size: 2560
    randomize-chunk-size: yes

host:
  hash-size: 4096
  prealloc: 1000
  memcap: 32mb

decoder:
  teredo:
    enabled: true
    ports:
      dp: $TEREDO_PORTS
      sp: $TEREDO_PORTS
  vxlan:
    enabled: true
    ports:
      dp: $VXLAN_PORTS
      sp: $VXLAN_PORTS
  geneve:
    enabled: true
    ports:
      dp: $GENEVE_PORTS
      sp: $GENEVE_PORTS

detect:
  profile: medium
  custom-values:
    toclient-groups: 3
    toserver-groups: 25
  sgh-mpm-context: auto
  inspection-recursion-limit: 3000
  prefilter:
    default: mpm
  grouping:
  profiling:
    grouping:
      dump-to-disk: false
      include-rules: false
      include-mpm-stats: false

mpm-algo: auto

spm-algo: auto

threading:
  set-cpu-affinity: no

luajit:
  states: 128

classification-file: /etc/suricata/classification.config
reference-config-file: /etc/suricata/reference.config

rule-files:
  - botcc.rules
  - ciarmy.rules
  - compromised.rules
  - drop.rules
  - dshield.rules
  - emerging-activex.rules
  - emerging-attack_response.rules
  - emerging-chat.rules
  - emerging-current_events.rules
  - emerging-dns.rules
  - emerging-dos.rules
  - emerging-exploit.rules
  - emerging-ftp.rules
  - emerging-imap.rules
  - emerging-inappropriate.rules
  - emerging-malware.rules
  - emerging-misc.rules
  - emerging-mobile_malware.rules
  - emerging-netbios.rules
  - emerging-p2p.rules
  - emerging-policy.rules
  - emerging-pop3.rules
  - emerging-rpc.rules
  - emerging-scada.rules
  - emerging-scan.rules
  - emerging-shellcode.rules
  - emerging-smtp.rules
  - emerging-snmp.rules
  - emerging-sql.rules
  - emerging-telnet.rules
  - emerging-tftp.rules
  - emerging-trojan.rules
  - emerging-user_agents.rules
  - emerging-voip.rules
  - emerging-web_client.rules
  - emerging-web_server.rules
  - emerging-worm.rules
  - tor.rules
  - decoder-events.rules
  - stream-events.rules
  - http-events.rules
  - smtp-events.rules
  - dns-events.rules
  - tls-events.rules

default-rule-path: /etc/suricata/rules

action-order:
  - pass
  - drop
  - reject
  - alert
```

#### Custom Suricata Rules
```bash
# /opt/cyberblue/suricata/rules/local.rules

# Custom CyberBlue Rules

# Detect DNS over HTTPS (DoH)
alert tls $HOME_NET any -> any 443 (msg:"Possible DNS over HTTPS"; flow:established,to_server; tls.sni; content:"cloudflare-dns.com"; sid:1000001; rev:1;)
alert tls $HOME_NET any -> any 443 (msg:"Possible DNS over HTTPS"; flow:established,to_server; tls.sni; content:"dns.google"; sid:1000002; rev:1;)

# Detect suspicious PowerShell downloads
alert http $HOME_NET any -> any any (msg:"Suspicious PowerShell Download"; flow:established,to_server; content:"powershell"; http_uri; content:"DownloadString"; http_uri; sid:1000003; rev:1;)

# Detect potential data exfiltration
alert tcp $HOME_NET any -> !$HOME_NET any (msg:"Large data transfer outbound"; flow:established,to_server; dsize:>1000000; threshold:type both, track by_src, count 5, seconds 60; sid:1000004; rev:1;)

# Detect SSH tunneling
alert tcp $HOME_NET any -> any 22 (msg:"Possible SSH tunnel - High data volume"; flow:established; dsize:>50000; threshold:type both, track by_src, count 10, seconds 300; sid:1000005; rev:1;)

# Detect cryptocurrency mining
alert http any any -> any any (msg:"Cryptocurrency mining detected"; flow:established; content:"stratum+tcp://"; http_uri; sid:1000006; rev:1;)
alert tcp any any -> any [8332,8333,9332,9333] (msg:"Bitcoin protocol detected"; flow:established; sid:1000007; rev:1;)

# Detect lateral movement
alert smb $HOME_NET any -> $HOME_NET any (msg:"SMB lateral movement attempt"; flow:established; content:"|ff|SMB"; depth:4; content:"admin$"; distance:0; sid:1000008; rev:1;)

# Detect suspicious user agents
alert http any any -> any any (msg:"Suspicious User Agent - sqlmap"; flow:established,to_server; content:"User-Agent|3a 20|sqlmap"; http_header; sid:1000009; rev:1;)
alert http any any -> any any (msg:"Suspicious User Agent - Metasploit"; flow:established,to_server; content:"User-Agent|3a 20|Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)"; http_header; sid:1000010; rev:1;)

# Detect command injection attempts
alert http any any -> any any (msg:"Command injection attempt"; flow:established,to_server; content:"|3b|"; http_uri; pcre:"/(\||;|&|`|\$\()/i"; sid:1000011; rev:1;)

# Detect file upload attempts to web shells
alert http any any -> any any (msg:"Possible web shell upload"; flow:established,to_server; content:"POST"; http_method; content:".php"; http_uri; content:"Content-Type|3a 20|multipart/form-data"; http_header; sid:1000012; rev:1;)
```

---

## 🧠 **Threat Intelligence Tools**

### MISP Configuration

#### Advanced MISP Settings
```php
// /opt/cyberblue/configs/config.php (MISP configuration)
<?php
$config = array (
  'debug' => 0,
  'MISP' => array(
    'baseurl' => 'https://YOUR_IP:7003',
    'live' => true,
    'language' => 'eng',
    'uuid' => 'YOUR_MISP_UUID',
    'contact' => 'admin@cyberblue.local',
    'cveurl' => 'https://cve.circl.lu/cve/',
    'disablerestalert' => false,
    'showCorrelationsOnIndex' => true,
    'showProposalsOnIndex' => true,
    'enable_advanced_correlations' => true,
    'server_settings_skip_backup_rotate' => false,
    'maintenance_message' => 'Great things are happening! MISP is undergoing maintenance, but will return shortly. You can contact the administration at $email.',
    'background_jobs' => true,
    'log_each_individual_auth_fail' => false,
    'log_auth' => false,
    'log_user_ips' => true,
    'log_user_ips_authkeys' => true,
    'disable_browser_cache' => false,
    'check_sec_fetch_site_header' => true,
    'security_rest_auth_key_validate' => false,
    'auth_enforced' => false,
    'email_otp_enabled' => false,
    'email_otp_length' => 6,
    'email_otp_validity' => 300,
    'disable_emailing' => false,
    'disable_user_self_management' => false,
    'disable_user_add' => false,
    'allow_self_registration' => false,
    'self_registration_message' => 'If you would like to send us a registration request, please fill out the form below. Make sure you fill out as much information as possible in order to ease the task of the administrators.',
    'password_policy_length' => 12,
    'password_policy_complexity' => '/^((?=.*\d)|(?=.*\W+))(?![\n])(?=.*[A-Z])(?=.*[a-z]).*$|.{16,}/',
    'require_password_confirmation' => true,
    'sanitise_attribute_on_delete' => false,
    'hide_organisation_index_from_users' => false,
    'logging' => array(
      'enabled' => true,
      'level' => 'notice'
    ),
    'ca_path' => '/etc/ssl/certs',
    'python_bin' => '/usr/bin/python3',
    'disable_auto_logout' => false,
    'ssdeep_correlation_threshold' => 40,
    'max_correlation_value_length' => 1024,
    'deadlock_avoidance' => true,
    'download_gpg_from_homedir' => false,
    'download_attachments_on_load' => true,
    'title_text' => 'CyberBlue MISP',
    'terms_download' => false,
    'showorgalternate' => false,
    'event_alert_republish_ban' => false,
    'event_alert_republish_ban_threshold' => 5,
    'event_alert_republish_ban_refresh_on_retry' => false,
    'volatile_redis_connection' => false,
    'incoming_tags_disabled_by_default' => false,
    'footermidleft' => 'CyberBlue',
    'footermidright' => 'Threat Intelligence Platform',
    'homepage' => 'https://cyberblue.local'
  ),
  'GnuPG' => array(
    'email' => 'admin@cyberblue.local',
    'homedir' => '/var/www/MISP/.gnupg',
    'password' => '',
    'bodyonlyencrypted' => false,
    'sign' => true,
    'binary' => '/usr/bin/gpg'
  ),
  'SMIME' => array(
    'enabled' => false,
    'email' => 'admin@cyberblue.local',
    'cert_public_sign' => '/var/www/MISP/.smime/email.pem',
    'key_sign' => '/var/www/MISP/.smime/email.key',
    'password' => ''
  ),
  'Proxy' => array(
    'host' => '',
    'port' => '',
    'method' => '',
    'user' => '',
    'password' => ''
  ),
  'SecureAuth' => array(
    'amount' => 5,
    'expire' => 300
  ),
  'Security' => array(
    'salt' => 'YOUR_SALT_HERE',
    'cipherSeed' => '',
    'auth_enforced' => false,
    'log_each_individual_auth_fail' => false,
    'username_in_response_header' => false,
    'disable_browser_cache' => false,
    'check_sec_fetch_site_header' => true,
    'csp_enforce' => false,
    'advanced_authkeys' => false,
    'password_policy_length' => 12,
    'password_policy_complexity' => '/^((?=.*\d)|(?=.*\W+))(?![\n])(?=.*[A-Z])(?=.*[a-z]).*$|.{16,}/',
    'self_registration_message' => 'Please provide your details to request access.'
  ),
  'Session' => array(
    'defaults' => 'php',
    'timeout' => 3600,
    'cookieTimeout' => 3600,
    'autoRegenerate' => false,
    'checkAgent' => false
  )
);
```

#### MISP Feed Configuration
```bash
#!/bin/bash
# scripts/configure-misp-feeds.sh

MISP_URL="https://localhost:7003"
API_KEY="YOUR_MISP_API_KEY"

# Add threat intelligence feeds
curl -k -X POST "$MISP_URL/feeds/add" \
  -H "Authorization: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "Feed": {
      "name": "CIRCL OSINT Feed",
      "provider": "CIRCL",
      "url": "https://www.circl.lu/doc/misp/feed-osint/",
      "rules": "",
      "enabled": true,
      "distribution": 3,
      "sharing_group_id": 0,
      "tag_id": 0,
      "default": true,
      "source_format": "misp",
      "fixed_event": false,
      "delta_merge": false,
      "event_id": 0,
      "publish": false,
      "override_ids": false,
      "settings": "",
      "input_source": "network",
      "delete_local_file": false,
      "lookup_visible": true,
      "headers": ""
    }
  }'

# Add more feeds...
```

### MITRE ATT&CK Navigator Configuration

#### Custom Layer Configuration
```json
// attack-navigator/custom-layer.json
{
  "name": "CyberBlue Detection Coverage",
  "version": "4.5",
  "domain": "enterprise-attack",
  "description": "Detection coverage for CyberBlue environment",
  "filters": {
    "stages": ["act"],
    "platforms": ["windows", "linux", "macos"]
  },
  "sorting": 0,
  "layout": {
    "layout": "side",
    "aggregateFunction": "average",
    "showID": false,
    "showName": true,
    "countUnscored": false
  },
  "hideDisabled": false,
  "techniques": [
    {
      "techniqueID": "T1059.001",
      "tactic": "execution",
      "color": "#ff0000",
      "comment": "Detected by Wazuh PowerShell monitoring",
      "enabled": true,
      "metadata": [],
      "links": [],
      "showSubtechniques": true
    },
    {
      "techniqueID": "T1110.001",
      "tactic": "credential-access",
      "color": "#ff6600",
      "comment": "Detected by Suricata and Wazuh SSH monitoring",
      "enabled": true,
      "metadata": [],
      "links": [],
      "showSubtechniques": true
    }
  ],
  "gradient": {
    "colors": ["#ff0000", "#ffff00", "#00ff00"],
    "minValue": 0,
    "maxValue": 100
  },
  "legendItems": [
    {
      "label": "Full Detection",
      "color": "#00ff00"
    },
    {
      "label": "Partial Detection", 
      "color": "#ffff00"
    },
    {
      "label": "No Detection",
      "color": "#ff0000"
    }
  ],
  "metadata": [],
  "links": [],
  "showTacticRowBackground": false,
  "tacticRowBackground": "#dddddd",
  "selectTechniquesAcrossTactics": true,
  "selectSubtechniquesWithParent": false
}
```

---

## 🕵️ **DFIR Tools**

### Velociraptor Configuration

#### Server Configuration
```yaml
# /opt/cyberblue/velociraptor/server.config.yaml
version:
  name: velociraptor
  version: 0.6.7
  commit: 2c78293
  build_time: "2023-01-15T10:30:00Z"

Client:
  server_urls:
    - https://localhost:7000/
  ca_certificate: |
    -----BEGIN CERTIFICATE-----
    YOUR_CA_CERTIFICATE_HERE
    -----END CERTIFICATE-----
  nonce: YOUR_NONCE_HERE
  
API:
  bind_address: 0.0.0.0
  bind_port: 8001
  bind_scheme: tcp
  pinned_gw_name: ""

GUI:
  bind_address: 0.0.0.0
  bind_port: 8889
  gw_certificate: |
    -----BEGIN CERTIFICATE-----
    YOUR_CERTIFICATE_HERE
    -----END CERTIFICATE-----
  gw_private_key: |
    -----BEGIN PRIVATE KEY-----
    YOUR_PRIVATE_KEY_HERE
    -----END PRIVATE KEY-----
  internal_cidr:
    - 127.0.0.1/12
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12
  authenticator:
    type: Basic
    sub_authenticators:
    - type: PasswordFileAuthenticator
      password_file: /velociraptor/users.db

CA:
  private_key: |
    -----BEGIN PRIVATE KEY-----
    YOUR_CA_PRIVATE_KEY_HERE
    -----END PRIVATE KEY-----

Frontend:
  bind_address: 0.0.0.0
  bind_port: 8000
  certificate: |
    -----BEGIN CERTIFICATE-----
    YOUR_FRONTEND_CERTIFICATE_HERE
    -----END CERTIFICATE-----
  private_key: |
    -----BEGIN PRIVATE KEY-----
    YOUR_FRONTEND_PRIVATE_KEY_HERE
    -----END PRIVATE KEY-----
  dyn_dns:
    hostname: localhost
  GRPC_pool_max_size: 100
  GRPC_pool_max_wait: 60

Datastore:
  implementation: FileBaseDataStore
  location: /velociraptor/datastore
  filestore_directory: /velociraptor/filestore

Writeback:
  private_key: |
    -----BEGIN PRIVATE KEY-----
    YOUR_WRITEBACK_PRIVATE_KEY_HERE
    -----END PRIVATE KEY-----

Mail:
  from: velociraptor@cyberblue.local
  server: localhost
  server_port: 25

Logging:
  output_directory: /velociraptor/logs
  separate_logs_per_component: true
  rotation_time: 604800
  max_age: 31536000

Monitoring:
  bind_address: 127.0.0.1
  bind_port: 8003

api_config:
  hostname: localhost
  ca_certificate: |
    -----BEGIN CERTIFICATE-----
    YOUR_CA_CERTIFICATE_HERE
    -----END CERTIFICATE-----
```

#### Custom Artifacts
```yaml
# /opt/cyberblue/velociraptor/artifacts/CyberBlue.Suspicious.PowerShell.yaml
name: CyberBlue.Suspicious.PowerShell
description: |
  Collect suspicious PowerShell activity from Windows Event Logs

type: CLIENT

parameters:
  - name: EventLog
    default: Microsoft-Windows-PowerShell/Operational
  - name: SuspiciousKeywords
    type: csv
    default: |
      Keyword
      DownloadString
      Invoke-Expression
      IEX
      EncodedCommand
      FromBase64String
      WebClient
      Net.WebClient
      System.Net.WebClient
      Invoke-WebRequest
      IWR
      curl
      wget

sources:
  - precondition:
      SELECT OS From info() where OS = 'windows'
    
    query: |
      SELECT EventTime,
             Computer,
             Channel,
             EventID,
             EventData,
             System,
             Message
      FROM parse_evtx(filename=expand(
        path='%SystemRoot%/System32/Winevt/Logs/' + EventLog + '.evtx'))
      WHERE EventID in (4103, 4104, 4105, 4106)
        AND Message =~ '(?i)(' + 
            join(array=SuspiciousKeywords.Keyword, sep="|") + ')'
      ORDER BY EventTime DESC
      LIMIT 1000

reports:
  - type: CLIENT
    template: |
      # CyberBlue Suspicious PowerShell Activity
      
      {{ range .Query }}
      ## Event {{ .EventID }} - {{ .EventTime }}
      **Computer:** {{ .Computer }}
      **Message:** {{ .Message }}
      
      {{ end }}
```

### Arkime Configuration

#### Configuration File
```ini
# /opt/cyberblue/arkime/config.ini
[default]
elasticsearch=http://os01:9200
rotateIndex=daily
pcapDir=/data/pcap
maxFileSizeG=12
tcpTimeout=600
tcpSaveTimeout=720
udpTimeout=30
icmpTimeout=10
maxPackets=10000
minFreeSpaceG=100
viewPort=8005
webBasePath=/
passwordSecret=YOUR_PASSWORD_SECRET_HERE
httpRealm=Moloch
interface=eth0
pcapReadMethod=libpcap-over-mmap
tpacketv3NumThreads=2
pcapWriteMethod=simple
pcapWriteSize=2560000
dbBulkSize=300000
dbFlushTimeout=5
maxESConns=30
maxESRequests=500
packetsPerPoll=50000
pcapBufferSize=300000000
pcapWriteSize=2560000
maxFreeOutputBuffers=50

# Parsers
parsersDir=/data/moloch/parsers

# Plugins
pluginsDir=/data/moloch/plugins
plugins=wise.so

# GeoIP
geoLite2Country=/usr/share/GeoIP/GeoLite2-Country.mmdb
geoLite2ASN=/usr/share/GeoIP/GeoLite2-ASN.mmdb

# Other
rirFile=/data/moloch/etc/ipv4-address-space.csv

# Rules
rulesFiles=/data/moloch/etc/rules.yaml

# Headers
dontSaveIPs=10.0.0.0/8;192.168.0.0/16;172.16.0.0/12;127.0.0.0/8
```

---

## ⚡ **SOAR Tools**

### Shuffle Configuration

#### Workflow Configuration
```json
{
  "name": "CyberBlue Incident Response",
  "description": "Automated incident response workflow",
  "start": "webhook_trigger",
  "triggers": [
    {
      "id": "webhook_trigger",
      "name": "Webhook Trigger",
      "type": "webhook",
      "status": "running",
      "parameters": {
        "url": "/api/v1/hooks/webhook_example",
        "method": "POST"
      }
    }
  ],
  "actions": [
    {
      "id": "parse_alert",
      "name": "Parse Alert",
      "app_name": "shuffle-tools",
      "app_version": "1.0.0",
      "function": "json_parse",
      "parameters": {
        "json_data": "$webhook_trigger.body"
      }
    },
    {
      "id": "enrich_iocs",
      "name": "Enrich IOCs",
      "app_name": "virustotal",
      "app_version": "3.0",
      "function": "get_ip_report",
      "parameters": {
        "ip": "$parse_alert.src_ip"
      }
    },
    {
      "id": "create_misp_event",
      "name": "Create MISP Event",
      "app_name": "misp",
      "app_version": "1.0",
      "function": "create_event",
      "parameters": {
        "info": "Automated alert from Wazuh: $parse_alert.rule_description",
        "distribution": "1",
        "threat_level_id": "2",
        "analysis": "0"
      }
    },
    {
      "id": "notify_team",
      "name": "Notify Security Team",
      "app_name": "email",
      "app_version": "1.0",
      "function": "send_email",
      "parameters": {
        "to": "security-team@company.com",
        "subject": "Security Alert: $parse_alert.rule_description",
        "body": "Alert details:\nRule: $parse_alert.rule_description\nSource IP: $parse_alert.src_ip\nTimestamp: $parse_alert.timestamp\n\nMISP Event: $create_misp_event.event_id"
      }
    }
  ],
  "branches": [
    {
      "source_id": "webhook_trigger",
      "destination_id": "parse_alert"
    },
    {
      "source_id": "parse_alert",
      "destination_id": "enrich_iocs"
    },
    {
      "source_id": "enrich_iocs",
      "destination_id": "create_misp_event"
    },
    {
      "source_id": "create_misp_event",
      "destination_id": "notify_team"
    }
  ]
}
```

### TheHive Configuration

#### Application Configuration
```hocon
# /opt/cyberblue/thehive/application.conf
play.http.secret.key="YOUR_SECRET_KEY_HERE"

play.http.context="/thehive/"

# Database
db.janusgraph {
  storage.backend: berkeleyje
  storage.directory: /opt/thp/thehive/database
  index.search.backend: lucene
  index.search.directory: /opt/thp/thehive/index
}

# Attachment storage
storage {
  provider: localfs
  localfs.location: /opt/thp/thehive/files
}

# Service configuration
play.http.parser.maxDiskBuffer: 50MB
play.http.parser.maxMemoryBuffer: 10MB

# MISP Integration
misp {
  interval: 1 hour
  max: 100
  case-template: "misp"
  tags: ["misp-import"]
  whitelist: []
  exclusion: []
  
  servers: [
    {
      name = "MISP-Server"
      url = "https://localhost:7003"
      auth {
        type = key
        key = "YOUR_MISP_API_KEY"
      }
      wsConfig {}
      tags = ["misp"]
      max-attributes = 1000
      max-size = 1 MiB
      exclusion {
        organisation = [".*"]
        tags = [".*:whitelisted", "osint"]
      }
      whitelist {
        tags = [".*:indicator"]
      }
      purpose = ImportAndExport
    }
  ]
}

# Cortex Integration
cortex {
  servers: [
    {
      name: Cortex-Server
      url: "http://localhost:7006"
      auth {
        type: "bearer"
        key: "YOUR_CORTEX_API_KEY"
      }
    }
  ]
  refreshDelay = 1 minute
  maxRetryOnError = 3
  statusCheckInterval = 1 minute
}

# Authentication
auth {
  providers: [
    {name: session}
    {name: basic, realm: thehive}
    {name: local}
    {name: key}
  ]
  
  # Multi-factor authentication
  multifactor: [
    {name: totp}
  ]
}

# Notification
notification.webhook.endpoints = [
  {
    name: local
    url: "http://localhost:5000/"
    version: 0
    wsConfig: {}
    includedTheHiveOrganisations: ["*"]
    excludedTheHiveOrganisations: []
  }
]
```

---

## 🔧 **Utility Tools**

### CyberChef Custom Operations

#### Custom Recipe Configuration
```javascript
// /opt/cyberblue/cyberchef/custom-operations.js

// Custom operation for CyberBlue log parsing
const CyberBlueLogParser = {
    "op": "CyberBlue Log Parser",
    "module": "Custom",
    "description": "Parse CyberBlue security logs",
    "infoURL": "",
    "inputType": "string",
    "outputType": "JSON",
    "flowControl": false,
    "manualBake": false,
    "args": [
        {
            "name": "Log Type",
            "type": "option",
            "value": ["Wazuh", "Suricata", "MISP"]
        }
    ],
    
    run: function(input, args) {
        const logType = args[0];
        const lines = input.split('\n');
        const parsed = [];
        
        lines.forEach(line => {
            if (line.trim()) {
                try {
                    const log = JSON.parse(line);
                    
                    switch(logType) {
                        case "Wazuh":
                            parsed.push({
                                timestamp: log.timestamp,
                                agent: log.agent?.name || "unknown",
                                rule_id: log.rule?.id,
                                rule_description: log.rule?.description,
                                level: log.rule?.level,
                                mitre_technique: log.rule?.mitre?.id,
                                src_ip: log.data?.srcip,
                                dst_ip: log.data?.dstip
                            });
                            break;
                            
                        case "Suricata":
                            if (log.event_type === "alert") {
                                parsed.push({
                                    timestamp: log.timestamp,
                                    alert: log.alert?.signature,
                                    category: log.alert?.category,
                                    severity: log.alert?.severity,
                                    src_ip: log.src_ip,
                                    dst_ip: log.dest_ip,
                                    proto: log.proto
                                });
                            }
                            break;
                            
                        case "MISP":
                            parsed.push({
                                event_id: log.Event?.id,
                                info: log.Event?.info,
                                threat_level: log.Event?.threat_level_id,
                                analysis: log.Event?.analysis,
                                attributes: log.Event?.Attribute?.length || 0
                            });
                            break;
                    }
                } catch (e) {
                    // Skip invalid JSON lines
                }
            }
        });
        
        return JSON.stringify(parsed, null, 2);
    }
};

// Add to CyberChef operations
if (typeof module !== 'undefined') {
    module.exports = CyberBlueLogParser;
}
```

### Portainer Configuration

#### Stack Configuration Template
```yaml
# Portainer stack template for CyberBlue monitoring
version: '3.8'

services:
  monitoring-dashboard:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=cyberblue123
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
    ports:
      - "3000:3000"
    networks:
      - cyber-blue

  prometheus:
    image: prom/prometheus:latest
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-storage:/prometheus
    ports:
      - "9090:9090"
    networks:
      - cyber-blue

volumes:
  grafana-storage:
  prometheus-storage:

networks:
  cyber-blue:
    external: true
```

---

## 🔗 **Tool Integration Configurations**

### Wazuh to MISP Integration
```bash
#!/bin/bash
# /opt/cyberblue/scripts/wazuh-to-misp.py

import json
import requests
from datetime import datetime

# Configuration
MISP_URL = "https://localhost:7003"
MISP_API_KEY = "YOUR_MISP_API_KEY"
WAZUH_THRESHOLD_LEVEL = 10

def create_misp_event(alert_data):
    """Create MISP event from Wazuh alert"""
    
    headers = {
        'Authorization': MISP_API_KEY,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    event_data = {
        "Event": {
            "info": f"Wazuh Alert: {alert_data['rule']['description']}",
            "distribution": 1,
            "threat_level_id": 2,
            "analysis": 0,
            "date": datetime.now().strftime("%Y-%m-%d"),
            "Attribute": []
        }
    }
    
    # Add source IP as attribute
    if 'srcip' in alert_data.get('data', {}):
        event_data["Event"]["Attribute"].append({
            "category": "Network activity",
            "type": "ip-src",
            "value": alert_data['data']['srcip'],
            "to_ids": True,
            "comment": f"Source IP from Wazuh rule {alert_data['rule']['id']}"
        })
    
    # Add destination IP as attribute
    if 'dstip' in alert_data.get('data', {}):
        event_data["Event"]["Attribute"].append({
            "category": "Network activity", 
            "type": "ip-dst",
            "value": alert_data['data']['dstip'],
            "to_ids": True,
            "comment": f"Destination IP from Wazuh rule {alert_data['rule']['id']}"
        })
    
    # Add MITRE technique tag
    if 'mitre' in alert_data.get('rule', {}):
        for technique in alert_data['rule']['mitre']:
            event_data["Event"]["Tag"] = [{
                "name": f"misp-galaxy:mitre-attack-pattern=\"{technique['id']} - {technique['tactic']}\""
            }]
    
    response = requests.post(
        f"{MISP_URL}/events",
        headers=headers,
        json=event_data,
        verify=False
    )
    
    if response.status_code == 200:
        print(f"MISP event created: {response.json()['Event']['id']}")
    else:
        print(f"Failed to create MISP event: {response.text}")

def process_wazuh_alert(alert):
    """Process Wazuh alert and create MISP event if criteria met"""
    
    alert_data = json.loads(alert)
    
    # Check if alert meets threshold
    if alert_data.get('rule', {}).get('level', 0) >= WAZUH_THRESHOLD_LEVEL:
        create_misp_event(alert_data)

if __name__ == "__main__":
    # This would be called by Wazuh integration script
    # For testing:
    sample_alert = '''
    {
        "timestamp": "2024-01-15T10:30:00.000Z",
        "rule": {
            "id": 5716,
            "level": 12,
            "description": "SSH authentication failed",
            "mitre": [
                {
                    "id": "T1110.001",
                    "tactic": "credential-access"
                }
            ]
        },
        "agent": {
            "name": "web-server-01"
        },
        "data": {
            "srcip": "192.168.1.100",
            "user": "admin"
        }
    }
    '''
    process_wazuh_alert(sample_alert)
```

---

## 📋 **Configuration Management Best Practices**

### Version Control for Configurations
```bash
#!/bin/bash
# scripts/backup-configs.sh

# Initialize git repository for configuration tracking
cd /opt/cyberblue
git init
git add .env* docker-compose.yml configs/ ssl/
git commit -m "Initial CyberBlue configuration backup"

# Create configuration versioning script
cat > scripts/version-config.sh << 'EOF'
#!/bin/bash
cd /opt/cyberblue
git add -A
git commit -m "Configuration update: $(date)"
git tag "config-$(date +%Y%m%d-%H%M%S)"
EOF

chmod +x scripts/version-config.sh
```

### Configuration Validation Script
```bash
#!/bin/bash
# scripts/validate-configs.sh

echo "Validating CyberBlue configurations..."

# Validate Docker Compose
if docker-compose config > /dev/null 2>&1; then
    echo "✅ Docker Compose configuration is valid"
else
    echo "❌ Docker Compose configuration has errors"
    docker-compose config
    exit 1
fi

# Validate environment file
if [ -f .env ]; then
    echo "✅ Environment file exists"
    
    # Check required variables
    required_vars=("HOST_IP" "WAZUH_ADMIN_PASSWORD" "MISP_ADMIN_PASSWORD")
    for var in "${required_vars[@]}"; do
        if grep -q "^$var=" .env; then
            echo "✅ $var is configured"
        else
            echo "❌ $var is missing from .env"
        fi
    done
else
    echo "❌ Environment file (.env) is missing"
fi

# Validate SSL certificates
if [ -d ssl ]; then
    for cert in ssl/*.pem; do
        if [ -f "$cert" ]; then
            if openssl x509 -in "$cert" -noout -checkend 86400; then
                echo "✅ Certificate $cert is valid"
            else
                echo "⚠️ Certificate $cert expires within 24 hours"
            fi
        fi
    done
fi

echo "Configuration validation completed"
```

---

*This tool configuration guide should be customized based on your specific security requirements and integrated with your existing security policies and procedures.*
