# Useful Scripts

## [linux-vpn-route-workaround.sh](linux-vpn-route-workaround.sh)

Tested on Rocky 9 Linux. Compatible with most Linux operating systems. 

**Why?** This script was created to ensure that SSH traffic coming INTO the server is not routed through the OpenVPN connection.

**Assumptions**: You'll need two commands; the first is `connect` and `disconnect` inside your `~/bin` directory:

`~/bin/connect`:
```bash
#!/bin/bash
openvpn3 session-start --config ~/.vpn/client.ovpn
openvpn3 sessions-list
```

`~/bin/disconnect`: 
```bash
#!/bin/bash
openvpn3 session-manage --disconnect --config ~/.vpn/client.ovpn
openvpn3 sessions-list
```

**FYI**: The nuts and bolts of this script can be simplified to: 

`linux-vpn-route-workaround.sh --install`: 
```bash
sudo ip rule add from "${HOST_IP}" table "${TABLE_ID}"
sudo ip route add table "${TABLE_ID}" to "${HOST_SUBNET}" dev "${INTERFACE}"
sudo ip route add table "${TABLE_ID}" default via "${HOST_GATEWAY}"
```
`linux-vpn-route-workaround.sh --uninstall`: 
```bash
sudo ip route del table "${TABLE_ID}" to "${HOST_SUBNET}" dev "${INTERFACE}"
sudo ip route del table "${TABLE_ID}" default via "${HOST_GATEWAY}"
sudo ip rule del from "${HOST_IP}" table "${TABLE_ID}"
```

# LICENSE

MIT

Copyright 2023 @andreiwashere

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
