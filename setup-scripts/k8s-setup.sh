#!/bin/bash

# Default Services and Directory
K8S_CONFIG_DIR="$HOME/.kube"
K8S_KUBEAPI_FILE="/var/snap/k8s/common/args/kube-apiserver"
#K8S_CONTROLLER_FILE="/var/snap/k8s/common/args/kube-controller-manager"
DASHBOARD_CONFIG_DIR="$HOME/k8s-default"
CONFIG_CHANGED=false

# Define color codes as global variables
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_RESET='\033[0m'

# Initialization in Yellow color
print_init() {
    local message="$1"
    printf "${COLOR_YELLOW}%s${COLOR_RESET}\n" "$message"
}

# Function to print success messages in green
print_success() {
    local message="$1"
    printf "${COLOR_GREEN}%s${COLOR_RESET}\n" "$message"
}

# Function to print failure messages in red
print_fail() {
    local message="$1"
    printf "${COLOR_RED}%s${COLOR_RESET}\n" "$message"
}

# Function to print separator
print_separator() {
    echo "=========================================================================="
}

# Function to print usage information
user_help_function() {
    local script_name="$0"
    printf "\n\n"
    print_success "Usage: $script_name [-s <service1,service2,...>] [-d <log_directory>]"
    echo "Options:"
    echo "  -s, --service <service1,service2,...>  Comma-separated list of services to check"
    echo "  -d, --directory <log_directory>        Optional: Directory where log file will be stored"
    echo
    print_fail "Examples:"
    print_init "  $script_name -s nginx.service,supervisor.service"
    print_init "  $script_name -s nginx.service -d /path/to/logdir"
    printf "\n"
    print_fail "Contact and Support"
    echo -n "   Email:   "
    print_success "subash.chaudhary@globalyhub.com"
    echo -n "   Phone:   "
    print_success "+977 9823827047"
    exit 1
}

