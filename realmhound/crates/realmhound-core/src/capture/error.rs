//! Capture error types.

use thiserror::Error;

/// Errors that can occur during packet capture.
#[derive(Error, Debug)]
pub enum CaptureError {
    /// Npcap/pcap is not installed
    #[error("Npcap is not installed. Please install from https://npcap.com/")]
    NpcapNotInstalled,

    /// BPF packet capture permission denied on macOS
    #[error(
        "Packet capture permission denied for /dev/bpf*.\n\
         macOS requires root privileges or membership in the access_bpf group to capture packets.\n\n\
         To enable capture on macOS:\n\
         - Option 1 (Recommended): Install Wireshark's ChmodBPF package: brew install --cask wireshark-chmodbpf\n\
         - Option 2: Run RealmHound with sudo: sudo ./RealmHound"
    )]
    BpfPermissionDenied,

    /// No network interfaces found
    #[error("No network interfaces found")]
    NoInterfaces,

    /// Failed to open interface
    #[error("Failed to open interface '{name}': {reason}")]
    InterfaceOpenFailed { name: String, reason: String },

    /// Failed to set filter
    #[error("Failed to set capture filter: {0}")]
    FilterFailed(String),

    /// Capture error
    #[error("Capture error: {0}")]
    CaptureError(String),

    /// Pcap error
    #[error("Pcap error: {0}")]
    PcapError(#[from] pcap::Error),
}
