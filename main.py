from collections import namedtuple
from datetime import datetime


from flask import Flask, render_template, jsonify, redirect, url_for, request
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import desc

app = Flask(__name__)


app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://postgres:68017346@localhost/namemaster'
db = SQLAlchemy(app)

Messages = namedtuple('Messages', 'text')
messagesSession = []


class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(1024), nullable=True)
        
    def __init__(self, text):
        self.text = text.strip()


with app.app_context():
    db.create_all()


@app.route('/', methods=['GET'])
def hello_world():
    return render_template('index.html')


@app.route("/main", methods=['GET'])
def main():
    return render_template('main.html', messagesSession=messagesSession, messages=Message.query.order_by(desc(Message.id)).limit(5).all())



@app.route('/add_message', methods=['POST'])
def add_message():
    text = request.form['text']
    textx = request.form['text']


    messagesSession.append(Messages(text))

    db.session.add(Message(text))
    db.session.commit()

    return redirect(url_for('main'))
