import hashlib
import os
import time
from collections import namedtuple

from flask import Flask, abort, render_template, redirect, url_for, request
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import desc

from form import Name


app = Flask(__name__)

# PostgreSQL database connection parameters
app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{os.environ['postgresql-username']}:{os.environ['postgresql-password']}@{os.environ['postgresql-host']}:{os.environ['postgresql-port']}/{os.environ['postgresql-database']}"
# The secret key for FlaskForm operation
app.config['SECRET_KEY'] = {os.environ['namemaster-secretkey']}  
db = SQLAlchemy(app)

# Passing the text from input to the class="form" field
Messages = namedtuple('Messages', 'text')
messagesSession = []

class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(1024), nullable=True)
        
    def __init__(self, text):
        self.text = text.strip()


with app.app_context():
    db.create_all()

@app.route("/healthz", methods=['GET'])
def healthz():
    return {"status": "ok"}

@app.route("/load/cpu", methods=['GET', 'POST'])
def load_cpu():
    token = os.getenv("LOAD_TEST_TOKEN")
    if not token or request.headers.get("X-Load-Test-Token") != token:
        abort(404)

    try:
        duration_ms = int(request.args.get("duration_ms", "100"))
    except ValueError:
        duration_ms = 100
    duration_ms = max(1, min(duration_ms, 500))

    deadline = time.perf_counter() + duration_ms / 1000
    digest = b"namemaster"
    loops = 0
    while time.perf_counter() < deadline:
        digest = hashlib.sha256(digest + loops.to_bytes(8, "little", signed=False)).digest()
        loops += 1

    return {"status": "ok", "duration_ms": duration_ms, "loops": loops}

@app.route("/", methods=['POST', 'GET'])
def main():
    # Passing the text to FlaskForm
    form = Name()
    if form.validate_on_submit():
        text = form.name.data
        messagesSession.append(Messages(text))

        db.session.add(Message(text))
        db.session.commit()
        # Restarts the site to clear the input
        return redirect(url_for('main'))
    # We write the result to the database and output it to class="form"
    return render_template('main.html', messagesSession=messagesSession, messages=Message.query.order_by(desc(Message.id)).limit(5).all(), form=form)

# Deletes all data from the "Message"
@app.route("/delete_data", methods=['POST'])
def delete_data():
    if request.method == 'POST':
        db.session.query(Message).delete()
        db.session.commit()
        return redirect(url_for('main'))
    
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
