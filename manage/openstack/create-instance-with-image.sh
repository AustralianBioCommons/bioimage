#!/bin/bash

# Configuration
VM_PREFIX="training"
SECURITY_GROUP="ssh"
IMAGE_ID="a92eb89c-9106-45b5-b4fc-aa068be80ffd"
AVAILABILITY_ZONE="CloudV3"
KEY_NAME="ssh-key"
FLAVOR="c3pl.2c4m20d"
BATCH_SIZE=10          # Number of VMs to create simultaneously
BATCH_DELAY=30         # Seconds to wait between batches
RETRY_ATTEMPTS=3       # Number of retry attempts for failed VMs
RETRY_DELAY=10         # Seconds to wait between retries
CHECK_INTERVAL=5       # Seconds to wait when checking VM status
DEBUG=0                # Set to 1 to enable debug output

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${2:-$NC}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check OpenStack CLI availability
if ! command -v openstack &> /dev/null; then
    log "OpenStack CLI not found. Please load your OpenStack environment (e.g. 'source openrc.sh')" $RED
    exit 1
fi

# Check if image exists
if ! openstack image show "$IMAGE_ID" &> /dev/null; then
    log "Image '$IMAGE_ID' not found in OpenStack. Use 'openstack image list' to check." $RED
    exit 1
fi

# Check if flavor exists
if ! openstack flavor show "$FLAVOR" &> /dev/null; then
    log "Flavor '$FLAVOR' not found in OpenStack. Use 'openstack flavor list' to check." $RED
    exit 1
fi

# Check if key pair exists
if ! openstack keypair show "$KEY_NAME" &> /dev/null; then
    log "Key pair '$KEY_NAME' not found in OpenStack. Use 'openstack keypair list' to check." $RED
    exit 1
fi

# Check if security group exists
if ! openstack security group show "$SECURITY_GROUP" &> /dev/null; then
    log "Security group '$SECURITY_GROUP' not found in OpenStack. Use 'openstack security group list' to check." $RED
    exit 1
fi

# Prompt for number of VMs
read -p "How many VMs do you want to create? " NUM_VMS

# Validate number
if ! [[ "$NUM_VMS" =~ ^[0-9]+$ ]] || [[ "$NUM_VMS" -le 0 ]]; then
    log "Invalid number: $NUM_VMS" $RED
    exit 1
fi

