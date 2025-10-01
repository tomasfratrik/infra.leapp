#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a copy of some function of existing library:
#
#   lib.sh of /CoreOS/rhel-system-roles/Library/basic
#   Description: Basic functions for rhel-system-roles testing
#   Author: David Jez <djez@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



rolesGetAnsibleVersion() {
    local ver
    ver="$(ansible --version | grep '^ansible .*[0-9][.]')"
    if [[ "$ver" =~ ^ansible\ ([0-9]+[.][0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$ver" =~ ^ansible\ .*core\ ([0-9]+[.][0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo UNKNOWN_ANSIBLE_VERSION
    fi
}


rolesInstallAnsible() {
    local ae_version
    ae_version=$1
    local ansible_pkg
    local pkg_cmd
    local baseurl

    if rlIsRHEL ">=8.6" && [ "$ANSIBLE_VER" != "2.9" ]; then
        pkg_cmd="dnf"
        ansible_pkg="ansible-core"
    elif rlIsRHEL 8; then
        pkg_cmd="dnf"
        ansible_pkg="ansible"
        baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/$(arch)/ansible/$ae_version/os/"
    else
        # el7
        pkg_cmd="yum"
        ansible_pkg="ansible"
        if [ "$(arch)" == "ppc64le" ]; then
            baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/rhel/power-le/7/7Server/$(arch)/ansible/$ae_version/os/"
        elif [ "$(arch)" == "s390x" ]; then
            baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/rhel/system-z/7/7Server/$(arch)/ansible/$ae_version/os/"
        else
            baseurl="https://rhsm-pulp.corp.redhat.com/content/dist/rhel/server/7/7Server/$(arch)/ansible/$ae_version/os/"
        fi
    fi

    if rlIsRHEL ">7"; then
        if "$pkg_cmd" module info standard-test-roles > /dev/null 2>&1; then
            "$pkg_cmd" -y module disable standard-test-roles
        fi
    fi
    if [ -n "${baseurl:-}" ]; then
        echo "[${ansible_pkg}-$ae_version]
name=${ansible_pkg}-$ae_version
baseurl=$baseurl
enabled=1
gpgcheck=0
priority=1" > /etc/yum.repos.d/lsr-test-ansible.repo
    fi

    # We need to swap an ansible/ansible-core if other package has been previously installed. Otherwise try to install a chosen one.
    action="install"
    rpm --quiet -q ansible && test "$ansible_pkg" = "ansible-core" && action="swap ansible"
    rpm --quiet -q ansible-core && test "$ansible_pkg" = "ansible" && action="swap ansible-core"

    rlRun "$pkg_cmd -y $action $ansible_pkg"
    rlAssertRpm "$ansible_pkg"
    # set SR_ANSIBLE_VER from ansible
    SR_ANSIBLE_VER="$(rolesGetAnsibleVersion)"
}

