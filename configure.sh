#!/bin/bash
set -euo pipefail

# Terraform runs this script as opc. Keep a durable copy of all bootstrap and
# Ansible output because remote-exec output is not available after a failed
# provisioning run.
log_directory=/var/log/oci-nfs
log_file="${log_directory}/ansible-bootstrap.log"
sudo install -d -o opc -g opc -m 0755 "${log_directory}"
sudo touch "${log_file}"
sudo chown opc:opc "${log_file}"
sudo chmod 0644 "${log_file}"
exec > >(tee -a "${log_file}") 2>&1
echo "===== OCI NFS Ansible bootstrap started: $(date -u +'%Y-%m-%dT%H:%M:%SZ') ====="

wait_for_oci_yum_dns() {
  local attempt
  for attempt in {1..30}; do
    if getent ahostsv4 yum."${region}".oci.oraclecloud.com >/dev/null; then
      return 0
    fi
    echo "Waiting for OCI Yum DNS (${attempt}/30)..."
    sleep 10
  done
  echo "ERROR: OCI Yum DNS did not become available after 300 seconds." >&2
  return 1
}

retry_package_command() {
  local attempt
  for attempt in {1..5}; do
    if "$@"; then
      return 0
    fi
    echo "Package command failed; retrying in 15 seconds (${attempt}/5)..." >&2
    sleep 15
  done
  return 1
}
#
# Cluster init configuration script
#

#
# wait for cloud-init completion on the bastion host
#
sudo cloud-init status --wait
# `/instance/region` returns a short region key (for example, "iad"), while
# OCI Yum hostnames require the full identifier (for example, "us-ashburn-1").
region=$(curl --fail --silent --show-error \
  -H "Authorization: Bearer Oracle" \
  http://169.254.169.254/opc/v2/instance/regionInfo \
  | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["regionIdentifier"])')
wait_for_oci_yum_dns
#
# Install ansible and other required packages
#
source /etc/os-release

if [[ "${ID}" == "ol" && "${VERSION_ID%%.*}" == "8" ]] ; then
  repo="ol8_developer_EPEL"
  netaddr_package="python3-netaddr"
  package_manager="dnf"

  # The OL8 EPEL repository definition is provided by this release package.
  retry_package_command sudo dnf install -y oracle-epel-release-el8
elif [[ "${ID}" == "ol" && "${VERSION_ID%%.*}" == "7" ]] ; then
  repo="ol7_developer_EPEL"
  netaddr_package="python-netaddr"
  package_manager="yum"
else
  repo="epel"
  netaddr_package="python3-netaddr"
  package_manager="dnf"
fi


# Install ansible and other required packages

retry_package_command sudo "${package_manager}" makecache --enablerepo="${repo}"
retry_package_command sudo "${package_manager}" install --enablerepo="${repo}" -y ansible "${netaddr_package}"

# Modules such as firewalld and mount are distributed in ansible.posix rather
# than the Ansible 2.9 package installed from the OL8 repository.
if [[ -f /home/opc/playbooks/collections/requirements.yml ]] ; then
  ansible-galaxy collection install \
    --requirements-file /home/opc/playbooks/collections/requirements.yml
else
  # Supports retrying a partially-created stack whose playbooks were uploaded
  # before the requirements file was added.
  ansible-galaxy collection install ansible.posix:1.5.4
fi

# Wait for every rendered inventory host, including the client and qdevice.
# The bounded Ansible waiter avoids an unbounded shell loop during ORM deploys.
echo "Waiting for all inventory hosts to accept Ansible connections"
ANSIBLE_HOST_KEY_CHECKING=False ansible all \
  -i /home/opc/playbooks/inventory \
  -m wait_for_connection \
  -a "connect_timeout=10 sleep=10 timeout=600"

#
# Ansible will take care of key exchange and learning the host fingerprints, but for the first time we need
# to disable host key checking. 

ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_FORKS=128 \
ANSIBLE_LOG_PATH="${log_directory}/ansible.log" ansible-playbook -vv \
  /home/opc/playbooks/site.yml \
  -i /home/opc/playbooks/inventory
