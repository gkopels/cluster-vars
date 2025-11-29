#!/bin/bash
# Script to set up environment variables for a specific cluster
# Usage: source /path/to/setup-cluster.sh <cluster-name> [interface-type]
# Example: source ~/Documents/cluster-vars/setup-cluster.sh cluster1
# Example: source ~/Documents/cluster-vars/setup-cluster.sh cluster8 X710

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ]; then
    echo "Usage: source $0 <cluster-name> [interface-type]"
    echo ""
    echo "Available clusters:"
    ls -1 "$SCRIPT_DIR/clusters"/*.txt 2>/dev/null | sed "s|$SCRIPT_DIR/clusters/||" | sed 's|\.txt||' | sed 's/^/  /'
    exit 1
fi

CLUSTER_NAME=$1
INTERFACE_TYPE="$2"
CLUSTER_FILE="$SCRIPT_DIR/clusters/${CLUSTER_NAME}.txt"

if [ ! -f "$CLUSTER_FILE" ]; then
    echo "Error: Cluster file '$CLUSTER_FILE' not found"
    echo ""
    echo "Available clusters:"
    ls -1 "$SCRIPT_DIR/clusters"/*.txt 2>/dev/null | sed "s|$SCRIPT_DIR/clusters/||" | sed 's|\.txt||' | sed 's/^/  /'
    return 2>/dev/null || exit 1
fi

# Source only export statements from the cluster file (ignore comments and other commands)
echo "Loading cluster variables from $CLUSTER_FILE..."

if [ -n "$INTERFACE_TYPE" ]; then
    echo "Using interface type: $INTERFACE_TYPE"
    # Unset interface variables at the start to prevent stale values
    unset ECO_CNF_CORE_NET_SRIOV_INTERFACE_LIST
    unset ECO_CNF_CORE_NET_SWITCH_INTERFACES
    unset ECO_OCP_SRIOV_INTERFACE_LIST
    IN_TARGET_SECTION=false
    FOUND_TARGET_SECTION=false
    
    # First pass: check if the interface section exists
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*#.*[Ii]nterface ]]; then
            LINE_UPPER=$(echo "$line" | tr '[:lower:]' '[:upper:]')
            INTERFACE_UPPER=$(echo "$INTERFACE_TYPE" | tr '[:lower:]' '[:upper:]')
            INTERFACE_ESCAPED=$(echo "$INTERFACE_UPPER" | sed 's/[.*+?^${}()|[]/\\&/g')
            
            if [[ "$LINE_UPPER" =~ INTERFACE[[:space:]]+${INTERFACE_ESCAPED}([[:space:]]|$|#) ]]; then
                FOUND_TARGET_SECTION=true
                break
            fi
        fi
    done < "$CLUSTER_FILE"
    
    if [[ "$FOUND_TARGET_SECTION" == false ]]; then
        echo "Warning: Interface type '$INTERFACE_TYPE' not found in $CLUSTER_FILE"
        echo "Available interfaces:"
        grep -E "^[[:space:]]*#.*[Ii]nterface" "$CLUSTER_FILE" | sed 's/^[[:space:]]*#.*[Ii]nterface[[:space:]]*/  /' | sed 's/[[:space:]]*$//'
        echo ""
        # Unset any existing interface variables to prevent stale values
        unset ECO_CNF_CORE_NET_SRIOV_INTERFACE_LIST
        unset ECO_CNF_CORE_NET_SWITCH_INTERFACES
        unset ECO_OCP_SRIOV_INTERFACE_LIST
    fi
    
    # Second pass: process the file
    while IFS= read -r line; do
        # Check if this is an interface section header
        if [[ "$line" =~ ^[[:space:]]*#.*[Ii]nterface ]]; then
            # Check if this line matches the target interface type exactly
            # Case-insensitive match, handle hyphens and spaces flexibly
            LINE_UPPER=$(echo "$line" | tr '[:lower:]' '[:upper:]')
            INTERFACE_UPPER=$(echo "$INTERFACE_TYPE" | tr '[:lower:]' '[:upper:]')
            
            # Escape special regex characters in interface name, but allow hyphens
            INTERFACE_ESCAPED=$(echo "$INTERFACE_UPPER" | sed 's/[.*+?^${}()|[]/\\&/g')
            
            # Match "Interface" followed by optional spaces, then the exact interface name
            # The interface name must be followed by space, end of line, or start of comment
            # This ensures exact matching: "E810" matches "E810" but not "E8" or "E8100"
            # And "MLX" won't match "MLX-BF2" unless you specify "MLX-BF2"
            if [[ "$LINE_UPPER" =~ INTERFACE[[:space:]]+${INTERFACE_ESCAPED}([[:space:]]|$|#) ]]; then
                IN_TARGET_SECTION=true
                continue
            else
                IN_TARGET_SECTION=false
                continue
            fi
        fi
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Process export statements
        if [[ "$line" =~ ^[[:space:]]*export ]]; then
            # Check if this is an interface-related variable
            if [[ "$line" =~ ECO_CNF_CORE_NET_SRIOV_INTERFACE_LIST|ECO_CNF_CORE_NET_SWITCH_INTERFACES|ECO_OCP_SRIOV_INTERFACE_LIST ]]; then
                # Only process interface vars if we're in the target section AND the section was found
                if [[ "$IN_TARGET_SECTION" == true ]] && [[ "$FOUND_TARGET_SECTION" == true ]]; then
                    eval "$line"
                fi
            else
                # Process all non-interface variables
                eval "$line"
            fi
        fi
    done < "$CLUSTER_FILE"
else
    # No interface type specified - process all (last interface section wins)
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Only process export statements
        if [[ "$line" =~ ^[[:space:]]*export ]]; then
            eval "$line"
        fi
    done < "$CLUSTER_FILE"
fi

echo ""
echo "Cluster '$CLUSTER_NAME' variables loaded successfully!"
echo ""
echo "Key variables set:"
echo "  KUBECONFIG: $KUBECONFIG"
echo "  ECO_TEST_VERBOSE: ${ECO_TEST_VERBOSE:-not set}"
echo "  ECO_VERBOSE_LEVEL: ${ECO_VERBOSE_LEVEL:-not set}"
echo "  ECO_CNF_CORE_NET_CNF_MCP_LABEL: ${ECO_CNF_CORE_NET_CNF_MCP_LABEL:-not set}"
echo "  ECO_WORKER_LABEL: ${ECO_WORKER_LABEL:-not set}"
echo "  ECO_CNF_CORE_NET_VLAN: ${ECO_CNF_CORE_NET_VLAN:-not set}"
echo "  ECO_CNF_CORE_NET_SWITCH_LAGS: ${ECO_CNF_CORE_NET_SWITCH_LAGS:-not set}"
echo "  ECO_CNF_CORE_NET_MLB_ADDR_LIST: ${ECO_CNF_CORE_NET_MLB_ADDR_LIST:-not set}"
echo "  ECO_CNF_CORE_NET_SWITCH_IP: ${ECO_CNF_CORE_NET_SWITCH_IP:-not set}"
echo "  ECO_CNF_CORE_NET_SWITCH_USER: ${ECO_CNF_CORE_NET_SWITCH_USER:-not set}"
echo "  ECO_CNF_CORE_NET_SWITCH_PASS: ${ECO_CNF_CORE_NET_SWITCH_PASS:-not set}"
if [ -n "$INTERFACE_TYPE" ]; then
    echo "  Interface Type: $INTERFACE_TYPE"
fi
echo "  ECO_CNF_CORE_NET_SRIOV_INTERFACE_LIST: ${ECO_CNF_CORE_NET_SRIOV_INTERFACE_LIST:-not set}"
echo "  ECO_CNF_CORE_NET_SWITCH_INTERFACES: ${ECO_CNF_CORE_NET_SWITCH_INTERFACES:-not set}"
if [ -n "$ECO_OCP_SRIOV_INTERFACE_LIST" ]; then
    echo "  ECO_OCP_SRIOV_INTERFACE_LIST: $ECO_OCP_SRIOV_INTERFACE_LIST"
fi
echo ""
echo "Images:"
echo "  ECO_CNF_CORE_NET_DPDK_TEST_CONTAINER: ${ECO_CNF_CORE_NET_DPDK_TEST_CONTAINER:-not set}"
echo "  ECO_CNF_CORE_NET_TEST_CONTAINER: ${ECO_CNF_CORE_NET_TEST_CONTAINER:-not set}"
echo "  ECO_CNF_CORE_NET_FRR_IMAGE: ${ECO_CNF_CORE_NET_FRR_IMAGE:-not set}"
if [ -n "$ECO_OCP_SRIOV_TEST_IMAGE" ]; then
    echo "  ECO_OCP_SRIOV_TEST_IMAGE: $ECO_OCP_SRIOV_TEST_IMAGE"
fi
echo ""