# Function to check VM status
check_vm_status() {
    local vm_name=$1
    local vm_info
    
    vm_info=$(openstack server show "$vm_name" -f value -c status -c power_state 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "not_found"
        return
    fi
    
    # Parse the output
    local line1=$(echo "$vm_info" | head -n1 | tr -d ' \t\r\n')
    local line2=$(echo "$vm_info" | tail -n1 | tr -d ' \t\r\n')
    
    # Determine which line is status and which is power_state
    local status power_state
    if [[ "$line1" =~ ^(Running|Shutdown|Paused|Suspended)$ ]]; then
        # First line is power_state, second is status
        power_state="$line1"
        status="$line2"
    else
        # First line is status, second is power_state
        status="$line1"
        power_state="$line2"
    fi
    
    # Handle empty values
    if [[ -z "$status" ]]; then
        status="unknown"
    fi
    if [[ -z "$power_state" ]]; then
        power_state="unknown"
    fi
    
    # Debug output
    if [[ "$DEBUG" == "1" ]]; then
        log "DEBUG: VM '$vm_name' raw output: '$vm_info'" $YELLOW
        log "DEBUG: Line1: '$line1', Line2: '$line2'" $YELLOW
        log "DEBUG: Parsed status: '$status', power_state: '$power_state'" $YELLOW
    fi
    
    echo "${status}:${power_state}"
}

# Function to wait for VM to be ready
wait_for_vm_ready() {
    local vm_name=$1
    local max_wait=600  # 10 minutes max wait
    local elapsed=0
    
    log "Waiting for VM '$vm_name' to be ready..." $BLUE
    
    while [[ $elapsed -lt $max_wait ]]; do
        local status_info=$(check_vm_status "$vm_name")
        local status=$(echo "$status_info" | cut -d':' -f1)
        local power_state=$(echo "$status_info" | cut -d':' -f2)
        
        case "$status" in
            "ACTIVE"|"active")
                if [[ "$power_state" == "Running" || "$power_state" == "running" || "$power_state" == "ACTIVE" || "$power_state" == "active" ]]; then
                    log "VM '$vm_name' is active and ready (power: '$power_state')" $GREEN
                    return 0
                else
                    log "VM '$vm_name' is active but power state is '$power_state'" $YELLOW
                    return 1
                fi
                ;;
            "ERROR"|"error")
                log "VM '$vm_name' is in error state" $RED
                return 2
                ;;
            "BUILD"|"build"|"BUILDING"|"building")
                log "VM '$vm_name' is still building... (${elapsed}s elapsed)" $BLUE
                ;;
            "SPAWN"|"spawn"|"SPAWNING"|"spawning")
                log "VM '$vm_name' is spawning... (${elapsed}s elapsed)" $BLUE
                ;;
            "PENDING"|"pending")
                log "VM '$vm_name' is pending... (${elapsed}s elapsed)" $BLUE
                ;;
            "SCHEDULING"|"scheduling")
                log "VM '$vm_name' is being scheduled... (${elapsed}s elapsed)" $BLUE
                ;;
            "NETWORKING"|"networking")
                log "VM '$vm_name' is configuring network... (${elapsed}s elapsed)" $BLUE
                ;;
            "BLOCK_DEVICE_MAPPING"|"block_device_mapping")
                log "VM '$vm_name' is mapping block devices... (${elapsed}s elapsed)" $BLUE
                ;;
            "IMAGE_SNAPSHOT"|"image_snapshot")
                log "VM '$vm_name' is creating image snapshot... (${elapsed}s elapsed)" $BLUE
                ;;
            "not_found")
                log "VM '$vm_name' not found" $RED
                return 3
                ;;
            *)
                log "VM '$vm_name' status: '$status' (power: '$power_state')" $YELLOW
                ;;
        esac
        
        sleep $CHECK_INTERVAL
        elapsed=$((elapsed + CHECK_INTERVAL))
    done
    
    log "Timeout waiting for VM '$vm_name' to be ready" $RED
    return 4
}

# Function to create a single VM
create_vm() {
    local vm_name=$1
    local attempt=$2
    
    log "Creating VM '$vm_name' (attempt $attempt)..." $BLUE
    
    # Create the VM
    local create_output
    create_output=$(openstack server create "$vm_name" \
        --security-group "$SECURITY_GROUP" \
        --image "$IMAGE_ID" \
        --availability-zone "$AVAILABILITY_ZONE" \
        --key-name "$KEY_NAME" \
        --flavor "$FLAVOR" 2>&1)
    
    local create_result=$?
    
    if [[ $create_result -eq 0 ]]; then
        log "VM creation command successful for '$vm_name'" $GREEN
        return 0
    else
        log "VM creation command failed for '$vm_name': $create_output" $RED
        return 1
    fi
}

# Function to delete a VM
delete_vm() {
    local vm_name=$1
    log "Deleting VM '$vm_name'..." $YELLOW
    openstack server delete "$vm_name" 2>/dev/null
    sleep 10  # Give some time for deletion
}

