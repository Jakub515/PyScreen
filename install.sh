#!/bin/bash

# Krok 1: Sprawdzamy, czy Python 3.6.9 jest zainstalowany
echo "Sprawdzam, czy Python 3.6.9 jest zainstalowany..."
PYTHON_VERSION=$(python3.6 --version 2>&1)

echo $PYTHON_VERSION
# Sprawdzanie, czy zainstalowana wersja to 3.6.9
if [[ ! $PYTHON_VERSION =~ "Python 3.6" ]]; then
    echo "Python 3.6 nie jest zainstalowany. Instaluję Pythona..."

    # Instalacja Pythona 3.6 w zależności od dystrybucji
    if [ -x "$(command -v apt)" ]; then
        # Dla dystrybucji Debian/Ubuntu
        sudo apt update
        sudo apt install -y python3.6 python3.6-venv python3.6-dev python3-pip
    elif [ -x "$(command -v dnf)" ]; then
        # Dla dystrybucji Fedora
        sudo dnf install -y python3.6 python3.6-venv python3.6-dev python3-pip
    elif [ -x "$(command -v yum)" ]; then
        # Dla dystrybucji RHEL/CentOS
        sudo yum install -y python36 python36-pip
    elif [ -x "$(command -v pacman)" ]; then
        # Dla dystrybucji Arch Linux
        sudo pacman -S python3.6 python3-pip
    else
        echo "Nie obsługujemy tej dystrybucji. Proszę zainstalować Python 3.6 ręcznie."
        exit 1
    fi

    # Sprawdzanie, czy instalacja Pythona się powiodła
    PYTHON_VERSION=$(python3 --version 2>&1)
    if [[ $PYTHON_VERSION =~ "Python 3.6" ]]; then
        echo "Python 3.6 został pomyślnie zainstalowany."
    else
        echo "Błąd: Instalacja Pythona 3.6 nie powiodła się."
        exit 1
    fi
else
    echo "Python 3.6 już zainstalowany."
fi
# Krok 2: Instalacja PyInstaller w wersji 4.10
echo "Instaluję PyInstaller 4.10..."
python3.6 -m pip install pyinstaller==4.10

# Krok 3: Instalujemy wymagane biblioteki
echo "Instaluję wymagane biblioteki Pythona..."
python3.6 -m pip install -r requirements.txt

# Krok 4: Kompilacja aplikacji za pomocą PyInstaller
echo "Kompiluję aplikację..."
python3.6 -m PyInstaller --onefile --noconsole --add-data "logo.png:." --add-data "setup.sh:." --add-data ".config:." --add-data "server.crt:." --add-data "server.key:." screen.py

# Krok 6: Przenosimy skompilowaną aplikację do /usr/local/bin
echo "Przenoszę aplikację do /usr/local/bin..."
sudo mv dist/screen /usr/local/bin/screen

# Krok 7: Tworzymy usługę systemową
echo "Tworzę usługę systemową..."
SERVICE_PATH="/etc/systemd/system/screen_test.service"
echo "[Unit]
Description=Screen app
After=graphical.target

[Service]
ExecStart=/usr/local/bin/screen
Environment=DISPLAY=:0
Environment=XAUTHORITY=/tmp/.Xauthority
User=root
Group=root
Restart=always

[Install]
WantedBy=default.target" | sudo tee /etc/systemd/system/screen_test.service

# Krok 9: Modyfikujemy plik /etc/profile
echo "Modyfikuję plik /etc/profile..."

if ! sudo grep -Fxq "xhost +local:" /etc/profile; then
  echo "Dodano xhost +local: do /etc/profile."
  echo "xhost +local:" | sudo tee -a /etc/profile > /dev/null
else
  echo "xhost +local: już istnieje w /etc/profile."
fi

# Krok 8: Włączamy usługę
echo "Włączam usługę screen..."
sudo systemctl daemon-reload
sudo systemctl enable screen_test.service
sudo systemctl start screen_test.service
sudo systemctl daemon-reload

echo "Instalacja zakończona. Do poprawnego działania prosimy o ponowne zalogowanie się lub restart systemu."

