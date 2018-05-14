#!/bin/bash

####    SetItUp
####    Sets Linux up for YOU!
####    Built to make it easy to start fresh Kali VMs regularly.
####    Author: Joshua Collins

base_packages="build-essential curl htop nmap sshpass"
dev_packages="ctags git gcc g++ make perl python3 python3-dev python3-pip shellcheck vim-runtime xterm"

# Used for python2 and python3
pip_packages="requests"
perl_libraries="libdbi-perl"
tcl_packages="expect"

novelty_packages="sysvbanner cowsay"

vbox_packages="dkms virtualbox-guest-x11 virtualbox-guest-dkms virtualbox-guest-utils"

# Update apt repository state, pull the system forward to the latest (fixes lots of fun bugs in
# virtualisation software!)
unsupervised_initial_tasks()
{
    sudo apt-get update
    # Resolves some issues
    sudo apt-get --y dist-upgrade
}

# Ask a question, with a default (enter) answer of "Yes!"
# $1: The question to print/ask.
ask_question()
{
    local finish
    finish=0

    while [ $finish -ne 1 ]; do
        read -rn 1 -p "$1 (Y/n)" aq_answer

        if [ "${aq_answer,,}" == "y" ] || [ "$aq_answer" == "" ]; then
           return 0
        elif [ "${aq_answer,,}" == "n" ]; then
           return 1
        fi
        echo ""
    done
}

install_selected_packages()
{
    ask_question "Install basic-niceness packages?"
    if [ "$?" -eq 0 ]; then
        sudo apt-get -y install ${base_packages}
    fi

    ask_question "Install development packages (Python, C/C++, Perl, Vim, Make, Ctags)?"
    if [ "$?" -eq 0 ]; then
        sudo apt-get -y install ${base_packages}
        sudo apt-get -y install ${perl_libraries}

        ask_question "Install common Python2 libraries (using pip)?"
        if [ "$?" -eq 0 ]; then
            pip install ${pip_packages}
        fi

        ask_question "Install common Python3 libraries (using pip)?"
        if [ "$?" -eq 0 ]; then
            pip3 install ${pip_packages}
        fi

        ask_question "Install TCL/Expect?"
        if [ "$?" -eq 0 ]; then
            sudo apt-get -y install ${tcl_packages}
        fi
    fi

    ask_question "Do you like fun?"
    if [ "$?" -eq 0 ]; then
        sudo apt-get -y install ${novelty_packages}

        banner "YAY"
    fi
}

gnome_config()
{
    # Stop lock screen from appearing after you've been idle
    # Just hope gnome is installed, keep going if not
    gsettings set org.gnome.desktop.session idle-delay 0 || true

}

virtualbox_config()
{
    # Because shipping a package with all the important features turned off is what they did!
    VBoxClient --clipboard
    VBoxClient --draganddrop
    VBoxClient --display
    VBoxClient --seamless
    VBoxClient --vmsvga

    VBoxControl sharedfolder -automount

    # Like, seriously!?! You thought I wanted my clock to stay stuck on installation day?
    VBoxService --enable-timesync
    VBoxService --enable-automount
}

virtualbox_packages()
{
    ask_question "Install virtualbox extensions?"

    if [ "$?" -eq 0 ]; then
        # Full integration packages for kali/ubuntu

        sudo apt-get --y install ${vbox_packages}

        virtualbox_config
    fi
}

new_passwd()
{
    ask_question "Is your password still root/toor?"
    if [ "$?" -eq 0 ]; then
        echo "Shameful!"
        passwd
    fi
}

secure_ssh()
{
    ask_question "Is your SSH public key available?"
    if [ "$?" -eq 0 ]; then
        echo "In theory, copy paste should now work in your VM, if enabled in the host settings"
        read -p $'Paste your SSH public key here:\n' -r trusted_key

        echo "${trusted_key}" >> ~/.ssh/authorized_keys
    fi

    # Set appropriate permissions for the ~/.ssh directory
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys || true

    # Clear offending lines, append at the end
    sed -e 's/^PermitRootLogin.*//g' \
        -e 's/^PasswordAuthentication.*//g' \
        < /etc/ssh/sshd_config > /etc/ssh/sshd_config.tmp

    # Append the settings we want to set
    echo "# Added by $0\nPermitRootLogin no\nPasswordAuthentication no\n" >> /etc/sshd_config.tmp

    mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
}

bash_profile()
{
    # Turn on grep with colour, and open up la/ll ls aliases.

    sed -e "s|#alias \([ef]\?\)grep='\1grep --color=auto'|alias \1grep='\1grep --color=auto'|g" \
        -e "s|#alias l\([la]\?\)='ls \(.*\)'|alias l\1='ls \2'|g" \
        < ~/.bashrc > ~/.bashrc.tmp
    mv ~/.bashrc.tmp ~/.bashrc
}

vim_setup()
{
    # Skip if it's not installed.
    dpkg -s vim-runtime
    if [ "$?" -ne 0 ]; then
        return
    fi

    ask_question "Setup vimrc?"
    if [ "$?" -eq 0 ]; then
        # We like 4 spaces because we're not troglodytes.
        # Line length defaults to 100, because your screen is widescreen.
        cat >> ~/.vimrc <<EOF
set number relativenumber
set tabstop=4 expandtab shiftwidth=4 smarttab
syntax on
set colorcolumn=100
EOF
    fi

}


main()
{
    unsupervised_initial_tasks
    virtualbox_packages
    install_selected_packages

    #Configuration
    new_passwd
    secure_ssh
    gnome_config
    bash_profile
    vim_setup

    ask_question "Reboot now?"
    if [ "$?" -eq 0 ]; then
        echo "Hoping it all went OK..."
        reboot
    fi
}

main