# Function to process a single VM (create and validate)
process_vm() {
    local vm_name=$1
    local attempt=1
    
    while [[ $attempt -le $RETRY_ATTEMPTS ]]; do
        # Check if VM already exists
        local status_info=$(check_vm_status "$vm_name")
        local status=$(echo "$status_info" | cut -d':' -f1)
        local power_state=$(echo "$status_info" | cut -d':' -f2)
        
        case "$status" in
            "ACTIVE"|"active")
                if [[ "$power_state" == "Running" || "$power_state" == "running" || "$power_state" == "ACTIVE" || "$power_state" == "active" ]]; then
                    log "VM '$vm_name' already exists and is ready (power: '$power_state')" $GREEN
                    return 0
                else
                    log "VM '$vm_name' is active but not ready (power: '$power_state')" $YELLOW
                    # You might want to start it instead of recreating
                    log "Attempting to start VM '$vm_name'..." $BLUE
                    openstack server start "$vm_name" 2>/dev/null
                    wait_for_vm_ready "$vm_name"
                    local wait_result=$?
                    if [[ $wait_result -eq 0 ]]; then
                        return 0
                    fi
                fi
                ;;
            "ERROR"|"error")
                log "VM '$vm_name' is in error state, recreating..." $YELLOW
                delete_vm "$vm_name"
                ;;
            "BUILD"|"build"|"BUILDING"|"building"|"SPAWN"|"spawn"|"SPAWNING"|"spawning"|"PENDING"|"pending"|"SCHEDULING"|"scheduling"|"NETWORKING"|"networking"|"BLOCK_DEVICE_MAPPING"|"block_device_mapping"|"IMAGE_SNAPSHOT"|"image_snapshot")
                log "VM '$vm_name' is being created (status: '$status'), waiting..." $BLUE
                wait_for_vm_ready "$vm_name"
                local wait_result=$?
                if [[ $wait_result -eq 0 ]]; then
                    return 0
                else
                    log "VM '$vm_name' failed to become ready after creation process" $RED
                    delete_vm "$vm_name"
                fi
                ;;
            "SHUTOFF"|"shutoff")
                log "VM '$vm_name' exists but is shut off, starting..." $BLUE
                openstack server start "$vm_name" 2>/dev/null
                wait_for_vm_ready "$vm_name"
                local wait_result=$?
                if [[ $wait_result -eq 0 ]]; then
                    return 0
                else
                    log "VM '$vm_name' failed to start properly" $RED
                    delete_vm "$vm_name"
                fi
                ;;
            "not_found")
                # VM doesn't exist, create it
                ;;
            ""|"unknown")
                log "VM '$vm_name' has unknown status, checking manually..." $YELLOW
                # Try a different approach to get status
                local manual_check=$(openstack server list --name "$vm_name" -f value -c Status -c Power\ State 2>/dev/null)
                if [[ -n "$manual_check" ]]; then
                    local manual_status=$(echo "$manual_check" | awk '{print $1}')
                    local manual_power=$(echo "$manual_check" | awk '{print $2}')
                    log "Manual check: status='$manual_status', power='$manual_power'" $BLUE
                    if [[ "$manual_status" == "ACTIVE" || "$manual_status" == "active" ]]; then
                        if [[ "$manual_power" == "Running" || "$manual_power" == "running" || "$manual_power" == "ACTIVE" || "$manual_power" == "active" ]]; then
                            log "VM '$vm_name' is actually active and ready" $GREEN
                            return 0
                        fi
                    fi
                fi
                log "VM '$vm_name' status unclear, recreating..." $YELLOW
                delete_vm "$vm_name"
                ;;
            *)
                log "VM '$vm_name' has unexpected status '$status' (power: '$power_state'), recreating..." $YELLOW
                delete_vm "$vm_name"
                ;;
        esac
        
        # Create the VM
        if create_vm "$vm_name" "$attempt"; then
            wait_for_vm_ready "$vm_name"
            local wait_result=$?
            if [[ $wait_result -eq 0 ]]; then
                return 0
            else
                log "VM '$vm_name' failed to become ready after creation" $RED
                delete_vm "$vm_name"
            fi
        fi
        
        attempt=$((attempt + 1))
        if [[ $attempt -le $RETRY_ATTEMPTS ]]; then
            log "Retrying VM '$vm_name' in ${RETRY_DELAY}s..." $YELLOW
            sleep $RETRY_DELAY
        fi
    done
    
    log "Failed to create VM '$vm_name' after $RETRY_ATTEMPTS attempts" $RED
    return 1
}

