import sys
import os
import subprocess
from flask import Flask, request, make_response, redirect, send_file, Response, session
from PIL import Image
from urllib.parse import parse_qs
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
import time
import mss
import io
import gc
import random
import ssl
import smtplib
import uuid
import base64

app = Flask(__name__)

# Load configuration
def load_config(file_path):
    with open(file_path, 'r') as file:
        return [line.strip() for line in file.readlines()]

if getattr(sys, 'frozen', False):  # If run from .exe
    config_path = os.path.join(sys._MEIPASS, '.config')
    image_path = os.path.join(sys._MEIPASS, 'logo.png')
    config_data = load_config(config_path)
    bash_file = os.path.join(sys._MEIPASS, 'setup.sh')
    CERT_FILE = os.path.join(sys._MEIPASS, 'server.crt')
    KEY_FILE = os.path.join(sys._MEIPASS, 'server.key')
else:
    image_path = 'logo.png'
    config_data = load_config('.config')
    bash_file = 'setup.sh'
    config_path = ".config"
    CERT_FILE = "server.crt"
    KEY_FILE = "server.key"

app.config['SECRET_KEY'] = config_data[0].encode()  # Flask uses this for session management
PASSWORD_APP = config_data[1]
URL_USERNAME = config_data[2]
URL_PASSWORD = config_data[3]
ADV_USERNAME = config_data[4]
ADV_PASSWORD = config_data[5]
IP_ADDRESS = config_data[6]
PORT_ADRRESS = int(config_data[7])

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SENDER_EMAIL = "wifi.esp32@gmail.com"  # Your email
SENDER_PASSWORD = "qmbh sbzx nbsr nckf "  # Your email password

LOGIN_HTML = """<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Logowanie</title>
</head>
<body>
    <h2>Logowanie</h2>
    <form action="/auth" method="post">
        <label for="username">Nazwa użytkownika:</label>
        <input type="text" id="username" name="username" required>
        <br>
        <label for="password">Hasło:</label>
        <input type="password" id="password" name="password" required>
        <br>
        <button type="submit">Zaloguj</button>
    </form>
</body>
</html>
"""

VERYFICATION_HTML = """<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Weryfikacja</title>
</head>
<body>
    <h2>Wprowadź kod weryfikacyjny</h2>
    <form action="/verify" method="post">
        <label for="verification_code">Kod weryfikacyjny:</label>
        <input type="text" id="verification_code" name="verification_code" required>
        <br>
        <button type="submit">Zweryfikuj</button>
    </form>
</body>
</html>
"""

#test argumentów
try:
    if sys.argv[1] == "setup":
        subprocess.run(["bash", bash_file, str(os.getpid()), str(config_path)])
        exit()
except IndexError:
    pass

auth_ip = []
lista_uuid = []
lista_uuid_stream = []
ifDecCorrect = True

def send_cors_headers(response):
    """Sets CORS headers."""
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    response.headers["Access-Control-Allow-Credentials"] = "true"
    return response

@app.route('/favicon.ico', methods=['GET'])
def favicon():
    return send_file("logo.png", mimetype='image/png')

@app.route('/auth/', methods=['GET'])
def auth_get():
    resp = make_response(LOGIN_HTML)
    send_cors_headers(resp)
    resp.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    resp.headers['Pragma'] = 'no-cache'
    resp.headers['Expires'] = '0'
    return resp

@app.route('/icon.png', methods=['GET'])
def icon():
    try:
        with open("logo.png", 'rb') as file:
            img_data = file.read()
        resp = make_response(img_data)
        resp.headers['Content-Type'] = 'image/png'
        return send_cors_headers(resp)
    except FileNotFoundError:
        return "File not found", 404

@app.route('/auth/' + URL_USERNAME + '/' + URL_PASSWORD + '/<string:uuid_param>', methods=['GET'])
def auth_stream(uuid_param):
    global auth_ip

    for i in auth_ip:
        print(f"in for. i: {i}")
        if (10 + i[1]) > time.time():
            if i[0] == request.remote_addr:
                if "/auth/"+URL_USERNAME+"/"+URL_PASSWORD+"/"+i[2] == request.path:
                    print(f"authorized. deleting: {i}")
                    auth_ip.remove(i)
                    return Response(stream(), mimetype='multipart/x-mixed-replace; boundary=frame')
                else:
                    print("ip address authorised but password doesn't much. deleting")
                    auth_ip.remove(i)
            else:
                return "Unauthorized", 401
        else:
            print("timeout detected")
            auth_ip.remove(i)
    return "Unauthorized", 401

@app.route('/stream', methods=['GET'])
def stream_route():
    # Sprawdzamy, czy UUID streamu znajduje się na liście
    if session.get('acceptStream') in lista_uuid_stream:
        # Po zakończeniu streamingu lub po raz jednorazowy, usuwamy UUID z listy
        lista_uuid_stream.remove(session.get('acceptStream'))
        return Response(stream(), mimetype='multipart/x-mixed-replace; boundary=frame')
    else:
        return redirect('/auth/')

