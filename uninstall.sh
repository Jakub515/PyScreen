#!/bin/bash

# Funkcja do pytania o potwierdzenie Y/N
ask_confirmation() {
    while true; do
        read -p "$1 (Y/N): " yn
        case $yn in
            [Yy]* ) return 0;;  # Tak, kontynuuj
            [Nn]* ) return 1;;  # Nie, zakończ
            * ) echo "Proszę odpowiedzieć Y lub N.";;
        esac
    done
}

# Krok 1: Usuwamy usługę systemową
ask_confirmation "Czy chcesz usunąć usługę systemową?" && {
    echo "Usuwam usługę systemową..."
    sudo systemctl stop screen_test.service
    sudo systemctl disable screen_test.service
    sudo rm /etc/systemd/system/screen_test.service
    sudo systemctl daemon-reload
}

# Krok 2: Usuwamy aplikację z /usr/local/bin
ask_confirmation "Czy chcesz usunąć aplikację z /usr/local/bin?" && {
    echo "Usuwam aplikację z /usr/local/bin..."
    sudo rm /usr/local/bin/screen
}

# Krok 3: Usuwamy repozytorium z Gita
ask_confirmation "Czy chcesz usunąć repozytorium z Gita?" && {
    echo "Usuwam repozytorium z Gita..."
    rm -rf screen
}

# Krok 4: Usuwamy wymagane biblioteki Pythona
ask_confirmation "Czy chcesz usunąć wymagane biblioteki Pythona?" && {
    echo "Wyświetlam listę bibliotek, które zostaną usunięte:"
    cat requirements.txt
    ask_confirmation "Czy na pewno chcesz usunąć te biblioteki?" && {
        echo "Usuwam wymagane biblioteki Pythona..."
        python3.6 -m pip uninstall -y -r requirements.txt
    } || {
        echo "Anulowano usuwanie bibliotek Pythona."
    }
}

# Krok 5: Usuwamy Pythona 3.6.9 (jeśli zainstalowaliśmy tę wersję)
ask_confirmation "Czy chcesz usunąć Pythona 3.6.9?" && {
    if [ -x "$(command -v apt)" ]; then
        # Dla dystrybucji Debian/Ubuntu
        sudo apt remove --purge -y python3.6 python3.6-venv python3.6-dev python3-pip
    elif [ -x "$(command -v dnf)" ]; then
        # Dla dystrybucji Fedora
        sudo dnf remove -y python3.6 python3.6-venv python3.6-dev python3-pip
    elif [ -x "$(command -v yum)" ]; then
        # Dla dystrybucji RHEL/CentOS
        sudo yum remove -y python36 python36-pip
    elif [ -x "$(command -v pacman)" ]; then
        # Dla dystrybucji Arch Linux
        sudo pacman -Rns python3.6 python3-pip
    else
        echo "Nie obsługujemy tej dystrybucji. Proszę usunąć Python 3.6 ręcznie."
    fi
}

# Krok 6: Usuwamy wpis w /etc/profile
ask_confirmation "Czy chcesz usunąć wpis z pliku /etc/profile?" && {
    echo "Usuwam wpis z pliku /etc/profile..."
    sudo sed -i '/xhost +local:/d' /etc/profile
}

echo "Proces odinstalowywania zakończony!"

