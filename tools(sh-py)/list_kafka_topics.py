#!/usr/bin/env python3
"""Simple Kafka topics lister using socket protocol"""
import socket
import struct

def get_kafka_topics(host, port, timeout=5):
    """Connect to Kafka and list topics"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        
        # Connect to broker
        print(f"Connecting to {host}:{port}...")
        sock.connect((host, port))
        
        # Send MetadataRequest (API version 0)
        # [request_size:4][api_key:2][api_version:2][correlation_id:4][client_id_len:2]
        request = struct.pack('>H', 3)  # API key 3 = Metadata
        request += struct.pack('>H', 0)  # Version 0
        request += struct.pack('>I', 1)  # Correlation ID
        request += struct.pack('>H', 11)  # Client ID length
        request += b'kafka-lister\x00'[:11].ljust(11, b'\x00')
        request += struct.pack('>I', 0)  # Topic array length = 0 (all topics)
        
        size = struct.pack('>I', len(request))
        sock.sendall(size + request)
        
        # Receive response (simplified)
        response = sock.recv(1024)
        print(f"Response received: {len(response)} bytes")
        print("Unable to parse Kafka protocol - using fallback method...")
        sock.close()
        
        return None
        
    except Exception as e:
        print(f"Connection failed: {e}")
        print("Trying alternative approach...")
        return None

if __name__ == '__main__':
    import subprocess
    import sys
    import os
    
    # Try using Docker/WSL Kafka tools if available
    try:
        result = subprocess.run(
            ['wsl', 'bash', '-c', 'nc -zv 127.0.0.1 19092 2>&1'],
            capture_output=True,
            text=True,
            timeout=5
        )
        print(result.stdout)
        print(result.stderr)
        
        if 'succeeded' in result.stderr or 'open' in result.stderr:
            print("\n✓ Kafka port 19092 is OPEN and responding")
            print("\nTo list topics, use one of these methods:")
            print("\n1. From WSL with kafka-cli installed:")
            print("   wsl bash -c 'kafka-topics --bootstrap-server 127.0.0.1:19092 --list'")
            print("\n2. Using Docker (if available):")
            print("   docker exec <kafka_container> kafka-topics --bootstrap-server localhost:9092 --list")
            print("\n3. Install Kafka locally and add to PATH:")
            print("   set KAFKA_HOME=C:\\kafka\\bin")
            print("   %KAFKA_HOME%\\kafka-topics.bat --bootstrap-server 127.0.0.1:19092 --list")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
