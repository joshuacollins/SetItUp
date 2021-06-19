#!/bin/bash

####    SetItUp
####    Sets Linux up for YOU!
####    Built to make it easy to start fresh Kali VMs regularly.
####    Author: Joshua Collins

base_packages="build-essential chromium curl firefox-esr ftp htop nmap slurm ssh sshpass"
dev_packages="ctags git gcc g++ make perl python-pip python3 python3-dev python3-pip shellcheck vim vim-runtime xterm"
gui_packages="task-gnome-desktop"

# Used for python2 and python3
pip_packages="requests"
perl_libraries="libdbi-perl"
ruby_packages="ruby-full"
tcl_packages="expect"

novelty_packages="sysvbanner cowsay"

vbox_packages="build-essential dkms linux-headers-$(uname -r)"

#What type of system is it?
# kali | debian
THIS_SYSTEM=""
HAS_GUI=""

# Sets THIS_SYSTEM variable. Currently detects kali and debian.
detect_system()
{
    uname_output="$(uname -ars)"
    echo "${uname_output}" | grep "Linux kali-2018"
    if [ "$?" -eq 0 ]; then
        THIS_SYSTEM="kali"
    fi

    echo "${uname_output}" | grep "Linux debian"
    if [ "$?" -eq 0 ]; then
        THIS_SYSTEM="debian"
    fi
}

# Update apt repository state, pull the system forward to the latest (fixes lots of fun bugs in
# virtualisation software!)
unsupervised_initial_tasks()
{
    sudo apt-get update
    # Resolves some issues
    sudo apt-get -y dist-upgrade

    #shhhhhhh
    echo 'j' | sudo echo 'sudo'
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
    ask_question "Install basic packages?"
    if [ "$?" -eq 0 ]; then
        sudo apt-get -y install ${base_packages}
    fi

    ask_question "Install the GNOME GUI?"
    if [ "$?" -eq 0 ]; then
        sudo apt-get -y install ${gui_packages}
        HAS_GUI="yes"
    fi

    ask_question "Install development packages (Python, C/C++, Perl, Vim, Make, Ctags)?"
    if [ "$?" -eq 0 ]; then
        sudo apt-get -y install ${dev_packages}
        sudo apt-get -y install ${perl_libraries}

        ask_question "Install common Python3 libraries (using pip)?"
        if [ "$?" -eq 0 ]; then
            pip3 install ${pip_packages}
        fi

        ask_question "Install node.js?"
        if [ "$?" -eq 0 ]; then
            curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
            sudo apt-get install -y nodejs
        fi

        ask_question "Install TCL/Expect?"
        if [ "$?" -eq 0 ]; then
            sudo apt-get -y install ${tcl_packages}
        fi

        ask_question "Install Ruby?"
        if [ "$?" -eq 0 ]; then
            sudo apt-get -y install ${ruby_packages}
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
    # Skip if there is no GUI installed
    if [ "${HAS_GUI}" == "" ]; then
        return
    fi

    # Stop lock screen from appearing after you've been idle
    # Just hope gnome is installed, keep going if not
    gsettings set org.gnome.desktop.session idle-delay 0 || true

    #TODO: Disable transparency in the gnome-terminal
}

# Enable most commonly used features for a VM in the virtualbox package.
# Some of these commands will fail, but will have successfully enabled the feature which will work
# on reboot.
virtualbox_config()
{
    # Because shipping a package with all the important features turned off is what they did!
    sudo VBoxClient --clipboard
    sudo VBoxClient --draganddrop
    sudo VBoxClient --display
    sudo VBoxClient --seamless
    sudo VBoxClient --vmsvga

    sudo VBoxControl sharedfolder -automount

    # Like, seriously!?! You thought I wanted my clock to stay stuck on installation day?
    sudo VBoxService --enable-timesync
    sudo VBoxService --enable-automount

}

virtualbox_packages()
{
    ask_question "Install virtualbox extensions?"

    if [ "$?" -eq 0 ]; then
        # Full integration packages for kali/ubuntu
        sudo apt-get -y install ${vbox_packages}

        if [ -e '/media/cdrom' ]; then

            sudo cp /media/cdrom/VBoxLinuxAdditions.run ./
            sudo ./VBoxLinuxAdditions.run

            virtualbox_config

            sudo rm ./VBoxLinuxAdditions.run

        else
            echo "Couldn't find VirtualBox Guest Additions CDROM"
        fi
    fi
}

new_root_passwd()
{
    if [ "${THIS_SYSTEM}" == "kali" ]; then
        ask_question "Is your password still root/toor?"
        if [ "$?" -eq 0 ]; then
            echo "Shameful!"
            passwd
        fi
    fi
}

secure_ssh()
{
    ask_question "Is your SSH public key available?"
    if [ "$?" -eq 0 ]; then
        # TODO: No it won't, not without a reboot.
        echo "In theory, copy paste should now work in your VM, if enabled in the host settings"
        read -p $'Paste your SSH public key here:\n' -r trusted_key

        if [ ! -d "~/.ssh/" ]; then
            mkdir ~/.ssh
        fi
        echo "${trusted_key}" >> ~/.ssh/authorized_keys
    fi

    #TODO: Determine effective user - if running as sudo in a system without root, we try to write to
    # non-existent directories.

    # Set appropriate permissions for the ~/.ssh directory
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys || true

    if [ -e "/etc/ssh/sshd_config" ]; then
        # Clear offending lines, append at the end
        sudo sh -c "sed -e 's/^PermitRootLogin.*//g' \
            -e 's/^PasswordAuthentication.*//g' \
            < /etc/ssh/sshd_config > /etc/ssh/sshd_config.tmp"

        # Append the settings we want to set
        sudo echo -e "# Added by $0\nPermitRootLogin no\nPasswordAuthentication no\n" >> /etc/ssh/sshd_config.tmp

        sudo mv /etc/ssh/sshd_config.tmp /etc/ssh/sshd_config
    else
        echo "SSH server not installed, skipping"
    fi
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
    dpkg -s vim-runtime > /dev/null
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

msf_init()
{
    if [ "${THIS_SYSTEM}" == "kali" ]; then
        msfdb init
        msfconsole -x "db_rebuild_cache"
    fi
}

clean_up()
{
    echo "Removing packages no longer required"
    sudo apt autoremove
}


main()
{
    detect_system
    unsupervised_initial_tasks
    virtualbox_packages
    install_selected_packages

    #Configuration
    new_root_passwd
    secure_ssh
    gnome_config
    bash_profile
    vim_setup
    clean_up

    ask_question "Reboot now?"
    if [ "$?" -eq 0 ]; then
        echo "Hoping it all went OK..."
        sudo reboot 
    fi
}

main
