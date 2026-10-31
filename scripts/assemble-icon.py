#!/usr/bin/env python3
"""Package original native-rendered PNG representations into the ICNS container."""
import struct
from pathlib import Path
root = Path(__file__).resolve().parent.parent
source = root / '.build/Tether.iconset'
chunks = []
for kind, filename in [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'), ('icp6', 'icon_32x32@2x.png'), ('ic07', 'icon_128x128.png'), ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'), ('ic10', 'icon_512x512@2x.png')]:
    data = (source / filename).read_bytes()
    chunks.append(kind.encode() + struct.pack('>I', len(data) + 8) + data)
payload = b''.join(chunks)
(root / 'Resources/Tether.icns').write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)