# Main processing logic
log "Starting VM creation process for $NUM_VMS VMs" $BLUE
log "Using batch size: $BATCH_SIZE, batch delay: ${BATCH_DELAY}s" $BLUE
log "Configuration:" $BLUE
log "  Prefix: $VM_PREFIX" $BLUE
log "  Image: $IMAGE_ID" $BLUE
log "  Flavor: $FLAVOR" $BLUE
log "  Key: $KEY_NAME" $BLUE
log "  Security Group: $SECURITY_GROUP" $BLUE
log "  Availability Zone: $AVAILABILITY_ZONE" $BLUE

successful_vms=()
failed_vms=()

# Create temporary directory for batch results
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Process VMs in batches
for ((start=1; start<=NUM_VMS; start+=BATCH_SIZE)); do
    end=$((start + BATCH_SIZE - 1))
    if [[ $end -gt $NUM_VMS ]]; then
        end=$NUM_VMS
    fi
    
    log "Processing batch: VMs $start to $end" $BLUE
    
    # Process VMs in current batch in parallel
    batch_pids=()
    for ((i=start; i<=end; i++)); do
        vm_name="${VM_PREFIX}-${i}"
        (
            if process_vm "$vm_name"; then
                echo "SUCCESS:$vm_name" > "$TEMP_DIR/result_$i"
            else
                echo "FAILED:$vm_name" > "$TEMP_DIR/result_$i"
            fi
        ) &
        batch_pids+=($!)
    done
    
    # Wait for all VMs in current batch to complete
    for pid in "${batch_pids[@]}"; do
        wait $pid
    done
    
    # Collect results from temporary files
    for ((i=start; i<=end; i++)); do
        if [[ -f "$TEMP_DIR/result_$i" ]]; then
            result=$(cat "$TEMP_DIR/result_$i")
            vm_name="${VM_PREFIX}-${i}"
            
            if [[ "$result" == "SUCCESS:$vm_name" ]]; then
                successful_vms+=("$vm_name")
                log "Batch result: VM '$vm_name' - SUCCESS" $GREEN
            else
                failed_vms+=("$vm_name")
                log "Batch result: VM '$vm_name' - FAILED" $RED
            fi
        else
            # If no result file, assume failed
            vm_name="${VM_PREFIX}-${i}"
            failed_vms+=("$vm_name")
            log "Batch result: VM '$vm_name' - FAILED (no result file)" $RED
        fi
    done
    
    # Wait between batches (except for the last batch)
    if [[ $end -lt $NUM_VMS ]]; then
        log "Waiting ${BATCH_DELAY}s before next batch..." $BLUE
        sleep $BATCH_DELAY
    fi
done

# Final verification - double-check the status of all VMs
log "Performing final verification of all VMs..." $BLUE
final_successful=()
final_failed=()

for ((i=1; i<=NUM_VMS; i++)); do
    vm_name="${VM_PREFIX}-${i}"
    status_info=$(check_vm_status "$vm_name")
    status=$(echo "$status_info" | cut -d':' -f1)
    power_state=$(echo "$status_info" | cut -d':' -f2)
    
    if [[ ("$status" == "ACTIVE" || "$status" == "active") && ("$power_state" == "Running" || "$power_state" == "running" || "$power_state" == "ACTIVE" || "$power_state" == "active") ]]; then
        final_successful+=("$vm_name")
    else
        final_failed+=("$vm_name")
        log "Final check: VM '$vm_name' status: '$status', power: '$power_state'" $YELLOW
    fi
done

log "=== SUMMARY ===" $BLUE
log "Process Results - Successful: ${#successful_vms[@]}, Failed: ${#failed_vms[@]}" $BLUE
log "Final Verification - Successful: ${#final_successful[@]}, Failed: ${#final_failed[@]}" $BLUE

if [[ ${#final_successful[@]} -gt 0 ]]; then
    log "Successfully created and verified VMs:" $GREEN
    printf '%s\n' "${final_successful[@]}" | sort -V
fi

if [[ ${#final_failed[@]} -gt 0 ]]; then
    log "Failed or problematic VMs:" $RED
    printf '%s\n' "${final_failed[@]}" | sort -V
    log "You can rerun this script to retry failed VMs." $YELLOW
fi

log "VM creation process completed." $BLUE