@app.route('/postauth', methods=['POST'])
def post_auth():
    global ifDecCorrect
    try:
        encrypted_password = request.data.decode('utf-8')
        print("Odebrane dane zaszyfrowane: ", encrypted_password)
        print("Typ danych: ", type(encrypted_password))
        ifDecCorrect = True
        decrypted_password = decrypt_password(encrypted_password)

        if ifDecCorrect:
            print("Rozszyfrowane dane: ", decrypted_password)
            print("Typ danych: ", type(decrypted_password))
            ifDecCorrect = (decrypted_password == PASSWORD_APP)
        print("Czy zgodność haseł: ", str(ifDecCorrect))
        uuid_for_url_stream = uuid.uuid4().hex[:24]
        if ifDecCorrect:
            auth_ip.append([request.remote_addr, time.time(), uuid_for_url_stream])
            print(auth_ip)

        # Przygotowanie odpowiedzi
        response_data = uuid_for_url_stream.encode('utf-8') if ifDecCorrect else b'ok'
        resp = make_response(response_data)
        resp.headers["Content-Type"] = "text/plain; charset=utf-8"
        
        # Zastosowanie CORS w odpowiedzi
        return send_cors_headers(resp)

    except Exception as e:
        error_message = f"Błąd: {str(e)}"
        resp = make_response(error_message, 400)
        
        # Zastosowanie CORS w odpowiedzi z błędem
        return send_cors_headers(resp)



@app.route('/auth', methods=['POST'])
def auth():
    username = request.form.get("username")
    password = request.form.get("password")

    if username == ADV_USERNAME and password == ADV_PASSWORD:
        verification_code = generate_verification_code()
        send_verification_email(ADV_USERNAME, verification_code)
        special_uuid = str(uuid.uuid4())
        session['authenticated'] = special_uuid
        lista_uuid.append(special_uuid)
        return redirect('/verify')
    else:
        resp = make_response(LOGIN_HTML)
        resp.status_code = 401
        return send_cors_headers(resp)

@app.route('/verify', methods=['POST', 'GET'])
def verify():
    user_uuid = session.get('authenticated')

    if user_uuid not in lista_uuid:
        print("Niepoprawna sesja, usuwam `authenticated`")
        session.pop('authenticated', None)
        session.pop('verification_code', None)
        return redirect('/auth/')

    entered_code = request.form.get("verification_code")
    if entered_code == session.get('verification_code'):
        special_uuid_stream = str(uuid.uuid4())
        session['acceptStream'] = special_uuid_stream
        lista_uuid_stream.append(special_uuid_stream)

        # Usuwamy UUID użytkownika z listy, aby dostęp był jednorazowy
        lista_uuid.remove(user_uuid)
        session.pop('authenticated', None)
        session.pop('verification_code', None)

        return redirect('/stream')
    else:
        resp = make_response(VERYFICATION_HTML)
        resp.status_code = 401
        return send_cors_headers(resp)



@app.route('/', methods=['OPTIONS'])
def options():
    resp = make_response()
    return send_cors_headers(resp)

def decrypt_password(encrypted_password):
    global ifDecCorrect
    try:
        encrypted_password_bytes = base64.b64decode(encrypted_password)
        cipher = AES.new(app.config['SECRET_KEY'], AES.MODE_CBC, app.config['SECRET_KEY'])
        decrypted_bytes = unpad(cipher.decrypt(encrypted_password_bytes), AES.block_size)
        return decrypted_bytes.decode('utf-8')
    except ValueError:
        ifDecCorrect = False
        return None

def generate_verification_code():
    """Generates a random verification code."""
    code = "".join(map(str, random.sample(range(10), 6)))
    session['verification_code'] = code
    return code

def send_verification_email(recipient_email, verification_code):
    """Sends an email with the verification code."""
    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = recipient_email
    current_time = time.strftime("%Y.%m.%d %H:%M:%S", time.localtime())
    msg['Subject'] = f"{verification_code} - kod weryfikacyjny - {current_time}"

    body = f"<html><head></head><body><h2>Kod weryfikacyjny</h2><p>Twój kod weryfikacyjny to <b>{verification_code}</b>.</p><br></body></html>"
    msg.attach(MIMEText(body, "html"))

    context = ssl.create_default_context()
    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls(context=context)
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
            server.sendmail(SENDER_EMAIL, recipient_email, msg.as_string())
        print("E-mail z kodem weryfikacyjnym został wysłany.")
    except Exception as e:
        print(f"Nie udało się wysłać e-maila: {e}")

def stream():
    with mss.mss() as sct:
        while True:
            try:
                start_time = time.time()
                screenshot = sct.grab(sct.monitors[1])

                img_byte_arr = io.BytesIO()
                img = Image.frombytes("RGB", screenshot.size, screenshot.rgb)
                img = img.resize((screenshot.width // 2, screenshot.height // 2))
                img.save(img_byte_arr, format='JPEG', quality=50)
                img_byte_arr.seek(0)

                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + img_byte_arr.read() + b'\r\n')

                print("czas: " + str(time.time() - start_time))
                if (time.time() - start_time) < 0.14:
                    time.sleep(0.14 - (time.time() - start_time))
                else:
                    time.sleep(0.05)
                img.close()
                img_byte_arr.close()
                gc.collect()
            except BrokenPipeError as e:
                print(e)
                break

if __name__ == "__main__":
    print("ip:",IP_ADDRESS)
    #app.run(host=IP_ADDRESS, port=PORT_ADRRESS, debug=True)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    app.run(host=IP_ADDRESS, port=PORT_ADRRESS, debug=True, ssl_context=context)