dependency_installation() {
    # Check if K8s is already installed
    sudo apt update    
    local packages=("k8s:Kubernetes" "kubectl:Kubectl" "helm:Helm")
    local i=0
    while [ $i -lt ${#packages[@]} ]; do
        IFS=':' read -r cmd name <<< "${packages[$i]}"
        if ! command -v "$cmd" &> /dev/null; then
            print_init "Installing $name"
            sudo snap install "$cmd" --classic
        else
            print_success "$name is already installed. Skipping."
        fi
        ((i++))
    done

    print_init "Checking K8s cluster status"    
    # Check if cluster is already ready
    if sudo k8s status --wait-ready --timeout 8s &> /dev/null; then
        print_success "K8s cluster is already ready. Skipping bootstrap."
    else
        print_init "Cluster not ready. Running bootstrap..."
        sudo k8s bootstrap
        
        print_init "Waiting for cluster to become ready..."
        if sudo k8s status --wait-ready; then
            print_success "K8s cluster is now ready"
        else
            print_fail "Cluster failed to reach ready state after bootstrap"
            print_fail "Please check logs with 'k8s inspect' or contact support"
            return 1
        fi
    fi    

    # Check if Kubernetes config directory exists
    if [[ ! -d "${K8S_CONFIG_DIR}" ]]; then
        mkdir -p "${K8S_CONFIG_DIR}"
        sudo k8s config > "${K8S_CONFIG_DIR}/config"
        sudo chown $USER:$USER ${K8S_CONFIG_DIR}/config
        echo "Created config config directory: ${K8S_CONFIG_DIR}"
        print_separator
    else
        print_success "K8s config directory: ${K8S_CONFIG_DIR} already exists"
    fi
}

add_kubectl_auto_completion() {
    echo "----------------------"
    if ! dpkg -l | grep -q bash-completion; then
        sudo apt install -y bash-completion
    fi

    # Add kubectl completion to .bashrc if missing
    if ! grep -q "kubectl completion bash" ~/.bashrc; then
        print_init "Configuring kubectl completion"
        echo 'source <(kubectl completion bash)' >> ~/.bashrc
        source ~/.bashrc
        print_success "kubectl completion configured"
    fi  
}


updating_service_port_range() {
    
    echo "----------------------"
    print_init "Test 1: Updating Service Port Range"
    local service_file="${K8S_KUBEAPI_FILE}"
    if ! sudo test -f "${service_file}"; then
        print_fail "API service-file config is not found at ${service_file}"
        echo "----------------------"
        return 1
    else
        print_success "File found. Testing service-port-range"
        if sudo grep -q "service-node-port-range" "${service_file}"; then
            local current_port_range
            current_port_range=$(sudo grep "service-node-port-range" "${service_file}" | awk -F '=' '{print $2}' | tr -d ' ')
            print_init "Current port range: ${current_port_range}"

            if [[ "${current_port_range}" == "26-65534" ]]; then
                print_success "Port is already configured correctly"
            else
                print_fail "Unexpected port range configuration: ${current_port_range}"
                print_init "Updating port range to 26-65534"
                sudo sed -i "s|service-node-port-range=.*|service-node-port-range=26-65534|" "${service_file}"
                print_success "Port range updated to 1025-65534"
                CONFIG_CHANGED=true
            fi
        else
            print_fail "No port range configuration found"
            print_init "Adding service-node-port-range=1025-65534 to the configuration"
            echo "--service-node-port-range=26-65534" | sudo tee -a /var/snap/k8s/common/args/kube-apiserver > /dev/null
            print_success "Port range configuration added: 26-65534"
            CONFIG_CHANGED=true
        fi
    fi
    echo "----------------------"
}

kube_proxy_cidr_update() {
    echo "----------------------"
    print_init "Test 2: Updating Kube Proxy CIDR"
    local service_file="${K8S_KUBEAPI_FILE}"
    if ! sudo test -f "${service_file}"; then
        print_fail "API service-file config is not found at ${service_file}"
        echo "----------------------"
        return 1
    else
        print_success "File found. Testing service-cluster-ip-range"
        if sudo grep -q "service-cluster-ip-range" "${service_file}"; then
            local current_cidr
            current_cidr=$(sudo grep "service-cluster-ip-range" "${service_file}" | awk -F '=' '{print $2}' | tr -d ' ')
            print_init "Current CIDR range: ${current_cidr}"

            if [[ "${current_cidr}" == "10.152.0.0/16" ]]; then
                print_success "CIDR range is already configured correctly"
            else
                print_fail "Unexpected CIDR range configuration: ${current_cidr}"
                print_init "Updating CIDR range to 10.152.0.0/16"
                sudo sed -i "s|service-cluster-ip-range=.*|service-cluster-ip-range=10.152.0.0/16|" "${service_file}"
                print_success "CIDR range updated to 10.152.0.0/16"
                CONFIG_CHANGED=true
            fi
        fi
    fi
    echo "----------------------"
}

restart_K8s() {
    print_init "Restarting K8s services"

    # Attempt to stop K8s
    if ! sudo snap stop k8s; then
        print_fail "Failed to stop k8s. Continuing with start attempt."
    fi

    # Attempt to start K8s
    if sudo snap start k8s; then
        # Check K8s status to ensure it started correctly
        print_init "Checking K8s status"
        if sudo k8s status --wait-ready >/dev/null; then
            print_success "K8s restarted successfully"
        else
            print_fail "K8s failed to reach ready state"
            print_fail "Please check logs with 'K8s inspect' or contact support"
            return 1
        fi
    else
        print_fail "Failed to start K8s"
        print_fail "Please check logs with 'K8s inspect' or contact support"
        return 1
    fi
}


# Main function
main() {
    dependency_installation
    add_kubectl_auto_completion
    updating_service_port_range
    kube_proxy_cidr_update

    if [[ "$CONFIG_CHANGED" == true ]]; then
        restart_K8s
    else
        print_success "No configuration changes detected. Skipping K8s restart."
    fi
    # Unset all variables
    unset K8S_CONFIG_DIR
    unset K8S_TOKEN_FILE
    unset K8S_KUBEAPI_FILE
    unset CONFIG_CHANGED
    unset COLOR_GREEN
    unset COLOR_RED
    unset COLOR_YELLOW
    unset COLOR_RESET
}

main "$@"