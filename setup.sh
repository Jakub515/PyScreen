#!/usr/bin/bash
echo "Setup uruchomiony"

echo "Zatrzymuję usługę systemową"

# sudo systemctl stop screen_test
# sudo systemctl disable screen_test

echo "Zatrzymuję wszystkie procesy związane z usługą, nie licząc własnego"

MY_PID=$1

# Znajdź wszystkie procesy związane z /usr/local/bin/screen_test
ps -ef | grep "/usr/local/bin/screen_test" | awk '{print $2}' | while read pid; do
    # Sprawdź, czy PID jest różny od twojego procesu
    if [ "$pid" != "$MY_PID" ]; then
        # Zakończ proces
        sudo kill $pid
    fi
done

# Tablica do przechowywania danych
declare -a data_array

echo "Wprowadź 8 danych do zapisania w pliku $2"

# Tworzymy kopię pliku konfiguracyjnego, aby zachować oryginalne dane
temp_file=$(mktemp)

# Skopiuj zawartość oryginalnego pliku do tymczasowego pliku
cp "$2" "$temp_file"

# Warunki dla danych
# 1. Pierwszy input - 16 liczb
while true; do
    echo "Wprowadź pierwszy ciąg 16 liczb:"
    read data
    if [[ "$data" =~ ^[0-9]{16}$ ]]; then
        data_array+=("$data")
        break
    elif [ -z "$data" ]; then
        data_array+=($(sed -n '1p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź ciąg dokładnie 16 liczb."
    fi
done

# 2. Drugi input - 32-znakowy ciąg
while true; do
    echo "Wprowadź drugi ciąg 32 znaków:"
    read data
    if [[ "${#data}" -eq 32 ]]; then
        data_array+=("$data")
        break
    elif [ -z "$data" ]; then
        data_array+=($(sed -n '2p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź dokładnie 32 znaki."
    fi
done

# 3. Trzeci input - 48-znakowy ciąg
while true; do
    echo "Wprowadź trzeci ciąg 48 znaków:"
    read data
    if [[ "${#data}" -eq 48 ]]; then
        data_array+=("$data")
        break
    elif [ -z "$data" ]; then
        data_array+=($(sed -n '3p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź dokładnie 48 znaków."
    fi
done

# 4. Czwarty input - 48-znakowy ciąg
while true; do
    echo "Wprowadź czwarty ciąg 48 znaków:"
    read data
    if [[ "${#data}" -eq 48 ]]; then
        data_array+=("$data")
        break
    elif [ -z "$data" ]; then
        data_array+=($(sed -n '4p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź dokładnie 48 znaków."
    fi
done

# 5. Piąty input - adres e-mail
while true; do
    echo "Wprowadź piąty input (adres e-mail):"
    read data
    if [[ "$data" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        data_array+=("$data")
        break
    elif [ -z "$data" ]; then
        data_array+=($(sed -n '5p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź poprawny adres e-mail."
    fi
done

# 6. Szósty input - dowolny ciąg znaków
echo "Wprowadź szósty input (dowolny ciąg znaków):"
read data
if [ -n "$data" ]; then
    data_array+=("$data")
else
    data_array+=($(sed -n '6p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
fi

# 7. Siódmy input - adres IP (127.0-255.0-255.0-255)
while true; do
    echo "Wprowadź adres IP (format: 127.0-255.0-255.0-255):"
    read ip
    if [[ "$ip" =~ ^(127|1[2-9][0-9]|2[0-4][0-9]|25[0-5])(\.(0|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$ ]]; then
        data_array+=("$ip")
        break
    elif [ -z "$ip" ]; then
        data_array+=($(sed -n '7p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź poprawny adres IP."
    fi
done

# 8. Ósmy input - port (1024-49151)
while true; do
    echo "Wprowadź port (zakres: 1024-49151):"
    read port
    if [[ "$port" =~ ^([1-9][0-9]{3}|[1-4][0-9]{4}|4915[0-1])$ ]]; then
        data_array+=("$port")
        break
    elif [ -z "$port" ]; then
        data_array+=($(sed -n '8p' "$temp_file"))  # Dodaj istniejącą wartość z pliku
        break
    else
        echo "Błąd! Wprowadź port w zakresie 1024-49151."
    fi
done

# Zapisz dane w pliku konfiguracyjnym
# Nadpisz plik z danymi z tablicy, ale jeśli dane były puste, zostaną one pominięte
line_index=1
for entry in "${data_array[@]}"; do
    echo $entry
    safe_entry=$(printf '%s' "$entry" | sed 's/[&/\]/\\&/g; s/[][\.*^$(){}?+|]/\\&/g')
    sed -i "${line_index}s|.*|$safe_entry|" "$2"
    ((line_index++))
done

echo "Dane zostały zapisane w pliku $2."
